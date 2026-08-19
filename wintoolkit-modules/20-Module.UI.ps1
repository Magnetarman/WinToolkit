

# SECTION 3 · UI — RENDERING AND PRESENTATION
# Visual output functions: messages, bars, headers, tables.
# Depend only on $Global:MsgStyles and Write-ToolkitLog (Section 4).
# ==============================================================================

function Clear-ProgressLine {
    if ($Host.Name -eq 'ConsoleHost') {
        try {
            $rawUI = $Host.UI.RawUI

            if ($Global:ProgressLineStart) {
                $startRow = [math]::Max(0, [int]$Global:ProgressLineStart.Y)
                $endRow = [math]::Min(
                    $rawUI.BufferSize.Height - 1,
                    $startRow + [math]::Max(1, [int]$Global:ProgressLineRows) - 1
                )
                $rectangle = [System.Management.Automation.Host.Rectangle]::new(
                    0, $startRow, $rawUI.BufferSize.Width - 1, $endRow
                )
                $blankCell = [System.Management.Automation.Host.BufferCell]::new(
                    ' ', $rawUI.ForegroundColor, $rawUI.BackgroundColor,
                    [System.Management.Automation.Host.BufferCellType]::Complete
                )

                try {
                    $rawUI.SetBufferContents($rectangle, $blankCell)
                }
                catch {
                    $blankLine = ' ' * $rawUI.BufferSize.Width
                    for ($row = $startRow; $row -le $endRow; $row++) {
                        $rawUI.CursorPosition = [System.Management.Automation.Host.Coordinates]::new(0, $row)
                        Write-Host $blankLine -NoNewline
                    }
                }

                $rawUI.CursorPosition = $Global:ProgressLineStart
                $Global:ProgressLineStart = $null
                $Global:ProgressLineRows = 0
                return
            }

            $width = $rawUI.WindowSize.Width - 1
            Write-Host "`r$(' ' * $width)`r" -NoNewline
        }
        catch {
            Write-Host "`r                                                                                `r" -NoNewline
            $Global:ProgressLineStart = $null
            $Global:ProgressLineRows = 0
        }
    }
}

function Get-CenteredText {
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
    $displayText = $Text
    Write-Host "[$timestamp] $($style.Icon) $displayText" -ForegroundColor $style.Color -NoNewline:$NoNewline

    $logLevel = switch ($Type) {
        'Success' { 'SUCCESS' } 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' }
    }
    Write-ToolkitLog -Level $logLevel -Message $displayText
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
        $progressLine = "$Spinner $Icon $Activity $bar"
        if ($Status) { $progressLine += " $Status" }

        $startPosition = $null
        if ($Host.Name -eq 'ConsoleHost') {
            try {
                $cursor = $Host.UI.RawUI.CursorPosition
                $startPosition = [System.Management.Automation.Host.Coordinates]::new(0, $cursor.Y)
            }
            catch {}
        }

        Write-Host "`r$progressLine" -NoNewline -ForegroundColor $Color
        if ($Percent -ge 100) {
            Write-Host ''
            $Global:ProgressLineStart = $null
            $Global:ProgressLineRows = 0
        }
        elseif ($startPosition) {
            $endPosition = $Host.UI.RawUI.CursorPosition
            $Global:ProgressLineStart = $startPosition
            $Global:ProgressLineRows = [math]::Max(1, $endPosition.Y - $startPosition.Y + 1)
        }
    }
}

function Write-ProgressUpdate {
    <#
    .SYNOPSIS
        Helper DRY: pulisce la riga e disegna Show-ProgressBar in un'unica chiamata.
        Usato da tutti gli spinner, download e countdown per evitare duplicazione di Clear + Write.
    #>
    param(
        [string]$Activity,
        [string]$Status = '',
        [int]$Percent = 0,
        [string]$Icon = '⏳',
        [string]$Color = 'Green',
        [string]$Spinner = ''
    )
    if ($Global:GuiSessionActive) { return }
    Clear-ProgressLine
    Show-ProgressBar -Activity $Activity -Status $Status -Percent $Percent -Icon $Icon -Spinner $Spinner -Color $Color
}

function Show-Header {
    <#
    .SYNOPSIS
        Mostra l'intestazione standardizzata del toolkit.
    #>
    param([string]$SubTitle)
    if ($Global:GuiSessionActive) { return }
    if ([string]::IsNullOrWhiteSpace($SubTitle)) { $SubTitle = Get-SourceTextLoc 'menu.main' }
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
        ("       " + (Get-SourceTextLoc 'sourceText.version') + " $ToolkitVersion")
    )
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    foreach ($line in $asciiArt) { Write-Host (Get-CenteredText $line $width) -ForegroundColor White }
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
        $statusColumn = $Columns | Where-Object { $_.Key -eq 'Status' -or $_.Key -eq 'Stato' } | Select-Object -First 1
        $statusKey = if ($statusColumn) { $statusColumn.Key } else { $null }
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