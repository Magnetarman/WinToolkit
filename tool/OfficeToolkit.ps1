function OfficeToolkit {
    param([int]$CountdownSeconds = 30)

    # Variabili globali consolidate
    $script:Log = @(); $script:TempDir = "$env:LOCALAPPDATA\WinToolkit\Office"
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }; Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error = @{ Color = 'Red'; Icon = '❌' }; Info = @{ Color = 'Cyan'; Icon = '💎' }
    }
    $DownloadFiles = @(
        @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Setup.exe'; Name = 'Setup.exe'; Icon = '⚙️' }
        @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Basic.xml'; Name = 'Basic.xml'; Icon = '📄' }
    )

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
                Write-StyledMessage Error '⏸️ Riavvio automatico annullato'
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

    function Center-Text([string]$Text, [int]$Width) {
        $padding = [math]::Max(0, [math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding) + $Text
    }

    function Show-WelcomeScreen {
        $Host.UI.RawUI.WindowTitle = "Office Toolkit By MagnetarMan"
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
            '     Office Toolkit By MagnetarMan',
            '        Version 2.1 (Build 3)'
        )
        
        $asciiArt | ForEach-Object { Write-Host (Center-Text -Text $_ -Width $width) -ForegroundColor White }
        Write-Host ('═' * $width) -ForegroundColor Green
        Write-Host ''
    }

    function Show-MainMenu {
        Write-StyledMessage Info "🎯 Seleziona un'opzione:"
        Write-Host ''
        Write-Host '  [1]  Installazione Office Basic (Word, PowerPoint, Excel)' -ForegroundColor White
        Write-Host '  [2]  Ripara Installazione di Office corrotta' -ForegroundColor White
        Write-Host '  [0]  Esci' -ForegroundColor Gray
        Write-Host ''
        
        do {
            $choice = Read-Host 'Inserisci la tua scelta'
            switch ($choice) {
                '1' { return 'install' }
                '2' { return 'repair' }
                '0' { return 'exit' }
                default { Write-StyledMessage Warning 'Opzione non valida. Riprova.' }
            }
        } while ($true)
    }

    function New-TempDirectory {
        try {
            if (-not (Test-Path $script:TempDir)) {
                New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
                Write-StyledMessage Info "📁 Directory temporanea creata: $script:TempDir"
            }
            return $true
        }
        catch {
            Write-StyledMessage Error "Impossibile creare directory temporanea: $_"
            return $false
        }
    }

    function Invoke-FileDownload([hashtable]$FileInfo) {
        $filePath = Join-Path $script:TempDir $FileInfo.Name
        $spinnerIndex = 0
        
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
            
            Write-StyledMessage Info "📥 Download di $($FileInfo.Name) in corso..."
            
            # Simulazione progresso download con spinner
            $downloadTask = $webClient.DownloadFileTaskAsync($FileInfo.Url, $filePath)
            
            while (-not $downloadTask.IsCompleted) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                Show-ProgressBar "Download $($FileInfo.Name)" 'In corso...' 50 $FileInfo.Icon $spinner 'Cyan'
                Start-Sleep -Milliseconds 300
            }
            
            if (Test-Path $filePath) {
                Show-ProgressBar "Download $($FileInfo.Name)" 'Completato' 100 $FileInfo.Icon
                Write-Host ''
                Write-StyledMessage Success "$($FileInfo.Name) scaricato con successo"
                $script:Log += "[Download] ✅ $($FileInfo.Name) scaricato correttamente"
                return $true
            }
            else {
                throw "File non trovato dopo il download"
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante il download di $($FileInfo.Name): $_"
            $script:Log += "[Download] ❌ Errore scaricando $($FileInfo.Name): $_"
            return $false
        }
        finally {
            if ($webClient) { $webClient.Dispose() }
        }
    }

    function Start-OfficeInstallation {
        Write-StyledMessage Info '🏢 Avvio installazione Office Basic...'
        Write-Host ''
        
        # Creazione directory temporanea
        if (-not (New-TempDirectory)) { return $false }
        
        # Download files
        $downloadSuccess = $true
        foreach ($file in $DownloadFiles) {
            if (-not (Invoke-FileDownload $file)) {
                $downloadSuccess = $false
                break
            }
            Start-Sleep 1
        }
        
        if (-not $downloadSuccess) {
            Write-StyledMessage Error 'Errore durante il download dei file necessari'
            return $false
        }
        
        # Esecuzione installazione
        Write-Host ''
        Write-StyledMessage Info '🚀 Avvio del processo di installazione Office...'
        
        try {
            $setupPath = Join-Path $script:TempDir 'Setup.exe'
            $configPath = Join-Path $script:TempDir 'Basic.xml'
            
            Start-Process -FilePath $setupPath -ArgumentList "/configure `"$configPath`"" -WorkingDirectory $script:TempDir
            $script:Log += "[Installazione] ✅ Processo di installazione avviato"
            
            # Attesa manuale dell'utente
            Write-Host ''
            Write-StyledMessage Warning '⏳ Installazione in corso. L''interfaccia di Office potrebbe aprirsi...'
            $spinnerIndex = 0
            
            Write-StyledMessage Info '💡 Premi un tasto qualsiasi quando l''installazione è completata...'
            
            do {
                if ([Console]::KeyAvailable) {
                    [Console]::ReadKey($true) | Out-Null
                    break
                }
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                Write-Host "`r$spinner 🏢 Attendendo completamento installazione Office..." -NoNewline -ForegroundColor Yellow
                Start-Sleep -Milliseconds 500
            } while ($true)
            
            Write-Host ''
            
            # Conferma completamento
            do {
                $confirmation = Read-Host "`n✅ L'installazione è stata completata correttamente? [Y/N]"
                if ($confirmation.ToLower() -eq 'y') {
                    Write-StyledMessage Success 'Installazione Office completata con successo!'
                    $script:Log += "[Installazione] ✅ Installazione completata dall'utente"
                    return $true
                }
                elseif ($confirmation.ToLower() -eq 'n') {
                    Write-StyledMessage Warning 'Installazione non completata'
                    $script:Log += "[Installazione] ⚠️ Installazione non completata"
                    return $false
                }
                else {
                    Write-StyledMessage Warning 'Risposta non valida. Inserisci Y o N.'
                }
            } while ($true)
        }
        catch {
            Write-StyledMessage Error "Errore durante l'installazione: $_"
            $script:Log += "[Installazione] ❌ Errore: $_"
            return $false
        }
    }

    function Stop-OfficeProcesses {
        $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'msproject', 'lync')
        Write-StyledMessage Info '🔄 Chiusura processi di Office in corso...'
        
        $closedCount = 0
        foreach ($process in $processes) {
            $runningProcesses = Get-Process -Name $process -ErrorAction SilentlyContinue
            if ($runningProcesses) {
                $runningProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
                $closedCount++
                Write-StyledMessage Success "Processo $process terminato"
            }
        }
        
        if ($closedCount -gt 0) {
            Write-StyledMessage Success "$closedCount processi di Office chiusi"
            $script:Log += "[Riparazione] ✅ $closedCount processi Office terminati"
        }
        else {
            Write-StyledMessage Info 'Nessun processo Office in esecuzione'
        }
    }

    function Clear-OfficeCache {
        Write-StyledMessage Info '🧹 Eliminazione cache di Office...'
        
        $cachePaths = @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache.xml",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )
        
        $removedCount = 0
        foreach ($path in $cachePaths) {
            if (Test-Path $path) {
                try {
                    Remove-Item $path -Recurse -Force -ErrorAction Stop
                    Write-StyledMessage Success "Cache eliminata: $(Split-Path $path -Leaf)"
                    $removedCount++
                }
                catch {
                    Write-StyledMessage Warning "Impossibile rimuovere: $(Split-Path $path -Leaf)"
                }
            }
        }
        
        if ($removedCount -gt 0) {
            Write-StyledMessage Success "$removedCount elementi cache eliminati"
            $script:Log += "[Riparazione] ✅ $removedCount cache eliminate"
        }
        else {
            Write-StyledMessage Info 'Nessuna cache da eliminare'
        }
    }

    function Reset-OfficeRegistry {
        Write-StyledMessage Info '📝 Reset impostazioni registro Office...'
        
        try {
            $regPath = 'HKCU:\Software\Microsoft\Office\16.0'
            if (Test-Path $regPath) {
                $backupPath = 'HKCU:\Software\Microsoft\Office\Office.16.0.bak'
                
                # Rimuovi backup esistente se presente
                if (Test-Path $backupPath) {
                    Remove-Item $backupPath -Recurse -Force
                }
                
                Rename-Item -Path $regPath -NewName 'Office.16.0.bak' -Force
                Write-StyledMessage Success 'Chiave registro rinominata in Office.16.0.bak'
                $script:Log += "[Riparazione] ✅ Registro Office resettato (backup creato)"
            }
            else {
                Write-StyledMessage Info 'Chiave registro Office non trovata'
            }
        }
        catch {
            Write-StyledMessage Warning "Errore reset registro: $_"
            $script:Log += "[Riparazione] ⚠️ Errore reset registro: $_"
        }
    }

    function Start-OfficeRepair {
        Write-StyledMessage Info '🔧 Avvio riparazione Office Click-to-Run...'
        
        $officeC2R = "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
        $officeC2Rx64 = "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
        
        $clientPath = $null
        if (Test-Path $officeC2R) {
            Write-StyledMessage Info '🖥️ Office 64-bit rilevato'
            $clientPath = $officeC2R
        }
        elseif (Test-Path $officeC2Rx64) {
            Write-StyledMessage Info '🖥️ Office 32-bit rilevato'
            $clientPath = $officeC2Rx64
        }
        else {
            Write-StyledMessage Error 'OfficeC2RClient.exe non trovato. Verifica installazione Office.'
            return $false
        }
        
        try {
            # Avvio processo riparazione
            Start-Process -FilePath $clientPath -ArgumentList '/repair Office16' -Verb RunAs
            Write-StyledMessage Success 'Processo di riparazione avviato'
            $script:Log += "[Riparazione] ✅ Riparazione Office avviata"
            
            # Monitoraggio processo
            Write-Host ''
            Write-StyledMessage Info '⏳ Monitoraggio processo di riparazione...'
            $spinnerIndex = 0
            
            # Attesa iniziale per l'avvio del processo
            Start-Sleep 3
            
            do {
                $repairProcess = Get-Process -Name 'OfficeC2RClient' -ErrorAction SilentlyContinue
                if ($repairProcess) {
                    $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                    Write-Host "`r$spinner 🔧 Riparazione Office in corso..." -NoNewline -ForegroundColor Yellow
                    Start-Sleep 1
                }
                else {
                    # Verifica se il processo è mai partito
                    Start-Sleep 2
                    $repairProcess = Get-Process -Name 'OfficeC2RClient' -ErrorAction SilentlyContinue
                    if (-not $repairProcess) {
                        break
                    }
                }
            } while ($repairProcess)
            
            Write-Host ''
            Write-StyledMessage Success 'Riparazione Office completata!'
            $script:Log += "[Riparazione] ✅ Riparazione Office completata"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore avvio riparazione: $_"
            $script:Log += "[Riparazione] ❌ Errore riparazione: $_"
            return $false
        }
    }

    function Start-OfficeRepairSequence {
        Write-StyledMessage Info '🛠️ Avvio sequenza di riparazione Office...'
        Write-Host ''
        
        # Sequenza di riparazione
        Stop-OfficeProcesses
        Start-Sleep 1
        
        Clear-OfficeCache
        Start-Sleep 1
        
        Reset-OfficeRegistry
        Start-Sleep 1
        
        $repairSuccess = Start-OfficeRepair
        
        if ($repairSuccess) {
            Write-Host ''
            Write-StyledMessage Success '🎉 Riparazione Office completata con successo!'
            Write-StyledMessage Info '💡 Verrà eseguito un riavvio per applicare le modifiche'
            return $true
        }
        else {
            Write-StyledMessage Warning '⚠️ La riparazione potrebbe non essere completata correttamente'
            return $false
        }
    }

    function Remove-TempDirectory {
        try {
            if (Test-Path $script:TempDir) {
                Remove-Item $script:TempDir -Recurse -Force
                Write-StyledMessage Success '🗑️ Directory temporanea eliminata'
                $script:Log += "[Cleanup] ✅ Directory temporanea rimossa"
            }
        }
        catch {
            Write-StyledMessage Warning "Impossibile eliminare directory temporanea: $_"
        }
    }

    function Start-SystemRestart([string]$Reason) {
        Write-StyledMessage Info '🔄 Il sistema verrà riavviato per finalizzare le modifiche'
        
        if (Start-InterruptibleCountdown $CountdownSeconds 'Riavvio automatico') {
            try {
                Write-StyledMessage Info '🔄 Riavvio in corso...'
                Restart-Computer -Force
            }
            catch {
                Write-StyledMessage Error "❌ Errore riavvio: $_"
                Write-StyledMessage Info '🔄 Riavviare manualmente il sistema.'
            }
        }
        else {
            Write-StyledMessage Info '✅ Script completato. Sistema non riavviato.'
            Write-StyledMessage Info '💡 Riavvia quando possibile per applicare le modifiche.'
        }
    }

    # Interfaccia principale
    Show-WelcomeScreen
    
    # Countdown preparazione
    for ($i = 3; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"
    
    try {
        do {
            $choice = Show-MainMenu
            Write-Host ''
            
            switch ($choice) {
                'install' {
                    Write-StyledMessage Info '🏢 Avvio installazione Office Basic...'
                    $installSuccess = Start-OfficeInstallation
                    
                    if ($installSuccess) {
                        Remove-TempDirectory
                        Start-SystemRestart 'Installazione Office completata'
                    }
                    else {
                        Write-StyledMessage Warning 'Installazione non completata'
                        Remove-TempDirectory
                    }
                    break
                }
                'repair' {
                    Write-StyledMessage Info '🔧 Avvio riparazione Office...'
                    $repairSuccess = Start-OfficeRepairSequence
                    
                    if ($repairSuccess) {
                        Start-SystemRestart 'Riparazione Office completata'
                    }
                    else {
                        Write-StyledMessage Info '⚠️ Script completato con avvisi'
                    }
                    break
                }
                'exit' {
                    Write-StyledMessage Info '👋 Uscita dal toolkit...'
                    return
                }
            }
            
            if ($choice -ne 'exit') {
                Write-Host "`n" + ('─' * 50)
                Write-Host ''
            }
            
        } while ($choice -ne 'exit')
    }
    catch {
        Write-StyledMessage Error "❌ Errore critico: $($_.Exception.Message)"
        $script:Log += "[Sistema] ❌ Errore critico: $($_.Exception.Message)"
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
    }
}

# Esecuzione del toolkit
OfficeToolkit