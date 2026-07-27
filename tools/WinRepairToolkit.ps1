function WinRepairToolkit {
    <#
    .SYNOPSIS
        Esegue riparazioni standard di Windows (SFC, DISM, Chkdsk) e salva i log di Scannow nella cartella del Toolkit debug addizionale.
    #>
    [CmdletBinding()]
    param(
        [int]$MaxRetryAttempts = 3,
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "WinRepairToolkit" -SubTitle "Repair Toolkit"

    $script:CurrentAttempt = 0

    $sysInfo = Get-SystemInfo

    $RepairTools = @(
        @{ Tool = 'chkdsk'; Args = @('/scan', '/perf'); Name = 'Controllo disco'; Icon = '💽' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (1)'; Icon = '🗂️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Name = 'Ripristino immagine Windows'; Icon = '🛠️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'); Name = 'Pulizia Residui Aggiornamenti'; Icon = '🕸️' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (2)'; Icon = '🗂️' }
        @{ Tool = 'chkdsk'; Args = @('/f', '/r', '/x'); Name = 'Controllo disco approfondito'; Icon = '💽'; IsCritical = $false }
    )

    function Invoke-RepairCommand {
        param([hashtable]$Config, [int]$Step, [int]$Total)

        Write-StyledMessage -Type 'Info' -Text "[$Step/$Total] Avvio $($Config.Name)."
        $isChkdsk = ($Config.Tool -ieq 'chkdsk')
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()

        try {
            $processTimeoutSeconds = 600

            switch ($Config.Name) {
                'Ripristino immagine Windows'   { $processTimeoutSeconds = 10800 }
                'Controllo file di sistema (1)' { $processTimeoutSeconds = 3600 }
                'Controllo file di sistema (2)' { $processTimeoutSeconds = 10800 }
                'Pulizia Residui Aggiornamenti' { $processTimeoutSeconds = 3600 }
                'Controllo disco' { $processTimeoutSeconds = 900 }
                'Controllo disco approfondito'  { $processTimeoutSeconds = 3600 }
            }
            $spinnerUpdateInterval = if ($Config.Name -eq 'Ripristino immagine Windows') { 900 } else { 600 }

            if ($Config.Tool -ieq 'DISM' -and $Config.Args -contains '/StartComponentCleanup') {
                Write-StyledMessage -Type 'Info' -Text "🔧 Pulizia stato Windows Update prima di avviare Cleanup..."
                Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                Start-Sleep 1
                Remove-ItemSafely -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\SessionsPending' -Recurse
                Start-Sleep 1
            }

            $commandToRun = $Config.Tool
            $argsToRun = $Config.Args
            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
                $drive = ($Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1) ?? $env:SystemDrive
                $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }
                $commandToRun = 'cmd.exe'
                $argsToRun = @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ')")
            }

            $spinnerResult = Invoke-WithSpinner -Activity $Config.Name `
                -Command $commandToRun `
                -Arguments $argsToRun `
                -TimeoutSeconds $processTimeoutSeconds `
                -UpdateInterval $spinnerUpdateInterval `
                -LogContextKey "Repair-$($Config.Tool)"

            $exitCode = $spinnerResult.ExitCode
            $results = ($spinnerResult.StdOut + "`n" + $spinnerResult.StdErr) -split "`n"

            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r') -and ($results -join ' ').ToLower() -match 'schedule|next time.*restart|volume.*in use') {
                Write-StyledMessage -Type 'Info' -Text "🔧 $($Config.Name): controllo schedulato al prossimo riavvio."
                return @{ Success = $true; ErrorCount = 0 }
            }

            $isTimeout = ($spinnerResult.TimedOut -eq $true) -or ($null -eq $exitCode) -or ($exitCode -eq -1)

            if ($isChkdsk -and $exitCode -eq 3) {
                Write-StyledMessage -Type 'Info' -Text "🔧 $($Config.Name): controllo schedulato al prossimo riavvio."
                return @{ Success = $true; ErrorCount = 0 }
            }

            if (($Config.Tool -ieq 'DISM') -and ($results -match '0x800f0806')) {
                Write-StyledMessage -Type 'Warning' -Text "⚠️ $($Config.Name): Errore 0x800f0806 (operazioni pendenti). Questo non è un errore critico."
                Write-StyledMessage -Type 'Info' -Text "💡 Riavviare il sistema per completare le operazioni in sospeso."
                return @{ Success = $true; ErrorCount = 0 }
            }

            $hasDismSuccess = (-not $isTimeout) -and ($Config.Tool -ieq 'DISM') -and ($results -match '(?i)completed successfully')

            if (($Config.Tool -ieq 'DISM') -and ($Config.Args -contains '/ResetBase') -and $exitCode -eq 3010) {
                $hasDismSuccess = $true
            }

            $isChkdskScan = $isChkdsk -and ($Config.Args -contains '/scan')
            $chkdskCompleted = (-not $isTimeout) -and $isChkdskScan -and (($results -join ' ') -match '(?i)(scansione.*completata|scan.*completed|successfully scanned)')

            $isSuccess = (-not $isTimeout) -and (($exitCode -eq 0) -or $exitCode -eq 3010 -or $hasDismSuccess -or $chkdskCompleted)

            $errors = $warnings = @()
            if (-not $isSuccess) {
                if ($isTimeout) {
                    $errors += "Timeout: L'operazione ha superato il tempo limite ed è stata terminata."
                }

                foreach ($line in ($results | Where-Object { $_ -and ![string]::IsNullOrWhiteSpace($_.Trim()) })) {
                    $trim = $line.Trim()
                    if ($trim -match '^\[=+\s*\d+' -or $trim -match '(?i)version:|deployment image') { continue }

                    if ($isChkdsk) {
                        if ($trim -match '(?i)(stage|fase|percent complete|verificat|scanned|scanning|errors found.*corrected|volume label)') { continue }
                        if ($trim -match '(?i)(cannot|unable to|access denied|critical|fatal|corrupt file system|bad sectors)') {
                            $errors += $trim
                        }
                    }
                    else {
                        if ($trim -match '0x800f0806') {
                            # gestito separatamente
                        }
                        elseif ($trim -match '(?i)(errore|error|failed|impossibile|corrotto|corruption)') { $errors += $trim }
                        elseif ($trim -match '(?i)(warning|avviso|attenzione)') { $warnings += $trim }
                    }
                }

                if ($errors.Count -eq 0 -and -not $isTimeout) {
                    $errors += "Errore generico o terminazione anomala (ExitCode: $exitCode)."
                }
            }

            $success = $isSuccess -and ($errors.Count -eq 0)

            if ($isTimeout) {
                $message = "$($Config.Name) NON completato (interrotto per Timeout)."
            }
            else {
                $message = "$($Config.Name) completato " + $(if ($success) { 'con successo' } else { "con $($errors.Count) errori" })
            }
            Write-StyledMessage -Type 'Success' -Text $message

            if ($Config.Tool -ieq 'sfc') {
                $cbsLogPath = "C:\Windows\Logs\CBS\CBS.log"
                if (Test-Path $cbsLogPath) {
                    try {
                        $safeStepName = $Config.Name -replace '[^a-zA-Z0-9]', '_'
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                        $destLogName = "SFC_CBS_${safeStepName}_${timestamp}.log"
                        $destLogPath = Join-Path $AppConfig.Paths.Logs $destLogName
                        Copy-Item -Path $cbsLogPath -Destination $destLogPath -Force -ErrorAction SilentlyContinue
                        if (Test-Path $destLogPath) {
                            Write-StyledMessage -Type 'Info' -Text "📄 Log SFC salvato in: $destLogName"
                        }
                    }
                    catch {
                        Write-StyledMessage -Type 'Warning' -Text "⚠️ Impossibile esportare il log CBS di SFC (file in uso)."
                    }
                }
            }

            return @{ Success = $success; ErrorCount = $errors.Count }
        }
        catch {
            Write-ToolkitError -Record $_ -ToolName "WinRepairToolkit" -Message "Errore in Invoke-RepairCommand [$($Config.Tool)]"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Start-RepairCycle {
        param([int]$Attempt = 1)

        $script:CurrentAttempt = $Attempt
        Write-StyledMessage -Type 'Info' -Text "🔄 Tentativo $Attempt/$MaxRetryAttempts - Riparazione sistema."

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
            Write-StyledMessage -Type 'Warning' -Text "🔄 $totalErrors errori rilevati. Nuovo tentativo."
            Start-Sleep 3
            return Start-RepairCycle -Attempt ($Attempt + 1)
        }
        return @{ Success = ($totalErrors -eq 0); TotalErrors = $totalErrors; AttemptsUsed = $Attempt }
    }

    function Start-DeepDiskRepair {
        Write-StyledMessage -Type 'Info' -Text '🔧 Avvio riparazione profonda del disco C: al prossimo riavvio.'
        try {
            $fsutilResult = Invoke-ExternalCommandWithLog -Command 'fsutil.exe' -Arguments @('dirty', 'set', 'C:') -TimeoutSeconds 300 -LogContextKey 'DeepDiskRepair-Fsutil'
            if (-not $fsutilResult.Success) {
                Write-StyledMessage -Type 'Error' -Text "❌ Impossibile marcare il disco come dirty (fsutil)."
                return $false
            }

            $chkdskResult = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'echo Y | chkdsk C: /f /r /v /x /b') -TimeoutSeconds 7200 -LogContextKey 'DeepDiskRepair-Chkdsk'
            if (-not $chkdskResult.Success) {
                Write-StyledMessage -Type 'Error' -Text "❌ Errore durante la schedulazione di chkdsk per la riparazione profonda."
                return $false
            }

            Write-StyledMessage -Type 'Info' -Text 'Comando chkdsk inviato. Riavvia per eseguire la riparazione profonda del disco.'
            return $true
        }
        catch {
            Write-ToolkitError -Record $_ -ToolName "WinRepairToolkit" -Message "Eccezione in Start-DeepDiskRepair"
            return $false
        }
    }

    function Test-PendingOperations {
        $pendingRebootKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
            'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
        )

        foreach ($key in $pendingRebootKeys) {
            if (Test-Path $key) {
                $values = Get-ItemProperty $key -ErrorAction SilentlyContinue
                if ($values -and $values.PSObject.Properties.Count -gt 1) {
                    return $true
                }
            }
        }
        return $false
    }

    if (Test-PendingOperations) {
        Write-ToolkitLog -Level WARNING -Message "Rilevate operazioni pendenti che richiedono riavvio. DISM potrebbe fallire." -Context @{
            Tool = 'WinRepairToolkit'
            Step = 'PreExecutionCheck'
        }
        Write-StyledMessage -Type 'Warning' -Text "⚠️ Rilevate operazioni pendenti che richiedono riavvio. DISM potrebbe fallire."
        Write-StyledMessage -Type 'Info' -Text "💡 Consigliato riavviare prima di eseguire le riparazioni."
    }

    try {
        $repairResult = Start-RepairCycle

        $deepRepairScheduled = $false
        if ($repairResult.TotalErrors -gt 0) {
            Write-ToolkitLog -Level WARNING -Message "Rilevati errori persistenti. Avvio riparazione profonda." -Context @{
                Tool = 'WinRepairToolkit'
                Step = 'RepairCycle'
                TotalErrors = $repairResult.TotalErrors
            }
            Write-StyledMessage -Type 'Warning' -Text "Rilevati errori persistenti. Avvio riparazione profonda."
            $deepRepairScheduled = Start-DeepDiskRepair
        }
        else {
            Write-StyledMessage -Type 'Success' -Text "Sistema in salute. Riparazione profonda non necessaria."
        }

        Write-StyledMessage -Type 'Info' -Text "⚙️ Impostazione scadenza password illimitata."
        $null = Invoke-ExternalCommandWithLog -Command 'net' -Arguments @('accounts', '/maxpwage:unlimited') -TimeoutSeconds 30 -LogContextKey 'Repair-NetAccounts'

        if ($deepRepairScheduled) { Write-StyledMessage -Type 'Warning' -Text 'Riavvio necessario per riparazione profonda.' }

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
        Write-ToolkitError -Record $_ -ToolName "WinRepairToolkit"
    }
    finally {
        # Cleanup finale se necessario
    }
}
