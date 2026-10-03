$ErrorActionPreference = 'Stop'
$root = 'E:\IIOP'
$project = Join-Path $root 'harmony'
$runtime = 'E:\IIOP-data\dev\infra'
$env:DEVECO_SDK_HOME = 'D:\DevEco Studio\sdk'
$env:NODE_HOME = 'D:\DevEco Studio\tools\node'
$env:PATH = "$env:NODE_HOME;$env:PATH"
$env:JAVA_HOME = 'F:\Program Files\Java\jdk-17'
$env:ROCKETMQ_HOME = 'E:\DevTools\rocketmq-all-5.3.1-bin-release'
$hdc = 'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$hvigor = 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
$emulator = 'D:\DevEco Studio\tools\emulator\Emulator.exe'

function Test-Port([int]$Port) {
    $client = [System.Net.Sockets.TcpClient]::new()
    try { $client.Connect('127.0.0.1', $Port); return $true } catch { return $false } finally { $client.Dispose() }
}

function Wait-Port([int]$Port, [int]$TimeoutSeconds, [string]$Name) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do { if (Test-Port $Port) { return }; Start-Sleep -Seconds 2 } while ((Get-Date) -lt $deadline)
    throw "$Name 未在 $TimeoutSeconds 秒内监听端口 $Port。"
}

function Get-RealHdcTarget {
    $lines = @(& $hdc list targets 2>$null)
    foreach ($line in $lines) {
        $candidate = ([string]$line).Trim()
        if (-not $candidate -or $candidate -eq '[Empty]' -or $candidate -match '^COM\d+$') { continue }
        $candidate = ($candidate -split '\s+')[0]
        if (-not $candidate -or $candidate -eq '[Empty]' -or $candidate -match '^COM\d+$') { continue }
        $probe = (& $hdc -t $candidate shell echo IIOP_EMULATOR_OK 2>$null | Out-String).Trim()
        if ($probe -match 'IIOP_EMULATOR_OK') { return $candidate }
    }
    return $null
}

Write-Host '[1/8] 检查开发工具与基础设施'
foreach ($path in $hdc, $hvigor, $emulator, (Join-Path $env:JAVA_HOME 'bin\java.exe')) {
    if (-not (Test-Path -LiteralPath $path)) { throw "缺少开发工具：$path" }
}
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
if (-not (Test-Port 3306)) {
    try { Start-Service MySQL80 } catch { throw 'MANUAL STEP REQUIRED：MySQL80 未运行，请允许 Windows UAC 后启动该服务。' }
    Wait-Port 3306 30 'MySQL'
}
if (-not (Test-Port 6379)) {
    try { Start-Service Redis -ErrorAction Stop } catch {
        Start-Process -FilePath 'E:\Redis-x64-5.0.14.1\redis-server.exe' -ArgumentList @('E:\Redis-x64-5.0.14.1\redis.windows-service.conf') -WorkingDirectory 'E:\Redis-x64-5.0.14.1' -WindowStyle Hidden
    }
    Wait-Port 6379 20 'Redis'
}
if (-not (Test-Port 8848)) {
    Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c','"E:\DevTools\nacos-server-3.0.3\bin\startup.cmd" -m standalone') -WorkingDirectory 'E:\DevTools\nacos-server-3.0.3\bin' -RedirectStandardOutput (Join-Path $runtime 'nacos-launcher.log') -RedirectStandardError (Join-Path $runtime 'nacos-launcher.err.log') -WindowStyle Hidden
    Wait-Port 8848 90 'Nacos'
}
if (-not (Test-Port 9876)) {
    Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c','"E:\DevTools\rocketmq-all-5.3.1-bin-release\bin\mqnamesrv.cmd"') -WorkingDirectory 'E:\DevTools\rocketmq-all-5.3.1-bin-release\bin' -RedirectStandardOutput (Join-Path $runtime 'rocketmq-namesrv-launcher.log') -RedirectStandardError (Join-Path $runtime 'rocketmq-namesrv-launcher.err.log') -WindowStyle Hidden
    Wait-Port 9876 45 'RocketMQ NameServer'
}
if (-not (Test-Port 10911)) {
    Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c','"E:\DevTools\rocketmq-all-5.3.1-bin-release\bin\mqbroker.cmd" -n 127.0.0.1:9876 -c "E:\IIOP\infra\local\rocketmq\broker.conf"') -WorkingDirectory 'E:\DevTools\rocketmq-all-5.3.1-bin-release\bin' -RedirectStandardOutput (Join-Path $runtime 'rocketmq-broker-launcher.log') -RedirectStandardError (Join-Path $runtime 'rocketmq-broker-launcher.err.log') -WindowStyle Hidden
    Wait-Port 10911 60 'RocketMQ Broker'
}

Write-Host '[2/8] 检查 Backend 与 Gateway'
$backendPorts = 8080,9201,9202,9203,9204,9205
if (@($backendPorts | Where-Object { -not (Test-Port $_) }).Count -gt 0) {
    & (Join-Path $root 'scripts\dev\backend-start.ps1')
}
foreach ($port in $backendPorts) { Wait-Port $port 120 "Backend $port" }
$captcha = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/api/auth/captcha' -Method Get -TimeoutSec 15
if ($captcha.code -ne 0 -or -not $captcha.data.captchaId -or -not $captcha.data.image) { throw 'Gateway Captcha Host Gate 未通过。' }

Write-Host '[3/8] 检查并启动现有 Mate 90 Pro Emulator'
$target = Get-RealHdcTarget
if (-not $target) {
    $instanceRoot = 'D:\HarmonyEmulator'
    $instanceName = 'Mate 90 Pro'
    $instanceDirectory = Join-Path $instanceRoot $instanceName
    if (-not (Test-Path -LiteralPath (Join-Path $instanceDirectory 'config.ini'))) { throw 'MANUAL STEP REQUIRED：未找到现有 Mate 90 Pro 实例，请在 Device Manager 检查实例目录。' }
    if (-not (Get-Process -Name Emulator -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $emulator -ArgumentList @('-start','"Mate 90 Pro"','-instancePath','"D:\HarmonyEmulator"','-bootMode','coldboot') -WorkingDirectory (Split-Path $emulator)
    }
}

Write-Host '[4/8] 等待真实 HDC target'
$deadline = (Get-Date).AddMinutes(8)
do {
    $target = Get-RealHdcTarget
    if ($target) { break }
    & $hdc tconn 127.0.0.1:5555 2>$null | Out-Null
    Start-Sleep -Seconds 5
} while ((Get-Date) -lt $deadline)
if (-not $target) { throw 'MANUAL STEP REQUIRED：模拟器未形成真实 HDC target；null、空字符串和 [Empty] 均不会继续安装。' }
Write-Host "已连接 HDC target：$target"

Write-Host '[5/8] clean 并构建本次 Debug HAP'
$buildStartedAt = Get-Date
Push-Location $project
try {
    & $hvigor --mode module -p product=default -p module=entry@default clean --no-daemon
    if ($LASTEXITCODE -ne 0) { throw "HarmonyOS clean 失败，退出码：$LASTEXITCODE" }
    & $hvigor --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon
    if ($LASTEXITCODE -ne 0) { throw "HarmonyOS 构建失败，退出码：$LASTEXITCODE" }
} finally { Pop-Location }
$output = Join-Path $project 'entry\build\default\outputs\default'
$haps = @(Get-ChildItem -LiteralPath $output -Filter '*.hap' -File | Where-Object { $_.LastWriteTime -ge $buildStartedAt.AddSeconds(-2) })
$hap = $haps | Sort-Object @{ Expression = { $_.Name -notmatch 'unsigned' }; Descending = $true }, LastWriteTime -Descending | Select-Object -First 1
if (-not $hap) { throw '本次构建完成但没有生成可识别的 HAP。' }

Write-Host '[6/8] 安装本次 Debug HAP（现有 Emulator 允许 unsigned）'
& $hdc -t $target install -r $hap.FullName
if ($LASTEXITCODE -ne 0) { throw "HAP 安装失败，退出码：$LASTEXITCODE" }

Write-Host '[7/8] 读取并启动真实 Bundle/Ability'
$appText = Get-Content -LiteralPath (Join-Path $project 'AppScope\app.json5') -Raw
$moduleText = Get-Content -LiteralPath (Join-Path $project 'entry\src\main\module.json5') -Raw
$bundleName = [regex]::Match($appText, '"bundleName"\s*:\s*"([^"]+)"').Groups[1].Value
$abilityName = [regex]::Match($moduleText, '"abilities"\s*:\s*\[\s*\{[\s\S]*?"name"\s*:\s*"([^"]+)"').Groups[1].Value
if (-not $bundleName -or -not $abilityName) { throw '无法从项目配置读取 bundleName 或 abilityName。' }
& $hdc -t $target shell aa start -a $abilityName -b $bundleName
if ($LASTEXITCODE -ne 0) { throw "应用启动失败，退出码：$LASTEXITCODE" }

Write-Host '[8/8] IIOP 鸿蒙端已启动'
Write-Host "HAP：$($hap.FullName)"
