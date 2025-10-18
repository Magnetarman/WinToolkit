<#
.SYNOPSIS
    WinToolkit - Strumenti di manutenzione Windows
.DESCRIPTION
    Menu principale per strumenti di gestione e riparazione Windows
.NOTES
  Versione 2.3.0 (Build 2) - 2025-10-18
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
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        $timestamp = Get-Date -Format "HH:mm:ss"
        $cleanText = $Text -replace '^(✅|⚠️|❌|💎|🔥|🚀|⚙️|🧹|📦|📋|📜|🔒|💾|⬇️|🔧|⚡|🖼️|🌐|🪟|🔄|🗂️|📁|🖨️|📄|🗑️|💭|⏸️|▶️|💡|⏰|🎉|💻|📊|🛡️|🔧|🔑|📦|🧹|💎|⚙️|🚀)\s*', ''
        Write-Host "[$timestamp] $($style.Icon) $cleanText" -ForegroundColor $style.Color
        if ($Type -in @('Info', 'Warning', 'Error')) { $script:Log += "[$timestamp] [$Type] $cleanText" }
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
            $pathExists = ($currentPath -split ';') | Where-Object { $_.TrimEnd('\') -eq $PathToAdd.TrimEnd('\') }
            
            if ($pathExists) {
                Write-StyledMessage 'Info' "Percorso già nel PATH: $PathToAdd"
                return $true
            }

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
                $testPath = if ($resolved.FullName -notmatch '\*') { $resolved.FullName } else { $resolved.FullName }
                if (Test-Path "$testPath\$ExecutableName") { return $testPath }
            }

            $directPath = $path -replace '\*.*$', ''
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

    function Center-Text([string]$Text, [int]$Width = $Host.UI.RawUI.BufferSize.Width) {
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
            '   InstallPSProfile By MagnetarMan',
            '      Version 2.2.4 (Build 1)'
        )

        foreach ($line in $asciiArt) {
            if ($line) { Write-Host (Center-Text $line $width) -ForegroundColor White }
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
        Invoke-RestMethod $profileUrl -OutFile $tempProfile -UseBasicParsing
        $newHash = Get-FileHash $tempProfile

        $profileDir = Split-Path $PROFILE -Parent
        if (!(Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
        if (!(Test-Path "$PROFILE.hash")) { $newHash.Hash | Out-File "$PROFILE.hash" }
        
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
                
                $installProcess = Start-Process -FilePath "winget" -ArgumentList "install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements --silent" -NoNewWindow -PassThru

                while (-not $installProcess.HasExited -and $percent -lt 90) {
                    Show-ProgressBar "oh-my-posh" "Installazione..." $percent '📦' $spinners[$spinnerIndex++ % $spinners.Length]
                    $percent += 2
                    Start-Sleep -Milliseconds 300
                }

                $installProcess.WaitForExit()
                Start-Sleep -Seconds 2
                Show-ProgressBar "oh-my-posh" "Completato" 100 '📦'
                Write-Host ''

                $ohMyPoshPaths = @(
                    "$env:LOCALAPPDATA\Programs\oh-my-posh\bin",
                    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\JanDeDobbeleer.OhMyPosh_Microsoft.Winget.Source_*",
                    "$env:ProgramFiles\oh-my-posh\bin"
                )

                $foundPath = Find-ProgramPath "oh-my-posh" $ohMyPoshPaths "oh-my-posh.exe"

                if ($foundPath) {
                    Add-ToSystemPath $foundPath | Out-Null
                    Write-StyledMessage 'Success' "oh-my-posh configurato: $foundPath"
                }
                else {
                    $searchResult = Get-ChildItem -Path "$env:LOCALAPPDATA" -Filter "oh-my-posh.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($searchResult) {
                        $foundPath = Split-Path $searchResult.FullName -Parent
                        Add-ToSystemPath $foundPath | Out-Null
                        Write-StyledMessage 'Success' "oh-my-posh trovato: $foundPath"
                    }
                    else {
                        Write-StyledMessage 'Warning' "oh-my-posh installato, PATH disponibile dopo riavvio"
                    }
                }
            }
            catch {
                Write-StyledMessage 'Warning' "Errore oh-my-posh: $($_.Exception.Message)"
            }

            # zoxide
            try {
                Write-StyledMessage 'Info' "Installazione zoxide..."
                $spinnerIndex = 0; $percent = 0
                
                $installProcess = Start-Process -FilePath "winget" -ArgumentList "install ajeetdsouza.zoxide -s winget --accept-package-agreements --accept-source-agreements --silent" -NoNewWindow -PassThru

                while (-not $installProcess.HasExited -and $percent -lt 90) {
                    Show-ProgressBar "zoxide" "Installazione..." $percent '⚡' $spinners[$spinnerIndex++ % $spinners.Length]
                    $percent += 2
                    Start-Sleep -Milliseconds 300
                }

                $installProcess.WaitForExit()
                Start-Sleep -Seconds 2
                Show-ProgressBar "zoxide" "Completato" 100 '⚡'
                Write-Host ''

                $zoxidePaths = @(
                    "$env:LOCALAPPDATA\Programs\zoxide",
                    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\ajeetdsouza.zoxide_Microsoft.Winget.Source_*",
                    "$env:ProgramFiles\zoxide"
                )

                $foundPath = Find-ProgramPath "zoxide" $zoxidePaths "zoxide.exe"

                if ($foundPath) {
                    Add-ToSystemPath $foundPath | Out-Null
                    Write-StyledMessage 'Success' "zoxide configurato: $foundPath"
                }
                else {
                    $searchResult = Get-ChildItem -Path "$env:LOCALAPPDATA" -Filter "zoxide.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($searchResult) {
                        $foundPath = Split-Path $searchResult.FullName -Parent
                        Add-ToSystemPath $foundPath | Out-Null
                        Write-StyledMessage 'Success' "zoxide trovato: $foundPath"
                    }
                    else {
                        Write-StyledMessage 'Warning' "zoxide installato, PATH disponibile dopo riavvio"
                    }
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
        if (Test-Path "$env:TEMP\Microsoft.PowerShell_profile.ps1") {
            Remove-Item "$env:TEMP\Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
        }
    }
    finally {
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

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
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
                $script:Log += "[$($Config.Name)] ℹ️ Controllo disco schedulato al prossimo riavvio"
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

            $logStatus = if ($success) { '✅ Successo' } else { "⚠️ $($errors.Count) errori" }
            if ($warnings.Count -gt 0) { $logStatus += " - $($warnings.Count) avvisi" }
            $script:Log += "[$($Config.Name)] $logStatus"

            return @{ Success = $success; ErrorCount = $errors.Count }

        }
        catch {
            Write-StyledMessage Error "Errore durante $($Config.Name): $_"
            $script:Log += "[$($Config.Name)] ❌ Errore fatale: $_"
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
        $script:Log += "[Controllo disco Esteso] ℹ️ Segno volume dirty e apro cmd"

        try {
            Start-Process 'fsutil.exe' @('dirty', 'set', 'C:') -NoNewWindow -Wait
            Start-Process 'cmd.exe' @('/c', 'echo Y | chkdsk C: /f /r /v /x /b') -WindowStyle Hidden -Wait
            Write-StyledMessage Info 'Comando chkdsk inviato (finestra nascosta). Riavvia il sistema per eseguire la scansione profonda.'
            $script:Log += "[Controllo disco Esteso] ✅ chkdsk eseguito in background; riavviare per applicare"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore eseguendo operazione: $_"
            $script:Log += "[Controllo disco Esteso] ❌ Errore: $_"
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
            '       Version 2.2.4 (Build 1)'
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

    # Setup logging specifico per WinUpdateReset
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\WinUpdateReset_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
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

    function Center-Text([string]$text, [int]$width) {
        $padding = [math]::Max(0, [math]::Floor(($width - $text.Length) / 2))
        return (' ' * $padding) + $text
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
            # Soppressione completa dell'output con redirezione a $null
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            
            # Eliminazione con output completamente soppresso
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue *>$null
            
            # Reset completo del cursore alla posizione originale
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline
            [Console]::Out.Flush()
            
            Write-StyledMessage Success "🗑️ Directory $displayName eliminata."
            return $true
        }
        catch {
            # Reset cursore in caso di errore
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline
            
            Write-StyledMessage Warning "Tentativo fallito, provo con eliminazione forzata..."
        
            try {
                # Metodo alternativo con robocopy per eliminazione forzata
                $tempDir = [System.IO.Path]::GetTempPath() + "empty_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                $null = New-Item -ItemType Directory -Path $tempDir -Force
                
                # Usa robocopy per svuotare e poi elimina
                $null = Start-Process "robocopy.exe" -ArgumentList "`"$tempDir`" `"$path`" /MIR /NFL /NDL /NJH /NJS /NP /NC" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                Remove-Item $tempDir -Force -ErrorAction SilentlyContinue
                Remove-Item $path -Force -ErrorAction SilentlyContinue
                
                # Reset cursore finale
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
                # Reset delle preferenze
                $ErrorActionPreference = 'Continue'
                $ProgressPreference = 'Continue'
                $VerbosePreference = 'SilentlyContinue'
            }
        }
    }
 
    # Funzione ausiliaria per centrare il testo.
    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$text,
            [Parameter(Mandatory = $false)]
            [int]$width = $Host.UI.RawUI.BufferSize.Width
        )

        $padding = [Math]::Max(0, [Math]::Floor(($width - $text.Length) / 2))

        return (' ' * $padding + $text)
    }

    #---

    # Main script
    Clear-Host
 
    # Get the actual console width for dynamic centering.
    $width = $Host.UI.RawUI.BufferSize.Width
 
    # Draw the top border line, adjusting for dynamic width.
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
 
    $asciiArt = @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        ' Update Reset Toolkit By MagnetarMan',
        '       Version 2.2.4 (Build 1)'
    )
 
    foreach ($line in $asciiArt) {
        # Call the Center-Text function, passing the dynamic width.
        if (-not [string]::IsNullOrEmpty($line)) {
            Write-Host (Center-Text -text $line -width $width) -ForegroundColor White
        }
    }
 
    # Draw the bottom border line.
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    Write-Host ''

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

function Invoke-WPFUpdatesEnable {
    <#

    .SYNOPSIS
        Re-enables Windows Update after it has been disabled

    .DESCRIPTION
        This function reverses the changes made by Invoke-WPFUpdatesdisable, restoring
        Windows Update functionality by resetting registry settings to defaults,
        configuring services with correct startup types, restoring renamed DLLs,
        and enabling scheduled tasks.

    .NOTES
        This function requires administrator privileges and will attempt to run as SYSTEM for certain operations.
        A system restart may be required for all changes to take full effect.

    #>

    $Host.UI.RawUI.WindowTitle = "Update Enable Toolkit By MagnetarMan"

    Write-StyledMessage Info '🔧 Inizializzazione ripristino Windows Update...'

    # Restore Windows Update registry settings to defaults
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

    # Reset WaaSMedicSvc registry settings to defaults
    Write-StyledMessage Info '🔧 Ripristino impostazioni WaaSMedicSvc...'

    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Type DWord -Value 3 -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "FailureActions" -ErrorAction SilentlyContinue
        Write-StyledMessage Success "⚙️ Impostazioni WaaSMedicSvc ripristinate."
    }
    catch {
        Write-StyledMessage Warning "Avviso: Impossibile ripristinare WaaSMedicSvc - $($_.Exception.Message)"
    }

    # Restore update services to their default state
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

                # Reset failure actions to default using sc command
                Start-Process -FilePath "sc.exe" -ArgumentList "failure `"$($service.Name)`" reset= 86400 actions= restart/60000/restart/60000/restart/60000" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

                # Start the service if it should be running
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

    # Restore renamed DLLs if they exist
    Write-StyledMessage Info '📁 Ripristino DLL rinominate...'

    $dlls = @("WaaSMedicSvc", "wuaueng")

    foreach ($dll in $dlls) {
        $dllPath = "C:\Windows\System32\$dll.dll"
        $backupPath = "C:\Windows\System32\${dll}_BAK.dll"

        if ((Test-Path $backupPath) -and !(Test-Path $dllPath)) {
            try {
                # Take ownership of backup file
                Start-Process -FilePath "takeown.exe" -ArgumentList "/f `"$backupPath`"" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

                # Grant full control to everyone
                Start-Process -FilePath "icacls.exe" -ArgumentList "`"$backupPath`" /grant *S-1-1-0:F" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

                # Rename back to original
                Rename-Item -Path $backupPath -NewName "$dll.dll" -ErrorAction SilentlyContinue
                Write-StyledMessage Success "Ripristinato ${dll}_BAK.dll a $dll.dll"

                # Restore ownership to TrustedInstaller
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

    # Enable update related scheduled tasks
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

    # Enable driver offering through Windows Update
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

    # Enable Windows Update automatic restart
    Write-StyledMessage Info '🔄 Abilitazione riavvio automatico Windows Update...'

    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -ErrorAction SilentlyContinue
        Write-StyledMessage Success "🔄 Riavvio automatico Windows Update abilitato."
    }
    catch {
        Write-StyledMessage Warning "Avviso: Impossibile abilitare riavvio automatico - $($_.Exception.Message)"
    }

    # Reset Windows Update settings to default
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

    # Reset Windows Local Policies to Default
    Write-StyledMessage Info '📋 Ripristino criteri locali Windows...'

    try {
        Start-Process -FilePath "secedit" -ArgumentList "/configure /cfg $env:windir\inf\defltbase.inf /db defltbase.sdb /verbose" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c RD /S /Q $env:WinDir\System32\GroupPolicyUsers" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c RD /S /Q $env:WinDir\System32\GroupPolicy" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        Start-Process -FilePath "gpupdate" -ArgumentList "/force" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

        # Clean up registry keys
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

    # Final status and verification
    Write-Host ""
    Write-Host ('═' * 70) -ForegroundColor Green
    Write-StyledMessage Success '🎉 Windows Update è stato RIPRISTINATO ai valori predefiniti!'
    Write-StyledMessage Success '🔄 Servizi, registro e criteri sono stati configurati correttamente.'
    Write-StyledMessage Warning "⚡ Nota: È necessario un riavvio per applicare completamente tutte le modifiche."
    Write-Host ('═' * 70) -ForegroundColor Green
    Write-Host ""

    Write-StyledMessage Info '🔍 Verifica finale dello stato dei servizi...'

    $verificationServices = @('wuauserv', 'BITS', 'UsoSvc', 'WaaSMedicSvc')
    foreach ($service in $verificationServices) {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc) {
            $status = if ($svc.Status -eq 'Running') { '🟢 ATTIVO' } else { '🟡 INATTIVO' }
            $startup = $svc.StartType
            Write-StyledMessage Info "📊 $service - Stato: $status | Avvio: $startup"
        }
    }

    Write-Host ""
    Write-StyledMessage Info '💡 Windows Update dovrebbe ora funzionare normalmente.'
    Write-StyledMessage Info '🔧 Verifica aprendo Impostazioni > Aggiornamento e sicurezza.'
    Write-StyledMessage Info '📝 Se necessario, riavvia il sistema per applicare tutte le modifiche.'

}
function WinReinstallStore {
    <#
    .SYNOPSIS
        Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget.

    .DESCRIPTION
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI senza output bloccanti.
    #>

    param([int]$CountdownSeconds = 30)

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
            [Parameter(Mandatory = $true)]
            [string]$text,
            [Parameter(Mandatory = $false)]
            [int]$width = $Host.UI.RawUI.BufferSize.Width # Usa la larghezza dinamica di default
        )

        # Calcola il padding necessario
        $padding = [Math]::Max(0, [Math]::Floor(($width - $text.Length) / 2))

        # Restituisce la stringa centrata
        return (' ' * $padding + $text)
    }

    #---

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
            ' Store Repair Toolkit By MagnetarMan',
            '       Version 2.2.4 (Build 1)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -text $line -width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }
    function Write-StyledMessage([string]$type, [string]$text) {
        $style = $MsgStyles[$type]
        Write-Host "$($style.Icon) $text" -ForegroundColor $style.Color
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
        Write-StyledMessage Progress "Reinstallazione Winget in corso..."
        Stop-InterferingProcesses

        $originalPos = [Console]::CursorTop
        try {
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            
            if ([System.Environment]::OSVersion.Version.Build -ge 26100) {
                try {
                    if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                        $null = Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                        Start-Sleep 5
                        if (Test-WingetAvailable) { return $true }
                    }
                }
                catch {}
            }

            $url = "https://aka.ms/getwinget"
            $temp = "$env:TEMP\WingetInstaller.msixbundle"
            if (Test-Path $temp) { Remove-Item $temp -Force *>$null }

            Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing *>$null
            $process = Start-Process powershell -ArgumentList @(
                "-NoProfile", "-WindowStyle", "Hidden", "-Command",
                "try { Add-AppxPackage -Path '$temp' -ForceApplicationShutdown -ErrorAction Stop } catch { exit 1 }; exit 0"
            ) -Wait -PassThru -WindowStyle Hidden

            Remove-Item $temp -Force -ErrorAction SilentlyContinue *>$null
            
            # Reset cursore e flush output
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            
            Start-Sleep 5
            return (Test-WingetAvailable)
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
            
            $null = Start-Process winget -ArgumentList "uninstall --exact --id MartiCliment.UniGetUI --silent --disable-interactivity" -Wait -PassThru -WindowStyle Hidden
            Start-Sleep 2
            $process = Start-Process winget -ArgumentList "install --exact --id MartiCliment.UniGetUI --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity --force" -Wait -PassThru -WindowStyle Hidden
            
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
    
    function Start-CountdownReboot([int]$Seconds) {
        Write-StyledMessage Warning "Riavvio necessario per applicare le modifiche"
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

        try {
            shutdown /r /t 0
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore riavvio: $_"
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

        if (Start-CountdownReboot -Seconds $CountdownSeconds) {
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
            '        Version 2.2.4 (Build 1)'
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
        Queste cartelle sono protette e NON verranno mai cancellate durante la pulizia.
        - WinSxS Assemblies sostituiti
        - Rapporti Errori Windows
        - Registro Eventi Windows
        - Cronologia Installazioni Windows Update
        - Punti di Ripristino del sistema
        - Cache Download Windows
        - Prefetch Windows
        - Cache Miniature Explorer
        - Cache web WinInet
        - Cookie Internet
        - Cache DNS
        - File Temporanei Windows
        - File Temporanei Utente
        - Coda di Stampa
        - Log di Sistema
    #>

    param([int]$CountdownSeconds = 30)

    $Host.UI.RawUI.WindowTitle = "Cleaner Toolkit By MagnetarMan"
    $script:Log = @(); $script:CurrentAttempt = 0

    # Setup logging specifico per WinCleaner
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\WinCleaner_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    $CleanupTasks = @(
        @{ Task = 'CleanMgrAuto'; Name = 'Pulizia automatica CleanMgr'; Icon = '🧹'; Auto = $true }
        @{ Task = 'WinSxS'; Name = 'WinSxS - Assembly sostituiti'; Icon = '📦'; Auto = $false }
        @{ Task = 'ErrorReports'; Name = 'Rapporti errori Windows'; Icon = '📋'; Auto = $false }
        @{ Task = 'EventLogs'; Name = 'Registro eventi Windows'; Icon = '📜'; Auto = $false }
        @{ Task = 'UpdateHistory'; Name = 'Cronologia Windows Update'; Icon = '📝'; Auto = $false }
        @{ Task = 'RestorePoints'; Name = 'Punti ripristino sistema'; Icon = '💾'; Auto = $false }
        @{ Task = 'DownloadCache'; Name = 'Cache download Windows'; Icon = '⬇️'; Auto = $false }
        @{ Task = 'Prefetch'; Name = 'Cache Prefetch Windows'; Icon = '⚡'; Auto = $false }
        @{ Task = 'ThumbnailCache'; Name = 'Cache miniature Explorer'; Icon = '🖼️'; Auto = $false }
        @{ Task = 'WinInetCache'; Name = 'Cache web WinInet'; Icon = '🌐'; Auto = $false }
        @{ Task = 'InternetCookies'; Name = 'Cookie Internet'; Icon = '🍪'; Auto = $false }
        @{ Task = 'DNSFlush'; Name = 'Flush cache DNS'; Icon = '🔄'; Auto = $false }
        @{ Task = 'WindowsTemp'; Name = 'File temporanei Windows'; Icon = '🗂️'; Auto = $false }
        @{ Task = 'UserTemp'; Name = 'File temporanei utente'; Icon = '📁'; Auto = $false }
        @{ Task = 'PrintQueue'; Name = 'Coda di stampa'; Icon = '🖨️'; Auto = $false }
        @{ Task = 'SystemLogs'; Name = 'Log di sistema'; Icon = '📄'; Auto = $false }
        @{ Task = 'WindowsOld'; Name = 'Cartella Windows.old'; Icon = '🗑️'; Auto = $false } )

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        $timestamp = Get-Date -Format "HH:mm:ss"

        # Rimuovi emoji duplicati dal testo se presenti
        $cleanText = $Text -replace '^(✅|||💎|🔍|🚀|⚙️|🧹|📦|📋|📜|📝|💾|⬇️|🔧|⚡|🖼️|🌐|🍪|🔄|🗂️|📁|🖨️|📄|🗑️|💭|⏸️|▶️|💡|⏰|🎉|💻|📊|❌)\s*', ''

        Write-Host "[$timestamp] $($style.Icon) $cleanText" -ForegroundColor $style.Color

        # Log dettagliato per operazioni importanti
        if ($Type -in @('Info', 'Warning', 'Error')) {
            $logEntry = "[$timestamp] [$Type] $cleanText"
            $script:Log += $logEntry
        }
    }

    function Test-ExcludedPath {
        param([string]$Path)

        # Esclusioni tassative - QUESTE CARTELLE SONO VITALI E NON DEVONO MAI ESSERE CANCELLATE
        $excludedPaths = @(
            "$env:LOCALAPPDATA\WinToolkit"  # CARTELLA VITALE: Contiene toolkit, log e dati essenziali
        )

        $fullPath = $Path
        if (-not [System.IO.Path]::IsPathRooted($Path)) {
            $fullPath = Join-Path (Get-Location) $Path
        }

        foreach ($excluded in $excludedPaths) {
            $excludedFull = $excluded
            if (-not [System.IO.Path]::IsPathRooted($excluded)) {
                $excludedFull = [Environment]::ExpandEnvironmentVariables($excluded)
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
        param(
            [string]$FilePath,
            [string[]]$ArgumentList,
            [int]$TimeoutSeconds = 300,
            [string]$Activity = "Processo in esecuzione",
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

            # Usa WindowStyle Hidden OPPURE NoNewWindow, non entrambi
            if ($Hidden) {
                $processParams.Add('WindowStyle', 'Hidden')
            }
            else {
                $processParams.Add('NoNewWindow', $true)
            }

            $proc = Start-Process @processParams

            while (-not $proc.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                if ($percent -lt 90) { $percent += Get-Random -Minimum 1 -Maximum 3 }
                Show-ProgressBar $Activity "In esecuzione... ($elapsed secondi)" $percent '⏳' $spinner
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

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '▒' * (30 - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Clear-ProgressLine {
        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline
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

    function Invoke-CleanMgrAuto {
        Write-StyledMessage Info "🧹 Pulizia disco tramite CleanMgr..."
        $percent = 0; $spinnerIndex = 0

        try {
            Write-StyledMessage Info "⚙️ Verifica configurazione CleanMgr nel registro..."
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"

            # Verifica se esistono già configurazioni valide
            $existingConfigs = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue |
            Where-Object {
                $stateFlag = $null
                try {
                    $stateFlag = Get-ItemProperty -Path $_.PSPath -Name "StateFlags0065" -ErrorAction SilentlyContinue
                }
                catch {}
                $stateFlag -and $stateFlag.StateFlags0065 -eq 2
            }

            # Conta quante opzioni valide sono configurate
            $validOptions = 0
            Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $stateFlag = Get-ItemProperty -Path $_.PSPath -Name "StateFlags0065" -ErrorAction SilentlyContinue
                    if ($stateFlag -and $stateFlag.StateFlags0065 -eq 2) { $validOptions++ }
                }
                catch {}
            }

            if (-not $existingConfigs -or $validOptions -lt 3) {
                Write-StyledMessage Info "📝 Configurazione opzioni di pulizia nel registro..."
                
                # Abilita tutte le opzioni di pulizia disponibili con StateFlags0065
                $cleanOptions = @(
                    "Active Setup Temp Folders",
                    "BranchCache",
                    "D3D Shader Cache",
                    "Delivery Optimization Files",
                    "Downloaded Program Files",
                    "Internet Cache Files",
                    "Memory Dump Files",
                    "Recycle Bin",
                    "Setup Log Files",
                    "System error memory dump files",
                    "System error minidump files",
                    "Temporary Files",
                    "Temporary Setup Files",
                    "Thumbnail Cache",
                    "Windows Error Reporting Files",
                    "Windows Upgrade Log Files"
                )

                $configuredCount = 0
                $availableOptions = @()

                # Prima verifica quali opzioni sono effettivamente disponibili
                foreach ($option in $cleanOptions) {
                    $optionPath = Join-Path $regPath $option
                    if (Test-Path $optionPath) {
                        $availableOptions += $option
                    }
                }

                Write-StyledMessage Info "📋 Trovate $($availableOptions.Count) opzioni di pulizia disponibili"

                # Configura solo le opzioni disponibili
                foreach ($option in $availableOptions) {
                    $optionPath = Join-Path $regPath $option
                    try {
                        Set-ItemProperty -Path $optionPath -Name "StateFlags0065" -Value 2 -Type DWORD -Force -ErrorAction Stop
                        $configuredCount++
                        Write-StyledMessage Info "✅ Configurata: $option"
                    }
                    catch {
                        Write-StyledMessage Warning "❌ Impossibile configurare: $option - $($_.Exception.Message)"
                    }
                }

                Write-StyledMessage Info "✅ Configurate $configuredCount opzioni di pulizia"
            }
            else {
                Write-StyledMessage Info "✅ Configurazione esistente trovata nel registro"
            }

            # Verifica se ci sono effettivamente file da pulire
            Write-StyledMessage Info "🔍 Verifica se ci sono file da pulire..."
            $startTime = Get-Date
            $testProc = Start-Process 'cleanmgr.exe' -ArgumentList '/sagerun:65' -PassThru -WindowStyle Hidden -Wait

            if ($testProc.ExitCode -eq 0 -and (Get-Date) - $startTime -lt [TimeSpan]::FromSeconds(5)) {
                Write-StyledMessage Info "💨 CleanMgr completato rapidamente - probabilmente nessun file da pulire"
                Write-StyledMessage Success "✅ Verifica pulizia completata - sistema già pulito"
                return @{ Success = $true; ErrorCount = 0 }
            }

            # Esecuzione pulizia con configurazione automatica (se necessario)
            Write-StyledMessage Info "🚀 Avvio pulizia disco (questo può richiedere diversi minuti)..."
            $proc = Start-Process 'cleanmgr.exe' -ArgumentList '/sagerun:65' -PassThru -WindowStyle Minimized

            Write-StyledMessage Info "🔍 Processo CleanMgr avviato (PID: $($proc.Id))"
            
            # Attendi che il processo si stabilizzi
            Start-Sleep -Seconds 3
            
            # Timeout di sicurezza (15 minuti max per CleanMgr)
            $timeout = 900
            $lastCheck = Get-Date
            
            while (-not $proc.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 0)
                
                # Verifica se il processo è ancora attivo
                try {
                    $proc.Refresh()
                    $cpuUsage = (Get-Process -Id $proc.Id -ErrorAction Stop).CPU
                    
                    # Aggiorna percentuale in base al tempo trascorso (stima)
                    if ($elapsed -lt 60) {
                        $percent = [math]::Min(30, $elapsed / 2)
                    }
                    elseif ($elapsed -lt 180) {
                        $percent = 30 + (($elapsed - 60) / 4)
                    }
                    else {
                        $percent = [math]::Min(95, 60 + (($elapsed - 180) / 10))
                    }
                    
                    Show-ProgressBar "Pulizia CleanMgr" "Analisi e pulizia in corso... ($elapsed s)" ([int]$percent) '🧹' $spinner
                    Start-Sleep -Milliseconds 1000
                }
                catch {
                    # Processo terminato
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
                catch {
                    # Processo già terminato
                }
                $script:Log += "[CleanMgrAuto] Timeout dopo $timeout secondi"
                return @{ Success = $true; ErrorCount = 0 }
            }

            $exitCode = $proc.ExitCode
            Clear-ProgressLine
            Show-ProgressBar "Pulizia CleanMgr" 'Completato' 100 '🧹'
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
        Write-StyledMessage Info "📦 Pulizia componenti WinSxS sostituiti..."
        $percent = 0; $spinnerIndex = 0

        try {
            Write-StyledMessage Info "🔍 Avvio analisi componenti WinSxS..."

            $result = Start-ProcessWithTimeout -FilePath 'DISM.exe' -ArgumentList '/Online /Cleanup-Image /StartComponentCleanup /ResetBase' -TimeoutSeconds 900 -Activity "WinSxS Cleanup" -Hidden

            if ($result.TimedOut) {
                Write-StyledMessage Warning "Pulizia WinSxS interrotta per timeout"
                $script:Log += "[WinSxS]  Timeout dopo 15 minuti"
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
                $script:Log += "[WinSxS]  Completato con warnings (Exit code: $exitCode)"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante pulizia WinSxS: $($_.Exception.Message)"
            $script:Log += "[WinSxS]  Errore: $($_.Exception.Message)"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ErrorReportsCleanup {
        Write-StyledMessage Info "📋 Pulizia rapporti errori Windows..."
        $werPaths = @(
            "$env:ProgramData\Microsoft\Windows\WER",
            "$env:ALLUSERSPROFILE\Microsoft\Windows\WER"
        )

        $totalCleaned = 0
        foreach ($path in $werPaths) {
            # Verifica esclusione cartella WinToolkit
            if (Test-ExcludedPath $path) {
                continue
            }

            if (Test-Path $path) {
                try {
                    $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                        -not (Test-ExcludedPath $_.FullName)
                    }
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
        Write-StyledMessage Info "📜 Pulizia registro eventi Windows..."
        try {
            # Backup dei log attuali
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupPath = "$env:TEMP\EventLogs_Backup_$timestamp.evtx"

            wevtutil el | ForEach-Object {
                wevtutil cl $_ 2>$null
            }

            Write-StyledMessage Success "✅ Registro eventi pulito"
            $script:Log += "[EventLogs] ✅ Pulizia completata"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia registro eventi: $_"
            $script:Log += "[EventLogs]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-UpdateHistoryCleanup {
        Write-StyledMessage Info "📝 Pulizia cronologia Windows Update..."
        $updatePaths = @(
            "C:\WINDOWS\SoftwareDistribution\DataStore\DataStore.edb",
            "C:\WINDOWS\SoftwareDistribution\DataStore\DataStore.jfm",
            "C:\WINDOWS\SoftwareDistribution\DataStore\Logs"
        )

        $totalCleaned = 0
        foreach ($path in $updatePaths) {
            # Verifica esclusione cartella WinToolkit
            if (Test-ExcludedPath $path) {
                continue
            }

            try {
                if (Test-Path $path) {
                    if (Test-Path -Path $path -PathType Container) {
                        $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                            -not (Test-ExcludedPath $_.FullName)
                        }
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
                Write-StyledMessage Warning " Impossibile rimuovere $path - $_"
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
        Write-StyledMessage Info "💾 Disattivazione punti ripristino sistema..."
        try {
            # Disattiva la protezione del sistema
            vssadmin delete shadows /all /quiet 2>$null

            # Disattiva la protezione del sistema per il disco C:
            Disable-ComputerRestore -Drive "C:" -ErrorAction SilentlyContinue

            Write-StyledMessage Success "✅ Punti ripristino disattivati"
            $script:Log += "[RestorePoints] ✅ Disattivazione completata"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning " Errore durante disattivazione punti ripristino: $_"
            $script:Log += "[RestorePoints]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DownloadCacheCleanup {
        Write-StyledMessage Info "⬇️ Pulizia cache download Windows..."
        $downloadPath = "C:\WINDOWS\SoftwareDistribution\Download"

        try {
            # Verifica esclusione cartella WinToolkit
            if (Test-ExcludedPath $downloadPath) {
                Write-StyledMessage Info "💭 Cache download esclusa dalla pulizia"
                $script:Log += "[DownloadCache] ℹ️ Directory esclusa"
                return @{ Success = $true; ErrorCount = 0 }
            }

            if (Test-Path $downloadPath) {
                $files = Get-ChildItem -Path $downloadPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                    -not (Test-ExcludedPath $_.FullName)
                }
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
            Write-StyledMessage Warning " Errore durante pulizia cache download: $_"
            $script:Log += "[DownloadCache]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }


    function Invoke-PrefetchCleanup {
        Write-StyledMessage Info "⚡ Pulizia cache Prefetch Windows..."
        $prefetchPath = "C:\WINDOWS\Prefetch"

        try {
            if (Test-Path $prefetchPath) {
                $files = Get-ChildItem -Path $prefetchPath -File -ErrorAction SilentlyContinue
                $files | Remove-Item -Force -ErrorAction SilentlyContinue

                Write-StyledMessage Success "✅ Cache Prefetch pulita ($($files.Count) file)"
                $script:Log += "[Prefetch] ✅ Pulizia completata ($($files.Count) file)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Info "💭 Cache Prefetch non presente"
                $script:Log += "[Prefetch] ℹ️ Directory non presente"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Warning " Errore durante pulizia Prefetch: $_"
            $script:Log += "[Prefetch]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ThumbnailCacheCleanup {
        Write-StyledMessage Info "🖼️ Pulizia cache miniature Explorer..."
        $thumbnailPaths = @(
            "$env:APPDATA\Microsoft\Windows\Explorer",
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        )

        $totalCleaned = 0
        $thumbnailFiles = @(
            "iconcache_*.db", "thumbcache_*.db", "ExplorerStartupLog*.etl",
            "NotifyIcon", "RecommendationsFilterList.json"
        )

        foreach ($path in $thumbnailPaths) {
            # Verifica esclusione cartella WinToolkit
            if (Test-ExcludedPath $path) {
                continue
            }

            foreach ($pattern in $thumbnailFiles) {
                try {
                    $files = Get-ChildItem -Path $path -Name $pattern -ErrorAction SilentlyContinue | Where-Object {
                        $fullPath = Join-Path $path $_
                        -not (Test-ExcludedPath $fullPath)
                    }
                    $files | ForEach-Object {
                        $fullPath = Join-Path $path $_
                        Remove-Item -Path $fullPath -Force -ErrorAction SilentlyContinue
                        if (-not (Test-Path $fullPath)) { $totalCleaned++ }
                    }
                }
                catch {
                    Write-StyledMessage Warning " Impossibile rimuovere alcuni file in $path"
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
        Write-StyledMessage Info "🌐 Pulizia cache web WinInet..."
        try {
            # Pulisce la cache WinInet per tutti gli utenti
            $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
            $totalCleaned = 0

            foreach ($user in $users) {
                $localAppData = "$($user.FullName)\AppData\Local\Microsoft\Windows\INetCache"

                # Verifica esclusione cartella WinToolkit
                if (Test-ExcludedPath $localAppData) {
                    continue
                }

                if (Test-Path $localAppData) {
                    try {
                        $files = Get-ChildItem -Path $localAppData -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                            -not (Test-ExcludedPath $_.FullName)
                        }
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        $totalCleaned += $files.Count
                    }
                    catch {
                        Write-StyledMessage Warning " Impossibile pulire cache per utente $($user.Name)"
                    }
                }
            }

            # Forza pulizia cache IE
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 8 2>$null
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 2 2>$null

            Write-StyledMessage Success "✅ Cache WinInet pulita ($totalCleaned file)"
            $script:Log += "[WinInetCache] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning " Errore durante pulizia cache WinInet: $_"
            $script:Log += "[WinInetCache]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-InternetCookiesCleanup {
        Write-StyledMessage Info "🍪 Pulizia cookie Internet..."
        try {
            # Pulisce i cookie per tutti gli utenti
            $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
            $totalCleaned = 0

            foreach ($user in $users) {
                $cookiesPaths = @(
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\INetCookies",
                    "$($user.FullName)\AppData\Roaming\Microsoft\Windows\Cookies"
                )

                foreach ($path in $cookiesPaths) {
                    # Verifica esclusione cartella WinToolkit
                    if (Test-ExcludedPath $path) {
                        continue
                    }

                    if (Test-Path $path) {
                        try {
                            $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                                -not (Test-ExcludedPath $_.FullName)
                            }
                            $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                            $totalCleaned += $files.Count
                        }
                        catch {
                            Write-StyledMessage Warning " Impossibile pulire cookie per utente $($user.Name)"
                        }
                    }
                }
            }

            # Forza pulizia cookie IE
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 1 2>$null

            Write-StyledMessage Success "✅ Cookie Internet puliti ($totalCleaned file)"
            $script:Log += "[InternetCookies] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning " Errore durante pulizia cookie: $_"
            $script:Log += "[InternetCookies]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DNSFlush {
        Write-StyledMessage Info "🔄 Flush cache DNS..."
        try {
            # Esegue il flush della cache DNS
            $result = ipconfig /flushdns 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-StyledMessage Success "✅ Cache DNS svuotata con successo"
                $script:Log += "[DNSFlush] ✅ Flush completato"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Warning " Flush DNS completato con warnings"
                $script:Log += "[DNSFlush]  Completato con warnings"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Warning " Errore durante flush DNS: $_"
            $script:Log += "[DNSFlush]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WindowsTempCleanup {
        Write-StyledMessage Info "🗂️ Pulizia file temporanei Windows..."
        $tempPath = "C:\WINDOWS\Temp"

        try {
            # Verifica esclusione cartella WinToolkit
            if (Test-ExcludedPath $tempPath) {
                Write-StyledMessage Info "💭 Cartella temporanei Windows esclusa dalla pulizia"
                $script:Log += "[WindowsTemp] ℹ️ Directory esclusa"
                return @{ Success = $true; ErrorCount = 0 }
            }

            if (Test-Path $tempPath) {
                $files = Get-ChildItem -Path $tempPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                    -not (Test-ExcludedPath $_.FullName)
                }
                $totalSize = ($files | Measure-Object -Property Length -Sum).Sum / 1MB
                $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

                Write-StyledMessage Success "✅ File temporanei Windows puliti ($($files.Count) file, $([math]::Round($totalSize, 2)) MB)"
                $script:Log += "[WindowsTemp] ✅ Pulizia completata ($($files.Count) file)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Info "💭 Cartella temporanei Windows non presente"
                $script:Log += "[WindowsTemp] ℹ️ Directory non presente"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Warning " Errore durante pulizia file temporanei Windows: $_"
            $script:Log += "[WindowsTemp]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-UserTempCleanup {
        Write-StyledMessage Info "📁 Pulizia file temporanei utente..."
        try {
            # Pulisce i file temporanei per tutti gli utenti
            $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
            $totalCleaned = 0
            $totalSize = 0

            foreach ($user in $users) {
                $tempPaths = @(
                    "$($user.FullName)\AppData\Local\Temp",
                    "$($user.FullName)\AppData\LocalLow\Temp"
                )

                foreach ($path in $tempPaths) {
                    if (Test-Path $path) {
                        try {
                            # Verifica esclusione cartella WinToolkit
                            if (Test-ExcludedPath $path) {
                                continue
                            }

                            $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                                -not (Test-ExcludedPath $_.FullName)
                            }
                            $size = ($files | Measure-Object -Property Length -Sum).Sum / 1MB
                            $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                            $totalCleaned += $files.Count
                            $totalSize += $size
                        }
                        catch {
                            Write-StyledMessage Warning " Impossibile pulire temp per utente $($user.Name)"
                        }
                    }
                }
            }

            if ($totalCleaned -gt 0) {
                Write-StyledMessage Success "✅ File temporanei utente puliti ($totalCleaned file, $([math]::Round($totalSize, 2)) MB)"
                $script:Log += "[UserTemp] ✅ Pulizia completata ($totalCleaned file)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Info "💭 Nessun file temporaneo utente da pulire"
                $script:Log += "[UserTemp] ℹ️ Nessun file da pulire"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Warning " Errore durante pulizia file temporanei utente: $_"
            $script:Log += "[UserTemp]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-PrintQueueCleanup {
        Write-StyledMessage Info "🖨️ Pulizia coda di stampa..."
        try {
            # Ferma il servizio spooler
            Write-StyledMessage Info "⏸️ Arresto servizio spooler..."
            Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2

            # Pulisce la coda di stampa
            $spoolPath = "C:\WINDOWS\System32\spool\PRINTERS"
            $totalCleaned = 0

            if (Test-Path $spoolPath) {
                $files = Get-ChildItem -Path $spoolPath -File -ErrorAction SilentlyContinue
                $files | Remove-Item -Force -ErrorAction SilentlyContinue
                $totalCleaned = $files.Count
            }

            # Riavvia il servizio spooler
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
            # Assicura che il servizio spooler sia riavviato anche in caso di errore
            Start-Service -Name Spooler -ErrorAction SilentlyContinue
            Write-StyledMessage Warning " Errore durante pulizia coda di stampa: $_"
            $script:Log += "[PrintQueue]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-SystemLogsCleanup {
        Write-StyledMessage Info "📄 Pulizia log di sistema..."
        $logPaths = @(
            "C:\WINDOWS\Logs",
            "C:\WINDOWS\System32\LogFiles",
            "C:\WINDOWS\Panther",
            "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"
        )

        $totalCleaned = 0
        $totalSize = 0

        foreach ($path in $logPaths) {
            # Verifica esclusione cartella WinToolkit
            if (Test-ExcludedPath $path) {
                continue
            }

            if (Test-Path $path) {
                try {
                    $files = Get-ChildItem -Path $path -Recurse -File -Include "*.log", "*.etl", "*.txt" -ErrorAction SilentlyContinue | Where-Object {
                        -not (Test-ExcludedPath $_.FullName)
                    }
                    $size = ($files | Measure-Object -Property Length -Sum).Sum / 1MB
                    $files | Remove-Item -Force -ErrorAction SilentlyContinue
                    $totalCleaned += $files.Count
                    $totalSize += $size
                    Write-StyledMessage Info "🗑️ Puliti log da: $path"
                }
                catch {
                    Write-StyledMessage Warning " Impossibile pulire alcuni log in $path"
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
    
    function Invoke-WindowsOldCleanup {
        Write-StyledMessage Info "🗑️ Pulizia cartella Windows.old..."
        $windowsOldPath = "C:\Windows.old"
        $errorCount = 0
    
        try {
            if (Test-Path -Path $windowsOldPath) {
                Write-StyledMessage Info "🔍 Trovata cartella Windows.old. Tentativo di rimozione forzata..."
                $script:Log += "[WindowsOld] 🔍 Trovata cartella Windows.old. Tentativo di rimozione forzata..."
    
                # 1. Assumere la proprietà (Take Ownership)
                Write-StyledMessage Info "1. Assunzione della proprietà (Take Ownership)..."
                $takeownResult = cmd /c takeown /F $windowsOldPath /R /A /D Y 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-StyledMessage Warning "❌ Errore durante l'assunzione della proprietà: $takeownResult"
                    $script:Log += "[WindowsOld] ❌ Errore takeown: $takeownResult"
                    $errorCount++
                }
                else {
                    Write-StyledMessage Info "✅ Proprietà assunta."
                    $script:Log += "[WindowsOld] ✅ Proprietà assunta."
                }
                Start-Sleep -Milliseconds 500 # Give system a moment
    
                # 2. Assegnare i permessi di controllo completo agli amministratori
                Write-StyledMessage Info "2. Assegnazione dei permessi di Controllo Completo (Full Control)..."
                $icaclsResult = cmd /c icacls $windowsOldPath /T /grant Administrators:F 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-StyledMessage Warning "❌ Errore durante l'assegnazione permessi: $icaclsResult"
                    $script:Log += "[WindowsOld] ❌ Errore icacls: $icaclsResult"
                    $errorCount++
                }
                else {
                    Write-StyledMessage Info "✅ Permessi di controllo completo assegnati agli Amministratori."
                    $script:Log += "[WindowsOld] ✅ Permessi di controllo completo assegnati agli Amministratori."
                }
                Start-Sleep -Milliseconds 500 # Give system a moment
    
                # 3. Rimuovere la cartella con la forzatura
                Write-StyledMessage Info "3. Rimozione forzata della cartella..."
                try {
                    Remove-Item -Path $windowsOldPath -Recurse -Force -ErrorAction Stop
                }
                catch {
                    Write-StyledMessage Error "❌ ERRORE durante la rimozione di Windows.old: $($_.Exception.Message)"
                    $script:Log += "[WindowsOld] ❌ ERRORE durante la rimozione: $($_.Exception.Message)"
                    $errorCount++
                }
                
                # 4. Verifica finale
                if (Test-Path -Path $windowsOldPath) {
                    Write-StyledMessage Error "❌ ERRORE: La cartella $windowsOldPath non è stata rimossa."
                    $script:Log += "[WindowsOld] ❌ Cartella non rimossa dopo tentativi forzati."
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
    
    function Invoke-CleanupTask([hashtable]$Task, [int]$Step, [int]$Total) {
        Write-StyledMessage Info "[$Step/$Total] Avvio $($Task.Name)..."
        $percent = 0; $spinnerIndex = 0

        try {
            $result = switch ($Task.Task) {
                'CleanMgrAuto' { Invoke-CleanMgrAuto }
                'WinSxS' { Invoke-WinSxSCleanup }
                'ErrorReports' { Invoke-ErrorReportsCleanup }
                'EventLogs' { Invoke-EventLogsCleanup }
                'UpdateHistory' { Invoke-UpdateHistoryCleanup }
                'RestorePoints' { Invoke-RestorePointsCleanup }
                'DownloadCache' { Invoke-DownloadCacheCleanup }
                'Prefetch' { Invoke-PrefetchCleanup }
                'ThumbnailCache' { Invoke-ThumbnailCacheCleanup }
                'WinInetCache' { Invoke-WinInetCacheCleanup }
                'InternetCookies' { Invoke-InternetCookiesCleanup }
                'DNSFlush' { Invoke-DNSFlush }
                'WindowsTemp' { Invoke-WindowsTempCleanup }
                'UserTemp' { Invoke-UserTempCleanup }
                'PrintQueue' { Invoke-PrintQueueCleanup }
                'SystemLogs' { Invoke-SystemLogsCleanup }
                'WindowsOld' { Invoke-WindowsOldCleanup }
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
            $script:Log += "[$($Task.Name)]  Errore fatale: $_"
            return @{ Success = $false; ErrorCount = 1 }
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
            '    Cleaner Toolkit By MagnetarMan',
            '       Version 2.3.0 (Build 8)'
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
        Write-StyledMessage Info '🧹 Avvio pulizia completa del sistema...'
        Write-Host ''

        $totalErrors = $successCount = 0
        for ($i = 0; $i -lt $CleanupTasks.Count; $i++) {
            $result = Invoke-CleanupTask $CleanupTasks[$i] ($i + 1) $CleanupTasks.Count
            if ($result.Success) { $successCount++ }
            $totalErrors += $result.ErrorCount
            Start-Sleep 1
        }

        Write-Host ''
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-StyledMessage Success "🎉 Pulizia completata con successo!"
        Write-StyledMessage Success "💻 Completati $successCount/$($CleanupTasks.Count) task di pulizia"

        if ($totalErrors -gt 0) {
            Write-StyledMessage Warning " $totalErrors errori durante la pulizia"
        }

        # Mostra riepilogo dettagliato
        Write-Host ''
        Write-StyledMessage Info "📊 RIEPILOGO OPERAZIONI:"
        foreach ($logEntry in $script:Log) {
            if ($logEntry -match '✅|||ℹ️') {
                Write-Host "  $logEntry" -ForegroundColor Gray
            }
        }

        Write-StyledMessage Info "🔄 Il sistema verrà riavviato per applicare tutte le modifiche"
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-Host ''

        $shouldReboot = Start-InterruptibleCountdown $CountdownSeconds "Preparazione riavvio sistema"

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
        Write-StyledMessage Error ' Si è verificato un errore durante la pulizia.'
        Write-Host ('═' * 65) -ForegroundColor Red
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
        try { Stop-Transcript | Out-Null } catch {}
    }

}
# function SearchRepair {}
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
        Toolkit Driver Grafici - Installazione e configurazione driver GPU.

    .DESCRIPTION
        Script per l'installazione e configurazione ottimale dei driver grafici:
        - Rilevamento automatico GPU (NVIDIA, AMD, Intel)
        - Download driver più recenti dal sito ufficiale
        - Installazione pulita con pulizia precedente
        - Configurazione ottimale per gaming e prestazioni
        - Installazione software di controllo (GeForce Experience, AMD Software)
    #>

    param([int]$CountdownSeconds = 30)

    $Host.UI.RawUI.WindowTitle = "Driver Install Toolkit By MagnetarMan"
    $script:Log = @(); $script:CurrentAttempt = 0
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    # --- NEW: Define Constants and Paths ---
    $GitHubAssetBaseUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/"
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
            '       Version 2.3.0 (Build 9)'
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
            Identifies the manufacturer of the primary display adapter.
        .RETURNS
            'NVIDIA', 'AMD', 'Intel' or 'Unknown'
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
                return 'Intel' # While not explicitly requested for actions, it's good to identify.
            }
        }
        return 'Unknown'
    }

    function Set-BlockWindowsUpdateDrivers {
        <#
        .SYNOPSIS
            Blocks Windows Update from automatically downloading and installing drivers.
        .DESCRIPTION
            This function sets a registry key that prevents Windows Update from
            including drivers in quality updates, reducing conflicts with
            manufacturer-specific driver installations. It then forces a Group Policy update.
            Requires administrative privileges.
        #>
        Write-StyledMessage 'Info' "Configurazione per bloccare download driver da Windows Update..."

        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        $propertyName = "ExcludeWUDriversInQualityUpdate"
        $propertyValue = 1

        try {
            # Ensure the parent path exists
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }

            # Set the registry key to block driver downloads
            Set-ItemProperty -Path $regPath -Name $propertyName -Value $propertyValue -Type DWord -Force -ErrorAction Stop
            Write-StyledMessage 'Success' "Blocco download driver da Windows Update impostato correttamente nel registro."
            Write-StyledMessage 'Info' "Questa impostazione impedisce a Windows Update di installare driver automaticamente."
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante l'impostazione del blocco download driver da Windows Update: $($_.Exception.Message)"
            Write-StyledMessage 'Warning' "Potrebbe essere necessario eseguire lo script come amministratore."
            # Continue without forcing gpupdate if registry failed, as gpupdate won't reflect the change anyway.
            return
        }

        # Force Group Policy update
        Write-StyledMessage 'Info' "Aggiornamento dei criteri di gruppo in corso per applicare le modifiche..."
        try {
            # Use Start-Process with -Wait for gpupdate as it's an external executable
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
                Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -UseBasicParsing -ErrorAction Stop
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
        param(
            [Parameter(Mandatory = $true)]
            [int]$Seconds,
            [Parameter(Mandatory = $true)]
            [string]$Message
        )

        for ($i = $Seconds; $i -gt 0; $i--) {
            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r$($MsgStyles.Error.Icon) $Message tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep -Seconds 1
        }

        Write-Host "`r$($MsgStyles.Error.Icon) $Message tra 0 secondi [$('█' * 20)] 100%`n" -ForegroundColor Red
    }

    function Handle-InstallVideoDrivers {
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
        Write-StyledMessage 'Warning' "Opzione 2: Avvio procedura di reinstallazione/riparazione driver video. Richiesto riavvio."

        # Download DDU
        $dduZipUrl = "${GitHubAssetBaseUrl}DDU-18.1.3.5.zip"
        $dduZipPath = Join-Path $DriverToolsLocalPath "DDU-18.1.3.5.zip"

        if (-not (Download-FileWithProgress -Url $dduZipUrl -DestinationPath $dduZipPath -Description "DDU (Display Driver Uninstaller)")) {
            Write-StyledMessage 'Error' "Impossibile scaricare DDU. Annullamento operazione."
            return
        }

        # Extract DDU to Desktop
        Write-StyledMessage 'Info' "Estrazione DDU sul Desktop..."
        try {
            # Expand-Archive extracts to a folder with the same name as the zip file on the destination path.
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
            $amdInstallerPath = Join-Path $DesktopPath "AMD-Autodetect.exe" # Download to Desktop

            if (-not (Download-FileWithProgress -Url $amdInstallerUrl -DestinationPath $amdInstallerPath -Description "AMD Auto-Detect Tool")) {
                Write-StyledMessage 'Error' "Impossibile scaricare l'installer AMD. Annullamento operazione."
                return
            }
        }
        elseif ($gpuManufacturer -eq 'NVIDIA') {
            $nvidiaInstallerUrl = "${GitHubAssetBaseUrl}NVCleanstall_1.19.0.exe"
            $nvidiaInstallerPath = Join-Path $DesktopPath "NVCleanstall_1.19.0.exe" # Download to Desktop

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
        Write-StyledMessage 'Error' "ATTENZIONE: Il sistema sta per riavviarsi in modalità avanzata per permettere l'accesso alla modalità provvisoria."

        Start-InverseCountdown -Seconds 30 -Message "Riavvio in modalità avanzata in corso..."

        try {
            # Note: shutdown -o triggers advanced startup options, not direct safe mode boot.
            # User will need to manually select Safe Mode from the options.
            shutdown -r -o -t 0
            Write-StyledMessage 'Success' "Comando di riavvio inviato."
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante l'esecuzione del comando di riavvio: $($_.Exception.Message)"
        }
    }

    Show-Header

    # --- NEW: Call function to block Windows Update driver downloads ---
    Set-BlockWindowsUpdateDrivers
    # --- END NEW ---

    # --- NEW: Main Menu Logic ---
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
    # --- END NEW ---
}
function GamingToolkit {
    <#
    .SYNOPSIS
        Gaming Toolkit - Strumenti di ottimizzazione per il gaming su Windows.

    .DESCRIPTION
        Script per ottimizzare le prestazioni del sistema per il gaming:
        - Ottimizzazione servizi di sistema
        - Configurazione alimentazione alta prestazione
        - Disabilitazione notifiche durante il gaming
        - Ottimizzazione rete per gaming online
        - Configurazione priorità processi gaming
    #>

    param([int]$CountdownSeconds = 30)

    $Host.UI.RawUI.WindowTitle = "Gaming Toolkit By MagnetarMan"
    $script:Log = @(); $script:CurrentAttempt = 0
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('=' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '    Gaming Toolkit By MagnetarMan',
            '       Version 2.2.4 (Build 1)'
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

    Show-Header

    Write-StyledMessage 'Info' 'Gaming Toolkit - Funzione in sviluppo'
    Write-StyledMessage 'Info' 'Questa funzione sarà implementata nella versione 2.4'
    Write-Host ''
    Write-StyledMessage 'Warning' 'Sviluppo funzione in corso'

    Write-Host "
Premi un tasto per tornare al menu principale..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}


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
