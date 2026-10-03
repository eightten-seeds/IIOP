. (Join-Path $PSScriptRoot '..\common.ps1')
$state = Join-Path (Get-IiopRuntimeRoot) 'web'

function Get-TaskStatus($name) {
    $pidFile = Join-Path $state "$name.pid"
    $exitFile = Join-Path $state "$name.exit"
    if (Test-Path -LiteralPath $pidFile) {
        $processId = [int](Get-Content -LiteralPath $pidFile)
        if (Get-Process -Id $processId -ErrorAction SilentlyContinue) { return 'RUNNING' }
    }
    if (Test-Path -LiteralPath $exitFile) {
        if ((Get-Content -LiteralPath $exitFile -Raw).Trim() -eq '0') { return 'SUCCESS' }
        return 'FAILED'
    }
    return 'NOT_STARTED'
}

Write-Output "install: $(Get-TaskStatus install)"
Write-Output "build: $(Get-TaskStatus build)"

$devPidFile = Join-Path $state 'dev.pid'
$dev = 'STOPPED'
if (Test-Path -LiteralPath $devPidFile) {
    $processId = [int](Get-Content -LiteralPath $devPidFile)
    if (Get-Process -Id $processId -ErrorAction SilentlyContinue) { $dev = 'RUNNING' }
}

Write-Output "dev: $dev"
Write-Output "logs: $state"
