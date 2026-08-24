# Tokenizer-safe PowerShell minifier. Strips comment tokens, trims whitespace, drops blank lines.
# Verifies syntax after minification and rolls back to original on error.

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
