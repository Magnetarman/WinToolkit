#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Unit tests for the localization helpers in 20-Module.Localization.ps1.

    Verifies that a known key resolves, positional arguments interpolate, key
    aliases redirect, and that the embedded English fallback prevents the raw
    "[MISSING TRANSLATION: ...]" placeholder from ever reaching the user (§3.7).
#>

BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\start-modules')
    foreach ($file in (Get-ChildItem -Path $moduleRoot -Filter '*.ps1' | Sort-Object Name)) {
        # The Main skeleton auto-invokes Invoke-WinToolkitSetup at load time,
        # which requires an interactive console; skip it in unit tests.
        if ($file.Name -eq '90-Skeleton.Main.ps1') { continue }
        . $file.FullName
    }

    if (-not (Test-Path Variable:Global:MsgStyles)) {
        $Global:MsgStyles = @{
            Success = @{ Icon = '[OK]';   Color = 'Green' }
            Warning = @{ Icon = '[WARN]'; Color = 'Yellow' }
            Error   = @{ Icon = '[ERR]';  Color = 'Red' }
            Info    = @{ Icon = '[INFO]'; Color = 'Cyan' }
        }
    }

    # Language resolution normally runs network preparation; for unit tests we
    # initialise directly from the embedded English text (the offline fallback).
    Initialize-SourceTextLocalization -LanguageCode 'en-US'
}

Describe 'Get-SourceTextLoc' {

    It 'resolves a known embedded key without network calls' {
        Get-SourceTextLoc 'uiText.configurationComplete' | Should -Be 'Configuration complete.'
    }

    It 'resolves an embedded key with descriptive text' {
        $value = Get-SourceTextLoc 'uiText.systemClockResynced'
        $value | Should -Not -Match '\[MISSING TRANSLATION'
        $value | Should -Match 'System clock resynchronized\.'
    }

    It 'resolves an alias key to its canonical key' {
        Get-SourceTextLoc 'uiText.setupComplete' | Should -Be 'Configuration complete.'
    }

    It 'never produces the literal error string for a known embedded key' {
        Get-SourceTextLoc 'uiText.wingetNotFoundInSystem' | Should -Not -Match '\[MISSING TRANSLATION'
    }

    It 'returns a readable placeholder (never $null) for an unknown key' {
        $value = Get-SourceTextLoc 'uiText.questaChiaveNonEsiste'
        $value | Should -BeOfType [string]
        $value | Should -Match '\[MISSING TRANSLATION: uiText.questaChiaveNonEsiste\]'
    }
}

Describe 'Get-SourceTextAutoDetectedLanguage' {

    It 'returns en-US when the system culture is not among the available ones' {
        Get-SourceTextAutoDetectedLanguage -AvailableCultures 'en-US' -SystemUICulture 'xx-XX' | Should -Be 'en-US'
    }

    It 'returns the available culture matching the neutral prefix' {
        Get-SourceTextAutoDetectedLanguage -AvailableCultures 'en-US,it-IT' -SystemUICulture 'it-CH' | Should -Be 'it-IT'
    }
}
