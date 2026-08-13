#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Structural and syntax validation for the start-modules/ source fragments.

    These tests run against the modular sources directly (never against the
    compiled start-core.ps1), so a failure isolates the offending module.
#>

BeforeAll {
    $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\start-modules')
    $script:ModuleFiles = Get-ChildItem -Path $script:ModuleRoot -Filter '*.ps1' | Sort-Object Name

    function Test-AstParse {
        param([string]$Path)
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors)
        return $errors
    }
}

Describe 'start-modules — structural validation' {

    It 'each file follows the NN-Skeleton|Module.Name.ps1 naming convention' {
        foreach ($f in $script:ModuleFiles) {
            $f.Name | Should -Match '^\d{2}-(Skeleton|Module)\.[A-Za-z]+\.ps1$'
        }
    }

    It 'contains exactly one skeleton header and one skeleton main' {
        $headers = @($script:ModuleFiles | Where-Object { $_.Name -eq '00-Skeleton.Header.ps1' })
        $mains   = @($script:ModuleFiles | Where-Object { $_.Name -eq '90-Skeleton.Main.ps1' })
        $headers | Should -HaveCount 1
        $mains   | Should -HaveCount 1
    }

    It 'contains no AST syntax errors (PowerShell 7 parser)' {
        foreach ($f in $script:ModuleFiles) {
            $errors = Test-AstParse -Path $f.FullName
            $errors.Count | Should -Be 0 -Because "file $($f.Name) must not contain syntax errors"
        }
    }

    It 'no function is defined in more than one file (no duplicates across modules)' {
        $allFunctionNames = foreach ($f in $script:ModuleFiles) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$null)
            $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true).Name
        }
        ($allFunctionNames | Group-Object | Where-Object Count -gt 1).Count | Should -Be 0
    }

    It 'no fragment imports another local fragment via Import-Module (irm|iex constraint, §5.1)' {
        # Importing the external Microsoft.WinGet.Client Gallery module inside
        # 40-Module.Winget.ps1 is legitimate and must NOT trip this guard.
        foreach ($f in $script:ModuleFiles) {
            $content = Get-Content $f.FullName -Raw
            $hasLocalImport = $content -match 'Import-Module\s+(?:\.\\)?[\w-]*Modules?[\w-]*' -or
                              $content -match 'Import-Module\s+[.\/\\]'
            $hasLocalImport | Should -BeFalse -Because "$($f.Name) must not import local fragments via Import-Module"
        }
    }

    It 'only the Dev and main branches are referenced in the URL maps (§2.10.2)' {
        $raw = ($script:ModuleFiles | Get-Content -Raw) -join "`n"
        $raw | Should -Not -Match 'refs/heads/(?!Dev|main)[A-Za-z]+'
    }
}

Describe 'start-modules — concatenation produces a valid start-core.ps1' {

    It 'the ordered concatenation of fragments parses without errors' {
        $concatenated = ($script:ModuleFiles | Get-Content -Raw) -join "`n"
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($concatenated, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }
}
