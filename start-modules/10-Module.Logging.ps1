# ============================================================================
# LOGGING AND CONSOLE OUTPUT
# ============================================================================

function Write-StyledMessage {
    <#
    .SYNOPSIS
    Prints one timestamped, colored console message and mirrors it to the log file.
    #>
    param(
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Progress')]
        [string]$Type,
        [string]$Text
    )

    $style = $script:AppConfig.MsgStyles[$Type]
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color

    # The log level is the type in upper case, except Progress, which is informational.
    $logLevel = if ($Type -in @('Info', 'Progress')) { 'INFO' } else { $Type.ToUpperInvariant() }
    Write-ToolkitLog -Level $logLevel -Message $Text
}


function Stop-ToolkitTranscript {
    <#
    .SYNOPSIS
        Stops an optional transcript and returns the host message when one was active.

    .DESCRIPTION
        A missing transcript is not an error: PowerShell reports it with a common
        error ID and a localized message, so the inactive case is detected from the
        error ID and the inner exception type instead of from localized text.
    #>
    try {
        return (Stop-Transcript -ErrorAction Stop)
    }
    catch {
        if ($_.FullyQualifiedErrorId -eq 'InvalidOperation,Microsoft.PowerShell.Commands.StopTranscriptCommand' -and
            $_.Exception.InnerException -is [System.Management.Automation.PSInvalidOperationException]) {
            return $null
        }
        Write-Warning "start-modules\10-Module.Logging.ps1, Stop-ToolkitTranscript: $($_.Exception.Message)"
        return $null
    }
}


function Start-ToolkitLog {
    <#
    .SYNOPSIS
        Initializes the structured log file for a specific tool.
    #>
    param([string]$ToolName)

    # Close any transcript left open by an earlier run before starting a new one.
    $null = Stop-ToolkitTranscript

    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = $script:AppConfig.Paths.Logs
    $null = Initialize-Directory -Path $logdir

    # Retention: drop log files older than 30 days.
    Get-ChildItem -Path $logdir -Filter '*.log' -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item -Force -ErrorAction SilentlyContinue
    $script:CurrentLogFile = "$logdir\${ToolName}_${dateTime}_$PID.log"
    Start-Transcript -Path "$logdir\${ToolName}_${dateTime}_$PID.transcript.log" -Append -Force | Out-Null

    # Header metadata, so a standalone log is self-describing.
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $psVer = $PSVersionTable.PSVersion.ToString()

    $header = @"
[START LOG HEADER]
Start time     : $dateTime
ToolName       : $ToolName
OS             : $($os.Caption) $($os.Version)
PSVersion      : $psVer
ToolkitVersion : $script:AppConfig.Header.Version
[END LOG HEADER]

"@
    try { Add-Content -Path $script:CurrentLogFile -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue } catch {
        Write-Warning "start-modules\10-Module.Logging.ps1, Start-ToolkitLog: $($_.Exception.Message)"
    }
}


function Write-ToolkitLog {
    <#
    .SYNOPSIS
        Appends one structured line to the log file only (never to the console).
    #>
    param(
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',
        [string]$Message
    )
    if (-not $script:CurrentLogFile) { return }

    $ts = Get-Date -Format "HH:mm:ss"
    $clean = $Message -replace '^\s+', ''
    # Remove all ANSI/color characters before saving to file
    $clean = $clean -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
    $line = "[$ts] [$Level] $clean"
    try { Add-Content -Path $script:CurrentLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch {
        Write-Warning "start-modules\10-Module.Logging.ps1, Write-ToolkitLog: $($_.Exception.Message)"
    }
}


function Format-CenteredText {
    <#
    .SYNOPSIS
    Formats text centered to the specified width.
    #>
    param(
        [string]$Text,
        [int]$Width = 80
    )
    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    return (" " * $padding) + $Text
}


function Show-Header {
    <#
    .SYNOPSIS
    Displays the script graphical header with title and version.
    #>
    param(
        [string]$Title,
        [string]$Version
    )
    Clear-Host
    $width = $script:AppConfig.Layout.Width
    Write-Host ('═' * $width) -ForegroundColor Green
    @(
        '      __        __  _   _   _ ',
        '      \ \      / / | | | \ | |',
        '       \ \ /\ / /  | | |  \| |',
        '        \ V  V /   | | | |\  |',
        '         \_/\_/    |_| |_| \_|',
        '',
        $Title,
        $Version
    ) | ForEach-Object { Write-Host (Format-CenteredText -Text $_ -Width $width) -ForegroundColor White }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''
}
