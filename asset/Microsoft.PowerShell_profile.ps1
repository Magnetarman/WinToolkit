<#
.SYNOPSIS
    Profilo PowerShell
.DESCRIPTION
    Profilo PowerShell con utility, navigazione rapida, informazioni di sistema e configurazioni.
.NOTES
    Versione: 2.5.0 - 08/01/2026
    Autore: MagnetarMan
#>

# ============================================================================
# AMBIENTE E CONFIGURAZIONE BASE
# ============================================================================

# Controllo Amministratore
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }

# Personalizzazione Prompt
function Set-Prompt {
    $promptChar = if ($isAdmin) { "#" } else { "$" }
    Write-Host "[$(Get-Location)] $promptChar " -NoNewline
}

# Titolo finestra
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# ============================================================================
# FUNZIONI UTILITY
# ============================================================================

function Test-CommandExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function ReloadProfile {
    & $PROFILE | Out-Null
}

function Expand-ZipFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$FilePath
    )
    Write-Host "📦 Estrazione $FilePath in $pwd..." -ForegroundColor Cyan
    $fullFile = Get-ChildItem -Path $pwd -Filter $FilePath | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd -Force | Out-Null
    Write-Host "✅ Estrazione completata" -ForegroundColor Green
}

function Find-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )
    Get-ChildItem -Recurse -Filter "*${Name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "$($_.directory)\$($_)" -ForegroundColor White
    }
}

function New-Mkcd {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Directory
    )
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    Set-Location -Path $Directory
}

# ============================================================================
# NAVIGAZIONE RAPIDA
# ============================================================================

function Set-LocationToDesktop {
    Set-Location -Path "$HOME\Desktop"
}

function EditProfile {
    EditPSProfile
}

# ============================================================================
# INFORMAZIONI DI SISTEMA
# ============================================================================

function Get-SystemInfo {
    Get-ComputerInfo | Out-Host
}

function Get-PublicIP {
    (Invoke-WebRequest -Uri "https://am.i.mullvad.net/ip" -UseBasicParsing).Content.Trim()
}

function Get-MainboardInfo {
    Get-CimInstance -ClassName Win32_baseboard | Select-Object Product, Manufacturer, Version, SerialNumber
}

function Get-RAMInfo {
    Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object PSComputerName, PartNumber, Capacity, Speed, ConfiguredVoltage, DeviceLocator, Tag, SerialNumber
}

# ============================================================================
# UTILITY DI RETE
# ============================================================================

function FlushDns {
    Clear-DnsClientCache | Out-Null
    Write-Host "✅ Cache DNS svuotata" -ForegroundColor Green
}

# ============================================================================
# SISTEMA
# ============================================================================

function WinToolkit-Stable {
    Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p `"PowerShell`" pwsh.exe -NoExit -ExecutionPolicy Bypass -Command `"irm https://magnetarman.com/WinToolkit | iex`"" -Verb RunAs
}

function WinToolkit-Dev {
    Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p `"PowerShell`" pwsh.exe -NoExit -ExecutionPolicy Bypass -Command `"irm https://magnetarman.com/WinToolkit-Dev | iex`"" -Verb RunAs
}

function doReboot {
    shutdown /r /f /t 0
}

function Shutdownfast {
    shutdown /s /f /t 0
}

function ShutdownComplete {
    shutdown /s /full /f /t 0
}

# ============================================================================
# CONFIGURAZIONE EDITOR CON FALLBACK
# ============================================================================

function Get-PreferredEditor {
    # Controlla Zed (percorsi comuni)
    $zedPaths = @(
        "$env:LOCALAPPDATA\Programs\Zed\Zed.exe",
        "$env:PROGRAMFILES\Zed\Zed.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Programs\Zed\Zed.exe"
    )

    foreach ($path in $zedPaths) {
        if (Test-Path $path) {
            return @{
                Name    = 'Zed'
                Path    = $path
                Command = $path
            }
        }
    }

    # Controlla se zed è nel PATH
    if (Test-CommandExists -Name "zed") {
        $zedCmd = Get-Command zed -ErrorAction SilentlyContinue
        return @{
            Name    = 'Zed'
            Path    = $zedCmd.Source
            Command = $zedCmd.Source
        }
    }

    # Fallback a VS Code
    if (Test-CommandExists -Name "code") {
        return @{
            Name    = 'Visual Studio Code'
            Path    = (Get-Command code).Source
            Command = 'code'
        }
    }

    # Fallback finale a Notepad
    return @{
        Name    = 'Notepad'
        Path    = 'notepad.exe'
        Command = 'notepad'
    }
}

# Ottieni l'editor preferito
$EDITOR_INFO = Get-PreferredEditor
$EDITOR = $EDITOR_INFO.Command

# Crea alias solo se non è notepad (già presente in Windows)
if ($EDITOR -ne 'notepad') {
    Set-Alias -Name edit -Value $EDITOR -Scope Global -ErrorAction SilentlyContinue
}

function EditPSProfile {
    [CmdletBinding()]
    param()

    try {
        switch ($EDITOR_INFO.Name) {
            'Zed' {
                if (Test-Path $EDITOR_INFO.Path) {
                    Start-Process -FilePath $EDITOR_INFO.Path -ArgumentList $PROFILE
                }
                else {
                    throw "Zed non trovato in: $($EDITOR_INFO.Path)"
                }
            }
            'Visual Studio Code' {
                & code $PROFILE
            }
            'Notepad' {
                & notepad $PROFILE
            }
        }
    }
    catch {
        Write-Host "⚠️ Errore nell'apertura con $($EDITOR_INFO.Name): $_" -ForegroundColor Yellow
        Write-Host "📝 Apertura con Notepad come fallback..." -ForegroundColor Cyan
        Start-Process notepad $PROFILE
    }
}

# ============================================================================
# HELP E ALIAS PERSONALIZZATI
# ============================================================================

function Show-Help {
    $helpText = @"
$($PSStyle.Foreground.Cyan)Guida al Profilo PowerShell$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)===========================$($PSStyle.Reset)

$($PSStyle.Foreground.Cyan)Utility Generali$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)--------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)ReloadProfile$($PSStyle.Reset)         - Ricarica il profilo PowerShell corrente
$($PSStyle.Foreground.Green)Expand-ZipFile$($PSStyle.Reset)        - Estrae un file ZIP nella directory corrente
$($PSStyle.Foreground.Green)Find-File$($PSStyle.Reset)             - Cerca file ricorsivamente per nome parziale
$($PSStyle.Foreground.Green)New-Mkcd$($PSStyle.Reset)              - Crea una directory e ci si sposta

$($PSStyle.Foreground.Cyan)Navigazione File e Directory$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)----------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Set-LocationToDesktop$($PSStyle.Reset) - Naviga alla directory Desktop
$($PSStyle.Foreground.Green)EditProfile$($PSStyle.Reset)           - Apre il profilo corrente nell'editor
$($PSStyle.Foreground.Green)EditPSProfile$($PSStyle.Reset)         - Apre il profilo PowerShell nell'editor

$($PSStyle.Foreground.Cyan)Informazioni di Sistema$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)-----------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Get-SystemInfo$($PSStyle.Reset)        - Visualizza informazioni di sistema dettagliate
$($PSStyle.Foreground.Green)Get-PublicIP$($PSStyle.Reset)          - Recupera l'indirizzo IP pubblico
$($PSStyle.Foreground.Green)Get-MainboardInfo$($PSStyle.Reset)     - Informazioni sulla scheda madre
$($PSStyle.Foreground.Green)Get-RAMInfo$($PSStyle.Reset)           - Informazioni sui moduli RAM installati

$($PSStyle.Foreground.Cyan)Utility di Rete$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)--------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)FlushDns$($PSStyle.Reset)              - Svuota la cache DNS

$($PSStyle.Foreground.Cyan)Sistema$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)-------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)WinToolkit-Stable$($PSStyle.Reset)     - Lancia WinToolkit (stabile)
$($PSStyle.Foreground.Green)WinToolkit-Dev$($PSStyle.Reset)        - Lancia WinToolkit (sviluppo)
$($PSStyle.Foreground.Green)doReboot$($PSStyle.Reset)              - Riavvia il sistema immediatamente
$($PSStyle.Foreground.Green)Shutdownfast$($PSStyle.Reset)          - Spegnimento rapido
$($PSStyle.Foreground.Green)ShutdownComplete$($PSStyle.Reset)      - Spegnimento completo (bypass Fast Startup)

$($PSStyle.Foreground.Cyan)Software Installati$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)-----------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)btop$($PSStyle.Reset)                  - Monitor delle risorse per il terminale

$($PSStyle.Foreground.Cyan)Editor Configurato$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)------------------$($PSStyle.Reset)
Editor corrente: $($PSStyle.Foreground.Magenta)$($EDITOR_INFO.Name)$($PSStyle.Reset)

$($PSStyle.Foreground.Yellow)===========================$($PSStyle.Reset)
Scrivi '$($PSStyle.Foreground.Magenta)help$($PSStyle.Reset)' per visualizzare questo messaggio.
"@
    Write-Host $helpText
}

Set-Alias -Name help -Value Show-Help

# ============================================================================
# POWERSHELL ENHANCEMENTS
# ============================================================================

Set-PSReadLineOption -Colors @{
    Command   = 'Yellow'
    Parameter = 'Green'
    String    = 'DarkCyan'
}

# ============================================================================
# INSTALLAZIONI E INIZIALIZZAZIONI
# ============================================================================

# Verifica aggiornamento PowerShell
try {
    Write-Host "🔍 Verifica degli aggiornamenti di PowerShell..." -ForegroundColor Cyan
    $updateNeeded = $false
    $currentVersion = $PSVersionTable.PSVersion.ToString()
    $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl -UseBasicParsing
    $latestVersion = $latestReleaseInfo.tag_name.Trim('v')

    if ($currentVersion -lt $latestVersion) {
        $updateNeeded = $true
    }

    if ($updateNeeded) {
        Write-Host "🔄 Aggiornamento di PowerShell in corso..." -ForegroundColor Yellow
        winget upgrade "Microsoft.PowerShell" --accept-source-agreements --accept-package-agreements | Out-Null
        Write-Host "✅ PowerShell aggiornato. Riavvia la shell per applicare le modifiche." -ForegroundColor Magenta
    }
    else {
        Write-Host "✅ PowerShell è aggiornato (v$currentVersion)" -ForegroundColor Green
    }
}
catch {
    Write-Host "❌ Impossibile verificare aggiornamenti PowerShell: $_" -ForegroundColor Red
}

# ============================================================================
# OH MY POSH
# ============================================================================

# Helper function for cross-edition compatibility
function Get-ProfileDir {
    if ($PSVersionTable.PSEdition -eq "Core") {
        return [Environment]::GetFolderPath("MyDocuments") + "\PowerShell"
    }
    elseif ($PSVersionTable.PSEdition -eq "Desktop") {
        return [Environment]::GetFolderPath("MyDocuments") + "\WindowsPowerShell"
    }
    else {
        Write-Error "Unsupported PowerShell edition: $($PSVersionTable.PSEdition)"
        return $null
    }
}

# Calcola il percorso del tema locale
$profileDir = Get-ProfileDir
$themeName = "atomic"
$localThemePath = Join-Path $profileDir "Themes\$themeName.omp.json"

# Download del tema se non esiste localmente
if (-not (Test-Path $localThemePath)) {
    $themeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
    try {
        Write-Host "⬇️ Download tema Oh My Posh..." -ForegroundColor Cyan
        $themesDir = Join-Path $profileDir "Themes"
        if (-not (Test-Path $themesDir)) {
            New-Item -ItemType Directory -Path $themesDir -Force | Out-Null
        }
        Invoke-WebRequest -Uri $themeUrl -OutFile $localThemePath -UseBasicParsing -ErrorAction Stop
        Write-Host "✅ Tema '$themeName' scaricato in: $localThemePath" -ForegroundColor Green
    }
    catch {
        Write-Warning "Impossibile scaricare il tema atomic.omp.json: $($_.Exception.Message)"
        $localThemePath = $null
    }
}

# Inizializza Oh My Posh
if (Test-Path $localThemePath) {
    oh-my-posh init pwsh --config $localThemePath | Invoke-Expression
}
else {
    $fallbackUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
    Write-Warning "Tema locale non disponibile. Uso fallback remoto."
    oh-my-posh init pwsh --config $fallbackUrl | Invoke-Expression
}

# zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# fastfetch
fastfetch

# Messaggio di benvenuto
Write-Host ""
Write-Host "💡 Digita 'help' per scoprire i comandi personalizzati." -ForegroundColor Yellow
