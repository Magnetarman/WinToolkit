function WinRepairToolkit {
    <#
.SYNOPSIS
    Esegue riparazioni standard di Windows (SFC, DISM, Chkdsk).
#>
    param([int]$MaxRetryAttempts = 3, [int]$CountdownSeconds = 30)

    Initialize-ToolLogging -ToolName "WinRepairToolkit"
    Show-Header -SubTitle "Repair Toolkit"

    $script:CurrentAttempt = 0
    $RepairTools = @(
        @{ Tool = 'chkdsk'; Args = @('/scan', '/perf'); Name = 'Controllo disco'; Icon = '💽' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (1)'; Icon = '🗂️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Name = 'Ripristino immagine Windows'; Icon = '🛠️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'); Name = 'Pulizia Residui Aggiornamenti'; Icon = '🕸️' }
        @{ Tool = 'powershell.exe'; Args = @('-Command', "Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction Stop"); Name = 'Registrazione AppX (Client CBS)'; Icon = '📦'; IsCritical = $false }
        @{ Tool = 'powershell.exe'; Args = @('-Command', "Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction Stop"); Name = 'Registrazione AppX (UI Xaml CBS)'; Icon = '📦'; IsCritical = $false }
        @{ Tool = 'powershell.exe'; Args = @('-Command', "Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.Core_cw5n1h2txyewy\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction Stop"); Name = 'Registrazione AppX (Client Core)'; Icon = '📦'; IsCritical = $false }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (2)'; Icon = '🗂️' }
    )

    function Invoke-RepairCommand([hashtable]$Config, [int]$Step, [int]$Total) {
        Write-StyledMessage Info "[$Step/$Total] Avvio $($Config.Name)..."
        $isChkdsk = ($Config.Tool -ieq 'chkdsk')
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()

        try {
            # Sposta l'intera logica di avvio del processo all'interno del blocco di script per Invoke-WithSpinner
            $result = Invoke-WithSpinner -Activity $Config.Name -Process -Action {
                if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
                    $drive = ($Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1) ?? $env:SystemDrive
                    $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }
                    Start-Process 'cmd.exe' @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ')") -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
                }
                else {
                    Start-Process $Config.Tool $Config.Args -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
                }
            } -UpdateInterval $(if ($Config.Name -eq 'Ripristino immagine Windows') { 900 } else { 600 })

            $results = @()
            @($outFile, $errFile) | Where-Object { Test-Path $_ } | ForEach-Object {
                $results += Get-Content $_ -ErrorAction SilentlyContinue
            }

            # Logica controllo errori originale
            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r') -and ($results -join ' ').ToLower() -match 'schedule|next time.*restart|volume.*in use') {
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

    function Start-RepairCycle([int]$Attempt = 1) {
        $script:CurrentAttempt = $Attempt
        Write-StyledMessage Info "🔄 Tentativo $Attempt/$MaxRetryAttempts - Riparazione sistema..."
        Write-Host ''

        $totalErrors = $successCount = 0
        for ($i = 0; $i -lt $RepairTools.Count; $i++) {
            $result = Invoke-RepairCommand $RepairTools[$i] ($i + 1) $RepairTools.Count
            if ($result.Success) { $successCount++ }
            if (!$result.Success -and !($RepairTools[$i].ContainsKey('IsCritical') -and !$RepairTools[$i].IsCritical)) {
                $totalErrors += $result.ErrorCount
            }
            Start-Sleep 1
        }

        if ($totalErrors -gt 0 -and $Attempt -lt $MaxRetryAttempts) {
            Write-StyledMessage Warning "🔄 $totalErrors errori rilevati. Nuovo tentativo..."
            Start-Sleep 3
            return Start-RepairCycle ($Attempt + 1)
        }
        return @{ Success = ($totalErrors -eq 0); TotalErrors = $totalErrors; AttemptsUsed = $Attempt }
    }

    function Start-DeepDiskRepair {
        Write-StyledMessage Warning '🔧 Vuoi eseguire una riparazione profonda del disco C:?'
        $response = Read-Host 'Procedere con la riparazione profonda? (s/n)'
        if ($response.ToLower() -ne 's') { return $false }
        try {
            Start-Process 'fsutil.exe' @('dirty', 'set', 'C:') -NoNewWindow -Wait
            Start-Process 'cmd.exe' @('/c', 'echo Y | chkdsk C: /f /r /v /x /b') -WindowStyle Hidden -Wait
            Write-StyledMessage Info 'Comando chkdsk inviato. Riavvia per eseguire.'
            return $true
        }
        catch { return $false }
    }

    # Esecuzione
    try {
        $repairResult = Start-RepairCycle
        $deepRepairScheduled = Start-DeepDiskRepair

        Write-StyledMessage Info "⚙️ Impostazione scadenza password illimitata..."
        Start-Process "net" -ArgumentList "accounts", "/maxpwage:unlimited" -NoNewWindow -Wait

        if ($deepRepairScheduled) { Write-StyledMessage Warning 'Riavvio necessario per riparazione profonda.' }

        if (Start-InterruptibleCountdown $CountdownSeconds 'Riavvio automatico') {
            Restart-Computer -Force
        }
    }
    catch {
        Write-StyledMessage Error "❌ Errore critico: $($_.Exception.Message)"
    }
}
