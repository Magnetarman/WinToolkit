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

    $Host.UI.RawUI.WindowTitle = "Driver Backup Toolkit By MagnetarMan"
    # Configurazione
    $BackupDir = "$env:LOCALAPPDATA\WinToolkit\Driver Backup"
    $ZipName = "DriverBackup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
    $FinalZipPath = Join-Path $DesktopPath "$ZipName.zip"

    $MsgStyles = @{
        Success  = @{ Color = 'Green'; Icon = '✅' }
        Warning  = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error    = @{ Color = 'Red'; Icon = '❌' }
        Info     = @{ Color = 'Cyan'; Icon = '💎' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }

    # Funzione per centrare il testo
    function Center-Text {
        param(
            [Parameter(Mandatory = $true)][string]$Text,
            [Parameter(Mandatory = $false)][int]$Width = $Host.UI.RawUI.BufferSize.Width
        )
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent) {
        $safePercent = [Math]::Max(0, [Math]::Min(100, $Percent))
        $filled = [Math]::Floor($safePercent * 30 / 100)
        $bar = "[$('█' * $filled)$('▒' * (30 - $filled))] $safePercent%"
        Write-Host "`r🔄 $Activity $bar $Status" -NoNewline -ForegroundColor Magenta
        if ($Percent -eq 100) { Write-Host '' }
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
            '   Driver Backup Toolkit By MagnetarMan',
            '       Version 2.2 (Build 5)'
        )

        foreach ($line in $asciiArt) {
            if ($line -ne '') {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
            else {
                Write-Host ''
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    function Test-Administrator {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Start-DriverExport {
        Write-StyledMessage Info "💾 Avvio esportazione driver di terze parti..."

        try {
            # Verifica se la cartella esiste già
            if (Test-Path $BackupDir) {
                Write-StyledMessage Warning "Cartella backup esistente trovata, rimozione in corso..."
                Remove-Item $BackupDir -Recurse -Force -ErrorAction Stop
                Start-Sleep 1
            }

            # Crea la cartella di backup
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            Write-StyledMessage Success "Cartella backup creata: $BackupDir"

            # Esegue l'esportazione DISM
            Write-StyledMessage Info "🔧 Esecuzione DISM per esportazione driver..."
            Write-StyledMessage Info "💡 Questa operazione può richiedere diversi minuti..."

            $dismArgs = @('/online', '/export-driver', "/destination:`"$BackupDir`"")

            $process = Start-Process 'dism.exe' -ArgumentList $dismArgs -NoNewWindow -PassThru -Wait

            if ($process.ExitCode -eq 0) {
                # Verifica se sono stati esportati dei driver
                $exportedDrivers = Get-ChildItem -Path $BackupDir -Recurse -File -ErrorAction SilentlyContinue

                if ($exportedDrivers -and $exportedDrivers.Count -gt 0) {
                    Write-StyledMessage Success "Driver esportati con successo!"
                    Write-StyledMessage Info "Driver trovati: $($exportedDrivers.Count)"
                    return $true
                }
                else {
                    Write-StyledMessage Warning "Nessun driver di terze parti trovato da esportare"
                    Write-StyledMessage Info "💡 I driver integrati di Windows non vengono esportati"
                    return $true
                }
            }
            else {
                Write-StyledMessage Error "Errore durante esportazione DISM (Exit code: $($process.ExitCode))"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante esportazione driver: $_"
            return $false
        }
    }

    function Start-DriverCompression {
        Write-StyledMessage Info "📦 Compressione cartella backup..."

        try {
            # Verifica che la cartella esista e contenga file
            if (-not (Test-Path $BackupDir)) {
                Write-StyledMessage Error "Cartella backup non trovata"
                return $false
            }

            $files = Get-ChildItem -Path $BackupDir -Recurse -File -ErrorAction SilentlyContinue
            if (-not $files -or $files.Count -eq 0) {
                Write-StyledMessage Warning "Nessun file da comprimere nella cartella backup"
                return $false
            }

            # Calcola dimensione totale per la progress bar
            $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
            $totalSizeMB = [Math]::Round($totalSize / 1MB, 2)

            Write-StyledMessage Info "Dimensione totale: $totalSizeMB MB"

            # Crea il file ZIP
            $tempZipPath = Join-Path $env:TEMP "$ZipName.zip"

            # Rimuovi file ZIP esistente se presente
            if (Test-Path $tempZipPath) {
                Remove-Item $tempZipPath -Force -ErrorAction SilentlyContinue
            }

            # Comprime la cartella
            Write-StyledMessage Info "🔄 Compressione in corso..."

            $progress = 0
            $compressAction = {
                param($backupDir, $tempZipPath)
                Compress-Archive -Path $backupDir -DestinationPath $tempZipPath -CompressionLevel Optimal -Force
            }

            $job = Start-Job -ScriptBlock $compressAction -ArgumentList $BackupDir, $tempZipPath

            while ($job.State -eq 'Running') {
                $progress += Get-Random -Minimum 1 -Maximum 5
                if ($progress -gt 95) { $progress = 95 }

                Show-ProgressBar "Compressione" "Elaborazione file..." $progress
                Start-Sleep -Milliseconds 500
            }

            $compressResult = Receive-Job $job -Wait
            Remove-Job $job

            Show-ProgressBar "Compressione" "Completato!" 100
            Write-Host ''

            # Verifica che il file ZIP sia stato creato
            if (Test-Path $tempZipPath) {
                $zipSize = (Get-Item $tempZipPath).Length
                $zipSizeMB = [Math]::Round($zipSize / 1MB, 2)

                Write-StyledMessage Success "Compressione completata!"
                Write-StyledMessage Info "Archivio creato: $tempZipPath ($zipSizeMB MB)"

                return $tempZipPath
            }
            else {
                Write-StyledMessage Error "File ZIP non creato"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante compressione: $_"
            return $false
        }
    }

    function Move-ZipToDesktop {
        param([string]$ZipPath)

        Write-StyledMessage Info "📂 Spostamento archivio sul desktop..."

        try {
            # Verifica che il file ZIP esista
            if (-not (Test-Path $ZipPath)) {
                Write-StyledMessage Error "File ZIP non trovato: $ZipPath"
                return $false
            }

            # Sposta il file sul desktop
            Move-Item -Path $ZipPath -Destination $FinalZipPath -Force -ErrorAction Stop

            # Verifica che il file sia stato spostato
            if (Test-Path $FinalZipPath) {
                Write-StyledMessage Success "Archivio spostato sul desktop!"
                Write-StyledMessage Info "Posizione: $FinalZipPath"
                return $true
            }
            else {
                Write-StyledMessage Error "Errore durante spostamento sul desktop"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore spostamento: $_"
            return $false
        }
    }

    function Show-BackupSummary {
        param([string]$ZipPath)

        Write-Host ''
        Write-StyledMessage Success "🎉 Backup driver completato con successo!"
        Write-Host ''

        Write-StyledMessage Info "📁 Posizione archivio:"
        Write-Host "  $FinalZipPath" -ForegroundColor Cyan
        Write-Host ''

        Write-StyledMessage Info "💡 IMPORTANTE:"
        Write-StyledMessage Info "  🔄 Salva questo archivio in un luogo sicuro!"
        Write-StyledMessage Info "  💾 Potrai utilizzarlo per reinstallare tutti i driver"
        Write-StyledMessage Info "  🔧 Senza doverli riscaricare singolarmente"
        Write-Host ''
    }

    # MAIN EXECUTION
    Show-Header

    # Verifica privilegi amministrativi
    if (-not (Test-Administrator)) {
        Write-StyledMessage Error " Questo script richiede privilegi amministrativi!"
        Write-StyledMessage Info "💡 Riavvia PowerShell come Amministratore e riprova"
        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        return
    }

    Write-Host "⏳ Inizializzazione sistema..." -ForegroundColor Yellow
    Start-Sleep 2
    Write-Host Success "✅ Sistema pronto`n" -ForegroundColor Green

    try {
        # Passo 1: Esportazione driver
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 FASE 1: ESPORTAZIONE DRIVER"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        if (-not (Start-DriverExport)) {
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

        # Passo 2: Compressione
        $zipPath = Start-DriverCompression
        if (-not $zipPath) {
            Write-StyledMessage Error "Compressione fallita"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }

        Write-Host ''
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 FASE 3: SPOSTAMENTO DESKTOP"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        # Passo 3: Spostamento sul desktop
        if (-not (Move-ZipToDesktop $zipPath)) {
            Write-StyledMessage Error "Spostamento sul desktop fallito"
            Write-StyledMessage Warning "💡 L'archivio potrebbe essere ancora nella cartella temporanea"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }

        # Passo 4: Riepilogo finale
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 BACKUP COMPLETATO"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        Show-BackupSummary $FinalZipPath

    }
    catch {
        Write-StyledMessage Error "Errore critico durante il backup: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Controlla i log per dettagli o contatta il supporto"
    }
    finally {
        # Pulizia cartella temporanea
        Write-StyledMessage Info "🧹 Pulizia cartella temporanea..."
        if (Test-Path $BackupDir) {
            Remove-Item $BackupDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        Write-StyledMessage Success "🎯 Driver Backup Toolkit terminato"
    }
}

WinBackupDriver