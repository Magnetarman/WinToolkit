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

    # Variabili globali
    $script:TempDir = "$env:LOCALAPPDATA\WinToolkit\Office"
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
        Write-StyledMessage Info '💡 Premi qualsiasi tasto per annullare il riavvio...'
        Write-Host ''
        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Error '⏸️ Riavvio annullato'
                return $false
            }
            $remainingPercent = 100 - [math]::Round((($Seconds - $i) / $Seconds) * 100)
            Show-ProgressBar 'Countdown Riavvio' "$Message - $i sec" $remainingPercent '⏳' '' 'Red'
            Start-Sleep 1
        }
        Write-Host ''
        Write-StyledMessage Warning '⏰ Riavvio sistema...'
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
        $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'msproject', 'lync')
        $closed = 0
        foreach ($process in $processes) {
            $running = Get-Process -Name $process -ErrorAction SilentlyContinue
            if ($running) {
                $running | Stop-Process -Force -ErrorAction SilentlyContinue
                $closed++
            }
        }
        if ($closed -gt 0) { Write-StyledMessage Success "$closed processi Office terminati" }
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
        Write-StyledMessage Info "🔄 $Reason - Riavvio necessario"
        if (Start-InterruptibleCountdown $CountdownSeconds 'Riavvio automatico') {
            try { Restart-Computer -Force }
            catch { Write-StyledMessage Error "Errore riavvio: $_" }
        }
    }

    function Start-OfficeInstall {
        Write-StyledMessage Info '🏢 Installazione Office Basic...'
        
        # Crea directory e download
        try {
            if (-not (Test-Path $script:TempDir)) { New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null }
            
            $files = @(
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Setup.exe'; Name = 'Setup.exe'; Icon = '⚙️' },
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Basic.xml'; Name = 'Basic.xml'; Icon = '📄' }
            )
            
            foreach ($file in $files) {
                $filePath = Join-Path $script:TempDir $file.Name
                try {
                    Write-Host "`r📥 Download in corso: $($file.Name)..." -NoNewline -ForegroundColor 'Cyan'
                    Invoke-WebRequest -Uri $file.Url -OutFile $filePath -UseBasicParsing
                    Write-Host "`r$($file.Icon) Download completato: $($file.Name)      "
                }
                catch {
                    Write-StyledMessage Error "Download fallito: $($file.Name)"
                    return $false
                }
            }
            
            # Avvia installazione
            Write-StyledMessage Info '🚀 Avvio installazione...'
            $setupPath = Join-Path $script:TempDir 'Setup.exe'
            $configPath = Join-Path $script:TempDir 'Basic.xml'
            Start-Process -FilePath $setupPath -ArgumentList "/configure `"$configPath`"" -WorkingDirectory $script:TempDir
            
            # Attesa utente
            $spinnerIndex = 0
            Write-StyledMessage Info '💡 Premi un tasto quando completata...'
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
            
            # Conferma
            do {
                $confirm = Read-Host "✅ Installazione completata? [Y/N]"
                if ($confirm.ToLower() -eq 'y') {
                    Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
                    return $true
                }
                elseif ($confirm.ToLower() -eq 'n') { return $false }
                else { Write-StyledMessage Warning 'Risposta non valida.' }
            } while ($true)
        }
        catch {
            Write-StyledMessage Error "Errore installazione: $_"
            return $false
        }
    }

    function Start-OfficeRepair {
        Write-StyledMessage Info '🔧 Riparazione Office...'
        Stop-OfficeProcesses

        # Pulizia cache
        $caches = @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache.xml",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )
        $cleaned = 0
        foreach ($cache in $caches) {
            if (Test-Path $cache) {
                try {
                    Remove-Item $cache -Recurse -Force -ErrorAction SilentlyContinue
                    $cleaned++
                }
                catch { }
            }
        }
        if ($cleaned -gt 0) { Write-StyledMessage Success "$cleaned cache eliminate" }
    
        $repaired = $false
        do {
            # Scegli tipo di riparazione
            do {
                Write-Host "Scegliere il tipo di riparazione:" -ForegroundColor Cyan
                Write-Host "  [1] Riparazione rapida" -ForegroundColor Yellow
                Write-Host "  [2] Riparazione online" -ForegroundColor Red
                Write-Host ""
                $choice = Read-Host "Scelta"
                Write-Host ""
                if ($choice -ne '1' -and $choice -ne '2') {
                    Write-StyledMessage Warning 'Opzione non valida. Scegliere 1 o 2.'
                }
            } while ($choice -ne '1' -and $choice -ne '2')

            # Esegui riparazione in base alla scelta
            if ($choice -eq '1') {
                Write-StyledMessage Info '🚀 Avvio riparazione rapida...'
                $RepairType = 'QuickRepair'
                $duration = 10
            }
            else {
                Write-StyledMessage Info '🌐 Avvio riparazione online (richiede connessione internet)...'
                $RepairType = 'FullRepair'
                $duration = 30
            }

            # Comando di riparazione
            $OfficeRepairCommand = "& `"`$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe`" scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=$RepairType DisplayLevel=True"
            Invoke-Expression $OfficeRepairCommand | Out-Null

            # Spinner
            $spinnerChars = '|/-\'
            $spinnerIndex = 0
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Write-Host "⚙️ Riparazione in corso..." -NoNewline -ForegroundColor Green

            while ($stopwatch.Elapsed.TotalSeconds -lt $duration) {
                Write-Host "`r$($spinnerChars[$spinnerIndex])" -NoNewline -ForegroundColor Green
                $spinnerIndex = ($spinnerIndex + 1) % $spinnerChars.Length
                Start-Sleep -Milliseconds 250
            }
            $stopwatch.Stop()
            Write-Host ""
        
            # Chiedi conferma all'utente
            do {
                $confirm = Read-Host "✅ Il ripristino ha funzionato correttamente? [Y/N]"
                if ($confirm.ToLower() -eq 'y') {
                    Write-StyledMessage Success 'Riparazione completata. Avvio riavvio...'
                    $repaired = $true
                    break
                }
                elseif ($confirm.ToLower() -eq 'n') {
                    Write-StyledMessage Info 'Riparazione non riuscita. Riprova con Riparazione Online.'
                    break
                }
                else {
                    Write-StyledMessage Warning 'Risposta non valida.'
                }
            } while ($true)

        } while (-not $repaired)

        # Sezione per il riavvio del sistema
        if ($repaired) {
            # Codice per il riavvio del sistema
            Write-StyledMessage Info 'Riavvio del sistema in corso...'
            # Shutdown.exe /r /t 0
        }
    }

    function Start-OfficeUninstall {
        Write-StyledMessage Warning '🗑️ Rimozione completa Office con Microsoft SaRA'
        Write-StyledMessage Warning '⚠️ ATTENZIONE: Verrà scaricato ed eseguito lo strumento ufficiale Microsoft.'
        
        do {
            $confirm = Read-Host "Procedere? [Y/N]"
            if ($confirm.ToLower() -eq 'n') { return $false }
            elseif ($confirm.ToLower() -eq 'y') { break }
            else { Write-StyledMessage Warning 'Risposta non valida.' }
        } while ($true)
        
        Stop-OfficeProcesses
        
        try {
            # 1. Preparazione della directory e download dello strumento SaRA (file zip)
            if (-not (Test-Path $script:TempDir)) { New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null }
            
            $saraUrl = 'https://aka.ms/SaRA_EnterpriseVersionFiles'
            $saraZipPath = Join-Path $script:TempDir 'SaRA.zip'
            $extractedPath = Join-Path $script:TempDir 'DONE'
            $saraExePath = Join-Path $extractedPath 'SaRAcmd.exe'
            
            Write-StyledMessage Info '📥 Download Microsoft Support and Recovery Assistant (SaRA)...'
            try {
                Write-Host "`r📥 Download in corso: SaRA.zip..." -NoNewline -ForegroundColor 'Cyan'
                Invoke-WebRequest -Uri $saraUrl -OutFile $saraZipPath -UseBasicParsing
                Write-Host "`r📥 Download completato: SaRA.zip      "
            }
            catch {
                Write-StyledMessage Error "Download di SaRA fallito: $_"
                return $false
            }
            
            # 2. Estrazione del file zip e verifica
            Write-StyledMessage Info '📦 Estrazione file...'
            try {
                Expand-Archive -Path $saraZipPath -DestinationPath $script:TempDir -Force
            }
            catch {
                Write-StyledMessage Error "Estrazione fallita: $_"
                return $false
            }
            
            if (-not (Test-Path $saraExePath)) {
                Write-StyledMessage Error "❌ Errore: File 'SaRAcmd.exe' non trovato nella cartella 'DONE'."
                Write-StyledMessage Warning "Riprova o scarica lo strumento manualmente."
                return $false
            }
            
            # 3. Esecuzione di SaRA per la disinstallazione
            Write-StyledMessage Info '🚀 Avvio rimozione Office tramite SaRA...'
            Write-StyledMessage Info '💡 Questo processo potrebbe richiedere molto tempo. Attendere prego...'
            
            # ✅ Aggiunta di una breve pausa per la scansione di sicurezza
            Write-StyledMessage Info '⏱️ Attesa di 5 secondi per la scansione di sicurezza...'
            Start-Sleep -Seconds 5

            $arguments = '-S OfficeScrubScenario -AcceptEula -OfficeVersion All'
            Start-Process -FilePath $saraExePath -ArgumentList $arguments -WorkingDirectory $extractedPath -PassThru -Verb RunAs
            
            # 4. Attesa della conferma da parte dell'utente
            $spinnerIndex = 0
            Write-StyledMessage Info '💡 Premi un tasto quando il programma SaRA ha terminato il lavoro.'
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
            
            Write-StyledMessage Success '🎉 Rimozione tramite SaRA completata con successo!'
        }
        catch {
            Write-StyledMessage Error "Errore durante l'esecuzione di SaRA: $_"
            return $false
        }
        finally {
            # 5. Pulizia
            Write-StyledMessage Info '🧹 Pulizia file temporanei...'
            Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        return $true
    }

    # Interfaccia principale
    $Host.UI.RawUI.WindowTitle = "Office Toolkit By MagnetarMan"
    Clear-Host
    
    # Header
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
        '        Version 2.1 (Build 23)'
    )
    $asciiArt | ForEach-Object { 
        $padding = [math]::Max(0, [math]::Floor(($width - $_.Length) / 2))
        Write-Host ((' ' * $padding) + $_) -ForegroundColor White 
    }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''
    
    # Preparazione
    for ($i = 3; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione - $i sec..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"
    
    try {
        do {
            # Menu
            Write-StyledMessage Info "🎯 Seleziona un'opzione:"
            Write-Host ''
            Write-Host '  [1]  Installazione Office Basic' -ForegroundColor White
            Write-Host '  [2]  Ripara Office corrotto' -ForegroundColor White
            Write-Host '  [3]  Rimozione completa Office' -ForegroundColor Red
            Write-Host '  [0]  Esci' -ForegroundColor Gray
            Write-Host ''
            
            $choice = Read-Host 'Scelta'
            Write-Host ''
            
            switch ($choice) {
                '1' {
                    if (Start-OfficeInstall) {
                        Invoke-SystemRestart 'Installazione completata'
                    }
                }
                '2' {
                    if (Start-OfficeRepair) {
                        Invoke-SystemRestart 'Riparazione completata'
                    }
                }
                '3' {
                    if (Start-OfficeUninstall) {
                        Invoke-SystemRestart 'Rimozione completata'
                    }
                }
                '0' {
                    Write-StyledMessage Info '👋 Uscita...'
                    return
                }
                default {
                    Write-StyledMessage Warning 'Opzione non valida'
                }
            }
            
            if ($choice -ne '0') {
                Write-Host "`n" + ('─' * 50) + "`n"
            }
            
        } while ($choice -ne '0')
    }
    catch {
        Write-StyledMessage Error "Errore critico: $_"
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
    }
}

# Esecuzione
OfficeToolkit