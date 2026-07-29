#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Integration test for the build pipeline.
.NOTES
    Verifies that compiler.ps1, the source files, and Test-CompiledScript.ps1
    are syntactically valid and consistent with each other.
    Tests marked with -Tag 'Slow' perform a real compilation
    and are skipped during fast CI runs (executed only in the build pipeline).
#>

BeforeAll {
    $script:RepoRoot       = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    $script:CompilerPath   = Join-Path $script:RepoRoot 'compiler.ps1'
    $script:TemplatePath   = Join-Path $script:RepoRoot 'WinToolkit-template.ps1'
    $script:ToolFolder     = Join-Path $script:RepoRoot 'tools'
    $script:TestScriptPath = Join-Path $script:RepoRoot '.github\scripts\Test-CompiledScript.ps1'
}

# =============================================================================
# Source syntax
# =============================================================================
Describe 'Build Pipeline — Source Syntax' {

    It 'compiler.ps1 must have valid PowerShell syntax' {
        $code   = Get-Content -Raw -Path $script:CompilerPath
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'WinToolkit-template.ps1 must have valid PowerShell syntax' {
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

# =============================================================================
# Source consistency
# =============================================================================
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

    It 'The template must contain a placeholder for every tools/*.ps1 file' {
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

# =============================================================================
# End-to-End Compilation (Slow — requires complete source files)
# =============================================================================
Describe 'Build Pipeline — End-to-End' -Tag 'Slow' {

    It 'compiler.ps1 produces a valid WinToolkit.ps1 output' {
        $originalLocation = Get-Location
        Set-Location $script:RepoRoot
        try {
            & $script:CompilerPath
            $LASTEXITCODE | Should -Be 0
            $outputPath = Join-Path $script:RepoRoot 'WinToolkit.ps1'
            Test-Path $outputPath | Should -Be $true

            $outputSize = (Get-Item $outputPath).Length
            $outputSize | Should -BeGreaterThan 10240 -Because 'output must be at least 10 KB'

            $code   = Get-Content -Raw -Path $outputPath
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$errors)
            $errors.Count | Should -Be 0 -Because 'compiled output must be syntactically valid'
        }
        finally {
            Set-Location $originalLocation
        }
    }
}