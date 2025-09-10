function WinReinstallStore {
    <#
    .SYNOPSIS
        Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget come punto di partenza.
    
    .DESCRIPTION
        Questa funzione automatizza il processo completo di reinstallazione del Microsoft Store:
        1. Verifica e installa/aggiorna Winget se necessario
        2. Tenta la reinstallazione del Microsoft Store attraverso diversi metodi
        3. Installa UniGet UI come strumento aggiuntivo
        4. Gestisce il riavvio del sistema per applicare le modifiche
    #>
    
    param([int]$CountdownSeconds = 30)
    
    # Inizializzazione
    $Host.UI.RawUI.WindowTitle = "Store Repair Toolkit By MagnetarMan"
    Clear-Host
    
    # Configurazione globale
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }; Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error = @{ Color = 'Red'; Icon = '❌' }; Info = @{ Color = 'Cyan'; Icon = '💎' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }
    
    # Header grafico ottimizzato
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
            '  Store Repair Toolkit By MagnetarMan',
            '        Version 2.0 (Build 15)'
        )
        foreach ($line in $asciiArt) {
            Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
        }
        Write-Host ('═' * $width) -ForegroundColor Green
        Write-Host ''
    }
    
    # Funzioni helper ottimizzate
    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }
    
    function Test-WingetInstallation {
        try {
            $version = & winget --version 2>$null
            return if ($version -match "v(\d+\.\d+\.\d+)") { "installed" } else { "outdated" }
        }
        catch { return "notinstalled" }
    }
    
    function Install-Winget {
        Write-StyledMessage Progress "🔧 Iniziando installazione/aggiornamento di Winget..."
        
        # Verifica versione Windows
        if ((Get-ComputerInfo).WindowsVersion -lt "1809") {
            Write-StyledMessage Error "Winget non è supportato su questa versione di Windows (Pre-1809)"
            throw "Versione Windows non supportata"
        }
        
        # Metodi di installazione ottimizzati
        $methods = @(
            { # Aggiornamento via Winget esistente
                $wingetCmd = Get-Command winget -ErrorAction Stop
                Start-Process -FilePath $wingetCmd.Source -ArgumentList "install -e --accept-source-agreements --accept-package-agreements Microsoft.AppInstaller" -Wait -NoNewWindow -PassThru
            },
            { # Repair-WinGetPackageManager (Windows 24H2+)
                if ([System.Environment]::OSVersion.Version.Build -ge 26100) {
                    Repair-WinGetPackageManager -Force -Latest -Verbose
                    Get-Command winget -ErrorAction Stop
                }
            },
            { # Download manuale
                $url = "https://aka.ms/getwinget"
                $temp = "$env:TEMP\Microsoft.AppInstaller.msixbundle"
                Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing
                Add-AppxPackage -Path $temp -ForceUpdateFromAnyVersion
                Remove-Item $temp -Force -ErrorAction SilentlyContinue
            }
        )
        
        foreach ($method in $methods) {
            try {
                & $method | Out-Null
                $ENV:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                Start-Sleep 2
                if ((Test-WingetInstallation) -eq "installed") {
                    Write-StyledMessage Success "WinGet installato/aggiornato con successo!"
                    return $true
                }
            }
            catch { Write-StyledMessage Warning "Metodo fallito: $($_.Exception.Message)" }
        }
        return $false
    }
    
    function Fix-BlockedDeployment {
        Write-Host "=== FIX DEPLOYMENT BLOCCATO ===" -ForegroundColor Yellow
        
        # Terminazione processi e pulizia ottimizzata
        @("WinStore.App", "wsappx", "AppInstaller", "Microsoft.WindowsStore", "RuntimeBroker", "dllhost") | 
        ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
        
        # Reset servizi critici
        @(@{Name = "AppXSvc"; Display = "AppX Deployment Service" }, @{Name = "ClipSVC"; Display = "Client License Service" }, 
            @{Name = "WSService"; Display = "Windows Store Service" }) | ForEach-Object {
            try {
                $svc = Get-Service -Name $_.Name -ErrorAction SilentlyContinue
                if ($svc) {
                    Restart-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
                    Write-Host "✅ Riavviato: $($_.Display)" -ForegroundColor Green
                }
            }
            catch { Write-Host "⚠️ Errore servizio $($_.Name)" -ForegroundColor Yellow }
        }
        
        # Pulizia cache e pacchetti corrotti
        @("$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache", "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
            "$env:TEMP\*AppX*", "$env:WINDIR\Temp\*AppX*") | ForEach-Object {
            if (Test-Path $_) { Remove-Item -Path $_ -Recurse -Force -ErrorAction SilentlyContinue }
        }
        
        # Rimozione pacchetti corrotti
        Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*WindowsStore*" -or $_.Status -eq "Staged" } |
        ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }
    }
    
    function Install-MicrosoftStore {
        Write-StyledMessage Info "🏪 Iniziando reinstallazione Microsoft Store..."
        
        # Metodi di installazione ordinati per efficacia
        $methods = @(
            {
                Write-StyledMessage Progress "Tentativo 1: Installazione tramite Winget..."
                $output = winget install 9WZDNCRFJBMP --accept-source-agreements --accept-package-agreements 2>&1
                if ($output -match "No available upgrade found|already installed" -or $LASTEXITCODE -eq 0) {
                    Write-StyledMessage Success "Microsoft Store installato/aggiornato tramite Winget!"
                    return $true
                }
                throw "Installazione Winget fallita"
            },
            {
                Write-StyledMessage Progress "Tentativo 2: Reinstallazione tramite Manifest Windows..."
                $storePackage = Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue
                if ($storePackage) {
                    $storePackage | ForEach-Object {
                        $manifestPath = "$($_.InstallLocation)\AppXManifest.xml"
                        if (Test-Path $manifestPath) {
                            Add-AppxPackage -DisableDevelopmentMode -Register $manifestPath -ForceUpdateFromAnyVersion
                        }
                    }
                    Write-StyledMessage Success "Microsoft Store reinstallato tramite Manifest!"
                    return $true
                }
                throw "Nessun pacchetto Store trovato"
            },
            {
                Write-StyledMessage Progress "Tentativo 3: Installazione tramite DISM Capability..."
                $result = Start-Process -FilePath "DISM" -ArgumentList "/Online /Add-Capability /CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0" -Wait -NoNewWindow -PassThru
                if ($result.ExitCode -eq 0) {
                    Write-StyledMessage Success "Microsoft Store installato tramite DISM!"
                    return $true
                }
                throw "DISM fallito"
            },
            {
                Write-StyledMessage Progress "Tentativo 4: Download e installazione manuale..."
                Install-StoreManually
            }
        )
        
        foreach ($method in $methods) {
            try {
                if (& $method) {
                    # Avvio wsreset.exe per verificare funzionamento Store
                    Write-StyledMessage Info "🔄 Avvio wsreset.exe per verificare il funzionamento del Microsoft Store..."
                    try {
                        Start-Process -FilePath "wsreset.exe" -Wait -WindowStyle Hidden
                        Write-StyledMessage Success "✅ wsreset.exe completato - Microsoft Store verificato!"
                    }
                    catch {
                        Write-StyledMessage Warning "⚠️ wsreset.exe non eseguito ma Store dovrebbe funzionare"
                    }
                    return $true
                }
            }
            catch { Write-StyledMessage Warning $_.Exception.Message }
        }
        return $false
    }
    
    function Install-StoreManually {
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "Privilegi amministratore necessari per installazione manuale"
        }
        
        $tempDir = "$env:TEMP\MSStore"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        # Pacchetti essenziali ottimizzati
        $packages = @(
            @{Name = "VCLibs"; Url = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" },
            @{Name = "UI.Xaml"; Url = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx" },
            @{Name = "Store"; Url = "https://www.microsoft.com/store/productId/9WZDNCRFJBMP" }
        )
        
        $downloaded = @()
        foreach ($pkg in $packages) {
            try {
                $file = Join-Path $tempDir "$($pkg.Name).appx"
                if ($pkg.Name -eq "Store") {
                    # Per Store usa store.rg-adguard.net API semplificata
                    $storeUrl = (Invoke-RestMethod -Uri "https://store.rg-adguard.net/api/GetFiles" -Method POST -Body "type=url&url=$($pkg.Url)&ring=Retail" -ContentType "application/x-www-form-urlencoded" | 
                        Select-String -Pattern 'href="([^"]+\.(?:appx|msix|appxbundle|msixbundle))"' -AllMatches).Matches[0].Groups[1].Value
                    Invoke-WebRequest -Uri $storeUrl -OutFile $file -UseBasicParsing
                }
                else {
                    Invoke-WebRequest -Uri $pkg.Url -OutFile $file -UseBasicParsing
                }
                $downloaded += $file
                Write-StyledMessage Success "📦 Scaricato: $($pkg.Name)"
            }
            catch { Write-StyledMessage Warning "Download fallito: $($pkg.Name)" }
        }
        
        # Installazione sequenziale
        $downloaded | ForEach-Object {
            try {
                Add-AppxPackage -Path $_ -ForceApplicationShutdown
                Write-StyledMessage Success "✅ Installato: $(Split-Path $_ -Leaf)"
            }
            catch { Write-StyledMessage Warning "Installazione fallita: $($_.Exception.Message)" }
        }
        
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        return (Get-AppxPackage -Name "Microsoft.WindowsStore" -ErrorAction SilentlyContinue) -ne $null
    }
    
    function Install-UniGetUI {
        try {
            $result = Start-Process -FilePath "winget" -ArgumentList "install --exact --id MartiCliment.UniGetUI --source winget --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow -PassThru
            if ($result.ExitCode -eq 0) {
                Write-StyledMessage Success "UniGet UI installato con successo!"
                return $true
            }
        }
        catch { }
        Write-StyledMessage Warning "UniGet UI non installato"
        return $false
    }
    
    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi qualsiasi tasto per annullare il riavvio automatico...'
        
        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-StyledMessage Error '⏸️ Riavvio annullato - Riavvia manualmente con: shutdown /r /t 0'
                return $false
            }
            
            $progress = (($Seconds - $i) / $Seconds) * 100
            $bar = ("[" + ('▌' * [math]::Floor($progress / 3.33)) + ('▒' * (30 - [math]::Floor($progress / 3.33))) + "] {0:0}%" -f $progress)
            Write-Host "`r⏳ $Message - $i sec $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }
        
        Write-Host ''; Write-StyledMessage Warning '⏰ Riavvio in corso...'; Start-Sleep 1
        return $true
    }
    
    # === LOGICA PRINCIPALE OTTIMIZZATA ===
    Show-Header
    Write-StyledMessage Info "🏪 REINSTALLAZIONE MICROSOFT STORE - AVVIO PROCEDURA"
    
    try {
        # FASE 1: Winget
        Write-StyledMessage Info "📋 FASE 1: Verifica Winget"
        $wingetStatus = Test-WingetInstallation
        
        if ($wingetStatus -ne "installed") {
            Write-StyledMessage Warning "Winget $wingetStatus - $(if($wingetStatus -eq 'outdated'){'aggiornamento'}else{'installazione'}) necessaria"
            if (-not (Install-Winget)) { throw "Impossibile preparare Winget" }
        }
        else {
            Write-StyledMessage Success "Winget già installato e funzionante"
        }
        
        # FASE 2: Microsoft Store
        Write-Host ""; Write-StyledMessage Info "📋 FASE 2: Reinstallazione Microsoft Store"
        Fix-BlockedDeployment
        
        if (-not (Install-MicrosoftStore)) {
            Write-StyledMessage Error "❌ ERRORE: Tutti i metodi di installazione falliti!"
            Write-StyledMessage Info "💡 Suggerimenti: Verifica connessione internet, esegui come Admin, prova Windows Update"
            return
        }
        
        # FASE 3: UniGet UI
        Write-Host ""; Write-StyledMessage Info "📋 FASE 3: Installazione UniGet UI"
        Install-UniGetUI | Out-Null
        
        # FASE 4: Completamento
        Write-Host ""; Write-Host "===" -ForegroundColor Green
        Write-StyledMessage Success "🎉 OPERAZIONE COMPLETATA CON SUCCESSO!"
        Write-Host "===" -ForegroundColor Green
        
        @("   ✅ Winget verificato/installato", "   ✅ Microsoft Store reinstallato", "   ✅ UniGet UI installato") |
        ForEach-Object { Write-Host $_ -ForegroundColor Green }
        
        Write-Host ""; Write-StyledMessage Warning "⚠️ È necessario riavviare il sistema per applicare tutte le modifiche"
        
        if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio del sistema") {
            Write-StyledMessage Info "🔄 Riavvio del sistema in corso..."
            shutdown /r /t 0
        }
        
    }
    catch {
        Write-Host ""; Write-Host "===" -ForegroundColor Red
        Write-StyledMessage Error "❌ ERRORE DURANTE L'ESECUZIONE"
        Write-Host "===" -ForegroundColor Red
        Write-StyledMessage Error "Dettagli: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Verifica: Admin, Internet, Windows Update, Riavvio"
    }
}

WinReinstallStore
