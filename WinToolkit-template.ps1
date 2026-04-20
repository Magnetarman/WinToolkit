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

# --- GESTIONE INTERRUZIONI (CTRL+C) ---
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

    # Verifica se siamo in una sessione interattiva con console reale
    if ($Host.Name -ne 'ConsoleHost' -or $Global:GuiSessionActive) {
        if ($Prompt) { return Microsoft.PowerShell.Utility\Read-Host -Prompt $Prompt }
        return Microsoft.PowerShell.Utility\Read-Host
    }

    $oldTreatControlC = [console]::TreatControlCAsInput
    try { [console]::TreatControlCAsInput = $true } catch {}

    try {
        if ($Prompt) {
            Write-Host "${Prompt}: " -NoNewline -ForegroundColor Cyan
        }

        $inputString = ""
        while ($true) {
            $keyInfo = [console]::ReadKey($true)

            # Gestione CTRL+C
            if ($keyInfo.Modifiers -match "Control" -and $keyInfo.Key -eq "C") {
                Write-Host ""
                return $null
            }
            # Invio / Enter
            if ($keyInfo.Key -eq "Enter") {
                Write-Host ""
                if ($AsSecureString) {
                    $secure = New-Object System.Security.SecureString
                    foreach ($char in $inputString.ToCharArray()) { $secure.AppendChar($char) }
                    return $secure
                }
                return $inputString ?? ""
            }
            # Backspace
            if ($keyInfo.Key -eq "Backspace") {
                if ($inputString.Length -gt 0) {
                    $inputString = $inputString.Substring(0, $inputString.Length - 1)
                    # Muove il cursore indietro, scrive uno spazio per cancellare, e torna indietro
                    Write-Host "`b `b" -NoNewline
                }
            }
            else {
                # Ignora tasti di controllo non testuali (eccetto i necessari)
                if (-not [char]::IsControl($keyInfo.KeyChar)) {
                    $inputString += $keyInfo.KeyChar
                    if ($AsSecureString -or $MaskInput) {
                        Write-Host "*" -NoNewline -ForegroundColor Yellow
                    }
                    else {
                        Write-Host $keyInfo.KeyChar -NoNewline
                    }
                }
            }
        }
    }
    catch {
        # Fallback in caso di errori imprevisti nel loop
        if ($Prompt) {
            return Microsoft.PowerShell.Utility\Read-Host -Prompt $Prompt
        }
        return Microsoft.PowerShell.Utility\Read-Host
    }
    finally {
        try {
            [console]::TreatControlCAsInput = $oldTreatControlC
        }
        catch {}
    }
}

# --- CONFIGURAZIONE GLOBALE ---
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan"
$ToolkitVersion = "2.5.4 (Build 32)"

# --- CONFIGURAZIONE CENTRALIZZATA ---
$AppConfig = @{
    URLs     = @{
        # GitHub Asset URLs
        GitHubAssetBaseUrl    = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/"
        GitHubAssetDevBaseUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/"

        # Office
        OfficeSetup           = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Setup.exe"
        OfficeBasicConfig     = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Basic.xml"
        SaRAInstaller         = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/SaRACmd_17_01_2877_000.zip"

        # Video Driver
        AMDInstaller          = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/AMD-Autodetect.exe"
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
    WindowsTerminal = @{
        DelegationTerminalClsid = "{E12F0936-0E6F-548E-A9F6-B20C69A27D17}"
        DelegationConsoleClsid  = "{B23D10C0-31E3-401A-97EF-4BB30B62E10B}"
    }
    WingetProcesses = @(
        'WinStore.App',
        'wsappx',
        'AppInstaller',
        'Microsoft.WindowsStore',
        'Microsoft.DesktopAppInstaller',
        'winget',
        'WindowsPackageManagerServer'
    )
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

function Stop-ToolkitProcesses {
    <#
    .SYNOPSIS
        Chiude in modo forzato e silenzioso i processi specificati.
    #>
    param(
        [string[]]$ProcessNames
    )
    Write-StyledMessage -Type Info -Text "Chiusura processi interferenti..."
    
    foreach ($procName in $ProcessNames) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue |
            Where-Object { $_.Id -ne $PID } |
            Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
}


function Get-WingetExecutable {
    <#
    .SYNOPSIS
        Risolve il percorso di winget.exe privilegiando l'App Execution Alias.
    #>
    # Priorità: Alias di esecuzione (localappdata) -> Evita "Accesso Negato" di WindowsApps
    $aliasPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path $aliasPath) { return $aliasPath }

    # Fallback: Ricerca in WindowsApps
    $arch = [Environment]::Is64BitOperatingSystem ? "x64" : "x86"
    $wingetDir = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1

    if ($wingetDir) {
        $exe = Join-Path $wingetDir.FullName "winget.exe"
        if (Test-Path $exe) { return $exe }
    }
    return "winget"
}

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
    Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color

    # Bridge: mirror to log file (silently, no UI side-effects)
    $logLevel = switch ($Type) {
        'Success' { 'SUCCESS' }
        'Warning' { 'WARNING' }
        'Error' { 'ERROR' }
        'Progress' { 'INFO' }
        default { 'INFO' }
    }
    Write-ToolkitLog -Level $logLevel -Message $Text
}

function Center-Text {
    param(
        [string]$Text,
        [int]$Width = $Host.UI.RawUI.BufferSize.Width
    )
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

function Start-ToolkitLog {
    <#
    .SYNOPSIS
        Inizializza il file di log strutturato per un tool specifico.
        Sostituisce Initialize-ToolLogging con il nuovo
        motore di logging dual-stream.
    #>
    param([string]$ToolName)

    # Pulizia residui transcript (backward compat)
    try {
        Stop-Transcript -ErrorAction SilentlyContinue
    }
    catch {}

    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = $AppConfig.Paths.Logs
    if (-not (Test-Path $logdir)) {
        New-Item -Path $logdir -ItemType Directory -Force | Out-Null
    }
    $Global:CurrentLogFile = "$logdir\${ToolName}_$dateTime.log"

    # CorrelationId: GUID univoco per questa esecuzione, utile per correlare log tool + transcript GUI + zip supporto
    $Global:CurrentCorrelationId = [guid]::NewGuid().ToString()

    # Raccolta metadati di sistema per l'header
    $os = Get-CimInstance Win32_OperatingSystem  -ErrorAction SilentlyContinue
    $sys = Get-CimInstance Win32_ComputerSystem   -ErrorAction SilentlyContinue
    $psVer = $PSVersionTable.PSVersion.ToString()
    $psEd = $PSVersionTable.PSEdition
    $psCompat = ($PSVersionTable.PSCompatibleVersions | ForEach-Object { $_.ToString() }) -join ', '
    $gitId = if ($PSVersionTable.GitCommitId) { $PSVersionTable.GitCommitId } else { 'N/A' }
    $wsManVer = if ($PSVersionTable.WSManStackVersion) { $PSVersionTable.WSManStackVersion.ToString() } else { 'N/A' }
    $remoteVer = if ($PSVersionTable.PSRemotingProtocolVersion) { $PSVersionTable.PSRemotingProtocolVersion.ToString() } else { 'N/A' }
    $serVer = if ($PSVersionTable.SerializationVersion) { $PSVersionTable.SerializationVersion.ToString() } else { 'N/A' }

    # Mappa build -> versione display
    $build = [int]$os.BuildNumber
    $verMap = @{26100 = '24H2'; 22631 = '23H2'; 22621 = '22H2'; 22000 = '21H2'; 19045 = '22H2'; 19044 = '21H2' }
    $dispVer = 'N/A'
    foreach ($k in ($verMap.Keys | Sort-Object -Descending)) {
        if ($build -ge $k) {
            $dispVer = $verMap[$k]
            break
        }
    }

    $header = @"
[START LOG HEADER]
Start time              : $dateTime
CorrelationId           : $($Global:CurrentCorrelationId)
ToolName                : $ToolName
Username                : $([Environment]::UserDomainName + '\' + [Environment]::UserName)
RunAs User              : $([Security.Principal.WindowsIdentity]::GetCurrent().Name)
Machine                 : $($sys.Name) ($($os.Caption) $($os.Version))
Host Application        : $([Environment]::CommandLine)
Process ID              : $PID
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
    try {
        Add-Content -Path $Global:CurrentLogFile -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {}
}

function Write-ToolkitLog {
    <#
    .SYNOPSIS
        Scrive una riga di log strutturata SOLO su file. Mai su console.
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
    # Rimuovi tutti i caratteri ANSI/colori prima di salvare su file
    $clean = $clean -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
    $line = "[$ts] [$Level] $clean"
    if ($Context.Count -gt 0) {
        try {
            $line += " | Context: " + ($Context | ConvertTo-Json -Compress -Depth 3)
        }
        catch {}
    }
    try {
        Add-Content -Path $Global:CurrentLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {}
}

function Invoke-ExternalCommandWithLog {
    <#
    .SYNOPSIS
        Esegue un comando esterno con logging strutturato e cattura completa di STDOUT/STDERR.
    .DESCRIPTION
        Wrapper standardizzato per processi esterni.
        - Logga comando, argomenti, exit code, durata ed eventuali errori.
        - Restituisce un oggetto con Success, ExitCode, StdOut, StdErr, Elapsed.
        - Non scrive mai direttamente su console (la responsabilità è del chiamante tramite Write-StyledMessage).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @(),

        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 0,

        [Parameter(Mandatory = $false)]
        [string]$LogContextKey = ''
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $argString = $Arguments -join ' '

    Write-ToolkitLog -Level 'INFO' -Message "Esecuzione comando esterno: $Command $argString" -Context @{
        Command    = $Command
        Arguments  = $Arguments
        WorkingDir = $WorkingDirectory
        TimeoutSec = $TimeoutSeconds
        ContextKey = $LogContextKey
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Command
    $psi.Arguments = $argString
    if ($WorkingDirectory) {
        $psi.WorkingDirectory = $WorkingDirectory
    }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi

    $outText = ""
    $errText = ""
    $success = $false
    $exitCode = $null

    try {
        if (-not $proc.Start()) {
            throw "Impossibile avviare il processo esterno."
        }

        # Lettura asincrona tramite Task (evita crash del runspace causato dai gestori degli eventi non vincolati)
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()

        if ($TimeoutSeconds -gt 0) {
            if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
                try { $proc.Kill() } catch {}
                throw "Timeout dopo $TimeoutSeconds secondi."
            }
        }
        else {
            $proc.WaitForExit()
        }

        # Attendi completamento lettura flussi standard
        try { [System.Threading.Tasks.Task]::WaitAll($outTask, $errTask) } catch {}
        
        if ($outTask.Status -eq 'RanToCompletion') { $outText = $outTask.Result }
        if ($errTask.Status -eq 'RanToCompletion') { $errText = $errTask.Result }

        $exitCode = $proc.ExitCode
        $success = ($exitCode -eq 0)
    }
    catch {
        $exitCode = if ($exitCode -ne $null) { $exitCode } else { -1 }
        Write-ToolkitLog -Level 'ERROR' -Message "Eccezione durante esecuzione comando esterno" -Context @{
            Command    = $Command
            Arguments  = $Arguments
            WorkingDir = $WorkingDirectory
            TimeoutSec = $TimeoutSeconds
            ContextKey = $LogContextKey
            Exception  = $_.Exception.Message
            Stack      = $_.ScriptStackTrace
        }
    }
    finally {
        $stopwatch.Stop()
        $elapsed = $stopwatch.Elapsed

        if ($null -eq $outText) { $outText = "" }
        if ($null -eq $errText) { $errText = "" }

        # Evita file log enormi: tronca output molto lunghi ma preserva informazione di taglio
        $maxLen = 8000
        $outLogged = $outText
        $errLogged = $errText
        if ($outLogged.Length -gt $maxLen) {
            $outLogged = $outLogged.Substring(0, $maxLen) + "`n[...output troncato...]"
        }
        if ($errLogged.Length -gt $maxLen) {
            $errLogged = $errLogged.Substring(0, $maxLen) + "`n[...stderr troncato...]"
        }

        Write-ToolkitLog -Level 'INFO' -Message "Risultato comando esterno" -Context @{
            Command       = $Command
            Arguments     = $Arguments
            WorkingDir    = $WorkingDirectory
            TimeoutSec    = $TimeoutSeconds
            ContextKey    = $LogContextKey
            ExitCode      = $exitCode
            Success       = $success
            Elapsed       = $elapsed.ToString()
            StdOutSnippet = $outLogged
            StdErrSnippet = $errLogged
        }

        if ($proc) {
            # Handler rimossi per risolvere Issue #12 (Runspace crash)
            $proc.Dispose()
        }
    }

    [pscustomobject]@{
        Success  = $success
        ExitCode = $exitCode
        StdOut   = $outText
        StdErr   = $errText
        Elapsed  = $stopwatch.Elapsed
    }
}

# Helper: installa AppX tramite System.Diagnostics.Process (CreateNoWindow=true).
# Blocca in modo assoluto le write Win32 native del deployment engine e gestisce l'errore di downgrade.
function Start-AppxSilentProcess {
    param(
        [string]$AppxPath, 
        [string]$Flags = '-ForceApplicationShutdown',
        [string[]]$DependencyPaths = @()
    )

    # Costruzione sicura del comando interno
    # Usiamo -Register se presente nei flags, altrimenti -Path
    $pathParam = ($Flags -match '-Register') ? "" : "-Path '$($AppxPath -replace "'", "''")'"
    
    $depString = ""
    if ($DependencyPaths.Count -gt 0) {
        $depString = "-DependencyPackagePath " + (($DependencyPaths | ForEach-Object { "'$($_ -replace "'", "''")'" }) -join ", ")
    }

    # Script interno: sopprime TUTTO l'output nativo e gestisce il downgrade (0x80073D06) e bypass SYSTEM
    $cmd = @"
`$ProgressPreference = 'SilentlyContinue';
`$ErrorActionPreference = 'SilentlyContinue';
try {
    Add-AppxPackage $pathParam $depString $Flags -ErrorAction Stop | Out-Null
}
catch {
    if (`$_.Exception.Message -match '0x80073D06' -or `$_.Exception.Message -match 'versione successiva') {
        exit 0
    }
    if (`$_.Exception.Message -match '0x80073CF9' -or ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)) {
        try {
            if ('$pathParam' -eq '') {
                exit 1 # Register for manifest not supported via Provisioned
            }
            Add-AppxProvisionedPackage -Online -PackagePath '$($AppxPath -replace "'", "''")' $depString -SkipLicense -ErrorAction Stop | Out-Null
            exit 0
        }
        catch {
            exit 1
        }
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
    .DESCRIPTION
        Verifica sia la risposta dell'eseguibile (--version) che l'accessibilità del database (list).
        Ritorna $true appena Winget risponde correttamente, $false allo scadere del timeout.
    #>
    param(
        [int]$MaxWaitSeconds = 300,
        [int]$PollIntervalSeconds = 5
    )

    Write-StyledMessage -Type Info -Text "🔍 Validazione integrità Winget in corso (timeout: $MaxWaitSeconds s)..."

    $wingetExe = Get-WingetExecutable
    $maxRetries = [Math]::Floor($MaxWaitSeconds / $PollIntervalSeconds)

    for ($i = 1; $i -le $maxRetries; $i++) {
        try {
            # Verifica 1: l'eseguibile risponde?
            $versionProc = Start-Process -FilePath $wingetExe -ArgumentList '--version' `
                -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue

            # Verifica 2: il database è accessibile? (list su app non esistente, ExitCode 0 = DB ok)
            $dbProc = Start-Process -FilePath $wingetExe `
                -ArgumentList 'list', 'NonExistentApp_WinToolkitCheck', '--accept-source-agreements' `
                -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue

            if ($versionProc.ExitCode -eq 0 -and $dbProc.ExitCode -eq 0) {
                Write-StyledMessage -Type Success -Text "✅ Winget pronto e database sbloccato (tentativo $i/$maxRetries)."
                return $true
            }
        }
        catch { }

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
        Procedura integrata e robusta a due fasi per la riparazione completa di Winget.

        Fase 1 - Ripristino Core (veloce):
          Reinstalla Visual C++ Redistributable, dipendenze AppX dal repository ufficiale
          e il bundle MSIX principale.

        Fase 2 - Ripristino Avanzato (se la Fase 1 non basta):
          Installa il modulo Microsoft.WinGet.Client, esegue Repair-WinGetPackageManager,
          ripara il database (cache, file JSON di stato, Reset-AppxPackage) e corregge
          permessi e voci PATH di sistema e utente.

        Include validazione profonda post-installazione con rilevamento di crash
        ACCESS_VIOLATION (codice 0xC0000005 / -1073741819).
    #>
    param([switch]$Force)

    $ProgressPreference = 'SilentlyContinue'
    $OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

    # ─────────────────────────────────────────────────────────────────────────
    # HELPER PRIVATI
    # ─────────────────────────────────────────────────────────────────────────

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
        } catch { }
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
        if ($Scope -in 'User', 'Both') {
            if (($env:PATH -split ';').Contains($PathToCheck)) { $found = $true }
        }
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
        catch {
            Write-StyledMessage -Type Warning -Text "Impossibile impostare permessi su '$FolderPath': $($_.Exception.Message)."
        }
    }

    function _Set-WingetPathPermissions {
        $wingetFolderPath = $null
        try {
            $arch = [Environment]::Is64BitOperatingSystem ? 'x64' : 'x86'
            $wingetDir = Get-ChildItem "$env:ProgramFiles\WindowsApps" `
                -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" `
                -ErrorAction SilentlyContinue |
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

            # Pulizia cache locale (escludi lock e tmp)
            $cachePath = "$env:LOCALAPPDATA\WinGet"
            if (Test-Path $cachePath) {
                Write-StyledMessage -Type Info -Text "Pulizia cache Winget."
                Get-ChildItem -Path $cachePath -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '\\lock\\|\\tmp\\' } |
                    ForEach-Object { try { Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue } catch {} }
            }

            # Rimuovi file di stato JSON corrotti
            @("$env:LOCALAPPDATA\WinGet\Data\USERTEMPLATE.json",
              "$env:LOCALAPPDATA\WinGet\Data\DEFAULTUSER.json") | ForEach-Object {
                if (Test-Path $_ -PathType Leaf) {
                    Write-StyledMessage -Type Info -Text "Reset file stato: $_."
                    Remove-Item $_ -Force -ErrorAction SilentlyContinue
                }
            }

            # Reset sorgenti Winget
            try { $null = & (Get-WingetExecutable) source reset --force 2>&1 } catch {}

            # Reset pacchetto AppInstaller (corregge ACCESS_VIOLATION)
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
            } catch { }

            # Repair via modulo WinGet se disponibile
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
                else {
                    Write-StyledMessage -Type Warning -Text "Repair-WinGetPackageManager fallito: $($_.Exception.Message)."
                }
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
            # NuGet provider (necessario per PS 5.1)
            if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
                if ($PSVersionTable.PSVersion.Major -lt 7) {
                    try {
                        Install-PackageProvider -Name 'NuGet' -Force -ForceBootstrap -ErrorAction SilentlyContinue *>$null
                    }
                    catch { Write-StyledMessage -Type Warning -Text "NuGet provider non installabile." }
                }
            }

            # Modulo Microsoft.WinGet.Client
            Write-StyledMessage -Type Info -Text "Installazione modulo Microsoft.WinGet.Client."
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
                Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
                Write-StyledMessage -Type Success -Text "Modulo WinGet Client installato."
            }
            catch {
                Write-StyledMessage -Type Warning -Text "Impossibile installare modulo WinGet Client: $($_.Exception.Message)."
            }

            # Repair-WinGetPackageManager
            if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Info -Text "Tentativo Repair-WinGetPackageManager."
                try {
                    Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                    Write-StyledMessage -Type Success -Text "Repair-WinGetPackageManager completato."
                }
                catch {
                    if ($_.Exception.Message -match '0x80073D06' -or $_.Exception.Message -match 'versione successiva') {
                        Write-StyledMessage -Type Success -Text "Repair-WinGetPackageManager ignorato (versione superiore già presente)."
                    } else {
                        Write-StyledMessage -Type Warning -Text "Repair-WinGetPackageManager fallito: $($_.Exception.Message)."
                    }
                }
                Start-Sleep 3
            }

            # Fallback: MSIXBundle diretto MS se winget ancora assente
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

            # Reset finale AppInstaller
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

            # Rilevamento crash ACCESS_VIOLATION (0xC0000005 = -1073741819)
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

    # ─────────────────────────────────────────────────────────────────────────
    # LOGICA PRINCIPALE — Orchestrazione a Due Fasi
    # ─────────────────────────────────────────────────────────────────────────
    Write-StyledMessage -Type Info -Text "🚀 Avvio riparazione avanzata Winget..."

    # 0. Verifica compatibilità OS
    if (-not (_Test-WingetCompatibility)) { return $false }

    # 1. Se Winget funziona già e non è forzata la riparazione, esci subito
    if (-not $Force -and (_Test-WingetFunctionality)) {
        Write-StyledMessage -Type Success -Text "✅ Winget già operativo. Nessuna riparazione necessaria."
        return $true
    }

    Stop-ToolkitProcesses -ProcessNames $AppConfig.WingetProcesses

    try {
        # ── FASE 1: RIPRISTINO CORE (VELOCE) ─────────────────────────────────
        Write-StyledMessage -Type Info -Text "⚡ Fase 1: Ripristino Core (VC++, dipendenze AppX, MSIXBundle)."

        # 1a. VC++ Redistributable
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

        # 1b. Dipendenze AppX dal repository ufficiale
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
                ForEach-Object {
                    Write-StyledMessage -Type Info -Text "Trovata dipendenza: $($_.Name)."
                    $script:WingetDependencies += $_.FullName
                }
            Write-StyledMessage -Type Success -Text "Dipendenze caricate."
        }

        # 1c. MSIXBundle principale
        Write-StyledMessage -Type Info -Text "Installazione Winget MSIXBundle (con dipendenze)..."
        $bundleUrl = _Get-LatestAssetUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        if ($bundleUrl) {
            $bundleFile = Join-Path $AppConfig.Paths.Temp "winget.msixbundle"
            Invoke-WebRequest -Uri $bundleUrl -OutFile $bundleFile -UseBasicParsing
            $deps = if ($script:WingetDependencies) { $script:WingetDependencies } else { @() }
            Start-AppxSilentProcess -AppxPath $bundleFile -DependencyPaths $deps -Flags '-ForceApplicationShutdown'
            Write-StyledMessage -Type Success -Text "Winget Core installato."
        }

        # 1d. Re-registrazione manifest (previene leak barra avanzamento deployment engine)
        _Register-AppxManifest

        Update-EnvironmentPath

        # Risultato Fase 1
        if (_Test-WingetFunctionality) {
            Write-StyledMessage -Type Success -Text "✅ Fase 1 completata. Winget operativo."
        }
        else {
            # ── FASE 2: RIPRISTINO AVANZATO ──────────────────────────────────
            Write-StyledMessage -Type Warning -Text "⚠️ Fase 1 insufficiente. Avvio Fase 2: Ripristino Avanzato."
            $null = _Install-WingetAdvanced
            $null = _Repair-WingetDatabase
            Update-EnvironmentPath
        }

        # Pausa breve di stabilizzazione post-installazione (senza polling bloccante)
        Start-Sleep -Seconds 3

        # Reset immediato delle sorgenti Winget
        try {
            $wingetExeForReset = Get-WingetExecutable
            Start-Process -FilePath $wingetExeForReset -ArgumentList 'source', 'reset', '--force' `
                -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        }
        catch { }

        # Validazione profonda finale (connettività + rilevamento ACCESS_VIOLATION)
        $deepOk = _Test-WingetDeepValidation

        if ($deepOk) {
            Write-StyledMessage -Type Success -Text "✅ Winget ripristinato e testato con successo."
            return $true
        }
        else {
            Write-StyledMessage -Type Warning -Text "⚠️ Winget installato. La validazione profonda ha rilevato anomalie (possibili problemi di rete o DB)."
            return $true  # L'installazione è avvenuta; i problemi di rete/DB sono esterni
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
    if ($Global:SystemInfoCache) { return $Global:SystemInfoCache }
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

        $Global:SystemInfoCache = @{
            ProductName = $osInfo.Caption -replace 'Microsoft ', ''; BuildNumber = $build; DisplayVersion = $ver
            Architecture = $osInfo.OSArchitecture; ComputerName = $computerInfo.Name
            TotalRAM = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
            TotalDisk = [Math]::Round($diskInfo.Size / 1GB, 0)
            FreeDisk = [Math]::Round($diskInfo.FreeSpace / 1GB, 0)
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

function Initialize-ToolkitPaths {
    <#
    .SYNOPSIS
        Assicura la creazione di tutte le directory necessarie al primo avvio.
    #>
    foreach ($path in $AppConfig.Paths.Values) {
        if (-not (Test-Path $path -PathType Leaf) -and $path -notmatch "\.exe$|\.zip$|\.msixbundle$") {
            try {
                if (-not (Test-Path $path)) {
                    $null = New-Item -Path $path -ItemType Directory -Force -ErrorAction SilentlyContinue
                }
            }
            catch {}
        }
    }
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

# --- HELPER INPUT E UX AVANZATA ---

function Read-ValidatedChoice {
    <#
    .SYNOPSIS
        Legge e valida una selezione numerica multipla dall'utente.
    .DESCRIPTION
        Accetta input del tipo "1 2 3", "1,2,3", "1, 2 3" o varianti miste.
        Filtra valori non numerici, valori fuori range e duplicati.
        Registra la scelta nel log file con contesto strutturato.
        Supporta easter egg: "Windows è una merda" attiva un easter egg.
    .PARAMETER Prompt
        Testo da mostrare come prompt.
    .PARAMETER Min
        Valore minimo accettabile (incluso).
    .PARAMETER Max
        Valore massimo accettabile (incluso).
    .PARAMETER AllowZero
        Se specificato, il valore 0 è accettato come uscita/annulla.
    .PARAMETER RawInput
        Input pre-letto (opzionale). Se fornito, salta Read-Host.
    .OUTPUTS
        Array [int[]] di valori selezionati. Array vuoto se nessuna selezione valida.
    #>
    [CmdletBinding()]
    param(
        [string]$Prompt = 'Selezione',
        [int]$Min = 1,
        [int]$Max = 99,
        [switch]$AllowZero,
        [string]$RawInput
    )

    if ([string]::IsNullOrEmpty($RawInput)) {
        $rawInput = Read-Host $Prompt
    }
    else {
        $rawInput = $RawInput
    }
    if ($null -eq $rawInput) { return @() }

    if ($AllowZero -and $rawInput.Trim() -eq '0') {
        Write-ToolkitLog -Level 'INFO' -Message 'Utente ha selezionato: 0 (uscita/annulla)' -Context @{ Input = '0' }
        return @(0)
    }

    $tokens = $rawInput -split '[\s,]+' | Where-Object { $_ -match '^\d+$' }
    $valid = @()
    $invalid = @()

    foreach ($token in $tokens) {
        $num = [int]$token
        if ($num -ge $Min -and $num -le $Max) {
            if ($valid -notcontains $num) { $valid += $num }
        }
        else {
            $invalid += $num
        }
    }

    if ($invalid.Count -gt 0) {
        Write-StyledMessage -Type Warning -Text "⚠️ Valori fuori range ignorati: $($invalid -join ', ') (range valido: $Min–$Max)"
    }

    Write-ToolkitLog -Level 'INFO' -Message 'Input utente validato' -Context @{
        RawInput = $rawInput
        Valid    = ($valid -join ',')
        Invalid  = ($invalid -join ',')
    }

    return $valid
}

function Get-UserConfirmation {
    <#
    .SYNOPSIS
        ⚠️ DEPRECATA: Questa funzione è in fase di eliminazione.
        Il toolkit sta acquisendo autonomia totale e non richiederà conferme utente.
        Usa invece Read-Host diretto o Read-ValidatedChoice per le selezioni.
    .DESCRIPTION
        Chiede conferma sì/no all'utente in modo uniforme.
        Mostra un prompt coerente con lo schema di messaggistica del toolkit.
        Registra la scelta nel log con contesto strutturato.
    .PARAMETER Prompt
        Testo della domanda da porre.
    .PARAMETER Default
        Valore predefinito: 'Y' oppure 'N'. Default = 'N'.
    .PARAMETER Severity
        Livello di enfasi visiva: 'Info' (Cyan) oppure 'Warning' (Yellow).
    .OUTPUTS
        [bool] $true se l'utente ha confermato, $false altrimenti.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [ValidateSet('Y', 'N')]
        [string]$Default = 'N',

        [ValidateSet('Info', 'Warning')]
        [string]$Severity = 'Info'
    )

    Write-StyledMessage -Type Warning -Text "⚠️ [DEPRECATED] Get-UserConfirmation sarà rimossa. Non richiederà più conferme."

    $yesLabel = if ($Default -eq 'Y') { '[Y]' } else { 'y' }
    $noLabel = if ($Default -eq 'N') { '[N]' } else { 'n' }
    $fullPrompt = "$Prompt ($yesLabel/$noLabel)"

    Write-StyledMessage -Type $Severity -Text $fullPrompt
    $answer = Read-Host ''

    if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $Default }
    $confirmed = $answer -match '^[Yy]'

    Write-ToolkitLog -Level 'INFO' -Message 'Conferma utente' -Context @{
        Prompt    = $Prompt
        Default   = $Default
        Answer    = $answer
        Confirmed = $confirmed
    }

    return $confirmed
}

function Show-ConsoleTable {
    <#
    .SYNOPSIS
        Visualizza dati in formato tabellare ASCII nella console.
    .DESCRIPTION
        Accetta una lista di hashtable/oggetti e una lista di colonne.
        Calcola automaticamente la larghezza delle colonne in base al contenuto.
        Stampa intestazioni, separatori e righe dati con bordi ASCII puliti.
    .PARAMETER Rows
        Array di hashtable o pscustomobject da visualizzare.
    .PARAMETER Columns
        Array di hashtable con chiavi 'Header' (string) e 'Key' (string) che
        corrispondono alle proprietà in Rows. Opzionale: 'Color' (string).
    .PARAMETER Title
        Titolo opzionale da mostrare sopra la tabella.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Rows,

        [Parameter(Mandatory = $true)]
        [hashtable[]]$Columns,

        [string]$Title = ''
    )

    # Calcola larghezze colonne (max tra header e contenuto di ogni riga)
    $widths = @{}
    foreach ($col in $Columns) {
        $widths[$col.Key] = $col.Header.Length
    }
    foreach ($row in $Rows) {
        foreach ($col in $Columns) {
            $val = if ($row -is [hashtable]) { "$($row[$col.Key])" } else { "$($row.$($col.Key))" }
            if ($val.Length -gt $widths[$col.Key]) { $widths[$col.Key] = $val.Length }
        }
    }

    # Costruisce separatore orizzontale
    $sep = '+' + (($Columns | ForEach-Object { '-' * ($widths[$_.Key] + 2) }) -join '+') + '+'

    if ($Title) {
        $totalWidth = $sep.Length
        $paddedTitle = " $Title "
        $pad = [Math]::Max(0, [Math]::Floor(($totalWidth - $paddedTitle.Length) / 2))
        Write-Host ('=' * $totalWidth) -ForegroundColor Cyan
        Write-Host ((' ' * $pad) + $paddedTitle) -ForegroundColor Cyan
        Write-Host ('=' * $totalWidth) -ForegroundColor Cyan
    }

    # Intestazione
    Write-Host $sep -ForegroundColor DarkGray
    $headerLine = '|'
    foreach ($col in $Columns) {
        $headerLine += ' ' + $col.Header.PadRight($widths[$col.Key]) + ' |'
    }
    Write-Host $headerLine -ForegroundColor Cyan
    Write-Host $sep -ForegroundColor DarkGray

    # Righe dati
    foreach ($row in $Rows) {
        $line = '|'
        foreach ($col in $Columns) {
            $val = if ($row -is [hashtable]) { "$($row[$col.Key])" } else { "$($row.$($col.Key))" }
            $cell = ' ' + $val.PadRight($widths[$col.Key]) + ' |'
            $color = if ($col.Color) { $col.Color } else { 'White' }
            $line += $cell
        }
        # Colora l'intera riga in base alla colonna 'Status' se presente
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
Initialize-ToolkitPaths
WinOSCheck

function Test-WindowsUpdateStatus {
    <#
    .SYNOPSIS
        Controlla lo stato degli aggiornamenti Windows e avvisa l'utente in caso di operazioni pendenti.
    .DESCRIPTION
        Verifica riavvio pendente e stato servizio TrustedInstaller.
        Utilizza PSWindowsUpdate se disponibile, altrimenti fallback su registro e servizi nativi.
    #>
    try {
        Write-StyledMessage -Type 'Info' -Text "🔍 Controllo stato aggiornamenti Windows..."
        
        $pendingReboot = $false
        $installerRunning = $false
        
        # Verifica disponibilità modulo PSWindowsUpdate
        if (Get-Module -ListAvailable -Name PSWindowsUpdate -ErrorAction SilentlyContinue) {
            Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
            
            # Controllo riavvio pendente
            try {
                $rebootStatus = Get-WURebootStatus -ErrorAction SilentlyContinue
                if ($rebootStatus -and $rebootStatus.RebootRequired) {
                    $pendingReboot = $true
                    Write-StyledMessage -Type 'Warning' -Text "⚠️ Rilevato riavvio pendente per aggiornamenti Windows"
                }
            }
            catch { }
            
            # Controllo stato servizio installatore aggiornamenti
            try {
                $installerStatus = Get-WUInstallerStatus -ErrorAction SilentlyContinue
                if ($installerStatus -and $installerStatus.IsBusy) {
                    $installerRunning = $true
                    Write-StyledMessage -Type 'Warning' -Text "⚠️ Servizio installazione aggiornamenti Windows attualmente in esecuzione"
                }
            }
            catch { }
        }
        else {
            # Fallback: controllo chiavi registro ufficiali Windows Update
            $regPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootRequired",
                "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"
            )
            
            foreach ($path in $regPaths) {
                if (Test-Path $path -ErrorAction SilentlyContinue) {
                    $pendingReboot = $true
                    break
                }
            }
            
            # Controllo servizio TrustedInstaller nativo
            $trustedInstaller = Get-Service -Name TrustedInstaller -ErrorAction SilentlyContinue
            if ($trustedInstaller -and $trustedInstaller.Status -eq 'Running') {
                $installerRunning = $true
            }
        }
        
        # Mostra avviso dettagliato in caso di condizioni critiche
        if ($pendingReboot -or $installerRunning) {
            Write-Host ""
            Write-Host ('═' * ($Host.UI.RawUI.BufferSize.Width - 1)) -ForegroundColor Yellow
            Write-Host ""
            Write-Host (Center-Text "⚠️  AVVISO IMPORTANTE ⚠️") -ForegroundColor Yellow
            Write-Host ""
            Write-Host " Sono stati rilevati aggiornamenti di sistema pendenti:" -ForegroundColor Yellow
            if ($pendingReboot) {
                Write-Host "  ✓ Riavvio del sistema richiesto per completare aggiornamenti" -ForegroundColor Yellow
            }
            if ($installerRunning) {
                Write-Host "  ✓ Servizio installazione aggiornamenti Windows in corso" -ForegroundColor Yellow
            }
            Write-Host ""
            Write-Host " Questo potrebbe causare malfunzionamenti, errori o comportamenti" -ForegroundColor Yellow
            Write-Host " imprevisti in alcune o tutte le funzionalità di WinToolkit." -ForegroundColor Yellow
            Write-Host ""
            Write-Host (Center-Text "⚠️  PROCEDERE CON CAUTELA ⚠️") -ForegroundColor Red
            Write-Host ""
            Write-Host " Si consiglia vivamente di completare tutti gli aggiornamenti in corso," -ForegroundColor Yellow
            Write-Host " riavviare il sistema e poi riavviare WinToolkit prima di proseguire." -ForegroundColor Yellow
            Write-Host ""
            Write-Host ('═' * ($Host.UI.RawUI.BufferSize.Width - 1)) -ForegroundColor Yellow
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

Test-WindowsUpdateStatus

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
        
        # Leggi input RAW per Secret check (prima della validazione numerica)
        $rawInput = Microsoft.PowerShell.Utility\Read-Host 'Inserisci uno o più numeri (es: 1 2 3 oppure 1,2,3) per eseguire le operazioni in sequenza'
        
        # Secret check - valuta PRIMA della validazione numerica
        if ($rawInput -eq [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('V2luZG93cyDDqCB1bmEgbWVyZGE='))) {
            Start-Process ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly93d3cueW91dHViZS5jb20vd2F0Y2g/dj15QVZVT2tlNGtvYw==')))
            continue
        }
        
        # Valida input come numeri per il menu
        $rawSelections = Read-ValidatedChoice -Prompt 'Inserisci uno o più numeri' -Min 0 -Max $allScripts.Count -AllowZero -RawInput $rawInput
        $c = if ($rawSelections.Count -gt 0) { $rawSelections[0] } else { '' }

        if ($c -eq 0 -or $c -eq '0') {
            Write-StyledMessage -type 'Warning' -text 'Per supporto: Github.com/Magnetarman'
            Write-StyledMessage -type 'Success' -text 'Chiusura in corso...'
            Write-ToolkitLog -Level INFO -Message "Sessione WinToolkit terminata dall'utente."
            Start-Sleep -Seconds 3
            break
        }

        # Usa le selezioni già validate da Read-ValidatedChoice (filtra 0 se presente)
        $selections = @($rawSelections | Where-Object { $_ -ge 1 -and $_ -le $allScripts.Count })

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

        # Riepilogo esecuzione (solo se multi-script) — usa Show-ConsoleTable
        if ($isMultiScript) {
            Write-Host ''
            $tableRows = $Global:ExecutionLog | ForEach-Object {
                @{
                    Operazione = $_.Name
                    Stato      = if ($_.Success) { '✅ Completato' } else { '❌ Errore' }
                    Dettaglio  = if ($_.Error) { $_.Error } else { '' }
                }
            }
            $tableCols = @(
                @{ Header = 'Operazione'; Key = 'Operazione' },
                @{ Header = 'Stato'; Key = 'Stato' },
                @{ Header = 'Dettaglio'; Key = 'Dettaglio' }
            )
            Show-ConsoleTable -Rows $tableRows -Columns $tableCols -Title '📊 Riepilogo Esecuzione'
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



























































