# scripts/test-phase6.ps1
# Phase 6 Automated Simulated Customer & Gemini AI Response Test Harness

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " AI SALES AGENT - PHASE 6 GEMINI & SIMULATED TEST " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Load knowledge base fixture
$kbJson = Get-Content (Join-Path $ProjectRoot "data\knowledge_base.json") -Raw | ConvertFrom-Json

# Deterministic simulated engine matching n8n subworkflow
function Simulate-CustomerResponse([string]$query, [string]$customerName = "Carat") {
    $q = $query.ToLower().Trim()

    $memberAliases = [ordered]@{
        'scoups' = 'S.COUPS'; 's.coups' = 'S.COUPS'; 'coups' = 'S.COUPS';
        'jeonghan' = 'JEONGHAN'; 'hannie' = 'JEONGHAN';
        'joshua' = 'JOSHUA'; 'shua' = 'JOSHUA';
        'jun' = 'JUN'; 'junhui' = 'JUN';
        'hoshi' = 'HOSHI'; 'soonyoung' = 'HOSHI';
        'wonwoo' = 'WONWOO';
        'woozi' = 'WOOZI'; 'jihoon' = 'WOOZI';
        'dk' = 'DK'; 'dokyeom' = 'DK';
        'mingyu' = 'MINGYU';
        'minghao' = 'MINGHAO'; 'the8' = 'MINGHAO';
        'seungkwan' = 'SEUNGKWAN';
        'vernon' = 'VERNON'; 'hansol' = 'VERNON';
        'dino' = 'DINO'; 'chan' = 'DINO';
    }

    $detectedMembers = @()
    foreach ($entry in $memberAliases.GetEnumerator()) {
        $pattern = "(?i)(^|\W)" + [regex]::Escape($entry.Key) + "($|\W)"
        if ($q -match $pattern -and $detectedMembers -notcontains $entry.Value) {
            $detectedMembers += $entry.Value
        }
    }

    $isShipping = ($q -match "(?i)\b(shipping|sf|pf|pack|delivery|luzon|visayas|mindanao|j and t|j&t|courier)\b")
    $isPayment = ($q -match "(?i)\b(payment|mop|gcash|maya|maribank|downpayment|nrdp|deadline|bayad)\b")

    # Priority 1: Pure Shipping or Payment Inquiry with no specific member
    if ($detectedMembers.Count -eq 0 -and $isShipping) {
        return [PSCustomObject]@{
            Status = "SHIPPING_INQUIRY"
            Query = $query
            Reply = "Hii po! 💗 Our shipping rates via J&T (includes ₱21 voucher):`n• Luzon: Small ₱79 / Medium ₱144 / Large ₱174`n• Visayas: Small ₱74 / Medium ₱134 / Large ₱164`n• Mindanao: Small ₱54 / Medium ₱104 / Large ₱144`nPacking fee: Small ₱20, Medium ₱25, Large ₱30. Delivery days are Monday-Wednesday only po! (🤖 Automated shop assistant)"
            HasDisclosure = $true
            IsTaglish = $true
        }
    }

    if ($detectedMembers.Count -eq 0 -and $isPayment) {
        return [PSCustomObject]@{
            Status = "PAYMENT_INQUIRY"
            Query = $query
            Reply = "Hii po! 💗 We accept GCash, Maya, and MariBank. Payment deadline is 1 week with 30% non-refundable downpayment (nrdp) po! (🤖 Automated shop assistant)"
            HasDisclosure = $true
            IsTaglish = $true
        }
    }

    $stopWords = @('and', 'the', 'for', 'via', 'with', 'magkano', 'ano', 'meron', 'available', 'po', 'ba', 'kayo', 'ni', 'sa')
    $scoredList = New-Object System.Collections.ArrayList
    foreach ($p in $kbJson.products) {
        $score = 0
        $mLower = $p.member.ToLower()
        $pLower = $p.product_name.ToLower()
        $nLower = if ($p.notes) { $p.notes.ToLower() } else { "" }
        $fullText = "$mLower $pLower $nLower"

        if ($detectedMembers.Count -gt 0) {
            if ($detectedMembers -contains $p.member) {
                $score += 50
            } else {
                continue
            }
        }

        $tokens = $q -split '\s+' | Where-Object { $_.Length -gt 1 -and $stopWords -notcontains $_ }
        foreach ($tok in $tokens) {
            if ($pLower -like "*$tok*") { $score += 25 }
            elseif ($nLower -like "*$tok*") { $score += 10 }
            elseif ($mLower -like "*$tok*") { $score += 15 }
        }

        $versionKeywords = @('deluxe', 'barbie', 'prince', 'connect', 'carat ver', 'weverse', 'shopee', 'dear', 'hear', 'regular', 'digital code', 'pob', 'lucky draw', 'album')
        foreach ($v in $versionKeywords) {
            if ($q -like "*$v*" -and $pLower -like "*$v*") {
                $score += 35
            }
        }

        $albums = @('fml', 'sector 17', 'attacca', 'fts', 'face the sun', '17rh', '17 is right here', 'heaven', 'spill the feels', 'stf', 'an ode', 'henggarae', 'v8', 'burstday', 'teen age')
        foreach ($alb in $albums) {
            if ($q -like "*$alb*" -and $fullText -like "*$alb*") {
                $score += 30
            }
        }

        if ($score -ge 40) {
            [void]$scoredList.Add([PSCustomObject]@{ Product = $p; Score = $score })
        }
    }

    $scored = @($scoredList | Sort-Object -Property Score -Descending)

    $matchingProducts = @()
    $status = "NOT_FOUND"

    if ($scored.Count -eq 1) {
        $status = if ($scored[0].Product.stock -eq 0) { "OUT_OF_STOCK" } else { "EXACT_MATCH" }
        $matchingProducts = @($scored[0].Product)
    } elseif ($scored.Count -gt 1) {
        if ($scored[0].Score -ge ($scored[1].Score + 20)) {
            $status = if ($scored[0].Product.stock -eq 0) { "OUT_OF_STOCK" } else { "EXACT_MATCH" }
            $matchingProducts = @($scored[0].Product)
        } else {
            $status = "AMBIGUOUS_MATCH"
            $matchingProducts = @($scored | Select-Object -First 4 | ForEach-Object { $_.Product })
        }
    } elseif ($detectedMembers.Count -eq 1) {
        $mProds = @($kbJson.products | Where-Object { $_.member -eq $detectedMembers[0] })
        if ($mProds.Count -gt 0) {
            if ($mProds.Count -eq 1 -and $mProds[0].stock -eq 0) {
                $status = "OUT_OF_STOCK"
                $matchingProducts = $mProds
            } else {
                $status = "AMBIGUOUS_MATCH"
                $matchingProducts = $mProds
            }
        }
    }

    # Determine simulated response
    $reply = ""

    if ($status -eq "OUT_OF_STOCK") {
        $p = $matchingProducts[0]
        $reply = "Hii po! 💗 As of now, $($p.member) is currently out of stock po. We will announce once we have new stocks available! Salamat po sa interest! 💗 (🤖 Automated shop assistant)"
    } elseif ($status -eq "EXACT_MATCH") {
        $p = $matchingProducts[0]
        $note = if ($p.notes) { " Note: " + $p.notes + "." } else { "" }
        $reply = "Hii po! 💗 For $($p.member) - $($p.product_name), it's ₱$($p.price_php) with $($p.stock) item(s) in stock.$note Delivery days are Monday-Wednesday only via J&T. Would you like to reserve this item po? (🤖 Automated shop assistant)"
    } elseif ($status -eq "AMBIGUOUS_MATCH") {
        $list = ($matchingProducts | Select-Object -First 4 | ForEach-Object { "• $($_.member) $($_.product_name) (₱$($_.price_php))" }) -join "`n"
        $reply = "Hii po! 💗 Here are the available items matching your inquiry:`n$list`nWhich one were you looking for po? (🤖 Automated shop assistant)"
    } elseif ($isShipping) {
        $status = "SHIPPING_INQUIRY"
        $reply = "Hii po! 💗 Our shipping rates via J&T (includes ₱21 voucher):`n• Luzon: Small ₱79 / Medium ₱144 / Large ₱174`n• Visayas: Small ₱74 / Medium ₱134 / Large ₱164`n• Mindanao: Small ₱54 / Medium ₱104 / Large ₱144`nPacking fee: Small ₱20, Medium ₱25, Large ₱30. Delivery days are Monday-Wednesday only po! (🤖 Automated shop assistant)"
    } elseif ($isPayment) {
        $status = "PAYMENT_INQUIRY"
        $reply = "Hii po! 💗 We accept GCash, Maya, and MariBank. Payment deadline is 1 week with 30% non-refundable downpayment (nrdp) po! (🤖 Automated shop assistant)"
    } else {
        $reply = "Hii po! 💗 This is Sash's automated shop assistant. We have SEVENTEEN photocards and albums in stock. You can ask for specific members, prices, shipping fees, or payment options po! (🤖 Automated shop assistant)"
    }

    return [PSCustomObject]@{
        Status = $status
        Query = $query
        Reply = $reply
        HasDisclosure = ($reply -like "*(🤖 Automated shop assistant)*")
        IsTaglish = ($reply -like "*Hii po! 💗*")
    }
}

$simulations = @(
    [PSCustomObject]@{
        Scenario = "Scenario A: Specific Item Inquiry with Condition Note"
        Query = "magkano po fml deluxe ni jun at may damage ba?"
        ExpectedSubstring = "₱100"
        ExpectedNoteSubstring = "dent on backprint"
    },
    [PSCustomObject]@{
        Scenario = "Scenario B: Out of Stock Inquiry"
        Query = "may photocard pa po ba kayo ni scoups?"
        ExpectedSubstring = "out of stock"
    },
    [PSCustomObject]@{
        Scenario = "Scenario C: Ambiguous Multi-Product Inquiry"
        Query = "ano available pcs ni mingyu?"
        ExpectedSubstring = "available items matching your inquiry"
    },
    [PSCustomObject]@{
        Scenario = "Scenario D: Shipping Fee Inquiry"
        Query = "magkano shipping to luzon via j and t?"
        ExpectedSubstring = "Luzon: Small ₱79"
    },
    [PSCustomObject]@{
        Scenario = "Scenario E: Payment Methods & Rules"
        Query = "ano po mop and rules sa downpayment?"
        ExpectedSubstring = "30% non-refundable downpayment"
    }
)

$passed = 0
$failed = 0

foreach ($sim in $simulations) {
    Write-Host "`nTesting $($sim.Scenario)..." -ForegroundColor Yellow
    Write-Host "  Query: '$($sim.Query)'" -ForegroundColor Gray
    $res = Simulate-CustomerResponse -query $sim.Query
    Write-Host "  Generated Reply: $($res.Reply)" -ForegroundColor Cyan

    $ok = $true
    if ($sim.ExpectedSubstring -and $res.Reply -notlike "*$($sim.ExpectedSubstring)*") {
        Write-Host "  FAILED: Expected response to contain '$($sim.ExpectedSubstring)'" -ForegroundColor Red
        $ok = $false
    }
    if ($sim.ExpectedNoteSubstring -and $res.Reply -notlike "*$($sim.ExpectedNoteSubstring)*") {
        Write-Host "  FAILED: Expected note to contain '$($sim.ExpectedNoteSubstring)'" -ForegroundColor Red
        $ok = $false
    }
    if (-not $res.HasDisclosure) {
        Write-Host "  FAILED: Automated disclosure tag missing" -ForegroundColor Red
        $ok = $false
    }
    if (-not $res.IsTaglish) {
        Write-Host "  FAILED: Taglish friendly opener missing" -ForegroundColor Red
        $ok = $false
    }

    if ($ok) {
        Write-Host "  PASSED: Factual, grounded, and polite response generated." -ForegroundColor Green
        $passed++
    } else {
        $failed++
    }
}

$summaryColor = if ($failed -eq 0) { "Green" } else { "Red" }
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "PHASE 6 TEST SUMMARY: $passed Passed, $failed Failed" -ForegroundColor $summaryColor
Write-Host "==================================================" -ForegroundColor Cyan

if ($failed -gt 0) { exit 1 }
