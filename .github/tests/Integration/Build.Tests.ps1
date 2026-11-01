# WinToolkit CI/CD V4.2.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
Integration test for the build pipeline.
Verifies compiler.ps1, source files, and Test-CompiledScript.ps1 are syntactically valid and consistent.
Tests tagged 'Slow' perform a real compilation and are skipped during fast CI runs.
#>

BeforeAll {
    $script:RepoRoot       = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    $script:CompilerPath   = Join-Path $script:RepoRoot 'compiler.ps1'
    $script:TemplatePath   = & (Join-Path $PSScriptRoot '..\..\scripts\New-WinToolkitCoreScript.ps1')
    $script:ToolFolder     = Join-Path $script:RepoRoot 'tools'
    $script:TestScriptPath = Join-Path $script:RepoRoot '.github\scripts\Test-CompiledScript.ps1'
}

Describe 'Build Pipeline — Source Syntax' {

    It 'compiler.ps1 must have valid PowerShell syntax' {
        $code   = Get-Content -Raw -Path $script:CompilerPath
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'The assembled WinToolkit core must have valid PowerShell syntax' {
        $code   = Get-Content -Raw -Path $script:TemplatePath
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'Test-CompiledScript.ps1 must have valid PowerShell syntax' {
        $code   = Get-Content -Raw -Path $script:TestScriptPath
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'All tools/*.ps1 files must have valid PowerShell syntax' -ForEach (
        Get-ChildItem -Path (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')) 'tools') -Filter '*.ps1' |
        ForEach-Object { @{ File = $_ } }
    ) {
        $code   = Get-Content -Raw -Path $File.FullName
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0 -Because "$($File.Name) must be syntactically valid"
    }
}

Describe 'Build Pipeline — Source Consistency' {

    It 'Every tools/*.ps1 file must declare a function with its own name' {
        $files = Get-ChildItem -Path $script:ToolFolder -Filter '*.ps1'
        $files.Count | Should -BeGreaterThan 0

        foreach ($file in $files) {
            $functionName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $source       = Get-Content -Raw -Path $file.FullName
            $source | Should -Match "(?i)function\s+$([regex]::Escape($functionName))" `
                -Because "$($file.Name) must contain the function declaration $functionName"
        }
    }

    It 'The assembled core must contain a placeholder for every tools/*.ps1 file' {
        $templateContent = Get-Content -Raw -Path $script:TemplatePath
        $files = Get-ChildItem -Path $script:ToolFolder -Filter '*.ps1'

        foreach ($file in $files) {
            $functionName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $templateContent | Should -Match "function\s+$([regex]::Escape($functionName))\s*\{" `
                -Because "The template must have a placeholder for $functionName"
        }
    }

    It 'compiler.ps1 must declare the -Minify parameter' {
        $code = Get-Content -Raw -Path $script:CompilerPath
        $code | Should -Match '\[switch\]\$Minify'
    }
}

Describe 'Build Pipeline — Entry Function Injection' {

    It 'runs the tool body with <Scenario>, Minify=<Minify>' -ForEach $(
        $cases = @(
            @{ Scenario = 'leading line comments'; Source = @'
# This comment must not hide the entry function.
function WinDeleteUserProfiles {
    [CmdletBinding()]
    param([string]$Probe)
    Start-ToolkitSession
    "executed:$Probe"
}
'@ },
            @{ Scenario = 'block comments and a multiline declaration'; Source = @'
<# Leading help with braces: { } #>
function WinDeleteUserProfiles
{
    [CmdletBinding()]
    param([string]$Probe)
    Start-ToolkitSession
    "executed:$Probe"
}
# Trailing comment with braces: } {
'@ },
            @{ Scenario = 'an uncommented declaration'; Source = @'
function WinDeleteUserProfiles {
    [CmdletBinding()]
    param([string]$Probe)
    Start-ToolkitSession
    "executed:$Probe"
}
'@ },
            @{ Scenario = 'an unwrapped script body'; Source = @'
[CmdletBinding()]
param([string]$Probe)
Start-ToolkitSession
"executed:$Probe"
'@ }
        )
        foreach ($case in $cases) {
            foreach ($minify in @($false, $true)) {
                @{ Scenario = $case.Scenario; Source = $case.Source; Minify = $minify }
            }
        }
    ) {
        $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $fixtureTools = New-Item -Path (Join-Path $fixtureRoot 'tools') -ItemType Directory -Force
        $fixtureModules = New-Item -Path (Join-Path $fixtureRoot 'wintoolkit-modules') -ItemType Directory -Force
        $fixtureCompiler = Join-Path $fixtureRoot 'compiler.ps1'
        Copy-Item -LiteralPath $script:CompilerPath -Destination $fixtureCompiler
        Set-Content -LiteralPath (Join-Path $fixtureTools.FullName 'WinDeleteUserProfiles.ps1') -Value $Source -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $fixtureModules.FullName '00-Fixture.ps1') -Value 'function Start-ToolkitSession {}' -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $fixtureModules.FullName '01-Placeholder.ps1') -Value 'function WinDeleteUserProfiles {}' -Encoding UTF8

        & $fixtureCompiler -Minify:$Minify 6>$null
        $LASTEXITCODE | Should -Be 0
        $outputPath = Join-Path $fixtureRoot 'WinToolkit.ps1'
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($outputPath, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
        $entryFunctions = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'WinDeleteUserProfiles'
        }, $true))
        $entryFunctions | Should -HaveCount 1

        . $outputPath
        @(WinDeleteUserProfiles -Probe 'regression') | Should -Be @('executed:regression')
        if (-not $Minify -and $Scenario -eq 'block comments and a multiline declaration') {
            $compiledSource = Get-Content -LiteralPath $outputPath -Raw
            $compiledSource | Should -Match 'Leading help with braces'
            $compiledSource | Should -Match 'Trailing comment with braces'
        }
    }
}

Describe 'Build Pipeline — End-to-End' -Tag 'Slow' {

    It 'compiler.ps1 produces a valid WinToolkit.ps1 output, Minify=<Minify>' -ForEach @(
        @{ Minify = $false },
        @{ Minify = $true }
    ) {
        $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = New-Item -Path $fixtureRoot -ItemType Directory
        $fixtureCompiler = Join-Path $fixtureRoot 'compiler.ps1'
        Copy-Item -LiteralPath $script:CompilerPath -Destination $fixtureCompiler
        foreach ($folder in @('tools', 'wintoolkit-modules', 'languages')) {
            Copy-Item -LiteralPath (Join-Path $script:RepoRoot $folder) -Destination $fixtureRoot -Recurse
        }
        $fixtureScripts = New-Item -Path (Join-Path $fixtureRoot '.github/scripts') -ItemType Directory -Force
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot '.github/scripts/Minify-Source.ps1') -Destination $fixtureScripts.FullName

        & $fixtureCompiler -Minify:$Minify 6>$null
        $LASTEXITCODE | Should -Be 0
        $outputPath = Join-Path $fixtureRoot 'WinToolkit.ps1'
        Test-Path $outputPath | Should -Be $true

        $outputSize = (Get-Item $outputPath).Length
        $outputSize | Should -BeGreaterThan 10240 -Because 'output must be at least 10 KB'

        $code   = Get-Content -Raw -Path $outputPath
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0 -Because 'compiled output must be syntactically valid'

        foreach ($toolFile in Get-ChildItem -LiteralPath (Join-Path $fixtureRoot 'tools') -Filter *.ps1 -File) {
            $name = $toolFile.BaseName
            $entries = @($ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
            }, $true))
            $entries | Should -HaveCount 1 -Because "$name must not be nested inside another copy of itself"
            $entries[0].Body.ParamBlock | Should -Not -BeNullOrEmpty -Because "$name must expose its actual parameters"
        }
    }
}
