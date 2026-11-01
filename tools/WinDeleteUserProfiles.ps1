# Coordinate registered-profile and residual-folder cleanup with shared protections and result reporting.
function WinDeleteUserProfiles {
    <#
    .SYNOPSIS
        Safely removes unused local user accounts, unloaded profiles, and residual folders from C:\Users.

    .DESCRIPTION
        Performs a controlled cleanup of local profiles in C:\Users using Win32_UserProfile.
        Excludes special and loaded profiles, system accounts, the current user profile, and protected names.
        Processes each selected profile completely before starting the next profile.
        After deleting registered profiles, checks the users folder and removes residual directories that are no
        longer associated with profiles in the registry or CIM, while preserving all protected exclusions.
        Removes eligible local accounts by SID after their profile data is gone, including accounts left behind
        by earlier profile-only cleanup. Never removes domain accounts, built-in accounts, or accounts whose
        profiles remain registered. Accounts without profiles are considered only under the Windows profiles root.

        The script does not request interactive confirmation before deletion.

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

    # Preserve shared/system folders and both names that can identify the current user's profile.
    $protectedProfileNames = @(
        'Public',
        'Pubblica',
        'Default',
        'Default User',
        'All Users',
        'defaultuser0',
        'DefaultAccount',
        'WDAGUtilityAccount',
        'WSIAccount',
        'Administrator',
        'Guest',
        $currentUser,
        $currentUserFolder
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    # Permanent cleanup events share one console/log route instead of separate output streams.
    function Write-ProfileCleanupMessage {
        param(
            [ValidateSet('Info', 'Warning', 'Error', 'Success')]
            [string]$Type = 'Info',

            [Parameter(Mandatory = $true)]
            [string]$Text
        )

        if ($Global:ProgressLineStart) { Clear-ProgressLine }
        Write-StyledMessage -Type $Type -Text $Text
    }

    # Render target data once so the console and structured log retain the same complete rows.
    function Write-ProfileCleanupTable {
        [CmdletBinding()]
        param([Parameter(ValueFromPipeline = $true)][object]$InputObject)

        begin { $rows = [System.Collections.Generic.List[object]]::new() }
        process { if ($null -ne $InputObject) { $rows.Add($InputObject) } }
        end {
            $table = $rows | Format-Table -AutoSize | Out-String -Width 4096
            foreach ($line in ($table -split '\r?\n')) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-ProfileCleanupMessage -Type 'Info' -Text $line.TrimEnd()
                }
            }
        }
    }

    # Apply the same case-insensitive name exclusions to registered profiles and residual folders.
    function New-ProtectedNameSet {
        $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $protectedProfileNames | ForEach-Object { [void]$excluded.Add($_) }
        # The unary comma returns the set itself instead of enumerating its entries into the pipeline.
        return , $excluded
    }

    # Protect built-in identities by SID even when their names have been localized or changed.
    function Test-ProtectedLocalAccount {
        param([Parameter(Mandatory = $true)][object]$Account)

        $sid = [string]$Account.SID
        if ($sid -eq $currentUserSid -or $sid -notmatch '^S-1-5-21-\d+-\d+-\d+-(\d+)$') {
            return $true
        }
        if ([uint64]$Matches[1] -lt 1000) { return $true }

        $excluded = New-ProtectedNameSet
        return $excluded.Contains($Account.Name)
    }

    # Logons and configured services can use a local identity without ever loading its user profile.
    function Get-ProtectedLocalAccountSids {
        param([Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Accounts)

        $protectedSids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $activeNames = @(Get-CimInstance -ClassName Win32_LoggedOnUser -ErrorAction Stop |
            Where-Object { $_.Antecedent.Domain -eq $computerName } | ForEach-Object { $_.Antecedent.Name })
        $serviceNames = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop | ForEach-Object { $_.StartName })
        foreach ($account in $Accounts) {
            if ((Test-ProtectedLocalAccount -Account $account) -or $activeNames -contains $account.Name -or
                $serviceNames -contains $account.Name -or $serviceNames -contains ".\$($account.Name)" -or
                $serviceNames -contains "$computerName\$($account.Name)" -or $serviceNames -contains "$($account.Name)@$computerName") {
                [void]$protectedSids.Add([string]$account.SID)
            }
        }
        return , $protectedSids
    }

    # Account discovery is independent of profile discovery so a second run can repair profile-only cleanup.
    function Get-RemovableLocalAccounts {
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [array]$Accounts,

            [AllowEmptyCollection()]
            [array]$ProfileResults = @()
        )

        # Fail closed if either provider cannot confirm which profiles still exist.
        $remainingProfiles = @(Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop)
        $profileListKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
        $registeredSids = @(Get-ChildItem -LiteralPath $profileListKey -ErrorAction Stop |
            ForEach-Object { $_.PSChildName -replace '\.bak$', '' })
        $removedProfileSids = @($ProfileResults | Where-Object { $_.Success } | ForEach-Object { $_.Sid })
        $failedProfileSids = @($ProfileResults | Where-Object { -not $_.Success } | ForEach-Object { $_.Sid })
        $protectedSids = Get-ProtectedLocalAccountSids -Accounts $Accounts

        foreach ($account in $Accounts) {
            $sid = [string]$account.SID
            if ($protectedSids.Contains($sid)) { continue }
            if ($failedProfileSids -contains $sid -or $registeredSids -contains $sid -or
                @($remainingProfiles | Where-Object { $_.SID -eq $sid }).Count -gt 0) { continue }

            if ($removedProfileSids -notcontains $sid) {
                # A custom root must not turn unrelated, profile-less machine accounts into targets.
                if (-not $usersRoot.Equals($profilesDirectory, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
                # Without a profile timestamp, require an old, known logon when an age limit is requested.
                if ($minimumLastUseDate -and (-not $account.LastLogon -or $account.LastLogon -gt $minimumLastUseDate)) { continue }
            }

            $accountPath = [System.IO.Path]::GetFullPath((Join-Path $usersRoot $account.Name))
            if (-not $accountPath.StartsWith($usersRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
                (Test-Path -LiteralPath $accountPath -ErrorAction Stop)) { continue }

            $account
        }
    }

    # Delete the exact local identity, then verify it disappeared instead of trusting a command's return alone.
    function Remove-LocalUserAccounts {
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [array]$Accounts,

            [AllowEmptyCollection()]
            [array]$ProfileResults = @()
        )

        foreach ($account in $Accounts) {
            $start = Get-Date
            $sid = [string]$account.SID
            $success = $false
            if (Test-ProtectedLocalAccount -Account $account) { continue }

            try {
                # Refresh activity immediately before deletion; failures here must never permit removal.
                # Resolve names again by SID and repeat every exclusion in case identity or profile state changed.
                $currentAccount = Get-LocalUser -SID $sid -ErrorAction Stop
                $eligibleAccounts = @(Get-RemovableLocalAccounts -Accounts @($currentAccount) -ProfileResults $ProfileResults)
                if ($eligibleAccounts.Count -ne 1) {
                    throw (Get-SourceTextLoc 'toolText.localAccountProtected0' -Args @($account.Name))
                }
                Remove-LocalUser -SID $sid -ErrorAction Stop -Confirm:$false
                if (@(Get-LocalUser -ErrorAction Stop | Where-Object { [string]$_.SID -eq $sid }).Count -gt 0) {
                    throw (Get-SourceTextLoc 'toolText.localAccountStillExists0' -Args @($sid))
                }
                $success = $true
                Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.localAccountRemoved01' -Args @($account.Name, $sid))
            }
            catch {
                Write-ProfileCleanupMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.localAccountRemovalFailed01' -Args @($account.Name, $_.Exception.Message))
            }

            [PSCustomObject]@{
                Type     = 'LocalAccount'
                UserName = $account.Name
                Sid      = $sid
                Success  = $success
                Duration = New-TimeSpan -Start $start -End (Get-Date)
            }
        }
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
            Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.registryEntryRemovedForSid01' -Args @($UserName, $Sid))
            
            return $true
        }
        catch {
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.failedToRemoveRegistryEntryForSid01' -Args @($UserName, $($_.Exception.Message)))
            
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
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.cimProfileDetectionFailed0' -Args @($($_.Exception.Message)))
            
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
                Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.failedToNormalizeRegisteredProfileLocalpath0' -Args @($($_.LocalPath)))
            }
        }

        return , $pathSet
    }

    # Select unloaded, non-special profiles under the configured root before scheduling destructive work.
    function Get-RemovableUserProfiles {
        $excluded = New-ProtectedNameSet

        Write-ProfileCleanupMessage -Type 'Info' -Text ("🔍 " + (Get-SourceTextLoc 'toolText.scanningRegisteredLocalProfiles'))

        try {
            $profiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop
        }
        catch {
            Write-ProfileCleanupMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.cimProfileDetectionFailed0' -Args @($($_.Exception.Message))))
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
                Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.excludedProfile01' -Args @($profileName, $($profileItem.LocalPath)))
                continue
            }

            # Protect the current account independently of folder-name exclusions.
            if ($protectedAccountSids -and $protectedAccountSids.Contains($profileItem.SID)) {
                Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.excludedProfile01' -Args @($profileName, $profileItem.LocalPath))
                continue
            }

            if ($profileItem.SID -eq $currentUserSid) {
                Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.excludedProfileBecauseSidMatchesCurrentUser0' -Args @($profileName, $profileItem.SID))
                continue
            }

            # Apply the optional age cutoff only when Windows provides a last-use timestamp.
            if ($minimumLastUseDate -and $profileItem.LastUseTime) {
                $lastUse = $profileItem.LastUseTime
                if ($lastUse -gt $minimumLastUseDate) {
                    Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.profileExcludedDueToTimeThreshold0LastUse1' -Args @($profileName, $lastUse))
                    continue
                }
            }

            $profileItem
        }
    }

    # Complete each registered profile before starting the next, using the existing toolkit context.
    function Remove-UserProfile {
        param(
            [Parameter(Mandatory = $true)]
            [object]$ProfileItem
        )

        # Terminating errors route failed deletion steps through their fallback cleanup paths.
        $ErrorActionPreference = 'Stop'

        $userPath = $ProfileItem.LocalPath
        $userName = [System.IO.Path]::GetFileName($userPath)
        $userSid = $ProfileItem.SID
        $start = Get-Date

        Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startResidualFolder01' -Args @($userName, $userPath))

        # Let Windows remove the registered profile first; filesystem cleanup handles any leftovers.
        try {
            Remove-CimInstance -InputObject $ProfileItem -ErrorAction Stop -Confirm:$false
            Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.cimProfileRemoved0' -Args @($userName))
        }
        catch {
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.cimRemoveFailed01' -Args @($userName, $($_.Exception.Message)))
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

                Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.folderRemoved0' -Args @($userName))
            }
            catch {
                Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.standardFolderCleanupFailed01' -Args @($userName, $($_.Exception.Message)))

                # Repair ownership and access if permissions prevented standard folder removal.
                try {
                    Invoke-ExternalCommandWithLog -Command 'takeown.exe' -Arguments @('/F', "`"$userPath`"", '/R', '/D', 'Y') -LogContextKey "ProfileCleanup-TakeOwn-$userName" | Out-Null
                    # S-1-5-32-544 - Fixed SID across Windows languages; avoids depending on localized group names.
                    Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$userPath`"", '/grant', '*S-1-5-32-544:F', '/T', '/C') -LogContextKey "ProfileCleanup-Icacls-$userName" | Out-Null
                    Remove-Item -LiteralPath $userPath -Recurse -Force -ErrorAction Stop -Confirm:$false
                    Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.folderRemovedAfterAclReset0' -Args @($userName))
                }
                catch {
                    Write-ProfileCleanupMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.cleanupFailed01' -Args @($userName, $($_.Exception.Message)))
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
            Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.completedProfile01' -Args @($userName, $duration.ToString()))
        }
        else {
            Write-ProfileCleanupMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.failedProfile0' -Args @($userName))
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

    # Return one result per profile in the original input order, including unexpected failures.
    function Invoke-ProfileRemovalBatch {
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [array]$Profiles
        )

        $results = [System.Collections.Generic.List[object]]::new()
        $total = $Profiles.Count
        $completed = 0

        try {
            foreach ($profileItem in $Profiles) {
                $userName = [System.IO.Path]::GetFileName($profileItem.LocalPath)
                $start = Get-Date
                $percent = if ($total -gt 0) { [math]::Floor(($completed / $total) * 100) } else { 100 }
                Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingRegisteredProfiles') -Status ("{0} / {1} - {2}" -f ($completed + 1), $total, $userName) -Percent $percent -Icon '🗑️'

                try {
                    $result = Remove-UserProfile -ProfileItem $profileItem
                }
                catch {
                    Write-ProfileCleanupMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.cleanupFailed01' -Args @($userName, $_.Exception.Message))
                    # Preserve identity in a failed result so exceptions remain visible in summary counts.
                    $result = [PSCustomObject]@{
                        Type     = 'Profile'
                        UserName = $userName
                        Path     = $profileItem.LocalPath
                        Sid      = $profileItem.SID
                        Success  = $false
                        Duration = New-TimeSpan -Start $start -End (Get-Date)
                    }
                }

                $results.Add($result)
                $completed++
                $percent = if ($total -gt 0) { [math]::Floor(($completed / $total) * 100) } else { 100 }
                Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingRegisteredProfiles') -Status (Get-SourceTextLoc 'toolText.extra.01Completed' -Args @($completed, $total)) -Percent $percent -Icon '🗑️'
            }

            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingRegisteredProfiles') -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
            return $results
        }
        finally {
            Clear-ProgressLine
        }
    }

    # Select leftover directories only after protected-name, CIM-path, registered-SID, and link exclusions.
    function Get-ResidualUserFolders {
        $excluded = New-ProtectedNameSet
        # Refresh registration after profile removal so this scan reflects the state Windows now reports.
        $registeredProfilePaths = Get-RegisteredProfilePathSet

        Write-ProfileCleanupMessage -Type 'Info' -Text ("🔎 " + (Get-SourceTextLoc 'toolText.checkResidualFoldersInTheUsersDirectory'))

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
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.couldNotEnumerateRegistryProfileList0' -Args @($($_.Exception.Message)))
        }

        foreach ($folder in $folders) {
            $folderName = $folder.Name
            $folderPath = [System.IO.Path]::GetFullPath($folder.FullName).TrimEnd('\')

            if ($excluded.Contains($folderName)) {
                Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.residualFolderExcludedForProtectedName01' -Args @($folderName, $folderPath))
                continue
            }

            if ($registeredProfilePaths.Contains($folderPath)) {
                Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.residualFolderExcludedBecauseItIsStillAssociatedWithWin32Userprofile01' -Args @($folderName, $folderPath))
                continue
            }

            if ($registeredSids -contains $folderName) {
                Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.residualFolderExcludedBecauseSidStillRegistered01' -Args @($folderName, $folderPath))
                continue
            }

            # Keep the link exclusion at candidate selection as well as during initial enumeration.
            if ($folder.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.residualFolderExcludedBecauseReparsePointSymlink01' -Args @($folderName, $folderPath))
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

            Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startResidualFolder01' -Args @($($folder.Name), $($folder.Path)))

            $folderPath = $folder.Path

            try {
                # Literal paths preserve folder names containing wildcard characters during deletion.
                Remove-Item -LiteralPath $folderPath -Force -Recurse -ErrorAction Stop -Confirm:$false
                # A completed command is insufficient; verify that the directory is actually gone.
                $success = -not [System.IO.Directory]::Exists($folderPath)
            }
            catch {
                Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.standardResidualFolderRemovalFailed01' -Args @($folderPath, $($_.Exception.Message)))

                # Retry with ownership and access repaired when normal filesystem deletion fails.
                try {
                    Invoke-ExternalCommandWithLog -Command 'takeown.exe' -Arguments @('/F', "`"$folderPath`"", '/R', '/D', 'Y') -LogContextKey "ResidualTakeOwn-$($folder.Name)" | Out-Null
                    # S-1-5-32-544 - Fixed SID across Windows languages; avoids depending on localized group names.
                    Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$folderPath`"", '/grant', '*S-1-5-32-544:F', '/T', '/C') -LogContextKey "ResidualIcacls-$($folder.Name)" | Out-Null
                    Remove-Item -LiteralPath $folderPath -Recurse -Force -ErrorAction Stop -Confirm:$false
                    $success = -not [System.IO.Directory]::Exists($folderPath)
                }
                catch {
                    Write-ProfileCleanupMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.remnantFolderRemovalFailed01' -Args @($folderPath, $($_.Exception.Message)))
                    $success = $false
                }
            }

            $duration = New-TimeSpan -Start $start -End (Get-Date)

            if ($success) {
                Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.completedResidualFolder01' -Args @($($folder.Name), $duration.ToString()))
            }
            else {
                Write-ProfileCleanupMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.failedResidualFolder0' -Args @($($folder.Name)))
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

        # Check account support before deleting data, and snapshot accounts so newly created users are not selected.
        Get-Command Remove-LocalUser -ErrorAction Stop | Out-Null
        $localAccounts = @(Get-LocalUser -ErrorAction Stop)
        $profilesDirectoryValue = Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -Name 'ProfilesDirectory' -ErrorAction Stop
        $profilesDirectory = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($profilesDirectoryValue).TrimEnd('\') + '\')
        $protectedAccountSids = Get-ProtectedLocalAccountSids -Accounts $localAccounts
        foreach ($account in $localAccounts) {
            if ($protectedAccountSids.Contains([string]$account.SID)) {
                $protectedProfileNames += $account.Name
            }
        }

        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os -and $os.Caption -notmatch 'Windows 11') {
            Write-ProfileCleanupMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.systemDetected0TheScriptIsDesignedForWindows11' -Args @($($os.Caption))))
        }

        Write-ProfileCleanupMessage -Type 'Info' -Text ("🖥️ " + (Get-SourceTextLoc 'toolText.computer0' -Args @($computerName)))
        Write-ProfileCleanupMessage -Type 'Info' -Text ("👤 " + (Get-SourceTextLoc 'toolText.currentUserProtected0' -Args @($currentUser)))
        Write-ProfileCleanupMessage -Type 'Info' -Text ("📁 " + (Get-SourceTextLoc 'toolText.profilePath0' -Args @($usersRoot)))
        Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.nonInteractiveModeNoConfirmationWillBeRequestedBeforeCancellations')

        if ($minimumLastUseDate) {
            Write-ProfileCleanupMessage -Type 'Info' -Text ("📅 " + (Get-SourceTextLoc 'toolText.lastActivityThresholdProfilesNotUsedForAtLeast0Days' -Args @($MinimumProfileAgeDays)))
        }

        Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.sessionStartedOn0' -Args @($computerName))

        $profileResults = @()
        $residualResults = @()
        $accountResults = @()

        $targets = @(Get-RemovableUserProfiles)

        if ($targets -and $targets.Count -gt 0) {
            Write-Host ''
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.registeredProfilesSelectedForAutomaticRemoval')
            Write-Host ''

            $targets |
            Select-Object @{Name = 'User'; Expression = { [System.IO.Path]::GetFileName($_.LocalPath) } },
            @{Name = 'Loaded'; Expression = { $_.Loaded } },
            @{Name = 'LastUseTime'; Expression = { $_.LastUseTime } },
            @{Name = 'Path'; Expression = { $_.LocalPath } } |
            Write-ProfileCleanupTable

            Write-Host ''
            Write-ProfileCleanupMessage -Type 'Info' -Text ("🚀 " + (Get-SourceTextLoc 'toolText.startAutomaticRemovalOf0RegisteredProfiles' -Args @($targets.Count)))
            Write-Host ''

            $profileResults = @(Invoke-ProfileRemovalBatch -Profiles $targets)
        }
        else {
            Write-Host ''
            Write-ProfileCleanupMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.noRemovableRegisteredProfilesFound'))
        }

        # Scan leftovers after registered-profile removal using the updated registration state.
        if (-not $SkipResidualFolderCleanup) {
            $residualFolders = @(Get-ResidualUserFolders)

            if ($residualFolders -and $residualFolders.Count -gt 0) {
                Write-Host ''
                Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.residualFoldersSelectedForAutomaticRemoval0' -Args @($residualFolders.Count))
                $residualFolders | Select-Object Name, Path | Write-ProfileCleanupTable

                Write-Host ''
                Write-ProfileCleanupMessage -Type 'Info' -Text ("🧹 " + (Get-SourceTextLoc 'toolText.startingRemovalOfResidualFolders'))
                Write-Host ''

                $residualResults = @(Remove-ResidualUserFolders -Folders $residualFolders)
            }
            else {
                Write-ProfileCleanupMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.noRemovableResidualFolderFoundInCUsers'))
            }
        }
        else {
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.residualFolderCleanupSkippedForSkipresidualfoldercleanupParameter')
        }

        # Report successes separately for each phase, but base restart advice on failures from either phase.
        $accountTargets = @(Get-RemovableLocalAccounts -Accounts $localAccounts -ProfileResults $profileResults)
        if ($accountTargets.Count -gt 0) {
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.localAccountsSelectedForAutomaticRemoval0' -Args @($accountTargets.Count))
            $accountTargets | Select-Object Name, SID | Write-ProfileCleanupTable
            $accountResults = @(Remove-LocalUserAccounts -Accounts $accountTargets -ProfileResults $profileResults)
        }

        $allResults = @($profileResults) + @($residualResults) + @($accountResults)
        $failedCount = @($allResults | Where-Object { -not $_.Success }).Count
        $profileSuccessCount = @($profileResults | Where-Object { $_.Success }).Count
        $residualSuccessCount = @($residualResults | Where-Object { $_.Success }).Count
        $accountSuccessCount = @($accountResults | Where-Object { $_.Success }).Count

        # Open sessions or handles may prevent cleanup; recommend a restart only when items failed.
        if ($failedCount -gt 0) {
            $rebootRecommended = $true
            Write-ProfileCleanupMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.extra.restartRecommendedAfterProfileCleanup'))
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.recommendedReboot0' -Args @((Get-SourceTextLoc 'toolText.0ItemsNotRemovedMayBeBlockedByOpenSessionsOrHandles' -Args @($failedCount))))
        }

        Write-ProfileCleanupMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.registeredProfilesRemoved0' -Args @($profileSuccessCount)))
        Write-ProfileCleanupMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.residualFoldersRemoved0' -Args @($residualSuccessCount)))
        Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.localAccountsRemoved0' -Args @($accountSuccessCount))
        if ($failedCount -gt 0) {
            Write-ProfileCleanupMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.itemsNotRemoved0' -Args @($failedCount)))
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
        Write-ProfileCleanupMessage -Type 'Info' -Text ("♻️ " + (Get-SourceTextLoc 'toolText.winDeleteUserProfilesSessionEnded'))
    }
}
