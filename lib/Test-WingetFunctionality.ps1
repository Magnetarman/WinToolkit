function Test-WingetFunctionality {
    Write-StyledMessage -Type Info -Text "🔍 Verifica funzionalità Winget..."

    # Aggiorna il PATH per rilevare installazioni recenti
    Update-EnvironmentPath

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Warning -Text "Winget non trovato nel PATH."
        return $false
    }

    try {
        # Usa --version: locale, immediato, non richiede connessione internet
        $versionOutput = (& winget --version 2>$null) | Out-String
        if ($LASTEXITCODE -eq 0 -and $versionOutput -match 'v\d+\.\d+') {
            Write-StyledMessage -Type Success -Text "✅ Winget operativo (versione: $($versionOutput.Trim()))."
            return $true
        }
        else {
            Write-StyledMessage -Type Warning -Text "Winget presente ma non risponde correttamente (ExitCode: $LASTEXITCODE)."
            return $false
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Errore durante test Winget: $($_.Exception.Message)"
        return $false
    }
}
