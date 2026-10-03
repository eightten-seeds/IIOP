$ErrorActionPreference = 'Stop'

$root = 'E:\IIOP'
$runtimeRoot = 'E:\IIOP-data\dev'
$infraRuntime = Join-Path $runtimeRoot 'infra'
$backendRuntime = Join-Path $runtimeRoot 'backend'
$webRuntime = Join-Path $runtimeRoot 'web'
$harmonyProject = Join-Path $root 'harmony'
$hap = Join-Path $harmonyProject 'entry\build\default\outputs\default\entry-default-unsigned.hap'

$env:JAVA_HOME = 'F:\Program Files\Java\jdk-17'
$env:DEVECO_SDK_HOME = 'D:\DevEco Studio\sdk'
$env:NODE_HOME = 'D:\DevEco Studio\tools\node'
$env:ROCKETMQ_HOME = 'E:\DevTools\rocketmq-all-5.3.1-bin-release'
$env:PATH = "$env:NODE_HOME;$env:JAVA_HOME\bin;$env:PATH"

$hdc = 'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$hvigor = 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
$emulator = 'D:\DevEco Studio\tools\emulator\Emulator.exe'
$emulatorRoot = 'D:\HarmonyEmulator'
$emulatorName = 'Mate 90 Pro'
$emulatorConfig = Join-Path (Join-Path $emulatorRoot $emulatorName) 'config.ini'
$bundleName = 'com.iiop.mobile'
$abilityName = 'EntryAbility'
$webUrl = 'http://127.0.0.1:5173'

$script:failedComponent = ''
$script:failedPort = $null
$script:failedLog = ''
$script:hapAction = 'REUSED'
$script:hdcTarget = ''

function Test-Port([int]$Port) {
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $async = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne(800)) { return $false }
        $client.EndConnect($async)
        return $true
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

function Fail-Startup([string]$Component, [string]$Reason, [Nullable[int]]$Port = $null, [string]$Log = '') {
    $script:failedComponent = $Component
    $script:failedPort = $Port
    $script:failedLog = $Log
    throw $Reason
}

function Wait-Port([int]$Port, [int]$TimeoutSeconds, [string]$Component, [string]$Log = '') {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (Test-Port $Port) { return }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    Fail-Startup $Component "$Component did not listen on port $Port within $TimeoutSeconds seconds" $Port $Log
}

function Require-Path([string]$Path, [string]$Component) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Fail-Startup $Component "Required path does not exist: $Path"
    }
}

function Get-HdcTarget {
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

function Wait-HdcTarget([int]$TimeoutSeconds) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $candidate = Get-HdcTarget
        if ($candidate) { return $candidate }
        & $hdc tconn 127.0.0.1:5555 2>$null | Out-Null
        Start-Sleep -Seconds 5
    } while ((Get-Date) -lt $deadline)
    Fail-Startup 'Emulator' "HDC target did not become online within $TimeoutSeconds seconds"
}

function Test-HarmonyBuildRequired {
    if (-not (Test-Path -LiteralPath $hap)) { return $true }
    $hapTime = (Get-Item -LiteralPath $hap).LastWriteTimeUtc
    $sourceFiles = @()
    foreach ($directory in @(
        (Join-Path $harmonyProject 'AppScope'),
        (Join-Path $harmonyProject 'entry\src')
    )) {
        if (Test-Path -LiteralPath $directory) {
            $sourceFiles += Get-ChildItem -LiteralPath $directory -File -Recurse
        }
    }
    foreach ($file in @(
        (Join-Path $harmonyProject 'build-profile.json5'),
        (Join-Path $harmonyProject 'oh-package.json5'),
        (Join-Path $harmonyProject 'oh-package-lock.json5'),
        (Join-Path $harmonyProject 'hvigor\hvigor-config.json5'),
        (Join-Path $harmonyProject 'entry\build-profile.json5'),
        (Join-Path $harmonyProject 'entry\oh-package.json5')
    )) {
        if (Test-Path -LiteralPath $file) { $sourceFiles += Get-Item -LiteralPath $file }
    }
    return $null -ne ($sourceFiles | Where-Object { $_.LastWriteTimeUtc -gt $hapTime } | Select-Object -First 1)
}

function Write-FinalStatus {
    Write-Host ''
    Write-Host '========================================'
    Write-Host '        IIOP STARTUP STATUS'
    Write-Host '========================================'
    Write-Host ('{0,-15} PASS  {1}' -f 'MySQL', '3306')
    Write-Host ('{0,-15} PASS  {1}' -f 'Redis', '6379')
    Write-Host ('{0,-15} PASS  {1}' -f 'Nacos', '8848')
    Write-Host ('{0,-15} PASS  {1}' -f 'RocketMQ NS', '9876')
    Write-Host ('{0,-15} PASS  {1}' -f 'RocketMQ', '10911')
    Write-Host ''
    Write-Host ('{0,-15} PASS  {1}' -f 'Auth', '9201')
    Write-Host ('{0,-15} PASS  {1}' -f 'Device', '9202')
    Write-Host ('{0,-15} PASS  {1}' -f 'Inspection', '9203')
    Write-Host ('{0,-15} PASS  {1}' -f 'Maintenance', '9204')
    Write-Host ('{0,-15} PASS  {1}' -f 'AI', '9205')
    Write-Host ('{0,-15} PASS  {1}' -f 'Gateway', '8080')
    Write-Host ''
    Write-Host ('{0,-15} PASS' -f 'Web')
    Write-Host ('{0,-15} {1}' -f 'Web URL', $webUrl)
    Write-Host ''
    Write-Host ('{0,-15} PASS' -f 'Emulator')
    Write-Host ('{0,-15} PASS  {1}' -f 'HDC', $script:hdcTarget)
    Write-Host ('{0,-15} PASS  {1}' -f 'Harmony HAP', $script:hapAction)
    Write-Host ('{0,-15} STARTED' -f 'IIOP Mobile')
    Write-Host ''
    Write-Host '========================================'
    Write-Host '              IIOP READY'
    Write-Host '========================================'
}

try {
    New-Item -ItemType Directory -Force -Path $infraRuntime, $backendRuntime, $webRuntime | Out-Null
    foreach ($required in @($hdc, $hvigor, $emulator, $emulatorConfig, (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
        Require-Path $required 'Environment'
    }

    Write-Host '[1/5] Infrastructure'
    if (Test-Port 3306) {
        Write-Host 'MySQL: SKIP / PASS (3306)'
    } else {
        try { Start-Service MySQL80 -ErrorAction Stop } catch { Fail-Startup 'MySQL' $_.Exception.Message 3306 }
        Wait-Port 3306 30 'MySQL'
        Write-Host 'MySQL: PASS (3306)'
    }

    if (Test-Port 6379) {
        Write-Host 'Redis: SKIP / PASS (6379)'
    } else {
        try {
            Start-Service Redis -ErrorAction Stop
        } catch {
            $redisExe = 'E:\Redis-x64-5.0.14.1\redis-server.exe'
            $redisConfig = 'E:\Redis-x64-5.0.14.1\redis.windows-service.conf'
            Require-Path $redisExe 'Redis'
            Require-Path $redisConfig 'Redis'
            Start-Process -FilePath $redisExe -ArgumentList @($redisConfig) -WorkingDirectory (Split-Path $redisExe) -WindowStyle Hidden
        }
        Wait-Port 6379 30 'Redis'
        Write-Host 'Redis: PASS (6379)'
    }

    if (Test-Port 8848) {
        Write-Host 'Nacos: SKIP / PASS (8848)'
    } else {
        $nacos = 'E:\DevTools\nacos-server-3.0.3\bin\startup.cmd'
        Require-Path $nacos 'Nacos'
        $nacosLog = Join-Path $infraRuntime 'nacos-launcher.log'
        Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', '"E:\DevTools\nacos-server-3.0.3\bin\startup.cmd" -m standalone') -WorkingDirectory (Split-Path $nacos) -RedirectStandardOutput $nacosLog -RedirectStandardError (Join-Path $infraRuntime 'nacos-launcher.err.log') -WindowStyle Hidden
        Wait-Port 8848 120 'Nacos' $nacosLog
        Write-Host 'Nacos: PASS (8848)'
    }

    if (Test-Port 9876) {
        Write-Host 'RocketMQ NS: SKIP / PASS (9876)'
    } else {
        $namesrv = 'E:\DevTools\rocketmq-all-5.3.1-bin-release\bin\mqnamesrv.cmd'
        Require-Path $namesrv 'RocketMQ NS'
        $namesrvLog = Join-Path $infraRuntime 'rocketmq-namesrv-launcher.log'
        Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', '"E:\DevTools\rocketmq-all-5.3.1-bin-release\bin\mqnamesrv.cmd"') -WorkingDirectory (Split-Path $namesrv) -RedirectStandardOutput $namesrvLog -RedirectStandardError (Join-Path $infraRuntime 'rocketmq-namesrv-launcher.err.log') -WindowStyle Hidden
        Wait-Port 9876 60 'RocketMQ NS' $namesrvLog
        Write-Host 'RocketMQ NS: PASS (9876)'
    }

    if (Test-Port 10911) {
        Write-Host 'RocketMQ: SKIP / PASS (10911)'
    } else {
        $broker = 'E:\DevTools\rocketmq-all-5.3.1-bin-release\bin\mqbroker.cmd'
        $brokerConfig = Join-Path $root 'infra\local\rocketmq\broker.conf'
        Require-Path $broker 'RocketMQ'
        Require-Path $brokerConfig 'RocketMQ'
        $brokerLog = Join-Path $infraRuntime 'rocketmq-broker-launcher.log'
        $brokerCommand = "call `"$broker`" -n 127.0.0.1:9876 -c `"$brokerConfig`""
        Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d', '/c', $brokerCommand) -WorkingDirectory (Split-Path $broker) -RedirectStandardOutput $brokerLog -RedirectStandardError (Join-Path $infraRuntime 'rocketmq-broker-launcher.err.log') -WindowStyle Hidden
        Wait-Port 10911 90 'RocketMQ' $brokerLog
        Write-Host 'RocketMQ: PASS (10911)'
    }

    Write-Host '[2/5] Backend'
    $backendServices = @(
        @{ Name = 'Gateway'; Module = 'iiop-gateway'; Port = 8080; Log = 'gateway.err.log' },
        @{ Name = 'Auth'; Module = 'iiop-auth'; Port = 9201; Log = 'auth.err.log' },
        @{ Name = 'Device'; Module = 'iiop-device'; Port = 9202; Log = 'device.err.log' },
        @{ Name = 'Inspection'; Module = 'iiop-inspection'; Port = 9203; Log = 'inspection.err.log' },
        @{ Name = 'Maintenance'; Module = 'iiop-maintenance'; Port = 9204; Log = 'maintenance.err.log' },
        @{ Name = 'AI'; Module = 'iiop-ai'; Port = 9205; Log = 'ai.err.log' }
    )
    # Always call backend-start.ps1; it applies CASE A-E stale-PID detection per service.
    # Only build missing JARs first if any are absent.
    $missingJars = @($backendServices | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root "backend\$($_.Module)\target\$($_.Module)-1.0.0-SNAPSHOT.jar")) })
    if ($missingJars.Count -gt 0) {
        $mvn = (Get-Command mvn.cmd -ErrorAction SilentlyContinue).Source
        if (-not $mvn) { $mvn = (Get-Command mvn -ErrorAction SilentlyContinue).Source }
        if (-not $mvn) { Fail-Startup 'Backend Build' 'mvn was not found on PATH' }
        Push-Location (Join-Path $root 'backend')
        try {
            & $mvn '-Dmaven.repo.local=E:/DevCache/maven/repository' package -DskipTests
            if ($LASTEXITCODE -ne 0) { Fail-Startup 'Backend Build' "Maven package failed with exit code $LASTEXITCODE" $null (Join-Path $backendRuntime 'build.log') }
        } finally {
            Pop-Location
        }
    }
    & (Join-Path $root 'scripts\dev\backend-start.ps1')
    foreach ($service in $backendServices) {
        if (Test-Port $service.Port) {
            Write-Host "$($service.Name): SKIP / PASS ($($service.Port))"
        } else {
            Wait-Port $service.Port 120 $service.Name (Join-Path $backendRuntime $service.Log)
            Write-Host "$($service.Name): PASS ($($service.Port))"
        }
    }

    Write-Host '[3/5] Web'
    if (Test-Port 5173) {
        Write-Host 'Web: SKIP / PASS (5173)'
    } else {
        $webProject = Join-Path $root 'frontend\iiop-web'
        if (-not (Test-Path -LiteralPath (Join-Path $webProject 'node_modules'))) {
            $npm = (Get-Command npm.cmd -ErrorAction SilentlyContinue).Source
            if (-not $npm) { $npm = (Get-Command npm -ErrorAction SilentlyContinue).Source }
            if (-not $npm) { Fail-Startup 'Web' 'npm was not found on PATH' 5173 (Join-Path $webRuntime 'dev.log') }
            Push-Location $webProject
            try {
                if (Test-Path -LiteralPath (Join-Path $webProject 'package-lock.json')) {
                    & $npm ci --cache 'E:\DevCache\npm'
                } else {
                    & $npm install --cache 'E:\DevCache\npm'
                }
                if ($LASTEXITCODE -ne 0) { Fail-Startup 'Web' "npm install failed with exit code $LASTEXITCODE" 5173 (Join-Path $webRuntime 'dev.log') }
            } finally {
                Pop-Location
            }
        }
        & (Join-Path $root 'scripts\dev\web-start.ps1')
        Wait-Port 5173 90 'Web' (Join-Path $webRuntime 'dev.log')
        Write-Host 'Web: PASS (5173)'
    }
    Write-Host "Web URL: $webUrl"

    Write-Host '[4/5] Harmony Emulator and HAP'
    $target = Get-HdcTarget
    if ($target) {
        Write-Host "Emulator: SKIP / PASS ($target)"
    } else {
        if (-not (Get-Process -Name Emulator -ErrorAction SilentlyContinue)) {
            Start-Process -FilePath $emulator -ArgumentList @('-start','"Mate 90 Pro"','-instancePath','"D:\HarmonyEmulator"','-bootMode','coldboot') -WorkingDirectory (Split-Path $emulator)
        }
        $target = Wait-HdcTarget 300
        Write-Host "Emulator: PASS ($target)"
    }
    $script:hdcTarget = $target

    if (Test-HarmonyBuildRequired) {
        Write-Host 'Harmony HAP: source is newer; building once'
        Push-Location $harmonyProject
        try {
            & $hvigor --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon
            if ($LASTEXITCODE -ne 0) { Fail-Startup 'Harmony HAP' "assembleHap failed with exit code $LASTEXITCODE" }
        } finally {
            Pop-Location
        }
        $script:hapAction = 'BUILT'
    } else {
        Write-Host 'Harmony HAP: REUSED'
    }
    Require-Path $hap 'Harmony HAP'

    # Wait for emulator system services (BMS/SAMGR) to be fully ready before installing
    $bmsDeadline = (Get-Date).AddSeconds(60)
    do {
        $dumpCheck = (& $hdc -t $target shell bm dump -a 2>&1 | Out-String).Trim()
        if ($dumpCheck -match 'bundleName') { break }
        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $bmsDeadline)

    Write-Host '[5/5] Install and launch IIOP Mobile'
    $installSuccess = $false
    $installDeadline = (Get-Date).AddSeconds(60)
    $lastInstallOutput = ''
    do {
        $lastInstallOutput = (& $hdc -t $target install -r $hap 2>&1 | Out-String).Trim()
        if ($lastInstallOutput -match 'install bundle successfully' -or $lastInstallOutput -match 'already exists') {
            $installSuccess = $true
            break
        }
        Start-Sleep -Seconds 5
    } while ((Get-Date) -lt $installDeadline)
    if (-not $installSuccess) {
        Fail-Startup 'Harmony HAP' "HAP install failed: $lastInstallOutput"
    }

    $bundleConfirmed = $false
    $bmDeadline = (Get-Date).AddSeconds(30)
    do {
        $bundleOutput = (& $hdc -t $target shell bm dump -n $bundleName 2>&1 | Out-String).Trim()
        if ($bundleOutput -match [regex]::Escape($bundleName)) { $bundleConfirmed = $true; break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $bmDeadline)
    if (-not $bundleConfirmed) {
        Fail-Startup 'IIOP Mobile' "bm dump did not confirm $bundleName within 30 seconds"
    }

    $launchOutput = (& $hdc -t $target shell aa start -a $abilityName -b $bundleName 2>&1 | Out-String)
    $launchText = $launchOutput.Trim()
    if ($launchText -match '10106102' -or $launchText -match 'screen is locked') {
        Write-Host ''
        Write-Host '========================================' -ForegroundColor Yellow
        Write-Host '     HARMONY MANUAL ACTION REQUIRED' -ForegroundColor Yellow
        Write-Host '========================================' -ForegroundColor Yellow
        Write-Host 'Mate 90 Pro Emulator is locked.'
        Write-Host ''
        Write-Host 'Please manually unlock the emulator screen.'
        Write-Host ''
        Write-Host 'Do not close this window.'
        Write-Host 'After the emulator is unlocked, press Enter to continue.'
        Write-Host '========================================' -ForegroundColor Yellow
        Read-Host 'Press Enter after unlocking'

        $target = Get-HdcTarget
        if (-not $target) {
            Fail-Startup 'Emulator' 'HDC target is no longer online after manual unlock'
        }
        $launchOutput = (& $hdc -t $target shell aa start -a $abilityName -b $bundleName 2>&1 | Out-String)
        $launchText = $launchOutput.Trim()
    }

    if ($launchText -notmatch 'start ability successfully') {
        Fail-Startup 'IIOP Mobile' $launchText
    }

    # Give the App process a moment to appear in the process table after aa start
    Start-Sleep -Seconds 3
    $mobileStarted = $false
    $mobileDeadline = (Get-Date).AddSeconds(60)
    do {
        $pidOutput = (& $hdc -t $target shell pidof $bundleName 2>$null | Out-String).Trim()
        if ($pidOutput -match '\d+') { $mobileStarted = $true; break }
        $psOutput = (& $hdc -t $target shell ps -A 2>$null | Out-String)
        if ($psOutput -match [regex]::Escape($bundleName)) { $mobileStarted = $true; break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $mobileDeadline)
    if (-not $mobileStarted) { Fail-Startup 'IIOP Mobile' 'App process was not observed within 60 seconds' }

    Write-FinalStatus
    exit 0
} catch {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Red
    Write-Host '          IIOP START FAILED' -ForegroundColor Red
    Write-Host '========================================' -ForegroundColor Red
    if ($script:failedComponent) { Write-Host "FAIL: $script:failedComponent" -ForegroundColor Red }
    if ($null -ne $script:failedPort) { Write-Host "PORT: $script:failedPort" }
    Write-Host "REASON: $($_.Exception.Message)"
    if ($script:failedLog) { Write-Host "LOG:`n$script:failedLog" }
    exit 1
}
