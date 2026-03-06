function Test-WingetDeepValidation {
    Write-StyledMessage -Type Info -Text "🔍 Esecuzione test profondo di Winget (ricerca pacchetti in rete)..."

    try {
        # Testa connettività ai repository, integrità del DB locale e parser Winget
        # Esegue ricerca diretta per ottenere ExitCode corretto
        $searchResult = & winget search "Git.Git" --accept-source-agreements 2>&1
        $exitCode = $LASTEXITCODE

        # Check for access violation crash (0xC0000005 = -1073741819 or 3221225781)
        if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
            Write-StyledMessage -Type Warning -Text "⚠️ Crash rilevato (ExitCode: $exitCode = ACCESS_VIOLATION). Tentativo ripristino avanzato..."
            
            # 1. Prova prima il ripristino DB + Reset Appx
            $null = Repair-WingetDatabase
            
            Write-StyledMessage -Type Info -Text "🔄 Ripetizione test dopo ripristino database..."
            Start-Sleep 3
            $searchResult = & winget search "Git.Git" --accept-source-agreements 2>&1
            $exitCode = $LASTEXITCODE

            # 2. Se crasha ancora, prova la reinstallazione completa
            if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                Write-StyledMessage -Type Warning -Text "⚠️ Crash persistente. Avvio reinstallazione completa Winget..."
                $null = Install-WingetPackage
                
                Write-StyledMessage -Type Info -Text "🔄 Test finale dopo reinstallazione..."
                Start-Sleep 3
                $searchResult = & winget search "Git.Git" --accept-source-agreements 2>&1
                $exitCode = $LASTEXITCODE
            }
        }

        if ($exitCode -eq 0) {
            Write-StyledMessage -Type Success -Text "✅ Test profondo superato: Winget comunica correttamente con i repository."
            return $true
        }
        else {
            # Logga i dettagli per debug
            $errorDetails = $searchResult | Out-String
            if ($errorDetails.Length -gt 200) { $errorDetails = $errorDetails.Substring(0, 200) + "..." }
            Write-StyledMessage -Type Warning -Text "⚠️ Test profondo fallito: ExitCode=$exitCode. Dettagli: $errorDetails"
            return $false
        }
    }
    catch {
        Write-StyledMessage -Type Error -Text "❌ Errore durante il test profondo di Winget: $($_.Exception.Message)"
        return $false
    }
}
