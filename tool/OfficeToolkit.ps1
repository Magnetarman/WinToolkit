function OfficeToolkit {
    <#
    .SYNOPSIS
        Strumento di gestione Microsoft Office (installazione, riparazione, rimozione)
    
    .DESCRIPTION
        Script PowerShell per gestire Microsoft Office tramite interfaccia utente semplificata.
        Supporta installazione Office Basic, riparazione Click-to-Run e rimozione completa con SaRA.
    #>
    
    param([int]$CountdownSeconds = 30)

    # Configurazione
    $TempDir = "$env:LOCALAPPDATA\WinToolkit\Office"
    $Log = [System.Collections.ArrayList]::new()
    $Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💡' }
    }

    # Funzioni Helper
    function Write-StyledMessage([string]$Type, [string]$Message) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Message" -ForegroundColor $style.Color
    }

    function Add-LogEntry([string]$Category, [string]$Level, [string]$Message) {
        $entry = "[{0}] {1} {2}" -f $Category, $Level, $Message
        [void]$Log.Add($entry)
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent) {
        $safePercent = [Math]::Max(0, [Math]::Min(100, $Percent))
        $filled = [Math]::Floor($safePercent * 30 / 100)
        $bar = "[$('█' * $filled)$('░' * (30 - $filled))] $safePercent%"
        Write-Host "`r🔄 $Activity $bar $Status" -NoNewline -ForegroundColor Yellow
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Show-Spinner([string]$Activity, [scriptblock]$Action) {
        $spinnerIndex = 0
        $job = Start-Job -ScriptBlock $Action
        
        while ($job.State -eq 'Running') {
            $spinner = $Spinners[$spinnerIndex++ % $Spinners.Length]
            Write-Host "`r$spinner $Activity..." -NoNewline -ForegroundColor Yellow
            Start-Sleep -Milliseconds 200
        }
        
        $result = Receive-Job $job -Wait
        Remove-Job $job
        Write-Host ''
        return $result
    }

    function Get-UserConfirmation([string]$Message, [string]$DefaultChoice = 'N') {
        do {
            $response = Read-Host "$Message [$DefaultChoice]"
            if ([string]::IsNullOrEmpty($response)) { $response = $DefaultChoice }
            $response = $response.ToUpper()
        } while ($response -notin @('Y', 'N'))
        return $response -eq 'Y'
    }

    function Start-CountdownRestart([string]$Reason) {
        Write-StyledMessage Info "🔄 $Reason - Il sistema verrà riavviato"
        Write-StyledMessage Info "💡 Premi un tasto qualsiasi per annullare..."
        
        for ($i = $CountdownSeconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning "⏸️ Riavvio annullato dall'utente"
                Add-LogEntry "Sistema" "ℹ️" "Riavvio annullato dall'utente"
                return $false
            }
            Write-Host "`r⏰ Riavvio automatico tra $i secondi..." -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }
        
        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."
        Add-LogEntry "Sistema" "✅" "Riavvio eseguito"
        
        try {
            Restart-Computer -Force
            return $true
        }
        catch {
            Write-StyledMessage Error "❌ Errore riavvio: $_"
            Add-LogEntry "Sistema" "❌" "Errore riavvio: $_"
            return $false
        }
    }

    function Stop-OfficeProcesses {
        $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
        $closed = 0
        
        Write-StyledMessage Info "📋 Chiusura processi Office..."
        
        foreach ($processName in $processes) {
            $runningProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($runningProcesses) {
                try {
                    $runningProcesses | Stop-Process -Force -ErrorAction Stop
                    $closed++
                }
                catch {
                    Write-StyledMessage Warning "⚠️ Impossibile chiudere: $processName"
                }
            }
        }
        
        if ($closed -gt 0) {
            Write-StyledMessage Success "✅ $closed processi Office chiusi"
            Add-LogEntry "Processi" "✅" "$closed processi Office chiusi"
        }
    }

    function Get-OfficeClient {
        $paths = @(
            "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe",
            "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
        )
        return $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
    }

    function Invoke-DownloadFile([string]$Url, [string]$OutputPath, [string]$Description) {
        try {
            Write-StyledMessage Info "📥 Download $Description..."
            
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $OutputPath)
            $webClient.Dispose()
            
            if (Test-Path $OutputPath) {
                Write-StyledMessage Success "✅ Download completato: $Description"
                Add-LogEntry "Download" "✅" "$Description scaricato"
                return $true
            }
            else {
                Write-StyledMessage Error "❌ File non trovato dopo download: $Description"
                Add-LogEntry "Download" "❌" "$Description - file non trovato"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "❌ Errore download $Description`: $_"
            Add-LogEntry "Download" "❌" "$Description - $_"
            return $false
        }
    }

    function Start-OfficeInstallation {
        Write-StyledMessage Info "🏢 Avvio installazione Office Basic..."
        Add-LogEntry "Installazione" "ℹ️" "Avvio installazione Office Basic"
        
        try {
            # Preparazione directory
            if (-not (Test-Path $TempDir)) {
                New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
            }
            
            # Download file necessari
            $setupPath = Join-Path $TempDir 'Setup.exe'
            $configPath = Join-Path $TempDir 'Basic.xml'
            
            $downloads = @(
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Setup.exe'; Path = $setupPath; Name = 'Setup Office' },
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Basic.xml'; Path = $configPath; Name = 'Configurazione Basic' }
            )
            
            foreach ($download in $downloads) {
                if (-not (Invoke-DownloadFile $download.Url $download.Path $download.Name)) {
                    return $false
                }
            }
            
            # Avvio installazione
            Write-StyledMessage Info "🚀 Avvio processo installazione..."
            $arguments = "/configure `"$configPath`""
            Start-Process -FilePath $setupPath -ArgumentList $arguments -WorkingDirectory $TempDir
            Add-LogEntry "Installazione" "ℹ️" "Processo avviato con argomenti: $arguments"
            
            # Attesa completamento
            Write-StyledMessage Info "⏳ Attesa completamento installazione..."
            Write-Host "💡 Premi INVIO quando l'installazione è completata..." -ForegroundColor Yellow
            Read-Host | Out-Null
            
            # Conferma risultato
            if (Get-UserConfirmation "✅ Installazione completata con successo?" 'Y') {
                Write-StyledMessage Success "🎉 Installazione Office completata!"
                Add-LogEntry "Installazione" "✅" "Installazione completata con successo"
                return $true
            }
            else {
                Write-StyledMessage Warning "⚠️ Installazione non completata correttamente"
                Add-LogEntry "Installazione" "⚠️" "Installazione non completata"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "❌ Errore durante installazione: $_"
            Add-LogEntry "Installazione" "❌" "Errore: $_"
            return $false
        }
        finally {
            # Pulizia
            if (Test-Path $TempDir) {
                Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    function Start-OfficeRepair {
        Write-StyledMessage Info "🔧 Avvio riparazione Office..."
        Add-LogEntry "Riparazione" "ℹ️" "Avvio processo riparazione"
        
        Stop-OfficeProcesses
        
        # Pulizia cache
        Write-StyledMessage Info "🧹 Pulizia cache Office..."
        $caches = @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )
        
        $cleanedCount = 0
        foreach ($cache in $caches) {
            if (Test-Path $cache) {
                try {
                    Remove-Item $cache -Recurse -Force -ErrorAction Stop
                    $cleanedCount++
                }
                catch {
                    Add-LogEntry "Pulizia" "⚠️" "Impossibile eliminare cache: $cache"
                }
            }
        }
        
        if ($cleanedCount -gt 0) {
            Write-StyledMessage Success "✅ $cleanedCount cache eliminate"
        }
        
        # Selezione tipo riparazione
        Write-StyledMessage Info "🎯 Tipo di riparazione:"
        Write-Host "  [1] 🚀 Riparazione rapida (offline)" -ForegroundColor Green
        Write-Host "  [2] 🌐 Riparazione completa (online)" -ForegroundColor Yellow
        
        do {
            $choice = Read-Host "Scelta [1-2]"
        } while ($choice -notin @('1', '2'))
        
        # Esecuzione riparazione
        try {
            $officeClient = Get-OfficeClient
            if (-not $officeClient) {
                Write-StyledMessage Error "❌ Office Click-to-Run non trovato"
                Add-LogEntry "Riparazione" "❌" "Office Click-to-Run non trovato"
                return $false
            }
            
            $repairType = if ($choice -eq '1') { 'QuickRepair' } else { 'FullRepair' }
            $repairName = if ($choice -eq '1') { 'rapida' } else { 'completa' }
            
            Write-StyledMessage Info "🔧 Avvio riparazione $repairName..."
            
            $arguments = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=$repairType DisplayLevel=True"
            Start-Process -FilePath $officeClient -ArgumentList $arguments -NoNewWindow
            Add-LogEntry "Riparazione" "ℹ️" "Avviata riparazione $repairType"
            
            # Attesa completamento
            Write-StyledMessage Info "⏳ Attesa completamento riparazione..."
            Write-Host "💡 Premi INVIO quando la riparazione è completata..." -ForegroundColor Yellow
            Read-Host | Out-Null
            
            # Conferma risultato
            if (Get-UserConfirmation "✅ Riparazione completata con successo?" 'Y') {
                Write-StyledMessage Success "🎉 Riparazione Office completata!"
                Add-LogEntry "Riparazione" "✅" "Riparazione $repairType completata"
                return $true
            }
            else {
                Write-StyledMessage Warning "⚠️ Riparazione non completata correttamente"
                Add-LogEntry "Riparazione" "⚠️" "Riparazione $repairType fallita"
                
                # Suggerimento riparazione completa se era rapida
                if ($choice -eq '1') {
                    if (Get-UserConfirmation "🌐 Tentare riparazione completa online?" 'Y') {
                        Write-StyledMessage Info "🌐 Avvio riparazione completa..."
                        $arguments = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True"
                        Start-Process -FilePath $officeClient -ArgumentList $arguments -NoNewWindow
                        
                        Write-Host "💡 Premi INVIO quando la riparazione completa è terminata..." -ForegroundColor Yellow
                        Read-Host | Out-Null
                        
                        return Get-UserConfirmation "✅ Riparazione completa riuscita?" 'Y'
                    }
                }
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "❌ Errore durante riparazione: $_"
            Add-LogEntry "Riparazione" "❌" "Errore: $_"
            return $false
        }
    }

    function Start-OfficeUninstall {
        Write-StyledMessage Warning "🗑️ Rimozione completa Microsoft Office"
        Write-StyledMessage Warning "⚠️ Verrà utilizzato Microsoft Support and Recovery Assistant (SaRA)"
        Add-LogEntry "Rimozione" "ℹ️" "Avvio processo rimozione completa"
        
        if (-not (Get-UserConfirmation "❓ Procedere con la rimozione completa?" 'N')) {
            Write-StyledMessage Info "❌ Operazione annullata"
            return $false
        }
        
        Stop-OfficeProcesses
        
        try {
            # Preparazione directory
            if (-not (Test-Path $TempDir)) {
                New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
            }
            
            # Download SaRA
            $saraUrl = 'https://aka.ms/SaRA_EnterpriseVersionFiles'
            $saraZipPath = Join-Path $TempDir 'SaRA.zip'
            
            if (-not (Invoke-DownloadFile $saraUrl $saraZipPath 'Microsoft SaRA')) {
                return $false
            }
            
            # Estrazione
            Write-StyledMessage Info "📦 Estrazione SaRA..."
            try {
                Expand-Archive -Path $saraZipPath -DestinationPath $TempDir -Force
                Write-StyledMessage Success "✅ Estrazione completata"
            }
            catch {
                Write-StyledMessage Error "❌ Errore estrazione: $_"
                Add-LogEntry "Estrazione" "❌" "Errore: $_"
                return $false
            }
            
            # Ricerca eseguibile SaRA
            $saraExe = Get-ChildItem -Path $TempDir -Name "SaRAcmd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $saraExe) {
                Write-StyledMessage Error "❌ SaRAcmd.exe non trovato"
                Add-LogEntry "Verifica" "❌" "SaRAcmd.exe non trovato"
                return $false
            }
            
            $saraPath = Join-Path $TempDir $saraExe
            
            # Esecuzione SaRA
            Write-StyledMessage Info "🚀 Avvio rimozione tramite SaRA..."
            Write-StyledMessage Warning "⏰ Questa operazione può richiedere molto tempo"
            
            $arguments = '-S OfficeScrubScenario -AcceptEula -OfficeVersion All'
            Start-Process -FilePath $saraPath -ArgumentList $arguments -Verb RunAs
            Add-LogEntry "Rimozione" "ℹ️" "SaRA avviato con argomenti: $arguments"
            
            # Attesa completamento
            Write-Host "💡 Premi INVIO quando SaRA ha completato la rimozione..." -ForegroundColor Yellow
            Read-Host | Out-Null
            
            # Conferma risultato
            if (Get-UserConfirmation "✅ Rimozione completata con successo?" 'Y') {
                Write-StyledMessage Success "🎉 Rimozione Office completata!"
                Add-LogEntry "Rimozione" "✅" "Rimozione completata con successo"
                return $true
            }
            else {
                Write-StyledMessage Warning "⚠️ Rimozione potrebbe essere incompleta"
                Add-LogEntry "Rimozione" "⚠️" "Rimozione potenzialmente incompleta"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "❌ Errore durante rimozione: $_"
            Add-LogEntry "Rimozione" "❌" "Errore: $_"
            return $false
        }
        finally {
            # Pulizia
            if (Test-Path $TempDir) {
                Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    function Show-Header {
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
            '        Version 2.2 (Build 27)'
        )
        
        foreach ($line in $asciiArt) {
            $padding = [Math]::Max(0, [Math]::Floor(($width - $line.Length) / 2))
            Write-Host (' ' * $padding + $line) -ForegroundColor White
        }
        
        Write-Host ('═' * $width) -ForegroundColor Green
        Write-Host ''
    }

    function Save-LogFile {
        if ($Log.Count -eq 0) { return }
        
        try {
            $logPath = "$env:USERPROFILE\Desktop\OfficeToolkit_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            $logHeader = @(
                "=== OFFICE TOOLKIT LOG ==="
                "Data: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
                "Versione: 2.2 (Build 27)"
                "Sistema: $env:COMPUTERNAME"
                "Utente: $env:USERNAME"
                "==========================="
                ""
            )
            
            ($logHeader + $Log) | Out-File -FilePath $logPath -Encoding UTF8
            Write-StyledMessage Success "📋 Log salvato: $logPath"
        }
        catch {
            Write-StyledMessage Warning "⚠️ Impossibile salvare log: $_"
        }
    }

    # MAIN EXECUTION
    Show-Header
    
    # Inizializzazione
    Write-Host "⏳ Inizializzazione sistema..." -ForegroundColor Yellow
    Start-Sleep 2
    Write-Host "✅ Sistema pronto`n" -ForegroundColor Green
    
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
            
            $choice = Read-Host 'Scelta [0-3]'
            Write-Host ''
            
            $success = $false
            $operation = ''
            
            switch ($choice) {
                '1' {
                    $operation = 'Installazione'
                    $success = Start-OfficeInstallation
                }
                '2' {
                    $operation = 'Riparazione'
                    $success = Start-OfficeRepair
                }
                '3' {
                    $operation = 'Rimozione'
                    $success = Start-OfficeUninstall
                }
                '0' {
                    Write-StyledMessage Info "👋 Uscita dal toolkit..."
                    Write-StyledMessage Success "✅ Grazie per aver utilizzato Office Toolkit!"
                    return
                }
                default {
                    Write-StyledMessage Warning "⚠️ Opzione non valida. Seleziona 0-3."
                    continue
                }
            }
            
            # Gestione post-operazione
            if ($choice -in @('1', '2', '3')) {
                if ($success) {
                    Write-StyledMessage Success "🎉 $operation completata!"
                    if (Get-UserConfirmation "🔄 Riavviare ora per finalizzare?" 'Y') {
                        Start-CountdownRestart "$operation completata"
                    }
                    else {
                        Write-StyledMessage Info "💡 Riavvia manualmente quando possibile"
                    }
                }
                else {
                    Write-StyledMessage Error "❌ $operation non riuscita"
                    Write-StyledMessage Info "💡 Controlla i log per dettagli o contatta il supporto"
                }
                Write-Host "`n" + ('─' * 50) + "`n"
            }
            
        } while ($choice -ne '0')
    }
    catch {
        Write-StyledMessage Error "❌ Errore critico: $($_.Exception.Message)"
        Add-LogEntry "Sistema" "❌" "Errore critico: $($_.Exception.Message)"
    }
    finally {
        # Pulizia finale
        Write-StyledMessage Info "🧹 Pulizia finale..."
        
        if (Test-Path $TempDir) {
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Save-LogFile
        
        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        Write-StyledMessage Success "🎯 Office Toolkit terminato"
    }
}

# Avvio automatico
OfficeToolkit