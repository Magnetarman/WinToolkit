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
        Write-StyledMessage -Type 'Info' -Text "🗂️ Inizializzazione ambiente backup."

        try {
            if (Test-Path $script:BackupConfig.BackupDir) {
                Write-StyledMessage -Type 'Warning' -Text "Rimozione backup precedenti."
                Remove-Item $script:BackupConfig.BackupDir -Recurse -Force -ErrorAction Stop *>$null
            }

            New-Item -ItemType Directory -Path $script:BackupConfig.BackupDir -Force *>$null
            New-Item -ItemType Directory -Path $script:BackupConfig.LogsDir -Force *>$null
            Write-StyledMessage -Type 'Success' -Text "Directory backup e log create."
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore inizializzazione ambiente: $_"
            return $false
        }
    }

    function Export-SystemDrivers {
        try {
            # Utilizzo del nuovo pattern Invoke-WithSpinner che internamente usa Invoke-ExternalCommandWithLog
            $result = Invoke-WithSpinner -Activity "Esportazione driver DISM" -Command 'dism.exe' -Arguments @('/online', '/export-driver', "/destination:`"$($script:BackupConfig.BackupDir)`"") -TimeoutSeconds $timeout -LogContextKey "Backup-DISM"

            if ($result.TimedOut) {
                throw "Timeout raggiunto durante l'esportazione DISM"
            }

            if ($result.ExitCode -ne 0) {
                throw "Esportazione DISM fallita con ExitCode: $($result.ExitCode)."
            }

            $exportedDrivers = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
            if (-not $exportedDrivers -or $exportedDrivers.Count -eq 0) {
                Write-StyledMessage -Type 'Warning' -Text "Nessun driver di terze parti trovato da esportare."
                Write-StyledMessage -Type 'Info' -Text "💡 I driver integrati di Windows non vengono esportati."
                return $true
            }

            $totalSize = ($exportedDrivers | Measure-Object -Property Length -Sum).Sum
            $totalSizeMB = [Math]::Round($totalSize / 1MB, 2)

            Write-StyledMessage -Type 'Success' -Text "Esportazione completata: $($exportedDrivers.Count) driver trovati ($totalSizeMB MB)."
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante esportazione driver: $_"
            return $false
        }
    }

    function Resolve-7ZipExecutable {
        return Install-7ZipPortable
    }

    function Install-7ZipPortable {
        $installDir = Join-Path $AppConfig.Paths.LocalAppData "WinToolkit\7zip"
        $executablePath = "$installDir\7zr.exe"

        if (Test-Path $executablePath) {
            Write-StyledMessage -Type 'Success' -Text "7-Zip portable già presente."
            return $executablePath
        }

        New-Item -ItemType Directory -Path $installDir -Force *>$null

        $downloadSources = @(
            @{ Url = $AppConfig.URLs.GitHubAssetBaseUrl + "7zr.exe"; Name = "Repository MagnetarMan" },
            @{ Url = $AppConfig.URLs.SevenZipOfficial; Name = "Sito ufficiale 7-Zip" }
        )

        foreach ($source in $downloadSources) {
            try {
                Write-StyledMessage -Type 'Info' -Text "⬇️ Download 7-Zip da: $($source.Name)"
                Invoke-WebRequest -Uri $source.Url -OutFile $executablePath -UseBasicParsing -ErrorAction Stop

                if (Test-Path $executablePath) {
                    $fileSize = (Get-Item $executablePath).Length

                    if ($fileSize -gt 100KB -and $fileSize -lt 10MB) {
                        $testResult = & $executablePath 2>&1
                        if ($testResult -match "7-Zip" -or $testResult -match "Licensed") {
                            Write-StyledMessage -Type 'Success' -Text "7-Zip portable scaricato e verificato."
                            return $executablePath
                        }
                    }

                    Write-StyledMessage -Type 'Warning' -Text "File scaricato non valido (Dimensione: $fileSize bytes)."
                    Remove-Item $executablePath -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Download fallito da $($source.Name): $_"
                if (Test-Path $executablePath) {
                    Remove-Item $executablePath -Force -ErrorAction SilentlyContinue
                }
            }
        }

        Write-StyledMessage -Type 'Error' -Text "Impossibile scaricare 7-Zip da tutte le fonti."
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

        Write-StyledMessage -Type 'Info' -Text "📦 Preparazione compressione archivio."

        $backupFiles = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
        if (-not $backupFiles) {
            Write-StyledMessage -Type 'Warning' -Text "Nessun file da comprimere nella directory backup."
            return $null
        }

        $totalSizeMB = [Math]::Round(($backupFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-StyledMessage -Type 'Info' -Text "Dimensione totale: $totalSizeMB MB"

        $archivePath = "$($script:BackupConfig.TempPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).7z"
        $compressionArgs = @('a', '-t7z', '-mx=6', '-mmt=on', "`"$archivePath`"", "`"$($script:BackupConfig.BackupDir)\*`"")

        # File per reindirizzare l'output di 7zip
        $stdOutputPath = "$($script:BackupConfig.LogsDir)\7zip_$($script:BackupConfig.DateTime).log"
        $stdErrorPath = "$($script:BackupConfig.LogsDir)\7zip_err_$($script:BackupConfig.DateTime).log"

        try {
            Write-StyledMessage -Type 'Info' -Text "🚀 Compressione con 7-Zip."

            $result = Invoke-WithSpinner -Activity "Compressione archivio 7-Zip" -Command $SevenZipPath -Arguments $compressionArgs -TimeoutSeconds 800 -LogContextKey "Backup-7Zip"

            if ($result.TimedOut) {
                throw "Timeout raggiunto durante la compressione."
            }

            if ($result.ExitCode -eq 0 -and (Test-Path $archivePath)) {
                $compressedSizeMB = [Math]::Round((Get-Item $archivePath).Length / 1MB, 2)
                $compressionRatio = [Math]::Round((1 - $compressedSizeMB / $totalSizeMB) * 100, 1)

                Write-StyledMessage -Type 'Success' -Text "Compressione completata: $compressedSizeMB MB (Riduzione: $compressionRatio%)."
                return $archivePath
            }
            else {
                Write-StyledMessage -Type 'Error' -Text "Compressione fallita con ExitCode: $($result.ExitCode)."
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

        Write-StyledMessage -Type 'Info' -Text "📂 Spostamento archivio su desktop."

        try {
            if (-not (Test-Path $script:BackupConfig.DesktopPath)) {
                throw "Directory desktop non accessibile: $($script:BackupConfig.DesktopPath)"
            }

            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage -Type 'Warning' -Text "Rimozione archivio precedente."
                Remove-Item $script:FinalArchivePath -Force -ErrorAction Stop
            }

            Copy-Item -Path $ArchivePath -Destination $script:FinalArchivePath -Force -ErrorAction Stop

            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage -Type 'Success' -Text "Archivio salvato sul desktop."
                Write-StyledMessage -Type 'Info' -Text "Posizione: $script:FinalArchivePath"
                return $true
            }

            throw "Copia archivio fallita."
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore spostamento archivio: $_"
            return $false
        }
    }

    try {
        if (-not (Test-AdministratorPrivilege)) {
            Write-StyledMessage -Type 'Error' -Text "❌ Privilegi amministratore richiesti."
            Write-StyledMessage -Type 'Info' -Text "💡 Riavvia PowerShell come Amministratore."
            Write-StyledMessage -Type 'Info' -Text "`n⌨️ Premi un tasto per uscire."
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        Write-StyledMessage -Type 'Info' -Text "🚀 Inizializzazione sistema."
        Start-Sleep -Seconds 1

        if (Initialize-BackupEnvironment) {


            if (Export-SystemDrivers) {


                $sevenZipPath = (Resolve-7ZipExecutable | Select-Object -Last 1)
                if ($sevenZipPath) {


                    $compressedArchive = Compress-BackupArchive -SevenZipPath $sevenZipPath
                    if ($compressedArchive) {


                        if (Move-ArchiveToDesktop -ArchivePath $compressedArchive) {

                            Write-StyledMessage -Type 'Success' -Text "🎉 Backup driver completato con successo!"
                                Write-StyledMessage -Type 'Info' -Text "📁 Archivio finale: $script:FinalArchivePath"
                                Write-StyledMessage -Type 'Info' -Text "💾 Utilizzabile per reinstallare tutti i driver."
                                Write-StyledMessage -Type 'Info' -Text "🔧 Senza doverli riscaricare singolarmente."
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore critico durante backup: $($_.Exception.Message)"
        Write-StyledMessage -Type 'Info' -Text "💡 Controlla i log per dettagli tecnici."
        Write-ToolkitLog -Level ERROR -Message "Errore critico in WinBackupDriver" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text "🧹 Pulizia ambiente temporaneo."
        if (Test-Path $script:BackupConfig.BackupDir) {
            Remove-Item $script:BackupConfig.BackupDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-ToolkitLog -Level INFO -Message "WinBackupDriver sessione terminata."
        Write-StyledMessage -Type 'Success' -Text "🎯 Driver Backup Toolkit terminato."
    }
}
