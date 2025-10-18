function VideoDriverInstall {
    <#
    .SYNOPSIS
        Toolkit Driver Grafici - Installazione e configurazione driver GPU.

    .DESCRIPTION
        Script per l'installazione e configurazione ottimale dei driver grafici:
        - Rilevamento automatico GPU (NVIDIA, AMD, Intel)
        - Download driver più recenti dal sito ufficiale
        - Installazione pulita con pulizia precedente
        - Configurazione ottimale per gaming e prestazioni
        - Installazione software di controllo (GeForce Experience, AMD Software)
    #>

    param([int]$CountdownSeconds = 30)

    $Host.UI.RawUI.WindowTitle = "Driver Install Toolkit By MagnetarMan"
    $script:Log = @(); $script:CurrentAttempt = 0
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    # --- NEW: Define Constants and Paths ---
    $GitHubAssetBaseUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/"
    $DriverToolsLocalPath = Join-Path $env:LOCALAPPDATA "WinToolkit\Drivers"
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
    # --- END NEW ---

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('=' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            ' Video Driver Install Toolkit By MagnetarMan',
            '       Version 2.3.0 (Build 7)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )

        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }

    function Get-GpuManufacturer {
        <#
        .SYNOPSIS
            Identifies the manufacturer of the primary display adapter.
        .RETURNS
            'NVIDIA', 'AMD', 'Intel' or 'Unknown'
        #>
        $pnpDevices = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue

        if (-not $pnpDevices) {
            Write-StyledMessage 'Warning' "Nessun dispositivo display Plug and Play rilevato."
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
                return 'Intel' # While not explicitly requested for actions, it's good to identify.
            }
        }
        return 'Unknown'
    }

    function Set-BlockWindowsUpdateDrivers {
        <#
        .SYNOPSIS
            Blocks Windows Update from automatically downloading and installing drivers.
        .DESCRIPTION
            This function sets a registry key that prevents Windows Update from
            including drivers in quality updates, reducing conflicts with
            manufacturer-specific driver installations. It then forces a Group Policy update.
            Requires administrative privileges.
        #>
        Write-StyledMessage 'Info' "Configurazione per bloccare download driver da Windows Update..."

        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        $propertyName = "ExcludeWUDriversInQualityUpdate"
        $propertyValue = 1

        try {
            # Ensure the parent path exists
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }

            # Set the registry key to block driver downloads
            Set-ItemProperty -Path $regPath -Name $propertyName -Value $propertyValue -Type DWord -Force -ErrorAction Stop
            Write-StyledMessage 'Success' "Blocco download driver da Windows Update impostato correttamente nel registro."
            Write-StyledMessage 'Info' "Questa impostazione impedisce a Windows Update di installare driver automaticamente."
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante l'impostazione del blocco download driver da Windows Update: $($_.Exception.Message)"
            Write-StyledMessage 'Warning' "Potrebbe essere necessario eseguire lo script come amministratore."
            # Continue without forcing gpupdate if registry failed, as gpupdate won't reflect the change anyway.
            return
        }

        # Force Group Policy update
        Write-StyledMessage 'Info' "Aggiornamento dei criteri di gruppo in corso per applicare le modifiche..."
        try {
            # Use Start-Process with -Wait for gpupdate as it's an external executable
            $gpupdateProcess = Start-Process -FilePath "gpupdate.exe" -ArgumentList "/force" -Wait -NoNewWindow -PassThru -ErrorAction Stop
            if ($gpupdateProcess.ExitCode -eq 0) {
                Write-StyledMessage 'Success' "Criteri di gruppo aggiornati con successo."
            }
            else {
                Write-StyledMessage 'Warning' "Aggiornamento dei criteri di gruppo completato con codice di uscita non zero: $($gpupdateProcess.ExitCode)."
            }
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante l'aggiornamento dei criteri di gruppo: $($_.Exception.Message)"
            Write-StyledMessage 'Warning' "Le modifiche ai criteri potrebbero richiedere un riavvio o del tempo per essere applicate."
        }
    }

    function Download-FileWithProgress {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Url,
            [Parameter(Mandatory = $true)]
            [string]$DestinationPath,
            [Parameter(Mandatory = $true)]
            [string]$Description,
            [int]$MaxRetries = 3
        )

        Write-StyledMessage 'Info' "Scaricando $Description..."

        $destDir = Split-Path -Path $DestinationPath -Parent
        if (-not (Test-Path $destDir)) {
            try {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            catch {
                Write-StyledMessage 'Error' "Impossibile creare la cartella di destinazione '$destDir': $($_.Exception.Message)"
                return $false
            }
        }

        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            try {
                Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -UseBasicParsing -ErrorAction Stop
                Write-StyledMessage 'Success' "Download di $Description completato."
                return $true
            }
            catch {
                Write-StyledMessage 'Warning' "Tentativo $attempt fallito per $Description`: $($_.Exception.Message)"
                if ($attempt -lt $MaxRetries) {
                    Start-Sleep -Seconds 2
                }
            }
        }
        Write-StyledMessage 'Error' "Errore durante il download di $Description dopo $MaxRetries tentativi."
        return $false
    }

    function Start-InverseCountdown {
        param(
            [Parameter(Mandatory = $true)]
            [int]$Seconds,
            [Parameter(Mandatory = $true)]
            [string]$Message
        )

        for ($i = $Seconds; $i -gt 0; $i--) {
            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r$($MsgStyles.Error.Icon) $Message tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep -Seconds 1
        }

        Write-Host "`r$($MsgStyles.Error.Icon) $Message tra 0 secondi [$('█' * 20)] 100%`n" -ForegroundColor Red
    }

    function Handle-InstallVideoDrivers {
        Write-StyledMessage 'Info' "Opzione 1: Avvio installazione driver video."

        $gpuManufacturer = Get-GpuManufacturer
        Write-StyledMessage 'Info' "Rilevata GPU: $gpuManufacturer"

        if ($gpuManufacturer -eq 'AMD') {
            $amdInstallerUrl = "${GitHubAssetBaseUrl}AMD-Autodetect.exe"
            $amdInstallerPath = Join-Path $DriverToolsLocalPath "AMD-Autodetect.exe"

            if (Download-FileWithProgress -Url $amdInstallerUrl -DestinationPath $amdInstallerPath -Description "AMD Auto-Detect Tool") {
                Write-StyledMessage 'Info' "Avvio installazione driver video AMD. Premi un tasto per chiudere correttamente il terminale quando l'installazione è completata."
                Start-Process -FilePath $amdInstallerPath -Wait -ErrorAction SilentlyContinue
                Write-StyledMessage 'Success' "Installazione driver video AMD completata o chiusa."
            }
        }
        elseif ($gpuManufacturer -eq 'NVIDIA') {
            $nvidiaInstallerUrl = "${GitHubAssetBaseUrl}NVCleanstall_1.19.0.exe"
            $nvidiaInstallerPath = Join-Path $DriverToolsLocalPath "NVCleanstall_1.19.0.exe"

            if (Download-FileWithProgress -Url $nvidiaInstallerUrl -DestinationPath $nvidiaInstallerPath -Description "NVCleanstall Tool") {
                Write-StyledMessage 'Info' "Avvio installazione driver video NVIDIA Ottimizzato. Premi un tasto per chiudere correttamente il terminale quando l'installazione è completata."
                Start-Process -FilePath $nvidiaInstallerPath -Wait -ErrorAction SilentlyContinue
                Write-StyledMessage 'Success' "Installazione driver video NVIDIA completata o chiusa."
            }
        }
        elseif ($gpuManufacturer -eq 'Intel') {
            Write-StyledMessage 'Info' "Rilevata GPU Intel. Utilizza Windows Update per aggiornare i driver integrati."
        }
        else {
            Write-StyledMessage 'Error' "Produttore GPU non supportato o non rilevato per l'installazione automatica dei driver."
        }
    }

    function Handle-ReinstallRepairVideoDrivers {
        Write-StyledMessage 'Warning' "Opzione 2: Avvio procedura di reinstallazione/riparazione driver video. Richiesto riavvio."

        # Download DDU
        $dduZipUrl = "${GitHubAssetBaseUrl}DDU-18.1.3.5.zip"
        $dduZipPath = Join-Path $DriverToolsLocalPath "DDU-18.1.3.5.zip"

        if (-not (Download-FileWithProgress -Url $dduZipUrl -DestinationPath $dduZipPath -Description "DDU (Display Driver Uninstaller)")) {
            Write-StyledMessage 'Error' "Impossibile scaricare DDU. Annullamento operazione."
            return
        }

        # Extract DDU to Desktop
        Write-StyledMessage 'Info' "Estrazione DDU sul Desktop..."
        try {
            # Expand-Archive extracts to a folder with the same name as the zip file on the destination path.
            Expand-Archive -Path $dduZipPath -DestinationPath $DesktopPath -Force
            Write-StyledMessage 'Success' "DDU estratto correttamente sul Desktop."
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante l'estrazione di DDU sul Desktop: $($_.Exception.Message)"
            return
        }

        $gpuManufacturer = Get-GpuManufacturer
        Write-StyledMessage 'Info' "Rilevata GPU: $gpuManufacturer"

        if ($gpuManufacturer -eq 'AMD') {
            $amdInstallerUrl = "${GitHubAssetBaseUrl}AMD-Autodetect.exe"
            $amdInstallerPath = Join-Path $DesktopPath "AMD-Autodetect.exe" # Download to Desktop

            if (-not (Download-FileWithProgress -Url $amdInstallerUrl -DestinationPath $amdInstallerPath -Description "AMD Auto-Detect Tool")) {
                Write-StyledMessage 'Error' "Impossibile scaricare l'installer AMD. Annullamento operazione."
                return
            }
        }
        elseif ($gpuManufacturer -eq 'NVIDIA') {
            $nvidiaInstallerUrl = "${GitHubAssetBaseUrl}NVCleanstall_1.19.0.exe"
            $nvidiaInstallerPath = Join-Path $DesktopPath "NVCleanstall_1.19.0.exe" # Download to Desktop

            if (-not (Download-FileWithProgress -Url $nvidiaInstallerUrl -DestinationPath $nvidiaInstallerPath -Description "NVCleanstall Tool")) {
                Write-StyledMessage 'Error' "Impossibile scaricare l'installer NVIDIA. Annullamento operazione."
                return
            }
        }
        elseif ($gpuManufacturer -eq 'Intel') {
            Write-StyledMessage 'Info' "Rilevata GPU Intel. Scarica manualmente i driver da Intel se necessario."
        }
        else {
            Write-StyledMessage 'Warning' "Produttore GPU non supportato o non rilevato. Verrà posizionato solo DDU sul desktop."
        }

        Write-StyledMessage 'Info' "DDU e l'installer dei Driver (se rilevato) sono stati posizionati sul desktop."
        Write-StyledMessage 'Error' "ATTENZIONE: Il sistema sta per riavviarsi in modalità avanzata per permettere l'accesso alla modalità provvisoria."

        Start-InverseCountdown -Seconds 30 -Message "Riavvio in modalità avanzata in corso..."

        try {
            # Note: shutdown -o triggers advanced startup options, not direct safe mode boot.
            # User will need to manually select Safe Mode from the options.
            shutdown -r -o -t 0
            Write-StyledMessage 'Success' "Comando di riavvio inviato."
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante l'esecuzione del comando di riavvio: $($_.Exception.Message)"
        }
    }

    Show-Header

    # --- NEW: Call function to block Windows Update driver downloads ---
    Set-BlockWindowsUpdateDrivers
    # --- END NEW ---

    # --- NEW: Main Menu Logic ---
    $choice = ""
    do {
        Write-Host ""
        Write-StyledMessage 'Info' 'Seleziona un''opzione:'
        Write-Host "  1) Installa Driver Video"
        Write-Host "  2) Reinstalla/Ripara Driver Video"
        Write-Host "  Q) Torna al menu principale"
        Write-Host ""
        $choice = Read-Host "La tua scelta"
        Write-Host ""

        switch ($choice.ToUpper()) {
            "1" { Handle-InstallVideoDrivers }
            "2" { Handle-ReinstallRepairVideoDrivers }
            "Q" { Write-StyledMessage 'Info' 'Tornando al menu principale.' }
            default { Write-StyledMessage 'Warning' "Scelta non valida. Riprova." }
        }

        if ($choice.ToUpper() -ne "Q") {
            Write-Host "Premi un tasto per continuare..."
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            Clear-Host
            Show-Header
        }

    } while ($choice.ToUpper() -ne "Q")
    # --- END NEW ---
}