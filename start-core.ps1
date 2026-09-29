[CmdletBinding()]
param(
    [string]$Language = $(if ($env:WTOOLKIT_LANGUAGE) { $env:WTOOLKIT_LANGUAGE } else { 'Auto' })
)
Set-StrictMode -Version Latest
$script:Branch = 'Dev'
$ToolkitVersion = "Work In Progress"
$GitHubRepoRawBase = @{
    Dev  = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev"
    main = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main"
}
$GitHubRepoBase = @{
    Dev  = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev"
    main = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/main"
}
$script:RepoRawBase = $GitHubRepoRawBase[$script:Branch]
$script:RepoBase = $GitHubRepoBase[$script:Branch]
$script:AppConfig = @{
    Branch           = $script:Branch
    ToolkitVersion   = $ToolkitVersion
    MsgStyles        = @{
        Success  = @{ Icon = '✅'; Color = 'Green' }
        Warning  = @{ Icon = '⚠️'; Color = 'Yellow' }
        Error    = @{ Icon = '❌'; Color = 'Red' }
        Info     = @{ Icon = '💎'; Color = 'Cyan' }
        Progress = @{ Icon = '⏳'; Color = 'DarkCyan' }
    }
    Header           = @{
        Title   = "Toolkit Starter By MagnetarMan"
        Version = "Version $ToolkitVersion"
    }
    URLs             = @{
        WingetMSIX        = "https://aka.ms/getwinget"
        VCRedistTemplate  = "https://aka.ms/vs/17/release/vc_redist.{0}.exe"
        WingetCliRelease  = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        GitRelease        = "https://api.github.com/repos/git-for-windows/git/releases/latest"
        PowerShellRelease = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        TerminalRelease   = "https://api.github.com/repos/microsoft/terminal/releases/latest"
        WebInstaller      = "https://magnetarman.com/WinToolkit-Dev"
    }
    Paths            = @{
        Logs          = "$env:LOCALAPPDATA\WinToolkit\logs"
        WinToolkitDir = "$env:LOCALAPPDATA\WinToolkit"
        Languages     = "$env:LOCALAPPDATA\WinToolkit\languages"
        Temp          = "$env:TEMP\WinToolkitSetup"
        Packages      = "$env:LOCALAPPDATA\Packages"
        Desktop       = $null
        MyDocuments   = $null
        wtExe         = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
        wtDir         = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    }
    UserScope       = @{
        EnvUser           = 'WTOOLKIT_ORIGINAL_USER'
        EnvUserProfile    = 'WTOOLKIT_ORIGINAL_USERPROFILE'
        EnvDesktop        = 'WTOOLKIT_ORIGINAL_DESKTOP'
        EnvMyDocuments    = 'WTOOLKIT_ORIGINAL_MYDOCUMENTS'
        PowerShellProfileFolder = 'PowerShell'
        ThemesFolderName        = 'Themes'
        ProfileFileName         = 'Microsoft.PowerShell_profile.ps1'
        ThemeFileName           = 'atomic.omp.json'
        MinThemeFileBytes = 512
    }
    Registry         = @{
        TerminalStartup = "HKCU:\Console\%%Startup"
    }
    WindowsTerminal  = @{
        DelegationTerminalClsid = "{E12F0936-0E6F-548E-A9F6-B20C69A27D17}"
        DelegationConsoleClsid  = "{B23D10C0-31E3-401A-97EF-4BB30B62E10B}"
    }
    UpdateServices   = @('wuauserv', 'bits')
    Timeouts         = @{
        WingetProbe  = 30
        Winget       = 120
        Installer    = 300
        VCRedist     = 600
        Appx         = 120
        Condition    = 15
    }
    Winget          = @{
        RpcFailureExitCode = -2147012859
        AlreadyInstalledExitCodes = @(-1978335135, -1978335189)
    }
    DownloadSignatures = @{
        vcRedist    = @('Microsoft Corporation', 'Microsoft Windows')
        git         = @('Git for Windows')
        wingetMsix  = @('Microsoft Corporation', 'Microsoft Windows')
        terminalMsix = @('Microsoft Corporation', 'Microsoft Windows')
    }
    WindowsAppsPackageName = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe'
    Defender          = @{
        MaxConfirmations = 3
    }
    WingetProcesses  = @(
        'WinStore.App',
        'AppInstaller',
        'Microsoft.WindowsStore',
        'Microsoft.DesktopAppInstaller',
        'winget',
        'WindowsPackageManagerServer'
    )
    HostsFilePath     = "$env:SystemRoot\System32\drivers\etc\hosts"
    MinProfileBytes   = 256
    MaxCapturedOutputChars = 65536
    Layout           = @{
        Width = 65
    }
}
$script:AppConfig.URLs.StartScript = "$script:RepoRawBase/start.ps1"
$script:AppConfig.URLs.PowerShellProfile = "$script:RepoBase/assets/Microsoft.PowerShell_profile.ps1"
$script:AppConfig.URLs.WindowsTerminalSettings = "$script:RepoBase/assets/settings.json"
$script:AppConfig.URLs.ToolkitIcon = "$script:RepoRawBase/images/WinToolkit.ico"
$script:AppConfig.URLs.OhMyPoshThemeUrls = @(
    "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json",
    "https://github.com/JanDeDobbeleer/oh-my-posh/raw/refs/heads/main/themes/atomic.omp.json",
    "https://cdn.jsdelivr.net/gh/JanDeDobbeleer/oh-my-posh@main/themes/atomic.omp.json"
)
$script:AppConfig.URLs.LanguagesRawUrl = "$script:RepoBase/languages"
$script:AppConfig.URLs.LanguagesApiUrl = "https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=$script:Branch"
$script:EXITCODE_ACCESS_VIOLATION_SIGNED = -1073741819
$script:LNK_RUNAS_ADMIN_BYTE_OFFSET = 21
$script:LNK_RUNAS_ADMIN_BIT = 32
$script:MIN_ICON_FILE_BYTES = 1024
$script:State = @{
    LogFile      = $null
    Results      = [System.Collections.Generic.List[object]]::new()
    UserContext  = $null
    Text         = @{ Active = $null; Default = $null }
    Winget       = @{ Modern = $null; ProbedExe = $null }
    SourcesReset = $false
}
function Write-StyledMessage {
    param(
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Progress')]
        [string]$Type,
        [string]$Text
    )
    $style = $script:AppConfig.MsgStyles[$Type]
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color
    $logLevel = if ($Type -in @('Info', 'Progress')) { 'INFO' } else { $Type.ToUpperInvariant() }
    Write-ToolkitLog -Level $logLevel -Message $Text
}
function Stop-ToolkitTranscript {
    try {
        return (Stop-Transcript -ErrorAction Stop)
    }
    catch {
        if ($_.FullyQualifiedErrorId -eq 'InvalidOperation,Microsoft.PowerShell.Commands.StopTranscriptCommand' -and
            $_.Exception.InnerException -is [System.Management.Automation.PSInvalidOperationException]) {
            return $null
        }
        Write-ToolkitLog -Level 'WARNING' -Message "Stop-ToolkitTranscript: $($_.Exception.Message)"
        return $null
    }
}
function Start-ToolkitLog {
    param([string]$ToolName)
    $null = Stop-ToolkitTranscript
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = $script:AppConfig.Paths.Logs
    $null = Initialize-Directory -Path $logdir
    Get-ChildItem -Path $logdir -Filter '*.log' -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item -Force -ErrorAction SilentlyContinue
    $script:State.LogFile = "$logdir\${ToolName}_${dateTime}_$PID.log"
    Start-Transcript -Path "$logdir\${ToolName}_${dateTime}_$PID.transcript.log" -Append -Force | Out-Null
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $psVer = $PSVersionTable.PSVersion.ToString()
    $header = @"
[START LOG HEADER]
Start time     : $dateTime
ToolName       : $ToolName
OS             : $($os.Caption) $($os.Version)
PSVersion      : $psVer
ToolkitVersion : $($script:AppConfig.Header.Version)
[END LOG HEADER]
"@
    Add-Content -Path $script:State.LogFile -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue
}
function Write-ToolkitLog {
    param(
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',
        [string]$Message
    )
    if (-not $script:State.LogFile) { return }
    $ts = Get-Date -Format "HH:mm:ss"
    $clean = $Message -replace '^\s+', ''
    $clean = $clean -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
    $line = "[$ts] [$Level] $clean"
    Add-Content -Path $script:State.LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}
function Format-CenteredText {
    param(
        [string]$Text,
        [int]$Width = 80
    )
    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    return (" " * $padding) + $Text
}
function Show-Header {
    param(
        [string]$Title,
        [string]$Version
    )
    Clear-Host
    $width = $script:AppConfig.Layout.Width
    Write-Host ('═' * $width) -ForegroundColor Green
    @(
        '      __        __  _   _   _ ',
        '      \ \      / / | | | \ | |',
        '       \ \ /\ / /  | | |  \| |',
        '        \ V  V /   | | | |\  |',
        '         \_/\_/    |_| |_| \_|',
        '',
        $Title,
        $Version
    ) | ForEach-Object { Write-Host (Format-CenteredText -Text $_ -Width $width) -ForegroundColor White }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''
}
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
    return $script:AppConfig.Paths.Languages
}
function Invoke-SourceTextLanguagePreparation {
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
        $stagedFile = Join-Path $cultureDir "WinToolkit.psd1.$([guid]::NewGuid()).tmp"
        try {
            $remoteUrl = "$RemoteBaseUrl/$culture/WinToolkit.psd1"
            if (-not (Invoke-DownloadFile -Uri $remoteUrl -OutFile $stagedFile -Silent)) {
                throw "Unable to download the language file for '$culture'."
            }
            Move-Item -LiteralPath $stagedFile -Destination $localFile -Force -ErrorAction Stop
        }
        catch {
            Write-ToolkitLog -Level 'WARNING' -Message "Language file for '$culture' unavailable: $($_.Exception.Message)"
        }
        finally {
            Remove-PathQuietly -Path $stagedFile
        }
    }
    return $localDir
}
function Get-SourceTextAutoDetectedLanguage {
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
function Get-SystemArchitecture {
    try {
        $architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    }
    catch {
        $architecture = $env:PROCESSOR_ARCHITECTURE
    }
    switch -Regex ($architecture) {
        'Arm64|ARM64' { return 'ARM64' }
        'X86|x86' { return 'X86' }
        default { return 'X64' }
    }
}
function Update-EnvironmentPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
}
function Test-PathInEnvironment {
    param (
        [string]$PathToCheck,
        [string]$Scope = 'Both'
    )
    $targets = @()
    if ($Scope -in @('User', 'Both')) { $targets += 'User' }
    if ($Scope -in @('System', 'Both')) { $targets += 'Machine' }
    foreach ($target in $targets) {
        $value = [Environment]::GetEnvironmentVariable('PATH', $target)
        if ($value -and ($value -split ';').Contains($PathToCheck)) { return $true }
    }
    return $false
}
function Add-ToEnvironmentPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PathToAdd,
        [ValidateSet('User', 'System')]
        [string]$Scope
    )
    if (-not (Test-PathInEnvironment -PathToCheck $PathToAdd -Scope $Scope)) {
        $target = if ($Scope -eq 'System') { 'Machine' } else { 'User' }
        $currentPath = [Environment]::GetEnvironmentVariable('PATH', $target)
        $newPath = (@($currentPath, $PathToAdd) | Where-Object { $_ }) -join ';'
        [Environment]::SetEnvironmentVariable('PATH', $newPath, $target)
        if (-not ($env:PATH -split ';').Contains($PathToAdd)) {
            $env:PATH += ";$PathToAdd"
        }
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updatedPath0' -Args @($PathToAdd))
    }
}
function Repair-SystemClock {
    $changed = $false
    try {
        $service = Get-Service w32time -ErrorAction SilentlyContinue
        if (-not $service) {
            return New-StepResult -Success $false -Message 'The w32time service is not present on this system.'
        }
        if ($service.Status -eq 'Running') {
            return New-StepResult -Success $true -Message 'System clock already synchronized.'
        }
        Start-Service w32time -ErrorAction Stop | Out-Null
        w32tm /resync /force 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "w32tm resync failed with exit code $LASTEXITCODE." }
        $changed = $true
        Write-StyledMessage -Type Success -Text ("🕒 " + (Get-SourceTextLoc 'uiText.systemClockResynced'))
        return New-StepResult -Success $true -Changed $changed -Message 'System clock synchronized.'
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "System clock resync failed: $($_.Exception.Message)"
        return New-StepResult -Success $false -Changed $changed -Message $_.Exception.Message
    }
}
function Reset-SchannelSettings {
    param()
    $changed = $false
    try {
        $schannelPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL'
        if (-not (Test-Path $schannelPath)) { return New-StepResult -Success $true -Message 'SCHANNEL key not present.' }
        $tls12Path = Join-Path $schannelPath 'Protocols\TLS 1.2'
        if (Test-Path $tls12Path) {
            foreach ($mode in @('Client', 'Server')) {
                $modePath = Join-Path $tls12Path $mode
                if (Test-Path $modePath) {
                    $enabled = (Get-ItemProperty -Path $modePath -Name 'Enabled' -ErrorAction SilentlyContinue).Enabled
                    if ($enabled -eq 0) {
                        Set-ItemProperty -Path $modePath -Name 'Enabled' -Value 1 -Type DWord -Force
                        $changed = $true
                        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.schannelTls12ModeReactivated0' -Args @($mode))
                        Write-ToolkitLog -Level 'INFO' -Message "Re-enabled TLS 1.2 $mode"
                    }
                }
            }
        }
        $message = if ($changed) { 'SCHANNEL settings repaired.' } else { 'SCHANNEL settings already valid.' }
        return New-StepResult -Success $true -Changed $changed -Message $message
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "SCHANNEL reset failed: $($_.Exception.Message)"
        return New-StepResult -Success $false -Changed $changed -Message $_.Exception.Message
    }
}
function Reset-HostsFile {
    param()
    try {
        $hostsPath = $script:AppConfig.HostsFilePath
        if (-not (Test-Path $hostsPath)) { return New-StepResult -Success $true -Message 'Hosts file not present.' }
        $lines = Get-Content $hostsPath -ErrorAction SilentlyContinue
        if (-not $lines) { return New-StepResult -Success $true -Message 'Hosts file is empty.' }
        $blockedPattern = '(?i)microsoft\.com|storeedgefd|winget\.azureedge\.net'
        $keptLines = @($lines | Where-Object { $_ -notmatch $blockedPattern })
        $hasOverrides = $keptLines.Count -ne $lines.Count
        if (-not $hasOverrides) {
            return New-StepResult -Success $true -Message 'No blocked hosts overrides found.'
        }
        $backupDir = Initialize-Directory -Path $script:AppConfig.Paths.WinToolkitDir
        $backupPath = Join-Path $backupDir ("hosts.backup.{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Copy-Item -LiteralPath $hostsPath -Destination $backupPath -Force -ErrorAction Stop
        Set-Content -Path $hostsPath -Value $keptLines -Encoding ASCII -Force
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.hostsFileModifiedBackupSaved0' -Args @($backupPath))
        Write-ToolkitLog -Level 'INFO' -Message 'Hosts file reset: removed Microsoft/Store/Winget overrides'
        return New-StepResult -Success $true -Changed $true -Message "Hosts reset; backup: $backupPath"
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Hosts file reset failed: $($_.Exception.Message)"
        return New-StepResult -Success $false -Message $_.Exception.Message
    }
}
function Repair-HostsFileIfNeeded {
    $health = Get-WingetHealth
    if ($health.Runs -and $health.Reachable) {
        return New-StepResult -Success $true -Message 'WinGet sources are reachable, hosts file left untouched.'
    }
    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.hostsFileResetOnlyOnSourceFailure0')
    return Reset-HostsFile
}
function Request-DefenderPause {
    try {
        $defender = Get-MpComputerStatus -ErrorAction Stop
        if (-not $defender.RealTimeProtectionEnabled) { return $false }
    }
    catch {
        Write-ToolkitLog -Level 'DEBUG' -Message "Defender status unavailable: $($_.Exception.Message)"
        return $false
    }
    if ([Console]::IsInputRedirected) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.defenderActiveNonInteractive0')
        return $false
    }
    $maxAttempts = $script:AppConfig.Defender.MaxConfirmations
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.defenderActiveDisablePrompt0' -Args @($attempt, $maxAttempts))
        $null = Read-Host (Get-SourceTextLoc 'uiText.defenderPressEnterAfterDisabling0')
        try {
            $defender = Get-MpComputerStatus -ErrorAction Stop
            if (-not $defender.RealTimeProtectionEnabled) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.defenderDisabledContinuing0')
                return $true
            }
        }
        catch {
            Write-ToolkitLog -Level 'DEBUG' -Message "Defender status unavailable: $($_.Exception.Message)"
            break
        }
    }
    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.defenderStillActiveContinuing0')
    return $false
}
function Get-UpdateServicesStatusPath {
    return (Join-Path $script:AppConfig.Paths.WinToolkitDir 'update-services.status.txt')
}
function Write-UpdateServicesStatus {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Status
    )
    $statusPath = Get-UpdateServicesStatusPath
    if (-not (Test-Path -LiteralPath $script:AppConfig.Paths.WinToolkitDir)) {
        $null = New-Item -Path $script:AppConfig.Paths.WinToolkitDir -ItemType Directory -Force -ErrorAction Stop
    }
    $tempPath = "$statusPath.$([guid]::NewGuid()).tmp"
    try {
        $Status.LastUpdatedUtc = [DateTime]::UtcNow.ToString('o')
        $Status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $tempPath -Encoding UTF8 -ErrorAction Stop
        Move-Item -LiteralPath $tempPath -Destination $statusPath -Force -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}
function Read-UpdateServicesStatus {
    $statusPath = Get-UpdateServicesStatusPath
    if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) { return $null }
    try {
        return (Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
    }
    catch {
        Write-ToolkitLog -Level 'ERROR' -Message "Update services status file is unreadable: $($_.Exception.Message)"
        return $null
    }
}
function Initialize-UpdateServicesState {
    $previous = Read-UpdateServicesStatus
    if (-not $previous) { return }
    if ($previous.State -in @('Suspending', 'Suspended', 'RestoreFailed')) {
        $message = "Previous setup did not finish cleanly; saved Windows Update service state found (state: $($previous.State))."
        if ($previous.LastError) { $message += " Previous error: $($previous.LastError)" }
        Write-ToolkitLog -Level 'WARNING' -Message $message
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.previousInterruptionDetectedRestoringUpdateServices')
        Invoke-StartUpdateServices
    }
}
function Set-UpdateServicesState {
    param(
        [Parameter(Mandatory = $true)][object]$Status,
        [Parameter(Mandatory = $true)][string]$State,
        $LastError = $null
    )
    $Status.State = $State
    $Status.LastError = $LastError
    Write-UpdateServicesStatus -Status $Status
}
function Set-UpdateServicesError {
    param([string]$Message)
    $status = Read-UpdateServicesStatus
    if ($status) {
        Set-UpdateServicesState -Status $status -State 'RestoreFailed' -LastError $Message
    }
    Write-ToolkitLog -Level 'ERROR' -Message "Windows Update services recovery: $Message"
}
function Sync-UserScopeWithInstalledTools {
    [CmdletBinding()]
    param()
    $context = Get-ToolkitOriginalUserContext
    if (-not $context.AccountSwitched) {
        return New-StepResult -Success $true -Message 'No account switch: the user scope is already correct.'
    }
    $toolsRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if (-not (Test-Path -LiteralPath $toolsRoot -PathType Container)) {
        Write-ToolkitLog -Level 'WARNING' -Message "Tool directory not found, nothing to align: $toolsRoot"
        return New-StepResult -Success $false -Message "No WindowsApps directory to align for '$($context.OriginalUser)'."
    }
    $hiveReg = 'HKU\WinToolkitUserScope'
    $loaded = $false
    try {
        $null = & reg.exe load $hiveReg (Join-Path $context.UserProfile 'NTUSER.DAT') 2>&1
        $loaded = ($LASTEXITCODE -eq 0)
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Could not load the user hive: $($_.Exception.Message)"
        $loaded = $false
    }
    if (-not $loaded) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.userScopeNotAligned0' -Args @($context.OriginalUser, $toolsRoot))
        return New-StepResult -Success $false -Message "Tools are in '$($context.CurrentUser)'; the PATH of '$($context.OriginalUser)' could not be updated."
    }
    try {
        $envKey = "Registry::$hiveReg\Environment"
        $current = (Get-ItemProperty -Path $envKey -Name 'Path' -ErrorAction SilentlyContinue).Path
        if ([string]::IsNullOrWhiteSpace($current)) { $current = '' }
        if (($current -split ';') -contains $toolsRoot) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.userScopeAlreadyAligned0' -Args @($context.OriginalUser))
            return New-StepResult -Success $true -Message 'The user PATH already contains the tool directory.'
        }
        $newPath = if ($current.TrimEnd(';')) { $current.TrimEnd(';') + ';' + $toolsRoot } else { $toolsRoot }
        Set-ItemProperty -Path $envKey -Name 'Path' -Value $newPath -Type ExpandString -Force
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.userScopeAligned0' -Args @($context.OriginalUser, $toolsRoot))
        Write-ToolkitLog -Level 'INFO' -Message "User PATH aligned: added '$toolsRoot' to '$($context.OriginalUser)'."
        return New-StepResult -Success $true -Changed $true -Message "Tool directory added to the PATH of '$($context.OriginalUser)'."
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Could not update the user PATH: $($_.Exception.Message)"
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.userScopeNotAligned0' -Args @($context.OriginalUser, $toolsRoot))
        return New-StepResult -Success $false -Message "Failed to update the PATH of '$($context.OriginalUser)'."
    }
    finally {
        if ($loaded) {
            $null = & reg.exe unload $hiveReg 2>&1
            Write-ToolkitLog -Level 'DEBUG' -Message "Unloaded the temporary user hive ($LASTEXITCODE)."
        }
    }
}
function Invoke-StopUpdateServices {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not $PSCmdlet.ShouldProcess('Windows Update services', 'Suspend services')) { return }
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.temporarilySuspendWindowsUpdateServicesToAvoidConflicts')
    $savedServices = @(
        Get-Service -Name $script:AppConfig.UpdateServices -ErrorAction SilentlyContinue |
            ForEach-Object {
                [pscustomobject]@{
                    Name      = $_.Name
                    Status    = [string]$_.Status
                    StartType = [string]$_.StartType
                }
            }
    )
    $status = @{
        Version    = 1
        State      = 'Suspending'
        LastError  = $null
        Services   = $savedServices
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
    }
    Write-UpdateServicesStatus -Status $status
    try {
        foreach ($saved in $savedServices) {
            if ($saved.Status -ne 'Stopped') {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.serviceStop0' -Args @($saved.Name))
                Stop-Service -Name $saved.Name -Force -ErrorAction Stop
                $current = Get-Service -Name $saved.Name -ErrorAction Stop
                if ($current.Status -ne 'Stopped') { throw "Service $($saved.Name) did not stop." }
            }
        }
        Set-UpdateServicesState -Status $status -State 'Suspended'
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updateServicesSuccessfullySuspended')
    }
    catch {
        Set-UpdateServicesState -Status $status -State 'RestoreFailed' -LastError $_.Exception.Message
        throw
    }
}
function Invoke-StartUpdateServices {
    param()
    $status = Read-UpdateServicesStatus
    if (-not $status -or $status.State -eq 'Restored') { return $true }
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resettingWindowsUpdateServices')
    $restoreErrors = @()
    foreach ($saved in @($status.Services)) {
        try {
            $service = Get-Service -Name $saved.Name -ErrorAction Stop
            $startupType = switch ($saved.StartType) {
                'Auto' { 'Automatic' }
                'Disabled' { 'Disabled' }
                default { $saved.StartType }
            }
            Set-Service -Name $saved.Name -StartupType $startupType -ErrorAction Stop
            if ($saved.Status -eq 'Running' -and $service.Status -ne 'Running') {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingService0' -Args @($saved.Name))
                Start-Service -Name $saved.Name -ErrorAction Stop
            }
            elseif ($saved.Status -eq 'Stopped' -and $service.Status -ne 'Stopped') {
                Stop-Service -Name $saved.Name -Force -ErrorAction Stop
            }
        }
        catch {
            $restoreErrors += "$($saved.Name): $($_.Exception.Message)"
        }
    }
    if ($restoreErrors.Count -gt 0) {
        Set-UpdateServicesState -Status $status -State 'RestoreFailed' -LastError ($restoreErrors -join '; ')
        Write-ToolkitLog -Level 'ERROR' -Message "Unable to restore Windows Update services: $($restoreErrors -join '; ')"
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.updateServicesRestoreIncomplete0' -Args @($status.LastError))
        return $false
    }
    Set-UpdateServicesState -Status $status -State 'Restored'
    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updateServicesRestored')
    return $true
}
function Get-WinGetExecutable {
    $aliasPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    if (Test-Path $aliasPath) {
        return $aliasPath
    }
    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source -and (Test-Path -LiteralPath $command.Source)) {
        return $command.Source
    }
    return $null
}
function Register-WingetAppExecutionAlias {
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop
        Write-ToolkitLog -Level 'INFO' -Message 'App Installer execution alias registered by family name.'
        return $true
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Unable to register App Installer execution alias: $($_.Exception.Message)"
        return $false
    }
}
function Start-AppxSilentProcess {
    param(
        [string]$AppxPath,
        [string]$Flags = '-ForceApplicationShutdown',
        [string[]]$DependencyPaths = @(),
        [string]$ExpectedPackageName,
        [int]$TimeoutSeconds = 120
    )
    $dependencyPathString = ""
    $dependencyPackagePathString = ""
    if ($DependencyPaths.Count -gt 0) {
        $quotedDependencies = (($DependencyPaths | ForEach-Object { "'$($_ -replace "'", "''")'" }) -join ", ")
        $dependencyPathString = "-DependencyPath $quotedDependencies"
        $dependencyPackagePathString = "-DependencyPackagePath $quotedDependencies"
    }
    $cmd = @"
`$ProgressPreference = 'SilentlyContinue';
`$ErrorActionPreference = 'SilentlyContinue';
try {
    Add-AppxPackage -Path '$($AppxPath -replace "'", "''")' $dependencyPathString $Flags -ErrorAction Stop | Out-Null
}
catch {
    if (`$_.Exception.Message -match '0x80073D06') {
        exit 0
    }
    if (`$_.Exception.Message -match '0x80073CF9' -or ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)) {
        try {
            Add-AppxProvisionedPackage -Online -PackagePath '$($AppxPath -replace "'", "''")' $dependencyPackagePathString -SkipLicense -ErrorAction Stop | Out-Null
            exit 0
        }
        catch {
            [Console]::Error.WriteLine(`$_.Exception.Message); exit 1
        }
    }
    [Console]::Error.WriteLine(`$_.Exception.Message); exit 1
}
exit 0
"@
    $encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
    $result = Invoke-ExternalCommand -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-NonInteractive', '-EncodedCommand', $encodedCmd) -TimeoutSeconds $TimeoutSeconds
    if ($result.TimedOut) {
        Write-ToolkitLog -Level 'ERROR' -Message "AppX installation timeout after $TimeoutSeconds seconds: $AppxPath"
        return $false
    }
    if ($result.ExitCode -ne 0) {
        Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.appxInstallFailed01' -Args @($AppxPath, $result.StdErr.Trim()))
        return $false
    }
    if ($ExpectedPackageName -and
        -not (Get-AppxPackage -Name $ExpectedPackageName -ErrorAction SilentlyContinue)) {
        Write-ToolkitLog -Level 'ERROR' -Message "AppX command succeeded but package verification failed: $ExpectedPackageName"
        return $false
    }
    return $true
}
function Reset-AppxPackageSilently {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$Package
    )
    process {
        $previousProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            $Package | Reset-AppxPackage -ErrorAction SilentlyContinue 2>$null | Out-Null
        }
        finally {
            $ProgressPreference = $previousProgress
        }
    }
}
function Reset-AppInstallerPackage {
    Write-ToolkitLog -Level 'INFO' -Message 'Resetting Microsoft.DesktopAppInstaller package.'
    Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue | Reset-AppxPackageSilently
}
function Test-WingetRpcFailure {
    param(
        [Parameter(Mandatory = $true)][object]$Result
    )
    return ($Result.ExitCode -eq $script:AppConfig.Winget.RpcFailureExitCode)
}
function Test-WingetModernVersion {
    param(
        [Parameter(Mandatory = $true)][string]$VersionOutput
    )
    if ($VersionOutput -match '(\d+)\.(\d+)') {
        try {
            return ([version]("$($Matches[1]).$($Matches[2])") -ge [version]'1.4')
        }
        catch {
            Write-ToolkitLog -Level 'DEBUG' -Message "Unparsable WinGet version '$VersionOutput': $($_.Exception.Message)"
        }
    }
    return $true
}
function Get-WingetModernFlag {
    [CmdletBinding()]
    param([string]$WingetExe)
    if (-not $WingetExe) { return $null }
    if ($script:State.Winget.Modern -and $script:State.Winget.ProbedExe -eq $WingetExe) {
        if ($script:State.Winget.Modern) { return '--disable-interactivity' }
        return $null
    }
    $result = Invoke-ExternalCommand -FilePath $WingetExe -ArgumentList @('--version') `
        -TimeoutSeconds $script:AppConfig.Timeouts.WingetProbe
    $modern = $false
    if ($result.ExitCode -eq 0) {
        $modern = Test-WingetModernVersion -VersionOutput "$($result.StdOut)$($result.StdErr)"
    }
    else {
        Write-ToolkitLog -Level 'DEBUG' -Message "WinGet --version probe failed with exit code $($result.ExitCode); assuming a modern build."
        $modern = $true
    }
    $script:State.Winget.ProbedExe = $WingetExe
    $script:State.Winget.Modern = $modern
    return $(if ($modern) { '--disable-interactivity' } else { $null })
}
function Invalidate-WingetVersionCache {
    $script:State.Winget.Modern = $null
    $script:State.Winget.ProbedExe = $null
}
function Invoke-WingetRpcRecovery {
    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetRpcFailureDetected')
    Invoke-ForceCloseWinget
    $null = Register-WingetAppExecutionAlias
    $null = Reset-AppInstallerPackage
    Update-EnvironmentPath
    Start-Sleep -Seconds 2
    $probe = Invoke-WingetCommand -Arguments '--version'
    if (Test-WingetRpcFailure -Result $probe) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetRpcRecoveryFailed')
        return $false
    }
    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetRpcRecovered')
    return $true
}
function Invoke-WingetCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Arguments,
        [int]$TimeoutSeconds = 120
    )
    try {
        $wingetExe = Get-WinGetExecutable
        if (-not $wingetExe) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInSystem')
            return New-ExternalCommandResult -ExitCode -1 -FilePath 'winget.exe' -ArgumentList @($Arguments) -Error 'WinGet executable not found.'
        }
        $modernFlag = Get-WingetModernFlag -WingetExe $wingetExe
        $finalArgs = if ($modernFlag) { "$Arguments $modernFlag" } else { $Arguments }
        $result = Invoke-ExternalCommand -FilePath $wingetExe -ArgumentList (ConvertTo-ProcessArgumentList -Arguments $finalArgs) -TimeoutSeconds $TimeoutSeconds
        if ($result.TimedOut) {
            Write-ToolkitLog -Level 'ERROR' -Message "Winget timeout after $TimeoutSeconds seconds: $Arguments"
        }
        elseif (Test-WingetRpcFailure -Result $result) {
            Write-ToolkitLog -Level 'ERROR' -Message "Winget failed with 0x800706BA (App Installer deployment server unavailable) running: $Arguments"
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.wingetRpcFailureDetected')
        }
        return $result
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetCommandError0' -Args @($_.Exception.Message))
        return New-ExternalCommandResult -ExitCode -1 -FilePath 'winget.exe' -ArgumentList @($Arguments) -Error $_.Exception.Message
    }
}
function Invoke-WingetInstall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [switch]$Exact,
        [switch]$Upgrade,
        [string]$Source = 'winget'
    )
    if (-not (Get-WinGetExecutable)) {
        return New-ExternalCommandResult -ExitCode -1 -FilePath 'winget.exe' -ArgumentList @($Id) -Error 'WinGet executable not found.'
    }
    $acceptedExitCodes = @(0) + $script:AppConfig.Winget.AlreadyInstalledExitCodes
    $operation = if ($Upgrade) { 'upgrade' } else { 'install' }
    $exactFlag = if ($Exact) { '-e ' } else { '' }
    $command = "$operation $exactFlag--id $Id --source $Source --accept-source-agreements --accept-package-agreements --silent"
    $result = Invoke-WingetCommand -Arguments $command
    $result | Add-Member -NotePropertyName 'Accepted' -NotePropertyValue (
        (-not $result.TimedOut) -and $acceptedExitCodes -contains $result.ExitCode
    ) -Force
    if ((-not $result.Accepted) -and (Test-WingetRpcFailure -Result $result)) {
        if (Invoke-WingetRpcRecovery) {
            $result = Invoke-WingetCommand -Arguments $command
            $result | Add-Member -NotePropertyName 'Accepted' -NotePropertyValue (
                (-not $result.TimedOut) -and $acceptedExitCodes -contains $result.ExitCode
            ) -Force
        }
    }
    return $result
}
function Reset-WingetSources {
    $result = Invoke-WingetCommand -Arguments 'source reset --force'
    if ($result.ExitCode -ne 0) {
        Write-ToolkitLog -Level 'WARNING' -Message "Winget source reset failed with exit code $($result.ExitCode)."
    }
}
function Repair-WingetMsStoreSource {
    try {
        $wingetExe = Get-WinGetExecutable
        if (-not $wingetExe) { return }
        $result = Invoke-WingetCommand -Arguments 'source update --source msstore --accept-source-agreements'
        $sourceOutput = "$($result.StdOut)$($result.StdErr)"
        if ($result.ExitCode -eq 0 -or $sourceOutput -notmatch '0x8a15005e') { return }
        Write-StyledMessage -Type Warning -Text "Detected msstore certificate pinning failure (0x8a15005e). Resetting WinGet sources to default..."
        Reset-WingetSources
        Update-EnvironmentPath
        Write-StyledMessage -Type Success -Text "WinGet sources reset completed. Using the 'winget' source only."
    }
    catch {
        Write-ToolkitLog -Level 'DEBUG' -Message "msstore source repair skipped: $($_.Exception.Message)"
    }
}
function Repair-AppInstaller {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not $PSCmdlet.ShouldProcess('Microsoft.DesktopAppInstaller', 'Repair App Installer')) { return }
    $tempFile = $null
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'App Installer already exposes winget.' }
        }
        $changed = $false
        if (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue) {
            Reset-AppInstallerPackage
            $changed = $true
        }
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            $tempFile = Join-Path $env:TEMP 'WingetInstaller.msixbundle'
            if (-not (Invoke-DownloadFile -Uri $script:AppConfig.URLs.WingetMSIX -OutFile $tempFile `
                        -ContentValidator (New-SignatureValidator -ProfileKey 'wingetMsix'))) {
                throw 'App Installer bundle download failed or its signature is not trusted.'
            }
            if (-not (Start-AppxSilentProcess -AppxPath $tempFile -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.DesktopAppInstaller')) {
                throw 'App Installer package installation failed.'
            }
            $changed = $true
        }
        if (-not (Register-WingetAppExecutionAlias)) { throw 'App Installer execution alias registration failed.' }
        return [pscustomobject]@{ Success = $true; Changed = $changed; Message = 'App Installer repaired and alias registered.' }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "App Installer repair failed: $($_.Exception.Message)"
        return [pscustomobject]@{ Success = $false; Changed = $false; Message = $_.Exception.Message }
    }
    finally {
        if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}
function Test-WingetCompatibility {
    $osInfo = [Environment]::OSVersion
    $build = $osInfo.Version.Build
    if ($osInfo.Version.Major -lt 10) {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.wingetNotSupportedOnWindows0' -Args @($osInfo.Version.Major))
        return $false
    }
    if ($osInfo.Version.Major -eq 10 -and $build -lt 17763) {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.windows10Build0NonSupportaWinget' -Args @($build))
        return $false
    }
    return $true
}
function Get-WingetHealth {
    Update-EnvironmentPath
    $health = [pscustomobject]@{
        Present   = [bool](Get-WinGetExecutable)
        Runs      = $false
        Version   = $null
        Reachable = $false
    }
    if (-not $health.Present) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInPath')
        return $health
    }
    $version = Invoke-WingetCommand -Arguments '--version'
    if (($version.ExitCode -eq 0) -and ("$($version.StdOut)$($version.StdErr)" -match 'v(\d+\.\d+)')) {
        $health.Runs = $true
        $health.Version = $Matches[1]
    }
    else {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetPresentButNotRespondingCorrectlyExitcode0' -Args @($version.ExitCode))
        return $health
    }
    $search = Invoke-WingetCommand -Arguments 'search --id Microsoft.PowerShell --source winget' -TimeoutSeconds $script:AppConfig.Timeouts.Winget
    $health.Reachable = ($search.ExitCode -eq 0)
    if (-not $health.Reachable) {
        Write-ToolkitLog -Level 'WARNING' -Message "WinGet sources not reachable (search exit code $($search.ExitCode))."
    }
    return $health
}
function Test-WingetAppInstaller {
    $wingetExe = Get-WinGetExecutable
    if (-not $wingetExe) {
        return $false
    }
    Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.checkingMicrosoftAppInstallerPackage'))
    $present = [bool](Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue)
    try {
        if (-not $present) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerNotFoundInstalling')
            $null = Invoke-WingetCommand -Arguments 'install --id Microsoft.AppInstaller --source winget --accept-package-agreements --accept-source-agreements --force'
        }
        else {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerPresentForcingUpdate')
            $null = Invoke-WingetCommand -Arguments 'upgrade --id Microsoft.AppInstaller --source winget --accept-package-agreements --accept-source-agreements --force'
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerUpdateError0' -Args @($_.Exception.Message))
    }
    $ok = [bool](Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue)
    if ($ok) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerUpdated')
    }
    else {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerInstallationFailed')
    }
    return $ok
}
function Invoke-ForceCloseWinget {
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.closingInterferingProcesses')
    foreach ($procName in $script:AppConfig.WingetProcesses) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -ne $PID } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep 2
    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.interferingProcessesClosed')
}
function Set-WingetPathPermissions {
    $aliasRegistered = Register-WingetAppExecutionAlias
    Update-EnvironmentPath
    Invalidate-WingetVersionCache
    if ($aliasRegistered) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.pathAndWingetPermissionsUpdated')
    }
}
function Invoke-WinGetPackageManagerRepair {
    if (-not (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue)) {
        return $false
    }
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.attemptingWingetRepairViaPackageManager')
    try {
        Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
        return $true
    }
    catch {
        if ($_.Exception.Message -match '0x80073D06') {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerIgnoredHigherVersionAlreadyPresent')
            return $true
        }
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerFallito0' -Args @($_.Exception.Message))
        return $false
    }
}
function Repair-WingetDatabase {
    Write-StyledMessage -Type Info -Text ("🔧 " + (Get-SourceTextLoc 'uiText.startWingetDatabaseRecovery'))
    try {
        Invoke-ForceCloseWinget
        $wingetCachePath = "$env:LOCALAPPDATA\WinGet"
        if (Test-Path $wingetCachePath) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.clearingWingetCache')
            Get-ChildItem -Path $wingetCachePath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\lock\\|\\tmp\\' } |
            ForEach-Object {
                try {
                    Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
                }
                catch {
                    Write-ToolkitLog -Level 'WARNING' -Message "Repair-WingetDatabase cache: $($_.Exception.Message)"
                }
            }
        }
        $stateFiles = @(
            "$env:LOCALAPPDATA\WinGet\Data\USERTEMPLATE.json",
            "$env:LOCALAPPDATA\WinGet\Data\DEFAULTUSER.json"
        )
        foreach ($file in $stateFiles) {
            if (Test-Path $file -PathType Leaf) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetStatusFile0' -Args @($file))
                Remove-Item $file -Force -ErrorAction SilentlyContinue
            }
        }
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetWingetSources')
        Reset-WingetSources
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetPackageMicrosoftDesktopappinstaller')
        if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
            Reset-AppInstallerPackage
        }
        try {
            $manifest = (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue).InstallLocation
            if ($manifest) {
                $manifestXml = Join-Path $manifest 'AppxManifest.xml'
                if (Test-Path $manifestXml) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.reRegisterManifestAppxmanifestXml')
                    $null = Start-AppxSilentProcess -AppxPath $manifestXml -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown'
                }
            }
        }
        catch {
            Write-ToolkitLog -Level 'WARNING' -Message "Repair-WingetDatabase manifest: $($_.Exception.Message)"
        }
        $null = Invoke-WinGetPackageManagerRepair
        Set-WingetPathPermissions
        Update-EnvironmentPath
        Start-Sleep 2
        $versionResult = Invoke-WingetCommand -Arguments '--version'
        if ($versionResult.ExitCode -ne 0) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.restoreCompletedButWingetMayNotWork')
        }
        else {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetDatabaseRestoredVersion0' -Args @($versionResult.StdOut.Trim()))
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorRestoringDatabase0' -Args @($_.Exception.Message))
        return $false
    }
}
function Test-WingetAccessViolation {
    param([Parameter(Mandatory = $true)][int]$ExitCode)
    return $ExitCode -eq $script:EXITCODE_ACCESS_VIOLATION_SIGNED
}
function Test-WingetDeepValidation {
    Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.deepTestExecutionOfWingetSearchForPacketsOnTheNetwork'))
    try {
        $searchResult = Invoke-WingetCommand -Arguments 'search Git.Git --accept-source-agreements'
        $exitCode = $searchResult.ExitCode
        if (Test-WingetAccessViolation -ExitCode $exitCode) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.crashDetectedExitcode0AccessViolationAdvancedRecoveryAttempt' -Args @($exitCode))
            $recoverySteps = @(
                @{ Repair = { Repair-WingetDatabase }; WarningKey = $null; InfoKey = 'uiText.repeatTestAfterDatabaseRestore' },
                @{ Repair = { Install-WingetCore }; WarningKey = 'uiText.persistentCrashStartingCompleteReinstallationOfWinget'; InfoKey = 'uiText.finalTestAfterReinstallation' }
            )
            foreach ($step in $recoverySteps) {
                if ($step.WarningKey) {
                    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc $step.WarningKey)
                }
                $null = & $step.Repair
                Write-StyledMessage -Type Info -Text ("🔄 " + (Get-SourceTextLoc $step.InfoKey))
                Start-Sleep 3
                $searchResult = Invoke-WingetCommand -Arguments 'search Git.Git --accept-source-agreements'
                $exitCode = $searchResult.ExitCode
                if (-not (Test-WingetAccessViolation -ExitCode $exitCode)) { break }
            }
        }
        if ($exitCode -eq 0) {
            $sourceUpdate = Invoke-WingetCommand -Arguments 'source update --accept-source-agreements'
            if ($sourceUpdate.ExitCode -ne 0) {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'toolText.sourceUpdateError0' -Args @($sourceUpdate.ExitCode))
            }
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.deepTestPassedWingetCommunicatesCorrectlyWithRepositories')
            return $true
        }
        $errorDetails = "$($searchResult.StdOut)$($searchResult.StdErr)"
        if ($errorDetails.Length -gt 200) {
            $errorDetails = $errorDetails.Substring(0, 200) + "."
        }
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.deepTestFailedExitcode0Details1' -Args @($exitCode, $errorDetails))
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorDuringWingetDeepTest0' -Args @($_.Exception.Message))
        return $false
    }
}
function Get-WingetDownloadUrl {
    param([Parameter(Mandatory = $true)][string]$Match)
    try {
        $latest = Invoke-RestMethod -Uri $script:AppConfig.URLs.WingetCliRelease -UseBasicParsing
        $asset = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
        if ($asset) {
            return $asset.browser_download_url
        }
        throw (Get-SourceTextLoc 'uiText.asset0NotFound' -Args @($Match))
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.assetUrlRetrievalError0' -Args @($_.Exception.Message))
        return $null
    }
}
function Install-WingetCore {
    Write-StyledMessage -Type Info -Text ("🛠️ " + (Get-SourceTextLoc 'uiText.startingWingetCoreRecoveryProcedure'))
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    $tempDir = "$env:TEMP\WinToolkitWinget"
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force *>$null
    }
    try {
        if (-not (Test-VCRedistInstalled)) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.visualCRedistributableInstallation')
            $vcUrl = $script:AppConfig.URLs.VCRedistTemplate -f (Get-ArchitectureSpecificValue -X64 'x64' -X86 'x86' -ARM64 'arm64')
            $vcFile = Join-Path $tempDir "vc_redist.exe"
            if (-not (Invoke-DownloadFile -Uri $vcUrl -OutFile $vcFile `
                    -ContentValidator (New-SignatureValidator -ProfileKey 'vcRedist' -BlockOnInvalid))) {
                throw 'Visual C++ Redistributable download failed or its signature was not trusted.'
            }
            $vcResult = Invoke-ExternalCommand -FilePath $vcFile -ArgumentList @('/install', '/quiet', '/norestart') -TimeoutSeconds 600 -AcceptedExitCodes @(0, 1638, 3010)
            if ($vcResult.Accepted) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.visualCRedistributableInstalled')
            }
            else {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.installationFailedCode0' -Args @($vcResult.ExitCode))
            }
        }
        else {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.visualCRedistributableAlreadyPresent')
        }
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadWingetDependencies')
        $dependencies = @()
        $depUrl = Get-WingetDownloadUrl -Match 'DesktopAppInstaller_Dependencies.zip'
        if ($depUrl) {
            $depZip = Join-Path $tempDir "dependencies.zip"
            try {
                if (-not (Invoke-DownloadFile -Uri $depUrl -OutFile $depZip -Silent)) {
                    throw 'WinGet dependency bundle download failed.'
                }
                $extractPath = Join-Path $tempDir "deps"
                Expand-Archive -Path $depZip -DestinationPath $extractPath -Force
                $archPattern = Get-ArchitectureSpecificValue -X64 'x64|neutral|ne' -X86 'x86|neutral|ne' -ARM64 'arm64|neutral|ne'
                $appxFiles = Get-ChildItem -Path $extractPath -Recurse -Filter "*.appx" | Where-Object { $_.Name -match $archPattern }
                foreach ($file in $appxFiles) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.dependencyFound0' -Args @($file.Name))
                    $dependencies += $file.FullName
                }
            }
            catch {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.unableToExtractOrInstallDependenciesFromTheOfficialZipError0' -Args @($_.Exception.Message))
            }
        }
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadAndInstallWingetBundle')
        $wingetUrl = Get-WingetDownloadUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        if (-not $wingetUrl) {
            throw (Get-SourceTextLoc 'uiText.wingetCoreInstallationFailed')
        }
        $wingetFile = Join-Path $tempDir "winget.msixbundle"
        if (-not (Invoke-DownloadFile -Uri $wingetUrl -OutFile $wingetFile -Silent `
                    -ContentValidator (New-SignatureValidator -ProfileKey 'wingetMsix'))) {
            throw (Get-SourceTextLoc 'uiText.wingetCoreInstallationFailed')
        }
        if (Start-AppxSilentProcess -AppxPath $wingetFile -DependencyPaths $dependencies -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.DesktopAppInstaller') {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetCoreSuccessfullyInstalled')
        }
        else {
            throw (Get-SourceTextLoc 'uiText.wingetCoreInstallationFailed')
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorRestoringWinget0' -Args @($_.Exception.Message))
        return $false
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        $ProgressPreference = $oldProgress
    }
}
function Reset-WingetSourcesOnce {
    if ($script:State.SourcesReset) { return }
    Reset-WingetSources
    $script:State.SourcesReset = $true
}
function Reinstall-WingetForced {
    [CmdletBinding()]
    param(
        [switch]$SkipModule,
        [switch]$Force
    )
    $appInstallerRepaired = $false
    $moduleInstalled = $false
    $notes = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-WingetCompatibility)) {
        return New-StepResult -Success $false -Message 'This Windows build is not supported by WinGet.'
    }
    Invoke-ForceCloseWinget
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.forcedReinstallAppInstaller0')
        Reset-AppInstallerPackage
        $present = [bool](Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue)
        if (-not ($Force -or -not $present)) {
            $appInstallerRepaired = $true
        }
        else {
            $tempInstaller = Join-Path (Initialize-Directory -Path $script:AppConfig.Paths.Temp) 'WingetInstaller.msixbundle'
            try {
                if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.WingetMSIX -OutFile $tempInstaller -Silent `
                        -ContentValidator (New-SignatureValidator -ProfileKey 'wingetMsix')) {
                    if (Start-AppxSilentProcess -AppxPath $tempInstaller -Flags '-ForceApplicationShutdown' `
                            -ExpectedPackageName 'Microsoft.DesktopAppInstaller') {
                        $appInstallerRepaired = $true
                        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetMsixBundleInstallationSuccessful')
                    }
                    else { $notes.Add('The App Installer bundle was rejected by Windows.') }
                }
                else { $notes.Add('The App Installer bundle could not be downloaded or its signature was not trusted.') }
            }
            finally { Remove-PathQuietly -Path $tempInstaller }
        }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Forced App Installer repair failed: $($_.Exception.Message)"
        $notes.Add("App Installer repair failed: $($_.Exception.Message)")
    }
    if ($SkipModule) {
        $notes.Add('Module install skipped as requested.')
        Write-ToolkitLog -Level 'INFO' -Message 'Skipped the WinGet.Client module install: -SkipModule set.'
    }
    else {
        try {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingMicrosoftWingetClientModule')
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
            Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetClientModuleInstalled')
            Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
            $moduleInstalled = $true
        }
        catch {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.moduloWingetClient0' -Args @($_.Exception.Message))
            Write-ToolkitLog -Level 'WARNING' -Message "WinGet.Client module install failed: $($_.Exception.Message)"
            $notes.Add("Module install failed: $($_.Exception.Message)")
        }
    }
    Set-WingetPathPermissions
    Update-EnvironmentPath
    Invalidate-WingetVersionCache
    $health = Get-WingetHealth
    $detail = ($notes -join ' ')
    if ($health.Runs) {
        Reset-WingetSourcesOnce
        return New-StepResult -Success $true -Changed $true -Message "WinGet operational (v$($health.Version)). $detail".Trim()
    }
    $repaired = [bool]($appInstallerRepaired -or $moduleInstalled)
    return New-StepResult -Success $repaired -Changed $repaired -Message "WinGet still unavailable. $detail".Trim()
}
function Initialize-Winget {
    Update-EnvironmentPath
    $null = Repair-WingetMsStoreSource
    $health = Get-WingetHealth
    if ($health.Runs) {
        return New-StepResult -Success $true -Message "WinGet operational (v$($health.Version))."
    }
    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetDoesnTRespondFastRecoveryAttemptCore')
    $null = Install-WingetCore
    Update-EnvironmentPath
    Invalidate-WingetVersionCache
    $health = Get-WingetHealth
    if ($health.Runs) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetRestoredQuickly')
        Reset-WingetSourcesOnce
        return New-StepResult -Success $true -Changed $true -Message "WinGet restored (v$($health.Version))."
    }
    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.quickRecoveryFailedAttemptAdvancedSlowerMethod')
    $null = Repair-WingetDatabase
    $null = Install-WingetCore
    Update-EnvironmentPath
    Invalidate-WingetVersionCache
    $health = Get-WingetHealth
    if ($health.Runs) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetRestoredQuickly')
        Reset-WingetSourcesOnce
        return New-StepResult -Success $true -Changed $true -Message "WinGet restored (v$($health.Version))."
    }
    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.quickRecoveryFailedAttemptForcedPackageReinstall')
    $null = Reinstall-WingetForced
    Update-EnvironmentPath
    Invalidate-WingetVersionCache
    $health = Get-WingetHealth
    if (-not $health.Runs) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFunctionalAfterAllAttempts')
        return New-StepResult -Success $false -Message 'WinGet remains unavailable after recovery.'
    }
    Reset-WingetSourcesOnce
    return New-StepResult -Success $true -Changed $true -Message "WinGet reinstalled (v$($health.Version))."
}
function Test-VCRedistRuntime {
    param(
        [Parameter(Mandatory = $true)][string]$RuntimeName,
        [Parameter(Mandatory = $true)][string]$DllPath
    )
    $registryPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\$RuntimeName"
    if (-not (Test-Path -Path $registryPath)) { return $false }
    $major = (Get-ItemProperty -Path $registryPath -Name 'Major' -ErrorAction SilentlyContinue).Major
    return [bool]($major -eq 14 -and [System.IO.File]::Exists($DllPath))
}
function Test-VCRedistInstalled {
    $architecture = Get-SystemArchitecture
    $required = @(
        @{ Runtime = 'x86'; DllPath = "$env:windir\syswow64\concrt140.dll" }
    )
    if ($architecture -ne 'X86') {
        $nativeRuntime = Get-ArchitectureSpecificValue -X64 'x64' -ARM64 'arm64'
        $required += @{ Runtime = $nativeRuntime; DllPath = "$env:windir\system32\concrt140.dll" }
    }
    $results = foreach ($item in $required) {
        Test-VCRedistRuntime -RuntimeName $item.Runtime -DllPath $item.DllPath
    }
    return -not ($results -contains $false)
}
function Install-GitPackage {
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.verifyGitInstallation')
    Update-EnvironmentPath
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitAlreadyInstalled')
        return $true
    }
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.gitInstallation')
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $result = Invoke-WingetInstall -Id 'Git.Git'
        if ($result.Accepted) {
            Update-EnvironmentPath
            if (Wait-Until -Condition { Test-CommandExists -Name git } -TimeoutSeconds 15 -IntervalMs 1000) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitInstalledViaWinget')
                return $true
            }
        }
    }
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.fallbackDownloadGitFromGitHub')
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.runningGitInstaller')
        $assetPattern = Get-ArchitectureSpecificValue -X64 '64-bit\.exe$' -X86 '32-bit\.exe$' -ARM64 'arm64\.exe$'
        $installResult = Install-FromGitHubRelease -ReleaseApiUrl $script:AppConfig.URLs.GitRelease `
            -AssetPattern $assetPattern -ExecutablePath '{INSTALLER}' `
            -InstallerArguments @('/SILENT', '/NORESTART', '/CLOSEAPPLICATIONS')
        if ($installResult.Success) {
            Update-EnvironmentPath
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitInstalledSuccessfully')
            return $true
        }
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.installationFailedCode0' -Args @($installResult.ExitCode))
        if ($installResult.PSObject.Properties.Name -contains 'Error' -and $installResult.Error) {
            Write-ToolkitLog -Level 'ERROR' -Message "Git installer fallback error: $($installResult.Error)"
        }
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.gitInstallationError0' -Args @($_.Exception.Message))
        return $false
    }
}
function Install-PowerShellCore {
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.checkingPowershell7')
    $pwshExe = Join-Path $PSHOME 'pwsh.exe'
    if (($PSVersionTable.PSVersion.Major -ge 7) -and (Test-Path -LiteralPath $pwshExe)) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7AlreadyInstalled')
        return $true
    }
    Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.powershellInstallationError0' -Args @("pwsh.exe not found in '$PSHOME'."))
    return $false
}
function Test-WindowsTerminalInstalled {
    $command = Get-Command 'wt.exe' -ErrorAction SilentlyContinue
    return [bool]($command -and $command.Source -and (Test-Path -LiteralPath $command.Source))
}
function Test-WindowsTerminalDefaultSupported {
    $version = [Environment]::OSVersion.Version
    if ($version.Build -ge 22000) { return $true }
    if ($version.Build -eq 19045 -and $version.Revision -ge 3031) { return $true }
    return $false
}
function Install-WindowsTerminalApp {
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.windowsTerminalConfiguration')
    if (Test-WindowsTerminalInstalled) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalIsAlreadyInstalled')
        return $true
    }
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.windowsTerminalInstallationInProgress')
    $tempFile = $null
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.attemptingToInstallWindowsTerminalViaWinget')
            $result = Invoke-WingetInstall -Id 'Microsoft.WindowsTerminal'
            if ($result.Accepted -and (Wait-Until -Condition { Test-WindowsTerminalInstalled })) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalInstalledViaWinget')
                return $true
            }
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstallationForWindowsTerminalFailed')
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstallationForWindowsTerminalFailed' -Args @($_.Exception.Message))
    }
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.retrieveUrlLatestReleaseOfWindowsTerminal')
        $latestRel = Invoke-RestMethod -Uri $script:AppConfig.URLs.TerminalRelease -UseBasicParsing
        $asset = $latestRel.assets |
        Where-Object { $_.name -match '^Microsoft\.WindowsTerminal_.*\.msixbundle$' } |
        Select-Object -First 1
        if (-not $asset) {
            throw (Get-SourceTextLoc 'uiText.windowsTerminalAssetMsixbundleNotFound')
        }
        $downloadUrl = $asset.browser_download_url
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.attemptingNativeAppxInstallFromBundle')
        $tempFile = Join-Path $env:TEMP "WinTerminal.msixbundle"
        if (-not (Invoke-DownloadFile -Uri $downloadUrl -OutFile $tempFile `
                    -ContentValidator (New-SignatureValidator -ProfileKey 'terminalMsix'))) {
            throw (Get-SourceTextLoc 'uiText.windowsTerminalAppxInstallationFailed')
        }
        if (Start-AppxSilentProcess -AppxPath $tempFile -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.WindowsTerminal') {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalAppxInstallationSuccessful')
        }
        else {
            throw (Get-SourceTextLoc 'uiText.windowsTerminalAppxInstallationFailed')
        }
        if (-not (Wait-Until -Condition { Test-WindowsTerminalInstalled } -TimeoutSeconds 30 -IntervalMs 1000)) {
            throw 'Windows Terminal package installed but wt.exe was not detected.'
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.standardWindowsTerminalInstallationFailed0FallbackToTheMicrosoftStore' -Args @($_.Exception.Message))
    }
    finally {
        if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
    if (Test-WindowsTerminalInstalled) {
        return $true
    }
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.fallbackAperturaMicrosoftStorePerWindowsTerminal')
    Start-Process "ms-windows-store://pdp/?ProductId=9N0DX20HK701"
    Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.unableToInstallWindowsTerminalViaAnyAutomaticMethod')
    return $false
}
function Set-WindowsTerminalAsDefault {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not (Test-WindowsTerminalDefaultSupported)) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.defaultTerminalNotSupportedOnThisBuild')
        return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'Default terminal not supported on this build.' }
    }
    if (-not $PSCmdlet.ShouldProcess('Windows Terminal', 'Set as default terminal application')) {
        return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'WhatIf: default terminal not changed.' }
    }
    Write-StyledMessage -Type Info -Text ("⚙️ " + (Get-SourceTextLoc 'uiText.settingWindowsTerminalAsDefaultViaRegistry'))
    try {
        $registryPath = $script:AppConfig.Registry.TerminalStartup
        if (-not (Test-Path $registryPath)) { $null = New-Item -Path $registryPath -Force }
        Set-ItemProperty -Path $registryPath -Name 'DelegationTerminal' -Value $script:AppConfig.WindowsTerminal.DelegationTerminalClsid -Force
        Set-ItemProperty -Path $registryPath -Name 'DelegationConsole' -Value $script:AppConfig.WindowsTerminal.DelegationConsoleClsid -Force
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalSetAsDefault')
        return [pscustomobject]@{ Success = $true; Changed = $true; Message = 'Windows Terminal set as default.' }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.failedToSetDefaultTerminal0' -Args @($_.Exception.Message))
        return [pscustomobject]@{ Success = $false; Changed = $false; Message = $_.Exception.Message }
    }
}
function Update-WindowsTerminalSettings {
    param([Parameter(Mandatory = $true)][string]$SettingsPath)
    try {
        if (-not (Install-RemoteFile -Url $script:AppConfig.URLs.WindowsTerminalSettings `
                    -Destination $SettingsPath -MinimumBytes 64 -Backup)) {
            return $false
        }
        return $true
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Windows Terminal settings update skipped: $($_.Exception.Message)"
        return $false
    }
}
function Install-NerdFontsLocal {
    try {
        Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.checkForJetbrainsmonoNerdFont'))
        $fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $installed = Get-ItemProperty -Path $fontRegistryPath -ErrorAction SilentlyContinue |
        Get-Member -MemberType NoteProperty |
        Where-Object Name -like "*JetBrainsMono*"
        if ($installed) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.jetbrainsmonoNerdFontAlreadyInstalled')
            return $true
        }
        Write-StyledMessage -Type Info -Text ("⬇️ " + (Get-SourceTextLoc 'uiText.fontInstallationViaWingetQuickMethod'))
        $result = Invoke-WingetInstall -Id 'DEVCOM.JetBrainsMonoNerdFont'
        if (-not $result.Accepted) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetReturnedCode0TheFontMayRequireATerminalRestart' -Args @($result.ExitCode))
            return $false
        }
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.nerdFontsInstalledSuccessfully')
        Write-StyledMessage -Type Warning -Text ("💡 " + (Get-SourceTextLoc 'uiText.noteFontsViaWingetRequireRestartingTerminalOrExplorerToBeVisible'))
        return $true
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.errorInstallingFont0' -Args @($_.Exception.Message))
        return $false
    }
}
function Test-OhMyPoshThemeFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        if (-not (Test-FileHasMinimumSize -Path $Path -MinimumBytes $script:AppConfig.UserScope.MinThemeFileBytes)) {
            return $false
        }
        $null = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        return $true
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Oh My Posh theme is not valid JSON ($Path): $($_.Exception.Message)"
        return $false
    }
}
function Install-PspEnvironment {
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingPowershellEnvironmentSetupPsp')
    $result = [pscustomobject]@{
        Success          = $true
        Tools            = [pscustomobject]@{ Installed = @(); Failed = @() }
        FontOk           = $null
        ThemeOk          = $false
        ProfileOk        = $false
        ProfilePath      = $null
        ThemePath        = $null
        WingetRpcFailure = $false
        Message          = 'PowerShell environment configured.'
    }
    $context = Get-ToolkitOriginalUserContext
    if ($context.AccountSwitched) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.elevationSwitchedAccount0' -Args @($context.OriginalUser, $context.CurrentUser))
    }
    $tools = @(
        @{ Id = "JanDeDobbeleer.OhMyPosh"; Name = "Oh My Posh" },
        @{ Id = "ajeetdsouza.zoxide"; Name = "zoxide" },
        @{ Id = "aristocratos.btop4win"; Name = "btop" },
        @{ Id = "Fastfetch-cli.Fastfetch"; Name = "fastfetch" }
    )
    $wingetAvailable = [bool](Get-WinGetExecutable)
    foreach ($tool in $tools) {
        if (-not $wingetAvailable) {
            $result.Tools.Failed += "$($tool.Name) (WinGet not available)"
            continue
        }
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.check0' -Args @($tool.Name))
        $toolResult = Invoke-WingetInstall -Id $tool.Id -Exact
        if ($toolResult.Accepted) {
            $result.Tools.Installed += $tool.Name
        }
        else {
            if (Test-WingetRpcFailure -Result $toolResult) { $result.WingetRpcFailure = $true }
            $result.Tools.Failed += "$($tool.Name) (exit $($toolResult.ExitCode))"
            Write-ToolkitLog -Level 'WARNING' -Message "Tool $($tool.Id) install returned exit code $($toolResult.ExitCode)."
        }
    }
    $paths = $null
    try {
        $paths = Resolve-ToolkitPowerShellProfileDirectory
        Write-ToolkitLog -Level 'INFO' -Message "PowerShell profile directory resolved: $($paths.ProfileDirectory)"
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.profileDirectoryUnavailable0' -Args @($_.Exception.Message))
        $result.Success = $false
        $result.Message = "Unable to prepare the PowerShell profile directory: $($_.Exception.Message)"
        Write-ToolkitLog -Level 'ERROR' -Message $result.Message
        return $result
    }
    $result.ProfilePath = $paths.ProfilePath
    $result.ThemePath = $paths.ThemePath
    $themeUris = @($script:AppConfig.URLs.OhMyPoshThemeUrls)
    if (Invoke-DownloadFile -Uri $themeUris -OutFile $paths.ThemePath `
            -MinimumBytes $script:AppConfig.UserScope.MinThemeFileBytes `
            -ContentValidator { param($candidatePath) Test-OhMyPoshThemeFile -Path $candidatePath }) {
        $result.ThemeOk = $true
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.ohMyPoshThemeDownloaded')
        Write-ToolkitLog -Level 'INFO' -Message "Oh My Posh theme installed: $($paths.ThemePath)"
    }
    else {
        $result.Success = $false
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.ohMyPoshThemeDownloadFailed0' -Args @($paths.ThemePath))
    }
    $result.FontOk = Install-NerdFontsLocal
    if (-not $result.FontOk) { $result.Success = $false }
    $targetProfile = $paths.ProfilePath
    try {
        if (Install-RemoteFile -Url $script:AppConfig.URLs.PowerShellProfile `
                -Destination $targetProfile -MinimumBytes $script:AppConfig.MinProfileBytes -Backup) {
            if (Test-FileHasMinimumSize -Path $targetProfile -MinimumBytes $script:AppConfig.MinProfileBytes) {
                $result.ProfileOk = $true
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7ProfileConfigured')
                Write-ToolkitLog -Level 'INFO' -Message "PowerShell profile installed: $targetProfile"
            }
            else {
                $result.Success = $false
                Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.profileNotInstalled0' -Args @($targetProfile))
            }
        }
        else {
            $result.Success = $false
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.profileNotInstalled0' -Args @($targetProfile))
        }
    }
    catch {
        $result.Success = $false
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.profileConfigurationError0' -Args @($_.Exception.Message))
    }
    if (-not $result.ProfileOk -or -not $result.ThemeOk) {
        $result.Message = "PowerShell environment incomplete (profile installed: $($result.ProfileOk), theme installed: $($result.ThemeOk))."
    }
    try {
        $wtPackages = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Directory `
            -Filter 'Microsoft.WindowsTerminal*' -ErrorAction SilentlyContinue
        foreach ($wtPkg in $wtPackages) {
            $localStatePath = Join-Path $wtPkg.FullName 'LocalState'
            if (Test-Path $localStatePath) {
                $settingsPath = Join-Path $localStatePath 'settings.json'
                if (Update-WindowsTerminalSettings -SettingsPath $settingsPath) {
                    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalSettingsUpdated0' -Args @($wtPkg.Name))
                }
            }
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.terminalSettingsUpdateError0' -Args @($_.Exception.Message))
    }
    if ($result.WingetRpcFailure) {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.wingetRpcFailureDetected')
        $result.Message += ' WinGet failed with 0x800706BA (App Installer deployment server unavailable): the CLI tools were NOT installed.'
    }
    return $result
}
function Update-ShellDesktopCache {
    try {
        $signature = @'
[DllImport("shell32.dll", CharSet = CharSet.Auto, SetLastError = false)]
public static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);
'@
        $shell32 = Add-Type -MemberDefinition $signature -Name 'WinToolkitShell32' -Namespace 'WinToolkit' -PassThru
        $shell32::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)
        return $true
    }
    catch {
        Write-ToolkitLog -Level 'DEBUG' -Message "SHChangeNotify unavailable: $($_.Exception.Message)"
        return $false
    }
}
function New-ToolkitDesktopShortcut {
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.desktopShortcutCreation')
    try {
        $desktop = Get-ToolkitUserFolderPath -Kind 'Desktop'
        $shortcut = Join-Path $desktop "Win Toolkit.lnk"
        $iconDir = $script:AppConfig.Paths.WinToolkitDir
        $icon = Join-Path $iconDir "WinToolkit.ico"
        $null = Initialize-Directory -Path $iconDir
        if (-not (Test-FileHasMinimumSize -Path $icon -MinimumBytes $script:MIN_ICON_FILE_BYTES)) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadIcon')
            $null = Invoke-DownloadFile -Uri $script:AppConfig.URLs.ToolkitIcon -OutFile $icon -MinimumBytes $script:MIN_ICON_FILE_BYTES
        }
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcut)
        $link.TargetPath = $script:AppConfig.Paths.wtExe
        $link.Arguments = 'pwsh -ExecutionPolicy Bypass -Command "irm ' + $script:AppConfig.URLs.WebInstaller + ' | iex"'
        $link.WorkingDirectory = $script:AppConfig.Paths.wtDir
        if (Test-FileHasMinimumSize -Path $icon -MinimumBytes $script:MIN_ICON_FILE_BYTES) {
            $link.IconLocation = $icon
        }
        $link.Description = "Win Toolkit - Master Windows with Ease"
        $link.Save()
        if (-not (Test-Path -LiteralPath $shortcut -PathType Leaf)) {
            throw "The shortcut was not written to '$shortcut'."
        }
        $bytes = [IO.File]::ReadAllBytes($shortcut)
        if ($bytes.Length -le $script:LNK_RUNAS_ADMIN_BYTE_OFFSET) {
            throw "Unexpected .lnk layout: file is only $($bytes.Length) bytes."
        }
        $bytes[$script:LNK_RUNAS_ADMIN_BYTE_OFFSET] = $bytes[$script:LNK_RUNAS_ADMIN_BYTE_OFFSET] -bor $script:LNK_RUNAS_ADMIN_BIT
        [IO.File]::WriteAllBytes($shortcut, $bytes)
        if (-not (Test-Path -LiteralPath $shortcut -PathType Leaf)) {
            throw "The shortcut disappeared from '$shortcut' after the elevation flag was set."
        }
        $null = Update-ShellDesktopCache
        Write-ToolkitLog -Level 'INFO' -Message "Desktop shortcut created: $shortcut"
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.shortcutCreatedSuccessfully')
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.shortcutCreationError0' -Args @($_.Exception.Message))
        Write-ToolkitLog -Level 'ERROR' -Message "Desktop shortcut creation failed: $($_.Exception.Message)"
        return $false
    }
}
function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}
function Test-LocalRootedPath {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $trimmed = $Path.Trim().TrimEnd('\')
    if ($trimmed -notmatch '^[A-Za-z]:[\\/]') { return $null }
    return $trimmed
}
function Remove-PathQuietly {
    param(
        [Parameter(Position = 0)][string[]]$Path
    )
    foreach ($item in $Path) {
        if ([string]::IsNullOrWhiteSpace($item)) { continue }
        Remove-Item -LiteralPath $item -Force -Recurse -ErrorAction SilentlyContinue
    }
}
function Initialize-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = Test-LocalRootedPath -Path $Path
    if (-not $resolved) {
        throw "Initialize-Directory: refusing to use '$Path' (empty, relative or drive-root path)."
    }
    if (-not (Test-Path -LiteralPath $resolved)) {
        $null = New-Item -Path $resolved -ItemType Directory -Force -ErrorAction Stop
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Initialize-Directory: '$resolved' is not an accessible directory."
    }
    return $resolved
}
function Get-ToolkitOriginalUserContext {
    if ($script:State.UserContext) { return $script:State.UserContext }
    $scope = $script:AppConfig.UserScope
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $originalUser = [Environment]::GetEnvironmentVariable($scope.EnvUser)
    $script:State.UserContext = [pscustomobject]@{
        CurrentUser     = $currentUser
        OriginalUser    = $originalUser
        AccountSwitched = [bool]($originalUser -and $currentUser -and ($originalUser -ne $currentUser))
        UserProfile     = [Environment]::GetEnvironmentVariable($scope.EnvUserProfile)
        Desktop         = [Environment]::GetEnvironmentVariable($scope.EnvDesktop)
        MyDocuments     = [Environment]::GetEnvironmentVariable($scope.EnvMyDocuments)
    }
    return $script:State.UserContext
}
function Get-ToolkitUserFolderPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Desktop', 'MyDocuments')]
        [string]$Kind
    )
    $context = Get-ToolkitOriginalUserContext
    $candidates = @()
    if ($context.AccountSwitched) {
        $original = if ($Kind -eq 'Desktop') { $context.Desktop } else { $context.MyDocuments }
        if ($original) { $candidates += $original }
    }
    try { $candidates += [Environment]::GetFolderPath($Kind, [Environment+SpecialFolderOption]::Create) }
    catch { Write-ToolkitLog -Level 'DEBUG' -Message "GetFolderPath($Kind, Create) failed: $($_.Exception.Message)" }
    try { $candidates += [Environment]::GetFolderPath($Kind) }
    catch { Write-ToolkitLog -Level 'DEBUG' -Message "GetFolderPath($Kind) failed: $($_.Exception.Message)" }
    $registryName = if ($Kind -eq 'Desktop') { 'Desktop' } else { 'Personal' }
    try {
        $shellKey = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name $registryName -ErrorAction Stop
        if ($shellKey.$registryName) {
            $candidates += [Environment]::ExpandEnvironmentVariables([string]$shellKey.$registryName)
        }
    }
    catch { Write-ToolkitLog -Level 'DEBUG' -Message "User Shell Folders\$registryName unreadable: $($_.Exception.Message)" }
    $profileRoot = if ($context.AccountSwitched -and $context.UserProfile) { $context.UserProfile } else { $env:USERPROFILE }
    if ($profileRoot) { $candidates += (Join-Path $profileRoot $Kind) }
    foreach ($candidate in $candidates) {
        $path = Test-LocalRootedPath -Path $candidate
        if (-not $path) { continue }
        try {
            return Initialize-Directory -Path $path
        }
        catch {
            Write-ToolkitLog -Level 'WARNING' -Message "Known folder candidate rejected for ${Kind}: $path ($($_.Exception.Message))"
        }
    }
    throw "Unable to resolve a usable '$Kind' known folder for user '$($context.CurrentUser)'."
}
function Test-FileHasMinimumSize {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$MinimumBytes
    )
    $file = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    return [bool]($file -and -not $file.PSIsContainer -and $file.Length -ge $MinimumBytes)
}
function Resolve-ToolkitPowerShellProfileDirectory {
    [CmdletBinding()]
    param()
    $scope = $script:AppConfig.UserScope
    $documents = Get-ToolkitUserFolderPath -Kind 'MyDocuments'
    $profileDirectory = Initialize-Directory -Path (Join-Path $documents $scope.PowerShellProfileFolder)
    $themesDirectory = Initialize-Directory -Path (Join-Path $profileDirectory $scope.ThemesFolderName)
    return [pscustomobject]@{
        ProfileDirectory = $profileDirectory
        ThemesDirectory  = $themesDirectory
        ProfilePath      = (Join-Path $profileDirectory $scope.ProfileFileName)
        ThemePath        = (Join-Path $themesDirectory $scope.ThemeFileName)
    }
}
function Copy-FileAtomically {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [switch]$Backup
    )
    $targetDir = Split-Path -Path $DestinationPath -Parent
    $null = Initialize-Directory -Path $targetDir
    $stagedPath = Join-Path $targetDir "$([IO.Path]::GetFileName($DestinationPath)).$([guid]::NewGuid()).tmp"
    try {
        Copy-Item -LiteralPath $SourcePath -Destination $stagedPath -Force -ErrorAction Stop
        if ($Backup -and (Test-Path -LiteralPath $DestinationPath -PathType Leaf)) {
            $backupPath = "$DestinationPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            [System.IO.File]::Replace($stagedPath, $DestinationPath, $backupPath, $true)
            return $backupPath
        }
        Move-Item -LiteralPath $stagedPath -Destination $DestinationPath -Force -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $stagedPath) { Remove-Item -LiteralPath $stagedPath -Force -ErrorAction SilentlyContinue }
    }
}
function Get-ArchitectureSpecificValue {
    param(
        [Parameter(Mandatory = $true)][string]$X64,
        [string]$X86 = $X64,
        [string]$ARM64 = $X64
    )
    switch (Get-SystemArchitecture) {
        'ARM64' { return $ARM64 }
        'X86' { return $X86 }
        default { return $X64 }
    }
}
function Wait-Until {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Condition,
        [int]$TimeoutSeconds = 0,
        [int]$IntervalMs = 1000
    )
    if ($TimeoutSeconds -le 0) { $TimeoutSeconds = $script:AppConfig.Timeouts.Condition }
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (& $Condition) { return $true }
        if ((Get-Date) -ge $deadline) { break }
        Start-Sleep -Milliseconds $IntervalMs
    } while ($true)
    return $false
}
function ConvertTo-ProcessArgumentList {
    param([Parameter(Mandatory = $true)][string]$Arguments)
    $tokens = [regex]::Matches($Arguments, '"([^"]*)"|''([^'']*)''|(\S+)')
    return @($tokens | ForEach-Object {
            if ($_.Groups[1].Success) { $_.Groups[1].Value }
            elseif ($_.Groups[2].Success) { $_.Groups[2].Value }
            else { $_.Groups[3].Value }
        })
}
function Invoke-DownloadFile {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Uri,
        [Parameter(Mandatory = $true)][string]$OutFile,
        [switch]$Silent,
        [int]$MinimumBytes = 1,
        [scriptblock]$ContentValidator,
        [int]$RetryCount = 2,
        [int]$RetryIntervalSeconds = 2
    )
    $previousProgress = $ProgressPreference
    $failures = @()
    try {
        $ProgressPreference = 'SilentlyContinue'
        $parentDir = Split-Path -Path $OutFile -Parent
        if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
            $null = New-Item -Path $parentDir -ItemType Directory -Force -ErrorAction Stop
        }
        foreach ($candidate in $Uri) {
            if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
            for ($attempt = 0; $attempt -le $RetryCount; $attempt++) {
                try {
                    Remove-PathQuietly -Path $OutFile
                    Invoke-WebRequest -Uri $candidate -OutFile $OutFile -ErrorAction Stop
                    $downloaded = Get-Item -LiteralPath $OutFile -ErrorAction Stop
                    if ($downloaded.PSIsContainer) { throw 'The response is not a file.' }
                    if ($downloaded.Length -lt $MinimumBytes) {
                        throw "Only $($downloaded.Length) bytes received (expected at least $MinimumBytes)."
                    }
                    if ($ContentValidator -and -not (& $ContentValidator $OutFile)) {
                        throw 'The downloaded content did not pass validation.'
                    }
                    Write-ToolkitLog -Level 'INFO' -Message "Downloaded '$candidate' -> $OutFile ($($downloaded.Length) bytes)."
                    return $true
                }
                catch {
                    $failures += "${candidate}: $($_.Exception.Message)"
                    Write-ToolkitLog -Level 'WARNING' -Message "Download attempt failed ($candidate, try $($attempt + 1)/$($RetryCount + 1)): $($_.Exception.Message)"
                    Remove-PathQuietly -Path $OutFile
                    if ($attempt -lt $RetryCount) { Start-Sleep -Seconds $RetryIntervalSeconds }
                }
            }
        }
        $detail = if ($failures.Count -gt 0) { ($failures | Select-Object -Unique) -join ' | ' } else { 'no candidate URL provided' }
        if (-not $Silent) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.downloadError0' -Args @($detail))
        }
        Write-ToolkitLog -Level 'ERROR' -Message "Download failed for $OutFile after $($Uri.Count) candidate(s): $detail"
        return $false
    }
    catch {
        if (-not $Silent) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.downloadError0' -Args @($_.Exception.Message))
        }
        Write-ToolkitLog -Level 'WARNING' -Message "Download failed ($OutFile): $($_.Exception.Message)"
        return $false
    }
    finally {
        $ProgressPreference = $previousProgress
    }
}
function Test-DownloadedSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$ExpectedSigners
    )
    try {
        $signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Signature could not be read for '$Path': $($_.Exception.Message)"
        return $false
    }
    if ($signature.Status -ne 'Valid') {
        Write-ToolkitLog -Level 'WARNING' -Message "Invalid or untrusted signature on '$Path': status=$($signature.Status)"
        return $false
    }
    $subject = [string]$signature.SignerCertificate.Subject
    foreach ($expected in $ExpectedSigners) {
        if ($subject -like "*$expected*") {
            Write-ToolkitLog -Level 'INFO' -Message "Signature verified on '$Path': $subject"
            return $true
        }
    }
    Write-ToolkitLog -Level 'WARNING' -Message "Unexpected signer on '$Path': '$subject' (expected one of: $($ExpectedSigners -join ', '))."
    return $false
}
function New-SignatureValidator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ProfileKey,
        [switch]$BlockOnInvalid
    )
    if (-not $script:AppConfig.DownloadSignatures.ContainsKey($ProfileKey)) {
        throw "Unknown signature profile '$ProfileKey'. Known: $($script:AppConfig.DownloadSignatures.Keys -join ', ')"
    }
    $signers = @($script:AppConfig.DownloadSignatures[$ProfileKey])
    $block = $BlockOnInvalid.IsPresent
    $signatureCheck = ${function:Test-DownloadedSignature}
    $validator = {
        param($candidatePath)
        $ok = & $signatureCheck -Path $candidatePath -ExpectedSigners $signers
        if (-not $ok -and $block) {
            throw "Signature verification failed for '$candidatePath': the file will not be installed."
        }
        return $ok
    }
    return $validator.GetNewClosure()
}
function Install-RemoteFile {
    param(
        [Parameter(Mandatory = $true)][string[]]$Url,
        [Parameter(Mandatory = $true)][string]$Destination,
        [int]$MinimumBytes = 1,
        [switch]$Backup,
        [int]$BackupRetention = 3
    )
    $stagedPath = Join-Path $script:AppConfig.Paths.Temp ("wt-stage-{0}.tmp" -f [guid]::NewGuid())
    try {
        if (-not (Invoke-DownloadFile -Uri $Url -OutFile $stagedPath -Silent -MinimumBytes $MinimumBytes)) {
            return $false
        }
        if ((Test-Path -LiteralPath $Destination -PathType Leaf) -and
            ((Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -eq
             (Get-FileHash -LiteralPath $stagedPath -Algorithm SHA256).Hash)) {
            Write-ToolkitLog -Level 'INFO' -Message "Already up to date, not rewritten: $Destination"
            return $true
        }
        $null = Initialize-Directory -Path (Split-Path -Path $Destination -Parent)
        $backupPath = Copy-FileAtomically -SourcePath $stagedPath -Destination $Destination -Backup
        if (-not (Test-FileHasMinimumSize -Path $Destination -MinimumBytes $MinimumBytes)) {
            Write-ToolkitLog -Level 'ERROR' -Message "Installed file is smaller than expected: $Destination"
            return $false
        }
        if ($backupPath) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.existingProfileSaved0' -Args @($backupPath))
            Remove-ExpiredBackups -Path "$Destination.bak.*" -Keep $BackupRetention
        }
        return $true
    }
    finally {
        Remove-PathQuietly -Path $stagedPath
    }
}
function Remove-ExpiredBackups {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Keep = 3
    )
    $backups = @(Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending)
    if ($backups.Count -le $Keep) { return }
    Remove-PathQuietly -Path @($backups[$Keep..($backups.Count - 1)].FullName)
}
function New-ExternalCommandResult {
    param(
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int[]]$AcceptedExitCodes = @(0),
        [bool]$TimedOut = $false,
        [string]$StdOut = '',
        [string]$StdErr = '',
        [int]$DurationMs = 0,
        [string]$Error = ''
    )
    return [pscustomobject]@{
        ExitCode   = $ExitCode
        TimedOut   = $TimedOut
        Accepted   = (-not $TimedOut) -and ($AcceptedExitCodes -contains $ExitCode)
        StdOut     = $StdOut
        StdErr     = $StdErr
        DurationMs = $DurationMs
        Command    = "$FilePath $($ArgumentList -join ' ')"
        Error      = $Error
    }
}
function Invoke-ExternalCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int]$TimeoutSeconds = 120,
        [int[]]$AcceptedExitCodes = @(0)
    )
    $proc = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $commandLine = "$FilePath $($ArgumentList -join ' ')"
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $FilePath
        foreach ($argument in $ArgumentList) { $psi.ArgumentList.Add([string]$argument) }
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $null = $proc.Start()
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()
        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            try { $proc.Kill($true) } catch { try { $proc.Kill() } catch {
                Write-ToolkitLog -Level 'WARNING' -Message "Invoke-ExternalCommand: $($_.Exception.Message)"
            } }
            $null = $proc.WaitForExit()
            Write-ToolkitLog -Level 'ERROR' -Message "External command timed out after $TimeoutSeconds s: $commandLine"
            return New-ExternalCommandResult -ExitCode -2 -TimedOut $true -DurationMs $stopwatch.ElapsedMilliseconds -FilePath $FilePath -ArgumentList $ArgumentList -AcceptedExitCodes $AcceptedExitCodes
        }
        $capturedOut = try { $outTask.GetAwaiter().GetResult() } catch { '' }
        $capturedErr = try { $errTask.GetAwaiter().GetResult() } catch { '' }
        $limit = $script:AppConfig.MaxCapturedOutputChars
        $stdOut = if ($capturedOut.Length -gt $limit) { $capturedOut.Substring(0, $limit) } else { $capturedOut }
        $stdErr = if ($capturedErr.Length -gt $limit) { $capturedErr.Substring(0, $limit) } else { $capturedErr }
        return New-ExternalCommandResult -ExitCode $proc.ExitCode -FilePath $FilePath -ArgumentList $ArgumentList -AcceptedExitCodes $AcceptedExitCodes -StdOut $stdOut -StdErr $stdErr -DurationMs $stopwatch.ElapsedMilliseconds
    }
    catch {
        Write-ToolkitLog -Level 'ERROR' -Message "External command failed ($FilePath): $($_.Exception.Message)"
        return New-ExternalCommandResult -ExitCode -1 -FilePath $FilePath -ArgumentList $ArgumentList -AcceptedExitCodes $AcceptedExitCodes -DurationMs $stopwatch.ElapsedMilliseconds -Error $_.Exception.Message
    }
    finally {
        $stopwatch.Stop()
        if ($proc) { $proc.Dispose() }
    }
}
function Install-FromGitHubRelease {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ReleaseApiUrl,
        [Parameter(Mandatory = $true)][string]$AssetPattern,
        [Parameter(Mandatory = $true)][string]$ExecutablePath,
        [string[]]$InstallerArguments = @(),
        [int[]]$AcceptedExitCodes = @(0),
        [int]$TimeoutSeconds = 300
    )
    $downloadPath = $null
    try {
        $release = Invoke-RestMethod -Uri $ReleaseApiUrl -UseBasicParsing -ErrorAction Stop
        $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
        if (-not $asset) { throw "No release asset matched '$AssetPattern'." }
        $downloadPath = Join-Path $script:AppConfig.Paths.Temp $asset.name
        if (-not (Invoke-DownloadFile -Uri $asset.browser_download_url -OutFile $downloadPath `
                    -ContentValidator (New-SignatureValidator -ProfileKey 'git' -BlockOnInvalid))) {
            throw "Unable to download the release asset $($asset.name) or its signature is not trusted."
        }
        $installerArgs = @($InstallerArguments | ForEach-Object {
                $_ -replace '\{INSTALLER\}', $downloadPath
            })
        if ($ExecutablePath -eq '{INSTALLER}') { $ExecutablePath = $downloadPath }
        $result = Invoke-ExternalCommand -FilePath $ExecutablePath -ArgumentList $installerArgs `
            -TimeoutSeconds $TimeoutSeconds -AcceptedExitCodes $AcceptedExitCodes
        return [pscustomobject]@{
            Success  = [bool]$result.Accepted
            ExitCode = $result.ExitCode
            Asset    = $asset.name
            TimedOut = $result.TimedOut
        }
    }
    catch {
        return [pscustomobject]@{ Success = $false; ExitCode = -1; Error = $_.Exception.Message; TimedOut = $false }
    }
    finally {
        if ($downloadPath -and (Test-Path $downloadPath)) {
            Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
        }
    }
}
function New-StepResult {
    param(
        [Parameter(Mandatory = $true)][bool]$Success,
        [bool]$Changed = $false,
        [string]$Message = '',
        [switch]$Skipped
    )
    return [pscustomobject]@{
        Success  = $Success
        Changed  = $Changed
        Message  = $Message
        Skipped  = [bool]$Skipped
        Blocking = $false
    }
}
function Add-SetupResult {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(ParameterSetName = 'Result')][object]$Result,
        [Parameter(ParameterSetName = 'Fields', Mandatory = $true)][bool]$Success,
        [Parameter(ParameterSetName = 'Fields')][bool]$Changed = $false,
        [Parameter(ParameterSetName = 'Fields')][string]$Message = '',
        [bool]$Blocking = $false,
        [switch]$Skipped
    )
    $stepSkipped = $Skipped.IsPresent
    $stepSuccess = $false
    $stepChanged = $false
    $stepMessage = ''
    if ($PSCmdlet.ParameterSetName -eq 'Result') {
        $stepSuccess = [bool]$Result.Success
        $stepChanged = [bool]$Result.Changed
        $stepMessage = [string]$Result.Message
        $stepSkipped = $stepSkipped -or [bool]$Result.Skipped
        $Blocking = $Blocking -or [bool]$Result.Blocking
    }
    else {
        $stepSuccess = $Success
        $stepChanged = $Changed
        $stepMessage = $Message
    }
    $status = if ($stepSkipped) { 'Skipped' }
    elseif ($stepSuccess) { if ($stepChanged) { 'Changed' } else { 'Succeeded' } }
    else { 'Failed' }
    $script:State.Results.Add([pscustomobject]@{
            Name = $Name; Status = $status; Message = $stepMessage; Blocking = $Blocking
        })
}
function Write-SetupSummary {
    $counts = @{}
    foreach ($status in @('Succeeded', 'Changed', 'Failed', 'Skipped')) {
        $counts[$status] = @($script:State.Results | Where-Object Status -eq $status).Count
    }
    $counters = @('Succeeded', 'Changed', 'Failed', 'Skipped') | ForEach-Object {
        '{0}={1}' -f (Get-SourceTextLoc "summary.$($_.ToLowerInvariant())"), $counts[$_]
    }
    $summaryText = '{0}: {1}.' -f (Get-SourceTextLoc 'summary.title'), ($counters -join ' ')
    Write-StyledMessage -Type Info -Text $summaryText
    foreach ($result in $script:State.Results | Where-Object Status -eq 'Failed') {
        $level = if ($result.Blocking) { 'Error' } else { 'Warning' }
        Write-StyledMessage -Type $level -Text "$($result.Name): $($result.Message)"
    }
    $hasBlockingFailure = @($script:State.Results | Where-Object { $_.Status -eq 'Failed' -and $_.Blocking }).Count -gt 0
    $hasFailure = @($script:State.Results | Where-Object Status -eq 'Failed').Count -gt 0
    if ($hasBlockingFailure) { return 1 }
    if ($hasFailure) { return 2 }
    return 0
}
function Invoke-WinToolkitSetup {
    param([string]$Language = 'Auto')
    $script:State.Results.Clear()
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            throw 'start-core.ps1 requires PowerShell 7 or later. Run start.ps1 instead.'
        }
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'start-core.ps1 must be started by the elevated start.ps1 stub.'
        }
        $ErrorActionPreference = 'Stop'
        $Host.UI.RawUI.WindowTitle = 'Toolkit Starter by MagnetarMan'
        Start-ToolkitLog 'WinToolkitStarter'
        $null = Resolve-SourceTextLanguage -RequestedLanguage $Language
        Initialize-UpdateServicesState
        Show-Header -Title $script:AppConfig.Header.Title -Version $script:AppConfig.Header.Version
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.powershell0' -Args @($PSVersionTable.PSVersion))
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingWinToolkitSetup')
        $null = Request-DefenderPause
        $steps = @(
            @{ Name = 'System clock'; Run = { Repair-SystemClock } }
            @{ Name = 'SCHANNEL'; Run = { Reset-SchannelSettings } }
            @{ Name = 'Hosts file'; Run = { Repair-HostsFileIfNeeded } }
            @{ Name = 'App Installer'; Run = { Repair-AppInstaller } }
            @{ Name = 'WinGet'; Run = { Initialize-Winget }; Blocking = $true }
            @{ Name = 'Git'; Run = { Install-GitPackage } }
            @{ Name = 'Windows Terminal'; Run = { Install-WindowsTerminalApp } }
            @{ Name = 'Default terminal'; Run = { Set-WindowsTerminalAsDefault }; When = { Test-WindowsTerminalInstalled } }
            @{ Name = 'PowerShell environment'; Run = { Install-PspEnvironment } }
            @{ Name = 'User scope alignment'; Run = { Sync-UserScopeWithInstalledTools }
                When = { (Get-ToolkitOriginalUserContext).AccountSwitched } }
            @{ Name = 'Desktop shortcut'; Run = { New-ToolkitDesktopShortcut }
                When = { (Test-WindowsTerminalInstalled) -and (Test-CommandExists -Name 'pwsh') }
            }
        )
        Invoke-StopUpdateServices
        foreach ($step in $steps) {
            if ($step.When -and -not (& $step.When)) {
                Add-SetupResult -Name $step.Name -Success $true -Skipped -Message 'Step not applicable on this system.'
                continue
            }
            $result = & $step.Run
            Add-SetupResult -Name $step.Name -Result $result -Blocking:([bool]$step.Blocking)
            if ($step.Blocking -and -not $result.Success) {
                throw "Required step '$($step.Name)' failed: $($result.Message)"
            }
        }
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.configurationComplete')
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wintoolkitIsReadyOnTheDesktop')
        return (Write-SetupSummary)
    }
    catch {
        Set-UpdateServicesError -Message $_.Exception.Message
        Add-SetupResult -Name 'Setup flow' -Success $false -Message $_.Exception.Message -Blocking $true
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.criticalErrorDuringSetup0' -Args @($_.Exception.Message))
        Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.unhandledException01' -Args @($_.Exception.Message, $_.ScriptStackTrace))
        if (-not [Console]::IsInputRedirected) {
            Write-Host (Get-SourceTextLoc 'sourceText.pressAnyKeyToExit')
            $null = [Console]::ReadKey($true)
        }
        Write-SetupSummary | Out-Null
        return 1
    }
    finally {
        $null = Invoke-StartUpdateServices
        $transcriptMessage = Stop-ToolkitTranscript
        if ($transcriptMessage) {
            Write-StyledMessage -Type Info -Text $transcriptMessage
        }
        $ErrorActionPreference = $previousErrorActionPreference
    }
}
exit (Invoke-WinToolkitSetup -Language $Language)