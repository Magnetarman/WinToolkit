<#
.SYNOPSIS
    Compila WinToolkit.ps1 da WinToolkit-template.ps1 e i file in /tool.

.DESCRIPTION
    Questo script esegue la compilazione del toolkit, calcola le statistiche
    di compressione e gestisce il logging.

.EXAMPLE
    .\Invoke-Build.ps1 -Version "2.5.2 (Build 13)"

.NOTES
    Autore: WinToolkit CI/CD
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Version = "Unknown",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "WinToolkit.ps1",

    [Parameter(Mandatory = $false)]
    [string]$TemplatePath = "WinToolkit-template.ps1",

    [Parameter(Mandatory = $false)]
    [string]$LogsDirectory = ".github/logs"
)

# --- Best Practices PowerShell ---
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Variabili per statistiche ---
$script:SourceTotalBytes = 0
$script:SourceTotalLines = 0
$script:OutputTotalBytes = 0
$script:OutputTotalLines = 0
$script:FilesProcessed = 0

function Write-BuildLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Header')]
        [string]$Type = 'Info'
    )

    $colors = @{
        'Info'    = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
        'Header'  = 'Magenta'
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $colors[$Type]
}

function Get-FileStats {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return @{ Bytes = 0; Lines = 0 }
    }

    $content = Get-Content -Path $Path -Raw
    $bytes = (Get-Item $Path).Length
    $lines = ($content -split "`r?`n").Count

    return @{
        Bytes = $bytes
        Lines = $lines
    }
}

function Initialize-LogsDirectory {
    param([string]$LogPath)

    if (-not (Test-Path $LogPath)) {
        $null = New-Item -Path $LogPath -ItemType Directory -Force
        Write-BuildLog -Message "📁 Creata directory log: $LogPath" -Type Info
    }
}

try {
    Write-BuildLog -Message "========================================" -Type Header
    Write-BuildLog -Message "  COMPILAZIONE WINTOOLKIT.PS1" -Type Header
    Write-BuildLog -Message "  Versione: $Version" -Type Header
    Write-BuildLog -Message "========================================" -Type Header

    # Crea directory logs
    Initialize-LogsDirectory -LogPath $LogsDirectory

    # Avvia transcript per logging
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $transcriptPath = Join-Path $LogsDirectory "build_transcript_$timestamp.log"
    Start-Transcript -Path $transcriptPath -Append

    Write-BuildLog -Message "📋 Transcript avviato: $transcriptPath" -Type Info

    # Verifica prerequisiti
    Write-BuildLog -Message "`n📋 Verifica prerequisiti..." -Type Info

    if (-not (Test-Path "compiler.ps1")) {
        Write-BuildLog -Message "❌ File compiler.ps1 non trovato" -Type Error
        Stop-Transcript -ErrorAction SilentlyContinue
        exit 1
    }
    Write-BuildLog -Message "  ✅ compiler.ps1 presente" -Type Success

    if (-not (Test-Path $TemplatePath)) {
        Write-BuildLog -Message "❌ File $TemplatePath non trovato" -Type Error
        Stop-Transcript -ErrorAction SilentlyContinue
        exit 1
    }
    Write-BuildLog -Message "  ✅ $TemplatePath presente" -Type Success

    # Verifica file nella cartella tool
    $toolFiles = Get-ChildItem -Path "tool" -Filter "*.ps1" -ErrorAction SilentlyContinue
    if ($toolFiles.Count -eq 0) {
        Write-BuildLog -Message "❌ Nessun file .ps1 trovato nella cartella tool" -Type Error
        Stop-Transcript -ErrorAction SilentlyContinue
        exit 1
    }
    Write-BuildLog -Message "  ✅ $($toolFiles.Count) file trovati in /tool" -Type Success

    # Calcola statistiche sorgente PRIMA della compilazione
    Write-BuildLog -Message "`n📊 Calcolo statistiche sorgente..." -Type Info

    foreach ($file in $toolFiles) {
        $stats = Get-FileStats -Path $file.FullName
        $script:SourceTotalBytes += $stats.Bytes
        $script:SourceTotalLines += $stats.Lines
        $script:FilesProcessed++
        Write-BuildLog -Message "  📄 $($file.Name): $($stats.Bytes) bytes, $($stats.Lines) righe" -Type Info
    }

    # Aggiungi anche il template
    $templateStats = Get-FileStats -Path $TemplatePath
    $script:SourceTotalBytes += $templateStats.Bytes
    $script:SourceTotalLines += $templateStats.Lines
    Write-BuildLog -Message "  📄 ${TemplatePath}: $($templateStats.Bytes) bytes, $($templateStats.Lines) righe" -Type Info

    Write-BuildLog -Message "`n📈 Totale sorgente: $([math]::Round($script:SourceTotalBytes/1KB, 2)) KB, $($script:SourceTotalLines) righe" -Type Header

    # Esegui compilazione
    Write-BuildLog -Message "`n🔨 Avvio compilazione..." -Type Info

    try {
        $output = & ".\compiler.ps1" 2>&1 | Out-String

        Write-BuildLog -Message "Output compilatore:`n$output" -Type Info

        if ($LASTEXITCODE -ne 0) {
            Write-BuildLog -Message "❌ Compilazione fallita con exit code: $LASTEXITCODE" -Type Error
            Stop-Transcript -ErrorAction SilentlyContinue
            exit 1
        }
    }
    catch {
        Write-BuildLog -Message "❌ Errore durante compilazione: $($_.Exception.Message)" -Type Error
        Stop-Transcript -ErrorAction SilentlyContinue
        exit 1
    }

    # Verifica output
    if (-not (Test-Path $OutputPath)) {
        Write-BuildLog -Message "❌ File $OutputPath non creato" -Type Error
        Stop-Transcript -ErrorAction SilentlyContinue
        exit 1
    }

    Write-BuildLog -Message "✅ File compilato creato: $OutputPath" -Type Success

    # Calcola statistiche output DOPO la compilazione
    Write-BuildLog -Message "`n📊 Calcolo statistiche output..." -Type Info

    $outputStats = Get-FileStats -Path $OutputPath
    $script:OutputTotalBytes = $outputStats.Bytes
    $script:OutputTotalLines = $outputStats.Lines

    Write-BuildLog -Message "  📄 ${OutputPath}: $($outputStats.Bytes) bytes, $($outputStats.Lines) righe" -Type Info

    # Calcola statistiche compressione
    $reductionBytes = $script:SourceTotalBytes - $script:OutputTotalBytes
    $reductionPercent = [math]::Round(($reductionBytes / $script:SourceTotalBytes) * 100, 2)
    $linesRemoved = $script:SourceTotalLines - $script:OutputTotalLines

    Write-BuildLog -Message "`n========================================" -Type Header
    Write-BuildLog -Message "  STATISTICHE COMPRESSIONE" -Type Header
    Write-BuildLog -Message "========================================" -Type Header
    Write-BuildLog -Message "📦 Peso sorgente: $([math]::Round($script:SourceTotalBytes/1KB, 2)) KB" -Type Info
    Write-BuildLog -Message "📦 Peso finale:    $([math]::Round($script:OutputTotalBytes/1KB, 2)) KB" -Type Info
    Write-BuildLog -Message "📉 Riduzione:     $([math]::Round($reductionBytes/1KB, 2)) KB ($reductionPercent%)" -Type Success
    Write-BuildLog -Message "📝 Righe sorgente:  $($script:SourceTotalLines)" -Type Info
    Write-BuildLog -Message "📝 Righe finali:   $($script:OutputTotalLines)" -Type Info
    Write-BuildLog -Message "📝 Righe eliminate: $linesRemoved" -Type Success

    # Salva log rinominato
    Stop-Transcript -ErrorAction SilentlyContinue

    $logFileName = "build_v$Version.log"
    $logFileName = $logFileName -replace '[\\/:]', '_'  # Sanitize filename
    $finalLogPath = Join-Path $LogsDirectory $logFileName

    if (Test-Path $transcriptPath) {
        Move-Item -Path $transcriptPath -Destination $finalLogPath -Force
        Write-BuildLog -Message "📝 Log salvato: $finalLogPath" -Type Success
    }

    Write-BuildLog -Message "`n========================================" -Type Header
    Write-BuildLog -Message "  COMPILAZIONE COMPLETATA" -Type Header
    Write-BuildLog -Message "========================================" -Type Header

    # Output per GitHub Actions
    Write-Output "source_bytes=$script:SourceTotalBytes" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "source_kb=$([math]::Round($script:SourceTotalBytes/1KB, 2))" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "source_lines=$script:SourceTotalLines" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "output_bytes=$script:OutputTotalBytes" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "output_kb=$([math]::Round($script:OutputTotalBytes/1KB, 2))" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "output_lines=$script:OutputTotalLines" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "reduction_bytes=$reductionBytes" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "reduction_percent=$reductionPercent" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "lines_removed=$linesRemoved" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "files_processed=$script:FilesProcessed" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "log_path=$finalLogPath" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append

    exit 0
}
catch {
    Write-BuildLog -Message "❌ ERRORE: $($_.Exception.Message)" -Type Error
    Write-BuildLog -Message "Stack Trace: $($_.ScriptStackTrace)" -Type Error

    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}

    exit 1
}
