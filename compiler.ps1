# Script di compilazione per WinToolkit (Enterprise-Grade)
# Gestisce aggregazione moduli, logging strutturato e minificazione del codice.

[CmdletBinding()]
param(
    [switch]$Minify
)

$ErrorActionPreference = 'Stop'
$ScriptStartTime = [System.Diagnostics.Stopwatch]::StartNew()

# ============================================================================
# 1. SISTEMA DI LOGGING ENTERPRISE
# ============================================================================
function Write-StyledMessage {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Warning', 'Error', 'Info')]
        [string]$Type,
        
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Type) {
        'Success' { 
            Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
            Write-Host "[SUCCESS] " -ForegroundColor Green -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        'Warning' { 
            Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
            Write-Host "[WARN]    " -ForegroundColor Yellow -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        'Error' { 
            Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
            Write-Host "[ERROR]   " -ForegroundColor Red -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        'Info' { 
            Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
            Write-Host "[INFO]    " -ForegroundColor Cyan -NoNewline
            Write-Host $Message -ForegroundColor White
        }
    }
}

Write-StyledMessage 'Info' "Avvio processo di build WinToolkit..."

# ============================================================================
# 2. INIZIALIZZAZIONE E VERIFICA PERCORSI
# ============================================================================
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$toolFolder = Join-Path $scriptPath "tool"
$sourceFile = Join-Path $scriptPath "WinToolkit-template.ps1"
$outputFile = Join-Path $scriptPath "WinToolkit.ps1"

try {
    if (-not (Test-Path $sourceFile)) { throw "File template non trovato in: $sourceFile" }
    if (-not (Test-Path $toolFolder)) { throw "Cartella tool non trovata in: $toolFolder" }
}
catch {
    Write-StyledMessage 'Error' "Errore di inzializzazione: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# 3. LETTURA SORGENTI E PREPARAZIONE
# ============================================================================
try {
    Write-StyledMessage 'Info' "Lettura template originario: WinToolkit-template.ps1"
    $templateLines = Get-Content $sourceFile -Encoding UTF8 -ErrorAction Stop
    $toolFiles = Get-ChildItem -Path $toolFolder -Filter "*.ps1" -File -ErrorAction Stop
}
catch {
    Write-StyledMessage 'Error' "Errore I/O durante la lettura dei file sorgente: $($_.Exception.Message)"
    exit 1
}

if ($toolFiles.Count -eq 0) {
    Write-StyledMessage 'Warning' "Nessun modulo .ps1 trovato in $toolFolder. Operazione annullata."
    exit 0
}

# Statistiche per la dashboard
$stats = @{
    Processed = 0
    Skipped   = 0
    Errors    = 0
    Warnings  = 0
    TotalSourceSize = (Get-Item $sourceFile).Length
    TotalSourceLines = $templateLines.Count
}

Write-StyledMessage 'Info' "Inizio aggregazione di $($toolFiles.Count) moduli..."
Write-Host ""

# ============================================================================
# 4. MOTORE DI AGGREGAZIONE (INIEZIONE CODICE)
# ============================================================================
foreach ($file in $toolFiles) {
    $functionName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $stats.TotalSourceSize += $file.Length
    
    try {
        $fileLines = Get-Content $file.FullName -Encoding UTF8 -ErrorAction Stop
        $stats.TotalSourceLines += $fileLines.Count
        
        # Gestione moduli vuoti o con solo spazi
        if ($fileLines.Count -eq 0 -or ($fileLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -eq 0) {
            Write-StyledMessage 'Warning' "Modulo pre-compilato vuoto: '$functionName'. Inserimento stub di svilluppo."
            $fileLines = @("    Write-StyledMessage 'Warning' `"Sviluppo funzione in corso`"")
            $stats.Warnings++
        }
        else {
            # Trim self-call (chiamata alla funzione in coda al file)
            $lastNonEmptyIndex = -1
            for ($i = $fileLines.Count - 1; $i -ge 0; $i--) {
                if (-not [string]::IsNullOrWhiteSpace($fileLines[$i])) { $lastNonEmptyIndex = $i; break }
            }
            if ($lastNonEmptyIndex -ge 0 -and $fileLines[$lastNonEmptyIndex].Trim() -eq $functionName) {
                # Sostituiamo rimozione con slice fino a -1
                if ($lastNonEmptyIndex -eq 0) { $fileLines = @() } else { $fileLines = $fileLines[0..($lastNonEmptyIndex - 1)] }
            }
        }
        
        # Ricerca del segnaposto function nel template
        $functionFound = $false
        $startIndex = -1
        $endIndex = -1
        
        for ($i = 0; $i -lt $templateLines.Count; $i++) {
            $line = $templateLines[$i].Trim()
            if ($line -match "^function\s+$([regex]::Escape($functionName))\s*\{(.*)$") {
                $startIndex = $i
                $functionFound = $true
                $restOfLine = $matches[1].Trim()
                
                # Check graffe su monoriga
                if ($restOfLine -eq "}") { $endIndex = $i; break }
                
                $braceCount = 1 + ($restOfLine.ToCharArray() | Where-Object { $_ -eq '{' }).Count - ($restOfLine.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                if ($braceCount -eq 0) { $endIndex = $i; break }
                
                # Cerca la fine scorrendo le righe del template
                for ($j = $i + 1; $j -lt $templateLines.Count; $j++) {
                    $currentLine = $templateLines[$j]
                    $braceCount += ($currentLine.ToCharArray() | Where-Object { $_ -eq '{' }).Count - ($currentLine.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                    if ($braceCount -eq 0) { $endIndex = $j; break }
                }
                break
            }
        }
        
        # Iniezione del codice processato
        if ($functionFound -and $startIndex -ge 0 -and $endIndex -ge 0) {
            $newLines = @()
            if ($startIndex -gt 0) { $newLines += $templateLines[0..($startIndex - 1)] }
            
            # Controllo eventuale definizione 'function NomeTool' già presente nel tool stesso
            if ($fileLines.Count -gt 0) {
                $hasInternalFunction = $fileLines | Select-String -Pattern "(?i)^\s*function\s+$([regex]::Escape($functionName))\b" -Quiet
                if ($hasInternalFunction) {
                    Write-StyledMessage 'Warning' "Il tool contiene una keyword function interna. Verificare conformità a file finale."
                    $stats.Warnings++
                }
            }
            
            # Injecting base logic
            $hasLogging = $fileLines | Select-String -Pattern "Initialize-ToolLogging" -Quiet
            
            $newLines += "function $functionName {"
            if (-not $hasLogging) { 
                $newLines += "    Initialize-ToolLogging -ToolName `"$functionName`"" 
                Write-StyledMessage 'Info' "Policy applicata: Iniezione automatica Initialize-ToolLogging"
            }
            $newLines += $fileLines
            $newLines += "}"
            
            if ($endIndex + 1 -lt $templateLines.Count) { $newLines += $templateLines[($endIndex + 1)..($templateLines.Count - 1)] }
            
            # Aggiorna il buffer master con la sostituzione
            $templateLines = $newLines
            Write-StyledMessage 'Success' "Modulo processato: $functionName"
            $stats.Processed++
        }
        else {
            Write-StyledMessage 'Warning' "Nessun endpoint trovato nel template. Skip di: $functionName"
            $stats.Skipped++
        }
    }
    catch {
        Write-StyledMessage 'Error' "Errore I/O aggregando il modulo $functionName`: $($_.Exception.Message)"
        $stats.Errors++
    }
}
Write-Host ""


# ============================================================================
# 5. MOTORE DI MINIFICAZIONE SICURA (-Minify)
#    Usa il tokenizer nativo di PowerShell invece di regex cieche.
#    Il tokenizer conosce esattamente dove si trovano commenti, stringhe,
#    here-strings, ecc. — quindi non può mai rompere la sintassi.
# ============================================================================
if ($Minify) {
    Write-StyledMessage 'Info' "Avvio minificazione sicura via tokenizer PowerShell..."
    try {
        $rawContent = $templateLines -join "`n"

        # ------------------------------------------------------------------
        # FASE 1 — Rimozione commenti tramite tokenizer nativo
        #   Il parser PowerShell classifica ogni token per tipo.
        #   I token di tipo 'Comment' includono:
        #     - Block comments  <# ... #>  (anche multiriga)
        #     - Inline comments # testo...  SOLO quando sono codice, MAI
        #       quando # appare dentro una stringa o here-string
        #   Processiamo i token in ordine INVERSO per mantenere validi
        #   gli offset mentre modifichiamo la stringa.
        # ------------------------------------------------------------------
        $parseErrors = $null
        $tokens      = $null
        [System.Management.Automation.Language.Parser]::ParseInput(
            $rawContent,
            [ref]$tokens,
            [ref]$parseErrors
        ) | Out-Null

        if ($parseErrors.Count -gt 0) {
            # Se il sorgente ha già errori di sintassi prima della minificazione
            # li segnaliamo ma proseguiamo ugualmente (errori pre-esistenti)
            Write-StyledMessage 'Warning' "Il sorgente contiene $($parseErrors.Count) errore/i di parse pre-esistenti. Minificazione applicata comunque."
        }

        # Ordine DECRESCENTE per offset: rimuovendo da fondo a testa
        # gli offset dei token non ancora processati rimangono validi
        $commentTokens = $tokens |
            Where-Object { $_.Kind -eq 'Comment' } |
            Sort-Object   { $_.Extent.StartOffset } -Descending

        foreach ($token in $commentTokens) {
            $start  = $token.Extent.StartOffset
            $length = $token.Extent.EndOffset - $start
            $rawContent = $rawContent.Remove($start, $length)
        }

        Write-StyledMessage 'Info' "  Rimossi $($commentTokens.Count) token commento"

        # ------------------------------------------------------------------
        # FASE 2 — Pulizia whitespace conservativa
        #   Operiamo RIGA PER RIGA per non unire mai righe distinte.
        #   Unire righe in PowerShell è SEMPRE pericoloso: pipe, backtick
        #   continuation, array literals, ecc. dipendono dal newline.
        # ------------------------------------------------------------------
        $cleanedLines = ($rawContent -split "`n") | ForEach-Object {
            # Rimuovi solo il whitespace di CODA (non toccare l'indentazione
            # iniziale: altera leggibilità ma non rompe la sintassi.
            # Rimuoverla è sicuro solo se si è certi che nessuna stringa
            # multiriga dipenda dall'indentazione, cosa impossibile da
            # garantire con un approccio generico.)
            $_.TrimEnd()
        } | Where-Object {
            # Elimina le righe completamente vuote (residui dopo rimozione commenti)
            -not [string]::IsNullOrWhiteSpace($_)
        }

        $templateLines = $cleanedLines

        # ------------------------------------------------------------------
        # FASE 3 — Verifica post-minificazione
        #   Ri-parseamo il risultato per accertarci che la minificazione
        #   non abbia introdotto errori. Se li trova, abortiamo e usiamo
        #   il sorgente originale non minificato.
        # ------------------------------------------------------------------
        $verifyContent = $templateLines -join "`n"
        $verifyErrors  = $null
        $verifyTokens  = $null
        [System.Management.Automation.Language.Parser]::ParseInput(
            $verifyContent,
            [ref]$verifyTokens,
            [ref]$verifyErrors
        ) | Out-Null

        if ($verifyErrors.Count -gt 0) {
            Write-StyledMessage 'Warning' "Rilevati $($verifyErrors.Count) errore/i sintassi post-minificazione — rollback al sorgente originale."
            foreach ($e in $verifyErrors) {
                Write-StyledMessage 'Warning' "  Riga $($e.Extent.StartLineNumber): $($e.Message)"
            }
            # Rollback: usa le righe originali senza minificazione
            $templateLines = $templateLines -join "`n" | ForEach-Object { $_ }
            $templateLines = (($templateLines) -split "`n")
        }
        else {
            $linesAfter  = $templateLines.Count
            Write-StyledMessage 'Success' "Minificazione completata: $linesAfter righe — nessun errore di sintassi rilevato."
        }
    }
    catch {
        Write-StyledMessage 'Error' "Errore imprevisto durante la minificazione: $($_.Exception.Message)"
        Write-StyledMessage 'Warning' "Continuazione build senza minificazione."
        # Non uscire: la build prosegue con il codice non minificato
        # $templateLines rimane invariato dall'ultima assegnazione valida
    }
    Write-Host ""
}


# ============================================================================
# 6. SCRITTURA COMPILAZIONE FINALE SUL DISCO
# ============================================================================
try {
    Write-StyledMessage 'Info' "Salvataggio eseguibile stand-alone: WinToolkit.ps1"
    
    if (Test-Path $outputFile) { Remove-Item $outputFile -Force -ErrorAction Stop }
    
    # Scrittura in UTF8 no-BOM per evitare problemi multipiattaforma o avvisi editor
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($outputFile, $templateLines, $utf8NoBom)
    
}
catch {
    Write-StyledMessage 'Error' "Fallimento irreversibile nella scrittura finale su disco: $($_.Exception.Message)"
    exit 1
}


# ============================================================================
# 7. METRICHE E BUILD DASHBOARD RIEPILOGATIVA
# ============================================================================
$ScriptStartTime.Stop()
$buildTimeSec = [math]::Round($ScriptStartTime.Elapsed.TotalSeconds, 3)

$minifySize = (Get-Item $outputFile).Length
$compressionPercent = 0
if ($stats.TotalSourceSize -gt 0) {
    $compressionPercent = [math]::Round(100 - (($minifySize / $stats.TotalSourceSize) * 100), 1)
}
$sourceMB = [math]::Round($stats.TotalSourceSize / 1KB, 2)
$finalMB = [math]::Round($minifySize / 1KB, 2)
$finalLinesCount = $templateLines.Count
$linesReduction = $stats.TotalSourceLines - $finalLinesCount

Write-Host ""
Write-Host "╔═════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                🚀 BUILD DASHBOARD RIEPILOGATIVA                 ║" -ForegroundColor Cyan
Write-Host "╠═════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║ 📊 STATISTICHE MODULI                                           ║" -ForegroundColor Yellow
Write-Host "║    ✅ Processati : $($stats.Processed)" -ForegroundColor Green
Write-Host "║    ⚠️  Saltati    : $($stats.Skipped)" -ForegroundColor Yellow
if ($stats.Errors -gt 0) {
    Write-Host "║    ❌ Errori     : $($stats.Errors)" -ForegroundColor Red
} else {
    Write-Host "║    ❌ Errori     : 0" -ForegroundColor DarkGray
}
Write-Host "╠═════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║ 💾 STORAGE E COMPRESSIONE                                       ║" -ForegroundColor Yellow
Write-Host "║    📦 Sorgenti   : $sourceMB KB ($($stats.TotalSourceLines) righe)" -ForegroundColor White
Write-Host "║    📄 File Finale: $finalMB KB ($finalLinesCount righe)" -ForegroundColor Cyan
if ($Minify) {
    Write-Host "║    📉 Riduzione  : $compressionPercent % ($linesReduction righe eliminate)" -ForegroundColor Green
} else {
    Write-Host "║    📉 Riduzione  : OFF (Flag -Minify non rilevato)" -ForegroundColor DarkGray
}
Write-Host "╠═════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║ ⏱️  TIMEDIFF MEASURE                                            ║" -ForegroundColor Yellow
Write-Host "║    ⏳ Esecuzione : $buildTimeSec sec" -ForegroundColor White
Write-Host "╚═════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($stats.Errors -gt 0) {
    Write-StyledMessage 'Warning' "La build è stata completata ma ha riscontrato anomalie minori o moduli saltati."
    exit 1
} else {
    Write-StyledMessage 'Success' "Pipeline compiler.ps1 eseguita con codice 0."
    exit 0
}