function WinBackupDriver {
    <#
    .SYNOPSIS
        Creates a complete backup of Windows system drivers.
    .DESCRIPTION
        Exports all third-party drivers through DISM, compresses them in 7z format,
        and saves the archive to the Desktop.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 10,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "WinBackupDriver" -SubTitle (Get-Loc 'script.WinBackupDriver')

    $timeout = 86400

    $script:BackupConfig = @{
        DateTime    = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        BackupDir   = $AppConfig.Paths.DriverBackupTemp
        ArchiveName = "DriverBackup"
        DesktopPath = $AppConfig.Paths.Desktop
        TempPath    = $AppConfig.Paths.TempFolder
        LogsDir     = $AppConfig.Paths.DriverBackupLogs
    }
    $script:FinalArchivePath = "$($script:BackupConfig.DesktopPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).7z"

    # ── Helper locali ─────────────────────────────────────────────────────────

    function Initialize-BackupEnvironment {
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.initializingBackupEnvironment')
        try {
            if (Test-Path $script:BackupConfig.BackupDir) {
                Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.removingPreviousBackups')
                Remove-ItemSafely -Path $script:BackupConfig.BackupDir -Recurse
            }
            New-Item -ItemType Directory -Path $script:BackupConfig.BackupDir -Force *>$null
            New-Item -ItemType Directory -Path $script:BackupConfig.LogsDir   -Force *>$null
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.createBackupAndLogDirectories')
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.environmentInitializationError0' -Args @($_))
            return $false
        }
    }

    function Export-SystemDrivers {
        try {
            $result = Invoke-WithSpinner -Activity (Get-Loc 'toolText.extra.dismDriverExport') -Command 'dism.exe' `
                -Arguments @('/online', '/export-driver', "/destination:`"$($script:BackupConfig.BackupDir)`"") `
                -TimeoutSeconds $timeout -LogContextKey "Backup-DISM"

            if ($result.TimedOut)       { throw (Get-Loc 'toolText.extra.timeoutReachedDuringDismExport') }
            if ($result.ExitCode -ne 0) { throw (Get-Loc 'uiText.dismExportFailedWithExitcode0' -Args @($($result.ExitCode))) }

            $exportedDrivers = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
            if (-not $exportedDrivers -or $exportedDrivers.Count -eq 0) {
                Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.noThirdPartyDriversFoundToExport')
                Write-StyledMessage -Type 'Info'    -Text (Get-Loc 'toolText.windowsBuiltInDriversAreNotExported')
                return $true
            }

            $totalSizeMB = [Math]::Round(($exportedDrivers | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.exportCompleted0Driver1Mb' -Args @($($exportedDrivers.Count), $totalSizeMB))
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorExportingDriver0' -Args @($_))
            return $false
        }
    }

    function Install-7ZipPortable {
        $installDir     = Join-Path $AppConfig.Paths.LocalAppData "WinToolkit\7zip"
        $executablePath = "$installDir\7zr.exe"

        if (Test-Path $executablePath) {
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.7ZipPortableAlreadyPresent')
            return $executablePath
        }

        New-Item -ItemType Directory -Path $installDir -Force *>$null

        $downloadSources = @(
            @{ Url = $AppConfig.URLs.GitHubAssetBaseUrl + "7zr.exe"; Name = "Repository MagnetarMan" },
            @{ Url = $AppConfig.URLs.SevenZipOfficial;                Name = "Sito ufficiale 7-Zip" }
        )

        foreach ($source in $downloadSources) {
            try {
                Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.download7ZipFrom0' -Args @($($source.Name)))
                Invoke-WebRequest -Uri $source.Url -OutFile $executablePath -UseBasicParsing -ErrorAction Stop

                if (Test-Path $executablePath) {
                    $fileSize = (Get-Item $executablePath).Length
                    if ($fileSize -gt 100KB -and $fileSize -lt 10MB) {
                        $testResult = & $executablePath 2>&1
                        if ($testResult -match "7-Zip" -or $testResult -match "Licensed") {
                            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.7ZipPortableDownloadedAndVerified')
                            return $executablePath
                        }
                    }
                    Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.invalidDownloadedFileSize0Bytes' -Args @($fileSize))
                    Remove-ItemSafely -Path $executablePath
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.downloadFailedFrom01' -Args @($($source.Name), $_))
                Remove-ItemSafely -Path $executablePath
            }
        }

        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.unableToDownload7ZipFromAllSources')
        return $null
    }

    function Compress-BackupArchive {
        param([string]$SevenZipPath)

        if (-not $SevenZipPath -or -not (Test-Path $SevenZipPath)) { throw (Get-Loc 'toolText.extra.invalid7ZipPath0' -Args @($SevenZipPath)) }
        if (-not (Test-Path $script:BackupConfig.BackupDir))        { throw (Get-Loc 'toolText.extra.backupDirectoryNotFound0' -Args @($($script:BackupConfig.BackupDir))) }

        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.preparingArchiveCompression')

        $backupFiles = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
        if (-not $backupFiles) {
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.noFilesToCompressInBackupDirectory')
            return $null
        }

        $totalSizeMB = [Math]::Round(($backupFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.totalSize0Mb' -Args @($totalSizeMB))

        $archivePath    = "$($script:BackupConfig.TempPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).7z"
        $compressionArgs = @('a', '-t7z', '-mx=6', '-mmt=on', "`"$archivePath`"", "`"$($script:BackupConfig.BackupDir)\*`"")

        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.compressionWith7Zip')
        $result = Invoke-WithSpinner -Activity (Get-Loc 'toolText.extra.7ZipArchiveCompression') -Command $SevenZipPath `
            -Arguments $compressionArgs -TimeoutSeconds 800 -LogContextKey "Backup-7Zip"

        if ($result.TimedOut) { throw (Get-Loc 'toolText.extra.timeoutReachedDuringCompression') }

        if ($result.ExitCode -eq 0 -and (Test-Path $archivePath)) {
            $compressedSizeMB  = [Math]::Round((Get-Item $archivePath).Length / 1MB, 2)
            $compressionRatio  = [Math]::Round((1 - $compressedSizeMB / $totalSizeMB) * 100, 1)
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.compressionCompleted0MbReduction1' -Args @($compressedSizeMB, $compressionRatio))
            return $archivePath
        }

        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.compressionFailedWithExitcode0' -Args @($($result.ExitCode)))
        return $null
    }

    function Move-ArchiveToDesktop {
        param([string]$ArchivePath)

        if ([string]::IsNullOrWhiteSpace($ArchivePath) -or -not (Test-Path $ArchivePath)) {
            throw (Get-Loc 'toolText.extra.invalidArchivePath0' -Args @($ArchivePath))
        }

        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.movingArchiveToDesktop')
        try {
            if (-not (Test-Path $script:BackupConfig.DesktopPath)) {
                throw (Get-Loc 'toolText.extra2.desktopDirectoryNotAccessible0' -Args @($($script:BackupConfig.DesktopPath)))
            }

            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.removingOldArchive')
                Remove-ItemSafely -Path $script:FinalArchivePath
            }

            Copy-Item -Path $ArchivePath -Destination $script:FinalArchivePath -Force -ErrorAction Stop

            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.archiveSavedToDesktop')
                Write-StyledMessage -Type 'Info'    -Text (Get-Loc 'toolText.location0' -Args @($script:FinalArchivePath))
                return $true
            }

            throw (Get-Loc 'uiText.archiveCopyFailed')
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.archiveMoveError0' -Args @($_))
            return $false
        }
    }

    # ── Logica principale ─────────────────────────────────────────────────────

    try {
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.systemInitialization')
        Start-Sleep -Seconds 1

        if (-not (Initialize-BackupEnvironment)) { return }
        if (-not (Export-SystemDrivers))         { return }

        $sevenZipPath = Install-7ZipPortable | Select-Object -Last 1
        if (-not $sevenZipPath) { return }

        $compressedArchive = Compress-BackupArchive -SevenZipPath $sevenZipPath
        if (-not $compressedArchive) { return }

        if (Move-ArchiveToDesktop -ArchivePath $compressedArchive) {
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.driverBackupCompletedSuccessfully')
            Write-StyledMessage -Type 'Info'    -Text (Get-Loc 'toolText.finalArchive0' -Args @($script:FinalArchivePath))
            Write-StyledMessage -Type 'Info'    -Text (Get-Loc 'toolText.canBeUsedToReinstallAllDriversWithoutRedownloadingThem')
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinBackupDriver" -Message (Get-Loc 'toolText.extra.criticalErrorDuringBackup')
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.checkTheLogsForTechnicalDetails')
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.temporaryEnvironmentCleaning')
        Remove-ItemSafely -Path $script:BackupConfig.BackupDir -Recurse
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.driverBackupToolkitFinished')
        Write-ToolkitLog -Level INFO -Message (Get-Loc 'toolText.winbackupdriverSessionEnded')
    }
}
