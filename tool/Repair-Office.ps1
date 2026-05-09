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

    Start-ToolkitLog -ToolName "OfficeRepair"
    Show-Header -SubTitle "Office Repair"
    $Host.UI.RawUI.WindowTitle = "Office Repair By MagnetarMan"

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

    function Stop-OfficeProcesses {
        $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
        $closed = 0

        Write-StyledMessage -Type 'Info' -Text "📋 Chiusura processi Office."
        foreach ($processName in $processes) {
            $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($running) {
                try {
                    $running | Stop-Process -Force -ErrorAction Stop
                    $closed++
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Impossibile chiudere: $processName."
                }
            }
        }
        if ($closed -gt 0) { Write-StyledMessage -Type 'Success' -Text "$closed processi Office chiusi." }
    }

    function Apply-OfficePostConfig {
        Write-StyledMessage -Type 'Info' -Text "⚙️ Configurazione post-riparazione Office."

        $telemetryKeys = @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "disconnectedstate"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "usercontentdisabled"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "downloadcontentdisabled"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 }
        )

        foreach ($reg in $telemetryKeys) {
            if (-not (Test-Path $reg.Path)) { $null = New-Item -Path $reg.Path -Force }
            Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type 'DWord' -Force
        }

        $feedbackPath = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"
        if (-not (Test-Path $feedbackPath)) { $null = New-Item $feedbackPath -Force }
        Set-ItemProperty -Path $feedbackPath -Name "ShownOptIn" -Value 1 -Type 'DWord' -Force

        Write-StyledMessage -Type 'Success' -Text "✅ Telemetria e Privacy Office disabilitate."
    }

    $needsReboot = $false

    try {
        Write-StyledMessage -Type 'Info' -Text "🔧 Avvio riparazione Office."
        Stop-OfficeProcesses

        Write-StyledMessage -Type 'Info' -Text "🧹 Pulizia cache Office."
        $caches = @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )
        $cleanedCount = 0
        foreach ($cache in $caches) {
            if (Invoke-SilentRemoval -Path $cache -Recurse) { $cleanedCount++ }
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

            Apply-OfficePostConfig
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

                Apply-OfficePostConfig
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
        if ($SuppressIndividualReboot) {
            $Global:NeedsFinalReboot = $true
            Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
        }
        else {
            if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riparazione completata") {
                Restart-Computer -Force
            }
        }
    }
}
