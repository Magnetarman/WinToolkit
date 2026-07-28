#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Integration test della pipeline di compilazione.
.NOTES
    Verifica che compiler.ps1, i sorgenti e Test-CompiledScript.ps1
    siano sintatticamente validi e coerenti tra loro.
    I test contrassegnati con -Tag 'Slow' eseguono la compilazione reale
    e vengono saltati nei run di CI rapidi (eseguiti solo nella pipeline build).
#>

BeforeAll {
    $script:RepoRoot       = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    $script:CompilerPath   = Join-Path $script:RepoRoot 'compiler.ps1'
    $script:TemplatePath   = Join-Path $script:RepoRoot 'WinToolkit-template.ps1'
    $script:ToolFolder     = Join-Path $script:RepoRoot 'tools'
    $script:TestScriptPath = Join-Path $script:RepoRoot '.github\scripts\Test-CompiledScript.ps1'
}

# =============================================================================
# Sintassi sorgenti
# =============================================================================
Describe 'Build Pipeline — Sintassi Sorgenti' {

    It 'compiler.ps1 deve avere sintassi PowerShell valida' {
        $code   = Get-Content -Raw -Path $script:CompilerPath
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'WinToolkit-template.ps1 deve avere sintassi PowerShell valida' {
        $code   = Get-Content -Raw -Path $script:TemplatePath
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'Test-CompiledScript.ps1 deve avere sintassi PowerShell valida' {
        $code   = Get-Content -Raw -Path $script:TestScriptPath
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'Tutti i file tools/*.ps1 devono avere sintassi PowerShell valida' -ForEach (
        Get-ChildItem -Path (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')) 'tools') -Filter '*.ps1' |
        ForEach-Object { @{ File = $_ } }
    ) {
        $code   = Get-Content -Raw -Path $File.FullName
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0 -Because "$($File.Name) deve essere sintatticamente valido"
    }
}

# =============================================================================
# Coerenza sorgenti
# =============================================================================
Describe 'Build Pipeline — Coerenza Sorgenti' {

    It 'Ogni file tools/*.ps1 deve dichiarare una funzione con il suo stesso nome' {
        $files = Get-ChildItem -Path $script:ToolFolder -Filter '*.ps1'
        $files.Count | Should -BeGreaterThan 0

        foreach ($file in $files) {
            $functionName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $source       = Get-Content -Raw -Path $file.FullName
            $source | Should -Match "(?i)function\s+$([regex]::Escape($functionName))" `
                -Because "$($file.Name) deve contenere la dichiarazione della funzione $functionName"
        }
    }

    It 'Il template deve contenere un placeholder per ogni file tools/*.ps1' {
        $templateContent = Get-Content -Raw -Path $script:TemplatePath
        $files = Get-ChildItem -Path $script:ToolFolder -Filter '*.ps1'

        foreach ($file in $files) {
            $functionName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $templateContent | Should -Match "function\s+$([regex]::Escape($functionName))\s*\{" `
                -Because "Il template deve avere un placeholder per $functionName"
        }
    }

    It 'compiler.ps1 deve dichiarare il parametro -Minify' {
        $code = Get-Content -Raw -Path $script:CompilerPath
        $code | Should -Match '\[switch\]\$Minify'
    }
}

# =============================================================================
# Compilazione End-to-End (Slow — richiede file sorgente completi)
# =============================================================================
Describe 'Build Pipeline — End-to-End' -Tag 'Slow' {

    It 'compiler.ps1 produce un output WinToolkit.ps1 valido' {
        $originalLocation = Get-Location
        Set-Location $script:RepoRoot
        try {
            & $script:CompilerPath
            $LASTEXITCODE | Should -Be 0
            $outputPath = Join-Path $script:RepoRoot 'WinToolkit.ps1'
            Test-Path $outputPath | Should -Be $true

            $outputSize = (Get-Item $outputPath).Length
            $outputSize | Should -BeGreaterThan 10240 -Because 'L output deve essere almeno 10 KB'

            $code   = Get-Content -Raw -Path $outputPath
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$errors)
            $errors.Count | Should -Be 0 -Because 'L output compilato deve essere sintatticamente valido'
        }
        finally {
            Set-Location $originalLocation
        }
    }
}
