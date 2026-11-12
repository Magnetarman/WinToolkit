#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
Loads localization definitions without running toolkit startup or touching the real language cache.
Build checks write only to TestDrive and never rebuild repository artifacts.
#>

Describe 'Version-matched toolkit translations' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:LocalizationPath = Join-Path $script:RepoRoot 'wintoolkit-modules\10-Module.Localization.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:LocalizationPath, [ref]$null, [ref]$null)
        foreach ($name in @('Get-SourceTextLanguageDirectory', 'Import-SourceTextLanguageFile', 'Set-SourceTextLanguage', 'Get-SourceTextLoc')) {
            $definition = $ast.Find({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
            }, $true)
            . ([scriptblock]::Create($definition.Extent.Text))
        }
        $script:Catalogues = @{}
        foreach ($culture in @('en-US', 'it-IT')) {
            $data = $null
            Import-LocalizedData -BindingVariable data -BaseDirectory (Join-Path $script:RepoRoot 'languages') -FileName 'WinToolkit.psd1' -UICulture $culture
            $script:Catalogues[$culture] = $data
        }
        $script:SavedGlobals = @{}
        foreach ($name in @('SourceTextLanguage', 'SourceTextLanguageData', 'SourceTextDefaultLanguageData', 'SourceTextPreparedLanguagesDir', 'SourceTextKeyAliases', 'SourceTextEmbeddedLanguageData')) {
            $variable = Get-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
            $script:SavedGlobals[$name] = @{ Exists = $null -ne $variable; Value = if ($variable) { $variable.Value } else { $null } }
        }
    }

    BeforeEach {
        $script:FixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:SourceRoot = Join-Path $script:FixtureRoot 'source'
        $cacheRoot = Join-Path $script:FixtureRoot 'cache'
        foreach ($fixtureCulture in @('en-US', 'it-IT')) {
            $sourceCulture = Join-Path $script:SourceRoot "languages\$fixtureCulture"
            $cacheCulture = Join-Path $cacheRoot $fixtureCulture
            [void][IO.Directory]::CreateDirectory($sourceCulture)
            [void][IO.Directory]::CreateDirectory($cacheCulture)
            $path = Join-Path $script:RepoRoot "languages\$fixtureCulture\WinToolkit.psd1"
            Copy-Item -LiteralPath $path -Destination (Join-Path $sourceCulture 'WinToolkit.psd1')
            $stale = (Get-Content -LiteralPath $path -Raw) -replace '(?m)^toolText\.localAccount[^\r\n]*\r?\n', ''
            $stale = $stale -replace '(?m)^confirm\.profile\.warn1 = [^\r\n]*', 'confirm.profile.warn1 = Legacy profile-only warning'
            Set-Content -LiteralPath (Join-Path $cacheCulture 'WinToolkit.psd1') -Value $stale -Encoding UTF8
        }
        $Global:SourceTextPreparedLanguagesDir = $cacheRoot
        $Global:SourceTextEmbeddedLanguageData = @{}
        $Global:SourceTextLanguageData = $null
        $Global:SourceTextDefaultLanguageData = $null
        $Global:SourceTextKeyAliases = @{}
        Mock Get-Location { [pscustomobject]@{ Path = $script:SourceRoot } }
    }

    AfterAll {
        foreach ($name in $script:SavedGlobals.Keys) {
            $saved = $script:SavedGlobals[$name]
            if ($saved.Exists) { Set-Variable -Name $name -Scope Global -Value $saved.Value }
            else { Remove-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue }
        }
    }

    It 'uses bundled <Culture> messages when the prepared cache predates account cleanup' -ForEach @(
        @{ Culture = 'en-US' }, @{ Culture = 'it-IT' }
    ) {
        Set-SourceTextLanguage -LanguageCode $Culture

        Get-SourceTextLoc 'toolText.localAccountsSelectedForAutomaticRemoval0' -Args @(10) |
            Should -Be ([string]::Format($script:Catalogues[$Culture]['toolText.localAccountsSelectedForAutomaticRemoval0'], 10))
        Get-SourceTextLoc 'toolText.localAccountRemoved01' -Args @('test0', 'S-1-5-21-100-200-300-1011') |
            Should -Be ([string]::Format($script:Catalogues[$Culture]['toolText.localAccountRemoved01'], 'test0', 'S-1-5-21-100-200-300-1011'))
        Get-SourceTextLoc 'toolText.localAccountsRemoved0' -Args @(0) |
            Should -Be ([string]::Format($script:Catalogues[$Culture]['toolText.localAccountsRemoved0'], 0))
        Get-SourceTextLoc 'confirm.profile.warn1' | Should -Be $script:Catalogues[$Culture]['confirm.profile.warn1']
    }

    It 'uses embedded <Culture> messages for standalone scripts despite stale cached files' -ForEach @(
        @{ Culture = 'en-US' }, @{ Culture = 'it-IT' }
    ) {
        $Global:SourceTextEmbeddedLanguageData = $script:Catalogues
        Mock Get-Location { [pscustomobject]@{ Path = (Join-Path $script:FixtureRoot 'standalone') } }

        Set-SourceTextLanguage -LanguageCode $Culture

        Get-SourceTextLoc 'toolText.localAccountsRemoved0' -Args @(10) |
            Should -Be ([string]::Format($script:Catalogues[$Culture]['toolText.localAccountsRemoved0'], 10))
        Get-SourceTextLoc 'confirm.profile.warn1' | Should -Be $script:Catalogues[$Culture]['confirm.profile.warn1']
    }

    It 'preserves cached translations for cultures not bundled with the toolkit' {
        $cultureDir = Join-Path $Global:SourceTextPreparedLanguagesDir 'fr-FR'
        [void][IO.Directory]::CreateDirectory($cultureDir)
        Set-Content -LiteralPath (Join-Path $cultureDir 'WinToolkit.psd1') -Encoding UTF8 -Value @"
ConvertFrom-StringData @'
language.code = fr-FR
toolText.computer0 = Ordinateur : {0}
'@
"@

        Set-SourceTextLanguage -LanguageCode 'fr-FR'

        Get-SourceTextLoc 'toolText.computer0' -Args @('VM') | Should -Be 'Ordinateur : VM'
        Get-SourceTextLoc 'toolText.localAccountsRemoved0' -Args @(10) |
            Should -Be ([string]::Format($script:Catalogues['en-US']['toolText.localAccountsRemoved0'], 10))
    }

    It 'does not mutate the embedded catalogue when a loaded language table changes' {
        $Global:SourceTextEmbeddedLanguageData = $script:Catalogues

        Set-SourceTextLanguage -LanguageCode 'it-IT'
        $Global:SourceTextLanguageData['toolText.localAccountsRemoved0'] = 'Changed'

        $Global:SourceTextEmbeddedLanguageData['it-IT']['toolText.localAccountsRemoved0'] |
            Should -Be $script:Catalogues['it-IT']['toolText.localAccountsRemoved0']
        $Global:SourceTextDefaultLanguageData['toolText.localAccountsRemoved0'] |
            Should -Be $script:Catalogues['en-US']['toolText.localAccountsRemoved0']
    }

    It 'embeds matching catalogues in an isolated build with Minify=<Minify>' -ForEach @(
        @{ Minify = $false }, @{ Minify = $true }
    ) {
        $fixtureTools = Join-Path $script:SourceRoot 'tools'
        $fixtureModules = Join-Path $script:SourceRoot 'wintoolkit-modules'
        $fixtureScripts = Join-Path $script:SourceRoot '.github\scripts'
        foreach ($directory in @($fixtureTools, $fixtureModules, $fixtureScripts)) { [void][IO.Directory]::CreateDirectory($directory) }
        $fixtureCompiler = Join-Path $script:SourceRoot 'compiler.ps1'
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'compiler.ps1') -Destination $fixtureCompiler
        Copy-Item -LiteralPath $script:LocalizationPath -Destination (Join-Path $fixtureModules '10-Module.Localization.ps1')
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot '.github\scripts\Minify-Source.ps1') -Destination $fixtureScripts
        Set-Content -LiteralPath (Join-Path $fixtureModules '00-Fixture.ps1') -Value 'param([switch]$ImportOnly)'
        Set-Content -LiteralPath (Join-Path $fixtureModules '87-Fixture.ps1') -Value 'function Probe {}'
        Set-Content -LiteralPath (Join-Path $fixtureTools 'Probe.ps1') -Value @'
function Probe {
    param()
    Start-ToolkitSession
}
'@

        $buildLog = Join-Path $script:SourceRoot 'build.log'
        & $fixtureCompiler -Minify:$Minify 6>$buildLog
        if ($LASTEXITCODE -ne 0) { throw (Get-Content -LiteralPath $buildLog -Raw) }

        $LASTEXITCODE | Should -Be 0
        $outputPath = Join-Path $script:SourceRoot 'WinToolkit.ps1'
        $errors = $null
        $compiled = [System.Management.Automation.Language.Parser]::ParseFile($outputPath, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
        $assignment = $compiled.Find({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text -eq '$Global:SourceTextEmbeddedLanguageData'
        }, $true)
        $assignment | Should -Not -BeNullOrEmpty
        . ([scriptblock]::Create($assignment.Extent.Text))
        foreach ($culture in @('en-US', 'it-IT')) {
            $embedded = $Global:SourceTextEmbeddedLanguageData[$culture]
            $embedded.Count | Should -Be $script:Catalogues[$culture].Count
            foreach ($key in $script:Catalogues[$culture].Keys) {
                $embedded[$key] | Should -Be $script:Catalogues[$culture][$key]
            }
        }
    }
}
