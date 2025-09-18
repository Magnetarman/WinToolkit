function OfficeToolkit {
    #region Inizializzazione e Stile
    param([int]$CountdownSeconds = 30)

    $script:Log = @()
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
        Step    = @{ Color = 'Magenta'; Icon = '➡️' }
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
                [void][Console]::ReadKey($true)
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
        if ($Text.Length -ge $Width) { return $Text }
        $padding = $Width - $Text.Length
        $leftPad = [math]::Floor($padding / 2)
        return (' ' * $leftPad) + $Text
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
            '      Office Toolkit By MagnetarMan',
            '        Version 2.1 (Build 1)'
        )

        $asciiArt | ForEach-Object { Write-Host (Center-Text -Text $_ -Width $width) -ForegroundColor White }
        Write-Host ('═' * $width) -ForegroundColor Green
        Write-Host ''
    }

    function Request-Reboot() {
        Write-StyledMessage Info '🔄 Il sistema verrà riavviato per finalizzare le modifiche.'
        if (Start-InterruptibleCountdown $CountdownSeconds 'Riavvio automatico') {
            try {
                Write-StyledMessage Info '🔄 Riavvio in corso...'
                Restart-Computer -Force -ErrorAction Stop
            }
            catch {
                Write-StyledMessage Error "❌ Errore durante il tentativo di riavvio: $_"
                Write-StyledMessage Info '🔄 Riavviare manualmente il sistema.'
            }
        }
        else {
            Write-StyledMessage Info '✅ Script completato. Sistema non riavviato.'
            Write-StyledMessage Info '💡 Riavvia quando possibile per applicare le modifiche.'
        }
    }
    #endregion

    #region Logica Installazione Office
    function Start-OfficeInstallation {
        Write-StyledMessage Step "Avvio installazione di Office Basic..."
        $tempDir = Join-Path $env:LOCALAPPDATA "WinToolkit\Office"
        $setupUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Setup.exe"
        $configUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Basic.xml"
        $setupPath = Join-Path $tempDir "Setup.exe"
        $configPath = Join-Path $tempDir "Basic.xml"

        try {
            # 1. Creazione cartella temporanea
            Write-StyledMessage Info "Creazione directory temporanea in: $tempDir"
            New-Item -Path $tempDir -ItemType Directory -Force -ErrorAction Stop | Out-Null

            # 2. Download Setup.exe
            Write-StyledMessage Info "Download di Setup.exe..."
            Invoke-WebRequest -Uri $setupUrl -OutFile $setupPath -ErrorAction Stop
            Write-StyledMessage Success "Setup.exe scaricato."

            # 3. Download Basic.xml
            Write-StyledMessage Info "Download di Basic.xml..."
            Invoke-WebRequest -Uri $configUrl -OutFile $configPath -ErrorAction Stop
            Write-StyledMessage Success "Basic.xml scaricato."

            # 4. Esecuzione setup
            Write-StyledMessage Info "Avvio del setup di Office. Segui le istruzioni a schermo."
            Start-Process -FilePath $setupPath -ArgumentList "/configure Basic.xml" -WorkingDirectory $tempDir

            # 5. Messaggio di attesa
            $spinnerIndex = 0
            Write-Host ""
            while (-not [Console]::KeyAvailable) {
                $spinnerChar = $spinners[$spinnerIndex++ % $spinners.Length]
                $msg = "`r$spinnerChar 💎 In attesa del completamento dell'installazione... (Premi un tasto qualsiasi per continuare)"
                Write-Host $msg -NoNewline -ForegroundColor 'Cyan'
                Start-Sleep -Milliseconds 100
            }
            [void][Console]::ReadKey($true)
            Write-Host "`n"

            # 6. Conferma completamento
            $confirmation = Read-Host "⚠️ L'installazione di Office è stata completata con successo? (Y/N)"
            if ($confirmation -notmatch '^[Yy]$') {
                Write-StyledMessage Error "Installazione non confermata. Potrebbero verificarsi problemi. Lo script verrà interrotto."
                return
            }
            
            Write-StyledMessage Success "Installazione completata e confermata."

        }
        catch {
            Write-StyledMessage Error "Si è verificato un errore: $_"
            return
        }
        finally {
            # 7. Pulizia
            if (Test-Path $tempDir) {
                Write-StyledMessage Info "Pulizia dei file temporanei..."
                Remove-Item -Path $tempDir -Recurse -Force
                Write-StyledMessage Success "Directory temporanea rimossa."
            }
        }

        # 8. Riavvio
        Request-Reboot
    }
    #endregion

    #region Logica Riparazione Office
    function Start-OfficeRepair {
        Write-StyledMessage Step "Avvio riparazione installazione di Office..."

        # 1. Termina processi Office
        $processes = "winword", "excel", "powerpnt", "outlook", "onenote", "msaccess", "visio", "msproject", "lync"
        Write-StyledMessage Info "Chiusura dei processi di Office in corso..."
        foreach ($process in $processes) {
            Get-Process -Name $process -ErrorAction SilentlyContinue | Stop-Process -Force
        }
        Write-StyledMessage Success "Processi di Office chiusi."

        # 2. Elimina cache
        Write-StyledMessage Info "Eliminazione delle cartelle della cache di Office..."
        $cachePaths = @(
            Join-Path $env:LOCALAPPDATA "Microsoft\Office\16.0\Lync\Lync.cache"
            Join-Path $env:LOCALAPPDATA "Microsoft\Office\16.0\Lync\Lync.cache.xml"
            Join-Path $env:LOCALAPPDATA "Microsoft\Office\16.0\OfficeFileCache"
        )
        foreach ($path in $cachePaths) {
            if (Test-Path $path) {
                Remove-Item $path -Recurse -Force
                Write-StyledMessage Info "Cache eliminata: $path"
            }
        }
        Write-StyledMessage Success "Cache di Office eliminata."

        # 3. Resetta registro
        Write-StyledMessage Info "Reset delle impostazioni di Office nel registro..."
        $regPath = "HKCU:\Software\Microsoft\Office\16.0"
        if (Test-Path $regPath) {
            try {
                Rename-Item -Path $regPath -NewName "Office.16.0.bak" -Force -ErrorAction Stop
                Write-StyledMessage Success "Chiave di registro rinominata in 'Office.16.0.bak'."
            }
            catch {
                Write-StyledMessage Warning "Impossibile rinominare la chiave di registro. Potrebbe essere necessario eseguire lo script come amministratore."
            }
        }

        # 4. Avvia riparazione
        Write-StyledMessage Info "Avvio della riparazione di Office Click-to-Run..."
        $officeC2R = Join-Path ${env:ProgramFiles} "Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
        $officeC2Rx86 = Join-Path ${env:ProgramFiles(x86)} "Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
        $repairStarted = $false

        if (Test-Path $officeC2R) {
            Write-StyledMessage Info "Office a 64-bit rilevato. Avvio riparazione..."
            Start-Process -FilePath $officeC2R -ArgumentList "/repair Office16"
            $repairStarted = $true
        }
        elseif (Test-Path $officeC2Rx86) {
            Write-StyledMessage Info "Office a 32-bit rilevato. Avvio riparazione..."
            Start-Process -FilePath $officeC2Rx86 -ArgumentList "/repair Office16"
            $repairStarted = $true
        }
        else {
            Write-StyledMessage Error "Impossibile trovare OfficeC2RClient.exe. Assicurati che Office sia installato."
            return
        }

        if ($repairStarted) {
            Write-StyledMessage Success "Il processo di riparazione di Office è stato avviato. Segui le istruzioni a schermo."
            Write-StyledMessage Info "Lo script attenderà il completamento della riparazione..."
            
            # 5. Monitoraggio processo
            $spinnerIndex = 0
            while (Get-Process -Name "OfficeC2RClient" -ErrorAction SilentlyContinue) {
                $spinnerChar = $spinners[$spinnerIndex++ % $spinners.Length]
                Write-Host "`r$spinnerChar 🛠️ Riparazione in corso... Non chiudere questa finestra." -NoNewline -ForegroundColor 'Yellow'
                Start-Sleep -Seconds 1
            }
            Write-Host "`r" + (' ' * 80) + "`r" # Pulisce la riga dello spinner
            Write-StyledMessage Success "Riparazione di Office completata."
            
            # 6. Riavvio
            Request-Reboot
        }
    }
    #endregion

    #region Menu Principale
    Show-WelcomeScreen
    do {
        Write-Host "Cosa vorresti fare?" -ForegroundColor White
        Write-Host " 1. Installa Office Basic (Word, PowerPoint, Excel)" -ForegroundColor Cyan
        Write-Host " 2. Ripara un'installazione di Office corrotta" -ForegroundColor Cyan
        Write-Host " Q. Esci" -ForegroundColor Red
        $choice = Read-Host "Inserisci la tua scelta"

        switch ($choice) {
            '1' { Start-OfficeInstallation; $choice = 'Q' }
            '2' { Start-OfficeRepair; $choice = 'Q' }
            'Q' { Write-StyledMessage Info "Uscita dal Toolkit. A presto!" }
            default { Write-StyledMessage Error "Scelta non valida. Riprova." }
        }
        Write-Host ""
    } while ($choice -ne 'Q')
    #endregion
}

# Esecuzione dello script
OfficeToolkit