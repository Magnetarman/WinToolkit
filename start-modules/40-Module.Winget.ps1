# ============================================================================
# WINGET AND APPX
# ============================================================================

function Get-WinGetExecutable {
    <#
    .SYNOPSIS
    Returns the path of a usable winget.exe, or $null when WinGet is missing.

    .DESCRIPTION
    Only stable locations are considered: the per-user execution alias and the
    command resolver. Versioned WindowsApps paths are never used, because they
    change on every App Installer update.
    #>
    # Single place that knows the stable per-user execution alias.
    $aliasPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    if (Test-Path $aliasPath) {
        return $aliasPath
    }

    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source -and (Test-Path -LiteralPath $command.Source)) {
        return $command.Source
    }

    return $null
}


function Register-WingetAppExecutionAlias {
    <#
    .SYNOPSIS
    Registers the stable App Installer execution alias without using a versioned path.
    #>
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop
        Write-ToolkitLog -Level 'INFO' -Message 'App Installer execution alias registered by family name.'
        return $true
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Unable to register App Installer execution alias: $($_.Exception.Message)"
        return $false
    }
}


function Start-AppxSilentProcess {
    <#
    .SYNOPSIS
        Installs an AppX/MSIX package through a hidden PowerShell child process.

    .DESCRIPTION
        Add-AppxPackage writes a native "Deployment operation progress" activity to
        the host console, so the install runs in a child process to keep the toolkit
        output clean. The child falls back to Add-AppxProvisionedPackage for the
        error codes that require provisioning.

        The bundle signature is checked by the caller through
        -ContentValidator. It is a WARNING here, not a block: Add-AppxPackage
        validates the package signature itself and fails safely, so the OS remains
        the authority on that decision.
    #>
    param(
        [string]$AppxPath,
        [string]$Flags = '-ForceApplicationShutdown',
        [string[]]$DependencyPaths = @(),
        [string]$ExpectedPackageName,
        [int]$TimeoutSeconds = 120
    )

    $dependencyPathString = ""
    $dependencyPackagePathString = ""
    if ($DependencyPaths.Count -gt 0) {
        $quotedDependencies = (($DependencyPaths | ForEach-Object { "'$($_ -replace "'", "''")'" }) -join ", ")
        # Add-AppxPackage uses -DependencyPath; Add-AppxProvisionedPackage uses
        # -DependencyPackagePath. They are not interchangeable.
        $dependencyPathString = "-DependencyPath $quotedDependencies"
        $dependencyPackagePathString = "-DependencyPackagePath $quotedDependencies"
    }

    # The child reports failures on stderr, which the parent already drains: no
    # temporary file, no cleanup branch, and the error text cannot be lost when
    # the process is killed.
    $cmd = @"
`$ProgressPreference = 'SilentlyContinue';
`$ErrorActionPreference = 'SilentlyContinue';
try {
    Add-AppxPackage -Path '$($AppxPath -replace "'", "''")' $dependencyPathString $Flags -ErrorAction Stop | Out-Null
}
catch {
    if (`$_.Exception.Message -match '0x80073D06') {
        exit 0
    }
    if (`$_.Exception.Message -match '0x80073CF9' -or ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)) {
        try {
            Add-AppxProvisionedPackage -Online -PackagePath '$($AppxPath -replace "'", "''")' $dependencyPackagePathString -SkipLicense -ErrorAction Stop | Out-Null
            exit 0
        }
        catch {
            [Console]::Error.WriteLine(`$_.Exception.Message); exit 1
        }
    }
    [Console]::Error.WriteLine(`$_.Exception.Message); exit 1
}
exit 0
"@
    $encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))

    # Invoke-ExternalCommand owns the process plumbing (detached console, drained
    # streams, timeout and process-tree kill), so AppX installs get the same
    # timeout handling as every other installer.
    $result = Invoke-ExternalCommand -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-NonInteractive', '-EncodedCommand', $encodedCmd) -TimeoutSeconds $TimeoutSeconds

    if ($result.TimedOut) {
        Write-ToolkitLog -Level 'ERROR' -Message "AppX installation timeout after $TimeoutSeconds seconds: $AppxPath"
        return $false
    }

    if ($result.ExitCode -ne 0) {
        Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.appxInstallFailed01' -Args @($AppxPath, $result.StdErr.Trim()))
        return $false
    }

    if ($ExpectedPackageName -and
        -not (Get-AppxPackage -Name $ExpectedPackageName -ErrorAction SilentlyContinue)) {
        Write-ToolkitLog -Level 'ERROR' -Message "AppX command succeeded but package verification failed: $ExpectedPackageName"
        return $false
    }
    return $true
}


function Reset-AppxPackageSilently {
    <#
    .SYNOPSIS
        Resets an AppX package without leaking the native "Deployment operation
        progress" activity to the host console. Add-AppxPackage/Reset-AppxPackage
        write that activity even when stderr is suppressed, which causes a stuck
        progress line to bleed into the main output.
    #>
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$Package
    )
    process {
        $previousProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            $Package | Reset-AppxPackage -ErrorAction SilentlyContinue 2>$null | Out-Null
        }
        finally {
            $ProgressPreference = $previousProgress
        }
    }
}


function Reset-AppInstallerPackage {
    <#
    .SYNOPSIS
    Resets the App Installer package that provides WinGet, when it is installed.
    #>
    Write-ToolkitLog -Level 'INFO' -Message 'Resetting Microsoft.DesktopAppInstaller package.'
    Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue | Reset-AppxPackageSilently
}


function Test-WingetRpcFailure {
    <#
    .SYNOPSIS
    Returns $true when a WinGet result is the App Installer RPC failure.

    .DESCRIPTION
    0x800706BA (RPC_S_SERVER_UNAVAILABLE, surfaced as -2147012859) is what winget
    returns when the per-user App Installer deployment server cannot serve the
    session. Every install then fails identically while "winget --version" and
    "winget search" keep working, which is why the old flow reported the tools as
    handled. The exit code is conclusive on its own, so no output parsing is
    involved: the previous text match could never change the answer.
    #>
    param(
        [Parameter(Mandatory = $true)][object]$Result
    )

    return ($Result.ExitCode -eq $script:AppConfig.Winget.RpcFailureExitCode)
}


function Test-WingetModernVersion {
    <#
    .SYNOPSIS
    Returns $true when the WinGet build accepts --disable-interactivity (1.4+).

    .DESCRIPTION
    The previous check was the regex 'v1\.[4-9]', which does not match 1.10, 1.11
    or 1.12: on every current build the flag was therefore never added and winget
    could block on an interactive prompt. The version is parsed as [version] and
    compared numerically, and the result is cached because probing spawns a
    process (see Get-WingetModernFlag).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$VersionOutput
    )

    if ($VersionOutput -match '(\d+)\.(\d+)') {
        try {
            return ([version]("$($Matches[1]).$($Matches[2])") -ge [version]'1.4')
        }
        catch {
            Write-ToolkitLog -Level 'DEBUG' -Message "Unparsable WinGet version '$VersionOutput': $($_.Exception.Message)"
        }
    }
    # Unknown build: assume modern, since --disable-interactivity is only rejected
    # by the very old builds that predate the 1.4 milestone.
    return $true
}


function Get-WingetModernFlag {
    <#
    .SYNOPSIS
    Returns '--disable-interactivity' when the installed WinGet supports it.

    .DESCRIPTION
    The probe cost one extra winget process per command, so the answer is cached
    on the executable path it was measured for. Invalidate-WingetVersionCache drops
    it whenever PATH or the App Installer package may have changed.
    #>
    [CmdletBinding()]
    param([string]$WingetExe)

    if (-not $WingetExe) { return $null }
    if ($script:State.Winget.Modern -and $script:State.Winget.ProbedExe -eq $WingetExe) {
        if ($script:State.Winget.Modern) { return '--disable-interactivity' }
        return $null
    }

    $result = Invoke-ExternalCommand -FilePath $WingetExe -ArgumentList @('--version') `
        -TimeoutSeconds $script:AppConfig.Timeouts.WingetProbe
    $modern = $false
    if ($result.ExitCode -eq 0) {
        $modern = Test-WingetModernVersion -VersionOutput "$($result.StdOut)$($result.StdErr)"
    }
    else {
        Write-ToolkitLog -Level 'DEBUG' -Message "WinGet --version probe failed with exit code $($result.ExitCode); assuming a modern build."
        $modern = $true
    }

    $script:State.Winget.ProbedExe = $WingetExe
    $script:State.Winget.Modern = $modern
    return $(if ($modern) { '--disable-interactivity' } else { $null })
}


function Invalidate-WingetVersionCache {
    <#
    .SYNOPSIS
    Drops the cached WinGet version probe after PATH or App Installer changes.
    #>
    $script:State.Winget.Modern = $null
    $script:State.Winget.ProbedExe = $null
}


function Invoke-WingetRpcRecovery {
    <#
    .SYNOPSIS
    One recovery attempt for the App Installer RPC failure, used before retrying.
    #>
    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetRpcFailureDetected')
    Invoke-ForceCloseWinget
    $null = Register-WingetAppExecutionAlias
    $null = Reset-AppInstallerPackage
    Update-EnvironmentPath
    Start-Sleep -Seconds 2

    $probe = Invoke-WingetCommand -Arguments '--version'
    if (Test-WingetRpcFailure -Result $probe) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetRpcRecoveryFailed')
        return $false
    }
    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetRpcRecovered')
    return $true
}


function Invoke-WingetCommand {
    <#
    .SYNOPSIS
    Runs one WinGet command line and returns a structured result.

    .DESCRIPTION
    Single entry point for WinGet invocations: it resolves winget.exe once and
    appends --disable-interactivity only on the versions that support it (1.4+),
    so one call site works on every WinGet build. The version probe is cached
    instead of spawning `winget --version` before every single command.
    Failure paths return the same shape as success paths, with ExitCode -1.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Arguments,
        [int]$TimeoutSeconds = 120
    )

    try {
        $wingetExe = Get-WinGetExecutable
        if (-not $wingetExe) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInSystem')
            return New-ExternalCommandResult -ExitCode -1 -FilePath 'winget.exe' -ArgumentList @($Arguments) -Error 'WinGet executable not found.'
        }

        # --disable-interactivity is accepted from WinGet 1.4 onwards.
        $modernFlag = Get-WingetModernFlag -WingetExe $wingetExe
        $finalArgs = if ($modernFlag) { "$Arguments $modernFlag" } else { $Arguments }

        $result = Invoke-ExternalCommand -FilePath $wingetExe -ArgumentList (ConvertTo-ProcessArgumentList -Arguments $finalArgs) -TimeoutSeconds $TimeoutSeconds
        if ($result.TimedOut) {
            Write-ToolkitLog -Level 'ERROR' -Message "Winget timeout after $TimeoutSeconds seconds: $Arguments"
        }
        elseif (Test-WingetRpcFailure -Result $result) {
            # Name the failure: a generic non-zero exit code here is what let four
            # failed tool installs look like a normal "already installed" run.
            Write-ToolkitLog -Level 'ERROR' -Message "Winget failed with 0x800706BA (App Installer deployment server unavailable) running: $Arguments"
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.wingetRpcFailureDetected')
        }
        return $result
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetCommandError0' -Args @($_.Exception.Message))
        return New-ExternalCommandResult -ExitCode -1 -FilePath 'winget.exe' -ArgumentList @($Arguments) -Error $_.Exception.Message
    }
}


function Invoke-WingetInstall {
    <#
    .SYNOPSIS
    Installs one package through WinGet and returns a structured result.

    .DESCRIPTION
    Single entry point for package installs, which removes the standard flag
    string that was repeated at seven call sites. It also fixes the exit-code
    contract: `winget install` on an already installed package returns
    0x8A150061 (no applicable update is 0x8A15002B), so a rerun used to report
    Failed and to make the font step return Success=$false. The caller must test
    .Accepted, never `-eq 0`.

    The App Installer RPC failure (0x800706BA) is recovered from once, with a
    single retry, because it is the only non-idempotent error worth retrying here.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [switch]$Exact,
        [switch]$Upgrade,
        [string]$Source = 'winget'
    )

    if (-not (Get-WinGetExecutable)) {
        return New-ExternalCommandResult -ExitCode -1 -FilePath 'winget.exe' -ArgumentList @($Id) -Error 'WinGet executable not found.'
    }

    $acceptedExitCodes = @(0) + $script:AppConfig.Winget.AlreadyInstalledExitCodes
    $operation = if ($Upgrade) { 'upgrade' } else { 'install' }
    $exactFlag = if ($Exact) { '-e ' } else { '' }
    $command = "$operation $exactFlag--id $Id --source $Source --accept-source-agreements --accept-package-agreements --silent"

    $result = Invoke-WingetCommand -Arguments $command
    $result | Add-Member -NotePropertyName 'Accepted' -NotePropertyValue (
        (-not $result.TimedOut) -and $acceptedExitCodes -contains $result.ExitCode
    ) -Force

    if ((-not $result.Accepted) -and (Test-WingetRpcFailure -Result $result)) {
        if (Invoke-WingetRpcRecovery) {
            $result = Invoke-WingetCommand -Arguments $command
            $result | Add-Member -NotePropertyName 'Accepted' -NotePropertyValue (
                (-not $result.TimedOut) -and $acceptedExitCodes -contains $result.ExitCode
            ) -Force
        }
    }
    return $result
}


function Reset-WingetSources {
    <#
    .SYNOPSIS
    Resets WinGet sources to force a repository metadata refresh.

    .DESCRIPTION
    Single place that performs the reset: the msstore repair, the database restore
    and the reinstall path all call this one instead of invoking winget directly.
    #>
    $result = Invoke-WingetCommand -Arguments 'source reset --force'
    if ($result.ExitCode -ne 0) {
        Write-ToolkitLog -Level 'WARNING' -Message "Winget source reset failed with exit code $($result.ExitCode)."
    }
}


function Repair-WingetMsStoreSource {
    <#
    .SYNOPSIS
    Detects and fixes the msstore certificate pinning failure (0x8a15005e).

    .DESCRIPTION
    Best effort only: when the msstore source stays unusable the caller keeps
    working with the remaining sources, so every failure here stays a log line.
    #>
    try {
        $wingetExe = Get-WinGetExecutable
        if (-not $wingetExe) { return }

        $result = Invoke-WingetCommand -Arguments 'source update --source msstore --accept-source-agreements'
        $sourceOutput = "$($result.StdOut)$($result.StdErr)"
        if ($result.ExitCode -eq 0 -or $sourceOutput -notmatch '0x8a15005e') { return }

        Write-StyledMessage -Type Warning -Text "Detected msstore certificate pinning failure (0x8a15005e). Resetting WinGet sources to default..."
        Reset-WingetSources
        Update-EnvironmentPath
        Write-StyledMessage -Type Success -Text "WinGet sources reset completed. Using the 'winget' source only."
    }
    catch {
        Write-ToolkitLog -Level 'DEBUG' -Message "msstore source repair skipped: $($_.Exception.Message)"
    }
}


function Repair-AppInstaller {
    <#
    .SYNOPSIS
    Repairs the App Installer package and re-registers its execution alias.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess('Microsoft.DesktopAppInstaller', 'Repair App Installer')) { return }

    $tempFile = $null
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'App Installer already exposes winget.' }
        }

        $changed = $false
        if (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue) {
            Reset-AppInstallerPackage
            $changed = $true
        }

        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            # Reinstall from the official App Installer bundle when the reset did
            # not bring the winget alias back.
            $tempFile = Join-Path $env:TEMP 'WingetInstaller.msixbundle'
            if (-not (Invoke-DownloadFile -Uri $script:AppConfig.URLs.WingetMSIX -OutFile $tempFile `
                        -ContentValidator (New-SignatureValidator -ProfileKey 'wingetMsix'))) {
                throw 'App Installer bundle download failed or its signature is not trusted.'
            }
            if (-not (Start-AppxSilentProcess -AppxPath $tempFile -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.DesktopAppInstaller')) {
                throw 'App Installer package installation failed.'
            }
            $changed = $true
        }

        if (-not (Register-WingetAppExecutionAlias)) { throw 'App Installer execution alias registration failed.' }
        return [pscustomobject]@{ Success = $true; Changed = $changed; Message = 'App Installer repaired and alias registered.' }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "App Installer repair failed: $($_.Exception.Message)"
        return [pscustomobject]@{ Success = $false; Changed = $false; Message = $_.Exception.Message }
    }
    finally {
        if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}


function Test-WingetCompatibility {
    <#
    .SYNOPSIS
    Checks OS compatibility with Winget.
    #>
    $osInfo = [Environment]::OSVersion
    $build = $osInfo.Version.Build

    if ($osInfo.Version.Major -lt 10) {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.wingetNotSupportedOnWindows0' -Args @($osInfo.Version.Major))
        return $false
    }
    # WinGet requires Windows 10 1809 (build 17763) or newer.
    if ($osInfo.Version.Major -eq 10 -and $build -lt 17763) {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.windows10Build0NonSupportaWinget' -Args @($build))
        return $false
    }
    return $true
}


function Get-WingetHealth {
    <#
    .SYNOPSIS
    Probes WinGet once and returns { Present; Runs; Version; Reachable }.

    .DESCRIPTION
    The previous flow had three separate health checks (Test-WingetFunctionality,
    the inline --version probe, Test-WingetDeepValidation) and ran them more than
    once per execution, each spawning its own process. `Runs` is local (it does
    not touch the network) and `Reachable` is the remote `search`, so the two
    failure modes stay distinguishable while the cost is paid once.
    #>
    Update-EnvironmentPath

    $health = [pscustomobject]@{
        Present   = [bool](Get-WinGetExecutable)
        Runs      = $false
        Version   = $null
        Reachable = $false
    }
    if (-not $health.Present) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInPath')
        return $health
    }

    $version = Invoke-WingetCommand -Arguments '--version'
    if (($version.ExitCode -eq 0) -and ("$($version.StdOut)$($version.StdErr)" -match 'v(\d+\.\d+)')) {
        $health.Runs = $true
        $health.Version = $Matches[1]
    }
    else {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetPresentButNotRespondingCorrectlyExitcode0' -Args @($version.ExitCode))
        return $health
    }

    $search = Invoke-WingetCommand -Arguments 'search --id Microsoft.PowerShell --source winget' -TimeoutSeconds $script:AppConfig.Timeouts.Winget
    $health.Reachable = ($search.ExitCode -eq 0)
    if (-not $health.Reachable) {
        Write-ToolkitLog -Level 'WARNING' -Message "WinGet sources not reachable (search exit code $($search.ExitCode))."
    }
    return $health
}


function Test-WingetAppInstaller {
    <#
    .SYNOPSIS
    Ensures App Installer is present and up to date.

    .DESCRIPTION
    After Winget is confirmed functional, the Microsoft.DesktopAppInstaller package
    must be present (and current) so that Winget stays fully functional and on
    the latest release/support. When the package is missing it is installed,
    and when already present it is force-updated to the latest release.
    #>
    $wingetExe = Get-WinGetExecutable
    if (-not $wingetExe) {
        return $false
    }

    Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.checkingMicrosoftAppInstallerPackage'))

    # AppX uses the Windows package name; WinGet uses the Microsoft.AppInstaller catalog ID.
    $present = [bool](Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue)

    try {
        # Microsoft.AppInstaller is the WinGet catalog ID; the AppX package is
        # Microsoft.DesktopAppInstaller (checked above with Get-AppxPackage).
        if (-not $present) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerNotFoundInstalling')
            $null = Invoke-WingetCommand -Arguments 'install --id Microsoft.AppInstaller --source winget --accept-package-agreements --accept-source-agreements --force'
        }
        else {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerPresentForcingUpdate')
            $null = Invoke-WingetCommand -Arguments 'upgrade --id Microsoft.AppInstaller --source winget --accept-package-agreements --accept-source-agreements --force'
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerUpdateError0' -Args @($_.Exception.Message))
    }

    $ok = [bool](Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue)
    if ($ok) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerUpdated')
    }
    else {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerInstallationFailed')
    }
    return $ok
}


function Invoke-ForceCloseWinget {
    <#
    .SYNOPSIS
    Closes the processes that block an AppX install, and nothing else.

    .DESCRIPTION
    Only the names listed in AppConfig.WingetProcesses are targeted, so
    system-critical processes are never touched and the running toolkit process
    is always spared.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.closingInterferingProcesses')

    foreach ($procName in $script:AppConfig.WingetProcesses) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -ne $PID } |  # Never kill the toolkit itself.
        Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep 2
    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.interferingProcessesClosed')
}


function Set-WingetPathPermissions {
    <#
    .SYNOPSIS
    Registers the App Installer execution alias and refreshes the session PATH.

    .DESCRIPTION
    The previous version also called Add-ToEnvironmentPath with the literal
    "%LOCALAPPDATA%\Microsoft\WindowsApps". Two problems: the literal was stored
    unexpanded, and [Environment]::SetEnvironmentVariable rewrites the user PATH
    from REG_EXPAND_SZ to REG_SZ, which permanently breaks every other %VAR%
    entry in it. That folder is already part of the default user PATH on a
    current Windows, so the write is not only unnecessary, it is destructive.
    #>

    $aliasRegistered = Register-WingetAppExecutionAlias
    Update-EnvironmentPath
    Invalidate-WingetVersionCache
    if ($aliasRegistered) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.pathAndWingetPermissionsUpdated')
    }
}


function Invoke-WinGetPackageManagerRepair {
    <#
    .SYNOPSIS
    Runs Repair-WinGetPackageManager (Microsoft.WinGet.Client) when it is available.

    .DESCRIPTION
    WinGet reports 0x80073D06 when a newer App Installer is already present, which
    is a success for a repair attempt rather than a failure. Kept in one place so
    the database restore and the reinstall path report it identically.
    #>
    if (-not (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue)) {
        return $false
    }

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.tentativoRiparazioneWingetRepairWingetpackagemanager')
    try {
        Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
        return $true
    }
    catch {
        if ($_.Exception.Message -match '0x80073D06') {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerIgnoredHigherVersionAlreadyPresent')
            return $true
        }
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerFallito0' -Args @($_.Exception.Message))
        return $false
    }
}


function Repair-WingetDatabase {
    <#
    .SYNOPSIS
    Performs a complete Winget database and configuration restore.
    #>
    Write-StyledMessage -Type Info -Text ("🔧 " + (Get-SourceTextLoc 'uiText.startWingetDatabaseRecovery'))

    try {
        # 1. Stop the processes that lock the package files.
        Invoke-ForceCloseWinget

        # 2. Drop the local WinGet cache, keeping the lock and tmp folders.
        $wingetCachePath = "$env:LOCALAPPDATA\WinGet"
        if (Test-Path $wingetCachePath) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.puliziaCacheWinget')
            Get-ChildItem -Path $wingetCachePath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\lock\\|\\tmp\\' } |
            ForEach-Object {
                try {
                    Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
                }
                catch {
                    Write-ToolkitLog -Level 'WARNING' -Message "Repair-WingetDatabase cache: $($_.Exception.Message)"
                }
            }
        }

        # 3. Remove the corrupted JSON state files.
        $stateFiles = @(
            "$env:LOCALAPPDATA\WinGet\Data\USERTEMPLATE.json",
            "$env:LOCALAPPDATA\WinGet\Data\DEFAULTUSER.json"
        )

        foreach ($file in $stateFiles) {
            if (Test-Path $file -PathType Leaf) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetStatusFile0' -Args @($file))
                Remove-Item $file -Force -ErrorAction SilentlyContinue
            }
        }

        # 4. Reset the sources.
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetWingetSources')
        Reset-WingetSources

        # 5. Reset the App Installer package: the decisive step for the
        #    ACCESS_VIOLATION crash (0xC0000005).
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetPackageMicrosoftDesktopappinstaller')
        if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
            Reset-AppInstallerPackage
        }

        # 6. Re-register the App Installer manifest.
        try {
            $manifest = (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue).InstallLocation
            if ($manifest) {
                $manifestXml = Join-Path $manifest 'AppxManifest.xml'
                if (Test-Path $manifestXml) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.reRegisterManifestAppxmanifestXml')
                    $null = Start-AppxSilentProcess -AppxPath $manifestXml -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown'
                }
            }
        }
        catch {
            Write-ToolkitLog -Level 'WARNING' -Message "Repair-WingetDatabase manifest: $($_.Exception.Message)"
        }

        # 7. Let the WinGet module repair itself, when it is installed.
        $null = Invoke-WinGetPackageManagerRepair

        # 8. Re-apply permissions and refresh PATH.
        Set-WingetPathPermissions
        Update-EnvironmentPath

        # 9. Verify that winget answers again.
        Start-Sleep 2
        $versionResult = Invoke-WingetCommand -Arguments '--version'
        if ($versionResult.ExitCode -ne 0) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.restoreCompletedButWingetMayNotWork')
        }
        else {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetDatabaseRestoredVersion0' -Args @($versionResult.StdOut.Trim()))
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorRestoringDatabase0' -Args @($_.Exception.Message))
        return $false
    }
}


function Test-WingetAccessViolation {
    <#
    .SYNOPSIS
    Returns $true when an exit code is the 0xC0000005 access violation WinGet crash.

    .DESCRIPTION
    Typed as [int] on purpose: Process.ExitCode is an Int32, so the unsigned
    spelling of 0xC0000005 (3221225477) could never be compared and the extra
    check was dead code. The signed value is the only one a real process reports.
    #>
    param([Parameter(Mandatory = $true)][int]$ExitCode)

    return $ExitCode -eq $script:EXITCODE_ACCESS_VIOLATION_SIGNED
}


function Test-WingetDeepValidation {
    <#
    .SYNOPSIS
    Performs an in-depth connectivity and functionality test of Winget.
    #>
    Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.deepTestExecutionOfWingetSearchForPacketsOnTheNetwork'))

    try {
        # One search covers repository connectivity, local database integrity and
        # the WinGet parser, and reports a crash through the exit code. A missing
        # WinGet is reported by Invoke-WingetCommand itself.
        $searchResult = Invoke-WingetCommand -Arguments 'search Git.Git --accept-source-agreements'
        $exitCode = $searchResult.ExitCode

        if (Test-WingetAccessViolation -ExitCode $exitCode) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.crashDetectedExitcode0AccessViolationAdvancedRecoveryAttempt' -Args @($exitCode))

            # Escalating recovery: restore the database first, reinstall WinGet only
            # if the crash survives the restore. The recovery level dispatcher is
            # gone, so the concrete repairs are named directly. The last step is a
            # plain MSIX reinstall (Install-WingetCore), NOT a module install: see
            # the note above Reset-WingetSourcesOnce.
            $recoverySteps = @(
                @{ Repair = { Repair-WingetDatabase }; WarningKey = $null; InfoKey = 'uiText.repeatTestAfterDatabaseRestore' },
                @{ Repair = { Install-WingetCore }; WarningKey = 'uiText.persistentCrashStartingCompleteReinstallationOfWinget'; InfoKey = 'uiText.finalTestAfterReinstallation' }
            )
            foreach ($step in $recoverySteps) {
                if ($step.WarningKey) {
                    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc $step.WarningKey)
                }
                $null = & $step.Repair

                Write-StyledMessage -Type Info -Text ("🔄 " + (Get-SourceTextLoc $step.InfoKey))
                Start-Sleep 3
                $searchResult = Invoke-WingetCommand -Arguments 'search Git.Git --accept-source-agreements'
                $exitCode = $searchResult.ExitCode
                if (-not (Test-WingetAccessViolation -ExitCode $exitCode)) { break }
            }
        }

        if ($exitCode -eq 0) {
            # A successful search is also the moment to refresh the source metadata.
            $sourceUpdate = Invoke-WingetCommand -Arguments 'source update --accept-source-agreements'
            if ($sourceUpdate.ExitCode -ne 0) {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'toolText.sourceUpdateError0' -Args @($sourceUpdate.ExitCode))
            }
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.deepTestPassedWingetCommunicatesCorrectlyWithRepositories')
            return $true
        }

        # Keep only the head of the output: it is the part that names the failure.
        $errorDetails = "$($searchResult.StdOut)$($searchResult.StdErr)"
        if ($errorDetails.Length -gt 200) {
            $errorDetails = $errorDetails.Substring(0, 200) + "."
        }
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.deepTestFailedExitcode0Details1' -Args @($exitCode, $errorDetails))
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorDuringWingetDeepTest0' -Args @($_.Exception.Message))
        return $false
    }
}


function Get-WingetDownloadUrl {
    <#
    .SYNOPSIS
    Resolves the download URL of the newest WinGet CLI asset published on GitHub.
    #>
    param([Parameter(Mandatory = $true)][string]$Match)

    try {
        $latest = Invoke-RestMethod -Uri $script:AppConfig.URLs.WingetCliRelease -UseBasicParsing
        $asset = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
        if ($asset) {
            return $asset.browser_download_url
        }
        throw (Get-SourceTextLoc 'uiText.asset0NotFound' -Args @($Match))
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.assetUrlRetrievalError0' -Args @($_.Exception.Message))
        return $null
    }
}


function Install-WingetCore {
    <#
    .SYNOPSIS
    Performs the minimal Winget installation and core dependencies.
    #>
    Write-StyledMessage -Type Info -Text ("🛠️ " + (Get-SourceTextLoc 'uiText.startingWingetCoreRecoveryProcedure'))

    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    $tempDir = "$env:TEMP\WinToolkitWinget"
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force *>$null
    }

    try {
        # 1. Visual C++ Redistributable: WinGet itself depends on it.
        if (-not (Test-VCRedistInstalled)) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.visualCRedistributableInstallation')
            $vcUrl = $script:AppConfig.URLs.VCRedistTemplate -f (Get-ArchitectureSpecificValue -X64 'x64' -X86 'x86' -ARM64 'arm64')
            $vcFile = Join-Path $tempDir "vc_redist.exe"

            if (-not (Invoke-DownloadFile -Uri $vcUrl -OutFile $vcFile `
                    -ContentValidator (New-SignatureValidator -ProfileKey 'vcRedist' -BlockOnInvalid))) {
                throw 'Visual C++ Redistributable download failed or its signature was not trusted.'
            }
            # 0 = installed, 1638 = a newer version is already present, 3010 = reboot required.
            $vcResult = Invoke-ExternalCommand -FilePath $vcFile -ArgumentList @('/install', '/quiet', '/norestart') -TimeoutSeconds 600 -AcceptedExitCodes @(0, 1638, 3010)
            if ($vcResult.Accepted) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.visualCRedistributableInstalled')
            }
            else {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.installationFailedCode0' -Args @($vcResult.ExitCode))
            }
        }
        else {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.visualCRedistributableAlreadyPresent')
        }

        # 2. Dependencies (UI.Xaml, VCLibs) extracted from the official bundle.
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadWingetDependenciesFromTheOfficialRepository')
        $dependencies = @()
        $depUrl = Get-WingetDownloadUrl -Match 'DesktopAppInstaller_Dependencies.zip'
        if ($depUrl) {
            $depZip = Join-Path $tempDir "dependencies.zip"
            try {
                if (-not (Invoke-DownloadFile -Uri $depUrl -OutFile $depZip -Silent)) {
                    throw 'WinGet dependency bundle download failed.'
                }

                # Architecture-targeted extraction and installation.
                $extractPath = Join-Path $tempDir "deps"
                Expand-Archive -Path $depZip -DestinationPath $extractPath -Force

                $archPattern = Get-ArchitectureSpecificValue -X64 'x64|neutral|ne' -X86 'x86|neutral|ne' -ARM64 'arm64|neutral|ne'
                $appxFiles = Get-ChildItem -Path $extractPath -Recurse -Filter "*.appx" | Where-Object { $_.Name -match $archPattern }

                foreach ($file in $appxFiles) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.dependencyFound0' -Args @($file.Name))
                    $dependencies += $file.FullName
                }
            }
            catch {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.unableToExtractOrInstallDependenciesFromTheOfficialZipError0' -Args @($_.Exception.Message))
            }
        }

        # 3. WinGet bundle, installed with the dependencies extracted above.
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadAndInstallWingetBundleWithDependencies')
        $wingetUrl = Get-WingetDownloadUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        if (-not $wingetUrl) {
            # No bundle URL means nothing was installed: never report success.
            throw (Get-SourceTextLoc 'uiText.wingetCoreInstallationFailed')
        }

        $wingetFile = Join-Path $tempDir "winget.msixbundle"
        if (-not (Invoke-DownloadFile -Uri $wingetUrl -OutFile $wingetFile -Silent `
                    -ContentValidator (New-SignatureValidator -ProfileKey 'wingetMsix'))) {
            throw (Get-SourceTextLoc 'uiText.wingetCoreInstallationFailed')
        }

        if (Start-AppxSilentProcess -AppxPath $wingetFile -DependencyPaths $dependencies -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.DesktopAppInstaller') {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetCoreSuccessfullyInstalled')
        }
        else {
            throw (Get-SourceTextLoc 'uiText.wingetCoreInstallationFailed')
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorRestoringWinget0' -Args @($_.Exception.Message))
        return $false
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        $ProgressPreference = $oldProgress
    }
}


# ==============================================================================
# NOTE ON THE WinGet.Client MODULE
# ------------------------------------------------------------------------------
# The previous last-resort step installed Microsoft.WinGet.Client with
# `Install-Module -Force -AllowClobber`. That permanently rewrites the USER's
# PowerShell environment (module plus NuGet provider), can clobber an existing
# user module, and is not reversible by the toolkit. It has been removed.
#
# The crash-recovery ladder in Test-WingetDeepValidation now ends with
# Install-WingetCore, which reinstalls the signed MSIX bundle and leaves the user
# profile untouched.
#
# If a module install is ever reintroduced, it MUST be behind an explicit user
# confirmation, for the reason above.
# ==============================================================================
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


