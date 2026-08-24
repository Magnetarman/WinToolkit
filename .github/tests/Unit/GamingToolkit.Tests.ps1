#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
Unit test for the GamingToolkit module.
Strategy: dot-source template (-ImportOnly) for the framework,
dot-source tools/GamingToolkit.ps1 for the function under test.
winget and all system commands are mocked.
#>

BeforeAll {
    $script:TemplatePath = & (Join-Path $PSScriptRoot '..\..\scripts\New-WinToolkitCoreScript.ps1')
    $script:ToolPath     = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\tools\GamingToolkit.ps1')

    . $script:TemplatePath -ImportOnly
    . $script:ToolPath

    Mock Start-ToolkitSession { }
    Mock Start-ToolkitLog     { }
    Mock Write-StyledMessage  { }
    Mock Read-ValidatedChoice { return 0 }
    Mock Read-Host            { throw "Read-Host not allowed in CI" }
}

Describe 'GamingToolkit — Signature' {

    It 'The GamingToolkit function must be available' {
        Get-Command GamingToolkit -ErrorAction SilentlyContinue | Should -Not -BeNull
    }

    It 'Must expose the -CountdownSeconds parameter' {
        (Get-Command GamingToolkit).Parameters.ContainsKey('CountdownSeconds') | Should -Be $true
    }

    It 'Must expose the -SuppressIndividualReboot parameter' {
        (Get-Command GamingToolkit).Parameters.ContainsKey('SuppressIndividualReboot') | Should -Be $true
    }

    It '-CountdownSeconds must have a default value of 30' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match '\[int\]\$CountdownSeconds\s*=\s*30'
    }
}

Describe 'GamingToolkit — WinGet Integration' {

    It 'The module must use winget for installations' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'winget'
    }

    It 'The module must include a package availability check function' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'Test-WingetPackage'
    }

    It 'The module must handle WinGet installation errors' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'catch'
    }
}