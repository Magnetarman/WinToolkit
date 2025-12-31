function VideoDriverInstall {
    <#
    .SYNOPSIS
        Toolkit per l'installazione e riparazione dei driver grafici.

    .DESCRIPTION
        Questo script PowerShell è progettato per l'installazione e la riparazione dei driver grafici,
        inclusa la pulizia completa con DDU e il download dei driver ufficiali per NVIDIA e AMD.
        Utilizza un'interfaccia utente migliorata con messaggi stilizzati, spinner e
        un conto alla rovescia per il riavvio in modalità provvisoria che può essere interrotto.
    #>

    [CmdletBinding()]
    param([int]$CountdownSeconds = 30)

    Initialize-ToolLogging -ToolName "VideoDriverInstall"
    Show-Header -SubTitle "Video Driver Install Toolkit"

    # --- NEW: Define Constants and Paths ---
    $GitHubAssetBaseUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/main/asset/"
    $DriverToolsLocalPath = Join-Path $env:LOCALAPPDATA "WinToolkit\Drivers"
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
    # --- END NEW ---

    function Get-GpuManufacturer {
        <#
        .SYNOPSIS
            Identifica il produttore della scheda grafica principale.
        .DESCRIPTION
            Ritorna 'NVIDIA', 'AMD', 'Intel' o 'Unknown' basandosi sui dispositivi Plug and Play.
        #>
        $pnpDevices = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue

        if (-not $pnpDevices) {
            Write-StyledMessage Warning "Nessun dispositivo display Plug and Play rilevato."
            return 'Unknown'
        }

        foreach ($device in $pnpDevices) {
            $manufacturer = $device.Manufacturer
            $friendlyName = $device.FriendlyName

            if ($friendlyName -match 'NVIDIA|GeForce|Quadro|Tesla' -or $manufacturer -match 'NVIDIA') {
                return 'NVIDIA'
            }
            elseif ($friendlyName -match 'AMD|Radeon|ATI' -or $manufacturer -match 'AMD|ATI') {
                return 'AMD'
            }
            elseif ($friendlyName -match 'Intel|Iris|UHD|HD Graphics' -or $manufacturer -match 'Intel') {
                return 'Intel'
            }
        }
        return 'Unknown'
    }

    function Set-BlockWindowsUpdateDrivers {
        <#
        .SYNOPSIS
            Blocca Windows Update dal scaricare automaticamente i driver.
        .DESCRIPTION
            Imposta una chiave di registro per impedire a Windows Update di includere driver negli aggiornamenti di qualità,
            riducendo conflitti con installazioni specifiche del produttore. Richiede privilegi amministrativi.
        #>
        Write-StyledMessage Info "Configurazione per bloccare download driver da Windows Update..."

        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        $propertyName = "ExcludeWUDriversInQualityUpdate"
        $propertyValue = 1

        try {
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            Set-ItemProperty -Path $regPath -Name $propertyName -Value $propertyValue -Type DWord -Force -ErrorAction Stop
            Write-StyledMessage Success "Blocco download driver da Windows Update impostato correttamente nel registro."
            Write-StyledMessage Info "Questa impostazione impedisce a Windows Update di installare driver automaticamente."
        }
        catch {
            Write-StyledMessage Error "Errore durante l'impostazione del blocco download driver da Windows Update: $($_.Exception.Message)"
            Write-StyledMessage Warning "Potrebbe essere necessario eseguire lo script come amministratore."
            return
        }

        Write-StyledMessage Info "Aggiornamento dei criteri di gruppo in corso per applicare le modifiche..."
        try {
            $gpupdateProcess = Start-Process -FilePath "gpupdate.exe" -ArgumentList "/force" -Wait -NoNewWindow -PassThru -ErrorAction Stop
            if ($gpupdateProcess.ExitCode -eq 0) {
                Write-StyledMessage Success "Criteri di gruppo aggiornati con successo."
            }
            else {
                Write-StyledMessage Warning "Aggiornamento dei criteri di gruppo completato con codice di uscita non zero: $($gpupdateProcess.ExitCode)."
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante l'aggiornamento dei criteri di gruppo: $($_.Exception.Message)"
            Write-StyledMessage Warning "Le modifiche ai criteri potrebbero richiedere un riavvio o del tempo per essere applicate."
        }
    }

    function Download-FileWithProgress {
        <#
        .SYNOPSIS
            Scarica un file con indicatore di progresso.
        .DESCRIPTION
            Scarica un file dall'URL specificato con spinner di progresso e gestione retry.
        #>
        param(
            [Parameter(Mandatory = $true)]
            [string]$Url,
            [Parameter(Mandatory = $true)]
            [string]$DestinationPath,
            [Parameter(Mandatory = $true)]
            [string]$Description,
            [int]$MaxRetries = 3
        )

        Write-StyledMessage Info "Scaricando $Description..."

        $destDir = Split-Path -Path $DestinationPath -Parent
        if (-not (Test-Path $destDir)) {
            try {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            catch {
                Write-StyledMessage Error "Impossibile creare la cartella di destinazione '$destDir': $($_.Exception.Message)"
                return $false
            }
        }

        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            try {
                $spinnerIndex = 0
                $webRequest = [System.Net.WebRequest]::Create($Url)
                $webResponse = $webRequest.GetResponse()
                $totalLength = [System.Math]::Floor($webResponse.ContentLength / 1024)
                $responseStream = $webResponse.GetResponseStream()
                $targetStream = [System.IO.FileStream]::new($DestinationPath, [System.IO.FileMode]::Create)
                $buffer = New-Object byte[] 10KB
                $count = $responseStream.Read($buffer, 0, $buffer.Length)
                $downloadedBytes = $count

                while ($count -gt 0) {
                    $targetStream.Write($buffer, 0, $count)
                    $count = $responseStream.Read($buffer, 0, $buffer.Length)
                    $downloadedBytes += $count

                    $spinner = $Global:Spinners[$spinnerIndex % $Global:Spinners.Length]
                    $percent = [math]::Min(100, [math]::Round(($downloadedBytes / $webResponse.ContentLength) * 100))

                    Show-ProgressBar -Activity "Download $Description" -Status "$percent%" -Percent $percent -Icon '💾' -Spinner $spinner

                    $spinnerIndex++
                    # Start-Sleep -Milliseconds 100 # Removed sleep for faster download
                }


                $targetStream.Flush()
                $targetStream.Close()
                $targetStream.Dispose()
                $responseStream.Dispose()
                $webResponse.Close()

                Write-StyledMessage Success "Download di $Description completato."
                return $true
            }
            catch {
                Write-StyledMessage Warning "Tentativo $attempt fallito per $Description`: $($_.Exception.Message)"
                if ($attempt -lt $MaxRetries) {
                    Start-Sleep -Seconds 2
                }
            }
        }
        Write-StyledMessage Error "Errore durante il download di $Description dopo $MaxRetries tentativi."
        return $false
    }

    function Handle-InstallVideoDrivers {
        <#
        .SYNOPSIS
            Gestisce l'installazione dei driver video.
        .DESCRIPTION
            Scarica e avvia l'installer appropriato per la GPU rilevata.
        #>
        Write-StyledMessage Info "Opzione 1: Avvio installazione driver video."

        $gpuManufacturer = Get-GpuManufacturer
        Write-StyledMessage Info "Rilevata GPU: $gpuManufacturer"

        if ($gpuManufacturer -eq 'AMD') {
            $amdInstallerUrl = "${GitHubAssetBaseUrl}AMD-Autodetect.exe"
            $amdInstallerPath = Join-Path $DriverToolsLocalPath "AMD-Autodetect.exe"

            if (Download-FileWithProgress -Url $amdInstallerUrl -DestinationPath $amdInstallerPath -Description "AMD Auto-Detect Tool") {
                Write-StyledMessage Info "Avvio installazione driver video AMD. Premi un tasto per chiudere correttamente il terminale quando l'installazione è completata."
                Start-Process -FilePath $amdInstallerPath -Wait -ErrorAction SilentlyContinue
                Write-StyledMessage Success "Installazione driver video AMD completata o chiusa."
            }
        }
        elseif ($gpuManufacturer -eq 'NVIDIA') {
            $nvidiaInstallerUrl = "${GitHubAssetBaseUrl}NVCleanstall_1.19.0.exe"
            $nvidiaInstallerPath = Join-Path $DriverToolsLocalPath "NVCleanstall_1.19.0.exe"

            if (Download-FileWithProgress -Url $nvidiaInstallerUrl -DestinationPath $nvidiaInstallerPath -Description "NVCleanstall Tool") {
                Write-StyledMessage Info "Avvio installazione driver video NVIDIA Ottimizzato. Premi un tasto per chiudere correttamente il terminale quando l'installazione è completata."
                Start-Process -FilePath $nvidiaInstallerPath -Wait -ErrorAction SilentlyContinue
                Write-StyledMessage Success "Installazione driver video NVIDIA completata o chiusa."
            }
        }
        elseif ($gpuManufacturer -eq 'Intel') {
            Write-StyledMessage Info "Rilevata GPU Intel. Utilizza Windows Update per aggiornare i driver integrati."
        }
        else {
            Write-StyledMessage Error "Produttore GPU non supportato o non rilevato per l'installazione automatica dei driver."
        }
    }

    function Handle-ReinstallRepairVideoDrivers {
        <#
        .SYNOPSIS
            Gestisce la reinstallazione/riparazione dei driver video.
        .DESCRIPTION
            Scarica DDU e gli installer dei driver, configura la modalità provvisoria e riavvia.
        #>
        Write-StyledMessage Warning "Opzione 2: Avvio procedura di reinstallazione/riparazione driver video. Richiesto riavvio."

        # Download DDU
        $dduZipUrl = "${GitHubAssetBaseUrl}DDU.zip"
        $dduZipPath = Join-Path $DriverToolsLocalPath "DDU.zip"

        if (-not (Download-FileWithProgress -Url $dduZipUrl -DestinationPath $dduZipPath -Description "DDU (Display Driver Uninstaller)")) {
            Write-StyledMessage Error "Impossibile scaricare DDU. Annullamento operazione."
            return
        }

        # Extract DDU to Desktop
        Write-StyledMessage Info "Estrazione DDU sul Desktop..."
        try {
            Expand-Archive -Path $dduZipPath -DestinationPath $DesktopPath -Force
            Write-StyledMessage Success "DDU estratto correttamente sul Desktop."
        }
        catch {
            Write-StyledMessage Error "Errore durante l'estrazione di DDU sul Desktop: $($_.Exception.Message)"
            return
        }

        $gpuManufacturer = Get-GpuManufacturer
        Write-StyledMessage Info "Rilevata GPU: $gpuManufacturer"

        if ($gpuManufacturer -eq 'AMD') {
            $amdInstallerUrl = "${GitHubAssetBaseUrl}AMD-Autodetect.exe"
            $amdInstallerPath = Join-Path $DesktopPath "AMD-Autodetect.exe"

            if (-not (Download-FileWithProgress -Url $amdInstallerUrl -DestinationPath $amdInstallerPath -Description "AMD Auto-Detect Tool")) {
                Write-StyledMessage Error "Impossibile scaricare l'installer AMD. Annullamento operazione."
                return
            }
        }
        elseif ($gpuManufacturer -eq 'NVIDIA') {
            $nvidiaInstallerUrl = "${GitHubAssetBaseUrl}NVCleanstall_1.19.0.exe"
            $nvidiaInstallerPath = Join-Path $DesktopPath "NVCleanstall_1.19.0.exe"

            if (-not (Download-FileWithProgress -Url $nvidiaInstallerUrl -DestinationPath $nvidiaInstallerPath -Description "NVCleanstall Tool")) {
                Write-StyledMessage Error "Impossibile scaricare l'installer NVIDIA. Annullamento operazione."
                return
            }
        }
        elseif ($gpuManufacturer -eq 'Intel') {
            Write-StyledMessage Info "Rilevata GPU Intel. Scarica manualmente i driver da Intel se necessario."
        }
        else {
            Write-StyledMessage Warning "Produttore GPU non supportato o non rilevato. Verrà posizionato solo DDU sul desktop."
        }

        Write-StyledMessage Info "DDU e l'installer dei Driver (se rilevato) sono stati posizionati sul desktop."

        # Creazione file batch per tornare alla modalità normale
        $batchFilePath = Join-Path $DesktopPath "Switch to Normal Mode.bat"
        try {
            Set-Content -Path $batchFilePath -Value 'bcdedit /deletevalue {current} safeboot' -Encoding ASCII
            Write-StyledMessage Info "File batch 'Switch to Normal Mode.bat' creato sul desktop per disabilitare la Modalità Provvisoria."
        }
        catch {
            Write-StyledMessage Warning "Impossibile creare il file batch: $($_.Exception.Message)"
        }

        Write-StyledMessage Error "ATTENZIONE: Il sistema sta per riavviarsi in modalità provvisoria."

        Write-StyledMessage Info "Configurazione del sistema per l'avvio automatico in Modalità Provvisoria..."
        try {
            Start-Process -FilePath "bcdedit.exe" -ArgumentList "/set {current} safeboot minimal" -Wait -NoNewWindow -ErrorAction Stop
            Write-StyledMessage Success "Modalità Provvisoria configurata per il prossimo avvio."
        }
        catch {
            Write-StyledMessage Error "Errore durante la configurazione della Modalità Provvisoria tramite bcdedit: $($_.Exception.Message)"
            Write-StyledMessage Warning "Il riavvio potrebbe non avvenire in Modalità Provvisoria. Procedere manualmente."
            return
        }

        $shouldReboot = Start-InterruptibleCountdown -Seconds 30 -Message "Riavvio in modalità provvisoria in corso..."

        if ($shouldReboot) {
            try {
                shutdown /r /t 0
                Write-StyledMessage Success "Comando di riavvio inviato."
            }
            catch {
                Write-StyledMessage Error "Errore durante l'esecuzione del comando di riavvio: $($_.Exception.Message)"
            }
        }
    }

    Write-StyledMessage Info '🔧 Inizializzazione dello Script di Installazione Driver Video...'
    Start-Sleep -Seconds 2

    Set-BlockWindowsUpdateDrivers

    # Main Menu Logic
    $choice = ""
    do {
        Write-Host ""
        Write-StyledMessage Info 'Seleziona un''opzione:'
        Write-Host "  1) Installa Driver Video"
        Write-Host "  2) Reinstalla/Ripara Driver Video"
        Write-Host "  0) Torna al menu principale"
        Write-Host ""
        $choice = Read-Host "La tua scelta"
        Write-Host ""

        switch ($choice.ToUpper()) {
            "1" { Handle-InstallVideoDrivers }
            "2" { Handle-ReinstallRepairVideoDrivers }
            "0" { Write-StyledMessage Info 'Tornando al menu principale.' }
            default { Write-StyledMessage Warning "Scelta non valida. Riprova." }
        }

        if ($choice.ToUpper() -ne "0") {
            Write-Host "Premi un tasto per continuare..."
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            Clear-Host
            Show-Header -SubTitle "Video Driver Install Toolkit"
        }

    } while ($choice.ToUpper() -ne "0")
}
