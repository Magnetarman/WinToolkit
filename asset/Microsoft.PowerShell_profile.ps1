<#
.SYNOPSIS
    Profilo PowerShell
.DESCRIPTION
    Profilo PowerShell con utility, navigazione rapida, informazioni di sistema e configurazioni.
.NOTES
    Versione: 2.5.0 - 07/01/2026
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

function Invoke-ReloadProfile {
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
    zed $PROFILE
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
# WINTOOLKIT
# ============================================================================

function WinToolkit-Stable {
    Start-Process -FilePath "pwsh.exe" -ArgumentList "-ExecutionPolicy Bypass -Command `"irm https://magnetarman.com/WinToolkit | iex`"" -Verb RunAs
}

function WinToolkit-Dev {
    Start-Process -FilePath "pwsh.exe" -ArgumentList "-ExecutionPolicy Bypass -Command `"irm https://magnetarman.com/WinToolkit-Dev | iex`"" -Verb RunAs
}

# ============================================================================
# CONFIGURAZIONE EDITOR
# ============================================================================

$EDITOR = if (Test-CommandExists -Name "zed") { 'zed' }
elseif (Test-CommandExists -Name "code") { 'code' }
else { 'notepad' }

Set-Alias -Name zed -Value $EDITOR -Scope Global

function Invoke-EditPowerShellProfile {
    if ($EDITOR -eq 'zed') {
        zed $PROFILE.CurrentUserAllHosts
    }
    elseif ($EDITOR -eq 'code') {
        code $PROFILE.CurrentUserAllHosts
    }
    else {
        notepad $PROFILE.CurrentUserAllHosts
    }
}

# ============================================================================
# HELP E ALIAS PERSONALIZZATI
# ============================================================================

function Show-Help {
    $helpText = @"
$($PSStyle.Foreground.Cyan)Guida al Profilo PowerShell$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)===========================$($PSStyle.Reset)

$($PSStyle.Foreground.Cyan)Utility Generali$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)--------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Invoke-ReloadProfile$($PSStyle.Reset) - Ricarica il profilo PowerShell corrente
$($PSStyle.Foreground.Green)Expand-ZipFile$($PSStyle.Reset)    - Estrae un file ZIP nella directory corrente
$($PSStyle.Foreground.Green)Find-File$($PSStyle.Reset)         - Cerca file ricorsivamente per nome parziale
$($PSStyle.Foreground.Green)New-Mkcd$($PSStyle.Reset)          - Crea una directory e ci si sposta

$($PSStyle.Foreground.Cyan)Navigazione File e Directory$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)----------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Set-LocationToDesktop$($PSStyle.Reset) - Naviga alla directory Desktop
$($PSStyle.Foreground.Green)EditProfile$($PSStyle.Reset)    - Apre il profilo corrente nell'editor

$($PSStyle.Foreground.Cyan)Informazioni di Sistema$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)-----------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Get-SystemInfo$($PSStyle.Reset)   - Visualizza informazioni di sistema dettagliate
$($PSStyle.Foreground.Green)Get-PublicIP$($PSStyle.Reset)     - Recupera l'indirizzo IP pubblico
$($PSStyle.Foreground.Green)Get-MainboardInfo$($PSStyle.Reset) - Informazioni sulla scheda madre
$($PSStyle.Foreground.Green)Get-RAMInfo$($PSStyle.Reset)      - Informazioni sui moduli RAM installati

$($PSStyle.Foreground.Cyan)Utility di Rete$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)---------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)FlushDns$($PSStyle.Reset)  - Svuota la cache DNS

$($PSStyle.Foreground.Cyan)WinToolkit$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)----------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)WinToolkit-Stable$($PSStyle.Reset) - Lancia WinToolkit (stabile)
$($PSStyle.Foreground.Green)WinToolkit-Dev$($PSStyle.Reset)    - Lancia WinToolkit (sviluppo)

$($PSStyle.Foreground.Cyan)Software Installati$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)-----------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)btop$($PSStyle.Reset)               - btop è un monitor delle risorse per il terminale.

$($PSStyle.Foreground.Cyan)Configurazione Editor$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)-------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Invoke-EditPowerShellProfile$($PSStyle.Reset) - Modifica il profilo PowerShell

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

# Oh My Posh
$ThemePath = "$env:USERPROFILE\Documents\PowerShell\Themes\atomic.omp.json"
if (-not (Test-Path $ThemePath)) {
    try {
        $null = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json" -OutFile $ThemePath -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Host "⚠️ Impossibile scaricare il tema atomic.omp.json" -ForegroundColor Yellow
    }
}

if (Test-Path $ThemePath) {
    oh-my-posh init pwsh --config $ThemePath | Invoke-Expression
}
else {
    oh-my-posh init pwsh --config "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json" | Invoke-Expression
}

# zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# fastfetch
fastfetch

# Messaggio di benvenuto
Write-Host ""
Write-Host "💡 Digita 'help' per scoprire i comandi personalizzati." -ForegroundColor Yellow
