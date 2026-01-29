function WinRepairToolkit {
    <#
.SYNOPSIS
    Esegue riparazioni standard di Windows (SFC, DISM, Chkdsk).
#>
    param(
        [int]$MaxRetryAttempts = 3,
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Initialize-ToolLogging -ToolName "WinRepairToolkit"
    Show-Header -SubTitle "Repair Toolkit"

    $script:CurrentAttempt = 0
    $RepairTools = @(
        @{ Tool = 'chkdsk'; Args = @('/scan', '/perf'); Name = 'Controllo disco'; Icon = '💽' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (1)'; Icon = '🗂️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Name = 'Ripristino immagine Windows'; Icon = '🛠️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'); Name = 'Pulizia Residui Aggiornamenti'; Icon = '🕸️' }
        @{ Tool = 'powershell.exe'; Args = @('-Command', "if (Test-Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\appxmanifest.xml') { Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction SilentlyContinue } else { Write-Host 'File non trovato: MicrosoftWindows.Client.CBS_cw5n1h2txyewy' }"); Name = 'Registrazione AppX (Client CBS)'; Icon = '📦'; IsCritical = $false }
        @{ Tool = 'powershell.exe'; Args = @('-Command', "if (Test-Path 'C:\Windows\SystemApps\Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe\appxmanifest.xml') { Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction SilentlyContinue } else { Write-Host 'File non trovato: Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe' }"); Name = 'Registrazione AppX (UI Xaml CBS)'; Icon = '📦'; IsCritical = $false }
        @{ Tool = 'powershell.exe'; Args = @('-Command', "if (Test-Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.Core_cw5n1h2txyewy\appxmanifest.xml') { Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.Core_cw5n1h2txyewy\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction SilentlyContinue } else { Write-Host 'File non trovato: MicrosoftWindows.Client.Core_cw5n1h2txyewy' }"); Name = 'Registrazione AppX (Client Core)'; Icon = '📦'; IsCritical = $false }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (2)'; Icon = '🗂️' }
    )

    function Invoke-RepairCommand {
        param([hashtable]$Config, [int]$Step, [int]$Total)
        
        Write-StyledMessage Info "[$Step/$Total] Avvio $($Config.Name)..."
        $isChkdsk = ($Config.Tool -ieq 'chkdsk')
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()

        try {
            # --- Parametri di processo e timeout dinamici ---
            $procFilePath = $Config.Tool
            $procArgumentList = $Config.Args
            $processTimeoutSeconds = 600 # Default timeout per la terminazione forzata (es. AppX, o DISM generico)
            $warningMessageThresholdSeconds = 0 # Default: nessun messaggio di avviso anticipato

            if ($Config.Tool -ieq 'sfc') {
                $processTimeoutSeconds = 3600 # SFC può essere molto lungo
                # Nessun warning esplicito qui, SFC ha già un feedback "Analisi in corso..."
            }
            elseif ($isChkdsk) {
                $processTimeoutSeconds = 300 # Timeout per la terminazione forzata di chkdsk
                $warningMessageThresholdSeconds = 300 # Avviso dopo 300 secondi
                # Gestione speciale per chkdsk /f, /r o /x che richiedono 'cmd.exe /c echo Y|'
                if ($Config.Args -contains '/f' -or $Config.Args -contains '/r' -or $Config.Args -contains '/x') {
                    $drive = ($Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1) ?? $env:SystemDrive
                    $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }
                    $procFilePath = 'cmd.exe'
                    $procArgumentList = @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ')")
                }
            }
            elseif ($Config.Name -eq 'Pulizia Residui Aggiornamenti') {
                $processTimeoutSeconds = 600 # Questo task può anche essere lungo
                $warningMessageThresholdSeconds = 600 # Avviso dopo 600 secondi
            }
            elseif ($Config.Name -eq 'Ripristino immagine Windows') {
                $processTimeoutSeconds = 900 # Già 900s nell'UpdateInterval, allineiamo il timeout
                $warningMessageThresholdSeconds = 900 # Avviso dopo 900 secondi
            }
            # --- Fine parametri dinamici ---

            $result = Invoke-WithSpinner -Activity $Config.Name -Process -Action {
                $procParams = @{
                    FilePath               = $procFilePath
                    ArgumentList           = $procArgumentList
                    RedirectStandardOutput = $outFile
                    RedirectStandardError  = $errFile
                    NoNewWindow            = $true
                    PassThru               = $true
                }
                $process = Start-Process @procParams

                $elapsed = 0
                $interval = 30 # Intervallo di polling predefinito
                $hasWarned = $false # Flag per assicurarsi che l'avviso venga visualizzato solo una volta

                while (!$process.HasExited -and $elapsed -lt $processTimeoutSeconds) {
                    Start-Sleep -Seconds $interval
                    $elapsed += $interval
                    
                    # Feedback intermedio specifico per SFC (se non c'è un warning generale attivo)
                    if ($Config.Tool -ieq 'sfc' -and -not $hasWarned) {
                         Write-Host "⏳ Analisi in corso... ($elapsed s)" -ForegroundColor DarkGray
                    }
                    
                    # Messaggio di avviso generale se la soglia è raggiunta e non è stato già emesso
                    if ($warningMessageThresholdSeconds -gt 0 -and $elapsed -ge $warningMessageThresholdSeconds -and -not $hasWarned) {
                        Write-Host "Attenzione! - L'operazione sta impiegando più tempo del previsto, ATTENDERE…" -ForegroundColor Yellow
                        $hasWarned = $true
                    }
                }

                if (!$process.HasExited) {
                    Stop-Process -Id $process.Id -Force
                    Write-Host "Timeout di $($processTimeoutSeconds) secondi raggiunto per $($Config.Name). Il processo è stato terminato forzatamente." -ForegroundColor Red
                }
                return $process
            } -UpdateInterval $(
                # L'UpdateInterval dello spinner dovrebbe riflettere il tempo massimo previsto per l'operazione
                if ($Config.Tool -ieq 'sfc') { 3600 }
                elseif ($Config.Tool -ieq 'chkdsk') { 300 } # Nuovo intervallo per chkdsk
                elseif ($Config.Name -eq 'Pulizia Residui Aggiornamenti') { 600 } # Nuovo intervallo per pulizia aggiornamenti
                elseif ($Config.Name -eq 'Ripristino immagine Windows') { 900 }
                else { 600 } # Default per altri task (es. registrazione AppX)
            )

            $results = @()
            @($outFile, $errFile) | Where-Object { Test-Path $_ } | ForEach-Object {
                $results += Get-Content $_ -ErrorAction SilentlyContinue
            }

            # Logica controllo errori originale
            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r' -or $Config.Args -contains '/x') -and ($results -join ' ').ToLower() -match 'schedule|next time.*restart|volume.*in use') {
                Write-StyledMessage Info "🔧 $($Config.Name): controllo schedulato al prossimo riavvio"
                return @{ Success = $true; ErrorCount = 0 }
            }

            $exitCode = $result.ExitCode
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

            return @{ Success = $success; ErrorCount = $errors.Count }
        }
        catch {
            Write-StyledMessage Error "Errore durante $($Config.Name): $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
        finally {
            Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
        }
    }

    function Start-RepairCycle {
        param([int]$Attempt = 1)
        
        $script:CurrentAttempt = $Attempt
        Write-StyledMessage Info "🔄 Tentativo $Attempt/$MaxRetryAttempts - Riparazione sistema..."
        Write-Host ''

        $totalErrors = $successCount = 0
        for ($toolIndex = 0; $toolIndex -lt $RepairTools.Count; $toolIndex++) {
            $result = Invoke-RepairCommand -Config $RepairTools[$toolIndex] -Step ($toolIndex + 1) -Total $RepairTools.Count
            if ($result.Success) { $successCount++ }
            if (!$result.Success -and !($RepairTools[$toolIndex].ContainsKey('IsCritical') -and !$RepairTools[$toolIndex].IsCritical)) {
                $totalErrors += $result.ErrorCount
            }
            Start-Sleep 1
        }

        if ($totalErrors -gt 0 -and $Attempt -lt $MaxRetryAttempts) {
            Write-StyledMessage Warning "🔄 $totalErrors errori rilevati. Nuovo tentativo..."
            Start-Sleep 3
            return Start-RepairCycle -Attempt ($Attempt + 1)
        }
        return @{ Success = ($totalErrors -eq 0); TotalErrors = $totalErrors; AttemptsUsed = $Attempt }
    }

    function Start-DeepDiskRepair {
        Write-StyledMessage Info '🔧 Avvio riparazione profonda del disco C:...'
        try {
            Start-Process 'fsutil.exe' @('dirty', 'set', 'C:') -NoNewWindow -Wait
            Start-Process 'cmd.exe' @('/c', 'echo Y | chkdsk C: /f /r /v /x /b') -WindowStyle Hidden -Wait
            Write-StyledMessage Info 'Comando chkdsk inviato. Riavvia per eseguire.'
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore durante la schedulazione della riparazione profonda: $($_.Exception.Message)"
            return $false
        }
    }

    # Esecuzione
    try {
        $repairResult = Start-RepairCycle
        $deepRepairScheduled = Start-DeepDiskRepair

        Write-StyledMessage Info "⚙️ Impostazione scadenza password illimitata..."
        Start-Process "net" -ArgumentList "accounts", "/maxpwage:unlimited" -NoNewWindow -Wait

        if ($deepRepairScheduled) { Write-StyledMessage Warning 'Riavvio necessario per riparazione profonda.' }

        if ($SuppressIndividualReboot) {
            if ($deepRepairScheduled) {
                $Global:NeedsFinalReboot = $true
                Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
            }
        }
        else {
            if (Start-InterruptibleCountdown $CountdownSeconds 'Riavvio automatico') {
                Restart-Computer -Force
            }
        }
    }
    catch {
        Write-StyledMessage Error "❌ Errore critico: $($_.Exception.Message)"
    }
}
