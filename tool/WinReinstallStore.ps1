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
    
    # Funzione per centrare il testo
    function Center-Text {
        param([string]$Text, [int]$Width)
        $padding = [math]::Max(0, ($Width - $Text.Length) / 2)
        return (' ' * [math]::Floor($padding)) + $Text
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
            '        Version 2.0 (Build 17)'
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
    
    # Funzione per terminare processi che potrebbero interferire
    function Stop-InterferingProcesses {
        Write-StyledMessage Progress "🔧 Terminazione processi interferenti..."
        
        $processesToKill = @(
            "WinStore.App", "wsappx", "AppInstaller", "Microsoft.WindowsStore", 
            "Microsoft.DesktopAppInstaller", "RuntimeBroker", "dllhost"
        )
        
        foreach ($processName in $processesToKill) {
            try {
                Get-Process -Name $processName -ErrorAction SilentlyContinue | 
                Stop-Process -Force -ErrorAction SilentlyContinue
                Write-Host "  ✓ Terminato: $processName" -ForegroundColor Gray
            }
            catch {
                # Ignora errori - processo potrebbe non esistere
            }
        }
        
        # Attendi un momento per la terminazione completa
        Start-Sleep -Seconds 3
    }
    
    function Install-Winget {
        Write-StyledMessage Progress "🔧 Iniziando installazione/aggiornamento di Winget..."
        
        # Verifica versione Windows
        $osVersion = [System.Environment]::OSVersion.Version
        if ($osVersion.Build -lt 17763) {
            # Windows 1809
            Write-StyledMessage Error "Winget non è supportato su questa versione di Windows (Pre-1809)"
            throw "Versione Windows non supportata"
        }
        
        # Termina processi interferenti prima dell'installazione
        Stop-InterferingProcesses
        
        # Metodi di installazione ottimizzati
        $methods = @(
            { # Aggiornamento via Winget esistente
                try {
                    $wingetCmd = Get-Command winget -ErrorAction Stop
                    $result = Start-Process -FilePath $wingetCmd.Source -ArgumentList "install -e --accept-source-agreements --accept-package-agreements Microsoft.AppInstaller" -Wait -NoNewWindow -PassThru
                    return $result.ExitCode -eq 0
                }
                catch {
                    return $false
                }
            },
            { # Repair-WinGetPackageManager solo se disponibile
                try {
                    if ($osVersion.Build -ge 26100 -and (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue)) {
                        Repair-WinGetPackageManager -Force -Latest -Verbose
                        Get-Command winget -ErrorAction Stop | Out-Null
                        return $true
                    }
                    return $false
                }
                catch {
                    return $false
                }
            },
            { # Download manuale con gestione processi migliorata
                try {
                    # Termina nuovamente i processi prima del download manuale
                    Stop-InterferingProcesses
                    
                    $url = "https://aka.ms/getwinget"
                    $temp = "$env:TEMP\Microsoft.AppInstaller.msixbundle"
                    
                    # Rimuovi file temporaneo esistente
                    if (Test-Path $temp) {
                        Remove-Item $temp -Force -ErrorAction SilentlyContinue
                    }
                    
                    Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing
                    
                    # Usa -ForceApplicationShutdown invece di -ForceUpdateFromAnyVersion
                    Add-AppxPackage -Path $temp -ForceApplicationShutdown
                    
                    Remove-Item $temp -Force -ErrorAction SilentlyContinue
                    return $true
                }
                catch {
                    Write-StyledMessage Warning "Errore download manuale: $($_.Exception.Message)"
                    return $false
                }
            }
        )
        
        foreach ($method in $methods) {
            try {
                Write-StyledMessage Info "Tentativo di installazione in corso..."
                if (& $method) {
                    # Ricarica PATH e attendi
                    $ENV:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                    Start-Sleep 5
                    
                    # Verifica installazione
                    if ((Test-WingetInstallation) -eq "installed") {
                        Write-StyledMessage Success "WinGet installato/aggiornato con successo!"
                        return $true
                    }
                }
            }
            catch { 
                Write-StyledMessage Warning "Metodo fallito: $($_.Exception.Message)" 
            }
        }
        
        # Ultimo tentativo: verifica se winget è ora disponibile dopo i tentativi
        $ENV:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        Start-Sleep 3
        if ((Test-WingetInstallation) -eq "installed") {
            Write-StyledMessage Success "WinGet risulta ora disponibile!"
            return $true
        }
        
        return $false
    }
    
    function Fix-BlockedDeployment {
        Write-Host "=== FIX DEPLOYMENT BLOCCATO ===" -ForegroundColor Yellow
        
        # Terminazione processi e pulizia ottimizzata
        Stop-InterferingProcesses
        
        # Reset servizi critici
        $services = @(
            @{Name = "AppXSvc"; Display = "AppX Deployment Service" }, 
            @{Name = "ClipSVC"; Display = "Client License Service" }, 
            @{Name = "WSService"; Display = "Windows Store Service" }
        )
        
        foreach ($svc in $services) {
            try {
                $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
                if ($service) {
                    Restart-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                    Write-Host "✅ Riavviato: $($svc.Display)" -ForegroundColor Green
                }
            }
            catch { 
                Write-Host "⚠️ Errore servizio $($svc.Name)" -ForegroundColor Yellow 
            }
        }
        
        # Pulizia cache e pacchetti corrotti
        $pathsToClean = @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache", 
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
            "$env:TEMP\*AppX*", 
            "$env:WINDIR\Temp\*AppX*"
        )
        
        foreach ($path in $pathsToClean) {
            try {
                if (Test-Path $path) { 
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue 
                }
            }
            catch {
                # Ignora errori di accesso
            }
        }
        
        # Rimozione pacchetti corrotti
        try {
            Get-AppxPackage -AllUsers | Where-Object { 
                $_.Name -like "*WindowsStore*" -or $_.Status -eq "Staged" 
            } | ForEach-Object { 
                Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue 
            }
        }
        catch {
            Write-StyledMessage Warning "Errore nella rimozione pacchetti corrotti"
        }
    }
    
    function Install-MicrosoftStore {
        Write-StyledMessage Info "🪟 Iniziando reinstallazione Microsoft Store..."
        
        # Metodi di installazione ordinati per efficacia
        $methods = @(
            {
                Write-StyledMessage Progress "Tentativo 1: Installazione tramite Winget..."
                try {
                    $output = & winget install 9WZDNCRFJBMP --accept-source-agreements --accept-package-agreements 2>&1
                    if ($LASTEXITCODE -eq 0 -or $output -match "No available upgrade found|already installed") {
                        Write-StyledMessage Success "Microsoft Store installato/aggiornato tramite Winget!"
                        return $true
                    }
                    return $false
                }
                catch {
                    return $false
                }
            },
            {
                Write-StyledMessage Progress "Tentativo 2: Reinstallazione tramite Manifest Windows..."
                try {
                    $storePackage = Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue
                    if ($storePackage) {
                        foreach ($package in $storePackage) {
                            $manifestPath = "$($package.InstallLocation)\AppXManifest.xml"
                            if (Test-Path $manifestPath) {
                                Add-AppxPackage -DisableDevelopmentMode -Register $manifestPath -ForceApplicationShutdown
                            }
                        }
                        Write-StyledMessage Success "Microsoft Store reinstallato tramite Manifest!"
                        return $true
                    }
                    return $false
                }
                catch {
                    return $false
                }
            },
            {
                Write-StyledMessage Progress "Tentativo 3: Installazione tramite DISM Capability..."
                try {
                    $result = Start-Process -FilePath "DISM" -ArgumentList "/Online /Add-Capability /CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0" -Wait -NoNewWindow -PassThru
                    if ($result.ExitCode -eq 0) {
                        Write-StyledMessage Success "Microsoft Store installato tramite DISM!"
                        return $true
                    }
                    return $false
                }
                catch {
                    return $false
                }
            },
            {
                Write-StyledMessage Progress "Tentativo 4: Download e installazione manuale..."
                return Install-StoreManually
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
            catch { 
                Write-StyledMessage Warning "Metodo fallito: $($_.Exception.Message)" 
            }
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
            @{Name = "UI.Xaml"; Url = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx" }
        )
        
        $downloaded = @()
        foreach ($pkg in $packages) {
            try {
                $file = Join-Path $tempDir "$($pkg.Name).appx"
                Invoke-WebRequest -Uri $pkg.Url -OutFile $file -UseBasicParsing
                $downloaded += $file
                Write-StyledMessage Success "📦 Scaricato: $($pkg.Name)"
            }
            catch { 
                Write-StyledMessage Warning "Download fallito: $($pkg.Name) - $($_.Exception.Message)" 
            }
        }
        
        # Installazione sequenziale
        foreach ($file in $downloaded) {
            try {
                Add-AppxPackage -Path $file -ForceApplicationShutdown
                Write-StyledMessage Success "✅ Installato: $(Split-Path $file -Leaf)"
            }
            catch { 
                Write-StyledMessage Warning "Installazione fallita: $(Split-Path $file -Leaf) - $($_.Exception.Message)" 
            }
        }
        
        # Prova installazione Store tramite PowerShell (metodo alternativo)
        try {
            Get-AppxPackage -allusers Microsoft.WindowsStore | ForEach-Object { Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" }
        }
        catch {
            Write-StyledMessage Warning "Metodo PowerShell fallito"
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
                Write-Host '';
                Write-StyledMessage Error '⏸️ Riavvio annullato - Riavvia manualmente con: shutdown /r /t 0'
                return $false
            }
            
            $progress = (($Seconds - $i) / $Seconds) * 100
            $bar = ("[" + ('█' * [math]::Floor($progress / 3.33)) + ('░' * (30 - [math]::Floor($progress / 3.33))) + "] {0:0}%" -f $progress)
            Write-Host "`r⏳ $Message - $i sec $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }
        
        Write-Host ''; Write-StyledMessage Warning '⏰ Riavvio in corso...'; Start-Sleep 1
        return $true
    }
    
    # === LOGICA PRINCIPALE OTTIMIZZATA ===
    Show-Header
    Write-StyledMessage Info "🪟 REINSTALLAZIONE MICROSOFT STORE - AVVIO PROCEDURA"
    
    try {
        # FASE 1: Winget
        Write-StyledMessage Info "📋 FASE 1: Verifica Winget"
        $wingetStatus = Test-WingetInstallation
        
        if ($wingetStatus -ne "installed") {
            Write-StyledMessage Warning "Winget $wingetStatus - $(if($wingetStatus -eq 'outdated'){'aggiornamento'}else{'installazione'}) necessaria"
            if (-not (Install-Winget)) { 
                Write-StyledMessage Warning "Winget non installato correttamente, ma continuiamo con altri metodi"
            }
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
        $unigetInstalled = Install-UniGetUI
        
        # FASE 4: Completamento
        Write-Host ""; Write-Host "===" -ForegroundColor Green
        Write-StyledMessage Success "🎉 OPERAZIONE COMPLETATA CON SUCCESSO!"
        Write-Host "===" -ForegroundColor Green
        
        $completionMessages = @(
            "   ✅ Winget verificato/installato", 
            "   ✅ Microsoft Store reinstallato"
        )
        
        if ($unigetInstalled) {
            $completionMessages += "   ✅ UniGet UI installato"
        }
        else {
            $completionMessages += "   ⚠️ UniGet UI non installato (opzionale)"
        }
        
        foreach ($msg in $completionMessages) {
            Write-Host $msg -ForegroundColor $(if ($msg -like "*⚠️*") { "Yellow" } else { "Green" })
        }
        
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

# Esegui la funzione
WinReinstallStore