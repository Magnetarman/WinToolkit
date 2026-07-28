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

    $desktopPath = $AppConfig.Paths.Desktop

    function Set-BlockWindowsUpdateDrivers {
        Write-StyledMessage -Type 'Info' -Text "Blocco driver automatici da Windows Update."
        try {
            Set-RegistryValue -Path $AppConfig.Registry.WindowsUpdatePolicies -Name "ExcludeWUDriversInQualityUpdate" -Value 1
            Write-StyledMessage -Type 'Success' -Text "Blocco WU driver impostato."
            $gpupdateResult = Invoke-WithSpinner -Activity "Aggiornamento criteri di gruppo (può impiegare 1-2 minuti)" -Command 'gpupdate.exe' -Arguments '/force' -LogContextKey "Video-GPUpdate" -TimeoutSeconds 180
            if ($gpupdateResult -and $gpupdateResult.ExitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "✅ Criteri di gruppo aggiornati."
            }
            elseif ($gpupdateResult) {
                Write-StyledMessage -Type 'Warning' -Text "⚠️  gpupdate completato con codice: $($gpupdateResult.ExitCode). Proseguo comunque."
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "⚠️  gpupdate non ha risposto. Proseguo comunque."
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "⚠️  Errore blocco WU driver: $($_.Exception.Message). Proseguo comunque."
        }
    }

    try {
        Write-StyledMessage -Type 'Info' -Text "🚀 Avvio installazione automatica driver video."
        Set-BlockWindowsUpdateDrivers
        
        Write-StyledMessage -Type 'Info' -Text "🔍 Rilevamento configurazione GPU in corso..."
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
                    Write-StyledMessage -Type 'Warning' -Text "GPU non rilevata: driver non disponibile per l'installazione automatica."
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
