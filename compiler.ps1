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
$sourceFile = Join-Path $scriptPath "WinToolkit-template.ps1"
$outputFile = Join-Path $scriptPath "WinToolkit.ps1"

Write-StyledMessage 'Info' "Avvio processo di compilazione WinToolkit"
Write-Host ""

# Verifica esistenza file e cartelle
if (-not (Test-Path $sourceFile)) {
    Write-StyledMessage 'Error' "File WinToolkit-template.ps1 non trovato in: $sourceFile"
    exit 1
}

if (-not (Test-Path $toolFolder)) {
    Write-StyledMessage 'Error' "Cartella tool non trovata in: $toolFolder"
    exit 1
}

# Carica il contenuto del file modello come array di righe
Write-StyledMessage 'Info' "Caricamento file modello: WinToolkit.ps1"
try {
    $templateLines = Get-Content $sourceFile -Encoding UTF8 -ErrorAction Stop
}
catch {
    Write-StyledMessage 'Error' "Errore durante la lettura di WinToolkit-template.ps1: $($_.Exception.Message)"
    exit 1
}

# Trova tutti i file .ps1 nella cartella tool
$toolFiles = Get-ChildItem -Path $toolFolder -Filter "*.ps1" -File

if ($toolFiles.Count -eq 0) {
    Write-StyledMessage 'Warning' "Nessun file .ps1 trovato nella cartella tool"
    exit 0
}

Write-StyledMessage 'Info' "Trovati $($toolFiles.Count) file da processare"
Write-Host ""

# Contatori per statistiche
$processedCount = 0
$skippedCount = 0
$warningCount = 0
$errorCount = 0

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
                "    Write-StyledMessage 'Warning' `"Sviluppo funzione in corso`""
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
            
            # Pattern preciso per trovare solo la dichiarazione della funzione (non chiamate o altro)
            if ($line -match "^function\s+$([regex]::Escape($functionName))\s*\{(.*)$") {
                $startIndex = $i
                $functionFound = $true
                
                # Verifica se è una funzione su una singola riga
                $restOfLine = $matches[1].Trim()
                if ($restOfLine -eq "}") {
                    # Funzione vuota su una riga: function Nome { }
                    $endIndex = $i
                    Write-StyledMessage 'Info' "Trovata funzione vuota su singola riga"
                    break
                }
                
                # Trova la fine della funzione contando le parentesi graffe
                $braceCount = 1  # Iniziamo con 1 perché abbiamo già trovato la graffa di apertura
                
                # Conta le graffe rimanenti nella riga corrente dopo 'function Nome {'
                $remainingBraces = ($restOfLine.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                $closingBraces = ($restOfLine.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                $braceCount += $remainingBraces - $closingBraces
                
                if ($braceCount -eq 0) {
                    # La funzione si chiude sulla stessa riga
                    $endIndex = $i
                    break
                }
                
                # Continua a cercare la graffa di chiusura nelle righe successive
                for ($j = $i + 1; $j -lt $templateLines.Count; $j++) {
                    $currentLine = $templateLines[$j]
                    
                    # Conta le parentesi graffe
                    $openBraces = ($currentLine.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                    $closeBraces = ($currentLine.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                    
                    $braceCount += $openBraces - $closeBraces
                    
                    # Se il conteggio è tornato a 0, abbiamo trovato la fine
                    if ($braceCount -eq 0) {
                        $endIndex = $j
                        break
                    }
                    
                    # Sicurezza: se il conteggio va sotto zero, qualcosa è andato storto
                    if ($braceCount -lt 0) {
                        Write-StyledMessage 'Warning' "Errore nel conteggio delle parentesi graffe per la funzione '$functionName'"
                        $functionFound = $false
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
            if ($startIndex -gt 0) {
                $newLines += $templateLines[0..($startIndex - 1)]
            }
            
            # Aggiungi la nuova definizione della funzione (sostituisce completamente quella esistente)
            # Aggiungi la nuova definizione della funzione (sostituisce completamente quella esistente)
            # Se il file tool include già la dichiarazione 'function <name> { ... }', la rileviamo anche se ci sono righe vuote/commenti iniziali
            if ($fileLines.Count -gt 0) {
                # Trova il primo indice con contenuto significativo
                $firstNonEmpty = -1
                for ($i = 0; $i -lt $fileLines.Count; $i++) {
                    if (-not [string]::IsNullOrWhiteSpace($fileLines[$i])) { $firstNonEmpty = $i; break }
                }
                if ($firstNonEmpty -ge 0) {
                    $firstLine = $fileLines[$firstNonEmpty].Trim()
                    if ($firstLine -match ("(?i)^function\s+" + [regex]::Escape($functionName) + "\s*\{")) {
                        # Rimuovi la riga della dichiarazione (prima non vuota)
                        if ($firstNonEmpty -eq 0) {
                            if ($fileLines.Count -gt 1) { $fileLines = $fileLines[1..($fileLines.Count - 1)] } else { $fileLines = @() }
                        }
                        else {
                            # Rimuovi l'elemento all'indice $firstNonEmpty
                            $fileLines = $fileLines[0..($firstNonEmpty - 1)] + $fileLines[($firstNonEmpty + 1)..($fileLines.Count - 1)]
                        }
                        # Rimuovi eventuale parentesi di chiusura alla fine (ultima riga non vuota)
                        $lastNonEmpty = -1
                        for ($j = $fileLines.Count - 1; $j -ge 0; $j--) {
                            if (-not [string]::IsNullOrWhiteSpace($fileLines[$j])) { $lastNonEmpty = $j; break }
                        }
                        if ($lastNonEmpty -ge 0 -and $fileLines[$lastNonEmpty].Trim() -eq "}") {
                            if ($lastNonEmpty -eq ($fileLines.Count - 1)) {
                                if ($fileLines.Count -gt 1) { $fileLines = $fileLines[0..($fileLines.Count - 2)] } else { $fileLines = @() }
                            }
                            else {
                                $fileLines = $fileLines[0..($lastNonEmpty - 1)] + $fileLines[($lastNonEmpty + 1)..($fileLines.Count - 1)]
                            }
                        }
                    }
                }
            }

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
            Write-StyledMessage 'Warning' "La funzione '$functionName' non è stata trovata in WinToolkit-template.ps1 e verrà saltata"
            $skippedCount++
        }
        
    }
    catch {
        Write-StyledMessage 'Error' "Errore durante il processamento di '$($file.Name)': $($_.Exception.Message)"
        $errorCount++
    }
    
    Write-Host ""
}

# Mostra riepilogo finale
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                 📊 RIEPILOGO COMPILAZIONE               ║" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor White

if ($processedCount -gt 0) {
    Write-Host "║  ✅ Processati: $processedCount funzioni" -ForegroundColor Green
}
else {
    Write-Host "║  ❌ Processati: $processedCount funzioni" -ForegroundColor Red
}

if ($skippedCount -gt 0) {
    Write-Host "║  ⚠️  Saltati: $skippedCount funzioni (non presenti nel template)" -ForegroundColor Yellow
}
else {
    Write-Host "║  ✅ Saltati: $skippedCount funzioni" -ForegroundColor Green
}

if ($warningCount -gt 0) {
    Write-Host "║  ⚠️  Avvisi: $warningCount file vuoti" -ForegroundColor Yellow
}
else {
    Write-Host "║  ✅ Avvisi: $warningCount file vuoti" -ForegroundColor Green
}

if ($errorCount -gt 0) {
    Write-Host "║  ❌ Errori: $errorCount durante l'elaborazione" -ForegroundColor Red
}
else {
    Write-Host "║  ✅ Errori: $errorCount durante l'elaborazione" -ForegroundColor Green
}

Write-Host "║                                                          ║" -ForegroundColor White
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Salva il file compilato
Write-StyledMessage 'Info' "Salvataggio file compilato: WinToolkit.ps1"
try {
    # Rimuovi il file di output esistente se presente
    if (Test-Path $outputFile) {
        Remove-Item $outputFile -Force
    }

    # Salva il contenuto compilato
    $templateLines | Out-File -FilePath $outputFile -Encoding UTF8

    Write-StyledMessage 'Success' "File WinToolkit.ps1 creato con successo!"

    # Esci con codice di errore solo se ci sono stati errori reali, non per funzioni saltate
    if ($errorCount -gt 0) {
        Write-StyledMessage 'Error' "Compilazione completata con errori"
        exit 1
    }
    else {
        Write-StyledMessage 'Success' "Compilazione completata con successo"
        exit 0
    }

}
catch {
    Write-StyledMessage 'Error' "Errore durante il salvataggio: $($_.Exception.Message)"
    exit 1
}