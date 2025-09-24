<#
.SYNOPSIS
    WinToolkit - Strumenti di manutenzione Windows
.DESCRIPTION
    Menu principale per strumenti di gestione e riparazione Windows
.NOTES
  Versione 2.2 (Build 12) - 2025-09-24
#>

param([int]$CountdownSeconds = 10)
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan"
$ErrorActionPreference = 'Stop'

# Setup logging
function Initialize-Logging {
    $script:LogStartTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $script:LogDir = "$env:localappdata\WinToolkit\logs"
    $script:LogPath = "$script:LogDir\WinToolkit_$script:LogStartTime.log"

    try {
        if (-not (Test-Path $script:LogDir)) {
            New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
        }
        Start-Transcript -Path $script:LogPath -Append -Force | Out-Null
        Write-StyledMessage -type 'Info' -text "Log inizializzato: $script:LogPath"
    }
    catch {
        Write-Warning "Impossibile inizializzare il logging: $($_.Exception.Message)"
    }
}

Initialize-Logging

function Write-StyledMessage {
    param([ValidateSet('Success', 'Warning', 'Error', 'Info')][string]$type, [string]$text)
    $icons = @{ Success = '✅'; Warning = '⚠️'; Error = '❌'; Info = '💎' }
    $colors = @{ Success = 'Green'; Warning = 'Yellow'; Error = 'Red'; Info = 'Cyan' }
    Write-Host "$($icons[$type]) $text" -ForegroundColor $colors[$type]
}

function Center-Text {
    param(
        [string]$Text,
        [Parameter(Mandatory = $false)]
        [int]$Width = $Host.UI.RawUI.BufferSize.Width
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return ''
    }

    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))

    return (' ' * $padding + $Text)
}

function Show-Header {
    Clear-Host
    $width = $Host.UI.RawUI.BufferSize.Width
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green

    foreach ($line in $asciiArt) {
        Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
    }

    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    Write-Host ''
}

function Get-ValidatedChoices {
    param(
        [string]$UserChoice,
        [array]$AllScripts
    )

    $choices = $UserChoice -split '[ ,]+' | Where-Object { $_ -ne '' }
    $scriptsToRun = [System.Collections.Generic.List[object]]::new()
    $invalidChoices = [System.Collections.Generic.List[string]]::new()

    foreach ($choice in $choices) {
        if (($choice -match '^\d+$') -and ([int]$choice -ge 1) -and ([int]$choice -le $AllScripts.Count)) {
            $scriptsToRun.Add($AllScripts[[int]$choice - 1])
        }
        else {
            $invalidChoices.Add($choice)
        }
    }

    return @{
        ValidScripts   = $scriptsToRun
        InvalidChoices = $invalidChoices
    }
}

function Invoke-MenuItem {
    param([object]$MenuItem)

    try {
        if ($MenuItem.Action -eq 'RunFile') {
            $scriptPath = Join-Path $PSScriptRoot $MenuItem.Name
            if (Test-Path $scriptPath) {
                & $scriptPath
                return @{ Success = $true }
            }
            else {
                return @{
                    Success      = $false
                    ErrorMessage = "Script non trovato: $($MenuItem.Name)"
                }
            }
        }
        elseif ($MenuItem.Action -eq 'RunFunction') {
            Invoke-Expression $MenuItem.Name
            return @{ Success = $true }
        }
        else {
            return @{
                Success      = $false
                ErrorMessage = "Azione non supportata: $($MenuItem.Action)"
            }
        }
    }
    catch {
        return @{
            Success      = $false
            ErrorMessage = $_.Exception.Message
        }
    }
}

function Get-AllMenuScripts {
    $allScripts = @()
    $scriptIndex = 1

    foreach ($category in $menuStructure) {
        foreach ($script in $category.Scripts) {
            $allScripts += $script
            $scriptIndex++
        }
    }

    return $allScripts
}

function Show-Menu {
    param(
        [array]$MenuStructure,
        [array]$AllScripts
    )

    $scriptIndex = 1

    foreach ($category in $MenuStructure) {
        Write-Host "=== $($category.Icon) $($category.Name) $($category.Icon) ===" -ForegroundColor Cyan
        Write-Host ''

        foreach ($script in $category.Scripts) {
            Write-StyledMessage -type 'Info' -text "[$scriptIndex] $($script.Description)"
            $scriptIndex++
        }
        Write-Host ''
    }
}

function Get-SystemInfo {
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $computerInfo = Get-CimInstance Win32_ComputerSystem
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

        $productName = $osInfo.Caption -replace 'Microsoft ', ''
        $buildNumber = [int]$osInfo.BuildNumber
        $totalRAM = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
        $totalDiskSpace = [Math]::Round($diskInfo.Size / 1GB, 0)
        $freePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)

        # Version mapping
        $versionMap = @{
            26100 = "24H2"; 22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2"
            19045 = "22H2"; 19044 = "21H2"; 19043 = "21H1"; 19042 = "20H2"
            19041 = "2004"; 18363 = "1909"; 18362 = "1903"; 17763 = "1809"
            17134 = "1803"; 16299 = "1709"; 15063 = "1703"; 14393 = "1607"
            10586 = "1511"; 10240 = "1507"
        }

        $windowsVersion = "N/A"
        foreach ($build in ($versionMap.Keys | Sort-Object -Descending)) {
            if ($buildNumber -ge $build) { $windowsVersion = $versionMap[$build]; break }
        }

        # Edition detection
        $windowsEdition = switch -Wildcard ($productName) {
            "*Home*" { "🏠 Home" }
            "*Pro*" { "💼 Professional" }
            "*Enterprise*" { "🏢 Enterprise" }
            "*Education*" { "🎓 Education" }
            "*Server*" { "🖥️ Server" }
            default { "💻 $productName" }
        }

        return @{
            OS             = $osInfo
            Computer       = $computerInfo
            Disk           = $diskInfo
            ProductName    = $productName
            BuildNumber    = $buildNumber
            TotalRAM       = $totalRAM
            TotalDiskSpace = $totalDiskSpace
            FreePercentage = $freePercentage
            WindowsVersion = $windowsVersion
            WindowsEdition = $windowsEdition
        }
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore nel recupero informazioni: $($_.Exception.Message)"
        return $null
    }
}

function Show-SystemInfo {
    param([hashtable]$SystemInfo)

    if (-not $SystemInfo) { return }

    $width = 65
    Write-Host ""
    Write-Host ('*' * $width) -ForegroundColor Red
    Write-Host (Center-Text "🖥️  INFORMAZIONI SISTEMA  🖥️" $width) -ForegroundColor White
    Write-Host ('*' * $width) -ForegroundColor Red
    Write-Host ""

    $info = @(
        @("💻 Edizione:", $SystemInfo.WindowsEdition, 'White'),
        @("📊 Versione:", "Ver. $($SystemInfo.WindowsVersion) (Build $($SystemInfo.BuildNumber))", 'Green'),
        @("🏗️ Architettura:", $SystemInfo.OS.OSArchitecture, 'White'),
        @("🏷️ Nome PC:", $SystemInfo.Computer.Name, 'White'),
        @("🧠 RAM:", "$($SystemInfo.TotalRAM) GB", 'White'),
        @("💾 Disco:", "$($SystemInfo.FreePercentage)% Libero ($($SystemInfo.TotalDiskSpace) GB)", 'Green')
    )

    foreach ($item in $info) {
        Write-Host "  $($item[0])" -ForegroundColor Yellow -NoNewline
        Write-Host " $($item[1])" -ForegroundColor $item[2]
    }

    Write-Host ""
    Write-Host ('*' * $width) -ForegroundColor Red
}

function winver {
    $systemInfo = Get-SystemInfo
    Show-SystemInfo -SystemInfo $systemInfo
}

# Placeholder functions (verranno automaticamente popolate dal compilatore)
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
        'Scripts' = @([pscustomobject]@{ Name = 'WinInstallPSProfile'; Description = 'Installa profilo PowerShell'; Action = 'RunFunction' })
    },
    @{
        'Name' = 'Backup & Tool'; 'Icon' = '📦'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'SetRustDesk'; Description = 'Setting RustDesk - MagnetarMan Mode'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinBackupDriver'; Description = 'Backup Driver PC'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'OfficeToolkit'; Description = 'Office Toolkit'; Action = 'RunFunction' }
        )
    },
    @{
        'Name' = 'Riparazione Windows'; 'Icon' = '🔧'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'WinRepairToolkit'; Description = 'Toolkit Riparazione Windows'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinUpdateReset'; Description = 'Reset Windows Update'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset'; Action = 'RunFunction' }
        )
    },
    @{
        'Name' = 'Driver & Gaming'; 'Icon' = '🎮'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'WinDriverInstall'; Description = 'Toolkit Driver Grafici - Planned V2.3'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'GamingToolkit'; Description = 'Gaming Toolkit - Planned V2.4'; Action = 'RunFunction' }
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
    '       WinToolkit By MagnetarMan',
    '       Version 2.2 (Build 12)'
)

# Main loop
while ($true) {
    Clear-Host
    $width = 65

    # Header
    Show-Header

    winver
    Write-Host ''

    # Build and display menu
    $allScripts = Get-AllMenuScripts
    Show-Menu -MenuStructure $menuStructure -AllScripts $allScripts

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
    $result = Get-ValidatedChoices -UserChoice $userChoice -AllScripts $allScripts
    $scriptsToRun = $result.ValidScripts
    $invalidChoices = $result.InvalidChoices

    # Handle invalid choices
    if ($invalidChoices.Count -gt 0) {
        Write-StyledMessage -type 'Warning' -text "Opzioni non valide ignorate: $($invalidChoices -join ', ')"
        Start-Sleep -Seconds 2
    }

    # Execute valid scripts
    if ($scriptsToRun.Count -gt 0) {
        $executedCount = 0
        $errorCount = 0

        foreach ($selectedItem in $scriptsToRun) {
            Write-Host "`n" + ('-' * ($width / 2))
            Write-StyledMessage -type 'Info' -text "Avvio '$($selectedItem.Description)'..."

            $executionResult = Invoke-MenuItem -MenuItem $selectedItem
            if ($executionResult.Success) {
                $executedCount++
                Write-StyledMessage -type 'Success' -text "Completato: '$($selectedItem.Description)'"
            }
            else {
                $errorCount++
                Write-StyledMessage -type 'Error' -text "Errore in '$($selectedItem.Description)'"
                if ($executionResult.ErrorMessage) {
                    Write-StyledMessage -type 'Error' -text "Dettagli: $($executionResult.ErrorMessage)"
                }
            }
        }

        Write-Host "`nOperazioni completate. Premi un tasto per continuare..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

        # Summary
        if ($errorCount -eq 0) {
            Write-StyledMessage -type 'Success' -text "🎉 Tutte le operazioni completate con successo! ($executedCount/$executedCount)"
        }
        else {
            Write-StyledMessage -type 'Warning' -text "⚠️ $executedCount operazioni completate, $errorCount errori"
        }
    }
    elseif ($invalidChoices.Count -eq $choices.Count) {
        Write-StyledMessage -type 'Error' -text 'Nessuna scelta valida. Riprova.'
        Start-Sleep -Seconds 2
    }
}

# Cleanup function
function Stop-Logging {
    try {
        Stop-Transcript | Out-Null
        Write-StyledMessage -type 'Info' -text "Log salvato: $script:LogPath"
    }
    catch {
        Write-Warning "Errore durante la chiusura del log: $($_.Exception.Message)"
    }
}

# Cleanup on exit
Stop-Logging