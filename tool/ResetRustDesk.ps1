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
            '        Version 2.2 (Build 2)'
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

    function Stop-RustDeskProcesses {
        @("rustdesk", "RustDesk") | ForEach-Object {
            Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep 2
    }

    function Test-RustDeskInstalled {
        $installPath = "$env:ProgramFiles\RustDesk"
        $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $rustDeskUninstall = Get-ChildItem $uninstallKey | Where-Object {
            $_.GetValue("DisplayName") -like "*RustDesk*"
        }
        return (Test-Path $installPath) -or ($null -ne $rustDeskUninstall)
    }

    function Remove-ExistingRustDesk {
        Write-StyledMessage Progress "Rimozione installazione esistente..."

        try {
            # Ferma processi
            Stop-RustDeskProcesses

            # Rimuovi tramite uninstaller se presente
            $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            $rustDeskUninstall = Get-ChildItem $uninstallKey | Where-Object {
                $_.GetValue("DisplayName") -like "*RustDesk*"
            }

            if ($rustDeskUninstall) {
                $uninstallString = $rustDeskUninstall.GetValue("UninstallString")
                if ($uninstallString) {
                    $process = Start-Process cmd -ArgumentList "/c $uninstallString /silent" -Wait -PassThru -WindowStyle Hidden
                    Start-Sleep 5
                }
            }

            # Rimuovi cartelle
            $pathsToRemove = @(
                "$env:ProgramFiles\RustDesk",
                "$env:LOCALAPPDATA\RustDesk",
                "$env:APPDATA\RustDesk"
            )

            foreach ($path in $pathsToRemove) {
                if (Test-Path $path) {
                    Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
                }
            }

            # Rimuovi chiavi registro
            $registryPaths = @(
                "HKLM:\SOFTWARE\RustDesk",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk",
                "HKCU:\SOFTWARE\RustDesk"
            )

            foreach ($regPath in $registryPaths) {
                Remove-Item $regPath -Recurse -Force -ErrorAction SilentlyContinue
            }

            Start-Sleep 3
            return $true
        }
        catch {
            Write-StyledMessage Warning "⚠️ Alcuni componenti potrebbero non essere stati rimossi completamente"
            return $false
        }
    }

    function Download-RustDeskInstaller {
        param([string]$DownloadPath)

        Write-StyledMessage Progress "Download installer RustDesk in corso..."

        try {
            # URL download RustDesk (ultima versione stabile)
            $url = "https://github.com/rustdesk/rustdesk/releases/latest/download/rustdesk-portable.exe"

            # Crea directory se non esiste
            $parentDir = Split-Path $DownloadPath -Parent
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }

            # Rimuovi file esistente
            if (Test-Path $DownloadPath) {
                Remove-Item $DownloadPath -Force
            }

            # Download
            Invoke-WebRequest -Uri $url -OutFile $DownloadPath -UseBasicParsing

            if (Test-Path $DownloadPath) {
                Write-StyledMessage Success "✅ Installer scaricato con successo"
                return $true
            }
            else {
                Write-StyledMessage Error "❌ Errore nel download dell'installer"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "❌ Errore durante il download: $($_.Exception.Message)"
            return $false
        }
    }

    function Install-RustDeskCustom {
        param([string]$InstallerPath, [string]$ServerIP)

        Write-StyledMessage Progress "Installazione RustDesk con configurazione personalizzata..."

        try {
            # Parametri di installazione personalizzati
            $installArgs = @(
                "--server", $ServerIP,
                "--silent",
                "--create-shortcuts",
                "--import-config"
            )

            # Esegui installazione
            $process = Start-Process $InstallerPath -ArgumentList $installArgs -Wait -PassThru -WindowStyle Hidden

            Start-Sleep 5

            if ($process.ExitCode -eq 0) {
                Write-StyledMessage Success "✅ RustDesk installato con configurazione personalizzata"

                # Verifica installazione
                if (Test-RustDeskInstalled) {
                    Write-StyledMessage Success "✅ Verifica installazione completata"
                    return $true
                }
                else {
                    Write-StyledMessage Warning "⚠️ Installazione completata ma verifica fallita"
                    return $false
                }
            }
            else {
                Write-StyledMessage Error "❌ Errore durante l'installazione (Exit Code: $($process.ExitCode))"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "❌ Errore durante l'installazione: $($_.Exception.Message)"
            return $false
        }
    }

    function Configure-RustDeskSecurity {
        param([string]$ServerIP)

        Write-StyledMessage Progress "Configurazione sicurezza RustDesk..."

        try {
            # Percorsi configurazione
            $configPaths = @(
                "$env:APPDATA\RustDesk\config\RustDesk.toml",
                "$env:APPDATA\RustDesk\config\RustDesk2.toml"
            )

            foreach ($configPath in $configPaths) {
                if (Test-Path $configPath) {
                    # Configurazione sicurezza
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

                    $configContent | Out-File $configPath -Encoding UTF8 -Force
                    Write-StyledMessage Success "✅ Configurazione sicurezza aggiornata"
                }
            }

            return $true
        }
        catch {
            Write-StyledMessage Warning "⚠️ Errore nella configurazione: $($_.Exception.Message)"
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
        # Configurazione percorsi
        $rustDeskDir = "$env:LOCALAPPDATA\WinToolkit\rustdesk"
        $installerPath = "$rustDeskDir\rustdesk-installer.exe"
        $serverIP = "89.168.23.158"

        # FASE 1: Rimozione esistente
        Write-StyledMessage Info "📋 FASE 1: Rimozione installazione esistente"
        if (Test-RustDeskInstalled) {
            $removeResult = Remove-ExistingRustDesk
            Clear-Terminal
            Show-Header
            Write-StyledMessage $(if ($removeResult) { 'Success' }else { 'Warning' }) "$(if($removeResult){'✅'}else{'⚠️'}) Rimozione $(if($removeResult){'completata'}else{'parziale'})"
        }
        else {
            Write-StyledMessage Info "ℹ️ Nessuna installazione esistente trovata"
        }

        # FASE 2: Download installer
        Write-StyledMessage Info "📋 FASE 2: Download installer"
        $downloadResult = Download-RustDeskInstaller -DownloadPath $installerPath
        if (-not $downloadResult) {
            Write-StyledMessage Error "❌ Impossibile procedere senza l'installer"
            return
        }

        # FASE 3: Installazione personalizzata
        Write-StyledMessage Info "📋 FASE 3: Installazione con server $serverIP"
        $installResult = Install-RustDeskCustom -InstallerPath $installerPath -ServerIP $serverIP
        if (-not $installResult) {
            Write-StyledMessage Error "❌ Errore durante l'installazione"
            return
        }

        # FASE 4: Configurazione sicurezza
        Write-StyledMessage Info "📋 FASE 4: Configurazione sicurezza"
        $configResult = Configure-RustDeskSecurity -ServerIP $serverIP
        Write-StyledMessage $(if ($configResult) { 'Success' }else { 'Warning' }) "$(if($configResult){'✅'}else{'⚠️'}) Configurazione $(if($configResult){'completata'}else{'parziale'})"

        # Pulizia file temporanei
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }

        # Completamento
        Write-Host ""
        Write-StyledMessage Success "🎉 RESET RUSTDESK COMPLETATO"

        # Ritorno allo script principale
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

# Esportazione funzione per utilizzo in altri script
ResetRustDesk