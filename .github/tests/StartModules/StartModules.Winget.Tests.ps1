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

Describe 'Test-DownloadedSignature / New-SignatureValidator (S-1)' {

    BeforeEach { $script:State.LogFile = $null }

    It 'accepts a Valid signature whose subject contains an expected signer' {
        Mock Get-AuthenticodeSignature {
            [pscustomobject]@{ Status = 'Valid'
                SignerCertificate = [pscustomobject]@{ Subject = 'CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond' } }
        }
        Test-DownloadedSignature -Path 'C:\x\vc_redist.x64.exe' -ExpectedSigners @('Microsoft Corporation') |
            Should -BeTrue
    }

    It 'rejects a Valid signature from an unexpected signer' {
        Mock Get-AuthenticodeSignature {
            [pscustomobject]@{ Status = 'Valid'
                SignerCertificate = [pscustomobject]@{ Subject = 'CN=Contoso Ltd' } }
        }
        Test-DownloadedSignature -Path 'C:\x\setup.exe' -ExpectedSigners @('Microsoft Corporation') |
            Should -BeFalse
    }

    It 'rejects a non-Valid status even for the expected signer' {
        Mock Get-AuthenticodeSignature {
            [pscustomobject]@{ Status = 'HashMismatch'
                SignerCertificate = [pscustomobject]@{ Subject = 'CN=Microsoft Corporation' } }
        }
        Test-DownloadedSignature -Path 'C:\x\a.exe' -ExpectedSigners @('Microsoft Corporation') | Should -BeFalse
    }

    It 'rejects when the signature cannot be read at all' {
        Mock Get-AuthenticodeSignature { throw 'no catalog' }
        Test-DownloadedSignature -Path 'C:\x\a.exe' -ExpectedSigners @('Microsoft Corporation') | Should -BeFalse
    }

    It 'builds a validator from the configured profile' {
        $validator = New-SignatureValidator -ProfileKey 'git'
        $validator | Should -BeOfType [scriptblock]
    }

    It 'throws for an unknown signature profile (a typo must not disable the check)' {
        { New-SignatureValidator -ProfileKey 'gitTypo' } | Should -Throw
    }

    It 'a blocking validator turns an invalid signature into a thrown error' {
        Mock Get-AuthenticodeSignature {
            [pscustomobject]@{ Status = 'NotSigned'; SignerCertificate = $null }
        }
        $validator = New-SignatureValidator -ProfileKey 'vcRedist' -BlockOnInvalid
        { & $validator 'C:\x\vc_redist.exe' } | Should -Throw
    }

    It 'a non-blocking validator only returns false, leaving the OS to decide' {
        Mock Get-AuthenticodeSignature {
            [pscustomobject]@{ Status = 'NotSigned'; SignerCertificate = $null }
        }
        $validator = New-SignatureValidator -ProfileKey 'wingetMsix'
        { & $validator 'C:\x\bundle.msixbundle' } | Should -Not -Throw
        (& $validator 'C:\x\bundle.msixbundle') | Should -BeFalse
    }

    It 'every signed profile declares at least one signer' {
        foreach ($key in @('vcRedist', 'git', 'wingetMsix', 'terminalMsix')) {
            @($script:AppConfig.DownloadSignatures[$key]).Count | Should -BeGreaterThan 0 -Because "$key must have an allow-list"
        }
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
