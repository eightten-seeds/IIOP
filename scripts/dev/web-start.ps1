$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common.ps1')

$root = Get-IiopRoot
$web = Join-Path $root 'frontend\iiop-web'
$state = Join-Path (Get-IiopRuntimeRoot) 'web'
$npm = Get-IiopNpmCommand

New-Item -ItemType Directory -Force -Path $state | Out-Null
$pidFile = Join-Path $state 'dev.pid'
$logFile = Join-Path $state 'dev.log'

if (Test-Path -LiteralPath $pidFile) {
    $old = [int](Get-Content -LiteralPath $pidFile)
    if (Get-Process -Id $old -ErrorAction SilentlyContinue) {
        Write-Output 'dev already running'
        exit 0
    }
}

$webLiteral = ConvertTo-IiopPowerShellLiteral $web
$npmLiteral = ConvertTo-IiopPowerShellLiteral $npm
$logLiteral = ConvertTo-IiopPowerShellLiteral $logFile
$cmd = "Set-Location -LiteralPath $webLiteral; & $npmLiteral run dev -- --host 127.0.0.1 *> $logLiteral"

$p = Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',$cmd -PassThru -WindowStyle Hidden
$p.Id | Set-Content -LiteralPath $pidFile
Write-Output "dev started: $($p.Id)"
