# WinToolkit CI/CD V4.2.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
Launcher contract and supported-configuration gate.

The defect this suite pins down: a standard account that elevated itself with
administrator credentials received every personalized setting - PowerShell
profile, Oh My Posh theme, Windows Terminal settings, desktop shortcut - in the
ADMINISTRATOR profile, and the log reported every step as successful. After the
reboot the machine looked untouched.

The launcher now refuses that configuration before touching anything, and
reports it on a dedicated result code.
#>

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    $moduleRoot = Join-Path $script:RepoRoot 'start-modules'
    foreach ($file in (Get-ChildItem -Path $moduleRoot -Filter '*.ps1' | Sort-Object Name)) {
        # Skip interactive entry point
        if ($file.Name -eq '90-Skeleton.Main.ps1') { continue }
        . $file.FullName
    }

    # The launcher is a script, not a module: its functions are extracted through
    # the AST so the gate logic can be unit tested without executing the launcher.
    $script:launcherPath = Join-Path $script:RepoRoot 'start.ps1'
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:launcherPath, [ref]$null, [ref]$parseErrors)
    $parseErrors | Should -BeNullOrEmpty
    $launcherFunctions = $ast.FindAll(
        { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
        $false)
    $launcherFunctions.Count | Should -BeGreaterThan 0
    . ([scriptblock]::Create(($launcherFunctions | ForEach-Object { $_.Extent.Text }) -join "`r`n"))

    $script:State.LogFile = $null
    if (-not (Test-Path Variable:Global:MsgStyles)) {
        $Global:MsgStyles = @{
            Success = @{ Icon = '[OK]';   Color = 'Green' }
            Warning = @{ Icon = '[WARN]'; Color = 'Yellow' }
            Error   = @{ Icon = '[ERR]';  Color = 'Red' }
            Info    = @{ Icon = '[INFO]'; Color = 'Cyan' }
        }
    }
    $script:AppConfig.Paths.Languages = (Resolve-Path (Join-Path $script:RepoRoot 'languages')).Path
    Initialize-SourceTextLocalization -LanguageCode 'en-US'
}

Describe 'Get-AccountShortName' {
    It 'strips the domain or host prefix' {
        Get-AccountShortName -AccountName 'HOST\User' | Should -Be 'User'
    }

    It 'leaves a bare name untouched' {
        Get-AccountShortName -AccountName 'User' | Should -Be 'User'
    }

    It 'keeps only the last segment of a deep prefix' {
        Get-AccountShortName -AccountName 'A\B\C' | Should -Be 'C'
    }

    It 'returns an empty string for an empty input' {
        Get-AccountShortName -AccountName '' | Should -Be ''
        Get-AccountShortName -AccountName $null | Should -Be ''
    }
}

Describe 'Get-InteractiveUserSupport' {
    It 'reports a complete context on the machine running the suite' {
        # No mocks: this is the reporting contract, whatever the verdict is here.
        $support = Get-InteractiveUserSupport
        $support.CurrentUser | Should -Not -BeNullOrEmpty
        $support.InteractiveUser | Should -Not -BeNullOrEmpty
        $support.InteractiveIsAdmin | Should -BeOfType [bool]
        $support.SameAccount | Should -BeOfType [bool]
        $support.Supported | Should -BeOfType [bool]
    }

    It 'names the reason when the configuration is not supported' {
        $support = Get-InteractiveUserSupport
        if ($support.Supported) {

Describe 'start.ps1 contract' {
    It 'parses and stays compatible with Windows PowerShell 5.1 (ASCII only)' {
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($script:launcherPath, [ref]$null, [ref]$parseErrors)
        $parseErrors.Count | Should -Be 0

        # The launcher runs under Windows PowerShell 5.1 before the elevation, so
        # a single non-ASCII byte can break the file it is embedded in.
        $bytes = [System.IO.File]::ReadAllBytes($script:launcherPath)
        @($bytes | Where-Object { $_ -gt 127 }).Count | Should -Be 0
    }

    It 'places the gate before the first side effect of the file' {
        $content = Get-Content -Raw -LiteralPath $script:launcherPath

        # Order is the whole point: on an unsupported machine the gate must run
        # before Defender is touched and before PowerShell 7 is installed.
        $gateIndex = $content.IndexOf('Write-InteractiveUserSupport -Support $support')
        $defenderIndex = $content.IndexOf("Request-DefenderPause`r`n")
        $gateIndex | Should -BeGreaterThan 0
        $defenderIndex | Should -BeGreaterThan $gateIndex
    }

    It 'exposes a dedicated result code for an unsupported interactive user' {
        $content = Get-Content -Raw -LiteralPath $script:launcherPath
        $content | Should -Match 'UnsupportedInteractiveUser\s*=\s*\d+'
        $content | Should -Match '\[WinToolkit\] result=\{0\} reason=\{1\}'
    }

    It 'keeps a version check for an already installed PowerShell 7' {
        $content = Get-Content -Raw -LiteralPath $script:launcherPath
        $content | Should -Match 'function\s+Sync-PowerShellVersion'
        $content | Should -Match "'upgrade',\s*'--id',\s*'Microsoft\.PowerShell'"

        # A PowerShell 7 that is merely present must not be accepted as final:
        # that is what left the "A new PowerShell stable release is available"
        # banner on every session.
        $content | Should -Not -Match 'if\s*\(-not\s+\$pwsh\)\s*\{\s*\$pwsh\s*=\s*Install-Pwsh\s*\}'
    }

    It 'prints the identity context and exits without installing (diagnostics)' {
        $output = & (Get-Process -Id $PID).Path -NoLogo -NoProfile -File $script:launcherPath -PrintContext 2>&1
        $LASTEXITCODE | Should -Be 0

        $text = ($output | Out-String)
        $text | Should -Match '\[WinToolkit\] Signed-in user\s*:'
        $text | Should -Match '\[WinToolkit\] Running as\s*:'
        $text | Should -Match '\[WinToolkit\] Supported\s*:'
        $text | Should -Match '\[WinToolkit\] result=\d+'
    }
}

            $support.Reason | Should -BeNullOrEmpty
        }
        else {
            $support.Reason | Should -BeIn @('NotLocalAdministrator', 'AccountMismatch')
        }
    }
}
