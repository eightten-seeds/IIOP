$ErrorActionPreference = 'Stop'
$root='E:\IIOP'; $web=Join-Path $root 'frontend\iiop-web'; $state='E:\IIOP-data\dev\web'
New-Item -ItemType Directory -Force -Path $state | Out-Null
$pidFile=Join-Path $state 'install.pid'; $exitFile=Join-Path $state 'install.exit'
if(Test-Path $pidFile){$old=[int](Get-Content $pidFile);if(Get-Process -Id $old -ErrorAction SilentlyContinue){Write-Output 'install already running';exit 0}}
Remove-Item $exitFile -Force -ErrorAction SilentlyContinue
$cmd="Set-Location '$web'; `$env:npm_config_cache='E:\DevCache\npm'; npm install --cache E:\DevCache\npm *> '$state\install.log'; `$LASTEXITCODE | Set-Content '$exitFile'"
$p=Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',$cmd -PassThru -WindowStyle Hidden
$p.Id | Set-Content $pidFile; Write-Output "install started: $($p.Id)"
