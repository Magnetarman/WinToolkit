<#
.SYNOPSIS
    Un toolkit per eseguire script di manutenzione e gestione di Windows.
.DESCRIPTION
    Questo script funge da menu principale per un insieme di strumenti di manutenzione e gestione di Windows.
    Permette agli utenti di selezionare ed eseguire vari script PowerShell per compiti specifici.
.NOTES
  Versione 2.2 (Build 5) - 2025-09-24
#>

param([int]$CountdownSeconds = 10)

# Configurazione iniziale
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan"
$ErrorActionPreference = 'Stop'

# Setup logging
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\WinToolkit\logs"
try {
    [System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
    Start-Transcript -Path "$logdir\WinToolkit_$dateTime.log" -Append -Force | Out-Null
}
catch { }

function Write-StyledMessage {
    param(
        [ValidateSet('Success', 'Warning', 'Error', 'Info')]
        [string]$Type,
        [string]$Text
    )
    
    $styles = @{
        Success = @{ Color = 'Green' ; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'   ; Icon = '❌' }
        Info    = @{ Color = 'White' ; Icon = '🔎' }
    }
    
    $style = $styles[$Type]
    Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
}

function Center-Text {
    param([string]$Text, [int]$Width = 60)
    
    if ($Text.Length -ge $Width) { return $Text }
    $padding = ' ' * [Math]::Floor(($Width - $Text.Length) / 2)
    return "$padding$Text"
}

function winver {
    try {
        # Raccolta dati ottimizzata con singola query CIM
        $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $computerInfo = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        
        # Elaborazione dati
        $productName = $osInfo.Caption -replace 'Microsoft ', ''
        $buildNumber = [int]$osInfo.BuildNumber
        $totalRAM = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
        $totalDiskSpace = [Math]::Round($diskInfo.Size / 1GB, 0)
        $freePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)
        
        # Rilevazione tipo disco
        $diskType = "HDD"
        try {
            $physicalDisk = Get-CimInstance MSFT_PhysicalDisk -Namespace "Root\Microsoft\Windows\Storage" -ErrorAction SilentlyContinue |
            Where-Object { $_.DeviceID -eq 0 -or $_.MediaType -ne $null } | Select-Object -First 1
            if ($physicalDisk -and $physicalDisk.MediaType -eq 4) { $diskType = "SSD" }
        }
        catch {
            try {
                $diskDrive = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | Where-Object { $_.Index -eq 0 }
                if ($diskDrive.MediaType -like "*SSD*" -or $diskDrive.MediaType -like "*Solid State*") { $diskType = "SSD" }
            }
            catch { $diskType = "Disk" }
        }
        
        # Mappatura build -> versione Windows (hashtable per performance)
        $versionMap = @{
            26100 = "24H2"; 22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2"
            19045 = "22H2"; 19044 = "21H2"; 19043 = "21H1"; 19042 = "20H2"
            19041 = "2004"; 18363 = "1909"; 18362 = "1903"; 17763 = "1809"
            17134 = "1803"; 16299 = "1709"; 15063 = "1703"; 14393 = "1607"
            10586 = "1511"; 10240 = "1507"
        }
        
        $windowsVersion = "N/A"
        foreach ($build in ($versionMap.Keys | Sort-Object -Descending)) {
            if ($buildNumber -ge $build) {
                $windowsVersion = $versionMap[$build]
                break
            }
        }
        
        # Determinazione edizione
        $windowsEdition = switch -Wildcard ($productName) {
            "*Home*" { "🏠 Home" }
            "*Pro*" { "💼 Professional" }
            "*Enterprise*" { "🏢 Enterprise" }
            "*Education*" { "🎓 Education" }
            "*Server*" { "🖥️ Server" }
            default { "💻 $productName" }
        }
        
        # Output formattato
        $width = 65
        Write-Host ""
        Write-Host ('*' * $width) -ForegroundColor Red
        Write-Host (Center-Text "🖥️  INFORMAZIONI SISTEMA  🖥️" $width) -ForegroundColor White
        Write-Host ('*' * $width) -ForegroundColor Red
        Write-Host ""
        
        $info = @(
            @("💻 Edizione:", $windowsEdition, 'White'),
            @("📊 Versione Windows:", "Ver. $windowsVersion Kernel $($osInfo.Version) (Build $buildNumber)", 'Green'),
            @("🏗️ Architettura:", $osInfo.OSArchitecture, 'White'),
            @("🏷️ Nome PC:", $computerInfo.Name, 'White'),
            @("🧠 RAM Totale:", "$totalRAM GB", 'White'),
            @("💾 Disco:", "($diskType) $freePercentage% Libero ($totalDiskSpace GB Totali)", 'Green')
        )
        
        foreach ($item in $info) {
            Write-Host "  $($item[0])" -ForegroundColor Yellow -NoNewline
            Write-Host " $($item[1])" -ForegroundColor $item[2]
        }
        
        Write-Host ""
        Write-Host ('*' * $width) -ForegroundColor Red
    }
    catch {
        Write-StyledMessage 'Error' "Impossibile recuperare le informazioni di sistema: $($_.Exception.Message)"
    }
}

# Placeholder functions
function WinInstallPSProfile {}
function WinRepairToolkit {}
function SetRustDesk {}
function WinUpdateReset {}
function WinReinstallStore {}
function WinDriverInstall {}
function WinBackupDriver {}
function OfficeToolkit {}
function GamingToolkit {}

# Menu structure
$menuStructure = @(
    @{
        'Name' = 'Operazioni Preliminari'; 'Icon' = '🪄'
        'Scripts' = @([pscustomobject]@{ Name = 'WinInstallPSProfile'; Description = 'Installa il profilo PowerShell.'; Action = 'RunFunction' })
    },
    @{
        'Name' = 'Backup & Tool'; 'Icon' = '📦'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'SetRustDesk'; Description = 'Setting RustDesk - ⚠️ MagnetarMan Mode. ⚠️'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinBackupDriver'; Description = 'Backup Driver PC. - Planned V2.2'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'OfficeToolkit'; Description = 'Office Toolkit.'; Action = 'RunFunction' }
        )
    },
    @{
        'Name' = 'Riparazione Windows'; 'Icon' = '🔧'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'WinRepairToolkit'; Description = 'Toolkit Riparazione Windows.'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinUpdateReset'; Description = 'Reset di Windows Update.'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset.'; Action = 'RunFunction' }
        )
    },
    @{
        'Name' = 'Driver & Gaming'; 'Icon' = '🎮'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'WinDriverInstall'; Description = 'Toolkit Driver Grafici. - Planned V2.3'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'GamingToolkit'; Description = 'Gaming Toolkit. - Planned V2.4'; Action = 'RunFunction' }
        )
    }
)

# ASCII Art
$asciiArt = @(
    '      __        __  _  _   _ ',
    '      \ \      / / | || \ | |',
    '       \ \ /\ / /  | ||  \| |',
    '        \ V  V /   | || |\  |',
    '         \_/\_/    |_||_| \_|',
    '',
    '       Toolkit By MagnetarMan',
    '       Version 2.2 (Build 5)'
)

# Main loop
while ($true) {
    Clear-Host
    $width = 65
    
    # Header
    Write-Host ('═' * $width) -ForegroundColor Green
    foreach ($line in $asciiArt) {
        Write-Host (Center-Text $line $width) -ForegroundColor White
    }
    Write-Host ('═' * $width) -ForegroundColor Green
    
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
            Write-StyledMessage 'Info' "[$scriptIndex] $($script.Description)"
            $scriptIndex++
        }
        Write-Host ''
    }
    
    # Exit section
    Write-Host "=== Uscita ===" -ForegroundColor Red
    Write-Host ''
    Write-StyledMessage 'Error' '[0] Esci dal Toolkit'
    Write-Host ''
    
    # Handle user choice
    $userChoice = Read-Host "Quale opzione vuoi eseguire? (es. 1, 3, 5 o 0 per uscire)"

    if ($userChoice -eq '0') {
        Write-StyledMessage 'Warning' 'In caso di problemi, contatta MagnetarMan su Github => Github.com/Magnetarman.'
        Write-StyledMessage 'Success' 'Grazie per aver usato il toolkit. Chiusura in corso...'
        Start-Sleep -Seconds 5
        break
    }

    # Separa gli input usando spazi o virgole come delimitatori e rimuove eventuali spazi vuoti
    $choices = $userChoice -split '[ ,]+' | Where-Object { $_ -ne '' }
    $scriptsToRun = [System.Collections.Generic.List[object]]::new()
    $invalidChoices = [System.Collections.Generic.List[string]]::new()

    # Valida ogni scelta e la aggiunge alla lista di esecuzione
    foreach ($choice in $choices) {
        if (($choice -match '^\d+$') -and ([int]$choice -ge 1) -and ([int]$choice -le $allScripts.Count)) {
            $scriptsToRun.Add($allScripts[[int]$choice - 1])
        }
        else {
            $invalidChoices.Add($choice)
        }
    }

    # Se ci sono scelte non valide, avvisa l'utente
    if ($invalidChoices.Count -gt 0) {
        Write-StyledMessage 'Warning' "Le seguenti opzioni non sono valide e verranno ignorate: $($invalidChoices -join ', ')"
        Start-Sleep -Seconds 2
    }

    # Esegui gli script validi in sequenza
    if ($scriptsToRun.Count -gt 0) {
        foreach ($selectedItem in $scriptsToRun) {
            Write-Host "`n" + ('-' * ($width / 2))
            Write-StyledMessage 'Info' "Avvio di '$($selectedItem.Description)'..."
        
            try {
                if ($selectedItem.Action -eq 'RunFile') {
                    $scriptPath = Join-Path $PSScriptRoot $selectedItem.Name
                    if (Test-Path $scriptPath) { & $scriptPath }
                    else { Write-StyledMessage 'Error' "Script '$($selectedItem.Name)' non trovato." }
                }
                elseif ($selectedItem.Action -eq 'RunFunction') {
                    Invoke-Expression $selectedItem.Name
                }
            }
            catch {
                Write-StyledMessage 'Error' "Errore durante l'esecuzione di '$($selectedItem.Description)'."
                Write-StyledMessage 'Error' "Dettagli: $($_.Exception.Message)"
            }
            Write-StyledMessage 'Success' "Esecuzione di '$($selectedItem.Description)' completata."
        }
    
        Write-Host "`nTutte le operazioni selezionate sono state completate."
        Write-Host "Premi un tasto per tornare al menu principale..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    elseif ($invalidChoices.Count -eq $choices.Count) {
        # Questo blocco viene eseguito se sono state inserite SOLO scelte non valide
        Write-StyledMessage 'Error' 'Nessuna scelta valida inserita. Riprova.'
        Start-Sleep -Seconds 3
    }
}