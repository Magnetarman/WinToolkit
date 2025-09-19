<#
.SYNOPSIS
    Un toolkit per eseguire script di manutenzione e gestione di Windows.
.DESCRIPTION
    Questo script funge da menu principale per un insieme di strumenti di manutenzione e gestione di Windows.
    Permette agli utenti di selezionare ed eseguire vari script PowerShell per compiti specifici.
.NOTES
  Versione 2.1 (Build 14) - 2025-09-19
#>

param([int]$CountdownSeconds = 10)
# Imposta il titolo della finestra di PowerShell per un'identificazione immediata.
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan"

# Imposta una gestione degli errori più rigorosa per lo script.
# 'Stop' interrompe l'esecuzione in caso di errore, permettendo una gestione controllata tramite try/catch.
$ErrorActionPreference = 'Stop'

# Creazione directory di log e avvio trascrizione
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\WinToolkit\logs"
try {
    [System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
    Start-Transcript -Path "$logdir\WinToolkit_$dateTime.log" -Append -Force | Out-Null
}
catch {
    # Gestione errori silenziosa per compatibilità
}

function Write-StyledMessage {
    <#
    .SYNOPSIS
        Scrive un messaggio formattato sulla console con icone e colori.
    .PARAMETER Type
        Il tipo di messaggio (Success, Warning, Error, Info).
    .PARAMETER Text
        Il testo del messaggio da visualizzare.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Warning', 'Error', 'Info')]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    # Definisce gli stili per ogni tipo di messaggio. L'uso degli emoji migliora la leggibilità.
    $styles = @{
        Success = @{ Color = 'Green' ; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'   ; Icon = '❌' }
        Info    = @{ Color = 'White'  ; Icon = '💎' }
    }

    $style = $styles[$Type]
    Write-Host "$($style.Icon) $($Text)" -ForegroundColor $style.Color
}

function Center-Text {
    <#
    .SYNOPSIS
        Centra una stringa di testo data una larghezza specifica.
    .PARAMETER Text
        Il testo da centrare.
    .PARAMETER Width
        La larghezza totale del contenitore.
    #>
    param(
        [string]$Text,
        [int]$Width = 60
    )

    if ($Text.Length -ge $Width) { return $Text }

    $padding = ' ' * [Math]::Floor(($Width - $Text.Length) / 2)
    return "$($padding)$($Text)"
}

function winver {
    <#
    .SYNOPSIS
        Visualizza informazioni dettagliate sulla versione di Windows in modo elegante.
    .DESCRIPTION
        Raccoglie e visualizza le informazioni sulla versione di Windows, build e edizione
        utilizzando lo stile grafico coerente con il resto del toolkit.
    #>
    try {
        # Raccolta informazioni di sistema ottimizzata
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $diskInfo = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        
        # Estrazione delle informazioni principali
        $productName = $osInfo.Caption -replace 'Microsoft ', ''
        $version = $osInfo.Version
        $buildNumber = $osInfo.BuildNumber
        $architecture = $osInfo.OSArchitecture
        $computerName = $computerInfo.Name
        $totalRAM = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
        
        # Informazioni disco C:
        $totalDiskSpace = [Math]::Round($diskInfo.Size / 1GB, 0)
        $freeDiskSpace = [Math]::Round($diskInfo.FreeSpace / 1GB, 0)
        $freePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)
        
        # Rilevazione tipo di disco (SSD/HDD)
        try {
            $physicalDisk = Get-CimInstance -ClassName MSFT_PhysicalDisk -Namespace "Root\Microsoft\Windows\Storage" -ErrorAction Stop |
            Where-Object { $_.DeviceID -eq 0 -or $_.MediaType -ne $null } | Select-Object -First 1
            $diskType = if ($physicalDisk -and $physicalDisk.MediaType -eq 4) { "SSD" } else { "HDD" }
        }
        catch {
            # Fallback: prova a rilevare tramite velocità di rotazione
            try {
                $diskDrive = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop | Where-Object { $_.Index -eq 0 }
                $diskType = if ($diskDrive.MediaType -like "*SSD*" -or $diskDrive.MediaType -like "*Solid State*") { "SSD" } else { "HDD" }
            }
            catch {
                $diskType = "Disk"
            }
        }
        
        # Mappatura delle build alla versione di Windows (23H2, 24H2, ecc.)
        $windowsVersion = if ([int]$buildNumber -ge 26100) {
            "24H2"      # Windows 11 24H2
        }
        elseif ([int]$buildNumber -ge 22631) {
            "23H2"      # Windows 11 23H2
        }
        elseif ([int]$buildNumber -ge 22621) {
            "22H2"      # Windows 11 22H2
        }
        elseif ([int]$buildNumber -ge 22000) {
            "21H2"      # Windows 11 21H2
        }
        elseif ([int]$buildNumber -ge 19045) {
            "22H2"      # Windows 10 22H2
        }
        elseif ([int]$buildNumber -ge 19044) {
            "21H2"      # Windows 10 21H2
        }
        elseif ([int]$buildNumber -ge 19043) {
            "21H1"      # Windows 10 21H1
        }
        elseif ([int]$buildNumber -ge 19042) {
            "20H2"      # Windows 10 20H2
        }
        elseif ([int]$buildNumber -ge 19041) {
            "2004"      # Windows 10 2004
        }
        elseif ([int]$buildNumber -ge 18363) {
            "1909"      # Windows 10 1909
        }
        elseif ([int]$buildNumber -ge 18362) {
            "1903"      # Windows 10 1903
        }
        elseif ([int]$buildNumber -ge 17763) {
            "1809"      # Windows 10 1809
        }
        elseif ([int]$buildNumber -ge 17134) {
            "1803"      # Windows 10 1803
        }
        elseif ([int]$buildNumber -ge 16299) {
            "1709"      # Windows 10 1709
        }
        elseif ([int]$buildNumber -ge 15063) {
            "1703"      # Windows 10 1703
        }
        elseif ([int]$buildNumber -ge 14393) {
            "1607"      # Windows 10 1607
        }
        elseif ([int]$buildNumber -ge 10586) {
            "1511"      # Windows 10 1511
        }
        elseif ([int]$buildNumber -ge 10240) {
            "1507"      # Windows 10 1507
        }
        else {
            "N/A"
        }
        
        # Determinazione dell'edizione Windows per una visualizzazione più pulita
        $windowsEdition = switch -Wildcard ($productName) {
            "*Home*" { "🏠 Home" }
            "*Pro*" { "💼 Professional" }
            "*Enterprise*" { "🏢 Enterprise" }
            "*Education*" { "🎓 Education" }
            "*Server*" { "🖥️ Server" }
            default { "💻 $productName" }
        }
        
        # Visualizzazione delle informazioni con stile coerente al toolkit
        $width = 65
        Write-Host ""
        Write-Host ('*' * $width) -ForegroundColor Red
        Write-Host (Center-Text -Text "🖥️  INFORMAZIONI SISTEMA  🖥️" -Width $width) -ForegroundColor White
        Write-Host ('*' * $width) -ForegroundColor Red
        
        Write-Host ""
        Write-Host "  💻 Edizione:" -ForegroundColor Yellow -NoNewline
        Write-Host " $windowsEdition" -ForegroundColor White
        
        Write-Host "  📊 Versione Windows:" -ForegroundColor Yellow -NoNewline  
        Write-Host " Ver. $windowsVersion Kernel $version (Build $buildNumber)" -ForegroundColor Green
        
        Write-Host "  🏗️ Architettura:" -ForegroundColor Yellow -NoNewline
        Write-Host " $architecture" -ForegroundColor White
        
        Write-Host "  🏷️ Nome PC:" -ForegroundColor Yellow -NoNewline
        Write-Host " $computerName" -ForegroundColor White
        
        Write-Host "  🧠 RAM Totale:" -ForegroundColor Yellow -NoNewline
        Write-Host " $totalRAM GB" -ForegroundColor White
        
        Write-Host "  💾 Disco:" -ForegroundColor Yellow -NoNewline
        Write-Host " ($diskType) $freePercentage% Libero ($totalDiskSpace GB Totali)" -ForegroundColor Green
        
        Write-Host ""
        Write-Host ('*' * $width) -ForegroundColor Red
    }
    catch {
        Write-StyledMessage 'Error' "Impossibile recuperare le informazioni di sistema: $($_.Exception.Message)"
    }
}
# Installazione del profilo PowerShell
function WinInstallPSProfile {}

# Riparazione di Windows
function WinRepairToolkit {}

# Reset di RustDesk
function ResetRustDesk {}

# Reset di Windows Update
function WinUpdateReset {}

# Reinstallazione del Microsoft Store & Winget
function WinReinstallStore {}

# Installazione dei driver di Windows
function WinDriverInstall {}

# Backup dei driver di Windows
function WinBackupDriver {}

# Toolkit per Microsoft Office
function OfficeToolkit {}

# Toolkit per il gaming
function GamingToolkit {}

# Ciclo principale del programma: mostra il menu e attende una scelta.
while ($true) {
    Clear-Host
    $width = 65
    Write-Host ('═' * $width) -ForegroundColor Green
    $asciiArt = @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        '       Toolkit By MagnetarMan',
        '       Version 2.1 (Build 14)'
    )
    foreach ($line in $asciiArt) {
        Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
    }
    Write-Host ('═' * $width) -ForegroundColor Green
    
    # Esecuzione automatica della funzione winver per mostrare sempre le info di sistema
    winver
    
    Write-Host ''

    # --- Definizione e visualizzazione del menu organizzato per categorie ---
    $menuStructure = @(
        @{
            'Name'    = 'Operazioni Preliminari'
            'Icon'    = '🪄'
            'Scripts' = @(
                [pscustomobject]@{ Name = 'WinInstallPSProfile'; Description = 'Installa il profilo PowerShell.'; Action = 'RunFunction' }
            )
        },
        @{
            'Name'    = 'Backup & Tool'
            'Icon'    = '📦'
            'Scripts' = @(
                [pscustomobject]@{ Name = 'ResetRustDesk'; Description = 'Reset Rust Desk. - Planned V2.2'; Action = 'RunFunction' }
                [pscustomobject]@{ Name = 'WinBackupDriver'; Description = 'Backup Driver PC. - Planned V2.2'; Action = 'RunFunction' }
                [pscustomobject]@{ Name = 'OfficeToolkit'; Description = 'Office Toolkit. - Planned V2.1'; Action = 'RunFunction' }
            )
        },
        @{
            'Name'    = 'Riparazione Windows'
            'Icon'    = '🔧'
            'Scripts' = @(
                [pscustomobject]@{ Name = 'WinRepairToolkit'; Description = 'Toolkit Riparazione Windows.'; Action = 'RunFunction' }
                [pscustomobject]@{ Name = 'WinUpdateReset'; Description = 'Reset di Windows Update.'; Action = 'RunFunction' }
                [pscustomobject]@{ Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset. - Planned V2.2'; Action = 'RunFunction' }
            )
        },
        @{
            'Name'    = 'Driver & Gaming'
            'Icon'    = '🎮'
            'Scripts' = @(
                [pscustomobject]@{ Name = 'WinDriverInstall'; Description = 'Toolkit Driver Grafici. - Planned V2.3'; Action = 'RunFunction' }
                [pscustomobject]@{ Name = 'GamingToolkit'; Description = 'Gaming Toolkit. - Planned V2.4'; Action = 'RunFunction' }
            )
        }
    )

    # Aggiorna anche il ciclo foreach per questa struttura:
    $allScripts = @()
    $scriptIndex = 1

    foreach ($category in $menuStructure) {
        # Visualizzazione del titolo della categoria
        $categoryTitle = "=== $($category.Icon) $($category.Name) $($category.Icon) ==="
        Write-Host $categoryTitle -ForegroundColor DarkYellow
        Write-Host ''
    
        # Visualizzazione degli script della categoria
        foreach ($script in $category.Scripts) {
            $allScripts += $script
            Write-StyledMessage 'Info' "[$scriptIndex] $($script.Description)"
            $scriptIndex++
        }
    
        Write-Host '' # Spazio tra le categorie
    }

    # Sezione di uscita
    Write-Host "=== Uscita ===" -ForegroundColor Red
    Write-Host ''
    Write-StyledMessage 'Error' '[0] Esci dal Toolkit'
    Write-Host ''

    # --- Logica di gestione della scelta utente ---
    $userChoice = Read-Host "Quale opzione vuoi eseguire? (0-$($allScripts.Count))"

    if ($userChoice -eq '0') {
        Write-StyledMessage 'Warning' 'In caso di problemi, contatta MagnetarMan su Github => Github.com/Magnetarman.'
        Write-StyledMessage 'Success' 'Grazie per aver usato il toolkit. Chiusura in corso...'
        Start-Sleep -Seconds 5
        break # Esce dal ciclo while ($true) e termina lo script.
    }

    # Verifica se l'input è un numero valido e rientra nel range delle opzioni.
    if (($userChoice -match '^\d+$') -and ([int]$userChoice -ge 1) -and ([int]$userChoice -le $allScripts.Count)) {
        $selectedIndex = [int]$userChoice - 1
        $selectedItem = $allScripts[$selectedIndex]

        Write-StyledMessage 'Info' "Avvio di '$($selectedItem.Description)'..."
        try {
            if ($selectedItem.Action -eq 'RunFile') {
                $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath $selectedItem.Name
                if (Test-Path $scriptPath) {
                    & $scriptPath
                }
                else {
                    Write-StyledMessage 'Error' "Script '$($selectedItem.Name)' non trovato nella directory '$($PSScriptRoot)'."
                }
            }
            elseif ($selectedItem.Action -eq 'RunFunction') {
                Invoke-Expression "$($selectedItem.Name)"
            }
        }
        catch {
            Write-StyledMessage 'Error' "Si è verificato un errore durante l'esecuzione dell'opzione selezionata."
            Write-StyledMessage 'Error' "Dettagli: $($_.Exception.Message)"
        }
    
        # Pausa prima di tornare al menu principale
        Write-Host "`nPremi un tasto per tornare al menu principale..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    else {
        Write-StyledMessage 'Error' 'Scelta non valida. Riprova.'
        Start-Sleep -Seconds 3
    }
}