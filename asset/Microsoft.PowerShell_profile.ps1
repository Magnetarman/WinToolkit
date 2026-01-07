<#
.SYNOPSIS
    Profilo PowerShell
.DESCRIPTION
    Profilo PowerShell personalizzato con funzioni e configurazioni organizzate.
.NOTES
    Versione: 2.5.0 - 07/01/2026
    Autore: MagnetarMan
#>

# =============================================================================
# AMBIENTE E CONFIGURAZIONE BASE
# =============================================================================

# Controllo Amministratore
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }

# Personalizzazione Prompt
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}

# Titolo finestra
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# =============================================================================
# FUNZIONI UTILITY
# =============================================================================

# Verifica esistenza comando
function Test-CommandExists {
    param($command)
    $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
}

# Ricarica profilo
function reload-profile {
    & $profile
}

# Estrazione file ZIP
function unzip {
    param($file)
    Write-Output "Estrazione $file in $pwd"
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}

# Cerca file ricorsivamente
function ff {
    param($name)
    Get-ChildItem -Recurse -Filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.directory)\$($_)"
    }
}

# Crea directory e naviga
function mkcd {
    param($dir)
    mkdir $dir -Force
    Set-Location $dir
}

# =============================================================================
# NAVIGAZIONE RAPIDA
# =============================================================================

function dtop { Set-Location -Path $HOME\Desktop }
function ep { zed $PROFILE }

# =============================================================================
# INFORMAZIONI DI SISTEMA
# =============================================================================

function sysinfo { Get-ComputerInfo }

function Get-PubIP { (Invoke-WebRequest https://am.i.mullvad.net/ip).Content }
function Get-Mainboard { Get-WMIObject -Class Win32_baseboard | Select-Object product, Manufacturer, version, serialnumber }
function Get-RAM { Get-WMIObject -Class Win32_Physicalmemory | Select-Object PSComputerName, PartNumber, Capacity, Speed, ConfiguredVoltage, DeviceLocator, Tag, SerialNumber }

# =============================================================================
# UTILITY DI RETE
# =============================================================================

function flushdns { Clear-DnsClientCache }

# =============================================================================
# Wintoolkit
# =============================================================================

function WinToolkit-Stable { Start-Process "https://magnetarman.com/WinToolkit" }
function WinToolkit-Dev { Start-Process "https://magnetarman.com/WinToolkit-Dev" }

# =============================================================================
# CONFIGURAZIONE EDITOR
# =============================================================================

$EDITOR = if (Test-CommandExists zed) { 'zed' }
elseif (Test-CommandExists code) { 'code' }
else { 'notepad' }
Set-Alias -Name zed -Value $EDITOR

function Edit-Profile {
    if ($EDITOR -eq 'zed') { zed $PROFILE.CurrentUserAllHosts }
    elseif ($EDITOR -eq 'code') { code $PROFILE.CurrentUserAllHosts }
    else { notepad $PROFILE.CurrentUserAllHosts }
}

# =============================================================================
# HELP E ALIAS PERSONALIZZATI
# =============================================================================

function Show-Help {
    $helpText = @"
$($PSStyle.Foreground.Cyan)Guida al Profilo PowerShell$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)===========================$($PSStyle.Reset)

$($PSStyle.Foreground.Cyan)Utility Generali$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)--------------------$($PSStyle.Reset) $($PSStyle.Foreground.Green)reload-profile$($PSStyle.Reset) - Ricarica il profilo PowerShell corrente. $($PSStyle.Foreground.Green)unzip$($PSStyle.Reset) - Estrae un file ZIP nella directory corrente. $($PSStyle.Foreground.Green)ff$($PSStyle.Reset) - Cerca file ricorsivamente in base a un nome parziale.

$($PSStyle.Foreground.Cyan)Navigazione File e Directory$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)----------------------------$($PSStyle.Reset) $($PSStyle.Foreground.Green)mkcd$($PSStyle.Reset) - Crea una nuova directory e ci si sposta. $($PSStyle.Foreground.Green)dtop$($PSStyle.Reset) - Naviga alla directory Desktop dell'utente. $($PSStyle.Foreground.Green)ep$($PSStyle.Reset) - Apre il file di profilo PowerShell corrente ($PROFILE).

$($PSStyle.Foreground.Cyan)Informazioni di Sistema$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)-----------------------$($PSStyle.Reset) $($PSStyle.Foreground.Green)sysinfo$($PSStyle.Reset) - Visualizza informazioni di sistema dettagliate. $($PSStyle.Foreground.Green)Get-PubIP$($PSStyle.Reset) - Recupera l'indirizzo IP pubblico della macchina. $($PSStyle.Foreground.Green)Get-Mainboard$($PSStyle.Reset) - Visualizza informazioni sulla scheda madre. $($PSStyle.Foreground.Green)Get-RAM$($PSStyle.Reset) - Visualizza informazioni sui moduli RAM installati.

$($PSStyle.Foreground.Cyan)Utility di Rete$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)---------------$($PSStyle.Reset) $($PSStyle.Foreground.Green)flushdns$($PSStyle.Reset) - Svuota la cache DNS.

$($PSStyle.Foreground.Cyan)WinToolkit$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)----------$($PSStyle.Reset) $($PSStyle.Foreground.Green)WinToolkit-Stable$($PSStyle.Reset) - Avvia il sito web di WinToolkit (versione stabile). $($PSStyle.Foreground.Green)WinToolkit-Dev$($PSStyle.Reset) - Avvia il sito web di WinToolkit (versione di sviluppo).

$($PSStyle.Foreground.Cyan)Configurazione Editor$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)-------------------$($PSStyle.Reset) $($PSStyle.Foreground.Green)Edit-Profile$($PSStyle.Reset) - Apre il file di profilo PowerShell utilizzando l'editor configurato (zed, code o notepad).

$($PSStyle.Foreground.Yellow)===========================$($PSStyle.Reset) Usa '$($PSStyle.Foreground.Magenta)help$($PSStyle.Reset)' per visualizzare questo messaggio di guida.
"@
    Write-Host $helpText
}

Set-Alias -Name help -Value Show-Help

# =============================================================================
# POWERSHELL ENHANCEMENTS
# =============================================================================

# Colori PSReadLine
Set-PSReadLineOption -Colors @{
    Command   = 'Yellow'
    Parameter = 'Green'
    String    = 'DarkCyan'
}

# =============================================================================
# INSTALLAZIONI E INIZIALIZZAZIONI
# =============================================================================

# Verifica aggiornamento PowerShell
try {
    Write-Host "Verifica degli aggiornamenti di PowerShell..." -ForegroundColor Cyan
    $updateNeeded = $false
    $currentVersion = $PSVersionTable.PSVersion.ToString()
    $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
    $latestVersion = $latestReleaseInfo.tag_name.Trim('v')
    if ($currentVersion -lt $latestVersion) { $updateNeeded = $true }

    if ($updateNeeded) {
        Write-Host "Aggiornamento di PowerShell in corso..." -ForegroundColor Yellow
        winget upgrade "Microsoft.PowerShell" --accept-source-agreements --accept-package-agreements
        Write-Host "PowerShell è stato aggiornato. Riavvia la shell per applicare le modifiche." -ForegroundColor Magenta
    }
    else {
        Write-Host "PowerShell è aggiornato." -ForegroundColor Green
    }
}
catch {
    Write-Error "Impossibile aggiornare PowerShell. Errore: $_"
}

# Oh My Posh
$ThemePath = "$env:USERPROFILE\Documents\PowerShell\Themes\atomic.omp.json"
if (-not (Test-Path $ThemePath)) {
    try {
        $null = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/atomic.omp.json" -OutFile $ThemePath -ErrorAction Stop
    }
    catch {
        Write-Warning "Impossibile scaricare il tema atomic.omp.json. Verrà utilizzato il tema predefinito."
    }
}
if (Test-Path $ThemePath) {
    oh-my-posh init pwsh --config $ThemePath | Invoke-Expression
}
else {
    oh-my-posh init pwsh --config "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/atomic.omp.json" | Invoke-Expression
}

# zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# fastfetch
fastfetch

# Messaggio di benvenuto
Write-Host "Digita 'help' per scoprire i comandi personalizzati." -ForegroundColor Yellow
