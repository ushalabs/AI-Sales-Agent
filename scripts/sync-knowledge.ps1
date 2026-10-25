# scripts/sync-knowledge.ps1
# Synchronize Knowledge Base into PostgreSQL from JSON fixtures / Google Sheets

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$jsonFile = Join-Path $ProjectRoot "data\knowledge_base.json"
if (-not (Test-Path $jsonFile)) {
    Write-Error "knowledge_base.json not found!"
    exit 1
}

$EnvLines = Get-Content .env
$dbUser = ($EnvLines | Where-Object { $_ -match '^POSTGRES_USER=(.*)$' } | ForEach-Object { $matches[1] }).Trim()
$dbName = ($EnvLines | Where-Object { $_ -match '^POSTGRES_DB=(.*)$' } | ForEach-Object { $matches[1] }).Trim()
if (-not $dbUser) { $dbUser = "n8n_db_user" }
if (-not $dbName) { $dbName = "n8n_sales_agent" }

Write-Host "Creating knowledge base tables..." -ForegroundColor Cyan
Get-Content (Join-Path $ProjectRoot "scripts\init-knowledge-db.sql") | docker compose exec -T postgres psql -U $dbUser -d $dbName | Out-Null

$kb = Get-Content $jsonFile -Raw | ConvertFrom-Json

Write-Host "Syncing $($kb.products.Count) products to PostgreSQL..." -ForegroundColor Yellow

# Truncate and insert cleanly
$sqlStatements = New-Object System.Text.StringBuilder
[void]$sqlStatements.AppendLine("BEGIN;")
[void]$sqlStatements.AppendLine("TRUNCATE TABLE inventory_products, shipping_rates, packing_fees, payment_methods, shop_policies RESTART IDENTITY;")

# Policies
[void]$sqlStatements.AppendLine("INSERT INTO shop_policies (policy_key, policy_value) VALUES ('delivery_days', '$($kb.shop_metadata.delivery_days)');")
[void]$sqlStatements.AppendLine("INSERT INTO shop_policies (policy_key, policy_value) VALUES ('courier', '$($kb.shop_metadata.shipment_courier)');")
[void]$sqlStatements.AppendLine("INSERT INTO shop_policies (policy_key, policy_value) VALUES ('payment_deadline', '$($kb.payment_rules.deadline)');")
[void]$sqlStatements.AppendLine("INSERT INTO shop_policies (policy_key, policy_value) VALUES ('payment_downpayment', '$($kb.payment_rules.downpayment)');")

# Payment Methods
foreach ($pm in $kb.payment_rules.methods) {
    [void]$sqlStatements.AppendLine("INSERT INTO payment_methods (method_name, account_number, account_name) VALUES ('$($pm.name)', '$($pm.account_number)', '$($pm.account_name)');")
}

# Shipping Rates
foreach ($prop in $kb.shipping_rates.PSObject.Properties) {
    $reg = $prop.Name
    $val = $prop.Value
    [void]$sqlStatements.AppendLine("INSERT INTO shipping_rates (region, small, medium, large) VALUES ('$reg', $($val.small), $($val.medium), $($val.large));")
}

# Packing Fees
foreach ($pf in $kb.packing_fees) {
    [void]$sqlStatements.AppendLine("INSERT INTO packing_fees (size, price_php, capacity, inclusions) VALUES ('$($pf.size)', $($pf.price_php), '$($pf.capacity)', '$($pf.inclusions)');")
}

# Products
foreach ($prod in $kb.products) {
    $m = $prod.member.Replace("'", "''")
    $p = $prod.product_name.Replace("'", "''")
    $n = if ($prod.notes) { $prod.notes.Replace("'", "''") } else { "" }
    $kw = "$m $p $n".ToLower()
    [void]$sqlStatements.AppendLine("INSERT INTO inventory_products (id, member, product_name, price_php, stock, notes, keywords) VALUES ($($prod.id), '$m', '$p', $($prod.price_php), $($prod.stock), '$n', '$kw');")
}

[void]$sqlStatements.AppendLine("COMMIT;")

$tempSql = Join-Path $ProjectRoot "backups\temp_sync.sql"
$sqlStatements.ToString() | Set-Content -Path $tempSql -Encoding utf8
Get-Content $tempSql | docker compose exec -T postgres psql -U $dbUser -d $dbName | Out-Null
Remove-Item $tempSql -Force

Write-Host "Knowledge Base synchronized successfully into PostgreSQL!" -ForegroundColor Green
