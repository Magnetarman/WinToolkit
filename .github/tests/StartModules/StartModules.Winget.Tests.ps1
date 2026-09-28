# WinToolkit CI/CD V4.1.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
Tests for the WinGet/AppX module (40-Module.Winget.ps1).
The repair-level dispatcher (Repair-Winget + the WingetRepairLevel enum) is gone:
the recovery ladder lives in Initialize-Winget and the concrete repairs are named
directly. What is covered here is the behaviour that replaced it: the health
probe, the recovery ladder, the cached version flag and the "already installed"
exit codes. Every repair touches the real system, so it is mocked.
#>

BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\start-modules')
    foreach ($file in (Get-ChildItem -Path $moduleRoot -Filter '*.ps1' | Sort-Object Name)) {
        # 90-Skeleton.Main.ps1 auto-invokes the interactive entry point; skip it
        if ($file.Name -eq '90-Skeleton.Main.ps1') { continue }
        . $file.FullName
    }

    $script:State.LogFile = $null
    if (-not (Test-Path Variable:Global:MsgStyles)) {
        $Global:MsgStyles = @{
            Success = @{ Icon = '[OK]';   Color = 'Green' }
            Warning = @{ Icon = '[WARN]'; Color = 'Yellow' }
            Error   = @{ Icon = '[ERR]';  Color = 'Red' }
            Info    = @{ Icon = '[INFO]'; Color = 'Cyan' }
        }
    }
    Initialize-SourceTextLocalization -LanguageCode 'en-US'
}

Describe 'Initialize-Winget — recovery ladder (§3.1)' {

    BeforeEach {
        # A healthy WinGet: the ladder must stop at the first probe.
        Mock Repair-WingetMsStoreSource { return $true }
        Mock Install-WingetCore { return $true }
        Mock Repair-WingetDatabase { return $true }
        Mock Reset-WingetSources {}
    }

    It 'returns success without installing when the health probe already passes' {
        Mock Get-WingetHealth { [pscustomobject]@{ Present = $true; Runs = $true; Version = '1.29'; Reachable = $true } }

        $result = Initialize-Winget
        $result.Success | Should -BeTrue
        $result.Message | Should -Match '1\.29'
        Should -Invoke Install-WingetCore -Times 0
        Should -Invoke Repair-WingetDatabase -Times 0
    }

    It 'falls back to a core install, then resets the sources once' {
        # First probe fails, second succeeds.
        $script:probe = 0
        Mock Get-WingetHealth {
            $script:probe++
            if ($script:probe -eq 1) { return [pscustomobject]@{ Present = $true; Runs = $false; Version = $null; Reachable = $false } }
            return [pscustomobject]@{ Present = $true; Runs = $true; Version = '1.29'; Reachable = $true }
        }

        $result = Initialize-Winget
        $result.Success | Should -BeTrue
        $result.Changed | Should -BeTrue
        Should -Invoke Install-WingetCore -Times 1
        Should -Invoke Reset-WingetSources -Times 1
    }

    It 'returns failure when every recovery attempt leaves WinGet unusable' {
        Mock Get-WingetHealth { [pscustomobject]@{ Present = $true; Runs = $false; Version = $null; Reachable = $false } }

        $result = Initialize-Winget
        $result.Success | Should -BeFalse
        Should -Invoke Repair-WingetDatabase -Times 1
    }
}

Describe 'Reset-WingetSourcesOnce — one source reset per run' {

    BeforeEach { $script:State.SourcesReset = $false }

    It 'resets the sources on the first call' {
        Mock Reset-WingetSources {}
        Reset-WingetSourcesOnce
        Should -Invoke Reset-WingetSources -Times 1
        $script:State.SourcesReset | Should -BeTrue
    }

    It 'is a no-op on the following calls' {
        Mock Reset-WingetSources {}
        Reset-WingetSourcesOnce
        Reset-WingetSourcesOnce
        Reset-WingetSourcesOnce
        Should -Invoke Reset-WingetSources -Times 1
    }
}

Describe 'Test-WingetModernVersion — --disable-interactivity support (B-01)' {

    It 'accepts 1.4 and above' {
        Test-WingetModernVersion -VersionOutput 'v1.4.0' | Should -BeTrue
        Test-WingetModernVersion -VersionOutput 'v1.9.0' | Should -BeTrue
    }

    It 'rejects the builds older than 1.4' {
        Test-WingetModernVersion -VersionOutput 'v1.3.2691' | Should -BeFalse
        Test-WingetModernVersion -VersionOutput 'v1.0.0' | Should -BeFalse
    }

    It 'compares numerically, so a two-digit minor version is modern (the v1\.[4-9] regex bug)' {
        Test-WingetModernVersion -VersionOutput 'v1.10.0' | Should -BeTrue
        Test-WingetModernVersion -VersionOutput 'v1.11.0' | Should -BeTrue
        Test-WingetModernVersion -VersionOutput 'v1.12.0' | Should -BeTrue
    }

    It 'assumes a modern build when the version cannot be parsed' {
        Test-WingetModernVersion -VersionOutput 'unparsable' | Should -BeTrue
    }
}

Describe 'Test-WingetRpcFailure — App Installer RPC error (B-03)' {

    It 'detects 0x800706BA' {
        Test-WingetRpcFailure -Result ([pscustomobject]@{ ExitCode = $script:AppConfig.Winget.RpcFailureExitCode }) |
            Should -BeTrue
    }

    It 'ignores any other exit code' {
        Test-WingetRpcFailure -Result ([pscustomobject]@{ ExitCode = 0 }) | Should -BeFalse
        Test-WingetRpcFailure -Result ([pscustomobject]@{ ExitCode = -1978335135 }) | Should -BeFalse
    }
}

Describe 'Test-WingetCompatibility — minimum build (§2.5)' {

    It 'enforces the minimum threshold 17763 (Windows 10 1809) in the source' {
        $source = Get-Content -Raw (Join-Path $moduleRoot '40-Module.Winget.ps1')
        $source | Should -Match '\$build -lt 17763'
    }

    It 'returns $true on the current build (>= 17763)' {
        Mock Write-StyledMessage {}
        Test-WingetCompatibility | Should -BeTrue
    }
}
