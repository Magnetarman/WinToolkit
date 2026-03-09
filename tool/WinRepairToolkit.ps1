function WinRepairToolkit {
    <#
    .SYNOPSIS
        Esegue riparazioni standard di Windows (SFC, DISM, Chkdsk) e salva i log di Scannow nella cartella del Toolkit debug addizionale.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$MaxRetryAttempts = 3,

        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Start-ToolkitLog -ToolName "WinRepairToolkit"
    Show-Header -SubTitle "Repair Toolkit"
    $Host.UI.RawUI.WindowTitle = "Repair Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    $script:CurrentAttempt = 0

    # Rilevamento della build di Windows per l'esecuzione condizionale
    $sysInfo = Get-SystemInfo
    $isWin11_24H2_OrNewer = $sysInfo -and ($sysInfo.BuildNumber -ge 26100)

    $RepairTools = @(
        @{ Tool = 'chkdsk'; Args = @('/scan', '/perf'); Name = 'Controllo disco'; Icon = '💽' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (1)'; Icon = '🗂️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Name = 'Ripristino immagine Windows'; Icon = '🛠️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'); Name = 'Pulizia Residui Aggiornamenti'; Icon = '🕸️' }

        # Le registrazioni AppX vengono inserite nell'array solo se la build è >= 26100 (Win11 24H2)
        if ($isWin11_24H2_OrNewer) {
            @{ Tool = 'powershell.exe'; Args = @('-Command', "if (Test-Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\appxmanifest.xml') { Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction SilentlyContinue } else { Write-Host 'File non trovato: MicrosoftWindows.Client.CBS_cw5n1h2txyewy' }"); Name = 'Registrazione AppX (Client CBS)'; Icon = '📦'; IsCritical = $false }
            @{ Tool = 'powershell.exe'; Args = @('-Command', "if (Test-Path 'C:\Windows\SystemApps\Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe\appxmanifest.xml') { Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction SilentlyContinue } else { Write-Host 'File non trovato: Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe' }"); Name = 'Registrazione AppX (UI Xaml CBS)'; Icon = '📦'; IsCritical = $false }
            @{ Tool = 'powershell.exe'; Args = @('-Command', "if (Test-Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.Core_cw5n1h2txyewy\appxmanifest.xml') { Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.Core_cw5n1h2txyewy\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction SilentlyContinue } else { Write-Host 'File non trovato: MicrosoftWindows.Client.Core_cw5n1h2txyewy' }"); Name = 'Registrazione AppX (Client Core)'; Icon = '📦'; IsCritical = $false }
        }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (2)'; Icon = '🗂️' }
        @{ Tool = 'chkdsk'; Args = @('/f', '/r', '/x'); Name = 'Controllo disco approfondito'; Icon = '💽'; IsCritical = $false }
    )

    function Invoke-RepairCommand {
        param([hashtable]$Config, [int]$Step, [int]$Total)

        Write-StyledMessage Info "[$Step/$Total] Avvio $($Config.Name)..."
        $isChkdsk = ($Config.Tool -ieq 'chkdsk')
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()

        try {
            # Calcolo timeout centralizzato (Fix 3: eliminata duplicazione)
            $processTimeoutSeconds = 600

            switch ($Config.Name) {
                'Ripristino immagine Windows'   { $processTimeoutSeconds = 1200 }
                'Controllo file di sistema (1)' { $processTimeoutSeconds = 1200 }
                'Controllo file di sistema (2)' { $processTimeoutSeconds = 1200 }
                'Pulizia Residui Aggiornamenti' { $processTimeoutSeconds = 1200 }
                'Controllo disco'               { $processTimeoutSeconds = 900 }
                'Controllo disco approfondito'  { $processTimeoutSeconds = 900 }
            }
            $spinnerUpdateInterval = if ($Config.Name -eq 'Ripristino immagine Windows') { 900 } else { 600 }

            $result = Invoke-WithSpinner -Activity $Config.Name -Process -Action {
                if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
                    $drive = ($Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1) ?? $env:SystemDrive
                    $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }

                    $procParams = @{
                        FilePath               = 'cmd.exe'
                        ArgumentList           = @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ')")
                        RedirectStandardOutput = $outFile
                        RedirectStandardError  = $errFile
                        NoNewWindow            = $true
                        PassThru               = $true
                    }
                    Start-Process @procParams
                }
                else {
                    $procParams = @{
                        FilePath               = $Config.Tool
                        ArgumentList           = $Config.Args
                        RedirectStandardOutput = $outFile
                        RedirectStandardError  = $errFile
                        NoNewWindow            = $true
                        PassThru               = $true
                    }
                    Start-Process @procParams
                }
            } -TimeoutSeconds $processTimeoutSeconds -UpdateInterval $spinnerUpdateInterval

            $results = @()
            @($outFile, $errFile) | Where-Object { Test-Path $_ } | ForEach-Object {
                $results += Get-Content $_ -ErrorAction SilentlyContinue
            }

            # Logica controllo errori con gestione flessibile per chkdsk
            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r') -and ($results -join ' ').ToLower() -match 'schedule|next time.*restart|volume.*in use') {
                Write-StyledMessage Info "🔧 $($Config.Name): controllo schedulato al prossimo riavvio"
                return @{ Success = $true; ErrorCount = 0 }
            }

            $exitCode = $result.ExitCode

            # FIX 1: Un timeout o un'interruzione forzata tipicamente restituisce -1.
            # Aggiunto controllo per exit code negativo.
            $isTimeout = ($null -eq $result) -or ($null -eq $exitCode) -or ($exitCode -eq -1)

            # FIX 2: Dism è considerato in successo solo se NON è andato in timeout e ha trovato la stringa
            $hasDismSuccess = (-not $isTimeout) -and ($Config.Tool -ieq 'DISM') -and ($results -match '(?i)completed successfully')

            # Per chkdsk /scan, considerare successo se completato (anche con exit code non-zero informativo)
            $isChkdskScan = $isChkdsk -and ($Config.Args -contains '/scan')
            $chkdskCompleted = (-not $isTimeout) -and $isChkdskScan -and (($results -join ' ') -match '(?i)(scansione.*completata|scan.*completed|successfully scanned)')

            $isSuccess = (-not $isTimeout) -and (($exitCode -eq 0) -or $hasDismSuccess -or $chkdskCompleted)

            $errors = $warnings = @()
            if (-not $isSuccess) {
                # Se c'è stato un timeout, forza un errore
                if ($isTimeout) {
                    $errors += "Timeout: L'operazione ha superato il tempo limite ed è stata terminata."
                }

                foreach ($line in ($results | Where-Object { $_ -and ![string]::IsNullOrWhiteSpace($_.Trim()) })) {
                    $trim = $line.Trim()
                    # Escludi linee di progresso, versione e messaggi informativi
                    if ($trim -match '^\[=+\s*\d+' -or $trim -match '(?i)version:|deployment image') { continue }

                    # Per chkdsk, ignora messaggi informativi comuni che non sono errori critici
                    if ($isChkdsk) {
                        # Ignora messaggi informativi di chkdsk
                        if ($trim -match '(?i)(stage|fase|percent complete|verificat|scanned|scanning|errors found.*corrected|volume label)') { continue }
                        # Solo errori critici per chkdsk
                        if ($trim -match '(?i)(cannot|unable to|access denied|critical|fatal|corrupt file system|bad sectors)') {
                            $errors += $trim
                        }
                    }
                    else {
                        # Logica normale per altri tool
                        if ($trim -match '(?i)(errore|error|failed|impossibile|corrotto|corruption)') { $errors += $trim }
                        elseif ($trim -match '(?i)(warning|avviso|attenzione)') { $warnings += $trim }
                    }
                }

                # Fallback: Se il processo fallisce ma i log non contengono keyword di errore
                if ($errors.Count -eq 0 -and -not $isTimeout) {
                    $errors += "Errore generico o terminazione anomala (ExitCode: $exitCode)."
                }
            }

            # FIX: La variabile di successo deve richiedere che l'operazione non sia fallita/andata in timeout
            $success = $isSuccess -and ($errors.Count -eq 0)

            if ($isTimeout) {
                $message = "$($Config.Name) NON completato (interrotto per Timeout)."
            }
            else {
                $message = "$($Config.Name) completato " + $(if ($success) { 'con successo' } else { "con $($errors.Count) errori" })
            }
            Write-StyledMessage $(if ($success) { 'Success' } else { 'Warning' }) $message

            # Esportazione Log CBS di SFC
            if ($Config.Tool -ieq 'sfc') {
                $cbsLogPath = "C:\Windows\Logs\CBS\CBS.log"
                if (Test-Path $cbsLogPath) {
                    try {
                        # Pulizia del nome della fase per renderlo sicuro per il file system
                        $safeStepName = $Config.Name -replace '[^a-zA-Z0-9]', '_'
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                        $destLogName = "SFC_CBS_${safeStepName}_${timestamp}.log"

                        # Utilizzo della variabile globale per la cartella dei log
                        $destLogPath = Join-Path $AppConfig.Paths.Logs $destLogName

                        Copy-Item -Path $cbsLogPath -Destination $destLogPath -Force -ErrorAction SilentlyContinue

                        # Verifica post-copia per dare un feedback accurato
                        if (Test-Path $destLogPath) {
                            Write-StyledMessage Info "📄 Log SFC salvato in: $destLogName"
                        }
                    }
                    catch {
                        Write-StyledMessage Warning "⚠️ Impossibile esportare il log CBS di SFC (file in uso)."
                    }
                }
            }

            return @{ Success = $success; ErrorCount = $errors.Count }
        }
        catch {
            Write-StyledMessage Error "Errore durante $($Config.Name): $($_.Exception.Message)"
            Write-ToolkitLog -Level ERROR -Message "Errore in Invoke-RepairCommand [$($Config.Tool)]" -Context @{
                Line      = $_.InvocationInfo.ScriptLineNumber
                Exception = $_.Exception.GetType().FullName
                Stack     = $_.ScriptStackTrace
            }
            return @{ Success = $false; ErrorCount = 1 }
        }
        finally {
            # Leggi e logga STDOUT/STDERR prima di eliminare i file temporanei
            foreach ($f in @($outFile, $errFile)) {
                if (Test-Path $f) {
                    $raw = Get-Content $f -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                    if (-not [string]::IsNullOrWhiteSpace($raw)) {
                        $label = if ($f -eq $outFile) { 'STDOUT' } else { 'STDERR' }
                        Write-ToolkitLog -Level DEBUG -Message "[PROCESS $label`: $($Config.Tool)]`n$raw"
                    }
                    Remove-Item $f -ErrorAction SilentlyContinue
                }
            }
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
        Write-StyledMessage Info '🔧 Avvio riparazione profonda del disco C: al prossimo riavvio'
        try {
            $fsutilParams = @{
                FilePath     = 'fsutil.exe'
                ArgumentList = @('dirty', 'set', 'C:')
                NoNewWindow  = $true
                Wait         = $true
            }
            Start-Process @fsutilParams
            $chkdskParams = @{
                FilePath     = 'cmd.exe'
                ArgumentList = @('/c', 'echo Y | chkdsk C: /f /r /v /x /b')
                WindowStyle  = 'Hidden'
                Wait         = $true
            }
            Start-Process @chkdskParams
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

        $deepRepairScheduled = $false
        # Fix 2: Esegue la riparazione profonda solo se ci sono ancora errori dopo 3 tentativi
        if ($repairResult.TotalErrors -gt 0) {
            Write-StyledMessage Warning "Rilevati errori persistenti. Avvio riparazione profonda..."
            $deepRepairScheduled = Start-DeepDiskRepair
        }
        else {
            Write-StyledMessage Success "Sistema in salute. Riparazione profonda non necessaria."
        }

        Write-StyledMessage Info "⚙️ Impostazione scadenza password illimitata..."
        $procParams = @{
            FilePath     = 'net'
            ArgumentList = @('accounts', '/maxpwage:unlimited')
            NoNewWindow  = $true
            Wait         = $true
        }
        Start-Process @procParams

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
        Write-ToolkitLog -Level ERROR -Message "Errore critico in WinRepairToolkit" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
}
