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

        $gpuAnalysis = VcardAnalizer
        $gpuManufacturer = $gpuAnalysis.PrimaryManufacturer
        Write-StyledMessage -Type 'Info' -Text "GPU rilevata: $gpuManufacturer."

        $stableDownloadDone = $false
        if ($gpuAnalysis.Matches.Count -gt 0) {
            foreach ($match in $gpuAnalysis.Matches) {
                if ([string]::IsNullOrWhiteSpace($match.DownloadUrl)) { continue }
                $targetName = if (-not [string]::IsNullOrWhiteSpace($match.FileName)) { $match.FileName } else { "$($match.Key).exe" }
                $targetPath = Join-Path $driverToolsPath $targetName
                $displayName = if (-not [string]::IsNullOrWhiteSpace($match.DisplayName)) { $match.DisplayName } else { $match.Key }

                if (Invoke-ToolkitDownload -Uri $match.DownloadUrl -OutputPath $targetPath -Description $displayName) {
                    Write-StyledMessage -Type 'Success' -Text "Driver stabile scaricato: $displayName"
                    $stableDownloadDone = $true
                }
            }
        }

        if (-not $stableDownloadDone) {
            Write-StyledMessage -Type 'Warning' -Text "Nessun driver stabile conosciuto trovato. Uso fallback autodetect."
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
