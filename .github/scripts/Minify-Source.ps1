# WinToolkit CI/CD Pipeline V 4.0.1 — Shared source minification
# =============================================================================
# Tokenizer-safe PowerShell minification shared by every build entry point
# (compiler.ps1 for WinToolkit.ps1, Invoke-Build-Start.ps1 for start-core.ps1).
#
# Invoked with:  & Minify-Source.ps1 -Content <string>
# It strips comment tokens via the PowerShell parser, trims trailing whitespace
# and drops blank lines. The minified result is re-parsed and, on any
# post-minification syntax error, the original content is returned unchanged so
# the emitted artifact is always syntactically safe. The minified string is
# written to stdout; callers capture it.
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$Content
)

$backup = $Content

$parseErrors = $null
$tokens = $null
[System.Management.Automation.Language.Parser]::ParseInput(
    $Content, [ref]$tokens, [ref]$parseErrors
) | Out-Null

if ($parseErrors.Count -gt 0) {
    Write-Verbose "Minify-Source: source has $($parseErrors.Count) pre-existing parse error(s); minification applied anyway."
}

$commentTokens = $tokens |
    Where-Object { $_.Kind -eq 'Comment' } |
    Sort-Object { $_.Extent.StartOffset } -Descending

foreach ($token in $commentTokens) {
    $start = $token.Extent.StartOffset
    $length = $token.Extent.EndOffset - $start
    $Content = $Content.Remove($start, $length)
}

if ($commentTokens.Count -gt 0) {
    Write-Verbose "Minify-Source: removed $($commentTokens.Count) comment tokens."
}

$minifiedLines = ($Content -split "`n") |
    ForEach-Object { $_.TrimEnd() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

$verifyErrors = $null
$verifyTokens = $null
[System.Management.Automation.Language.Parser]::ParseInput(
    ($minifiedLines -join "`n"), [ref]$verifyTokens, [ref]$verifyErrors
) | Out-Null

if ($verifyErrors.Count -gt 0) {
    Write-Verbose "Minify-Source: post-minification syntax error(s) detected; rolling back to original source."
    return $backup
}

return $minifiedLines -join "`r`n"
