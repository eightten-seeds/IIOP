$ErrorActionPreference = 'Stop'

$root = 'E:\IIOP'
$localSecrets = Join-Path $root 'scripts\dev\local-secrets.ps1'
if (Test-Path $localSecrets) { . $localSecrets }
$state = 'E:\IIOP-data\dev\backend'
$java = Join-Path $env:JAVA_HOME 'bin\java.exe'
if (-not (Test-Path $java)) { throw 'JAVA_HOME must point to a JDK with bin\java.exe' }
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
        $wmi = Get-WmiObject Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
        if ($wmi) { return $wmi.CommandLine } else { return '' }
    } catch {
        return ''
    }
}

function Get-PortOwnerPid([int]$Port) {
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($conn) { return $conn.OwningProcess } else { return $null }
}

foreach ($service in $services) {
    $pidFile    = Join-Path $state "$($service.name).pid"
    $jar        = Join-Path $root "backend\$($service.module)\target\$($service.module)-1.0.0-SNAPSHOT.jar"
    $log        = Join-Path $state "$($service.name).log"
    $errorLog   = Join-Path $state "$($service.name).err.log"
    $moduleName = $service.module
    $portNum    = $service.port

    # Read stored PID (avoid shadowing $pid automatic variable)
    $storedPid  = $null
    if (Test-Path $pidFile) {
        $storedPid = [int](Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue)
    }

    $portListening = Test-TcpPort $portNum

    # Determine actual process for stored PID
    $storedProc    = if ($storedPid) { Get-Process -Id $storedPid -ErrorAction SilentlyContinue } else { $null }
    $storedCmdLine = if ($storedProc) { Get-ProcessCmdLine $storedPid } else { '' }
    $storedIsIiop  = $storedCmdLine -match [regex]::Escape($moduleName)

    # CASE B: pid exists + pid process alive + it's our IIOP service + port LISTEN -> SKIP
    if ($storedPid -and $storedProc -and $storedIsIiop -and $portListening) {
        Write-Output "$($service.name): already running (PID=$storedPid, port=$portNum)"
        continue
    }

    # CASE C: pid file exists but PID process does not exist -> stale pid file
    if ($storedPid -and -not $storedProc) {
        Write-Output "$($service.name): stale PID file (PID=$storedPid not found); removing"
        Remove-Item -LiteralPath $pidFile -Force
        $storedPid = $null
    }

    # CASE D: pid file exists + PID alive + confirmed IIOP service + port NOT listening
    # OR: pid file exists + PID alive + NOT our service (wrong process owns the PID)
    if ($storedPid -and $storedProc) {
        if ($storedIsIiop -and -not $portListening) {
            Write-Output "$($service.name): stale/failed IIOP process (PID=$storedPid, $moduleName alive but port $portNum not listening); stopping"
            Stop-Process -Id $storedPid -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
            $storedPid = $null
        } elseif (-not $storedIsIiop) {
            # PID file points to unrelated process - just remove the stale file, don't kill unrelated process
            Write-Output "$($service.name): PID file points to unrelated process (PID=$storedPid, Name=$($storedProc.Name)); removing stale file"
            Remove-Item -LiteralPath $pidFile -Force
            $storedPid = $null
        }
    }

    # CASE E: port is already listening but we have no valid PID
    if ($portListening) {
        $ownerPid = Get-PortOwnerPid $portNum
        if ($ownerPid) {
            $ownerCmdLine = Get-ProcessCmdLine $ownerPid
            $ownerIsIiop  = $ownerCmdLine -match [regex]::Escape($moduleName)
            if ($ownerIsIiop) {
                # Port is ours - rebuild the PID file and skip
                Write-Output "$($service.name): port $portNum already listening by IIOP process (PID=$ownerPid); rebuilding PID file"
                $ownerPid | Set-Content -LiteralPath $pidFile
                continue
            } else {
                $ownerName = (Get-Process -Id $ownerPid -ErrorAction SilentlyContinue).Name
                Write-Output "ERROR: PORT $portNum OCCUPIED BY UNEXPECTED PROCESS"
                Write-Output "  PID: $ownerPid"
                Write-Output "  ProcessName: $ownerName"
                Write-Output "  CommandLine: $ownerCmdLine"
                throw "Port $portNum is occupied by unexpected process PID=$ownerPid ($ownerName). Cannot start $($service.name)."
            }
        }
    }

    # CASE A: port not listening, no stale pid -> normal start
    if (-not (Test-Path $jar)) { throw "Missing built jar: $jar" }
    $extraArg = if ($service.name -eq 'ai') { ' --spring.profiles.active=local' } else { '' }
    $cmdLine = "`"$java`" -jar `"$jar`"$extraArg 1>`"$log`" 2>`"$errorLog`""
    $fullCmd = "cmd.exe /c `"$cmdLine`""
    $wmi = [wmiclass]"win32_process"
    $res = $wmi.Create($fullCmd, $root, $null)
    if ($res.ReturnValue -ne 0) { throw "Failed to start $($service.name) via WMI: code $($res.ReturnValue)" }
    $wrapperPid = $res.ProcessId
    $actualPid = $wrapperPid
    $deadline = (Get-Date).AddSeconds(5)
    do {
        $children = Get-WmiObject Win32_Process -Filter "ParentProcessId=$wrapperPid" -ErrorAction SilentlyContinue
        $javaProc = $children | Where-Object { $_.Name -eq 'java.exe' } | Select-Object -First 1
        if ($javaProc) { $actualPid = $javaProc.ProcessId; break }
        Start-Sleep -Milliseconds 200
    } while ((Get-Date) -lt $deadline)
    $actualPid | Set-Content -LiteralPath $pidFile
    Write-Output "$($service.name): started (PID=$actualPid, port=$portNum)"
}
