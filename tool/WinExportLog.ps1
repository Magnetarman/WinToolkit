function WinExportLog {
    <#
    .SYNOPSIS
        Comprime i log di WinToolkit e li salva sul desktop per la diagnostica.
    #>
    param([int]$CountdownSeconds = 30)

    Initialize-ToolLogging -ToolName "WinExportLog"
    Show-Header -SubTitle "Esporta Log Diagnostici"

    # Definizione dei percorsi
    $logSourcePath = Join-Path $env:LOCALAPPDATA "WinToolkit\logs"
    $desktopPath = [System.Environment]::GetFolderPath("Desktop")
    $timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")
    $zipFileName = "WinToolkit_Logs_$timestamp.zip"
    $zipFilePath = Join-Path $desktopPath $zipFileName

    try {
        Write-StyledMessage Info "📂 Verifica presenza cartella log..."

        if (-not (Test-Path $logSourcePath -PathType Container)) {
            Write-StyledMessage Warning "La cartella dei log '$logSourcePath' non è stata trovata. Impossibile esportare."
            return
        }

        Write-StyledMessage Info "🗜️ Compressione dei log in corso. Potrebbe essere ignorato qualche file in uso..."

        # Compressione con gestione file in uso
        Compress-Archive -Path "$logSourcePath\*" -DestinationPath $zipFilePath -Force -ErrorAction SilentlyContinue

        if (Test-Path $zipFilePath) {
            Write-StyledMessage Success "✅ Log compressi con successo! File salvato: '$zipFileName' sul Desktop."

            # Messaggi per l'utente
            Write-StyledMessage Info "📩 Per favore, invia il file ZIP '$zipFileName' (lo trovi sul tuo Desktop) via Telegram [https://t.me/MagnetarMan] o email [me@magnetarman.com] per aiutarmi nella diagnostica."
        }
        else {
            Write-StyledMessage Error "❌ Errore sconosciuto: il file ZIP non è stato creato."
        }
    }
    catch {
        Write-StyledMessage Error "❌ Errore critico durante la compressione dei log: $($_.Exception.Message)"
    }
}
