# ============================================================================
# MAIN ORCHESTRATOR
# ============================================================================
#
# This is always the last concatenated fragment of start-core.ps1.
# Elevation and the PowerShell 7 requirement are handled once, upstream, by the
# ASCII-safe start.ps1 stub; this file only verifies those invariants and stops
# with a clear error if start-core.ps1 was launched some other way.

function Reset-WingetSourcesOnce {
    <#
    .SYNOPSIS
    Runs `winget source reset --force` at most once per execution.

    .DESCRIPTION
    The recovery ladder used to call it three times in a single run (after a
    successful fast recovery, after a full reinstall, and from the database
    repair). Each call is slow and they are mutually redundant.
    #>
    if ($script:State.SourcesReset) { return }
    Reset-WingetSources
    $script:State.SourcesReset = $true
}


function Initialize-Winget {
    <#
    .SYNOPSIS
    Brings WinGet to a working state and returns a StepResult.

    .DESCRIPTION
    The recovery ladder (health -> msstore cert -> core install -> database
    repair -> core install) used to live inline in the orchestrator, where it
    mixed messaging, PATH refreshes and three separate health probes. It is one
    function here, called once, so the flow is readable.
    #>
    Update-EnvironmentPath
    $null = Repair-WingetMsStoreSource

    $health = Get-WingetHealth
    if ($health.Runs) {
        return New-StepResult -Success $true -Message "WinGet operational (v$($health.Version))."
    }

    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetDoesnTRespondFastRecoveryAttemptCore')
    $null = Install-WingetCore
    Update-EnvironmentPath
    Invalidate-WingetVersionCache
    $health = Get-WingetHealth
    if ($health.Runs) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetRestoredQuickly')
        Reset-WingetSourcesOnce
        return New-StepResult -Success $true -Changed $true -Message "WinGet restored (v$($health.Version))."
    }

    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.quickRecoveryFailedAttemptAdvancedSlowerMethod')
    $null = Repair-WingetDatabase
    $null = Install-WingetCore
    Update-EnvironmentPath
    Invalidate-WingetVersionCache
    $health = Get-WingetHealth
    if (-not $health.Runs) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFunctionalAfterAllAttempts')
        return New-StepResult -Success $false -Message 'WinGet remains unavailable after recovery.'
    }

    Reset-WingetSourcesOnce
    return New-StepResult -Success $true -Changed $true -Message "WinGet reinstalled (v$($health.Version))."
}


function Repair-HostsFileIfNeeded {
    <#
    .SYNOPSIS
    Clears the WinGet/Store hosts overrides only when the package sources fail.

    .DESCRIPTION
    The hosts file was previously rewritten on EVERY run, which discarded the
    privacy blocklist the user had configured (any 0.0.0.0 entry pointing at
    microsoft.com). It is a repair, not a routine cleanup, so it now runs only
    when the WinGet/Store health check actually reports a failure.
    #>
    $health = Get-WingetHealth
    if ($health.Runs -and $health.Reachable) {
        return New-StepResult -Success $true -Message 'WinGet sources are reachable, hosts file left untouched.'
    }

    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.hostsFileResetOnlyOnSourceFailure0')
    return Reset-HostsFile
}


function Request-DefenderPause {
    <#
    .SYNOPSIS
    Warns that Defender is active and offers to wait for the user to disable it.

    .DESCRIPTION
    Active real-time protection interferes with AppX and WinGet installs. This is
    NOT blocking: the setup continues either way. Pressing ENTER three times in a
    row bypasses the check, so a user who keeps Defender enabled (by policy, or
    by choice) is never trapped in a prompt loop. A non-interactive session skips
    the prompt entirely instead of blocking on a key that will never arrive.
    #>
    try {
        $defender = Get-MpComputerStatus -ErrorAction Stop
        if (-not $defender.RealTimeProtectionEnabled) { return $false }
    }
    catch {
        Write-ToolkitLog -Level 'DEBUG' -Message "Defender status unavailable: $($_.Exception.Message)"
        return $false
    }

    if ([Console]::IsInputRedirected) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.defenderActiveNonInteractive0')
        return $false
    }

    $maxAttempts = $script:AppConfig.Defender.MaxConfirmations
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.defenderActiveDisablePrompt0' -Args @($attempt, $maxAttempts))
        $null = Read-Host (Get-SourceTextLoc 'uiText.defenderPressEnterAfterDisabling0')

        try {
            $defender = Get-MpComputerStatus -ErrorAction Stop
            if (-not $defender.RealTimeProtectionEnabled) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.defenderDisabledContinuing0')
                return $true
            }
        }
        catch {
            Write-ToolkitLog -Level 'DEBUG' -Message "Defender status unavailable: $($_.Exception.Message)"
            break
        }
    }

    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.defenderStillActiveContinuing0')
    return $false
}


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
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingWinToolkitConfiguration')

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