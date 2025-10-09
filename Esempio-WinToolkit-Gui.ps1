<#
.EXAMPLE
    Esempio di utilizzo di WinToolkit-GUI

.DESCRIPTION
    Questo script mostra come avviare e utilizzare WinToolkit-GUI.
    Eseguilo per vedere la GUI in azione con tutte le sue funzionalità.
#>

# Imposta la directory di lavoro
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "🖥️  WinToolkit-GUI - Esempio di utilizzo" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 ISTRUZIONI:" -ForegroundColor Yellow
Write-Host "1. Verrà avviata l'interfaccia grafica di WinToolkit" -ForegroundColor White
Write-Host "2. Potrai selezionare uno o più script da eseguire" -ForegroundColor White
Write-Host "3. Usa la ricerca per trovare script specifici" -ForegroundColor White
Write-Host "4. Controlla i log in tempo reale" -ForegroundColor White
Write-Host "5. Usa pausa/riprendi/stop durante l'esecuzione" -ForegroundColor White
Write-Host ""

Write-Host "⚡ CARATTERISTICHE PRINCIPALI:" -ForegroundColor Yellow
Write-Host "• Interfaccia moderna con design scuro" -ForegroundColor White
Write-Host "• Tab organizzate per categorie di script" -ForegroundColor White
Write-Host "• Selezione multipla con checkbox" -ForegroundColor White
Write-Host "• Log in tempo reale con colori" -ForegroundColor White
Write-Host "• Progress bar per esecuzioni batch" -ForegroundColor White
Write-Host "• Controlli avanzati (pausa/stop/riprendi)" -ForegroundColor White
Write-Host "• Informazioni di sistema sempre visibili" -ForegroundColor White
Write-Host ""

Write-Host "🎯 CATEGORIE DISPONIBILI:" -ForegroundColor Yellow
Write-Host "• 🪄 Operazioni Preliminari" -ForegroundColor White
Write-Host "• 🔧 Windows & Office" -ForegroundColor White
Write-Host "• 🎮 Driver & Gaming" -ForegroundColor White
Write-Host "• 🕹️ Supporto" -ForegroundColor White
Write-Host ""

# Verifica se i file necessari esistono
$guiScript = Join-Path $scriptDir "WinToolkit-Gui.ps1"
$configScript = Join-Path $scriptDir "WinToolkit-Gui-Config.ps1"

if (-not (Test-Path $guiScript)) {
    Write-Error "❌ File WinToolkit-Gui.ps1 non trovato!"
    Write-Host "Assicurati di essere nella directory corretta." -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ File trovati:" -ForegroundColor Green
Write-Host "  • $guiScript" -ForegroundColor White
if (Test-Path $configScript) {
    Write-Host "  • $configScript" -ForegroundColor White
}
Write-Host ""

# Richiedi conferma per avviare la GUI
$confirmation = Read-Host "🚀 Vuoi avviare WinToolkit-GUI ora? (S/N)"
if ($confirmation -notmatch '^[Ss]') {
    Write-Host "Annullato dall'utente." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "🎉 Avvio WinToolkit-GUI..." -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

try {
    # Avvia la GUI
    & $guiScript
}
catch {
    Write-Error "❌ Errore nell'avvio della GUI: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "💡 SUGGERIMENTI:" -ForegroundColor Yellow
    Write-Host "• Assicurati di avere PowerShell 5.1 o superiore" -ForegroundColor White
    Write-Host "• Verifica di avere i privilegi amministrativi" -ForegroundColor White
    Write-Host "• Controlla che Windows Forms sia disponibile" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "✅ WinToolkit-GUI completato!" -ForegroundColor Green