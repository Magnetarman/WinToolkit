function Install-Office {
    <#
    .SYNOPSIS
        Installs Microsoft Office Basic through ODT (Office Deployment Tool).
    .PARAMETER CountdownSeconds
        Number of seconds in the countdown before restarting.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "OfficeInstall" -SubTitle (Get-Loc 'script.Install-Office')

    $tempDir = $AppConfig.Paths.OfficeTemp

    function Set-OfficePostConfig {
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.officePostInstallationConfiguration')
        foreach ($reg in @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";         Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "disconnectedstate";     Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "usercontentdisabled";   Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "downloadcontentdisabled"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";         Value = 0 }
        )) { Set-RegistryValue -Path $reg.Path -Name $reg.Name -Value $reg.Value }
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General" -Name "ShownOptIn" -Value 1
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.telemetryAndPrivacyOfficeDisabled')
    }

    try {
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.startingOfficeBasicInstallation')

        if (-not (Test-Path $tempDir)) {
            $null = New-Item -ItemType Directory -Path $tempDir -Force
        }

        $setupPath  = Join-Path $tempDir 'Setup.exe'
        $configPath = Join-Path $tempDir 'Basic.xml'

        foreach ($dl in @(
            @{ Url = $AppConfig.URLs.OfficeSetup;       Path = $setupPath;  Name = (Get-Loc 'toolText.extra.officeSetup') },
            @{ Url = $AppConfig.URLs.OfficeBasicConfig; Path = $configPath; Name = (Get-Loc 'toolText.extra.basicConfiguration') }
        )) {
            if (-not (Invoke-ToolkitDownload -Uri $dl.Url -OutputPath $dl.Path -Description $dl.Name)) {
                Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.downloadFailedInstallationCancelled')
                return
            }
        }

        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.startingInstallationProcess')
        $result = Invoke-WithSpinner -Activity (Get-Loc 'toolText.extra.officeBasicInstallation') -Command $setupPath `
            -Arguments "/configure `"$configPath`"" -TimeoutSeconds 86400 -LogContextKey "Office-Install"

        Clear-ProgressLine

        if (-not $result.Success) {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.installationFailed')
            return
        }

        Set-OfficePostConfig
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.installationCompleted')
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.restartNotRequired')
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorInstallingOffice0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-Loc 'toolText.criticalErrorInInstallOffice') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Remove-ItemSafely -Path $tempDir -Recurse
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.officeInstallFinished')
        Write-ToolkitLog -Level INFO -Message (Get-Loc 'toolText.installOfficeSessionEnded')
    }
}
