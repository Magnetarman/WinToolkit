<#
.SYNOPSIS
    Genera le release notes aggregando PR e Issue chiuse dall'ultima release stabile.

.PARAMETER Version
    Stringa di versione della release corrente.

.PARAMETER SourceKB
    Dimensione sorgente in KB (metrica di build).

.PARAMETER OutputKB
    Dimensione output compilato in KB.

.PARAMETER ReductionPercent
    Percentuale di riduzione post-minificazione.

.PARAMETER LinesRemoved
    Numero di righe eliminate durante la build.

.OUTPUTS
    Scrive release_body.md nella directory corrente.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$SourceKB = '',
    [string]$OutputKB = '',
    [string]$ReductionPercent = '',
    [string]$LinesRemoved = ''
)

$ErrorActionPreference = 'Stop'

# ─── FASE 1: Identificazione release di riferimento ────────────────────────────
Write-Host "::group::FASE 1 — Ricerca release di riferimento"
$targetDate = $null

$stableTag = gh release list `
    --exclude-pre-releases --limit 1 `
    --json tagName,publishedAt --jq '.[0].tagName' 2>$null

if ($stableTag -and $stableTag.Trim() -ne '') {
    $stableTag = $stableTag.Trim()
    Write-Host "Release stabile trovata: $stableTag"
    $publishedAtRaw = gh release view $stableTag --json publishedAt --jq '.publishedAt'
    $targetDate = [System.DateTimeOffset]::Parse(
        $publishedAtRaw.Trim(),
        [System.Globalization.CultureInfo]::InvariantCulture
    ).UtcDateTime
    Write-Host "Data di taglio: $targetDate (UTC)"
}

if (-not $targetDate) {
    Write-Host "Nessuna release stabile. Scansione cronologia..."
    $allReleases = (gh release list --limit 200 --json tagName,publishedAt,isLatest,isPrerelease) | ConvertFrom-Json
    $latestRecord = $allReleases | Where-Object { $_.isLatest -eq $true } | Select-Object -First 1
    if ($latestRecord) {
        $targetRaw  = $latestRecord.publishedAt
        $targetDate = if ($targetRaw -is [System.DateTime]) { $targetRaw } else {
            [System.DateTimeOffset]::Parse($targetRaw.Trim(), [System.Globalization.CultureInfo]::InvariantCulture).UtcDateTime
        }
        Write-Host "isLatest=true: $($latestRecord.tagName) — $targetDate (UTC)"
    }
}

if (-not $targetDate) {
    Write-Host "Nessuna release trovata — uso data primo commit."
    $firstRaw = git log --reverse --format="%aI" | Select-Object -First 1
    if ($firstRaw -and $firstRaw.Trim() -ne '') {
        $targetDate = ([System.DateTimeOffset]::Parse($firstRaw.Trim(), [System.Globalization.CultureInfo]::InvariantCulture).UtcDateTime).AddSeconds(-1)
        Write-Host "Data primo commit: $targetDate (UTC)"
    } else {
        $targetDate = [System.DateTime]::MinValue
    }
}
Write-Host "::endgroup::"

# ─── FASE 2: Recupero e filtro PR ─────────────────────────────────────────────
Write-Host "::group::FASE 2 — Recupero e filtro PR"
Write-Host "Filtro PR mergiate dopo: $targetDate (UTC)"

$prsObj = (gh pr list --state merged --base Dev --limit 200 `
    --json number,title,url,author,mergedAt,labels) | ConvertFrom-Json
if (-not $prsObj) { $prsObj = @() }
Write-Host "PR totali: $($prsObj.Count)"

$botPatterns = @('*[bot]', 'dependabot*', 'renovate*')

$validPrs = $prsObj | Where-Object {
    $mergedAtUtc = if ($_.mergedAt -is [System.DateTime]) { $_.mergedAt } else {
        [System.DateTimeOffset]::Parse($_.mergedAt.Trim(), [System.Globalization.CultureInfo]::InvariantCulture).UtcDateTime
    }
    $afterCutoff = $mergedAtUtc -gt $targetDate
    $isExcluded  = $false
    foreach ($p in $botPatterns) { if ($_.author.login -like $p) { $isExcluded = $true; break } }
    $afterCutoff -and (-not $isExcluded)
}
Write-Host "PR valide: $($validPrs.Count)"
Write-Host "::endgroup::"

# ─── FASE 3: Categorizzazione ─────────────────────────────────────────────────
Write-Host "::group::FASE 3 — Generazione release notes"

function Get-PrCategory {
    param([string]$Title, [string[]]$Labels, [string]$Author)
    $t = $Title.ToLower().Trim()
    $a = $Author.ToLower()

    if ($a -ne 'magnetarman') { return 'external' }
    if ($t -match '^\[?gui\]?' -or $t -match '^gui\b') { return 'gui' }
    if ($t -match '^\[?feature\]?' -or $Labels -contains 'feature' -or $t -match '^(feat|feature|add|new|implement)\b') { return 'feature' }
    if ($t -match '^\[?bug(fix)?\]?' -or $t -match '^\[?fix\]?' -or $Labels -contains 'bug' -or $Labels -contains 'fix' -or $Labels -contains 'bugfix' -or $t -match '^(fix|bugfix|resolve|repair)\b' -or $t -match '\b(fix|bug|resolve)\b') { return 'bugfix' }
    if ($t -match '^\[?enhancement\]?' -or $Labels -contains 'enhancement' -or $t -match '^(update|improve|optimize|enhance|enhancement)\b') { return 'enhancement' }
    return 'external'
}

$cleanRegex = '^\[?(feature|feat|bug|bugfix|fix|hotfix|enhancement|enhance|update|improve|optimize|new|add|implement|gui)\]?[:\s-]*'
$gui = @(); $features = @(); $enhancements = @(); $bugFixes = @(); $externalChanges = @()

foreach ($pr in $validPrs) {
    $rawTitle = $pr.title.Trim()
    $author   = $pr.author.login
    $labels   = $pr.labels | ForEach-Object { $_.name.ToLower() }
    $category = Get-PrCategory -Title $rawTitle -Labels $labels -Author $author

    $cleanTitle = $rawTitle -replace $cleanRegex, ''
    $cleanTitle = $cleanTitle.Trim()
    if ($cleanTitle.Length -gt 0) { $cleanTitle = $cleanTitle.Substring(0,1).ToUpper() + $cleanTitle.Substring(1) }
    else { $cleanTitle = $rawTitle }

    $line = "- $cleanTitle @$author (#$($pr.number))"
    switch ($category) {
        'gui'         { $gui             += $line }
        'feature'     { $features        += $line }
        'enhancement' { $enhancements    += $line }
        'bugfix'      { $bugFixes        += $line }
        default       { $externalChanges += $line }
    }
}

$issuesObj = (gh issue list --state closed --limit 200 `
    --json number,title,url,author,closedAt,labels) | ConvertFrom-Json
if (-not $issuesObj) { $issuesObj = @() }

$validIssues = $issuesObj | Where-Object {
    $closedAtUtc = if ($_.closedAt -is [System.DateTime]) { $_.closedAt } else {
        [System.DateTimeOffset]::Parse($_.closedAt.Trim(), [System.Globalization.CultureInfo]::InvariantCulture).UtcDateTime
    }
    $closedAtUtc -gt $targetDate
}
Write-Host "Issues valide: $($validIssues.Count)"

foreach ($issue in $validIssues) {
    $rawTitle = $issue.title.Trim()
    $author   = $issue.author.login
    $labels   = $issue.labels | ForEach-Object { $_.name.ToLower() }
    $category = Get-PrCategory -Title $rawTitle -Labels $labels -Author $author

    $cleanTitle = $rawTitle -replace $cleanRegex, ''
    $cleanTitle = $cleanTitle.Trim()
    if ($cleanTitle.Length -gt 0) { $cleanTitle = $cleanTitle.Substring(0,1).ToUpper() + $cleanTitle.Substring(1) }
    else { $cleanTitle = $rawTitle }

    $line = "- $cleanTitle @$author (#$($issue.number))"
    switch ($category) {
        'gui'         { $gui          += $line }
        'feature'     { $features     += $line }
        'enhancement' { $enhancements += $line }
        'bugfix'      { $bugFixes     += $line }
        default       { $externalChanges += $line }
    }
}

$body = ""
if ($features.Count        -gt 0) { $body += "## 🚀 Features`n`n"         + ($features        -join "`n") + "`n`n" }
if ($gui.Count             -gt 0) { $body += "## 🖥️ GUI`n`n"              + ($gui             -join "`n") + "`n`n" }
if ($bugFixes.Count        -gt 0) { $body += "## 🐛 Bug Fixes`n`n"        + ($bugFixes        -join "`n") + "`n`n" }
if ($enhancements.Count    -gt 0) { $body += "## ✨ Enhancement`n`n"      + ($enhancements    -join "`n") + "`n`n" }
if ($externalChanges.Count -gt 0) { $body += "## 🔄 External Changes`n`n" + ($externalChanges -join "`n") + "`n`n" }
if (($validPrs.Count + $validIssues.Count) -eq 0) { $body += "_Nessun contributo in questa build._`n`n" }

$body += "`n### 📊 Statistiche Compressione`n`n"
$body += "| Metrica         | Valore        |`n"
$body += "|-----------------|---------------|`n"
$body += "| Peso Sorgente   | $SourceKB KB  |`n"
$body += "| Peso Finale     | $OutputKB KB  |`n"
$body += "| Riduzione       | $ReductionPercent%   |`n"
$body += "| Righe Eliminate | $LinesRemoved |`n"

[System.IO.File]::WriteAllText(
    (Join-Path $PWD "release_body.md"),
    $body,
    [System.Text.UTF8Encoding]::new($false)
)
Write-Host "release_body.md scritto."
Write-Host "::endgroup::"
