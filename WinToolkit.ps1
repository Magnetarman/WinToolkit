param([int]$CountdownSeconds = 30, [switch]$ImportOnly)
function Read-Host {
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
        if ($Prompt) {
            Write-Host "${Prompt}: " -NoNewline -ForegroundColor Cyan
        }
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
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan"
$ToolkitVersion = "2.5.4 (Build 31)"
$AppConfig = @{
    URLs     = @{
        GitHubAssetBaseUrl    = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/"
        GitHubAssetDevBaseUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/"
        OfficeSetup           = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Setup.exe"
        OfficeBasicConfig     = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Basic.xml"
        SaRAInstaller         = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/SaRACmd_17_01_2877_000.zip"
        AMDInstaller          = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/AMD-Autodetect.exe"
        NVCleanstall          = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/NVCleanstall_1.19.0.exe"
        DDUZip                = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/DDU.zip"
        DirectXWebSetup       = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/dxwebsetup.exe"
        BattleNetInstaller    = "https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"
        SevenZipOfficial      = "https://www.7-zip.org/a/7zr.exe"
        WingetInstaller       = "https://aka.ms/getwinget"
        VCRedist86            = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
        VCRedist64            = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    }
    Paths    = @{
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
        'WinStore.App',
        'wsappx',
        'AppInstaller',
        'Microsoft.WindowsStore',
        'Microsoft.DesktopAppInstaller',
        'winget',
        'WindowsPackageManagerServer'
    )
}
$Global:Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
$Global:MsgStyles = @{
    Success  = @{ Icon = '✅'; Color = 'Green' }
    Warning  = @{ Icon = '⚠️'; Color = 'Yellow' }
    Error    = @{ Icon = '❌'; Color = 'Red' }
    Info     = @{ Icon = '💎'; Color = 'Cyan' }
    Progress = @{ Icon = '🔄'; Color = 'Magenta' }
}
$Global:ExecutionLog = @()
$Global:NeedsFinalReboot = $false
function Update-EnvironmentPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
    $env:Path = $newPath
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
}
function Stop-ToolkitProcesses {
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
    $aliasPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path $aliasPath) { return $aliasPath }
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
    param([string]$SubTitle = "Menu Principale")
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
    param([string]$ToolName)
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
    $Global:CurrentCorrelationId = [guid]::NewGuid().ToString()
    $os = Get-CimInstance Win32_OperatingSystem  -ErrorAction SilentlyContinue
    $sys = Get-CimInstance Win32_ComputerSystem   -ErrorAction SilentlyContinue
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
function Start-AppxSilentProcess {
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
    param(
        [int]$MaxWaitSeconds = 300,
        [int]$PollIntervalSeconds = 5
    )
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
        catch { }
        $remaining = $MaxWaitSeconds - ($i * $PollIntervalSeconds)
        Write-StyledMessage -Type Progress -Text "⏳ Winget non ancora pronto (tentativo $i/$maxRetries, restano $remaining s). Attesa..."
        Start-Sleep -Seconds $PollIntervalSeconds
    }
    Write-StyledMessage -Type Warning -Text "⚠️ Winget non ha risposto entro $MaxWaitSeconds secondi. Proseguo comunque."
    return $false
}
function Reset-Winget {
    param([switch]$Force)
    $ProgressPreference = 'SilentlyContinue'
    $OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
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
            } catch { }
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
            if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
                if ($PSVersionTable.PSVersion.Major -lt 7) {
                    try {
                        Install-PackageProvider -Name 'NuGet' -Force -ForceBootstrap -ErrorAction SilentlyContinue *>$null
                    }
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
            catch {
                Write-StyledMessage -Type Warning -Text "Impossibile installare modulo WinGet Client: $($_.Exception.Message)."
            }
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
    Write-StyledMessage -Type Info -Text "🚀 Avvio riparazione avanzata Winget..."
    if (-not (_Test-WingetCompatibility)) { return $false }
    if (-not $Force -and (_Test-WingetFunctionality)) {
        Write-StyledMessage -Type Success -Text "✅ Winget già operativo. Nessuna riparazione necessaria."
        return $true
    }
    Stop-ToolkitProcesses -ProcessNames $AppConfig.WingetProcesses
    try {
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
                ForEach-Object {
                    Write-StyledMessage -Type Info -Text "Trovata dipendenza: $($_.Name)."
                    $script:WingetDependencies += $_.FullName
                }
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
            Write-StyledMessage -Type Warning -Text "⚠️ Fase 1 insufficiente. Avvio Fase 2: Ripristino Avanzato."
            $null = _Install-WingetAdvanced
            $null = _Repair-WingetDatabase
            Update-EnvironmentPath
        }
        Start-Sleep -Seconds 3
        try {
            $wingetExeForReset = Get-WingetExecutable
            Start-Process -FilePath $wingetExeForReset -ArgumentList 'source', 'reset', '--force' `
                -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        }
        catch { }
        $deepOk = _Test-WingetDeepValidation
        if ($deepOk) {
            Write-StyledMessage -Type Success -Text "✅ Winget ripristinato e testato con successo."
            return $true
        }
        else {
            Write-StyledMessage -Type Warning -Text "⚠️ Winget installato. La validazione profonda ha rilevato anomalie (possibili problemi di rete o DB)."
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
function Show-ProgressBar {
    param([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon = '⏳', [string]$Spinner = '', [string]$Color = 'Green')
    $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
    $filled = '█' * [math]::Floor($safePercent * 30 / 100)
    $empty = '▒' * (30 - $filled.Length)
    $bar = "[$filled$empty] {0,3}%" -f $safePercent
    if (-not $Global:GuiSessionActive) {
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -ge 100) { Write-Host '' }
    }
}
function Invoke-WithSpinner {
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
        $result = & $Action
        if ($Timer) {
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
                if (-not $Global:GuiSessionActive) {
                    Write-Host "`r$spinner ⏳ $Activity - $i secondi..." -NoNewline -ForegroundColor Yellow
                }
                Start-Sleep -Seconds 1
            }
            if (-not $Global:GuiSessionActive) { Write-Host '' }
            return $true
        }
        elseif ($Process -and $result -and $result.GetType().Name -eq 'Process') {
            while (-not $result.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                if ($PercentUpdate) {
                    $percent = & $PercentUpdate
                }
                elseif ($percent -lt 90) {
                    $percent += Get-Random -Minimum 1 -Maximum 3
                }
                if (-not $Global:GuiSessionActive) {
                    Write-Host "`r" -NoNewline
                }
                Show-ProgressBar -Activity $Activity -Status "Esecuzione in corso... ($elapsed secondi)" -Percent $percent -Icon '⏳' -Spinner $spinner
                Start-Sleep -Milliseconds $UpdateInterval
                $result.Refresh()
            }
            if (-not $result.HasExited) {
                if (-not $Global:GuiSessionActive) { Write-Host "" }
                Write-StyledMessage -Type 'Warning' -Text "Timeout raggiunto dopo $TimeoutSeconds secondi, terminazione processo..."
                $result.Kill()
                Start-Sleep -Seconds 2
                return @{ Success = $false; TimedOut = $true; ExitCode = -1 }
            }
            if (-not $Global:GuiSessionActive) {
                Clear-ProgressLine
            }
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
        Write-StyledMessage -Type 'Error' -Text "Errore durante $Activity`: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}
function Start-InterruptibleCountdown {
    param(
        [int]$Seconds = 30,
        [string]$Message = "Riavvio automatico",
        [switch]$Suppress
    )
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
function WinRepairToolkit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$MaxRetryAttempts = 3,
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,
        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitLog -ToolName "WinRepairToolkit"
    Show-Header -SubTitle "Repair Toolkit"
    $Host.UI.RawUI.WindowTitle = "Repair Toolkit By MagnetarMan"
    $script:CurrentAttempt = 0
    $sysInfo = Get-SystemInfo
    $isWin11_24H2_OrNewer = $sysInfo -and ($sysInfo.BuildNumber -ge 26100)
    $RepairTools = @(
        @{ Tool = 'chkdsk'; Args = @('/scan', '/perf'); Name = 'Controllo disco'; Icon = '💽' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (1)'; Icon = '🗂️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Name = 'Ripristino immagine Windows'; Icon = '🛠️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'); Name = 'Pulizia Residui Aggiornamenti'; Icon = '🕸️' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (2)'; Icon = '🗂️' }
        @{ Tool = 'chkdsk'; Args = @('/f', '/r', '/x'); Name = 'Controllo disco approfondito'; Icon = '💽'; IsCritical = $false }
    )
    if ($isWin11_24H2_OrNewer) {
        $RepairTools += @{ Tool = 'powershell.exe'; Args = @('-NoProfile', '-NonInteractive', '-NoLogo', '-Command', "if (Test-Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\appxmanifest.xml') { Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction SilentlyContinue } else { Write-Host 'File non trovato: MicrosoftWindows.Client.CBS_cw5n1h2txyewy' }"); Name = 'Registrazione AppX (Client CBS)'; Icon = '📦'; IsCritical = $false }
        $RepairTools += @{ Tool = 'powershell.exe'; Args = @('-NoProfile', '-NonInteractive', '-NoLogo', '-Command', "if (Test-Path 'C:\Windows\SystemApps\Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe\appxmanifest.xml') { Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction SilentlyContinue } else { Write-Host 'File non trovato: Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe' }"); Name = 'Registrazione AppX (UI Xaml CBS)'; Icon = '📦'; IsCritical = $false }
        $RepairTools += @{ Tool = 'powershell.exe'; Args = @('-NoProfile', '-NonInteractive', '-NoLogo', '-Command', "if (Test-Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.Core_cw5n1h2txyewy\appxmanifest.xml') { Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.Core_cw5n1h2txyewy\appxmanifest.xml' -DisableDevelopmentMode -ErrorAction SilentlyContinue } else { Write-Host 'File non trovato: MicrosoftWindows.Client.Core_cw5n1h2txyewy' }"); Name = 'Registrazione AppX (Client Core)'; Icon = '📦'; IsCritical = $false }
    }
    function Invoke-RepairCommand {
        param([hashtable]$Config, [int]$Step, [int]$Total)
        Write-StyledMessage Info "[$Step/$Total] Avvio $($Config.Name)."
        $isChkdsk = ($Config.Tool -ieq 'chkdsk')
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()
        try {
            $processTimeoutSeconds = 600
            switch ($Config.Name) {
                'Ripristino immagine Windows'   { $processTimeoutSeconds = 10800 }
                'Controllo file di sistema (1)' { $processTimeoutSeconds = 3600 }
                'Controllo file di sistema (2)' { $processTimeoutSeconds = 10800 }
                'Pulizia Residui Aggiornamenti' { $processTimeoutSeconds = 3600 }
                'Controllo disco' { $processTimeoutSeconds = 900 }
                'Controllo disco approfondito'  { $processTimeoutSeconds = 3600 }
            }
            $spinnerUpdateInterval = if ($Config.Name -eq 'Ripristino immagine Windows') { 900 } else { 600 }
            if ($Config.Tool -ieq 'DISM' -and $Config.Args -contains '/StartComponentCleanup') {
                Write-StyledMessage Info "🔧 Pulizia stato DISM prima di avviare Cleanup..."
                Start-Process -FilePath 'DISM.exe' -ArgumentList @('/Online', '/Cleanup-Image', '/CancelCommands') -NoNewWindow -Wait -ErrorAction SilentlyContinue
                Start-Sleep 2
            }
            $result = Invoke-WithSpinner -Activity $Config.Name -Process -Action {
                if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
                    $drive = ($Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1) ?? $env:SystemDrive
                    $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }
                    $procParams = @{
                        FilePath               = 'cmd.exe'
                        ArgumentList           = @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ') 2>&1")
                        RedirectStandardOutput = $outFile
                        RedirectStandardError  = $errFile
                        NoNewWindow            = $true
                        PassThru               = $true
                        UseNewEnvironment      = $true
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
            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r') -and ($results -join ' ').ToLower() -match 'schedule|next time.*restart|volume.*in use') {
                Write-StyledMessage Info "🔧 $($Config.Name): controllo schedulato al prossimo riavvio."
                return @{ Success = $true; ErrorCount = 0 }
            }
            $exitCode = $result.ExitCode
            $isTimeout = ($null -eq $result) -or ($null -eq $exitCode) -or ($exitCode -eq -1)
            if ($isChkdsk -and $exitCode -eq 3) {
                Write-StyledMessage Info "🔧 $($Config.Name): controllo schedulato al prossimo riavvio."
                return @{ Success = $true; ErrorCount = 0 }
            }
            if (($Config.Tool -ieq 'DISM') -and ($results -match '0x800f0806')) {
                Write-StyledMessage Warning "⚠️ $($Config.Name): Errore 0x800f0806 (operazioni pendenti). Questo non è un errore critico."
                Write-StyledMessage Info "💡 Riavviare il sistema per completare le operazioni in sospeso."
                return @{ Success = $true; ErrorCount = 0 }
            }
            $hasDismSuccess = (-not $isTimeout) -and ($Config.Tool -ieq 'DISM') -and ($results -match '(?i)completed successfully')
            if (($Config.Tool -ieq 'DISM') -and ($Config.Args -contains '/ResetBase') -and $exitCode -eq 3010) {
                $hasDismSuccess = $true
            }
            $isChkdskScan = $isChkdsk -and ($Config.Args -contains '/scan')
            $chkdskCompleted = (-not $isTimeout) -and $isChkdskScan -and (($results -join ' ') -match '(?i)(scansione.*completata|scan.*completed|successfully scanned)')
            $isSuccess = (-not $isTimeout) -and (($exitCode -eq 0) -or $exitCode -eq 3010 -or $hasDismSuccess -or $chkdskCompleted)
            $errors = $warnings = @()
            if (-not $isSuccess) {
                if ($isTimeout) {
                    $errors += "Timeout: L'operazione ha superato il tempo limite ed è stata terminata."
                }
                foreach ($line in ($results | Where-Object { $_ -and ![string]::IsNullOrWhiteSpace($_.Trim()) })) {
                    $trim = $line.Trim()
                    if ($trim -match '^\[=+\s*\d+' -or $trim -match '(?i)version:|deployment image') { continue }
                    if ($isChkdsk) {
                        if ($trim -match '(?i)(stage|fase|percent complete|verificat|scanned|scanning|errors found.*corrected|volume label)') { continue }
                        if ($trim -match '(?i)(cannot|unable to|access denied|critical|fatal|corrupt file system|bad sectors)') {
                            $errors += $trim
                        }
                    }
                     else {
                        if ($trim -match '0x800f0806') {
                        }
                        elseif ($trim -match '(?i)(errore|error|failed|impossibile|corrotto|corruption)') { $errors += $trim }
                        elseif ($trim -match '(?i)(warning|avviso|attenzione)') { $warnings += $trim }
                    }
                }
                if ($errors.Count -eq 0 -and -not $isTimeout) {
                    $errors += "Errore generico o terminazione anomala (ExitCode: $exitCode)."
                }
            }
            $success = $isSuccess -and ($errors.Count -eq 0)
            if ($isTimeout) {
                $message = "$($Config.Name) NON completato (interrotto per Timeout)."
            }
            else {
                $message = "$($Config.Name) completato " + $(if ($success) { 'con successo' } else { "con $($errors.Count) errori" })
            }
            Write-StyledMessage $(if ($success) { 'Success' } else { 'Warning' }) $message
            if ($Config.Tool -ieq 'sfc') {
                $cbsLogPath = "C:\Windows\Logs\CBS\CBS.log"
                if (Test-Path $cbsLogPath) {
                    try {
                        $safeStepName = $Config.Name -replace '[^a-zA-Z0-9]', '_'
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                        $destLogName = "SFC_CBS_${safeStepName}_${timestamp}.log"
                        $destLogPath = Join-Path $AppConfig.Paths.Logs $destLogName
                        Copy-Item -Path $cbsLogPath -Destination $destLogPath -Force -ErrorAction SilentlyContinue
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
            Write-StyledMessage Error "Errore durante $($Config.Name): $($_.Exception.Message)."
            Write-ToolkitLog -Level ERROR -Message "Errore in Invoke-RepairCommand [$($Config.Tool)]" -Context @{
                Line      = $_.InvocationInfo.ScriptLineNumber
                Exception = $_.Exception.GetType().FullName
                Stack     = $_.ScriptStackTrace
            }
            return @{ Success = $false; ErrorCount = 1 }
        }
        finally {
            foreach ($f in @($outFile, $errFile)) {
                if (Test-Path $f) {
                    $raw = Get-Content $f -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                    if (-not [string]::IsNullOrWhiteSpace($raw)) {
                        $label = if ($f -eq $outFile) { 'STDOUT' } else { 'STDERR' }
                        Write-ToolkitLog -Level DEBUG -Message "[PROCESS $label`: $($Config.Tool)]`n$raw"
                    }
                    Remove-Item $f -ErrorAction SilentlyContinue
                }
            }
        }
    }
    function Start-RepairCycle {
        param([int]$Attempt = 1)
        $script:CurrentAttempt = $Attempt
        Write-StyledMessage Info "🔄 Tentativo $Attempt/$MaxRetryAttempts - Riparazione sistema."
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
            Write-StyledMessage Warning "🔄 $totalErrors errori rilevati. Nuovo tentativo."
            Start-Sleep 3
            return Start-RepairCycle -Attempt ($Attempt + 1)
        }
        return @{ Success = ($totalErrors -eq 0); TotalErrors = $totalErrors; AttemptsUsed = $Attempt }
    }
    function Start-DeepDiskRepair {
        Write-StyledMessage -Type 'Info' -Text '🔧 Avvio riparazione profonda del disco C: al prossimo riavvio.'
        try {
            $fsutilResult = Invoke-ExternalCommandWithLog -Command 'fsutil.exe' -Arguments @('dirty', 'set', 'C:') -TimeoutSeconds 300 -LogContextKey 'DeepDiskRepair-Fsutil'
            if (-not $fsutilResult.Success) {
                Write-StyledMessage -Type 'Error' -Text "❌ Impossibile marcare il disco come dirty (fsutil)."
                return $false
            }
            $chkdskResult = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'echo Y | chkdsk C: /f /r /v /x /b') -TimeoutSeconds 7200 -LogContextKey 'DeepDiskRepair-Chkdsk'
            if (-not $chkdskResult.Success) {
                Write-StyledMessage -Type 'Error' -Text "❌ Errore durante la schedulazione di chkdsk per la riparazione profonda."
                return $false
            }
            Write-StyledMessage -Type 'Info' -Text 'Comando chkdsk inviato. Riavvia per eseguire la riparazione profonda del disco.'
            return $true
        }
        catch {
            Write-ToolkitLog -Level 'ERROR' -Message 'Eccezione in Start-DeepDiskRepair' -Context @{
                Tool      = 'WinRepairToolkit'
                Step      = 'Start-DeepDiskRepair'
                Exception = $_.Exception.Message
                Stack     = $_.ScriptStackTrace
            }
            Write-StyledMessage -Type 'Error' -Text "Errore durante la schedulazione della riparazione profonda: $($_.Exception.Message)."
            return $false
        }
    }
    function Test-PendingOperations {
        $pendingRebootKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
            'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
        )
        foreach ($key in $pendingRebootKeys) {
            if (Test-Path $key) {
                $values = Get-ItemProperty $key -ErrorAction SilentlyContinue
                if ($values -and $values.PSObject.Properties.Count -gt 1) {
                    return $true
                }
            }
        }
        return $false
    }
    if (Test-PendingOperations) {
        Write-StyledMessage Warning "⚠️ Rilevate operazioni pendenti che richiedono riavvio. DISM potrebbe fallire."
        Write-StyledMessage Info "💡 Consigliato riavviare prima di eseguire le riparazioni."
    }
    try {
        $repairResult = Start-RepairCycle
        $deepRepairScheduled = $false
        if ($repairResult.TotalErrors -gt 0) {
            Write-StyledMessage Warning "Rilevati errori persistenti. Avvio riparazione profonda."
            $deepRepairScheduled = Start-DeepDiskRepair
        }
        else {
            Write-StyledMessage Success "Sistema in salute. Riparazione profonda non necessaria."
        }
        Write-StyledMessage Info "⚙️ Impostazione scadenza password illimitata."
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
        Write-StyledMessage Error "❌ Errore critico: $($_.Exception.Message)."
        Write-ToolkitLog -Level ERROR -Message "Errore critico in WinRepairToolkit" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
}
function WinUpdateReset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,
        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitLog -ToolName "WinUpdateReset"
    Show-Header -SubTitle "Update Reset Toolkit"
    $Host.UI.RawUI.WindowTitle = "Win Update Reset Toolkit By MagnetarMan"
    function Set-ServiceStatus {
        param (
            [Parameter(Mandatory = $true)][string]$Name,
            [Parameter(Mandatory = $true)][ValidateSet('Running', 'Stopped')][string]$Status,
            [switch]$Wait,
            [int]$TimeoutSeconds = 10
        )
        $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if (-not $service) { return $false }
        if ($service.Status -eq $Status) { return $true }
        try {
            if ($Status -eq 'Running') { Start-Service -Name $Name -ErrorAction Stop }
            else { Stop-Service -Name $Name -Force -ErrorAction Stop }
        }
        catch { return $false }
        if ($Wait) {
            $timeout = $TimeoutSeconds
            while ((Get-Service -Name $Name -ErrorAction SilentlyContinue).Status -ne $Status -and $timeout -gt 0) {
                Start-Sleep -Seconds 1
                $timeout--
            }
            return ((Get-Service -Name $Name -ErrorAction SilentlyContinue).Status -eq $Status)
        }
        return $true
    }
    function Show-ServiceProgress([string]$ServiceName, [string]$Action, [int]$Current, [int]$Total) {
        $percent = [math]::Round(($Current / $Total) * 100)
        Invoke-WithSpinner -Activity "$Action $ServiceName" -Timer -Action { Start-Sleep -Milliseconds 200 } -TimeoutSeconds 1 | Out-Null
    }
    function Manage-Service($serviceName, $action, $config, $currentStep, $totalSteps) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            if (-not $service) {
                Write-StyledMessage -Type 'Warning' -Text "$serviceIcon Servizio $serviceName non trovato nel sistema."
                return
            }
            switch ($action) {
                'Stop' {
                    Show-ServiceProgress $serviceName "Arresto" $currentStep $totalSteps
                    $success = Set-ServiceStatus -Name $serviceName -Status 'Stopped' -Wait -TimeoutSeconds 10
                    if ($success) {
                        Write-StyledMessage -Type 'Info' -Text "$serviceIcon Servizio $serviceName arrestato."
                    }
                    else {
                        Write-StyledMessage -Type 'Warning' -Text "$serviceIcon Arresto di $serviceName ha richiesto troppo tempo o è fallito."
                    }
                }
                'Configure' {
                    Show-ServiceProgress $serviceName "Configurazione" $currentStep $totalSteps
                    Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop | Out-Null
                    Write-StyledMessage -Type 'Success' -Text "$serviceIcon Servizio $serviceName configurato come $($config.Type)."
                }
                'Start' {
                    Show-ServiceProgress $serviceName "Avvio" $currentStep $totalSteps
                    $success = $false
                    Invoke-WithSpinner -Activity "Attesa avvio $serviceName" -Timer -Action {
                        $success = Set-ServiceStatus -Name $serviceName -Status 'Running' -Wait -TimeoutSeconds 10
                    } -TimeoutSeconds 5 | Out-Null
                    $clearLine = "`r" + (' ' * 80) + "`r"
                    Write-Host $clearLine -NoNewline
                    if ($success) {
                        Write-StyledMessage -Type 'Success' -Text "$serviceIcon Servizio ${serviceName}: avviato correttamente."
                    }
                    else {
                        Write-StyledMessage -Type 'Warning' -Text "$serviceIcon Servizio ${serviceName}: avvio in corso o ritardato."
                    }
                }
                'Check' {
                    $status = ($service.Status -eq 'Running') ? '🟢 Attivo' : '🔴 Inattivo'
                    $serviceIcon = $config.Icon ?? '⚙️'
                    Write-StyledMessage -Type 'Info' -Text "$serviceIcon $serviceName - Stato: $status"
                }
            }
        }
        catch {
            $actionText = switch ($action) { 'Configure' { 'configurare' } 'Start' { 'avviare' } 'Check' { 'verificare' } default { $action.ToLower() } }
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            Write-StyledMessage -Type 'Warning' -Text "$serviceIcon Impossibile $actionText $serviceName - $($_.Exception.Message)."
        }
    }
    function Remove-DirectorySafely([string]$path, [string]$displayName) {
        if (-not (Test-Path $path)) {
            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Info' -Text "💭 Directory $displayName non presente."
            return $true
        }
        try {
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue *>$null
            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Success' -Text "🗑️ Directory $displayName eliminata."
            return $true
        }
        catch {
            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline
            Write-StyledMessage -Type 'Warning' -Text "Tentativo fallito, provo con eliminazione forzata."
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
                $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                Write-Host $clearLines -NoNewline
                [Console]::Out.Flush()
                if (-not (Test-Path $path)) {
                    Write-StyledMessage -Type 'Success' -Text "🗑️ Directory $displayName eliminata (metodo forzato)."
                    return $true
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "Directory $displayName parzialmente eliminata."
                    return $false
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Impossibile eliminare completamente $displayName - file in uso."
                return $false
            }
            finally {
                $ErrorActionPreference = 'Continue'
                $ProgressPreference = 'Continue'
                $VerbosePreference = 'SilentlyContinue'
            }
        }
    }
    Write-StyledMessage -Type 'Info' -Text '🔧 Inizializzazione dello Script di Reset Windows Update.'
    Invoke-WithSpinner -Activity "Caricamento moduli" -Timer -Action { Start-Sleep 2 } -TimeoutSeconds 2 | Out-Null
    Write-StyledMessage -Type 'Info' -Text '🛠️ Avvio riparazione servizi Windows Update.'
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
        Write-StyledMessage -Type 'Info' -Text '🛑 Arresto servizi Windows Update.'
        $stopServices = @('wuauserv', 'cryptsvc', 'bits', 'msiserver')
        for ($serviceIndex = 0; $serviceIndex -lt $stopServices.Count; $serviceIndex++) {
            Manage-Service $stopServices[$serviceIndex] 'Stop' $serviceConfig[$stopServices[$serviceIndex]] ($serviceIndex + 1) $stopServices.Count
        }
        Write-StyledMessage -Type 'Info' -Text '⏳ Attesa liberazione risorse.'
        Start-Sleep -Seconds 3
        Write-StyledMessage -Type 'Info' -Text '⚙️ Ripristino configurazione servizi Windows Update.'
        $criticalServices = $serviceConfig.Keys | Where-Object { $serviceConfig[$_].Critical }
        for ($criticalIndex = 0; $criticalIndex -lt $criticalServices.Count; $criticalIndex++) {
            $serviceName = $criticalServices[$criticalIndex]
            Write-StyledMessage -Type 'Info' -Text "$($serviceConfig[$serviceName].Icon) Elaborazione servizio: $serviceName."
            Manage-Service $serviceName 'Configure' $serviceConfig[$serviceName] ($criticalIndex + 1) $criticalServices.Count
        }
        Write-StyledMessage -Type 'Info' -Text '🔍 Verifica servizi di sistema critici.'
        for ($systemIndex = 0; $systemIndex -lt $systemServices.Count; $systemIndex++) {
            $sysService = $systemServices[$systemIndex]
            Manage-Service $sysService.Name 'Check' @{ Icon = $sysService.Icon } ($systemIndex + 1) $systemServices.Count
        }
        Write-StyledMessage -Type 'Info' -Text '📋 Ripristino chiavi di registro Windows Update.'
        Invoke-WithSpinner -Activity "Elaborazione registro" -Timer -Action { Start-Sleep 1 } -TimeoutSeconds 1 | Out-Null
        try {
            @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update",
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            ) | Where-Object { Test-Path $_ } | ForEach-Object {
                Remove-Item $_ -Recurse -Force -ErrorAction Stop | Out-Null
                Write-StyledMessage -Type 'Success' -Text 'Completato!'
            }
            if (-not @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update", "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate") | Where-Object { Test-Path $_ }) {
                Write-StyledMessage -Type 'Success' -Text 'Completato!'
                Write-StyledMessage -Type 'Info' -Text "🔑 Nessuna chiave di registro da rimuovere."
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text 'Errore!'
            Write-StyledMessage -Type 'Warning' -Text "Errore durante la modifica del registro - $($_.Exception.Message)."
        }
        Write-StyledMessage -Type 'Info' -Text '🗂️ Eliminazione componenti Windows Update.'
        $directories = @(
            @{ Path = "$env:WinDir\SoftwareDistribution"; Name = "SoftwareDistribution" },
            @{ Path = "$env:WinDir\System32\catroot2"; Name = "catroot2" },
            @{ Path = "$env:WinDir\System32\WaaSMedicSvc.dll"; Name = "WaaSMedicSvc.dll" },
            @{ Path = "$env:WinDir\System32\wuaueng.dll"; Name = "wuaueng.dll" },
            @{ Path = "$env:WinDir\System32\WaaSMedicSvc_BAK.dll"; Name = "WaaSMedicSvc_BAK.dll" },
            @{ Path = "$env:WinDir\System32\wuaueng_BAK.dll"; Name = "wuaueng_BAK.dll" },
            @{ Path = "$env:WinDir\SoftwareDistribution\Download"; Name = "Download" },
            @{ Path = "$env:WinDir\SoftwareDistribution\DataStore"; Name = "DataStore" },
            @{ Path = "$env:WinDir\SoftwareDistribution\Backup"; Name = "Backup" }
        )
        for ($dirIndex = 0; $dirIndex -lt $directories.Count; $dirIndex++) {
            $dir = $directories[$dirIndex]
            $percent = [math]::Round((($dirIndex + 1) / $directories.Count) * 100)
            Show-ProgressBar "Directory ($($dirIndex + 1)/$($directories.Count))" "Eliminazione $($dir.Name)" $percent '🗑️' '' 'Yellow'
            Start-Sleep -Milliseconds 300
            $success = Remove-DirectorySafely -path $dir.Path -displayName $dir.Name
            if (-not $success) {
                Write-StyledMessage -Type 'Info' -Text "💡 Suggerimento: Alcuni file potrebbero essere ricreati dopo il riavvio."
            }
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            Start-Sleep -Milliseconds 500
        }
        [Console]::Out.Flush()
        Write-StyledMessage -Type 'Info' -Text '🚀 Avvio servizi essenziali.'
        $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
        for ($essentialIndex = 0; $essentialIndex -lt $essentialServices.Count; $essentialIndex++) {
            Manage-Service $essentialServices[$essentialIndex] 'Start' $serviceConfig[$essentialServices[$essentialIndex]] ($essentialIndex + 1) $essentialServices.Count
        }
        Write-StyledMessage -Type 'Progress' -Text '⚡ Esecuzione comando reset. '
        try {
            $procParams = @{
                FilePath     = 'cmd.exe'
                ArgumentList = '/c', 'wuauclt', '/resetauthorization', '/detectnow'
                Wait         = $true
                WindowStyle  = 'Hidden'
                ErrorAction  = 'SilentlyContinue'
            }
            Start-Process @procParams | Out-Null
            Write-StyledMessage -Type 'Success' -Text 'Completato!'
            Write-StyledMessage -Type 'Success' -Text "🔄 Client Windows Update reimpostato."
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text 'Errore!'
            Write-StyledMessage -Type 'Warning' -Text "Errore durante il reset del client Windows Update."
        }
        Write-StyledMessage -Type 'Info' -Text '🔧 Abilitazione Windows Update e servizi correlati.'
        Write-StyledMessage -Type 'Info' -Text '📋 Ripristino impostazioni registro Windows Update.'
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
            Write-StyledMessage -Type 'Success' -Text "🔑 Impostazioni registro Windows Update ripristinate."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare alcune chiavi di registro - $($_.Exception.Message)"
        }
        Write-StyledMessage -Type 'Info' -Text '🔧 Ripristino impostazioni WaaSMedicSvc.'
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Type DWord -Value 3 -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "FailureActions" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "⚙️ Impostazioni WaaSMedicSvc ripristinate."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare WaaSMedicSvc - $($_.Exception.Message)."
        }
        Write-StyledMessage -Type 'Info' -Text '🔄 Ripristino servizi di update.'
        $services = @(
            @{Name = "BITS"; StartupType = "Manual"; Icon = "📡" },
            @{Name = "wuauserv"; StartupType = "Manual"; Icon = "🔄" },
            @{Name = "UsoSvc"; StartupType = "Automatic"; Icon = "🚀" },
            @{Name = "uhssvc"; StartupType = "Disabled"; Icon = "⭕" },
            @{Name = "WaaSMedicSvc"; StartupType = "Manual"; Icon = "🛡️" }
        )
        foreach ($service in $services) {
            try {
                Write-StyledMessage -Type 'Info' -Text "$($service.Icon) Ripristino $($service.Name) a $($service.StartupType)."
                $serviceObj = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
                if ($serviceObj) {
                    Set-Service -Name $service.Name -StartupType $service.StartupType -ErrorAction SilentlyContinue | Out-Null
                    $procParams = @{
                        FilePath     = 'sc.exe'
                        ArgumentList = 'failure', "$($service.Name)", 'reset= 86400 actions= restart/60000/restart/60000/restart/60000'
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams | Out-Null
                    if ($service.StartupType -eq "Automatic") {
                        Set-ServiceStatus -Name $service.Name -Status "Running" -Wait -TimeoutSeconds 5 | Out-Null
                    }
                    Write-StyledMessage -Type 'Success' -Text "$($service.Icon) Servizio $($service.Name) ripristinato."
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare servizio $($service.Name) - $($_.Exception.Message)."
            }
        }
        Write-StyledMessage -Type 'Info' -Text '🔍 Ripristino DLL rinominate.'
        $dlls = @("WaaSMedicSvc", "wuaueng")
        foreach ($dll in $dlls) {
            $dllPath = "$env:WinDir\System32\$dll.dll"
            $backupPath = "$env:WinDir\System32\${dll}_BAK.dll"
            if ((Test-Path $backupPath) -and !(Test-Path $dllPath)) {
                try {
                    $procParams = @{
                        FilePath     = 'takeown.exe'
                        ArgumentList = '/f', "`"$backupPath`""
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams | Out-Null
                    $procParams = @{
                        FilePath     = 'icacls.exe'
                        ArgumentList = "`"$backupPath`"", '/grant', '*S-1-1-0:F'
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                        ErrorAction  = 'SilentlyContinue'
                    }
                    Start-Process @procParams | Out-Null
                    Rename-Item -Path $backupPath -NewName "$dll.dll" -ErrorAction SilentlyContinue | Out-Null
                    Write-StyledMessage -Type 'Success' -Text "Ripristinato ${dll}_BAK.dll a $dll.dll."
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
                    Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare $dll.dll - $($_.Exception.Message)."
                }
            }
            elseif (Test-Path $dllPath) {
                Write-StyledMessage -Type 'Info' -Text "💭 $dll.dll già presente nella posizione originale."
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "⚠️ $dll.dll non trovato e nessun backup disponibile."
            }
        }
        Write-StyledMessage -Type 'Info' -Text '📅 Riabilitazione task pianificati.'
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
                    Write-StyledMessage -Type 'Success' -Text "Task abilitato: $($task.TaskName)."
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile abilitare task in $taskPath - $($_.Exception.Message)."
            }
        }
        Write-StyledMessage -Type 'Info' -Text '🖨️ Abilitazione driver tramite Windows Update.'
        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontPromptForWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontSearchWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DriverUpdateWizardWuSearchEnabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "🖨️ Driver tramite Windows Update abilitati."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile abilitare driver - $($_.Exception.Message)."
        }
        Write-StyledMessage -Type 'Info' -Text '🔄 Abilitazione riavvio automatico Windows Update.'
        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "🔄 Riavvio automatico Windows Update abilitato."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile abilitare riavvio automatico - $($_.Exception.Message)."
        }
        Write-StyledMessage -Type 'Info' -Text '⚙️ Ripristino impostazioni Windows Update.'
        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "BranchReadinessLevel" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferQualityUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "⚙️ Impostazioni Windows Update ripristinate."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare alcune impostazioni - $($_.Exception.Message)."
        }
        Write-StyledMessage -Type 'Info' -Text '📋 Ripristino criteri locali Windows.'
        try {
            Write-StyledMessage -Type 'Info' -Text '⏳ Eliminazione criteri locali.'
            $rdProc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c RD /S /Q `"$env:WinDir\System32\GroupPolicy`"" -WindowStyle Hidden -ErrorAction SilentlyContinue -PassThru
            $rdTimeout = 10
            while (-not $rdProc.HasExited -and $rdTimeout -gt 0) {
                Start-Sleep -Seconds 1
                $rdTimeout--
            }
            if (-not $rdProc.HasExited) { $rdProc | Stop-Process -Force -ErrorAction SilentlyContinue }
            Write-StyledMessage -Type 'Success' -Text '✅ Criteri eliminati.'
            Write-StyledMessage -Type 'Info' -Text '⏳ Aggiornamento criteri.'
            $gpProc = Start-Process -FilePath "gpupdate.exe" -ArgumentList "/force" -WindowStyle Hidden -ErrorAction SilentlyContinue -PassThru
            $gpTimeout = 15
            while (-not $gpProc.HasExited -and $gpTimeout -gt 0) {
                Start-Sleep -Seconds 1
                $gpTimeout--
            }
            if (-not $gpProc.HasExited) {
                $gpProc | Stop-Process -Force -ErrorAction SilentlyContinue
                Write-StyledMessage -Type 'Warning' -Text "⚠️ gpupdate terminato per timeout."
            }
            else {
                Write-StyledMessage -Type 'Success' -Text '✅ Criteri aggiornati.'
            }
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
            Write-StyledMessage -Type 'Success' -Text "📋 Criteri locali Windows ripristinati."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Avviso: Impossibile ripristinare alcuni criteri - $($_.Exception.Message)."
        }
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Success' -Text '🎉 Windows Update è stato RIPRISTINATO ai valori predefiniti!'
        Write-StyledMessage -Type 'Success' -Text '🔄 Servizi, registro e criteri sono stati configurati correttamente.'
        Write-StyledMessage -Type 'Warning' -Text "⚡ Nota: È necessario un riavvio per applicare completamente tutte le modifiche."
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Info' -Text '🔍 Verifica finale dello stato dei servizi.'
        $verificationServices = @('wuauserv', 'BITS', 'UsoSvc', 'WaaSMedicSvc')
        foreach ($service in $verificationServices) {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc) {
                $status = ($svc.Status -eq 'Running') ? '🟢 ATTIVO' : '🔴 INATTIVO'
                $startup = $svc.StartType
                Write-StyledMessage -Type 'Info' -Text "📊 $service - Stato: $status | Avvio: $startup."
            }
        }
        Write-StyledMessage -Type 'Info' -Text '💡 Windows Update dovrebbe ora funzionare normalmente.'
        Write-StyledMessage -Type 'Info' -Text '🔧 Verifica aprendo Impostazioni > Aggiornamento e sicurezza.'
        Write-StyledMessage -Type 'Info' -Text '🔄 Se necessario, riavvia il sistema per applicare tutte le modifiche.'
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Success' -Text '🎉 Riparazione completata con successo!'
        Write-StyledMessage -Type 'Success' -Text '💻 Il sistema necessita di un riavvio per applicare tutte le modifiche.'
        Write-StyledMessage -Type 'Warning' -Text "⚡ Attenzione: il sistema verrà riavviato automaticamente."
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        if ($SuppressIndividualReboot) {
            $Global:NeedsFinalReboot = $true
            Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
        }
        else {
            $shouldReboot = Start-InterruptibleCountdown $CountdownSeconds "Preparazione riavvio sistema"
            if ($shouldReboot) {
                Write-StyledMessage -Type 'Info' -Text "🔄 Riavvio in corso."
                Restart-Computer -Force
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text '═════════════════════════════════════════════════════════════════'
        Write-StyledMessage -Type 'Error' -Text "💥 Errore critico: $($_.Exception.Message)."
        Write-StyledMessage -Type 'Info' -Text '⌨️ Premere un tasto per uscire.'
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-ToolkitLog -Level ERROR -Message "Errore critico in WinUpdateReset: $($_.Exception.Message)" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
}
function WinReinstallStore {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitLog -ToolName "WinReinstallStore"
    Show-Header -SubTitle "Store Repair Toolkit"
    $savedProgressPref = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    function Install-MicrosoftStore {
        Write-StyledMessage -Type 'Info' -Text "🔄 Reinstallazione Microsoft Store in corso."
        Write-StyledMessage -Type 'Info' -Text "Restart servizi Microsoft Store."
        @('AppXSvc', 'ClipSVC', 'WSService') | ForEach-Object {
            try { Restart-Service $_ -Force -ErrorAction SilentlyContinue *>$null } catch { }
        }
        @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
            (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\INetCache")
        ) | ForEach-Object {
            if (Test-Path $_) {
                $ProgressPreference = 'SilentlyContinue'
                Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue *>$null
            }
        }
        $wingetExe = Get-WingetExecutable
        $installMethods = @(
            @{
                Name   = 'Winget Install'
                Action = {
                    if (-not (Test-Path $wingetExe -ErrorAction SilentlyContinue)) { return @{ ExitCode = -1 } }
                    $processResult = Invoke-WithConsoleRedirection -Action {
                        Invoke-WithSpinner -Activity "Installazione Store tramite Winget" -Process -Action {
                            $procParams = @{
                                FilePath     = $wingetExe
                                ArgumentList = @('install', '9WZDNCRFJBMP',
                                    '--accept-source-agreements', '--accept-package-agreements',
                                    '--silent', '--disable-interactivity')
                                PassThru     = $true
                                WindowStyle  = 'Hidden'
                            }
                            Start-Process @procParams
                        } -TimeoutSeconds 300
                    }
                    return @{ ExitCode = $processResult.ExitCode }
                }
            },
            @{
                Name   = 'AppX Manifest'
                Action = {
                    $store = Get-AppxPackage -AllUsers *WindowsStore* -ErrorAction SilentlyContinue | Select-Object -First 1
                    $manifest = if ($store) { Join-Path $store.InstallLocation 'AppxManifest.xml' } else { $null }
                    if (-not $manifest -or -not (Test-Path $manifest)) { return @{ ExitCode = -1 } }
                    $procResult = Invoke-WithSpinner -Activity "Registrazione AppX Manifest Store" -Process -Action {
                        Start-AppxSilentProcess -AppxPath $manifest -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown'
                    } -TimeoutSeconds 120
                    return @{ ExitCode = $procResult.ExitCode }
                }
            },
            @{
                Name   = 'DISM Capability'
                Action = {
                    $result = Invoke-WithConsoleRedirection -Action {
                        Invoke-WithSpinner -Activity "Aggiunta Store via DISM" -Process -Action {
                            $procParams = @{
                                FilePath     = 'DISM'
                                ArgumentList = @('/Online', '/Add-Capability', '/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0')
                                PassThru     = $true
                                WindowStyle  = 'Hidden'
                            }
                            Start-Process @procParams
                        } -TimeoutSeconds 300
                    }
                    return @{ ExitCode = $result.ExitCode }
                }
            }
        )
        $success = $false
        foreach ($method in $installMethods) {
            Write-StyledMessage -Type 'Info' -Text "Tentativo tramite: $($method.Name)."
            try {
                $result = $method.Action.Invoke()
                $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                Write-Host $clearLine -NoNewline
                [Console]::Out.Flush()
                $isSuccess = $result -and ($result.ExitCode -in @(0, 3010, 1638, -1978335189))
                if ($isSuccess) {
                    Write-StyledMessage -Type 'Success' -Text "Microsoft Store reinstallato tramite $($method.Name)."
                    $success = $true
                    break
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "Metodo $($method.Name) non riuscito (ExitCode: $(if ($result.ExitCode) { $result.ExitCode } else { 'N/A' }))."
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Metodo $($method.Name) fallito: $($_.Exception.Message)."
            }
        }
        if ($success) {
            $null = Invoke-WithConsoleRedirection -Action {
                Invoke-WithSpinner -Activity "Reset cache Microsoft Store (wsreset)" -Process -Action {
                    $procParams = @{
                        FilePath    = 'wsreset.exe'
                        PassThru    = $true
                        WindowStyle = 'Hidden'
                    }
                    Start-Process @procParams
                } -TimeoutSeconds 120
            }
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Success' -Text "Cache dello Store ripristinata."
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Impossibile reinstallare Microsoft Store tramite metodi automatici."
            Write-StyledMessage -Type 'Info' -Text "Tentativo di emergenza tramite AppXManifest."
            try {
                $null = Invoke-WithSpinner -Activity "Ripristino di emergenza Store" -Process -Action {
                    $ProgressPreference = 'SilentlyContinue'
                    Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object {
                        Start-AppxSilentProcess -AppxPath "$($_.InstallLocation)\AppXManifest.xml" -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown'
                    }
                } -TimeoutSeconds 300
                $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                Write-Host $clearLine -NoNewline
                [Console]::Out.Flush()
                Write-StyledMessage -Type 'Success' -Text "Microsoft Store ripristinato tramite metodo di emergenza."
                $success = $true
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Ripristino di emergenza fallito: $($_.Exception.Message)."
            }
        }
        return $success
    }
    function Install-UniGetUI {
        Write-StyledMessage -Type 'Info' -Text "🔄 Installazione UniGet UI."
        $wingetExe = Get-WingetExecutable
        if (-not (Test-Path $wingetExe -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Warning' -Text "Winget non disponibile. UniGet UI richiede Winget."
            return $false
        }
        try {
            $null = Invoke-WithSpinner -Activity "Disinstallazione versioni precedenti UniGet UI" -Process -Action {
                $procParams = @{
                    FilePath     = $wingetExe
                    ArgumentList = @('uninstall', '--exact', '--id', 'MartiCliment.UniGetUI',
                        '--silent', '--disable-interactivity')
                    PassThru     = $true
                    WindowStyle  = 'Hidden'
                }
                Start-Process @procParams
            } -TimeoutSeconds 120
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            $processResult = Invoke-WithSpinner -Activity "Installazione UniGet UI" -Process -Action {
                $procParams = @{
                    FilePath     = $wingetExe
                    ArgumentList = @('install', '--exact', '--id', 'Devolutions.UniGetUI',
                        '--source', 'winget', '--accept-source-agreements',
                        '--accept-package-agreements', '--silent',
                        '--disable-interactivity', '--force')
                    PassThru     = $true
                    WindowStyle  = 'Hidden'
                }
                Start-Process @procParams
            } -TimeoutSeconds 600
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            $isSuccess = $processResult.ExitCode -in @(0, 3010, 1638, -1978335189)
            if ($isSuccess) {
                Write-StyledMessage -Type 'Success' -Text "UniGet UI installato correttamente."
                try {
                    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
                    if (Get-ItemProperty -Path $regPath -Name 'WingetUI' -ErrorAction SilentlyContinue) {
                        Remove-ItemProperty -Path $regPath -Name 'WingetUI' -ErrorAction SilentlyContinue *>$null
                        Write-StyledMessage -Type 'Success' -Text "Avvio automatico UniGet UI disabilitato."
                    }
                }
                catch { }
                return $true
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "Installazione UniGet UI terminata con codice: $($processResult.ExitCode)."
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante installazione UniGet UI: $($_.Exception.Message)."
            return $false
        }
    }
    function Invoke-WithConsoleRedirection {
        param([scriptblock]$Action)
        if (-not ('WinReinstallStore.NativeConsole' -as [type])) {
            Add-Type -Namespace 'WinReinstallStore' -Name 'NativeConsole' -MemberDefinition @'
                [DllImport("kernel32.dll")] public static extern bool SetStdHandle(int nStdHandle, IntPtr hHandle);
                [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
                [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
                public static extern IntPtr CreateFileW(
                    string lpFileName, uint dwDesiredAccess, uint dwShareMode,
                    IntPtr lpSecurityAttributes, uint dwCreationDisposition,
                    uint dwFlagsAndAttributes, IntPtr hTemplateFile);
                [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr hObject);
'@
        }
        $STD_OUTPUT = -11
        $STD_ERROR = -12
        $STD_INPUT = -10
        $INVALID_HANDLE_VALUE = [IntPtr]::new(-1)
        $hOrigOut = $null
        $hOrigErr = $null
        $hOrigIn = $null
        $hNullOut = $null
        $hNullIn = $null
        try {
            $hOrigOut = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_OUTPUT)
            $hOrigErr = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_ERROR)
            $hOrigIn = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_INPUT)
        }
        catch {
            return & $Action
        }
        if ($hOrigOut -eq $INVALID_HANDLE_VALUE -or $hOrigOut -eq [IntPtr]::Zero -or
            $hOrigErr -eq $INVALID_HANDLE_VALUE -or $hOrigErr -eq [IntPtr]::Zero) {
            return & $Action
        }
        try {
            $hNullOut = [WinReinstallStore.NativeConsole]::CreateFileW(
                'NUL', 0x40000000, 3, [IntPtr]::Zero, 3, 0x80, [IntPtr]::Zero)
            $hNullIn = [WinReinstallStore.NativeConsole]::CreateFileW(
                'NUL', 0x80000000, 3, [IntPtr]::Zero, 3, 0x80, [IntPtr]::Zero)
        }
        catch {
            return & $Action
        }
        $canRedirect = (
            $hNullOut -ne $INVALID_HANDLE_VALUE -and $hNullOut -ne [IntPtr]::Zero -and
            $hOrigOut -ne $INVALID_HANDLE_VALUE -and $hOrigOut -ne [IntPtr]::Zero -and
            $hOrigErr -ne $INVALID_HANDLE_VALUE -and $hOrigErr -ne [IntPtr]::Zero
        )
        if (-not $canRedirect) {
            return & $Action
        }
        $handlesRedirected = $false
        try {
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_OUTPUT, $hNullOut) | Out-Null
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_ERROR, $hNullOut) | Out-Null
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_INPUT, $hNullIn) | Out-Null
            $handlesRedirected = $true
            $env:POWERSHELL_TELEMETRY_OPTOUT = '1'
            $ProgressPreference = 'SilentlyContinue'
            return & $Action
        }
        finally {
            if ($handlesRedirected) {
                try {
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_OUTPUT, $hOrigOut) | Out-Null
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_ERROR, $hOrigErr) | Out-Null
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_INPUT, $hOrigIn) | Out-Null
                }
                catch { }
            }
            if ($hNullOut -and $hNullOut -ne $INVALID_HANDLE_VALUE -and $hNullOut -ne [IntPtr]::Zero) {
                try { [WinReinstallStore.NativeConsole]::CloseHandle($hNullOut) | Out-Null } catch { }
            }
            if ($hNullIn -and $hNullIn -ne $INVALID_HANDLE_VALUE -and $hNullIn -ne [IntPtr]::Zero) {
                try { [WinReinstallStore.NativeConsole]::CloseHandle($hNullIn) | Out-Null } catch { }
            }
        }
    }
    try {
        Write-StyledMessage -Type 'Progress' -Text "Avvio reinstallazione Store & Winget."
        $wingetResult = $false
        try {
            $global:ProgressPreference = 'SilentlyContinue'
            $wingetResult = Invoke-WithConsoleRedirection -Action { Reset-Winget -Force }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore imprevisto durante Reset-Winget: $($_.Exception.Message)."
            Write-ToolkitLog -Level ERROR -Message "Reset-Winget eccezione non gestita: $($_.Exception.Message)"
        }
        finally {
            $global:ProgressPreference = $savedProgressPref
        }
        if ($wingetResult) {
            Write-StyledMessage -Type 'Success' -Text "Winget ripristinato e operativo."
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "❌ Ripristino Winget fallito."
        }
        $storeResult = Install-MicrosoftStore
        $unigetResult = Install-UniGetUI
        if ($storeResult) {
            Write-StyledMessage -Type 'Success' -Text "Microsoft Store ripristinato correttamente."
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "❌ Microsoft Store non ripristinato."
        }
        if ($unigetResult) {
            Write-StyledMessage -Type 'Success' -Text "UniGet UI installato."
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text "⚠️ UniGet UI richiedere verifica manuale."
        }
        Write-StyledMessage -Type 'Success' -Text "🎉 Operazione completata."
    }
    finally {
        $ProgressPreference = $savedProgressPref
    }
    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
    }
    else {
        if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio in") {
            Restart-Computer -Force
        }
    }
}
function WinBackupDriver {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 10,
        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitLog -ToolName "WinBackupDriver"
    Show-Header -SubTitle "Driver Backup Toolkit"
    $Host.UI.RawUI.WindowTitle = "Driver Backup Toolkit By MagnetarMan"
    $timeout = 86400
    $script:BackupConfig = @{
        DateTime    = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        BackupDir   = $AppConfig.Paths.DriverBackupTemp
        ArchiveName = "DriverBackup"
        DesktopPath = $AppConfig.Paths.Desktop
        TempPath    = $AppConfig.Paths.TempFolder
        LogsDir     = $AppConfig.Paths.DriverBackupLogs
    }
    $script:FinalArchivePath = "$($script:BackupConfig.DesktopPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).7z"
    function Test-AdministratorPrivilege {
        $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    function Initialize-BackupEnvironment {
        Write-StyledMessage Info "🗂️ Inizializzazione ambiente backup."
        try {
            if (Test-Path $script:BackupConfig.BackupDir) {
                Write-StyledMessage Warning "Rimozione backup precedenti."
                Remove-Item $script:BackupConfig.BackupDir -Recurse -Force -ErrorAction Stop | Out-Null
            }
            New-Item -ItemType Directory -Path $script:BackupConfig.BackupDir -Force | Out-Null
            New-Item -ItemType Directory -Path $script:BackupConfig.LogsDir -Force | Out-Null
            Write-StyledMessage Success "Directory backup e log create."
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore inizializzazione ambiente: $_"
            return $false
        }
    }
    function Export-SystemDrivers {
        Write-StyledMessage Info "💾 Avvio esportazione driver di sistema."
        $outFile = "$($script:BackupConfig.LogsDir)\dism_$($script:BackupConfig.DateTime).log"
        $errFile = "$($script:BackupConfig.LogsDir)\dism_err_$($script:BackupConfig.DateTime).log"
        try {
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
            } -TimeoutSeconds $timeout -UpdateInterval 1000
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
                Write-StyledMessage Warning "Nessun driver di terze parti trovato da esportare."
                Write-StyledMessage Info "💡 I driver integrati di Windows non vengono esportati."
                return $true
            }
            $totalSize = ($exportedDrivers | Measure-Object -Property Length -Sum).Sum
            $totalSizeMB = [Math]::Round($totalSize / 1MB, 2)
            Write-StyledMessage Success "Esportazione completata: $($exportedDrivers.Count) driver trovati ($totalSizeMB MB)."
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
            Write-StyledMessage Success "7-Zip portable già presente."
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
                            Write-StyledMessage Success "7-Zip portable scaricato e verificato."
                            return $executablePath
                        }
                    }
                    Write-StyledMessage Warning "File scaricato non valido (Dimensione: $fileSize bytes)."
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
        Write-StyledMessage Error "Impossibile scaricare 7-Zip da tutte le fonti."
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
        Write-StyledMessage Info "📦 Preparazione compressione archivio."
        $backupFiles = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
        if (-not $backupFiles) {
            Write-StyledMessage Warning "Nessun file da comprimere nella directory backup."
            return $null
        }
        $totalSizeMB = [Math]::Round(($backupFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-StyledMessage Info "Dimensione totale: $totalSizeMB MB"
        $archivePath = "$($script:BackupConfig.TempPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).7z"
        $compressionArgs = @('a', '-t7z', '-mx=6', '-mmt=on', "`"$archivePath`"", "`"$($script:BackupConfig.BackupDir)\*`"")
        $stdOutputPath = "$($script:BackupConfig.LogsDir)\7zip_$($script:BackupConfig.DateTime).log"
        $stdErrorPath = "$($script:BackupConfig.LogsDir)\7zip_err_$($script:BackupConfig.DateTime).log"
        try {
            Write-StyledMessage Info "🚀 Compressione con 7-Zip."
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
            } -TimeoutSeconds 800 -UpdateInterval 1000
            if ($result.TimedOut) {
                throw "Timeout raggiunto durante la compressione."
            }
            if ($result.ExitCode -eq 0 -and (Test-Path $archivePath)) {
                $compressedSizeMB = [Math]::Round((Get-Item $archivePath).Length / 1MB, 2)
                $compressionRatio = [Math]::Round((1 - $compressedSizeMB / $totalSizeMB) * 100, 1)
                Write-StyledMessage Success "Compressione completata: $compressedSizeMB MB (Riduzione: $compressionRatio%)."
                return $archivePath
            }
            else {
                $errorDetails = if (Test-Path $stdErrorPath) {
                    $errorContent = Get-Content $stdErrorPath -ErrorAction SilentlyContinue
                    if ($errorContent) { $errorContent -join '; ' } else { "Log errori vuoto." }
                }
                else { "File di log errori non trovato." }
                Write-StyledMessage Error "Compressione fallita (ExitCode: $($result.ExitCode)). Dettagli: $errorDetails"
                return $null
            }
        }
        finally {
        }
    }
    function Move-ArchiveToDesktop {
        param([string]$ArchivePath)
        if ([string]::IsNullOrWhiteSpace($ArchivePath) -or -not (Test-Path $ArchivePath)) {
            throw "Percorso archivio non valido: $ArchivePath"
        }
        Write-StyledMessage Info "📂 Spostamento archivio su desktop."
        try {
            if (-not (Test-Path $script:BackupConfig.DesktopPath)) {
                throw "Directory desktop non accessibile: $($script:BackupConfig.DesktopPath)"
            }
            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage Warning "Rimozione archivio precedente."
                Remove-Item $script:FinalArchivePath -Force -ErrorAction Stop
            }
            Copy-Item -Path $ArchivePath -Destination $script:FinalArchivePath -Force -ErrorAction Stop
            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage Success "Archivio salvato sul desktop."
                Write-StyledMessage Info "Posizione: $script:FinalArchivePath"
                return $true
            }
            throw "Copia archivio fallita."
        }
        catch {
            Write-StyledMessage Error "Errore spostamento archivio: $_"
            return $false
        }
    }
    try {
        if (-not (Test-AdministratorPrivilege)) {
            Write-StyledMessage Error "❌ Privilegi amministratore richiesti."
            Write-StyledMessage Info "💡 Riavvia PowerShell come Amministratore."
            Read-Host "`nPremi INVIO per uscire"
            return
        }
        Write-StyledMessage Info "🚀 Inizializzazione sistema."
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
                            Write-StyledMessage Info "💾 Utilizzabile per reinstallare tutti i driver."
                            Write-StyledMessage Info "🔧 Senza doverli riscaricare singolarmente."
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-StyledMessage Error "Errore critico durante backup: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Controlla i log per dettagli tecnici."
        Write-ToolkitLog -Level ERROR -Message "Errore critico in WinBackupDriver" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage Info "🧹 Pulizia ambiente temporaneo."
        if (Test-Path $script:BackupConfig.BackupDir) {
            Remove-Item $script:BackupConfig.BackupDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-ToolkitLog -Level INFO -Message "WinBackupDriver sessione terminata."
        Write-StyledMessage Success "🎯 Driver Backup Toolkit terminato."
    }
}
function WinDriverInstall {}
function OfficeToolkit {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitLog -ToolName "OfficeToolkit"
    Show-Header -SubTitle "Office Toolkit"
    $Host.UI.RawUI.WindowTitle = "Office Toolkit By MagnetarMan"
    $tempDir = $AppConfig.Paths.OfficeTemp
    function Invoke-SilentRemoval {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,
            [switch]$Recurse
        )
        if (-not (Test-Path $Path)) {
            return $false
        }
        try {
            $removeParams = @{
                Path        = $Path
                Force       = $true
                ErrorAction = 'SilentlyContinue'
            }
            if ($Recurse) {
                $removeParams.Add('Recurse', $Recurse)
            }
            Remove-Item @removeParams *>$null
            Clear-ProgressLine
            return $true
        } catch {
            return $false
        }
    }
    function Apply-OfficePostConfig {
        Write-StyledMessage -Type 'Info' -Text "⚙️ Configurazione post-installazione/riparazione Office."
        $telemetryKeys = @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "disconnectedstate"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "usercontentdisabled"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "downloadcontentdisabled"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 }
        )
        foreach ($reg in $telemetryKeys) {
            if (-not (Test-Path $reg.Path)) {
                $null = New-Item -Path $reg.Path -Force
            }
            $regParams = @{
                Path  = $reg.Path
                Name  = $reg.Name
                Value = $reg.Value
                Type  = 'DWord'
                Force = $true
            }
            Set-ItemProperty @regParams
        }
        $regPathFeedback = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"
        if (-not (Test-Path $regPathFeedback)) {
            $null = New-Item $regPathFeedback -Force
        }
        $feedbackParams = @{
            Path  = $regPathFeedback
            Name  = "ShownOptIn"
            Value = 1
            Type  = 'DWord'
            Force = $true
        }
        Set-ItemProperty @feedbackParams
        Write-StyledMessage -Type 'Success' -Text "✅ Telemetria e Privacy Office disabilitate in modo profondo."
    }
    function Get-UserConfirmation {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Message,
            [ValidateSet('Y', 'N')]
            [string]$DefaultChoice = 'N'
        )
        do {
            $response = (Read-Host "$Message [Y/N]").Trim().ToUpper()
            if ($response -eq 'N') {
                Write-StyledMessage -Type 'Warning' -Text "Inserire Y per confermare."
            } elseif ($response -ne 'Y') {
                Write-StyledMessage -Type 'Error' -Text "Input non valido."
            }
        } while ($response -ne 'Y')
        return $response
    }
    function Get-WindowsVersion {
        try {
            $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
            $buildNumber = [int]$osInfo.BuildNumber
            return $buildNumber -ge 22631 ? "Windows11_23H2_Plus" : ($buildNumber -ge 22000 ? "Windows11_22H2_Or_Older" : "Windows10_Or_Older")
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile rilevare versione Windows: $_"
            return "Unknown"
        }
    }
    function Stop-OfficeProcesses {
        $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
        $closed = 0
        Write-StyledMessage -Type 'Info' -Text "📋 Chiusura processi Office."
        foreach ($processName in $processes) {
            $runningProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($runningProcesses) {
                try {
                    $runningProcesses | Stop-Process -Force -ErrorAction Stop
                    $closed++
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Impossibile chiudere: $processName."
                }
            }
        }
        if ($closed -gt 0) {
            Write-StyledMessage -Type 'Success' -Text "$closed processi Office chiusi."
        }
    }
    function Invoke-DownloadFile([string]$Url, [string]$OutputPath, [string]$Description) {
        try {
            Write-StyledMessage -Type 'Info' -Text "📥 Download $Description."
        $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $OutputPath)
            $webClient.Dispose()
            $success = (Test-Path $OutputPath)
            Write-StyledMessage -Type ($success ? 'Success' : 'Error') -Text ($success ? "Download completato: $Description" : "File non trovato dopo download: $Description.")
            return $success
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore download $Description`: $_"
            return $false
        }
    }
    function Start-OfficeInstallation {
        Write-StyledMessage -Type 'Info' -Text "🏢 Avvio installazione Office Basic."
        try {
            if (-not (Test-Path $tempDir)) {
                $null = New-Item -ItemType Directory -Path $tempDir -Force
            }
            $setupPath = Join-Path $tempDir 'Setup.exe'
            $configPath = Join-Path $tempDir 'Basic.xml'
            $downloads = @(
                @{ Url = $AppConfig.URLs.OfficeSetup; Path = $setupPath; Name = 'Setup Office' },
                @{ Url = $AppConfig.URLs.OfficeBasicConfig; Path = $configPath; Name = 'Configurazione Basic' }
            )
            foreach ($download in $downloads) {
                if (-not (Invoke-DownloadFile $download.Url $download.Path $download.Name)) {
                    return $false
                }
            }
            Write-StyledMessage -Type 'Info' -Text "🚀 Avvio processo installazione."
            $arguments = "/configure `"$configPath`""
            $processTimeoutSeconds = 86400
            $result = Invoke-WithSpinner -Activity "Installazione Office Basic" -Process -Action {
                $procParams = @{
                    FilePath         = $setupPath
                    ArgumentList     = $arguments
                    WorkingDirectory = $tempDir
                    PassThru         = $true
                    WindowStyle      = 'Hidden'
                    ErrorAction      = 'Stop'
                }
                Start-Process @procParams
            } -TimeoutSeconds $processTimeoutSeconds -UpdateInterval 1000
            if (-not $result.Success) {
                Write-StyledMessage -Type 'Error' -Text "Installazione fallita o scaduta (fase di setup iniziale)."
                return $false
            }
            Apply-OfficePostConfig
            Write-StyledMessage -Type 'Success' -Text "Installazione completata."
            Write-StyledMessage -Type 'Info' -Text "Riavvio non necessario."
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante installazione Office: $($_.Exception.Message)"
            return $false
        }
        finally {
            Invoke-SilentRemoval -Path $tempDir -Recurse
        }
    }
    function Start-OfficeRepair {
        Write-StyledMessage -Type 'Info' -Text "🔧 Avvio riparazione Office."
        Stop-OfficeProcesses
        Write-StyledMessage -Type 'Info' -Text "🧹 Pulizia cache Office."
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
            Write-StyledMessage -Type 'Success' -Text "$cleanedCount cache eliminate."
        }
        $officeClient = (Test-Path "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe") ? "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe" : "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
        if (-not (Test-Path $officeClient)) {
            Write-StyledMessage -Type 'Error' -Text "OfficeClickToRun.exe non trovato. Office potrebbe non essere installato."
            return $false
        }
        try {
            $processTimeoutSeconds = 86400
            Write-StyledMessage -Type 'Info' -Text "🔧 Avvio riparazione rapida (offline)."
            $argumentsQuick = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=QuickRepair DisplayLevel=True"
            $resultQuick = Invoke-WithSpinner -Activity "Riparazione Rapida Office (Offline)" -Process -Action {
                $procParams = @{
                    FilePath     = $officeClient
                    ArgumentList = $argumentsQuick
                    PassThru     = $true
                    ErrorAction  = 'Stop'
                }
                return Start-Process @procParams
            } -TimeoutSeconds $processTimeoutSeconds -UpdateInterval 1000
            Apply-OfficePostConfig
            Write-StyledMessage -Type 'Success' -Text "🎉 Riparazione Office completata!"
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante riparazione Office: $($_.Exception.Message)."
            try {
                Write-StyledMessage -Type 'Info' -Text "🌐 Tentativo riparazione completa (online) come fallback."
                $processTimeoutSeconds = 86400
                $argumentsFull = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True"
                $resultFull = Invoke-WithSpinner -Activity "Riparazione Completa Office (Online)" -Process -Action {
                    $procParams = @{
                        FilePath     = $officeClient
                        ArgumentList = $argumentsFull
                        PassThru     = $true
                        ErrorAction  = 'Stop'
                    }
                    return Start-Process @procParams
                } -TimeoutSeconds $processTimeoutSeconds -UpdateInterval 1000
                Apply-OfficePostConfig
                Write-StyledMessage -Type 'Success' -Text "🎉 Riparazione Office completata!"
                return $true
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Errore anche durante riparazione online: $($_.Exception.Message)."
                return $false
            }
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
        Write-StyledMessage -Type 'Info' -Text "🔧 Avvio rimozione diretta Office."
        try {
            Write-StyledMessage -Type 'Info' -Text "📋 Ricerca installazioni Office."
            $officePackages = Get-Package -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*Microsoft Office*" -or $_.Name -like "*Microsoft 365*" -or $_.Name -like "*Office*" }
            if ($officePackages) {
                Write-StyledMessage -Type 'Info' -Text "Trovati $($officePackages.Count) pacchetti Office."
                foreach ($package in $officePackages) {
                    try {
                        $null = Uninstall-Package -Name $package.Name -Force -ErrorAction Stop
                        Write-StyledMessage -Type 'Success' -Text "Rimosso: $($package.Name)."
                    }
                    catch {}
                }
            }
            Write-StyledMessage -Type 'Info' -Text "🔍 Ricerca nel registro."
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
                                $spinnerActivity = "Rimozione: $($item.DisplayName)"
                                $null = Invoke-WithSpinner -Activity $spinnerActivity -Process -Action {
                                    $procParams = @{
                                        FilePath     = 'msiexec.exe'
                                        ArgumentList = @('/x', $productCode, '/qn', '/norestart')
                                        PassThru     = $true
                                        WindowStyle  = 'Hidden'
                                        ErrorAction  = 'Stop'
                                    }
                                    Start-Process @procParams
                                } -TimeoutSeconds 1800 -UpdateInterval 1000
                            }
                            catch {}
                        }
                    }
                }
                catch {}
            }
            Write-StyledMessage -Type 'Info' -Text "🛑 Arresto servizi Office."
            $officeServices = @('ClickToRunSvc', 'OfficeSvc', 'OSE')
            $stoppedServices = 0
            foreach ($serviceName in $officeServices) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    try {
                        Stop-Service -Name $serviceName -Force -ErrorAction Stop
                        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
                        Write-StyledMessage -Type 'Success' -Text "Servizio arrestato: $serviceName."
                        $stoppedServices++
                    }
                    catch {}
                }
            }
            Write-StyledMessage -Type 'Info' -Text "🧹 Pulizia cartelle Office."
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
                Write-StyledMessage -Type 'Success' -Text "$($folderResult.Count) cartelle Office rimosse."
            }
            if ($folderResult.Failed.Count -gt 0) {
                Write-StyledMessage -Type 'Warning' -Text "Impossibile rimuovere $($folderResult.Failed.Count) cartelle (potrebbero essere in uso)."
            }
            Write-StyledMessage -Type 'Info' -Text "🔧 Pulizia registro Office."
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
                Write-StyledMessage -Type 'Success' -Text "$($regResult.Count) chiavi registro Office rimosse."
            }
            Write-StyledMessage -Type 'Info' -Text "📅 Pulizia attività pianificate."
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
                    Write-StyledMessage -Type 'Success' -Text "$tasksRemoved attività Office rimosse."
                }
            }
            catch {}
            Write-StyledMessage -Type 'Info' -Text "🖥️ Rimozione collegamenti Office."
            $officeShortcuts = @(
                "Microsoft Word*.lnk", "Microsoft Excel*.lnk", "Microsoft PowerPoint*.lnk",
                "Microsoft Outlook*.lnk", "Microsoft OneNote*.lnk", "Microsoft Access*.lnk",
                "Office*.lnk", "Word*.lnk", "Excel*.lnk", "PowerPoint*.lnk", "Outlook*.lnk"
            )
            $desktopPaths = @(
                $AppConfig.Paths.Desktop,
                "$env:PUBLIC\Desktop",
                "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs"
            )
            $shortcutsRemoved = 0
            foreach ($desktopPath in $desktopPaths) {
                if (Test-Path $desktopPath) {
                    foreach ($shortcut in $officeShortcuts) {
                        $gciParams = @{
                            Path        = $desktopPath
                            Filter      = $shortcut
                            Recurse     = $true
                            ErrorAction = 'SilentlyContinue'
                        }
                        $shortcutFiles = Get-ChildItem @gciParams
                        foreach ($file in $shortcutFiles) {
                            if (Invoke-SilentRemoval -Path $file.FullName) {
                                $shortcutsRemoved++
                            }
                        }
                    }
                }
            }
            if ($shortcutsRemoved -gt 0) {
                Write-StyledMessage -Type 'Success' -Text "$shortcutsRemoved collegamenti Office rimossi."
            }
            Write-StyledMessage -Type 'Info' -Text "💽 Pulizia residui Office."
            $additionalPaths = @(
                "$env:LOCALAPPDATA\Microsoft\OneDrive",
                "$env:APPDATA\Microsoft\OneDrive",
                "$env:TEMP\Office*",
                "$env:TEMP\MSO*"
            )
            $residualsResult = Remove-ItemsSilently -Paths $additionalPaths -ItemType "residuo"
            Write-StyledMessage -Type 'Success' -Text "✅ Rimozione diretta completata."
            Write-StyledMessage -Type 'Info' -Text "📊 Riepilogo: $($folderResult.Count) cartelle, $($regResult.Count) chiavi registro, $shortcutsRemoved collegamenti, $tasksRemoved attività rimosse."
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante rimozione diretta Office: $($_.Exception.Message)."
            return $false
        }
    }
    function Start-OfficeUninstallWithSaRA {
        try {
            if (-not (Test-Path $tempDir)) {
                $null = New-Item -ItemType Directory -Path $tempDir -Force
            }
            $saraUrl = $AppConfig.URLs.SaRAInstaller
            $saraZipPath = Join-Path $tempDir 'SaRA.zip'
            if (-not (Invoke-DownloadFile $saraUrl $saraZipPath 'Microsoft SaRA')) {
                return $false
            }
            Write-StyledMessage -Type 'Info' -Text "📦 Estrazione SaRA."
            try {
                Expand-Archive -Path $saraZipPath -DestinationPath $tempDir -Force
                Write-StyledMessage -Type 'Success' -Text "Estrazione completata."
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Errore durante estrazione archivio SaRA: $($_.Exception.Message)."
                return $false
            }
            $gciParamsExe = @{
                Path        = $tempDir
                Filter      = "SaRACmd.exe"
                Recurse     = $true
                ErrorAction = 'SilentlyContinue'
            }
            $saraExe = Get-ChildItem @gciParamsExe | Select-Object -First 1
            if (-not $saraExe) {
                Write-StyledMessage -Type 'Error' -Text "SaRACmd.exe non trovato."
                return $false
            }
            Write-StyledMessage -Type 'Info' -Text "🚀 Rimozione tramite SaRA (backup locale)."
            Write-StyledMessage -Type 'Warning' -Text "⏰ Questa operazione può richiedere alcuni minuti."
            $arguments = '-S OfficeScrubScenario -AcceptEula -OfficeVersion All'
            try {
                $processTimeoutSeconds = 86400
                $result = Invoke-WithSpinner -Activity "Rimozione Office tramite SaRA" -Process -Action {
                    $procParams = @{
                        FilePath     = $saraExe.FullName
                        ArgumentList = $arguments
                        Verb         = 'RunAs'
                        PassThru     = $true
                        ErrorAction  = 'Stop'
                    }
                    Start-Process @procParams
                } -TimeoutSeconds $processTimeoutSeconds -UpdateInterval 1000
                if ($result.ExitCode -eq 0) {
                    Write-StyledMessage -Type 'Success' -Text "✅ SaRA completato con successo."
                    return $true
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "SaRA terminato con codice: $($result.ExitCode)."
                    Write-StyledMessage -Type 'Info' -Text "💡 Tentativo metodo alternativo."
                    return Remove-OfficeDirectly
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore durante esecuzione SaRA: $($_.Exception.Message)."
                Write-StyledMessage -Type 'Info' -Text "💡 Passaggio a metodo alternativo."
                return Remove-OfficeDirectly
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore durante processo SaRA: $($_.Exception.Message)."
            return $false
        }
        finally {
            Invoke-SilentRemoval -Path $tempDir -Recurse
        }
    }
    function Start-OfficeUninstall {
        Write-StyledMessage -Type 'Warning' -Text "🗑️ Avvio rimozione completa Microsoft Office."
        Stop-OfficeProcesses
        Write-StyledMessage -Type 'Info' -Text "🔍 Rilevamento versione Windows."
        $windowsVersion = Get-WindowsVersion
        Write-StyledMessage -Type 'Info' -Text "🎯 Versione rilevata: $windowsVersion."
        $success = $false
        switch ($windowsVersion) {
            'Windows11_23H2_Plus' {
                Write-StyledMessage -Type 'Info' -Text "🚀 Utilizzo metodo SaRA per Windows 11 23H2+."
                $success = Start-OfficeUninstallWithSaRA
            }
            default {
                Write-StyledMessage -Type 'Info' -Text "⚡ Utilizzo rimozione diretta per Windows 11 22H2 o precedenti."
                $success = Remove-OfficeDirectly
            }
        }
        Write-Progress -Activity "Rimozione" -Completed -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Host ""
        if ($success) {
            Write-StyledMessage -Type 'Success' -Text "🎉 Rimozione Office completata!"
            return $true
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Rimozione non completata."
            Write-StyledMessage -Type 'Info' -Text "💡 Puoi provare un metodo alternativo o rimozione manuale."
            return $false
        }
    }
    Write-StyledMessage -Type 'Progress' -Text "⏳ Inizializzazione sistema."
    Start-Sleep 2
    Write-StyledMessage -Type 'Success' -Text "✅ Sistema pronto."
    $needsReboot = $false
    $lastOperation = ''
    try {
        do {
            Write-StyledMessage -Type 'Info' -Text "🎯 Seleziona un'opzione:"
            Write-StyledMessage -Type 'Info' -Text "  [1]  🏢 Installazione Office (Basic Version)"
            Write-StyledMessage -Type 'Info' -Text "  [2]  🔧 Ripara Office"
            Write-StyledMessage -Type 'Info' -Text "  [3]  🗑️ Rimozione completa Office"
            Write-StyledMessage -Type 'Info' -Text "  [0]  ❌ Esci"
            $choice = Read-Host 'Scelta [0-3]'
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
                    Write-StyledMessage -Type 'Info' -Text "👋 Uscita dal toolkit."
                    break
                }
                default {
                    Write-StyledMessage -Type 'Warning' -Text "Opzione non valida. Seleziona 0-3."
                    continue
                }
            }
            if ($choice -in @('1', '2', '3')) {
                if ($success) {
                    if ($choice -ne '1') {
                        Write-StyledMessage -Type 'Success' -Text "🎉 $operation completata!"
                        $needsReboot = $true
                        $lastOperation = $operation
                        Write-StyledMessage -Type 'Info' -Text "💡 Il sistema verrà riavviato automaticamente alla fine del processo."
                    }
                }
                else {
                    Write-StyledMessage -Type 'Error' -Text "$operation non riuscita."
                    Write-StyledMessage -Type 'Info' -Text "💡 Controlla i log per dettagli o contatta il supporto."
                }
                $ProgressPreference = 'SilentlyContinue'
                Write-Host ""
                Write-StyledMessage -Type 'Info' -Text ('─' * 50)
                Write-Host ""
                $ProgressPreference = 'Continue'
            }
        } while ($choice -ne '0')
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore critico durante esecuzione OfficeToolkit: $($_.Exception.Message)."
        Write-ToolkitLog -Level ERROR -Message "Errore critico in OfficeToolkit" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text "🧹 Pulizia finale."
        Invoke-SilentRemoval -Path $tempDir -Recurse
        Write-StyledMessage -Type 'Success' -Text "🎯 Office Toolkit terminato."
        Write-ToolkitLog -Level INFO -Message "OfficeToolkit sessione terminata."
    }
    if ($needsReboot) {
        if ($SuppressIndividualReboot) {
            $Global:NeedsFinalReboot = $true
            Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
        }
        else {
            if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "$lastOperation completata") {
                Restart-Computer -Force
            }
        }
    }
}
function WinCleaner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 300)]
        [int]$CountdownSeconds = 30,
        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )
    $global:WinCleanerLog = @()
    function Add-CleanerLog {
        param(
            [Parameter(Mandatory = $true, Position = 0)]
            [ValidateSet('Success', 'Info', 'Warning', 'Error', 'Question')]
            [string]$Type,
            [Parameter(Mandatory = $true, Position = 1)]
            [string]$Text
        )
        Clear-ProgressLine
        $logEntry = @{
            Timestamp = Get-Date -Format "HH:mm:ss"
            Type      = $Type
            Text      = $Text
        }
        $global:WinCleanerLog += $logEntry
        Write-StyledMessage -Type $Type -Text $Text
    }
    Start-ToolkitLog -ToolName "WinCleaner"
    Show-Header -SubTitle "Cleaner Toolkit"
    $Host.UI.RawUI.WindowTitle = "Cleaner Toolkit By MagnetarMan"
    $timeout = 86400
    $ProgressPreference = 'Continue'
    $VitalExclusions = @(
        "$env:LOCALAPPDATA\WinToolkit"
    )
    function Test-VitalExclusion {
        param([string]$Path)
        if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
        $fullPath = $Path -replace '"', ''
        try {
            if (-not [System.IO.Path]::IsPathRooted($fullPath)) {
                $fullPath = Join-Path (Get-Location) $fullPath
            }
            foreach ($excluded in $VitalExclusions) {
                if ($fullPath -like "$excluded*" -or $fullPath -eq $excluded) {
                    Add-CleanerLog -Type 'Info' -Text "🛡️ PROTEZIONE VITALE ATTIVATA: $fullPath"
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
            [int]$TimeoutSeconds = 86400,
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
        if ($Hidden) { $processParams.WindowStyle = 'Hidden' } else { $processParams.NoNewWindow = $true }
        $proc = Start-Process @processParams
        $result = Invoke-WithSpinner -Activity $Activity -Process -Action { $proc } -TimeoutSeconds $TimeoutSeconds -UpdateInterval 500
        return $result
    }
    function Invoke-CommandAction {
        param($Rule)
        Clear-ProgressLine
        Write-StyledMessage -Type 'Info' -Text "🚀 Esecuzione comando: $($Rule.Name)."
        try {
            $timeoutCommands = @("DISM.exe", "cleanmgr.exe")
            if ($Rule.Command -in $timeoutCommands) {
                $result = Start-ProcessWithTimeout -FilePath $Rule.Command -ArgumentList $Rule.Args -TimeoutSeconds $timeout -Activity $Rule.Name -Hidden
                if ($result.TimedOut) { Write-StyledMessage -Type 'Warning' -Text "Comando timeout dopo 24 ore."; return $true }
                if ($result.ExitCode -eq -2146498554 -or $result.ExitCode -eq 0x800F0818) {
                    Add-CleanerLog -Type 'Warning' -Text "ATTENZIONE! - Stai effettuando la pulizia con Windows Update in corso. Aggiorna il sistema e riprova per eseguire la pulizia completa"
                    return $false
                }
                Add-CleanerLog -Type ($result.ExitCode -eq 0 ? 'Info' : 'Warning') -Text ($result.ExitCode -eq 0 ? "Comando completato." : "Comando completato con codice $($result.ExitCode)")
                return $true
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
                if ($proc.ExitCode -ne 0) {
                    Add-CleanerLog -Type 'Warning' -Text "Comando completato con codice $($proc.ExitCode)"
                }
                return $true
            }
        }
        catch {
            Add-CleanerLog -Type 'Error' -Text "Errore comando: $_"
            return $false
        }
    }
    function Invoke-ServiceAction {
        param($Rule)
        $svcName = $Rule.ServiceName
        $action = $Rule.Action
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if (-not $svc) { return $true }
            if ($action -eq 'Stop' -and $svc.Status -eq 'Running') {
                Add-CleanerLog -Type 'Info' -Text "⏸️ Arresto servizio $svcName."
                Stop-Service -Name $svcName -Force -ErrorAction Stop | Out-Null
            }
            elseif ($action -eq 'Start' -and $svc.Status -ne 'Running') {
                Add-CleanerLog -Type 'Info' -Text "▶️ Avvio servizio $svcName."
                Start-Service -Name $svcName -ErrorAction Stop | Out-Null
            }
            return $true
        }
        catch {
            Add-CleanerLog -Type 'Warning' -Text "Errore servizio $svcName : $_"
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
                    Add-CleanerLog -Type 'Info' -Text "🔑 Assunzione proprietà per $path."
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
                Add-CleanerLog -Type 'Warning' -Text "Errore rimozione $path : $_"
            }
        }
        if ($count -gt 0) { Write-StyledMessage -Type 'Success' -Text "🗑️ Puliti $count elementi in $($Rule.Name)." }
        return $true
    }
    function Remove-RegistryItem {
        param($Rule)
        $keys = $Rule.Keys
        $recursive = $Rule.Recursive
        $valuesOnly = $Rule.ValuesOnly
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
                    Add-CleanerLog -Type 'Success' -Text "⚙️ Puliti valori in $key"
                }
                else {
                    Remove-Item -Path $key -Recurse:$recursive -Force -ErrorAction Stop
                    Add-CleanerLog -Type 'Success' -Text "🗑️ Rimossa chiave $key"
                }
            }
            catch {
                Add-CleanerLog -Type 'Warning' -Text "Errore registro $key : $_"
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
            Add-CleanerLog -Type 'Success' -Text "⚙️ Impostato $key\$($Rule.ValueName)"
            return $true
        }
        catch { return $false }
    }
    function Invoke-WinCleanerRule {
        param($Rule)
        Clear-ProgressLine
        switch ($Rule.Type) {
            'File' { return Remove-FileItem -Rule $Rule }
            'Registry' { return Remove-RegistryItem -Rule $Rule }
            'RegSet' { return Set-RegistryItem -Rule $Rule }
            'Service' { return Invoke-ServiceAction -Rule $Rule }
            'Command' { return Invoke-CommandAction -Rule $Rule }
            'ScriptBlock' {
                if ($Rule.ScriptBlock) {
                    & $Rule.ScriptBlock
                    return $true
                }
            }
            'Custom' {
                if ($Rule.ScriptBlock) {
                    & $Rule.ScriptBlock
                    return $true
                }
            }
        }
        return $true
    }
    $Rules = @(
        @{ Name = "CleanMgr Config"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "🧹 Configurazione CleanMgr."
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
                $cleanMgrExecutionRule = @{
                    Name    = "Esecuzione CleanMgr con /sagerun:65";
                    Type    = "Command";
                    Command = "cleanmgr.exe";
                    Args    = @("/sagerun:65");
                }
                Invoke-CommandAction -Rule $cleanMgrExecutionRule
            }
        }
        @{ Name = "WinSxS Cleanup"; Type = "Command"; Command = "DISM.exe"; Args = @("/Online", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase") }
        @{ Name = "Minimize DISM"; Type = "RegSet"; Key = "HKLM:\Software\Microsoft\Windows\CurrentVersion\SideBySide\Configuration"; ValueName = "DisableResetbase"; ValueData = 0; ValueType = "DWORD" }
        @{ Name = "Error Reports"; Type = "File"; Paths = @(
                "$env:ProgramData\Microsoft\Windows\WER",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\WER"
            ); FilesOnly = $false
        }
        @{ Name = "Clear Event Logs"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "📜 Pulizia Event Logs."
                $wevtErr = $null
                & wevtutil sl 'Microsoft-Windows-LiveId/Operational' /ca:'O:BAG:SYD:(A;;0x1;;;SY)(A;;0x5;;;BA)(A;;0x1;;;LA)' 2>&1 | Out-String -OutVariable wevtErr | Out-Null
                if ($wevtErr) { Write-ToolkitLog -Level DEBUG -Message "wevtutil sl output: $wevtErr" }
                Get-WinEvent -ListLog * -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    $logName = $_.LogName
                    $clErr = $null
                    Wevtutil.exe cl $logName 2>&1 | Out-String -OutVariable clErr | Out-Null
                    if ($LASTEXITCODE -ne 0 -and $clErr) { Write-ToolkitLog -Level DEBUG -Message "Wevtutil cl [$logName]: $clErr" }
                }
            }
        }
        @{ Name = "Clear Windows Update cache"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "🔄 Pulizia cache di Windows Update."
                $services = @("wuauserv", "bits")
                foreach ($s in $services) {
                    Invoke-ServiceAction -Rule @{ ServiceName = $s; Action = "Stop" }
                }
                $paths = @(
                    "C:\Windows\SoftwareDistribution\Download",
                    "C:\Windows\SoftwareDistribution\DataStore"
                )
                foreach ($p in $paths) {
                    if (Test-Path $p) {
                        try {
                            Add-CleanerLog -Type 'Info' -Text "🗑️ Rimozione: $p"
                            Remove-Item -Path "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text "Impossibile pulire completamente $p"
                        }
                    }
                }
                foreach ($s in $services) {
                    Invoke-ServiceAction -Rule @{ ServiceName = $s; Action = "Start" }
                }
                Add-CleanerLog -Type 'Success' -Text "Windows Update cache cleared."
            }
        }
        @{ Name = "Windows App/Download Cache - User"; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Microsoft\Windows\AppCache",
                "%LOCALAPPDATA%\Microsoft\Windows\Caches"
            ); PerUser = $true; FilesOnly = $true
        }
        @{ Name = "System Restore Points"; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Add-CleanerLog -Type 'Info' -Text "💾 Pulizia punti di ripristino sistema."
                    Add-CleanerLog -Type 'Info' -Text "🗑️ Analisi e pulizia shadow copies (mantieni ultima)."
                    try {
                        $shadows = Get-CimInstance -ClassName Win32_ShadowCopy -ErrorAction Stop | Sort-Object InstallDate -Descending
                        if ($shadows.Count -gt 1) {
                            $toDelete = $shadows | Select-Object -Skip 1
                            $count = $toDelete.Count
                            Add-CleanerLog -Type 'Info' -Text "Rilevate $($shadows.Count) shadow copies. Rimozione di $count vecchie."
                            foreach ($shadow in $toDelete) {
                                Remove-CimInstance -InputObject $shadow -ErrorAction SilentlyContinue
                            }
                            Add-CleanerLog -Type 'Success' -Text "Vecchie shadow copies rimosse. Ultima copia preservata."
                        }
                        elseif ($shadows.Count -eq 1) {
                            Add-CleanerLog -Type 'Info' -Text "Trovata una sola shadow copy. Nessuna rimozione necessaria."
                        }
                        else {
                            Add-CleanerLog -Type 'Info' -Text "Nessuna shadow copy rilevata."
                        }
                    }
                    catch {
                        Add-CleanerLog -Type 'Warning' -Text "Errore gestione shadow copies: $_"
                    }
                    Add-CleanerLog -Type 'Info' -Text "💡 Protezione sistema mantenuta attiva per sicurezza"
                    Add-CleanerLog -Type 'Success' -Text "Pulizia punti di ripristino completata"
                }
                catch {
                    Add-CleanerLog -Type 'Warning' -Text "Errore durante la pulizia punti di ripristino: $($_.Exception.Message)"
                }
            }
        }
        @{ Name = "Cleanup - Windows Prefetch Cache"; Type = "File"; Paths = @("C:\WINDOWS\Prefetch"); FilesOnly = $false }
        @{ Name = "Cleanup - Explorer Thumbnail/Icon Cache"; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\Explorer"); PerUser = $true; FilesOnly = $true; TakeOwnership = $true }
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
                Add-CleanerLog -Type 'Info' -Text "🌐 Pulizia Cache Browser Chromium."
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
                Add-CleanerLog -Type 'Info' -Text "🦊 Pulizia Firefox (Cache & Crashes)."
                $users = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notmatch '^(Public|Default|All Users)$' }
                foreach ($u in $users) {
                    $cleanPaths = @(
                        "$($u.FullName)\AppData\Local\Mozilla\Firefox\Profiles",
                        "$($u.FullName)\AppData\Local\Mozilla\Firefox\Crash Reports"
                    )
                    foreach ($p in $cleanPaths) {
                        if (Test-Path $p) { Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue }
                    }
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
        @{ Name = "System Temp Files"; Type = "File"; Paths = @("C:\WINDOWS\Temp"); FilesOnly = $false }
        @{ Name = "User Temp Files"; Type = "File"; Paths = @(
                "%TEMP%",
                "%USERPROFILE%\AppData\Local\Temp",
                "%USERPROFILE%\AppData\LocalLow\Temp"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Service Profiles Temp"; Type = "File"; Paths = @("%SYSTEMROOT%\ServiceProfiles\LocalService\AppData\Local\Temp"); FilesOnly = $false }
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
        @{ Name = "Search History Files"; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\ConnectedSearch\History"); PerUser = $true }
        @{ Name = "Print Queue (Spooler)"; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Add-CleanerLog -Type 'Info' -Text "🖨️ Pulizia coda di stampa (Spooler)."
                    Add-CleanerLog -Type 'Info' -Text "⏸️ Arresto servizio Spooler."
                    Stop-Service -Name Spooler -Force -ErrorAction Stop | Out-Null
                    Add-CleanerLog -Type 'Info' -Text "Servizio Spooler arrestato."
                    Start-Sleep -Seconds 2
                    $printersPath = 'C:\WINDOWS\System32\spool\PRINTERS'
                    if (Test-Path $printersPath) {
                        $files = Get-ChildItem -Path $printersPath -Force -ErrorAction SilentlyContinue
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        Add-CleanerLog -Type 'Info' -Text "Coda di stampa pulita in $printersPath ($($files.Count) file rimossi)"
                    }
                    Add-CleanerLog -Type 'Info' -Text "▶️ Riavvio servizio Spooler."
                    Start-Service -Name Spooler -ErrorAction Stop | Out-Null
                    Add-CleanerLog -Type 'Info' -Text "Servizio Spooler riavviato."
                    Add-CleanerLog -Type 'Success' -Text "Print Queue Spooler pulito e riavviato con successo."
                }
                catch {
                    Start-Service -Name Spooler -ErrorAction SilentlyContinue
                    Add-CleanerLog -Type 'Warning' -Text "Errore durante la pulizia Spooler: $($_.Exception.Message)"
                }
            }
        }
        @{ Name = "Stop DPS"; Type = "Service"; ServiceName = "DPS"; Action = "Stop" }
        @{ Name = "SRUM Data"; Type = "File"; Paths = @("%SYSTEMROOT%\System32\sru\SRUDB.dat"); FilesOnly = $true; TakeOwnership = $true }
        @{ Name = "Start DPS"; Type = "Service"; ServiceName = "DPS"; Action = "Start" }
        @{ Name = "Listary Index"; Type = "File"; Paths = @("%APPDATA%\Listary\UserData"); PerUser = $true }
        @{ Name = "Flash Player Traces"; Type = "File"; Paths = @("%APPDATA%\Macromedia\Flash Player"); PerUser = $true }
        @{ Name = "Enhanced DiagTrack Management"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "🔄 Gestione migliorata servizio DiagTrack."
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
                        Write-Verbose "Path collision detected at: '$path'. Generating new path."
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
                Add-CleanerLog -Type 'Info' -Text "Verifica stato servizio $serviceName."
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if (-not $service) {
                    Add-CleanerLog -Type 'Warning' -Text "Servizio $serviceName non trovato, skip"
                    return
                }
                if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                    Add-CleanerLog -Type 'Info' -Text "Servizio $serviceName attivo, arresto in corso."
                    try {
                        $service | Stop-Service -Force -ErrorAction Stop
                        $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped, [TimeSpan]::FromSeconds(30))
                        $path = Get-UniqueStateFilePath $serviceName
                        if (New-EmptyFile $path) {
                            Add-CleanerLog -Type 'Success' -Text "Servizio arrestato e stato salvato - riavvio automatico abilitato"
                        }
                        else {
                            Add-CleanerLog -Type 'Warning' -Text "Servizio arrestato - riavvio manuale richiesto"
                        }
                    }
                    catch { Write-StyledMessage -Type 'Warning' -Text "Errore durante arresto servizio: $_" }
                }
                else {
                    Add-CleanerLog -Type 'Info' -Text "Servizio $serviceName non attivo, verifica riavvio."
                    $fileGlob = Get-StateFilePath -BaseName $serviceName -Suffix '*'
                    $stateFiles = Get-ChildItem -Path $fileGlob -ErrorAction SilentlyContinue
                    if ($stateFiles.Count -eq 1) {
                        try {
                            Remove-Item -Path $stateFiles[0].FullName -Force -ErrorAction Stop
                            $service | Start-Service -ErrorAction Stop
                            Add-CleanerLog -Type 'Success' -Text "Servizio $serviceName riavviato con successo"
                        }
                        catch { Write-StyledMessage -Type 'Warning' -Text "Errore durante riavvio servizio: $_" }
                    }
                    elseif ($stateFiles.Count -gt 1) {
                        Add-CleanerLog -Type 'Info' -Text "Multiple state files found, servizio non verrà riavviato automaticamente"
                    }
                    else {
                        Add-CleanerLog -Type 'Info' -Text "Servizio $serviceName non era attivo precedentemente"
                    }
                }
            }
        }
        @{ Name = "Credential Manager"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "🔑 Pulizia Credenziali."
                $cmdkeyErr = $null
                $targets = & cmdkey /list 2>&1 | Tee-Object -Variable cmdkeyErr | Where-Object { $_ -match '^Target:' }
                if ($cmdkeyErr -and $LASTEXITCODE -ne 0) { Write-ToolkitLog -Level DEBUG -Message "cmdkey list error: $cmdkeyErr" }
                $targets | ForEach-Object {
                    $t = $_.Split(':')[1].Trim()
                    $delErr = $null
                    & cmdkey /delete:$t 2>&1 | Tee-Object -Variable delErr | Out-Null
                    if ($delErr -and $LASTEXITCODE -ne 0) { Write-ToolkitLog -Level DEBUG -Message "cmdkey delete [$t] error: $delErr" }
                }
            }
        }
        @{ Name = "Regedit Last Key"; Type = "Registry"; Keys = @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit"); ValuesOnly = $true }
        @{ Name = "Windows.old"; Type = "ScriptBlock"; ScriptBlock = {
                $path = "C:\Windows.old"
                if (Test-Path $path) {
                    Add-CleanerLog -Type 'Info' -Text "🗑️ Rilevata cartella Windows.old. Avvio rimozione sicura con Native CleanMgr."
                    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations"
                    if (-not (Test-Path $regKey)) {
                        Add-CleanerLog -Type 'Warning' -Text "Chiave registro 'Previous Installations' non trovata. Tentativo di esecuzione standard."
                    }
                    else {
                        try {
                            Set-ItemProperty -Path $regKey -Name "StateFlags0066" -Value 2 -Type DWORD -Force -ErrorAction Stop
                            Add-CleanerLog -Type 'Info' -Text "✅ Configurazione CleanMgr attivata per Windows.old (StateFlags0066)."
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text "Impossibile scrivere nel registro per CleanMgr: $_"
                        }
                    }
                    $cleanMgrRule = @{
                        Name    = "Rimozione Windows.old (CleanMgr)";
                        Type    = "Command";
                        Command = "cleanmgr.exe";
                        Args    = @("/sagerun:66");
                    }
                    $result = Invoke-CommandAction -Rule $cleanMgrRule
                    if (Test-Path $path) {
                        Add-CleanerLog -Type 'Info' -Text "ℹ️ La cartella Windows.old potrebbe richiedere un riavvio per la rimozione completa."
                    }
                    else {
                        Add-CleanerLog -Type 'Success' -Text "✅ Windows.old rimosso con successo."
                    }
                }
                else {
                    Add-CleanerLog -Type 'Info' -Text "💭 Nessuna cartella Windows.old rilevata."
                }
            }
        }
        @{ Name = "Empty Recycle Bin"; Type = "Custom"; ScriptBlock = {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                Add-CleanerLog -Type 'Success' -Text "🗑️ Cestino svuotato"
            }
        }
    )
    $totalRules = $Rules.Count
    $currentRuleIndex = 0
    $successCount = 0
    $warningCount = 0
    $errorCount = 0
    foreach ($rule in $Rules) {
        $currentRuleIndex++
        $percent = [math]::Round(($currentRuleIndex / $totalRules) * 100)
        Clear-ProgressLine
        Show-ProgressBar -Activity "Esecuzione regole" -Status "$($rule.Name)" -Percent $percent -Icon '⚙️'
        $result = Invoke-WinCleanerRule -Rule $rule
        Clear-ProgressLine
        if ($result) {
            $successCount++
        }
        else {
            $errorCount++
        }
    }
    Clear-ProgressLine
    Write-Host "`n"
    Write-StyledMessage -Type 'Info' -Text "=================================================="
    Write-StyledMessage -Type 'Info' -Text "               RIEPILOGO OPERAZIONI               "
    Write-StyledMessage -Type 'Info' -Text "=================================================="
    $stats = $global:WinCleanerLog | Group-Object Type
    $sCount = ($stats | Where-Object Name -eq 'Success').Count
    $wCount = ($stats | Where-Object Name -eq 'Warning').Count
    $eCount = ($stats | Where-Object Name -eq 'Error').Count
    Write-StyledMessage -Type 'Success' -Text "Operazioni completate con successo: $sCount."
    if ($wCount -gt 0) { Write-StyledMessage -Type 'Warning' -Text "Avvisi generati: $wCount." }
    if ($eCount -gt 0) { Write-StyledMessage -Type 'Error' -Text "Errori riscontrati: $eCount." }
    Write-StyledMessage -Type 'Info' -Text "--------------------------------------------------"
    Write-StyledMessage -Type 'Info' -Text "Dettaglio Errori e Warning:"
    $problems = $global:WinCleanerLog | Where-Object { $_.Type -in 'Warning', 'Error' }
    if ($problems) {
        foreach ($p in $problems) {
            Write-StyledMessage -Type $p.Type -Text $p.Text
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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,
        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitLog -ToolName "VideoDriverInstall"
    Show-Header -SubTitle "Video Driver Install Toolkit"
    $Host.UI.RawUI.WindowTitle = "Video Driver Install Toolkit By MagnetarMan"
    $GitHubAssetBaseUrl = $AppConfig.URLs.GitHubAssetBaseUrl
    $DriverToolsLocalPath = $AppConfig.Paths.Drivers
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
    function Get-GpuManufacturer {
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
        Write-StyledMessage Info "Configurazione per bloccare download driver da Windows Update."
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
            Write-StyledMessage Error "Errore durante l'impostazione del blocco download driver da Windows Update: $($_.Exception.Message)."
            Write-StyledMessage Warning "Potrebbe essere necessario eseguire lo script come amministratore."
            return
        }
        Write-StyledMessage Info "Aggiornamento dei criteri di gruppo in corso per applicare le modifiche."
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
            Write-StyledMessage Error "Errore durante l'aggiornamento dei criteri di gruppo: $($_.Exception.Message)."
            Write-StyledMessage Warning "Le modifiche ai criteri potrebbero richiedere un riavvio o del tempo per essere applicate."
        }
    }
    function Download-FileWithProgress {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Url,
            [Parameter(Mandatory = $true)]
            [string]$DestinationPath,
            [Parameter(Mandatory = $true)]
            [string]$Description,
            [int]$MaxRetries = 3
        )
        Write-StyledMessage Info "Scaricando $Description."
        $destDir = Split-Path -Path $DestinationPath -Parent
        if (-not (Test-Path $destDir)) {
            try {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            catch {
                Write-StyledMessage Error "Impossibile creare la cartella di destinazione '$destDir': $($_.Exception.Message)."
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
                Write-Progress -Activity "Download $Description" -Status "Inizio download." -PercentComplete 0
                do {
                    $bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)
                    if ($bytesRead -gt 0) {
                        $targetStream.Write($buffer, 0, $bytesRead)
                        $downloadedBytes += $bytesRead
                        $percentComplete = [System.Math]::Round(($downloadedBytes / $totalBytes) * 100, 1)
                        $speed = if ($downloadedBytes -gt 0) { [System.Math]::Round(($downloadedBytes / 1024 / 1024), 2) } else { 0 }
                        $totalSize = [System.Math]::Round(($totalBytes / 1024 / 1024), 2)
                        Write-Progress -Activity "Download $Description" -Status "$speed MB / $totalSize MB" -PercentComplete $percentComplete
                    }
                } while ($bytesRead -gt 0)
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
                Write-StyledMessage Warning "Tentativo $attempt fallito per $Description`: $($_.Exception.Message)."
                if ($attempt -lt $MaxRetries) {
                    Start-Sleep -Seconds 2
                }
            }
        }
        Write-StyledMessage Error "Errore durante il download di $Description dopo $MaxRetries tentativi."
        return $false
    }
    function Handle-InstallVideoDrivers {
        Write-StyledMessage Info "Opzione 1: Avvio installazione driver video."
        $gpuManufacturer = Get-GpuManufacturer
        Write-StyledMessage Info "Rilevata GPU: $gpuManufacturer."
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
        Write-StyledMessage Warning "Opzione 2: Avvio procedura di reinstallazione/riparazione driver video. Richiesto riavvio."
        $dduZipUrl = $AppConfig.URLs.DDUZip
        $dduZipPath = Join-Path $DriverToolsLocalPath "DDU.zip"
        if (-not (Download-FileWithProgress -Url $dduZipUrl -DestinationPath $dduZipPath -Description "DDU (Display Driver Uninstaller)")) {
            Write-StyledMessage Error "Impossibile scaricare DDU. Annullamento operazione."
            return
        }
        Write-StyledMessage Info "Estrazione DDU sul Desktop."
        try {
            Expand-Archive -Path $dduZipPath -DestinationPath $DesktopPath -Force
            Write-StyledMessage Success "DDU estratto correttamente sul Desktop."
        }
        catch {
            Write-StyledMessage Error "Errore durante l'estrazione di DDU sul Desktop: $($_.Exception.Message)."
            return
        }
        $gpuManufacturer = Get-GpuManufacturer
        Write-StyledMessage Info "Rilevata GPU: $gpuManufacturer."
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
        $batchFilePath = Join-Path $DesktopPath "Switch to Normal Mode.bat"
        try {
            Set-Content -Path $batchFilePath -Value 'bcdedit /deletevalue {current} safeboot' -Encoding ASCII
            Write-StyledMessage Info "File batch 'Switch to Normal Mode.bat' creato sul desktop per disabilitare la Modalità Provvisoria."
        }
        catch {
            Write-StyledMessage Warning "Impossibile creare il file batch: $($_.Exception.Message)."
        }
        Write-StyledMessage Error "ATTENZIONE: Il sistema sta per riavviarsi in modalità provvisoria."
        Write-StyledMessage Info "Configurazione del sistema per l'avvio automatico in Modalità Provvisoria."
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
            Write-StyledMessage Error "Errore durante la configurazione della Modalità Provvisoria tramite bcdedit: $($_.Exception.Message)."
            Write-StyledMessage Warning "Il riavvio potrebbe non avvenire in Modalità Provvisoria. Procedere manualmente."
            return
        }
        if ($SuppressIndividualReboot) {
            $Global:NeedsFinalReboot = $true
            Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio in modalità provvisoria soppresso (esecuzione concatenata)."
            Write-StyledMessage -Type 'Warning' -Text "⚠️ DDU e installer driver sono sul Desktop. Al prossimo riavvio sarai in SAFE MODE."
        }
        else {
            $shouldReboot = Start-InterruptibleCountdown -Seconds 30 -Message "Riavvio in modalità provvisoria in corso."
            if ($shouldReboot) {
                try {
                    Restart-Computer -Force
                    Write-StyledMessage Success "Comando di riavvio inviato."
                }
                catch {
                    Write-StyledMessage Error "Errore durante l'esecuzione del comando di riavvio: $($_.Exception.Message)."
                }
            }
        }
    }
    Write-StyledMessage Info '🔧 Inizializzazione dello Script di Installazione Driver Video.'
    Start-Sleep -Seconds 2
    Set-BlockWindowsUpdateDrivers
    $choice = ""
    do {
        Write-Host ""
        Write-StyledMessage Info 'Seleziona un''opzione:'
        Write-Host "  1) Installa Driver Video."
        Write-Host "  2) Reinstalla/Ripara Driver Video."
        Write-Host "  0) Torna al menu principale."
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
            Write-Host "Premi un tasto per continuare."
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            Clear-Host
            Show-Header -SubTitle "Video Driver Install Toolkit"
        }
    } while ($choice.ToUpper() -ne "0")
}
function GamingToolkit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,
        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitLog -ToolName "GamingToolkit"
    Show-Header -SubTitle "Gaming Toolkit"
    $Host.UI.RawUI.WindowTitle = "Gaming Toolkit By MagnetarMan"
    $timeout = 3600
    function Test-WingetPackageAvailable([string]$PackageId) {
        try {
            $searchResult = winget search --id $PackageId --accept-source-agreements 2>&1
            $outputStr = $searchResult -join ' '
            if ($outputStr -match [regex]::Escape($PackageId)) {
                return $true
            }
            $listResult = winget list --id $PackageId --accept-source-agreements 2>&1
            $listStr = $listResult -join ' '
            if ($listStr -match [regex]::Escape($PackageId)) {
                return $true
            }
            return $false
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-StyledMessage -Type 'Warning' -Text ("Errore verifica pacchetto {0}: {1}" -f $PackageId, $errorMessage)
            return $false
        }
    }
    function Invoke-WingetInstallWithProgress([string]$PackageId, [string]$DisplayName, [int]$Step, [int]$Total) {
        Write-StyledMessage -Type 'Info' -Text "[$Step/$Total] 📦 Installazione: $DisplayName"
        $outFile = "$env:TEMP\winget_$PackageId.log"
        $errFile = "$env:TEMP\winget_err_$PackageId.log"
        try {
            $result = Invoke-WithSpinner -Activity "Installazione $DisplayName" -Process -Action {
                $procParams = @{
                    FilePath               = 'winget'
                    ArgumentList           = @('install', '--id', $PackageId, '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements')
                    PassThru               = $true
                    NoNewWindow            = $true
                    RedirectStandardOutput = $outFile
                    RedirectStandardError  = $errFile
                }
                Start-Process @procParams
            } -TimeoutSeconds $timeout -UpdateInterval 700
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)
            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text "Installato: $DisplayName"
                return @{ Success = $true; ExitCode = $exitCode }
            }
            else {
                Write-StyledMessage -Type 'Error' -Text "Errore installazione $DisplayName (codice: $exitCode)."
                return @{ Success = $false; ExitCode = $exitCode }
            }
        }
        catch {
            Write-Host "`r$(' ' * 120)" -NoNewline
            Write-Host "`r" -NoNewline
            Write-StyledMessage -Type 'Error' -Text "Eccezione $DisplayName : $($_.Exception.Message)."
            return @{ Success = $false }
        }
        finally {
            Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
        }
    }
    $Host.UI.RawUI.WindowTitle = "Gaming Toolkit by MagnetarMan"
    Invoke-WithSpinner -Activity "Preparazione" -Timer -Action { Start-Sleep 5 } -TimeoutSeconds 5
    Show-Header -SubTitle "Gaming Toolkit"
    Write-StyledMessage Info '🔍 Verifica disponibilità Winget.'
    Update-EnvironmentPath
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage Warning '⚠️ Winget non disponibile. Avvio ripristino automatico...'
        $resetOk = Reset-Winget
        Update-EnvironmentPath
        if (-not $resetOk -or -not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage Error '❌ Ripristino Winget fallito. Impossibile procedere con Gaming Toolkit.'
            Write-StyledMessage -Type 'Info' -Text 'Premi un tasto per continuare.'
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
    }
    Write-StyledMessage Success '✅ Winget disponibile.'
    Write-StyledMessage Info '🔄 Aggiornamento sorgenti Winget.'
    try {
        winget source update | Out-Null
        Write-StyledMessage Success 'Sorgenti aggiornate.'
    }
    catch {
        Write-StyledMessage Warning "Errore aggiornamento sorgenti: $($_.Exception.Message)."
    }
    Write-Host ''
    Write-StyledMessage Info '🔧 Abilitazione NetFramework.'
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs, NetFx3 -NoRestart -All -ErrorAction Stop | Out-Null
        Write-StyledMessage Success 'NetFramework abilitato.'
    }
    catch {
        Write-StyledMessage Error "Errore durante abilitazione NetFramework: $($_.Exception.Message)."
    }
    Write-Host ''
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
    Write-StyledMessage Info '🔥 Installazione runtime .NET e VCRedist.'
    for ($runtimeIndex = 0; $runtimeIndex -lt $runtimes.Count; $runtimeIndex++) {
        Invoke-WingetInstallWithProgress $runtimes[$runtimeIndex] $runtimes[$runtimeIndex] ($runtimeIndex + 1) $runtimes.Count | Out-Null
        Write-Host ''
    }
    Write-StyledMessage Success 'Runtime completati.'
    Write-Host ''
    Write-StyledMessage Info '🎮 Installazione DirectX.'
    $dxDir = "$env:LOCALAPPDATA\WinToolkit\Directx"
    $dxPath = "$dxDir\dxwebsetup.exe"
    if (-not (Test-Path $dxDir)) { New-Item -Path $dxDir -ItemType Directory -Force | Out-Null }
    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.DirectXWebSetup -OutFile $dxPath -ErrorAction Stop
        Write-StyledMessage Success 'DirectX scaricato.'
        $result = Invoke-WithSpinner -Activity "Installazione DirectX" -Process -Action {
            $procParams = @{
                FilePath     = $dxPath
                PassThru     = $true
            }
            Start-Process @procParams
        } -TimeoutSeconds $timeout -UpdateInterval 700
        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline
        if ($null -eq $result) {
            Write-StyledMessage Error "DirectX: processo non avviato correttamente."
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage Warning "Timeout DirectX."
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 3010, 5100, -9, 9, -1442840576)
            Write-StyledMessage -Type ($exitCode -in $successCodes ? 'Success' : 'Error') -Text ($exitCode -in $successCodes ? "DirectX installato (codice: $exitCode)." : "DirectX errore: $exitCode")
        }
    }
    catch {
        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline
        Write-StyledMessage Error "Errore durante installazione DirectX: $($_.Exception.Message)"
    }
    Write-Host ''
    $gameClients = @(
        "Amazon.Games", "GOG.Galaxy", "EpicGames.EpicGamesLauncher",
        "ElectronicArts.EADesktop", "Playnite.Playnite", "Valve.Steam",
        "Ubisoft.Connect"
    )
    Write-StyledMessage Info '🎮 Installazione client di gioco.'
    for ($clientIndex = 0; $clientIndex -lt $gameClients.Count; $clientIndex++) {
        Invoke-WingetInstallWithProgress $gameClients[$clientIndex] $gameClients[$clientIndex] ($clientIndex + 1) $gameClients.Count | Out-Null
        Write-Host ''
    }
    Write-StyledMessage Success 'Client installati.'
    Write-Host ''
    Write-StyledMessage Info '🎮 Reinstallazione Xbox Game Bar & App.'
    $xboxPackages = @("9NZKPSTSNW4P", "9MV0B5HZVK9Z")
    foreach ($pkg in $xboxPackages) {
        Write-StyledMessage -Type 'Info' -Text "Reinstallazione: $pkg."
        $outFile = "$env:TEMP\winget_$pkg.log"
        $errFile = "$env:TEMP\winget_err_$pkg.log"
        try {
            $result = Invoke-WithSpinner -Activity "Reinstallazione $pkg" -Process -Action {
                $procParams = @{
                    FilePath               = 'winget'
                    ArgumentList           = @('install', '--id', $pkg, '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements', '--force')
                    PassThru               = $true
                    NoNewWindow            = $true
                    RedirectStandardOutput = $outFile
                    RedirectStandardError  = $errFile
                }
                Start-Process @procParams
            } -TimeoutSeconds $timeout -UpdateInterval 700
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)
            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text "Reinstallato: $pkg."
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "${pkg}: codice $exitCode."
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore $pkg : $($_.Exception.Message)."
        }
        finally {
            Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
        }
        Write-Host ''
    }
    Write-StyledMessage Success 'Xbox reinstallati.'
    Write-Host ''
    Write-StyledMessage Info '🎮 Installazione Battle.net.'
    $bnPath = "$env:TEMP\Battle.net-Setup.exe"
    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.BattleNetInstaller -OutFile $bnPath -ErrorAction Stop
        Write-StyledMessage Success 'Battle.net scaricato.'
        $result = Invoke-WithSpinner -Activity "Installazione Battle.net" -Process -Action {
            $procParams = @{
                FilePath     = $bnPath
                ArgumentList = '--quiet'
                PassThru     = $true
                Verb         = 'RunAs'
                WindowStyle  = 'Hidden'
            }
            Start-Process @procParams
        } -TimeoutSeconds $timeout -UpdateInterval 500
        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline
        if ($null -eq $result) {
            Write-StyledMessage Error "Battle.net: processo non avviato correttamente."
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage Warning "Timeout Battle.net."
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            Write-StyledMessage -Type ($exitCode -in @(0, 3010) ? 'Success' : 'Warning') -Text ($exitCode -in @(0, 3010) ? "Battle.net installato." : "Battle.net: codice $exitCode")
        }
        Write-StyledMessage -Type 'Info' -Text 'Premi un tasto per continuare.'
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    catch {
        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline
        Write-StyledMessage Error "Errore durante installazione Battle.net: $($_.Exception.Message)"
        Write-StyledMessage -Type 'Info' -Text 'Premi un tasto per continuare.'
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    Write-Host ''
    Write-StyledMessage Info '🧹 Pulizia avvio automatico.'
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
    Write-StyledMessage Info '⚡ Configurazione profilo energetico.'
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
            Write-StyledMessage Error "Errore durante attivazione piano energetico: $($_.Exception.Message)."
        }
    }
    else {
        Write-StyledMessage Error "Impossibile attivare piano."
    }
    Write-Host ''
    Write-StyledMessage Info '🔕 Attivazione Non disturbare.'
    try {
        Set-ItemProperty -Path $AppConfig.Registry.FocusAssist -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0 -Force
        Write-StyledMessage Success 'Non disturbare attivo.'
    }
    catch {
        Write-StyledMessage Error "Errore durante configurazione Focus Assist: $($_.Exception.Message)"
    }
    Write-Host ''
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)
    Write-StyledMessage -Type 'Success' -Text 'Gaming Toolkit completato!'
    Write-StyledMessage -Type 'Success' -Text 'Sistema ottimizzato per il gaming.'
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)
    Write-Host ''
    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
        Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
    }
    else {
        if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio necessario") {
            Write-StyledMessage Info '🔄 Riavvio.'
            Restart-Computer -Force
        }
        else {
            Write-StyledMessage Warning 'Riavvia manualmente per applicare tutte le modifiche.'
            Write-StyledMessage -Type 'Info' -Text 'Premi un tasto per continuare.'
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
    }
}
function DisableBitlocker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,
        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitLog -ToolName "DisableBitlocker"
    Show-Header -SubTitle "Disable BitLocker Toolkit"
    $Host.UI.RawUI.WindowTitle = "Disable BitLocker Toolkit By MagnetarMan"
    $regPath = $AppConfig.Registry.BitLocker
    $timeout = 3600
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
    try {
        Write-StyledMessage -Type 'Info' -Text "🚀 Inizializzazione decrittazione drive C:."
        $result = Invoke-WithSpinner -Activity "Disattivazione BitLocker" -Process -Action {
            $procParams = @{
                FilePath     = 'manage-bde.exe'
                ArgumentList = @('-off', 'C:')
                PassThru     = $true
                WindowStyle  = 'Hidden'
            }
            Start-Process @procParams
        } -TimeoutSeconds $timeout
        if ($result.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text "✅ Decrittazione avviata/completata con successo."
            Start-Sleep -Seconds 2
            $status = Test-BitLockerStatus -DriveLetter "C:"
            if ($status -match "Decryption in progress" -or $status -match "Decriptazione in corso.") {
                Write-StyledMessage -Type 'Info' -Text "⏳ Decrittazione in corso in background."
            }
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text "⚠️ Codice uscita manage-bde: $($result.ExitCode). BitLocker potrebbe essere già disattivo o in errore."
        }
        Write-StyledMessage -Type 'Info' -Text "⚙️ Disabilitazione crittografia automatica nel registro."
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force *>$null
        }
        Set-ItemProperty -Path $regPath -Name "PreventDeviceEncryption" -Type DWord -Value 1 -Force
        Write-StyledMessage -Type 'Success' -Text "🎉 Configurazione completata."
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "❌ Errore critico in DisableBitlocker: $($_.Exception.Message)"
        Write-ToolkitLog -Level ERROR -Message "Errore critico in DisableBitlocker" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text "♻️ Pulizia risorse Completata."
        if ($SuppressIndividualReboot) {
            $Global:NeedsFinalReboot = $true
        }
        else {
            if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio in") {
                Restart-Computer -Force
            }
        }
        Write-ToolkitLog -Level INFO -Message "DisableBitlocker sessione terminata."
    }
}
function WinExportLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,
        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitLog -ToolName "WinExportLog"
    Show-Header -SubTitle "Esporta Log Diagnostici"
    $Host.UI.RawUI.WindowTitle = "Log Export By MagnetarMan"
    $logSourcePath = $AppConfig.Paths.Logs
    $desktopPath = $AppConfig.Paths.Desktop
    $timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")
    $zipFileName = "WinToolkit_Logs_$timestamp.zip"
    $zipFilePath = Join-Path $desktopPath $zipFileName
    try {
        Write-StyledMessage Info "📂 Verifica presenza cartella log."
        if (-not (Test-Path $logSourcePath -PathType Container)) {
            Write-StyledMessage Warning "La cartella dei log '$logSourcePath' non è stata trovata. Impossibile esportare."
            return
        }
        Write-StyledMessage Info "🗜️ Compressione dei log in corso. Potrebbe essere ignorato qualche file in uso."
        $tempFolder = Join-Path $AppConfig.Paths.TempFolder "WinToolkit_Logs_Temp_$timestamp"
        if (Test-Path $tempFolder) {
            Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
        $filesCopied = 0
        $filesSkipped = 0
        try {
            Get-ChildItem -Path $logSourcePath -File | ForEach-Object {
                try {
                    Copy-Item $_.FullName -Destination $tempFolder -Force -ErrorAction Stop
                    $filesCopied++
                }
                catch {
                    $filesSkipped++
                    Write-Debug "File ignorato: $($_.Name) - $($_.Exception.Message)"
                }
            }
        }
        catch {
            Write-StyledMessage Warning "Errore durante la copia dei file: $($_.Exception.Message)."
        }
        if ($filesCopied -gt 0) {
            Compress-Archive -Path "$tempFolder\*" -DestinationPath $zipFilePath -Force -ErrorAction Stop
            if (Test-Path $zipFilePath) {
                Write-StyledMessage Success "Log compressi con successo! File salvato: '$zipFileName' sul Desktop."
                if ($filesSkipped -gt 0) {
                    Write-StyledMessage Info "⚠️ Attenzione: $filesSkipped file sono stati ignorati perché in uso o non accessibili."
                }
                Write-StyledMessage Info "📩 Per favore, invia il file ZIP '$zipFileName' (lo trovi sul tuo Desktop) via Telegram [https://t.me/MagnetarMan] o email [me@magnetarman.com] per aiutarmi nella diagnostica."
            }
            else {
                Write-StyledMessage Error "Errore sconosciuto: il file ZIP non è stato creato."
            }
        }
        else {
            Write-StyledMessage Error "Nessun file log è stato copiato. Verifica i permessi e che i file esistano."
        }
        if (Test-Path $tempFolder) {
            Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-StyledMessage Error "Errore critico durante la compressione dei log: $($_.Exception.Message)."
        Write-ToolkitLog -Level ERROR -Message "Errore critico in WinExportLog" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
        $tempFolder = Join-Path $env:TEMP "WinToolkit_Logs_Temp_$timestamp"
        if (Test-Path $tempFolder) {
            Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
function Read-ValidatedChoice {
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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Rows,
        [Parameter(Mandatory = $true)]
        [hashtable[]]$Columns,
        [string]$Title = ''
    )
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
    foreach ($col in $Columns) {
        $headerLine += ' ' + $col.Header.PadRight($widths[$col.Key]) + ' |'
    }
    Write-Host $headerLine -ForegroundColor Cyan
    Write-Host $sep -ForegroundColor DarkGray
    foreach ($row in $Rows) {
        $line = '|'
        foreach ($col in $Columns) {
            $val = if ($row -is [hashtable]) { "$($row[$col.Key])" } else { "$($row.$($col.Key))" }
            $cell = ' ' + $val.PadRight($widths[$col.Key]) + ' |'
            $color = if ($col.Color) { $col.Color } else { 'White' }
            $line += $cell
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
    try {
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
            catch { }
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
            $trustedInstaller = Get-Service -Name TrustedInstaller -ErrorAction SilentlyContinue
            if ($trustedInstaller -and $trustedInstaller.Status -eq 'Running') {
                $installerRunning = $true
            }
        }
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
if (-not $ImportOnly -and -not $Global:GuiSessionActive) {
    Write-Host ""
    Write-StyledMessage -Type 'Info' -Text '💎 WinToolkit avviato in modalità interattiva'
    Write-Host ""
    while ($true) {
        Show-Header -SubTitle "Menu Principale"
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
            $diskFreeGB = $si.FreeDisk
            $displayString = "$($si.FreePercentage)% Libero ($($diskFreeGB) GB)"
            $diskColor = "Green"
            if ($diskFreeGB -lt 50) {
                $diskColor = "Red"
            }
            elseif ($diskFreeGB -ge 50 -and $diskFreeGB -le 80) {
                $diskColor = "Yellow"
            }
            Write-Host $displayString -ForegroundColor $diskColor -NoNewline
            Write-Host ""
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
        $rawInput = Microsoft.PowerShell.Utility\Read-Host 'Inserisci uno o più numeri (es: 1 2 3 oppure 1,2,3) per eseguire le operazioni in sequenza'
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
                    & ([scriptblock]::Create("$($scriptToRun.Name) -SuppressIndividualReboot"))
                }
                else {
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
    Write-Verbose "═══════════════════════════════════════════════════════════"
    Write-Verbose "  📚 WinToolkit caricato in modalità LIBRERIA"
    Write-Verbose "  ✅ Funzioni disponibili, menu TUI soppresso"
    Write-Verbose "  💎 Versione: $ToolkitVersion"
    Write-Verbose "═══════════════════════════════════════════════════════════"
    $Global:menuStructure = $menuStructure
}
