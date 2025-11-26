<#
.SYNOPSIS
    WinToolkit - Strumenti di manutenzione Windows
.DESCRIPTION
    Menu principale per strumenti di gestione e riparazione Windows
.NOTES
  Versione 2.4.2 (Build 7) - 2025-11-25
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
    '       Version 2.4.2 (Build 7)'
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
function CheckBitlocker {
    try {
        # Esegue manage-bde e cattura l'output come array di stringhe
        $bdeOutput = & manage-bde -status C: 2>&1
        
        # Cerca la riga "Stato protezione:" nell'output
        $protectionLine = $bdeOutput | Where-Object { $_ -match "Stato protezione:" }
        
        if ($protectionLine) {
            # Estrae solo il valore dopo i due punti e rimuove spazi
            $status = ($protectionLine -split ':')[1].Trim()
            return $status
        }
        else {
            # Se non trova la riga, BitLocker non è configurato
            return "Non configurato"
        }
    }
    catch {
        # Gestione errori
        Write-StyledMessage -type 'Warning' -text "Impossibile verificare BitLocker: $($_.Exception.Message)"
        return "Non disponibile"
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

    # Recupera lo stato BitLocker e definisce il colore
    $bitlockerStatus = CheckBitlocker
    $bitlockerColor = if ($bitlockerStatus -eq "Protezione attivata" -or $bitlockerStatus -eq "Errore") { 'Red' } else { 'Green' }

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
        @("🔒 Stato Bitlocker:", $bitlockerStatus, $bitlockerColor),
        @("💾 Disco:", "$($sysInfo.FreePercentage)% Libero ($($sysInfo.TotalDisk) GB)", 'Green')
    )

    foreach ($item in $info) {
        Write-Host "  $($item[0])" -ForegroundColor Yellow -NoNewline
        
        # Gestione speciale per BitLocker attivato (grassetto + rosso)
        if ($item[0] -eq "🔒 Stato Bitlocker:" -and $item[1] -eq "Protezione attivata") {
            Write-Host " $($item[1])" -ForegroundColor $item[2] -NoNewline
            Write-Host " ⚠️" -ForegroundColor Red
        }
        else {
            Write-Host " $($item[1])" -ForegroundColor $item[2]
        }
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
function WinInstallPSProfile {
    <#
    .SYNOPSIS
        Script per installare il profilo PowerShell di ChrisTitusTech.

    .DESCRIPTION
        Installa e configura il profilo PowerShell personalizzato con oh-my-posh, zoxide e altre utilità.
        Richiede privilegi di amministratore e PowerShell 7+.
#>

    $Host.UI.RawUI.WindowTitle = "InstallPSProfile by MagnetarMan"
    $script:Log = @()

    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path $logdir)) { New-Item -Path $logdir -ItemType Directory -Force | Out-Null }
        Start-Transcript -Path "$logdir\WinInstallPSProfile_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}

    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $script:MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    function Write-StyledMessage {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('Success', 'Warning', 'Error', 'Info')]
            [string]$Type,

            [Parameter(Mandatory = $true)]
            [string]$Text
        )

        $style = $script:MsgStyles[$Type]
        $timestamp = Get-Date -Format "HH:mm:ss"

        # Regex per rimuovere emoji dal testo per il log
        $emojiRegex = '^[✅⚠️❌💎🔥🚀⚙️🧹📦📋📜🔒💾⬇️🔧⚡🖼️🌐🪟🔄🗂️📁🖨️📄🗑️💭⏸️▶️💡⏰🎉💻📊🛡️🔑]\s*'
        $cleanText = $Text -replace $emojiRegex, ''

        Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color

        if ($Type -in @('Info', 'Warning', 'Error')) {
            $logEntry = "[$timestamp] [$Type] $cleanText"
            $script:Log += $logEntry
        }
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '░' * (30 - $filled.Length)
        Write-Host "`r$Spinner $Icon $Activity [$filled$empty] $safePercent% $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Add-ToSystemPath([string]$PathToAdd) {
        try {
            if (-not (Test-Path $PathToAdd)) {
                Write-StyledMessage 'Warning' "Percorso non esistente: $PathToAdd"
                return $false
            }

            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            $pathExists = ($currentPath -split ';') | Where-Object { $_.TrimEnd('\') -ieq $PathToAdd.TrimEnd('\') }
            
            if ($pathExists) {
                Write-StyledMessage 'Info' "Percorso già nel PATH: $PathToAdd"
                return $true
            }

            $PathToAdd = $PathToAdd.TrimStart(';')
            $newPath = if ($currentPath.EndsWith(';')) { "$currentPath$PathToAdd" } else { "$currentPath;$PathToAdd" }
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            $env:PATH = "$env:PATH;$PathToAdd"
            
            Write-StyledMessage 'Success' "Percorso aggiunto al PATH: $PathToAdd"
            return $true
        }
        catch {
            Write-StyledMessage 'Error' "Errore aggiunta PATH: $($_.Exception.Message)"
            return $false
        }
    }

    function Find-ProgramPath([string]$ProgramName, [string[]]$SearchPaths, [string]$ExecutableName) {
        foreach ($path in $SearchPaths) {
            $resolvedPaths = @()
            try {
                $resolvedPaths = Get-ChildItem -Path (Split-Path $path -Parent) -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -like (Split-Path $path -Leaf) }
            }
            catch { continue }

            foreach ($resolved in $resolvedPaths) {
                $testPath = $resolved.FullName
                if (Test-Path "$testPath\$ExecutableName") { return $testPath }
            }

            $directPath = $path -replace '\*.*', ''
            if (Test-Path "$directPath\$ExecutableName") { return $directPath }
        }
        return $null
    }

    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi un tasto per annullare...'
        Write-Host ''

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning '⏸️ Riavvio annullato'
                Write-StyledMessage Info "🔄 Riavvia manualmente: 'shutdown /r /t 0'"
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $bar = "[$('█' * $filled)$('░' * (20 - $filled))] $percent%"
            Write-Host "`r⏰ Riavvio tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning '⏰ Riavvio in corso...'
        Start-Sleep 1
        return $true
    }

    function Get-CenteredText {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )

        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ '
            '      \ \      / / | || \ | |'
            '       \ \ /\ / /  | ||  \| |'
            '        \ V  V /   | || |\  |'
            '         \_/\_/    |_||_| \_|'
            ''
            '   InstallPSProfile By MagnetarMan'
            '      Version 2.4.2 (Build 17)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Get-CenteredText -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    Show-Header

    for ($i = 5; $i -gt 0; $i--) {
        Write-Host "`r$($spinners[$i % $spinners.Length]) ⏳ Preparazione - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-StyledMessage 'Warning' "Richiesti privilegi amministratore"
        Write-StyledMessage 'Info' "Riavvio come amministratore..."

        try {
            Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { WinInstallPSProfile }`""
            return
        }
        catch {
            Write-StyledMessage 'Error' "Impossibile elevare privilegi: $($_.Exception.Message)"
            return
        }
    }

    try {
        Write-StyledMessage 'Info' "Installazione profilo PowerShell..."
        Write-Host ''

        if (-not (Get-Command "pwsh" -ErrorAction SilentlyContinue)) {
            Write-StyledMessage 'Error' "PowerShell Core non installato!"
            return
        }

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-StyledMessage 'Warning' "Richiesto PowerShell 7+"
            $choice = Read-Host "Procedere comunque? (S/N)"
            if ($choice -notmatch '^[SsYy]') {
                Write-StyledMessage 'Info' "Installazione annullata"
                return
            }
        }
        
        $profileUrl = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        $oldHash = if (Test-Path $PROFILE) { Get-FileHash $PROFILE -ErrorAction SilentlyContinue } else { $null }

        Write-StyledMessage 'Info' "Controllo aggiornamenti..."
        $tempProfile = "$env:TEMP\Microsoft.PowerShell_profile.ps1"
        try {
            Invoke-RestMethod $profileUrl -OutFile $tempProfile -UseBasicParsing
            $newHash = Get-FileHash $tempProfile
        }
        catch [System.Net.WebException] {
            Write-StyledMessage 'Error' "Errore rete durante download profilo: $($_.Exception.Message)"
            return
        }
        catch {
            Write-StyledMessage 'Error' "Errore download profilo: $($_.Exception.Message)"
            return
        }

        $profileDir = Split-Path $PROFILE -Parent
        if (!(Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
        $newHash.Hash | Out-File "$PROFILE.hash" -Force
        
        Write-StyledMessage 'Info' "Hash profilo locale: $($oldHash.Hash), remoto: $($newHash.Hash)"
        if ($newHash.Hash -ne $oldHash.Hash) {
            if ((Test-Path $PROFILE) -and (-not (Test-Path "$PROFILE.bak"))) {
                Write-StyledMessage 'Info' "Backup profilo esistente..."
                Copy-Item -Path $PROFILE -Destination "$PROFILE.bak" -Force
                Write-StyledMessage 'Success' "Backup completato"
            }

            Write-StyledMessage 'Info' "Installazione dipendenze..."
            Write-Host ''

            # oh-my-posh
            try {
                Write-StyledMessage 'Info' "Installazione oh-my-posh..."
                $spinnerIndex = 0; $percent = 0
                
                $installProcess = Start-Process -FilePath "cmd" -ArgumentList "/c winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements --silent >nul 2>&1" -NoNewWindow -PassThru

                while (-not $installProcess.HasExited -and $percent -lt 90) {
                    Show-ProgressBar "oh-my-posh" "Installazione..." $percent '📦' $spinners[$spinnerIndex++ % $spinners.Length]
                    $percent += 2
                    Start-Sleep -Milliseconds 300
                }

                $installProcess.WaitForExit()
                if ($installProcess.ExitCode -ne 0) {
                    Write-StyledMessage 'Error' "Installazione oh-my-posh fallita (ExitCode: $($installProcess.ExitCode))"
                }
                else {
                    Start-Sleep -Seconds 2
                    Show-ProgressBar "oh-my-posh" "Completato" 100 '📦'
                    Write-Host ''
                }

                $omp = Get-ChildItem -Path "$env:LOCALAPPDATA" -Filter "oh-my-posh.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($omp) {
                    $ompPath = [System.IO.Path]::GetFullPath($omp.DirectoryName)
                    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
                    $pathArray = $currentPath -split ';' | ForEach-Object { [System.IO.Path]::GetFullPath($_) } | Where-Object { $_ }
                    if ($pathArray -notcontains $ompPath) {
                        $newPath = if ($currentPath.EndsWith(';')) { "$currentPath$ompPath" } else { "$currentPath;$ompPath" }
                        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
                        Write-StyledMessage 'Success' "Path oh-my-posh aggiunto: $ompPath"
                    }
                    else {
                        Write-StyledMessage 'Info' "Path oh-my-posh già presente."
                    }
                }
                else {
                    Write-StyledMessage 'Error' "oh-my-posh.exe non trovato! Prova a reinstallarlo: winget install JanDeDobbeleer.OhMyPosh"
                }
            }
            catch {
                Write-StyledMessage 'Warning' "Errore oh-my-posh: $($_.Exception.Message)"
            }

            # zoxide
            try {
                Write-StyledMessage 'Info' "Installazione zoxide..."
                $spinnerIndex = 0; $percent = 0
                
                $installProcess = Start-Process -FilePath "cmd" -ArgumentList "/c winget install ajeetdsouza.zoxide -s winget --accept-package-agreements --accept-source-agreements --silent >nul 2>&1" -NoNewWindow -PassThru

                while (-not $installProcess.HasExited -and $percent -lt 90) {
                    Show-ProgressBar "zoxide" "Installazione..." $percent '⚡' $spinners[$spinnerIndex++ % $spinners.Length]
                    $percent += 2
                    Start-Sleep -Milliseconds 300
                }

                $installProcess.WaitForExit()
                if ($installProcess.ExitCode -ne 0) {
                    Write-StyledMessage 'Error' "Installazione zoxide fallita (ExitCode: $($installProcess.ExitCode))"
                }
                else {
                    Start-Sleep -Seconds 2
                    Show-ProgressBar "zoxide" "Completato" 100 '⚡'
                    Write-Host ''
                }

                $zox = Get-ChildItem -Path "$env:LOCALAPPDATA" -Filter "zoxide.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($zox) {
                    $zoxPath = [System.IO.Path]::GetFullPath($zox.DirectoryName)
                    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
                    $pathArray = $currentPath -split ';' | ForEach-Object { [System.IO.Path]::GetFullPath($_) } | Where-Object { $_ }
                    if ($pathArray -notcontains $zoxPath) {
                        $newPath = if ($currentPath.EndsWith(';')) { "$currentPath$zoxPath" } else { "$currentPath;$zoxPath" }
                        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
                        Write-StyledMessage 'Success' "Path zoxide aggiunto: $zoxPath"
                    }
                    else {
                        Write-StyledMessage 'Info' "Path zoxide già presente."
                    }
                }
                else {
                    Write-StyledMessage 'Error' "zoxide.exe non trovato! Prova a reinstallarlo: winget install ajeetdsouza.zoxide"
                }
            }
            catch {
                Write-StyledMessage 'Warning' "Errore zoxide: $($_.Exception.Message)"
            }

            # Refresh PATH
            Write-StyledMessage 'Info' "Aggiornamento variabili d'ambiente..."
            $spinnerIndex = 0; $percent = 0
            $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
            $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
            $env:PATH = "$machinePath;$userPath"

            while ($percent -lt 90) {
                Show-ProgressBar "PATH" "Aggiornamento..." $percent '🔧' $spinners[$spinnerIndex++ % $spinners.Length]
                $percent += Get-Random -Minimum 10 -Maximum 20
                Start-Sleep -Milliseconds 200
            }
            Show-ProgressBar "PATH" "Completato" 100 '🔧'
            Write-Host ''

            # Setup profilo
            Write-StyledMessage 'Info' "Configurazione profilo PowerShell..."
            try {
                $spinnerIndex = 0; $percent = 0
                while ($percent -lt 90) {
                    Show-ProgressBar "Profilo" "Setup..." $percent '⚙️' $spinners[$spinnerIndex++ % $spinners.Length]
                    $percent += Get-Random -Minimum 3 -Maximum 8
                    Start-Sleep -Milliseconds 400
                }

                Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1' -UseBasicParsing).Content
                Show-ProgressBar "Profilo" "Completato" 100 '⚙️'
                Write-Host ''
                Write-StyledMessage 'Success' "Profilo installato!"
                # Download e configurazione settings.json per Windows Terminal
                $wtSettingsUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/settings.json"
                $wtPath = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Directory -Filter "Microsoft.WindowsTerminal_*" -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $wtPath) {
                    Write-StyledMessage 'Warning' "Directory Windows Terminal non trovata, impossibile configurare settings.json."
                    return
                }
                $wtLocalStateDir = Join-Path $wtPath.FullName "LocalState"
                if (-not (Test-Path $wtLocalStateDir)) {
                    New-Item -ItemType Directory -Path $wtLocalStateDir -Force | Out-Null
                }
                $settingsPath = Join-Path $wtLocalStateDir "settings.json"

                Write-StyledMessage 'Info' "Download e configurazione settings.json per Windows Terminal..."
                $spinnerIndex = 0; $percent = 0
                try {
                    # Simulazione barra di progresso per il download
                    while ($percent -lt 80) {
                        Show-ProgressBar "settings.json WT" "Download..." $percent '🖼️' $spinners[$spinnerIndex++ % $spinners.Length]
                        $percent += Get-Random -Minimum 5 -Maximum 15
                        Start-Sleep -Milliseconds 200
                    }
                    Invoke-RestMethod $wtSettingsUrl -OutFile $settingsPath -UseBasicParsing -Force
                    $percent = 100 # Assicura che la barra di progresso raggiunga il 100%
                    Show-ProgressBar "settings.json WT" "Completato" 100 '🖼️'
                    Write-Host '' # Aggiunge un newline dopo la barra di progresso
                    Write-StyledMessage 'Success' "settings.json di Windows Terminal aggiornato con successo."
                }
                catch [System.Net.WebException] {
                    Write-StyledMessage 'Error' "Errore di rete durante il download di settings.json: $($_.Exception.Message)"
                }
                catch {
                    Write-StyledMessage 'Error' "Errore durante il download/copia di settings.json: $($_.Exception.Message)"
                }
            }
            catch {
                Write-StyledMessage 'Warning' "Fallback: copia manuale profilo"
                Copy-Item -Path $tempProfile -Destination $PROFILE -Force
                Write-StyledMessage 'Success' "Profilo copiato"
            }

            Write-Host ""
            Write-Host ('═' * 80) -ForegroundColor Green
            Write-StyledMessage 'Warning' "Riavvio OBBLIGATORIO per:"
            Write-Host "  • PATH oh-my-posh e zoxide" -ForegroundColor Cyan
            Write-Host "  • Font installati" -ForegroundColor Cyan
            Write-Host "  • Attivazione profilo" -ForegroundColor Cyan
            Write-Host "  • Variabili d'ambiente" -ForegroundColor Cyan
            Write-Host ('═' * 80) -ForegroundColor Green
            Write-Host ""

            $shouldReboot = Start-InterruptibleCountdown 30 "Riavvio sistema"

            if ($shouldReboot) {
                Write-StyledMessage 'Info' "Riavvio..."
                Restart-Computer -Force
            }
            else {
                Write-Host ""
                Write-Host ('═' * 80) -ForegroundColor Yellow
                Write-StyledMessage 'Warning' "RIAVVIO POSTICIPATO"
                Write-Host ('═' * 80) -ForegroundColor Yellow
                Write-Host ""
                Write-StyledMessage 'Error' "Il profilo NON funzionerà finché non riavvii!"
                Write-Host ""
                Write-StyledMessage 'Info' "Dopo il riavvio, verifica con:"
                Write-Host "  oh-my-posh --version" -ForegroundColor Cyan
                Write-Host "  zoxide --version" -ForegroundColor Cyan
                Write-Host ""
                # Salva stato riavvio necessario
                $rebootFlag = "$env:LOCALAPPDATA\WinToolkit\reboot_required.txt"
                "Riavvio necessario per applicare PATH oh-my-posh/zoxide e profilo PowerShell. Eseguito il $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $rebootFlag -Encoding UTF8
                Write-StyledMessage 'Info' "Flag riavvio salvato in: $rebootFlag"
            }
        }
        else {
            Write-StyledMessage 'Info' "Profilo già aggiornato"
        }


        Remove-Item $tempProfile -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host ''
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage 'Error' "Errore installazione: $($_.Exception.Message)"
        Write-Host ('═' * 65) -ForegroundColor Red
    }
    finally {
        # Pulizia file temporanei
        if (Test-Path $tempProfile) {
            Remove-Item $tempProfile -Force -ErrorAction SilentlyContinue
        }
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
        try { Stop-Transcript | Out-Null } catch {}
    }

}
function WinRepairToolkit {
    <#
    .SYNOPSIS
        Script per la riparazione del sistema Windows con strumenti integrati.

    .DESCRIPTION
        Questo script esegue una serie di strumenti di riparazione di Windows (chkdsk, SFC, DISM) in sequenza,
        con monitoraggio del progresso, gestione degli errori e tentativi di riparazione multipli.
        Al termine, offre un'opzione per una riparazione profonda del disco che richiede un riavvio.
        Infine, gestisce il riavvio del sistema con un conto alla rovescia interattivo.
    #>

    param([int]$MaxRetryAttempts = 3, [int]$CountdownSeconds = 30)

    $Host.UI.RawUI.WindowTitle = "Repair Toolkit By MagnetarMan"
    $script:Log = @(); $script:CurrentAttempt = 0

    # Setup logging specifico per WinRepairToolkit
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\WinRepairToolkit_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }
    $RepairTools = @(
        @{ Tool = 'chkdsk'; Args = @('/scan', '/perf'); Name = 'Controllo disco'; Icon = '💽' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (1)'; Icon = '🗂️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Name = 'Ripristino immagine Windows'; Icon = '🛠️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'); Name = 'Pulizia Residui Aggiornamenti'; Icon = '🕸️' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (2)'; Icon = '🗂️' }
    )

    function Write-StyledMessage {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('Success', 'Warning', 'Error', 'Info')]
            [string]$Type,
            
            [Parameter(Mandatory = $true)]
            [string]$Text
        )

        $style = $MsgStyles[$Type]
        $timestamp = Get-Date -Format "HH:mm:ss"
        
        # Rimuovi emoji duplicati dal testo per il log
        $cleanText = $Text -replace '^[✅⚠️❌💎🔍🚀⚙️🧹📦📋📜📝💾⬇️🔧⚡🖼️🌐🍪🔄🗂️📁🖨️📄🗑️💭⏸️▶️💡⏰🎉💻📊]\s*', ''

        Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color

        # Log automatico
        if ($Type -in @('Info', 'Warning', 'Error', 'Success')) {
            $logEntry = "[$timestamp] [$Type] $cleanText"
            $script:Log += $logEntry
        }
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '▒' * (30 - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi un tasto qualsiasi per annullare...'
        Write-Host ''

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning '⏸️ Riavvio automatico annullato'
                Write-StyledMessage Info "🔄 Puoi riavviare manualmente: 'shutdown /r /t 0' o dal menu Start."
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning '⏰ Tempo scaduto: il sistema verrà riavviato ora.'
        Start-Sleep 1
        return $true
    }

    function Invoke-RepairCommand([hashtable]$Config, [int]$Step, [int]$Total) {
        Write-StyledMessage Info "[$Step/$Total] Avvio $($Config.Name)..."
        $percent = 0; $spinnerIndex = 0; $isChkdsk = ($Config.Tool -ieq 'chkdsk')
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()

        try {
            $proc = if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
                $drive = ($Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1) ?? $env:SystemDrive
                $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }
                Start-Process 'cmd.exe' @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ')") -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
            }
            else {
                Start-Process $Config.Tool $Config.Args -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
            }

            while (-not $proc.HasExited) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                if ($isChkdsk) {
                    Show-ProgressBar $Config.Name 'Esecuzione in corso ...' 0 $Config.Icon $spinner 'Yellow'
                }
                else {
                    if ($percent -lt 95) { $percent += Get-Random -Minimum 1 -Maximum 3 }
                    Show-ProgressBar $Config.Name 'Esecuzione in corso...' $percent $Config.Icon $spinner
                }
                Start-Sleep -Milliseconds 600
                $proc.Refresh()
            }

            $results = @()
            @($outFile, $errFile) | Where-Object { Test-Path $_ } | ForEach-Object {
                $results += Get-Content $_ -ErrorAction SilentlyContinue
            }

            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r') -and
                ($results -join ' ').ToLower() -match 'schedule|next time.*restart|volume.*in use') {
                Write-StyledMessage Info "🔧 $($Config.Name): controllo schedulato al prossimo riavvio"
                return @{ Success = $true; ErrorCount = 0 }
            }

            Show-ProgressBar $Config.Name 'Completato con successo' 100 $Config.Icon
            Write-Host ''

            $exitCode = $proc.ExitCode
            $hasDismSuccess = ($Config.Tool -ieq 'DISM') -and ($results -match '(?i)completed successfully')
            $isSuccess = ($exitCode -eq 0) -or $hasDismSuccess

            $errors = $warnings = @()
            if (-not $isSuccess) {
                foreach ($line in ($results | Where-Object { $_ -and ![string]::IsNullOrWhiteSpace($_.Trim()) })) {
                    $trim = $line.Trim()
                    if ($trim -match '^\[=+\s*\d+' -or $trim -match '(?i)version:|deployment image') { continue }

                    if ($trim -match '(?i)(errore|error|failed|impossibile|corrotto|corruption)') { $errors += $trim }
                    elseif ($trim -match '(?i)(warning|avviso|attenzione)') { $warnings += $trim }
                }
            }

            $success = ($errors.Count -eq 0) -or $hasDismSuccess
            $message = "$($Config.Name) completato " + $(if ($success) { 'con successo' } else { "con $($errors.Count) errori" })
            Write-StyledMessage $(if ($success) { 'Success' } else { 'Warning' }) $message

            return @{ Success = $success; ErrorCount = $errors.Count }

        }
        catch {
            Write-StyledMessage Error "Errore durante $($Config.Name): $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
        finally {
            Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
        }
    }

    function Start-RepairCycle([int]$Attempt = 1) {
        $script:CurrentAttempt = $Attempt
        Write-StyledMessage Info "🔄 Tentativo $Attempt/$MaxRetryAttempts - Riparazione sistema ($($RepairTools.Count) strumenti)..."
        Write-Host ''

        $totalErrors = $successCount = 0
        for ($i = 0; $i -lt $RepairTools.Count; $i++) {
            $result = Invoke-RepairCommand $RepairTools[$i] ($i + 1) $RepairTools.Count
            if ($result.Success) { $successCount++ }
            $totalErrors += $result.ErrorCount
            Start-Sleep 1
        }

        Write-StyledMessage Info "🎯 Completati $successCount/$($RepairTools.Count) strumenti (Errori: $totalErrors)."

        if ($totalErrors -gt 0 -and $Attempt -lt $MaxRetryAttempts) {
            Write-Host ''
            Write-StyledMessage Warning "🔄 $totalErrors errori rilevati. Nuovo tentativo..."
            Start-Sleep 3
            Write-Host ''
            return Start-RepairCycle ($Attempt + 1)
        }

        return @{ Success = ($totalErrors -eq 0); TotalErrors = $totalErrors; AttemptsUsed = $Attempt }
    }

    function Start-DeepDiskRepair {
        Write-StyledMessage Warning '🔧 Vuoi eseguire una riparazione profonda del disco C:?'
        Write-StyledMessage Info 'Questa operazione richiederà un riavvio e può richiedere diverse ore.'

        $response = Read-Host 'Procedere con la riparazione profonda? (s/n)'
        if ($response.ToLower() -ne 's') { return $false }

        Write-StyledMessage Warning 'Segno il volume C: come "dirty" (chkdsk al prossimo riavvio) e apro una cmd per output.'

        try {
            Start-Process 'fsutil.exe' @('dirty', 'set', 'C:') -NoNewWindow -Wait
            Start-Process 'cmd.exe' @('/c', 'echo Y | chkdsk C: /f /r /v /x /b') -WindowStyle Hidden -Wait
            Write-StyledMessage Info 'Comando chkdsk inviato (finestra nascosta). Riavvia il sistema per eseguire la scansione profonda.'
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore eseguendo operazione: $_"
            return $false
        }
    }

    function Set-PasswordExpirationPolicy {
        Write-StyledMessage Info "⚙️ Impostazione della scadenza password a illimitata..."
        try {
            # Esegui il comando
            $process = Start-Process -FilePath "net" -ArgumentList "accounts", "/maxpwage:unlimited" -NoNewWindow -PassThru -Wait
            if ($process.ExitCode -eq 0) {
                Write-StyledMessage Success "✅ Scadenza password impostata a illimitata con successo."
                return $true
            }
            else {
                Write-StyledMessage Warning "⚠️ Impossibile impostare la scadenza password a illimitata. Codice di uscita: $($process.ExitCode)."
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "❌ Errore durante l'impostazione della scadenza password: $($_.Exception.Message)"
            return $false
        }
    }

    function Start-SystemRestart([hashtable]$RepairResult) {
        if ($RepairResult.Success) {
            Write-StyledMessage Info '🎉 Riparazione completata con successo!'
            Write-StyledMessage Info "🎯 Errori risolti in $($RepairResult.AttemptsUsed) tentativo/i."
        }
        else {
            Write-StyledMessage Warning "⚠️ $($RepairResult.TotalErrors) errori persistenti dopo $($RepairResult.AttemptsUsed) tentativo/i."
            Write-StyledMessage Info '📋 Controlla il log sul Desktop. 💡 Il riavvio potrebbe risolvere problemi residui.'
        }

        Write-StyledMessage Info '🔄 Il sistema verrà riavviato per finalizzare le modifiche'

        if (Start-InterruptibleCountdown $CountdownSeconds 'Riavvio automatico') {
            try {
                Write-StyledMessage Info '🔄 Riavvio in corso...'
                Restart-Computer -Force
            }
            catch {
                Write-StyledMessage Error "❌ Errore riavvio: $_"
                Write-StyledMessage Info '🔄 Riavviare manualmente il sistema.'
            }
        }
        else {
            Write-StyledMessage Info '✅ Script completato. Sistema non riavviato.'
            Write-StyledMessage Info '💡 Riavvia quando possibile per applicare le riparazioni.'
        }
    }

    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )
    
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    
        return (' ' * $padding + $Text)
    }
    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '    Repair Toolkit By MagnetarMan',
            '       Version 2.4.2 (Build 3)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    Show-Header

    for ($i = 5; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    try {
        $repairResult = Start-RepairCycle
        $deepRepairScheduled = Start-DeepDiskRepair

        # Impostazione della scadenza password a illimitata
        Set-PasswordExpirationPolicy

        if ($deepRepairScheduled) {
            Write-StyledMessage Warning 'Il sistema verrà riavviato per eseguire la riparazione profonda...'
        }
        Start-SystemRestart $repairResult

    }
    catch {
        Write-StyledMessage Error "❌ Errore critico: $($_.Exception.Message)"
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
        try { Stop-Transcript | Out-Null } catch {}
    }

}
function WinUpdateReset {
    <#
    .SYNOPSIS
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI.

    .DESCRIPTION
        Questo script PowerShell è progettato per riparare i problemi comuni di Windows Update,
        inclusa la reinstallazione di componenti critici come SoftwareDistribution e catroot2.
        Utilizza un'interfaccia utente migliorata con barre di progresso, messaggi stilizzati e
        un conto alla rovescia per il riavvio del sistema che può essere interrotto premendo un tasto.
#>
    param([int]$CountdownSeconds = 15)

    $Host.UI.RawUI.WindowTitle = "Update Reset Toolkit By MagnetarMan"
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()

    # Setup logging
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\WinUpdateReset_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}

    $script:MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    function Write-StyledMessage {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('Success', 'Warning', 'Error', 'Info')]
            [string]$Type,
            
            [Parameter(Mandatory = $true)]
            [string]$Text
        )

        $style = $script:MsgStyles[$Type]
        $timestamp = Get-Date -Format "HH:mm:ss"
        
        # Rimuovi emoji duplicati dal testo per il log
        $cleanText = $Text -replace '^[✅⚠️❌💎🔍🚀⚙️🧹📦📋📜📝💾⬇️🔧⚡🖼️🌐🍪🔄🗂️📁🖨️📄🗑️💭⏸️▶️💡⏰🎉💻📊]\s*', ''

        Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color

        if ($Type -in @('Info', 'Warning', 'Error')) {
            $logEntry = "[$timestamp] [$Type] $cleanText"
            $script:Log += $logEntry
        }
    }

    function Get-CenteredText {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )

        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ '
            '      \ \      / / | || \ | |'
            '       \ \ /\ / /  | ||  \| |'
            '        \ V  V /   | || |\  |'
            '         \_/\_/    |_||_| \_|'
            ''
            ' Update Reset Toolkit By MagnetarMan',
            '       Version 2.4.2 (Build 4)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Get-CenteredText -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $barLength = 30
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * $barLength / 100)
        $empty = '░' * ($barLength - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent
        
        $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
        Write-Host $clearLine -NoNewline
        Write-Host "$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        
        if ($Percent -eq 100) { 
            Write-Host ''
            [Console]::Out.Flush()
        }
    }

    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi qualsiasi tasto per annullare il riavvio automatico...'
        Write-Host ''
        
        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Error '⏸️ Riavvio automatico annullato'
                Write-StyledMessage Info "🔄 Puoi riavviare manualmente con: shutdown /r /t 0"
                return $false
            }
            
            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('░' * $remaining)] $percent%"
            
            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }
        Write-Host "`n"
        Write-StyledMessage Warning '⏰ Tempo scaduto: il sistema verrà riavviato ora.'
        Start-Sleep 1
        return $true
    }

    function Show-ServiceProgress([string]$ServiceName, [string]$Action, [int]$Current, [int]$Total) {
        $percent = [math]::Round(($Current / $Total) * 100)
        $spinnerIndex = ($Current % $spinners.Length)
        $spinner = $spinners[$spinnerIndex]
        Show-ProgressBar "Servizi ($Current/$Total)" "$Action $ServiceName" $percent '⚙️' $spinner 'Cyan'
        Start-Sleep -Milliseconds 200
    }

    function Manage-Service($serviceName, $action, $config, $currentStep, $totalSteps) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            
            if (-not $service) { 
                Write-StyledMessage Warning "$serviceIcon Servizio $serviceName non trovato nel sistema."
                return
            }

            switch ($action) {
                'Stop' { 
                    Show-ServiceProgress $serviceName "Arresto" $currentStep $totalSteps
                    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                    
                    $timeout = 10
                    do {
                        Start-Sleep -Milliseconds 500
                        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                        $timeout--
                    } while ($service.Status -eq 'Running' -and $timeout -gt 0)
                    
                    Write-Host ''
                    Write-StyledMessage Info "$serviceIcon Servizio $serviceName arrestato."
                }
                'Configure' {
                    Show-ServiceProgress $serviceName "Configurazione" $currentStep $totalSteps
                    Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop
                    Write-Host ''
                    Write-StyledMessage Success "$serviceIcon Servizio $serviceName configurato come $($config.Type)."
                }
                'Start' {
                    Show-ServiceProgress $serviceName "Avvio" $currentStep $totalSteps
                    Write-Host ''
                    Start-Service -Name $serviceName -ErrorAction Stop
                    
                    $timeout = 10; $spinnerIndex = 0
                    do {
                        $clearLine = "`r" + (' ' * 80) + "`r"
                        Write-Host $clearLine -NoNewline
                        Write-Host "$($spinners[$spinnerIndex % $spinners.Length]) 🔄 Attesa avvio $serviceName..." -NoNewline -ForegroundColor Yellow
                        Start-Sleep -Milliseconds 300
                        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                        $timeout--; $spinnerIndex++
                    } while ($service.Status -ne 'Running' -and $timeout -gt 0)
                    
                    $clearLine = "`r" + (' ' * 80) + "`r"
                    Write-Host $clearLine -NoNewline
                    
                    if ($service.Status -eq 'Running') {
                        Write-StyledMessage Success "$serviceIcon Servizio ${serviceName}: avviato correttamente."
                    }
                    else {
                        Write-StyledMessage Warning "$serviceIcon Servizio ${serviceName}: avvio in corso..."
                    }
                }
                'Check' {
                    $status = if ($service.Status -eq 'Running') { '🟢 Attivo' } else { '🔴 Inattivo' }
                    $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
                    Write-StyledMessage Info "$serviceIcon $serviceName - Stato: $status"
                }
            }
        }
        catch {
            Write-Host ''
            $actionText = switch ($action) { 'Configure' { 'configurare' } 'Start' { 'avviare' } 'Check' { 'verificare' } default { $action.ToLower() } }
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            Write-StyledMessage Warning "$serviceIcon Impossibile $actionText $serviceName - $($_.Exception.Message)"
        }
    }

    function Remove-DirectorySafely([string]$path, [string]$displayName) {
        if (-not (Test-Path $path)) {
            Write-StyledMessage Info "💭 Directory $displayName non presente."
            return $true
        }

        $originalPos = [Console]::CursorTop
        try {
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue *>$null
            
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline
            [Console]::Out.Flush()
            
            Write-StyledMessage Success "🗑️ Directory $displayName eliminata."
            return $true
        }
        catch {
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline
            
            Write-StyledMessage Warning "Tentativo fallito, provo con eliminazione forzata..."
        
            try {
                $tempDir = [System.IO.Path]::GetTempPath() + "empty_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                $null = New-Item -ItemType Directory -Path $tempDir -Force
                
                $null = Start-Process "robocopy.exe" -ArgumentList "`"$tempDir`" `"$path`" /MIR /NFL /NDL /NJH /NJS /NP /NC" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                Remove-Item $tempDir -Force -ErrorAction SilentlyContinue
                Remove-Item $path -Force -ErrorAction SilentlyContinue
                
                [Console]::SetCursorPosition(0, $originalPos)
                $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                Write-Host $clearLines -NoNewline
                [Console]::Out.Flush()
                
                if (-not (Test-Path $path)) {
                    Write-StyledMessage Success "🗑️ Directory $displayName eliminata (metodo forzato)."
                    return $true
                }
                else {
                    Write-StyledMessage Warning "Directory $displayName parzialmente eliminata."
                    return $false
                }
            }
            catch {
                Write-StyledMessage Warning "Impossibile eliminare completamente $displayName - file in uso."
                return $false
            }
            finally {
                $ErrorActionPreference = 'Continue'
                $ProgressPreference = 'Continue'
                $VerbosePreference = 'SilentlyContinue'
            }
        }
    }

    function Invoke-WPFUpdatesEnable {
        Write-StyledMessage Info '🔧 Inizializzazione ripristino Windows Update...'
        Write-StyledMessage Info '📋 Ripristino impostazioni registro Windows Update...'

        try {
            If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU")) {
                New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
            }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Type DWord -Value 0
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Type DWord -Value 3

            If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config")) {
                New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Force | Out-Null
            }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Type DWord -Value 1

            Write-StyledMessage Success "🔑 Impostazioni registro Windows Update ripristinate."
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile ripristinare alcune chiavi di registro - $($_.Exception.Message)"
        }

        Write-StyledMessage Info '🔧 Ripristino impostazioni WaaSMedicSvc...'

        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Type DWord -Value 3 -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "FailureActions" -ErrorAction SilentlyContinue
            Write-StyledMessage Success "⚙️ Impostazioni WaaSMedicSvc ripristinate."
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile ripristinare WaaSMedicSvc - $($_.Exception.Message)"
        }

        Write-StyledMessage Info '🔄 Ripristino servizi di update...'

        $services = @(
            @{Name = "BITS"; StartupType = "Manual"; Icon = "📡" },
            @{Name = "wuauserv"; StartupType = "Manual"; Icon = "🔄" },
            @{Name = "UsoSvc"; StartupType = "Automatic"; Icon = "🚀" },
            @{Name = "uhssvc"; StartupType = "Disabled"; Icon = "⭕" },
            @{Name = "WaaSMedicSvc"; StartupType = "Manual"; Icon = "🛡️" }
        )

        foreach ($service in $services) {
            try {
                Write-StyledMessage Info "$($service.Icon) Ripristino $($service.Name) a $($service.StartupType)..."
                $serviceObj = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
                if ($serviceObj) {
                    Set-Service -Name $service.Name -StartupType $service.StartupType -ErrorAction SilentlyContinue

                    Start-Process -FilePath "sc.exe" -ArgumentList "failure `"$($service.Name)`" reset= 86400 actions= restart/60000/restart/60000/restart/60000" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

                    if ($service.StartupType -eq "Automatic") {
                        Start-Service -Name $service.Name -ErrorAction SilentlyContinue
                    }

                    Write-StyledMessage Success "$($service.Icon) Servizio $($service.Name) ripristinato."
                }
            }
            catch {
                Write-StyledMessage Warning "Avviso: Impossibile ripristinare servizio $($service.Name) - $($_.Exception.Message)"
            }
        }

        Write-StyledMessage Info '📁 Ripristino DLL rinominate...'

        $dlls = @("WaaSMedicSvc", "wuaueng")

        foreach ($dll in $dlls) {
            $dllPath = "C:\Windows\System32\$dll.dll"
            $backupPath = "C:\Windows\System32\${dll}_BAK.dll"

            if ((Test-Path $backupPath) -and !(Test-Path $dllPath)) {
                try {
                    Start-Process -FilePath "takeown.exe" -ArgumentList "/f `"$backupPath`"" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                    Start-Process -FilePath "icacls.exe" -ArgumentList "`"$backupPath`" /grant *S-1-1-0:F" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                    Rename-Item -Path $backupPath -NewName "$dll.dll" -ErrorAction SilentlyContinue
                    Write-StyledMessage Success "Ripristinato ${dll}_BAK.dll a $dll.dll"
                    Start-Process -FilePath "icacls.exe" -ArgumentList "`"$dllPath`" /setowner `"NT SERVICE\TrustedInstaller`"" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                    Start-Process -FilePath "icacls.exe" -ArgumentList "`"$dllPath`" /remove *S-1-1-0" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                }
                catch {
                    Write-StyledMessage Warning "Avviso: Impossibile ripristinare $dll.dll - $($_.Exception.Message)"
                }
            }
            elseif (Test-Path $dllPath) {
                Write-StyledMessage Info "💭 $dll.dll già presente nella posizione originale."
            }
            else {
                Write-StyledMessage Warning "⚠️ $dll.dll non trovato e nessun backup disponibile."
            }
        }

        Write-StyledMessage Info '📅 Riabilitazione task pianificati...'

        $taskPaths = @(
            '\Microsoft\Windows\InstallService\*'
            '\Microsoft\Windows\UpdateOrchestrator\*'
            '\Microsoft\Windows\UpdateAssistant\*'
            '\Microsoft\Windows\WaaSMedic\*'
            '\Microsoft\Windows\WindowsUpdate\*'
            '\Microsoft\WindowsUpdate\*'
        )

        foreach ($taskPath in $taskPaths) {
            try {
                $tasks = Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue
                foreach ($task in $tasks) {
                    Enable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
                    Write-StyledMessage Success "Task abilitato: $($task.TaskName)"
                }
            }
            catch {
                Write-StyledMessage Warning "Avviso: Impossibile abilitare task in $taskPath - $($_.Exception.Message)"
            }
        }

        Write-StyledMessage Info '🖨️ Abilitazione driver tramite Windows Update...'

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontPromptForWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontSearchWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DriverUpdateWizardWuSearchEnabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
            Write-StyledMessage Success "🖨️ Driver tramite Windows Update abilitati."
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile abilitare driver - $($_.Exception.Message)"
        }

        Write-StyledMessage Info '🔄 Abilitazione riavvio automatico Windows Update...'

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -ErrorAction SilentlyContinue
            Write-StyledMessage Success "🔄 Riavvio automatico Windows Update abilitato."
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile abilitare riavvio automatico - $($_.Exception.Message)"
        }

        Write-StyledMessage Info '⚙️ Ripristino impostazioni Windows Update...'

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "BranchReadinessLevel" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferQualityUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Write-StyledMessage Success "⚙️ Impostazioni Windows Update ripristinate."
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile ripristinare alcune impostazioni - $($_.Exception.Message)"
        }

        Write-StyledMessage Info '📋 Ripristino criteri locali Windows...'

        try {
            Start-Process -FilePath "secedit" -ArgumentList "/configure /cfg $env:windir\inf\defltbase.inf /db defltbase.sdb /verbose" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c RD /S /Q $env:WinDir\System32\GroupPolicyUsers" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c RD /S /Q $env:WinDir\System32\GroupPolicy" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Process -FilePath "gpupdate" -ArgumentList "/force" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

            Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKCU:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKCU:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue

            Write-StyledMessage Success "📋 Criteri locali Windows ripristinati."
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile ripristinare alcuni criteri - $($_.Exception.Message)"
        }
    }

    # Main script
    Show-Header

    Write-StyledMessage Info '🔧 Inizializzazione dello Script di Reset Windows Update...'
    Start-Sleep -Seconds 2

    Write-Host '⚡ Caricamento moduli... ' -NoNewline -ForegroundColor Yellow
    for ($i = 0; $i -lt 15; $i++) {
        Write-Host $spinners[$i % $spinners.Length] -NoNewline -ForegroundColor Yellow
        Start-Sleep -Milliseconds 160
        Write-Host "`b" -NoNewline
    }
    Write-Host '✅ Completato!' -ForegroundColor Green
    Write-Host ''

    Write-StyledMessage Info '🛠️ Avvio riparazione servizi Windows Update...'
    Write-Host ''

    $serviceConfig = @{
        'wuauserv'         = @{ Type = 'Automatic'; Critical = $true; Icon = '🔄'; DisplayName = 'Windows Update' }
        'bits'             = @{ Type = 'Automatic'; Critical = $true; Icon = '📡'; DisplayName = 'Background Intelligent Transfer' }
        'cryptsvc'         = @{ Type = 'Automatic'; Critical = $true; Icon = '🔐'; DisplayName = 'Cryptographic Services' }
        'trustedinstaller' = @{ Type = 'Manual'; Critical = $true; Icon = '🛡️'; DisplayName = 'Windows Modules Installer' }
        'msiserver'        = @{ Type = 'Manual'; Critical = $false; Icon = '📦'; DisplayName = 'Windows Installer' }
    }
    
    $systemServices = @(
        @{ Name = 'appidsvc'; Icon = '🆔'; Display = 'Application Identity' },
        @{ Name = 'gpsvc'; Icon = '📋'; Display = 'Group Policy Client' },
        @{ Name = 'DcomLaunch'; Icon = '🚀'; Display = 'DCOM Server Process Launcher' },
        @{ Name = 'RpcSs'; Icon = '📞'; Display = 'Remote Procedure Call' },
        @{ Name = 'LanmanServer'; Icon = '🖥️'; Display = 'Server' },
        @{ Name = 'LanmanWorkstation'; Icon = '💻'; Display = 'Workstation' },
        @{ Name = 'EventLog'; Icon = '📄'; Display = 'Windows Event Log' },
        @{ Name = 'mpssvc'; Icon = '🛡️'; Display = 'Windows Defender Firewall' },
        @{ Name = 'WinDefend'; Icon = '🔒'; Display = 'Windows Defender Service' }
    )

    try {
        Write-StyledMessage Info '🛑 Arresto servizi Windows Update...'
        $stopServices = @('wuauserv', 'cryptsvc', 'bits', 'msiserver')
        for ($i = 0; $i -lt $stopServices.Count; $i++) {
            Manage-Service $stopServices[$i] 'Stop' $serviceConfig[$stopServices[$i]] ($i + 1) $stopServices.Count
        }
        
        Write-Host ''
        Write-StyledMessage Info '⏳ Attesa liberazione risorse...'
        Start-Sleep -Seconds 3
        Write-Host ''

        Write-StyledMessage Info '⚙️ Ripristino configurazione servizi Windows Update...'
        $criticalServices = $serviceConfig.Keys | Where-Object { $serviceConfig[$_].Critical }
        for ($i = 0; $i -lt $criticalServices.Count; $i++) {
            $serviceName = $criticalServices[$i]
            Write-StyledMessage Info "$($serviceConfig[$serviceName].Icon) Elaborazione servizio: $serviceName"
            Manage-Service $serviceName 'Configure' $serviceConfig[$serviceName] ($i + 1) $criticalServices.Count
        }
        Write-Host ''

        Write-StyledMessage Info '🔍 Verifica servizi di sistema critici...'
        for ($i = 0; $i -lt $systemServices.Count; $i++) {
            $sysService = $systemServices[$i]
            Manage-Service $sysService.Name 'Check' @{ Icon = $sysService.Icon } ($i + 1) $systemServices.Count
        }
        Write-Host ''

        Write-StyledMessage Info '📋 Ripristino chiavi di registro Windows Update...'
        Write-Host '🔄 Elaborazione registro... ' -NoNewline -ForegroundColor Cyan
        for ($i = 0; $i -lt 10; $i++) {
            Write-Host $spinners[$i % $spinners.Length] -NoNewline -ForegroundColor Cyan
            Start-Sleep -Milliseconds 150
            Write-Host "`b" -NoNewline
        }
        try {
            @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update",
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            ) | Where-Object { Test-Path $_ } | ForEach-Object {
                Remove-Item $_ -Recurse -Force -ErrorAction Stop
                Write-Host 'Completato!' -ForegroundColor Green
                Write-StyledMessage Success "🔑 Chiave rimossa: $_"
            }
            if (-not @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update", "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate") | Where-Object { Test-Path $_ }) {
                Write-Host 'Completato!' -ForegroundColor Green
                Write-StyledMessage Info "🔑 Nessuna chiave di registro da rimuovere."
            }
        }
        catch {
            Write-Host 'Errore!' -ForegroundColor Red
            Write-StyledMessage Warning "Errore durante la modifica del registro - $($_.Exception.Message)"
        }
        Write-Host ''

        Write-StyledMessage Info '🗂️ Eliminazione componenti Windows Update...'
        $directories = @(
            @{ Path = "C:\Windows\SoftwareDistribution"; Name = "SoftwareDistribution" },
            @{ Path = "C:\Windows\System32\catroot2"; Name = "catroot2" }
        )
        
        for ($i = 0; $i -lt $directories.Count; $i++) {
            $dir = $directories[$i]
            $percent = [math]::Round((($i + 1) / $directories.Count) * 100)
            Show-ProgressBar "Directory ($($i + 1)/$($directories.Count))" "Eliminazione $($dir.Name)" $percent '🗑️' '' 'Yellow'
            
            Start-Sleep -Milliseconds 300
            
            $success = Remove-DirectorySafely -path $dir.Path -displayName $dir.Name
            if (-not $success) {
                Write-StyledMessage Info "💡 Suggerimento: Alcuni file potrebbero essere ricreati dopo il riavvio."
            }
            
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            [Console]::SetCursorPosition(0, [Console]::CursorTop)
            Start-Sleep -Milliseconds 500
        }

        Write-Host ''
        [Console]::Out.Flush()
        [Console]::SetCursorPosition(0, [Console]::CursorTop)

        Write-StyledMessage Info '🚀 Avvio servizi essenziali...'
        $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
        for ($i = 0; $i -lt $essentialServices.Count; $i++) {
            Manage-Service $essentialServices[$i] 'Start' $serviceConfig[$essentialServices[$i]] ($i + 1) $essentialServices.Count
        }
        Write-Host ''

        Write-StyledMessage Info '🔄 Reset del client Windows Update...'
        Write-Host '⚡ Esecuzione comando reset... ' -NoNewline -ForegroundColor Magenta
        try {
            Start-Process "cmd.exe" -ArgumentList "/c wuauclt /resetauthorization /detectnow" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            Write-Host 'Completato!' -ForegroundColor Green
            Write-StyledMessage Success "🔄 Client Windows Update reimpostato."
        }
        catch {
            Write-Host 'Errore!' -ForegroundColor Red
            Write-StyledMessage Warning "Errore durante il reset del client Windows Update."
        }
        Write-Host ''

        Write-StyledMessage Info '🔧 Abilitazione Windows Update e servizi correlati...'
        Invoke-WPFUpdatesEnable
        Write-Host ''

        Write-Host ('═' * 65) -ForegroundColor Green
        Write-StyledMessage Success '🎉 Riparazione completata con successo!'
        Write-StyledMessage Success '💻 Il sistema necessita di un riavvio per applicare tutte le modifiche.'
        Write-StyledMessage Warning "⚡ Attenzione: il sistema verrà riavviato automaticamente"
        Write-Host ('═' * 65) -ForegroundColor Green
        Write-Host ''
        
        $shouldReboot = Start-InterruptibleCountdown $CountdownSeconds "Preparazione riavvio sistema"
        
        if ($shouldReboot) {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
            Restart-Computer -Force
        }
    }
    catch {
        Write-Host ''
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage Error "💥 Errore critico: $($_.Exception.Message)"
        Write-StyledMessage Error '❌ Si è verificato un errore durante la riparazione.'
        Write-StyledMessage Info '🔍 Controlla i messaggi sopra per maggiori dettagli.'
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage Info '⌨️ Premere un tasto per uscire...'
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        try { Stop-Transcript | Out-Null } catch {}
    }

}
function WinReinstallStore {

    <#
    .SYNOPSIS
        Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget.

    .DESCRIPTION
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI senza output bloccanti.

#>
    param([int]$CountdownSeconds = 30, [switch]$NoReboot)

    $Host.UI.RawUI.WindowTitle = "Store Repair Toolkit By MagnetarMan"

    # Setup logging specifico per WinReinstallStore
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\WinReinstallStore_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}
    
    $script:MsgStyles = @{
        Success  = @{ Color = 'Green'; Icon = '✅' }
        Warning  = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error    = @{ Color = 'Red'; Icon = '❌' }
        Info     = @{ Color = 'Cyan'; Icon = '💎' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }
    
    function Write-StyledMessage {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Progress')]
            [string]$Type,
            
            [Parameter(Mandatory = $true)]
            [string]$Text
        )

        $style = $script:MsgStyles[$Type]
        $timestamp = Get-Date -Format "HH:mm:ss"
        
        # Rimuovi emoji duplicati dal testo per il log
        $cleanText = $Text -replace '^[✅⚠️❌💎🔍🚀⚙️🧹📦📋📜📝💾⬇️🔧⚡🖼️🌐🍪🔄🗂️📁🖨️📄🗑️💭⏸️▶️💡⏰🎉💻📊]\s*', ''

        Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color

        if ($Type -in @('Info', 'Warning', 'Error')) {
            $logEntry = "[$timestamp] [$Type] $cleanText"
            $script:Log += $logEntry
        }
    }
    
    function Get-CenteredText {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )

        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ '
            '      \ \      / / | || \ | |'
            '       \ \ /\ / /  | ||  \| |'
            '        \ V  V /   | || |\  |'
            '         \_/\_/    |_||_| \_|'
            ''
            ' Store Repair Toolkit By MagnetarMan',
            '       Version 2.4.2 (Build 6)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Get-CenteredText -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }
    
    function Clear-Terminal {
        1..50 | ForEach-Object { Write-Host "" }
        Clear-Host
        [Console]::Clear()
        try {
            [System.Console]::SetCursorPosition(0, 0)
            $Host.UI.RawUI.CursorPosition = @{X = 0; Y = 0 }
        }
        catch {}
        Start-Sleep -Milliseconds 200
    }
    
    function Stop-InterferingProcesses {
        @("WinStore.App", "wsappx", "AppInstaller", "Microsoft.WindowsStore",
            "Microsoft.DesktopAppInstaller", "RuntimeBroker", "dllhost") | ForEach-Object {
            Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep 2
    }
    
    function Test-WingetAvailable {
        try {
            $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $null = & winget --version 2>$null
            return $LASTEXITCODE -eq 0
        }
        catch { return $false }
    }
    
    function Install-WingetSilent {
        Write-StyledMessage Progress "🚀 Avvio della procedura di reinstallazione e riparazione Winget..."
        Stop-InterferingProcesses

        $originalPos = [Console]::CursorTop
        try {
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'

            # --- FASE 1: Inizializzazione e Pulizia Profonda ---
            
            # Terminazione Processi
            Write-StyledMessage Progress "Chiusura forzata dei processi Winget e correlati..."
            @("winget", "WindowsPackageManagerServer") | ForEach-Object {
                Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                taskkill /im "$_.exe" /f 2>$null
            }
            Start-Sleep 2

            # Pulizia Cartella Temporanea
            Write-StyledMessage Progress "Pulizia dei file temporanei (%TEMP%\WinGet)..."
            $tempWingetPath = "$env:TEMP\WinGet"
            if (Test-Path $tempWingetPath) {
                Remove-Item -Path $tempWingetPath -Recurse -Force -ErrorAction SilentlyContinue *>$null
                Write-StyledMessage Info "Cartella temporanea di Winget eliminata."
            }
            else {
                Write-StyledMessage Info "Cartella temporanea di Winget non trovata o già pulita."
            }

            # Reset Sorgenti Winget
            Write-StyledMessage Progress "Reset delle sorgenti di Winget..."
            $wingetExePath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
            if (Test-Path $wingetExePath) {
                & $wingetExePath source reset --force *>$null
            }
            else {
                winget source reset --force *>$null
            }
            Write-StyledMessage Info "Sorgenti Winget resettate."

            # --- FASE 2: Installazione Dipendenze e Moduli PowerShell ---
            
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            # Installazione Provider NuGet
            Write-StyledMessage Progress "Installazione del PackageProvider NuGet..."
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                Write-StyledMessage Success "Provider NuGet installato/verificato."
            }
            catch {
                Write-StyledMessage Warning "Nota: Il provider NuGet potrebbe essere già installato o richiedere conferma manuale."
            }

            # Installazione Modulo Microsoft.WinGet.Client
            Write-StyledMessage Progress "Installazione e importazione del modulo Microsoft.WinGet.Client..."
            Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction SilentlyContinue *>$null
            Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
            Write-StyledMessage Success "Modulo Microsoft.WinGet.Client installato e importato."

            # --- FASE 3: Riparazione e Reinstallazione del Core di Winget ---

            # Tentativo A (Riparazione via Modulo)
            Write-StyledMessage Progress "Tentativo di riparazione Winget tramite il modulo WinGet Client..."
            if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                $null = Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                Start-Sleep 5
                if (Test-WingetAvailable) {
                    Write-StyledMessage Success "Winget riparato con successo tramite modulo."
                    # Procedi al reset Appx
                }
            }

            # Tentativo B (Reinstallazione tramite MSIXBundle - Fallback)
            if (-not (Test-WingetAvailable)) {
                Write-StyledMessage Progress "Scarico e installo Winget tramite MSIXBundle (metodo fallback)..."
                $url = "https://aka.ms/getwinget"
                $temp = "$env:TEMP\WingetInstaller.msixbundle"
                if (Test-Path $temp) { Remove-Item $temp -Force *>$null }

                Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing *>$null
                $process = Start-Process powershell -ArgumentList @(
                    "-NoProfile", "-WindowStyle", "Hidden", "-Command",
                    "try { Add-AppxPackage -Path '$temp' -ForceApplicationShutdown -ErrorAction Stop } catch { exit 1 }; exit 0"
                ) -Wait -PassThru -WindowStyle Hidden

                Remove-Item $temp -Force -ErrorAction SilentlyContinue *>$null
                Start-Sleep 5
                if (Test-WingetAvailable) {
                    Write-StyledMessage Success "Winget installato con successo tramite MSIXBundle."
                }
            }

            # --- FASE 4: Reset dell'App Installer Appx ---
            Write-StyledMessage Progress "Reset dell'App 'Programma di installazione app' (Microsoft.DesktopAppInstaller)..."
            try {
                Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage *>$null
                Write-StyledMessage Success "App 'Programma di installazione app' resettata con successo."
            }
            catch {
                Write-StyledMessage Warning "Impossibile resettare l'App 'Programma di installazione app'. Errore: $($_.Exception.Message)"
            }

            # --- FASE 5: Gestione Output Finale e Valore di Ritorno ---
            
            # Reset cursore e flush output
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            
            Start-Sleep 2
            $finalCheck = Test-WingetAvailable
            
            if ($finalCheck) {
                Write-StyledMessage Success "Winget è stato processato e sembra funzionante."
                return $true
            }
            else {
                Write-StyledMessage Error "❌ Impossibile installare o riparare Winget dopo tutti i tentativi."
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore critico in Install-WingetSilent: $($_.Exception.Message)"
            return $false
        }
        finally {
            # Reset delle preferenze
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
            $VerbosePreference = 'SilentlyContinue'
        }
    }
    
    function Install-MicrosoftStoreSilent {
        Write-StyledMessage Progress "Reinstallazione Microsoft Store in corso..."
        
        $originalPos = [Console]::CursorTop
        try {
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            
            @("AppXSvc", "ClipSVC", "WSService") | ForEach-Object {
                try { Restart-Service $_ -Force -ErrorAction SilentlyContinue *>$null } catch {}
            }

            @("$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
                "$env:LOCALAPPDATA\Microsoft\Windows\INetCache") | ForEach-Object {
                if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue *>$null }
            }

            $methods = @(
                {
                    if (Test-WingetAvailable) {
                        $process = Start-Process winget -ArgumentList "install 9WZDNCRFJBMP --accept-source-agreements --accept-package-agreements --silent --disable-interactivity" -Wait -PassThru -WindowStyle Hidden
                        return $process.ExitCode -eq 0
                    }
                    return $false
                },
                {
                    $store = Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue
                    if ($store) {
                        $store | ForEach-Object {
                            $manifest = "$($_.InstallLocation)\AppXManifest.xml"
                            if (Test-Path $manifest) {
                                $process = Start-Process powershell -ArgumentList @(
                                    "-NoProfile", "-WindowStyle", "Hidden", "-Command",
                                    "Add-AppxPackage -DisableDevelopmentMode -Register '$manifest' -ForceApplicationShutdown"
                                ) -Wait -PassThru -WindowStyle Hidden
                            }
                        }
                        return $true
                    }
                    return $false
                },
                {
                    $process = Start-Process DISM -ArgumentList "/Online /Add-Capability /CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0" -Wait -PassThru -WindowStyle Hidden
                    return $process.ExitCode -eq 0
                }
            )

            foreach ($method in $methods) {
                try {
                    if (& $method) {
                        Start-Process wsreset.exe -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue *>$null
                        
                        # Reset cursore e flush output
                        [Console]::SetCursorPosition(0, $originalPos)
                        $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                        Write-Host $clearLine -NoNewline
                        [Console]::Out.Flush()
                        
                        return $true
                    }
                }
                catch { continue }
            }
            return $false
        }
        finally {
            # Reset delle preferenze
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
            $VerbosePreference = 'SilentlyContinue'
        }
    }
    
    function Install-UniGetUISilent {
        Write-StyledMessage Progress "Reinstallazione UniGet UI in corso..."
        if (-not (Test-WingetAvailable)) { return $false }

        $originalPos = [Console]::CursorTop
        try {
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            
            $process = Start-Process winget -ArgumentList "install --exact --id MartiCliment.UniGetUI --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity --force" -Wait -PassThru -WindowStyle Hidden
    
            if ($process.ExitCode -eq 0) {
                Write-StyledMessage Progress "Disabilitazione avvio automatico UniGet UI..."
                try {
                    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                    $regKeyName = "WingetUI"
                    if (Test-Path -Path "$regPath\$regKeyName") {
                        Remove-ItemProperty -Path $regPath -Name $regKeyName -ErrorAction Stop | Out-Null
                        Write-StyledMessage Success "Avvio automatico UniGet UI disabilitato."
                    }
                    else {
                        Write-StyledMessage Info "La voce di avvio automatico per UniGet UI non è stata trovata o non è necessaria."
                    }
                }
                catch {
                    Write-StyledMessage Warning "Impossibile disabilitare l'avvio automatico di UniGet UI: $($_.Exception.Message)"
                }
            }
    
            # Reset cursore e flush output
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            
            return $process.ExitCode -eq 0
        }
        catch {
            return $false
        }
        finally {
            # Reset delle preferenze
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
            $VerbosePreference = 'SilentlyContinue'
        }
    }
    
    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Warning "$Message"
        Write-StyledMessage Info '💡 Premi un tasto qualsiasi per annullare...'

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning "⏸️ Riavvio automatico annullato"
                Write-StyledMessage Error 'Riavvia manualmente: shutdown /r /t 0'
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."

        if (-not $NoReboot) {
            try {
                shutdown /r /t 0
                return $true
            }
            catch {
                Write-StyledMessage Error "Errore riavvio: $_"
                return $false
            }
        }
        else {
            Write-StyledMessage Info "🚫 Riavvio saltato come richiesto."
            return $false
        }
    }
    
    Show-Header
    Write-StyledMessage Info "🚀 AVVIO REINSTALLAZIONE STORE"

    try {
        $wingetResult = Install-WingetSilent
        Write-StyledMessage $(if ($wingetResult) { 'Success' }else { 'Warning' }) "Winget $(if($wingetResult){'installato'}else{'processato'})"

        $storeResult = Install-MicrosoftStoreSilent
        if (-not $storeResult) {
            Write-StyledMessage Error "Errore installazione Microsoft Store"
            Write-StyledMessage Info "Verifica: Internet, Admin, Windows Update"
            return
        }
        Write-StyledMessage Success "Microsoft Store installato"

        $unigetResult = Install-UniGetUISilent
        Write-StyledMessage $(if ($unigetResult) { 'Success' }else { 'Warning' }) "UniGet UI $(if($unigetResult){'installato'}else{'processato'})"

        Write-Host ""
        Write-StyledMessage Success "🎉 OPERAZIONE COMPLETATA"

        if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio necessario per applicare le modifiche") {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
        }
    }
    catch {
        Clear-Terminal
        Show-Header
        Write-StyledMessage Error "❌ ERRORE: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Esegui come Admin, verifica Internet e Windows Update"
        try { Stop-Transcript | Out-Null } catch {}
    }

}
function WinBackupDriver {
    <#
    .SYNOPSIS
        Strumento di backup completo per i driver di sistema Windows.

    .DESCRIPTION
        Script PowerShell per eseguire il backup completo di tutti i driver di terze parti
        installati sul sistema. Il processo include l'esportazione tramite DISM, compressione
        in formato ZIP e spostamento automatico sul desktop con nomenclatura data-based.
        Ideale per il backup pre-format o per la migrazione dei driver su un nuovo sistema.
    #>

    param([int]$CountdownSeconds = 10)

    $Host.UI.RawUI.WindowTitle = "Driver Backup Toolkit By MagnetarMan"

    # Setup logging specifico per WinBackupDriver
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\WinBackupDriver_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}
    # Configurazione
    $BackupDir = "$env:LOCALAPPDATA\WinToolkit\Driver Backup"
    $ZipName = "DriverBackup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
    $FinalZipPath = Join-Path $DesktopPath "$ZipName.zip"

    $MsgStyles = @{
        Success  = @{ Color = 'Green'; Icon = '✅' }
        Warning  = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error    = @{ Color = 'Red'; Icon = '❌' }
        Info     = @{ Color = 'Cyan'; Icon = '💎' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }

    # Funzione per centrare il testo
    function Center-Text {
        param(
            [Parameter(Mandatory = $true)][string]$Text,
            [Parameter(Mandatory = $false)][int]$Width = $Host.UI.RawUI.BufferSize.Width
        )
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent) {
        $safePercent = [Math]::Max(0, [Math]::Min(100, $Percent))
        $filled = [Math]::Floor($safePercent * 30 / 100)
        $bar = "[$('█' * $filled)$('▒' * (30 - $filled))] $safePercent%"
        Write-Host "`r🔄 $Activity $bar $Status" -NoNewline -ForegroundColor Magenta
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '   Driver Backup Toolkit By MagnetarMan',
            '       Version 2.2.4 (Build 1)'
        )

        foreach ($line in $asciiArt) {
            if ($line -ne '') {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
            else {
                Write-Host ''
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    function Test-Administrator {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Start-DriverExport {
        Write-StyledMessage Info "💾 Avvio esportazione driver di terze parti..."

        try {
            # Verifica se la cartella esiste già
            if (Test-Path $BackupDir) {
                Write-StyledMessage Warning "Cartella backup esistente trovata, rimozione in corso..."
                
                $originalPos = [Console]::CursorTop
                # Soppressione completa dell'output
                $ErrorActionPreference = 'SilentlyContinue'
                $ProgressPreference = 'SilentlyContinue'
                $VerbosePreference = 'SilentlyContinue'
                
                Remove-Item $BackupDir -Recurse -Force -ErrorAction SilentlyContinue *>$null
                
                # Reset cursore e flush output
                [Console]::SetCursorPosition(0, $originalPos)
                $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                Write-Host $clearLine -NoNewline
                [Console]::Out.Flush()
                
                # Reset delle preferenze
                $ErrorActionPreference = 'Continue'
                $ProgressPreference = 'Continue'
                $VerbosePreference = 'SilentlyContinue'
                
                Start-Sleep 1
            }

            # Crea la cartella di backup
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            Write-StyledMessage Success "Cartella backup creata: $BackupDir"

            # Esegue l'esportazione DISM
            Write-StyledMessage Info "🔧 Esecuzione DISM per esportazione driver..."
            Write-StyledMessage Info "💡 Questa operazione può richiedere diversi minuti..."

            $dismArgs = @('/online', '/export-driver', "/destination:`"$BackupDir`"")

            $process = Start-Process 'dism.exe' -ArgumentList $dismArgs -NoNewWindow -PassThru -Wait

            if ($process.ExitCode -eq 0) {
                # Verifica se sono stati esportati dei driver
                $exportedDrivers = Get-ChildItem -Path $BackupDir -Recurse -File -ErrorAction SilentlyContinue

                if ($exportedDrivers -and $exportedDrivers.Count -gt 0) {
                    Write-StyledMessage Success "Driver esportati con successo!"
                    Write-StyledMessage Info "Driver trovati: $($exportedDrivers.Count)"
                    return $true
                }
                else {
                    Write-StyledMessage Warning "Nessun driver di terze parti trovato da esportare"
                    Write-StyledMessage Info "💡 I driver integrati di Windows non vengono esportati"
                    return $true
                }
            }
            else {
                Write-StyledMessage Error "Errore durante esportazione DISM (Exit code: $($process.ExitCode))"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante esportazione driver: $_"
            return $false
        }
    }

    function Start-DriverCompression {
        Write-StyledMessage Info "📦 Compressione cartella backup..."

        try {
            # Verifica che la cartella esista e contenga file
            if (-not (Test-Path $BackupDir)) {
                Write-StyledMessage Error "Cartella backup non trovata"
                return $false
            }

            $files = Get-ChildItem -Path $BackupDir -Recurse -File -ErrorAction SilentlyContinue
            if (-not $files -or $files.Count -eq 0) {
                Write-StyledMessage Warning "Nessun file da comprimere nella cartella backup"
                return $false
            }

            # Calcola dimensione totale per la progress bar
            $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
            $totalSizeMB = [Math]::Round($totalSize / 1MB, 2)

            Write-StyledMessage Info "Dimensione totale: $totalSizeMB MB"

            # Crea il file ZIP
            $tempZipPath = Join-Path $env:TEMP "$ZipName.zip"

            # Rimuovi file ZIP esistente se presente
            if (Test-Path $tempZipPath) {
                Remove-Item $tempZipPath -Force -ErrorAction SilentlyContinue
            }

            # Comprime la cartella
            Write-StyledMessage Info "🔄 Compressione in corso..."

            $progress = 0
            $compressAction = {
                param($backupDir, $tempZipPath)
                Compress-Archive -Path $backupDir -DestinationPath $tempZipPath -CompressionLevel Optimal -Force
            }

            $job = Start-Job -ScriptBlock $compressAction -ArgumentList $BackupDir, $tempZipPath

            while ($job.State -eq 'Running') {
                $progress += Get-Random -Minimum 1 -Maximum 5
                if ($progress -gt 95) { $progress = 95 }

                Show-ProgressBar "Compressione" "Elaborazione file..." $progress
                Start-Sleep -Milliseconds 500
            }

            $compressResult = Receive-Job $job -Wait
            Remove-Job $job

            Show-ProgressBar "Compressione" "Completato!" 100
            Write-Host ''

            # Verifica che il file ZIP sia stato creato
            if (Test-Path $tempZipPath) {
                $zipSize = (Get-Item $tempZipPath).Length
                $zipSizeMB = [Math]::Round($zipSize / 1MB, 2)

                Write-StyledMessage Success "Compressione completata!"
                Write-StyledMessage Info "Archivio creato: $tempZipPath ($zipSizeMB MB)"

                return $tempZipPath
            }
            else {
                Write-StyledMessage Error "File ZIP non creato"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante compressione: $_"
            return $false
        }
    }

    function Move-ZipToDesktop {
        param([string]$ZipPath)

        Write-StyledMessage Info "📂 Spostamento archivio sul desktop..."

        try {
            # Verifica che il file ZIP esista
            if (-not (Test-Path $ZipPath)) {
                Write-StyledMessage Error "File ZIP non trovato: $ZipPath"
                return $false
            }

            # Sposta il file sul desktop
            Move-Item -Path $ZipPath -Destination $FinalZipPath -Force -ErrorAction Stop

            # Verifica che il file sia stato spostato
            if (Test-Path $FinalZipPath) {
                Write-StyledMessage Success "Archivio spostato sul desktop!"
                Write-StyledMessage Info "Posizione: $FinalZipPath"
                return $true
            }
            else {
                Write-StyledMessage Error "Errore durante spostamento sul desktop"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore spostamento: $_"
            return $false
        }
    }

    function Show-BackupSummary {
        param([string]$ZipPath)

        Write-Host ''
        Write-StyledMessage Success "🎉 Backup driver completato con successo!"
        Write-Host ''

        Write-StyledMessage Info "📁 Posizione archivio:"
        Write-Host "  $FinalZipPath" -ForegroundColor Cyan
        Write-Host ''

        Write-StyledMessage Info "💡 IMPORTANTE:"
        Write-StyledMessage Info "  🔄 Salva questo archivio in un luogo sicuro!"
        Write-StyledMessage Info "  💾 Potrai utilizzarlo per reinstallare tutti i driver"
        Write-StyledMessage Info "  🔧 Senza doverli riscaricare singolarmente"
        Write-Host ''
    }

    # MAIN EXECUTION
    Show-Header

    # Verifica privilegi amministrativi
    if (-not (Test-Administrator)) {
        Write-StyledMessage Error " Questo script richiede privilegi amministrativi!"
        Write-StyledMessage Info "💡 Riavvia PowerShell come Amministratore e riprova"
        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        return
    }

    Write-Host "⏳ Inizializzazione sistema..." -ForegroundColor Yellow
    Start-Sleep 2
    Write-Host Success "✅ Sistema pronto`n" -ForegroundColor Green

    try {
        # Passo 1: Esportazione driver
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 FASE 1: ESPORTAZIONE DRIVER"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        if (-not (Start-DriverExport)) {
            Write-StyledMessage Error "Esportazione driver fallita"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }

        Write-Host ''
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 FASE 2: COMPRESSIONE ARCHIVIO"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        # Passo 2: Compressione
        $zipPath = Start-DriverCompression
        if (-not $zipPath) {
            Write-StyledMessage Error "Compressione fallita"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }

        Write-Host ''
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 FASE 3: SPOSTAMENTO DESKTOP"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        # Passo 3: Spostamento sul desktop
        if (-not (Move-ZipToDesktop $zipPath)) {
            Write-StyledMessage Error "Spostamento sul desktop fallito"
            Write-StyledMessage Warning "💡 L'archivio potrebbe essere ancora nella cartella temporanea"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }

        # Passo 4: Riepilogo finale
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 BACKUP COMPLETATO"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        Show-BackupSummary $FinalZipPath

    }
    catch {
        Write-StyledMessage Error "Errore critico durante il backup: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Controlla i log per dettagli o contatta il supporto"
    }
    finally {
        # Pulizia cartella temporanea
        Write-StyledMessage Info "🧹 Pulizia cartella temporanea..."
        if (Test-Path $BackupDir) {
            $originalPos = [Console]::CursorTop
            
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            
            Remove-Item $BackupDir -Recurse -Force -ErrorAction SilentlyContinue *>$null
            
            # Reset cursore e flush output
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            
            # Reset delle preferenze
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
            $VerbosePreference = 'SilentlyContinue'
        }

        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        Write-StyledMessage Success "🎯 Driver Backup Toolkit terminato"
        try { Stop-Transcript | Out-Null } catch {}
    }

}
function WinDriverInstall {}
function OfficeToolkit {
    <#
    .SYNOPSIS
        Strumento di gestione Microsoft Office (installazione, riparazione, rimozione)

    .DESCRIPTION
        Script PowerShell per gestire Microsoft Office tramite interfaccia utente semplificata.
        Supporta installazione Office Basic, riparazione Click-to-Run e rimozione automatica basata sulla versione Windows.
    #>

    param([int]$CountdownSeconds = 30)

    # Configurazione
    $TempDir = "$env:LOCALAPPDATA\WinToolkit\Office"
    $Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()

    # Setup logging
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\OfficeToolkit_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}

    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💡' }
    }

    # Funzioni Helper
    function Write-StyledMessage([string]$Type, [string]$Message) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Message" -ForegroundColor $style.Color
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent) {
        $safePercent = [Math]::Max(0, [Math]::Min(100, $Percent))
        $filled = [Math]::Floor($safePercent * 30 / 100)
        $bar = "[$('█' * $filled)$('░' * (30 - $filled))] $safePercent%"
        Write-Host "`r📊 $Activity $bar $Status" -NoNewline -ForegroundColor Yellow
        if ($Percent -eq 100) {
            Write-Host ''
            [Console]::Out.Flush()
        }
        else {
            [Console]::Out.Flush()
        }
    }

    function Clear-ConsoleLine {
        $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
        Write-Host $clearLine -NoNewline
        [Console]::Out.Flush()
    }

    function Clear-ConsoleLines([int]$Lines = 1) {
        for ($i = 0; $i -lt $Lines; $i++) {
            Clear-ConsoleLine
        }
    }

    function Invoke-SilentRemoval {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,
            [switch]$Recurse
        )

        if (-not (Test-Path $Path)) { return $false }

        try {
            $originalPos = [Console]::CursorTop
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            
            if ($Recurse) {
                Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue *>$null
            }
            else {
                Remove-Item $Path -Force -ErrorAction SilentlyContinue *>$null
            }
            
            [Console]::SetCursorPosition(0, $originalPos)
            Clear-ConsoleLine
            
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
            
            return $true
        }
        catch {
            return $false
        }
    }

    function Show-Spinner([string]$Activity, [scriptblock]$Action) {
        $spinnerIndex = 0
        $job = Start-Job -ScriptBlock $Action

        while ($job.State -eq 'Running') {
            $spinner = $Spinners[$spinnerIndex++ % $Spinners.Length]
            Write-Host "`r$spinner $Activity..." -NoNewline -ForegroundColor Yellow
            [Console]::Out.Flush()
            Start-Sleep -Milliseconds 200
        }

        $result = Receive-Job $job -Wait
        Remove-Job $job
        Clear-ConsoleLine
        Write-Host "✅ $Activity completato" -ForegroundColor Green
        [Console]::Out.Flush()
        return $result
    }

    function Get-UserConfirmation([string]$Message, [string]$DefaultChoice = 'N') {
        do {
            $response = Read-Host "$Message [Y/N]"
            if ([string]::IsNullOrEmpty($response)) { $response = $DefaultChoice }
            $response = $response.ToUpper()
        } while ($response -notin @('Y', 'N'))
        return $response -eq 'Y'
    }

    function Get-WindowsVersion {
        try {
            $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
            $buildNumber = [int]$osInfo.BuildNumber

            if ($buildNumber -ge 22631) {
                return "Windows11_23H2_Plus"
            }
            elseif ($buildNumber -ge 22000) {
                return "Windows11_22H2_Or_Older"
            }
            else {
                return "Windows10_Or_Older"
            }
        }
        catch {
            Write-StyledMessage Warning "Impossibile rilevare versione Windows: $_"
            return "Unknown"
        }
    }

    function Start-CountdownRestart([string]$Reason) {
        Write-StyledMessage Info "🔄 $Reason - Il sistema verrà riavviato"
        Write-StyledMessage Info "💡 Premi un tasto qualsiasi per annullare..."

        for ($i = $CountdownSeconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning "⏸️ Riavvio annullato dall'utente"
                return $false
            }

            $percent = [Math]::Round((($CountdownSeconds - $i) / $CountdownSeconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('░' * $remaining)] $percent%"

            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            [Console]::Out.Flush()
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."

        try {
            Restart-Computer -Force
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore riavvio: $_"
            return $false
        }
    }

    function Stop-OfficeProcesses {
        $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
        $closed = 0

        Write-StyledMessage Info "📋 Chiusura processi Office..."
        foreach ($processName in $processes) {
            $runningProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($runningProcesses) {
                try {
                    $runningProcesses | Stop-Process -Force -ErrorAction Stop
                    $closed++
                }
                catch {
                    Write-StyledMessage Warning "Impossibile chiudere: $processName"
                }
            }
        }

        if ($closed -gt 0) {
            Write-StyledMessage Success "$closed processi Office chiusi"
        }
    }

    function Invoke-DownloadFile([string]$Url, [string]$OutputPath, [string]$Description) {
        try {
            Write-StyledMessage Info "📥 Download $Description..."
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $OutputPath)
            $webClient.Dispose()

            if (Test-Path $OutputPath) {
                Write-StyledMessage Success "Download completato: $Description"
                return $true
            }
            else {
                Write-StyledMessage Error "File non trovato dopo download: $Description"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore download $Description`: $_"
            return $false
        }
    }

    function Start-OfficeInstallation {
        Write-StyledMessage Info "🏢 Avvio installazione Office Basic..."

        try {
            if (-not (Test-Path $TempDir)) {
                New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
            }

            $setupPath = Join-Path $TempDir 'Setup.exe'
            $configPath = Join-Path $TempDir 'Basic.xml'

            $downloads = @(
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Setup.exe'; Path = $setupPath; Name = 'Setup Office' },
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Basic.xml'; Path = $configPath; Name = 'Configurazione Basic' }
            )

            foreach ($download in $downloads) {
                if (-not (Invoke-DownloadFile $download.Url $download.Path $download.Name)) {
                    return $false
                }
            }

            Write-StyledMessage Info "🚀 Avvio processo installazione..."
            $arguments = "/configure `"$configPath`""
            Start-Process -FilePath $setupPath -ArgumentList $arguments -WorkingDirectory $TempDir

            Write-StyledMessage Info "⏳ Attesa completamento installazione..."
            Write-Host "💡 Premi INVIO quando l'installazione è completata..." -ForegroundColor Yellow
            Read-Host | Out-Null

            if (Get-UserConfirmation "✅ Installazione completata con successo?" 'Y') {
                # Nuove configurazioni post-installazione: Disabilitazione Telemetria e Notifiche Crash
                Write-StyledMessage Info "⚙️ Configurazione post-installazione Office..."

                Show-Spinner -Activity "Disabilitazione telemetria Office" -Action {
                    $RegPathTelemetry = "HKLM:\SOFTWARE\Microsoft\Office\Common\ClientTelemetry"
                    if (-not (Test-Path $RegPathTelemetry)) { New-Item $RegPathTelemetry -Force | Out-Null }
                    Set-ItemProperty -Path $RegPathTelemetry -Name "DisableTelemetry" -Value 1 -Type DWord -Force
                }

                Show-Spinner -Activity "Disabilitazione notifiche crash Office" -Action {
                    $RegPathFeedback = "HKLM:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback"
                    if (-not (Test-Path $RegPathFeedback)) { New-Item $RegPathFeedback -Force | Out-Null }
                    Set-ItemProperty -Path $RegPathFeedback -Name "OnBootNotify" -Value 0 -Type DWord -Force
                }
                # Fine nuove configurazioni

                Write-StyledMessage Success "🎉 Installazione Office completata!"
                return $true
            }
            else {
                Write-StyledMessage Warning "Installazione non completata correttamente"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante installazione: $_"
            return $false
        }
        finally {
            Invoke-SilentRemoval -Path $TempDir -Recurse
        }
    }

    function Start-OfficeRepair {
        Write-StyledMessage Info "🔧 Avvio riparazione Office..."
        Stop-OfficeProcesses

        Write-StyledMessage Info "🧹 Pulizia cache Office..."
        $caches = @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )

        $cleanedCount = 0
        foreach ($cache in $caches) {
            if (Invoke-SilentRemoval -Path $cache -Recurse) {
                $cleanedCount++
            }
        }

        if ($cleanedCount -gt 0) {
            Write-StyledMessage Success "$cleanedCount cache eliminate"
        }

        Write-StyledMessage Info "🎯 Tipo di riparazione:"
        Write-Host "  [1] 🚀 Riparazione rapida (offline)" -ForegroundColor Green
        Write-Host "  [2] 🌐 Riparazione completa (online)" -ForegroundColor Yellow

        do {
            $choice = Read-Host "Scelta [1-2]"
        } while ($choice -notin @('1', '2'))

        try {
            $repairType = if ($choice -eq '1') { 'QuickRepair' } else { 'FullRepair' }
            $repairName = if ($choice -eq '1') { 'rapida' } else { 'completa' }

            Write-StyledMessage Info "🔧 Avvio riparazione $repairName..."
            $arguments = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=$repairType DisplayLevel=True"
            
            $officeClient = "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
            if (-not (Test-Path $officeClient)) {
                $officeClient = "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
            }

            Start-Process -FilePath $officeClient -ArgumentList $arguments -Wait:$false

            Write-StyledMessage Info "⏳ Attesa completamento riparazione..."
            Write-Host "💡 Premi INVIO quando la riparazione è completata..." -ForegroundColor Yellow
            Read-Host | Out-Null

            if (Get-UserConfirmation "✅ Riparazione completata con successo?" 'Y') {
                Write-StyledMessage Success "🎉 Riparazione Office completata!"
                return $true
            }
            else {
                Write-StyledMessage Warning "Riparazione non completata correttamente"
                if ($choice -eq '1') {
                    if (Get-UserConfirmation "🌐 Tentare riparazione completa online?" 'Y') {
                        Write-StyledMessage Info "🌐 Avvio riparazione completa..."
                        $arguments = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True"
                        Start-Process -FilePath $officeClient -ArgumentList $arguments -Wait:$false

                        Write-Host "💡 Premi INVIO quando la riparazione completa è terminata..." -ForegroundColor Yellow
                        Read-Host | Out-Null

                        return Get-UserConfirmation "✅ Riparazione completa riuscita?" 'Y'
                    }
                }
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante riparazione: $_"
            return $false
        }
    }

    function Start-OfficeUninstall {
        Write-StyledMessage Warning "🗑️ Rimozione completa Microsoft Office"

        if (-not (Get-UserConfirmation "❓ Procedere con la rimozione completa?")) {
            Write-StyledMessage Info "❌ Operazione annullata"
            return $false
        }

        Stop-OfficeProcesses

        Write-StyledMessage Info "🔍 Rilevamento versione Windows..."
        $windowsVersion = Get-WindowsVersion
        Write-StyledMessage Info "🎯 Versione rilevata: $windowsVersion"

        $success = $false

        switch ($windowsVersion) {
            'Windows11_23H2_Plus' {
                Write-StyledMessage Info "🚀 Utilizzo metodo SaRA per Windows 11 23H2+..."
                $success = Start-OfficeUninstallWithSaRA
            }
            default {
                Write-StyledMessage Info "⚡ Utilizzo rimozione diretta per Windows 11 22H2 o precedenti..."
                Write-StyledMessage Warning "Questo metodo rimuove file e registro direttamente"
                if (Get-UserConfirmation "Confermi rimozione diretta?" 'Y') {
                    $success = Remove-OfficeDirectly
                }
            }
        }

        if ($success) {
            Write-StyledMessage Success "🎉 Rimozione Office completata!"
            return $true
        }
        else {
            Write-StyledMessage Error "Rimozione non completata"
            Write-StyledMessage Info "💡 Puoi provare un metodo alternativo o rimozione manuale"
            return $false
        }
    }

    function Remove-ItemsSilently {
        param(
            [string[]]$Paths,
            [string]$ItemType = "cartella"
        )

        $removed = @()
        $failed = @()

        foreach ($path in $Paths) {
            if (Test-Path $path) {
                if (Invoke-SilentRemoval -Path $path -Recurse) {
                    $removed += $path
                }
                else {
                    $failed += $path
                }
            }
        }

        return @{
            Removed = $removed
            Failed  = $failed
            Count   = $removed.Count
        }
    }

    function Remove-OfficeDirectly {
        Write-StyledMessage Info "🔧 Avvio rimozione diretta Office..."
        
        try {
            # Metodo 1: Rimozione pacchetti
            Write-StyledMessage Info "📋 Ricerca installazioni Office..."
            
            $officePackages = Get-Package -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -like "*Microsoft Office*" -or $_.Name -like "*Microsoft 365*" -or $_.Name -like "*Office*" }
            
            if ($officePackages) {
                Write-StyledMessage Info "Trovati $($officePackages.Count) pacchetti Office"
                foreach ($package in $officePackages) {
                    try {
                        Uninstall-Package -Name $package.Name -Force -ErrorAction Stop | Out-Null
                        Write-StyledMessage Success "Rimosso: $($package.Name)"
                    }
                    catch {}
                }
            }
            
            # Metodo 2: Rimozione tramite registro
            Write-StyledMessage Info "🔍 Ricerca nel registro..."
            
            $uninstallKeys = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
            
            foreach ($keyPath in $uninstallKeys) {
                try {
                    $items = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue |
                    Where-Object { $_.DisplayName -like "*Office*" -or $_.DisplayName -like "*Microsoft 365*" }
                    
                    foreach ($item in $items) {
                        if ($item.UninstallString -and $item.UninstallString -match "msiexec") {
                            try {
                                $productCode = $item.PSChildName
                                Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $productCode /qn /norestart" -Wait -NoNewWindow -ErrorAction Stop
                            }
                            catch {}
                        }
                    }
                }
                catch {}
            }
            
            # Metodo 3: Stop servizi Office
            Write-StyledMessage Info "🛑 Arresto servizi Office..."
            
            $officeServices = @('ClickToRunSvc', 'OfficeSvc', 'OSE')
            $stoppedServices = 0
            foreach ($serviceName in $officeServices) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    try {
                        Stop-Service -Name $serviceName -Force -ErrorAction Stop
                        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
                        Write-StyledMessage Success "Servizio arrestato: $serviceName"
                        $stoppedServices++
                    }
                    catch {}
                }
            }
            
            # Metodo 4: Pulizia cartelle Office
            Write-StyledMessage Info "🧹 Pulizia cartelle Office..."
            
            $foldersToClean = @(
                "$env:ProgramFiles\Microsoft Office",
                "${env:ProgramFiles(x86)}\Microsoft Office",
                "$env:ProgramFiles\Microsoft Office 15",
                "${env:ProgramFiles(x86)}\Microsoft Office 15",
                "$env:ProgramFiles\Microsoft Office 16",
                "${env:ProgramFiles(x86)}\Microsoft Office 16",
                "$env:ProgramData\Microsoft\Office",
                "$env:LOCALAPPDATA\Microsoft\Office",
                "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun",
                "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun"
            )
            
            $folderResult = Remove-ItemsSilently -Paths $foldersToClean -ItemType "cartella"
            
            if ($folderResult.Count -gt 0) {
                Write-StyledMessage Success "$($folderResult.Count) cartelle Office rimosse"
            }
            
            if ($folderResult.Failed.Count -gt 0) {
                Write-StyledMessage Warning "Impossibile rimuovere $($folderResult.Failed.Count) cartelle (potrebbero essere in uso)"
            }
            
            # Metodo 5: Pulizia registro Office
            Write-StyledMessage Info "🔧 Pulizia registro Office..."
            
            $registryPaths = @(
                "HKCU:\Software\Microsoft\Office",
                "HKLM:\SOFTWARE\Microsoft\Office",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office",
                "HKCU:\Software\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun"
            )
            
            $regResult = Remove-ItemsSilently -Paths $registryPaths -ItemType "chiave"
            
            if ($regResult.Count -gt 0) {
                Write-StyledMessage Success "$($regResult.Count) chiavi registro Office rimosse"
            }
            
            # Metodo 6: Pulizia attività pianificate
            Write-StyledMessage Info "📅 Pulizia attività pianificate..."

            try {
                $officeTasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
                Where-Object { $_.TaskName -like "*Office*" }

                $tasksRemoved = 0
                foreach ($task in $officeTasks) {
                    try {
                        Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
                        $tasksRemoved++
                    }
                    catch {}
                }
                
                if ($tasksRemoved -gt 0) {
                    Write-StyledMessage Success "$tasksRemoved attività Office rimosse"
                }
            }
            catch {}

            # Metodo 7: Rimozione collegamenti
            Write-StyledMessage Info "🖥️ Rimozione collegamenti Office..."

            $officeShortcuts = @(
                "Microsoft Word*.lnk", "Microsoft Excel*.lnk", "Microsoft PowerPoint*.lnk",
                "Microsoft Outlook*.lnk", "Microsoft OneNote*.lnk", "Microsoft Access*.lnk",
                "Office*.lnk", "Word*.lnk", "Excel*.lnk", "PowerPoint*.lnk", "Outlook*.lnk"
            )

            $desktopPaths = @(
                "$env:USERPROFILE\Desktop",
                "$env:PUBLIC\Desktop",
                "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs"
            )

            $shortcutsRemoved = 0
            foreach ($desktopPath in $desktopPaths) {
                if (Test-Path $desktopPath) {
                    foreach ($shortcut in $officeShortcuts) {
                        $shortcutFiles = Get-ChildItem -Path $desktopPath -Filter $shortcut -Recurse -ErrorAction SilentlyContinue
                        foreach ($file in $shortcutFiles) {
                            if (Invoke-SilentRemoval -Path $file.FullName) {
                                $shortcutsRemoved++
                            }
                        }
                    }
                }
            }

            if ($shortcutsRemoved -gt 0) {
                Write-StyledMessage Success "$shortcutsRemoved collegamenti Office rimossi"
            }

            # Metodo 8: Pulizia residui aggiuntivi
            Write-StyledMessage Info "💽 Pulizia residui Office..."
            
            $additionalPaths = @(
                "$env:LOCALAPPDATA\Microsoft\OneDrive",
                "$env:APPDATA\Microsoft\OneDrive",
                "$env:TEMP\Office*",
                "$env:TEMP\MSO*"
            )

            $residualsResult = Remove-ItemsSilently -Paths $additionalPaths -ItemType "residuo"

            Write-StyledMessage Success "✅ Rimozione diretta completata"
            Write-StyledMessage Info "📊 Riepilogo: $($folderResult.Count) cartelle, $($regResult.Count) chiavi registro, $shortcutsRemoved collegamenti, $tasksRemoved attività rimosse"
            
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore durante rimozione diretta: $_"
            return $false
        }
    }

    function Start-OfficeUninstallWithSaRA {
        try {
            if (-not (Test-Path $TempDir)) {
                New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
            }

            $saraUrl = 'https://aka.ms/SaRA_EnterpriseVersionFiles'
            $saraZipPath = Join-Path $TempDir 'SaRA.zip'

            if (-not (Invoke-DownloadFile $saraUrl $saraZipPath 'Microsoft SaRA')) {
                return $false
            }

            Write-StyledMessage Info "📦 Estrazione SaRA..."
            try {
                Expand-Archive -Path $saraZipPath -DestinationPath $TempDir -Force
                Write-StyledMessage Success "Estrazione completata"
            }
            catch {
                Write-StyledMessage Error "Errore estrazione: $_"
                return $false
            }

            $saraExe = Get-ChildItem -Path $TempDir -Filter "SaRAcmd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $saraExe) {
                Write-StyledMessage Error "SaRAcmd.exe non trovato"
                return $false
            }

            Write-StyledMessage Info "🚀 Rimozione tramite SaRA..."
            Write-StyledMessage Warning "⏰ Questa operazione può richiedere alcuni minuti"

            $arguments = '-S OfficeScrubScenario -AcceptEula -OfficeVersion All'
            
            try {
                $process = Start-Process -FilePath $saraExe.FullName -ArgumentList $arguments -Verb RunAs -PassThru -Wait -ErrorAction Stop
                
                if ($process.ExitCode -eq 0) {
                    Write-StyledMessage Success "✅ SaRA completato con successo"
                    return $true
                }
                else {
                    Write-StyledMessage Warning "SaRA terminato con codice: $($process.ExitCode)"
                    Write-StyledMessage Info "💡 Tentativo metodo alternativo..."
                    return Remove-OfficeDirectly
                }
            }
            catch {
                Write-StyledMessage Warning "Errore esecuzione SaRA: $_"
                Write-StyledMessage Info "💡 Passaggio a metodo alternativo..."
                return Remove-OfficeDirectly
            }
        }
        catch {
            Write-StyledMessage Warning "Errore durante SaRA: $_"
            return $false
        }
        finally {
            Invoke-SilentRemoval -Path $TempDir -Recurse
        }
    }

    function Show-Header {
        $Host.UI.RawUI.WindowTitle = "Office Toolkit By MagnetarMan"
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '      Office Toolkit By MagnetarMan',
            '        Version 2.4.1 (Build 1)'
        )

        foreach ($line in $asciiArt) {
            $padding = [Math]::Max(0, [Math]::Floor(($width - $line.Length) / 2))
            Write-Host (' ' * $padding + $line) -ForegroundColor White
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    # MAIN EXECUTION
    Show-Header
    Write-Host "⏳ Inizializzazione sistema..." -ForegroundColor Yellow
    Start-Sleep 2
    Write-Host "✅ Sistema pronto`n" -ForegroundColor Green

    try {
        do {
            Write-StyledMessage Info "🎯 Seleziona un'opzione:"
            Write-Host ''
            Write-Host '  [1]  🏢 Installazione Office (Basic Version)' -ForegroundColor White
            Write-Host '  [2]  🔧 Ripara Office' -ForegroundColor White
            Write-Host '  [3]  🗑️ Rimozione completa Office' -ForegroundColor Yellow
            Write-Host '  [0]  ❌ Esci' -ForegroundColor Red
            Write-Host ''

            $choice = Read-Host 'Scelta [0-3]'
            Write-Host ''

            $success = $false
            $operation = ''

            switch ($choice) {
                '1' {
                    $operation = 'Installazione'
                    $success = Start-OfficeInstallation
                }
                '2' {
                    $operation = 'Riparazione'
                    $success = Start-OfficeRepair
                }
                '3' {
                    $operation = 'Rimozione'
                    $success = Start-OfficeUninstall
                }
                '0' {
                    Write-StyledMessage Info "👋 Uscita dal toolkit..."
                    return
                }
                default {
                    Write-StyledMessage Warning "Opzione non valida. Seleziona 0-3."
                    continue
                }
            }

            if ($choice -in @('1', '2', '3')) {
                if ($success) {
                    Write-StyledMessage Success "🎉 $operation completata!"
                    if (Get-UserConfirmation "🔄 Riavviare ora per finalizzare?" 'Y') {
                        Start-CountdownRestart "$operation completata"
                    }
                    else {
                        Write-StyledMessage Info "💡 Riavvia manualmente quando possibile"
                    }
                }
                else {
                    Write-StyledMessage Error "$operation non riuscita"
                    Write-StyledMessage Info "💡 Controlla i log per dettagli o contatta il supporto"
                }
                Write-Host "`n" + ('─' * 50) + "`n"
            }

        } while ($choice -ne '0')
    }
    catch {
        Write-StyledMessage Error "Errore critico: $($_.Exception.Message)"
    }
    finally {
        Write-StyledMessage Success "🧹 Pulizia finale..."
        Invoke-SilentRemoval -Path $TempDir -Recurse

        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        Write-StyledMessage Success "🎯 Office Toolkit terminato"
        try { Stop-Transcript | Out-Null } catch {}
    }

}
function WinCleaner {
    <#
    .SYNOPSIS
        Script automatico per la pulizia completa del sistema Windows.

    .DESCRIPTION
        Questo script esegue una pulizia completa e automatica del sistema Windows,
        utilizzando cleanmgr.exe con configurazione automatica (/sageset e /sagerun)
        e pulendo manualmente tutti i componenti specificati.

        POLITICA ESCLUSIONI VITALI:
        - %LOCALAPPDATA%\WinToolkit: CARTELLA VITALE - Contiene toolkit, log e dati essenziali
        
    .PARAMETER CountdownSeconds
        Secondi di countdown prima del riavvio automatico (default: 30)
        
    .EXAMPLE
        WinCleaner
        WinCleaner -CountdownSeconds 60
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 300)]
        [int]$CountdownSeconds = 30
    )

    # ============================================================================
    # INIZIALIZZAZIONE VARIABILI E CONFIGURAZIONE
    # ============================================================================
    
    $Host.UI.RawUI.WindowTitle = "Cleaner Toolkit By MagnetarMan"
    $script:Log = @()
    $script:CurrentAttempt = 0

    # Setup logging
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logDir = "$env:LOCALAPPDATA\WinToolkit\logs"
    
    try {
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logDir\WinCleaner_$dateTime.log" -Append -Force | Out-Null
    }
    catch {
        Write-Warning "Impossibile inizializzare il logging: $_"
    }

    # Caratteri spinner per animazioni
    $script:Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    
    # Stili messaggi
    $script:MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    # Percorsi esclusi dalla pulizia
    $script:ExcludedPaths = @(
        "$env:LOCALAPPDATA\WinToolkit"
    )

    # ============================================================================
    # DEFINIZIONE TASK DI PULIZIA
    # ============================================================================
    
    $script:CleanupTasks = @(
        @{ Task = 'CleanMgrAuto'; Name = 'Pulizia automatica CleanMgr'; Icon = '🧹'; Auto = $true }
        @{ Task = 'WinSxS'; Name = 'WinSxS - Assembly sostituiti'; Icon = '📦'; Auto = $true }
        @{ Task = 'ErrorReports'; Name = 'Rapporti errori Windows'; Icon = '📋'; Auto = $true }
        @{ Task = 'EventLogs'; Name = 'Registro eventi Windows'; Icon = '📜'; Auto = $true }
        @{ Task = 'UpdateHistory'; Name = 'Cronologia Windows Update'; Icon = '📝'; Auto = $true }
        @{ Task = 'RestorePoints'; Name = 'Punti ripristino sistema'; Icon = '💾'; Auto = $true }
        @{ Task = 'DownloadCache'; Name = 'Cache download Windows'; Icon = '⬇️'; Auto = $true }
        @{ Task = 'PrefetchCleanup'; Name = 'Cache Prefetch Windows'; Icon = '⚡'; Auto = $true }
        @{ Task = 'ThumbnailCache'; Name = 'Cache miniature Explorer'; Icon = '🖼️'; Auto = $true }
        @{ Task = 'WinInetCacheCleanup'; Name = 'Cache web e file temporanei Internet'; Icon = '🌐'; Auto = $true }
        @{ Task = 'InternetCookiesCleanup'; Name = 'Cookie Internet'; Icon = '🍪'; Auto = $true }
        @{ Task = 'DNSFlush'; Name = 'Flush cache DNS'; Icon = '🔄'; Auto = $true }
        @{ Task = 'WindowsTempCleanup'; Name = 'File temporanei Windows'; Icon = '🗂️'; Auto = $true }
        @{ Task = 'UserTempCleanup'; Name = 'File temporanei utente'; Icon = '📁'; Auto = $true }
        @{ Task = 'PrintQueue'; Name = 'Coda di stampa'; Icon = '🖨️'; Auto = $true }
        @{ Task = 'SystemLogs'; Name = 'Log di sistema'; Icon = '📄'; Auto = $true }
        @{ Task = 'QuickAccessAndRecentFilesCleanup'; Name = 'Accesso Rapido e File Recenti'; Icon = '📁'; Auto = $true }
        @{ Task = 'RegeditHistoryCleanup'; Name = 'Cronologia Regedit'; Icon = '⚙️'; Auto = $true }
        @{ Task = 'ComDlg32HistoryCleanup'; Name = 'Cronologia Finestre di Dialogo File'; Icon = '📜'; Auto = $true }
        @{ Task = 'AdobeMediaBrowserCleanup'; Name = 'Cronologia Adobe Media Browser'; Icon = '🖼️'; Auto = $true }
        @{ Task = 'PaintAndWordPadHistoryCleanup'; Name = 'Cronologia Paint e WordPad'; Icon = '🎨'; Auto = $true }
        @{ Task = 'NetworkDriveHistoryCleanup'; Name = 'Cronologia Mappatura Unità di Rete'; Icon = '🌐'; Auto = $true }
        @{ Task = 'WindowsSearchHistoryCleanup'; Name = 'Cronologia Ricerca Windows'; Icon = '🔍'; Auto = $true }
        @{ Task = 'MediaPlayerHistoryCleanup'; Name = 'Cronologia Media Player'; Icon = '🎵'; Auto = $true }
        @{ Task = 'DirectXHistoryCleanup'; Name = 'Cronologia Applicazioni DirectX'; Icon = '🎮'; Auto = $true }
        @{ Task = 'RunCommandHistoryCleanup'; Name = 'Cronologia comandi Esegui'; Icon = '▶️'; Auto = $true }
        @{ Task = 'FileExplorerAddressBarHistoryCleanup'; Name = 'Cronologia Barra Indirizzi Esplora File'; Icon = '📂'; Auto = $true }
        @{ Task = 'ListarySearchIndexCleanup'; Name = 'Indice Ricerca Listary'; Icon = '📊'; Auto = $true }
        @{ Task = 'JavaCacheCleanup'; Name = 'Cache Java'; Icon = '☕'; Auto = $true }
        @{ Task = 'DotnetTelemetryCleanup'; Name = 'Telemetria Dotnet CLI'; Icon = '🌐'; Auto = $true }
        @{ Task = 'ChromeCleanup'; Name = 'Dati e Crash Report Chrome'; Icon = '🌐'; Auto = $true }
        @{ Task = 'FirefoxCleanup'; Name = 'Cronologia e Profili Firefox'; Icon = '🦊'; Auto = $true }
        @{ Task = 'OperaCleanup'; Name = 'Dati e Cronologia Opera'; Icon = '🅾️'; Auto = $true }
        @{ Task = 'CLRUsageTracesCleanup'; Name = 'Tracce di Utilizzo .NET CLR'; Icon = '💻'; Auto = $true }
        @{ Task = 'VisualStudioTelemetryRootCleanup'; Name = 'Telemetria Visual Studio'; Icon = '💻'; Auto = $true }
        @{ Task = 'VisualStudioLicensesCleanup'; Name = 'Licenze Visual Studio'; Icon = '💻'; Auto = $true }
        @{ Task = 'WindowsSystemProfilesTempCleanup'; Name = 'Temp Profili di Servizio Windows'; Icon = '👤'; Auto = $true }
        @{ Task = 'SystemLogFileCleanup'; Name = 'Log di Sistema e Applicazioni Varie'; Icon = '📄'; Auto = $true }
        @{ Task = 'MinimizeDISMResetBase'; Name = 'Minimizza Dati Aggiornamenti DISM'; Icon = '📊'; Auto = $true }
        @{ Task = 'WindowsUpdateFilesCleanup'; Name = 'File Temporanei Windows Update'; Icon = '🔄'; Auto = $true }
        @{ Task = 'DiagTrackLogsCleanup'; Name = 'Log di Tracciamento Diagnostica'; Icon = '🚫'; Auto = $true }
        @{ Task = 'DefenderProtectionHistoryCleanup'; Name = 'Cronologia Protezione Defender'; Icon = '🛡️'; Auto = $true }
        @{ Task = 'SystemResourceUsageMonitorCleanup'; Name = 'Dati SRUM'; Icon = '📈'; Auto = $true }
        @{ Task = 'CredentialManagerCleanup'; Name = 'Credenziali Windows'; Icon = '🔑'; Auto = $true }
        @{ Task = 'RecycleBinEmpty'; Name = 'Svuota Cestino'; Icon = '🗑️'; Auto = $true }
        @{ Task = 'WindowsOld'; Name = 'Cartella Windows.old'; Icon = '🗑️'; Auto = $true }
    )

    # ============================================================================
    # FUNZIONI HELPER
    # ============================================================================

    function Write-StyledMessage {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('Success', 'Warning', 'Error', 'Info')]
            [string]$Type,
            
            [Parameter(Mandatory = $true)]
            [string]$Text
        )

        $style = $script:MsgStyles[$Type]
        $timestamp = Get-Date -Format "HH:mm:ss"
        
        # Rimuovi emoji duplicati dal testo
        $cleanText = $Text -replace '^[✅⚠️❌💎🔍🚀⚙️🧹📦📋📜📝💾⬇️🔧⚡🖼️🌐🍪🔄🗂️📁🖨️📄🗑️💭⏸️▶️💡⏰🎉💻📊]\s*', ''

        Write-Host "[$timestamp] $($style.Icon) $cleanText" -ForegroundColor $style.Color

        # Log dettagliato per operazioni importanti
        if ($Type -in @('Info', 'Warning', 'Error')) {
            $logEntry = "[$timestamp] [$Type] $cleanText"
            $script:Log += $logEntry
        }
    }

    function Test-ExcludedPath {
        [CmdletBinding()]
        [OutputType([bool])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path
        )

        $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) {
            $Path
        }
        else {
            Join-Path (Get-Location) $Path
        }

        foreach ($excluded in $script:ExcludedPaths) {
            $excludedFull = if ([System.IO.Path]::IsPathRooted($excluded)) {
                $excluded
            }
            else {
                [Environment]::ExpandEnvironmentVariables($excluded)
            }

            # Verifica se il path è dentro una directory esclusa
            if ($fullPath -like "$excludedFull*" -or $fullPath -eq $excludedFull) {
                Write-StyledMessage Info "🛡️ CARTELLA VITALE PROTETTA: $fullPath"
                $script:Log += "[EXCLUSION] 🛡️ Cartella vitale protetta dalla pulizia: $fullPath"
                return $true
            }
        }

        return $false
    }

    function Start-ProcessWithTimeout {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$FilePath,
            
            [Parameter(Mandatory = $false)]
            [string[]]$ArgumentList = @(),
            
            [Parameter(Mandatory = $false)]
            [int]$TimeoutSeconds = 300,
            
            [Parameter(Mandatory = $false)]
            [string]$Activity = "Processo in esecuzione",
            
            [Parameter(Mandatory = $false)]
            [switch]$Hidden
        )

        $startTime = Get-Date
        $spinnerIndex = 0
        $percent = 0

        try {
            $processParams = @{
                FilePath     = $FilePath
                ArgumentList = $ArgumentList
                PassThru     = $true
            }

            if ($Hidden) {
                $processParams.WindowStyle = 'Hidden'
            }
            else {
                $processParams.NoNewWindow = $true
            }

            $proc = Start-Process @processParams

            while (-not $proc.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                $spinner = $script:Spinners[$spinnerIndex++ % $script:Spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                
                if ($percent -lt 90) { 
                    $percent += Get-Random -Minimum 1 -Maximum 3 
                }
                
                Show-ProgressBar -Activity $Activity -Status "In esecuzione... ($elapsed secondi)" -Percent $percent -Icon '⏳' -Spinner $spinner
                Start-Sleep -Milliseconds 500
                $proc.Refresh()
            }

            if (-not $proc.HasExited) {
                Clear-ProgressLine
                Write-StyledMessage Warning "Timeout raggiunto dopo $TimeoutSeconds secondi, terminazione processo..."
                $proc.Kill()
                Start-Sleep -Seconds 2
                return @{ Success = $false; TimedOut = $true; ExitCode = -1 }
            }

            Clear-ProgressLine
            return @{ Success = $true; TimedOut = $false; ExitCode = $proc.ExitCode }
        }
        catch {
            Clear-ProgressLine
            Write-StyledMessage Error "Errore nell'avvio del processo: $($_.Exception.Message)"
            return @{ Success = $false; TimedOut = $false; ExitCode = -1 }
        }
    }

    function Show-ProgressBar {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Activity,
            
            [Parameter(Mandatory = $true)]
            [string]$Status,
            
            [Parameter(Mandatory = $true)]
            [ValidateRange(0, 100)]
            [int]$Percent,
            
            [Parameter(Mandatory = $true)]
            [string]$Icon,
            
            [Parameter(Mandatory = $false)]
            [string]$Spinner = '',
            
            [Parameter(Mandatory = $false)]
            [string]$Color = 'Green'
        )

        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '▒' * (30 - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent
        
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        
        if ($Percent -eq 100) { 
            Write-Host '' 
        }
    }

    function Clear-ProgressLine {
        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline
    }

    function Invoke-DeletePaths {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string[]]$Paths,
            
            [Parameter(Mandatory = $true)]
            [string]$Description,
            
            [Parameter(Mandatory = $true)]
            [string]$Icon,
            
            [Parameter(Mandatory = $false)]
            [switch]$Recursive = $true,
            
            [Parameter(Mandatory = $false)]
            [switch]$FilesOnly = $false,
            
            [Parameter(Mandatory = $false)]
            [switch]$TakeOwnership = $false,
            
            [Parameter(Mandatory = $false)]
            [switch]$PerUser = $false
        )

        $totalCleaned = 0
        $errorCount = 0
        $pathsToProcess = @()

        if ($PerUser) {
            $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -notmatch '^(Public|Default|All Users)$' }
            
            foreach ($user in $users) {
                foreach ($path in $Paths) {
                    $expandedPath = $path `
                        -replace '%USERPROFILE%', $user.FullName `
                        -replace '%APPDATA%', "$($user.FullName)\AppData\Roaming" `
                        -replace '%LOCALAPPDATA%', "$($user.FullName)\AppData\Local" `
                        -replace '%TEMP%', "$($user.FullName)\AppData\Local\Temp"
                    $pathsToProcess += $expandedPath
                }
            }
        }
        else {
            foreach ($path in $Paths) {
                $pathsToProcess += [System.Environment]::ExpandEnvironmentVariables($path)
            }
        }

        foreach ($currentPath in $pathsToProcess) {
            if (Test-ExcludedPath $currentPath) {
                Write-StyledMessage Info "🛡️ Percorso escluso: $currentPath"
                continue
            }

            if ($TakeOwnership) {
                Write-StyledMessage Info "🔑 Assunzione proprietà per $currentPath..."
                
                $takeownResult = & cmd /c "takeown /F `"$currentPath`" /R /A /D Y 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Write-StyledMessage Warning "Errore takeown: $takeownResult"
                    $errorCount++
                }
                
                $adminSID = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
                $adminAccount = $adminSID.Translate([System.Security.Principal.NTAccount]).Value
                
                $icaclsResult = & cmd /c "icacls `"$currentPath`" /T /grant `"${adminAccount}:F`" 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Write-StyledMessage Warning "Errore icacls: $icaclsResult"
                    $errorCount++
                }
            }

            try {
                if (Test-Path $currentPath) {
                    if ($FilesOnly) {
                        $items = Get-ChildItem -Path $currentPath -Recurse -File -ErrorAction SilentlyContinue
                        $items | Remove-Item -Force -ErrorAction SilentlyContinue
                        $totalCleaned += $items.Count
                    }
                    else {
                        Remove-Item -Path $currentPath -Recurse:$Recursive -Force -ErrorAction SilentlyContinue
                        $totalCleaned++
                    }
                    Write-StyledMessage Success "🗑️ Pulito: $currentPath ($totalCleaned elementi)"
                }
            }
            catch {
                Write-StyledMessage Warning "Errore pulizia $currentPath : $_"
                $errorCount++
            }
        }

        return @{ Success = ($errorCount -eq 0); ErrorCount = $errorCount; CleanedCount = $totalCleaned }
    }

    function Invoke-ClearRegistryKeyValues {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$KeyPath,
            
            [Parameter(Mandatory = $true)]
            [string]$Description,
            
            [Parameter(Mandatory = $true)]
            [string]$Icon,
            
            [Parameter(Mandatory = $false)]
            [switch]$Recursive = $false
        )

        $totalCleaned = 0
        $errorCount = 0

        $expandedKeyPath = [System.Environment]::ExpandEnvironmentVariables($KeyPath)
        $formattedKeyPath = $expandedKeyPath -replace '^(HKCU|HKLM):', '$1:\'

        if (Test-Path -LiteralPath $formattedKeyPath) {
            try {
                $key = Get-Item -LiteralPath $formattedKeyPath -ErrorAction SilentlyContinue
                
                if ($key) {
                    $valueNames = $key.GetValueNames()
                    
                    foreach ($valueName in $valueNames) {
                        try {
                            if ($valueName -eq '(default)') {
                                $key.OpenSubKey('', $true).DeleteValue('')
                            }
                            else {
                                Remove-ItemProperty -LiteralPath $formattedKeyPath -Name $valueName -ErrorAction SilentlyContinue
                            }
                            $totalCleaned++
                        }
                        catch {
                            $errorCount++
                        }
                    }
                    
                    if ($Recursive) {
                        $subKeys = Get-ChildItem -Path $formattedKeyPath -ErrorAction SilentlyContinue
                        foreach ($subKey in $subKeys) {
                            $result = Invoke-ClearRegistryKeyValues -KeyPath $subKey.PSPath -Description "$Description (sottochiave)" -Icon $Icon -Recursive
                            $totalCleaned += $result.CleanedCount
                            $errorCount += $result.ErrorCount
                        }
                    }
                    
                    Write-StyledMessage Success "🗑️ Puliti valori registro: $formattedKeyPath ($totalCleaned valori)"
                }
            }
            catch {
                Write-StyledMessage Warning "Errore pulizia registro $formattedKeyPath : $_"
                $errorCount++
            }
        }
        else {
            Write-StyledMessage Info "💭 Chiave registro non esistente: $formattedKeyPath"
        }

        return @{ Success = ($errorCount -eq 0); ErrorCount = $errorCount; CleanedCount = $totalCleaned }
    }

    function Invoke-RemoveRegistryKeyFull {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$KeyPath,
            
            [Parameter(Mandatory = $true)]
            [string]$Description,
            
            [Parameter(Mandatory = $true)]
            [string]$Icon
        )

        $errorCount = 0
        $expandedKeyPath = [System.Environment]::ExpandEnvironmentVariables($KeyPath)
        $formattedKeyPath = $expandedKeyPath -replace '^(HKCU|HKLM):', '$1:\'

        if (Test-Path -LiteralPath $formattedKeyPath) {
            try {
                Remove-Item -LiteralPath $formattedKeyPath -Recurse -Force -ErrorAction Stop
                Write-StyledMessage Success "🗑️ Rimossa chiave registro: $formattedKeyPath"
            }
            catch {
                Write-StyledMessage Warning "Errore rimozione chiave registro $formattedKeyPath : $_"
                $errorCount++
            }
        }
        else {
            Write-StyledMessage Info "💭 Chiave registro non esistente: $formattedKeyPath"
        }

        return @{ Success = ($errorCount -eq 0); ErrorCount = $errorCount }
    }

    function Invoke-SetRegistryKeyValue {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$KeyPath,
            
            [Parameter(Mandatory = $true)]
            [string]$ValueName,
            
            [Parameter(Mandatory = $true)]
            [object]$ValueData,
            
            [Parameter(Mandatory = $true)]
            [ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')]
            [string]$ValueType,
            
            [Parameter(Mandatory = $true)]
            [string]$Description,
            
            [Parameter(Mandatory = $true)]
            [string]$Icon
        )

        $errorCount = 0
        $expandedKeyPath = [System.Environment]::ExpandEnvironmentVariables($KeyPath)
        $formattedKeyPath = $expandedKeyPath -replace '^(HKCU|HKLM):', '$1:\'

        try {
            if (-not (Test-Path $formattedKeyPath)) {
                New-Item -Path $formattedKeyPath -Force -ErrorAction Stop | Out-Null
            }
            
            Set-ItemProperty -LiteralPath $formattedKeyPath -Name $ValueName -Value $ValueData -Type $ValueType -Force -ErrorAction Stop
            Write-StyledMessage Success "⚙️ Impostato valore registro: $formattedKeyPath\$ValueName"
        }
        catch {
            Write-StyledMessage Warning "Errore impostazione valore registro $formattedKeyPath\$ValueName : $_"
            $errorCount++
        }

        return @{ Success = ($errorCount -eq 0); ErrorCount = $errorCount }
    }

    function Invoke-ServiceControl {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$ServiceName,
            
            [Parameter(Mandatory = $true)]
            [ValidateSet('Start', 'Stop')]
            [string]$Action,
            
            [Parameter(Mandatory = $true)]
            [string]$Description,
            
            [Parameter(Mandatory = $true)]
            [string]$Icon
        )

        $errorCount = 0
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        
        if (-not $service) {
            Write-StyledMessage Info "💭 Servizio $ServiceName non trovato"
            return @{ Success = $true; ErrorCount = 0 }
        }

        $stateFile = Join-Path "$env:LOCALAPPDATA\WinToolkit\service_state" "$ServiceName.tmp"

        try {
            if ($Action -eq 'Stop') {
                if ($service.Status -eq 'Running') {
                    Stop-Service -Name $ServiceName -Force -ErrorAction Stop
                    
                    if (Wait-ServiceStatus -ServiceName $ServiceName -Status 'Stopped' -Timeout 30) {
                        $stateDir = Split-Path $stateFile
                        if (-not (Test-Path $stateDir)) {
                            New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
                        }
                        New-Item -ItemType File -Path $stateFile -Force | Out-Null
                        Write-StyledMessage Success "⏸️ Servizio $ServiceName fermato"
                    }
                    else {
                        Write-StyledMessage Warning "Timeout durante arresto servizio $ServiceName"
                        $errorCount++
                    }
                }
            }
            elseif ($Action -eq 'Start') {
                $shouldStart = (Test-Path $stateFile) -or ($service.Status -ne 'Running')
                
                if ($shouldStart) {
                    if (Test-Path $stateFile) {
                        Remove-Item $stateFile -Force -ErrorAction SilentlyContinue
                    }
                    
                    Start-Service -Name $ServiceName -ErrorAction Stop
                    
                    if (Wait-ServiceStatus -ServiceName $ServiceName -Status 'Running' -Timeout 30) {
                        Write-StyledMessage Success "▶️ Servizio $ServiceName avviato"
                    }
                    else {
                        Write-StyledMessage Warning "Timeout durante avvio servizio $ServiceName"
                        $errorCount++
                    }
                }
            }
        }
        catch {
            Write-StyledMessage Warning "Errore controllo servizio $ServiceName : $_"
            $errorCount++
        }

        return @{ Success = ($errorCount -eq 0); ErrorCount = $errorCount }
    }

    function Wait-ServiceStatus {
        [CmdletBinding()]
        [OutputType([bool])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$ServiceName,
            
            [Parameter(Mandatory = $true)]
            [ValidateSet('Running', 'Stopped')]
            [string]$Status,
            
            [Parameter(Mandatory = $false)]
            [int]$Timeout = 30
        )

        $timer = [Diagnostics.Stopwatch]::StartNew()
        
        while ($timer.Elapsed.TotalSeconds -lt $Timeout) {
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            
            if ($service.Status -eq $Status) {
                $timer.Stop()
                return $true
            }
            
            Start-Sleep -Milliseconds 500
        }
        
        $timer.Stop()
        return $false
    }

    function Start-InterruptibleCountdown {
        [CmdletBinding()]
        [OutputType([bool])]
        param(
            [Parameter(Mandatory = $true)]
            [int]$Seconds,
            
            [Parameter(Mandatory = $true)]
            [string]$Message
        )

        Write-StyledMessage Info '💡 Premi un tasto qualsiasi per annullare...'
        Write-Host ''

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning '⏸️ Riavvio automatico annullato'
                Write-StyledMessage Info "🔄 Puoi riavviare manualmente: 'shutdown /r /t 0' o dal menu Start."
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning '⏰ Tempo scaduto: il sistema verrà riavviato ora.'
        Start-Sleep 1
        return $true
    }

    function Center-Text {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )

        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ '
            '      \ \      / / | || \ | |'
            '       \ \ /\ / /  | ||  \| |'
            '        \ V  V /   | || |\  |'
            '         \_/\_/    |_||_| \_|'
            ''
            '    Cleaner Toolkit By MagnetarMan'
            '       Version 2.4.1 (Build 5)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    # ============================================================================
    # FUNZIONI DI PULIZIA SPECIFICHE
    # ============================================================================

    function Invoke-CleanMgrAuto {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🧹 Pulizia disco tramite CleanMgr..."

        try {
            Write-StyledMessage Info "⚙️ Verifica configurazione CleanMgr nel registro..."
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"

            # Verifica configurazioni esistenti
            $validOptions = 0
            Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $stateFlag = Get-ItemProperty -Path $_.PSPath -Name "StateFlags0065" -ErrorAction SilentlyContinue
                    if ($stateFlag -and $stateFlag.StateFlags0065 -eq 2) { 
                        $validOptions++ 
                    }
                }
                catch { }
            }

            if ($validOptions -lt 3) {
                Write-StyledMessage Info "📝 Configurazione opzioni di pulizia nel registro..."
                
                $cleanOptions = @(
                    "Active Setup Temp Folders", "BranchCache", "D3D Shader Cache",
                    "Delivery Optimization Files", "Downloaded Program Files", "Internet Cache Files",
                    "Memory Dump Files", "Recycle Bin", "Setup Log Files",
                    "System error memory dump files", "System error minidump files",
                    "Temporary Files", "Temporary Setup Files", "Thumbnail Cache",
                    "Windows Error Reporting Files", "Windows Upgrade Log Files"
                )

                $configuredCount = 0
                foreach ($option in $cleanOptions) {
                    $optionPath = Join-Path $regPath $option
                    if (Test-Path $optionPath) {
                        try {
                            Set-ItemProperty -Path $optionPath -Name "StateFlags0065" -Value 2 -Type DWORD -Force -ErrorAction Stop
                            $configuredCount++
                            Write-StyledMessage Info "✅ Configurata: $option"
                        }
                        catch {
                            Write-StyledMessage Warning "Impossibile configurare: $option - $($_.Exception.Message)"
                        }
                    }
                }

                Write-StyledMessage Info "✅ Configurate $configuredCount opzioni di pulizia"
            }
            else {
                Write-StyledMessage Info "✅ Configurazione esistente trovata nel registro"
            }

            # Verifica se ci sono file da pulire
            Write-StyledMessage Info "🔍 Verifica se ci sono file da pulire..."
            $startTime = Get-Date
            $testProc = Start-Process 'cleanmgr.exe' -ArgumentList '/sagerun:65' -PassThru -WindowStyle Hidden -Wait

            if ($testProc.ExitCode -eq 0 -and ((Get-Date) - $startTime).TotalSeconds -lt 5) {
                Write-StyledMessage Info "💨 CleanMgr completato rapidamente - probabilmente nessun file da pulire"
                Write-StyledMessage Success "✅ Verifica pulizia completata - sistema già pulito"
                return @{ Success = $true; ErrorCount = 0 }
            }

            # Esecuzione pulizia
            Write-StyledMessage Info "🚀 Avvio pulizia disco (questo può richiedere diversi minuti)..."
            $proc = Start-Process 'cleanmgr.exe' -ArgumentList '/sagerun:65' -PassThru -WindowStyle Minimized

            Write-StyledMessage Info "🔍 Processo CleanMgr avviato (PID: $($proc.Id))"
            
            Start-Sleep -Seconds 3
            
            $timeout = 900
            $spinnerIndex = 0
            $percent = 0
            
            while (-not $proc.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
                $spinner = $script:Spinners[$spinnerIndex++ % $script:Spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 0)
                
                try {
                    $proc.Refresh()
                    
                    if ($elapsed -lt 60) {
                        $percent = [math]::Min(30, $elapsed / 2)
                    }
                    elseif ($elapsed -lt 180) {
                        $percent = 30 + (($elapsed - 60) / 4)
                    }
                    else {
                        $percent = [math]::Min(95, 60 + (($elapsed - 180) / 10))
                    }
                    
                    Show-ProgressBar -Activity "Pulizia CleanMgr" -Status "Analisi e pulizia in corso... ($elapsed s)" -Percent ([int]$percent) -Icon '🧹' -Spinner $spinner
                    Start-Sleep -Milliseconds 1000
                }
                catch {
                    break
                }
            }

            if (-not $proc.HasExited) {
                Clear-ProgressLine
                Write-StyledMessage Warning "Timeout raggiunto dopo $([math]::Round($timeout/60, 0)) minuti"
                try {
                    $proc.Kill()
                    Start-Sleep -Seconds 2
                }
                catch { }
                $script:Log += "[CleanMgrAuto] Timeout dopo $timeout secondi"
                return @{ Success = $true; ErrorCount = 0 }
            }

            $exitCode = $proc.ExitCode
            Clear-ProgressLine
            Show-ProgressBar -Activity "Pulizia CleanMgr" -Status 'Completato' -Percent 100 -Icon '🧹'
            Write-Host ''
            
            if ($exitCode -eq 0) {
                Write-StyledMessage Success "Pulizia disco completata con successo"
                $script:Log += "[CleanMgrAuto] ✅ Pulizia completata (Exit code: $exitCode, Durata: $([math]::Round(((Get-Date) - $startTime).TotalSeconds, 0))s)"
            }
            else {
                Write-StyledMessage Warning "Pulizia disco completata con warnings (Exit code: $exitCode)"
                $script:Log += "[CleanMgrAuto] Completato con warnings (Exit code: $exitCode)"
            }
            
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Clear-ProgressLine
            Write-StyledMessage Error "Errore durante pulizia CleanMgr: $($_.Exception.Message)"
            Write-StyledMessage Info "💡 Suggerimento: Eseguire manualmente 'cleanmgr.exe' per verificare"
            $script:Log += "[CleanMgrAuto] Errore: $($_.Exception.Message)"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WinSxSCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "📦 Pulizia componenti WinSxS sostituiti..."

        try {
            Write-StyledMessage Info "🔍 Avvio analisi componenti WinSxS..."

            $result = Start-ProcessWithTimeout -FilePath 'DISM.exe' `
                -ArgumentList '/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase' `
                -TimeoutSeconds 900 `
                -Activity "WinSxS Cleanup" `
                -Hidden

            if ($result.TimedOut) {
                Write-StyledMessage Warning "Pulizia WinSxS interrotta per timeout"
                $script:Log += "[WinSxS] Timeout dopo 15 minuti"
                return @{ Success = $true; ErrorCount = 0 }
            }

            $exitCode = $result.ExitCode

            if ($exitCode -eq 0) {
                Write-StyledMessage Success "✅ Componenti WinSxS puliti con successo"
                $script:Log += "[WinSxS] ✅ Pulizia completata (Exit code: $exitCode)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Warning "Pulizia WinSxS completata con warnings (Exit code: $exitCode)"
                $script:Log += "[WinSxS] Completato con warnings (Exit code: $exitCode)"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante pulizia WinSxS: $($_.Exception.Message)"
            $script:Log += "[WinSxS] Errore: $($_.Exception.Message)"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ErrorReportsCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "📋 Pulizia rapporti errori Windows..."
        
        $werPaths = @(
            "$env:ProgramData\Microsoft\Windows\WER"
            "$env:ALLUSERSPROFILE\Microsoft\Windows\WER"
        )

        $totalCleaned = 0
        foreach ($path in $werPaths) {
            if (Test-ExcludedPath $path) {
                continue
            }

            if (Test-Path $path) {
                try {
                    $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | 
                    Where-Object { -not (Test-ExcludedPath $_.FullName) }
                    
                    $files | Remove-Item -Force -ErrorAction SilentlyContinue
                    $totalCleaned += $files.Count
                    Write-StyledMessage Info "🗑️ Rimosso $($files.Count) file da $path"
                }
                catch {
                    Write-StyledMessage Warning "Impossibile pulire $path - $_"
                }
            }
        }

        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Rapporti errori puliti ($totalCleaned file)"
            $script:Log += "[ErrorReports] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessun rapporto errori da pulire"
            $script:Log += "[ErrorReports] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
        }
    }

    function Invoke-EventLogsCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "📜 Pulizia registro eventi Windows..."
        
        try {
            Write-StyledMessage Info "⚙️ Impostazione permessi per log eventi specifici..."
            
            $permResult = Start-ProcessWithTimeout `
                -FilePath 'wevtutil.exe' `
                -ArgumentList 'sl', 'Microsoft-Windows-LiveId/Operational', '/ca:O:BAG:SYD:(A;;0x1;;;SY)(A;;0x5;;;BA)(A;;0x1;;;LA)' `
                -TimeoutSeconds 30 `
                -Activity "Impostazione permessi log LiveId" `
                -Hidden
            
            if (-not $permResult.Success) {
                Write-StyledMessage Warning "Impossibile impostare permessi per Microsoft-Windows-LiveId/Operational."
            }

            & wevtutil el | ForEach-Object {
                & wevtutil cl $_ 2>$null
            }

            Write-StyledMessage Success "✅ Registro eventi pulito"
            $script:Log += "[EventLogs] ✅ Pulizia completata"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia registro eventi: $_"
            $script:Log += "[EventLogs] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-UpdateHistoryCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "📝 Pulizia cronologia Windows Update..."
        
        $updatePaths = @(
            "C:\WINDOWS\SoftwareDistribution\DataStore\DataStore.edb"
            "C:\WINDOWS\SoftwareDistribution\DataStore\DataStore.jfm"
            "C:\WINDOWS\SoftwareDistribution\DataStore\Logs"
        )

        $totalCleaned = 0
        foreach ($path in $updatePaths) {
            if (Test-ExcludedPath $path) {
                continue
            }

            try {
                if (Test-Path $path) {
                    if (Test-Path -Path $path -PathType Container) {
                        $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | 
                        Where-Object { -not (Test-ExcludedPath $_.FullName) }
                        
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        $totalCleaned += $files.Count
                        Write-StyledMessage Info "🗑️ Rimossa directory: $path"
                    }
                    else {
                        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                        $totalCleaned++
                        Write-StyledMessage Info "🗑️ Rimosso file: $path"
                    }
                }
            }
            catch {
                Write-StyledMessage Warning "Impossibile rimuovere $path - $_"
            }
        }

        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Cronologia Update pulita ($totalCleaned elementi)"
            $script:Log += "[UpdateHistory] ✅ Pulizia completata ($totalCleaned elementi)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessuna cronologia Update da pulire"
            $script:Log += "[UpdateHistory] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
        }
    }

    function Invoke-RestorePointsCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "💾 Disattivazione punti ripristino sistema..."
        
        try {
            & vssadmin delete shadows /all /quiet 2>$null
            Disable-ComputerRestore -Drive "C:" -ErrorAction SilentlyContinue

            Write-StyledMessage Success "✅ Punti ripristino disattivati"
            $script:Log += "[RestorePoints] ✅ Disattivazione completata"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning "Errore durante disattivazione punti ripristino: $_"
            $script:Log += "[RestorePoints] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DownloadCacheCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "⬇️ Pulizia cache download Windows..."
        $downloadPath = "C:\WINDOWS\SoftwareDistribution\Download"

        try {
            if (Test-ExcludedPath $downloadPath) {
                Write-StyledMessage Info "💭 Cache download esclusa dalla pulizia"
                $script:Log += "[DownloadCache] ℹ️ Directory esclusa"
                return @{ Success = $true; ErrorCount = 0 }
            }

            if (Test-Path $downloadPath) {
                $files = Get-ChildItem -Path $downloadPath -Recurse -File -ErrorAction SilentlyContinue | 
                Where-Object { -not (Test-ExcludedPath $_.FullName) }
                
                $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

                Write-StyledMessage Success "✅ Cache download pulita ($($files.Count) file)"
                $script:Log += "[DownloadCache] ✅ Pulizia completata ($($files.Count) file)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Info "💭 Cache download non presente"
                $script:Log += "[DownloadCache] ℹ️ Directory non presente"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cache download: $_"
            $script:Log += "[DownloadCache] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-PrefetchCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "⚡ Pulizia cache Prefetch Windows..."
        
        try {
            $result = Invoke-DeletePaths `
                -Paths @("C:\WINDOWS\Prefetch", "$env:SYSTEMROOT\Prefetch") `
                -Description "Cache Prefetch Windows" `
                -Icon '⚡'

            Write-StyledMessage Success "✅ Cache Prefetch pulita"
            $script:Log += "[Prefetch] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Prefetch: $_"
            $script:Log += "[Prefetch] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ThumbnailCacheCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🖼️ Pulizia cache miniature Explorer..."
        
        $thumbnailPaths = @(
            "$env:APPDATA\Microsoft\Windows\Explorer"
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        )

        $totalCleaned = 0
        $thumbnailFiles = @(
            "iconcache_*.db", "thumbcache_*.db", "ExplorerStartupLog*.etl",
            "NotifyIcon", "RecommendationsFilterList.json"
        )

        foreach ($path in $thumbnailPaths) {
            if (Test-ExcludedPath $path) {
                continue
            }

            foreach ($pattern in $thumbnailFiles) {
                try {
                    $files = Get-ChildItem -Path $path -Filter $pattern -ErrorAction SilentlyContinue | 
                    Where-Object {
                        $fullPath = $_.FullName
                        -not (Test-ExcludedPath $fullPath)
                    }
                    
                    foreach ($file in $files) {
                        Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                        if (-not (Test-Path $file.FullName)) { 
                            $totalCleaned++ 
                        }
                    }
                }
                catch {
                    Write-StyledMessage Warning "Impossibile rimuovere alcuni file in $path"
                }
            }
        }

        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Cache miniature pulita ($totalCleaned file)"
            $script:Log += "[ThumbnailCache] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessuna cache miniature da pulire"
            $script:Log += "[ThumbnailCache] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
        }
    }

    function Invoke-WinInetCacheCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🌐 Pulizia cache web WinInet e file temporanei Internet..."
        
        try {
            $paths1 = @(
                "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\IE"
                "$env:LOCALAPPDATA\Microsoft\Windows\WebCache"
                "$env:LOCALAPPDATA\Microsoft\Feeds Cache"
                "$env:LOCALAPPDATA\Microsoft\InternetExplorer\DOMStore"
                "$env:LOCALAPPDATA\Microsoft\Internet Explorer"
            )
            
            $result1 = Invoke-DeletePaths `
                -Paths $paths1 `
                -Description "Cache WinInet e dati Internet Explorer" `
                -Icon '🌐'
            
            $paths2 = @(
                "%USERPROFILE%\Local Settings\Temporary Internet Files"
                "%LOCALAPPDATA%\Microsoft\Windows\Temporary Internet Files"
            )
            
            $result2 = Invoke-DeletePaths `
                -Paths $paths2 `
                -Description "File Temporanei Internet (per tutti gli utenti)" `
                -Icon '🌐' `
                -TakeOwnership `
                -PerUser

            & RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 8 2>$null
            & RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 2 2>$null

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount
            Write-StyledMessage Success "✅ Cache WinInet e file temporanei Internet puliti"
            $script:Log += "[WinInetCache] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cache WinInet: $_"
            $script:Log += "[WinInetCache] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-InternetCookiesCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🍪 Pulizia cookie Internet..."
        
        try {
            $result = Invoke-DeletePaths `
                -Paths @(
                "%APPDATA%\Microsoft\Windows\Cookies"
                "%LOCALAPPDATA%\Microsoft\Windows\INetCookies"
            ) `
                -Description "Cookie Internet (per tutti gli utenti)" `
                -Icon '🍪' `
                -PerUser

            & RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 1 2>$null

            Write-StyledMessage Success "✅ Cookie Internet puliti"
            $script:Log += "[InternetCookies] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cookie: $_"
            $script:Log += "[InternetCookies] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DNSFlush {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🔄 Flush cache DNS..."
        
        try {
            $result = & ipconfig /flushdns 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-StyledMessage Success "✅ Cache DNS svuotata con successo"
                $script:Log += "[DNSFlush] ✅ Flush completato"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Warning "Flush DNS completato con warnings"
                $script:Log += "[DNSFlush] Completato con warnings"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Warning "Errore durante flush DNS: $_"
            $script:Log += "[DNSFlush] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WindowsTempCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🗂️ Pulizia file temporanei Windows..."
        
        try {
            $result = Invoke-DeletePaths `
                -Paths @("C:\WINDOWS\Temp", "$env:SYSTEMROOT\Temp") `
                -Description "File temporanei di sistema Windows" `
                -Icon '🗂️'

            Write-StyledMessage Success "✅ File temporanei Windows puliti"
            $script:Log += "[WindowsTemp] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia file temporanei Windows: $_"
            $script:Log += "[WindowsTemp] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-UserTempCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "📁 Pulizia file temporanei utente..."
        
        try {
            $result = Invoke-DeletePaths `
                -Paths @(
                "%USERPROFILE%\AppData\Local\Temp"
                "%USERPROFILE%\AppData\LocalLow\Temp"
                "%TEMP%"
            ) `
                -Description "File temporanei utente" `
                -Icon '📁' `
                -PerUser

            Write-StyledMessage Success "✅ File temporanei utente puliti"
            $script:Log += "[UserTemp] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia file temporanei utente: $_"
            $script:Log += "[UserTemp] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-PrintQueueCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🖨️ Pulizia coda di stampa..."
        
        try {
            Write-StyledMessage Info "⏸️ Arresto servizio spooler..."
            Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2

            $spoolPath = "C:\WINDOWS\System32\spool\PRINTERS"
            $totalCleaned = 0

            if (Test-Path $spoolPath) {
                $files = Get-ChildItem -Path $spoolPath -File -ErrorAction SilentlyContinue
                $files | Remove-Item -Force -ErrorAction SilentlyContinue
                $totalCleaned = $files.Count
            }

            Write-StyledMessage Info "▶️ Riavvio servizio spooler..."
            Start-Service -Name Spooler -ErrorAction SilentlyContinue

            if ($totalCleaned -gt 0) {
                Write-StyledMessage Success "✅ Coda di stampa pulita ($totalCleaned file)"
                $script:Log += "[PrintQueue] ✅ Pulizia completata ($totalCleaned file)"
            }
            else {
                Write-StyledMessage Info "💭 Nessun file in coda di stampa"
                $script:Log += "[PrintQueue] ℹ️ Nessun file da pulire"
            }

            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Start-Service -Name Spooler -ErrorAction SilentlyContinue
            Write-StyledMessage Warning "Errore durante pulizia coda di stampa: $_"
            $script:Log += "[PrintQueue] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-SystemLogsCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "📄 Pulizia log di sistema..."
        
        $logPaths = @(
            "C:\WINDOWS\Logs"
            "C:\WINDOWS\System32\LogFiles"
            "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"
        )
        
        $totalCleaned = 0
        $totalSize = 0
        
        foreach ($path in $logPaths) {
            if (Test-ExcludedPath $path) {
                continue
            }
        
            if (Test-Path $path) {
                try {
                    $files = Get-ChildItem -Path $path -Recurse -File -Include "*.log", "*.etl", "*.txt" -ErrorAction SilentlyContinue | 
                    Where-Object { -not (Test-ExcludedPath $_.FullName) }
                    
                    $size = ($files | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB
                    $files | Remove-Item -Force -ErrorAction SilentlyContinue
                    $totalCleaned += $files.Count
                    $totalSize += $size
                    Write-StyledMessage Info "🗑️ Puliti log da: $path"
                }
                catch {
                    Write-StyledMessage Warning "Impossibile pulire alcuni log in $path"
                }
            }
        }
        
        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Log di sistema puliti ($totalCleaned file, $([math]::Round($totalSize, 2)) MB)"
            $script:Log += "[SystemLogs] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessun log di sistema da pulire"
            $script:Log += "[SystemLogs] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
        }
    }

    function Invoke-QuickAccessAndRecentFilesCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "📁 Pulizia Accesso Rapido e File Recenti..."
        
        try {
            $result = Invoke-DeletePaths `
                -Paths @(
                "%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations"
                "%APPDATA%\Microsoft\Windows\Recent\CustomDestinations"
                "%APPDATA%\Microsoft\Windows\Recent Items"
            ) `
                -Description 'Pulizia Accesso Rapido e File Recenti' `
                -Icon '📁' `
                -PerUser

            Write-StyledMessage Success "✅ Accesso Rapido e File Recenti puliti"
            $script:Log += "[QuickAccessAndRecentFiles] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Accesso Rapido e File Recenti: $_"
            $script:Log += "[QuickAccessAndRecentFiles] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-RegeditHistoryCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "⚙️ Pulizia cronologia Regedit..."
        
        try {
            Remove-ItemProperty -LiteralPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit' `
                -Name 'LastKey' -ErrorAction SilentlyContinue
            
            $result = Invoke-ClearRegistryKeyValues `
                -KeyPath 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites' `
                -Description 'Valori Preferiti Regedit' `
                -Icon '⚙️'

            Write-StyledMessage Success "✅ Cronologia Regedit pulita"
            $script:Log += "[RegeditHistory] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia Regedit: $_"
            $script:Log += "[RegeditHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ComDlg32HistoryCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "📜 Pulizia cronologia finestre di dialogo file..."
        
        try {
            $registryPaths = @(
                'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedMRU'
                'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU'
                'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRULegacy'
                'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs'
                'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU'
                'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU'
            )

            $totalErrors = 0
            foreach ($regPath in $registryPaths) {
                $result = Invoke-ClearRegistryKeyValues `
                    -KeyPath $regPath `
                    -Description 'Cronologia finestre di dialogo' `
                    -Icon '📜' `
                    -Recursive
                $totalErrors += $result.ErrorCount
            }

            Write-StyledMessage Success "✅ Cronologia finestre di dialogo pulita"
            $script:Log += "[ComDlg32History] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia finestre di dialogo: $_"
            $script:Log += "[ComDlg32History] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-AdobeMediaBrowserCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🖼️ Pulizia cronologia Adobe Media Browser..."
        
        try {
            $result = Invoke-RemoveRegistryKeyFull `
                -KeyPath 'HKCU\Software\Adobe\MediaBrowser\MRU' `
                -Description 'Chiave Cronologia Adobe Media Browser' `
                -Icon '🖼️'

            Write-StyledMessage Success "✅ Cronologia Adobe Media Browser pulita"
            $script:Log += "[AdobeMediaBrowser] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Adobe Media Browser: $_"
            $script:Log += "[AdobeMediaBrowser] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-PaintAndWordPadHistoryCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🎨 Pulizia cronologia Paint e WordPad..."
        
        try {
            $result1 = Invoke-ClearRegistryKeyValues `
                -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Applets\Paint\Recent File List' `
                -Description 'Cronologia file recenti Paint' `
                -Icon '🎨'
            
            $result2 = Invoke-ClearRegistryKeyValues `
                -KeyPath 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Wordpad\Recent File List' `
                -Description 'Cronologia file recenti WordPad' `
                -Icon '🎨'

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount
            Write-StyledMessage Success "✅ Cronologia Paint e WordPad pulita"
            $script:Log += "[PaintAndWordPadHistory] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia Paint e WordPad: $_"
            $script:Log += "[PaintAndWordPadHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-NetworkDriveHistoryCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🌐 Pulizia cronologia mappatura unità di rete..."
        
        try {
            $result = Invoke-ClearRegistryKeyValues `
                -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Map Network Drive MRU' `
                -Description 'Cronologia mappatura unità di rete' `
                -Icon '🌐'

            Write-StyledMessage Success "✅ Cronologia mappatura unità di rete pulita"
            $script:Log += "[NetworkDriveHistory] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia unità di rete: $_"
            $script:Log += "[NetworkDriveHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WindowsSearchHistoryCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🔍 Pulizia cronologia ricerca Windows..."
        
        try {
            $registryPaths = @(
                'HKCU\Software\Microsoft\Search Assistant\ACMru'
                'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery'
                'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\SearchHistory'
            )

            $totalErrors = 0
            foreach ($regPath in $registryPaths) {
                $result = Invoke-ClearRegistryKeyValues `
                    -KeyPath $regPath `
                    -Description 'Cronologia ricerca Windows' `
                    -Icon '🔍' `
                    -Recursive
                $totalErrors += $result.ErrorCount
            }

            $result4 = Invoke-DeletePaths `
                -Paths @("%LOCALAPPDATA%\Microsoft\Windows\ConnectedSearch\History") `
                -Description 'Cartella cronologia ricerca Windows' `
                -Icon '🔍' `
                -PerUser

            $totalErrors += $result4.ErrorCount
            Write-StyledMessage Success "✅ Cronologia ricerca Windows pulita"
            $script:Log += "[WindowsSearchHistory] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia ricerca Windows: $_"
            $script:Log += "[WindowsSearchHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-MediaPlayerHistoryCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🎵 Pulizia cronologia Media Player..."
        
        try {
            $registryPaths = @(
                'HKCU\Software\Microsoft\MediaPlayer\Player\RecentFileList'
                'HKCU\Software\Microsoft\MediaPlayer\Player\RecentURLList'
                'HKCU\Software\Gabest\Media Player Classic\Recent File List'
            )

            $totalErrors = 0
            foreach ($regPath in $registryPaths) {
                $result = Invoke-ClearRegistryKeyValues `
                    -KeyPath $regPath `
                    -Description 'Cronologia Media Player' `
                    -Icon '🎵'
                $totalErrors += $result.ErrorCount
            }

            Write-StyledMessage Success "✅ Cronologia Media Player pulita"
            $script:Log += "[MediaPlayerHistory] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia Media Player: $_"
            $script:Log += "[MediaPlayerHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DirectXHistoryCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🎮 Pulizia cronologia applicazioni DirectX..."
        
        try {
            $result = Invoke-ClearRegistryKeyValues `
                -KeyPath 'HKCU\Software\Microsoft\Direct3D\MostRecentApplication' `
                -Description 'Cronologia applicazioni DirectX' `
                -Icon '🎮'

            Write-StyledMessage Success "✅ Cronologia DirectX pulita"
            $script:Log += "[DirectXHistory] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia DirectX: $_"
            $script:Log += "[DirectXHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-RunCommandHistoryCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "▶️ Pulizia cronologia comandi Esegui..."
        
        try {
            $result = Invoke-ClearRegistryKeyValues `
                -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU' `
                -Description 'Cronologia comandi Esegui' `
                -Icon '▶️'

            Write-StyledMessage Success "✅ Cronologia comandi Esegui pulita"
            $script:Log += "[RunCommandHistory] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia Esegui: $_"
            $script:Log += "[RunCommandHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-FileExplorerAddressBarHistoryCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "📂 Pulizia cronologia barra indirizzi Esplora File..."
        
        try {
            $result = Invoke-ClearRegistryKeyValues `
                -KeyPath 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths' `
                -Description 'Cronologia barra indirizzi Esplora File' `
                -Icon '📂'

            Write-StyledMessage Success "✅ Cronologia barra indirizzi pulita"
            $script:Log += "[FileExplorerAddressBarHistory] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia barra indirizzi: $_"
            $script:Log += "[FileExplorerAddressBarHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ListarySearchIndexCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "📊 Pulizia indice di ricerca Listary..."
        
        try {
            $result = Invoke-DeletePaths `
                -Paths @("%APPDATA%\Listary\UserData") `
                -Description 'Indice di ricerca Listary' `
                -Icon '📊' `
                -PerUser

            Write-StyledMessage Success "✅ Indice Listary pulito"
            $script:Log += "[ListarySearchIndex] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia indice Listary: $_"
            $script:Log += "[ListarySearchIndex] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-JavaCacheCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "☕ Pulizia cache Java..."
        
        try {
            $result = Invoke-DeletePaths `
                -Paths @("%APPDATA%\Sun\Java\Deployment\cache") `
                -Description 'Cache Java' `
                -Icon '☕' `
                -PerUser

            Write-StyledMessage Success "✅ Cache Java pulita"
            $script:Log += "[JavaCache] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cache Java: $_"
            $script:Log += "[JavaCache] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DotnetTelemetryCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🌐 Pulizia telemetria Dotnet CLI..."
        
        try {
            $result = Invoke-DeletePaths `
                -Paths @("%USERPROFILE%\.dotnet\TelemetryStorageService") `
                -Description 'Telemetria Dotnet CLI' `
                -Icon '🌐' `
                -PerUser

            Write-StyledMessage Success "✅ Telemetria Dotnet pulita"
            $script:Log += "[DotnetTelemetry] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia telemetria Dotnet: $_"
            $script:Log += "[DotnetTelemetry] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ChromeCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🌐 Pulizia dati e crash report Chrome..."
        
        try {
            $paths1 = @(
                "%LOCALAPPDATA%\Google\Chrome\User Data\Crashpad\reports"
                "%LOCALAPPDATA%\Google\CrashReports"
            )
            
            $result1 = Invoke-DeletePaths `
                -Paths $paths1 `
                -Description 'Crash Report Chrome' `
                -Icon '🌐'
            
            $result2 = Invoke-DeletePaths `
                -Paths @("%LOCALAPPDATA%\Google\Software Reporter Tool\*.log") `
                -Description 'Log Software Reporter Tool di Google' `
                -Icon '🌐' `
                -FilesOnly
            
            $paths3 = @(
                "%USERPROFILE%\Local Settings\Application Data\Google\Chrome\User Data"
                "%LOCALAPPDATA%\Google\Chrome\User Data"
            )
            
            $result3 = Invoke-DeletePaths `
                -Paths $paths3 `
                -Description 'Dati utente Chrome' `
                -Icon '🌐' `
                -TakeOwnership `
                -PerUser

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount
            Write-StyledMessage Success "✅ Dati Chrome puliti"
            $script:Log += "[ChromeCleanup] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Chrome: $_"
            $script:Log += "[ChromeCleanup] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-FirefoxCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🦊 Pulizia cronologia e profili Firefox..."
        
        try {
            $firefoxPaths = @(
                "%USERPROFILE%\Local Settings\Application Data\Mozilla\Firefox\Profiles\*"
                "%APPDATA%\Mozilla\Firefox\Profiles\*"
                "%LOCALAPPDATA%\Packages\Mozilla.Firefox_n80bbvh6b1yt2\LocalCache\Roaming\Mozilla\Firefox\Profiles\*"
            )

            $filePatterns = @("downloads.rdf", "downloads.sqlite", "places.sqlite", "favicons.sqlite")
            
            $totalErrors = 0
            foreach ($pattern in $filePatterns) {
                $paths = $firefoxPaths | ForEach-Object { "$_\$pattern" }
                $result = Invoke-DeletePaths `
                    -Paths $paths `
                    -Description "Cronologia Firefox ($pattern)" `
                    -Icon '🦊' `
                    -FilesOnly `
                    -PerUser
                $totalErrors += $result.ErrorCount
            }

            $profilePaths = @(
                "%LOCALAPPDATA%\Mozilla\Firefox\Profiles"
                "%APPDATA%\Mozilla\Firefox\Profiles"
                "%LOCALAPPDATA%\Packages\Mozilla.Firefox_n80bbvh6b1yt2\LocalCache\Roaming\Mozilla\Firefox\Profiles"
            )
            
            $result5 = Invoke-DeletePaths `
                -Paths $profilePaths `
                -Description 'Profili utente Firefox' `
                -Icon '🦊' `
                -PerUser

            $totalErrors += $result5.ErrorCount
            Write-StyledMessage Success "✅ Firefox pulito"
            $script:Log += "[FirefoxCleanup] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Firefox: $_"
            $script:Log += "[FirefoxCleanup] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-OperaCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🅾️ Pulizia dati e cronologia Opera..."
        
        try {
            $result = Invoke-DeletePaths `
                -Paths @(
                "%USERPROFILE%\Local Settings\Application Data\Opera\Opera"
                "%LOCALAPPDATA%\Opera\Opera"
                "%APPDATA%\Opera\Opera"
            ) `
                -Description 'Dati utente Opera' `
                -Icon '🅾️' `
                -PerUser

            Write-StyledMessage Success "✅ Opera pulito"
            $script:Log += "[OperaCleanup] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Opera: $_"
            $script:Log += "[OperaCleanup] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-CLRUsageTracesCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "💻 Pulizia tracce di utilizzo .NET CLR..."
        
        try {
            $result = Invoke-DeletePaths `
                -Paths @(
                "%LOCALAPPDATA%\Microsoft\CLR_v4.0\UsageTraces"
                "%LOCALAPPDATA%\Microsoft\CLR_v4.0_32\UsageTraces"
            ) `
                -Description 'Tracce di utilizzo .NET CLR' `
                -Icon '💻' `
                -PerUser

            Write-StyledMessage Success "✅ Tracce .NET CLR pulite"
            $script:Log += "[CLRUsageTraces] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia tracce .NET CLR: $_"
            $script:Log += "[CLRUsageTraces] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-VisualStudioTelemetryRootCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "💻 Pulizia telemetria Visual Studio..."
        
        try {
            $userPaths = @(
                "%LOCALAPPDATA%\Microsoft\VSCommon\14.0\SQM"
                "%LOCALAPPDATA%\Microsoft\VSCommon\15.0\SQM"
                "%LOCALAPPDATA%\Microsoft\VSCommon\16.0\SQM"
                "%LOCALAPPDATA%\Microsoft\VSCommon\17.0\SQM"
                "%LOCALAPPDATA%\Microsoft\VSApplicationInsights"
                "%TEMP%\Microsoft\VSApplicationInsights"
                "%APPDATA%\vstelemetry"
                "%TEMP%\VSFaultInfo"
                "%TEMP%\VSFeedbackPerfWatsonData"
                "%TEMP%\VSFeedbackVSRTCLogs"
                "%TEMP%\VSFeedbackIntelliCodeLogs"
                "%TEMP%\VSRemoteControl"
                "%TEMP%\Microsoft\VSFeedbackCollector"
                "%TEMP%\VSTelem"
                "%TEMP%\VSTelem.Out"
            )
            
            $result1 = Invoke-DeletePaths `
                -Paths $userPaths `
                -Description 'Telemetria Visual Studio per-utente' `
                -Icon '💻' `
                -PerUser
            
            $globalPaths = @(
                "%PROGRAMDATA%\Microsoft\VSApplicationInsights"
                "%PROGRAMDATA%\vstelemetry"
            )
            
            $result2 = Invoke-DeletePaths `
                -Paths $globalPaths `
                -Description 'Telemetria Visual Studio globale' `
                -Icon '💻'

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount
            Write-StyledMessage Success "✅ Telemetria Visual Studio pulita"
            $script:Log += "[VisualStudioTelemetry] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia telemetria Visual Studio: $_"
            $script:Log += "[VisualStudioTelemetry] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-VisualStudioLicensesCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "💻 Pulizia licenze Visual Studio..."
        
        try {
            $licensePaths = @(
                'HKLM\SOFTWARE\Classes\Licenses\77550D6B-6352-4E77-9DA3-537419DF564B'  # VS 2010
                'HKLM\SOFTWARE\Classes\Licenses\E79B3F9C-6543-4897-BBA5-5BFB0A02BB5C'  # VS 2013
                'HKLM\SOFTWARE\Classes\Licenses\4D8CFBCB-2F6A-4AD2-BABF-10E28F6F2C8F'  # VS 2015
                'HKLM\SOFTWARE\Classes\Licenses\5C505A59-E312-4B89-9508-E162F8150517'  # VS 2017
                'HKLM\SOFTWARE\Classes\Licenses\41717607-F34E-432C-A138-A3CFD7E25CDA'  # VS 2019
                'HKLM\SOFTWARE\Classes\Licenses\B16F0CF0-8AD1-4A5B-87BC-CB0DBE9C48FC'  # VS 2022
                'HKLM\SOFTWARE\Classes\Licenses\10D17DBA-761D-4CD8-A627-984E75A58700'  # VS 2022
                'HKLM\SOFTWARE\Classes\Licenses\1299B4B9-DFCC-476D-98F0-F65A2B46C96D'  # VS 2022
            )

            $totalErrors = 0
            foreach ($licensePath in $licensePaths) {
                $result = Invoke-RemoveRegistryKeyFull `
                    -KeyPath $licensePath `
                    -Description 'Licenza Visual Studio' `
                    -Icon '💻'
                $totalErrors += $result.ErrorCount
            }

            Write-StyledMessage Success "✅ Licenze Visual Studio pulite"
            $script:Log += "[VisualStudioLicenses] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia licenze Visual Studio: $_"
            $script:Log += "[VisualStudioLicenses] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WindowsSystemProfilesTempCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "👤 Pulizia temp profili di servizio Windows..."
        
        try {
            $result = Invoke-DeletePaths `
                -Paths @("%SYSTEMROOT%\ServiceProfiles\LocalService\AppData\Local\Temp") `
                -Description 'Temp profili di servizio Windows' `
                -Icon '👤'

            Write-StyledMessage Success "✅ Temp profili servizio puliti"
            $script:Log += "[WindowsSystemProfilesTemp] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia temp profili servizio: $_"
            $script:Log += "[WindowsSystemProfilesTemp] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-SystemLogFileCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "📄 Pulizia log di sistema e applicazioni varie..."
        
        try {
            $dirPaths = @(
                "%SYSTEMROOT%\Temp\CBS"
                "%SYSTEMROOT%\Logs\waasmedic"
                "%SYSTEMROOT%\Logs\SIH"
                "%SYSTEMROOT%\Traces\WindowsUpdate"
                "%SYSTEMROOT%\Logs\NetSetup"
                "%SYSTEMROOT%\System32\LogFiles\setupcln"
                "%SYSTEMROOT%\Panther"
            )
            
            $result1 = Invoke-DeletePaths `
                -Paths $dirPaths `
                -Description 'Log di sistema vari' `
                -Icon '📄'
            
            $filePaths = @(
                "%SYSTEMROOT%\comsetup.log"
                "%SYSTEMROOT%\DtcInstall.log"
                "%SYSTEMROOT%\PFRO.log"
                "%SYSTEMROOT%\setupact.log"
                "%SYSTEMROOT%\setuperr.log"
                "%SYSTEMROOT%\inf\setupapi.app.log"
                "%SYSTEMROOT%\inf\setupapi.dev.log"
                "%SYSTEMROOT%\inf\setupapi.offline.log"
                "%SYSTEMROOT%\Performance\WinSAT\winsat.log"
                "%SYSTEMROOT%\debug\PASSWD.LOG"
                "%SYSTEMROOT%\System32\catroot2\dberr.txt"
                "%SYSTEMROOT%\System32\catroot2.log"
                "%SYSTEMROOT%\System32\catroot2.jrs"
                "%SYSTEMROOT%\System32\catroot2.edb"
                "%SYSTEMROOT%\System32\catroot2.chk"
                "%SYSTEMROOT%\Logs\CBS\CBS.log"
                "%SYSTEMROOT%\Logs\DISM\DISM.log"
            )
            
            $result2 = Invoke-DeletePaths `
                -Paths $filePaths `
                -Description 'File log di sistema specifici' `
                -Icon '📄' `
                -FilesOnly

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount
            Write-StyledMessage Success "✅ Log di sistema puliti"
            $script:Log += "[SystemLogFileCleanup] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia log di sistema: $_"
            $script:Log += "[SystemLogFileCleanup] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-MinimizeDISMResetBase {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "📊 Minimizzazione dati aggiornamenti DISM..."
        
        try {
            $result = Invoke-SetRegistryKeyValue `
                -KeyPath 'HKLM\Software\Microsoft\Windows\CurrentVersion\SideBySide\Configuration' `
                -ValueName 'DisableResetbase' `
                -ValueData 0 `
                -ValueType DWORD `
                -Description 'Valore DisableResetbase per DISM' `
                -Icon '📊'

            Write-StyledMessage Success "✅ DISM configurato"
            $script:Log += "[MinimizeDISMResetBase] ✅ Configurazione completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante configurazione DISM: $_"
            $script:Log += "[MinimizeDISMResetBase] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WindowsUpdateFilesCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🔄 Pulizia file temporanei Windows Update..."
        
        try {
            $result1 = Invoke-ServiceControl -ServiceName 'wuauserv' -Action 'Stop' -Description 'Servizio Windows Update' -Icon '🔄'
            $result2 = Invoke-DeletePaths -Paths @("%SYSTEMROOT%\SoftwareDistribution") -Description 'Cartella SoftwareDistribution' -Icon '🔄'
            $result3 = Invoke-ServiceControl -ServiceName 'wuauserv' -Action 'Start' -Description 'Servizio Windows Update' -Icon '🔄'

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount
            Write-StyledMessage Success "✅ File Windows Update puliti"
            $script:Log += "[WindowsUpdateFiles] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Windows Update: $_"
            $script:Log += "[WindowsUpdateFiles] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DiagTrackLogsCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🚫 Pulizia log di tracciamento diagnostica..."
        
        try {
            $result1 = Invoke-ServiceControl -ServiceName 'DiagTrack' -Action 'Stop' -Description 'Servizio di Tracciamento Diagnostica' -Icon '🚫'
            
            $logPaths = @(
                "%PROGRAMDATA%\Microsoft\Diagnosis\ETLLogs\AutoLogger\AutoLogger-Diagtrack-Listener.etl"
                "%PROGRAMDATA%\Microsoft\Diagnosis\ETLLogs\ShutdownLogger\AutoLogger-Diagtrack-Listener.etl"
            )
            
            $result2 = Invoke-DeletePaths `
                -Paths $logPaths `
                -Description 'Log di tracciamento diagnostica' `
                -Icon '🚫' `
                -FilesOnly `
                -TakeOwnership
            
            $result3 = Invoke-ServiceControl -ServiceName 'DiagTrack' -Action 'Start' -Description 'Servizio di Tracciamento Diagnostica' -Icon '🚫'

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount
            Write-StyledMessage Success "✅ Log DiagTrack puliti"
            $script:Log += "[DiagTrackLogs] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia DiagTrack: $_"
            $script:Log += "[DiagTrackLogs] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DefenderProtectionHistoryCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🛡️ Pulizia cronologia protezione Windows Defender..."
        
        try {
            $result = Invoke-DeletePaths `
                -Paths @("%ProgramData%\Microsoft\Windows Defender\Scans\History") `
                -Description 'Cronologia protezione Windows Defender' `
                -Icon '🛡️' `
                -TakeOwnership

            Write-StyledMessage Success "✅ Cronologia Defender pulita"
            $script:Log += "[DefenderProtectionHistory] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia Defender: $_"
            $script:Log += "[DefenderProtectionHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-SystemResourceUsageMonitorCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "📈 Pulizia dati SRUM..."
        
        try {
            $result1 = Invoke-ServiceControl -ServiceName 'DPS' -Action 'Stop' -Description 'Servizio Monitoraggio Utilizzo Risorse' -Icon '📈'
            $result2 = Invoke-DeletePaths -Paths @("%SYSTEMROOT%\System32\sru\SRUDB.dat") -Description 'Database SRUM' -Icon '📈' -FilesOnly -TakeOwnership
            $result3 = Invoke-ServiceControl -ServiceName 'DPS' -Action 'Start' -Description 'Servizio Monitoraggio Utilizzo Risorse' -Icon '📈'

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount
            Write-StyledMessage Success "✅ Dati SRUM puliti"
            $script:Log += "[SystemResourceUsageMonitor] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia SRUM: $_"
            $script:Log += "[SystemResourceUsageMonitor] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-CredentialManagerCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🔑 Pulizia credenziali Windows..."
        
        try {
            $credentials = & cmdkey /list 2>$null | 
            Where-Object { $_ -match '^Target:' } | 
            ForEach-Object { $_.Split(':')[1].Trim() }
            
            foreach ($cred in $credentials) {
                & cmdkey /delete:$cred 2>$null | Out-Null
            }

            Write-StyledMessage Success "✅ Credenziali pulite"
            $script:Log += "[CredentialManager] ✅ Pulizia completata"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia credenziali: $_"
            $script:Log += "[CredentialManager] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-RecycleBinEmpty {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🗑️ Svuotamento cestino..."
        
        try {
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(0xA)
            $recycleBin.Items() | ForEach-Object { 
                $_.InvokeVerb("delete") 
            }

            Write-StyledMessage Success "✅ Cestino svuotato"
            $script:Log += "[RecycleBinEmpty] ✅ Svuotamento completato"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning "Errore durante svuotamento cestino: $_"
            $script:Log += "[RecycleBinEmpty] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WindowsOldCleanup {
        [CmdletBinding()]
        param()

        Write-StyledMessage Info "🗑️ Pulizia cartella Windows.old..."
        $windowsOldPath = "C:\Windows.old"
        $errorCount = 0
        
        try {
            if (Test-Path -Path $windowsOldPath) {
                Write-StyledMessage Info "🔍 Trovata cartella Windows.old. Tentativo di rimozione forzata..."
                $script:Log += "[WindowsOld] 🔍 Trovata cartella Windows.old. Tentativo di rimozione forzata..."
        
                # 1. Assumere la proprietà (Take Ownership)
                Write-StyledMessage Info "1. Assunzione della proprietà (Take Ownership)..."
                $takeownResult = & cmd /c "takeown /F `"$windowsOldPath`" /R /A /D Y 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Write-StyledMessage Warning "Errore durante l'assunzione della proprietà: $takeownResult"
                    $script:Log += "[WindowsOld] Errore takeown: $takeownResult"
                    $errorCount++
                }
                else {
                    Write-StyledMessage Info "✅ Proprietà assunta."
                    $script:Log += "[WindowsOld] ✅ Proprietà assunta."
                }
                Start-Sleep -Milliseconds 500
        
                # 2. Assegnare i permessi di controllo completo agli amministratori
                Write-StyledMessage Info "2. Assegnazione dei permessi di Controllo Completo (Full Control)..."
                $icaclsResult = & cmd /c "icacls `"$windowsOldPath`" /T /grant Administrators:F 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Write-StyledMessage Warning "Errore durante l'assegnazione permessi: $icaclsResult"
                    $script:Log += "[WindowsOld] Errore icacls: $icaclsResult"
                    $errorCount++
                }
                else {
                    Write-StyledMessage Info "✅ Permessi di controllo completo assegnati agli Amministratori."
                    $script:Log += "[WindowsOld] ✅ Permessi di controllo completo assegnati agli Amministratori."
                }
                Start-Sleep -Milliseconds 500
        
                # 3. Rimuovere la cartella con la forzatura
                Write-StyledMessage Info "3. Rimozione forzata della cartella..."
                try {
                    Remove-Item -Path $windowsOldPath -Recurse -Force -ErrorAction Stop
                }
                catch {
                    Write-StyledMessage Error "ERRORE durante la rimozione di Windows.old: $($_.Exception.Message)"
                    $script:Log += "[WindowsOld] ERRORE durante la rimozione: $($_.Exception.Message)"
                    $errorCount++
                }
                    
                # 4. Verifica finale
                if (Test-Path -Path $windowsOldPath) {
                    Write-StyledMessage Error "ERRORE: La cartella $windowsOldPath non è stata rimossa."
                    $script:Log += "[WindowsOld] Cartella non rimossa dopo tentativi forzati."
                    $errorCount++
                }
                else {
                    Write-StyledMessage Success "✅ La cartella Windows.old è stata rimossa con successo."
                    $script:Log += "[WindowsOld] ✅ Rimozione completata."
                }
            }
            else {
                Write-StyledMessage Info "💭 La cartella Windows.old non è presente. Nessuna azione necessaria."
                $script:Log += "[WindowsOld] ℹ️ Non presente, nessuna azione."
            }
        }
        catch {
            Write-StyledMessage Error "Errore fatale durante la pulizia di Windows.old: $($_.Exception.Message)"
            $script:Log += "[WindowsOld] 💥 Errore fatale: $($_.Exception.Message)"
            $errorCount++
        }
        
        return @{ Success = ($errorCount -eq 0); ErrorCount = $errorCount }
    }

    function Invoke-CleanupTask {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [hashtable]$Task,
            
            [Parameter(Mandatory = $true)]
            [int]$Step,
            
            [Parameter(Mandatory = $true)]
            [int]$Total
        )

        Write-StyledMessage Info "[$Step/$Total] Avvio $($Task.Name)..."

        try {
            $result = switch ($Task.Task) {
                'CleanMgrAuto' { Invoke-CleanMgrAuto }
                'WinSxS' { Invoke-WinSxSCleanup }
                'ErrorReports' { Invoke-ErrorReportsCleanup }
                'EventLogs' { Invoke-EventLogsCleanup }
                'UpdateHistory' { Invoke-UpdateHistoryCleanup }
                'RestorePoints' { Invoke-RestorePointsCleanup }
                'DownloadCache' { Invoke-DownloadCacheCleanup }
                'PrefetchCleanup' { Invoke-PrefetchCleanup }
                'ThumbnailCache' { Invoke-ThumbnailCacheCleanup }
                'WinInetCacheCleanup' { Invoke-WinInetCacheCleanup }
                'InternetCookiesCleanup' { Invoke-InternetCookiesCleanup }
                'DNSFlush' { Invoke-DNSFlush }
                'WindowsTempCleanup' { Invoke-WindowsTempCleanup }
                'UserTempCleanup' { Invoke-UserTempCleanup }
                'PrintQueue' { Invoke-PrintQueueCleanup }
                'SystemLogs' { Invoke-SystemLogsCleanup }
                'QuickAccessAndRecentFilesCleanup' { Invoke-QuickAccessAndRecentFilesCleanup }
                'RegeditHistoryCleanup' { Invoke-RegeditHistoryCleanup }
                'ComDlg32HistoryCleanup' { Invoke-ComDlg32HistoryCleanup }
                'AdobeMediaBrowserCleanup' { Invoke-AdobeMediaBrowserCleanup }
                'PaintAndWordPadHistoryCleanup' { Invoke-PaintAndWordPadHistoryCleanup }
                'NetworkDriveHistoryCleanup' { Invoke-NetworkDriveHistoryCleanup }
                'WindowsSearchHistoryCleanup' { Invoke-WindowsSearchHistoryCleanup }
                'MediaPlayerHistoryCleanup' { Invoke-MediaPlayerHistoryCleanup }
                'DirectXHistoryCleanup' { Invoke-DirectXHistoryCleanup }
                'RunCommandHistoryCleanup' { Invoke-RunCommandHistoryCleanup }
                'FileExplorerAddressBarHistoryCleanup' { Invoke-FileExplorerAddressBarHistoryCleanup }
                'ListarySearchIndexCleanup' { Invoke-ListarySearchIndexCleanup }
                'JavaCacheCleanup' { Invoke-JavaCacheCleanup }
                'DotnetTelemetryCleanup' { Invoke-DotnetTelemetryCleanup }
                'ChromeCleanup' { Invoke-ChromeCleanup }
                'FirefoxCleanup' { Invoke-FirefoxCleanup }
                'OperaCleanup' { Invoke-OperaCleanup }
                'CLRUsageTracesCleanup' { Invoke-CLRUsageTracesCleanup }
                'VisualStudioTelemetryRootCleanup' { Invoke-VisualStudioTelemetryRootCleanup }
                'VisualStudioLicensesCleanup' { Invoke-VisualStudioLicensesCleanup }
                'WindowsSystemProfilesTempCleanup' { Invoke-WindowsSystemProfilesTempCleanup }
                'SystemLogFileCleanup' { Invoke-SystemLogFileCleanup }
                'MinimizeDISMResetBase' { Invoke-MinimizeDISMResetBase }
                'WindowsUpdateFilesCleanup' { Invoke-WindowsUpdateFilesCleanup }
                'DiagTrackLogsCleanup' { Invoke-DiagTrackLogsCleanup }
                'DefenderProtectionHistoryCleanup' { Invoke-DefenderProtectionHistoryCleanup }
                'SystemResourceUsageMonitorCleanup' { Invoke-SystemResourceUsageMonitorCleanup }
                'CredentialManagerCleanup' { Invoke-CredentialManagerCleanup }
                'RecycleBinEmpty' { Invoke-RecycleBinEmpty }
                'WindowsOld' { Invoke-WindowsOldCleanup }
                default {
                    Write-StyledMessage Warning "Task sconosciuto: $($Task.Task)"
                    @{ Success = $false; ErrorCount = 1 }
                }
            }

            if ($result.Success) {
                Write-StyledMessage Success "$($Task.Icon) $($Task.Name) completato con successo"
            }
            else {
                Write-StyledMessage Warning "$($Task.Icon) $($Task.Name) completato con errori"
            }

            return $result
        }
        catch {
            Write-StyledMessage Error "Errore durante $($Task.Name): $_"
            $script:Log += "[$($Task.Name)] Errore fatale: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    # ============================================================================
    # ESECUZIONE PRINCIPALE
    # ============================================================================

    Show-Header

    # Countdown preparazione
    for ($i = 5; $i -gt 0; $i--) {
        $spinner = $script:Spinners[$i % $script:Spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    try {
        Write-StyledMessage Info '🧹 Avvio pulizia completa del sistema...'
        Write-Host ''

        $totalErrors = 0
        $successCount = 0
        
        for ($i = 0; $i -lt $script:CleanupTasks.Count; $i++) {
            $result = Invoke-CleanupTask -Task $script:CleanupTasks[$i] -Step ($i + 1) -Total $script:CleanupTasks.Count
            
            if ($result.Success) { 
                $successCount++ 
            }
            $totalErrors += $result.ErrorCount
            Start-Sleep -Milliseconds 500
        }

        Write-Host ''
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-StyledMessage Success "🎉 Pulizia completata con successo!"
        Write-StyledMessage Success "💻 Completati $successCount/$($script:CleanupTasks.Count) task di pulizia"

        if ($totalErrors -gt 0) {
            Write-StyledMessage Warning "$totalErrors errori durante la pulizia"
        }

        # Mostra riepilogo dettagliato
        Write-Host ''
        Write-StyledMessage Info "📊 RIEPILOGO OPERAZIONI:"
        foreach ($logEntry in $script:Log) {
            if ($logEntry -match '✅|ℹ️') {
                Write-Host "  $logEntry" -ForegroundColor Gray
            }
        }

        Write-StyledMessage Info "🔄 Il sistema verrà riavviato per applicare tutte le modifiche"
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-Host ''

        $shouldReboot = Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Preparazione riavvio sistema"

        if ($shouldReboot) {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
            Restart-Computer -Force
        }
        else {
            Write-StyledMessage Success "✅ Pulizia completata. Sistema non riavviato."
            Write-StyledMessage Info "💡 Riavvia quando possibile per applicare tutte le modifiche."
        }
    }
    catch {
        Write-Host ''
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage Error "💥 Errore critico: $($_.Exception.Message)"
        Write-StyledMessage Error 'Si è verificato un errore durante la pulizia.'
        Write-Host ('═' * 65) -ForegroundColor Red
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        $null = Read-Host
        try { 
            Stop-Transcript | Out-Null 
        } 
        catch { }
    }

}
function SetRustDesk {
    <#
    .SYNOPSIS
        Configura ed installa RustDesk con configurazioni personalizzata su Windows.

    .DESCRIPTION
        Script ottimizzato per fermare servizi, reinstallare RustDesk e applicare configurazioni personalizzate.
        Scarica i file di configurazione da repository GitHub e riavvia il sistema per applicare le modifiche.
    #>

    param([int]$CountdownSeconds = 30)

    # Inizializzazione
    $Host.UI.RawUI.WindowTitle = "RustDesk Setup Toolkit By MagnetarMan"

    # Setup logging
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\SetRustDesk_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}

    # Configurazione
    $MsgStyles = @{
        Success  = @{ Color = 'Green'; Icon = '✅' }
        Warning  = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error    = @{ Color = 'Red'; Icon = '❌' }
        Info     = @{ Color = 'Cyan'; Icon = '💡' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }

    # Funzioni Helper
    function Center-Text {
        param(
            [Parameter(Mandatory = $true)][string]$Text,
            [Parameter(Mandatory = $false)][int]$Width = $Host.UI.RawUI.BufferSize.Width
        )
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }
    
    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            'RustDesk Setup Toolkit By MagnetarMan',
            '       Version 2.2.4 (Build 1)'
        )

        foreach ($line in $asciiArt) {
            if ($line -ne '') {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
            else {
                Write-Host ''
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Clear-ConsoleLine {
        $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
        Write-Host $clearLine -NoNewline
        [Console]::Out.Flush()
    }

    function Stop-RustDeskComponents {
        $servicesFound = $false
        foreach ($service in @("RustDesk", "rustdesk")) {
            $serviceObj = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($serviceObj) {
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                $servicesFound = $true
            }
        }
        
        if ($servicesFound) {
            Write-StyledMessage Success "Servizi RustDesk arrestati"
        }

        $processesFound = $false
        foreach ($process in @("rustdesk", "RustDesk")) {
            $runningProcesses = Get-Process -Name $process -ErrorAction SilentlyContinue
            if ($runningProcesses) {
                $runningProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
                $processesFound = $true
            }
        }
        
        if ($processesFound) {
            Write-StyledMessage Success "Processi RustDesk terminati"
        }
        
        if (-not $servicesFound -and -not $processesFound) {
            Write-StyledMessage Warning "Nessun componente RustDesk attivo trovato"
        }
        
        Start-Sleep 2
    }

    function Get-LatestRustDeskRelease {
        try {
            $apiUrl = "https://api.github.com/repos/rustdesk/rustdesk/releases/latest"
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
            $msiAsset = $response.assets | Where-Object { $_.name -like "rustdesk-*-x86_64.msi" } | Select-Object -First 1

            if ($msiAsset) {
                return @{
                    Version     = $response.tag_name
                    DownloadUrl = $msiAsset.browser_download_url
                    FileName    = $msiAsset.name
                }
            }

            Write-StyledMessage Error "Nessun installer .msi trovato nella release"
            return $null
        }
        catch {
            Write-StyledMessage Error "Errore connessione GitHub API: $($_.Exception.Message)"
            return $null
        }
    }

    function Download-RustDeskInstaller {
        param([string]$DownloadPath)

        Write-StyledMessage Progress "Download installer RustDesk in corso..."
        $releaseInfo = Get-LatestRustDeskRelease
        if (-not $releaseInfo) { return $false }

        Write-StyledMessage Info "📥 Versione rilevata: $($releaseInfo.Version)"
        $parentDir = Split-Path $DownloadPath -Parent
        
        try {
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            
            if (Test-Path $DownloadPath) {
                Remove-Item $DownloadPath -Force -ErrorAction Stop
            }

            Invoke-WebRequest -Uri $releaseInfo.DownloadUrl -OutFile $DownloadPath -UseBasicParsing -ErrorAction Stop
            
            if (Test-Path $DownloadPath) {
                Write-StyledMessage Success "Installer $($releaseInfo.FileName) scaricato con successo"
                return $true
            }
        }
        catch {
            Write-StyledMessage Error "Errore download: $($_.Exception.Message)"
        }

        return $false
    }

    function Install-RustDesk {
        param([string]$InstallerPath)

        Write-StyledMessage Progress "Installazione RustDesk"
        
        try {
            $installArgs = "/i", "`"$InstallerPath`"", "/quiet", "/norestart"
            $process = Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
            Start-Sleep 10

            if ($process.ExitCode -eq 0) {
                Write-StyledMessage Success "RustDesk installato"
                return $true
            }
            else {
                Write-StyledMessage Error "Errore installazione (Exit Code: $($process.ExitCode))"
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante installazione: $($_.Exception.Message)"
        }

        return $false
    }

    function Clear-RustDeskConfig {
        Write-StyledMessage Progress "Pulizia configurazioni esistenti..."
        $rustDeskDir = "$env:APPDATA\RustDesk"
        $configDir = "$rustDeskDir\config"

        try {
            if (-not (Test-Path $rustDeskDir)) {
                New-Item -ItemType Directory -Path $rustDeskDir -Force | Out-Null
                Write-StyledMessage Info "Cartella RustDesk creata"
            }

            if (Test-Path $configDir) {
                Remove-Item $configDir -Recurse -Force -ErrorAction Stop
                Write-StyledMessage Success "Cartella config eliminata"
                Start-Sleep 1
            }
            else {
                Write-StyledMessage Warning "Cartella config non trovata"
            }
        }
        catch {
            Write-StyledMessage Error "Errore pulizia config: $($_.Exception.Message)"
        }
    }

    function Download-RustDeskConfigFiles {
        Write-StyledMessage Progress "Download file di configurazione..."
        $configDir = "$env:APPDATA\RustDesk\config"
        
        try {
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            }

            $configFiles = @(
                "RustDesk.toml",
                "RustDesk_local.toml",
                "RustDesk2.toml"
            )

            $baseUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset"
            $downloaded = 0

            foreach ($fileName in $configFiles) {
                $url = "$baseUrl/$fileName"
                $filePath = Join-Path $configDir $fileName
                
                try {
                    Invoke-WebRequest -Uri $url -OutFile $filePath -UseBasicParsing -ErrorAction Stop
                    $downloaded++
                }
                catch {
                    Write-StyledMessage Error "Errore download $fileName`: $($_.Exception.Message)"
                }
            }

            if ($downloaded -eq $configFiles.Count) {
                Write-StyledMessage Success "Tutti i file di configurazione scaricati ($downloaded/$($configFiles.Count))"
            }
            else {
                Write-StyledMessage Warning "Scaricati $downloaded/$($configFiles.Count) file di configurazione"
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante download configurazioni: $($_.Exception.Message)"
        }
    }

    function Start-CountdownRestart([string]$Reason) {
        Write-StyledMessage Info "🔄 $Reason - Il sistema verrà riavviato"
        Write-StyledMessage Info "💡 Premi un tasto qualsiasi per annullare..."

        for ($i = $CountdownSeconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning "⏸️ Riavvio annullato dall'utente"
                return $false
            }

            $percent = [Math]::Round((($CountdownSeconds - $i) / $CountdownSeconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('░' * $remaining)] $percent%"
            
            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            [Console]::Out.Flush()
            Start-Sleep 1
        }

        Clear-ConsoleLine
        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."
        
        try {
            Restart-Computer -Force
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore durante riavvio: $($_.Exception.Message)"
            return $false
        }
    }

    # === ESECUZIONE PRINCIPALE ===
    Show-Header
    Write-StyledMessage Info "🚀 AVVIO CONFIGURAZIONE RUSTDESK"

    try {
        $installerPath = "$env:LOCALAPPDATA\WinToolkit\rustdesk\rustdesk-installer.msi"

        # FASE 1: Stop servizi e processi
        Write-StyledMessage Info "📋 FASE 1: Arresto servizi e processi RustDesk"
        Stop-RustDeskComponents

        # FASE 2: Download e installazione
        Write-StyledMessage Info "📋 FASE 2: Download e installazione"
        if (-not (Download-RustDeskInstaller -DownloadPath $installerPath)) {
            Write-StyledMessage Error "Impossibile procedere senza l'installer"
            return
        }
        
        if (-not (Install-RustDesk -InstallerPath $installerPath)) {
            Write-StyledMessage Error "Errore durante l'installazione"
            return
        }

        # FASE 3: Verifica processi e pulizia
        Write-StyledMessage Info "📋 FASE 3: Verifica processi e pulizia"
        Stop-RustDeskComponents

        # FASE 4: Pulizia configurazioni
        Write-StyledMessage Info "📋 FASE 4: Pulizia configurazioni"
        Clear-RustDeskConfig

        # FASE 5: Download configurazioni
        Write-StyledMessage Info "📋 FASE 5: Download configurazioni"
        Download-RustDeskConfigFiles

        Write-Host ""
        Write-StyledMessage Success "🎉 CONFIGURAZIONE RUSTDESK COMPLETATA"
        Write-StyledMessage Info "🔄 Per applicare le modifiche il PC verrà riavviato"
        Start-CountdownRestart -Reason "Per applicare le modifiche è necessario riavviare il sistema"
    }
    catch {
        Write-StyledMessage Error "ERRORE CRITICO: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Verifica connessione Internet e riprova"
    }
    finally {
        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        Write-StyledMessage Success "🎯 Setup RustDesk terminato"
        try { Stop-Transcript | Out-Null } catch {}
    }

}
function VideoDriverInstall {
    <#
    .SYNOPSIS
        Toolkit per l'installazione e riparazione dei driver grafici.

    .DESCRIPTION
        Questo script PowerShell è progettato per l'installazione e la riparazione dei driver grafici,
        inclusa la pulizia completa con DDU e il download dei driver ufficiali per NVIDIA e AMD.
        Utilizza un'interfaccia utente migliorata con messaggi stilizzati, spinner e
        un conto alla rovescia per il riavvio in modalità provvisoria che può essere interrotto.
    #>

    param([int]$CountdownSeconds = 30)

    $Host.UI.RawUI.WindowTitle = "Driver Install Toolkit By MagnetarMan"
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()

    # Setup logging specifico per VideoDriverInstall
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\VideoDriverInstall_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    # --- NEW: Define Constants and Paths ---
    $GitHubAssetBaseUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/main/asset/"
    $DriverToolsLocalPath = Join-Path $env:LOCALAPPDATA "WinToolkit\Drivers"
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
    # --- END NEW ---

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            ' Video Driver Install Toolkit By MagnetarMan',
            '       Version 2.4.1 (Build 6)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )

        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }

    function Get-GpuManufacturer {
        <#
        .SYNOPSIS
            Identifica il produttore della scheda grafica principale.
        .DESCRIPTION
            Ritorna 'NVIDIA', 'AMD', 'Intel' o 'Unknown' basandosi sui dispositivi Plug and Play.
        #>
        $pnpDevices = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue

        if (-not $pnpDevices) {
            Write-StyledMessage 'Warning' "Nessun dispositivo display Plug and Play rilevato."
            return 'Unknown'
        }

        foreach ($device in $pnpDevices) {
            $manufacturer = $device.Manufacturer
            $friendlyName = $device.FriendlyName

            if ($friendlyName -match 'NVIDIA|GeForce|Quadro|Tesla' -or $manufacturer -match 'NVIDIA') {
                return 'NVIDIA'
            }
            elseif ($friendlyName -match 'AMD|Radeon|ATI' -or $manufacturer -match 'AMD|ATI') {
                return 'AMD'
            }
            elseif ($friendlyName -match 'Intel|Iris|UHD|HD Graphics' -or $manufacturer -match 'Intel') {
                return 'Intel'
            }
        }
        return 'Unknown'
    }

    function Set-BlockWindowsUpdateDrivers {
        <#
        .SYNOPSIS
            Blocca Windows Update dal scaricare automaticamente i driver.
        .DESCRIPTION
            Imposta una chiave di registro per impedire a Windows Update di includere driver negli aggiornamenti di qualità,
            riducendo conflitti con installazioni specifiche del produttore. Richiede privilegi amministrativi.
        #>
        Write-StyledMessage 'Info' "Configurazione per bloccare download driver da Windows Update..."

        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        $propertyName = "ExcludeWUDriversInQualityUpdate"
        $propertyValue = 1

        try {
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            Set-ItemProperty -Path $regPath -Name $propertyName -Value $propertyValue -Type DWord -Force -ErrorAction Stop
            Write-StyledMessage 'Success' "Blocco download driver da Windows Update impostato correttamente nel registro."
            Write-StyledMessage 'Info' "Questa impostazione impedisce a Windows Update di installare driver automaticamente."
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante l'impostazione del blocco download driver da Windows Update: $($_.Exception.Message)"
            Write-StyledMessage 'Warning' "Potrebbe essere necessario eseguire lo script come amministratore."
            return
        }

        Write-StyledMessage 'Info' "Aggiornamento dei criteri di gruppo in corso per applicare le modifiche..."
        try {
            $gpupdateProcess = Start-Process -FilePath "gpupdate.exe" -ArgumentList "/force" -Wait -NoNewWindow -PassThru -ErrorAction Stop
            if ($gpupdateProcess.ExitCode -eq 0) {
                Write-StyledMessage 'Success' "Criteri di gruppo aggiornati con successo."
            }
            else {
                Write-StyledMessage 'Warning' "Aggiornamento dei criteri di gruppo completato con codice di uscita non zero: $($gpupdateProcess.ExitCode)."
            }
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante l'aggiornamento dei criteri di gruppo: $($_.Exception.Message)"
            Write-StyledMessage 'Warning' "Le modifiche ai criteri potrebbero richiedere un riavvio o del tempo per essere applicate."
        }
    }

    function Download-FileWithProgress {
        <#
        .SYNOPSIS
            Scarica un file con indicatore di progresso.
        .DESCRIPTION
            Scarica un file dall'URL specificato con spinner di progresso e gestione retry.
        #>
        param(
            [Parameter(Mandatory = $true)]
            [string]$Url,
            [Parameter(Mandatory = $true)]
            [string]$DestinationPath,
            [Parameter(Mandatory = $true)]
            [string]$Description,
            [int]$MaxRetries = 3
        )

        Write-StyledMessage 'Info' "Scaricando $Description..."

        $destDir = Split-Path -Path $DestinationPath -Parent
        if (-not (Test-Path $destDir)) {
            try {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            catch {
                Write-StyledMessage 'Error' "Impossibile creare la cartella di destinazione '$destDir': $($_.Exception.Message)"
                return $false
            }
        }

        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            try {
                $spinnerIndex = 0
                $webRequest = [System.Net.WebRequest]::Create($Url)
                $webResponse = $webRequest.GetResponse()
                $totalLength = [System.Math]::Floor($webResponse.ContentLength / 1024)
                $responseStream = $webResponse.GetResponseStream()
                $targetStream = [System.IO.FileStream]::new($DestinationPath, [System.IO.FileMode]::Create)
                $buffer = New-Object byte[] 10KB
                $count = $responseStream.Read($buffer, 0, $buffer.Length)
                $downloadedBytes = $count

                while ($count -gt 0) {
                    $targetStream.Write($buffer, 0, $count)
                    $count = $responseStream.Read($buffer, 0, $buffer.Length)
                    $downloadedBytes += $count

                    $spinner = $spinners[$spinnerIndex % $spinners.Length]
                    $percent = [math]::Min(100, [math]::Round(($downloadedBytes / $webResponse.ContentLength) * 100))
                    $barLength = 30
                    $filled = '█' * [math]::Floor($percent * $barLength / 100)
                    $empty = '░' * ($barLength - $filled.Length)
                    $bar = "[$filled$empty] {0,3}%" -f $percent

                    $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                    Write-Host $clearLine -NoNewline
                    Write-Host "$spinner 💾 $Description $bar" -NoNewline -ForegroundColor Cyan

                    $spinnerIndex++
                    Start-Sleep -Milliseconds 100
                }

                $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                Write-Host $clearLine -NoNewline
                [Console]::Out.Flush()

                $targetStream.Flush()
                $targetStream.Close()
                $targetStream.Dispose()
                $responseStream.Dispose()
                $webResponse.Close()

                Write-StyledMessage 'Success' "Download di $Description completato."
                return $true
            }
            catch {
                Write-StyledMessage 'Warning' "Tentativo $attempt fallito per $Description`: $($_.Exception.Message)"
                if ($attempt -lt $MaxRetries) {
                    Start-Sleep -Seconds 2
                }
            }
        }
        Write-StyledMessage 'Error' "Errore durante il download di $Description dopo $MaxRetries tentativi."
        return $false
    }

    function Start-InverseCountdown {
        <#
        .SYNOPSIS
            Avvia un conto alla rovescia con barra di progresso.
        .DESCRIPTION
            Mostra un conto alla rovescia interattivo che può essere interrotto premendo un tasto.
        #>
        param(
            [Parameter(Mandatory = $true)]
            [int]$Seconds,
            [Parameter(Mandatory = $true)]
            [string]$Message
        )

        Write-StyledMessage 'Info' '💡 Premi qualsiasi tasto per annullare il riavvio automatico...'
        Write-Host ''

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage 'Error' '⏸️ Riavvio automatico annullato'
                Write-StyledMessage 'Info' "🔄 Puoi riavviare manualmente con: shutdown /r /t 0"
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('░' * $remaining)] $percent%"

            Write-Host "`r⏰ $Message tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }
        Write-Host "`n"
        Write-StyledMessage 'Warning' '⏰ Tempo scaduto: il sistema verrà riavviato ora.'
        Start-Sleep 1
        return $true
    }

    function Handle-InstallVideoDrivers {
        <#
        .SYNOPSIS
            Gestisce l'installazione dei driver video.
        .DESCRIPTION
            Scarica e avvia l'installer appropriato per la GPU rilevata.
        #>
        Write-StyledMessage 'Info' "Opzione 1: Avvio installazione driver video."

        $gpuManufacturer = Get-GpuManufacturer
        Write-StyledMessage 'Info' "Rilevata GPU: $gpuManufacturer"

        if ($gpuManufacturer -eq 'AMD') {
            $amdInstallerUrl = "${GitHubAssetBaseUrl}AMD-Autodetect.exe"
            $amdInstallerPath = Join-Path $DriverToolsLocalPath "AMD-Autodetect.exe"

            if (Download-FileWithProgress -Url $amdInstallerUrl -DestinationPath $amdInstallerPath -Description "AMD Auto-Detect Tool") {
                Write-StyledMessage 'Info' "Avvio installazione driver video AMD. Premi un tasto per chiudere correttamente il terminale quando l'installazione è completata."
                Start-Process -FilePath $amdInstallerPath -Wait -ErrorAction SilentlyContinue
                Write-StyledMessage 'Success' "Installazione driver video AMD completata o chiusa."
            }
        }
        elseif ($gpuManufacturer -eq 'NVIDIA') {
            $nvidiaInstallerUrl = "${GitHubAssetBaseUrl}NVCleanstall_1.19.0.exe"
            $nvidiaInstallerPath = Join-Path $DriverToolsLocalPath "NVCleanstall_1.19.0.exe"

            if (Download-FileWithProgress -Url $nvidiaInstallerUrl -DestinationPath $nvidiaInstallerPath -Description "NVCleanstall Tool") {
                Write-StyledMessage 'Info' "Avvio installazione driver video NVIDIA Ottimizzato. Premi un tasto per chiudere correttamente il terminale quando l'installazione è completata."
                Start-Process -FilePath $nvidiaInstallerPath -Wait -ErrorAction SilentlyContinue
                Write-StyledMessage 'Success' "Installazione driver video NVIDIA completata o chiusa."
            }
        }
        elseif ($gpuManufacturer -eq 'Intel') {
            Write-StyledMessage 'Info' "Rilevata GPU Intel. Utilizza Windows Update per aggiornare i driver integrati."
        }
        else {
            Write-StyledMessage 'Error' "Produttore GPU non supportato o non rilevato per l'installazione automatica dei driver."
        }
    }

    function Handle-ReinstallRepairVideoDrivers {
        <#
        .SYNOPSIS
            Gestisce la reinstallazione/riparazione dei driver video.
        .DESCRIPTION
            Scarica DDU e gli installer dei driver, configura la modalità provvisoria e riavvia.
        #>
        Write-StyledMessage 'Warning' "Opzione 2: Avvio procedura di reinstallazione/riparazione driver video. Richiesto riavvio."

        # Download DDU
        $dduZipUrl = "${GitHubAssetBaseUrl}DDU.zip"
        $dduZipPath = Join-Path $DriverToolsLocalPath "DDU.zip"

        if (-not (Download-FileWithProgress -Url $dduZipUrl -DestinationPath $dduZipPath -Description "DDU (Display Driver Uninstaller)")) {
            Write-StyledMessage 'Error' "Impossibile scaricare DDU. Annullamento operazione."
            return
        }

        # Extract DDU to Desktop
        Write-StyledMessage 'Info' "Estrazione DDU sul Desktop..."
        try {
            Expand-Archive -Path $dduZipPath -DestinationPath $DesktopPath -Force
            Write-StyledMessage 'Success' "DDU estratto correttamente sul Desktop."
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante l'estrazione di DDU sul Desktop: $($_.Exception.Message)"
            return
        }

        $gpuManufacturer = Get-GpuManufacturer
        Write-StyledMessage 'Info' "Rilevata GPU: $gpuManufacturer"

        if ($gpuManufacturer -eq 'AMD') {
            $amdInstallerUrl = "${GitHubAssetBaseUrl}AMD-Autodetect.exe"
            $amdInstallerPath = Join-Path $DesktopPath "AMD-Autodetect.exe"

            if (-not (Download-FileWithProgress -Url $amdInstallerUrl -DestinationPath $amdInstallerPath -Description "AMD Auto-Detect Tool")) {
                Write-StyledMessage 'Error' "Impossibile scaricare l'installer AMD. Annullamento operazione."
                return
            }
        }
        elseif ($gpuManufacturer -eq 'NVIDIA') {
            $nvidiaInstallerUrl = "${GitHubAssetBaseUrl}NVCleanstall_1.19.0.exe"
            $nvidiaInstallerPath = Join-Path $DesktopPath "NVCleanstall_1.19.0.exe"

            if (-not (Download-FileWithProgress -Url $nvidiaInstallerUrl -DestinationPath $nvidiaInstallerPath -Description "NVCleanstall Tool")) {
                Write-StyledMessage 'Error' "Impossibile scaricare l'installer NVIDIA. Annullamento operazione."
                return
            }
        }
        elseif ($gpuManufacturer -eq 'Intel') {
            Write-StyledMessage 'Info' "Rilevata GPU Intel. Scarica manualmente i driver da Intel se necessario."
        }
        else {
            Write-StyledMessage 'Warning' "Produttore GPU non supportato o non rilevato. Verrà posizionato solo DDU sul desktop."
        }

        Write-StyledMessage 'Info' "DDU e l'installer dei Driver (se rilevato) sono stati posizionati sul desktop."

        # Creazione file batch per tornare alla modalità normale
        $batchFilePath = Join-Path $DesktopPath "Switch to Normal Mode.bat"
        try {
            Set-Content -Path $batchFilePath -Value 'bcdedit /deletevalue {current} safeboot' -Encoding ASCII
            Write-StyledMessage 'Info' "File batch 'Switch to Normal Mode.bat' creato sul desktop per disabilitare la Modalità Provvisoria."
        }
        catch {
            Write-StyledMessage 'Warning' "Impossibile creare il file batch: $($_.Exception.Message)"
        }

        Write-StyledMessage 'Error' "ATTENZIONE: Il sistema sta per riavviarsi in modalità provvisoria."

        Write-StyledMessage 'Info' "Configurazione del sistema per l'avvio automatico in Modalità Provvisoria..."
        try {
            Start-Process -FilePath "bcdedit.exe" -ArgumentList "/set {current} safeboot minimal" -Wait -NoNewWindow -ErrorAction Stop
            Write-StyledMessage 'Success' "Modalità Provvisoria configurata per il prossimo avvio."
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante la configurazione della Modalità Provvisoria tramite bcdedit: $($_.Exception.Message)"
            Write-StyledMessage 'Warning' "Il riavvio potrebbe non avvenire in Modalità Provvisoria. Procedere manualmente."
            return
        }

        $shouldReboot = Start-InverseCountdown -Seconds 30 -Message "Riavvio in modalità provvisoria in corso..."

        if ($shouldReboot) {
            try {
                shutdown /r /t 0
                Write-StyledMessage 'Success' "Comando di riavvio inviato."
            }
            catch {
                Write-StyledMessage 'Error' "Errore durante l'esecuzione del comando di riavvio: $($_.Exception.Message)"
            }
        }
    }

    Show-Header

    Write-StyledMessage 'Info' '🔧 Inizializzazione dello Script di Installazione Driver Video...'
    Start-Sleep -Seconds 2

    Set-BlockWindowsUpdateDrivers

    # Main Menu Logic
    $choice = ""
    do {
        Write-Host ""
        Write-StyledMessage 'Info' 'Seleziona un''opzione:'
        Write-Host "  1) Installa Driver Video"
        Write-Host "  2) Reinstalla/Ripara Driver Video"
        Write-Host "  0) Torna al menu principale"
        Write-Host ""
        $choice = Read-Host "La tua scelta"
        Write-Host ""

        switch ($choice.ToUpper()) {
            "1" { Handle-InstallVideoDrivers }
            "2" { Handle-ReinstallRepairVideoDrivers }
            "0" { Write-StyledMessage 'Info' 'Tornando al menu principale.' }
            default { Write-StyledMessage 'Warning' "Scelta non valida. Riprova." }
        }

        if ($choice.ToUpper() -ne "0") {
            Write-Host "Premi un tasto per continuare..."
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            Clear-Host
            Show-Header
        }

    } while ($choice.ToUpper() -ne "0")
}
function GamingToolkit {
    <#
    .SYNOPSIS
        Gaming Toolkit - Strumenti di ottimizzazione per il gaming su Windows.
    .DESCRIPTION
        Script completo per ottimizzare le prestazioni del sistema per il gaming
    #>

    param([int]$CountdownSeconds = 30)

    # Configurazione globale
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }
    $script:Log = @()

    # Funzioni helper unificate
    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
        if ($Type -in @('Info', 'Warning', 'Error', 'Success')) {
            $script:Log += "[$(Get-Date -Format 'HH:mm:ss')] [$Type] $Text"
        }
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '░' * (30 - $filled.Length)
        Write-Host "`r$Spinner $Icon $Activity [$filled$empty] $safePercent% $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Clear-ProgressLine {
        Write-Host "`r$(' ' * 120)`r" -NoNewline
    }

    function Test-WingetPackageAvailable([string]$PackageId) {
        try {
            $result = winget search $PackageId 2>&1
            return $LASTEXITCODE -eq 0 -and $result -match $PackageId
        }
        catch { return $false }
    }

    function Invoke-WingetInstallWithProgress([string]$PackageId, [string]$DisplayName, [int]$Step, [int]$Total) {
        Write-StyledMessage 'Info' "[$Step/$Total] 📦 Installazione: $DisplayName..."
        
        if (-not (Test-WingetPackageAvailable $PackageId)) {
            Write-StyledMessage 'Warning' "Pacchetto $DisplayName non disponibile. Saltando."
            return @{ Success = $true; Skipped = $true }
        }

        try {
            $proc = Start-Process -FilePath 'winget' -ArgumentList @('install', '--id', $PackageId, '--silent', '--accept-package-agreements', '--accept-source-agreements') -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\winget_$PackageId.log" -RedirectStandardError "$env:TEMP\winget_err_$PackageId.log"
            
            $spinnerIndex = 0
            $percent = 0
            $startTime = Get-Date
            $timeout = 600

            while (-not $proc.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
                if ($percent -lt 95) { $percent += Get-Random -Minimum 1 -Maximum 2 }
                Show-ProgressBar $DisplayName "($elapsed s)" $percent '📦' $spinner
                Start-Sleep -Milliseconds 700
                $proc.Refresh()
            }

            Clear-ProgressLine

            if (-not $proc.HasExited) {
                Write-StyledMessage 'Warning' "Timeout per $DisplayName. Terminato."
                $proc.Kill()
                return @{ Success = $false; TimedOut = $true }
            }

            $exitCode = $proc.ExitCode
            $successCodes = @(0, 1638, 3010, -1978335189)
            
            if ($exitCode -in $successCodes) {
                Write-StyledMessage 'Success' "Installato: $DisplayName"
                return @{ Success = $true; ExitCode = $exitCode }
            }
            else {
                Write-StyledMessage 'Error' "Errore installazione $DisplayName (codice: $exitCode)"
                return @{ Success = $false; ExitCode = $exitCode }
            }
        }
        catch {
            Clear-ProgressLine
            Write-StyledMessage 'Error' "Eccezione $DisplayName`: $($_.Exception.Message)"
            return @{ Success = $false }
        }
        finally {
            Remove-Item "$env:TEMP\winget_$PackageId.log", "$env:TEMP\winget_err_$PackageId.log" -ErrorAction SilentlyContinue
        }
    }

    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi un tasto per annullare...'
        Write-Host ''

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning '⏸️ Riavvio annullato'
                Write-StyledMessage Info "Riavvia manualmente: 'shutdown /r /t 0'"
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $bar = "[$('█' * $filled)$('░' * (20 - $filled))] $percent%"
            Write-Host "`r⏰ Riavvio tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning 'Riavvio sistema...'
        return $true
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        
        @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '    Gaming Toolkit By MagnetarMan',
            '       Version 2.4.2 (Build 2)'
        ) | ForEach-Object {
            if ($_) {
                $padding = [Math]::Max(0, [Math]::Floor(($width - $_.Length) / 2))
                Write-Host (' ' * $padding + $_) -ForegroundColor White
            }
        }
        
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    # Verifica OS e Winget
    $osInfo = Get-ComputerInfo
    $buildNumber = $osInfo.OsBuildNumber
    $isWindows11Pre23H2 = ($buildNumber -ge 22000) -and ($buildNumber -lt 22631)

    if ($isWindows11Pre23H2) {
        Write-StyledMessage 'Warning' "Versione obsoleta rilevata. Winget potrebbe non funzionare."
        $response = Read-Host "Eseguire riparazione Winget? (Y/N)"
        if ($response -match '^[Yy]$') { WinReinstallStore }
    }

    $Host.UI.RawUI.WindowTitle = "Gaming Toolkit By MagnetarMan"

    # Setup logging
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    if (-not (Test-Path $logdir)) { New-Item -Path $logdir -ItemType Directory -Force | Out-Null }
    try {
        Start-Transcript -Path "$logdir\GamingToolkit_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log" -Append | Out-Null
    }
    catch {}

    # Countdown preparazione
    for ($i = 5; $i -gt 0; $i--) {
        Write-Host "`r$($spinners[$i % $spinners.Length]) ⏳ Preparazione - $i s..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    Show-Header

    # Step 1: Verifica Winget
    Write-StyledMessage 'Info' '🔍 Verifica Winget...'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage 'Error' 'Winget non disponibile.'
        Write-StyledMessage 'Info' 'Esegui reset Store/Winget e riprova.'
        Write-Host "`nPremi un tasto..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return
    }
    Write-StyledMessage 'Success' 'Winget funzionante.'

    Write-StyledMessage 'Info' '🔄 Aggiornamento sorgenti Winget...'
    try {
        winget source update | Out-Null
        Write-StyledMessage 'Success' 'Sorgenti aggiornate.'
    }
    catch {
        Write-StyledMessage 'Warning' "Errore aggiornamento sorgenti: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 2: NetFramework
    Write-StyledMessage 'Info' '🔧 Abilitazione NetFramework...'
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs, NetFx3 -NoRestart -All -ErrorAction Stop | Out-Null
        Write-StyledMessage 'Success' 'NetFramework abilitato.'
    }
    catch {
        Write-StyledMessage 'Error' "Errore NetFramework: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 3: Runtime e VCRedist
    $runtimes = @(
        "Microsoft.DotNet.DesktopRuntime.3_1", "Microsoft.DotNet.DesktopRuntime.5",
        "Microsoft.DotNet.DesktopRuntime.6", "Microsoft.DotNet.DesktopRuntime.7",
        "Microsoft.DotNet.DesktopRuntime.8", "Microsoft.DotNet.DesktopRuntime.9", "Microsoft.DotNet.DesktopRuntime.10",
        "Microsoft.VCRedist.2010.x64", "Microsoft.VCRedist.2010.x86",
        "Microsoft.VCRedist.2012.x64", "Microsoft.VCRedist.2012.x86",
        "Microsoft.VCRedist.2013.x64", "Microsoft.VCRedist.2013.x86",
        "Microsoft.VCLibs.Desktop.14", "Microsoft.VCRedist.2015+.x64", "Microsoft.VCRedist.2015+.x86"
    )

    Write-StyledMessage 'Info' '🔥 Installazione runtime .NET e VCRedist...'
    for ($i = 0; $i -lt $runtimes.Count; $i++) {
        Invoke-WingetInstallWithProgress $runtimes[$i] $runtimes[$i] ($i + 1) $runtimes.Count | Out-Null
        Write-Host ''
    }
    Write-StyledMessage 'Success' 'Runtime completati.'
    Write-Host ''

    # Step 4: DirectX
    Write-StyledMessage 'Info' '🎮 Installazione DirectX...'
    $dxDir = "$env:LOCALAPPDATA\WinToolkit\Directx"
    $dxPath = "$dxDir\dxwebsetup.exe"
    
    if (-not (Test-Path $dxDir)) { New-Item -Path $dxDir -ItemType Directory -Force | Out-Null }

    try {
        Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/main/asset/dxwebsetup.exe' -OutFile $dxPath -ErrorAction Stop
        Write-StyledMessage 'Success' 'DirectX scaricato.'

        $proc = Start-Process -FilePath $dxPath -PassThru -Verb RunAs -ErrorAction Stop
        $spinnerIndex = 0
        $percent = 0
        $startTime = Get-Date

        while (-not $proc.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt 600) {
            $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
            $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
            if ($percent -lt 95) { $percent += Get-Random -Minimum 1 -Maximum 2 }
            Show-ProgressBar "DirectX" "($elapsed s)" $percent '🎮' $spinner 'Yellow'
            Start-Sleep -Milliseconds 700
            $proc.Refresh()
        }

        Clear-ProgressLine

        if (-not $proc.HasExited) {
            Write-StyledMessage 'Warning' "Timeout DirectX."
            $proc.Kill()
        }
        else {
            $exitCode = $proc.ExitCode
            $successCodes = @(0, 3010, 5100, -9, 9, -1442840576)
            if ($exitCode -in $successCodes) {
                Write-StyledMessage 'Success' "DirectX installato (codice: $exitCode)."
            }
            else {
                Write-StyledMessage 'Error' "DirectX errore: $exitCode"
            }
        }
    }
    catch {
        Clear-ProgressLine
        Write-StyledMessage 'Error' "Errore DirectX: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 5: Client di gioco
    $gameClients = @(
        "Amazon.Games", "GOG.Galaxy", "EpicGames.EpicGamesLauncher",
        "ElectronicArts.EADesktop", "Playnite.Playnite", "Valve.Steam",
        "Ubisoft.Connect", "9MV0B5HZVK9Z"
    )

    Write-StyledMessage 'Info' '🎮 Installazione client di gioco...'
    for ($i = 0; $i -lt $gameClients.Count; $i++) {
        Invoke-WingetInstallWithProgress $gameClients[$i] $gameClients[$i] ($i + 1) $gameClients.Count | Out-Null
        Write-Host ''
    }
    Write-StyledMessage 'Success' 'Client installati.'
    Write-Host ''

    # Step 6: Battle.net
    Write-StyledMessage 'Info' '🎮 Installazione Battle.net...'
    $bnPath = "$env:TEMP\Battle.net-Setup.exe"
    
    try {
        Invoke-WebRequest -Uri 'https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live' -OutFile $bnPath -ErrorAction Stop
        Write-StyledMessage 'Success' 'Battle.net scaricato.'

        $proc = Start-Process -FilePath $bnPath -PassThru -Verb RunAs -ErrorAction Stop
        $spinnerIndex = 0
        $startTime = Get-Date

        while (-not $proc.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt 900) {
            $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
            $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
            Write-Host "`r$spinner 🎮 Battle.net ($elapsed s)" -NoNewline -ForegroundColor Cyan
            Start-Sleep -Milliseconds 500
            $proc.Refresh()
        }

        Clear-ProgressLine

        if (-not $proc.HasExited) {
            Write-StyledMessage 'Warning' "Timeout Battle.net."
            try { $proc.Kill() } catch {}
        }
        else {
            $exitCode = $proc.ExitCode
            if ($exitCode -in @(0, 3010)) {
                Write-StyledMessage 'Success' "Battle.net installato."
            }
            else {
                Write-StyledMessage 'Warning' "Battle.net: codice $exitCode"
            }
        }

        Write-Host "`nPremi un tasto..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    catch {
        Clear-ProgressLine
        Write-StyledMessage 'Error' "Errore Battle.net: $($_.Exception.Message)"
        Write-Host "`nPremi un tasto..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    Write-Host ''

    # Step 7: Pulizia avvio automatico
    Write-StyledMessage 'Info' '🧹 Pulizia avvio automatico...'
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    @('Steam', 'Battle.net', 'GOG Galaxy', 'GogGalaxy', 'GalaxyClient') | ForEach-Object {
        if (Get-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue
            Write-StyledMessage 'Success' "Rimosso: $_"
        }
    }

    $startupPath = [Environment]::GetFolderPath('Startup')
    @('Steam.lnk', 'Battle.net.lnk', 'GOG Galaxy.lnk') | ForEach-Object {
        $path = Join-Path $startupPath $_
        if (Test-Path $path) {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
            Write-StyledMessage 'Success' "Rimosso: $_"
        }
    }
    Write-StyledMessage 'Success' 'Pulizia completata.'
    Write-Host ''

    # Step 8: Profilo energetico
    Write-StyledMessage 'Info' '⚡ Configurazione profilo energetico...'
    $ultimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $planName = "WinToolkit Gaming Performance"
    $guid = $null

    $existingPlan = powercfg -list | Select-String -Pattern $planName -ErrorAction SilentlyContinue
    if ($existingPlan) {
        $guid = ($existingPlan.Line -split '\s+')[3]
        Write-StyledMessage 'Info' "Piano esistente trovato."
    }
    else {
        try {
            $output = powercfg /duplicatescheme $ultimateGUID | Out-String
            if ($output -match "\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b") {
                $guid = $matches[0]
                powercfg /changename $guid $planName "Ottimizzato per Gaming dal WinToolkit" | Out-Null
                Write-StyledMessage 'Success' "Piano creato."
            }
            else {
                Write-StyledMessage 'Error' "Errore creazione piano."
            }
        }
        catch {
            Write-StyledMessage 'Error' "Errore duplicazione piano: $($_.Exception.Message)"
        }
    }

    if ($guid) {
        try {
            powercfg -setactive $guid | Out-Null
            Write-StyledMessage 'Success' "Piano attivato."
        }
        catch {
            Write-StyledMessage 'Error' "Errore attivazione piano: $($_.Exception.Message)"
        }
    }
    else {
        Write-StyledMessage 'Error' "Impossibile attivare piano."
    }
    Write-Host ''

    # Step 9: Focus Assist
    Write-StyledMessage 'Info' '🔕 Attivazione Non disturbare...'
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0 -Force
        Write-StyledMessage 'Success' 'Non disturbare attivo.'
    }
    catch {
        Write-StyledMessage 'Error' "Errore: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 10: Completamento
    Write-Host ('═' * 80) -ForegroundColor Green
    Write-StyledMessage 'Success' 'Gaming Toolkit completato!'
    Write-StyledMessage 'Success' 'Sistema ottimizzato per il gaming.'
    Write-Host ('═' * 80) -ForegroundColor Green
    Write-Host ''

    # Step 11: Riavvio
    Write-Host "Riavvio necessario. Automatico tra $CountdownSeconds secondi..." -ForegroundColor Red
    
    if (Start-InterruptibleCountdown $CountdownSeconds "Riavvio") {
        Write-StyledMessage 'Info' '🔄 Riavvio...'
        Restart-Computer -Force
    }
    else {
        Write-StyledMessage 'Warning' 'Riavvia manualmente per applicare tutte le modifiche.'
        Write-Host "`nPremi un tasto..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }

}
function DisableBitlocker {
    <#
    .SYNOPSIS
        Disattiva BitLocker sul drive C:

    .DESCRIPTION
        Questo script disattiva la crittografia BitLocker per il drive di sistema (C:).
        Può essere eseguito in modalità standalone o come parte di un toolkit più ampio.
    #>

    param([bool]$RunStandalone = $true)

    $Host.UI.RawUI.WindowTitle = "BitLocker Toolkit By MagnetarMan"
    $script:Log = @()

    # Setup logging
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logDir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logDir\BitLockerToolkit_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}

    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    function Write-StyledMessage {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('Success', 'Warning', 'Error', 'Info')]
            [string]$Type,
            
            [Parameter(Mandatory = $true)]
            [string]$Text
        )

        $style = $MsgStyles[$Type]
        $timestamp = Get-Date -Format "HH:mm:ss"
        
        # Rimuovi emoji duplicati dal testo per il log
        $cleanText = $Text -replace '^[✅⚠️❌💎🔍🚀⚙️🧹📦📋📜📝💾⬇️🔧⚡🖼️🌐🍪🔄🗂️📁🖨️📄🗑️💭⏸️▶️💡⏰🎉💻📊]\s*', ''

        Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color

        # Log automatico
        if ($Type -in @('Info', 'Warning', 'Error', 'Success')) {
            $logEntry = "[$timestamp] [$Type] $cleanText"
            $script:Log += $logEntry
        }
    }

    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )
    
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    
        return (' ' * $padding + $Text)
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ '
            '      \ \      / / | || \ | |'
            '       \ \ /\ / /  | ||  \| |'
            '        \ V  V /   | || |\  |'
            '         \_/\_/    |_||_| \_|'
            '',
            '    BitLocker Toolkit By MagnetarMan',
            '       Version 2.4.2 (Build 6)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    Show-Header

    for ($i = 5; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    try {
        Write-StyledMessage Info "🔑 Avvio processo di disattivazione BitLocker per il drive C:..."

        $commandOutput = & manage-bde.exe -off C: 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            if ($commandOutput -match "Decryption in progress") {
                Write-StyledMessage Success "Disattivazione BitLocker avviata con successo."
            }
            elseif ($commandOutput -match "Volume C: is not BitLocker protected") {
                Write-StyledMessage Info "BitLocker è già disattivato sul drive C:."
            }
            else {
                Write-StyledMessage Success "Comando manage-bde completato."
            }

            Write-StyledMessage Info "📋 Output completo di manage-bde:"
            foreach ($line in $commandOutput) {
                Write-Host "   $line" -ForegroundColor DarkGray
            }
        }
        else {
            Write-StyledMessage Error "Errore nell'esecuzione di manage-bde (Exit code: $exitCode)"
            Write-StyledMessage Info "📋 Output di errore:"
            foreach ($line in $commandOutput) {
                Write-Host "   $line" -ForegroundColor Red
            }
        }

        Write-StyledMessage Info "🎉 Operazione di disattivazione BitLocker completata."

        # Impedisce a Windows di avviare la crittografia automatica del dispositivo.
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
        if (-not (Test-Path -Path $regPath)) {
            New-Item -Path $regPath -ItemType Directory -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name "PreventDeviceEncryption" -Type DWord -Value 1 -Force

        Write-StyledMessage Info "Impostazione del Registro di sistema per prevenire la crittografia automatica del dispositivo completata."

    }
    catch {
        Write-StyledMessage Error "Errore imprevisto: $($_.Exception.Message)"
    }
    finally {
        if ($RunStandalone) {
            Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
            Read-Host
        }
        try { Stop-Transcript | Out-Null } catch {}
    }

}
# function SearchRepair {}


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
            [pscustomobject]@{ Name = 'DisableBitlocker'; Description = 'Disabilita Bitlocker'; Action = 'RunFunction' }
        )
    },
    @{
        'Name' = 'Driver & Gaming'; 'Icon' = '🎮'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'VideoDriverInstall'; Description = 'Toolkit Driver Grafici'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'GamingToolkit'; Description = 'Gaming Toolkit'; Action = 'RunFunction' }
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
