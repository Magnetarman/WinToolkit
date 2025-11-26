
function WinReinstallStore {
    <#
    .SYNOPSIS
        Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget.

    .DESCRIPTION
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI senza output bloccanti.

#>
    param([int]$CountdownSeconds = 30, [switch]$NoReboot)

    $Host.UI.RawUI.WindowTitle = "Store Repair Toolkit By MagnetarMan"

    # Setup logging specifico per WinReinstallStore
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\WinReinstallStore_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}
    
    $script:MsgStyles = @{
        Success  = @{ Color = 'Green'; Icon = '✅' }
        Warning  = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error    = @{ Color = 'Red'; Icon = '❌' }
        Info     = @{ Color = 'Cyan'; Icon = '💎' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }
    
    function Write-StyledMessage {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Progress')]
            [string]$Type,
            
            [Parameter(Mandatory = $true)]
            [string]$Text
        )

        $style = $script:MsgStyles[$Type]
        $timestamp = Get-Date -Format "HH:mm:ss"
        
        # Rimuovi emoji duplicati dal testo per il log
        $cleanText = $Text -replace '^[✅⚠️❌💎🔍🚀⚙️🧹📦📋📜📝💾⬇️🔧⚡🖼️🌐🍪🔄🗂️📁🖨️📄🗑️💭⏸️▶️💡⏰🎉💻📊]\s*', ''

        Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color

        if ($Type -in @('Info', 'Warning', 'Error')) {
            $logEntry = "[$timestamp] [$Type] $cleanText"
            $script:Log += $logEntry
        }
    }
    
    function Get-CenteredText {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )

        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ '
            '      \ \      / / | || \ | |'
            '       \ \ /\ / /  | ||  \| |'
            '        \ V  V /   | || |\  |'
            '         \_/\_/    |_||_| \_|'
            ''
            ' Store Repair Toolkit By MagnetarMan',
            '       Version 2.4.2 (Build 7)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Get-CenteredText -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
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
    
    function Stop-InterferingProcesses {
        @("WinStore.App", "wsappx", "AppInstaller", "Microsoft.WindowsStore",
            "Microsoft.DesktopAppInstaller", "RuntimeBroker", "dllhost") | ForEach-Object {
            Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep 2
    }
    
    function Test-WingetAvailable {
        try {
            $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $null = & winget --version 2>$null
            return $LASTEXITCODE -eq 0
        }
        catch { return $false }
    }
    
    function Install-WingetSilent {
        Write-StyledMessage Progress "🚀 Avvio della procedura di reinstallazione e riparazione Winget..."
        Stop-InterferingProcesses

        $originalPos = [Console]::CursorTop
        try {
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'

            # --- FASE 1: Inizializzazione e Pulizia Profonda ---
            
            # Terminazione Processi
            Write-StyledMessage Progress "Chiusura forzata dei processi Winget e correlati..."
            @("winget", "WindowsPackageManagerServer") | ForEach-Object {
                Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                taskkill /im "$_.exe" /f 2>$null
            }
            Start-Sleep 2

            # Pulizia Cartella Temporanea
            Write-StyledMessage Progress "Pulizia dei file temporanei (%TEMP%\WinGet)..."
            $tempWingetPath = "$env:TEMP\WinGet"
            if (Test-Path $tempWingetPath) {
                Remove-Item -Path $tempWingetPath -Recurse -Force -ErrorAction SilentlyContinue *>$null
                Write-StyledMessage Info "Cartella temporanea di Winget eliminata."
            }
            else {
                Write-StyledMessage Info "Cartella temporanea di Winget non trovata o già pulita."
            }

            # Reset Sorgenti Winget
            Write-StyledMessage Progress "Reset delle sorgenti di Winget..."
            $wingetExePath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
            if (Test-Path $wingetExePath) {
                & $wingetExePath source reset --force *>$null
            }
            else {
                winget source reset --force *>$null
            }
            Write-StyledMessage Info "Sorgenti Winget resettate."

            # --- FASE 2: Installazione Dipendenze e Moduli PowerShell ---
            
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            # Installazione Provider NuGet
            Write-StyledMessage Progress "Installazione del PackageProvider NuGet..."
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                Write-StyledMessage Success "Provider NuGet installato/verificato."
            }
            catch {
                Write-StyledMessage Warning "Nota: Il provider NuGet potrebbe essere già installato o richiedere conferma manuale."
            }

            # Installazione Modulo Microsoft.WinGet.Client
            Write-StyledMessage Progress "Installazione e importazione del modulo Microsoft.WinGet.Client..."
            Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction SilentlyContinue *>$null
            Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
            Write-StyledMessage Success "Modulo Microsoft.WinGet.Client installato e importato."

            # --- FASE 3: Riparazione e Reinstallazione del Core di Winget ---

            # Tentativo A (Riparazione via Modulo)
            Write-StyledMessage Progress "Tentativo di riparazione Winget tramite il modulo WinGet Client..."
            if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                $null = Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                Start-Sleep 5
                if (Test-WingetAvailable) {
                    Write-StyledMessage Success "Winget riparato con successo tramite modulo."
                    # Procedi al reset Appx
                }
            }

            # Tentativo B (Reinstallazione tramite MSIXBundle - Fallback)
            if (-not (Test-WingetAvailable)) {
                Write-StyledMessage Progress "Scarico e installo Winget tramite MSIXBundle (metodo fallback)..."
                $url = "https://aka.ms/getwinget"
                $temp = "$env:TEMP\WingetInstaller.msixbundle"
                if (Test-Path $temp) { Remove-Item $temp -Force *>$null }

                Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing *>$null
                $process = Start-Process powershell -ArgumentList @(
                    "-NoProfile", "-WindowStyle", "Hidden", "-Command",
                    "try { Add-AppxPackage -Path '$temp' -ForceApplicationShutdown -ErrorAction Stop } catch { exit 1 }; exit 0"
                ) -Wait -PassThru -WindowStyle Hidden

                Remove-Item $temp -Force -ErrorAction SilentlyContinue *>$null
                Start-Sleep 5
                if (Test-WingetAvailable) {
                    Write-StyledMessage Success "Winget installato con successo tramite MSIXBundle."
                }
            }

            # --- FASE 4: Reset dell'App Installer Appx ---
            Write-StyledMessage Progress "Reset dell'App 'Programma di installazione app' (Microsoft.DesktopAppInstaller)..."
            try {
                Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage *>$null
                Write-StyledMessage Success "App 'Programma di installazione app' resettata con successo."
            }
            catch {
                Write-StyledMessage Warning "Impossibile resettare l'App 'Programma di installazione app'. Errore: $($_.Exception.Message)"
            }

            # --- FASE 5: Gestione Output Finale e Valore di Ritorno ---
            
            # Reset cursore e flush output
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            
            Start-Sleep 2
            $finalCheck = Test-WingetAvailable
            
            if ($finalCheck) {
                Write-StyledMessage Success "Winget è stato processato e sembra funzionante."
                return $true
            }
            else {
                Write-StyledMessage Error "❌ Impossibile installare o riparare Winget dopo tutti i tentativi."
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore critico in Install-WingetSilent: $($_.Exception.Message)"
            return $false
        }
        finally {
            # Reset delle preferenze
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
            $VerbosePreference = 'SilentlyContinue'
        }
    }
    
    function Install-MicrosoftStoreSilent {
        Write-StyledMessage Progress "Reinstallazione Microsoft Store in corso..."
        
        $originalPos = [Console]::CursorTop
        try {
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            
            @("AppXSvc", "ClipSVC", "WSService") | ForEach-Object {
                try { Restart-Service $_ -Force -ErrorAction SilentlyContinue *>$null } catch {}
            }

            @("$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
                "$env:LOCALAPPDATA\Microsoft\Windows\INetCache") | ForEach-Object {
                if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue *>$null }
            }

            $methods = @(
                {
                    if (Test-WingetAvailable) {
                        $process = Start-Process winget -ArgumentList "install 9WZDNCRFJBMP --accept-source-agreements --accept-package-agreements --silent --disable-interactivity" -Wait -PassThru -WindowStyle Hidden
                        return $process.ExitCode -eq 0
                    }
                    return $false
                },
                {
                    $store = Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue
                    if ($store) {
                        $store | ForEach-Object {
                            $manifest = "$($_.InstallLocation)\AppXManifest.xml"
                            if (Test-Path $manifest) {
                                $process = Start-Process powershell -ArgumentList @(
                                    "-NoProfile", "-WindowStyle", "Hidden", "-Command",
                                    "Add-AppxPackage -DisableDevelopmentMode -Register '$manifest' -ForceApplicationShutdown"
                                ) -Wait -PassThru -WindowStyle Hidden
                            }
                        }
                        return $true
                    }
                    return $false
                },
                {
                    $process = Start-Process DISM -ArgumentList "/Online /Add-Capability /CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0" -Wait -PassThru -WindowStyle Hidden
                    return $process.ExitCode -eq 0
                }
            )

            foreach ($method in $methods) {
                try {
                    if (& $method) {
                        Start-Process wsreset.exe -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue *>$null
                        
                        # Reset cursore e flush output
                        [Console]::SetCursorPosition(0, $originalPos)
                        $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                        Write-Host $clearLine -NoNewline
                        [Console]::Out.Flush()
                        
                        return $true
                    }
                }
                catch { continue }
            }
            return $false
        }
        finally {
            # Reset delle preferenze
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
            $VerbosePreference = 'SilentlyContinue'
        }
    }
    
    function Install-UniGetUISilent {
        Write-StyledMessage Progress "Reinstallazione UniGet UI in corso..."
        if (-not (Test-WingetAvailable)) { return $false }

        $originalPos = [Console]::CursorTop
        try {
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            
            $process = Start-Process winget -ArgumentList "install --exact --id MartiCliment.UniGetUI --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity --force" -Wait -PassThru -WindowStyle Hidden
    
            if ($process.ExitCode -eq 0) {
                Write-StyledMessage Progress "Disabilitazione avvio automatico UniGet UI..."
                try {
                    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                    $regKeyName = "WingetUI"
                    if (Test-Path -Path "$regPath\$regKeyName") {
                        Remove-ItemProperty -Path $regPath -Name $regKeyName -ErrorAction Stop | Out-Null
                        Write-StyledMessage Success "Avvio automatico UniGet UI disabilitato."
                    }
                    else {
                        Write-StyledMessage Info "La voce di avvio automatico per UniGet UI non è stata trovata o non è necessaria."
                    }
                }
                catch {
                    Write-StyledMessage Warning "Impossibile disabilitare l'avvio automatico di UniGet UI: $($_.Exception.Message)"
                }
            }
    
            # Reset cursore e flush output
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            
            return $process.ExitCode -eq 0
        }
        catch {
            return $false
        }
        finally {
            # Reset delle preferenze
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
            $VerbosePreference = 'SilentlyContinue'
        }
    }
    
    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Warning "$Message"
        Write-StyledMessage Info '💡 Premi un tasto qualsiasi per annullare...'

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning "⏸️ Riavvio automatico annullato"
                Write-StyledMessage Error 'Riavvia manualmente: shutdown /r /t 0'
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."

        if (-not $NoReboot) {
            try {
                shutdown /r /t 0
                return $true
            }
            catch {
                Write-StyledMessage Error "Errore riavvio: $_"
                return $false
            }
        }
        else {
            Write-StyledMessage Info "🚫 Riavvio saltato come richiesto."
            return $false
        }
    }
    
    Show-Header
    Write-StyledMessage Info "🚀 AVVIO REINSTALLAZIONE STORE"

    try {
        $wingetResult = Install-WingetSilent
        Write-StyledMessage $(if ($wingetResult) { 'Success' }else { 'Warning' }) "Winget $(if($wingetResult){'installato'}else{'processato'})"

        $storeResult = Install-MicrosoftStoreSilent
        if (-not $storeResult) {
            Write-StyledMessage Error "Errore installazione Microsoft Store"
            Write-StyledMessage Info "Verifica: Internet, Admin, Windows Update"
            return
        }
        Write-StyledMessage Success "Microsoft Store installato"

        $unigetResult = Install-UniGetUISilent
        Write-StyledMessage $(if ($unigetResult) { 'Success' }else { 'Warning' }) "UniGet UI $(if($unigetResult){'installato'}else{'processato'})"

        Write-Host ""
        Write-StyledMessage Success "🎉 OPERAZIONE COMPLETATA"

        if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio necessario per applicare le modifiche") {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
        }
    }
    catch {
        Clear-Terminal
        Show-Header
        Write-StyledMessage Error "❌ ERRORE: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Esegui come Admin, verifica Internet e Windows Update"
        try { Stop-Transcript | Out-Null } catch {}
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
        try { Stop-Transcript | Out-Null } catch {}
    }
}

WinReinstallStore