<#
.SYNOPSIS
    Profilo PowerShell
.DESCRIPTION
    Profilo PowerShell personalizzato.
.NOTES
    Versione: 2.5.0 - 07/01/2026
    Autore: MagnetarMan
#>


try {
    Write-Host "Verifica degli aggiornamenti di PowerShell..." -ForegroundColor Cyan
    $updateNeeded = $false
    $currentVersion = $PSVersionTable.PSVersion.ToString()
    $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
    $latestVersion = $latestReleaseInfo.tag_name.Trim('v')
    if ($currentVersion -lt $latestVersion) {
        $updateNeeded = $true
    }

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


# Controllo Amministratore e Personalizzazione Prompt
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# Funzioni Utility
function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

# Configurazione Editor
$EDITOR = if (Test-CommandExists zed) { 'zed' }
elseif (Test-CommandExists code) { 'code' }
else { 'notepad' }
Set-Alias -Name zed -Value $EDITOR

function Edit-Profile {
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

function ff($name) {
    Get-ChildItem -Recurse -Filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.directory)\$($_)"
    }
}

# Utility di Rete
function Get-PubIP { (Invoke-WebRequest https://am.i.mullvad.net/ip).Content }
function Get-Mainboard { Get-WMIObject -class Win32_baseboard | select product, Manufacturer, version, serialnumber }
function Get-RAM { Get-WMIObject -class Win32_Physicalmemory | select PSComputerName, PartNumber, Capacity, Speed, ConfiguredVoltage, DeviceLocator, Tag, SerialNumber }

function reload-profile {
    & $profile
}

function unzip ($file) {
    Write-Output "Estrazione" $file "in" $pwd
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}

# Gestione Directory
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

# Scorciatoie di Navigazione
function dtop { Set-Location -Path $HOME\Desktop }

# Accesso Rapido alla Modifica del Profilo
function ep { zed $PROFILE }

# Accesso Rapido alle Informazioni di Sistema
function sysinfo { Get-ComputerInfo }

# Utility di Rete
function flushdns { Clear-DnsClientCache }

# Esperienza PowerShell Migliorata
Set-PSReadLineOption -Colors @{
    Command   = 'Yellow'
    Parameter = 'Green'
    String    = 'DarkCyan'
}

# Inizializzazione Oh My Posh
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

# Inizializzazione zoxide
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
else {
    Write-Host "Comando zoxide non trovato. Tentativo di installazione tramite winget..."
    try {
        winget install -e --id ajeetdsouza.zoxide
        Write-Host "zoxide installato con successo. Inizializzazione..."
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    }
    catch {
        Write-Error "Impossibile installare zoxide. Errore: $_"
    }
}

# Funzioni WinToolkit
function WinToolkit-Stable {
    Start-Process "https://magnetarman.com/WinToolkit"
}

function WinToolkit-Dev {
    Start-Process "https://magnetarman.com/WinToolkit-Dev"
}

# Inizializzazione fastfetch
fastfetch
