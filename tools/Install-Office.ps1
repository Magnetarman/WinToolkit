function Install-Office {
    <#
    .SYNOPSIS
        Installa Microsoft Office Basic tramite ODT (Office Deployment Tool).
    .PARAMETER CountdownSeconds
        Secondi per il countdown prima del riavvio.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "OfficeInstall" -SubTitle "Office Install"

    $tempDir = $AppConfig.Paths.OfficeTemp

    function Set-OfficePostConfig {
        Write-StyledMessage -Type 'Info' -Text "⚙️ Configurazione post-installazione Office."
        foreach ($reg in @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";         Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "disconnectedstate";     Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "usercontentdisabled";   Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "downloadcontentdisabled"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";         Value = 0 }
        )) { Set-RegistryValue -Path $reg.Path -Name $reg.Name -Value $reg.Value }
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General" -Name "ShownOptIn" -Value 1
        Write-StyledMessage -Type 'Success' -Text "✅ Telemetria e Privacy Office disabilitate."
    }

    try {
        Write-StyledMessage -Type 'Info' -Text "🏢 Avvio installazione Office Basic."

        if (-not (Test-Path $tempDir)) {
            $null = New-Item -ItemType Directory -Path $tempDir -Force
        }

        $setupPath  = Join-Path $tempDir 'Setup.exe'
        $configPath = Join-Path $tempDir 'Basic.xml'

        foreach ($dl in @(
            @{ Url = $AppConfig.URLs.OfficeSetup;       Path = $setupPath;  Name = 'Setup Office' },
            @{ Url = $AppConfig.URLs.OfficeBasicConfig; Path = $configPath; Name = 'Configurazione Basic' }
        )) {
            if (-not (Invoke-ToolkitDownload -Uri $dl.Url -OutputPath $dl.Path -Description $dl.Name)) {
                Write-StyledMessage -Type 'Error' -Text "Download fallito. Installazione annullata."
                return
            }
        }

        Write-StyledMessage -Type 'Info' -Text "🚀 Avvio processo installazione."
        $result = Invoke-WithSpinner -Activity "Installazione Office Basic" -Command $setupPath `
            -Arguments "/configure `"$configPath`"" -TimeoutSeconds 86400 -LogContextKey "Office-Install"

        Clear-ProgressLine

        if (-not $result.Success) {
            Write-StyledMessage -Type 'Error' -Text "Installazione fallita."
            return
        }

        Set-OfficePostConfig
        Write-StyledMessage -Type 'Success' -Text "✅ Installazione completata."
        Write-StyledMessage -Type 'Info' -Text "Riavvio non necessario."
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante installazione Office: $($_.Exception.Message)"
        Write-ToolkitLog -Level ERROR -Message "Errore critico in Install-Office" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Remove-ItemSafely -Path $tempDir -Recurse
        Write-StyledMessage -Type 'Success' -Text "🎯 Office Install terminato."
        Write-ToolkitLog -Level INFO -Message "Install-Office sessione terminata."
    }
}
