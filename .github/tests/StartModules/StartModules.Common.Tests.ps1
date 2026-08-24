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
    $script:CurrentLogFile = $null
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
        $script:SetupResults = @()
    }

    It 'records a successful step with no changes as Succeeded' {
        Add-SetupResult -Name 'StepA' -Success $true -Changed $false
        $script:SetupResults[0].Status | Should -Be 'Succeeded'
    }

    It 'records a successful step with changes as Changed' {
        Add-SetupResult -Name 'StepB' -Success $true -Changed $true
        $script:SetupResults[0].Status | Should -Be 'Changed'
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
