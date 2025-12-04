function WinUpdateReset {
    <#
    .SYNOPSIS
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI.
    .DESCRIPTION
        Ripara i problemi comuni di Windows Update, reinstalla componenti critici
        e ripristina le configurazioni di default.
    #>
    param([int]$CountdownSeconds = 15)

    Initialize-ToolLogging -ToolName "WinUpdateReset"
    Show-Header -SubTitle "Update Reset Toolkit"

    # --- FUNZIONI LOCALI ---

    function Show-ServiceProgress([string]$ServiceName, [string]$Action, [int]$Current, [int]$Total) {
        $percent = [math]::Round(($Current / $Total) * 100)
        $spinner = $Global:Spinners[$Current % $Global:Spinners.Length]
        Show-ProgressBar "Servizi ($Current/$Total)" "$Action $ServiceName" $percent '⚙️' $spinner 'Cyan'
        Start-Sleep -Milliseconds 200
    }

    function Manage-Service($serviceName, $action, $config, $currentStep, $totalSteps) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            
            if (-not $service) { 
                Write-StyledMessage Warning "$serviceIcon Servizio $serviceName non trovato nel sistema."
                return
            }

            switch ($action) {
                'Stop' { 
                    Show-ServiceProgress $serviceName "Arresto" $currentStep $totalSteps
                    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                    
                    $timeout = 10
                    do {
                        Start-Sleep -Milliseconds 500
                        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                        $timeout--
                    } while ($service.Status -eq 'Running' -and $timeout -gt 0)
                    
                    Write-Host ''
                    Write-StyledMessage Info "$serviceIcon Servizio $serviceName arrestato."
                }
                'Configure' {
                    Show-ServiceProgress $serviceName "Configurazione" $currentStep $totalSteps
                    Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop
                    Write-Host ''
                    Write-StyledMessage Success "$serviceIcon Servizio $serviceName configurato come $($config.Type)."
                }
                'Start' {
                    Show-ServiceProgress $serviceName "Avvio" $currentStep $totalSteps
                    Write-Host ''
                    Start-Service -Name $serviceName -ErrorAction Stop
                    
                    $timeout = 10; $spinnerIndex = 0
                    do {
                        $clearLine = "`r" + (' ' * 80) + "`r"
                        Write-Host $clearLine -NoNewline
                        $spinChar = $Global:Spinners[$spinnerIndex % $Global:Spinners.Length]
                        Write-Host "$spinChar 🔄 Attesa avvio $serviceName..." -NoNewline -ForegroundColor Yellow
                        Start-Sleep -Milliseconds 300
                        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                        $timeout--; $spinnerIndex++
                    } while ($service.Status -ne 'Running' -and $timeout -gt 0)
                    
                    $clearLine = "`r" + (' ' * 80) + "`r"
                    Write-Host $clearLine -NoNewline
                    
                    if ($service.Status -eq 'Running') {
                        Write-StyledMessage Success "$serviceIcon Servizio ${serviceName}: avviato correttamente."
                    }
                    else {
                        Write-StyledMessage Warning "$serviceIcon Servizio ${serviceName}: avvio in corso..."
                    }
                }
                'Check' {
                    $status = if ($service.Status -eq 'Running') { '🟢 Attivo' } else { '🔴 Inattivo' }
                    $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
                    Write-StyledMessage Info "$serviceIcon $serviceName - Stato: $status"
                }
            }
        }
        catch {
            Write-Host ''
            $actionText = switch ($action) { 'Configure' { 'configurare' } 'Start' { 'avviare' } 'Check' { 'verificare' } default { $action.ToLower() } }
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            Write-StyledMessage Warning "$serviceIcon Impossibile $actionText $serviceName - $($_.Exception.Message)"
        }
    }

    function Remove-DirectorySafely([string]$path, [string]$displayName) {
        if (-not (Test-Path $path)) {
            Write-StyledMessage Info "💭 Directory $displayName non presente."
            return $true
        }

        $originalPos = [Console]::CursorTop
        try {
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue *>$null
            
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline
            [Console]::Out.Flush()
            
            Write-StyledMessage Success "🗑️ Directory $displayName eliminata."
            return $true
        }
        catch {
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline
            
            Write-StyledMessage Warning "Tentativo fallito, provo con eliminazione forzata..."
        
            try {
                $tempDir = [System.IO.Path]::GetTempPath() + "empty_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                $null = New-Item -ItemType Directory -Path $tempDir -Force
                
                $null = Start-Process "robocopy.exe" -ArgumentList "`"$tempDir`" `"$path`" /MIR /NFL /NDL /NJH /NJS /NP /NC" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                Remove-Item $tempDir -Force -ErrorAction SilentlyContinue
                Remove-Item $path -Force -ErrorAction SilentlyContinue
                
                [Console]::SetCursorPosition(0, $originalPos)
                $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                Write-Host $clearLines -NoNewline
                [Console]::Out.Flush()
                
                if (-not (Test-Path $path)) {
                    Write-StyledMessage Success "🗑️ Directory $displayName eliminata (metodo forzato)."
                    return $true
                }
                else {
                    Write-StyledMessage Warning "Directory $displayName parzialmente eliminata."
                    return $false
                }
            }
            catch {
                Write-StyledMessage Warning "Impossibile eliminare completamente $displayName - file in uso."
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

    Write-StyledMessage Info '🔧 Inizializzazione dello Script di Reset Windows Update...'
    Start-Sleep -Seconds 2

    Write-Host '⚡ Caricamento moduli... ' -NoNewline -ForegroundColor Yellow
    for ($i = 0; $i -lt 15; $i++) {
        $spinChar = $Global:Spinners[$i % $Global:Spinners.Length]
        Write-Host $spinChar -NoNewline -ForegroundColor Yellow
        Start-Sleep -Milliseconds 160
        Write-Host "`b" -NoNewline
    }
    Write-Host '✅ Completato!' -ForegroundColor Green
    Write-Host ''

    Write-StyledMessage Info '🛠️ Avvio riparazione servizi Windows Update...'
    Write-Host ''

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
        Write-StyledMessage Info '🛑 Arresto servizi Windows Update...'
        $stopServices = @('wuauserv', 'cryptsvc', 'bits', 'msiserver')
        for ($i = 0; $i -lt $stopServices.Count; $i++) {
            Manage-Service $stopServices[$i] 'Stop' $serviceConfig[$stopServices[$i]] ($i + 1) $stopServices.Count
        }
        
        Write-Host ''
        Write-StyledMessage Info '⏳ Attesa liberazione risorse...'
        Start-Sleep -Seconds 3
        Write-Host ''

        Write-StyledMessage Info '⚙️ Ripristino configurazione servizi Windows Update...'
        $criticalServices = $serviceConfig.Keys | Where-Object { $serviceConfig[$_].Critical }
        for ($i = 0; $i -lt $criticalServices.Count; $i++) {
            $serviceName = $criticalServices[$i]
            Write-StyledMessage Info "$($serviceConfig[$serviceName].Icon) Elaborazione servizio: $serviceName"
            Manage-Service $serviceName 'Configure' $serviceConfig[$serviceName] ($i + 1) $criticalServices.Count
        }
        Write-Host ''

        Write-StyledMessage Info '🔍 Verifica servizi di sistema critici...'
        for ($i = 0; $i -lt $systemServices.Count; $i++) {
            $sysService = $systemServices[$i]
            Manage-Service $sysService.Name 'Check' @{ Icon = $sysService.Icon } ($i + 1) $systemServices.Count
        }
        Write-Host ''

        Write-StyledMessage Info '📋 Ripristino chiavi di registro Windows Update...'
        Write-Host '🔄 Elaborazione registro... ' -NoNewline -ForegroundColor Cyan
        for ($i = 0; $i -lt 10; $i++) {
            $spinChar = $Global:Spinners[$i % $Global:Spinners.Length]
            Write-Host $spinChar -NoNewline -ForegroundColor Cyan
            Start-Sleep -Milliseconds 150
            Write-Host "`b" -NoNewline
        }
        try {
            @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update",
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            ) | Where-Object { Test-Path $_ } | ForEach-Object {
                Remove-Item $_ -Recurse -Force -ErrorAction Stop
                Write-Host 'Completato!' -ForegroundColor Green
                Write-StyledMessage Success "🔑 Chiave rimossa: $_"
            }
            if (-not @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update", "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate") | Where-Object { Test-Path $_ }) {
                Write-Host 'Completato!' -ForegroundColor Green
                Write-StyledMessage Info "🔑 Nessuna chiave di registro da rimuovere."
            }
        }
        catch {
            Write-Host 'Errore!' -ForegroundColor Red
            Write-StyledMessage Warning "Errore durante la modifica del registro - $($_.Exception.Message)"
        }
        Write-Host ''

        Write-StyledMessage Info '🗂️ Eliminazione componenti Windows Update...'
        $directories = @(
            @{ Path = "C:\Windows\SoftwareDistribution"; Name = "SoftwareDistribution" },
            @{ Path = "C:\Windows\System32\catroot2"; Name = "catroot2" }
        )
        
        for ($i = 0; $i -lt $directories.Count; $i++) {
            $dir = $directories[$i]
            $percent = [math]::Round((($i + 1) / $directories.Count) * 100)
            Show-ProgressBar "Directory ($($i + 1)/$($directories.Count))" "Eliminazione $($dir.Name)" $percent '🗑️' '' 'Yellow'
            
            Start-Sleep -Milliseconds 300
            
            $success = Remove-DirectorySafely -path $dir.Path -displayName $dir.Name
            if (-not $success) {
                Write-StyledMessage Info "💡 Suggerimento: Alcuni file potrebbero essere ricreati dopo il riavvio."
            }
            
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            [Console]::SetCursorPosition(0, [Console]::CursorTop)
            Start-Sleep -Milliseconds 500
        }

        Write-Host ''
        [Console]::Out.Flush()
        [Console]::SetCursorPosition(0, [Console]::CursorTop)

        Write-StyledMessage Info '🚀 Avvio servizi essenziali...'
        $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
        for ($i = 0; $i -lt $essentialServices.Count; $i++) {
            Manage-Service $essentialServices[$i] 'Start' $serviceConfig[$essentialServices[$i]] ($i + 1) $essentialServices.Count
        }
        Write-Host ''

        Write-StyledMessage Info '🔄 Reset del client Windows Update...'
        Write-Host '⚡ Esecuzione comando reset... ' -NoNewline -ForegroundColor Magenta
        try {
            Start-Process "cmd.exe" -ArgumentList "/c wuauclt /resetauthorization /detectnow" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            Write-Host 'Completato!' -ForegroundColor Green
            Write-StyledMessage Success "🔄 Client Windows Update reimpostato."
        }
        catch {
            Write-Host 'Errore!' -ForegroundColor Red
            Write-StyledMessage Warning "Errore durante il reset del client Windows Update."
        }
        Write-Host ''

        Write-StyledMessage Info '🔧 Abilitazione Windows Update e servizi correlati...'
        Invoke-WPFUpdatesEnable
        Write-Host ''

        Write-Host ('═' * 65) -ForegroundColor Green
        Write-StyledMessage Success '🎉 Riparazione completata con successo!'
        Write-StyledMessage Success '💻 Il sistema necessita di un riavvio per applicare tutte le modifiche.'
        Write-StyledMessage Warning "⚡ Attenzione: il sistema verrà riavviato automaticamente"
        Write-Host ('═' * 65) -ForegroundColor Green
        Write-Host ''
        
        $shouldReboot = Start-InterruptibleCountdown $CountdownSeconds "Preparazione riavvio sistema"
        
        if ($shouldReboot) {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
            Restart-Computer -Force
        }
    }
    catch {
        Write-Host ''
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage Error "💥 Errore critico: $($_.Exception.Message)"
        Write-StyledMessage Error '❌ Si è verificato un errore durante la riparazione.'
        Write-StyledMessage Info '🔍 Controlla i messaggi sopra per maggiori dettagli.'
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage Info '⌨️ Premere un tasto per uscire...'
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        try { Stop-Transcript | Out-Null } catch {}
    }
}

function Invoke-WPFUpdatesEnable {
    <#
    .SYNOPSIS
        Re-enables Windows Update after it has been disabled
    #>

    Show-Header -SubTitle "Update Enable Toolkit"

    Write-StyledMessage Info '🔧 Inizializzazione ripristino Windows Update...'

    # Restore Windows Update registry settings to defaults
    Write-StyledMessage Info '📋 Ripristino impostazioni registro Windows Update...'

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

        Write-StyledMessage Success "🔑 Impostazioni registro Windows Update ripristinate."
    }
    catch {
        Write-StyledMessage Warning "Avviso: Impossibile ripristinare alcune chiavi di registro - $($_.Exception.Message)"
    }

    # Reset WaaSMedicSvc registry settings to defaults
    Write-StyledMessage Info '🔧 Ripristino impostazioni WaaSMedicSvc...'

    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Type DWord -Value 3 -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "FailureActions" -ErrorAction SilentlyContinue
        Write-StyledMessage Success "⚙️ Impostazioni WaaSMedicSvc ripristinate."
    }
    catch {
        Write-StyledMessage Warning "Avviso: Impossibile ripristinare WaaSMedicSvc - $($_.Exception.Message)"
    }

    # Restore update services to their default state
    Write-StyledMessage Info '🔄 Ripristino servizi di update...'

    $services = @(
        @{Name = "BITS"; StartupType = "Manual"; Icon = "📡" },
        @{Name = "wuauserv"; StartupType = "Manual"; Icon = "🔄" },
        @{Name = "UsoSvc"; StartupType = "Automatic"; Icon = "🚀" },
        @{Name = "uhssvc"; StartupType = "Disabled"; Icon = "⭕" },
        @{Name = "WaaSMedicSvc"; StartupType = "Manual"; Icon = "🛡️" }
    )

    foreach ($service in $services) {
        try {
            Write-StyledMessage Info "$($service.Icon) Ripristino $($service.Name) a $($service.StartupType)..."
            $serviceObj = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
            if ($serviceObj) {
                Set-Service -Name $service.Name -StartupType $service.StartupType -ErrorAction SilentlyContinue

                # Reset failure actions to default using sc command
                Start-Process -FilePath "sc.exe" -ArgumentList "failure `"$($service.Name)`" reset= 86400 actions= restart/60000/restart/60000/restart/60000" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

                # Start the service if it should be running
                if ($service.StartupType -eq "Automatic") {
                    Start-Service -Name $service.Name -ErrorAction SilentlyContinue
                }

                Write-StyledMessage Success "$($service.Icon) Servizio $($service.Name) ripristinato."
            }
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile ripristinare servizio $($service.Name) - $($_.Exception.Message)"
        }
    }

    # Restore renamed DLLs if they exist
    Write-StyledMessage Info '📁 Ripristino DLL rinominate...'

    $dlls = @("WaaSMedicSvc", "wuaueng")

    foreach ($dll in $dlls) {
        $dllPath = "C:\Windows\System32\$dll.dll"
        $backupPath = "C:\Windows\System32\${dll}_BAK.dll"

        if ((Test-Path $backupPath) -and !(Test-Path $dllPath)) {
            try {
                # Take ownership of backup file
                Start-Process -FilePath "takeown.exe" -ArgumentList "/f `"$backupPath`"" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

                # Grant full control to everyone
                Start-Process -FilePath "icacls.exe" -ArgumentList "`"$backupPath`" /grant *S-1-1-0:F" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

                # Rename back to original
                Rename-Item -Path $backupPath -NewName "$dll.dll" -ErrorAction SilentlyContinue
                Write-StyledMessage Success "Ripristinato ${dll}_BAK.dll a $dll.dll"

                # Restore ownership to TrustedInstaller
                Start-Process -FilePath "icacls.exe" -ArgumentList "`"$dllPath`" /setowner `"NT SERVICE\TrustedInstaller`"" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                Start-Process -FilePath "icacls.exe" -ArgumentList "`"$dllPath`" /remove *S-1-1-0" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            }
            catch {
                Write-StyledMessage Warning "Avviso: Impossibile ripristinare $dll.dll - $($_.Exception.Message)"
            }
        }
        elseif (Test-Path $dllPath) {
            Write-StyledMessage Info "💭 $dll.dll già presente nella posizione originale."
        }
        else {
            Write-StyledMessage Warning "⚠️ $dll.dll non trovato e nessun backup disponibile."
        }
    }

    # Enable update related scheduled tasks
    Write-StyledMessage Info '📅 Riabilitazione task pianificati...'

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
                Enable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
                Write-StyledMessage Success "Task abilitato: $($task.TaskName)"
            }
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile abilitare task in $taskPath - $($_.Exception.Message)"
        }
    }

    # Enable driver offering through Windows Update
    Write-StyledMessage Info '🖨️ Abilitazione driver tramite Windows Update...'

    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontPromptForWindowsUpdate" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontSearchWindowsUpdate" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DriverUpdateWizardWuSearchEnabled" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
        Write-StyledMessage Success "🖨️ Driver tramite Windows Update abilitati."
    }
    catch {
        Write-StyledMessage Warning "Avviso: Impossibile abilitare driver - $($_.Exception.Message)"
    }

    # Enable Windows Update automatic restart
    Write-StyledMessage Info '🔄 Abilitazione riavvio automatico Windows Update...'

    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -ErrorAction SilentlyContinue
        Write-StyledMessage Success "🔄 Riavvio automatico Windows Update abilitato."
    }
    catch {
        Write-StyledMessage Warning "Avviso: Impossibile abilitare riavvio automatico - $($_.Exception.Message)"
    }

    # Reset Windows Update settings to default
    Write-StyledMessage Info '⚙️ Ripristino impostazioni Windows Update...'

    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "BranchReadinessLevel" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferQualityUpdatesPeriodInDays" -ErrorAction SilentlyContinue
        Write-StyledMessage Success "⚙️ Impostazioni Windows Update ripristinate."
    }
    catch {
        Write-StyledMessage Warning "Avviso: Impossibile ripristinare alcune impostazioni - $($_.Exception.Message)"
    }

    # Reset Windows Local Policies to Default
    Write-StyledMessage Info '📋 Ripristino criteri locali Windows...'

    try {
        #Start-Process -FilePath "secedit" -ArgumentList "/configure /cfg $env:windir\inf\defltbase.inf /db defltbase.sdb /verbose" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        #Start-Process -FilePath "cmd.exe" -ArgumentList "/c RD /S /Q $env:WinDir\System32\GroupPolicyUsers" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c RD /S /Q $env:WinDir\System32\GroupPolicy" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        Start-Process -FilePath "gpupdate" -ArgumentList "/force" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

        # Clean up registry keys
        Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKCU:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKCU:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\Software\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue

        Write-StyledMessage Success "📋 Criteri locali Windows ripristinati."
    }
    catch {
        Write-StyledMessage Warning "Avviso: Impossibile ripristinare alcuni criteri - $($_.Exception.Message)"
    }

    # Final status and verification
    Write-Host ""
    Write-Host ('═' * 70) -ForegroundColor Green
    Write-StyledMessage Success '🎉 Windows Update è stato RIPRISTINATO ai valori predefiniti!'
    Write-StyledMessage Success '🔄 Servizi, registro e criteri sono stati configurati correttamente.'
    Write-StyledMessage Warning "⚡ Nota: È necessario un riavvio per applicare completamente tutte le modifiche."
    Write-Host ('═' * 70) -ForegroundColor Green
    Write-Host ""

    Write-StyledMessage Info '🔍 Verifica finale dello stato dei servizi...'

    $verificationServices = @('wuauserv', 'BITS', 'UsoSvc', 'WaaSMedicSvc')
    foreach ($service in $verificationServices) {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc) {
            $status = if ($svc.Status -eq 'Running') { '🟢 ATTIVO' } else { '🟡 INATTIVO' }
            $startup = $svc.StartType
            Write-StyledMessage Info "📊 $service - Stato: $status | Avvio: $startup"
        }
    }

    Write-Host ""
    Write-StyledMessage Info '💡 Windows Update dovrebbe ora funzionare normalmente.'
    Write-StyledMessage Info '🔧 Verifica aprendo Impostazioni > Aggiornamento e sicurezza.'
    Write-StyledMessage Info '📝 Se necessario, riavvia il sistema per applicare tutte le modifiche.'
}

WinUpdateReset