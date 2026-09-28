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
    'summary.title'                            = 'Execution Summary'
    'summary.succeeded'                        = 'Succeeded'
    'summary.changed'                          = 'Changed'
    'summary.skipped'                          = 'Skipped'
    'summary.failed'                           = 'Failed'
}
$script:SourceTextKeyAliases = @{
    'uiText.environmentReady'            = 'uiText.environmentReadyForInstallation'
    'uiText.setupComplete'               = 'uiText.configurationComplete'
    'uiText.winget.missing'              = 'uiText.wingetNotFoundInSystem'
    'uiText.powershell.alreadyInstalled' = 'uiText.powershell7AlreadyInstalled'
    'uiText.terminal.alreadyInstalled'   = 'uiText.windowsTerminalIsAlreadyInstalled'
}

function Get-SourceTextLanguageDirectory {
    <#
    .SYNOPSIS
    Returns the first existing language directory, preferring the local sources.
    #>
    $root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    # Last resort: the per-user cache filled by Invoke-SourceTextLanguagePreparation.
    $candidates = @(
        (Join-Path $root 'languages'),
        (Join-Path (Split-Path $root -Parent) 'languages'),
        (Join-Path (Get-Location) 'languages'),
        $script:AppConfig.Paths.Languages
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


function Invoke-SourceTextLanguagePruning {
    <#
    .SYNOPSIS
    Removes cached language directories that are no longer present in the
    authoritative source (the remote culture list), keeping the local cache
    synchronized with the latest changes on every startup.
    #>
    [CmdletBinding()]
    param(
        [string]$LocalDir,
        [string[]]$AllowedCultures
    )
    if (-not (Test-Path $LocalDir)) { return }
    $allowed = @('en-US') + @($AllowedCultures | Where-Object { $_ -and $_.Trim() })
    $allowed = @($allowed | Select-Object -Unique)
    if ($allowed.Count -le 1) { return }
    foreach ($dir in (Get-ChildItem -Path $LocalDir -Directory -ErrorAction SilentlyContinue)) {
        if ($allowed -notcontains $dir.Name) {
            try {
                Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction Stop
                Write-Verbose "Pruned obsolete language directory: $($dir.Name)"
            }
            catch {
                Write-Verbose "Failed to prune language directory '$($dir.FullName)': $($_.Exception.Message)"
            }
        }
    }
}


function Invoke-SourceTextLanguagePreparation {
    [CmdletBinding()]
    param(
        [string]$ScriptRoot,
        [string]$RemoteBaseUrl = $script:AppConfig.URLs.LanguagesRawUrl,
        [string]$GitHubApiUrl = $script:AppConfig.URLs.LanguagesApiUrl
    )
    $localDir = $script:AppConfig.Paths.Languages
    $remoteCultures = Get-RemoteAvailableCultures -GitHubApiUrl $GitHubApiUrl
    if ($remoteCultures.Count -le 0) { return $localDir }

    $null = Initialize-Directory -Path $localDir

    # Sync the language cache with the reference branch on every startup:
    # remove cultures no longer present remotely, then download the latest
    # WinToolkit.psd1 for each available culture (overwriting any cached copy).
    Invoke-SourceTextLanguagePruning -LocalDir $localDir -AllowedCultures $remoteCultures

    foreach ($culture in (@('en-US') + $remoteCultures | Select-Object -Unique)) {
        $cultureDir = Initialize-Directory -Path (Join-Path $localDir $culture)
        $localFile = Join-Path $cultureDir 'WinToolkit.psd1'
        # Staged next to the target and swapped in: a half-written .psd1 must never
        # be picked up by the next Get-SourceTextValueFromData call.
        $stagedFile = Join-Path $cultureDir "WinToolkit.psd1.$([guid]::NewGuid()).tmp"
        try {
            $remoteUrl = "$RemoteBaseUrl/$culture/WinToolkit.psd1"
            if (-not (Invoke-DownloadFile -Uri $remoteUrl -OutFile $stagedFile -Silent)) {
                throw "Unable to download the language file for '$culture'."
            }
            Move-Item -LiteralPath $stagedFile -Destination $localFile -Force -ErrorAction Stop
        }
        catch {
            # Offline or unreachable branch: seed the cache from the local sources.
            if (-not (Test-Path $localFile)) {
                try {
                    $localFileFallback = Join-Path $ScriptRoot 'languages' $culture 'WinToolkit.psd1'
                    if (Test-Path $localFileFallback) { Copy-Item -LiteralPath $localFileFallback -Destination $localFile -Force }
                }
                catch {
                    Write-Warning "start-modules\20-Module.Localization.ps1, Invoke-SourceTextLanguagePreparation: $($_.Exception.Message)"
                }
            }
        }
        finally {
            if (Test-Path -LiteralPath $stagedFile) { Remove-Item -LiteralPath $stagedFile -Force -ErrorAction SilentlyContinue }
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


function Get-SourceTextValueFromData {
    <#
    .SYNOPSIS
    Looks a key up in the active language, then in the en-US fallback data.
    #>
    param([Parameter(Mandatory = $true)][string]$Key)

    if ($script:SourceTextLanguageData -and $script:SourceTextLanguageData.ContainsKey($Key)) {
        return [string]$script:SourceTextLanguageData[$Key]
    }
    if ($script:SourceTextDefaultLanguageData -and $script:SourceTextDefaultLanguageData.ContainsKey($Key)) {
        return [string]$script:SourceTextDefaultLanguageData[$Key]
    }
    return $null
}


function Get-SourceTextLoc {
    <#
    .SYNOPSIS
    Resolves a translation key, honouring aliases, numeric duplicates and the
    embedded English fallback, then formats it with Arguments when present.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Alias('Args')][object[]]$Arguments = @()
    )

    $resolvedKey = $Key
    if ($script:SourceTextKeyAliases.ContainsKey($resolvedKey)) {
        $resolvedKey = $script:SourceTextKeyAliases[$resolvedKey]
    }

    $value = Get-SourceTextValueFromData -Key $resolvedKey
    if ($null -eq $value -and $resolvedKey -match '^(.*?)(\d+)$') {
        # Collapse numeric duplicate keys (sourceText.completed2 -> sourceText.completed)
        # without touching the call sites.
        $value = Get-SourceTextValueFromData -Key $Matches[1]
    }
    if ($null -eq $value) {
        $value = if ($script:EmbeddedEnglishText.ContainsKey($resolvedKey)) {
            [string]$script:EmbeddedEnglishText[$resolvedKey]
        }
        else {
            "[MISSING TRANSLATION: $Key]"
        }
    }

    if ($Arguments.Count -gt 0) { return [string]::Format($value, $Arguments) }
    return $value
}


function Format-SourceText {
    <#
    .SYNOPSIS
    Composes a localized message from canonical verb/noun tokens to keep
    translation files small and generalized (infinitive verb + singular noun).

    .EXAMPLE
    Format-SourceText -Verb 'remove' -Noun 'folder'   # -> "Remove folder"
    #>
    [CmdletBinding()]
    param(
        [string]$Verb,
        [string]$Noun,
        [object[]]$Arguments = @()
    )

    $parts = @()
    if ($Verb) { $parts += (Get-SourceTextLoc "verb.$Verb") }
    if ($Noun) { $parts += (Get-SourceTextLoc "noun.$Noun") }
    $text = ($parts -join ' ').Trim()
    if ($Arguments -and $Arguments.Count -gt 0) { return [string]::Format($text, $Arguments) }
    return $text
}
