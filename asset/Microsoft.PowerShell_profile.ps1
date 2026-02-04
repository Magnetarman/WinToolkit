<#
.SYNOPSIS
    Profilo PowerShell

.DESCRIPTION
    Profilo PowerShell con utility, navigazione rapida, informazioni di sistema e configurazioni.

.NOTES
    Versione: 2.5.1 - 04/02/2026
    Autore: MagnetarMan
#>

# ============================================================================
# AMBIENTE E CONFIGURAZIONE BASE
# ============================================================================

# Controllo Amministratore
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }

# Personalizzazione Prompt
function prompt {
    $promptChar = if ($isAdmin) { "#" } else { "$" }
    Write-Host "[$(Get-Location)] $promptChar " -NoNewline
    return ""
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
        [string]$FilePath,
        [string]$DestinationPath = $pwd
    )
    Write-Host "📦 Estrazione $FilePath in $DestinationPath..." -ForegroundColor Cyan

    $fullFilePath = Resolve-Path $FilePath | Select-Object -ExpandProperty Path

    if (-not (Test-Path $fullFilePath)) {
        Write-Host "❌ File ZIP non trovato: '$FilePath'" -ForegroundColor Red
        return
    }

    try {
        Expand-Archive -Path $fullFilePath -DestinationPath $DestinationPath -Force | Out-Null
        Write-Host "✅ Estrazione completata" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Errore durante l'estrazione: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Find-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )
    Get-ChildItem -Recurse -Filter "*${Name}*" -ErrorAction SilentlyContinue | Select-Object FullName
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

function Speedtest {
    [CmdletBinding()]
    param()

    $assetDir = Join-Path $env:LOCALAPPDATA "WinToolkit\asset"
    $speedtestExePath = Join-Path $assetDir "speedtest.exe"
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $timestamp = Get-Date -Format "dd_MM_yyyy_HH_mm_ss"
    $outputPath = Join-Path $desktopPath "Speedtest_$timestamp.txt"

    if (-not (Test-Path $assetDir)) {
        Write-Host "📦 Creazione directory asset: $assetDir" -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $assetDir -Force | Out-Null
    }

    if (-not (Test-Path $speedtestExePath)) {
        Write-Host "🔍 speedtest.exe non trovato in '$assetDir'." -ForegroundColor Cyan
        Write-Host "⬇️ Download di speedtest.exe in corso da GitHub..." -ForegroundColor Yellow
        try {
            $downloadParams = @{
                Uri             = "https://github.com/Magnetarman/WinToolkit/raw/refs/heads/Dev/asset/speedtest.exe"
                OutFile         = $speedtestExePath
                UseBasicParsing = $true
                ErrorAction     = 'Stop'
            }
            Invoke-WebRequest @downloadParams
            Write-Host "✅ speedtest.exe scaricato con successo." -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Errore durante il download di speedtest.exe: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    }

    Write-Host "🚀 Avvio Speedtest..." -ForegroundColor Yellow
    Write-Host "📝 I risultati (inclusi i progressi) verranno salvati in '$outputPath'." -ForegroundColor Yellow

    try {
        & $speedtestExePath --accept-license --accept-gdpr -p *>&1 | Tee-Object -FilePath $outputPath
        Write-Host "✅ Speedtest completato e risultati salvati." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Errore durante l'esecuzione di speedtest.exe: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        Write-Host "♻️ Ricaricamento profilo PowerShell..." -ForegroundColor Cyan
        ReloadProfile
    }
}

function Reset-Network {
    [CmdletBinding()]
    param()

    # Controllo Amministratore
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "❌ Questa operazione richiede privilegi di Amministratore" -ForegroundColor Red
        Write-Host "ℹ️ Riavvia PowerShell come Amministratore per eseguire Reset-Network" -ForegroundColor Cyan
        return
    }

    Write-Host "⚠️ Attenzione: Questa operazione ripristinerà tutte le impostazioni di rete" -ForegroundColor Yellow
    Write-Host "ℹ️ Questo include catalogo Winsock, proxy WinHTTP e configurazioni IP" -ForegroundColor Cyan
    Write-Host "⚠️ La connessione di rete potrebbe essere interrotta" -ForegroundColor Yellow

    $confirmation = Read-Host "❓ Vuoi procedere con il ripristino? (S/N)"
    if ($confirmation -notmatch "^[Ss]$") {
        Write-Host "ℹ️ Operazione annullata" -ForegroundColor Cyan
        return
    }

    Write-Host "`n🚀 Avvio ripristino impostazioni di rete..." -ForegroundColor Cyan

    # Reset WinSock catalog to a clean state
    try {
        Write-Host "🔄 Ripristino catalogo Winsock..." -ForegroundColor Cyan
        $processInfo = Start-Process -FilePath "netsh" -ArgumentList "winsock", "reset" -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($processInfo.ExitCode -ne 0) { throw "Exit code: $($processInfo.ExitCode)" }
        Write-Host "✅ Catalogo Winsock ripristinato" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Errore ripristino Winsock: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Resets WinHTTP proxy setting to DIRECT
    try {
        Write-Host "🔄 Ripristino impostazioni proxy WinHTTP..." -ForegroundColor Cyan
        $processInfo = Start-Process -FilePath "netsh" -ArgumentList "winhttp", "reset", "proxy" -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($processInfo.ExitCode -ne 0) { throw "Exit code: $($processInfo.ExitCode)" }
        Write-Host "✅ Impostazioni proxy WinHTTP ripristinate" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Errore ripristino proxy WinHTTP: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Removes all user configured IP settings
    try {
        Write-Host "🔄 Ripristino configurazioni IP..." -ForegroundColor Cyan
        $processInfo = Start-Process -FilePath "netsh" -ArgumentList "int", "ip", "reset" -NoNewWindow -Wait -PassThru -ErrorAction Stop
        
        if ($processInfo.ExitCode -eq 0) {
            Write-Host "✅ Configurazioni IP ripristinate" -ForegroundColor Green
        }
        elseif ($processInfo.ExitCode -eq 1) {
            Write-Host "✅ Configurazioni IP ripristinate (con avvisi minori)" -ForegroundColor Green
        }
        else {
            throw "Exit code: $($processInfo.ExitCode)"
        }
    }
    catch {
        Write-Host "❌ Errore ripristino configurazioni IP: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host "`n✅ Ripristino rete completato" -ForegroundColor Green
    Write-Host "⚠️ Riavvia il computer per applicare le modifiche" -ForegroundColor Yellow
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
    if (Test-CommandExists -Name "zed") {
        $zedCmd = Get-Command zed -ErrorAction SilentlyContinue
        return @{
            Name    = 'Zed'
            Path    = $zedCmd.Source
            Command = $zedCmd.Source
        }
    }

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

    if (Test-CommandExists -Name "code") {
        return @{
            Name    = 'Visual Studio Code'
            Path    = (Get-Command code).Source
            Command = 'code'
        }
    }

    return @{
        Name    = 'Notepad'
        Path    = 'notepad.exe'
        Command = 'notepad'
    }
}

$EDITOR_INFO = Get-PreferredEditor
$EDITOR = $EDITOR_INFO.Command

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
$($PSStyle.Foreground.Green)EditPSProfile$($PSStyle.Reset)         - Apre il profilo PowerShell nell'editor

$($PSStyle.Foreground.Cyan)Informazioni di Sistema$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)-----------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Get-SystemInfo$($PSStyle.Reset)        - Visualizza informazioni di sistema dettagliate
$($PSStyle.Foreground.Green)Get-PublicIP$($PSStyle.Reset)          - Recupera l'indirizzo IP pubblico
$($PSStyle.Foreground.Green)Get-MainboardInfo$($PSStyle.Reset)     - Informazioni sulla scheda madre
$($PSStyle.Foreground.Green)Get-RAMInfo$($PSStyle.Reset)           - Informazioni sui moduli RAM installati

$($PSStyle.Foreground.Cyan)Utility di Rete$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)--------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)FlushDns$($PSStyle.Reset)              - Svuota la cache DNS
$($PSStyle.Foreground.Green)Speedtest$($PSStyle.Reset)             - Esegue un test della velocità di rete (download automatico di speedtest.exe)
$($PSStyle.Foreground.Green)Reset-Network$($PSStyle.Reset)         - Ripristina le impostazioni di rete a quelle predefinite

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

    [version]$currentPSVersion = $PSVersionTable.PSVersion
    $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl -UseBasicParsing
    [version]$latestPSVersion = $latestReleaseInfo.tag_name.Trim('v')

    if ($currentPSVersion -lt $latestPSVersion) {
        $updateNeeded = $true
    }

    if ($updateNeeded) {
        if (-not $isAdmin) {
            Write-Host "⚠️ Per aggiornare PowerShell è necessario eseguire la shell come Amministratore." -ForegroundColor DarkYellow
            return
        }
        Write-Host "🔄 Aggiornamento di PowerShell in corso (da v$currentPSVersion a v$latestPSVersion)..." -ForegroundColor Yellow
        winget upgrade "Microsoft.PowerShell" --accept-source-agreements --accept-package-agreements | Out-Null
        Write-Host "✅ PowerShell aggiornato. Riavvia la shell per applicare le modifiche." -ForegroundColor Magenta
    }
    else {
        Write-Host "✅ PowerShell è aggiornato (v$currentPSVersion)" -ForegroundColor Green
    }
}
catch {
    Write-Host "❌ Impossibile verificare o aggiornare PowerShell: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Message -like "*winget*") {
        Write-Host "Suggerimento: Assicurati che 'winget' sia installato." -ForegroundColor DarkYellow
    }
}

# Oh My Posh
function Get-ProfileDir {
    return Split-Path -Parent $PROFILE
}

$profileDir = Get-ProfileDir
$themeName = "atomic"
$localThemePath = Join-Path $profileDir "Themes\$themeName.omp.json"

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

Write-Host ""
Write-Host "💡 Digita 'help' per scoprire i comandi personalizzati." -ForegroundColor Yellow
