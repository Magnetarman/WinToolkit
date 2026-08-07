<#
.SYNOPSIS
    WinToolkit: Master Windows with Ease
.DESCRIPTION
    Unified modular framework.
    Contains the core functions (UI, Log, Info) and the main menu.
.NOTES
    Author: MagnetarMan
#>

param([int]$CountdownSeconds = 30, [switch]$ImportOnly, [string]$Language = 'en-US')

# ==============================================================================
# SECTION 1 · BOOTSTRAP
# Read-Host wrapper + initial process settings.
# ==============================================================================

function Read-Host {
    <#
    .SYNOPSIS
        Safe wrapper for Read-Host that handles CTRL+C interruptions without crashing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [Object]$Prompt,
        [switch]$AsSecureString,
        [switch]$MaskInput
    )

    if ($Host.Name -ne 'ConsoleHost' -or $Global:GuiSessionActive) {
        if ($Prompt) { return Microsoft.PowerShell.Utility\Read-Host -Prompt $Prompt }
        return Microsoft.PowerShell.Utility\Read-Host
    }

    $oldTreatControlC = [console]::TreatControlCAsInput
    try { [console]::TreatControlCAsInput = $true } catch {}

    try {
        if ($Prompt) { Write-Host "${Prompt}: " -NoNewline -ForegroundColor Cyan }

        $inputString = ""
        while ($true) {
            $keyInfo = [console]::ReadKey($true)

            if ($keyInfo.Modifiers -match "Control" -and $keyInfo.Key -eq "C") {
                Write-Host ""
                return $null
            }
            if ($keyInfo.Key -eq "Enter") {
                Write-Host ""
                if ($AsSecureString) {
                    $secure = New-Object System.Security.SecureString
                    foreach ($char in $inputString.ToCharArray()) { $secure.AppendChar($char) }
                    return $secure
                }
                if ($null -eq $inputString) { return "" }
                return $inputString
            }
            if ($keyInfo.Key -eq "Backspace") {
                if ($inputString.Length -gt 0) {
                    $inputString = $inputString.Substring(0, $inputString.Length - 1)
                    Write-Host "`b `b" -NoNewline
                }
            }
            else {
                if (-not [char]::IsControl($keyInfo.KeyChar)) {
                    $inputString += $keyInfo.KeyChar
                    if ($AsSecureString -or $MaskInput) { Write-Host "*" -NoNewline -ForegroundColor Yellow }
                    else { Write-Host $keyInfo.KeyChar -NoNewline }
                }
            }
        }
    }
    catch {
        if ($Prompt) { return Microsoft.PowerShell.Utility\Read-Host -Prompt $Prompt }
        return Microsoft.PowerShell.Utility\Read-Host
    }
    finally {
        try { [console]::TreatControlCAsInput = $oldTreatControlC } catch {}
    }
}

$ErrorActionPreference = 'Stop'
try { $Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan" } catch {}


# SECTION 2 · GLOBAL CONFIGURATION
# Version, URLs, paths, registry keys and UI/execution variables.
# ==============================================================================

$ToolkitVersion = "2.6.0 (Build 5)"

$AppConfig = @{
    URLs            = @{
        GitHubAssetBaseUrl    = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/assets/"
        GitHubAssetDevBaseUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/assets/"

        # Office
        OfficeSetup           = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/assets/Setup.exe"
        OfficeBasicConfig     = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/assets/Basic.xml"
        GetHelpInstaller      = "https://aka.ms/SaRA_EnterpriseVersionFiles"

        # Video Driver
        AMDInstaller          = "https://drivers.amd.com/drivers/installer/26.10/whql/amd-software-adrenalin-edition-26.5.2-minimalsetup-260513_web.exe"
        NVCleanstall          = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/assets/NVCleanstall_1.19.0.exe"
        DDUZip                = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/assets/DDU.zip"
        DriverOverridesJson   = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/assets/DriverOverrides.json"

        # Gaming
        DirectXWebSetup       = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/assets/dxwebsetup.exe"
        BattleNetInstaller    = "https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"

        # 7-Zip
        SevenZipOfficial      = "https://www.7-zip.org/a/7zr.exe"

        # Store
        WingetInstaller       = "https://aka.ms/getwinget"
        VCRedist86            = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
        VCRedist64            = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    }
    Paths           = @{
        Root                 = "$env:LOCALAPPDATA\WinToolkit"
        Logs                 = "$env:LOCALAPPDATA\WinToolkit\logs"
        Temp                 = "$env:TEMP\WinToolkit"
        Drivers              = "$env:LOCALAPPDATA\WinToolkit\Drivers"
        OfficeTemp           = "$env:LOCALAPPDATA\WinToolkit\Office"
        DriverBackupTemp     = "$env:TEMP\DriverBackup_Temp"
        DriverBackupLogs     = "$env:LOCALAPPDATA\WinToolkit\logs"
        GamingDirectX        = "$env:LOCALAPPDATA\WinToolkit\Directx"
        GamingDirectXSetup   = "$env:LOCALAPPDATA\WinToolkit\Directx\dxwebsetup.exe"
        BattleNetSetup       = "$env:TEMP\Battle.net-Setup.exe"
        Desktop              = [Environment]::GetFolderPath('Desktop')
        Startup              = [Environment]::GetFolderPath('Startup')
        TempFolder           = $env:TEMP
        LocalAppData         = $env:LOCALAPPDATA
        System32             = "$env:windir\System32"
        SoftwareDistribution = "$env:windir\SoftwareDistribution"
        Catroot2             = "$env:windir\System32\catroot2"
    }
    Registry        = @{
        WindowsUpdatePolicies = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ExcludeWUDrivers      = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\ExcludeWUDriversInQualityUpdate"
        OfficeTelemetry       = "HKLM:\SOFTWARE\Microsoft\Office\Common\ClientTelemetry"
        DisableTelemetry      = "HKLM:\SOFTWARE\Microsoft\Office\Common\ClientTelemetry\DisableTelemetry"
        OfficeFeedback        = "HKLM:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback"
        OnBootNotify          = "HKLM:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback\OnBootNotify"
        BitLocker             = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
        BitLockerStatus       = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"
        FocusAssist           = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
        NoGlobalToasts        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\NOC_GLOBAL_SETTING_TOASTS_ENABLED"
        StartupRun            = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        WindowsTerminal       = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    }
    WindowsTerminal = @{
        DelegationTerminalClsid = "{E12F0936-0E6F-548E-A9F6-B20C69A27D17}"
        DelegationConsoleClsid  = "{B23D10C0-31E3-401A-97EF-4BB30B62E10B}"
    }
    WingetProcesses = @(
        'WinStore.App', 'wsappx', 'AppInstaller',
        'Microsoft.WindowsStore', 'Microsoft.DesktopAppInstaller',
        'winget', 'WindowsPackageManagerServer'
    )
}

$Global:Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
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
        [string]$GitHubApiUrl = 'https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=Dev',
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


# SECTION 3 · UI — RENDERING AND PRESENTATION
# Visual output functions: messages, bars, headers, tables.
# Depend only on $Global:MsgStyles and Write-ToolkitLog (Section 4).
# ==============================================================================

function Clear-ProgressLine {
    if ($Host.Name -eq 'ConsoleHost') {
        try {
            $width = $Host.UI.RawUI.WindowSize.Width - 1
            Write-Host "`r$(' ' * $width)" -NoNewline
            Write-Host "`r" -NoNewline
        }
        catch {
            Write-Host "`r                                                                                `r" -NoNewline
        }
    }
}

function Get-CenteredText {
    param([string]$Text, [int]$Width = 0)
    if ($Width -eq 0) { $Width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 } }
    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    return (' ' * $padding + $Text)
}

function Write-StyledMessage {
    param(
        [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Progress', 'Question')][string]$Type,
        [string]$Text,
        [switch]$NoNewline
    )
    $style = $Global:MsgStyles[$Type]
    $timestamp = Get-Date -Format "HH:mm:ss"
    $displayText = $Text
    Write-Host "[$timestamp] $($style.Icon) $displayText" -ForegroundColor $style.Color -NoNewline:$NoNewline

    $logLevel = switch ($Type) {
        'Success' { 'SUCCESS' } 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' }
    }
    Write-ToolkitLog -Level $logLevel -Message $displayText
}

function Show-ProgressBar {
    <#
    .SYNOPSIS
        Mostra una barra di progresso testuale nella console.
    #>
    param([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon = '⏳', [string]$Spinner = '', [string]$Color = 'Green')
    $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
    $filled = '█' * [math]::Floor($safePercent * 30 / 100)
    $empty = '░' * (30 - $filled.Length)
    $bar = "[$filled$empty] {0,3}%" -f $safePercent
    $displayActivity = $Activity
    $displayStatus = $Status
    if (-not $Global:GuiSessionActive) {
        Write-Host "`r$Spinner $Icon $displayActivity $bar $displayStatus" -NoNewline -ForegroundColor $Color
        if ($Percent -ge 100) { Write-Host '' }
    }
}

function Write-ProgressUpdate {
    <#
    .SYNOPSIS
        Helper DRY: pulisce la riga e disegna Show-ProgressBar in un'unica chiamata.
        Usato da tutti gli spinner, download e countdown per evitare duplicazione di Clear + Write.
    #>
    param(
        [string]$Activity,
        [string]$Status = '',
        [int]$Percent = 0,
        [string]$Icon = '⏳',
        [string]$Color = 'Green',
        [string]$Spinner = ''
    )
    if ($Global:GuiSessionActive) { return }
    Clear-ProgressLine
    Show-ProgressBar -Activity $Activity -Status $Status -Percent $Percent -Icon $Icon -Spinner $Spinner -Color $Color
}

function Show-Header {
    <#
    .SYNOPSIS
        Mostra l'intestazione standardizzata del toolkit.
    #>
    param([string]$SubTitle)
    if ($Global:GuiSessionActive) { return }
    if ([string]::IsNullOrWhiteSpace($SubTitle)) { $SubTitle = Get-SourceTextLoc 'menu.main' }
    try { Clear-Host } catch {}
    $width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 }
    $asciiArt = @(
        '      __        __  _   _   _ ',
        '      \ \      / / | | | \ | |',
        '       \ \ /\ / /  | | |  \| |',
        '        \ V  V /   | | | |\  |',
        '         \_/\_/    |_| |_| \_|',
        '',
        "       WinToolkit - $SubTitle",
        ("       " + (Get-SourceTextLoc 'sourceText.version') + " $ToolkitVersion")
    )
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    foreach ($line in $asciiArt) { Write-Host (Get-CenteredText $line $width) -ForegroundColor White }
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    Write-Host ''
}

function Show-ConsoleTable {
    <#
    .SYNOPSIS
        Visualizza dati in formato tabellare ASCII nella console.
    .PARAMETER Rows
        Array di hashtable o pscustomobject da visualizzare.
    .PARAMETER Columns
        Array di hashtable con chiavi 'Header' (string) e 'Key' (string). Opzionale: 'Color'.
    .PARAMETER Title
        Titolo opzionale da mostrare sopra la tabella.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object[]]$Rows,
        [Parameter(Mandatory = $true)][hashtable[]]$Columns,
        [string]$Title = ''
    )

    $widths = @{}
    foreach ($col in $Columns) { $widths[$col.Key] = $col.Header.Length }
    foreach ($row in $Rows) {
        foreach ($col in $Columns) {
            $val = if ($row -is [hashtable]) { "$($row[$col.Key])" } else { "$($row.$($col.Key))" }
            if ($val.Length -gt $widths[$col.Key]) { $widths[$col.Key] = $val.Length }
        }
    }

    $sep = '+' + (($Columns | ForEach-Object { '-' * ($widths[$_.Key] + 2) }) -join '+') + '+'

    if ($Title) {
        $totalWidth = $sep.Length
        $paddedTitle = " $Title "
        $pad = [Math]::Max(0, [Math]::Floor(($totalWidth - $paddedTitle.Length) / 2))
        Write-Host ('=' * $totalWidth) -ForegroundColor Cyan
        Write-Host ((' ' * $pad) + $paddedTitle) -ForegroundColor Cyan
        Write-Host ('=' * $totalWidth) -ForegroundColor Cyan
    }

    Write-Host $sep -ForegroundColor DarkGray
    $headerLine = '|'
    foreach ($col in $Columns) { $headerLine += ' ' + $col.Header.PadRight($widths[$col.Key]) + ' |' }
    Write-Host $headerLine -ForegroundColor Cyan
    Write-Host $sep -ForegroundColor DarkGray

    foreach ($row in $Rows) {
        $line = '|'
        foreach ($col in $Columns) {
            $val = if ($row -is [hashtable]) { "$($row[$col.Key])" } else { "$($row.$($col.Key))" }
            $line += ' ' + $val.PadRight($widths[$col.Key]) + ' |'
        }
        $rowColor = 'White'
        $statusColumn = $Columns | Where-Object { $_.Key -eq 'Status' -or $_.Key -eq 'Stato' } | Select-Object -First 1
        $statusKey = if ($statusColumn) { $statusColumn.Key } else { $null }
        if ($statusKey) {
            $statusVal = if ($row -is [hashtable]) { "$($row[$statusKey])" } else { "$($row.$statusKey)" }
            if ($statusVal -match '✅|OK|Successo|Completato') { $rowColor = 'Green' }
            elseif ($statusVal -match '⚠️|Warning|Parziale') { $rowColor = 'Yellow' }
            elseif ($statusVal -match '❌|Errore|Fallito') { $rowColor = 'Red' }
        }
        Write-Host $line -ForegroundColor $rowColor
    }
    Write-Host $sep -ForegroundColor DarkGray
}


# ==============================================================================
# SEZIONE 4 · LOGGING
# Motore di log dual-stream: header di sessione + scrittura strutturata su file.
# Usato da Write-StyledMessage e da tutti i tool via Write-ToolkitLog.
# ==============================================================================

function Start-ToolkitLog {
    <#
    .SYNOPSIS
        Initializes the structured log file for a specific tool.
    #>
    param([string]$ToolName)

    $Global:CurrentToolName = $ToolName
    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}

    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = $AppConfig.Paths.Logs
    if (-not (Test-Path $logdir)) { New-Item -Path $logdir -ItemType Directory -Force | Out-Null }
    $Global:CurrentLogFile = "$logdir\${ToolName}_$dateTime.log"
    $Global:CurrentCorrelationId = [guid]::NewGuid().ToString()

    $os = Get-CimInstance Win32_OperatingSystem  -ErrorAction SilentlyContinue
    $psVer = $PSVersionTable.PSVersion.ToString()
    $psEd = $PSVersionTable.PSEdition
    $psCompat = ($PSVersionTable.PSCompatibleVersions | ForEach-Object { $_.ToString() }) -join ', '
    $gitId = if ($PSVersionTable.GitCommitId) { $PSVersionTable.GitCommitId } else { 'N/A' }
    $wsManVer = if ($PSVersionTable.WSManStackVersion) { $PSVersionTable.WSManStackVersion.ToString() } else { 'N/A' }
    $remoteVer = if ($PSVersionTable.PSRemotingProtocolVersion) { $PSVersionTable.PSRemotingProtocolVersion.ToString() } else { 'N/A' }
    $serVer = if ($PSVersionTable.SerializationVersion) { $PSVersionTable.SerializationVersion.ToString() } else { 'N/A' }

    $build = [int]$os.BuildNumber
    $verMap = @{26100 = '24H2'; 22631 = '23H2'; 22621 = '22H2'; 22000 = '21H2'; 19045 = '22H2'; 19044 = '21H2' }
    $dispVer = 'N/A'
    foreach ($k in ($verMap.Keys | Sort-Object -Descending)) { if ($build -ge $k) { $dispVer = $verMap[$k]; break } }

    $header = @"
[START LOG HEADER]
Start time              : $dateTime
CorrelationId           : $($Global:CurrentCorrelationId)
ToolName                : $ToolName
PSVersion               : $psVer
PSEdition               : $psEd
GitCommitId             : $gitId
ToolkitVersion          : $($Global:ToolkitVersion)
OS                      : $($os.Caption)
    Version                 : Version $dispVer (OS build $($os.BuildNumber))
Platform                : $([Environment]::OSVersion.Platform)
PSCompatibleVersions    : $psCompat
PSRemotingProtocolVersion: $remoteVer
SerializationVersion    : $serVer
WSManStackVersion       : $wsManVer
[END LOG HEADER]

"@
    try { Add-Content -Path $Global:CurrentLogFile -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}

function Write-ToolkitLog {
    <#
    .SYNOPSIS
        Scrive una riga di log strutturata solo su file. Mai su console.
        Resiliente: assorbe qualsiasi errore I/O senza crashare il toolkit.
    #>
    param(
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',
        [string]$Message,
        [hashtable]$Context = @{}
    )
    if (-not $Global:CurrentLogFile) { return }

    $ts = Get-Date -Format "HH:mm:ss"
    $clean = $Message -replace '^\s+', ''
    $clean = $clean -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
    $clean = $clean -replace '[⌀-⏿☀-➿\uD800-\uDFFF]', ''
    $line = "[$ts] [$Level] $clean"
    if ($Context.Count -gt 0) {
        try { $line += " | Context: " + ($Context | ConvertTo-Json -Compress -Depth 3) } catch {}
    }
    try {
        $mutex = New-Object System.Threading.Mutex($false, "Global\WinToolkitLogMutex")
        $hasHandle = $false
        try {
            $hasHandle = $mutex.WaitOne(5000)
            if ($hasHandle) { Add-Content -Path $Global:CurrentLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue }
        }
        finally {
            if ($hasHandle) { $mutex.ReleaseMutex() }
            $mutex.Dispose()
        }
    }
    catch {}
}


function Write-ToolkitError {
    <#
    .SYNOPSIS
        Scrive un errore strutturato su console e su file di log.
        Sostituisce il blocco catch+log ripetuto in ogni tool.
    #>
    param(
        [System.Management.Automation.ErrorRecord]$Record,
        [string]$ToolName,
        [string]$Message
    )
    if ([string]::IsNullOrWhiteSpace($Message)) { $Message = Get-SourceTextLoc 'sourceText.criticalError' }
    Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'uiText.0In12' -Args @($Message, ${ToolName}, $($Record.Exception.Message)))
    Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'uiText.0In1' -Args @($Message, $ToolName)) -Context @{
        Line      = $Record.InvocationInfo.ScriptLineNumber
        Exception = $Record.Exception.GetType().FullName
        Stack     = $Record.ScriptStackTrace
    }
}


# SECTION 5 · SYSTEM — INFORMATION AND STATUS
# Data collection on the operating system, hardware and security services.
# ==============================================================================

function Get-SystemInfo {
    if ($Global:SystemInfoCache) { return $Global:SystemInfoCache }
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $computerInfo = Get-CimInstance Win32_ComputerSystem
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $versionMap = @{
            28000 = "26H1"; 26200 = "25H2"; 26100 = "24H2"; 22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2"
            19045 = "22H2"; 19044 = "21H2"; 19043 = "21H1"; 19042 = "20H2"; 19041 = "2004"; 18363 = "1909"
            18362 = "1903"; 17763 = "1809"; 17134 = "1803"; 16299 = "1709"; 15063 = "1703"; 14393 = "1607"
            10586 = "1511"; 10240 = "1507"
        }
        $build = [int]$osInfo.BuildNumber
        $ver = "N/A"
        foreach ($k in ($versionMap.Keys | Sort-Object -Descending)) { if ($build -ge $k) { $ver = $versionMap[$k]; break } }

        $Global:SystemInfoCache = @{
            ProductName    = $osInfo.Caption -replace 'Microsoft ', ''
            BuildNumber    = $build
            DisplayVersion = $ver
            Architecture   = $osInfo.OSArchitecture
            ComputerName   = $computerInfo.Name
            TotalRAM       = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
            TotalDisk      = [Math]::Round($diskInfo.Size / 1GB, 0)
            FreeDisk       = [Math]::Round($diskInfo.FreeSpace / 1GB, 0)
            FreePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)
        }
        return $Global:SystemInfoCache
    }
    catch { return $null }
}

function Convert-BitlockerStatusToKey {
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

function Get-BitlockerStatus {
    param([switch]$Key)

    try {
        $out = & manage-bde -status C: 2>&1
        $statusText = $null
        if ($out -match "(?im)^\s*(Stato protezione|Protection Status):\s*(.*)$") {
            $statusText = $matches[2].Trim()
        }

        $statusKey = Convert-BitlockerStatusToKey -StatusText $statusText
        if ($Key) { return $statusKey }
        return (Get-SourceTextLoc $statusKey)
    }
    catch {
        if ($Key) { return 'bitlocker.status.off' }
        return (Get-SourceTextLoc 'bitlocker.status.off')
    }
}


function Get-SourceTextLocalUserProfiles {
    <#
    .SYNOPSIS
        Restituisce le directory utente reali, escludendo i profili di sistema.
    #>
    return Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '^(Public|Default|Default User|All Users)$' }
}


# ==============================================================================
# SEZIONE 6 · AMBIENTE — PERCORSI E INIZIALIZZAZIONE
# Creazione directory di lavoro e refresh del PATH di processo.
# ==============================================================================

function Initialize-ToolkitPaths {
    <#
    .SYNOPSIS
        Ensures creation of all required directories on first run.
    #>
    foreach ($path in $AppConfig.Paths.Values) {
        if (-not (Test-Path $path -PathType Leaf) -and $path -notmatch "\.exe$|\.zip$|\.msixbundle$") {
            try {
                if (-not (Test-Path $path)) { $null = New-Item -Path $path -ItemType Directory -Force -ErrorAction SilentlyContinue }
            }
            catch {}
        }
    }
}

function Update-EnvironmentPath {
    <#
    .SYNOPSIS
        Ricarica il PATH dalle variabili di sistema e utente per la sessione corrente.
    #>
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
    $env:Path = $newPath
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
}


function Set-RegistryValue {
    <#
    .SYNOPSIS
        Crea la chiave di registro se mancante e imposta il valore specificato.
    #>
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if (-not (Test-Path $Path)) { $null = New-Item -Path $Path -Force }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}


# ==============================================================================
# SEZIONE 7 · PROCESSI ED ESECUZIONE
# Chiusura processi, esecuzione comandi esterni con log, spinner, countdown.
# ==============================================================================

function Stop-ToolkitProcesses {
    <#
    .SYNOPSIS
        Chiude in modo forzato e silenzioso i processi specificati.
    #>
    param([string[]]$ProcessNames)
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.closingInterferingProcesses2')
    foreach ($procName in $ProcessNames) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -ne $PID } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
}

function Invoke-ExternalCommandWithLog {
    <#
    .SYNOPSIS
        Executes an external command with structured logging and full STDOUT/STDERR capture.
    .DESCRIPTION
        Standardized wrapper for external processes.
        Logga comando, argomenti, exit code, durata ed eventuali errori.
        Restituisce un oggetto con Success, ExitCode, StdOut, StdErr, Elapsed.
        Non scrive mai direttamente su console.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory,
        [int]$TimeoutSeconds = 0,
        [string]$LogContextKey = '',
        [string]$Activity = '',
        [int]$UpdateInterval = 500,
        [string]$Tool = $Global:CurrentToolName,
        [string]$Step = 'ExternalCommand'
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $startTime = Get-Date
    $argString = $Arguments -join ' '

    Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'uiText.runningCommand01Timeout2S' -Args @($Command, $argString, ${TimeoutSeconds}))
    Write-ToolkitLog -Level 'DEBUG' -Message (Get-SourceTextLoc 'uiText.commandContext') -Context @{
        Tool = $Tool; Step = $Step; WorkingDir = $WorkingDirectory; ContextKey = $LogContextKey
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Command
    $psi.Arguments = $argString
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $outText = ""; $errText = ""; $success = $false; $exitCode = $null; $timedOut = $false

    try {
        if (-not $proc.Start()) { throw (Get-SourceTextLoc 'uiText.unableToStartExternalProcess') }

        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()

        if ($Activity) {
            $spinnerIndex = 0; $percent = 0
            while (-not $proc.HasExited -and ($TimeoutSeconds -eq 0 -or ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds)) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                if ($percent -lt 90) { $percent += Get-Random -Minimum 1 -Maximum 3 }
                Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.executing0Seconds' -Args @($elapsed)) -Percent $percent -Icon '⏳' -Spinner $spinner
                Start-Sleep -Milliseconds $UpdateInterval
                $proc.Refresh()
            }
            if (-not $proc.HasExited -and $TimeoutSeconds -gt 0) {
                try { $proc.Kill() } catch {}
                throw (Get-SourceTextLoc 'uiText.timeoutAfter0Seconds' -Args @($TimeoutSeconds))
            }
            Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
            if (-not $Global:GuiSessionActive) { Write-Host "" }
        }
        else {
            if ($TimeoutSeconds -gt 0) {
                if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
                    try { $proc.Kill() } catch {}
                    throw (Get-SourceTextLoc 'uiText.timeoutAfter0Seconds' -Args @($TimeoutSeconds))
                }
            }
            else { $proc.WaitForExit() }
        }

        try { [System.Threading.Tasks.Task]::WaitAll($outTask, $errTask) } catch {}
        if ($outTask.Status -eq 'RanToCompletion') { $outText = $outTask.Result }
        if ($errTask.Status -eq 'RanToCompletion') { $errText = $errTask.Result }

        $exitCode = $proc.ExitCode
        $success = ($exitCode -eq 0)
    }
    catch {
        $exitCode = if ($null -ne $exitCode) { $exitCode } else { -1 }
        if ($_.Exception.Message -match 'Timeout') { $timedOut = $true }
        Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.exceptionWhileRunningExternalCommand') -Context @{
            Command = $Command; Arguments = $Arguments; WorkingDir = $WorkingDirectory
            TimeoutSec = $TimeoutSeconds; ContextKey = $LogContextKey
            Exception = $_.Exception.Message; Stack = $_.ScriptStackTrace
        }
    }
    finally {
        $stopwatch.Stop()
        if ($null -eq $outText) { $outText = "" }
        if ($null -eq $errText) { $errText = "" }

        $maxLen = 8000
        $outLogged = if ($outText.Length -gt $maxLen) { $outText.Substring(0, $maxLen) + "`n[...output truncated...]" } else { $outText }
        $errLogged = if ($errText.Length -gt $maxLen) { $errText.Substring(0, $maxLen) + "`n[...stderr truncated...]" } else { $errText }

        $statusMsg = if ($success) { Get-SourceTextLoc 'sourceText.completedSuccessfully' } else { Get-SourceTextLoc 'sourceText.completedWithErrors' }
        Write-ToolkitLog -Level 'INFO'  -Message (Get-SourceTextLoc 'uiText.command0ExitCode1Duration2' -Args @($statusMsg, $exitCode, $($stopwatch.Elapsed.ToString('hh\:mm\:ss'))))
        Write-ToolkitLog -Level 'DEBUG' -Message (Get-SourceTextLoc 'uiText.commandOutput0' -Args @($Command)) -Context @{
            ContextKey = $LogContextKey; StdOutSnippet = $outLogged; StdErrSnippet = $errLogged
        }
        if ($proc) { $proc.Dispose() }
    }

    [pscustomobject]@{
        Success  = $success
        ExitCode = $exitCode
        StdOut   = $outText
        StdErr   = $errText
        Elapsed  = $stopwatch.Elapsed
        TimedOut = $timedOut
    }
}

function Invoke-WithSpinner {
    <#
    .SYNOPSIS
        Executes an action with automatic spinner animation.
    .DESCRIPTION
        Higher-order function that automatically manages spinner
        animation for async operations, processes, jobs or timers.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Activity,
        [scriptblock]$Action,
        [int]$TimeoutSeconds = 300,
        [int]$UpdateInterval = 500,
        [switch]$Process,
        [switch]$Job,
        [switch]$Timer,
        [scriptblock]$PercentUpdate,
        [string]$Command,
        [string[]]$Arguments = @(),
        [string]$LogContextKey = ''
    )

    $startTime = Get-Date
    $spinnerIndex = 0
    $percent = 0

    if ($Command) {
        return Invoke-ExternalCommandWithLog -Command $Command -Arguments $Arguments `
            -TimeoutSeconds $TimeoutSeconds -Activity $Activity -UpdateInterval $UpdateInterval -LogContextKey $LogContextKey
    }

    try {
        $result = & $Action

        if ($Timer) {
            $totalSeconds = $TimeoutSeconds
            for ($i = $totalSeconds; $i -gt 0; $i--) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                $percent = if ($PercentUpdate) { & $PercentUpdate } else { [math]::Round((($totalSeconds - $i) / $totalSeconds) * 100) }
                Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.01Seconds' -Args @($Activity, $i)) -Status '' -Percent $percent -Icon '⏳' -Spinner $spinner -Color 'Yellow'
                Start-Sleep -Seconds 1
            }
            if (-not $Global:GuiSessionActive) { Write-Host '' }
            return $true
        }
        elseif ($Process -and $result -and $result.GetType().Name -eq 'Process') {
            while (-not $result.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                $percent = if ($PercentUpdate) { & $PercentUpdate } elseif ($percent -lt 90) { $percent + (Get-Random -Minimum 1 -Maximum 3) } else { $percent }
                Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.executing0Seconds' -Args @($elapsed)) -Percent $percent -Icon '⏳' -Spinner $spinner
                Start-Sleep -Milliseconds $UpdateInterval
                $result.Refresh()
            }
            if (-not $result.HasExited) {
                Write-ProgressUpdate -Activity $Activity -Status '' -Percent 0
                if (-not $Global:GuiSessionActive) { Write-Host "" }
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.timeoutReachedAfter0SecondsProcessTermination' -Args @($TimeoutSeconds))
                $result.Kill(); Start-Sleep -Seconds 2
                return @{ Success = $false; TimedOut = $true; ExitCode = -1 }
            }
            Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
            if (-not $Global:GuiSessionActive) { Write-Host "" }
            return @{ Success = $true; TimedOut = $false; ExitCode = $result.ExitCode }
        }
        elseif ($Job -and $result -and $result.GetType().Name -eq 'Job') {
            while ($result.State -eq 'Running') {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                Write-Host "`r$spinner $Activity..." -NoNewline -ForegroundColor Yellow
                Start-Sleep -Milliseconds $UpdateInterval
            }
            $jobResult = Receive-Job $result -Wait
            Write-Host ''
            return $jobResult
        }
        else {
            Start-Sleep -Seconds $TimeoutSeconds
            return $result
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'uiText.errorDuring01' -Args @(${Activity}, $($_.Exception.Message)))
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Start-InterruptibleCountdown {
    <#
    .SYNOPSIS
        Conto alla rovescia interrompibile dall'utente con pressione di un tasto.
    #>
    param([int]$Seconds = 30, [string]$Message, [switch]$Suppress)
    if ($Suppress) { return $true }
    if ([string]::IsNullOrWhiteSpace($Message)) { $Message = Get-SourceTextLoc 'sourceText.automaticRestart' }

    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'uiText.pressAnyKeyToCancel')
    Write-Host ''
    for ($i = $Seconds; $i -gt 0; $i--) {
        if ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
            Write-Host "`n"
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.systemRebootCancelled')
            return $false
        }
        $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
        Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.0In1Seconds' -Args @($Message, $i)) -Status '' -Percent $percent -Icon '⏰' -Color 'Red'
        Start-Sleep 1
    }
    Write-Host "`n"
    return $true
}


function Start-ToolkitSession {
    <#
    .SYNOPSIS
        Standard initialization for every tool: log, header, window title.
        Replaces the identical 3-line block present in all tools.
    #>
    param([string]$ToolName, [string]$SubTitle = $ToolName)
    Start-ToolkitLog -ToolName $ToolName
    Show-Header -SubTitle $SubTitle
    try { $Host.UI.RawUI.WindowTitle = "$SubTitle By MagnetarMan" } catch {}
}

function Invoke-ToolkitReboot {
    <#
    .SYNOPSIS
        Centralized reboot management: suppressed (multi-script) or interruptible countdown.
        Replaces the 9-line if/else block present in 11 tools.
    #>
    param(
        [string]$Message,
        [int]$Seconds = 30,
        [switch]$SuppressIndividualReboot
    )
    if ([string]::IsNullOrWhiteSpace($Message)) { $Message = Get-SourceTextLoc 'sourceText.operationCompleted' }
    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'uiText.individualRestartSuppressedAFinalRebootWillBeHandled')
    }
    else {
        if (Start-InterruptibleCountdown -Seconds $Seconds -Message $Message) {
            Restart-Computer -Force
        }
    }
}

function Remove-ItemSafely {
    <#
    .SYNOPSIS
        Silently removes a path (file or directory) without exceptions.
        Versione generalizzata di Invoke-OfficeSilentRemoval.
    #>
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$Recurse)
    if (-not (Test-Path $Path)) { return $false }
    try {
        $params = @{ Path = $Path; Force = $true; ErrorAction = 'SilentlyContinue' }
        if ($Recurse) { $params['Recurse'] = $true }
        Remove-Item @params *>$null
        Clear-ProgressLine
        return $true
    }
    catch { return $false }
}

function Invoke-ToolkitDownload {
    <#
    .SYNOPSIS
        Download di un file con retry automatico, barra di progresso, referrer AMD e messaggi standardizzati.
    .DESCRIPTION
        Implementa download con visualizzazione della barra di progresso in tempo reale.
        Supporta URL AMD con referrer per aggirare i blocchi.
        Retry automatico e fallback robusti per connessioni instabili.
    #>
    param(
        [string]$Uri,
        [string]$OutputPath,
        [string]$Description,
        [int]$MaxRetries = 3,
        [switch]$NoSpinner
    )
    
    if ([string]::IsNullOrWhiteSpace($Description)) { $Description = Get-SourceTextLoc 'sourceText.file' }
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'uiText.download0' -Args @($Description))
            
            # Creare parent directory se non esiste
            $parentDir = Split-Path -Parent $OutputPath
            if (-not (Test-Path $parentDir)) {
                New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
            }
            
            # Create HttpClient with 5 minute timeout
            $handler = New-Object System.Net.Http.HttpClientHandler
            $handler.AllowAutoRedirect = $true
            $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
            
            $httpClient = New-Object System.Net.Http.HttpClient($handler)
            $httpClient.Timeout = [TimeSpan]::FromSeconds(300)
            
            # Add custom headers
            $httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
            if ($Uri -match 'drivers\.amd\.com|amd-software') {
                $httpClient.DefaultRequestHeaders.Add("Referer", "https://www.amd.com")
            }
            
            # Perform HEAD request to get the size
            $totalBytes = 0
            try {
                $headRequest = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Head, $Uri)
                $headResponse = $httpClient.SendAsync($headRequest).Result
                if ($headResponse.Content.Headers.ContentLength -gt 0) {
                    $totalBytes = $headResponse.Content.Headers.ContentLength
                }
                $headResponse.Dispose()
            }
            catch {}  # Continue even if HEAD fails
            
            # Perform the GET download
            $getRequest = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $Uri)
            $getResponse = $httpClient.SendAsync($getRequest, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
            
            if (-not $getResponse.IsSuccessStatusCode) {
                throw (Get-SourceTextLoc 'uiText.httpError01' -Args @($($getResponse.StatusCode), $($getResponse.ReasonPhrase)))
            }
            
            # Try to get the size from the GET response if HEAD failed
            if ($totalBytes -eq 0 -and $getResponse.Content.Headers.ContentLength -gt 0) {
                $totalBytes = $getResponse.Content.Headers.ContentLength
            }

            # === NEW LOGIC: Fake progress bar disconnected from download ===
            $isUnknownSize = ($totalBytes -eq 0)
            $fakeProgressStart = $null
            if ($isUnknownSize -and -not $Global:GuiSessionActive) {
                $fakeProgressStart = Get-Date
                # Show fake bar immediately (before starting to read data)
                Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.download02' -Args @($Description)) `
                    -Status (Get-SourceTextLoc 'uiText.startingDownload') `
                    -Percent 8 -Icon '📥' -Color 'Cyan'
                Start-Sleep -Milliseconds 120   # small visual delay to make the bar appear
            }
            
            # Read the stream and write with progress tracking
            $contentStream = $getResponse.Content.ReadAsStreamAsync().Result
            $fileStream = [System.IO.File]::Create($OutputPath)
            $buffer = New-Object byte[] 8192
            $totalRead = 0
            $lastPercent = -1
            $lastProgressTime = Get-Date
            
            try {
                while ($true) {
                    $read = $contentStream.Read($buffer, 0, $buffer.Length)
                    if ($read -eq 0) { break }
                    
                    $fileStream.Write($buffer, 0, $read)
                    $totalRead += $read
                    
                    # Progress state calculation (DRY: logic here, rendering delegated)
                    if (-not $Global:GuiSessionActive) {
                        $currentDisplay = if ($totalRead -gt 1048576) {
                            "$([Math]::Round($totalRead / 1048576, 1)) MB"
                        }
                        else {
                            "$([Math]::Round($totalRead / 1024, 1)) KB"
                        }
                        
                        if ($totalBytes -gt 0) {
                            $percent = [Math]::Round(($totalRead / $totalBytes) * 100)
                            $totalDisplay = if ($totalBytes -gt 1048576) {
                                "$([Math]::Round($totalBytes / 1048576, 1)) MB"
                            }
                            else {
                                "$([Math]::Round($totalBytes / 1024, 1)) KB"
                            }
                            $status = "($currentDisplay / $totalDisplay)"
                            $icon = '📥'
                            $col = 'Cyan'
                        }
                        else {
                            # === Barra COMPLETAMENTE SCOLLEGATA dal download ===
                            # Use only elapsed time since the fake bar appeared
                            if ($fakeProgressStart) {
                                $elapsed = ((Get-Date) - $fakeProgressStart).TotalSeconds
                                # Rampa uniforme e prevedibile - max 95% durante il download
                                # (100% is forced only when the file is written to disk)
                                $percent = [math]::Min(95, [math]::Floor(8 + ($elapsed * 1.52)))
                            }
                            else {
                                $percent = 50   # fallback
                            }
                            $status = "$currentDisplay scaricati"
                            $icon = '📥'
                            $col = 'Cyan'
                        }
                        
                        $now = Get-Date
                        $timeSinceLast = ($now - $lastProgressTime).TotalMilliseconds
                        $shouldUpdate = $false

                        if ($lastPercent -eq -1) {
                            # First update: always show immediately (0% or first chunk)
                            $shouldUpdate = $true
                        }
                        elseif ($totalBytes -gt 0) {
                            # Known size: rate-limited + percent change (smooth, non-schizzofrenico)
                            if ($percent -ne $lastPercent -and $timeSinceLast -gt 250) {
                                $shouldUpdate = $true
                            }
                        }
                        else {
                            if ($timeSinceLast -gt 400 -or $percent -ne $lastPercent) {
                                $shouldUpdate = $true
                            }
                        }

                        if ($shouldUpdate) {
                            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.download02' -Args @($Description)) -Status $status -Percent $percent -Icon $icon -Color $col
                            $lastPercent = $percent
                            $lastProgressTime = $now
                        }
                    }
                }
            }
            finally {
                $fileStream.Dispose()
                $contentStream.Dispose()
            }
            
            $httpClient.Dispose()
            $handler.Dispose()
            
            if (Test-Path $OutputPath) {
                if ($totalBytes -gt 0) {
                    Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.download02' -Args @($Description)) -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅' -Color 'Green'
                }
                else {
                    Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.download02' -Args @($Description)) -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅' -Color 'Green'
                    if (-not $Global:GuiSessionActive) { Write-Host "" }
                }
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.downloadCompleted0' -Args @($Description))
                return $true
            }
        }
        catch {
            # Pulire in caso di errore
            if (Test-Path $OutputPath) {
                Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
            }
            
            if ($attempt -lt $MaxRetries) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.01AttemptFailed2ILlTryAgain' -Args @($attempt, $MaxRetries, $($_.Exception.Message)))
                Start-Sleep -Seconds 2
            }
        }
    }
    Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'uiText.downloadFailedAfter0Attempts1' -Args @($MaxRetries, $Description))
    return $false
}

function Restart-ServiceSafely {
    <#
    .SYNOPSIS
        Stop + Start of a Windows service with standardized error handling.
    #>
    param([string]$Name, [int]$WaitSeconds = 1)
    try {
        Stop-Service -Name $Name -Force -ErrorAction Stop
        Start-Sleep -Seconds $WaitSeconds
        Start-Service -Name $Name -ErrorAction Stop
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.serviceRestarted0' -Args @($Name))
        return $true
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.failedToRestart01' -Args @($Name, $($_.Exception.Message)))
        return $false
    }
}


# ==============================================================================
# SEZIONE 8 · WINGET — INSTALLAZIONE E RIPRISTINO
# Risoluzione eseguibile, installazione AppX silenziosa, validazione e reset.
# ==============================================================================

function Get-WingetExecutable {
    <#
    .SYNOPSIS
        Risolve il percorso di winget.exe privilegiando l'App Execution Alias.
    #>
    $aliasPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path $aliasPath) { return $aliasPath }

    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $wingetDir = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" `
        -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1

    if ($wingetDir) {
        $exe = Join-Path $wingetDir.FullName "winget.exe"
        if (Test-Path $exe) { return $exe }
    }
    return "winget"
}

function Start-AppxSilentProcess {
    <#
    .SYNOPSIS
        Installa un AppX tramite System.Diagnostics.Process (CreateNoWindow=true).
        Blocca le write Win32 native del deployment engine e gestisce il downgrade.
    #>
    param(
        [string]$AppxPath,
        [string]$Flags = '-ForceApplicationShutdown',
        [string[]]$DependencyPaths = @()
    )

    $pathParam = if ($Flags -match '-Register') { "" } else { "-Path '$($AppxPath -replace "'", "''")'" }
    $depString = ""
    if ($DependencyPaths.Count -gt 0) {
        $depString = "-DependencyPackagePath " + (($DependencyPaths | ForEach-Object { "'$($_ -replace "'", "''")'" }) -join ", ")
    }

    $cmd = @"
`$ProgressPreference = 'SilentlyContinue';
`$ErrorActionPreference = 'SilentlyContinue';
try {
    Add-AppxPackage $pathParam $depString $Flags -ErrorAction Stop | Out-Null
}
catch {
    if (`$_.Exception.Message -match '0x80073D06' -or `$_.Exception.Message -match 'versione successiva') { exit 0 }
    if (`$_.Exception.Message -match '0x80073CF9' -or ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)) {
        try {
            if ('$pathParam' -eq '') { exit 1 }
            Add-AppxProvisionedPackage -Online -PackagePath '$($AppxPath -replace "'", "''")' $depString -SkipLicense -ErrorAction Stop | Out-Null
            exit 0
        }
        catch { exit 1 }
    }
    exit 1
}
exit 0
"@
    $encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -NonInteractive -EncodedCommand $encodedCmd"
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    return [System.Diagnostics.Process]::Start($psi)
}

function Wait-WingetReady {
    <#
    .SYNOPSIS
        Polls for up to 5 minutes to verify that Winget is ready and the database is unlocked.
    #>
    param([int]$MaxWaitSeconds = 300, [int]$PollIntervalSeconds = 5)

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.wingetIntegrityValidationInProgressTimeout0S' -Args @($MaxWaitSeconds))
    $wingetExe = Get-WingetExecutable
    $maxRetries = [Math]::Floor($MaxWaitSeconds / $PollIntervalSeconds)

    for ($i = 1; $i -le $maxRetries; $i++) {
        try {
            $versionProc = Start-Process -FilePath $wingetExe -ArgumentList '--version' `
                -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
            $dbProc = Start-Process -FilePath $wingetExe `
                -ArgumentList 'list', 'NonExistentApp_WinToolkitCheck', '--accept-source-agreements' `
                -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
            if ($versionProc.ExitCode -eq 0 -and $dbProc.ExitCode -eq 0) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetReadyAndDatabaseUnlockedAttempt01' -Args @($i, $maxRetries))
                return $true
            }
        }
        catch {}
        $remaining = $MaxWaitSeconds - ($i * $PollIntervalSeconds)
        Write-StyledMessage -Type Progress -Text (Get-SourceTextLoc 'uiText.wingetNotYetReadyAttempt012SRemainWait' -Args @($i, $maxRetries, $remaining))
        Start-Sleep -Seconds $PollIntervalSeconds
    }
    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetDidNotRespondWithin0SecondsIContinueAnyway' -Args @($MaxWaitSeconds))
    return $false
}

function Reset-Winget {
    <#
    .SYNOPSIS
        Verifies, restores and tests the Winget installation.
    .DESCRIPTION
        Integrated two-phase procedure for complete Winget repair.

        Phase 1 — Core Restore (fast):
          VC++ Redistributable, AppX dependencies from official repo, main MSIXBundle.

        Phase 2 — Advanced Restore (if Phase 1 is insufficient):
          Microsoft.WinGet.Client, Repair-WinGetPackageManager, database restore,
          permissions and PATH reset.

        Includes deep post-installation validation with ACCESS_VIOLATION detection.
    #>
    param([switch]$Force)

    $ProgressPreference = 'SilentlyContinue'
    $OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

    # ── Helper privati ────────────────────────────────────────────────────────

    function Test-VCRedistInstalled {
        $64BitOS = [System.Environment]::Is64BitOperatingSystem
        $registryPath = [string]::Format(
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\{0}\Microsoft\VisualStudio\14.0\VC\Runtimes\X{1}',
            $(if ($64BitOS) { 'WOW6432Node' } else { '' }),
            $(if ($64BitOS) { '64' } else { '86' })
        )
        $major = (Get-ItemProperty -Path $registryPath -Name 'Major' -ErrorAction SilentlyContinue).Major
        $dllPath = [string]::Format('{0}\system32\concrt140.dll', $env:windir)
        return (Test-Path $registryPath) -and ($major -ge 14) -and (Test-Path $dllPath)
    }

    function Register-AppxManifest {
        try {
            $manifest = (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue).InstallLocation
            if ($manifest) {
                $manifestXml = Join-Path $manifest 'AppxManifest.xml'
                if (Test-Path $manifestXml) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.manifestReRegistrationAppxmanifestXmlPreventsLeaks')
                    Start-AppxSilentProcess -AppxPath $manifestXml -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown' | Out-Null
                }
            }
        }
        catch {}
    }

    function Get-LatestAssetUrl {
        param([string]$Match)
        try {
            $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing -ErrorAction Stop
            $asset = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
            if ($asset) { return $asset.browser_download_url }
            return $null
        }
        catch { return $null }
    }

    function Test-WingetCompatibility {
        $os = [Environment]::OSVersion.Version
        if ($os.Major -lt 10 -or ($os.Major -eq 10 -and $os.Build -lt 16299)) {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.systemNotSupportedByWingetWindows101709Required')
            return $false
        }
        return $true
    }

    function Test-WingetFunctionality {
        Update-EnvironmentPath
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInPath')
            return $false
        }
        try {
            $versionOutput = (& (Get-WingetExecutable) --version 2>$null) | Out-String
            if ($LASTEXITCODE -eq 0 -and $versionOutput -match 'v\d+\.\d+') {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.operationalWingetVersion02' -Args @($($versionOutput.Trim())))
                return $true
            }
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetPresentButNotRespondingCorrectlyExitcode0' -Args @($LASTEXITCODE))
            return $false
        }
        catch {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.errorDuringWingetTest0' -Args @($($_.Exception.Message)))
            return $false
        }
    }

    function Test-PathInEnvironment {
        param([string]$PathToCheck, [string]$Scope = 'Both')
        $found = $false
        if ($Scope -in 'User', 'Both') { if (($env:PATH -split ';').Contains($PathToCheck)) { $found = $true } }
        if ($Scope -in 'System', 'Both') {
            $syspath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
            if (($syspath -split ';').Contains($PathToCheck)) { $found = $true }
        }
        return $found
    }

    function Add-ToEnvironmentPath {
        param([string]$PathToAdd, [ValidateSet('User', 'System')][string]$Scope)
        if (Test-PathInEnvironment -PathToCheck $PathToAdd -Scope $Scope) { return }
        if ($Scope -eq 'System') {
            $cur = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
            [Environment]::SetEnvironmentVariable('PATH', "$cur;$PathToAdd", 'Machine')
        }
        else {
            $cur = [Environment]::GetEnvironmentVariable('PATH', 'User')
            [Environment]::SetEnvironmentVariable('PATH', "$cur;$PathToAdd", 'User')
        }
        if (-not ($env:PATH -split ';').Contains($PathToAdd)) { $env:PATH += ";$PathToAdd" }
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.updatedPath0' -Args @($PathToAdd))
    }

    function Set-PathPermissions {
        param([string]$FolderPath)
        if (-not (Test-Path $FolderPath)) { return }
        try {
            $sid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
            $group = $sid.Translate([System.Security.Principal.NTAccount])
            $acl = Get-Acl -Path $FolderPath -ErrorAction Stop
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $group, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $acl.SetAccessRule($rule)
            Set-Acl -Path $FolderPath -AclObject $acl -ErrorAction Stop
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.updatedFolderPermissions0' -Args @($FolderPath))
        }
        catch { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.unableToSetPermissionsOn01' -Args @($FolderPath, $($_.Exception.Message))) }
    }

    function Set-WingetPathPermissions {
        $wingetFolderPath = $null
        try {
            $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
            $wingetDir = Get-ChildItem "$env:ProgramFiles\WindowsApps" `
                -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
            if ($wingetDir) { $wingetFolderPath = $wingetDir.FullName }
        }
        catch {}
        if ($wingetFolderPath) {
            Set-PathPermissions -FolderPath $wingetFolderPath
            Add-ToEnvironmentPath -PathToAdd $wingetFolderPath -Scope 'System'
            Add-ToEnvironmentPath -PathToAdd '%LOCALAPPDATA%\Microsoft\WindowsApps' -Scope 'User'
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.pathAndWingetPermissionsUpdated2')
        }
    }

    function _Repair-WingetDatabase {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.ripristinoDatabaseWinget')
        try {
            Stop-ToolkitProcesses -ProcessNames $AppConfig.WingetProcesses

            $cachePath = "$env:LOCALAPPDATA\WinGet"
            if (Test-Path $cachePath) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.puliziaCacheWinget')
                Get-ChildItem -Path $cachePath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '\\lock\\|\\tmp\\' } |
                ForEach-Object { try { Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue } catch {} }
            }

            @("$env:LOCALAPPDATA\WinGet\Data\USERTEMPLATE.json",
                "$env:LOCALAPPDATA\WinGet\Data\DEFAULTUSER.json") | ForEach-Object {
                if (Test-Path $_ -PathType Leaf) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetStatusFile0' -Args @($_))
                    Remove-Item $_ -Force -ErrorAction SilentlyContinue
                }
            }

            try { $null = & (Get-WingetExecutable) source reset --force 2>&1 } catch {}

            if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
                Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
            }

            try {
                $manifest = (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue).InstallLocation
                if ($manifest) {
                    $manifestXml = Join-Path $manifest 'AppxManifest.xml'
                    if (Test-Path $manifestXml) {
                        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.reRegisterManifestAppxmanifestXml')
                        Start-AppxSilentProcess -AppxPath $manifestXml -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown' | Out-Null
                    }
                }
            }
            catch {}

            try {
                if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.esecuzioneRepairWingetpackagemanager')
                    Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                }
            }
            catch {
                if ($_.Exception.Message -match '0x80073D06' -or $_.Exception.Message -match 'versione successiva') {
                    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerCompletedHigherVersionAlreadyPresent')
                }
                else { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerFallito0' -Args @($($_.Exception.Message))) }
            }

            Set-WingetPathPermissions
            Update-EnvironmentPath
            return $true
        }
        catch {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorDuringDatabaseRestore0' -Args @($($_.Exception.Message)))
            return $false
        }
    }

    function _Install-WingetAdvanced {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.advancedInstallationViaMicrosoftWingetClientModule')
        try {
            if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
                if ($PSVersionTable.PSVersion.Major -lt 7) {
                    try { Install-PackageProvider -Name 'NuGet' -Force -ForceBootstrap -ErrorAction SilentlyContinue *>$null }
                    catch { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.nugetProviderNotInstallable') }
                }
            }

            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingMicrosoftWingetClientModule')
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
                Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetClientModuleInstalled')
            }
            catch { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.failedToInstallWingetClientModule0' -Args @($($_.Exception.Message))) }

            if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.tentativoRepairWingetpackagemanager')
                try {
                    Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerCompletato')
                }
                catch {
                    if ($_.Exception.Message -match '0x80073D06' -or $_.Exception.Message -match 'versione successiva') {
                        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerIgnoredHigherVersionAlreadyPresent')
                    }
                    else { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerFallito0' -Args @($($_.Exception.Message))) }
                }
                Start-Sleep 3
            }

            Update-EnvironmentPath
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.fallbackDownloadMsixbundleDirectFromMicrosoft')
                $tempDir = $AppConfig.Paths.Temp
                if (-not (Test-Path $tempDir)) { $null = New-Item -Path $tempDir -ItemType Directory -Force }
                $tempInstaller = Join-Path $tempDir "WingetInstaller.msixbundle"
                Invoke-WebRequest -Uri $AppConfig.URLs.WingetInstaller -OutFile $tempInstaller -UseBasicParsing -ErrorAction Stop
                Start-AppxSilentProcess -AppxPath $tempInstaller -Flags '-ForceApplicationShutdown'
                Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
                Start-Sleep 3
            }

            try { Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null } catch {}
            Set-WingetPathPermissions
            Update-EnvironmentPath
            return $true
        }
        catch {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.wingetAdvancedInstallationError0' -Args @($($_.Exception.Message)))
            return $false
        }
    }

    function Test-WingetDeepValidation {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.wingetDeepValidationConnectivityDatabaseIntegrity')
        try {
            $wingetExe = Get-WingetExecutable
            $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.crashAccessViolationExitcode0RipristinoDatabase' -Args @($exitCode))
                $null = _Repair-WingetDatabase
                Start-Sleep 3
                $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
                $exitCode = $LASTEXITCODE
                if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.persistentCrashAfterDatabaseRestore')
                    return $false
                }
            }

            if ($exitCode -eq 0) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.deepValidationPassedWingetCommunicatesWithRepositories')
                return $true
            }
            $details = ($searchResult | Out-String).Trim()
            if ($details.Length -gt 200) { $details = $details.Substring(0, 200) + "..." }
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.deepValidationFailedExitcode0Details1' -Args @($exitCode, $details))
            return $false
        }
        catch {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.deepValidationError0' -Args @($($_.Exception.Message)))
            return $false
        }
    }

    # ── Orchestrazione principale ─────────────────────────────────────────────

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingWingetAdvancedRepair')
    if (-not (Test-WingetCompatibility)) { return $false }
    if (-not $Force -and (Test-WingetFunctionality)) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetAlreadyOperationalNoRepairsNecessary')
        return $true
    }

    Stop-ToolkitProcesses -ProcessNames $AppConfig.WingetProcesses

    try {
        # Fase 1: Ripristino Core
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.phase1CoreRecoveryVcAppxDependenciesMsixbundle')

        if (-not (Test-VCRedistInstalled) -or $Force) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingVisualCRedistributable')
            $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
            $vcUrl = "https://aka.ms/vs/17/release/vc_redist.$arch.exe"
            $vcFile = Join-Path $AppConfig.Paths.Temp "vc_redist.exe"
            if (-not (Test-Path $AppConfig.Paths.Temp)) { $null = New-Item $AppConfig.Paths.Temp -ItemType Directory -Force }
            Invoke-WebRequest -Uri $vcUrl -OutFile $vcFile -UseBasicParsing
            Start-Process -FilePath $vcFile -ArgumentList "/install", "/quiet", "/norestart" -Wait
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.vcRedistInstalled')
        }

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadWingetDependenciesFromTheOfficialRepository2')
        $depUrl = Get-LatestAssetUrl -Match 'DesktopAppInstaller_Dependencies.zip'
        if ($depUrl) {
            $depZip = Join-Path $AppConfig.Paths.Temp "dependencies.zip"
            $depDir = Join-Path $AppConfig.Paths.Temp "deps"
            Invoke-WebRequest -Uri $depUrl -OutFile $depZip -UseBasicParsing
            Expand-Archive -Path $depZip -DestinationPath $depDir -Force
            $archPattern = if ([Environment]::Is64BitOperatingSystem) { "x64|ne" } else { "x86|ne" }
            $script:WingetDependencies = @()
            Get-ChildItem $depDir -Recurse -Filter "*.appx" |
            Where-Object { $_.Name -match $archPattern } |
            ForEach-Object { Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.dependencyFound0' -Args @($($_.Name))); $script:WingetDependencies += $_.FullName }
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.loadedDependencies')
        }

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingWingetMsixbundleWithDependencies')
        $bundleUrl = Get-LatestAssetUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        if ($bundleUrl) {
            $bundleFile = Join-Path $AppConfig.Paths.Temp "winget.msixbundle"
            Invoke-WebRequest -Uri $bundleUrl -OutFile $bundleFile -UseBasicParsing
            $deps = if ($script:WingetDependencies) { $script:WingetDependencies } else { @() }
            Start-AppxSilentProcess -AppxPath $bundleFile -DependencyPaths $deps -Flags '-ForceApplicationShutdown'
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetCoreInstalled')
        }

        Register-AppxManifest
        Update-EnvironmentPath

        if (Test-WingetFunctionality) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.phase1CompletedOperationalWinget')
        }
        else {
            # Fase 2: Ripristino Avanzato
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.phase1InsufficientStartingPhase2AdvancedRecovery')
            $null = _Install-WingetAdvanced
            $null = _Repair-WingetDatabase
            Update-EnvironmentPath
        }

        Start-Sleep -Seconds 3
        try {
            Start-Process -FilePath (Get-WingetExecutable) -ArgumentList 'source', 'reset', '--force' `
                -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        }
        catch {}

        $deepOk = Test-WingetDeepValidation
        if ($deepOk) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetSuccessfullyRestoredAndTested')
            return $true
        }
        else {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstalledDeepValidationWithAnomaliesPossibleNetworkOrDbProblems')
            return $true
        }
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.criticalErrorInReset0' -Args @($($_.Exception.Message)))
        return $false
    }
    finally {
        if (Test-Path $AppConfig.Paths.Temp) { Remove-Item $AppConfig.Paths.Temp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}


# ==============================================================================
# SEZIONE 9 · INTERAZIONE UTENTE
# Input validato, conferme e selezioni di menu.
# ==============================================================================

function Get-UserConfirmation {
    <#
    .SYNOPSIS
        Requests user confirmation (Yes/No) in a standardized way.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [switch]$DefaultYes,
        [ValidateSet('Info', 'Warning', 'Question')][string]$Level = 'Question'
    )

    $choices = if ($DefaultYes) { "[S/n]" } else { "[s/N]" }
    $fullPrompt = "$Prompt $choices"

    if ($Global:GuiSessionActive) {
        Write-StyledMessage -Type $Level -Text $fullPrompt
        return $true
    }

    Write-StyledMessage -Type $Level -Text "${fullPrompt}: " -NoNewline
    $response = Read-Host
    Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'uiText.userConfirmationPrompt0Response1' -Args @($Prompt, $response))

    if ([string]::IsNullOrWhiteSpace($response)) { return $DefaultYes }
    return $response -match '^[sS]'
}

function Read-ValidatedChoice {
    <#
    .SYNOPSIS
        Legge e valida scelte numeriche dall'utente (singole o multiple).
    #>
    param(
        [int[]]$ValidRange,
        [int]$Min,
        [int]$Max,
        [switch]$AllowZero,
        [string]$Prompt = "Seleziona un'opzione",
        [string]$RawInput
    )

    $currentInput = if ($PSBoundParameters.ContainsKey('RawInput')) { $RawInput } else { $null }
    while ($true) {
        $userInput = if ($null -ne $currentInput) {
            $val = $currentInput; $currentInput = $null; $val
        }
        else {
            Write-StyledMessage -Type 'Question' -Text "${Prompt}: " -NoNewline
            Microsoft.PowerShell.Utility\Read-Host
        }

        if ([string]::IsNullOrWhiteSpace($userInput)) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.emptyInputTryAgain')
            continue
        }

        $choices = $userInput -split '[\s,]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }

        if ($choices.Count -gt 0) {
            $isValid = $true
            foreach ($c in $choices) {
                if ($null -ne $ValidRange) { if ($c -notin $ValidRange) { $isValid = $false; break } }
                else {
                    if ($AllowZero -and $c -eq 0) { continue }
                    if ($null -ne $Min -and $c -lt $Min) { $isValid = $false; break }
                    if ($null -ne $Max -and $c -gt $Max) { $isValid = $false; break }
                }
            }
            if ($isValid) {
                Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'uiText.userChoices0' -Args @($($choices -join ',')))
                return $choices
            }
        }

        $rangeStr = if ($null -ne $ValidRange) { "$($ValidRange[0]) e $($ValidRange[-1])" } else { "$Min e $Max" }
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.invalidChoiceEnterNumbersBetween0' -Args @($rangeStr))
    }
}


# SECTION 10 · SYSTEM VERIFICATION AND COMPATIBILITY
# Pre-execution checks: OS, pending updates.
# ==============================================================================

function WinOSCheck {
    if ($Global:GuiSessionActive) { return }
    Show-Header -SubTitle (Get-SourceTextLoc 'system.infoTitle')
    $si = Get-SystemInfo
    if (-not $si) { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.systemInfoNotAvailable'); return }

    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'uiText.system01' -Args @($($si.ProductName), $($si.DisplayVersion)))

    if ($si.BuildNumber -ge 22000) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.compatibleSystemRecentWin1110') }
    elseif ($si.BuildNumber -ge 17763) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.compatibleSystemWin10') }
    elseif ($si.BuildNumber -eq 9600) { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.windows81PartialCompatibility') }
    else {
        Write-StyledMessage -Type 'Error' -Text "$(Get-CenteredText ('🤣 ' + (Get-SourceTextLoc 'sourceText.criticalError').ToUpperInvariant() + ' 🤣') 65)"
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'uiText.doYouReallyThinkThisScriptCanDoAnythingForThisVersion')
        Write-Host ("  " + (Get-SourceTextLoc 'uiText.doYouWantToTakeARiskYN')) -ForegroundColor Yellow
        if ((Read-Host) -notmatch '^[Yy]$') { exit }
    }
    Start-Sleep -Seconds 2
}

function Test-WindowsUpdateStatus {
    <#
    .SYNOPSIS
        Checks Windows Update status and warns about pending operations.
    .DESCRIPTION
        Checks pending reboot and TrustedInstaller service status.
        Uses PSWindowsUpdate if available, otherwise falls back to registry and native services.
    #>
    try {
        if ($Global:GuiSessionActive) { return }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'uiText.windowsUpdateStatusCheck')

        $pendingReboot = $false
        $installerRunning = $false

        if (Get-Module -ListAvailable -Name PSWindowsUpdate -ErrorAction SilentlyContinue) {
            Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
            try {
                $rebootStatus = Get-WURebootStatus -ErrorAction SilentlyContinue
                if ($rebootStatus -and $rebootStatus.RebootRequired) {
                    $pendingReboot = $true
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.pendingRebootDetectedForWindowsUpdates')
                }
            }
            catch {}
            try {
                $installerStatus = Get-WUInstallerStatus -ErrorAction SilentlyContinue
                if ($installerStatus -and $installerStatus.IsBusy) {
                    $installerRunning = $true
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.windowsUpdateInstallationServiceCurrentlyRunning')
                }
            }
            catch {}
        }
        else {
            $regPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootRequired",
                "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"
            )
            foreach ($path in $regPaths) {
                if (Test-Path $path -ErrorAction SilentlyContinue) { $pendingReboot = $true; break }
            }
            $trustedInstaller = Get-Service -Name TrustedInstaller -ErrorAction SilentlyContinue
            if ($trustedInstaller -and $trustedInstaller.Status -eq 'Running') { $installerRunning = $true }
        }

        if ($pendingReboot -or $installerRunning) {
            $width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 }
            Write-Host ""
            Write-Host ('═' * ($width - 1)) -ForegroundColor Yellow
            Write-Host ""
            Write-Host (Get-CenteredText (Get-SourceTextLoc 'uiText.importantWarning')) -ForegroundColor Yellow
            Write-Host ""
            Write-Host (" " + (Get-SourceTextLoc 'uiText.pendingSystemUpdatesHaveBeenDetected')) -ForegroundColor Yellow
            if ($pendingReboot) { Write-Host ("  " + (Get-SourceTextLoc 'uiText.systemRestartRequiredToCompleteUpdates')) -ForegroundColor Yellow }
            if ($installerRunning) { Write-Host ("  " + (Get-SourceTextLoc 'uiText.windowsUpdateInstallationServiceIsRunning')) -ForegroundColor Yellow }
            Write-Host ""
            Write-Host (" " + (Get-SourceTextLoc 'uiText.thisMayCauseMalfunctionsErrorsOrBehavior')) -ForegroundColor Yellow
            Write-Host (" " + (Get-SourceTextLoc 'uiText.unexpectedBehaviorInSomeOrAllWintoolkitFeatures')) -ForegroundColor Yellow
            Write-Host ""
            Write-Host (Get-CenteredText (Get-SourceTextLoc 'uiText.proceedWithCaution')) -ForegroundColor Red
            Write-Host ""
            Write-Host (" " + (Get-SourceTextLoc 'uiText.weStronglyRecommendThatYouCompleteAllOngoingUpdates')) -ForegroundColor Yellow
            Write-Host (" " + (Get-SourceTextLoc 'uiText.rebootYourSystemAndThenRestartWintoolkitBeforeContinuing')) -ForegroundColor Yellow
            Write-Host ""
            Write-Host ('═' * ($width - 1)) -ForegroundColor Yellow
            Write-Host ""
            Start-Sleep -Seconds 5
        }
        else {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.noPendingUpdatesDetected')
        }
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.unableToCheckWindowsUpdateStatus0' -Args @($($_.Exception.Message)))
    }
}


# SECTION 11 · OFFICE — SHARED HELPERS
# Functions shared by Install-Office, Repair-Office and Uninstall-Office.
# Defined at script scope to be accessible from all three compiled tools.
# ==============================================================================

function Invoke-OfficeSilentRemoval {
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$Recurse)
    return Remove-ItemSafely -Path $Path -Recurse:$Recurse
}

function Stop-OfficeProcesses {
    $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
    $closed = 0
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'uiText.closingOfficeProcesses')
    foreach ($processName in $processes) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($running) {
            try { $running | Stop-Process -Force -ErrorAction Stop; $closed++ }
            catch { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.unableToClose0' -Args @($processName)) }
        }
    }
    if ($closed -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.0OfficeProcessesClosed' -Args @($closed)) }
}

function Invoke-OfficeDownloadFile([string]$Url, [string]$OutputPath, [string]$Description) {
    return Invoke-ToolkitDownload -Uri $Url -OutputPath $OutputPath -Description $Description
}

function Set-OfficePostConfig {
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'uiText.deepOptimizationOfMicrosoftOffice')

    $registrySettings = @(
        # Privacy & Telemetria
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "disconnectedstate"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "usercontentdisabled"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "downloadcontentdisabled"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"; Name = "ShownOptIn"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback"; Name = "Enabled"; Value = 0 },
        # Performance & UI
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Graphics"; Name = "DisableAnimations"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Graphics"; Name = "DisableHardwareAcceleration"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"; Name = "DisableBootToStartScreen"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\LinkedIn"; Name = "ShowLinkedInIntegration"; Value = 0 }
    )

    foreach ($reg in $registrySettings) {
        if (-not (Test-Path $reg.Path)) { $null = New-Item -Path $reg.Path -Force }
        Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type 'DWord' -Force
    }

    $tasksToDisable = @(
        "OfficeTelemetryAgentLogon", "OfficeTelemetryAgentFallback",
        "OfficeBackgroundTaskHandlerRegistration", "OfficeBackgroundTaskHandlerLogon",
        "OfficeFeatureUpdates", "OfficeFeatureUpdatesLogon"
    )
    foreach ($tName in $tasksToDisable) {
        Get-ScheduledTask | Where-Object { $_.TaskName -eq $tName } | Disable-ScheduledTask -ErrorAction SilentlyContinue
    }

    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.officeOptimizedTelemetryPrivacyAndScheduledTasksRemoved')
}

function VcardAnalizer {
    <#
    .SYNOPSIS
        Analyzes present GPUs and tries to associate stable drivers from DriverOverrides.json.
    .DESCRIPTION
        Detects cards even without complete drivers using Win32_VideoController (Name/Caption/PNPDeviceID),
        compares data with an override JSON file and saves the result in
        $Global:VcardAnalysisResult for reuse in tools.
    #>
    [CmdletBinding()]
    param(
        [string]$OverridesPath
    )

    $assetCacheDir = Join-Path $AppConfig.Paths.Root 'assets'
    if (-not (Test-Path $assetCacheDir)) {
        $null = New-Item -Path $assetCacheDir -ItemType Directory -Force
    }
    $defaultLocalOverrides = Join-Path $assetCacheDir 'DriverOverrides.json'
    $resolvedOverridesPath = if ($OverridesPath) { $OverridesPath } else { $defaultLocalOverrides }

    $analysis = [pscustomobject]@{
        Cards               = @()
        Matches             = @()
        PrimaryManufacturer = 'Unknown'
        OverridesLoaded     = $false
        OverridesSource     = $resolvedOverridesPath
    }

    try {
        $cards = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        foreach ($card in $cards) {
            $name = [string]$card.Name
            $caption = [string]$card.Caption
            $pnpId = [string]$card.PNPDeviceID
            $manufacturer = 'Unknown'

            if ($name -match 'NVIDIA|GeForce|Quadro|Tesla' -or $caption -match 'NVIDIA') { $manufacturer = 'NVIDIA' }
            elseif ($name -match 'AMD|Radeon|ATI' -or $caption -match 'AMD|ATI') { $manufacturer = 'AMD' }
            elseif ($name -match 'Intel|Iris|UHD|HD Graphics' -or $caption -match 'Intel') { $manufacturer = 'Intel' }

            $analysis.Cards += [pscustomobject]@{
                Name         = $name
                Caption      = $caption
                PnpDeviceID  = $pnpId
                Manufacturer = $manufacturer
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.gpuAnalysisErrorReadingWin32Videocontroller0' -Args @($($_.Exception.Message)))
    }

    if ($analysis.Cards.Count -gt 0) {
        $analysis.PrimaryManufacturer = ($analysis.Cards | Select-Object -First 1).Manufacturer
    }

    $overrides = @()
    $remoteUrl = $AppConfig.URLs.DriverOverridesJson
    if ([string]::IsNullOrWhiteSpace($remoteUrl)) {
        $remoteUrl = "$($AppConfig.URLs.GitHubAssetBaseUrl)DriverOverrides.json"
    }

    try {
        if (Invoke-ToolkitDownload -Uri $remoteUrl -OutputPath $defaultLocalOverrides -Description 'Driver Overrides JSON') {
            $resolvedOverridesPath = $defaultLocalOverrides
            $analysis.OverridesSource = $resolvedOverridesPath
        }
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.driveroverridesJsonDownloadFailedUseLocalCacheIfAvailable')
    }

    if (Test-Path $resolvedOverridesPath) {
        try {
            $jsonRaw = Get-Content -Path $resolvedOverridesPath -Raw -Encoding UTF8
            $parsed = $jsonRaw | ConvertFrom-Json -ErrorAction Stop
            if ($parsed -is [System.Array]) { $overrides = $parsed }
            elseif ($parsed) { $overrides = @($parsed) }
            $analysis.OverridesLoaded = $true
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.invalidDriveroverridesJson0' -Args @($($_.Exception.Message)))
        }
    }
    else {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.driveroverridesJsonNotFoundIn0' -Args @($resolvedOverridesPath))
    }

    foreach ($gpu in $analysis.Cards) {
        foreach ($ovr in $overrides) {
            $namePattern = [string]$ovr.NamePattern
            $pnpPattern = [string]$ovr.PnpIdPattern
            $manufacturer = [string]$ovr.Manufacturer

            $nameMatches = $false
            $pnpMatches = $false
            $mfrMatches = $false

            if (-not [string]::IsNullOrWhiteSpace($namePattern) -and -not [string]::IsNullOrWhiteSpace($gpu.Name)) {
                $nameMatches = $gpu.Name -match $namePattern
            }
            if (-not [string]::IsNullOrWhiteSpace($pnpPattern) -and -not [string]::IsNullOrWhiteSpace($gpu.PnpDeviceID)) {
                $pnpMatches = $gpu.PnpDeviceID -like $pnpPattern
            }
            if (-not [string]::IsNullOrWhiteSpace($manufacturer) -and $gpu.Manufacturer -ne 'Unknown') {
                $mfrMatches = $gpu.Manufacturer -eq $manufacturer
            }

            if (($nameMatches -or $pnpMatches) -and ($mfrMatches -or [string]::IsNullOrWhiteSpace($manufacturer))) {
                $analysis.Matches += [pscustomobject]@{
                    Key          = [string]$ovr.Key
                    Manufacturer = [string]$ovr.Manufacturer
                    NamePattern  = [string]$ovr.NamePattern
                    PnpIdPattern = [string]$ovr.PnpIdPattern
                    DownloadUrl  = [string]$ovr.DownloadUrl
                    FileName     = [string]$ovr.FileName
                    DisplayName  = [string]$ovr.DisplayName
                    MatchedGpu   = [string]$gpu.Name
                    MatchedPnpId = [string]$gpu.PnpDeviceID
                }
            }
        }
    }

    if ($analysis.Matches.Count -gt 0) {
        $analysis.Matches = @($analysis.Matches | Group-Object Key | ForEach-Object { $_.Group | Select-Object -First 1 })
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.detected0StableDriverMatchesFromDriveroverridesJson' -Args @($($analysis.Matches.Count)))
    }
    else {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.noKnownStableDriversFoundForTheDetectedGpus')
    }

    $Global:VcardAnalysisResult = $analysis
    return $analysis
}


# ==============================================================================
# SEZIONE 12 · PLACEHOLDER COMPILATORE
# Stub vuoti sostituiti dal compiler.ps1 con i contenuti di /tools/*.ps1.
# Ordine: Windows → Office → Driver/Gaming → Supporto (segue $menuStructure).
# ==============================================================================

# Windows
function WinRepairToolkit {}
function WinUpdateReset {}
function WinReinstallStore {}
function WinBackupDriver {}
function WinDriverInstall {}
function WinDebloat {}
function WinCleaner {}
function DisableBitlocker {}
function WinDeleteUserProfiles {}

# Office
function Install-Office {}
function Repair-Office {}
function Uninstall-Office {}

# Driver & Gaming
function AutoVideoDriverInstall {}
function VideoDriverReinstall {}
function GamingToolkit {}

# Supporto
function WinExportLog {}


# ==============================================================================
# SECTION 13 · MENU STRUCTURE
# Category and interactive TUI menu item definitions.
# ==============================================================================

$menuStructure = @(
    @{ 'Name' = 'Windows'; 'CategoryKey' = 'category.windows'; 'Icon' = '🔧'; 'Scripts' = @(
            [pscustomobject]@{Name = 'WinRepairToolkit'; Description = 'Windows Repair'; DescriptionKey = 'script.WinRepairToolkit'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinUpdateReset'; Description = 'Reset Windows Update'; DescriptionKey = 'script.WinUpdateReset'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset'; DescriptionKey = 'script.WinReinstallStore'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinBackupDriver'; Description = 'Backup Driver PC'; DescriptionKey = 'script.WinBackupDriver'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinCleaner'; Description = 'Temporary File Cleanup'; DescriptionKey = 'script.WinCleaner'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'DisableBitlocker'; Description = 'Disable BitLocker'; DescriptionKey = 'script.DisableBitlocker'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinDeleteUserProfiles'; Description = 'Delete Windows User Profiles'; DescriptionKey = 'script.WinDeleteUserProfiles'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Office'; 'CategoryKey' = 'category.office'; 'Icon' = '🏢'; 'Scripts' = @(
            [pscustomobject]@{Name = 'Install-Office'; Description = 'Install Office Basic'; DescriptionKey = 'script.Install-Office'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'Repair-Office'; Description = 'Repair Office'; DescriptionKey = 'script.Repair-Office'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'Uninstall-Office'; Description = 'Remove Office'; DescriptionKey = 'script.Uninstall-Office'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Driver & Gaming'; 'CategoryKey' = 'category.driverGaming'; 'Icon' = '🎮'; 'Scripts' = @(
            [pscustomobject]@{Name = 'AutoVideoDriverInstall'; Description = 'Auto Install Driver Video [Nvidia-AMD]'; DescriptionKey = 'script.AutoVideoDriverInstall'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'VideoDriverReinstall'; Description = 'Reinstall Video Driver'; DescriptionKey = 'script.VideoDriverReinstall'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'GamingToolkit'; Description = 'Gaming Toolkit'; DescriptionKey = 'script.GamingToolkit'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Support'; 'CategoryKey' = 'category.support'; 'Icon' = '🕹️'; 'Scripts' = @(
            [pscustomobject]@{Name = 'WinExportLog'; Description = 'Export WinToolkit Logs'; DescriptionKey = 'script.WinExportLog'; Action = 'RunFunction' }
        )
    }
)


# ==============================================================================
# SECTION 14 · INITIALIZATION
# Single startup block: paths, OS check, updates.
# Executed only in interactive mode (not -ImportOnly, not GUI).
# ==============================================================================

if (-not $ImportOnly) {
    Initialize-ToolkitPaths
    WinOSCheck
    Test-WindowsUpdateStatus
}


# SECTION 15 · MAIN MENU
# Interactive TUI loop. Suppressed in library mode (-ImportOnly) and GUI.
# ==============================================================================

if (-not $ImportOnly -and -not $Global:GuiSessionActive) {

    Write-Host ""
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'menu.startedInteractive')
    Write-Host ""

    function Confirm-UserProfileDeletion {
        Write-Host ''
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'confirm.profile.warn1')
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'confirm.profile.warn2')
        Write-Host ''
        Write-Host "💎 [1] $(Get-SourceTextLoc 'confirm.profile.yes')" -ForegroundColor White
        Write-Host "[INVIO] $(Get-SourceTextLoc 'menu.back')" -ForegroundColor Gray
        $firstConfirm = Microsoft.PowerShell.Utility\Read-Host (Get-SourceTextLoc 'menu.choice')

        if ($firstConfirm -ne '1') {
            return $false
        }

        Write-Host ''
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'confirm.profile.sure')
        Write-Host ''
        Write-Host "💎 [1] $(Get-SourceTextLoc 'confirm.profile.accept')" -ForegroundColor White
        Write-Host "[INVIO] $(Get-SourceTextLoc 'menu.back')" -ForegroundColor Gray
        $secondConfirm = Microsoft.PowerShell.Utility\Read-Host (Get-SourceTextLoc 'menu.choice')

        return ($secondConfirm -eq '1')
    }

    function Show-LanguageMenu {
        while ($true) {
            Show-Header -SubTitle (Get-SourceTextLoc 'menu.language')
            Write-Host ''
            Write-Host "==== 🌐 $(Get-SourceTextLoc 'menu.chooseLanguage') 🌐 ====" -ForegroundColor Cyan
            Write-Host ''

            $languages = @(Get-AvailableSourceTextLanguages)
            if ($languages.Count -eq 0) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'menu.noLanguages')
                Start-Sleep -Seconds 2
                return
            }

            for ($i = 0; $i -lt $languages.Count; $i++) {
                $marker = if ($languages[$i].Code -eq $Global:SourceTextLanguage) { '*' } else { ' ' }
                $aiTag = if ($languages[$i].AiTranslated) { ' [AI Trad.]' } else { '' }
                Write-Host "💎 [$($i + 1)] $marker $($languages[$i].NativeName) ($($languages[$i].Code))$aiTag" -ForegroundColor White
            }

            Write-Host ''
            Write-Host "↩️ [0] $(Get-SourceTextLoc 'menu.back')" -ForegroundColor Gray
            Write-Host ''

            $choice = Microsoft.PowerShell.Utility\Read-Host (Get-SourceTextLoc 'menu.choice')
            if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq '0') { return }

            $parsed = 0
            if ([int]::TryParse($choice, [ref]$parsed) -and $parsed -ge 1 -and $parsed -le $languages.Count) {
                $selectedLanguage = $languages[$parsed - 1]
                Set-SourceTextLanguage -LanguageCode $selectedLanguage.Code
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'menu.languageChanged' -Args @($selectedLanguage.NativeName))
                Start-Sleep -Seconds 1
                return
            }

            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'menu.invalidSelection')
            Start-Sleep -Seconds 1
        }
    }

    :MainMenu while ($true) {
        Show-Header -SubTitle (Get-SourceTextLoc 'menu.main')

        # ── Informazioni di sistema ───────────────────────────────────────────
        $width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 }
        Write-Host ''
        Write-Host "==== 💻 $(Get-SourceTextLoc 'system.infoTitle') 💻 ====" -ForegroundColor Cyan
        Write-Host ''
        $si = Get-SystemInfo
        if ($si) {
            $editionIcon = if ($si.ProductName -match "Pro") { "🔧" } else { "💻" }
            Write-Host "💻 $(Get-SourceTextLoc 'system.edition'): $editionIcon $($si.ProductName)" -ForegroundColor White
            Write-Host "🆔 $(Get-SourceTextLoc 'system.version'): " -NoNewline -ForegroundColor White
            Write-Host (Get-SourceTextLoc 'uiText.ver0Build1' -Args @($($si.DisplayVersion), $($si.BuildNumber))) -ForegroundColor Green
            Write-Host "🔑 $(Get-SourceTextLoc 'system.architecture'): $($si.Architecture)"  -ForegroundColor White
            Write-Host "🔧 $(Get-SourceTextLoc 'system.computerName'): $($si.ComputerName)"       -ForegroundColor White
            Write-Host (Get-SourceTextLoc 'uiText.ram0Gb2' -Args @($($si.TotalRAM)))            -ForegroundColor White
            Write-Host "💾 $(Get-SourceTextLoc 'system.disk'): " -NoNewline -ForegroundColor White

            $diskFreeGB = $si.FreeDisk
            $displayString = "$($si.FreePercentage)% $(Get-SourceTextLoc 'system.free') ($($diskFreeGB) GB)"
            $diskColor = if ($diskFreeGB -lt 50) { "Red" } elseif ($diskFreeGB -le 80) { "Yellow" } else { "Green" }
            Write-Host $displayString -ForegroundColor $diskColor -NoNewline
            Write-Host ""

            $blStatusKey = Get-BitlockerStatus -Key
            $blStatus = Get-SourceTextLoc $blStatusKey
            $blColor = if ($blStatusKey -in @('bitlocker.status.off', 'bitlocker.status.notConfigured')) { 'Green' } elseif ($blStatusKey -in @('bitlocker.status.suspended', 'bitlocker.status.decrypting')) { 'Yellow' } else { 'Red' }
            Write-Host "🔒 $(Get-SourceTextLoc 'system.bitlockerStatus'): " -NoNewline -ForegroundColor White
            Write-Host "$blStatus" -ForegroundColor $blColor
        }
        Write-Host ('*' * 50) -ForegroundColor Red
        Write-Host ""

        # ── Voci di menu ─────────────────────────────────────────────────────
        $allScripts = @(); $idx = 1
        $languageMenuIndex = $null
        foreach ($cat in $menuStructure) {
            Write-Host "==== $($cat.Icon) $(Get-SourceTextMenuText $cat) $($cat.Icon) ====" -ForegroundColor Cyan
            Write-Host ""
            foreach ($s in $cat.Scripts) {
                $allScripts += $s
                Write-Host "💎 [$idx] $(Get-SourceTextMenuText $s)" -ForegroundColor White
                $idx++
            }
            if ($cat.Name -eq 'Support' -and -not $Global:GuiSessionActive) {
                $languageMenuIndex = $idx
                Write-Host "`e[1m🌐 [$idx] $(Get-SourceTextLoc 'menu.changeLanguage')`e[0m" -ForegroundColor Yellow
                $idx++
            }
            Write-Host ""
        }
        Write-Host "==== $(Get-SourceTextLoc 'menu.exitSection') ====" -ForegroundColor Red
        Write-Host ""
        Write-Host "❌ [0] $(Get-SourceTextLoc 'menu.exitToolkit')" -ForegroundColor Red
        Write-Host ""

        # ── Input utente ──────────────────────────────────────────────────────
        $rawInput = Microsoft.PowerShell.Utility\Read-Host (Get-SourceTextLoc 'menu.multiPrompt')

        # Secret check
        if ($rawInput -eq [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('V2luZG93cyDDqCB1bmEgbWVyZGE='))) {
            Start-Process ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly93d3cueW91dHViZS5jb20vd2F0Y2g/dj15QVZVT2tlNGtvYw==')))
            continue
        }

        $maxMenuOption = $allScripts.Count + $(if ($null -ne $languageMenuIndex) { 1 } else { 0 })
        $rawSelections = Read-ValidatedChoice -Prompt (Get-SourceTextLoc 'menu.multiPromptShort') -Min 0 -Max $maxMenuOption -AllowZero -RawInput $rawInput
        $c = if ($rawSelections.Count -gt 0) { $rawSelections[0] } else { '' }

        if ($c -eq 0 -or $c -eq '0') {
            Write-StyledMessage -type 'Warning' -text (Get-SourceTextLoc 'menu.support')
            Write-StyledMessage -type 'Success' -text (Get-SourceTextLoc 'menu.closing')
            Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'uiText.wintoolkitSessionTerminatedByUser')
            Start-Sleep -Seconds 3
            break
        }

        if ($null -ne $languageMenuIndex -and $rawSelections -contains $languageMenuIndex) {
            Show-LanguageMenu
            continue
        }

        $selections = @($rawSelections | Where-Object { $_ -ge 1 -and $_ -le $maxMenuOption })
        if ($selections.Count -eq 0) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'menu.invalidSelection')
            Start-Sleep -Seconds 2
            continue
        }

        # ── Esecuzione ────────────────────────────────────────────────
        $Global:ExecutionLog = @()
        $Global:NeedsFinalReboot = $false
        $isMultiScript = ($selections.Count -gt 1)

        Write-Host ''
        if ($isMultiScript) {
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'run.sequence' -Args @($selections.Count))
            Write-Host ''
        }

        foreach ($sel in $selections) {
            $scriptToRun = $allScripts[$sel - 1]
            $scriptDescription = Get-SourceTextMenuText $scriptToRun
            if ($scriptToRun.Name -eq 'WinDeleteUserProfiles' -and -not (Confirm-UserProfileDeletion)) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'run.cancelled')
                Start-Sleep -Seconds 2
                continue MainMenu
            }

            Write-StyledMessage -Type 'Progress' -Text (Get-SourceTextLoc 'run.start' -Args @($scriptDescription))
            Write-Host ''
            try {
                if ($isMultiScript) { & ([scriptblock]::Create("$($scriptToRun.Name) -SuppressIndividualReboot")) }
                else { & $ExecutionContext.InvokeCommand.GetCommand($scriptToRun.Name, 'Function') }
                $Global:ExecutionLog += @{ Name = $scriptDescription; Success = $true }
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'run.error' -Args @($scriptDescription, $_.Exception.Message))
                $Global:ExecutionLog += @{ Name = $scriptDescription; Success = $false; Error = $_.Exception.Message }
            }
            Write-Host ''
        }

        # ── Multi-script summary ────────────────────────────────────────────
        if ($isMultiScript) {
            Write-Host ''
            $tableRows = $Global:ExecutionLog | ForEach-Object {
                @{ Operation = $_.Name; Status = if ($_.Success) { "✅ $(Get-SourceTextLoc 'summary.completed')" } else { "❌ $(Get-SourceTextLoc 'summary.error')" }; Detail = if ($_.Error) { $_.Error } else { '' } }
            }
            Show-ConsoleTable -Rows $tableRows -Columns @(
                @{ Header = (Get-SourceTextLoc 'summary.operation'); Key = 'Operation' },
                @{ Header = (Get-SourceTextLoc 'summary.status'); Key = 'Status' },
                @{ Header = (Get-SourceTextLoc 'summary.detail'); Key = 'Detail' }
            ) -Title "📊 $(Get-SourceTextLoc 'summary.title')"
            Write-Host ''
        }

        # ── Final reboot ────────────────────────────────────────────────────
        if ($Global:NeedsFinalReboot) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'reboot.required')
            if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message (Get-SourceTextLoc 'reboot.countdown')) {
                Restart-Computer -Force
            }
            else {
                Write-Host ''
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'reboot.reminder')
            }
        }

        Write-Host "`n$(Get-SourceTextLoc 'menu.pressEnter')" -ForegroundColor Gray
        $null = Read-Host
    }
}
else {
    # Library/import mode — functions loaded, TUI menu suppressed
    Write-Verbose "═══════════════════════════════════════════════════════════"
    Write-Verbose ("  " + (Get-SourceTextLoc 'uiText.wintoolkitLoadedInLibraryMode'))
    Write-Verbose ("  " + (Get-SourceTextLoc 'uiText.functionsAvailableTuiMenuSuppressed'))
    Write-Verbose ("  💎 " + (Get-SourceTextLoc 'sourceText.version') + ": $ToolkitVersion")
    Write-Verbose "═══════════════════════════════════════════════════════════"
    $Global:menuStructure = $menuStructure
}



