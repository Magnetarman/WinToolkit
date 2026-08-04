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

    Start-ToolkitSession -ToolName "WinExportLog" -SubTitle (Get-SourceTextLoc 'script.WinExportLog')

    $logSourcePath = $AppConfig.Paths.Logs
    $desktopPath   = $AppConfig.Paths.Desktop
    $timestamp     = Get-Date -Format "yyyyMMdd_HHmmss"
    $zipFileName   = "WinToolkit_Logs_$timestamp.zip"
    $zipFilePath   = Join-Path $desktopPath $zipFileName
    $tempFolder    = Join-Path $AppConfig.Paths.TempFolder "WinToolkit_Logs_Temp_$timestamp"

    try {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.checkPresenceOfLogFolder')

        if (-not (Test-Path $logSourcePath -PathType Container)) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.theLogsFolder0WasNotFoundUnableToExport' -Args @($logSourcePath))
            return
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.compressingLogsSomeFilesInUseMayBeIgnored')

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
            Write-Debug (Get-SourceTextLoc 'uiText.fileIgnored01' -Args @($_.Name, $_.Exception.Message))
                }
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorCopyingFiles0' -Args @($($_.Exception.Message)))
        }

        if ($filesCopied -gt 0) {
            Compress-Archive -Path "$tempFolder\*" -DestinationPath $zipFilePath -Force -ErrorAction Stop

            if (Test-Path $zipFilePath) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.logsCompressedSuccessfullySavedFile0OnDesktop' -Args @($zipFileName))
                if ($filesSkipped -gt 0) {
                    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0FilesIgnoredBecauseTheyAreInUseOrNotAccessible' -Args @($filesSkipped))
                }
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.send0DesktopViaTelegramHttpsTMeMagnetarmanOrEmailMeMagnetarmanComForDiagnostics' -Args @($zipFileName))
            }
            else {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unknownErrorZipFileWasNotCreated')
            }
        }
        else {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.noLogFilesCopiedCheckPermissionsAndThatTheFilesExist')
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinExportLog" -Message (Get-SourceTextLoc 'toolText.extra.errorCompressingLogs')
    }
    finally {
        Remove-ItemSafely -Path $tempFolder -Recurse
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.winexportlogSessionEnded')
    }
}
