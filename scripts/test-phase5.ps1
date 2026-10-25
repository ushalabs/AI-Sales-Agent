# scripts/test-phase5.ps1
# Phase 5 Deterministic Knowledge Integration Test Harness

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " AI SALES AGENT - PHASE 5 KNOWLEDGE TEST HARNESS   " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Import knowledge json
$kb = Get-Content (Join-Path $ProjectRoot "data\knowledge_base.json") -Raw | ConvertFrom-Json

function Match-Knowledge([string]$query) {
    $q = $query.ToLower().Trim()
    
    $memberAliases = [ordered]@{
        'scoups' = 'S.COUPS'; 's.coups' = 'S.COUPS'; 'coups' = 'S.COUPS'; 'cheol' = 'S.COUPS'; 'seungcheol' = 'S.COUPS';
        'jeonghan' = 'JEONGHAN'; 'hannie' = 'JEONGHAN';
        'joshua' = 'JOSHUA'; 'shua' = 'JOSHUA';
        'jun' = 'JUN'; 'junhui' = 'JUN'; 'wen junhui' = 'JUN';
        'hoshi' = 'HOSHI'; 'soonyoung' = 'HOSHI'; 'tiger' = 'HOSHI';
        'wonwoo' = 'WONWOO';
        'woozi' = 'WOOZI'; 'jihoon' = 'WOOZI';
        'dk' = 'DK'; 'dokyeom' = 'DK'; 'seokmin' = 'DK';
        'mingyu' = 'MINGYU';
        'minghao' = 'MINGHAO'; 'the8' = 'MINGHAO'; 'myungho' = 'MINGHAO';
        'seungkwan' = 'SEUNGKWAN'; 'kwan' = 'SEUNGKWAN'; 'boo' = 'SEUNGKWAN';
        'vernon' = 'VERNON'; 'hansol' = 'VERNON';
        'dino' = 'DINO'; 'chan' = 'DINO';
        'unit' = 'UNIT'
    }

    $detectedMembers = @()
    foreach ($entry in $memberAliases.GetEnumerator()) {
        $alias = $entry.Key
        $canonical = $entry.Value
        $pattern = "(?i)(^|\W)" + [regex]::Escape($alias) + "($|\W)"
        if ($q -match $pattern -and $detectedMembers -notcontains $canonical) {
            $detectedMembers += $canonical
        }
    }

    $isShipping = ($q -match "(?i)\b(shipping|sf|pf|pack|delivery|luzon|visayas|mindanao|j\s*&\s*t|j and t|courier)\b")
    $isPayment = ($q -match "(?i)\b(payment|mop|gcash|maya|maribank|downpayment|nrdp|deadline|bayad)\b")

    $scoredList = New-Object System.Collections.ArrayList
    foreach ($p in $kb.products) {
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

        $tokens = $q -split '\s+' | Where-Object { $_.Length -gt 1 }
        foreach ($tok in $tokens) {
            if ($pLower -like "*$tok*") { $score += 25 }
            elseif ($nLower -like "*$tok*") { $score += 10 }
            elseif ($mLower -like "*$tok*") { $score += 15 }
        }

        # Specific version keywords matching
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

    $status = "NOT_FOUND"
    $matched = @()

    if ($scored.Count -eq 1) {
        $status = if ($scored[0].Product.stock -eq 0) { "OUT_OF_STOCK" } else { "EXACT_MATCH" }
        $matched = @($scored[0].Product)
    } elseif ($scored.Count -gt 1) {
        if ($scored[0].Score -ge ($scored[1].Score + 20)) {
            $status = if ($scored[0].Product.stock -eq 0) { "OUT_OF_STOCK" } else { "EXACT_MATCH" }
            $matched = @($scored[0].Product)
        } else {
            $status = "AMBIGUOUS_MATCH"
            $matched = @($scored | Select-Object -First 5 | ForEach-Object { $_.Product })
        }
    } elseif ($detectedMembers.Count -eq 1) {
        $mProds = @($kb.products | Where-Object { $_.member -eq $detectedMembers[0] })
        if ($mProds.Count -gt 0) {
            if ($mProds.Count -eq 1 -and $mProds[0].stock -eq 0) {
                $status = "OUT_OF_STOCK"
                $matched = $mProds
            } else {
                $status = "AMBIGUOUS_MATCH"
                $matched = $mProds
            }
        }
    }

    return [PSCustomObject]@{
        Status = $status
        Products = $matched
        IsShipping = $isShipping
        IsPayment = $isPayment
    }
}

$testList = @(
    [PSCustomObject]@{
        Name = 'Test 1: Exact Product Match with Condition Note'
        Query = 'magkano fml deluxe ni jun at may dent ba?'
        ExpectedStatus = 'EXACT_MATCH'
        ExpectedProduct = 'FML - Deluxe Version'
        ExpectedPrice = 100
        ExpectedNote = 'With dent on backprint'
    },
    [PSCustomObject]@{
        Name = 'Test 2: Out of Stock Member Detection'
        Query = 'available pa po ba scoups photocard?'
        ExpectedStatus = 'OUT_OF_STOCK'
        ExpectedStock = 0
    },
    [PSCustomObject]@{
        Name = 'Test 3: Typo / Member Alias Handling (Hannie -> Jeonghan)'
        Query = 'hm po yung hannie connect 8th anniversary?'
        ExpectedStatus = 'EXACT_MATCH'
        ExpectedProduct = '8th Anniversary CONNECT'
        ExpectedPrice = 350
        ExpectedNote = 'With dent on upper left'
    },
    [PSCustomObject]@{
        Name = 'Test 4: Ambiguous Product Reference Detection'
        Query = 'ano available photocards ni mingyu?'
        ExpectedStatus = 'AMBIGUOUS_MATCH'
        MinMatches = 2
    },
    [PSCustomObject]@{
        Name = 'Test 5: Shipping Fee Inquiry'
        Query = 'magkano po shipping fee pa luzon via j&t?'
        ExpectShipping = $true
    },
    [PSCustomObject]@{
        Name = 'Test 6: Payment Methods Inquiry'
        Query = 'ano po mop at payment deadline nyo?'
        ExpectPayment = $true
    }
)

$passed = 0
$failed = 0

foreach ($t in $testList) {
    Write-Host "`nRunning $($t.Name)..." -ForegroundColor Yellow
    $res = Match-Knowledge $t.Query
    $ok = $true

    if ($t.ExpectedStatus -and $res.Status -ne $t.ExpectedStatus) {
        Write-Host "  FAILED: Expected status $($t.ExpectedStatus), got $($res.Status)" -ForegroundColor Red
        $ok = $false
    }
    if ($t.ExpectedProduct -and $res.Products[0].product_name -ne $t.ExpectedProduct) {
        Write-Host "  FAILED: Expected product $($t.ExpectedProduct), got $($res.Products[0].product_name)" -ForegroundColor Red
        $ok = $false
    }
    if ($t.ExpectedPrice -and $res.Products[0].price_php -ne $t.ExpectedPrice) {
        Write-Host "  FAILED: Expected price $($t.ExpectedPrice), got $($res.Products[0].price_php)" -ForegroundColor Red
        $ok = $false
    }
    if ($t.ExpectedNote -and $res.Products[0].notes -ne $t.ExpectedNote) {
        Write-Host "  FAILED: Expected note '$($t.ExpectedNote)', got '$($res.Products[0].notes)'" -ForegroundColor Red
        $ok = $false
    }
    if ($t.MinMatches -and $res.Products.Count -lt $t.MinMatches) {
        Write-Host "  FAILED: Expected at least $($t.MinMatches) matches, got $($res.Products.Count)" -ForegroundColor Red
        $ok = $false
    }
    if ($t.ExpectShipping -and -not $res.IsShipping) {
        Write-Host "  FAILED: Expected shipping inquiry flag to be true" -ForegroundColor Red
        $ok = $false
    }
    if ($t.ExpectPayment -and -not $res.IsPayment) {
        Write-Host "  FAILED: Expected payment inquiry flag to be true" -ForegroundColor Red
        $ok = $false
    }

    if ($ok) {
        Write-Host "  PASSED: Status=$($res.Status), Matched=$($res.Products.Count) items" -ForegroundColor Green
        $passed++
    } else {
        $failed++
    }
}

$summaryColor = if ($failed -eq 0) { "Green" } else { "Red" }
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "PHASE 5 TEST SUMMARY: $passed Passed, $failed Failed" -ForegroundColor $summaryColor
Write-Host "==================================================" -ForegroundColor Cyan

if ($failed -gt 0) { exit 1 }
