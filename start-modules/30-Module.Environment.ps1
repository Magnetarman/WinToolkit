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
    $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'

    # Update the current PowerShell session
    $env:Path = $newPath
    # Force process-level refresh for .NET components started later
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
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

        $cipherPath = Join-Path $schannelPath 'Ciphers'
        if (Test-Path $cipherPath) {
            Get-ChildItem $cipherPath -ErrorAction SilentlyContinue |
            Where-Object { $_.PSIsContainer } |
            ForEach-Object {
                $prop = Get-ItemProperty -Path $_.FullName -Name 'Enabled' -ErrorAction SilentlyContinue
                if ($prop -and $prop.Enabled -eq 0) {
                    Remove-ItemProperty -Path $_.FullName -Name 'Enabled' -ErrorAction SilentlyContinue
                    $changed = $true
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.schannelCipherReenabled0' -Args @($_.PSChildName))
                    Write-ToolkitLog -Level 'INFO' -Message "Removed disabled cipher: $($_.PSChildName)"
                }
            }
        }
        return [pscustomobject]@{ Success = $true; Changed = $changed; Message = if ($changed) { 'SCHANNEL settings repaired.' } else { 'SCHANNEL settings already valid.' } }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "SCHANNEL reset failed: $($_.Exception.Message)"
        return [pscustomobject]@{ Success = $false; Changed = $changed; Message = $_.Exception.Message }
    }
}


function Reset-HostsFile {
    <#
    .SYNOPSIS
    Removes Microsoft/Store/WinGet overrides from the hosts file, after a backup.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess('C:\Windows\System32\drivers\etc\hosts', 'Reset hosts file')) { return }

    try {
        $hostsPath = 'C:\Windows\System32\drivers\etc\hosts'
        if (-not (Test-Path $hostsPath)) { return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'Hosts file not present.' } }

        $lines = Get-Content $hostsPath -ErrorAction SilentlyContinue
        if (-not $lines) { return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'Hosts file is empty.' } }

        # Drop only the entries that break WinGet and the Store; keep the rest.
        $blockedPattern = '(?i)microsoft\.com|storeedgefd|winget\.azureedge\.net'
        $newLines = @($lines | Where-Object { $_ -notmatch $blockedPattern })
        $hasOverrides = $newLines.Count -ne $lines.Count

        if ($hasOverrides) {
            $backupDir = Initialize-Directory -Path $script:AppConfig.Paths.WinToolkitDir
            $backupPath = Join-Path $backupDir ("hosts.backup.{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
            Copy-Item -LiteralPath $hostsPath -Destination $backupPath -Force -ErrorAction Stop
            $hostsHeader = @(
                '# Copyright (c) 1993-2009 Microsoft Corp.',
                '# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.',
                '#',
                '# This file contains the mappings of IP addresses to host names. Each',
                '# entry should be kept on an individual line. The IP address should',
                '# be placed in the first column followed by the corresponding host name.',
                '# The IP address and the host name should be separated by at least one',
                '# space.',
                '#',
                '# Additionally, comments (such as these) may be inserted on individual',
                '# lines or following the machine name denoted by a ''#'' symbol.',
                '#',
                '# For example:',
                '#      102.54.94.97     rhino.acme.com          # source server',
                '#       38.25.63.10     x.acme.com              # x client host'
            )
            $finalContent = $hostsHeader + ($newLines | Where-Object { $_.Trim() -ne '' })
            Set-Content -Path $hostsPath -Value $finalContent -Encoding ASCII -Force
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.hostsFileModifiedBackupSaved0' -Args @($backupPath))
            Write-ToolkitLog -Level 'INFO' -Message "Hosts file reset: removed Microsoft/Store/Winget overrides"
            return [pscustomobject]@{ Success = $true; Changed = $true; Message = "Hosts reset; backup: $backupPath" }
        }
        return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'No blocked hosts overrides found.' }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Hosts file reset failed: $($_.Exception.Message)"
        return [pscustomobject]@{ Success = $false; Changed = $false; Message = $_.Exception.Message }
    }
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


function Invoke-StopUpdateServices {
    <#
    .SYNOPSIS
    Temporarily suspends Windows Update and related services to avoid conflicts with Winget.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess('Windows Update services', 'Suspend services')) { return }

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.temporarilySuspendWindowsUpdateServicesToAvoidConflicts')
    $savedServices = @()
    foreach ($svc in $script:AppConfig.UpdateServices) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            $cimService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$svc'" -ErrorAction Stop
            $savedServices += [pscustomobject]@{
                Name      = $svc
                Present   = $true
                Status    = [string]$service.Status
                StartType = [string]$cimService.StartMode
            }
        }
    }

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
        $script:UpdateServicesSuspended = $true
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
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess('Windows Update services', 'Restore services')) { return }

    $status = Read-UpdateServicesStatus
    if (-not $status -or $status.State -eq 'Restored') { return $true }

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resettingWindowsUpdateServices')
    $restoreErrors = @()
    foreach ($saved in @($status.Services)) {
        try {
            $service = Get-Service -Name $saved.Name -ErrorAction Stop
            $startupType = switch ($saved.StartType) {
                'Auto' { 'Automatic' }
                'Disabled' { 'Disabled' }
                default { 'Manual' }
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
    $script:UpdateServicesSuspended = $false
    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updateServicesRestored')
    return $true
}

# --- Pre-flight checks removed ---
# The Windows Defender status check and the Windows Update pending-update
# check are no longer performed here. They are now handled upstream in
# start.ps1, which blocks dependency installation and start-core until
# Windows updates are fully completed.
