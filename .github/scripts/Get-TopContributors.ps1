# =============================================================================
# WinToolkit — Get-TopContributors.ps1
# =============================================================================
# Calcola la classifica dei Top 10 Contributors sul branch Dev e aggiorna
# il README.md con una sezione tra marker HTML dedicati.
#
# LOGICA:
#   - Recupera commit e PR dal branch Dev tramite API GitHub (paginazione 100).
#   - Esclude bot noti (github-actions[bot], dependabot[bot]).
#   - Ordina per numero di PR (decrescente), poi per commit (decrescente).
#   - Gestisce autori senza account GitHub collegato (commit.author nullo).
#   - Aggiorna il README tra i marker <!-- TOP_CONTRIBUTORS_START/END -->.
#   - Crea/aggiorna una PR verso main con le modifiche.
#
# BRANCH PROTECTION:
#   Il branch main NON risulta protetto (verifica API: 404). Pertanto si usa
#   GITHUB_TOKEN con fallback a RELEASE_AUTOMATION_TOKEN (pattern coerente
#   con le pipeline esistenti). Se in futuro venisse aggiunta protezione,
#   aggiungere un PAT con permessi repo come secret.
#
# SCHEDULING:
#   Il workflow usa un controllo runtime per il fuso orario Europe/Rome.
#   Il cron GitHub Actions e' fisso su UTC (04:00 UTC ogni lunedi', che
#   corrisponde a 06:00 CEST o 05:00 CET). Lo script verifica l'ora italiana
#   e procede solo se ci si trova in una finestra accettabile (05:00-07:00),
#   gestendo cosi' il cambio automatico CET/CEST.
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GitHubToken,

    [string]$Repo = "Magnetarman/WinToolkit",
    [string]$DevBranch = "Dev",
    [string]$MainBranch = "main",
    [string]$ReadmePath = "README.md",
    [int]$TopN = 10
)

$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

# ---------------------------------------------------------------------------
# CONFIGURAZIONE
# ---------------------------------------------------------------------------
$ApiBase = "https://api.github.com"
$Headers = @{
    Authorization = "Bearer $GitHubToken"
    Accept        = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent"  = "WinToolkit-TopContributors"
}

$ExcludedBots = @(
    "github-actions[bot]",
    "dependabot[bot]"
)

$StartMarker = "<!-- TOP_CONTRIBUTORS_START -->"
$EndMarker   = "<!-- TOP_CONTRIBUTORS_END -->"

$PrLabel = "top-contributors"
$BranchPrefix = "update/top-contributors"

# ---------------------------------------------------------------------------
# FUNZIONI DI SUPPORTO
# ---------------------------------------------------------------------------
function Invoke-GitHubApi {
    param(
        [string]$Uri,
        [int]$Page = 1,
        [int]$PerPage = 100
    )
    
    $url = if ($Uri -like "*?*") {
        "$Uri&page=$Page&per_page=$PerPage"
    } else {
        "$Uri?page=$Page&per_page=$PerPage"
    }
    
    $response = $null
    $retries = 3
    $delay = 2
    
    for ($i = 1; $i -le $retries; $i++) {
        try {
            $response = Invoke-RestMethod -Uri $url -Headers $Headers -Method Get -ErrorAction Stop
            break
        }
        catch {
            if ($i -eq $retries) {
                Write-Error "API request failed after $retries retries: $_"
                throw
            }
            $statusCode = $_.Exception.Response.StatusCode.value__
            if ($statusCode -eq 403 -or $statusCode -eq 429) {
                $retryAfter = 5
                if ($_.Exception.Response.Headers["Retry-After"]) {
                    $retryAfter = [int]$_.Exception.Response.Headers["Retry-After"]
                }
                Write-Warning "Rate limited (attempt $i/$retries). Waiting ${retryAfter}s..."
                Start-Sleep -Seconds $retryAfter
            } else {
                Write-Warning "HTTP $statusCode (attempt $i/$retries). Waiting ${delay}s..."
                Start-Sleep -Seconds $delay
                $delay *= 2
            }
        }
    }
    
    return $response
}

function Get-CommitsFromDev {
    param([string]$Token)
    
    Write-Host "Fetching commits from branch '$DevBranch'..."
    $allCommits = @()
    $page = 1
    $hasMore = $true
    
    while ($hasMore) {
        $uri = "$ApiBase/repos/$Repo/commits?sha=$DevBranch&page=$page&per_page=100"
        $commits = Invoke-GitHubApi -Uri $uri -Page $page -PerPage 100
        
        if (-not $commits -or $commits.Count -eq 0) {
            $hasMore = $false
        } else {
            $allCommits += $commits
            if ($commits.Count -lt 100) {
                $hasMore = $false
            } else {
                $page++
            }
        }
    }
    
    Write-Host "Total commits fetched: $($allCommits.Count)"
    return $allCommits
}

function Get-PrsFromDev {
    param([string]$Token)
    
    Write-Host "Fetching PRs with base='$DevBranch'..."
    $allPrs = @()
    $page = 1
    $hasMore = $true
    
    while ($hasMore) {
        $uri = "$ApiBase/repos/$Repo/pulls?base=$DevBranch&state=all&page=$page&per_page=100"
        $prs = Invoke-GitHubApi -Uri $uri -Page $page -PerPage 100
        
        if (-not $prs -or $prs.Count -eq 0) {
            $hasMore = $false
        } else {
            $allPrs += $prs
            if ($prs.Count -lt 100) {
                $hasMore = $false
            } else {
                $page++
            }
        }
    }
    
    Write-Host "Total PRs fetched: $($allPrs.Count)"
    return $allPrs
}

function ConvertTo-ContributorStats {
    param(
        [array]$Commits,
        [array]$Prs
    )
    
    $stats = @{}
    
    # Process commits
    foreach ($commit in $Commits) {
        $author = $commit.author
        if ($null -eq $author) {
            $commitAuthor = $commit.commit.author
            if ($null -ne $commitAuthor) {
                Write-Warning "Commit $($commit.sha) has no linked GitHub account (author: $($commitAuthor.name) <$($commitAuthor.email)>). Excluded from ranking."
            }
            continue
        }
        
        $login = $author.login.ToLower()
        
        if ($ExcludedBots -contains $login) {
            Write-Host "Excluding bot: $login"
            continue
        }
        
        if (-not $stats.ContainsKey($login)) {
            $stats[$login] = @{
                Login     = $login
                Name      = $author.login
                AvatarUrl = $author.avatar_url
                ProfileUrl = $author.html_url
                Commits   = 0
                Prs       = 0
            }
        }
        $stats[$login].Commits++
    }
    
    # Process PRs
    foreach ($pr in $Prs) {
        $login = $pr.user.login.ToLower()
        
        if ($ExcludedBots -contains $login) {
            Write-Host "Excluding bot from PR: $login"
            continue
        }
        
        if (-not $stats.ContainsKey($login)) {
            $stats[$login] = @{
                Login     = $login
                Name      = $pr.user.login
                AvatarUrl = $pr.user.avatar_url
                ProfileUrl = $pr.user.html_url
                Commits   = 0
                Prs       = 0
            }
        }
        $stats[$login].Prs++
    }
    
    return $stats.Values | Sort-Object { $_.Prs }, { $_.Commits } -Descending | Select-Object -First $TopN
}

function New-ContributorsMarkdown {
    param(
        [array]$TopContributors,
        [string]$SectionTitle = "Top 10 Contributors"
    )
    
    if ($TopContributors.Count -eq 0) {
        return "No contributors found yet."
    }
    
    $lines = @("## $SectionTitle")
    $lines += ""
    $lines += "| Rank | Contributor | Commits | PRs |"
    $lines += "| :--- | :--- | :--- | :--- |"
    
    $rank = 1
    foreach ($contributor in $TopContributors) {
        $avatar = "<img src=`"$($contributor.AvatarUrl)`" width=`"24`" height=`"24`" alt=`"$($contributor.Name)`" style=`"border-radius:50%;vertical-align:middle;`">"
        $profileLink = "[$($contributor.Name)](https://github.com/$($contributor.Login))"
        $line = "| $rank | $avatar $profileLink | $($contributor.Commits) | $($contributor.Prs) |"
        $lines += $line
        $rank++
    }
    
    $lines += ""
    return $lines -join "`n"
}

function Update-ReadmeSection {
    param(
        [string]$Path,
        [string]$NewContent
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "README not found at: $Path"
        return $false
    }
    
    $content = Get-Content -Path $Path -Raw -Encoding UTF8
    $startIdx = $content.IndexOf($StartMarker)
    $endIdx = $content.IndexOf($EndMarker)
    
    if ($startIdx -eq -1 -or $endIdx -eq -1) {
        Write-Warning "Markers not found. Appending section before 'Author' or at end of file."
        # Try to find a good insertion point
        $authorPattern = '(?mi)^## .*Author.*$'
        if ($content -match $authorPattern) {
            $insertIdx = $content.IndexOf($Matches[0])
            $before = $content.Substring(0, $insertIdx)
            $after = $content.Substring($insertIdx)
            $newSection = "$StartMarker`n$NewContent`n$EndMarker`n`n"
            $newContent = $before + $newSection + $after
        } else {
            $newSection = "`n$StartMarker`n$NewContent`n$EndMarker`n"
            $newContent = $content + $newSection
        }
    } else {
        $before = $content.Substring(0, $startIdx + $StartMarker.Length)
        $after = $content.Substring($endIdx)
        $newSection = "`n$NewContent`n"
        $newContent = $before + $newSection + $after
    }
    
    Set-Content -Path $Path -Value $newContent -Encoding UTF8 -NoNewline
    Write-Host "README updated successfully."
    return $true
}

function New-PullRequest {
    param(
        [string]$BranchName,
        [string]$Title,
        [string]$Body,
        [string]$Repo,
        [hashtable]$Headers
    )
    
    $apiBase = "https://api.github.com"
    
    # Check if PR already exists with our label
    $existingPrs = Invoke-RestMethod -Uri "$apiBase/repos/$Repo/pulls?state=open&per_page=100" -Headers $Headers -Method Get
    $existingPr = $existingPrs | Where-Object { $_.labels.name -contains $PrLabel } | Select-Object -First 1
    
    if ($existingPr) {
        Write-Host "PR esistente trovata: #$($existingPr.number) (branch: $($existingPr.head.ref)). Aggiorno il branch."
        # Return the existing branch name so we can push to it
        return @{ Number = $existingPr.number; Branch = $existingPr.head.ref; Exists = $true }
    }
    
    # Create new PR
    $bodyObj = @{
        title = $Title
        head  = $BranchName
        base  = $MainBranch
        body  = $Body
    } | ConvertTo-Json -Depth 3
    
    $pr = Invoke-RestMethod -Uri "$apiBase/repos/$Repo/pulls" -Headers $Headers -Method Post -Body $bodyObj -ContentType "application/json"
    
    # Add label
    Invoke-RestMethod -Uri "$apiBase/repos/$Repo/issues/$($pr.number)/labels" -Headers $Headers -Method Post -Body (@{labels = @($PrLabel)} | ConvertTo-Json) -ContentType "application/json"
    
    Write-Host "PR #$($pr.number) creata: $($pr.html_url)"
    return @{ Number = $pr.number; Branch = $BranchName; Exists = $false }
}

# ---------------------------------------------------------------------------
# VALIDAZIONE FUSO ORARIO (Europe/Rome)
# ---------------------------------------------------------------------------
function Test-ShouldProceed {
    $force = $env:FORCE_EXECUTION -eq "true"
    
    try {
        $tz = [TimeZoneInfo]::FindSystemTimeZoneById("Europe/Rome")
        $romeTime = [TimeZoneInfo]::ConvertTime([DateTime]::UtcNow, $tz)
    }
    catch {
        Write-Warning "Impossibile trovare il fuso orario Europe/Rome: $_. Proseguo senza controllo orario."
        return $true
    }
    
    $hour = $romeTime.Hour
    
    # Finestra accettabile: 05:00-07:00 ora italiana
    # Questo copre 04:00 UTC (CEST) e 05:00 UTC (CET)
    if ($hour -ge 5 -and $hour -lt 7) {
        Write-Host "Controllo orario superato: ora italiana corrente $($romeTime.ToString('yyyy-MM-dd HH:mm'))"
        return $true
    }
    
    # Se siamo nel giorno e nell'ora del workflow_dispatch, procedi comunque
    if ($env:GITHUB_EVENT_NAME -eq "workflow_dispatch" -or $force) {
        Write-Host "Esecuzione manuale o forzata, salto controllo finestra oraria."
        return $true
    }
    
    Write-Warning "Fuori finestra di esecuzione (ora italiana: $($romeTime.ToString('yyyy-MM-dd HH:mm')), ora=$hour). Attesa 05:00-07:00."
    return $false
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
if (-not (Test-ShouldProceed)) {
    Write-Host "Skipping execution due to time window restriction."
    exit 0
}

Write-Host "Starting Top Contributors update for repo: $Repo"

# Fetch data
$commits = Get-CommitsFromDev -Token $GitHubToken
$prs = Get-PrsFromDev -Token $GitHubToken

# Calculate stats
$topContributors = ConvertTo-ContributorStats -Commits $commits -Prs $prs
Write-Host "Top contributors calculated: $($topContributors.Count)"

# Generate markdown
$contributorsMarkdown = New-ContributorsMarkdown -TopContributors $topContributors -SectionTitle "Top 10 Contributors"
Write-Host "Generated markdown section:"
Write-Host $contributorsMarkdown

# Update README
$readmeUpdated = Update-ReadmeSection -Path $ReadmePath -NewContent $contributorsMarkdown
if (-not $readmeUpdated) {
    Write-Error "Failed to update README."
    exit 1
}

# Prepare PR body
$prBody = @"
## Top 10 Contributors — Automated Update

This PR updates the **Top 10 Contributors** section in the README.

### Summary
- Contributors analyzed: $($topContributors.Count)
- Branch analyzed: $DevBranch
- Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm')

### Ranking Criteria
1. Number of merged PRs (primary)
2. Number of commits (secondary, for ties)

### Excluded Accounts
- github-actions[bot]
- dependabot[bot]

---
*Automated by WinToolkit CI/CD — Top Contributors Workflow*
"@

# Git operations
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$branchName = "$BranchPrefix-$timestamp"

Write-Host "Preparing git branch: $branchName"

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git config core.autocrlf true
git config core.safecrlf false

git checkout $MainBranch
git pull origin $MainBranch

# Check if an existing PR with our label exists
$existingPrResult = New-PullRequest -BranchName $branchName -Title "docs: update Top 10 Contributors" -Body $prBody -Repo $Repo -Headers $Headers

if ($existingPrResult.Exists) {
    # Use the existing branch
    $branchName = $existingPrResult.Branch
    Write-Host "Using existing branch: $branchName"
    git checkout $branchName
    git pull origin $branchName
} else {
    git checkout -b $branchName
}

git add $ReadmePath
$diff = git diff --cached --stat
if ($diff) {
    git commit -m "docs: update Top 10 Contributors section"
    git push origin $branchName
    
    if (-not $existingPrResult.Exists) {
        $prNumber = New-PullRequest -BranchName $branchName -Title "docs: update Top 10 Contributors" -Body $prBody -Repo $Repo -Headers $Headers
        Write-Host "PR #$($prNumber.Number) creata/aggiornata con successo."
    } else {
        Write-Host "Branch aggiornato. PR #$($existingPrResult.Number) aggiornata automaticamente."
    }
} else {
    Write-Host "Nessuna modifica al README. Salto creazione PR."
}
