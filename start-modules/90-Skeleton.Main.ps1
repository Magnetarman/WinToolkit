# ============================================================================
# MAIN ORCHESTRATOR
# ============================================================================
#
# This is always the last concatenated fragment of start-core.ps1.
# Elevation and the PowerShell 7 requirement are handled once, upstream, by the
# ASCII-safe start.ps1 stub; this file only verifies those invariants and stops
# with a clear error if start-core.ps1 was launched some other way.

function Invoke-WinToolkitSetup {
    <#
    .SYNOPSIS
    Main function that orchestrates the entire WinToolkit installation and configuration process.
    #>
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

        # Initialize Logging
        Start-ToolkitLog "WinToolkitStarter"
        Initialize-UpdateServicesState

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            throw 'start-core.ps1 requires PowerShell 7 or later. Run start.ps1 instead.'
        }
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'start-core.ps1 must be started by the elevated start.ps1 stub.'
        }

        # Localization is prepared here, after logging exists and after the
        # elevation check, so the GitHub API is never queried twice per run.
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

        # Pre-flight checks (Windows Defender status and pending Windows Update
        # scan) were removed: they are now handled upstream in start.ps1, which
        # blocks dependency installation and start-core until Windows updates are
        # fully completed.

        # Suspend Windows Update services to ensure Winget stability
        Invoke-StopUpdateServices

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.powershell0' -Args @($($PSVersionTable.PSVersion)))

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingWinToolkitConfiguration')
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.carryingOutBasicChecks')

        # Update PATH before initial check to detect already installed winget
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

        # Ensure Microsoft.AppInstaller is present and updated (required for a
        # fully functional and up-to-date Winget before installing any package).
        $null = Test-WingetAppInstaller
        Update-EnvironmentPath

        # Thoroughly verify that Winget works correctly.
        if (-not $(Test-WingetDeepValidation)) {
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.warningInstallingSubsequentPackagesViaWingetMayFail'))
        }

        # Installa Git
        $gitSuccess = Install-GitPackage
        Add-SetupResult -Name 'Git' -Success ([bool]$gitSuccess) -Message 'Git verification/installation completed.'
        if ($gitSuccess) {
            Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.gitIsAlreadyOperational'))
        }
        else {
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.attentionGitHasNotBeenInstalledOrItMayNotWorkProperly'))
        }

        # Check and install PowerShell 7 (application level, see 50-Module.Installers.ps1)
        $ps7Success = Install-PowerShellCore
        Add-SetupResult -Name 'PowerShell 7' -Success ([bool]$ps7Success) -Message 'PowerShell 7 verification/installation completed.'

        # Installazioni core Windows Terminal
        $wtInstalled = Install-WindowsTerminalApp
        Add-SetupResult -Name 'Windows Terminal' -Success ([bool]$wtInstalled) -Message 'Windows Terminal verification/installation completed.'

        # Imposta Windows Terminal come terminale predefinito
        if ($wtInstalled -and (Test-WindowsTerminalInstalled)) {
            $defaultTerminal = Set-WindowsTerminalAsDefault
            Add-SetupResult -Name 'Default terminal' -Success ([bool]$defaultTerminal.Success) -Changed ([bool]$defaultTerminal.Changed) -Message $defaultTerminal.Message
        }

        # ALWAYS executed: PSP environment and profile installation
        Install-PspEnvironment
        Add-SetupResult -Name 'PowerShell environment' -Success $true -Message 'PowerShell environment configured.'

        # The desktop shortcut targets wt.exe and runs pwsh: only create it when
        # both components are actually available, otherwise it would be broken.
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
# Process exit contract: 0 = full success, 2 = partial success, 1 = blocking error.
exit $script:SetupExitCode
