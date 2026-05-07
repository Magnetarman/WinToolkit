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
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Start-ToolkitLog -ToolName "VideoDriverInstall"
    Show-Header -SubTitle "Video Driver Install Toolkit"
    $Host.UI.RawUI.WindowTitle = "Video Driver Install Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    $GitHubAssetBaseUrl = $AppConfig.URLs.GitHubAssetBaseUrl
    $DriverToolsLocalPath = $AppConfig.Paths.Drivers
    $DesktopPath = $AppConfig.Paths.Desktop

    # ============================================================================
    # 3. FUNZIONI HELPER LOCALI
    # ============================================================================

    function Get-GpuManufacturer {
        <#
        .SYNOPSIS
            Identifica il produttore della scheda grafica principale.
        .DESCRIPTION
            Ritorna 'NVIDIA', 'AMD', 'Intel' o 'Unknown' basandosi sui dispositivi Plug and Play.
        #>
        $pnpDevices = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue

        if (-not $pnpDevices) {
            Write-StyledMessage -Type 'Warning' -Text "Nessun dispositivo display Plug and Play rilevato."
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
        Write-StyledMessage -Type 'Info' -Text "Configurazione per bloccare download driver da Windows Update."

        $regPath = $AppConfig.Registry.WindowsUpdatePolicies
        $propertyName = "ExcludeWUDriversInQualityUpdate"
        $propertyValue = 1

        try {
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force *>$null
            }
            Set-ItemProperty -Path $regPath -Name $propertyName -Value $propertyValue -Type DWord -Force -ErrorAction Stop
            Write-StyledMessage -Type 'Success' -Text "Blocco download driver da Windows Update impostato correttamente nel registro."
            Write-StyledMessage -Type 'Info' -Text "Questa impostazione impedisce a Windows Update di installare driver automaticamente."
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante l'impostazione del blocco download driver da Windows Update: $($_.Exception.Message)."
            Write-StyledMessage -Type 'Warning' -Text "Potrebbe essere necessario eseguire lo script come amministratore."
            return
        }

        Write-StyledMessage -Type 'Info' -Text "Aggiornamento dei criteri di gruppo in corso per applicare le modifiche."
        try {
            $gpupdateProcess = Invoke-WithSpinner -Activity "Aggiornamento criteri di gruppo" -Command 'gpupdate.exe' -Arguments '/force' -LogContextKey "Video-GPUpdate"
            if ($gpupdateProcess.ExitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "Criteri di gruppo aggiornati con successo."
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "Aggiornamento dei criteri di gruppo completato con codice di uscita: $($gpupdateProcess.ExitCode)."
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante l'aggiornamento dei criteri di gruppo: $($_.Exception.Message)."
            Write-StyledMessage -Type 'Warning' -Text "Le modifiche ai criteri potrebbero richiedere un riavvio o del tempo per essere applicate."
        }
    }

    function Download-FileWithProgress {
        <#
        .SYNOPSIS
            Scarica un file con barra di progresso.
        .DESCRIPTION
            Scarica un file dall'URL specificato con barra di progresso che mostra la percentuale di download e gestione retry.
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

        Write-StyledMessage -Type 'Info' -Text "Scaricando $Description."

        $destDir = Split-Path -Path $DestinationPath -Parent
        if (-not (Test-Path $destDir)) {
            try {
                New-Item -ItemType Directory -Path $destDir -Force *>$null
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Impossibile creare la cartella di destinazione '$destDir': $($_.Exception.Message)."
                return $false
            }
        }

        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            try {
                $webRequest = [System.Net.WebRequest]::Create($Url)
                $webResponse = $webRequest.GetResponse()
                $totalBytes = $webResponse.ContentLength
                $responseStream = $webResponse.GetResponseStream()
                $targetStream = [System.IO.FileStream]::new($DestinationPath, [System.IO.FileMode]::Create)
                $buffer = New-Object byte[] 64KB
                $downloadedBytes = 0
                $bytesRead = 0

                # Inizializza la barra di progresso
                Write-Progress -Activity "Download $Description" -Status "Inizio download." -PercentComplete 0

                # Download con aggiornamento barra di progresso
                do {
                    $bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)
                    if ($bytesRead -gt 0) {
                        $targetStream.Write($buffer, 0, $bytesRead)
                        $downloadedBytes += $bytesRead

                        # Calcola la percentuale
                        $percentComplete = [System.Math]::Round(($downloadedBytes / $totalBytes) * 100, 1)
                        $speed = if ($downloadedBytes -gt 0) { [System.Math]::Round(($downloadedBytes / 1024 / 1024), 2) } else { 0 }
                        $totalSize = [System.Math]::Round(($totalBytes / 1024 / 1024), 2)

                        # Aggiorna la barra di progresso
                        Write-Progress -Activity "Download $Description" -Status "$speed MB / $totalSize MB" -PercentComplete $percentComplete
                    }
                } while ($bytesRead -gt 0)

                # Completa la barra di progresso
                Write-Progress -Activity "Download $Description" -Status "Completato" -PercentComplete 100 -Completed

                $targetStream.Flush()
                $targetStream.Close()
                $targetStream.Dispose()
                $responseStream.Dispose()
                $webResponse.Close()

                Write-StyledMessage -Type 'Success' -Text "Download di $Description completato."
                return $true
            }
            catch {
                Write-Progress -Activity "Download $Description" -Completed
                Write-StyledMessage -Type 'Warning' -Text "Tentativo $attempt fallito per $Description`: $($_.Exception.Message)."
                if ($attempt -lt $MaxRetries) {
                    Start-Sleep -Seconds 2
                }
            }
        }
        Write-StyledMessage -Type 'Error' -Text "Errore durante il download di $Description dopo $MaxRetries tentativi."
        return $false
    }

    function Handle-InstallVideoDrivers {
        <#
        .SYNOPSIS
            Gestisce l'installazione dei driver video.
        .DESCRIPTION
            Scarica e avvia l'installer appropriato per la GPU rilevata.
        #>
        Write-StyledMessage -Type 'Info' -Text "Opzione 1: Avvio installazione driver video."

        $gpuManufacturer = Get-GpuManufacturer
        Write-StyledMessage -Type 'Info' -Text "Rilevata GPU: $gpuManufacturer."

        if ($gpuManufacturer -eq 'AMD') {
            $amdInstallerUrl = $AppConfig.URLs.AMDInstaller
            $amdInstallerPath = Join-Path $DriverToolsLocalPath "AMD-Autodetect.exe"

            if (Download-FileWithProgress -Url $amdInstallerUrl -DestinationPath $amdInstallerPath -Description "AMD Auto-Detect Tool") {
                    Write-StyledMessage -Type 'Info' -Text "Avvio installazione driver video AMD. Premi un tasto per chiudere correttamente il terminale quando l'installazione è completata."
                Invoke-WithSpinner -Activity "Esecuzione installer AMD" -Command $amdInstallerPath -LogContextKey "Video-Install-AMD"
                Write-StyledMessage -Type 'Success' -Text "Installazione driver video AMD completata o chiusa."
            }
        }
        elseif ($gpuManufacturer -eq 'NVIDIA') {
            $nvidiaInstallerUrl = $AppConfig.URLs.NVCleanstall
            $nvidiaInstallerPath = Join-Path $DriverToolsLocalPath "NVCleanstall_1.19.0.exe"

            if (Download-FileWithProgress -Url $nvidiaInstallerUrl -DestinationPath $nvidiaInstallerPath -Description "NVCleanstall Tool") {
                    Write-StyledMessage -Type 'Info' -Text "Avvio installazione driver video NVIDIA Ottimizzato. Premi un tasto per chiudere correttamente il terminale quando l'installazione è completata."
                Invoke-WithSpinner -Activity "Esecuzione installer NVIDIA" -Command $nvidiaInstallerPath -LogContextKey "Video-Install-NVIDIA"
                        Write-StyledMessage -Type 'Success' -Text "Installazione driver video NVIDIA completata o chiusa."
            }
        }
        elseif ($gpuManufacturer -eq 'Intel') {
            Write-StyledMessage -Type 'Info' -Text "Rilevata GPU Intel. Utilizza Windows Update per aggiornare i driver integrati."
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Produttore GPU non supportato o non rilevato per l'installazione automatica dei driver."
        }
    }

    function Handle-ReinstallRepairVideoDrivers {
        <#
        .SYNOPSIS
            Gestisce la reinstallazione/riparazione dei driver video.
        .DESCRIPTION
            Scarica DDU e gli installer dei driver, configura la modalità provvisoria e riavvia.
        #>
        Write-StyledMessage -Type 'Warning' -Text "Opzione 2: Avvio procedura di reinstallazione/riparazione driver video. Richiesto riavvio."

        # Download DDU
        $dduZipUrl = $AppConfig.URLs.DDUZip
        $dduZipPath = Join-Path $DriverToolsLocalPath "DDU.zip"

        if (-not (Download-FileWithProgress -Url $dduZipUrl -DestinationPath $dduZipPath -Description "DDU (Display Driver Uninstaller)")) {
            Write-StyledMessage -Type 'Error' -Text "Impossibile scaricare DDU. Annullamento operazione."
            return
        }

        # Extract DDU to Desktop
        Write-StyledMessage -Type 'Info' -Text "Estrazione DDU sul Desktop."
        try {
            Expand-Archive -Path $dduZipPath -DestinationPath $DesktopPath -Force
            Write-StyledMessage -Type 'Success' -Text "DDU estratto correttamente sul Desktop."
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante l'estrazione di DDU sul Desktop: $($_.Exception.Message)."
            return
        }

        $gpuManufacturer = Get-GpuManufacturer
        Write-StyledMessage -Type 'Info' -Text "Rilevata GPU: $gpuManufacturer."

        if ($gpuManufacturer -eq 'AMD') {
            $amdInstallerUrl = $AppConfig.URLs.AMDInstaller
            $amdInstallerPath = Join-Path $DesktopPath "AMD-Autodetect.exe"

            if (-not (Download-FileWithProgress -Url $amdInstallerUrl -DestinationPath $amdInstallerPath -Description "AMD Auto-Detect Tool")) {
                Write-StyledMessage -Type 'Error' -Text "Impossibile scaricare l'installer AMD. Annullamento operazione."
                return
            }
        }
        elseif ($gpuManufacturer -eq 'NVIDIA') {
            $nvidiaInstallerUrl = $AppConfig.URLs.NVCleanstall
            $nvidiaInstallerPath = Join-Path $DesktopPath "NVCleanstall_1.19.0.exe"

            if (-not (Download-FileWithProgress -Url $nvidiaInstallerUrl -DestinationPath $nvidiaInstallerPath -Description "NVCleanstall Tool")) {
                Write-StyledMessage -Type 'Error' -Text "Impossibile scaricare l'installer NVIDIA. Annullamento operazione."
                return
            }
        }
        elseif ($gpuManufacturer -eq 'Intel') {
            Write-StyledMessage -Type 'Info' -Text "Rilevata GPU Intel. Scarica manualmente i driver da Intel se necessario."
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text "Produttore GPU non supportato o non rilevato. Verrà posizionato solo DDU sul desktop."
        }

        Write-StyledMessage -Type 'Info' -Text "DDU e l'installer dei Driver (se rilevato) sono stati posizionati sul desktop."

        # Creazione file batch per tornare alla modalità normale
        $batchFilePath = Join-Path $DesktopPath "Switch to Normal Mode.bat"
        try {
            Set-Content -Path $batchFilePath -Value 'bcdedit /deletevalue {current} safeboot' -Encoding ASCII
            Write-StyledMessage -Type 'Info' -Text "File batch 'Switch to Normal Mode.bat' creato sul desktop per disabilitare la Modalità Provvisoria."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile creare il file batch: $($_.Exception.Message)."
        }

        Write-StyledMessage -Type 'Error' -Text "ATTENZIONE: Il sistema sta per riavviarsi in modalità provvisoria."

        Write-StyledMessage -Type 'Info' -Text "Configurazione del sistema per l'avvio automatico in Modalità Provvisoria."
        try {
            Invoke-WithSpinner -Activity "Configurazione bcdedit" -Command 'bcdedit.exe' -Arguments '/set {current} safeboot minimal' -LogContextKey "Video-BCDEdit"
            Write-StyledMessage -Type 'Success' -Text "Modalità Provvisoria configurata per il prossimo avvio."
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante la configurazione della Modalità Provvisoria tramite bcdedit: $($_.Exception.Message)."
            Write-StyledMessage -Type 'Warning' -Text "Il riavvio potrebbe non avvenire in Modalità Provvisoria. Procedere manualmente."
            return
        }

        if ($SuppressIndividualReboot) {
            # In modalità concatenata, non riavviare in safe mode ma segnalare riavvio finale
            $Global:NeedsFinalReboot = $true
            Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio in modalità provvisoria soppresso (esecuzione concatenata)."
            Write-StyledMessage -Type 'Warning' -Text "⚠️ DDU e installer driver sono sul Desktop. Al prossimo riavvio sarai in SAFE MODE."
        }
        else {
            $shouldReboot = Start-InterruptibleCountdown -Seconds 30 -Message "Riavvio in modalità provvisoria in corso."

            if ($shouldReboot) {
                try {
                    Restart-Computer -Force
                    Write-StyledMessage -Type 'Success' -Text "Comando di riavvio inviato."
                }
                catch {
                    Write-StyledMessage -Type 'Error' -Text "Errore durante l'esecuzione del comando di riavvio: $($_.Exception.Message)."
                }
            }
        }
    }

    Write-StyledMessage -Type 'Info' -Text '🔧 Inizializzazione dello Script di Installazione Driver Video.'
    Start-Sleep -Seconds 2

    Set-BlockWindowsUpdateDrivers

    # Main Menu Logic
    $choice = ""
    do {


        Write-StyledMessage -Type 'Info' -Text 'Seleziona un''opzione:'
        Write-StyledMessage -Type 'Info' -Text '  [1] 🚀 Installa Driver Video (Rilevamento Automatico)'
        Write-StyledMessage -Type 'Info' -Text '  [2] 🔧 Reinstalla/Ripara Driver Video (Richiede Riavvio in Safe Mode)'
        Write-StyledMessage -Type 'Info' -Text '  [0] ❌ Torna al Menu Principale'

        $selections = Read-ValidatedChoice -Min 0 -Max 2 -Prompt "La tua scelta"
        $choice = $selections[0]

        switch ($choice.ToUpper()) {
            "1" { Handle-InstallVideoDrivers }
            "2" { Handle-ReinstallRepairVideoDrivers }
            "0" { Write-StyledMessage -Type 'Info' -Text 'Tornando al menu principale.' }
            default { Write-StyledMessage -Type 'Warning' -Text "Scelta non valida. Riprova." }
        }

        if ($choice.ToUpper() -ne "0") {

            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            Clear-Host
            Show-Header -SubTitle "Video Driver Install Toolkit"
        }

    } while ($choice.ToUpper() -ne "0")
}
