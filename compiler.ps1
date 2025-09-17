# Script di compilazione per WinToolkit
# Questo script legge i file .ps1 dalla cartella tool e li inietta nelle funzioni vuote di WinToolkit.ps1

param()

# Configurazione colori per i messaggi
function Write-StyledMessage {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Warning', 'Error', 'Info')]
        [string]$Type,
        
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    switch ($Type) {
        'Success' { Write-Host "✅ $Message" -ForegroundColor Green }
        'Warning' { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
        'Error' { Write-Host "❌ $Message" -ForegroundColor Red }
        'Info' { Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
    }
}

# Definizione dei percorsi (dinamici, relativi alla posizione dello script)
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$toolFolder = Join-Path $scriptPath "tool"
$sourceFile = Join-Path $scriptPath "WinToolkit.ps1"
$outputFile = Join-Path $scriptPath "WinToolkit_compiled.ps1"

Write-StyledMessage 'Info' "Avvio processo di compilazione WinToolkit"
Write-Host ""

# Verifica esistenza file e cartelle
if (-not (Test-Path $sourceFile)) {
    Write-StyledMessage 'Error' "File WinToolkit.ps1 non trovato in: $sourceFile"
    Write-Host "`nPremi un tasto per uscire..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

if (-not (Test-Path $toolFolder)) {
    Write-StyledMessage 'Error' "Cartella tool non trovata in: $toolFolder"
    Write-Host "`nPremi un tasto per uscire..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

# Carica il contenuto del file modello
Write-StyledMessage 'Info' "Caricamento file modello: WinToolkit.ps1"
try {
    $templateContent = Get-Content $sourceFile -Raw -Encoding UTF8
}
catch {
    Write-StyledMessage 'Error' "Errore durante la lettura di WinToolkit.ps1: $($_.Exception.Message)"
    Write-Host "`nPremi un tasto per uscire..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

# Copia il contenuto del template per la compilazione
$compiledContent = $templateContent

# Trova tutti i file .ps1 nella cartella tool
$toolFiles = Get-ChildItem -Path $toolFolder -Filter "*.ps1" -File

if ($toolFiles.Count -eq 0) {
    Write-StyledMessage 'Warning' "Nessun file .ps1 trovato nella cartella tool"
    Write-Host "`nPremi un tasto per uscire..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 0
}

Write-StyledMessage 'Info' "Trovati $($toolFiles.Count) file da processare"
Write-Host ""

# Contatori per statistiche
$processedCount = 0
$skippedCount = 0
$warningCount = 0

# Ciclo principale: processa ogni file .ps1
foreach ($file in $toolFiles) {
    $functionName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    Write-Host "Processando: $($file.Name) → funzione '$functionName'" -ForegroundColor White
    
    try {
        # Leggi il contenuto del file
        $fileContent = Get-Content $file.FullName -Raw -Encoding UTF8
        
        # Gestione file vuoto
        if ([string]::IsNullOrWhiteSpace($fileContent)) {
            Write-StyledMessage 'Warning' "File '$($file.Name)' è vuoto - inserimento codice di sviluppo"
            $fileContent = @"
Write-StyledMessage 'Warning' "Sviluppo funzione in corso"
Write-Host "`nPremi un tasto per tornare al menu principale..."
`$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
"@
            $warningCount++
        }
        else {
            # Rimuovi l'ultima riga se è una chiamata alla funzione
            $lines = $fileContent -split "`r?`n"
            $lastLineIndex = -1
            
            # Trova l'ultima riga non vuota
            for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                if (-not [string]::IsNullOrWhiteSpace($lines[$i])) {
                    $lastLineIndex = $i
                    break
                }
            }
            
            # Se l'ultima riga non vuota è la chiamata alla funzione, rimuovila
            if ($lastLineIndex -ge 0 -and $lines[$lastLineIndex].Trim() -eq $functionName) {
                Write-StyledMessage 'Info' "Rimossa chiamata automatica alla funzione dall'ultima riga"
                $lines = $lines[0..($lastLineIndex - 1)]
                $fileContent = $lines -join "`r`n"
            }
        }
        
        # Cerca la funzione corrispondente nel template
        # Pattern per trovare la funzione vuota: function NomeFunzione { } o function NomeFunzione {}
        $functionPattern = "function\s+$([regex]::Escape($functionName))\s*\{\s*\}"
        
        if ($compiledContent -match $functionPattern) {
            # Sostituisci la funzione vuota con quella completa
            $newFunctionDefinition = "function $functionName {`r`n$fileContent`r`n}"
            $compiledContent = $compiledContent -replace $functionPattern, $newFunctionDefinition
            
            Write-StyledMessage 'Success' "Compilazione di '$functionName' completata"
            $processedCount++
        }
        else {
            # Funzione non trovata - mostra avviso
            Write-StyledMessage 'Warning' "La funzione '$functionName' non è stata trovata in WinToolkit.ps1 e verrà saltata"
            Write-Host "Premi un tasto per continuare..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            $skippedCount++
        }
        
    }
    catch {
        Write-StyledMessage 'Error' "Errore durante il processamento di '$($file.Name)': $($_.Exception.Message)"
        $skippedCount++
    }
    
    Write-Host ""
}

# Salva il file compilato
Write-StyledMessage 'Info' "Salvataggio file compilato: WinToolkit_compiled.ps1"
try {
    # Rimuovi il file di output esistente se presente
    if (Test-Path $outputFile) {
        Remove-Item $outputFile -Force
    }
    
    # Salva il contenuto compilato
    $compiledContent | Out-File -FilePath $outputFile -Encoding UTF8 -NoNewline
    
    Write-StyledMessage 'Success' "File WinToolkit_compiled.ps1 creato con successo!"
    
}
catch {
    Write-StyledMessage 'Error' "Errore durante il salvataggio: $($_.Exception.Message)"
    Write-Host "`nPremi un tasto per uscire..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

# Statistiche finali
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-StyledMessage 'Info' "COMPILAZIONE COMPLETATA"
Write-Host "📊 Statistiche:" -ForegroundColor Cyan
Write-Host "   • File processati con successo: $processedCount" -ForegroundColor Green
Write-Host "   • File saltati: $skippedCount" -ForegroundColor Yellow
Write-Host "   • Avvisi: $warningCount" -ForegroundColor Yellow
Write-Host "   • File di output: WinToolkit_compiled.ps1" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

Write-Host "`nPremi un tasto per uscire..." -ForegroundColor White
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')