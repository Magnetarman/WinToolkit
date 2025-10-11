function SetRustDesk {
    <#
    .SYNOPSIS
        Configura ed installa RustDesk con configurazioni personalizzata su Windows.

    .DESCRIPTION
        Script ottimizzato per fermare servizi, reinstallare RustDesk e applicare configurazioni personalizzate.
        Scarica i file di configurazione da repository GitHub e riavvia il sistema per applicare le modifiche.
    #>

    param([int]$CountdownSeconds = 30)

    # Inizializzazione
    $Host.UI.RawUI.WindowTitle = "RustDesk Setup Toolkit By MagnetarMan"

    # Setup logging
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\SetRustDesk_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}

    # Configurazione
    $MsgStyles = @{
        Success  = @{ Color = 'Green'; Icon = '✅' }
        Warning  = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error    = @{ Color = 'Red'; Icon = '❌' }
        Info     = @{ Color = 'Cyan'; Icon = '💡' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }

    # Funzioni Helper
    function Center-Text {
        param(
            [Parameter(Mandatory = $true)][string]$Text,
            [Parameter(Mandatory = $false)][int]$Width = $Host.UI.RawUI.BufferSize.Width
        )
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }
    
    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            'RustDesk Setup Toolkit By MagnetarMan',
            '       Version 2.2.4 (Build 1)'
        )

        foreach ($line in $asciiArt) {
            if ($line -ne '') {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
            else {
                Write-Host ''
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Clear-ConsoleLine {
        $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
        Write-Host $clearLine -NoNewline
        [Console]::Out.Flush()
    }

    function Stop-RustDeskComponents {
        $servicesFound = $false
        foreach ($service in @("RustDesk", "rustdesk")) {
            $serviceObj = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($serviceObj) {
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                $servicesFound = $true
            }
        }
        
        if ($servicesFound) {
            Write-StyledMessage Success "Servizi RustDesk arrestati"
        }

        $processesFound = $false
        foreach ($process in @("rustdesk", "RustDesk")) {
            $runningProcesses = Get-Process -Name $process -ErrorAction SilentlyContinue
            if ($runningProcesses) {
                $runningProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
                $processesFound = $true
            }
        }
        
        if ($processesFound) {
            Write-StyledMessage Success "Processi RustDesk terminati"
        }
        
        if (-not $servicesFound -and -not $processesFound) {
            Write-StyledMessage Warning "Nessun componente RustDesk attivo trovato"
        }
        
        Start-Sleep 2
    }

    function Get-LatestRustDeskRelease {
        try {
            $apiUrl = "https://api.github.com/repos/rustdesk/rustdesk/releases/latest"
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
            $msiAsset = $response.assets | Where-Object { $_.name -like "rustdesk-*-x86_64.msi" } | Select-Object -First 1

            if ($msiAsset) {
                return @{
                    Version     = $response.tag_name
                    DownloadUrl = $msiAsset.browser_download_url
                    FileName    = $msiAsset.name
                }
            }

            Write-StyledMessage Error "Nessun installer .msi trovato nella release"
            return $null
        }
        catch {
            Write-StyledMessage Error "Errore connessione GitHub API: $($_.Exception.Message)"
            return $null
        }
    }

    function Download-RustDeskInstaller {
        param([string]$DownloadPath)

        Write-StyledMessage Progress "Download installer RustDesk in corso..."
        $releaseInfo = Get-LatestRustDeskRelease
        if (-not $releaseInfo) { return $false }

        Write-StyledMessage Info "📥 Versione rilevata: $($releaseInfo.Version)"
        $parentDir = Split-Path $DownloadPath -Parent
        
        try {
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            
            if (Test-Path $DownloadPath) {
                Remove-Item $DownloadPath -Force -ErrorAction Stop
            }

            Invoke-WebRequest -Uri $releaseInfo.DownloadUrl -OutFile $DownloadPath -UseBasicParsing -ErrorAction Stop
            
            if (Test-Path $DownloadPath) {
                Write-StyledMessage Success "Installer $($releaseInfo.FileName) scaricato con successo"
                return $true
            }
        }
        catch {
            Write-StyledMessage Error "Errore download: $($_.Exception.Message)"
        }

        return $false
    }

    function Install-RustDesk {
        param([string]$InstallerPath)

        Write-StyledMessage Progress "Installazione RustDesk"
        
        try {
            $installArgs = "/i", "`"$InstallerPath`"", "/quiet", "/norestart"
            $process = Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
            Start-Sleep 10

            if ($process.ExitCode -eq 0) {
                Write-StyledMessage Success "RustDesk installato"
                return $true
            }
            else {
                Write-StyledMessage Error "Errore installazione (Exit Code: $($process.ExitCode))"
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante installazione: $($_.Exception.Message)"
        }

        return $false
    }

    function Clear-RustDeskConfig {
        Write-StyledMessage Progress "Pulizia configurazioni esistenti..."
        $rustDeskDir = "$env:APPDATA\RustDesk"
        $configDir = "$rustDeskDir\config"

        try {
            if (-not (Test-Path $rustDeskDir)) {
                New-Item -ItemType Directory -Path $rustDeskDir -Force | Out-Null
                Write-StyledMessage Info "Cartella RustDesk creata"
            }

            if (Test-Path $configDir) {
                Remove-Item $configDir -Recurse -Force -ErrorAction Stop
                Write-StyledMessage Success "Cartella config eliminata"
                Start-Sleep 1
            }
            else {
                Write-StyledMessage Warning "Cartella config non trovata"
            }
        }
        catch {
            Write-StyledMessage Error "Errore pulizia config: $($_.Exception.Message)"
        }
    }

    function Download-RustDeskConfigFiles {
        Write-StyledMessage Progress "Download file di configurazione..."
        $configDir = "$env:APPDATA\RustDesk\config"
        
        try {
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            }

            $configFiles = @(
                "RustDesk.toml",
                "RustDesk_local.toml",
                "RustDesk2.toml"
            )

            $baseUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset"
            $downloaded = 0

            foreach ($fileName in $configFiles) {
                $url = "$baseUrl/$fileName"
                $filePath = Join-Path $configDir $fileName
                
                try {
                    Invoke-WebRequest -Uri $url -OutFile $filePath -UseBasicParsing -ErrorAction Stop
                    $downloaded++
                }
                catch {
                    Write-StyledMessage Error "Errore download $fileName`: $($_.Exception.Message)"
                }
            }

            if ($downloaded -eq $configFiles.Count) {
                Write-StyledMessage Success "Tutti i file di configurazione scaricati ($downloaded/$($configFiles.Count))"
            }
            else {
                Write-StyledMessage Warning "Scaricati $downloaded/$($configFiles.Count) file di configurazione"
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante download configurazioni: $($_.Exception.Message)"
        }
    }

    function Start-CountdownRestart([string]$Reason) {
        Write-StyledMessage Info "🔄 $Reason - Il sistema verrà riavviato"
        Write-StyledMessage Info "💡 Premi un tasto qualsiasi per annullare..."

        for ($i = $CountdownSeconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning "⏸️ Riavvio annullato dall'utente"
                return $false
            }

            $percent = [Math]::Round((($CountdownSeconds - $i) / $CountdownSeconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('░' * $remaining)] $percent%"
            
            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            [Console]::Out.Flush()
            Start-Sleep 1
        }

        Clear-ConsoleLine
        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."
        
        try {
            Restart-Computer -Force
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore durante riavvio: $($_.Exception.Message)"
            return $false
        }
    }

    # === ESECUZIONE PRINCIPALE ===
    Show-Header
    Write-StyledMessage Info "🚀 AVVIO CONFIGURAZIONE RUSTDESK"

    try {
        $installerPath = "$env:LOCALAPPDATA\WinToolkit\rustdesk\rustdesk-installer.msi"

        # FASE 1: Stop servizi e processi
        Write-StyledMessage Info "📋 FASE 1: Arresto servizi e processi RustDesk"
        Stop-RustDeskComponents

        # FASE 2: Download e installazione
        Write-StyledMessage Info "📋 FASE 2: Download e installazione"
        if (-not (Download-RustDeskInstaller -DownloadPath $installerPath)) {
            Write-StyledMessage Error "Impossibile procedere senza l'installer"
            return
        }
        
        if (-not (Install-RustDesk -InstallerPath $installerPath)) {
            Write-StyledMessage Error "Errore durante l'installazione"
            return
        }

        # FASE 3: Verifica processi e pulizia
        Write-StyledMessage Info "📋 FASE 3: Verifica processi e pulizia"
        Stop-RustDeskComponents

        # FASE 4: Pulizia configurazioni
        Write-StyledMessage Info "📋 FASE 4: Pulizia configurazioni"
        Clear-RustDeskConfig

        # FASE 5: Download configurazioni
        Write-StyledMessage Info "📋 FASE 5: Download configurazioni"
        Download-RustDeskConfigFiles

        Write-Host ""
        Write-StyledMessage Success "🎉 CONFIGURAZIONE RUSTDESK COMPLETATA"
        Write-StyledMessage Info "🔄 Per applicare le modifiche il PC verrà riavviato"
        Start-CountdownRestart -Reason "Per applicare le modifiche è necessario riavviare il sistema"
    }
    catch {
        Write-StyledMessage Error "ERRORE CRITICO: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Verifica connessione Internet e riprova"
    }
    finally {
        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        Write-StyledMessage Success "🎯 Setup RustDesk terminato"
        try { Stop-Transcript | Out-Null } catch {}
    }
}

SetRustDesk