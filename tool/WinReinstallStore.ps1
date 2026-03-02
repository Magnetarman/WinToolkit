function WinReinstallStore {
    <#
    .SYNOPSIS
        Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget.

    .DESCRIPTION
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI senza output bloccanti.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$NoReboot,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName "WinReinstallStore"
    Show-Header -SubTitle "Store Repair Toolkit"
    $Host.UI.RawUI.WindowTitle = "Store Repair Toolkit By MagnetarMan"

    # ============================================================================
    # 2. FUNZIONI HELPER LOCALI
    # ============================================================================

    function Install-WingetCore {
        Write-StyledMessage -Type 'Info' -Text "🚀 Avvio della procedura di reinstallazione e riparazione Winget..."

        # --- FASE 1: Inizializzazione e Pulizia Profonda ---

        # Terminazione processi interferenti — usa helper globale
        Write-StyledMessage -Type 'Info' -Text "🔄 Chiusura forzata dei processi Winget e correlati..."
        Stop-InterferingProcess

        # Terminazione processi specifici di Winget (inclusi nel global ma forziamo anche taskkill)
        @("winget", "WindowsPackageManagerServer") | ForEach-Object {
            taskkill /im "$_.exe" /f 2>$null
        }

        # Pulizia cartella temporanea
        Write-StyledMessage -Type 'Info' -Text "🔄 Pulizia dei file temporanei (%TEMP%\WinGet)..."
        $tempWingetPath = "$env:TEMP\WinGet"
        if (Test-Path $tempWingetPath) {
            Remove-Item -Path $tempWingetPath -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Write-StyledMessage -Type 'Info' -Text "Cartella temporanea di Winget eliminata."
        }
        else {
            Write-StyledMessage -Type 'Info' -Text "Cartella temporanea di Winget non trovata o già pulita."
        }

        # Reset sorgenti Winget
        Write-StyledMessage -Type 'Info' -Text "🔄 Reset delle sorgenti Winget..."
        try {
            $wingetExePath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
            if (Test-Path $wingetExePath) {
                & $wingetExePath source reset --force *>$null
            }
            else {
                winget source reset --force *>$null
            }
            Write-StyledMessage -Type 'Success' -Text "Sorgenti Winget resettate."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Reset sorgenti Winget non riuscito: $($_.Exception.Message)"
        }

        # --- FASE 2: Installazione Dipendenze e Moduli PowerShell ---

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Installazione Provider NuGet
        Write-StyledMessage -Type 'Info' -Text "🔄 Installazione PackageProvider NuGet..."
        try {
            if (-not (Get-Module -Name PowerShellGet -ListAvailable)) {
                Install-Module -Name PowerShellGet -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
            }
            else {
                Update-Module -Name PowerShellGet -Force -ErrorAction SilentlyContinue *>$null
            }

            $nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
            if (-not $nugetProvider) {
                try {
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                    Write-StyledMessage -Type 'Success' -Text "Provider NuGet installato."
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Provider NuGet: conferma manuale potrebbe essere richiesta. Errore: $($_.Exception.Message)"
                }
            }
            else {
                Write-StyledMessage -Type 'Success' -Text "Provider NuGet già installato."
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore durante l'installazione del provider NuGet: $($_.Exception.Message)"
        }

        # Installazione Modulo Microsoft.WinGet.Client
        Write-StyledMessage -Type 'Info' -Text "🔄 Installazione modulo Microsoft.WinGet.Client..."
        try {
            Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
            Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "Modulo Microsoft.WinGet.Client installato e importato."
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore installazione/import Microsoft.WinGet.Client: $($_.Exception.Message)"
        }

        # --- FASE 3: Riparazione e Reinstallazione del Core di Winget ---

        # Tentativo A — Riparazione via Modulo
        if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type 'Info' -Text "🔄 Riparazione Winget tramite modulo WinGet Client..."
            try {
                $result = Invoke-WithSpinner -Activity "Riparazione Winget (modulo)" -Process -Action {
                    $procParams = @{
                        FilePath     = 'powershell'
                        ArgumentList = @('-NoProfile', '-WindowStyle', 'Hidden', '-Command',
                            'Repair-WinGetPackageManager -Force -Latest 2>$null')
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                } -TimeoutSeconds 180

                if ($result.ExitCode -eq 0) {
                    Write-StyledMessage -Type 'Success' -Text "Winget riparato con successo tramite modulo."
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "Riparazione Winget tramite modulo non riuscita (ExitCode: $($result.ExitCode))."
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore durante la riparazione Winget: $($_.Exception.Message)"
            }
        }

        # Tentativo B — Reinstallazione tramite MSIXBundle (Fallback)
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Info' -Text "🔄 Installazione Winget tramite MSIXBundle..."
            $tempInstaller = Join-Path $AppConfig.Paths.Temp "WingetInstaller.msixbundle"

            try {
                $null = New-Item -Path $AppConfig.Paths.Temp -ItemType Directory -Force -ErrorAction SilentlyContinue

                $iwrParams = @{
                    Uri             = $AppConfig.URLs.WingetMSIX
                    OutFile         = $tempInstaller
                    UseBasicParsing = $true
                    ErrorAction     = 'Stop'
                }
                Invoke-WebRequest @iwrParams

                $result = Invoke-WithSpinner -Activity "Installazione Winget MSIXBundle" -Process -Action {
                    $procParams = @{
                        FilePath     = 'powershell'
                        ArgumentList = @('-NoProfile', '-WindowStyle', 'Hidden', '-Command',
                            "try { Add-AppxPackage -Path '$tempInstaller' -ForceApplicationShutdown -ErrorAction Stop } catch { exit 1 }; exit 0")
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                } -TimeoutSeconds 120

                if ($result.ExitCode -eq 0) {
                    Write-StyledMessage -Type 'Success' -Text "Winget installato con successo tramite MSIXBundle."
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "Installazione Winget tramite MSIXBundle fallita (ExitCode: $($result.ExitCode))."
                }
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Errore download/install MSIXBundle: $($_.Exception.Message)"
            }
            finally {
                Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue *>$null
            }
        }

        # --- FASE 4: Reset dell'App Installer Appx ---
        try {
            Write-StyledMessage -Type 'Info' -Text "🔄 Reset 'Programma di installazione app'..."

            $result = Invoke-WithSpinner -Activity "Reset App Installer" -Process -Action {
                $procParams = @{
                    FilePath     = 'powershell'
                    ArgumentList = @('-NoProfile', '-WindowStyle', 'Hidden', '-Command',
                        "Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue | Reset-AppxPackage -ErrorAction SilentlyContinue")
                    PassThru     = $true
                    WindowStyle  = 'Hidden'
                }
                Start-Process @procParams
            } -TimeoutSeconds 60

            if ($result.ExitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "App 'Programma di installazione app' resettata con successo."
            }
            else {
                Write-StyledMessage -Type 'Info' -Text "Reset Appx completato (ExitCode: $($result.ExitCode))."
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile resettare App Installer: $($_.Exception.Message)"
        }

        # --- FASE 5: Verifica Finale ---
        Start-Sleep 2
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
        $isWingetAvailable = [bool](Get-Command winget -ErrorAction SilentlyContinue)

        if ($isWingetAvailable) {
            Write-StyledMessage -Type 'Success' -Text "Winget è stato processato e sembra funzionante."
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Impossibile installare o riparare Winget dopo tutti i tentativi."
        }

        return $isWingetAvailable
    }

    function Install-MicrosoftStore {
        Write-StyledMessage -Type 'Info' -Text "🔄 Reinstallazione Microsoft Store in corso..."

        # Restart servizi correlati allo Store
        @("AppXSvc", "ClipSVC", "WSService") | ForEach-Object {
            try { Restart-Service $_ -Force -ErrorAction SilentlyContinue *>$null } catch {}
        }

        # Pulizia cache Store
        $cachePaths = @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
        )
        foreach ($cachePath in $cachePaths) {
            if (Test-Path $cachePath) { Remove-Item $cachePath -Recurse -Force -ErrorAction SilentlyContinue *>$null }
        }

        # Metodi di installazione in ordine di preferenza
        $installMethods = @(
            @{
                Name   = "Winget Install"
                Action = {
                    $isWingetReady = [bool](Get-Command winget -ErrorAction SilentlyContinue)
                    if (-not $isWingetReady) { return @{ ExitCode = -1 } }

                    $procParams = @{
                        FilePath     = 'winget'
                        ArgumentList = @('install', '9WZDNCRFJBMP', '--accept-source-agreements',
                            '--accept-package-agreements', '--silent', '--disable-interactivity')
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                }
            },
            @{
                Name   = "AppX Manifest"
                Action = {
                    $store = Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue | Select-Object -First 1
                    if (-not $store) { return @{ ExitCode = -1 } }

                    $manifest = "$($store.InstallLocation)\AppXManifest.xml"
                    if (-not (Test-Path $manifest)) { return @{ ExitCode = -1 } }

                    $procParams = @{
                        FilePath     = 'powershell'
                        ArgumentList = @('-NoProfile', '-WindowStyle', 'Hidden', '-Command',
                            "Add-AppxPackage -DisableDevelopmentMode -Register '$manifest' -ForceApplicationShutdown")
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                }
            },
            @{
                Name   = "DISM Capability"
                Action = {
                    $procParams = @{
                        FilePath     = 'DISM'
                        ArgumentList = @('/Online', '/Add-Capability', '/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0')
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                }
            }
        )

        # Codici di uscita considerati successo
        $successCodes = @(0, 3010, 1638, -1978335189)

        $success = $false
        foreach ($method in $installMethods) {
            Write-StyledMessage -Type 'Info' -Text "Tentativo: Installazione Store ($($method.Name))..."
            try {
                $result = Invoke-WithSpinner -Activity "Store: $($method.Name)" -Process -Action $method.Action -TimeoutSeconds 300

                $isSuccess = $result.ExitCode -in $successCodes
                if ($isSuccess) {
                    Write-StyledMessage -Type 'Success' -Text "$($method.Name) completato con successo."

                    Write-StyledMessage -Type 'Info' -Text "Esecuzione wsreset.exe per pulire la cache dello Store..."
                    $procParams = @{
                        FilePath     = 'wsreset.exe'
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams *>$null

                    Write-StyledMessage -Type 'Success' -Text "Cache dello Store ripristinata."
                    $success = $true
                    break
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "$($method.Name) non riuscito (ExitCode: $($result.ExitCode)). Tentativo prossimo metodo."
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore durante $($method.Name): $($_.Exception.Message)"
            }
        }

        return $success
    }

    function Install-UniGetUI {
        Write-StyledMessage -Type 'Info' -Text "🔄 Reinstallazione UniGet UI in corso..."

        $isWingetReady = [bool](Get-Command winget -ErrorAction SilentlyContinue)
        if (-not $isWingetReady) {
            Write-StyledMessage -Type 'Warning' -Text "Winget non disponibile. Impossibile installare UniGet UI."
            return $false
        }

        $successCodes = @(0, 3010, 1638, -1978335189)

        try {
            # Rimozione versione esistente (ignora errori — potrebbe non essere installata)
            Write-StyledMessage -Type 'Info' -Text "🔄 Rimozione versione esistente UniGet UI..."
            $uninstallParams = @{
                FilePath     = 'winget'
                ArgumentList = @('uninstall', '--exact', '--id', 'MartiCliment.UniGetUI', '--silent', '--disable-interactivity')
                Wait         = $true
                WindowStyle  = 'Hidden'
            }
            Start-Process @uninstallParams *>$null
            Start-Sleep 2

            # Installazione nuova versione
            Write-StyledMessage -Type 'Info' -Text "🔄 Installazione UniGet UI..."
            $installResult = Invoke-WithSpinner -Activity "Installazione UniGet UI" -Process -Action {
                $procParams = @{
                    FilePath     = 'winget'
                    ArgumentList = @('install', '--exact', '--id', 'MartiCliment.UniGetUI', '--source', 'winget',
                        '--accept-source-agreements', '--accept-package-agreements', '--silent',
                        '--disable-interactivity', '--force')
                    PassThru     = $true
                    WindowStyle  = 'Hidden'
                }
                Start-Process @procParams
            } -TimeoutSeconds 300

            $isSuccess = $installResult.ExitCode -in $successCodes
            if ($isSuccess) {
                Write-StyledMessage -Type 'Success' -Text "UniGet UI installata con successo."

                # Disabilitazione avvio automatico
                Write-StyledMessage -Type 'Info' -Text "🔄 Disabilitazione avvio automatico UniGet UI..."
                try {
                    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                    $regKeyName = "WingetUI"
                    if (Get-ItemProperty -Path $regPath -Name $regKeyName -ErrorAction SilentlyContinue) {
                        Remove-ItemProperty -Path $regPath -Name $regKeyName -ErrorAction Stop *>$null
                        Write-StyledMessage -Type 'Success' -Text "Avvio automatico UniGet UI disabilitato."
                    }
                    else {
                        Write-StyledMessage -Type 'Info' -Text "Voce di avvio automatico UniGet UI non trovata — skip."
                    }
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Impossibile disabilitare avvio automatico UniGet UI: $($_.Exception.Message)"
                }
                return $true
            }
            else {
                Write-StyledMessage -Type 'Error' -Text "Installazione UniGet UI fallita (ExitCode: $($installResult.ExitCode))."
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore critico durante installazione UniGet UI: $($_.Exception.Message)"
            return $false
        }
    }

    # ============================================================================
    # 3. ESECUZIONE PRINCIPALE
    # ============================================================================

    Write-StyledMessage -Type 'Info' -Text "🚀 AVVIO REINSTALLAZIONE STORE"

    try {
        $wingetResult = Install-WingetCore
        Write-StyledMessage -Type $(if ($wingetResult) { 'Success' } else { 'Warning' }) -Text "Winget $(if ($wingetResult) { 'installato' } else { 'processato — verifica manuale consigliata' })."

        $storeResult = Install-MicrosoftStore
        if (-not $storeResult) {
            Write-StyledMessage -Type 'Error' -Text "Errore installazione Microsoft Store."
            Write-StyledMessage -Type 'Info' -Text "Verifica: connessione Internet, privilegi Admin, Windows Update."
            return
        }
        Write-StyledMessage -Type 'Success' -Text "Microsoft Store installato."

        $unigetResult = Install-UniGetUI
        Write-StyledMessage -Type $(if ($unigetResult) { 'Success' } else { 'Warning' }) -Text "UniGet UI $(if ($unigetResult) { 'installata' } else { 'processata — verifica manuale consigliata' })."

        Write-StyledMessage -Type 'Success' -Text "🎉 OPERAZIONE COMPLETATA"
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "❌ ERRORE: $($_.Exception.Message)"
        Write-StyledMessage -Type 'Info' -Text "💡 Esegui come Admin, verifica Internet e Windows Update."
    }
    finally {
        try { Stop-Transcript | Out-Null } catch {}
    }

    # ============================================================================
    # 4. GESTIONE RIAVVIO — SEMPRE ULTIMA
    # ============================================================================

    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
        Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
    }
    else {
        if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio necessario per applicare le modifiche") {
            Write-StyledMessage -Type 'Info' -Text "🔄 Riavvio in corso..."
            if (-not $NoReboot) {
                Restart-Computer -Force
            }
        }
    }
}
