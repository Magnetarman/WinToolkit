<#
.SYNOPSIS
    Profilo PowerShell

.DESCRIPTION
    Profilo PowerShell con utility, navigazione rapida, informazioni di sistema e configurazioni.

.NOTES
    Autore: MagnetarMan
#>

# ============================================================================
# CONFIGURAZIONE CENTRALIZZATA (URL)
# ============================================================================

$ProfileVersion = "2.5.4.2"

$URL_SPEEDTEST = "https://github.com/Magnetarman/WinToolkit/raw/refs/heads/Dev/asset/speedtest.exe"
$URL_WINTOOLKIT_STABLE = "https://magnetarman.com/WinToolkit"
$URL_WINTOOLKIT_DEV = "https://magnetarman.com/WinToolkit-Dev"
$URL_WINREG = "https://get.activated.win"
$URL_RustDesk_Setup = "https://raw.githubusercontent.com/Magnetarman/WinStarter/refs/heads/main/Asset/RustDesk/SetRustDesk.ps1"
$URL_OHMYPOSH_THEME = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
$URL_PROFILE = "https://github.com/Magnetarman/WinToolkit/raw/refs/heads/Dev/asset/Microsoft.PowerShell_profile.ps1"
$URL_IP_API = "https://am.i.mullvad.net/ip"
$URL_WINTOOLKIT_ICO_MAIN = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/img/WinToolkit.ico"
$URL_WINTOOLKIT_ICO_DEV = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/img/WinToolkit-Dev.ico"
$URL_PROFILE_MAIN = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/main/asset/Microsoft.PowerShell_profile.ps1"
$URL_PWSH_RELEASE_API = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"

# ============================================================================
# FUNZIONI HELPER GLOBALI
# ============================================================================

function Assert-Admin {
    [CmdletBinding()]
    param()

    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================================
# AMBIENTE E CONFIGURAZIONE BASE
# ============================================================================

# Controllo Amministratore
$isAdmin = Assert-Admin

# Personalizzazione Prompt

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
    Set-Location -Path (Join-Path $HOME "Desktop")
}

# ============================================================================
# INFORMAZIONI DI SISTEMA
# ============================================================================

function Get-SystemInfo {
    Get-ComputerInfo | Out-Host
}

function Get-PublicIP {
    (Invoke-WebRequest -Uri $URL_IP_API -UseBasicParsing).Content.Trim()
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
                Uri             = $URL_SPEEDTEST
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

}

function Reset-Network {
    [CmdletBinding()]
    param()

    # Controllo Amministratore
    if (-not (Assert-Admin)) {
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

    # Ripristina lo stato pulito del catalogo WinSock
    try {
        Write-Host "🔄 Ripristino catalogo Winsock..." -ForegroundColor Cyan
        $processInfo = Start-Process -FilePath "netsh" -ArgumentList "winsock", "reset" -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($processInfo.ExitCode -ne 0) { throw "Exit code: $($processInfo.ExitCode)" }
        Write-Host "✅ Catalogo Winsock ripristinato" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Errore ripristino Winsock: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Reimposta le impostazioni proxy WinHTTP su DIRECT
    try {
        Write-Host "🔄 Ripristino impostazioni proxy WinHTTP..." -ForegroundColor Cyan
        $processInfo = Start-Process -FilePath "netsh" -ArgumentList "winhttp", "reset", "proxy" -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($processInfo.ExitCode -ne 0) { throw "Exit code: $($processInfo.ExitCode)" }
        Write-Host "✅ Impostazioni proxy WinHTTP ripristinate" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Errore ripristino proxy WinHTTP: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Rimuove tutte le configurazioni IP definite dall'utente
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
# AGGIORNAMENTO PROFILO
# ============================================================================

function PSProfileUpdate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $localProfilePath = $PROFILE
    $remoteProfileUrl = $URL_PROFILE

    Write-Host "🔍 Verifica aggiornamenti per il profilo PowerShell..." -ForegroundColor Cyan

    try {
        # Controlla la versione locale dalla variabile caricata in sessione
        $localVersion = $null
        if ($null -ne $ProfileVersion) {
            $localVersion = [version]$ProfileVersion
        }
        else {
            throw "Variabile `$ProfileVersion non trovata o sconosciuta nel profilo locale."
        }

        # Recupera il contenuto remoto per estrarne la versione
        $remoteContent = (Invoke-WebRequest -Uri $remoteProfileUrl -UseBasicParsing -ErrorAction Stop).Content
        $match = [regex]::Match($remoteContent, '(?i)\$ProfileVersion\s*=\s*[''"]([^''"]+)[''"]')

        if (-not $match.Success) {
            throw "Impossibile determinare la versione remota dal file scaricato."
        }
        $remoteVersion = [version]$match.Groups[1].Value

        if ($localVersion -ge $remoteVersion) {
            Write-Host "✅ Il profilo è aggiornato all'ultima versione: $localVersion" -ForegroundColor Green
            return
        }

        Write-Host "⚠️ È disponibile una versione aggiornata! (Locale: $localVersion -> Remota: $remoteVersion)" -ForegroundColor Yellow
        Write-Host "🔄 Aggiornamento in corso..." -ForegroundColor Cyan

        Invoke-WebRequest -Uri $remoteProfileUrl -OutFile $localProfilePath -UseBasicParsing -ErrorAction Stop
        Write-Host "✅ Profilo scaricato e sostituito con successo. Riavvia la sessione per applicare le modifiche." -ForegroundColor Green

    }
    catch {
        Write-Host "⚠️ Rilevato problema: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "🔄 Forzatura: Scaricamento e sovrascrittura del profilo remoto per eliminare i problemi..." -ForegroundColor Cyan

        try {
            Invoke-WebRequest -Uri $remoteProfileUrl -OutFile $localProfilePath -UseBasicParsing -ErrorAction Stop
            Write-Host "✅ Profilo forzatamente ripristinato dalla versione remota. Riavvia PowerShell." -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Errore critico: Impossibile scaricare il profilo dal link remoto. Controlla la rete." -ForegroundColor Red
        }
    }
}

# ============================================================================
# SISTEMA
# ============================================================================

function WinToolkit-Stable {
    Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p `"PowerShell`" pwsh.exe -NoExit -ExecutionPolicy Bypass -Command `"irm $URL_WINTOOLKIT_STABLE | iex`"" -Verb RunAs
}

function SetRustDesk {
    [CmdletBinding()]
    param()

    Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p `"PowerShell`" pwsh.exe -NoExit -ExecutionPolicy Bypass -Command `"irm $URL_RustDesk_Setup | iex`"" -Verb RunAs

    Write-Host "🔍 Avvio configurazione RustDesk..." -ForegroundColor Cyan

}

function WinReg {
    [CmdletBinding()]
    param()

    Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p `"PowerShell`" pwsh.exe -NoExit -ExecutionPolicy Bypass -Command `"irm $URL_WINREG | iex`"" -Verb RunAs
}

function WinToolkit-Dev {
    Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p `"PowerShell`" pwsh.exe -NoExit -ExecutionPolicy Bypass -Command `"irm $URL_WINTOOLKIT_DEV | iex`"" -Verb RunAs
}

function WinToolkit-GUI {
    Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p `"PowerShell`" pwsh.exe -NoExit -ExecutionPolicy Bypass -Command `"irm https://magnetarman.com/Wintoolkit-gui | iex`"" -Verb RunAs
}

function SetBranch-Dev {
    [CmdletBinding()]
    param()

    Write-Host "`n🔄 Avvio procedura di switch di WinToolkit al ramo Dev..." -ForegroundColor Cyan

    # 1. Ricreazione Scorciatoia Desktop
    try {
        Write-Host "📦 Ricreazione scorciatoia desktop..." -ForegroundColor Cyan
        $desktop = [Environment]::GetFolderPath('Desktop')
        $shortcut = Join-Path $desktop "Win Toolkit.lnk"
        $iconDir = Join-Path $env:LOCALAPPDATA "WinToolkit"
        $icon = Join-Path $iconDir "WinToolkit-Dev.ico"

        if (-not (Test-Path $iconDir)) {
            New-Item -Path $iconDir -ItemType Directory -Force | Out-Null
        }

        # Scarica/Sovrascrive l'icona dal ramo dev
        Invoke-WebRequest -Uri $URL_WINTOOLKIT_ICO_DEV -OutFile $icon -UseBasicParsing

        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcut)
        $link.TargetPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\wt.exe"
        $link.Arguments = 'pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm ' + 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/WinToolkit.ps1' + ' | iex"'
        $link.WorkingDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
        $link.IconLocation = $icon
        $link.Description = "Win Toolkit - SOPRAVVIVI A Windows"
        $link.Save()

        # Abilita esecuzione come amministratore modificando i byte del file .lnk
        $bytes = [IO.File]::ReadAllBytes($shortcut)
        $bytes[21] = $bytes[21] -bor 32
        [IO.File]::WriteAllBytes($shortcut, $bytes)

        Write-Host "✅ Scorciatoia desktop aggiornata al ramo dev." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Errore creazione scorciatoia: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 2. Sostituzione Profilo PowerShell
    try {
        Write-Host "⬇️ Download del profilo PowerShell dal ramo dev..." -ForegroundColor Cyan

        # Sovrascrive il profilo senza chiedere conferma
        Invoke-WebRequest -Uri $URL_PROFILE -OutFile $PROFILE -UseBasicParsing
        Write-Host "✅ Profilo PowerShell sovrascritto con la versione dev." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Errore aggiornamento profilo: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 3. Avviso all'utente
    Write-Host "`n🎉 Switch al ramo Dev completato con successo! Modifiche effettuate:" -ForegroundColor Green
    Write-Host "  - Icona desktop 'Win Toolkit' rigenerata e puntata al ramo dev." -ForegroundColor Yellow
    Write-Host "  - Profilo PowerShell sostituito con la versione del ramo dev." -ForegroundColor Yellow
    Write-Host "`n⚠️  ATTENZIONE: Riavvia il terminale per applicare le modifiche del nuovo profilo." -ForegroundColor Magenta
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

function SetBranch-Main {
    [CmdletBinding()]
    param()

    Write-Host "`n🔄 Avvio procedura di switch di WinToolkit al ramo Main..." -ForegroundColor Cyan

    # 1. Ricreazione Scorciatoia Desktop
    try {
        Write-Host "📦 Ricreazione scorciatoia desktop..." -ForegroundColor Cyan
        $desktop = [Environment]::GetFolderPath('Desktop')
        $shortcut = Join-Path $desktop "Win Toolkit.lnk"
        $iconDir = Join-Path $env:LOCALAPPDATA "WinToolkit"
        $icon = Join-Path $iconDir "WinToolkit.ico"

        if (-not (Test-Path $iconDir)) {
            New-Item -Path $iconDir -ItemType Directory -Force | Out-Null
        }

        # Scarica/Sovrascrive l'icona dal ramo main
        Invoke-WebRequest -Uri $URL_WINTOOLKIT_ICO_MAIN -OutFile $icon -UseBasicParsing

        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcut)
        $link.TargetPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\wt.exe"
        $link.Arguments = 'pwsh -ExecutionPolicy Bypass -Command "irm ' + $URL_WINTOOLKIT_STABLE + ' | iex"'
        $link.WorkingDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
        $link.IconLocation = $icon
        $link.Description = "Win Toolkit - SOPRAVVIVI A Windows"
        $link.Save()

        # Abilita esecuzione come amministratore modificando i byte del file .lnk
        $bytes = [IO.File]::ReadAllBytes($shortcut)
        $bytes[21] = $bytes[21] -bor 32
        [IO.File]::WriteAllBytes($shortcut, $bytes)

        Write-Host "✅ Scorciatoia desktop aggiornata al ramo main." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Errore creazione scorciatoia: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 2. Sostituzione Profilo PowerShell
    try {
        Write-Host "⬇️ Download del profilo PowerShell dal ramo main..." -ForegroundColor Cyan

        # Sovrascrive il profilo senza chiedere conferma
        Invoke-WebRequest -Uri $URL_PROFILE_MAIN -OutFile $PROFILE -UseBasicParsing
        Write-Host "✅ Profilo PowerShell sovrascritto con la versione main." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Errore aggiornamento profilo: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 3. Avviso all'utente
    Write-Host "`n🎉 Switch al ramo Main completato con successo! Modifiche effettuate:" -ForegroundColor Green
    Write-Host "  - Icona desktop 'Win Toolkit' rigenerata e puntata al ramo main." -ForegroundColor Yellow
    Write-Host "  - Profilo PowerShell sostituito con la versione del ramo main." -ForegroundColor Yellow
    Write-Host "`n⚠️  ATTENZIONE: Riavvia il terminale per applicare le modifiche del nuovo profilo." -ForegroundColor Magenta
}

function PS-Reset {
    [CmdletBinding()]
    param()

    # 1. Controllo Amministratore (Necessario per disinstallazioni e riavvio)
    if (-not (Assert-Admin)) {
        Write-Host "❌ Questa operazione richiede privilegi di Amministratore." -ForegroundColor Red
        Write-Host "ℹ️ Riavvia PowerShell come Amministratore per eseguire PS-Reset." -ForegroundColor Cyan
        return
    }

    Write-Host "⚠️ ATTENZIONE: Questa operazione eseguirà un ROLLBACK COMPLETO:" -ForegroundColor Yellow
    Write-Host "  - Disinstallerà OhMyPosh, Zoxide, Btop, Fastfetch e i font Nerd." -ForegroundColor DarkYellow
    Write-Host "  - Eliminerà le cartelle WinToolkit, i log e i file temporanei." -ForegroundColor DarkYellow
    Write-Host "  - Resetterà Windows Terminal e il profilo PowerShell alle impostazioni di fabbrica." -ForegroundColor DarkYellow
    Write-Host "  - RIAVVIERÀ automaticamente il sistema al termine." -ForegroundColor Red

    $confirmation = Read-Host "`n❓ Vuoi procedere in modo irreversibile? (S/N)"

    if ($confirmation -notmatch "^[Ss]$") {
        Write-Host "ℹ️ Operazione annullata." -ForegroundColor Cyan
        return
    }

    Write-Host "`n🔄 Avvio procedura di reset profondo..." -ForegroundColor Cyan

    # 2. Rimozione Scorciatoia Desktop
    Write-Host "`n🗑️ Rimozione scorciatoia Desktop..." -ForegroundColor Cyan
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcut = Join-Path $desktopPath "Win Toolkit.lnk"
    if (Test-Path $shortcut) {
        Remove-Item -Path $shortcut -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Scorciatoia Desktop rimossa." -ForegroundColor Green
    }

    # 3. Pulizia cartelle di sistema e temporanee
    Write-Host "`n🧹 Pulizia file temporanei e directory WinToolkit..." -ForegroundColor Cyan
    $directoriesToRemove = @(
        (Join-Path $env:LOCALAPPDATA "WinToolkit"),
        (Join-Path $env:TEMP "WinToolkitSetup"),
        (Join-Path $env:TEMP "WinToolkitWinget")
    )

    foreach ($dir in $directoriesToRemove) {
        if (Test-Path $dir) {
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "   -> Rimossa directory: $dir" -ForegroundColor DarkGray
        }
    }
    Write-Host "✅ Pulizia cartelle completata." -ForegroundColor Green

    # 4. Reset Windows Terminal
    Write-Host "`n🔄 Reset impostazioni Windows Terminal..." -ForegroundColor Cyan
    $wtSettingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (Test-Path $wtSettingsPath) {
        Remove-Item -Path $wtSettingsPath -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Impostazioni di Windows Terminal eliminate." -ForegroundColor Green
    }

    # 5. Eliminazione Directory Profilo PowerShell (Include profili, .bak, e cartella Themes)
    # Eseguito prima della disinstallazione di Oh My Posh per evitare crash della shell
    Write-Host "`n🗑️ Eliminazione configurazioni profilo PowerShell..." -ForegroundColor Cyan
    $profileDir = Split-Path -Parent $PROFILE
    if (Test-Path $profileDir) {
        Remove-Item -Path $profileDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Directory del profilo PowerShell eliminata." -ForegroundColor Green
    }

    # 6. Disinstallazione pacchetti Winget (Eseguita ULTIMA come risorsa finale)
    # Oh My Posh deve essere disinstallato per ultimo per evitare crash del terminale
    $wingetPackages = @(
        "JanDeDobbeleer.OhMyPosh",
        "ajeetdsouza.zoxide",
        "aristocratos.btop4win",
        "Fastfetch-cli.Fastfetch",
        "DEVCOM.JetBrainsMonoNerdFont"
    )

    Write-Host "`n📦 Disinstallazione tool da riga di comando via Winget..." -ForegroundColor Cyan
    foreach ($pkg in $wingetPackages) {
        Write-Host "   -> Rimozione di $pkg..." -ForegroundColor DarkGray
        # Utilizzo di Start-Process per attendere la fine dell'operazione silenziosa
        Start-Process -FilePath "winget" -ArgumentList "uninstall --id $pkg --silent --accept-source-agreements" -Wait -NoNewWindow
    }
    Write-Host "✅ Disinstallazioni Winget completate." -ForegroundColor Green

    # 7. Conclusione e Riavvio temporizzato
    Write-Host "`n🎉 RESET COMPLETATO CON SUCCESSO!" -ForegroundColor Green
    Write-Host "L'ambiente è stato riportato alle impostazioni di fabbrica." -ForegroundColor Magenta
    Write-Host "Il sistema verrà riavviato per pulire i processi in sospeso e finalizzare le modifiche.`n" -ForegroundColor Yellow

    # Countdown di 10 secondi
    for ($i = 10; $i -gt 0; $i--) {
        Write-Host "`r⏳ Riavvio automatico tra $i secondi... " -NoNewline -ForegroundColor Red
        Start-Sleep -Seconds 1
    }

    Write-Host "`n`n🚀 Avvio riavvio del sistema in corso..." -ForegroundColor Cyan
    shutdown /r /f /t 0
}

function ReadyToGo {
    [CmdletBinding()]
    param()

    Write-Host "`n🚀 Avvio esecuzione ReadyToGo..." -ForegroundColor Cyan

    # 1. Elimina i log di PSReadLine
    try {
        Write-Host "🧹 Eliminazione cronologia PSReadLine..." -ForegroundColor Cyan
        $psReadLinePath = Join-Path $env:APPDATA "Microsoft\Windows\PowerShell\PSReadLine\*"
        Remove-Item -Path $psReadLinePath -Recurse -Force -ErrorAction Stop
        Write-Host "✅ Cronologia PSReadLine eliminata." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Errore durante l'eliminazione della cronologia PSReadLine: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 2. Reset Microsoft Edge
    try {
        Write-Host "🔄 Chiusura di Microsoft Edge..." -ForegroundColor Cyan
        Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        Write-Host "🧹 Reset profondo di Microsoft Edge..." -ForegroundColor Cyan
        $edgeUserDataPath = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data"
        if (Test-Path $edgeUserDataPath) {
            Remove-Item -Path $edgeUserDataPath -Recurse -Force -ErrorAction Stop
            Write-Host "✅ Dati utente di Microsoft Edge eliminati (Reset alle impostazioni di fabbrica)." -ForegroundColor Green
        }
        else {
            Write-Host "ℹ️ Cartella dati utente di Microsoft Edge non trovata." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ Errore durante il reset di Microsoft Edge: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 3. Disinstallazione di Revo Uninstaller Pro (se presente)
    try {
        Write-Host "📦 Verifica e disinstallazione di Revo Uninstaller Pro..." -ForegroundColor Cyan
        # Esegui disinstallazione silenziosa ignorando gli errori e accettando gli accordi
        Start-Process -FilePath "winget" -ArgumentList "uninstall --id RevoUninstaller.RevoUninstallerPro --silent --accept-source-agreements" -Wait -NoNewWindow
        Write-Host "✅ Verifica Revo Uninstaller Pro completata." -ForegroundColor Green
    }
    catch {
        Write-Host "ℹ️ Revo Uninstaller Pro non trovato o errore durante la disinstallazione." -ForegroundColor Yellow
    }

    Write-Host "🎉 Operazione ReadyToGo completata con successo!" -ForegroundColor Green
}

# ============================================================================
# CONFIGURAZIONE EDITOR CON FALLBACK
# ============================================================================

function Get-PreferredEditor {
    # Tenta di trovare Zed nel PATH per primo
    if (Test-CommandExists -Name "zed") {
        $zedCmd = Get-Command zed -ErrorAction SilentlyContinue
        if ($zedCmd) {
            return @{
                Name    = 'Zed'
                Path    = $zedCmd.Source
                Command = $zedCmd.Source
            }
        }
    }

    # Se non nel PATH, controlla le posizioni di installazione comuni
    $zedPaths = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Zed\Zed.exe"),
        (Join-Path $env:PROGRAMFILES "Zed\Zed.exe"),
        (Join-Path $HOME "AppData\Local\Programs\Zed\Zed.exe")
    )

    foreach ($zpath in $zedPaths) {
        if (Test-Path $zpath) {
            return @{
                Name    = 'Zed'
                Path    = $zpath
                Command = $zpath
            }
        }
    }

    # Fallback a Visual Studio Code
    if (Test-CommandExists -Name "code") {
        return @{
            Name    = 'Visual Studio Code'
            Path    = (Get-Command code).Source
            Command = 'code'
        }
    }

    # Ultimo fallback a Notepad
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
$($PSStyle.Foreground.Cyan)Guida al Profilo PowerShell$($PSStyle.Reset) $($PSStyle.Foreground.Red)========================================================$($PSStyle.Reset)

$($PSStyle.Foreground.Green)Verde (Safe):$($PSStyle.Reset) utilizzo sicuro, non comporta problematiche.
$($PSStyle.Foreground.Yellow)Giallo (Warning):$($PSStyle.Reset) Attenzione leggere attentamente la descrizione, questo tipo di comandi comportano variazioni distruttive al sistema.
$($PSStyle.Foreground.Red)Rosso (ALLERT!):$($PSStyle.Reset) Queste funzioni sono state designare per effettuare modifiche profonde e distruttive, attento a cosa stai facendo!

$($PSStyle.Foreground.Green)====================================================================================$($PSStyle.Reset)

$($PSStyle.Foreground.Cyan)Informazioni Sistema e Hardware$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)----------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Get-SystemInfo$($PSStyle.Reset)            - Visualizza informazioni di sistema dettagliate.
$($PSStyle.Foreground.Green)Get-MainboardInfo$($PSStyle.Reset)         - Informazioni sulla scheda madre.
$($PSStyle.Foreground.Green)Get-RAMInfo$($PSStyle.Reset)               - Informazioni sui moduli RAM installati.
$($PSStyle.Foreground.Green)Get-PublicIP$($PSStyle.Reset)              - Recupera l'indirizzo IP pubblico.

$($PSStyle.Foreground.Cyan)Gestione File e Directory$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)----------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)New-Mkcd$($PSStyle.Reset)                  - Crea una directory e ci si sposta.
$($PSStyle.Foreground.Green)Set-LocationToDesktop$($PSStyle.Reset)     - Naviga alla directory Desktop.
$($PSStyle.Foreground.Green)Find-File$($PSStyle.Reset)                 - Cerca file ricorsivamente per nome parziale.
$($PSStyle.Foreground.Green)Expand-ZipFile$($PSStyle.Reset)            - Estrae un file ZIP nella directory corrente.

$($PSStyle.Foreground.Cyan)Diagnostica e Strumenti di Rete$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)----------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Speedtest$($PSStyle.Reset)                 - Esegue un test della velocità di rete.
$($PSStyle.Foreground.Green)FlushDns$($PSStyle.Reset)                  - Svuota la cache DNS.
$($PSStyle.Foreground.Yellow)Reset-Network$($PSStyle.Reset)             - Ripristina le impostazioni di rete a quelle predefinite.

$($PSStyle.Foreground.Cyan)Controllo sistema$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)------------------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)doReboot$($PSStyle.Reset)                  - Riavvia il sistema immediatamente.
$($PSStyle.Foreground.Green)Shutdownfast$($PSStyle.Reset)              - Spegnimento rapido.
$($PSStyle.Foreground.Green)ShutdownComplete$($PSStyle.Reset)          - Spegnimento completo (bypass Fast Startup).

$($PSStyle.Foreground.Cyan)Lancio WinToolkit$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)------------------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)WinToolkit-Stable$($PSStyle.Reset)         - Lancia WinToolkit (stabile).
$($PSStyle.Foreground.Yellow)WinToolkit-Dev$($PSStyle.Reset)            - Lancia WinToolkit (Dev).
$($PSStyle.Foreground.Magenta)WinToolkit-GUI$($PSStyle.Reset)            - Lancia WinToolkit (Versione GUI).
$($PSStyle.Foreground.Yellow)SetBranch-Main$($PSStyle.Reset)            - Switcha l'ambiente (Icona e Profilo) al ramo main.
$($PSStyle.Foreground.Yellow)SetBranch-Dev$($PSStyle.Reset)             - Switcha l'ambiente (Icona e Profilo) al ramo dev.
$($PSStyle.Foreground.Red)WinReg$($PSStyle.Reset)                    - Attiva Windows/Office (MAS).
$($PSStyle.Foreground.Red)SetRustDesk$($PSStyle.Reset)               - Configura RustDesk per il controllo remoto.

$($PSStyle.Foreground.Cyan)Gestione Profilo Powershell$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)--------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)EditPSProfile$($PSStyle.Reset)             - Apre il profilo PowerShell nell'editor.
$($PSStyle.Foreground.Green)ReloadProfile$($PSStyle.Reset)             - Ricarica il profilo PowerShell corrente.
$($PSStyle.Foreground.Green)PSProfileUpdate$($PSStyle.Reset)           - Aggiorna il profilo PowerShell all'ultima versione.
$($PSStyle.Foreground.Yellow)PS-Reset$($PSStyle.Reset)                  - Resetta Windows Terminal e cancella questo profilo.
$($PSStyle.Foreground.Green)Update-Pwsh$($PSStyle.Reset)               - Aggiorna PowerShell all'ultima versione.
$($PSStyle.Foreground.Red)ReadyToGo$($PSStyle.Reset)                 - Rende pronto il PC per l'uso finale (PC Delivery).

$($PSStyle.Foreground.Cyan)Utility terminale$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)------------------------------------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)btop$($PSStyle.Reset)                      - Monitor delle risorse per il terminale.


$($PSStyle.Foreground.Cyan)Editor Configurato$($PSStyle.Reset) $($PSStyle.Foreground.Yellow)-----------------------------------------------------------------$($PSStyle.Reset)
Editor corrente: $($PSStyle.Foreground.Magenta)$($EDITOR_INFO.Name)$($PSStyle.Reset)

$($PSStyle.Foreground.Green)====================================================================================$($PSStyle.Reset)
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

function Update-Pwsh {
    [CmdletBinding()]
    param()

    # Avviso se eseguito da Windows PowerShell 5.x invece di PowerShell 7+
    if ($PSVersionTable.PSEdition -ne 'Core') {
        Write-Host "⚠️ Stai usando Windows PowerShell $($PSVersionTable.PSVersion)." -ForegroundColor DarkYellow
        Write-Host "   Questa funzione aggiorna PowerShell 7+. Apri una sessione 'pwsh' per continuare." -ForegroundColor DarkYellow
        return
    }

    Write-Host "🔍 Verifica degli aggiornamenti di PowerShell..." -ForegroundColor Cyan

    try {
        [version]$currentPSVersion = $PSVersionTable.PSVersion
        $latestReleaseInfo = Invoke-RestMethod -Uri $URL_PWSH_RELEASE_API -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        [version]$latestPSVersion = $latestReleaseInfo.tag_name.TrimStart('v')

        Write-Host "   Versione corrente : v$currentPSVersion" -ForegroundColor Gray
        Write-Host "   Ultima versione   : v$latestPSVersion" -ForegroundColor Gray

        if ($currentPSVersion -ge $latestPSVersion) {
            Write-Host "✅ PowerShell è già aggiornato (v$currentPSVersion)" -ForegroundColor Green
            return
        }

        # Aggiornamento necessario
        if (-not (Assert-Admin)) {
            Write-Host "⚠️ Per aggiornare PowerShell sono necessari i privilegi di Amministratore." -ForegroundColor Yellow
            Write-Host "   Riesegui la funzione in una sessione 'pwsh' avviata come Amministratore." -ForegroundColor DarkYellow
            return
        }

        Write-Host "🔄 Aggiornamento di PowerShell in corso (v$currentPSVersion → v$latestPSVersion)..." -ForegroundColor Yellow
        winget upgrade --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Aggiornamento completato. Chiudi e riapri il terminale per usare PowerShell v$latestPSVersion." -ForegroundColor Green
        }
        elseif ($LASTEXITCODE -eq -1978335189) {
            Write-Host "" -ForegroundColor Yellow
            Write-Host "⚠️ Rilevata incompatibilità tecnologia installazione (codice: $LASTEXITCODE)." -ForegroundColor Yellow
            Write-Host "   Il pacchetto installato utilizza un metodo diverso da quello atteso da winget." -ForegroundColor DarkYellow
            Write-Host "🔄 Avvio procedura di reinstallazione automatica..." -ForegroundColor Cyan

            # Step 1: Disinstallazione
            Write-Host "   1/2 - Disinstallazione di Microsoft.PowerShell in corso..." -ForegroundColor Cyan
            winget uninstall --id Microsoft.PowerShell --accept-source-agreements --silent --all-versions
            if ($LASTEXITCODE -ne 0) {
                Write-Host "❌ Disinstallazione fallita (codice: $LASTEXITCODE). Operazione interrotta." -ForegroundColor Red
                Write-Host "   Prova a disinstallare PowerShell manualmente e poi esegui nuovamente Update-Pwsh." -ForegroundColor DarkYellow
                return
            }
            Write-Host "   ✅ Disinstallazione completata." -ForegroundColor Green

            # Step 2: Reinstallazione
            Write-Host "   2/2 - Installazione di PowerShell v$latestPSVersion in corso..." -ForegroundColor Cyan
            winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Reinstallazione completata con successo." -ForegroundColor Green
                Write-Host "⚠️ IMPORTANTE: Devi aprire una nuova sessione del terminale per usare PowerShell v$latestPSVersion." -ForegroundColor Yellow
            }
            else {
                Write-Host "❌ Reinstallazione fallita (codice: $LASTEXITCODE)." -ForegroundColor Red
                Write-Host "   Consulta l'output di winget qui sopra per dettagli sull'errore." -ForegroundColor DarkYellow
            }
        }
        else {
            Write-Host "⚠️ winget ha restituito il codice di uscita $LASTEXITCODE. Verifica l'output qui sopra." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ Impossibile verificare o aggiornare PowerShell: $($_.Exception.Message)" -ForegroundColor Red
        if (-not (Test-CommandExists 'winget')) {
            Write-Host "   Suggerimento: 'winget' non trovato. Assicurati che App Installer sia installato." -ForegroundColor DarkYellow
        }
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
    $themeUrl = $URL_OHMYPOSH_THEME
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
    $fallbackUrl = $URL_OHMYPOSH_THEME
    Write-Warning "Tema locale non disponibile. Uso fallback remoto."
    oh-my-posh init pwsh --config $fallbackUrl | Invoke-Expression
}

# zoxide
if (Test-CommandExists -Name "zoxide") {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# fastfetch
if (Test-CommandExists -Name "fastfetch") {
    fastfetch
}

Write-Host ""
Write-Host "💡 Digita 'help' per scoprire i comandi personalizzati." -ForegroundColor Yellow
Write-Host "✅ Profilo caricato - Versione: $ProfileVersion" -ForegroundColor Green

# ============================================================================
# FINE DEL PROFILO
# ============================================================================
