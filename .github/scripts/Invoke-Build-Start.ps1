<#
.SYNOPSIS
    Builds start-core.ps1 by concatenating the ordered start-modules fragments.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$SourceDir = 'start-modules',
    [string]$OutputPath = 'start-core.ps1',

    [switch]$Minify = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-BuildLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Header')]
        [string]$Type = 'Info'
    )

    $colors = @{
        Info = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red'; Header = 'Magenta'
    }
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] $Message" -ForegroundColor $colors[$Type]
}

function Get-FileStats {
    param([Parameter(Mandatory = $true)][string]$Path)
    $item = Get-Item -LiteralPath $Path
    $content = Get-Content -Raw -LiteralPath $Path
    return @{
        Bytes = $item.Length
        Lines = ($content -split "`r?`n").Count
    }
}

function Write-GitHubOutput {
    param([Parameter(Mandatory = $true)][string]$Name, [Parameter(Mandatory = $true)][object]$Value)
    if ($env:GITHUB_OUTPUT) {
        "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    }
}

try {
    $sourceRoot = (Resolve-Path -LiteralPath $SourceDir -ErrorAction Stop).Path
    $files = @(Get-ChildItem -LiteralPath $sourceRoot -Filter '*.ps1' -File | Sort-Object Name)
    $header = @($files | Where-Object Name -eq '00-Skeleton.Header.ps1')
    $main = @($files | Where-Object Name -eq '90-Skeleton.Main.ps1')

    if ($files.Count -eq 0) { throw "No PowerShell fragments found in '$SourceDir'." }
    if ($header.Count -ne 1) { throw "Expected exactly one 00-Skeleton.Header.ps1 in '$SourceDir'." }
    if ($main.Count -ne 1) { throw "Expected exactly one 90-Skeleton.Main.ps1 in '$SourceDir'." }

    Write-BuildLog -Message "Building start-core.ps1 from $($files.Count) fragments." -Type Header
    $parts = foreach ($file in $files) {
        $relative = Join-Path $SourceDir $file.Name
        @(
            '# ============================================================',
            "# SOURCE: $relative",
            '# ============================================================',
            (Get-Content -Raw -LiteralPath $file.FullName).TrimEnd(),
            ''
        ) -join "`r`n"
    }

    $content = ($parts -join "`r`n")
    $escapedVersion = $Version.Replace('$', '`$').Replace('"', '`"')
    $versionPattern = '(?m)^\$ToolkitVersion\s*=\s*"[^"]*"'
    if ($content -notmatch $versionPattern) { throw 'ToolkitVersion placeholder was not found in start-modules.' }
    $content = [regex]::Replace($content, $versionPattern, ('$ToolkitVersion = "' + $escapedVersion + '"'), 1)

    # Tokenizer-safe minification (mirrors compiler.ps1): strip comment tokens,
    # trim trailing whitespace and drop blank lines. The result is verified with
    # the PowerShell parser and rolled back to the original content on any
    # post-minification syntax error, so a compact start-core.ps1 is always
    # syntactically safe.
    if ($Minify) {
        Write-BuildLog -Message 'Applying tokenizer-safe minification...' -Type Info
        try {
            $backupContent = $content
            $parseErrors = $null
            $tokens = $null
            [System.Management.Automation.Language.Parser]::ParseInput(
                $content, [ref]$tokens, [ref]$parseErrors
            ) | Out-Null

            if ($parseErrors.Count -gt 0) {
                Write-BuildLog -Message "Source has $($parseErrors.Count) pre-existing parse error(s); minification applied anyway." -Type Warning
            }

            $commentTokens = $tokens |
                Where-Object { $_.Kind -eq 'Comment' } |
                Sort-Object { $_.Extent.StartOffset } -Descending

            foreach ($token in $commentTokens) {
                $start = $token.Extent.StartOffset
                $length = $token.Extent.EndOffset - $start
                $content = $content.Remove($start, $length)
            }

            Write-BuildLog -Message "Removed $($commentTokens.Count) comment tokens." -Type Info

            $minifiedLines = ($content -split "`n") |
                ForEach-Object { $_.TrimEnd() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

            $verifyErrors = $null
            $verifyTokens = $null
            [System.Management.Automation.Language.Parser]::ParseInput(
                ($minifiedLines -join "`n"), [ref]$verifyTokens, [ref]$verifyErrors
            ) | Out-Null

            if ($verifyErrors.Count -gt 0) {
                Write-BuildLog -Message "Post-minification syntax error(s) detected; rolling back to original source." -Type Warning
                $content = $backupContent
            }
            else {
                $content = $minifiedLines -join "`r`n"
                Write-BuildLog -Message "Minification completed: $($minifiedLines.Count) lines, no syntax errors." -Type Success
            }
        }
        catch {
            Write-BuildLog -Message "Unexpected error during minification ($($_.Exception.Message)); keeping original source." -Type Warning
        }
    }

    $outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
    $outputDirectory = Split-Path -Parent $outputFullPath
    if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($outputFullPath, $content, [System.Text.UTF8Encoding]::new($false))

    $sourceBytes = ($files | ForEach-Object { (Get-FileStats -Path $_.FullName).Bytes } | Measure-Object -Sum).Sum
    $outputStats = Get-FileStats -Path $outputFullPath
    $sourceKb = [math]::Round($sourceBytes / 1KB, 2)
    $outputKb = [math]::Round($outputStats.Bytes / 1KB, 2)
    Write-BuildLog -Message "Source: $sourceKb KB; output: $outputKb KB; lines: $($outputStats.Lines)." -Type Success

    Write-GitHubOutput -Name 'source_kb' -Value $sourceKb
    Write-GitHubOutput -Name 'output_kb' -Value $outputKb
    Write-GitHubOutput -Name 'source_files' -Value $files.Count
    Write-GitHubOutput -Name 'output_lines' -Value $outputStats.Lines
    exit 0
}
catch {
    Write-BuildLog -Message $_.Exception.Message -Type Error
    exit 1
}
