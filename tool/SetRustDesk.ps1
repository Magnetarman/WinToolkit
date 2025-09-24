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

    # Configurazione globale
    $MsgStyles = @{
        Success  = @{ Color = 'Green'; Icon = '✅' }
        Warning  = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error    = @{ Color = 'Red'; Icon = '❌' }
        Info     = @{ Color = 'Cyan'; Icon = '💎' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }

    # Funzione per centrare il testo
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
            '       Version 2.2 (Build 10)'
        )

        foreach ($line in $asciiArt) {
            Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Stop-RustDeskComponents {
        $servicesFound = $false
        foreach ($service in @("RustDesk", "rustdesk")) {
            $serviceObj = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($serviceObj) {
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                Write-StyledMessage Success "Servizio $service arrestato"
                $servicesFound = $true
            }
        }
        if (-not $servicesFound) {
            Write-StyledMessage Warning "Nessun servizio RustDesk trovato - Proseguo con l'installazione"
        }

        $processesFound = $false
        foreach ($process in @("rustdesk", "RustDesk")) {
            $runningProcesses = Get-Process -Name $process -ErrorAction SilentlyContinue
            if ($runningProcesses) {
                $runningProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
                Write-StyledMessage Success "Processi $process terminati"
                $processesFound = $true
            }
        }
        if (-not $processesFound) {
            Write-StyledMessage Warning "Nessun processo RustDesk trovato"
        }
        Start-Sleep 2
    }

    function Get-LatestRustDeskRelease {
        $apiUrl = "https://api.github.com/repos/rustdesk/rustdesk/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get
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

    function Download-RustDeskInstaller {
        param([string]$DownloadPath)

        Write-StyledMessage Progress "Download installer RustDesk in corso..."
        $releaseInfo = Get-LatestRustDeskRelease
        if (-not $releaseInfo) { return $false }

        Write-StyledMessage Info "📥 Versione rilevata: $($releaseInfo.Version)"
        $parentDir = Split-Path $DownloadPath -Parent
        $null = New-Item -ItemType Directory -Path $parentDir -Force
        Remove-Item $DownloadPath -Force -ErrorAction SilentlyContinue

        Invoke-WebRequest -Uri $releaseInfo.DownloadUrl -OutFile $DownloadPath -UseBasicParsing
        if (Test-Path $DownloadPath) {
            Write-StyledMessage Success "Installer $($releaseInfo.FileName) scaricato con successo"
            return $true
        }

        Write-StyledMessage Error "Errore nel download dell'installer"
        return $false
    }

    function Install-RustDesk {
        param([string]$InstallerPath, [string]$ServerIP)

        Write-StyledMessage Progress "Installazione RustDesk"
        $installArgs = "/i", "`"$InstallerPath`"", "/quiet", "/norestart"
        $process = Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -WindowStyle Hidden
        Start-Sleep 10

        if ($process.ExitCode -eq 0) {
            Write-StyledMessage Success "RustDesk installato"
            return $true
        }

        Write-StyledMessage Error "Errore installazione (Exit Code: $($process.ExitCode))"
        return $false
    }

    function Clear-RustDeskConfig {
        Write-StyledMessage Progress "Pulizia configurazioni esistenti..."
        $configDir = "$env:APPDATA\RustDesk\config"

        if (Test-Path $configDir) {
            Remove-Item $configDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-StyledMessage Success "Cartella config eliminata"
            Start-Sleep 1
        }
        else {
            Write-StyledMessage Warning "Cartella config non trovata - Potrebbe essere la prima installazione"
        }
    }

    function Download-RustDeskConfigFiles {
        Write-StyledMessage Progress "Download file di configurazione..."
        $configDir = "$env:APPDATA\RustDesk\config"
        $null = New-Item -ItemType Directory -Path $configDir -Force

        $configFiles = @(
            "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/RustDesk.toml",
            "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/RustDesk_local.toml",
            "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/RustDesk2.toml"
        )

        foreach ($url in $configFiles) {
            $fileName = Split-Path $url -Leaf
            $filePath = Join-Path $configDir $fileName
            try {
                Invoke-WebRequest -Uri $url -OutFile $filePath -UseBasicParsing
                Write-StyledMessage Success "$fileName scaricato"
            }
            catch {
                Write-StyledMessage Error "Errore download $fileName`: $($_.Exception.Message)"
            }
        }
    }

    function Start-CountdownRestart([string]$Reason) {
        Write-StyledMessage Info "🔄 $Reason - Il sistema verrà riavviato"
        Write-StyledMessage Info "💡 Premi un tasto qualsiasi per annullare..."

        for ($i = $CountdownSeconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                $null = [Console]::ReadKey($true)
                Write-Host "`n"
                Write-StyledMessage Warning "⏸️ Riavvio annullato dall'utente"
                return $false
            }

            $percent = [Math]::Round((($CountdownSeconds - $i) / $CountdownSeconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"
            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."
        Restart-Computer -Force
        return $true
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
        if (-not (Install-RustDesk -InstallerPath $installerPath -ServerIP $null)) {
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
        Write-StyledMessage Error "ERRORE: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Verifica connessione Internet e riprova"
    }
}

SetRustDesk