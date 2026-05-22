function AutoVideoDriverInstall {
    <#
    .SYNOPSIS
        Installazione automatica driver video con rilevamento GPU (AMD/NVIDIA/Intel).
    .PARAMETER CountdownSeconds
        Secondi per il countdown prima del riavvio.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "AutoVideoDriverInstall" -SubTitle "Auto Video Driver Install"

    $driverToolsPath = $AppConfig.Paths.Drivers

    function Get-GpuManufacturer {
        $pnpDevices = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue
        if (-not $pnpDevices) {
            Write-StyledMessage -Type 'Warning' -Text "Nessun dispositivo display PnP rilevato."
            return 'Unknown'
        }
        foreach ($device in $pnpDevices) {
            $name = $device.FriendlyName
            $mfr  = $device.Manufacturer
            if ($name -match 'NVIDIA|GeForce|Quadro|Tesla' -or $mfr -match 'NVIDIA') { return 'NVIDIA' }
            if ($name -match 'AMD|Radeon|ATI'               -or $mfr -match 'AMD|ATI') { return 'AMD'    }
            if ($name -match 'Intel|Iris|UHD|HD Graphics'   -or $mfr -match 'Intel')  { return 'Intel'  }
        }
        return 'Unknown'
    }

    function Set-BlockWindowsUpdateDrivers {
        Write-StyledMessage -Type 'Info' -Text "Blocco driver automatici da Windows Update."
        try {
            Set-RegistryValue -Path $AppConfig.Registry.WindowsUpdatePolicies -Name "ExcludeWUDriversInQualityUpdate" -Value 1
            Write-StyledMessage -Type 'Success' -Text "Blocco WU driver impostato."
            $gpupdateResult = Invoke-WithSpinner -Activity "Aggiornamento criteri di gruppo" -Command 'gpupdate.exe' -Arguments '/force' -LogContextKey "Video-GPUpdate"
            if ($gpupdateResult.ExitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "Criteri di gruppo aggiornati."
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "gpupdate completato con codice: $($gpupdateResult.ExitCode)."
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore blocco WU driver: $($_.Exception.Message)."
        }
    }

    try {
        Write-StyledMessage -Type 'Info' -Text "🚀 Avvio installazione automatica driver video."
        Set-BlockWindowsUpdateDrivers

        $gpuManufacturer = Get-GpuManufacturer
        Write-StyledMessage -Type 'Info' -Text "GPU rilevata: $gpuManufacturer."

        switch ($gpuManufacturer) {
            'AMD' {
                $amdPath = Join-Path $driverToolsPath "AMD-Autodetect.exe"
                if (Invoke-ToolkitDownload -Uri $AppConfig.URLs.AMDInstaller -OutputPath $amdPath -Description "AMD Auto-Detect Tool") {
                    Write-StyledMessage -Type 'Info' -Text "Avvio installer AMD. Chiudi il terminale al termine dell'installazione."
                    $null = Invoke-WithSpinner -Activity "Esecuzione installer AMD" -Command $amdPath -LogContextKey "Video-Install-AMD"
                    Write-StyledMessage -Type 'Success' -Text "Installazione driver AMD completata."
                }
            }
            'NVIDIA' {
                $nvidiaPath = Join-Path $driverToolsPath "NVCleanstall_1.19.0.exe"
                if (Invoke-ToolkitDownload -Uri $AppConfig.URLs.NVCleanstall -OutputPath $nvidiaPath -Description "NVCleanstall") {
                    Write-StyledMessage -Type 'Info' -Text "Avvio NVCleanstall. Chiudi il terminale al termine dell'installazione."
                    $null = Invoke-WithSpinner -Activity "Esecuzione NVCleanstall" -Command $nvidiaPath -LogContextKey "Video-Install-NVIDIA"
                    Write-StyledMessage -Type 'Success' -Text "Installazione driver NVIDIA completata."
                }
            }
            'Intel' {
                Write-StyledMessage -Type 'Info' -Text "GPU Intel rilevata. Usa Windows Update per aggiornare i driver integrati."
            }
            default {
                Write-StyledMessage -Type 'Error' -Text "Produttore GPU non supportato o non rilevato per l'installazione automatica."
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante installazione driver: $($_.Exception.Message)"
        Write-ToolkitLog -Level ERROR -Message "Errore in AutoVideoDriverInstall" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text "🎯 Auto Video Driver Install terminato."
        Write-ToolkitLog -Level INFO -Message "AutoVideoDriverInstall sessione terminata."
    }
}
