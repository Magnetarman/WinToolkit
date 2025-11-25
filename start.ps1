<#
.SYNOPSIS
    Script di Start per Win Toolkit.
.DESCRIPTION
    Questo script funge da punto di ingresso per l'installazione e la configurazione di Win Toolkit V2.0.
    Verifica la presenza di Git e PowerShell 7, installandoli se necessario, e configura Windows Terminal.
    Crea inoltre una scorciatoia sul desktop per avviare Win Toolkit con privilegi amministrativi.
.NOTES
  Versione 2.4.2 (Build 3) - 2025-11-25
#>

function Center-text {
    param([string]$text, [int]$width = 80)
    $padding = [math]::Max(0, [math]::Floor(($width - $text.Length) / 2))
    return (" " * $padding) + $text
}

$Host.UI.RawUI.WindowTitle = "Toolkit Starter by MagnetarMan"

function Write-StyledMessage {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$type,
        [Parameter(Mandatory = $true)]
        [string]$text
    )

    $colors = @{
        'Info'    = 'Cyan'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
        'Success' = 'Green'
    }
    Write-Host $text -ForegroundColor $colors[$type]
}

function Test-WingetAvailable {
    try {
        $null = winget --version 2>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Invoke-WingetWithTimeout {
    param(
        [string]$Arguments,
        [int]$TimeoutSeconds = 60
    )
    
    try {
        $job = Start-Job -ScriptBlock {
            param($args)
            $output = winget $args 2>&1
            return @{
                Output   = $output
                ExitCode = $LASTEXITCODE
            }
        } -ArgumentList $Arguments.Split(' ')
        
        $completed = Wait-Job $job -Timeout $TimeoutSeconds
        
        if ($completed) {
            $result = Receive-Job $job
            Remove-Job $job -Force
            return $result
        }
        else {
            Remove-Job $job -Force
            Write-StyledMessage -type 'Warning' -text "Comando winget timeout dopo $TimeoutSeconds secondi"
            return $null
        }
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore esecuzione winget: $($_.Exception.Message)"
        return $null
    }
}

function Install-WingetSilent {
    Write-StyledMessage -type 'Info' -text "Verifica disponibilità Winget..."

    if (Test-WingetAvailable) {
        Write-StyledMessage -type 'Success' -text "Winget è già disponibile e funzionante."
        return $true
    }

    Write-StyledMessage -type 'Warning' -text "Winget non trovato. Tentativo di installazione..."

    $osInfo = [System.Environment]::OSVersion
    $buildNumber = $osInfo.Version.Build

    if ($osInfo.Version.Major -eq 10 -and $buildNumber -lt 16299) {
        Write-StyledMessage -type 'Error' -text "Windows 10 build $buildNumber non supporta Winget."
        return $false
    }

    if ($osInfo.Version.Major -lt 10) {
        Write-StyledMessage -type 'Error' -text "Winget non è supportato su Windows $($osInfo.Version.Major)."
        return $false
    }

    try {
        $ErrorActionPreference = 'SilentlyContinue'
        $ProgressPreference = 'SilentlyContinue'

        # Tentativo riparazione per Windows 11 24H2+
        if ($buildNumber -ge 26100) {
            Write-StyledMessage -type 'Info' -text "Rilevato Windows 11 24H2+. Tentativo riparazione..."
            try {
                if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                    $null = Repair-WinGetPackageManager -Force -Latest 2>$null
                    Start-Sleep 5
                    if (Test-WingetAvailable) {
                        Write-StyledMessage -type 'Success' -text "Winget riparato con successo."
                        return $true
                    }
                }
            }
            catch {}
        }

        # --- Existing online installation logic (fallback if not in offline mode or local file missing) ---
        Write-StyledMessage -type 'Info' -text "Download e installazione Winget..."
        $url = "https://aka.ms/getwinget"
        $temp = "$env:TEMP\WingetInstaller.msixbundle"

        if (Test-Path $temp) { Remove-Item $temp -Force }

        Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing -TimeoutSec 30

        $installScript = "Add-AppxPackage -Path '$temp' -ForceApplicationShutdown -ErrorAction Stop"
        $process = Start-Process powershell -ArgumentList "-NoProfile", "-WindowStyle", "Hidden", "-Command", $installScript -Wait -PassThru -WindowStyle Hidden

        Remove-Item $temp -Force -ErrorAction SilentlyContinue

        Start-Sleep 3
        if (Test-WingetAvailable) {
            Write-StyledMessage -type 'Success' -text "Winget installato con successo."
            return $true
        }
        else {
            Write-StyledMessage -type 'Error' -text "Installazione completata ma Winget non disponibile."
            return $false
        }
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore installazione Winget: $($_.Exception.Message)"
        return $false
    }
    finally {
        $ErrorActionPreference = 'Continue'
        $ProgressPreference = 'Continue'
    }
}

function Install-Git {
    Write-StyledMessage -type 'Info' -text "Verifica installazione Git..."

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    if (Get-Command "git" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -type 'Success' -text "Git è già installato."
        return $true
    }

    Write-StyledMessage -type 'Info' -text "Git non trovato. Avvio installazione..."

    # Tentativo con winget (existing logic - will only run if not in offline mode or if offline mode fails)
    if (Test-WingetAvailable) {
        Write-StyledMessage -type 'Info' -text "Installazione Git tramite winget..."

        $result = Invoke-WingetWithTimeout -Arguments "install Git.Git --accept-source-agreements --accept-package-agreements --silent" -TimeoutSeconds 120

        if ($result -and $result.ExitCode -eq 0) {
            Start-Sleep 5
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            if (Get-Command "git" -ErrorAction SilentlyContinue) {
                Write-StyledMessage -type 'Success' -text "Git installato con successo tramite winget."
                return $true
            }
        }
        Write-StyledMessage -type 'Warning' -text "Installazione winget non riuscita. Tentativo download diretto..."
    }

    # Installazione diretta (existing logic - will only run if not in offline mode and winget fails)
    try {
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.1/Git-2.51.0-64-bit.exe"
        $gitInstaller = "$env:TEMP\Git-2.51.0-64-bit.exe"

        Write-StyledMessage -type 'Info' -text "Download Git da GitHub..."

        if (Test-Path $gitInstaller) { Remove-Item $gitInstaller -Force }

        $maxRetries = 3
        for ($i = 1; $i -le $maxRetries; $i++) {
            try {
                Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing -TimeoutSec 60
                break
            }
            catch {
                if ($i -eq $maxRetries) {
                    Write-StyledMessage -type 'Error' -text "Download fallito dopo $maxRetries tentativi."
                    return $false
                }
                Start-Sleep 2
            }
        }

        Write-StyledMessage -type 'Info' -text "Installazione Git..."
        $process = Start-Process $gitInstaller -ArgumentList "/SILENT /NORESTART /CLOSEAPPLICATIONS" -Wait -PassThru

        Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue

        if ($process.ExitCode -eq 0) {
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            Write-StyledMessage -type 'Success' -text "Git installato con successo."
            return $true
        }
        else {
            Write-StyledMessage -type 'Error' -text "Installazione Git fallita. Codice: $($process.ExitCode)"
            return $false
        }
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore installazione Git: $($_.Exception.Message)"
        return $false
    }
}

function Install-PowerShell7 {
    Write-StyledMessage -type 'Info' -text "Verifica PowerShell 7..."
    
    if (Test-Path "$env:ProgramFiles\PowerShell\7") {
        Write-StyledMessage -type 'Success' -text "PowerShell 7 è già installato."
        return $true
    }

    # Tentativo con winget (existing logic - will only run if not in offline mode or if offline mode fails)
    if (Test-WingetAvailable) {
        Write-StyledMessage -type 'Info' -text "Installazione PowerShell 7 tramite winget..."

        $result = Invoke-WingetWithTimeout -Arguments "install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent" -TimeoutSeconds 180

        if ($result -and $result.ExitCode -eq 0) {
            Start-Sleep 5
            if (Test-Path "$env:ProgramFiles\PowerShell\7") {
                Write-StyledMessage -type 'Success' -text "PowerShell 7 installato tramite winget."
                return $true
            }
        }
        Write-StyledMessage -type 'Warning' -text "Installazione winget non completata. Tentativo download diretto..."
    }

    # Installazione diretta con timeout (existing logic - will only run if not in offline mode and winget fails)
    try {
        $ps7Url = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.4/PowerShell-7.5.4-win-x64.msi"
        $ps7Installer = "$env:TEMP\PowerShell-7.5.4-win-x64.msi"

        Write-StyledMessage -type 'Info' -text "Download PowerShell 7..."
        Invoke-WebRequest -Uri $ps7Url -OutFile $ps7Installer -UseBasicParsing -TimeoutSec 60

        Write-StyledMessage -type 'Info' -text "Installazione PowerShell 7 in corso (attendere fino a 3 minuti)..."

        # Esecuzione MSI con timeout usando Job
        $job = Start-Job -ScriptBlock {
            param($installer)
            $installArgs = "/i `"$installer`" /quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1"
            $process = Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -WindowStyle Hidden
            return $process.ExitCode
        } -ArgumentList $ps7Installer

        $completed = Wait-Job $job -Timeout 180

        if ($completed) {
            $exitCode = Receive-Job $job
            Remove-Job $job -Force
            Remove-Item $ps7Installer -Force -ErrorAction SilentlyContinue

            # Verifica installazione
            Start-Sleep 3
            if (Test-Path "$env:ProgramFiles\PowerShell\7") {
                Write-StyledMessage -type 'Success' -text "PowerShell 7 installato con successo."
                return $true
            }
            elseif ($exitCode -eq 0) {
                Write-StyledMessage -type 'Success' -text "Installazione completata. PowerShell 7 sarà disponibile dopo il riavvio."
                return $true
            }
            else {
                Write-StyledMessage -type 'Error' -text "Installazione fallita. Codice: $exitCode"
                return $false
            }
        }
        else {
            Remove-Job $job -Force
            Remove-Item $ps7Installer -Force -ErrorAction SilentlyContinue

            # Verifica se l'installazione è comunque riuscita
            Start-Sleep 3
            if (Test-Path "$env:ProgramFiles\PowerShell\7") {
                Write-StyledMessage -type 'Success' -text "PowerShell 7 installato (timeout superato ma installazione completata)."
                return $true
            }

            Write-StyledMessage -type 'Error' -text "Timeout installazione (180s). Possibile interferenza o sistema lento."
            Write-StyledMessage -type 'Warning' -text "Provare a eseguire manualmente: msiexec /i PowerShell-7.5.2-win-x64.msi"
            return $false
        }
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore installazione PowerShell 7: $($_.Exception.Message)"
        return $false
    }
}

function Install-WindowsTerminal {
    Write-StyledMessage -type 'Info' -text "Configurazione Windows Terminal..."
    
    if (Get-Command "wt" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -type 'Success' -text "Windows Terminal già presente."
    }
    else {
        # Tentativo 1: winget con timeout (existing logic)
        if (-not (Get-Command "wt" -ErrorAction SilentlyContinue)) {
            # Only try if not installed yet
            if (Test-WingetAvailable) {
                Write-StyledMessage -type 'Info' -text "Installazione tramite winget..."

                $result = Invoke-WingetWithTimeout -Arguments "install --id 9N0DX20HK701 --source msstore --accept-source-agreements --accept-package-agreements --silent" -TimeoutSeconds 120

                Start-Sleep 5
                if (Get-Command "wt" -ErrorAction SilentlyContinue) {
                    Write-StyledMessage -type 'Success' -text "Windows Terminal installato tramite winget."
                }
            }
        }

        # Tentativo 2: Microsoft Store (existing logic)
        if (-not (Get-Command "wt" -ErrorAction SilentlyContinue)) {
            try {
                Write-StyledMessage -type 'Info' -text "Apertura Microsoft Store..."
                Start-Process "ms-windows-store://pdp/?ProductId=9N0DX20HK701"
                Write-StyledMessage -type 'Warning' -text "Completare l'installazione manualmente da Microsoft Store."
                Start-Sleep 10
            }
            catch {
                Write-StyledMessage -type 'Warning' -text "Impossibile aprire Microsoft Store."
            }
        }

        # Tentativo 3: GitHub Release (existing logic)
        if (-not (Get-Command "wt" -ErrorAction SilentlyContinue)) {
            try {
                Write-StyledMessage -type 'Info' -text "Download da GitHub..."
                $releaseUrl = "https://api.github.com/repos/microsoft/terminal/releases/latest"
                $release = Invoke-RestMethod -Uri $releaseUrl -UseBasicParsing
                $asset = $release.assets | Where-Object { $_.name -like "*Win10*msixbundle" } | Select-Object -First 1

                if ($asset) {
                    $installerPath = "$env:TEMP\$($asset.name)"
                    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -UseBasicParsing
                    Add-AppxPackage -Path $installerPath
                    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                    Write-StyledMessage -type 'Success' -text "Windows Terminal installato da GitHub."
                }
            }
            catch {
                Write-StyledMessage -type 'Warning' -text "Installazione da GitHub fallita."
            }
        }
    }

    # Configurazione terminale predefinito
    try {
        $terminalPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
        if (Test-Path $terminalPath) {
            $registryPath = "HKCU:\Console\%%Startup"
            if (-not (Test-Path $registryPath)) {
                New-Item -Path $registryPath -Force | Out-Null
            }
            Set-ItemProperty -Path $registryPath -Name "DelegationConsole" -Value "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}" -Force
            Set-ItemProperty -Path $registryPath -Name "DelegationTerminal" -Value "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}" -Force
            Write-StyledMessage -type 'Success' -text "Windows Terminal impostato come predefinito."
        }
    }
    catch {}

    # Attesa per assicurare che Windows Terminal sia completamente installato
    Start-Sleep -Seconds 3

    # Configurazione PowerShell 7 come profilo predefinito
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    
    # Crea la directory se non esiste
    $settingsDir = Split-Path $settingsPath -Parent
    if (-not (Test-Path $settingsDir)) {
        try {
            New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
            Write-StyledMessage -type 'Info' -text "Directory settings creata."
        }
        catch {
            Write-StyledMessage -type 'Warning' -text "Impossibile creare directory settings: $($_.Exception.Message)"
        }
    }

    # Attendi che il file settings.json venga creato (max 10 secondi)
    $maxWait = 10
    $waited = 0
    while (-not (Test-Path $settingsPath) -and $waited -lt $maxWait) {
        Start-Sleep -Seconds 1
        $waited++
    }

    if (Test-Path $settingsPath) {
        try {
            Write-StyledMessage -type 'Info' -text "Configurazione profilo PowerShell 7..."
            
            # Leggi il file JSON
            $settingsContent = Get-Content $settingsPath -Raw -Encoding UTF8
            $settings = $settingsContent | ConvertFrom-Json
            
            # Cerca il profilo PowerShell 7
            # Possibili nomi: "PowerShell", "pwsh", o source che contiene "PowerShell.PowerShell_7"
            $ps7Profile = $null
            
            foreach ($profile in $settings.profiles.list) {
                # Verifica source per PowerShell 7
                if ($profile.source -like "*PowerShell.PowerShell_7*") {
                    $ps7Profile = $profile
                    break
                }
                # Verifica commandline per pwsh.exe
                if ($profile.commandline -like "*pwsh.exe*") {
                    $ps7Profile = $profile
                    break
                }
                # Fallback: cerca per nome
                if ($profile.name -eq "PowerShell" -and $profile.source) {
                    $ps7Profile = $profile
                    break
                }
            }
            
            if ($ps7Profile) {
                Write-StyledMessage -type 'Success' -text "Profilo PowerShell 7 trovato: $($ps7Profile.name)"
                
                # Imposta come profilo predefinito
                $settings.defaultProfile = $ps7Profile.guid
                
                # Aggiungi o modifica la proprietà elevate
                if ($ps7Profile.PSObject.Properties.Name -contains "elevate") {
                    $ps7Profile.elevate = $true
                }
                else {
                    $ps7Profile | Add-Member -MemberType NoteProperty -Name "elevate" -Value $true -Force
                }
                
                # Assicurati che startingDirectory sia impostato (opzionale)
                if (-not ($ps7Profile.PSObject.Properties.Name -contains "startingDirectory")) {
                    $ps7Profile | Add-Member -MemberType NoteProperty -Name "startingDirectory" -Value "%USERPROFILE%" -Force
                }
                
                # Salva le modifiche con formattazione corretta
                $settings | ConvertTo-Json -Depth 100 | Set-Content $settingsPath -Encoding UTF8 -Force
                
                Write-StyledMessage -type 'Success' -text "PowerShell 7 configurato come predefinito con privilegi amministratore."
            }
            else {
                Write-StyledMessage -type 'Warning' -text "Profilo PowerShell 7 non trovato. Potrebbe essere necessaria configurazione manuale."
                Write-StyledMessage -type 'Info' -text "Profili disponibili:"
                foreach ($profile in $settings.profiles.list) {
                    Write-Host "  - $($profile.name) [Source: $($profile.source)]" -ForegroundColor Gray
                }
            }
        }
        catch {
            Write-StyledMessage -type 'Error' -text "Errore configurazione settings.json: $($_.Exception.Message)"
            Write-StyledMessage -type 'Info' -text "Sarà necessaria configurazione manuale."
        }
    }
    else {
        Write-StyledMessage -type 'Warning' -text "File settings.json non trovato. Windows Terminal potrebbe non essere completamente installato."
        Write-StyledMessage -type 'Info' -text "Avviare Windows Terminal manualmente per generare il file di configurazione."
    }
}

function ToolKit-Desktop {
    Write-StyledMessage -type 'Info' -text "Creazione scorciatoia desktop..."
    
    try {
        $desktopPath = [System.Environment]::GetFolderPath('Desktop')
        $shortcutPath = Join-Path $desktopPath "Win Toolkit.lnk"
        $iconDir = "$env:LOCALAPPDATA\WinToolkit"
        $iconPath = Join-Path $iconDir "WinToolkit.ico"
        
        if (-not (Test-Path $iconDir)) {
            New-Item -Path $iconDir -ItemType Directory -Force | Out-Null
        }
        
        if (-not (Test-Path $iconPath)) {
            # Only download if not in offline mode or local copy was not found/copied
            Write-StyledMessage -type 'Info' -text "Download icona..."
            $iconUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/img/WinToolkit.ico"
            Invoke-WebRequest -Uri $iconUrl -OutFile $iconPath -UseBasicParsing
        }
        
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
        $Shortcut.Arguments = 'pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://magnetarman.com/WinToolkit | iex"'
        $Shortcut.WorkingDirectory = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
        $Shortcut.IconLocation = $iconPath
        $Shortcut.Description = "Win Toolkit - SOPRAVVIVI A Windows"
        $Shortcut.Save()
        
        # Abilita esecuzione come amministratore
        $bytes = [System.IO.File]::ReadAllBytes($shortcutPath)
        $bytes[21] = $bytes[21] -bor 32
        [System.IO.File]::WriteAllBytes($shortcutPath, $bytes)
        
        Write-StyledMessage -type 'Success' -text "Scorciatoia creata con successo."
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore creazione scorciatoia: $($_.Exception.Message)"
    }
}



function Start-WinToolkit {
    param(
        [switch]$InstallProfileOnly
    )

    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Output "Riavvio con privilegi amministratore..."
        $argList = $PSBoundParameters.GetEnumerator() | ForEach-Object {
            if ($_.Value -is [switch] -and $_.Value) { "-$($_.Key)" }
            elseif ($_.Value -is [array]) { "-$($_.Key) $($_.Value -join ',')" }
            elseif ($_.Value) { "-$($_.Key) '$($_.Value)'" }
        }
        $script = if ($PSCommandPath) {
            "& { & `'$PSCommandPath`' $($argList -join ' ') }"
        }
        else {
            "&([ScriptBlock]::Create((irm https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/start.ps1))) $($argList -join ' ')"
        }
        Start-Process "powershell" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
        return
    }

    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path $logdir)) { New-Item -Path $logdir -ItemType Directory -Force | Out-Null }
        Start-Transcript -Path "$logdir\WinToolkitStarter_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}

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
        '     Toolkit Starter By MagnetarMan',
        '        Version 2.4.2 (Build 3)'
    )
    foreach ($line in $asciiArt) {
        Write-Host (Center-text -text $line -width $width) -ForegroundColor White
    }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''
    
    Write-StyledMessage -type 'Info' -text "PowerShell: $($PSVersionTable.PSVersion)"
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-StyledMessage -type 'Warning' -text "PowerShell 7 raccomandato per funzionalità avanzate."
    }

    Write-StyledMessage -type 'Info' -text "Avvio configurazione Win Toolkit..."

    $rebootNeeded = $false
  
    Install-WingetSilent
    Install-Git
    
    if (-not (Test-Path "$env:ProgramFiles\PowerShell\7")) {
        if (Install-PowerShell7) {
            $rebootNeeded = $true
        }
    }
    else {
        Write-StyledMessage -type 'Success' -text "PowerShell 7 già presente."
    }

    Install-WindowsTerminal
    ToolKit-Desktop
    
    Write-StyledMessage -type 'Success' -text "Configurazione completata."
    
    if ($rebootNeeded) {
        Write-StyledMessage -type 'Warning' -text "Riavvio necessario per completare l'installazione."
        Write-StyledMessage -type 'Info' -text "Riavvio automatico tra 10 secondi..."
        for ($i = 10; $i -gt 0; $i--) {
            Write-Host "`rPreparazione riavvio - $i secondi..." -NoNewline -ForegroundColor Yellow
            Start-Sleep 1
        }
        Write-Host ""
        try { Stop-Transcript | Out-Null } catch {}
        Restart-Computer -Force
    }
    else {
        Write-StyledMessage -type 'Success' -text "Nessun riavvio necessario."
        try { Stop-Transcript | Out-Null } catch {}
    }
}

Start-WinToolkit