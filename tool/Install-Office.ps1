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
            if (-not (Invoke-OfficeDownloadFile $dl.Url $dl.Path $dl.Name)) {
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
        Invoke-OfficeSilentRemoval -Path $tempDir -Recurse
        Write-StyledMessage -Type 'Success' -Text "🎯 Office Install terminato."
        Write-ToolkitLog -Level INFO -Message "Install-Office sessione terminata."
    }
}
