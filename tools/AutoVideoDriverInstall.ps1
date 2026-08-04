function AutoVideoDriverInstall {
    <#
    .SYNOPSIS
        Automatically installs video drivers after detecting the GPU vendor (AMD/NVIDIA/Intel).
    .PARAMETER CountdownSeconds
        Number of seconds in the countdown before restarting.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "AutoVideoDriverInstall" -SubTitle (Get-Loc 'script.AutoVideoDriverInstall')

    $desktopPath = $AppConfig.Paths.Desktop

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

    try {
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.startingAutomaticVideoDriverInstallation')
        Set-BlockWindowsUpdateDrivers
        
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.detectingGpuConfiguration')
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
                    Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.gpuNotDetectedDriverNotAvailableForAutomaticInstallation')
                }
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorDuringDriverInstallation0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-Loc 'toolText.errorInAutovideodriverinstall') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.autoVideoDriverInstallFinished')
        Write-ToolkitLog -Level INFO -Message (Get-Loc 'toolText.autovideodriverinstallSessionEnded')
    }
}
