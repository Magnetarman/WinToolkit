function WinBackupDriver {
    <#
    .SYNOPSIS
        Strumento di backup completo per i driver di sistema Windows.
    .DESCRIPTION
        Script PowerShell per eseguire il backup completo di tutti i driver di terze parti
        installati sul sistema. Il processo include l'esportazione tramite DISM, compressione
        in formato 7z e spostamento automatico sul desktop.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 10,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Start-ToolkitLog -ToolName "WinBackupDriver"
    Show-Header -SubTitle "Driver Backup Toolkit"
    $Host.UI.RawUI.WindowTitle = "Driver Backup Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    $timeout = 86400    # Timer di un giorno in secondi.
    
    $script:BackupConfig = @{
        DateTime    = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        BackupDir   = $AppConfig.Paths.DriverBackupTemp
        ArchiveName = "DriverBackup"
        DesktopPath = $AppConfig.Paths.Desktop
        TempPath    = $AppConfig.Paths.TempFolder
        LogsDir     = $AppConfig.Paths.DriverBackupLogs
    }

    $script:FinalArchivePath = "$($script:BackupConfig.DesktopPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).7z"

    # ============================================================================
    # 3. FUNZIONI HELPER LOCALI
    # ============================================================================

    function Test-AdministratorPrivilege {
        $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Initialize-BackupEnvironment {
        Write-StyledMessage Info "🗂️ Inizializzazione ambiente backup..."

        try {
            if (Test-Path $script:BackupConfig.BackupDir) {
                Write-StyledMessage Warning "Rimozione backup precedenti..."
                Remove-Item $script:BackupConfig.BackupDir -Recurse -Force -ErrorAction Stop | Out-Null
            }

            New-Item -ItemType Directory -Path $script:BackupConfig.BackupDir -Force | Out-Null
            New-Item -ItemType Directory -Path $script:BackupConfig.LogsDir -Force | Out-Null
            Write-StyledMessage Success "Directory backup e log create"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore inizializzazione ambiente: $_"
            return $false
        }
    }

    function Export-SystemDrivers {
        Write-StyledMessage Info "💾 Avvio esportazione driver di sistema..."

        $outFile = "$($script:BackupConfig.LogsDir)\dism_$($script:BackupConfig.DateTime).log"
        $errFile = "$($script:BackupConfig.LogsDir)\dism_err_$($script:BackupConfig.DateTime).log"

        try {
            # Usa Invoke-WithSpinner per monitorare il processo DISM
            $result = Invoke-WithSpinner -Activity "Esportazione driver DISM" -Process -Action {
                $procParams = @{
                    FilePath               = 'dism.exe'
                    ArgumentList           = @('/online', '/export-driver', "/destination:`"$($script:BackupConfig.BackupDir)`"")
                    NoNewWindow            = $true
                    PassThru               = $true
                    RedirectStandardOutput = $outFile
                    RedirectStandardError  = $errFile
                }
                Start-Process @procParams
            } -TimeoutSeconds $timeout -UpdateInterval 1000

            if ($result.TimedOut) {
                throw "Timeout raggiunto durante l'esportazione DISM"
            }

            if ($result.ExitCode -ne 0) {
                $errorDetails = if (Test-Path $errFile) {
                    (Get-Content $errFile -ErrorAction SilentlyContinue) -join '; '
                }
                else { "Dettagli non disponibili" }
                throw "Esportazione DISM fallita (ExitCode: $($result.ExitCode)). Dettagli: $errorDetails"
            }

            $exportedDrivers = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
            if (-not $exportedDrivers -or $exportedDrivers.Count -eq 0) {
                Write-StyledMessage Warning "Nessun driver di terze parti trovato da esportare"
                Write-StyledMessage Info "💡 I driver integrati di Windows non vengono esportati"
                return $true
            }

            $totalSize = ($exportedDrivers | Measure-Object -Property Length -Sum).Sum
            $totalSizeMB = [Math]::Round($totalSize / 1MB, 2)

            Write-StyledMessage Success "Esportazione completata: $($exportedDrivers.Count) driver trovati ($totalSizeMB MB)"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore durante esportazione driver: $_"
            return $false
        }
    }

    function Resolve-7ZipExecutable {
        return Install-7ZipPortable
    }

    function Install-7ZipPortable {
        $installDir = "$env:LOCALAPPDATA\WinToolkit\7zip"
        $executablePath = "$installDir\7zr.exe"

        if (Test-Path $executablePath) {
            Write-StyledMessage Success "7-Zip portable già presente"
            return $executablePath
        }

        New-Item -ItemType Directory -Path $installDir -Force | Out-Null

        $downloadSources = @(
            @{ Url = $AppConfig.URLs.GitHubAssetBaseUrl + "7zr.exe"; Name = "Repository MagnetarMan" },
            @{ Url = $AppConfig.URLs.SevenZipOfficial; Name = "Sito ufficiale 7-Zip" }
        )

        foreach ($source in $downloadSources) {
            try {
                Write-StyledMessage Info "⬇️ Download 7-Zip da: $($source.Name)"
                Invoke-WebRequest -Uri $source.Url -OutFile $executablePath -UseBasicParsing -ErrorAction Stop

                if (Test-Path $executablePath) {
                    $fileSize = (Get-Item $executablePath).Length

                    if ($fileSize -gt 100KB -and $fileSize -lt 10MB) {
                        $testResult = & $executablePath 2>&1
                        if ($testResult -match "7-Zip" -or $testResult -match "Licensed") {
                            Write-StyledMessage Success "7-Zip portable scaricato e verificato"
                            return $executablePath
                        }
                    }

                    Write-StyledMessage Warning "File scaricato non valido (Dimensione: $fileSize bytes)"
                    Remove-Item $executablePath -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-StyledMessage Warning "Download fallito da $($source.Name): $_"
                if (Test-Path $executablePath) {
                    Remove-Item $executablePath -Force -ErrorAction SilentlyContinue
                }
            }
        }

        Write-StyledMessage Error "Impossibile scaricare 7-Zip da tutte le fonti"
        return $null
    }

    function Compress-BackupArchive {
        param([string]$SevenZipPath)

        if (-not $SevenZipPath -or -not (Test-Path $SevenZipPath)) {
            throw "Percorso 7-Zip non valido: $SevenZipPath"
        }

        if (-not (Test-Path $script:BackupConfig.BackupDir)) {
            throw "Directory backup non trovata: $($script:BackupConfig.BackupDir)"
        }

        Write-StyledMessage Info "📦 Preparazione compressione archivio..."

        $backupFiles = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
        if (-not $backupFiles) {
            Write-StyledMessage Warning "Nessun file da comprimere nella directory backup"
            return $null
        }

        $totalSizeMB = [Math]::Round(($backupFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-StyledMessage Info "Dimensione totale: $totalSizeMB MB"

        $archivePath = "$($script:BackupConfig.TempPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).7z"
        $compressionArgs = @('a', '-t7z', '-mx=6', '-mmt=on', "`"$archivePath`"", "`"$($script:BackupConfig.BackupDir)\*`"")

        # File per reindirizzare l'output di 7zip
        $stdOutputPath = "$($script:BackupConfig.LogsDir)\7zip_$($script:BackupConfig.DateTime).log"
        $stdErrorPath = "$($script:BackupConfig.LogsDir)\7zip_err_$($script:BackupConfig.DateTime).log"

        try {
            Write-StyledMessage Info "🚀 Compressione con 7-Zip..."

            # Usa Invoke-WithSpinner per monitorare il processo 7zip
            $result = Invoke-WithSpinner -Activity "Compressione archivio 7-Zip" -Process -Action {
                $procParams = @{
                    FilePath               = $SevenZipPath
                    ArgumentList           = $compressionArgs
                    NoNewWindow            = $true
                    PassThru               = $true
                    RedirectStandardOutput = $stdOutputPath
                    RedirectStandardError  = $stdErrorPath
                }
                Start-Process @procParams
            } -TimeoutSeconds 800 -UpdateInterval 1000

            if ($result.TimedOut) {
                throw "Timeout raggiunto durante la compressione"
            }

            if ($result.ExitCode -eq 0 -and (Test-Path $archivePath)) {
                $compressedSizeMB = [Math]::Round((Get-Item $archivePath).Length / 1MB, 2)
                $compressionRatio = [Math]::Round((1 - $compressedSizeMB / $totalSizeMB) * 100, 1)

                Write-StyledMessage Success "Compressione completata: $compressedSizeMB MB (Riduzione: $compressionRatio%)"
                return $archivePath
            }
            else {
                # Log degli errori di 7zip per debugging
                $errorDetails = if (Test-Path $stdErrorPath) {
                    $errorContent = Get-Content $stdErrorPath -ErrorAction SilentlyContinue
                    if ($errorContent) { $errorContent -join '; ' } else { "Log errori vuoto" }
                }
                else { "File di log errori non trovato" }

                Write-StyledMessage Error "Compressione fallita (ExitCode: $($result.ExitCode)). Dettagli: $errorDetails"
                return $null
            }
        }
        finally {
            # Log conservati in $script:BackupConfig.LogsDir per debugging
        }
    }

    function Move-ArchiveToDesktop {
        param([string]$ArchivePath)

        if ([string]::IsNullOrWhiteSpace($ArchivePath) -or -not (Test-Path $ArchivePath)) {
            throw "Percorso archivio non valido: $ArchivePath"
        }

        Write-StyledMessage Info "📂 Spostamento archivio su desktop..."

        try {
            if (-not (Test-Path $script:BackupConfig.DesktopPath)) {
                throw "Directory desktop non accessibile: $($script:BackupConfig.DesktopPath)"
            }

            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage Warning "Rimozione archivio precedente..."
                Remove-Item $script:FinalArchivePath -Force -ErrorAction Stop
            }

            Copy-Item -Path $ArchivePath -Destination $script:FinalArchivePath -Force -ErrorAction Stop

            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage Success "Archivio salvato sul desktop"
                Write-StyledMessage Info "Posizione: $script:FinalArchivePath"
                return $true
            }

            throw "Copia archivio fallita"
        }
        catch {
            Write-StyledMessage Error "Errore spostamento archivio: $_"
            return $false
        }
    }

    try {
        if (-not (Test-AdministratorPrivilege)) {
            Write-StyledMessage Error "❌ Privilegi amministratore richiesti"
            Write-StyledMessage Info "💡 Riavvia PowerShell come Amministratore"
            Read-Host "`nPremi INVIO per uscire"
            return
        }

        Write-StyledMessage Info "🚀 Inizializzazione sistema..."
        Start-Sleep -Seconds 1

        if (Initialize-BackupEnvironment) {
            Write-Host ""

            if (Export-SystemDrivers) {
                Write-Host ""

                $sevenZipPath = (Resolve-7ZipExecutable | Select-Object -Last 1)
                if ($sevenZipPath) {
                    Write-Host ""

                    $compressedArchive = Compress-BackupArchive -SevenZipPath $sevenZipPath
                    if ($compressedArchive) {
                        Write-Host ""

                        if (Move-ArchiveToDesktop -ArchivePath $compressedArchive) {
                            Write-Host ""
                            Write-StyledMessage Success "🎉 Backup driver completato con successo!"
                            Write-StyledMessage Info "📁 Archivio finale: $script:FinalArchivePath"
                            Write-StyledMessage Info "💾 Utilizzabile per reinstallare tutti i driver"
                            Write-StyledMessage Info "🔧 Senza doverli riscaricare singolarmente"
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-StyledMessage Error "Errore critico durante backup: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Controlla i log per dettagli tecnici"
        Write-ToolkitLog -Level ERROR -Message "Errore critico in WinBackupDriver" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage Info "🧹 Pulizia ambiente temporaneo..."
        if (Test-Path $script:BackupConfig.BackupDir) {
            Remove-Item $script:BackupConfig.BackupDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-ToolkitLog -Level INFO -Message "WinBackupDriver sessione terminata."
        Write-StyledMessage Success "🎯 Driver Backup Toolkit terminato"
    }
}
