<#
.SYNOPSIS
    Validates the compiled start-core.ps1 artefact.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [string]$SourceDir = 'start-modules',
    [int]$MinimumSizeBytes = 50KB
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()

function Write-TestOutput {
    param([string]$Name, [object]$Value)
    if ($env:GITHUB_OUTPUT) { "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append }
}

try {
    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) { $errors.Add("Compiled script not found: $ScriptPath") }
    if ($errors.Count -eq 0) {
        $content = Get-Content -Raw -LiteralPath $ScriptPath
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$parseErrors) | Out-Null
        if ($parseErrors.Count -gt 0) { $errors.Add("PowerShell syntax errors: $($parseErrors.Count)") }

        $sourceFiles = @(Get-ChildItem -LiteralPath $SourceDir -Filter '*.ps1' -File | Sort-Object Name)
        $expectedFunctions = foreach ($file in $sourceFiles) {
            $fileErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$fileErrors)
            $functionAsts = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))
            foreach ($functionAst in $functionAsts) { $functionAst.Name }
        }
        $compiledAst = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
        $compiledFunctionAsts = @($compiledAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))
        $compiledFunctions = @($compiledFunctionAsts | ForEach-Object Name)
        $missing = @($expectedFunctions | Where-Object { $_ -notin $compiledFunctions })
        if ($missing.Count -gt 0) { $errors.Add("Missing functions: $($missing -join ', ')") }

        $sourceMarkers = @([regex]::Matches($content, '(?m)^# SOURCE: .+$'))
        # Minified artifacts intentionally remove comments, including SOURCE
        # markers. For non-minified output, retain the strict marker check.
        if ($sourceMarkers.Count -ne 0 -and $sourceMarkers.Count -ne $sourceFiles.Count) {
            $errors.Add("Expected either 0 SOURCE markers (minified) or $($sourceFiles.Count) SOURCE markers, found $($sourceMarkers.Count).")
        }
        $localImport = [regex]::Matches($content, '(?m)^\s*Import-Module\s+([./\\])')
        if ($localImport.Count -gt 0) { $errors.Add('Local Import-Module references are forbidden in start-core.ps1.') }

        $size = (Get-Item -LiteralPath $ScriptPath).Length
        if ($size -lt $MinimumSizeBytes) { $errors.Add("Compiled script is too small: $size bytes; minimum is $MinimumSizeBytes.") }
    }

    $passed = $errors.Count -eq 0
    if ($passed) { Write-Host 'start-core.ps1 validation passed.' -ForegroundColor Green }
    else { $errors | ForEach-Object { Write-Host "::error::$_" -ForegroundColor Red } }
    Write-TestOutput -Name 'tests_passed' -Value $passed.ToString().ToLowerInvariant()
    if (-not $passed) { exit 1 }
    exit 0
}
catch {
    Write-Host "::error::$($_.Exception.Message)" -ForegroundColor Red
    Write-TestOutput -Name 'tests_passed' -Value 'false'
    exit 1
}
