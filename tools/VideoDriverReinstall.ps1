function VideoDriverReinstall {
    <#
    .SYNOPSIS
        Reinstalls or repairs video drivers with DDU in Safe Mode.
        Downloads DDU and the detected driver installer to the Desktop, then restarts in Safe Mode.
    .PARAMETER CountdownSeconds
        Number of seconds in the countdown before restarting.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "VideoDriverReinstall" -SubTitle (Get-Loc 'script.VideoDriverReinstall')

    $driverToolsPath = $AppConfig.Paths.Drivers
    $desktopPath     = $AppConfig.Paths.Desktop

    function Set-BlockWindowsUpdateDrivers {
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.blockingAutomaticDriversFromWindowsUpdate')
        try {
            Set-RegistryValue -Path $AppConfig.Registry.WindowsUpdatePolicies -Name "ExcludeWUDriversInQualityUpdate" -Value 1
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.driverWuLockSet')
            $gpupdateResult = Invoke-WithSpinner -Activity (Get-Loc 'toolText.extra.groupPolicyUpdateMayTake12Minutes') -Command 'gpupdate.exe' -Arguments '/force' -LogContextKey "Video-GPUpdate" -TimeoutSeconds 180
            if ($gpupdateResult -and $gpupdateResult.ExitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.updatedGroupPolicy')
            }
            elseif ($gpupdateResult) {
                Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.gpupdateCompletedWithCode0IContinueAnyway' -Args @($($gpupdateResult.ExitCode)))
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.gpupdateDidNotRespondIContinueAnyway')
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.driverWuBlockError0IContinueAnyway' -Args @($($_.Exception.Message)))
        }
    }

    $needsReboot = $false

    try {
        Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.startingVideoDriverReinstallationRepairProcedure')
        Set-BlockWindowsUpdateDrivers
        
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.preparingToDownloadTheNecessaryTools')
        # Download e estrazione DDU
        $dduZipPath = Join-Path $driverToolsPath "DDU.zip"
        if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.DDUZip -OutputPath $dduZipPath -Description 'DDU (Display Driver Uninstaller)')) {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.unableToDownloadDduAnnulment')
            return
        }

        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.extractingDduToDesktop')
        try {
            Expand-Archive -Path $dduZipPath -DestinationPath $desktopPath -Force
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.dduExtractedToDesktop')
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.dduExtractionError0' -Args @($($_.Exception.Message)))
            return
        }

        # Download installer driver rilevato (sul Desktop per uso in Safe Mode)
        $gpuAnalysis = VcardAnalizer
        $gpuManufacturer = $gpuAnalysis.PrimaryManufacturer
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.gpuDetected0' -Args @($gpuManufacturer))

        $stableDownloadDone = $false
        if ($gpuAnalysis.Matches.Count -gt 0) {
            foreach ($match in $gpuAnalysis.Matches) {
                if ([string]::IsNullOrWhiteSpace($match.DownloadUrl)) { continue }
                $targetName = if (-not [string]::IsNullOrWhiteSpace($match.FileName)) { $match.FileName } else { "$($match.Key).exe" }
                $targetPath = Join-Path $desktopPath $targetName
                $displayName = if (-not [string]::IsNullOrWhiteSpace($match.DisplayName)) { $match.DisplayName } else { $match.Key }

                if (Invoke-ToolkitDownload -Uri $match.DownloadUrl -OutputPath $targetPath -Description $displayName) {
                    Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.stableDriverDownloadedToDesktop0' -Args @($displayName))
                    $stableDownloadDone = $true
                }
            }
        }

        if (-not $stableDownloadDone) {
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.noKnownStableDriversFoundIUseAutodetectFallback')
            switch ($gpuManufacturer) {
                'AMD' {
                    $amdPath = Join-Path $desktopPath "AMD-Autodetect.exe"
                    if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.AMDInstaller -OutputPath $amdPath -Description "AMD Auto-Detect Tool")) {
                        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.unableToDownloadAmdInstallerAnnulment')
                        return
                    }
                }
                'NVIDIA' {
                    $nvidiaPath = Join-Path $desktopPath "NVCleanstall_1.19.0.exe"
                    if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.NVCleanstall -OutputPath $nvidiaPath -Description "NVCleanstall")) {
                        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.unableToDownloadNvcleanstallAnnulment')
                        return
                    }
                }
                'Intel' {
                    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.intelGpuDownloadDriversManuallyFromIntelIfNecessary')
                }
                default {
                    Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.gpuNotDetectedOnlyDduWillBePlacedOnTheDesktop')
                }
            }
        }

        # Batch to return to normal mode after DDU
        $batchPath = Join-Path $desktopPath "Switch to Normal Mode.bat"
        try {
            Set-Content -Path $batchPath -Value 'bcdedit /deletevalue {current} safeboot' -Encoding ASCII
            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.batchSwitchToNormalModeBatCreatedOnDesktop')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.failedToCreateSafeModeBatch0' -Args @($($_.Exception.Message)))
        }

        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.warningTheSystemWillRebootIntoSafeMode')
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.inSafeModeRunDduToCleanTheDriversThenReinstallWithTheDesktopInstallerFinallyUseBatchToRetu')

        # Configura Safe Mode per il prossimo avvio
        try {
            $null = Invoke-WithSpinner -Activity (Get-Loc 'toolText.extra.safeModeConfigurationBcdedit') -Command 'bcdedit.exe' `
                -Arguments '/set {current} safeboot minimal' -LogContextKey "Video-BCDEdit"
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.safeModeConfiguredForNextBoot')
            $needsReboot = $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.safeModeConfigurationError0' -Args @($($_.Exception.Message)))
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.criticalErrorDuringDriverReinstallation0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-Loc 'toolText.errorInVideodriverreinstall') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.videoDriverReinstallFinished')
        Write-ToolkitLog -Level INFO -Message (Get-Loc 'toolText.videodriverreinstallSessionEnded')
    }

    if ($needsReboot) {
        Invoke-ToolkitReboot -Message (Get-Loc 'toolText.extra.restartInSafeModeForDdu') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
