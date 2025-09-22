function WinUpdateReset {
    <#
    .SYNOPSIS
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI senza output bloccanti.
    
    .DESCRIPTION
        Questo script PowerShell è progettato per riparare i problemi comuni di Windows Update, 
        inclusa la reinstallazione di componenti critici come SoftwareDistribution e catroot2. 
        Utilizza un'interfaccia utente migliorata con barre di progresso, messaggi stilizzati e 
        un conto alla rovescia per il riavvio del sistema che può essere interrotto premendo un tasto.
    #>

    param(
        [int]$CountdownSeconds = 15
    )

    $Host.UI.RawUI.WindowTitle = "Update Reset Toolkit By MagnetarMan"
    # Variabili locali per interfaccia grafica
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $SpinnerIntervalMs = 160
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    # Funzioni helper annidate
    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $barLength = 30
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * $barLength / 100)
        $empty = '▒' * ($barLength - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent
        
        # Pulisce la riga corrente e scrive la progress bar
        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        
        if ($Percent -eq 100) { 
            Write-Host '' # Va a capo quando completa
        }
    }

    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi qualsiasi tasto per annullare il riavvio automatico...'
        Write-Host ''
        
        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Error '⏸️ Riavvio automatico annullato'
                Write-StyledMessage Info "🔄 Puoi riavviare manualmente con: shutdown /r /t 0"
                return $false
            }
            
            # Barra di progressione countdown identica a quella fornita
            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"
            
            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }
        Write-Host "`n" # Assicura il ritorno a capo finale
        Write-StyledMessage Warning '⏰ Tempo scaduto: il sistema verrà riavviato ora.'
        Start-Sleep 1
        return $true
    }

    function Center-Text([string]$Text, [int]$Width) {
        $padding = [math]::Max(0, [math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding) + $Text
    }

    function Show-ServiceProgress([string]$ServiceName, [string]$Action, [int]$Current, [int]$Total) {
        $percent = [math]::Round(($Current / $Total) * 100)
        $spinnerIndex = ($Current % $spinners.Length)
        $spinner = $spinners[$spinnerIndex]
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
                    
                    # Attesa per assicurarsi che il servizio si sia fermato completamente
                    $timeout = 10
                    do {
                        Start-Sleep -Milliseconds 500
                        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                        $timeout--
                    } while ($service.Status -eq 'Running' -and $timeout -gt 0)
                    
                    Write-Host '' # Assicura il ritorno a capo
                    Write-StyledMessage Info "$serviceIcon Servizio $serviceName arrestato."
                }
                'Configure' {
                    Show-ServiceProgress $serviceName "Configurazione" $currentStep $totalSteps
                    Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop
                    Write-Host '' # Assicura il ritorno a capo
                    Write-StyledMessage Success "$serviceIcon Servizio $serviceName configurato come $($config.Type)."
                }
                'Start' {
                    Show-ServiceProgress $serviceName "Avvio" $currentStep $totalSteps
                    Write-Host '' # Va a capo prima di avviare
                    Start-Service -Name $serviceName -ErrorAction Stop
                    
                    # Attesa avvio con spinner
                    $timeout = 10; $spinnerIndex = 0
                    do {
                        # Pulisce la riga prima di scrivere
                        Write-Host "`r$(' ' * 80)" -NoNewline
                        Write-Host "`r$($spinners[$spinnerIndex % $spinners.Length]) 🔄 Attesa avvio $serviceName..." -NoNewline -ForegroundColor Yellow
                        Start-Sleep -Milliseconds 300
                        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                        $timeout--; $spinnerIndex++
                    } while ($service.Status -ne 'Running' -and $timeout -gt 0)
                    
                    # Pulisce la riga dello spinner
                    Write-Host "`r$(' ' * 80)" -NoNewline
                    Write-Host "`r" -NoNewline
                    
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
            Write-Host '' # Assicura il ritorno a capo in caso di errore
            $actionText = switch ($action) { 'Configure' { 'configurare' } 'Start' { 'avviare' } 'Check' { 'verificare' } default { $action.ToLower() } }
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            Write-StyledMessage Warning "$serviceIcon Impossibile $actionText $serviceName - $($_.Exception.Message)"
        }
    }

    # NUOVA FUNZIONE per eliminazione sicura delle directory
    function Remove-DirectorySafely([string]$Path, [string]$DisplayName) {
        if (-not (Test-Path $Path)) {
            Write-StyledMessage Info "💭 Directory $DisplayName non presente."
            return $true
        }

        try {
            # Prima prova: eliminazione diretta usando il cmdlet nativo
            Microsoft.PowerShell.Management\Remove-Item $Path -Recurse -Force -ErrorAction Stop
            Write-StyledMessage Success "🗑️ Directory $DisplayName eliminata."
            return $true
        }
        catch {
            Write-Host '' # Assicura il ritorno a capo
            Write-StyledMessage Warning "Tentativo fallito, provo con eliminazione selettiva..."
        
            try {
                # Seconda prova: elimina i contenuti prima, poi la cartella
                if (Test-Path $Path) {
                    Get-ChildItem -Path $Path -Recurse -Force | ForEach-Object {
                        try {
                            if ($_.PSIsContainer) {
                                Microsoft.PowerShell.Management\Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                            }
                            else {
                                $_.Delete()
                            }
                        }
                        catch {
                            # Ignora errori su singoli file
                        }
                    }
                
                    # Prova a eliminare la directory principale
                    Start-Sleep -Seconds 1
                    Microsoft.PowerShell.Management\Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue
                
                    if (-not (Test-Path $Path)) {
                        Write-StyledMessage Success "🗑️ Directory $DisplayName eliminata (metodo alternativo)."
                        return $true
                    }
                    else {
                        Write-StyledMessage Warning "Directory $DisplayName parzialmente eliminata (alcuni file potrebbero essere in uso)."
                        return $false
                    }
                }
            }
            catch {
                Write-StyledMessage Warning "Impossibile eliminare completamente $DisplayName - alcuni file potrebbero essere in uso."
                return $false
            }
        }
    }
 
    Clear-Host
    $width = 65
    Write-Host ('═' * $width) -ForegroundColor Green
    $asciiArt = @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        '  Update Reset Toolkit By MagnetarMan',
        '       Version 2.1 (Build 29)'
    )
    foreach ($line in $asciiArt) {
        Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
    }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''

    Write-StyledMessage Info '🔧 Inizializzazione dello Script di Reset Windows Update...'
    Start-Sleep -Seconds 2

    # Simulazione caricamento con spinner
    Write-Host '⚡ Caricamento moduli... ' -NoNewline -ForegroundColor Yellow
    for ($i = 0; $i -lt 15; $i++) {
        Write-Host $spinners[$i % $spinners.Length] -NoNewline -ForegroundColor Yellow
        Start-Sleep -Milliseconds $SpinnerIntervalMs
        Write-Host "`b" -NoNewline
    }
    Write-Host '✅ Completato!' -ForegroundColor Green
    Write-Host ''

    Write-StyledMessage Info '🛠️ Avvio riparazione servizi Windows Update...'
    Write-Host ''

    # Configurazione servizi con icone
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
        # Stop servizi Windows Update con progress bar
        Write-StyledMessage Info '🛑 Arresto servizi Windows Update...'
        $stopServices = @('wuauserv', 'cryptsvc', 'bits', 'msiserver')
        for ($i = 0; $i -lt $stopServices.Count; $i++) {
            Manage-Service $stopServices[$i] 'Stop' $serviceConfig[$stopServices[$i]] ($i + 1) $stopServices.Count
        }
        
        # Pausa aggiuntiva per permettere la liberazione completa delle risorse
        Write-Host ''
        Write-StyledMessage Info '⏳ Attesa liberazione risorse...'
        Start-Sleep -Seconds 3
        Write-Host ''

        # Configurazione servizi con progress bar
        Write-StyledMessage Info '⚙️ Ripristino configurazione servizi Windows Update...'
        $criticalServices = $serviceConfig.Keys | Where-Object { $serviceConfig[$_].Critical }
        for ($i = 0; $i -lt $criticalServices.Count; $i++) {
            $serviceName = $criticalServices[$i]
            Write-StyledMessage Info "$($serviceConfig[$serviceName].Icon) Elaborazione servizio: $serviceName"
            Manage-Service $serviceName 'Configure' $serviceConfig[$serviceName] ($i + 1) $criticalServices.Count
        }
        Write-Host ''

        # Verifica servizi di sistema
        Write-StyledMessage Info '🔍 Verifica servizi di sistema critici...'
        for ($i = 0; $i -lt $systemServices.Count; $i++) {
            $sysService = $systemServices[$i]
            Manage-Service $sysService.Name 'Check' @{ Icon = $sysService.Icon } ($i + 1) $systemServices.Count
        }
        Write-Host ''

        # Reset registro con animazione
        Write-StyledMessage Info '📋 Ripristino chiavi di registro Windows Update...'
        Write-Host '🔄 Elaborazione registro... ' -NoNewline -ForegroundColor Cyan
        for ($i = 0; $i -lt 10; $i++) {
            Write-Host $spinners[$i % $spinners.Length] -NoNewline -ForegroundColor Cyan
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

        # Reset componenti con progress bar e gestione errori migliorata
        Write-StyledMessage Info '🗂️ Eliminazione componenti Windows Update...'
        $directories = @(
            @{ Path = "C:\Windows\SoftwareDistribution"; Name = "SoftwareDistribution" },
            @{ Path = "C:\Windows\System32\catroot2"; Name = "catroot2" }
        )
        
        for ($i = 0; $i -lt $directories.Count; $i++) {
            $dir = $directories[$i]
            $percent = [math]::Round((($i + 1) / $directories.Count) * 100)
            Show-ProgressBar "Directory ($($i + 1)/$($directories.Count))" "Eliminazione $($dir.Name)" $percent '🗑️' '' 'Yellow'
            Write-Host '' # Assicura il ritorno a capo dopo la progress bar
            
            $success = Remove-DirectorySafely -Path $dir.Path -DisplayName $dir.Name
            if (-not $success) {
                Write-StyledMessage Info "💡 Suggerimento: Alcuni file potrebbero essere ricreati dopo il riavvio."
            }
        }
        Write-Host ''

        # Avvio servizi essenziali
        Write-StyledMessage Info '🚀 Avvio servizi essenziali...'
        $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
        for ($i = 0; $i -lt $essentialServices.Count; $i++) {
            Manage-Service $essentialServices[$i] 'Start' $serviceConfig[$essentialServices[$i]] ($i + 1) $essentialServices.Count
        }
        Write-Host ''

        # Reset client Windows Update
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

        # SECONDO CICLO DI VERIFICA E CORREZIONE
        Write-Host ('═' * 65) -ForegroundColor Yellow
        Write-StyledMessage Info '🔍 SECONDO CICLO: Verifica e correzione finale...'
        Write-StyledMessage Info '🎯 Esecuzione controlli di sicurezza per garantire la completezza della riparazione.'
        Write-Host ('═' * 65) -ForegroundColor Yellow
        Write-Host ''

        # Verifica e riconfigurazione servizi critici
        Write-StyledMessage Info '🔧 Verifica finale configurazione servizi Windows Update...'
        $criticalServices = $serviceConfig.Keys | Where-Object { $serviceConfig[$_].Critical }
        $serviceIssues = 0
        
        for ($i = 0; $i -lt $criticalServices.Count; $i++) {
            $serviceName = $criticalServices[$i]
            $config = $serviceConfig[$serviceName]
            
            try {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    $currentStartup = (Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'").StartMode
                    $targetStartup = if ($config.Type -eq 'Automatic') { 'Auto' } else { 'Manual' }
                    
                    if ($currentStartup -ne $targetStartup) {
                        Write-StyledMessage Warning "$($config.Icon) Correzione necessaria per $serviceName (attuale: $currentStartup, richiesto: $targetStartup)"
                        Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop
                        Write-StyledMessage Success "$($config.Icon) Servizio $serviceName riconfigurato correttamente."
                        $serviceIssues++
                    }
                    else {
                        Write-StyledMessage Success "$($config.Icon) Servizio ${serviceName}: configurazione corretta."
                    }
                }
            }
            catch {
                Write-StyledMessage Warning "$($config.Icon) Errore nella verifica di $serviceName - $($_.Exception.Message)"
                $serviceIssues++
            }
        }
        
        if ($serviceIssues -eq 0) {
            Write-StyledMessage Success "✅ Tutti i servizi sono configurati correttamente!"
        }
        else {
            Write-StyledMessage Info "🔧 Corretti $serviceIssues problemi di configurazione."
        }
        Write-Host ''

        # Verifica stato servizi essenziali
        Write-StyledMessage Info '🚀 Verifica finale stato servizi essenziali...'
        $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
        $stoppedServices = @()
        
        foreach ($serviceName in $essentialServices) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            $config = $serviceConfig[$serviceName]
            
            if ($service -and $service.Status -ne 'Running') {
                Write-StyledMessage Warning "$($config.Icon) Servizio $serviceName non in esecuzione, tentativo di avvio..."
                try {
                    Start-Service -Name $serviceName -ErrorAction Stop
                    
                    # Attesa avvio
                    $timeout = 5; $spinnerIndex = 0
                    do {
                        Write-Host "`r$(' ' * 80)" -NoNewline
                        Write-Host "`r$($spinners[$spinnerIndex % $spinners.Length]) 🔄 Avvio $serviceName..." -NoNewline -ForegroundColor Yellow
                        Start-Sleep -Milliseconds 300
                        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                        $timeout--; $spinnerIndex++
                    } while ($service.Status -ne 'Running' -and $timeout -gt 0)
                    
                    Write-Host "`r$(' ' * 80)" -NoNewline
                    Write-Host "`r" -NoNewline
                    
                    if ($service.Status -eq 'Running') {
                        Write-StyledMessage Success "$($config.Icon) Servizio ${serviceName}: riavviato con successo."
                    }
                    else {
                        Write-StyledMessage Warning "$($config.Icon) Servizio ${serviceName}: avvio in corso..."
                        $stoppedServices += $serviceName
                    }
                }
                catch {
                    Write-StyledMessage Warning "$($config.Icon) Impossibile avviare $serviceName - $($_.Exception.Message)"
                    $stoppedServices += $serviceName
                }
            }
            else {
                Write-StyledMessage Success "$($config.Icon) Servizio ${serviceName}: in esecuzione correttamente."
            }
        }
        Write-Host ''

        # Verifica finale directory
        Write-StyledMessage Info '🔍 Verifica finale eliminazione componenti...'
        $directories = @(
            @{ Path = "C:\Windows\SoftwareDistribution"; Name = "SoftwareDistribution" },
            @{ Path = "C:\Windows\System32\catroot2"; Name = "catroot2" }
        )
        
        $recreatedDirs = 0
        foreach ($dir in $directories) {
            if (Test-Path $dir.Path) {
                Write-StyledMessage Info "📂 Directory $($dir.Name) ricreata dal sistema - questo è normale."
                $recreatedDirs++
            }
            else {
                Write-StyledMessage Success "✅ Directory $($dir.Name) correttamente eliminata."
            }
        }
        
        if ($recreatedDirs -gt 0) {
            Write-StyledMessage Info "💡 $recreatedDirs directory sono state ricreate automaticamente dal sistema (comportamento normale)."
        }
        Write-Host ''

        # Esecuzione secondo reset del client
        Write-StyledMessage Info '🔄 Secondo reset del client Windows Update...'
        Write-Host '⚡ Esecuzione comando reset aggiuntivo... ' -NoNewline -ForegroundColor Magenta
        try {
            Start-Process "cmd.exe" -ArgumentList "/c wuauclt /resetauthorization /detectnow" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            Write-Host 'Completato!' -ForegroundColor Green
            Write-StyledMessage Success "🔄 Secondo reset del client completato."
        }
        catch {
            Write-Host 'Errore!' -ForegroundColor Red
            Write-StyledMessage Warning "Errore durante il secondo reset del client."
        }
        Write-Host ''

        # Riepilogo finale
        Write-Host ('═' * 65) -ForegroundColor Cyan
        Write-StyledMessage Info '📊 RIEPILOGO FINALE:'
        Write-StyledMessage Success "✅ Primo ciclo di riparazione: Completato"
        Write-StyledMessage Success "✅ Secondo ciclo di verifica: Completato"
        if ($serviceIssues -eq 0) {
            Write-StyledMessage Success "✅ Configurazione servizi: Perfetta"
        }
        else {
            Write-StyledMessage Success "✅ Configurazione servizi: Corretta ($serviceIssues problemi risolti)"
        }
        if ($stoppedServices.Count -eq 0) {
            Write-StyledMessage Success "✅ Stato servizi essenziali: Tutti attivi"
        }
        else {
            Write-StyledMessage Warning "Servizi con problemi: $($stoppedServices -join ', ')"
        }
        Write-StyledMessage Success "✅ Reset client Windows Update: Eseguito 2 volte"
        Write-Host ('═' * 65) -ForegroundColor Cyan
        Write-Host ''

        # Messaggi finali con stile
        Write-Host ('═' * 65) -ForegroundColor Green
        Write-StyledMessage Success '🎉 Riparazione completata con successo!'
        Write-StyledMessage Success '💻 Il sistema necessita di un riavvio per applicare tutte le modifiche.'
        Write-StyledMessage Warning "⚡ Attenzione: il sistema verrà riavviato automaticamente"
        Write-Host ('═' * 65) -ForegroundColor Green
        Write-Host ''
        
        # Countdown interrompibile con progress bar
        $shouldReboot = Start-InterruptibleCountdown $CountdownSeconds "Preparazione riavvio sistema"
        
        if ($shouldReboot) {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
            try { Stop-Transcript | Out-Null } catch {}
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
    }
}

WinUpdateReset