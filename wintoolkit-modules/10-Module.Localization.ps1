

$Global:MsgStyles = @{
    Success  = @{ Icon = '✅'; Color = 'Green' }
    Warning  = @{ Icon = '⚠️'; Color = 'Yellow' }
    Error    = @{ Icon = '❌'; Color = 'Red' }
    Info     = @{ Icon = '💎'; Color = 'Cyan' }
    Progress = @{ Icon = '🔄'; Color = 'Magenta' }
    Question = @{ Icon = '❓'; Color = 'Cyan' }
}
$Global:ExecutionLog = @()
$Global:NeedsFinalReboot = $false
$Global:SourceTextLanguage = 'en-US'
$Global:SourceTextLanguageData = $null
$Global:SourceTextDefaultLanguageData = $null
$Global:SourceTextPreparedLanguagesDir = $null

function Get-SourceTextLanguageDirectory {
    if ($Global:SourceTextPreparedLanguagesDir -and (Test-Path $Global:SourceTextPreparedLanguagesDir)) {
        return $Global:SourceTextPreparedLanguagesDir
    }
    $root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $candidate = Join-Path $root 'languages'
    if (Test-Path $candidate) { return $candidate }

    $repoCandidate = Join-Path (Get-Location) 'languages'
    if (Test-Path $repoCandidate) { return $repoCandidate }

    return $candidate
}

function Get-AvailableSourceTextLanguages {
    $languageDir = Get-SourceTextLanguageDirectory
    if (-not (Test-Path $languageDir)) { return @() }

    Get-ChildItem -Path $languageDir -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName 'WinToolkit.psd1') } |
    ForEach-Object {
        try {
            $data = Import-SourceTextLanguageFile -LanguageCode $_.Name
            [pscustomobject]@{
                Code         = if ($data.ContainsKey('language.code')) { $data['language.code'] } else { $_.Name }
                Name         = if ($data.ContainsKey('language.name')) { $data['language.name'] } else { $_.Name }
                NativeName   = if ($data.ContainsKey('language.nativeName')) { $data['language.nativeName'] } else { $_.Name }
                AiTranslated = if ($data.ContainsKey('language.aiTranslated')) { $data['language.aiTranslated'] -eq 'true' } else { $false }
                Path         = $_.FullName
            }
        }
        catch {
            Write-Verbose "Invalid language file '$($_.FullName)': $($_.Exception.Message)"
        }
    } | Sort-Object Code
}

function Import-SourceTextLanguageFile {
    param([string]$LanguageCode)

    $languageDir = Get-SourceTextLanguageDirectory
    try {
        $localizedData = $null
        Import-LocalizedData -BindingVariable localizedData -BaseDirectory $languageDir -FileName 'WinToolkit.psd1' -UICulture $LanguageCode -ErrorAction Stop
        return $localizedData
    }
    catch {
        return $null
    }
}

function Set-SourceTextLanguage {
    param([string]$LanguageCode = 'en-US')

    $defaultData = Import-SourceTextLanguageFile -LanguageCode 'en-US'
    if ($defaultData) { $Global:SourceTextDefaultLanguageData = $defaultData }

    $languageData = Import-SourceTextLanguageFile -LanguageCode $LanguageCode
    if (-not $languageData) {
        $LanguageCode = 'en-US'
        $languageData = $defaultData
    }

    if ($languageData) {
        $Global:SourceTextLanguage = $LanguageCode
        $Global:SourceTextLanguageData = $languageData
    }
}

function Get-SourceTextLoc {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Alias('Args')][object[]]$Arguments = @()
    )

    $value = $null
    if ($Global:SourceTextLanguageData -and $Global:SourceTextLanguageData.ContainsKey($Key)) {
        $value = [string]$Global:SourceTextLanguageData[$Key]
    }
    elseif ($Global:SourceTextDefaultLanguageData -and $Global:SourceTextDefaultLanguageData.ContainsKey($Key)) {
        $value = [string]$Global:SourceTextDefaultLanguageData[$Key]
    }
    else {
        $value = $Key
    }

    if ($Arguments -and $Arguments.Count -gt 0) { return [string]::Format($value, $Arguments) }
    return $value
}

function Get-SourceTextMenuText {
    param([object]$Item)

    if ($Item -is [System.Collections.IDictionary]) {
        if ($Item.Contains('DescriptionKey') -and $Item['DescriptionKey']) {
            return (Get-SourceTextLoc $Item['DescriptionKey'])
        }
        if ($Item.Contains('CategoryKey') -and $Item['CategoryKey']) {
            return (Get-SourceTextLoc $Item['CategoryKey'])
        }
        if ($Item.Contains('Description')) { return $Item['Description'] }
        if ($Item.Contains('Name')) { return $Item['Name'] }
    }

    if ($Item.PSObject.Properties.Name -contains 'DescriptionKey' -and $Item.DescriptionKey) {
        return (Get-SourceTextLoc $Item.DescriptionKey)
    }
    if ($Item.PSObject.Properties.Name -contains 'CategoryKey' -and $Item.CategoryKey) {
        return (Get-SourceTextLoc $Item.CategoryKey)
    }
    if ($Item.PSObject.Properties.Name -contains 'Description') { return $Item.Description }
    if ($Item.PSObject.Properties.Name -contains 'Name') { return $Item.Name }
    return [string]$Item
}

function Get-RemoteAvailableCultures {
    param([string]$GitHubApiUrl = "https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=$Branch")
    try {
        $response = Invoke-RestMethod -Uri $GitHubApiUrl -UseBasicParsing -ErrorAction Stop
        return @($response | Where-Object { $_.type -eq 'dir' } | ForEach-Object { $_.name })
    }
    catch {
        return @()
    }
}

function Invoke-SourceTextLanguagePreparation {
    [CmdletBinding()]
    param(
        [string]$ScriptRoot,
        [string]$RemoteBaseUrl = "$RepoBase/languages",
        [string]$GitHubApiUrl = "https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=$Branch",
        [int]$CacheMaxAgeDays = 7
    )
    $localDir = Join-Path $env:LOCALAPPDATA 'WinToolkit\languages'
    $remoteCultures = Get-RemoteAvailableCultures -GitHubApiUrl $GitHubApiUrl
    $needDownload = $false
    if (-not (Test-Path $localDir)) {
        $needDownload = $true
    }
    else {
        $oldestFile = Get-ChildItem -Path $localDir -Recurse -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -First 1
        if ($oldestFile) {
            $age = (Get-Date) - $oldestFile.LastWriteTime
            if ($age.TotalDays -ge $CacheMaxAgeDays) { $needDownload = $true }
        }
        else { $needDownload = $true }
        if (-not $needDownload) {
            foreach ($culture in $remoteCultures) {
                $localFile = Join-Path $localDir $culture 'WinToolkit.psd1'
                if (-not (Test-Path $localFile)) { $needDownload = $true; break }
            }
        }
    }
    if ($needDownload -and $remoteCultures.Count -gt 0) {
        if (-not (Test-Path $localDir)) { New-Item -Path $localDir -ItemType Directory -Force | Out-Null }
        foreach ($culture in $remoteCultures) {
            $cultureDir = Join-Path $localDir $culture
            $localFile = Join-Path $cultureDir 'WinToolkit.psd1'
            if (-not (Test-Path $cultureDir)) { New-Item -Path $cultureDir -ItemType Directory -Force | Out-Null }
            try {
                $remoteUrl = "$RemoteBaseUrl/$culture/WinToolkit.psd1"
                Invoke-WebRequest -Uri $remoteUrl -OutFile $localFile -UseBasicParsing -ErrorAction Stop | Out-Null
            }
            catch {
                if (-not (Test-Path $localFile)) {
                    try {
                        $localFileFallback = Join-Path $ScriptRoot 'languages' $culture 'WinToolkit.psd1'
                        if (Test-Path $localFileFallback) { Copy-Item -Path $localFileFallback -Destination $localFile -Force }
                    }
                    catch {}
                }
            }
        }
    }
    return $localDir
}

function Get-SourceTextAutoDetectedLanguage {
    param([string]$AvailableCultures = 'en-US', [string]$SystemUICulture = ($PSUICulture.ToString()))
    $normalizedSystem = $SystemUICulture.ToLowerInvariant()
    $availableList = @($AvailableCultures -split '[\s,]+' | Where-Object { $_ })
    if ($availableList -contains $normalizedSystem) { return $normalizedSystem }
    $neutralSystem = $normalizedSystem.Split('-')[0]
    foreach ($culture in $availableList) {
        if ($culture.Split('-')[0] -eq $neutralSystem) { return $culture }
    }
    return 'en-US'
}

$Global:SourceTextPreparedLanguagesDir = Invoke-SourceTextLanguagePreparation -ScriptRoot $PSScriptRoot
if ($Language -eq 'en-US') {
    $availableCultures = @()
    if ($Global:SourceTextPreparedLanguagesDir -and (Test-Path $Global:SourceTextPreparedLanguagesDir)) {
        $availableCultures = @(Get-ChildItem -Path $Global:SourceTextPreparedLanguagesDir -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName 'WinToolkit.psd1') } | ForEach-Object { $_.Name })
    }
    $Language = Get-SourceTextAutoDetectedLanguage -AvailableCultures ($availableCultures -join ',')
}
Set-SourceTextLanguage -LanguageCode $Language
