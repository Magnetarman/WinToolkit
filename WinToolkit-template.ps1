<#
.SYNOPSIS
    WinToolkit - Suite di manutenzione Windows
.DESCRIPTION
    Framework modulare unificato.
    Contiene le funzioni core (UI, Log, Info) e il menu principale.
.NOTES
    Versione: 2.5.0 - 04/01/2026
    Autore: MagnetarMan
#>

param([int]$CountdownSeconds = 30)

# --- CONFIGURAZIONE GLOBALE ---
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan"
$ToolkitVersion = "2.5.0 (Build 168)"


# Setup Variabili Globali UI
$Global:Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
$Global:MsgStyles = @{
    Success  = @{ Icon = '✅'; Color = 'Green' }
    Warning  = @{ Icon = '⚠️'; Color = 'Yellow' }
    Error    = @{ Icon = '❌'; Color = 'Red' }
    Info     = @{ Icon = '💎'; Color = 'Cyan' }
    Progress = @{ Icon = '🔄'; Color = 'Magenta' }
}

# --- FUNZIONI HELPER CONDIVISE ---

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

function Invoke-WithSpinner {
    <#
    .SYNOPSIS
        Esegue un'azione con animazione spinner automatica.

    .DESCRIPTION
        Funzione di ordine superiore che gestisce automaticamente l'animazione
        dello spinner per operazioni asincrone, processi, job o timer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [int]$UpdateInterval = 500,

        [Parameter(Mandatory = $false)]
        [switch]$Process,

        [Parameter(Mandatory = $false)]
        [switch]$Job,

        [Parameter(Mandatory = $false)]
        [switch]$Timer,

        [Parameter(Mandatory = $false)]
        [scriptblock]$PercentUpdate
    )

    $startTime = Get-Date
    $spinnerIndex = 0
    $percent = 0

    try {
        # Esegue l'azione iniziale
        $result = & $Action

        # Determina il tipo di monitoraggio
        if ($Timer) {
            # Timer/Countdown
            $totalSeconds = $TimeoutSeconds
            for ($i = $totalSeconds; $i -gt 0; $i--) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                $elapsed = $totalSeconds - $i

                if ($PercentUpdate) {
                    $percent = & $PercentUpdate
                } else {
                    $percent = [math]::Round((($totalSeconds - $i) / $totalSeconds) * 100)
                }

                Write-Host "`r$spinner ⏳ $Activity - $i secondi..." -NoNewline -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
            Write-Host ''
            return $true
        }
        elseif ($Process -and $result -and $result.GetType().Name -eq 'Process') {
            # Monitoraggio processo
            while (-not $result.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

                if ($PercentUpdate) {
                    $percent = & $PercentUpdate
                } elseif ($percent -lt 90) {
                    $percent += Get-Random -Minimum 1 -Maximum 3
                }

                Show-ProgressBar -Activity $Activity -Status "Esecuzione in corso... ($elapsed secondi)" -Percent $percent -Icon '⏳' -Spinner $spinner
                Start-Sleep -Milliseconds $UpdateInterval
                $result.Refresh()
            }

            if (-not $result.HasExited) {
                Write-StyledMessage -Type 'Warning' -Text "Timeout raggiunto dopo $TimeoutSeconds secondi, terminazione processo..."
                $result.Kill()
                Start-Sleep -Seconds 2
                return @{ Success = $false; TimedOut = $true; ExitCode = -1 }
            }

            Show-ProgressBar -Activity $Activity -Status 'Completato' -Percent 100 -Icon '✅'
            return @{ Success = $true; TimedOut = $false; ExitCode = $result.ExitCode }
        }
        elseif ($Job -and $result -and $result.GetType().Name -eq 'Job') {
            # Monitoraggio job PowerShell
            while ($result.State -eq 'Running') {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                Write-Host "`r$spinner $Activity..." -NoNewline -ForegroundColor Yellow
                Start-Sleep -Milliseconds $UpdateInterval
            }

            $jobResult = Receive-Job $result -Wait
            Write-Host ''
            return $jobResult
        }
        else {
            # Operazione sincrona semplice
            Start-Sleep -Seconds $TimeoutSeconds
            return $result
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante $Activity`: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
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
    catch { return "Disattivato" }
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
function WinInstallPSProfile {}
function WinRepairToolkit {}
function WinUpdateReset {}
function WinReinstallStore {}
function WinBackupDriver {}
function WinDriverInstall {}
function OfficeToolkit {}
function WinCleaner {}
function SetRustDesk {}
function VideoDriverInstall {}
function GamingToolkit {}
function DisableBitlocker {}
function WinExportLog {}

# --- MENU PRINCIPALE ---
$menuStructure = @(
    @{ 'Name' = 'Operazioni Preliminari'; 'Icon' = '🪄'; 'Scripts' = @([pscustomobject]@{Name = 'WinInstallPSProfile'; Description = 'Installa profilo PowerShell'; Action = 'RunFunction' }) },
    @{ 'Name' = 'Windows & Office'; 'Icon' = '🔧'; 'Scripts' = @(
            [pscustomobject]@{Name = 'WinRepairToolkit'; Description = 'Riparazione Windows'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinUpdateReset'; Description = 'Reset Windows Update'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinBackupDriver'; Description = 'Backup Driver PC'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinCleaner'; Description = 'Pulizia File Temporanei'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'OfficeToolkit'; Description = 'Office Toolkit'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'DisableBitlocker'; Description = 'Disabilita Bitlocker'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Driver & Gaming'; 'Icon' = '🎮'; 'Scripts' = @(
            [pscustomobject]@{Name = 'VideoDriverInstall'; Description = 'Driver Video Toolkit'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'GamingToolkit'; Description = 'Gaming Toolkit'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Supporto'; 'Icon' = '🕹️'; 'Scripts' = @(
        [pscustomobject]@{Name = 'SetRustDesk'; Description = 'Setting RustDesk - MagnetarMan Mode'; Action = 'RunFunction' }
        [pscustomobject]@{Name = 'WinExportLog'; Description = 'Esporta Log WinToolkit'; Action = 'RunFunction' }
        )
    }
)

WinOSCheck

while ($true) {
    Show-Header -SubTitle "Menu Principale"

    # Info Sistema
    $width = $Host.UI.RawUI.BufferSize.Width
    Write-Host ('*' * 50) -ForegroundColor Red
    Write-Host ''
    Write-Host "==== 💻 INFORMAZIONI DI SISTEMA 💻 ====" -ForegroundColor Cyan
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

        # Logica per la formattazione dello spazio disco libero
        $diskFreeGB = $si.FreeDisk
        $displayString = "$($si.FreePercentage)% Libero ($($diskFreeGB) GB)"

        # Determina il colore in base allo spazio libero
        $diskColor = "Green" # Default per > 80 GB
        if ($diskFreeGB -lt 50) {
            $diskColor = "Red"
        }
        elseif ($diskFreeGB -ge 50 -and $diskFreeGB -le 80) {
            $diskColor = "Yellow"
        }

        # Output delle informazioni sul disco con colore appropriato
        Write-Host $displayString -ForegroundColor $diskColor -NoNewline
        Write-Host "" # Per una nuova riga dopo le informazioni sul disco
        $blStatus = CheckBitlocker
        $blColor = 'Red'
        if ($blStatus -match 'Disattivato|Non configurato|Off') { $blColor = 'Green' }
        Write-Host "🔒 Stato Bitlocker: " -NoNewline -ForegroundColor White
        Write-Host "$blStatus" -ForegroundColor $blColor
        Write-Host ('*' * 50) -ForegroundColor Red
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
    Write-Host ""
    Write-Host "❌ [0] Esci dal Toolkit" -ForegroundColor Red
    Write-Host ""
    $c = Read-Host "Digita il numero dell'operazione da eseguire e premi INVIO"

    if ($c -eq '0') {
        Write-StyledMessage -type 'Warning' -text 'Per supporto: Github.com/Magnetarman'
        Write-StyledMessage -type 'Success' -text 'Chiusura in corso...'
        if ($Global:Transcript -or $Transcript) {
            Stop-Transcript -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 3
        break
    }

    if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $allScripts.Count) {
        Invoke-Expression $allScripts[[int]$c - 1].Name
        Write-Host "`nPremi INVIO..." -ForegroundColor Gray; $null = Read-Host
    }
}
