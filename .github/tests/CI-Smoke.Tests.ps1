#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Minimal deterministic smoke tests used by the GitHub Actions pipeline.

    The complete suite remains in WinToolkit.Tests.ps1 for local validation.
#>

BeforeAll {
    $templatePath = Resolve-Path (Join-Path $PSScriptRoot '..\..\WinToolkit-template.ps1')
    . $templatePath -ImportOnly

    if (-not $Global:MsgStyles) {
        $Global:MsgStyles = @{
            Success  = @{ Icon = '[OK]';   Color = 'Green' }
            Warning  = @{ Icon = '[WARN]'; Color = 'Yellow' }
            Error    = @{ Icon = '[ERR]';  Color = 'Red' }
            Info     = @{ Icon = '[INFO]'; Color = 'Cyan' }
            Progress = @{ Icon = '[...]';  Color = 'Blue' }
            Question = @{ Icon = '[?]';    Color = 'Magenta' }
        }
    }

    $Global:CurrentLogFile = $null
    $Global:GuiSessionActive = $false
}

Describe 'WinToolkit CI smoke checks' {
    It 'loads the critical core functions' {
        (Get-Command Read-ValidatedChoice -ErrorAction Stop).CommandType |
            Should -Be 'Function'
        (Get-Command Invoke-ExternalCommandWithLog -ErrorAction Stop).CommandType |
            Should -Be 'Function'
        (Get-Command Write-StyledMessage -ErrorAction Stop).CommandType |
            Should -Be 'Function'
    }

    It 'accepts a valid RawInput choice without prompting' {
        Read-ValidatedChoice -ValidRange @(1, 2, 3) -RawInput '2' |
            Should -Be 2
    }

    It 'accepts multiple valid RawInput choices' {
        $choices = @(Read-ValidatedChoice -ValidRange @(1, 2, 3) -RawInput '1,3')

        $choices | Should -HaveCount 2
        $choices | Should -Contain 1
        $choices | Should -Contain 3
    }

    It 'does not throw for a styled message' {
        { Write-StyledMessage -Type Success -Text 'CI smoke test' } |
            Should -Not -Throw
    }

    It 'returns a successful result for an external command' {
        $arguments = @('/c', 'exit 0')
        $result = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments $arguments -TimeoutSeconds 10

        $result.Success | Should -BeTrue
        $result.ExitCode | Should -Be 0
        $result.TimedOut | Should -BeFalse
    }
}
