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
        Success = @{ Icon = '✅'; Color = 'Green' }
        Warning = @{ Icon = '⚠️'; Color = 'Yellow' }
        Error   = @{ Icon = '❌'; Color = 'Red' }
        Info    = @{ Icon = '💎'; Color = 'Cyan' }
    }
    Header           = @{
        Title   = "Toolkit Starter By MagnetarMan"
        Version = "Version $ToolkitVersion"
    }
    URLs             = @{
        WingetMSIX        = "https://aka.ms/getwinget"
        GitRelease        = "https://api.github.com/repos/git-for-windows/git/releases/latest"
        PowerShellRelease = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        OhMyPoshTheme     = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
        TerminalRelease   = "https://api.github.com/repos/microsoft/terminal/releases/latest"
        WebInstaller      = "https://magnetarman.com/WinToolkit-Dev"
    }
    Paths            = @{
        Logs          = "$env:LOCALAPPDATA\WinToolkit\logs"
        WinToolkitDir = "$env:LOCALAPPDATA\WinToolkit"
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
$script:AppConfig.URLs.StartScript = "$($script:RepoRawBase)/start.ps1"
$script:AppConfig.URLs.PowerShellProfile = "$($script:RepoBase)/assets/Microsoft.PowerShell_profile.ps1"
$script:AppConfig.URLs.WindowsTerminalSettings = "$($script:RepoBase)/assets/settings.json"
$script:AppConfig.URLs.ToolkitIcon = "$($script:RepoRawBase)/images/WinToolkit.ico"
$script:AppConfig.URLs.LanguagesRawUrl = "$($script:RepoBase)/languages"
$script:AppConfig.URLs.LanguagesApiUrl = "https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=$($script:Branch)"
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
    $logLevel = switch ($Type) {
        'Success' { 'SUCCESS' }
        'Warning' { 'WARNING' }
        'Error' { 'ERROR' }
        default { 'INFO' }
    }
    Write-ToolkitLog -Level $logLevel -Message $Text
}
function Start-ToolkitLog {
    param([string]$ToolName)
    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = $script:AppConfig.Paths.Logs
    if (-not (Test-Path $logdir)) {
        New-Item -Path $logdir -ItemType Directory -Force | Out-Null
    }
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
ToolkitVersion : $($script:AppConfig.Header.Version)
[END LOG HEADER]
"@
    try { Add-Content -Path $script:CurrentLogFile -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
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
    try { Add-Content -Path $script:CurrentLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
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
    $k = $Key
    if ($script:SourceTextKeyAliases.ContainsKey($k)) {
        $k = $script:SourceTextKeyAliases[$k]
    }
    $value = $null
    if ($script:SourceTextLanguageData -and $script:SourceTextLanguageData.ContainsKey($k)) {
        $value = [string]$script:SourceTextLanguageData[$k]
    }
    elseif ($script:SourceTextDefaultLanguageData -and $script:SourceTextDefaultLanguageData.ContainsKey($k)) {
        $value = [string]$script:SourceTextDefaultLanguageData[$k]
    }
    else {
        if ($k -match '^(.*?)(\d+)$') {
            $stem = $Matches[1]
            if ($script:SourceTextLanguageData -and $script:SourceTextLanguageData.ContainsKey($stem)) {
                $value = [string]$script:SourceTextLanguageData[$stem]
            }
            elseif ($script:SourceTextDefaultLanguageData -and $script:SourceTextDefaultLanguageData.ContainsKey($stem)) {
                $value = [string]$script:SourceTextDefaultLanguageData[$stem]
            }
        }
    }
    if ($null -eq $value) {
        if ($script:EmbeddedEnglishText.ContainsKey($k)) {
            $value = [string]$script:EmbeddedEnglishText[$k]
        }
        else {
            $value = "[MISSING TRANSLATION: $Key]"
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
    $pathExists = $false
    if ($Scope -eq 'User' -or $Scope -eq 'Both') {
        $userEnvPath = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::User)
        if (($userEnvPath -split ';').Contains($PathToCheck)) {
            $pathExists = $true
        }
    }
    if ($Scope -eq 'System' -or $Scope -eq 'Both') {
        $systemEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)
        if (($systemEnvPath -split ';').Contains($PathToCheck)) {
            $pathExists = $true
        }
    }
    return $pathExists
}
function Add-ToEnvironmentPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PathToAdd,
        [ValidateSet('User', 'System')]
        [string]$Scope
    )
    if (-not (Test-PathInEnvironment -PathToCheck $PathToAdd -Scope $Scope)) {
        if ($Scope -eq 'System') {
            $systemEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)
            $systemEnvPath += ";$PathToAdd"
            [System.Environment]::SetEnvironmentVariable('PATH', $systemEnvPath, [System.EnvironmentVariableTarget]::Machine)
        }
        elseif ($Scope -eq 'User') {
            $userEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::User)
            $userEnvPath += ";$PathToAdd"
            [System.Environment]::SetEnvironmentVariable('PATH', $userEnvPath, [System.EnvironmentVariableTarget]::User)
        }
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
                        Write-StyledMessage -Type Info -Text "SCHANNEL TLS 1.2 $mode riattivato."
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
                    Write-StyledMessage -Type Info -Text "SCHANNEL cipher $($_.PSChildName) riabilitato."
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
        $hasOverrides = $false
        $newLines = @()
        foreach ($line in $lines) {
            if ($line -match '(?i)microsoft\.com|storeedgefd|winget\.azureedge\.net') {
                $hasOverrides = $true
                continue
            }
            $newLines += $line
        }
        if ($hasOverrides) {
            $backupDir = $script:AppConfig.Paths.WinToolkitDir
            if (-not (Test-Path $backupDir)) { $null = New-Item -Path $backupDir -ItemType Directory -Force -ErrorAction Stop }
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
            Write-StyledMessage -Type Info -Text "File hosts modificato; backup salvato in $backupPath."
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
        Write-StyledMessage -Type Warning -Text 'Rilevata una precedente interruzione: ripristino dello stato dei servizi Windows Update.'
        Invoke-StartUpdateServices
    }
}
function Set-UpdateServicesError {
    param([string]$Message)
    $status = Read-UpdateServicesStatus
    if ($status) {
        $status.State = 'RestoreFailed'
        $status.LastError = $Message
        Write-UpdateServicesStatus -Status $status
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
        $status.State = 'Suspended'
        Write-UpdateServicesStatus -Status $status
        $script:UpdateServicesSuspended = $true
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updateServicesSuccessfullySuspended')
    }
    catch {
        $status.State = 'RestoreFailed'
        $status.LastError = $_.Exception.Message
        Write-UpdateServicesStatus -Status $status
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
            $status.State = 'RestoreFailed'
            $status.LastError = $otherErrors -join '; '
            Write-UpdateServicesStatus -Status $status
            Write-ToolkitLog -Level 'ERROR' -Message "Unable to restore Windows Update services: $($status.LastError)"
            Write-StyledMessage -Type Error -Text "Ripristino servizi Windows Update incompleto: $($status.LastError)"
            return $false
        }
        if ($dosvcErrors.Count -gt 0) {
            $status.State = 'Restored'
            $status.LastError = $null
            Write-UpdateServicesStatus -Status $status
            Write-ToolkitLog -Level 'WARNING' -Message "Windows Update service dosvc could not be restored (known Windows limitation): $($dosvcErrors -join '; ')"
            Write-StyledMessage -Type Warning -Text "Servizio Windows Update dosvc (Ottimizzazione recapito) non è stato ripristinato: limite noto di Windows. Il setup prosegue."
        }
    }
    $status.State = 'Restored'
    Write-UpdateServicesStatus -Status $status
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
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -NonInteractive -EncodedCommand $encodedCmd"
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            $proc.Kill()
            $proc.WaitForExit()
            Write-ToolkitLog -Level 'ERROR' -Message "AppX installation timeout after $TimeoutSeconds seconds: $AppxPath"
            return $false
        }
        if ($proc.ExitCode -ne 0) {
            if (Test-Path $errFile) {
                $errMsg = Get-Content $errFile -Raw
                Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.appxInstallFailed01' -Args @($AppxPath, $errMsg))
            }
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
        $proc.Dispose()
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
function Invoke-WingetCommand {
    param(
        [string]$Arguments,
        [int]$TimeoutSeconds = 120
    )
    try {
        $wingetExe = Get-WinGetExecutable
        if (-not $wingetExe) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInSystem')
            return @{ ExitCode = -1 }
        }
        $versionRaw = (& $wingetExe --version 2>$null) | Out-String
        $isModern = $versionRaw -match 'v1\.[4-9]' -or $versionRaw -match 'v[2-9]'
        $finalArgs = if ($isModern) { "$Arguments --disable-interactivity" } else { $Arguments }
        $result = Invoke-ExternalCommand -FilePath $wingetExe -ArgumentList (ConvertTo-ProcessArgumentList -Arguments $finalArgs) -TimeoutSeconds $TimeoutSeconds
        if ($result.TimedOut) {
            Write-ToolkitLog -Level 'ERROR' -Message "Winget timeout after $TimeoutSeconds seconds: $Arguments"
        }
        return $result
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetCommandError0' -Args @($($_.Exception.Message)))
        return @{ ExitCode = -1 }
    }
}
function Reset-WingetSources {
    try {
        $wingetExe = Get-WinGetExecutable
        if ($wingetExe) {
            $null = & $wingetExe source reset --force 2>&1
        }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Winget source reset failed: $($_.Exception.Message)"
    }
}
function Repair-WingetMsStoreSource {
    try {
        $wingetExe = Get-WinGetExecutable
        if (-not $wingetExe) { return }
        $output = & $wingetExe source update --source msstore --accept-source-agreements 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0 -and $output -match '0x8a15005e') {
            Write-StyledMessage -Type Warning -Text "Detected msstore certificate pinning failure (0x8a15005e). Resetting Winget sources to default..."
            $null = & $wingetExe source reset --force 2>&1
            Update-EnvironmentPath
            Write-StyledMessage -Type Success -Text "Winget sources reset completed. Using 'winget' source only."
        }
    }
    catch {
        Write-ToolkitLog -Level 'DEBUG' -Message "msstore source repair skipped: $($_.Exception.Message)"
    }
}
function Repair-AppInstaller {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not $PSCmdlet.ShouldProcess('Microsoft.DesktopAppInstaller', 'Repair App Installer')) { return }
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'App Installer already exposes winget.' }
        }
        $changed = $false
        $pkg = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue
        if ($pkg) {
            $pkg | Reset-AppxPackageSilently
            $changed = $true
        }
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            $tempFile = Join-Path $env:TEMP 'WingetInstaller.msixbundle'
            Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile $tempFile -UseBasicParsing -ErrorAction Stop
            if (-not (Start-AppxSilentProcess -AppxPath $tempFile -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.DesktopAppInstaller')) {
                throw 'App Installer package installation failed.'
            }
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            $changed = $true
        }
        if (-not (Register-WingetAppExecutionAlias)) { throw 'App Installer execution alias registration failed.' }
        return [pscustomobject]@{ Success = $true; Changed = $changed; Message = 'App Installer repaired and alias registered.' }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "App Installer repair failed: $($_.Exception.Message)"
        return [pscustomobject]@{ Success = $false; Changed = $false; Message = $_.Exception.Message }
    }
}
function Test-WingetCompatibility {
    $osInfo = [Environment]::OSVersion
    $build = $osInfo.Version.Build
    if ($osInfo.Version.Major -lt 10) {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.wingetNotSupportedOnWindows0' -Args @($($osInfo.Version.Major)))
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
        $versionOutput = (& winget --version 2>$null) | Out-String
        if ($LASTEXITCODE -eq 0 -and $versionOutput -match 'v\d+\.\d+') {
            Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.operationalWingetVersion0' -Args @($($versionOutput.Trim()))))
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
function Test-WingetAppInstaller {
    $wingetExe = Get-WinGetExecutable
    if (-not $wingetExe) {
        return $false
    }
    Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.checkingMicrosoftAppInstallerPackage'))
    $present = [bool](Get-AppxPackage -Name 'Microsoft.AppInstaller' -ErrorAction SilentlyContinue)
    try {
        if (-not $present) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerNotFoundInstalling')
            $null = & $wingetExe install --id Microsoft.AppInstaller --source winget --accept-package-agreements --accept-source-agreements --force 2>&1
        }
        else {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerPresentForcingUpdate')
            $null = & $wingetExe upgrade --id Microsoft.AppInstaller --source winget --accept-package-agreements --accept-source-agreements --force 2>&1
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerUpdateError0' -Args @($($_.Exception.Message)))
    }
    $ok = [bool](Get-AppxPackage -Name 'Microsoft.AppInstaller' -ErrorAction SilentlyContinue)
    if ($ok) {
        Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.microsoftAppInstallerUpdated'))
    }
    else {
        Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.microsoftAppInstallerInstallationFailed'))
    }
    return $ok
}
function Invoke-ForceCloseWinget {
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.closingInterferingProcesses')
    $interferingProcesses = $script:AppConfig.WingetProcesses
    foreach ($procName in $interferingProcesses) {
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
                catch {}
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
        try {
            $null = & winget.exe source reset --force 2>&1
        }
        catch {}
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetPackageMicrosoftDesktopappinstaller')
        if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
            Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackageSilently
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
        catch { }
        try {
            if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.esecuzioneRepairWingetpackagemanager')
                Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
            }
        }
        catch {
            if ($_.Exception.Message -match '0x80073D06') {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerCompletedHigherVersionAlreadyPresent')
            }
            else {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.repairModuleFailed0' -Args @($($_.Exception.Message)))
            }
        }
        Set-WingetPathPermissions
        Update-EnvironmentPath
        Start-Sleep 2
        $testVersion = & winget --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.restoreCompletedButWingetMayNotWork'))
        }
        else {
            Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.wingetDatabaseRestoredVersion0' -Args @($testVersion)))
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text ((Get-SourceTextLoc 'uiText.errorRestoringDatabase0' -Args @($($_.Exception.Message))))
        return $false
    }
}
function Test-WingetDeepValidation {
    Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.deepTestExecutionOfWingetSearchForPacketsOnTheNetwork'))
    try {
        $wingetExe = Get-WinGetExecutable
        if (-not $wingetExe) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInSystem')
            return $false
        }
        $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq $script:EXITCODE_ACCESS_VIOLATION_SIGNED -or $exitCode -eq $script:EXITCODE_ACCESS_VIOLATION) {
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.crashDetectedExitcode0AccessViolationAdvancedRecoveryAttempt' -Args @($exitCode)))
            $null = Repair-Winget -Level FullDatabase
            Write-StyledMessage -Type Info -Text ("🔄 " + (Get-SourceTextLoc 'uiText.repeatTestAfterDatabaseRestore'))
            Start-Sleep 3
            $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
            $exitCode = $LASTEXITCODE
            if ($exitCode -eq $script:EXITCODE_ACCESS_VIOLATION_SIGNED -or $exitCode -eq $script:EXITCODE_ACCESS_VIOLATION) {
                Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.persistentCrashStartingCompleteReinstallationOfWinget'))
                $null = Repair-Winget -Level FullReinstall
                Write-StyledMessage -Type Info -Text ("🔄 " + (Get-SourceTextLoc 'uiText.finalTestAfterReinstallation'))
                Start-Sleep 3
                $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
                $exitCode = $LASTEXITCODE
            }
        }
        if ($exitCode -eq 0) {
            try {
                $null = & $wingetExe source update --accept-source-agreements 2>&1
            }
            catch {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'toolText.sourceUpdateError0' -Args @($($_.Exception.Message)))
            }
            Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.deepTestPassedWingetCommunicatesCorrectlyWithRepositories'))
            return $true
        }
        $errorDetails = $searchResult | Out-String
        if ($errorDetails.Length -gt 200) {
            $errorDetails = $errorDetails.Substring(0, 200) + "."
        }
        Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.deepTestFailedExitcode0Details1' -Args @($exitCode, $errorDetails)))
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text ((Get-SourceTextLoc 'uiText.errorDuringWingetDeepTest0' -Args @($($_.Exception.Message))))
        return $false
    }
}
function Get-WingetDownloadUrl {
    param([string]$Match)
    try {
        $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
        $asset = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
        if ($asset) {
            return $asset.browser_download_url
        }
        throw (Get-SourceTextLoc 'uiText.asset0NotFound' -Args @($Match))
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.assetUrlRetrievalError0' -Args @($($_.Exception.Message)))
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
            $arch = switch (Get-SystemArchitecture) {
                'ARM64' { 'arm64' }
                'X86' { 'x86' }
                default { 'x64' }
            }
            $vcUrl = "https://aka.ms/vs/17/release/vc_redist.$arch.exe"
            $vcFile = Join-Path $tempDir "vc_redist.exe"
            Invoke-WebRequest -Uri $vcUrl -OutFile $vcFile -UseBasicParsing
            $procParams = @{
                FilePath     = $vcFile
                ArgumentList = @("/install", "/quiet", "/norestart")
                Wait         = $true
                NoNewWindow  = $true
            }
            Start-Process @procParams
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.visualCRedistributableInstalled')
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
                $iwrDepParams = @{
                    Uri             = $depUrl
                    OutFile         = $depZip
                    UseBasicParsing = $true
                    ErrorAction     = 'Stop'
                }
                Invoke-WebRequest @iwrDepParams
                $extractPath = Join-Path $tempDir "deps"
                Expand-Archive -Path $depZip -DestinationPath $extractPath -Force
                $archPattern = switch (Get-SystemArchitecture) {
                    'ARM64' { 'arm64|neutral|ne' }
                    'X86' { 'x86|neutral|ne' }
                    default { 'x64|neutral|ne' }
                }
                $appxFiles = Get-ChildItem -Path $extractPath -Recurse -Filter "*.appx" | Where-Object { $_.Name -match $archPattern }
                foreach ($file in $appxFiles) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.dependencyFound0' -Args @($($file.Name)))
                    $dependencies += $file.FullName
                }
            }
            catch {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.unableToExtractOrInstallDependenciesFromTheOfficialZipError0' -Args @($($_.Exception.Message)))
            }
        }
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadAndInstallWingetBundleWithDependencies')
        $wingetUrl = Get-WingetDownloadUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        if (-not $wingetUrl) {
            throw (Get-SourceTextLoc 'uiText.wingetCoreInstallationFailed')
        }
        $wingetFile = Join-Path $tempDir "winget.msixbundle"
        Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetFile -UseBasicParsing
        if (Start-AppxSilentProcess -AppxPath $wingetFile -DependencyPaths $dependencies -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.DesktopAppInstaller') {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetCoreSuccessfullyInstalled')
        }
        else {
            throw (Get-SourceTextLoc 'uiText.wingetCoreInstallationFailed')
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorRestoringWinget0' -Args @($($_.Exception.Message)))
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
    $oldProgress = $ProgressPreference
    try {
        $ProgressPreference = 'SilentlyContinue'
        $tempPath = "$env:TEMP\WinGet"
        if (Test-Path $tempPath) {
            Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            try {
                $null = & "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" source reset --force 2>$null
            }
            catch {}
        }
        if (-not (Get-Module -ListAvailable Microsoft.WinGet.Client) -or $Force) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingMicrosoftWingetClientModule')
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetClientModuleInstalled')
            }
            catch {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.moduloWingetClient0' -Args @($($_.Exception.Message)))
            }
        }
        Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
        if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.tentativoRiparazioneWingetRepairWingetpackagemanager')
            try {
                Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerEseguito')
            }
            catch {
                if ($_.Exception.Message -match '0x80073D06') {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerIgnoredHigherVersionAlreadyPresent')
                }
                else {
                    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerFallito0' -Args @($($_.Exception.Message)))
                }
            }
            Start-Sleep 3
        }
        if (-not (Get-Command winget -ErrorAction SilentlyContinue) -or $Force) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadMsixbundleDaMicrosoft')
            $msixTempDir = $script:AppConfig.Paths.Temp
            if (-not (Test-Path $msixTempDir)) {
                $null = New-Item -Path $msixTempDir -ItemType Directory -Force
            }
            $tempInstaller = Join-Path $msixTempDir "WingetInstaller.msixbundle"
            $iwrParams = @{
                Uri             = $script:AppConfig.URLs.WingetMSIX
                OutFile         = $tempInstaller
                UseBasicParsing = $true
                ErrorAction     = 'Stop'
            }
            Invoke-WebRequest @iwrParams
            if (Start-AppxSilentProcess -AppxPath $tempInstaller -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.DesktopAppInstaller') {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetMsixBundleInstallationSuccessful')
            }
            else {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetMsixBundleInstallationFailed')
            }
            Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
            Start-Sleep 3
        }
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetAppInstaller')
        try {
            Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackageSilently
        }
        catch {}
        Set-WingetPathPermissions
        Start-Sleep 2
        Update-EnvironmentPath
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.wingetInstalledAndWorking'))
            return $true
        }
        Write-StyledMessage -Type Error -Text ((Get-SourceTextLoc 'uiText.unableToInstallWinget'))
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.criticalError0' -Args @($($_.Exception.Message)))
        return $false
    }
    finally {
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
function Test-VCRedistInstalled {
    $architecture = Get-SystemArchitecture
    $checksPassed = 0
    $registryPath32 = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86'
    $dllPath32 = "$env:windir\syswow64\concrt140.dll"
    if ((Test-Path -Path $registryPath32) -and
        ((Get-ItemProperty -Path $registryPath32 -Name 'Major' -ErrorAction SilentlyContinue).Major -eq 14) -and
        [System.IO.File]::Exists($dllPath32)) {
        $checksPassed++
    }
    if ($architecture -ne 'X86') {
        $nativeRuntime = if ($architecture -eq 'ARM64') { 'arm64' } else { 'x64' }
        $registryPath64 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\$nativeRuntime"
        $dllPath64 = "$env:windir\system32\concrt140.dll"
        if ((Test-Path -Path $registryPath64) -and
            ((Get-ItemProperty -Path $registryPath64 -Name 'Major' -ErrorAction SilentlyContinue).Major -eq 14) -and
            [System.IO.File]::Exists($dllPath64)) {
            $checksPassed++
        }
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
        $assetPattern = switch (Get-SystemArchitecture) {
            'ARM64' { 'arm64\.exe$' }
            'X86' { '32-bit\.exe$' }
            default { '64-bit\.exe$' }
        }
        $installResult = Install-FromGitHubRelease -ReleaseApiUrl $script:AppConfig.URLs.GitRelease `
            -AssetPattern $assetPattern -ExecutablePath '{INSTALLER}' `
            -InstallerArguments @('/SILENT', '/NORESTART', '/CLOSEAPPLICATIONS')
        if ($installResult.Success) {
            Update-EnvironmentPath
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitInstalledSuccessfully')
            return $true
        }
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.installationFailedCode0' -Args @($($installResult.ExitCode)))
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.gitInstallationError0' -Args @($($_.Exception.Message)))
        return $false
    }
}
function Install-PowerShellCore {
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.verificaPowershell7')
    $ps7Path64 = "$env:SystemDrive\Program Files\PowerShell\7"
    $ps7Path32 = "$env:SystemDrive\Program Files (x86)\PowerShell\7"
    $architecture = Get-SystemArchitecture
    if ((Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7AlreadyInstalled')
        return $true
    }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.attemptingToInstallPowershell7ViaWinget')
        $iwcParams = @{
            Arguments = "install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements --silent"
        }
        $result = Invoke-WingetCommand @iwcParams
        if ($result.ExitCode -eq 0) {
            if (Wait-Until -Condition {
                    (Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Test-CommandExists -Name pwsh)
                } -TimeoutSeconds 15 -IntervalMs 1000) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7InstallatoViaWinget')
                return $true
            }
        }
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstallationFailedOrFailedExitcode0FallbackToDirectDownload' -Args @($($result.ExitCode)))
    }
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.recuperoUltimaReleasePowershell')
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingPowershell7InProgress')
        $assetPattern = switch ($architecture) {
            'ARM64' { 'win-arm64\.msi$' }
            'X86' { 'win-x86\.msi$' }
            default { 'win-x64\.msi$' }
        }
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
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.installationFailedCode02' -Args @($($installResult.ExitCode)))
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.powershellInstallationError0' -Args @($($_.Exception.Message)))
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
    try {
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.attemptingToInstallWindowsTerminalViaWinget')
            $iwcParams = @{
                Arguments = "install --id Microsoft.WindowsTerminal --source winget --accept-source-agreements --accept-package-agreements --silent"
            }
            $result = Invoke-WingetCommand @iwcParams
            if ($result.ExitCode -eq 0 -and (Wait-Until -Condition { Test-WindowsTerminalInstalled } -TimeoutSeconds 15 -IntervalMs 1000)) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalInstalledViaWinget')
                return $true
            }
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstallationForWindowsTerminalFailed')
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstallationForWindowsTerminalFailed' -Args @($($_.Exception.Message)))
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
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
        if (Start-AppxSilentProcess -AppxPath $tempFile -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.WindowsTerminal') {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalAppxInstallationSuccessful')
        }
        else {
            throw (Get-SourceTextLoc 'uiText.windowsTerminalAppxInstallationFailed')
        }
        $null = Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        if (-not (Wait-Until -Condition { Test-WindowsTerminalInstalled } -TimeoutSeconds 30 -IntervalMs 1000)) {
            throw 'Windows Terminal package installed but wt.exe was not detected.'
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.standardWindowsTerminalInstallationFailed0FallbackToTheMicrosoftStore' -Args @($($_.Exception.Message)))
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
        Write-StyledMessage -Type Warning -Text "Questa build di Windows non supporta l'impostazione del terminale predefinito: passaggio saltato."
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
        Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.windowsTerminalSetAsDefault'))
        return [pscustomobject]@{ Success = $true; Changed = $true; Message = 'Windows Terminal set as default.' }
    }
    catch {
        Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.failedToSetDefaultTerminal0' -Args @($($_.Exception.Message))))
        return [pscustomobject]@{ Success = $false; Changed = $false; Message = $_.Exception.Message }
    }
}
function Update-WindowsTerminalSettings {
    param([Parameter(Mandatory = $true)][string]$SettingsPath)
    $remotePath = Join-Path $script:AppConfig.Paths.Temp "wt-settings-$([guid]::NewGuid()).json"
    try {
        if (-not (Invoke-DownloadFile -Uri $script:AppConfig.URLs.WindowsTerminalSettings -OutFile $remotePath)) {
            return $false
        }
        $backupPath = "$SettingsPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if (Test-Path -LiteralPath $SettingsPath) {
            Copy-Item -LiteralPath $SettingsPath -Destination $backupPath -Force -ErrorAction Stop
        }
        $tempPath = "$SettingsPath.$([guid]::NewGuid()).tmp"
        try {
            Copy-Item -LiteralPath $remotePath -Destination $tempPath -Force -ErrorAction Stop
            Move-Item -LiteralPath $tempPath -Destination $SettingsPath -Force -ErrorAction Stop
        }
        finally {
            if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
        }
        Write-StyledMessage -Type Info -Text "Windows Terminal settings sovrascritti con la versione distribuita; backup: $backupPath."
        return $true
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Windows Terminal settings update skipped: $($_.Exception.Message)"
        return $false
    }
    finally {
        if (Test-Path -LiteralPath $remotePath) { Remove-Item -LiteralPath $remotePath -Force -ErrorAction SilentlyContinue }
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
            Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.jetbrainsmonoNerdFontAlreadyInstalled'))
            return $true
        }
        Write-StyledMessage -Type Info -Text ("⬇️ " + (Get-SourceTextLoc 'uiText.fontInstallationViaWingetQuickMethod'))
        $result = Invoke-WingetCommand -Arguments "install --id DEVCOM.JetBrainsMonoNerdFont --source winget --accept-source-agreements --accept-package-agreements --silent"
        if ($result.ExitCode -ne 0) {
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.wingetReturnedCode0TheFontMayRequireATerminalRestart' -Args @($($result.ExitCode))))
            return $false
        }
        Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.nerdFontsInstalledSuccessfully'))
        Write-StyledMessage -Type Warning -Text ("💡 " + (Get-SourceTextLoc 'uiText.noteFontsViaWingetRequireRestartingTerminalOrExplorerToBeVisible'))
        return $true
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.errorInstallingFont0' -Args @($($_.Exception.Message)))
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
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.check0' -Args @($($tool.Name)))
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            $toolResult = Invoke-WingetCommand -Arguments "install -e --id $($tool.Id) --source winget --accept-source-agreements --accept-package-agreements --silent"
            if ($toolResult.ExitCode -ne 0) {
                Write-ToolkitLog -Level 'WARNING' -Message "Tool $($tool.Id) install returned exit code $($toolResult.ExitCode)."
            }
        }
    }
    $ps7ProfileDir = [Environment]::GetFolderPath('MyDocuments') + '\PowerShell'
    $themesFolder = Join-Path $ps7ProfileDir 'Themes'
    if (-not (Test-Path $themesFolder)) {
        New-Item -Path $themesFolder -ItemType Directory -Force *>$null
    }
    $themePath = Join-Path $themesFolder 'atomic.omp.json'
    if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.OhMyPoshTheme -OutFile $themePath) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.temaOhMyPoshScaricato')
    }
    Install-NerdFontsLocal *>$null
    if (-not (Test-Path $ps7ProfileDir)) {
        New-Item -Path $ps7ProfileDir -ItemType Directory -Force *>$null
    }
    $targetProfile = Join-Path $ps7ProfileDir 'Microsoft.PowerShell_profile.ps1'
    $temporaryProfile = "$targetProfile.$([guid]::NewGuid()).tmp"
    try {
        if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.PowerShellProfile -OutFile $temporaryProfile) {
            if (Test-Path -LiteralPath $targetProfile) {
                $profileBackup = "$targetProfile.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                [System.IO.File]::Replace($temporaryProfile, $targetProfile, $profileBackup, $true)
                Write-StyledMessage -Type Info -Text "Profilo esistente salvato in $profileBackup."
            }
            else {
                Move-Item -LiteralPath $temporaryProfile -Destination $targetProfile -Force -ErrorAction Stop
            }
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7ProfileConfigured')
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.profileConfigurationError0' -Args @($($_.Exception.Message)))
    }
    finally {
        if ($temporaryProfile -and (Test-Path -LiteralPath $temporaryProfile)) {
            Remove-Item -LiteralPath $temporaryProfile -Force -ErrorAction SilentlyContinue
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
                    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalSettingsUpdated0' -Args @($($wtPkg.Name)))
                }
            }
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.terminalSettingsUpdateError0' -Args @($($_.Exception.Message)))
    }
}
function New-ToolkitDesktopShortcut {
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.desktopShortcutCreation')
    try {
        $desktop = $script:AppConfig.Paths.Desktop
        $shortcut = Join-Path $desktop "Win Toolkit.lnk"
        $iconDir = $script:AppConfig.Paths.WinToolkitDir
        $icon = Join-Path $iconDir "WinToolkit.ico"
        if (-not (Test-Path $iconDir)) {
            $niParams = @{
                Path     = $iconDir
                ItemType = 'Directory'
                Force    = $true
            }
            $null = New-Item @niParams *>$null
        }
        if (-not (Test-Path $icon)) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadIcona')
            $null = Invoke-DownloadFile -Uri $script:AppConfig.URLs.ToolkitIcon -OutFile $icon
        }
        if (Test-Path $icon) {
            $iconItem = Get-Item $icon -ErrorAction SilentlyContinue
            if (-not $iconItem -or $iconItem.Length -lt $script:MIN_ICON_FILE_BYTES) {
                Remove-Item $icon -Force -ErrorAction SilentlyContinue
                $null = Invoke-DownloadFile -Uri $script:AppConfig.URLs.ToolkitIcon -OutFile $icon
            }
        }
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcut)
        $link.TargetPath = $script:AppConfig.Paths.wtExe
        $link.Arguments = 'pwsh -ExecutionPolicy Bypass -Command "irm ' + $script:AppConfig.URLs.WebInstaller + ' | iex"'
        $link.WorkingDirectory = $script:AppConfig.Paths.wtDir
        $iconValid = $false
        if (Test-Path -Path $icon) {
            $iconFile = Get-Item -Path $icon -ErrorAction SilentlyContinue
            if ($null -ne $iconFile -and $iconFile.Length -ge $script:MIN_ICON_FILE_BYTES) {
                $iconValid = $true
            }
        }
        if ($iconValid) {
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
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.shortcutCreationError0' -Args @($($_.Exception.Message)))
        return $false
    }
}
function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
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
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.downloadError0' -Args @($($_.Exception.Message)))
        }
        Write-ToolkitLog -Level 'WARNING' -Message "Download failed ($Uri): $($_.Exception.Message)"
        return $false
    }
    finally {
        $ProgressPreference = $previousProgress
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
    $outFile = $null
    $errFile = $null
    $proc = $null
    $outTask = $null
    $errTask = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $outFile = Join-Path $env:TEMP "ext_$([guid]::NewGuid()).out"
        $errFile = Join-Path $env:TEMP "ext_$([guid]::NewGuid()).err"
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
            try { $proc.Kill($true) } catch { try { $proc.Kill() } catch { } }
            $null = $proc.WaitForExit()
            Write-ToolkitLog -Level 'ERROR' -Message "External command timed out after $TimeoutSeconds s: $FilePath $($ArgumentList -join ' ')"
            return [pscustomobject]@{
                ExitCode = -2; TimedOut = $true; Accepted = $false
                StdOut = ''; StdErr = ''; DurationMs = $stopwatch.ElapsedMilliseconds
                Command = "$FilePath $($ArgumentList -join ' ')"
            }
        }
        $capturedOut = try { $outTask.GetAwaiter().GetResult() } catch { '' }
        $capturedErr = try { $errTask.GetAwaiter().GetResult() } catch { '' }
        Set-Content -Path $outFile -Value $capturedOut -Encoding UTF8 -ErrorAction SilentlyContinue
        Set-Content -Path $errFile -Value $capturedErr -Encoding UTF8 -ErrorAction SilentlyContinue
        $stdOut = if ($CaptureOutput) { $capturedOut } else { '' }
        $stdErr = if ($CaptureOutput) { $capturedErr } else { '' }
        return [pscustomobject]@{
            ExitCode   = $proc.ExitCode
            TimedOut   = $false
            Accepted   = ($AcceptedExitCodes -contains $proc.ExitCode)
            StdOut     = $stdOut
            StdErr     = $stdErr
            DurationMs = $stopwatch.ElapsedMilliseconds
            Command    = "$FilePath $($ArgumentList -join ' ')"
        }
    }
    catch {
        Write-ToolkitLog -Level 'ERROR' -Message "External command failed ($FilePath): $($_.Exception.Message)"
        return [pscustomobject]@{
            ExitCode = -1; TimedOut = $false; Accepted = $false; Error = $_.Exception.Message
            StdOut = ''; StdErr = ''; DurationMs = $stopwatch.ElapsedMilliseconds
            Command = "$FilePath $($ArgumentList -join ' ')"
        }
    }
    finally {
        $stopwatch.Stop()
        if ($proc) { $proc.Dispose() }
        if ($outFile -and (Test-Path $outFile)) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }
        if ($errFile -and (Test-Path $errFile)) { Remove-Item $errFile -Force -ErrorAction SilentlyContinue }
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
        $tempDir = $script:AppConfig.Paths.Temp
        if (-not (Test-Path $tempDir)) { $null = New-Item -Path $tempDir -ItemType Directory -Force -ErrorAction Stop }
        $downloadPath = Join-Path $tempDir $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop
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
    Write-StyledMessage -Type Info -Text "Riepilogo: Successi=$($counts.Succeeded) Modificati=$($counts.Changed) Falliti=$($counts.Failed) Saltati=$($counts.Skipped)."
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
        Initialize-UpdateServicesState
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            throw 'start-core.ps1 requires PowerShell 7 or later. Run start.ps1 instead.'
        }
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'start-core.ps1 must be started by the elevated start.ps1 stub.'
        }
        $null = Resolve-SourceTextLanguage -RequestedLanguage $Language
        Show-Header -Title $script:AppConfig.Header.Title -Version $script:AppConfig.Header.Version
        foreach ($repair in @(
                @{ Name = 'System clock'; Action = { Repair-SystemClock } },
                @{ Name = 'SCHANNEL'; Action = { Reset-SchannelSettings } },
                @{ Name = 'Hosts file'; Action = { Reset-HostsFile } },
                @{ Name = 'App Installer'; Action = { [pscustomobject]@{ Success = (Repair-Winget -Level AppxReset); Changed = $true; Message = 'App Installer repair level completed.' } } }
            )) {
            $repairResult = & $repair.Action
            Add-SetupResult -Name $repair.Name -Success ([bool]$repairResult.Success) -Changed ([bool]$repairResult.Changed) -Message $repairResult.Message
        }
        Invoke-StopUpdateServices
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.powershell0' -Args @($($PSVersionTable.PSVersion)))
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingWinToolkitConfiguration')
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.carryingOutBasicChecks')
        Update-EnvironmentPath
        Repair-Winget -Level MsStoreCert | Out-Null
        if (-not (Test-WingetFunctionality)) {
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.wingetDoesnTRespondFastRecoveryAttemptCore'))
            $coreSuccess = Repair-Winget -Level CoreInstall
            Update-EnvironmentPath
            if ($coreSuccess -and (Test-WingetFunctionality)) {
                Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.wingetRestoredQuickly'))
                Reset-WingetSources
            }
            else {
                Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.quickRecoveryFailedAttemptAdvancedSlowerMethod'))
                $null = Repair-Winget -Level FullReinstall
                Update-EnvironmentPath
                if (-not (Test-WingetFunctionality)) {
                    Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.wingetNotFunctionalAfterAllAttempts'))
                    Add-SetupResult -Name 'WinGet' -Success $false -Message 'WinGet remains unavailable after recovery.' -Blocking $true
                    throw 'WinGet is required for the installation flow and remains unavailable.'
                }
                else {
                    Reset-WingetSources
                }
            }
        }
        else {
            Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.wingetIsAlreadyOperational'))
        }
        Add-SetupResult -Name 'WinGet' -Success ([bool](Test-WingetFunctionality)) -Message 'WinGet operational.' -Blocking $true
        $null = Test-WingetAppInstaller
        Update-EnvironmentPath
        if (-not $(Test-WingetDeepValidation)) {
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.warningInstallingSubsequentPackagesViaWingetMayFail'))
        }
        $gitSuccess = Install-GitPackage
        Add-SetupResult -Name 'Git' -Success ([bool]$gitSuccess) -Message 'Git verification/installation completed.'
        if ($gitSuccess) {
            Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.gitIsAlreadyOperational'))
        }
        else {
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.attentionGitHasNotBeenInstalledOrItMayNotWorkProperly'))
        }
        $ps7Success = Install-PowerShellCore
        Add-SetupResult -Name 'PowerShell 7' -Success ([bool]$ps7Success) -Message 'PowerShell 7 verification/installation completed.'
        $wtInstalled = Install-WindowsTerminalApp
        Add-SetupResult -Name 'Windows Terminal' -Success ([bool]$wtInstalled) -Message 'Windows Terminal verification/installation completed.'
        if ($wtInstalled -and (Test-WindowsTerminalInstalled)) {
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
        Write-StyledMessage -Type Error -Text ((Get-SourceTextLoc 'uiText.criticalErrorDuringSetup0' -Args @($($_.Exception.Message))))
        Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.unhandledException01' -Args @($($_.Exception.Message), $($_.ScriptStackTrace)))
        Write-Host (Get-SourceTextLoc 'sourceText.pressAnyKeyToExit')
        $null = [Console]::ReadKey($true)
        $script:SetupExitCode = 1
        Write-SetupSummary | Out-Null
        return
    }
    finally {
        Invoke-StartUpdateServices
        try { Stop-Transcript -ErrorAction SilentlyContinue } catch { }
        $ErrorActionPreference = $previousErrorActionPreference
    }
}
Invoke-WinToolkitSetup -Language $Language
exit $script:SetupExitCode