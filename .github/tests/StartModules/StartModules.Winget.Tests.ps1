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
    # Point localization at the REPOSITORY copy, not the per-user cache in
    # %LOCALAPPDATA%: that cache is whatever a previous run downloaded, so a newly
    # added key resolves to "[MISSING TRANSLATION: ...]" and the suite keeps
    # passing while the string that actually ships is never exercised. Reading the
    # repository files makes the suites assert the shipped strings.
    $script:AppConfig.Paths.Languages = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\languages')).Path
    Initialize-SourceTextLocalization -LanguageCode 'en-US'
}

Describe 'Initialize-Winget — recovery ladder (§3.1)' {

    BeforeEach {
        # A healthy WinGet: the ladder must stop at the first probe.
        Mock Repair-WingetMsStoreSource { return $true }
        Mock Install-WingetCore { return $true }
        Mock Repair-WingetDatabase { return $true }
        Mock Reset-WingetSources {}
        # The forced package reinstall is a REAL system operation (AppX reset, module
        # install, process kill). It MUST be stubbed here: without it the unit test
        # would reset the App Installer package and touch the PowerShell profile of
        # the machine running the suite.
        Mock Confirm-ToolkitInteractiveAction { return $false }
        Mock Reinstall-WingetForced { return New-StepResult -Success $true -Message 'stubbed' }
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

    It 'falls back to the forced package reinstall when the core install did not help' {
        # The ladder probes health THREE times before the forced reinstall (initial,
        # after the core install, after the database repair), so probes 1..3 must fail
        # and only the fourth one - taken after the forced repair - succeeds.
        $script:probe = 0
        Mock Get-WingetHealth {
            $script:probe++
            if ($script:probe -le 3) { return [pscustomobject]@{ Present = $true; Runs = $false; Version = $null; Reachable = $false } }
            return [pscustomobject]@{ Present = $true; Runs = $true; Version = '1.29'; Reachable = $true }
        }

        $result = Initialize-Winget
        Should -Invoke Reinstall-WingetForced -Times 1
        $result.Success | Should -BeTrue
    }

    It 'never reaches the forced reinstall once the health probe passes' {
        Mock Get-WingetHealth { [pscustomobject]@{ Present = $true; Runs = $true; Version = '1.29'; Reachable = $true } }
        $null = Initialize-Winget
        Should -Invoke Reinstall-WingetForced -Times 0
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

Describe 'Every translation key used by the fragments exists' {

    It 'resolves without the [MISSING TRANSLATION] fallback' {
        # Reads the repository languages/ (see BeforeAll), so a key added to the
        # code but forgotten in the .psd1 files fails HERE instead of showing an
        # English placeholder to the user at run time.
        $keys = [regex]::Matches(
            (Get-ChildItem (Join-Path $moduleRoot '*.ps1') | Get-Content -Raw) -join "`n",
            "Get-SourceTextLoc\s+(?:'([^']+)'|`"([^`"]+)`")") |
            ForEach-Object { if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value } } |
            Where-Object { $_ -and $_ -notmatch '\$' } |   # skip dynamic keys like "summary.$($_.ToLowerInvariant())"
            Sort-Object -Unique

        $keys.Count | Should -BeGreaterThan 50
        $missing = @($keys | Where-Object { (Get-SourceTextLoc $_) -match '\[MISSING TRANSLATION' })
        ($missing -join ', ') | Should -BeNullOrEmpty
    }
}

Describe 'Reinstall-WingetForced — forced repair of the two WinGet packages' {

    BeforeEach {
        $script:State.LogFile = $null
        Mock Write-StyledMessage {}
        # Every system-touching call is stubbed: this suite must never reset an
        # AppX package, download anything, or install a module on the test machine.
        Mock Test-WingetCompatibility { return $true }
        Mock Invoke-ForceCloseWinget {}
        Mock Reset-AppInstallerPackage {}
        Mock Set-WingetPathPermissions {}
        Mock Update-EnvironmentPath {}
        Mock Invalidate-WingetVersionCache {}
        Mock Initialize-Directory { param($Path) $Path }
        Mock Install-PackageProvider {}
        Mock Install-Module {}
        Mock Import-Module {}
        Mock Reset-WingetSources {}
        Mock Get-WingetHealth { [pscustomobject]@{ Present = $true; Runs = $true; Version = '1.29'; Reachable = $true } }
    }

    It 'repairs the App Installer without touching the module when not confirmed' {
        Mock Get-AppxPackage { return [pscustomobject]@{ Name = 'Microsoft.DesktopAppInstaller' } }
        $result = Reinstall-WingetForced
        $result.Success | Should -BeTrue
        Should -Invoke Reset-AppInstallerPackage -Times 1
        Should -Invoke Install-Module -Times 0 -Because 'a module install needs explicit confirmation'
        $result.Message | Should -Match 'not confirmed'
    }

    It 'installs the module when the confirmation is given' {
        Mock Get-AppxPackage { return [pscustomobject]@{ Name = 'Microsoft.DesktopAppInstaller' } }
        $result = Reinstall-WingetForced -ConfirmModuleInstall
        $result.Success | Should -BeTrue
        Should -Invoke Install-PackageProvider -Times 1
        Should -Invoke Install-Module -Times 1
    }

    It 'never installs the module when -SkipModule is used' {
        Mock Get-AppxPackage { return [pscustomobject]@{ Name = 'Microsoft.DesktopAppInstaller' } }
        $null = Reinstall-WingetForced -ConfirmModuleInstall -SkipModule
        Should -Invoke Install-Module -Times 0
    }

    It 'redownloads the bundle when the App Installer package is missing' {
        Mock Get-AppxPackage { return $null }
        Mock Invoke-DownloadFile { return $true }
        Mock Start-AppxSilentProcess { return $true }
        $null = Reinstall-WingetForced
        Should -Invoke Invoke-DownloadFile -Times 1
        Should -Invoke Start-AppxSilentProcess -Times 1
    }

    It 'redownloads the bundle even when the package is present, with -Force' {
        Mock Get-AppxPackage { return [pscustomobject]@{ Name = 'Microsoft.DesktopAppInstaller' } }
        Mock Invoke-DownloadFile { return $true }
        Mock Start-AppxSilentProcess { return $true }
        $null = Reinstall-WingetForced -Force
        Should -Invoke Start-AppxSilentProcess -Times 1
    }

    It 'does not throw when the App Installer repair fails' {
        Mock Get-AppxPackage { return $null }
        Mock Reset-AppInstallerPackage { throw 'Appx reset failed' }
        Mock Get-WingetHealth { [pscustomobject]@{ Present = $false; Runs = $false; Version = $null; Reachable = $false } }
        { Reinstall-WingetForced } | Should -Not -Throw
    }

    It 'reports failure when WinGet is still unusable and nothing was repaired' {
        Mock Get-AppxPackage { return $null }
        Mock Invoke-DownloadFile { return $false }
        Mock Get-WingetHealth { [pscustomobject]@{ Present = $false; Runs = $false; Version = $null; Reachable = $false } }
        (Reinstall-WingetForced).Success | Should -BeFalse
    }

    It 'refuses to run on an unsupported Windows build' {
        Mock Test-WingetCompatibility { return $false }
        $result = Reinstall-WingetForced
        $result.Success | Should -BeFalse
        Should -Invoke Invoke-ForceCloseWinget -Times 0
    }
}

Describe 'Confirm-ToolkitInteractiveAction — gated confirmations' {

    BeforeEach { $script:State.LogFile = $null }

    It 'returns $false without prompting in a non-interactive session' {
        # Pester runs redirected: Read-Host must never be reached.
        Mock Read-Host { throw 'must not be called' }
        Confirm-ToolkitInteractiveAction -Key 'uiText.confirmForcedModuleInstall0' | Should -BeFalse
    }

    It 'accepts an explicit yes' {
        Confirm-ToolkitInteractiveAction -Key 'uiText.confirmForcedModuleInstall0' -Answer 'Y' | Should -BeTrue
    }

    It 'accepts the Italian shorthand' {
        Confirm-ToolkitInteractiveAction -Key 'uiText.confirmForcedModuleInstall0' -Answer 'si' | Should -BeTrue
    }

    It 'treats an empty answer as a no' {
        Confirm-ToolkitInteractiveAction -Key 'uiText.confirmForcedModuleInstall0' -Answer '' | Should -BeFalse
    }

    It 'treats an unrecognized answer as a no' {
        Confirm-ToolkitInteractiveAction -Key 'uiText.confirmForcedModuleInstall0' -Answer 'maybe' | Should -BeFalse
    }

    It 'returns $false when the prompt itself fails' {
        Mock Read-Host { throw 'no console' }
        { Confirm-ToolkitInteractiveAction -Key 'uiText.confirmForcedModuleInstall0' } | Should -Not -Throw
    }
}

Describe 'Test-WingetCompatibility — minimum build (§2.5)' {

    It 'enforces the minimum threshold 17763 (Windows 10 1809) in the source' {
        $source = Get-Content -Raw (Join-Path $moduleRoot '40-Module.Winget.ps1')
        $source | Should -Match '\$build -lt 17763'
    }

    It 'enforces the minimum threshold 17763 (Windows 10 1809) in the source' {
        $source = Get-Content -Raw (Join-Path $moduleRoot '40-Module.Winget.ps1')
        $source | Should -Match '\$build -lt 17763'
    }

    It 'returns $true on the current build (>= 17763)' {
        Mock Write-StyledMessage {}
        Test-WingetCompatibility | Should -BeTrue
    }
}
