<#
.SYNOPSIS
    WinToolkit - Suite di manutenzione Windows
.DESCRIPTION
    Framework modulare unificato.
    Contiene le funzioni core (UI, Log, Info) e il menu principale.
.NOTES
    Versione: 2.4.2 - 26/11/2025
    Autore: MagnetarMan
#>

param([int]$CountdownSeconds = 30)

# --- CONFIGURAZIONE GLOBALE ---
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan"
$ToolkitVersion = "2.4.2 (Build 108)"

# Setup Variabili Globali UI
$Global:Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
$Global:MsgStyles = @{
    Success  = @{ Icon = '✅'; Color = 'Green' }
    Warning  = @{ Icon = '⚠️'; Color = 'Yellow' }
    Error    = @{ Icon = '❌'; Color = 'Red' }
    Info     = @{ Icon = '💎'; Color = 'Cyan' }
    Progress = @{ Icon = '🔄'; Color = 'Magenta' }
}

# --- FUNZIONI HELPER CONDIVISE (DRY) ---

function Write-StyledMessage {
    param(
        [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Progress')][string]$Type,
        [string]$Text
    )
    $style = $Global:MsgStyles[$Type]
    $timestamp = Get-Date -Format "HH:mm:ss"
    $cleanText = $Text -replace '^[✅⚠️❌💎🔄🗂️📁🖨️📄🗑️💭⸏▶️💡⏰🎉💻📊]\s*', ''
    Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color
}

function Center-Text {
    param([string]$Text, [int]$Width = $Host.UI.RawUI.BufferSize.Width)
    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    return (' ' * $padding + $Text)
}

function Show-Header {
    <#
    .SYNOPSIS
        Mostra l'intestazione standardizzata.
    #>
    param([string]$SubTitle = "Menu Principale")
    Clear-Host
    $width = $Host.UI.RawUI.BufferSize.Width
    $asciiArt = @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        "       WinToolkit - $SubTitle",
        "       Versione $ToolkitVersion"
    )
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    foreach ($line in $asciiArt) {
        Write-Host (Center-Text $line $width) -ForegroundColor White
    }
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    Write-Host ''
}

function Initialize-ToolLogging {
    <#
    .SYNOPSIS
        Avvia il transcript per un tool specifico.
    #>
    param([string]$ToolName)
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    if (-not (Test-Path $logdir)) { New-Item -Path $logdir -ItemType Directory -Force | Out-Null }
    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}
    Start-Transcript -Path "$logdir\${ToolName}_$dateTime.log" -Append -Force | Out-Null
}

function Show-ProgressBar {
    <#
    .SYNOPSIS
        Mostra una barra di progresso testuale.
    #>
    param([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon = '⏳', [string]$Spinner = '', [string]$Color = 'Green')
    $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
    $filled = '█' * [math]::Floor($safePercent * 30 / 100)
    $empty = '▒' * (30 - $filled.Length)
    $bar = "[$filled$empty] {0,3}%" -f $safePercent
    Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
    if ($Percent -ge 100) { Write-Host '' }
}

function Start-InterruptibleCountdown {
    <#
    .SYNOPSIS
        Conto alla rovescia che può essere interrotto dall'utente.
    #>
    param([int]$Seconds = 30, [string]$Message = "Riavvio automatico")
    Write-StyledMessage -Type 'Info' -Text '💡 Premi un tasto qualsiasi per annullare...'
    Write-Host ''
    for ($i = $Seconds; $i -gt 0; $i--) {
        if ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
            Write-Host "`n"
            Write-StyledMessage -Type 'Warning' -Text '⏸️ Operazione annullata.'
            return $false
        }
        $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
        $filled = [Math]::Floor($percent * 20 / 100)
        $remaining = 20 - $filled
        $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"
        Write-Host "`r⏰ $Message tra $i secondi $bar" -NoNewline -ForegroundColor Red
        Start-Sleep 1
    }
    Write-Host "`n"
    return $true
}

function Get-SystemInfo {
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $computerInfo = Get-CimInstance Win32_ComputerSystem
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $versionMap = @{
            26100 = "24H2"; 22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2"; 19045 = "22H2"; 19044 = "21H2";
            19043 = "21H1"; 19042 = "20H2"; 19041 = "2004"; 18363 = "1909"; 18362 = "1903"; 17763 = "1809";
            17134 = "1803"; 16299 = "1709"; 15063 = "1703"; 14393 = "1607"; 10586 = "1511"; 10240 = "1507"
        }
        $build = [int]$osInfo.BuildNumber
        $ver = "N/A"
        foreach ($k in ($versionMap.Keys | Sort -Desc)) { if ($build -ge $k) { $ver = $versionMap[$k]; break } }
        
        return @{
            ProductName = $osInfo.Caption -replace 'Microsoft ', ''; BuildNumber = $build; DisplayVersion = $ver
            Architecture = $osInfo.OSArchitecture; ComputerName = $computerInfo.Name
            TotalRAM = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
            TotalDisk = [Math]::Round($diskInfo.Size / 1GB, 0)
            FreeDisk = [Math]::Round($diskInfo.FreeSpace / 1GB, 0)
            FreePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)
        }
    }
    catch { return $null }
}

function CheckBitlocker {
    try {
        $out = & manage-bde -status C: 2>&1
        if ($out -match "Stato protezione:\s*(.*)") { return $matches[1].Trim() }
        return "Non configurato"
    }
    catch { return "Non disponibile" }
}

function WinOSCheck {
    Show-Header -SubTitle "System Check"
    $si = Get-SystemInfo
    if (-not $si) { Write-StyledMessage 'Warning' "Info sistema non disponibili."; return }
    
    Write-Host "  Sistema: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($si.ProductName) ($($si.DisplayVersion))" -ForegroundColor White
    Write-Host ""
    
    if ($si.BuildNumber -ge 22000) { Write-StyledMessage 'Success' "Sistema compatibile (Win11/10 recente)." }
    elseif ($si.BuildNumber -ge 17763) { Write-StyledMessage 'Success' "Sistema compatibile (Win10)." }
    elseif ($si.BuildNumber -eq 9600) { Write-StyledMessage 'Warning' "Windows 8.1: Compatibilità parziale." }
    else {
        Write-Host ('*' * 65) -ForegroundColor Red
        Write-Host (Center-Text "🤣 ERRORE CRITICO 🤣" 65) -ForegroundColor Red
        Write-Host ('*' * 65) -ForegroundColor Red
        Write-Host "`n  Davvero pensi che questo script possa fare qualcosa per questa versione?`n" -ForegroundColor Red
        Write-Host "  Vuoi rischiare? [Y/N]" -ForegroundColor Yellow
        if ((Read-Host) -notmatch '^[Yy]$') { exit }
    }
    Start-Sleep -Seconds 2
}

# --- PLACEHOLDER PER COMPILATORE ---
function WinInstallPSProfile {
    <#
    .SYNOPSIS
        Script per installare il profilo PowerShell di ChrisTitusTech.

    .DESCRIPTION
        Installa e configura il profilo PowerShell personalizzato con oh-my-posh, zoxide e altre utilità.
        Richiede privilegi di amministratore e PowerShell 7+.
    #>

    Initialize-ToolLogging -ToolName "WinInstallPSProfile"
    Show-Header -SubTitle "Install Profilo PowerShell"

    function Add-ToSystemPath([string]$PathToAdd) {
        try {
            if (-not (Test-Path $PathToAdd)) {
                Write-StyledMessage Warning "Percorso non esistente: $PathToAdd"
                return $false
            }

            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            $pathExists = ($currentPath -split ';') | Where-Object { $_.TrimEnd('\') -ieq $PathToAdd.TrimEnd('\') }
            
            if ($pathExists) {
                Write-StyledMessage Info "Percorso già nel PATH: $PathToAdd"
                return $true
            }

            $PathToAdd = $PathToAdd.TrimStart(';')
            $newPath = if ($currentPath.EndsWith(';')) { "$currentPath$PathToAdd" } else { "$currentPath;$PathToAdd" }
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            $env:PATH = "$env:PATH;$PathToAdd"
            
            Write-StyledMessage Success "Percorso aggiunto al PATH: $PathToAdd"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore aggiunta PATH: $($_.Exception.Message)"
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

    for ($i = 5; $i -gt 0; $i--) {
        $spinner = $Global:Spinners[$i % $Global:Spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-StyledMessage Warning "Richiesti privilegi amministratore"
        Write-StyledMessage Info "Riavvio come amministratore..."

        try {
            Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { WinInstallPSProfile }`""
            return
        }
        catch {
            Write-StyledMessage Error "Impossibile elevare privilegi: $($_.Exception.Message)"
            return
        }
    }

    try {
        Write-StyledMessage Info "Installazione profilo PowerShell..."
        Write-Host ''

        if (-not (Get-Command "pwsh" -ErrorAction SilentlyContinue)) {
            Write-StyledMessage Error "PowerShell Core non installato!"
            return
        }

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-StyledMessage Warning "Richiesto PowerShell 7+"
            $choice = Read-Host "Procedere comunque? (S/N)"
            if ($choice -notmatch '^[SsYy]') {
                Write-StyledMessage Info "Installazione annullata"
                return
            }
        }
        
        $profileUrl = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        $oldHash = if (Test-Path $PROFILE) { Get-FileHash $PROFILE -ErrorAction SilentlyContinue } else { $null }

        Write-StyledMessage Info "Controllo aggiornamenti..."
        $tempProfile = "$env:TEMP\Microsoft.PowerShell_profile.ps1"
        try {
            Invoke-RestMethod $profileUrl -OutFile $tempProfile -UseBasicParsing
            $newHash = Get-FileHash $tempProfile
        }
        catch [System.Net.WebException] {
            Write-StyledMessage Error "Errore rete durante download profilo: $($_.Exception.Message)"
            return
        }
        catch {
            Write-StyledMessage Error "Errore download profilo: $($_.Exception.Message)"
            return
        }

        $profileDir = Split-Path $PROFILE -Parent
        if (!(Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
        $newHash.Hash | Out-File "$PROFILE.hash" -Force
        
        Write-StyledMessage Info "Hash profilo locale: $($oldHash.Hash), remoto: $($newHash.Hash)"
        if ($newHash.Hash -ne $oldHash.Hash) {
            if ((Test-Path $PROFILE) -and (-not (Test-Path "$PROFILE.bak"))) {
                Write-StyledMessage Info "Backup profilo esistente..."
                Copy-Item -Path $PROFILE -Destination "$PROFILE.bak" -Force
                Write-StyledMessage Success "Backup completato"
            }

            Write-StyledMessage Info "Installazione dipendenze..."
            Write-Host ''

            # oh-my-posh
            try {
                Write-StyledMessage Info "Installazione oh-my-posh..."
                $spinnerIndex = 0; $percent = 0
                
                $installProcess = Start-Process -FilePath "cmd" -ArgumentList "/c winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements --silent >nul 2>&1" -NoNewWindow -PassThru

                while (-not $installProcess.HasExited -and $percent -lt 90) {
                    $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                    Show-ProgressBar "oh-my-posh" "Installazione..." $percent '📦' $spinner
                    $percent += 2
                    Start-Sleep -Milliseconds 300
                }

                $installProcess.WaitForExit()
                if ($installProcess.ExitCode -ne 0) {
                    Write-StyledMessage Error "Installazione oh-my-posh fallita (ExitCode: $($installProcess.ExitCode))"
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
                    $pathArray = ($currentPath -split ';') | Where-Object { $_ -and $_.Trim() } | ForEach-Object { [System.IO.Path]::GetFullPath($_) }
                    if ($pathArray -notcontains $ompPath) {
                        $newPath = if ($currentPath.EndsWith(';')) { "$currentPath$ompPath" } else { "$currentPath;$ompPath" }
                        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
                        Write-StyledMessage Success "Path oh-my-posh aggiunto: $ompPath"
                    }
                    else {
                        Write-StyledMessage Info "Path oh-my-posh già presente."
                    }
                }
                else {
                    Write-StyledMessage Error "oh-my-posh.exe non trovato! Prova a reinstallarlo: winget install JanDeDobbeleer.OhMyPosh"
                }
            }
            catch {
                Write-StyledMessage Warning "Errore oh-my-posh: $($_.Exception.Message)"
            }

            # zoxide
            try {
                Write-StyledMessage Info "Installazione zoxide..."
                $spinnerIndex = 0; $percent = 0
                
                $installProcess = Start-Process -FilePath "cmd" -ArgumentList "/c winget install ajeetdsouza.zoxide -s winget --accept-package-agreements --accept-source-agreements --silent >nul 2>&1" -NoNewWindow -PassThru

                while (-not $installProcess.HasExited -and $percent -lt 90) {
                    $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                    Show-ProgressBar "zoxide" "Installazione..." $percent '⚡' $spinner
                    $percent += 2
                    Start-Sleep -Milliseconds 300
                }

                $installProcess.WaitForExit()
                if ($installProcess.ExitCode -ne 0) {
                    Write-StyledMessage Error "Installazione zoxide fallita (ExitCode: $($installProcess.ExitCode))"
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
                    $pathArray = ($currentPath -split ';') | Where-Object { $_ -and $_.Trim() } | ForEach-Object { [System.IO.Path]::GetFullPath($_) }
                    if ($pathArray -notcontains $zoxPath) {
                        $newPath = if ($currentPath.EndsWith(';')) { "$currentPath$zoxPath" } else { "$currentPath;$zoxPath" }
                        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
                        Write-StyledMessage Success "Path zoxide aggiunto: $zoxPath"
                    }
                    else {
                        Write-StyledMessage Info "Path zoxide già presente."
                    }
                }
                else {
                    Write-StyledMessage Error "zoxide.exe non trovato! Prova a reinstallarlo: winget install ajeetdsouza.zoxide"
                }
            }
            catch {
                Write-StyledMessage Warning "Errore zoxide: $($_.Exception.Message)"
            }

            # Refresh PATH
            Write-StyledMessage Info "Aggiornamento variabili d'ambiente..."
            $spinnerIndex = 0; $percent = 0
            $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
            $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
            $env:PATH = "$machinePath;$userPath"

            while ($percent -lt 90) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                Show-ProgressBar "PATH" "Aggiornamento..." $percent '🔧' $spinner
                $percent += Get-Random -Minimum 10 -Maximum 20
                Start-Sleep -Milliseconds 200
            }
            Show-ProgressBar "PATH" "Completato" 100 '🔧'
            Write-Host ''

            # Setup profilo
            Write-StyledMessage Info "Configurazione profilo PowerShell..."
            try {
                $spinnerIndex = 0; $percent = 0
                while ($percent -lt 90) {
                    $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                    Show-ProgressBar "Profilo" "Setup..." $percent '⚙️' $spinner
                    $percent += Get-Random -Minimum 3 -Maximum 8
                    Start-Sleep -Milliseconds 400
                }

                Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1' -UseBasicParsing).Content
                Show-ProgressBar "Profilo" "Completato" 100 '⚙️'
                Write-Host ''
                Write-StyledMessage Success "Profilo installato!"
                # Download e configurazione settings.json per Windows Terminal
                $wtSettingsUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/settings.json"
                $wtPath = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Directory -Filter "Microsoft.WindowsTerminal_*" -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $wtPath) {
                    Write-StyledMessage Warning "Directory Windows Terminal non trovata, impossibile configurare settings.json."
                    return
                }
                $wtLocalStateDir = Join-Path $wtPath.FullName "LocalState"
                if (-not (Test-Path $wtLocalStateDir)) {
                    New-Item -ItemType Directory -Path $wtLocalStateDir -Force | Out-Null
                }
                $settingsPath = Join-Path $wtLocalStateDir "settings.json"

                Write-StyledMessage Info "Download e configurazione settings.json per Windows Terminal..."
                $spinnerIndex = 0; $percent = 0
                try {
                    # Simulazione barra di progresso per il download
                    while ($percent -lt 80) {
                        $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                        Show-ProgressBar "settings.json WT" "Download..." $percent '🖼️' $spinner
                        $percent += Get-Random -Minimum 5 -Maximum 15
                        Start-Sleep -Milliseconds 200
                    }
                    Invoke-WebRequest $wtSettingsUrl -OutFile $settingsPath -UseBasicParsing
                    $percent = 100 # Assicura che la barra di progresso raggiunga il 100%
                    Show-ProgressBar "settings.json WT" "Completato" 100 '🖼️'
                    Write-Host '' # Aggiunge un newline dopo la barra di progresso
                    Write-StyledMessage Success "settings.json di Windows Terminal aggiornato con successo."
                }
                catch [System.Net.WebException] {
                    Write-StyledMessage Error "Errore di rete durante il download di settings.json: $($_.Exception.Message)"
                }
                catch {
                    Write-StyledMessage Error "Errore durante il download/copia di settings.json: $($_.Exception.Message)"
                }
            }
            catch {
                Write-StyledMessage Warning "Fallback: copia manuale profilo"
                Copy-Item -Path $tempProfile -Destination $PROFILE -Force
                Write-StyledMessage Success "Profilo copiato"
            }

            Write-Host ""
            Write-Host ('═' * 80) -ForegroundColor Green
            Write-StyledMessage Warning "Riavvio OBBLIGATORIO per:"
            Write-Host "  • PATH oh-my-posh e zoxide" -ForegroundColor Cyan
            Write-Host "  • Font installati" -ForegroundColor Cyan
            Write-Host "  • Attivazione profilo" -ForegroundColor Cyan
            Write-Host "  • Variabili d'ambiente" -ForegroundColor Cyan
            Write-Host ('═' * 80) -ForegroundColor Green
            Write-Host ""

            $shouldReboot = Start-InterruptibleCountdown 30 "Riavvio sistema"

            if ($shouldReboot) {
                Write-StyledMessage Info "Riavvio..."
                Restart-Computer -Force
            }
            else {
                Write-Host ""
                Write-Host ('═' * 80) -ForegroundColor Yellow
                Write-StyledMessage Warning "RIAVVIO POSTICIPATO"
                Write-Host ('═' * 80) -ForegroundColor Yellow
                Write-Host ""
                Write-StyledMessage Error "Il profilo NON funzionerà finché non riavvii!"
                Write-Host ""
                Write-StyledMessage Info "Dopo il riavvio, verifica con:"
                Write-Host "  oh-my-posh --version" -ForegroundColor Cyan
                Write-Host "  zoxide --version" -ForegroundColor Cyan
                Write-Host ""
                # Salva stato riavvio necessario
                $rebootFlag = "$env:LOCALAPPDATA\WinToolkit\reboot_required.txt"
                "Riavvio necessario per applicare PATH oh-my-posh/zoxide e profilo PowerShell. Eseguito il $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $rebootFlag -Encoding UTF8
                Write-StyledMessage Info "Flag riavvio salvato in: $rebootFlag"
            }
        }
        else {
            Write-StyledMessage Info "Profilo già aggiornato"
        }


        Remove-Item $tempProfile -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host ''
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage Error "Errore installazione: $($_.Exception.Message)"
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
#function WinRepairToolkit {}
#function WinUpdateReset {}
#function WinReinstallStore {}
#function WinBackupDriver {}
#function WinDriverInstall {}
#function OfficeToolkit {}
#function WinCleaner {}
#function SetRustDesk {}
#function VideoDriverInstall {}
#function GamingToolkit {}
#function DisableBitlocker {}

# --- MENU PRINCIPALE ---
$menuStructure = @(
    @{ 'Name' = 'Operazioni Preliminari'; 'Icon' = '🪄'; 'Scripts' = @([pscustomobject]@{Name = 'WinInstallPSProfile'; Description = 'Installa profilo PowerShell'; Action = 'RunFunction' }) },
    @{ 'Name' = 'Windows & Office'; 'Icon' = '🔧'; 'Scripts' = @(
            [pscustomobject]@{Name = 'WinRepairToolkit'; Description = 'Toolkit Riparazione Windows'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinUpdateReset'; Description = 'Reset Windows Update'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinBackupDriver'; Description = 'Backup Driver PC'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinCleaner'; Description = 'Pulizia File Temporanei'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'OfficeToolkit'; Description = 'Office Toolkit'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'DisableBitlocker'; Description = 'Disabilita Bitlocker'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Driver & Gaming'; 'Icon' = '🎮'; 'Scripts' = @(
            [pscustomobject]@{Name = 'VideoDriverInstall'; Description = 'Toolkit Driver Grafici'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'GamingToolkit'; Description = 'Gaming Toolkit'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Supporto'; 'Icon' = '🕹️'; 'Scripts' = @([pscustomobject]@{Name = 'SetRustDesk'; Description = 'Setting RustDesk - MagnetarMan Mode'; Action = 'RunFunction' }) }
)

WinOSCheck

while ($true) {
    Show-Header -SubTitle "Menu Principale"

    # Info Sistema
    $width = $Host.UI.RawUI.BufferSize.Width
    Write-Host ('*' * ($width - 1)) -ForegroundColor Red
    Write-Host (Center-Text "💻  INFORMAZIONI SISTEMA  💻" $width) -ForegroundColor Cyan
    Write-Host ''
    $si = Get-SystemInfo
    if ($si) {
        $editionIcon = if ($si.ProductName -match "Pro") { "🔧" } else { "💻" }
        Write-Host "💻 Edizione: $editionIcon $($si.ProductName)" -ForegroundColor White
        Write-Host "🆔 Versione: " -NoNewline -ForegroundColor White
        Write-Host "Ver. $($si.DisplayVersion) (Build $($si.BuildNumber))" -ForegroundColor Green
        Write-Host "🔑 Architettura: $($si.Architecture)" -ForegroundColor White
        Write-Host "🔧 Nome PC: $($si.ComputerName)" -ForegroundColor White
        Write-Host "🧠 RAM: $($si.TotalRAM) GB" -ForegroundColor White
        Write-Host "💾 Disco: " -NoNewline -ForegroundColor White
        Write-Host "$($si.FreePercentage)% Libero ($($si.FreeDisk) GB)" -ForegroundColor Green
        Write-Host ('*' * ($Host.UI.RawUI.BufferSize.Width - 1)) -ForegroundColor Red
    }
    Write-Host ""

    $allScripts = @(); $idx = 1
    foreach ($cat in $menuStructure) {
        Write-Host "==== $($cat.Icon) $($cat.Name) $($cat.Icon) ====" -ForegroundColor Cyan
        Write-Host ""
        foreach ($s in $cat.Scripts) { 
            $allScripts += $s
            Write-Host "💎 [$idx] $($s.Description)" -ForegroundColor White
            $idx++ 
        }
        Write-Host ""
    }

    Write-Host "==== Uscita ====" -ForegroundColor Red
    Write-Host "❌ [0] Esci dal Toolkit" -ForegroundColor Red
    Write-Host ""
    $c = Read-Host "Scegli un'opzione (es. 1, 3, 5 o 0 per uscire)"
    
    if ($c -eq '0') { Stop-Transcript -ErrorAction SilentlyContinue; break }
    
    if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $allScripts.Count) {
        Invoke-Expression $allScripts[[int]$c - 1].Name
        Write-Host "`nPremi INVIO..." -ForegroundColor Gray; $null = Read-Host
    }
}
