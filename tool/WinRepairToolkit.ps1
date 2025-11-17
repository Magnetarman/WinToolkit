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

    $Host.UI.RawUI.WindowTitle = "Repair Toolkit By MagnetarMan"
    $script:Log = @(); $script:CurrentAttempt = 0

    # Setup logging specifico per WinRepairToolkit
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\WinRepairToolkit_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
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
            $proc = if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
                $drive = ($Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1) ?? $env:SystemDrive
                $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }
                Start-Process 'cmd.exe' @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ')") -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
            }
            else {
                Start-Process $Config.Tool $Config.Args -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
            }

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

            $results = @()
            @($outFile, $errFile) | Where-Object { Test-Path $_ } | ForEach-Object {
                $results += Get-Content $_ -ErrorAction SilentlyContinue
            }

            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r') -and
                ($results -join ' ').ToLower() -match 'schedule|next time.*restart|volume.*in use') {
                Write-StyledMessage Info "🔧 $($Config.Name): controllo schedulato al prossimo riavvio"
                $script:Log += "[$($Config.Name)] ℹ️ Controllo disco schedulato al prossimo riavvio"
                return @{ Success = $true; ErrorCount = 0 }
            }

            Show-ProgressBar $Config.Name 'Completato con successo' 100 $Config.Icon
            Write-Host ''

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

    function Set-PasswordExpirationPolicy {
        Write-StyledMessage Info "⚙️ Impostazione della scadenza password a illimitata..."
        try {
            # Esegui il comando
            $process = Start-Process -FilePath "net" -ArgumentList "accounts", "/maxpwage:unlimited" -NoNewWindow -PassThru -Wait
            if ($process.ExitCode -eq 0) {
                Write-StyledMessage Success "✅ Scadenza password impostata a illimitata con successo."
                $script:Log += "[Password Policy] ✅ Scadenza password impostata a illimitata."
                return $true
            } else {
                Write-StyledMessage Warning "⚠️ Impossibile impostare la scadenza password a illimitata. Codice di uscita: $($process.ExitCode)."
                $script:Log += "[Password Policy] ⚠️ Fallito: $($process.ExitCode)."
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "❌ Errore durante l'impostazione della scadenza password: $($_.Exception.Message)"
            $script:Log += "[Password Policy] ❌ Errore fatale: $($_.Exception.Message)"
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

    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )
    
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    
        return (' ' * $padding + $Text)
    }
    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '    Repair Toolkit By MagnetarMan',
            '       Version 2.4.2 (Build 2)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    Show-Header

    for ($i = 5; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    try {
        $repairResult = Start-RepairCycle
        $deepRepairScheduled = Start-DeepDiskRepair

        # Impostazione della scadenza password a illimitata
        Set-PasswordExpirationPolicy

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
        try { Stop-Transcript | Out-Null } catch {}
    }
}

WinRepairToolkit