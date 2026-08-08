#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Tests for the WinGet/AppX module (40-Module.Winget.ps1).

    Repair-Winget is the consolidation entry point from §3.1: it must dispatch to
    exactly the implementation that matches the requested level, with no
    side-effecting calls to unrequested repair functions. Those implementations
    touch the real system, so they are mocked here.
#>

BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\start-modules')
    foreach ($file in (Get-ChildItem -Path $moduleRoot -Filter '*.ps1' | Sort-Object Name)) {
        # The Main skeleton auto-invokes Invoke-WinToolkitSetup at load time,
        # which requires an interactive console; skip it in unit tests.
        if ($file.Name -eq '90-Skeleton.Main.ps1') { continue }
        . $file.FullName
    }

    $script:CurrentLogFile = $null
    if (-not $Global:MsgStyles) {
        $Global:MsgStyles = @{
            Success = @{ Icon = '[OK]';   Color = 'Green' }
            Warning = @{ Icon = '[WARN]'; Color = 'Yellow' }
            Error   = @{ Icon = '[ERR]';  Color = 'Red' }
            Info    = @{ Icon = '[INFO]'; Color = 'Cyan' }
        }
    }
    Initialize-SourceTextLocalization -LanguageCode 'en-US'
}

Describe 'Repair-Winget — orchestratore livelli (§3.1)' {

    It 'SourceReset invoca solo Reset-WingetSources' {
        Mock Reset-WingetSources {}
        Mock Repair-WingetMsStoreSource {}
        Mock Repair-AppInstaller { return [pscustomobject]@{ Success = $true } }
        Mock Repair-WingetDatabase { return $true }
        Mock Install-WingetCore { return $true }
        Mock Install-WingetPackage { return $true }

        $result = Repair-Winget -Level SourceReset
        $result | Should -BeTrue
        Should -Invoke Reset-WingetSources -Times 1
        Should -Invoke Repair-WingetDatabase -Times 0
        Should -Invoke Install-WingetPackage -Times 0
    }

    It 'MsStoreCert invoca solo Repair-WingetMsStoreSource' {
        Mock Reset-WingetSources {}
        Mock Repair-WingetMsStoreSource {}
        Mock Repair-AppInstaller { return [pscustomobject]@{ Success = $true } }
        Mock Repair-WingetDatabase { return $true }
        Mock Install-WingetCore { return $true }
        Mock Install-WingetPackage { return $true }

        Repair-Winget -Level MsStoreCert
        Should -Invoke Repair-WingetMsStoreSource -Times 1
        Should -Invoke Reset-WingetSources -Times 0
    }

    It 'AppxReset delega a Repair-AppInstaller' {
        Mock Reset-WingetSources {}
        Mock Repair-WingetMsStoreSource {}
        Mock Repair-AppInstaller { return [pscustomobject]@{ Success = $true } }
        Mock Repair-WingetDatabase { return $true }
        Mock Install-WingetCore { return $true }
        Mock Install-WingetPackage { return $true }

        Repair-Winget -Level AppxReset
        Should -Invoke Repair-AppInstaller -Times 1
    }

    It 'solleva se il livello non è supportato' {
        Mock Reset-WingetSources {}
        { Repair-Winget -Level 'UnsupportedLevelXYZ' } | Should -Throw
    }
}

Describe 'Test-WingetCompatibility — build minimo (§2.5)' {

    It 'applica la soglia minima 17763 (Windows 10 1809) nel sorgente' {
        $source = Get-Content -Raw (Join-Path $moduleRoot '40-Module.Winget.ps1')
        $source | Should -Match '\$build -lt 17763'
    }

    It 'ritorna $true sulla build corrente (>= 17763)' {
        Mock Write-StyledMessage {}
        Test-WingetCompatibility | Should -BeTrue
    }
}
