<#
.SYNOPSIS
    WinToolkit - Sopravvivi a Windows
.DESCRIPTION
    Framework modulare unificato.
    Contiene le funzioni core (UI, Log, Info) e il menu principale.
.NOTES
    Autore: MagnetarMan
#>

param([int]$CountdownSeconds = 30, [switch]$ImportOnly)

# ==============================================================================
# SEZIONE 1 · BOOTSTRAP
# Wrapper Read-Host + impostazioni processo iniziali.
# Caricato per primo: tutto il resto dipende da questi fondamentali.
# ==============================================================================

function Read-Host {
    <#
    .SYNOPSIS
        Wrapper sicuro per Read-Host che gestisce le interruzioni CTRL+C senza crash.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [Object]$Prompt,
        [switch]$AsSecureString,
        [switch]$MaskInput
    )

    if ($Host.Name -ne 'ConsoleHost' -or $Global:GuiSessionActive) {
        if ($Prompt) { return Microsoft.PowerShell.Utility\Read-Host -Prompt $Prompt }
        return Microsoft.PowerShell.Utility\Read-Host
    }

    $oldTreatControlC = [console]::TreatControlCAsInput
    try { [console]::TreatControlCAsInput = $true } catch {}

    try {
        if ($Prompt) { Write-Host "${Prompt}: " -NoNewline -ForegroundColor Cyan }

        $inputString = ""
        while ($true) {
            $keyInfo = [console]::ReadKey($true)

            if ($keyInfo.Modifiers -match "Control" -and $keyInfo.Key -eq "C") {
                Write-Host ""
                return $null
            }
            if ($keyInfo.Key -eq "Enter") {
                Write-Host ""
                if ($AsSecureString) {
                    $secure = New-Object System.Security.SecureString
                    foreach ($char in $inputString.ToCharArray()) { $secure.AppendChar($char) }
                    return $secure
                }
                return $inputString ?? ""
            }
            if ($keyInfo.Key -eq "Backspace") {
                if ($inputString.Length -gt 0) {
                    $inputString = $inputString.Substring(0, $inputString.Length - 1)
                    Write-Host "`b `b" -NoNewline
                }
            }
            else {
                if (-not [char]::IsControl($keyInfo.KeyChar)) {
                    $inputString += $keyInfo.KeyChar
                    if ($AsSecureString -or $MaskInput) { Write-Host "*" -NoNewline -ForegroundColor Yellow }
                    else { Write-Host $keyInfo.KeyChar -NoNewline }
                }
            }
        }
    }
    catch {
        if ($Prompt) { return Microsoft.PowerShell.Utility\Read-Host -Prompt $Prompt }
        return Microsoft.PowerShell.Utility\Read-Host
    }
    finally {
        try { [console]::TreatControlCAsInput = $oldTreatControlC } catch {}
    }
}

$ErrorActionPreference = 'Stop'
try { $Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan" } catch {}


# ==============================================================================
# SEZIONE 2 · CONFIGURAZIONE GLOBALE
# Versione, URL, percorsi, chiavi di registro e variabili UI/esecuzione.
# ==============================================================================

$ToolkitVersion = "2.5.4 (Build 46)"

$AppConfig = @{
    URLs            = @{
        GitHubAssetBaseUrl    = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/"
        GitHubAssetDevBaseUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/"

        # Office
        OfficeSetup           = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Setup.exe"
        OfficeBasicConfig     = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Basic.xml"
        GetHelpInstaller      = "https://aka.ms/SaRA_EnterpriseVersionFiles"

        # Video Driver
        AMDInstaller          = "https://drivers.amd.com/drivers/installer/26.10/whql/amd-software-adrenalin-edition-26.5.2-minimalsetup-260513_web.exe"
        NVCleanstall          = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/NVCleanstall_1.19.0.exe"
        DDUZip                = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/DDU.zip"

        # Gaming
        DirectXWebSetup       = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/dxwebsetup.exe"
        BattleNetInstaller    = "https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"

        # 7-Zip
        SevenZipOfficial      = "https://www.7-zip.org/a/7zr.exe"

        # Store
        WingetInstaller       = "https://aka.ms/getwinget"
        VCRedist86            = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
        VCRedist64            = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    }
    Paths           = @{
        Root                 = "$env:LOCALAPPDATA\WinToolkit"
        Logs                 = "$env:LOCALAPPDATA\WinToolkit\logs"
        Temp                 = "$env:TEMP\WinToolkit"
        Drivers              = "$env:LOCALAPPDATA\WinToolkit\Drivers"
        OfficeTemp           = "$env:LOCALAPPDATA\WinToolkit\Office"
        DriverBackupTemp     = "$env:TEMP\DriverBackup_Temp"
        DriverBackupLogs     = "$env:LOCALAPPDATA\WinToolkit\logs"
        GamingDirectX        = "$env:LOCALAPPDATA\WinToolkit\Directx"
        GamingDirectXSetup   = "$env:LOCALAPPDATA\WinToolkit\Directx\dxwebsetup.exe"
        BattleNetSetup       = "$env:TEMP\Battle.net-Setup.exe"
        Desktop              = [Environment]::GetFolderPath('Desktop')
        Startup              = [Environment]::GetFolderPath('Startup')
        TempFolder           = $env:TEMP
        LocalAppData         = $env:LOCALAPPDATA
        System32             = "$env:windir\System32"
        SoftwareDistribution = "$env:windir\SoftwareDistribution"
        Catroot2             = "$env:windir\System32\catroot2"
    }
    Registry        = @{
        WindowsUpdatePolicies = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ExcludeWUDrivers      = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\ExcludeWUDriversInQualityUpdate"
        OfficeTelemetry       = "HKLM:\SOFTWARE\Microsoft\Office\Common\ClientTelemetry"
        DisableTelemetry      = "HKLM:\SOFTWARE\Microsoft\Office\Common\ClientTelemetry\DisableTelemetry"
        OfficeFeedback        = "HKLM:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback"
        OnBootNotify          = "HKLM:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback\OnBootNotify"
        BitLocker             = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
        BitLockerStatus       = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"
        FocusAssist           = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
        NoGlobalToasts        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\NOC_GLOBAL_SETTING_TOASTS_ENABLED"
        StartupRun            = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        WindowsTerminal       = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    }
    WindowsTerminal = @{
        DelegationTerminalClsid = "{E12F0936-0E6F-548E-A9F6-B20C69A27D17}"
        DelegationConsoleClsid  = "{B23D10C0-31E3-401A-97EF-4BB30B62E10B}"
    }
    WingetProcesses = @(
        'WinStore.App', 'wsappx', 'AppInstaller',
        'Microsoft.WindowsStore', 'Microsoft.DesktopAppInstaller',
        'winget', 'WindowsPackageManagerServer'
    )
}

$Global:Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
$Global:MsgStyles = @{
    Success  = @{ Icon = '✅'; Color = 'Green' }
    Warning  = @{ Icon = '⚠️'; Color = 'Yellow' }
    Error    = @{ Icon = '❌'; Color = 'Red' }
    Info     = @{ Icon = '💎'; Color = 'Cyan' }
    Progress = @{ Icon = '🔄'; Color = 'Magenta' }
    Question = @{ Icon = '❓'; Color = 'Cyan' }
}
$Global:ExecutionLog = @()
$Global:NeedsFinalReboot = $false


# ==============================================================================
# SEZIONE 3 · UI — RENDERING E PRESENTAZIONE
# Funzioni di output visuale: messaggi, barre, header, tabelle.
# Dipendono solo da $Global:MsgStyles e Write-ToolkitLog (Sezione 4).
# ==============================================================================

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

function Center-Text {
    param([string]$Text, [int]$Width = 0)
    if ($Width -eq 0) { $Width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 } }
    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    return (' ' * $padding + $Text)
}

function Write-StyledMessage {
    param(
        [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Progress', 'Question')][string]$Type,
        [string]$Text,
        [switch]$NoNewline
    )
    $style = $Global:MsgStyles[$Type]
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color -NoNewline:$NoNewline

    $logLevel = switch ($Type) {
        'Success' { 'SUCCESS' } 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' }
    }
    Write-ToolkitLog -Level $logLevel -Message $Text
}

function Show-ProgressBar {
    <#
    .SYNOPSIS
        Mostra una barra di progresso testuale nella console.
    #>
    param([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon = '⏳', [string]$Spinner = '', [string]$Color = 'Green')
    $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
    $filled = '█' * [math]::Floor($safePercent * 30 / 100)
    $empty = '░' * (30 - $filled.Length)
    $bar = "[$filled$empty] {0,3}%" -f $safePercent
    if (-not $Global:GuiSessionActive) {
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -ge 100) { Write-Host '' }
    }
}

function Show-Header {
    <#
    .SYNOPSIS
        Mostra l'intestazione standardizzata del toolkit.
    #>
    param([string]$SubTitle = "Menu Principale")
    if ($Global:GuiSessionActive) { return }
    try { Clear-Host } catch {}
    $width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 }
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
    foreach ($line in $asciiArt) { Write-Host (Center-Text $line $width) -ForegroundColor White }
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    Write-Host ''
}

function Show-ConsoleTable {
    <#
    .SYNOPSIS
        Visualizza dati in formato tabellare ASCII nella console.
    .PARAMETER Rows
        Array di hashtable o pscustomobject da visualizzare.
    .PARAMETER Columns
        Array di hashtable con chiavi 'Header' (string) e 'Key' (string). Opzionale: 'Color'.
    .PARAMETER Title
        Titolo opzionale da mostrare sopra la tabella.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object[]]$Rows,
        [Parameter(Mandatory = $true)][hashtable[]]$Columns,
        [string]$Title = ''
    )

    $widths = @{}
    foreach ($col in $Columns) { $widths[$col.Key] = $col.Header.Length }
    foreach ($row in $Rows) {
        foreach ($col in $Columns) {
            $val = if ($row -is [hashtable]) { "$($row[$col.Key])" } else { "$($row.$($col.Key))" }
            if ($val.Length -gt $widths[$col.Key]) { $widths[$col.Key] = $val.Length }
        }
    }

    $sep = '+' + (($Columns | ForEach-Object { '-' * ($widths[$_.Key] + 2) }) -join '+') + '+'

    if ($Title) {
        $totalWidth = $sep.Length
        $paddedTitle = " $Title "
        $pad = [Math]::Max(0, [Math]::Floor(($totalWidth - $paddedTitle.Length) / 2))
        Write-Host ('=' * $totalWidth) -ForegroundColor Cyan
        Write-Host ((' ' * $pad) + $paddedTitle) -ForegroundColor Cyan
        Write-Host ('=' * $totalWidth) -ForegroundColor Cyan
    }

    Write-Host $sep -ForegroundColor DarkGray
    $headerLine = '|'
    foreach ($col in $Columns) { $headerLine += ' ' + $col.Header.PadRight($widths[$col.Key]) + ' |' }
    Write-Host $headerLine -ForegroundColor Cyan
    Write-Host $sep -ForegroundColor DarkGray

    foreach ($row in $Rows) {
        $line = '|'
        foreach ($col in $Columns) {
            $val = if ($row -is [hashtable]) { "$($row[$col.Key])" } else { "$($row.$($col.Key))" }
            $line += ' ' + $val.PadRight($widths[$col.Key]) + ' |'
        }
        $rowColor = 'White'
        $statusKey = ($Columns | Where-Object { $_.Key -eq 'Status' -or $_.Key -eq 'Stato' } | Select-Object -First 1)?.Key
        if ($statusKey) {
            $statusVal = if ($row -is [hashtable]) { "$($row[$statusKey])" } else { "$($row.$statusKey)" }
            if ($statusVal -match '✅|OK|Successo|Completato') { $rowColor = 'Green' }
            elseif ($statusVal -match '⚠️|Warning|Parziale') { $rowColor = 'Yellow' }
            elseif ($statusVal -match '❌|Errore|Fallito') { $rowColor = 'Red' }
        }
        Write-Host $line -ForegroundColor $rowColor
    }
    Write-Host $sep -ForegroundColor DarkGray
}


# ==============================================================================
# SEZIONE 4 · LOGGING
# Motore di log dual-stream: header di sessione + scrittura strutturata su file.
# Usato da Write-StyledMessage e da tutti i tool via Write-ToolkitLog.
# ==============================================================================

function Start-ToolkitLog {
    <#
    .SYNOPSIS
        Inizializza il file di log strutturato per un tool specifico.
    #>
    param([string]$ToolName)

    $Global:CurrentToolName = $ToolName
    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}

    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = $AppConfig.Paths.Logs
    if (-not (Test-Path $logdir)) { New-Item -Path $logdir -ItemType Directory -Force | Out-Null }
    $Global:CurrentLogFile = "$logdir\${ToolName}_$dateTime.log"
    $Global:CurrentCorrelationId = [guid]::NewGuid().ToString()

    $os = Get-CimInstance Win32_OperatingSystem  -ErrorAction SilentlyContinue
    $psVer = $PSVersionTable.PSVersion.ToString()
    $psEd = $PSVersionTable.PSEdition
    $psCompat = ($PSVersionTable.PSCompatibleVersions | ForEach-Object { $_.ToString() }) -join ', '
    $gitId = if ($PSVersionTable.GitCommitId) { $PSVersionTable.GitCommitId } else { 'N/A' }
    $wsManVer = if ($PSVersionTable.WSManStackVersion) { $PSVersionTable.WSManStackVersion.ToString() } else { 'N/A' }
    $remoteVer = if ($PSVersionTable.PSRemotingProtocolVersion) { $PSVersionTable.PSRemotingProtocolVersion.ToString() } else { 'N/A' }
    $serVer = if ($PSVersionTable.SerializationVersion) { $PSVersionTable.SerializationVersion.ToString() } else { 'N/A' }

    $build = [int]$os.BuildNumber
    $verMap = @{26100 = '24H2'; 22631 = '23H2'; 22621 = '22H2'; 22000 = '21H2'; 19045 = '22H2'; 19044 = '21H2' }
    $dispVer = 'N/A'
    foreach ($k in ($verMap.Keys | Sort-Object -Descending)) { if ($build -ge $k) { $dispVer = $verMap[$k]; break } }

    $header = @"
[START LOG HEADER]
Start time              : $dateTime
CorrelationId           : $($Global:CurrentCorrelationId)
ToolName                : $ToolName
PSVersion               : $psVer
PSEdition               : $psEd
GitCommitId             : $gitId
ToolkitVersion          : $($Global:ToolkitVersion)
OS                      : $($os.Caption)
Version                 : Versione $dispVer (build SO $($os.BuildNumber))
Platform                : $([Environment]::OSVersion.Platform)
PSCompatibleVersions    : $psCompat
PSRemotingProtocolVersion: $remoteVer
SerializationVersion    : $serVer
WSManStackVersion       : $wsManVer
[END LOG HEADER]

"@
    try { Add-Content -Path $Global:CurrentLogFile -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}

function Write-ToolkitLog {
    <#
    .SYNOPSIS
        Scrive una riga di log strutturata solo su file. Mai su console.
        Resiliente: assorbe qualsiasi errore I/O senza crashare il toolkit.
    #>
    param(
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',
        [string]$Message,
        [hashtable]$Context = @{}
    )
    if (-not $Global:CurrentLogFile) { return }

    $ts = Get-Date -Format "HH:mm:ss"
    $clean = $Message -replace '^\s+', ''
    $clean = $clean -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
    $clean = $clean -replace '[⌀-⏿☀-➿\uD800-\uDFFF]', ''
    $line = "[$ts] [$Level] $clean"
    if ($Context.Count -gt 0) {
        try { $line += " | Context: " + ($Context | ConvertTo-Json -Compress -Depth 3) } catch {}
    }
    try {
        $mutex = New-Object System.Threading.Mutex($false, "Global\WinToolkitLogMutex")
        $hasHandle = $false
        try {
            $hasHandle = $mutex.WaitOne(5000)
            if ($hasHandle) { Add-Content -Path $Global:CurrentLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue }
        }
        finally {
            if ($hasHandle) { $mutex.ReleaseMutex() }
            $mutex.Dispose()
        }
    }
    catch {}
}


function Write-ToolkitError {
    <#
    .SYNOPSIS
        Scrive un errore strutturato su console e su file di log.
        Sostituisce il blocco catch+log ripetuto in ogni tool.
    #>
    param(
        [System.Management.Automation.ErrorRecord]$Record,
        [string]$ToolName,
        [string]$Message = "Errore critico"
    )
    Write-StyledMessage -Type 'Error' -Text "$Message in ${ToolName}: $($Record.Exception.Message)"
    Write-ToolkitLog -Level ERROR -Message "$Message in $ToolName" -Context @{
        Line      = $Record.InvocationInfo.ScriptLineNumber
        Exception = $Record.Exception.GetType().FullName
        Stack     = $Record.ScriptStackTrace
    }
}


# ==============================================================================
# SEZIONE 5 · SISTEMA — INFORMAZIONI E STATO
# Raccolta dati sul sistema operativo, hardware e servizi di sicurezza.
# ==============================================================================

function Get-SystemInfo {
    if ($Global:SystemInfoCache) { return $Global:SystemInfoCache }
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $computerInfo = Get-CimInstance Win32_ComputerSystem
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $versionMap = @{
            28000 = "26H1"; 26200 = "25H2"; 26100 = "24H2"; 22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2"
            19045 = "22H2"; 19044 = "21H2"; 19043 = "21H1"; 19042 = "20H2"; 19041 = "2004"; 18363 = "1909"
            18362 = "1903"; 17763 = "1809"; 17134 = "1803"; 16299 = "1709"; 15063 = "1703"; 14393 = "1607"
            10586 = "1511"; 10240 = "1507"
        }
        $build = [int]$osInfo.BuildNumber
        $ver = "N/A"
        foreach ($k in ($versionMap.Keys | Sort-Object -Descending)) { if ($build -ge $k) { $ver = $versionMap[$k]; break } }

        $Global:SystemInfoCache = @{
            ProductName    = $osInfo.Caption -replace 'Microsoft ', ''
            BuildNumber    = $build
            DisplayVersion = $ver
            Architecture   = $osInfo.OSArchitecture
            ComputerName   = $computerInfo.Name
            TotalRAM       = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
            TotalDisk      = [Math]::Round($diskInfo.Size / 1GB, 0)
            FreeDisk       = [Math]::Round($diskInfo.FreeSpace / 1GB, 0)
            FreePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)
        }
        return $Global:SystemInfoCache
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


function Get-LocalUserProfiles {
    <#
    .SYNOPSIS
        Restituisce le directory utente reali, escludendo i profili di sistema.
    #>
    return Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '^(Public|Default|Default User|All Users)$' }
}


# ==============================================================================
# SEZIONE 6 · AMBIENTE — PERCORSI E INIZIALIZZAZIONE
# Creazione directory di lavoro e refresh del PATH di processo.
# ==============================================================================

function Initialize-ToolkitPaths {
    <#
    .SYNOPSIS
        Assicura la creazione di tutte le directory necessarie al primo avvio.
    #>
    foreach ($path in $AppConfig.Paths.Values) {
        if (-not (Test-Path $path -PathType Leaf) -and $path -notmatch "\.exe$|\.zip$|\.msixbundle$") {
            try {
                if (-not (Test-Path $path)) { $null = New-Item -Path $path -ItemType Directory -Force -ErrorAction SilentlyContinue }
            }
            catch {}
        }
    }
}

function Update-EnvironmentPath {
    <#
    .SYNOPSIS
        Ricarica il PATH dalle variabili di sistema e utente per la sessione corrente.
    #>
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
    $env:Path = $newPath
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
}


function Set-RegistryValue {
    <#
    .SYNOPSIS
        Crea la chiave di registro se mancante e imposta il valore specificato.
    #>
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if (-not (Test-Path $Path)) { $null = New-Item -Path $Path -Force }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}


# ==============================================================================
# SEZIONE 7 · PROCESSI ED ESECUZIONE
# Chiusura processi, esecuzione comandi esterni con log, spinner, countdown.
# ==============================================================================

function Stop-ToolkitProcesses {
    <#
    .SYNOPSIS
        Chiude in modo forzato e silenzioso i processi specificati.
    #>
    param([string[]]$ProcessNames)
    Write-StyledMessage -Type Info -Text "Chiusura processi interferenti..."
    foreach ($procName in $ProcessNames) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -ne $PID } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
}

function Invoke-ExternalCommandWithLog {
    <#
    .SYNOPSIS
        Esegue un comando esterno con logging strutturato e cattura completa di STDOUT/STDERR.
    .DESCRIPTION
        Wrapper standardizzato per processi esterni.
        Logga comando, argomenti, exit code, durata ed eventuali errori.
        Restituisce un oggetto con Success, ExitCode, StdOut, StdErr, Elapsed.
        Non scrive mai direttamente su console.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory,
        [int]$TimeoutSeconds = 0,
        [string]$LogContextKey = '',
        [string]$Activity = '',
        [int]$UpdateInterval = 500,
        [string]$Tool = $Global:CurrentToolName,
        [string]$Step = 'ExternalCommand'
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $startTime = Get-Date
    $argString = $Arguments -join ' '

    Write-ToolkitLog -Level 'INFO' -Message "Esecuzione comando: $Command $argString (Timeout: ${TimeoutSeconds}s)"
    Write-ToolkitLog -Level 'DEBUG' -Message "Contesto comando" -Context @{
        Tool = $Tool; Step = $Step; WorkingDir = $WorkingDirectory; ContextKey = $LogContextKey
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Command
    $psi.Arguments = $argString
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $outText = ""; $errText = ""; $success = $false; $exitCode = $null; $timedOut = $false

    try {
        if (-not $proc.Start()) { throw "Impossibile avviare il processo esterno." }

        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()

        if ($Activity) {
            $spinnerIndex = 0; $percent = 0
            while (-not $proc.HasExited -and ($TimeoutSeconds -eq 0 -or ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds)) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                if ($percent -lt 90) { $percent += Get-Random -Minimum 1 -Maximum 3 }
                Show-ProgressBar -Activity $Activity -Status "Esecuzione in corso... ($elapsed secondi)" -Percent $percent -Icon '⏳' -Spinner $spinner
                Start-Sleep -Milliseconds $UpdateInterval
                $proc.Refresh()
            }
            if (-not $proc.HasExited -and $TimeoutSeconds -gt 0) {
                try { $proc.Kill() } catch {}
                throw "Timeout dopo $TimeoutSeconds secondi."
            }
            Show-ProgressBar -Activity $Activity -Status 'Completato' -Percent 100 -Icon '✅'
            if (-not $Global:GuiSessionActive) { Write-Host "" }
        }
        else {
            if ($TimeoutSeconds -gt 0) {
                if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
                    try { $proc.Kill() } catch {}
                    throw "Timeout dopo $TimeoutSeconds secondi."
                }
            }
            else { $proc.WaitForExit() }
        }

        try { [System.Threading.Tasks.Task]::WaitAll($outTask, $errTask) } catch {}
        if ($outTask.Status -eq 'RanToCompletion') { $outText = $outTask.Result }
        if ($errTask.Status -eq 'RanToCompletion') { $errText = $errTask.Result }

        $exitCode = $proc.ExitCode
        $success = ($exitCode -eq 0)
    }
    catch {
        $exitCode = if ($exitCode -ne $null) { $exitCode } else { -1 }
        if ($_.Exception.Message -match 'Timeout') { $timedOut = $true }
        Write-ToolkitLog -Level 'ERROR' -Message "Eccezione durante esecuzione comando esterno" -Context @{
            Command = $Command; Arguments = $Arguments; WorkingDir = $WorkingDirectory
            TimeoutSec = $TimeoutSeconds; ContextKey = $LogContextKey
            Exception = $_.Exception.Message; Stack = $_.ScriptStackTrace
        }
    }
    finally {
        $stopwatch.Stop()
        if ($null -eq $outText) { $outText = "" }
        if ($null -eq $errText) { $errText = "" }

        $maxLen = 8000
        $outLogged = if ($outText.Length -gt $maxLen) { $outText.Substring(0, $maxLen) + "`n[...output troncato...]" } else { $outText }
        $errLogged = if ($errText.Length -gt $maxLen) { $errText.Substring(0, $maxLen) + "`n[...stderr troncato...]" } else { $errText }

        $statusMsg = if ($success) { "Completato con successo" } else { "Completato con errori" }
        Write-ToolkitLog -Level 'INFO'  -Message "Comando $statusMsg (ExitCode: $exitCode, Durata: $($stopwatch.Elapsed.ToString('hh\:mm\:ss')))"
        Write-ToolkitLog -Level 'DEBUG' -Message "Output comando ($Command)" -Context @{
            ContextKey = $LogContextKey; StdOutSnippet = $outLogged; StdErrSnippet = $errLogged
        }
        if ($proc) { $proc.Dispose() }
    }

    [pscustomobject]@{
        Success  = $success
        ExitCode = $exitCode
        StdOut   = $outText
        StdErr   = $errText
        Elapsed  = $stopwatch.Elapsed
        TimedOut = $timedOut
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
        [Parameter(Mandatory = $true)][string]$Activity,
        [scriptblock]$Action,
        [int]$TimeoutSeconds = 300,
        [int]$UpdateInterval = 500,
        [switch]$Process,
        [switch]$Job,
        [switch]$Timer,
        [scriptblock]$PercentUpdate,
        [string]$Command,
        [string[]]$Arguments = @(),
        [string]$LogContextKey = ''
    )

    $startTime = Get-Date
    $spinnerIndex = 0
    $percent = 0

    if ($Command) {
        return Invoke-ExternalCommandWithLog -Command $Command -Arguments $Arguments `
            -TimeoutSeconds $TimeoutSeconds -Activity $Activity -UpdateInterval $UpdateInterval -LogContextKey $LogContextKey
    }

    try {
        $result = & $Action

        if ($Timer) {
            $totalSeconds = $TimeoutSeconds
            for ($i = $totalSeconds; $i -gt 0; $i--) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                $percent = if ($PercentUpdate) { & $PercentUpdate } else { [math]::Round((($totalSeconds - $i) / $totalSeconds) * 100) }
                if (-not $Global:GuiSessionActive) { Write-Host "`r$spinner ⏳ $Activity - $i secondi..." -NoNewline -ForegroundColor Yellow }
                Start-Sleep -Seconds 1
            }
            if (-not $Global:GuiSessionActive) { Write-Host '' }
            return $true
        }
        elseif ($Process -and $result -and $result.GetType().Name -eq 'Process') {
            while (-not $result.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                $percent = if ($PercentUpdate) { & $PercentUpdate } elseif ($percent -lt 90) { $percent + (Get-Random -Minimum 1 -Maximum 3) } else { $percent }
                if (-not $Global:GuiSessionActive) { Write-Host "`r" -NoNewline }
                Show-ProgressBar -Activity $Activity -Status "Esecuzione in corso... ($elapsed secondi)" -Percent $percent -Icon '⏳' -Spinner $spinner
                Start-Sleep -Milliseconds $UpdateInterval
                $result.Refresh()
            }
            if (-not $result.HasExited) {
                if (-not $Global:GuiSessionActive) { Write-Host "" }
                Write-StyledMessage -Type 'Warning' -Text "Timeout raggiunto dopo $TimeoutSeconds secondi, terminazione processo..."
                $result.Kill(); Start-Sleep -Seconds 2
                return @{ Success = $false; TimedOut = $true; ExitCode = -1 }
            }
            if (-not $Global:GuiSessionActive) { Clear-ProgressLine }
            Show-ProgressBar -Activity $Activity -Status 'Completato' -Percent 100 -Icon '✅'
            if (-not $Global:GuiSessionActive) { Write-Host "" }
            return @{ Success = $true; TimedOut = $false; ExitCode = $result.ExitCode }
        }
        elseif ($Job -and $result -and $result.GetType().Name -eq 'Job') {
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
            Start-Sleep -Seconds $TimeoutSeconds
            return $result
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante ${Activity}: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Start-InterruptibleCountdown {
    <#
    .SYNOPSIS
        Conto alla rovescia interrompibile dall'utente con pressione di un tasto.
    #>
    param([int]$Seconds = 30, [string]$Message = "Riavvio automatico", [switch]$Suppress)
    if ($Suppress) { return $true }

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
        $bar = "[$('█' * $filled)$('▒' * (20 - $filled))]"
        Write-Host "`r⏰ $Message tra $i secondi $bar" -NoNewline -ForegroundColor Red
        Start-Sleep 1
    }
    Write-Host "`n"
    return $true
}


function Start-ToolkitSession {
    <#
    .SYNOPSIS
        Inizializzazione standard di ogni tool: log, header, titolo finestra.
        Sostituisce il blocco di 3 righe identico presente in tutti i tool.
    #>
    param([string]$ToolName, [string]$SubTitle = $ToolName)
    Start-ToolkitLog -ToolName $ToolName
    Show-Header -SubTitle $SubTitle
    try { $Host.UI.RawUI.WindowTitle = "$SubTitle By MagnetarMan" } catch {}
}

function Invoke-ToolkitReboot {
    <#
    .SYNOPSIS
        Gestione centralizzata del riavvio: soppresso (multi-script) o countdown interrompibile.
        Sostituisce il blocco if/else da 9 righe presente in 11 tool.
    #>
    param(
        [string]$Message = "Operazione completata",
        [int]$Seconds = 30,
        [switch]$SuppressIndividualReboot
    )
    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
        Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
    }
    else {
        if (Start-InterruptibleCountdown -Seconds $Seconds -Message $Message) {
            Restart-Computer -Force
        }
    }
}

function Remove-ItemSafely {
    <#
    .SYNOPSIS
        Rimuove un path (file o directory) in modo silenzioso, senza eccezioni.
        Versione generalizzata di Invoke-OfficeSilentRemoval.
    #>
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$Recurse)
    if (-not (Test-Path $Path)) { return $false }
    try {
        $params = @{ Path = $Path; Force = $true; ErrorAction = 'SilentlyContinue' }
        if ($Recurse) { $params['Recurse'] = $true }
        Remove-Item @params *>$null
        Clear-ProgressLine
        return $true
    }
    catch { return $false }
}

function Invoke-ToolkitDownload {
    <#
    .SYNOPSIS
        Download di un file con retry automatico e messaggi standardizzati.
        Versione unificata dei 3 pattern di download esistenti nel progetto.
    #>
    param(
        [string]$Uri,
        [string]$OutputPath,
        [string]$Description = "file",
        [int]$MaxRetries = 3
    )
    Write-StyledMessage -Type 'Info' -Text "📥 Download $Description."
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($Uri, $OutputPath)
            $wc.Dispose()
            if (Test-Path $OutputPath) {
                Write-StyledMessage -Type 'Success' -Text "Download completato: $Description."
                return $true
            }
        }
        catch {
            if ($attempt -lt $MaxRetries) {
                Write-StyledMessage -Type 'Warning' -Text "Tentativo $attempt/$MaxRetries fallito. Riprovo..."
                Start-Sleep -Seconds 2
            }
        }
    }
    Write-StyledMessage -Type 'Error' -Text "Download fallito dopo $MaxRetries tentativi: $Description."
    return $false
}

function Restart-ServiceSafely {
    <#
    .SYNOPSIS
        Stop + Start di un servizio Windows con gestione errori standardizzata.
    #>
    param([string]$Name, [int]$WaitSeconds = 1)
    try {
        Stop-Service -Name $Name -Force -ErrorAction Stop
        Start-Sleep -Seconds $WaitSeconds
        Start-Service -Name $Name -ErrorAction Stop
        Write-StyledMessage -Type 'Success' -Text "Servizio riavviato: $Name."
        return $true
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text "Impossibile riavviare '$Name': $($_.Exception.Message)."
        return $false
    }
}


# ==============================================================================
# SEZIONE 8 · WINGET — INSTALLAZIONE E RIPRISTINO
# Risoluzione eseguibile, installazione AppX silenziosa, validazione e reset.
# ==============================================================================

function Get-WingetExecutable {
    <#
    .SYNOPSIS
        Risolve il percorso di winget.exe privilegiando l'App Execution Alias.
    #>
    $aliasPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path $aliasPath) { return $aliasPath }

    $arch = [Environment]::Is64BitOperatingSystem ? "x64" : "x86"
    $wingetDir = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" `
        -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1

    if ($wingetDir) {
        $exe = Join-Path $wingetDir.FullName "winget.exe"
        if (Test-Path $exe) { return $exe }
    }
    return "winget"
}

function Start-AppxSilentProcess {
    <#
    .SYNOPSIS
        Installa un AppX tramite System.Diagnostics.Process (CreateNoWindow=true).
        Blocca le write Win32 native del deployment engine e gestisce il downgrade.
    #>
    param(
        [string]$AppxPath,
        [string]$Flags = '-ForceApplicationShutdown',
        [string[]]$DependencyPaths = @()
    )

    $pathParam = ($Flags -match '-Register') ? "" : "-Path '$($AppxPath -replace "'", "''")'"
    $depString = ""
    if ($DependencyPaths.Count -gt 0) {
        $depString = "-DependencyPackagePath " + (($DependencyPaths | ForEach-Object { "'$($_ -replace "'", "''")'" }) -join ", ")
    }

    $cmd = @"
`$ProgressPreference = 'SilentlyContinue';
`$ErrorActionPreference = 'SilentlyContinue';
try {
    Add-AppxPackage $pathParam $depString $Flags -ErrorAction Stop | Out-Null
}
catch {
    if (`$_.Exception.Message -match '0x80073D06' -or `$_.Exception.Message -match 'versione successiva') { exit 0 }
    if (`$_.Exception.Message -match '0x80073CF9' -or ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)) {
        try {
            if ('$pathParam' -eq '') { exit 1 }
            Add-AppxProvisionedPackage -Online -PackagePath '$($AppxPath -replace "'", "''")' $depString -SkipLicense -ErrorAction Stop | Out-Null
            exit 0
        }
        catch { exit 1 }
    }
    exit 1
}
exit 0
"@
    $encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -NonInteractive -EncodedCommand $encodedCmd"
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    return [System.Diagnostics.Process]::Start($psi)
}

function Wait-WingetReady {
    <#
    .SYNOPSIS
        Polling fino a 5 minuti per verificare che Winget sia pronto e il database sbloccato.
    #>
    param([int]$MaxWaitSeconds = 300, [int]$PollIntervalSeconds = 5)

    Write-StyledMessage -Type Info -Text "🔍 Validazione integrità Winget in corso (timeout: $MaxWaitSeconds s)..."
    $wingetExe = Get-WingetExecutable
    $maxRetries = [Math]::Floor($MaxWaitSeconds / $PollIntervalSeconds)

    for ($i = 1; $i -le $maxRetries; $i++) {
        try {
            $versionProc = Start-Process -FilePath $wingetExe -ArgumentList '--version' `
                -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
            $dbProc = Start-Process -FilePath $wingetExe `
                -ArgumentList 'list', 'NonExistentApp_WinToolkitCheck', '--accept-source-agreements' `
                -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
            if ($versionProc.ExitCode -eq 0 -and $dbProc.ExitCode -eq 0) {
                Write-StyledMessage -Type Success -Text "✅ Winget pronto e database sbloccato (tentativo $i/$maxRetries)."
                return $true
            }
        }
        catch {}
        $remaining = $MaxWaitSeconds - ($i * $PollIntervalSeconds)
        Write-StyledMessage -Type Progress -Text "⏳ Winget non ancora pronto (tentativo $i/$maxRetries, restano $remaining s). Attesa..."
        Start-Sleep -Seconds $PollIntervalSeconds
    }
    Write-StyledMessage -Type Warning -Text "⚠️ Winget non ha risposto entro $MaxWaitSeconds secondi. Proseguo comunque."
    return $false
}

function Reset-Winget {
    <#
    .SYNOPSIS
        Verifica, ripristina e testa l'installazione di Winget.
    .DESCRIPTION
        Procedura integrata a due fasi per la riparazione completa di Winget.

        Fase 1 — Ripristino Core (veloce):
          VC++ Redistributable, dipendenze AppX dal repo ufficiale, MSIXBundle principale.

        Fase 2 — Ripristino Avanzato (se Fase 1 insufficiente):
          Microsoft.WinGet.Client, Repair-WinGetPackageManager, ripristino database,
          reset permessi e PATH.

        Include validazione profonda post-installazione con rilevamento ACCESS_VIOLATION.
    #>
    param([switch]$Force)

    $ProgressPreference = 'SilentlyContinue'
    $OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

    # ── Helper privati ────────────────────────────────────────────────────────

    function _Test-VCRedistInstalled {
        $64BitOS = [System.Environment]::Is64BitOperatingSystem
        $registryPath = [string]::Format(
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\{0}\Microsoft\VisualStudio\14.0\VC\Runtimes\X{1}',
            $(if ($64BitOS) { 'WOW6432Node' } else { '' }),
            $(if ($64BitOS) { '64' } else { '86' })
        )
        $major = (Get-ItemProperty -Path $registryPath -Name 'Major' -ErrorAction SilentlyContinue).Major
        $dllPath = [string]::Format('{0}\system32\concrt140.dll', $env:windir)
        return (Test-Path $registryPath) -and ($major -ge 14) -and (Test-Path $dllPath)
    }

    function _Register-AppxManifest {
        try {
            $manifest = (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue).InstallLocation
            if ($manifest) {
                $manifestXml = Join-Path $manifest 'AppxManifest.xml'
                if (Test-Path $manifestXml) {
                    Write-StyledMessage -Type Info -Text "Re-registrazione manifest: AppxManifest.xml previene leak."
                    Start-AppxSilentProcess -AppxPath $manifestXml -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown' | Out-Null
                }
            }
        }
        catch {}
    }

    function _Get-LatestAssetUrl {
        param([string]$Match)
        try {
            $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing -ErrorAction Stop
            $asset = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
            return $asset ? $asset.browser_download_url : $null
        }
        catch { return $null }
    }

    function _Test-WingetCompatibility {
        $os = [Environment]::OSVersion.Version
        if ($os.Major -lt 10 -or ($os.Major -eq 10 -and $os.Build -lt 16299)) {
            Write-StyledMessage -Type Error -Text "Sistema non supportato da Winget (richiesto Windows 10 1709+)."
            return $false
        }
        return $true
    }

    function _Test-WingetFunctionality {
        Update-EnvironmentPath
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type Warning -Text "Winget non trovato nel PATH."
            return $false
        }
        try {
            $versionOutput = (& (Get-WingetExecutable) --version 2>$null) | Out-String
            if ($LASTEXITCODE -eq 0 -and $versionOutput -match 'v\d+\.\d+') {
                Write-StyledMessage -Type Success -Text "Winget operativo (versione: $($versionOutput.Trim()))."
                return $true
            }
            Write-StyledMessage -Type Warning -Text "Winget presente ma non risponde correttamente (ExitCode: $LASTEXITCODE)."
            return $false
        }
        catch {
            Write-StyledMessage -Type Warning -Text "Errore durante test Winget: $($_.Exception.Message)."
            return $false
        }
    }

    function _Test-PathInEnvironment {
        param([string]$PathToCheck, [string]$Scope = 'Both')
        $found = $false
        if ($Scope -in 'User', 'Both') { if (($env:PATH -split ';').Contains($PathToCheck)) { $found = $true } }
        if ($Scope -in 'System', 'Both') {
            $syspath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
            if (($syspath -split ';').Contains($PathToCheck)) { $found = $true }
        }
        return $found
    }

    function _Add-ToEnvironmentPath {
        param([string]$PathToAdd, [ValidateSet('User', 'System')][string]$Scope)
        if (_Test-PathInEnvironment -PathToCheck $PathToAdd -Scope $Scope) { return }
        if ($Scope -eq 'System') {
            $cur = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
            [Environment]::SetEnvironmentVariable('PATH', "$cur;$PathToAdd", 'Machine')
        }
        else {
            $cur = [Environment]::GetEnvironmentVariable('PATH', 'User')
            [Environment]::SetEnvironmentVariable('PATH', "$cur;$PathToAdd", 'User')
        }
        if (-not ($env:PATH -split ';').Contains($PathToAdd)) { $env:PATH += ";$PathToAdd" }
        Write-StyledMessage -Type Info -Text "PATH aggiornato: $PathToAdd."
    }

    function _Set-PathPermissions {
        param([string]$FolderPath)
        if (-not (Test-Path $FolderPath)) { return }
        try {
            $sid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
            $group = $sid.Translate([System.Security.Principal.NTAccount])
            $acl = Get-Acl -Path $FolderPath -ErrorAction Stop
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $group, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $acl.SetAccessRule($rule)
            Set-Acl -Path $FolderPath -AclObject $acl -ErrorAction Stop
            Write-StyledMessage -Type Info -Text "Permessi cartella aggiornati: $FolderPath."
        }
        catch { Write-StyledMessage -Type Warning -Text "Impossibile impostare permessi su '$FolderPath': $($_.Exception.Message)." }
    }

    function _Set-WingetPathPermissions {
        $wingetFolderPath = $null
        try {
            $arch = [Environment]::Is64BitOperatingSystem ? 'x64' : 'x86'
            $wingetDir = Get-ChildItem "$env:ProgramFiles\WindowsApps" `
                -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
            if ($wingetDir) { $wingetFolderPath = $wingetDir.FullName }
        }
        catch {}
        if ($wingetFolderPath) {
            _Set-PathPermissions -FolderPath $wingetFolderPath
            _Add-ToEnvironmentPath -PathToAdd $wingetFolderPath -Scope 'System'
            _Add-ToEnvironmentPath -PathToAdd '%LOCALAPPDATA%\Microsoft\WindowsApps' -Scope 'User'
            Write-StyledMessage -Type Success -Text "PATH e permessi Winget aggiornati."
        }
    }

    function _Repair-WingetDatabase {
        Write-StyledMessage -Type Info -Text "🔧 Ripristino database Winget."
        try {
            Stop-ToolkitProcesses -ProcessNames $AppConfig.WingetProcesses

            $cachePath = "$env:LOCALAPPDATA\WinGet"
            if (Test-Path $cachePath) {
                Write-StyledMessage -Type Info -Text "Pulizia cache Winget."
                Get-ChildItem -Path $cachePath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '\\lock\\|\\tmp\\' } |
                ForEach-Object { try { Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue } catch {} }
            }

            @("$env:LOCALAPPDATA\WinGet\Data\USERTEMPLATE.json",
                "$env:LOCALAPPDATA\WinGet\Data\DEFAULTUSER.json") | ForEach-Object {
                if (Test-Path $_ -PathType Leaf) {
                    Write-StyledMessage -Type Info -Text "Reset file stato: $_."
                    Remove-Item $_ -Force -ErrorAction SilentlyContinue
                }
            }

            try { $null = & (Get-WingetExecutable) source reset --force 2>&1 } catch {}

            if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
                Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
            }

            try {
                $manifest = (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue).InstallLocation
                if ($manifest) {
                    $manifestXml = Join-Path $manifest 'AppxManifest.xml'
                    if (Test-Path $manifestXml) {
                        Write-StyledMessage -Type Info -Text "Re-registrazione manifest: AppxManifest.xml."
                        Start-AppxSilentProcess -AppxPath $manifestXml -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown' | Out-Null
                    }
                }
            }
            catch {}

            try {
                if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                    Write-StyledMessage -Type Info -Text "Esecuzione Repair-WinGetPackageManager."
                    Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                }
            }
            catch {
                if ($_.Exception.Message -match '0x80073D06' -or $_.Exception.Message -match 'versione successiva') {
                    Write-StyledMessage -Type Success -Text "Repair-WinGetPackageManager completato (versione superiore già presente)."
                }
                else { Write-StyledMessage -Type Warning -Text "Repair-WinGetPackageManager fallito: $($_.Exception.Message)." }
            }

            _Set-WingetPathPermissions
            Update-EnvironmentPath
            return $true
        }
        catch {
            Write-StyledMessage -Type Error -Text "Errore durante ripristino database: $($_.Exception.Message)."
            return $false
        }
    }

    function _Install-WingetAdvanced {
        Write-StyledMessage -Type Info -Text "🚀 Installazione avanzata tramite modulo Microsoft.WinGet.Client."
        try {
            if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
                if ($PSVersionTable.PSVersion.Major -lt 7) {
                    try { Install-PackageProvider -Name 'NuGet' -Force -ForceBootstrap -ErrorAction SilentlyContinue *>$null }
                    catch { Write-StyledMessage -Type Warning -Text "NuGet provider non installabile." }
                }
            }

            Write-StyledMessage -Type Info -Text "Installazione modulo Microsoft.WinGet.Client."
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
                Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
                Write-StyledMessage -Type Success -Text "Modulo WinGet Client installato."
            }
            catch { Write-StyledMessage -Type Warning -Text "Impossibile installare modulo WinGet Client: $($_.Exception.Message)." }

            if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Info -Text "Tentativo Repair-WinGetPackageManager."
                try {
                    Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                    Write-StyledMessage -Type Success -Text "Repair-WinGetPackageManager completato."
                }
                catch {
                    if ($_.Exception.Message -match '0x80073D06' -or $_.Exception.Message -match 'versione successiva') {
                        Write-StyledMessage -Type Success -Text "Repair-WinGetPackageManager ignorato (versione superiore già presente)."
                    }
                    else { Write-StyledMessage -Type Warning -Text "Repair-WinGetPackageManager fallito: $($_.Exception.Message)." }
                }
                Start-Sleep 3
            }

            Update-EnvironmentPath
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                Write-StyledMessage -Type Info -Text "Fallback: Download MSIXBundle diretto da Microsoft."
                $tempDir = $AppConfig.Paths.Temp
                if (-not (Test-Path $tempDir)) { $null = New-Item -Path $tempDir -ItemType Directory -Force }
                $tempInstaller = Join-Path $tempDir "WingetInstaller.msixbundle"
                Invoke-WebRequest -Uri $AppConfig.URLs.WingetInstaller -OutFile $tempInstaller -UseBasicParsing -ErrorAction Stop
                Start-AppxSilentProcess -AppxPath $tempInstaller -Flags '-ForceApplicationShutdown'
                Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
                Start-Sleep 3
            }

            try { Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null } catch {}
            _Set-WingetPathPermissions
            Update-EnvironmentPath
            return $true
        }
        catch {
            Write-StyledMessage -Type Error -Text "Errore installazione avanzata Winget: $($_.Exception.Message)."
            return $false
        }
    }

    function _Test-WingetDeepValidation {
        Write-StyledMessage -Type Info -Text "🔍 Validazione profonda Winget (connettività + integrità database)."
        try {
            $wingetExe = Get-WingetExecutable
            $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                Write-StyledMessage -Type Warning -Text "⚠️ Crash ACCESS_VIOLATION (ExitCode: $exitCode). Ripristino database."
                $null = _Repair-WingetDatabase
                Start-Sleep 3
                $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
                $exitCode = $LASTEXITCODE
                if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                    Write-StyledMessage -Type Warning -Text "⚠️ Crash persistente dopo ripristino database."
                    return $false
                }
            }

            if ($exitCode -eq 0) {
                Write-StyledMessage -Type Success -Text "✅ Validazione profonda superata: Winget comunica con i repository."
                return $true
            }
            $details = ($searchResult | Out-String).Trim()
            if ($details.Length -gt 200) { $details = $details.Substring(0, 200) + "..." }
            Write-StyledMessage -Type Warning -Text "⚠️ Validazione profonda fallita (ExitCode=$exitCode). Dettagli: $details"
            return $false
        }
        catch {
            Write-StyledMessage -Type Error -Text "Errore validazione profonda: $($_.Exception.Message)."
            return $false
        }
    }

    # ── Orchestrazione principale ─────────────────────────────────────────────

    Write-StyledMessage -Type Info -Text "🚀 Avvio riparazione avanzata Winget..."
    if (-not (_Test-WingetCompatibility)) { return $false }
    if (-not $Force -and (_Test-WingetFunctionality)) {
        Write-StyledMessage -Type Success -Text "✅ Winget già operativo. Nessuna riparazione necessaria."
        return $true
    }

    Stop-ToolkitProcesses -ProcessNames $AppConfig.WingetProcesses

    try {
        # Fase 1: Ripristino Core
        Write-StyledMessage -Type Info -Text "⚡ Fase 1: Ripristino Core (VC++, dipendenze AppX, MSIXBundle)."

        if (-not (_Test-VCRedistInstalled) -or $Force) {
            Write-StyledMessage -Type Info -Text "Installazione Visual C++ Redistributable..."
            $arch = [Environment]::Is64BitOperatingSystem ? "x64" : "x86"
            $vcUrl = "https://aka.ms/vs/17/release/vc_redist.$arch.exe"
            $vcFile = Join-Path $AppConfig.Paths.Temp "vc_redist.exe"
            if (-not (Test-Path $AppConfig.Paths.Temp)) { $null = New-Item $AppConfig.Paths.Temp -ItemType Directory -Force }
            Invoke-WebRequest -Uri $vcUrl -OutFile $vcFile -UseBasicParsing
            Start-Process -FilePath $vcFile -ArgumentList "/install", "/quiet", "/norestart" -Wait
            Write-StyledMessage -Type Success -Text "VC++ Redist installato."
        }

        Write-StyledMessage -Type Info -Text "Download dipendenze Winget dal repository ufficiale..."
        $depUrl = _Get-LatestAssetUrl -Match 'DesktopAppInstaller_Dependencies.zip'
        if ($depUrl) {
            $depZip = Join-Path $AppConfig.Paths.Temp "dependencies.zip"
            $depDir = Join-Path $AppConfig.Paths.Temp "deps"
            Invoke-WebRequest -Uri $depUrl -OutFile $depZip -UseBasicParsing
            Expand-Archive -Path $depZip -DestinationPath $depDir -Force
            $archPattern = [Environment]::Is64BitOperatingSystem ? "x64|ne" : "x86|ne"
            $script:WingetDependencies = @()
            Get-ChildItem $depDir -Recurse -Filter "*.appx" |
            Where-Object { $_.Name -match $archPattern } |
            ForEach-Object { Write-StyledMessage -Type Info -Text "Trovata dipendenza: $($_.Name)."; $script:WingetDependencies += $_.FullName }
            Write-StyledMessage -Type Success -Text "Dipendenze caricate."
        }

        Write-StyledMessage -Type Info -Text "Installazione Winget MSIXBundle (con dipendenze)..."
        $bundleUrl = _Get-LatestAssetUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        if ($bundleUrl) {
            $bundleFile = Join-Path $AppConfig.Paths.Temp "winget.msixbundle"
            Invoke-WebRequest -Uri $bundleUrl -OutFile $bundleFile -UseBasicParsing
            $deps = if ($script:WingetDependencies) { $script:WingetDependencies } else { @() }
            Start-AppxSilentProcess -AppxPath $bundleFile -DependencyPaths $deps -Flags '-ForceApplicationShutdown'
            Write-StyledMessage -Type Success -Text "Winget Core installato."
        }

        _Register-AppxManifest
        Update-EnvironmentPath

        if (_Test-WingetFunctionality) {
            Write-StyledMessage -Type Success -Text "✅ Fase 1 completata. Winget operativo."
        }
        else {
            # Fase 2: Ripristino Avanzato
            Write-StyledMessage -Type Warning -Text "⚠️ Fase 1 insufficiente. Avvio Fase 2: Ripristino Avanzato."
            $null = _Install-WingetAdvanced
            $null = _Repair-WingetDatabase
            Update-EnvironmentPath
        }

        Start-Sleep -Seconds 3
        try {
            Start-Process -FilePath (Get-WingetExecutable) -ArgumentList 'source', 'reset', '--force' `
                -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        }
        catch {}

        $deepOk = _Test-WingetDeepValidation
        if ($deepOk) {
            Write-StyledMessage -Type Success -Text "✅ Winget ripristinato e testato con successo."
            return $true
        }
        else {
            Write-StyledMessage -Type Warning -Text "⚠️ Winget installato. Validazione profonda con anomalie (possibili problemi di rete o DB)."
            return $true
        }
    }
    catch {
        Write-StyledMessage -Type Error -Text "❌ Errore critico nel reset: $($_.Exception.Message)"
        return $false
    }
    finally {
        if (Test-Path $AppConfig.Paths.Temp) { Remove-Item $AppConfig.Paths.Temp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}


# ==============================================================================
# SEZIONE 9 · INTERAZIONE UTENTE
# Input validato, conferme e selezioni di menu.
# ==============================================================================

function Get-UserConfirmation {
    <#
    .SYNOPSIS
        Richiede conferma all'utente (Sì/No) in modo standardizzato.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [switch]$DefaultYes,
        [ValidateSet('Info', 'Warning', 'Question')][string]$Level = 'Question'
    )

    $choices = if ($DefaultYes) { "[S/n]" } else { "[s/N]" }
    $fullPrompt = "$Prompt $choices"

    if ($Global:GuiSessionActive) {
        Write-StyledMessage -Type $Level -Text $fullPrompt
        return $true
    }

    Write-StyledMessage -Type $Level -Text "${fullPrompt}: " -NoNewline
    $response = Read-Host
    Write-ToolkitLog -Level 'INFO' -Message "User Confirmation Prompt: $Prompt | Response: $response"

    if ([string]::IsNullOrWhiteSpace($response)) { return $DefaultYes }
    return $response -match '^[sS]'
}

function Read-ValidatedChoice {
    <#
    .SYNOPSIS
        Legge e valida scelte numeriche dall'utente (singole o multiple).
    #>
    param(
        [int[]]$ValidRange,
        [int]$Min,
        [int]$Max,
        [switch]$AllowZero,
        [string]$Prompt = "Seleziona un'opzione",
        [string]$RawInput
    )

    $currentInput = if ($PSBoundParameters.ContainsKey('RawInput')) { $RawInput } else { $null }
    while ($true) {
        $input = if ($null -ne $currentInput) {
            $val = $currentInput; $currentInput = $null; $val
        }
        else {
            Write-StyledMessage -Type 'Question' -Text "${Prompt}: " -NoNewline
            Microsoft.PowerShell.Utility\Read-Host
        }

        if ([string]::IsNullOrWhiteSpace($input)) {
            Write-StyledMessage -Type Warning -Text "⚠️ Input vuoto. Riprova."
            continue
        }

        $choices = $input -split '[\s,]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }

        if ($choices.Count -gt 0) {
            $isValid = $true
            foreach ($c in $choices) {
                if ($null -ne $ValidRange) { if ($c -notin $ValidRange) { $isValid = $false; break } }
                else {
                    if ($AllowZero -and $c -eq 0) { continue }
                    if ($null -ne $Min -and $c -lt $Min) { $isValid = $false; break }
                    if ($null -ne $Max -and $c -gt $Max) { $isValid = $false; break }
                }
            }
            if ($isValid) {
                Write-ToolkitLog -Level 'INFO' -Message "User Choices: $($choices -join ',')"
                return $choices
            }
        }

        $rangeStr = if ($null -ne $ValidRange) { "$($ValidRange[0]) e $($ValidRange[-1])" } else { "$Min e $Max" }
        Write-StyledMessage -Type Warning -Text "⚠️ Scelta non valida. Inserisci numeri compresi tra $rangeStr."
    }
}


# ==============================================================================
# SEZIONE 10 · VERIFICA E COMPATIBILITÀ SISTEMA
# Controlli pre-esecuzione: OS, aggiornamenti pendenti.
# ==============================================================================

function WinOSCheck {
    if ($Global:GuiSessionActive) { return }
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

function Test-WindowsUpdateStatus {
    <#
    .SYNOPSIS
        Controlla lo stato degli aggiornamenti Windows e avvisa in caso di operazioni pendenti.
    .DESCRIPTION
        Verifica riavvio pendente e stato servizio TrustedInstaller.
        Usa PSWindowsUpdate se disponibile, altrimenti fallback su registro e servizi nativi.
    #>
    try {
        if ($Global:GuiSessionActive) { return }
        Write-StyledMessage -Type 'Info' -Text "🔍 Controllo stato aggiornamenti Windows..."

        $pendingReboot = $false
        $installerRunning = $false

        if (Get-Module -ListAvailable -Name PSWindowsUpdate -ErrorAction SilentlyContinue) {
            Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
            try {
                $rebootStatus = Get-WURebootStatus -ErrorAction SilentlyContinue
                if ($rebootStatus -and $rebootStatus.RebootRequired) {
                    $pendingReboot = $true
                    Write-StyledMessage -Type 'Warning' -Text "⚠️ Rilevato riavvio pendente per aggiornamenti Windows"
                }
            }
            catch {}
            try {
                $installerStatus = Get-WUInstallerStatus -ErrorAction SilentlyContinue
                if ($installerStatus -and $installerStatus.IsBusy) {
                    $installerRunning = $true
                    Write-StyledMessage -Type 'Warning' -Text "⚠️ Servizio installazione aggiornamenti Windows attualmente in esecuzione"
                }
            }
            catch {}
        }
        else {
            $regPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootRequired",
                "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"
            )
            foreach ($path in $regPaths) {
                if (Test-Path $path -ErrorAction SilentlyContinue) { $pendingReboot = $true; break }
            }
            $trustedInstaller = Get-Service -Name TrustedInstaller -ErrorAction SilentlyContinue
            if ($trustedInstaller -and $trustedInstaller.Status -eq 'Running') { $installerRunning = $true }
        }

        if ($pendingReboot -or $installerRunning) {
            $width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 }
            Write-Host ""
            Write-Host ('═' * ($width - 1)) -ForegroundColor Yellow
            Write-Host ""
            Write-Host (Center-Text "⚠️  AVVISO IMPORTANTE ⚠️") -ForegroundColor Yellow
            Write-Host ""
            Write-Host " Sono stati rilevati aggiornamenti di sistema pendenti:" -ForegroundColor Yellow
            if ($pendingReboot) { Write-Host "  ✓ Riavvio del sistema richiesto per completare aggiornamenti" -ForegroundColor Yellow }
            if ($installerRunning) { Write-Host "  ✓ Servizio installazione aggiornamenti Windows in corso" -ForegroundColor Yellow }
            Write-Host ""
            Write-Host " Questo potrebbe causare malfunzionamenti, errori o comportamenti" -ForegroundColor Yellow
            Write-Host " imprevisti in alcune o tutte le funzionalità di WinToolkit." -ForegroundColor Yellow
            Write-Host ""
            Write-Host (Center-Text "⚠️  PROCEDERE CON CAUTELA ⚠️") -ForegroundColor Red
            Write-Host ""
            Write-Host " Si consiglia vivamente di completare tutti gli aggiornamenti in corso," -ForegroundColor Yellow
            Write-Host " riavviare il sistema e poi riavviare WinToolkit prima di proseguire." -ForegroundColor Yellow
            Write-Host ""
            Write-Host ('═' * ($width - 1)) -ForegroundColor Yellow
            Write-Host ""
            Start-Sleep -Seconds 5
        }
        else {
            Write-StyledMessage -Type 'Success' -Text "✅ Nessun aggiornamento pendente rilevato"
        }
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text "⚠️ Impossibile verificare stato aggiornamenti Windows: $($_.Exception.Message)"
    }
}


# ==============================================================================
# SEZIONE 11 · OFFICE — HELPER CONDIVISI
# Funzioni condivise da Install-Office, Repair-Office e Uninstall-Office.
# Definite a scope script per essere accessibili da tutti e tre i tool compilati.
# ==============================================================================

function Invoke-OfficeSilentRemoval {
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$Recurse)
    return Remove-ItemSafely -Path $Path -Recurse:$Recurse
}

function Stop-OfficeProcesses {
    $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
    $closed = 0
    Write-StyledMessage -Type 'Info' -Text "📋 Chiusura processi Office."
    foreach ($processName in $processes) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($running) {
            try { $running | Stop-Process -Force -ErrorAction Stop; $closed++ }
            catch { Write-StyledMessage -Type 'Warning' -Text "Impossibile chiudere: $processName." }
        }
    }
    if ($closed -gt 0) { Write-StyledMessage -Type 'Success' -Text "$closed processi Office chiusi." }
}

function Invoke-OfficeDownloadFile([string]$Url, [string]$OutputPath, [string]$Description) {
    return Invoke-ToolkitDownload -Uri $Url -OutputPath $OutputPath -Description $Description
}

function Set-OfficePostConfig {
    Write-StyledMessage -Type 'Info' -Text "⚙️ Ottimizzazione profonda di Microsoft Office."

    $registrySettings = @(
        # Privacy & Telemetria
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "disconnectedstate"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "usercontentdisabled"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "downloadcontentdisabled"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"; Name = "ShownOptIn"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback"; Name = "Enabled"; Value = 0 },
        # Performance & UI
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Graphics"; Name = "DisableAnimations"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Graphics"; Name = "DisableHardwareAcceleration"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"; Name = "DisableBootToStartScreen"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\LinkedIn"; Name = "ShowLinkedInIntegration"; Value = 0 }
    )

    foreach ($reg in $registrySettings) {
        if (-not (Test-Path $reg.Path)) { $null = New-Item -Path $reg.Path -Force }
        Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type 'DWord' -Force
    }

    $tasksToDisable = @(
        "OfficeTelemetryAgentLogon", "OfficeTelemetryAgentFallback",
        "OfficeBackgroundTaskHandlerRegistration", "OfficeBackgroundTaskHandlerLogon",
        "OfficeFeatureUpdates", "OfficeFeatureUpdatesLogon"
    )
    foreach ($tName in $tasksToDisable) {
        Get-ScheduledTask | Where-Object { $_.TaskName -eq $tName } | Disable-ScheduledTask -ErrorAction SilentlyContinue
    }

    Write-StyledMessage -Type 'Success' -Text "✅ Office ottimizzato: telemetria, privacy e task pianificati rimossi."
}


# ==============================================================================
# SEZIONE 12 · PLACEHOLDER COMPILATORE
# Stub vuoti sostituiti dal compiler.ps1 con i contenuti di /tool/*.ps1.
# Ordine: Windows → Office → Driver/Gaming → Supporto (segue $menuStructure).
# ==============================================================================

# Windows
function WinRepairToolkit {}
function WinUpdateReset {}
function WinReinstallStore {}
function WinBackupDriver {}
function WinDriverInstall {}
function WinDebloat {}
function WinCleaner {}
function DisableBitlocker {}

# Office
function Install-Office {}
function Repair-Office {}
function Uninstall-Office {}

# Driver & Gaming
function VideoDriverInstall {}
function GamingToolkit {}

# Supporto
function WinExportLog {}


# ==============================================================================
# SEZIONE 13 · STRUTTURA MENU
# Definizione categorie e voci del menu interattivo TUI.
# ==============================================================================

$menuStructure = @(
    @{ 'Name' = 'Windows'; 'Icon' = '🔧'; 'Scripts' = @(
            [pscustomobject]@{Name = 'WinRepairToolkit'; Description = 'Riparazione Windows'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinUpdateReset'; Description = 'Reset Windows Update'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinBackupDriver'; Description = 'Backup Driver PC'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinCleaner'; Description = 'Pulizia File Temporanei'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'DisableBitlocker'; Description = 'Disabilita Bitlocker'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Office'; 'Icon' = '🏢'; 'Scripts' = @(
            [pscustomobject]@{Name = 'Install-Office'; Description = 'Installa Office Basic'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'Repair-Office'; Description = 'Ripara Office'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'Uninstall-Office'; Description = 'Rimuovi Office'; Action = 'RunFunction' }
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


# ==============================================================================
# SEZIONE 14 · INIZIALIZZAZIONE
# Blocco unico di avvio: percorsi, controllo OS, aggiornamenti.
# Eseguito solo in modalità interattiva (non -ImportOnly, non GUI).
# ==============================================================================

if (-not $ImportOnly) {
    Initialize-ToolkitPaths
    WinOSCheck
    Test-WindowsUpdateStatus
}


# ==============================================================================
# SEZIONE 15 · MENU PRINCIPALE
# Loop interattivo TUI. Soppresso in modalità libreria (-ImportOnly) e GUI.
# ==============================================================================

if (-not $ImportOnly -and -not $Global:GuiSessionActive) {

    Write-Host ""
    Write-StyledMessage -Type 'Info' -Text '💎 WinToolkit avviato in modalità interattiva'
    Write-Host ""

    while ($true) {
        Show-Header -SubTitle "Menu Principale"

        # ── Informazioni di sistema ───────────────────────────────────────────
        $width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 }
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
            Write-Host "🔑 Architettura: $($si.Architecture)"  -ForegroundColor White
            Write-Host "🔧 Nome PC: $($si.ComputerName)"       -ForegroundColor White
            Write-Host "🧠 RAM: $($si.TotalRAM) GB"            -ForegroundColor White
            Write-Host "💾 Disco: " -NoNewline -ForegroundColor White

            $diskFreeGB = $si.FreeDisk
            $displayString = "$($si.FreePercentage)% Libero ($($diskFreeGB) GB)"
            $diskColor = if ($diskFreeGB -lt 50) { "Red" } elseif ($diskFreeGB -le 80) { "Yellow" } else { "Green" }
            Write-Host $displayString -ForegroundColor $diskColor -NoNewline
            Write-Host ""

            $blStatus = Get-BitlockerStatus
            $blColor = if ($blStatus -match 'Disattivato|Non configurato|Off') { 'Green' } else { 'Red' }
            Write-Host "🔒 Stato Bitlocker: " -NoNewline -ForegroundColor White
            Write-Host "$blStatus" -ForegroundColor $blColor
        }
        Write-Host ('*' * 50) -ForegroundColor Red
        Write-Host ""

        # ── Voci di menu ─────────────────────────────────────────────────────
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

        # ── Input utente ──────────────────────────────────────────────────────
        $rawInput = Microsoft.PowerShell.Utility\Read-Host 'Inserisci uno o più numeri (es: 1 2 3 oppure 1,2,3) per eseguire le operazioni in sequenza'

        # Secret check
        if ($rawInput -eq [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('V2luZG93cyDDqCB1bmEgbWVyZGE='))) {
            Start-Process ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly93d3cueW91dHViZS5jb20vd2F0Y2g/dj15QVZVT2tlNGtvYw==')))
            continue
        }

        $rawSelections = Read-ValidatedChoice -Prompt 'Inserisci uno o più numeri' -Min 0 -Max $allScripts.Count -AllowZero -RawInput $rawInput
        $c = if ($rawSelections.Count -gt 0) { $rawSelections[0] } else { '' }

        if ($c -eq 0 -or $c -eq '0') {
            Write-StyledMessage -type 'Warning' -text 'Per supporto: Github.com/Magnetarman'
            Write-StyledMessage -type 'Success' -text 'Chiusura in corso...'
            Write-ToolkitLog -Level INFO -Message "Sessione WinToolkit terminata dall'utente."
            Start-Sleep -Seconds 3
            break
        }

        $selections = @($rawSelections | Where-Object { $_ -ge 1 -and $_ -le $allScripts.Count })
        if ($selections.Count -eq 0) {
            Write-StyledMessage -Type 'Warning' -Text '⚠️ Nessuna selezione valida. Riprova.'
            Start-Sleep -Seconds 2
            continue
        }

        # ── Esecuzione ────────────────────────────────────────────────────────
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
                if ($isMultiScript) { & ([scriptblock]::Create("$($scriptToRun.Name) -SuppressIndividualReboot")) }
                else { & $ExecutionContext.InvokeCommand.GetCommand($scriptToRun.Name, 'Function') }
                $Global:ExecutionLog += @{ Name = $scriptToRun.Description; Success = $true }
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "❌ Errore durante $($scriptToRun.Description): $($_.Exception.Message)"
                $Global:ExecutionLog += @{ Name = $scriptToRun.Description; Success = $false; Error = $_.Exception.Message }
            }
            Write-Host ''
        }

        # ── Riepilogo multi-script ────────────────────────────────────────────
        if ($isMultiScript) {
            Write-Host ''
            $tableRows = $Global:ExecutionLog | ForEach-Object {
                @{ Operazione = $_.Name; Stato = if ($_.Success) { '✅ Completato' } else { '❌ Errore' }; Dettaglio = if ($_.Error) { $_.Error } else { '' } }
            }
            Show-ConsoleTable -Rows $tableRows -Columns @(
                @{ Header = 'Operazione'; Key = 'Operazione' },
                @{ Header = 'Stato'; Key = 'Stato' },
                @{ Header = 'Dettaglio'; Key = 'Dettaglio' }
            ) -Title '📊 Riepilogo Esecuzione'
            Write-Host ''
        }

        # ── Riavvio finale ────────────────────────────────────────────────────
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
    # Modalità libreria/import — funzioni caricate, menu TUI soppresso
    Write-Verbose "═══════════════════════════════════════════════════════════"
    Write-Verbose "  📚 WinToolkit caricato in modalità LIBRERIA"
    Write-Verbose "  ✅ Funzioni disponibili, menu TUI soppresso"
    Write-Verbose "  💎 Versione: $ToolkitVersion"
    Write-Verbose "═══════════════════════════════════════════════════════════"
    $Global:menuStructure = $menuStructure
}


