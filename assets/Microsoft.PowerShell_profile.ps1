<#
.SYNOPSIS
    PowerShell Profile

.DESCRIPTION
    PowerShell profile with utilities, quick navigation, system information, and configurations.

.NOTES
    Author: MagnetarMan
#>

# ============================================================================
# CENTRALIZED CONFIGURATION (URL)
# ============================================================================

$ProfileVersion = "2.6.0.6"

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

# ============================================================================
# GLOBAL HELPER FUNCTIONS
# ============================================================================

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
# ENVIRONMENT AND BASE CONFIGURATION
# ============================================================================

# Administrator Check
$isAdmin = Assert-Admin

# Personalizzazione Prompt

function Test-CommandExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function ReloadProfile {
    & $PROFILE | Out-Null
}

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
        Write-Host "❌ ZIP file not found: '$FilePath'" -ForegroundColor Red
        return
    }

    try {
        Expand-Archive -Path $fullFilePath -DestinationPath $DestinationPath -Force | Out-Null
        Write-Host "✅ Extraction completed" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error during extraction: $($_.Exception.Message)" -ForegroundColor Red
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

# ============================================================================
# QUICK NAVIGATION
# ============================================================================

function Set-LocationToDesktop {
    Set-Location -Path (Join-Path $HOME "Desktop")
}

# ============================================================================
# SYSTEM INFORMATION
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
# NETWORK UTILITIES
# ============================================================================

function FlushDns {
    Clear-DnsClientCache | Out-Null
    Write-Host "✅ DNS cache flushed" -ForegroundColor Green
    Write-Host "⚠️ Restart the system to apply changes" -ForegroundColor Yellow
}

function Reset-IP {
    [CmdletBinding()]
    param()

    if (-not (Require-Admin -FeatureName "Reset-IP")) {
        return
    }

    Write-Host "⚠️ Warning: This operation will release and renew the IP configuration" -ForegroundColor Yellow
    Write-Host "ℹ️ This includes release and renew of the current IP address" -ForegroundColor Cyan

    $confirmation = Read-Host "❓ Do you want to proceed? (Y/N)"
    if ($confirmation -notmatch "^[Yy]$") {
        Write-Host "ℹ️ Operation cancelled" -ForegroundColor Cyan
        return
    }

    Write-Host "`n🚀 Starting IP reset..." -ForegroundColor Cyan

    try {
        Write-Host "🔄 Releasing IP address..." -ForegroundColor Cyan
        $processInfo = Start-Process -FilePath "ipconfig" -ArgumentList "/release" -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($processInfo.ExitCode -ne 0) { throw "Exit code: $($processInfo.ExitCode)" }
        Write-Host "✅ IP address released" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ IP release error: $($_.Exception.Message)" -ForegroundColor Red
    }

    try {
        Write-Host "🔄 Renewing IP address..." -ForegroundColor Cyan
        $processInfo = Start-Process -FilePath "ipconfig" -ArgumentList "/renew" -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($processInfo.ExitCode -ne 0) { throw "Exit code: $($processInfo.ExitCode)" }
        Write-Host "✅ IP address renewed" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ IP renew error: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host "`n✅ IP reset completed" -ForegroundColor Green
    Write-Host "⚠️ Restart the system to apply changes" -ForegroundColor Yellow
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
    catch {}

    # If missing, install the package via WinGet (machine scope requires Administrator)
    if (-not $installed) {
        if (-not (Require-Admin -FeatureName 'Speedtest')) { return $null }
        Write-Host "⬇️ $packageId is not installed. Installing via WinGet..." -ForegroundColor Yellow
        winget install --id $packageId --source winget --accept-source-agreements --accept-package-agreements --silent --scope machine
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ $packageId installation failed (code $LASTEXITCODE)." -ForegroundColor Red
            return $null
        }
        # Refresh PATH so the freshly installed executable is found in the current session
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    }

    $speedtestExe = (Get-Command 'speedtest.exe' -CommandType Application -ErrorAction SilentlyContinue).Source
    if (-not $speedtestExe) {
        Write-Host "❌ speedtest.exe not found in PATH after installation." -ForegroundColor Red
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
        [string]$PingLabel = 'Ping',
        [string]$Jitter,
        [string]$DownloadLatency,
        [string]$UploadLatency,
        [string]$Server
    )

    Write-Host "`n📋 Speedtest - Summary:" -ForegroundColor Cyan
    Write-Host ("  {0,-18}: {1} Mbps" -f "Download", $Download) -ForegroundColor Green
    Write-Host ("  {0,-18}: {1} Mbps" -f "Upload", $Upload) -ForegroundColor Green
    Write-Host ("  {0,-18}: {1} ms" -f $PingLabel, $Ping) -ForegroundColor Yellow
    if ($Jitter) { Write-Host ("  {0,-18}: {1} ms" -f "Jitter", $Jitter) -ForegroundColor Yellow }
    if ($DownloadLatency) { Write-Host ("  {0,-18}: {1} ms" -f "Download Latency", $DownloadLatency) -ForegroundColor Yellow }
    if ($UploadLatency) { Write-Host ("  {0,-18}: {1} ms" -f "Upload Latency", $UploadLatency) -ForegroundColor Yellow }
    if ($Server) { Write-Host ("  {0,-18}: {1}" -f "Server", $Server) -ForegroundColor DarkCyan }

    Write-Host "`n✅ Speedtest completed." -ForegroundColor Green
    Read-Host "Press ENTER to finish"
}

function Speedtest {
    [CmdletBinding()]
    param()

    $speedtestExe = Get-SpeedtestExecutable
    if (-not $speedtestExe) { return }

    $outputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "Speedtest_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
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
    $jitter = Get-Value 'jitter\):\s*([\d.]+)\s*ms' $text
    $serverM = [regex]::Match($text, '(?m)^\s*Server:\s*(.+?)\r?$')
    $server = if ($serverM.Success) { $serverM.Groups[1].Value.Trim() } else { '' }

    Show-SpeedtestSummary -Download $download -Upload $upload -Ping $ping -Jitter $jitter -Server $server
}

function Speedtest-Advance {
    [CmdletBinding()]
    param()

    $speedtestExe = Get-SpeedtestExecutable
    if (-not $speedtestExe) { return }

    $outputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "Speedtest_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
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
    catch {}

    if (-not $result) {
        Write-Host "⚠️ Unable to generate the summary table: result object not found." -ForegroundColor Yellow
        Write-Host "`n✅ Speedtest completed." -ForegroundColor Green
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
        -Server "$($result.server.name) - $($result.server.location)"
}


function Reset-Network {
    [CmdletBinding()]
    param()

    # Administrator Check
    if (-not (Require-Admin -FeatureName "Reset-Network")) {
        return
    }

    Write-Host "⚠️ Warning: This operation will reset all network settings" -ForegroundColor Yellow
    Write-Host "ℹ️ This includes Winsock catalog, WinHTTP proxy, and IP configurations" -ForegroundColor Cyan
    Write-Host "⚠️ Network connection may be interrupted" -ForegroundColor Yellow

    $confirmation = Read-Host "❓ Do you want to proceed with the reset? (Y/N)"
    if ($confirmation -notmatch "^[Yy]$") {
        Write-Host "ℹ️ Operation cancelled" -ForegroundColor Cyan
        return
    }

    Write-Host "`n🚀 Starting network settings reset..." -ForegroundColor Cyan

    # Restores clean Winsock catalog state
    try {
        Write-Host "🔄 Resetting Winsock catalog..." -ForegroundColor Cyan
        $processInfo = Start-Process -FilePath "netsh" -ArgumentList "winsock", "reset" -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($processInfo.ExitCode -ne 0) { throw "Exit code: $($processInfo.ExitCode)" }
        Write-Host "✅ Winsock catalog reset" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Winsock reset error: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Resets WinHTTP proxy settings to DIRECT
    try {
        Write-Host "🔄 Resetting WinHTTP proxy settings..." -ForegroundColor Cyan
        $processInfo = Start-Process -FilePath "netsh" -ArgumentList "winhttp", "reset", "proxy" -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($processInfo.ExitCode -ne 0) { throw "Exit code: $($processInfo.ExitCode)" }
        Write-Host "✅ WinHTTP proxy settings reset" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ WinHTTP proxy reset error: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Removes all user-defined IP configurations
    try {
        Write-Host "🔄 Resetting IP configurations..." -ForegroundColor Cyan
        $processInfo = Start-Process -FilePath "netsh" -ArgumentList "int", "ip", "reset" -NoNewWindow -Wait -PassThru -ErrorAction Stop

        if ($processInfo.ExitCode -eq 0) {
            Write-Host "✅ IP configurations reset" -ForegroundColor Green
        }
        elseif ($processInfo.ExitCode -eq 1) {
            Write-Host "✅ IP configurations reset (with minor warnings)" -ForegroundColor Green
        }
        else {
            throw "Exit code: $($processInfo.ExitCode)"
        }
    }
    catch {
        Write-Host "❌ IP configuration reset error: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host "`n✅ Network reset completed" -ForegroundColor Green
    Write-Host "⚠️ Restart your computer to apply changes" -ForegroundColor Yellow
}

# ============================================================================
# PROFILE UPDATE
# ============================================================================

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
            Write-Host "✅ The profile is updated to the latest version: $localVersion" -ForegroundColor Green
            return
        }

        Write-Host "⚠️ An updated version is available! (Local: $localVersion -> Remote: $remoteVersion)" -ForegroundColor Yellow
        Write-Host "🔄 Updating in progress..." -ForegroundColor Cyan

        Invoke-WebRequest -Uri $remoteProfileUrl -OutFile $localProfilePath -UseBasicParsing -ErrorAction Stop
        Write-Host "✅ Profile downloaded and replaced successfully. Restart the session to apply changes." -ForegroundColor Green

    }
    catch {
        Write-Host "⚠️ Issue detected: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "🔄 Forcing: Downloading and overwriting remote profile to eliminate issues..." -ForegroundColor Cyan

        try {
            Invoke-WebRequest -Uri $remoteProfileUrl -OutFile $localProfilePath -UseBasicParsing -ErrorAction Stop
            Write-Host "✅ Profile forcibly restored from remote version. Restart PowerShell." -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Critical error: Unable to download the profile from the remote link. Check the network." -ForegroundColor Red
        }
    }
}

# ============================================================================
# SYSTEM
# ============================================================================

function WinToolkit-Stable {
    Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p `"PowerShell`" pwsh.exe -NoProfile -NoExit -ExecutionPolicy Bypass -Command `"irm $URL_WINTOOLKIT_STABLE | iex`"" -Verb RunAs
}

function SetRustDesk {
    [CmdletBinding()]
    param()

    Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p `"PowerShell`" pwsh.exe -NoProfile -NoExit -ExecutionPolicy Bypass -Command `"irm $URL_RustDesk_Setup | iex`"" -Verb RunAs

    Write-Host "🔍 Starting RustDesk configuration..." -ForegroundColor Cyan

}

function WinReg {
    [CmdletBinding()]
    param()

    Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p `"PowerShell`" pwsh.exe -NoProfile -NoExit -ExecutionPolicy Bypass -Command `"irm $URL_WINREG | iex`"" -Verb RunAs
}

function WinToolkit-Dev {
    Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p `"PowerShell`" pwsh.exe -NoProfile -NoExit -ExecutionPolicy Bypass -Command `"irm $URL_WINTOOLKIT_DEV | iex`"" -Verb RunAs
}

function WinToolkit-GUI {
    Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p `"PowerShell`" pwsh.exe -NoProfile -NoExit -ExecutionPolicy Bypass -Command `"irm https://magnetarman.com/Wintoolkit-gui | iex`"" -Verb RunAs
}

function SetBranch-Main {
    [CmdletBinding()]
    param()

    Write-Host "`n🔄 Starting WinToolkit switch procedure to the Main branch..." -ForegroundColor Cyan

    # 1. Recreate Desktop Shortcut
    try {
        Write-Host "📦 Recreating desktop shortcut..." -ForegroundColor Cyan
        $desktop = [Environment]::GetFolderPath('Desktop')
        $shortcut = Join-Path $desktop "Win Toolkit.lnk"
        $iconDir = Join-Path $env:LOCALAPPDATA "WinToolkit"
        $icon = Join-Path $iconDir "WinToolkit.ico"

        if (-not (Test-Path $iconDir)) {
            New-Item -Path $iconDir -ItemType Directory -Force | Out-Null
        }

        # Download/Overwrite icon from main branch
        Invoke-WebRequest -Uri $URL_WINTOOLKIT_ICO_MAIN -OutFile $icon -UseBasicParsing

        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcut)
        $link.TargetPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\wt.exe"
        $link.Arguments = 'pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm ' + $URL_WINTOOLKIT_STABLE + ' | iex"'
        $link.WorkingDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
        $link.IconLocation = $icon
        $link.Description = "Win Toolkit - SOPRAVVIVI A Windows"
        $link.Save()

        # Enable run as administrator by modifying .lnk file bytes
        $bytes = [IO.File]::ReadAllBytes($shortcut)
        $bytes[21] = $bytes[21] -bor 32
        [IO.File]::WriteAllBytes($shortcut, $bytes)

        Write-Host "✅ Desktop shortcut updated to main branch." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Shortcut creation error: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 2. Replace PowerShell Profile
    try {
        Write-Host "⬇️ Downloading PowerShell profile from main branch..." -ForegroundColor Cyan

        # Overwrites the profile without asking for confirmation
        Invoke-WebRequest -Uri $URL_PROFILE_MAIN -OutFile $PROFILE -UseBasicParsing
        Write-Host "✅ PowerShell profile overwritten with main version." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Profile update error: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 3. User Notice
    Write-Host "`n🎉 Switch to Main branch completed successfully! Changes applied:" -ForegroundColor Green
    Write-Host "  - Desktop 'Win Toolkit' icon regenerated and pointed to main branch." -ForegroundColor Yellow
    Write-Host "  - PowerShell profile replaced with main branch version." -ForegroundColor Yellow
    Write-Host "`n⚠️  WARNING: Restart the terminal to apply the new profile changes." -ForegroundColor Magenta
}

function SetBranch-Dev {
    [CmdletBinding()]
    param()

    Write-Host "`n🔄 Starting WinToolkit switch procedure to the Dev branch..." -ForegroundColor Cyan

    # 1. Recreate Desktop Shortcut
    try {
        Write-Host "📦 Recreating desktop shortcut..." -ForegroundColor Cyan
        $desktop = [Environment]::GetFolderPath('Desktop')
        $shortcut = Join-Path $desktop "Win Toolkit.lnk"
        $iconDir = Join-Path $env:LOCALAPPDATA "WinToolkit"
        $icon = Join-Path $iconDir "WinToolkit-Dev.ico"

        if (-not (Test-Path $iconDir)) {
            New-Item -Path $iconDir -ItemType Directory -Force | Out-Null
        }

        # Download/Overwrite icon from dev branch
        Invoke-WebRequest -Uri $URL_WINTOOLKIT_ICO_DEV -OutFile $icon -UseBasicParsing

        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcut)
        $link.TargetPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\wt.exe"
        $link.Arguments = 'pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm ' + $URL_WINTOOLKIT_DEV + ' | iex"'
        $link.WorkingDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
        $link.IconLocation = $icon
        $link.Description = "Win Toolkit - SOPRAVVIVI A Windows"
        $link.Save()

        # Enable run as administrator by modifying .lnk file bytes
        $bytes = [IO.File]::ReadAllBytes($shortcut)
        $bytes[21] = $bytes[21] -bor 32
        [IO.File]::WriteAllBytes($shortcut, $bytes)

        Write-Host "✅ Desktop shortcut updated to dev branch." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Shortcut creation error: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 2. Replace PowerShell Profile
    try {
        Write-Host "⬇️ Downloading PowerShell profile from dev branch..." -ForegroundColor Cyan

        # Overwrites the profile without asking for confirmation
        Invoke-WebRequest -Uri $URL_PROFILE_DEV -OutFile $PROFILE -UseBasicParsing
        Write-Host "✅ PowerShell profile overwritten with dev version." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Profile update error: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 3. User Notice
    Write-Host "`n🎉 Switch to Dev branch completed successfully! Changes applied:" -ForegroundColor Green
    Write-Host "  - Desktop 'Win Toolkit' icon regenerated and pointed to dev branch." -ForegroundColor Yellow
    Write-Host "  - PowerShell profile replaced with dev branch version." -ForegroundColor Yellow
    Write-Host "`n⚠️  WARNING: Restart the terminal to apply the new profile changes." -ForegroundColor Magenta
}

function doReboot {
    shutdown /r /f /t 0
}

function Shutdownfast {
    shutdown /s /hybrid /f /t 0
}

function ShutdownComplete {
    shutdown /s /f /t 0
}

function PS-Reset {
    [CmdletBinding()]
    param()

    # 1. Administrator Check (Required for uninstallations and restart)
    if (-not (Require-Admin -FeatureName "PS-Reset")) {
        return
    }

    Write-Host "⚠️ WARNING: This operation will perform a FULL ROLLBACK:" -ForegroundColor Yellow
    Write-Host "  - It will uninstall OhMyPosh, Zoxide, Btop, Fastfetch, and Nerd Fonts." -ForegroundColor DarkYellow
    Write-Host "  - It will delete WinToolkit folders, logs, and temporary files." -ForegroundColor DarkYellow
    Write-Host "  - It will reset Windows Terminal and the PowerShell profile to factory settings." -ForegroundColor DarkYellow
    Write-Host "  - It will automatically RESTART the system when finished." -ForegroundColor Red

    $confirmation = Read-Host "`n❓ Do you want to proceed irreversibly? (Y/N)"

    if ($confirmation -notmatch "^[Yy]$") {
        Write-Host "ℹ️ Operation cancelled." -ForegroundColor Cyan
        return
    }

    Write-Host "`n🔄 Starting deep reset procedure..." -ForegroundColor Cyan

    # 2. Remove Desktop Shortcut
    Write-Host "`n🗑️ Removing desktop shortcut..." -ForegroundColor Cyan
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcut = Join-Path $desktopPath "Win Toolkit.lnk"
    if (Test-Path $shortcut) {
        Remove-Item -Path $shortcut -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Desktop shortcut removed." -ForegroundColor Green
    }

    # 3. Clean system and temporary folders
    Write-Host "`n🧹 Cleaning temporary files and WinToolkit directories..." -ForegroundColor Cyan
    $directoriesToRemove = @(
        (Join-Path $env:LOCALAPPDATA "WinToolkit"),
        (Join-Path $env:TEMP "WinToolkitSetup"),
        (Join-Path $env:TEMP "WinToolkitWinget")
    )

    foreach ($dir in $directoriesToRemove) {
        if (Test-Path $dir) {
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "   -> Removed directory: $dir" -ForegroundColor DarkGray
        }
    }
    Write-Host "✅ Folder cleanup completed." -ForegroundColor Green

    # 4. Reset Windows Terminal
    Write-Host "`n🔄 Resetting Windows Terminal settings..." -ForegroundColor Cyan
    $wtSettingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (Test-Path $wtSettingsPath) {
        Remove-Item -Path $wtSettingsPath -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Windows Terminal settings removed." -ForegroundColor Green
    }

    # 5. Delete PowerShell Profile Directory (Includes profiles, .bak, and Themes folder)
    # Done before Oh My Posh uninstallation to avoid shell crashes
    Write-Host "`n🗑️ Deleting PowerShell profile configurations..." -ForegroundColor Cyan
    $profileDir = Split-Path -Parent $PROFILE
    if (Test-Path $profileDir) {
        Remove-Item -Path $profileDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✅ PowerShell profile directory deleted." -ForegroundColor Green
    }

    # 6. Uninstall Winget packages (Done LAST as final resource).
    # Winget cannot reliably remove per-user packages from an elevated session,
    # so this runs non-elevated via Start-NonElevated, then the code resumes.
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
        Write-Host "⚠️ Non-elevated uninstall failed, falling back..." -ForegroundColor Yellow
        foreach ($pkg in $wingetPackages) {
            Start-Process winget -ArgumentList "uninstall --id $pkg --silent --accept-source-agreements" -Wait -NoNewWindow
        }
    }
    Write-Host "✅ Winget uninstallations completed." -ForegroundColor Green
    Write-Host "✅ Winget uninstallations completed." -ForegroundColor Green

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

function ReadyToGo {
    [CmdletBinding()]
    param()

    Write-Host "`n🚀 Starting ReadyToGo execution..." -ForegroundColor Cyan

    # 1. Delete PSReadLine logs
    try {
        Write-Host "🧹 Deleting PSReadLine history..." -ForegroundColor Cyan
        $psReadLinePath = Join-Path $env:APPDATA "Microsoft\Windows\PowerShell\PSReadLine\*"
        Remove-Item -Path $psReadLinePath -Recurse -Force -ErrorAction Stop
        Write-Host "✅ PSReadLine history deleted." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error deleting PSReadLine history: $($_.Exception.Message)" -ForegroundColor Red
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
            Write-Host "✅ Microsoft Edge user data removed (Factory reset)." -ForegroundColor Green
        }
        else {
            Write-Host "ℹ️ Microsoft Edge user data folder not found." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ Error resetting Microsoft Edge: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 3. Uninstall Revo Uninstaller Pro (if present)
    try {
        Write-Host "📦 Checking and uninstalling Revo Uninstaller Pro..." -ForegroundColor Cyan
        # Run silent uninstall ignoring errors and accepting agreements
        Start-Process -FilePath "winget" -ArgumentList "uninstall --id RevoUninstaller.RevoUninstallerPro --silent --accept-source-agreements" -Wait -NoNewWindow
        Write-Host "✅ Revo Uninstaller Pro check completed." -ForegroundColor Green
    }
    catch {
        Write-Host "ℹ️ Revo Uninstaller Pro not found or error during uninstall." -ForegroundColor Yellow
    }

    Write-Host "🎉 ReadyToGo operation completed successfully!" -ForegroundColor Green
}

# ============================================================================
# EDITOR CONFIGURATION WITH FALLBACK
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
        Write-Host "⚠️ Error opening with $($EDITOR_INFO.Name): $_" -ForegroundColor Yellow
        Write-Host "📝 Opening with Notepad as fallback..." -ForegroundColor Cyan
        Start-Process notepad $PROFILE
    }
}

# ============================================================================
# HELP E ALIAS PERSONALIZZATI
# ============================================================================

function Show-Help {
    $helpText = @"
$($PSStyle.Foreground.Cyan)PowerShell Profile Guide$($PSStyle.Reset) $($PSStyle.Foreground.Red)========================================================$($PSStyle.Reset)

$($PSStyle.Foreground.Green)Green (Safe):$($PSStyle.Reset) Usage does not pose risks or issues.
$($PSStyle.Foreground.Yellow)Yellow (Warning):$($PSStyle.Reset) Warning! Read the description because these commands can make risky system changes.
$($PSStyle.Foreground.Red)Red (ALERT!):$($PSStyle.Reset) STOP! These functions are designed to perform deep and destructive changes. Be careful!

$($PSStyle.Foreground.Green)====================================================================================$($PSStyle.Reset)

$($PSStyle.Foreground.Cyan)System and hardware information$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)----------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Get-SystemInfo$($PSStyle.Reset)            - Displays detailed system information.
$($PSStyle.Foreground.Green)Get-MainboardInfo$($PSStyle.Reset)         - Motherboard information.
$($PSStyle.Foreground.Green)Get-RAMInfo$($PSStyle.Reset)               - Information about installed RAM modules.
$($PSStyle.Foreground.Green)Get-PublicIP$($PSStyle.Reset)              - Retrieves the public IP address.

$($PSStyle.Foreground.Cyan)File and Directory Management$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)----------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)New-Mkcd$($PSStyle.Reset)                  - Creates a directory and moves into it.
$($PSStyle.Foreground.Green)Set-LocationToDesktop$($PSStyle.Reset)     - Navigates to the Desktop directory.
$($PSStyle.Foreground.Green)Find-File$($PSStyle.Reset)                 - Searches files recursively by partial name.
$($PSStyle.Foreground.Green)Expand-ZipFile$($PSStyle.Reset)            - Extracts a ZIP file into the current directory.

$($PSStyle.Foreground.Cyan)Network Diagnostics and Tools$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)----------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Speedtest$($PSStyle.Reset)                 - Runs a network speed test (human-readable).
$($PSStyle.Foreground.Yellow)Speedtest-Advance$($PSStyle.Reset)         - Advanced speed test (JSON) with full latency stats.
$($PSStyle.Foreground.Green)FlushDns$($PSStyle.Reset)                  - Flushes the DNS cache.
$($PSStyle.Foreground.Yellow)Reset-IP$($PSStyle.Reset)                  - Releases and renews the network adapter IP address.
$($PSStyle.Foreground.Yellow)Reset-Network$($PSStyle.Reset)             - Restores network settings to default.

$($PSStyle.Foreground.Cyan)System Control$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)------------------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)doReboot$($PSStyle.Reset)                  - Reboots the system immediately.
$($PSStyle.Foreground.Green)Shutdownfast$($PSStyle.Reset)              - Hybrid shutdown (enables Fast Startup on next boot).
$($PSStyle.Foreground.Green)ShutdownComplete$($PSStyle.Reset)          - Full shutdown (bypasses Fast Startup).
$($PSStyle.Foreground.Yellow)wingetupgrade$($PSStyle.Reset)             - Upgrades pasted WinGet package IDs and automatically reinstalls incompatible packages.

$($PSStyle.Foreground.Cyan)Launch WinToolkit$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)------------------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)WinToolkit-Stable$($PSStyle.Reset)         - Launches WinToolkit (stable).
$($PSStyle.Foreground.Yellow)WinToolkit-Dev$($PSStyle.Reset)            - Launches WinToolkit (Dev).
$($PSStyle.Foreground.Magenta)WinToolkit-GUI$($PSStyle.Reset)            - Launches WinToolkit (GUI version).
$($PSStyle.Foreground.Yellow)SetBranch-Main$($PSStyle.Reset)            - Switches the environment (Icon and Profile) to main branch.
$($PSStyle.Foreground.Yellow)SetBranch-Dev$($PSStyle.Reset)             - Switches the environment (Icon and Profile) to dev branch.
$($PSStyle.Foreground.Red)WinReg$($PSStyle.Reset)                    - Activates Windows/Office (MAS).
$($PSStyle.Foreground.Red)SetRustDesk$($PSStyle.Reset)               - Configures RustDesk for remote control.

$($PSStyle.Foreground.Cyan)PowerShell Profile Management$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)--------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)EditPSProfile$($PSStyle.Reset)             - Opens the PowerShell profile in the editor.
$($PSStyle.Foreground.Green)ReloadProfile$($PSStyle.Reset)             - Reloads the current PowerShell profile.
$($PSStyle.Foreground.Green)PSProfileUpdate$($PSStyle.Reset)           - Updates the PowerShell profile to the latest version.
$($PSStyle.Foreground.Yellow)PS-Reset$($PSStyle.Reset)                  - Resets Windows Terminal and removes this profile.
$($PSStyle.Foreground.Green)Update-Pwsh$($PSStyle.Reset)               - Updates PowerShell to the latest version.
$($PSStyle.Foreground.Red)ReadyToGo$($PSStyle.Reset)                 - Prepares the PC for final use (PC Delivery).

$($PSStyle.Foreground.Cyan)Terminal Utilities$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)------------------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)btop$($PSStyle.Reset)                      - System resource monitor for the terminal.


$($PSStyle.Foreground.Cyan)Configured Editor$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)-----------------------------------------------------------------$($PSStyle.Reset)
Editor: $($PSStyle.Foreground.Magenta)$($EDITOR_INFO.Name)$($PSStyle.Reset)

$($PSStyle.Foreground.Green)====================================================================================$($PSStyle.Reset)
Type '$($PSStyle.Foreground.Magenta)help$($PSStyle.Reset)' to display this message.
"@
    Write-Host $helpText
}

Set-Alias -Name help -Value Show-Help

# ============================================================================
# POWERSHELL ENHANCEMENTS
# ============================================================================

Set-PSReadLineOption -Colors @{
    Command   = 'Yellow'
    Parameter = 'Green'
    String    = 'DarkCyan'
}

# ============================================================================
# INSTALLATIONS AND INITIALIZATIONS
# ============================================================================

function Update-Pwsh {
    [CmdletBinding()]
    param()

    # Warning if run from Windows PowerShell 5.x instead of PowerShell 7+
    if ($PSVersionTable.PSEdition -ne 'Core') {
        Write-Host "⚠️ You are using Windows PowerShell $($PSVersionTable.PSVersion)." -ForegroundColor DarkYellow
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
            Write-Host "✅ PowerShell is already up to date (v$currentPSVersion)" -ForegroundColor Green
            return
        }

        # Update required
        if (-not (Require-Admin -FeatureName "Update-Pwsh" -ErrorMessage "⚠️ Administrator privileges are required to update PowerShell." -InfoMessage "   Rerun the function in an Administrator-started 'pwsh' session.")) {
            return
        }

        Write-Host "🔄 Updating PowerShell in progress (v$currentPSVersion → v$latestPSVersion)..." -ForegroundColor Yellow
        winget upgrade --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Update completed. Close and reopen the terminal to use PowerShell v$latestPSVersion." -ForegroundColor Green
        }
        elseif ($LASTEXITCODE -eq -1978335189) {
            Write-Host "" -ForegroundColor Yellow
            Write-Host "⚠️ Detected installation technology incompatibility (code: $LASTEXITCODE)." -ForegroundColor Yellow
            Write-Host "   The installed package uses a different method than expected by winget." -ForegroundColor DarkYellow
            Write-Host "🔄 Starting automatic reinstall procedure..." -ForegroundColor Cyan

            # Step 1: Uninstall
            Write-Host "   1/2 - Uninstalling Microsoft.PowerShell in progress..." -ForegroundColor Cyan
            winget uninstall --id Microsoft.PowerShell --accept-source-agreements --silent --all-versions
            if ($LASTEXITCODE -ne 0) {
                Write-Host "❌ Uninstall failed (code: $LASTEXITCODE). Operation interrupted." -ForegroundColor Red
                Write-Host "   Try uninstalling PowerShell manually, then run Update-Pwsh again." -ForegroundColor DarkYellow
                return
            }
            Write-Host "   ✅ Uninstallation completed." -ForegroundColor Green

            # Step 2: Reinstall
            Write-Host "   2/2 - Installing PowerShell v$latestPSVersion in progress..." -ForegroundColor Cyan
            winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Reinstallation completed successfully." -ForegroundColor Green
                Write-Host "⚠️ IMPORTANT: You must open a new terminal session to use PowerShell v$latestPSVersion." -ForegroundColor Yellow
            }
            else {
                Write-Host "❌ Reinstall failed (code: $LASTEXITCODE)." -ForegroundColor Red
                Write-Host "   Check the winget output above for error details." -ForegroundColor DarkYellow
            }
        }
        else {
            Write-Host "⚠️ winget returned exit code $LASTEXITCODE. Check the output above." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ Unable to check or update PowerShell: $($_.Exception.Message)" -ForegroundColor Red
        if (-not (Test-CommandExists 'winget')) {
            Write-Host "   Tip: 'winget' not found. Make sure App Installer is installed." -ForegroundColor DarkYellow
        }
    }
}

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

    # WinGet uses this exit code when the installed package technology is incompatible
    # with the available upgrade. Check it directly because WinGet output is localized.
    return $Result.ExitCode -eq -1978335189 -or $Result.Output -match '(?i)installed in another way|requires uninstall first'
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
        Write-Host "⚠️ $PackageId is user-scoped and cannot be removed from an elevated session." -ForegroundColor Yellow
        Write-Host "🔄 Delegating the full uninstall+reinstall to a non-elevated context..." -ForegroundColor Cyan

        $reinstallCmd = "winget $($uninstallArgs -join ' ') ; winget $($installArgs -join ' ')"
        try {
            Start-NonElevated -Command $reinstallCmd
            Write-Host "✅ $PackageId reinstall sequence completed (non-elevated)." -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "❌ $PackageId non-elevated reinstall failed: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }

    if ($uninstallResult.ExitCode -ne 0) {
        Write-Host "❌ $PackageId uninstall failed (code $($uninstallResult.ExitCode)). Reinstall skipped." -ForegroundColor Red
        return $false
    }

    Write-Host "⬇️ Reinstalling $PackageId..." -ForegroundColor Cyan
    $installResult = Invoke-WingetPackageAction -Arguments $installArgs
    if ($installResult.ExitCode -eq 0) {
        Write-Host "✅ $PackageId reinstalled successfully." -ForegroundColor Green
        return $true
    }

    Write-Host "❌ $PackageId reinstall failed (code $($installResult.ExitCode))." -ForegroundColor Red
    return $false
}

function wingetupgrade {
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
        Write-Host "❌ winget not found. Make sure App Installer is installed." -ForegroundColor Red
        return
    }

    Write-Host "📦 Paste the WinGet package IDs to upgrade, one per line." -ForegroundColor Cyan
    Write-Host "ℹ️ Press ENTER on an empty line to start." -ForegroundColor Cyan

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
            Write-Host "⚠️ Duplicate package ID ignored: $packageId" -ForegroundColor Yellow
        }
    }

    if ($packageIds.Count -eq 0) {
        Write-Host "ℹ️ No package IDs provided. Operation cancelled." -ForegroundColor Cyan
        return
    }

    $failedPackages = [System.Collections.Generic.List[string]]::new()

    foreach ($packageId in $packageIds) {
        Write-Host "`n🔄 Upgrading $packageId..." -ForegroundColor Cyan
        $result = Invoke-WingetPackageAction -Arguments @('upgrade', '--id', $packageId, '-e', '--silent', '--accept-package-agreements', '--accept-source-agreements')

        if (Test-WingetReinstallRequired -Result $result) {
            $failedPackages.Add($packageId)
            Write-Host "⚠️ $packageId requires an automatic reinstall after the remaining upgrades." -ForegroundColor Yellow
        }
        elseif ($result.ExitCode -eq 0) {
            Write-Host "✅ $packageId upgraded successfully." -ForegroundColor Green
        }
        else {
            Write-Host "❌ $packageId upgrade failed (code $($result.ExitCode))." -ForegroundColor Red
        }
    }

    if ($failedPackages.Count -eq 0) {
        Write-Host "`n✅ WinGet upgrades completed." -ForegroundColor Green
        return
    }

    Write-Host "`n🔄 Starting automatic reinstall procedure for incompatible packages..." -ForegroundColor Cyan
    foreach ($packageId in $failedPackages) {
        $null = Invoke-WingetReinstall -PackageId $packageId
    }

    Write-Host "`n✅ WinGet upgrade procedure completed." -ForegroundColor Green
}

# Oh My Posh
function Get-ProfileDir {
    return Split-Path -Parent $PROFILE
}

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
        Write-Host "✅ Theme '$themeName' downloaded to: $localThemePath" -ForegroundColor Green
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
Write-Host "✅ Profile loaded - Version: $ProfileVersion" -ForegroundColor Green

# ============================================================================
# END OF PROFILE
# ============================================================================
