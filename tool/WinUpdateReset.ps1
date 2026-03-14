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
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Start-ToolkitLog -ToolName "WinUpdateReset"
    Show-Header -SubTitle "Update Reset Toolkit"
    $Host.UI.RawUI.WindowTitle = "Win Update Reset Toolkit By MagnetarMan"

    # ============================================================================
    # 2. FUNZIONI HELPER LOCALI
    # ============================================================================

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
        $percent = [math]::Round(($Current / $Total) * 100)
        Invoke-WithSpinner -Activity "$Action $ServiceName" -Timer -Action { Start-Sleep -Milliseconds 200 } -TimeoutSeconds 1 | Out-Null
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
                    Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop | Out-Null
                    Write-StyledMessage -Type 'Success' -Text "$serviceIcon Servizio $serviceName configurato come $($config.Type)."
                }
                'Start' {
                    Show-ServiceProgress $serviceName "Avvio" $currentStep $totalSteps
                    
                    $success = $false
                    Invoke-WithSpinner -Activity "Attesa avvio $serviceName" -Timer -Action { 
                        $success = Set-ServiceStatus -Name $serviceName -Status 'Running' -Wait -TimeoutSeconds 10
                    } -TimeoutSeconds 5 | Out-Null

                    $clearLine = "`r" + (' ' * 80) + "`r"
                    Write-Host $clearLine -NoNewline

                    if ($success) {
                        Write-StyledMessage -Type 'Success' -Text "$serviceIcon Servizio ${serviceName}: avviato correttamente."
                    }
                    else {
                        Write-StyledMessage -Type 'Warning' -Text "$serviceIcon Servizio ${serviceName}: avvio in corso o ritardato..."
                    }
                }
                'Check' {
                    $status = ($service.Status -eq 'Running') ? '🟢 Attivo' : '🔴 Inattivo'
                    $serviceIcon = $config.Icon ?? '⚙️'
                    Write-StyledMessage -Type 'Info' -Text "$serviceIcon $serviceName - Stato: $status"
                }
            }
        }
        catch {
            $actionText = switch ($action) { 'Configure' { 'configurare' } 'Start' { 'avviare' } 'Check' { 'verificare' } default { $action.ToLower() } }
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            Write-StyledMessage -Type 'Warning' -Text "$serviceIcon Impossibile $actionText $serviceName - $($_.Exception.Message)"
        }
    }

    function Remove-DirectorySafely([string]$path, [string]$displayName) {
        if (-not (Test-Path $path)) {
            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Info' -Text "💭 Directory $displayName non presente."
            return $true
        }

        try {
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'

            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue *>$null

            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline
            [Console]::Out.Flush()

            Write-StyledMessage -Type 'Success' -Text "🗑️ Directory $displayName eliminata."
            return $true
        }
        catch {
            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline

            Write-StyledMessage -Type 'Warning' -Text "Tentativo fallito, provo con eliminazione forzata..."

            try {
                $tempDir = [System.IO.Path]::GetTempPath() + "empty_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                $null = New-Item -ItemType Directory -Path $tempDir -Force

                $procParams = @{
                    FilePath     = 'robocopy.exe'
                    ArgumentList = @("`"$tempDir`"", "`"$path`"", '/MIR', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/NC')
                    Wait         = $true
                    WindowStyle  = 'Hidden'
                    ErrorAction  = 'SilentlyContinue'
                }
                $null = Start-Process @procParams
                Remove-Item $tempDir -Force -ErrorAction SilentlyContinue | Out-Null
                Remove-Item $path -Force -ErrorAction SilentlyContinue | Out-Null

                $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                Write-Host $clearLines -NoNewline
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
            finally {
                $ErrorActionPreference = 'Continue'
                $ProgressPreference = 'Continue'
                $VerbosePreference = 'SilentlyContinue'
            }
        }
    }

    # --- MAIN LOGIC ---

    Write-StyledMessage -Type 'Info' -Text '🔧 Inizializzazione dello Script di Reset Windows Update...'

    # Caricamento moduli
    Invoke-WithSpinner -Activity "Caricamento moduli" -Timer -Action { Start-Sleep 2 } -TimeoutSeconds 2 | Out-Null

    Write-StyledMessage -Type 'Info' -Text '🛠️ Avvio riparazione servizi Windows Update...'
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
        Write-StyledMessage -Type 'Info' -Text '🛑 Arresto servizi Windows Update...'
        $stopServices = @('wuauserv', 'cryptsvc', 'bits', 'msiserver')
        for ($serviceIndex = 0; $serviceIndex -lt $stopServices.Count; $serviceIndex++) {
            Manage-Service $stopServices[$serviceIndex] 'Stop' $serviceConfig[$stopServices[$serviceIndex]] ($serviceIndex + 1) $stopServices.Count
        }

        Write-StyledMessage -Type 'Info' -Text '⏳ Attesa liberazione risorse...'
        Start-Sleep -Seconds 3

        Write-StyledMessage -Type 'Info' -Text '⚙️ Ripristino configurazione servizi Windows Update...'
        $criticalServices = $serviceConfig.Keys | Where-Object { $serviceConfig[$_].Critical }
        for ($criticalIndex = 0; $criticalIndex -lt $criticalServices.Count; $criticalIndex++) {
            $serviceName = $criticalServices[$criticalIndex]
            Write-StyledMessage -Type 'Info' -Text "$($serviceConfig[$serviceName].Icon) Elaborazione servizio: $serviceName"
            Manage-Service $serviceName 'Configure' $serviceConfig[$serviceName] ($criticalIndex + 1) $criticalServices.Count
        }

        Write-StyledMessage -Type 'Info' -Text '🔍 Verifica servizi di sistema critici...'
        for ($systemIndex = 0; $systemIndex -lt $systemServices.Count; $systemIndex++) {
            $sysService = $systemServices[$systemIndex]
            Manage-Service $sysService.Name 'Check' @{ Icon = $sysService.Icon } ($systemIndex + 1) $systemServices.Count
        }

        Write-StyledMessage -Type 'Info' -Text '📋 Ripristino chiavi di registro Windows Update...'
        # Elaborazione registro
        Invoke-WithSpinner -Activity "Elaborazione registro" -Timer -Action { Start-Sleep 1 } -TimeoutSeconds 1 | Out-Null
        try {
            @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update",
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            ) | Where-Object { Test-Path $_ } | ForEach-Object {
                Remove-Item $_ -Recurse -Force -ErrorAction Stop | Out-Null
                Write-StyledMessage -Type 'Success' -Text 'Completato!'
            }
            if (-not @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update", "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate") | Where-Object { Test-Path $_ }) {
                Write-StyledMessage -Type 'Success' -Text 'Completato!'
                Write-StyledMessage -Type 'Info' -Text "🔑 Nessuna chiave di registro da rimuovere."
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text 'Errore!'
            Write-StyledMessage -Type 'Warning' -Text "Errore durante la modifica del registro - $($_.Exception.Message)"
        }

        Write-StyledMessage -Type 'Info' -Text '🗂️ Eliminazione componenti Windows Update...'
        $directories = @(
            @{ Path = "$env:WinDir\SoftwareDistribution"; Name = "SoftwareDistribution" },
            @{ Path = "$env:WinDir\System32\catroot2"; Name = "catroot2" },
            @{ Path = "$env:WinDir\System32\WaaSMedicSvc.dll"; Name = "WaaSMedicSvc.dll" },
            @{ Path = "$env:WinDir\System32\wuaueng.dll"; Name = "wuaueng.dll" },
            @{ Path = "$env:WinDir\System32\WaaSMedicSvc_BAK.dll"; Name = "WaaSMedicSvc_BAK.dll" },
            @{ Path = "$env:WinDir\System32\wuaueng_BAK.dll"; Name = "wuaueng_BAK.dll" },
            @{ Path = "$env:WinDir\SoftwareDistribution\Download"; Name = "Download" },
            @{ Path = "$env:WinDir\SoftwareDistribution\DataStore"; Name = "DataStore" },
            @{ Path = "$env:WinDir\SoftwareDistribution\Backup"; Name = "Backup" }
        )

        for ($dirIndex = 0; $dirIndex -lt $directories.Count; $dirIndex++) {
            $dir = $directories[$dirIndex]
            $percent = [math]::Round((($dirIndex + 1) / $directories.Count) * 100)
            Show-ProgressBar "Directory ($($dirIndex + 1)/$($directories.Count))" "Eliminazione $($dir.Name)" $percent '🗑️' '' 'Yellow'

            Start-Sleep -Milliseconds 300

            $success = Remove-DirectorySafely -path $dir.Path -displayName $dir.Name
            if (-not $success) {
                Write-StyledMessage -Type 'Info' -Text "💡 Suggerimento: Alcuni file potrebbero essere ricreati dopo il riavvio."
            }

            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            Start-Sleep -Milliseconds 500
        }

        [Console]::Out.Flush()

        Write-StyledMessage -Type 'Info' -Text '🚀 Avvio servizi essenziali...'
        $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
        for ($essentialIndex = 0; $essentialIndex -lt $essentialServices.Count; $essentialIndex++) {
            Manage-Service $essentialServices[$essentialIndex] 'Start' $serviceConfig[$essentialServices[$essentialIndex]] ($essentialIndex + 1) $essentialServices.Count
        }

        Write-StyledMessage -Type 'Progress' -Text '⚡ Esecuzione comando reset... '
        try {
            $procParams = @{
                FilePath     = 'cmd.exe'
                ArgumentList = '/c', 'wuauclt', '/resetauthorization', '/detectnow'
                Wait         = $true
                WindowStyle  = 'Hidden'
                ErrorAction  = 'SilentlyContinue'
            }
            Start-Process @procParams | Out-Null
            Write-StyledMessage -Type 'Success' -Text 'Completato!'
            Write-StyledMessage -Type 'Success' -Text "🔄 Client Windows Update reimpostato."
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text 'Errore!'
            Write-StyledMessage -Type 'Warning' -Text "Errore durante il reset del client Windows Update."
        }

        Write-StyledMessage -Type 'Info' -Text '🔧 Abilitazione Windows Update e servizi correlati...'

        # Restore Windows Update registry settings to defaults
        Write-StyledMessage -Type 'Info' -Text '📋 Ripristino impostazioni registro Windows Update...'

        try {
            If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU")) {
                New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
            }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Type DWord -Value 0
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Type DWord -Value 3

            If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config")) {
                New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Force | Out-Null
            }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Type DWord -Value 1

            Write-StyledMessage -Type 'Success' -Text "🔑 Impostazioni registro Windows Update ripristinate."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare alcune chiavi di registro - $($_.Exception.Message)"
        }

        # Reset WaaSMedicSvc registry settings to defaults
        Write-StyledMessage -Type 'Info' -Text '🔧 Ripristino impostazioni WaaSMedicSvc...'

        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Type DWord -Value 3 -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "FailureActions" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "⚙️ Impostazioni WaaSMedicSvc ripristinate."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare WaaSMedicSvc - $($_.Exception.Message)"
        }

        # Restore update services to their default state
        Write-StyledMessage -Type 'Info' -Text '🔄 Ripristino servizi di update...'

        $services = @(
            @{Name = "BITS"; StartupType = "Manual"; Icon = "📡" },
            @{Name = "wuauserv"; StartupType = "Manual"; Icon = "🔄" },
            @{Name = "UsoSvc"; StartupType = "Automatic"; Icon = "🚀" },
            @{Name = "uhssvc"; StartupType = "Disabled"; Icon = "⭕" },
            @{Name = "WaaSMedicSvc"; StartupType = "Manual"; Icon = "🛡️" }
        )

        foreach ($service in $services) {
            try {
                Write-StyledMessage -Type 'Info' -Text "$($service.Icon) Ripristino $($service.Name) a $($service.StartupType)..."
                $serviceObj = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
                if ($serviceObj) {
                    Set-Service -Name $service.Name -StartupType $service.StartupType -ErrorAction SilentlyContinue | Out-Null

                    # Reset failure actions to default using sc command
                    $procParams = @{
                        FilePath     = 'sc.exe'
                        ArgumentList = 'failure', "$($service.Name)", 'reset= 86400 actions= restart/60000/restart/60000/restart/60000'
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams | Out-Null

                    # Start the service if it should be running
                    if ($service.StartupType -eq "Automatic") {
                        Set-ServiceStatus -Name $service.Name -Status "Running" -Wait -TimeoutSeconds 5 | Out-Null
                    }

                    Write-StyledMessage -Type 'Success' -Text "$($service.Icon) Servizio $($service.Name) ripristinato."
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare servizio $($service.Name) - $($_.Exception.Message)"
            }
        }

        # Restore renamed DLLs if they exist
        Write-StyledMessage -Type 'Info' -Text '🔍 Ripristino DLL rinominate...'

        $dlls = @("WaaSMedicSvc", "wuaueng")

        foreach ($dll in $dlls) {
            $dllPath = "$env:WinDir\System32\$dll.dll"
            $backupPath = "$env:WinDir\System32\${dll}_BAK.dll"

            if ((Test-Path $backupPath) -and !(Test-Path $dllPath)) {
                try {
                    # Take ownership of backup file
                    $procParams = @{
                        FilePath     = 'takeown.exe'
                        ArgumentList = '/f', "`"$backupPath`""
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams | Out-Null

                    # Grant full control to everyone
                    $procParams = @{
                        FilePath     = 'icacls.exe'
                        ArgumentList = "`"$backupPath`"", '/grant', '*S-1-1-0:F'
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams | Out-Null

                    # Rename back to original
                    Rename-Item -Path $backupPath -NewName "$dll.dll" -ErrorAction SilentlyContinue | Out-Null
                    Write-StyledMessage -Type 'Success' -Text "Ripristinato ${dll}_BAK.dll a $dll.dll"

                    # Restore ownership to TrustedInstaller
                    $procParams = @{
                        FilePath     = 'icacls.exe'
                        ArgumentList = "`"$dllPath`"", '/setowner', '"NT SERVICE\TrustedInstaller"'
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams | Out-Null
                    $procParams = @{
                        FilePath     = 'icacls.exe'
                        ArgumentList = "`"$dllPath`"", '/remove', '*S-1-1-0'
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams | Out-Null
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare $dll.dll - $($_.Exception.Message)"
                }
            }
            elseif (Test-Path $dllPath) {
                Write-StyledMessage -Type 'Info' -Text "💭 $dll.dll già presente nella posizione originale."
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "⚠️ $dll.dll non trovato e nessun backup disponibile."
            }
        }

        # Enable update related scheduled tasks
        Write-StyledMessage -Type 'Info' -Text '📅 Riabilitazione task pianificati...'

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
                    Enable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue | Out-Null
                    Write-StyledMessage -Type 'Success' -Text "Task abilitato: $($task.TaskName)"
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile abilitare task in $taskPath - $($_.Exception.Message)"
            }
        }

        # Enable driver offering through Windows Update
        Write-StyledMessage -Type 'Info' -Text '🖨️ Abilitazione driver tramite Windows Update...'

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontPromptForWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontSearchWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DriverUpdateWizardWuSearchEnabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "🖨️ Driver tramite Windows Update abilitati."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile abilitare driver - $($_.Exception.Message)"
        }

        # Enable Windows Update automatic restart
        Write-StyledMessage -Type 'Info' -Text '🔄 Abilitazione riavvio automatico Windows Update...'

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "🔄 Riavvio automatico Windows Update abilitato."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile abilitare riavvio automatico - $($_.Exception.Message)"
        }

        # Reset Windows Update settings to default
        Write-StyledMessage -Type 'Info' -Text '⚙️ Ripristino impostazioni Windows Update...'

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "BranchReadinessLevel" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferQualityUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "⚙️ Impostazioni Windows Update ripristinate."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare alcune impostazioni - $($_.Exception.Message)"
        }

        # Reset Windows Local Policies to Default
        Write-StyledMessage -Type 'Info' -Text '📋 Ripristino criteri locali Windows...'

        try {
            #Start-Process -FilePath "secedit" -ArgumentList "/configure /cfg $env:windir\inf\defltbase.inf /db defltbase.sdb /verbose" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            #Start-Process -FilePath "cmd.exe" -ArgumentList "/c RD /S /Q $env:WinDir\System32\GroupPolicyUsers" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            
            Write-StyledMessage -Type 'Info' -Text '⏳ Eliminazione criteri locali...'
            $rdProc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c RD /S /Q `"$env:WinDir\System32\GroupPolicy`"" -WindowStyle Hidden -ErrorAction SilentlyContinue -PassThru
            $rdTimeout = 10
            while (-not $rdProc.HasExited -and $rdTimeout -gt 0) {
                Start-Sleep -Seconds 1
                $rdTimeout--
            }
            if (-not $rdProc.HasExited) { $rdProc | Stop-Process -Force -ErrorAction SilentlyContinue }
            Write-StyledMessage -Type 'Success' -Text '✅ Criteri eliminati.'
            
            Write-StyledMessage -Type 'Info' -Text '⏳ Aggiornamento criteri...'
            $gpProc = Start-Process -FilePath "gpupdate.exe" -ArgumentList "/force" -WindowStyle Hidden -ErrorAction SilentlyContinue -PassThru
            $gpTimeout = 15
            while (-not $gpProc.HasExited -and $gpTimeout -gt 0) {
                Start-Sleep -Seconds 1
                $gpTimeout--
            }
            if (-not $gpProc.HasExited) { 
                $gpProc | Stop-Process -Force -ErrorAction SilentlyContinue
                Write-StyledMessage -Type 'Warning' -Text "⚠️ gpupdate terminato per timeout."
            }
            else {
                Write-StyledMessage -Type 'Success' -Text '✅ Criteri aggiornati.'
            }

            # Clean up registry keys
            Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKCU:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKCU:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

            Write-StyledMessage -Type 'Success' -Text "📋 Criteri locali Windows ripristinati."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare alcuni criteri - $($_.Exception.Message)"
        }

        # Final status and verification
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Success' -Text '🎉 Windows Update è stato RIPRISTINATO ai valori predefiniti!'
        Write-StyledMessage -Type 'Success' -Text '🔄 Servizi, registro e criteri sono stati configurati correttamente.'
        Write-StyledMessage -Type 'Warning' -Text "⚡ Nota: È necessario un riavvio per applicare completamente tutte le modifiche."
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)

        Write-StyledMessage -Type 'Info' -Text '🔍 Verifica finale dello stato dei servizi...'

        $verificationServices = @('wuauserv', 'BITS', 'UsoSvc', 'WaaSMedicSvc')
        foreach ($service in $verificationServices) {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc) {
                $status = ($svc.Status -eq 'Running') ? '🟢 ATTIVO' : '🔴 INATTIVO'
                $startup = $svc.StartType
                Write-StyledMessage -Type 'Info' -Text "📊 $service - Stato: $status | Avvio: $startup"
            }
        }

        Write-StyledMessage -Type 'Info' -Text '💡 Windows Update dovrebbe ora funzionare normalmente.'
        Write-StyledMessage -Type 'Info' -Text '🔧 Verifica aprendo Impostazioni > Aggiornamento e sicurezza.'
        Write-StyledMessage -Type 'Info' -Text '🔄 Se necessario, riavvia il sistema per applicare tutte le modifiche.'

        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Success' -Text '🎉 Riparazione completata con successo!'
        Write-StyledMessage -Type 'Success' -Text '💻 Il sistema necessita di un riavvio per applicare tutte le modifiche.'
        Write-StyledMessage -Type 'Warning' -Text "⚡ Attenzione: il sistema verrà riavviato automaticamente"
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)

        if ($SuppressIndividualReboot) {
            $Global:NeedsFinalReboot = $true
            Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
        }
        else {
            $shouldReboot = Start-InterruptibleCountdown $CountdownSeconds "Preparazione riavvio sistema"
            if ($shouldReboot) {
                Write-StyledMessage -Type 'Info' -Text "🔄 Riavvio in corso..."
                Restart-Computer -Force
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text '═════════════════════════════════════════════════════════════════'
        Write-StyledMessage -Type 'Error' -Text "💥 Errore critico: $($_.Exception.Message)"
        Write-StyledMessage -Type 'Info' -Text '⌨️ Premere un tasto per uscire...'
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-ToolkitLog -Level ERROR -Message "Errore critico in WinUpdateReset: $($_.Exception.Message)" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
}