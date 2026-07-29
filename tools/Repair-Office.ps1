function Repair-Office {
    <#
    .SYNOPSIS
        Repairs Microsoft Office through Click-to-Run (Quick Repair with Online Repair fallback).
    .PARAMETER CountdownSeconds
        Number of seconds in the countdown before restarting.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "OfficeRepair" -SubTitle (Get-Loc 'script.Repair-Office')

    function Set-OfficePostConfig {
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.officePostRepairSetup')
        foreach ($reg in @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";           Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "disconnectedstate";       Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "usercontentdisabled";     Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "downloadcontentdisabled"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";           Value = 0 }
        )) { Set-RegistryValue -Path $reg.Path -Name $reg.Name -Value $reg.Value }
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General" -Name "ShownOptIn" -Value 1
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.telemetryAndPrivacyOfficeDisabled')
    }

    $needsReboot = $false

    try {
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.startingOfficeRepair')
        Stop-ToolkitProcesses -ProcessNames @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')

        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.officeCacheCleaner')
        $cleanedCount = 0
        foreach ($cache in @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )) {
            if (Remove-ItemSafely -Path $cache -Recurse) { $cleanedCount++ }
        }
        if ($cleanedCount -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.0DeletedCaches' -Args @($cleanedCount)) }

        $officeClient64 = "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
        $officeClient32 = "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
        $officeClient = if (Test-Path $officeClient64) { $officeClient64 } else { $officeClient32 }

        if (-not (Test-Path $officeClient)) {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.officeclicktorunExeNotFoundOfficeMayNotBeInstalled')
            return
        }

        try {
            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.launchQuickRepairOffline')
            $null = Invoke-WithSpinner -Activity (Get-Loc 'uiText.quickOfficeRepairOffline') -Command $officeClient `
                -Arguments "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=QuickRepair DisplayLevel=True" `
                -TimeoutSeconds 86400 -LogContextKey "Office-Repair-Quick"

            Set-OfficePostConfig
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.officeRepairComplete')
            $needsReboot = $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorDuringQuickRepair0' -Args @($($_.Exception.Message)))
            try {
                Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.attemptingFullRepairOnlineAsAFallback')
                $null = Invoke-WithSpinner -Activity (Get-Loc 'uiText.completeOfficeRepairOnline') -Command $officeClient `
                    -Arguments "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True" `
                    -TimeoutSeconds 86400 -LogContextKey "Office-Repair-Full"

                Set-OfficePostConfig
                Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.officeRepairComplete')
                $needsReboot = $true
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorAlsoDuringOnlineRepair0' -Args @($($_.Exception.Message)))
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.criticalErrorRepairingOffice0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-Loc 'toolText.criticalErrorInRepairOffice') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.officeRepairFinished')
        Write-ToolkitLog -Level INFO -Message (Get-Loc 'toolText.repairOfficeSessionEnded')
    }

    if ($needsReboot) {
        Invoke-ToolkitReboot -Message (Get-Loc 'toolText.extra.repairCompleted') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
