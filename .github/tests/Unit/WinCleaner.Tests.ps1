#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Unit test per il modulo WinCleaner.
.NOTES
    Strategia: dot-source del template (-ImportOnly) per il framework,
    dot-source di tool/WinCleaner.ps1 per la funzione sotto test.
    Tutte le operazioni di sistema vengono mockate.
#>

BeforeAll {
    $script:TemplatePath = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\WinToolkit-template.ps1')
    $script:ToolPath     = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\tool\WinCleaner.ps1')

    . $script:TemplatePath -ImportOnly
    . $script:ToolPath

    # Inibisce tutta l'interazione con il sistema e la console
    Mock Start-ToolkitSession { }
    Mock Start-ToolkitLog     { }
    Mock Write-StyledMessage  { }
    Mock Clear-ProgressLine   { }
    Mock Read-ValidatedChoice { return 0 }
    Mock Read-Host            { throw "Read-Host non ammesso in CI" }
}

# =============================================================================
# Firma della funzione
# =============================================================================
Describe 'WinCleaner — Firma' {

    It 'La funzione WinCleaner deve essere disponibile' {
        Get-Command WinCleaner -ErrorAction SilentlyContinue | Should -Not -BeNull
    }

    It 'Deve esporre il parametro -CountdownSeconds' {
        (Get-Command WinCleaner).Parameters.ContainsKey('CountdownSeconds') | Should -Be $true
    }

    It 'Deve esporre il parametro -SuppressIndividualReboot' {
        (Get-Command WinCleaner).Parameters.ContainsKey('SuppressIndividualReboot') | Should -Be $true
    }

    It '-CountdownSeconds deve avere ValidateRange [0, 300]' {
        $attr = (Get-Command WinCleaner).Parameters['CountdownSeconds'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
        $attr            | Should -Not -BeNull
        $attr.MinRange   | Should -Be 0
        $attr.MaxRange   | Should -Be 300
    }

    It '-SuppressIndividualReboot deve essere un parametro switch' {
        $param = (Get-Command WinCleaner).Parameters['SuppressIndividualReboot']
        $param.ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
    }
}

# =============================================================================
# VitalExclusions — protezione percorsi critici
# =============================================================================
Describe 'WinCleaner — VitalExclusions' {

    It 'Il percorso WinToolkit LocalAppData deve essere in VitalExclusions' {
        # Verifica che il sorgente includa il percorso di auto-protezione
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'LocalAppData.*WinToolkit'
    }
}
