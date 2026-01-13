<#
.SYNOPSIS
    Script di Start per Win Toolkit.
.DESCRIPTION
    Punto di ingresso per l'installazione e configurazione di Win Toolkit V2.0.
    Verifica e installa Git, PowerShell 7, configura Windows Terminal e crea scorciatoia desktop.
.NOTES
    Versione 2.5.0 (Build 212) - 2026-01-13
    Compatibile con PowerShell 5.1+
#>

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Center-Text {
    param([string]$Text, [int]$Width = 80)
    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    (" " * $padding) + $Text
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

function Stop-InterferingProcesses {
    $processes = @("WinStore.App", "wsappx", "AppInstaller", "Microsoft.WindowsStore",
        "Microsoft.DesktopAppInstaller", "RuntimeBroker", "dllhost")

    Get-Process -Name $processes -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
}

function Invoke-WingetWithTimeout {
    param([string]$Arguments, [int]$TimeoutSeconds = 120)

    try {
        $process = Start-Process winget -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
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

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

function Install-WingetSilent {
    Write-StyledMessage -Type Info -Text "🚀 Avvio procedura reinstallazione Winget..."

    if (-not (Test-WingetCompatibility)) { return $false }

    Stop-InterferingProcesses

    try {
        $ProgressPreference = 'SilentlyContinue'

        # Terminazione processi
        Write-StyledMessage -Type Info -Text "Chiusura processi Winget..."
        @("winget", "WindowsPackageManagerServer") | ForEach-Object {
            Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep 2

        # Pulizia temporanei
        $tempPath = "$env:TEMP\WinGet"
        if (Test-Path $tempPath) {
            Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-StyledMessage -Type Info -Text "Cache temporanea eliminata."
        }

        # Reset sorgenti
        Write-StyledMessage -Type Info -Text "Reset sorgenti Winget..."
        & "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" source reset --force 2>$null

        # Installazione dipendenze
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

        # Fallback: installazione via MSIXBundle
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type Info -Text "Download MSIXBundle da Microsoft..."
            $temp = "$env:TEMP\WingetInstaller.msixbundle"

            Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile $temp -UseBasicParsing
            Add-AppxPackage -Path $temp -ForceApplicationShutdown -ErrorAction Stop
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
            Start-Sleep 3
        }

        # Reset App Installer
        Write-StyledMessage -Type Info -Text "Reset App Installer..."
        Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null

        Start-Sleep 2

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Success -Text "Winget installato e funzionante."
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

function Install-Git {
    Write-StyledMessage -Type Info -Text "Verifica installazione Git..."

    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
    [Environment]::GetEnvironmentVariable("Path", "User")

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Success -Text "Git già installato."
        return $true
    }

    Write-StyledMessage -Type Info -Text "Installazione Git..."

    # Tentativo via winget
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $result = Invoke-WingetWithTimeout -Arguments "install Git.Git --accept-source-agreements --accept-package-agreements --silent"

        if ($result.ExitCode -eq 0) {
            Start-Sleep 3
            $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [Environment]::GetEnvironmentVariable("Path", "User")

            if (Get-Command git -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Success -Text "Git installato via winget."
                return $true
            }
        }
    }

    # Fallback: download diretto da GitHub
    try {
        Write-StyledMessage -Type Info -Text "Download da GitHub..."
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest" -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -like "*64-bit.exe" } | Select-Object -First 1

        if (-not $asset) {
            Write-StyledMessage -Type Error -Text "Asset Git 64-bit non trovato."
            return $false
        }

        $installer = "$env:TEMP\$($asset.name)"
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installer -UseBasicParsing

        Write-StyledMessage -Type Info -Text "Installazione Git..."
        $process = Start-Process $installer -ArgumentList "/SILENT /NORESTART /CLOSEAPPLICATIONS" -Wait -PassThru
        Remove-Item $installer -Force -ErrorAction SilentlyContinue

        if ($process.ExitCode -eq 0) {
            $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [Environment]::GetEnvironmentVariable("Path", "User")
            Write-StyledMessage -Type Success -Text "Git installato con successo."
            return $true
        }

        Write-StyledMessage -Type Error -Text "Installazione fallita. Codice: $($process.ExitCode)"
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore installazione: $($_.Exception.Message)"
        return $false
    }
}

function Install-PowerShell7 {
    Write-StyledMessage -Type Info -Text "Verifica PowerShell 7..."

    if (Test-Path "$env:ProgramFiles\PowerShell\7") {
        Write-StyledMessage -Type Success -Text "PowerShell 7 già installato."
        return $true
    }

    try {
        Write-StyledMessage -Type Info -Text "Download PowerShell 7.5.2..."
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/tags/v7.5.4" -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -like "*win-x64.msi" } | Select-Object -First 1

        if (-not $asset) {
            Write-StyledMessage -Type Error -Text "Asset PowerShell 7.5.4 non trovato."
            return $false
        }

        $installer = "$env:TEMP\$($asset.name)"
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installer -UseBasicParsing

        Write-StyledMessage -Type Info -Text "Avvio installatore PowerShell 7.5.4. Completare l'installazione..."

        $installParams = @{
            FilePath     = "msiexec.exe"
            ArgumentList = "/i `"$installer`" /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1"
            Wait         = $true
            PassThru     = $true
        }

        $process = Start-Process @installParams
        Remove-Item $installer -Force -ErrorAction SilentlyContinue

        Start-Sleep 3

        if ((Test-Path "$env:ProgramFiles\PowerShell\7") -or $process.ExitCode -eq 0) {
            Write-StyledMessage -Type Success -Text "PowerShell 7.5.4 installato."
            return $true
        }

        Write-StyledMessage -Type Error -Text "Installazione fallita. Codice: $($process.ExitCode)"
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore installazione: $($_.Exception.Message)"
        return $false
    }
}

function Install-WindowsTerminal {
    Write-StyledMessage -Type Info -Text "Configurazione Windows Terminal..."

    # Installazione se necessario
    if (-not (Get-Command wt -ErrorAction SilentlyContinue)) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text "Installazione via winget..."
            $result = Invoke-WingetWithTimeout -Arguments "install --id 9N0DX20HK701 --source msstore --accept-source-agreements --accept-package-agreements --silent"
            Start-Sleep 3
        }

        if (-not (Get-Command wt -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type Info -Text "Apertura Microsoft Store..."
            Start-Process "ms-windows-store://pdp/?ProductId=9N0DX20HK701"
            Write-StyledMessage -Type Warning -Text "Completare installazione manualmente."
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

    # Configurazione PowerShell 7
    Start-Sleep 3
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

    # Attesa creazione file settings
    $waited = 0
    while (-not (Test-Path $settingsPath) -and $waited -lt 20) {
        Start-Sleep 1
        $waited++
    }

    if (-not (Test-Path $settingsPath)) {
        Write-StyledMessage -Type Warning -Text "File settings.json non trovato. Avviare Windows Terminal manualmente."
        return
    }

    try {
        Write-StyledMessage -Type Info -Text "Configurazione profilo PowerShell 7..."

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
            Write-StyledMessage -Type Success -Text "PowerShell 7 configurato con privilegi amministratore."
        }
        else {
            Write-StyledMessage -Type Warning -Text "Profilo PowerShell 7 non trovato. Configurazione manuale necessaria."
        }
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore configurazione settings.json: $($_.Exception.Message)"
    }
}

function Install-PSPEnv {
    Write-StyledMessage -Type Info -Text "Avvio configurazione ambiente PowerShell (PSP)..."

    # ============================================================================
    # CONFIGURAZIONE HARDCODED
    # ============================================================================
    $PSPConfig = @{
        NerdFontsAPI            = "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
        JetBrainsMonoFallback   = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.zip"
        OhMyPoshTheme           = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
        PowerShellProfile       = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/Microsoft.PowerShell_profile.ps1"
        WindowsTerminalSettings = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/settings.json"
    }

    # ============================================================================
    # HELPER FUNCTIONS LOCALI
    # ============================================================================

    function Install-NerdFontsLocal {
        try {
            $fontNamesToCheck = @("JetBrainsMono Nerd Font", "JetBrainsMonoNL Nerd Font", "JetBrainsMono NFM")
            $fonts = [System.Drawing.Text.InstalledFontCollection]::new()

            foreach ($fontName in $fontNamesToCheck) {
                if ($fonts.Families.Name -contains $fontName) {
                    Write-StyledMessage -Type Success -Text "Font $fontName già installato."
                    return $true
                }
            }

            # Check cartella Fonts
            if (Get-ChildItem -Path "C:\Windows\Fonts" -Filter "*JetBrains*" -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Info -Text "File JetBrainsMono presenti. Skip."
                return $true
            }

            Write-StyledMessage -Type Info -Text "⬇️ Download JetBrainsMono Nerd Font..."

            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

            # Tentativo download da API GitHub, fallback su URL diretto
            $fontZipUrl = $PSPConfig.JetBrainsMonoFallback
            try {
                $release = Invoke-RestMethod $PSPConfig.NerdFontsAPI -ErrorAction SilentlyContinue
                $asset = $release.assets | Where-Object { $_.name -eq "JetBrainsMono.zip" } | Select-Object -First 1
                if ($asset) { $fontZipUrl = $asset.browser_download_url }
            } catch {}

            $zipFilePath = "$env:TEMP\JetBrainsMono.zip"
            $extractPath = "$env:TEMP\JetBrainsMono"

            Invoke-WebRequest -Uri $fontZipUrl -OutFile $zipFilePath -UseBasicParsing
            Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force

            Write-StyledMessage -Type Info -Text "Installazione font..."
            $shellFontFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)

            Get-ChildItem -Path $extractPath -Recurse -Filter "*.ttf" | ForEach-Object {
                if (-not (Test-Path "C:\Windows\Fonts\$($_.Name)")) {
                    $shellFontFolder.CopyHere($_.FullName, 0x10)
                }
            }

            Remove-Item $extractPath, $zipFilePath -Recurse -Force -ErrorAction SilentlyContinue
            Write-StyledMessage -Type Success -Text "Nerd Fonts installati."
            return $true
        }
        catch {
            Write-StyledMessage -Type Warning -Text "Errore installazione font: $($_.Exception.Message)"
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
    # ESECUZIONE SETUP
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
            Invoke-WingetWithTimeout -Arguments "install -e --id $($tool.Id) --accept-source-agreements --accept-package-agreements --silent" | Out-Null
        }
    }

    # 2. Installazione Tema Oh My Posh
    $profileDir = Get-ProfileDirLocal
    if ($profileDir) {
        $themesFolder = Join-Path $profileDir "Themes"
        if (-not (Test-Path $themesFolder)) { New-Item -Path $themesFolder -ItemType Directory -Force | Out-Null }

        $themePath = Join-Path $themesFolder "atomic.omp.json"
        try {
            Invoke-WebRequest -Uri $PSPConfig.OhMyPoshTheme -OutFile $themePath -UseBasicParsing
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
            Invoke-WebRequest -Uri $PSPConfig.PowerShellProfile -OutFile $targetProfile -UseBasicParsing
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
                Invoke-WebRequest -Uri $PSPConfig.WindowsTerminalSettings -OutFile $settingsPath -UseBasicParsing
                Write-StyledMessage -Type Success -Text "Settings Windows Terminal aggiornati."
            }
        }
    } catch {
        Write-StyledMessage -Type Warning -Text "Errore aggiornamento settings terminal."
    }
}

function New-ToolkitShortcut {
    Write-StyledMessage -Type Info -Text "Creazione scorciatoia desktop..."

    try {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $shortcut = Join-Path $desktop "Win Toolkit.lnk"
        $iconDir = "$env:LOCALAPPDATA\WinToolkit"
        $icon = Join-Path $iconDir "WinToolkit.ico"

        if (-not (Test-Path $iconDir)) {
            New-Item -Path $iconDir -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path $icon)) {
            Write-StyledMessage -Type Info -Text "Download icona..."
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/img/WinToolkit.ico" `
                -OutFile $icon -UseBasicParsing
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
# MAIN FUNCTION
# ============================================================================

function Start-WinToolkit {
    param(
        [switch]$InstallProfileOnly
    )

    $Host.UI.RawUI.WindowTitle = "Toolkit Starter by MagnetarMan"

    # Verifica privilegi amministratore
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Output "Riavvio con privilegi amministratore..."

        $argList = $PSBoundParameters.GetEnumerator() | ForEach-Object {
            if ($_.Value -is [switch] -and $_.Value) { "-$($_.Key)" }
            elseif ($_.Value -is [array]) { "-$($_.Key) $($_.Value -join ',')" }
            elseif ($_.Value) { "-$($_.Key) '$($_.Value)'" }
        }

        $script = if ($PSCommandPath) {
            "& '$PSCommandPath' $($argList -join ' ')"
        }
        else {
            "iex (irm https://magnetarman.com/WinToolkit) $($argList -join ' ')"
        }

        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
        return
    }

    # Logging
    $logDir = "$env:LOCALAPPDATA\WinToolkit\logs"
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
        '        Version 2.5.0 (Build 212)'
    ) | ForEach-Object { Write-Host (Center-Text -Text $_ -Width $width) -ForegroundColor White }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''

    Write-StyledMessage -Type Info -Text "PowerShell: $($PSVersionTable.PSVersion)"
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-StyledMessage -Type Warning -Text "PowerShell 7 raccomandato per funzionalità avanzate."
    }

    Write-StyledMessage -Type Info -Text "Avvio configurazione Win Toolkit..."

    # Installazioni
    $rebootNeeded = $false

    Install-WingetSilent
    Install-Git

    if (-not (Test-Path "$env:ProgramFiles\PowerShell\7")) {
        if (Install-PowerShell7) {
            $rebootNeeded = $true
        }
    }
    else {
        Write-StyledMessage -Type Success -Text "PowerShell 7 già presente."
    }

    # --- AUTO-RELAUNCH IN POWERSHELL 7 ---
    # Se siamo in una versione vecchia (< 7) e abbiamo installato/trovato PS 7, riavviamo lo script nel nuovo motore.
    if ($PSVersionTable.PSVersion.Major -lt 7 -and (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe")) {
        Write-StyledMessage -Type Info -Text "✨ Rilevata PowerShell 7. Upgrade dell'ambiente di esecuzione..."
        Start-Sleep 2

        # Ricostruisce i parametri passati allo script
        $argList = $PSBoundParameters.GetEnumerator() | ForEach-Object {
            if ($_.Value -is [switch] -and $_.Value) { "-$($_.Key)" }
            elseif ($_.Value -is [array]) { "-$($_.Key) $($_.Value -join ',')" }
            elseif ($_.Value) { "-$($_.Key) '$($_.Value)'" }
        }

        # Determina come rilanciare (file locale o blocco di script remoto)
        $script = if ($PSCommandPath) {
            "& '$PSCommandPath' $($argList -join ' ')"
        }
        else {
            "iex (irm https://magnetarman.com/WinToolkit) $($argList -join ' ')"
        }

        # Avvia pwsh.exe come Admin
        Start-Process "$env:ProgramFiles\PowerShell\7\pwsh.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs

        Write-StyledMessage -Type Success -Text "Script riavviato su PowerShell 7. Chiusura sessione legacy..."
        try { Stop-Transcript | Out-Null } catch { }
        exit
    }
    # -------------------------------------

    Install-WindowsTerminal

    # Nuova integrazione Setup PSP
    Install-PSPEnv

    New-ToolkitShortcut

    Write-StyledMessage -Type Success -Text "Configurazione completata."

    # Gestione riavvio
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

Start-WinToolkit
