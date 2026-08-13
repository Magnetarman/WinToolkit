#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Unit tests for the shared helper functions defined in 80-Module.Common.ps1
    and 10-Module.Logging.ps1.

    The module fragments are dot-sourced in BeforeAll so the same function
    objects the pipeline will concatenate are exercised here.
#>

BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\start-modules')
    foreach ($file in (Get-ChildItem -Path $moduleRoot -Filter '*.ps1' | Sort-Object Name)) {
        # The Main skeleton auto-invokes Invoke-WinToolkitSetup at load time
        # (it owns the script entry point), which requires an interactive
        # console. Unit tests dot-source every fragment except Main.
        if ($file.Name -eq '90-Skeleton.Main.ps1') { continue }
        . $file.FullName
    }

    # Logging helpers used by the common helpers must not crash when no log
    # file is configured yet.
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
    It 'centra correttamente una stringa più corta della larghezza data' {
        $centered = Format-CenteredText -Text 'OK' -Width 10
        $centered | Should -Match '^\s+OK'
        $centered.Length | Should -BeLessOrEqual 10
        $centered.Trim() | Should -Be 'OK'
    }

    It 'non aggiunge padding quando il testo riempie la larghezza' {
        Format-CenteredText -Text '1234567890' -Width 10 | Should -Be '1234567890'
    }
}

Describe 'Test-CommandExists' {
    It 'ritorna $true per un comando esistente (Get-Command stesso)' {
        Test-CommandExists -Name 'Get-Command' | Should -BeTrue
    }

    It 'ritorna $false per un comando inesistente' {
        Test-CommandExists -Name 'ComandoCheNonEsisteXYZ' | Should -BeFalse
    }
}

Describe 'Wait-Until' {
    It 'esce subito se la condizione è già vera' {
        (Measure-Command { Wait-Until -Condition { $true } -TimeoutSeconds 5 }).TotalSeconds | Should -BeLessThan 1
    }

    It 'ritorna $false allo scadere del timeout se la condizione resta falsa' {
        Wait-Until -Condition { $false } -TimeoutSeconds 1 -IntervalMs 200 | Should -BeFalse
    }
}

Describe 'Invoke-ExternalCommand — timeout (§2.3, §3.2)' {
    It 'termina il processo e ritorna TimedOut=$true se supera il timeout dichiarato' {
        $result = Invoke-ExternalCommand -FilePath 'powershell' -ArgumentList @('-Command', 'Start-Sleep 10') -TimeoutSeconds 1
        $result.TimedOut | Should -BeTrue
        $result.ExitCode | Should -Be -2
    }

    It 'ritorna Accepted=$true per un comando che termina con exit 0' {
        $result = Invoke-ExternalCommand -FilePath 'cmd.exe' -ArgumentList @('/c', 'exit 0') -TimeoutSeconds 10
        $result.TimedOut   | Should -BeFalse
        $result.Accepted  | Should -BeTrue
        $result.ExitCode  | Should -Be 0
    }

    It 'onora AcceptedExitCodes personalizzati (es. 3010)' {
        $result = Invoke-ExternalCommand -FilePath 'cmd.exe' -ArgumentList @('/c', 'exit 3010') -TimeoutSeconds 10 -AcceptedExitCodes @(0, 3010)
        $result.Accepted | Should -BeTrue
    }
}

Describe 'Test-PathInEnvironment' {
    It 'rileva un path già presente nel PATH utente (case-sensitive, match esatto)' {
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

    It 'ritorna $false per un path non presente' {
        Test-PathInEnvironment -PathToCheck 'C:\PercorsoInesistenteXYZ' -Scope 'User' | Should -BeFalse
    }
}

Describe 'Add-SetupResult / Write-SetupSummary (§2.8, §4.1)' {
    BeforeEach {
        $script:SetupResults = @()
    }

    It 'registra uno step riuscito senza modifiche come Succeeded' {
        Add-SetupResult -Name 'StepA' -Success $true -Changed $false
        $script:SetupResults[0].Status | Should -Be 'Succeeded'
    }

    It 'registra uno step riuscito con modifiche come Changed' {
        Add-SetupResult -Name 'StepB' -Success $true -Changed $true
        $script:SetupResults[0].Status | Should -Be 'Changed'
    }

    It 'Write-SetupSummary ritorna 0 quando tutto ha successo' {
        Add-SetupResult -Name 'StepA' -Success $true
        Add-SetupResult -Name 'StepB' -Success $true -Changed $true
        Write-SetupSummary | Should -Be 0
    }

    It 'Write-SetupSummary ritorna 1 in presenza di un fallimento bloccante' {
        Add-SetupResult -Name 'StepA' -Success $true
        Add-SetupResult -Name 'StepFail' -Success $false -Blocking $true -Message 'boom'
        Write-SetupSummary | Should -Be 1
    }

    It 'Write-SetupSummary ritorna 2 in presenza di un fallimento non bloccante' {
        Add-SetupResult -Name 'StepA' -Success $true
        Add-SetupResult -Name 'StepWarn' -Success $false -Blocking $false -Message 'warn'
        Write-SetupSummary | Should -Be 2
    }
}
