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

# Carica il contenuto del file modello come array di righe
Write-StyledMessage 'Info' "Caricamento file modello: WinToolkit.ps1"
try {
    $templateLines = Get-Content $sourceFile -Encoding UTF8 -ErrorAction Stop
}
catch {
    Write-StyledMessage 'Error' "Errore durante la lettura di WinToolkit.ps1: $($_.Exception.Message)"
    Write-Host "`nPremi un tasto per uscire..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

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
        # Leggi il contenuto del file come array di righe
        $fileLines = Get-Content $file.FullName -Encoding UTF8 -ErrorAction Stop
        
        # Gestione file vuoto
        if ($fileLines.Count -eq 0 -or ($fileLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -eq 0) {
            Write-StyledMessage 'Warning' "File '$($file.Name)' è vuoto - inserimento codice di sviluppo"
            $fileLines = @(
                "    Write-StyledMessage 'Warning' `"Sviluppo funzione in corso`"",
                "    Write-Host `"`nPremi un tasto per tornare al menu principale...`"",
                "    `$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')"
            )
            $warningCount++
        }
        else {
            # Rimuovi l'ultima riga se è una chiamata alla funzione
            $lastNonEmptyIndex = -1
            for ($i = $fileLines.Count - 1; $i -ge 0; $i--) {
                if (-not [string]::IsNullOrWhiteSpace($fileLines[$i])) {
                    $lastNonEmptyIndex = $i
                    break
                }
            }
            
            # Se l'ultima riga non vuota è la chiamata alla funzione, rimuovila
            if ($lastNonEmptyIndex -ge 0 -and $fileLines[$lastNonEmptyIndex].Trim() -eq $functionName) {
                Write-StyledMessage 'Info' "Rimossa chiamata automatica alla funzione dall'ultima riga"
                $fileLines = $fileLines[0..($lastNonEmptyIndex - 1)]
            }
        }
        
        # Cerca la funzione nel template
        $functionFound = $false
        $startIndex = -1
        $endIndex = -1
        
        # Cerca la definizione della funzione
        for ($i = 0; $i -lt $templateLines.Count; $i++) {
            $line = $templateLines[$i].Trim()
            
            # Pattern più flessibile per trovare la funzione
            if ($line -match "^function\s+$([regex]::Escape($functionName))\s*\{") {
                $startIndex = $i
                $functionFound = $true
                
                # Trova la fine della funzione (riga con solo "}")
                $braceCount = 0
                $foundOpenBrace = $false
                
                for ($j = $i; $j -lt $templateLines.Count; $j++) {
                    $currentLine = $templateLines[$j]
                    
                    # Conta le parentesi graffe
                    $openBraces = ($currentLine.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                    $closeBraces = ($currentLine.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                    
                    if ($openBraces -gt 0) { $foundOpenBrace = $true }
                    $braceCount += $openBraces - $closeBraces
                    
                    # Se abbiamo trovato la graffa di apertura e il conteggio è tornato a 0, abbiamo trovato la fine
                    if ($foundOpenBrace -and $braceCount -eq 0) {
                        $endIndex = $j
                        break
                    }
                }
                break
            }
        }
        
        if ($functionFound -and $startIndex -ge 0 -and $endIndex -ge 0) {
            # Costruisci il nuovo contenuto
            $newLines = @()
            
            # Aggiungi tutto prima della funzione
            $newLines += $templateLines[0..($startIndex - 1)]
            
            # Aggiungi la nuova definizione della funzione
            $newLines += "function $functionName {"
            $newLines += $fileLines
            $newLines += "}"
            
            # Aggiungi tutto dopo la funzione
            if ($endIndex + 1 -lt $templateLines.Count) {
                $newLines += $templateLines[($endIndex + 1)..($templateLines.Count - 1)]
            }
            
            # Aggiorna il template per le prossime iterazioni
            $templateLines = $newLines
            
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
    $templateLines | Out-File -FilePath $outputFile -Encoding UTF8
    
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