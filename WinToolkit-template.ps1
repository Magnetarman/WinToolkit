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
$ToolkitVersion = "2.5.2 (Build 27)"

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
        VCRedist86            = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
        VCRedist64            = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
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
        BitLocker             = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
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

function Reset-Winget {
    <#
    .SYNOPSIS
        Verifica, ripristina e testa l'installazione di Winget.
    .DESCRIPTION
        Procedura integrata e robusta per la riparazione di Winget.
        Include installazione dipendenze, VC++ Redist e validazione profonda.
    #>
    param([switch]$Force)

    # --- Helper Interni ---
    $UpdateEnvironmentPath = {
        $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
        $env:Path = $newPath
        [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
    }

    function _Get-LatestAssetUrl {
        param([string]$Match)
        try {
            $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing -ErrorAction Stop
            $asset = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
            if ($asset) { return $asset.browser_download_url }
        }
        catch {}
        return $null
    }

    function _Test-WingetCompatibility {
        $osInfo = [Environment]::OSVersion
        if ($osInfo.Version.Major -lt 10) { return $false }
        if ($osInfo.Version.Major -eq 10 -and $osInfo.Version.Build -lt 16299) { return $false }
        return $true
    }

    function _Invoke-ForceClose {
        Write-StyledMessage -Type Info -Text "Chiusura processi interferenti..."
        $procs = @("WinStore.App", "wsappx", "AppInstaller", "Microsoft.WindowsStore", "Microsoft.DesktopAppInstaller", "winget", "WindowsPackageManagerServer")
        foreach ($p in $procs) { Get-Process -Name $p -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID } | Stop-Process -Force -ErrorAction SilentlyContinue }
        Start-Sleep 2
    }

    function _Apply-Permissions {
        try {
            $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
            $wingetDir = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
            if ($wingetDir) {
                $administratorsGroupSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
                $administratorsGroup = $administratorsGroupSid.Translate([System.Security.Principal.NTAccount])
                $acl = Get-Acl -Path $wingetDir.FullName
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($administratorsGroup, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
                $acl.SetAccessRule($rule)
                Set-Acl -Path $wingetDir.FullName -AclObject $acl
                
                # Update PATH
                $sysPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
                if (-not ($sysPath -split ';').Contains($wingetDir.FullName)) { [Environment]::SetEnvironmentVariable('Path', "$sysPath;$($wingetDir.FullName)", 'Machine') }
            }
        }
        catch {}
    }

    # --- Logica Principale ---
    Write-StyledMessage -Type Info -Text "🚀 Avvio procedura integrata Reset-Winget..."

    if (-not (_Test-WingetCompatibility)) {
        Write-StyledMessage -Type Error -Text "Sistema non compatibile con Winget."
        return $false
    }

    # FASE 0: VC++ Redists
    Write-StyledMessage -Type Info -Text "Verifica Visual C++ Redistributable..."
    $vcKey = if ([Environment]::Is64BitOperatingSystem) { "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64" } else { "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X86" }
    if (-not (Test-Path $vcKey) -or $Force) {
        Write-StyledMessage -Type Info -Text "Installazione VC++ Redistributable..."
        $vcUrl = if ([Environment]::Is64BitOperatingSystem) { $AppConfig.URLs.VCRedist64 } else { $AppConfig.URLs.VCRedist86 }
        $tempFile = Join-Path $AppConfig.Paths.Temp "vc_redist.exe"
        try {
            if (-not (Test-Path $AppConfig.Paths.Temp)) { New-Item -Path $AppConfig.Paths.Temp -ItemType Directory -Force | Out-Null }
            Invoke-WebRequest -Uri $vcUrl -OutFile $tempFile -UseBasicParsing -ErrorAction Stop
            Start-Process -FilePath $tempFile -ArgumentList "/install", "/quiet", "/norestart" -Wait
            Write-StyledMessage -Type Success -Text "VC++ Redist installato."
        }
        catch {
            Write-StyledMessage -Type Warning -Text "Errore installazione VC++: $($_.Exception.Message)"
        }
        finally {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        }
    }

    # FASE 1: Verifica e Installazione Core
    & $UpdateEnvironmentPath
    $wingetOk = (Get-Command winget -ErrorAction SilentlyContinue) -and (& winget --version 2>$null | Out-String -Stream | Select-String 'v\d')
    
    if (-not $wingetOk -or $Force) {
        Write-StyledMessage -Type Warning -Text "Winget non operativo. Avvio ripristino core..."
        _Invoke-ForceClose
        
        # 1.1 Installazione Dipendenze (UI.Xaml, VCLibs)
        Write-StyledMessage -Type Info -Text "Download dipendenze Appx..."
        $depUrl = _Get-LatestAssetUrl -Match 'DesktopAppInstaller_Dependencies.zip'
        if ($depUrl) {
            $depZip = Join-Path $AppConfig.Paths.Temp "dependencies.zip"
            $depDir = Join-Path $AppConfig.Paths.Temp "deps"
            try {
                Invoke-WebRequest -Uri $depUrl -OutFile $depZip -UseBasicParsing -ErrorAction Stop
                Expand-Archive -Path $depZip -DestinationPath $depDir -Force
                $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
                Get-ChildItem -Path $depDir -Recurse -Filter "*.appx" | Where-Object { $_.Name -match $arch -or $_.Name -match "neutral" } | ForEach-Object {
                    Add-AppxPackage -Path $_.FullName -ForceApplicationShutdown -ErrorAction SilentlyContinue
                }
                Write-StyledMessage -Type Success -Text "Dipendenze Appx installate."
            }
            catch {} finally {
                if (Test-Path $depZip) { Remove-Item $depZip -Force }
                if (Test-Path $depDir) { Remove-Item $depDir -Recurse -Force }
            }
        }

        # 1.2 Installazione Winget Bundle
        Write-StyledMessage -Type Info -Text "Installazione Winget MSIXBundle..."
        $bundleFile = Join-Path $AppConfig.Paths.Temp "WingetInstaller.msixbundle"
        try {
            $bundleUrl = _Get-LatestAssetUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
            if (-not $bundleUrl) { $bundleUrl = $AppConfig.URLs.WingetInstaller }
            Invoke-WebRequest -Uri $bundleUrl -OutFile $bundleFile -UseBasicParsing -ErrorAction Stop
            Add-AppxPackage -Path $bundleFile -ForceApplicationShutdown -ErrorAction Stop
            Write-StyledMessage -Type Success -Text "Winget Bundle installato."
        }
        catch {
            Write-StyledMessage -Type Error -Text "Installazione fallita: $($_.Exception.Message)"
        }
        finally {
            if (Test-Path $bundleFile) { Remove-Item $bundleFile -Force }
        }
    }

    # FASE 2: Riparazione Database e Sorgenti
    Write-StyledMessage -Type Info -Text "Riparazione database e reset sorgenti..."
    try {
        Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage -ErrorAction SilentlyContinue
        & winget source reset --force 2>$null
    }
    catch {}

    _Apply-Permissions
    & $UpdateEnvironmentPath

    # FASE 3: Test Finale
    Write-StyledMessage -Type Info -Text "🔍 Verifica finale connettività..."
    $test = & winget search "Git.Git" --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-StyledMessage -Type Success -Text "✅ Winget ripristinato con successo."
        return $true
    }
    else {
        Write-StyledMessage -Type Error -Text "❌ Winget non operativo dopo il reset."
        return $false
    }
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
function WinRepairToolkit {}
function WinUpdateReset {}
function WinReinstallStore {}
function WinBackupDriver {}
function WinDriverInstall {}
function OfficeToolkit {}
function WinCleaner {}
function VideoDriverInstall {}
function GamingToolkit {}
function DisableBitlocker {}
function WinExportLog {}


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

