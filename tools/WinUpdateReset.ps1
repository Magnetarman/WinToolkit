function WinUpdateReset {
    <#
    .SYNOPSIS
        Repairs Windows Update components and resets services, registry settings, and policies to their defaults.
    .DESCRIPTION
        Repairs common Windows Update problems, reinstalls critical components,
        and restores default settings.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "WinUpdateReset" -SubTitle (Get-SourceTextLoc 'script.WinUpdateReset')

    function Set-ServiceStatus {
        param (
            [Parameter(Mandatory = $true)][string]$Name,
            [Parameter(Mandatory = $true)][ValidateSet('Running', 'Stopped')][string]$Status,
            [switch]$Wait,
            [int]$TimeoutSeconds = 10
        )

        $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if (-not $service) { return $false }
        if ($service.Status -eq $Status) { return $true }

        try {
            if ($Status -eq 'Running') { Start-Service -Name $Name -ErrorAction Stop }
            else { Stop-Service -Name $Name -Force -ErrorAction Stop }
        }
        catch { return $false }

        if ($Wait) {
            $timeout = $TimeoutSeconds
            while ((Get-Service -Name $Name -ErrorAction SilentlyContinue).Status -ne $Status -and $timeout -gt 0) {
                Start-Sleep -Seconds 1
                $timeout--
            }
            return ((Get-Service -Name $Name -ErrorAction SilentlyContinue).Status -eq $Status)
        }
        return $true
    }

    function Show-ServiceProgress([string]$Activity, [int]$Current, [int]$Total) {
        Invoke-WithSpinner -Activity $Activity -Timer -Action { Start-Sleep -Milliseconds 200 } -TimeoutSeconds 1 *>$null
    }

    function Manage-Service($serviceName, $action, $config, $currentStep, $totalSteps) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }

            if (-not $service) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Service1NotFoundOnTheSystem' -Args @($serviceIcon, $serviceName))
                return
            }

            switch ($action) {
                'Stop' {
                    Show-ServiceProgress (Get-SourceTextLoc 'toolText.extra3.stopping0' -Args @($serviceName)) $currentStep $totalSteps
                    $success = Set-ServiceStatus -Name $serviceName -Status 'Stopped' -Wait -TimeoutSeconds 10

                    if ($success) {
                        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0Service1Stopped' -Args @($serviceIcon, $serviceName))
                    }
                    else {
                        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0ShuttingDown1TookTooLongOrFailed' -Args @($serviceIcon, $serviceName))
                    }
                }
                'Configure' {
                    Show-ServiceProgress (Get-SourceTextLoc 'toolText.extra3.configuring0' -Args @($serviceName)) $currentStep $totalSteps
                    Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop *>$null
                    $startupTypeText = if ($config.Type -eq 'Automatic') { Get-SourceTextLoc 'sourceText.automatic' } else { Get-SourceTextLoc 'sourceText.manual' }
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0Service1ConfiguredAs2' -Args @($serviceIcon, $serviceName, $startupTypeText))
                }
                'Start' {
                    Show-ServiceProgress (Get-SourceTextLoc 'toolText.extra3.starting0' -Args @($serviceName)) $currentStep $totalSteps

                    Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.waitingForStart0' -Args @($serviceName)) -Timer -Action { Start-Sleep -Milliseconds 200 } -TimeoutSeconds 1 *>$null
                    $success = Set-ServiceStatus -Name $serviceName -Status 'Running' -Wait -TimeoutSeconds 10

                    Clear-ProgressLine

                    if ($success) {
                        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0Service1StartedSuccessfully' -Args @($serviceIcon, ${serviceName}))
                    }
                    else {
                        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Service1StartingOrDelayed' -Args @($serviceIcon, ${serviceName}))
                    }
                }
                'Check' {
                    $status = if ($service.Status -eq 'Running') { '🟢 ' + (Get-SourceTextLoc 'sourceText.active') } else { '🔴 ' + (Get-SourceTextLoc 'sourceText.inactive') }
                    $serviceIcon = if ($null -ne $config.Icon) { $config.Icon } else { '⚙️' }
                    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.01Status2' -Args @($serviceIcon, $serviceName, $status))
                }
            }
        }
        catch {
            $actionText = switch ($action) {
                'Configure' { Get-SourceTextLoc 'sourceText.configure' }
                'Start' { Get-SourceTextLoc 'sourceText.start' }
                'Check' { Get-SourceTextLoc 'sourceText.check' }
                default { $action.ToLower() }
            }
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Unable123' -Args @($serviceIcon, $actionText, $serviceName, $($_.Exception.Message)))
        }
    }

    function Remove-DirectorySafely([string]$path, [string]$displayName) {
        if (-not (Test-Path $path)) {
            Clear-ProgressLine
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.directory0NotPresent' -Args @($displayName))
            return $true
        }

        try {
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue *>$null

            Clear-ProgressLine
            [Console]::Out.Flush()

            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.directory0Deleted' -Args @($displayName))
            return $true
        }
        catch {
            Clear-ProgressLine

            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.attemptFailedILlTryForceDeletion')

            try {
                $tempDir = [System.IO.Path]::GetTempPath() + "empty_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                $null = New-Item -ItemType Directory -Path $tempDir -Force

                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.cleaning0' -Args @($displayName)) -Command 'robocopy.exe' -Arguments @("`"$tempDir`"", "`"$path`"", '/MIR', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/NC') -TimeoutSeconds 300 -LogContextKey 'RemoveDirectorySafely-Robocopy'
                Remove-Item $tempDir -Force -ErrorAction SilentlyContinue *>$null
                Remove-Item $path -Force -ErrorAction SilentlyContinue *>$null

                Clear-ProgressLine
                [Console]::Out.Flush()

                if (-not (Test-Path $path)) {
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.directory0DeletedForcedMethod' -Args @($displayName))
                    return $true
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.directory0PartiallyDeleted' -Args @($displayName))
                    return $false
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.unableToCompletelyDelete0FileInUse' -Args @($displayName))
                return $false
            }
        }
    }

    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.initializingTheWindowsUpdateResetScript')

    Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.loadingForms') -Timer -Action { Start-Sleep 2 } -TimeoutSeconds 2 *>$null

    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startingWindowsUpdateServicesRepair')
    $serviceConfig = @{
        'wuauserv'         = @{ Type = 'Automatic'; Critical = $true; Icon = '🔄'; DisplayName = 'Windows Update' }
        'bits'             = @{ Type = 'Automatic'; Critical = $true; Icon = '📡'; DisplayName = 'Background Intelligent Transfer' }
        'cryptsvc'         = @{ Type = 'Automatic'; Critical = $true; Icon = '🔐'; DisplayName = 'Cryptographic Services' }
        'trustedinstaller' = @{ Type = 'Manual'; Critical = $true; Icon = '🛡️'; DisplayName = 'Windows Modules Installer' }
        'msiserver'        = @{ Type = 'Manual'; Critical = $false; Icon = '📦'; DisplayName = 'Windows Installer' }
    }

    $systemServices = @(
        @{ Name = 'appidsvc'; Icon = '🆔'; Display = 'Application Identity' },
        @{ Name = 'gpsvc'; Icon = '📋'; Display = 'Group Policy Client' },
        @{ Name = 'DcomLaunch'; Icon = '🚀'; Display = 'DCOM Server Process Launcher' },
        @{ Name = 'RpcSs'; Icon = '📞'; Display = 'Remote Procedure Call' },
        @{ Name = 'LanmanServer'; Icon = '🖥️'; Display = 'Server' },
        @{ Name = 'LanmanWorkstation'; Icon = '💻'; Display = 'Workstation' },
        @{ Name = 'EventLog'; Icon = '📄'; Display = 'Windows Event Log' },
        @{ Name = 'mpssvc'; Icon = '🛡️'; Display = 'Windows Defender Firewall' },
        @{ Name = 'WinDefend'; Icon = '🔒'; Display = 'Windows Defender Service' }
    )

    try {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.windowsUpdateServicesStopping')
        $stopServices = @('wuauserv', 'cryptsvc', 'bits', 'msiserver')
        for ($serviceIndex = 0; $serviceIndex -lt $stopServices.Count; $serviceIndex++) {
            Manage-Service $stopServices[$serviceIndex] 'Stop' $serviceConfig[$stopServices[$serviceIndex]] ($serviceIndex + 1) $stopServices.Count
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.cleanupGpcacheCacheAndWsusSettings')

        try {
            if (Test-Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache") {
                Remove-Item "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache" -Recurse -Force -ErrorAction Stop
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.gpcacheCacheDeleted')
            } else {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.gpcacheCacheNotPresent')
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningFailedToDeleteGpcacheCache0' -Args @($($_.Exception.Message)))
        }

        try {
            if (Test-Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate") {
                Remove-Item "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate" -Recurse -Force -ErrorAction Stop
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.wsusSettingsRemoved')
            } else {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.wsusSettingsNotPresent')
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningFailedToRemoveWsusSettings0' -Args @($($_.Exception.Message)))
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.waitingForResourcesToBeReleased')
        Start-Sleep -Seconds 3

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.windowsUpdateServicesReset')
        $criticalServices = $serviceConfig.Keys | Where-Object { $serviceConfig[$_].Critical }
        for ($criticalIndex = 0; $criticalIndex -lt $criticalServices.Count; $criticalIndex++) {
            $serviceName = $criticalServices[$criticalIndex]
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0ServiceProcessing1' -Args @($($serviceConfig[$serviceName].Icon), $serviceName))
            Manage-Service $serviceName 'Configure' $serviceConfig[$serviceName] ($criticalIndex + 1) $criticalServices.Count
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.checkCriticalSystemServices')
        for ($systemIndex = 0; $systemIndex -lt $systemServices.Count; $systemIndex++) {
            $sysService = $systemServices[$systemIndex]
            Manage-Service $sysService.Name 'Check' @{ Icon = $sysService.Icon } ($systemIndex + 1) $systemServices.Count
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.restoringWindowsUpdateRegistryKeys')
        Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.logProcessing') -Timer -Action { Start-Sleep 1 } -TimeoutSeconds 1 *>$null
        try {
            @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update",
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            ) | Where-Object { Test-Path $_ } | ForEach-Object {
                Remove-Item $_ -Recurse -Force -ErrorAction Stop *>$null
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.completed2')
            }
            if (-not @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update", "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate") | Where-Object { Test-Path $_ }) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.completed2')
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.noRegistryKeysToRemove')
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.error')
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorEditingRegistry0' -Args @($($_.Exception.Message)))
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.deletionOfWindowsUpdateComponents')
        $directories = @(
            @{ Path = $AppConfig.Paths.SoftwareDistribution; Name = "SoftwareDistribution" },
            @{ Path = $AppConfig.Paths.Catroot2; Name = "catroot2" },
            @{ Path = Join-Path $AppConfig.Paths.System32 "WaaSMedicSvc.dll"; Name = "WaaSMedicSvc.dll" },
            @{ Path = Join-Path $AppConfig.Paths.System32 "wuaueng.dll"; Name = "wuaueng.dll" },
            @{ Path = Join-Path $AppConfig.Paths.System32 "WaaSMedicSvc_BAK.dll"; Name = "WaaSMedicSvc_BAK.dll" },
            @{ Path = Join-Path $AppConfig.Paths.System32 "wuaueng_BAK.dll"; Name = "wuaueng_BAK.dll" },
            @{ Path = Join-Path $AppConfig.Paths.SoftwareDistribution "Download"; Name = "Download" },
            @{ Path = Join-Path $AppConfig.Paths.SoftwareDistribution "DataStore"; Name = "DataStore" },
            @{ Path = Join-Path $AppConfig.Paths.SoftwareDistribution "Backup"; Name = "Backup" }
        )

        for ($dirIndex = 0; $dirIndex -lt $directories.Count; $dirIndex++) {
            $dir = $directories[$dirIndex]
            $percent = [math]::Round((($dirIndex + 1) / $directories.Count) * 100)
            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.directories01' -Args @($($dirIndex + 1), $($directories.Count))) -Status (Get-SourceTextLoc 'toolText.elimination0' -Args @($($dir.Name))) -Percent $percent -Icon '🗑️' -Color 'Yellow'

            Start-Sleep -Milliseconds 300

            $success = Remove-DirectorySafely -path $dir.Path -displayName $dir.Name
            if (-not $success) {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.tipSomeFilesMayBeRecreatedAfterReboot')
            }

            Clear-ProgressLine
            [Console]::Out.Flush()
            Start-Sleep -Milliseconds 500
        }

        [Console]::Out.Flush()

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startOfEssentialServices')
        $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
        for ($essentialIndex = 0; $essentialIndex -lt $essentialServices.Count; $essentialIndex++) {
            Manage-Service $essentialServices[$essentialIndex] 'Start' $serviceConfig[$essentialServices[$essentialIndex]] ($essentialIndex + 1) $essentialServices.Count
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.performingAWindowsUpdateClientReset')
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.resetClientUpdate') -Command 'cmd.exe' -Arguments @('/c', 'wuauclt', '/resetauthorization', '/detectnow') -TimeoutSeconds 60 -LogContextKey 'UpdateReset-Wuauclt'

        if ($result.Success) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.windowsUpdateClientResetSuccessfully')
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.windowsUpdateClientResetNotCompletedPossibleTimeout')
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.enablingWindowsUpdateAndRelatedServices')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.resetWindowsUpdateRegistrySettings')

        try {
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 0
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 3
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 1
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.windowsUpdateRegistrySettingsReset')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToRestoreSomeRegistryKeys0' -Args @($($_.Exception.Message)))
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.resetWaasmedicsvcSettings')

        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Type DWord -Value 3 -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "FailureActions" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.waasmedicsvcSettingsReset')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningFailedToRestoreWaasmedicsvc0' -Args @($($_.Exception.Message)))
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.restorationOfUpdateServices')

        $services = @(
            @{Name = "BITS"; StartupType = "Manual"; Icon = "📡" },
            @{Name = "wuauserv"; StartupType = "Manual"; Icon = "🔄" },
            @{Name = "UsoSvc"; StartupType = "Automatic"; Icon = "🚀" },
            @{Name = "uhssvc"; StartupType = "Disabled"; Icon = "⭕" },
            @{Name = "WaaSMedicSvc"; StartupType = "Manual"; Icon = "🛡️" }
        )

        foreach ($service in $services) {
            try {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0Reverting1To2' -Args @($($service.Icon), $($service.Name), $($service.StartupType)))
                $serviceObj = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
                if ($serviceObj) {
                    Set-Service -Name $service.Name -StartupType $service.StartupType -ErrorAction SilentlyContinue *>$null

                    $null = Invoke-ExternalCommandWithLog -Command 'sc.exe' -Arguments @('failure', "$($service.Name)", 'reset= 86400', 'actions= restart/60000/restart/60000/restart/60000') -TimeoutSeconds 30 -LogContextKey "ServiceFailureReset-$($service.Name)"

                    if ($service.StartupType -eq "Automatic") {
                        Set-ServiceStatus -Name $service.Name -Status "Running" -Wait -TimeoutSeconds 5 *>$null
                    }

                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0Service1Restored' -Args @($($service.Icon), $($service.Name)))
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToRestoreService01' -Args @($($service.Name), $($_.Exception.Message)))
            }
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.restoringRenamedDlls')

        $dlls = @("WaaSMedicSvc", "wuaueng")

        foreach ($dll in $dlls) {
            $dllPath = Join-Path $AppConfig.Paths.System32 "$dll.dll"
            $backupPath = Join-Path $AppConfig.Paths.System32 "${dll}_BAK.dll"

            if ((Test-Path $backupPath) -and !(Test-Path $dllPath)) {
                try {
                    $null = Invoke-ExternalCommandWithLog -Command 'takeown.exe' -Arguments @('/f', "`"$backupPath`"") -TimeoutSeconds 30 -LogContextKey "DLLRestore-Takeown-$dll"
                    $null = Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$backupPath`"", '/grant', '*S-1-1-0:F') -TimeoutSeconds 30 -LogContextKey "DLLRestore-IcaclsGrant-$dll"
                    Rename-Item -Path $backupPath -NewName "$dll.dll" -ErrorAction SilentlyContinue *>$null
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.reverted0BakDllTo1Dll' -Args @(${dll}, $dll))
                    $null = Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$dllPath`"", '/setowner', '"NT SERVICE\TrustedInstaller"') -TimeoutSeconds 30 -LogContextKey "DLLRestore-IcaclsOwner-$dll"
                    $null = Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$dllPath`"", '/remove', '*S-1-1-0') -TimeoutSeconds 30 -LogContextKey "DLLRestore-IcaclsRemove-$dll"
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningFailedToRepair0Dll1' -Args @($dll, $($_.Exception.Message)))
                }
            }
            elseif (Test-Path $dllPath) {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0DllAlreadyPresentInTheOriginalLocation' -Args @($dll))
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0DllNotFoundAndNoBackupAvailable' -Args @($dll))
            }
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.rehabilitationOfScheduledTasks')

        $taskPaths = @(
            '\Microsoft\Windows\InstallService\*'
            '\Microsoft\Windows\UpdateOrchestrator\*'
            '\Microsoft\Windows\UpdateAssistant\*'
            '\Microsoft\Windows\WaaSMedic\*'
            '\Microsoft\Windows\WindowsUpdate\*'
            '\Microsoft\WindowsUpdate\*'
        )

        foreach ($taskPath in $taskPaths) {
            try {
                $tasks = Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue
                foreach ($task in $tasks) {
                    Enable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue *>$null
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.taskEnabled0' -Args @($($task.TaskName)))
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToEnableTaskIn01' -Args @($taskPath, $($_.Exception.Message)))
            }
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.enablingDriversViaWindowsUpdate')

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontPromptForWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontSearchWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DriverUpdateWizardWuSearchEnabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.driversViaWindowsUpdateEnabled')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToEnableDriver0' -Args @($($_.Exception.Message)))
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.enableWindowsUpdateAutomaticRestart')

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.windowsUpdateAutomaticRestartEnabled')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToEnableAutomaticRestart0' -Args @($($_.Exception.Message)))
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.resetWindowsUpdateSettings')

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "BranchReadinessLevel" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferQualityUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.windowsUpdateSettingsReset')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToResetSomeSettings0' -Args @($($_.Exception.Message)))
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.resetWindowsLocalPolicies')

        try {
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.deletingLocalPolicies')
            $null = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'RD', '/S', '/Q', "`"$(Join-Path $AppConfig.Paths.System32 "GroupPolicy")`"") -TimeoutSeconds 30 -LogContextKey 'GPReset-RD'
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.criteriaRemoved')

            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.policyUpdate')
            $gpResult = Invoke-ExternalCommandWithLog -Command 'gpupdate.exe' -Arguments @('/force') -TimeoutSeconds 60 -LogContextKey 'GPReset-GPUpdate'
            if (-not $gpResult.Success) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.gpupdateTerminatedWithErrorsOrTimedOut')
            }
            else {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.updatedCriteria')
            }

            Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKCU:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKCU:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue *>$null

            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.windowsLocalPoliciesRestored')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToResetSomePolicies0' -Args @($($_.Exception.Message)))
        }

        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.windowsUpdateHasBeenRestoredToDefaultValues')
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.servicesRegistryAndPoliciesHaveBeenConfiguredSuccessfully')
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.noteARebootIsRequiredToFullyApplyAllChanges')
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.finalCheckOfTheStatusOfTheServices')

        $verificationServices = @('wuauserv', 'BITS', 'UsoSvc', 'WaaSMedicSvc')
        foreach ($service in $verificationServices) {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc) {
                $status = if ($svc.Status -eq 'Running') { '🟢 ' + (Get-SourceTextLoc 'sourceText.active').ToUpperInvariant() } else { '🔴 ' + (Get-SourceTextLoc 'sourceText.inactive').ToUpperInvariant() }
                $startup = if ($svc.StartType -eq 'Automatic') { Get-SourceTextLoc 'sourceText.automatic' } elseif ($svc.StartType -eq 'Manual') { Get-SourceTextLoc 'sourceText.manual' } else { [string]$svc.StartType }
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0Status1Starting2' -Args @($service, $status, $startup))
            }
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.windowsUpdateShouldNowWorkNormally')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.checkByOpeningSettingsUpdateSecurity')
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.repairCompletedSuccessfully')
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.theSystemRequiresARebootToApplyAllChanges')
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningTheSystemWillRestartAutomatically')
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)

        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.preparingToRestartTheSystem') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text '═════════════════════════════════════════════════════════════════'
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.criticalError0SeeTheLogInLocalappdataWintoolkitLogsOrIn1' -Args @($($_.Exception.Message), $Global:CurrentLogFile))
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.pressAnyKeyToExit')
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-ToolkitError -Record $_ -ToolName "WinUpdateReset"
    }
    finally {
        # Cleanup finale se necessario
    }
}
