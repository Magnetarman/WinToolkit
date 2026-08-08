# ============================================================================
# LOCALIZATION
# ============================================================================
#
# Resolution order: locally cached language files -> %LOCALAPPDATA% cache ->
# network refresh. Any network failure falls back to the English strings that
# are embedded below, so the user never sees a raw "[MISSING TRANSLATION: ...]"
# placeholder for the messages that matter most.

$script:SourceTextLanguageData = $null
$script:SourceTextDefaultLanguageData = $null
$script:EmbeddedEnglishText = @{
    'uiText.environmentReadyForInstallation'   = 'Environment ready for installation.'
    'uiText.configurationComplete'             = 'Configuration complete.'
    'uiText.wingetNotFoundInSystem'            = 'WinGet was not found on this system.'
    'uiText.powershell7AlreadyInstalled'       = 'PowerShell 7 is already installed.'
    'uiText.windowsTerminalIsAlreadyInstalled' = 'Windows Terminal is already installed.'
    'uiText.systemClockResynced'               = 'System clock resynchronized.'
}
$script:SourceTextKeyAliases = @{
    'uiText.environmentReady'            = 'uiText.environmentReadyForInstallation'
    'uiText.setupComplete'               = 'uiText.configurationComplete'
    'uiText.winget.missing'              = 'uiText.wingetNotFoundInSystem'
    'uiText.powershell.alreadyInstalled' = 'uiText.powershell7AlreadyInstalled'
    'uiText.terminal.alreadyInstalled'   = 'uiText.windowsTerminalIsAlreadyInstalled'
}

function Get-SourceTextLanguageDirectory {
    $root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $candidates = @(
        (Join-Path $root 'languages'),
        (Join-Path (Split-Path $root -Parent) 'languages'),
        (Join-Path (Get-Location) 'languages'),
        (Join-Path $env:LOCALAPPDATA 'WinToolkit\languages')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $candidates[-1]
}

function Get-RemoteAvailableCultures {
    param([string]$GitHubApiUrl = $script:AppConfig.URLs.LanguagesApiUrl)
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
        [string]$RemoteBaseUrl = $script:AppConfig.URLs.LanguagesRawUrl,
        [string]$GitHubApiUrl = $script:AppConfig.URLs.LanguagesApiUrl,
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
        foreach ($culture in (@('en-US') + $remoteCultures | Select-Object -Unique)) {
            $cultureDir = Join-Path $localDir $culture
            $localFile = Join-Path $cultureDir 'WinToolkit.psd1'
            if (-not (Test-Path $cultureDir)) { New-Item -Path $cultureDir -ItemType Directory -Force | Out-Null }
            try {
                $remoteUrl = "$RemoteBaseUrl/$culture/WinToolkit.psd1"
                $temporaryFile = "$localFile.$([guid]::NewGuid()).tmp"
                try {
                    Invoke-WebRequest -Uri $remoteUrl -OutFile $temporaryFile -UseBasicParsing -ErrorAction Stop | Out-Null
                    Move-Item -LiteralPath $temporaryFile -Destination $localFile -Force -ErrorAction Stop
                }
                finally {
                    if (Test-Path -LiteralPath $temporaryFile) { Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue }
                }
            }
            catch {
                if (-not (Test-Path $localFile)) {
                    try {
                        $localFileFallback = Join-Path $ScriptRoot 'languages' $culture 'WinToolkit.psd1'
                        if (Test-Path $localFileFallback) {
                            $temporaryFallback = "$localFile.$([guid]::NewGuid()).tmp"
                            Copy-Item -LiteralPath $localFileFallback -Destination $temporaryFallback -Force
                            Move-Item -LiteralPath $temporaryFallback -Destination $localFile -Force
                        }
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

function Import-SourceTextLanguageFile {
    param([string]$LanguageCode)

    $languageDirectory = Get-SourceTextLanguageDirectory
    if (-not (Test-Path $languageDirectory)) { return $null }
    try {
        $localizedData = $null
        Import-LocalizedData -BindingVariable localizedData -BaseDirectory $languageDirectory -FileName 'WinToolkit.psd1' -UICulture $LanguageCode -ErrorAction Stop
        return $localizedData
    }
    catch {
        return $null
    }
}

function Initialize-SourceTextLocalization {
    param([string]$LanguageCode)

    $script:SourceTextDefaultLanguageData = Import-SourceTextLanguageFile -LanguageCode 'en-US'
    if (-not $script:SourceTextDefaultLanguageData) {
        $script:SourceTextDefaultLanguageData = $script:EmbeddedEnglishText
    }
    $script:SourceTextLanguageData = Import-SourceTextLanguageFile -LanguageCode $LanguageCode
    if (-not $script:SourceTextLanguageData) {
        $script:SourceTextLanguageData = $script:SourceTextDefaultLanguageData
    }
}

function Resolve-SourceTextLanguage {
    <#
    .SYNOPSIS
    Prepares the language cache and resolves 'Auto' to a concrete culture.

    .DESCRIPTION
    Called once by the orchestrator (90-Skeleton.Main.ps1) instead of running as
    script-level code, so that the language cache is only touched after logging
    is available and after the elevation/PowerShell 7 checks have passed.
    #>
    [CmdletBinding()]
    param([string]$RequestedLanguage = 'Auto')

    $preparedDir = Invoke-SourceTextLanguagePreparation -ScriptRoot $PSScriptRoot
    $resolved = $RequestedLanguage
    if ($resolved -eq 'Auto') {
        $availableCultures = @()
        if ($preparedDir -and (Test-Path $preparedDir)) {
            $availableCultures = @(Get-ChildItem -Path $preparedDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { Test-Path (Join-Path $_.FullName 'WinToolkit.psd1') } |
                ForEach-Object { $_.Name })
        }
        $resolved = Get-SourceTextAutoDetectedLanguage -AvailableCultures ($availableCultures -join ',')
    }
    Initialize-SourceTextLocalization -LanguageCode $resolved
    return $resolved
}

function Get-SourceTextLoc {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Alias('Args')][object[]]$Arguments = @()
    )

    $value = $null
    if ($script:SourceTextKeyAliases.ContainsKey($Key)) {
        $Key = $script:SourceTextKeyAliases[$Key]
    }
    if ($script:SourceTextLanguageData -and $script:SourceTextLanguageData.ContainsKey($Key)) {
        $value = [string]$script:SourceTextLanguageData[$Key]
    }
    elseif ($script:SourceTextDefaultLanguageData -and $script:SourceTextDefaultLanguageData.ContainsKey($Key)) {
        $value = [string]$script:SourceTextDefaultLanguageData[$Key]
    }
    else {
        if ($script:EmbeddedEnglishText.ContainsKey($Key)) {
            $value = [string]$script:EmbeddedEnglishText[$Key]
        }
        else {
            $value = "[MISSING TRANSLATION: $Key]"
        }
    }
    if ($Arguments.Count -gt 0) { return [string]::Format($value, $Arguments) }
    return $value
}
