# IIOP 开发环境：安全 UTF-8 演示数据导入脚本。
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common.ps1')

$root = Get-IiopRoot
$user = if ($env:MYSQL_AUTH_USERNAME) { $env:MYSQL_AUTH_USERNAME } else { 'root' }
$hostName = if ($env:MYSQL_HOST) { $env:MYSQL_HOST } else { '127.0.0.1' }
$port = if ($env:MYSQL_PORT) { $env:MYSQL_PORT } else { '3306' }
$sqlFile = (Join-Path $root 'infra\sql\06_seed_data.sql').Replace('\', '/')
$mysql = Resolve-IiopExecutable -CommandNames @('mysql.exe', 'mysql')

if (-not $mysql) {
    throw 'mysql client was not found. Install MySQL client and add mysql to PATH.'
}
if (-not (Test-Path -LiteralPath $sqlFile)) {
    throw "Missing seed SQL file: $sqlFile"
}

Write-Output "Executing UTF-8 seed import via mysql client..."
$hadPwd = Test-Path Env:\MYSQL_PWD
$origPwd = if ($hadPwd) { $env:MYSQL_PWD } else { $null }

try {
    if ($env:MYSQL_AUTH_PASSWORD) {
        $env:MYSQL_PWD = $env:MYSQL_AUTH_PASSWORD
    }
    & $mysql --default-character-set=utf8mb4 -u $user -h $hostName -P $port -e "source $sqlFile"
    $exitCode = $LASTEXITCODE
} finally {
    if ($hadPwd) {
        $env:MYSQL_PWD = $origPwd
    } else {
        Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue
    }
}

if ($exitCode -eq 0) {
    Write-Output 'Database seed completed successfully with utf8mb4 character set.'
} else {
    throw "Database seed failed with exit code $exitCode"
}
