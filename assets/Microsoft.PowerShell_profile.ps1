<#
.SYNOPSIS
    PowerShell Profile

.DESCRIPTION
    PowerShell profile with utilities, quick navigation, system information, and configurations.

.NOTES
    Author: MagnetarMan
#>


# ============================================================================
# PROFILE MAP
# ============================================================================
#  01 CONFIGURATION AND PATHS ..... version, remote endpoints, personal folders
#  02 CORE HELPERS ................ output, paths, privileges, process launcher
#  03 ENVIRONMENT AND SHELL ....... PSReadLine, command lookup, profile reload
#  04 FILE AND DIRECTORY ......... zip/search/mkcd, cd history, back, up
#  05 SYSTEM INFORMATION .......... computer, public IP, mainboard, RAM
#  06 NETWORK UTILITIES ........... DNS, IP/Winsock reset, speedtest
#  07 SYSTEM COMMANDS ............. reboot and shutdown
#  08 EDITOR INTEGRATION .......... editor detection and profile editing
#  09 PROGRAM UPDATES ............. profile, WinGet, pip, PowerShell
#  10 WINTOOLKIT .................. launchers and Main/Dev branch switching
#  11 MAINTENANCE AND RESET ....... PC delivery, personal backup, rollback
#  12 HELP AND ALIASES ............ help text and the help alias
#  13 PROFILE BOOTSTRAP ........... runtime init (must run last)

# Reading rule: infrastructure first, then features by topic, bootstrap last.


# ============================================================================
# 01. CONFIGURATION AND PATHS
# ============================================================================
# Single source of truth for version, remote endpoints and personal folders.
# ============================================================================


$ProfileVersion = "2.6.0.7"


$URL_WINTOOLKIT_STABLE = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/WinToolkit.ps1"
$URL_WINTOOLKIT_DEV = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/WinToolkit.ps1"
$URL_WINREG = "https://get.activated.win"
$URL_RustDesk_Setup = "https://raw.githubusercontent.com/Magnetarman/WinStarter/refs/heads/main/Asset/RustDesk/SetRustDesk.ps1"
$URL_OHMYPOSH_THEME = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
$URL_PROFILE_DEV = "https://github.com/Magnetarman/WinToolkit/raw/refs/heads/Dev/assets/Microsoft.PowerShell_profile.ps1"
$URL_IP_API = "https://am.i.mullvad.net/ip"
$URL_WINTOOLKIT_ICO_MAIN = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/images/WinToolkit.ico"
$URL_WINTOOLKIT_ICO_DEV = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/images/WinToolkit-Dev.ico"
$URL_PROFILE_MAIN = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/main/assets/Microsoft.PowerShell_profile.ps1"
$URL_PWSH_RELEASE_API = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"

# Personal/private scripts directory (out of the public WinToolkit distribution).
$PRIVATE_SCRIPTS_DIR = Join-Path $env:USERPROFILE 'Documents\Gitlab\WinToolkit-Docs\private'


# ============================================================================
# 02. CORE HELPERS
# ============================================================================
# Infrastructure reused by every other section: output, paths, privileges, process launching.
# ============================================================================


function Write-Success {
    <#
    .SYNOPSIS
        Writes a success message (green).
    .DESCRIPTION
        Centralized status helper. The emoji and the color are applied here once so
        that every message of this kind looks identical across the whole profile.
        Pass -Color only to intentionally override the default palette.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][AllowEmptyString()]
        [string]$Message,

        [ConsoleColor]$Color = 'Green'
    )

    Write-Host "✅ $Message" -ForegroundColor $Color
}


function Write-Failure {
    <#
    .SYNOPSIS
        Writes a failure message (red).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][AllowEmptyString()]
        [string]$Message,

        [ConsoleColor]$Color = 'Red'
    )

    Write-Host "❌ $Message" -ForegroundColor $Color
}


function Write-Warn {
    <#
    .SYNOPSIS
        Writes a warning message (yellow).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][AllowEmptyString()]
        [string]$Message,

        [ConsoleColor]$Color = 'Yellow'
    )

    Write-Host "⚠️ $Message" -ForegroundColor $Color
}


function Write-Info {
    <#
    .SYNOPSIS
        Writes an informational message (cyan).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][AllowEmptyString()]
        [string]$Message,

        [ConsoleColor]$Color = 'Cyan'
    )

    Write-Host "ℹ️ $Message" -ForegroundColor $Color
}


function Get-DesktopPath {
    <#
    .SYNOPSIS
        Returns the current user Desktop path (single source of truth).
    #>
    [CmdletBinding()]
    param()

    return [Environment]::GetFolderPath('Desktop')
}


function Get-WinToolkitDir {
    <#
    .SYNOPSIS
        Returns the local WinToolkit folder ($env:LOCALAPPDATA\WinToolkit).
    #>
    [CmdletBinding()]
    param()

    return (Join-Path $env:LOCALAPPDATA "WinToolkit")
}


function Assert-Admin {
    [CmdletBinding()]
    param()

    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}


function Require-Admin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$FeatureName,

        [string]$ErrorMessage = "❌ This operation requires Administrator privileges",
        [string]$InfoMessage = "ℹ️ Restart PowerShell as Administrator to run $FeatureName"
    )

    if (-not (Assert-Admin)) {
        Write-Host $ErrorMessage -ForegroundColor Red
        Write-Host $InfoMessage -ForegroundColor Cyan
        return $false
    }
    return $true
}


function Start-NonElevated {
    <#
    .SYNOPSIS
    Runs a command in a separate non-elevated (filtered) context. There is no
    built-in cmdlet to drop an admin token, so this uses a scheduled task with
    RunLevel Limited (current user), which is the supported way to launch a
    non-administrator process from an elevated session.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Command
    )
    $taskName = "WinToolkitNE_$(Get-Random)"
    try {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$Command`""
        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
        $null = Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -ErrorAction Stop
        Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
        while ((Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue).State -in 'Running', 'Queued') {
            Start-Sleep -Seconds 2
        }
    }
    finally {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
}


# ============================================================================
# 03. ENVIRONMENT AND SHELL
# ============================================================================
# Shell appearance and generic session helpers.
# ============================================================================


Set-PSReadLineOption -Colors @{
    Command   = 'Yellow'
    Parameter = 'Green'
    String    = 'DarkCyan'
}


function Test-CommandExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}


function Get-ProfileDir {
    return Split-Path -Parent $PROFILE
}


function ReloadProfile {
    & $PROFILE | Out-Null
}


# ============================================================================
# 04. FILE AND DIRECTORY MANAGEMENT
# ============================================================================
# Path helpers, plus the cd history that powers back and up.
# ============================================================================


function Expand-ZipFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$FilePath,
        [string]$DestinationPath = $pwd
    )
    Write-Host "📦 Extracting $FilePath to $DestinationPath..." -ForegroundColor Cyan

    $fullFilePath = Resolve-Path $FilePath | Select-Object -ExpandProperty Path

    if (-not (Test-Path $fullFilePath)) {
        Write-Failure "ZIP file not found: '$FilePath'"
        return
    }

    try {
        Expand-Archive -Path $fullFilePath -DestinationPath $DestinationPath -Force | Out-Null
        Write-Success "Extraction completed"
    }
    catch {
        Write-Failure "Error during extraction: $($_.Exception.Message)"
    }
}


function Find-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )
    Get-ChildItem -Recurse -Filter "*${Name}*" -ErrorAction SilentlyContinue | Select-Object FullName
}


function New-Mkcd {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Directory
    )
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    Set-Location -Path $Directory
}


function Set-LocationToDesktop {
    Set-Location -Path (Join-Path $HOME "Desktop")
}


# ---------------------------------------------------------------------------
# Directory history + 'back'/'up' (cd-aware navigation)
# ---------------------------------------------------------------------------

# Global stack of visited directories (survives profile reloads within the session)
if (-not $global:DirHistory) {
    $global:DirHistory = [System.Collections.ArrayList]::new()
}

# Wrap Set-Location (cd/sl/chdir) so every real move is recorded in the stack.
# The original cmdlet is cached to avoid infinite recursion through the alias.
$script:OriginalSetLocation = Get-Command Set-Location -CommandType Cmdlet

function Set-LocationWithHistory {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Path,
        [switch]$PassThru
    )

    # Don't pollute the stack with the "-" / "--" toggle or no-op calls
    if ($Path -and $Path -ne '-' -and $Path -ne '--') {
        if ($global:DirHistory.Count -eq 0 -or $global:DirHistory[-1] -ne $PWD.Path) {
            $null = $global:DirHistory.Add($PWD.Path)
        }
    }

    if ($Path) {
        & $script:OriginalSetLocation -Path $Path -PassThru:$PassThru -ErrorAction Stop
    }
    else {
        & $script:OriginalSetLocation -PassThru:$PassThru -ErrorAction Stop
    }
}

Set-Alias -Name cd    -Value Set-LocationWithHistory -Force -Option AllScope
Set-Alias -Name sl    -Value Set-LocationWithHistory -Force -Option AllScope
Set-Alias -Name chdir -Value Set-LocationWithHistory -Force -Option AllScope


function back {
    <#
    .SYNOPSIS
        Returns to a previous directory using the cd history stack.
    .DESCRIPTION
        'back' with no argument goes back one directory; 'back N' goes back N directories.
        Works thanks to the cd wrapper that records the directory history.
    #>
    [CmdletBinding()]
    param(
        [int]$Steps = 1
    )

    if ($Steps -le 0) {
        Write-Warn "The number of steps must be greater than 0."
        return
    }

    if ($global:DirHistory.Count -eq 0) {
        Write-Info "No directory history available." -Color Yellow
        return
    }

    if ($Steps -gt $global:DirHistory.Count) {
        Write-Warn "Requested $Steps steps, but only $($global:DirHistory.Count) directories are in history."
        $Steps = $global:DirHistory.Count
    }

    $targetIndex = $global:DirHistory.Count - $Steps
    $targetPath = $global:DirHistory[$targetIndex]

    for ($i = 0; $i -lt $Steps; $i++) {
        $global:DirHistory.RemoveAt($global:DirHistory.Count - 1)
    }

    Write-Host "🔙 Returning to: $targetPath" -ForegroundColor Cyan
    Set-Location -Path $targetPath
}


function up {
    <#
    .SYNOPSIS
        Moves up one (or more) levels in the directory tree.
    .DESCRIPTION
        'up' with no argument goes up one level, e.g. from 'C:\Users\Nomecartella'
        to 'C:\Users'. 'up N' goes up N levels at once. Going up is also recorded in
        the cd history stack, so 'back' can return to the starting directory.
        Stops at the drive/root and reports when no higher level is available.
    #>
    [CmdletBinding()]
    param(
        [int]$Levels = 1
    )

    if ($Levels -le 0) {
        Write-Warn "The number of levels must be greater than 0."
        return
    }

    $current = $PWD.ProviderPath
    if (-not $current) { $current = $PWD.Path }

    $target = $current
    for ($i = 0; $i -lt $Levels; $i++) {
        $parent = Split-Path -Path $target -Parent
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $target) {
            break
        }
        $target = $parent
    }

    if ($target -eq $current) {
        Write-Info "Already at the top of the path: $current" -Color Yellow
        return
    }

    Write-Host "⬆️ Going up: $target" -ForegroundColor Cyan

    # Use the history-aware wrapper so that 'back' can undo this move
    Set-LocationWithHistory -Path $target
}


# ============================================================================
# 05. SYSTEM INFORMATION
# ============================================================================
# Read-only hardware and network inventory.
# ============================================================================


function Get-SystemInfo {
    Get-ComputerInfo | Out-Host
}


function Get-PublicIP {
    (Invoke-WebRequest -Uri $URL_IP_API -UseBasicParsing).Content.Trim()
}


function Get-MainboardInfo {
    Get-CimInstance -ClassName Win32_baseboard | Select-Object Product, Manufacturer, Version, SerialNumber
}


function Get-RAMInfo {
    Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object PSComputerName, PartNumber, Capacity, Speed, ConfiguredVoltage, DeviceLocator, Tag, SerialNumber
}


# ============================================================================
# 06. NETWORK UTILITIES
# ============================================================================
# DNS, IP/Winsock resets and speedtests. Shared helpers first, then the features using them.
# ============================================================================


function FlushDns {
    Clear-DnsClientCache | Out-Null
    Write-Success "DNS cache flushed"
    Write-Warn "Restart the system to apply changes"
}


function Invoke-NetshReset {
    <#
    .SYNOPSIS
        Runs a 'netsh ... reset' command and reports the outcome.
    .DESCRIPTION
        Single source of truth for the netsh reset pattern: starts netsh, waits for it,
        validates the exit code and throws on failure so the caller can log the error.
        -AcceptedWarningExitCode lists exit codes treated as success with a note
        (netsh 'int ip reset' returns 1 when the reset succeeded with minor warnings).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$Arguments,

        [int[]]$AcceptedWarningExitCode = @()
    )

    $processInfo = Start-Process -FilePath "netsh" -ArgumentList $Arguments -NoNewWindow -Wait -PassThru -ErrorAction Stop

    if ($processInfo.ExitCode -eq 0) {
        return @{ Succeeded = $true; Warning = $false }
    }
    if ($AcceptedWarningExitCode -contains $processInfo.ExitCode) {
        return @{ Succeeded = $true; Warning = $true }
    }

    throw "Exit code: $($processInfo.ExitCode)"
}


function Assert-AdminConfirm {
    <#
    .SYNOPSIS
        Combines the Administrator guard with a Y/N confirmation prompt.
    .DESCRIPTION
        Returns $true when the caller may continue, $false when the user cancelled or
        lacks privileges. Each warning is displayed on its own line, in order, after the
        admin check passes. Cancelling prints the standard "Operation cancelled" notice.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$FeatureName,

        [string[]]$Warning = @(),

        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [string[]]$Info = @(),

        [string]$CancelledMessage = 'Operation cancelled'
    )

    if (-not (Require-Admin -FeatureName $FeatureName)) {
        return $false
    }

    foreach ($line in $Warning) { Write-Warn $line }
    foreach ($line in $Info) { Write-Info $line }

    $confirmation = Read-Host $Prompt
    if ($confirmation -notmatch "^[Yy]$") {
        Write-Info $CancelledMessage
        return $false
    }

    return $true
}


function Reset-IP {
    [CmdletBinding()]
    param()

    # Administrator Check + Y/N confirmation
    if (-not (Assert-AdminConfirm -FeatureName "Reset-IP" `
            -Warning @('Warning: This operation will release and renew the IP configuration') `
            -Info @('This includes release and renew of the current IP address') `
            -Prompt "❓ Do you want to proceed? (Y/N)")) {
        return
    }

    Write-Host "`n🚀 Starting IP reset..." -ForegroundColor Cyan

    try {
        Write-Host "🔄 Releasing IP address..." -ForegroundColor Cyan
        $processInfo = Start-Process -FilePath "ipconfig" -ArgumentList "/release" -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($processInfo.ExitCode -ne 0) { throw "Exit code: $($processInfo.ExitCode)" }
        Write-Success "IP address released"
    }
    catch {
        Write-Failure "IP release error: $($_.Exception.Message)"
    }

    try {
        Write-Host "🔄 Renewing IP address..." -ForegroundColor Cyan
        $processInfo = Start-Process -FilePath "ipconfig" -ArgumentList "/renew" -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($processInfo.ExitCode -ne 0) { throw "Exit code: $($processInfo.ExitCode)" }
        Write-Success "IP address renewed"
    }
    catch {
        Write-Failure "IP renew error: $($_.Exception.Message)"
    }

    Write-Success "`nIP reset completed"
    Write-Warn "Restart the system to apply changes"
}


function Get-SpeedtestExecutable {
    [CmdletBinding()]
    param()

    $packageId = "Ookla.Speedtest.CLI"

    # Check via WinGet whether the package is already installed
    $installed = $false
    try {
        $listOutput = & winget list --id $packageId --exact --source winget --accept-source-agreements 2>$null
        $installed = $LASTEXITCODE -eq 0 -and ($listOutput -join "`n") -match [regex]::Escape($packageId)
    }
    catch {
        Write-Warning "assets\Microsoft.PowerShell_profile.ps1, Get-SpeedtestExecutable: $($_.Exception.Message)"
    }

    # If missing, install the package via WinGet (machine scope requires Administrator)
    if (-not $installed) {
        if (-not (Require-Admin -FeatureName 'Speedtest')) { return $null }
        Write-Host "⬇️ $packageId is not installed. Installing via WinGet..." -ForegroundColor Yellow
        winget install --id $packageId --source winget --accept-source-agreements --accept-package-agreements --silent --scope machine
        if ($LASTEXITCODE -ne 0) {
            Write-Failure "$packageId installation failed (code $LASTEXITCODE)."
            return $null
        }
        # Refresh PATH so the freshly installed executable is found in the current session
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    }

    $speedtestExe = (Get-Command 'speedtest.exe' -CommandType Application -ErrorAction SilentlyContinue).Source
    if (-not $speedtestExe) {
        Write-Failure "speedtest.exe not found in PATH after installation."
        return $null
    }
    return $speedtestExe
}


function Show-SpeedtestSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Download,
        [Parameter(Mandatory = $true)] [string]$Upload,
        [Parameter(Mandatory = $true)] [string]$Ping,
        [string]$PingLabel = 'Ping/Idle Latency',
        [string]$Jitter,
        [string]$DownloadLatency,
        [string]$UploadLatency,
        [string]$ISP,
        [string]$Server
    )

    Write-Host "`n📋 Speedtest - Summary:" -ForegroundColor Cyan
    Write-Host ("  {0,-18}: {1} Mbps" -f "Download", $Download) -ForegroundColor Green
    Write-Host ("  {0,-18}: {1} Mbps" -f "Upload", $Upload) -ForegroundColor Green
    Write-Host ("  {0,-18}: {1} ms" -f $PingLabel, $Ping) -ForegroundColor Yellow
    if ($Jitter) { Write-Host ("  {0,-18}: {1} ms" -f "Jitter", $Jitter) -ForegroundColor Yellow }
    if ($DownloadLatency) { Write-Host ("  {0,-18}: {1} ms" -f "Download Latency", $DownloadLatency) -ForegroundColor Yellow }
    if ($UploadLatency) { Write-Host ("  {0,-18}: {1} ms" -f "Upload Latency", $UploadLatency) -ForegroundColor Yellow }
    if ($ISP) { Write-Host ("  {0,-18}: {1}" -f "ISP", $ISP) -ForegroundColor DarkCyan }
    if ($Server) { Write-Host ("  {0,-18}: {1}" -f "Server", $Server) -ForegroundColor DarkCyan }

    Write-Success "`nSpeedtest completed."
    Read-Host "Press ENTER to finish"
}


function Speedtest {
    [CmdletBinding()]
    param()

    $speedtestExe = Get-SpeedtestExecutable
    if (-not $speedtestExe) { return }

    $outputPath = Join-Path (Get-DesktopPath) "Speedtest_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
    Write-Host "🚀 Starting Speedtest..." -ForegroundColor Yellow
    Write-Host "📝 Results saved to '$outputPath'." -ForegroundColor Yellow

    # Human-readable raw output on screen + save to file (single run, no extra latency)
    & $speedtestExe --accept-license --accept-gdpr -p *>&1 | Tee-Object -FilePath $outputPath

    $text = Get-Content -Path $outputPath -Raw

    # Helper: extract first capture group or 'n/a' (guarantees a non-empty value)
    function Get-Value([string]$Pattern, [string]$InputStr) {
        $m = [regex]::Match($InputStr, $Pattern)
        if ($m.Success) { return $m.Groups[1].Value }
        return 'n/a'
    }

    $download = Get-Value '(?m)^\s*Download:\s*([\d.]+)' $text
    $upload = Get-Value '(?m)^\s*Upload:\s*([\d.]+)' $text
    $ping = Get-Value 'Latency:\s*([\d.]+)' $text
    $jitter = Get-Value 'jitter:\s*([\d.]+)\s*ms' $text
    $downloadLatency = Get-Value '(?m)^[^\S\r\n]*Download:\s*[\d.]+\s+Mbps\s+\(data used:[^)\r\n]+\)[^\S\r\n]*\r?\n[^\S\r\n]*([\d.]+)\s*ms' $text
    $uploadLatency = Get-Value '(?m)^[^\S\r\n]*Upload:\s*[\d.]+\s+Mbps\s+\(data used:[^)\r\n]+\)[^\S\r\n]*\r?\n[^\S\r\n]*([\d.]+)\s*ms' $text
    $isp = Get-Value '(?m)^\s*ISP:\s*(.+?)\r?$' $text
    $serverM = [regex]::Match($text, '(?m)^\s*Server:\s*(.+?)\r?$')
    $server = if ($serverM.Success) { $serverM.Groups[1].Value.Trim() } else { '' }

    Show-SpeedtestSummary `
        -Download $download -Upload $upload -Ping $ping -Jitter $jitter `
        -DownloadLatency $downloadLatency -UploadLatency $uploadLatency -ISP $isp -Server $server
}


function Speedtest-Advance {
    [CmdletBinding()]
    param()

    $speedtestExe = Get-SpeedtestExecutable
    if (-not $speedtestExe) { return }

    $outputPath = Join-Path (Get-DesktopPath) "Speedtest_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
    Write-Host "🚀 Starting Speedtest (Advance)..." -ForegroundColor Yellow
    Write-Host "📝 Results saved to '$outputPath'." -ForegroundColor Yellow
    Write-Host "⏳ Test in progress, please wait..." -ForegroundColor Cyan

    # JSON run: no raw output to terminal, full structured data from a single test
    & $speedtestExe --accept-license --accept-gdpr --format=jsonl --progress=no *> $outputPath

    $result = $null
    try {
        foreach ($line in (Get-Content -Path $outputPath)) {
            $line = $line.Trim()
            if ($line.StartsWith('{')) {
                $obj = $line | ConvertFrom-Json -ErrorAction Stop
                if ($obj.type -eq 'result') { $result = $obj; break }
            }
        }
    }
    catch {
        Write-Warning "assets\Microsoft.PowerShell_profile.ps1, Speedtest-Advance: $($_.Exception.Message)"
    }

    if (-not $result) {
        Write-Warn "Unable to generate the summary table: result object not found."
        Write-Success "`nSpeedtest completed."
        Read-Host "Press ENTER to finish"
        return
    }

    Show-SpeedtestSummary `
        -Download ([math]::Round($result.download.bandwidth * 8 / 1e6, 2)) `
        -Upload ([math]::Round($result.upload.bandwidth * 8 / 1e6, 2)) `
        -Ping ([math]::Round($result.ping.latency, 2)) -PingLabel 'Ping (avg)' `
        -Jitter ([math]::Round($result.ping.jitter, 2)) `
        -DownloadLatency ([math]::Round($result.download.latency.iqm, 2)) `
        -UploadLatency ([math]::Round($result.upload.latency.iqm, 2)) `
        -ISP $result.isp `
        -Server "$($result.server.name) - $($result.server.location)"
}


function Reset-Network {
    [CmdletBinding()]
    param()

    # Administrator Check + Y/N confirmation
    if (-not (Assert-AdminConfirm -FeatureName "Reset-Network" `
            -Warning @(
            'Warning: This operation will reset all network settings',
            'Network connection may be interrupted'
        ) `
            -Info @('This includes Winsock catalog, WinHTTP proxy, and IP configurations') `
            -Prompt "❓ Do you want to proceed with the reset? (Y/N)")) {
        return
    }

    Write-Host "`n🚀 Starting network settings reset..." -ForegroundColor Cyan

    # Restores clean Winsock catalog state
    try {
        Write-Host "🔄 Resetting Winsock catalog..." -ForegroundColor Cyan
        Invoke-NetshReset -Arguments @('winsock', 'reset') | Out-Null
        Write-Success "Winsock catalog reset"
    }
    catch {
        Write-Failure "Winsock reset error: $($_.Exception.Message)"
    }

    # Resets WinHTTP proxy settings to DIRECT
    try {
        Write-Host "🔄 Resetting WinHTTP proxy settings..." -ForegroundColor Cyan
        Invoke-NetshReset -Arguments @('winhttp', 'reset', 'proxy') | Out-Null
        Write-Success "WinHTTP proxy settings reset"
    }
    catch {
        Write-Failure "WinHTTP proxy reset error: $($_.Exception.Message)"
    }

    # Removes all user-defined IP configurations (exit code 1 = reset with minor warnings)
    try {
        Write-Host "🔄 Resetting IP configurations..." -ForegroundColor Cyan
        $result = Invoke-NetshReset -Arguments @('int', 'ip', 'reset') -AcceptedWarningExitCode @(1)

        if ($result.Warning) {
            Write-Success "IP configurations reset (with minor warnings)"
        }
        else {
            Write-Success "IP configurations reset"
        }
    }
    catch {
        Write-Failure "IP configuration reset error: $($_.Exception.Message)"
    }

    Write-Success "`nNetwork reset completed"
    Write-Warn "Restart your computer to apply changes"
}


# ============================================================================
# 07. SYSTEM COMMANDS
# ============================================================================
# Power control. These act immediately and do not ask for confirmation.
# ============================================================================


function doReboot {
    shutdown /r /f /t 0
}


function Shutdownfast {
    shutdown /s /hybrid /f /t 0
}


function ShutdownComplete {
    shutdown /s /f /t 0
}


# ============================================================================
# 08. EDITOR INTEGRATION
# ============================================================================
# Editor detection with fallback, and the profile editor command.
# ============================================================================


function Get-PreferredEditor {
    # Try to find Zed in PATH first
    if (Test-CommandExists -Name "zed") {
        $zedCmd = Get-Command zed -ErrorAction SilentlyContinue
        if ($zedCmd) {
            return @{
                Name    = 'Zed'
                Path    = $zedCmd.Source
                Command = $zedCmd.Source
            }
        }
    }

    # If not in PATH, check common installation locations
    $zedPaths = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Zed\Zed.exe"),
        (Join-Path $env:PROGRAMFILES "Zed\Zed.exe"),
        (Join-Path $HOME "AppData\Local\Programs\Zed\Zed.exe")
    )

    foreach ($zpath in $zedPaths) {
        if (Test-Path $zpath) {
            return @{
                Name    = 'Zed'
                Path    = $zpath
                Command = $zpath
            }
        }
    }

    # Fallback to Visual Studio Code
    if (Test-CommandExists -Name "code") {
        return @{
            Name    = 'Visual Studio Code'
            Path    = (Get-Command code).Source
            Command = 'code'
        }
    }

    # Last fallback to Notepad
    return @{
        Name    = 'Notepad'
        Path    = 'notepad.exe'
        Command = 'notepad'
    }
}


$EDITOR_INFO = Get-PreferredEditor
$EDITOR = $EDITOR_INFO.Command

if ($EDITOR -ne 'notepad') {
    Set-Alias -Name edit -Value $EDITOR -Scope Global -ErrorAction SilentlyContinue
}


function EditPSProfile {
    [CmdletBinding()]
    param()

    try {
        switch ($EDITOR_INFO.Name) {
            'Zed' {
                if (Test-Path $EDITOR_INFO.Path) {
                    Start-Process -FilePath $EDITOR_INFO.Path -ArgumentList $PROFILE
                }
                else {
                    throw "Zed not found at: $($EDITOR_INFO.Path)"
                }
            }
            'Visual Studio Code' {
                & code $PROFILE
            }
            'Notepad' {
                & notepad $PROFILE
            }
        }
    }
    catch {
        Write-Warn "Error opening with $($EDITOR_INFO.Name): $_"
        Write-Host "📝 Opening with Notepad as fallback..." -ForegroundColor Cyan
        Start-Process notepad $PROFILE
    }
}


# ============================================================================
# 09. PROGRAM UPDATES
# ============================================================================
# Update the profile itself, WinGet packages, pip packages and PowerShell.
# ============================================================================


function Invoke-WingetPackageAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    try {
        $output = @(& winget @Arguments 2>&1)
        $exitCode = $LASTEXITCODE

        foreach ($line in $output) {
            Write-Host $line
        }

        return [PSCustomObject]@{
            ExitCode = $exitCode
            Output   = ($output -join [Environment]::NewLine)
        }
    }
    catch {
        return [PSCustomObject]@{
            ExitCode = $null
            Output   = $_.Exception.Message
        }
    }
}


function Test-WingetReinstallRequired {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Result
    )

    # WinGet returns -1978335189 for both a real install-tech/scope conflict (needs reinstall)
    # and the benign "no applicable update" case (e.g. Zed). We match an explicit trigger phrase
    # and skip reinstall whenever the output says no update applies.
    $reinstallPhrases = '(?i)installed in another way|requires uninstall first|installato in un altro modo|richiede la disinstallazione'
    $noUpdatePhrases = '(?i)no applicable update|nessun aggiornamento applicabile|non si applica|does not apply'

    if ($Result.Output -match $noUpdatePhrases) {
        return $false
    }

    return $Result.Output -match $reinstallPhrases
}


function Invoke-WingetReinstall {
    <#
    .SYNOPSIS
        Performs uninstall then reinstall of a WinGet package when upgrade fails due to technology incompatibility.
    .DESCRIPTION
        WinGet cannot remove a per-user package from an elevated session. If the uninstall is blocked
        for that reason, the whole uninstall+reinstall sequence is delegated to a non-elevated context
        via Start-NonElevated (scheduled task with RunLevel Limited).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId
    )

    $uninstallArgs = @('uninstall', '--id', $PackageId, '-e', '--silent', '--accept-source-agreements')
    $installArgs = @('install', '--id', $PackageId, '-e', '--force', '--silent', '--accept-package-agreements', '--accept-source-agreements')

    Write-Host "`n🗑️ Uninstalling $PackageId..." -ForegroundColor Cyan
    $uninstallResult = Invoke-WingetPackageAction -Arguments $uninstallArgs

    $scopeBlocked = $uninstallResult.ExitCode -eq -1978335107 -or $uninstallResult.Output -match '(?i)cannot be uninstalled when running with administrator'

    if ($scopeBlocked) {
        Write-Warn "$PackageId is user-scoped and cannot be removed from an elevated session."
        Write-Host "🔄 Delegating the full uninstall+reinstall to a non-elevated context..." -ForegroundColor Cyan

        $reinstallCmd = "winget $($uninstallArgs -join ' ') ; winget $($installArgs -join ' ')"
        try {
            Start-NonElevated -Command $reinstallCmd
            Write-Success "$PackageId reinstall sequence completed (non-elevated)."
            return $true
        }
        catch {
            Write-Failure "$PackageId non-elevated reinstall failed: $($_.Exception.Message)"
            return $false
        }
    }

    if ($uninstallResult.ExitCode -ne 0) {
        Write-Failure "$PackageId uninstall failed (code $($uninstallResult.ExitCode)). Reinstall skipped."
        return $false
    }

    Write-Host "⬇️ Reinstalling $PackageId..." -ForegroundColor Cyan
    $installResult = Invoke-WingetPackageAction -Arguments $installArgs
    if ($installResult.ExitCode -eq 0) {
        Write-Success "$PackageId reinstalled successfully."
        return $true
    }

    Write-Failure "$PackageId reinstall failed (code $($installResult.ExitCode))."
    return $false
}


function PSProfileUpdate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $localProfilePath = $PROFILE
    $remoteProfileUrl = $URL_PROFILE_MAIN

    Write-Host "🔍 Checking PowerShell profile updates..." -ForegroundColor Cyan

    try {
        # Check local version from session-loaded variable
        $localVersion = $null
        if ($null -ne $ProfileVersion) {
            $localVersion = [version]$ProfileVersion
        }
        else {
            throw "Variable `$ProfileVersion not found or unknown in local profile."
        }

        # Retrieve remote content to extract version
        $remoteContent = (Invoke-WebRequest -Uri $remoteProfileUrl -UseBasicParsing -ErrorAction Stop).Content
        $match = [regex]::Match($remoteContent, '(?i)\$ProfileVersion\s*=\s*[''"]([^''"]+)[''"]')

        if (-not $match.Success) {
            throw "Unable to determine remote version from downloaded file."
        }
        $remoteVersion = [version]$match.Groups[1].Value

        if ($localVersion -ge $remoteVersion) {
            Write-Success "The profile is updated to the latest version: $localVersion"
            return
        }

        Write-Warn "An updated version is available! (Local: $localVersion -> Remote: $remoteVersion)"
        Write-Host "🔄 Updating in progress..." -ForegroundColor Cyan

        Update-ProfileFromUrl -Url $remoteProfileUrl -DestinationPath $localProfilePath
        Write-Success "Profile downloaded and replaced successfully. Restart the session to apply changes."

    }
    catch {
        Write-Warn "Issue detected: $($_.Exception.Message)" -Color Red
        Write-Host "🔄 Forcing: Downloading and overwriting remote profile to eliminate issues..." -ForegroundColor Cyan

        try {
            Update-ProfileFromUrl -Url $remoteProfileUrl -DestinationPath $localProfilePath
            Write-Success "Profile forcibly restored from remote version. Restart PowerShell."
        }
        catch {
            Write-Failure "Critical error: Unable to download the profile from the remote link. Check the network."
        }
    }
}


function Winget-Update {
    <#
    .SYNOPSIS
        Upgrades pasted WinGet package IDs and automatically reinstalls incompatible packages.
    .DESCRIPTION
        Prompts for a list of package IDs (one per line), upgrades each, and automatically
        uninstalls + reinstalls any that fail due to installation technology incompatibility.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-CommandExists -Name 'winget')) {
        Write-Failure "winget not found. Make sure App Installer is installed."
        return
    }

    Write-Host "📦 Paste the WinGet package IDs to upgrade, one per line." -ForegroundColor Cyan
    Write-Info "Press ENTER on an empty line to start."

    $packageIds = [System.Collections.Generic.List[string]]::new()
    $knownIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    while ($true) {
        $packageId = (Read-Host).Trim()
        if ([string]::IsNullOrWhiteSpace($packageId)) {
            break
        }

        if ($knownIds.Add($packageId)) {
            $packageIds.Add($packageId)
        }
        else {
            Write-Warn "Duplicate package ID ignored: $packageId"
        }
    }

    if ($packageIds.Count -eq 0) {
        Write-Info "No package IDs provided. Operation cancelled."
        return
    }

    $failedPackages = [System.Collections.Generic.List[string]]::new()

    foreach ($packageId in $packageIds) {
        Write-Host "`n🔄 Upgrading $packageId..." -ForegroundColor Cyan
        $result = Invoke-WingetPackageAction -Arguments @('upgrade', '--id', $packageId, '-e', '--silent', '--accept-package-agreements', '--accept-source-agreements')

        if (Test-WingetReinstallRequired -Result $result) {
            $failedPackages.Add($packageId)
            Write-Warn "$packageId requires an automatic reinstall after the remaining upgrades."
        }
        elseif ($result.ExitCode -eq 0) {
            Write-Success "$packageId upgraded successfully."
        }
        else {
            Write-Failure "$packageId upgrade failed (code $($result.ExitCode))."
        }
    }

    if ($failedPackages.Count -eq 0) {
        Write-Success "`nWinGet upgrades completed."
        return
    }

    Write-Host "`n🔄 Starting automatic reinstall procedure for incompatible packages..." -ForegroundColor Cyan
    foreach ($packageId in $failedPackages) {
        $null = Invoke-WingetReinstall -PackageId $packageId
    }

    Write-Success "`nWinGet upgrade procedure completed."
}


function Pip-Update {
    <#
    .SYNOPSIS
        Upgrades all outdated pip packages in the current Python environment.
    .DESCRIPTION
        Detects outdated packages via 'python -m pip list --outdated --format=json' and upgrades
        each independently. Core packages (python, pip) are excluded to avoid breaking the
        interpreter or its dependencies. Mirrors the DRY, per-package style of Winget-Update.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-CommandExists -Name 'python')) {
        Write-Failure "python not found. Make sure Python is installed and in PATH."
        return
    }

    # Core/installer packages excluded from automatic upgrade to avoid breaking the interpreter.
    $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    'python', 'pip' | ForEach-Object { $null = $excluded.Add($_) }

    Write-Host "🐍 Detecting outdated pip packages..." -ForegroundColor Cyan

    $jsonOutput = & python -m pip list --outdated --format=json 2>&1 | Out-String
    if (-not $jsonOutput.Trim()) {
        Write-Success "No outdated packages detected."
        return
    }

    try {
        $outdated = $jsonOutput | ConvertFrom-Json
    }
    catch {
        Write-Failure "Error parsing pip output: $($_.Exception.Message)"
        return
    }

    if (-not $outdated -or $outdated.Count -eq 0) {
        Write-Success "No outdated packages detected."
        return
    }

    $toUpdate = @($outdated | Where-Object { -not $excluded.Contains($_.name) })
    $skipped = @($outdated | Where-Object { $excluded.Contains($_.name) })

    if ($skipped.Count -gt 0) {
        Write-Warn "Excluded from automatic upgrade: $($skipped.name -join ', ')"
    }

    if ($toUpdate.Count -eq 0) {
        Write-Success "No upgradeable packages (all outdated packages are excluded)."
        return
    }

    Write-Host "📦 Packages to upgrade: $($toUpdate.Count)" -ForegroundColor Yellow
    $toUpdate | ForEach-Object { Write-Host " - $($_.name) ($($_.version) -> $($_.latest_version))" }

    Write-Host "`n🚀 Starting pip upgrades..." -ForegroundColor Cyan
    $failed = [System.Collections.Generic.List[string]]::new()

    foreach ($pkg in $toUpdate) {
        Write-Host "`n🔄 Upgrading $($pkg.name)..." -ForegroundColor Gray
        & python -m pip install --upgrade $pkg.name 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Upgrade of $($pkg.name) finished with code $LASTEXITCODE"
            $failed.Add($pkg.name)
        }
    }

    if ($failed.Count -eq 0) {
        Write-Success "`nPip upgrade completed."
    }
    else {
        Write-Warn "`nPip upgrade completed with $($failed.Count) error(s): $($failed -join ', ')"
    }
}


function Update-Pwsh {
    [CmdletBinding()]
    param()

    # Warning if run from Windows PowerShell 5.x instead of PowerShell 7+
    if ($PSVersionTable.PSEdition -ne 'Core') {
        Write-Warn "You are using Windows PowerShell $($PSVersionTable.PSVersion)." -Color DarkYellow
        Write-Host "   This function updates PowerShell 7+. Open a 'pwsh' session to continue." -ForegroundColor DarkYellow
        return
    }

    Write-Host "🔍 Checking PowerShell updates..." -ForegroundColor Cyan

    try {
        [version]$currentPSVersion = $PSVersionTable.PSVersion
        $latestReleaseInfo = Invoke-RestMethod -Uri $URL_PWSH_RELEASE_API -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        [version]$latestPSVersion = $latestReleaseInfo.tag_name.TrimStart('v')

        Write-Host "   Current version : v$currentPSVersion" -ForegroundColor Gray
        Write-Host "   Latest version   : v$latestPSVersion" -ForegroundColor Gray

        if ($currentPSVersion -ge $latestPSVersion) {
            Write-Success "PowerShell is already up to date (v$currentPSVersion)"
            return
        }

        # Update required
        if (-not (Require-Admin -FeatureName "Update-Pwsh" -ErrorMessage "⚠️ Administrator privileges are required to update PowerShell." -InfoMessage "   Rerun the function in an Administrator-started 'pwsh' session.")) {
            return
        }

        Write-Host "🔄 Updating PowerShell in progress (v$currentPSVersion → v$latestPSVersion)..." -ForegroundColor Yellow
        winget upgrade --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Update completed. Close and reopen the terminal to use PowerShell v$latestPSVersion."
        }
        elseif ($LASTEXITCODE -eq -1978335189) {
            Write-Host "" -ForegroundColor Yellow
            Write-Warn "Detected installation technology incompatibility (code: $LASTEXITCODE)."
            Write-Host "   The installed package uses a different method than expected by winget." -ForegroundColor DarkYellow
            Write-Host "🔄 Starting automatic reinstall procedure..." -ForegroundColor Cyan

            # Step 1: Uninstall
            Write-Host "   1/2 - Uninstalling Microsoft.PowerShell in progress..." -ForegroundColor Cyan
            winget uninstall --id Microsoft.PowerShell --accept-source-agreements --silent --all-versions
            if ($LASTEXITCODE -ne 0) {
                Write-Failure "Uninstall failed (code: $LASTEXITCODE). Operation interrupted."
                Write-Host "   Try uninstalling PowerShell manually, then run Update-Pwsh again." -ForegroundColor DarkYellow
                return
            }
            Write-Success "Uninstallation completed."

            # Step 2: Reinstall
            Write-Host "   2/2 - Installing PowerShell v$latestPSVersion in progress..." -ForegroundColor Cyan
            winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Reinstallation completed successfully."
                Write-Warn "IMPORTANT: You must open a new terminal session to use PowerShell v$latestPSVersion."
            }
            else {
                Write-Failure "Reinstall failed (code: $LASTEXITCODE)."
                Write-Host "   Check the winget output above for error details." -ForegroundColor DarkYellow
            }
        }
        else {
            Write-Warn "winget returned exit code $LASTEXITCODE. Check the output above."
        }
    }
    catch {
        Write-Failure "Unable to check or update PowerShell: $($_.Exception.Message)"
        if (-not (Test-CommandExists 'winget')) {
            Write-Host "   Tip: 'winget' not found. Make sure App Installer is installed." -ForegroundColor DarkYellow
        }
    }
}


# ============================================================================
# 10. WINTOOLKIT
# ============================================================================
# Elevated launchers in a new terminal tab, and Main/Dev branch switching.
# ============================================================================


function Start-WtIrmAsAdmin {
    <#
    .SYNOPSIS
        Downloads and executes a remote script in a new elevated Windows Terminal tab.
    .DESCRIPTION
        Single source of truth for the "wt.exe + irm | iex" pattern: launches a new
        PowerShell tab with Windows Terminal and runs 'irm <Url> | iex' elevated,
        without closing the current session (-NoExit).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Url
    )

    $remoteCommand = "irm $Url | iex"
    Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p `"PowerShell`" pwsh.exe -NoProfile -NoExit -ExecutionPolicy Bypass -Command `"$remoteCommand`"" -Verb RunAs
}


function WinToolkit-Stable {
    Start-WtIrmAsAdmin -Url $URL_WINTOOLKIT_STABLE
}


function SetRustDesk {
    [CmdletBinding()]
    param()

    Start-WtIrmAsAdmin -Url $URL_RustDesk_Setup

    Write-Host "🔍 Starting RustDesk configuration..." -ForegroundColor Cyan

}


function WinReg {
    [CmdletBinding()]
    param()

    Start-WtIrmAsAdmin -Url $URL_WINREG
}


function WinToolkit-Dev {
    Start-WtIrmAsAdmin -Url $URL_WINTOOLKIT_DEV
}


function WinToolkit-GUI {
    Start-WtIrmAsAdmin -Url 'https://magnetarman.com/Wintoolkit-gui'
}


function New-AdminShortcut {
    <#
    .SYNOPSIS
        Creates (or overwrites) a Desktop shortcut that always runs as Administrator.
    .DESCRIPTION
        Single source of truth for the WinToolkit shortcut. Besides creating the
        standard shortcut fields, it patches byte 21 of the .lnk file to set the
        "Run as administrator" flag (0x20) in the ShellLink header, which the
        COM object cannot set on its own.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ShortcutPath,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Arguments,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$IconLocation,
        [string]$Description
    )

    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($ShortcutPath)
    $link.TargetPath = $Target
    $link.Arguments = $Arguments
    $link.WorkingDirectory = $WorkingDirectory
    $link.IconLocation = $IconLocation
    if ($Description) {
        $link.Description = $Description
    }
    $link.Save()

    # Enable run as administrator by modifying .lnk file bytes
    $bytes = [IO.File]::ReadAllBytes($ShortcutPath)
    $bytes[21] = $bytes[21] -bor 32
    [IO.File]::WriteAllBytes($ShortcutPath, $bytes)
}


function Update-ProfileFromUrl {
    <#
    .SYNOPSIS
        Overwrites the local PowerShell profile with the remote version.
    .DESCRIPTION
        Shared download logic used by Set-WinToolkitBranch and PSProfileUpdate.
        Throws on failure so the caller can decide how to report the error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [string]$DestinationPath = $PROFILE
    )

    # Overwrites the profile without asking for confirmation
    Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -UseBasicParsing -ErrorAction Stop
}


function Set-WinToolkitBranch {
    <#
    .SYNOPSIS
        Switches the environment (Desktop icon + PowerShell profile) to the Main or Dev branch.
    .DESCRIPTION
        Single source of truth for the branch switch: the two branches only differ by
        icon URL/file, profile URL, WinToolkit script URL and wording, so every step is
        parameterized here instead of being copy-pasted in two nearly identical functions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('Main', 'Dev')]
        [string]$Branch
    )

    $isMain = $Branch -eq 'Main'
    $branchLower = $Branch.ToLowerInvariant()

    $iconUrl = if ($isMain) { $URL_WINTOOLKIT_ICO_MAIN } else { $URL_WINTOOLKIT_ICO_DEV }
    $iconFile = if ($isMain) { 'WinToolkit.ico' } else { 'WinToolkit-Dev.ico' }
    $profileUrl = if ($isMain) { $URL_PROFILE_MAIN } else { $URL_PROFILE_DEV }
    $scriptUrl = if ($isMain) { $URL_WINTOOLKIT_STABLE } else { $URL_WINTOOLKIT_DEV }

    $windowsApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
    $shortcutPath = Join-Path (Get-DesktopPath) "Win Toolkit.lnk"
    $iconDir = Get-WinToolkitDir
    $iconPath = Join-Path $iconDir $iconFile

    Write-Host "`n🔄 Starting WinToolkit switch procedure to the $Branch branch..." -ForegroundColor Cyan

    # 1. Recreate Desktop Shortcut
    try {
        Write-Host "📦 Recreating desktop shortcut..." -ForegroundColor Cyan

        if (-not (Test-Path $iconDir)) {
            New-Item -Path $iconDir -ItemType Directory -Force | Out-Null
        }

        # Download/Overwrite icon from the selected branch
        Invoke-WebRequest -Uri $iconUrl -OutFile $iconPath -UseBasicParsing

        New-AdminShortcut `
            -ShortcutPath $shortcutPath `
            -Target (Join-Path $windowsApps "wt.exe") `
            -Arguments ('pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm ' + $scriptUrl + ' | iex"') `
            -WorkingDirectory $windowsApps `
            -IconLocation $iconPath `
            -Description "Win Toolkit - SOPRAVVIVI A Windows"

        Write-Success "Desktop shortcut updated to $branchLower branch."
    }
    catch {
        Write-Failure "Shortcut creation error: $($_.Exception.Message)"
    }

    # 2. Replace PowerShell Profile
    try {
        Write-Host "⬇️ Downloading PowerShell profile from $branchLower branch..." -ForegroundColor Cyan

        Update-ProfileFromUrl -Url $profileUrl
        Write-Success "PowerShell profile overwritten with $branchLower version."
    }
    catch {
        Write-Failure "Profile update error: $($_.Exception.Message)"
    }

    # 3. User Notice
    Write-Host "`n🎉 Switch to $Branch branch completed successfully! Changes applied:" -ForegroundColor Green
    Write-Host "  - Desktop 'Win Toolkit' icon regenerated and pointed to $branchLower branch." -ForegroundColor Yellow
    Write-Host "  - PowerShell profile replaced with $branchLower branch version." -ForegroundColor Yellow
    Write-Warn "`n WARNING: Restart the terminal to apply the new profile changes." -Color Magenta
}


function SetBranch-Main {
    [CmdletBinding()]
    param()

    Set-WinToolkitBranch -Branch 'Main'
}


function SetBranch-Dev {
    [CmdletBinding()]
    param()

    Set-WinToolkitBranch -Branch 'Dev'
}


# ============================================================================
# 11. MAINTENANCE AND RESET
# ============================================================================
# PC delivery, personal backup and full rollback. All of these remove data or settings.
# ============================================================================


function ReadyToGo {
    [CmdletBinding()]
    param()

    Write-Host "`n🚀 Starting ReadyToGo execution..." -ForegroundColor Cyan

    # 1. Delete PSReadLine logs
    try {
        Write-Host "🧹 Deleting PSReadLine history..." -ForegroundColor Cyan
        $psReadLinePath = Join-Path $env:APPDATA "Microsoft\Windows\PowerShell\PSReadLine\*"
        Remove-Item -Path $psReadLinePath -Recurse -Force -ErrorAction Stop
        Write-Success "PSReadLine history deleted."
    }
    catch {
        Write-Failure "Error deleting PSReadLine history: $($_.Exception.Message)"
    }

    # 2. Reset Microsoft Edge
    try {
        Write-Host "🔄 Closing Microsoft Edge..." -ForegroundColor Cyan
        Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        Write-Host "🧹 Deep reset of Microsoft Edge..." -ForegroundColor Cyan
        $edgeUserDataPath = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data"
        if (Test-Path $edgeUserDataPath) {
            Remove-Item -Path $edgeUserDataPath -Recurse -Force -ErrorAction Stop
            Write-Success "Microsoft Edge user data removed (Factory reset)."
        }
        else {
            Write-Info "Microsoft Edge user data folder not found." -Color Yellow
        }
    }
    catch {
        Write-Failure "Error resetting Microsoft Edge: $($_.Exception.Message)"
    }

    # 3. Uninstall Revo Uninstaller Pro (if present)
    try {
        Write-Host "📦 Checking and uninstalling Revo Uninstaller Pro..." -ForegroundColor Cyan
        # Run silent uninstall ignoring errors and accepting agreements
        Start-Process -FilePath "winget" -ArgumentList "uninstall --id RevoUninstaller.RevoUninstallerPro --silent --accept-source-agreements" -Wait -NoNewWindow
        Write-Success "Revo Uninstaller Pro check completed."
    }
    catch {
        Write-Info "Revo Uninstaller Pro not found or error during uninstall." -Color Yellow
    }

    Write-Host "🎉 ReadyToGo operation completed successfully!" -ForegroundColor Green
}


function Nuke {
    <#
    .SYNOPSIS
        Personal wrapper: dot-sources the user's own 'nuke.ps1' from the private scripts folder.
    .DESCRIPTION
        Personal helper that loads a private script kept out of the public
        WinToolkit distribution. The script location is resolved through the
        centralized $PRIVATE_SCRIPTS_DIR variable. If the file is missing, a
        clear message tells the user where to place it.
    #>
    [CmdletBinding()]
    param()

    $nukeScript = Join-Path $PRIVATE_SCRIPTS_DIR 'nuke.ps1'

    if (-not (Test-Path $nukeScript)) {
        Write-Failure "Nuke script not found: $nukeScript"
        Write-Info "Place your personal 'nuke.ps1' in the private scripts folder to enable this command."
        Write-Host "   Folder: $PRIVATE_SCRIPTS_DIR" -ForegroundColor DarkGray
        return
    }

    try {
        . $nukeScript
    }
    catch {
        Write-Failure "Unable to load nuke.ps1: $($_.Exception.Message)"
        return
    }

    if (-not (Get-Command -Name 'Nuke' -ErrorAction SilentlyContinue)) {
        Write-Failure "The script was loaded but no 'Nuke' function was found inside it."
        return
    }

    # Forward arguments (none expected, kept for future expansion)
    Nuke @args
}


function PS-Reset {
    [CmdletBinding()]
    param()

    # 1. Administrator Check (Required for uninstallations and restart) + Y/N confirmation
    if (-not (Assert-AdminConfirm -FeatureName "PS-Reset" `
            -Warning @(
            'WARNING: This operation will perform a FULL ROLLBACK:',
            '  - It will uninstall OhMyPosh, Zoxide, Btop, Fastfetch, and Nerd Fonts.',
            '  - It will delete WinToolkit folders, logs, and temporary files.',
            '  - It will reset Windows Terminal and the PowerShell profile to factory settings.'
        ) `
            -Prompt "`n❓ Do you want to proceed irreversibly? (Y/N)" `
            -CancelledMessage 'Operation cancelled.')) {
        return
    }

    Write-Host "  - It will automatically RESTART the system when finished." -ForegroundColor Red

    Write-Host "`n🔄 Starting deep reset procedure..." -ForegroundColor Cyan

    # 2. Remove Desktop Shortcut
    Write-Host "`n🗑️ Removing desktop shortcut..." -ForegroundColor Cyan
    $desktopPath = Get-DesktopPath
    $shortcut = Join-Path $desktopPath "Win Toolkit.lnk"
    if (Test-Path $shortcut) {
        Remove-Item -Path $shortcut -Force -ErrorAction SilentlyContinue
        Write-Success "Desktop shortcut removed."
    }

    # 3. Clean system and temporary folders
    Write-Host "`n🧹 Cleaning temporary files and WinToolkit directories..." -ForegroundColor Cyan
    $directoriesToRemove = @(
        (Get-WinToolkitDir),
        (Join-Path $env:TEMP "WinToolkitSetup"),
        (Join-Path $env:TEMP "WinToolkitWinget")
    )

    foreach ($dir in $directoriesToRemove) {
        if (Test-Path $dir) {
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "   -> Removed directory: $dir" -ForegroundColor DarkGray
        }
    }
    Write-Success "Folder cleanup completed."

    # 4. Reset Windows Terminal
    Write-Host "`n🔄 Resetting Windows Terminal settings..." -ForegroundColor Cyan
    $wtSettingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (Test-Path $wtSettingsPath) {
        Remove-Item -Path $wtSettingsPath -Force -ErrorAction SilentlyContinue
        Write-Success "Windows Terminal settings removed."
    }

    # 5. Delete PowerShell Profile Directory (profiles, .bak, Themes) before Oh My Posh uninstall to avoid shell crashes
    Write-Host "`n🗑️ Deleting PowerShell profile configurations..." -ForegroundColor Cyan
    $profileDir = Split-Path -Parent $PROFILE
    if (Test-Path $profileDir) {
        Remove-Item -Path $profileDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "PowerShell profile directory deleted."
    }

    # 6. Uninstall Winget packages last, via Start-NonElevated (per-user packages can't be removed from an elevated session)
    $wingetPackages = @(
        "JanDeDobbeleer.OhMyPosh",
        "ajeetdsouza.zoxide",
        "aristocratos.btop4win",
        "Fastfetch-cli.Fastfetch",
        "DEVCOM.JetBrainsMonoNerdFont"
    )

    $wingetCommand = ($wingetPackages | ForEach-Object {
            "winget uninstall --id '$_' --silent --accept-source-agreements"
        }) -join '; '

    try {
        Write-Host "`n📦 Uninstalling command-line tools via Winget (non-elevated)..." -ForegroundColor Cyan
        Start-NonElevated -Command $wingetCommand
    }
    catch {
        Write-Warn "Non-elevated uninstall failed, falling back..."
        foreach ($pkg in $wingetPackages) {
            Start-Process winget -ArgumentList "uninstall --id $pkg --silent --accept-source-agreements" -Wait -NoNewWindow
        }
    }
    Write-Success "Winget uninstallations completed."

    # 7. Conclusion and Timed Restart
    Write-Host "`n🎉 RESET COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "The environment has been restored to factory settings." -ForegroundColor Magenta
    Write-Host "The system will restart to clear pending processes and finalize the changes.`n" -ForegroundColor Yellow

    # 10 seconds countdown
    for ($i = 10; $i -gt 0; $i--) {
        Write-Host "`r⏳ Automatic restart in $i seconds... " -NoNewline -ForegroundColor Red
        Start-Sleep -Seconds 1
    }

    Write-Host "`n`n🚀 Starting system restart..." -ForegroundColor Cyan
    shutdown /r /f /t 0
}


# ============================================================================
# 12. HELP AND ALIASES
# ============================================================================
# The help command and its alias. Mirrors the section order above.
# ============================================================================


function Show-Help {
    $helpText = @"
$($PSStyle.Foreground.Cyan)PowerShell Profile Guide$($PSStyle.Reset) $($PSStyle.Foreground.Red)========================================================$($PSStyle.Reset)

$($PSStyle.Foreground.Green)Green (Safe):$($PSStyle.Reset) Usage does not pose risks or issues.
$($PSStyle.Foreground.Yellow)Yellow (Warning):$($PSStyle.Reset) Warning! Read the description because these commands can make risky system changes.
$($PSStyle.Foreground.Red)Red (ALERT!):$($PSStyle.Reset) STOP! These functions are designed to perform deep and destructive changes. Be careful!

$($PSStyle.Foreground.Green)====================================================================================$($PSStyle.Reset)

$($PSStyle.Foreground.Cyan)Environment and Base Configuration$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)ReloadProfile$($PSStyle.Reset)             - Reloads the current PowerShell profile.

$($PSStyle.Foreground.Cyan)File and Directory Management$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)-----------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)New-Mkcd$($PSStyle.Reset)                  - Creates a directory and moves into it.
$($PSStyle.Foreground.Green)Find-File$($PSStyle.Reset)                 - Searches files recursively by partial name.
$($PSStyle.Foreground.Green)Expand-ZipFile$($PSStyle.Reset)            - Extracts a ZIP file into the current directory.
$($PSStyle.Foreground.Green)Set-LocationToDesktop$($PSStyle.Reset)     - Navigates to the Desktop directory.
$($PSStyle.Foreground.Green)back$($PSStyle.Reset)                      - Returns to a previous directory (cd history-aware).
$($PSStyle.Foreground.Green)up$($PSStyle.Reset)                        - Goes up one level in the directory tree (e.g. C:\Users\Name -> C:\Users).

$($PSStyle.Foreground.Cyan)System Information$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)------------------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Get-SystemInfo$($PSStyle.Reset)            - Displays detailed system information.
$($PSStyle.Foreground.Green)Get-MainboardInfo$($PSStyle.Reset)         - Motherboard information.
$($PSStyle.Foreground.Green)Get-RAMInfo$($PSStyle.Reset)               - Information about installed RAM modules.
$($PSStyle.Foreground.Green)Get-PublicIP$($PSStyle.Reset)              - Retrieves the public IP address.

$($PSStyle.Foreground.Cyan)Network Utilities$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)------------------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Speedtest$($PSStyle.Reset)                 - Runs a network speed test (human-readable).
$($PSStyle.Foreground.Yellow)Speedtest-Advance$($PSStyle.Reset)         - Advanced speed test (JSON) with full latency stats.
$($PSStyle.Foreground.Green)FlushDns$($PSStyle.Reset)                  - Flushes the DNS cache.
$($PSStyle.Foreground.Yellow)Reset-IP$($PSStyle.Reset)                  - Releases and renews the network adapter IP address.
$($PSStyle.Foreground.Yellow)Reset-Network$($PSStyle.Reset)             - Restores network settings to default.

$($PSStyle.Foreground.Cyan)Programs Update$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)------------------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Update-Pwsh$($PSStyle.Reset)               - Updates PowerShell to the latest version.
$($PSStyle.Foreground.Yellow)Winget-Update$($PSStyle.Reset)             - Upgrades pasted WinGet package IDs and automatically reinstalls incompatible packages.
$($PSStyle.Foreground.Yellow)Pip-Update$($PSStyle.Reset)                - Upgrades all outdated pip packages (excludes python/pip).
$($PSStyle.Foreground.Green)PSProfileUpdate$($PSStyle.Reset)           - Updates the PowerShell profile to the latest version.

$($PSStyle.Foreground.Cyan)System$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)--------------------------------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)doReboot$($PSStyle.Reset)                  - Reboots the system immediately.
$($PSStyle.Foreground.Green)Shutdownfast$($PSStyle.Reset)              - Hybrid shutdown (enables Fast Startup on next boot).
$($PSStyle.Foreground.Green)ShutdownComplete$($PSStyle.Reset)          - Full shutdown (bypasses Fast Startup).
$($PSStyle.Foreground.Red)WinReg$($PSStyle.Reset)                    - Activates Windows/Office (MAS).
$($PSStyle.Foreground.Red)SetRustDesk$($PSStyle.Reset)               - Configures RustDesk for remote control.
$($PSStyle.Foreground.Yellow)PS-Reset$($PSStyle.Reset)                  - Resets Windows Terminal and removes this profile.
$($PSStyle.Foreground.Red)ReadyToGo$($PSStyle.Reset)                 - Prepares the PC for final use (PC Delivery).
$($PSStyle.Foreground.Green)btop$($PSStyle.Reset)                      - System resource monitor for the terminal.
$($PSStyle.Foreground.Blue)Nuke$($PSStyle.Reset)                      - Pre-format full backup. (Personal: loads nuke.ps1 from Private Directory; will not work for other users.)

$($PSStyle.Foreground.Cyan)WinToolkit$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)---------------------------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)WinToolkit-Stable$($PSStyle.Reset)         - Launches WinToolkit (stable).
$($PSStyle.Foreground.Yellow)WinToolkit-Dev$($PSStyle.Reset)            - Launches WinToolkit (Dev).
$($PSStyle.Foreground.Magenta)WinToolkit-GUI$($PSStyle.Reset)            - Launches WinToolkit (GUI version).
$($PSStyle.Foreground.Yellow)SetBranch-Main$($PSStyle.Reset)            - Switches the environment (Icon and Profile) to main branch.
$($PSStyle.Foreground.Yellow)SetBranch-Dev$($PSStyle.Reset)             - Switches the environment (Icon and Profile) to dev branch.

$($PSStyle.Foreground.Cyan)Editor Configuration$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)----------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)EditPSProfile$($PSStyle.Reset)             - Opens the PowerShell profile in the editor.

$($PSStyle.Foreground.Cyan)Configured Editor$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)-----------------------------------------------------------------$($PSStyle.Reset)
Editor: $($PSStyle.Foreground.Magenta)$($EDITOR_INFO.Name)$($PSStyle.Reset)

$($PSStyle.Foreground.Green)====================================================================================$($PSStyle.Reset)
Type '$($PSStyle.Foreground.Magenta)help$($PSStyle.Reset)' to display this message.
"@
    Write-Host $helpText
}

Set-Alias -Name help -Value Show-Help


# ============================================================================
# PROFILE BOOTSTRAP (runtime initialization - must run last)
# ============================================================================

# Oh My Posh
$profileDir = Get-ProfileDir
$themeName = "atomic"
$localThemePath = Join-Path $profileDir "Themes\$themeName.omp.json"

if (-not (Test-Path $localThemePath)) {
    $themeUrl = $URL_OHMYPOSH_THEME
    try {
        Write-Host "⬇️ Downloading Oh My Posh theme..." -ForegroundColor Cyan
        $themesDir = Join-Path $profileDir "Themes"
        if (-not (Test-Path $themesDir)) {
            New-Item -ItemType Directory -Path $themesDir -Force | Out-Null
        }
        Invoke-WebRequest -Uri $themeUrl -OutFile $localThemePath -UseBasicParsing -ErrorAction Stop
        Write-Success "Theme '$themeName' downloaded to: $localThemePath"
    }
    catch {
        Write-Warning "Unable to download atomic.omp.json theme: $($_.Exception.Message)"
        $localThemePath = $null
    }
}

if (Test-Path $localThemePath) {
    $ompScript = oh-my-posh init pwsh --config $localThemePath | Out-String
    . ([ScriptBlock]::Create($ompScript))
}
else {
    $fallbackUrl = $URL_OHMYPOSH_THEME
    Write-Warning "Local theme not available. Using remote fallback."
    $ompScript = oh-my-posh init pwsh --config $fallbackUrl | Out-String
    . ([ScriptBlock]::Create($ompScript))
}

# zoxide
if (Test-CommandExists -Name "zoxide") {
    $zoxideScript = zoxide init powershell | Out-String
    . ([ScriptBlock]::Create($zoxideScript))
}

# fastfetch
if (Test-CommandExists -Name "fastfetch") {
    fastfetch
}

Write-Host ""
Write-Host "💡 Type 'help' to discover custom commands." -ForegroundColor Yellow
Write-Success "Profile loaded - Version: $ProfileVersion"

# ============================================================================
# END OF PROFILE
