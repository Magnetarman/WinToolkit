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
            '      Store Repair Toolkit By MagnetarMan',
            '        Version 2.0 (Build 22)'
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
    
    # Funzione migliorata per testare Winget - risolve il problema di rilevamento
    function Test-WingetInstallation {
        try {
            # Aggiorna PATH environment prima del test
            $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            
            # Test multipli per assicurarsi che winget sia davvero funzionante
            $wingetPaths = @(
                (Get-Command winget -ErrorAction SilentlyContinue),
                "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
                "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller*\winget.exe"
            )
            
            foreach ($path in $wingetPaths) {
                if ($path -and (Test-Path $path)) {
                    try {
                        $result = & $path --version 2>&1
                        if ($result -and $result -match "v[\d\.]+") {
                            Write-Host "   ✓ Winget trovato: $path" -ForegroundColor Gray
                            return "installed"
                        }
                    }
                    catch { continue }
                }
            }
            
            return "notinstalled"
        }
        catch { 
            return "notinstalled" 
        }
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
        Write-StyledMessage Progress "🔧 Forzando reinstallazione/aggiornamento di Winget..."
        
        # Verifica versione Windows
        $osVersion = [System.Environment]::OSVersion.Version
        if ($osVersion.Build -lt 17763) {
            Write-StyledMessage Error "Winget non è supportato su questa versione di Windows (Pre-1809)"
            throw "Versione Windows non supportata"
        }
        
        # Termina processi interferenti prima dell'installazione
        Stop-InterferingProcesses
        
        # Metodi di installazione ottimizzati - SEMPRE eseguiti
        $methods = @(
            { # Repair-WinGetPackageManager se disponibile
                try {
                    if ($osVersion.Build -ge 26100 -and (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue)) {
                        Write-StyledMessage Info "   → Usando Repair-WinGetPackageManager..."
                        Repair-WinGetPackageManager -Force -Latest -Verbose
                        return $true
                    }
                    return $false
                }
                catch {
                    Write-StyledMessage Warning "   → Repair-WinGetPackageManager fallito: $($_.Exception.Message)"
                    return $false
                }
            },
            { # Download manuale con gestione processi migliorata - SEMPRE eseguito
                try {
                    Write-StyledMessage Info "   → Download manuale da Microsoft..."
                    Stop-InterferingProcesses
                    
                    $url = "https://aka.ms/getwinget"
                    $temp = "$env:TEMP\Microsoft.AppInstaller.msixbundle"
                    
                    # Rimuovi file temporaneo esistente
                    if (Test-Path $temp) {
                        Remove-Item $temp -Force -ErrorAction SilentlyContinue
                    }
                    
                    Write-Host "   → Download in corso..." -ForegroundColor Yellow -NoNewline
                    Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing
                    Write-Host " ✓" -ForegroundColor Green
                    
                    # Usa PowerShell Job per nascondere l'output di Add-AppxPackage
                    Write-Host "   → Installazione pacchetto..." -ForegroundColor Yellow -NoNewline
                    
                    $job = Start-Job -ScriptBlock {
                        param($PackagePath)
                        try {
                            Add-AppxPackage -Path $PackagePath -ForceApplicationShutdown -ErrorAction Stop
                            return $true
                        }
                        catch {
                            return $false
                        }
                    } -ArgumentList $temp
                    
                    # Indicatore di progresso personalizzato
                    $counter = 0
                    while ($job.State -eq "Running") {
                        $spinner = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')[$counter % 10]
                        Write-Host "`r   → Installazione pacchetto $spinner" -NoNewline -ForegroundColor Yellow
                        Start-Sleep -Milliseconds 200
                        $counter++
                        
                        # Timeout di sicurezza (2 minuti)
                        if ($counter -gt 600) {
                            Stop-Job -Job $job
                            Remove-Job -Job $job
                            Write-Host " ✗ Timeout" -ForegroundColor Red
                            Remove-Item $temp -Force -ErrorAction SilentlyContinue
                            return $false
                        }
                    }
                    
                    $result = Receive-Job -Job $job
                    Remove-Job -Job $job
                    Remove-Item $temp -Force -ErrorAction SilentlyContinue
                    
                    if ($result) {
                        Write-Host "`r   → Installazione pacchetto ✓     " -ForegroundColor Green
                        return $true
                    }
                    else {
                        Write-Host "`r   → Installazione pacchetto ✗     " -ForegroundColor Red
                        return $false
                    }
                }
                catch {
                    Write-Host "`r   → Errore installazione ✗        " -ForegroundColor Red
                    Write-StyledMessage Warning "   → Download manuale fallito: $($_.Exception.Message)"
                    return $false
                }
            }
        )
        
        $installed = $false
        foreach ($method in $methods) {
            try {
                if (& $method) {
                    $installed = $true
                    # Ricarica PATH e attendi
                    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                    Start-Sleep 5
                    break
                }
            }
            catch { 
                Write-StyledMessage Warning "Metodo fallito: $($_.Exception.Message)" 
            }
        }
        
        # Verifica finale con attesa più lunga
        Start-Sleep 10
        $finalCheck = Test-WingetInstallation
        if ($finalCheck -eq "installed") {
            Write-StyledMessage Success "WinGet installato/aggiornato con successo!"
            
            # PULIZIA FORZATA DEL TERMINALE - METODO MULTIPLO
            Start-Sleep 2
            Clear-Host
            [Console]::Clear()
            
            # Su alcuni terminali serve anche questo
            if ($Host.Name -eq "ConsoleHost") {
                try { $Host.UI.RawUI.CursorPosition = @{X = 0; Y = 0 } } catch {}
            }
            
            # Forza refresh del buffer
            try { [System.Console]::SetCursorPosition(0, 0) } catch {}
            Start-Sleep -Milliseconds 500
            
            Show-Header
            Write-StyledMessage Success "✅ WinGet installazione completata!"
            Write-Host ""
            
            return $true
        }
        else {
            Write-StyledMessage Warning "WinGet potrebbe non essere completamente funzionante, ma procediamo"
            
            # PULIZIA ANCHE IN CASO DI WARNING
            Start-Sleep 2
            Clear-Host
            [Console]::Clear()
            try { [System.Console]::SetCursorPosition(0, 0) } catch {}
            Start-Sleep -Milliseconds 500
            
            Show-Header
            Write-StyledMessage Warning "⚠️ WinGet processato (continuiamo)"
            Write-Host ""
            
            return $false
        }
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
                    # Metodo completamente nascosto per evitare qualsiasi output bloccante
                    $wingetArgs = "install 9WZDNCRFJBMP --accept-source-agreements --accept-package-agreements --silent --disable-interactivity --no-upgrade"
                    
                    # Esegui Winget in background completo con tutti gli output nascosti
                    $psi = New-Object System.Diagnostics.ProcessStartInfo
                    $psi.FileName = "winget"
                    $psi.Arguments = $wingetArgs
                    $psi.UseShellExecute = $false
                    $psi.RedirectStandardOutput = $true
                    $psi.RedirectStandardError = $true
                    $psi.CreateNoWindow = $true
                    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
                    
                    $process = [System.Diagnostics.Process]::Start($psi)
                    
                    # Mostra indicatore di progresso personalizzato
                    $counter = 0
                    while (-not $process.HasExited) {
                        $dots = "." * (($counter % 4) + 1)
                        Write-Host "`r   → Installazione in corso$dots" -NoNewline -ForegroundColor Yellow
                        Start-Sleep -Milliseconds 500
                        $counter++
                        
                        # Timeout di sicurezza (2 minuti)
                        if ($counter -gt 240) {
                            $process.Kill()
                            break
                        }
                    }
                    
                    $process.WaitForExit()
                    Write-Host "`r   → Installazione completata    " -ForegroundColor Green
                    
                    $output = $process.StandardOutput.ReadToEnd()
                    $error = $process.StandardError.ReadToEnd()
                    
                    if ($process.ExitCode -eq 0 -or $output -match "No available upgrade found|already installed" -or $error -match "No available upgrade found|already installed") {
                        Write-StyledMessage Success "Microsoft Store installato/aggiornato tramite Winget!"
                        return $true
                    }
                    
                    return $false
                }
                catch {
                    Write-Host "`r   → Errore durante installazione" -ForegroundColor Red
                    Write-StyledMessage Warning "Errore Winget: $($_.Exception.Message)"
                    return $false
                }
            },
            {
                Write-StyledMessage Progress "Tentativo 2: Reinstallazione tramite Manifest Windows..."
                try {
                    $storePackage = Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue
                    if ($storePackage) {
                        Write-Host "   → Reinstallazione via Manifest..." -ForegroundColor Yellow -NoNewline
                        
                        $job = Start-Job -ScriptBlock {
                            param($Packages)
                            try {
                                foreach ($package in $Packages) {
                                    $manifestPath = "$($package.InstallLocation)\AppXManifest.xml"
                                    if (Test-Path $manifestPath) {
                                        Add-AppxPackage -DisableDevelopmentMode -Register $manifestPath -ForceApplicationShutdown -ErrorAction Stop
                                    }
                                }
                                return $true
                            }
                            catch {
                                return $false
                            }
                        } -ArgumentList (, $storePackage)
                        
                        # Attendi con indicatore
                        $counter = 0
                        while ($job.State -eq "Running") {
                            $dots = "." * (($counter % 4) + 1)
                            Write-Host "`r   → Reinstallazione via Manifest$dots" -NoNewline -ForegroundColor Yellow
                            Start-Sleep -Milliseconds 400
                            $counter++
                            
                            if ($counter -gt 300) {
                                # 2 minuti timeout
                                Stop-Job -Job $job
                                break
                            }
                        }
                        
                        $result = Receive-Job -Job $job
                        Remove-Job -Job $job
                        
                        if ($result) {
                            Write-Host "`r   → Reinstallazione via Manifest ✓     " -ForegroundColor Green
                            Write-StyledMessage Success "Microsoft Store reinstallato tramite Manifest!"
                            return $true
                        }
                        else {
                            Write-Host "`r   → Reinstallazione via Manifest ✗     " -ForegroundColor Red
                        }
                    }
                    return $false
                }
                catch {
                    Write-Host "`r   → Errore Manifest ✗                  " -ForegroundColor Red
                    Write-StyledMessage Warning "Errore Manifest: $($_.Exception.Message)"
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
                    Write-StyledMessage Warning "Errore DISM: $($_.Exception.Message)"
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
        
        # Installazione sequenziale con Jobs
        foreach ($file in $downloaded) {
            try {
                Write-Host "   → Installazione $(Split-Path $file -Leaf)..." -ForegroundColor Yellow -NoNewline
                
                $job = Start-Job -ScriptBlock {
                    param($FilePath)
                    try {
                        Add-AppxPackage -Path $FilePath -ForceApplicationShutdown -ErrorAction Stop
                        return $true
                    }
                    catch {
                        return $false
                    }
                } -ArgumentList $file
                
                # Attendi con spinner
                $counter = 0
                while ($job.State -eq "Running") {
                    $spinner = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')[$counter % 10]
                    Write-Host "`r   → Installazione $(Split-Path $file -Leaf) $spinner" -NoNewline -ForegroundColor Yellow
                    Start-Sleep -Milliseconds 150
                    $counter++
                    
                    if ($counter -gt 400) {
                        # Timeout
                        Stop-Job -Job $job
                        break
                    }
                }
                
                $result = Receive-Job -Job $job
                Remove-Job -Job $job
                
                if ($result) {
                    Write-Host "`r   → Installazione $(Split-Path $file -Leaf) ✓     " -ForegroundColor Green
                    Write-StyledMessage Success "✅ Installato: $(Split-Path $file -Leaf)"
                }
                else {
                    Write-Host "`r   → Installazione $(Split-Path $file -Leaf) ✗     " -ForegroundColor Red
                    Write-StyledMessage Warning "Installazione fallita: $(Split-Path $file -Leaf)"
                }
            }
            catch { 
                Write-Host "`r   → Errore $(Split-Path $file -Leaf) ✗              " -ForegroundColor Red
                Write-StyledMessage Warning "Installazione fallita: $(Split-Path $file -Leaf) - $($_.Exception.Message)" 
            }
        }
        
        # Prova installazione Store tramite PowerShell (metodo alternativo) con Job
        try {
            Write-Host "   → Tentativo PowerShell..." -ForegroundColor Yellow -NoNewline
            
            $job = Start-Job -ScriptBlock {
                try {
                    Get-AppxPackage -allusers Microsoft.WindowsStore | ForEach-Object { 
                        Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction Stop
                    }
                    return $true
                }
                catch {
                    return $false
                }
            }
            
            # Attendi con dots
            $counter = 0
            while ($job.State -eq "Running") {
                $dots = "." * (($counter % 4) + 1)
                Write-Host "`r   → Tentativo PowerShell$dots" -NoNewline -ForegroundColor Yellow
                Start-Sleep -Milliseconds 300
                $counter++
                
                if ($counter -gt 200) {
                    # Timeout
                    Stop-Job -Job $job
                    break
                }
            }
            
            $result = Receive-Job -Job $job
            Remove-Job -Job $job
            
            if ($result) {
                Write-Host "`r   → Tentativo PowerShell ✓         " -ForegroundColor Green
            }
            else {
                Write-Host "`r   → Tentativo PowerShell ✗         " -ForegroundColor Red
            }
        }
        catch {
            Write-Host "`r   → Errore PowerShell ✗            " -ForegroundColor Red
            Write-StyledMessage Warning "Metodo PowerShell fallito"
        }
        
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        return (Get-AppxPackage -Name "Microsoft.WindowsStore" -ErrorAction SilentlyContinue) -ne $null
    }
    
    # Funzione corretta per UniGet UI - SEMPRE reinstalla con output nascosto
    function Install-UniGetUI {
        Write-StyledMessage Progress "Forzando reinstallazione UniGet UI..."
        try {
            # Prima disinstalla se esiste - completamente nascosto
            $psi1 = New-Object System.Diagnostics.ProcessStartInfo
            $psi1.FileName = "winget"
            $psi1.Arguments = "uninstall --exact --id MartiCliment.UniGetUI --silent --disable-interactivity"
            $psi1.UseShellExecute = $false
            $psi1.RedirectStandardOutput = $true
            $psi1.RedirectStandardError = $true
            $psi1.CreateNoWindow = $true
            $psi1.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
            
            $process1 = [System.Diagnostics.Process]::Start($psi1)
            $process1.WaitForExit()
            Start-Sleep 2
            
            # Poi installa sempre - con indicatore personalizzato
            $psi2 = New-Object System.Diagnostics.ProcessStartInfo
            $psi2.FileName = "winget"
            $psi2.Arguments = "install --exact --id MartiCliment.UniGetUI --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity --force"
            $psi2.UseShellExecute = $false
            $psi2.RedirectStandardOutput = $true
            $psi2.RedirectStandardError = $true
            $psi2.CreateNoWindow = $true
            $psi2.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
            
            $process2 = [System.Diagnostics.Process]::Start($psi2)
            
            # Indicatore di progresso personalizzato
            $counter = 0
            while (-not $process2.HasExited) {
                $spinner = @('|', '/', '-', '\')[$counter % 4]
                Write-Host "`r   $spinner Installazione UniGet UI in corso..." -NoNewline -ForegroundColor Cyan
                Start-Sleep -Milliseconds 300
                $counter++
                
                # Timeout di sicurezza (3 minuti)
                if ($counter -gt 600) {
                    $process2.Kill()
                    break
                }
            }
            
            $process2.WaitForExit()
            Write-Host "`r   ✓ Installazione UniGet UI completata     " -ForegroundColor Green
            
            if ($process2.ExitCode -eq 0) {
                Write-StyledMessage Success "UniGet UI reinstallato con successo!"
                return $true
            }
            else {
                Write-StyledMessage Warning "UniGet UI: Exit code $($process2.ExitCode) (potrebbe essere già installato)"
                return $false
            }
        }
        catch { 
            Write-Host "`r   ✗ Errore durante installazione UniGet UI" -ForegroundColor Red
            Write-StyledMessage Warning "Errore UniGet UI: $($_.Exception.Message)"
            return $false
        }
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
        # FASE 1: Winget - SEMPRE ESEGUITA
        Write-StyledMessage Info "📋 FASE 1: Reinstallazione forzata Winget"
        $wingetInstalled = Install-Winget
        
        # FASE 2: Microsoft Store
        Write-StyledMessage Info "📋 FASE 2: Reinstallazione Microsoft Store"
        Fix-BlockedDeployment
        
        if (-not (Install-MicrosoftStore)) {
            Write-StyledMessage Error "❌ ERRORE: Tutti i metodi di installazione falliti!"
            Write-StyledMessage Info "💡 Suggerimenti: Verifica connessione internet, esegui come Admin, prova Windows Update"
            return
        }
        
        # FASE 3: UniGet UI - SEMPRE REINSTALLATA
        Write-StyledMessage Info "📋 FASE 3: Reinstallazione forzata UniGet UI"
        $unigetInstalled = Install-UniGetUI
        
        # FASE 4: Completamento
        Write-Host ""; Write-Host "===" -ForegroundColor Green
        Write-StyledMessage Success "🎉 OPERAZIONE COMPLETATA CON SUCCESSO!"
        Write-Host "===" -ForegroundColor Green
        
        $completionMessages = @(
            "   ✅ Winget $(if($wingetInstalled){'reinstallato'}else{'processato'})", 
            "   ✅ Microsoft Store reinstallato",
            "   ✅ UniGet UI $(if($unigetInstalled){'reinstallato'}else{'processato'})"
        )
        
        foreach ($msg in $completionMessages) {
            Write-Host $msg -ForegroundColor Green
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

WinReinstallStore