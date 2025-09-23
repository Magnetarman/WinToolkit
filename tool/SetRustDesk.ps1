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
        Success = @{ Color = 'Green'; Icon = '✅' }; Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error = @{ Color = 'Red'; Icon = '❌' }; Info = @{ Color = 'Cyan'; Icon = '💎' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }

    # Funzione per centrare il testo
    function Center-Text {
        param([string]$Text, [int]$Width)
        $padding = [math]::Max(0, ($Width - $Text.Length) / 2)
        return (' ' * [math]::Floor($padding)) + $Text
    }

    # Header grafico
    function Show-Header {
        Clear-Host
        $width = 65
        Write-Host ('═' * $width) -ForegroundColor Green
        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '   RustDesk Setup Toolkit By MagnetarMan',
            '        Version 2.2 (Build 7)'
        )
        foreach ($line in $asciiArt) {
            Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
        }
        Write-Host ('═' * $width) -ForegroundColor Green
        Write-Host ''
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Clear-Terminal {
        1..50 | ForEach-Object { Write-Host "" }
        Clear-Host
        [Console]::Clear()
        try {
            [System.Console]::SetCursorPosition(0, 0)
            $Host.UI.RawUI.CursorPosition = @{X = 0; Y = 0 }
        }
        catch {}
        Start-Sleep -Milliseconds 200
    }

    function Stop-RustDeskServices {
        Write-StyledMessage Progress "Arresto servizi RustDesk in corso..."

        $rustDeskServices = @("RustDesk", "rustdesk")
        $servicesFound = $false

        foreach ($service in $rustDeskServices) {
            try {
                $serviceObj = Get-Service -Name $service -ErrorAction SilentlyContinue
                if ($serviceObj) {
                    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                    Write-StyledMessage Success "Servizio $service arrestato"
                    $servicesFound = $true
                }
            }
            catch {}
        }

        if (-not $servicesFound) {
            Write-StyledMessage Warning "Nessun servizio RustDesk trovato - Proseguo con l'installazione"
        }

        Start-Sleep 2
    }

    function Stop-RustDeskProcesses {
        Write-StyledMessage Progress "Termine processi RustDesk in corso..."

        $rustDeskProcesses = @("rustdesk", "RustDesk")
        $processesFound = $false

        foreach ($process in $rustDeskProcesses) {
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
        try {
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
        catch {
            Write-StyledMessage Error "Errore API GitHub: $($_.Exception.Message)"
            return $null
        }
    }

    function Download-RustDeskInstaller {
        param([string]$DownloadPath)

        Write-StyledMessage Progress "Download installer RustDesk in corso..."

        try {
            $releaseInfo = Get-LatestRustDeskRelease
            if (-not $releaseInfo) {
                return $false
            }

            Write-StyledMessage Info "📥 Versione rilevata: $($releaseInfo.Version)"

            $parentDir = Split-Path $DownloadPath -Parent
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }

            if (Test-Path $DownloadPath) {
                Remove-Item $DownloadPath -Force
            }

            Invoke-WebRequest -Uri $releaseInfo.DownloadUrl -OutFile $DownloadPath -UseBasicParsing

            if (Test-Path $DownloadPath) {
                Write-StyledMessage Success "Installer $($releaseInfo.FileName) scaricato con successo"
                return $true
            }

            Write-StyledMessage Error "Errore nel download dell'installer"
            return $false
        }
        catch {
            Write-StyledMessage Error "Errore download: $($_.Exception.Message)"
            return $false
        }
    }

    function Install-RustDesk {
        param([string]$InstallerPath, [string]$ServerIP)

        Write-StyledMessage Progress "Installazione RustDesk"

        try {
            $installArgs = @(
                "/i", "`"$InstallerPath`"",
                "/quiet", "/norestart"
            )

            $process = Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -WindowStyle Hidden
            Start-Sleep 10

            if ($process.ExitCode -eq 0) {
                Write-StyledMessage Success "RustDesk installato"
                return $true
            }

            Write-StyledMessage Error "Errore installazione (Exit Code: $($process.ExitCode))"
            return $false
        }
        catch {
            Write-StyledMessage Error "Errore installazione: $($_.Exception.Message)"
            return $false
        }
    }

    function Clear-RustDeskConfig {
        Write-StyledMessage Progress "Pulizia configurazioni esistenti..."

        $configDir = "$env:APPDATA\RustDesk\config"

        if (Test-Path $configDir) {
            try {
                Remove-Item $configDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-StyledMessage Success "Cartella config eliminata"
                Start-Sleep 1
            }
            catch {
                Write-StyledMessage Warning "Errore nella rimozione della cartella config: $($_.Exception.Message)"
            }
        }
        else {
            Write-StyledMessage Warning "Cartella config non trovata - Potrebbe essere la prima installazione"
        }
    }

    function Download-RustDeskConfigFiles {
        Write-StyledMessage Progress "Download file di configurazione..."

        $configDir = "$env:APPDATA\RustDesk\config"
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        $configFiles = @(
            @{
                Url  = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/RustDesk.toml"
                Path = "$configDir\RustDesk.toml"
            },
            @{
                Url  = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/RustDesk_local.toml"
                Path = "$configDir\RustDesk_local.toml"
            },
            @{
                Url  = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/RustDesk2.toml"
                Path = "$configDir\RustDesk2.toml"
            }
        )

        foreach ($file in $configFiles) {
            try {
                Invoke-WebRequest -Uri $file.Url -OutFile $file.Path -UseBasicParsing
                if (Test-Path $file.Path) {
                    Write-StyledMessage Success "$(Split-Path $file.Path -Leaf) scaricato"
                }
                else {
                    Write-StyledMessage Error "Errore download $(Split-Path $file.Path -Leaf)"
                }
            }
            catch {
                Write-StyledMessage Error "Errore download $($file.Path): $($_.Exception.Message)"
            }
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

            # Barra di progressione countdown con colore rosso
            $percent = [Math]::Round((($CountdownSeconds - $i) / $CountdownSeconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."

        try {
            Restart-Computer -Force
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore riavvio: $_"
            return $false
        }
    }

    # === ESECUZIONE PRINCIPALE ===
    Show-Header
    Write-StyledMessage Info "🚀 AVVIO CONFIGURAZIONE RUSTDESK"

    try {
        $rustDeskDir = "$env:LOCALAPPDATA\WinToolkit\rustdesk"
        $installerPath = "$rustDeskDir\rustdesk-installer.msi"

        # FASE 1: Stop dei servizi relativi a rust desk in esecuzione
        Write-StyledMessage Info "📋 FASE 1: Arresto servizi RustDesk"
        Stop-RustDeskServices

        # FASE 2: Scarica ed installa Rust Desk
        Write-StyledMessage Info "📋 FASE 2: Download e installazione"
        if (-not (Download-RustDeskInstaller -DownloadPath $installerPath)) {
            Write-StyledMessage Error "Impossibile procedere senza l'installer"
            return
        }

        if (-not (Install-RustDesk -InstallerPath $installerPath -ServerIP $null)) {
            Write-StyledMessage Error "Errore durante l'installazione"
            return
        }

        # FASE 3: Controlla se il programma si è avviato e termina tutti i processi
        Write-StyledMessage Info "📋 FASE 3: Verifica processi e pulizia"
        Stop-RustDeskProcesses

        # FASE 4: Cancella la cartella config
        Write-StyledMessage Info "📋 FASE 4: Pulizia configurazioni"
        Clear-RustDeskConfig

        # FASE 5: Scarica i file di configurazione
        Write-StyledMessage Info "📋 FASE 5: Download configurazioni"
        Download-RustDeskConfigFiles

        # Completamento
        Write-Host ""
        Write-StyledMessage Success "🎉 CONFIGURAZIONE RUSTDESK COMPLETATA"

        # Riavvio sistema
        Write-StyledMessage Info "🔄 Per applicare le modifiche il PC verrà riavviato"
        if (Start-CountdownRestart -Reason "Per applicare le modifiche è necessario riavviare il sistema") {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
        }
    }
    catch {
        Clear-Terminal
        Show-Header
        Write-StyledMessage Error "ERRORE: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Verifica connessione Internet e riprova"
    }
}

SetRustDesk