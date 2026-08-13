# Compilation script for WinToolkit (Enterprise-Grade)
# Handles module aggregation, structured logging and code minification.

[CmdletBinding()]
param(
    [switch]$Minify,
    [string]$Language = 'en-US'
)

$ErrorActionPreference = 'Stop'
$ScriptStartTime = [System.Diagnostics.Stopwatch]::StartNew()

# ============================================================================
# 1. ENTERPRISE LOGGING SYSTEM
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
        [Alias('Args')][object[]]$Arguments = @()
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
    if ($Arguments.Count -gt 0) { return [string]::Format($value, $Arguments) }
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
# 2. PATH INITIALIZATION AND VERIFICATION
# ============================================================================
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$toolFolder = Join-Path $scriptPath "tools"
$sourceFile = Join-Path $scriptPath "WinToolkit-template.ps1"
$outputFile = Join-Path $scriptPath "WinToolkit.ps1"

try {
    if (-not (Test-Path $sourceFile)) {
        throw (Get-SourceTextLoc 'uiText.templateFileNotFoundIn0' -Arguments @($sourceFile))
    }
    
    if (-not (Test-Path $toolFolder)) {
        throw (Get-SourceTextLoc 'uiText.toolsFolderNotFoundIn0' -Arguments @($toolFolder))
    }
}
catch {
    Write-StyledMessage 'Error' ((Get-SourceTextLoc 'sourceText.initializationError') + ": $($_.Exception.Message).")
    exit 1
}

# ============================================================================
# 3. SOURCE READING AND PREPARATION
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

# Statistics for the dashboard
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
# 4. AGGREGATION ENGINE (CODE INJECTION)
# ============================================================================
foreach ($file in $toolFiles) {
    $functionName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $stats.TotalSourceSize += $file.Length
    
    try {
        $fileLines = Get-Content $file.FullName -Encoding UTF8 -ErrorAction Stop
        $stats.TotalSourceLines += $fileLines.Count
        
        # Handle empty or whitespace-only modules
        if ($fileLines.Count -eq 0 -or ($fileLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -eq 0) {
            Write-StyledMessage 'Warning' (Get-SourceTextLoc 'uiText.emptyPrecompiledModule0InsertingDevelopmentStub' -Args @($functionName))
            $fileLines = @("    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.functionDevelopmentInProgress')")
            $stats.Warnings++
        }
        else {
            # Trim self-call (function call at end of file)
            $lastNonEmptyIndex = -1
            for ($i = $fileLines.Count - 1; $i -ge 0; $i--) {
                if (-not [string]::IsNullOrWhiteSpace($fileLines[$i])) { $lastNonEmptyIndex = $i; break }
            }
            if ($lastNonEmptyIndex -ge 0 -and $fileLines[$lastNonEmptyIndex].Trim() -eq $functionName) {
                # Replace removal with slice up to -1
                if ($lastNonEmptyIndex -eq 0) { $fileLines = @() } else { $fileLines = $fileLines[0..($lastNonEmptyIndex - 1)] }
            }
        }
        
        # Search for function placeholder in template
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
        
        # Injection of processed code
        if ($functionFound -and $startIndex -ge 0 -and $endIndex -ge 0) {
            $newLines = @()
            if ($startIndex -gt 0) { $newLines += $templateLines[0..($startIndex - 1)] }
            
            # --- LOGICA DI DE-INCAPSULAMENTO (UNWRAP) ---
            # If the tool file already includes the declaration 'function <name> { ... }', we remove it
            # to avoid double nesting (catastrophic).
            $processedFileLines = $fileLines
            
            if ($fileLines.Count -gt 0) {
                # Trova il primo indice con contenuto significativo
                $firstNonEmpty = -1
                for ($i = 0; $i -lt $fileLines.Count; $i++) {
                    if (-not [string]::IsNullOrWhiteSpace($fileLines[$i])) { $firstNonEmpty = $i; break }
                }

                if ($firstNonEmpty -ge 0) {
                    $firstLine = $fileLines[$firstNonEmpty].Trim()
                    # Case-Insensitive detection of the correct function
                    if ($firstLine -match ("(?i)^function\s+" + [regex]::Escape($functionName) + "\s*\{")) {
                        Write-StyledMessage 'Info' ((Get-SourceTextLoc 'sourceText.detectedInternalFunctionIn') + " '$functionName'. " + (Get-SourceTextLoc 'sourceText.applyingUnwrapping'))
                        
                        # We remove the declaration line
                        if ($firstNonEmpty -eq 0) {
                            if ($fileLines.Count -gt 1) { $processedFileLines = $fileLines[1..($fileLines.Count - 1)] } else { $processedFileLines = @() }
                        }
                        else {
                            $processedFileLines = $fileLines[0..($firstNonEmpty - 1)] + $fileLines[($firstNonEmpty + 1)..($fileLines.Count - 1)]
                        }
                        
                        # We remove any final closing brace '}' (last non-empty line)
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
            
            # --- LOGGING AND RE-INSERTION ---
            $hasLogging = $processedFileLines | Select-String -Pattern "Start-ToolkitLog|Start-ToolkitSession" -Quiet
            
            $newLines += "function $functionName {"
            if (-not $hasLogging) { 
                $newLines += "    Start-ToolkitLog -ToolName `"$functionName`"" 
                Write-StyledMessage 'Info' (Get-SourceTextLoc 'uiText.automaticStartToolkitLogInjectionPolicy0' -Args @($functionName))
            }
            $newLines += $processedFileLines
            $newLines += "}"
            
            if ($endIndex + 1 -lt $templateLines.Count) { $newLines += $templateLines[($endIndex + 1)..($templateLines.Count - 1)] }
            
            # Update the master buffer with the replacement
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
# 5. SAFE MINIFICATION ENGINE (-Minify)
#    Delegates to the shared tokenizer-safe minifier (Minify-Source.ps1).
# ============================================================================
if ($Minify) {
    Write-StyledMessage 'Info' (Get-SourceTextLoc 'sourceText.startingSafeMinificationThroughThePowershellTokenizer')
    try {
        $templateContent = $templateLines -join "`n"
        $minifiedContent = & "$PSScriptRoot/.github/scripts/Minify-Source.ps1" -Content $templateContent -Verbose:$false
        $templateLines = $minifiedContent -split "`r?`n"
    }
    catch {
        Write-StyledMessage 'Error' ((Get-SourceTextLoc 'sourceText.unexpectedErrorDuringMinification') + ": $($_.Exception.Message).")
        Write-StyledMessage 'Warning' (Get-SourceTextLoc 'uiText.continuingBuildWithoutMinification')
    }
    Write-Host ""
}


# ============================================================================
# 6. FINAL COMPILATION WRITING TO DISK
# ============================================================================
try {
    Write-StyledMessage 'Info' ((Get-SourceTextLoc 'sourceText.savingStandaloneExecutable') + ': WinToolkit.ps1.')

    # Keep the generated artifact lint-clean without altering the source files.
    $templateLines = @($templateLines | ForEach-Object { $_.TrimEnd() })
    while ($templateLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($templateLines[-1])) {
        $templateLines = $templateLines[0..($templateLines.Count - 2)]
    }
    
    if (Test-Path $outputFile) { Remove-Item $outputFile -Force -ErrorAction Stop }
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($outputFile, $templateLines, $utf8NoBom)
    
}
catch {
    Write-StyledMessage 'Error' (Get-SourceTextLoc 'uiText.irreversibleFailureWritingFinalFile0' -Args @($_.Exception.Message))
    exit 1
}


# ============================================================================
# 7. METRICS AND BUILD SUMMARY DASHBOARD
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
