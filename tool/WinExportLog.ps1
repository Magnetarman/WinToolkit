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

        # Metodo alternativo per gestire file in uso
        $tempFolder = Join-Path $env:TEMP "WinToolkit_Logs_Temp_$timestamp"
        
        # Crea cartella temporanea
        if (Test-Path $tempFolder) {
            Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null

        # Copia i file con gestione degli errori
        $filesCopied = 0
        $filesSkipped = 0
        
        try {
            Get-ChildItem -Path $logSourcePath -File | ForEach-Object {
                try {
                    Copy-Item $_.FullName -Destination $tempFolder -Force -ErrorAction Stop
                    $filesCopied++
                }
                catch {
                    # File in uso o altri errori - salta silenziosamente
                    $filesSkipped++
                    Write-Debug "File ignorato: $($_.Name) - $($_.Exception.Message)"
                }
            }
        }
        catch {
            Write-StyledMessage Warning "Errore durante la copia dei file: $($_.Exception.Message)"
        }

        # Comprime la cartella temporanea
        if ($filesCopied -gt 0) {
            Compress-Archive -Path "$tempFolder\*" -DestinationPath $zipFilePath -Force -ErrorAction Stop
            
            if (Test-Path $zipFilePath) {
                Write-StyledMessage Success "Log compressi con successo! File salvato: '$zipFileName' sul Desktop."
                
                if ($filesSkipped -gt 0) {
                    Write-StyledMessage Info "⚠️ Attenzione: $filesSkipped file sono stati ignorati perché in uso o non accessibili."
                }
                
                # Messaggi per l'utente
                Write-StyledMessage Info "📩 Per favore, invia il file ZIP '$zipFileName' (lo trovi sul tuo Desktop) via Telegram [https://t.me/MagnetarMan] o email [me@magnetarman.com] per aiutarmi nella diagnostica."
            }
            else {
                Write-StyledMessage Error "Errore sconosciuto: il file ZIP non è stato creato."
            }
        }
        else {
            Write-StyledMessage Error "Nessun file log è stato copiato. Verifica i permessi e che i file esistano."
        }

        # Pulizia cartella temporanea
        if (Test-Path $tempFolder) {
            Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-StyledMessage Error "Errore critico durante la compressione dei log: $($_.Exception.Message)"
        
        # Pulizia forzata in caso di errore
        $tempFolder = Join-Path $env:TEMP "WinToolkit_Logs_Temp_$timestamp"
        if (Test-Path $tempFolder) {
            Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
