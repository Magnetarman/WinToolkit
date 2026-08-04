function Uninstall-Office {
    <#
    .SYNOPSIS
        Completely removes Microsoft Office. Uses Get Help on Windows 11 23H2+ and direct removal on earlier versions.
    .PARAMETER CountdownSeconds
        Number of seconds in the countdown before restarting.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "OfficeUninstall" -SubTitle (Get-Loc 'script.Uninstall-Office')

    $tempDir = $AppConfig.Paths.OfficeTemp

    # ============================================================================
    # FUNZIONI HELPER SPECIFICHE PER UNINSTALL
    # ============================================================================

    function Get-WindowsVersion {
        try {
            $buildNumber = [int](Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
            if ($buildNumber -ge 22631) { return "Windows11_23H2_Plus" }
            if ($buildNumber -ge 22000) { return "Windows11_22H2_Or_Older" }
            return "Windows10_Or_Older"
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.unableToDetectWindowsVersion0' -Args @($_))
            return "Unknown"
        }
    }

    function Remove-ItemsSilently {
        param([string[]]$Paths, [string]$ItemType = "folder")
        $removed = @()
        $failed  = @()
        foreach ($path in $Paths) {
            if (Test-Path $path) {
                if (Remove-ItemSafely -Path $path -Recurse) { $removed += $path }
                else { $failed += $path }
            }
        }
        return @{ Removed = $removed; Failed = $failed; Count = $removed.Count }
    }

    # ============================================================================
    # METODI DI RIMOZIONE
    # ============================================================================

    function Remove-OfficeDirectly {
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.startingOfficeDirectRemoval')

        try {
            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.searchForOfficeInstallations')
            $officePackages = Get-Package -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*Microsoft Office*" -or $_.Name -like "*Microsoft 365*" -or $_.Name -like "*Office*" }

            if ($officePackages) {
                Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.found0OfficePackages' -Args @($($officePackages.Count)))
                foreach ($package in $officePackages) {
                    try {
                        $null = Uninstall-Package -Name $package.Name -Force -ErrorAction Stop
                        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.removed02' -Args @($($package.Name)))
                    }
                    catch {}
                }
            }

            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.searchTheRegistry')
            foreach ($keyPath in @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )) {
                try {
                    $items = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue |
                        Where-Object { $_.DisplayName -like "*Office*" -or $_.DisplayName -like "*Microsoft 365*" }
                    foreach ($item in $items) {
                        if ($item.UninstallString -and $item.UninstallString -match "msiexec") {
                            try {
                                $null = Invoke-WithSpinner -Activity (Get-Loc 'toolText.extra.removal0' -Args @($($item.DisplayName))) -Command 'msiexec.exe' `
                                    -Arguments @('/x', $item.PSChildName, '/qn', '/norestart') -TimeoutSeconds 1800 `
                                    -LogContextKey "Office-Uninstall-MSI-$($item.PSChildName)"
                            }
                            catch {}
                        }
                    }
                }
                catch {}
            }

            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.stoppingOfficeServices')
            $stoppedServices = 0
            foreach ($serviceName in @('ClickToRunSvc', 'OfficeSvc', 'OSE')) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    try {
                        Stop-Service  -Name $serviceName -Force -ErrorAction Stop
                        Set-Service   -Name $serviceName -StartupType Disabled -ErrorAction Stop
                        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.serviceStopped0' -Args @($serviceName))
                        $stoppedServices++
                    }
                    catch {}
                }
            }

            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.officeFolderCleaning')
            $folderResult = Remove-ItemsSilently -Paths @(
                "$env:ProgramFiles\Microsoft Office",
                "${env:ProgramFiles(x86)}\Microsoft Office",
                "$env:ProgramFiles\Microsoft Office 15",
                "${env:ProgramFiles(x86)}\Microsoft Office 15",
                "$env:ProgramFiles\Microsoft Office 16",
                "${env:ProgramFiles(x86)}\Microsoft Office 16",
                "$env:ProgramData\Microsoft\Office",
                "$env:LOCALAPPDATA\Microsoft\Office",
                "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun",
                "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun"
            ) -ItemType "folder"
            if ($folderResult.Count -gt 0)        { Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.0OfficeFoldersRemoved' -Args @($($folderResult.Count))) }
            if ($folderResult.Failed.Count -gt 0)  { Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.unableToRemove0FoldersMayBeInUse' -Args @($($folderResult.Failed.Count))) }

            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.officeRegistryCleaner')
            $regResult = Remove-ItemsSilently -Paths @(
                "HKCU:\Software\Microsoft\Office",
                "HKLM:\SOFTWARE\Microsoft\Office",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office",
                "HKCU:\Software\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun"
            ) -ItemType "registry key"
            if ($regResult.Count -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.0OfficeRegistryKeysRemoved' -Args @($($regResult.Count))) }

            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.cleaningScheduledTasks')
            $tasksRemoved = 0
            try {
                $officeTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*Office*" }
                foreach ($task in $officeTasks) {
                    try { Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop; $tasksRemoved++ }
                    catch {}
                }
                if ($tasksRemoved -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.0OfficeTasksRemoved' -Args @($tasksRemoved)) }
            }
            catch {}

            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.removingOfficeLinks')
            $shortcutsRemoved = 0
            foreach ($desktopPath in @(
                $AppConfig.Paths.Desktop,
                "$env:PUBLIC\Desktop",
                "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs"
            )) {
                if (Test-Path $desktopPath) {
                    foreach ($shortcut in @(
                        "Microsoft Word*.lnk", "Microsoft Excel*.lnk", "Microsoft PowerPoint*.lnk",
                        "Microsoft Outlook*.lnk", "Microsoft OneNote*.lnk", "Microsoft Access*.lnk",
                        "Office*.lnk", "Word*.lnk", "Excel*.lnk", "PowerPoint*.lnk", "Outlook*.lnk"
                    )) {
                        foreach ($file in (Get-ChildItem -Path $desktopPath -Filter $shortcut -Recurse -ErrorAction SilentlyContinue)) {
                            if (Remove-ItemSafely -Path $file.FullName) { $shortcutsRemoved++ }
                        }
                    }
                }
            }
            if ($shortcutsRemoved -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.0OfficeLinksRemoved' -Args @($shortcutsRemoved)) }

            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.officeResidueCleaning')
            $null = Remove-ItemsSilently -Paths @(
                "$env:LOCALAPPDATA\Microsoft\OneDrive",
                "$env:APPDATA\Microsoft\OneDrive",
                "$env:TEMP\Office*",
                "$env:TEMP\MSO*"
            ) -ItemType "residuo"

            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.directRemovalCompleted')
            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.summary0Folders1RegistryKeys2Links3TasksRemoved' -Args @($($folderResult.Count), $($regResult.Count), $shortcutsRemoved, $tasksRemoved))
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorWhileDirectlyRemovingOffice0' -Args @($($_.Exception.Message)))
            return $false
        }
    }

    function Start-OfficeUninstallWithGetHelp {
        try {
            if (-not (Test-Path $tempDir)) { $null = New-Item -ItemType Directory -Path $tempDir -Force }

            $getHelpZipPath = Join-Path $tempDir 'GetHelp.zip'
            if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.GetHelpInstaller -OutputPath $getHelpZipPath -Description 'Microsoft Get Help')) {
                return $false
            }

            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.extractionGetHelp')
            try {
                Expand-Archive -Path $getHelpZipPath -DestinationPath $tempDir -Force
                Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.extractionCompleted')
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorExtractingArchiveGetHelp0' -Args @($($_.Exception.Message)))
                return $false
            }

            $getHelpExe = Get-ChildItem -Path $tempDir -Filter "GetHelpCmd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $getHelpExe) {
                Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.gethelpcmdExeNotFound')
                return $false
            }

            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.removalViaGetHelp')
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.thisOperationMayTakeAFewMinutes')

            try {
                $result = Invoke-WithSpinner -Activity (Get-Loc 'toolText.extra.removingOfficeUsingGetHelp') -Command $getHelpExe.FullName `
                    -Arguments '-S OfficeScrubScenario -AcceptEula' `
                    -TimeoutSeconds 86400 -LogContextKey "Office-Uninstall-GetHelp"

                $outputStr    = $result.StdOut + $result.StdErr
                $isInvalidArgs = $outputStr -match "Error: Invalid command line arguments" -or $outputStr -match "Usage: GetHelpCmd\.exe"

                if ($result.ExitCode -eq 0 -and -not $isInvalidArgs) {
                    $blockingProcesses = @('Setup', 'GetHelpCmd', 'OfficeClickToRun', 'Integrator', 'OfficeScrub', 'cscript')
                    $waitStart         = Get-Date
                    Start-Sleep -Seconds 12

                    if (Get-Process -Name $blockingProcesses -ErrorAction SilentlyContinue) {
                        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.getHelpStartedTheRemovalInAnExternalWindowWaitingForCompletion')
                        $spinnerIndex = 0
                        while ((Get-Process -Name $blockingProcesses -ErrorAction SilentlyContinue) -and ((Get-Date) - $waitStart).TotalSeconds -lt 2700) {
                            $elapsed = [math]::Round(((Get-Date) - $waitStart).TotalSeconds, 1)
                            $spinner = if ($Global:Spinners) { $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length] } else { '' }
                            Write-ProgressUpdate -Activity (Get-Loc 'toolText.removingOffice') -Status (Get-Loc 'toolText.inProgress0Seconds' -Args @($elapsed)) -Percent 90 -Icon '⏳' -Spinner $spinner
                            Start-Sleep -Milliseconds 500
                        }
                        Clear-ProgressLine
                    }

                    Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.getHelpCompletedSuccessfully')
                    return $true
                }
                else {
                    $reason = if ($isInvalidArgs) { 'Parameters not supported by the tool version' } else { "Exit code: $($result.ExitCode)" }
                    Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.getHelpFailed0AttemptedAlternativeMethod' -Args @($reason))
                    return Remove-OfficeDirectly
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.errorRunningGetHelp0SwitchingToAlternativeMethod' -Args @($($_.Exception.Message)))
                return Remove-OfficeDirectly
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.errorDuringGetHelpProcess0' -Args @($($_.Exception.Message)))
            return $false
        }
        finally {
            Remove-ItemSafely -Path $tempDir -Recurse
        }
    }

    # ============================================================================
    # ESECUZIONE PRINCIPALE
    # ============================================================================

    $needsReboot = $false

    try {
        Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.startingCompleteMicrosoftOfficeRemoval')
        Stop-ToolkitProcesses -ProcessNames @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')

        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.windowsVersionDetection')
        $windowsVersion = Get-WindowsVersion
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.versionDetected0' -Args @($windowsVersion))

        $success = switch ($windowsVersion) {
            'Windows11_23H2_Plus' {
                Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.usingGetHelpMethodForWindows1123h2')
                Start-OfficeUninstallWithGetHelp
            }
            default {
                Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.usingDirectRemovalForWindows1122h2OrEarlier')
                Remove-OfficeDirectly
            }
        }

        $removalProgressText = Get-Loc 'sourceText.removal'
        Write-Progress -Activity $removalProgressText -Completed -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Host ""

        if ($success) {
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.officeRemovalComplete')
            $needsReboot = $true
        }
        else {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.removalNotCompleted')
            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.youCanTryAnAlternativeMethodOrManualRemoval')
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.criticalErrorWhileRemovingOffice0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-Loc 'toolText.criticalErrorInUninstallOffice') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.finalCleaning')
        Remove-ItemSafely -Path $tempDir -Recurse
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.officeUninstallFinished')
        Write-ToolkitLog -Level INFO -Message (Get-Loc 'toolText.uninstallOfficeSessionEnded')
    }

    if ($needsReboot) {
        Invoke-ToolkitReboot -Message (Get-Loc 'toolText.extra.removalCompleted') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
