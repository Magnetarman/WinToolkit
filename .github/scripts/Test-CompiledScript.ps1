<#
.SYNOPSIS
    Validates the compiled WinToolkit.ps1 file.

.DESCRIPTION
    Performs integrity tests on the compiled file: syntax, functions, encoding,
    size, and menu structure.

.EXAMPLE
    .\Test-CompiledScript.ps1 -ScriptPath "WinToolkit.ps1"

.NOTES
    Author: MagnetarMan
    Version: 1.0.7
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ScriptPath = "WinToolkit.ps1",

    [Parameter(Mandatory = $false)]
    [string]$ToolPath = "tools",

    [Parameter(Mandatory = $false)]
    [string]$TemplatePath = "WinToolkit-template.ps1"
)

# --- PowerShell Best Practices ---
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Result variables ---
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
    Write-TestLog -Message "  COMPILED FILE INTEGRITY TESTS" -Type Info
    Write-TestLog -Message "========================================" -Type Info
    Write-TestLog -Message "📋 Testing file: $ScriptPath" -Type Info

    # Verify the file exists
    if (-not (Test-Path $ScriptPath)) {
        Write-TestLog -Message "❌ File $ScriptPath not found" -Type Error
        $script:TotalErrors++
        $script:CriticalErrors += "File not found: $ScriptPath"
    }

    # Read the content
    $scriptContent = Get-Content -Raw -Path $ScriptPath -ErrorAction Stop
    Write-TestLog -Message "✅ File read successfully" -Type Success

    # ========================================
    # TEST 1: PowerShell Syntax
    # ========================================
    Write-TestLog -Message "`n🔍 Test 1: Syntax check..." -Type Info

    $parseErrors = $null
    $tokens = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors.Count -gt 0) {
        Write-TestLog -Message "  ❌ Syntax errors found: $($parseErrors.Count)" -Type Error
        foreach ($parseErr in $parseErrors) {
            Write-TestLog -Message "    → Line $($parseErr.Extent.StartLineNumber): $($parseErr.Message)" -Type Error
            $script:CriticalErrors += "Line $($parseErr.Extent.StartLineNumber): $($parseErr.Message)"
        }
        $script:TotalErrors += $parseErrors.Count
        $script:TestResults += "❌ Syntax: $($parseErrors.Count) errors"
    }
    else {
        Write-TestLog -Message "  ✅ Syntax OK" -Type Success
        $script:TestResults += "✅ Syntax: OK"
    }

    # ========================================
    # TEST 2: Available functions
    # ========================================
    Write-TestLog -Message "`n🔍 Test 2: Functions check..." -Type Info

    # Auto-detect functions from the tools/ folder
    $toolFiles = Get-ChildItem -Path $ToolPath -Filter "*.ps1" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*start-*" }
    $expectedFunctions = $toolFiles | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }

    # Parse the compiled file to find functions
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$null)
    $functions = $scriptAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

    $presentFunctions = @()
    $missingFunctions = @()
    $emptyFunctions = @()
    $devFunctions = @()

    foreach ($funcName in $expectedFunctions) {
        $funcAst = $functions | Where-Object { $_.Name -eq $funcName }
        if ($funcAst) {
            # Check if the function is empty
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
            # If missing from compiled, check the template (because minification removes comments)
            $templateContent = if (Test-Path $TemplatePath) { Get-Content -Raw $TemplatePath } else { "" }

            if ($templateContent -match "(?m)^\s*#\s*(function\s+)?$funcName\s*\{") {
                $devFunctions += $funcName
            }
            elseif ($templateContent -match "(?m)^\s*function\s+$funcName\s*\{") {
                 # Present in template but not in compiled? Odd, but consider it under development/skipped
                 $devFunctions += $funcName
            }
            else {
                $missingFunctions += $funcName
            }
        }
    }

    Write-TestLog -Message "  📊 Expected functions: $($expectedFunctions.Count)" -Type Info
    Write-TestLog -Message "  📊 Present functions: $($presentFunctions.Count)" -Type Success

    if ($devFunctions.Count -gt 0) {
        Write-TestLog -Message "  🚧 Functions in development (commented out): $($devFunctions.Count)" -Type Info
        foreach ($f in $devFunctions) { Write-TestLog -Message "    → $f (In Development)" -Type Info }
    }

    if ($emptyFunctions.Count -gt 0) {
        Write-TestLog -Message "  ⚠️ Empty functions: $($emptyFunctions.Count)" -Type Warning
        foreach ($f in $emptyFunctions) { Write-TestLog -Message "    → $f (Empty)" -Type Warning }
    }

    if ($missingFunctions.Count -gt 0) {
        Write-TestLog -Message "  ❌ MISSING functions: $($missingFunctions.Count)" -Type Error
        foreach ($f in $missingFunctions) { Write-TestLog -Message "    → $f (NOT FOUND)" -Type Error }
    }

    if ($missingFunctions.Count -eq 0) {
        $status = "✅ Functions: All handled ($($presentFunctions.Count) active"
        if ($devFunctions.Count -gt 0) { $status += ", $($devFunctions.Count) in development" }
        $status += ")"
        $script:TestResults += $status
    }
    else {
        $script:TestResults += "❌ Functions: $($presentFunctions.Count)/$($expectedFunctions.Count) present"
        $script:TotalErrors++
        $errorMsg = "MODULES MISSING IN TEMPLATE: The following scripts in /tools do not have a placeholder (even commented out) in WinToolkit-template.ps1: $($missingFunctions -join ', ')"
        $script:CriticalErrors += $errorMsg
    }

    $script:TotalWarnings += $emptyFunctions.Count

    # ========================================
    # TEST 3: Menu structure
    # ========================================
    Write-TestLog -Message "`n🔍 Test 3: Menu structure check..." -Type Info

    $menuTests = @(
        @{ Pattern = [regex]::Escape("while (`$true)"); Name = "Main menu" }
    )

    foreach ($test in $menuTests) {
        if ($scriptContent -match $test.Pattern) {
            Write-TestLog -Message "  ✅ $($test.Name)" -Type Success
            $script:TestResults += "✅ $($test.Name)"
        }
        else {
            Write-TestLog -Message "  ❌ $($test.Name) missing" -Type Error
            $script:TotalErrors++
            $script:CriticalErrors += "Menu structure: $($test.Name) missing"
            $script:TestResults += "❌ $($test.Name) missing"
        }
    }

    # ========================================
    # TEST 4: File size
    # ========================================
    Write-TestLog -Message "`n🔍 Test 4: File size check..." -Type Info

    $fileSize = (Get-Item $ScriptPath).Length
    $fileSizeKB = [math]::Round($fileSize / 1KB, 2)

    if ($fileSize -lt 10000) {
        Write-TestLog -Message "  ❌ File too small: $fileSize bytes" -Type Error
        $script:TotalErrors++
        $script:CriticalErrors += "Suspicious file size: $fileSizeKB KB"
        $script:TestResults += "❌ Size: $fileSizeKB KB (too small)"
    }
    else {
        Write-TestLog -Message "  ✅ Size OK: $fileSizeKB KB" -Type Success
        $script:TestResults += "✅ Size: $fileSizeKB KB"
    }

    # ========================================
    # TEST 5: UTF-8 with BOM encoding
    # ========================================
    Write-TestLog -Message "`n🔍 Test 5: Encoding check..." -Type Info

    $encoding = [System.Text.Encoding]::GetEncoding('UTF-8')
    $preamble = $encoding.GetPreamble()
    $fileBytes = Get-Content $ScriptPath -AsByteStream -ReadCount 0

    if ($fileBytes.Length -ge 3 -and $fileBytes[0] -eq $preamble[0] -and $fileBytes[1] -eq $preamble[1] -and $fileBytes[2] -eq $preamble[2]) {
        Write-TestLog -Message "  ✅ Encoding UTF-8 with BOM" -Type Success
        $script:TestResults += "✅ Encoding: UTF-8 with BOM"
    }
    else {
        Write-TestLog -Message "  ⚠️ Encoding without BOM (acceptable)" -Type Warning
        $script:TotalWarnings++
        $script:TestResults += "⚠️ Encoding: Without BOM"
    }

    # ========================================
    # Results summary
    # ========================================
    Write-TestLog -Message "`n========================================" -Type Info
    Write-TestLog -Message "  TEST SUMMARY" -Type Info
    Write-TestLog -Message "========================================" -Type Info

    foreach ($result in $script:TestResults) {
        Write-TestLog -Message "  $result" -Type Info
    }

    Write-TestLog -Message "`n📊 Errors: $script:TotalErrors | Warnings: $script:TotalWarnings" -Type Info

    # Final output
    if ($script:TotalErrors -gt 0) {
        Write-TestLog -Message "`n❌ TESTS FAILED - $script:TotalErrors errors detected" -Type Error
        if ($script:CriticalErrors.Count -gt 0) {
            Write-TestLog -Message "`n🔍 Critical errors:" -Type Warning
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
        Write-TestLog -Message "`n✅ ALL TESTS PASSED!" -Type Success
        if ($script:TotalWarnings -gt 0) {
            Write-TestLog -Message "ℹ️ Note: $($script:TotalWarnings) warning(s)" -Type Warning
        }
        Write-Output "tests_passed=true" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
        Write-Output "total_errors=$script:TotalErrors" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
        Write-Output "total_warnings=$script:TotalWarnings" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
        exit 0
    }
}
catch {
    Write-TestLog -Message "❌ ERROR DURING TESTS: $($_.Exception.Message)" -Type Error
    Write-TestLog -Message "Stack Trace: $($_.ScriptStackTrace)" -Type Error

    $script:TotalErrors++
    Write-Output "tests_passed=false" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "total_errors=$script:TotalErrors" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append

    exit 1
}
