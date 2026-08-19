<#
.SYNOPSIS
    Compiles WinToolkit.ps1 from WinToolkit-template.ps1 and files in /tools.

.DESCRIPTION
    This script performs the toolkit build, calculates compression
    statistics, and handles logging.

.EXAMPLE
    .\Invoke-Build.ps1 -Version "2.5.2 (Build 13)"

.NOTES
    Author: MagnetarMan
    Version: 1.0.5
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Version = "Unknown",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "WinToolkit.ps1",

    [Parameter(Mandatory = $false)]
    [string]$TemplatePath = "wintoolkit-modules",

    [Parameter(Mandatory = $false)]
    [switch]$Minify = $true
)

# --- PowerShell Best Practices ---
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Variables for statistics ---
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


try {
    Write-BuildLog -Message "========================================" -Type Header
    Write-BuildLog -Message "  COMPILING WinToolkit.ps1" -Type Header
    Write-BuildLog -Message "  Version: $Version" -Type Header
    Write-BuildLog -Message "========================================" -Type Header

    # Prerequisite check
    Write-BuildLog -Message "`n📋 Checking prerequisites..." -Type Info

    if (-not (Test-Path "compiler.ps1")) {
        Write-BuildLog -Message "❌ compiler.ps1 not found" -Type Error
        exit 1
    }
    Write-BuildLog -Message "  ✅ compiler.ps1 present" -Type Success

    if (-not (Test-Path $TemplatePath)) {
        Write-BuildLog -Message "❌ Path $TemplatePath not found" -Type Error
        exit 1
    }
    Write-BuildLog -Message "  ✅ $TemplatePath present" -Type Success

    # Check files in the tools folder
    $toolFiles = Get-ChildItem -Path "tools" -Filter "*.ps1" -ErrorAction SilentlyContinue
    if ($toolFiles.Count -eq 0) {
        Write-BuildLog -Message "❌ No .ps1 files found in the tools folder" -Type Error
        exit 1
    }
    Write-BuildLog -Message "  ✅ $($toolFiles.Count) files found in /tools" -Type Success

    # Calculate source statistics BEFORE compilation
    Write-BuildLog -Message "`n📊 Calculating source statistics..." -Type Info

    foreach ($file in $toolFiles) {
        $stats = Get-FileStats -Path $file.FullName
        $script:SourceTotalBytes += $stats.Bytes
        $script:SourceTotalLines += $stats.Lines
        $script:FilesProcessed++
        Write-BuildLog -Message "  📄 $($file.Name): $($stats.Bytes) bytes, $($stats.Lines) lines" -Type Info
    }

    # Include the template as well
    $templateStats = Get-FileStats -Path $TemplatePath
    $script:SourceTotalBytes += $templateStats.Bytes
    $script:SourceTotalLines += $templateStats.Lines
    Write-BuildLog -Message "  📄 ${TemplatePath}: $($templateStats.Bytes) bytes, $($templateStats.Lines) lines" -Type Info

    Write-BuildLog -Message "`n📈 Total source: $([math]::Round($script:SourceTotalBytes/1KB, 2)) KB, $($script:SourceTotalLines) lines" -Type Header

    # Run compilation (with or without safe minification via tokenizer)
    $minifyLabel = if ($Minify) { "WITH minification (tokenizer-safe)" } else { "WITHOUT minification" }
    Write-BuildLog -Message "`n🔨 Starting compilation $minifyLabel..." -Type Info

    try {
        if ($Minify) {
            $output = & ".\compiler.ps1" -Minify 2>&1 | Out-String
        }
        else {
            $output = & ".\compiler.ps1" 2>&1 | Out-String
        }

        Write-BuildLog -Message "Compiler output:`n$output" -Type Info

        if ($LASTEXITCODE -ne 0) {
            Write-BuildLog -Message "❌ Compilation failed with exit code: $LASTEXITCODE" -Type Error
            exit 1
        }
    }
    catch {
        Write-BuildLog -Message "❌ Error during compilation: $($_.Exception.Message)" -Type Error
        exit 1
    }

    # Verify output
    if (-not (Test-Path $OutputPath)) {
        Write-BuildLog -Message "❌ File $OutputPath not created" -Type Error
        exit 1
    }

    Write-BuildLog -Message "✅ Compiled file created: $OutputPath" -Type Success

    # Calculate output statistics AFTER compilation
    Write-BuildLog -Message "`n📊 Calculating output statistics..." -Type Info

    $outputStats = Get-FileStats -Path $OutputPath
    $script:OutputTotalBytes = $outputStats.Bytes
    $script:OutputTotalLines = $outputStats.Lines

    Write-BuildLog -Message "  📄 ${OutputPath}: $($outputStats.Bytes) bytes, $($outputStats.Lines) lines" -Type Info

    # Calculate compression statistics
    $reductionBytes = $script:SourceTotalBytes - $script:OutputTotalBytes
    $reductionPercent = [math]::Round(($reductionBytes / $script:SourceTotalBytes) * 100, 2)
    $linesRemoved = $script:SourceTotalLines - $script:OutputTotalLines

    Write-BuildLog -Message "`n========================================" -Type Header
    Write-BuildLog -Message "  COMPRESSION STATISTICS" -Type Header
    Write-BuildLog -Message "========================================" -Type Header
    Write-BuildLog -Message "📦 Source size: $([math]::Round($script:SourceTotalBytes/1KB, 2)) KB" -Type Info
    Write-BuildLog -Message "📦 Final size:    $([math]::Round($script:OutputTotalBytes/1KB, 2)) KB" -Type Info
    Write-BuildLog -Message "📉 Reduction:     $([math]::Round($reductionBytes/1KB, 2)) KB ($reductionPercent%)" -Type Success
    Write-BuildLog -Message "📝 Source lines:  $($script:SourceTotalLines)" -Type Info
    Write-BuildLog -Message "📝 Final lines:   $($script:OutputTotalLines)" -Type Info
    Write-BuildLog -Message "📝 Lines removed: $linesRemoved" -Type Success


    Write-BuildLog -Message "`n========================================" -Type Header
    Write-BuildLog -Message "  COMPILATION COMPLETE" -Type Header
    Write-BuildLog -Message "========================================" -Type Header

    # Output for GitHub Actions
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

    exit 0
}
catch {
    Write-BuildLog -Message "❌ ERROR: $($_.Exception.Message)" -Type Error
    Write-BuildLog -Message "Stack Trace: $($_.ScriptStackTrace)" -Type Error

    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}

    exit 1
}
