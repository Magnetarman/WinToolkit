function WinUpdateReset {
    <#
    .SYNOPSIS
        Ripara i componenti di Windows Update, reimposta servizi, registro e criteri di default.
    .DESCRIPTION
        Ripara i problemi comuni di Windows Update, reinstalla componenti critici
        e ripristina le configurazioni di default.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "WinUpdateReset" -SubTitle "Update Reset Toolkit"

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

    function Show-ServiceProgress([string]$ServiceName, [string]$Action, [int]$Current, [int]$Total) {
        Invoke-WithSpinner -Activity "$Action $ServiceName" -Timer -Action { Start-Sleep -Milliseconds 200 } -TimeoutSeconds 1 *>$null
    }

    function Manage-Service($serviceName, $action, $config, $currentStep, $totalSteps) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }

            if (-not $service) {
                Write-StyledMessage -Type 'Warning' -Text "$serviceIcon Servizio $serviceName non trovato nel sistema."
                return
            }

            switch ($action) {
                'Stop' {
                    Show-ServiceProgress $serviceName "Arresto" $currentStep $totalSteps
                    $success = Set-ServiceStatus -Name $serviceName -Status 'Stopped' -Wait -TimeoutSeconds 10

                    if ($success) {
                        Write-StyledMessage -Type 'Info' -Text "$serviceIcon Servizio $serviceName arrestato."
                    }
                    else {
                        Write-StyledMessage -Type 'Warning' -Text "$serviceIcon Arresto di $serviceName ha richiesto troppo tempo o è fallito."
                    }
                }
                'Configure' {
                    Show-ServiceProgress $serviceName "Configurazione" $currentStep $totalSteps
                    Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop *>$null
                    Write-StyledMessage -Type 'Success' -Text "$serviceIcon Servizio $serviceName configurato come $($config.Type)."
                }
                'Start' {
                    Show-ServiceProgress $serviceName "Avvio" $currentStep $totalSteps

                    Invoke-WithSpinner -Activity "Attesa avvio $serviceName" -Timer -Action { Start-Sleep -Milliseconds 200 } -TimeoutSeconds 1 *>$null
                    $success = Set-ServiceStatus -Name $serviceName -Status 'Running' -Wait -TimeoutSeconds 10

                    Clear-ProgressLine

                    if ($success) {
                        Write-StyledMessage -Type 'Success' -Text "$serviceIcon Servizio ${serviceName}: avviato correttamente."
                    }
                    else {
                        Write-StyledMessage -Type 'Warning' -Text "$serviceIcon Servizio ${serviceName}: avvio in corso o ritardato."
                    }
                }
                'Check' {
                    $status = if ($service.Status -eq 'Running') { '🟢 Attivo' } else { '🔴 Inattivo' }
                    $serviceIcon = if ($null -ne $config.Icon) { $config.Icon } else { '⚙️' }
                    Write-StyledMessage -Type 'Info' -Text "$serviceIcon $serviceName - Stato: $status"
                }
            }
        }
        catch {
            $actionText = switch ($action) { 'Configure' { 'configurare' } 'Start' { 'avviare' } 'Check' { 'verificare' } default { $action.ToLower() } }
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            Write-StyledMessage -Type 'Warning' -Text "$serviceIcon Impossibile $actionText $serviceName - $($_.Exception.Message)."
        }
    }

    function Remove-DirectorySafely([string]$path, [string]$displayName) {
        if (-not (Test-Path $path)) {
            Clear-ProgressLine
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Info' -Text "💭 Directory $displayName non presente."
            return $true
        }

        try {
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue *>$null

            Clear-ProgressLine
            [Console]::Out.Flush()

            Write-StyledMessage -Type 'Success' -Text "🗑️ Directory $displayName eliminata."
            return $true
        }
        catch {
            Clear-ProgressLine

            Write-StyledMessage -Type 'Warning' -Text "Tentativo fallito, provo con eliminazione forzata."

            try {
                $tempDir = [System.IO.Path]::GetTempPath() + "empty_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                $null = New-Item -ItemType Directory -Path $tempDir -Force

                $null = Invoke-WithSpinner -Activity "Pulizia $displayName" -Command 'robocopy.exe' -Arguments @("`"$tempDir`"", "`"$path`"", '/MIR', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/NC') -TimeoutSeconds 300 -LogContextKey 'RemoveDirectorySafely-Robocopy'
                Remove-Item $tempDir -Force -ErrorAction SilentlyContinue *>$null
                Remove-Item $path -Force -ErrorAction SilentlyContinue *>$null

                Clear-ProgressLine
                [Console]::Out.Flush()

                if (-not (Test-Path $path)) {
                    Write-StyledMessage -Type 'Success' -Text "🗑️ Directory $displayName eliminata (metodo forzato)."
                    return $true
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "Directory $displayName parzialmente eliminata."
                    return $false
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Impossibile eliminare completamente $displayName - file in uso."
                return $false
            }
        }
    }

    Write-StyledMessage -Type 'Info' -Text '🔧 Inizializzazione dello Script di Reset Windows Update.'

    Invoke-WithSpinner -Activity "Caricamento moduli" -Timer -Action { Start-Sleep 2 } -TimeoutSeconds 2 *>$null

    Write-StyledMessage -Type 'Info' -Text '🛠️ Avvio riparazione servizi Windows Update.'
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
        Write-StyledMessage -Type 'Info' -Text '🛑 Arresto servizi Windows Update.'
        $stopServices = @('wuauserv', 'cryptsvc', 'bits', 'msiserver')
        for ($serviceIndex = 0; $serviceIndex -lt $stopServices.Count; $serviceIndex++) {
            Manage-Service $stopServices[$serviceIndex] 'Stop' $serviceConfig[$stopServices[$serviceIndex]] ($serviceIndex + 1) $stopServices.Count
        }

        Write-StyledMessage -Type 'Info' -Text '🧹 Pulizia cache GPCache e impostazioni WSUS.'

        try {
            if (Test-Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache") {
                Remove-Item "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache" -Recurse -Force -ErrorAction Stop
                Write-StyledMessage -Type 'Success' -Text "🗑️ Cache GPCache eliminata."
            } else {
                Write-StyledMessage -Type 'Info' -Text "💭 Cache GPCache non presente."
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile eliminare cache GPCache - $($_.Exception.Message)."
        }

        try {
            if (Test-Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate") {
                Remove-Item "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate" -Recurse -Force -ErrorAction Stop
                Write-StyledMessage -Type 'Success' -Text "🔑 Impostazioni WSUS rimosse."
            } else {
                Write-StyledMessage -Type 'Info' -Text "💭 Impostazioni WSUS non presenti."
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile rimuovere impostazioni WSUS - $($_.Exception.Message)."
        }

        Write-StyledMessage -Type 'Info' -Text '⏳ Attesa liberazione risorse.'
        Start-Sleep -Seconds 3

        Write-StyledMessage -Type 'Info' -Text '⚙️ Ripristino configurazione servizi Windows Update.'
        $criticalServices = $serviceConfig.Keys | Where-Object { $serviceConfig[$_].Critical }
        for ($criticalIndex = 0; $criticalIndex -lt $criticalServices.Count; $criticalIndex++) {
            $serviceName = $criticalServices[$criticalIndex]
            Write-StyledMessage -Type 'Info' -Text "$($serviceConfig[$serviceName].Icon) Elaborazione servizio: $serviceName."
            Manage-Service $serviceName 'Configure' $serviceConfig[$serviceName] ($criticalIndex + 1) $criticalServices.Count
        }

        Write-StyledMessage -Type 'Info' -Text '🔍 Verifica servizi di sistema critici.'
        for ($systemIndex = 0; $systemIndex -lt $systemServices.Count; $systemIndex++) {
            $sysService = $systemServices[$systemIndex]
            Manage-Service $sysService.Name 'Check' @{ Icon = $sysService.Icon } ($systemIndex + 1) $systemServices.Count
        }

        Write-StyledMessage -Type 'Info' -Text '📋 Ripristino chiavi di registro Windows Update.'
        Invoke-WithSpinner -Activity "Elaborazione registro" -Timer -Action { Start-Sleep 1 } -TimeoutSeconds 1 *>$null
        try {
            @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update",
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            ) | Where-Object { Test-Path $_ } | ForEach-Object {
                Remove-Item $_ -Recurse -Force -ErrorAction Stop *>$null
                Write-StyledMessage -Type 'Success' -Text 'Completato!'
            }
            if (-not @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update", "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate") | Where-Object { Test-Path $_ }) {
                Write-StyledMessage -Type 'Success' -Text 'Completato!'
                Write-StyledMessage -Type 'Info' -Text "🔑 Nessuna chiave di registro da rimuovere."
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text 'Errore!'
            Write-StyledMessage -Type 'Warning' -Text "Errore durante la modifica del registro - $($_.Exception.Message)."
        }

        Write-StyledMessage -Type 'Info' -Text '🗂️ Eliminazione componenti Windows Update.'
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
            Write-ProgressUpdate -Activity "Directory ($($dirIndex + 1)/$($directories.Count))" -Status "Eliminazione $($dir.Name)" -Percent $percent -Icon '🗑️' -Color 'Yellow'

            Start-Sleep -Milliseconds 300

            $success = Remove-DirectorySafely -path $dir.Path -displayName $dir.Name
            if (-not $success) {
                Write-StyledMessage -Type 'Info' -Text "💡 Suggerimento: Alcuni file potrebbero essere ricreati dopo il riavvio."
            }

            Clear-ProgressLine
            [Console]::Out.Flush()
            Start-Sleep -Milliseconds 500
        }

        [Console]::Out.Flush()

        Write-StyledMessage -Type 'Info' -Text '🚀 Avvio servizi essenziali.'
        $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
        for ($essentialIndex = 0; $essentialIndex -lt $essentialServices.Count; $essentialIndex++) {
            Manage-Service $essentialServices[$essentialIndex] 'Start' $serviceConfig[$essentialServices[$essentialIndex]] ($essentialIndex + 1) $essentialServices.Count
        }

        Write-StyledMessage -Type 'Info' -Text '⚡ Esecuzione reset client Windows Update...'
        $result = Invoke-WithSpinner -Activity 'Reset Client Update' -Command 'cmd.exe' -Arguments @('/c', 'wuauclt', '/resetauthorization', '/detectnow') -TimeoutSeconds 60 -LogContextKey 'UpdateReset-Wuauclt'

        if ($result.Success) {
            Write-StyledMessage -Type 'Success' -Text "🔄 Client Windows Update reimpostato correttamente."
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text "⚠️ Reset client Windows Update non completato (possibile timeout)."
        }

        Write-StyledMessage -Type 'Info' -Text '🔧 Abilitazione Windows Update e servizi correlati.'
        Write-StyledMessage -Type 'Info' -Text '📋 Ripristino impostazioni registro Windows Update.'

        try {
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 0
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 3
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 1
            Write-StyledMessage -Type 'Success' -Text "🔑 Impostazioni registro Windows Update ripristinate."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare alcune chiavi di registro - $($_.Exception.Message)"
        }

        Write-StyledMessage -Type 'Info' -Text '🔧 Ripristino impostazioni WaaSMedicSvc.'

        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Type DWord -Value 3 -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "FailureActions" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "⚙️ Impostazioni WaaSMedicSvc ripristinate."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare WaaSMedicSvc - $($_.Exception.Message)."
        }

        Write-StyledMessage -Type 'Info' -Text '🔄 Ripristino servizi di update.'

        $services = @(
            @{Name = "BITS"; StartupType = "Manual"; Icon = "📡" },
            @{Name = "wuauserv"; StartupType = "Manual"; Icon = "🔄" },
            @{Name = "UsoSvc"; StartupType = "Automatic"; Icon = "🚀" },
            @{Name = "uhssvc"; StartupType = "Disabled"; Icon = "⭕" },
            @{Name = "WaaSMedicSvc"; StartupType = "Manual"; Icon = "🛡️" }
        )

        foreach ($service in $services) {
            try {
                Write-StyledMessage -Type 'Info' -Text "$($service.Icon) Ripristino $($service.Name) a $($service.StartupType)."
                $serviceObj = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
                if ($serviceObj) {
                    Set-Service -Name $service.Name -StartupType $service.StartupType -ErrorAction SilentlyContinue *>$null

                    $null = Invoke-ExternalCommandWithLog -Command 'sc.exe' -Arguments @('failure', "$($service.Name)", 'reset= 86400', 'actions= restart/60000/restart/60000/restart/60000') -TimeoutSeconds 30 -LogContextKey "ServiceFailureReset-$($service.Name)"

                    if ($service.StartupType -eq "Automatic") {
                        Set-ServiceStatus -Name $service.Name -Status "Running" -Wait -TimeoutSeconds 5 *>$null
                    }

                    Write-StyledMessage -Type 'Success' -Text "$($service.Icon) Servizio $($service.Name) ripristinato."
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare servizio $($service.Name) - $($_.Exception.Message)."
            }
        }

        Write-StyledMessage -Type 'Info' -Text '🔍 Ripristino DLL rinominate.'

        $dlls = @("WaaSMedicSvc", "wuaueng")

        foreach ($dll in $dlls) {
            $dllPath = Join-Path $AppConfig.Paths.System32 "$dll.dll"
            $backupPath = Join-Path $AppConfig.Paths.System32 "${dll}_BAK.dll"

            if ((Test-Path $backupPath) -and !(Test-Path $dllPath)) {
                try {
                    $null = Invoke-ExternalCommandWithLog -Command 'takeown.exe' -Arguments @('/f', "`"$backupPath`"") -TimeoutSeconds 30 -LogContextKey "DLLRestore-Takeown-$dll"
                    $null = Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$backupPath`"", '/grant', '*S-1-1-0:F') -TimeoutSeconds 30 -LogContextKey "DLLRestore-IcaclsGrant-$dll"
                    Rename-Item -Path $backupPath -NewName "$dll.dll" -ErrorAction SilentlyContinue *>$null
                    Write-StyledMessage -Type 'Success' -Text "Ripristinato ${dll}_BAK.dll a $dll.dll."
                    $null = Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$dllPath`"", '/setowner', '"NT SERVICE\TrustedInstaller"') -TimeoutSeconds 30 -LogContextKey "DLLRestore-IcaclsOwner-$dll"
                    $null = Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$dllPath`"", '/remove', '*S-1-1-0') -TimeoutSeconds 30 -LogContextKey "DLLRestore-IcaclsRemove-$dll"
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare $dll.dll - $($_.Exception.Message)."
                }
            }
            elseif (Test-Path $dllPath) {
                Write-StyledMessage -Type 'Info' -Text "💭 $dll.dll già presente nella posizione originale."
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "⚠️ $dll.dll non trovato e nessun backup disponibile."
            }
        }

        Write-StyledMessage -Type 'Info' -Text '📅 Riabilitazione task pianificati.'

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
                    Write-StyledMessage -Type 'Success' -Text "Task abilitato: $($task.TaskName)."
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile abilitare task in $taskPath - $($_.Exception.Message)."
            }
        }

        Write-StyledMessage -Type 'Info' -Text '🖨️ Abilitazione driver tramite Windows Update.'

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontPromptForWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontSearchWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DriverUpdateWizardWuSearchEnabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "🖨️ Driver tramite Windows Update abilitati."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile abilitare driver - $($_.Exception.Message)."
        }

        Write-StyledMessage -Type 'Info' -Text '🔄 Abilitazione riavvio automatico Windows Update.'

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "🔄 Riavvio automatico Windows Update abilitato."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile abilitare riavvio automatico - $($_.Exception.Message)."
        }

        Write-StyledMessage -Type 'Info' -Text '⚙️ Ripristino impostazioni Windows Update.'

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "BranchReadinessLevel" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferQualityUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "⚙️ Impostazioni Windows Update ripristinate."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare alcune impostazioni - $($_.Exception.Message)."
        }

        Write-StyledMessage -Type 'Info' -Text '📋 Ripristino criteri locali Windows.'

        try {
            Write-StyledMessage -Type 'Info' -Text '⏳ Eliminazione criteri locali.'
            $null = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'RD', '/S', '/Q', "`"$(Join-Path $AppConfig.Paths.System32 "GroupPolicy")`"") -TimeoutSeconds 30 -LogContextKey 'GPReset-RD'
            Write-StyledMessage -Type 'Success' -Text '✅ Criteri eliminati.'

            Write-StyledMessage -Type 'Info' -Text '⏳ Aggiornamento criteri.'
            $gpResult = Invoke-ExternalCommandWithLog -Command 'gpupdate.exe' -Arguments @('/force') -TimeoutSeconds 60 -LogContextKey 'GPReset-GPUpdate'
            if (-not $gpResult.Success) {
                Write-StyledMessage -Type 'Warning' -Text "⚠️ gpupdate terminato con errori o timeout."
            }
            else {
                Write-StyledMessage -Type 'Success' -Text '✅ Criteri aggiornati.'
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

            Write-StyledMessage -Type 'Success' -Text "📋 Criteri locali Windows ripristinati."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare alcuni criteri - $($_.Exception.Message)."
        }

        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Success' -Text '🎉 Windows Update è stato RIPRISTINATO ai valori predefiniti!'
        Write-StyledMessage -Type 'Success' -Text '🔄 Servizi, registro e criteri sono stati configurati correttamente.'
        Write-StyledMessage -Type 'Warning' -Text "⚡ Nota: È necessario un riavvio per applicare completamente tutte le modifiche."
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)

        Write-StyledMessage -Type 'Info' -Text '🔍 Verifica finale dello stato dei servizi.'

        $verificationServices = @('wuauserv', 'BITS', 'UsoSvc', 'WaaSMedicSvc')
        foreach ($service in $verificationServices) {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc) {
                $status = if ($svc.Status -eq 'Running') { '🟢 ATTIVO' } else { '🔴 INATTIVO' }
                $startup = $svc.StartType
                Write-StyledMessage -Type 'Info' -Text "📊 $service - Stato: $status | Avvio: $startup."
            }
        }

        Write-StyledMessage -Type 'Info' -Text '💡 Windows Update dovrebbe ora funzionare normalmente.'
        Write-StyledMessage -Type 'Info' -Text '🔧 Verifica aprendo Impostazioni > Aggiornamento e sicurezza.'
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Success' -Text '🎉 Riparazione completata con successo!'
        Write-StyledMessage -Type 'Success' -Text '💻 Il sistema necessita di un riavvio per applicare tutte le modifiche.'
        Write-StyledMessage -Type 'Warning' -Text "⚡ Attenzione: il sistema verrà riavviato automaticamente."
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)

        Invoke-ToolkitReboot -Message "Preparazione riavvio sistema" -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text '═════════════════════════════════════════════════════════════════'
        Write-StyledMessage -Type 'Error' -Text "💥 Errore critico: $($_.Exception.Message). Consulta il log in %LOCALAPPDATA%\WinToolkit\logs o in $Global:CurrentLogFile"
        Write-StyledMessage -Type 'Info' -Text '⌨️ Premere un tasto per uscire.'
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-ToolkitError -Record $_ -ToolName "WinUpdateReset"
    }
    finally {
        # Cleanup finale se necessario
    }
}
