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
    $usersRoot = [System.IO.Path]::GetFullPath($UsersRoot.TrimEnd('\') + '\')
    $currentUser = $env:USERNAME
    $computerName = $env:COMPUTERNAME
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
    $maxThreadsEffective = [Math]::Min($MaxThreads, 4)

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

    function New-ProtectedNameSet {
        $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $protectedProfileNames | ForEach-Object { [void]$excluded.Add($_) }
        return ,$excluded
    }

    function Remove-ProfileRegistryEntries {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Sid,

            [Parameter(Mandatory = $true)]
            [string]$UserName
        )

        if ([string]::IsNullOrWhiteSpace($Sid) -or $Sid -eq 'NULL') { return $false }

        $profileRegKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $Sid

        if (-not (Test-Path -LiteralPath $profileRegKey)) { return $false }

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

    function Get-RegisteredProfilePathSet {
        $pathSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        try {
            $cimProfiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop
        }
        catch {
            Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.cimProfileDetectionFailed0' -Args @($($_.Exception.Message)))
            return ,$pathSet
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

        return ,$pathSet
    }

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

        $profiles = $profiles | Where-Object {
            -not $_.Special -and
            -not $_.Loaded -and
            $_.LocalPath -and
            $_.LocalPath.StartsWith($usersRoot, [System.StringComparison]::OrdinalIgnoreCase)
        }

        foreach ($profile in $profiles) {
            $profileName = [System.IO.Path]::GetFileName($profile.LocalPath)

            if ($excluded.Contains($profileName)) {
                Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.excludedProfile01' -Args @($profileName, $($profile.LocalPath)))
                continue
            }

            if ($profile.SID -eq $currentUserSid) {
                Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.excludedProfileBecauseSidMatchesCurrentUser0' -Args @($profileName, $profile.SID))
                continue
            }

            if ($minimumLastUseDate -and $profile.LastUseTime) {
                $lastUse = $profile.LastUseTime
                if ($lastUse -gt $minimumLastUseDate) {
                    Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.profileExcludedDueToTimeThreshold0LastUse1' -Args @($profileName, $lastUse))
                    continue
                }
            }

            $profile
        }
    }

    function Invoke-ProfileRemovalBatch {
        param(
            [Parameter(Mandatory = $true)]
            [array]$Profiles
        )

        $pool = [RunspaceFactory]::CreateRunspacePool(1, $maxThreadsEffective)
        $pool.Open()

        $jobs = [System.Collections.Generic.List[object]]::new()

        $scriptBlock = {
            param($Profile)

            $ErrorActionPreference = 'Stop'

            $userPath = $Profile.LocalPath
            $userName = [System.IO.Path]::GetFileName($userPath)
            $userSid = $Profile.SID
            $start = Get-Date

            Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.startResidualFolder01' -Args @($userName, $userPath))

            $cimSuccess = $false
            try {
                Remove-CimInstance -InputObject $Profile -ErrorAction Stop -Confirm:$false
                Write-ToolkitLog -Level 'SUCCESS' -Message (Get-SourceTextLoc 'toolText.cimProfileRemoved0' -Args @($userName))
                $cimSuccess = $true
            }
            catch {
                Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.cimRemoveFailed01' -Args @($userName, $($_.Exception.Message)))
            }

            if ([System.IO.Directory]::Exists($userPath)) {
                try {
                    $tempEmpty = Join-Path $env:TEMP "EmptyFolder"

                    if (-not (Test-Path $tempEmpty)) {
                        New-Item -ItemType Directory -Path $tempEmpty | Out-Null
                    }

                    Invoke-ExternalCommandWithLog -Command 'robocopy.exe' `
                        -Arguments @("`"$tempEmpty`"", "`"$userPath`"", '/MIR', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP') `
                        -LogContextKey "ProfileCleanup-Robocopy-$userName" | Out-Null

                    Remove-ItemSafely -Path $userPath -Recurse

                    Write-ToolkitLog -Level 'SUCCESS' -Message (Get-SourceTextLoc 'toolText.folderRemoved0' -Args @($userName))
                }
                catch {
                    Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.standardFolderCleanupFailed01' -Args @($userName, $($_.Exception.Message)))

                    try {
                        Invoke-ExternalCommandWithLog -Command 'takeown.exe' -Arguments @('/F', "`"$userPath`"", '/R', '/D', 'Y') -LogContextKey "ProfileCleanup-TakeOwn-$userName" | Out-Null
                        Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$userPath`"", '/grant', 'Administrators:F', '/T', '/C') -LogContextKey "ProfileCleanup-Icacls-$userName" | Out-Null
                        Remove-ItemSafely -Path $userPath -Recurse
                        Write-ToolkitLog -Level 'SUCCESS' -Message (Get-SourceTextLoc 'toolText.folderRemovedAfterAclReset0' -Args @($userName))
                    }
                    catch {
                        Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'toolText.cleanupFailed01' -Args @($userName, $($_.Exception.Message)))
                    }
                }
            }

            $folderGone = -not [System.IO.Directory]::Exists($userPath)
            if (-not $cimSuccess -and $folderGone -and $userSid) {
                Remove-ProfileRegistryEntries -Sid $userSid -UserName $userName
            }

            $success = $folderGone
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
            foreach ($profile in $Profiles) {
                $ps = [PowerShell]::Create()
                $ps.RunspacePool = $pool

                [void]$ps.AddScript($scriptBlock, $true).
                    AddArgument($profile)

                $handle = $ps.BeginInvoke()

                $jobs.Add([PSCustomObject]@{
                    PowerShell = $ps
                    Handle     = $handle
                })
            }

            $total = $jobs.Count
            $lastPercent = -1

            do {
                $completed = ($jobs | Where-Object { $_.Handle.IsCompleted }).Count
                $percent = if ($total -gt 0) { [math]::Floor(($completed / $total) * 100) } else { 100 }

                if ($percent -ne $lastPercent) {
                    $lastPercent = $percent
                    Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingRegisteredProfiles') -Status (Get-SourceTextLoc 'toolText.extra.01Completed' -Args @($completed, $total)) -Percent $percent -Icon '🗑️'
                }

                Start-Sleep -Milliseconds 500
            } while ($completed -lt $total)

            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingRegisteredProfiles') -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
            Clear-ProgressLine

            $results = foreach ($job in $jobs) {
                try {
                    $job.PowerShell.EndInvoke($job.Handle)
                }
                catch {
                    Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'toolText.runspaceError0' -Args @($($_.Exception.Message)))
                }
                finally {
                    $job.PowerShell.Commands.Clear()
                    $job.PowerShell.Dispose()
                }
            }

            return $results
        }
        finally {
            if ($pool) {
                $pool.Close()
                $pool.Dispose()
            }
        }
    }

    function Get-ResidualUserFolders {
        $excluded = New-ProtectedNameSet
        $registeredProfilePaths = Get-RegisteredProfilePathSet

        Write-StyledMessage -Type 'Info' -Text ("🔎 " + (Get-SourceTextLoc 'toolText.checkResidualFoldersInTheUsersDirectory'))
        Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'toolText.checkResidualFoldersInTheUsersDirectory')

        $folders = Get-ChildItem -Path $usersRoot -Directory -Force |
            Where-Object {
                -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
            }

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
                Remove-Item -LiteralPath $folderPath -Force -Recurse -ErrorAction Stop -Confirm:$false
                $success = -not [System.IO.Directory]::Exists($folderPath)
            }
            catch {
                Write-ToolkitLog -Level 'WARNING' -Message (Get-SourceTextLoc 'toolText.standardResidualFolderRemovalFailed01' -Args @($folderPath, $($_.Exception.Message)))

                try {
                    Invoke-ExternalCommandWithLog -Command 'takeown.exe' -Arguments @('/F', "`"$folderPath`"", '/R', '/D', 'Y') -LogContextKey "ResidualTakeOwn-$($folder.Name)" | Out-Null
                    Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$folderPath`"", '/grant', 'Administrators:F', '/T', '/C') -LogContextKey "ResidualIcacls-$($folder.Name)" | Out-Null
                    Remove-ItemSafely -Path $folderPath -Recurse
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

    Start-ToolkitSession -ToolName $script:ToolName -SubTitle (Get-SourceTextLoc 'script.WinDeleteUserProfiles')

    try {
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
                Select-Object @{Name='User'; Expression={ [System.IO.Path]::GetFileName($_.LocalPath) }},
                                @{Name='Loaded'; Expression={ $_.Loaded }},
                                @{Name='LastUseTime'; Expression={ $_.LastUseTime }},
                                @{Name='Path'; Expression={ $_.LocalPath }} |
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

        $allResults = @($profileResults) + @($residualResults)
        $failedCount = @($allResults | Where-Object { -not $_.Success }).Count
        $profileSuccessCount = @($profileResults | Where-Object { $_.Success }).Count
        $residualSuccessCount = @($residualResults | Where-Object { $_.Success }).Count

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
            Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.restartRecommendedAfterProfileCleanup') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName $script:ToolName
        throw
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text ("♻️ " + (Get-SourceTextLoc 'toolText.winDeleteUserProfilesSessionEnded'))
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.winDeleteUserProfilesSessionEnded')
    }
}
