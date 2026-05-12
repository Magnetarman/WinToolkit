function Repair-Office {
    <#
    .SYNOPSIS
        Ripara Microsoft Office tramite Click-to-Run (riparazione rapida + fallback online).
    .PARAMETER CountdownSeconds
        Secondi per il countdown prima del riavvio.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "OfficeRepair" -SubTitle "Office Repair"

    function Set-OfficePostConfig {
        Write-StyledMessage -Type 'Info' -Text "⚙️ Configurazione post-riparazione Office."
        foreach ($reg in @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";           Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "disconnectedstate";       Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "usercontentdisabled";     Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "downloadcontentdisabled"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";           Value = 0 }
        )) { Set-RegistryValue -Path $reg.Path -Name $reg.Name -Value $reg.Value }
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General" -Name "ShownOptIn" -Value 1
        Write-StyledMessage -Type 'Success' -Text "✅ Telemetria e Privacy Office disabilitate."
    }

    $needsReboot = $false

    try {
        Write-StyledMessage -Type 'Info' -Text "🔧 Avvio riparazione Office."
        Stop-ToolkitProcesses -ProcessNames @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')

        Write-StyledMessage -Type 'Info' -Text "🧹 Pulizia cache Office."
        $cleanedCount = 0
        foreach ($cache in @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )) {
            if (Remove-ItemSafely -Path $cache -Recurse) { $cleanedCount++ }
        }
        if ($cleanedCount -gt 0) { Write-StyledMessage -Type 'Success' -Text "$cleanedCount cache eliminate." }

        $officeClient = (Test-Path "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe") ?
            "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe" :
            "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"

        if (-not (Test-Path $officeClient)) {
            Write-StyledMessage -Type 'Error' -Text "OfficeClickToRun.exe non trovato. Office potrebbe non essere installato."
            return
        }

        try {
            Write-StyledMessage -Type 'Info' -Text "🔧 Avvio riparazione rapida (offline)."
            $null = Invoke-WithSpinner -Activity "Riparazione Rapida Office (Offline)" -Command $officeClient `
                -Arguments "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=QuickRepair DisplayLevel=True" `
                -TimeoutSeconds 86400 -LogContextKey "Office-Repair-Quick"

            Set-OfficePostConfig
            Write-StyledMessage -Type 'Success' -Text "🎉 Riparazione Office completata!"
            $needsReboot = $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante riparazione rapida: $($_.Exception.Message)."
            try {
                Write-StyledMessage -Type 'Info' -Text "🌐 Tentativo riparazione completa (online) come fallback."
                $null = Invoke-WithSpinner -Activity "Riparazione Completa Office (Online)" -Command $officeClient `
                    -Arguments "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True" `
                    -TimeoutSeconds 86400 -LogContextKey "Office-Repair-Full"

                Set-OfficePostConfig
                Write-StyledMessage -Type 'Success' -Text "🎉 Riparazione Office completata!"
                $needsReboot = $true
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Errore anche durante riparazione online: $($_.Exception.Message)."
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore critico durante riparazione Office: $($_.Exception.Message)"
        Write-ToolkitLog -Level ERROR -Message "Errore critico in Repair-Office" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text "🎯 Office Repair terminato."
        Write-ToolkitLog -Level INFO -Message "Repair-Office sessione terminata."
    }

    if ($needsReboot) {
        Invoke-ToolkitReboot -Message "Riparazione completata" -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
