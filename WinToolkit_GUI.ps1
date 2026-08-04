<#
.SYNOPSIS
    WinToolkit GUI v3.1.0
.DESCRIPTION
    Refactored WinToolkit GUI that dynamically loads Core Script (WinToolkit.ps1)
    Features: Remote Core loading, dynamic menu generation, output bridging, version sync
.NOTES
    Version: Dynamic (extracted from Core)
    Architecture: Thin Client / Backend separation
    Author: MagnetarMan
#>

#Requires -Version 7.0

# 1. Flag to tell the Core to NOT show the menu (CRITICAL)
$Global:GuiSessionActive = $true

# =============================================================================
# GUI VERSION CONFIGURATION (Separate from Core Version)
# =============================================================================
$Global:GuiVersion = "3.1.0 (Build 12)"  # Format: CoreVersion.GuiBuildNumber

# =============================================================================
# CONFIGURATION AND CONSTANTS
# =============================================================================
$ScriptTitle = "WinToolkit GUI Edition by MagnetarMan"
$LogDirectory = "$env:LOCALAPPDATA\WinToolkit\logs"
$WindowWidth = 1280     # HD ready resolution in 16:9.
$WindowHeight = 720     # HD ready resolution in 16:9.
$FontFamily = "JetBrains Mono Nerd Font, Cascadia Code, Consolas, Courier New"
$FontSize = @{Small = 14; Medium = 16; Large = 18; Title = 20; Header = 28 }

# Emoji mappings for GUI elements
$emojiMappings = @{
    # Header and Branding
    "ToolIcon"                 = "🛠️"
    "SendErrorLogsImage"       = "📡"

    # Available Functions - Categories
    "CategorySystem"           = "⚙️"
    "CategoryMaintenance"      = "🔧"
    "CategoryOptimization"     = "🚀"
    "CategoryRepair"           = "🪛"
    "CategoryBackup"           = "💾"
    "CategoryTweaks"           = "⚡"

    # Script-specific Icons
    "ScriptPowerShell"         = "💻"
    "ScriptWinget"             = "📦"
    "ScriptCleaner"            = "🧹"
    "ScriptRepair"             = "🔧"
    "ScriptBackup"             = "💾"
    "ScriptUpdate"             = "🔄"
    "ScriptDriver"             = "🎮"
    "ScriptNetwork"            = "🌐"
    "ScriptPrivacy"            = "🔒"
    "ScriptPerformance"        = "🔧"
    "ScriptSecurity"           = "🛡️"
    "ScriptDebloat"            = "🔧"
    "ScriptTweak"              = "⚙️"

    # System Info Icons (for Image controls)
    "SysInfoTitleImage"        = "🛠️"
    "SysInfoEditionImage"      = "💿"
    "SysInfoVersionImage"      = "📊"
    "SysInfoArchitectureImage" = "⚙️"
    "SysInfoComputerNameImage" = "🏷️"
    "SysInfoRAMImage"          = "🧠"
    "SysInfoDiskImage"         = "💾"

    # Status LEDs
    "LEDStatusGreen"           = "🟢"
    "LEDStatusYellow"          = "🟡"
    "LEDStatusRed"             = "🧰"

    # Play Icon for Execute Button
    "ExecutePlayImage"         = "▶️"

    # Output and Log
    "OutputLogImage"           = "📋"

    # Execute Button
    "ExecuteButtonImage"       = "▶️"

    # Support Icon (Joystick)
    "SupportImage"             = "🕹️"

    # Bitlocker Icon
    "BitlockerImage"           = "🔒"
}

# =============================================================================
# EMOJI ICONS CONFIGURATION
# =============================================================================
$localIconBasePath = Join-Path $env:LOCALAPPDATA "WinToolkit\assets\png"
$remoteIconBasePath = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/assets/png"

# =============================================================================
# GLOBAL VARIABLES
# =============================================================================
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$mainLog = "$LogDirectory\WinToolkit_GUI_$dateTime.log"
$window = $null
$outputTextBox = $null
$executeButton = $null
$SysInfoEdition = $null
$SysInfoVersion = $null
$SysInfoArchitecture = $null
$SysInfoComputerName = $null
$SysInfoRAM = $null
$SysInfoDisk = $null
$SysInfoScriptCompatibility = $null
$SysInfoScriptCompatibilityImage = $null
$SysInfoBitlocker = $null
$progressBar = $null
$actionsPanel = $null

# Async execution variables (for GUI responsiveness)
$Global:ScriptJob = $null
$Global:JobMonitorTimer = $null
$Global:SelectedScriptsQueue = @()
$Global:CurrentScriptIndex = 0
$Global:LastJobOutputCount = 0
$Global:IsInputWaiting = $false
$Global:RebootRequired = $false
$Global:NeedsFinalReboot = $false

# Global variables to optimize RichTextBox logging
$Global:LastLogEntryType = $null
$Global:LastLogParagraphRef = $null

# =============================================================================
# CORE INTEGRATION CONFIGURATION
# =============================================================================

# Configuration for dynamic Core Script loading
$Global:CoreConfig = @{
    RemoteUrl         = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/WinToolkit.ps1"
    LocalCachePath    = "$env:LOCALAPPDATA\WinToolkit\cache\WinToolkit_Core.ps1"
    CacheMaxAge       = 3600 # seconds (1 hour)
    FallbackToCache   = $true
    RequiredFunctions = @('Get-SystemInfo', 'Write-StyledMessage', 'Show-Header', 'Initialize-ToolLogging')
}

# Variables for the loaded Core Script
$Global:CoreScriptContent = $null
$Global:CoreScriptVersion = "Unknown"
$Global:CoreScriptLoaded = $false
$Global:MenuStructure = @() # Will be populated by the Core
$Global:SourceTextLanguage = 'en-US'
$Global:SourceTextLanguageData = $null
$Global:SourceTextDefaultLanguageData = $null
# =============================================================================
# LOGGING AND UTILITY FUNCTIONS
# =============================================================================

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
                Code       = if ($data.ContainsKey('language.code')) { $data['language.code'] } else { $_.Name }
                Name       = if ($data.ContainsKey('language.name')) { $data['language.name'] } else { $_.Name }
                NativeName = if ($data.ContainsKey('language.nativeName')) { $data['language.nativeName'] } else { $_.Name }
                Path       = $_.FullName
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
        [object[]]$Args = @()
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

    if ($Args -and $Args.Count -gt 0) { return [string]::Format($value, $Args) }
    return $value
}

function Get-ToolkitMenuText {
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
    param([string]$GitHubApiUrl = 'https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=Dev')
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
        [string]$RemoteBaseUrl = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/languages',
        [string]$GitHubApiUrl = 'https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=Dev'
    )
    $localDir = Join-Path $env:LOCALAPPDATA 'WinToolkit\languages'
    $remoteCultures = Get-RemoteAvailableCultures -GitHubApiUrl $GitHubApiUrl
    if ($remoteCultures.Count -gt 0) {
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
                Write-Host "WARNING: Failed to download language file for '$culture': $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
    $Global:SourceTextPreparedLanguagesDir = $localDir
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

# Detect the operating system UI culture on every script load.
Invoke-SourceTextLanguagePreparation -ScriptRoot $(if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path })
$availableCultures = (Get-AvailableSourceTextLanguages).Code -join ','
if ([string]::IsNullOrWhiteSpace($availableCultures)) { $availableCultures = 'en-US' }
$detectedLanguage = Get-SourceTextAutoDetectedLanguage -AvailableCultures $availableCultures
Set-SourceTextLanguage -LanguageCode $detectedLanguage
$Global:SourceTextLanguageDirectory = Get-SourceTextLanguageDirectory

function Write-UnifiedLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)][string]$Type, # 'Info', 'Warning', 'Error', 'Success', 'Progress'
        [string]$GuiColor = "#FFFFFF" # Default if not determined by Type
    )

    $consoleColors = @{
        Info     = 'Cyan'
        Warning  = 'Yellow'
        Error    = 'Red'
        Success  = 'Green'
        Progress = 'Magenta'
    }
    $currentDateTime = Get-Date -Format 'HH:mm:ss'
    $logPrefix = "[$currentDateTime] [$Type]"
    $formattedMessage = "$logPrefix $Message"

    # Write to console (unchanged)
    try {
        Write-Host "$formattedMessage" -ForegroundColor $consoleColors[$Type]
    }
    catch {
        # Silently fail console output
    }

    # Write to GUI OutputTextBox (if available)
    if ($outputTextBox -and $window -and $window.Dispatcher) {
        try {
            $window.Dispatcher.Invoke([Action] {
                    # Determine Foreground Color and FontWeight based on Type
                    $runForeground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($GuiColor))
                    $runFontWeight = [System.Windows.FontWeights]::Normal

                    switch -Wildcard ($Type.ToLower()) {
                        "error" { $runForeground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#FF5555")); $runFontWeight = [System.Windows.FontWeights]::Bold }
                        "warning" { $runForeground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")) }
                        "success" { $runForeground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#4CAF50")); $runFontWeight = [System.Windows.FontWeights]::Bold }
                        "progress" { $runForeground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#2196F3")) }
                        default { } # Defaults to GuiColor or falls through
                    }

                    $paragraph = $Global:LastLogParagraphRef

                    # Create a new paragraph if:
                    # 1. It's the very first message.
                    # 2. The message Type has changed since the last message.
                    # 3. The last paragraph reference is invalid or not a Paragraph (e.g., after Clear()).
                    if (-not $paragraph -or ($Type -ne $Global:LastLogEntryType) -or (-not ($paragraph -is [System.Windows.Documents.Paragraph]))) {
                        $paragraph = New-Object System.Windows.Documents.Paragraph
                        $paragraph.Margin = New-Object System.Windows.Thickness(0, 2, 0, 2)
                        $outputTextBox.Document.Blocks.Add($paragraph)

                        # Update global tracking variables
                        $Global:LastLogParagraphRef = $paragraph
                        $Global:LastLogEntryType = $Type
                    }

                    # Create a Run for the current message
                    $run = New-Object System.Windows.Documents.Run
                    $run.Text = "${formattedMessage}" + "`n" # Add newline at the end of each run for visual separation
                    $run.Foreground = $runForeground
                    $run.FontWeight = $runFontWeight

                    $paragraph.Inlines.Add($run)
                    $outputTextBox.ScrollToEnd()
                })
        }
        catch {
            # Silently fail GUI logging if there are issues
        }
    }
}

# =============================================================================
# CORE SCRIPT LOADER MODULE
# =============================================================================

function Initialize-CoreScript {
    <#
    .SYNOPSIS
        Loads the Core Script (WinToolkit.ps1) from remote source or local cache.

    .DESCRIPTION
        Manages downloading the Core Script from GitHub, local caching, version extraction,
        and dot-sourcing functions into the current scope.
        Implements remote vs local version comparison to optimize downloads.

    .OUTPUTS
        Boolean - True if Core loaded successfully, False otherwise
    #>

    [CmdletBinding()]
    param()

    try {
        # Show loading screen
        Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.resourceInitializationCoreScriptLoading') -GuiColor "#00CED1"
        Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.pleaseWaitOperationInProgress') -GuiColor "#FFA500"

        # Create cache directory if it doesn't exist
        $cacheDir = Split-Path $Global:CoreConfig.LocalCachePath -Parent
        if (-not (Test-Path $cacheDir)) {
            New-Item -Path $cacheDir -ItemType Directory -Force | Out-Null
        }

        $coreContent = $null
        $usedCache = $false
        $localCoreNumericVersion = [version]"0.0.0" # Numeric version for comparison
        $localCoreFullVersion = "Unknown" # Full version string for display

        # 1. Retrieve the local Core Script version (if cache exists)
        if (Test-Path $Global:CoreConfig.LocalCachePath) {
            try {
                # Read the entire content for greater robustness
                $localCacheRawContent = Get-Content $Global:CoreConfig.LocalCachePath -Raw -Encoding UTF8
                if ($localCacheRawContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
                    $localCoreFullVersion = $matches[1]
                    # Extract the numeric part for comparison (e.g. "2.5.1" from "2.5.1 (Build 6)")
                    if ($localCoreFullVersion -match '(\d+(?:\.\d+){0,3})') {
                        $localCoreNumericVersion = [version]$matches[1]
                        Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.localCoreVersionFound0Numeric1' -Args @($localCoreFullVersion, $localCoreNumericVersion)) -GuiColor "#00CED1"
                    }
                    else {
                        Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.unableToExtractNumericPartFromLocale0IAssume000ForComparison' -Args @($localCoreFullVersion)) -GuiColor "#FFA500"
                    }
                }
                else {
                    Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.unableToExtractVersionFromLocalCacheIAssume000ForComparison') -GuiColor "#FFA500"
                }
            }
            catch {
                Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.errorReadingLocalCacheVersion0' -Args @($($_.Exception.Message))) -GuiColor "#FFA500"
            }
        }

        # 2. Retrieve the remote Core Script version
        $remoteCoreNumericVersion = [version]"0.0.0"
        $remoteCoreFullVersion = "Unknown"
        Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.remoteCoreScriptVersionRecovery') -GuiColor "#00CED1"
        try {
            # Use Invoke-RestMethod to retrieve the complete content for robust parsing
            $remoteRawContent = Invoke-RestMethod -Uri $Global:CoreConfig.RemoteUrl -UseBasicParsing -ErrorAction Stop
            if ($remoteRawContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
                $remoteCoreFullVersion = $matches[1]
                if ($remoteCoreFullVersion -match '(\d+(?:\.\d+){0,3})') {
                    $remoteCoreNumericVersion = [version]$matches[1]
                    Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.remoteCoreVersionDetected0Numeric1' -Args @($remoteCoreFullVersion, $remoteCoreNumericVersion)) -GuiColor "#00CED1"
                }
                else {
                    Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.unableToExtractNumericPartFromRemoteVersion0IAssume000ForComparison' -Args @($remoteCoreFullVersion)) -GuiColor "#FFA500"
                }
            }
            else {
                Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.unableToExtractRemoteVersionFromCoreScriptIAssume000ForComparison') -GuiColor "#FFA500"
            }
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.failedToGetRemoteVersion0AForcedDownloadOrFallbackMayBeRequired' -Args @($($_.Exception.Message))) -GuiColor "#FFA500"
        }

        # 3. Determine whether the Core Script needs to be downloaded
        $shouldDownload = $false
        $cacheExists = Test-Path $Global:CoreConfig.LocalCachePath
        $cacheExpired = $false

        if ($cacheExists) {
            $cacheAge = (Get-Date) - (Get-Item $Global:CoreConfig.LocalCachePath).LastWriteTime
            $cacheExpired = ($cacheAge.TotalSeconds -ge $Global:CoreConfig.CacheMaxAge)
        }

        if (-not $cacheExists) {
            Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.noLocalCacheFoundForcedDownload') -GuiColor "#00CED1"
            $shouldDownload = $true
        }
        elseif ($remoteCoreNumericVersion -gt $localCoreNumericVersion) {
            Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.newCoreVersion0AvailableCurrent1DownloadInProgress' -Args @($remoteCoreFullVersion, $localCoreFullVersion)) -GuiColor "#00CED1"
            $shouldDownload = $true
        }
        elseif ($cacheExpired) {
            Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.localCacheExpiredAge0MinutesDownloadToUpdate' -Args @($([Math]::Round($cacheAge.TotalMinutes, 1)))) -GuiColor "#FFA500"
            $shouldDownload = $true
        }
        else {
            Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.validAndUpdatedLocalCacheV0CacheUsage' -Args @($localCoreFullVersion)) -GuiColor "#00FF00"
            $coreContent = Get-Content $Global:CoreConfig.LocalCachePath -Raw -Encoding UTF8
            $usedCache = $true
            $Global:CoreScriptVersion = $localCoreFullVersion
        }

        if ($shouldDownload) {
            Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.downloadCoreScriptDaGithub') -GuiColor "#00CED1"
            Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.url0' -Args @($($Global:CoreConfig.RemoteUrl))) -GuiColor "#808080"

            try {
                $downloadParams = @{
                    Uri             = $Global:CoreConfig.RemoteUrl
                    OutFile         = $Global:CoreConfig.LocalCachePath
                    UseBasicParsing = $true
                    ErrorAction     = 'Stop'
                }

                Invoke-WebRequest @downloadParams
                $coreContent = Get-Content $Global:CoreConfig.LocalCachePath -Raw -Encoding UTF8
                Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.coreScriptDownloadedSuccessfully') -GuiColor "#00FF00"
                Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.cached0' -Args @($($Global:CoreConfig.LocalCachePath))) -GuiColor "#00CED1"

                # Extract the version from the newly downloaded Core (full string for display)
                if ($coreContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
                    $Global:CoreScriptVersion = $matches[1]
                    Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.coreVersionDownloaded0' -Args @($Global:CoreScriptVersion)) -GuiColor "#00FF00"
                }
                else {
                    Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.unableToExtractVersionFromNewlyDownloadedCore') -GuiColor "#FFA500"
                    $Global:CoreScriptVersion = "Unknown"
                }

            }
            catch {
                Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.downloadFailed0' -Args @($($_.Exception.Message))) -GuiColor "#FFA500"

                if ($cacheExists -and $Global:CoreConfig.FallbackToCache) {
                    Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.usingLocalCacheExpiredOrOlderButAvailableAsAFallback') -GuiColor "#FFA500"
                    $coreContent = Get-Content $Global:CoreConfig.LocalCachePath -Raw -Encoding UTF8
                    $usedCache = $true
                    # Re-extract the version from the cache as a fallback
                    if ($coreContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
                        $Global:CoreScriptVersion = $matches[1]
                        Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.coreVersionFromFallbackCache0' -Args @($Global:CoreScriptVersion)) -GuiColor "#00FF00"
                    }
                }
                else {
                    throw (Get-SourceTextLoc 'uiText.unableToDownloadCoreScriptAndNoCacheAvailableConfiguredForFallback')
                }
            }
        }

        # If the cache was used without a download, ensure that $Global:CoreScriptVersion is set correctly
        if ($usedCache -and ([string]::IsNullOrEmpty($Global:CoreScriptVersion) -or $Global:CoreScriptVersion -eq "Unknown")) {
            if ($coreContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
                $Global:CoreScriptVersion = $matches[1]
            }
        }

        if (-not $coreContent) {
            throw (Get-SourceTextLoc 'sourceText.coreScriptContentIsEmptyAfterLoadingAttempts')
        }

        # NOTE: Loading moved to main scope to fix variable visibility
        $Global:CoreScriptContent = $coreContent
        $Global:CoreScriptLoaded = $true

        Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.initializationCompleteGuiReadyToUse') -GuiColor "#00FF00"
        Write-Host ""

        return $true
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.criticalErrorWhileLoadingCore0' -Args @($($_.Exception.Message))) -GuiColor "#FF0000"
        Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.tipManuallyDownloadWintoolkitPs1From') -GuiColor "#00CED1"
        Write-UnifiedLog -Type 'Info' -Message "   $($Global:CoreConfig.RemoteUrl)" -GuiColor "#808080"
        Write-UnifiedLog -Type 'Info' -Message ("   " + (Get-SourceTextLoc 'uiText.andSaveItIn0' -Args @($($Global:CoreConfig.LocalCachePath)))) -GuiColor "#808080"

        $Global:CoreScriptLoaded = $false
        return $false
    }
}

# =============================================================================
# EMOJI ICONS HELPER FUNCTIONS
# =============================================================================

function Get-EmojiIconPath {
    param ([string]$EmojiCharacter)

    if ([string]::IsNullOrEmpty($EmojiCharacter)) {
        return $null
    }

    try {
        $bytes = [System.Text.Encoding]::UTF32.GetBytes($EmojiCharacter)
        if ($bytes.Length -lt 4) {
            return $null
        }
        $codepoint = [BitConverter]::ToUInt32($bytes, 0).ToString("X")
        $fileName = "U+$codepoint.png"
        $fullPath = Join-Path $localIconBasePath $fileName
        return $fullPath
    }
    catch {
        return $null
    }
}

# Helper function to load icon with emoji fallback
function Get-IconWithFallback {
    param(
        [string]$EmojiCharacter,
        [string]$FallbackText = "?"
    )

    $iconPath = Get-EmojiIconPath -EmojiCharacter $EmojiCharacter

    # If the file exists locally, return the path
    if ($iconPath -and (Test-Path $iconPath)) {
        return $iconPath
    }

    # Otherwise return null to indicate using the emoji as fallback
    return $null
}

function Split-EmojiAndText {
    param ([string]$InputString)

    $parts = $InputString -split ' ', 2

    if ($parts.Length -ge 2) {
        return @{
            Emoji = $parts[0]
            Text  = $parts[1]
        }
    }
    else {
        return @{
            Emoji = ""
            Text  = $InputString
        }
    }
}

function Test-EmojiIcons {
    param(
        [Parameter(Mandatory = $true)][hashtable]$EmojiMap,
        [Parameter(Mandatory = $true)][string]$LocalPath,
        [Parameter(Mandatory = $true)][string]$RemotePath
    )
    Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.ensuringAllRequiredIconsAreAvailableLocally') -GuiColor "#00CED1"
    try {
        foreach ($key in $EmojiMap.Keys) {
            $emojiChar = $EmojiMap[$key]
            $localIconFile = Get-EmojiIconPath -EmojiCharacter $emojiChar

            if ([string]::IsNullOrEmpty($localIconFile)) {
                Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.couldNotGetLocalPathForEmoji0Skipping' -Args @($emojiChar)) -GuiColor "#FFA500"
                continue
            }

            if (-not (Test-Path $localIconFile)) {
                $fileName = Split-Path $localIconFile -Leaf
                $remoteIconUri = "$RemotePath/$fileName"

                Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.downloadingIconFor0From1' -Args @($emojiChar, $remoteIconUri)) -GuiColor "#00CED1"
                try {
                    Invoke-WebRequest -Uri $remoteIconUri -OutFile $localIconFile -UseBasicParsing -ErrorAction Stop | Out-Null
                    Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.downloaded0' -Args @($fileName)) -GuiColor "#00FF00"
                }
                catch {
                    Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.failedToDownloadIcon01' -Args @($fileName, $($_.Exception.Message))) -GuiColor "#FF0000"
                }
            }
        }
        Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.iconAvailabilityCheckCompleted') -GuiColor "#00FF00"
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.errorDuringIconSynchronization0' -Args @($($_.Exception.Message))) -GuiColor "#FF0000"
    }
}

function Get-AllCheckBoxes {
    <#
    .SYNOPSIS
        Helper function to recursively find all CheckBoxes in a container.
    #>
    param([System.Windows.Controls.Panel]$Container)

    $checkBoxes = @()

    foreach ($child in $Container.Children) {
        if ($child -is [System.Windows.Controls.CheckBox]) {
            $checkBoxes += $child
        }
        elseif ($child -is [System.Windows.Controls.Panel]) {
            # Recursively search StackPanel containers
            $checkBoxes += Get-AllCheckBoxes -Container $child
        }
    }

    return $checkBoxes
}

function Send-ErrorLogs {
    <#
    .SYNOPSIS
        Generates and sends GUI-SPECIFIC error logs and any recent Core logs
        to facilitate GUI bug reporting.
    #>
    try {
        Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.preparingGuiErrorLogForReporting') -GuiColor "#00CED1"

        # Include the main GUI log and the most recent Core transcripts
        $recentLogFiles = @($mainLog) # The GUI log itself

        # Find the most recent Core logs in the AppData directory
        $coreLogDir = "$env:LOCALAPPDATA\WinToolkit\logs"
        if (Test-Path $coreLogDir) {
            # Select the 3 most recent Core logs (excluding the GUI log if it appears twice)
            $coreTranscripts = Get-ChildItem -Path $coreLogDir -Filter "*.log" -ErrorAction SilentlyContinue |
            Sort-Object -Property LastWriteTime -Descending | Select-Object -First 3
            $recentLogFiles += $coreTranscripts.FullName | Where-Object { $_ -ne $mainLog }
        }
        $recentLogFiles = $recentLogFiles | Select-Object -Unique # Remove duplicates

        if (-not $recentLogFiles) {
            Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.noGuiOrCoreLogFilesFoundForReporting') -GuiColor "#FFA500"
            return
        }

        # Create the JSON metadata file contents
        $metadata = @{
            Timestamp     = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            GuiVersion    = $Global:GuiVersion
            CoreVersion   = $Global:CoreScriptVersion
            CorrelationId = if ($Global:CurrentCorrelationId) { $Global:CurrentCorrelationId } else { "N/A" }
            OS            = (Get-CimInstance Win32_OperatingSystem).Caption
            OSVersion     = (Get-CimInstance Win32_OperatingSystem).Version
            MachineName   = $env:COMPUTERNAME
        }
        $metadataPath = Join-Path $env:TEMP "metadata.json"
        $metadata | ConvertTo-Json | Out-File -FilePath $metadataPath -Encoding UTF8 -Force

        # Create a README for the log package
        $readmeContent = @"
WinToolkit Support Log Package
============================
Timestamp: $($metadata.Timestamp)
CorrelationId: $($metadata.CorrelationId)
GUI Version: $($metadata.GuiVersion)
Core Version: $($metadata.CoreVersion)
OS: $($metadata.OS) ($($metadata.OSVersion))
Machine: $($metadata.MachineName)

Contents:
- metadata.json: Session metadata
- README.txt: This file
- WinToolkit_GUI_ErrorReport_*.txt: Combined log report
- Core logs from %LOCALAPPDATA%\WinToolkit\logs (if included)

Usage:
Attach this zip file when reporting issues. The CorrelationId links logs across tools and GUI sessions.
"@
        $readmePath = Join-Path $env:TEMP "README.txt"
        $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8 -Force

        # Create the combined log contents
        $logContent = "=" * 60 + "`n"
        $logContent += "WinToolkit GUI Error Report`n"
        $logContent += (Get-SourceTextLoc 'uiText.reportDate0' -Args @($metadata.Timestamp)) + "`n"
        $logContent += "CorrelationId: $($metadata.CorrelationId)`n"
        $logContent += (Get-SourceTextLoc 'uiText.guiVersion0' -Args @($metadata.GuiVersion)) + "`n"
        $logContent += (Get-SourceTextLoc 'uiText.reportCoreVersion0' -Args @($metadata.CoreVersion)) + "`n"
        $logContent += "=" * 60 + "`n`n"

        foreach ($logFile in $recentLogFiles) {
            $logContent += "--- $($logFile | Split-Path -Leaf) ---`n"
            $logContent += (Get-Content -Path $logFile -ErrorAction SilentlyContinue -Raw)
            $logContent += "`n`n"
        }

        # Save the temporary report
        $tempReportPath = Join-Path $env:TEMP "WinToolkit_GUI_ErrorReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $logContent | Out-File -FilePath $tempReportPath -Encoding UTF8 -Force

        # Compress the report and metadata into a ZIP file on the Desktop
        $zipPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "WinToolkit_SupportLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
        if (Get-Command 'Compress-Archive' -ErrorAction SilentlyContinue) {
            Compress-Archive -Path $tempReportPath, $metadataPath, $readmePath -DestinationPath $zipPath -Force
            Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.supportLogPackageCreated0' -Args @($zipPath)) -GuiColor "#00FF00"
        }
        else {
            Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.compressArchiveNotAvailableGuiReportSavedIn0' -Args @($tempReportPath)) -GuiColor "#FFA500"
            $zipPath = $tempReportPath # If it cannot be zipped, use the .txt path for the final message
        }

        # Delete the temporary report if it was successfully zipped
        if (Test-Path $tempReportPath -PathType Leaf) {
            Remove-Item $tempReportPath -ErrorAction SilentlyContinue
        }

        # Open the default browser to the GitHub Issues page
        try {
            Start-Process -FilePath "https://github.com/Magnetarman/WinToolkit/issues/new?template=bug_report.yml"
            Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.browserOpenForReportingOnGithub') -GuiColor "#00CED1"
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.unableToOpenBrowser0' -Args @($($_.Exception.Message))) -GuiColor "#FFA500"
        }

        # Write the final message to the Output box
        $window.Dispatcher.Invoke([Action] {
                $paragraph = New-Object System.Windows.Documents.Paragraph
                $run = New-Object System.Windows.Documents.Run
                $run.Text = Get-SourceTextLoc 'uiText.sendSupportArchive0' -Args @($zipPath)
                $run.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#00FF00"))
                $run.FontWeight = [System.Windows.FontWeights]::Bold
                $paragraph.Inlines.Add($run)
                $outputTextBox.Document.Blocks.Add($paragraph)
                $outputTextBox.ScrollToEnd()
            })

        Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.operationCompleted') -GuiColor "#00FF00"
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.errorPreparingGuiLogs0' -Args @($($_.Exception.Message))) -GuiColor "#FF0000"
    }
}

# =============================================================================
# LOAD ALL TOOL SCRIPTS INTO GLOBAL SCOPE (before any job execution)
# =============================================================================
# NOTE: This section has been removed. All tool functions are now defined
# in the Core Script (WinToolkit.ps1) and are loaded when the Core Script
# is dot-sourced. The job now only needs to load the Core Script to access
# all tool functions.
# $Global:ToolScriptsPath = Join-Path $PSScriptRoot "tools"

# function Load-AllToolScripts { ... } # REMOVED - All functions are in Core Script

# Initial load count is 0 since functions are loaded via Core Script
$Global:ToolScriptsLoadedCount = 0

# =============================================================================
# INITIALIZATION
# =============================================================================

# Create log directory
try {
    [System.IO.Directory]::CreateDirectory($LogDirectory) | Out-Null
    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}
    Start-Transcript -Path $mainLog -Append -Force | Out-Null
    Write-Host (Get-SourceTextLoc 'uiText.infoLoggingInitializedTo0' -Args @($mainLog)) -ForegroundColor Cyan
}
catch {
    Write-Host (Get-SourceTextLoc 'uiText.errorFailedToInitializeLogging0' -Args @($($_.Exception.Message))) -ForegroundColor Red
}

# Create icon cache directory
try {
    if (-not (Test-Path $localIconBasePath)) {
        [System.IO.Directory]::CreateDirectory($localIconBasePath) | Out-Null
    }
}
catch {
    Write-Host (Get-SourceTextLoc 'uiText.errorFailedToCreateIconDirectory0' -Args @($($_.Exception.Message))) -ForegroundColor Red
}

# Download and cache all required icons
Test-EmojiIcons -EmojiMap $emojiMappings -LocalPath $localIconBasePath -RemotePath $remoteIconBasePath

# Check administrator privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host (Get-SourceTextLoc 'uiText.errorAdministratorPrivilegesRequired') -ForegroundColor Red
    exit
}

Write-Host (Get-SourceTextLoc 'uiText.infoAdministratorPrivilegesConfirmed') -ForegroundColor Green

# Load WPF assemblies
$assemblies = @("PresentationFramework", "PresentationCore", "WindowsBase", "System.Windows.Forms")
foreach ($assembly in $assemblies) {
    try {
        Add-Type -AssemblyName $assembly -ErrorAction Stop
        Write-Host (Get-SourceTextLoc 'uiText.successLoaded0' -Args @($assembly)) -ForegroundColor Green
    }
    catch {
        Write-Host (Get-SourceTextLoc 'uiText.errorFailedToLoad01' -Args @($assembly, $($_.Exception.Message))) -ForegroundColor Red
    }
}

# ==========================================
# INITIALIZE CORE SCRIPT (CRITICAL STEP)
# ==========================================

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ("  " + (Get-SourceTextLoc 'uiText.wintoolkitGuiV30GuiEdition')) -ForegroundColor White
Write-Host ("  " + (Get-SourceTextLoc 'uiText.loadingCoreScript')) -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

$coreLoaded = Initialize-CoreScript

if (-not $coreLoaded) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ("  " + (Get-SourceTextLoc 'uiText.fatalErrorCoreScriptLoadingFailed')) -ForegroundColor Red
    Write-Host ("  " + (Get-SourceTextLoc 'uiText.theGuiCannotContinueWithoutTheCoreScript')) -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Read-Host (Get-SourceTextLoc 'uiText.pressEnterToExit')
    exit
}

# ==========================================
# EXECUTE CORE SCRIPT (SCOPE FIX)
# ==========================================
try {
    Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.loadingCoreFunctionsIntoMemoryGlobalScope') -GuiColor "#00CED1"

    # Dot-sourcing in the current scope (Script/Global)
    # Use the local path ensured by Initialize-CoreScript
    . $Global:CoreConfig.LocalCachePath

    # Retrieve $menuStructure after loading
    if ($menuStructure) {
        $Global:MenuStructure = $menuStructure
        Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.menuStructureLoadedCategories0' -Args @($($Global:MenuStructure.Count))) -GuiColor "#00FF00"
    }
    else {
        Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.0NotFoundAfterLoading' -Args @($menuStructure)) -GuiColor "#FFA500"
    }

    # Verify critical functions
    if (Get-Command 'Get-SystemInfo' -ErrorAction SilentlyContinue) {
        Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.getSysteminfoFunctionAvailable') -GuiColor "#00FF00"
    }
    else {
        Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.getSysteminfoFunctionNotFound') -GuiColor "#FF0000"
    }

}
catch {
    Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.errorDuringDotSourcingCore0' -Args @($($_.Exception.Message))) -GuiColor "#FF0000"
}

# =============================================================================
# GUI LOCALIZATION OVERRIDES
# Re-apply after core dot-sourcing so cached/remote cores cannot overwrite them.
# =============================================================================

function Get-GuiMenuLocalizationKey {
    param([object]$Item)

    $name = $null
    if ($Item -is [System.Collections.IDictionary]) {
        if ($Item.Contains('CategoryKey') -and $Item['CategoryKey']) { return $Item['CategoryKey'] }
        if ($Item.Contains('DescriptionKey') -and $Item['DescriptionKey']) { return $Item['DescriptionKey'] }
        if ($Item.Contains('Name')) { $name = [string]$Item['Name'] }
    }
    else {
        if ($Item.PSObject.Properties.Name -contains 'CategoryKey' -and $Item.CategoryKey) { return $Item.CategoryKey }
        if ($Item.PSObject.Properties.Name -contains 'DescriptionKey' -and $Item.DescriptionKey) { return $Item.DescriptionKey }
        if ($Item.PSObject.Properties.Name -contains 'Name') { $name = [string]$Item.Name }
    }

    switch -Regex ($name) {
        '^Windows$' { return 'category.windows' }
        '^Office$' { return 'category.office' }
        '^Driver & Gaming$' { return 'category.driverGaming' }
        '^(Supporto|Support)$' { return 'category.support' }
        default {
            if (-not [string]::IsNullOrWhiteSpace($name)) { return "script.$name" }
        }
    }

    return $null
}

function Get-ToolkitMenuText {
    param([object]$Item)

    $key = Get-GuiMenuLocalizationKey -Item $Item
    if ($key) {
        $localized = Get-SourceTextLoc $key
        if ($localized -ne $key) { return $localized }
    }

    if ($Item -is [System.Collections.IDictionary]) {
        if ($Item.Contains('Description')) { return $Item['Description'] }
        if ($Item.Contains('Name')) { return $Item['Name'] }
    }
    else {
        if ($Item.PSObject.Properties.Name -contains 'Description') { return $Item.Description }
        if ($Item.PSObject.Properties.Name -contains 'Name') { return $Item.Name }
    }

    return [string]$Item
}

function Convert-GuiBitlockerStatusToKey {
    param([string]$StatusText)

    if ([string]::IsNullOrWhiteSpace($StatusText)) { return 'bitlocker.status.notConfigured' }

    $normalized = $StatusText.Trim().ToLowerInvariant()
    if ($normalized -match 'decritt|decrypt') { return 'bitlocker.status.decrypting' }
    if ($normalized -match 'crittografia in corso|encrypt') { return 'bitlocker.status.encrypting' }
    if ($normalized -match 'sospes|suspend') { return 'bitlocker.status.suspended' }
    if ($normalized -match 'non configur|not configured') { return 'bitlocker.status.notConfigured' }
    if ($normalized -match 'disattiv|protection off|off|disabled') { return 'bitlocker.status.off' }
    if ($normalized -match 'attiv|protection on|on|enabled') { return 'bitlocker.status.on' }

    return 'bitlocker.status.unknown'
}

function Get-GuiBitlockerStatusKey {
    $command = Get-Command 'Get-BitlockerStatus' -ErrorAction SilentlyContinue
    if ($command -and $command.Parameters.ContainsKey('Key')) {
        $statusKey = Get-BitlockerStatus -Key
        if ($statusKey -match '^bitlocker\.status\.') { return $statusKey }
    }

    $statusText = if ($command) { Get-BitlockerStatus } else { $null }
    return (Convert-GuiBitlockerStatusToKey -StatusText $statusText)
}

# =============================================================================
# WPF GUI DEFINITION
# =============================================================================

$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="$($ScriptTitle) - v$($Global:CoreScriptVersion)"
    Height="$($WindowHeight)"
    Width="$($WindowWidth)"
    WindowStartupLocation="CenterScreen">

    <Window.Resources>
        <!-- New Color Palette from Gui.jpg -->
        <SolidColorBrush x:Key="BackgroundDark" Color="#FF1E1E1E"/>
        <SolidColorBrush x:Key="BackgroundColor" Color="#FF2D2D2D"/>
        <SolidColorBrush x:Key="HeaderBackgroundColor" Color="#FF1A1A1A"/>
        <SolidColorBrush x:Key="PanelBackgroundColor" Color="#FF3D3D3D"/>
        <SolidColorBrush x:Key="TextColor" Color="#FFFFFFFF"/>
        <SolidColorBrush x:Key="LabelBlue" Color="#FF4FC3F7"/>
        <SolidColorBrush x:Key="DescriptionGray" Color="#FFBDBDBD"/>
        <SolidColorBrush x:Key="SeparatorGreen" Color="#FF2E7D32"/>
        <SolidColorBrush x:Key="ExecuteButtonColor" Color="#FF2196F3"/>
        <SolidColorBrush x:Key="ErrorButtonColor" Color="#FFD32F2F"/>
        <SolidColorBrush x:Key="SuccessColor" Color="#FF00FF00"/>
        <SolidColorBrush x:Key="BorderColor" Color="#FF0078D4"/>
        <SolidColorBrush x:Key="OutputBackgroundColor" Color="#FF1A1A1A"/>
        <SolidColorBrush x:Key="LEDGreenColor" Color="#FF4CAF50"/>
        <FontFamily x:Key="PrimaryFont">$FontFamily</FontFamily>

        <!-- Button Styles for CornerRadius (workaround for PowerShell XAML parsing) -->
        <Style x:Key="PillButtonStyle" TargetType="Button">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="25"
                                Padding="{TemplateBinding Padding}"
                                BorderThickness="{TemplateBinding BorderThickness}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                              VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SmallButtonStyle" TargetType="Button">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="8"
                                Padding="{TemplateBinding Padding}"
                                BorderThickness="{TemplateBinding BorderThickness}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                              VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Style for a rounded ProgressBar (Pill) -->
        <Style x:Key="PillProgressBarStyle" TargetType="ProgressBar">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid>
                            <Border x:Name="PART_Track"
                                    Background="{TemplateBinding Background}"
                                    BorderBrush="{TemplateBinding BorderBrush}"
                                    BorderThickness="{TemplateBinding BorderThickness}"
                                    CornerRadius="10" />
                            <Border x:Name="PART_Indicator"
                                    Background="{TemplateBinding Foreground}"
                                    CornerRadius="10"
                                    HorizontalAlignment="Left" />
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Background="{StaticResource BackgroundDark}">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Task 1: Header with 3 columns and CornerRadius -->
        <Border Grid.Row="0" Background="{StaticResource HeaderBackgroundColor}"
                Padding="16" Margin="16,16,16,8" CornerRadius="12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <!-- Column 0: Tool icon -->
                <Image Grid.Column="0" x:Name="ToolIconImage"
                       Source="/images/WinToolkit-icon.png"
                       Width="96" Height="96"
                       VerticalAlignment="Center" Margin="0,0,16,0"/>

                <!-- Column 1: Centered title, subtitle, and language selection -->
                <StackPanel Grid.Column="1" VerticalAlignment="Center" HorizontalAlignment="Center">
                    <TextBlock Text="$($ScriptTitle)"
                               FontSize="$($FontSize.Header)" FontWeight="Bold"
                               Foreground="{StaticResource TextColor}"
                               FontFamily="{StaticResource PrimaryFont}"
                               TextAlignment="Center"/>
                    <TextBlock x:Name="GuiEditionVersionsText" Text="GUI Edition v$($Global:GuiVersion) | Core v$($Global:CoreScriptVersion)"
                               FontSize="$($FontSize.Medium)" FontWeight="Normal"
                               Foreground="{StaticResource LabelBlue}"
                               FontFamily="{StaticResource PrimaryFont}"
                               TextAlignment="Center" Margin="0,4,0,0"/>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,8,0,0">
                        <TextBlock x:Name="LanguageLabelText" Text="Lingua GUI (Italiano):"
                                   Foreground="{StaticResource LabelBlue}"
                                   FontFamily="{StaticResource PrimaryFont}"
                                   FontWeight="SemiBold"
                                   FontSize="$($FontSize.Small)"
                                   VerticalAlignment="Center"
                                   Margin="0,0,8,0"/>
                        <ComboBox x:Name="LanguageComboBox"
                                  Width="150"
                                  Height="30"
                                  SelectedValuePath="Tag"
                                  FontFamily="{StaticResource PrimaryFont}"
                                  FontSize="$($FontSize.Small)"/>
                    </StackPanel>
                </StackPanel>

                <!-- Column 2: Send Error Log button (red, top right) -->
                <StackPanel Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Right" Margin="16,0,0,0">
                    <Button x:Name="SendErrorLogsButton"
                            VerticalAlignment="Center"
                            HorizontalAlignment="Right"
                            Background="{StaticResource ErrorButtonColor}"
                            Foreground="{StaticResource TextColor}"
                            Padding="20,12"
                            BorderThickness="0"
                            Cursor="Hand"
                            Style="{StaticResource SmallButtonStyle}">
                        <StackPanel Orientation="Horizontal">
                            <Image x:Name="SendErrorLogsImage" Width="28" Height="28" Margin="0,0,8,0"/>
                            <TextBlock x:Name="SendErrorLogsText" Text="Send error logs" VerticalAlignment="Center"
                                       FontFamily="{StaticResource PrimaryFont}" FontWeight="SemiBold" FontSize="$($FontSize.Small)"/>
                        </StackPanel>
                    </Button>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Task 2: System Information panel with 3 blocks (refactored layout with separators) -->
        <Border Grid.Row="1" Background="{StaticResource OutputBackgroundColor}"
                CornerRadius="8" Padding="16" Margin="16,0,16,8">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto" MinWidth="200"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- Block 1: Windows info (blue labels on the left, white values on the right) -->
                <StackPanel Grid.Column="0" Margin="0,0,20,0">
                    <TextBlock x:Name="SysInfoTitleText" Text="▬▬ System information ▬▬"
                               Foreground="{StaticResource LabelBlue}"
                               FontSize="$($FontSize.Medium)" FontWeight="Bold"
                               FontFamily="{StaticResource PrimaryFont}"
                               Margin="0,0,0,12" TextAlignment="Left"/>

                    <!-- Windows Edition Row - Increased font size -->
                    <Grid Margin="0,6,0,6">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Image x:Name="SysInfoEditionImage" Width="16" Height="16" Margin="0,0,5,0"/>
                            <TextBlock x:Name="SysInfoEditionLabel" Text="Windows edition: " Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoEdition" Text="Loading."
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center" TextAlignment="Right"/>
                    </Grid>

                    <!-- Version Row - Increased font size -->
                    <Grid Margin="0,6,0,6">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Image x:Name="SysInfoVersionImage" Width="16" Height="16" Margin="0,0,5,0"/>
                            <TextBlock x:Name="SysInfoVersionLabel" Text="Version: " Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoVersion" Text="Loading."
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center" TextAlignment="Right"/>
                    </Grid>

                    <!-- Architecture Row - Increased font size -->
                    <Grid Margin="0,6,0,6">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Image x:Name="SysInfoArchitectureImage" Width="16" Height="16" Margin="0,0,5,0"/>
                            <TextBlock x:Name="SysInfoArchitectureLabel" Text="Architecture: " Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoArchitecture" Text="Loading."
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center" TextAlignment="Right"/>
                    </Grid>
                </StackPanel>

                <!-- Green vertical separator 1: Between System Information and Script Features -->
                <Border Grid.Column="1" Width="3" Background="{StaticResource SeparatorGreen}"
                        VerticalAlignment="Stretch" Margin="15,5"/>

                <!-- Block 2: Script status (center widget) - Simplified layout without LED -->
                <StackPanel Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Center"
                            Margin="20,0" MinWidth="200">

                    <!-- Row 1: Script features with colored status -->
                    <Grid HorizontalAlignment="Center" Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                            <Image x:Name="SysInfoScriptCompatibilityImage" Width="14" Height="14" Margin="0,0,5,0"
                                   VerticalAlignment="Center"/>
                            <TextBlock x:Name="SysInfoScriptCompatibilityLabel" Text="Script features: "
                                       Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontWeight="Bold"
                                       FontFamily="{StaticResource PrimaryFont}"
                                       VerticalAlignment="Center"/>
                            <TextBlock x:Name="SysInfoScriptCompatibility" Text="Checking."
                                       Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                       FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                       VerticalAlignment="Center" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Grid>

                    <!-- Row 2: BitLocker status with colored status - Same size as Row 1 -->
                    <Grid HorizontalAlignment="Center" Margin="0,4,0,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Image x:Name="BitlockerImage" Width="14" Height="14" Margin="0,0,5,0"
                               VerticalAlignment="Center"/>
                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock x:Name="SysInfoBitlockerLabel" Text="BitLocker status: "
                                       Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontWeight="Bold"
                                       FontFamily="{StaticResource PrimaryFont}"
                                       VerticalAlignment="Center" Margin="0,0,8,0"/>
                            <TextBlock x:Name="SysInfoBitlocker" Text="Checking."
                                       Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                       FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                       VerticalAlignment="Center"/>
                        </StackPanel>
                    </Grid>
                </StackPanel>

                <!-- Green vertical separator 2: Between Script Features and Hardware -->
                <Border Grid.Column="3" Width="3" Background="{StaticResource SeparatorGreen}"
                        VerticalAlignment="Stretch" Margin="15,5"/>

                <!-- Block 3: Hardware info (mirrored alignment with block 1) -->
                <StackPanel Grid.Column="4" Margin="20,0,0,0">
                    <TextBlock x:Name="HardwareTitleText" Text="▬▬ Hardware ▬▬"
                               Foreground="{StaticResource LabelBlue}"
                               FontSize="$($FontSize.Medium)" FontWeight="Bold"
                               FontFamily="{StaticResource PrimaryFont}"
                               Margin="0,0,0,12" TextAlignment="Right"/>

                    <!-- Computer Name Row - Increased font size -->
                    <Grid Margin="0,6,0,6">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Image x:Name="SysInfoComputerNameImage" Width="16" Height="16" Margin="0,0,5,0"/>
                            <TextBlock x:Name="SysInfoComputerNameLabel" Text="PC name: " Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoComputerName" Text="Loading."
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center" TextAlignment="Right"/>
                    </Grid>

                    <!-- RAM Row - Increased font size -->
                    <Grid Margin="0,6,0,6">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Image x:Name="SysInfoRAMImage" Width="16" Height="16" Margin="0,0,5,0"/>
                            <TextBlock x:Name="SysInfoRAMLabel" Text="RAM: " Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoRAM" Text="Loading."
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center" TextAlignment="Right"/>
                    </Grid>

                    <!-- Disk Row - Increased font size -->
                    <Grid Margin="0,6,0,6">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Image x:Name="SysInfoDiskImage" Width="16" Height="16" Margin="0,0,5,0"/>
                            <TextBlock x:Name="SysInfoDiskLabel" Text="Disk: " Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoDisk" Text="Loading."
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center" TextAlignment="Right"/>
                    </Grid>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Main content - Left panel with thick green separators -->
        <Grid Grid.Row="2" Margin="16">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="500"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Left panel - Actions with thick green separators -->
            <Border Grid.Column="0" Background="{StaticResource PanelBackgroundColor}"
                    CornerRadius="8" Margin="0,0,8,0" Padding="16">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Header with Gear icon (CategorySystem) -->
                    <StackPanel Grid.Row="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,0,12">
                        <Image x:Name="CategorySystemImage" Width="24" Height="24" Margin="0,0,8,0"
                               VerticalAlignment="Center"/>
                        <TextBlock x:Name="AvailableFunctionsText" Text="Available functions"
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Large)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center"/>
                    </StackPanel>

                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel x:Name="ActionsPanel" Margin="0,0,0,8"/>
                    </ScrollViewer>
                </Grid>
            </Border>

            <!-- Right Panel - Output -->
            <Border Grid.Column="1" Background="{StaticResource PanelBackgroundColor}"
                    CornerRadius="8" Padding="16">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Header with Notebook icon (OutputLog) -->
                    <StackPanel Grid.Row="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,0,12">
                        <Image x:Name="OutputLogImage" Width="24" Height="24" Margin="0,0,8,0"
                               VerticalAlignment="Center"/>
                        <TextBlock x:Name="OutputLogsText" Text="Output and logs"
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Large)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center"/>
                    </StackPanel>

                    <RichTextBox x:Name="OutputTextBox"
                                 Grid.Row="1"
                                 Background="{StaticResource OutputBackgroundColor}"
                                 Foreground="{StaticResource TextColor}"
                                 BorderBrush="{StaticResource BorderColor}"
                                 BorderThickness="1"
                                 IsReadOnly="True"
                                 FontFamily="{StaticResource PrimaryFont}"
                                 FontSize="$($FontSize.Small)"/>
                </Grid>
            </Border>
        </Grid>

        <!-- Task 5: Footer with Execute pill-shaped button (CornerRadius 20+) -->
        <Border Grid.Row="3" Background="{StaticResource HeaderBackgroundColor}"
                Padding="16" Margin="16,8,16,16" CornerRadius="12">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- Visible ProgressBar with height 20 and vivid blue color, made pill-shaped via Style -->
                <ProgressBar x:Name="MainProgressBar"
                             Grid.Row="0"
                             Grid.ColumnSpan="3"
                             Height="20"
                             Margin="0,0,0,12"
                             Background="{StaticResource PanelBackgroundColor}"
                             BorderBrush="{StaticResource SeparatorGreen}"
                             BorderThickness="1"
                             Foreground="#2196F3"
                             Minimum="0"
                             Maximum="100"
                             Value="0"
                             Style="{StaticResource PillProgressBarStyle}"/>

                <!-- Centered Execute button, pill-shaped (CornerRadius 25), blue -->
                <Button x:Name="ExecuteButton"
                        Grid.Row="1"
                        Grid.Column="1"
                        Background="{StaticResource ExecuteButtonColor}"
                        Foreground="{StaticResource TextColor}"
                        FontSize="$($FontSize.Large)"
                        FontWeight="Bold"
                        FontFamily="{StaticResource PrimaryFont}"
                        Padding="48,18"
                        BorderThickness="0"
                        HorizontalAlignment="Center"
                        Cursor="Hand"
                        Style="{StaticResource PillButtonStyle}">
                    <StackPanel Orientation="Horizontal">
                        <Image x:Name="ExecuteButtonImage" Width="20" Height="20" Margin="0,0,8,0"/>
                        <TextBlock x:Name="ExecuteButtonText" Text="Run scripts" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# Create window
try {
    Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.creatingWpfWindow') -GuiColor "#00CED1"
    $window = [Windows.Markup.XamlReader]::Parse($xaml)

    # Setup Window Icon (Favicon & Taskbar) - Remote Fallback
    try {
        $localImgDir = Join-Path $env:LOCALAPPDATA "WinToolkit\images"
        if (-not (Test-Path $localImgDir)) { New-Item -Path $localImgDir -ItemType Directory -Force | Out-Null }

        $iconPath = Join-Path $localImgDir "WinToolkit.ico"
        $iconUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/images/WinToolkit.ico"

        if (-not (Test-Path $iconPath)) {
            Invoke-WebRequest -Uri $iconUrl -OutFile $iconPath -UseBasicParsing -ErrorAction Stop
        }
        else {
            $window.Icon = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$iconPath)
        }
    }
    catch {
        Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.failedToLoadOrDownloadWindowIcon0' -Args @($($_.Exception.Message))) -GuiColor "#FFA500"
    }

    Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.windowCreatedSuccessfully') -GuiColor "#00FF00"
}
catch {
    Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.failedToCreateWindow0' -Args @($($_.Exception.Message))) -GuiColor "#FF0000"
    Read-Host (Get-SourceTextLoc 'uiText.pressEnterToExit')
    exit
}

# Get controls
$actionsPanel = $window.FindName("ActionsPanel")
$outputTextBox = $window.FindName("OutputTextBox")
$executeButton = $window.FindName("ExecuteButton")
$SysInfoEdition = $window.FindName("SysInfoEdition")
$SysInfoVersion = $window.FindName("SysInfoVersion")
$SysInfoArchitecture = $window.FindName("SysInfoArchitecture")
$SysInfoComputerName = $window.FindName("SysInfoComputerName")
$SysInfoRAM = $window.FindName("SysInfoRAM")
$SysInfoDisk = $window.FindName("SysInfoDisk")
$SysInfoScriptCompatibility = $window.FindName("SysInfoScriptCompatibility")
$SysInfoScriptCompatibilityImage = $window.FindName("SysInfoScriptCompatibilityImage")
$SysInfoBitlocker = $window.FindName("SysInfoBitlocker")
$BitlockerImage = $window.FindName("BitlockerImage")
$SysInfoEditionImage = $window.FindName("SysInfoEditionImage")
$SysInfoVersionImage = $window.FindName("SysInfoVersionImage")
$SysInfoArchitectureImage = $window.FindName("SysInfoArchitectureImage")
$SysInfoComputerNameImage = $window.FindName("SysInfoComputerNameImage")
$SysInfoRAMImage = $window.FindName("SysInfoRAMImage")
$SysInfoDiskImage = $window.FindName("SysInfoDiskImage")
$SendErrorLogsButton = $window.FindName("SendErrorLogsButton")
$SendErrorLogsText = $window.FindName("SendErrorLogsText")
$LanguageLabelText = $window.FindName("LanguageLabelText")
$LanguageComboBox = $window.FindName("LanguageComboBox")
$GuiEditionVersionsText = $window.FindName("GuiEditionVersionsText")
$SysInfoTitleText = $window.FindName("SysInfoTitleText")
$HardwareTitleText = $window.FindName("HardwareTitleText")
$SysInfoEditionLabel = $window.FindName("SysInfoEditionLabel")
$SysInfoVersionLabel = $window.FindName("SysInfoVersionLabel")
$SysInfoArchitectureLabel = $window.FindName("SysInfoArchitectureLabel")
$SysInfoScriptCompatibilityLabel = $window.FindName("SysInfoScriptCompatibilityLabel")
$SysInfoBitlockerLabel = $window.FindName("SysInfoBitlockerLabel")
$SysInfoComputerNameLabel = $window.FindName("SysInfoComputerNameLabel")
$SysInfoRAMLabel = $window.FindName("SysInfoRAMLabel")
$SysInfoDiskLabel = $window.FindName("SysInfoDiskLabel")
$AvailableFunctionsText = $window.FindName("AvailableFunctionsText")
$OutputLogsText = $window.FindName("OutputLogsText")
$ExecuteButtonText = $window.FindName("ExecuteButtonText")
$SendErrorLogsImage = $window.FindName("SendErrorLogsImage")
$ToolIconImage = $window.FindName("ToolIconImage")
$ExecuteButtonImage = $window.FindName("ExecuteButtonImage")
$CategorySystemImage = $window.FindName("CategorySystemImage")
$OutputLogImage = $window.FindName("OutputLogImage")
$progressBar = $window.FindName("MainProgressBar")

function Set-TextBlockText {
    param([object]$Control, [string]$Text)
    if ($Control) { $Control.Text = $Text }
}

function Initialize-LanguageComboBox {
    if (-not $LanguageComboBox) { return }

    $LanguageComboBox.Items.Clear()
    foreach ($language in @(Get-AvailableSourceTextLanguages)) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = $language.NativeName
        $item.Tag = $language.Code
        $LanguageComboBox.Items.Add($item) | Out-Null
        if ($language.Code -eq $Global:SourceTextLanguage) {
            $LanguageComboBox.SelectedItem = $item
        }
    }

    if (-not $LanguageComboBox.SelectedItem -and $LanguageComboBox.Items.Count -gt 0) {
        $LanguageComboBox.SelectedIndex = 0
    }
}

function Apply-GuiLocalization {
    Set-TextBlockText $LanguageLabelText (Get-SourceTextLoc 'gui.languageLabel')
    Set-TextBlockText $GuiEditionVersionsText (Get-SourceTextLoc 'gui.editionVersionsFormat' -Args @($Global:GuiVersion, $Global:CoreScriptVersion))
    Set-TextBlockText $SendErrorLogsText (Get-SourceTextLoc 'gui.sendErrorLogs')
    Set-TextBlockText $SysInfoTitleText "▬▬ $(Get-SourceTextLoc 'gui.systemInfo') ▬▬"
    Set-TextBlockText $HardwareTitleText "▬▬ $(Get-SourceTextLoc 'gui.hardware') ▬▬"
    Set-TextBlockText $SysInfoEditionLabel (Get-SourceTextLoc 'gui.windowsEdition')
    Set-TextBlockText $SysInfoVersionLabel (Get-SourceTextLoc 'gui.version')
    Set-TextBlockText $SysInfoArchitectureLabel (Get-SourceTextLoc 'gui.architecture')
    Set-TextBlockText $SysInfoScriptCompatibilityLabel (Get-SourceTextLoc 'gui.scriptFeatures')
    Set-TextBlockText $SysInfoBitlockerLabel (Get-SourceTextLoc 'gui.bitlockerStatus')
    Set-TextBlockText $SysInfoComputerNameLabel (Get-SourceTextLoc 'gui.pcName')
    Set-TextBlockText $SysInfoRAMLabel (Get-SourceTextLoc 'gui.ram')
    Set-TextBlockText $SysInfoDiskLabel (Get-SourceTextLoc 'gui.disk')
    Set-TextBlockText $AvailableFunctionsText (Get-SourceTextLoc 'gui.availableFunctions')
    Set-TextBlockText $OutputLogsText (Get-SourceTextLoc 'gui.outputLogs')
    Set-TextBlockText $ExecuteButtonText (Get-SourceTextLoc 'gui.executeScripts')

    if ($SysInfoScriptCompatibility -and $SysInfoScriptCompatibility.Text -match '^(Complete|Completa)$') {
        $SysInfoScriptCompatibility.Text = Get-SourceTextLoc 'gui.complete'
    }
    elseif ($SysInfoScriptCompatibility -and $SysInfoScriptCompatibility.Text -match '^(Limited|Limitata)$') {
        $SysInfoScriptCompatibility.Text = Get-SourceTextLoc 'gui.limited'
    }
    elseif ($SysInfoScriptCompatibility -and $SysInfoScriptCompatibility.Text -match '^(Unsupported|Non supportata)$') {
        $SysInfoScriptCompatibility.Text = Get-SourceTextLoc 'gui.unsupported'
    }
}

Initialize-LanguageComboBox
Apply-GuiLocalization

if ($LanguageComboBox) {
    $LanguageComboBox.Add_SelectionChanged({
            if (-not $LanguageComboBox.SelectedItem) { return }
            $selectedLanguage = [string]$LanguageComboBox.SelectedItem.Tag
            if ([string]::IsNullOrWhiteSpace($selectedLanguage) -or $selectedLanguage -eq $Global:SourceTextLanguage) { return }

            Set-SourceTextLanguage -LanguageCode $selectedLanguage
            Apply-GuiLocalization
            Update-SystemInformationPanel
            Update-ActionsPanel
        })
}

# Set up ExecuteButton with the new style and initialize icons
try {
    # Initialize the Execute button icon
    if ($ExecuteButtonImage) {
        try {
            $playIconPath = Get-EmojiIconPath -EmojiCharacter $emojiMappings.ExecuteButtonImage
            if ($playIconPath -and (Test-Path $playIconPath)) {
                $ExecuteButtonImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri]$playIconPath)
            }
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.couldNotLoadExecutebuttonIcon') -GuiColor "#FFA500"
        }
    }

    # Initialize the CategorySystem (Gear) icon for "Available Functions"
    if ($CategorySystemImage) {
        try {
            $gearIconPath = Get-EmojiIconPath -EmojiCharacter $emojiMappings.CategorySystem
            if ($gearIconPath -and (Test-Path $gearIconPath)) {
                $CategorySystemImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri]$gearIconPath)
            }
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.couldNotLoadCategorysystemIcon') -GuiColor "#FFA500"
        }
    }

    # Initialize the OutputLog (Notebook) icon
    if ($OutputLogImage) {
        try {
            $logIconPath = Get-EmojiIconPath -EmojiCharacter $emojiMappings.OutputLogImage
            if ($logIconPath -and (Test-Path $logIconPath)) {
                $OutputLogImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri]$logIconPath)
            }
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.couldNotLoadOutputlogIcon') -GuiColor "#FFA500"
        }
    }

    # Initialize the Tool icon (WinToolkit logo header) - Remote fallback
    if ($ToolIconImage) {
        try {
            $localImgDir = Join-Path $env:LOCALAPPDATA "WinToolkit\images"
            if (-not (Test-Path $localImgDir)) { New-Item -Path $localImgDir -ItemType Directory -Force | Out-Null }

            # Use the same icon downloaded earlier, or download another one if needed.
            # Load WinToolkit.ico as requested by the user
            $toolLogoPath = Join-Path $localImgDir "WinToolkit.ico"
            $toolLogoUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/images/WinToolkit.ico"

            if (-not (Test-Path $toolLogoPath)) {
                Invoke-WebRequest -Uri $toolLogoUrl -OutFile $toolLogoPath -UseBasicParsing -ErrorAction Stop
            }

            if (Test-Path $toolLogoPath) {
                # Use IconBitmapDecoder to read the ICO into the WPF images
                $decoder = New-Object System.Windows.Media.Imaging.IconBitmapDecoder(
                    [uri]$toolLogoPath,
                    [System.Windows.Media.Imaging.BitmapCreateOptions]::None,
                    [System.Windows.Media.Imaging.BitmapCacheOption]::Default
                )
                $ToolIconImage.Source = $decoder.Frames[0]
            }
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.couldNotLoadTooliconimage0' -Args @($($_.Exception.Message))) -GuiColor "#FFA500"
        }
    }

    Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.executebuttonConfiguredWithPillShapedStyleAndPlayIcon') -GuiColor "#00FF00"
}
catch {
    Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.couldNotConfigureExecutebutton') -GuiColor "#FFA500"
}

# =============================================================================
# SYSTEM INFORMATION UPDATE (Using Core's Get-SystemInfo) - Task 2
# =============================================================================

function Update-SystemInformationPanel {
    try {
        # Use Core's Get-SystemInfo function
        $sysInfo = Get-SystemInfo

        if (-not $sysInfo) {
            Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.failedToRetrieveSystemInformationFromCore') -GuiColor "#FF0000"
            return
        }

        # Update GUI on UI thread
        $window.Dispatcher.Invoke([Action] {
                # Task 2: Update text for the new 3-block layout
                $SysInfoEdition.Text = $sysInfo.ProductName
                $SysInfoVersion.Text = "$($sysInfo.DisplayVersion) (Build $($sysInfo.BuildNumber))"
                $SysInfoArchitecture.Text = $sysInfo.Architecture
                $SysInfoComputerName.Text = $sysInfo.ComputerName
                $SysInfoRAM.Text = "$($sysInfo.TotalRAM) GB"
                $SysInfoDisk.Text = Get-SourceTextLoc 'gui.diskFreeFormat' -Args @($sysInfo.FreePercentage, $sysInfo.FreeDisk, $sysInfo.TotalDisk)

                # Set image sources
                try {
                    $SysInfoEditionImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SysInfoEditionImage))
                    $SysInfoVersionImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SysInfoVersionImage))
                    $SysInfoArchitectureImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SysInfoArchitectureImage))
                    $SysInfoComputerNameImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SysInfoComputerNameImage))
                    $SysInfoRAMImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SysInfoRAMImage))
                    $SysInfoDiskImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SysInfoDiskImage))

                    if ($SendErrorLogsImage) {
                        $SendErrorLogsImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SendErrorLogsImage))
                    }
                }
                catch {
                    Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.couldNotLoadSomeIcons0' -Args @($($_.Exception.Message))) -GuiColor "#FFA500"
                }

                # Task 2: Compatibility indicator with colored status text
                $statusText = ""
                $statusIconKey = "LEDStatusRed"

                if ($sysInfo.BuildNumber -ge 22000) {
                    $statusText = Get-SourceTextLoc 'gui.complete'
                    $statusIconKey = "LEDStatusGreen"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                }
                elseif ($sysInfo.BuildNumber -ge 17763) {
                    $statusText = Get-SourceTextLoc 'gui.complete'
                    $statusIconKey = "LEDStatusGreen"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                }
                elseif ($sysInfo.BuildNumber -ge 10240) {
                    $statusText = Get-SourceTextLoc 'gui.limited'
                    $statusIconKey = "LEDStatusYellow"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Orange)
                }
                else {
                    $statusText = Get-SourceTextLoc 'gui.unsupported'
                    $statusIconKey = "LEDStatusRed"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Red)
                }

                $SysInfoScriptCompatibility.Text = $statusText
                if ($SysInfoScriptCompatibilityImage) {
                    $statusIconPath = Get-EmojiIconPath -EmojiCharacter $emojiMappings[$statusIconKey]
                    if ($statusIconPath -and (Test-Path $statusIconPath)) {
                        $SysInfoScriptCompatibilityImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri]$statusIconPath)
                    }
                }

                # Update BitLocker status
                try {
                    $blStatusKey = Get-GuiBitlockerStatusKey
                    $blStatus = Get-SourceTextLoc $blStatusKey
                    $SysInfoBitlocker.Text = $blStatus

                    # Color the BitLocker status based on a stable key rather than localized text.
                    if ($blStatusKey -eq 'bitlocker.status.on' -or $blStatusKey -eq 'bitlocker.status.encrypting') {
                        $SysInfoBitlocker.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                    }
                    elseif ($blStatusKey -eq 'bitlocker.status.suspended' -or $blStatusKey -eq 'bitlocker.status.decrypting') {
                        $SysInfoBitlocker.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Orange)
                    }
                    else {
                        # Disabled/not configured states = red
                        $SysInfoBitlocker.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Red)
                    }

                    # Load the BitLocker icon
                    if ($BitlockerImage) {
                        $blIconPath = Get-EmojiIconPath -EmojiCharacter $emojiMappings.BitlockerImage
                        if ($blIconPath -and (Test-Path $blIconPath)) {
                            $BitlockerImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri]$blIconPath)
                        }
                    }
                }
                catch {
                    Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.couldNotCheckBitlockerStatus0' -Args @($($_.Exception.Message))) -GuiColor "#FFA500"
                }
            })

        Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.systemInformationPanelUpdated3BlockLayout') -GuiColor "#00FF00"
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.errorUpdatingSystemInformation0' -Args @($($_.Exception.Message))) -GuiColor "#FF0000"
    }
}

# =============================================================================
# DYNAMIC MENU GENERATION (From Core's $menuStructure)
# =============================================================================

function Update-ActionsPanel {
    try {
        Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.generatingDynamicMenuFromCore0' -Args @($menuStructure)) -GuiColor "#00CED1"

        $window.Dispatcher.Invoke([Action] {
                $actionsPanel.Children.Clear()

                if ($Global:MenuStructure.Count -eq 0) {
                    Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.0IsEmptyUsingFallbackStaticMenu' -Args @($menuStructure)) -GuiColor "#FFA500"
                    return
                }

                foreach ($category in $Global:MenuStructure) {
                    # ========================================
                    # A. CATEGORY HEADER (with Green Line + Emoji)
                    # ========================================

                    # Add a thick green line (3px) BEFORE the title
                    $greenLine = New-Object System.Windows.Controls.Border
                    $greenLine.Height = 3
                    $greenLine.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#2E7D32"))
                    $greenLine.Margin = New-Object System.Windows.Thickness(0, 5, 0, 10)
                    $actionsPanel.Children.Add($greenLine) | Out-Null

                    # Category container with Emoji + Name
                    $categoryContainer = New-Object System.Windows.Controls.StackPanel
                    $categoryContainer.Orientation = [System.Windows.Controls.Orientation]::Horizontal
                    $categoryContainer.Margin = '0,0,0,6'

                    # Emoji (ONLY in the category header)
                    $iconPath = Get-IconWithFallback -EmojiCharacter $category.Icon
                    if ($iconPath) {
                        $categoryEmoji = New-Object System.Windows.Controls.Image
                        $categoryEmoji.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri]$iconPath)
                        $categoryEmoji.Width = 20
                        $categoryEmoji.Height = 20
                        $categoryEmoji.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
                        $categoryEmoji.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                    }
                    else {
                        $categoryEmoji = New-Object System.Windows.Controls.TextBlock
                        $categoryEmoji.Text = $category.Icon
                        $categoryEmoji.FontSize = $FontSize.Large
                        $categoryEmoji.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
                        $categoryEmoji.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                        $categoryEmoji.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::White)
                    }
                    $categoryContainer.Children.Add($categoryEmoji) | Out-Null

                    # Category Name (Bold, Cyan)
                    $categoryHeader = New-Object System.Windows.Controls.TextBlock
                    $categoryHeader.Text = Get-ToolkitMenuText $category
                    $categoryHeader.FontSize = $FontSize.Small
                    $categoryHeader.FontWeight = 'Bold'
                    $categoryHeader.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Cyan)
                    $categoryHeader.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                    $categoryHeader.FontFamily = New-Object System.Windows.Media.FontFamily($FontFamily)
                    $categoryContainer.Children.Add($categoryHeader) | Out-Null

                    $actionsPanel.Children.Add($categoryContainer) | Out-Null

                    # ========================================
                    # B. SCRIPT ROWS (CheckBox + Text)
                    # ========================================

                    foreach ($script in $category.Scripts) {
                        # Horizontal container for CheckBox + Text
                        $scriptRow = New-Object System.Windows.Controls.StackPanel
                        $scriptRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal
                        $scriptRow.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Transparent)
                        $scriptRow.Margin = '0,4,0,4'
                        $scriptRow.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

                        # CheckBox
                        $checkBox = New-Object System.Windows.Controls.CheckBox
                        $checkBox.Name = "chk_$($script.Name.Replace(' ', '').Replace('-', '_'))"
                        $checkBox.Tag = $script.Name
                        $checkBox.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#4FC3F7"))
                        $checkBox.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Gray)
                        $checkBox.BorderBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#4FC3F7"))
                        $checkBox.BorderThickness = New-Object System.Windows.Thickness(1)
                        $checkBox.Padding = New-Object System.Windows.Thickness(6, 4, 6, 4)
                        $checkBox.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
                        $checkBox.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                        $checkBox.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
                        $scriptRow.Children.Add($checkBox) | Out-Null

                        # Single TextBlock: <Bold>Script Name</Bold> - Description
                        $textBlock = New-Object System.Windows.Controls.TextBlock
                        $textBlock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                        $textBlock.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
                        $textBlock.MaxWidth = 320
                        $textBlock.FontFamily = New-Object System.Windows.Media.FontFamily($FontFamily)

                        # Bold Script Name (White)
                        $titleRun = New-Object System.Windows.Documents.Run
                        $titleRun.Text = Get-ToolkitMenuText $script
                        $titleRun.FontWeight = [System.Windows.FontWeights]::Bold
                        $titleRun.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::White)

                        $textBlock.Inlines.Add($titleRun)
                        $scriptRow.Children.Add($textBlock) | Out-Null

                        $actionsPanel.Children.Add($scriptRow) | Out-Null
                    }
                }

                Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.dynamicMenuGenerated0Categories' -Args @($($Global:MenuStructure.Count))) -GuiColor "#00FF00"
            })
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.errorGeneratingDynamicMenu0' -Args @($($_.Exception.Message))) -GuiColor "#FF0000"
    }
}

# Task 6: Helper function to determine the emoji based on the script name
function Get-ScriptEmoji {
    param([string]$ScriptName)

    $nameLower = $ScriptName.ToLower()

    if ($nameLower -match 'powershell|posh') { return $emojiMappings.ScriptPowerShell }
    elseif ($nameLower -match 'winget|install|package') { return $emojiMappings.ScriptWinget }
    elseif ($nameLower -match 'clean|remove|debloat') { return $emojiMappings.ScriptCleaner }
    elseif ($nameLower -match 'repair|fix|restore') { return $emojiMappings.ScriptRepair }
    elseif ($nameLower -match 'backup|driver|export') { return $emojiMappings.ScriptBackup }
    elseif ($nameLower -match 'update|upgrade') { return $emojiMappings.ScriptUpdate }
    elseif ($nameLower -match 'driver|nvidia|amd|gpu') { return $emojiMappings.ScriptDriver }
    elseif ($nameLower -match 'network|tcp|dns|firewall') { return $emojiMappings.ScriptNetwork }
    elseif ($nameLower -match 'privacy|telemetry') { return $emojiMappings.ScriptPrivacy }
    elseif ($nameLower -match 'performance|optimization|tweak') { return $emojiMappings.ScriptPerformance }
    elseif ($nameLower -match 'security|antivirus|defender') { return $emojiMappings.ScriptSecurity }
    elseif ($nameLower -match 'debloat|appx|store') { return $emojiMappings.ScriptDebloat }
    else { return "📄" }
}

# =============================================================================
# HELPER FUNCTION: Filter and format job output
# =============================================================================
function Format-JobOutput {
    param(
        [string]$Line
    )

    # Filter empty or insignificant messages
    if (-not $Line.Trim()) { return $false }

    # Handle WINTOOLKIT_STYLED_MESSAGE_TAG
    if ($Line -match '\[WINTOOLKIT_STYLED_MESSAGE_TAG\]\s*(?<Type>\w+)\s*:\s*(?<Text>.*)') {
        $outputType = $matches.Type
        $messageText = $matches.Text
        $guiColor = switch -Wildcard ($outputType.ToLower()) {
            "error" { "#FF5555" }
            "warning" { "#FFB74D" }
            "success" { "#4CAF50" }
            "info" { "#00CED1" }
            "progress" { "#2196F3" }
            default { "#FFFFFF" }
        }
        Write-UnifiedLog -Type $outputType -Message $messageText -GuiColor $guiColor
        return $true
    }

    # Handle WINTOOLKIT_PROGRESS_TAG (Relaxed regex to match anywhere)
    if ($Line -match '\[WINTOOLKIT_PROGRESS_TAG\].*Percent:\s*(?<Percent>\d+)%') {
        $percent = [int]$matches.Percent

        # Log version of progress to OutputTextBox
        if ($Line -match 'Activity:\s*(?<Activity>[^|]+)\| Status:\s*(?<Status>[^|]+)') {
            $activity = $matches.Activity.Trim()
            $status = $matches.Status.Trim()

            # IMPROVED VERBOSITY: Log only if percentage OR status has changed
            if ( ($status -ne $Global:LastLoggedProgress.Status) -or
                ($percent -ne $Global:LastLoggedProgress.Percent)
            ) {
                Write-UnifiedLog -Type 'Progress' -Message "🔄 [$activity] $status ($percent%)." -GuiColor "#2196F3"
                $Global:LastLoggedProgress.Percent = $percent
                $Global:LastLoggedProgress.Status = $status
            }
        }

        $window.Dispatcher.Invoke([Action] {
                if ($progressBar) { $progressBar.Value = $percent }
            })
        return $true
    }

    # Handle WINTOOLKIT_INPUT_BYPASS_TAG (New)
    if ($Line -match '\[WINTOOLKIT_INPUT_BYPASS_TAG\] Prompt:\s*(?<Prompt>.*)') {
        $promptText = $matches.Prompt
        Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.iInteractiveInputBypassedFor0DefaultChoiceY' -Args @($promptText)) -GuiColor "#00CED1"
        return $true
    }

    # Handle WINTOOLKIT_COUNTDOWN_BYPASS_TAG (New)
    if ($Line -match '\[WINTOOLKIT_COUNTDOWN_BYPASS_TAG\] Message:\s*(?<Message>.*)\s*\|\s*Seconds:\s*(?<Seconds>\d+)') {
        $countdownMessage = $matches.Message
        $countdownSeconds = $matches.Seconds
        Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.countdownBypassed01Seconds' -Args @($countdownMessage, $countdownSeconds)) -GuiColor "#00CED1"
        return $true
    }

    # Handle WINTOOLKIT_CONFIRMATION_BYPASS_TAG (New)
    if ($Line -match '\[WINTOOLKIT_CONFIRMATION_BYPASS_TAG\] Message:\s*(?<Message>.*)') {
        $confirmationMessage = $matches.Message
        Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.bypassedUserConfirmationFor0DefaultResponseYes' -Args @($confirmationMessage)) -GuiColor "#00CED1"
        return $true
    }

    # Handle WINTOOLKIT_RAW_HOST_OUTPUT_TAG
    if ($Line -match '\[WINTOOLKIT_RAW_HOST_OUTPUT_TAG\](?<Text>.*)') {
        $messageText = $matches.Text.Trim()
        if (-not [string]::IsNullOrEmpty($messageText)) {
            # Regex updated to include all common icons from Core's MsgStyles and various script rules
            $styledRawPattern = "^\[(?<Timestamp>\d{2}:\d{2}:\d{2})\]\s*(?<Icon>[✅⚠️❌💎🔄🗂️📁🖨️📄🗑️💭⸏▶️💡⏰🎉💻📊⚙️🛡️🚀📡🔑⏳📦💽🕸️🖨️🎯🔕🔥✨📜💾💽🦊🌐])\s*(?<Rest>.*)$"
            if ($messageText -match $styledRawPattern) {
                $icon = $matches.Icon
                $restOfText = $matches.Rest.Trim()
                $type = 'Info' # Default, will try to infer more precisely
                $guiColor = "#00CED1" # Default Info color

                # Infer type and color from icon and keywords
                switch ($icon) {
                    '✅' { $type = 'Success'; $guiColor = "#4CAF50" }
                    '⚠️' { $type = 'Warning'; $guiColor = "#FFB74D" }
                    '❌' { $type = 'Error'; $guiColor = "#FF5555" }
                    { $_ -in @('💎', 'ℹ️', '💡', '⚙️', '🔑', '⏳', '📦', '🚀', '🛡️', '💽', '🕸️', '🖨️', '🎯', '🔕', '🔥', '✨', '📜', '💾', '🦊', '🌐') } { $type = 'Info'; $guiColor = "#00CED1" }
                    '🔄' { $type = 'Progress'; $guiColor = "#2196F3" }
                }
                # Also try to infer from keywords within the "Rest" part if icon mapping isn't precise
                if ($type -eq 'Info') {
                    if ($restOfText -match '(?i)ERROR|FAILED|ERR|FALLITO|CRITICAL') { $type = 'Error'; $guiColor = "#FF5555" }
                    elseif ($restOfText -match '(?i)WARNING|WARN|ATTENZIONE|IMPOSSIBLE') { $type = 'Warning'; $guiColor = "#FFB74D" }
                    elseif ($restOfText -match '(?i)SUCCESS|COMPLETED|FATTO|OK') { $type = 'Success'; $guiColor = "#4CAF50" }
                }

                # Fix double emoji: if RestOfText already starts with the MUST-HAVE emoji, don't double it
                if ($restOfText.StartsWith($icon)) {
                    Write-UnifiedLog -Type $type -Message "$restOfText" -GuiColor $guiColor
                }
                else {
                    Write-UnifiedLog -Type $type -Message "$icon $restOfText" -GuiColor $guiColor
                }
            }
            # Handle special header/footer lines (No TRACE for these)
            elseif ($messageText -match '^(?:={5,}|-{5,}|_={5,}|_\s*={5,}|╔|╚|═|─|━|┌|┐|└|┘|│|WinToolkit - System Check)') {
                # Ignore decorative lines
            }
            else {
                # Preserve unrecognized output as plain diagnostic information.
                Write-UnifiedLog -Type 'Info' -Message "$messageText" -GuiColor "#B0B0B0"
            }
        }
        return $true
    }

    # Patterns for ASCII banners and decorative lines (consolidated and improved)
    $bannerPatterns = @(
        '^\s*═+\s*$', '^\s*─+\s*$', '^\s*—+\s*$', '^\s*━+\s*$',
        '__        __  _  _   _',
        '\\ \\      / / | || \\ | |',
        '__   __  / /  | || . ` | |',
        '   |/  \|/|  | || |\  | |',
        '   |_||_| |_| |_||_| \_|',
        '╔═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗',
        '^\s*║',
        '╚═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝',
        '──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────',
        'WinToolkit - System Check',
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        '\[Header\]',
        '╦.*╦',
        '╠.*╣',
        '╩.*╩',
        '^\*\*\*\*\*+'
    )

    foreach ($pattern in $bannerPatterns) {
        if ($Line -match $pattern) { return $false }
    }

    # Check for interactive input prompts
    if ($Line -match '\[INPUT\]|\[CHOICE\]|\[CONFIRM\]|\?|\[Y/N\]|press any key to continue|do you want to take the risk|premi un tasto per continuare|vuoi rischiare') {
        $Global:IsInputWaiting = $true
        Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.interactiveInputDetected0NotSupportedInGuiMode' -Args @($Line)) -GuiColor "#FFA500"
        return $true
    }

    # Default handling for any other output
    $outputType = 'Info'
    $guiColor = "#B0B0B0"
    if ($Line -match '(?i)ERROR|FAILED|ERR|FALLITO|CRITICAL') { $outputType = 'Error'; $guiColor = "#FF5555" }
    elseif ($Line -match '(?i)WARNING|WARN|ATTENZIONE|IMPOSSIBLE') { $outputType = 'Warning'; $guiColor = "#FFB74D" }
    elseif ($Line -match '(?i)SUCCESS|COMPLETED|FATTO|OK') { $outputType = 'Success'; $guiColor = "#4CAF50" }

    Write-UnifiedLog -Type $outputType -Message $Line.Trim() -GuiColor $guiColor
    return $true
}

# =============================================================================
# SCRIPT EXECUTION - ASYNCHRONOUS IMPLEMENTATION (Using DispatcherTimer)
# =============================================================================

# Function to start the job for the current script
function Start-NextScriptJob {
    param($scriptName)

    # Disable the Execute button and reset the progress bar (if this is the first script)
    $window.Dispatcher.Invoke([Action] {
            $executeButton.IsEnabled = $false
        })

    Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.startExecution0' -Args @($scriptName)) -GuiColor "#00CED1"

    # Define paths needed by the job
    $coreScriptPath = $Global:CoreConfig.LocalCachePath
    $mainLogDirectory = $LogDirectory

    Write-UnifiedLog -Type 'Info' -Message ("   " + (Get-SourceTextLoc 'uiText.coreForJob0' -Args @($coreScriptPath))) -GuiColor "#808080"

    # Define the script block to be executed within the job's isolated runspace
    $jobScriptBlock = {
        param($CorePath, $CmdName, $MainLogDir, $LanguageDir, $LanguageCode)

        # Set ErrorActionPreference for the job's runspace
        $ErrorActionPreference = 'Continue'

        # --- FIX: Ensure PATH is fully available for child processes ---
        $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        # --- END FIX ---

        # Ensure logging directory exists for the job process
        try {
            if (-not ([System.IO.Directory]::Exists($MainLogDir))) {
                [System.IO.Directory]::CreateDirectory($MainLogDir) | Out-Null
            }
        }
        catch {}

        # Dot-source the Core script first, as all functions are defined there
        try {
            if (Test-Path $CorePath) {
                $Global:GuiSessionActive = $true
                # ImportOnly prevents the standalone core from running its
                # console initialization/menu while it is loaded by the GUI.
                . $CorePath -ImportOnly -Language $LanguageCode
            }
            else {
                Write-Error (Get-SourceTextLoc 'uiText.coreScriptNotFoundAt0WithinJob' -Args @($CorePath))
                $Global:NeedsFinalReboot = $false
                return @{ Success = $false; RebootRequired = $Global:NeedsFinalReboot; Error = "Core script not found." }
            }
        }
        catch {
            Write-Error (Get-SourceTextLoc 'uiText.failedToDotSourceCoreScriptWithinJob0' -Args @($($_.Exception.Message)))
            $Global:NeedsFinalReboot = $false
            return @{ Success = $false; RebootRequired = $Global:NeedsFinalReboot; Error = $_.Exception.Message }
        }

        # Override Get-SourceTextLanguageDirectory so the core script can find language files
        if ($LanguageDir -and (Test-Path $LanguageDir)) {
            function Get-SourceTextLanguageDirectory {
                return $LanguageDir
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($LanguageCode) -and (Get-Command Set-SourceTextLanguage -ErrorAction SilentlyContinue)) {
            Set-SourceTextLanguage -LanguageCode $LanguageCode
        }

        # *** FIX: Create alias Get-Loc -> Get-SourceTextLoc for Core compatibility ***
        # The Core Script uses Get-Loc as an abbreviated name for Get-SourceTextLoc.
        # Define it here (and in Global scope) so all dot-sourced Core functions work.
        if (Get-Command Get-SourceTextLoc -ErrorAction SilentlyContinue) {
            if (-not (Get-Alias Get-Loc -ErrorAction SilentlyContinue)) {
                Set-Alias -Name Get-Loc -Value Get-SourceTextLoc -Scope Global
            }
        }

        # --- FIX: Suppress Verbose and Debug output streams within the job ---
        $VerbosePreference = 'SilentlyContinue'
        $DebugPreference = 'SilentlyContinue'
        # --- END FIX ---

        # 5. --- REDEFINE (SHIM) CRITICAL UI FUNCTIONS FOR GUI MODE ---
        # These definitions will now override the ones loaded from CorePath,
        # ensuring GUI-specific behavior for output and user interaction.

        # Shim Clear-Host to prevent clearing job output or causing errors in non-console host.
        function Clear-Host { Write-Debug "[GUI_SHIM] Clear-Host bypassed." }

        # Shim Clear-ProgressLine. The original has a ConsoleHost check, but this ensures no raw UI access.
        function Clear-ProgressLine { Write-Debug "[GUI_SHIM] Clear-ProgressLine bypassed." }

        # Shim Read-Host to provide default answers, preventing job blockage.
        function Read-Host {
            param([string]$Prompt)
            Write-Debug "[GUI_SHIM] Interactive prompt bypassed for: '$Prompt'. Returning 'Y'."
            Write-Output (Get-SourceTextLoc 'uiText.wintoolkitInputBypassTagPrompt0' -Args @($Prompt)) # Tag for the GUI
            return 'Y' # Default to 'Yes' for most confirmations/choices in GUI mode.
        }

        # Shim Start-InterruptibleCountdown to bypass user interaction and the console UI countdown.
        function Start-InterruptibleCountdown {
            param(
                [int]$Seconds = 30,
                [string]$Message,
                [switch]$Suppress
            )
            if ([string]::IsNullOrWhiteSpace($Message)) { $Message = Get-SourceTextLoc 'sourceText.automaticRestart' }
            Write-Debug "[GUI_SHIM] Countdown bypassed for '$Message' (duration: $Seconds seconds)."
            Write-Output (Get-SourceTextLoc 'uiText.wintoolkitCountdownBypassTagMessage0Seconds1' -Args @($Message, $Seconds)) # Tag for the GUI
            return $true
        }

        # Shim Get-UserConfirmation to always confirm actions, preventing user interaction.
        function Get-UserConfirmation {
            param([string]$Message, [string]$DefaultChoice = 'N')
            Write-Debug "[GUI_SHIM] User confirmation bypassed for: '$Message'. Returning 'Yes'."
            Write-Output (Get-SourceTextLoc 'uiText.wintoolkitConfirmationBypassTagMessage0' -Args @($Message)) # Tag for the GUI
            return $true # Assume 'Yes' for all user confirmations in GUI mode.
        }

        # Shim Show-Header to prevent raw console output (ASCII art, direct window size checks).
        function Show-Header {
            param([string]$SubTitle)
            if ([string]::IsNullOrWhiteSpace($SubTitle)) { $SubTitle = Get-SourceTextLoc 'menu.main' }
            Write-Debug "[GUI_SHIM] Header: WinToolkit - $SubTitle (bypassed direct console output)."
            Write-Output (Get-SourceTextLoc 'uiText.wintoolkitStyledMessageTagInfoHeader0' -Args @($SubTitle)) # Send as a styled message for the GUI
        }

        # Shim Invoke-WithSpinner - GUI version adapts progress reporting for scripts using Invoke-WithSpinner
        function Invoke-WithSpinner {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true)][string]$Activity,
                [Parameter(Mandatory = $true)][scriptblock]$Action,
                [Parameter(Mandatory = $false)][int]$TimeoutSeconds = 300,
                [Parameter(Mandatory = $false)][int]$UpdateInterval = 500,
                [Parameter(Mandatory = $false)][switch]$Process,
                [Parameter(Mandatory = $false)][switch]$Job,
                [Parameter(Mandatory = $false)][switch]$Timer,
                [Parameter(Mandatory = $false)][scriptblock]$PercentUpdate
            )

            $startTime = Get-Date
            $percent = 0

            try {
                $result = & $Action

                if ($Timer) {
                    $totalSeconds = $TimeoutSeconds
                    for ($i = $totalSeconds; $i -gt 0; $i--) {
                        if ($PercentUpdate) {
                            $percent = & $PercentUpdate
                        }
                        else {
                            $percent = [math]::Round((($totalSeconds - $i) / $totalSeconds) * 100)
                        }
                        # Output via Warning stream to avoid pipeline pollution
                        Write-Warning (Get-SourceTextLoc 'uiText.wintoolkitProgressTagActivity0Status1SecondiPercent2' -Args @($Activity, $i, $percent))
                        Start-Sleep -Seconds 1
                    }
                    return $true
                }
                elseif ($Process -and $result -and $result.GetType().Name -eq 'Process') {
                    while (-not $result.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

                        if ($PercentUpdate) {
                            $percent = & $PercentUpdate
                        }
                        else {
                            # Allow the random percentage to reach 99% for more natural progress
                            $percent = [math]::Min(99, $percent + (Get-Random -Minimum 1 -Maximum 3))
                        }

                        Write-Warning (Get-SourceTextLoc 'uiText.wintoolkitProgressTagActivity0StatusRunning1SecondsPercent2' -Args @($Activity, $elapsed, $percent))
                        Start-Sleep -Milliseconds $UpdateInterval
                        $result.Refresh()
                    }

                    if (-not $result.HasExited) {
                        Write-Warning (Get-SourceTextLoc 'uiText.wintoolkitStyledMessageTagWarningTimeoutReachedAfter0SecondsTerminatingProcess' -Args @($TimeoutSeconds))
                        $result.Kill()
                        Start-Sleep -Seconds 2
                        return @{ Success = $false; TimedOut = $true; ExitCode = -1 }
                    }

                    Write-Warning (Get-SourceTextLoc 'uiText.wintoolkitProgressTagActivity0StatusCompletedPercent100' -Args @($Activity))
                    return @{ Success = $true; TimedOut = $false; ExitCode = $result.ExitCode }
                }
                elseif ($Job -and $result -and $result.GetType().Name -eq 'Job') {
                    while ($result.State -eq 'Running') {
                        Write-Warning (Get-SourceTextLoc 'uiText.wintoolkitProgressTagActivity0StatusInEsecuzionePercent1' -Args @($Activity, $percent))
                        Start-Sleep -Milliseconds $UpdateInterval
                        # Allow progress up to 99% for Jobs too
                        if ($percent -lt 99) { $percent += 5 }
                    }
                    $jobResult = Receive-Job $result -Wait
                    return $jobResult
                }
                else {
                    return $result
                }
            }
            catch {
                Write-Warning (Get-SourceTextLoc 'uiText.wintoolkitStyledMessageTagErrorErroreDurante01' -Args @(${Activity}, $($_.Exception.Message)))
                return @{ Success = $false; Error = $_.Exception.Message }
            }
        }

        # Shim Write-StyledMessage to redirect styled messages from Core to Write-Warning with tags
        function Write-StyledMessage {
            param(
                [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Progress')][string]$Type,
                [string]$Text
            )
            # Use Write-Warning to bypass Success Pipeline (prevent variable pollution)
            Write-Warning (Get-SourceTextLoc 'uiText.wintoolkitStyledMessageTag01' -Args @($Type, $Text))
        }

        # Shim Show-ProgressBar to prevent raw console output for progress bars.
        function Show-ProgressBar {
            param(
                [string]$Activity,
                [string]$Status,
                [int]$Percent,
                [string]$Icon = '⏳',
                [string]$Spinner = '',
                [string]$Color = 'Green'
            )
            # Ensure Percent is an integer
            $intPercent = [int]$Percent
            Write-Warning (Get-SourceTextLoc 'uiText.wintoolkitProgressTagActivity0Status1Percent2Icon3Spinner4' -Args @($Activity, $Status, $($intPercent), $Icon, $Spinner))
        }

        # Shim Write-Progress to redirect standard PowerShell progress to the GUI
        function Write-Progress {
            param(
                [Parameter(Mandatory = $true)][string]$Activity,
                [string]$Status = "",
                [int]$PercentComplete = -1,
                [switch]$Completed
            )
            $displayActivity = $Activity
            $displayStatus = $Status
            if ($Completed) {
                $displayCompleted = Get-SourceTextLoc 'sourceText.completed'
                Write-Warning (Get-SourceTextLoc 'uiText.wintoolkitProgressTagActivity0Status1Percent100' -Args @($displayActivity, $displayCompleted))
            }
            elseif ($PercentComplete -ge 0) {
                Write-Warning (Get-SourceTextLoc 'uiText.wintoolkitProgressTagActivity0Status1Percent2' -Args @($displayActivity, $displayStatus, $($PercentComplete)))
            }
        }

        # Shim Write-Host - uses Write-Warning to bypass Success Pipeline
        function Write-Host {
            param(
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object] $Object,
                [string] $Separator = " ",
                [string] $ForegroundColor,
                [string] $BackgroundColor,
                [switch] $NoNewline
            )

            process {
                # Use $Object to handle direct calls; handle pipeline via $_ if $Object is null
                $target = if ($null -ne $Object) { $Object } else { $_ }
                $output = ($target | Out-String).TrimEnd("`r`n")
                if (-not [string]::IsNullOrEmpty($output)) {
                    # If it's already a tagged message, don't double tag it
                    if ($output -match '\[WINTOOLKIT_.*_TAG\]') {
                        Write-Warning $output
                    }
                    else {
                        Write-Warning (Get-SourceTextLoc 'uiText.wintoolkitRawHostOutputTag0' -Args @($output))
                    }
                }
            }
        }
        # --- End of REDEFINITIONS ---

        # Build dynamic arguments to avoid interactive prompts
        $argsToPass = @()
        try {
            $commandInfo = Get-Command $CmdName -ErrorAction Stop
            if ($commandInfo.Parameters.ContainsKey('SuppressIndividualReboot')) {
                $argsToPass += '-SuppressIndividualReboot'
            }
            if ($commandInfo.Parameters.ContainsKey('CountdownSeconds')) {
                $argsToPass += '-CountdownSeconds 0'
            }
            if ($commandInfo.Parameters.ContainsKey('RunStandalone')) {
                $argsToPass += '-RunStandalone:$false'
            }
        }
        catch {
            Write-Error (Get-SourceTextLoc 'uiText.cannotGetParametersForFunction01' -Args @($CmdName, $($_.Exception.Message)))
            $Global:NeedsFinalReboot = $false
            return @{ Success = $false; RebootRequired = $Global:NeedsFinalReboot; Error = $_.Exception.Message }
        }

        # Execute the function. Redirect all streams to capture everything.
        try {
            if (Get-Command $CmdName -ErrorAction SilentlyContinue) {
                $Global:NeedsFinalReboot = $false
                $scriptBlock = [ScriptBlock]::Create("& $CmdName $($argsToPass -join ' ') *>&1")
                & $scriptBlock
            }
            else {
                Write-Error (Get-SourceTextLoc 'uiText.function0NotFoundAfterDotSourcingWithinJob' -Args @($CmdName))
                $Global:NeedsFinalReboot = $false
                return @{ Success = $false; RebootRequired = $Global:NeedsFinalReboot; Error = "Function not found." }
            }
        }
        catch {
            Write-Error (Get-SourceTextLoc 'uiText.errorExecutingFunction0WithinJob1' -Args @($CmdName, $($_.Exception.Message)))
            $Global:NeedsFinalReboot = $false
            return @{ Success = $false; RebootRequired = $Global:NeedsFinalReboot; Error = $_.Exception.Message }
        }

        # Return reboot status and success
        return @{ Success = $true; RebootRequired = $Global:NeedsFinalReboot }
    }

    try {
        $Global:ScriptJob = Start-Job -ScriptBlock $jobScriptBlock -ArgumentList $coreScriptPath, $scriptName, $mainLogDirectory, $Global:SourceTextLanguageDirectory, $Global:SourceTextLanguage -Name "WinToolkit_ScriptJob_$scriptName" -ErrorAction Stop
        $Global:LastJobOutputCount = 0 # Reset output counter for new job
        Write-UnifiedLog -Type 'Info' -Message ("   " + (Get-SourceTextLoc 'uiText.powershellJob0StartedId1' -Args @($scriptName, $($Global:ScriptJob.Id)))) -GuiColor "#00CED1"

        # *** FIX: Restart JobMonitorTimer to process output from the new job ***
        if ($Global:JobMonitorTimer) {
            if (-not $Global:JobMonitorTimer.IsEnabled) {
                $Global:JobMonitorTimer.Start()
                Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.monitoringTimerRestarted') -GuiColor "#808080"
            }
        }
        # *** END FIX ***
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.errorStartingJob01' -Args @($scriptName, $($_.Exception.Message))) -GuiColor "#FF0000"
        Invoke-JobCompletion -JobStatus 'ErrorStarting' -JobName $scriptName
    }
}

# Function to process job completion
function Invoke-JobCompletion {
    param(
        [string]$JobStatus,
        [string]$JobName
    )

    # *** FIX: Separate synchronous UI logic from asynchronous job launching ***
    $window.Dispatcher.Invoke([Action] {
            if ($Global:ScriptJob) {
                $rawOutput = Receive-Job -Job $Global:ScriptJob -ErrorAction SilentlyContinue *>&1
                # Start-Job deserializes returned hashtables, so inspect properties
                # instead of relying on the original runtime type.
                $jobResultObject = $rawOutput |
                Where-Object {
                    $_ -and $_.PSObject.Properties['RebootRequired'] -and $_.PSObject.Properties['Success']
                } |
                Select-Object -Last 1

                if ($jobResultObject) {
                    $Global:RebootRequired = $Global:RebootRequired -or [bool]$jobResultObject.RebootRequired
                    $finalJobOutput = $rawOutput | Where-Object {
                        -not ($_ -and $_.PSObject.Properties['RebootRequired'] -and $_.PSObject.Properties['Success'])
                    }
                }
                else {
                    $finalJobOutput = $rawOutput
                }

                foreach ($line in ($finalJobOutput | Out-String -Stream)) {
                    [void](Format-JobOutput -Line $line)
                }
            }

            if ($JobStatus -eq 'Completed') {
                $jobReportedFailure = $jobResultObject -and
                $jobResultObject.PSObject.Properties['Success'] -and
                (-not [bool]$jobResultObject.Success)
                if (($Global:ScriptJob -and $Global:ScriptJob.HasErrors) -or $jobReportedFailure) {
                    $errorRecords = $Global:ScriptJob | Select-Object -ExpandProperty ChildJobs | Where-Object { $_.HasErrors } | Select-Object -ExpandProperty Error
                    $errorMessages = ($errorRecords | Select-Object -ExpandProperty Exception | Select-Object -ExpandProperty Message) -join "
"
                    if ([string]::IsNullOrEmpty($errorMessages) -and $jobResultObject.PSObject.Properties['Error']) {
                        $errorMessages = [string]$jobResultObject.Error
                    }
                    if ([string]::IsNullOrEmpty($errorMessages)) {
                        $errorMessages = Get-SourceTextLoc 'uiText.unknownErrorsOccurred'
                    }
                    Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.0CompletedWithErrors1' -Args @($JobName, $errorMessages)) -GuiColor "#FF0000"
                }
                else {
                    Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.completed0' -Args @($JobName)) -GuiColor "#00FF00"
                }
            }
            elseif ($JobStatus -eq 'Failed' -or $JobStatus -eq 'ErrorStarting') {
                $errorMsg = $null
                if ($Global:ScriptJob.JobStateInfo.Reason) {
                    $errorMsg = $Global:ScriptJob.JobStateInfo.Reason.Message
                }
                if ([string]::IsNullOrWhiteSpace($errorMsg) -and $Global:ScriptJob.ChildJobs) {
                    $errorMsg = ($Global:ScriptJob.ChildJobs |
                        Select-Object -ExpandProperty Error -ErrorAction SilentlyContinue |
                        Select-Object -ExpandProperty Exception -ErrorAction SilentlyContinue |
                        Select-Object -ExpandProperty Message -ErrorAction SilentlyContinue |
                        Select-Object -First 1)
                }
                if ([string]::IsNullOrWhiteSpace($errorMsg) -and $jobResultObject -and $jobResultObject.PSObject.Properties['Error']) {
                    $errorMsg = [string]$jobResultObject.Error
                }
                if ([string]::IsNullOrWhiteSpace($errorMsg)) { $errorMsg = Get-SourceTextLoc 'sourceText.unknownError' }
                Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.0Failed1' -Args @($JobName, $errorMsg)) -GuiColor "#FF0000"
            }
            elseif ($JobStatus -eq 'Stopped') {
                Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.0Discontinued' -Args @($JobName)) -GuiColor "#FFA500"
            }

            if ($Global:ScriptJob) {
                Remove-Job -Job $Global:ScriptJob -ErrorAction SilentlyContinue | Out-Null
                $Global:ScriptJob = $null
            }

            $Global:CurrentScriptIndex++
            if ($Global:SelectedScriptsQueue.Count -gt 0) {
                $progressPercentage = [int]((($Global:CurrentScriptIndex) / $Global:SelectedScriptsQueue.Count) * 100)
                if ($progressBar) { $progressBar.Value = $progressPercentage }
            }
            else {
                if ($progressBar) { $progressBar.Value = 100 }
            }
        })

    # Part 2: Start the next job (OUTSIDE the Dispatcher to avoid blocking the UI)
    if ($Global:CurrentScriptIndex -lt $Global:SelectedScriptsQueue.Count) {
        $window.Dispatcher.Invoke([Action] {
                Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.preparingTheNextScript') -GuiColor "#FFA500"
            })

        Start-Sleep -Milliseconds 200

        Start-NextScriptJob -scriptName $Global:SelectedScriptsQueue[$Global:CurrentScriptIndex]
    }
    else {
        $window.Dispatcher.Invoke([Action] {
                if ($Global:JobMonitorTimer) {
                    $Global:JobMonitorTimer.Stop()
                    $Global:JobMonitorTimer = $null
                }
                $executeButton.IsEnabled = $true
                Write-UnifiedLog -Type 'Success' -Message "🎉 $(Get-SourceTextLoc 'gui.allExecuted')" -GuiColor "#00FF00"
                if ($progressBar) { $progressBar.Value = 100 }

                if ($Global:RebootRequired) {
                    $result = [System.Windows.MessageBox]::Show((Get-SourceTextLoc 'gui.rebootPrompt'), (Get-SourceTextLoc 'gui.rebootTitle'), [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
                    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                        Restart-Computer -Force
                    }
                }
            })
    }
    # *** END FIX ***
}

# Timer Tick handler to monitor the job
function Tick_JobMonitor {
    if ($Global:ScriptJob -and ($Global:ScriptJob.State -eq 'Running' -or $Global:ScriptJob.State -eq 'NotStarted')) {
        # Receive available output in chunks for real-time updates
        $currentJobOutput = Receive-Job -Job $Global:ScriptJob -Keep -ErrorAction SilentlyContinue *>&1

        # Process only new output lines
        $newOutputLines = $currentJobOutput | Select-Object -Skip $Global:LastJobOutputCount
        if ($newOutputLines.Count -gt 0) {
            # Safely invoke on Dispatcher (prevent crash if window is closing)
            try {
                if ($window -and $window.Dispatcher) {
                    $window.Dispatcher.Invoke([Action] {
                            foreach ($line in ($newOutputLines | Out-String -Stream)) {
                                [void](Format-JobOutput -Line $line)
                            }
                        })
                }
            }
            catch {
                # Ignore dispatcher errors during shutdown
            }
            $Global:LastJobOutputCount = $currentJobOutput.Count
        }
    }
    elseif ($Global:ScriptJob -and ($Global:ScriptJob.State -eq 'Completed' -or $Global:ScriptJob.State -eq 'Failed' -or $Global:ScriptJob.State -eq 'Stopped')) {
        $Global:JobMonitorTimer.Stop()
        Invoke-JobCompletion -JobStatus $Global:ScriptJob.State -JobName $Global:SelectedScriptsQueue[$Global:CurrentScriptIndex]
    }
}

# ExecuteButton Click Handler - Updated for async execution
$executeButton.Add_Click({
        # Clear previous output
        $window.Dispatcher.Invoke([Action] {
                $outputTextBox.Document.Blocks.Clear()
                $Global:LastLogParagraphRef = $null
                $Global:LastLogEntryType = $null
            })

        # Get selected scripts on UI thread - use recursive search
        $selectedScripts = @()
        $allCheckBoxes = Get-AllCheckBoxes -Container $actionsPanel

        Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.total0CheckboxesFound' -Args @($($allCheckBoxes.Count))) -GuiColor "#00CED1"

        foreach ($checkBox in $allCheckBoxes) {
            try {
                if ($checkBox.IsChecked -eq $true) {
                    $scriptName = $checkBox.Tag
                    if ($scriptName) {
                        $selectedScripts += $scriptName
                        Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.selectedScript0' -Args @($scriptName)) -GuiColor "#00FF00"
                    }
                }
            }
            catch {
                Write-UnifiedLog -Type 'Warning' -Message (Get-SourceTextLoc 'uiText.checkboxReadingError0' -Args @($($_.Exception.Message))) -GuiColor "#FFA500"
            }
        }

        if ($selectedScripts.Count -eq 0) {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ $(Get-SourceTextLoc 'gui.noneSelected')" -GuiColor "#FFA500"
            $window.Dispatcher.Invoke([Action] { $executeButton.IsEnabled = $true })
            return
        }

        $Global:SelectedScriptsQueue = $selectedScripts
        $Global:CurrentScriptIndex = 0
        $Global:IsInputWaiting = $false
        $Global:RebootRequired = $false

        # Reset progress debouncer for new run
        $Global:LastLoggedProgress = @{ Percent = -1; Status = "" }

        # Initialize and start the timer if it is not already active
        if (-not $Global:JobMonitorTimer) {
            $Global:JobMonitorTimer = New-Object System.Windows.Threading.DispatcherTimer
            $Global:JobMonitorTimer.Interval = New-Object System.TimeSpan (0, 0, 0, 0, 500) # 500ms
            $Global:JobMonitorTimer.Add_Tick({ Tick_JobMonitor })
        }
        $Global:JobMonitorTimer.Start()

        # Start the first script
        Start-NextScriptJob -scriptName $Global:SelectedScriptsQueue[$Global:CurrentScriptIndex]
    })

# Add SendErrorLogs button click handler
$SendErrorLogsButton.Add_Click({
        try {
            Send-ErrorLogs
        }
        catch {
            Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.errorSendingLog0' -Args @($($_.Exception.Message))) -GuiColor "#FF0000"
        }
    })

# =============================================================================
# CONSOLE MINIMIZATION HELPER
# =============================================================================

function Set-ConsoleWindowMinimized {
    <#
    .SYNOPSIS
        Minimizes the PowerShell console window.
    #>
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WindowHelper {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public const int SW_MINIMIZE = 2;

    public static void Minimize() {
        IntPtr handle = System.Diagnostics.Process.GetCurrentProcess().MainWindowHandle;
        if (handle != IntPtr.Zero) {
            ShowWindow(handle, SW_MINIMIZE);
        }
    }
}
"@ -ReferencedAssemblies System.Windows.Forms

        [WindowHelper]::Minimize()
        Write-Host (Get-SourceTextLoc 'uiText.consoleMinimized') -ForegroundColor Cyan
    }
    catch {
        Write-Host (Get-SourceTextLoc 'uiText.couldNotMinimizeConsoleNonCritical') -ForegroundColor Yellow
    }
}

# =============================================================================
# INITIALIZATION AND DISPLAY
# =============================================================================

# Update system info and generate menu AFTER window is loaded to prevent handle exhaustion
$window.Add_Loaded({
        try {
            # Update system info
            Update-SystemInformationPanel

            # Generate dynamic menu
            Update-ActionsPanel

            # Show initial log message
            Write-UnifiedLog -Type 'Success' -Message "🎉 $(Get-SourceTextLoc 'gui.initialized')" -GuiColor "#00FF00"
            Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.coreVersion0' -Args @($Global:CoreScriptVersion)) -GuiColor "#00CED1"
            Write-UnifiedLog -Type 'Info' -Message "💡 $(Get-SourceTextLoc 'gui.instructions')" -GuiColor "#00CED1"

            # Minimize console - DISABLED to prevent handle exhaustion crash (Win32Exception 1816)
            # Set-ConsoleWindowMinimized
        }
        catch {
            Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.errorDuringInitializationLoaded0' -Args @($($_.Exception.Message))) -GuiColor "#FF0000"
        }
    })

# Cleanup handler for Window Closing to kill running jobs
$window.Add_Closing({
        if ($Global:ScriptJob) {
            Write-UnifiedLog -Type 'Info' -Message (Get-SourceTextLoc 'uiText.guiWindowClosedAttemptToStopTheJobInProgress') -GuiColor "#FFA500"
            try {
                Stop-Job -Job $Global:ScriptJob -Force -ErrorAction SilentlyContinue | Out-Null
                Remove-Job -Job $Global:ScriptJob -Force -ErrorAction SilentlyContinue | Out-Null
                $Global:ScriptJob = $null
                Write-UnifiedLog -Type 'Success' -Message (Get-SourceTextLoc 'uiText.jobInProgressStoppedAndRemoved') -GuiColor "#00FF00"
            }
            catch {
                Write-UnifiedLog -Type 'Error' -Message (Get-SourceTextLoc 'uiText.errorInterruptingJob0' -Args @($($_.Exception.Message))) -GuiColor "#FF0000"
            }
        }
        if ($Global:JobMonitorTimer) {
            $Global:JobMonitorTimer.Stop()
            $Global:JobMonitorTimer = $null
        }
        try {
            Stop-Transcript -ErrorAction SilentlyContinue
        }
        catch {}
    })

# Show window
$window.ShowDialog() | Out-Null

# Cleanup on exit
try {
    Stop-Transcript -ErrorAction SilentlyContinue
}
catch {}

