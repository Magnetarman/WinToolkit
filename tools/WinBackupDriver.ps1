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

    Start-ToolkitSession -ToolName "WinBackupDriver" -SubTitle (Get-SourceTextLoc 'script.WinBackupDriver')

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
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.initializingBackupEnvironment')
        try {
            if (Test-Path $script:BackupConfig.BackupDir) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.removingPreviousBackups')
                Remove-ItemSafely -Path $script:BackupConfig.BackupDir -Recurse
            }
            New-Item -ItemType Directory -Path $script:BackupConfig.BackupDir -Force *>$null
            New-Item -ItemType Directory -Path $script:BackupConfig.LogsDir   -Force *>$null
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.createBackupAndLogDirectories')
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.environmentInitializationError0' -Args @($_))
            return $false
        }
    }

    function Export-SystemDrivers {
        try {
            $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.dismDriverExport') -Command 'dism.exe' `
                -Arguments @('/online', '/export-driver', "/destination:`"$($script:BackupConfig.BackupDir)`"") `
                -TimeoutSeconds $timeout -LogContextKey "Backup-DISM"

            if ($result.TimedOut)       { throw (Get-SourceTextLoc 'toolText.extra.timeoutReachedDuringDismExport') }
            if ($result.ExitCode -ne 0) { throw (Get-SourceTextLoc 'uiText.dismExportFailedWithExitcode0' -Args @($($result.ExitCode))) }

            $exportedDrivers = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
            if (-not $exportedDrivers -or $exportedDrivers.Count -eq 0) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.noThirdPartyDriversFoundToExport')
                Write-StyledMessage -Type 'Info'    -Text (Get-SourceTextLoc 'toolText.windowsBuiltInDriversAreNotExported')
                return $true
            }

            $totalSizeMB = [Math]::Round(($exportedDrivers | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.exportCompleted0Driver1Mb' -Args @($($exportedDrivers.Count), $totalSizeMB))
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorExportingDriver0' -Args @($_))
            return $false
        }
    }

    function Install-7ZipPortable {
        $installDir     = Join-Path $AppConfig.Paths.LocalAppData "WinToolkit\7zip"
        $executablePath = "$installDir\7zr.exe"

        if (Test-Path $executablePath) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.7ZipPortableAlreadyPresent')
            return $executablePath
        }

        New-Item -ItemType Directory -Path $installDir -Force *>$null

        $downloadSources = @(
            @{ Url = $AppConfig.URLs.GitHubAssetBaseUrl + "7zr.exe"; Name = "Repository MagnetarMan" },
            @{ Url = $AppConfig.URLs.SevenZipOfficial;                Name = "Sito ufficiale 7-Zip" }
        )

        foreach ($source in $downloadSources) {
            try {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.download7ZipFrom0' -Args @($($source.Name)))
                Invoke-WebRequest -Uri $source.Url -OutFile $executablePath -UseBasicParsing -ErrorAction Stop

                if (Test-Path $executablePath) {
                    $fileSize = (Get-Item $executablePath).Length
                    if ($fileSize -gt 100KB -and $fileSize -lt 10MB) {
                        $testResult = & $executablePath 2>&1
                        if ($testResult -match "7-Zip" -or $testResult -match "Licensed") {
                            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.7ZipPortableDownloadedAndVerified')
                            return $executablePath
                        }
                    }
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.invalidDownloadedFileSize0Bytes' -Args @($fileSize))
                    Remove-ItemSafely -Path $executablePath
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.downloadFailedFrom01' -Args @($($source.Name), $_))
                Remove-ItemSafely -Path $executablePath
            }
        }

        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToDownload7ZipFromAllSources')
        return $null
    }

    function Compress-BackupArchive {
        param([string]$SevenZipPath)

        if (-not $SevenZipPath -or -not (Test-Path $SevenZipPath)) { throw (Get-SourceTextLoc 'toolText.extra.invalid7ZipPath0' -Args @($SevenZipPath)) }
        if (-not (Test-Path $script:BackupConfig.BackupDir))        { throw (Get-SourceTextLoc 'toolText.extra.backupDirectoryNotFound0' -Args @($($script:BackupConfig.BackupDir))) }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.preparingArchiveCompression')

        $backupFiles = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
        if (-not $backupFiles) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.noFilesToCompressInBackupDirectory')
            return $null
        }

        $totalSizeMB = [Math]::Round(($backupFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.totalSize0Mb' -Args @($totalSizeMB))

        $archivePath    = "$($script:BackupConfig.TempPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).7z"
        $compressionArgs = @('a', '-t7z', '-mx=6', '-mmt=on', "`"$archivePath`"", "`"$($script:BackupConfig.BackupDir)\*`"")

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.compressionWith7Zip')
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.7ZipArchiveCompression') -Command $SevenZipPath `
            -Arguments $compressionArgs -TimeoutSeconds 800 -LogContextKey "Backup-7Zip"

        if ($result.TimedOut) { throw (Get-SourceTextLoc 'toolText.extra.timeoutReachedDuringCompression') }

        if ($result.ExitCode -eq 0 -and (Test-Path $archivePath)) {
            $compressedSizeMB  = [Math]::Round((Get-Item $archivePath).Length / 1MB, 2)
            $compressionRatio  = [Math]::Round((1 - $compressedSizeMB / $totalSizeMB) * 100, 1)
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.compressionCompleted0MbReduction1' -Args @($compressedSizeMB, $compressionRatio))
            return $archivePath
        }

        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.compressionFailedWithExitcode0' -Args @($($result.ExitCode)))
        return $null
    }

    function Move-ArchiveToDesktop {
        param([string]$ArchivePath)

        if ([string]::IsNullOrWhiteSpace($ArchivePath) -or -not (Test-Path $ArchivePath)) {
            throw (Get-SourceTextLoc 'toolText.extra.invalidArchivePath0' -Args @($ArchivePath))
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.movingArchiveToDesktop')
        try {
            if (-not (Test-Path $script:BackupConfig.DesktopPath)) {
                throw (Get-SourceTextLoc 'toolText.extra2.desktopDirectoryNotAccessible0' -Args @($($script:BackupConfig.DesktopPath)))
            }

            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.removingOldArchive')
                Remove-ItemSafely -Path $script:FinalArchivePath
            }

            Copy-Item -Path $ArchivePath -Destination $script:FinalArchivePath -Force -ErrorAction Stop

            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.archiveSavedToDesktop')
                Write-StyledMessage -Type 'Info'    -Text (Get-SourceTextLoc 'toolText.location0' -Args @($script:FinalArchivePath))
                return $true
            }

            throw (Get-SourceTextLoc 'uiText.archiveCopyFailed')
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.archiveMoveError0' -Args @($_))
            return $false
        }
    }

    # ── Logica principale ─────────────────────────────────────────────────────

    try {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.systemInitialization')
        Start-Sleep -Seconds 1

        if (-not (Initialize-BackupEnvironment)) { return }
        if (-not (Export-SystemDrivers))         { return }

        $sevenZipPath = Install-7ZipPortable | Select-Object -Last 1
        if (-not $sevenZipPath) { return }

        $compressedArchive = Compress-BackupArchive -SevenZipPath $sevenZipPath
        if (-not $compressedArchive) { return }

        if (Move-ArchiveToDesktop -ArchivePath $compressedArchive) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.driverBackupCompletedSuccessfully')
            Write-StyledMessage -Type 'Info'    -Text (Get-SourceTextLoc 'toolText.finalArchive0' -Args @($script:FinalArchivePath))
            Write-StyledMessage -Type 'Info'    -Text (Get-SourceTextLoc 'toolText.canBeUsedToReinstallAllDriversWithoutRedownloadingThem')
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinBackupDriver" -Message (Get-SourceTextLoc 'toolText.extra.criticalErrorDuringBackup')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.checkTheLogsForTechnicalDetails')
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.temporaryEnvironmentCleaning')
        Remove-ItemSafely -Path $script:BackupConfig.BackupDir -Recurse
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.driverBackupToolkitFinished')
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.winbackupdriverSessionEnded')
    }
}
