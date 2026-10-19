# Coordinate registered-profile and residual-folder cleanup with shared protections and result reporting.
function WinDeleteUserProfiles {
    <#
    .SYNOPSIS
        Safely removes unloaded local user profiles and residual folders from C:\Users.

    .DESCRIPTION
        Performs a controlled cleanup of local profiles in C:\Users using Win32_UserProfile.
        Excludes special and loaded profiles, system accounts, the current user profile, and protected names.
        After deleting registered profiles, checks the users folder and removes residual directories that are no
        longer associated with profiles in the registry or CIM, while preserving all protected exclusions.

        The script does not request interactive confirmation before deletion.

    .PARAMETER MaxThreads
        Maximum number of parallel runspaces. Automatically limited to 4 for Win32_UserProfile.

    .PARAMETER CountdownSeconds
        Number of seconds in the countdown before a recommended restart.

    .PARAMETER SuppressIndividualReboot
        Suppresses the individual restart and delegates the final restart to the toolkit.

    .PARAMETER UsersRoot
        Root path of the local user profiles.

    .PARAMETER MinimumProfileAgeDays
        Minimum profile age in days since its last use. The default value 0 preserves the original behavior.

    .PARAMETER SkipResidualFolderCleanup
        Skips the final cleanup of residual folders in C:\Users.

    .EXAMPLE
        WinDeleteUserProfiles

    .EXAMPLE
        WinDeleteUserProfiles -MinimumProfileAgeDays 30
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(1, 4)]
        [int]$MaxThreads = [Math]::Min(2, [Environment]::ProcessorCount),

        [ValidateRange(0, 3600)]
        [int]$CountdownSeconds = 30,

        [switch]$SuppressIndividualReboot,

        [ValidateNotNullOrEmpty()]
        [string]$UsersRoot = 'C:\Users',

        [ValidateRange(0, 3650)]
        [int]$MinimumProfileAgeDays = 0,

        [switch]$SkipResidualFolderCleanup
    )

    $script:ToolName = 'WinDeleteUserProfiles'
    # Keep a trailing separator so root checks cannot match sibling paths with the same prefix.
    $usersRoot = [System.IO.Path]::GetFullPath($UsersRoot.TrimEnd('\') + '\')
    $currentUser = $env:USERNAME
    $computerName = $env:COMPUTERNAME
    # Resolve the current profile by SID because its folder name can differ from the account name.
    $currentUserSid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    $currentUserProfilePath = (Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { $_.SID -eq $currentUserSid } | Select-Object -First 1 -ExpandProperty LocalPath -ErrorAction SilentlyContinue)
    if ($currentUserProfilePath -and $currentUserProfilePath.StartsWith($usersRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $currentUserFolder = [System.IO.Path]::GetFileName($currentUserProfilePath)
    }
    else {
        $currentUserFolder = $currentUser
    }
    $minimumLastUseDate = if ($MinimumProfileAgeDays -gt 0) { (Get-Date).AddDays(-$MinimumProfileAgeDays) } else { $null }
    $rebootRecommended = $false
    # Cap simultaneous CIM operations and the resources held by the worker batch.
    $maxThreadsEffective = [Math]::Min($MaxThreads, 4)

    # Preserve shared/system folders and both names that can identify the current user's profile.
    $protectedProfileNames = @(
        'Public',
        'Pubblica',
        'Default',
        'Default User',
        'All Users',
        'defaultuser0',
        'WDAGUtilityAccount',
        'Administrator',
        'Guest',
        $currentUser,
        $currentUserFolder
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    # Apply the same case-insensitive name exclusions to registered profiles and residual folders.
    function New-ProtectedNameSet {
        $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $protectedProfileNames | ForEach-Object { [void]$excluded.Add($_) }
        # The unary comma returns the set itself instead of enumerating its entries into the pipeline.
        return , $excluded
    }

    # Remove leftover ProfileList state after the profile directory is gone, reporting registry failure separately.
    function Remove-ProfileRegistryEntries {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Sid,

            [Parameter(Mandatory = $true)]
            [string]$UserName
        )

        # Never construct a destructive registry path from a missing or placeholder SID.
        if ([string]::IsNullOrWhiteSpace($Sid) -or $Sid -eq 'NULL') { 
            return $false
        }

        $profileRegKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $Sid

        # CIM removal can already delete this key; an absent entry counts as successful cleanup.
        if (-not (Test-Path -LiteralPath $profileRegKey)) {
            return $true
        }

        try {
            Remove-Item -LiteralPath $profileRegKey -Recurse -Force -ErrorAction Stop
            Write-ToolkitLog -Level 'SUCCESS' -Message (Get-SourceTextLoc 'toolText.registryEntryRemovedForSid01' -Args @($UserName, $Sid))
            
            return $true
        }
        catch {
            Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.failedToRemoveRegistryEntryForSid01' -Args @($UserName, $($_.Exception.Message)))
            
            return $false
        }
    }

    # Collect normalized registered paths so the residual scan preserves folders still associated with CIM profiles.
    function Get-RegisteredProfilePathSet {
        $pathSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        try {
            $cimProfiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop
        }
        catch {
            Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.cimProfileDetectionFailed0' -Args @($($_.Exception.Message)))
            
            return , $pathSet
        }

        $cimProfiles |
        Where-Object {
            $_.LocalPath -and
            $_.LocalPath.StartsWith($usersRoot, [System.StringComparison]::OrdinalIgnoreCase)
        } |
        ForEach-Object {
            try {
                [void]$pathSet.Add([System.IO.Path]::GetFullPath($_.LocalPath).TrimEnd('\'))
            }
            catch {
                Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.failedToNormalizeRegisteredProfileLocalpath0' -Args @($($_.LocalPath)))
            }
        }

        return , $pathSet
    }

    # Select unloaded, non-special profiles under the configured root before scheduling destructive work.
    function Get-RemovableUserProfiles {
        $excluded = New-ProtectedNameSet

        Write-StyledMessage -Type 'Info' -Text ("🔍 " + (Get-SourceTextLoc 'toolText.scanningRegisteredLocalProfiles'))
        Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.scanningRegisteredLocalProfiles')

        try {
            $profiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop
        }
        catch {
            Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.cimProfileDetectionFailed0' -Args @($($_.Exception.Message)))
            Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.cimProfileDetectionFailed0' -Args @($($_.Exception.Message))))
            return
        }

        # Active sessions and Windows-managed special profiles must keep their profile data.
        $profiles = $profiles | Where-Object {
            -not $_.Special -and
            -not $_.Loaded -and
            $_.LocalPath -and
            $_.LocalPath.StartsWith($usersRoot, [System.StringComparison]::OrdinalIgnoreCase)
        }

        foreach ($profileItem in $profiles) {
            $profileName = [System.IO.Path]::GetFileName($profileItem.LocalPath)

            if ($excluded.Contains($profileName)) {
                Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.excludedProfile01' -Args @($profileName, $($profileItem.LocalPath)))
                continue
            }

            # Protect the current account independently of folder-name exclusions.
            if ($profileItem.SID -eq $currentUserSid) {
                Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.excludedProfileBecauseSidMatchesCurrentUser0' -Args @($profileName, $profileItem.SID))
                continue
            }

            # Apply the optional age cutoff only when Windows provides a last-use timestamp.
            if ($minimumLastUseDate -and $profileItem.LastUseTime) {
                $lastUse = $profileItem.LastUseTime
                if ($lastUse -gt $minimumLastUseDate) {
                    Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.profileExcludedDueToTimeThreshold0LastUse1' -Args @($profileName, $lastUse))
                    continue
                }
            }

            $profileItem
        }
    }

    # Supply worker dependencies explicitly: runspaces do not inherit toolkit functions or language/log context.
    function New-ProfileRemovalSessionState {
        $sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

        foreach ($functionName in @(
                'Get-SourceTextLoc',
                'Write-ToolkitLog',
                'Invoke-ExternalCommandWithLog',
                'Remove-ItemSafely',
                'Remove-ProfileRegistryEntries',
                'Get-SpinnerChar'
            )) {
            $command = Get-Command -Name $functionName -CommandType Function -ErrorAction Stop
            $sessionState.Commands.Add(
                [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($functionName, $command.Definition)
            )
        }

        # Only the parent runspace may update the shared console progress line.
        foreach ($functionName in @('Clear-ProgressLine', 'Write-ProgressUpdate')) {
            $sessionState.Commands.Add(
                [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($functionName, '')
            )
        }

        foreach ($variableName in @(
                'SourceTextLanguageData',
                'SourceTextDefaultLanguageData',
                'SourceTextKeyAliases',
                'CurrentLogFile',
                'CurrentToolName',
                'Spinners'
            )) {
            $value = Get-Variable -Name $variableName -Scope Global -ValueOnly -ErrorAction Stop
            $sessionState.Variables.Add(
                [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new($variableName, $value, '')
            )
        }
        # Shared helpers must leave console rendering to the parent even inside worker sessions.
        $sessionState.Variables.Add(
            [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('GuiSessionActive', $true, '')
        )

        return $sessionState
    }

    # Collect a finished worker's result and release its pipeline before scheduling replacement work.
    function Receive-ProfileRemovalResult {
        param(
            [Parameter(Mandatory = $true)]
            [object]$Job
        )

        try {
            $Job.PowerShell.EndInvoke($Job.Handle)
        }
        catch {
            Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'toolText.runspaceError0' -Args @($($_.Exception.Message)))
            # Preserve identity in a failed result so worker exceptions remain visible in summary counts.
            [PSCustomObject]@{
                Type     = 'Profile'
                UserName = [System.IO.Path]::GetFileName($Job.Profile.LocalPath)
                Path     = $Job.Profile.LocalPath
                Sid      = $Job.Profile.SID
                Success  = $false
                Duration = [TimeSpan]::Zero
            }
        }
        finally {
            # Release command references and pipeline resources as soon as collection finishes.
            $Job.PowerShell.Commands.Clear()
            $Job.PowerShell.Dispose()
        }
    }

    # Clean up workers abandoned by a batch failure while keeping individual cleanup errors non-terminating.
    function Close-ProfileRemovalPowerShell {
        param(
            [Parameter(Mandatory = $true)]
            [object]$PowerShell
        )

        try {
            $PowerShell.Stop()
        }
        # Collection may have disposed the instance before a later batch operation failed.
        catch [System.ObjectDisposedException] {}
        catch {
            # Explicit Continue prevents the caller's warning preference from interrupting cleanup.
            Write-Warning -Message $_.Exception.Message -WarningAction Continue
        }
        finally {
            # Dispose must still run when Stop fails.
            try {
                $PowerShell.Dispose()
            }
            catch {
                Write-Warning -Message $_.Exception.Message -WarningAction Continue
            }
        }
    }

    # Bound the number of live pipelines while returning one result per profile in the original input order.
    function Invoke-ProfileRemovalBatch {
        param(
            [Parameter(Mandatory = $true)]
            [array]$Profiles
        )

        $sessionState = New-ProfileRemovalSessionState
        $pool = [RunspaceFactory]::CreateRunspacePool(1, $maxThreadsEffective, $sessionState, $Host)

        # Retain only outstanding jobs so pipeline memory stays bounded by the concurrency limit.
        $jobs = [System.Collections.Generic.List[object]]::new()
        # Keep ownership of a new instance until startup succeeds and it joins the tracked job list.
        $pendingPowerShell = $null

        $scriptBlock = {
            param($ProfileItem)

            # Terminating errors route failed deletion steps through their fallback cleanup paths.
            $ErrorActionPreference = 'Stop'

            $userPath = $ProfileItem.LocalPath
            $userName = [System.IO.Path]::GetFileName($userPath)
            $userSid = $ProfileItem.SID
            $start = Get-Date

            Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.startResidualFolder01' -Args @($userName, $userPath))

            # Let Windows remove the registered profile first; filesystem cleanup handles any leftovers.
            try {
                Remove-CimInstance -InputObject $ProfileItem -ErrorAction Stop -Confirm:$false
                Write-ToolkitLog -Level 'SUCCESS' -Message (Get-SourceTextLoc 'toolText.cimProfileRemoved0' -Args @($userName))
            }
            catch {
                Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.cimRemoveFailed01' -Args @($userName, $($_.Exception.Message)))
            }

            if ([System.IO.Directory]::Exists($userPath)) {
                try {
                    # An empty source lets /MIR remove leftover contents; /XJ excludes junctions.
                    $tempEmpty = Join-Path $env:TEMP "EmptyFolder"

                    if (-not (Test-Path $tempEmpty)) {
                        New-Item -ItemType Directory -Path $tempEmpty | Out-Null
                    }

                    Invoke-ExternalCommandWithLog -Command 'robocopy.exe' `
                        -Arguments @("`"$tempEmpty`"", "`"$userPath`"", '/MIR', '/XJ', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP') `
                        -LogContextKey "ProfileCleanup-Robocopy-$userName" | Out-Null

                    Remove-Item -LiteralPath $userPath -Recurse -Force -ErrorAction Stop -Confirm:$false

                    Write-ToolkitLog -Level 'SUCCESS' -Message (Get-SourceTextLoc 'toolText.folderRemoved0' -Args @($userName))
                }
                catch {
                    Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.standardFolderCleanupFailed01' -Args @($userName, $($_.Exception.Message)))

                    # Repair ownership and access if permissions prevented standard folder removal.
                    try {
                        Invoke-ExternalCommandWithLog -Command 'takeown.exe' -Arguments @('/F', "`"$userPath`"", '/R', '/D', 'Y') -LogContextKey "ProfileCleanup-TakeOwn-$userName" | Out-Null
                        # S-1-5-32-544 - Fixed SID across Windows languages; avoids depending on localized group names.
                        Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$userPath`"", '/grant', '*S-1-5-32-544:F', '/T', '/C') -LogContextKey "ProfileCleanup-Icacls-$userName" | Out-Null
                        Remove-Item -LiteralPath $userPath -Recurse -Force -ErrorAction Stop -Confirm:$false
                        Write-ToolkitLog -Level 'SUCCESS' -Message (Get-SourceTextLoc 'toolText.folderRemovedAfterAclReset0' -Args @($userName))
                    }
                    catch {
                        Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'toolText.cleanupFailed01' -Args @($userName, $($_.Exception.Message)))
                    }
                }
            }

            # Remove any remaining registry entry only after the directory is gone; require both outcomes for success.
            $folderGone = -not [System.IO.Directory]::Exists($userPath)
            $registrySuccess = $false
            if ($folderGone -and $userSid) {
                $registrySuccess = Remove-ProfileRegistryEntries -Sid $userSid -UserName $userName
            }

            $success = $folderGone -and $registrySuccess
            $duration = New-TimeSpan -Start $start -End (Get-Date)

            if ($success) {
                Write-ToolkitLog -Level 'SUCCESS' -Message (Get-SourceTextLoc 'toolText.completedProfile01' -Args @($userName, $duration.ToString()))
            }
            else {
                Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'toolText.failedProfile0' -Args @($userName))
            }

            return [PSCustomObject]@{
                Type     = 'Profile'
                UserName = $userName
                Path     = $userPath
                Sid      = $userSid
                Success  = $success
                Duration = $duration
            }
        }

        try {
            $pool.Open()
            $total = $Profiles.Count
            # Workers finish out of order, so store each result at its original profile index.
            $results = [object[]]::new($total)
            $nextProfileIndex = 0
            $completed = 0
            $lastPercent = -1

            do {
                # Walk backwards so removing completed jobs cannot shift an unvisited entry.
                for ($jobIndex = $jobs.Count - 1; $jobIndex -ge 0; $jobIndex--) {
                    $job = $jobs[$jobIndex]
                    if (-not $job.Handle.IsCompleted) { continue }

                    $results[$job.Index] = Receive-ProfileRemovalResult -Job $job
                    $jobs.RemoveAt($jobIndex)
                    $completed++
                }

                # Create replacements only after collection frees a slot, bounding queued and running instances.
                while ($nextProfileIndex -lt $total -and $jobs.Count -lt $maxThreadsEffective) {
                    $profileItem = $Profiles[$nextProfileIndex]
                    $ps = [PowerShell]::Create()
                    $pendingPowerShell = $ps
                    $ps.RunspacePool = $pool

                    [void]$ps.AddScript($scriptBlock, $true).
                    AddArgument($profileItem)

                    $handle = $ps.BeginInvoke()

                    $jobs.Add([PSCustomObject]@{
                            PowerShell = $ps
                            Handle     = $handle
                            Profile    = $profileItem
                            Index      = $nextProfileIndex
                        })
                    # Transfer cleanup ownership only after the new job has been registered successfully.
                    $pendingPowerShell = $null
                    $nextProfileIndex++
                }

                $percent = if ($total -gt 0) { [math]::Floor(($completed / $total) * 100) } else { 100 }

                # Update the console only when the whole-number percentage changes.
                if ($percent -ne $lastPercent) {
                    $lastPercent = $percent
                    Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingRegisteredProfiles') -Status (Get-SourceTextLoc 'toolText.extra.01Completed' -Args @($completed, $total)) -Percent $percent -Icon '🗑️'
                }

                if ($jobs.Count -gt 0) {
                    # Wait for any worker or a short timeout instead of continuously polling completion.
                    $waitHandles = [System.Threading.WaitHandle[]]@($jobs | ForEach-Object { $_.Handle.AsyncWaitHandle })
                    [void][System.Threading.WaitHandle]::WaitAny($waitHandles, 500)
                }
            } while ($completed -lt $total)

            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingRegisteredProfiles') -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
            Clear-ProgressLine

            return $results
        }
        finally {
            # Failure paths can bypass collection, leaving pending or tracked instances for this cleanup.
            try {
                if ($pendingPowerShell) {
                    Close-ProfileRemovalPowerShell -PowerShell $pendingPowerShell
                }
                foreach ($job in $jobs) {
                    Close-ProfileRemovalPowerShell -PowerShell $job.PowerShell
                }
                $jobs.Clear()
            }
            finally {
                # Release the pool even after instance cleanup fails, and dispose it even if Close fails.
                if ($pool) {
                    try { $pool.Close() }
                    finally { $pool.Dispose() }
                }
            }
        }
    }

    # Select leftover directories only after protected-name, CIM-path, registered-SID, and link exclusions.
    function Get-ResidualUserFolders {
        $excluded = New-ProtectedNameSet
        # Refresh registration after profile removal so this scan reflects the state Windows now reports.
        $registeredProfilePaths = Get-RegisteredProfilePathSet

        Write-StyledMessage -Type 'Info' -Text ("🔎 " + (Get-SourceTextLoc 'toolText.checkResidualFoldersInTheUsersDirectory'))
        Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.checkResidualFoldersInTheUsersDirectory')

        # Exclude reparse points so residual cleanup does not select links into other locations.
        $folders = Get-ChildItem -Path $usersRoot -Directory -Force |
        Where-Object {
            -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
        }

        # SID-named folders need a registry exclusion in addition to the CIM path exclusion.
        $profileListKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
        $registeredSids = @()
        try {
            $registeredSids = Get-ChildItem -Path $profileListKey -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName }
        }
        catch {
            Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.couldNotEnumerateRegistryProfileList0' -Args @($($_.Exception.Message)))
        }

        foreach ($folder in $folders) {
            $folderName = $folder.Name
            $folderPath = [System.IO.Path]::GetFullPath($folder.FullName).TrimEnd('\')

            if ($excluded.Contains($folderName)) {
                Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.residualFolderExcludedForProtectedName01' -Args @($folderName, $folderPath))
                continue
            }

            if ($registeredProfilePaths.Contains($folderPath)) {
                Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.residualFolderExcludedBecauseItIsStillAssociatedWithWin32Userprofile01' -Args @($folderName, $folderPath))
                continue
            }

            if ($registeredSids -contains $folderName) {
                Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.residualFolderExcludedBecauseSidStillRegistered01' -Args @($folderName, $folderPath))
                continue
            }

            # Keep the link exclusion at candidate selection as well as during initial enumeration.
            if ($folder.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.residualFolderExcludedBecauseReparsePointSymlink01' -Args @($folderName, $folderPath))
                continue
            }

            [PSCustomObject]@{
                Name = $folderName
                Path = $folderPath
            }
        }
    }

    # Remove selected orphan folders separately, recording each outcome and retrying after ACL recovery if needed.
    function Remove-ResidualUserFolders {
        param(
            [Parameter(Mandatory = $true)]
            [array]$Folders
        )

        $results = [System.Collections.Generic.List[object]]::new()
        $total = $Folders.Count
        $index = 0

        foreach ($folder in $Folders) {
            $index++
            $percent = if ($total -gt 0) { [math]::Floor(($index / $total) * 100) } else { 100 }

            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingResidualFoldersInCUsers') -Status ("{0} / {1} - {2}" -f $index, $total, $folder.Name) -Percent $percent -Icon '🗑️'

            $start = Get-Date
            $success = $false

            Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.startResidualFolder01' -Args @($($folder.Name), $($folder.Path)))

            $folderPath = $folder.Path

            try {
                # Literal paths preserve folder names containing wildcard characters during deletion.
                Remove-Item -LiteralPath $folderPath -Force -Recurse -ErrorAction Stop -Confirm:$false
                # A completed command is insufficient; verify that the directory is actually gone.
                $success = -not [System.IO.Directory]::Exists($folderPath)
            }
            catch {
                Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.standardResidualFolderRemovalFailed01' -Args @($folderPath, $($_.Exception.Message)))

                # Retry with ownership and access repaired when normal filesystem deletion fails.
                try {
                    Invoke-ExternalCommandWithLog -Command 'takeown.exe' -Arguments @('/F', "`"$folderPath`"", '/R', '/D', 'Y') -LogContextKey "ResidualTakeOwn-$($folder.Name)" | Out-Null
                    # S-1-5-32-544 - Fixed SID across Windows languages; avoids depending on localized group names.
                    Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$folderPath`"", '/grant', '*S-1-5-32-544:F', '/T', '/C') -LogContextKey "ResidualIcacls-$($folder.Name)" | Out-Null
                    Remove-Item -LiteralPath $folderPath -Recurse -Force -ErrorAction Stop -Confirm:$false
                    $success = -not [System.IO.Directory]::Exists($folderPath)
                }
                catch {
                    Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'toolText.remnantFolderRemovalFailed01' -Args @($folderPath, $($_.Exception.Message)))
                    $success = $false
                }
            }

            $duration = New-TimeSpan -Start $start -End (Get-Date)

            if ($success) {
                Write-ToolkitLog -Level 'SUCCESS' -Message (Get-SourceTextLoc 'toolText.completedResidualFolder01' -Args @($($folder.Name), $duration.ToString()))
            }
            else {
                Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'toolText.failedResidualFolder0' -Args @($($folder.Name)))
            }

            $results.Add([PSCustomObject]@{
                    Type     = 'ResidualFolder'
                    UserName = $folder.Name
                    Path     = $folder.Path
                    Success  = $success
                    Duration = $duration
                }) | Out-Null
        }

        Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingResidualFoldersInCUsers') -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
        Clear-ProgressLine

        return $results
    }

    # Both cleanup phases share the toolkit's progress, localization, and log context.
    Start-ToolkitSession -ToolName $script:ToolName -SubTitle (Get-SourceTextLoc 'script.WinDeleteUserProfiles')

    try {
        # Validate the configured directory before either cleanup phase can delete anything.
        if (-not (Test-Path -LiteralPath $usersRoot -PathType Container)) {
            throw (Get-SourceTextLoc 'toolText.extra.profilePathDoesNotExist0' -Args @($usersRoot))
        }

        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os -and $os.Caption -notmatch 'Windows 11') {
            Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.systemDetected0TheScriptIsDesignedForWindows11' -Args @($($os.Caption))))
        }

        Write-StyledMessage -Type 'Info' -Text ("🖥️ " + (Get-SourceTextLoc 'toolText.computer0' -Args @($computerName)))
        Write-StyledMessage -Type 'Info' -Text ("👤 " + (Get-SourceTextLoc 'toolText.currentUserProtected0' -Args @($currentUser)))
        Write-StyledMessage -Type 'Info' -Text ("📁 " + (Get-SourceTextLoc 'toolText.profilePath0' -Args @($usersRoot)))
        Write-StyledMessage -Type 'Info' -Text ("🧵 " + (Get-SourceTextLoc 'toolText.threadsConfigured0' -Args @($maxThreadsEffective)))
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.nonInteractiveModeNoConfirmationWillBeRequestedBeforeCancellations')

        if ($minimumLastUseDate) {
            Write-StyledMessage -Type 'Info' -Text ("📅 " + (Get-SourceTextLoc 'toolText.lastActivityThresholdProfilesNotUsedForAtLeast0Days' -Args @($MinimumProfileAgeDays)))
        }

        Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.sessionStartedOn0' -Args @($computerName))

        $profileResults = @()
        $residualResults = @()

        $targets = @(Get-RemovableUserProfiles)

        if ($targets -and $targets.Count -gt 0) {
            Write-Host ''
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.registeredProfilesSelectedForAutomaticRemoval')
            Write-Host ''

            $targets |
            Select-Object @{Name = 'User'; Expression = { [System.IO.Path]::GetFileName($_.LocalPath) } },
            @{Name = 'Loaded'; Expression = { $_.Loaded } },
            @{Name = 'LastUseTime'; Expression = { $_.LastUseTime } },
            @{Name = 'Path'; Expression = { $_.LocalPath } } |
            Format-Table -AutoSize

            Write-Host ''
            Write-StyledMessage -Type 'Info' -Text ("🚀 " + (Get-SourceTextLoc 'toolText.startAutomaticRemovalOf0RegisteredProfiles' -Args @($targets.Count)))
            Write-Host ''

            $profileResults = @(Invoke-ProfileRemovalBatch -Profiles $targets)
        }
        else {
            Write-Host ''
            Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.noRemovableRegisteredProfilesFound'))
        }

        # Scan leftovers after registered-profile removal using the updated registration state.
        if (-not $SkipResidualFolderCleanup) {
            $residualFolders = @(Get-ResidualUserFolders)

            if ($residualFolders -and $residualFolders.Count -gt 0) {
                Write-Host ''
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.residualFoldersSelectedForAutomaticRemoval0' -Args @($residualFolders.Count))
                $residualFolders | Select-Object Name, Path | Format-Table -AutoSize

                Write-Host ''
                Write-StyledMessage -Type 'Info' -Text ("🧹 " + (Get-SourceTextLoc 'toolText.startingRemovalOfResidualFolders'))
                Write-Host ''

                $residualResults = @(Remove-ResidualUserFolders -Folders $residualFolders)
            }
            else {
                Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.noRemovableResidualFolderFoundInCUsers'))
            }
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.residualFolderCleanupSkippedForSkipresidualfoldercleanupParameter')
        }

        # Report successes separately for each phase, but base restart advice on failures from either phase.
        $allResults = @($profileResults) + @($residualResults)
        $failedCount = @($allResults | Where-Object { -not $_.Success }).Count
        $profileSuccessCount = @($profileResults | Where-Object { $_.Success }).Count
        $residualSuccessCount = @($residualResults | Where-Object { $_.Success }).Count

        # Open sessions or handles may prevent cleanup; recommend a restart only when items failed.
        if ($failedCount -gt 0) {
            $rebootRecommended = $true
            Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.extra.restartRecommendedAfterProfileCleanup'))
            Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.recommendedReboot0' -Args @((Get-SourceTextLoc 'toolText.0ItemsNotRemovedMayBeBlockedByOpenSessionsOrHandles' -Args @($failedCount))))
        }

        Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.registeredProfilesRemoved0' -Args @($profileSuccessCount)))
        Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.residualFoldersRemoved0' -Args @($residualSuccessCount)))
        if ($failedCount -gt 0) {
            Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.itemsNotRemoved0' -Args @($failedCount)))
        }

        if ($rebootRecommended) {
            # Forward suppression so a toolkit batch can manage its final restart centrally.
            Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.restartRecommendedAfterProfileCleanup') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName $script:ToolName
        # Preserve the original exception so the caller can detect an unsuccessful run.
        throw
    }
    finally {
        # Report that the session ended even when a cleanup phase throws.
        Write-StyledMessage -Type 'Info' -Text ("♻️ " + (Get-SourceTextLoc 'toolText.winDeleteUserProfilesSessionEnded'))
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.winDeleteUserProfilesSessionEnded')
    }
}
