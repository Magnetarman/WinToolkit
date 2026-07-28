function WinExportLog {
    <#
    .SYNOPSIS
        Compresses WinToolkit logs and saves them to the Desktop for diagnostic submission.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "WinExportLog" -SubTitle (Get-Loc 'script.WinExportLog')

    $logSourcePath = $AppConfig.Paths.Logs
    $desktopPath   = $AppConfig.Paths.Desktop
    $timestamp     = Get-Date -Format "yyyyMMdd_HHmmss"
    $zipFileName   = "WinToolkit_Logs_$timestamp.zip"
    $zipFilePath   = Join-Path $desktopPath $zipFileName
    $tempFolder    = Join-Path $AppConfig.Paths.TempFolder "WinToolkit_Logs_Temp_$timestamp"

    try {
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.checkPresenceOfLogFolder')

        if (-not (Test-Path $logSourcePath -PathType Container)) {
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.theLogsFolder0WasNotFoundUnableToExport' -Args @($logSourcePath))
            return
        }

        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.compressingLogsSomeFilesInUseMayBeIgnored')

        Remove-ItemSafely -Path $tempFolder -Recurse
        New-Item -ItemType Directory -Path $tempFolder -Force *>$null

        $filesCopied  = 0
        $filesSkipped = 0

        try {
            Get-ChildItem -Path $logSourcePath -File | ForEach-Object {
                try {
                    Copy-Item $_.FullName -Destination $tempFolder -Force -ErrorAction Stop
                    $filesCopied++
                }
                catch {
                    $filesSkipped++
            Write-Debug (Get-Loc 'uiText.fileIgnored01' -Args @($_.Name, $_.Exception.Message))
                }
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.errorCopyingFiles0' -Args @($($_.Exception.Message)))
        }

        if ($filesCopied -gt 0) {
            Compress-Archive -Path "$tempFolder\*" -DestinationPath $zipFilePath -Force -ErrorAction Stop

            if (Test-Path $zipFilePath) {
                Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.logsCompressedSuccessfullySavedFile0OnDesktop' -Args @($zipFileName))
                if ($filesSkipped -gt 0) {
                    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.0FilesIgnoredBecauseTheyAreInUseOrNotAccessible' -Args @($filesSkipped))
                }
                Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.send0DesktopViaTelegramHttpsTMeMagnetarmanOrEmailMeMagnetarmanComForDiagnostics' -Args @($zipFileName))
            }
            else {
                Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.unknownErrorZipFileWasNotCreated')
            }
        }
        else {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.noLogFilesCopiedCheckPermissionsAndThatTheFilesExist')
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinExportLog" -Message (Get-Loc 'toolText.extra.errorCompressingLogs')
    }
    finally {
        Remove-ItemSafely -Path $tempFolder -Recurse
        Write-ToolkitLog -Level INFO -Message (Get-Loc 'toolText.winexportlogSessionEnded')
    }
}
