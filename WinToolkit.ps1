param([int]$CountdownSeconds = 30, [switch]$ImportOnly, [string]$Language = 'en-US')
function Read-Host {
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
$ToolkitVersion = "2.5.5 (Build 4)"
$AppConfig = @{
    URLs            = @{
        GitHubAssetBaseUrl    = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/assets/"
        GitHubAssetDevBaseUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/assets/"
        OfficeSetup           = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/assets/Setup.exe"
        OfficeBasicConfig     = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/assets/Basic.xml"
        GetHelpInstaller      = "https://aka.ms/SaRA_EnterpriseVersionFiles"
        AMDInstaller          = "https://drivers.amd.com/drivers/installer/26.10/whql/amd-software-adrenalin-edition-26.5.2-minimalsetup-260513_web.exe"
        NVCleanstall          = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/assets/NVCleanstall_1.19.0.exe"
        DDUZip                = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/assets/DDU.zip"
        DriverOverridesJson   = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/assets/DriverOverrides.json"
        DirectXWebSetup       = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/assets/dxwebsetup.exe"
        BattleNetInstaller    = "https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"
        SevenZipOfficial      = "https://www.7-zip.org/a/7zr.exe"
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
                Code       = if ($data.ContainsKey('language.code')) { $data['language.code'] } else { $_.Name }
                Name       = if ($data.ContainsKey('language.name')) { $data['language.name'] } else { $_.Name }
                NativeName = if ($data.ContainsKey('language.nativeName')) { $data['language.nativeName'] } else { $_.Name }
                AiTranslated = if ($data.ContainsKey('language.aiTranslated')) { $data['language.aiTranslated'] } else { $false }
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
function Start-ToolkitLog {
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
    return Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '^(Public|Default|Default User|All Users)$' }
}
function Initialize-ToolkitPaths {
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
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
    $env:Path = $newPath
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
}
function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if (-not (Test-Path $Path)) { $null = New-Item -Path $Path -Force }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}
function Stop-ToolkitProcesses {
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
    param([string]$ToolName, [string]$SubTitle = $ToolName)
    Start-ToolkitLog -ToolName $ToolName
    Show-Header -SubTitle $SubTitle
    try { $Host.UI.RawUI.WindowTitle = "$SubTitle By MagnetarMan" } catch {}
}
function Invoke-ToolkitReboot {
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
            $parentDir = Split-Path -Parent $OutputPath
            if (-not (Test-Path $parentDir)) {
                New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
            }
            $handler = New-Object System.Net.Http.HttpClientHandler
            $handler.AllowAutoRedirect = $true
            $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
            $httpClient = New-Object System.Net.Http.HttpClient($handler)
            $httpClient.Timeout = [TimeSpan]::FromSeconds(300)
            $httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
            if ($Uri -match 'drivers\.amd\.com|amd-software') {
                $httpClient.DefaultRequestHeaders.Add("Referer", "https://www.amd.com")
            }
            $totalBytes = 0
            try {
                $headRequest = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Head, $Uri)
                $headResponse = $httpClient.SendAsync($headRequest).Result
                if ($headResponse.Content.Headers.ContentLength -gt 0) {
                    $totalBytes = $headResponse.Content.Headers.ContentLength
                }
                $headResponse.Dispose()
            }
            catch {}
            $getRequest = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $Uri)
            $getResponse = $httpClient.SendAsync($getRequest, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
            if (-not $getResponse.IsSuccessStatusCode) {
                throw (Get-SourceTextLoc 'uiText.httpError01' -Args @($($getResponse.StatusCode), $($getResponse.ReasonPhrase)))
            }
            if ($totalBytes -eq 0 -and $getResponse.Content.Headers.ContentLength -gt 0) {
                $totalBytes = $getResponse.Content.Headers.ContentLength
            }
            $isUnknownSize = ($totalBytes -eq 0)
            $fakeProgressStart = $null
            if ($isUnknownSize -and -not $Global:GuiSessionActive) {
                $fakeProgressStart = Get-Date
                Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.download02' -Args @($Description)) `
                    -Status (Get-SourceTextLoc 'uiText.startingDownload') `
                    -Percent 8 -Icon '📥' -Color 'Cyan'
                Start-Sleep -Milliseconds 120
            }
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
                            if ($fakeProgressStart) {
                                $elapsed = ((Get-Date) - $fakeProgressStart).TotalSeconds
                                $percent = [math]::Min(95, [math]::Floor(8 + ($elapsed * 1.52)))
                            }
                            else {
                                $percent = 50
                            }
                            $status = "$currentDisplay scaricati"
                            $icon = '📥'
                            $col = 'Cyan'
                        }
                        $now = Get-Date
                        $timeSinceLast = ($now - $lastProgressTime).TotalMilliseconds
                        $shouldUpdate = $false
                        if ($lastPercent -eq -1) {
                            $shouldUpdate = $true
                        }
                        elseif ($totalBytes -gt 0) {
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
function Get-WingetExecutable {
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
    param([switch]$Force)
    $ProgressPreference = 'SilentlyContinue'
    $OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
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
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingWingetAdvancedRepair')
    if (-not (Test-WingetCompatibility)) { return $false }
    if (-not $Force -and (Test-WingetFunctionality)) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetAlreadyOperationalNoRepairsNecessary')
        return $true
    }
    Stop-ToolkitProcesses -ProcessNames $AppConfig.WingetProcesses
    try {
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
function Get-UserConfirmation {
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
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "disconnectedstate"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "usercontentdisabled"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "downloadcontentdisabled"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"; Name = "ShownOptIn"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback"; Name = "Enabled"; Value = 0 },
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
function WinRepairToolkit {
    [CmdletBinding()]
    param(
        [int]$MaxRetryAttempts = 3,
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "WinRepairToolkit" -SubTitle (Get-SourceTextLoc 'script.WinRepairToolkit')
    $script:CurrentAttempt = 0
    $sysInfo = Get-SystemInfo
    $RepairTools = @(
        @{ Tool = 'chkdsk'; Args = @('/scan', '/perf'); Name = 'Disk check'; NameKey = 'toolText.extra.diskCheck'; Icon = '💽' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'System File Checker (1)'; NameKey = 'toolText.extra.systemFileChecker1'; Icon = '🗂️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Name = 'Windows Image Recovery'; NameKey = 'toolText.extra.windowsImageRecovery'; Icon = '🛠️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'); Name = 'Remnant Cleanup Updates'; NameKey = 'toolText.extra.remnantCleanupUpdates'; Icon = '🕸️' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'System File Checker (2)'; NameKey = 'toolText.extra.systemFileChecker2'; Icon = '🗂️' }
        @{ Tool = 'chkdsk'; Args = @('/f', '/r', '/x'); Name = 'Thorough disk check'; NameKey = 'toolText.extra.thoroughDiskCheck'; Icon = '💽'; IsCritical = $false }
    )
    function Invoke-RepairCommand {
        param([hashtable]$Config, [int]$Step, [int]$Total)
        $displayName = Get-SourceTextLoc $Config.NameKey
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.01Starting2' -Args @($Step, $Total, $displayName))
        $isChkdsk = ($Config.Tool -ieq 'chkdsk')
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()
        try {
            $processTimeoutSeconds = 600
            switch ($Config.Name) {
                'Windows Image Recovery'   { $processTimeoutSeconds = 10800 }
                'System File Checker (1)' { $processTimeoutSeconds = 3600 }
                'System File Checker (2)' { $processTimeoutSeconds = 10800 }
                'Remnant Cleanup Updates' { $processTimeoutSeconds = 3600 }
                'Disk check' { $processTimeoutSeconds = 900 }
                'Thorough disk check'  { $processTimeoutSeconds = 3600 }
            }
            $spinnerUpdateInterval = if ($Config.Name -eq 'Windows Image Recovery') { 900 } else { 600 }
            if ($Config.Tool -ieq 'DISM' -and $Config.Args -contains '/StartComponentCleanup') {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.cleaningWindowsUpdateStatusBeforeStartingCleanup')
                Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                Start-Sleep 1
                Remove-ItemSafely -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\SessionsPending' -Recurse
                Start-Sleep 1
            }
            $commandToRun = $Config.Tool
            $argsToRun = $Config.Args
            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
                $drive = $Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1
                if ($null -eq $drive) { $drive = $env:SystemDrive }
                $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }
                $commandToRun = 'cmd.exe'
                $argsToRun = @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ')")
            }
            $spinnerResult = Invoke-WithSpinner -Activity $displayName `
                -Command $commandToRun `
                -Arguments $argsToRun `
                -TimeoutSeconds $processTimeoutSeconds `
                -UpdateInterval $spinnerUpdateInterval `
                -LogContextKey "Repair-$($Config.Tool)"
            $exitCode = $spinnerResult.ExitCode
            $results = ($spinnerResult.StdOut + "`n" + $spinnerResult.StdErr) -split "`n"
            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r') -and ($results -join ' ').ToLower() -match 'schedule|next time.*restart|volume.*in use') {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0CheckScheduledAtNextReboot' -Args @($displayName))
                return @{ Success = $true; ErrorCount = 0 }
            }
            $isTimeout = ($spinnerResult.TimedOut -eq $true) -or ($null -eq $exitCode) -or ($exitCode -eq -1)
            if ($isChkdsk -and $exitCode -eq 3) {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0CheckScheduledAtNextReboot' -Args @($displayName))
                return @{ Success = $true; ErrorCount = 0 }
            }
            if (($Config.Tool -ieq 'DISM') -and ($results -match '0x800f0806')) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Error0x800f0806PendingOperationsThisIsNotACriticalError' -Args @($displayName))
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.rebootTheSystemToCompletePendingOperations')
                return @{ Success = $true; ErrorCount = 0 }
            }
            $hasDismSuccess = (-not $isTimeout) -and ($Config.Tool -ieq 'DISM') -and ($results -match '(?i)completed successfully')
            if (($Config.Tool -ieq 'DISM') -and ($Config.Args -contains '/ResetBase') -and $exitCode -eq 3010) {
                $hasDismSuccess = $true
            }
            $isChkdskScan = $isChkdsk -and ($Config.Args -contains '/scan')
            $chkdskCompleted = (-not $isTimeout) -and $isChkdskScan -and (($results -join ' ') -match '(?i)(scansione.*completata|scan.*completed|successfully scanned)')
            $isSuccess = (-not $isTimeout) -and (($exitCode -eq 0) -or $exitCode -eq 3010 -or $hasDismSuccess -or $chkdskCompleted)
            $errors = $warnings = @()
            if (-not $isSuccess) {
                if ($isTimeout) {
                    $errors += Get-SourceTextLoc 'uiText.repairOperationTimedOut'
                }
                foreach ($line in ($results | Where-Object { $_ -and ![string]::IsNullOrWhiteSpace($_.Trim()) })) {
                    $trim = $line.Trim()
                    if ($trim -match '^\[=+\s*\d+' -or $trim -match '(?i)version:|deployment image') { continue }
                    if ($isChkdsk) {
                        if ($trim -match '(?i)(stage|fase|percent complete|verificat|scanned|scanning|errors found.*corrected|volume label)') { continue }
                        if ($trim -match '(?i)(cannot|unable to|access denied|critical|fatal|corrupt file system|bad sectors)') {
                            $errors += $trim
                        }
                    }
                    else {
                        if ($trim -match '0x800f0806') {
                        }
                        elseif ($trim -match '(?i)(errore|error|failed|impossibile|corrotto|corruption)') { $errors += $trim }
                        elseif ($trim -match '(?i)(warning|avviso|attenzione)') { $warnings += $trim }
                    }
                }
                if ($errors.Count -eq 0 -and -not $isTimeout) {
                    $errors += "Generic error or abend (ExitCode: $exitCode)."
                }
            }
            $success = $isSuccess -and ($errors.Count -eq 0)
            if ($isTimeout) {
                $message = Get-SourceTextLoc 'toolText.extra.0NotCompletedAbortedDueToTimeout' -Args @($displayName)
            }
            else {
                $message = if ($success) {
                    Get-SourceTextLoc 'toolText.extra3.0CompletedSuccessfully' -Args @($displayName)
                }
                else {
                    Get-SourceTextLoc 'toolText.extra3.0CompletedWith1Errors' -Args @($displayName, $errors.Count)
                }
            }
            Write-StyledMessage -Type 'Success' -Text $message
            if ($Config.Tool -ieq 'sfc') {
                $cbsLogPath = "C:\Windows\Logs\CBS\CBS.log"
                if (Test-Path $cbsLogPath) {
                    try {
                        $safeStepName = $Config.Name -replace '[^a-zA-Z0-9]', '_'
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                        $destLogName = "SFC_CBS_${safeStepName}_${timestamp}.log"
                        $destLogPath = Join-Path $AppConfig.Paths.Logs $destLogName
                        Copy-Item -Path $cbsLogPath -Destination $destLogPath -Force -ErrorAction SilentlyContinue
                        if (Test-Path $destLogPath) {
                            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.sfcLogSavedIn0' -Args @($destLogName))
                        }
                    }
                    catch {
                        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.failedToExportSfcCbsLogFileInUse')
                    }
                }
            }
            return @{ Success = $success; ErrorCount = $errors.Count }
        }
        catch {
            Write-ToolkitError -Record $_ -ToolName "WinRepairToolkit" -Message (Get-SourceTextLoc 'toolText.extra.errorInInvokeRepaircommand0' -Args @($($Config.Tool)))
            return @{ Success = $false; ErrorCount = 1 }
        }
    }
    function Start-RepairCycle {
        param([int]$Attempt = 1)
        $script:CurrentAttempt = $Attempt
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.attempting01SystemRepair' -Args @($Attempt, $MaxRetryAttempts))
        $totalErrors = $successCount = 0
        for ($toolIndex = 0; $toolIndex -lt $RepairTools.Count; $toolIndex++) {
            $result = Invoke-RepairCommand -Config $RepairTools[$toolIndex] -Step ($toolIndex + 1) -Total $RepairTools.Count
            if ($result.Success) { $successCount++ }
            if (!$result.Success -and !($RepairTools[$toolIndex].ContainsKey('IsCritical') -and !$RepairTools[$toolIndex].IsCritical)) {
                $totalErrors += $result.ErrorCount
            }
            Start-Sleep 1
        }
        if ($totalErrors -gt 0 -and $Attempt -lt $MaxRetryAttempts) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0ErrorsDetectedNewAttempt' -Args @($totalErrors))
            Start-Sleep 3
            return Start-RepairCycle -Attempt ($Attempt + 1)
        }
        return @{ Success = ($totalErrors -eq 0); TotalErrors = $totalErrors; AttemptsUsed = $Attempt }
    }
    function Start-DeepDiskRepair {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startDeepRepairOfDiskCOnNextReboot')
        try {
            $fsutilResult = Invoke-ExternalCommandWithLog -Command 'fsutil.exe' -Arguments @('dirty', 'set', 'C:') -TimeoutSeconds 300 -LogContextKey 'DeepDiskRepair-Fsutil'
            if (-not $fsutilResult.Success) {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToMarkDiskDirtyFsutil')
                return $false
            }
            $chkdskResult = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'echo Y | chkdsk C: /f /r /v /x /b') -TimeoutSeconds 7200 -LogContextKey 'DeepDiskRepair-Chkdsk'
            if (-not $chkdskResult.Success) {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorSchedulingChkdskForDeepRepair')
                return $false
            }
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.chkdskCommandSentRebootToPerformDeepDiskRepair')
            return $true
        }
        catch {
            Write-ToolkitError -Record $_ -ToolName "WinRepairToolkit" -Message (Get-SourceTextLoc 'uiText.exceptionInStartDeepdiskrepair')
            return $false
        }
    }
    function Test-PendingOperations {
        $pendingRebootKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
            'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
        )
        foreach ($key in $pendingRebootKeys) {
            if (Test-Path $key) {
                $values = Get-ItemProperty $key -ErrorAction SilentlyContinue
                if ($values -and $values.PSObject.Properties.Count -gt 1) {
                    return $true
                }
            }
        }
        return $false
    }
    if (Test-PendingOperations) {
        Write-ToolkitLog -Level WARNING -Message (Get-SourceTextLoc 'toolText.pendingOperationsRequiringRebootDetectedDismCouldFail') -Context @{
            Tool = 'WinRepairToolkit'
            Step = 'PreExecutionCheck'
        }
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.pendingOperationsRequiringRebootDetectedDismCouldFail2')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.restartRecommendedBeforePerformingRepairs')
    }
    try {
        $repairResult = Start-RepairCycle
        $deepRepairScheduled = $false
        if ($repairResult.TotalErrors -gt 0) {
            Write-ToolkitLog -Level WARNING -Message (Get-SourceTextLoc 'toolText.persistentErrorsDetectedStartDeepRepair') -Context @{
                Tool = 'WinRepairToolkit'
                Step = 'RepairCycle'
                TotalErrors = $repairResult.TotalErrors
            }
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.persistentErrorsDetectedStartDeepRepair')
            $deepRepairScheduled = Start-DeepDiskRepair
        }
        else {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.systemHealthyDeepRepairNotNecessary')
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.unlimitedPasswordExpirationSetting')
        $null = Invoke-ExternalCommandWithLog -Command 'net' -Arguments @('accounts', '/maxpwage:unlimited') -TimeoutSeconds 30 -LogContextKey 'Repair-NetAccounts'
        if ($deepRepairScheduled) { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.rebootRequiredForDeepRepair') }
        if ($SuppressIndividualReboot) {
            if ($deepRepairScheduled) {
                $Global:NeedsFinalReboot = $true
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.individualRestartSuppressedAFinalRebootWillBeHandled')
            }
        }
        else {
            if (Start-InterruptibleCountdown $CountdownSeconds 'Automatic restart') {
                Restart-Computer -Force
            }
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinRepairToolkit"
    }
    finally {
    }
}
function WinUpdateReset {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "WinUpdateReset" -SubTitle (Get-SourceTextLoc 'script.WinUpdateReset')
    function Set-ServiceStatus {
        param (
            [Parameter(Mandatory = $true)][string]$Name,
            [Parameter(Mandatory = $true)][ValidateSet('Running', 'Stopped')][string]$Status,
            [switch]$Wait,
            [int]$TimeoutSeconds = 10
        )
        $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if (-not $service) { return $false }
        if ($service.Status -eq $Status) { return $true }
        try {
            if ($Status -eq 'Running') { Start-Service -Name $Name -ErrorAction Stop }
            else { Stop-Service -Name $Name -Force -ErrorAction Stop }
        }
        catch { return $false }
        if ($Wait) {
            $timeout = $TimeoutSeconds
            while ((Get-Service -Name $Name -ErrorAction SilentlyContinue).Status -ne $Status -and $timeout -gt 0) {
                Start-Sleep -Seconds 1
                $timeout--
            }
            return ((Get-Service -Name $Name -ErrorAction SilentlyContinue).Status -eq $Status)
        }
        return $true
    }
    function Show-ServiceProgress([string]$Activity, [int]$Current, [int]$Total) {
        Invoke-WithSpinner -Activity $Activity -Timer -Action { Start-Sleep -Milliseconds 200 } -TimeoutSeconds 1 *>$null
    }
    function Manage-Service($serviceName, $action, $config, $currentStep, $totalSteps) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            if (-not $service) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Service1NotFoundOnTheSystem' -Args @($serviceIcon, $serviceName))
                return
            }
            switch ($action) {
                'Stop' {
                    Show-ServiceProgress (Get-SourceTextLoc 'toolText.extra3.stopping0' -Args @($serviceName)) $currentStep $totalSteps
                    $success = Set-ServiceStatus -Name $serviceName -Status 'Stopped' -Wait -TimeoutSeconds 10
                    if ($success) {
                        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0Service1Stopped' -Args @($serviceIcon, $serviceName))
                    }
                    else {
                        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0ShuttingDown1TookTooLongOrFailed' -Args @($serviceIcon, $serviceName))
                    }
                }
                'Configure' {
                    Show-ServiceProgress (Get-SourceTextLoc 'toolText.extra3.configuring0' -Args @($serviceName)) $currentStep $totalSteps
                    Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop *>$null
                    $startupTypeText = if ($config.Type -eq 'Automatic') { Get-SourceTextLoc 'sourceText.automatic' } else { Get-SourceTextLoc 'sourceText.manual' }
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0Service1ConfiguredAs2' -Args @($serviceIcon, $serviceName, $startupTypeText))
                }
                'Start' {
                    Show-ServiceProgress (Get-SourceTextLoc 'toolText.extra3.starting0' -Args @($serviceName)) $currentStep $totalSteps
                    Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.waitingForStart0' -Args @($serviceName)) -Timer -Action { Start-Sleep -Milliseconds 200 } -TimeoutSeconds 1 *>$null
                    $success = Set-ServiceStatus -Name $serviceName -Status 'Running' -Wait -TimeoutSeconds 10
                    Clear-ProgressLine
                    if ($success) {
                        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0Service1StartedSuccessfully' -Args @($serviceIcon, ${serviceName}))
                    }
                    else {
                        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Service1StartingOrDelayed' -Args @($serviceIcon, ${serviceName}))
                    }
                }
                'Check' {
                    $status = if ($service.Status -eq 'Running') { '🟢 ' + (Get-SourceTextLoc 'sourceText.active') } else { '🔴 ' + (Get-SourceTextLoc 'sourceText.inactive') }
                    $serviceIcon = if ($null -ne $config.Icon) { $config.Icon } else { '⚙️' }
                    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.01Status2' -Args @($serviceIcon, $serviceName, $status))
                }
            }
        }
        catch {
            $actionText = switch ($action) {
                'Configure' { Get-SourceTextLoc 'sourceText.configure' }
                'Start' { Get-SourceTextLoc 'sourceText.start' }
                'Check' { Get-SourceTextLoc 'sourceText.check' }
                default { $action.ToLower() }
            }
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Unable123' -Args @($serviceIcon, $actionText, $serviceName, $($_.Exception.Message)))
        }
    }
    function Remove-DirectorySafely([string]$path, [string]$displayName) {
        if (-not (Test-Path $path)) {
            Clear-ProgressLine
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.directory0NotPresent' -Args @($displayName))
            return $true
        }
        try {
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Clear-ProgressLine
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.directory0Deleted' -Args @($displayName))
            return $true
        }
        catch {
            Clear-ProgressLine
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.attemptFailedILlTryForceDeletion')
            try {
                $tempDir = [System.IO.Path]::GetTempPath() + "empty_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                $null = New-Item -ItemType Directory -Path $tempDir -Force
                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.cleaning0' -Args @($displayName)) -Command 'robocopy.exe' -Arguments @("`"$tempDir`"", "`"$path`"", '/MIR', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/NC') -TimeoutSeconds 300 -LogContextKey 'RemoveDirectorySafely-Robocopy'
                Remove-Item $tempDir -Force -ErrorAction SilentlyContinue *>$null
                Remove-Item $path -Force -ErrorAction SilentlyContinue *>$null
                Clear-ProgressLine
                [Console]::Out.Flush()
                if (-not (Test-Path $path)) {
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.directory0DeletedForcedMethod' -Args @($displayName))
                    return $true
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.directory0PartiallyDeleted' -Args @($displayName))
                    return $false
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.unableToCompletelyDelete0FileInUse' -Args @($displayName))
                return $false
            }
        }
    }
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.initializingTheWindowsUpdateResetScript')
    Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.loadingForms') -Timer -Action { Start-Sleep 2 } -TimeoutSeconds 2 *>$null
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startingWindowsUpdateServicesRepair')
    $serviceConfig = @{
        'wuauserv'         = @{ Type = 'Automatic'; Critical = $true; Icon = '🔄'; DisplayName = 'Windows Update' }
        'bits'             = @{ Type = 'Automatic'; Critical = $true; Icon = '📡'; DisplayName = 'Background Intelligent Transfer' }
        'cryptsvc'         = @{ Type = 'Automatic'; Critical = $true; Icon = '🔐'; DisplayName = 'Cryptographic Services' }
        'trustedinstaller' = @{ Type = 'Manual'; Critical = $true; Icon = '🛡️'; DisplayName = 'Windows Modules Installer' }
        'msiserver'        = @{ Type = 'Manual'; Critical = $false; Icon = '📦'; DisplayName = 'Windows Installer' }
    }
    $systemServices = @(
        @{ Name = 'appidsvc'; Icon = '🆔'; Display = 'Application Identity' },
        @{ Name = 'gpsvc'; Icon = '📋'; Display = 'Group Policy Client' },
        @{ Name = 'DcomLaunch'; Icon = '🚀'; Display = 'DCOM Server Process Launcher' },
        @{ Name = 'RpcSs'; Icon = '📞'; Display = 'Remote Procedure Call' },
        @{ Name = 'LanmanServer'; Icon = '🖥️'; Display = 'Server' },
        @{ Name = 'LanmanWorkstation'; Icon = '💻'; Display = 'Workstation' },
        @{ Name = 'EventLog'; Icon = '📄'; Display = 'Windows Event Log' },
        @{ Name = 'mpssvc'; Icon = '🛡️'; Display = 'Windows Defender Firewall' },
        @{ Name = 'WinDefend'; Icon = '🔒'; Display = 'Windows Defender Service' }
    )
    try {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.windowsUpdateServicesStopping')
        $stopServices = @('wuauserv', 'cryptsvc', 'bits', 'msiserver')
        for ($serviceIndex = 0; $serviceIndex -lt $stopServices.Count; $serviceIndex++) {
            Manage-Service $stopServices[$serviceIndex] 'Stop' $serviceConfig[$stopServices[$serviceIndex]] ($serviceIndex + 1) $stopServices.Count
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.cleanupGpcacheCacheAndWsusSettings')
        try {
            if (Test-Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache") {
                Remove-Item "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache" -Recurse -Force -ErrorAction Stop
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.gpcacheCacheDeleted')
            } else {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.gpcacheCacheNotPresent')
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningFailedToDeleteGpcacheCache0' -Args @($($_.Exception.Message)))
        }
        try {
            if (Test-Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate") {
                Remove-Item "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate" -Recurse -Force -ErrorAction Stop
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.wsusSettingsRemoved')
            } else {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.wsusSettingsNotPresent')
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningFailedToRemoveWsusSettings0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.waitingForResourcesToBeReleased')
        Start-Sleep -Seconds 3
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.windowsUpdateServicesReset')
        $criticalServices = $serviceConfig.Keys | Where-Object { $serviceConfig[$_].Critical }
        for ($criticalIndex = 0; $criticalIndex -lt $criticalServices.Count; $criticalIndex++) {
            $serviceName = $criticalServices[$criticalIndex]
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0ServiceProcessing1' -Args @($($serviceConfig[$serviceName].Icon), $serviceName))
            Manage-Service $serviceName 'Configure' $serviceConfig[$serviceName] ($criticalIndex + 1) $criticalServices.Count
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.checkCriticalSystemServices')
        for ($systemIndex = 0; $systemIndex -lt $systemServices.Count; $systemIndex++) {
            $sysService = $systemServices[$systemIndex]
            Manage-Service $sysService.Name 'Check' @{ Icon = $sysService.Icon } ($systemIndex + 1) $systemServices.Count
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.restoringWindowsUpdateRegistryKeys')
        Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.logProcessing') -Timer -Action { Start-Sleep 1 } -TimeoutSeconds 1 *>$null
        try {
            @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update",
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            ) | Where-Object { Test-Path $_ } | ForEach-Object {
                Remove-Item $_ -Recurse -Force -ErrorAction Stop *>$null
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.completed2')
            }
            if (-not @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update", "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate") | Where-Object { Test-Path $_ }) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.completed2')
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.noRegistryKeysToRemove')
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.error')
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorEditingRegistry0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.deletionOfWindowsUpdateComponents')
        $directories = @(
            @{ Path = $AppConfig.Paths.SoftwareDistribution; Name = "SoftwareDistribution" },
            @{ Path = $AppConfig.Paths.Catroot2; Name = "catroot2" },
            @{ Path = Join-Path $AppConfig.Paths.System32 "WaaSMedicSvc.dll"; Name = "WaaSMedicSvc.dll" },
            @{ Path = Join-Path $AppConfig.Paths.System32 "wuaueng.dll"; Name = "wuaueng.dll" },
            @{ Path = Join-Path $AppConfig.Paths.System32 "WaaSMedicSvc_BAK.dll"; Name = "WaaSMedicSvc_BAK.dll" },
            @{ Path = Join-Path $AppConfig.Paths.System32 "wuaueng_BAK.dll"; Name = "wuaueng_BAK.dll" },
            @{ Path = Join-Path $AppConfig.Paths.SoftwareDistribution "Download"; Name = "Download" },
            @{ Path = Join-Path $AppConfig.Paths.SoftwareDistribution "DataStore"; Name = "DataStore" },
            @{ Path = Join-Path $AppConfig.Paths.SoftwareDistribution "Backup"; Name = "Backup" }
        )
        for ($dirIndex = 0; $dirIndex -lt $directories.Count; $dirIndex++) {
            $dir = $directories[$dirIndex]
            $percent = [math]::Round((($dirIndex + 1) / $directories.Count) * 100)
            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.directories01' -Args @($($dirIndex + 1), $($directories.Count))) -Status (Get-SourceTextLoc 'toolText.elimination0' -Args @($($dir.Name))) -Percent $percent -Icon '🗑️' -Color 'Yellow'
            Start-Sleep -Milliseconds 300
            $success = Remove-DirectorySafely -path $dir.Path -displayName $dir.Name
            if (-not $success) {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.tipSomeFilesMayBeRecreatedAfterReboot')
            }
            Clear-ProgressLine
            [Console]::Out.Flush()
            Start-Sleep -Milliseconds 500
        }
        [Console]::Out.Flush()
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startOfEssentialServices')
        $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
        for ($essentialIndex = 0; $essentialIndex -lt $essentialServices.Count; $essentialIndex++) {
            Manage-Service $essentialServices[$essentialIndex] 'Start' $serviceConfig[$essentialServices[$essentialIndex]] ($essentialIndex + 1) $essentialServices.Count
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.performingAWindowsUpdateClientReset')
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.resetClientUpdate') -Command 'cmd.exe' -Arguments @('/c', 'wuauclt', '/resetauthorization', '/detectnow') -TimeoutSeconds 60 -LogContextKey 'UpdateReset-Wuauclt'
        if ($result.Success) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.windowsUpdateClientResetSuccessfully')
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.windowsUpdateClientResetNotCompletedPossibleTimeout')
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.enablingWindowsUpdateAndRelatedServices')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.resetWindowsUpdateRegistrySettings')
        try {
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 0
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 3
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 1
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.windowsUpdateRegistrySettingsReset')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToRestoreSomeRegistryKeys0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.resetWaasmedicsvcSettings')
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Type DWord -Value 3 -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "FailureActions" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.waasmedicsvcSettingsReset')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningFailedToRestoreWaasmedicsvc0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.restorationOfUpdateServices')
        $services = @(
            @{Name = "BITS"; StartupType = "Manual"; Icon = "📡" },
            @{Name = "wuauserv"; StartupType = "Manual"; Icon = "🔄" },
            @{Name = "UsoSvc"; StartupType = "Automatic"; Icon = "🚀" },
            @{Name = "uhssvc"; StartupType = "Disabled"; Icon = "⭕" },
            @{Name = "WaaSMedicSvc"; StartupType = "Manual"; Icon = "🛡️" }
        )
        foreach ($service in $services) {
            try {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0Reverting1To2' -Args @($($service.Icon), $($service.Name), $($service.StartupType)))
                $serviceObj = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
                if ($serviceObj) {
                    Set-Service -Name $service.Name -StartupType $service.StartupType -ErrorAction SilentlyContinue *>$null
                    $null = Invoke-ExternalCommandWithLog -Command 'sc.exe' -Arguments @('failure', "$($service.Name)", 'reset= 86400', 'actions= restart/60000/restart/60000/restart/60000') -TimeoutSeconds 30 -LogContextKey "ServiceFailureReset-$($service.Name)"
                    if ($service.StartupType -eq "Automatic") {
                        Set-ServiceStatus -Name $service.Name -Status "Running" -Wait -TimeoutSeconds 5 *>$null
                    }
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0Service1Restored' -Args @($($service.Icon), $($service.Name)))
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToRestoreService01' -Args @($($service.Name), $($_.Exception.Message)))
            }
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.restoringRenamedDlls')
        $dlls = @("WaaSMedicSvc", "wuaueng")
        foreach ($dll in $dlls) {
            $dllPath = Join-Path $AppConfig.Paths.System32 "$dll.dll"
            $backupPath = Join-Path $AppConfig.Paths.System32 "${dll}_BAK.dll"
            if ((Test-Path $backupPath) -and !(Test-Path $dllPath)) {
                try {
                    $null = Invoke-ExternalCommandWithLog -Command 'takeown.exe' -Arguments @('/f', "`"$backupPath`"") -TimeoutSeconds 30 -LogContextKey "DLLRestore-Takeown-$dll"
                    $null = Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$backupPath`"", '/grant', '*S-1-1-0:F') -TimeoutSeconds 30 -LogContextKey "DLLRestore-IcaclsGrant-$dll"
                    Rename-Item -Path $backupPath -NewName "$dll.dll" -ErrorAction SilentlyContinue *>$null
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.reverted0BakDllTo1Dll' -Args @(${dll}, $dll))
                    $null = Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$dllPath`"", '/setowner', '"NT SERVICE\TrustedInstaller"') -TimeoutSeconds 30 -LogContextKey "DLLRestore-IcaclsOwner-$dll"
                    $null = Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$dllPath`"", '/remove', '*S-1-1-0') -TimeoutSeconds 30 -LogContextKey "DLLRestore-IcaclsRemove-$dll"
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningFailedToRepair0Dll1' -Args @($dll, $($_.Exception.Message)))
                }
            }
            elseif (Test-Path $dllPath) {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0DllAlreadyPresentInTheOriginalLocation' -Args @($dll))
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0DllNotFoundAndNoBackupAvailable' -Args @($dll))
            }
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.rehabilitationOfScheduledTasks')
        $taskPaths = @(
            '\Microsoft\Windows\InstallService\*'
            '\Microsoft\Windows\UpdateOrchestrator\*'
            '\Microsoft\Windows\UpdateAssistant\*'
            '\Microsoft\Windows\WaaSMedic\*'
            '\Microsoft\Windows\WindowsUpdate\*'
            '\Microsoft\WindowsUpdate\*'
        )
        foreach ($taskPath in $taskPaths) {
            try {
                $tasks = Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue
                foreach ($task in $tasks) {
                    Enable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue *>$null
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.taskEnabled0' -Args @($($task.TaskName)))
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToEnableTaskIn01' -Args @($taskPath, $($_.Exception.Message)))
            }
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.enablingDriversViaWindowsUpdate')
        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontPromptForWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontSearchWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DriverUpdateWizardWuSearchEnabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.driversViaWindowsUpdateEnabled')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToEnableDriver0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.enableWindowsUpdateAutomaticRestart')
        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.windowsUpdateAutomaticRestartEnabled')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToEnableAutomaticRestart0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.resetWindowsUpdateSettings')
        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "BranchReadinessLevel" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferQualityUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.windowsUpdateSettingsReset')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToResetSomeSettings0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.resetWindowsLocalPolicies')
        try {
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.deletingLocalPolicies')
            $null = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'RD', '/S', '/Q', "`"$(Join-Path $AppConfig.Paths.System32 "GroupPolicy")`"") -TimeoutSeconds 30 -LogContextKey 'GPReset-RD'
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.criteriaRemoved')
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.policyUpdate')
            $gpResult = Invoke-ExternalCommandWithLog -Command 'gpupdate.exe' -Arguments @('/force') -TimeoutSeconds 60 -LogContextKey 'GPReset-GPUpdate'
            if (-not $gpResult.Success) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.gpupdateTerminatedWithErrorsOrTimedOut')
            }
            else {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.updatedCriteria')
            }
            Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKCU:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKCU:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.windowsLocalPoliciesRestored')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToResetSomePolicies0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.windowsUpdateHasBeenRestoredToDefaultValues')
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.servicesRegistryAndPoliciesHaveBeenConfiguredSuccessfully')
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.noteARebootIsRequiredToFullyApplyAllChanges')
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.finalCheckOfTheStatusOfTheServices')
        $verificationServices = @('wuauserv', 'BITS', 'UsoSvc', 'WaaSMedicSvc')
        foreach ($service in $verificationServices) {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc) {
                $status = if ($svc.Status -eq 'Running') { '🟢 ' + (Get-SourceTextLoc 'sourceText.active').ToUpperInvariant() } else { '🔴 ' + (Get-SourceTextLoc 'sourceText.inactive').ToUpperInvariant() }
                $startup = if ($svc.StartType -eq 'Automatic') { Get-SourceTextLoc 'sourceText.automatic' } elseif ($svc.StartType -eq 'Manual') { Get-SourceTextLoc 'sourceText.manual' } else { [string]$svc.StartType }
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0Status1Starting2' -Args @($service, $status, $startup))
            }
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.windowsUpdateShouldNowWorkNormally')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.checkByOpeningSettingsUpdateSecurity')
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.repairCompletedSuccessfully')
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.theSystemRequiresARebootToApplyAllChanges')
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningTheSystemWillRestartAutomatically')
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.preparingToRestartTheSystem') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text '═════════════════════════════════════════════════════════════════'
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.criticalError0SeeTheLogInLocalappdataWintoolkitLogsOrIn1' -Args @($($_.Exception.Message), $Global:CurrentLogFile))
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.pressAnyKeyToExit')
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-ToolkitError -Record $_ -ToolName "WinUpdateReset"
    }
    finally {
    }
}
function WinReinstallStore {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "WinReinstallStore" -SubTitle (Get-SourceTextLoc 'script.WinReinstallStore')
    $savedProgressPref = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    function Install-MicrosoftStore {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.reinstallingMicrosoftStore')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.restartMicrosoftStoreServices')
        @('AppXSvc', 'ClipSVC', 'WSService') | ForEach-Object {
            try { Restart-Service $_ -Force -ErrorAction SilentlyContinue *>$null } catch { }
        }
        @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
            (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\INetCache")
        ) | ForEach-Object { Remove-ItemSafely -Path $_ -Recurse }
        $wingetExe = Get-WingetExecutable
        $installMethods = @(
            @{
                Name   = 'Winget Install'
                Action = {
                    if (-not (Test-Path $wingetExe -ErrorAction SilentlyContinue)) { return @{ ExitCode = -1 } }
                    $processResult = Invoke-WithConsoleRedirection -Action {
                        Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.storeInstallationViaWinget') -Command $wingetExe -Arguments @('install', '9WZDNCRFJBMP', '--accept-source-agreements', '--accept-package-agreements', '--silent', '--disable-interactivity') -TimeoutSeconds 300 -LogContextKey "Store-Winget-Install"
                    }
                    return @{ ExitCode = $processResult.ExitCode }
                }
            },
            @{
                Name   = 'AppX Manifest'
                Action = {
                    $store = Get-AppxPackage -AllUsers *WindowsStore* -ErrorAction SilentlyContinue | Select-Object -First 1
                    $manifest = if ($store) { Join-Path $store.InstallLocation 'AppxManifest.xml' } else { $null }
                    if (-not $manifest -or -not (Test-Path $manifest)) { return @{ ExitCode = -1 } }
                    $procResult = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.appxManifestStoreRegistration') -Process -Action {
                        Start-AppxSilentProcess -AppxPath $manifest -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown'
                    } -TimeoutSeconds 120
                    return @{ ExitCode = $procResult.ExitCode }
                }
            },
            @{
                Name   = 'DISM Capability'
                Action = {
                    $result = Invoke-WithConsoleRedirection -Action {
                        Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.addingStoreViaDism') -Command 'DISM' -Arguments @('/Online', '/Add-Capability', '/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0') -TimeoutSeconds 300 -LogContextKey "Store-DISM-Add"
                    }
                    return @{ ExitCode = $result.ExitCode }
                }
            }
        )
        $success = $false
        foreach ($method in $installMethods) {
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.attemptedVia0' -Args @($($method.Name)))
            try {
                $result = $method.Action.Invoke()
                Clear-ProgressLine
                [Console]::Out.Flush()
                $isSuccess = $result -and ($result.ExitCode -in @(0, 3010, 1638, -1978335189))
                if ($isSuccess) {
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.microsoftStoreReinstalledVia0' -Args @($($method.Name)))
                    $success = $true
                    break
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.method0FailedExitcode1' -Args @($($method.Name), $(if ($result.ExitCode) { $result.ExitCode } else { 'N/A' })))
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.method0Failed1' -Args @($($method.Name), $($_.Exception.Message)))
            }
        }
        if ($success) {
            $null = Invoke-WithConsoleRedirection -Action {
                Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.resetCacheMicrosoftStoreWsreset') -Command 'wsreset.exe' -TimeoutSeconds 120 -LogContextKey "Store-WSReset"
            }
            Clear-ProgressLine
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.storeCacheReset')
        }
        else {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToReinstallMicrosoftStoreViaAutomaticMethods')
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.emergencyAttemptViaAppxmanifest')
            try {
                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.disasterRecoveryStore') -Process -Action {
                    $ProgressPreference = 'SilentlyContinue'
                    Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object {
                        Start-AppxSilentProcess -AppxPath "$($_.InstallLocation)\AppXManifest.xml" -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown'
                    }
                } -TimeoutSeconds 300
                Clear-ProgressLine
                [Console]::Out.Flush()
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.microsoftStoreRestoredViaEmergencyMethod')
                $success = $true
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.disasterRecoveryFailed0' -Args @($($_.Exception.Message)))
            }
        }
        return $success
    }
    function Install-UniGetUI {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.unigetUiInstallation')
        $wingetExe = Get-WingetExecutable
        if (-not (Test-Path $wingetExe -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.wingetNotAvailableUnigetUiRequiresWinget')
            return $false
        }
        try {
            foreach ($oldId in @('MartiCliment.UniGetUI', 'Devolutions.UniGetUI')) {
                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.uninstallation0' -Args @($oldId)) -Command $wingetExe -Arguments @('uninstall', '--exact', '--id', $oldId, '--silent', '--disable-interactivity') -TimeoutSeconds 120 -LogContextKey "Store-UniGet-Uninstall"
                Clear-ProgressLine
                [Console]::Out.Flush()
            }
            $processResult = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.unigetUiInstallation') -Command $wingetExe -Arguments @('install', '--exact', '--id', 'Devolutions.UniGetUI', '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements', '--silent', '--disable-interactivity', '--force') -TimeoutSeconds 600 -LogContextKey "Store-UniGet-Install"
            Clear-ProgressLine
            [Console]::Out.Flush()
            $isSuccess = $processResult.ExitCode -in @(0, 3010, 1638, -1978335189)
            if ($isSuccess) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.unigetUiInstalledSuccessfully')
                try {
                    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
                    foreach ($runName in @('WingetUI', 'UniGetUI', 'UniGet UI')) {
                        if (Get-ItemProperty -Path $regPath -Name $runName -ErrorAction SilentlyContinue) {
                            Remove-ItemProperty -Path $regPath -Name $runName -ErrorAction SilentlyContinue *>$null
                            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.autostart0RemovedFromRegistry' -Args @($runName))
                        }
                    }
                    $startupFolder = [Environment]::GetFolderPath('Startup')
                    foreach ($lnkName in @('UniGetUI.lnk', 'WingetUI.lnk', 'UniGet UI.lnk')) {
                        $lnkPath = Join-Path $startupFolder $lnkName
                        if (Test-Path $lnkPath) {
                            Remove-Item $lnkPath -Force -ErrorAction SilentlyContinue *>$null
                            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.autostartLink0Removed' -Args @($lnkName))
                        }
                    }
                }
                catch { }
                return $true
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.unigetUiInstallationFinishedWithCode0' -Args @($($processResult.ExitCode)))
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorInstallingUnigetUi0' -Args @($($_.Exception.Message)))
            return $false
        }
    }
    function Invoke-WithConsoleRedirection {
        param([scriptblock]$Action)
        if (-not ('WinReinstallStore.NativeConsole' -as [type])) {
            Add-Type -Namespace 'WinReinstallStore' -Name 'NativeConsole' -MemberDefinition @'
                [DllImport("kernel32.dll")] public static extern bool SetStdHandle(int nStdHandle, IntPtr hHandle);
                [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
                [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
                public static extern IntPtr CreateFileW(
                    string lpFileName, uint dwDesiredAccess, uint dwShareMode,
                    IntPtr lpSecurityAttributes, uint dwCreationDisposition,
                    uint dwFlagsAndAttributes, IntPtr hTemplateFile);
                [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr hObject);
'@
        }
        $STD_OUTPUT = -11
        $STD_ERROR = -12
        $STD_INPUT = -10
        $INVALID_HANDLE_VALUE = [IntPtr]::new(-1)
        $hOrigOut = $null
        $hOrigErr = $null
        $hOrigIn = $null
        $hNullOut = $null
        $hNullIn = $null
        try {
            $hOrigOut = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_OUTPUT)
            $hOrigErr = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_ERROR)
            $hOrigIn = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_INPUT)
        }
        catch {
            return & $Action
        }
        if ($hOrigOut -eq $INVALID_HANDLE_VALUE -or $hOrigOut -eq [IntPtr]::Zero -or
            $hOrigErr -eq $INVALID_HANDLE_VALUE -or $hOrigErr -eq [IntPtr]::Zero) {
            return & $Action
        }
        try {
            $hNullOut = [WinReinstallStore.NativeConsole]::CreateFileW(
                'NUL', 0x40000000, 3, [IntPtr]::Zero, 3, 0x80, [IntPtr]::Zero)
            $hNullIn = [WinReinstallStore.NativeConsole]::CreateFileW(
                'NUL', 0x80000000, 3, [IntPtr]::Zero, 3, 0x80, [IntPtr]::Zero)
        }
        catch {
            return & $Action
        }
        $canRedirect = (
            $hNullOut -ne $INVALID_HANDLE_VALUE -and $hNullOut -ne [IntPtr]::Zero -and
            $hOrigOut -ne $INVALID_HANDLE_VALUE -and $hOrigOut -ne [IntPtr]::Zero -and
            $hOrigErr -ne $INVALID_HANDLE_VALUE -and $hOrigErr -ne [IntPtr]::Zero
        )
        if (-not $canRedirect) {
            return & $Action
        }
        $handlesRedirected = $false
        try {
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_OUTPUT, $hNullOut) *>$null
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_ERROR, $hNullOut) *>$null
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_INPUT, $hNullIn) *>$null
            $handlesRedirected = $true
            $env:POWERSHELL_TELEMETRY_OPTOUT = '1'
            $ProgressPreference = 'SilentlyContinue'
            return & $Action
        }
        finally {
            if ($handlesRedirected) {
                try {
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_OUTPUT, $hOrigOut) *>$null
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_ERROR, $hOrigErr) *>$null
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_INPUT, $hOrigIn) *>$null
                }
                catch { }
            }
            if ($hNullOut -and $hNullOut -ne $INVALID_HANDLE_VALUE -and $hNullOut -ne [IntPtr]::Zero) {
                try { [WinReinstallStore.NativeConsole]::CloseHandle($hNullOut) *>$null } catch { }
            }
            if ($hNullIn -and $hNullIn -ne $INVALID_HANDLE_VALUE -and $hNullIn -ne [IntPtr]::Zero) {
                try { [WinReinstallStore.NativeConsole]::CloseHandle($hNullIn) *>$null } catch { }
            }
        }
    }
    try {
        Write-StyledMessage -Type 'Progress' -Text (Get-SourceTextLoc 'toolText.startingStoreWingetReinstallation')
        $wingetResult = $false
        try {
            $ProgressPreference = 'SilentlyContinue'
            $wingetResult = Invoke-WithConsoleRedirection -Action { Reset-Winget -Force }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unexpectedErrorDuringResetWinget0' -Args @($($_.Exception.Message)))
            Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.resetWingetUnhandledException0' -Args @($($_.Exception.Message)))
        }
        finally {
            $ProgressPreference = $savedProgressPref
        }
        if ($wingetResult) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.wingetRestoredAndOperational')
        }
        else {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.wingetRestoreFailed')
        }
        $storeResult = Install-MicrosoftStore
        $unigetResult = Install-UniGetUI
        if ($storeResult) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.microsoftStoreSuccessfullyRestored')
        }
        else {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.microsoftStoreNotRestored')
        }
        if ($unigetResult) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.unigetUiInstalled')
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.unigetUiRequireManualVerification')
        }
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.operationCompleted')
    }
    finally {
        $ProgressPreference = $savedProgressPref
    }
    Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.rebootingIn') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
}
function WinBackupDriver {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 10,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "WinBackupDriver" -SubTitle (Get-SourceTextLoc 'script.WinBackupDriver')
    $timeout = 86400
    $script:BackupConfig = @{
        DateTime    = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        BackupDir   = $AppConfig.Paths.DriverBackupTemp
        ArchiveName = "DriverBackup"
        DesktopPath = $AppConfig.Paths.Desktop
        TempPath    = $AppConfig.Paths.TempFolder
        LogsDir     = $AppConfig.Paths.DriverBackupLogs
    }
    $script:FinalArchivePath = "$($script:BackupConfig.DesktopPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).7z"
    function Initialize-BackupEnvironment {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.initializingBackupEnvironment')
        try {
            if (Test-Path $script:BackupConfig.BackupDir) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.removingPreviousBackups')
                Remove-ItemSafely -Path $script:BackupConfig.BackupDir -Recurse
            }
            New-Item -ItemType Directory -Path $script:BackupConfig.BackupDir -Force *>$null
            New-Item -ItemType Directory -Path $script:BackupConfig.LogsDir   -Force *>$null
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.createBackupAndLogDirectories')
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.environmentInitializationError0' -Args @($_))
            return $false
        }
    }
    function Export-SystemDrivers {
        try {
            $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.dismDriverExport') -Command 'dism.exe' `
                -Arguments @('/online', '/export-driver', "/destination:`"$($script:BackupConfig.BackupDir)`"") `
                -TimeoutSeconds $timeout -LogContextKey "Backup-DISM"
            if ($result.TimedOut)       { throw (Get-SourceTextLoc 'toolText.extra.timeoutReachedDuringDismExport') }
            if ($result.ExitCode -ne 0) { throw (Get-SourceTextLoc 'uiText.dismExportFailedWithExitcode0' -Args @($($result.ExitCode))) }
            $exportedDrivers = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
            if (-not $exportedDrivers -or $exportedDrivers.Count -eq 0) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.noThirdPartyDriversFoundToExport')
                Write-StyledMessage -Type 'Info'    -Text (Get-SourceTextLoc 'toolText.windowsBuiltInDriversAreNotExported')
                return $true
            }
            $totalSizeMB = [Math]::Round(($exportedDrivers | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.exportCompleted0Driver1Mb' -Args @($($exportedDrivers.Count), $totalSizeMB))
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorExportingDriver0' -Args @($_))
            return $false
        }
    }
    function Install-7ZipPortable {
        $installDir     = Join-Path $AppConfig.Paths.LocalAppData "WinToolkit\7zip"
        $executablePath = "$installDir\7zr.exe"
        if (Test-Path $executablePath) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.7ZipPortableAlreadyPresent')
            return $executablePath
        }
        New-Item -ItemType Directory -Path $installDir -Force *>$null
        $downloadSources = @(
            @{ Url = $AppConfig.URLs.GitHubAssetBaseUrl + "7zr.exe"; Name = "Repository MagnetarMan" },
            @{ Url = $AppConfig.URLs.SevenZipOfficial;                Name = "Sito ufficiale 7-Zip" }
        )
        foreach ($source in $downloadSources) {
            try {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.download7ZipFrom0' -Args @($($source.Name)))
                Invoke-WebRequest -Uri $source.Url -OutFile $executablePath -UseBasicParsing -ErrorAction Stop
                if (Test-Path $executablePath) {
                    $fileSize = (Get-Item $executablePath).Length
                    if ($fileSize -gt 100KB -and $fileSize -lt 10MB) {
                        $testResult = & $executablePath 2>&1
                        if ($testResult -match "7-Zip" -or $testResult -match "Licensed") {
                            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.7ZipPortableDownloadedAndVerified')
                            return $executablePath
                        }
                    }
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.invalidDownloadedFileSize0Bytes' -Args @($fileSize))
                    Remove-ItemSafely -Path $executablePath
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.downloadFailedFrom01' -Args @($($source.Name), $_))
                Remove-ItemSafely -Path $executablePath
            }
        }
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToDownload7ZipFromAllSources')
        return $null
    }
    function Compress-BackupArchive {
        param([string]$SevenZipPath)
        if (-not $SevenZipPath -or -not (Test-Path $SevenZipPath)) { throw (Get-SourceTextLoc 'toolText.extra.invalid7ZipPath0' -Args @($SevenZipPath)) }
        if (-not (Test-Path $script:BackupConfig.BackupDir))        { throw (Get-SourceTextLoc 'toolText.extra.backupDirectoryNotFound0' -Args @($($script:BackupConfig.BackupDir))) }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.preparingArchiveCompression')
        $backupFiles = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
        if (-not $backupFiles) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.noFilesToCompressInBackupDirectory')
            return $null
        }
        $totalSizeMB = [Math]::Round(($backupFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.totalSize0Mb' -Args @($totalSizeMB))
        $archivePath    = "$($script:BackupConfig.TempPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).7z"
        $compressionArgs = @('a', '-t7z', '-mx=6', '-mmt=on', "`"$archivePath`"", "`"$($script:BackupConfig.BackupDir)\*`"")
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.compressionWith7Zip')
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.7ZipArchiveCompression') -Command $SevenZipPath `
            -Arguments $compressionArgs -TimeoutSeconds 800 -LogContextKey "Backup-7Zip"
        if ($result.TimedOut) { throw (Get-SourceTextLoc 'toolText.extra.timeoutReachedDuringCompression') }
        if ($result.ExitCode -eq 0 -and (Test-Path $archivePath)) {
            $compressedSizeMB  = [Math]::Round((Get-Item $archivePath).Length / 1MB, 2)
            $compressionRatio  = [Math]::Round((1 - $compressedSizeMB / $totalSizeMB) * 100, 1)
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.compressionCompleted0MbReduction1' -Args @($compressedSizeMB, $compressionRatio))
            return $archivePath
        }
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.compressionFailedWithExitcode0' -Args @($($result.ExitCode)))
        return $null
    }
    function Move-ArchiveToDesktop {
        param([string]$ArchivePath)
        if ([string]::IsNullOrWhiteSpace($ArchivePath) -or -not (Test-Path $ArchivePath)) {
            throw (Get-SourceTextLoc 'toolText.extra.invalidArchivePath0' -Args @($ArchivePath))
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.movingArchiveToDesktop')
        try {
            if (-not (Test-Path $script:BackupConfig.DesktopPath)) {
                throw (Get-SourceTextLoc 'toolText.extra2.desktopDirectoryNotAccessible0' -Args @($($script:BackupConfig.DesktopPath)))
            }
            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.removingOldArchive')
                Remove-ItemSafely -Path $script:FinalArchivePath
            }
            Copy-Item -Path $ArchivePath -Destination $script:FinalArchivePath -Force -ErrorAction Stop
            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.archiveSavedToDesktop')
                Write-StyledMessage -Type 'Info'    -Text (Get-SourceTextLoc 'toolText.location0' -Args @($script:FinalArchivePath))
                return $true
            }
            throw (Get-SourceTextLoc 'uiText.archiveCopyFailed')
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.archiveMoveError0' -Args @($_))
            return $false
        }
    }
    try {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.systemInitialization')
        Start-Sleep -Seconds 1
        if (-not (Initialize-BackupEnvironment)) { return }
        if (-not (Export-SystemDrivers))         { return }
        $sevenZipPath = Install-7ZipPortable | Select-Object -Last 1
        if (-not $sevenZipPath) { return }
        $compressedArchive = Compress-BackupArchive -SevenZipPath $sevenZipPath
        if (-not $compressedArchive) { return }
        if (Move-ArchiveToDesktop -ArchivePath $compressedArchive) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.driverBackupCompletedSuccessfully')
            Write-StyledMessage -Type 'Info'    -Text (Get-SourceTextLoc 'toolText.finalArchive0' -Args @($script:FinalArchivePath))
            Write-StyledMessage -Type 'Info'    -Text (Get-SourceTextLoc 'toolText.canBeUsedToReinstallAllDriversWithoutRedownloadingThem')
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinBackupDriver" -Message (Get-SourceTextLoc 'toolText.extra.criticalErrorDuringBackup')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.checkTheLogsForTechnicalDetails')
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.temporaryEnvironmentCleaning')
        Remove-ItemSafely -Path $script:BackupConfig.BackupDir -Recurse
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.driverBackupToolkitFinished')
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.winbackupdriverSessionEnded')
    }
}
function WinDriverInstall {}
function WinDebloat {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "WinDebloat" -SubTitle (Get-SourceTextLoc 'uiText.windebloatToolkit')
    $DebloatServices = @(
    )
    $rebootRequired = $false
    function Invoke-ServiceOptimization {
        param([hashtable]$ServiceConfig)
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.serviceOptimization01' -Args @($($ServiceConfig.Name), $($ServiceConfig.Description)))
        try {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.service0OptimizedSuccessfully' -Args @($($ServiceConfig.Name)))
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorOptimizing01' -Args @($($ServiceConfig.Name), $($_.Exception.Message)))
            return $false
        }
    }
    try {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startingServiceDebloatProcess')
        foreach ($service in $DebloatServices) { Invoke-ServiceOptimization -ServiceConfig $service }
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.debloatOperationsCompleted')
        if ($rebootRequired) {
            Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.rebootToApplyChanges') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinDebloat"
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.resourceCleanupAndWindebloatSessionShutdown')
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.windebloatSessionEnded')
    }
}
function WinCleaner {
    [CmdletBinding()]
    param(
        [ValidateRange(0, 300)]
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    $script:WinCleanerLog = @()
    function Add-CleanerLog {
        param(
            [Parameter(Mandatory = $true, Position = 0)]
            [ValidateSet('Success', 'Info', 'Warning', 'Error', 'Question')]
            [string]$Type,
            [Parameter(Mandatory = $true, Position = 1)]
            [string]$Text
        )
        Clear-ProgressLine
        $script:WinCleanerLog += @{
            Timestamp = Get-Date -Format "HH:mm:ss"
            Type      = $Type
            Text      = $Text
        }
        Write-StyledMessage -Type $Type -Text $Text
    }
    Start-ToolkitSession -ToolName "WinCleaner" -SubTitle (Get-SourceTextLoc 'script.WinCleaner')
    $timeout = 86400
    $ProgressPreference = 'Continue'
    $VitalExclusions = @(
        "$env:LOCALAPPDATA\WinToolkit"
    )
    function Test-VitalExclusion {
        param([string]$Path)
        if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
        $fullPath = $Path -replace '"', ''
        try {
            if (-not [System.IO.Path]::IsPathRooted($fullPath)) {
                $fullPath = Join-Path (Get-Location) $fullPath
            }
            foreach ($excluded in $VitalExclusions) {
                if ($fullPath -like "$excluded*" -or $fullPath -eq $excluded) {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'uiText.lifeProtectionActivated0' -Args @($fullPath))
                    return $true
                }
            }
        }
        catch { return $false }
        return $false
    }
    function Invoke-CommandAction {
        param($Rule)
        $displayName = Get-SourceTextLoc $Rule.NameKey
        Clear-ProgressLine
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.commandExecution0' -Args @($displayName))
        try {
            $result = Invoke-WithSpinner -Activity $displayName -Command $Rule.Command -Arguments $Rule.Args -TimeoutSeconds $timeout -LogContextKey "Cleaner-$($Rule.Name)"
            if ($result.TimedOut) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.commandTimesOutAfter0Hours' -Args @($($timeout/3600)))
                return $true
            }
            if ($result.ExitCode -eq -2146498554 -or $result.ExitCode -eq 0x800F0818) {
                Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.attentionYouAreCleaningWithWindowsUpdateInProgressRefreshYourSystemAndTryAgainToPerformAFu')
                return $false
            }
            $isSuccess = ($result.ExitCode -eq 0)
            $messageType = if ($isSuccess) { 'Info' } else { 'Warning' }
            $messageText = if ($isSuccess) {
                Get-SourceTextLoc 'toolText.extra.commandCompleted'
            }
            else {
                Get-SourceTextLoc 'toolText.extra.commandCompletedWithCode0' -Args @($result.ExitCode)
            }
            Add-CleanerLog -Type $messageType -Text $messageText
            return $true
        }
        catch {
            Add-CleanerLog -Type 'Error' -Text (Get-SourceTextLoc 'toolText.extra.commandError0' -Args @($_))
            return $false
        }
    }
    function Invoke-ServiceAction {
        param($Rule)
        $svcName = $Rule.ServiceName
        $action = $Rule.Action
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if (-not $svc) { return $true }
            if ($action -eq 'Stop' -and $svc.Status -eq 'Running') {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.stoppingService0' -Args @($svcName))
                Stop-Service -Name $svcName -Force -ErrorAction Stop *>$null
            }
            elseif ($action -eq 'Start' -and $svc.Status -ne 'Running') {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.startingService0' -Args @($svcName))
                Start-Service -Name $svcName -ErrorAction Stop *>$null
            }
            return $true
        }
        catch {
            Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.serviceError01' -Args @($svcName, $_))
            return $false
        }
    }
    function Remove-FileItem {
        param($Rule)
        $displayName = Get-SourceTextLoc $Rule.NameKey
        $paths = $Rule.Paths
        $isPerUser = $Rule.PerUser
        $filesOnly = $Rule.FilesOnly
        $takeOwn = $Rule.TakeOwnership
        $targetPaths = @()
        if ($isPerUser) {
            $users = Get-LocalUserProfiles
            foreach ($user in $users) {
                foreach ($p in $paths) {
                    $targetPaths += $p -replace '%USERPROFILE%', $user.FullName `
                        -replace '%APPDATA%', "$($user.FullName)\AppData\Roaming" `
                        -replace '%LOCALAPPDATA%', "$($user.FullName)\AppData\Local" `
                        -replace '%TEMP%', "$($user.FullName)\AppData\Local\Temp"
                }
            }
        }
        else {
            foreach ($p in $paths) { $targetPaths += [Environment]::ExpandEnvironmentVariables($p) }
        }
        $count = 0
        foreach ($path in $targetPaths) {
            if (Test-VitalExclusion $path) { continue }
            if (-not (Test-Path $path)) { continue }
            try {
                if ($takeOwn) {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'uiText.takingOwnershipFor0' -Args @($path))
                    $null = & cmd /c "takeown /F `"$path`" /R /A >nul 2>&1"
                    $adminSID = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
                    $adminAccount = $adminSID.Translate([System.Security.Principal.NTAccount]).Value
                    $null = & cmd /c "icacls `"$path`" /T /grant `"${adminAccount}:F`" >nul 2>&1"
                }
                if ($filesOnly) {
                    $files = Get-ChildItem -Path $path -File -Force -ErrorAction SilentlyContinue
                    foreach ($file in $files) {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    }
                }
                else {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                }
                $count++
            }
            catch {
                Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.removalError01' -Args @($path, $_))
            }
        }
        if ($count -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.cleaned0ItemsIn1' -Args @($count, $displayName)) }
        return $true
    }
    function Remove-RegistryItem {
        param($Rule)
        $keys = $Rule.Keys
        $recursive = $Rule.Recursive
        $valuesOnly = $Rule.ValuesOnly
        foreach ($rawKey in $keys) {
            $key = $rawKey -replace '^(HKCU|HKLM):\\*', '$1:\'
            if (-not (Test-Path $key)) { continue }
            try {
                if ($valuesOnly) {
                    $item = Get-Item $key -ErrorAction Stop
                    $item.GetValueNames() | ForEach-Object {
                        if ($_ -ne '(default)') { Remove-ItemProperty -LiteralPath $key -Name $_ -Force -ErrorAction SilentlyContinue *>$null }
                    }
                    if ($recursive) {
                        Get-ChildItem $key -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                            $currentKeyPath = $_.PSPath
                            $_.GetValueNames() | ForEach-Object { Remove-ItemProperty -LiteralPath $currentKeyPath -Name $_ -Force -ErrorAction SilentlyContinue *>$null }
                        }
                    }
                    Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'uiText.cleanedValuesIn0' -Args @($key))
                }
                else {
                    Remove-Item -Path $key -Recurse:$recursive -Force -ErrorAction Stop
                    Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra.removedKey0' -Args @($key))
                }
            }
            catch {
                Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.registerError01' -Args @($key, $_))
            }
        }
        return $true
    }
    function Set-RegistryItem {
        param($Rule)
        $key = $Rule.Key -replace '^(HKCU|HKLM):', '$1:\'
        try {
            Set-RegistryValue -Path $key -Name $Rule.ValueName -Value $Rule.ValueData -Type $Rule.ValueType
            Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra2.set01' -Args @($key, $($Rule.ValueName)))
            return $true
        }
        catch { return $false }
    }
    function Invoke-WinCleanerRule {
        param($Rule)
        Clear-ProgressLine
        switch ($Rule.Type) {
            'File' { return Remove-FileItem -Rule $Rule }
            'Registry' { return Remove-RegistryItem -Rule $Rule }
            'RegSet' { return Set-RegistryItem -Rule $Rule }
            'Service' { return Invoke-ServiceAction -Rule $Rule }
            'Command' { return Invoke-CommandAction -Rule $Rule }
            'ScriptBlock' {
                if ($Rule.ScriptBlock) {
                    & $Rule.ScriptBlock
                    return $true
                }
            }
            'Custom' {
                if ($Rule.ScriptBlock) {
                    & $Rule.ScriptBlock
                    return $true
                }
            }
        }
        return $true
    }
    $Rules = @(
        @{ Name = "CleanMgr Config"; NameKey = 'cleanerRule.cleanmgrConfig'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleanmgrConfiguration')
                $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
                $opts = @(
                    "Active Setup Temp Folders",
                    "BranchCache",
                    "D3D Shader Cache",
                    "Delivery Optimization Files",
                    'Device Driver Packages',
                    "Downloaded Program Files",
                    "Internet Cache Files",
                    "Memory Dump Files",
                    "Old ChkDsk Files",
                    "Recycle Bin",
                    "Temporary Files",
                    "Thumbnail Cache",
                    "Update Cleanup",
                    "Windows Defender",
                    "Windows Error Reporting Files",
                    "Setup Log Files",
                    "System error memory dump files",
                    "System error minidump files",
                    "Temporary Setup Files",
                    "Windows Upgrade Log Files"
                )
                foreach ($o in $opts) {
                    $p = Join-Path $reg $o
                    if (Test-Path $p) { Set-ItemProperty -Path $p -Name "StateFlags0065" -Value 2 -Type DWORD -Force -ErrorAction SilentlyContinue }
                }
                $cleanMgrExecutionRule = @{
                    Name    = 'Running CleanMgr with /sagerun:65';
                    Type    = "Command";
                    Command = "cleanmgr.exe";
                    Args    = @("/sagerun:65");
                }
                Invoke-CommandAction -Rule $cleanMgrExecutionRule
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra2.waitingForCleanmgrToCompleteMayTakeAFewMinutes')
                $cmDeadline = (Get-Date).AddHours(1)
                while ((Get-Process -Name "cleanmgr" -ErrorAction SilentlyContinue) -and (Get-Date) -lt $cmDeadline) {
                    Start-Sleep -Seconds 10
                }
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleanmgrCompleted')
            }
        }
        @{ Name = "WinSxS Cleanup"; NameKey = 'cleanerRule.winsxsCleanup'; Type = "Command"; Command = "DISM.exe"; Args = @("/Online", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase") }
        @{ Name = "Minimize DISM"; NameKey = 'cleanerRule.minimizeDism'; Type = "RegSet"; Key = "HKLM:\Software\Microsoft\Windows\CurrentVersion\SideBySide\Configuration"; ValueName = "DisableResetbase"; ValueData = 0; ValueType = "DWORD" }
        @{ Name = "Error Reports"; NameKey = 'cleanerRule.errorReports'; Type = "File"; Paths = @(
                "$env:ProgramData\Microsoft\Windows\WER",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\WER"
            ); FilesOnly = $false
        }
        @{ Name = "Clear Event Logs"; NameKey = 'cleanerRule.clearEventLogs'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleaningEventLogsClassicModern')
                $classicLogs = Get-EventLog -List -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Log
                foreach ($logName in $classicLogs) {
                    try {
                        Clear-EventLog -LogName $logName -ErrorAction Stop
                        Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.clearEventlog0' -Args @($logName))
                    }
                    catch {
                        Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.clearEventlog01' -Args @($logName, $($_.Exception.Message)))
                    }
                }
                $wevtErr = $null
                & wevtutil sl 'Microsoft-Windows-LiveId/Operational' /ca:'O:BAG:SYD:(A;;0x1;;;SY)(A;;0x5;;;BA)(A;;0x1;;;LA)' 2>&1 | Out-String -OutVariable wevtErr *>$null
                if ($wevtErr) { Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.wevtutilSlOutput0' -Args @($wevtErr)) }
                Get-WinEvent -ListLog * -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    $logName = $_.LogName
                    if ($_.LogType -in 'Analytical', 'Debug') {
                        Wevtutil.exe sl $logName /e:false *>$null
                    }
                    $clErr = $null
                    Wevtutil.exe cl $logName 2>&1 | Out-String -OutVariable clErr *>$null
                    if ($LASTEXITCODE -ne 0 -and $clErr) { Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.wevtutilCl01' -Args @($logName, $clErr)) }
                }
                Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'uiText.classicAndModernEventLogsDeleted')
            }
        }
        @{ Name = "Clear Windows Update cache"; NameKey = 'cleanerRule.clearWindowsUpdateCache'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.windowsUpdateCacheCleaner')
                $services = @("wuauserv", "bits")
                foreach ($s in $services) {
                    Invoke-ServiceAction -Rule @{ ServiceName = $s; Action = "Stop" }
                }
                $paths = @(
                    "C:\Windows\SoftwareDistribution\Download",
                    "C:\Windows\SoftwareDistribution\DataStore"
                )
                foreach ($p in $paths) {
                    if (Test-Path $p) {
                        try {
                            Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.removal02' -Args @($p))
                            Remove-Item -Path "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.unableToCleanCompletely0' -Args @($p))
                        }
                    }
                }
                foreach ($s in $services) {
                    Invoke-ServiceAction -Rule @{ ServiceName = $s; Action = "Start" }
                }
                Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'uiText.windowsUpdateCacheCleared')
            }
        }
        @{ Name = "Windows App/Download Cache - User"; NameKey = 'cleanerRule.windowsAppDownloadCacheUser'; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Microsoft\Windows\AppCache",
                "%LOCALAPPDATA%\Microsoft\Windows\Caches"
            ); PerUser = $true; FilesOnly = $true
        }
        @{ Name = "System Restore Points"; NameKey = 'cleanerRule.systemRestorePoints'; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleanSystemRestorePoints')
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.analysisAndCleaningOfShadowCopiesKeepLatest')
                    try {
                        $shadows = Get-CimInstance -ClassName Win32_ShadowCopy -ErrorAction Stop | Sort-Object InstallDate -Descending
                        if ($shadows.Count -gt 1) {
                            $toDelete = $shadows | Select-Object -Skip 1
                            $count = $toDelete.Count
                            Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.0ShadowCopiesDetectedRemovingOld1' -Args @($($shadows.Count), $count))
                            foreach ($shadow in $toDelete) {
                                Remove-CimInstance -InputObject $shadow -ErrorAction SilentlyContinue
                            }
                            Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra2.oldShadowCopiesRemovedLastPreservedCopy')
                        }
                        elseif ($shadows.Count -eq 1) {
                            Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.onlyOneShadowCopyFoundNoRemovalNecessary')
                        }
                        else {
                            Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.noShadowCopyDetected')
                        }
                    }
                    catch {
                        Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.shadowCopyManagementError0' -Args @($_))
                    }
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.systemProtectionKeptActiveForSafety')
                    Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra.restorePointCleanupCompleted')
                }
                catch {
                    Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.errorCleaningRestorePoints0' -Args @($($_.Exception.Message)))
                }
            }
        }
        @{ Name = "Cleanup - Windows Prefetch Cache"; NameKey = 'cleanerRule.cleanupWindowsPrefetchCache'; Type = "File"; Paths = @("C:\WINDOWS\Prefetch"); FilesOnly = $false }
        @{ Name = "Cleanup - Explorer Thumbnail/Icon Cache"; NameKey = 'cleanerRule.cleanupExplorerThumbnailIconCache'; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\Explorer"); PerUser = $true; FilesOnly = $true; TakeOwnership = $true }
        @{ Name = "WinInet Cache - User"; NameKey = 'cleanerRule.wininetCacheUser'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleanupWininetWebcacheCache')
                $cacheTaskDisabled = $false
                try {
                    $ct = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Wininet\' -TaskName 'CacheTask' -ErrorAction SilentlyContinue
                    if ($ct -and $ct.State -ne 'Disabled') {
                        Stop-ScheduledTask -TaskPath '\Microsoft\Windows\Wininet\' -TaskName 'CacheTask' -ErrorAction SilentlyContinue
                        Disable-ScheduledTask -TaskPath '\Microsoft\Windows\Wininet\' -TaskName 'CacheTask' -ErrorAction SilentlyContinue *>$null
                        $cacheTaskDisabled = $true
                        Start-Sleep -Seconds 2
                    }
                }
                catch { Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.cachetaskDisableError0' -Args @($_)) }
                $users = Get-LocalUserProfiles
                foreach ($u in $users) {
                    $paths = @(
                        "$($u.FullName)\AppData\Local\Microsoft\Windows\INetCache\IE",
                        "$($u.FullName)\AppData\Local\Microsoft\Windows\WebCache",
                        "$($u.FullName)\AppData\Local\Microsoft\Feeds Cache",
                        "$($u.FullName)\AppData\Local\Microsoft\InternetExplorer\DOMStore",
                        "$($u.FullName)\AppData\Local\Microsoft\Internet Explorer"
                    )
                    foreach ($p in $paths) {
                        if (-not (Test-Path $p)) { continue }
                        Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
                        if (Test-Path $p) {
                            Get-ChildItem -Path $p -Recurse -File -Force -ErrorAction SilentlyContinue |
                                ForEach-Object { Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue }
                            Get-ChildItem -Path $p -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                                Sort-Object { $_.FullName.Length } -Descending |
                                ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
                        }
                    }
                }
                if ($cacheTaskDisabled) {
                    try {
                        Enable-ScheduledTask -TaskPath '\Microsoft\Windows\Wininet\' -TaskName 'CacheTask' -ErrorAction SilentlyContinue *>$null
                    }
                    catch { Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.cachetaskEnableError0' -Args @($_)) }
                }
                Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'uiText.cleanWininetWebcache')
            }
        }
        @{ Name = "Temporary Internet Files"; NameKey = 'cleanerRule.temporaryInternetFiles'; Type = "File"; Paths = @(
                "%USERPROFILE%\Local Settings\Temporary Internet Files"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Cache/History Cleanup"; NameKey = 'cleanerRule.cacheHistoryCleanup'; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "8") }
        @{ Name = "Form Data Cleanup"; NameKey = 'cleanerRule.formDataCleanup'; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "2") }
        @{ Name = "Internet Cookies Cleanup"; NameKey = 'cleanerRule.internetCookiesCleanup'; Type = "File"; Paths = @(
                "%APPDATA%\Microsoft\Windows\Cookies",
                "%LOCALAPPDATA%\Microsoft\Windows\INetCookies"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Cookies Cleanup"; NameKey = 'cleanerRule.cookiesCleanup'; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "1") }
        @{ Name = "Chromium Browsers Cache (Chrome, Edge, Brave, Vivaldi)"; NameKey = 'cleanerRule.chromiumBrowsersCacheChromeEdgeBraveVivaldi'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.chromiumBrowserCacheCleaner')
                $browsers = @(
                    @{ Name = "Google Chrome"; Path = "Google\Chrome\User Data" },
                    @{ Name = "Microsoft Edge"; Path = "Microsoft\Edge\User Data" },
                    @{ Name = "Brave Browser"; Path = "BraveSoftware\Brave-Browser\User Data" },
                    @{ Name = "Vivaldi"; Path = "Vivaldi\User Data" }
                )
                $users = Get-LocalUserProfiles
                foreach ($u in $users) {
                    foreach ($b in $browsers) {
                        $userDataPath = Join-Path "$($u.FullName)\AppData\Local" $b.Path
                        if (Test-Path $userDataPath) {
                            $patterns = @(
                                "$userDataPath\*\Cache",
                                "$userDataPath\*\Code Cache",
                                "$userDataPath\*\GPUCache",
                                "$userDataPath\*\ShaderCache",
                                "$userDataPath\CrashReports"
                            )
                            foreach ($p in $patterns) {
                                Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                }
            }
        }
        @{ Name = "Google Chrome AI OptGuide Model"; NameKey = 'cleanerRule.googleChromeAiOptguideModel'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleaningAndDisablingAiChromeOptguide')
                $users = Get-LocalUserProfiles
                foreach ($u in $users) {
                    $optGuidePath = Join-Path "$($u.FullName)\AppData\Local" "Google\Chrome\User Data\OptGuideOnDeviceModel"
                    if (Test-Path $optGuidePath) {
                        try {
                            Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.removingOptguideFolder0' -Args @($optGuidePath))
                            Remove-Item -Path $optGuidePath -Recurse -Force -ErrorAction Stop
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.removalError01' -Args @($optGuidePath, $_))
                        }
                    }
                    try {
                        if (-not (Test-Path $optGuidePath)) {
                            New-Item -Path $optGuidePath -ItemType Directory -Force -ErrorAction Stop *>$null
                        }
                        $acl = Get-Acl -Path $optGuidePath -ErrorAction Stop
                        $acl.SetAccessRuleProtection($true, $false)
                        $denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                            "Everyone", "Write", "ContainerInherit,ObjectInherit", "None", "Deny"
                        )
                        $acl.AddAccessRule($denyRule)
                        Set-Acl -Path $optGuidePath -AclObject $acl -ErrorAction Stop
                        Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra.optguideFolderSetToReadOnly0' -Args @($optGuidePath))
                    }
                    catch {
                        Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.readOnlySettingErrorFor01' -Args @($optGuidePath, $_))
                    }
                }
                $chromePolicyKey = "HKLM:\SOFTWARE\Policies\Google\Chrome"
                try {
                    if (-not (Test-Path $chromePolicyKey)) {
                        New-Item -Path $chromePolicyKey -Force -ErrorAction Stop *>$null
                    }
                    $aiPolicies = @{
                        "GenAILocalFoundationalModelSettings" = 1
                        "AIModeSettings" = 2
                        "GeminiSettings" = 1
                        "HelpMeWriteSettings" = 2
                        "DevToolsGenAiSettings" = 2
                    }
                    foreach ($policy in $aiPolicies.GetEnumerator()) {
                        Set-ItemProperty -Path $chromePolicyKey -Name $policy.Key -Value $policy.Value -Type DWORD -Force -ErrorAction Stop
                        Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'uiText.chromePolicySet01' -Args @($($policy.Key), $($policy.Value)))
                    }
                }
                catch {
                    Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.chromeAiPolicySettingError0' -Args @($_))
                }
            }
        }
        @{ Name = "Firefox Browser Cache"; NameKey = 'cleanerRule.firefoxBrowserCache'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleaningFirefoxCacheCrashes')
                $users = Get-LocalUserProfiles
                foreach ($u in $users) {
                    $cleanPaths = @(
                        "$($u.FullName)\AppData\Local\Mozilla\Firefox\Profiles",
                        "$($u.FullName)\AppData\Local\Mozilla\Firefox\Crash Reports"
                    )
                    foreach ($p in $cleanPaths) {
                        if (Test-Path $p) { Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                    $msStoreProfiles = Get-ChildItem `
                        "$($u.FullName)\AppData\Local\Packages" `
                        -Directory -Filter "Mozilla.Firefox_*" `
                        -ErrorAction SilentlyContinue
                    foreach ($pkg in $msStoreProfiles) {
                        $msCache = "$($pkg.FullName)\LocalCache\Roaming\Mozilla\Firefox\Profiles"
                        if (Test-Path $msCache) { Remove-Item -Path $msCache -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                }
            }
        }
        @{ Name = "Edge Legacy (HTML) Cache"; NameKey = 'cleanerRule.edgeLegacyHtmlCache'; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC\*\MicrosoftEdge\Cache",
                "%LOCALAPPDATA%\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC\#!001\MicrosoftEdge\Cache"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Opera & Java Cache"; NameKey = 'cleanerRule.operaJavaCache'; Type = "File"; Paths = @(
                "%USERPROFILE%\Local Settings\Application Data\Opera\Opera",
                "%LOCALAPPDATA%\Opera\Opera",
                "%APPDATA%\Opera\Opera",
                "%APPDATA%\Sun\Java\Deployment\cache"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "DNS Flush"; NameKey = 'cleanerRule.dnsFlush'; Type = "Command"; Command = "ipconfig"; Args = @("/flushdns") }
        @{ Name = "System Temp Files"; NameKey = 'cleanerRule.systemTempFiles'; Type = "File"; Paths = @("C:\WINDOWS\Temp"); FilesOnly = $false }
        @{ Name = "User Temp Files"; NameKey = 'cleanerRule.userTempFiles'; Type = "File"; Paths = @(
                "%USERPROFILE%\AppData\Local\Temp",
                "%USERPROFILE%\AppData\LocalLow\Temp"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Service Profiles Temp"; NameKey = 'cleanerRule.serviceProfilesTemp'; Type = "File"; Paths = @("%SYSTEMROOT%\ServiceProfiles\LocalService\AppData\Local\Temp"); FilesOnly = $false }
        @{ Name = "System & Component Logs"; NameKey = 'cleanerRule.systemComponentLogs'; Type = "File"; Paths = @(
                "C:\WINDOWS\Logs",
                "C:\WINDOWS\System32\LogFiles",
                "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
                "%SYSTEMROOT%\Logs\waasmedic",
                "%SYSTEMROOT%\Logs\SIH",
                "%SYSTEMROOT%\Logs\NetSetup",
                "%SYSTEMROOT%\System32\LogFiles\setupcln",
                "%SYSTEMROOT%\Panther",
                "%SYSTEMROOT%\comsetup.log",
                "%SYSTEMROOT%\DtcInstall.log",
                "%SYSTEMROOT%\PFRO.log",
                "%SYSTEMROOT%\setupact.log",
                "%SYSTEMROOT%\setuperr.log",
                "%SYSTEMROOT%\inf\setupapi.app.log",
                "%SYSTEMROOT%\inf\setupapi.dev.log",
                "%SYSTEMROOT%\inf\setupapi.offline.log",
                "%SYSTEMROOT%\Performance\WinSAT\winsat.log",
                "%SYSTEMROOT%\debug\PASSWD.LOG"
            ); FilesOnly = $true
        }
        @{ Name = "User Registry History - Values Only"; NameKey = 'cleanerRule.userRegistryHistoryValuesOnly'; Type = "Registry"; Keys = @(
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRULegacy",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Paint\Recent File List",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Wordpad\Recent File List",
                "HKCU:\Software\Microsoft\MediaPlayer\Player\RecentFileList",
                "HKCU:\Software\Microsoft\MediaPlayer\Player\RecentURLList",
                "HKCU:\Software\Gabest\Media Player Classic\Recent File List",
                "HKCU:\Software\Microsoft\Direct3D\MostRecentApplication",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths",
                "HKCU:\Software\Microsoft\Search Assistant\ACMru",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\SearchHistory",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Map Network Drive MRU"
            ); ValuesOnly = $true; Recursive = $true
        }
        @{ Name = "Adobe Media Browser Key"; NameKey = 'cleanerRule.adobeMediaBrowserKey'; Type = "Registry"; Keys = @("HKCU:\Software\Adobe\MediaBrowser\MRU"); ValuesOnly = $false }
        @{ Name = "Developer Telemetry & Traces"; NameKey = 'cleanerRule.developerTelemetryTraces'; Type = "File"; Paths = @(
                "%USERPROFILE%\.dotnet\TelemetryStorageService",
                "%LOCALAPPDATA%\Microsoft\CLR_v4.0\UsageTraces",
                "%LOCALAPPDATA%\Microsoft\CLR_v4.0_32\UsageTraces",
                "%LOCALAPPDATA%\Microsoft\VSCommon\14.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSCommon\15.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSCommon\16.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSCommon\17.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSApplicationInsights",
                "%TEMP%\Microsoft\VSApplicationInsights",
                "%APPDATA%\vstelemetry",
                "%TEMP%\VSFaultInfo",
                "%TEMP%\VSFeedbackPerfWatsonData",
                "%TEMP%\VSFeedbackVSRTCLogs",
                "%TEMP%\VSFeedbackIntelliCodeLogs",
                "%TEMP%\VSRemoteControl",
                "%TEMP%\Microsoft\VSFeedbackCollector",
                "%TEMP%\VSTelem",
                "%TEMP%\VSTelem.Out",
                "%PROGRAMDATA%\Microsoft\VSApplicationInsights",
                "%PROGRAMDATA%\vstelemetry"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Visual Studio Licenses"; NameKey = 'cleanerRule.visualStudioLicenses'; Type = "Registry"; Keys = @(
                "HKLM:\SOFTWARE\Classes\Licenses\77550D6B-6352-4E77-9DA3-537419DF564B",
                "HKLM:\SOFTWARE\Classes\Licenses\E79B3F9C-6543-4897-BBA5-5BFB0A02BB5C",
                "HKLM:\SOFTWARE\Classes\Licenses\4D8CFBCB-2F6A-4AD2-BABF-10E28F6F2C8F",
                "HKLM:\SOFTWARE\Classes\Licenses\5C505A59-E312-4B89-9508-E162F8150517",
                "HKLM:\SOFTWARE\Classes\Licenses\41717607-F34E-432C-A138-A3CFD7E25CDA",
                "HKLM:\SOFTWARE\Classes\Licenses\B16F0CF0-8AD1-4A5B-87BC-CB0DBE9C48FC",
                "HKLM:\SOFTWARE\Classes\Licenses\10D17DBA-761D-4CD8-A627-984E75A58700",
                "HKLM:\SOFTWARE\Classes\Licenses\1299B4B9-DFCC-476D-98F0-F65A2B46C96D"
            ); ValuesOnly = $false
        }
        @{ Name = "Search History Files"; NameKey = 'cleanerRule.searchHistoryFiles'; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\ConnectedSearch\History"); PerUser = $true }
        @{ Name = "Print Queue (Spooler)"; NameKey = 'cleanerRule.printQueueSpooler'; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.printQueueCleaningSpooler')
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.stoppingSpoolerService')
                    Stop-Service -Name Spooler -Force -ErrorAction Stop *>$null
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.spoolerServiceStopped')
                    Start-Sleep -Seconds 2
                    $printersPath = 'C:\WINDOWS\System32\spool\PRINTERS'
                    if (Test-Path $printersPath) {
                        $files = Get-ChildItem -Path $printersPath -Force -ErrorAction SilentlyContinue
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleanPrintQueueIn01FilesRemoved' -Args @($printersPath, $($files.Count)))
                    }
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.restartingSpoolerService')
                    Start-Service -Name Spooler -ErrorAction Stop *>$null
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.spoolerServiceRestarted')
                    Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra2.printQueueSpoolerCleanedAndRestartedSuccessfully')
                }
                catch {
                    Start-Service -Name Spooler -ErrorAction SilentlyContinue
                    Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.errorCleaningSpooler0' -Args @($($_.Exception.Message)))
                }
            }
        }
        @{ Name = "Stop DPS"; NameKey = 'cleanerRule.stopDps'; Type = "Service"; ServiceName = "DPS"; Action = "Stop" }
        @{ Name = "SRUM Data"; NameKey = 'cleanerRule.srumData'; Type = "File"; Paths = @("%SYSTEMROOT%\System32\sru\SRUDB.dat"); FilesOnly = $true; TakeOwnership = $true }
        @{ Name = "Start DPS"; NameKey = 'cleanerRule.startDps'; Type = "Service"; ServiceName = "DPS"; Action = "Start" }
        @{ Name = "Listary Index"; NameKey = 'cleanerRule.listaryIndex'; Type = "File"; Paths = @("%APPDATA%\Listary\UserData"); PerUser = $true }
        @{ Name = "WinUtil Data"; NameKey = 'cleanerRule.winutilData'; Type = "File"; Paths = @("%LOCALAPPDATA%\winutil"); PerUser = $true }
        @{ Name = "Flash Player Traces"; NameKey = 'cleanerRule.flashPlayerTraces'; Type = "File"; Paths = @("%APPDATA%\Macromedia\Flash Player"); PerUser = $true }
        @{ Name = "Enhanced DiagTrack Management"; NameKey = 'cleanerRule.enhancedDiagtrackManagement'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.improvedManagementOfDiagtrackService')
                function Get-StateFilePath($BaseName, $Suffix) {
                    $escapedBaseName = $BaseName.Split([IO.Path]::GetInvalidFileNameChars()) -Join '_'
                    $uniqueFilename = $escapedBaseName, $Suffix -Join '-'
                    $path = [IO.Path]::Combine($env:APPDATA, 'WinToolkit', 'state', $uniqueFilename)
                    return $path
                }
                function Get-UniqueStateFilePath($BaseName) {
                    $suffix = New-Guid
                    $path = Get-StateFilePath -BaseName $BaseName -Suffix $suffix
                    if (Test-Path -Path $path) {
                        Write-Verbose "Path collision detected at: '$path'. Generating new path."
                        return Get-UniqueStateFilePath $serviceName
                    }
                    return $path
                }
                function New-EmptyFile($Path) {
                    $parentDirectory = [System.IO.Path]::GetDirectoryName($Path)
                    if (-not (Test-Path $parentDirectory -PathType Container)) {
                        try { New-Item -ItemType Directory -Path $parentDirectory -Force -ErrorAction Stop *>$null }
                        catch { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.failedToCreateParentDirectory0' -Args @($_)); return $false }
                    }
                    try { New-Item -ItemType File -Path $Path -Force -ErrorAction Stop *>$null; return $true }
                    catch { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.failedToCreateFile0' -Args @($_)); return $false }
                }
                $serviceName = 'DiagTrack'
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.checkServiceStatus0' -Args @($serviceName))
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if (-not $service) {
                    Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.service0NotFoundSkip' -Args @($serviceName))
                    return
                }
                if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.service0ActiveStopping' -Args @($serviceName))
                    try {
                        $service | Stop-Service -Force -ErrorAction Stop
                        $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped, [TimeSpan]::FromSeconds(30))
                        $path = Get-UniqueStateFilePath $serviceName
                        if (New-EmptyFile $path) {
                            Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra.serviceStoppedAndStateSavedAutoRestartEnabled')
                        }
                        else {
                            Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.serviceStoppedManualRestartRequired')
                        }
                    }
                    catch { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorStoppingService0' -Args @($_)) }
                }
                else {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.service0DownCheckRestart' -Args @($serviceName))
                    $fileGlob = Get-StateFilePath -BaseName $serviceName -Suffix '*'
                    $stateFiles = Get-ChildItem -Path $fileGlob -ErrorAction SilentlyContinue
                    if ($stateFiles.Count -eq 1) {
                        try {
                            Remove-Item -Path $stateFiles[0].FullName -Force -ErrorAction Stop
                            $service | Start-Service -ErrorAction Stop
                            Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra.service0RestartedSuccessfully' -Args @($serviceName))
                        }
                        catch { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorRestartingService0' -Args @($_)) }
                    }
                    elseif ($stateFiles.Count -gt 1) {
                        Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.multipleStateFilesFoundServiceWillNotBeRestartedAutomatically')
                    }
                    else {
                        Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.service0WasNotActivePreviously' -Args @($serviceName))
                    }
                }
            }
        }
        @{ Name = "Credential Manager"; NameKey = 'cleanerRule.credentialManager'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleaningCredentials')
                $cmdkeyErr = $null
                $targets = & cmdkey /list 2>&1 | Tee-Object -Variable cmdkeyErr | Where-Object { $_ -match '^Target:' }
                if ($cmdkeyErr -and $LASTEXITCODE -ne 0) { Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.cmdkeyListError0' -Args @($cmdkeyErr)) }
                $targets | ForEach-Object {
                    $t = $_.Split(':')[1].Trim()
                    $delErr = $null
                    & cmdkey /delete:$t 2>&1 | Tee-Object -Variable delErr *>$null
                    if ($delErr -and $LASTEXITCODE -ne 0) { Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.cmdkeyDelete0Error1' -Args @($t, $delErr)) }
                }
            }
        }
        @{ Name = "Regedit Last Key"; NameKey = 'cleanerRule.regeditLastKey'; Type = "Registry"; Keys = @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit"); ValuesOnly = $true }
        @{ Name = "Windows.old"; NameKey = 'cleanerRule.windowsOld'; Type = "ScriptBlock"; ScriptBlock = {
                $path = "C:\Windows.old"
                if (Test-Path $path) {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.windowsOldFolderDetectedStartingSafeRemovalWithNativeCleanmgr')
                    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations"
                    if (-not (Test-Path $regKey)) {
                        Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.registryKeyPreviousInstallationsNotFoundStandardExecutionAttempt')
                    }
                    else {
                        try {
                            Set-ItemProperty -Path $regKey -Name "StateFlags0066" -Value 2 -Type DWORD -Force -ErrorAction Stop
                            Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleanmgrConfigurationEnabledForWindowsOldStateflags0066')
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.failedToWriteToRegistryForCleanmgr0' -Args @($_))
                        }
                    }
                    $cleanMgrRule = @{
                        Name    = 'Removing Windows.old (CleanMgr)';
                        Type    = "Command";
                        Command = "cleanmgr.exe";
                        Args    = @("/sagerun:66");
                    }
                    $null = Invoke-CommandAction -Rule $cleanMgrRule
                    if (Test-Path $path) {
                        Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.iTheWindowsOldFolderMayRequireARebootForCompleteRemoval')
                    }
                    else {
                        Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra2.windowsOldSuccessfullyRemoved')
                    }
                }
                else {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.noWindowsOldFolderDetected')
                }
            }
        }
        @{ Name = "Empty Recycle Bin"; NameKey = 'cleanerRule.emptyRecycleBin'; Type = "Custom"; ScriptBlock = {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'uiText.trashEmptied')
            }
        }
    )
    $totalRules = $Rules.Count
    $currentRuleIndex = 0
    $successCount = 0
    $errorCount = 0
    foreach ($rule in $Rules) {
        $currentRuleIndex++
        $percent = [math]::Round(($currentRuleIndex / $totalRules) * 100)
        Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.ruleExecution') -Status (Get-SourceTextLoc $rule.NameKey) -Percent $percent -Icon '⚙️'
        $result = Invoke-WinCleanerRule -Rule $rule
        Clear-ProgressLine
        if ($result) { $successCount++ }
        else { $errorCount++ }
    }
    Clear-ProgressLine
    Write-StyledMessage -Type 'Info' -Text "=================================================="
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.summaryOfOperations')
    Write-StyledMessage -Type 'Info' -Text "=================================================="
    $stats = $script:WinCleanerLog | Group-Object Type
    $sCount = ($stats | Where-Object Name -eq 'Success').Count
    $wCount = ($stats | Where-Object Name -eq 'Warning').Count
    $eCount = ($stats | Where-Object Name -eq 'Error').Count
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.operationsCompletedSuccessfully0' -Args @($sCount))
    if ($wCount -gt 0) { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.alertsGenerated0' -Args @($wCount)) }
    if ($eCount -gt 0) { Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorsEncountered0' -Args @($eCount)) }
    Write-StyledMessage -Type 'Info' -Text "--------------------------------------------------"
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.detailsOfErrorsAndWarnings')
    $problems = $script:WinCleanerLog | Where-Object { $_.Type -in 'Warning', 'Error' }
    if ($problems) {
        foreach ($p in $problems) {
            Write-StyledMessage -Type $p.Type -Text $p.Text
        }
    }
    else {
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.noProblemsDetected')
    }
    Write-StyledMessage -Type 'Info' -Text "=================================================="
    Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.systemRebootIn') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
}
function DisableBitlocker {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "DisableBitlocker" -SubTitle (Get-SourceTextLoc 'script.DisableBitlocker')
    $regPath = $AppConfig.Registry.BitLocker
    $timeout = 3600
    function Test-BitLockerStatus {
        param([string]$DriveLetter = "C:")
        try { return manage-bde -status $DriveLetter }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.unableToCheckBitlockerStatus0' -Args @($($_.Exception.Message)))
            return $null
        }
    }
    try {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.initializingDriveCDecryption')
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.disablingBitlocker') -Command 'manage-bde.exe' `
            -Arguments @('-off', 'C:') -TimeoutSeconds $timeout -LogContextKey "Bitlocker-Disable"
        if ($result.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.decryptionStartedCompletedSuccessfully')
            Start-Sleep -Seconds 2
            $status = Test-BitLockerStatus -DriveLetter "C:"
            if ($status -match "Decryption in progress" -or $status -match 'Decryption in progress.') {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.decryptionInProgressInBackground')
            }
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.manageBdeExitCode0BitlockerMayAlreadyBeDownOrInError' -Args @($($result.ExitCode)))
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.disablingAutomaticEncryptionInTheRegistry')
        Set-RegistryValue -Path $regPath -Name "PreventDeviceEncryption" -Value 1
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.setupComplete')
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "DisableBitlocker"
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.resourceCleanupCompleted')
        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.rebootingIn') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.disablebitlockerSessionEnded')
    }
}
function WinDeleteUserProfiles {
    [CmdletBinding()]
    param(
        [ValidateRange(1, 16)]
        [int]$MaxThreads = [Math]::Min(2, [Environment]::ProcessorCount),
        [ValidateRange(0, 3600)]
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot,
        [ValidateNotNullOrEmpty()]
        [string]$UsersRoot = 'C:\Users',
        [ValidateNotNullOrEmpty()]
        [string]$LogFolder = 'C:\Temp',
        [ValidateRange(0, 3650)]
        [int]$MinimumProfileAgeDays = 0,
        [switch]$SkipResidualFolderCleanup,
        [switch]$SuppressToolkitSession
    )
    begin {
        $script:ToolName = 'WinDeleteUserProfiles'
        $script:ToolVersion = '3.1'
        $script:SessionStart = Get-Date
        $script:UsersRoot = [System.IO.Path]::GetFullPath($UsersRoot.TrimEnd('\') + '\')
        $script:LogFolder = [System.IO.Path]::GetFullPath($LogFolder)
        $script:LogFile = Join-Path $script:LogFolder ("{0}_{1}.log" -f $script:ToolName, (Get-Date -Format 'yyyyMMdd_HHmmss'))
        $script:CurrentUser = $env:USERNAME
        $script:ComputerName = $env:COMPUTERNAME
        $script:CountdownSeconds = $CountdownSeconds
        $script:SuppressIndividualReboot = $SuppressIndividualReboot
        $script:RebootRecommended = $false
        $script:MinimumLastUseDate = if ($MinimumProfileAgeDays -gt 0) { (Get-Date).AddDays(-$MinimumProfileAgeDays) } else { $null }
        $script:ProtectedProfileNames = @(
            'Public',
            'Pubblica',
            'Default',
            'Default User',
            'All Users',
            'defaultuser0',
            'WDAGUtilityAccount',
            'Administrator',
            'Guest',
            $script:CurrentUser
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $savedErrorActionPreference = $ErrorActionPreference
        $savedProgressPreference = $ProgressPreference
        $savedConfirmPreference = $ConfirmPreference
        $ErrorActionPreference = 'Stop'
        $ProgressPreference = 'Continue'
        $ConfirmPreference = 'None'
        $script:LogQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    }
    process {
        if (-not (Get-Command -Name Write-StyledMessage -ErrorAction SilentlyContinue)) {
            function Write-StyledMessage {
                param(
                    [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Progress')]
                    [string]$Type = 'Info',
                    [Parameter(Mandatory = $true)]
                    [string]$Text
                )
                $color = switch ($Type) {
                    'Success' { 'Green' }
                    'Warning' { 'Yellow' }
                    'Error'   { 'Red' }
                    default   { 'Cyan' }
                }
                Write-Host $Text -ForegroundColor $color
            }
        }
        function Add-ProfileCleanupLog {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Text,
                [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
                [string]$Level = 'INFO'
            )
            $script:LogQueue.Enqueue(
                ('{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Text)
            )
        }
        function Set-ProfileCleanupRebootRecommended {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Reason
            )
            $script:RebootRecommended = $true
            Add-ProfileCleanupLog -Level 'WARNING' -Text (Get-SourceTextLoc 'toolText.recommendedReboot0' -Args @($Reason))
        }
        function Invoke-ProfileCleanupReboot {
            if (-not $script:RebootRecommended) {
                return
            }
            if (Get-Command -Name Invoke-ToolkitReboot -ErrorAction SilentlyContinue) {
                Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.restartRecommendedAfterProfileCleanup') -Seconds $script:CountdownSeconds -SuppressIndividualReboot:$script:SuppressIndividualReboot
                return
            }
            if ($script:SuppressIndividualReboot) {
                $Global:NeedsFinalReboot = $true
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.individualRestartSuppressedAFinalRebootWillBeHandled')
                return
            }
            if (Get-Command -Name Start-InterruptibleCountdown -ErrorAction SilentlyContinue) {
                if (Start-InterruptibleCountdown -Seconds $script:CountdownSeconds -Message (Get-SourceTextLoc 'toolText.extra.restartRecommendedAfterProfileCleanup')) {
                    Restart-Computer -Force
                }
                return
            }
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.restartRecommendedToCompleteCleanupOfUnremovedProfiles')
        }
        function Test-IsAdministrator {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = [Security.Principal.WindowsPrincipal]::new($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        function Initialize-ProfileCleanupSession {
            [System.IO.Directory]::CreateDirectory($script:LogFolder) | Out-Null
            if (-not (Test-IsAdministrator)) {
                throw (Get-SourceTextLoc 'toolText.extra2.theScriptMustBeRunFromAPowershellConsoleStartedAsAdministrator')
            }
            if (-not (Test-Path -LiteralPath $script:UsersRoot -PathType Container)) {
                throw (Get-SourceTextLoc 'toolText.extra.profilePathDoesNotExist0' -Args @($script:UsersRoot))
            }
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($os -and $os.Caption -notmatch 'Windows 11') {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.systemDetected0TheScriptIsDesignedForWindows11' -Args @($($os.Caption)))
            }
            if (-not $SuppressToolkitSession -and (Get-Command -Name Start-ToolkitSession -ErrorAction SilentlyContinue)) {
                $profileCleanupTitle = if (Get-Command -Name Get-SourceTextLoc -ErrorAction SilentlyContinue) {
                    Get-SourceTextLoc 'script.WinDeleteUserProfiles'
                }
                else {
                    'Delete Windows user profiles'
                }
                Start-ToolkitSession -ToolName $script:ToolName -SubTitle $profileCleanupTitle
            }
            else {
                Write-Host ''
                Write-Host '====================================================' -ForegroundColor Cyan
                Write-Host (Get-SourceTextLoc 'toolText.0V1' -Args @($script:ToolName, $script:ToolVersion))
                Write-Host '====================================================' -ForegroundColor Cyan
                Write-Host ''
            }
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.computer0' -Args @($script:ComputerName))
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.currentUserProtected0' -Args @($script:CurrentUser))
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.profilePath0' -Args @($script:UsersRoot))
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.threadsConfigured0' -Args @($MaxThreads))
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.nonInteractiveModeNoConfirmationWillBeRequestedBeforeCancellations')
            if ($script:MinimumLastUseDate) {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.lastActivityThresholdProfilesNotUsedForAtLeast0Days' -Args @($MinimumProfileAgeDays))
            }
            Add-ProfileCleanupLog -Text (Get-SourceTextLoc 'toolText.sessionStartedOn0' -Args @($script:ComputerName))
        }
        function New-ProtectedNameSet {
            $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $script:ProtectedProfileNames | ForEach-Object { [void]$excluded.Add($_) }
            return ,$excluded
        }
        function Get-RegisteredProfilePathSet {
            $pathSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.LocalPath -and
                    $_.LocalPath.StartsWith($script:UsersRoot, [System.StringComparison]::OrdinalIgnoreCase)
                } |
                ForEach-Object {
                    try {
                        [void]$pathSet.Add([System.IO.Path]::GetFullPath($_.LocalPath).TrimEnd('\'))
                    }
                    catch {
                        Add-ProfileCleanupLog -Level 'WARNING' -Text (Get-SourceTextLoc 'toolText.failedToNormalizeRegisteredProfileLocalpath0' -Args @($($_.LocalPath)))
                    }
                }
            return ,$pathSet
        }
        function Get-RemovableUserProfiles {
            $excluded = New-ProtectedNameSet
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.scanningRegisteredLocalProfiles')
            $profiles = Get-CimInstance -ClassName Win32_UserProfile | Where-Object {
                -not $_.Special -and
                -not $_.Loaded -and
                $_.LocalPath -and
                $_.LocalPath.StartsWith($script:UsersRoot, [System.StringComparison]::OrdinalIgnoreCase)
            }
            foreach ($profile in $profiles) {
                $profileName = [System.IO.Path]::GetFileName($profile.LocalPath)
                if ($excluded.Contains($profileName)) {
                    Add-ProfileCleanupLog -Text (Get-SourceTextLoc 'toolText.excludedProfile01' -Args @($profileName, $($profile.LocalPath)))
                    continue
                }
                if ($script:MinimumLastUseDate -and $profile.LastUseTime) {
                    $lastUse = $profile.LastUseTime
                    if ($lastUse -gt $script:MinimumLastUseDate) {
                        Add-ProfileCleanupLog -Text (Get-SourceTextLoc 'toolText.profileExcludedDueToTimeThreshold0LastUse1' -Args @($profileName, $lastUse))
                        continue
                    }
                }
                $profile
            }
        }
        function Show-ProfileCleanupPreview {
            param(
                [Parameter(Mandatory = $true)]
                [array]$Profiles
            )
            Write-Host ''
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.registeredProfilesSelectedForAutomaticRemoval')
            Write-Host ''
            $Profiles |
                Select-Object @{Name='User'; Expression={ [System.IO.Path]::GetFileName($_.LocalPath) }},
                              @{Name='Loaded'; Expression={ $_.Loaded }},
                              @{Name='LastUseTime'; Expression={ $_.LastUseTime }},
                              @{Name='Path'; Expression={ $_.LocalPath }} |
                Format-Table -AutoSize
            Write-Host ''
        }
        function Invoke-ProfileRemovalBatch {
            param(
                [Parameter(Mandatory = $true)]
                [array]$Profiles
            )
            $pool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
            $pool.Open()
            $jobs = [System.Collections.Generic.List[object]]::new()
            $scriptBlock = {
                param($Profile, $LogQueue)
                $ConfirmPreference = 'None'
                $ErrorActionPreference = 'Stop'
                $userPath = $Profile.LocalPath
                $userName = [System.IO.Path]::GetFileName($userPath)
                $start = Get-Date
                $LogQueue.Enqueue(('{0} [INFO] START PROFILE - {1} - {2}' -f $start.ToString('yyyy-MM-dd HH:mm:ss'), $userName, $userPath))
                try {
                    Remove-CimInstance -InputObject $Profile -ErrorAction Stop -Confirm:$false
                    $LogQueue.Enqueue(('{0} [SUCCESS] CIM profile removed - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                }
                catch {
                    $LogQueue.Enqueue(('{0} [WARNING] CIM remove failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))
                }
                if ([System.IO.Directory]::Exists($userPath)) {
                    try {
                        $tempEmpty = Join-Path $env:TEMP "EmptyFolder"
                        if (-not (Test-Path $tempEmpty)) {
                            New-Item -ItemType Directory -Path $tempEmpty | Out-Null
                        }
                        robocopy $tempEmpty $userPath /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
                        Remove-Item -LiteralPath $userPath -Force -Recurse -ErrorAction SilentlyContinue
                        $LogQueue.Enqueue(('{0} [SUCCESS] Folder removed - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                    }
                    catch {
                        $LogQueue.Enqueue(('{0} [WARNING] Standard folder cleanup failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))
                        try {
                            try {
                                & takeown.exe /F $userPath /R /D S | Out-Null
                            }
                            catch {
                                try {
                                    & takeown.exe /F $userPath /R /D Y | Out-Null
                                }
                                catch {
                                    $LogQueue.Enqueue(('{0} [ERROR] takeown failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))
                                }
                            }
                            & icacls.exe $userPath /grant Administrators:F /T /C | Out-Null
                            Remove-Item -LiteralPath $userPath -Force -Recurse -ErrorAction Stop -Confirm:$false
                            $LogQueue.Enqueue(('{0} [SUCCESS] Folder removed after ACL reset - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                        }
                        catch {
                            $LogQueue.Enqueue(('{0} [ERROR] Cleanup failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))
                        }
                    }
                }
                $success = -not [System.IO.Directory]::Exists($userPath)
                $duration = New-TimeSpan -Start $start -End (Get-Date)
                if ($success) {
                    $LogQueue.Enqueue(('{0} [SUCCESS] COMPLETED PROFILE - {1} - {2:hh\:mm\:ss}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $duration))
                }
                else {
                    $LogQueue.Enqueue(('{0} [ERROR] FAILED PROFILE - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                }
                return [PSCustomObject]@{
                    Type     = 'Profile'
                    UserName = $userName
                    Path     = $userPath
                    Success  = $success
                    Duration = $duration
                }
            }
            try {
                foreach ($profile in $Profiles) {
                    $ps = [PowerShell]::Create()
                    $ps.RunspacePool = $pool
                    [void]$ps.AddScript($scriptBlock, $true).
                        AddArgument($profile).
                        AddArgument($script:LogQueue)
                    $handle = $ps.BeginInvoke()
                    $jobs.Add([PSCustomObject]@{
                        PowerShell = $ps
                        Handle     = $handle
                    })
                }
                $total = $jobs.Count
                $lastPercent = -1
                do {
                    $completed = ($jobs | Where-Object { $_.Handle.IsCompleted }).Count
                    $percent = if ($total -gt 0) { [math]::Floor(($completed / $total) * 100) } else { 100 }
                    if ($percent -ne $lastPercent) {
                        $lastPercent = $percent
                        Write-Progress -Activity (Get-SourceTextLoc 'toolText.extra.removingRegisteredProfiles') -Status (Get-SourceTextLoc 'toolText.extra.01Completed' -Args @($completed, $total)) -PercentComplete $percent
                    }
                    Start-Sleep -Milliseconds 500
                } while ($completed -lt $total)
                Write-Progress -Activity (Get-SourceTextLoc 'toolText.extra.removingRegisteredProfiles') -Completed
                $results = foreach ($job in $jobs) {
                    try {
                        $job.PowerShell.EndInvoke($job.Handle)
                    }
                    catch {
                        Add-ProfileCleanupLog -Level 'ERROR' -Text (Get-SourceTextLoc 'toolText.runspaceError0' -Args @($($_.Exception.Message)))
                    }
                    finally {
                        $job.PowerShell.Commands.Clear()
                        $job.PowerShell.Dispose()
                    }
                }
                return $results
            }
            finally {
                if ($pool) {
                    $pool.Close()
                    $pool.Dispose()
                }
            }
        }
        function Get-ResidualUserFolders {
            $excluded = New-ProtectedNameSet
            $registeredProfilePaths = Get-RegisteredProfilePathSet
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.checkResidualFoldersInTheUsersDirectory')
            $folders = Get-ChildItem -Path $UsersRoot -Directory -Force |
                Where-Object {
                    -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
                }
            foreach ($folder in $folders) {
                $folderName = $folder.Name
                $folderPath = [System.IO.Path]::GetFullPath($folder.FullName).TrimEnd('\')
                if ($excluded.Contains($folderName)) {
                    Add-ProfileCleanupLog -Text (Get-SourceTextLoc 'toolText.residualFolderExcludedForProtectedName01' -Args @($folderName, $folderPath))
                    continue
                }
                if ($registeredProfilePaths.Contains($folderPath)) {
                    Add-ProfileCleanupLog -Text (Get-SourceTextLoc 'toolText.residualFolderExcludedBecauseItIsStillAssociatedWithWin32Userprofile01' -Args @($folderName, $folderPath))
                    continue
                }
                if ($folder.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                    Add-ProfileCleanupLog -Level 'WARNING' -Text (Get-SourceTextLoc 'toolText.residualFolderExcludedBecauseReparsePointSymlink01' -Args @($folderName, $folderPath))
                    continue
                }
                [PSCustomObject]@{
                    Name = $folderName
                    Path = $folderPath
                }
            }
        }
        function Remove-ResidualUserFolders {
            param(
                [Parameter(Mandatory = $true)]
                [array]$Folders
            )
            $results = [System.Collections.Generic.List[object]]::new()
            $total = $Folders.Count
            $index = 0
            foreach ($folder in $Folders) {
                $index++
                $percent = if ($total -gt 0) { [math]::Floor(($index / $total) * 100) } else { 100 }
                Write-Progress `
                    -Activity (Get-SourceTextLoc 'toolText.extra.removingResidualFoldersInCUsers') `
                    -Status ("{0} / {1} - {2}" -f $index, $total, $folder.Name) `
                    -PercentComplete $percent
                $start = Get-Date
                $success = $false
                Add-ProfileCleanupLog -Text (Get-SourceTextLoc 'toolText.startResidualFolder01' -Args @($($folder.Name), $($folder.Path)))
                $folderPath = $folder.Path
                try {
                    Remove-Item -LiteralPath $folderPath -Force -Recurse -ErrorAction Stop -Confirm:$false
                    $success = -not [System.IO.Directory]::Exists($folderPath)
                }
                catch {
                    Add-ProfileCleanupLog -Level 'WARNING' -Text (Get-SourceTextLoc 'toolText.standardResidualFolderRemovalFailed01' -Args @($folderPath, $($_.Exception.Message)))
                    try {
                        & takeown.exe /F $folderPath /R /D Y | Out-Null
                        & icacls.exe $folderPath /grant Administrators:F /T /C | Out-Null
                        Remove-Item -LiteralPath $folderPath -Force -Recurse -ErrorAction Stop -Confirm:$false
                        $success = -not [System.IO.Directory]::Exists($folderPath)
                    }
                    catch {
                        Add-ProfileCleanupLog -Level 'ERROR' -Text (Get-SourceTextLoc 'toolText.remnantFolderRemovalFailed01' -Args @($folderPath, $($_.Exception.Message)))
                        $success = $false
                    }
                }
                $duration = New-TimeSpan -Start $start -End (Get-Date)
                if ($success) {
                    Add-ProfileCleanupLog -Level 'SUCCESS' -Text (Get-SourceTextLoc 'toolText.completedResidualFolder01' -Args @($($folder.Name), $($duration.ToString())))
                }
                else {
                    Add-ProfileCleanupLog -Level 'ERROR' -Text (Get-SourceTextLoc 'toolText.failedResidualFolder0' -Args @($($folder.Name)))
                }
                $results.Add([PSCustomObject]@{
                    Type     = 'ResidualFolder'
                    UserName = $folder.Name
                    Path     = $folder.Path
                    Success  = $success
                    Duration = $duration
                }) | Out-Null
            }
            Write-Progress -Activity (Get-SourceTextLoc 'toolText.extra.removingResidualFoldersInCUsers') -Completed
            return $results
        }
        function Save-ProfileCleanupLog {
            $logLines = [System.Collections.Generic.List[string]]::new()
            $line = $null
            while ($script:LogQueue.TryDequeue([ref]$line)) {
                $logLines.Add($line)
            }
            $logLines | Set-Content -LiteralPath $script:LogFile -Encoding UTF8
        }
        try {
            Initialize-ProfileCleanupSession
            $profileResults = @()
            $residualResults = @()
            $targets = @(Get-RemovableUserProfiles)
            if ($targets -and $targets.Count -gt 0) {
                Show-ProfileCleanupPreview -Profiles $targets
                Write-Host ''
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startAutomaticRemovalOf0RegisteredProfiles' -Args @($targets.Count))
                Write-Host ''
                $profileResults = @(Invoke-ProfileRemovalBatch -Profiles $targets)
            }
            else {
                Write-Host ''
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.noRemovableRegisteredProfilesFound')
                Add-ProfileCleanupLog -Level 'SUCCESS' -Text (Get-SourceTextLoc 'toolText.noRemovableRegisteredProfilesFound2')
            }
            if (-not $SkipResidualFolderCleanup) {
                $residualFolders = @(Get-ResidualUserFolders)
                if ($residualFolders -and $residualFolders.Count -gt 0) {
                    Write-Host ''
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.residualFoldersSelectedForAutomaticRemoval0' -Args @($residualFolders.Count))
                    $residualFolders | Select-Object Name, Path | Format-Table -AutoSize
                    Write-Host ''
                    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startingRemovalOfResidualFolders')
                    Write-Host ''
                    $residualResults = @(Remove-ResidualUserFolders -Folders $residualFolders)
                }
                else {
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.noRemovableResidualFolderFoundInCUsers')
                    Add-ProfileCleanupLog -Level 'SUCCESS' -Text (Get-SourceTextLoc 'toolText.noRemovableResidualFoldersFound')
                }
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.residualFolderCleanupSkippedForSkipresidualfoldercleanupParameter')
                Add-ProfileCleanupLog -Level 'WARNING' -Text (Get-SourceTextLoc 'toolText.remainingFolderCleanupSkipped')
            }
            $allResults = @($profileResults) + @($residualResults)
            $successCount = @($allResults | Where-Object { $_.Success }).Count
            $failedCount = @($allResults | Where-Object { -not $_.Success }).Count
            $profileSuccessCount = @($profileResults | Where-Object { $_.Success }).Count
            $residualSuccessCount = @($residualResults | Where-Object { $_.Success }).Count
            if ($failedCount -gt 0) {
                Set-ProfileCleanupRebootRecommended -Reason (Get-SourceTextLoc 'toolText.0ItemsNotRemovedMayBeBlockedByOpenSessionsOrHandles' -Args @($failedCount))
            }
            $script:SessionEnd = Get-Date
            $totalDuration = New-TimeSpan -Start $script:SessionStart -End $script:SessionEnd
            Add-ProfileCleanupLog -Level 'INFO' -Text (Get-SourceTextLoc 'toolText.sessionCompletedProfilesRemoved0ResidualFoldersRemoved1Errors2Duration3' -Args @($profileSuccessCount, $residualSuccessCount, $failedCount, $totalDuration))
            Save-ProfileCleanupLog
            Write-Host ''
            Write-Host '====================================================' -ForegroundColor Green
            $completionText = (Get-SourceTextLoc 'sourceText.completed').ToUpperInvariant()
            Write-Host $completionText
            Write-Host '====================================================' -ForegroundColor Green
            Write-Host ''
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.registeredProfilesRemoved0' -Args @($profileSuccessCount))
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.residualFoldersRemoved0' -Args @($residualSuccessCount))
            if ($failedCount -gt 0) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.itemsNotRemoved0' -Args @($failedCount))
            }
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'uiText.duration0' -Args @($totalDuration))
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.log0' -Args @($script:LogFile))
            Invoke-ProfileCleanupReboot
        }
        catch {
            Add-ProfileCleanupLog -Level 'ERROR' -Text $_.Exception.Message
            try { Save-ProfileCleanupLog } catch { }
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.error0' -Args @($_.Exception.Message))
            throw
        }
        finally {
            $ErrorActionPreference = $savedErrorActionPreference
            $ProgressPreference = $savedProgressPreference
            $ConfirmPreference = $savedConfirmPreference
        }
    }
}
function Install-Office {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "OfficeInstall" -SubTitle (Get-SourceTextLoc 'script.Install-Office')
    $tempDir = $AppConfig.Paths.OfficeTemp
    function Set-OfficePostConfig {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.officePostInstallationConfiguration')
        foreach ($reg in @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";         Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "disconnectedstate";     Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "usercontentdisabled";   Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "downloadcontentdisabled"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";         Value = 0 }
        )) { Set-RegistryValue -Path $reg.Path -Name $reg.Name -Value $reg.Value }
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General" -Name "ShownOptIn" -Value 1
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.telemetryAndPrivacyOfficeDisabled')
    }
    try {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startingOfficeBasicInstallation')
        if (-not (Test-Path $tempDir)) {
            $null = New-Item -ItemType Directory -Path $tempDir -Force
        }
        $setupPath  = Join-Path $tempDir 'Setup.exe'
        $configPath = Join-Path $tempDir 'Basic.xml'
        foreach ($dl in @(
            @{ Url = $AppConfig.URLs.OfficeSetup;       Path = $setupPath;  Name = (Get-SourceTextLoc 'toolText.extra.officeSetup') },
            @{ Url = $AppConfig.URLs.OfficeBasicConfig; Path = $configPath; Name = (Get-SourceTextLoc 'toolText.extra.basicConfiguration') }
        )) {
            if (-not (Invoke-ToolkitDownload -Uri $dl.Url -OutputPath $dl.Path -Description $dl.Name)) {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.downloadFailedInstallationCancelled')
                return
            }
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startingInstallationProcess')
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.officeBasicInstallation') -Command $setupPath `
            -Arguments "/configure `"$configPath`"" -TimeoutSeconds 86400 -LogContextKey "Office-Install"
        Clear-ProgressLine
        if (-not $result.Success) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.installationFailed')
            return
        }
        Set-OfficePostConfig
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.installationCompleted')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.restartNotRequired')
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorInstallingOffice0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.criticalErrorInInstallOffice') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Remove-ItemSafely -Path $tempDir -Recurse
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.officeInstallFinished')
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.installOfficeSessionEnded')
    }
}
function Repair-Office {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "OfficeRepair" -SubTitle (Get-SourceTextLoc 'script.Repair-Office')
    function Set-OfficePostConfig {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.officePostRepairSetup')
        foreach ($reg in @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";           Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "disconnectedstate";       Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "usercontentdisabled";     Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "downloadcontentdisabled"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";           Value = 0 }
        )) { Set-RegistryValue -Path $reg.Path -Name $reg.Name -Value $reg.Value }
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General" -Name "ShownOptIn" -Value 1
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.telemetryAndPrivacyOfficeDisabled')
    }
    $needsReboot = $false
    try {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startingOfficeRepair')
        Stop-ToolkitProcesses -ProcessNames @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.officeCacheCleaner')
        $cleanedCount = 0
        foreach ($cache in @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )) {
            if (Remove-ItemSafely -Path $cache -Recurse) { $cleanedCount++ }
        }
        if ($cleanedCount -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0DeletedCaches' -Args @($cleanedCount)) }
        $officeClient64 = "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
        $officeClient32 = "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
        $officeClient = if (Test-Path $officeClient64) { $officeClient64 } else { $officeClient32 }
        if (-not (Test-Path $officeClient)) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.officeclicktorunExeNotFoundOfficeMayNotBeInstalled')
            return
        }
        try {
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.launchQuickRepairOffline')
            $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.quickOfficeRepairOffline') -Command $officeClient `
                -Arguments "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=QuickRepair DisplayLevel=True" `
                -TimeoutSeconds 86400 -LogContextKey "Office-Repair-Quick"
            Set-OfficePostConfig
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.officeRepairComplete')
            $needsReboot = $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringQuickRepair0' -Args @($($_.Exception.Message)))
            try {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.attemptingFullRepairOnlineAsAFallback')
                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.completeOfficeRepairOnline') -Command $officeClient `
                    -Arguments "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True" `
                    -TimeoutSeconds 86400 -LogContextKey "Office-Repair-Full"
                Set-OfficePostConfig
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.officeRepairComplete')
                $needsReboot = $true
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorAlsoDuringOnlineRepair0' -Args @($($_.Exception.Message)))
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.criticalErrorRepairingOffice0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.criticalErrorInRepairOffice') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.officeRepairFinished')
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.repairOfficeSessionEnded')
    }
    if ($needsReboot) {
        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.repairCompleted') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
function Uninstall-Office {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "OfficeUninstall" -SubTitle (Get-SourceTextLoc 'script.Uninstall-Office')
    $tempDir = $AppConfig.Paths.OfficeTemp
    function Get-WindowsVersion {
        try {
            $buildNumber = [int](Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
            if ($buildNumber -ge 22631) { return "Windows11_23H2_Plus" }
            if ($buildNumber -ge 22000) { return "Windows11_22H2_Or_Older" }
            return "Windows10_Or_Older"
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.unableToDetectWindowsVersion0' -Args @($_))
            return "Unknown"
        }
    }
    function Remove-ItemsSilently {
        param([string[]]$Paths, [string]$ItemType = "folder")
        $removed = @()
        $failed  = @()
        foreach ($path in $Paths) {
            if (Test-Path $path) {
                if (Remove-ItemSafely -Path $path -Recurse) { $removed += $path }
                else { $failed += $path }
            }
        }
        return @{ Removed = $removed; Failed = $failed; Count = $removed.Count }
    }
    function Remove-OfficeDirectly {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startingOfficeDirectRemoval')
        try {
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.searchForOfficeInstallations')
            $officePackages = Get-Package -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*Microsoft Office*" -or $_.Name -like "*Microsoft 365*" -or $_.Name -like "*Office*" }
            if ($officePackages) {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.found0OfficePackages' -Args @($($officePackages.Count)))
                foreach ($package in $officePackages) {
                    try {
                        $null = Uninstall-Package -Name $package.Name -Force -ErrorAction Stop
                        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.removed02' -Args @($($package.Name)))
                    }
                    catch {}
                }
            }
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.searchTheRegistry')
            foreach ($keyPath in @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )) {
                try {
                    $items = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue |
                        Where-Object { $_.DisplayName -like "*Office*" -or $_.DisplayName -like "*Microsoft 365*" }
                    foreach ($item in $items) {
                        if ($item.UninstallString -and $item.UninstallString -match "msiexec") {
                            try {
                                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.removal0' -Args @($($item.DisplayName))) -Command 'msiexec.exe' `
                                    -Arguments @('/x', $item.PSChildName, '/qn', '/norestart') -TimeoutSeconds 1800 `
                                    -LogContextKey "Office-Uninstall-MSI-$($item.PSChildName)"
                            }
                            catch {}
                        }
                    }
                }
                catch {}
            }
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.stoppingOfficeServices')
            $stoppedServices = 0
            foreach ($serviceName in @('ClickToRunSvc', 'OfficeSvc', 'OSE')) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    try {
                        Stop-Service  -Name $serviceName -Force -ErrorAction Stop
                        Set-Service   -Name $serviceName -StartupType Disabled -ErrorAction Stop
                        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.serviceStopped0' -Args @($serviceName))
                        $stoppedServices++
                    }
                    catch {}
                }
            }
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.officeFolderCleaning')
            $folderResult = Remove-ItemsSilently -Paths @(
                "$env:ProgramFiles\Microsoft Office",
                "${env:ProgramFiles(x86)}\Microsoft Office",
                "$env:ProgramFiles\Microsoft Office 15",
                "${env:ProgramFiles(x86)}\Microsoft Office 15",
                "$env:ProgramFiles\Microsoft Office 16",
                "${env:ProgramFiles(x86)}\Microsoft Office 16",
                "$env:ProgramData\Microsoft\Office",
                "$env:LOCALAPPDATA\Microsoft\Office",
                "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun",
                "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun"
            ) -ItemType "folder"
            if ($folderResult.Count -gt 0)        { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0OfficeFoldersRemoved' -Args @($($folderResult.Count))) }
            if ($folderResult.Failed.Count -gt 0)  { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.unableToRemove0FoldersMayBeInUse' -Args @($($folderResult.Failed.Count))) }
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.officeRegistryCleaner')
            $regResult = Remove-ItemsSilently -Paths @(
                "HKCU:\Software\Microsoft\Office",
                "HKLM:\SOFTWARE\Microsoft\Office",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office",
                "HKCU:\Software\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun"
            ) -ItemType "registry key"
            if ($regResult.Count -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0OfficeRegistryKeysRemoved' -Args @($($regResult.Count))) }
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.cleaningScheduledTasks')
            $tasksRemoved = 0
            try {
                $officeTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*Office*" }
                foreach ($task in $officeTasks) {
                    try { Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop; $tasksRemoved++ }
                    catch {}
                }
                if ($tasksRemoved -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0OfficeTasksRemoved' -Args @($tasksRemoved)) }
            }
            catch {}
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.removingOfficeLinks')
            $shortcutsRemoved = 0
            foreach ($desktopPath in @(
                $AppConfig.Paths.Desktop,
                "$env:PUBLIC\Desktop",
                "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs"
            )) {
                if (Test-Path $desktopPath) {
                    foreach ($shortcut in @(
                        "Microsoft Word*.lnk", "Microsoft Excel*.lnk", "Microsoft PowerPoint*.lnk",
                        "Microsoft Outlook*.lnk", "Microsoft OneNote*.lnk", "Microsoft Access*.lnk",
                        "Office*.lnk", "Word*.lnk", "Excel*.lnk", "PowerPoint*.lnk", "Outlook*.lnk"
                    )) {
                        foreach ($file in (Get-ChildItem -Path $desktopPath -Filter $shortcut -Recurse -ErrorAction SilentlyContinue)) {
                            if (Remove-ItemSafely -Path $file.FullName) { $shortcutsRemoved++ }
                        }
                    }
                }
            }
            if ($shortcutsRemoved -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0OfficeLinksRemoved' -Args @($shortcutsRemoved)) }
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.officeResidueCleaning')
            $null = Remove-ItemsSilently -Paths @(
                "$env:LOCALAPPDATA\Microsoft\OneDrive",
                "$env:APPDATA\Microsoft\OneDrive",
                "$env:TEMP\Office*",
                "$env:TEMP\MSO*"
            ) -ItemType "residuo"
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.directRemovalCompleted')
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.summary0Folders1RegistryKeys2Links3TasksRemoved' -Args @($($folderResult.Count), $($regResult.Count), $shortcutsRemoved, $tasksRemoved))
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorWhileDirectlyRemovingOffice0' -Args @($($_.Exception.Message)))
            return $false
        }
    }
    function Start-OfficeUninstallWithGetHelp {
        try {
            if (-not (Test-Path $tempDir)) { $null = New-Item -ItemType Directory -Path $tempDir -Force }
            $getHelpZipPath = Join-Path $tempDir 'GetHelp.zip'
            if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.GetHelpInstaller -OutputPath $getHelpZipPath -Description 'Microsoft Get Help')) {
                return $false
            }
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extractionGetHelp')
            try {
                Expand-Archive -Path $getHelpZipPath -DestinationPath $tempDir -Force
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extractionCompleted')
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorExtractingArchiveGetHelp0' -Args @($($_.Exception.Message)))
                return $false
            }
            $getHelpExe = Get-ChildItem -Path $tempDir -Filter "GetHelpCmd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $getHelpExe) {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.gethelpcmdExeNotFound')
                return $false
            }
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.removalViaGetHelp')
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.thisOperationMayTakeAFewMinutes')
            try {
                $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.removingOfficeUsingGetHelp') -Command $getHelpExe.FullName `
                    -Arguments '-S OfficeScrubScenario -AcceptEula' `
                    -TimeoutSeconds 86400 -LogContextKey "Office-Uninstall-GetHelp"
                $outputStr    = $result.StdOut + $result.StdErr
                $isInvalidArgs = $outputStr -match "Error: Invalid command line arguments" -or $outputStr -match "Usage: GetHelpCmd\.exe"
                if ($result.ExitCode -eq 0 -and -not $isInvalidArgs) {
                    $blockingProcesses = @('Setup', 'GetHelpCmd', 'OfficeClickToRun', 'Integrator', 'OfficeScrub', 'cscript')
                    $waitStart         = Get-Date
                    Start-Sleep -Seconds 12
                    if (Get-Process -Name $blockingProcesses -ErrorAction SilentlyContinue) {
                        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.getHelpStartedTheRemovalInAnExternalWindowWaitingForCompletion')
                        $spinnerIndex = 0
                        while ((Get-Process -Name $blockingProcesses -ErrorAction SilentlyContinue) -and ((Get-Date) - $waitStart).TotalSeconds -lt 2700) {
                            $elapsed = [math]::Round(((Get-Date) - $waitStart).TotalSeconds, 1)
                            $spinner = if ($Global:Spinners) { $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length] } else { '' }
                            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.removingOffice') -Status (Get-SourceTextLoc 'toolText.inProgress0Seconds' -Args @($elapsed)) -Percent 90 -Icon '⏳' -Spinner $spinner
                            Start-Sleep -Milliseconds 500
                        }
                        Clear-ProgressLine
                    }
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.getHelpCompletedSuccessfully')
                    return $true
                }
                else {
                    $reason = if ($isInvalidArgs) { 'Parameters not supported by the tool version' } else { "Exit code: $($result.ExitCode)" }
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.getHelpFailed0AttemptedAlternativeMethod' -Args @($reason))
                    return Remove-OfficeDirectly
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorRunningGetHelp0SwitchingToAlternativeMethod' -Args @($($_.Exception.Message)))
                return Remove-OfficeDirectly
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorDuringGetHelpProcess0' -Args @($($_.Exception.Message)))
            return $false
        }
        finally {
            Remove-ItemSafely -Path $tempDir -Recurse
        }
    }
    $needsReboot = $false
    try {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.startingCompleteMicrosoftOfficeRemoval')
        Stop-ToolkitProcesses -ProcessNames @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.windowsVersionDetection')
        $windowsVersion = Get-WindowsVersion
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.versionDetected0' -Args @($windowsVersion))
        $success = switch ($windowsVersion) {
            'Windows11_23H2_Plus' {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.usingGetHelpMethodForWindows1123h2')
                Start-OfficeUninstallWithGetHelp
            }
            default {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.usingDirectRemovalForWindows1122h2OrEarlier')
                Remove-OfficeDirectly
            }
        }
        $removalProgressText = Get-SourceTextLoc 'sourceText.removal'
        Write-Progress -Activity $removalProgressText -Completed -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Host ""
        if ($success) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.officeRemovalComplete')
            $needsReboot = $true
        }
        else {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.removalNotCompleted')
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.youCanTryAnAlternativeMethodOrManualRemoval')
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.criticalErrorWhileRemovingOffice0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.criticalErrorInUninstallOffice') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.finalCleaning')
        Remove-ItemSafely -Path $tempDir -Recurse
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.officeUninstallFinished')
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.uninstallOfficeSessionEnded')
    }
    if ($needsReboot) {
        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.removalCompleted') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
function AutoVideoDriverInstall {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "AutoVideoDriverInstall" -SubTitle (Get-SourceTextLoc 'script.AutoVideoDriverInstall')
    $desktopPath = $AppConfig.Paths.Desktop
    function Set-BlockWindowsUpdateDrivers {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.blockingAutomaticDriversFromWindowsUpdate')
        try {
            Set-RegistryValue -Path $AppConfig.Registry.WindowsUpdatePolicies -Name "ExcludeWUDriversInQualityUpdate" -Value 1
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.driverWuLockSet')
            $gpupdateResult = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.groupPolicyUpdateMayTake12Minutes') -Command 'gpupdate.exe' -Arguments '/force' -LogContextKey "Video-GPUpdate" -TimeoutSeconds 180
            if ($gpupdateResult -and $gpupdateResult.ExitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.updatedGroupPolicy')
            }
            elseif ($gpupdateResult) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.gpupdateCompletedWithCode0IContinueAnyway' -Args @($($gpupdateResult.ExitCode)))
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.gpupdateDidNotRespondIContinueAnyway')
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.driverWuBlockError0IContinueAnyway' -Args @($($_.Exception.Message)))
        }
    }
    try {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startingAutomaticVideoDriverInstallation')
        Set-BlockWindowsUpdateDrivers
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.detectingGpuConfiguration')
        $gpuAnalysis = VcardAnalizer
        $gpuManufacturer = $gpuAnalysis.PrimaryManufacturer
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.gpuDetected0' -Args @($gpuManufacturer))
        $stableDownloadDone = $false
        if ($gpuAnalysis.Matches.Count -gt 0) {
            foreach ($match in $gpuAnalysis.Matches) {
                if ([string]::IsNullOrWhiteSpace($match.DownloadUrl)) { continue }
                $targetName = if (-not [string]::IsNullOrWhiteSpace($match.FileName)) { $match.FileName } else { "$($match.Key).exe" }
                $targetPath = Join-Path $desktopPath $targetName
                $displayName = if (-not [string]::IsNullOrWhiteSpace($match.DisplayName)) { $match.DisplayName } else { $match.Key }
                if (Invoke-ToolkitDownload -Uri $match.DownloadUrl -OutputPath $targetPath -Description $displayName) {
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.stableDriverDownloadedToDesktop0' -Args @($displayName))
                    $stableDownloadDone = $true
                }
            }
        }
        if (-not $stableDownloadDone) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.noKnownStableDriversFoundIUseAutodetectFallback')
            switch ($gpuManufacturer) {
                'AMD' {
                    $amdPath = Join-Path $desktopPath "AMD-Autodetect.exe"
                    if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.AMDInstaller -OutputPath $amdPath -Description "AMD Auto-Detect Tool")) {
                        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToDownloadAmdInstallerAnnulment')
                        return
                    }
                }
                'NVIDIA' {
                    $nvidiaPath = Join-Path $desktopPath "NVCleanstall_1.19.0.exe"
                    if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.NVCleanstall -OutputPath $nvidiaPath -Description "NVCleanstall")) {
                        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToDownloadNvcleanstallAnnulment')
                        return
                    }
                }
                'Intel' {
                    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.intelGpuDownloadDriversManuallyFromIntelIfNecessary')
                }
                default {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.gpuNotDetectedDriverNotAvailableForAutomaticInstallation')
                }
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringDriverInstallation0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.errorInAutovideodriverinstall') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.autoVideoDriverInstallFinished')
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.autovideodriverinstallSessionEnded')
    }
}
function VideoDriverReinstall {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "VideoDriverReinstall" -SubTitle (Get-SourceTextLoc 'script.VideoDriverReinstall')
    $driverToolsPath = $AppConfig.Paths.Drivers
    $desktopPath     = $AppConfig.Paths.Desktop
    function Set-BlockWindowsUpdateDrivers {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.blockingAutomaticDriversFromWindowsUpdate')
        try {
            Set-RegistryValue -Path $AppConfig.Registry.WindowsUpdatePolicies -Name "ExcludeWUDriversInQualityUpdate" -Value 1
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.driverWuLockSet')
            $gpupdateResult = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.groupPolicyUpdateMayTake12Minutes') -Command 'gpupdate.exe' -Arguments '/force' -LogContextKey "Video-GPUpdate" -TimeoutSeconds 180
            if ($gpupdateResult -and $gpupdateResult.ExitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.updatedGroupPolicy')
            }
            elseif ($gpupdateResult) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.gpupdateCompletedWithCode0IContinueAnyway' -Args @($($gpupdateResult.ExitCode)))
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.gpupdateDidNotRespondIContinueAnyway')
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.driverWuBlockError0IContinueAnyway' -Args @($($_.Exception.Message)))
        }
    }
    $needsReboot = $false
    try {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.startingVideoDriverReinstallationRepairProcedure')
        Set-BlockWindowsUpdateDrivers
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.preparingToDownloadTheNecessaryTools')
        $dduZipPath = Join-Path $driverToolsPath "DDU.zip"
        if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.DDUZip -OutputPath $dduZipPath -Description 'DDU (Display Driver Uninstaller)')) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToDownloadDduAnnulment')
            return
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extractingDduToDesktop')
        try {
            Expand-Archive -Path $dduZipPath -DestinationPath $desktopPath -Force
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.dduExtractedToDesktop')
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.dduExtractionError0' -Args @($($_.Exception.Message)))
            return
        }
        $gpuAnalysis = VcardAnalizer
        $gpuManufacturer = $gpuAnalysis.PrimaryManufacturer
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.gpuDetected0' -Args @($gpuManufacturer))
        $stableDownloadDone = $false
        if ($gpuAnalysis.Matches.Count -gt 0) {
            foreach ($match in $gpuAnalysis.Matches) {
                if ([string]::IsNullOrWhiteSpace($match.DownloadUrl)) { continue }
                $targetName = if (-not [string]::IsNullOrWhiteSpace($match.FileName)) { $match.FileName } else { "$($match.Key).exe" }
                $targetPath = Join-Path $desktopPath $targetName
                $displayName = if (-not [string]::IsNullOrWhiteSpace($match.DisplayName)) { $match.DisplayName } else { $match.Key }
                if (Invoke-ToolkitDownload -Uri $match.DownloadUrl -OutputPath $targetPath -Description $displayName) {
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.stableDriverDownloadedToDesktop0' -Args @($displayName))
                    $stableDownloadDone = $true
                }
            }
        }
        if (-not $stableDownloadDone) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.noKnownStableDriversFoundIUseAutodetectFallback')
            switch ($gpuManufacturer) {
                'AMD' {
                    $amdPath = Join-Path $desktopPath "AMD-Autodetect.exe"
                    if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.AMDInstaller -OutputPath $amdPath -Description "AMD Auto-Detect Tool")) {
                        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToDownloadAmdInstallerAnnulment')
                        return
                    }
                }
                'NVIDIA' {
                    $nvidiaPath = Join-Path $desktopPath "NVCleanstall_1.19.0.exe"
                    if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.NVCleanstall -OutputPath $nvidiaPath -Description "NVCleanstall")) {
                        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToDownloadNvcleanstallAnnulment')
                        return
                    }
                }
                'Intel' {
                    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.intelGpuDownloadDriversManuallyFromIntelIfNecessary')
                }
                default {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.gpuNotDetectedOnlyDduWillBePlacedOnTheDesktop')
                }
            }
        }
        $batchPath = Join-Path $desktopPath "Switch to Normal Mode.bat"
        try {
            Set-Content -Path $batchPath -Value 'bcdedit /deletevalue {current} safeboot' -Encoding ASCII
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.batchSwitchToNormalModeBatCreatedOnDesktop')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.failedToCreateSafeModeBatch0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.warningTheSystemWillRebootIntoSafeMode')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.inSafeModeRunDduToCleanTheDriversThenReinstallWithTheDesktopInstallerFinallyUseBatchToRetu')
        try {
            $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.safeModeConfigurationBcdedit') -Command 'bcdedit.exe' `
                -Arguments '/set {current} safeboot minimal' -LogContextKey "Video-BCDEdit"
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.safeModeConfiguredForNextBoot')
            $needsReboot = $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.safeModeConfigurationError0' -Args @($($_.Exception.Message)))
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.criticalErrorDuringDriverReinstallation0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.errorInVideodriverreinstall') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.videoDriverReinstallFinished')
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.videodriverreinstallSessionEnded')
    }
    if ($needsReboot) {
        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.restartInSafeModeForDdu') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
function GamingToolkit {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateRange(0, 300)]
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "GamingToolkit" -SubTitle (Get-SourceTextLoc 'script.GamingToolkit')
    $timeout = 3600
    function Test-WingetPackageAvailable([string]$PackageId) {
        try {
            $searchResult = winget search --id $PackageId --accept-source-agreements 2>&1
            $outputStr = $searchResult -join ' '
            if ($outputStr -match [regex]::Escape($PackageId)) {
                return $true
            }
            $listResult = winget list --id $PackageId --accept-source-agreements 2>&1
            $listStr = $listResult -join ' '
            if ($listStr -match [regex]::Escape($PackageId)) {
                return $true
            }
            return $false
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.packetVerificationError01' -Args @($PackageId, $errorMessage))
            return $false
        }
    }
    function Invoke-WingetInstallWithProgress([string]$PackageId, [string]$DisplayName, [int]$Step, [int]$Total) {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.01Installation2' -Args @($Step, $Total, $DisplayName))
        $outFile = "$env:TEMP\winget_$PackageId.log"
        $errFile = "$env:TEMP\winget_err_$PackageId.log"
        try {
            $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.installation0' -Args @($DisplayName)) -Command 'winget' -Arguments @('install', '--id', $PackageId, '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements') -TimeoutSeconds $timeout -LogContextKey "Gaming-Install-$PackageId"
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)
            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.installed0' -Args @($DisplayName))
                return @{ Success = $true; ExitCode = $exitCode }
            }
            else {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.installationError0Code1' -Args @($DisplayName, $exitCode))
                return @{ Success = $false; ExitCode = $exitCode }
            }
        }
        catch {
            Clear-ProgressLine
            Clear-ProgressLine
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.exception01' -Args @($DisplayName, $($_.Exception.Message)))
            return @{ Success = $false }
        }
        finally {
            Remove-ItemSafely -Path $outFile
            Remove-ItemSafely -Path $errFile
        }
    }
    Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.preparation') -Timer -Action { Start-Sleep 5 } -TimeoutSeconds 5
    Show-Header -SubTitle (Get-SourceTextLoc 'script.GamingToolkit')
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.checkWingetAvailability')
    Update-EnvironmentPath
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.wingetNotAvailableStartingAutomaticRecovery')
        $resetOk = Reset-Winget
        Update-EnvironmentPath
        if (-not $resetOk -or -not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.wingetRestoreFailedUnableToProceedWithGamingToolkit')
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.pressAnyKeyToContinue')
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.wingetAvailable')
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.wingetSourcesUpdate')
    try {
        winget source update *>$null
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.updatedSources')
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.sourceUpdateError0' -Args @($($_.Exception.Message)))
    }
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.enablingNetframework')
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs, NetFx3 -NoRestart -All -ErrorAction Stop *>$null
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.netframeworkEnabled')
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorEnablingNetframework0' -Args @($($_.Exception.Message)))
    }
    $runtimes = @(
        "Microsoft.DotNet.DesktopRuntime.3_1",
        "Microsoft.DotNet.DesktopRuntime.5",
        "Microsoft.DotNet.DesktopRuntime.6",
        "Microsoft.DotNet.DesktopRuntime.7",
        "Microsoft.DotNet.DesktopRuntime.8",
        "Microsoft.DotNet.DesktopRuntime.9",
        "Microsoft.DotNet.DesktopRuntime.10",
        "Microsoft.VCRedist.2010.x64",
        "Microsoft.VCRedist.2010.x86",
        "Microsoft.VCRedist.2012.x64",
        "Microsoft.VCRedist.2012.x86",
        "Microsoft.VCRedist.2013.x64",
        "Microsoft.VCRedist.2013.x86",
        "Microsoft.VCLibs.Desktop.14",
        "Microsoft.VCRedist.2015+.x64",
        "Microsoft.VCRedist.2015+.x86"
    )
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.installingNetRuntimeAndVcredist')
    for ($runtimeIndex = 0; $runtimeIndex -lt $runtimes.Count; $runtimeIndex++) {
        Invoke-WingetInstallWithProgress $runtimes[$runtimeIndex] $runtimes[$runtimeIndex] ($runtimeIndex + 1) $runtimes.Count *>$null
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.runtimesCompleted')
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.directxInstallation')
    $dxDir = Join-Path $AppConfig.Paths.LocalAppData "WinToolkit\Directx"
    $dxPath = "$dxDir\dxwebsetup.exe"
    if (-not (Test-Path $dxDir)) { New-Item -Path $dxDir -ItemType Directory -Force *>$null }
    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.DirectXWebSetup -OutFile $dxPath -ErrorAction Stop
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.directxDownloaded')
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.directxInstallation') -Command $dxPath -TimeoutSeconds $timeout -LogContextKey "Gaming-DirectX"
        Clear-ProgressLine
        Clear-ProgressLine
        if ($null -eq $result) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.directxProcessDidNotStartCorrectly')
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.directxTimeout')
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 3010, 5100, -9, 9, -1442840576)
            $messageType = if ($exitCode -in $successCodes) { 'Success' } else { 'Error' }
            $messageText = if ($exitCode -in $successCodes) {
                Get-SourceTextLoc 'toolText.extra.directxInstalledCode0' -Args @($exitCode)
            }
            else {
                Get-SourceTextLoc 'toolText.extra.directxError0' -Args @($exitCode)
            }
            Write-StyledMessage -Type $messageType -Text $messageText
        }
    }
    catch {
        Clear-ProgressLine
        Clear-ProgressLine
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringDirectxInstallation0' -Args @($($_.Exception.Message)))
    }
    $gameClients = @(
        "Amazon.Games", "GOG.Galaxy", "EpicGames.EpicGamesLauncher",
        "ElectronicArts.EADesktop", "Playnite.Playnite", "Valve.Steam",
        "Ubisoft.Connect"
    )
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.gameClientInstallation')
    for ($clientIndex = 0; $clientIndex -lt $gameClients.Count; $clientIndex++) {
        Invoke-WingetInstallWithProgress $gameClients[$clientIndex] $gameClients[$clientIndex] ($clientIndex + 1) $gameClients.Count *>$null
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.clientsInstalled')
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.reinstallingXboxGameBarApp')
    $xboxPackages = @("9NZKPSTSNW4P", "9MV0B5HZVK9Z")
    foreach ($pkg in $xboxPackages) {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.reinstallation0' -Args @($pkg))
        $outFile = "$env:TEMP\winget_$pkg.log"
        $errFile = "$env:TEMP\winget_err_$pkg.log"
        try {
            $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.reinstallation0' -Args @($pkg)) -Process -Action {
                $procParams = @{
                    FilePath               = 'winget'
                    ArgumentList           = @('install', '--id', $pkg, '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements', '--force')
                    PassThru               = $true
                    NoNewWindow            = $true
                    RedirectStandardOutput = $outFile
                    RedirectStandardError  = $errFile
                }
                Start-Process @procParams
            } -TimeoutSeconds $timeout -UpdateInterval 700
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)
            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.reinstalled0' -Args @($pkg))
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Code1' -Args @(${pkg}, $exitCode))
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.error01' -Args @($pkg, $($_.Exception.Message)))
        }
        finally {
            Remove-ItemSafely -Path $outFile
            Remove-ItemSafely -Path $errFile
        }
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.xboxReinstalled')
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.installingBattleNet')
    $bnPath = "$env:TEMP\Battle.net-Setup.exe"
    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.BattleNetInstaller -OutFile $bnPath -ErrorAction Stop
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.battleNetDownloaded')
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.installingBattleNet') -Command $bnPath -Arguments '--quiet' -TimeoutSeconds $timeout -LogContextKey "Gaming-BattleNet"
        Clear-ProgressLine
        Clear-ProgressLine
        if ($null -eq $result) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.battleNetProcessDidNotStartProperly')
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.battleNetTimedOut')
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $messageType = if ($exitCode -in @(0, 3010)) { 'Success' } else { 'Warning' }
            $messageText = if ($exitCode -in @(0, 3010)) {
                Get-SourceTextLoc 'uiText.battleNetInstalled'
            }
            else {
                Get-SourceTextLoc 'toolText.extra.battleNetCode0' -Args @($exitCode)
            }
            Write-StyledMessage -Type $messageType -Text $messageText
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.pressAnyKeyToContinue')
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    catch {
        Clear-ProgressLine
        Clear-ProgressLine
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorInstallingBattleNet0' -Args @($($_.Exception.Message)))
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.pressAnyKeyToContinue')
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.autostartCleaner')
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    @('Steam', 'Battle.net', 'GOG Galaxy', 'GogGalaxy', 'GalaxyClient') | ForEach-Object {
        if (Get-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.removed0' -Args @($_))
        }
    }
    $startupPath = $AppConfig.Paths.Startup
    @('Steam.lnk', 'Battle.net.lnk', 'GOG Galaxy.lnk') | ForEach-Object {
        $path = Join-Path $startupPath $_
        Remove-ItemSafely -Path $path
        if (-not (Test-Path $path)) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.removed0' -Args @($_))
        }
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.cleaningCompleted')
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.energyProfileConfiguration')
    $ultimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $planName = "WinToolkit Gaming Performance"
    $guid = $null
    $existingPlan = powercfg -list | Select-String -Pattern $planName -ErrorAction SilentlyContinue
    if ($existingPlan) {
        $guid = ($existingPlan.Line -split '\s+')[3]
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.existingPlanFound')
    }
    else {
        try {
            $output = powercfg /duplicatescheme $ultimateGUID | Out-String
            if ($output -match "\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b") {
                $guid = $matches[0]
                powercfg /changename $guid $planName 'Optimized for Gaming by WinToolkit' *>$null
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.planCreated')
            }
            else {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.planCreationError')
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringEnergyPlanDuplication0' -Args @($($_.Exception.Message)))
        }
    }
    if ($guid) {
        try {
            powercfg -setactive $guid *>$null
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.planActivated')
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringEnergyPlanActivation0' -Args @($($_.Exception.Message)))
        }
    }
    else {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToActivatePlan')
    }
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.doNotDisturbActivation')
    try {
        Set-ItemProperty -Path $AppConfig.Registry.FocusAssist -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0 -Force
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.doNotDisturbActive')
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringFocusAssistConfiguration0' -Args @($($_.Exception.Message)))
    }
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.gamingToolkitCompleted')
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.systemOptimizedForGaming')
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)
    Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.rebootRequired') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
}
function WinExportLog {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "WinExportLog" -SubTitle (Get-SourceTextLoc 'script.WinExportLog')
    $logSourcePath = $AppConfig.Paths.Logs
    $desktopPath   = $AppConfig.Paths.Desktop
    $timestamp     = Get-Date -Format "yyyyMMdd_HHmmss"
    $zipFileName   = "WinToolkit_Logs_$timestamp.zip"
    $zipFilePath   = Join-Path $desktopPath $zipFileName
    $tempFolder    = Join-Path $AppConfig.Paths.TempFolder "WinToolkit_Logs_Temp_$timestamp"
    try {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.checkPresenceOfLogFolder')
        if (-not (Test-Path $logSourcePath -PathType Container)) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.theLogsFolder0WasNotFoundUnableToExport' -Args @($logSourcePath))
            return
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.compressingLogsSomeFilesInUseMayBeIgnored')
        Remove-ItemSafely -Path $tempFolder -Recurse
        New-Item -ItemType Directory -Path $tempFolder -Force *>$null
        $filesCopied  = 0
        $filesSkipped = 0
        try {
            Get-ChildItem -Path $logSourcePath -File | ForEach-Object {
                try {
                    Copy-Item $_.FullName -Destination $tempFolder -Force -ErrorAction Stop
                    $filesCopied++
                }
                catch {
                    $filesSkipped++
            Write-Debug (Get-SourceTextLoc 'uiText.fileIgnored01' -Args @($_.Name, $_.Exception.Message))
                }
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorCopyingFiles0' -Args @($($_.Exception.Message)))
        }
        if ($filesCopied -gt 0) {
            Compress-Archive -Path "$tempFolder\*" -DestinationPath $zipFilePath -Force -ErrorAction Stop
            if (Test-Path $zipFilePath) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.logsCompressedSuccessfullySavedFile0OnDesktop' -Args @($zipFileName))
                if ($filesSkipped -gt 0) {
                    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0FilesIgnoredBecauseTheyAreInUseOrNotAccessible' -Args @($filesSkipped))
                }
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.send0DesktopViaTelegramHttpsTMeMagnetarmanOrEmailMeMagnetarmanComForDiagnostics' -Args @($zipFileName))
            }
            else {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unknownErrorZipFileWasNotCreated')
            }
        }
        else {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.noLogFilesCopiedCheckPermissionsAndThatTheFilesExist')
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinExportLog" -Message (Get-SourceTextLoc 'toolText.extra.errorCompressingLogs')
    }
    finally {
        Remove-ItemSafely -Path $tempFolder -Recurse
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.winexportlogSessionEnded')
    }
}
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
if (-not $ImportOnly) {
    Initialize-ToolkitPaths
    WinOSCheck
    Test-WindowsUpdateStatus
}
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
        $rawInput = Microsoft.PowerShell.Utility\Read-Host (Get-SourceTextLoc 'menu.multiPrompt')
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
    Write-Verbose "═══════════════════════════════════════════════════════════"
    Write-Verbose ("  " + (Get-SourceTextLoc 'uiText.wintoolkitLoadedInLibraryMode'))
    Write-Verbose ("  " + (Get-SourceTextLoc 'uiText.functionsAvailableTuiMenuSuppressed'))
    Write-Verbose ("  💎 " + (Get-SourceTextLoc 'sourceText.version') + ": $ToolkitVersion")
    Write-Verbose "═══════════════════════════════════════════════════════════"
    $Global:menuStructure = $menuStructure
}
