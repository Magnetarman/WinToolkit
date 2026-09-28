[CmdletBinding()]
param(
    [string]$Language = $(if ($env:WTOOLKIT_LANGUAGE) { $env:WTOOLKIT_LANGUAGE } else { 'Auto' })
)
Set-StrictMode -Version Latest
$script:Branch = 'Dev'
$ToolkitVersion = "2.6.0 (Build 5)"
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
        OhMyPoshTheme     = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
        TerminalRelease   = "https://api.github.com/repos/microsoft/terminal/releases/latest"
        WebInstaller      = "https://magnetarman.com/WinToolkit-Dev"
    }
    Paths            = @{
        Logs          = "$env:LOCALAPPDATA\WinToolkit\logs"
        WinToolkitDir = "$env:LOCALAPPDATA\WinToolkit"
        Languages     = "$env:LOCALAPPDATA\WinToolkit\languages"
        Temp          = "$env:TEMP\WinToolkitSetup"
        Packages      = "$env:LOCALAPPDATA\Packages"
        Desktop       = [Environment]::GetFolderPath('Desktop')
        wtExe         = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
        wtDir         = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    }
    Registry         = @{
        TerminalStartup = "HKCU:\Console\%%Startup"
    }
    WindowsTerminal  = @{
        DelegationTerminalClsid = "{E12F0936-0E6F-548E-A9F6-B20C69A27D17}"
        DelegationConsoleClsid  = "{B23D10C0-31E3-401A-97EF-4BB30B62E10B}"
    }
    EnablePSRemoting = $false
    WingetProcesses  = @(
        'WinStore.App',
        'wsappx',
        'AppInstaller',
        'Microsoft.WindowsStore',
        'Microsoft.DesktopAppInstaller',
        'winget',
        'WindowsPackageManagerServer'
    )
    UpdateServices   = @('wuauserv', 'bits', 'cryptsvc', 'dosvc')
    Layout           = @{
        Width = 65
    }
}
$script:AppConfig.URLs.StartScript = "$script:RepoRawBase/start.ps1"
$script:AppConfig.URLs.PowerShellProfile = "$script:RepoBase/assets/Microsoft.PowerShell_profile.ps1"
$script:AppConfig.URLs.WindowsTerminalSettings = "$script:RepoBase/assets/settings.json"
$script:AppConfig.URLs.ToolkitIcon = "$script:RepoRawBase/images/WinToolkit.ico"
$script:AppConfig.URLs.LanguagesRawUrl = "$script:RepoBase/languages"
$script:AppConfig.URLs.LanguagesApiUrl = "https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=$script:Branch"
$script:EXITCODE_ACCESS_VIOLATION = 3221225477
$script:EXITCODE_ACCESS_VIOLATION_SIGNED = -1073741819
$script:LNK_RUNAS_ADMIN_BYTE_OFFSET = 21
$script:LNK_RUNAS_ADMIN_BIT = 32
$script:MIN_ICON_FILE_BYTES = 1024
$script:UpdateServicesSuspended = $false
$script:CurrentLogFile = $null
$script:SetupResults = @()
$script:SetupExitCode = 1
enum WingetRepairLevel {
    SourceReset
    MsStoreCert
    AppxReset
    CoreInstall
    FullDatabase
    FullReinstall
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
        Write-Warning "start-modules\10-Module.Logging.ps1, Stop-ToolkitTranscript: $($_.Exception.Message)"
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
    $script:CurrentLogFile = "$logdir\${ToolName}_${dateTime}_$PID.log"
    Start-Transcript -Path "$logdir\${ToolName}_${dateTime}_$PID.transcript.log" -Append -Force | Out-Null
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $psVer = $PSVersionTable.PSVersion.ToString()
    $header = @"
[START LOG HEADER]
Start time     : $dateTime
ToolName       : $ToolName
OS             : $($os.Caption) $($os.Version)
PSVersion      : $psVer
ToolkitVersion : $script:AppConfig.Header.Version
[END LOG HEADER]
"@
    try { Add-Content -Path $script:CurrentLogFile -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue } catch {
        Write-Warning "start-modules\10-Module.Logging.ps1, Start-ToolkitLog: $($_.Exception.Message)"
    }
}
function Write-ToolkitLog {
    param(
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',
        [string]$Message
    )
    if (-not $script:CurrentLogFile) { return }
    $ts = Get-Date -Format "HH:mm:ss"
    $clean = $Message -replace '^\s+', ''
    $clean = $clean -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
    $line = "[$ts] [$Level] $clean"
    try { Add-Content -Path $script:CurrentLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch {
        Write-Warning "start-modules\10-Module.Logging.ps1, Write-ToolkitLog: $($_.Exception.Message)"
    }
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
    $root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
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
    Invoke-SourceTextLanguagePruning -LocalDir $localDir -AllowedCultures $remoteCultures
    foreach ($culture in (@('en-US') + $remoteCultures | Select-Object -Unique)) {
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
function Format-SourceText {
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
    $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
    $env:Path = $newPath
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
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
        $status = (w32tm /query /status 2>$null | Out-String)
        $needsRepair = ($LASTEXITCODE -ne 0 -or $status -notmatch 'Last Successful Sync Time')
        if (-not $needsRepair) {
            return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'System clock already synchronized.' }
        }
        $w32Time = Get-Service w32time -ErrorAction SilentlyContinue
        if ($w32Time -and $w32Time.Status -ne 'Running') {
            Start-Service w32time -ErrorAction Stop | Out-Null
            $changed = $true
        }
        w32tm /resync /force 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "w32tm resync failed with exit code $LASTEXITCODE." }
        $changed = $true
        Write-StyledMessage -Type Success -Text ("🕒 " + (Get-SourceTextLoc 'uiText.systemClockResynced'))
        return [pscustomobject]@{ Success = $true; Changed = $changed; Message = 'System clock synchronized.' }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "System clock resync failed: $($_.Exception.Message)"
        return [pscustomobject]@{ Success = $false; Changed = $changed; Message = $_.Exception.Message }
    }
}
function Reset-SchannelSettings {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not $PSCmdlet.ShouldProcess('SCHANNEL registry keys', 'Reset TLS/cipher settings')) { return }
    $changed = $false
    try {
        $schannelPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL'
        if (-not (Test-Path $schannelPath)) { return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'SCHANNEL key not present.' } }
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
        $cipherPath = Join-Path $schannelPath 'Ciphers'
        if (Test-Path $cipherPath) {
            Get-ChildItem $cipherPath -ErrorAction SilentlyContinue |
            Where-Object { $_.PSIsContainer } |
            ForEach-Object {
                $prop = Get-ItemProperty -Path $_.FullName -Name 'Enabled' -ErrorAction SilentlyContinue
                if ($prop -and $prop.Enabled -eq 0) {
                    Remove-ItemProperty -Path $_.FullName -Name 'Enabled' -ErrorAction SilentlyContinue
                    $changed = $true
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.schannelCipherReenabled0' -Args @($_.PSChildName))
                    Write-ToolkitLog -Level 'INFO' -Message "Removed disabled cipher: $($_.PSChildName)"
                }
            }
        }
        return [pscustomobject]@{ Success = $true; Changed = $changed; Message = if ($changed) { 'SCHANNEL settings repaired.' } else { 'SCHANNEL settings already valid.' } }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "SCHANNEL reset failed: $($_.Exception.Message)"
        return [pscustomobject]@{ Success = $false; Changed = $changed; Message = $_.Exception.Message }
    }
}
function Reset-HostsFile {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not $PSCmdlet.ShouldProcess('C:\Windows\System32\drivers\etc\hosts', 'Reset hosts file')) { return }
    try {
        $hostsPath = 'C:\Windows\System32\drivers\etc\hosts'
        if (-not (Test-Path $hostsPath)) { return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'Hosts file not present.' } }
        $lines = Get-Content $hostsPath -ErrorAction SilentlyContinue
        if (-not $lines) { return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'Hosts file is empty.' } }
        $blockedPattern = '(?i)microsoft\.com|storeedgefd|winget\.azureedge\.net'
        $newLines = @($lines | Where-Object { $_ -notmatch $blockedPattern })
        $hasOverrides = $newLines.Count -ne $lines.Count
        if ($hasOverrides) {
            $backupDir = Initialize-Directory -Path $script:AppConfig.Paths.WinToolkitDir
            $backupPath = Join-Path $backupDir ("hosts.backup.{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
            Copy-Item -LiteralPath $hostsPath -Destination $backupPath -Force -ErrorAction Stop
            $hostsHeader = @(
                '# Copyright (c) 1993-2009 Microsoft Corp.',
                '# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.',
                '#',
                '# This file contains the mappings of IP addresses to host names. Each',
                '# entry should be kept on an individual line. The IP address should',
                '# be placed in the first column followed by the corresponding host name.',
                '# The IP address and the host name should be separated by at least one',
                '# space.',
                '#',
                '# Additionally, comments (such as these) may be inserted on individual',
                '# lines or following the machine name denoted by a ''#'' symbol.',
                '#',
                '# For example:',
                '#      102.54.94.97     rhino.acme.com          # source server',
                '#       38.25.63.10     x.acme.com              # x client host'
            )
            $finalContent = $hostsHeader + ($newLines | Where-Object { $_.Trim() -ne '' })
            Set-Content -Path $hostsPath -Value $finalContent -Encoding ASCII -Force
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.hostsFileModifiedBackupSaved0' -Args @($backupPath))
            Write-ToolkitLog -Level 'INFO' -Message "Hosts file reset: removed Microsoft/Store/Winget overrides"
            return [pscustomobject]@{ Success = $true; Changed = $true; Message = "Hosts reset; backup: $backupPath" }
        }
        return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'No blocked hosts overrides found.' }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Hosts file reset failed: $($_.Exception.Message)"
        return [pscustomobject]@{ Success = $false; Changed = $false; Message = $_.Exception.Message }
    }
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
function Invoke-StopUpdateServices {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not $PSCmdlet.ShouldProcess('Windows Update services', 'Suspend services')) { return }
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.temporarilySuspendWindowsUpdateServicesToAvoidConflicts')
    $savedServices = @()
    foreach ($svc in $script:AppConfig.UpdateServices) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            $cimService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$svc'" -ErrorAction Stop
            $savedServices += [pscustomobject]@{
                Name      = $svc
                Present   = $true
                Status    = [string]$service.Status
                StartType = [string]$cimService.StartMode
            }
        }
    }
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
        $script:UpdateServicesSuspended = $true
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updateServicesSuccessfullySuspended')
    }
    catch {
        Set-UpdateServicesState -Status $status -State 'RestoreFailed' -LastError $_.Exception.Message
        throw
    }
}
function Invoke-StartUpdateServices {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not $PSCmdlet.ShouldProcess('Windows Update services', 'Restore services')) { return }
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
                default { 'Manual' }
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
        $dosvcErrors = @($restoreErrors | Where-Object { $_ -match '^dosvc:' })
        $otherErrors = @($restoreErrors | Where-Object { $_ -notmatch '^dosvc:' })
        if ($otherErrors.Count -gt 0) {
            Set-UpdateServicesState -Status $status -State 'RestoreFailed' -LastError ($otherErrors -join '; ')
            Write-ToolkitLog -Level 'ERROR' -Message "Unable to restore Windows Update services: $($status.LastError)"
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.updateServicesRestoreIncomplete0' -Args @($status.LastError))
            return $false
        }
        if ($dosvcErrors.Count -gt 0) {
            Set-UpdateServicesState -Status $status -State 'Restored'
            Write-ToolkitLog -Level 'WARNING' -Message "Windows Update service dosvc could not be restored (known Windows limitation): $dosvcErrors -join '; '"
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.dosvcNotRestoredKnownLimitation')
        }
    }
    Set-UpdateServicesState -Status $status -State 'Restored'
    $script:UpdateServicesSuspended = $false
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
    $errFile = Join-Path $env:TEMP "AppxError_$([guid]::NewGuid()).txt"
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
            `$_.Exception.Message | Out-File '$errFile' -Encoding UTF8; exit 1
        }
    }
    `$_.Exception.Message | Out-File '$errFile' -Encoding UTF8; exit 1
}
exit 0
"@
    $encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
    $result = Invoke-ExternalCommand -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-NonInteractive', '-EncodedCommand', $encodedCmd) -TimeoutSeconds $TimeoutSeconds
    try {
        if ($result.TimedOut) {
            Write-ToolkitLog -Level 'ERROR' -Message "AppX installation timeout after $TimeoutSeconds seconds: $AppxPath"
            return $false
        }
        if ($result.ExitCode -ne 0) {
            $errMsg = if (Test-Path $errFile) { Get-Content $errFile -Raw } else { '' }
            Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.appxInstallFailed01' -Args @($AppxPath, $errMsg))
            return $false
        }
        if ($ExpectedPackageName -and
            -not (Get-AppxPackage -Name $ExpectedPackageName -ErrorAction SilentlyContinue)) {
            Write-ToolkitLog -Level 'ERROR' -Message "AppX command succeeded but package verification failed: $ExpectedPackageName"
            return $false
        }
        return $true
    }
    finally {
        if (Test-Path $errFile) {
            Remove-Item $errFile -Force -ErrorAction SilentlyContinue
        }
    }
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
function Invoke-WingetCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Arguments,
        [int]$TimeoutSeconds = 120,
        [switch]$CaptureOutput
    )
    try {
        $wingetExe = Get-WinGetExecutable
        if (-not $wingetExe) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInSystem')
            return New-ExternalCommandResult -ExitCode -1 -FilePath 'winget.exe' -ArgumentList @($Arguments) -Error 'WinGet executable not found.'
        }
        $versionRaw = (& $wingetExe --version 2>$null) | Out-String
        $isModern = $versionRaw -match 'v1\.[4-9]' -or $versionRaw -match 'v[2-9]'
        $finalArgs = if ($isModern) { "$Arguments --disable-interactivity" } else { $Arguments }
        $result = Invoke-ExternalCommand -FilePath $wingetExe -ArgumentList (ConvertTo-ProcessArgumentList -Arguments $finalArgs) -TimeoutSeconds $TimeoutSeconds -CaptureOutput:$CaptureOutput
        if ($result.TimedOut) {
            Write-ToolkitLog -Level 'ERROR' -Message "Winget timeout after $TimeoutSeconds seconds: $Arguments"
        }
        return $result
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetCommandError0' -Args @($_.Exception.Message))
        return New-ExternalCommandResult -ExitCode -1 -FilePath 'winget.exe' -ArgumentList @($Arguments) -Error $_.Exception.Message
    }
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
        $result = Invoke-WingetCommand -Arguments 'source update --source msstore --accept-source-agreements' -CaptureOutput
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
            if (-not (Invoke-DownloadFile -Uri $script:AppConfig.URLs.WingetMSIX -OutFile $tempFile)) {
                throw 'App Installer bundle download failed.'
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
function Test-WingetFunctionality {
    Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.checkWingetFunctionality'))
    Update-EnvironmentPath
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInPath')
        return $false
    }
    try {
        $result = Invoke-WingetCommand -Arguments '--version' -CaptureOutput
        $versionOutput = $result.StdOut.Trim()
        if ($result.ExitCode -eq 0 -and $versionOutput -match 'v\d+\.\d+') {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.operationalWingetVersion0' -Args @($versionOutput))
            return $true
        }
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetPresentButNotRespondingCorrectlyExitcode0' -Args @($result.ExitCode))
        return $false
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.errorDuringWingetTest0' -Args @($_.Exception.Message))
        return $false
    }
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
    Add-ToEnvironmentPath -PathToAdd "%LOCALAPPDATA%\Microsoft\WindowsApps" -Scope 'User'
    if ($aliasRegistered) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.pathAndWingetPermissionsUpdated')
    }
}
function Invoke-WinGetPackageManagerRepair {
    if (-not (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue)) {
        return $false
    }
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.tentativoRiparazioneWingetRepairWingetpackagemanager')
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
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.puliziaCacheWinget')
            Get-ChildItem -Path $wingetCachePath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\lock\\|\\tmp\\' } |
            ForEach-Object {
                try {
                    Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Warning "start-modules\40-Module.Winget.ps1, Repair-WingetDatabase cache: $($_.Exception.Message)"
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
            Write-Warning "start-modules\40-Module.Winget.ps1, Repair-WingetDatabase manifest: $($_.Exception.Message)"
        }
        $null = Invoke-WinGetPackageManagerRepair
        Set-WingetPathPermissions
        Update-EnvironmentPath
        Start-Sleep 2
        $versionResult = Invoke-WingetCommand -Arguments '--version' -CaptureOutput
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
    param([Parameter(Mandatory = $true)][long]$ExitCode)
    return $ExitCode -eq $script:EXITCODE_ACCESS_VIOLATION_SIGNED -or $ExitCode -eq $script:EXITCODE_ACCESS_VIOLATION
}
function Test-WingetDeepValidation {
    Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.deepTestExecutionOfWingetSearchForPacketsOnTheNetwork'))
    try {
        $searchResult = Invoke-WingetCommand -Arguments 'search Git.Git --accept-source-agreements' -CaptureOutput
        $exitCode = $searchResult.ExitCode
        if (Test-WingetAccessViolation -ExitCode $exitCode) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.crashDetectedExitcode0AccessViolationAdvancedRecoveryAttempt' -Args @($exitCode))
            $recoverySteps = @(
                @{ Level = 'FullDatabase'; WarningKey = $null; InfoKey = 'uiText.repeatTestAfterDatabaseRestore' },
                @{ Level = 'FullReinstall'; WarningKey = 'uiText.persistentCrashStartingCompleteReinstallationOfWinget'; InfoKey = 'uiText.finalTestAfterReinstallation' }
            )
            foreach ($step in $recoverySteps) {
                if ($step.WarningKey) {
                    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc $step.WarningKey)
                }
                $null = Repair-Winget -Level $step.Level
                Write-StyledMessage -Type Info -Text ("🔄 " + (Get-SourceTextLoc $step.InfoKey))
                Start-Sleep 3
                $searchResult = Invoke-WingetCommand -Arguments 'search Git.Git --accept-source-agreements' -CaptureOutput
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
            if (-not (Invoke-DownloadFile -Uri $vcUrl -OutFile $vcFile)) {
                throw 'Visual C++ Redistributable download failed.'
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
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadWingetDependenciesFromTheOfficialRepository')
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
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadAndInstallWingetBundleWithDependencies')
        $wingetUrl = Get-WingetDownloadUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        if (-not $wingetUrl) {
            throw (Get-SourceTextLoc 'uiText.wingetCoreInstallationFailed')
        }
        $wingetFile = Join-Path $tempDir "winget.msixbundle"
        if (-not (Invoke-DownloadFile -Uri $wingetUrl -OutFile $wingetFile -Silent)) {
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
function Install-WingetPackage {
    param([switch]$Force)
    Write-StyledMessage -Type Info -Text ("🚀 " + (Get-SourceTextLoc 'uiText.startWingetInstallationVerificationProcedure'))
    if (-not (Test-WingetCompatibility)) {
        return $false
    }
    Invoke-ForceCloseWinget
    $tempInstaller = $null
    $oldProgress = $ProgressPreference
    try {
        $ProgressPreference = 'SilentlyContinue'
        $tempPath = "$env:TEMP\WinGet"
        if (Test-Path $tempPath) {
            Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Reset-WingetSources
        }
        if (-not (Get-Module -ListAvailable Microsoft.WinGet.Client) -or $Force) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingMicrosoftWingetClientModule')
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetClientModuleInstalled')
            }
            catch {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.moduloWingetClient0' -Args @($_.Exception.Message))
            }
        }
        Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
        if (Invoke-WinGetPackageManagerRepair) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerEseguito')
        }
        Start-Sleep 3
        if (-not (Get-Command winget -ErrorAction SilentlyContinue) -or $Force) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadMsixbundleDaMicrosoft')
            $msixTempDir = Initialize-Directory -Path $script:AppConfig.Paths.Temp
            $tempInstaller = Join-Path $msixTempDir "WingetInstaller.msixbundle"
            if (-not (Invoke-DownloadFile -Uri $script:AppConfig.URLs.WingetMSIX -OutFile $tempInstaller -Silent)) {
                throw 'WinGet MSIX bundle download failed.'
            }
            if (Start-AppxSilentProcess -AppxPath $tempInstaller -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.DesktopAppInstaller') {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetMsixBundleInstallationSuccessful')
            }
            else {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetMsixBundleInstallationFailed')
            }
            Start-Sleep 3
        }
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetAppInstaller')
        try {
            Reset-AppInstallerPackage
        }
        catch {
            Write-Warning "start-modules\40-Module.Winget.ps1, Install-WingetPackage: $($_.Exception.Message)"
        }
        Set-WingetPathPermissions
        Start-Sleep 2
        Update-EnvironmentPath
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetInstalledAndWorking')
            return $true
        }
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.unableToInstallWinget')
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.criticalError0' -Args @($_.Exception.Message))
        return $false
    }
    finally {
        if ($tempInstaller -and (Test-Path -LiteralPath $tempInstaller)) {
            Remove-Item -LiteralPath $tempInstaller -Force -ErrorAction SilentlyContinue
        }
        $ProgressPreference = $oldProgress
    }
}
function Repair-Winget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [WingetRepairLevel]$Level
    )
    Write-ToolkitLog -Level 'INFO' -Message "Starting WinGet repair level: $Level"
    switch ($Level) {
        'SourceReset' {
            Reset-WingetSources
            return $true
        }
        'MsStoreCert' {
            Repair-WingetMsStoreSource
            return $true
        }
        'AppxReset' {
            $result = Repair-AppInstaller
            return [bool]$result.Success
        }
        'CoreInstall' {
            return [bool](Install-WingetCore)
        }
        'FullDatabase' {
            return [bool](Repair-WingetDatabase)
        }
        'FullReinstall' {
            return [bool](Install-WingetPackage -Force)
        }
        default {
            throw "Unsupported WinGet repair level: $Level"
        }
    }
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
    $checksPassed = 0
    if (Test-VCRedistRuntime -RuntimeName 'x86' -DllPath "$env:windir\syswow64\concrt140.dll") { $checksPassed++ }
    if ($architecture -ne 'X86') {
        $nativeRuntime = Get-ArchitectureSpecificValue -X64 'x64' -ARM64 'arm64'
        if (Test-VCRedistRuntime -RuntimeName $nativeRuntime -DllPath "$env:windir\system32\concrt140.dll") { $checksPassed++ }
    }
    $requiredChecks = if ($architecture -eq 'X86') { 1 } else { 2 }
    return $checksPassed -eq $requiredChecks
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
        $result = Invoke-WingetCommand -Arguments "install Git.Git --source winget --accept-source-agreements --accept-package-agreements --silent"
        if ($result.ExitCode -eq 0) {
            Update-EnvironmentPath
            if (Wait-Until -Condition { Test-CommandExists -Name git } -TimeoutSeconds 15 -IntervalMs 1000) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitInstalledViaWinget')
                return $true
            }
        }
    }
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.fallbackDownloadGitDaGithub')
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
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.gitInstallationError0' -Args @($_.Exception.Message))
        return $false
    }
}
function Install-PowerShellCore {
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.verificaPowershell7')
    $ps7Path64 = "$env:SystemDrive\Program Files\PowerShell\7"
    $ps7Path32 = "$env:SystemDrive\Program Files (x86)\PowerShell\7"
    if ((Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7AlreadyInstalled')
        return $true
    }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.attemptingToInstallPowershell7ViaWinget')
        $result = Invoke-WingetCommand -Arguments "install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements --silent"
        if ($result.ExitCode -eq 0) {
            if (Wait-Until -Condition {
                    (Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Test-CommandExists -Name pwsh)
                } -TimeoutSeconds 15 -IntervalMs 1000) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7InstallatoViaWinget')
                return $true
            }
        }
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstallationFailedOrFailedExitcode0FallbackToDirectDownload' -Args @($result.ExitCode))
    }
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.recuperoUltimaReleasePowershell')
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingPowershell7InProgress')
        $assetPattern = Get-ArchitectureSpecificValue -X64 'win-x64\.msi$' -X86 'win-x86\.msi$' -ARM64 'win-arm64\.msi$'
        $installerArguments = @('/i', '{INSTALLER}', '/norestart', '/passive',
            'ADD_PATH=1', 'ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1', 'REGISTER_MANIFEST=1')
        if ($script:AppConfig.EnablePSRemoting) {
            $installerArguments += 'ENABLE_PSREMOTING=1'
        }
        $installResult = Install-FromGitHubRelease -ReleaseApiUrl $script:AppConfig.URLs.PowerShellRelease `
            -AssetPattern $assetPattern -ExecutablePath 'msiexec.exe' `
            -InstallerArguments $installerArguments `
            -AcceptedExitCodes @(0, 1641, 3010)
        if ((Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Test-CommandExists -Name pwsh) -or $installResult.Success) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7InstalledSuccessfully')
            return $true
        }
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.installationFailedCode02' -Args @($installResult.ExitCode))
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.powershellInstallationError0' -Args @($_.Exception.Message))
        return $false
    }
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
            $result = Invoke-WingetCommand -Arguments "install --id Microsoft.WindowsTerminal --source winget --accept-source-agreements --accept-package-agreements --silent"
            if ($result.ExitCode -eq 0 -and (Wait-Until -Condition { Test-WindowsTerminalInstalled } -TimeoutSeconds 15 -IntervalMs 1000)) {
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
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.iTryNativeAppxInstallationFromDownloadedBundle')
        $tempFile = Join-Path $env:TEMP "WinTerminal.msixbundle"
        if (-not (Invoke-DownloadFile -Uri $downloadUrl -OutFile $tempFile)) {
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
    $downloadedPath = Join-Path $script:AppConfig.Paths.Temp "wt-settings-$([guid]::NewGuid()).json"
    try {
        if (-not (Invoke-DownloadFile -Uri $script:AppConfig.URLs.WindowsTerminalSettings -OutFile $downloadedPath -Silent)) {
            return $false
        }
        $backupPath = Copy-FileAtomically -SourcePath $downloadedPath -DestinationPath $SettingsPath -Backup
        if ($backupPath) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.windowsTerminalSettingsOverwrittenBackup0' -Args @($backupPath))
        }
        return $true
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Windows Terminal settings update skipped: $($_.Exception.Message)"
        return $false
    }
    finally {
        if (Test-Path -LiteralPath $downloadedPath) { Remove-Item -LiteralPath $downloadedPath -Force -ErrorAction SilentlyContinue }
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
        $result = Invoke-WingetCommand -Arguments "install --id DEVCOM.JetBrainsMonoNerdFont --source winget --accept-source-agreements --accept-package-agreements --silent"
        if ($result.ExitCode -ne 0) {
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
function Install-PspEnvironment {
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingPowershellEnvironmentSetupPsp')
    $tools = @(
        @{ Id = "JanDeDobbeleer.OhMyPosh"; Name = "Oh My Posh" },
        @{ Id = "ajeetdsouza.zoxide"; Name = "zoxide" },
        @{ Id = "aristocratos.btop4win"; Name = "btop" },
        @{ Id = "Fastfetch-cli.Fastfetch"; Name = "fastfetch" }
    )
    foreach ($tool in $tools) {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.check0' -Args @($tool.Name))
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            $toolResult = Invoke-WingetCommand -Arguments "install -e --id $($tool.Id) --source winget --accept-source-agreements --accept-package-agreements --silent"
            if ($toolResult.ExitCode -ne 0) {
                Write-ToolkitLog -Level 'WARNING' -Message "Tool $($tool.Id) install returned exit code $($toolResult.ExitCode)."
            }
        }
    }
    $ps7ProfileDir = [Environment]::GetFolderPath('MyDocuments') + '\PowerShell'
    $themesFolder = Initialize-Directory -Path (Join-Path $ps7ProfileDir 'Themes')
    $themePath = Join-Path $themesFolder 'atomic.omp.json'
    if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.OhMyPoshTheme -OutFile $themePath) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.temaOhMyPoshScaricato')
    }
    Install-NerdFontsLocal *>$null
    $null = Initialize-Directory -Path $ps7ProfileDir
    $targetProfile = Join-Path $ps7ProfileDir 'Microsoft.PowerShell_profile.ps1'
    $stagedProfile = "$targetProfile.$([guid]::NewGuid()).tmp"
    try {
        if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.PowerShellProfile -OutFile $stagedProfile) {
            $profileBackup = Copy-FileAtomically -SourcePath $stagedProfile -DestinationPath $targetProfile -Backup
            if ($profileBackup) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.existingProfileSaved0' -Args @($profileBackup))
            }
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7ProfileConfigured')
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.profileConfigurationError0' -Args @($_.Exception.Message))
    }
    finally {
        if (Test-Path -LiteralPath $stagedProfile) {
            Remove-Item -LiteralPath $stagedProfile -Force -ErrorAction SilentlyContinue
        }
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
}
function New-ToolkitDesktopShortcut {
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.desktopShortcutCreation')
    try {
        $desktop = $script:AppConfig.Paths.Desktop
        $shortcut = Join-Path $desktop "Win Toolkit.lnk"
        $iconDir = $script:AppConfig.Paths.WinToolkitDir
        $icon = Join-Path $iconDir "WinToolkit.ico"
        $null = Initialize-Directory -Path $iconDir
        if (-not (Test-FileHasMinimumSize -Path $icon -MinimumBytes $script:MIN_ICON_FILE_BYTES)) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadIcona')
            $null = Invoke-DownloadFile -Uri $script:AppConfig.URLs.ToolkitIcon -OutFile $icon
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
        $bytes = [IO.File]::ReadAllBytes($shortcut)
        if ($bytes.Length -le $script:LNK_RUNAS_ADMIN_BYTE_OFFSET) {
            throw "Unexpected .lnk layout: file is only $($bytes.Length) bytes."
        }
        $bytes[$script:LNK_RUNAS_ADMIN_BYTE_OFFSET] = $bytes[$script:LNK_RUNAS_ADMIN_BYTE_OFFSET] -bor $script:LNK_RUNAS_ADMIN_BIT
        [IO.File]::WriteAllBytes($shortcut, $bytes)
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.shortcutCreatedSuccessfully')
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.shortcutCreationError0' -Args @($_.Exception.Message))
        return $false
    }
}
function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}
function Initialize-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        $null = New-Item -Path $Path -ItemType Directory -Force
    }
    return $Path
}
function Test-FileHasMinimumSize {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$MinimumBytes
    )
    $file = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    return [bool]($file -and -not $file.PSIsContainer -and $file.Length -ge $MinimumBytes)
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
        [int]$TimeoutSeconds = 30,
        [int]$IntervalMs = 1000
    )
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
        [string]$Uri,
        [string]$OutFile,
        [switch]$Silent
    )
    $previousProgress = $ProgressPreference
    try {
        $ProgressPreference = 'SilentlyContinue'
        if ($OutFile) {
            $parentDir = Split-Path -Path $OutFile -Parent
            if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
                $null = New-Item -Path $parentDir -ItemType Directory -Force -ErrorAction Stop
            }
        }
        $iwrParams = @{
            Uri             = $Uri
            OutFile         = $OutFile
            UseBasicParsing = $true
            ErrorAction     = 'Stop'
        }
        Invoke-WebRequest @iwrParams
        return $true
    }
    catch {
        if (-not $Silent) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.downloadError0' -Args @($_.Exception.Message))
        }
        Write-ToolkitLog -Level 'WARNING' -Message "Download failed ($Uri): $($_.Exception.Message)"
        return $false
    }
    finally {
        $ProgressPreference = $previousProgress
    }
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
        [int[]]$AcceptedExitCodes = @(0),
        [switch]$CaptureOutput
    )
    $proc = $null
    $outTask = $null
    $errTask = $null
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
                Write-Warning "start-modules\80-Module.Common.ps1, Invoke-ExternalCommand: $($_.Exception.Message)"
            } }
            $null = $proc.WaitForExit()
            Write-ToolkitLog -Level 'ERROR' -Message "External command timed out after $TimeoutSeconds s: $commandLine"
            return New-ExternalCommandResult -ExitCode -2 -TimedOut $true -DurationMs $stopwatch.ElapsedMilliseconds -FilePath $FilePath -ArgumentList $ArgumentList -AcceptedExitCodes $AcceptedExitCodes
        }
        $capturedOut = try { $outTask.GetAwaiter().GetResult() } catch { '' }
        $capturedErr = try { $errTask.GetAwaiter().GetResult() } catch { '' }
        $stdOut = if ($CaptureOutput) { $capturedOut } else { '' }
        $stdErr = if ($CaptureOutput) { $capturedErr } else { '' }
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
        if (-not (Invoke-DownloadFile -Uri $asset.browser_download_url -OutFile $downloadPath)) {
            throw "Unable to download the release asset $($asset.name)."
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
function Add-SetupResult {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Success,
        [bool]$Changed = $false,
        [string]$Message = '',
        [bool]$Blocking = $false
    )
    $status = if ($Success) { if ($Changed) { 'Changed' } else { 'Succeeded' } } else { 'Failed' }
    $script:SetupResults += [pscustomobject]@{
        Name = $Name; Status = $status; Message = $Message; Blocking = $Blocking
    }
}
function Write-SetupSummary {
    $counts = @{}
    foreach ($status in @('Succeeded', 'Changed', 'Failed', 'Skipped')) {
        $counts[$status] = @($script:SetupResults | Where-Object Status -eq $status).Count
    }
    $counters = @('Succeeded', 'Changed', 'Failed', 'Skipped') | ForEach-Object {
        '{0}={1}' -f (Get-SourceTextLoc "summary.$($_.ToLowerInvariant())"), $counts[$_]
    }
    $summaryText = '{0}: {1}.' -f (Get-SourceTextLoc 'summary.title'), ($counters -join ' ')
    Write-StyledMessage -Type Info -Text $summaryText
    foreach ($result in $script:SetupResults | Where-Object Status -eq 'Failed') {
        $level = if ($result.Blocking) { 'Error' } else { 'Warning' }
        Write-StyledMessage -Type $level -Text "$($result.Name): $($result.Message)"
    }
    $hasBlockingFailure = @($script:SetupResults | Where-Object { $_.Status -eq 'Failed' -and $_.Blocking }).Count -gt 0
    $hasFailure = @($script:SetupResults | Where-Object Status -eq 'Failed').Count -gt 0
    if ($hasBlockingFailure) { return 1 }
    if ($hasFailure) { return 2 }
    return 0
}
function Invoke-WinToolkitSetup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Language = 'Auto'
    )
    $script:SetupResults = @()
    $script:SetupExitCode = 1
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        if (-not $PSCmdlet.ShouldProcess('Windows system', 'Run WinToolkit setup')) {
            $script:SetupExitCode = 0
            return
        }
        $ErrorActionPreference = 'Stop'
        $Host.UI.RawUI.WindowTitle = "Toolkit Starter by MagnetarMan"
        Start-ToolkitLog "WinToolkitStarter"
        $null = Resolve-SourceTextLanguage -RequestedLanguage $Language
        Initialize-UpdateServicesState
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            throw 'start-core.ps1 requires PowerShell 7 or later. Run start.ps1 instead.'
        }
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'start-core.ps1 must be started by the elevated start.ps1 stub.'
        }
        Show-Header -Title $script:AppConfig.Header.Title -Version $script:AppConfig.Header.Version
        foreach ($repair in @(
                @{ Name = 'System clock'; Action = { Repair-SystemClock } },
                @{ Name = 'SCHANNEL'; Action = { Reset-SchannelSettings } },
                @{ Name = 'Hosts file'; Action = { Reset-HostsFile } },
                @{ Name = 'App Installer'; Action = { Repair-AppInstaller } }
            )) {
            $repairResult = & $repair.Action
            Add-SetupResult -Name $repair.Name -Success ([bool]$repairResult.Success) -Changed ([bool]$repairResult.Changed) -Message $repairResult.Message
        }
        Invoke-StopUpdateServices
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.powershell0' -Args @($PSVersionTable.PSVersion))
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingWinToolkitConfiguration')
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.carryingOutBasicChecks')
        Update-EnvironmentPath
        Repair-Winget -Level MsStoreCert | Out-Null
        $wingetReady = Test-WingetFunctionality
        if ($wingetReady) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetIsAlreadyOperational')
        }
        else {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetDoesnTRespondFastRecoveryAttemptCore')
            $coreSuccess = Repair-Winget -Level CoreInstall
            Update-EnvironmentPath
            if ($coreSuccess -and (Test-WingetFunctionality)) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetRestoredQuickly')
                Reset-WingetSources
                $wingetReady = $true
            }
            else {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.quickRecoveryFailedAttemptAdvancedSlowerMethod')
                $null = Repair-Winget -Level FullReinstall
                Update-EnvironmentPath
                $wingetReady = Test-WingetFunctionality
                if (-not $wingetReady) {
                    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFunctionalAfterAllAttempts')
                    Add-SetupResult -Name 'WinGet' -Success $false -Message 'WinGet remains unavailable after recovery.' -Blocking $true
                    throw 'WinGet is required for the installation flow and remains unavailable.'
                }
                Reset-WingetSources
            }
        }
        Add-SetupResult -Name 'WinGet' -Success ([bool]$wingetReady) -Message 'WinGet operational.' -Blocking $true
        $null = Test-WingetAppInstaller
        Update-EnvironmentPath
        if (-not (Test-WingetDeepValidation)) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.warningInstallingSubsequentPackagesViaWingetMayFail')
        }
        $gitSuccess = Install-GitPackage
        Add-SetupResult -Name 'Git' -Success ([bool]$gitSuccess) -Message 'Git verification/installation completed.'
        if ($gitSuccess) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitIsAlreadyOperational')
        }
        else {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.attentionGitHasNotBeenInstalledOrItMayNotWorkProperly')
        }
        $ps7Success = Install-PowerShellCore
        Add-SetupResult -Name 'PowerShell 7' -Success ([bool]$ps7Success) -Message 'PowerShell 7 verification/installation completed.'
        $wtInstalled = Install-WindowsTerminalApp
        Add-SetupResult -Name 'Windows Terminal' -Success ([bool]$wtInstalled) -Message 'Windows Terminal verification/installation completed.'
        if ($wtInstalled) {
            $defaultTerminal = Set-WindowsTerminalAsDefault
            Add-SetupResult -Name 'Default terminal' -Success ([bool]$defaultTerminal.Success) -Changed ([bool]$defaultTerminal.Changed) -Message $defaultTerminal.Message
        }
        Install-PspEnvironment
        Add-SetupResult -Name 'PowerShell environment' -Success $true -Message 'PowerShell environment configured.'
        if ((Test-WindowsTerminalInstalled) -and (Test-CommandExists -Name 'pwsh')) {
            $shortcutCreated = New-ToolkitDesktopShortcut
            Add-SetupResult -Name 'Desktop shortcut' -Success ([bool]$shortcutCreated) -Message 'Desktop shortcut creation completed.'
        }
        else {
            Add-SetupResult -Name 'Desktop shortcut' -Success $false -Message 'Skipped: Windows Terminal or PowerShell 7 is not available, the shortcut would not work.'
        }
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.configurationComplete')
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wintoolkitIsReadyOnTheDesktop')
        Start-Sleep 3
        $script:SetupExitCode = Write-SetupSummary
        return
    }
    catch {
        Set-UpdateServicesError -Message $_.Exception.Message
        Add-SetupResult -Name 'Setup flow' -Success $false -Message $_.Exception.Message -Blocking $true
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.criticalErrorDuringSetup0' -Args @($_.Exception.Message))
        Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.unhandledException01' -Args @($_.Exception.Message, $_.ScriptStackTrace))
        Write-Host (Get-SourceTextLoc 'sourceText.pressAnyKeyToExit')
        $null = [Console]::ReadKey($true)
        $script:SetupExitCode = 1
        Write-SetupSummary | Out-Null
        return
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
Invoke-WinToolkitSetup -Language $Language
exit $script:SetupExitCode