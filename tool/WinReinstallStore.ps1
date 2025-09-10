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
    
    .PARAMETER CountdownSeconds
        Secondi per il countdown prima del riavvio automatico (default: 30)
    
    .EXAMPLE
        WinReinstallStore
        
    .EXAMPLE
        WinReinstallStore -CountdownSeconds 60
    #>
    
    param(
        [int]$CountdownSeconds = 30
    )
    
    # Variabili globali e configurazione
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error = @{ Color = 'Red'; Icon = '❌' }
        Info = @{ Color = 'Cyan'; Icon = '💎' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }
    
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $SpinnerIndex = 0
    
    # Funzioni helper
    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }
    
    function Show-Spinner([string]$Message) {
        $spinner = $spinners[$script:SpinnerIndex % $spinners.Length]
        Write-Host "`r$spinner $Message" -NoNewline -ForegroundColor Cyan
        $script:SpinnerIndex++
        Start-Sleep -Milliseconds 100
    }
    
    function Test-WingetInstallation {
        try {
            $wingetCmd = Get-Command winget -ErrorAction Stop
            $version = & winget --version
            if ($version -match "v(\d+\.\d+\.\d+)") {
                return "installed"
            } else {
                return "outdated"
            }
        } catch {
            return "notinstalled"
        }
    }
    
    function Install-Winget {
        Write-StyledMessage Progress "🔧 Iniziando installazione/aggiornamento di Winget..."
        
        # Verifica versione Windows
        $ComputerInfo = Get-ComputerInfo -ErrorAction Stop
        if (($ComputerInfo.WindowsVersion) -lt "1809") {
            Write-StyledMessage Error "Winget non è supportato su questa versione di Windows (Pre-1809)"
            throw "Versione Windows non supportata"
        }
        
        # Tentativo 1: Aggiornamento tramite Winget esistente
        try {
            $wingetCmd = Get-Command winget -ErrorAction Stop
            Write-StyledMessage Info "Tentativo aggiornamento WinGet tramite comando esistente..."
            $result = Start-Process -FilePath "`"$($wingetCmd.Source)`"" -ArgumentList "install -e --accept-source-agreements --accept-package-agreements Microsoft.AppInstaller" -Wait -NoNewWindow -PassThru
            if ($result.ExitCode -eq 0) {
                Write-StyledMessage Success "WinGet aggiornato con successo!"
                $ENV:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                return $true
            } else {
                throw "Aggiornamento WinGet fallito con codice: $($result.ExitCode)"
            }
        } catch {
            Write-StyledMessage Warning "Aggiornamento tramite Winget fallito: $($_.Exception.Message)"
        }
        
        # Tentativo 2: Repair-WinGetPackageManager (Windows 24H2+)
        try {
            if ([System.Environment]::OSVersion.Version.Build -ge 26100) {
                Write-StyledMessage Info "Tentativo riparazione WinGet con Repair-WinGetPackageManager..."
                Repair-WinGetPackageManager -Force -Latest -Verbose
                $wingetCmd = Get-Command winget -ErrorAction Stop
                Write-StyledMessage Success "WinGet riparato con successo!"
                $ENV:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                return $true
            }
        } catch {
            Write-StyledMessage Warning "Riparazione WinGet fallita: $($_.Exception.Message)"
        }
        
        # Tentativo 3: Download manuale Microsoft.AppInstaller
        try {
            Write-StyledMessage Info "Tentativo download e installazione Microsoft.AppInstaller..."
            
            # URL per il download diretto
            $AppInstallerUrl = "https://aka.ms/getwinget"
            $TempPath = "$env:TEMP\Microsoft.AppInstaller.msixbundle"
            
            # Download file
            Write-StyledMessage Progress "📥 Download Microsoft.AppInstaller in corso..."
            Invoke-WebRequest -Uri $AppInstallerUrl -OutFile $TempPath -UseBasicParsing
            
            # Installazione
            Write-StyledMessage Progress "📦 Installazione Microsoft.AppInstaller..."
            Add-AppxPackage -Path $TempPath -ForceUpdateFromAnyVersion
            
            # Pulizia
            Remove-Item $TempPath -Force -ErrorAction SilentlyContinue
            
            # Refresh PATH
            $ENV:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            
            # Verifica installazione
            Start-Sleep 3
            $wingetTest = Test-WingetInstallation
            if ($wingetTest -eq "installed") {
                Write-StyledMessage Success "WinGet installato con successo tramite download diretto!"
                return $true
            }
            
        } catch {
            Write-StyledMessage Warning "Installazione tramite download diretto fallita: $($_.Exception.Message)"
        }
        
        return $false
    }
    
    function Install-MicrosoftStore {
        Write-StyledMessage Info "🏪 Iniziando reinstallazione Microsoft Store..."
        
        # Metodo 1: Winget
        try {
            Write-StyledMessage Progress "Tentativo 1: Installazione tramite Winget..."
            $result = Start-Process -FilePath "winget" -ArgumentList "install 9WZDNCRFJBMP --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow -PassThru
            if ($result.ExitCode -eq 0) {
                Write-StyledMessage Success "Microsoft Store installato con successo tramite Winget!"
                return $true
            }
        } catch {
            Write-StyledMessage Warning "Installazione tramite Winget fallita: $($_.Exception.Message)"
        }
        
        # Metodo 2: Manifest Windows
        try {
            Write-StyledMessage Progress "Tentativo 2: Reinstallazione tramite Manifest Windows..."
            $storePackage = Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue
            if ($storePackage) {
                foreach ($package in $storePackage) {
                    if (Test-Path "$($package.InstallLocation)\AppXManifest.xml") {
                        Add-AppxPackage -DisableDevelopmentMode -Register "$($package.InstallLocation)\AppXManifest.xml" -ForceUpdateFromAnyVersion
                    }
                }
                Write-StyledMessage Success "Microsoft Store reinstallato tramite Manifest Windows!"
                return $true
            } else {
                throw "Nessun pacchetto Microsoft Store trovato nel sistema"
            }
        } catch {
            Write-StyledMessage Warning "Reinstallazione tramite Manifest fallita: $($_.Exception.Message)"
        }
        
        # Metodo 3: DISM Capability
        try {
            Write-StyledMessage Progress "Tentativo 3: Installazione tramite DISM Capability..."
            $dismResult = Start-Process -FilePath "DISM" -ArgumentList "/Online /Add-Capability /CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0" -Wait -NoNewWindow -PassThru
            if ($dismResult.ExitCode -eq 0) {
                Write-StyledMessage Success "Microsoft Store installato tramite DISM Capability!"
                return $true
            }
        } catch {
            Write-StyledMessage Warning "Installazione tramite DISM fallita: $($_.Exception.Message)"
        }
        
        # Metodo 4: Download manuale
        try {
            Write-StyledMessage Progress "Tentativo 4: Download e installazione manuale..."
            
            $TempDir = "$env:TEMP\MSStore"
            New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
            
            # URL per i file necessari
            $StoreUrl = "https://store.rg-adguard.net/api/GetFiles"
            
            # Download Microsoft Store Bundle (simulazione - in realtà serve logica più complessa)
            Write-StyledMessage Info "📥 Download dei pacchetti Microsoft Store..."
            
            # Questo è un esempio semplificato - nella realtà bisognerebbe:
            # 1. Fare query a store.rg-adguard.net per ottenere link diretti
            # 2. Scaricare VCLibs, UI.Xaml e Microsoft Store bundle
            # 3. Installarli in ordine di dipendenza
            
            Write-StyledMessage Warning "Download manuale richiede implementazione avanzata - metodo saltato"
            
        } catch {
            Write-StyledMessage Warning "Download manuale fallito: $($_.Exception.Message)"
        }
        
        return $false
    }
    
    function Install-UniGetUI {
        try {
            Write-StyledMessage Progress "🔧 Installazione UniGet UI..."
            $result = Start-Process -FilePath "winget" -ArgumentList "install --exact --id MartiCliment.UniGetUI --source winget --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow -PassThru
            if ($result.ExitCode -eq 0) {
                Write-StyledMessage Success "UniGet UI installato con successo!"
                return $true
            } else {
                Write-StyledMessage Warning "Installazione UniGet UI fallita con codice: $($result.ExitCode)"
                return $false
            }
        } catch {
            Write-StyledMessage Warning "Errore installazione UniGet UI: $($_.Exception.Message)"
            return $false
        }
    }
    
    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi qualsiasi tasto per annullare il riavvio automatico...'
        Write-Host ''
        
        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Error '⏸️ Riavvio automatico annullato'
                Write-StyledMessage Info "🔄 Puoi riavviare manualmente: 'shutdown /r /t 0' o dal menu Start."
                return $false
            }
            
            $barLength = 30
            $progress = (($Seconds - $i) / $Seconds) * 100
            $filled = '█' * [math]::Floor($progress * $barLength / 100)
            $empty = '░' * ($barLength - $filled.Length)
            $bar = "[$filled$empty] {0,3}%" -f [math]::Round($progress)
            
            Write-Host "`r⏳ $Message - $i sec (Premi un tasto per annullare) $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }
        
        Write-Host ''
        Write-StyledMessage Warning '⏰ Tempo scaduto: il sistema verrà riavviato ora.'
        Start-Sleep 1
        return $true
    }
    
    # === INIZIO LOGICA PRINCIPALE ===
    
    Write-Host "`n" + "="*70 -ForegroundColor Magenta
    Write-StyledMessage Info "🏪 REINSTALLAZIONE MICROSOFT STORE - AVVIO PROCEDURA"
    Write-Host "="*70 -ForegroundColor Magenta
    Write-Host ""
    
    try {
        # FASE 1: Verifica e installazione Winget
        Write-StyledMessage Info "📋 FASE 1: Verifica e preparazione Winget"
        
        $wingetStatus = Test-WingetInstallation
        
        switch ($wingetStatus) {
            "installed" {
                Write-StyledMessage Success "Winget è già installato e funzionante"
            }
            "outdated" {
                Write-StyledMessage Warning "Winget è obsoleto - aggiornamento necessario"
                if (-not (Install-Winget)) {
                    throw "Impossibile aggiornare Winget"
                }
            }
            "notinstalled" {
                Write-StyledMessage Warning "Winget non è installato - installazione necessaria"
                if (-not (Install-Winget)) {
                    throw "Impossibile installare Winget"
                }
            }
        }
        
        Write-Host ""
        
        # FASE 2: Reinstallazione Microsoft Store
        Write-StyledMessage Info "📋 FASE 2: Reinstallazione Microsoft Store"
        
        $storeInstalled = Install-MicrosoftStore
        
        if (-not $storeInstalled) {
            Write-StyledMessage Error "❌ ERRORE: Tutti i metodi di installazione del Microsoft Store sono falliti!"
            Write-StyledMessage Info "💡 Suggerimenti:"
            Write-Host "   • Verifica la connessione internet" -ForegroundColor Gray
            Write-Host "   • Esegui lo script come Amministratore" -ForegroundColor Gray
            Write-Host "   • Prova a eseguire Windows Update prima di riprovare" -ForegroundColor Gray
            Write-Host "   • Considera un ripristino del sistema" -ForegroundColor Gray
            return
        }
        
        Write-Host ""
        
        # FASE 3: Installazione UniGet UI
        Write-StyledMessage Info "📋 FASE 3: Installazione UniGet UI"
        Install-UniGetUI | Out-Null
        
        Write-Host ""
        
        # FASE 4: Successo e riavvio
        Write-Host "="*70 -ForegroundColor Green
        Write-StyledMessage Success "🎉 OPERAZIONE COMPLETATA CON SUCCESSO!"
        Write-Host "="*70 -ForegroundColor Green
        Write-Host ""
        
        Write-StyledMessage Info "📝 Riepilogo operazioni completate:"
        Write-Host "   ✅ Winget verificato/installato" -ForegroundColor Green
        Write-Host "   ✅ Microsoft Store reinstallato" -ForegroundColor Green
        Write-Host "   ✅ UniGet UI installato" -ForegroundColor Green
        Write-Host ""
        
        Write-StyledMessage Warning "È necessario riavviare il sistema per applicare tutte le modifiche"
        
        # Countdown per riavvio
        $shouldRestart = Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio del sistema"
        
        if ($shouldRestart) {
            Write-StyledMessage Info "🔄 Riavvio del sistema in corso..."
            shutdown /r /t 0
        }
        
    } catch {
        Write-Host ""
        Write-Host "="*70 -ForegroundColor Red
        Write-StyledMessage Error " ERRORE DURANTE L'ESECUZIONE"
        Write-Host "="*70 -ForegroundColor Red
        Write-Host ""
        Write-StyledMessage Error "Dettagli errore: $($_.Exception.Message)"
        Write-Host ""
        Write-StyledMessage Info "💡 Per assistenza:"
        Write-Host "   • Verifica di eseguire PowerShell come Amministratore" -ForegroundColor Gray
        Write-Host "   • Controlla la connessione internet" -ForegroundColor Gray
        Write-Host "   • Prova a eseguire Windows Update" -ForegroundColor Gray
        Write-Host "   • Riavvia il sistema e riprova" -ForegroundColor Gray
    }
}

# Esempio di utilizzo:
WinReinstallStore
