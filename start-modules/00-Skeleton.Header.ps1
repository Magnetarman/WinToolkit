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

# ==============================================================================
# SECTION 1 · BOOTSTRAP
# Runtime options and top-level policy. This is the first fragment of the
# concatenated start-core.ps1 artefact.
# ==============================================================================

# Branch selector: the ONLY value to change to ship from Dev to main.
# Every repository-relative URL below is derived from this single switch.
$script:Branch = 'Dev'

# ==============================================================================
# SECTION 2 · GLOBAL CONFIGURATION
# Version, URLs, paths, registry keys and UI/execution variables.
# Mirrors the structure of WinToolkit-template.ps1 so a single Branch switch
# makes the whole script main-ready.
# ==============================================================================

# --- HEADER CONFIGURATION (modify here to update title and version) ---
$ToolkitVersion = "2.6.0 (Build 6)"

# Single source of truth for repository base URLs, keyed by branch.
# Switching $script:Branch flips every derived asset/profile/icon/start URL.
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
    ToolkitVersion  = $ToolkitVersion
    MsgStyles       = @{
        Success = @{ Icon = '✅'; Color = 'Green' }
        Warning = @{ Icon = '⚠️'; Color = 'Yellow' }
        Error   = @{ Icon = '❌'; Color = 'Red' }
        Info    = @{ Icon = '💎'; Color = 'Cyan' }
    }
    Header          = @{
        Title   = "Toolkit Starter By MagnetarMan"
        Version = "Version $ToolkitVersion"
    }
    URLs            = @{
        # --- Branch-dependent URLs are assigned from $script:Branch below ---
        # --- Branch-independent (aka.ms / third-party release APIs) ---
        WingetMSIX              = "https://aka.ms/getwinget"
        GitRelease              = "https://api.github.com/repos/git-for-windows/git/releases/latest"
        PowerShellRelease       = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        OhMyPoshTheme           = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
        TerminalRelease         = "https://api.github.com/repos/microsoft/terminal/releases/latest"
        WebInstaller            = "https://magnetarman.com/WinToolkit-$script:Branch"
    }
    Paths           = @{
        Logs          = "$env:LOCALAPPDATA\WinToolkit\logs"
        WinToolkitDir = "$env:LOCALAPPDATA\WinToolkit"
        Temp          = "$env:TEMP\WinToolkitSetup"
        Packages      = "$env:LOCALAPPDATA\Packages"
        Desktop       = [Environment]::GetFolderPath('Desktop')
        wtExe         = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
        wtDir         = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    }
    Registry        = @{
        TerminalStartup = "HKCU:\Console\%%Startup"
    }
    WindowsTerminal = @{
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

# ==============================================================================
# BRANCH-DEPENDENT URL RESOLUTION (single source of truth)
# ------------------------------------------------------------------------------
# Every repository-relative URL is derived HERE from the single $script:Branch
# selector. Nothing else in the script may build a branch URL by string
# concatenation: modules must read $script:AppConfig.URLs.* instead. Flipping
# $script:Branch above retargets the entire script with no other edits.
# ==============================================================================

$script:AppConfig.URLs.StartScript = "$($script:RepoRawBase)/start.ps1"
$script:AppConfig.URLs.PowerShellProfile = "$($script:RepoBase)/assets/Microsoft.PowerShell_profile.ps1"
$script:AppConfig.URLs.WindowsTerminalSettings = "$($script:RepoBase)/assets/settings.json"
$script:AppConfig.URLs.ToolkitIcon = "$($script:RepoRawBase)/images/WinToolkit.ico"

# Localization assets live under the same branch.
$script:AppConfig.URLs.LanguagesRawUrl = "$($script:RepoBase)/languages"
$script:AppConfig.URLs.LanguagesApiUrl = "https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=$($script:Branch)"

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
