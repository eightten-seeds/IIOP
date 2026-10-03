. (Join-Path $PSScriptRoot '..\common.ps1')
$state = Join-Path (Get-IiopRuntimeRoot) 'web'
$pidFile = Join-Path $state 'dev.pid'

if (-not (Test-Path -LiteralPath $pidFile)) {
    Write-Output 'dev not started'
    exit 0
}

$id = [int](Get-Content -LiteralPath $pidFile)
$p = Get-Process -Id $id -ErrorAction SilentlyContinue
if ($p) {
    Stop-Process -Id $id -Force
    Write-Output 'dev stopped'
} else {
    Write-Output 'dev already stopped'
}
Remove-Item -LiteralPath $pidFile -Force
