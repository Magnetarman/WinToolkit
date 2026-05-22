#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Unit tests per i moduli video driver dopo refactoring.
.DESCRIPTION
    Verifica che i nuovi script esistano, siano caricabili e che i riferimenti
    al vecchio script VideoDriverInstall siano stati rimossi.
#>

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    $script:ToolDir  = Join-Path $script:RepoRoot 'tool'

    $script:AutoScript = Join-Path $script:ToolDir 'AutoVideoDriverInstall.ps1'
    $script:ReScript   = Join-Path $script:ToolDir 'VideoDriverReinstall.ps1'
    $script:OldScript  = Join-Path $script:ToolDir 'VideoDriverInstall.ps1'
    $script:Template   = Join-Path $script:RepoRoot 'WinToolkit-template.ps1'
}

Describe 'Video Driver scripts refactor integrity' {
    It 'Nuovi script video driver devono esistere' {
        Test-Path $script:AutoScript | Should -BeTrue
        Test-Path $script:ReScript   | Should -BeTrue
    }

    It 'Vecchio script VideoDriverInstall.ps1 non deve esistere' {
        Test-Path $script:OldScript | Should -BeFalse
    }

    It 'AutoVideoDriverInstall.ps1 deve dichiarare la funzione corretta' {
        (Get-Content -Raw $script:AutoScript) | Should -Match 'function\s+AutoVideoDriverInstall\s*\{'
    }

    It 'VideoDriverReinstall.ps1 deve dichiarare la funzione corretta' {
        (Get-Content -Raw $script:ReScript) | Should -Match 'function\s+VideoDriverReinstall\s*\{'
    }

    It 'WinToolkit-template deve referenziare i nuovi tool video' {
        $content = Get-Content -Raw $script:Template
        $content | Should -Match 'function\s+AutoVideoDriverInstall\s*\{\s*\}'
        $content | Should -Match 'function\s+VideoDriverReinstall\s*\{\s*\}'
        $content | Should -Match "Name\s*=\s*'AutoVideoDriverInstall'"
        $content | Should -Match "Name\s*=\s*'VideoDriverReinstall'"
    }

    It 'WinToolkit-template non deve referenziare il vecchio VideoDriverInstall' {
        (Get-Content -Raw $script:Template) | Should -Not -Match 'VideoDriverInstall'
    }
}
