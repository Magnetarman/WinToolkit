<#
.SYNOPSIS
    Un toolkit per eseguire script di manutenzione e gestione di Windows.
.DESCRIPTION
    Questo script funge da menu principale per un insieme di strumenti di manutenzione e gestione di Windows.
    Permette agli utenti di selezionare ed eseguire vari script PowerShell per compiti specifici.
.NOTES
  Versione 2.0 (Build 72) - 2025-09-06
#>

# Imposta il titolo della finestra di PowerShell per un'identificazione immediata.
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan v2.0 (Build 72)"

# Imposta una gestione degli errori più rigorosa per lo script.
# 'Stop' interrompe l'esecuzione in caso di errore, permettendo una gestione controllata tramite try/catch.
$ErrorActionPreference = 'Stop'

# Creazione directory di log e avvio trascrizione
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\WinToolkit\logs"
try {
    [System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
    Start-Transcript -Path "$logdir\WinToolkit_$dateTime.log" -Append -Force | Out-Null
} catch {
    # Gestione errori silenziosa per compatibilità
}

function Write-StyledMessage {
    <#
    .SYNOPSIS
        Scrive un messaggio formattato sulla console con icone e colori.
    .PARAMETER Type
        Il tipo di messaggio (Success, Warning, Error, Info).
    .PARAMETER Text
        Il testo del messaggio da visualizzare.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Warning', 'Error', 'Info')]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    # Definisce gli stili per ogni tipo di messaggio. L'uso degli emoji migliora la leggibilità.
    $styles = @{
        Success = @{ Color = 'Green' ; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'   ; Icon = '❌' }
        Info    = @{ Color = 'Cyan'  ; Icon = '💎' }
    }

    $style = $styles[$Type]
    Write-Host "$($style.Icon) $($Text)" -ForegroundColor $style.Color
}

function Center-Text {
    <#
    .SYNOPSIS
        Centra una stringa di testo data una larghezza specifica.
    .PARAMETER Text
        Il testo da centrare.
    .PARAMETER Width
        La larghezza totale del contenitore.
    #>
    param(
        [string]$Text,
        [int]$Width = 60
    )

    if ($Text.Length -ge $Width) { return $Text }

    $padding = ' ' * [Math]::Floor(($Width - $Text.Length) / 2)
    return "$($padding)$($Text)"
}

# Funzione per installare il profilo PowerShell
function WinInstallPSProfile {
    <#
    .SYNOPSIS
        Installa il profilo PowerShell di Chris Titus Tech.
    #>
    
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
            } else {
                Write-StyledMessage 'Info' "Riavvio annullato. Ricorda di riavviare il sistema per vedere tutte le modifiche."
            }
        } else {
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
# MagnetarMan's Windows Repair Toolkit v2.0
param([int]$MaxRetryAttempts = 3, [int]$CountdownSeconds = 30)

# Variabili globali
$script:Log = @(); $script:CurrentAttempt = 0
$spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
$SpinnerIntervalMs = 160
$MsgStyles = @{
    Success = @{ Color = 'Green'; Icon = '✅' }; Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
    Error = @{ Color = 'Red'; Icon = '❌' }; Info = @{ Color = 'Cyan'; Icon = '💎' }
}
$RepairTools = @(
    @{ Tool = 'chkdsk'; Args = @('/scan','/perf'); Name = 'Controllo disco'; Icon = '💽' }
    @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (1)'; Icon = '🗂️' }
    @{ Tool = 'DISM'; Args = @('/Online','/Cleanup-Image','/RestoreHealth'); Name = 'Ripristino immagine Windows'; Icon = '🛠️' }
    @{ Tool = 'DISM'; Args = @('/Online','/Cleanup-Image','/StartComponentCleanup','/ResetBase'); Name = 'Pulizia Residui Aggiornamenti'; Icon = '🕸️' }
    @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (2)'; Icon = '🗂️' }
)

function Write-StyledMessage([string]$Type, [string]$Text) {
    $style = $MsgStyles[$Type]
    Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
}

function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
    $barLength = 30
    $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
    $filled = '█' * [math]::Floor($safePercent * $barLength / 100)
    $empty = '░' * ($barLength - $filled.Length)
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

function Invoke-RepairCommand([hashtable]$Config, [int]$Step, [int]$Total) {
    Write-StyledMessage Info "[$Step/$Total] Avvio $($Config.Name)..."
    $percent = 0; $spinnerIndex = 0; $isChkdsk = ($Config.Tool -ieq 'chkdsk')
    $outFile = [System.IO.Path]::GetTempFileName()
    $errFile = [System.IO.Path]::GetTempFileName()
    
    try {
        # Preparazione comando
        if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
            $drive = ($Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1)
            if (-not $drive) { $drive = $env:SystemDrive }
            $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }
            $proc = Start-Process 'cmd.exe' @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ')") -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
        } else {
            $proc = Start-Process $Config.Tool $Config.Args -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
        }
        
        # Monitoraggio progresso
        while (-not $proc.HasExited) {
            $spinner = $spinners[$spinnerIndex % $spinners.Length]
            $spinnerIndex++
            
            if ($isChkdsk) {
                Show-ProgressBar $Config.Name 'Esecuzione in corso ...' 0 $Config.Icon $spinner 'Yellow'
            } else {
                if ($percent -lt 95) { $percent += Get-Random -Minimum 1 -Maximum 3 }
                Show-ProgressBar $Config.Name 'Esecuzione in corso...' $percent $Config.Icon $spinner
            }
            Start-Sleep -Milliseconds 600
            $proc.Refresh()
        }
        
        # Lettura risultati
        $results = @()
        if (Test-Path $outFile) { $results += Get-Content $outFile -ErrorAction SilentlyContinue }
        if (Test-Path $errFile) { $results += Get-Content $errFile -ErrorAction SilentlyContinue }
        
        # Check scheduling per chkdsk
        if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
            $partialText = ($results -join ' ').ToLower()
            if ($partialText -match 'schedule|next time.*restart|volume.*in use') {
                Write-StyledMessage Info "🔧 $($Config.Name): controllo schedulato al prossimo riavvio"
                $script:Log += "[$($Config.Name)] ℹ️ Controllo disco schedulato al prossimo riavvio"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        
        Show-ProgressBar $Config.Name 'Completato con successo' 100 $Config.Icon
        Write-Host ''
        
        # Analisi risultati
        $exitCode = $proc.ExitCode
        $hasDismSuccess = ($Config.Tool -ieq 'DISM') -and ($results -match '(?i)completed successfully')
        $isSuccess = ($exitCode -eq 0) -or $hasDismSuccess
        
        $errors = @()
        $warnings = @()
        
        if (-not $isSuccess) {
            foreach ($line in $results) {
                if ($null -eq $line -or [string]::IsNullOrWhiteSpace($line.Trim())) { continue }
                $trim = $line.Trim()
                if ($trim -match '^\[=+\s*\d+' -or $trim -match '(?i)version:|deployment image') { continue }
                
                if ($trim -match '(?i)(errore|error|failed|impossibile|corrotto|corruption)') { $errors += $trim }
                elseif ($trim -match '(?i)(warning|avviso|attenzione)') { $warnings += $trim }
            }
        }
        
        $success = ($errors.Count -eq 0) -or $hasDismSuccess
        $message = "$($Config.Name) completato " + $(if ($success) { 'con successo' } else { "con $($errors.Count) errori" })
        Write-StyledMessage $(if ($success) { 'Success' } else { 'Warning' }) $message
        
        $logStatus = if ($success) { '✅ Successo' } else { "⚠️ $($errors.Count) errori" }
        if ($warnings.Count -gt 0) { $logStatus += " - $($warnings.Count) avvisi" }
        $script:Log += "[$($Config.Name)] $logStatus"
        
        return @{ Success = $success; ErrorCount = $errors.Count }
        
    } catch {
        Write-StyledMessage Error "Errore durante $($Config.Name): $_"
        $script:Log += "[$($Config.Name)] ❌ Errore fatale: $_"
        return @{ Success = $false; ErrorCount = 1 }
    } finally {
        Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
    }
}

function Start-RepairCycle([int]$Attempt = 1) {
    $script:CurrentAttempt = $Attempt
    Write-StyledMessage Info "🔄 Tentativo $Attempt/$MaxRetryAttempts - Riparazione sistema ($($RepairTools.Count) strumenti)..."
    Write-Host ''
    
    $totalErrors = 0
    $successCount = 0
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
        Start-Process 'fsutil.exe' @('dirty','set','C:') -NoNewWindow -Wait
        Start-Process 'cmd.exe' @('/c','echo Y | chkdsk C: /f /r /v /x /b') -WindowStyle Hidden -Wait
        Write-StyledMessage Info 'Comando chkdsk inviato (finestra nascosta). Riavvia il sistema per eseguire la scansione profonda.'
        $script:Log += "[Controllo disco Esteso] ✅ chkdsk eseguito in background; riavviare per applicare"
        return $true
    } catch {
        Write-StyledMessage Error "Errore eseguendo operazione: $_"
        $script:Log += "[Controllo disco Esteso] ❌ Errore: $_"
        return $false
    }
}

function Start-SystemRestart([hashtable]$RepairResult) {
    
    if ($RepairResult.Success) {
        Write-StyledMessage Info '🎉 Riparazione completata con successo!'
        Write-StyledMessage Info "🎯 Errori risolti in $($RepairResult.AttemptsUsed) tentativo/i."
    } else {
        Write-StyledMessage Warning "⚠️ $($RepairResult.TotalErrors) errori persistenti dopo $($RepairResult.AttemptsUsed) tentativo/i."
        Write-StyledMessage Info '📋 Controlla il log sul Desktop. 💡 Il riavvio potrebbe risolvere problemi residui.'
    }
    
    Write-StyledMessage Info '🔄 Il sistema verrà riavviato per finalizzare le modifiche'
    
    if (Start-InterruptibleCountdown $CountdownSeconds 'Riavvio automatico') {
        try { 
            Write-StyledMessage Info '🔄 Riavvio in corso...'
            Restart-Computer -Force 
        } catch { 
            Write-StyledMessage Error "❌ Errore riavvio: $_"
            Write-StyledMessage Info '🔄 Riavviare manualmente il sistema.'
        }
    } else {
        Write-StyledMessage Info '✅ Script completato. Sistema non riavviato.'
        Write-StyledMessage Info '💡 Riavvia quando possibile per applicare le riparazioni.'
    }
}


$Host.UI.RawUI.WindowTitle = "Repair Toolkit By MagnetarMan"
 Clear-Host

    # --- Schermata di Benvenuto ---
    $width = 60
    $asciiArt = @(
        ' __        __  _  _   _ '
        ' \ \      / / | || \ | |'
        '  \ \ /\ / /  | ||  \| |'
        '   \ V  V /   | || |\  |'
        '    \_/\_/    |_||_| \_|'
        ''
        '    Repair Toolkit By MagnetarMan'
        '      Version 2.0 (Build 13)'
    )
    foreach ($line in $asciiArt) {
        Write-StyledMessage 'Info' (Center-Text -Text $line -Width $width)
    }
    Write-Host '' # Spazio


# Countdown preparazione
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
    
} catch {
    Write-StyledMessage Error "❌ Errore critico: $($_.Exception.Message)"
} finally {
    Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
    Read-Host
}
}

param([int]$CountdownSeconds = 10)

# Variabili globali per interfaccia grafica
$spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
$SpinnerIntervalMs = 160
$MsgStyles = @{
    Success = @{ Color = 'Green'; Icon = '✅' }
    Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
    Error = @{ Color = 'Red'; Icon = '❌' }
    Info = @{ Color = 'Cyan'; Icon = '💎' }
}

function Write-StyledMessage([string]$Type, [string]$Text) {
    $style = $MsgStyles[$Type]
    Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
}

function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
    $barLength = 30
    $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
    $filled = '█' * [math]::Floor($safePercent * $barLength / 100)
    $empty = '░' * ($barLength - $filled.Length)
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
            Write-StyledMessage Info "🔄 Puoi riavviare manualmente con: shutdown /r /t 0"
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

function Show-ServiceProgress([string]$ServiceName, [string]$Action, [int]$Current, [int]$Total) {
    $percent = [math]::Round(($Current / $Total) * 100)
    $spinnerIndex = ($Current % $spinners.Length)
    $spinner = $spinners[$spinnerIndex]
    Show-ProgressBar "Servizi ($Current/$Total)" "$Action $ServiceName" $percent '⚙️' $spinner 'Cyan'
    Start-Sleep -Milliseconds 200
}

function WinUpdateReset {
    param([int]$CountdownSeconds = 10)
    
    # Variabili locali per interfaccia grafica
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $SpinnerIntervalMs = 160
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error = @{ Color = 'Red'; Icon = '❌' }
        Info = @{ Color = 'Cyan'; Icon = '💎' }
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
        $empty = '░' * ($barLength - $filled.Length)
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
                Write-StyledMessage Info "🔄 Puoi riavviare manualmente con: shutdown /r /t 0"
                return $false
            }
            $remainingPercent = 100 - [math]::Round((($Seconds - $i) / $Seconds) * 100)
            Show-ProgressBar 'Countdown Riavvio' "${Message} - $i sec (Premi un tasto per annullare)" $remainingPercent '⏳' '' 'Red'
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
                    Write-StyledMessage Info "$serviceIcon Servizio $serviceName arrestato."
                }
                'Configure' {
                    Show-ServiceProgress $serviceName "Configurazione" $currentStep $totalSteps
                    Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop
                    Write-StyledMessage Success "$serviceIcon Servizio $serviceName configurato come $($config.Type)."
                }
                'Start' {
                    Show-ServiceProgress $serviceName "Avvio" $currentStep $totalSteps
                    Start-Service -Name $serviceName -ErrorAction Stop
                    
                    # Attesa avvio con spinner
                    $timeout = 10; $spinnerIndex = 0
                    do {
                        Write-Host "`r$($spinners[$spinnerIndex % $spinners.Length]) 🔄 Attesa avvio $serviceName..." -NoNewline -ForegroundColor Yellow
                        Start-Sleep -Milliseconds 300
                        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                        $timeout--; $spinnerIndex++
                    } while ($service.Status -ne 'Running' -and $timeout -gt 0)
                    Write-Host "`r" -NoNewline
                    
                    if ($service.Status -eq 'Running') {
                        Write-StyledMessage Success "$serviceIcon Servizio $serviceName avviato correttamente."
                    } else {
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
            $actionText = switch ($action) { 'Configure' { 'configurare' } 'Start' { 'avviare' } 'Check' { 'verificare' } default { $action.ToLower() } }
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            Write-StyledMessage Warning "$serviceIcon Impossibile $actionText $serviceName - $($_.Exception.Message)"
        }
    }

    # === INIZIO ESECUZIONE PRINCIPALE ===
    Clear-Host
    
    # --- Header Grafico Migliorato ---
    $width = 65
    Write-Host ('═' * $width) -ForegroundColor DarkCyan
    $asciiArt = @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        '  Update Reset Toolkit By MagnetarMan',
        '       Version 2.0 (Build 17)'
    )
    foreach ($line in $asciiArt) {
        Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
    }
    Write-Host ('═' * $width) -ForegroundColor DarkCyan
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

    # Configurazione servizi con icone
    $serviceConfig = @{
        'wuauserv' = @{ Type = 'Automatic'; Critical = $true; Icon = '🔄'; DisplayName = 'Windows Update' }
        'bits' = @{ Type = 'Automatic'; Critical = $true; Icon = '📡'; DisplayName = 'Background Intelligent Transfer' }
        'cryptsvc' = @{ Type = 'Automatic'; Critical = $true; Icon = '🔐'; DisplayName = 'Cryptographic Services' }
        'trustedinstaller' = @{ Type = 'Manual'; Critical = $true; Icon = '🛡️'; DisplayName = 'Windows Modules Installer' }
        'msiserver' = @{ Type = 'Manual'; Critical = $false; Icon = '📦'; DisplayName = 'Windows Installer' }
    }
    
    $systemServices = @(
        @{ Name = 'appidsvc'; Icon = '🆔'; Display = 'Application Identity' },
        @{ Name = 'gpsvc'; Icon = '📋'; Display = 'Group Policy Client' },
        @{ Name = 'DcomLaunch'; Icon = '🚀'; Display = 'DCOM Server Process Launcher' },
        @{ Name = 'RpcSs'; Icon = '📞'; Display = 'Remote Procedure Call' },
        @{ Name = 'LanmanServer'; Icon = '🖥️'; Display = 'Server' },
        @{ Name = 'LanmanWorkstation'; Icon = '💻'; Display = 'Workstation' },
        @{ Name = 'EventLog'; Icon = '📝'; Display = 'Windows Event Log' },
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
                Write-StyledMessage Success "📝 Chiave rimossa: $_"
            }
            Write-Host 'Completato!' -ForegroundColor Green
        }
        catch {
            Write-Host 'Errore!' -ForegroundColor Red
            Write-StyledMessage Warning "⚠️ Errore durante la modifica del registro - $($_.Exception.Message)"
        }
        Write-Host ''

        # Reset componenti con progress bar
        Write-StyledMessage Info '🗂️ Eliminazione componenti Windows Update...'
        $directories = @("C:\Windows\SoftwareDistribution", "C:\Windows\System32\catroot2")
        for ($i = 0; $i -lt $directories.Count; $i++) {
            $dir = $directories[$i]
            $percent = [math]::Round((($i + 1) / $directories.Count) * 100)
            Show-ProgressBar "Directory ($($i + 1)/$($directories.Count))" "Eliminazione $(Split-Path $dir -Leaf)" $percent '🗑️' '' 'Yellow'
            
            if (Test-Path $dir) {
                try {
                    Remove-Item $dir -Recurse -Force -ErrorAction Stop
                    Write-StyledMessage Success "🗑️ Directory $(Split-Path $dir -Leaf) eliminata."
                }
                catch {
                    Write-StyledMessage Warning "⚠️ Errore eliminando $(Split-Path $dir -Leaf) - $($_.Exception.Message)"
                }
            } else {
                Write-StyledMessage Info "💭 Directory $(Split-Path $dir -Leaf) non presente."
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
            Write-StyledMessage Warning "⚠️ Errore durante il reset del client Windows Update."
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


#function WinReinstallStore {}

# Ciclo principale del programma: mostra il menu e attende una scelta.
while ($true) {
    Clear-Host

    # --- Schermata di Benvenuto ---
    $width = 60
    $asciiArt = @(
        ' __        __  _  _   _ '
        ' \ \      / / | || \ | |'
        '  \ \ /\ / /  | ||  \| |'
        '   \ V  V /   | || |\  |'
        '    \_/\_/    |_||_| \_|'
        ''
        '    Toolkit By MagnetarMan'
        '      Version 2.0 (Build 72)'
    )
    foreach ($line in $asciiArt) {
        Write-StyledMessage 'Info' (Center-Text -Text $line -Width $width)
    }
    Write-Host '' # Spazio

    # --- Definizione e visualizzazione del menu ---
    $scripts = @(
        [pscustomobject]@{ Name = 'WinInstallPSProfile'; Description = 'Installa il profilo PowerShell - Fortemente Consigliato.' ; Action = 'RunFunction' }
        [pscustomobject]@{ Name = 'WinRepairToolkit'; Description = 'Avvia il Toolkit di Riparazione Windows.' ; Action = 'RunFunction' }
        [pscustomobject]@{ Name = 'WinUpdateReset'  ; Description = 'Esegui il Reset di Windows Update.'       ; Action = 'RunFunction' }
        [pscustomobject]@{ Name = 'WinReinstallStore'; Description = 'Reinstalla Winget ed il Windows Store.'  ; Action = 'RunFunction' }
        ) 

    Write-StyledMessage 'Warning' 'Seleziona lo script da avviare:'
    for ($i = 0; $i -lt $scripts.Count; $i++) {
        Write-StyledMessage 'Info' ("[$($i + 1)] $($scripts[$i].Description)")
    }
    Write-StyledMessage 'Error' '[0] Esci dal Toolkit'
    Write-Host '' # Spazio

    # --- Logica di gestione della scelta utente ---
    $userChoice = Read-Host "Inserisci il numero della tua scelta"

    if ($userChoice -eq '0') {
        Write-StyledMessage 'Warning' 'In caso di problemi, contatta MagnetarMan su GitHub.'
        Write-StyledMessage 'Success' 'Grazie per aver usato il toolkit. Chiusura in corso...'
        Start-Sleep -Seconds 5
        break # Esce dal ciclo while ($true) e termina lo script.
    }

    # Verifica se l'input è un numero valido e rientra nel range delle opzioni.
    if (($userChoice -match '^\d+$') -and ([int]$userChoice -ge 1) -and ([int]$userChoice -le $scripts.Count)) {
        $selectedIndex = [int]$userChoice - 1
        $selectedItem = $scripts[$selectedIndex]

        Write-StyledMessage 'Info' "Avvio di '$($selectedItem.Description)'..."
        try {
            if ($selectedItem.Action -eq 'RunFile') {
                $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath $selectedItem.Name
                if (Test-Path $scriptPath) {
                    & $scriptPath
                } else {
                    Write-StyledMessage 'Error' "Script '$($selectedItem.Name)' non trovato nella directory '$($PSScriptRoot)'."
                }
            } elseif ($selectedItem.Action -eq 'RunFunction') {
                Invoke-Expression "$($selectedItem.Name)"
            }
        }
        catch {
            Write-StyledMessage 'Error' "Si è verificato un errore durante l'esecuzione dell'opzione selezionata."
            Write-StyledMessage 'Error' "Dettagli: $($_.Exception.Message)"
        }
        
        # Pausa prima di tornare al menu principale
        Write-Host "`nPremi un tasto per tornare al menu principale..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    else {
        Write-StyledMessage 'Error' 'Scelta non valida. Riprova.'
        Start-Sleep -Seconds 3
    }
}
