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
    
    param(
        [int]$CountdownSeconds = 30
    )
    
    # Inizializzazione e header grafico
    $Host.UI.RawUI.WindowTitle = "Store Repair Toolkit By MagnetarMan"
    Clear-Host
    
    # Funzione per centrare il testo
    function Center-Text {
        param([string]$Text, [int]$Width)
        $padding = [math]::Max(0, ($Width - $Text.Length) / 2)
        return (' ' * $padding) + $Text
    }
    
    # Header grafico
    $width = 65
    Write-Host ('═' * $width) -ForegroundColor Green
    $asciiArt = @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        '    Store Repair Toolkit By MagnetarMan',
        '        Version 2.0 (Build 10)'
    )
    foreach ($line in $asciiArt) {
        Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
    }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''
    
    # Variabili globali e configurazione
    $MsgStyles = @{
        Success  = @{ Color = 'Green'; Icon = '✅' }
        Warning  = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error    = @{ Color = 'Red'; Icon = '❌' }
        Info     = @{ Color = 'Cyan'; Icon = '💎' }
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
            }
            else {
                return "outdated"
            }
        }
        catch {
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
            }
            else {
                throw "Aggiornamento WinGet fallito con codice: $($result.ExitCode)"
            }
        }
        catch {
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
        }
        catch {
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
            
        }
        catch {
            Write-StyledMessage Warning "Installazione tramite download diretto fallita: $($_.Exception.Message)"
        }
        
        return $false
    }
    
    function Install-MicrosoftStore {
        Write-StyledMessage Info "🏪 Iniziando reinstallazione Microsoft Store..."
        
        # Metodo 1: Winget
        Write-StyledMessage Progress "Tentativo 1: Installazione tramite Winget..."
        try {
            $output = winget install 9WZDNCRFJBMP --accept-source-agreements --accept-package-agreements 2>&1
            if ($output -match "No available upgrade found" -or $output -match "already installed") {
                Write-StyledMessage Success "Microsoft Store risulta già installato e aggiornato tramite Winget!"
            }
            elseif ($LASTEXITCODE -eq 0) {
                Write-StyledMessage Success "Microsoft Store installato con successo tramite Winget!"
            }
            else {
                throw "Installazione Microsoft Store tramite Winget fallita. Codice uscita: $LASTEXITCODE"
            }
        }
        catch {
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
            }
            else {
                throw "Nessun pacchetto Microsoft Store trovato nel sistema"
            }
        }
        catch {
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
        }
        catch {
            Write-StyledMessage Warning "Installazione tramite DISM fallita: $($_.Exception.Message)"
        }
        
        # Metodo 4: Download manuale
        try {
            Write-StyledMessage Progress "Tentativo 4: Download e installazione manuale..."
    
            $TempDir = "$env:TEMP\MSStore"
            New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    
            # Verifica privilegi amministratore
            if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                throw "Sono necessari privilegi di amministratore per l'installazione manuale"
            }
    
            Write-StyledMessage Info "📥 Download dei pacchetti Microsoft Store..."
    
            # Funzione per query a store.rg-adguard.net
            function Get-StorePackageUrls {
                param(
                    [string]$PackageIdentifier,
                    [string]$Ring = "Retail"
                )
        
                $body = @{
                    type = 'url'
                    url  = $PackageIdentifier
                    ring = $Ring
                    lang = 'it-IT'
                }
        
                try {
                    $response = Invoke-RestMethod -Uri "https://store.rg-adguard.net/api/GetFiles" -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
            
                    # Parsing della risposta HTML per estrarre i link di download
                    if ($response -match '<a[^>]+href="([^"]+\.(?:appx|msix|appxbundle|msixbundle))"[^>]*>([^<]+)</a>') {
                        $urls = @()
                        $matches = [regex]::Matches($response, '<a[^>]+href="([^"]+\.(?:appx|msix|appxbundle|msixbundle))"[^>]*>([^<]+)</a>')
                        foreach ($match in $matches) {
                            $urls += @{
                                Url      = $match.Groups[1].Value
                                FileName = $match.Groups[2].Value.Trim()
                            }
                        }
                        return $urls
                    }
                }
                catch {
                    Write-StyledMessage Warning "Errore nel recupero URL per $PackageIdentifier : $($_.Exception.Message)"
                }
                return @()
            }
    
            # Funzione per download con retry
            function Download-Package {
                param(
                    [string]$Url,
                    [string]$FilePath,
                    [int]$MaxRetries = 3
                )
        
                for ($i = 1; $i -le $MaxRetries; $i++) {
                    try {
                        Write-StyledMessage Info "  -> Download tentativo $i : $(Split-Path $FilePath -Leaf)"
                        Invoke-WebRequest -Uri $Url -OutFile $FilePath -UseBasicParsing -TimeoutSec 300
                        if (Test-Path $FilePath) {
                            Write-StyledMessage Success "  -> ✅ Download completato"
                            return $true
                        }
                    }
                    catch {
                        Write-StyledMessage Warning "  -> ❌ Tentativo $i fallito: $($_.Exception.Message)"
                        if ($i -eq $MaxRetries) {
                            throw "Download fallito dopo $MaxRetries tentativi"
                        }
                        Start-Sleep -Seconds (2 * $i)
                    }
                }
                return $false
            }
    
            # Pacchetti da scaricare in ordine di dipendenza
            $PackagesToDownload = @(
                @{
                    Name       = "Microsoft.VCLibs.140.00"
                    Identifier = "https://www.microsoft.com/store/productId/9PGJGD53TN86"
                    Pattern    = "*VCLibs*x64*"
                    Required   = $true
                },
                @{
                    Name       = "Microsoft.VCLibs.140.00.UWPDesktop"
                    Identifier = "https://www.microsoft.com/store/productId/9PGJGD53TN86"
                    Pattern    = "*VCLibs*UWPDesktop*x64*"
                    Required   = $true
                },
                @{
                    Name       = "Microsoft.UI.Xaml.2.8"
                    Identifier = "https://www.microsoft.com/store/productId/9NXQXXLFST89"
                    Pattern    = "*UI.Xaml*x64*"
                    Required   = $true
                },
                @{
                    Name       = "Microsoft.NET.Native.Framework.2.2"
                    Identifier = "https://www.microsoft.com/store/productId/9NBLGGH1Z6CD"
                    Pattern    = "*NET.Native.Framework*x64*"
                    Required   = $false
                },
                @{
                    Name       = "Microsoft.WindowsStore"
                    Identifier = "https://www.microsoft.com/store/productId/9WZDNCRFJBMP"
                    Pattern    = "*WindowsStore*"
                    Required   = $true
                }
            )
    
            $DownloadedFiles = @()
    
            # Download dei pacchetti
            foreach ($package in $PackagesToDownload) {
                Write-StyledMessage Info "🔍 Ricerca pacchetto: $($package.Name)"
        
                $urls = Get-StorePackageUrls -PackageIdentifier $package.Identifier
        
                if ($urls.Count -eq 0) {
                    if ($package.Required) {
                        throw "Impossibile trovare URL per il pacchetto richiesto: $($package.Name)"
                    }
                    else {
                        Write-StyledMessage Warning "Pacchetto opzionale non trovato: $($package.Name)"
                        continue
                    }
                }
        
                # Filtra per architettura x64 e trova il file più appropriato
                $targetUrl = $urls | Where-Object { 
                    $_.FileName -like $package.Pattern -and 
                    ($_.FileName -like "*x64*" -or $_.FileName -notlike "*arm*") 
                } | Sort-Object FileName | Select-Object -Last 1
        
                if (-not $targetUrl) {
                    if ($package.Required) {
                        throw "Impossibile trovare file compatibile per: $($package.Name)"
                    }
                    else {
                        Write-StyledMessage Warning "File compatibile non trovato per: $($package.Name)"
                        continue
                    }
                }
        
                $fileName = $targetUrl.FileName -replace '[<>:"/\\|?*]', '_'
                $filePath = Join-Path $TempDir $fileName
        
                if (Download-Package -Url $targetUrl.Url -FilePath $filePath) {
                    $DownloadedFiles += @{
                        Path      = $filePath
                        Name      = $package.Name
                        IsMainApp = ($package.Name -eq "Microsoft.WindowsStore")
                    }
                }
                elseif ($package.Required) {
                    throw "Download fallito per pacchetto richiesto: $($package.Name)"
                }
            }
    
            if ($DownloadedFiles.Count -eq 0) {
                throw "Nessun pacchetto scaricato con successo"
            }
    
            Write-StyledMessage Success "📦 Download completato. Inizio installazione..."
    
            # Installazione in ordine di dipendenza
            $DependencyOrder = @(
                "Microsoft.VCLibs.140.00",
                "Microsoft.VCLibs.140.00.UWPDesktop", 
                "Microsoft.NET.Native.Framework.2.2",
                "Microsoft.UI.Xaml.2.8"
            )
    
            # Prima installa le dipendenze
            foreach ($depName in $DependencyOrder) {
                $depFile = $DownloadedFiles | Where-Object { $_.Name -eq $depName }
                if ($depFile) {
                    Write-StyledMessage Info "🔧 Installazione dipendenza: $($depFile.Name)"
                    try {
                        Add-AppxPackage -Path $depFile.Path -ForceApplicationShutdown
                        Write-StyledMessage Success "  -> ✅ Installato con successo"
                    }
                    catch {
                        # Non bloccare per dipendenze opzionali
                        if ($depName -like "*NET.Native*") {
                            Write-StyledMessage Warning "  -> ⚠️ Installazione opzionale fallita: $($_.Exception.Message)"
                        }
                        else {
                            Write-StyledMessage Warning "  -> ❌ Installazione fallita: $($_.Exception.Message)"
                            # Continua comunque, potrebbe già essere installato
                        }
                    }
                }
            }
    
            # Poi installa Microsoft Store
            $storeFile = $DownloadedFiles | Where-Object { $_.IsMainApp -eq $true }
            if ($storeFile) {
                Write-StyledMessage Info "🏪 Installazione Microsoft Store..."
                try {
                    Add-AppxPackage -Path $storeFile.Path -ForceApplicationShutdown
                    Write-StyledMessage Success "✅ Microsoft Store installato con successo!"
            
                    # Avvia il servizio Windows Store se non è in esecuzione
                    $storeService = Get-Service -Name "WSService" -ErrorAction SilentlyContinue
                    if ($storeService -and $storeService.Status -ne "Running") {
                        Start-Service -Name "WSService" -ErrorAction SilentlyContinue
                    }
            
                    # Verifica installazione
                    Start-Sleep -Seconds 3
                    $storeApp = Get-AppxPackage -Name "Microsoft.WindowsStore" -ErrorAction SilentlyContinue
                    if ($storeApp) {
                        Write-StyledMessage Success "🎉 Installazione verificata con successo!"
                        Write-StyledMessage Info "💡 Puoi ora aprire Microsoft Store dal menu Start"
                    }
                    else {
                        Write-StyledMessage Warning "⚠️ Installazione completata ma verifica fallita"
                    }
                }
                catch {
                    throw "Installazione Microsoft Store fallita: $($_.Exception.Message)"
                }
            }
            else {
                throw "File Microsoft Store non trovato nei download"
            }
    
            # Pulizia file temporanei
            try {
                Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-StyledMessage Info "🧹 File temporanei rimossi"
            }
            catch {
                Write-StyledMessage Warning "Impossibile rimuovere file temporanei da $TempDir"
            }
        }
        catch {
            Write-StyledMessage Error "❌ Download/installazione manuale fallita: $($_.Exception.Message)"
    
            # Cleanup in caso di errore
            if (Test-Path $TempDir) {
                try {
                    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                catch {
                    # Ignora errori di cleanup
                }
            }
    
            throw $_.Exception
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
            }
            else {
                Write-StyledMessage Warning "Installazione UniGet UI fallita con codice: $($result.ExitCode)"
                return $false
            }
        }
        catch {
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
    
    Write-StyledMessage Info "🏪 REINSTALLAZIONE MICROSOFT STORE - AVVIO PROCEDURA"
    Write-Host "===" -ForegroundColor Magenta
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
        Write-Host "===" -ForegroundColor Green
        Write-StyledMessage Success "🎉 OPERAZIONE COMPLETATA CON SUCCESSO!"
        Write-Host "===" -ForegroundColor Green
        Write-Host ""
        
        Write-StyledMessage Info "📝 Riepilogo operazioni completate:"
        Write-Host "   ✅ Winget verificato/installato" -ForegroundColor Green
        Write-Host "   ✅ Microsoft Store reinstallato" -ForegroundColor Green
        Write-Host "   ✅ UniGet UI installato" -ForegroundColor Green
        Write-Host ""
        
        Write-StyledMessage Warning "⚠️ È necessario riavviare il sistema per applicare tutte le modifiche"
        
        # Countdown per riavvio
        $shouldRestart = Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio del sistema"
        
        if ($shouldRestart) {
            Write-StyledMessage Info "🔄 Riavvio del sistema in corso..."
            shutdown /r /t 0
        }
        
    }
    catch {
        Write-Host ""
        Write-Host "===" -ForegroundColor Red
        Write-StyledMessage Error " ERRORE DURANTE L'ESECUZIONE"
        Write-Host "===" -ForegroundColor Red
        Write-Host ""
        Write-StyledMessage Error "Dettagli errore: $($_.Exception.Message)"
        Write-Host ""
        Write-StyledMessage Info "💡 Per assistenza:"
        Write-Host Info "Verifica di eseguire PowerShell come Amministratore" -ForegroundColor Yellow
        Write-Host Info "Controlla la connessione internet" -ForegroundColor Yellow
        Write-Host Info "Prova a eseguire Windows Update" -ForegroundColor Yellow
        Write-Host Info "Riavvia il sistema e riprova" -ForegroundColor Yellow
    }
}

# Esempio di utilizzo:
WinReinstallStore
# WinReinstallStore -CountdownSeconds 60