<#
.SYNOPSIS
    Starter script that installs and configures WinToolkit.
.DESCRIPTION
    Verifies, installs and configures some software, then creates a WinToolkit shortcut on the desktop.
.NOTES
    This file is executed by the ASCII-safe start.ps1 stub under PowerShell 7+.

    SOURCE LAYOUT
    This is the first fragment of start-core.ps1. The published artefact is
    built by concatenating every start-modules/*.ps1 file in file-name order
    (the NN- numeric prefix defines the concatenation order). The fragments are
    never loaded as PowerShell modules at runtime, because start-core.ps1 is
    distributed via "irm <url> | iex" and therefore has no $PSScriptRoot on disk.
#>

[CmdletBinding()]
param(
    [string]$Language = $(if ($env:WTOOLKIT_LANGUAGE) { $env:WTOOLKIT_LANGUAGE } else { 'Auto' })
)

Set-StrictMode -Version Latest

# Error policy:
# 1) best-effort diagnostics/repairs log a Warning and continue;
# 2) operations with a fallback log a Warning before trying the fallback;
# 3) blocking operations throw, log an Error, and are converted to exit code 1
#    by the main orchestrator. Every operation must return a meaningful result
#    when the caller can continue with a partial outcome.

# --- GLOBAL CONFIGURATION ---

$script:AppConfig = @{
    Branch           = 'Dev'
    MsgStyles        = @{
        Success = @{ Icon = '✅'; Color = 'Green' }
        Warning = @{ Icon = '⚠️'; Color = 'Yellow' }
        Error   = @{ Icon = '❌'; Color = 'Red' }
        Info    = @{ Icon = '💎'; Color = 'Cyan' }
    }
    # ============================================================================
    # HEADER CONFIGURATION - Modify here to update title and version
    # ============================================================================
    Header           = @{
        Title   = "Toolkit Starter By MagnetarMan"
        Version = "Version 2.6.0 (Build 6)"
    }
    URLs             = @{
        StartScript             = $null
        WingetMSIX              = "https://aka.ms/getwinget"
        GitRelease              = "https://api.github.com/repos/git-for-windows/git/releases/latest"
        PowerShellRelease       = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        OhMyPoshTheme           = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
        PowerShellProfile       = $null
        WindowsTerminalSettings = $null
        ToolkitIcon             = $null
        TerminalRelease         = "https://api.github.com/repos/microsoft/terminal/releases/latest"
        WebInstaller            = "https://magnetarman.com/WinToolkit-Dev"
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

# Keep every repository-relative URL on the configured branch in one place.
$script:AppConfig.URLs.StartScript = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/$($script:AppConfig.Branch)/start.ps1"
$script:AppConfig.URLs.PowerShellProfile = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/$($script:AppConfig.Branch)/assets/Microsoft.PowerShell_profile.ps1"
$script:AppConfig.URLs.WindowsTerminalSettings = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/$($script:AppConfig.Branch)/assets/settings.json"
$script:AppConfig.URLs.ToolkitIcon = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/$($script:AppConfig.Branch)/images/WinToolkit.ico"

# --- NAMED CONSTANTS (no magic numbers in the modules) ---

# 0xC0000005 STATUS_ACCESS_VIOLATION, as unsigned and signed 32-bit values.
$script:EXITCODE_ACCESS_VIOLATION = 3221225477
$script:EXITCODE_ACCESS_VIOLATION_SIGNED = -1073741819
# Offset of the flags byte in the .lnk shell link header (MS-SHLLINK).
$script:LNK_RUNAS_ADMIN_BYTE_OFFSET = 21
# Bit set in that byte to request "Run as administrator".
$script:LNK_RUNAS_ADMIN_BIT = 32
# Smallest plausible size (bytes) for a real .ico file.
$script:MIN_ICON_FILE_BYTES = 1024

# --- MUTABLE SCRIPT STATE ---

$script:TemporaryDefenderExclusionAdded = $false
$script:TemporaryDefenderExclusionPath = $null
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
