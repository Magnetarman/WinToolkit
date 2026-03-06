<#
.SYNOPSIS
    Script di inizio che installa e configura WinToolkit.
.DESCRIPTION
    Verifica, installa e configura alcuni software, per poi creare una scorciatoia di avvio di WinToolkit sul desktop.
.NOTES
    Compatibile con PowerShell 5.1+
#>

# ============================================================================
# CONFIGURAZIONE CENTRALIZZATA
# ============================================================================

$script:AppConfig = @{
    # ============================================================================
    # HEADER CONFIGURATION - Modifica qui per aggiornare titolo e versione
    # ============================================================================
    Header = @{
        Title   = "Toolkit Starter By MagnetarMan"
        Version = "Version 2.5.2 (Build 13)"
    }
    URLs   = @{
        StartScript             = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/start.ps1"
        WingetMSIX              = "https://aka.ms/getwinget"
        PowerShellRelease       = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        OhMyPoshTheme           = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
        PowerShellProfile       = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/Microsoft.PowerShell_profile.ps1"
        WindowsTerminalSettings = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/settings.json"
        ToolkitIcon             = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/img/WinToolkit.ico"
        TerminalRelease         = "https://api.github.com/repos/microsoft/terminal/releases/latest"
        WebInstaller            = "https://magnetarman.com/WinToolkit-Dev"
        LibBase                 = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/lib"
    }
    Paths  = @{
        Logs          = "$env:LOCALAPPDATA\WinToolkit\logs"
        WinToolkitDir = "$env:LOCALAPPDATA\WinToolkit"
        Temp          = "$env:TEMP\WinToolkitSetup"
        PowerShell7   = "$env:ProgramFiles\PowerShell\7"
        Packages      = "$env:LOCALAPPDATA\Packages"
        Desktop       = [Environment]::GetFolderPath('Desktop')
        wtExe         = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
        wtDir         = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    }
    Registry = @{
        TerminalStartup = "HKCU:\Console\%%Startup"
    }
}

# ============================================================================
# MODULAR LIBRARY LOADING & INITIALIZATION
# ============================================================================
function Initialize-WinToolkitLibrary {
    $localLibPath = Join-Path $script:AppConfig.Paths.WinToolkitDir "lib"
    if (-not (Test-Path $localLibPath)) { $null = New-Item -ItemType Directory -Path $localLibPath -Force }

    # Lista delle funzioni necessarie da scaricare se non presenti localmente
    $libFiles = @(
        "Add-ToEnvironmentPath.ps1",
        "Apply-WingetPathPermissions.ps1",
        "Find-WinGet.ps1",
        "Install-NuGetIfRequired.ps1",
        "Install-WingetCore.ps1",
        "Install-WingetPackage.ps1",
        "Invoke-ForceCloseWinget.ps1",
        "Repair-WingetDatabase.ps1",
        "Test-VCRedistInstalled.ps1",
        "Test-WingetCompatibility.ps1",
        "Test-WingetDeepValidation.ps1",
        "Test-WingetFunctionality.ps1"
    )

    foreach ($file in $libFiles) {
        $localFile = Join-Path $localLibPath $file
        if (-not (Test-Path $localFile)) {
            Write-StyledMessage -Type Info -Text "Download risorsa: $file..."
            $remoteUrl = "$($script:AppConfig.URLs.LibBase)/$file"
            try {
                Invoke-WebRequest -Uri $remoteUrl -OutFile $localFile -UseBasicParsing -ErrorAction Stop
            }
            catch {
                Write-StyledMessage -Type Warning -Text "Errore download $file: $($_.Exception.Message)"
            }
        }
        # Carica la funzione se il file esiste
        if (Test-Path $localFile) { . $localFile }
    }
}

# Avvio inizializzazione libreria
Initialize-WinToolkitLibrary

function Format-CenteredText {
    param(
        [string]$Text,
        [int]$Width = 80
    )
    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    return (" " * $padding) + $Text
}

function Show-Header {
    param(
        [string]$Title,
        [string]$Version
    )
    Clear-Host
    $width = 65
    Write-Host ('═' * $width) -ForegroundColor Green
    @(
        '      __        __  _   _   _ ',
        '      \ \      / / | | | \ | |',
        '       \ \ /\ / /  | | |  \| |',
        '        \ V  V /   | | | |\  |',
        '         \_/\_/    |_| |_| \_|',
        '',
        $Title,
        $Version
    ) | ForEach-Object { Write-Host (Format-CenteredText -Text $_ -Width $width) -ForegroundColor White }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''
}

function Write-StyledMessage {
    param(
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Type,
        [string]$Text
    )
    # FIX: Windows 11 Indentation Issue
    # Su W11 (Build >= 22000), forziamo il ritorno a capo (CR) prima di scrivere.
    if ([Environment]::OSVersion.Version.Build -ge 22000) {
        $Text = "`r$Text"
    }

    $colors = @{ Info = 'Cyan'; Warning = 'Yellow'; Error = 'Red'; Success = 'Green' }
    Write-Host $Text -ForegroundColor $colors[$Type]
}

function Stop-InterferingProcess {
    # Lista mirata dei processi che bloccano effettivamente l'installazione Appx
    $interferingProcesses = @(
        "WinStore.App",
        "wsappx",
        "AppInstaller",
        "Microsoft.WindowsStore",
        "Microsoft.DesktopAppInstaller",
        "winget",
        "WindowsPackageManagerServer"
    )

    foreach ($procName in $interferingProcesses) {
        $null = Get-Process -Name $procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep 2
}

function Update-EnvironmentPath {
    # Ricarica PATH da Machine e User per rilevare installazioni avvenute nel processo corrente
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'

    # Aggiorna la sessione PowerShell corrente
    $env:Path = $newPath
    # Forza il refresh a livello di processo per i componenti .NET avviati successivamente
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
}

function Invoke-WingetCommand {
    param(
        [string]$Arguments,
        [int]$TimeoutSeconds = 120
    )

    try {
        # Verifichiamo la versione di winget per retrocompatibilità
        # --disable-interactivity è supportato dalla versione 1.4+
        $versionRaw = (winget --version 2>$null) | Out-String
        $isModern = $versionRaw -match 'v1\.[4-9]' -or $versionRaw -match 'v[2-9]'

        # Aggiungiamo il flag solo se supportato (v1.4+)
        $finalArgs = if ($isModern) { "$Arguments --disable-interactivity" } else { $Arguments }

        $procParams = @{
            FilePath     = 'winget'
            ArgumentList = $finalArgs -split ' '
            Wait         = $true
            PassThru     = $true
            NoNewWindow  = $true
        }
        $process = Start-Process @procParams
        return @{ ExitCode = $process.ExitCode }
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Errore comando Winget: $($_.Exception.Message)"
        return @{ ExitCode = -1 }
    }
}

function Path-ExistsInEnvironment {
    param (
        [string]$PathToCheck,
        [string]$Scope = 'Both'
    )

    $pathExists = $false

    if ($Scope -eq 'User' -or $Scope -eq 'Both') {
        $userEnvPath = $env:PATH
        if (($userEnvPath -split ';').Contains($PathToCheck)) { $pathExists = $true }
    }

    if ($Scope -eq 'System' -or $Scope -eq 'Both') {
        $systemEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)
        if (($systemEnvPath -split ';').Contains($PathToCheck)) { $pathExists = $true }
    }

    return $pathExists
}

function Set-PathPermissions {
    <#
    .SYNOPSIS
    Grants full control permissions for the Administrators group on the specified directory path.
    #>
    param (
        [string]$FolderPath
    )

    if (-not (Test-Path $FolderPath)) { return }

    try {
        $administratorsGroupSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
        $administratorsGroup = $administratorsGroupSid.Translate([System.Security.Principal.NTAccount])
        $acl = Get-Acl -Path $FolderPath -ErrorAction Stop
        
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $administratorsGroup, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        
        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $FolderPath -AclObject $acl -ErrorAction Stop
        Write-StyledMessage -Type Info -Text "Permessi cartella aggiornati: $FolderPath"
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Impossibile impostare permessi: $($_.Exception.Message)"
    }
}

# Test-WingetCompatibility and Test-WingetFunctionality moved to lib/


# ============================================================================
# FUNZIONI DI RIPARAZIONE WINGET (Moved to lib/)
# ============================================================================


# ============================================================================
# FUNZIONI DI INSTALLAZIONE (Moved to lib/)
# ============================================================================

function Install-PowerShellCore {
    Write-StyledMessage -Type Info -Text "Verifica PowerShell 7..."

    $ps7Path = $script:AppConfig.Paths.PowerShell7
    if (Test-Path $ps7Path) {
        Write-StyledMessage -Type Success -Text "PowerShell 7 già installato."
        return $true
    }

    # 1. Tentativo via Winget (Prioritario)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Info -Text "Tentativo installazione PowerShell 7 via Winget..."
        $iwcParams = @{
            Arguments = "install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements --silent"
        }
        $result = Invoke-WingetCommand @iwcParams
        
        if ($result.ExitCode -eq 0) {
            Start-Sleep 3
            if (Test-Path $ps7Path) {
                Write-StyledMessage -Type Success -Text "PowerShell 7 installato via Winget."
                return $true
            }
        }
        Write-StyledMessage -Type Warning -Text "Installazione Winget fallita o non riuscita (ExitCode: $($result.ExitCode)). Fallback al download diretto..."
    }

    # 2. Fallback: download diretto MSI da GitHub
    try {
        Write-StyledMessage -Type Info -Text "Recupero ultima release PowerShell..."
        $release = Invoke-RestMethod -Uri $script:AppConfig.URLs.PowerShellRelease -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -like "*win-x64.msi" } | Select-Object -First 1

        if (-not $asset) {
            Write-StyledMessage -Type Error -Text "Asset PowerShell 7 win-x64.msi non trovato."
            return $false
        }

        $tempDir = $script:AppConfig.Paths.Temp
        if (-not (Test-Path $tempDir)) { 
            $niParams = @{
                Path     = $tempDir
                ItemType = 'Directory'
                Force    = $true
            }
            $null = New-Item @niParams *>$null 
        }
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
        $null = Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

        Start-Sleep 3

        if ((Test-Path $ps7Path) -or $process.ExitCode -eq 0) {
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

    if (Get-Command "wt.exe" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Success -Text "Windows Terminal è già installato."
        return $true
    }

    Write-StyledMessage -Type Info -Text "Installazione Windows Terminal in corso..."

    $downloadUrl = $null

    try {
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            Write-StyledMessage -Type Info -Text "Tentativo installazione Windows Terminal via winget..."
            $iwcParams = @{
                Arguments = "install --id 9N0DX20HK701 --source msstore --accept-source-agreements --accept-package-agreements --silent"
            }
            $result = Invoke-WingetCommand @iwcParams
            Start-Sleep 3
            if ($result.ExitCode -eq 0 -and (Get-Command "wt.exe" -ErrorAction SilentlyContinue)) {
                Write-StyledMessage -Type Success -Text "Windows Terminal installato via winget."
                return $true
            }
            else {
                Write-StyledMessage -Type Warning -Text "Installazione Winget per Windows Terminal non riuscita."
            }
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Installazione Winget per Windows Terminal fallita: $($_.Exception.Message)"
    }

    try {
        Write-StyledMessage -Type Info -Text "Recupero URL ultima release di Windows Terminal..."
        $latestRel = Invoke-RestMethod -Uri $script:AppConfig.URLs.TerminalRelease -UseBasicParsing
        $asset = $latestRel.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1

        if (-not $asset) {
            throw "Asset .msixbundle di Windows Terminal non trovato."
        }
        $downloadUrl = $asset.browser_download_url

        Write-StyledMessage -Type Info -Text "Provo installazione nativa Appx da bundle scaricato..."
        $tempFile = Join-Path $env:TEMP "WinTerminal.msixbundle"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing

        $apParams = @{
            Path                     = $tempFile
            ForceApplicationShutdown = $true
            ErrorAction              = 'Stop'
        }
        Add-AppxPackage @apParams
        $null = Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        Write-StyledMessage -Type Success -Text "Installazione Appx di Windows Terminal riuscita."
        return $true

    }
    catch {
        Write-StyledMessage -Type Warning -Text "Installazione Standard di Windows Terminal fallita: $($_.Exception.Message). Fallback al Microsoft Store."
    }

    if (-not (Get-Command "wt.exe" -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Info -Text "Fallback: Apertura Microsoft Store per Windows Terminal."
        Start-Process "ms-windows-store://pdp/?ProductId=9N0DX20HK701"
        Start-Sleep 5
        return $false
    }

    Write-StyledMessage -Type Error -Text "Impossibile installare Windows Terminal tramite qualsiasi metodo automatico."
    return $false
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
                Write-StyledMessage -Type Warning -Text "💡 Nota: i font via WinGet richiedono il riavvio del Terminale (o di Explorer) per essere visibili."
                return $true
            }
            else {
                Write-StyledMessage -Type Warning -Text "⚠️ WinGet ha restituito codice $($result.ExitCode). Il font potrebbe richiedere un riavvio del terminale."
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type Warning -Text "Errore durante l'installazione font: $($_.Exception.Message)"
            return $false
        }
    }

    function Get-ProfileDirLocal {
        if ($PSVersionTable.PSEdition -eq "Core") {
            return [Environment]::GetFolderPath("MyDocuments") + "\PowerShell"
        }
        else {
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
            Invoke-WingetCommand -Arguments "install -e --id $($tool.Id) --accept-source-agreements --accept-package-agreements --silent" *>$null
        }
    }

    # 2. Installazione Tema Oh My Posh
    $profileDir = Get-ProfileDirLocal
    if ($profileDir) {
        $themesFolder = Join-Path $profileDir "Themes"
        if (-not (Test-Path $themesFolder)) { New-Item -Path $themesFolder -ItemType Directory -Force *>$null }

        $themePath = Join-Path $themesFolder "atomic.omp.json"
        try {
            $iwrParams = @{
                Uri             = $script:AppConfig.URLs.OhMyPoshTheme
                OutFile         = $themePath
                UseBasicParsing = $true
            }
            Invoke-WebRequest @iwrParams
            Write-StyledMessage -Type Success -Text "Tema Oh My Posh scaricato."
        }
        catch {
            Write-StyledMessage -Type Warning -Text "Errore download tema: $($_.Exception.Message)"
        }
    }

    # 3. Installazione Font
    Install-NerdFontsLocal *>$null

    # 4. Configurazione Profilo
    if ($profileDir) {
        if (-not (Test-Path $profileDir)) { New-Item -Path $profileDir -ItemType Directory -Force *>$null }

        $targetProfile = $PROFILE
        if (-not $targetProfile) { $targetProfile = Join-Path $profileDir "Microsoft.PowerShell_profile.ps1" }

        try {
            if (Test-Path $targetProfile) {
                Move-Item -Path $targetProfile -Destination "$targetProfile.bak" -Force -ErrorAction SilentlyContinue
            }
            $iwrParams = @{
                Uri             = $script:AppConfig.URLs.PowerShellProfile
                OutFile         = $targetProfile
                UseBasicParsing = $true
            }
            Invoke-WebRequest @iwrParams
            Write-StyledMessage -Type Success -Text "Profilo PowerShell configurato."
        }
        catch {
            Write-StyledMessage -Type Warning -Text "Errore configurazione profilo: $($_.Exception.Message)"
        }
    }

    # 5. Configurazione Settings Windows Terminal
    try {
        $wtPath = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Directory -Filter "Microsoft.WindowsTerminal_*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($wtPath) {
            $settingsPath = Join-Path $wtPath.FullName "LocalState\settings.json"
            if (Test-Path (Join-Path $wtPath.FullName "LocalState")) {
                $iwrParams = @{
                    Uri             = $script:AppConfig.URLs.WindowsTerminalSettings
                    OutFile         = $settingsPath
                    UseBasicParsing = $true
                }
                Invoke-WebRequest @iwrParams
                Write-StyledMessage -Type Success -Text "Settings Windows Terminal aggiornati."
            }
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Errore aggiornamento settings terminal: $($_.Exception.Message)"
    }
}

function New-ToolkitDesktopShortcut {
    Write-StyledMessage -Type Info -Text "Creazione scorciatoia desktop..."

    try {
        $desktop = $script:AppConfig.Paths.Desktop
        $shortcut = Join-Path $desktop "Win Toolkit.lnk"
        $iconDir = $script:AppConfig.Paths.WinToolkitDir
        $icon = Join-Path $iconDir "WinToolkit.ico"

        if (-not (Test-Path $iconDir)) {
            $niParams = @{
                Path     = $iconDir
                ItemType = 'Directory'
                Force    = $true
            }
            $null = New-Item @niParams *>$null
        }

        if (-not (Test-Path $icon)) {
            Write-StyledMessage -Type Info -Text "Download icona..."
            $iwrParams = @{
                Uri             = $script:AppConfig.URLs.ToolkitIcon
                OutFile         = $icon
                UseBasicParsing = $true
            }
            Invoke-WebRequest @iwrParams
        }

        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcut)
        $link.TargetPath = $script:AppConfig.Paths.wtExe
        $link.Arguments = 'pwsh -ExecutionPolicy Bypass -Command "irm ' + $script:AppConfig.URLs.WebInstaller + ' | iex"'
        $link.WorkingDirectory = $script:AppConfig.Paths.wtDir
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

    $isResumeSetup = $env:WINTOOLKIT_RESUME -eq "1"

    $Host.UI.RawUI.WindowTitle = "Toolkit Starter by MagnetarMan"

    # FIX: Correzione Sintassi ForEach-Object e Join (Aggiunte parentesi)
    $argList = ($PSBoundParameters.GetEnumerator() | ForEach-Object {
            if ($_.Value -is [switch] -and $_.Value) { "-$($_.Key)" }
            elseif ($_.Value -is [array]) { "-$($_.Key) $($_.Value -join ',')" }
            elseif ($_.Value) { "-$($_.Key) '$($_.Value)'" }
        }) -join ' '

    $startUrl = $script:AppConfig.URLs.StartScript
    $scriptBlockForRelaunch = if ($PSCommandPath) {
        "& '$PSCommandPath' $argList"
    }
    else {
        "iex (irm '$startUrl') $argList"
    }

    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-StyledMessage -Type Info -Text "Riavvio con privilegi amministratore..."

        $procParams = @{
            FilePath     = 'powershell'
            ArgumentList = @( '-ExecutionPolicy', 'Bypass', '-NoProfile', '-Command', "`"$scriptBlockForRelaunch`"" )
            Verb         = 'RunAs'
        }
        Start-Process @procParams
        return
    }

    $logDir = $script:AppConfig.Paths.Logs
    try {
        if (-not (Test-Path $logDir)) {
            $niParams = @{
                Path     = $logDir
                ItemType = 'Directory'
                Force    = $true
            }
            $null = New-Item @niParams *>$null 
        }
        $null = Start-Transcript -Path "$logDir\WinToolkitStarter_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log" -Append -Force *>$null
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Errore avvio logging: $($_.Exception.Message)"
    }

    Show-Header -Title $script:AppConfig.Header.Title -Version $script:AppConfig.Header.Version

    Write-StyledMessage -Type Info -Text "PowerShell: $($PSVersionTable.PSVersion)"
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-StyledMessage -Type Warning -Text "PowerShell 7 raccomandato per funzionalità avanzate."
    }

    Write-StyledMessage -Type Info -Text "Avvio configurazione Win Toolkit..."

    $rebootNeeded = $false

    if (-not $isResumeSetup) {
        Write-StyledMessage -Type Info -Text "Esecuzione controlli base..."

        # Aggiorna PATH prima del check iniziale per rilevare winget già installato
        Update-EnvironmentPath

        if (-not (Test-WingetFunctionality)) {
            Write-StyledMessage -Type Warning -Text "⚠️ Winget non risponde. Tentativo di ripristino veloce (Core)..."

            $coreSuccess = Install-WingetCore

            # Aggiorna PATH dopo install-core prima di ri-testare
            Update-EnvironmentPath

            if ($coreSuccess -and (Test-WingetFunctionality)) {
                Write-StyledMessage -Type Success -Text "✅ Winget ripristinato velocemente."
            }
            else {
                Write-StyledMessage -Type Warning -Text "⚠️ Ripristino veloce fallito. Tentativo metodo avanzato (più lento)..."
                $null = Install-WingetPackage

                # Aggiorna PATH dopo install-package prima del check finale
                Update-EnvironmentPath

                if (-not (Test-WingetFunctionality)) {
                    Write-StyledMessage -Type Warning -Text "⚠️ Winget non funzionale dopo tutti i tentativi."
                    Write-StyledMessage -Type Info -Text "Lo script proseguirà, ma l'installazione di pacchetti potrebbe fallire."
                }
            }
        }
        else {
            Write-StyledMessage -Type Success -Text "✅ Winget è già operativo."
        }

        # Validazione profonda di Winget: verifica connettività ai repository e integrità del DB
        $wingetDeepCheck = Test-WingetDeepValidation

        if (-not $wingetDeepCheck) {
            Write-StyledMessage -Type Warning -Text "⚠️ Attenzione: l'installazione dei pacchetti successivi via Winget potrebbe fallire a causa di problemi di rete o del repository."
        }

        if (-not (Test-Path "$env:ProgramFiles\PowerShell\7")) {
            if (Install-PowerShellCore) {
                $null
            }
        }
        else {
            Write-StyledMessage -Type Success -Text "PowerShell 7 già presente."
        }
    }

    if ($PSVersionTable.PSVersion.Major -lt 7 -and (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe")) {
        Write-StyledMessage -Type Info -Text "✨ Rilevata PowerShell 7. Upgrade dell'ambiente di esecuzione..."
        Start-Sleep 2

        $env:WINTOOLKIT_RESUME = "1"

        $procParams = @{
            FilePath     = Join-Path $ps7Path "pwsh.exe"
            ArgumentList = @("-ExecutionPolicy", "Bypass", "-NoExit", "-Command", "`"$scriptBlockForRelaunch`"")
            Verb         = "RunAs"
        }
        Start-Process @procParams

        Write-StyledMessage -Type Success -Text "Script riavviato su PowerShell 7. Chiusura sessione legacy..."
        try { Stop-Transcript *>$null } catch { }
        exit
    }

    # Cattura il risultato dell'installazione Windows Terminal
    $wtInstalled = Install-WindowsTerminalApp

    # Imposta Windows Terminal come terminale predefinito se installato
    # Verifica assoluta che wt.exe risponda prima di modificare il registro
    $isWtExecutable = [bool](Get-Command 'wt.exe' -ErrorAction SilentlyContinue)
    if ($wtInstalled -and $isWtExecutable) {
        Write-StyledMessage -Type Info -Text "⚙️ Impostazione Windows Terminal come predefinito via Registry..."
        try {
            $registryPath = $script:AppConfig.Registry.TerminalStartup
            if (-not (Test-Path $registryPath)) {
                $null = New-Item -Path $registryPath -Force
            }

            # CLSID per Windows Terminal (Stable)
            $wtClsid = '{E12F0936-0E6F-548E-A9F6-B20C69A27D17}'
            # CLSID per l'host di delega (OpenConsole)
            $consoleHostClsid = '{B23D10C0-31E3-401A-97EF-4BB30B62E10B}'

            $sipParams1 = @{
                Path  = $registryPath
                Name  = 'DelegationTerminal'
                Value = $wtClsid
                Force = $true
            }
            $null = Set-ItemProperty @sipParams1

            $sipParams2 = @{
                Path  = $registryPath
                Name  = 'DelegationConsole'
                Value = $consoleHostClsid
                Force = $true
            }
            $null = Set-ItemProperty @sipParams2

            Write-StyledMessage -Type Success -Text "✅ Windows Terminal impostato come predefinito nel Registro."
        }
        catch {
            Write-StyledMessage -Type Warning -Text "⚠️ Impossibile impostare il terminale predefinito: $($_.Exception.Message)"
        }
    }
    elseif ($wtInstalled) {
        Write-StyledMessage -Type Warning -Text "⚠️ Terminale installato ma wt.exe non ancora disponibile nel PATH. Modifica registro saltata per sicurezza."
    }

    Install-PspEnvironment
    New-ToolkitDesktopShortcut

    Write-StyledMessage -Type Success -Text "Configurazione completata."

    # Se siamo già in modalità ripresa, evitiamo di entrare in loop tentando di riaprire terminali
    if ($isResumeSetup) {
        Write-StyledMessage -Type Info -Text "Installazione ripresa, sessione completata. Non tenterò un riavvio del terminale."
        try { Stop-Transcript *>$null } catch { }
        return
    }

    $wtExe = "wt.exe"
    $canLaunchWT = (Get-Command "wt.exe" -ErrorAction SilentlyContinue)

    # FIX: Check if we are already inside WT before trying to launch it
    # AND if we fail, do NOT restart script recursively
    if (-not ($env:WT_SESSION) -and $canLaunchWT) {
        Write-StyledMessage -Type Info -Text "Riavvio dello script in Windows Terminal..."

        $pwshPath = Join-Path $script:AppConfig.Paths.PowerShell7 "pwsh.exe"
        if (-not (Test-Path $pwshPath)) { $pwshPath = "powershell.exe" }

        # FIX: Aggiunto -d . per directory corrente e semplificato gli argomenti
        $wtArgs = "-w 0 new-tab -p `"PowerShell`" -d . `"$pwshPath`" -ExecutionPolicy Bypass -NoExit -Command `"$scriptBlockForRelaunch`""

        try {
            $procParams = @{
                FilePath     = $wtExe
                ArgumentList = $wtArgs
            }
            Start-Process @procParams
            Write-StyledMessage -Type Success -Text "Script riavviato in Windows Terminal. Chiusura sessione corrente..."
            try { Stop-Transcript *>$null } catch { }
            exit
        }
        catch {
            Write-StyledMessage -Type Error -Text "Errore durante l'avvio di Windows Terminal: $($_.Exception.Message)"
        }
    }

    # FIX: Loop Infinito risolto
    # Se il tentativo di avvio WT fallisce, lo script continua e termina QUI.
    # Non chiamiamo più Invoke-Expression (che causava il loop).
    if (-not ($env:WT_SESSION) -and -not $canLaunchWT) {
        Write-StyledMessage -Type Warning -Text "Impossibile avviare Windows Terminal o non trovato."
        Write-StyledMessage -Type Info -Text "L'installazione è stata comunque completata nella console corrente."
    }

    if ($rebootNeeded) {
        Write-StyledMessage -Type Warning -Text "Riavvio necessario per completare l'installazione."
        Write-StyledMessage -Type Info -Text "Riavvio automatico tra 10 secondi..."

        for ($i = 10; $i -gt 0; $i--) {
            Write-StyledMessage -Type Warning -Text "`rPreparazione riavvio - $i secondi..."
            Start-Sleep 1
        }

        try { Stop-Transcript *>$null } catch { }
        Restart-Computer -Force
    }
    else {
        Write-StyledMessage -Type Success -Text "WinToolkit è Pronto sul Desktop! 🚀"
        Start-Sleep 3
        try { Stop-Transcript *>$null } catch { }
        exit
    }
}

Invoke-WinToolkitSetup
