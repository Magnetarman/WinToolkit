function WinRepairToolkit {
    <#
    .SYNOPSIS
        Runs standard Windows repairs (SFC, DISM, and Chkdsk) and saves Scannow logs in the toolkit folder for additional debugging.
    #>
    [CmdletBinding()]
    param(
        [int]$MaxRetryAttempts = 3,
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "WinRepairToolkit" -SubTitle (Get-SourceTextLoc 'script.WinRepairToolkit')

    $script:CurrentAttempt = 0

    $sysInfo = Get-SystemInfo

    $RepairTools = @(
        @{ Tool = 'chkdsk'; Args = @('/scan', '/perf'); Name = 'Disk check'; NameKey = 'toolText.extra.diskCheck'; Icon = '💽' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'System File Checker (1)'; NameKey = 'toolText.extra.systemFileChecker1'; Icon = '🗂️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Name = 'Windows Image Recovery'; NameKey = 'toolText.extra.windowsImageRecovery'; Icon = '🛠️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'); Name = 'Remnant Cleanup Updates'; NameKey = 'toolText.extra.remnantCleanupUpdates'; Icon = '🕸️' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'System File Checker (2)'; NameKey = 'toolText.extra.systemFileChecker2'; Icon = '🗂️' }
        @{ Tool = 'chkdsk'; Args = @('/f', '/r', '/x'); Name = 'Thorough disk check'; NameKey = 'toolText.extra.thoroughDiskCheck'; Icon = '💽'; IsCritical = $false }
    )

    function Invoke-RepairCommand {
        param([hashtable]$Config, [int]$Step, [int]$Total)

        $displayName = Get-SourceTextLoc $Config.NameKey
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.01Starting2' -Args @($Step, $Total, $displayName))
        $isChkdsk = ($Config.Tool -ieq 'chkdsk')
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()

        try {
            $processTimeoutSeconds = 600

            switch ($Config.Name) {
                'Windows Image Recovery'   { $processTimeoutSeconds = 10800 }
                'System File Checker (1)' { $processTimeoutSeconds = 3600 }
                'System File Checker (2)' { $processTimeoutSeconds = 10800 }
                'Remnant Cleanup Updates' { $processTimeoutSeconds = 3600 }
                'Disk check' { $processTimeoutSeconds = 900 }
                'Thorough disk check'  { $processTimeoutSeconds = 3600 }
            }
            $spinnerUpdateInterval = if ($Config.Name -eq 'Windows Image Recovery') { 900 } else { 600 }

            if ($Config.Tool -ieq 'DISM' -and $Config.Args -contains '/StartComponentCleanup') {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.cleaningWindowsUpdateStatusBeforeStartingCleanup')
                Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                Start-Sleep 1
                Remove-ItemSafely -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\SessionsPending' -Recurse
                Start-Sleep 1
            }

            $commandToRun = $Config.Tool
            $argsToRun = $Config.Args
            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
                $drive = $Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1
                if ($null -eq $drive) { $drive = $env:SystemDrive }
                $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }
                $commandToRun = 'cmd.exe'
                $argsToRun = @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ')")
            }

            $spinnerResult = Invoke-WithSpinner -Activity $displayName `
                -Command $commandToRun `
                -Arguments $argsToRun `
                -TimeoutSeconds $processTimeoutSeconds `
                -UpdateInterval $spinnerUpdateInterval `
                -LogContextKey "Repair-$($Config.Tool)"

            $exitCode = $spinnerResult.ExitCode
            $results = ($spinnerResult.StdOut + "`n" + $spinnerResult.StdErr) -split "`n"

            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r') -and ($results -join ' ').ToLower() -match 'schedule|next time.*restart|volume.*in use') {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0CheckScheduledAtNextReboot' -Args @($displayName))
                return @{ Success = $true; ErrorCount = 0 }
            }

            $isTimeout = ($spinnerResult.TimedOut -eq $true) -or ($null -eq $exitCode) -or ($exitCode -eq -1)

            if ($isChkdsk -and $exitCode -eq 3) {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0CheckScheduledAtNextReboot' -Args @($displayName))
                return @{ Success = $true; ErrorCount = 0 }
            }

            if (($Config.Tool -ieq 'DISM') -and ($results -match '0x800f0806')) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Error0x800f0806PendingOperationsThisIsNotACriticalError' -Args @($displayName))
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.rebootTheSystemToCompletePendingOperations')
                return @{ Success = $true; ErrorCount = 0 }
            }

            $hasDismSuccess = (-not $isTimeout) -and ($Config.Tool -ieq 'DISM') -and ($results -match '(?i)completed successfully')

            if (($Config.Tool -ieq 'DISM') -and ($Config.Args -contains '/ResetBase') -and $exitCode -eq 3010) {
                $hasDismSuccess = $true
            }

            $isChkdskScan = $isChkdsk -and ($Config.Args -contains '/scan')
            $chkdskCompleted = (-not $isTimeout) -and $isChkdskScan -and (($results -join ' ') -match '(?i)(scansione.*completata|scan.*completed|successfully scanned)')

            $isSuccess = (-not $isTimeout) -and (($exitCode -eq 0) -or $exitCode -eq 3010 -or $hasDismSuccess -or $chkdskCompleted)

            $errors = $warnings = @()
            if (-not $isSuccess) {
                if ($isTimeout) {
                    $errors += Get-SourceTextLoc 'uiText.repairOperationTimedOut'
                }

                foreach ($line in ($results | Where-Object { $_ -and ![string]::IsNullOrWhiteSpace($_.Trim()) })) {
                    $trim = $line.Trim()
                    if ($trim -match '^\[=+\s*\d+' -or $trim -match '(?i)version:|deployment image') { continue }

                    if ($isChkdsk) {
                        if ($trim -match '(?i)(stage|fase|percent complete|verificat|scanned|scanning|errors found.*corrected|volume label)') { continue }
                        if ($trim -match '(?i)(cannot|unable to|access denied|critical|fatal|corrupt file system|bad sectors)') {
                            $errors += $trim
                        }
                    }
                    else {
                        if ($trim -match '0x800f0806') {
                            # gestito separatamente
                        }
                        elseif ($trim -match '(?i)(errore|error|failed|impossibile|corrotto|corruption)') { $errors += $trim }
                        elseif ($trim -match '(?i)(warning|avviso|attenzione)') { $warnings += $trim }
                    }
                }

                if ($errors.Count -eq 0 -and -not $isTimeout) {
                    $errors += "Generic error or abend (ExitCode: $exitCode)."
                }
            }

            $success = $isSuccess -and ($errors.Count -eq 0)

            if ($isTimeout) {
                $message = Get-SourceTextLoc 'toolText.extra.0NotCompletedAbortedDueToTimeout' -Args @($displayName)
            }
            else {
                $message = if ($success) {
                    Get-SourceTextLoc 'toolText.extra3.0CompletedSuccessfully' -Args @($displayName)
                }
                else {
                    Get-SourceTextLoc 'toolText.extra3.0CompletedWith1Errors' -Args @($displayName, $errors.Count)
                }
            }
            Write-StyledMessage -Type 'Success' -Text $message

            if ($Config.Tool -ieq 'sfc') {
                $cbsLogPath = "C:\Windows\Logs\CBS\CBS.log"
                if (Test-Path $cbsLogPath) {
                    try {
                        $safeStepName = $Config.Name -replace '[^a-zA-Z0-9]', '_'
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                        $destLogName = "SFC_CBS_${safeStepName}_${timestamp}.log"
                        $destLogPath = Join-Path $AppConfig.Paths.Logs $destLogName
                        Copy-Item -Path $cbsLogPath -Destination $destLogPath -Force -ErrorAction SilentlyContinue
                        if (Test-Path $destLogPath) {
                            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.sfcLogSavedIn0' -Args @($destLogName))
                        }
                    }
                    catch {
                        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.failedToExportSfcCbsLogFileInUse')
                    }
                }
            }

            return @{ Success = $success; ErrorCount = $errors.Count }
        }
        catch {
            Write-ToolkitError -Record $_ -ToolName "WinRepairToolkit" -Message (Get-SourceTextLoc 'toolText.extra.errorInInvokeRepaircommand0' -Args @($($Config.Tool)))
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Start-RepairCycle {
        param([int]$Attempt = 1)

        $script:CurrentAttempt = $Attempt
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.attempting01SystemRepair' -Args @($Attempt, $MaxRetryAttempts))

        $totalErrors = $successCount = 0
        for ($toolIndex = 0; $toolIndex -lt $RepairTools.Count; $toolIndex++) {
            $result = Invoke-RepairCommand -Config $RepairTools[$toolIndex] -Step ($toolIndex + 1) -Total $RepairTools.Count
            if ($result.Success) { $successCount++ }
            if (!$result.Success -and !($RepairTools[$toolIndex].ContainsKey('IsCritical') -and !$RepairTools[$toolIndex].IsCritical)) {
                $totalErrors += $result.ErrorCount
            }
            Start-Sleep 1
        }

        if ($totalErrors -gt 0 -and $Attempt -lt $MaxRetryAttempts) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0ErrorsDetectedNewAttempt' -Args @($totalErrors))
            Start-Sleep 3
            return Start-RepairCycle -Attempt ($Attempt + 1)
        }
        return @{ Success = ($totalErrors -eq 0); TotalErrors = $totalErrors; AttemptsUsed = $Attempt }
    }

    function Start-DeepDiskRepair {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startDeepRepairOfDiskCOnNextReboot')
        try {
            $fsutilResult = Invoke-ExternalCommandWithLog -Command 'fsutil.exe' -Arguments @('dirty', 'set', 'C:') -TimeoutSeconds 300 -LogContextKey 'DeepDiskRepair-Fsutil'
            if (-not $fsutilResult.Success) {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToMarkDiskDirtyFsutil')
                return $false
            }

            $chkdskResult = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'echo Y | chkdsk C: /f /r /v /x /b') -TimeoutSeconds 7200 -LogContextKey 'DeepDiskRepair-Chkdsk'
            if (-not $chkdskResult.Success) {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorSchedulingChkdskForDeepRepair')
                return $false
            }

            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.chkdskCommandSentRebootToPerformDeepDiskRepair')
            return $true
        }
        catch {
            Write-ToolkitError -Record $_ -ToolName "WinRepairToolkit" -Message (Get-SourceTextLoc 'uiText.exceptionInStartDeepdiskrepair')
            return $false
        }
    }

    function Test-PendingOperations {
        $pendingRebootKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
            'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
        )

        foreach ($key in $pendingRebootKeys) {
            if (Test-Path $key) {
                $values = Get-ItemProperty $key -ErrorAction SilentlyContinue
                if ($values -and $values.PSObject.Properties.Count -gt 1) {
                    return $true
                }
            }
        }
        return $false
    }

    if (Test-PendingOperations) {
        Write-ToolkitLog -Level WARNING -Message (Get-SourceTextLoc 'toolText.pendingOperationsRequiringRebootDetectedDismCouldFail') -Context @{
            Tool = 'WinRepairToolkit'
            Step = 'PreExecutionCheck'
        }
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.pendingOperationsRequiringRebootDetectedDismCouldFail')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.restartRecommendedBeforePerformingRepairs')
    }

    try {
        $repairResult = Start-RepairCycle

        $deepRepairScheduled = $false
        if ($repairResult.TotalErrors -gt 0) {
            Write-ToolkitLog -Level WARNING -Message (Get-SourceTextLoc 'toolText.persistentErrorsDetectedStartDeepRepair') -Context @{
                Tool = 'WinRepairToolkit'
                Step = 'RepairCycle'
                TotalErrors = $repairResult.TotalErrors
            }
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.persistentErrorsDetectedStartDeepRepair')
            $deepRepairScheduled = Start-DeepDiskRepair
        }
        else {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.systemHealthyDeepRepairNotNecessary')
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.unlimitedPasswordExpirationSetting')
        $null = Invoke-ExternalCommandWithLog -Command 'net' -Arguments @('accounts', '/maxpwage:unlimited') -TimeoutSeconds 30 -LogContextKey 'Repair-NetAccounts'

        if ($deepRepairScheduled) { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.rebootRequiredForDeepRepair') }

        if ($SuppressIndividualReboot) {
            if ($deepRepairScheduled) {
                $Global:NeedsFinalReboot = $true
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.individualRestartSuppressedAFinalRebootWillBeHandled')
            }
        }
        else {
            if (Start-InterruptibleCountdown $CountdownSeconds 'Automatic restart') {
                Restart-Computer -Force
            }
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinRepairToolkit"
    }
    finally {
        # Cleanup finale se necessario
    }
}
