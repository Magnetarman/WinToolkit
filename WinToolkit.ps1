<#
.SYNOPSIS
    Un toolkit per eseguire script di manutenzione e gestione di Windows.
.DESCRIPTION
    Questo script funge da menu principale per un insieme di strumenti di manutenzione e gestione di Windows.
    Permette agli utenti di selezionare ed eseguire vari script PowerShell per compiti specifici.
.NOTES
  Versione 2.2 (Build 2) - 2025-09-23
#>

param([int]$CountdownSeconds = 10)

# Configurazione iniziale
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan"
$ErrorActionPreference = 'Stop'

# Setup logging
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\WinToolkit\logs"
try {
    [System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
    Start-Transcript -Path "$logdir\WinToolkit_$dateTime.log" -Append -Force | Out-Null
}
catch { }

function Write-StyledMessage {
    param(
        [ValidateSet('Success', 'Warning', 'Error', 'Info')]
        [string]$Type,
        [string]$Text
    )
    
    $styles = @{
        Success = @{ Color = 'Green' ; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'   ; Icon = '❌' }
        Info    = @{ Color = 'White' ; Icon = '🔎' }
    }
    
    $style = $styles[$Type]
    Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
}

function Center-Text {
    param([string]$Text, [int]$Width = 60)
    
    if ($Text.Length -ge $Width) { return $Text }
    $padding = ' ' * [Math]::Floor(($Width - $Text.Length) / 2)
    return "$padding$Text"
}

function winver {
    try {
        # Raccolta dati ottimizzata con singola query CIM
        $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $computerInfo = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        
        # Elaborazione dati
        $productName = $osInfo.Caption -replace 'Microsoft ', ''
        $buildNumber = [int]$osInfo.BuildNumber
        $totalRAM = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
        $totalDiskSpace = [Math]::Round($diskInfo.Size / 1GB, 0)
        $freePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)
        
        # Rilevazione tipo disco
        $diskType = "HDD"
        try {
            $physicalDisk = Get-CimInstance MSFT_PhysicalDisk -Namespace "Root\Microsoft\Windows\Storage" -ErrorAction SilentlyContinue |
            Where-Object { $_.DeviceID -eq 0 -or $_.MediaType -ne $null } | Select-Object -First 1
            if ($physicalDisk -and $physicalDisk.MediaType -eq 4) { $diskType = "SSD" }
        }
        catch {
            try {
                $diskDrive = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | Where-Object { $_.Index -eq 0 }
                if ($diskDrive.MediaType -like "*SSD*" -or $diskDrive.MediaType -like "*Solid State*") { $diskType = "SSD" }
            }
            catch { $diskType = "Disk" }
        }
        
        # Mappatura build -> versione Windows (hashtable per performance)
        $versionMap = @{
            26100 = "24H2"; 22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2"
            19045 = "22H2"; 19044 = "21H2"; 19043 = "21H1"; 19042 = "20H2"
            19041 = "2004"; 18363 = "1909"; 18362 = "1903"; 17763 = "1809"
            17134 = "1803"; 16299 = "1709"; 15063 = "1703"; 14393 = "1607"
            10586 = "1511"; 10240 = "1507"
        }
        
        $windowsVersion = "N/A"
        foreach ($build in ($versionMap.Keys | Sort-Object -Descending)) {
            if ($buildNumber -ge $build) {
                $windowsVersion = $versionMap[$build]
                break
            }
        }
        
        # Determinazione edizione
        $windowsEdition = switch -Wildcard ($productName) {
            "*Home*" { "🏠 Home" }
            "*Pro*" { "💼 Professional" }
            "*Enterprise*" { "🏢 Enterprise" }
            "*Education*" { "🎓 Education" }
            "*Server*" { "🖥️ Server" }
            default { "💻 $productName" }
        }
        
        # Output formattato
        $width = 65
        Write-Host ""
        Write-Host ('*' * $width) -ForegroundColor Red
        Write-Host (Center-Text "🖥️  INFORMAZIONI SISTEMA  🖥️" $width) -ForegroundColor White
        Write-Host ('*' * $width) -ForegroundColor Red
        Write-Host ""
        
        $info = @(
            @("💻 Edizione:", $windowsEdition, 'White'),
            @("📊 Versione Windows:", "Ver. $windowsVersion Kernel $($osInfo.Version) (Build $buildNumber)", 'Green'),
            @("🏗️ Architettura:", $osInfo.OSArchitecture, 'White'),
            @("🏷️ Nome PC:", $computerInfo.Name, 'White'),
            @("🧠 RAM Totale:", "$totalRAM GB", 'White'),
            @("💾 Disco:", "($diskType) $freePercentage% Libero ($totalDiskSpace GB Totali)", 'Green')
        )
        
        foreach ($item in $info) {
            Write-Host "  $($item[0])" -ForegroundColor Yellow -NoNewline
            Write-Host " $($item[1])" -ForegroundColor $item[2]
        }
        
        Write-Host ""
        Write-Host ('*' * $width) -ForegroundColor Red
    }
    catch {
        Write-StyledMessage 'Error' "Impossibile recuperare le informazioni di sistema: $($_.Exception.Message)"
    }
}

# Placeholder functions
function WinInstallPSProfile {
    <#
    .SYNOPSIS
        Script per installare il profilo PowerShell di ChrisTitusTech.
    .DESCRIPTION
        Questo script scarica e installa il profilo PowerShell personalizzato di ChrisTitusTech, che include configurazioni per oh-my-posh, font, e altre utilità.
        Lo script verifica se è in esecuzione con privilegi di amministratore e, in caso contrario, si rilancia con i permessi necessari.
        Inoltre, controlla se PowerShell Core è installato e se la versione di PowerShell è 7 o superiore.
        Se il profilo esistente è diverso dalla versione più recente disponibile online, lo aggiorna e crea un backup del profilo precedente.
        Al termine dell'installazione, offre la possibilità di riavviare il sistema per applicare tutte le modifiche.
    #>
    $Host.UI.RawUI.WindowTitle = "InstallPSProfile by MagnetarMan"
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
        '   Install PSProfile By MagnetarMan',
        '        Version 2.1 (Build 5)'
    )
    foreach ($line in $asciiArt) {
        Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
    }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''

    # Controlla se lo script è eseguito come amministratore
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-StyledMessage 'Warning' "L'installazione del profilo PowerShell richiede privilegi di amministratore."
        Write-StyledMessage 'Info' "Riavvio come amministratore..."
        
        # Rilancia lo script corrente come amministratore
        try {
            $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { WinInstallPSProfile }`""
            Start-Process PowerShell -Verb RunAs -ArgumentList $arguments
            return
        }
        catch {
            Write-StyledMessage 'Error' "Impossibile elevare i privilegi: $($_.Exception.Message)"
            Write-StyledMessage 'Error' "Esegui PowerShell come amministratore e riprova."
            return
        }
    }
    
    Write-StyledMessage 'Info' "Installazione del profilo PowerShell in corso..."
    
    try {
        # Verifica se PowerShell Core è disponibile
        if (-not (Get-Command "pwsh" -ErrorAction SilentlyContinue)) {
            Write-StyledMessage 'Error' "Questo profilo richiede PowerShell Core, che non è attualmente installato!"
            return
        }
        
        # Verifica la versione di PowerShell
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-StyledMessage 'Warning' "Questo profilo richiede PowerShell 7 o superiore."
            
            # Chiedi conferma per procedere comunque
            $choice = Read-Host "Vuoi procedere comunque con l'installazione per PowerShell 7? (S/N)"
            if ($choice -notmatch '^[SsYy]') {
                Write-StyledMessage 'Info' "Installazione annullata dall'utente."
                return
            }
        }
        
        # URL del profilo per il controllo degli aggiornamenti
        $profileUrl = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        
        # Ottieni l'hash del profilo corrente (se esiste)
        $oldHash = $null
        if (Test-Path $PROFILE) {
            $oldHash = Get-FileHash $PROFILE -ErrorAction SilentlyContinue
        }
        
        # Scarica il nuovo profilo nella cartella TEMP per confronto
        Write-StyledMessage 'Info' "Controllo aggiornamenti profilo..."
        $tempProfile = "$env:TEMP\Microsoft.PowerShell_profile.ps1"
        Invoke-RestMethod $profileUrl -OutFile $tempProfile -UseBasicParsing
        
        # Ottieni l'hash del nuovo profilo
        $newHash = Get-FileHash $tempProfile
        
        # Crea la directory del profilo se non esiste
        $profileDir = Split-Path $PROFILE -Parent
        if (!(Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        
        # Salva l'hash per riferimenti futuri
        if (!(Test-Path "$PROFILE.hash")) {
            $newHash.Hash | Out-File "$PROFILE.hash"
        }
        
        # Controlla se il profilo deve essere aggiornato
        if ($newHash.Hash -ne $oldHash.Hash) {
            
            # Backup del profilo esistente
            if ((Test-Path $PROFILE) -and (-not (Test-Path "$PROFILE.bak"))) {
                Write-StyledMessage 'Info' "Backup del profilo esistente..."
                Copy-Item -Path $PROFILE -Destination "$PROFILE.bak" -Force
                Write-StyledMessage 'Success' "Backup completato."
            }
            
            # QUESTO È IL PUNTO CRUCIALE: esegui lo script di SETUP, non solo scaricare il profilo
            Write-StyledMessage 'Info' "Installazione profilo e dipendenze (oh-my-posh, font, ecc.)..."
            
            # Esegui lo script di setup che installa tutto (oh-my-posh, font, dipendenze)
            Start-Process -FilePath "pwsh" `
                -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1')`"" `
                -Wait
            
            Write-StyledMessage 'Success' "Profilo PowerShell installato correttamente!"
            Write-StyledMessage 'Warning' "Riavvia PowerShell per applicare il nuovo profilo."
            Write-StyledMessage 'Info' "Per vedere tutte le modifiche (font, oh-my-posh, ecc.) è consigliato riavviare il sistema."
            
            # Chiedi se riavviare il sistema
            Write-Host ""
            $restart = Read-Host "Vuoi riavviare il sistema ora per applicare tutte le modifiche? (Y/N)"
            
            if ($restart -match '^[YySs]') {
                Write-StyledMessage 'Warning' "Riavvio del sistema in corso..."
                
                # Countdown di 5 secondi
                for ($i = 5; $i -gt 0; $i--) {
                    Write-Host "Riavvio tra $i secondi..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
                
                # Riavvia il sistema
                Write-StyledMessage 'Info' "Riavvio del sistema..."
                Restart-Computer -Force
            }
            else {
                Write-StyledMessage 'Info' "Riavvio annullato. Ricorda di riavviare il sistema per vedere tutte le modifiche."
            }
        }
        else {
            Write-StyledMessage 'Info' "Il profilo è già aggiornato alla versione più recente."
        }
        
        # Pulisci il file temporaneo
        Remove-Item $tempProfile -Force -ErrorAction SilentlyContinue
        
    }
    catch {
        Write-StyledMessage 'Error' "Errore durante l'installazione del profilo: $($_.Exception.Message)"
        
        # Pulisci i file temporanei in caso di errore
        if (Test-Path "$env:TEMP\Microsoft.PowerShell_profile.ps1") {
            Remove-Item "$env:TEMP\Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
        }
    }

}
function WinRepairToolkit {
    <#
    .SYNOPSIS
        Script per la riparazione del sistema Windows con strumenti integrati.
    
    .DESCRIPTION
        Questo script esegue una serie di strumenti di riparazione di Windows (chkdsk, SFC, DISM) in sequenza,
        con monitoraggio del progresso, gestione degli errori e tentativi di riparazione multipli.
        Al termine, offre un'opzione per una riparazione profonda del disco che richiede un riavvio.
        Infine, gestisce il riavvio del sistema con un conto alla rovescia interattivo.
    #>

    param([int]$MaxRetryAttempts = 3, [int]$CountdownSeconds = 30)

    # Variabili globali consolidate
    $script:Log = @(); $script:CurrentAttempt = 0
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }; Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error = @{ Color = 'Red'; Icon = '❌' }; Info = @{ Color = 'Cyan'; Icon = '💎' }
    }
    $RepairTools = @(
        @{ Tool = 'chkdsk'; Args = @('/scan', '/perf'); Name = 'Controllo disco'; Icon = '💽' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (1)'; Icon = '🗂️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Name = 'Ripristino immagine Windows'; Icon = '🛠️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'); Name = 'Pulizia Residui Aggiornamenti'; Icon = '🕸️' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (2)'; Icon = '🗂️' }
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
        Write-StyledMessage Info '💡 Premi un tasto qualsiasi per annullare...'
        Write-Host ''
        
        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning '⏸️ Riavvio automatico annullato'
                Write-StyledMessage Info "🔄 Puoi riavviare manualmente: 'shutdown /r /t 0' o dal menu Start."
                return $false
            }
            
            # Barra di progressione countdown con colore rosso
            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"
            
            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }
        
        Write-Host "`n"
        Write-StyledMessage Warning '⏰ Tempo scaduto: il sistema verrà riavviato ora.'
        Start-Sleep 1
        return $true
    }

    function Invoke-RepairCommand([hashtable]$Config, [int]$Step, [int]$Total) {
        Write-StyledMessage Info "[$Step/$Total] Avvio $($Config.Name)..."
        $percent = 0; $spinnerIndex = 0; $isChkdsk = ($Config.Tool -ieq 'chkdsk')
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()
    
        try {
            # Preparazione comando ottimizzata
            $proc = if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
                $drive = ($Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1) ?? $env:SystemDrive
                $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }
                Start-Process 'cmd.exe' @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ')") -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
            }
            else {
                Start-Process $Config.Tool $Config.Args -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
            }
        
            # Monitoraggio progresso consolidato
            while (-not $proc.HasExited) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                if ($isChkdsk) {
                    Show-ProgressBar $Config.Name 'Esecuzione in corso ...' 0 $Config.Icon $spinner 'Yellow'
                }
                else {
                    if ($percent -lt 95) { $percent += Get-Random -Minimum 1 -Maximum 3 }
                    Show-ProgressBar $Config.Name 'Esecuzione in corso...' $percent $Config.Icon $spinner
                }
                Start-Sleep -Milliseconds 600
                $proc.Refresh()
            }
        
            # Lettura risultati consolidata
            $results = @()
            @($outFile, $errFile) | Where-Object { Test-Path $_ } | ForEach-Object { 
                $results += Get-Content $_ -ErrorAction SilentlyContinue 
            }
        
            # Check scheduling per chkdsk ottimizzato
            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r') -and 
                ($results -join ' ').ToLower() -match 'schedule|next time.*restart|volume.*in use') {
                Write-StyledMessage Info "🔧 $($Config.Name): controllo schedulato al prossimo riavvio"
                $script:Log += "[$($Config.Name)] ℹ️ Controllo disco schedulato al prossimo riavvio"
                return @{ Success = $true; ErrorCount = 0 }
            }
        
            Show-ProgressBar $Config.Name 'Completato con successo' 100 $Config.Icon
            Write-Host ''
        
            # Analisi risultati
            $exitCode = $proc.ExitCode
            $hasDismSuccess = ($Config.Tool -ieq 'DISM') -and ($results -match '(?i)completed successfully')
            $isSuccess = ($exitCode -eq 0) -or $hasDismSuccess
        
            $errors = $warnings = @()
            if (-not $isSuccess) {
                foreach ($line in ($results | Where-Object { $_ -and ![string]::IsNullOrWhiteSpace($_.Trim()) })) {
                    $trim = $line.Trim()
                    if ($trim -match '^\[=+\s*\d+' -or $trim -match '(?i)version:|deployment image') { continue }
                    
                    if ($trim -match '(?i)(errore|error|failed|impossibile|corrotto|corruption)') { $errors += $trim }
                    elseif ($trim -match '(?i)(warning|avviso|attenzione)') { $warnings += $trim }
                }
            }
        
            $success = ($errors.Count -eq 0) -or $hasDismSuccess
            $message = "$($Config.Name) completato " + $(if ($success) { 'con successo' } else { "con $($errors.Count) errori" })
            Write-StyledMessage $(if ($success) { 'Success' } else { 'Warning' }) $message
        
            # Logging consolidato
            $logStatus = if ($success) { '✅ Successo' } else { "⚠️ $($errors.Count) errori" }
            if ($warnings.Count -gt 0) { $logStatus += " - $($warnings.Count) avvisi" }
            $script:Log += "[$($Config.Name)] $logStatus"
        
            return @{ Success = $success; ErrorCount = $errors.Count }
        
        }
        catch {
            Write-StyledMessage Error "Errore durante $($Config.Name): $_"
            $script:Log += "[$($Config.Name)] ❌ Errore fatale: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
        finally {
            Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
        }
    }

    function Start-RepairCycle([int]$Attempt = 1) {
        $script:CurrentAttempt = $Attempt
        Write-StyledMessage Info "🔄 Tentativo $Attempt/$MaxRetryAttempts - Riparazione sistema ($($RepairTools.Count) strumenti)..."
        Write-Host ''
    
        $totalErrors = $successCount = 0
        for ($i = 0; $i -lt $RepairTools.Count; $i++) {
            $result = Invoke-RepairCommand $RepairTools[$i] ($i + 1) $RepairTools.Count
            if ($result.Success) { $successCount++ }
            $totalErrors += $result.ErrorCount
            Start-Sleep 1
        }
    
        Write-StyledMessage Info "🎯 Completati $successCount/$($RepairTools.Count) strumenti (Errori: $totalErrors)."
    
        if ($totalErrors -gt 0 -and $Attempt -lt $MaxRetryAttempts) {
            Write-Host ''
            Write-StyledMessage Warning "🔄 $totalErrors errori rilevati. Nuovo tentativo..."
            Start-Sleep 3
            Write-Host ''
            return Start-RepairCycle ($Attempt + 1)
        }
    
        return @{ Success = ($totalErrors -eq 0); TotalErrors = $totalErrors; AttemptsUsed = $Attempt }
    }

    function Start-DeepDiskRepair {
        Write-StyledMessage Warning '🔧 Vuoi eseguire una riparazione profonda del disco C:?'
        Write-StyledMessage Info 'Questa operazione richiederà un riavvio e può richiedere diverse ore.'
    
        $response = Read-Host 'Procedere con la riparazione profonda? (s/n)'
        if ($response.ToLower() -ne 's') { return $false }
    
        Write-StyledMessage Warning 'Segno il volume C: come "dirty" (chkdsk al prossimo riavvio) e apro una cmd per output.'
        $script:Log += "[Controllo disco Esteso] ℹ️ Segno volume dirty e apro cmd"
    
        try {
            Start-Process 'fsutil.exe' @('dirty', 'set', 'C:') -NoNewWindow -Wait
            Start-Process 'cmd.exe' @('/c', 'echo Y | chkdsk C: /f /r /v /x /b') -WindowStyle Hidden -Wait
            Write-StyledMessage Info 'Comando chkdsk inviato (finestra nascosta). Riavvia il sistema per eseguire la scansione profonda.'
            $script:Log += "[Controllo disco Esteso] ✅ chkdsk eseguito in background; riavviare per applicare"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore eseguendo operazione: $_"
            $script:Log += "[Controllo disco Esteso] ❌ Errore: $_"
            return $false
        }
    }

    function Start-SystemRestart([hashtable]$RepairResult) {
        if ($RepairResult.Success) {
            Write-StyledMessage Info '🎉 Riparazione completata con successo!'
            Write-StyledMessage Info "🎯 Errori risolti in $($RepairResult.AttemptsUsed) tentativo/i."
        }
        else {
            Write-StyledMessage Warning "⚠️ $($RepairResult.TotalErrors) errori persistenti dopo $($RepairResult.AttemptsUsed) tentativo/i."
            Write-StyledMessage Info '📋 Controlla il log sul Desktop. 💡 Il riavvio potrebbe risolvere problemi residui.'
        }
    
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
            Write-StyledMessage Info '💡 Riavvia quando possibile per applicare le riparazioni.'
        }
    }

    function Center-Text([string]$Text, [int]$Width) {
        $padding = [math]::Max(0, [math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding) + $Text
    }

    # Interfaccia principale
    $Host.UI.RawUI.WindowTitle = "Repair Toolkit By MagnetarMan"
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
        '     Repair Toolkit By MagnetarMan',
        '        Version 2.1 (Build 4)'
    )
    
    $asciiArt | ForEach-Object { Write-Host (Center-Text -Text $_ -Width $width) -ForegroundColor White }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''

    # Countdown preparazione ottimizzato
    for ($i = 5; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    try {
        $repairResult = Start-RepairCycle
        $deepRepairScheduled = Start-DeepDiskRepair
    
        if ($deepRepairScheduled) {
            Write-StyledMessage Warning 'Il sistema verrà riavviato per eseguire la riparazione profonda...'
        }
        Start-SystemRestart $repairResult
    
    }
    catch {
        Write-StyledMessage Error "❌ Errore critico: $($_.Exception.Message)"
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
    }

}
function ResetRustDesk {
    Write-StyledMessage 'Warning' "Sviluppo funzione in corso"
    Write-Host "
Premi un tasto per tornare al menu principale..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
function WinUpdateReset {
    <#
    .SYNOPSIS
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI.
    
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

    # FUNZIONE OTTIMIZZATA per eliminazione sicura delle directory
    function Remove-DirectorySafely([string]$Path, [string]$DisplayName) {
        if (-not (Test-Path $Path)) {
            Write-StyledMessage Info "💭 Directory $DisplayName non presente."
            return $true
        }

        try {
            # Prima prova: eliminazione diretta usando il cmdlet nativo
            Microsoft.PowerShell.Management\Remove-Item $Path -Recurse -Force -ErrorAction Stop
            
            # FIX: Assicura output pulito dopo eliminazione
            Write-Host "`r$(' ' * 120)" -NoNewline
            Write-Host "`r" -NoNewline
            Write-StyledMessage Success "🗑️ Directory $DisplayName eliminata."
            return $true
        }
        catch {
            # FIX: Pulisce output prima del messaggio di warning
            Write-Host "`r$(' ' * 120)" -NoNewline
            Write-Host "`r" -NoNewline
            Write-StyledMessage Warning "Tentativo fallito, provo con eliminazione selettiva..."
        
            try {
                if (Test-Path $Path) {
                    Get-ChildItem -Path $Path -Recurse -Force | ForEach-Object {
                        try {
                            Microsoft.PowerShell.Management\Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        catch {
                            # Ignora errori su singoli file
                        }
                    }
                
                    # Prova finale a eliminare la directory principale
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
        '       Version 2.2 (Build 4)'
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
            
            Start-Sleep -Milliseconds 500
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
function WinReinstallStore {
    <#
    .SYNOPSIS
        Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget.
    
    .DESCRIPTION
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI senza output bloccanti.
    #>
    
    param([int]$CountdownSeconds = 30)
    
    # Inizializzazione
    $Host.UI.RawUI.WindowTitle = "Store Repair Toolkit By MagnetarMan"
    
    # Configurazione globale
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }; Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error = @{ Color = 'Red'; Icon = '❌' }; Info = @{ Color = 'Cyan'; Icon = '💎' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }
    
    # Funzione per centrare il testo
    function Center-Text {
        param([string]$Text, [int]$Width)
        $padding = [math]::Max(0, ($Width - $Text.Length) / 2)
        return (' ' * [math]::Floor($padding)) + $Text
    }
    
    # Header grafico
    function Show-Header {
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
            '        Store Repair Toolkit By MagnetarMan',
            '        Version 2.2 (Build 26)'
        )
        foreach ($line in $asciiArt) {
            Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
        }
        Write-Host ('═' * $width) -ForegroundColor Green
        Write-Host ''
    }
    
    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }
    
    function Clear-Terminal {
        # Pulizia aggressiva multi-metodo
        1..50 | ForEach-Object { Write-Host "" }  # Forza scroll
        Clear-Host
        [Console]::Clear()
        try { 
            [System.Console]::SetCursorPosition(0, 0)
            $Host.UI.RawUI.CursorPosition = @{X = 0; Y = 0 }
        }
        catch {}
        Start-Sleep -Milliseconds 200
    }
    
    function Stop-InterferingProcesses {
        @("WinStore.App", "wsappx", "AppInstaller", "Microsoft.WindowsStore", 
            "Microsoft.DesktopAppInstaller", "RuntimeBroker", "dllhost") | ForEach-Object {
            Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep 2
    }
    
    function Test-WingetAvailable {
        try {
            $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $null = & winget --version 2>$null
            return $LASTEXITCODE -eq 0
        }
        catch { return $false }
    }
    
    function Install-WingetSilent {
        Write-StyledMessage Progress "Reinstallazione Winget in corso..."
        Stop-InterferingProcesses
        
        try {
            # Metodo 1: Repair se disponibile (Windows 11 24H2+)
            if ([System.Environment]::OSVersion.Version.Build -ge 26100) {
                try {
                    if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                        $null = Repair-WinGetPackageManager -Force -Latest 2>$null
                        Start-Sleep 5
                        if (Test-WingetAvailable) { return $true }
                    }
                }
                catch {}
            }
            
            # Metodo 2: Download diretto con esecuzione completamente nascosta
            $url = "https://aka.ms/getwinget"
            $temp = "$env:TEMP\WingetInstaller.msixbundle"
            if (Test-Path $temp) { Remove-Item $temp -Force }
            
            Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing
            
            # Esecuzione in subprocess completamente isolato
            $process = Start-Process powershell -ArgumentList @(
                "-NoProfile", "-WindowStyle", "Hidden", "-Command",
                "try { Add-AppxPackage -Path '$temp' -ForceApplicationShutdown -ErrorAction Stop } catch { exit 1 }; exit 0"
            ) -Wait -PassThru -WindowStyle Hidden
            
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
            Start-Sleep 5
            
            return (Test-WingetAvailable)
        }
        catch {
            return $false
        }
    }
    
    function Install-MicrosoftStoreSilent {
        Write-StyledMessage Progress "Reinstallazione Microsoft Store in corso..."
        
        # Reset servizi
        @("AppXSvc", "ClipSVC", "WSService") | ForEach-Object {
            try { Restart-Service $_ -Force -ErrorAction SilentlyContinue } catch {}
        }
        
        # Pulizia cache
        @("$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache") | ForEach-Object {
            if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue }
        }
        
        # Metodi di installazione
        $methods = @(
            # Winget
            {
                if (Test-WingetAvailable) {
                    $process = Start-Process winget -ArgumentList "install 9WZDNCRFJBMP --accept-source-agreements --accept-package-agreements --silent --disable-interactivity" -Wait -PassThru -WindowStyle Hidden
                    return $process.ExitCode -eq 0
                }
                return $false
            },
            # Manifest
            {
                $store = Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue
                if ($store) {
                    $store | ForEach-Object {
                        $manifest = "$($_.InstallLocation)\AppXManifest.xml"
                        if (Test-Path $manifest) {
                            $process = Start-Process powershell -ArgumentList @(
                                "-NoProfile", "-WindowStyle", "Hidden", "-Command",
                                "Add-AppxPackage -DisableDevelopmentMode -Register '$manifest' -ForceApplicationShutdown"
                            ) -Wait -PassThru -WindowStyle Hidden
                        }
                    }
                    return $true
                }
                return $false
            },
            # DISM
            {
                $process = Start-Process DISM -ArgumentList "/Online /Add-Capability /CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0" -Wait -PassThru -WindowStyle Hidden
                return $process.ExitCode -eq 0
            }
        )
        
        foreach ($method in $methods) {
            try {
                if (& $method) {
                    Start-Process wsreset.exe -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                    return $true
                }
            }
            catch { continue }
        }
        return $false
    }
    
    function Install-UniGetUISilent {
        Write-StyledMessage Progress "Reinstallazione UniGet UI in corso..."
        if (-not (Test-WingetAvailable)) { return $false }
        
        try {
            # Disinstalla se presente
            $null = Start-Process winget -ArgumentList "uninstall --exact --id MartiCliment.UniGetUI --silent --disable-interactivity" -Wait -PassThru -WindowStyle Hidden
            Start-Sleep 2
            
            # Installa sempre
            $process = Start-Process winget -ArgumentList "install --exact --id MartiCliment.UniGetUI --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity --force" -Wait -PassThru -WindowStyle Hidden
            return $process.ExitCode -eq 0
        }
        catch {
            return $false
        }
    }
    
    function Start-CountdownReboot([int]$Seconds) {
        Write-StyledMessage Warning "Riavvio necessario per applicare le modifiche"
        Write-StyledMessage Info '💡 Premi un tasto qualsiasi per annullare...'
        
        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning "⏸️ Riavvio automatico annullato"
                Write-StyledMessage Error 'Riavvia manualmente: shutdown /r /t 0'
                return $false
            }
            
            # Barra di progressione countdown identica al riferimento
            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"
            
            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }
        
        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."
        
        try {
            shutdown /r /t 0
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore riavvio: $_"
            return $false
        }
    }
    
    # === ESECUZIONE PRINCIPALE ===
    Show-Header
    Write-StyledMessage Info "🚀 AVVIO REINSTALLAZIONE STORE"
    
    try {
        # FASE 1: Winget
        Write-StyledMessage Info "📋 FASE 1: Winget"
        $wingetResult = Install-WingetSilent
        Clear-Terminal
        Show-Header
        Write-StyledMessage $(if ($wingetResult) { 'Success' }else { 'Warning' }) "$(if($wingetResult){'✅'}else{'⚠️'}) Winget $(if($wingetResult){'installato'}else{'processato'})"
        
        # FASE 2: Microsoft Store  
        Write-StyledMessage Info "📋 FASE 2: Microsoft Store"
        $storeResult = Install-MicrosoftStoreSilent
        if (-not $storeResult) {
            Write-StyledMessage Error "❌ Errore installazione Microsoft Store"
            Write-StyledMessage Info "💡 Verifica: Internet, Admin, Windows Update"
            return
        }
        Write-StyledMessage Success "✅ Microsoft Store installato"
        
        # FASE 3: UniGet UI
        Write-StyledMessage Info "📋 FASE 3: UniGet UI" 
        $unigetResult = Install-UniGetUISilent
        Write-StyledMessage $(if ($unigetResult) { 'Success' }else { 'Warning' }) "$(if($unigetResult){'✅'}else{'⚠️'}) UniGet UI $(if($unigetResult){'installato'}else{'processato'})"
        
        # Completamento
        Write-Host ""
        Write-StyledMessage Success "🎉 OPERAZIONE COMPLETATA"
        
        if (Start-CountdownReboot -Seconds $CountdownSeconds) {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
        }
    }
    catch {
        Clear-Terminal
        Show-Header
        Write-StyledMessage Error "❌ ERRORE: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Esegui come Admin, verifica Internet e Windows Update"
    }

}
function WinDriverInstall {
    Write-StyledMessage 'Warning' "Sviluppo funzione in corso"
    Write-Host "
Premi un tasto per tornare al menu principale..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
function WinBackupDriver {
    Write-StyledMessage 'Warning' "Sviluppo funzione in corso"
    Write-Host "
Premi un tasto per tornare al menu principale..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
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

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent) {
        $safePercent = [Math]::Max(0, [Math]::Min(100, $Percent))
        $filled = [Math]::Floor($safePercent * 30 / 100)
        $bar = "[$('█' * $filled)$('▒' * (30 - $filled))] $safePercent%"
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
                return $false
            }
            
            # Barra di progressione countdown con colore rosso
            $percent = [Math]::Round((($CountdownSeconds - $i) / $CountdownSeconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"
            
            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }
        
        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."
        
        try {
            Restart-Computer -Force
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore riavvio: $_"
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
                    Write-StyledMessage Warning "Impossibile chiudere: $processName"
                }
            }
        }
        
        if ($closed -gt 0) {
            Write-StyledMessage Success "$closed processi Office chiusi"
        }
    }

    function Get-OfficeClient {
        $paths = @(
            "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe",
            "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
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
                Write-StyledMessage Success "Download completato: $Description"
                return $true
            }
            else {
                Write-StyledMessage Error "File non trovato dopo download: $Description"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore download $Description`: $_"
            return $false
        }
    }

    function Start-OfficeInstallation {
        Write-StyledMessage Info "🏢 Avvio installazione Office Basic..."
        
        try {
            # Preparazione directory
            if (-not (Test-Path $TempDir)) {
                New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
            }
            
            # Download file necessari
            $setupPath = Join-Path $TempDir 'Setup.exe'
            $configPath = Join-Path $TempDir 'Basic.xml'
            
            $downloads = @(
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Setup.exe'; Path = $setupPath; Name = 'Setup Office' },
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Basic.xml'; Path = $configPath; Name = 'Configurazione Basic' }
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
            
            # Attesa completamento
            Write-StyledMessage Info "⏳ Attesa completamento installazione..."
            Write-Host "💡 Premi INVIO quando l'installazione è completata..." -ForegroundColor Yellow
            Read-Host | Out-Null
            
            # Conferma risultato
            if (Get-UserConfirmation "✅ Installazione completata con successo?" 'Y') {
                Write-StyledMessage Success "🎉 Installazione Office completata!"
                return $true
            }
            else {
                Write-StyledMessage Warning "Installazione non completata correttamente"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante installazione: $_"
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
                    # Ignora errori di cache
                }
            }
        }
        
        if ($cleanedCount -gt 0) {
            Write-StyledMessage Success "$cleanedCount cache eliminate"
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
                Write-StyledMessage Error "Office Click-to-Run non trovato"
                return $false
            }
            
            $repairType = if ($choice -eq '1') { 'QuickRepair' } else { 'FullRepair' }
            $repairName = if ($choice -eq '1') { 'rapida' } else { 'completa' }
            
            Write-StyledMessage Info "🔧 Avvio riparazione $repairName..."
            
            # Correzione: uso il percorso completo con & e parametri corretti
            $arguments = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=$repairType DisplayLevel=True"
            Start-Process -FilePath $officeClient -ArgumentList $arguments -Wait:$false
            
            # Attesa completamento
            Write-StyledMessage Info "⏳ Attesa completamento riparazione..."
            Write-Host "💡 Premi INVIO quando la riparazione è completata..." -ForegroundColor Yellow
            Read-Host | Out-Null
            
            # Conferma risultato
            if (Get-UserConfirmation "✅ Riparazione completata con successo?" 'Y/N') {
                Write-StyledMessage Success "🎉 Riparazione Office completata!"
                return $true
            }
            else {
                Write-StyledMessage Warning "Riparazione non completata correttamente"
                
                # Suggerimento riparazione completa se era rapida
                if ($choice -eq '1') {
                    if (Get-UserConfirmation "🌐 Tentare riparazione completa online?" 'Y') {
                        Write-StyledMessage Info "🌐 Avvio riparazione completa (Riparazione Online)"
                        $arguments = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True"
                        Start-Process -FilePath $officeClient -ArgumentList $arguments -Wait:$false
                        
                        Write-Host "💡 Premi INVIO quando la riparazione completa è terminata..." -ForegroundColor Yellow
                        Read-Host | Out-Null
                        
                        return Get-UserConfirmation "✅ Riparazione completa riuscita?" 'Y/N'
                    }
                }
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante riparazione: $_"
            return $false
        }
    }

    function Start-OfficeUninstall {
        Write-StyledMessage Warning "🗑️ Rimozione completa Microsoft Office, Verrà utilizzato Microsoft Support and Recovery Assistant (SaRA)"
        
        if (-not (Get-UserConfirmation "❓ Procedere con la rimozione completa? [Y/N]")) {
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
                Write-StyledMessage Success "Estrazione completata"
            }
            catch {
                Write-StyledMessage Error "Errore estrazione: $_"
                return $false
            }
            
            # Ricerca eseguibile SaRA
            $saraExe = Get-ChildItem -Path $TempDir -Name "SaRAcmd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $saraExe) {
                Write-StyledMessage Error "SaRAcmd.exe non trovato"
                return $false
            }
            
            $saraPath = Join-Path $TempDir $saraExe
            
            # Esecuzione SaRA
            Write-StyledMessage Info "🚀 Avvio rimozione tramite SaRA..."
            Write-StyledMessage Warning "⏰ Questa operazione può richiedere molto tempo"
            Write-StyledMessage Warning "🚀 Ad operazione avviata, non chiudere la finestra di SaRA, la finestra si chiuderà automaticamente"
            
            $arguments = '-S OfficeScrubScenario -AcceptEula -OfficeVersion All'
            Start-Process -FilePath $saraPath -ArgumentList $arguments -Verb RunAs
            
            # Attesa completamento
            Write-Host "💡 Premi INVIO quando SaRA ha completato la rimozione..." -ForegroundColor Yellow
            Read-Host | Out-Null
            
            # Conferma risultato
            if (Get-UserConfirmation "✅ Rimozione completata con successo?" 'Y') {
                Write-StyledMessage Success "🎉 Rimozione Office completata!"
                return $true
            }
            else {
                Write-StyledMessage Warning "Rimozione potrebbe essere incompleta"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante rimozione: $_"
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
            '        Version 2.1 (Build 32)'
        )
        
        foreach ($line in $asciiArt) {
            $padding = [Math]::Max(0, [Math]::Floor(($width - $line.Length) / 2))
            Write-Host (' ' * $padding + $line) -ForegroundColor White
        }
        
        Write-Host ('═' * $width) -ForegroundColor Green
        Write-Host ''
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
                    return
                }
                default {
                    Write-StyledMessage Warning "Opzione non valida. Seleziona 0-3."
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
                    Write-StyledMessage Error "$operation non riuscita"
                    Write-StyledMessage Info "💡 Controlla i log per dettagli o contatta il supporto"
                }
                Write-Host "`n" + ('─' * 50) + "`n"
            }
            
        } while ($choice -ne '0')
    }
    catch {
        Write-StyledMessage Error "Errore critico: $($_.Exception.Message)"
    }
    finally {
        # Pulizia finale
        Write-StyledMessage Success "🧹 Pulizia finale..."
        
        if (Test-Path $TempDir) {
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        Write-StyledMessage Success "🎯 Office Toolkit terminato"
    }

}
function GamingToolkit {
    Write-StyledMessage 'Warning' "Sviluppo funzione in corso"
    Write-Host "
Premi un tasto per tornare al menu principale..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

# Menu structure
$menuStructure = @(
    @{
        'Name' = 'Operazioni Preliminari'; 'Icon' = '🪄'
        'Scripts' = @([pscustomobject]@{ Name = 'WinInstallPSProfile'; Description = 'Installa il profilo PowerShell.'; Action = 'RunFunction' })
    },
    @{
        'Name' = 'Backup & Tool'; 'Icon' = '📦'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'ResetRustDesk'; Description = 'Reset Rust Desk. - Planned V2.2'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinBackupDriver'; Description = 'Backup Driver PC. - Planned V2.2'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'OfficeToolkit'; Description = 'Office Toolkit.'; Action = 'RunFunction' }
        )
    },
    @{
        'Name' = 'Riparazione Windows'; 'Icon' = '🔧'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'WinRepairToolkit'; Description = 'Toolkit Riparazione Windows.'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinUpdateReset'; Description = 'Reset di Windows Update.'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset.'; Action = 'RunFunction' }
        )
    },
    @{
        'Name' = 'Driver & Gaming'; 'Icon' = '🎮'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'WinDriverInstall'; Description = 'Toolkit Driver Grafici. - Planned V2.3'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'GamingToolkit'; Description = 'Gaming Toolkit. - Planned V2.4'; Action = 'RunFunction' }
        )
    }
)

# ASCII Art
$asciiArt = @(
    '      __        __  _  _   _ ',
    '      \ \      / / | || \ | |',
    '       \ \ /\ / /  | ||  \| |',
    '        \ V  V /   | || |\  |',
    '         \_/\_/    |_||_| \_|',
    '',
    '       Toolkit By MagnetarMan',
    '       Version 2.2 (Build 3)'
)

# Main loop
while ($true) {
    Clear-Host
    $width = 65
    
    # Header
    Write-Host ('═' * $width) -ForegroundColor Green
    foreach ($line in $asciiArt) {
        Write-Host (Center-Text $line $width) -ForegroundColor White
    }
    Write-Host ('═' * $width) -ForegroundColor Green
    
    winver
    Write-Host ''
    
    # Build and display menu
    $allScripts = @()
    $scriptIndex = 1
    
    foreach ($category in $menuStructure) {
        Write-Host "=== $($category.Icon) $($category.Name) $($category.Icon) ===" -ForegroundColor Cyan
        Write-Host ''
        
        foreach ($script in $category.Scripts) {
            $allScripts += $script
            Write-StyledMessage 'Info' "[$scriptIndex] $($script.Description)"
            $scriptIndex++
        }
        Write-Host ''
    }
    
    # Exit section
    Write-Host "=== Uscita ===" -ForegroundColor Red
    Write-Host ''
    Write-StyledMessage 'Error' '[0] Esci dal Toolkit'
    Write-Host ''
    
    # Handle user choice
    $userChoice = Read-Host "Quale opzione vuoi eseguire? (es. 1, 3, 5 o 0 per uscire)"

    if ($userChoice -eq '0') {
        Write-StyledMessage 'Warning' 'In caso di problemi, contatta MagnetarMan su Github => Github.com/Magnetarman.'
        Write-StyledMessage 'Success' 'Grazie per aver usato il toolkit. Chiusura in corso...'
        Start-Sleep -Seconds 5
        break
    }

    # Separa gli input usando spazi o virgole come delimitatori e rimuove eventuali spazi vuoti
    $choices = $userChoice -split '[ ,]+' | Where-Object { $_ -ne '' }
    $scriptsToRun = [System.Collections.Generic.List[object]]::new()
    $invalidChoices = [System.Collections.Generic.List[string]]::new()

    # Valida ogni scelta e la aggiunge alla lista di esecuzione
    foreach ($choice in $choices) {
        if (($choice -match '^\d+$') -and ([int]$choice -ge 1) -and ([int]$choice -le $allScripts.Count)) {
            $scriptsToRun.Add($allScripts[[int]$choice - 1])
        }
        else {
            $invalidChoices.Add($choice)
        }
    }

    # Se ci sono scelte non valide, avvisa l'utente
    if ($invalidChoices.Count -gt 0) {
        Write-StyledMessage 'Warning' "Le seguenti opzioni non sono valide e verranno ignorate: $($invalidChoices -join ', ')"
        Start-Sleep -Seconds 2
    }

    # Esegui gli script validi in sequenza
    if ($scriptsToRun.Count -gt 0) {
        foreach ($selectedItem in $scriptsToRun) {
            Write-Host "`n" + ('-' * ($width / 2))
            Write-StyledMessage 'Info' "Avvio di '$($selectedItem.Description)'..."
        
            try {
                if ($selectedItem.Action -eq 'RunFile') {
                    $scriptPath = Join-Path $PSScriptRoot $selectedItem.Name
                    if (Test-Path $scriptPath) { & $scriptPath }
                    else { Write-StyledMessage 'Error' "Script '$($selectedItem.Name)' non trovato." }
                }
                elseif ($selectedItem.Action -eq 'RunFunction') {
                    Invoke-Expression $selectedItem.Name
                }
            }
            catch {
                Write-StyledMessage 'Error' "Errore durante l'esecuzione di '$($selectedItem.Description)'."
                Write-StyledMessage 'Error' "Dettagli: $($_.Exception.Message)"
            }
            Write-StyledMessage 'Success' "Esecuzione di '$($selectedItem.Description)' completata."
        }
    
        Write-Host "`nTutte le operazioni selezionate sono state completate."
        Write-Host "Premi un tasto per tornare al menu principale..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    elseif ($invalidChoices.Count -eq $choices.Count) {
        # Questo blocco viene eseguito se sono state inserite SOLO scelte non valide
        Write-StyledMessage 'Error' 'Nessuna scelta valida inserita. Riprova.'
        Start-Sleep -Seconds 3
    }
}
