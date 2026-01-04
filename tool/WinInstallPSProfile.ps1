function WinInstallPSProfile {
    <#
    .SYNOPSIS
        Script per installare il profilo PowerShell di ChrisTitusTech.

    .DESCRIPTION
        Installa e configura il profilo PowerShell personalizzato con oh-my-posh, zoxide e altre utilità.
        Richiede privilegi di amministratore e PowerShell 7+.
    #>

    Initialize-ToolLogging -ToolName "WinInstallPSProfile"
    Show-Header -SubTitle "Install Profilo PowerShell"

    function Add-ToSystemPath([string]$PathToAdd) {
        try {
            if (-not (Test-Path $PathToAdd)) {
                Write-StyledMessage Warning "Percorso non esistente: $PathToAdd"
                return $false
            }

            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            $pathExists = ($currentPath -split ';') | Where-Object { $_.TrimEnd('\') -ieq $PathToAdd.TrimEnd('\') }

            if ($pathExists) {
                Write-StyledMessage Info "Percorso già nel PATH: $PathToAdd"
                return $true
            }

            $PathToAdd = $PathToAdd.TrimStart(';')
            $newPath = if ($currentPath.EndsWith(';')) { "$currentPath$PathToAdd" } else { "$currentPath;$PathToAdd" }
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            $env:PATH = "$env:PATH;$PathToAdd"

            Write-StyledMessage Success "Percorso aggiunto al PATH: $PathToAdd"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore aggiunta PATH: $($_.Exception.Message)"
            return $false
        }
    }

    function Find-ProgramPath([string]$ProgramName, [string[]]$SearchPaths, [string]$ExecutableName) {
        foreach ($path in $SearchPaths) {
            $resolvedPaths = @()
            try {
                $resolvedPaths = Get-ChildItem -Path (Split-Path $path -Parent) -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like (Split-Path $path -Leaf) }
            }
            catch { continue }

            foreach ($resolved in $resolvedPaths) {
                $testPath = $resolved.FullName
                if (Test-Path "$testPath\$ExecutableName") { return $testPath }
            }

            $directPath = $path -replace '\*.*', ''
            if (Test-Path "$directPath\$ExecutableName") { return $directPath }
        }
        return $null
    }

    # Countdown preparazione
    Invoke-WithSpinner -Activity "Preparazione" -Timer -Action { Start-Sleep 5 } -TimeoutSeconds 5

    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-StyledMessage Warning "Richiesti privilegi amministratore"
        Write-StyledMessage Info "Riavvio come amministratore..."

        try {
            Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { WinInstallPSProfile }`""
            return
        }
        catch {
            Write-StyledMessage Error "Impossibile elevare privilegi: $($_.Exception.Message)"
            return
        }
    }

    try {
        Write-StyledMessage Info "Installazione profilo PowerShell..."
        Write-Host ''

        if (-not (Get-Command "pwsh" -ErrorAction SilentlyContinue)) {
            Write-StyledMessage Error "PowerShell Core non installato!"
            return
        }

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-StyledMessage Warning "Richiesto PowerShell 7+"
            $choice = Read-Host "Procedere comunque? (S/N)"
            if ($choice -notmatch '^[SsYy]') {
                Write-StyledMessage Info "Installazione annullata"
                return
            }
        }

        $profileUrl = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        $oldHash = if (Test-Path $PROFILE) { Get-FileHash $PROFILE -ErrorAction SilentlyContinue } else { $null }

        Write-StyledMessage Info "Controllo aggiornamenti..."
        $tempProfile = "$env:TEMP\Microsoft.PowerShell_profile.ps1"
        try {
            Invoke-RestMethod $profileUrl -OutFile $tempProfile -UseBasicParsing
            $newHash = Get-FileHash $tempProfile
        }
        catch [System.Net.WebException] {
            Write-StyledMessage Error "Errore rete durante download profilo: $($_.Exception.Message)"
            return
        }
        catch {
            Write-StyledMessage Error "Errore download profilo: $($_.Exception.Message)"
            return
        }

        $profileDir = Split-Path $PROFILE -Parent
        if (!(Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
        $newHash.Hash | Out-File "$PROFILE.hash" -Force

        Write-StyledMessage Info "Hash profilo locale: $($oldHash.Hash), remoto: $($newHash.Hash)"
        if ($newHash.Hash -ne $oldHash.Hash) {
            if ((Test-Path $PROFILE) -and (-not (Test-Path "$PROFILE.bak"))) {
                Write-StyledMessage Info "Backup profilo esistente..."
                Copy-Item -Path $PROFILE -Destination "$PROFILE.bak" -Force
                Write-StyledMessage Success "Backup completato"
            }

            Write-StyledMessage Info "Installazione dipendenze..."
            Write-Host ''

            # oh-my-posh
            try {
                Write-StyledMessage Info "Installazione oh-my-posh..."
                
                $installProcess = Start-Process -FilePath "cmd" -ArgumentList "/c winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements --silent >nul 2>&1" -NoNewWindow -PassThru
                
                # Usa la funzione globale Invoke-WithSpinner per monitorare l'installazione oh-my-posh
                Invoke-WithSpinner -Activity "Installazione oh-my-posh" -Process -Action { $installProcess } -UpdateInterval 300

                $installProcess.WaitForExit()
                if ($installProcess.ExitCode -ne 0) {
                    Write-StyledMessage Error "Installazione oh-my-posh fallita (ExitCode: $($installProcess.ExitCode))"
                }
                else {
                    Start-Sleep -Seconds 2
                    Show-ProgressBar "oh-my-posh" "Completato" 100 '📦'
                    Write-Host ''
                }

                $omp = Get-ChildItem -Path "$env:LOCALAPPDATA" -Filter "oh-my-posh.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($omp) {
                    $ompPath = [System.IO.Path]::GetFullPath($omp.DirectoryName)
                    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
                    $pathArray = ($currentPath -split ';') | Where-Object { $_ -and $_.Trim() } | ForEach-Object { [System.IO.Path]::GetFullPath($_) }
                    if ($pathArray -notcontains $ompPath) {
                        $newPath = if ($currentPath.EndsWith(';')) { "$currentPath$ompPath" } else { "$currentPath;$ompPath" }
                        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
                        Write-StyledMessage Success "Path oh-my-posh aggiunto: $ompPath"
                    }
                    else {
                        Write-StyledMessage Info "Path oh-my-posh già presente."
                    }
                }
                else {
                    Write-StyledMessage Error "oh-my-posh.exe non trovato! Prova a reinstallarlo: winget install JanDeDobbeleer.OhMyPosh"
                }
            }
            catch {
                Write-StyledMessage Warning "Errore oh-my-posh: $($_.Exception.Message)"
            }

            # zoxide
            try {
                Write-StyledMessage Info "Installazione zoxide..."
                
                $installProcess = Start-Process -FilePath "cmd" -ArgumentList "/c winget install ajeetdsouza.zoxide -s winget --accept-package-agreements --accept-source-agreements --silent >nul 2>&1" -NoNewWindow -PassThru
                
                # Usa la funzione globale Invoke-WithSpinner per monitorare l'installazione zoxide
                Invoke-WithSpinner -Activity "Installazione zoxide" -Process -Action { $installProcess } -UpdateInterval 300

                $installProcess.WaitForExit()
                if ($installProcess.ExitCode -ne 0) {
                    Write-StyledMessage Error "Installazione zoxide fallita (ExitCode: $($installProcess.ExitCode))"
                }
                else {
                    Start-Sleep -Seconds 2
                    Show-ProgressBar "zoxide" "Completato" 100 '⚡'
                    Write-Host ''
                }

                $zox = Get-ChildItem -Path "$env:LOCALAPPDATA" -Filter "zoxide.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($zox) {
                    $zoxPath = [System.IO.Path]::GetFullPath($zox.DirectoryName)
                    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
                    $pathArray = ($currentPath -split ';') | Where-Object { $_ -and $_.Trim() } | ForEach-Object { [System.IO.Path]::GetFullPath($_) }
                    if ($pathArray -notcontains $zoxPath) {
                        $newPath = if ($currentPath.EndsWith(';')) { "$currentPath$zoxPath" } else { "$currentPath;$zoxPath" }
                        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
                        Write-StyledMessage Success "Path zoxide aggiunto: $zoxPath"
                    }
                    else {
                        Write-StyledMessage Info "Path zoxide già presente."
                    }
                }
                else {
                    Write-StyledMessage Error "zoxide.exe non trovato! Prova a reinstallarlo: winget install ajeetdsouza.zoxide"
                }
            }
            catch {
                Write-StyledMessage Warning "Errore zoxide: $($_.Exception.Message)"
            }

            # Refresh PATH
            Write-StyledMessage Info "Aggiornamento variabili d'ambiente..."
            Invoke-WithSpinner -Activity "Aggiornamento PATH" -Timer -Action { 
                $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
                $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
                $env:PATH = "$machinePath;$userPath"
                Start-Sleep 2
            } -TimeoutSeconds 2

            # Setup profilo
            Write-StyledMessage Info "Configurazione profilo PowerShell..."
            Invoke-WithSpinner -Activity "Setup profilo PowerShell" -Timer -Action { 
                Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1' -UseBasicParsing).Content
                Start-Sleep 3
            } -TimeoutSeconds 3
            # Download e configurazione settings.json per Windows Terminal
            $wtSettingsUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/settings.json"
            $wtPath = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Directory -Filter "Microsoft.WindowsTerminal_*" -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $wtPath) {
                Write-StyledMessage Warning "Directory Windows Terminal non trovata, impossibile configurare settings.json."
                return
            }
            $wtLocalStateDir = Join-Path $wtPath.FullName "LocalState"
            if (-not (Test-Path $wtLocalStateDir)) {
                New-Item -ItemType Directory -Path $wtLocalStateDir -Force | Out-Null
            }
            $settingsPath = Join-Path $wtLocalStateDir "settings.json"

            Write-StyledMessage Info "Download e configurazione settings.json per Windows Terminal..."
            $spinnerIndex = 0; $percent = 0
            try {
                # Download settings.json per Windows Terminal
                Invoke-WithSpinner -Activity "Download settings.json Windows Terminal" -Timer -Action { 
                    Invoke-WebRequest $wtSettingsUrl -OutFile $settingsPath -UseBasicParsing
                    Start-Sleep 2
                } -TimeoutSeconds 2
            }
            catch [System.Net.WebException] {
                Write-StyledMessage Error "Errore di rete durante il download di settings.json: $($_.Exception.Message)"
            }
            catch {
                Write-StyledMessage Error "Errore durante il download/copia di settings.json: $($_.Exception.Message)"
            }
        }
        catch {
            Write-StyledMessage Warning "Fallback: copia manuale profilo"
            Copy-Item -Path $tempProfile -Destination $PROFILE -Force
            Write-StyledMessage Success "Profilo copiato"
        }

        Write-Host ""
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-StyledMessage Warning "Riavvio OBBLIGATORIO per:"
        Write-Host "  • PATH oh-my-posh e zoxide" -ForegroundColor Cyan
        Write-Host "  • Font installati" -ForegroundColor Cyan
        Write-Host "  • Attivazione profilo" -ForegroundColor Cyan
        Write-Host "  • Variabili d'ambiente" -ForegroundColor Cyan
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-Host ""

        $shouldReboot = Start-InterruptibleCountdown 30 "Riavvio sistema"

        if ($shouldReboot) {
            Write-StyledMessage Info "Riavvio..."
            Restart-Computer -Force
        }
        else {
            Write-Host ""
            Write-Host ('═' * 80) -ForegroundColor Yellow
            Write-StyledMessage Warning "RIAVVIO POSTICIPATO"
            Write-Host ('═' * 80) -ForegroundColor Yellow
            Write-Host ""
            Write-StyledMessage Error "Il profilo NON funzionerà finché non riavvii!"
            Write-Host ""
            Write-StyledMessage Info "Dopo il riavvio, verifica con:"
            Write-Host "  oh-my-posh --version" -ForegroundColor Cyan
            Write-Host "  zoxide --version" -ForegroundColor Cyan
            Write-Host ""
            # Salva stato riavvio necessario
            $rebootFlag = "$env:LOCALAPPDATA\WinToolkit\reboot_required.txt"
            "Riavvio necessario per applicare PATH oh-my-posh/zoxide e profilo PowerShell. Eseguito il $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $rebootFlag -Encoding UTF8
            Write-StyledMessage Info "Flag riavvio salvato in: $rebootFlag"
        }
    }
    catch {
        Write-StyledMessage Error "Errore durante l'installazione del profilo: $($_.Exception.Message)"
    }
    finally {
        # Pulizia file temporanei
        if (Test-Path $tempProfile) {
            Remove-Item $tempProfile -Force -ErrorAction SilentlyContinue
        }
    }
}
