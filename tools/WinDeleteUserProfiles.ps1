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

    .PARAMETER LogFolder
        Folder in which to save the log file.

    .PARAMETER MinimumProfileAgeDays
        Minimum profile age in days since its last use. The default value 0 preserves the original behavior.

    .PARAMETER SkipResidualFolderCleanup
        Skips the final cleanup of residual folders in C:\Users.

    .PARAMETER SuppressToolkitSession
        Does not call Start-ToolkitSession even when it is available.

    .EXAMPLE
        WinDeleteUserProfiles

    .EXAMPLE
        WinDeleteUserProfiles -MinimumProfileAgeDays 30
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(1, 16)]
        [int]$MaxThreads = [Math]::Min(2, [Environment]::ProcessorCount),

        [ValidateRange(0, 3600)]
        [int]$CountdownSeconds = 30,

        [switch]$SuppressIndividualReboot,

        [ValidateNotNullOrEmpty()]
        [string]$UsersRoot = 'C:\Users',

        [ValidateNotNullOrEmpty()]
        [string]$LogFolder = 'C:\Temp',

        [ValidateRange(0, 3650)]
        [int]$MinimumProfileAgeDays = 0,

        [switch]$SkipResidualFolderCleanup,

        [switch]$SuppressToolkitSession
    )

    begin {
        $script:ToolName = 'WinDeleteUserProfiles'
        $script:ToolVersion = '3.1'
        $script:SessionStart = Get-Date
        $script:UsersRoot = [System.IO.Path]::GetFullPath($UsersRoot.TrimEnd('\') + '\')
        $script:LogFolder = [System.IO.Path]::GetFullPath($LogFolder)
        $script:LogFile = Join-Path $script:LogFolder ("{0}_{1}.log" -f $script:ToolName, (Get-Date -Format 'yyyyMMdd_HHmmss'))
        $script:CurrentUser = $env:USERNAME
        $script:ComputerName = $env:COMPUTERNAME
        $script:CountdownSeconds = $CountdownSeconds
        $script:SuppressIndividualReboot = $SuppressIndividualReboot
        $script:RebootRecommended = $false
        $script:MinimumLastUseDate = if ($MinimumProfileAgeDays -gt 0) { (Get-Date).AddDays(-$MinimumProfileAgeDays) } else { $null }

        $script:ProtectedProfileNames = @(
            'Public',
            'Pubblica',
            'Default',
            'Default User',
            'All Users',
            'defaultuser0',
            'WDAGUtilityAccount',
            'Administrator',
            'Guest',
            $script:CurrentUser
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        $savedErrorActionPreference = $ErrorActionPreference
        $savedProgressPreference = $ProgressPreference
        $savedConfirmPreference = $ConfirmPreference

        $ErrorActionPreference = 'Stop'
        $ProgressPreference = 'Continue'
        $ConfirmPreference = 'None'

        $script:LogQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    }

    process {
        if (-not (Get-Command -Name Write-StyledMessage -ErrorAction SilentlyContinue)) {
            function Write-StyledMessage {
                param(
                    [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Progress')]
                    [string]$Type = 'Info',

                    [Parameter(Mandatory = $true)]
                    [string]$Text
                )

                $color = switch ($Type) {
                    'Success' { 'Green' }
                    'Warning' { 'Yellow' }
                    'Error'   { 'Red' }
                    default   { 'Cyan' }
                }

                Write-Host $Text -ForegroundColor $color
            }
        }


        function Add-ProfileCleanupLog {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Text,

                [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
                [string]$Level = 'INFO'
            )

            $script:LogQueue.Enqueue(
                ('{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Text)
            )
        }


        function Set-ProfileCleanupRebootRecommended {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Reason
            )

            $script:RebootRecommended = $true
            Add-ProfileCleanupLog -Level 'WARNING' -Text (Get-Loc 'toolText.recommendedReboot0' -Args @($Reason))
        }


        function Invoke-ProfileCleanupReboot {
            if (-not $script:RebootRecommended) {
                return
            }

            if (Get-Command -Name Invoke-ToolkitReboot -ErrorAction SilentlyContinue) {
                Invoke-ToolkitReboot -Message (Get-Loc 'toolText.extra.restartRecommendedAfterProfileCleanup') -Seconds $script:CountdownSeconds -SuppressIndividualReboot:$script:SuppressIndividualReboot
                return
            }

            if ($script:SuppressIndividualReboot) {
                $Global:NeedsFinalReboot = $true
                Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.individualRestartSuppressedAFinalRebootWillBeHandled')
                return
            }

            if (Get-Command -Name Start-InterruptibleCountdown -ErrorAction SilentlyContinue) {
                if (Start-InterruptibleCountdown -Seconds $script:CountdownSeconds -Message (Get-Loc 'toolText.extra.restartRecommendedAfterProfileCleanup')) {
                    Restart-Computer -Force
                }
                return
            }

            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.restartRecommendedToCompleteCleanupOfUnremovedProfiles')
        }


        function Test-IsAdministrator {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = [Security.Principal.WindowsPrincipal]::new($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }


        function Initialize-ProfileCleanupSession {
            [System.IO.Directory]::CreateDirectory($script:LogFolder) | Out-Null

            if (-not (Test-IsAdministrator)) {
                throw (Get-Loc 'toolText.extra2.theScriptMustBeRunFromAPowershellConsoleStartedAsAdministrator')
            }

            if (-not (Test-Path -LiteralPath $script:UsersRoot -PathType Container)) {
                throw (Get-Loc 'toolText.extra.profilePathDoesNotExist0' -Args @($script:UsersRoot))
            }

            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($os -and $os.Caption -notmatch 'Windows 11') {
                Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.systemDetected0TheScriptIsDesignedForWindows11' -Args @($($os.Caption)))
            }

            if (-not $SuppressToolkitSession -and (Get-Command -Name Start-ToolkitSession -ErrorAction SilentlyContinue)) {
                $profileCleanupTitle = if (Get-Command -Name Get-Loc -ErrorAction SilentlyContinue) {
                    Get-Loc 'script.WinDeleteUserProfiles'
                }
                else {
                    'Delete Windows user profiles'
                }
                Start-ToolkitSession -ToolName $script:ToolName -SubTitle $profileCleanupTitle
            }
            else {
                Write-Host ''
                Write-Host '====================================================' -ForegroundColor Cyan
                Write-Host (Get-Loc 'toolText.0V1' -Args @($script:ToolName, $script:ToolVersion))
                Write-Host '====================================================' -ForegroundColor Cyan
                Write-Host ''
            }

            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.computer0' -Args @($script:ComputerName))
            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.currentUserProtected0' -Args @($script:CurrentUser))
            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.profilePath0' -Args @($script:UsersRoot))
            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.threadsConfigured0' -Args @($MaxThreads))
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.nonInteractiveModeNoConfirmationWillBeRequestedBeforeCancellations')

            if ($script:MinimumLastUseDate) {
                Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.lastActivityThresholdProfilesNotUsedForAtLeast0Days' -Args @($MinimumProfileAgeDays))
            }

            Add-ProfileCleanupLog -Text (Get-Loc 'toolText.sessionStartedOn0' -Args @($script:ComputerName))
        }


        function New-ProtectedNameSet {
            $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $script:ProtectedProfileNames | ForEach-Object { [void]$excluded.Add($_) }
            return ,$excluded
        }


        function Get-RegisteredProfilePathSet {
            $pathSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

            Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.LocalPath -and
                    $_.LocalPath.StartsWith($script:UsersRoot, [System.StringComparison]::OrdinalIgnoreCase)
                } |
                ForEach-Object {
                    try {
                        [void]$pathSet.Add([System.IO.Path]::GetFullPath($_.LocalPath).TrimEnd('\'))
                    }
                    catch {
                        Add-ProfileCleanupLog -Level 'WARNING' -Text (Get-Loc 'toolText.failedToNormalizeRegisteredProfileLocalpath0' -Args @($($_.LocalPath)))
                    }
                }

            return ,$pathSet
        }


        function Get-RemovableUserProfiles {
            $excluded = New-ProtectedNameSet

            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.scanningRegisteredLocalProfiles')

            $profiles = Get-CimInstance -ClassName Win32_UserProfile | Where-Object {
                -not $_.Special -and
                -not $_.Loaded -and
                $_.LocalPath -and
                $_.LocalPath.StartsWith($script:UsersRoot, [System.StringComparison]::OrdinalIgnoreCase)
            }

            foreach ($profile in $profiles) {
                $profileName = [System.IO.Path]::GetFileName($profile.LocalPath)

                if ($excluded.Contains($profileName)) {
                    Add-ProfileCleanupLog -Text (Get-Loc 'toolText.excludedProfile01' -Args @($profileName, $($profile.LocalPath)))
                    continue
                }

                if ($script:MinimumLastUseDate -and $profile.LastUseTime) {
                    $lastUse = $profile.LastUseTime
                    if ($lastUse -gt $script:MinimumLastUseDate) {
                        Add-ProfileCleanupLog -Text (Get-Loc 'toolText.profileExcludedDueToTimeThreshold0LastUse1' -Args @($profileName, $lastUse))
                        continue
                    }
                }

                $profile
            }
        }


        function Show-ProfileCleanupPreview {
            param(
                [Parameter(Mandatory = $true)]
                [array]$Profiles
            )

            Write-Host ''
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.registeredProfilesSelectedForAutomaticRemoval')
            Write-Host ''

            $Profiles |
                Select-Object @{Name='User'; Expression={ [System.IO.Path]::GetFileName($_.LocalPath) }},
                              @{Name='Loaded'; Expression={ $_.Loaded }},
                              @{Name='LastUseTime'; Expression={ $_.LastUseTime }},
                              @{Name='Path'; Expression={ $_.LocalPath }} |
                Format-Table -AutoSize

            Write-Host ''
        }


        function Invoke-ProfileRemovalBatch {
            param(
                [Parameter(Mandatory = $true)]
                [array]$Profiles
            )

            $pool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
            $pool.Open()

            $jobs = [System.Collections.Generic.List[object]]::new()

            $scriptBlock = {
                param($Profile, $LogQueue)

                $ConfirmPreference = 'None'
                $ErrorActionPreference = 'Stop'

                $userPath = $Profile.LocalPath
                $userName = [System.IO.Path]::GetFileName($userPath)
                $start = Get-Date

                $LogQueue.Enqueue(('{0} [INFO] START PROFILE - {1} - {2}' -f $start.ToString('yyyy-MM-dd HH:mm:ss'), $userName, $userPath))

                try {
                    Remove-CimInstance -InputObject $Profile -ErrorAction Stop -Confirm:$false
                    $LogQueue.Enqueue(('{0} [SUCCESS] CIM profile removed - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                }
                catch {
                    $LogQueue.Enqueue(('{0} [WARNING] CIM remove failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))
                }

                if ([System.IO.Directory]::Exists($userPath)) {
                    try {
                        $tempEmpty = Join-Path $env:TEMP "EmptyFolder"

                        if (-not (Test-Path $tempEmpty)) {
                            New-Item -ItemType Directory -Path $tempEmpty | Out-Null
                        }
                        robocopy $tempEmpty $userPath /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
                        Remove-Item -LiteralPath $userPath -Force -Recurse -ErrorAction SilentlyContinue

                        $LogQueue.Enqueue(('{0} [SUCCESS] Folder removed - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                    }
                    catch {
                        $LogQueue.Enqueue(('{0} [WARNING] Standard folder cleanup failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))

                        try {
                            try {
                                & takeown.exe /F $userPath /R /D S | Out-Null
                            }
                            catch {
                                try {
                                    & takeown.exe /F $userPath /R /D Y | Out-Null
                                }
                                catch {
                                    $LogQueue.Enqueue(('{0} [ERROR] takeown failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))
                                }
                            }
                            & icacls.exe $userPath /grant Administrators:F /T /C | Out-Null
                            Remove-Item -LiteralPath $userPath -Force -Recurse -ErrorAction Stop -Confirm:$false
                            $LogQueue.Enqueue(('{0} [SUCCESS] Folder removed after ACL reset - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                        }
                        catch {
                            $LogQueue.Enqueue(('{0} [ERROR] Cleanup failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))
                        }
                    }
                }

                $success = -not [System.IO.Directory]::Exists($userPath)
                $duration = New-TimeSpan -Start $start -End (Get-Date)

                if ($success) {
                    $LogQueue.Enqueue(('{0} [SUCCESS] COMPLETED PROFILE - {1} - {2:hh\:mm\:ss}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $duration))
                }
                else {
                    $LogQueue.Enqueue(('{0} [ERROR] FAILED PROFILE - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                }

                return [PSCustomObject]@{
                    Type     = 'Profile'
                    UserName = $userName
                    Path     = $userPath
                    Success  = $success
                    Duration = $duration
                }
            }

            try {
                foreach ($profile in $Profiles) {
                    $ps = [PowerShell]::Create()
                    $ps.RunspacePool = $pool

                    [void]$ps.AddScript($scriptBlock, $true).
                        AddArgument($profile).
                        AddArgument($script:LogQueue)

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
                        Write-Progress -Activity (Get-Loc 'toolText.extra.removingRegisteredProfiles') -Status (Get-Loc 'toolText.extra.01Completed' -Args @($completed, $total)) -PercentComplete $percent
                    }

                    Start-Sleep -Milliseconds 500
                } while ($completed -lt $total)

                Write-Progress -Activity (Get-Loc 'toolText.extra.removingRegisteredProfiles') -Completed

                $results = foreach ($job in $jobs) {
                    try {
                        $job.PowerShell.EndInvoke($job.Handle)
                    }
                    catch {
                        Add-ProfileCleanupLog -Level 'ERROR' -Text (Get-Loc 'toolText.runspaceError0' -Args @($($_.Exception.Message)))
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

            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.checkResidualFoldersInTheUsersDirectory')

            $folders = Get-ChildItem -Path $UsersRoot -Directory -Force |
                Where-Object {
                    -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
                }

            foreach ($folder in $folders) {
                $folderName = $folder.Name
                $folderPath = [System.IO.Path]::GetFullPath($folder.FullName).TrimEnd('\')

                if ($excluded.Contains($folderName)) {
                    Add-ProfileCleanupLog -Text (Get-Loc 'toolText.residualFolderExcludedForProtectedName01' -Args @($folderName, $folderPath))
                    continue
                }

                if ($registeredProfilePaths.Contains($folderPath)) {
                    Add-ProfileCleanupLog -Text (Get-Loc 'toolText.residualFolderExcludedBecauseItIsStillAssociatedWithWin32Userprofile01' -Args @($folderName, $folderPath))
                    continue
                }

                if ($folder.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                    Add-ProfileCleanupLog -Level 'WARNING' -Text (Get-Loc 'toolText.residualFolderExcludedBecauseReparsePointSymlink01' -Args @($folderName, $folderPath))
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

                Write-Progress `
                    -Activity (Get-Loc 'toolText.extra.removingResidualFoldersInCUsers') `
                    -Status ("{0} / {1} - {2}" -f $index, $total, $folder.Name) `
                    -PercentComplete $percent

                $start = Get-Date
                $success = $false

                Add-ProfileCleanupLog -Text (Get-Loc 'toolText.startResidualFolder01' -Args @($($folder.Name), $($folder.Path)))

                $folderPath = $folder.Path

                try {
                    Remove-Item -LiteralPath $folderPath -Force -Recurse -ErrorAction Stop -Confirm:$false
                    $success = -not [System.IO.Directory]::Exists($folderPath)
                }
                catch {
                    Add-ProfileCleanupLog -Level 'WARNING' -Text (Get-Loc 'toolText.standardResidualFolderRemovalFailed01' -Args @($folderPath, $($_.Exception.Message)))

                    try {
                        & takeown.exe /F $folderPath /R /D Y | Out-Null
                        & icacls.exe $folderPath /grant Administrators:F /T /C | Out-Null
                        Remove-Item -LiteralPath $folderPath -Force -Recurse -ErrorAction Stop -Confirm:$false
                        $success = -not [System.IO.Directory]::Exists($folderPath)
                    }
                    catch {
                        Add-ProfileCleanupLog -Level 'ERROR' -Text (Get-Loc 'toolText.remnantFolderRemovalFailed01' -Args @($folderPath, $($_.Exception.Message)))
                        $success = $false
                    }
                }

                $duration = New-TimeSpan -Start $start -End (Get-Date)

                if ($success) {
                    Add-ProfileCleanupLog -Level 'SUCCESS' -Text (Get-Loc 'toolText.completedResidualFolder01' -Args @($($folder.Name), $($duration.ToString())))
                }
                else {
                    Add-ProfileCleanupLog -Level 'ERROR' -Text (Get-Loc 'toolText.failedResidualFolder0' -Args @($($folder.Name)))
                }

                $results.Add([PSCustomObject]@{
                    Type     = 'ResidualFolder'
                    UserName = $folder.Name
                    Path     = $folder.Path
                    Success  = $success
                    Duration = $duration
                }) | Out-Null
            }

            Write-Progress -Activity (Get-Loc 'toolText.extra.removingResidualFoldersInCUsers') -Completed

            return $results
        }


        function Save-ProfileCleanupLog {
            $logLines = [System.Collections.Generic.List[string]]::new()
            $line = $null

            while ($script:LogQueue.TryDequeue([ref]$line)) {
                $logLines.Add($line)
            }

            $logLines | Set-Content -LiteralPath $script:LogFile -Encoding UTF8
        }

        try {
            Initialize-ProfileCleanupSession

            $profileResults = @()
            $residualResults = @()

            $targets = @(Get-RemovableUserProfiles)

            if ($targets -and $targets.Count -gt 0) {
                Show-ProfileCleanupPreview -Profiles $targets

                Write-Host ''
                Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.startAutomaticRemovalOf0RegisteredProfiles' -Args @($targets.Count))
                Write-Host ''

                $profileResults = @(Invoke-ProfileRemovalBatch -Profiles $targets)
            }
            else {
                Write-Host ''
                Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.noRemovableRegisteredProfilesFound')
                Add-ProfileCleanupLog -Level 'SUCCESS' -Text (Get-Loc 'toolText.noRemovableRegisteredProfilesFound2')
            }

            if (-not $SkipResidualFolderCleanup) {
                $residualFolders = @(Get-ResidualUserFolders)

                if ($residualFolders -and $residualFolders.Count -gt 0) {
                    Write-Host ''
                    Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.residualFoldersSelectedForAutomaticRemoval0' -Args @($residualFolders.Count))
                    $residualFolders | Select-Object Name, Path | Format-Table -AutoSize

                    Write-Host ''
                    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.startingRemovalOfResidualFolders')
                    Write-Host ''

                    $residualResults = @(Remove-ResidualUserFolders -Folders $residualFolders)
                }
                else {
                    Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.noRemovableResidualFolderFoundInCUsers')
                    Add-ProfileCleanupLog -Level 'SUCCESS' -Text (Get-Loc 'toolText.noRemovableResidualFoldersFound')
                }
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.residualFolderCleanupSkippedForSkipresidualfoldercleanupParameter')
                Add-ProfileCleanupLog -Level 'WARNING' -Text (Get-Loc 'toolText.remainingFolderCleanupSkipped')
            }

            $allResults = @($profileResults) + @($residualResults)
            $successCount = @($allResults | Where-Object { $_.Success }).Count
            $failedCount = @($allResults | Where-Object { -not $_.Success }).Count
            $profileSuccessCount = @($profileResults | Where-Object { $_.Success }).Count
            $residualSuccessCount = @($residualResults | Where-Object { $_.Success }).Count

            if ($failedCount -gt 0) {
                Set-ProfileCleanupRebootRecommended -Reason (Get-Loc 'toolText.0ItemsNotRemovedMayBeBlockedByOpenSessionsOrHandles' -Args @($failedCount))
            }

            $script:SessionEnd = Get-Date
            $totalDuration = New-TimeSpan -Start $script:SessionStart -End $script:SessionEnd

            Add-ProfileCleanupLog -Level 'INFO' -Text (Get-Loc 'toolText.sessionCompletedProfilesRemoved0ResidualFoldersRemoved1Errors2Duration3' -Args @($profileSuccessCount, $residualSuccessCount, $failedCount, $totalDuration))
            Save-ProfileCleanupLog

            Write-Host ''
            Write-Host '====================================================' -ForegroundColor Green
            $completionText = (Get-Loc 'sourceText.completed').ToUpperInvariant()
            Write-Host $completionText
            Write-Host '====================================================' -ForegroundColor Green
            Write-Host ''
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.registeredProfilesRemoved0' -Args @($profileSuccessCount))
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.residualFoldersRemoved0' -Args @($residualSuccessCount))
            if ($failedCount -gt 0) {
                Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.itemsNotRemoved0' -Args @($failedCount))
            }
            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'uiText.duration0' -Args @($totalDuration))
            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.log0' -Args @($script:LogFile))

            Invoke-ProfileCleanupReboot
        }
        catch {
            Add-ProfileCleanupLog -Level 'ERROR' -Text $_.Exception.Message
            try { Save-ProfileCleanupLog } catch { }
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.error0' -Args @($_.Exception.Message))
            throw
        }
        finally {
            $ErrorActionPreference = $savedErrorActionPreference
            $ProgressPreference = $savedProgressPreference
            $ConfirmPreference = $savedConfirmPreference
        }
    }
}
