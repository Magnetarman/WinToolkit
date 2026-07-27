function WinExportLog {
    <#
    .SYNOPSIS
        Comprime i log di WinToolkit e li salva sul desktop per l'invio diagnostico.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "WinExportLog" -SubTitle "Esporta Log Diagnostici"

    $logSourcePath = $AppConfig.Paths.Logs
    $desktopPath   = $AppConfig.Paths.Desktop
    $timestamp     = Get-Date -Format "yyyyMMdd_HHmmss"
    $zipFileName   = "WinToolkit_Logs_$timestamp.zip"
    $zipFilePath   = Join-Path $desktopPath $zipFileName
    $tempFolder    = Join-Path $AppConfig.Paths.TempFolder "WinToolkit_Logs_Temp_$timestamp"

    try {
        Write-StyledMessage -Type 'Info' -Text "📂 Verifica presenza cartella log."

        if (-not (Test-Path $logSourcePath -PathType Container)) {
            Write-StyledMessage -Type 'Warning' -Text "La cartella dei log '$logSourcePath' non è stata trovata. Impossibile esportare."
            return
        }

        Write-StyledMessage -Type 'Info' -Text "🗜️ Compressione dei log in corso. Potrebbe essere ignorato qualche file in uso."

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
                    Write-Debug "File ignorato: $($_.Name) - $($_.Exception.Message)"
                }
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore durante la copia dei file: $($_.Exception.Message)."
        }

        if ($filesCopied -gt 0) {
            Compress-Archive -Path "$tempFolder\*" -DestinationPath $zipFilePath -Force -ErrorAction Stop

            if (Test-Path $zipFilePath) {
                Write-StyledMessage -Type 'Success' -Text "Log compressi con successo! File salvato: '$zipFileName' sul Desktop."
                if ($filesSkipped -gt 0) {
                    Write-StyledMessage -Type 'Info' -Text "⚠️ $filesSkipped file ignorati perché in uso o non accessibili."
                }
                Write-StyledMessage -Type 'Info' -Text "📩 Invia '$zipFileName' (Desktop) via Telegram [https://t.me/MagnetarMan] o email [me@magnetarman.com] per la diagnostica."
            }
            else {
                Write-StyledMessage -Type 'Error' -Text "Errore sconosciuto: il file ZIP non è stato creato."
            }
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Nessun file log copiato. Verifica i permessi e che i file esistano."
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinExportLog" -Message "Errore durante la compressione dei log"
    }
    finally {
        Remove-ItemSafely -Path $tempFolder -Recurse
        Write-ToolkitLog -Level INFO -Message "WinExportLog sessione terminata."
    }
}
