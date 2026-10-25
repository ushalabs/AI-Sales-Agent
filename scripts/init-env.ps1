# scripts/init-env.ps1
# Initialize or configure the local .env file securely

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$EnvFile = Join-Path $ProjectRoot ".env"
$EnvExampleFile = Join-Path $ProjectRoot ".env.example"

if (-not (Test-Path $EnvExampleFile)) {
    Write-Error ".env.example not found!"
    exit 1
}

function Generate-RandomHex([int]$bytes) {
    $buffer = New-Object byte[] $bytes
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($buffer)
    return -join ($buffer | ForEach-Object { '{0:x2}' -f $_ })
}

Write-Host "Checking environment configuration..." -ForegroundColor Cyan

# Read existing .env if present
$existingLines = @()
if (Test-Path $EnvFile) {
    $existingLines = Get-Content $EnvFile
    Write-Host "Found existing .env file. Preserving existing keys." -ForegroundColor Yellow
} else {
    $existingLines = Get-Content $EnvExampleFile
    Write-Host "Created new .env file from .env.example." -ForegroundColor Green
}

# Generate secure tokens if not already configured or placeholder
$encryptionMatch = $existingLines | Where-Object { $_ -match '^N8N_ENCRYPTION_KEY=(.*)$' }
$encryptionKey = if ($encryptionMatch) { ($encryptionMatch -replace '^N8N_ENCRYPTION_KEY=', '').Trim() } else { $null }

if ([string]::IsNullOrWhiteSpace($encryptionKey) -or $encryptionKey -like "*replace*") {
    $newEncryptionKey = Generate-RandomHex 32
    if ($encryptionMatch) {
        $existingLines = $existingLines | ForEach-Object {
            if ($_ -match '^N8N_ENCRYPTION_KEY=') { "N8N_ENCRYPTION_KEY=$newEncryptionKey" } else { $_ }
        }
    } else {
        $existingLines += "N8N_ENCRYPTION_KEY=$newEncryptionKey"
    }
    Write-Host "Generated persistent N8N_ENCRYPTION_KEY." -ForegroundColor Green
}

$pgMatch = $existingLines | Where-Object { $_ -match '^POSTGRES_PASSWORD=(.*)$' }
$pgPassword = if ($pgMatch) { ($pgMatch -replace '^POSTGRES_PASSWORD=', '').Trim() } else { $null }

if ([string]::IsNullOrWhiteSpace($pgPassword) -or $pgPassword -like "*replace*") {
    $newPgPassword = Generate-RandomHex 16
    if ($pgMatch) {
        $existingLines = $existingLines | ForEach-Object {
            if ($_ -match '^POSTGRES_PASSWORD=') { "POSTGRES_PASSWORD=$newPgPassword" }
            elseif ($_ -match '^DB_POSTGRESDB_PASSWORD=') { "DB_POSTGRESDB_PASSWORD=$newPgPassword" }
            else { $_ }
        }
    } else {
        $existingLines += "POSTGRES_PASSWORD=$newPgPassword"
        $existingLines += "DB_POSTGRESDB_PASSWORD=$newPgPassword"
    }
    Write-Host "Generated secure PostgreSQL database password." -ForegroundColor Green
}

# Ensure other required defaults exist
$requiredDefaults = [ordered]@{
    "N8N_IMAGE_TAG" = "2.44.6"
    "POSTGRES_IMAGE_TAG" = "16-alpine"
    "POSTGRES_DB" = "n8n_sales_agent"
    "POSTGRES_USER" = "n8n_db_user"
    "DB_TYPE" = "postgresdb"
    "DB_POSTGRESDB_HOST" = "postgres"
    "DB_POSTGRESDB_PORT" = "5432"
    "DB_POSTGRESDB_DATABASE" = "n8n_sales_agent"
    "DB_POSTGRESDB_USER" = "n8n_db_user"
    "N8N_HOST" = "127.0.0.1"
    "N8N_PORT" = "5678"
    "N8N_PROTOCOL" = "http"
    "WEBHOOK_URL" = "http://127.0.0.1:5678/"
    "GENERIC_TIMEZONE" = "Asia/Manila"
    "TZ" = "Asia/Manila"
    "EXECUTIONS_DATA_PRUNE" = "true"
    "EXECUTIONS_DATA_MAX_AGE" = "168"
    "EXECUTIONS_DATA_PRUNE_MAX_COUNT" = "50000"
    "EXECUTIONS_DATA_SAVE_ON_ERROR" = "all"
    "EXECUTIONS_DATA_SAVE_ON_SUCCESS" = "all"
    "EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS" = "true"
}

foreach ($entry in $requiredDefaults.GetEnumerator()) {
    $key = $entry.Key
    $val = $entry.Value
    if (-not ($existingLines -match "^$key=")) {
        $existingLines += "$key=$val"
    }
}

$existingLines | Set-Content -Path $EnvFile -Encoding utf8
Write-Host "Environment initialization complete (.env ready)." -ForegroundColor Green
