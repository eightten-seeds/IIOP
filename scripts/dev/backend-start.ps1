$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common.ps1')

$root = Get-IiopRoot
$state = Join-Path (Get-IiopRuntimeRoot) 'backend'
$java = Get-IiopJavaExecutable

New-Item -ItemType Directory -Force -Path $state | Out-Null

$services = @(
    @{ name = 'gateway';     module = 'iiop-gateway';     port = 8080 },
    @{ name = 'auth';        module = 'iiop-auth';        port = 9201 },
    @{ name = 'device';      module = 'iiop-device';      port = 9202 },
    @{ name = 'inspection';  module = 'iiop-inspection';  port = 9203 },
    @{ name = 'maintenance'; module = 'iiop-maintenance'; port = 9204 },
    @{ name = 'ai';          module = 'iiop-ai';          port = 9205 }
)

function Test-TcpPort([int]$Port) {
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

function Get-ProcessCmdLine([int]$ProcessId) {
    try {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
        if ($process) { return [string]$process.CommandLine }
        return ''
    } catch {
        return ''
    }
}

function Get-PortOwnerPid([int]$Port) {
    $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($connection) { return $connection.OwningProcess }
    return $null
}

foreach ($service in $services) {
    $pidFile = Join-Path $state "$($service.name).pid"
    $jar = Join-Path $root "backend\$($service.module)\target\$($service.module)-1.0.0-SNAPSHOT.jar"
    $log = Join-Path $state "$($service.name).log"
    $errorLog = Join-Path $state "$($service.name).err.log"
    $moduleName = $service.module
    $portNum = $service.port

    $storedPid = $null
    if (Test-Path -LiteralPath $pidFile) {
        $rawPid = (Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($rawPid -match '^\d+$') { $storedPid = [int]$rawPid }
    }

    $portListening = Test-TcpPort $portNum
    $storedProc = if ($storedPid) { Get-Process -Id $storedPid -ErrorAction SilentlyContinue } else { $null }
    $storedCmdLine = if ($storedProc) { Get-ProcessCmdLine $storedPid } else { '' }
    $storedIsIiop = $storedCmdLine -match [regex]::Escape($moduleName)

    if ($storedPid -and $storedProc -and $storedIsIiop -and $portListening) {
        Write-Output "$($service.name): already running (PID=$storedPid, port=$portNum)"
        continue
    }

    if ($storedPid -and -not $storedProc) {
        Write-Output "$($service.name): stale PID file (PID=$storedPid not found); removing"
        Remove-Item -LiteralPath $pidFile -Force
        $storedPid = $null
    }

    if ($storedPid -and $storedProc) {
        if ($storedIsIiop -and -not $portListening) {
            Write-Output "$($service.name): stale/failed IIOP process (PID=$storedPid, port $portNum not listening); stopping"
            Stop-Process -Id $storedPid -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
            $storedPid = $null
        } elseif (-not $storedIsIiop) {
            Write-Output "$($service.name): PID file points to unrelated process; removing stale file"
            Remove-Item -LiteralPath $pidFile -Force
            $storedPid = $null
        }
    }

    if ($portListening) {
        $ownerPid = Get-PortOwnerPid $portNum
        if ($ownerPid) {
            $ownerCmdLine = Get-ProcessCmdLine $ownerPid
            $ownerIsIiop = $ownerCmdLine -match [regex]::Escape($moduleName)
            if ($ownerIsIiop) {
                Write-Output "$($service.name): port $portNum already belongs to IIOP (PID=$ownerPid); rebuilding PID file"
                $ownerPid | Set-Content -LiteralPath $pidFile
                continue
            }

            $ownerName = (Get-Process -Id $ownerPid -ErrorAction SilentlyContinue).Name
            throw "Port $portNum is occupied by unexpected process PID=$ownerPid ($ownerName). Cannot start $($service.name)."
        }
    }

    if (-not (Test-Path -LiteralPath $jar)) {
        throw "Missing built jar: $jar"
    }

    $arguments = @('-jar', $jar)
    if ($service.name -eq 'ai') {
        $arguments += '--spring.profiles.active=local'
    }

    $process = Start-Process -FilePath $java -ArgumentList $arguments -WorkingDirectory $root -RedirectStandardOutput $log -RedirectStandardError $errorLog -PassThru -WindowStyle Hidden
    $process.Id | Set-Content -LiteralPath $pidFile
    Write-Output "$($service.name): started (PID=$($process.Id), port=$portNum)"
}
