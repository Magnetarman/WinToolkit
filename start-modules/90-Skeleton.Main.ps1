# ============================================================================
# MAIN ORCHESTRATOR
# ============================================================================
#
# This is always the last concatenated fragment of start-core.ps1.
# Elevation and the PowerShell 7 requirement are handled once, upstream, by the
# ASCII-safe start.ps1 stub; this file only verifies those invariants and stops
# with a clear error if start-core.ps1 was launched some other way.
#
# It contains no repair logic of its own: every step is a function owned by a
# module, and the orchestrator only decides the order, what is required
# (Blocking) and what does not apply to this system (When).


function Invoke-WinToolkitSetup {
    <#
    .SYNOPSIS
    Main function that orchestrates the entire WinToolkit installation and configuration process.
    #>
    param([string]$Language = 'Auto')

    # The process exit code is a RETURN VALUE (see the last line of the file), so
    # there is no $script:SetupExitCode to keep in sync with the results.
    $script:State.Results.Clear()
    $previousErrorActionPreference = $ErrorActionPreference

    try {
        # Preconditions come FIRST. A check that stops the run must not come after
        # a log file was created, a language file was downloaded and the Windows
        # Update services had already been restarted.
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            throw 'start-core.ps1 requires PowerShell 7 or later. Run start.ps1 instead.'
        }
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'start-core.ps1 must be started by the elevated start.ps1 stub.'
        }

        $ErrorActionPreference = 'Stop'
        $Host.UI.RawUI.WindowTitle = 'Toolkit Starter by MagnetarMan'
        Start-ToolkitLog 'WinToolkitStarter'

        # Localization must be resolved before any path that emits translated
        # messages. In particular, Initialize-UpdateServicesState can trigger an
        # early Windows Update service restore (when a previous run left a
        # RestoreFailed state) and that restore prints translation keys such as
        # uiText.resettingWindowsUpdateServices. Resolving first prevents
        # "[MISSING TRANSLATION]" warnings during that startup recovery.
        $null = Resolve-SourceTextLanguage -RequestedLanguage $Language

        Initialize-UpdateServicesState
        Show-Header -Title $script:AppConfig.Header.Title -Version $script:AppConfig.Header.Version
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.powershell0' -Args @($PSVersionTable.PSVersion))
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingWinToolkitSetup')

        # Non-blocking: real-time protection interferes with AppX installs, but the
        # setup must continue if the user keeps Defender enabled.
        $null = Request-DefenderPause

        # One table, one loop: every step returns a StepResult, the orchestrator
        # only records it. `When` marks a step that does not apply to this system
        # (Skipped, not Failed), `Blocking` marks one the flow cannot continue
        # without.
        $steps = @(
            @{ Name = 'System clock'; Run = { Repair-SystemClock } }
            @{ Name = 'SCHANNEL'; Run = { Reset-SchannelSettings } }
            @{ Name = 'Hosts file'; Run = { Repair-HostsFileIfNeeded } }
            @{ Name = 'App Installer'; Run = { Repair-AppInstaller } }
            @{ Name = 'WinGet'; Run = { Initialize-Winget }; Blocking = $true }
            @{ Name = 'Git'; Run = { Install-GitPackage } }
            @{ Name = 'Windows Terminal'; Run = { Install-WindowsTerminalApp } }
            @{ Name = 'Default terminal'; Run = { Set-WindowsTerminalAsDefault }; When = { Test-WindowsTerminalInstalled } }
            @{ Name = 'PowerShell environment'; Run = { Install-PspEnvironment } }
            # Not a Blocking step: when elevation switched account, the tools went
            # into the administrator profile. The alignment is best effort and a
            # failure degrades to a warning (S-4).
            @{ Name = 'User scope alignment'; Run = { Sync-UserScopeWithInstalledTools }
                When = { (Get-ToolkitOriginalUserContext).AccountSwitched } }
            @{ Name = 'Desktop shortcut'; Run = { New-ToolkitDesktopShortcut }
                When = { (Test-WindowsTerminalInstalled) -and (Test-CommandExists -Name 'pwsh') }
            }
        )

        # Windows Update services are suspended for the installer phase and always
        # restored by the finally block below.
        Invoke-StopUpdateServices

        foreach ($step in $steps) {
            if ($step.When -and -not (& $step.When)) {
                Add-SetupResult -Name $step.Name -Success $true -Skipped -Message 'Step not applicable on this system.'
                continue
            }

            $result = & $step.Run
            Add-SetupResult -Name $step.Name -Result $result -Blocking:([bool]$step.Blocking)

            if ($step.Blocking -and -not $result.Success) {
                throw "Required step '$($step.Name)' failed: $($result.Message)"
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
        return (Write-SetupSummary)
    }
    catch {
        Set-UpdateServicesError -Message $_.Exception.Message
        Add-SetupResult -Name 'Setup flow' -Success $false -Message $_.Exception.Message -Blocking $true
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.criticalErrorDuringSetup0' -Args @($_.Exception.Message))
        Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.unhandledException01' -Args @($_.Exception.Message, $_.ScriptStackTrace))
        if (-not [Console]::IsInputRedirected) {
            Write-Host (Get-SourceTextLoc 'sourceText.pressAnyKeyToExit')
            $null = [Console]::ReadKey($true)
        }
        Write-SetupSummary | Out-Null
        return 1
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

# Process exit contract: 0 = full success, 2 = partial success, 1 = blocking error.
exit (Invoke-WinToolkitSetup -Language $Language)
