# scripts/register-webhook.ps1
# Register and verify Telegram Webhook for Business Events

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$EnvLines = Get-Content .env
$botToken = ($EnvLines | Where-Object { $_ -match '^TELEGRAM_BOT_TOKEN=(.*)$' } | ForEach-Object { $matches[1] }).Trim()
$webhookUrl = ($EnvLines | Where-Object { $_ -match '^WEBHOOK_URL=(.*)$' } | ForEach-Object { $matches[1] }).Trim()
$secretToken = ($EnvLines | Where-Object { $_ -match '^TELEGRAM_WEBHOOK_SECRET=(.*)$' } | ForEach-Object { $matches[1] }).Trim()

if ([string]::IsNullOrWhiteSpace($botToken) -or $botToken -eq "your_telegram_bot_token_here") {
    Write-Warning "TELEGRAM_BOT_TOKEN is not set in .env! Please set your bot token before registering the webhook."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($webhookUrl) -or $webhookUrl -like "*127.0.0.1*" -or $webhookUrl -like "*localhost*") {
    Write-Warning "WEBHOOK_URL is currently pointing to localhost ($webhookUrl). Telegram requires a public HTTPS URL."
    Write-Host "Please run ./scripts/start-tunnel.ps1 to generate a public Cloudflare tunnel first." -ForegroundColor Yellow
    exit 1
}

# Ensure webhook path matches the workflow webhook path
$fullWebhookUrl = "$($webhookUrl.TrimEnd('/'))/webhook/telegram-business"

Write-Host "Registering Telegram Webhook..." -ForegroundColor Cyan
Write-Host "Target URL: $fullWebhookUrl" -ForegroundColor Cyan

$allowedUpdates = @(
    "business_connection",
    "business_message",
    "edited_business_message",
    "message"
)

$payload = @{
    url = $fullWebhookUrl
    allowed_updates = $allowedUpdates
    drop_pending_updates = $true
}

if (-not [string]::IsNullOrWhiteSpace($secretToken) -and $secretToken -notlike "*replace*") {
    $payload["secret_token"] = $secretToken
    Write-Host "Secret token verification: ENABLED" -ForegroundColor Green
} else {
    Write-Warning "TELEGRAM_WEBHOOK_SECRET is not configured. Webhook will register without secret token."
}

$apiUrl = "https://api.telegram.org/bot$botToken/setWebhook"

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body ($payload | ConvertTo-Json -Depth 5) -ContentType "application/json"
    if ($response.ok -eq $true) {
        Write-Host "Telegram Webhook registered successfully!" -ForegroundColor Green
        Write-Host "Description: $($response.description)" -ForegroundColor Green
    } else {
        Write-Host "Failed to register webhook: $($response.description)" -ForegroundColor Red
        exit 1
    }

    # Verify Webhook Info
    $infoUrl = "https://api.telegram.org/bot$botToken/getWebhookInfo"
    $info = Invoke-RestMethod -Uri $infoUrl -Method Get
    Write-Host "`n--- Current Telegram Webhook Info ---" -ForegroundColor Cyan
    Write-Host "URL:                      $($info.result.url)"
    Write-Host "Custom Certificate:       $($info.result.has_custom_certificate)"
    Write-Host "Pending Update Count:     $($info.result.pending_update_count)"
    Write-Host "Allowed Updates:          $(($info.result.allowed_updates) -join ', ')"
    if ($info.result.last_error_message) {
        Write-Host "Last Error Message:       $($info.result.last_error_message)" -ForegroundColor Red
    }
} catch {
    Write-Host "Error communicating with Telegram Bot API: $_" -ForegroundColor Red
    exit 1
}
