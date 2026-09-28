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

        # Localization must be resolved before any path that emits translated
        # messages. In particular, Initialize-UpdateServicesState can trigger an
        # early Windows Update service restore (when a previous run left a
        # RestoreFailed state) and that restore prints translation keys such as
        # uiText.resettingWindowsUpdateServices. Resolving first prevents
        # "[MISSING TRANSLATION]" warnings during that startup recovery.
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

        # Pre-flight checks (Windows Defender status and pending Windows Update
        # scan) were removed: they are now handled upstream in start.ps1, which
        # blocks dependency installation and start-core until Windows updates are
        # fully completed.

        # Suspend Windows Update services to ensure Winget stability
        Invoke-StopUpdateServices

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.powershell0' -Args @($PSVersionTable.PSVersion))

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingWinToolkitConfiguration')
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.carryingOutBasicChecks')

        # Update PATH before the first check, so a WinGet installed moments ago is seen.
        Update-EnvironmentPath

        Repair-Winget -Level MsStoreCert | Out-Null

        # WinGet gates the whole flow: it is probed once, and the result of the
        # last probe is the one recorded in the summary (no duplicate probe).
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

        # Ensure App Installer is present and updated (a fully functional WinGet
        # requires a current App Installer package).
        $null = Test-WingetAppInstaller
        Update-EnvironmentPath

        # Thoroughly verify that WinGet works correctly.
        if (-not (Test-WingetDeepValidation)) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.warningInstallingSubsequentPackagesViaWingetMayFail')
        }

        # Git is needed to clone private repositories and for some package installs.
        $gitSuccess = Install-GitPackage
        Add-SetupResult -Name 'Git' -Success ([bool]$gitSuccess) -Message 'Git verification/installation completed.'
        if ($gitSuccess) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitIsAlreadyOperational')
        }
        else {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.attentionGitHasNotBeenInstalledOrItMayNotWorkProperly')
            Write-ToolkitLog -Level 'WARNING' -Message 'Git is not operational: the winget path and the GitHub release fallback both failed (see the entries above).'
        }

        # Check and install PowerShell 7 (application level, see 50-Module.Installers.ps1)
        $ps7Success = Install-PowerShellCore
        Add-SetupResult -Name 'PowerShell 7' -Success ([bool]$ps7Success) -Message 'PowerShell 7 verification/installation completed.'

        # Windows Terminal is a core requirement: the shortcut and the default
        # terminal both depend on it.
        $wtInstalled = Install-WindowsTerminalApp
        Add-SetupResult -Name 'Windows Terminal' -Success ([bool]$wtInstalled) -Message 'Windows Terminal verification/installation completed.'

        # Make Windows Terminal the default terminal application.
        if ($wtInstalled) {
            $defaultTerminal = Set-WindowsTerminalAsDefault
            Add-SetupResult -Name 'Default terminal' -Success ([bool]$defaultTerminal.Success) -Changed ([bool]$defaultTerminal.Changed) -Message $defaultTerminal.Message
        }

        # ALWAYS executed: PSP environment and profile installation
        $pspResult = Install-PspEnvironment
        Add-SetupResult -Name 'PowerShell environment' -Success ([bool]$pspResult.Success) -Message $pspResult.Message

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
# Process exit contract: 0 = full success, 2 = partial success, 1 = blocking error.
exit $script:SetupExitCode
