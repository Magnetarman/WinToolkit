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

    Start-ToolkitSession -ToolName "OfficeRepair" -SubTitle (Get-SourceTextLoc 'script.Repair-Office')

    function Set-OfficePostConfig {
        Write-StyledMessage -Type 'Info' -Text ("⚙️ " + (Get-SourceTextLoc 'toolText.officePostRepairSetup'))
        foreach ($reg in @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";           Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "disconnectedstate";       Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "usercontentdisabled";     Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "downloadcontentdisabled"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";           Value = 0 }
        )) { Set-RegistryValue -Path $reg.Path -Name $reg.Name -Value $reg.Value }
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General" -Name "ShownOptIn" -Value 1
        Write-StyledMessage -Type 'Success' -Text ("✅ " + (Get-SourceTextLoc 'toolText.telemetryAndPrivacyOfficeDisabled'))
    }

    $needsReboot = $false

    try {
        Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.startingOfficeRepair'))
        Stop-ToolkitProcesses -ProcessNames @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')

        Write-StyledMessage -Type 'Info' -Text ("🧹 " + (Get-SourceTextLoc 'toolText.officeCacheCleaner'))
        $cleanedCount = 0
        foreach ($cache in @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )) {
            if (Remove-ItemSafely -Path $cache -Recurse) { $cleanedCount++ }
        }
        if ($cleanedCount -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0DeletedCaches' -Args @($cleanedCount)) }

        $officeClient64 = "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
        $officeClient32 = "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
        $officeClient = if (Test-Path $officeClient64) { $officeClient64 } else { $officeClient32 }

        if (-not (Test-Path $officeClient)) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.officeclicktorunExeNotFoundOfficeMayNotBeInstalled')
            return
        }

        try {
            Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.launchQuickRepairOffline'))
            $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.quickOfficeRepairOffline') -Command $officeClient `
                -Arguments "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=QuickRepair DisplayLevel=True" `
                -TimeoutSeconds 86400 -LogContextKey "Office-Repair-Quick"

            Set-OfficePostConfig
            Write-StyledMessage -Type 'Success' -Text ("🎉 " + (Get-SourceTextLoc 'toolText.officeRepairComplete'))
            $needsReboot = $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringQuickRepair0' -Args @($($_.Exception.Message)))
            try {
                Write-StyledMessage -Type 'Info' -Text ("🌐 " + (Get-SourceTextLoc 'toolText.attemptingFullRepairOnlineAsAFallback'))
                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.completeOfficeRepairOnline') -Command $officeClient `
                    -Arguments "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True" `
                    -TimeoutSeconds 86400 -LogContextKey "Office-Repair-Full"

                Set-OfficePostConfig
                Write-StyledMessage -Type 'Success' -Text ("🎉 " + (Get-SourceTextLoc 'toolText.officeRepairComplete'))
                $needsReboot = $true
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorAlsoDuringOnlineRepair0' -Args @($($_.Exception.Message)))
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.criticalErrorRepairingOffice0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.criticalErrorInRepairOffice') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text ("🎯 " + (Get-SourceTextLoc 'toolText.officeRepairFinished'))
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.repairOfficeSessionEnded')
    }

    if ($needsReboot) {
        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.repairCompleted') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
