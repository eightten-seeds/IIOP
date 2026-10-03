$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common.ps1')

$root = Get-IiopRoot
$web = Join-Path $root 'frontend\iiop-web'
$state = Join-Path (Get-IiopRuntimeRoot) 'web'
$npm = Get-IiopNpmCommand

New-Item -ItemType Directory -Force -Path $state | Out-Null
$pidFile = Join-Path $state 'build.pid'
$exitFile = Join-Path $state 'build.exit'
$logFile = Join-Path $state 'build.log'

if (Test-Path -LiteralPath $pidFile) {
    $old = [int](Get-Content -LiteralPath $pidFile)
    if (Get-Process -Id $old -ErrorAction SilentlyContinue) {
        Write-Output 'build already running'
        exit 0
    }
}

Remove-Item -LiteralPath $exitFile -Force -ErrorAction SilentlyContinue

$webLiteral = ConvertTo-IiopPowerShellLiteral $web
$npmLiteral = ConvertTo-IiopPowerShellLiteral $npm
$logLiteral = ConvertTo-IiopPowerShellLiteral $logFile
$exitLiteral = ConvertTo-IiopPowerShellLiteral $exitFile
$cmd = "Set-Location -LiteralPath $webLiteral; & $npmLiteral run build *> $logLiteral; `$LASTEXITCODE | Set-Content -LiteralPath $exitLiteral"

$p = Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',$cmd -PassThru -WindowStyle Hidden
$p.Id | Set-Content -LiteralPath $pidFile
Write-Output "build started: $($p.Id)"
