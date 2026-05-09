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

    Start-ToolkitLog -ToolName "OfficeInstall"
    Show-Header -SubTitle "Office Install"
    $Host.UI.RawUI.WindowTitle = "Office Install By MagnetarMan"

    $tempDir = $AppConfig.Paths.OfficeTemp

    function Invoke-SilentRemoval {
        param(
            [Parameter(Mandatory = $true)][string]$Path,
            [switch]$Recurse
        )
        if (-not (Test-Path $Path)) { return $false }
        try {
            $params = @{ Path = $Path; Force = $true; ErrorAction = 'SilentlyContinue' }
            if ($Recurse) { $params['Recurse'] = $true }
            Remove-Item @params *>$null
            Clear-ProgressLine
            return $true
        } catch { return $false }
    }

    function Apply-OfficePostConfig {
        Write-StyledMessage -Type 'Info' -Text "⚙️ Ottimizzazione profonda di Microsoft Office."

        $registrySettings = @(
            # Privacy & Telemetria
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "disconnectedstate"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "usercontentdisabled"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "downloadcontentdisabled"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"; Name = "ShownOptIn"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback"; Name = "Enabled"; Value = 0 },
            # Performance & UI
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Graphics"; Name = "DisableAnimations"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Graphics"; Name = "DisableHardwareAcceleration"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"; Name = "DisableBootToStartScreen"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\LinkedIn"; Name = "ShowLinkedInIntegration"; Value = 0 }
        )

        foreach ($reg in $registrySettings) {
            if (-not (Test-Path $reg.Path)) { $null = New-Item -Path $reg.Path -Force }
            Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type 'DWord' -Force
        }

        $tasksToDisable = @(
            "OfficeTelemetryAgentLogon",
            "OfficeTelemetryAgentFallback",
            "OfficeBackgroundTaskHandlerRegistration",
            "OfficeBackgroundTaskHandlerLogon",
            "OfficeFeatureUpdates",
            "OfficeFeatureUpdatesLogon"
        )
        foreach ($tName in $tasksToDisable) {
            Get-ScheduledTask | Where-Object { $_.TaskName -eq $tName } | Disable-ScheduledTask -ErrorAction SilentlyContinue
        }

        Write-StyledMessage -Type 'Success' -Text "✅ Office ottimizzato: telemetria, privacy e task pianificati rimossi."
    }

    function Invoke-DownloadFile([string]$Url, [string]$OutputPath, [string]$Description) {
        try {
            Write-StyledMessage -Type 'Info' -Text "📥 Download $Description."
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $OutputPath)
            $webClient.Dispose()
            $success = (Test-Path $OutputPath)
            Write-StyledMessage -Type ($success ? 'Success' : 'Error') -Text ($success ? "Download completato: $Description" : "File non trovato dopo download: $Description.")
            return $success
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore download $Description`: $_"
            return $false
        }
    }

    try {
        Write-StyledMessage -Type 'Info' -Text "🏢 Avvio installazione Office Basic."

        if (-not (Test-Path $tempDir)) { $null = New-Item -ItemType Directory -Path $tempDir -Force }

        $setupPath  = Join-Path $tempDir 'Setup.exe'
        $configPath = Join-Path $tempDir 'Basic.xml'

        $downloads = @(
            @{ Url = $AppConfig.URLs.OfficeSetup; Path = $setupPath; Name = 'Setup Office' },
            @{ Url = $AppConfig.URLs.OfficeBasicConfig; Path = $configPath; Name = 'Configurazione Basic' }
        )

        foreach ($dl in $downloads) {
            if (-not (Invoke-DownloadFile $dl.Url $dl.Path $dl.Name)) {
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

        Apply-OfficePostConfig
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
        Invoke-SilentRemoval -Path $tempDir -Recurse
        Write-StyledMessage -Type 'Success' -Text "🎯 Office Install terminato."
        Write-ToolkitLog -Level INFO -Message "Install-Office sessione terminata."
    }
}
