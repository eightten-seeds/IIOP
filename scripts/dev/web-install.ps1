$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common.ps1')

$root = Get-IiopRoot
$web = Join-Path $root 'frontend\iiop-web'
$state = Join-Path (Get-IiopRuntimeRoot) 'web'
$npm = Get-IiopNpmCommand

New-Item -ItemType Directory -Force -Path $state | Out-Null
$pidFile = Join-Path $state 'install.pid'
$exitFile = Join-Path $state 'install.exit'
$logFile = Join-Path $state 'install.log'

if (Test-Path -LiteralPath $pidFile) {
    $old = [int](Get-Content -LiteralPath $pidFile)
    if (Get-Process -Id $old -ErrorAction SilentlyContinue) {
        Write-Output 'install already running'
        exit 0
    }
}

Remove-Item -LiteralPath $exitFile -Force -ErrorAction SilentlyContinue

$webLiteral = ConvertTo-IiopPowerShellLiteral $web
$npmLiteral = ConvertTo-IiopPowerShellLiteral $npm
$logLiteral = ConvertTo-IiopPowerShellLiteral $logFile
$exitLiteral = ConvertTo-IiopPowerShellLiteral $exitFile
$cacheArg = ''
if ($env:NPM_CONFIG_CACHE) {
    $cacheLiteral = ConvertTo-IiopPowerShellLiteral $env:NPM_CONFIG_CACHE
    $cacheArg = " --cache $cacheLiteral"
}

$cmd = "Set-Location -LiteralPath $webLiteral; & $npmLiteral install$cacheArg *> $logLiteral; `$LASTEXITCODE | Set-Content -LiteralPath $exitLiteral"
$p = Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',$cmd -PassThru -WindowStyle Hidden
$p.Id | Set-Content -LiteralPath $pidFile
Write-Output "install started: $($p.Id)"
