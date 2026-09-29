# ============================================================================
# ENVIRONMENT: architecture, PATH, system repairs, Defender, readiness
# ============================================================================

function Get-SystemArchitecture {
    <#
    .SYNOPSIS
    Returns the real OS architecture (X64, X86 or ARM64), never a 32/64 guess.
    #>
    try {
        $architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    }
    catch {
        $architecture = $env:PROCESSOR_ARCHITECTURE
    }
    switch -Regex ($architecture) {
        'Arm64|ARM64' { return 'ARM64' }
        'X86|x86' { return 'X86' }
        default { return 'X64' }
    }
}


function Update-EnvironmentPath {
    <#
    .SYNOPSIS
    Reloads system and user PATH variables in the current session.
    #>
    # Reload PATH from Machine and User to detect installations in the current process
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

    # Assigning $env:Path already updates the process environment block that child
    # processes inherit, so the previous SetEnvironmentVariable(...,'Process') call
    # was a duplicate of the line above it.
    $env:Path = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
}


function Test-PathInEnvironment {
    <#
    .SYNOPSIS
    Checks if a path is present in the PATH variable of the specified environment.
    #>
    param (
        [string]$PathToCheck,
        [string]$Scope = 'Both'
    )

    # One loop over the requested scopes instead of two duplicated blocks.
    $targets = @()
    if ($Scope -in @('User', 'Both')) { $targets += 'User' }
    if ($Scope -in @('System', 'Both')) { $targets += 'Machine' }

    foreach ($target in $targets) {
        $value = [Environment]::GetEnvironmentVariable('PATH', $target)
        if ($value -and ($value -split ';').Contains($PathToCheck)) { return $true }
    }
    return $false
}


function Add-ToEnvironmentPath {
    <#
    .SYNOPSIS
    Adds a path to the PATH environment variable in the specified scope.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$PathToAdd,
        [ValidateSet('User', 'System')]
        [string]$Scope
    )

    # Written once: the scope only changes the target of the registry write.
    if (-not (Test-PathInEnvironment -PathToCheck $PathToAdd -Scope $Scope)) {
        $target = if ($Scope -eq 'System') { 'Machine' } else { 'User' }
        $currentPath = [Environment]::GetEnvironmentVariable('PATH', $target)
        $newPath = (@($currentPath, $PathToAdd) | Where-Object { $_ }) -join ';'
        [Environment]::SetEnvironmentVariable('PATH', $newPath, $target)

        # Keep the current process in sync as well.
        if (-not ($env:PATH -split ';').Contains($PathToAdd)) {
            $env:PATH += ";$PathToAdd"
        }
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updatedPath0' -Args @($PathToAdd))
    }
}


function Repair-SystemClock {
    <#
    .SYNOPSIS
    Resynchronizes the system clock only when the time service cannot.
    #>
    $changed = $false
    try {
        # Decided WITHOUT parsing w32tm output: that output is localized, so the
        # previous 'Last Successful Sync Time' match never hit on a non-English
        # install and the clock was resynced on every single run.
        $service = Get-Service w32time -ErrorAction SilentlyContinue
        if (-not $service) {
            return New-StepResult -Success $false -Message 'The w32time service is not present on this system.'
        }
        if ($service.Status -eq 'Running') {
            return New-StepResult -Success $true -Message 'System clock already synchronized.'
        }

        Start-Service w32time -ErrorAction Stop | Out-Null
        w32tm /resync /force 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "w32tm resync failed with exit code $LASTEXITCODE." }
        $changed = $true
        Write-StyledMessage -Type Success -Text ("🕒 " + (Get-SourceTextLoc 'uiText.systemClockResynced'))
        return New-StepResult -Success $true -Changed $changed -Message 'System clock synchronized.'
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "System clock resync failed: $($_.Exception.Message)"
        return New-StepResult -Success $false -Changed $changed -Message $_.Exception.Message
    }
}


function Reset-SchannelSettings {
    <#
    .SYNOPSIS
    Re-enables TLS 1.2 for client and server, reporting every real change.

    .DESCRIPTION
    Ciphers are deliberately left untouched: see the note on the cipher block.
    #>
    param()

    $changed = $false
    try {
        $schannelPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL'
        if (-not (Test-Path $schannelPath)) { return New-StepResult -Success $true -Message 'SCHANNEL key not present.' }

        $tls12Path = Join-Path $schannelPath 'Protocols\TLS 1.2'
        if (Test-Path $tls12Path) {
            foreach ($mode in @('Client', 'Server')) {
                $modePath = Join-Path $tls12Path $mode
                if (Test-Path $modePath) {
                    $enabled = (Get-ItemProperty -Path $modePath -Name 'Enabled' -ErrorAction SilentlyContinue).Enabled
                    if ($enabled -eq 0) {
                        Set-ItemProperty -Path $modePath -Name 'Enabled' -Value 1 -Type DWord -Force
                        $changed = $true
                        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.schannelTls12ModeReactivated0' -Args @($mode))
                        Write-ToolkitLog -Level 'INFO' -Message "Re-enabled TLS 1.2 $mode"
                    }
                }
            }
        }

        # Ciphers are intentionally NOT touched. The previous code deleted the
        # "Enabled = 0" value from every cipher subkey, which re-enabled RC4,
        # 3DES and NULL: ciphers the administrator had disabled on purpose. That
        # is a security regression, not a repair.
        $message = if ($changed) { 'SCHANNEL settings repaired.' } else { 'SCHANNEL settings already valid.' }
        return New-StepResult -Success $true -Changed $changed -Message $message
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "SCHANNEL reset failed: $($_.Exception.Message)"
        return New-StepResult -Success $false -Changed $changed -Message $_.Exception.Message
    }
}


function Reset-HostsFile {
    <#
    .SYNOPSIS
    Removes Microsoft/Store/WinGet overrides from the hosts file, after a backup.

    .DESCRIPTION
    The filtered lines are written back AS THEY ARE. The previous version prepended
    a hardcoded Microsoft copyright header to lines that already contained it (they
    came from the file itself), so every run appended another copy of the header.
    #>
    param()

    try {
        $hostsPath = $script:AppConfig.HostsFilePath
        if (-not (Test-Path $hostsPath)) { return New-StepResult -Success $true -Message 'Hosts file not present.' }

        $lines = Get-Content $hostsPath -ErrorAction SilentlyContinue
        if (-not $lines) { return New-StepResult -Success $true -Message 'Hosts file is empty.' }

        # Drop only the entries that break WinGet and the Store; keep the rest.
        $blockedPattern = '(?i)microsoft\.com|storeedgefd|winget\.azureedge\.net'
        $keptLines = @($lines | Where-Object { $_ -notmatch $blockedPattern })
        $hasOverrides = $keptLines.Count -ne $lines.Count

        if (-not $hasOverrides) {
            return New-StepResult -Success $true -Message 'No blocked hosts overrides found.'
        }

        $backupDir = Initialize-Directory -Path $script:AppConfig.Paths.WinToolkitDir
        $backupPath = Join-Path $backupDir ("hosts.backup.{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Copy-Item -LiteralPath $hostsPath -Destination $backupPath -Force -ErrorAction Stop
        Set-Content -Path $hostsPath -Value $keptLines -Encoding ASCII -Force
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.hostsFileModifiedBackupSaved0' -Args @($backupPath))
        Write-ToolkitLog -Level 'INFO' -Message 'Hosts file reset: removed Microsoft/Store/Winget overrides'
        return New-StepResult -Success $true -Changed $true -Message "Hosts reset; backup: $backupPath"
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Hosts file reset failed: $($_.Exception.Message)"
        return New-StepResult -Success $false -Message $_.Exception.Message
    }
}


function Repair-HostsFileIfNeeded {
    <#
    .SYNOPSIS
    Clears the WinGet/Store hosts overrides only when the package sources fail.

    .DESCRIPTION
    The hosts file was previously rewritten on EVERY run, which discarded the
    privacy blocklist the user had configured (any 0.0.0.0 entry pointing at
    microsoft.com). It is a repair, not a routine cleanup, so it now runs only
    when the WinGet/Store health check actually reports a failure: if the sources
    answer, the user entries stay exactly as they are.
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


# --- Windows Update services: persisted state, suspend and restore ---

function Get-UpdateServicesStatusPath {
    return (Join-Path $script:AppConfig.Paths.WinToolkitDir 'update-services.status.txt')
}


function Write-UpdateServicesStatus {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Status
    )

    $statusPath = Get-UpdateServicesStatusPath
    if (-not (Test-Path -LiteralPath $script:AppConfig.Paths.WinToolkitDir)) {
        $null = New-Item -Path $script:AppConfig.Paths.WinToolkitDir -ItemType Directory -Force -ErrorAction Stop
    }
    $tempPath = "$statusPath.$([guid]::NewGuid()).tmp"
    try {
        $Status.LastUpdatedUtc = [DateTime]::UtcNow.ToString('o')
        $Status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $tempPath -Encoding UTF8 -ErrorAction Stop
        Move-Item -LiteralPath $tempPath -Destination $statusPath -Force -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}


function Read-UpdateServicesStatus {
    $statusPath = Get-UpdateServicesStatusPath
    if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) { return $null }
    try {
        return (Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
    }
    catch {
        Write-ToolkitLog -Level 'ERROR' -Message "Update services status file is unreadable: $($_.Exception.Message)"
        return $null
    }
}


function Initialize-UpdateServicesState {
    $previous = Read-UpdateServicesStatus
    if (-not $previous) { return }

    if ($previous.State -in @('Suspending', 'Suspended', 'RestoreFailed')) {
        $message = "Previous setup did not finish cleanly; saved Windows Update service state found (state: $($previous.State))."
        if ($previous.LastError) { $message += " Previous error: $($previous.LastError)" }
        Write-ToolkitLog -Level 'WARNING' -Message $message
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.previousInterruptionDetectedRestoringUpdateServices')
        Invoke-StartUpdateServices
    }
}


function Set-UpdateServicesState {
    <#
    .SYNOPSIS
    Persists one state transition of the Windows Update service state file.

    .DESCRIPTION
    Every suspend/restore path goes through this helper, so the state, the last
    error and the persisted file can never drift apart.
    #>
    param(
        [Parameter(Mandatory = $true)][object]$Status,
        [Parameter(Mandatory = $true)][string]$State,
        $LastError = $null
    )

    $Status.State = $State
    $Status.LastError = $LastError
    Write-UpdateServicesStatus -Status $Status
}


function Set-UpdateServicesError {
    param([string]$Message)
    $status = Read-UpdateServicesStatus
    if ($status) {
        Set-UpdateServicesState -Status $status -State 'RestoreFailed' -LastError $Message
    }
    Write-ToolkitLog -Level 'ERROR' -Message "Windows Update services recovery: $Message"
}


function Sync-UserScopeWithInstalledTools {
    <#
    .SYNOPSIS
    Aligns the interactive user with the tools that were installed, after an
    elevation that switched account, and returns a StepResult.

    .DESCRIPTION
    WinGet is a PER-USER application: its execution alias and its cache live under
    the LOCALAPPDATA of the account that runs the process. When UAC elevation
    switched to another administrator, every tool was therefore installed into
    THAT account, and the interactive user would not find any of them.

    The chosen policy is hybrid, and deliberately non-blocking in both directions:

      - when it can be done, it is done: the original user's registry hive is
        loaded (it is not loaded when another account is running), the WindowsApps
        directory that received the tools is appended to that user's PATH, and the
        hive is unloaded immediately afterwards;
      - when the hive cannot be loaded, the setup does NOT fail: it falls back to
        an explicit warning naming the account that holds the tools, because a
        blocked PATH write must never abort an otherwise completed installation.

    The PATH is written with Set-ItemProperty -Type ExpandString, never with
    [Environment]::SetEnvironmentVariable: the latter rewrites the user PATH from
    REG_EXPAND_SZ to REG_SZ and would permanently break every other %VAR% in it
    (this is the same defect as B-09).
    #>
    [CmdletBinding()]
    param()

    $context = Get-ToolkitOriginalUserContext
    if (-not $context.AccountSwitched) {
        return New-StepResult -Success $true -Message 'No account switch: the user scope is already correct.'
    }

    $toolsRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if (-not (Test-Path -LiteralPath $toolsRoot -PathType Container)) {
        Write-ToolkitLog -Level 'WARNING' -Message "Tool directory not found, nothing to align: $toolsRoot"
        return New-StepResult -Success $false -Message "No WindowsApps directory to align for '$($context.OriginalUser)'."
    }

    $hiveReg = 'HKU\WinToolkitUserScope'
    $loaded = $false
    try {
        # reg.exe rather than the registry provider: mounting another user's hive
        # is a native operation and this keeps the failure path explicit.
        $null = & reg.exe load $hiveReg (Join-Path $context.UserProfile 'NTUSER.DAT') 2>&1
        $loaded = ($LASTEXITCODE -eq 0)
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Could not load the user hive: $($_.Exception.Message)"
        $loaded = $false
    }

    if (-not $loaded) {
        # Degrade, never block.
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.userScopeNotAligned0' -Args @($context.OriginalUser, $toolsRoot))
        return New-StepResult -Success $false -Message "Tools are in '$($context.CurrentUser)'; the PATH of '$($context.OriginalUser)' could not be updated."
    }

    try {
        $envKey = "Registry::$hiveReg\Environment"
        $current = (Get-ItemProperty -Path $envKey -Name 'Path' -ErrorAction SilentlyContinue).Path
        if ([string]::IsNullOrWhiteSpace($current)) { $current = '' }

        if (($current -split ';') -contains $toolsRoot) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.userScopeAlreadyAligned0' -Args @($context.OriginalUser))
            return New-StepResult -Success $true -Message 'The user PATH already contains the tool directory.'
        }

        $newPath = if ($current.TrimEnd(';')) { $current.TrimEnd(';') + ';' + $toolsRoot } else { $toolsRoot }
        # ExpandString preserves the %VAR% entries already in the user PATH.
        Set-ItemProperty -Path $envKey -Name 'Path' -Value $newPath -Type ExpandString -Force

        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.userScopeAligned0' -Args @($context.OriginalUser, $toolsRoot))
        Write-ToolkitLog -Level 'INFO' -Message "User PATH aligned: added '$toolsRoot' to '$($context.OriginalUser)'."
        return New-StepResult -Success $true -Changed $true -Message "Tool directory added to the PATH of '$($context.OriginalUser)'."
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Could not update the user PATH: $($_.Exception.Message)"
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.userScopeNotAligned0' -Args @($context.OriginalUser, $toolsRoot))
        return New-StepResult -Success $false -Message "Failed to update the PATH of '$($context.OriginalUser)'."
    }
    finally {
        if ($loaded) {
            $null = & reg.exe unload $hiveReg 2>&1
            Write-ToolkitLog -Level 'DEBUG' -Message "Unloaded the temporary user hive ($LASTEXITCODE)."
        }
    }
}


function Invoke-StopUpdateServices {
    <#
    .SYNOPSIS
    Temporarily suspends Windows Update and related services to avoid conflicts with Winget.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess('Windows Update services', 'Suspend services')) { return }

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.temporarilySuspendWindowsUpdateServicesToAvoidConflicts')
    # PowerShell 7 exposes StartType on Get-Service, so the previous per-service
    # Get-CimInstance Win32_Service round trip (and its Auto->Automatic mapping)
    # is not needed: one call returns both the state to restore and its startup type.
    $savedServices = @(
        Get-Service -Name $script:AppConfig.UpdateServices -ErrorAction SilentlyContinue |
            ForEach-Object {
                [pscustomobject]@{
                    Name      = $_.Name
                    Status    = [string]$_.Status
                    StartType = [string]$_.StartType
                }
            }
    )

    $status = @{
        Version    = 1
        State      = 'Suspending'
        LastError  = $null
        Services   = $savedServices
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
    }
    Write-UpdateServicesStatus -Status $status

    try {
        foreach ($saved in $savedServices) {
            if ($saved.Status -ne 'Stopped') {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.serviceStop0' -Args @($saved.Name))
                Stop-Service -Name $saved.Name -Force -ErrorAction Stop
                $current = Get-Service -Name $saved.Name -ErrorAction Stop
                if ($current.Status -ne 'Stopped') { throw "Service $($saved.Name) did not stop." }
            }
        }
        Set-UpdateServicesState -Status $status -State 'Suspended'
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updateServicesSuccessfullySuspended')
    }
    catch {
        Set-UpdateServicesState -Status $status -State 'RestoreFailed' -LastError $_.Exception.Message
        throw
    }
}


function Invoke-StartUpdateServices {
    <#
    .SYNOPSIS
    Restores Windows Update and related services.

    .DESCRIPTION
    The startup type is restored from what Get-Service reported (PS7 exposes
    StartType directly), so the old Auto->Automatic translation table and the
    dosvc special case are gone: dosvc is not suspended any more, and cryptsvc is
    not touched at all, because stopping it breaks AppX signature validation and
    that is precisely what the following winget installs do.
    #>
    param()

    $status = Read-UpdateServicesStatus
    if (-not $status -or $status.State -eq 'Restored') { return $true }

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resettingWindowsUpdateServices')
    $restoreErrors = @()
    foreach ($saved in @($status.Services)) {
        try {
            $service = Get-Service -Name $saved.Name -ErrorAction Stop
            # Unknown/older payloads stored the CIM StartMode name instead.
            $startupType = switch ($saved.StartType) {
                'Auto' { 'Automatic' }
                'Disabled' { 'Disabled' }
                default { $saved.StartType }
            }
            Set-Service -Name $saved.Name -StartupType $startupType -ErrorAction Stop

            if ($saved.Status -eq 'Running' -and $service.Status -ne 'Running') {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingService0' -Args @($saved.Name))
                Start-Service -Name $saved.Name -ErrorAction Stop
            }
            elseif ($saved.Status -eq 'Stopped' -and $service.Status -ne 'Stopped') {
                Stop-Service -Name $saved.Name -Force -ErrorAction Stop
            }
        }
        catch {
            $restoreErrors += "$($saved.Name): $($_.Exception.Message)"
        }
    }

    if ($restoreErrors.Count -gt 0) {
        $dosvcErrors = @($restoreErrors | Where-Object { $_ -match '^dosvc:' })
        $otherErrors = @($restoreErrors | Where-Object { $_ -notmatch '^dosvc:' })

        if ($otherErrors.Count -gt 0) {
            Set-UpdateServicesState -Status $status -State 'RestoreFailed' -LastError ($otherErrors -join '; ')
            Write-ToolkitLog -Level 'ERROR' -Message "Unable to restore Windows Update services: $($status.LastError)"
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.updateServicesRestoreIncomplete0' -Args @($status.LastError))
            return $false
        }

        if ($dosvcErrors.Count -gt 0) {
            # dosvc refuses to start on some Windows builds: a known limitation, not a failure.
            Set-UpdateServicesState -Status $status -State 'Restored'
            # $dosvcErrors is an array: it must be joined INSIDE the subexpression,
            # otherwise the literal "-join" text ends up in the log line.
            $dosvcDetail = $dosvcErrors -join '; '
            Write-ToolkitLog -Level 'WARNING' -Message "Windows Update service dosvc could not be restored (known Windows limitation): $dosvcDetail"
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.dosvcNotRestoredKnownLimitation')
        }
    }

    Set-UpdateServicesState -Status $status -State 'Restored'
    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updateServicesRestored')
    return $true
}

# --- Pre-flight checks removed ---
# The Windows Defender status check and the Windows Update pending-update
# check are no longer performed here. They are now handled upstream in
# start.ps1, which blocks dependency installation and start-core until
# Windows updates are fully completed.
