function WinReinstallStore {
    <#
    .SYNOPSIS
        Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget.

    .DESCRIPTION
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI senza output bloccanti.

    #>
    param([int]$CountdownSeconds = 30, [switch]$NoReboot)

    Initialize-ToolLogging -ToolName "WinReinstallStore"
    Show-Header -SubTitle "Store Repair Toolkit"


    function Clear-ProgressLine {
        Write-Host "`r" -NoNewline
        Write-Host " " * 100 -NoNewline
        Write-Host "`r" -NoNewline
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
        Write-StyledMessage Info "🚀 Avvio della procedura di reinstallazione e riparazione Winget..."
        Stop-InterferingProcesses

        try {
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'

            # --- FASE 1: Inizializzazione e Pulizia Profonda ---

            # Terminazione Processi
            Write-StyledMessage Info "🔄 Chiusura forzata dei processi Winget e correlati..."
            @("winget", "WindowsPackageManagerServer") | ForEach-Object {
                Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                taskkill /im "$_.exe" /f 2>$null
            }
            Start-Sleep 2

            # Pulizia Cartella Temporanea
            Write-StyledMessage Info "🔄 Pulizia dei file temporanei (%TEMP%\WinGet)..."
            $tempWingetPath = "$env:TEMP\WinGet"
            if (Test-Path $tempWingetPath) {
                Remove-Item -Path $tempWingetPath -Recurse -Force -ErrorAction SilentlyContinue *>$null
                Write-StyledMessage Info "Cartella temporanea di Winget eliminata."
            }
            else {
                Write-StyledMessage Info "Cartella temporanea di Winget non trovata o già pulita."
            }

            # Reset Sorgenti Winget
            $resetActivity = "Reset delle sorgenti Winget"
            Write-StyledMessage Info "🔄 $resetActivity..."
            try {
                $wingetExePath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
                if (Test-Path $wingetExePath) {
                    & $wingetExePath source reset --force *>$null
                }
                else {
                    winget source reset --force *>$null
                }
                Write-StyledMessage Success "Sorgenti Winget resettate."
            }
            catch {
                Write-StyledMessage Warning "Reset delle sorgenti Winget non riuscito o parzialmente completato: $($_.Exception.Message)"
            }

            # --- FASE 2: Installazione Dipendenze e Moduli PowerShell ---

            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            # Installazione Provider NuGet
            $nugetActivity = "Installazione PackageProvider NuGet"
            Write-StyledMessage Info "🔄 $nugetActivity..."
            try {
                # Ensure PowerShellGet module is installed and up-to-date
                if (-not (Get-Module -Name PowerShellGet -ListAvailable)) {
                    Install-Module -Name PowerShellGet -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
                }
                else {
                    Update-Module -Name PowerShellGet -Force -ErrorAction SilentlyContinue *>$null
                }
                 
                # Verify NuGet provider is installed
                $nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
                if (-not $nugetProvider) {
                    try {
                        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                        Write-StyledMessage Success "Provider NuGet installato."
                    }
                    catch {
                        Write-StyledMessage Warning "Nota: Il provider NuGet potrebbe richiedere conferma manuale. Errore: $($_.Exception.Message)"
                    }
                }
                else {
                    Write-StyledMessage Success "Provider NuGet già installato."
                }
            }
            catch {
                Write-StyledMessage Warning "Errore durante l'installazione del provider NuGet: $($_.Exception.Message)"
            }

            # Installazione Modulo Microsoft.WinGet.Client
            $moduleActivity = "Installazione modulo Microsoft.WinGet.Client"
            Write-StyledMessage Info "🔄 $moduleActivity..."
            try {
                Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
                Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
                Write-StyledMessage Success "Modulo Microsoft.WinGet.Client installato e importato."
            }
            catch {
                Write-StyledMessage Error "Errore durante l'installazione o l'importazione del modulo Microsoft.WinGet.Client: $($_.Exception.Message)"
            }

            # --- FASE 3: Riparazione e Reinstallazione del Core di Winget ---

            # Tentativo A (Riparazione via Modulo)
            if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                $repairModuleActivity = "Riparazione Winget tramite modulo WinGet Client"
                Write-StyledMessage Info "🔄 $repairModuleActivity..."
                try {
                    # Salva posizione cursore per pulizia output
                    $cursorTop = [Console]::CursorTop
                    $null = Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                    
                    # Pulisci eventuali righe di output rimaste
                    [Console]::SetCursorPosition(0, $cursorTop)
                    $clearLine = " " * ([Console]::WindowWidth - 1)
                    Write-Host "`r$clearLine`r" -NoNewline
                    
                    Start-Sleep 5
                    if (Test-WingetAvailable) {
                        Write-StyledMessage Success "Winget riparato con successo tramite modulo."
                    }
                    else {
                        Write-StyledMessage Warning "Riparazione Winget tramite modulo non riuscita."
                    }
                }
                catch {
                    Write-StyledMessage Warning "Errore durante la riparazione Winget: $($_.Exception.Message)"
                }
            }

            # Tentativo B (Reinstallazione tramite MSIXBundle - Fallback)
            if (-not (Test-WingetAvailable)) {
                $installMsiActivity = "Installazione Winget tramite MSIXBundle"
                Write-StyledMessage Info "🔄 $installMsiActivity..."
                $url = $AppConfig.URLs.WingetInstaller
                $temp = "$env:TEMP\WingetInstaller.msixbundle"
                if (Test-Path $temp) { Remove-Item $temp -Force *>$null }
                Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing *>$null
                
                # Cattura posizione cursore per pulizia output
                $originalPos = [Console]::CursorTop
                
                $process = Start-Process powershell -ArgumentList @(
                    "-NoProfile", "-WindowStyle", "Hidden", "-Command",
                    "try { Add-AppxPackage -Path '$temp' -ForceApplicationShutdown -ErrorAction Stop } catch { exit 1 }; exit 0"
                ) -Wait -PassThru -WindowStyle Hidden
                
                # Reset cursore e flush output
                [Console]::SetCursorPosition(0, $originalPos)
                $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                Write-Host $clearLine -NoNewline
                [Console]::Out.Flush()

                Remove-Item $temp -Force -ErrorAction SilentlyContinue *>$null
                Start-Sleep 5
                
                if ($process.ExitCode -eq 0) {
                    Write-StyledMessage Success "Winget installato con successo tramite MSIXBundle."
                }
                else {
                    Write-StyledMessage Warning "Installazione Winget tramite MSIXBundle fallita o non riuscita (ExitCode: $($process.ExitCode))."
                }
            }

            # --- FASE 4: Reset dell'App Installer Appx ---
            try {
                $resetAppxActivity = "Reset 'Programma di installazione app'"
                Write-StyledMessage Info "🔄 $resetAppxActivity..."
                
                # Salva posizione cursore e sopprimi completamente l'output
                $originalPos = [Console]::CursorTop
                Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage -ErrorAction SilentlyContinue | Out-Null
                Start-Sleep -Milliseconds 500  # Dare tempo al progress bar di completare
                
                # Reset cursore e flush output
                [Console]::SetCursorPosition(0, $originalPos)
                $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                Write-Host $clearLine -NoNewline
                [Console]::Out.Flush()
                
                Write-StyledMessage Success "App 'Programma di installazione app' resettata con successo."
            }
            catch {
                Write-StyledMessage Warning "Impossibile resettare l'App 'Programma di installazione app'. Errore: $($_.Exception.Message)"
            }

            # --- FASE 5: Gestione Output Finale e Valore di Ritorno ---
            Start-Sleep 2
            $finalCheck = Test-WingetAvailable

            if ($finalCheck) {
                Write-StyledMessage Success "Winget è stato processato e sembra funzionante."
                return $true
            }
            else {
                Write-StyledMessage Error "Impossibile installare o riparare Winget dopo tutti i tentativi."
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
        Write-StyledMessage Info "🔄 Reinstallazione Microsoft Store in corso..."

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
                @{ Name = "Winget Install"; Script = {
                        if (Test-WingetAvailable) {
                            $procParams = @{
                                FilePath               = 'winget'
                                ArgumentList           = 'install', '9WZDNCRFJBMP', '--accept-source-agreements', '--accept-package-agreements', '--silent', '--disable-interactivity', '--disable-progress'
                                PassThru               = $true
                                WindowStyle            = 'Hidden'
                                RedirectStandardOutput = 'NUL'
                                RedirectStandardError  = 'NUL'
                            }
                            $process = Start-Process @procParams
                            return $process.ExitCode -eq 0
                        }
                        return $false
                    }
                },
                @{ Name = "AppX Manifest"; Script = {
                        $store = Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue
                        if ($store) {
                            $store | ForEach-Object {
                                $manifest = "$($_.InstallLocation)\AppXManifest.xml"
                                if (Test-Path $manifest) {
                                    $procParams = @{
                                        FilePath               = 'powershell'
                                        ArgumentList           = @('-NoProfile', '-WindowStyle', 'Hidden', '-Command', "Add-AppxPackage -DisableDevelopmentMode -Register '$manifest' -ForceApplicationShutdown *>$null")
                                        PassThru               = $true
                                        WindowStyle            = 'Hidden'
                                        RedirectStandardOutput = 'NUL'
                                        RedirectStandardError  = 'NUL'
                                    }
                                    $process = Start-Process @procParams
                                }
                            }
                            return $true
                        }
                        return $false
                    }
                },
                @{ Name = "DISM Capability"; Script = {
                        $procParams = @{
                            FilePath               = 'DISM'
                            ArgumentList           = '/Online', '/Add-Capability', '/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0'
                            PassThru               = $true
                            WindowStyle            = 'Hidden'
                            RedirectStandardOutput = 'NUL'
                            RedirectStandardError  = 'NUL'
                        }
                        $process = Start-Process @procParams
                        return $process.ExitCode -eq 0
                    }
                }
            )

            $success = $false
            foreach ($method in $methods) {
                $activityName = "Installazione Store ($($method.Name))"
                Write-StyledMessage Info "Tentativo: $activityName..."

                $processResult = $null
                try {
                    if ($method.Name -eq "Winget Install") {
                        if (Test-WingetAvailable) {
                            # Cattura posizione cursore per pulizia output
                            $originalPos = [Console]::CursorTop
                            
                            $process = Start-Process winget -ArgumentList "install 9WZDNCRFJBMP --accept-source-agreements --accept-package-agreements --silent --disable-interactivity" -Wait -PassThru -WindowStyle Hidden
                            
                            # Reset cursore e flush output
                            [Console]::SetCursorPosition(0, $originalPos)
                            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                            Write-Host $clearLine -NoNewline
                            [Console]::Out.Flush()
                            
                            $processResult = @{ Success = $true; ExitCode = $process.ExitCode }
                        }
                        else {
                            # Winget non disponibile, segna come fallito
                            $processResult = @{ Success = $false; ExitCode = -1 }
                        }
                    }
                    elseif ($method.Name -eq "AppX Manifest") {
                        # Cattura posizione cursore per pulizia output
                        $originalPos = [Console]::CursorTop
                        
                        $store = Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($store) {
                            $manifest = "$($store.InstallLocation)\AppXManifest.xml"
                            if (Test-Path $manifest) {
                                $process = Start-Process powershell -ArgumentList @(
                                    "-NoProfile", "-WindowStyle", "Hidden", "-Command",
                                    "Add-AppxPackage -DisableDevelopmentMode -Register '$manifest' -ForceApplicationShutdown"
                                ) -Wait -PassThru -WindowStyle Hidden
                                
                                # Reset cursore e flush output
                                [Console]::SetCursorPosition(0, $originalPos)
                                $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                                Write-Host $clearLine -NoNewline
                                [Console]::Out.Flush()
                                
                                $processResult = @{ Success = $true; ExitCode = $process.ExitCode }
                            }
                            else { $processResult = @{ Success = $false; ExitCode = -1 } }
                        }
                        else { $processResult = @{ Success = $false; ExitCode = -1 } }
                    }
                    elseif ($method.Name -eq "DISM Capability") {
                        # Cattura posizione cursore per pulizia output
                        $originalPos = [Console]::CursorTop
                        
                        $process = Start-Process DISM -ArgumentList "/Online /Add-Capability /CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0" -Wait -PassThru -WindowStyle Hidden
                        
                        # Reset cursore e flush output
                        [Console]::SetCursorPosition(0, $originalPos)
                        $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                        Write-Host $clearLine -NoNewline
                        [Console]::Out.Flush()
                        
                        $processResult = @{ Success = $true; ExitCode = $process.ExitCode }
                    }
                }
                catch {
                    Write-StyledMessage Warning "Errore durante l'esecuzione del metodo $($method.Name): $($_.Exception.Message)"
                    $processResult = @{ Success = $false; ExitCode = -1 }
                }

                # Verifica il risultato di Invoke-WithSpinner
                # Codici di successo comuni: 0 (successo), 3010 (successo, riavvio richiesto), 1638 (già installato), -1978335189 (winget "Noop")
                # Per i comandi powershell, solo 0 è un successo tipico.
                $isSuccess = $processResult.Success -and ($processResult.ExitCode -eq 0 -or $processResult.ExitCode -eq 3010 -or $processResult.ExitCode -eq 1638 -or $processResult.ExitCode -eq -1978335189)

                if ($isSuccess) {
                    Write-StyledMessage Success "$($method.Name) completato con successo."
                    # Esegui wsreset.exe solo una volta, dopo il successo del primo metodo
                    Write-StyledMessage Info "Esecuzione di wsreset.exe per pulire la cache dello Store..."
                    Start-Process wsreset.exe -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue *>$null
                    Write-StyledMessage Success "Cache dello Store ripristinata."
                    $success = $true
                    break # Esci dal loop se un metodo ha successo
                }
                else {
                    Write-StyledMessage Warning "$($method.Name) non riuscito (ExitCode: $($processResult.ExitCode ?? 'N/A')). Tentativo prossimo metodo."
                }
            }
            return $success
        }
        finally {
            # Reset delle preferenze
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
            $VerbosePreference = 'SilentlyContinue'
        }
    }

    function Install-UniGetUISilent {
        Write-StyledMessage Info "🔄 Reinstallazione UniGet UI in corso..."
        if (-not (Test-WingetAvailable)) { return $false }

        try {
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'

            $unigetActivity = "Installazione UniGet UI"
            Write-StyledMessage Info "🔄 $unigetActivity..."
            
            # Cattura posizione cursore per pulizia output
            $originalPos = [Console]::CursorTop
            
            $null = Start-Process winget -ArgumentList "uninstall --exact --id MartiCliment.UniGetUI --silent --disable-interactivity" -Wait -PassThru -WindowStyle Hidden
            Start-Sleep 2
            $process = Start-Process winget -ArgumentList "install --exact --id MartiCliment.UniGetUI --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity --force" -Wait -PassThru -WindowStyle Hidden
            
            # Reset cursore e flush output
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()

            # Verifica il risultato
            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010 -or $process.ExitCode -eq 1638 -or $process.ExitCode -eq -1978335189) {
                Write-StyledMessage Success "$unigetActivity completata."
                Write-StyledMessage Info "🔄 Disabilitazione avvio automatico UniGet UI..."
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
                return $true
            }
            else {
                Write-StyledMessage Error "$unigetActivity fallita o non riuscita (ExitCode: $($process.ExitCode))."
                return $false
            }
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

        Write-StyledMessage Success "🎉 OPERAZIONE COMPLETATA"

        if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio necessario per applicare le modifiche") {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
            if (-not $NoReboot) {
                Restart-Computer -Force
            }
        }
    }
    catch {
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
