# IIOP teammate local configuration template.
# Copy this file to scripts/dev/local-secrets.ps1 and fill in local values.
# local-secrets.ps1 is ignored by Git. Do not commit real passwords or API keys.

$env:MYSQL_AUTH_USERNAME = "root"
$env:MYSQL_AUTH_PASSWORD = "CHANGE_ME"

$env:MYSQL_DEVICE_USERNAME = "root"
$env:MYSQL_DEVICE_PASSWORD = "CHANGE_ME"

$env:MYSQL_INSPECTION_USERNAME = "root"
$env:MYSQL_INSPECTION_PASSWORD = "CHANGE_ME"

$env:MYSQL_MAINTENANCE_USERNAME = "root"
$env:MYSQL_MAINTENANCE_PASSWORD = "CHANGE_ME"

$env:MYSQL_AI_USERNAME = "root"
$env:MYSQL_AI_PASSWORD = "CHANGE_ME"

$env:REDIS_PASSWORD = ""

$env:NACOS_SERVER_ADDR = "127.0.0.1:8848"
$env:NACOS_NAMESPACE = ""
$env:NACOS_GROUP = "IIOP_GROUP"
$env:ROCKETMQ_NAME_SERVER = "127.0.0.1:9876"

# Enable once on a fresh database to create the first SUPER_ADMIN account.
$env:IIOP_BOOTSTRAP_ADMIN_ENABLED = "true"
$env:IIOP_BOOTSTRAP_ADMIN_USERNAME = "superadmin"
$env:IIOP_BOOTSTRAP_ADMIN_PASSWORD = "CHANGE_ME_8_CHARS_MIN"

# Required only for real AI diagnosis.
$env:DEEPSEEK_API_KEY = "CHANGE_ME"
$env:DEEPSEEK_BASE_URL = "https://api.deepseek.com/v1"
$env:DEEPSEEK_MODEL = "deepseek-flash"
