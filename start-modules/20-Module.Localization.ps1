# ============================================================================
# LOCALIZATION
# ============================================================================
#
# Resolution order: the per-user cache filled by
# Invoke-SourceTextLanguagePreparation, then the English strings embedded below,
# so the user never sees a raw "[MISSING TRANSLATION: ...]" placeholder for the
# messages that matter most. The active and default tables live on $script:State.

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
    Returns the per-user language cache directory.

    .DESCRIPTION
    The previous version searched $PSScriptRoot, its parent, the current
    directory and finally the cache. Under `irm | iex` $PSScriptRoot is empty, so
    the search effectively depended on the caller's working directory, and with
    the working directory at C:\ the parent lookup produced an empty string that
    made Join-Path throw. Loading translations from whatever happened to sit in the
    working directory is not something a bootstrapper should do: there is exactly
    one cache, and it is named in AppConfig.
    #>
    return $script:AppConfig.Paths.Languages
}


function Invoke-SourceTextLanguagePreparation {
    <#
    .SYNOPSIS
    Fetches the language files actually needed: en-US plus the resolved culture.

    .DESCRIPTION
    The previous flow called the unauthenticated GitHub contents API (60 requests
    per hour, shared by every user behind the same IP) on EVERY startup, then
    downloaded the .psd1 of every culture in the repository, then pruned the cache
    against that list. For a setup that displays one language, that is one
    avoidable API call plus N-2 pointless downloads.

    The language is resolved first (from the explicit request, then from the
    system UI culture) and only those two files are fetched. A missing culture
    simply falls back to en-US, which is the same outcome the old flow produced
    when the download failed.
    #>
    [CmdletBinding()]
    param(
        [string]$Culture = 'en-US',
        [string]$RemoteBaseUrl = $script:AppConfig.URLs.LanguagesRawUrl
    )

    $localDir = Initialize-Directory -Path $script:AppConfig.Paths.Languages
    $wanted = @('en-US')
    if ($Culture -and $Culture -ne 'en-US') { $wanted += $Culture }

    foreach ($culture in ($wanted | Select-Object -Unique)) {
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
            # Offline or unknown culture: keep whatever the cache already holds.
            Write-ToolkitLog -Level 'WARNING' -Message "Language file for '$culture' unavailable: $($_.Exception.Message)"
        }
        finally {
            Remove-PathQuietly -Path $stagedFile
        }
    }
    return $localDir
}


function Get-SourceTextAutoDetectedLanguage {
    <#
    .SYNOPSIS
    Maps the system UI culture onto one of the available culture FOLDERS.

    .DESCRIPTION
    The previous signature took the cultures as a comma separated string and
    re-split it, then returned the lowercased system culture instead of the
    folder name that actually exists on disk: with a folder named 'it-IT' and a
    system culture of 'it-it' the lookup missed every time. The list is now a
    proper [string[]] and the original list element is returned.
    #>
    param(
        [string[]]$AvailableCultures = @('en-US'),
        [string]$SystemUICulture = ($PSUICulture.ToString())
    )

    $normalizedSystem = $SystemUICulture.ToLowerInvariant()
    foreach ($culture in $AvailableCultures) {
        if ($culture -and $culture.ToLowerInvariant() -eq $normalizedSystem) { return $culture }
    }
    $neutralSystem = $normalizedSystem.Split('-')[0]
    foreach ($culture in $AvailableCultures) {
        if ($culture -and $culture.Split('-')[0].ToLowerInvariant() -eq $neutralSystem) { return $culture }
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

    $default = Import-SourceTextLanguageFile -LanguageCode 'en-US'
    if (-not $default) { $default = $script:EmbeddedEnglishText }
    $script:State.Text.Default = $default

    $active = Import-SourceTextLanguageFile -LanguageCode $LanguageCode
    $script:State.Text.Active = if ($active) { $active } else { $default }
}


function Resolve-SourceTextLanguage {
    <#
    .SYNOPSIS
    Resolves 'Auto' to a concrete culture and loads its translation table.

    .DESCRIPTION
    Called once by the orchestrator (90-Skeleton.Main.ps1) instead of running as
    script-level code, so that the language cache is only touched after logging
    is available and after the elevation/PowerShell 7 checks have passed.

    The culture is decided from the explicit request or from the system UI
    culture, and only that language plus en-US are downloaded (see
    Invoke-SourceTextLanguagePreparation).
    #>
    [CmdletBinding()]
    param([string]$RequestedLanguage = 'Auto')

    $culture = $RequestedLanguage
    if ([string]::IsNullOrWhiteSpace($culture) -or $culture -eq 'Auto') {
        $culture = Get-SourceTextAutoDetectedLanguage
    }
    $null = Invoke-SourceTextLanguagePreparation -Culture $culture
    Initialize-SourceTextLocalization -LanguageCode $culture
    return $culture
}


function Get-SourceTextValueFromData {
    <#
    .SYNOPSIS
    Looks a key up in the active language, then in the en-US fallback data.
    #>
    param([Parameter(Mandatory = $true)][string]$Key)

    if ($script:State.Text.Active -and $script:State.Text.Active.ContainsKey($Key)) {
        return [string]$script:State.Text.Active[$Key]
    }
    if ($script:State.Text.Default -and $script:State.Text.Default.ContainsKey($Key)) {
        return [string]$script:State.Text.Default[$Key]
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
