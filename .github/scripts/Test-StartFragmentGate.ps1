# WinToolkit CI/CD V4.1.0
<#
    Acceptance gate for the start-modules fragments.

    Rebuilds the compiled artefact and runs, in order:
      1. AST parse of the ordered concatenation (the published form is `irm | iex`);
      2. no function defined twice across fragments;
      3. no undefined function referenced (defined-and-never-called audit is
         reported separately, as information);
      4. PSScriptAnalyzer over the fragment sources;
      5. the fragment test suites.

    Usage: .\.github\scripts\Test-StartFragmentGate.ps1 [-SkipTests]
#>
[CmdletBinding()]
param([switch]$SkipTests)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$moduleRoot = Join-Path $repoRoot 'start-modules'
$failures = [System.Collections.Generic.List[string]]::new()

function Write-GateSection { param([string]$Text) Write-Host ''; Write-Host "== $Text" -ForegroundColor Cyan }

Write-GateSection '1. Ordered concatenation parses (PS7 parser)'
$files = @(Get-ChildItem -LiteralPath $moduleRoot -Filter '*.ps1' -File | Sort-Object Name)
$joined = ($files | Get-Content -Raw) -join "`n"
$parseErrors = $null
$joinedAst = [System.Management.Automation.Language.Parser]::ParseInput($joined, [ref]$null, [ref]$parseErrors)
if ($parseErrors) {
    $parseErrors | ForEach-Object { Write-Host "   PARSE ERROR: $($_.Message)" -ForegroundColor Red; $failures.Add($_.Message) }
}
else { Write-Host "   OK - $($files.Count) fragments, no syntax error" -ForegroundColor Green }

Write-GateSection '2. No function defined in more than one fragment'
$defined = foreach ($f in $files) {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$null)
    @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) |
        ForEach-Object { $_.Name }
}
$duplicates = @($defined | Group-Object | Where-Object Count -gt 1)
if ($duplicates) {
    $duplicates | ForEach-Object { Write-Host "   DUPLICATE: $($_.Name) x$($_.Count)" -ForegroundColor Red; $failures.Add("duplicate $($_.Name)") }
}
else { Write-Host "   OK - $($defined.Count) functions, all unique" -ForegroundColor Green }

Write-GateSection '3. Audit: functions defined and never called'
# Informational by default; -TreatDeadCodeAsError is opt-in so the F2 phase can
# use it as a hard acceptance criterion.
$called = @{}
foreach ($m in [regex]::Matches($joined, '([A-Za-z][A-Za-z0-9\-]*)')) { $called[$m.Groups[1].Value] = $true }
$dead = @($defined | Where-Object { -not $called.ContainsKey($_) } | Sort-Object -Unique)
if ($dead) {
    foreach ($name in $dead) {
        Write-Host "   never called: $name" -ForegroundColor Yellow
    }
}
else { Write-Host '   OK - every function is referenced' -ForegroundColor Green }

Write-GateSection '4. No local variable read before assignment (AST)'
# Set-StrictMode -Version Latest (00-Skeleton.Header.ps1) turns a read of an
# unassigned local into a terminating error, so an orchestrator that reads a
# variable nobody ever sets does not degrade: the whole run aborts. That is
# invisible to the tests, which never execute the orchestrator, so the check
# lives here. The parse tree is the one built in section 1.
#
# Only unqualified locals are audited: $script:/$global:/$env: state is declared
# in the header and is someone else's business, and parameters are initialised by
# definition (including the ones of nested script blocks, e.g. -ContentValidator).
$automatic = @(
    'args', 'null', 'true', 'false', 'input', 'PSItem', 'LASTEXITCODE', 'Matches',
    'Error', 'Host', 'PID', 'PSScriptRoot', 'PSCommandPath', 'MyInvocation', 'PSCmdlet',
    'PSBoundParameters', 'PSVersionTable', 'PSUICulture', 'PSHOME', 'ErrorActionPreference',
    'PWD', 'OFS', 'StackTrace', 'ExecutionContext', 'Sender', 'Event', 'EventArgs',
    'EventSubscriber', 'IsWindows', 'IsLinux', 'IsMacOS', 'IsCoreCLR', 'ShellId',
    'ConsoleFileName', 'foreach', 'switch', 'HOME', 'EnabledExperimentalFeatures',
    'MaximumHistoryCount'
)
$uninitialised = [System.Collections.Generic.List[string]]::new()

if ($parseErrors) {
    Write-Host '   SKIPPED - the concatenation does not parse, fix section 1 first' -ForegroundColor Yellow
}
else {
    foreach ($function in $joinedAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        if (-not $function.Body) { continue }

        $scoped = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($parameter in $function.Body.FindAll({ $args[0] -is [System.Management.Automation.Language.ParameterAst] }, $true)) {
            [void]$scoped.Add($parameter.Name.VariablePath.UserPath)
        }

        $assigned = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($assignment in $function.Body.FindAll({ $args[0] -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
            if ($assignment.Left -is [System.Management.Automation.Language.VariableExpressionAst]) {
                [void]$assigned.Add($assignment.Left.VariablePath.UserPath)
            }
        }
        foreach ($increment in $function.Body.FindAll({ $args[0] -is [System.Management.Automation.Language.UnaryExpressionAst] -and $args[0].TokenKind -eq 'PlusPlus' }, $true)) {
            if ($increment.Child -is [System.Management.Automation.Language.VariableExpressionAst]) {
                [void]$assigned.Add($increment.Child.VariablePath.UserPath)
            }
        }
        foreach ($loop in $function.Body.FindAll({ $args[0] -is [System.Management.Automation.Language.ForEachStatementAst] }, $true)) {
            [void]$assigned.Add($loop.Variable.VariablePath.UserPath)
        }
        # catch { ... } binds $_, and anything the handler reads counts as bound.
        foreach ($clause in $function.Body.FindAll({ $args[0] -is [System.Management.Automation.Language.CatchClauseAst] }, $true)) {
            foreach ($bound in $clause.Body.FindAll({ $args[0] -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)) {
                [void]$assigned.Add($bound.VariablePath.UserPath)
            }
        }

        foreach ($read in $function.Body.FindAll({ $args[0] -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)) {
            $path = $read.VariablePath
            if (-not $path.IsUnscopedVariable) { continue }
            $name = $path.UserPath
            if ($name -eq '_' -or $automatic -contains $name) { continue }
            if ($scoped.Contains($name) -or $assigned.Contains($name)) { continue }
            $uninitialised.Add("$($function.Name) reads `$$name (line $($read.Extent.StartLineNumber))")
        }
    }

    if ($uninitialised.Count -gt 0) {
        $uninitialised | Sort-Object -Unique | ForEach-Object {
            Write-Host "   UNINITIALISED: $_" -ForegroundColor Red
            $failures.Add("uninitialised local: $_")
        }
    }
    else {
        $functionCount = @($joinedAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)).Count
        Write-Host "   OK - $functionCount functions, every local is assigned before use" -ForegroundColor Green
    }
}

Write-GateSection '5. PSScriptAnalyzer (Warning/Error)'
$settings = Join-Path $repoRoot '.github\linters\PSScriptAnalyzer-settings.psd1'
$findings = @()
foreach ($folder in @('start-modules', 'wintoolkit-modules')) {
    $target = Join-Path $repoRoot $folder
    if (Test-Path $target) {
        $findings += @(Invoke-ScriptAnalyzer -Path $target -Settings $settings -Recurse |
                Where-Object { $_.Severity -in @('Warning', 'Error') })
    }
}
if ($findings) {
    $findings | Select-Object -First 25 | ForEach-Object {
        Write-Host "   $($_.Severity): $($_.ScriptName):$($_.Line) $($_.RuleName)" -ForegroundColor Red
    }
    $failures.Add("PSScriptAnalyzer findings: $($findings.Count)")
}
else { Write-Host '   OK - no findings' -ForegroundColor Green }

Write-GateSection '6. Compiled artefact'
$version = ([regex]::Match($joined, '(?m)^\$ToolkitVersion\s*=\s*"([^"]*)"')).Groups[1].Value
$buildScript = Join-Path $repoRoot '.github\scripts\Invoke-Build-Start.ps1'
& pwsh -NoProfile -File $buildScript -Version $version | ForEach-Object { Write-Host "   $_" }
if ($LASTEXITCODE -ne 0) { $failures.Add('build failed') }
$testCompiled = Join-Path $repoRoot '.github\scripts\Test-CompiledStartScript.ps1'
& pwsh -NoProfile -File $testCompiled -ScriptPath 'start-core.ps1' | ForEach-Object { Write-Host "   $_" }
if ($LASTEXITCODE -ne 0) { $failures.Add('compiled artefact validation failed') }

if (-not $SkipTests) {
    Write-GateSection '7. Fragment test suites'
    # Pester runs in a CHILD process on purpose: this script sets StrictMode and
    # ErrorActionPreference = Stop for its own checks, and inheriting that state
    # would make the suites fail for reasons unrelated to the fragments.
    $runner = Join-Path $env:TEMP ("wt-gate-pester-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
    $runnerCode = @"
`$r = Invoke-Pester -Path '$($repoRoot -replace "'", "''")\.github\tests\StartModules' -PassThru -Output None
"Execution Summary: Passed=`$(`$r.PassedCount) Failed=`$(`$r.FailedCount)"
if (`$r.FailedCount -gt 0) { `$r.Failed | ForEach-Object { "FAILED: `$(`$_.ExpandedPath)" }; exit 1 }
exit 0
"@
    try {
        Set-Content -LiteralPath $runner -Value $runnerCode -Encoding UTF8
        & pwsh -NoProfile -File $runner | ForEach-Object { Write-Host "   $_" }
        if ($LASTEXITCODE -ne 0) { $failures.Add('failing tests in the fragment suites') }
    }
    finally {
        Remove-Item -LiteralPath $runner -Force -ErrorAction SilentlyContinue
    }
}

Write-GateSection 'RESULT'
$lines = (Get-ChildItem $moduleRoot -Filter '*.ps1' -File | Get-Content | Measure-Object -Line).Lines
Write-Host "   start-modules total lines: $lines"
if ($failures) {
    foreach ($f in $failures) { Write-Host "   FAIL: $f" -ForegroundColor Red }
    exit 1
}
Write-Host '   GATE PASSED' -ForegroundColor Green
exit 0
