# WinToolkit CI/CD V4.1.0
# Source-only blank-line normalizer. Caps consecutive blank lines at two, removes
# trailing whitespace and trailing blank lines, and leaves a single final newline.
# Here-string payloads and block comments are copied verbatim.
#
# The tool never adds blank lines: it only normalizes what is already there, so
# running it on compliant sources is a guaranteed no-op.
#
# SCOPE: this tool only ever rewrites files inside the two fragment folders
# (start-modules\ and wintoolkit-modules\). Compiled artefacts
# (WinToolkit.ps1, start-core.ps1) are machine-only and must stay compact, so any
# other path is refused. It is never invoked by the build pipeline.
#
# Usage:
#   .\.github\scripts\Format-FunctionSpacing.ps1 -Path start-modules -WhatIf
#   .\.github\scripts\Format-FunctionSpacing.ps1 -Path wintoolkit-modules

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$Path,

    [switch]$Recurse
)

$ErrorActionPreference = 'Stop'

# Repository root, derived from the script location so the guard does not depend
# on the caller's current directory.
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$allowedFolders = @('start-modules', 'wintoolkit-modules')
$forbiddenNames = @('WinToolkit.ps1', 'start-core.ps1')

# Resolves a path and refuses everything outside the fragment folders.
function Resolve-SourceFragment {
    param([string]$Candidate)

    $resolved = Resolve-Path -LiteralPath $Candidate -ErrorAction Stop
    $full = $resolved.Path

    # Compiled artefacts are refused by name as well, belt and braces.
    if ($forbiddenNames -contains (Split-Path -Leaf $full)) {
        throw "Refusing to touch the compiled artefact '$($resolved.Path)': it must stay compact."
    }

    $relative = [System.IO.Path]::GetRelativePath($repoRoot, $full)
    if ($relative.StartsWith('..')) {
        throw "Refusing to touch '$($resolved.Path)': it is outside the repository."
    }

    $rootFolder = ($relative -split '[\\/]')[0]
    if ($allowedFolders -notcontains $rootFolder) {
        throw "Refusing to touch '$($resolved.Path)': only $($allowedFolders -join ' and ') are allowed."
    }
    return $full
}

# Core transformation: returns the formatted content, or the original on error.
function Format-FragmentContent {
    param([string]$Content)

    $parseErrors = $null
    $tokens = $null
    [System.Management.Automation.Language.Parser]::ParseInput(
        $Content, [ref]$tokens, [ref]$parseErrors
    ) | Out-Null

    $formatted = [System.Collections.Generic.List[string]]::new()
    $pendingBlanks = 0
    $hereStringClose = $null
    $inBlockComment = $false

    foreach ($line in ($Content -split "`r`n|`n")) {
        # Everything inside a here-string or a block comment is payload: keep it.
        if ($hereStringClose) {
            $formatted.Add($line)
            if ($line.TrimStart() -eq $hereStringClose) { $hereStringClose = $null }
            continue
        }
        if ($inBlockComment) {
            $formatted.Add($line)
            if ($line.TrimEnd().EndsWith('#>')) { $inBlockComment = $false }
            continue
        }

        $trimmed = $line.TrimEnd()
        if ($trimmed.Length -eq 0) {
            $pendingBlanks++
            continue
        }

        # Cap pending blank lines at two. Nothing is ever inserted: the tool only
        # removes excess, so compliant files stay byte-identical.
        # The loop is explicit because "1..0" would yield 1,0 in PowerShell.
        $required = [Math]::Min($pendingBlanks, 2)
        for ($i = 0; $i -lt $required; $i++) { $formatted.Add('') }
        $pendingBlanks = 0
        $formatted.Add($trimmed)

        # Track an unterminated here-string opener: @" or @' at the end of a line.
        if ($line -cmatch '(@"|@\'')\s*$') { $hereStringClose = $Matches[1].Substring(1) + '@' }
        elseif ($trimmed.StartsWith('<#') -and -not $trimmed.EndsWith('#>')) { $inBlockComment = $true }
    }

    # A source file ends with exactly one newline (.editorconfig
    # insert_final_newline = true), so the join is terminated explicitly.
    $result = ($formatted -join "`r`n") + "`r`n"

    $verifyErrors = $null
    $verifyTokens = $null
    [System.Management.Automation.Language.Parser]::ParseInput(
        $result, [ref]$verifyTokens, [ref]$verifyErrors
    ) | Out-Null

    if ($verifyErrors.Count -gt 0) {
        Write-Host ("DEBUG-VERIFY line=" + $verifyErrors[0].Extent.StartLineNumber + " : " + $verifyErrors[0].Message + " || CONTEXT: [" + $verifyErrors[0].Extent.Text + "]")
        return $Content
    }
    return $result
}

$changed = 0
$skipped = 0

foreach ($target in $Path) {
    $full = Resolve-SourceFragment -Candidate $target
    $item = Get-Item -LiteralPath $full

    $files = if ($item.PSIsContainer) {
        @(Get-ChildItem -LiteralPath $full -Filter '*.ps1' -File -Recurse:$Recurse)
    }
    else { @($item) }

    foreach ($file in $files) {
        # Re-validate: never process a compiled artefact even if enumerated.
        if ($forbiddenNames -contains $file.Name) { continue }

        $content = [System.IO.File]::ReadAllText($file.FullName)
        $formatted = Format-FragmentContent -Content $content
        if ($formatted -eq $content) {
            $skipped++
            continue
        }

        if ($PSCmdlet.ShouldProcess($file.FullName, 'Normalize blank-line spacing')) {
            # UTF-8 without BOM, CRLF: the repository convention for .ps1 files.
            [System.IO.File]::WriteAllText($file.FullName, $formatted, [System.Text.UTF8Encoding]::new($false))
            $changed++
        }
    }
}

Write-Verbose "Format-FunctionSpacing: $changed file(s) formatted, $skipped already compliant."
