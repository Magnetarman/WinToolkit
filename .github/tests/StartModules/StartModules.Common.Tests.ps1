# WinToolkit CI/CD V4.1.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
Unit tests for shared helpers in 80-Module.Common.ps1 and 10-Module.Logging.ps1.
Module fragments are dot-sourced in BeforeAll (same objects the pipeline concatenates).
#>

BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\start-modules')
    foreach ($file in (Get-ChildItem -Path $moduleRoot -Filter '*.ps1' | Sort-Object Name)) {
        # Skip interactive entry point
        if ($file.Name -eq '90-Skeleton.Main.ps1') { continue }
        . $file.FullName
    }

    # Allow no-op logging when no log file is configured
    $script:State.LogFile = $null
    if (-not (Test-Path Variable:Global:MsgStyles)) {
        $Global:MsgStyles = @{
            Success = @{ Icon = '[OK]';   Color = 'Green' }
            Warning = @{ Icon = '[WARN]'; Color = 'Yellow' }
            Error   = @{ Icon = '[ERR]';  Color = 'Red' }
            Info    = @{ Icon = '[INFO]'; Color = 'Cyan' }
        }
    }
    $script:AppConfig = $script:AppConfig
}

Describe 'Format-CenteredText' {
    It 'centers a string shorter than the given width' {
        $centered = Format-CenteredText -Text 'OK' -Width 10
        $centered | Should -Match '^\s+OK'
        $centered.Length | Should -BeLessOrEqual 10
        $centered.Trim() | Should -Be 'OK'
    }

    It 'adds no padding when the text fills the width' {
        Format-CenteredText -Text '1234567890' -Width 10 | Should -Be '1234567890'
    }
}

Describe 'Install-RemoteFile — profile/settings install policy (S-6)' {

    BeforeEach {
        $script:State.LogFile = $null
        $script:probeDir = Join-Path $env:TEMP ('wt-remote-' + [guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:probeDir -Force
        $script:probeUrl = 'https://example.invalid/probe.txt'
    }

    AfterEach {
        Remove-Item $script:probeDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Each test below declares its own Mock with the content inlined: a Mock built
    # inside a helper function does not see that helper's parameters, because Pester
    # invokes mocks in a different scope.

    It 'returns $false and writes nothing when the download fails' {
        Mock Invoke-DownloadFile { return $false }
        $dest = Join-Path $script:probeDir 'file.txt'
        Install-RemoteFile -Url $script:probeUrl -Destination $dest | Should -BeFalse
        Test-Path $dest | Should -BeFalse
    }

    It 'leaves the staged temp file behind never (cleanup always runs)' {
        Mock Invoke-DownloadFile { return $false }
        $before = @(Get-ChildItem $script:probeDir -File -ErrorAction SilentlyContinue).Count
        $null = Install-RemoteFile -Url $script:probeUrl -Destination (Join-Path $script:probeDir 'f.txt')
        @(Get-ChildItem $script:probeDir -File -ErrorAction SilentlyContinue).Count | Should -Be $before
    }

    # NOTE: each test declares its own Mock with the content inlined. A Mock created
    # inside a helper function does not see the helper's parameters, and Pester mocks
    # are invoked in a different scope, so $Content would be empty.
    # The mock also creates the parent folder, because in the real flow the temp
    # directory is created by the download itself.
    It 'installs the payload and returns $true on a successful download' {
        Mock Invoke-DownloadFile {
            $null = New-Item -Path (Split-Path $OutFile -Parent) -ItemType Directory -Force
            [IO.File]::WriteAllText($OutFile, 'new-content'); return $true
        }
        $dest = Join-Path $script:probeDir 'file.txt'
        Install-RemoteFile -Url $script:probeUrl -Destination $dest | Should -BeTrue
        [IO.File]::ReadAllText($dest) | Should -Be 'new-content'
    }

    It 'does not rewrite, and creates no backup, when the content is already identical' {
        # The previous code produced a .bak on EVERY run even when nothing changed.
        Mock Invoke-DownloadFile {
            $null = New-Item -Path (Split-Path $OutFile -Parent) -ItemType Directory -Force
            [IO.File]::WriteAllText($OutFile, 'same-content'); return $true
        }
        $dest = Join-Path $script:probeDir 'file.txt'
        [IO.File]::WriteAllText($dest, 'same-content')

        Install-RemoteFile -Url $script:probeUrl -Destination $dest -Backup | Should -BeTrue
        @(Get-ChildItem $script:probeDir -Filter 'file.txt.bak.*' -ErrorAction SilentlyContinue).Count |
            Should -Be 0 -Because 'an unchanged file must not produce a backup'
    }

    It 'keeps a backup of the previous content when the file actually changes' {
        Mock Invoke-DownloadFile {
            $null = New-Item -Path (Split-Path $OutFile -Parent) -ItemType Directory -Force
            [IO.File]::WriteAllText($OutFile, 'v2'); return $true
        }
        $dest = Join-Path $script:probeDir 'file.txt'
        [IO.File]::WriteAllText($dest, 'v1')

        Install-RemoteFile -Url $script:probeUrl -Destination $dest -Backup | Should -BeTrue
        [IO.File]::ReadAllText($dest) | Should -Be 'v2'

        $backups = @(Get-ChildItem $script:probeDir -Filter 'file.txt.bak.*' -ErrorAction SilentlyContinue)
        $backups.Count | Should -Be 1
        [IO.File]::ReadAllText($backups[0].FullName) | Should -Be 'v1'
    }

    It 'creates the destination directory when it does not exist yet' {
        Mock Invoke-DownloadFile {
            $null = New-Item -Path (Split-Path $OutFile -Parent) -ItemType Directory -Force
            [IO.File]::WriteAllText($OutFile, 'x'); return $true
        }
        $dest = Join-Path (Join-Path $script:probeDir 'deep\nested') 'file.txt'
        Install-RemoteFile -Url $script:probeUrl -Destination $dest | Should -BeTrue
        Test-Path $dest | Should -BeTrue
    }

    It 'rejects an installed file smaller than -MinimumBytes' {
        # The staged payload downloads fine but is too small once installed.
        Mock Invoke-DownloadFile {
            $null = New-Item -Path (Split-Path $OutFile -Parent) -ItemType Directory -Force
            [IO.File]::WriteAllText($OutFile, 'tiny'); return $true
        }
        $dest = Join-Path $script:probeDir 'small.bin'
        Install-RemoteFile -Url $script:probeUrl -Destination $dest -MinimumBytes 1024 | Should -BeFalse
    }
}

Describe 'Remove-ExpiredBackups — retention (S-6)' {

    BeforeEach {
        $script:probeDir = Join-Path $env:TEMP ('wt-bak-' + [guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:probeDir -Force
    }
    AfterEach { Remove-Item $script:probeDir -Recurse -Force -ErrorAction SilentlyContinue }

    It 'keeps the newest N backups and removes the rest' {
        $pattern = Join-Path $script:probeDir 'file.txt.bak.*'
        1..5 | ForEach-Object {
            $p = Join-Path $script:probeDir "file.txt.bak.2026090$_-000000"
            [IO.File]::WriteAllText($p, "v$_")
            (Get-Item $p).LastWriteTime = (Get-Date).AddMinutes($_)
        }
        Remove-ExpiredBackups -Path $pattern -Keep 3
        @(Get-ChildItem $script:probeDir -Filter 'file.txt.bak.*').Count | Should -Be 3
    }

    It 'is a no-op when fewer backups than the retention exist' {
        $pattern = Join-Path $script:probeDir 'file.txt.bak.*'
        [IO.File]::WriteAllText((Join-Path $script:probeDir 'file.txt.bak.1'), 'a')
        Remove-ExpiredBackups -Path $pattern -Keep 3
        @(Get-ChildItem $script:probeDir -Filter 'file.txt.bak.*').Count | Should -Be 1
    }
}

Describe 'Test-CommandExists' {
    It 'returns $true for an existing command (Get-Command itself)' {
        Test-CommandExists -Name 'Get-Command' | Should -BeTrue
    }

    It 'returns $false for a non-existing command' {
        Test-CommandExists -Name 'ComandoCheNonEsisteXYZ' | Should -BeFalse
    }
}

Describe 'Wait-Until' {
    It 'exits immediately when the condition is already true' {
        (Measure-Command { Wait-Until -Condition { $true } -TimeoutSeconds 5 }).TotalSeconds | Should -BeLessThan 1
    }

    It 'returns $false when the timeout expires and the condition stays false' {
        Wait-Until -Condition { $false } -TimeoutSeconds 1 -IntervalMs 200 | Should -BeFalse
    }
}

Describe 'Invoke-ExternalCommand — timeout (§2.3, §3.2)' {
    It 'terminates the process and returns TimedOut=$true when it exceeds the declared timeout' {
        $result = Invoke-ExternalCommand -FilePath 'powershell' -ArgumentList @('-Command', 'Start-Sleep 10') -TimeoutSeconds 1
        $result.TimedOut | Should -BeTrue
        $result.ExitCode | Should -Be -2
    }

    It 'returns Accepted=$true for a command exiting with code 0' {
        $result = Invoke-ExternalCommand -FilePath 'cmd.exe' -ArgumentList @('/c', 'exit 0') -TimeoutSeconds 10
        $result.TimedOut   | Should -BeFalse
        $result.Accepted  | Should -BeTrue
        $result.ExitCode  | Should -Be 0
    }

    It 'honours custom AcceptedExitCodes (e.g. 3010)' {
        $result = Invoke-ExternalCommand -FilePath 'cmd.exe' -ArgumentList @('/c', 'exit 3010') -TimeoutSeconds 10 -AcceptedExitCodes @(0, 3010)
        $result.Accepted | Should -BeTrue
    }
}

Describe 'Test-PathInEnvironment' {
    It 'detects a path already present in the user PATH (case-sensitive, exact match)' {
        $userPath = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::User)
        $probe = Join-Path $env:TEMP ('wtprobe_' + [guid]::NewGuid().ToString('N'))
        try {
            [Environment]::SetEnvironmentVariable('PATH', "$probe;$($userPath)", [EnvironmentVariableTarget]::User)
            Test-PathInEnvironment -PathToCheck $probe -Scope 'User' | Should -BeTrue
        }
        finally {
            [Environment]::SetEnvironmentVariable('PATH', $userPath, [EnvironmentVariableTarget]::User)
        }
    }

    It 'returns $false for a path that is not present' {
        Test-PathInEnvironment -PathToCheck 'C:\PercorsoInesistenteXYZ' -Scope 'User' | Should -BeFalse
    }
}

Describe 'Add-SetupResult / Write-SetupSummary (§2.8, §4.1)' {
    BeforeEach {
        $script:State.Results.Clear()
    }

    It 'records a successful step with no changes as Succeeded' {
        Add-SetupResult -Name 'StepA' -Success $true -Changed $false
        $script:State.Results[0].Status | Should -Be 'Succeeded'
    }

    It 'records a successful step with changes as Changed' {
        Add-SetupResult -Name 'StepB' -Success $true -Changed $true
        $script:State.Results[0].Status | Should -Be 'Changed'
    }

    It 'Write-SetupSummary returns 0 when everything succeeds' {
        Add-SetupResult -Name 'StepA' -Success $true
        Add-SetupResult -Name 'StepB' -Success $true -Changed $true
        Write-SetupSummary | Should -Be 0
    }

    It 'Write-SetupSummary returns 1 when a blocking failure occurred' {
        Add-SetupResult -Name 'StepA' -Success $true
        Add-SetupResult -Name 'StepFail' -Success $false -Blocking $true -Message 'boom'
        Write-SetupSummary | Should -Be 1
    }

    It 'Write-SetupSummary returns 2 when a non-blocking failure occurred' {
        Add-SetupResult -Name 'StepA' -Success $true
        Add-SetupResult -Name 'StepWarn' -Success $false -Blocking $false -Message 'warn'
        Write-SetupSummary | Should -Be 2
    }
}

Describe 'New-StepResult — the single step contract (T-02)' {

    It 'defaults to Succeeded with no change and no skip' {
        $r = New-StepResult -Success $true
        $r.Success | Should -BeTrue
        $r.Changed | Should -BeFalse
        $r.Skipped | Should -BeFalse
        $r.Blocking | Should -BeFalse
    }

    It 'carries the message, Changed and Skipped' {
        $r = New-StepResult -Success $false -Changed $true -Message 'm' -Skipped
        $r.Success | Should -BeFalse
        $r.Changed | Should -BeTrue
        $r.Skipped | Should -BeTrue
        $r.Message | Should -Be 'm'
    }
}

Describe 'Add-SetupResult — Result and Skipped forms (B-12, T-02)' {

    BeforeEach { $script:State.Results.Clear() }

    It 'accepts a StepResult through -Result' {
        Add-SetupResult -Name 'Step' -Result (New-StepResult -Success $true -Changed $true -Message 'from step')
        $script:State.Results[0].Status | Should -Be 'Changed'
        $script:State.Results[0].Message | Should -Be 'from step'
    }

    It 'records an explicitly skipped step as Skipped, not Failed' {
        Add-SetupResult -Name 'Step' -Success $true -Skipped -Message 'n/a'
        $script:State.Results[0].Status | Should -Be 'Skipped'
    }

    It 'propagates Skipped carried by the StepResult' {
        Add-SetupResult -Name 'Step' -Result (New-StepResult -Success $true -Skipped)
        $script:State.Results[0].Status | Should -Be 'Skipped'
    }

    It 'a skipped step does not make Write-SetupSummary report a failure' {
        Add-SetupResult -Name 'StepA' -Success $true
        Add-SetupResult -Name 'Shortcut' -Success $true -Skipped -Message 'not applicable'
        Write-SetupSummary | Should -Be 0
    }
}

Describe 'Test-LocalRootedPath — path shape guard (T-12)' {

    It 'accepts a fully qualified local path and trims the trailing separator' {
        Test-LocalRootedPath -Path 'C:\Users\Me\Documents\' | Should -Be 'C:\Users\Me\Documents'
    }

    It 'rejects an empty path' {
        Test-LocalRootedPath -Path '' | Should -BeNullOrEmpty
    }

    It 'rejects a drive root' {
        Test-LocalRootedPath -Path 'C:\' | Should -BeNullOrEmpty
        Test-LocalRootedPath -Path 'C:' | Should -BeNullOrEmpty
    }

    It 'rejects a drive-relative path (the C:\PowerShell bug)' {
        Test-LocalRootedPath -Path '\PowerShell' | Should -BeNullOrEmpty
        Test-LocalRootedPath -Path '/PowerShell' | Should -BeNullOrEmpty
    }

    It 'rejects a relative path' {
        Test-LocalRootedPath -Path 'PowerShell' | Should -BeNullOrEmpty
    }
}

Describe 'Initialize-Directory — creates and verifies (T-12)' {

    It 'refuses a drive-relative path instead of creating C:\PowerShell' {
        { Initialize-Directory -Path '\PowerShell' } | Should -Throw
    }

    It 'creates a missing directory and returns it' {
        $probe = Join-Path $env:TEMP ('wt-initdir_' + [guid]::NewGuid().ToString('N'))
        try {
            $resolved = Initialize-Directory -Path $probe
            $resolved | Should -Be $probe
            Test-Path -LiteralPath $probe -PathType Container | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $probe -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Remove-PathQuietly — never throws (T-03)' {

    It 'removes existing paths and ignores missing ones' {
        $probe = Join-Path $env:TEMP ('wt-rmq_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $probe -Force | Out-Null
        { Remove-PathQuietly -Path @($probe, (Join-Path $probe 'does-not-exist')) } | Should -Not -Throw
        Test-Path -LiteralPath $probe | Should -BeFalse
    }
}
