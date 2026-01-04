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

    function Get-7ZipExecutable {
        Write-StyledMessage Info "🔍 Ricerca 7-Zip..."
        
        $commonPaths = @(
            "$env:ProgramFiles\7-Zip\7z.exe",
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
            "$env:LOCALAPPDATA\7-Zip\7z.exe"
        )
        
        foreach ($path in $commonPaths) {
            if (Test-Path $path) {
                Write-StyledMessage Success "7-Zip trovato: $path"
                return $path
            }
        }
        
        Write-StyledMessage Info "7-Zip non trovato, download versione portable in corso..."
        return (Install-7ZipPortable)
    }

    function Install-7ZipPortable {
        try {
            $7zDir = "$env:LOCALAPPDATA\WinToolkit\7zip"
            $7zExe = "$7zDir\7zr.exe"
            
            if (Test-Path $7zExe) {
                Write-StyledMessage Success "Versione portable già presente"
                return $7zExe
            }
            
            New-Item -ItemType Directory -Path $7zDir -Force | Out-Null
            
            $primaryUrl = "https://www.7-zip.org/a/7zr.exe"
            $fallbackUrl = "https://github.com/Magnetarman/WinToolkit/raw/Dev/asset/7zr.exe"
            
            Write-StyledMessage Info "⬇️ Download 7-Zip standalone..."
            
            try {
                $webClient = New-Object System.Net.WebClient
                $webClient.DownloadFile($primaryUrl, $7zExe)
            }
            catch {
                Write-StyledMessage Warning "Download primario fallito, tentativo fallback..."
                $webClient = New-Object System.Net.WebClient
                $webClient.DownloadFile($fallbackUrl, $7zExe)
            }
            
            if (Test-Path $7zExe) {
                Write-StyledMessage Success "7-Zip portable scaricato con successo"
                return $7zExe
            }
            
            throw "Download 7-Zip fallito da entrambe le fonti"
        }
        catch {
            Write-StyledMessage Error "Errore download 7-Zip: $_"
            return $null
        }
    }

    function Compress-With7Zip {
        param([string]$SevenZipPath)
        
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

            Write-StyledMessage Info "🚀 Compressione con 7-Zip (livello massimo)..."
            
            $7zArgs = @(
                'a',
                '-tzip',
                '-mx9',
                '-mmt',
                "`"$tempZip`"",
                "`"$BackupDir\*`""
            )
            
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = $SevenZipPath
            $processInfo.Arguments = $7zArgs -join ' '
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $processInfo.UseShellExecute = $false
            $processInfo.CreateNoWindow = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            $process.Start() | Out-Null
            
            $spinnerChars = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
            $spinnerIndex = 0
            
            Write-Host ''
            while (-not $process.HasExited) {
                $spinnerChar = $spinnerChars[$spinnerIndex % $spinnerChars.Count]
                Write-Host "`r  $spinnerChar Compressione in corso..." -NoNewline -ForegroundColor Cyan
                $spinnerIndex++
                Start-Sleep -Milliseconds 100
            }
            
            $process.WaitForExit()
            Write-Host "`r" + (' ' * 60) + "`r" -NoNewline
            
            $exitCode = $process.ExitCode
            $stderr = $process.StandardError.ReadToEnd()
            
            if ($exitCode -eq 0 -and (Test-Path $tempZip)) {
                $zipMB = [Math]::Round((Get-Item $tempZip).Length / 1MB, 2)
                Write-StyledMessage Success "Compressione completata!"
                Write-StyledMessage Info "Archivio creato: $tempZip ($zipMB MB)"
                return $tempZip
            }
            
            Write-StyledMessage Error "Compressione fallita (Exit: $exitCode)"
            if ($stderr) {
                Write-StyledMessage Error "Dettaglio: $stderr"
            }
            return $null
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
                Write-StyledMessage Error "File ZIP non trovato: '$ZipPath'"
                return $false
            }

            if (-not (Test-Path $DesktopPath)) {
                Write-StyledMessage Error "Percorso desktop non valido: $DesktopPath"
                return $false
            }

            if (Test-Path $FinalZipPath) {
                Remove-Item $FinalZipPath -Force -EA Stop
            }

            Copy-Item $ZipPath $FinalZipPath -Force -EA Stop
            
            if (Test-Path $FinalZipPath) {
                Remove-Item $ZipPath -Force -EA SilentlyContinue
                Write-StyledMessage Success "Archivio spostato sul desktop"
                Write-StyledMessage Info "Posizione: $FinalZipPath"
                return $true
            }
            
            Write-StyledMessage Error "Errore durante spostamento sul desktop"
            return $false
        }
        catch {
            Write-StyledMessage Error "Errore spostamento: $_"
            
            try {
                if (Test-Path $ZipPath) {
                    Copy-Item $ZipPath $FinalZipPath -Force -EA Stop
                    if (Test-Path $FinalZipPath) {
                        Remove-Item $ZipPath -Force -EA SilentlyContinue
                        Write-StyledMessage Success "Archivio copiato sul desktop (fallback)"
                        Write-StyledMessage Info "Posizione: $FinalZipPath"
                        return $true
                    }
                }
            }
            catch {
                Write-StyledMessage Error "Fallback fallito: $_"
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
        Write-StyledMessage Info "  📄 Salva questo archivio in un luogo sicuro"
        Write-StyledMessage Info "  💾 Utilizzabile per reinstallare tutti i driver"
        Write-StyledMessage Info "  🔧 Senza doverli riscaricare singolarmente"
        Write-Host ''
    }

    if (-not (Test-Admin)) {
        Write-StyledMessage Error "❌ Privilegi amministrativi richiesti"
        Write-StyledMessage Info "💡 Riavvia PowerShell come Amministratore"
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
        Write-StyledMessage Info "📋 FASE 2: CONFIGURAZIONE 7-ZIP"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        $7zPath = Get-7ZipExecutable
        if (-not $7zPath) {
            Write-StyledMessage Error "Impossibile ottenere 7-Zip"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }

        Write-Host ''
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 FASE 3: COMPRESSIONE ARCHIVIO"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        $zipPath = Compress-With7Zip -SevenZipPath $7zPath
        
        if ([string]::IsNullOrWhiteSpace($zipPath) -or -not (Test-Path $zipPath)) {
            Write-StyledMessage Error "Compressione fallita"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }

        Write-Host ''
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 FASE 4: SPOSTAMENTO DESKTOP"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        if (-not (Move-ToDesktop $zipPath)) {
            Write-StyledMessage Error "Spostamento sul desktop fallito"
            Write-StyledMessage Warning "💡 L'archivio è in: $zipPath"
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
        Write-StyledMessage Error "Errore critico: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Controlla i log per dettagli"
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