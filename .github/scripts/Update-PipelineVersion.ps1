# WinToolkit CI/CD V4.1.0
# Aligns the pipeline version across every workflow, composite action and
# pipeline script.
#
# SINGLE SOURCE OF TRUTH: the PIPELINE_VERSION value in the canonical workflow
# (CI-WinToolkit-Dev.yml by default). Edit that one value; this script rewrites
# the "V<major>.<minor>.<patch>" token in every workflow/action name, and both
# rewrites and inserts the "# WinToolkit CI/CD V<version>" header in every
# pipeline script, so the version can never drift.
#
# Usage:
#   .\.github\scripts\Update-PipelineVersion.ps1                 # align (no-op if aligned)
#   .\.github\scripts\Update-PipelineVersion.ps1 -Version 4.2.0  # set and align
#   .\.github\scripts\Update-PipelineVersion.ps1 -Check          # fail if any drift

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Version,

    [string]$CanonicalWorkflow = '.github\workflows\CI-WinToolkit-Dev.yml',

    # Report drift without writing anything; exits non-zero when inconsistent.
    [switch]$Check,

    # Receives one relative path per changed file, one per line. Callers use it to
    # report or commit the alignment without having to parse git output.
    [string]$ChangedFileListPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$versionPattern = 'V\d+\.\d+\.\d+'

# Canonical header every pipeline script must carry as its first line.
$headerPattern = '(?m)^[ \t]*#[ \t]*WinToolkit[ \t]+CI/CD[ \t]+V\d+\.\d+\.\d+[ \t]*\r?$'
$bomText = "$([char]0xEF)$([char]0xBB)$([char]0xBF)"

# Inserts the header as the very first line, preserving any BOM and the dominant
# line ending. A leading comment is always syntactically neutral.
function Add-PipelineHeader {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Version
    )

    $offset = 0
    if ($Text.StartsWith($bomText)) { $offset = $bomText.Length }

    $eol = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }

    return $Text.Substring(0, $offset) + "# WinToolkit CI/CD V$Version" + $eol + $Text.Substring($offset)
}

# Reads the canonical value; falls back to -Version when supplied.
function Get-CanonicalVersion {
    param([string]$Explicit)

    if ($Explicit) { return $Explicit.Trim() }

    $canonicalPath = Join-Path $repoRoot $CanonicalWorkflow
    if (-not (Test-Path -LiteralPath $canonicalPath)) {
        throw "Canonical workflow not found: $CanonicalWorkflow"
    }
    $text = [System.IO.File]::ReadAllText($canonicalPath)
    $match = [regex]::Match($text, '(?m)^\s*PIPELINE_VERSION:\s*["'']?([0-9]+\.[0-9]+\.[0-9]+)["'']?\s*$')
    if (-not $match.Success) {
        throw "PIPELINE_VERSION not found in $CanonicalWorkflow; add it under 'env:'."
    }
    return $match.Groups[1].Value
}

$target = Get-CanonicalVersion -Explicit $Version
if ($target -notmatch '^\d+\.\d+\.\d+$') {
    throw "Invalid pipeline version '$target'; expected <major>.<minor>.<patch>."
}

# Byte-level rewrite: encoding, BOM and line endings are preserved exactly.
$latin1 = [System.Text.Encoding]::GetEncoding(28591)
# Target files, and nothing else:
#   - .yml : workflow definitions (.github\workflows) and composite actions
#            (.github\actions\*\action.yml);
#   - .ps1 : pipeline scripts, only when they live inside .github\ (scripts and
#            tests). Application sources (start-modules, wintoolkit-modules,
#            tools) are never touched: they carry the product version, not the
#            pipeline version.
$files = @(
    Get-ChildItem -Path (Join-Path $repoRoot '.github\workflows') -Filter '*.yml' -File
    Get-ChildItem -Path (Join-Path $repoRoot '.github\actions') -Filter 'action.yml' -File -Recurse
    Get-ChildItem -Path (Join-Path $repoRoot '.github') -Filter '*.ps1' -File -Recurse
)

$updated = @()
$drift = @()
$missingHeader = @()
$headerAdded = @()

# With an explicit -Version the canonical value is the one being overridden, so it
# is written too: the tree must never be left with files and canonical disagreeing.
if ($Version) {
    $canonicalPath = Join-Path $repoRoot $CanonicalWorkflow
    $canonicalBytes = [System.IO.File]::ReadAllBytes($canonicalPath)
    $canonicalText = $latin1.GetString($canonicalBytes)
    $canonicalNew = [regex]::Replace(
        $canonicalText,
        '(?m)^(\s*PIPELINE_VERSION:\s*)["'']?[0-9]+\.[0-9]+\.[0-9]+["'']?\s*$',
        "`$1`"$target`""
    )
    if ($canonicalNew -ne $canonicalText -and $PSCmdlet.ShouldProcess($CanonicalWorkflow, "Set PIPELINE_VERSION to $target")) {
        [System.IO.File]::WriteAllBytes($canonicalPath, $latin1.GetBytes($canonicalNew))
        $updated += $CanonicalWorkflow
    }
}

foreach ($file in $files) {
    $relative = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName)

    # Hard scope guard: a .ps1 is only ever touched inside .github\, and a .yml
    # only inside .github\workflows or .github\actions.
    if ($file.Extension -eq '.ps1' -and -not $relative.StartsWith(".github$([System.IO.Path]::DirectorySeparatorChar)")) {
        throw "Refusing to touch '$relative': pipeline .ps1 files must live inside .github\."
    }

    $isScript = $file.Extension -eq '.ps1'
    $text = $latin1.GetString([System.IO.File]::ReadAllBytes($file.FullName))

    # Only the version token changes; the rest of every line is preserved.
    $aligned = $text
    if ($text -match $versionPattern) {
        $aligned = [regex]::Replace($text, $versionPattern, "V$target")
    }

    $changed = $aligned -ne $text
    $needsHeader = $false

    # A pipeline script without the canonical header is drift too: without this
    # rule a brand new .ps1 would stay silently unversioned forever, and -Check
    # would keep passing.
    if ($isScript -and $aligned -notmatch $headerPattern) {
        $aligned = Add-PipelineHeader -Text $aligned -Version $target
        $changed = $true
        $needsHeader = $true
    }

    if (-not $changed) { continue }

    if ($Check) {
        $drift += $relative
        if ($needsHeader) { $missingHeader += $relative }
        continue
    }
    if ($PSCmdlet.ShouldProcess($relative, "Set pipeline version to V$target")) {
        [System.IO.File]::WriteAllBytes($file.FullName, $latin1.GetBytes($aligned))
        $updated += $relative
        if ($needsHeader) { $headerAdded += $relative }
    }
}

if ($Check) {
    if ($drift.Count -gt 0) {
        Write-Host "::error::Pipeline version drift against V$target in: $($drift -join ', ')"
        if ($missingHeader.Count -gt 0) {
            Write-Host "::error::Missing '# WinToolkit CI/CD V$target' header in: $($missingHeader -join ', ')"
        }
        throw "Pipeline version is not aligned with V$target. Run Update-PipelineVersion.ps1 locally and commit. Drifted files: $($drift -join ', ')"
    }
    Write-Host "Pipeline version aligned: V$target"
    return
}

Write-Host "Pipeline version V$target"
if ($updated.Count -gt 0) {
    Write-Host "Updated: $($updated -join ', ')"
}
if ($headerAdded.Count -gt 0) {
    Write-Host "Header added to $($headerAdded.Count) script(s): $($headerAdded -join ', ')"
}
if ($updated.Count -eq 0) {
    Write-Host 'Nothing to update: every workflow, action and pipeline script is already aligned.'
}

# Machine-readable result for the workflow steps: one relative path per line.
# Written last, and only in align mode, so a caller can never act on a stale list.
if ($ChangedFileListPath) {
    [System.IO.File]::WriteAllLines(
        $ChangedFileListPath,
        [string[]]@($updated),
        [System.Text.UTF8Encoding]::new($false)
    )
}
