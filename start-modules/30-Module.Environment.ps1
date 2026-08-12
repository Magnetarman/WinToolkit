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

    $pathExists = $false

    if ($Scope -eq 'User' -or $Scope -eq 'Both') {
        $userEnvPath = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::User)
        if (($userEnvPath -split ';').Contains($PathToCheck)) {
            $pathExists = $true
        }
    }
    if ($Scope -eq 'System' -or $Scope -eq 'Both') {
        $systemEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)
        if (($systemEnvPath -split ';').Contains($PathToCheck)) {
            $pathExists = $true
        }
    }
    return $pathExists
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

    # Check if path already exists
    if (-not (Test-PathInEnvironment -PathToCheck $PathToAdd -Scope $Scope)) {
        if ($Scope -eq 'System') {
            $systemEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)
            $systemEnvPath += ";$PathToAdd"
            [System.Environment]::SetEnvironmentVariable('PATH', $systemEnvPath, [System.EnvironmentVariableTarget]::Machine)
        }
        elseif ($Scope -eq 'User') {
            $userEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::User)
            $userEnvPath += ";$PathToAdd"
            [System.Environment]::SetEnvironmentVariable('PATH', $userEnvPath, [System.EnvironmentVariableTarget]::User)
        }

        # Update current process
        if (-not ($env:PATH -split ';').Contains($PathToAdd)) {
            $env:PATH += ";$PathToAdd"
        }
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updatedPath0' -Args @($PathToAdd))
    }
}

function Repair-SystemClock {
    <#
    .SYNOPSIS
    Resynchronizes the system clock only when it is actually out of sync.
    #>
    $changed = $false
    try {
        $status = (w32tm /query /status 2>$null | Out-String)
        $needsRepair = ($LASTEXITCODE -ne 0 -or $status -notmatch 'Last Successful Sync Time')
        if (-not $needsRepair) {
            return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'System clock already synchronized.' }
        }
        $w32Time = Get-Service w32time -ErrorAction SilentlyContinue
        if ($w32Time -and $w32Time.Status -ne 'Running') {
            Start-Service w32time -ErrorAction Stop | Out-Null
            $changed = $true
        }
        w32tm /resync /force 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "w32tm resync failed with exit code $LASTEXITCODE." }
        $changed = $true
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.systemClockResynced')
        return [pscustomobject]@{ Success = $true; Changed = $changed; Message = 'System clock synchronized.' }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "System clock resync failed: $($_.Exception.Message)"
        return [pscustomobject]@{ Success = $false; Changed = $changed; Message = $_.Exception.Message }
    }
}

function Reset-SchannelSettings {
    <#
    .SYNOPSIS
    Re-enables TLS 1.2 and disabled SCHANNEL ciphers, reporting every real change.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess('SCHANNEL registry keys', 'Reset TLS/cipher settings')) { return }

    $changed = $false
    try {
        $schannelPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL'
        if (-not (Test-Path $schannelPath)) { return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'SCHANNEL key not present.' } }

        $tls12Path = Join-Path $schannelPath 'Protocols\TLS 1.2'
        if (Test-Path $tls12Path) {
            foreach ($mode in @('Client', 'Server')) {
                $modePath = Join-Path $tls12Path $mode
                if (Test-Path $modePath) {
                    $enabled = (Get-ItemProperty -Path $modePath -Name 'Enabled' -ErrorAction SilentlyContinue).Enabled
                    if ($enabled -eq 0) {
                        Set-ItemProperty -Path $modePath -Name 'Enabled' -Value 1 -Type DWord -Force
                        $changed = $true
                        Write-StyledMessage -Type Info -Text "SCHANNEL TLS 1.2 $mode riattivato."
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
                    Write-StyledMessage -Type Info -Text "SCHANNEL cipher $($_.PSChildName) riabilitato."
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

        $hasOverrides = $false
        $newLines = @()
        foreach ($line in $lines) {
            if ($line -match '(?i)microsoft\.com|storeedgefd|winget\.azureedge\.net') {
                $hasOverrides = $true
                continue
            }
            $newLines += $line
        }

        if ($hasOverrides) {
            $backupDir = $script:AppConfig.Paths.WinToolkitDir
            if (-not (Test-Path $backupDir)) { $null = New-Item -Path $backupDir -ItemType Directory -Force -ErrorAction Stop }
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
            Write-StyledMessage -Type Info -Text "File hosts modificato; backup salvato in $backupPath."
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
        Write-StyledMessage -Type Warning -Text 'Rilevata una precedente interruzione: ripristino dello stato dei servizi Windows Update.'
        Invoke-StartUpdateServices
    }
}

function Set-UpdateServicesError {
    param([string]$Message)
    $status = Read-UpdateServicesStatus
    if ($status) {
        $status.State = 'RestoreFailed'
        $status.LastError = $Message
        Write-UpdateServicesStatus -Status $status
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
        $status.State = 'Suspended'
        Write-UpdateServicesStatus -Status $status
        $script:UpdateServicesSuspended = $true
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updateServicesSuccessfullySuspended')
    }
    catch {
        $status.State = 'RestoreFailed'
        $status.LastError = $_.Exception.Message
        Write-UpdateServicesStatus -Status $status
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
            $status.State = 'RestoreFailed'
            $status.LastError = $otherErrors -join '; '
            Write-UpdateServicesStatus -Status $status
            Write-ToolkitLog -Level 'ERROR' -Message "Unable to restore Windows Update services: $($status.LastError)"
            Write-StyledMessage -Type Error -Text "Ripristino servizi Windows Update incompleto: $($status.LastError)"
            return $false
        }

        if ($dosvcErrors.Count -gt 0) {
            $status.State = 'Restored'
            $status.LastError = $null
            Write-UpdateServicesStatus -Status $status
            Write-ToolkitLog -Level 'WARNING' -Message "Windows Update service dosvc could not be restored (known Windows limitation): $($dosvcErrors -join '; ')"
            Write-StyledMessage -Type Warning -Text "Servizio Windows Update dosvc (Ottimizzazione recapito) non è stato ripristinato: limite noto di Windows. Il setup prosegue."
        }
    }

    $status.State = 'Restored'
    Write-UpdateServicesStatus -Status $status
    $script:UpdateServicesSuspended = $false
    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updateServicesRestored')
    return $true
}

# --- Pre-flight checks removed ---
# The Windows Defender status check and the Windows Update pending-update
# check are no longer performed here. They are now handled upstream in
# start.ps1, which blocks dependency installation and start-core until
# Windows updates are fully completed.

