function WinBackupDriver {
    <#
    .SYNOPSIS
        Strumento di backup completo per i driver di sistema Windows.

    .DESCRIPTION
        Script PowerShell per eseguire il backup completo di tutti i driver di terze parti
        installati sul sistema. Il processo include l'esportazione tramite DISM, compressione
        in formato ZIP e spostamento automatico sul desktop con nomenclatura data-based.
        Ideale per il backup pre-format o per la migrazione dei driver su un nuovo sistema.
    #>
    param([int]$CountdownSeconds = 10)

    Initialize-ToolLogging -ToolName "WinBackupDriver"
    Show-Header -SubTitle "Driver Backup Toolkit"

    $dt = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $BackupDir = "$env:LOCALAPPDATA\WinToolkit\Driver Backup"
    $ZipName = "DriverBackup_$dt"
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
    $FinalZipPath = "$DesktopPath\$ZipName.zip"

    function Test-Admin {
        $u = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($u)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Export-Drivers {
        Write-StyledMessage Info "💾 Avvio esportazione driver di terze parti..."
        try {
            if (Test-Path $BackupDir) {
                Write-StyledMessage Warning "Cartella backup esistente trovata, rimozione in corso..."
                $pos = [Console]::CursorTop
                $ErrorActionPreference = 'SilentlyContinue'
                $ProgressPreference = 'SilentlyContinue'
                Remove-Item $BackupDir -Recurse -Force -EA SilentlyContinue | Out-Null
                [Console]::SetCursorPosition(0, $pos)
                Write-Host ("`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r") -NoNewline
                [Console]::Out.Flush()
                $ErrorActionPreference = 'Continue'
                $ProgressPreference = 'Continue'
                Start-Sleep 1
            }

            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            Write-StyledMessage Success "Cartella backup creata: $BackupDir"
            Write-StyledMessage Info "🔧 Esecuzione DISM per esportazione driver..."
            Write-StyledMessage Info "💡 Questa operazione può richiedere diversi minuti..."

            $proc = Start-Process 'dism.exe' -ArgumentList @('/online', '/export-driver', "/destination:`"$BackupDir`"") -NoNewWindow -PassThru -Wait

            if ($proc.ExitCode -eq 0) {
                $drivers = Get-ChildItem $BackupDir -Recurse -File -EA SilentlyContinue
                if ($drivers -and $drivers.Count -gt 0) {
                    Write-StyledMessage Success "Driver esportati con successo!"
                    Write-StyledMessage Info "Driver trovati: $($drivers.Count)"
                }
                else {
                    Write-StyledMessage Warning "Nessun driver di terze parti trovato da esportare"
                    Write-StyledMessage Info "💡 I driver integrati di Windows non vengono esportati"
                }
                return $true
            }
            Write-StyledMessage Error "Errore durante esportazione DISM (Exit code: $($proc.ExitCode))"
            return $false
        }
        catch {
            Write-StyledMessage Error "Errore durante esportazione driver: $_"
            return $false
        }
    }

    function Compress-Backup {
        Write-StyledMessage Info "📦 Compressione cartella backup..."
        try {
            if (-not (Test-Path $BackupDir)) {
                Write-StyledMessage Error "Cartella backup non trovata"
                return $null
            }

            $files = Get-ChildItem $BackupDir -Recurse -File -EA SilentlyContinue
            if (-not $files -or $files.Count -eq 0) {
                Write-StyledMessage Warning "Nessun file da comprimere nella cartella backup"
                return $null
            }

            $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
            $totalMB = [Math]::Round($totalSize / 1MB, 2)
            Write-StyledMessage Info "Dimensione totale: $totalMB MB"

            $tempZip = "$env:TEMP\$ZipName.zip"
            if (Test-Path $tempZip) { Remove-Item $tempZip -Force -EA SilentlyContinue }

            Write-StyledMessage Info "🔄 Compressione in corso..."
            $scriptBlock = {
                param($b, $t)
                try {
                    Compress-Archive -Path $b -DestinationPath $t -CompressionLevel Optimal -Force -ErrorAction Stop | Out-Null
                    return $t
                }
                catch {
                    Write-Error "Errore durante la compressione nel job: $($_.Exception.Message)"
                    return $null
                }
            }
            $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $BackupDir, $tempZip -Name "CompressDrivers"

            Invoke-WithSpinner -Activity "Compressione" -Job -Action { $job } -UpdateInterval 500

            Wait-Job $job | Out-Null

            $jobResult = Receive-Job $job
            $jobState = $job.State
            $jobErrors = $job.ChildJobs[0].Error

            Remove-Job $job

            Show-ProgressBar "Compressione" "Completato!" 100 '📦'
            Write-Host ''

            # Verifica che il job sia completato e che abbia restituito un percorso valido
            if ($jobState -eq 'Completed' -and $jobResult -and (Test-Path $jobResult)) {
                $zipMB = [Math]::Round((Get-Item $jobResult).Length / 1MB, 2)
                Write-StyledMessage Success "Compressione completata!"
                Write-StyledMessage Info "Archivio creato: $jobResult ($zipMB MB)"
                # CORREZIONE: Restituisci SOLO il percorso del file, non return $true
                return $jobResult
            }
            else {
                Write-StyledMessage Error "Compressione fallita o archivio ZIP non creato correttamente."
                if ($jobErrors.Count -gt 0) {
                    Write-StyledMessage Error "  Dettaglio errore dal job: $($jobErrors[0].Exception.Message)"
                }
                return $null
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante compressione: $_"
            return $null
        }
    }

    function Move-ToDesktop([string]$ZipPath) {
        Write-StyledMessage Info "📂 Spostamento archivio sul desktop..."
        try {
            if ([string]::IsNullOrWhiteSpace($ZipPath) -or -not (Test-Path $ZipPath)) {
                Write-StyledMessage Error "File ZIP non trovato o percorso non valido: '$ZipPath'"
                return $false
            }

            # Verifica che il desktop esista
            if (-not (Test-Path $DesktopPath)) {
                Write-StyledMessage Error "Percorso desktop non valido: $DesktopPath"
                return $false
            }

            # Se il file di destinazione esiste già, rimuovilo
            if (Test-Path $FinalZipPath) {
                Remove-Item $FinalZipPath -Force -EA Stop
            }

            # Usa Copy-Item invece di Move-Item per maggiore affidabilità
            Copy-Item $ZipPath $FinalZipPath -Force -EA Stop

            if (Test-Path $FinalZipPath) {
                # Rimuovi il file temporaneo solo dopo aver verificato la copia
                Remove-Item $ZipPath -Force -EA SilentlyContinue
                Write-StyledMessage Success "Archivio spostato sul desktop!"
                Write-StyledMessage Info "Posizione: $FinalZipPath"
                return $true
            }

            Write-StyledMessage Error "Errore durante spostamento sul desktop"
            return $false
        }
        catch {
            Write-StyledMessage Error "Errore spostamento: $_"
            Write-StyledMessage Info "Tentativo di fallback con Copy-Item..."

            # Tentativo di fallback
            try {
                if (Test-Path $ZipPath) {
                    Copy-Item $ZipPath $FinalZipPath -Force -EA Stop
                    if (Test-Path $FinalZipPath) {
                        Remove-Item $ZipPath -Force -EA SilentlyContinue
                        Write-StyledMessage Success "Archivio copiato sul desktop (fallback)!"
                        Write-StyledMessage Info "Posizione: $FinalZipPath"
                        return $true
                    }
                }
            }
            catch {
                Write-StyledMessage Error "Anche il fallback è fallito: $_"
            }

            return $false
        }
    }

    function Show-Summary {
        Write-Host ''
        Write-StyledMessage Success "🎉 Backup driver completato con successo!"
        Write-Host ''
        Write-StyledMessage Info "📁 Posizione archivio:"
        Write-Host "  $FinalZipPath" -ForegroundColor Cyan
        Write-Host ''
        Write-StyledMessage Info "💡 IMPORTANTE:"
        Write-StyledMessage Info "  📄 Salva questo archivio in un luogo sicuro!"
        Write-StyledMessage Info "  💾 Potrai utilizzarlo per reinstallare tutti i driver"
        Write-StyledMessage Info "  🔧 Senza doverli riscaricare singolarmente"
        Write-Host ''
    }

    if (-not (Test-Admin)) {
        Write-StyledMessage Error " Questo script richiede privilegi amministrativi!"
        Write-StyledMessage Info "💡 Riavvia PowerShell come Amministratore e riprova"
        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        return
    }

    Write-Host "⏳ Inizializzazione sistema..." -ForegroundColor Yellow
    Start-Sleep 2
    Write-Host "✅ Sistema pronto`n" -ForegroundColor Green

    try {
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 FASE 1: ESPORTAZIONE DRIVER"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        if (-not (Export-Drivers)) {
            Write-StyledMessage Error "Esportazione driver fallita"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }

        Write-Host ''
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 FASE 2: COMPRESSIONE ARCHIVIO"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        $zipPath = Compress-Backup

        # CORREZIONE: Verifica che $zipPath sia una stringa valida
        if ([string]::IsNullOrWhiteSpace($zipPath) -or -not (Test-Path $zipPath)) {
            Write-StyledMessage Error "Compressione fallita o percorso non valido"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }

        Write-Host ''
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 FASE 3: SPOSTAMENTO DESKTOP"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        if (-not (Move-ToDesktop $zipPath)) {
            Write-StyledMessage Error "Spostamento sul desktop fallito"
            Write-StyledMessage Warning "💡 L'archivio potrebbe essere ancora nella cartella temporanea"
            Write-StyledMessage Info "📁 Controlla: $zipPath"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }

        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 BACKUP COMPLETATO"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''
        Show-Summary

    }
    catch {
        Write-StyledMessage Error "Errore critico durante il backup: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Controlla i log per dettagli o contatta il supporto"
    }
    finally {
        Write-StyledMessage Info "🧹 Pulizia cartella temporanea..."
        if (Test-Path $BackupDir) {
            $pos = [Console]::CursorTop
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            Remove-Item $BackupDir -Recurse -Force -EA SilentlyContinue | Out-Null
            [Console]::SetCursorPosition(0, $pos)
            Write-Host ("`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r") -NoNewline
            [Console]::Out.Flush()
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
        }
        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        Write-StyledMessage Success "🎯 Driver Backup Toolkit terminato"
        try { Stop-Transcript | Out-Null } catch {}
    }
}
