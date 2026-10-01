# IIOP 开发环境: 安全 UTF-8 演示数据导入脚本
# 强制使用 --default-character-set=utf8mb4，并通过 mysql 客户端内置 source 命令直接读取 UTF-8 SQL 文件，
# 避免 PowerShell 文本管道转码导致中文乱码（Mojibake）。
$ErrorActionPreference = 'Stop'
$root = 'E:\IIOP'
$localSecrets = Join-Path $root 'scripts\dev\local-secrets.ps1'
if (Test-Path $localSecrets) { . $localSecrets }

$user = if ($env:MYSQL_AUTH_USERNAME) { $env:MYSQL_AUTH_USERNAME } else { 'root' }
$sqlFile = (Join-Path $root 'infra\sql\06_seed_data.sql').Replace('\', '/')

if (-not (Test-Path $sqlFile)) {
    throw "Missing seed SQL file: $sqlFile"
}

Write-Output "Executing UTF-8 seed import via mysql client..."
if ($env:MYSQL_AUTH_PASSWORD) {
    & mysql --default-character-set=utf8mb4 -u $user "-p$($env:MYSQL_AUTH_PASSWORD)" -h 127.0.0.1 -e "source $sqlFile"
} else {
    & mysql --default-character-set=utf8mb4 -u $user -h 127.0.0.1 -e "source $sqlFile"
}

if ($LASTEXITCODE -eq 0) {
    Write-Output "Database seed completed successfully with utf8mb4 character set."
} else {
    throw "Database seed failed with exit code $LASTEXITCODE"
}
