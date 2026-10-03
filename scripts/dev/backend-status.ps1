. (Join-Path $PSScriptRoot '..\common.ps1')
$state = Join-Path (Get-IiopRuntimeRoot) 'backend'
$services = @(
    @{name='gateway';port=8080},
    @{name='auth';port=9201},
    @{name='device';port=9202},
    @{name='inspection';port=9203},
    @{name='maintenance';port=9204},
    @{name='ai';port=9205}
)

foreach ($service in $services) {
    $pidFile = Join-Path $state "$($service.name).pid"
    $running = $false
    if (Test-Path -LiteralPath $pidFile) {
        $running = $null -ne (Get-Process -Id ([int](Get-Content -LiteralPath $pidFile)) -ErrorAction SilentlyContinue)
    }
    $portOpen = $null -ne (Get-NetTCPConnection -LocalPort $service.port -State Listen -ErrorAction SilentlyContinue)
    $status = if ($running -and $portOpen) { 'RUNNING' } else { 'STOPPED' }
    $portStatus = if ($portOpen) { 'LISTENING' } else { 'CLOSED' }
    Write-Output "$($service.name): $status (port $($service.port): $portStatus)"
}
Write-Output "logs: $state"
