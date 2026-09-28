# WinToolkit CI/CD V4.1.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
Unit tests for localization helpers in 20-Module.Localization.ps1.
Verifies key resolution, positional interpolation, alias redirection, and the
embedded English fallback (prevents raw "[MISSING TRANSLATION: ...]" reaching the user, §3.7).
#>

BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\start-modules')
    foreach ($file in (Get-ChildItem -Path $moduleRoot -Filter '*.ps1' | Sort-Object Name)) {
        # 90-Skeleton.Main.ps1 auto-invokes the interactive entry point; skip it
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

    # Init directly from embedded English (offline fallback)
    Initialize-SourceTextLocalization -LanguageCode 'en-US'
}

Describe 'Localization key sets stay aligned across languages (S-5)' {

    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
        $script:EnFile = Join-Path $repoRoot 'languages\en-US\WinToolkit.psd1'
        $script:ItFile = Join-Path $repoRoot 'languages\it-IT\WinToolkit.psd1'
        $script:EnKeys = @((Get-Content $script:EnFile -Raw) -split "`r?`n" |
            Where-Object { $_ -match '^([\w.\-]+)\s*=' } | ForEach-Object { $Matches[1] })
        $script:ItKeys = @((Get-Content $script:ItFile -Raw) -split "`r?`n" |
            Where-Object { $_ -match '^([\w.\-]+)\s*=' } | ForEach-Object { $Matches[1] })

        # Explicit list, not a language detector: a substring match on Italian words
        # also flags English keys that merely contain them (unigetUiRequireVerifi
        # cation, packetVerificationError01, ...StatusInEsecuzionePercent1).
        $script:RenamedKeys = @(
            'uiText.downloadIcon', 'uiText.clearingWingetCache',
            'uiText.retrievingLatestPowershellRelease', 'uiText.ohMyPoshThemeDownloaded',
            'uiText.checkingPowershell7', 'uiText.runningPackageManagerRepair',
            'uiText.attemptingPackageManagerRepair',
            'uiText.attemptingWingetRepairViaPackageManager',
            'uiText.startingWingetInstallVerification',
            'uiText.downloadMsixBundleFromMicrosoft', 'uiText.downloadCoreScriptFromGitHub',
            'uiText.downloadAndInstallWingetBundle',
            'uiText.downloadWingetDependencies',
            'uiText.fallbackDownloadGitFromGitHub',
            'uiText.fallbackDownloadMsixBundleDirect',
            'uiText.attemptingNativeAppxInstallFromBundle',
            'uiText.downloadCompleted0', 'uiText.downloaded0', 'uiText.downloadFailed0',
            'uiText.download02', 'uiText.downloadCoreScriptFromGitHub',
            'uiText.startingDownloadProcess', 'uiText.startingWinToolkitSetup',
            'uiText.resettingMicrosoftStoreCache', 'uiText.windowsTerminalConfiguration'
        ) | Select-Object -Unique
    }

    It 'both language files exist and expose keys' {
        Test-Path $script:EnFile | Should -BeTrue
        Test-Path $script:ItFile | Should -BeTrue
        $script:EnKeys.Count | Should -BeGreaterThan 100
        $script:ItKeys.Count | Should -BeGreaterThan 100
    }

    It 'defines exactly the same key set in en-US and it-IT' {
        # A missing key is not cosmetic: Get-SourceTextLoc falls back to the
        # embedded English text, so an Italian user would silently read English.
        $missingInIt = @(Compare-Object $script:EnKeys $script:ItKeys |
                Where-Object SideIndicator -eq '<=' | ForEach-Object InputObject)
        $missingInEn = @(Compare-Object $script:EnKeys $script:ItKeys |
                Where-Object SideIndicator -eq '=>' | ForEach-Object InputObject)

        ($missingInIt -join ', ') | Should -BeNullOrEmpty -Because 'every en-US key must exist in it-IT'
        ($missingInEn -join ', ') | Should -BeNullOrEmpty -Because 'every it-IT key must exist in en-US'
    }

    It 'has no duplicate key inside a single file (ConvertFrom-StringData would fail)' {
        $dupEn = @($script:EnKeys | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
        $dupIt = @($script:ItKeys | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
        ($dupEn -join ', ') | Should -BeNullOrEmpty
        ($dupIt -join ', ') | Should -BeNullOrEmpty
    }

    It 'loads with the same mechanism the runtime uses (Import-LocalizedData)' {
        # Not Import-PowerShellDataFile: the file is a ConvertFrom-StringData
        # script, which that cmdlet cannot parse. Import-LocalizedData is what
        # Import-SourceTextLanguageFile actually calls.
        foreach ($culture in @('en-US', 'it-IT')) {
            $data = $null
            {
                Import-LocalizedData -BindingVariable data `
                    -BaseDirectory (Join-Path $PSScriptRoot '..\..\..\languages' $culture) `
                    -FileName 'WinToolkit.psd1' -UICulture $culture -ErrorAction Stop
            } | Should -Not -Throw
        }
    }

    It 'no longer defines the Italian-named keys replaced during S-5' {
        $stillThere = @($script:EnKeys | Where-Object { $script:RenamedKeys -contains $_ })
        ($stillThere -join ', ') | Should -BeNullOrEmpty -Because 'these keys were renamed to English'
    }

    It 'resolves a suffixed key through the numeric-suffix fallback' {
        # The convention is frozen by behaviour, not by renaming 350+ keys: a key
        # named `<stem><n>` resolves to the stem when the suffixed one is absent.
        Get-SourceTextLoc 'uiText.check0' | Should -Not -Match '\[MISSING TRANSLATION'
    }
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
        Get-SourceTextAutoDetectedLanguage -AvailableCultures @('en-US') -SystemUICulture 'xx-XX' | Should -Be 'en-US'
    }

    It 'returns the available culture matching the neutral prefix' {
        Get-SourceTextAutoDetectedLanguage -AvailableCultures @('en-US', 'it-IT') -SystemUICulture 'it-CH' | Should -Be 'it-IT'
    }

    It 'matches case-insensitively but returns the FOLDER name, not the lowercased system culture (B-14)' {
        # The previous implementation returned the lowercased system culture, so
        # 'it-it' was returned for a folder actually named 'it-IT'.
        Get-SourceTextAutoDetectedLanguage -AvailableCultures @('en-US', 'it-IT') -SystemUICulture 'it-it' | Should -Be 'it-IT'
    }
}

Describe 'Get-SourceTextLanguageDirectory' {

    It 'returns the configured cache, never a folder found in the working directory (B-10)' {
        Get-SourceTextLanguageDirectory | Should -Be $script:AppConfig.Paths.Languages
    }
}
