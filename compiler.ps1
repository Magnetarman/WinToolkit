# Script di compilazione per WinToolkit (Enterprise-Grade)
# Gestisce aggregazione moduli, logging strutturato e minificazione del codice.

[CmdletBinding()]
param(
    [switch]$Minify,
    [string]$Language = 'en-US'
)

$ErrorActionPreference = 'Stop'
$ScriptStartTime = [System.Diagnostics.Stopwatch]::StartNew()

# ============================================================================
# 1. SISTEMA DI LOGGING ENTERPRISE
# ============================================================================
$script:SourceTextLanguageData = $null
$script:SourceTextDefaultLanguageData = $null

function Get-SourceTextLanguageDirectory {
    $candidates = @(
        (Join-Path $PSScriptRoot 'languages'),
        (Join-Path (Split-Path $PSScriptRoot -Parent) 'languages'),
        (Join-Path (Get-Location) 'languages')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $candidates[0]
}

function Import-SourceTextLanguageFile {
    param([string]$LanguageCode)

    $languageDirectory = Get-SourceTextLanguageDirectory
    if (-not (Test-Path $languageDirectory)) { return $null }
    try {
        $localizedData = $null
        Import-LocalizedData -BindingVariable localizedData -BaseDirectory $languageDirectory -FileName 'WinToolkit.psd1' -UICulture $LanguageCode -ErrorAction Stop
        return $localizedData
    }
    catch {
        return $null
    }
}

function Initialize-SourceTextLocalization {
    param([string]$LanguageCode)

    $script:SourceTextDefaultLanguageData = Import-SourceTextLanguageFile -LanguageCode 'en-US'
    $script:SourceTextLanguageData = Import-SourceTextLanguageFile -LanguageCode $LanguageCode
    if (-not $script:SourceTextLanguageData) {
        $script:SourceTextLanguageData = $script:SourceTextDefaultLanguageData
    }
}

function Get-SourceTextLoc {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [object[]]$Args = @()
    )

    $value = $null
    if ($script:SourceTextLanguageData -and $script:SourceTextLanguageData.ContainsKey($Key)) {
        $value = [string]$script:SourceTextLanguageData[$Key]
    }
    elseif ($script:SourceTextDefaultLanguageData -and $script:SourceTextDefaultLanguageData.ContainsKey($Key)) {
        $value = [string]$script:SourceTextDefaultLanguageData[$Key]
    }
    else {
        $value = $Key
    }
    if ($Args.Count -gt 0) { return [string]::Format($value, $Args) }
    return $value
}

Initialize-SourceTextLocalization -LanguageCode $Language

function Write-StyledMessage {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Progress')]
        [string]$Type,
        
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Type) {
        'Success' { 
            Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
            Write-Host ((Get-SourceTextLoc 'uiText.success') + " ") -ForegroundColor Green -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        'Warning' { 
            Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
            Write-Host ((Get-SourceTextLoc 'uiText.warn') + "    ") -ForegroundColor Yellow -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        'Error' { 
            Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
            Write-Host ((Get-SourceTextLoc 'uiText.error') + "   ") -ForegroundColor Red -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        'Info' { 
            Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
            Write-Host ((Get-SourceTextLoc 'uiText.info') + "    ") -ForegroundColor Cyan -NoNewline
            Write-Host $Message -ForegroundColor White
        }
    }
}

Write-StyledMessage 'Info' (Get-SourceTextLoc 'sourceText.startingWintoolkitBuildProcess')

# ============================================================================
# 2. INIZIALIZZAZIONE E VERIFICA PERCORSI
# ============================================================================
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$toolFolder = Join-Path $scriptPath "tools"
$sourceFile = Join-Path $scriptPath "WinToolkit-template.ps1"
$outputFile = Join-Path $scriptPath "WinToolkit.ps1"

try {
    if (-not (Test-Path $sourceFile)) {
        throw (Get-SourceTextLoc 'uiText.templateFileNotFoundIn0' -Args @($sourceFile))
    }
    
    if (-not (Test-Path $toolFolder)) {
        throw (Get-SourceTextLoc 'uiText.toolsFolderNotFoundIn0' -Args @($toolFolder))
    }
}
catch {
    Write-StyledMessage 'Error' ((Get-SourceTextLoc 'sourceText.initializationError') + ": $($_.Exception.Message).")
    exit 1
}

# ============================================================================
# 3. LETTURA SORGENTI E PREPARAZIONE
# ============================================================================
try {
    Write-StyledMessage 'Info' ((Get-SourceTextLoc 'sourceText.readingSourceTemplate') + ': WinToolkit-template.ps1.')
    $templateLines = Get-Content $sourceFile -Encoding UTF8 -ErrorAction Stop
    $toolFiles = Get-ChildItem -Path $toolFolder -Filter "*.ps1" -File -ErrorAction Stop
}
catch {
    Write-StyledMessage 'Error' ((Get-SourceTextLoc 'sourceText.iOErrorWhileReadingSourceFiles') + ": $($_.Exception.Message).")
    exit 1
}

if ($toolFiles.Count -eq 0) {
    Write-StyledMessage 'Warning' (Get-SourceTextLoc 'uiText.noPs1ModulesFound0OperationCanceled' -Args @($toolFolder))
    exit 0
}

# Statistiche per la dashboard
$stats = @{
    Processed        = 0
    Skipped          = 0
    Errors           = 0
    Warnings         = 0
    TotalSourceSize  = (Get-Item $sourceFile).Length
    TotalSourceLines = $templateLines.Count
}

Write-StyledMessage 'Info' ((Get-SourceTextLoc 'sourceText.startingAggregation') + " $($toolFiles.Count) " + (Get-SourceTextLoc 'sourceText.modules') + '.')
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
            Write-StyledMessage 'Warning' (Get-SourceTextLoc 'uiText.emptyPrecompiledModule0InsertingDevelopmentStub' -Args @($functionName))
            $fileLines = @("    Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'uiText.functionDevelopmentInProgress')")
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
            
            # --- LOGICA DI DE-INCAPSULAMENTO (UNWRAP) ---
            # Se il file tool include già la dichiarazione 'function <name> { ... }', la rimuoviamo
            # per evitare la doppia nidificazione (catastrofica).
            $processedFileLines = $fileLines
            
            if ($fileLines.Count -gt 0) {
                # Trova il primo indice con contenuto significativo
                $firstNonEmpty = -1
                for ($i = 0; $i -lt $fileLines.Count; $i++) {
                    if (-not [string]::IsNullOrWhiteSpace($fileLines[$i])) { $firstNonEmpty = $i; break }
                }

                if ($firstNonEmpty -ge 0) {
                    $firstLine = $fileLines[$firstNonEmpty].Trim()
                    # Rilevamento Case-Insensitive della funzione corretta
                    if ($firstLine -match ("(?i)^function\s+" + [regex]::Escape($functionName) + "\s*\{")) {
                        Write-StyledMessage 'Info' ((Get-SourceTextLoc 'sourceText.detectedInternalFunctionIn') + " '$functionName'. " + (Get-SourceTextLoc 'sourceText.applyingUnwrapping'))
                        
                        # Rimuoviamo la riga della dichiarazione
                        if ($firstNonEmpty -eq 0) {
                            if ($fileLines.Count -gt 1) { $processedFileLines = $fileLines[1..($fileLines.Count - 1)] } else { $processedFileLines = @() }
                        }
                        else {
                            $processedFileLines = $fileLines[0..($firstNonEmpty - 1)] + $fileLines[($firstNonEmpty + 1)..($fileLines.Count - 1)]
                        }
                        
                        # Rimuoviamo eventuale parentesi di chiusura finale '}' (ultima riga non vuota)
                        $lastNonEmpty = -1
                        for ($j = $processedFileLines.Count - 1; $j -ge 0; $j--) {
                            if (-not [string]::IsNullOrWhiteSpace($processedFileLines[$j])) { $lastNonEmpty = $j; break }
                        }
                        if ($lastNonEmpty -ge 0 -and $processedFileLines[$lastNonEmpty].Trim() -eq "}") {
                            if ($lastNonEmpty -eq ($processedFileLines.Count - 1)) {
                                if ($processedFileLines.Count -gt 1) { $processedFileLines = $processedFileLines[0..($processedFileLines.Count - 2)] } else { $processedFileLines = @() }
                            }
                            else {
                                $processedFileLines = $processedFileLines[0..($lastNonEmpty - 1)] + $processedFileLines[($lastNonEmpty + 1)..($processedFileLines.Count - 1)]
                            }
                        }
                    }
                }
            }
            
            # --- GESTIONE LOGGING E RE-INSERIMENTO ---
            $hasLogging = $processedFileLines | Select-String -Pattern "Start-ToolkitLog|Start-ToolkitSession" -Quiet
            
            $newLines += "function $functionName {"
            if (-not $hasLogging) { 
                $newLines += "    Start-ToolkitLog -ToolName `"$functionName`"" 
                Write-StyledMessage 'Info' (Get-SourceTextLoc 'uiText.automaticStartToolkitLogInjectionPolicy0' -Args @($functionName))
            }
            $newLines += $processedFileLines
            $newLines += "}"
            
            if ($endIndex + 1 -lt $templateLines.Count) { $newLines += $templateLines[($endIndex + 1)..($templateLines.Count - 1)] }
            
            # Aggiorna il buffer master con la sostituzione
            $templateLines = $newLines
            Write-StyledMessage 'Success' ((Get-SourceTextLoc 'sourceText.moduleProcessed') + ": $functionName.")
            $stats.Processed++
        }
        else {
            Write-StyledMessage 'Warning' (Get-SourceTextLoc 'uiText.noEndpointFoundInTemplateSkipping0' -Args @($functionName))
            $stats.Skipped++
        }
    }
    catch {
        Write-StyledMessage 'Error' ((Get-SourceTextLoc 'sourceText.iOErrorWhileAggregatingModule') + " $functionName`: $($_.Exception.Message).")
        $stats.Errors++
    }
}
Write-Host ""


# ============================================================================
# 5. MOTORE DI MINIFICAZIONE SICURA (-Minify)
# ============================================================================
if ($Minify) {
    Write-StyledMessage 'Info' (Get-SourceTextLoc 'sourceText.startingSafeMinificationThroughThePowershellTokenizer')
    try {
        $backupLines = $templateLines
        $rawContent = $templateLines -join "`n"

        $parseErrors = $null
        $tokens = $null
        [System.Management.Automation.Language.Parser]::ParseInput(
            $rawContent,
            [ref]$tokens,
            [ref]$parseErrors
        ) | Out-Null

        if ($parseErrors.Count -gt 0) {
            Write-StyledMessage 'Warning' ((Get-SourceTextLoc 'sourceText.theSourceContains') + " $($parseErrors.Count) " + (Get-SourceTextLoc 'sourceText.preExistingParseErrorSMinificationAppliedAnyway'))
        }

        $commentTokens = $tokens |
        Where-Object { $_.Kind -eq 'Comment' } |
        Sort-Object { $_.Extent.StartOffset } -Descending

        foreach ($token in $commentTokens) {
            $start = $token.Extent.StartOffset
            $length = $token.Extent.EndOffset - $start
            $rawContent = $rawContent.Remove($start, $length)
        }

        Write-StyledMessage 'Info' (Get-SourceTextLoc 'uiText.removed0CommentTokens' -Args @($commentTokens.Count))

        $cleanedLines = ($rawContent -split "`n") | ForEach-Object {
            $_.TrimEnd()
        } | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        }

        $templateLines = $cleanedLines

        $verifyContent = $templateLines -join "`n"
        $verifyErrors = $null
        $verifyTokens = $null
        [System.Management.Automation.Language.Parser]::ParseInput(
            $verifyContent,
            [ref]$verifyTokens,
            [ref]$verifyErrors
        ) | Out-Null

        if ($verifyErrors.Count -gt 0) {
            Write-StyledMessage 'Warning' ((Get-SourceTextLoc 'sourceText.detected3') + " $($verifyErrors.Count) " + (Get-SourceTextLoc 'sourceText.postMinificationSyntaxErrorSRollingBackToOriginalSource'))
            foreach ($e in $verifyErrors) {
            Write-StyledMessage 'Warning' (Get-SourceTextLoc 'uiText.line01' -Args @($e.Extent.StartLineNumber, $e.Message))
            }
            $templateLines = $backupLines
        }
        else {
            $linesAfter = $templateLines.Count
            Write-StyledMessage 'Success' ((Get-SourceTextLoc 'sourceText.minificationCompleted') + ": $linesAfter " + (Get-SourceTextLoc 'sourceText.lines') + ' - ' + (Get-SourceTextLoc 'sourceText.noSyntaxErrorsDetected') + '.')
        }
    }
    catch {
        Write-StyledMessage 'Error' ((Get-SourceTextLoc 'sourceText.unexpectedErrorDuringMinification') + ": $($_.Exception.Message).")
        Write-StyledMessage 'Warning' (Get-SourceTextLoc 'uiText.continuingBuildWithoutMinification')
    }
    Write-Host ""
}


# ============================================================================
# 6. SCRITTURA COMPILAZIONE FINALE SUL DISCO
# ============================================================================
try {
    Write-StyledMessage 'Info' ((Get-SourceTextLoc 'sourceText.savingStandaloneExecutable') + ': WinToolkit.ps1.')
    
    if (Test-Path $outputFile) { Remove-Item $outputFile -Force -ErrorAction Stop }
    
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllLines($outputFile, $templateLines, $utf8Bom)
    
}
catch {
    Write-StyledMessage 'Error' (Get-SourceTextLoc 'uiText.irreversibleFailureWritingFinalFile0' -Args @($_.Exception.Message))
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
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ("                       " + (Get-SourceTextLoc 'sourceText.summaryBuildDashboard') + "                         ") -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ((Get-SourceTextLoc 'uiText.moduleStatistics') + "                                                  ") -ForegroundColor Yellow
Write-Host ("    " + (Get-SourceTextLoc 'uiText.processed0' -Args @($($stats.Processed)))) -ForegroundColor Green
Write-Host ("    " + (Get-SourceTextLoc 'uiText.skipped0' -Args @($($stats.Skipped)))) -ForegroundColor Yellow
if ($stats.Errors -gt 0) {
    Write-Host (Get-SourceTextLoc 'uiText.errors0' -Args @($($stats.Errors))) -ForegroundColor Red
}
else {
    Write-Host (Get-SourceTextLoc 'uiText.errors02') -ForegroundColor DarkGray
}
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ((Get-SourceTextLoc 'uiText.storageAndCompression') + "                                             ") -ForegroundColor Yellow
Write-Host ("    " + (Get-SourceTextLoc 'uiText.sources0Kb1Lines' -Args @($sourceMB, $($stats.TotalSourceLines)))) -ForegroundColor White
Write-Host ("    " + (Get-SourceTextLoc 'uiText.finalFile0Kb1Lines' -Args @($finalMB, $finalLinesCount))) -ForegroundColor Cyan
if ($Minify) {
    Write-Host (" " + (Get-SourceTextLoc 'uiText.reduction01LinesRemoved' -Args @($compressionPercent, $linesReduction))) -ForegroundColor Green
}
else {
    Write-Host (" " + (Get-SourceTextLoc 'uiText.reductionOffFlagMinifyNotDetected')) -ForegroundColor DarkGray
}
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ("    " + (Get-SourceTextLoc 'uiText.timediffMeasure') + "                                                       ") -ForegroundColor Yellow
Write-Host ("    " + (Get-SourceTextLoc 'uiText.execution0Sec' -Args @($buildTimeSec))) -ForegroundColor White
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

if ($stats.Errors -gt 0) {
    Write-StyledMessage 'Warning' (Get-SourceTextLoc 'uiText.buildCompletedWithMinorAnomaliesOrSkippedModules')
    exit 1
}
else {
    Write-StyledMessage 'Success' ((Get-SourceTextLoc 'sourceText.compilerPs1PipelineExecutedWithCode') + ' 0.')
    exit 0
}
