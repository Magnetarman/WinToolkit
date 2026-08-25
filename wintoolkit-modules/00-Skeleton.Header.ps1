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
    try { [console]::TreatControlCAsInput = $true } catch {
        Write-Warning "wintoolkit-modules\00-Skeleton.Header.ps1, Read-Host 1: $($_.Exception.Message)"
    }

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
        try { [console]::TreatControlCAsInput = $oldTreatControlC } catch {
            Write-Warning "wintoolkit-modules\00-Skeleton.Header.ps1, Read-Host 2: $($_.Exception.Message)"
        }
    }
}

$ErrorActionPreference = 'Stop'
try { $Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan" } catch {
    Write-Warning "wintoolkit-modules\00-Skeleton.Header.ps1, script scope: $($_.Exception.Message)"
}


# SECTION 2 · GLOBAL CONFIGURATION
# Version, URLs, paths, registry keys and UI/execution variables.
# ==============================================================================

$ToolkitVersion = "2.6.0 (Build 5)"

# --- BRANCH SELECTOR ---
# The ONLY value to change when shipping from Dev to main.
# Every repository-relative URL below is derived from this single switch.
$Branch = 'Dev'

# Single source of truth for repository base URLs, keyed by branch.
# Switching $Branch flips every derived asset/profile/icon/start URL.
$GitHubRepoRawBase = @{
    Dev  = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev"
    main = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main"
}
$GitHubRepoBase = @{
    Dev  = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev"
    main = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/main"
}
$RepoRawBase = $GitHubRepoRawBase[$Branch]
$RepoBase    = $GitHubRepoBase[$Branch]

$AppConfig = @{
    Branch          = $Branch
    ToolkitVersion = $ToolkitVersion
    URLs            = @{
        # --- Branch-independent (aka.ms / third-party release APIs) ---
        GetHelpInstaller      = "https://aka.ms/SaRA_EnterpriseVersionFiles"

        # Video Driver (third-party CDN, always latest)
        AMDInstaller          = "https://drivers.amd.com/drivers/installer/26.10/whql/amd-software-adrenalin-edition-26.5.2-minimalsetup-260513_web.exe"

        # Store (Microsoft CDN, always latest)
        WingetInstaller       = "https://aka.ms/getwinget"
        VCRedist86            = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
        VCRedist64            = "https://aka.ms/vs/17/release/vc_redist.x64.exe"

        # --- Branch-dependent URLs are assigned from $Branch below ---
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

# ==============================================================================
# BRANCH-DEPENDENT URL RESOLUTION (single source of truth)
# ------------------------------------------------------------------------------
# Every repository-relative URL is derived HERE from the single $Branch selector.
# Nothing else may build a branch URL by string concatenation: tools must read
# $AppConfig.URLs.* instead. Flipping $Branch above retargets the entire script
# with no other edits.
# ==============================================================================

$AppConfig.URLs.OfficeSetup           = "$RepoRawBase/assets/Setup.exe"
$AppConfig.URLs.OfficeBasicConfig     = "$RepoRawBase/assets/Basic.xml"
$AppConfig.URLs.NVCleanstall          = "$RepoRawBase/assets/NVCleanstall_1.19.0.exe"
$AppConfig.URLs.DDUZip                = "$RepoRawBase/assets/DDU.zip"
$AppConfig.URLs.DriverOverridesJson   = "$RepoRawBase/assets/DriverOverrides.json"
$AppConfig.URLs.DirectXWebSetup       = "$RepoRawBase/assets/dxwebsetup.exe"

# Localization assets live under the same branch.
$AppConfig.URLs.LanguagesRawUrl = "$RepoBase/languages"
$AppConfig.URLs.LanguagesApiUrl = "https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=$Branch"
