# ============================================================================
# LOGGING AND CONSOLE OUTPUT
# ============================================================================

function Write-StyledMessage {
    <#
    .SYNOPSIS
    Writes a formatted message with timestamp, icon and color, and saves it to the log.
    #>
    param(
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Progress')]
        [string]$Type,
        [string]$Text
    )

    $style = $script:AppConfig.MsgStyles[$Type]
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color

    # Mirror to log file
    $logLevel = switch ($Type) {
        'Success' { 'SUCCESS' }
        'Warning' { 'WARNING' }
        'Error' { 'ERROR' }
        default { 'INFO' }
    }
    Write-ToolkitLog -Level $logLevel -Message $Text
}

function Start-ToolkitLog {
    <#
    .SYNOPSIS
        Initializes the structured log file for a specific tool.
    #>
    param([string]$ToolName)

    # Clean up leftover transcripts
    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}

    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = $script:AppConfig.Paths.Logs
    if (-not (Test-Path $logdir)) {
        New-Item -Path $logdir -ItemType Directory -Force | Out-Null
    }
    Get-ChildItem -Path $logdir -Filter '*.log' -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item -Force -ErrorAction SilentlyContinue
    $script:CurrentLogFile = "$logdir\${ToolName}_${dateTime}_$PID.log"
    Start-Transcript -Path "$logdir\${ToolName}_${dateTime}_$PID.transcript.log" -Append -Force | Out-Null

    # Raccolta metadati
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $psVer = $PSVersionTable.PSVersion.ToString()

    $header = @"
[START LOG HEADER]
Start time     : $dateTime
ToolName       : $ToolName
OS             : $($os.Caption) $($os.Version)
PSVersion      : $psVer
ToolkitVersion : $($script:AppConfig.Header.Version)
[END LOG HEADER]

"@
    try { Add-Content -Path $script:CurrentLogFile -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}

function Write-ToolkitLog {
    <#
    .SYNOPSIS
        Scrive una riga di log strutturata SOLO su file.
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
    try { Add-Content -Path $script:CurrentLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
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
