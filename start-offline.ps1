<#
.SYNOPSIS
    Script di Start per Win Toolkit in modalità Offline.
.DESCRIPTION
    Questo script prepara l'ambiente Win Toolkit scaricando tutte le dipendenze
    necessarie (installatori, icone, ecc.) in una cartella 'start' locale.
    Successivamente, avvia lo script principale 'start.ps1' (che deve essere
    precedentemente posizionato nella cartella 'start') in modalità offline,
    consentendo l'esecuzione del toolkit anche senza connessione internet.
.NOTES
  Versione 2.4.1 Build 3
#>

# Ensure script runs with PowerShell 5.1 or higher for basic compatibility
# This script itself doesn't require PowerShell 7, but the main toolkit might.

function Write-StyledMessage {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug')]
        [string]$type,
        [Parameter(Mandatory = $true)]
        [string]$text
    )

    $colors = @{
        'Info'    = 'Cyan'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
        'Success' = 'Green'
        'Debug'   = 'DarkGray'
    }
    Write-Host $text -ForegroundColor $colors[$type]
}

function Show-Host {
    <#
    .SYNOPSIS
        Mostra informazioni sul sistema host.
    .DESCRIPTION
        Visualizza informazioni dettagliate sul sistema operativo, hardware e configurazione corrente.
    #>

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
        '    Start-Offline By MagnetarMan',
        '       Version 2.4.1 (Build 3)'
    )

    foreach ($line in $asciiArt) {
        if ($line) {
            $padding = [Math]::Max(0, [Math]::Floor(($width - $line.Length) / 2))
            Write-Host (' ' * $padding + $line) -ForegroundColor White
        }
    }

    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    Write-Host ""

    try {
        $osInfo = Get-ComputerInfo
        $cpuInfo = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
        $memoryInfo = Get-WmiObject -Class Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
        $diskInfo = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"

        Write-StyledMessage -type 'Info' -text "🖥️  Sistema Operativo: $($osInfo.OsName)"
        Write-StyledMessage -type 'Info' -text "🏗️  Build: $($osInfo.OsBuildNumber) ($($osInfo.OsArchitecture))"
        Write-StyledMessage -type 'Info' -text "👤 Utente: $($env:USERNAME) su $($env:COMPUTERNAME)"
        Write-StyledMessage -type 'Info' -text "🔧 PowerShell: $($PSVersionTable.PSVersion.ToString())"
        Write-StyledMessage -type 'Info' -text "⚡ CPU: $($cpuInfo.Name.Trim())"
        Write-StyledMessage -type 'Info' -text "💾 RAM: $([math]::Round($memoryInfo.Sum / 1GB, 2)) GB"
        Write-StyledMessage -type 'Info' -text "🗄️  Disco C: $([math]::Round($diskInfo.Size / 1GB, 2)) GB totale, $([math]::Round($diskInfo.FreeSpace / 1GB, 2)) GB liberi"

        # Verifica Winget
        $wingetVersion = $null
        try {
            $wingetOutput = winget --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                $wingetVersion = $wingetOutput.Trim()
            }
        } catch {}

        if ($wingetVersion) {
            Write-StyledMessage -type 'Success' -text "📦 Winget: $wingetVersion"
        } else {
            Write-StyledMessage -type 'Warning' -text "📦 Winget: Non disponibile"
        }

        # Verifica connessione internet
        $internetConnected = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet
        if ($internetConnected) {
            Write-StyledMessage -type 'Success' -text "🌐 Connessione Internet: Disponibile"
        } else {
            Write-StyledMessage -type 'Warning' -text "🌐 Connessione Internet: Non disponibile (modalità offline)"
        }

        Write-Host ""
        Write-StyledMessage -type 'Info' -text "Script Start-Offline Versione 2.4.1 Build 3"
        Write-StyledMessage -type 'Info' -text "By MagnetarMan - Win Toolkit Project"
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore nel recupero informazioni sistema: $($_.Exception.Message)"
    }

    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    Write-Host ""
}

function Invoke-DownloadFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [int]$TimeoutSeconds = 60,
        [int]$MaxRetries = 3
    )

    $FileName = Split-Path $OutputPath -Leaf
    Write-StyledMessage -type 'Info' -text "Download '$FileName' da '$Uri'..."

    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutputPath -UseBasicParsing -TimeoutSec $TimeoutSeconds
            Write-StyledMessage -type 'Success' -text "Download di '$FileName' completato."
            return $true
        }
        catch {
            Write-StyledMessage -type 'Warning' -text "Tentativo $i di $MaxRetries fallito per '$FileName': $($_.Exception.Message)"
            if ($i -lt $MaxRetries) {
                Start-Sleep -Seconds 5
            }
        }
    }
    Write-StyledMessage -type 'Error' -text "Download di '$FileName' fallito dopo $MaxRetries tentativi."
    return $false
}

function Prepare-OfflineResources {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OfflineResourcesDir
    )

    Write-Host ""
    Write-StyledMessage -type 'Info' -text "=========================================================="
    Write-StyledMessage -type 'Info' -text " Preparazione Risorse Offline per Win Toolkit Starter "
    Write-StyledMessage -type 'Info' -text "=========================================================="
    Write-Host ""

    if (-not (Test-Path $OfflineResourcesDir)) {
        New-Item -Path $OfflineResourcesDir -ItemType Directory -Force | Out-Null
        Write-StyledMessage -type 'Info' -text "Creata directory risorse offline: $OfflineResourcesDir"
    }
    else {
        Write-StyledMessage -type 'Info' -text "Directory risorse offline esistente: $OfflineResourcesDir"
    }
    Write-Host ""

    $allDownloadsSuccessful = $true

    # --- Winget Installer ---
    $wingetUrl = "https://aka.ms/getwinget"
    $wingetPath = Join-Path $OfflineResourcesDir "WingetInstaller.msixbundle"
    if (-not (Test-Path $wingetPath)) {
        if (-not (Invoke-DownloadFile -Uri $wingetUrl -OutputPath $wingetPath)) {
            $allDownloadsSuccessful = $false
        }
    } else { Write-StyledMessage -type 'Info' -text "WingetInstaller.msixbundle già presente." }

    # --- Git Installer ---
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.1/Git-2.51.0-64-bit.exe"
    $gitPath = Join-Path $OfflineResourcesDir "Git-2.51.0-64-bit.exe"
    if (-not (Test-Path $gitPath)) {
        if (-not (Invoke-DownloadFile -Uri $gitUrl -OutputPath $gitPath)) {
            $allDownloadsSuccessful = $false
        }
    } else { Write-StyledMessage -type 'Info' -text "Git-2.51.0-64-bit.exe già presente." }

    # --- PowerShell 7 Installer ---
    $ps7Url = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/PowerShell-7.5.2-win-x64.msi"
    $ps7Path = Join-Path $OfflineResourcesDir "PowerShell-7.5.2-win-x64.msi"
    if (-not (Test-Path $ps7Path)) {
        if (-not (Invoke-DownloadFile -Uri $ps7Url -OutputPath $ps7Path)) {
            $allDownloadsSuccessful = $false
        }
    } else { Write-StyledMessage -type 'Info' -text "PowerShell-7.5.2-win-x64.msi già presente." }

    # --- Windows Terminal Installer (latest MSIX bundle from GitHub) ---
    $wtApiPath = "https://api.github.com/repos/microsoft/terminal/releases/latest"
    $wtFileNamePattern = "Microsoft.WindowsTerminal_*.msixbundle"
    $localWtInstaller = Get-ChildItem -Path $OfflineResourcesDir -Filter $wtFileNamePattern -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName -First 1

    if (-not $localWtInstaller) {
        Write-StyledMessage -type 'Info' -text "Ricerca installer Windows Terminal più recente su GitHub..."
        try {
            $release = Invoke-RestMethod -Uri $wtApiPath -UseBasicParsing -TimeoutSec 30
            $asset = $release.assets | Where-Object { $_.name -like "*Win10*msixbundle" } | Select-Object -First 1

            if ($asset) {
                $wtDownloadUrl = $asset.browser_download_url
                $wtPath = Join-Path $OfflineResourcesDir $($asset.name)
                if (-not (Test-Path $wtPath)) {
                    if (-not (Invoke-DownloadFile -Uri $wtDownloadUrl -OutputPath $wtPath)) {
                        $allDownloadsSuccessful = $false
                    }
                } else { Write-StyledMessage -type 'Info' -text "$($asset.name) già presente." }
            }
            else {
                Write-StyledMessage -type 'Error' -text "Nessun asset MSIX bundle trovato per Windows Terminal."
                $allDownloadsSuccessful = $false
            }
        }
        catch {
            Write-StyledMessage -type 'Error' -text "Errore nel recupero release Windows Terminal da GitHub: $($_.Exception.Message)"
            $allDownloadsSuccessful = $false
        }
    } else {
        Write-StyledMessage -type 'Info' -text "Windows Terminal installer ($($localWtInstaller | Split-Path -Leaf)) già presente."
    }

    # --- Win Toolkit Icon ---
    $iconUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/img/WinToolkit.ico"
    $iconPath = Join-Path $OfflineResourcesDir "WinToolkit.ico"
    if (-not (Test-Path $iconPath)) {
        if (-not (Invoke-DownloadFile -Uri $iconUrl -OutputPath $iconPath)) {
            $allDownloadsSuccessful = $false
        }
    } else { Write-StyledMessage -type 'Info' -text "WinToolkit.ico già presente." }

    Write-Host ""
    if ($allDownloadsSuccessful) {
        Write-StyledMessage -type 'Success' -text "Tutte le risorse offline sono state preparate con successo."
    } else {
        Write-StyledMessage -type 'Error' -text "Alcune risorse offline non sono state scaricate. Verificare la connessione e riprovare."
    }
    Write-Host ""

    return $allDownloadsSuccessful
}

# --- Main execution for Start-Offline.ps1 ---
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$OfflineResourcesDir = Join-Path $PSScriptRoot "start"
$mainScriptPath = Join-Path $OfflineResourcesDir "start.ps1"

$Host.UI.RawUI.WindowTitle = "Toolkit Starter Offline by MagnetarMan"

Clear-Host
Show-Host
Write-StyledMessage -type 'Info' -text "Avvio preparazione ambiente offline..."

if (Prepare-OfflineResources -OfflineResourcesDir $OfflineResourcesDir) {
    Write-StyledMessage -type 'Info' -text "Verifica presenza script principale 'start.ps1' in $OfflineResourcesDir..."
    if (-not (Test-Path $mainScriptPath)) {
        Write-StyledMessage -type 'Error' -text "Errore: Lo script 'start.ps1' modificato non è presente in '$OfflineResourcesDir'."
        Write-StyledMessage -type 'Error' -text "Assicurati di aver copiato lo script principale modificato (dopo Step 2) in questa directory."
        Read-Host "Premi Enter per uscire..."
        exit 1
    }

    Write-StyledMessage -type 'Success' -text "Risorse pronte. Avvio dello script principale in modalità offline..."
    Write-Host ""

    # Execute the modified main script, passing the offline directory
    # Use Invoke-Expression (iex) to ensure the script runs in the current session context if preferred,
    # or '&' for a new context. Using '&' is safer for external scripts.
    & $mainScriptPath -OfflineModeDir $OfflineResourcesDir
}
else {
    Write-StyledMessage -type 'Error' -text "La preparazione delle risorse offline è fallita. Impossibile procedere."
    Read-Host "Premi Enter per uscire..."
    exit 1
}