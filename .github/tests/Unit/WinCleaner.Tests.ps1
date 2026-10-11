# WinToolkit CI/CD V4.2.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
Unit test for the WinCleaner module.
Strategy: dot-source template (-ImportOnly) for the framework,
dot-source tools/WinCleaner.ps1 for the function under test.
All system operations are mocked.
#>

BeforeAll {
    $script:TemplatePath = & (Join-Path $PSScriptRoot '..\..\scripts\New-WinToolkitCoreScript.ps1')
    $script:ToolPath     = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\tools\WinCleaner.ps1')

    . $script:TemplatePath -ImportOnly
    . $script:ToolPath

    # Prevent system and console interaction
    Mock Start-ToolkitSession { }
    Mock Start-ToolkitLog     { }
    Mock Write-StyledMessage  { }
    Mock Clear-ProgressLine   { }
    Mock Read-ValidatedChoice { return 0 }
    Mock Read-Host            { throw "Read-Host not allowed in CI" }
}

Describe 'WinCleaner — Signature' {

    It 'The WinCleaner function must be available' {
        Get-Command WinCleaner -ErrorAction SilentlyContinue | Should -Not -BeNull
    }

    It 'Must expose the -CountdownSeconds parameter' {
        (Get-Command WinCleaner).Parameters.ContainsKey('CountdownSeconds') | Should -Be $true
    }

    It 'Must expose the -SuppressIndividualReboot parameter' {
        (Get-Command WinCleaner).Parameters.ContainsKey('SuppressIndividualReboot') | Should -Be $true
    }

    It '-CountdownSeconds must have ValidateRange [0, 300]' {
        $attr = (Get-Command WinCleaner).Parameters['CountdownSeconds'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
        $attr            | Should -Not -BeNull
        $attr.MinRange   | Should -Be 0
        $attr.MaxRange   | Should -Be 300
    }

    It '-SuppressIndividualReboot must be a switch parameter' {
        $param = (Get-Command WinCleaner).Parameters['SuppressIndividualReboot']
        $param.ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
    }
}

Describe 'WinCleaner — VitalExclusions' {

    It 'The WinToolkit LocalAppData path must be in VitalExclusions' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'LocalAppData.*WinToolkit'
    }
}

Describe 'WinCleaner — Invoke-CommandAction displayName (regression for empty NameKey)' {

    It 'Resolves DisplayName via Get-SourceTextLoc only when NameKey is present' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match '\$displayName\s*=\s*if\s*\(\s*\$Rule\.NameKey\s*\)\s*\{'
        $source | Should -Match 'Get-SourceTextLoc\s+\$Rule\.NameKey\s*\}\s*else\s*\{\s*\$Rule\.Name\s*\}'
    }

    It 'Never calls Get-SourceTextLoc with a bare (unguarded) NameKey' {
        # Before the fix: "$displayName = Get-SourceTextLoc $Rule.NameKey" → throws
        # "Cannot bind argument to parameter 'Key' because it is an empty string"
        # when a Command rule omits NameKey (e.g. the inline cleanmgr rules).
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Not -Match '\$displayName\s*=\s*Get-SourceTextLoc\s+\$Rule\.NameKey\s*$'
    }

    It 'Inline CleanMgr Command rules still expose a Name for the NameKey fallback' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match "Name\s*=\s*'Running CleanMgr with /sagerun:65'"
        $source | Should -Match "Name\s*=\s*'Removing Windows\.old \(CleanMgr\)'"
    }
}

Describe 'WinCleaner — Get-LocalUserProfiles (regression for undefined function)' {

    It 'WinCleaner.ps1 must define a Get-LocalUserProfiles helper' {
        # WinCleaner per-user rules call Get-LocalUserProfiles; if undefined the cleaner
        # aborts with "Il termine 'Get-LocalUserProfiles' non è riconosciuto" right after
        # the Windows Update cache step.
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'function Get-LocalUserProfiles\s*\{'
    }

    It 'Get-LocalUserProfiles must delegate to the shared core helper' {
        $source = Get-Content -Path $script:ToolPath -Raw
        $source | Should -Match 'Get-SourceTextLocalUserProfiles'
    }
}
