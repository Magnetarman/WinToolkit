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
$ToolkitVersion = "2.6.0 (Build 5)"

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
    ToolkitVersion   = $ToolkitVersion
    # One style entry per Write-StyledMessage -Type value: a missing key would
    # make the icon lookup fail under Set-StrictMode.
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
        # --- Branch-dependent URLs are assigned from $script:Branch below ---
        # --- Branch-independent (aka.ms / third-party release APIs) ---
        WingetMSIX        = "https://aka.ms/getwinget"
        # VCRedistTemplate is a composite format string: {0} is the architecture
        # token (x64, x86 or arm64) resolved by Get-ArchitectureSpecificValue.
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
        # Desktop and MyDocuments are NOT resolved here on purpose: the header runs
        # before the helper functions are defined, and [Environment]::GetFolderPath
        # returns an empty string when a known folder is missing or unresolved (an
        # empty or freshly reset Documents folder), which would silently redirect the
        # profile to <drive>:\PowerShell. Both are resolved, created and verified at
        # runtime by Get-ToolkitUserFolderPath (see 80-Module.Common.ps1).
        Desktop       = $null
        MyDocuments   = $null
        wtExe         = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
        wtDir         = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    }
    # Known-folder resolution policy, consumed by Get-ToolkitUserFolderPath.
    UserScope       = @{
        # Environment variables written by the start.ps1 stub BEFORE it elevates
        # itself, so the user-scoped artifacts (profile, theme, desktop shortcut)
        # always land in the interactive user's account even when UAC elevation
        # switched to a different administrator account.
        EnvUser           = 'WTOOLKIT_ORIGINAL_USER'
        EnvUserProfile    = 'WTOOLKIT_ORIGINAL_USERPROFILE'
        EnvDesktop        = 'WTOOLKIT_ORIGINAL_DESKTOP'
        EnvMyDocuments    = 'WTOOLKIT_ORIGINAL_MYDOCUMENTS'
        # Leaf folder created (and verified) under the Documents known folder.
        PowerShellProfileFolder = 'PowerShell'
        ThemesFolderName        = 'Themes'
        ProfileFileName         = 'Microsoft.PowerShell_profile.ps1'
        ThemeFileName           = 'atomic.omp.json'
        # Smallest plausible size (bytes) of a valid .omp.json theme.
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
        # Every external wait lives here, so no call site carries a magic number.
        WingetProbe  = 30
        Winget       = 120
        Installer    = 300
        VCRedist     = 600
        Appx         = 120
        Condition    = 15
    }
    Winget          = @{
        # 0x800706BA RPC_S_SERVER_UNAVAILABLE (signed 32-bit): the App Installer
        # deployment server cannot serve the session, so every install fails while
        # read-only commands keep working.
        RpcFailureExitCode = -2147012859
        # `winget install` on an already installed package: 0x8A150061.
        # 0x8A15002B (no applicable update) covers the upgrade path.
        AlreadyInstalledExitCodes = @(-1978335135, -1978335189)
    }
    WindowsAppsPackageName = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe'
    # Non-blocking Defender check: how many times the user may confirm "continue
    # anyway" before the check is bypassed and the setup carries on regardless.
    Defender          = @{
        MaxConfirmations = 3
    }
    # Processes that lock the App Installer files during a repair or an install.
    # 'wsappx' is deliberately NOT here: it hosts the AppX/Store service, and
    # killing it is a system-wide side effect, not a WinGet cleanup. The list only
    # covers the package manager front ends and their host.
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

$script:AppConfig.URLs.StartScript = "$script:RepoRawBase/start.ps1"
$script:AppConfig.URLs.PowerShellProfile = "$script:RepoBase/assets/Microsoft.PowerShell_profile.ps1"
$script:AppConfig.URLs.WindowsTerminalSettings = "$script:RepoBase/assets/settings.json"
$script:AppConfig.URLs.ToolkitIcon = "$script:RepoRawBase/images/WinToolkit.ico"

# The Oh My Posh theme is fetched from an ordered candidate list: the first
# endpoint that answers with a valid theme wins, so one 404 is not fatal.
$script:AppConfig.URLs.OhMyPoshThemeUrls = @(
    "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json",
    "https://github.com/JanDeDobbeleer/oh-my-posh/raw/refs/heads/main/themes/atomic.omp.json",
    "https://cdn.jsdelivr.net/gh/JanDeDobbeleer/oh-my-posh@main/themes/atomic.omp.json"
)

# Localization assets live under the same branch.
$script:AppConfig.URLs.LanguagesRawUrl = "$script:RepoBase/languages"
$script:AppConfig.URLs.LanguagesApiUrl = "https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=$script:Branch"

# --- NAMED CONSTANTS (no magic numbers in the modules) ---

# 0xC0000005 STATUS_ACCESS_VIOLATION, as signed 32-bit value.
$script:EXITCODE_ACCESS_VIOLATION_SIGNED = -1073741819
# Offset of the flags byte in the .lnk shell link header (MS-SHLLINK).
$script:LNK_RUNAS_ADMIN_BYTE_OFFSET = 21
# Bit set in that byte to request "Run as administrator".
$script:LNK_RUNAS_ADMIN_BIT = 32
# Smallest plausible size (bytes) for a real .ico file.
$script:MIN_ICON_FILE_BYTES = 1024

# ==============================================================================
# RUNTIME STATE
# ------------------------------------------------------------------------------
# ONE block for everything that is filled in after the header has run. The
# previous layout declared the same data in three different styles (AppConfig
# keys set to $null, standalone $script: variables, lazy caches) purely to
# satisfy Set-StrictMode -Version Latest, which made it impossible to tell an
# intentional cache from an accidental global. Members are added here as the
# owning module needs them; nothing else declares $script: state.
# ==============================================================================

$script:State = @{
    LogFile      = $null   # active log path, set by Start-ToolkitLog
    Results      = [System.Collections.Generic.List[object]]::new()
    UserContext  = $null   # cache: Get-ToolkitOriginalUserContext
    Text         = @{ Active = $null; Default = $null }  # localization tables
    Winget       = @{ Modern = $null; ProbedExe = $null }  # cache: version probe
    SourcesReset = $false  # one `source reset --force` per run
}
