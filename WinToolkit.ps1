<#
.SYNOPSIS
    WinToolkit - Suite di manutenzione Windows
.DESCRIPTION
    Framework modulare unificato.
    Contiene le funzioni core (UI, Log, Info) e il menu principale.
.NOTES
    Autore: MagnetarMan
#>

param([int]$CountdownSeconds = 30, [switch]$ImportOnly)

# --- CONFIGURAZIONE GLOBALE ---
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan"
$ToolkitVersion = "2.5.2 (Build 8)"

# --- CONFIGURAZIONE CENTRALIZZATA ---
$AppConfig = @{
    URLs     = @{
        # GitHub Asset URLs
        GitHubAssetBaseUrl    = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/main/asset/"
        GitHubAssetDevBaseUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/"

        # Office
        OfficeSetup           = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Setup.exe"
        OfficeBasicConfig     = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Basic.xml"
        SaRAInstaller         = "https://aka.ms/SaRA_EnterpriseVersionFiles"

        # Video Driver
        AMDInstaller          = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/main/asset/AMD-Autodetect.exe"
        NVCleanstall          = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/main/asset/NVCleanstall_1.19.0.exe"
        DDUZip                = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/main/asset/DDU.zip"

        # Gaming
        DirectXWebSetup       = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/main/asset/dxwebsetup.exe"
        BattleNetInstaller    = "https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"

        # 7-Zip
        SevenZipOfficial      = "https://www.7-zip.org/a/7zr.exe"

        # Store
        WingetInstaller       = "https://aka.ms/getwinget"
    }
    Paths    = @{
        # Base paths
        Root               = "$env:LOCALAPPDATA\WinToolkit"
        Logs               = "$env:LOCALAPPDATA\WinToolkit\logs"
        Temp               = "$env:TEMP\WinToolkit"
        Drivers            = "$env:LOCALAPPDATA\WinToolkit\Drivers"
        OfficeTemp         = "$env:LOCALAPPDATA\WinToolkit\Office"
        DriverBackupTemp   = "$env:TEMP\DriverBackup_Temp"
        DriverBackupLogs   = "$env:LOCALAPPDATA\WinToolkit\logs"
        GamingDirectX      = "$env:LOCALAPPDATA\WinToolkit\Directx"
        GamingDirectXSetup = "$env:LOCALAPPDATA\WinToolkit\Directx\dxwebsetup.exe"
        BattleNetSetup     = "$env:TEMP\Battle.net-Setup.exe"
        Desktop            = [Environment]::GetFolderPath('Desktop')
        TempFolder         = $env:TEMP
    }
    Registry = @{
        # Windows Update
        WindowsUpdatePolicies = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ExcludeWUDrivers      = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\ExcludeWUDriversInQualityUpdate"

        # Office Telemetry
        OfficeTelemetry       = "HKLM:\SOFTWARE\Microsoft\Office\Common\ClientTelemetry"
        DisableTelemetry      = "HKLM:\SOFTWARE\Microsoft\Office\Common\ClientTelemetry\DisableTelemetry"

        # Office Feedback
        OfficeFeedback        = "HKLM:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback"
        OnBootNotify          = "HKLM:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback\OnBootNotify"

        # BitLocker
        BitLockerStatus       = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"

        # Focus Assist
        FocusAssist           = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
        NoGlobalToasts        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\NOC_GLOBAL_SETTING_TOASTS_ENABLED"

        # Startup Programs
        StartupRun            = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

        # Windows Terminal
        WindowsTerminal       = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

    }
}


# Setup Variabili Globali UI
$Global:Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
$Global:MsgStyles = @{
    Success  = @{ Icon = '✅'; Color = 'Green' }
    Warning  = @{ Icon = '⚠️'; Color = 'Yellow' }
    Error    = @{ Icon = '❌'; Color = 'Red' }
    Info     = @{ Icon = '💎'; Color = 'Cyan' }
    Progress = @{ Icon = '🔄'; Color = 'Magenta' }
}

# --- VARIABILI GLOBALI PER ESECUZIONE MULTI-SCRIPT ---
$Global:ExecutionLog = @()
$Global:NeedsFinalReboot = $false

# --- FUNZIONI HELPER CONDIVISE ---

function Clear-ProgressLine {
    if ($Host.Name -eq 'ConsoleHost') {
        try {
            $width = $Host.UI.RawUI.WindowSize.Width - 1
            Write-Host "`r$(' ' * $width)" -NoNewline
            Write-Host "`r" -NoNewline
        }
        catch {
            Write-Host "`r                                                                                `r" -NoNewline
        }
    }
}

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

    # Skip header display if running in GUI mode to prevent console UI issues
    if ($Global:GuiSessionActive) {
        return
    }

    Clear-Host
    $width = $Host.UI.RawUI.BufferSize.Width
    $asciiArt = @(
        '      __        __  _   _   _ ',
        '      \ \      / / | | | \ | |',
        '       \ \ /\ / /  | | |  \| |',
        '        \ V  V /   | | | |\  |',
        '         \_/\_/    |_| |_| \_|',
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
    $logdir = $AppConfig.Paths.Logs
    if (-not (Test-Path $logdir)) { $null = New-Item -Path $logdir -ItemType Directory -Force }
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
    # Only write to console if NOT in GUI session (to avoid interfering with job output)
    if (-not $Global:GuiSessionActive) {
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -ge 100) { Write-Host '' }
    }
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
                }
                else {
                    $percent = [math]::Round((($totalSeconds - $i) / $totalSeconds) * 100)
                }

                # Only write to console if NOT in GUI session
                if (-not $Global:GuiSessionActive) {
                    Write-Host "`r$spinner ⏳ $Activity - $i secondi..." -NoNewline -ForegroundColor Yellow
                }
                Start-Sleep -Seconds 1
            }
            if (-not $Global:GuiSessionActive) { Write-Host '' }
            return $true
        }
        elseif ($Process -and $result -and $result.GetType().Name -eq 'Process') {
            # Monitoraggio processo
            while (-not $result.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

                if ($PercentUpdate) {
                    $percent = & $PercentUpdate
                }
                elseif ($percent -lt 90) {
                    $percent += Get-Random -Minimum 1 -Maximum 3
                }

                # Clear any previous output and show progress bar
                if (-not $Global:GuiSessionActive) {
                    Write-Host "`r" -NoNewline
                }
                Show-ProgressBar -Activity $Activity -Status "Esecuzione in corso... ($elapsed secondi)" -Percent $percent -Icon '⏳' -Spinner $spinner
                Start-Sleep -Milliseconds $UpdateInterval
                $result.Refresh()
            }

            if (-not $result.HasExited) {
                if (-not $Global:GuiSessionActive) { Write-Host "" } # Forza il ritorno a capo, chiudendo la riga dello spinner
                Write-StyledMessage -Type 'Warning' -Text "Timeout raggiunto dopo $TimeoutSeconds secondi, terminazione processo..."
                $result.Kill()
                Start-Sleep -Seconds 2
                return @{ Success = $false; TimedOut = $true; ExitCode = -1 }
            }

            # Clear line and show completion
            if (-not $Global:GuiSessionActive) {
                Clear-ProgressLine
            }
            Show-ProgressBar -Activity $Activity -Status 'Completato' -Percent 100 -Icon '✅'
            if (-not $Global:GuiSessionActive) { Write-Host "" } # Add newline after completion
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
    param(
        [int]$Seconds = 30,
        [string]$Message = "Riavvio automatico",
        [switch]$Suppress
    )

    # Se il parametro Suppress è attivo, ritorna immediatamente senza countdown
    if ($Suppress) {
        return $true
    }

    Write-StyledMessage -Type 'Info' -Text '💡 Premi un tasto qualsiasi per annullare...'
    Write-Host ''
    for ($i = $Seconds; $i -gt 0; $i--) {
        if ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
            Write-Host "`n"
            Write-StyledMessage -Type 'Warning' -Text '⏸️ Riavvio del sistema annullato.'
            return $false
        }
        $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
        $filled = [Math]::Floor($percent * 20 / 100)
        $remaining = 20 - $filled
        $bar = "[$('█' * $filled)$('▒' * $remaining)]"
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
            28000 = "26H1"; 26200 = "25H2"; 26100 = "24H2"; 22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2";
            19045 = "22H2"; 19044 = "21H2"; 19043 = "21H1"; 19042 = "20H2"; 19041 = "2004"; 18363 = "1909";
            18362 = "1903"; 17763 = "1809"; 17134 = "1803"; 16299 = "1709"; 15063 = "1703"; 14393 = "1607";
            10586 = "1511"; 10240 = "1507"
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

function Get-BitlockerStatus {
    try {
        $out = & manage-bde -status C: 2>&1
        if ($out -match "Stato protezione:\s*(.*)") { return $matches[1].Trim() }
        return "Non configurato"
    }
    catch { return "Disattivato" }
}

function WinOSCheck {
    # Skip WinOSCheck if running in GUI mode to prevent duplicate output in job runspaces
    if ($Global:GuiSessionActive) {
        return
    }

    Show-Header -SubTitle "System Check"
    $si = Get-SystemInfo
    if (-not $si) { Write-StyledMessage -Type 'Warning' -Text "Info sistema non disponibili."; return }

    Write-StyledMessage -Type 'Info' -Text "Sistema: $($si.ProductName) ($($si.DisplayVersion))"

    if ($si.BuildNumber -ge 22000) { Write-StyledMessage -Type 'Success' -Text "Sistema compatibile (Win11/10 recente)." }
    elseif ($si.BuildNumber -ge 17763) { Write-StyledMessage -Type 'Success' -Text "Sistema compatibile (Win10)." }
    elseif ($si.BuildNumber -eq 9600) { Write-StyledMessage -Type 'Warning' -Text "Windows 8.1: Compatibilità parziale." }
    else {
        Write-StyledMessage -Type 'Error' -Text "$(Center-Text '🤣 ERRORE CRITICO 🤣' 65)"
        Write-StyledMessage -Type 'Error' -Text "Davvero pensi che questo script possa fare qualcosa per questa versione?"
        Write-Host "  Vuoi rischiare? [Y/N]" -ForegroundColor Yellow
        if ((Read-Host) -notmatch '^[Yy]$') { exit }
    }
    Start-Sleep -Seconds 2
}

# --- PLACEHOLDER PER COMPILATORE ---
function WinRepairToolkit {
    <#
    .SYNOPSIS
        Esegue riparazioni standard di Windows (SFC, DISM, Chkdsk) e salva i log di Scannow nella cartella del Toolkit debug addizionale.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$MaxRetryAttempts = 3,

        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName "WinRepairToolkit"
    Show-Header -SubTitle "Repair Toolkit"
    $Host.UI.RawUI.WindowTitle = "Repair Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    $script:CurrentAttempt = 0

    # Rilevamento della build di Windows per l'esecuzione condizionale
    $sysInfo = Get-SystemInfo
    $isWin11_24H2_OrNewer = $sysInfo -and ($sysInfo.BuildNumber -ge 26100)

    $RepairTools = @(
        @{ Tool = 'chkdsk'; Args = @('/scan', '/perf'); Name = 'Controllo disco'; Icon = '💽' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (1)'; Icon = '🗂️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Name = 'Ripristino immagine Windows'; Icon = '🛠️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'); Name = 'Pulizia Residui Aggiornamenti'; Icon = '🕸️' }

        # Le registrazioni AppX vengono inserite nell'array solo se la build è >= 26100 (Win11 24H2)
        if ($isWin11_24H2_OrNewer) {
            @{ Tool = 'powershell.exe'; Args = @('-Command', "if (Test-Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\appxmanifest.xml') { Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction SilentlyContinue } else { Write-Host 'File non trovato: MicrosoftWindows.Client.CBS_cw5n1h2txyewy' }"); Name = 'Registrazione AppX (Client CBS)'; Icon = '📦'; IsCritical = $false }
            @{ Tool = 'powershell.exe'; Args = @('-Command', "if (Test-Path 'C:\Windows\SystemApps\Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe\appxmanifest.xml') { Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction SilentlyContinue } else { Write-Host 'File non trovato: Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe' }"); Name = 'Registrazione AppX (UI Xaml CBS)'; Icon = '📦'; IsCritical = $false }
            @{ Tool = 'powershell.exe'; Args = @('-Command', "if (Test-Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.Core_cw5n1h2txyewy\appxmanifest.xml') { Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.Core_cw5n1h2txyewy\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction SilentlyContinue } else { Write-Host 'File non trovato: MicrosoftWindows.Client.Core_cw5n1h2txyewy' }"); Name = 'Registrazione AppX (Client Core)'; Icon = '📦'; IsCritical = $false }
        }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (2)'; Icon = '🗂️' }
        @{ Tool = 'chkdsk'; Args = @('/f', '/r', '/x'); Name = 'Controllo disco approfondito'; Icon = '💽'; IsCritical = $false }
    )

    function Invoke-RepairCommand {
        param([hashtable]$Config, [int]$Step, [int]$Total)

        Write-StyledMessage Info "[$Step/$Total] Avvio $($Config.Name)..."
        $isChkdsk = ($Config.Tool -ieq 'chkdsk')
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()

        try {
            # Calcolo timeout centralizzato (Fix 3: eliminata duplicazione)
            $processTimeoutSeconds = 600

            switch ($Config.Name) {
                'Ripristino immagine Windows'   { $processTimeoutSeconds = 900 }
                'Controllo file di sistema (1)' { $processTimeoutSeconds = 900 }
                'Controllo file di sistema (2)' { $processTimeoutSeconds = 900 }
                'Pulizia Residui Aggiornamenti' { $processTimeoutSeconds = 900 }
                'Controllo disco'               { $processTimeoutSeconds = 600 }
                'Controllo disco approfondito'  { $processTimeoutSeconds = 600 }
            }
            $spinnerUpdateInterval = if ($Config.Name -eq 'Ripristino immagine Windows') { 900 } else { 600 }

            $result = Invoke-WithSpinner -Activity $Config.Name -Process -Action {
                if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
                    $drive = ($Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1) ?? $env:SystemDrive
                    $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }

                    $procParams = @{
                        FilePath               = 'cmd.exe'
                        ArgumentList           = @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ')")
                        RedirectStandardOutput = $outFile
                        RedirectStandardError  = $errFile
                        NoNewWindow            = $true
                        PassThru               = $true
                    }
                    Start-Process @procParams
                }
                else {
                    $procParams = @{
                        FilePath               = $Config.Tool
                        ArgumentList           = $Config.Args
                        RedirectStandardOutput = $outFile
                        RedirectStandardError  = $errFile
                        NoNewWindow            = $true
                        PassThru               = $true
                    }
                    Start-Process @procParams
                }
            } -TimeoutSeconds $processTimeoutSeconds -UpdateInterval $spinnerUpdateInterval

            $results = @()
            @($outFile, $errFile) | Where-Object { Test-Path $_ } | ForEach-Object {
                $results += Get-Content $_ -ErrorAction SilentlyContinue
            }

            # Logica controllo errori con gestione flessibile per chkdsk
            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r') -and ($results -join ' ').ToLower() -match 'schedule|next time.*restart|volume.*in use') {
                Write-StyledMessage Info "🔧 $($Config.Name): controllo schedulato al prossimo riavvio"
                return @{ Success = $true; ErrorCount = 0 }
            }

            $exitCode = $result.ExitCode

            # FIX 1: Un timeout o un'interruzione forzata tipicamente restituisce -1.
            # Aggiunto controllo per exit code negativo.
            $isTimeout = ($null -eq $result) -or ($null -eq $exitCode) -or ($exitCode -eq -1)

            # FIX 2: Dism è considerato in successo solo se NON è andato in timeout e ha trovato la stringa
            $hasDismSuccess = (-not $isTimeout) -and ($Config.Tool -ieq 'DISM') -and ($results -match '(?i)completed successfully')

            # Per chkdsk /scan, considerare successo se completato (anche con exit code non-zero informativo)
            $isChkdskScan = $isChkdsk -and ($Config.Args -contains '/scan')
            $chkdskCompleted = (-not $isTimeout) -and $isChkdskScan -and (($results -join ' ') -match '(?i)(scansione.*completata|scan.*completed|successfully scanned)')

            $isSuccess = (-not $isTimeout) -and (($exitCode -eq 0) -or $hasDismSuccess -or $chkdskCompleted)

            $errors = $warnings = @()
            if (-not $isSuccess) {
                # Se c'è stato un timeout, forza un errore
                if ($isTimeout) {
                    $errors += "Timeout: L'operazione ha superato il tempo limite ed è stata terminata."
                }

                foreach ($line in ($results | Where-Object { $_ -and ![string]::IsNullOrWhiteSpace($_.Trim()) })) {
                    $trim = $line.Trim()
                    # Escludi linee di progresso, versione e messaggi informativi
                    if ($trim -match '^\[=+\s*\d+' -or $trim -match '(?i)version:|deployment image') { continue }

                    # Per chkdsk, ignora messaggi informativi comuni che non sono errori critici
                    if ($isChkdsk) {
                        # Ignora messaggi informativi di chkdsk
                        if ($trim -match '(?i)(stage|fase|percent complete|verificat|scanned|scanning|errors found.*corrected|volume label)') { continue }
                        # Solo errori critici per chkdsk
                        if ($trim -match '(?i)(cannot|unable to|access denied|critical|fatal|corrupt file system|bad sectors)') {
                            $errors += $trim
                        }
                    }
                    else {
                        # Logica normale per altri tool
                        if ($trim -match '(?i)(errore|error|failed|impossibile|corrotto|corruption)') { $errors += $trim }
                        elseif ($trim -match '(?i)(warning|avviso|attenzione)') { $warnings += $trim }
                    }
                }

                # Fallback: Se il processo fallisce ma i log non contengono keyword di errore
                if ($errors.Count -eq 0 -and -not $isTimeout) {
                    $errors += "Errore generico o terminazione anomala (ExitCode: $exitCode)."
                }
            }

            # FIX: La variabile di successo deve richiedere che l'operazione non sia fallita/andata in timeout
            $success = $isSuccess -and ($errors.Count -eq 0)

            if ($isTimeout) {
                $message = "$($Config.Name) NON completato (interrotto per Timeout)."
            }
            else {
                $message = "$($Config.Name) completato " + $(if ($success) { 'con successo' } else { "con $($errors.Count) errori" })
            }
            Write-StyledMessage $(if ($success) { 'Success' } else { 'Warning' }) $message

            # Esportazione Log CBS di SFC
            if ($Config.Tool -ieq 'sfc') {
                $cbsLogPath = "C:\Windows\Logs\CBS\CBS.log"
                if (Test-Path $cbsLogPath) {
                    try {
                        # Pulizia del nome della fase per renderlo sicuro per il file system
                        $safeStepName = $Config.Name -replace '[^a-zA-Z0-9]', '_'
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                        $destLogName = "SFC_CBS_${safeStepName}_${timestamp}.log"

                        # Utilizzo della variabile globale per la cartella dei log
                        $destLogPath = Join-Path $AppConfig.Paths.Logs $destLogName

                        Copy-Item -Path $cbsLogPath -Destination $destLogPath -Force -ErrorAction SilentlyContinue

                        # Verifica post-copia per dare un feedback accurato
                        if (Test-Path $destLogPath) {
                            Write-StyledMessage Info "📄 Log SFC salvato in: $destLogName"
                        }
                    }
                    catch {
                        Write-StyledMessage Warning "⚠️ Impossibile esportare il log CBS di SFC (file in uso)."
                    }
                }
            }

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

    function Start-RepairCycle {
        param([int]$Attempt = 1)

        $script:CurrentAttempt = $Attempt
        Write-StyledMessage Info "🔄 Tentativo $Attempt/$MaxRetryAttempts - Riparazione sistema..."
        Write-Host ''

        $totalErrors = $successCount = 0
        for ($toolIndex = 0; $toolIndex -lt $RepairTools.Count; $toolIndex++) {
            $result = Invoke-RepairCommand -Config $RepairTools[$toolIndex] -Step ($toolIndex + 1) -Total $RepairTools.Count
            if ($result.Success) { $successCount++ }
            if (!$result.Success -and !($RepairTools[$toolIndex].ContainsKey('IsCritical') -and !$RepairTools[$toolIndex].IsCritical)) {
                $totalErrors += $result.ErrorCount
            }
            Start-Sleep 1
        }

        if ($totalErrors -gt 0 -and $Attempt -lt $MaxRetryAttempts) {
            Write-StyledMessage Warning "🔄 $totalErrors errori rilevati. Nuovo tentativo..."
            Start-Sleep 3
            return Start-RepairCycle -Attempt ($Attempt + 1)
        }
        return @{ Success = ($totalErrors -eq 0); TotalErrors = $totalErrors; AttemptsUsed = $Attempt }
    }

    function Start-DeepDiskRepair {
        Write-StyledMessage Info '🔧 Avvio riparazione profonda del disco C: al prossimo riavvio'
        try {
            $fsutilParams = @{
                FilePath     = 'fsutil.exe'
                ArgumentList = @('dirty', 'set', 'C:')
                NoNewWindow  = $true
                Wait         = $true
            }
            Start-Process @fsutilParams
            $chkdskParams = @{
                FilePath     = 'cmd.exe'
                ArgumentList = @('/c', 'echo Y | chkdsk C: /f /r /v /x /b')
                WindowStyle  = 'Hidden'
                Wait         = $true
            }
            Start-Process @chkdskParams
            Write-StyledMessage Info 'Comando chkdsk inviato. Riavvia per eseguire.'
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore durante la schedulazione della riparazione profonda: $($_.Exception.Message)"
            return $false
        }
    }

    # Esecuzione
    try {
        $repairResult = Start-RepairCycle

        $deepRepairScheduled = $false
        # Fix 2: Esegue la riparazione profonda solo se ci sono ancora errori dopo 3 tentativi
        if ($repairResult.TotalErrors -gt 0) {
            Write-StyledMessage Warning "Rilevati errori persistenti. Avvio riparazione profonda..."
            $deepRepairScheduled = Start-DeepDiskRepair
        }
        else {
            Write-StyledMessage Success "Sistema in salute. Riparazione profonda non necessaria."
        }

        Write-StyledMessage Info "⚙️ Impostazione scadenza password illimitata..."
        $procParams = @{
            FilePath     = 'net'
            ArgumentList = @('accounts', '/maxpwage:unlimited')
            NoNewWindow  = $true
            Wait         = $true
        }
        Start-Process @procParams

        if ($deepRepairScheduled) { Write-StyledMessage Warning 'Riavvio necessario per riparazione profonda.' }

        if ($SuppressIndividualReboot) {
            if ($deepRepairScheduled) {
                $Global:NeedsFinalReboot = $true
                Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
            }
        }
        else {
            if (Start-InterruptibleCountdown $CountdownSeconds 'Riavvio automatico') {
                Restart-Computer -Force
            }
        }
    }
    catch {
        Write-StyledMessage Error "❌ Errore critico: $($_.Exception.Message)"
    }
}
function WinUpdateReset {
    <#
    .SYNOPSIS
        Ripara i componenti di Windows Update, reimposta servizi, registro e criteri di default.
    .DESCRIPTION
        Ripara i problemi comuni di Windows Update, reinstalla componenti critici
        e ripristina le configurazioni di default.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 15,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName "WinUpdateReset"
    Show-Header -SubTitle "Update Reset Toolkit"
    $Host.UI.RawUI.WindowTitle = "Win Update Reset Toolkit By MagnetarMan"

    # ============================================================================
    # 2. FUNZIONI HELPER LOCALI
    # ============================================================================


    function Show-ServiceProgress([string]$ServiceName, [string]$Action, [int]$Current, [int]$Total) {
        $percent = [math]::Round(($Current / $Total) * 100)
        Invoke-WithSpinner -Activity "$Action $ServiceName" -Timer -Action { Start-Sleep -Milliseconds 200 } -TimeoutSeconds 1 | Out-Null
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
                    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue | Out-Null

                    $timeout = 10
                    do {
                        Start-Sleep -Milliseconds 500
                        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                        $timeout--
                    } while ($service.Status -eq 'Running' -and $timeout -gt 0)

                    Write-StyledMessage Info "$serviceIcon Servizio $serviceName arrestato."
                }
                'Configure' {
                    Show-ServiceProgress $serviceName "Configurazione" $currentStep $totalSteps
                    Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop | Out-Null
                    Write-StyledMessage Success "$serviceIcon Servizio $serviceName configurato come $($config.Type)."
                }
                'Start' {
                    Show-ServiceProgress $serviceName "Avvio" $currentStep $totalSteps
                    # Usa la funzione globale Invoke-WithSpinner per l'attesa avvio servizio
                    Invoke-WithSpinner -Activity "Attesa avvio $serviceName" -Timer -Action { 
                        $timeout = 10
                        do {
                            Start-Sleep -Milliseconds 500
                            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                            $timeout--
                        } while ($service.Status -ne 'Running' -and $timeout -gt 0)
                    } -TimeoutSeconds 5 | Out-Null

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

                $procParams = @{
                    FilePath     = 'robocopy.exe'
                    ArgumentList = @("`"$tempDir`"", "`"$path`"", '/MIR', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/NC')
                    Wait         = $true
                    WindowStyle  = 'Hidden'
                    ErrorAction  = 'SilentlyContinue'
                }
                $null = Start-Process @procParams
                Remove-Item $tempDir -Force -ErrorAction SilentlyContinue | Out-Null
                Remove-Item $path -Force -ErrorAction SilentlyContinue | Out-Null

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

    # --- MAIN LOGIC ---

    Write-StyledMessage Info '🔧 Inizializzazione dello Script di Reset Windows Update...'
    Start-Sleep -Seconds 2

    # Caricamento moduli
    Invoke-WithSpinner -Activity "Caricamento moduli" -Timer -Action { Start-Sleep 2 } -TimeoutSeconds 2 | Out-Null

    Write-StyledMessage Info '🛠️ Avvio riparazione servizi Windows Update...'

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
        for ($serviceIndex = 0; $serviceIndex -lt $stopServices.Count; $serviceIndex++) {
            Manage-Service $stopServices[$serviceIndex] 'Stop' $serviceConfig[$stopServices[$serviceIndex]] ($serviceIndex + 1) $stopServices.Count
        }

        Write-StyledMessage Info '⏳ Attesa liberazione risorse...'
        Start-Sleep -Seconds 3

        Write-StyledMessage Info '⚙️ Ripristino configurazione servizi Windows Update...'
        $criticalServices = $serviceConfig.Keys | Where-Object { $serviceConfig[$_].Critical }
        for ($criticalIndex = 0; $criticalIndex -lt $criticalServices.Count; $criticalIndex++) {
            $serviceName = $criticalServices[$criticalIndex]
            Write-StyledMessage Info "$($serviceConfig[$serviceName].Icon) Elaborazione servizio: $serviceName"
            Manage-Service $serviceName 'Configure' $serviceConfig[$serviceName] ($i + 1) $criticalServices.Count
        }

        Write-StyledMessage Info '🔍 Verifica servizi di sistema critici...'
        for ($systemIndex = 0; $systemIndex -lt $systemServices.Count; $systemIndex++) {
            $sysService = $systemServices[$systemIndex]
            Manage-Service $sysService.Name 'Check' @{ Icon = $sysService.Icon } ($i + 1) $systemServices.Count
        }

        Write-StyledMessage Info '📋 Ripristino chiavi di registro Windows Update...'
        # Elaborazione registro
        Invoke-WithSpinner -Activity "Elaborazione registro" -Timer -Action { Start-Sleep 1 } -TimeoutSeconds 1 | Out-Null
        try {
            @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update",
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            ) | Where-Object { Test-Path $_ } | ForEach-Object {
                Remove-Item $_ -Recurse -Force -ErrorAction Stop | Out-Null
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

        Write-StyledMessage Info '🗂️ Eliminazione componenti Windows Update...'
        $directories = @(
            @{ Path = "C:\Windows\SoftwareDistribution"; Name = "SoftwareDistribution" },
            @{ Path = "C:\Windows\System32\catroot2"; Name = "catroot2" }
        )

        for ($dirIndex = 0; $dirIndex -lt $directories.Count; $dirIndex++) {
            $dir = $directories[$dirIndex]
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

        [Console]::Out.Flush()
        [Console]::SetCursorPosition(0, [Console]::CursorTop)

        Write-StyledMessage Info '🚀 Avvio servizi essenziali...'
        $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
        for ($essentialIndex = 0; $essentialIndex -lt $essentialServices.Count; $essentialIndex++) {
            Manage-Service $essentialServices[$essentialIndex] 'Start' $serviceConfig[$essentialServices[$essentialIndex]] ($essentialIndex + 1) $essentialServices.Count
        }

        Write-StyledMessage Info '🔄 Reset del client Windows Update...'
        Write-Host '⚡ Esecuzione comando reset... ' -NoNewline -ForegroundColor Magenta
        try {
            $procParams = @{
                FilePath     = 'cmd.exe'
                ArgumentList = '/c', 'wuauclt', '/resetauthorization', '/detectnow'
                Wait         = $true
                WindowStyle  = 'Hidden'
                ErrorAction  = 'SilentlyContinue'
            }
            Start-Process @procParams | Out-Null
            Write-Host 'Completato!' -ForegroundColor Green
            Write-StyledMessage Success "🔄 Client Windows Update reimpostato."
        }
        catch {
            Write-Host 'Errore!' -ForegroundColor Red
            Write-StyledMessage Warning "Errore durante il reset del client Windows Update."
        }

        Write-StyledMessage Info '🔧 Abilitazione Windows Update e servizi correlati...'

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
                    Set-Service -Name $service.Name -StartupType $service.StartupType -ErrorAction SilentlyContinue | Out-Null

                    # Reset failure actions to default using sc command
                    $procParams = @{
                        FilePath     = 'sc.exe'
                        ArgumentList = 'failure', "$($service.Name)", 'reset= 86400 actions= restart/60000/restart/60000/restart/60000'
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams | Out-Null

                    # Start the service if it should be running
                    if ($service.StartupType -eq "Automatic") {
                        Start-Service -Name $service.Name -ErrorAction SilentlyContinue | Out-Null
                    }

                    Write-StyledMessage Success "$($service.Icon) Servizio $($service.Name) ripristinato."
                }
            }
            catch {
                Write-StyledMessage Warning "Avviso: Impossibile ripristinare servizio $($service.Name) - $($_.Exception.Message)"
            }
        }

        # Restore renamed DLLs if they exist
        Write-StyledMessage Info '🔍 Ripristino DLL rinominate...'

        $dlls = @("WaaSMedicSvc", "wuaueng")

        foreach ($dll in $dlls) {
            $dllPath = "C:\Windows\System32\$dll.dll"
            $backupPath = "C:\Windows\System32\${dll}_BAK.dll"

            if ((Test-Path $backupPath) -and !(Test-Path $dllPath)) {
                try {
                    # Take ownership of backup file
                    $procParams = @{
                        FilePath     = 'takeown.exe'
                        ArgumentList = '/f', "`"$backupPath`""
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams | Out-Null

                    # Grant full control to everyone
                    $procParams = @{
                        FilePath     = 'icacls.exe'
                        ArgumentList = "`"$backupPath`"", '/grant', '*S-1-1-0:F'
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams | Out-Null

                    # Rename back to original
                    Rename-Item -Path $backupPath -NewName "$dll.dll" -ErrorAction SilentlyContinue | Out-Null
                    Write-StyledMessage Success "Ripristinato ${dll}_BAK.dll a $dll.dll"

                    # Restore ownership to TrustedInstaller
                    $procParams = @{
                        FilePath     = 'icacls.exe'
                        ArgumentList = "`"$dllPath`"", '/setowner', '"NT SERVICE\TrustedInstaller"'
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams | Out-Null
                    $procParams = @{
                        FilePath     = 'icacls.exe'
                        ArgumentList = "`"$dllPath`"", '/remove', '*S-1-1-0'
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams | Out-Null
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
                    Enable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue | Out-Null
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
            #Start-Process -FilePath "secedit" -ArgumentList "/configure /cfg $env:windir\inf\defltbase.inf /db defltbase.sdb /verbose" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            #Start-Process -FilePath "cmd.exe" -ArgumentList "/c RD /S /Q $env:WinDir\System32\GroupPolicyUsers" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            $procParams = @{
                FilePath     = 'cmd.exe'
                ArgumentList = '/c', 'RD', '/S', '/Q', "$env:WinDir\System32\GroupPolicy"
                Wait         = $true
                WindowStyle  = 'Hidden'
                ErrorAction  = 'SilentlyContinue'
            }
            Start-Process @procParams | Out-Null
            $procParams = @{
                FilePath     = 'gpupdate'
                ArgumentList = '/force'
                Wait         = $true
                WindowStyle  = 'Hidden'
                ErrorAction  = 'SilentlyContinue'
            }
            Start-Process @procParams | Out-Null

            # Clean up registry keys
            Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKCU:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKCU:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

            Write-StyledMessage Success "📋 Criteri locali Windows ripristinati."
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile ripristinare alcuni criteri - $($_.Exception.Message)"
        }

        # Final status and verification
        Write-Host ('═' * 70) -ForegroundColor Green
        Write-StyledMessage Success '🎉 Windows Update è stato RIPRISTINATO ai valori predefiniti!'
        Write-StyledMessage Success '🔄 Servizi, registro e criteri sono stati configurati correttamente.'
        Write-StyledMessage Warning "⚡ Nota: È necessario un riavvio per applicare completamente tutte le modifiche."
        Write-Host ('═' * 70) -ForegroundColor Green

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

        Write-StyledMessage Info '💡 Windows Update dovrebbe ora funzionare normalmente.'
        Write-StyledMessage Info '🔧 Verifica aprendo Impostazioni > Aggiornamento e sicurezza.'
        Write-StyledMessage Info '🔄 Se necessario, riavvia il sistema per applicare tutte le modifiche.'

        Write-Host ('═' * 65) -ForegroundColor Green
        Write-StyledMessage Success '🎉 Riparazione completata con successo!'
        Write-StyledMessage Success '💻 Il sistema necessita di un riavvio per applicare tutte le modifiche.'
        Write-StyledMessage Warning "⚡ Attenzione: il sistema verrà riavviato automaticamente"
        Write-Host ('═' * 65) -ForegroundColor Green

        if ($SuppressIndividualReboot) {
            $Global:NeedsFinalReboot = $true
            Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
        }
        else {
            $shouldReboot = Start-InterruptibleCountdown $CountdownSeconds "Preparazione riavvio sistema"
            if ($shouldReboot) {
                Write-StyledMessage Info "🔄 Riavvio in corso..."
                Restart-Computer -Force
            }
        }
    }
    catch {
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
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI senza output bloccanti in modo completo.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$NoReboot,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName "WinReinstallStore"
    Show-Header -SubTitle "Store Repair Toolkit"

    # ============================================================================
    # 2. FUNZIONI HELPER LOCALI - GESTIONE AMBIENTE E PERCORSI
    # ============================================================================

    function Update-EnvironmentPath {
        <#
        .SYNOPSIS
            Ricarica PATH da Machine e User per rilevare installazioni recenti.
        #>
        $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'

        $env:Path = $newPath
        [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
    }

    function Path-ExistsInEnvironment {
        <#
        .SYNOPSIS
            Controlla se un percorso esiste nella variabile PATH.
        #>
        param (
            [string]$PathToCheck,
            [string]$Scope = 'Both'
        )

        $pathExists = $false

        if ($Scope -eq 'User' -or $Scope -eq 'Both') {
            $userEnvPath = $env:PATH
            if (($userEnvPath -split ';').Contains($PathToCheck)) { $pathExists = $true }
        }

        if ($Scope -eq 'System' -or $Scope -eq 'Both') {
            $systemEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)
            if (($systemEnvPath -split ';').Contains($PathToCheck)) { $pathExists = $true }
        }

        return $pathExists
    }

    function Add-ToEnvironmentPath {
        <#
        .SYNOPSIS
            Aggiunge un percorso alla variabile PATH.
        #>
        param (
            [Parameter(Mandatory = $true)]
            [string]$PathToAdd,
            [ValidateSet('User', 'System')]
            [string]$Scope
        )

        if (-not (Path-ExistsInEnvironment -PathToCheck $PathToAdd -Scope $Scope)) {
            if ($Scope -eq 'System') {
                $systemEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)
                $systemEnvPath += ";$PathToAdd"
                [System.Environment]::SetEnvironmentVariable('PATH', $systemEnvPath, [System.EnvironmentVariableTarget]::Machine)
            }
            elseif ($Scope -eq 'User') {
                $userEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::User)
                $userEnvPath += ";$PathToAdd"
                [System.Environment]::SetEnvironmentVariable('PATH', $userEnvPath, [System.EnvironmentVariableTarget]::User)
            }

            if (-not ($env:PATH -split ';').Contains($PathToAdd)) {
                $env:PATH += ";$PathToAdd"
            }
            Write-StyledMessage -Type 'Info' -Text "PATH aggiornato: $PathToAdd"
        }
    }

    function Set-PathPermissions {
        <#
        .SYNOPSIS
            Concede permessi full control al gruppo Administrators sulla cartella specificata.
        #>
        param (
            [string]$FolderPath
        )

        if (-not (Test-Path $FolderPath)) { return }

        try {
            $administratorsGroupSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
            $administratorsGroup = $administratorsGroupSid.Translate([System.Security.Principal.NTAccount])
            $acl = Get-Acl -Path $FolderPath -ErrorAction Stop
            
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $administratorsGroup, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
            )
            
            $acl.SetAccessRule($accessRule)
            Set-Acl -Path $FolderPath -AclObject $acl -ErrorAction Stop
            Write-StyledMessage -Type 'Info' -Text "Permessi cartella aggiornati: $FolderPath"
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile impostare permessi: $($_.Exception.Message)"
        }
    }

    # ============================================================================
    # 2B. FUNZIONI HELPER LOCALI - VERIFICA INSTALLAZIONE
    # ============================================================================

    function Test-VCRedistInstalled {
        <#
        .SYNOPSIS
            Verifica se Visual C++ Redistributable è installato e verifica la versione principale è 14.
        #>
        
        $is64BitOS = [System.Environment]::Is64BitOperatingSystem
        $is64BitProcess = [System.Environment]::Is64BitProcess

        if ($is64BitOS -and -not $is64BitProcess) {
            Write-StyledMessage -Type 'Warning' -Text "Esegui PowerShell nativo (x64)."
            return $false
        }

        $registryPath = [string]::Format(
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\{0}\Microsoft\VisualStudio\14.0\VC\Runtimes\X{1}',
            $(if ($is64BitOS -and $is64BitProcess) { 'WOW6432Node' } else { '' }),
            $(if ($is64BitOS) { '64' } else { '86' })
        )

        $isRegistryExists = Test-Path -Path $registryPath

        $majorVersion = if ($isRegistryExists) {
            (Get-ItemProperty -Path $registryPath -Name 'Major' -ErrorAction SilentlyContinue).Major
        }
        else { 0 }

        $dllPath = [string]::Format('{0}\concrt140.dll', [Environment]::GetFolderPath('System'))
        $dllExists = [System.IO.File]::Exists($dllPath)

        return $isRegistryExists -and $majorVersion -eq 14 -and $dllExists
    }

    function Find-WinGet {
        <#
        .SYNOPSIS
            Trova la posizione dell'eseguibile WinGet.
        #>
        try {
            $wingetPathToResolve = Join-Path -Path $ENV:ProgramFiles -ChildPath 'Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe'
            $resolveWingetPath = Resolve-Path -Path $wingetPathToResolve -ErrorAction Stop | Sort-Object {
                [version]($_.Path -replace '^[^\d]+_((\d+\.)*\d+)_.*', '$1')
            }

            if ($resolveWingetPath) {
                $wingetPath = $resolveWingetPath[-1].Path
            }

            $wingetExe = Join-Path $wingetPath 'winget.exe'

            if (Test-Path -Path $wingetExe) {
                return $wingetExe
            }
            else {
                return $null
            }
        }
        catch {
            return $null
        }
    }

    function Install-NuGetIfRequired {
        <#
        .SYNOPSIS
            Verifica se il provider NuGet è installato e lo installa se necessario.
        #>
        
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            if ($PSVersionTable.PSVersion.Major -lt 7) {
                try {
                    Install-PackageProvider -Name "NuGet" -Force -ForceBootstrap -ErrorAction SilentlyContinue *>$null
                    Write-StyledMessage -Type 'Info' -Text "Provider NuGet installato."
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Impossibile installare provider NuGet."
                }
            }
        }
    }

    # ============================================================================
    # 2C. FUNZIONI HELPER LOCALI - GESTIONE PROCESSI E RIPARAZIONE
    # ============================================================================

    function Invoke-ForceCloseWinget {
        <#
        .SYNOPSIS
            Chiude i processi che bloccano l'installazione di Winget/Store.
            Approccio mirato per evitare di chiudere processi di sistema non necessari.
        #>
        Write-StyledMessage -Type 'Info' -Text "Chiusura processi interferenti..."
        
        # Lista mirata dei processi che bloccano effettivamente l'installazione Appx
        $interferingProcesses = @(
            @{ Name = "WinStore.App"; Description = "Windows Store process" },
            @{ Name = "wsappx"; Description = "AppX deployment service" },
            @{ Name = "AppInstaller"; Description = "App Installer service" },
            @{ Name = "Microsoft.WindowsStore"; Description = "Windows Store" },
            @{ Name = "Microsoft.DesktopAppInstaller"; Description = "Desktop App Installer" },
            @{ Name = "winget"; Description = "Winget CLI" },
            @{ Name = "WindowsPackageManagerServer"; Description = "Windows Package Manager Server" }
        )

        foreach ($proc in $interferingProcesses) {
            Get-Process -Name $proc.Name -ErrorAction SilentlyContinue | 
            Where-Object { $_.Id -ne $PID } | 
            Stop-Process -Force -ErrorAction SilentlyContinue
        }
        
        Start-Sleep 2
        Write-StyledMessage -Type 'Success' -Text "Processi interferenti chiusi."
    }

    function Apply-WingetPathPermissions {
        <#
        .SYNOPSIS
            Applica permessi PATH e aggiunge la cartella winget a PATH.
            Basato su approccio asheroto.
        #>
        
        $wingetFolderPath = $null
        
        try {
            $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
            $wingetDir = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue | 
            Sort-Object Name -Descending | Select-Object -First 1
            
            if ($wingetDir) {
                $wingetFolderPath = $wingetDir.FullName
            }
        }
        catch { }

        if ($wingetFolderPath) {
            Set-PathPermissions -FolderPath $wingetFolderPath
            Add-ToEnvironmentPath -PathToAdd $wingetFolderPath -Scope 'System'
            Add-ToEnvironmentPath -PathToAdd "%LOCALAPPDATA%\Microsoft\WindowsApps" -Scope 'User'
            
            Write-StyledMessage -Type 'Success' -Text "PATH e permessi winget aggiornati."
        }
    }

    function Repair-WingetDatabase {
        <#
        .SYNOPSIS
            Ripara il database di Winget.
        #>
        Write-StyledMessage -Type 'Info' -Text "Avvio ripristino database Winget..."
        
        try {
            # 1. Usa Stop-InterferingProcess come in start.ps1
            Stop-InterferingProcess
            
            $wingetCachePath = "$env:LOCALAPPDATA\WinGet"
            if (Test-Path $wingetCachePath) {
                Write-StyledMessage -Type 'Info' -Text "Pulizia cache Winget..."
                Get-ChildItem -Path $wingetCachePath -Recurse -Force -ErrorAction SilentlyContinue | 
                Where-Object { $_.FullName -notmatch '\\lock\\|\\tmp\\' } |
                ForEach-Object {
                    try { 
                        Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue 
                    }
                    catch { }
                }
            }
            
            $stateFiles = @(
                "$env:LOCALAPPDATA\WinGet\Data\USERTEMPLATE.json",
                "$env:LOCALAPPDATA\WinGet\Data\DEFAULTUSER.json"
            )
            
            foreach ($file in $stateFiles) {
                if (Test-Path $file -PathType Leaf) {
                    Write-StyledMessage -Type 'Info' -Text "Reset file stato: $file"
                    Remove-Item $file -Force -ErrorAction SilentlyContinue
                }
            }
            
            Write-StyledMessage -Type 'Info' -Text "Reset sorgenti Winget..."
            try {
                $null = & winget.exe source reset --force 2>&1
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore durante reset sorgenti Winget: $($_.Exception.Message)"
            }
            
            Update-EnvironmentPath
            
            try {
                if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                    Write-StyledMessage -Type 'Info' -Text "Esecuzione Repair-WinGetPackageManager..."
                    Repair-WinGetPackageManager -Force -Latest *>$null
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Modulo Riparazione non disponibile: $($_.Exception.Message)"
            }
            
            Start-Sleep 2
            $testVersion = & winget --version *>$null
            if ($LASTEXITCODE -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "Database Winget ripristinato (versione: $testVersion)."
                return $true
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "Ripristino completato ma winget potrebbe non funzionare."
                return $true
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante ripristino database: $($_.Exception.Message)"
            return $false
        }
    }

    # ============================================================================
    # 2D. FUNZIONI HELPER LOCALI - VALIDAZIONE E DOWNLOAD
    # ============================================================================

    function Test-WingetDeepValidation {
        <#
        .SYNOPSIS
            Esegue test profondo di winget (ricerca pacchetti in rete).
        #>
        Write-StyledMessage -Type 'Info' -Text "Esecuzione test profondo di Winget (ricerca pacchetti in rete)..."

        try {
            $searchResult = & winget search "Git.Git" --accept-source-agreements 2>&1
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                Write-StyledMessage -Type 'Warning' -Text "Crash rilevato (ExitCode: $exitCode = ACCESS_VIOLATION). Tentativo ripristino database..."
                
                $repairAttempt = Repair-WingetDatabase
                
                if ($repairAttempt) {
                    Write-StyledMessage -Type 'Info' -Text "Ripetizione test dopo ripristino..."
                    Start-Sleep 3
                    $searchResult = & winget search "Git.Git" --accept-source-agreements 2>&1
                    $exitCode = $LASTEXITCODE
                }
            }

            if ($exitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "Test profondo superato: Winget comunica correttamente con i repository."
                return $true
            }
            else {
                $errorDetails = $searchResult | Out-String
                if ($errorDetails.Length -gt 200) { $errorDetails = $errorDetails.Substring(0, 200) + "..." }
                Write-StyledMessage -Type 'Warning' -Text "Test profondo fallito: ExitCode=$exitCode. Dettagli: $errorDetails"
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante il test profondo di Winget: $($_.Exception.Message)"
            return $false
        }
    }

    function Get-WingetDownloadUrl {
        <#
        .SYNOPSIS
            Recupera URL download da GitHub releases.
        #>
        param([string]$Match)
        try {
            $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
            $asset = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
            if ($asset) { return $asset.browser_download_url }
            throw "Asset '$Match' non trovato."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore recupero URL asset: $($_.Exception.Message)"
            return $null
        }
    }

    function Install-WingetCore {
        Write-StyledMessage -Type 'Info' -Text "🚀 Avvio della procedura di reinstallazione e riparazione Winget..."

        $oldProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        # --- FASE 0: Verifica Visual C++ Redistributable ---
        if (-not (Test-VCRedistInstalled)) {
            Write-StyledMessage -Type 'Info' -Text "Installazione Visual C++ Redistributable..."
            $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
            $vcUrl = "https://aka.ms/vs/17/release/vc_redist.$arch.exe"
            $tempDir = "$env:TEMP\WinToolkitWinget"
            if (-not (Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force *>$null }
            $vcFile = Join-Path $tempDir "vc_redist.exe"

            try {
                Invoke-WebRequest -Uri $vcUrl -OutFile $vcFile -UseBasicParsing -ErrorAction Stop
                $procParams = @{
                    FilePath     = $vcFile
                    ArgumentList = @("/install", "/quiet", "/norestart")
                    Wait         = $true
                    NoNewWindow  = $true
                }
                Start-Process @procParams
                Write-StyledMessage -Type 'Success' -Text "Visual C++ Redistributable installato."
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Impossibile installare VC++ Redistributable: $($_.Exception.Message)"
            }
        }
        else {
            Write-StyledMessage -Type 'Success' -Text "Visual C++ Redistributable già presente."
        }

        # --- FASE 0B: Installazione Dipendenze Winget (UI.Xaml, VCLibs) ---
        Write-StyledMessage -Type 'Info' -Text "Download dipendenze Winget dal repository ufficiale..."
        $depUrl = Get-WingetDownloadUrl -Match 'DesktopAppInstaller_Dependencies.zip'
        if ($depUrl) {
            $depZip = Join-Path $tempDir "dependencies.zip"
            try {
                $iwrDepParams = @{
                    Uri             = $depUrl
                    OutFile         = $depZip
                    UseBasicParsing = $true
                    ErrorAction     = 'Stop'
                }
                Invoke-WebRequest @iwrDepParams

                $extractPath = Join-Path $tempDir "deps"
                if (Test-Path $extractPath) { Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue }
                Expand-Archive -Path $depZip -DestinationPath $extractPath -Force

                $archPattern = if ([Environment]::Is64BitOperatingSystem) { "x64|ne" } else { "x86|ne" }
                $appxFiles = Get-ChildItem -Path $extractPath -Recurse -Filter "*.appx" | Where-Object { $_.Name -match $archPattern }

                foreach ($file in $appxFiles) {
                    Write-StyledMessage -Type 'Info' -Text "Installazione dipendenza: $($file.Name)..."
                    Add-AppxPackage -Path $file.FullName -ErrorAction SilentlyContinue -ForceApplicationShutdown
                }
                Write-StyledMessage -Type 'Success' -Text "Dipendenze Winget installate."
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Impossibile estrarre/installare dipendenze: $($_.Exception.Message)"
            }
            finally {
                if (Test-Path $depZip) { Remove-Item $depZip -Force -ErrorAction SilentlyContinue }
            }
        }

        # --- FASE 1: Inizializzazione e Pulizia Profonda ---

        # Usa helper avanzato per terminare processi interferenti
        Write-StyledMessage -Type 'Info' -Text "🔄 Chiusura forzata dei processi Winget e correlati..."
        Invoke-ForceCloseWinget

        # Terminazione processi specifici di Winget (taskkill supplementare)
        $null = Invoke-WithSpinner -Activity "Terminazione processi Winget" -Process -Action {
            @("winget", "WindowsPackageManagerServer") | ForEach-Object {
                taskkill /im "$_.exe" /f *>$null
            }
        }

        # Pulizia cartella temporanea
        Write-StyledMessage -Type 'Info' -Text "🔄 Pulizia dei file temporanei (%TEMP%\WinGet)..."
        $tempWingetPath = "$env:TEMP\WinGet"
        if (Test-Path $tempWingetPath) {
            Remove-Item -Path $tempWingetPath -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Write-StyledMessage -Type 'Info' -Text "Cartella temporanea di Winget eliminata."
        }
        else {
            Write-StyledMessage -Type 'Info' -Text "Cartella temporanea di Winget non trovata o già pulita."
        }

        # Reset sorgenti Winget
        Write-StyledMessage -Type 'Info' -Text "🔄 Reset delle sorgenti Winget..."
        try {
            $wingetExePath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
            $null = Invoke-WithSpinner -Activity "Reset sorgenti Winget" -Process -Action {
                if (Test-Path $wingetExePath) {
                    & $wingetExePath source reset --force *>$null
                }
                else {
                    winget source reset --force *>$null
                }
            }
            Write-StyledMessage -Type 'Success' -Text "Sorgenti Winget resettate."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Reset sorgenti Winget non riuscito: $($_.Exception.Message)"
        }

        # --- FASE 2: Installazione Dipendenze e Moduli PowerShell ---

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Installazione Provider NuGet (usando helper)
        Write-StyledMessage -Type 'Info' -Text "🔄 Installazione PackageProvider NuGet..."
        Install-NuGetIfRequired
        
        try {
            $nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
            if (-not $nugetProvider) {
                try {
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                    Write-StyledMessage -Type 'Success' -Text "Provider NuGet installato."
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Provider NuGet: conferma manuale potrebbe essere richiesta. Errore: $($_.Exception.Message)"
                }
            }
            else {
                Write-StyledMessage -Type 'Success' -Text "Provider NuGet già installato."
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore durante l'installazione del provider NuGet: $($_.Exception.Message)"
        }

        # Installazione Modulo Microsoft.WinGet.Client
        Write-StyledMessage -Type 'Info' -Text "🔄 Installazione modulo Microsoft.WinGet.Client..."
        try {
            Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
            Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "Modulo Microsoft.WinGet.Client installato e importato."
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore installazione/import Microsoft.WinGet.Client: $($_.Exception.Message)"
        }

        # --- FASE 3: Riparazione e Reinstallazione del Core di Winget ---

        # Tentativo A — Riparazione via Modulo
        if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type 'Info' -Text "🔄 Riparazione Winget tramite modulo WinGet Client..."
            try {
                $result = Invoke-WithSpinner -Activity "Riparazione Winget (modulo)" -Process -Action {
                    $procParams = @{
                        FilePath     = 'powershell'
                        ArgumentList = @('-NoProfile', '-WindowStyle', 'Hidden', '-Command',
                            'Repair-WinGetPackageManager -Force -Latest 2>$null')
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                } -TimeoutSeconds 180

                if ($result.ExitCode -eq 0) {
                    Write-StyledMessage -Type 'Success' -Text "Winget riparato con successo tramite modulo."
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "Riparazione Winget tramite modulo non riuscita (ExitCode: $($result.ExitCode))."
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore durante la riparazione Winget: $($_.Exception.Message)"
            }
        }

        # Tentativo B — Reinstallazione tramite MSIXBundle (Fallback)
        Update-EnvironmentPath
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Info' -Text "🔄 Installazione Winget tramite MSIXBundle..."
            $tempInstaller = Join-Path $AppConfig.Paths.Temp "WingetInstaller.msixbundle"

            try {
                $null = New-Item -Path $AppConfig.Paths.Temp -ItemType Directory -Force -ErrorAction SilentlyContinue

                # Prova prima con URL dinamico da GitHub, poi fallback a aka.ms
                $wingetUrl = Get-WingetDownloadUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
                if (-not $wingetUrl) {
                    $wingetUrl = $AppConfig.URLs.WingetInstaller
                }

                $iwrParams = @{
                    Uri             = $wingetUrl
                    OutFile         = $tempInstaller
                    UseBasicParsing = $true
                    ErrorAction     = 'Stop'
                }
                Invoke-WebRequest @iwrParams

                $result = Invoke-WithSpinner -Activity "Installazione Winget MSIXBundle" -Process -Action {
                    $procParams = @{
                        FilePath     = 'powershell'
                        ArgumentList = @('-NoProfile', '-WindowStyle', 'Hidden', '-Command',
                            "try { Add-AppxPackage -Path '$tempInstaller' -ForceApplicationShutdown -ErrorAction Stop } catch { exit 1 }; exit 0")
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                } -TimeoutSeconds 120

                if ($result.ExitCode -eq 0) {
                    Write-StyledMessage -Type 'Success' -Text "Winget installato con successo tramite MSIXBundle."
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "Installazione Winget tramite MSIXBundle fallita (ExitCode: $($result.ExitCode))."
                }
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Errore download/install MSIXBundle: $($_.Exception.Message)"
            }
            finally {
                Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue *>$null
            }
        }

        # --- FASE 4: Reset dell'App Installer Appx ---
        try {
            Write-StyledMessage -Type 'Info' -Text "🔄 Reset 'Programma di installazione app'..."

            $result = Invoke-WithSpinner -Activity "Reset App Installer" -Process -Action {
                $procParams = @{
                    FilePath     = 'powershell'
                    ArgumentList = @('-NoProfile', '-WindowStyle', 'Hidden', '-Command',
                        "Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue | Reset-AppxPackage -ErrorAction SilentlyContinue")
                    PassThru     = $true
                    WindowStyle  = 'Hidden'
                }
                Start-Process @procParams
            } -TimeoutSeconds 60

            if ($result.ExitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "App 'Programma di installazione app' resettata con successo."
            }
            else {
                Write-StyledMessage -Type 'Info' -Text "Reset Appx completato (ExitCode: $($result.ExitCode))."
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile resettare App Installer: $($_.Exception.Message)"
        }

        # --- FASE 5: Applica permessi PATH ---
        Apply-WingetPathPermissions

        # --- FASE 6: Verifica Finale ---
        Start-Sleep 2
        Update-EnvironmentPath
        $isWingetAvailable = [bool](Get-Command winget -ErrorAction SilentlyContinue)

        if ($isWingetAvailable) {
            Write-StyledMessage -Type 'Success' -Text "Winget è stato processato e sembra funzionante."
            
            # Test profondo opzionale
            Write-StyledMessage -Type 'Info' -Text "Esecuzione validazione approfondita..."
            $deepTestResult = Test-WingetDeepValidation
            if ($deepTestResult) {
                Write-StyledMessage -Type 'Success' -Text "Validazione approfondita superata."
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "Validazione approfondita fallita - potrebbero esserci problemi di rete o repository."
            }
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Impossibile installare o riparare Winget dopo tutti i tentativi."
        }

        $ProgressPreference = $oldProgress
        
        # Pulizia directory temporanea
        $tempDir = "$env:TEMP\WinToolkitWinget"
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        return $isWingetAvailable
    }

    function Install-MicrosoftStore {
        Write-StyledMessage -Type 'Info' -Text "🔄 Reinstallazione Microsoft Store in corso..."

        # Restart servizi correlati allo Store
        @("AppXSvc", "ClipSVC", "WSService") | ForEach-Object {
            try { Restart-Service $_ -Force -ErrorAction SilentlyContinue *>$null } catch {}
        }

        # Pulizia cache Store
        $cachePaths = @(
            @{ Path = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache"; Description = "Windows Store Local Cache" },
            @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; Description = "Internet Cache" }
        )
        foreach ($cache in $cachePaths) {
            if (Test-Path $cache.Path) { Remove-Item $cache.Path -Recurse -Force -ErrorAction SilentlyContinue *>$null }
        }

        # Metodi di installazione in ordine di preferenza
        $installMethods = @(
            @{
                Name   = "Winget Install"
                Action = {
                    $isWingetReady = [bool](Get-Command winget -ErrorAction SilentlyContinue)
                    if (-not $isWingetReady) { return @{ ExitCode = -1 } }

                    $procParams = @{
                        FilePath     = 'winget'
                        ArgumentList = @('install', '9WZDNCRFJBMP', '--accept-source-agreements',
                            '--accept-package-agreements', '--silent', '--disable-interactivity')
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                }
            },
            @{
                Name   = "AppX Manifest"
                Action = {
                    $store = Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue | Select-Object -First 1
                    if (-not $store) { return @{ ExitCode = -1 } }

                    $manifest = "$($store.InstallLocation)\AppXManifest.xml"
                    if (-not (Test-Path $manifest)) { return @{ ExitCode = -1 } }

                    $procParams = @{
                        FilePath     = 'powershell'
                        ArgumentList = @('-NoProfile', '-WindowStyle', 'Hidden', '-Command',
                            "Add-AppxPackage -DisableDevelopmentMode -Register '$manifest' -ForceApplicationShutdown")
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                }
            },
            @{
                Name   = "DISM Capability"
                Action = {
                    $procParams = @{
                        FilePath     = 'DISM'
                        ArgumentList = @('/Online', '/Add-Capability', '/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0')
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                }
            }
        )

        # Codici di uscita considerati successo
        $successCodes = @(0, 3010, 1638, -1978335189)

        $success = $false
        foreach ($method in $installMethods) {
            Write-StyledMessage -Type 'Info' -Text "Tentativo: Installazione Store ($($method.Name))..."
            try {
                $result = Invoke-WithSpinner -Activity "Store: $($method.Name)" -Process -Action $method.Action -TimeoutSeconds 300

                $isSuccess = $result.ExitCode -in $successCodes
                if ($isSuccess) {
                    Write-StyledMessage -Type 'Success' -Text "$($method.Name) completato con successo."

                    Write-StyledMessage -Type 'Info' -Text "Esecuzione wsreset.exe per pulire la cache dello Store..."
                    $procParams = @{
                        FilePath    = 'wsreset.exe'
                        Wait        = $true
                        WindowStyle = 'Hidden'
                        ErrorAction = 'SilentlyContinue'
                    }
                    Start-Process @procParams *>$null

                    Write-StyledMessage -Type 'Success' -Text "Cache dello Store ripristinata."
                    $success = $true
                    break
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "$($method.Name) non riuscito (ExitCode: $($result.ExitCode)). Tentativo prossimo metodo."
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore durante $($method.Name): $($_.Exception.Message)"
            }
        }

        return $success
    }

    function Install-UniGetUI {
        Write-StyledMessage -Type 'Info' -Text "🔄 Reinstallazione UniGet UI in corso..."

        $isWingetReady = [bool](Get-Command winget -ErrorAction SilentlyContinue)
        if (-not $isWingetReady) {
            Write-StyledMessage -Type 'Warning' -Text "Winget non disponibile. Impossibile installare UniGet UI."
            return $false
        }

        $successCodes = @(0, 3010, 1638, -1978335189)

        try {
            # Rimozione versione esistente (ignora errori — potrebbe non essere installata)
            Write-StyledMessage -Type 'Info' -Text "🔄 Rimozione versione esistente UniGet UI..."
            $uninstallParams = @{
                FilePath     = 'winget'
                ArgumentList = @('uninstall', '--exact', '--id', 'MartiCliment.UniGetUI', '--silent', '--disable-interactivity')
                Wait         = $true
                WindowStyle  = 'Hidden'
            }
            Start-Process @uninstallParams *>$null
            Start-Sleep 2

            # Installazione nuova versione
            Write-StyledMessage -Type 'Info' -Text "🔄 Installazione UniGet UI..."
            $installResult = Invoke-WithSpinner -Activity "Installazione UniGet UI" -Process -Action {
                $procParams = @{
                    FilePath     = 'winget'
                    ArgumentList = @('install', '--exact', '--id', 'MartiCliment.UniGetUI', '--source', 'winget',
                        '--accept-source-agreements', '--accept-package-agreements', '--silent',
                        '--disable-interactivity', '--force')
                    PassThru     = $true
                    WindowStyle  = 'Hidden'
                }
                Start-Process @procParams
            } -TimeoutSeconds 300

            $isSuccess = $installResult.ExitCode -in $successCodes
            if ($isSuccess) {
                Write-StyledMessage -Type 'Success' -Text "UniGet UI installata con successo."

                # Disabilitazione avvio automatico
                Write-StyledMessage -Type 'Info' -Text "🔄 Disabilitazione avvio automatico UniGet UI..."
                try {
                    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                    $regKeyName = "WingetUI"
                    if (Get-ItemProperty -Path $regPath -Name $regKeyName -ErrorAction SilentlyContinue) {
                        Remove-ItemProperty -Path $regPath -Name $regKeyName -ErrorAction Stop *>$null
                        Write-StyledMessage -Type 'Success' -Text "Avvio automatico UniGet UI disabilitato."
                    }
                    else {
                        Write-StyledMessage -Type 'Info' -Text "Voce di avvio automatico UniGet UI non trovata — skip."
                    }
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Impossibile disabilitare avvio automatico UniGet UI: $($_.Exception.Message)"
                }
                return $true
            }
            else {
                Write-StyledMessage -Type 'Error' -Text "Installazione UniGet UI fallita (ExitCode: $($installResult.ExitCode))."
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore critico durante installazione UniGet UI: $($_.Exception.Message)"
            return $false
        }
    }

    # ============================================================================
    # 3. ESECUZIONE PRINCIPALE
    # ============================================================================

    Write-StyledMessage -Type 'Info' -Text "🚀 AVVIO REINSTALLAZIONE STORE"

    try {
        $wingetResult = Install-WingetCore
        Write-StyledMessage -Type $(if ($wingetResult) { 'Success' } else { 'Warning' }) -Text "Winget $(if ($wingetResult) { 'installato' } else { 'processato — verifica manuale consigliata' })."

        $storeResult = Install-MicrosoftStore
        if (-not $storeResult) {
            Write-StyledMessage -Type 'Error' -Text "Errore installazione Microsoft Store."
            Write-StyledMessage -Type 'Info' -Text "Verifica: connessione Internet, privilegi Admin, Windows Update."
            return
        }
        Write-StyledMessage -Type 'Success' -Text "Microsoft Store installato."

        $unigetResult = Install-UniGetUI
        Write-StyledMessage -Type $(if ($unigetResult) { 'Success' } else { 'Warning' }) -Text "UniGet UI $(if ($unigetResult) { 'installata' } else { 'processata — verifica manuale consigliata' })."

        Write-StyledMessage -Type 'Success' -Text "🎉 OPERAZIONE COMPLETATA"
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "❌ ERRORE: $($_.Exception.Message)"
        Write-StyledMessage -Type 'Info' -Text "💡 Esegui come Admin, verifica Internet e Windows Update."
    }
    finally {
        try { Stop-Transcript | Out-Null } catch {}
    }

    # ============================================================================
    # 4. GESTIONE RIAVVIO — SEMPRE ULTIMA
    # ============================================================================

    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
        Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
    }
    else {
        if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio necessario per applicare le modifiche") {
            Write-StyledMessage -Type 'Info' -Text "🔄 Riavvio in corso..."
            if (-not $NoReboot) {
                Restart-Computer -Force
            }
        }
    }
}
function WinBackupDriver {
    <#
    .SYNOPSIS
        Strumento di backup completo per i driver di sistema Windows.
    .DESCRIPTION
        Script PowerShell per eseguire il backup completo di tutti i driver di terze parti
        installati sul sistema. Il processo include l'esportazione tramite DISM, compressione
        in formato 7z e spostamento automatico sul desktop.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 10,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName "WinBackupDriver"
    Show-Header -SubTitle "Driver Backup Toolkit"
    $Host.UI.RawUI.WindowTitle = "Driver Backup Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    
    $script:BackupConfig = @{
        DateTime    = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        BackupDir   = $AppConfig.Paths.DriverBackupTemp
        ArchiveName = "DriverBackup"
        DesktopPath = $AppConfig.Paths.Desktop
        TempPath    = $AppConfig.Paths.TempFolder
        LogsDir     = $AppConfig.Paths.DriverBackupLogs
    }
    
    $script:FinalArchivePath = "$($script:BackupConfig.DesktopPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).7z"

    # ============================================================================
    # 3. FUNZIONI HELPER LOCALI
    # ============================================================================

    function Test-AdministratorPrivilege {
        $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    
    function Initialize-BackupEnvironment {
        Write-StyledMessage Info "🗂️ Inizializzazione ambiente backup..."
        
        try {
            if (Test-Path $script:BackupConfig.BackupDir) {
                Write-StyledMessage Warning "Rimozione backup precedenti..."
                Remove-Item $script:BackupConfig.BackupDir -Recurse -Force -ErrorAction Stop | Out-Null
            }
            
            New-Item -ItemType Directory -Path $script:BackupConfig.BackupDir -Force | Out-Null
            New-Item -ItemType Directory -Path $script:BackupConfig.LogsDir -Force | Out-Null
            Write-StyledMessage Success "Directory backup e log create"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore inizializzazione ambiente: $_"
            return $false
        }
    }

    function Export-SystemDrivers {
        Write-StyledMessage Info "💾 Avvio esportazione driver di sistema..."
        
        $outFile = "$($script:BackupConfig.LogsDir)\dism_$($script:BackupConfig.DateTime).log"
        $errFile = "$($script:BackupConfig.LogsDir)\dism_err_$($script:BackupConfig.DateTime).log"
        
        try {
            # Usa Invoke-WithSpinner per monitorare il processo DISM
            $result = Invoke-WithSpinner -Activity "Esportazione driver DISM" -Process -Action {
                $procParams = @{
                    FilePath               = 'dism.exe'
                    ArgumentList           = @('/online', '/export-driver', "/destination:`"$($script:BackupConfig.BackupDir)`"")
                    NoNewWindow            = $true
                    PassThru               = $true
                    RedirectStandardOutput = $outFile
                    RedirectStandardError  = $errFile
                }
                Start-Process @procParams
            } -TimeoutSeconds 300 -UpdateInterval 1000
            
            if ($result.TimedOut) {
                throw "Timeout raggiunto durante l'esportazione DISM"
            }
            
            if ($result.ExitCode -ne 0) {
                $errorDetails = if (Test-Path $errFile) {
                    (Get-Content $errFile -ErrorAction SilentlyContinue) -join '; '
                }
                else { "Dettagli non disponibili" }
                throw "Esportazione DISM fallita (ExitCode: $($result.ExitCode)). Dettagli: $errorDetails"
            }
            
            $exportedDrivers = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
            if (-not $exportedDrivers -or $exportedDrivers.Count -eq 0) {
                Write-StyledMessage Warning "Nessun driver di terze parti trovato da esportare"
                Write-StyledMessage Info "💡 I driver integrati di Windows non vengono esportati"
                return $true
            }
            
            $totalSize = ($exportedDrivers | Measure-Object -Property Length -Sum).Sum
            $totalSizeMB = [Math]::Round($totalSize / 1MB, 2)
            
            Write-StyledMessage Success "Esportazione completata: $($exportedDrivers.Count) driver trovati ($totalSizeMB MB)"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore durante esportazione driver: $_"
            return $false
        }
    }
    
    function Resolve-7ZipExecutable {
        return Install-7ZipPortable
    }
    
    function Install-7ZipPortable {
        $installDir = "$env:LOCALAPPDATA\WinToolkit\7zip"
        $executablePath = "$installDir\7zr.exe"
        
        if (Test-Path $executablePath) {
            Write-StyledMessage Success "7-Zip portable già presente"
            return $executablePath
        }
        
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
        
        $downloadSources = @(
            @{ Url = $AppConfig.URLs.GitHubAssetBaseUrl + "7zr.exe"; Name = "Repository MagnetarMan" },
            @{ Url = $AppConfig.URLs.SevenZipOfficial; Name = "Sito ufficiale 7-Zip" }
        )
        
        foreach ($source in $downloadSources) {
            try {
                Write-StyledMessage Info "⬇️ Download 7-Zip da: $($source.Name)"
                Invoke-WebRequest -Uri $source.Url -OutFile $executablePath -UseBasicParsing -ErrorAction Stop
                
                if (Test-Path $executablePath) {
                    $fileSize = (Get-Item $executablePath).Length
                    
                    if ($fileSize -gt 100KB -and $fileSize -lt 10MB) {
                        $testResult = & $executablePath 2>&1
                        if ($testResult -match "7-Zip" -or $testResult -match "Licensed") {
                            Write-StyledMessage Success "7-Zip portable scaricato e verificato"
                            return $executablePath
                        }
                    }
                    
                    Write-StyledMessage Warning "File scaricato non valido (Dimensione: $fileSize bytes)"
                    Remove-Item $executablePath -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-StyledMessage Warning "Download fallito da $($source.Name): $_"
                if (Test-Path $executablePath) { 
                    Remove-Item $executablePath -Force -ErrorAction SilentlyContinue 
                }
            }
        }
        
        Write-StyledMessage Error "Impossibile scaricare 7-Zip da tutte le fonti"
        return $null
    }
    
    function Compress-BackupArchive {
        param([string]$SevenZipPath)
        
        if (-not $SevenZipPath -or -not (Test-Path $SevenZipPath)) {
            throw "Percorso 7-Zip non valido: $SevenZipPath"
        }
        
        if (-not (Test-Path $script:BackupConfig.BackupDir)) {
            throw "Directory backup non trovata: $($script:BackupConfig.BackupDir)"
        }
        
        Write-StyledMessage Info "📦 Preparazione compressione archivio..."
        
        $backupFiles = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
        if (-not $backupFiles) {
            Write-StyledMessage Warning "Nessun file da comprimere nella directory backup"
            return $null
        }
        
        $totalSizeMB = [Math]::Round(($backupFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-StyledMessage Info "Dimensione totale: $totalSizeMB MB"
        
        $archivePath = "$($script:BackupConfig.TempPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).7z"
        $compressionArgs = @('a', '-t7z', '-mx=6', '-mmt=on', "`"$archivePath`"", "`"$($script:BackupConfig.BackupDir)\*`"")
        
        # File per reindirizzare l'output di 7zip
        $stdOutputPath = "$($script:BackupConfig.LogsDir)\7zip_$($script:BackupConfig.DateTime).log"
        $stdErrorPath = "$($script:BackupConfig.LogsDir)\7zip_err_$($script:BackupConfig.DateTime).log"
        
        try {
            Write-StyledMessage Info "🚀 Compressione con 7-Zip..."

            # Usa Invoke-WithSpinner per monitorare il processo 7zip
            $result = Invoke-WithSpinner -Activity "Compressione archivio 7-Zip" -Process -Action {
                $procParams = @{
                    FilePath               = $SevenZipPath
                    ArgumentList           = $compressionArgs
                    NoNewWindow            = $true
                    PassThru               = $true
                    RedirectStandardOutput = $stdOutputPath
                    RedirectStandardError  = $stdErrorPath
                }
                Start-Process @procParams
            } -TimeoutSeconds 600 -UpdateInterval 1000
            
            if ($result.TimedOut) {
                throw "Timeout raggiunto durante la compressione"
            }
            
            if ($result.ExitCode -eq 0 -and (Test-Path $archivePath)) {
                $compressedSizeMB = [Math]::Round((Get-Item $archivePath).Length / 1MB, 2)
                $compressionRatio = [Math]::Round((1 - $compressedSizeMB / $totalSizeMB) * 100, 1)
                
                Write-StyledMessage Success "Compressione completata: $compressedSizeMB MB (Riduzione: $compressionRatio%)"
                return $archivePath
            }
            else {
                # Log degli errori di 7zip per debugging
                $errorDetails = if (Test-Path $stdErrorPath) {
                    $errorContent = Get-Content $stdErrorPath -ErrorAction SilentlyContinue
                    if ($errorContent) { $errorContent -join '; ' } else { "Log errori vuoto" }
                }
                else { "File di log errori non trovato" }
                
                Write-StyledMessage Error "Compressione fallita (ExitCode: $($result.ExitCode)). Dettagli: $errorDetails"
                return $null
            }
        }
        finally {
            # Log conservati in $script:BackupConfig.LogsDir per debugging
        }
    }
    
    function Move-ArchiveToDesktop {
        param([string]$ArchivePath)
        
        if ([string]::IsNullOrWhiteSpace($ArchivePath) -or -not (Test-Path $ArchivePath)) {
            throw "Percorso archivio non valido: $ArchivePath"
        }
        
        Write-StyledMessage Info "📂 Spostamento archivio su desktop..."
        
        try {
            if (-not (Test-Path $script:BackupConfig.DesktopPath)) {
                throw "Directory desktop non accessibile: $($script:BackupConfig.DesktopPath)"
            }
            
            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage Warning "Rimozione archivio precedente..."
                Remove-Item $script:FinalArchivePath -Force -ErrorAction Stop
            }
            
            Copy-Item -Path $ArchivePath -Destination $script:FinalArchivePath -Force -ErrorAction Stop
            
            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage Success "Archivio salvato sul desktop"
                Write-StyledMessage Info "Posizione: $script:FinalArchivePath"
                return $true
            }
            
            throw "Copia archivio fallita"
        }
        catch {
            Write-StyledMessage Error "Errore spostamento archivio: $_"
            return $false
        }
    }

    try {
        if (-not (Test-AdministratorPrivilege)) {
            Write-StyledMessage Error "❌ Privilegi amministratore richiesti"
            Write-StyledMessage Info "💡 Riavvia PowerShell come Amministratore"
            Read-Host "`nPremi INVIO per uscire"
            return
        }
        
        Write-StyledMessage Info "🚀 Inizializzazione sistema..."
        Start-Sleep -Seconds 1
        
        if (Initialize-BackupEnvironment) {
            Write-Host ""
            
            if (Export-SystemDrivers) {
                Write-Host ""
                
                $sevenZipPath = (Resolve-7ZipExecutable | Select-Object -Last 1)
                if ($sevenZipPath) {
                    Write-Host ""
                    
                    $compressedArchive = Compress-BackupArchive -SevenZipPath $sevenZipPath
                    if ($compressedArchive) {
                        Write-Host ""
                        
                        if (Move-ArchiveToDesktop -ArchivePath $compressedArchive) {
                            Write-Host ""
                            Write-StyledMessage Success "🎉 Backup driver completato con successo!"
                            Write-StyledMessage Info "📁 Archivio finale: $script:FinalArchivePath"
                            Write-StyledMessage Info "💾 Utilizzabile per reinstallare tutti i driver"
                            Write-StyledMessage Info "🔧 Senza doverli riscaricare singolarmente"
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-StyledMessage Error "Errore critico durante backup: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Controlla i log per dettagli tecnici"
    }
    finally {
        Write-StyledMessage Info "🧹 Pulizia ambiente temporaneo..."
        if (Test-Path $script:BackupConfig.BackupDir) {
            Remove-Item $script:BackupConfig.BackupDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        if (-not $SuppressIndividualReboot) {
            Write-Host "`nPremi INVIO per terminare..." -ForegroundColor Gray
            Read-Host | Out-Null
        }
        
        try { Stop-Transcript | Out-Null } catch {}
        Write-StyledMessage Success "🎯 Driver Backup Toolkit terminato"
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

    .PARAMETER CountdownSeconds
        Numero di secondi per il countdown prima del riavvio.

    .OUTPUTS
        None. La funzione non restituisce output.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,
        
        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName "OfficeToolkit"
    Show-Header -SubTitle "Office Toolkit"
    $Host.UI.RawUI.WindowTitle = "Office Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    $TempDir = $AppConfig.Paths.OfficeTemp

    # ============================================================================
    # 3. FUNZIONI HELPER LOCALI
    # ============================================================================
    function Clear-ConsoleLine {
        $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
        Write-Host $clearLine -NoNewline
        [Console]::Out.Flush()
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
            Write-StyledMessage -Type 'Warning' -Text "Impossibile rilevare versione Windows: $_"
            return "Unknown"
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
                @{ Url = $AppConfig.URLs.OfficeSetup; Path = $setupPath; Name = 'Setup Office' },
                @{ Url = $AppConfig.URLs.OfficeBasicConfig; Path = $configPath; Name = 'Configurazione Basic' }
            )

            foreach ($download in $downloads) {
                if (-not (Invoke-DownloadFile $download.Url $download.Path $download.Name)) {
                    return $false
                }
            }

            Write-StyledMessage Info "🚀 Avvio processo installazione..."
            $arguments = "/configure `"$configPath`""
            $procParams = @{
                FilePath         = $setupPath
                ArgumentList     = $arguments
                WorkingDirectory = $TempDir
                Wait             = $true
            }
            Write-StyledMessage Info "⏳ Installazione in corso, attendere il completamento in background..."
            Start-Process @procParams

            # Nuove configurazioni post-installazione: Disabilitazione Telemetria e Notifiche Crash
            Write-StyledMessage Info "⚙️ Configurazione post-installazione Office..."

            # Configurazione telemetria Office
            Write-StyledMessage Info "⚙️ Disabilitazione telemetria Office..."
            $RegPathTelemetry = $AppConfig.Registry.OfficeTelemetry
            if (-not (Test-Path $RegPathTelemetry)) { New-Item $RegPathTelemetry -Force | Out-Null }
            Set-ItemProperty -Path $RegPathTelemetry -Name "DisableTelemetry" -Value 1 -Type DWord -Force
            Write-StyledMessage Success "✅ Telemetria Office disabilitata"

            # Configurazione notifiche crash Office
            Write-StyledMessage Info "⚙️ Disabilitazione notifiche crash Office..."
            $RegPathFeedback = $AppConfig.Registry.OfficeFeedback
            if (-not (Test-Path $RegPathFeedback)) { New-Item $RegPathFeedback -Force | Out-Null }
            Set-ItemProperty -Path $RegPathFeedback -Name "OnBootNotify" -Value 0 -Type DWord -Force
            Write-StyledMessage Success "✅ Notifiche crash Office disabilitate"
            # Fine nuove configurazioni

            Write-StyledMessage Success "Installazione completata"
            Write-StyledMessage Info "Riavvio non necessario"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore durante installazione Office: $($_.Exception.Message)"
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

        $officeClient = "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
        if (-not (Test-Path $officeClient)) {
            $officeClient = "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
        }

        try {
            Write-StyledMessage Info "🔧 Avvio riparazione rapida (offline)..."
            $argumentsQuick = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=QuickRepair DisplayLevel=True"
            $procParamsQuick = @{
                FilePath     = $officeClient
                ArgumentList = $argumentsQuick
                Wait         = $true
            }
            Start-Process @procParamsQuick

            if (Get-UserConfirmation "✅ La riparazione rapida ha risolto il problema?" 'Y') {
                Write-StyledMessage Success "🎉 Riparazione Office completata!"
                return $true
            }
            else {
                Write-StyledMessage Info "🌐 Avvio riparazione completa (online)..."
                $argumentsFull = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True"
                $procParamsFull = @{
                    FilePath     = $officeClient
                    ArgumentList = $argumentsFull
                    Wait         = $true
                }
                Start-Process @procParamsFull

                Write-StyledMessage Success "🎉 Riparazione Office completata!"
                return $true
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante riparazione Office: $($_.Exception.Message)"
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
                                $procParams = @{
                                    FilePath     = 'msiexec.exe'
                                    ArgumentList = @('/x', $productCode, '/qn', '/norestart')
                                    Wait         = $true
                                    NoNewWindow  = $true
                                    ErrorAction  = 'Stop'
                                }
                                Start-Process @procParams
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
            Write-StyledMessage Error "Errore durante rimozione diretta Office: $($_.Exception.Message)"
            return $false
        }
    }

    function Start-OfficeUninstallWithSaRA {
        try {
            if (-not (Test-Path $TempDir)) {
                New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
            }

            $saraUrl = $AppConfig.URLs.SaRAInstaller
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
                Write-StyledMessage Error "Errore durante estrazione archivio SaRA: $($_.Exception.Message)"
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
                $procParams = @{
                    FilePath     = $saraExe.FullName
                    ArgumentList = $arguments
                    Verb         = 'RunAs'
                    PassThru     = $true
                    Wait         = $true
                    ErrorAction  = 'Stop'
                }
                $process = Start-Process @procParams

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
                Write-StyledMessage Warning "Errore durante esecuzione SaRA: $($_.Exception.Message)"
                Write-StyledMessage Info "💡 Passaggio a metodo alternativo..."
                return Remove-OfficeDirectly
            }
        }
        catch {
            Write-StyledMessage Warning "Errore durante processo SaRA: $($_.Exception.Message)"
            return $false
        }
        finally {
            Invoke-SilentRemoval -Path $TempDir -Recurse
        }
    }

    function Start-OfficeUninstall {
        Write-StyledMessage Warning "🗑️ Avvio rimozione completa Microsoft Office..."

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
                $success = Remove-OfficeDirectly
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

    # MAIN EXECUTION
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
                    if ($choice -ne '1') {
                        Write-StyledMessage Success "🎉 $operation completata!"
                        if (Get-UserConfirmation "🔄 Riavviare ora per finalizzare?" 'Y') {
                            if ($SuppressIndividualReboot) {
                                $Global:NeedsFinalReboot = $true
                                Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
                            }
                            else {
                                Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "$operation completata"
                                Restart-Computer -Force
                            }
                        }
                        else {
                            Write-StyledMessage Info "💡 Riavvia manualmente quando possibile"
                        }
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
        Write-StyledMessage Error "Errore critico durante esecuzione OfficeToolkit: $($_.Exception.Message)"
    }
    finally {
        Write-StyledMessage Success "🧹 Pulizia finale..."
        Invoke-SilentRemoval -Path $TempDir -Recurse

        Write-StyledMessage Success "🎯 Office Toolkit terminato"
        try { Stop-Transcript | Out-Null } catch {}
    }
}
function WinCleaner {
    <#
    .SYNOPSIS
        Script automatico per la pulizia completa del sistema Windows.

    .DESCRIPTION
        Esegue una pulizia completa utilizzando un motore basato su regole.
        Include protezione vitale per cartelle critiche e gestione unificata di file, registro e servizi.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 300)]
        [int]$CountdownSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # Initialize global execution log BEFORE any function calls
    $global:WinCleanerLog = @()


    # ============================================================================
    # FUNZIONI GLOBALI LOCALI
    # ============================================================================

    function Clear-ProgressLine {
        if ($Host.Name -eq 'ConsoleHost') {
            try {
                $width = $Host.UI.RawUI.WindowSize.Width - 1
                Write-Host "`r$(' ' * $width)" -NoNewline
                Write-Host "`r" -NoNewline
            }
            catch {
                # Fallback for non-console hosts or errors
                Write-Host "`r                                                                                `r" -NoNewline
            }
        }
    }

    function Write-StyledMessage {
        param(
            [Parameter(Mandatory = $true, Position = 0)]
            [ValidateSet('Success', 'Info', 'Warning', 'Error', 'Question')]
            [string]$Type,

            [Parameter(Mandatory = $true, Position = 1)]
            [string]$Text
        )

        Clear-ProgressLine

        # Add to execution log
        $logEntry = @{
            Timestamp = Get-Date -Format "HH:mm:ss"
            Type      = $Type
            Text      = $Text
        }
        $global:WinCleanerLog += $logEntry

        $colorMap = @{
            'Success'  = 'Green'
            'Info'     = 'Cyan'
            'Warning'  = 'Yellow'
            'Error'    = 'Red'
            'Question' = 'White'
        }

        $iconMap = @{
            'Success'  = '✅'
            'Info'     = 'ℹ️'
            'Warning'  = '⚠️'
            'Error'    = '❌'
            'Question' = '❓'
        }

        $color = $colorMap[$Type]
        $icon = $iconMap[$Type]

        Write-Host "[$($logEntry.Timestamp)] $icon $Text" -ForegroundColor $color
    }

    # ============================================================================
    # 1. INIZIALIZZAZIONE CON FRAMEWORK GLOBALE
    # ============================================================================

    Initialize-ToolLogging -ToolName "WinCleaner"
    Show-Header -SubTitle "Cleaner Toolkit"
    $Host.UI.RawUI.WindowTitle = "Cleaner Toolkit By MagnetarMan"

    $ProgressPreference = 'Continue'

    # ============================================================================
    # 2. ESCLUSIONI VITALI
    # ============================================================================

    $VitalExclusions = @(
        "$env:LOCALAPPDATA\WinToolkit"
    )

    # ============================================================================
    # 3. FUNZIONI CORE
    # ============================================================================

    function Test-VitalExclusion {
        param([string]$Path)
        if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
        $fullPath = $Path -replace '"', '' # Remove quotes
        try {
            if (-not [System.IO.Path]::IsPathRooted($fullPath)) {
                $fullPath = Join-Path (Get-Location) $fullPath
            }
            foreach ($excluded in $VitalExclusions) {
                if ($fullPath -like "$excluded*" -or $fullPath -eq $excluded) {
                    Write-StyledMessage -Type 'Info' -Text "🛡️ PROTEZIONE VITALE ATTIVATA: $fullPath"
                    return $true
                }
            }
        }
        catch { return $false }
        return $false
    }

    function Start-ProcessWithTimeout {
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

        $processParams = @{
            FilePath     = $FilePath
            ArgumentList = $ArgumentList
            PassThru     = $true
            ErrorAction  = 'Stop'
        }

        if ($Hidden) {
            $processParams.WindowStyle = 'Hidden'
        }
        else {
            $processParams.NoNewWindow = $true
        }

        $proc = Start-Process @processParams

        # Usa la funzione globale Invoke-WithSpinner per monitorare il processo
        $result = Invoke-WithSpinner -Activity $Activity -Process -Action { $proc } -TimeoutSeconds $TimeoutSeconds -UpdateInterval 500

        return $result
    }

    function Invoke-CommandAction {
        param($Rule)
        Write-StyledMessage -Type 'Info' -Text "🚀 Esecuzione comando: $($Rule.Name)"
        try {
            # Use timeout for potentially long-running commands
            $timeoutCommands = @("DISM.exe", "cleanmgr.exe")
            if ($Rule.Command -in $timeoutCommands) {
                $result = Start-ProcessWithTimeout -FilePath $Rule.Command -ArgumentList $Rule.Args -TimeoutSeconds 900 -Activity $Rule.Name -Hidden
                if ($result.TimedOut) {
                    Write-StyledMessage -Type 'Warning' -Text "Comando timeout dopo 15 minuti"
                    return $true # Non-fatal
                }
                if ($result.ExitCode -eq 0) { return $true }
                Write-StyledMessage -Type 'Warning' -Text "Comando completato con codice $($result.ExitCode)"
                return $true # Non-fatal
            }
            else {
                $procParams = @{
                    FilePath     = $Rule.Command
                    ArgumentList = $Rule.Args
                    PassThru     = $true
                    WindowStyle  = 'Hidden'
                    Wait         = $true
                    ErrorAction  = 'SilentlyContinue'
                }
                $proc = Start-Process @procParams
                if ($proc.ExitCode -eq 0) { return $true }
                # Suppress warning if exit code is null (process failed to start)
                if ($null -ne $proc.ExitCode) {
                    Write-StyledMessage -Type 'Warning' -Text "Comando completato con codice $($proc.ExitCode)"
                }
                return $true # Non-fatal
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore comando: $_"
            return $false
        }
    }

    function Invoke-ServiceAction {
        param($Rule)
        $svcName = $Rule.ServiceName
        $action = $Rule.Action # Start/Stop

        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if (-not $svc) { return $true }

            if ($action -eq 'Stop' -and $svc.Status -eq 'Running') {
                Write-StyledMessage -Type 'Info' -Text "⏸️ Arresto servizio $svcName..."
                Stop-Service -Name $svcName -Force -ErrorAction Stop | Out-Null
            }
            elseif ($action -eq 'Start' -and $svc.Status -ne 'Running') {
                Write-StyledMessage -Type 'Info' -Text "▶️ Avvio servizio $svcName..."
                Start-Service -Name $svcName -ErrorAction Stop | Out-Null
            }
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore servizio $svcName : $_"
            return $false
        }
    }

    function Remove-FileItem {
        param($Rule)
        $paths = $Rule.Paths
        $isPerUser = $Rule.PerUser
        $filesOnly = $Rule.FilesOnly
        $takeOwn = $Rule.TakeOwnership

        $targetPaths = @()
        if ($isPerUser) {
            $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^(Public|Default|All Users)$' }
            foreach ($user in $users) {
                foreach ($p in $paths) {
                    $targetPaths += $p -replace '%USERPROFILE%', $user.FullName `
                        -replace '%APPDATA%', "$($user.FullName)\AppData\Roaming" `
                        -replace '%LOCALAPPDATA%', "$($user.FullName)\AppData\Local" `
                        -replace '%TEMP%', "$($user.FullName)\AppData\Local\Temp"
                }
            }
        }
        else {
            foreach ($p in $paths) { $targetPaths += [Environment]::ExpandEnvironmentVariables($p) }
        }

        $count = 0
        foreach ($path in $targetPaths) {
            if (Test-VitalExclusion $path) { continue }
            if (-not (Test-Path $path)) { continue }

            try {
                if ($takeOwn) {
                    Write-StyledMessage -Type 'Info' -Text "🔑 Assunzione proprietà per $path..."
                    $null = & cmd /c "takeown /F `"$path`" /R /A >nul 2>&1"

                    $adminSID = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
                    $adminAccount = $adminSID.Translate([System.Security.Principal.NTAccount]).Value
                    $null = & cmd /c "icacls `"$path`" /T /grant `"${adminAccount}:F`" >nul 2>&1"
                }

                if ($filesOnly) {
                    $files = Get-ChildItem -Path $path -File -Force -ErrorAction SilentlyContinue
                    foreach ($file in $files) {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    }
                }
                else {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                }
                $count++
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore rimozione $path : $_"
            }
        }
        if ($count -gt 0) { Write-StyledMessage -Type 'Success' -Text "🗑️ Puliti $count elementi in $($Rule.Name)" }
        return $true
    }

    function Remove-RegistryItem {
        param($Rule)
        $keys = $Rule.Keys
        $recursive = $Rule.Recursive
        $valuesOnly = $Rule.ValuesOnly # If true, clear values but keep key

        foreach ($rawKey in $keys) {
            $key = $rawKey -replace '^(HKCU|HKLM):\\*', '$1:\'
            if (-not (Test-Path $key)) { continue }
            try {
                if ($valuesOnly) {
                    $item = Get-Item $key -ErrorAction Stop
                    $item.GetValueNames() | ForEach-Object {
                        if ($_ -ne '(default)') { Remove-ItemProperty -LiteralPath $key -Name $_ -Force -ErrorAction SilentlyContinue | Out-Null }
                    }
                    if ($recursive) {
                        Get-ChildItem $key -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                            $currentKeyPath = $_.PSPath
                            $_.GetValueNames() | ForEach-Object { Remove-ItemProperty -LiteralPath $currentKeyPath -Name $_ -Force -ErrorAction SilentlyContinue | Out-Null }
                        }
                    }
                    Write-StyledMessage -Type 'Success' -Text "⚙️ Puliti valori in $key"
                }
                else {
                    Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop | Out-Null
                    Write-StyledMessage -Type 'Success' -Text "🗑️ Rimossa chiave $key"
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore registro $key : $_"
            }
        }
        return $true
    }

    function Set-RegistryItem {
        param($Rule)
        $key = $Rule.Key -replace '^(HKCU|HKLM):', '$1:\'
        try {
            if (-not (Test-Path $key)) { New-Item -Path $key -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $key -Name $Rule.ValueName -Value $Rule.ValueData -Type $Rule.ValueType -Force -ErrorAction SilentlyContinue | Out-Null
            Write-StyledMessage -Type 'Success' -Text "⚙️ Impostato $key\$($Rule.ValueName)"
            return $true
        }
        catch { return $false }
    }

    function Invoke-WinCleanerRule {
        param($Rule)
        switch ($Rule.Type) {
            'File' { return Remove-FileItem -Rule $Rule }
            'Registry' { return Remove-RegistryItem -Rule $Rule }
            'RegSet' { return Set-RegistryItem -Rule $Rule }
            'Service' { return Invoke-ServiceAction -Rule $Rule }
            'Command' { return Invoke-CommandAction -Rule $Rule }
            'ScriptBlock' {
                # Operazioni multi-passo complesse
                if ($Rule.ScriptBlock) {
                    & $Rule.ScriptBlock
                    return $true
                }
            }
            'Custom' {
                # Operazioni complesse specializzate
                if ($Rule.ScriptBlock) {
                    & $Rule.ScriptBlock
                    return $true
                }
            }
        }
        return $true
    }

    # ============================================================================
    # 4. DEFINIZIONE REGOLE
    # ============================================================================

    $Rules = @(
        # --- CleanMgr Auto ---
        @{ Name = "CleanMgr Config"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage -Type 'Info' -Text "🧹 Configurazione CleanMgr..."
                $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
                $opts = @(
                    "Active Setup Temp Folders",
                    "BranchCache",
                    "D3D Shader Cache",
                    "Delivery Optimization Files",
                    "Downloaded Program Files",
                    "Internet Cache Files",
                    "Memory Dump Files",
                    "Recycle Bin",
                    "Temporary Files",
                    "Thumbnail Cache",
                    "Windows Error Reporting Files",
                    "Setup Log Files",
                    "System error memory dump files",
                    "System error minidump files",
                    "Temporary Setup Files",
                    "Windows Upgrade Log Files"
                )
                foreach ($o in $opts) {
                    $p = Join-Path $reg $o
                    if (Test-Path $p) { Set-ItemProperty -Path $p -Name "StateFlags0065" -Value 2 -Type DWORD -Force -ErrorAction SilentlyContinue }
                }

                # Esegui cleanmgr.exe attendendo il completamento, sfruttando Invoke-CommandAction
                # che include già logica di timeout per cleanmgr.exe e gestisce la visualizzazione.
                $cleanMgrExecutionRule = @{
                    Name    = "Esecuzione CleanMgr con /sagerun:65";
                    Type    = "Command";
                    Command = "cleanmgr.exe";
                    Args    = @("/sagerun:65");
                }
                Invoke-CommandAction -Rule $cleanMgrExecutionRule
            }
        }

        # --- WinSxS ---
        @{ Name = "WinSxS Cleanup"; Type = "Command"; Command = "DISM.exe"; Args = @("/Online", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase") }
        @{ Name = "Minimize DISM"; Type = "RegSet"; Key = "HKLM:\Software\Microsoft\Windows\CurrentVersion\SideBySide\Configuration"; ValueName = "DisableResetbase"; ValueData = 0; ValueType = "DWORD" }

        # --- Error Reports ---
        @{ Name = "Error Reports"; Type = "File"; Paths = @(
                "$env:ProgramData\Microsoft\Windows\WER",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\WER"
            ); FilesOnly = $false
        }

        # --- Event Logs ---
        @{ Name = "Clear Event Logs"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage -Type 'Info' -Text "📜 Pulizia Event Logs..."
                & wevtutil sl 'Microsoft-Windows-LiveId/Operational' /ca:'O:BAG:SYD:(A;;0x1;;;SY)(A;;0x5;;;BA)(A;;0x1;;;LA)' 2>$null
                Get-WinEvent -ListLog * -Force -ErrorAction SilentlyContinue | ForEach-Object { Wevtutil.exe cl $_.LogName 2>$null }
            }
        }

        # --- Windows Update ---
        @{ Name = "Stop - Windows Update Service"; Type = "Service"; ServiceName = "wuauserv"; Action = "Stop" }
        @{ Name = "Stop - BITS Service"; Type = "Service"; ServiceName = "bits"; Action = "Stop" }
        @{ Name = "Cleanup - Windows Update Cache"; Type = "File"; Paths = @(
                "C:\WINDOWS\SoftwareDistribution\DataStore",
                "C:\WINDOWS\SoftwareDistribution\Download"
            ); FilesOnly = $false
        }
        @{ Name = "Start - BITS Service"; Type = "Service"; ServiceName = "bits"; Action = "Start" }
        @{ Name = "Start - Windows Update Service"; Type = "Service"; ServiceName = "wuauserv"; Action = "Start" }

        # --- Windows App/Download Cache ---
        @{ Name = "Windows App/Download Cache - System"; Type = "File"; Paths = @("C:\WINDOWS\SoftwareDistribution\Download"); FilesOnly = $true }
        @{ Name = "Windows App/Download Cache - User"; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Microsoft\Windows\AppCache",
                "%LOCALAPPDATA%\Microsoft\Windows\Caches"
            ); PerUser = $true; FilesOnly = $true
        }

        # --- Restore Points ---
        @{ Name = "System Restore Points"; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Write-StyledMessage -Type 'Info' -Text "💾 Pulizia punti di ripristino sistema..."

                    Write-StyledMessage -Type 'Info' -Text "🗑️ Analisi e pulizia shadow copies (mantieni ultima)..."
                    try {
                        $shadows = Get-CimInstance -ClassName Win32_ShadowCopy -ErrorAction Stop | Sort-Object InstallDate -Descending
                        if ($shadows.Count -gt 1) {
                            $toDelete = $shadows | Select-Object -Skip 1
                            $count = $toDelete.Count
                            Write-StyledMessage -Type 'Info' -Text "Rilevate $($shadows.Count) shadow copies. Rimozione di $count vecchie..."
                            
                            foreach ($shadow in $toDelete) {
                                Remove-CimInstance -InputObject $shadow -ErrorAction SilentlyContinue
                            }
                            Write-StyledMessage -Type 'Success' -Text "Vecchie shadow copies rimosse. Ultima copia preservata."
                        }
                        elseif ($shadows.Count -eq 1) {
                            Write-StyledMessage -Type 'Info' -Text "Trovata una sola shadow copy. Nessuna rimozione necessaria."
                        }
                        else {
                            Write-StyledMessage -Type 'Info' -Text "Nessuna shadow copy rilevata."
                        }
                    }
                    catch {
                        Write-StyledMessage -Type 'Warning' -Text "Errore gestione shadow copies: $_"
                    }

                    Write-StyledMessage -Type 'Info' -Text "💡 Protezione sistema mantenuta attiva per sicurezza"
                    Write-StyledMessage -Type 'Success' -Text "Pulizia punti di ripristino completata"
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Errore durante la pulizia punti di ripristino: $($_.Exception.Message)"
                }
            }
        }

        # --- Prefetch ---
        @{ Name = "Cleanup - Windows Prefetch Cache"; Type = "File"; Paths = @("C:\WINDOWS\Prefetch"); FilesOnly = $false }

        # --- Thumbnails ---
        @{ Name = "Cleanup - Explorer Thumbnail/Icon Cache"; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\Explorer"); PerUser = $true; FilesOnly = $true; TakeOwnership = $true }

        # --- Browser & Web Cache (Consolidato) ---
        @{ Name = "WinInet Cache - User"; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Microsoft\Windows\INetCache\IE",
                "%LOCALAPPDATA%\Microsoft\Windows\WebCache",
                "%LOCALAPPDATA%\Microsoft\Feeds Cache",
                "%LOCALAPPDATA%\Microsoft\InternetExplorer\DOMStore",
                "%LOCALAPPDATA%\Microsoft\Internet Explorer"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Temporary Internet Files"; Type = "File"; Paths = @(
                "%USERPROFILE%\Local Settings\Temporary Internet Files"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Cache/History Cleanup"; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "8") }
        @{ Name = "Form Data Cleanup"; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "2") }
        @{ Name = "Internet Cookies Cleanup"; Type = "File"; Paths = @(
                "%APPDATA%\Microsoft\Windows\Cookies",
                "%LOCALAPPDATA%\Microsoft\Windows\INetCookies"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Cookies Cleanup"; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "1") }
        @{ Name = "Chromium Browsers Cache (Chrome, Edge, Brave, Vivaldi)"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage -Type 'Info' -Text "🌐 Pulizia Cache Browser Chromium..."

                $browsers = @(
                    @{ Name = "Google Chrome"; Path = "Google\Chrome\User Data" },
                    @{ Name = "Microsoft Edge"; Path = "Microsoft\Edge\User Data" },
                    @{ Name = "Brave Browser"; Path = "BraveSoftware\Brave-Browser\User Data" },
                    @{ Name = "Vivaldi"; Path = "Vivaldi\User Data" }
                )

                $users = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notmatch '^(Public|Default|All Users)$' }
                foreach ($u in $users) {
                    foreach ($b in $browsers) {
                        $userDataPath = Join-Path "$($u.FullName)\AppData\Local" $b.Path
                        if (Test-Path $userDataPath) {
                            $patterns = @(
                                "$userDataPath\*\Cache",
                                "$userDataPath\*\Code Cache",
                                "$userDataPath\*\GPUCache",
                                "$userDataPath\*\ShaderCache",
                                "$userDataPath\CrashReports"
                            )
                            foreach ($p in $patterns) {
                                Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                }
            }
        }
        @{ Name = "Firefox Browser Cache"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage -Type 'Info' -Text "🦊 Pulizia Firefox (Cache & Crashes)..."

                $users = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notmatch '^(Public|Default|All Users)$' }
                foreach ($u in $users) {
                    # Standard Firefox (Cache in Local AppData)
                    $cleanPaths = @(
                        "$($u.FullName)\AppData\Local\Mozilla\Firefox\Profiles",
                        "$($u.FullName)\AppData\Local\Mozilla\Firefox\Crash Reports"
                    )
                    foreach ($p in $cleanPaths) {
                        if (Test-Path $p) { Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue }
                    }

                    # Microsoft Store Firefox (UWP)
                    $msStoreProfiles = Get-ChildItem `
                        "$($u.FullName)\AppData\Local\Packages" `
                        -Directory -Filter "Mozilla.Firefox_*" `
                        -ErrorAction SilentlyContinue
                    foreach ($pkg in $msStoreProfiles) {
                        $msCache = "$($pkg.FullName)\LocalCache\Roaming\Mozilla\Firefox\Profiles"
                        if (Test-Path $msCache) { Remove-Item -Path $msCache -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                }
            }
        }
        @{ Name = "Edge Legacy (HTML) Cache"; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC\*\MicrosoftEdge\Cache",
                "%LOCALAPPDATA%\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC\#!001\MicrosoftEdge\Cache"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Opera & Java Cache"; Type = "File"; Paths = @(
                "%USERPROFILE%\Local Settings\Application Data\Opera\Opera",
                "%LOCALAPPDATA%\Opera\Opera",
                "%APPDATA%\Opera\Opera",
                "%APPDATA%\Sun\Java\Deployment\cache"
            ); PerUser = $true; FilesOnly = $false
        }

        @{ Name = "DNS Flush"; Type = "Command"; Command = "ipconfig"; Args = @("/flushdns") }

        # --- Temp Files (Consolidato) ---
        @{ Name = "System Temp Files"; Type = "File"; Paths = @("C:\WINDOWS\Temp"); FilesOnly = $false }
        @{ Name = "User Temp Files"; Type = "File"; Paths = @(
                "%TEMP%",
                "%USERPROFILE%\AppData\Local\Temp",
                "%USERPROFILE%\AppData\LocalLow\Temp"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Service Profiles Temp"; Type = "File"; Paths = @("%SYSTEMROOT%\ServiceProfiles\LocalService\AppData\Local\Temp"); FilesOnly = $false }

        # --- System & Component Logs ---
        @{ Name = "System & Component Logs"; Type = "File"; Paths = @(
                "C:\WINDOWS\Logs",
                "C:\WINDOWS\System32\LogFiles",
                "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
                "%SYSTEMROOT%\Logs\waasmedic",
                "%SYSTEMROOT%\Logs\SIH",
                "%SYSTEMROOT%\Logs\NetSetup",
                "%SYSTEMROOT%\System32\LogFiles\setupcln",
                "%SYSTEMROOT%\Panther",
                "%SYSTEMROOT%\comsetup.log",
                "%SYSTEMROOT%\DtcInstall.log",
                "%SYSTEMROOT%\PFRO.log",
                "%SYSTEMROOT%\setupact.log",
                "%SYSTEMROOT%\setuperr.log",
                "%SYSTEMROOT%\inf\setupapi.app.log",
                "%SYSTEMROOT%\inf\setupapi.dev.log",
                "%SYSTEMROOT%\inf\setupapi.offline.log",
                "%SYSTEMROOT%\Performance\WinSAT\winsat.log",
                "%SYSTEMROOT%\debug\PASSWD.LOG"
            ); FilesOnly = $true
        }

        # --- User Registry History ---
        @{ Name = "User Registry History - Values Only"; Type = "Registry"; Keys = @(
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRULegacy",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Paint\Recent File List",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Wordpad\Recent File List",
                "HKCU:\Software\Microsoft\MediaPlayer\Player\RecentFileList",
                "HKCU:\Software\Microsoft\MediaPlayer\Player\RecentURLList",
                "HKCU:\Software\Gabest\Media Player Classic\Recent File List",
                "HKCU:\Software\Microsoft\Direct3D\MostRecentApplication",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths",
                "HKCU:\Software\Microsoft\Search Assistant\ACMru",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\SearchHistory",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Map Network Drive MRU"
            ); ValuesOnly = $true; Recursive = $true
        }
        @{ Name = "Adobe Media Browser Key"; Type = "Registry"; Keys = @("HKCU:\Software\Adobe\MediaBrowser\MRU"); ValuesOnly = $false }

        # --- Developer Telemetry (Consolidato) ---
        @{ Name = "Developer Telemetry & Traces"; Type = "File"; Paths = @(
                "%USERPROFILE%\.dotnet\TelemetryStorageService",
                "%LOCALAPPDATA%\Microsoft\CLR_v4.0\UsageTraces",
                "%LOCALAPPDATA%\Microsoft\CLR_v4.0_32\UsageTraces",
                "%LOCALAPPDATA%\Microsoft\VSCommon\14.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSCommon\15.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSCommon\16.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSCommon\17.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSApplicationInsights",
                "%TEMP%\Microsoft\VSApplicationInsights",
                "%APPDATA%\vstelemetry",
                "%TEMP%\VSFaultInfo",
                "%TEMP%\VSFeedbackPerfWatsonData",
                "%TEMP%\VSFeedbackVSRTCLogs",
                "%TEMP%\VSFeedbackIntelliCodeLogs",
                "%TEMP%\VSRemoteControl",
                "%TEMP%\Microsoft\VSFeedbackCollector",
                "%TEMP%\VSTelem",
                "%TEMP%\VSTelem.Out",
                "%PROGRAMDATA%\Microsoft\VSApplicationInsights",
                "%PROGRAMDATA%\vstelemetry"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Visual Studio Licenses"; Type = "Registry"; Keys = @(
                "HKLM:\SOFTWARE\Classes\Licenses\77550D6B-6352-4E77-9DA3-537419DF564B",
                "HKLM:\SOFTWARE\Classes\Licenses\E79B3F9C-6543-4897-BBA5-5BFB0A02BB5C",
                "HKLM:\SOFTWARE\Classes\Licenses\4D8CFBCB-2F6A-4AD2-BABF-10E28F6F2C8F",
                "HKLM:\SOFTWARE\Classes\Licenses\5C505A59-E312-4B89-9508-E162F8150517",
                "HKLM:\SOFTWARE\Classes\Licenses\41717607-F34E-432C-A138-A3CFD7E25CDA",
                "HKLM:\SOFTWARE\Classes\Licenses\B16F0CF0-8AD1-4A5B-87BC-CB0DBE9C48FC",
                "HKLM:\SOFTWARE\Classes\Licenses\10D17DBA-761D-4CD8-A627-984E75A58700",
                "HKLM:\SOFTWARE\Classes\Licenses\1299B4B9-DFCC-476D-98F0-F65A2B46C96D"
            ); ValuesOnly = $false
        }

        # --- Search History Files ---
        @{ Name = "Search History Files"; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\ConnectedSearch\History"); PerUser = $true }

        # --- Print Queue (Spooler) ---
        @{ Name = "Print Queue (Spooler)"; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Write-StyledMessage -Type 'Info' -Text "🖨️ Pulizia coda di stampa (Spooler)..."

                    Write-StyledMessage -Type 'Info' -Text "⏸️ Arresto servizio Spooler..."
                    Stop-Service -Name Spooler -Force -ErrorAction Stop | Out-Null
                    Write-StyledMessage -Type 'Info' -Text "Servizio Spooler arrestato."
                    Start-Sleep -Seconds 2

                    $printersPath = 'C:\WINDOWS\System32\spool\PRINTERS'
                    if (Test-Path $printersPath) {
                        $files = Get-ChildItem -Path $printersPath -Force -ErrorAction SilentlyContinue
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        Write-StyledMessage -Type 'Info' -Text "Coda di stampa pulita in $printersPath ($($files.Count) file rimossi)"
                    }

                    Write-StyledMessage -Type 'Info' -Text "▶️ Riavvio servizio Spooler..."
                    Start-Service -Name Spooler -ErrorAction Stop | Out-Null
                    Write-StyledMessage -Type 'Info' -Text "Servizio Spooler riavviato."

                    Write-StyledMessage -Type 'Success' -Text "Print Queue Spooler pulito e riavviato con successo."
                }
                catch {
                    Start-Service -Name Spooler -ErrorAction SilentlyContinue
                    Write-StyledMessage -Type 'Warning' -Text "Errore durante la pulizia Spooler: $($_.Exception.Message)"
                }
            }
        }

        # --- SRUM & Defender ---
        @{ Name = "Stop DPS"; Type = "Service"; ServiceName = "DPS"; Action = "Stop" }
        @{ Name = "SRUM Data"; Type = "File"; Paths = @("%SYSTEMROOT%\System32\sru\SRUDB.dat"); FilesOnly = $true; TakeOwnership = $true }
        @{ Name = "Start DPS"; Type = "Service"; ServiceName = "DPS"; Action = "Start" }

        # --- Utility Apps ---
        @{ Name = "Listary Index"; Type = "File"; Paths = @("%APPDATA%\Listary\UserData"); PerUser = $true }


        # --- Legacy Applications & Media ---
        @{ Name = "Flash Player Traces"; Type = "File"; Paths = @("%APPDATA%\Macromedia\Flash Player"); PerUser = $true }

        # --- Enhanced DiagTrack Service Management ---
        @{ Name = "Enhanced DiagTrack Management"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage -Type 'Info' -Text "🔄 Gestione migliorata servizio DiagTrack..."

                function Get-StateFilePath($BaseName, $Suffix) {
                    $escapedBaseName = $BaseName.Split([IO.Path]::GetInvalidFileNameChars()) -Join '_'
                    $uniqueFilename = $escapedBaseName, $Suffix -Join '-'
                    $path = [IO.Path]::Combine($env:APPDATA, 'WinToolkit', 'state', $uniqueFilename)
                    return $path
                }

                function Get-UniqueStateFilePath($BaseName) {
                    $suffix = New-Guid
                    $path = Get-StateFilePath -BaseName $BaseName -Suffix $suffix
                    if (Test-Path -Path $path) {
                        Write-Verbose "Path collision detected at: '$path'. Generating new path..."
                        return Get-UniqueStateFilePath $serviceName
                    }
                    return $path
                }

                function New-EmptyFile($Path) {
                    $parentDirectory = [System.IO.Path]::GetDirectoryName($Path)
                    if (-not (Test-Path $parentDirectory -PathType Container)) {
                        try { New-Item -ItemType Directory -Path $parentDirectory -Force -ErrorAction Stop | Out-Null }
                        catch { Write-StyledMessage -Type 'Warning' -Text "Failed to create parent directory: $_"; return $false }
                    }
                    try { New-Item -ItemType File -Path $Path -Force -ErrorAction Stop | Out-Null; return $true }
                    catch { Write-StyledMessage -Type 'Warning' -Text "Failed to create file: $_"; return $false }
                }

                $serviceName = 'DiagTrack'
                Write-StyledMessage -Type 'Info' -Text "Verifica stato servizio $serviceName..."

                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if (-not $service) {
                    Write-StyledMessage -Type 'Warning' -Text "Servizio $serviceName non trovato, skip"
                    return
                }

                if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                    Write-StyledMessage -Type 'Info' -Text "Servizio $serviceName attivo, arresto in corso..."
                    try {
                        $service | Stop-Service -Force -ErrorAction Stop
                        $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped, [TimeSpan]::FromSeconds(30))
                        $path = Get-UniqueStateFilePath $serviceName
                        if (New-EmptyFile $path) {
                            Write-StyledMessage -Type 'Success' -Text "Servizio arrestato e stato salvato - riavvio automatico abilitato"
                        }
                        else {
                            Write-StyledMessage -Type 'Warning' -Text "Servizio arrestato - riavvio manuale richiesto"
                        }
                    }
                    catch { Write-StyledMessage -Type 'Warning' -Text "Errore durante arresto servizio: $_" }
                }
                else {
                    Write-StyledMessage -Type 'Info' -Text "Servizio $serviceName non attivo, verifica riavvio..."
                    $fileGlob = Get-StateFilePath -BaseName $serviceName -Suffix '*'
                    $stateFiles = Get-ChildItem -Path $fileGlob -ErrorAction SilentlyContinue

                    if ($stateFiles.Count -eq 1) {
                        try {
                            Remove-Item -Path $stateFiles[0].FullName -Force -ErrorAction Stop
                            $service | Start-Service -ErrorAction Stop
                            Write-StyledMessage -Type 'Success' -Text "Servizio $serviceName riavviato con successo"
                        }
                        catch { Write-StyledMessage -Type 'Warning' -Text "Errore durante riavvio servizio: $_" }
                    }
                    elseif ($stateFiles.Count -gt 1) {
                        Write-StyledMessage -Type 'Info' -Text "Multiple state files found, servizio non verrà riavviato automaticamente"
                    }
                    else {
                        Write-StyledMessage -Type 'Info' -Text "Servizio $serviceName non era attivo precedentemente"
                    }
                }
            }
        }

        # --- Special Operations ---
        @{ Name = "Credential Manager"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage -Type 'Info' -Text "🔑 Pulizia Credenziali..."
                & cmdkey /list 2>$null | Where-Object { $_ -match '^Target:' } | ForEach-Object {
                    $t = $_.Split(':')[1].Trim()
                    & cmdkey /delete:$t 2>$null
                }
            }
        }
        @{ Name = "Regedit Last Key"; Type = "Registry"; Keys = @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit"); ValuesOnly = $true }
        @{ Name = "Windows.old"; Type = "ScriptBlock"; ScriptBlock = {
                $path = "C:\Windows.old"
                if (Test-Path $path) {
                    Write-StyledMessage -Type 'Info' -Text "🗑️ Rilevata cartella Windows.old. Avvio rimozione sicura con Native CleanMgr..."

                    # 1. Configura il registro per selezionare automaticamente "Previous Installations"
                    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations"
                    if (-not (Test-Path $regKey)) {
                        Write-StyledMessage -Type 'Warning' -Text "Chiave registro 'Previous Installations' non trovata. Tentativo di esecuzione standard."
                    }
                    else {
                        try {
                            Set-ItemProperty -Path $regKey -Name "StateFlags0066" -Value 2 -Type DWORD -Force -ErrorAction Stop
                            Write-StyledMessage -Type 'Info' -Text "✅ Configurazione CleanMgr attivata per Windows.old (StateFlags0066)."
                        }
                        catch {
                            Write-StyledMessage -Type 'Warning' -Text "Impossibile scrivere nel registro per CleanMgr: $_"
                        }
                    }

                    # 2. Esegui CleanMgr sfruttando la funzione di gestione processi sicura
                    # Utilizziamo Invoke-CommandAction simulando una regola per beneficiare del timeout e spinner
                    $cleanMgrRule = @{
                        Name    = "Rimozione Windows.old (CleanMgr)";
                        Type    = "Command";
                        Command = "cleanmgr.exe";
                        Args    = @("/sagerun:66");
                    }

                    $result = Invoke-CommandAction -Rule $cleanMgrRule

                    # 3. Verifica finale (CleanMgr potrebbe richiedere riavvio, quindi non è un vero errore se rimane)
                    if (Test-Path $path) {
                        Write-StyledMessage -Type 'Info' -Text "ℹ️ La cartella Windows.old potrebbe richiedere un riavvio per la rimozione completa."
                    }
                    else {
                        Write-StyledMessage -Type 'Success' -Text "✅ Windows.old rimosso con successo."
                    }
                }
                else {
                    # Silent or low verbosity if not present
                    Write-StyledMessage -Type 'Info' -Text "💭 Nessuna cartella Windows.old rilevata."
                }
            }
        }
        @{ Name = "Empty Recycle Bin"; Type = "Custom"; ScriptBlock = {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                Write-StyledMessage -Type 'Success' -Text "🗑️ Cestino svuotato"
            }
        }
    )

    # ============================================================================
    # 5. ESECUZIONE REGOLE
    # ============================================================================

    $totalRules = $Rules.Count
    $currentRuleIndex = 0
    $successCount = 0
    $warningCount = 0
    $errorCount = 0

    foreach ($rule in $Rules) {
        $currentRuleIndex++
        $percent = [math]::Round(($currentRuleIndex / $totalRules) * 100)

        # Clear line before showing progress to avoid ghosting
        Clear-ProgressLine
        Show-ProgressBar -Activity "Esecuzione regole" -Status "$($rule.Name)" -Percent $percent -Icon '⚙️'

        $result = Invoke-WinCleanerRule -Rule $rule

        # Clear progress bar line after rule execution to ensure next log message is clean
        Clear-ProgressLine

        if ($result) {
            $successCount++
        }
        else {
            $errorCount++
        }
    }

    # ============================================================================
    # 6. RIEPILOGO OPERAZIONI
    # ============================================================================

    Clear-ProgressLine
    Write-Host "`n"
    Write-StyledMessage -Type 'Info' -Text "=================================================="
    Write-StyledMessage -Type 'Info' -Text "               RIEPILOGO OPERAZIONI               "
    Write-StyledMessage -Type 'Info' -Text "=================================================="

    # Group logs by type for summary stats
    $stats = $global:WinCleanerLog | Group-Object Type
    $sCount = ($stats | Where-Object Name -eq 'Success').Count
    $wCount = ($stats | Where-Object Name -eq 'Warning').Count
    $eCount = ($stats | Where-Object Name -eq 'Error').Count

    Write-StyledMessage -Type 'Success' -Text "✅ Operazioni completate con successo: $sCount"
    if ($wCount -gt 0) { Write-StyledMessage -Type 'Warning' -Text "⚠️ Avvisi generati: $wCount" }
    if ($eCount -gt 0) { Write-StyledMessage -Type 'Error' -Text "❌ Errori riscontrati: $eCount" }

    Write-StyledMessage -Type 'Info' -Text "--------------------------------------------------"
    Write-StyledMessage -Type 'Info' -Text "Dettaglio Errori e Warning:"

    $problems = $global:WinCleanerLog | Where-Object { $_.Type -in 'Warning', 'Error' }
    if ($problems) {
        foreach ($p in $problems) {
            $icon = if ($p.Type -eq 'Error') { '❌' } else { '⚠️' }
            Write-Host "[$($p.Timestamp)] $icon $($p.Text)" -ForegroundColor ($p.Type -eq 'Error' ? 'Red' : 'Yellow')
        }
    }
    else {
        Write-StyledMessage -Type 'Success' -Text "Nessun problema rilevato."
    }

    Write-StyledMessage -Type 'Info' -Text "=================================================="
    Write-Host "`n"

    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
        Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
    }
    else {
        $shouldReboot = Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio sistema in"
        if ($shouldReboot) {
            Restart-Computer -Force
        }
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

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName "VideoDriverInstall"
    Show-Header -SubTitle "Video Driver Install Toolkit"
    $Host.UI.RawUI.WindowTitle = "Video Driver Install Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    $GitHubAssetBaseUrl = $AppConfig.URLs.GitHubAssetBaseUrl
    $DriverToolsLocalPath = $AppConfig.Paths.Drivers
    $DesktopPath = [Environment]::GetFolderPath('Desktop')

    # ============================================================================
    # 3. FUNZIONI HELPER LOCALI
    # ============================================================================

    function Get-GpuManufacturer {
        <#
        .SYNOPSIS
            Identifica il produttore della scheda grafica principale.
        .DESCRIPTION
            Ritorna 'NVIDIA', 'AMD', 'Intel' o 'Unknown' basandosi sui dispositivi Plug and Play.
        #>
        $pnpDevices = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue

        if (-not $pnpDevices) {
            Write-StyledMessage Warning "Nessun dispositivo display Plug and Play rilevato."
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
        Write-StyledMessage Info "Configurazione per bloccare download driver da Windows Update..."

        $regPath = $AppConfig.Registry.WindowsUpdatePolicies
        $propertyName = "ExcludeWUDriversInQualityUpdate"
        $propertyValue = 1

        try {
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            Set-ItemProperty -Path $regPath -Name $propertyName -Value $propertyValue -Type DWord -Force -ErrorAction Stop
            Write-StyledMessage Success "Blocco download driver da Windows Update impostato correttamente nel registro."
            Write-StyledMessage Info "Questa impostazione impedisce a Windows Update di installare driver automaticamente."
        }
        catch {
            Write-StyledMessage Error "Errore durante l'impostazione del blocco download driver da Windows Update: $($_.Exception.Message)"
            Write-StyledMessage Warning "Potrebbe essere necessario eseguire lo script come amministratore."
            return
        }

        Write-StyledMessage Info "Aggiornamento dei criteri di gruppo in corso per applicare le modifiche..."
        try {
            $procParams = @{
                FilePath     = 'gpupdate.exe'
                ArgumentList = '/force'
                Wait         = $true
                NoNewWindow  = $true
                PassThru     = $true
                ErrorAction  = 'Stop'
            }
            $gpupdateProcess = Start-Process @procParams
            if ($gpupdateProcess.ExitCode -eq 0) {
                Write-StyledMessage Success "Criteri di gruppo aggiornati con successo."
            }
            else {
                Write-StyledMessage Warning "Aggiornamento dei criteri di gruppo completato con codice di uscita non zero: $($gpupdateProcess.ExitCode)."
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante l'aggiornamento dei criteri di gruppo: $($_.Exception.Message)"
            Write-StyledMessage Warning "Le modifiche ai criteri potrebbero richiedere un riavvio o del tempo per essere applicate."
        }
    }

    function Download-FileWithProgress {
        <#
        .SYNOPSIS
            Scarica un file con barra di progresso.
        .DESCRIPTION
            Scarica un file dall'URL specificato con barra di progresso che mostra la percentuale di download e gestione retry.
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

        Write-StyledMessage Info "Scaricando $Description..."

        $destDir = Split-Path -Path $DestinationPath -Parent
        if (-not (Test-Path $destDir)) {
            try {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            catch {
                Write-StyledMessage Error "Impossibile creare la cartella di destinazione '$destDir': $($_.Exception.Message)"
                return $false
            }
        }

        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            try {
                $webRequest = [System.Net.WebRequest]::Create($Url)
                $webResponse = $webRequest.GetResponse()
                $totalBytes = $webResponse.ContentLength
                $responseStream = $webResponse.GetResponseStream()
                $targetStream = [System.IO.FileStream]::new($DestinationPath, [System.IO.FileMode]::Create)
                $buffer = New-Object byte[] 64KB
                $downloadedBytes = 0
                $bytesRead = 0

                # Inizializza la barra di progresso
                Write-Progress -Activity "Download $Description" -Status "Inizio download..." -PercentComplete 0

                # Download con aggiornamento barra di progresso
                do {
                    $bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)
                    if ($bytesRead -gt 0) {
                        $targetStream.Write($buffer, 0, $bytesRead)
                        $downloadedBytes += $bytesRead

                        # Calcola la percentuale
                        $percentComplete = [System.Math]::Round(($downloadedBytes / $totalBytes) * 100, 1)
                        $speed = if ($downloadedBytes -gt 0) { [System.Math]::Round(($downloadedBytes / 1024 / 1024), 2) } else { 0 }
                        $totalSize = [System.Math]::Round(($totalBytes / 1024 / 1024), 2)

                        # Aggiorna la barra di progresso
                        Write-Progress -Activity "Download $Description" -Status "$speed MB / $totalSize MB" -PercentComplete $percentComplete
                    }
                } while ($bytesRead -gt 0)

                # Completa la barra di progresso
                Write-Progress -Activity "Download $Description" -Status "Completato" -PercentComplete 100 -Completed

                $targetStream.Flush()
                $targetStream.Close()
                $targetStream.Dispose()
                $responseStream.Dispose()
                $webResponse.Close()

                Write-StyledMessage Success "Download di $Description completato."
                return $true
            }
            catch {
                Write-Progress -Activity "Download $Description" -Completed
                Write-StyledMessage Warning "Tentativo $attempt fallito per $Description`: $($_.Exception.Message)"
                if ($attempt -lt $MaxRetries) {
                    Start-Sleep -Seconds 2
                }
            }
        }
        Write-StyledMessage Error "Errore durante il download di $Description dopo $MaxRetries tentativi."
        return $false
    }

    function Handle-InstallVideoDrivers {
        <#
        .SYNOPSIS
            Gestisce l'installazione dei driver video.
        .DESCRIPTION
            Scarica e avvia l'installer appropriato per la GPU rilevata.
        #>
        Write-StyledMessage Info "Opzione 1: Avvio installazione driver video."

        $gpuManufacturer = Get-GpuManufacturer
        Write-StyledMessage Info "Rilevata GPU: $gpuManufacturer"

        if ($gpuManufacturer -eq 'AMD') {
            $amdInstallerUrl = $AppConfig.URLs.AMDInstaller
            $amdInstallerPath = Join-Path $DriverToolsLocalPath "AMD-Autodetect.exe"

            if (Download-FileWithProgress -Url $amdInstallerUrl -DestinationPath $amdInstallerPath -Description "AMD Auto-Detect Tool") {
                Write-StyledMessage Info "Avvio installazione driver video AMD. Premi un tasto per chiudere correttamente il terminale quando l'installazione è completata."
                $procParams = @{
                    FilePath    = $amdInstallerPath
                    Wait        = $true
                    ErrorAction = 'SilentlyContinue'
                }
                Start-Process @procParams
                Write-StyledMessage Success "Installazione driver video AMD completata o chiusa."
            }
        }
        elseif ($gpuManufacturer -eq 'NVIDIA') {
            $nvidiaInstallerUrl = $AppConfig.URLs.NVCleanstall
            $nvidiaInstallerPath = Join-Path $DriverToolsLocalPath "NVCleanstall_1.19.0.exe"

            if (Download-FileWithProgress -Url $nvidiaInstallerUrl -DestinationPath $nvidiaInstallerPath -Description "NVCleanstall Tool") {
                Write-StyledMessage Info "Avvio installazione driver video NVIDIA Ottimizzato. Premi un tasto per chiudere correttamente il terminale quando l'installazione è completata."
                $procParams = @{
                    FilePath    = $nvidiaInstallerPath
                    Wait        = $true
                    ErrorAction = 'SilentlyContinue'
                }
                Start-Process @procParams
                Write-StyledMessage Success "Installazione driver video NVIDIA completata o chiusa."
            }
        }
        elseif ($gpuManufacturer -eq 'Intel') {
            Write-StyledMessage Info "Rilevata GPU Intel. Utilizza Windows Update per aggiornare i driver integrati."
        }
        else {
            Write-StyledMessage Error "Produttore GPU non supportato o non rilevato per l'installazione automatica dei driver."
        }
    }

    function Handle-ReinstallRepairVideoDrivers {
        <#
        .SYNOPSIS
            Gestisce la reinstallazione/riparazione dei driver video.
        .DESCRIPTION
            Scarica DDU e gli installer dei driver, configura la modalità provvisoria e riavvia.
        #>
        Write-StyledMessage Warning "Opzione 2: Avvio procedura di reinstallazione/riparazione driver video. Richiesto riavvio."

        # Download DDU
        $dduZipUrl = $AppConfig.URLs.DDUZip
        $dduZipPath = Join-Path $DriverToolsLocalPath "DDU.zip"

        if (-not (Download-FileWithProgress -Url $dduZipUrl -DestinationPath $dduZipPath -Description "DDU (Display Driver Uninstaller)")) {
            Write-StyledMessage Error "Impossibile scaricare DDU. Annullamento operazione."
            return
        }

        # Extract DDU to Desktop
        Write-StyledMessage Info "Estrazione DDU sul Desktop..."
        try {
            Expand-Archive -Path $dduZipPath -DestinationPath $DesktopPath -Force
            Write-StyledMessage Success "DDU estratto correttamente sul Desktop."
        }
        catch {
            Write-StyledMessage Error "Errore durante l'estrazione di DDU sul Desktop: $($_.Exception.Message)"
            return
        }

        $gpuManufacturer = Get-GpuManufacturer
        Write-StyledMessage Info "Rilevata GPU: $gpuManufacturer"

        if ($gpuManufacturer -eq 'AMD') {
            $amdInstallerUrl = $AppConfig.URLs.AMDInstaller
            $amdInstallerPath = Join-Path $DesktopPath "AMD-Autodetect.exe"

            if (-not (Download-FileWithProgress -Url $amdInstallerUrl -DestinationPath $amdInstallerPath -Description "AMD Auto-Detect Tool")) {
                Write-StyledMessage Error "Impossibile scaricare l'installer AMD. Annullamento operazione."
                return
            }
        }
        elseif ($gpuManufacturer -eq 'NVIDIA') {
            $nvidiaInstallerUrl = $AppConfig.URLs.NVCleanstall
            $nvidiaInstallerPath = Join-Path $DesktopPath "NVCleanstall_1.19.0.exe"

            if (-not (Download-FileWithProgress -Url $nvidiaInstallerUrl -DestinationPath $nvidiaInstallerPath -Description "NVCleanstall Tool")) {
                Write-StyledMessage Error "Impossibile scaricare l'installer NVIDIA. Annullamento operazione."
                return
            }
        }
        elseif ($gpuManufacturer -eq 'Intel') {
            Write-StyledMessage Info "Rilevata GPU Intel. Scarica manualmente i driver da Intel se necessario."
        }
        else {
            Write-StyledMessage Warning "Produttore GPU non supportato o non rilevato. Verrà posizionato solo DDU sul desktop."
        }

        Write-StyledMessage Info "DDU e l'installer dei Driver (se rilevato) sono stati posizionati sul desktop."

        # Creazione file batch per tornare alla modalità normale
        $batchFilePath = Join-Path $DesktopPath "Switch to Normal Mode.bat"
        try {
            Set-Content -Path $batchFilePath -Value 'bcdedit /deletevalue {current} safeboot' -Encoding ASCII
            Write-StyledMessage Info "File batch 'Switch to Normal Mode.bat' creato sul desktop per disabilitare la Modalità Provvisoria."
        }
        catch {
            Write-StyledMessage Warning "Impossibile creare il file batch: $($_.Exception.Message)"
        }

        Write-StyledMessage Error "ATTENZIONE: Il sistema sta per riavviarsi in modalità provvisoria."

        Write-StyledMessage Info "Configurazione del sistema per l'avvio automatico in Modalità Provvisoria..."
        try {
            $procParams = @{
                FilePath     = 'bcdedit.exe'
                ArgumentList = '/set {current} safeboot minimal'
                Wait         = $true
                NoNewWindow  = $true
                ErrorAction  = 'Stop'
            }
            Start-Process @procParams
            Write-StyledMessage Success "Modalità Provvisoria configurata per il prossimo avvio."
        }
        catch {
            Write-StyledMessage Error "Errore durante la configurazione della Modalità Provvisoria tramite bcdedit: $($_.Exception.Message)"
            Write-StyledMessage Warning "Il riavvio potrebbe non avvenire in Modalità Provvisoria. Procedere manualmente."
            return
        }

        if ($SuppressIndividualReboot) {
            # In modalità concatenata, non riavviare in safe mode ma segnalare riavvio finale
            $Global:NeedsFinalReboot = $true
            Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio in modalità provvisoria soppresso (esecuzione concatenata)."
            Write-StyledMessage -Type 'Warning' -Text "⚠️ DDU e installer driver sono sul Desktop. Al prossimo riavvio sarai in SAFE MODE."
        }
        else {
            $shouldReboot = Start-InterruptibleCountdown -Seconds 30 -Message "Riavvio in modalità provvisoria in corso..."

            if ($shouldReboot) {
                try {
                    Restart-Computer -Force
                    Write-StyledMessage Success "Comando di riavvio inviato."
                }
                catch {
                    Write-StyledMessage Error "Errore durante l'esecuzione del comando di riavvio: $($_.Exception.Message)"
                }
            }
        }
    }

    Write-StyledMessage Info '🔧 Inizializzazione dello Script di Installazione Driver Video...'
    Start-Sleep -Seconds 2

    Set-BlockWindowsUpdateDrivers

    # Main Menu Logic
    $choice = ""
    do {
        Write-Host ""
        Write-StyledMessage Info 'Seleziona un''opzione:'
        Write-Host "  1) Installa Driver Video"
        Write-Host "  2) Reinstalla/Ripara Driver Video"
        Write-Host "  0) Torna al menu principale"
        Write-Host ""
        $choice = Read-Host "La tua scelta"
        Write-Host ""

        switch ($choice.ToUpper()) {
            "1" { Handle-InstallVideoDrivers }
            "2" { Handle-ReinstallRepairVideoDrivers }
            "0" { Write-StyledMessage Info 'Tornando al menu principale.' }
            default { Write-StyledMessage Warning "Scelta non valida. Riprova." }
        }

        if ($choice.ToUpper() -ne "0") {
            Write-Host "Premi un tasto per continuare..."
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            Clear-Host
            Show-Header -SubTitle "Video Driver Install Toolkit"
        }

    } while ($choice.ToUpper() -ne "0")
}
function GamingToolkit {
    <#
    .SYNOPSIS
        Gaming Toolkit - Strumenti di ottimizzazione per il gaming su Windows.

    .DESCRIPTION
        Script completo per ottimizzare le prestazioni del sistema per il gaming.
        Include installazione di runtime, client di gioco e configurazione del sistema.

    .PARAMETER CountdownSeconds
        Numero di secondi per il countdown prima del riavvio.

    .OUTPUTS
        None. La funzione non restituisce output.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,
        
        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName "GamingToolkit"
    Show-Header -SubTitle "Gaming Toolkit"
    $Host.UI.RawUI.WindowTitle = "Gaming Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    $osInfo = Get-ComputerInfo
    $buildNumber = $osInfo.OsBuildNumber
    $isWindows11Pre23H2 = ($buildNumber -ge 22000) -and ($buildNumber -lt 22631)

    # ============================================================================
    # 3. FUNZIONI HELPER LOCALI
    # ============================================================================
    function Test-WingetPackageAvailable([string]$PackageId) {
        try {
            $result = winget search $PackageId 2>&1
            return $LASTEXITCODE -eq 0 -and $result -match $PackageId
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-StyledMessage -Type 'Warning' -Text ("Errore verifica pacchetto {0}: {1}" -f $PackageId, $errorMessage)
            return $false
        }
    }

    function Invoke-WingetInstallWithProgress([string]$PackageId, [string]$DisplayName, [int]$Step, [int]$Total) {
        Write-StyledMessage -Type 'Info' -Text "[$Step/$Total] 📦 Installazione: $DisplayName..."

        if (-not (Test-WingetPackageAvailable $PackageId)) {
            Write-StyledMessage -Type 'Warning' -Text "Pacchetto $DisplayName non disponibile. Saltando."
            return @{ Success = $true; Skipped = $true }
        }

        try {
            # Usa la funzione globale Invoke-WithSpinner per monitorare il processo winget
            $result = Invoke-WithSpinner -Activity "Installazione $DisplayName" -Process -Action {
                $procParams = @{
                    FilePath     = 'winget'
                    ArgumentList = @('install', '--id', $PackageId, '--silent', '--accept-package-agreements', '--accept-source-agreements')
                    PassThru     = $true
                    NoNewWindow  = $true
                }
                Start-Process @procParams
            } -TimeoutSeconds 300 -UpdateInterval 700

            $exitCode = $result.ExitCode
            $successCodes = @(0, 1638, 3010, -1978335189)

            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text "Installato: $DisplayName"
                return @{ Success = $true; ExitCode = $exitCode }
            }
            else {
                Write-StyledMessage -Type 'Error' -Text "Errore installazione $DisplayName (codice: $exitCode)"
                return @{ Success = $false; ExitCode = $exitCode }
            }
        }
        catch {
            Write-Host "`r$(' ' * 120)" -NoNewline
            Write-Host "`r" -NoNewline
            Write-StyledMessage -Type 'Error' -Text "Eccezione $DisplayName`: $($_.Exception.Message)"
            return @{ Success = $false }
        }
        finally {
            Remove-Item "$env:TEMP\winget_$PackageId.log", "$env:TEMP\winget_err_$PackageId.log" -ErrorAction SilentlyContinue
        }
    }

    if ($isWindows11Pre23H2) {
        Write-StyledMessage Warning "Versione obsoleta rilevata. Winget potrebbe non funzionare."
        $response = Read-Host "Eseguire riparazione Winget? (Y/N)"
        if ($response -match '^[Yy]$') { WinReinstallStore }
    }

    $Host.UI.RawUI.WindowTitle = "Gaming Toolkit By MagnetarMan"

    # Countdown preparazione
    Invoke-WithSpinner -Activity "Preparazione" -Timer -Action { Start-Sleep 5 } -TimeoutSeconds 5

    Show-Header -SubTitle "Gaming Toolkit"

    # Step 1: Verifica Winget
    Write-StyledMessage Info '🔍 Verifica Winget...'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage Error 'Winget non disponibile.'
        Write-StyledMessage Info 'Esegui reset Store/Winget e riprova.'
        Write-Host "`nPremi un tasto..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return
    }
    Write-StyledMessage Success 'Winget funzionante.'

    Write-StyledMessage Info '🔄 Aggiornamento sorgenti Winget...'
    try {
        winget source update | Out-Null
        Write-StyledMessage Success 'Sorgenti aggiornate.'
    }
    catch {
        Write-StyledMessage Warning "Errore aggiornamento sorgenti: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 2: NetFramework
    Write-StyledMessage Info '🔧 Abilitazione NetFramework...'
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs, NetFx3 -NoRestart -All -ErrorAction Stop | Out-Null
        Write-StyledMessage Success 'NetFramework abilitato.'
    }
    catch {
        Write-StyledMessage Error "Errore durante abilitazione NetFramework: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 3: Runtime e VCRedist
    $runtimes = @(
        "Microsoft.DotNet.DesktopRuntime.3_1",
        "Microsoft.DotNet.DesktopRuntime.5",
        "Microsoft.DotNet.DesktopRuntime.6",
        "Microsoft.DotNet.DesktopRuntime.7",
        "Microsoft.DotNet.DesktopRuntime.8",
        "Microsoft.DotNet.DesktopRuntime.9",
        "Microsoft.DotNet.DesktopRuntime.10",
        "Microsoft.VCRedist.2010.x64",
        "Microsoft.VCRedist.2010.x86",
        "Microsoft.VCRedist.2012.x64",
        "Microsoft.VCRedist.2012.x86",
        "Microsoft.VCRedist.2013.x64",
        "Microsoft.VCRedist.2013.x86",
        "Microsoft.VCLibs.Desktop.14",
        "Microsoft.VCRedist.2015+.x64",
        "Microsoft.VCRedist.2015+.x86"
    )

    Write-StyledMessage Info '🔥 Installazione runtime .NET e VCRedist...'
    for ($runtimeIndex = 0; $runtimeIndex -lt $runtimes.Count; $runtimeIndex++) {
        Invoke-WingetInstallWithProgress $runtimes[$runtimeIndex] $runtimes[$runtimeIndex] ($runtimeIndex + 1) $runtimes.Count | Out-Null
        Write-Host ''
    }
    Write-StyledMessage Success 'Runtime completati.'
    Write-Host ''

    # Step 4: DirectX
    Write-StyledMessage Info '🎮 Installazione DirectX...'
    $dxDir = "$env:LOCALAPPDATA\WinToolkit\Directx"
    $dxPath = "$dxDir\dxwebsetup.exe"

    if (-not (Test-Path $dxDir)) { New-Item -Path $dxDir -ItemType Directory -Force | Out-Null }

    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.DirectXWebSetup -OutFile $dxPath -ErrorAction Stop
        Write-StyledMessage Success 'DirectX scaricato.'

        # Usa la funzione globale Invoke-WithSpinner per monitorare il processo DirectX
        $result = Invoke-WithSpinner -Activity "Installazione DirectX" -Process -Action {
            $procParams = @{
                FilePath = $dxPath
                PassThru = $true
            }
            Start-Process @procParams
        } -TimeoutSeconds 600 -UpdateInterval 700

        if (-not $result.Process.HasExited) {
            Write-Host "`r$(' ' * 120)" -NoNewline
            Write-Host "`r" -NoNewline
            Write-StyledMessage Warning "Timeout DirectX."
            $result.Process.Kill()
        }
        else {
            Write-Host "`r$(' ' * 120)" -NoNewline
            Write-Host "`r" -NoNewline
            $exitCode = $result.Process.ExitCode
            $successCodes = @(0, 3010, 5100, -9, 9, -1442840576)
            if ($exitCode -in $successCodes) {
                Write-StyledMessage Success "DirectX installato (codice: $exitCode)."
            }
            else {
                Write-StyledMessage Error "DirectX errore: $exitCode"
            }
        }
    }
    catch {
        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline
        Write-StyledMessage Error "Errore durante installazione DirectX: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 5: Client di gioco
    $gameClients = @(
        "Amazon.Games", "GOG.Galaxy", "EpicGames.EpicGamesLauncher",
        "ElectronicArts.EADesktop", "Playnite.Playnite", "Valve.Steam",
        "Ubisoft.Connect", "9MV0B5HZVK9Z"
    )

    Write-StyledMessage Info '🎮 Installazione client di gioco...'
    for ($clientIndex = 0; $clientIndex -lt $gameClients.Count; $clientIndex++) {
        Invoke-WingetInstallWithProgress $gameClients[$clientIndex] $gameClients[$clientIndex] ($clientIndex + 1) $gameClients.Count | Out-Null
        Write-Host ''
    }
    Write-StyledMessage Success 'Client installati.'
    Write-Host ''

    # Step 6: Battle.net
    Write-StyledMessage Info '🎮 Installazione Battle.net...'
    $bnPath = "$env:TEMP\Battle.net-Setup.exe"

    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.BattleNetInstaller -OutFile $bnPath -ErrorAction Stop
        Write-StyledMessage Success 'Battle.net scaricato.'

        # Usa la funzione globale Invoke-WithSpinner per monitorare il processo Battle.net
        $result = Invoke-WithSpinner -Activity "Installazione Battle.net" -Process -Action {
            $procParams = @{
                FilePath    = $bnPath
                PassThru    = $true
                Verb        = 'RunAs'
                ErrorAction = 'Stop'
            }
            Start-Process @procParams
        } -TimeoutSeconds 900 -UpdateInterval 500

        if (-not $result.Process.HasExited) {
            Write-Host "`r$(' ' * 120)" -NoNewline
            Write-Host "`r" -NoNewline
            Write-StyledMessage Warning "Timeout Battle.net."
            try { $result.Process.Kill() } catch {}
        }
        else {
            Write-Host "`r$(' ' * 120)" -NoNewline
            Write-Host "`r" -NoNewline
            $exitCode = $result.Process.ExitCode
            if ($exitCode -in @(0, 3010)) {
                Write-StyledMessage Success "Battle.net installato."
            }
            else {
                Write-StyledMessage Warning "Battle.net: codice $exitCode"
            }
        }

        Write-Host "`nPremi un tasto..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    catch {
        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline
        Write-StyledMessage Error "Errore durante installazione Battle.net: $($_.Exception.Message)"
        Write-Host "`nPremi un tasto..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    Write-Host ''

    # Step 7: Pulizia avvio automatico
    Write-StyledMessage Info '🧹 Pulizia avvio automatico...'
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    @('Steam', 'Battle.net', 'GOG Galaxy', 'GogGalaxy', 'GalaxyClient') | ForEach-Object {
        if (Get-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue
            Write-StyledMessage Success "Rimosso: $_"
        }
    }

    $startupPath = [Environment]::GetFolderPath('Startup')
    @('Steam.lnk', 'Battle.net.lnk', 'GOG Galaxy.lnk') | ForEach-Object {
        $path = Join-Path $startupPath $_
        if (Test-Path $path) {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
            Write-StyledMessage Success "Rimosso: $_"
        }
    }
    Write-StyledMessage Success 'Pulizia completata.'
    Write-Host ''

    # Step 8: Profilo energetico
    Write-StyledMessage Info '⚡ Configurazione profilo energetico...'
    $ultimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $planName = "WinToolkit Gaming Performance"
    $guid = $null

    $existingPlan = powercfg -list | Select-String -Pattern $planName -ErrorAction SilentlyContinue
    if ($existingPlan) {
        $guid = ($existingPlan.Line -split '\s+')[3]
        Write-StyledMessage Info "Piano esistente trovato."
    }
    else {
        try {
            $output = powercfg /duplicatescheme $ultimateGUID | Out-String
            if ($output -match "\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b") {
                $guid = $matches[0]
                powercfg /changename $guid $planName "Ottimizzato per Gaming dal WinToolkit" | Out-Null
                Write-StyledMessage Success "Piano creato."
            }
            else {
                Write-StyledMessage Error "Errore creazione piano."
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante duplicazione piano energetico: $($_.Exception.Message)"
        }
    }

    if ($guid) {
        try {
            powercfg -setactive $guid | Out-Null
            Write-StyledMessage Success "Piano attivato."
        }
        catch {
            Write-StyledMessage Error "Errore durante attivazione piano energetico: $($_.Exception.Message)"
        }
    }
    else {
        Write-StyledMessage Error "Impossibile attivare piano."
    }
    Write-Host ''

    # Step 9: Focus Assist
    Write-StyledMessage Info '🔕 Attivazione Non disturbare...'
    try {
        Set-ItemProperty -Path $AppConfig.Registry.FocusAssist -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0 -Force
        Write-StyledMessage Success 'Non disturbare attivo.'
    }
    catch {
        Write-StyledMessage Error "Errore durante configurazione Focus Assist: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 10: Completamento
    Write-Host ('═' * 80) -ForegroundColor Green
    Write-StyledMessage Success 'Gaming Toolkit completato!'
    Write-StyledMessage Success 'Sistema ottimizzato per il gaming.'
    Write-Host ('═' * 80) -ForegroundColor Green
    Write-Host ''

    # Step 11: Riavvio
    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
        Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
    }
    else {
        $shouldReboot = Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio necessario"

        if ($shouldReboot) {
            Write-StyledMessage Info '🔄 Riavvio...'
            Restart-Computer -Force
        }
        else {
            Write-StyledMessage Warning 'Riavvia manualmente per applicare tutte le modifiche.'
            Write-Host "`nPremi un tasto..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
    }
}
function DisableBitlocker {
    <#
    .SYNOPSIS
        Disattiva BitLocker sul drive C:.

    .DESCRIPTION
        Funzione per disattivare BitLocker sul drive C: e prevenire la crittografia futura.
        Include gestione degli errori e logging dettagliato.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName "DisableBitlocker"
    Show-Header -SubTitle "Disable BitLocker Toolkit"
    $Host.UI.RawUI.WindowTitle = "Disable BitLocker Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
    $Global:DisableBitlockerLog = @()

    # ============================================================================
    # 3. FUNZIONI HELPER LOCALI
    # ============================================================================

    function Test-BitLockerStatus {
        param([string]$DriveLetter = "C:")
        try {
            $status = manage-bde -status $DriveLetter
            return $status
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile verificare lo stato BitLocker: $($_.Exception.Message)"
            return $null
        }
    }

    # ============================================================================
    # 4. LOGICA PRINCIPALE (TRY-CATCH-FINALLY)
    # ============================================================================

    try {
        Write-StyledMessage -Type 'Info' -Text "🚀 Inizializzazione decrittazione drive C:..."

        # Tentativo disattivazione
        $procParams = @{
            FilePath     = 'manage-bde.exe'
            ArgumentList = @('-off', 'C:')
            PassThru     = $true
            Wait         = $true
            NoNewWindow  = $true
        }
        $proc = Start-Process @procParams

        if ($proc.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text "✅ Decrittazione avviata/completata con successo."
            Start-Sleep -Seconds 2

            # Check stato
            $status = Test-BitLockerStatus -DriveLetter "C:"
            if ($status -match "Decryption in progress" -or $status -match "Decriptazione in corso") {
                Write-StyledMessage -Type 'Info' -Text "⏳ Decrittazione in corso in background."
            }
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text "⚠️ Codice uscita manage-bde: $($proc.ExitCode). BitLocker potrebbe essere già disattivo o in errore."
        }

        # Prevenzione crittografia futura
        Write-StyledMessage -Type 'Info' -Text "⚙️ Disabilitazione crittografia automatica nel registro..."
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name "PreventDeviceEncryption" -Type DWord -Value 1 -Force

        Write-StyledMessage -Type 'Success' -Text "🎉 Configurazione completata."
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "❌ Errore critico in DisableBitlocker: $($_.Exception.Message)"
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text "♻️ Pulizia risorse Completata."
        if (-not $SuppressIndividualReboot) {
            Write-Host "`nPremi Enter per terminare..." -ForegroundColor Gray
            Read-Host | Out-Null
        }
        try { Stop-Transcript | Out-Null } catch {}
    }
}
function WinExportLog {
    <#
    .SYNOPSIS
        Comprime i log di WinToolkit e li salva sul desktop per l'invio diagnostico.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName "WinExportLog"
    Show-Header -SubTitle "Esporta Log Diagnostici"
    $Host.UI.RawUI.WindowTitle = "Log Export By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    $logSourcePath = $AppConfig.Paths.Logs
    $desktopPath = $AppConfig.Paths.Desktop
    $timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")
    $zipFileName = "WinToolkit_Logs_$timestamp.zip"
    $zipFilePath = Join-Path $desktopPath $zipFileName

    try {
        Write-StyledMessage Info "📂 Verifica presenza cartella log..."

        if (-not (Test-Path $logSourcePath -PathType Container)) {
            Write-StyledMessage Warning "La cartella dei log '$logSourcePath' non è stata trovata. Impossibile esportare."
            return
        }

        Write-StyledMessage Info "🗜️ Compressione dei log in corso. Potrebbe essere ignorato qualche file in uso..."

        # Metodo alternativo per gestire file in uso
        $tempFolder = Join-Path $AppConfig.Paths.TempFolder "WinToolkit_Logs_Temp_$timestamp"

        # Crea cartella temporanea
        if (Test-Path $tempFolder) {
            Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null

        # Copia i file con gestione degli errori
        $filesCopied = 0
        $filesSkipped = 0

        try {
            Get-ChildItem -Path $logSourcePath -File | ForEach-Object {
                try {
                    Copy-Item $_.FullName -Destination $tempFolder -Force -ErrorAction Stop
                    $filesCopied++
                }
                catch {
                    # File in uso o altri errori - salta silenziosamente
                    $filesSkipped++
                    Write-Debug "File ignorato: $($_.Name) - $($_.Exception.Message)"
                }
            }
        }
        catch {
            Write-StyledMessage Warning "Errore durante la copia dei file: $($_.Exception.Message)"
        }

        # Comprime la cartella temporanea
        if ($filesCopied -gt 0) {
            Compress-Archive -Path "$tempFolder\*" -DestinationPath $zipFilePath -Force -ErrorAction Stop

            if (Test-Path $zipFilePath) {
                Write-StyledMessage Success "Log compressi con successo! File salvato: '$zipFileName' sul Desktop."

                if ($filesSkipped -gt 0) {
                    Write-StyledMessage Info "⚠️ Attenzione: $filesSkipped file sono stati ignorati perché in uso o non accessibili."
                }

                # Messaggi per l'utente
                Write-StyledMessage Info "📩 Per favore, invia il file ZIP '$zipFileName' (lo trovi sul tuo Desktop) via Telegram [https://t.me/MagnetarMan] o email [me@magnetarman.com] per aiutarmi nella diagnostica."
            }
            else {
                Write-StyledMessage Error "Errore sconosciuto: il file ZIP non è stato creato."
            }
        }
        else {
            Write-StyledMessage Error "Nessun file log è stato copiato. Verifica i permessi e che i file esistano."
        }

        # Pulizia cartella temporanea
        if (Test-Path $tempFolder) {
            Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-StyledMessage Error "Errore critico durante la compressione dei log: $($_.Exception.Message)"

        # Pulizia forzata in caso di errore
        $tempFolder = Join-Path $env:TEMP "WinToolkit_Logs_Temp_$timestamp"
        if (Test-Path $tempFolder) {
            Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}


# --- MENU PRINCIPALE ---
$menuStructure = @(
    @{ 'Name' = 'Windows & Office'; 'Icon' = '🔧'; 'Scripts' = @(
            [pscustomobject]@{Name = 'WinRepairToolkit'; Description = 'Riparazione Windows'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinUpdateReset'; Description = 'Reset Windows Update'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinBackupDriver'; Description = 'Backup Driver PC'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinCleaner'; Description = 'Pulizia File Temporanei'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'DisableBitlocker'; Description = 'Disabilita Bitlocker'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'OfficeToolkit'; Description = 'Office Toolkit'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Driver & Gaming'; 'Icon' = '🎮'; 'Scripts' = @(
            [pscustomobject]@{Name = 'VideoDriverInstall'; Description = 'Driver Video Toolkit'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'GamingToolkit'; Description = 'Gaming Toolkit'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Supporto'; 'Icon' = '🕹️'; 'Scripts' = @(
            [pscustomobject]@{Name = 'WinExportLog'; Description = 'Esporta Log WinToolkit'; Action = 'RunFunction' }
        )
    }
)

WinOSCheck

# =============================================================================
# MENU PRINCIPALE - Esegui solo se NON in modalità ImportOnly o GUI
# =============================================================================

if (-not $ImportOnly -and -not $Global:GuiSessionActive) {
    # Modalità interattiva TUI standard
    Write-Host ""
    Write-StyledMessage -Type 'Info' -Text '💎 WinToolkit avviato in modalità interattiva'
    Write-Host ""

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
            $blStatus = Get-BitlockerStatus
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
        $c = Read-Host "Inserisci uno o più numeri (es: 1 2 3 oppure 1,2,3) per eseguire le operazioni in sequenza"

        # Secret check
        if ($c -eq [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('V2luZG93cyDDqCB1bmEgbWVyZGE='))) {
            Start-Process ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly93d3cueW91dHViZS5jb20vd2F0Y2g/dj15QVZVT2tlNGtvYw==')))
            continue
        }

        if ($c -eq '0') {
            Write-StyledMessage -type 'Warning' -text 'Per supporto: Github.com/Magnetarman'
            Write-StyledMessage -type 'Success' -text 'Chiusura in corso...'
            if ($Global:Transcript -or $Transcript) {
                Stop-Transcript -ErrorAction SilentlyContinue
            }
            Start-Sleep -Seconds 3
            break
        }

        # Parsing input multipli: supporta "1 2 3", "1,2,3", "1, 2, 3"
        $selections = @()
        $rawInputs = $c -split '[\s,]+' | Where-Object { $_ -match '^\d+$' }
        foreach ($input in $rawInputs) {
            $num = [int]$input
            if ($num -ge 1 -and $num -le $allScripts.Count) {
                $selections += $num
            }
        }

        if ($selections.Count -eq 0) {
            Write-StyledMessage -Type 'Warning' -Text '⚠️ Nessuna selezione valida. Riprova.'
            Start-Sleep -Seconds 2
            continue
        }

        # Reset variabili globali per esecuzione multi-script
        $Global:ExecutionLog = @()
        $Global:NeedsFinalReboot = $false
        $isMultiScript = ($selections.Count -gt 1)

        Write-Host ''
        if ($isMultiScript) {
            Write-StyledMessage -Type 'Info' -Text "🚀 Esecuzione sequenziale di $($selections.Count) operazioni..."
            Write-Host ''
        }

        foreach ($sel in $selections) {
            $scriptToRun = $allScripts[$sel - 1]
            Write-StyledMessage -Type 'Progress' -Text "▶️ Avvio: $($scriptToRun.Description)"
            Write-Host ''

            try {
                if ($isMultiScript) {
                    # Esecuzione con soppressione riavvio individuale
                    & ([scriptblock]::Create("$($scriptToRun.Name) -SuppressIndividualReboot"))
                }
                else {
                    # Esecuzione normale (singola selezione)
                    & $ExecutionContext.InvokeCommand.GetCommand($scriptToRun.Name, 'Function')
                }
                $Global:ExecutionLog += @{ Name = $scriptToRun.Description; Success = $true }
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "❌ Errore durante $($scriptToRun.Description): $($_.Exception.Message)"
                $Global:ExecutionLog += @{ Name = $scriptToRun.Description; Success = $false; Error = $_.Exception.Message }
            }
            Write-Host ''
        }

        # Riepilogo esecuzione (solo se multi-script)
        if ($isMultiScript) {
            Write-Host ''
            Write-StyledMessage -Type 'Info' -Text '📊 Riepilogo esecuzione:'
            foreach ($log in $Global:ExecutionLog) {
                if ($log.Success) {
                    Write-Host "  ✅ $($log.Name)" -ForegroundColor Green
                }
                else {
                    Write-Host "  ❌ $($log.Name)" -ForegroundColor Red
                }
            }
            Write-Host ''
        }

        # Gestione riavvio finale centralizzato
        if ($Global:NeedsFinalReboot) {
            Write-StyledMessage -Type 'Warning' -Text '🔄 È necessario un riavvio per completare le operazioni.'
            if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message 'Riavvio sistema in') {
                Restart-Computer -Force
            }
            else {
                Write-Host ''
                Write-StyledMessage -Type 'Info' -Text '💡 Ricorda di riavviare il sistema manualmente per completare le operazioni.'
            }
        }

        Write-Host "`nPremi INVIO per tornare al menu..." -ForegroundColor Gray
        $null = Read-Host
    }
}
else {
    # Modalità libreria/import - funzioni caricate ma menu soppresso
    Write-Verbose "═══════════════════════════════════════════════════════════"
    Write-Verbose "  📚 WinToolkit caricato in modalità LIBRERIA"
    Write-Verbose "  ✅ Funzioni disponibili, menu TUI soppresso"
    Write-Verbose "  💎 Versione: $ToolkitVersion"
    Write-Verbose "═══════════════════════════════════════════════════════════"

    # Esponi $menuStructure globalmente per la GUI
    $Global:menuStructure = $menuStructure
}
