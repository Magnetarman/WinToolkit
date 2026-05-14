#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Unit test per il modulo GamingToolkit.
.NOTES
    Strategia: dot-source del template (-ImportOnly) per il framework,
    dot-source di tool/GamingToolkit.ps1 per la funzione sotto test.
    winget e tutti i comandi di sistema vengono mockati.
#>

BeforeAll {
    $script:TemplatePath = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\WinToolkit-template.ps1')
    $script:ToolPath     = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\tool\GamingToolkit.ps1')

    . $script:TemplatePath -ImportOnly
    . $script:ToolPath

    Mock Start-ToolkitSession { }
    Mock Start-ToolkitLog     { }
    Mock Write-StyledMessage  { }
    Mock Read-ValidatedChoice { return 0 }
    Mock Read-Host            { throw "Read-Host non ammesso in CI" }
}

# =============================================================================
# Firma della funzione
# =============================================================================
Describe 'GamingToolkit — Firma' {

    It 'La funzione GamingToolkit deve essere disponibile' {
        Get-Command GamingToolkit -ErrorAction SilentlyContinue | Should -Not -BeNull
    }

    It 'Deve esporre il parametro -CountdownSeconds' {
        (Get-Command GamingToolkit).Parameters.ContainsKey('CountdownSeconds') | Should -Be $true
    }

    It 'Deve esporre il parametro -SuppressIndividualReboot' {
        (Get-Command GamingToolkit).Parameters.ContainsKey('SuppressIndividualReboot') | Should -Be $true
    }

    It '-CountdownSeconds deve avere valore di default 30' {
        $default = (Get-Command GamingToolkit).Parameters['CountdownSeconds'].DefaultValue
        $default | Should -Be 30
    }
}

# =============================================================================
# Integrazione WinGet — verifica sorgente
# =============================================================================
Describe 'GamingToolkit — Integrazione WinGet' {

    It 'Il modulo deve usare winget per le installazioni' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'winget'
    }

    It 'Il modulo deve includere una funzione di verifica disponibilità pacchetto' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'Test-WingetPackage'
    }

    It 'Il modulo deve gestire errori di installazione WinGet' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'catch'
    }
}
