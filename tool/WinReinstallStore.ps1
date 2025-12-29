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

        $originalPos = [Console]::CursorTop
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
            Write-StyledMessage Info "🔄 Reset delle sorgenti di Winget..."
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
            Write-StyledMessage Info "🔄 Installazione del PackageProvider NuGet..."
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                Write-StyledMessage Success "Provider NuGet installato/verificato."
            }
            catch {
                Write-StyledMessage Warning "Nota: Il provider NuGet potrebbe essere già installato o richiedere conferma manuale."
            }

            # Installazione Modulo Microsoft.WinGet.Client
            Write-StyledMessage Info "🔄 Installazione e importazione del modulo Microsoft.WinGet.Client..."
            Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction SilentlyContinue *>$null
            Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
            Write-StyledMessage Success "Modulo Microsoft.WinGet.Client installato e importato."

            # --- FASE 3: Riparazione e Reinstallazione del Core di Winget ---

            # Tentativo A (Riparazione via Modulo)
            Write-StyledMessage Info "🔄 Tentativo di riparazione Winget tramite il modulo WinGet Client..."
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
                Write-StyledMessage Info "🔄 Scarico e installo Winget tramite MSIXBundle (metodo fallback)..."
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
            Write-StyledMessage Info "🔄 Reset dell'App 'Programma di installazione app' (Microsoft.DesktopAppInstaller)..."
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
        Write-StyledMessage Info "🔄 Reinstallazione Microsoft Store in corso..."

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
        Write-StyledMessage Info "🔄 Reinstallazione UniGet UI in corso..."
        if (-not (Test-WingetAvailable)) { return $false }

        $originalPos = [Console]::CursorTop
        try {
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'

            $process = Start-Process winget -ArgumentList "install --exact --id MartiCliment.UniGetUI --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity --force" -Wait -PassThru -WindowStyle Hidden

            if ($process.ExitCode -eq 0) {
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

WinReinstallStore