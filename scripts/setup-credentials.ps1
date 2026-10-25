# scripts/setup-credentials.ps1
# Imports the local postgres credential into n8n using n8n CLI

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$envLines = Get-Content .env
$pgPass = ($envLines | Where-Object { $_ -match "^POSTGRES_PASSWORD=(.*)$" } | ForEach-Object { $matches[1] }).Trim()
if (-not $pgPass) {
    $pgPass = ($envLines | Where-Object { $_ -match "^DB_POSTGRESDB_PASSWORD=(.*)$" } | ForEach-Object { $matches[1] }).Trim()
}

$cred = @(
    @{
        id = "postgres-sales-agent"
        name = "Postgres account"
        type = "postgres"
        data = @{
            host = "postgres"
            database = "n8n_sales_agent"
            user = "n8n_db_user"
            password = $pgPass
            port = 5432
            ssl = "disable"
        }
    }
)

$json = "[" + ($cred | ConvertTo-Json -Depth 5) + "]"
$tempFile = [System.IO.Path]::GetTempFileName()
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tempFile, $json, $utf8NoBom)

docker cp $tempFile sales_agent_n8n:/tmp/pg_cred.json
Remove-Item -Force $tempFile

# Execute import in n8n
docker compose exec -T -u node n8n n8n import:credentials --input=/tmp/pg_cred.json --projectId=EVbKmAuf1FuhDRjk
docker compose exec -T -u 0 n8n rm -f /tmp/pg_cred.json

Write-Host "Postgres credential imported successfully!" -ForegroundColor Green
