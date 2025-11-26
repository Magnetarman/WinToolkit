<#
.SYNOPSIS
    WinToolkit - Suite di manutenzione e riparazione Windows.
.DESCRIPTION
    Framework modulare per tecnici IT. Include strumenti centralizzati per UI, Logging e operazioni di sistema.
.NOTES
    Versione: 2.4.2 (Build 100) - 26/11/2025
    Autore: MagnetarMan
    Licenza: MIT
#>

param([int]$CountdownSeconds = 30)

# --- CONFIGURAZIONE GLOBALE ---
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan"
$ToolkitVersion = "2.4.2 (Build 100)"

# Dizionario Stili Messaggi (Globale)
$Global:MsgStyles = @{
    Success  = @{ Icon = '✅'; Color = 'Green' }
    Warning  = @{ Icon = '⚠️'; Color = 'Yellow' }
    Error    = @{ Icon = '❌'; Color = 'Red' }
    Info     = @{ Icon = '💎'; Color = 'Cyan' }
    Progress = @{ Icon = '🔄'; Color = 'Magenta' }
}

$Global:Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()

# --- FUNZIONI HELPER GLOBALI (CORE) ---

function Write-StyledMessage {
    <#
    .SYNOPSIS
        Scrive un messaggio formattato in console e nel log (se attivo).
    #>
    param(
        [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Progress')][string]$Type,
        [string]$Text
    )
    $style = $Global:MsgStyles[$Type]
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    # Pulisce emoji per il log testuale
    $cleanText = $Text -replace '^[✅⚠️❌💎🔄🗂️📁🖨️📄🗑️💭⏸️▶️💡⏰🎉💻📊]\s*', ''
    
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
    
    if (-not (Test-Path $logdir)) { 
        New-Item -Path $logdir -ItemType Directory -Force | Out-Null 
    }
    
    # Ferma eventuali transcript precedenti per evitare conflitti
    Stop-Transcript -ErrorAction SilentlyContinue
    
    Start-Transcript -Path "$logdir\${ToolName}_$dateTime.log" -Append -Force | Out-Null
}

function Show-ProgressBar {
    <#
    .SYNOPSIS
        Mostra una barra di progresso testuale.
    #>
    param(
        [string]$Activity, 
        [string]$Status, 
        [int]$Percent, 
        [string]$Icon = '⏳', 
        [string]$Spinner = '', 
        [string]$Color = 'Green'
    )
    $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
    $filled = '█' * [math]::Floor($safePercent * 30 / 100)
    $empty = '▒' * (30 - $filled.Length) # Usato carattere ▒ per stile WinRepairToolkit
    
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
            Write-StyledMessage -Type 'Warning' -Text '⏸️ Operazione annullata dall''utente.'
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

function Invoke-DownloadWithProgress {
    <#
    .SYNOPSIS
        Scarica file con barra di progresso e gestione errori.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$DestPath,
        [string]$Description = "File"
    )

    Write-StyledMessage -Type 'Info' -Text "Download in corso: $Description..."
    
    try {
        $webRequest = [System.Net.WebRequest]::Create($Url)
        $webResponse = $webRequest.GetResponse()
        $totalSize = $webResponse.ContentLength
        
        $responseStream = $webResponse.GetResponseStream()
        $targetStream = [System.IO.FileStream]::new($DestPath, [System.IO.FileMode]::Create)
        
        $buffer = New-Object byte[] 10KB
        $downloaded = 0
        $spinnerIndex = 0
        
        while (($count = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $targetStream.Write($buffer, 0, $count)
            $downloaded += $count
            
            if ($totalSize -gt 0) {
                $percent = [Math]::Floor(($downloaded / $totalSize) * 100)
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                
                # Barra di progresso inline
                $filled = '█' * [math]::Floor($percent * 20 / 100)
                $empty = '░' * (20 - $filled.Length)
                Write-Host "`r$spinner 📥 Download $filled$empty $percent%" -NoNewline -ForegroundColor Cyan
            }
        }
        
        Write-Host "" # Newline
        $targetStream.Close()
        $responseStream.Close()
        $webResponse.Close()
        
        if (Test-Path $DestPath) {
            Write-StyledMessage -Type 'Success' -Text "Download completato: $Description"
            return $true
        }
        return $false
    }
    catch {
        Write-Host ""
        Write-StyledMessage -Type 'Error' -Text "Errore download $Description: $($_.Exception.Message)"
        return $false
    }
}

function Get-SystemInfo {
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $computerInfo = Get-CimInstance Win32_ComputerSystem
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

        # Mapping Versioni
        $versionMap = @{
            26100 = "24H2"; 22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2"
            19045 = "22H2"; 19044 = "21H2"; 19043 = "21H1"; 19042 = "20H2"
            19041 = "2004"; 18363 = "1909"; 17763 = "1809"; 17134 = "1803"
            16299 = "1709"; 15063 = "1703"; 14393 = "1607"; 10586 = "1511"; 10240 = "1507"
        }
        
        $build = [int]$osInfo.BuildNumber
        $displayVer = "N/A"
        foreach ($key in ($versionMap.Keys | Sort-Object -Descending)) {
            if ($build -ge $key) { $displayVer = $versionMap[$key]; break }
        }

        return @{
            ProductName    = $osInfo.Caption -replace 'Microsoft ', ''
            BuildNumber    = $build
            DisplayVersion = $displayVer
            Architecture   = $osInfo.OSArchitecture
            ComputerName   = $computerInfo.Name
            TotalRAM       = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
            TotalDisk      = [Math]::Round($diskInfo.Size / 1GB, 0)
            FreePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)
        }
    }
    catch {
        return $null
    }
}

function WinOSCheck {
    Show-Header -SubTitle "Check Preliminare"
    $sysInfo = Get-SystemInfo
    
    if (-not $sysInfo) {
        Write-StyledMessage -Type 'Warning' -Text "Impossibile recuperare info sistema."
        return
    }

    Write-Host "  Sistema rilevato: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($sysInfo.ProductName) ($($sysInfo.DisplayVersion))" -ForegroundColor White
    Write-Host ""
    
    # Logica semplificata per brevità template
    if ($sysInfo.BuildNumber -lt 17763) {
        Write-StyledMessage -Type 'Error' -Text "Sistema Obsoleto (Pre-1809). Rischi di stabilità."
        $choice = Read-Host "  Continuare? [S/N]"
        if ($choice -ne 'S') { exit }
    }
    else {
        Write-StyledMessage -Type 'Success' -Text "Sistema compatibile."
    }
    Start-Sleep -Seconds 2
}

# --- PLACEHOLDER FUNZIONI ---
# Il compilatore inietterà qui il codice dei tool
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
function SearchRepair {}

# --- MENU PRINCIPALE ---
$menuStructure = @(
    @{
        'Name' = 'Operazioni Preliminari'; 'Icon' = '🪄'
        'Scripts' = @([pscustomobject]@{ Name = 'WinInstallPSProfile'; Description = 'Installa profilo PowerShell & Terminal'; Action = 'RunFunction' })
    },
    @{
        'Name' = 'Windows & Office'; 'Icon' = '🔧'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'WinRepairToolkit'; Description = 'Toolkit Riparazione Windows'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinUpdateReset'; Description = 'Reset Windows Update'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinReinstallStore'; Description = 'Ripristino Store & Winget'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinCleaner'; Description = 'Pulizia Profonda Sistema'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'OfficeToolkit'; Description = 'Gestione Office (Install/Fix/Remove)'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'DisableBitlocker'; Description = 'Disabilita BitLocker (C:)'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'SearchRepair'; Description = 'Reset Ricerca Windows'; Action = 'RunFunction' }
        )
    },
    @{
        'Name' = 'Driver & Hardware'; 'Icon' = '🎮'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'VideoDriverInstall'; Description = 'Toolkit Driver Grafici'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinBackupDriver'; Description = 'Backup Completo Driver'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'GamingToolkit'; Description = 'Ottimizzazione Gaming'; Action = 'RunFunction' }
        )
    },
    @{
        'Name' = 'Supporto Remoto'; 'Icon' = '🕹️'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'SetRustDesk'; Description = 'Configurazione RustDesk'; Action = 'RunFunction' }
        )
    }
)

WinOSCheck

while ($true) {
    Show-Header -SubTitle "Menu Principale"
    
    # Info Rapide
    $si = Get-SystemInfo
    if ($si) {
        Write-Host "  💻 $($si.ProductName) | 🧠 RAM: $($si.TotalRAM)GB | 💾 C: $($si.FreePercentage)% Libero" -ForegroundColor DarkGray
        Write-Host ""
    }

    $allScripts = @()
    $idx = 1

    foreach ($cat in $menuStructure) {
        Write-Host "=== $($cat.Icon) $($cat.Name) ===" -ForegroundColor Cyan
        foreach ($script in $cat.Scripts) {
            $allScripts += $script
            Write-Host "  [$idx] $($script.Description)"
            $idx++
        }
        Write-Host ""
    }

    Write-Host "=== Uscita ===" -ForegroundColor Red
    Write-Host "  [0] Esci"
    Write-Host ""

    $choice = Read-Host "  Seleziona opzione"

    if ($choice -eq '0') {
        Write-StyledMessage -Type 'Info' -Text "Chiusura WinToolkit..."
        Stop-Transcript -ErrorAction SilentlyContinue
        break
    }

    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $allScripts.Count) {
        $selected = $allScripts[[int]$choice - 1]
        
        Invoke-Expression $selected.Name
        
        Write-Host "`nPremi INVIO per tornare al menu..." -ForegroundColor Gray
        $null = Read-Host
    }
    else {
        Write-StyledMessage -Type 'Warning' -Text "Scelta non valida."
        Start-Sleep -Seconds 1
    }
}