<#
.SYNOPSIS
    WinToolkit - Strumenti di manutenzione Windows
.DESCRIPTION
    Menu principale per strumenti di gestione e riparazione Windows
.NOTES
  Versione 2.3.0 (Build 3) - 2025-10-18
#>

param([int]$CountdownSeconds = 10)
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan"
$ErrorActionPreference = 'Stop'

# Setup logging
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\WinToolkit\logs"
try {
    [System.IO.Directory]::CreateDirectory($logdir) | Out-Null
    Start-Transcript -Path "$logdir\WinToolkit_$dateTime.log" -Append -Force | Out-Null
}
catch {}

# ASCII Art
$asciiArt = @(
    '      __        __  _  _   _ ',
    '      \ \      / / | || \ | |',
    '       \ \ /\ / /  | ||  \| |',
    '        \ V  V /   | || |\  |',
    '         \_/\_/    |_||_| \_|',
    '',
    '       WinToolkit By MagnetarMan',
    '       Version 2.3.0 (Build 3)'
)

# Version mapping (usato da più funzioni)
$versionMap = @{
    26100 = "24H2"; 22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2"
    19045 = "22H2"; 19044 = "21H2"; 19043 = "21H1"; 19042 = "20H2"
    19041 = "2004"; 18363 = "1909"; 18362 = "1903"; 17763 = "1809"
    17134 = "1803"; 16299 = "1709"; 15063 = "1703"; 14393 = "1607"
    10586 = "1511"; 10240 = "1507"
}

# Utility Functions
function Write-StyledMessage {
    param([ValidateSet('Success', 'Warning', 'Error', 'Info')][string]$type, [string]$text)
    $config = @{
        Success = @{ Icon = '✅'; Color = 'Green' }
        Warning = @{ Icon = '⚠️'; Color = 'Yellow' }
        Error   = @{ Icon = '❌'; Color = 'Red' }
        Info    = @{ Icon = '💎'; Color = 'Cyan' }
    }
    Write-Host "$($config[$type].Icon) $text" -ForegroundColor $config[$type].Color
}

function Center-Text {
    param([string]$text, [int]$width = $Host.UI.RawUI.BufferSize.Width)
    if ($text.Length -ge $width) { return $text }
    ' ' * [Math]::Floor(($width - $text.Length) / 2) + $text
}

function Show-Header {
    Clear-Host
    $width = $Host.UI.RawUI.BufferSize.Width
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    foreach ($line in $asciiArt) {
        Write-Host (Center-Text $line $width) -ForegroundColor White
    }
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    Write-Host ''
}

function Get-WindowsVersion {
    param([int]$buildNumber)
    
    foreach ($build in ($versionMap.Keys | Sort-Object -Descending)) {
        if ($buildNumber -ge $build) { return $versionMap[$build] }
    }
    return "N/A"
}

function Get-SystemInfo {
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $computerInfo = Get-CimInstance Win32_ComputerSystem
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

        return @{
            ProductName    = $osInfo.Caption -replace 'Microsoft ', ''
            BuildNumber    = [int]$osInfo.BuildNumber
            Architecture   = $osInfo.OSArchitecture
            ComputerName   = $computerInfo.Name
            TotalRAM       = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
            TotalDisk      = [Math]::Round($diskInfo.Size / 1GB, 0)
            FreePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)
        }
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore nel recupero informazioni: $($_.Exception.Message)"
        return $null
    }
}

function winver {
    $sysInfo = Get-SystemInfo
    if (-not $sysInfo) { return }

    $buildNumber = $sysInfo.BuildNumber
    $windowsVersion = Get-WindowsVersion $buildNumber

    # Edition detection
    $windowsEdition = switch -Wildcard ($sysInfo.ProductName) {
        "*Home*" { "🏠 Home" }
        "*Pro*" { "💼 Professional" }
        "*Enterprise*" { "🏢 Enterprise" }
        "*Education*" { "🎓 Education" }
        "*Server*" { "🖥️ Server" }
        default { "💻 $($sysInfo.ProductName)" }
    }

    # Display info
    $width = 65
    Write-Host ""
    Write-Host ('*' * $width) -ForegroundColor Red
    Write-Host (Center-Text "🖥️  INFORMAZIONI SISTEMA  🖥️" $width) -ForegroundColor White
    Write-Host ('*' * $width) -ForegroundColor Red
    Write-Host ""

    $info = @(
        @("💻 Edizione:", $windowsEdition, 'White'),
        @("📊 Versione:", "Ver. $windowsVersion (Build $buildNumber)", 'Green'),
        @("🗝️ Architettura:", $sysInfo.Architecture, 'White'),
        @("🏷️ Nome PC:", $sysInfo.ComputerName, 'White'),
        @("🧠 RAM:", "$($sysInfo.TotalRAM) GB", 'White'),
        @("💾 Disco:", "$($sysInfo.FreePercentage)% Libero ($($sysInfo.TotalDisk) GB)", 'Green')
    )

    foreach ($item in $info) {
        Write-Host "  $($item[0])" -ForegroundColor Yellow -NoNewline
        Write-Host " $($item[1])" -ForegroundColor $item[2]
    }

    Write-Host ""
    Write-Host ('*' * $width) -ForegroundColor Red
}

function Show-Countdown {
    param([string]$message = "Chiusura in")
    
    Write-Host ''
    Write-StyledMessage -type 'Success' -text 'Grazie per aver utilizzato WinToolkit!'
    Write-StyledMessage -type 'Info' -text 'Per supporto: Github.com/Magnetarman'
    Write-Host ''
    
    for ($i = $CountdownSeconds; $i -gt 0; $i--) {
        Write-Host "  $message $i secondi..." -ForegroundColor Cyan
        Start-Sleep -Seconds 1
    }
    
    Stop-Transcript -ErrorAction SilentlyContinue
    exit
}

function WinOSCheck {
    Show-Header
    Write-StyledMessage -type 'Info' -text 'Verifica Sistema Operativo'
    Write-Host ''
    
    $sysInfo = Get-SystemInfo
    if (-not $sysInfo) {
        Write-StyledMessage -type 'Warning' -text 'Impossibile verificare il sistema. Prosecuzione con compatibilità limitata...'
        Start-Sleep -Seconds 5
        return
    }

    $buildNumber = $sysInfo.BuildNumber
    $windowsVersion = Get-WindowsVersion $buildNumber
    
    # Determina categoria Windows
    $isWin11 = $buildNumber -ge 22000
    $isWin10 = ($buildNumber -ge 10240) -and ($buildNumber -lt 22000)
    $isWin81 = $buildNumber -eq 9600
    $isWin8 = $buildNumber -eq 9200
    
    $osDisplay = if ($isWin11) { "Windows 11" } 
    elseif ($isWin10) { "Windows 10" }
    elseif ($isWin81) { "Windows 8.1" }
    elseif ($isWin8) { "Windows 8" }
    else { $sysInfo.ProductName }
    
    Write-Host "  Sistema rilevato: " -NoNewline -ForegroundColor Yellow
    Write-Host "$osDisplay (Build $buildNumber - Ver. $windowsVersion)" -ForegroundColor White
    Write-Host ''
    
    # Logica di compatibilità aggiornata
    if ($isWin11 -and $buildNumber -ge 22621) {
        # Windows 11 22H2+
        Write-StyledMessage -type 'Success' -text 'Sistema completamente compatibile!'
        Write-Host "  Lo script funzionerà alla massima velocità ed efficienza." -ForegroundColor Green
        Write-Host ''
        Start-Sleep -Seconds 5
        return
    }

    if ($isWin11 -and $buildNumber -ge 22000) {
        # Windows 11 21H2 - Supporto completo con eccezioni
        Write-StyledMessage -type 'Success' -text 'Sistema compatibile con eccezioni'
        Write-Host "  Lo script è completamente supportato con alcune eccezioni minori." -ForegroundColor Green
        Write-Host "  Potrebbero essere necessarie lievi ottimizzazioni." -ForegroundColor Yellow
        Write-Host ''
        Start-Sleep -Seconds 7
        return
    }

    if ($isWin10 -and $buildNumber -ge 17763) {
        # Windows 10 1809+ - Supporto completo
        Write-StyledMessage -type 'Success' -text 'Sistema completamente compatibile!'
        Write-Host "  Lo script funzionerà alla massima velocità ed efficienza." -ForegroundColor Green
        Write-Host ''
        Start-Sleep -Seconds 5
        return
    }

    if ($isWin10 -and $buildNumber -lt 17763) {
        # Windows 10 pre-1809
        Write-StyledMessage -type 'Error' -text 'Sistema troppo vecchio - Sconsigliato'
        Write-Host "  Lo script potrebbe avere gravi problemi di affidabilità!" -ForegroundColor Red
        Write-Host ''

        Write-Host "  Vuoi proseguire a tuo rischio e pericolo? " -NoNewline -ForegroundColor Yellow
        Write-Host "[Y/N]: " -NoNewline -ForegroundColor White
        $response = Read-Host

        if ($response -notmatch '^[Yy]$') { Show-Countdown }

        Write-StyledMessage -type 'Warning' -text 'Prosecuzione confermata - Buona fortuna!'
        Start-Sleep -Seconds 2
        return
    }

    if ($isWin81) {
        # Windows 8.1 - Supporto parziale
        Write-StyledMessage -type 'Warning' -text 'Sistema parzialmente compatibile'
        Write-Host "  Il sistema non è completamente aggiornato." -ForegroundColor Yellow
        Write-Host "  Lo script userà workaround e funzioni alternative per garantire" -ForegroundColor Yellow
        Write-Host "  la massima compatibilità, con efficienza leggermente ridotta." -ForegroundColor Yellow
        Write-Host ''
        Start-Sleep -Seconds 10
        return
    }

    if ($isWin8) {
        # Windows 8 - Non supportato
        Write-StyledMessage -type 'Error' -text 'Sistema obsoleto - Non supportato'
        Write-Host "  Windows 8 non è più supportato ufficialmente." -ForegroundColor Red
        Write-Host "  Lo script avrà gravi problemi di affidabilità e stabilità!" -ForegroundColor Red
        Write-Host ''

        Write-Host "  Vuoi davvero proseguire a tuo rischio e pericolo? " -NoNewline -ForegroundColor Yellow
        Write-Host "[Y/N]: " -NoNewline -ForegroundColor White
        $response = Read-Host

        if ($response -notmatch '^[Yy]$') { Show-Countdown }

        Write-StyledMessage -type 'Warning' -text 'Hai scelto la strada difficile... In bocca al lupo!'
        Start-Sleep -Seconds 2
        return
    }
    
    # Windows 7 o precedenti
    Write-Host ''
    Write-Host ('*' * 65) -ForegroundColor Red
    Write-Host (Center-Text "🤣 ERRORE CRITICO 🤣" 65) -ForegroundColor Red
    Write-Host ('*' * 65) -ForegroundColor Red
    Write-Host ''
    Write-Host "  Davvero pensi che questo script possa fare qualcosa" -ForegroundColor Red
    Write-Host "  per questa versione di Windows?" -ForegroundColor Red
    Write-Host ''
    Write-Host "  E' già un miracolo che tu riesca a vedere questo" -ForegroundColor Yellow
    Write-Host "  messaggio di errore senza che il pc sia esploso 🤣" -ForegroundColor Yellow
    Write-Host ''
    Write-Host "  💡 Suggerimento: Aggiorna Windows o passa a Linux!" -ForegroundColor Cyan
    Write-Host ''
    Write-Host ('*' * 65) -ForegroundColor Red
    Write-Host ''
    
    Write-Host "  Vuoi comunque tentare l'impossibile? " -NoNewline -ForegroundColor Magenta
    Write-Host "[Y/N]: " -NoNewline -ForegroundColor White
    $response = Read-Host
    
    if ($response -notmatch '^[Yy]$') { Show-Countdown }
    
    Write-StyledMessage -type 'Warning' -text 'Ok, ma non dire che non ti avevo avvertito! 😅'
    Write-Host "  La maggior parte delle funzioni NON funzioneranno." -ForegroundColor Red
    Write-Host "  Potrebbero verificarsi errori e instabilità del sistema." -ForegroundColor Red
    Start-Sleep -Seconds 3
}

# Placeholder functions (verranno automaticamente popolate dal compilatore)
function WinInstallPSProfile {}
function WinRepairToolkit {}
function WinUpdateReset {}
function WinReinstallStore {}
function WinBackupDriver {}
function WinDriverInstall {}
function OfficeToolkit {}
function WinCleaner {}
# function SearchRepair {}
function SetRustDesk {}
function VideoDriverInstall {}
function GamingToolkit {}


# Menu structure
$menuStructure = @(
    @{
        'Name' = 'Operazioni Preliminari'; 'Icon' = '🪄'
        'Scripts' = @([pscustomobject]@{ Name = 'WinInstallPSProfile'; Description = 'Installa profilo PowerShell'; Action = 'RunFunction' })
    },
    @{
        'Name' = 'Windows & Office'; 'Icon' = '🔧'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'WinRepairToolkit'; Description = 'Toolkit Riparazione Windows'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinUpdateReset'; Description = 'Reset Windows Update'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinBackupDriver'; Description = 'Backup Driver PC'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinCleaner'; Description = 'Pulizia File Temporanei'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'OfficeToolkit'; Description = 'Office Toolkit'; Action = 'RunFunction' }
        )
    },
    @{
        'Name' = 'Driver & Gaming'; 'Icon' = '🎮'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'VideoDriverInstall'; Description = 'Toolkit Driver Grafici'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'GamingToolkit'; Description = 'Gaming Toolkit - Planned V2.4'; Action = 'RunFunction' }
        )
    },
    @{
        'Name' = 'Supporto'; 'Icon' = '🕹️'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'SetRustDesk'; Description = 'Setting RustDesk - MagnetarMan Mode'; Action = 'RunFunction' }
        )
    }
)

# Esegui verifica compatibilità sistema
WinOSCheck

# Main loop
while ($true) {
    Clear-Host
    $width = 65

    # Header
    Show-Header
    winver
    Write-Host ''

    # Build and display menu
    $allScripts = @()
    $scriptIndex = 1

    foreach ($category in $menuStructure) {
        Write-Host "=== $($category.Icon) $($category.Name) $($category.Icon) ===" -ForegroundColor Cyan
        Write-Host ''

        foreach ($script in $category.Scripts) {
            $allScripts += $script
            Write-StyledMessage -type 'Info' -text "[$scriptIndex] $($script.Description)"
            $scriptIndex++
        }
        Write-Host ''
    }

    # Exit section
    Write-Host "=== Uscita ===" -ForegroundColor Red
    Write-Host ''
    Write-StyledMessage -type 'Error' -text '[0] Esci dal Toolkit'
    Write-Host ''

    # Handle user choice
    $userChoice = Read-Host "Scegli un'opzione (es. 1, 3, 5 o 0 per uscire)"

    if ($userChoice -eq '0') {
        Write-StyledMessage -type 'Warning' -text 'Per supporto: Github.com/Magnetarman'
        Write-StyledMessage -type 'Success' -text 'Chiusura in corso...'
        Start-Sleep -Seconds 3
        break
    }

    # Parse and validate choices
    $choices = $userChoice -split '[ ,]+' | Where-Object { $_ -ne '' }
    $scriptsToRun = [System.Collections.Generic.List[object]]::new()
    $invalidChoices = [System.Collections.Generic.List[string]]::new()

    foreach ($choice in $choices) {
        if (($choice -match '^\d+$') -and ([int]$choice -ge 1) -and ([int]$choice -le $allScripts.Count)) {
            $scriptsToRun.Add($allScripts[[int]$choice - 1])
        }
        else {
            $invalidChoices.Add($choice)
        }
    }

    # Handle invalid choices
    if ($invalidChoices.Count -gt 0) {
        Write-StyledMessage -type 'Warning' -text "Opzioni non valide ignorate: $($invalidChoices -join ', ')"
        Start-Sleep -Seconds 2
    }

    # Execute valid scripts
    if ($scriptsToRun.Count -gt 0) {
        foreach ($selectedItem in $scriptsToRun) {
            Write-Host "`n" + ('-' * ($width / 2))
            Write-StyledMessage -type 'Info' -text "Avvio '$($selectedItem.Description)'..."

            try {
                if ($selectedItem.Action -eq 'RunFile') {
                    $scriptPath = Join-Path $PSScriptRoot $selectedItem.Name
                    if (Test-Path $scriptPath) { 
                        & $scriptPath 
                    }
                    else { 
                        Write-StyledMessage -type 'Error' -text "Script non trovato: $($selectedItem.Name)" 
                    }
                }
                elseif ($selectedItem.Action -eq 'RunFunction') {
                    Invoke-Expression $selectedItem.Name
                }
                Write-StyledMessage -type 'Success' -text "Completato: '$($selectedItem.Description)'"
            }
            catch {
                Write-StyledMessage -type 'Error' -text "Errore in '$($selectedItem.Description)'"
                Write-StyledMessage -type 'Error' -text "Dettagli: $($_.Exception.Message)"
            }
        }

        Write-Host "`nOperazioni completate. Premi un tasto per continuare..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    elseif ($invalidChoices.Count -eq $choices.Count) {
        Write-StyledMessage -type 'Error' -text 'Nessuna scelta valida. Riprova.'
        Start-Sleep -Seconds 2
    }
}