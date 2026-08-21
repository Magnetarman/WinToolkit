

# ==============================================================================
# SEZIONE 4 · LOGGING
# Motore di log dual-stream: header di sessione + scrittura strutturata su file.
# Usato da Write-StyledMessage e da tutti i tool via Write-ToolkitLog.
# ==============================================================================

function Start-ToolkitLog {
    <#
    .SYNOPSIS
        Initializes the structured log file for a specific tool.
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
    Version                 : Version $dispVer (OS build $($os.BuildNumber))
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
        [string]$Message
    )
    if ([string]::IsNullOrWhiteSpace($Message)) { $Message = Get-SourceTextLoc 'sourceText.criticalError' }
    Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'uiText.0In12' -Args @($Message, ${ToolName}, $($Record.Exception.Message)))
    Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'uiText.0In1' -Args @($Message, $ToolName)) -Context @{
        Line      = $Record.InvocationInfo.ScriptLineNumber
        Exception = $Record.Exception.GetType().FullName
        Stack     = $Record.ScriptStackTrace
    }
}
