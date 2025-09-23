function ResetRustDesk {
    <#
    .SYNOPSIS
        Reinstalla automaticamente RustDesk con configurazione personalizzata su Windows.

    .DESCRIPTION
        Script ottimizzato per reinstallare RustDesk con server personalizzato e configurazioni di sicurezza.
        Scarica l'installer nella cartella temporanea e configura il client con parametri personalizzati.
    #>

    param([int]$CountdownSeconds = 10)

    # Inizializzazione
    $Host.UI.RawUI.WindowTitle = "RustDesk Reset Toolkit By MagnetarMan"

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
            '   RustDesk Reset Toolkit By MagnetarMan',
            '        Version 2.2 (Build 3)'
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
        # Pulizia aggressiva multi-metodo
        1..50 | ForEach-Object { Write-Host "" }  # Forza scroll
        Clear-Host
        [Console]::Clear()
        try {
            [System.Console]::SetCursorPosition(0, 0)
            $Host.UI.RawUI.CursorPosition = @{X = 0; Y = 0 }
        }
        catch {}
        Start-Sleep -Milliseconds 200
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

            Write-StyledMessage Error "❌ Nessun installer .msi trovato nella release"
            return $null
        }
        catch {
            Write-StyledMessage Error "❌ Errore API GitHub: $($_.Exception.Message)"
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
                Write-StyledMessage Success "✅ Installer $($releaseInfo.FileName) scaricato con successo"
                return $true
            }

            Write-StyledMessage Error "❌ Errore nel download dell'installer"
            return $false
        }
        catch {
            Write-StyledMessage Error "❌ Errore download: $($_.Exception.Message)"
            return $false
        }
    }

    function Install-RustDeskCustom {
        param([string]$InstallerPath, [string]$ServerIP)

        Write-StyledMessage Progress "Installazione RustDesk con configurazione personalizzata..."

        try {
            $installArgs = @(
                "/i", "`"$InstallerPath`"",
                "/quiet", "/norestart",
                "RELAYSERVER=$ServerIP",
                "RENDEZVOUSSERVER=$ServerIP",
                "ENABLE_AUDIO=1", "ENABLE_CLIPBOARD=1",
                "ENABLE_FILETRANSFER=1", "ENABLE_KEYBOARD=1",
                "ENABLE_MOUSE=1", "ENABLE_DESKTOP=1"
            )

            $process = Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -WindowStyle Hidden
            Start-Sleep 10

            if ($process.ExitCode -eq 0) {
                Write-StyledMessage Success "✅ RustDesk installato con configurazione personalizzata"
                return $true
            }

            Write-StyledMessage Error "❌ Errore installazione (Exit Code: $($process.ExitCode))"
            return $false
        }
        catch {
            Write-StyledMessage Error "❌ Errore installazione: $($_.Exception.Message)"
            return $false
        }
    }

    function Configure-RustDeskSecurity {
        param([string]$ServerIP)

        Write-StyledMessage Progress "Configurazione sicurezza RustDesk..."

        try {
            $configPaths = @(
                "$env:APPDATA\RustDesk\config\RustDesk.toml",
                "$env:APPDATA\RustDesk\config\RustDesk2.toml"
            )

            $configContent = @"
# Configurazione RustDesk - Generata automaticamente
[options]
custom_rendezvous_server = '$ServerIP'
enable_direct_ip = true
enable_relay = true
enable_hole_punching = true
enable_upnp = true

[security]
enable_password = false
enable_2fa = false
allow_always_relay = false
allow_desktop = true
allow_file = true
allow_clipboard = true
allow_audio = true
allow_keyboard = true
allow_mouse = true
"@

            foreach ($configPath in $configPaths) {
                if (Test-Path $configPath) {
                    $configContent | Out-File $configPath -Encoding UTF8 -Force
                    Write-StyledMessage Success "✅ Configurazione sicurezza aggiornata"
                }
            }

            return $true
        }
        catch {
            Write-StyledMessage Warning "⚠️ Errore configurazione: $($_.Exception.Message)"
            return $false
        }
    }

    function Start-CountdownReturn([int]$Seconds) {
        Write-StyledMessage Info '💡 Ritorno allo script principale tra pochi secondi...'

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning "⏸️ Ritorno automatico interrotto"
                return $false
            }

            # Barra di progressione countdown
            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r⏰ Ritorno automatico tra $i secondi $bar" -NoNewline -ForegroundColor Cyan
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Info "🔄 Ritorno allo script principale..."
        return $true
    }

    # === ESECUZIONE PRINCIPALE ===
    Show-Header
    Write-StyledMessage Info "🚀 AVVIO RESET RUSTDESK"

    try {
        $rustDeskDir = "$env:LOCALAPPDATA\WinToolkit\rustdesk"
        $installerPath = "$rustDeskDir\rustdesk-installer.msi"
        $serverIP = "89.168.23.158"

        # FASE 1: Download installer
        Write-StyledMessage Info "📋 FASE 1: Download installer"
        if (-not (Download-RustDeskInstaller -DownloadPath $installerPath)) {
            Write-StyledMessage Error "❌ Impossibile procedere senza l'installer"
            return
        }

        # FASE 2: Installazione personalizzata
        Write-StyledMessage Info "📋 FASE 2: Installazione con server $serverIP"
        if (-not (Install-RustDeskCustom -InstallerPath $installerPath -ServerIP $serverIP)) {
            Write-StyledMessage Error "❌ Errore durante l'installazione"
            return
        }

        # FASE 3: Configurazione sicurezza
        Write-StyledMessage Info "📋 FASE 3: Configurazione sicurezza"
        $configResult = Configure-RustDeskSecurity -ServerIP $serverIP
        Write-StyledMessage $(if ($configResult) { 'Success' }else { 'Warning' }) "$(if($configResult){'✅'}else{'⚠️'}) Configurazione $(if($configResult){'completata'}else{'parziale'})"

        Write-Host ""
        Write-StyledMessage Success "🎉 RESET RUSTDESK COMPLETATO"

        if (Start-CountdownReturn -Seconds $CountdownSeconds) {
            Write-StyledMessage Info "🔄 Ritorno in corso..."
        }
    }
    catch {
        Clear-Terminal
        Show-Header
        Write-StyledMessage Error "❌ ERRORE: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Verifica connessione Internet e riprova"
    }
}

ResetRustDesk