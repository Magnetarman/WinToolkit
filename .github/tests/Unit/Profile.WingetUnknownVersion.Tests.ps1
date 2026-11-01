# WinToolkit CI/CD
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
Pester 5 test suite for the PowerShell profile helper Test-WingetUnknownVersion.
Strategy: parse the profile AST to extract only the function definition (no profile
side effects), then Invoke-Expression it in the test scope.
#>

BeforeAll {
    $script:ProfilePath = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\assets\Microsoft.PowerShell_profile.ps1')

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:ProfilePath, [ref]$tokens, [ref]$errors)
    if ($errors) { throw "Profile parse errors: $($errors -join '; ')" }

    $fn = $ast.FindAll(
        { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-WingetUnknownVersion' },
        $true
    ) | Select-Object -First 1

    if (-not $fn) { throw "Test-WingetUnknownVersion not found in profile." }
    Invoke-Expression $fn.Extent.Text

    if (-not (Get-Command Test-WingetUnknownVersion -ErrorAction SilentlyContinue)) {
        throw "Test-WingetUnknownVersion was not defined after Invoke-Expression."
    }
}

Describe 'Test-WingetUnknownVersion' {

    It 'returns $true when the output contains the --include-unknown hint' {
        $result = [PSCustomObject]@{
            ExitCode = -1978335189
            Output   = 'This package''s version number cannot be determined. To upgrade it anyway, add the argument --include-unknown to your previous command.'
        }
        Test-WingetUnknownVersion -Result $result | Should -Be $true
    }

    It 'returns $true for the Italian localized hint' {
        $result = [PSCustomObject]@{
            ExitCode = -1978335189
            Output   = 'Non e possibile determinare il numero di versione di questo pacchetto. Per aggiornarlo comunque, aggiungere l''argomento --include-unknown al comando precedente.'
        }
        Test-WingetUnknownVersion -Result $result | Should -Be $true
    }

    It 'returns $false when the output has no --include-unknown hint' {
        $result = [PSCustomObject]@{
            ExitCode = 0
            Output   = 'Successfully installed.'
        }
        Test-WingetUnknownVersion -Result $result | Should -Be $false
    }

    It 'returns $false when the output is empty' {
        $result = [PSCustomObject]@{
            ExitCode = -1978335189
            Output   = ''
        }
        Test-WingetUnknownVersion -Result $result | Should -Be $false
    }

    It 'returns $false when Output is $null' {
        $result = [PSCustomObject]@{
            ExitCode = -1978335189
            Output   = $null
        }
        Test-WingetUnknownVersion -Result $result | Should -Be $false
    }
}