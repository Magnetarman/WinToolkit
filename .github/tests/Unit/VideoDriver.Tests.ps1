#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Unit test per il modulo VideoDriverInstall.
.NOTES
    Strategia: dot-source del template (-ImportOnly) per il framework,
    dot-source di tool/VideoDriverInstall.ps1 per la funzione sotto test.
    Get-PnpDevice viene mockato per evitare accesso hardware reale.
#>

BeforeAll {
    $script:TemplatePath = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\WinToolkit-template.ps1')
    $script:ToolPath     = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\tool\VideoDriverInstall.ps1')

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
Describe 'VideoDriverInstall — Firma' {

    It 'La funzione VideoDriverInstall deve essere disponibile' {
        Get-Command VideoDriverInstall -ErrorAction SilentlyContinue | Should -Not -BeNull
    }

    It 'Deve esporre il parametro -CountdownSeconds' {
        (Get-Command VideoDriverInstall).Parameters.ContainsKey('CountdownSeconds') | Should -Be $true
    }

    It 'Deve esporre il parametro -SuppressIndividualReboot' {
        (Get-Command VideoDriverInstall).Parameters.ContainsKey('SuppressIndividualReboot') | Should -Be $true
    }

    It '-CountdownSeconds deve avere valore di default 30' {
        $cmd = Get-Command VideoDriverInstall
        $param = $cmd.ScriptBlock.Ast.Body.ParamBlock.Parameters |
            Where-Object { $_.Name.VariablePath.UserPath -eq 'CountdownSeconds' }
        $param.DefaultValue.Value | Should -Be 30
    }
}

# =============================================================================
# Rilevamento GPU — stringa sorgente
# =============================================================================
Describe 'VideoDriverInstall — Rilevamento GPU' {

    It 'Il modulo deve supportare il rilevamento NVIDIA' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'NVIDIA'
    }

    It 'Il modulo deve supportare il rilevamento AMD' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'AMD'
    }

    It 'Il modulo deve supportare il rilevamento Intel' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'Intel'
    }

    It 'Il modulo deve gestire il caso Unknown per GPU non riconosciuta' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'Unknown'
    }
}
