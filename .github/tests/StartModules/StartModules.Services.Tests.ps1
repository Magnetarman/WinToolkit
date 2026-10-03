# WinToolkit CI/CD V4.2.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
Windows Update service scope: only the services in their STANDARD ACTIVE state
(running with the automatic startup type) are suspended and restored.

The defect this suite pins down: the restore re-applied the recorded state to
every service in the snapshot, including the ones it had never stopped. A
service the administrator had already stopped - and that the system started on
its own during the run - was therefore stopped again, and the refusal was
reported as "Windows Update services restore incomplete".

The Get-Service stub distinguishes the snapshot call (an array of names) from
the verification call (a single name), so the suspend path can be exercised
end to end without a stateful mock.
#>

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    $moduleRoot = Join-Path $script:RepoRoot 'start-modules'
    foreach ($file in (Get-ChildItem -Path $moduleRoot -Filter '*.ps1' | Sort-Object Name)) {
        # Skip interactive entry point
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
    $script:AppConfig.Paths.Languages = (Resolve-Path (Join-Path $script:RepoRoot 'languages')).Path
    Initialize-SourceTextLocalization -LanguageCode 'en-US'

    # Records what the code under test decided, in the same shape the script
    # uses for the services it manages.
    $global:Stopped = @()
    $global:Started = @()
    $global:StartupTypeWrites = @()
}

Describe 'Windows Update services - suspension scope' {
    BeforeEach {
        $script:StatusRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('wt-services-' + [guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:StatusRoot -Force
        $script:AppConfig.Paths.WinToolkitDir = $script:StatusRoot
        $script:State.LogFile = $null
        $global:Stopped = @()
        $global:Started = @()
        $global:StartupTypeWrites = @()

        Mock Stop-Service { $global:Stopped += $Name } -ParameterFilter { $true }
        Mock Start-Service { $global:Started += $Name } -ParameterFilter { $true }
        Mock Set-Service { $global:StartupTypeWrites += "$Name=$StartupType" } -ParameterFilter { $true }
    }

    AfterEach {
        Remove-Item -LiteralPath $script:StatusRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'suspends only the services in their standard active state' {
        # wuauserv is in the factory state and conflicts with WinGet; bits was
        # stopped beforehand and must not be touched.
        Mock Get-Service {
            param($Name)
            $names = @($Name)
            if ($names.Count -gt 1) {
                return @(
                    [pscustomobject]@{ Name = 'wuauserv'; Status = 'Running'; StartType = 'Automatic' }
                    [pscustomobject]@{ Name = 'bits'; Status = 'Stopped'; StartType = 'Automatic' }
                )
            }
            # Verification call right after a stop: the service is down.
            return [pscustomobject]@{ Name = $names[0]; Status = 'Stopped'; StartType = 'Automatic' }
        } -ParameterFilter { $true }

        Invoke-StopUpdateServices

        $global:Stopped | Should -Be @('wuauserv')
    }

    It 'leaves a manually started service alone' {
        # Running but not automatic is not a standard active state: not suspended,
        # and its startup type is never rewritten.
        Mock Get-Service {
            @(
                [pscustomobject]@{ Name = 'wuauserv'; Status = 'Running'; StartType = 'Manual' }
                [pscustomobject]@{ Name = 'bits'; Status = 'Running'; StartType = 'Manual' }
            )
        } -ParameterFilter { $true }

        Invoke-StopUpdateServices

        $global:Stopped | Should -BeNullOrEmpty
    }

    It 'leaves a disabled service alone' {
        Mock Get-Service {
            param($Name)
            $names = @($Name)
            if ($names.Count -gt 1) {
                return @(
                    [pscustomobject]@{ Name = 'wuauserv'; Status = 'Running'; StartType = 'Automatic' }
                    [pscustomobject]@{ Name = 'bits'; Status = 'Stopped'; StartType = 'Disabled' }
                )
            }
            return [pscustomobject]@{ Name = $names[0]; Status = 'Stopped'; StartType = 'Automatic' }
        } -ParameterFilter { $true }

        Invoke-StopUpdateServices

        $global:Stopped | Should -Be @('wuauserv')
        $global:StartupTypeWrites | Should -BeNullOrEmpty
    }


    It 'records the decision so a later restore knows what it owns' {
        Mock Get-Service {
            param($Name)
            $names = @($Name)
            if ($names.Count -gt 1) {
                return @(
                    [pscustomobject]@{ Name = 'wuauserv'; Status = 'Running'; StartType = 'Automatic' }
                    [pscustomobject]@{ Name = 'bits'; Status = 'Stopped'; StartType = 'Automatic' }
                )
            }
            return [pscustomobject]@{ Name = $names[0]; Status = 'Stopped'; StartType = 'Automatic' }
        } -ParameterFilter { $true }

        Invoke-StopUpdateServices

        $status = Read-UpdateServicesStatus
        $status | Should -Not -BeNullOrEmpty
        ($status.Services | Where-Object { $_.Name -eq 'wuauserv' }).InScope | Should -BeTrue
        ($status.Services | Where-Object { $_.Name -eq 'bits' }).InScope | Should -BeFalse
    }

    It 'suspends nothing when no service is in a standard active state' {
        Mock Get-Service {
            @(
                [pscustomobject]@{ Name = 'wuauserv'; Status = 'Stopped'; StartType = 'Automatic' }
                [pscustomobject]@{ Name = 'bits'; Status = 'Stopped'; StartType = 'Disabled' }
            )
        } -ParameterFilter { $true }

        Invoke-StopUpdateServices

        $global:Stopped | Should -BeNullOrEmpty
        # Nothing pending: the restore must find the run already completed.
        (Read-UpdateServicesStatus).State | Should -Be 'Restored'
    }
}

Describe 'Invoke-StartUpdateServices - services it does not own' {
    BeforeEach {
        $script:StatusRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('wt-services-' + [guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:StatusRoot -Force
        $script:AppConfig.Paths.WinToolkitDir = $script:StatusRoot
        $script:State.LogFile = $null
        $global:Stopped = @()
        $global:Started = @()
        $global:StartupTypeWrites = @()

        Mock Stop-Service { $global:Stopped += $Name } -ParameterFilter { $true }
        Mock Start-Service { $global:Started += $Name } -ParameterFilter { $true }
        Mock Set-Service { $global:StartupTypeWrites += "$Name=$StartupType" } -ParameterFilter { $true }
        Mock Get-Service {
            param($Name)
            $requested = [string]@($Name)[0]
            if ($requested -eq 'bits') {
                # Started by the system while the run was in progress.
                return [pscustomobject]@{ Name = 'bits'; Status = 'Running'; StartType = 'Automatic' }
            }
            return [pscustomobject]@{ Name = $requested; Status = 'Stopped'; StartType = 'Automatic' }
        } -ParameterFilter { $true }
    }

    AfterEach {
        Remove-Item -LiteralPath $script:StatusRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'never stops a service it did not suspend (the bits defect)' {
        Write-UpdateServicesStatus -Status @{
            Version    = 2
            State      = 'Suspended'
            LastError  = $null
            Services   = @(
                [pscustomobject]@{ Name = 'wuauserv'; Status = 'Running'; StartType = 'Automatic'; InScope = $true }
                [pscustomobject]@{ Name = 'bits'; Status = 'Stopped'; StartType = 'Automatic'; InScope = $false }
            )
            CreatedUtc = [DateTime]::UtcNow.ToString('o')
        }

        $result = Invoke-StartUpdateServices

        $result | Should -BeTrue
        $global:Stopped | Should -BeNullOrEmpty
        $global:Started | Should -Be @('wuauserv')
        $global:StartupTypeWrites | Should -Be @('wuauserv=Automatic')
        (Read-UpdateServicesStatus).State | Should -Be 'Restored'
    }

    It 'recomputes the scope for a payload written before InScope existed' {
        # Version 1 payloads have no InScope: the decision is derived from the
        # recorded state, and the old CIM StartMode name is normalized.
        Write-UpdateServicesStatus -Status @{
            Version    = 1
            State      = 'Suspended'
            LastError  = $null
            Services   = @(
                [pscustomobject]@{ Name = 'wuauserv'; Status = 'Running'; StartType = 'Auto' }
                [pscustomobject]@{ Name = 'bits'; Status = 'Stopped'; StartType = 'Auto' }
            )
            CreatedUtc = [DateTime]::UtcNow.ToString('o')
        }

        $result = Invoke-StartUpdateServices

        $result | Should -BeTrue
        $global:Stopped | Should -BeNullOrEmpty
        $global:Started | Should -Be @('wuauserv')
        $global:StartupTypeWrites | Should -Be @('wuauserv=Automatic')
    }
}

Describe 'Test-ToolkitPathBelongsToInteractiveUser' {
    It 'accepts a path inside the current profile' {
        Test-ToolkitPathBelongsToInteractiveUser -Path (Join-Path $env:USERPROFILE 'Documents\PowerShell') | Should -BeTrue
    }

    It 'reports a path that belongs to another account' {
        # The exact failure: the Documents folder of the administrator profile is
        # resolved and written while the standard user is signed in.
        Test-ToolkitPathBelongsToInteractiveUser -Path 'C:\Users\SomeoneElse\Documents\PowerShell' | Should -BeFalse
    }
}
