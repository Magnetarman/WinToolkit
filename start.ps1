<#
.SYNOPSIS
    Script di Start per Win Toolkit.
.DESCRIPTION
    Punto di ingresso per l'installazione e configurazione di Win Toolkit V2.5.0.
    Verifica e installa Git, PowerShell 7, configura Windows Terminal e crea scorciatoia desktop.
.NOTES
    Versione 2.5.0 (Build 233) - 2026-01-25
    Compatibile con PowerShell 5.1+
#>

# ============================================================================
# CONFIGURAZIONE CENTRALIZZATA
# ============================================================================

$script:AppConfig = @{
    URLs  = @{
        StartScript             = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/start.ps1"
        WingetMSIX              = "https://aka.ms/getwinget"
        GitRelease              = "https://api.github.com/repos/git-for-windows/git/releases/latest"
        PowerShellRelease       = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"

        OhMyPoshTheme           = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
        PowerShellProfile       = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/Microsoft.PowerShell_profile.ps1"
        WindowsTerminalSettings = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/settings.json"
        ToolkitIcon             = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/img/WinToolkit.ico"
    }
    Paths = @{
        Logs          = "$env:LOCALAPPDATA\WinToolkit\logs"
        WinToolkitDir = "$env:LOCALAPPDATA\WinToolkit"
        Temp          = "$env:TEMP\WinToolkitSetup"
    }
}

# ============================================================================
# FUNZIONI DI UTILITÀ
# ============================================================================

function Format-CenteredText {
    param(
        [string]$Text,
        [int]$Width = 80
    )
    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    return (" " * $padding) + $Text
}

function Write-StyledMessage {
    param(
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Type,
        [string]$Text
    )
    $colors = @{ Info = 'Cyan'; Warning = 'Yellow'; Error = 'Red'; Success = 'Green' }
    Write-Host $Text -ForegroundColor $colors[$Type]
}

function Stop-InterferingProcess {
    $interferingProcesses = @(
        "WinStore.App",
        "wsappx",
        "AppInstaller",
        "Microsoft.WindowsStore",
        "Microsoft.DesktopAppInstaller",
        "RuntimeBroker",
        "dllhost",
        "winget",
        "WindowsPackageManagerServer"
    )

    foreach ($procName in $interferingProcesses) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep 2
}

function Invoke-WingetCommand {
    param(
        [string]$Arguments,
        [int]$TimeoutSeconds = 120
    )

    try {
        $procParams = @{
            FilePath     = 'winget'
            ArgumentList = $Arguments -split ' '
            Wait         = $true
            PassThru     = $true
            NoNewWindow  = $true
        }
        $process = Start-Process @procParams
        return @{ ExitCode = $process.ExitCode }
    }
    catch {
        return @{ ExitCode = -1 }
    }
}

function Test-WingetCompatibility {
    $osInfo = [Environment]::OSVersion
    $build = $osInfo.Version.Build

    if ($osInfo.Version.Major -lt 10) {
        Write-StyledMessage -Type Error -Text "Winget non supportato su Windows $($osInfo.Version.Major)."
        return $false
    }

    if ($osInfo.Version.Major -eq 10 -and $build -lt 16299) {
        Write-StyledMessage -Type Error -Text "Windows 10 build $build non supporta Winget."
        return $false
    }

    return $true
}

function Test-WingetFunctionality {
    Write-StyledMessage -Type Info -Text "🔍 Verifica funzionalità Winget..."

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Warning -Text "Winget non trovato nel PATH."
        return $false
    }

    try {
        # Test download pacchetto leggero per verificare funzionalità
        $result = Invoke-WingetCommand -Arguments "search Microsoft.PowerToys --count 1"

        if ($result.ExitCode -eq 0) {
            Write-StyledMessage -Type Success -Text "✅ Winget operativo e funzionante."
            return $true
        }
        else {
            Write-StyledMessage -Type Warning -Text "Winget presente ma non funzionante (Exit Code: $($result.ExitCode))."
            return $false
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Errore durante test Winget: $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
# FUNZIONI DI INSTALLAZIONE
# ============================================================================

function Install-WingetCore {
    Write-StyledMessage -Type Info -Text "🛠️ Avvio procedura di ripristino Winget (Core)..."
    
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    # Configurazione Helper interni
    function Get-WingetDownloadUrl {
        param([string]$Match)
        try {
            $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
            $asset = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
            if ($asset) { return $asset.browser_download_url }
            throw "Asset '$Match' non trovato."
        }
        catch {
            Write-StyledMessage -Type Warning -Text "Errore recupero URL asset: $($_.Exception.Message)"
            return $null
        }
    }

    function Test-VCRedist {
        # Semplificato: controlla la chiave di registro per VC++ 2015-2022 (v14+)
        $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
        $regPath = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\$arch"
        if (Test-Path $regPath) {
            $ver = (Get-ItemProperty $regPath).Version
            if ($ver) { return $true }
        }
        return $false
    }

    $tempDir = "$env:TEMP\WinToolkitWinget"
    if (-not (Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force | Out-Null }
    
    try {
        # 1. Visual C++ Redistributable
        if (-not (Test-VCRedist)) {
            Write-StyledMessage -Type Info -Text "Installazione Visual C++ Redistributable..."
            $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
            $vcUrl = "https://aka.ms/vs/17/release/vc_redist.$arch.exe"
            $vcFile = Join-Path $tempDir "vc_redist.exe"
            
            Invoke-WebRequest -Uri $vcUrl -OutFile $vcFile -UseBasicParsing
            Start-Process -FilePath $vcFile -ArgumentList "/install", "/quiet", "/norestart" -Wait
            Write-StyledMessage -Type Success -Text "Visual C++ Redistributable installato."
        } else {
            Write-StyledMessage -Type Success -Text "Visual C++ Redistributable già presente."
        }

        # 2. Dipendenze (UI.Xaml, VCLibs)
        Write-StyledMessage -Type Info -Text "Download dipendenze Winget..."
        $depUrl = Get-WingetDownloadUrl -Match 'DesktopAppInstaller_Dependencies.zip'
        if ($depUrl) {
            $depZip = Join-Path $tempDir "dependencies.zip"
            Invoke-WebRequest -Uri $depUrl -OutFile $depZip -UseBasicParsing
            
            # Estrazione e installazione mirata
            $extractPath = Join-Path $tempDir "deps"
            Expand-Archive -Path $depZip -DestinationPath $extractPath -Force
            
            $archPattern = if ([Environment]::Is64BitOperatingSystem) { "x64|ne" } else { "x86|ne" }
            $appxFiles = Get-ChildItem -Path $extractPath -Recurse -Filter "*.appx" | Where-Object { $_.Name -match $archPattern }
            
            foreach ($file in $appxFiles) {
                Write-StyledMessage -Type Info -Text "Installazione dipendenza: $($file.Name)..."
                Add-AppxPackage -Path $file.FullName -ErrorAction SilentlyContinue
            }
        }

        # 3. Winget Bundle
        Write-StyledMessage -Type Info -Text "Download e installazione Winget Bundle..."
        $wingetUrl = Get-WingetDownloadUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        if ($wingetUrl) {
            $wingetFile = Join-Path $tempDir "winget.msixbundle"
            Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetFile -UseBasicParsing
            
            Add-AppxPackage -Path $wingetFile -ForceApplicationShutdown -ErrorAction Stop
            Write-StyledMessage -Type Success -Text "Winget Core installato con successo."
        }

        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore durante il ripristino Winget: $($_.Exception.Message)"
        return $false
    }
    finally {
        if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
        $ProgressPreference = $oldProgress
    }
}

function Install-WingetPackage {
    Write-StyledMessage -Type Info -Text "🚀 Avvio procedura installazione/verifica Winget..."

    if (-not (Test-WingetCompatibility)) { return $false }

    Stop-InterferingProcess

    try {
        $ProgressPreference = 'SilentlyContinue'

        # Pulizia temporanei
        $tempPath = "$env:TEMP\WinGet"
        if (Test-Path $tempPath) {
            Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-StyledMessage -Type Info -Text "Cache temporanea eliminata."
        }

        # Reset sorgenti se Winget esiste
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text "Reset sorgenti Winget..."
            & "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" source reset --force 2>$null
        }



        # Fallback: Installazione dipendenze NuGet
        Write-StyledMessage -Type Info -Text "Installazione NuGet e moduli..."
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop | Out-Null
            Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop | Out-Null
            Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
            Write-StyledMessage -Type Success -Text "Dipendenze installate."
        }
        catch {
            Write-StyledMessage -Type Warning -Text "Dipendenze potrebbero richiedere conferma manuale."
        }

        # Riparazione via modulo
        Write-StyledMessage -Type Info -Text "Tentativo riparazione Winget..."
        if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
             Repair-WinGetPackageManager -Force -Latest 2>$null | Out-Null
             Start-Sleep 3
        }

        # Fallback finale: installazione via MSIXBundle
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type Info -Text "Download MSIXBundle da Microsoft..."
            $tempInstaller = "$tempDir\WingetInstaller.msixbundle"

            Invoke-WebRequest -Uri $script:AppConfig.URLs.WingetMSIX -OutFile $tempInstaller -UseBasicParsing
            Add-AppxPackage -Path $tempInstaller -ForceApplicationShutdown -ErrorAction Stop
            Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
            Start-Sleep 3
        }

        # Reset App Installer
        Write-StyledMessage -Type Info -Text "Reset App Installer..."
        Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null

        Start-Sleep 2

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Success -Text "✅ Winget installato e funzionante."
            return $true
        }

        Write-StyledMessage -Type Error -Text "❌ Impossibile installare Winget."
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore critico: $($_.Exception.Message)"
        return $false
    }
    finally {
        $ProgressPreference = 'Continue'
    }
}

function Install-GitPackage {
    Write-StyledMessage -Type Info -Text "Verifica installazione Git..."

    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Success -Text "Git già installato."
        return $true
    }

    Write-StyledMessage -Type Info -Text "Installazione Git..."

    # 1. Tentativo via winget (Prioritario)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $result = Invoke-WingetCommand -Arguments "install Git.Git --accept-source-agreements --accept-package-agreements --silent"

        if ($result.ExitCode -eq 0) {
            Start-Sleep 3
            $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

            if (Get-Command git -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Success -Text "Git installato via winget."
                return $true
            }
        }
    }

    # 2. Fallback: download diretto da GitHub
    try {
        Write-StyledMessage -Type Info -Text "Fallback: Download Git da GitHub..."
        $release = Invoke-RestMethod -Uri $script:AppConfig.URLs.GitRelease -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -like "*64-bit.exe" } | Select-Object -First 1

        if (-not $asset) {
            Write-StyledMessage -Type Error -Text "Asset Git 64-bit non trovato."
            return $false
        }

        $tempDir = $script:AppConfig.Paths.Temp
        if (-not (Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force | Out-Null }
        $installerPath = Join-Path $tempDir $asset.name

        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -UseBasicParsing

        Write-StyledMessage -Type Info -Text "Esecuzione installer Git..."

        $procParams = @{
            FilePath     = $installerPath
            ArgumentList = @("/SILENT", "/NORESTART", "/CLOSEAPPLICATIONS")
            Wait         = $true
            PassThru     = $true
        }
        $process = Start-Process @procParams

        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

        if ($process.ExitCode -eq 0) {
            $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
            Write-StyledMessage -Type Success -Text "Git installato con successo."
            return $true
        }

        Write-StyledMessage -Type Error -Text "Installazione fallita. Codice: $($process.ExitCode)"
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore installazione Git: $($_.Exception.Message)"
        return $false
    }
}

function Install-PowerShellCore {
    Write-StyledMessage -Type Info -Text "Verifica PowerShell 7..."

    if (Test-Path "$env:ProgramFiles\PowerShell\7") {
        Write-StyledMessage -Type Success -Text "PowerShell 7 già installato."
        return $true
    }

    try {
        Write-StyledMessage -Type Info -Text "Recupero ultima release PowerShell..."
        $release = Invoke-RestMethod -Uri $script:AppConfig.URLs.PowerShellRelease -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -like "*win-x64.msi" } | Select-Object -First 1

        if (-not $asset) {
            Write-StyledMessage -Type Error -Text "Asset PowerShell 7 win-x64.msi non trovato."
            return $false
        }

        $tempDir = $script:AppConfig.Paths.Temp
        if (-not (Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force | Out-Null }
        $installerPath = Join-Path $tempDir $asset.name

        Write-StyledMessage -Type Info -Text "Download installer..."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -UseBasicParsing

        Write-StyledMessage -Type Info -Text "Installazione PowerShell 7 in corso..."

        $procParams = @{
            FilePath     = "msiexec.exe"
            ArgumentList = @(
                "/i", "`"$installerPath`"",
                "/norestart",
                "/passive",
                "ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1",
                "ENABLE_PSREMOTING=1",
                "REGISTER_MANIFEST=1"
            )
            Wait         = $true
            PassThru     = $true
        }

        $process = Start-Process @procParams
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

        Start-Sleep 3

        if ((Test-Path "$env:ProgramFiles\PowerShell\7") -or $process.ExitCode -eq 0) {
            Write-StyledMessage -Type Success -Text "PowerShell 7 installato con successo."
            return $true
        }

        Write-StyledMessage -Type Error -Text "Installazione fallita. Codice: $($process.ExitCode)"
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore installazione PowerShell: $($_.Exception.Message)"
        return $false
    }
}

function Install-WindowsTerminalApp {
    Write-StyledMessage -Type Info -Text "Configurazione Windows Terminal..."

    # Installazione se necessario
    if (-not (Get-Command wt -ErrorAction SilentlyContinue)) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text "Installazione via winget..."
            $result = Invoke-WingetCommand -Arguments "install --id 9N0DX20HK701 --source msstore --accept-source-agreements --accept-package-agreements --silent"
            Start-Sleep 3
        }

        if (-not (Get-Command wt -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type Info -Text "Fallback: Apertura Microsoft Store..."
            Start-Process "ms-windows-store://pdp/?ProductId=9N0DX20HK701"
            Write-StyledMessage -Type Warning -Text "Completare installazione manualmente dal Store."
            Start-Sleep 5
            return
        }
    }
    else {
        Write-StyledMessage -Type Success -Text "Windows Terminal già presente."
    }

    # Imposta come terminale predefinito
    try {
        $terminalPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
        if (Test-Path $terminalPath) {
            $regPath = "HKCU:\Console\%%Startup"
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            Set-ItemProperty -Path $regPath -Name "DelegationConsole" -Value "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}" -Force
            Set-ItemProperty -Path $regPath -Name "DelegationTerminal" -Value "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}" -Force
            Write-StyledMessage -Type Success -Text "Windows Terminal impostato come predefinito."
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Errore impostazione predefinito: $($_.Exception.Message)"
    }

    # Configurazione Profilo PowerShell 7 in Terminal
    Start-Sleep 3
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

    # Attesa creazione file settings
    $waited = 0
    while (-not (Test-Path $settingsPath) -and $waited -lt 20) {
        Start-Sleep 1
        $waited++
    }

    if (-not (Test-Path $settingsPath)) {
        Write-StyledMessage -Type Warning -Text "File settings.json non trovato. Avviare Windows Terminal manualmente una volta."
        return
    }

    try {
        Write-StyledMessage -Type Info -Text "Configurazione profilo PowerShell 7 in Terminal..."
        $settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

        # Ricerca profilo PowerShell 7
        $ps7Profile = $settings.profiles.list | Where-Object {
            $_.source -like "*PowerShell.PowerShell_7*" -or
            $_.commandline -like "*pwsh.exe*" -or
            ($_.name -eq "PowerShell" -and $_.source)
        } | Select-Object -First 1

        if ($ps7Profile) {
            Write-StyledMessage -Type Success -Text "Profilo PowerShell 7 trovato: $($ps7Profile.name)"

            $settings.defaultProfile = $ps7Profile.guid
            $ps7Profile | Add-Member -MemberType NoteProperty -Name "elevate" -Value $true -Force

            $settings | ConvertTo-Json -Depth 100 | Set-Content $settingsPath -Encoding UTF8 -Force
            Write-StyledMessage -Type Success -Text "Windows Terminal configurato per PS7 Admin."
        }
        else {
            Write-StyledMessage -Type Warning -Text "Profilo PowerShell 7 non trovato automaticamente."
        }
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore configurazione settings.json: $($_.Exception.Message)"
    }
}

function Install-PspEnvironment {
    Write-StyledMessage -Type Info -Text "Avvio configurazione ambiente PowerShell (PSP)..."

    # ============================================================================
    # HELPER FUNCTIONS LOCALI
    # ============================================================================

    function Install-NerdFontsLocal {
        try {
            Write-StyledMessage -Type Info -Text "🔍 Verifica presenza JetBrainsMono Nerd Font..."
            
            # Controllo rapido se il font è già registrato nel sistema
            $fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
            $installed = Get-ItemProperty -Path $fontRegistryPath -ErrorAction SilentlyContinue | 
                         Get-Member -MemberType NoteProperty | 
                         Where-Object Name -like "*JetBrainsMono*"

            if ($installed) {
                Write-StyledMessage -Type Success -Text "✅ JetBrainsMono Nerd Font già installato."
                return $true
            }

            Write-StyledMessage -Type Info -Text "⬇️ Installazione font tramite WinGet (Metodo Rapido)..."
            
            # Utilizzo della funzione helper esistente per coerenza logica
            $result = Invoke-WingetCommand -Arguments "install --id DEVCOM.JetBrainsMonoNerdFont --source winget --accept-source-agreements --accept-package-agreements --silent"

            if ($result.ExitCode -eq 0) {
                Write-StyledMessage -Type Success -Text "✅ Nerd Fonts installati con successo."
                return $true
            } else {
                Write-StyledMessage -Type Warning -Text "⚠️ WinGet ha restituito codice $($result.ExitCode). Il font potrebbe richiedere un riavvio del terminale."
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type Warning -Text "❌ Errore durante l'installazione font: $($_.Exception.Message)"
            return $false
        }
    }

    function Get-ProfileDirLocal {
        if ($PSVersionTable.PSEdition -eq "Core") {
            return [Environment]::GetFolderPath("MyDocuments") + "\PowerShell"
        } else {
            return [Environment]::GetFolderPath("MyDocuments") + "\WindowsPowerShell"
        }
    }

    # ============================================================================
    # ESECUZIONE SETUP PSP
    # ============================================================================

    # 1. Installazione Tool via Winget
    $tools = @(
        @{ Id = "JanDeDobbeleer.OhMyPosh"; Name = "Oh My Posh" },
        @{ Id = "ajeetdsouza.zoxide"; Name = "zoxide" },
        @{ Id = "aristocratos.btop4win"; Name = "btop" },
        @{ Id = "Fastfetch-cli.Fastfetch"; Name = "fastfetch" }
    )

    foreach ($tool in $tools) {
        Write-StyledMessage -Type Info -Text "Verifica $($tool.Name)..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Invoke-WingetCommand -Arguments "install -e --id $($tool.Id) --accept-source-agreements --accept-package-agreements --silent" | Out-Null
        }
    }

    # 2. Installazione Tema Oh My Posh
    $profileDir = Get-ProfileDirLocal
    if ($profileDir) {
        $themesFolder = Join-Path $profileDir "Themes"
        if (-not (Test-Path $themesFolder)) { New-Item -Path $themesFolder -ItemType Directory -Force | Out-Null }

        $themePath = Join-Path $themesFolder "atomic.omp.json"
        try {
            Invoke-WebRequest -Uri $script:AppConfig.URLs.OhMyPoshTheme -OutFile $themePath -UseBasicParsing
            Write-StyledMessage -Type Success -Text "Tema Oh My Posh scaricato."
        } catch {
            Write-StyledMessage -Type Warning -Text "Errore download tema."
        }
    }

    # 3. Installazione Font
    Install-NerdFontsLocal

    # 4. Configurazione Profilo
    if ($profileDir) {
        if (-not (Test-Path $profileDir)) { New-Item -Path $profileDir -ItemType Directory -Force | Out-Null }

        $targetProfile = $PROFILE
        if (-not $targetProfile) { $targetProfile = Join-Path $profileDir "Microsoft.PowerShell_profile.ps1" }

        try {
            if (Test-Path $targetProfile) {
                Move-Item -Path $targetProfile -Destination "$targetProfile.bak" -Force -ErrorAction SilentlyContinue
            }
            Invoke-WebRequest -Uri $script:AppConfig.URLs.PowerShellProfile -OutFile $targetProfile -UseBasicParsing
            Write-StyledMessage -Type Success -Text "Profilo PowerShell configurato."
        } catch {
            Write-StyledMessage -Type Warning -Text "Errore configurazione profilo."
        }
    }

    # 5. Configurazione Settings Windows Terminal
    try {
        $wtPath = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Directory -Filter "Microsoft.WindowsTerminal_*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($wtPath) {
            $settingsPath = Join-Path $wtPath.FullName "LocalState\settings.json"
            if (Test-Path (Join-Path $wtPath.FullName "LocalState")) {
                Invoke-WebRequest -Uri $script:AppConfig.URLs.WindowsTerminalSettings -OutFile $settingsPath -UseBasicParsing
                Write-StyledMessage -Type Success -Text "Settings Windows Terminal aggiornati."
            }
        }
    } catch {
        Write-StyledMessage -Type Warning -Text "Errore aggiornamento settings terminal."
    }
}

function New-ToolkitDesktopShortcut {
    Write-StyledMessage -Type Info -Text "Creazione scorciatoia desktop..."

    try {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $shortcut = Join-Path $desktop "Win Toolkit.lnk"
        $iconDir = $script:AppConfig.Paths.WinToolkitDir
        $icon = Join-Path $iconDir "WinToolkit.ico"

        if (-not (Test-Path $iconDir)) {
            New-Item -Path $iconDir -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path $icon)) {
            Write-StyledMessage -Type Info -Text "Download icona..."
            Invoke-WebRequest -Uri $script:AppConfig.URLs.ToolkitIcon -OutFile $icon -UseBasicParsing
        }

        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcut)
        $link.TargetPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
        $link.Arguments = 'pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://magnetarman.com/WinToolkit | iex"'
        $link.WorkingDirectory = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
        $link.IconLocation = $icon
        $link.Description = "Win Toolkit - SOPRAVVIVI A Windows"
        $link.Save()

        # Abilita esecuzione come amministratore
        $bytes = [IO.File]::ReadAllBytes($shortcut)
        $bytes[21] = $bytes[21] -bor 32
        [IO.File]::WriteAllBytes($shortcut, $bytes)

        Write-StyledMessage -Type Success -Text "Scorciatoia creata con successo."
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore creazione scorciatoia: $($_.Exception.Message)"
    }
}

# ============================================================================
# FUNZIONE PRINCIPALE
# ============================================================================

function Invoke-WinToolkitSetup {
    param(
        [switch]$InstallProfileOnly
    )

    # Controlla se siamo in modalità resume (già installato PS7, rilanciato)
    $isResumeSetup = $env:WINTOOLKIT_RESUME -eq "1"

    $Host.UI.RawUI.WindowTitle = "Toolkit Starter by MagnetarMan"

    # Verifica privilegi amministratore
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Output "Riavvio con privilegi amministratore..."

        $argList = $PSBoundParameters.GetEnumerator() | ForEach-Object {
            if ($_.Value -is [switch] -and $_.Value) { "-$($_.Key)" }
            elseif ($_.Value -is [array]) { "-$($_.Key) $($_.Value -join ',')" }
            elseif ($_.Value) { "-$($_.Key) '$($_.Value)'" }
        }

        $startUrl = $script:AppConfig.URLs.StartScript
        $scriptBlock = if ($PSCommandPath) {
            "& '$PSCommandPath' $($argList -join ' ')"
        }
        else {
            "iex (irm '$startUrl') $($argList -join ' ')"
        }

        $procParams = @{
            FilePath     = 'powershell'
            ArgumentList = @( '-ExecutionPolicy', 'Bypass', '-NoProfile', '-Command', "`"$scriptBlock`"" )
            Verb         = 'RunAs'
        }
        Start-Process @procParams
        return
    }

    # Configurazione Logging
    $logDir = $script:AppConfig.Paths.Logs
    try {
        if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
        Start-Transcript -Path "$logDir\WinToolkitStarter_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log" -Append -Force | Out-Null
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Errore avvio logging: $($_.Exception.Message)"
    }

    # Banner
    Clear-Host
    $width = 65
    Write-Host ('═' * $width) -ForegroundColor Green
    @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        '     Toolkit Starter By MagnetarMan',
        '        Version 2.5.0 (Build 234)'
    ) | ForEach-Object { Write-Host (Format-CenteredText -Text $_ -Width $width) -ForegroundColor White }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''

    Write-StyledMessage -Type Info -Text "PowerShell: $($PSVersionTable.PSVersion)"
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-StyledMessage -Type Warning -Text "PowerShell 7 raccomandato per funzionalità avanzate."
    }

    Write-StyledMessage -Type Info -Text "Avvio configurazione Win Toolkit..."

    # Pipeline Installazione
    $rebootNeeded = $false

    if (-not $isResumeSetup) {
        Write-StyledMessage -Type Info -Text "Esecuzione controlli base..."

        # 1. Test e Ripristino Winget (Requirement 3 & 4)
        if (-not (Test-WingetFunctionality)) {
            Write-StyledMessage -Type Warning -Text "⚠️ Winget non risponde. Tentativo di ripristino..."
            
            # 1. Tentativo Ripristino Veloce (Core/Bundle)
            $coreSuccess = Install-WingetCore
            
            # Verifica intermediaria: se Winget funziona ora, salta il metodo lento
            if ($coreSuccess -and (Test-WingetFunctionality)) {
                 Write-StyledMessage -Type Success -Text "✅ Winget ripristinato velocemente."
            }
            else {
                # 2. Fallback Lento (Moduli PowerShell)
                Write-StyledMessage -Type Warning -Text "⚠️ Ripristino veloce fallito. Tentativo metodo avanzato (più lento)..."
                Install-WingetPackage 
                
                # Verifica Post-Installazione
                if (-not (Test-WingetFunctionality)) {
                    Write-StyledMessage -Type Warning -Text "⚠️ Winget non funzionale anche dopo il tentativo di installazione."
                    Write-StyledMessage -Type Info -Text "Lo script proseguirà, ma l'installazione di pacchetti potrebbe fallire."
                }
            }
        }
        else {
            Write-StyledMessage -Type Success -Text "✅ Winget è già operativo."
        }
        Install-GitPackage

        if (-not (Test-Path "$env:ProgramFiles\PowerShell\7")) {
            if (Install-PowerShellCore) {
                $null
            }
        }
        else {
            Write-StyledMessage -Type Success -Text "PowerShell 7 già presente."
        }
    }

    # --- AUTO-RELAUNCH IN POWERSHELL 7 ---
    # Riavvio dello script nel nuovo motore PS7 se disponibile
    if ($PSVersionTable.PSVersion.Major -lt 7 -and (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe")) {
        Write-StyledMessage -Type Info -Text "✨ Rilevata PowerShell 7. Upgrade dell'ambiente di esecuzione..."
        Start-Sleep 2

        $argList = $PSBoundParameters.GetEnumerator() | ForEach-Object {
            if ($_.Value -is [switch] -and $_.Value) { "-$($_.Key)" }
            elseif ($_.Value -is [array]) { "-$($_.Key) $($_.Value -join ',')" }
            elseif ($_.Value) { "-$($_.Key) '$($_.Value)'" }
        }

        # Imposta variabile ambiente per segnalare il resume al nuovo processo
        $env:WINTOOLKIT_RESUME = "1"

        $startUrl = $script:AppConfig.URLs.StartScript
        $scriptBlock = if ($PSCommandPath) {
            "& '$PSCommandPath' $($argList -join ' ')"
        }
        else {
            "iex (irm '$startUrl') $($argList -join ' ')"
        }

        # Splatting per Start-Process
        $procParams = @{
            FilePath     = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
            ArgumentList = @("-ExecutionPolicy", "Bypass", "-NoExit", "-Command", "`"$scriptBlock`"")
            Verb         = "RunAs"
        }
        Start-Process @procParams

        Write-StyledMessage -Type Success -Text "Script riavviato su PowerShell 7. Chiusura sessione legacy..."
        try { Stop-Transcript | Out-Null } catch { }
        exit
    }
    # -------------------------------------

    Install-WindowsTerminalApp
    Install-PspEnvironment
    New-ToolkitDesktopShortcut

    Write-StyledMessage -Type Success -Text "Configurazione completata."

    # Gestione Riavvio
    if ($rebootNeeded) {
        Write-StyledMessage -Type Warning -Text "Riavvio necessario per completare l'installazione."
        Write-StyledMessage -Type Info -Text "Riavvio automatico tra 10 secondi..."

        for ($i = 10; $i -gt 0; $i--) {
            Write-Host "`rPreparazione riavvio - $i secondi..." -NoNewline -ForegroundColor Yellow
            Start-Sleep 1
        }
        Write-Host ""

        try { Stop-Transcript | Out-Null } catch { }
        Restart-Computer -Force
    }
    else {
        Write-StyledMessage -Type Success -Text "Nessun riavvio necessario."
        try { Stop-Transcript | Out-Null } catch { }
    }
}

# Avvio Script
Invoke-WinToolkitSetup
