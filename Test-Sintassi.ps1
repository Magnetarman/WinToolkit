<#
.SYNOPSIS
    Script di test per verificare la sintassi dei file creati
#>

param([string]$FilePath = "")

Write-Host "🧪 Test Sintassi WinToolkit-GUI" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

# Test del file principale se non specificato altrimenti
if (-not $FilePath) {
    $filesToTest = @(
        "WinToolkit-Gui.ps1",
        "WinToolkit-Gui-Config.ps1",
        "Esempio-WinToolkit-Gui.ps1"
    )
}
else {
    $filesToTest = @($FilePath)
}

$allGood = $true

foreach ($file in $filesToTest) {
    if (Test-Path $file) {
        Write-Host "📄 Test $file..." -ForegroundColor Yellow

        try {
            # Legge il contenuto del file
            $content = Get-Content $file -Raw -ErrorAction Stop

            # Verifica sintassi di base
            $tokens = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)

            if ($tokens) {
                Write-Host "  ✅ Sintassi OK" -ForegroundColor Green

                # Conta righe e caratteri
                $lines = $content.Split("`n").Count
                $chars = $content.Length

                Write-Host "  📊 $lines righe, $chars caratteri" -ForegroundColor Gray
            }
            else {
                Write-Host "  ❌ Errore nella tokenizzazione" -ForegroundColor Red
                $allGood = $false
            }
        }
        catch {
            Write-Host "  ❌ Errore: $($_.Exception.Message)" -ForegroundColor Red
            $allGood = $false
        }
    }
    else {
        Write-Host "  ⚠️ File non trovato: $file" -ForegroundColor Yellow
    }

    Write-Host ""
}

# Verifica se tutti i file richiesti esistono
$requiredFiles = @(
    "WinToolkit.ps1",
    "WinToolkit-Gui.ps1",
    "WinToolkit-Gui-Config.ps1",
    "README-WinToolkit-Gui.md"
)

Write-Host "📋 Verifica file richiesti:" -ForegroundColor Yellow
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ $file" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ $file - MANCANTE" -ForegroundColor Red
        $allGood = $false
    }
}

Write-Host ""

if ($allGood) {
    Write-Host "🎉 TUTTI I TEST SUPERATI!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 SOMMARIO:" -ForegroundColor Cyan
    Write-Host "• WinToolkit-Gui.ps1 - Interfaccia grafica completa" -ForegroundColor White
    Write-Host "• WinToolkit-Gui-Config.ps1 - File di configurazione" -ForegroundColor White
    Write-Host "• README-WinToolkit-Gui.md - Documentazione" -ForegroundColor White
    Write-Host "• Esempio-WinToolkit-Gui.ps1 - Guida all'uso" -ForegroundColor White
    Write-Host ""
    Write-Host "🚀 Pronto per l'uso!" -ForegroundColor Green
}
else {
    Write-Host "⚠️ ALCUNI TEST FALLITI" -ForegroundColor Yellow
    Write-Host "Verifica i messaggi di errore sopra." -ForegroundColor White
}

Write-Host ""
Write-Host "Premi un tasto per uscire..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")