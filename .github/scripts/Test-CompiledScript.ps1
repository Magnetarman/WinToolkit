<#
.SYNOPSIS
    Valida il file WinToolkit.ps1 compilato.

.DESCRIPTION
    Esegue test di integrità sul file compilato: sintassi, funzioni, encoding,
    dimensione e struttura del menu.

.EXAMPLE
    .\Test-CompiledScript.ps1 -ScriptPath "WinToolkit.ps1"

.NOTES
    Autore: MagnetarMan
    Version: 1.0.4
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ScriptPath = "WinToolkit.ps1",

    [Parameter(Mandatory = $false)]
    [string]$ToolPath = "tool"
)

# --- Best Practices PowerShell ---
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Variabili risultati ---
$script:TotalErrors = 0
$script:TotalWarnings = 0
$script:TestResults = @()
$script:CriticalErrors = @()

function Write-TestLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )

    $colors = @{
        'Info'    = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $colors[$Type]
}

function Initialize-OutputVariable {
    # Create empty output file
    "" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Force
}

try {
    Write-TestLog -Message "========================================" -Type Info
    Write-TestLog -Message "  TEST INTEGRITÀ FILE COMPILATO" -Type Info
    Write-TestLog -Message "========================================" -Type Info
    Write-TestLog -Message "📋 Test del file: $ScriptPath" -Type Info

    # Verifica che il file esista
    if (-not (Test-Path $ScriptPath)) {
        Write-TestLog -Message "❌ File $ScriptPath non trovato" -Type Error
        $script:TotalErrors++
        $script:CriticalErrors += "File non trovato: $ScriptPath"
    }

    # Leggi il contenuto
    $scriptContent = Get-Content -Raw -Path $ScriptPath -ErrorAction Stop
    Write-TestLog -Message "✅ File letto con successo" -Type Success

    # ========================================
    # TEST 1: Sintassi PowerShell
    # ========================================
    Write-TestLog -Message "`n🔍 Test 1: Verifica sintassi..." -Type Info

    $parseErrors = $null
    $tokens = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors.Count -gt 0) {
        Write-TestLog -Message "  ❌ Errori di sintassi trovati: $($parseErrors.Count)" -Type Error
        foreach ($parseErr in $parseErrors) {
            Write-TestLog -Message "    → Linea $($parseErr.Extent.StartLineNumber): $($parseErr.Message)" -Type Error
            $script:CriticalErrors += "Linea $($parseErr.Extent.StartLineNumber): $($parseErr.Message)"
        }
        $script:TotalErrors += $parseErrors.Count
        $script:TestResults += "❌ Sintassi: $($parseErrors.Count) errori"
    }
    else {
        Write-TestLog -Message "  ✅ Sintassi OK" -Type Success
        $script:TestResults += "✅ Sintassi: OK"
    }

    # ========================================
    # TEST 2: Funzioni disponibili
    # ========================================
    Write-TestLog -Message "`n🔍 Test 2: Verifica funzioni..." -Type Info

    # Rilevamento automatico delle funzioni dalla cartella tool/
    $toolFiles = Get-ChildItem -Path $ToolPath -Filter "*.ps1" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*start-*" }
    $expectedFunctions = $toolFiles | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }

    # Parse del file compilato per trovare le funzioni
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$null)
    $functions = $scriptAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

    $presentFunctions = @()
    $missingFunctions = @()
    $emptyFunctions = @()

    foreach ($funcName in $expectedFunctions) {
        $funcAst = $functions | Where-Object { $_.Name -eq $funcName }
        if ($funcAst) {
            # Verifica se la funzione è vuota
            $bodyText = $funcAst.Body.Extent.Text
            $nonEmptyLines = $bodyText -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Trim()) }
            if ($nonEmptyLines.Count -le 2) {
                $emptyFunctions += $funcName
            }
            else {
                $presentFunctions += $funcName
            }
        }
        else {
            $missingFunctions += $funcName
        }
    }

    Write-TestLog -Message "  📊 Funzioni attese: $($expectedFunctions.Count)" -Type Info
    Write-TestLog -Message "  📊 Funzioni presenti: $($presentFunctions.Count)" -Type Success
    Write-TestLog -Message "  📊 Funzioni vuote: $($emptyFunctions.Count)" -Type Warning
    Write-TestLog -Message "  📊 Funzioni mancanti: $($missingFunctions.Count)" -Type Warning

    if ($presentFunctions.Count -eq $expectedFunctions.Count) {
        $script:TestResults += "✅ Funzioni: Tutte presenti e compilate ($($presentFunctions.Count))"
    }
    else {
        $script:TestResults += "ℹ️ Funzioni: $($presentFunctions.Count)/$($expectedFunctions.Count) presenti"
    }

    $script:TotalWarnings += $emptyFunctions.Count

    # ========================================
    # TEST 3: Struttura del menu
    # ========================================
    Write-TestLog -Message "`n🔍 Test 3: Verifica struttura menu..." -Type Info

    $menuTests = @(
        @{ Pattern = [regex]::Escape("while (`$true)"); Name = "Menu principale" },
        @{ Pattern = "Windows & Office"; Name = "Categoria Windows & Office" },
        @{ Pattern = "Driver & Gaming"; Name = "Categoria Driver & Gaming" },
        @{ Pattern = "Supporto"; Name = "Categoria Supporto" }
    )

    foreach ($test in $menuTests) {
        if ($scriptContent -match $test.Pattern) {
            Write-TestLog -Message "  ✅ $($test.Name)" -Type Success
            $script:TestResults += "✅ $($test.Name)"
        }
        else {
            Write-TestLog -Message "  ❌ $($test.Name) mancante" -Type Error
            $script:TotalErrors++
            $script:CriticalErrors += "Struttura menu: $($test.Name) mancante"
            $script:TestResults += "❌ $($test.Name) mancante"
        }
    }

    # ========================================
    # TEST 4: Dimensione del file
    # ========================================
    Write-TestLog -Message "`n🔍 Test 4: Verifica dimensione file..." -Type Info

    $fileSize = (Get-Item $ScriptPath).Length
    $fileSizeKB = [math]::Round($fileSize / 1KB, 2)

    if ($fileSize -lt 10000) {
        Write-TestLog -Message "  ❌ File troppo piccolo: $fileSize bytes" -Type Error
        $script:TotalErrors++
        $script:CriticalErrors += "Dimensione file sospetta: $fileSizeKB KB"
        $script:TestResults += "❌ Dimensione: $fileSizeKB KB (troppo piccolo)"
    }
    else {
        Write-TestLog -Message "  ✅ Dimensione OK: $fileSizeKB KB" -Type Success
        $script:TestResults += "✅ Dimensione: $fileSizeKB KB"
    }

    # ========================================
    # TEST 5: Encoding UTF-8 con BOM
    # ========================================
    Write-TestLog -Message "`n🔍 Test 5: Verifica encoding..." -Type Info

    $encoding = [System.Text.Encoding]::GetEncoding('UTF-8')
    $preamble = $encoding.GetPreamble()
    $fileBytes = Get-Content $ScriptPath -AsByteStream -ReadCount 0

    if ($fileBytes.Length -ge 3 -and $fileBytes[0] -eq $preamble[0] -and $fileBytes[1] -eq $preamble[1] -and $fileBytes[2] -eq $preamble[2]) {
        Write-TestLog -Message "  ✅ Encoding UTF-8 con BOM" -Type Success
        $script:TestResults += "✅ Encoding: UTF-8 con BOM"
    }
    else {
        Write-TestLog -Message "  ⚠️ Encoding senza BOM (accettabile)" -Type Warning
        $script:TotalWarnings++
        $script:TestResults += "⚠️ Encoding: Senza BOM"
    }

    # ========================================
    # Riepilogo risultati
    # ========================================
    Write-TestLog -Message "`n========================================" -Type Info
    Write-TestLog -Message "  RIEPILOGO TEST" -Type Info
    Write-TestLog -Message "========================================" -Type Info

    foreach ($result in $script:TestResults) {
        Write-TestLog -Message "  $result" -Type Info
    }

    Write-TestLog -Message "`n📊 Errori: $script:TotalErrors | Warning: $script:TotalWarnings" -Type Info

    # Output finale
    if ($script:TotalErrors -gt 0) {
        Write-TestLog -Message "`n❌ TEST FALLITI - $script:TotalErrors errori rilevati" -Type Error
        if ($script:CriticalErrors.Count -gt 0) {
            Write-TestLog -Message "`n🔍 Errori critici:" -Type Warning
            foreach ($errItem in $script:CriticalErrors) {
                Write-TestLog -Message "  - $errItem" -Type Error
            }
        }
        Write-Output "tests_passed=false" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
        Write-Output "total_errors=$script:TotalErrors" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
        Write-Output "total_warnings=$script:TotalWarnings" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
        exit 1
    }
    else {
        Write-TestLog -Message "`n✅ TUTTI I TEST SUPERATI!" -Type Success
        if ($script:TotalWarnings -gt 0) {
            Write-TestLog -Message "ℹ️ Nota: $($script:TotalWarnings) warning" -Type Warning
        }
        Write-Output "tests_passed=true" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
        Write-Output "total_errors=$script:TotalErrors" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
        Write-Output "total_warnings=$script:TotalWarnings" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
        exit 0
    }
}
catch {
    Write-TestLog -Message "❌ ERRORE DURANTE I TEST: $($_.Exception.Message)" -Type Error
    Write-TestLog -Message "Stack Trace: $($_.ScriptStackTrace)" -Type Error

    $script:TotalErrors++
    Write-Output "tests_passed=false" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "total_errors=$script:TotalErrors" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append

    exit 1
}
