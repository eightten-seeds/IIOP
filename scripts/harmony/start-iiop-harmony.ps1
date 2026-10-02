$ErrorActionPreference = 'Stop'
$project = 'E:\IIOP\harmony'
$gateway = 'http://127.0.0.1:8080'
$env:DEVECO_SDK_HOME = 'D:\DevEco Studio\sdk'
$hdcCommand = Get-Command hdc -ErrorAction SilentlyContinue
$hvigorCommand = Get-Command hvigorw -ErrorAction SilentlyContinue
$hdc = if ($hdcCommand) { $hdcCommand.Source } else { 'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' }
$hvigor = if ($hvigorCommand) { $hvigorCommand.Source } elseif (Test-Path -LiteralPath 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat') { 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat' } else { Join-Path $project 'hvigorw.bat' }

Write-Host '[1/7] 检查 HarmonyOS 开发环境'
if (-not (Test-Path -LiteralPath $hdc) -or -not (Test-Path -LiteralPath $hvigor)) {
    throw 'MANUAL STEP REQUIRED：请使用华为官方 DevEco Studio 安装器补齐 SDK Toolchains、hdc 与 Hvigor。'
}

Write-Host '[2/7] 检查 IIOP Gateway'
try { Invoke-WebRequest -Uri $gateway -UseBasicParsing -TimeoutSec 5 | Out-Null } catch {
    if (-not $_.Exception.Response) { throw 'Gateway 8080 当前不可达，请先启动 IIOP 后端。' }
}

Write-Host '[3/7] 检查 HarmonyOS Emulator'
$targets = & $hdc list targets 2>$null
if (-not $targets -or ($targets -join '').Trim().Length -eq 0) {
    throw 'MANUAL STEP REQUIRED：请在 DevEco Studio Device Manager 首次创建并启动 Phone Emulator。'
}

Write-Host '[4/7] 等待设备连接'
Write-Host "已连接：$($targets -join ', ')"

Write-Host '[5/7] 构建 IIOP'
Push-Location $project
try { & $hvigor --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon } finally { Pop-Location }
if ($LASTEXITCODE -ne 0) { throw "HarmonyOS 构建失败，退出码：$LASTEXITCODE" }
$haps = Get-ChildItem -LiteralPath (Join-Path $project 'entry\build') -Filter '*.hap' -File -Recurse | Sort-Object LastWriteTime -Descending
$hap = $haps | Where-Object { $_.Name -notmatch 'unsigned' } | Select-Object -First 1
if (-not $hap -and $haps) { throw 'MANUAL STEP REQUIRED：已生成 unsigned HAP，请先在 DevEco Studio 中完成 Debug 自动签名配置。' }
if (-not $hap) { throw '构建完成但未找到 HAP 产物。' }

Write-Host '[6/7] 安装应用'
& $hdc install -r $hap.FullName
if ($LASTEXITCODE -ne 0) { throw "HAP 安装失败，退出码：$LASTEXITCODE" }

Write-Host '[7/7] 启动 IIOP'
& $hdc shell aa start -a EntryAbility -b com.iiop.mobile
if ($LASTEXITCODE -ne 0) { throw "应用启动失败，退出码：$LASTEXITCODE" }
Write-Host 'IIOP 鸿蒙端已启动。'
