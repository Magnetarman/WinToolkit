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
                $spinnerIndex = 0
                
                try {
                    $webClient = New-Object System.Net.WebClient
                    $webClient.Headers.Add('User-Agent', 'Mozilla/5.0')
                    
                    $downloadTask = $webClient.DownloadFileTaskAsync($file.Url, $filePath)
                    while (-not $downloadTask.IsCompleted) {
                        $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                        Show-ProgressBar "Download $($file.Name)" 'In corso...' 50 $file.Icon $spinner 'Cyan'
                        Start-Sleep -Milliseconds 300
                    }
                    
                    Show-ProgressBar "Download $($file.Name)" 'Completato' 100 $file.Icon
                    Write-Host ''
                    $webClient.Dispose()
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
                    Remove-Item $cache -Recurse -Force
                    $cleaned++
                }
                catch { }
            }
        }
        if ($cleaned -gt 0) { Write-StyledMessage Success "$cleaned cache eliminate" }
        
        # Reset registro
        try {
            $regPath = 'HKCU:\Software\Microsoft\Office\16.0'
            if (Test-Path $regPath) {
                $backupPath = 'HKCU:\Software\Microsoft\Office\Office.16.0.bak'
                if (Test-Path $backupPath) { Remove-Item $backupPath -Recurse -Force }
                Rename-Item -Path $regPath -NewName 'Office.16.0.bak' -Force
                Write-StyledMessage Success 'Registro resettato'
            }
        }
        catch { Write-StyledMessage Warning "Errore registro: $_" }
        
        # Riparazione Click-to-Run
        $client = Get-OfficeClient
        if ($client) {
            try {
                Start-Process -FilePath $client -ArgumentList '/repair Office16' -Verb RunAs
                Write-StyledMessage Success 'Riparazione avviata'
                Wait-ProcessCompletion 'OfficeC2RClient' 'Riparazione Office' '🔧'
                Write-StyledMessage Success 'Riparazione completata!'
                return $true
            }
            catch {
                Write-StyledMessage Error "Errore riparazione: $_"
                return $false
            }
        }
        else {
            Write-StyledMessage Error 'Client Office non trovato'
            return $false
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
        
        # 1. Download SaRA
        Write-StyledMessage Info '📥 Download Microsoft Support and Recovery Assistant (SaRA)...'
        try {
            if (-not (Test-Path $script:TempDir)) { New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null }
            
            $saraUrl = 'https://aka.ms/SaRA-Office_Uninstall'
            $saraPath = Join-Path $script:TempDir 'SaRAcmd.exe'
            $spinnerIndex = 0
            
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add('User-Agent', 'Mozilla/5.0')
            
            $downloadTask = $webClient.DownloadFileTaskAsync($saraUrl, $saraPath)
            while (-not $downloadTask.IsCompleted) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                Show-ProgressBar "Download SaRAcmd.exe" 'In corso...' 50 '📥' $spinner 'Cyan'
                Start-Sleep -Milliseconds 300
            }
            
            Show-ProgressBar "Download SaRAcmd.exe" 'Completato' 100 '📥'
            Write-Host ''
            $webClient.Dispose()
        }
        catch {
            Write-StyledMessage Error "Download di SaRA fallito: $_"
            return $false
        }
        
        # 2. Esecuzione di SaRA per la disinstallazione
        Write-StyledMessage Info '🚀 Avvio rimozione Office tramite SaRA...'
        Write-StyledMessage Info '💡 Questo processo potrebbe richiedere molto tempo. Attendere prego...'
        
        try {
            $arguments = '-S -AcceptEULA -OfficeVersion All -RemoveOffice'
            $process = Start-Process -FilePath $saraPath -ArgumentList $arguments -PassThru -Verb RunAs
            
            Wait-ProcessCompletion 'SaRAcmd' 'Rimozione Office in corso' '🗑️'
            
            if ($process.ExitCode -eq 0) {
                Write-StyledMessage Success '🎉 Rimozione tramite SaRA completata con successo!'
            }
            else {
                Write-StyledMessage Warning "SaRA ha terminato con codice: $($process.ExitCode). Un riavvio è comunque necessario."
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante l'esecuzione di SaRA: $_"
            return $false
        }
        finally {
            # 3. Pulizia
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
        '        Version 2.1 (Build 11)'
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