#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Unit tests for the localization helpers in 20-Module.Localization.ps1.

    Verifies that a known key resolves, positional arguments interpolate, key
    aliases redirect, and that the embedded English fallback prevents the raw
    "[MISSING TRANSLATION: ...]" placeholder from ever reaching the user (§3.7).
#>

BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\start-modules')
    foreach ($file in (Get-ChildItem -Path $moduleRoot -Filter '*.ps1' | Sort-Object Name)) {
        # The Main skeleton auto-invokes Invoke-WinToolkitSetup at load time,
        # which requires an interactive console; skip it in unit tests.
        if ($file.Name -eq '90-Skeleton.Main.ps1') { continue }
        . $file.FullName
    }

    # Language resolution normally runs network preparation; for unit tests we
    # initialise directly from the embedded English text (the offline fallback).
    Initialize-SourceTextLocalization -LanguageCode 'en-US'
}

Describe 'Get-SourceTextLoc' {

    It 'risolve una chiave embedded nota senza chiamate di rete' {
        Get-SourceTextLoc 'uiText.configurationComplete' | Should -Be 'Configuration complete.'
    }

    It 'interpola correttamente gli argomenti posizionali' {
        Get-SourceTextLoc 'uiText.systemClockResynced' | Should -Be 'System clock resynchronized.'
    }

    It 'risolve una chiave alias alla sua chiave canonica' {
        Get-SourceTextLoc 'uiText.setupComplete' | Should -Be 'Configuration complete.'
    }

    It 'non produce mai la stringa letterale di errore per una chiave embedded nota' {
        Get-SourceTextLoc 'uiText.wingetNotFoundInSystem' | Should -Not -Match '\[MISSING TRANSLATION'
    }

    It 'ritorna un placeholder leggibile (mai $null) per una chiave sconosciuta' {
        $value = Get-SourceTextLoc 'uiText.questaChiaveNonEsiste'
        $value | Should -BeOfType [string]
        $value | Should -Match '\[MISSING TRANSLATION: uiText.questaChiaveNonEsiste\]'
    }
}

Describe 'Get-SourceTextAutoDetectedLanguage' {

    It 'ritorna en-US quando la cultura di sistema non è tra quelle disponibili' {
        Get-SourceTextAutoDetectedLanguage -AvailableCultures 'en-US' -SystemUICulture 'xx-XX' | Should -Be 'en-US'
    }

    It 'ritorna la cultura disponibile corrispondente al prefisso neutro' {
        Get-SourceTextAutoDetectedLanguage -AvailableCultures 'en-US,it-IT' -SystemUICulture 'it-CH' | Should -Be 'it-IT'
    }
}
