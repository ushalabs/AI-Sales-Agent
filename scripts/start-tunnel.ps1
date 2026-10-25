# scripts/start-tunnel.ps1
# Start Cloudflare Quick Tunnel and configure n8n WEBHOOK_URL

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " STARTING CLOUDFLARE QUICK TUNNEL & WEBHOOK PROXY " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Start proxy and cloudflared containers
Write-Host "`n[1/4] Starting webhook_proxy and cloudflared containers..." -ForegroundColor Yellow
docker compose up -d webhook_proxy cloudflared

# 2. Poll for the assigned trycloudflare.com URL
Write-Host "[2/4] Waiting for Cloudflare Quick Tunnel assignment..." -ForegroundColor Yellow
$tunnelUrl = $null
$maxRetries = 25
$retry = 0

while (-not $tunnelUrl -and $retry -lt $maxRetries) {
    Start-Sleep -Seconds 2
    $retry++
    $logs = docker compose logs cloudflared 2>&1
    if ($logs -match 'https://[a-zA-Z0-9-]+\.trycloudflare\.com') {
        $tunnelUrl = $matches[0]
    }
}

if (-not $tunnelUrl) {
    Write-Error "Failed to obtain Cloudflare Tunnel URL. Check logs: docker compose logs cloudflared"
    exit 1
}

Write-Host "Assigned Tunnel URL: $tunnelUrl" -ForegroundColor Green

# 3. Update WEBHOOK_URL in .env
Write-Host "`n[3/4] Updating WEBHOOK_URL in .env..." -ForegroundColor Yellow
$formattedUrl = "$($tunnelUrl.TrimEnd('/'))/"
$envLines = Get-Content .env
$hasWebhookUrl = $false

$updatedLines = $envLines | ForEach-Object {
    if ($_ -match '^WEBHOOK_URL=') {
        $hasWebhookUrl = $true
        "WEBHOOK_URL=$formattedUrl"
    } else {
        $_
    }
}

if (-not $hasWebhookUrl) {
    $updatedLines += "WEBHOOK_URL=$formattedUrl"
}

$updatedLines | Set-Content -Path .env -Encoding utf8
Write-Host "WEBHOOK_URL set to $formattedUrl" -ForegroundColor Green

# 4. Restart n8n to apply the updated WEBHOOK_URL
Write-Host "`n[4/4] Restarting n8n to apply WEBHOOK_URL configuration..." -ForegroundColor Yellow
docker compose up -d n8n

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host " CLOUDFLARE TUNNEL INITIALIZATION COMPLETE!       " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Public Webhook URL: $tunnelUrl/webhook/telegram-business" -ForegroundColor Cyan
Write-Host "Security:           Direct root access ($tunnelUrl/) is blocked (403 Forbidden)" -ForegroundColor Green
Write-Host "Local n8n Editor:   Accessible at http://127.0.0.1:5678" -ForegroundColor Green
Write-Host "`nIMPORTANT: Because this is an ephemeral quick tunnel, the URL changes on restart." -ForegroundColor Yellow
Write-Host "To register this new URL with Telegram, run: ./scripts/register-webhook.ps1" -ForegroundColor Yellow
