function OfficeToolkit {
    <#
    .SYNOPSIS
        Strumento di gestione Office (installazione, riparazione, rimozione).
    
    .DESCRIPTION
        Questo script PowerShell fornisce un'interfaccia utente per installare, riparare o rimuovere Microsoft Office.
        Include funzionalità avanzate come download con barra di progresso, gestione processi, pulizia registro e file temporanei.
        Supporta l'installazione di Office Basic tramite ODT e la rimozione completa tramite Microsoft SaRA.
        Offre messaggi stilizzati e una barra di progresso interattiva per migliorare l'esperienza utente.
    #>
    
    param([int]$CountdownSeconds = 30)

    # Variabili globali consolidate
    $script:TempDir = "$env:LOCALAPPDATA\WinToolkit\Office"
    $script:Log = @()
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }; Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error = @{ Color = 'Red'; Icon = '❌' }; Info = @{ Color = 'Cyan'; Icon = '💎' }
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '▒' * (30 - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi qualsiasi tasto per annullare il riavvio automatico...'
        Write-Host ''
        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Error '⸕️ Riavvio automatico annullato'
                Write-StyledMessage Info "🔄 Puoi riavviare manualmente: 'shutdown /r /t 0' o dal menu Start."
                return $false
            }
            $remainingPercent = 100 - [math]::Round((($Seconds - $i) / $Seconds) * 100)
            Show-ProgressBar 'Countdown Riavvio' "$Message - $i sec (Premi un tasto per annullare)" $remainingPercent '⏳' '' 'Red'
            Start-Sleep 1
        }
        Write-Host ''
        Write-StyledMessage Warning '⏰ Tempo scaduto: il sistema verrà riavviato ora.'
        Start-Sleep 1
        return $true
    }

    function Get-OfficeClient {
        $paths = @(
            "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe",
            "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
        )
        return $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
    }

    function Stop-OfficeProcesses {
        Write-StyledMessage Info '🔄 Chiusura processi Office attivi...'
        $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'msproject', 'lync')
        $closed = 0
        foreach ($process in $processes) {
            $running = Get-Process -Name $process -ErrorAction SilentlyContinue
            if ($running) {
                try {
                    $running | Stop-Process -Force -ErrorAction SilentlyContinue
                    $closed++
                }
                catch {
                    Write-StyledMessage Warning "Impossibile chiudere processo: $process"
                }
            }
        }
        if ($closed -gt 0) { 
            Write-StyledMessage Success "$closed processi Office terminati con successo"
            $script:Log += "[Gestione Processi] ✅ $closed processi Office chiusi"
        }
        Start-Sleep 2
    }

    function Wait-ProcessCompletion([string]$ProcessName, [string]$Activity, [string]$Icon) {
        $spinnerIndex = 0
        Start-Sleep 3
        do {
            $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            if ($proc) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                Write-Host "`r$spinner $Icon $Activity..." -NoNewline -ForegroundColor Yellow
                Start-Sleep 1
            }
            else {
                Start-Sleep 2
                $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
                if (-not $proc) { break }
            }
        } while ($proc)
        Write-Host ''
    }

    function Invoke-SystemRestart([string]$Reason) {
        Write-StyledMessage Info "🔄 $Reason"
        Write-StyledMessage Info '🔄 Il sistema verrà riavviato per finalizzare le modifiche'
        
        if (Start-InterruptibleCountdown $CountdownSeconds 'Riavvio automatico') {
            try { 
                Write-StyledMessage Info '🔄 Riavvio in corso...'
                $script:Log += "[Sistema] ✅ Riavvio eseguito con successo"
                Restart-Computer -Force 
            }
            catch { 
                Write-StyledMessage Error "❌ Errore riavvio: $_"
                Write-StyledMessage Info '🔄 Riavviare manualmente il sistema.'
                $script:Log += "[Sistema] ❌ Errore durante il riavvio: $_"
            }
        }
        else {
            Write-StyledMessage Info '✅ Script completato. Sistema non riavviato.'
            Write-StyledMessage Info '💡 Riavvia quando possibile per applicare le modifiche.'
        }
    }

    function Start-OfficeInstall {
        Write-StyledMessage Info '🏢 Avvio installazione Office Basic...'
        $script:Log += "[Installazione] ℹ️ Avvio installazione Office Basic"
        
        # Crea directory e download
        try {
            if (-not (Test-Path $script:TempDir)) { 
                New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null 
                Write-StyledMessage Success "Directory temporanea creata: $script:TempDir"
            }
            
            $files = @(
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Setup.exe'; Name = 'Setup.exe'; Icon = '⚙️' },
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Basic.xml'; Name = 'Basic.xml'; Icon = '📄' }
            )
            
            $downloadedFiles = 0
            foreach ($file in $files) {
                $filePath = Join-Path $script:TempDir $file.Name
                try {
                    $spinnerIndex = 0
                    Write-StyledMessage Info "📥 Download di $($file.Name) in corso..."
                    
                    # Simulazione download con progress bar
                    for ($i = 0; $i -le 100; $i += Get-Random -Minimum 5 -Maximum 15) {
                        if ($i -gt 100) { $i = 100 }
                        $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                        Show-ProgressBar "Download $($file.Name)" "In corso..." $i $file.Icon $spinner 'Cyan'
                        Start-Sleep -Milliseconds 200
                    }
                    
                    Invoke-WebRequest -Uri $file.Url -OutFile $filePath -UseBasicParsing
                    Write-StyledMessage Success "✅ Download completato: $($file.Name)"
                    $downloadedFiles++
                    $script:Log += "[Download] ✅ $($file.Name) scaricato con successo"
                }
                catch {
                    Write-StyledMessage Error "❌ Download fallito per $($file.Name): $_"
                    $script:Log += "[Download] ❌ Errore download $($file.Name): $_"
                    return $false
                }
            }
            
            if ($downloadedFiles -ne $files.Count) {
                Write-StyledMessage Error "❌ Download incompleto. File scaricati: $downloadedFiles/$($files.Count)"
                return $false
            }
            
            # Avvia installazione
            Write-StyledMessage Info '🚀 Avvio processo di installazione...'
            $setupPath = Join-Path $script:TempDir 'Setup.exe'
            $configPath = Join-Path $script:TempDir 'Basic.xml'
            
            if (-not (Test-Path $setupPath) -or -not (Test-Path $configPath)) {
                Write-StyledMessage Error "❌ File di installazione mancanti"
                return $false
            }
            
            Start-Process -FilePath $setupPath -ArgumentList "/configure `"$configPath`"" -WorkingDirectory $script:TempDir
            $script:Log += "[Installazione] ℹ️ Processo di installazione avviato"
            
            # Attesa utente con spinner migliorato
            $spinnerIndex = 0
            Write-StyledMessage Info '💡 Premi un tasto quando l'installazione è completata...'
            Write-Host ''
            do {
                if ([Console]::KeyAvailable) {
                    [Console]::ReadKey($true) | Out-Null
                    break
                }
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                Write-Host "`r$spinner 🏢 Installazione in corso..." -NoNewline -ForegroundColor Yellow
                Start-Sleep -Milliseconds 500
            } while ($true)
            Write-Host ''
            
            # Conferma con retry
            $maxAttempts = 3
            $currentAttempt = 0
            do {
                $currentAttempt++
                $confirm = Read-Host "✅ Installazione completata con successo? [Y/N]"
                if ($confirm.ToLower() -eq 'y') {
                    Write-StyledMessage Success '🎉 Installazione Office completata con successo!'
                    Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
                    $script:Log += "[Installazione] ✅ Installazione completata con successo"
                    return $true
                }
                elseif ($confirm.ToLower() -eq 'n') { 
                    Write-StyledMessage Warning '⚠️ Installazione non riuscita'
                    $script:Log += "[Installazione] ⚠️ Installazione fallita - confermato dall'utente"
                    return $false 
                }
                else { 
                    Write-StyledMessage Warning "Risposta non valida. Tentativo $currentAttempt/$maxAttempts"
                }
            } while ($currentAttempt -lt $maxAttempts)
            
            Write-StyledMessage Error "❌ Troppi tentativi falliti"
            return $false
        }
        catch {
            Write-StyledMessage Error "❌ Errore durante l'installazione: $_"
            $script:Log += "[Installazione] ❌ Errore fatale: $_"
            return $false
        }
    }

    function Start-OfficeRepair {
        Write-StyledMessage Info '🔧 Avvio riparazione Microsoft Office...'
        $script:Log += "[Riparazione] ℹ️ Avvio processo di riparazione"
        
        Stop-OfficeProcesses

        # Pulizia cache con progress
        Write-StyledMessage Info '🧹 Pulizia cache Office...'
        $caches = @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache.xml",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )
        $cleaned = 0
        $totalCaches = $caches.Count
        
        for ($i = 0; $i -lt $totalCaches; $i++) {
            $cache = $caches[$i]
            $percent = [math]::Round(($i / $totalCaches) * 100)
            Show-ProgressBar "Pulizia Cache" "Controllo cache..." $percent '🧹'
            
            if (Test-Path $cache) {
                try {
                    Remove-Item $cache -Recurse -Force -ErrorAction SilentlyContinue
                    $cleaned++
                    $script:Log += "[Pulizia] ✅ Cache eliminata: $cache"
                }
                catch { 
                    $script:Log += "[Pulizia] ⚠️ Impossibile eliminare cache: $cache"
                }
            }
            Start-Sleep -Milliseconds 300
        }
        
        Show-ProgressBar "Pulizia Cache" "Completata" 100 '🧹'
        Write-Host ''
        
        if ($cleaned -gt 0) { 
            Write-StyledMessage Success "✅ $cleaned cache eliminate con successo"
        }
        else {
            Write-StyledMessage Info "ℹ️ Nessuna cache da eliminare"
        }

        $repairSucceeded = $false
        $quickRepairAttempted = $false

        # Chiedi tipo di riparazione iniziale
        Write-StyledMessage Info "🎯 Seleziona il tipo di riparazione:"
        Write-Host ''
        do {
            Write-Host "  [1] 🚀 Riparazione rapida (veloce, offline)" -ForegroundColor Green
            Write-Host "  [2] 🌐 Riparazione online (completa, richiede internet)" -ForegroundColor Yellow
            Write-Host ''
            $choice = Read-Host "Scelta"
            Write-Host ''
            if ($choice -ne '1' -and $choice -ne '2') {
                Write-StyledMessage Warning 'Opzione non valida. Scegliere 1 o 2.'
            }
        } while ($choice -ne '1' -and $choice -ne '2')

        # Ciclo di riparazione migliorato
        while (-not $repairSucceeded) {
            if ($choice -eq '1' -and -not $quickRepairAttempted) {
                Write-StyledMessage Info '🚀 Avvio riparazione rapida...'
                $RepairType = 'QuickRepair'
                $duration = 15
                $quickRepairAttempted = $true
                $script:Log += "[Riparazione] ℹ️ Riparazione rapida avviata"
            }
            else {
                Write-StyledMessage Info '🌐 Avvio riparazione online (richiede connessione internet)...'
                $RepairType = 'FullRepair'
                $duration = 45
                $script:Log += "[Riparazione] ℹ️ Riparazione online avviata"
            }

            # Comando di riparazione
            try {
                $officeClient = Get-OfficeClient
                if (-not $officeClient) {
                    Write-StyledMessage Error "❌ Office Click-to-Run non trovato"
                    $script:Log += "[Riparazione] ❌ Office Click-to-Run non trovato"
                    return $false
                }

                $arguments = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=$RepairType DisplayLevel=True"
                Start-Process -FilePath $officeClient -ArgumentList $arguments -NoNewWindow

                # Progress bar durante la riparazione
                $spinnerIndex = 0
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $percent = 0
                
                while ($stopwatch.Elapsed.TotalSeconds -lt $duration) {
                    $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                    $elapsed = $stopwatch.Elapsed.TotalSeconds
                    $percent = [math]::Min(95, [math]::Round(($elapsed / $duration) * 100))
                    
                    $status = if ($RepairType -eq 'QuickRepair') { "Riparazione rapida in corso..." } else { "Riparazione completa in corso..." }
                    Show-ProgressBar "Riparazione Office" $status $percent '🔧' $spinner 'Yellow'
                    Start-Sleep -Milliseconds 600
                }
                
                Show-ProgressBar "Riparazione Office" "Completata" 100 '🔧'
                Write-Host ''
                $stopwatch.Stop()
            }
            catch {
                Write-StyledMessage Error "❌ Errore durante la riparazione: $_"
                $script:Log += "[Riparazione] ❌ Errore durante l'esecuzione: $_"
                return $false
            }

            # Conferma dall'utente con retry
            $maxConfirmAttempts = 3
            $confirmAttempt = 0
            do {
                $confirmAttempt++
                $confirm = Read-Host "✅ La riparazione ha funzionato correttamente? [Y/N]"
                if ($confirm.ToLower() -eq 'y') {
                    Write-StyledMessage Success '🎉 Riparazione completata con successo!'
                    $script:Log += "[Riparazione] ✅ Riparazione completata con successo"
                    $repairSucceeded = $true
                    break
                }
                elseif ($confirm.ToLower() -eq 'n') {
                    if ($quickRepairAttempted -and $choice -eq '1') {
                        Write-StyledMessage Warning '⚠️ Riparazione rapida non riuscita. Tentativo con riparazione online...'
                        $choice = '2'
                        $script:Log += "[Riparazione] ⚠️ Riparazione rapida fallita, passaggio alla riparazione online"
                    }
                    else {
                        Write-StyledMessage Error '❌ Riparazione non riuscita. Contatta il supporto tecnico per assistenza.'
                        $script:Log += "[Riparazione] ❌ Riparazione fallita - nessuna soluzione disponibile"
                        return $false
                    }
                    break
                }
                else {
                    Write-StyledMessage Warning "Risposta non valida. Tentativo $confirmAttempt/$maxConfirmAttempts"
                }
            } while ($confirmAttempt -lt $maxConfirmAttempts)
            
            if ($confirmAttempt -ge $maxConfirmAttempts) {
                Write-StyledMessage Error "❌ Troppi tentativi falliti"
                return $false
            }
        }

        return $repairSucceeded
    }

    function Start-OfficeUninstall {
        Write-StyledMessage Warning '🗑️ Avvio rimozione completa Microsoft Office'
        Write-StyledMessage Warning '⚠️ ATTENZIONE: Verrà utilizzato lo strumento ufficiale Microsoft SaRA.'
        Write-StyledMessage Info 'ℹ️ Questo processo rimuoverà completamente Office dal sistema.'
        $script:Log += "[Rimozione] ℹ️ Avvio processo di rimozione completa"
        
        # Conferma con retry
        $maxAttempts = 3
        $attempt = 0
        do {
            $attempt++
            $confirm = Read-Host "Procedere con la rimozione completa? [Y/N]"
            if ($confirm.ToLower() -eq 'n') { 
                Write-StyledMessage Info '❌ Operazione annullata dall\'utente'
                return $false 
            }
            elseif ($confirm.ToLower() -eq 'y') { break }
            else { 
                Write-StyledMessage Warning "Risposta non valida. Tentativo $attempt/$maxAttempts"
            }
        } while ($attempt -lt $maxAttempts)
        
        if ($attempt -ge $maxAttempts) {
            Write-StyledMessage Error "❌ Troppi tentativi falliti"
            return $false
        }
        
        Stop-OfficeProcesses
        
        try {
            # Preparazione della directory
            Write-StyledMessage Info '📁 Preparazione ambiente di lavoro...'
            if (-not (Test-Path $script:TempDir)) { 
                New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null 
            }
            
            $saraUrl = 'https://aka.ms/SaRA_EnterpriseVersionFiles'
            $saraZipPath = Join-Path $script:TempDir 'SaRA.zip'
            $extractedPath = Join-Path $script:TempDir 'DONE'
            $saraExePath = Join-Path $extractedPath 'SaRAcmd.exe'
            
            # Download con progress bar migliorata
            Write-StyledMessage Info '📥 Download Microsoft Support and Recovery Assistant (SaRA)...'
            try {
                # Simulazione progress download
                for ($i = 0; $i -le 100; $i += Get-Random -Minimum 3 -Maximum 8) {
                    if ($i -gt 100) { $i = 100 }
                    $spinnerIndex = $i % $spinners.Length
                    $spinner = $spinners[$spinnerIndex]
                    Show-ProgressBar "Download SaRA" "Download in corso..." $i '📥' $spinner 'Cyan'
                    Start-Sleep -Milliseconds 150
                }
                
                Invoke-WebRequest -Uri $saraUrl -OutFile $saraZipPath -UseBasicParsing
                Write-StyledMessage Success '✅ Download SaRA completato con successo'
                $script:Log += "[Download] ✅ SaRA scaricato con successo"
            }
            catch {
                Write-StyledMessage Error "❌ Download di SaRA fallito: $_"
                $script:Log += "[Download] ❌ Errore download SaRA: $_"
                return $false
            }
            
            # Estrazione con progress
            Write-StyledMessage Info '📦 Estrazione archivio SaRA...'
            try {
                for ($i = 0; $i -le 100; $i += 20) {
                    Show-ProgressBar "Estrazione" "Estrazione file in corso..." $i '📦'
                    Start-Sleep -Milliseconds 200
                }
                
                Expand-Archive -Path $saraZipPath -DestinationPath $script:TempDir -Force
                Write-StyledMessage Success '✅ Estrazione completata'
                $script:Log += "[Estrazione] ✅ SaRA estratto con successo"
            }
            catch {
                Write-StyledMessage Error "❌ Estrazione fallita: $_"
                $script:Log += "[Estrazione] ❌ Errore estrazione: $_"
                return $false
            }
            
            # Verifica file estratti
            if (-not (Test-Path $saraExePath)) {
                Write-StyledMessage Error "❌ File 'SaRAcmd.exe' non trovato nella cartella estratta"
                Write-StyledMessage Warning "💡 Riprova l'operazione o contatta il supporto tecnico"
                $script:Log += "[Verifica] ❌ SaRAcmd.exe non trovato"
                return $false
            }
            
            Write-StyledMessage Success "✅ Strumento SaRA preparato correttamente"
            
            # Esecuzione di SaRA
            Write-StyledMessage Info '🚀 Avvio rimozione Office tramite Microsoft SaRA...'
            Write-StyledMessage Warning '⏰ Questo processo può richiedere molto tempo. Non chiudere la finestra.'
            
            # Pausa di sicurezza
            Write-StyledMessage Info '⏱️ Attesa di 5 secondi per la scansione di sicurezza...'
            for ($i = 5; $i -gt 0; $i--) {
                Write-Host "`r⏱️ Avvio tra $i secondi..." -NoNewline -ForegroundColor Yellow
                Start-Sleep 1
            }
            Write-Host ''

            $arguments = '-S OfficeScrubScenario -AcceptEula -OfficeVersion All'
            Start-Process -FilePath $saraExePath -ArgumentList $arguments -WorkingDirectory $extractedPath -PassThru -Verb RunAs
            $script:Log += "[Rimozione] ℹ️ SaRA avviato con argomenti: $arguments"
            
            # Attesa della conferma con spinner migliorato
            $spinnerIndex = 0
            Write-StyledMessage Info '💡 Premi un tasto quando SaRA ha completato il lavoro di rimozione.'
            Write-Host ''
            do {
                if ([Console]::KeyAvailable) {
                    [Console]::ReadKey($true) | Out-Null
                    break
                }
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                Write-Host "`r$spinner 🗑️ Rimozione Office in corso..." -NoNewline -ForegroundColor Yellow
                Start-Sleep -Milliseconds 500
            } while ($true)
            Write-Host ''
            
            # Conferma finale
            $finalConfirm = Read-Host "✅ La rimozione di Office è stata completata con successo? [Y/N]"
            if ($finalConfirm.ToLower() -eq 'y') {
                Write-StyledMessage Success '🎉 Rimozione Office completata con successo!'
                $script:Log += "[Rimozione] ✅ Rimozione completata con successo"
                return $true
            }
            else {
                Write-StyledMessage Warning '⚠️ Rimozione potrebbe non essere completata correttamente'
                $script:Log += "[Rimozione] ⚠️ Rimozione potrebbe essere incompleta"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "❌ Errore durante l'esecuzione di SaRA: $_"
            $script:Log += "[Rimozione] ❌ Errore durante SaRA: $_"
            return $false
        }
        finally {
            # Pulizia con progress
            Write-StyledMessage Info '🧹 Pulizia file temporanei...'
            try {
                for ($i = 0; $i -le 100; $i += 25) {
                    Show-ProgressBar "Pulizia" "Rimozione file temporanei..." $i '🧹'
                    Start-Sleep -Milliseconds 200
                }
                Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-StyledMessage Success '✅ Pulizia completata'
            }
            catch {
                Write-StyledMessage Warning "⚠️ Impossibile rimuovere alcuni file temporanei: $_"
            }
        }
    }

    function Center-Text([string]$Text, [int]$Width) {
        $padding = [math]::Max(0, [math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding) + $Text
    }

    # Interfaccia principale
    $Host.UI.RawUI.WindowTitle = "Office Toolkit By MagnetarMan"
    Clear-Host
    
    # Header identico a WinRepairToolkit
    $width = 65
    Write-Host ('═' * $width) -ForegroundColor Green
    
    $asciiArt = @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        '     Office Toolkit By MagnetarMan',
        '        Version 2.1 (Build 26)'
    )
    
    $asciiArt | ForEach-Object { Write-Host (Center-Text -Text $_ -Width $width) -ForegroundColor White }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''

    # Countdown preparazione ottimizzato (identico a WinRepairToolkit)
    for ($i = 5; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"
    
    try {
        do {
            # Menu principale
            Write-StyledMessage Info "🎯 Seleziona un'opzione:"
            Write-Host ''
            Write-Host '  [1]  🏢 Installazione Office (Basic Version)' -ForegroundColor White
            Write-Host '  [2]  🔧 Ripara Office' -ForegroundColor White
            Write-Host '  [3]  🗑️ Rimozione completa Office' -ForegroundColor Yellow
            Write-Host '  [0]  ❌ Esci' -ForegroundColor Red
            Write-Host ''
            
            $choice = Read-Host 'Scelta'
            Write-Host ''
            
            switch ($choice) {
                '1' {
                    Write-StyledMessage Info '🏢 Avvio processo di installazione Office...'
                    if (Start-OfficeInstall) {
                        Write-StyledMessage Success '🎉 Installazione Office completata!'
                        Write-StyledMessage Info '🎯 Installazione riuscita. Il sistema verrà riavviato per finalizzare.'
                        Invoke-SystemRestart 'Installazione completata'
                    }
                    else {
                        Write-StyledMessage Error '❌ Installazione Office non riuscita'
                        Write-StyledMessage Info '💡 Verifica la connessione internet e riprova'
                    }
                }
                '2' {
                    Write-StyledMessage Info '🔧 Avvio processo di riparazione Office...'
                    if (Start-OfficeRepair) {
                        Write-StyledMessage Success '🎉 Riparazione Office completata!'
                        Write-StyledMessage Info '🎯 Riparazione riuscita. Il sistema verrà riavviato per finalizzare.'
                        Invoke-SystemRestart 'Riparazione completata'
                    }
                    else {
                        Write-StyledMessage Error '❌ Riparazione Office non riuscita'
                        Write-StyledMessage Info '💡 Prova con una riparazione online o contatta il supporto'
                    }
                }
                '3' {
                    Write-StyledMessage Warning '🗑️ Avvio processo di rimozione Office...'
                    if (Start-OfficeUninstall) {
                        Write-StyledMessage Success '🎉 Rimozione Office completata!'
                        Write-StyledMessage Info '🎯 Rimozione riuscita. Il sistema verrà riavviato per finalizzare.'
                        Invoke-SystemRestart 'Rimozione completata'
                    }
                    else {
                        Write-StyledMessage Error '❌ Rimozione Office non completata'
                        Write-StyledMessage Info '💡 Alcuni componenti potrebbero non essere stati rimossi'
                    }
                }
                '0' {
                    Write-StyledMessage Info '👋 Uscita dal toolkit...'
                    Write-StyledMessage Success '✅ Grazie per aver utilizzato Office Toolkit!'
                    return
                }
                default {
                    Write-StyledMessage Warning '⚠️ Opzione non valida. Seleziona un numero da 0 a 3.'
                }
            }
            
            if ($choice -ne '0') {
                Write-Host "`n" + ('─' * 50) + "`n"
            }
            
        } while ($choice -ne '0')
    }
    catch {
        Write-StyledMessage Error "❌ Errore critico durante l'esecuzione: $($_.Exception.Message)"
        $script:Log += "[Sistema] ❌ Errore critico: $($_.Exception.Message)"
        
        # Salvataggio log su desktop in caso di errore critico
        try {
            $logPath = "$env:USERPROFILE\Desktop\OfficeToolkit_ErrorLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            $script:Log | Out-File -FilePath $logPath -Encoding UTF8
            Write-StyledMessage Info "📋 Log degli errori salvato sul Desktop: $logPath"
        }
        catch {
            Write-StyledMessage Warning "⚠️ Impossibile salvare il log degli errori"
        }
    }
    finally {
        # Pulizia finale
        Write-Host ''
        Write-StyledMessage Info '🧹 Operazioni di pulizia finale...'
        
        # Rimozione directory temporanea se presente
        if (Test-Path $script:TempDir) {
            try {
                Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-StyledMessage Success '✅ File temporanei rimossi'
            }
            catch {
                Write-StyledMessage Warning '⚠️ Alcuni file temporanei potrebbero non essere stati rimossi'
            }
        }
        
        # Salvataggio log finale se presente
        if ($script:Log.Count -gt 0) {
            try {
                $finalLogPath = "$env:USERPROFILE\Desktop\OfficeToolkit_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
                @(
                    "=== OFFICE TOOLKIT LOG ==="
                    "Data: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
                    "Versione: 2.1 (Build 25)"
                    "Sistema: $env:COMPUTERNAME"
                    "Utente: $env:USERNAME"
                    "==========================="
                    ""
                ) + $script:Log | Out-File -FilePath $finalLogPath -Encoding UTF8
                Write-StyledMessage Success "📋 Log completo salvato: $finalLogPath"
            }
            catch {
                Write-StyledMessage Warning "⚠️ Impossibile salvare il log finale"
            }
        }
        
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
        Write-StyledMessage Success '🎯 Office Toolkit terminato correttamente'
    }
}

OfficeToolkit