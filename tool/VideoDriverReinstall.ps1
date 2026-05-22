function VideoDriverReinstall {
    <#
    .SYNOPSIS
        Reinstallazione/riparazione driver video tramite DDU in modalità provvisoria.
        Scarica DDU e l'installer del driver rilevato sul Desktop, poi riavvia in Safe Mode.
    .PARAMETER CountdownSeconds
        Secondi per il countdown prima del riavvio.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "VideoDriverReinstall" -SubTitle "Video Driver Reinstall"

    $driverToolsPath = $AppConfig.Paths.Drivers
    $desktopPath     = $AppConfig.Paths.Desktop

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

    $needsReboot = $false

    try {
        Write-StyledMessage -Type 'Warning' -Text "🔧 Avvio procedura reinstallazione/riparazione driver video."
        Set-BlockWindowsUpdateDrivers

        # Download e estrazione DDU
        $dduZipPath = Join-Path $driverToolsPath "DDU.zip"
        if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.DDUZip -OutputPath $dduZipPath -Description "DDU (Display Driver Uninstaller)")) {
            Write-StyledMessage -Type 'Error' -Text "Impossibile scaricare DDU. Annullamento."
            return
        }

        Write-StyledMessage -Type 'Info' -Text "Estrazione DDU sul Desktop."
        try {
            Expand-Archive -Path $dduZipPath -DestinationPath $desktopPath -Force
            Write-StyledMessage -Type 'Success' -Text "DDU estratto sul Desktop."
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore estrazione DDU: $($_.Exception.Message)."
            return
        }

        # Download installer driver rilevato (sul Desktop per uso in Safe Mode)
        $gpuAnalysis = VcardAnalizer
        $gpuManufacturer = $gpuAnalysis.PrimaryManufacturer
        Write-StyledMessage -Type 'Info' -Text "GPU rilevata: $gpuManufacturer."

        $stableDownloadDone = $false
        if ($gpuAnalysis.Matches.Count -gt 0) {
            foreach ($match in $gpuAnalysis.Matches) {
                if ([string]::IsNullOrWhiteSpace($match.DownloadUrl)) { continue }
                $targetName = if (-not [string]::IsNullOrWhiteSpace($match.FileName)) { $match.FileName } else { "$($match.Key).exe" }
                $targetPath = Join-Path $desktopPath $targetName
                $displayName = if (-not [string]::IsNullOrWhiteSpace($match.DisplayName)) { $match.DisplayName } else { $match.Key }

                if (Invoke-ToolkitDownload -Uri $match.DownloadUrl -OutputPath $targetPath -Description $displayName) {
                    Write-StyledMessage -Type 'Success' -Text "Driver stabile scaricato sul desktop: $displayName"
                    $stableDownloadDone = $true
                }
            }
        }

        if (-not $stableDownloadDone) {
            Write-StyledMessage -Type 'Warning' -Text "Nessun driver stabile conosciuto trovato. Uso fallback autodetect."
            switch ($gpuManufacturer) {
                'AMD' {
                    $amdPath = Join-Path $desktopPath "AMD-Autodetect.exe"
                    if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.AMDInstaller -OutputPath $amdPath -Description "AMD Auto-Detect Tool")) {
                        Write-StyledMessage -Type 'Error' -Text "❌ Impossibile scaricare installer AMD. Annullamento."
                        return
                    }
                }
                'NVIDIA' {
                    $nvidiaPath = Join-Path $desktopPath "NVCleanstall_1.19.0.exe"
                    if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.NVCleanstall -OutputPath $nvidiaPath -Description "NVCleanstall")) {
                        Write-StyledMessage -Type 'Error' -Text "❌ Impossibile scaricare NVCleanstall. Annullamento."
                        return
                    }
                }
                'Intel' {
                    Write-StyledMessage -Type 'Info' -Text "GPU Intel: scarica driver manualmente da Intel se necessario."
                }
                default {
                    Write-StyledMessage -Type 'Warning' -Text "GPU non rilevata: solo DDU verrà posizionato sul Desktop."
                }
            }
        }

        # Batch per tornare alla modalità normale dopo DDU
        $batchPath = Join-Path $desktopPath "Switch to Normal Mode.bat"
        try {
            Set-Content -Path $batchPath -Value 'bcdedit /deletevalue {current} safeboot' -Encoding ASCII
            Write-StyledMessage -Type 'Info' -Text "Batch 'Switch to Normal Mode.bat' creato sul Desktop."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile creare batch Safe Mode: $($_.Exception.Message)."
        }

        Write-StyledMessage -Type 'Error' -Text "ATTENZIONE: Il sistema si riavvierà in modalità provvisoria."
        Write-StyledMessage -Type 'Info' -Text "In Safe Mode: esegui DDU per pulire i driver, poi reinstalla con l'installer sul Desktop. Infine usa il batch per tornare alla modalità normale."

        # Configura Safe Mode per il prossimo avvio
        try {
            $null = Invoke-WithSpinner -Activity "Configurazione Safe Mode (bcdedit)" -Command 'bcdedit.exe' `
                -Arguments '/set {current} safeboot minimal' -LogContextKey "Video-BCDEdit"
            Write-StyledMessage -Type 'Success' -Text "Modalità provvisoria configurata per il prossimo avvio."
            $needsReboot = $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore configurazione Safe Mode: $($_.Exception.Message)."
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore critico durante reinstallazione driver: $($_.Exception.Message)"
        Write-ToolkitLog -Level ERROR -Message "Errore in VideoDriverReinstall" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text "🎯 Video Driver Reinstall terminato."
        Write-ToolkitLog -Level INFO -Message "VideoDriverReinstall sessione terminata."
    }

    if ($needsReboot) {
        Invoke-ToolkitReboot -Message "Riavvio in Safe Mode per DDU" -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
