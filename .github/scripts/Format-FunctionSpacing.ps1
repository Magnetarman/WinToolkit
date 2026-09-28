# Blank-line normalizer for compiled PowerShell artefacts. Guarantees exactly two
# blank lines before every top-level function, at most two blank lines anywhere
# else, no trailing whitespace, and no trailing blank lines. Here-string payloads
# (and block comments) are copied verbatim. Verifies syntax after formatting and
# rolls back to the original content on error.

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
    Write-Verbose "Format-FunctionSpacing: input has $($parseErrors.Count) pre-existing parse error(s); formatting applied anyway."
}

$newLine = "`r`n"
$blankLinesBeforeFunction = 2
$maxBlankLines = 2

$formatted = [System.Collections.Generic.List[string]]::new()
$pendingBlanks = 0
$hereStringClose = $null
$inBlockComment = $false

foreach ($line in ($Content -split "`r`n|`n")) {
    # Everything inside a here-string or a block comment is payload: keep it as is.
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

    # A top-level function always gets exactly the standard separation (this is
    # what restores the spacing on minified output, where blank lines are gone);
    # anywhere else, pending blank lines are only capped.
    $required = [Math]::Min($pendingBlanks, $maxBlankLines)
    if ($line.StartsWith('function ')) { $required = $blankLinesBeforeFunction }
    if ($formatted.Count -gt 0) {
        for ($i = 0; $i -lt $required; $i++) { $formatted.Add('') }
    }
    $pendingBlanks = 0
    $formatted.Add($trimmed)

    # Track an unterminated here-string opener: @" or @' at the end of a line.
    if ($line -cmatch '(@"|@\'')\s*$') { $hereStringClose = $Matches[1].Substring(1) + '@' }
    elseif ($trimmed.StartsWith('<#') -and -not $trimmed.EndsWith('#>')) { $inBlockComment = $true }
}

$result = $formatted -join $newLine

$verifyErrors = $null
$verifyTokens = $null
[System.Management.Automation.Language.Parser]::ParseInput(
    $result, [ref]$verifyTokens, [ref]$verifyErrors
) | Out-Null

if ($verifyErrors.Count -gt 0) {
    Write-Verbose "Format-FunctionSpacing: post-formatting syntax error(s) detected; rolling back to original content."
    return $backup
}

return $result
