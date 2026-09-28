# Aligns the pipeline version across every workflow and composite action.
#
# SINGLE SOURCE OF TRUTH: the PIPELINE_VERSION value in the canonical workflow
# (CI-WinToolkit-Dev.yml by default). Edit that one value; this script rewrites
# the "V<major>.<minor>.<patch>" token in every workflow/action name and header
# comment, so the version can never drift between the 14 files.
#
# Usage:
#   .\.github\scripts\Update-PipelineVersion.ps1                 # align (no-op if aligned)
#   .\.github\scripts\Update-PipelineVersion.ps1 -Version 4.0.4  # set and align
#   .\.github\scripts\Update-PipelineVersion.ps1 -Check          # fail if any drift

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Version,

    [string]$CanonicalWorkflow = '.github\workflows\CI-WinToolkit-Dev.yml',

    # Report drift without writing anything; exits non-zero when inconsistent.
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$versionPattern = 'V\d+\.\d+\.\d+'

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
$files = @(
    Get-ChildItem -Path (Join-Path $repoRoot '.github\workflows') -Filter '*.yml' -File
    Get-ChildItem -Path (Join-Path $repoRoot '.github\actions') -Filter 'action.yml' -File -Recurse
)

$updated = @()
$drift = @()

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
    $text = $latin1.GetString([System.IO.File]::ReadAllBytes($file.FullName))
    if ($text -notmatch $versionPattern) { continue }

    # Only the version token changes; the rest of the line is preserved.
    $aligned = [regex]::Replace($text, $versionPattern, "V$target")
    if ($aligned -eq $text) { continue }

    $relative = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName)
    if ($Check) {
        $drift += $relative
        continue
    }
    if ($PSCmdlet.ShouldProcess($relative, "Set pipeline version to V$target")) {
        [System.IO.File]::WriteAllBytes($file.FullName, $latin1.GetBytes($aligned))
        $updated += $relative
    }
}

if ($Check) {
    if ($drift.Count -gt 0) {
        Write-Host "::error::Pipeline version drift against V$target in: $($drift -join ', ')"
        throw "Pipeline version is not aligned with V$target. Run Update-PipelineVersion.ps1 locally and commit. Drifted files: $($drift -join ', ')"
    }
    Write-Host "Pipeline version aligned: V$target"
    return
}

Write-Host "Pipeline version V$target"
if ($updated.Count -gt 0) {
    Write-Host "Updated: $($updated -join ', ')"
}
else {
    Write-Host 'Nothing to update: every workflow and action is already aligned.'
}
