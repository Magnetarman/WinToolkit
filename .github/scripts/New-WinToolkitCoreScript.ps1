# Build WinToolkit framework core by concatenating ordered wintoolkit-modules/*.ps1 fragments.
[CmdletBinding()]
param(
    [string]$ModuleDir = 'wintoolkit-modules',
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

if ($PSScriptRoot) {
    # Script lives in .github/scripts -> repo root is two levels up.
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
else {
    $repoRoot = $PWD.Path
}

$modDir = Join-Path $repoRoot $ModuleDir
if (-not (Test-Path $modDir)) {
    throw "Module directory not found: $modDir"
}

$files = @(Get-ChildItem -Path $modDir -Filter '*.ps1' -File -ErrorAction Stop | Sort-Object Name)
if ($files.Count -eq 0) {
    throw "No PowerShell fragments found in '$modDir'."
}

$lines = foreach ($f in $files) {
    Get-Content -LiteralPath $f.FullName -Encoding UTF8 -ErrorAction Stop
}
$text = $lines -join "`r`n"

if (-not $OutputPath) {
    $OutputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("WinToolkit-core-$([guid]::NewGuid()).ps1")
}

[System.IO.File]::WriteAllText($OutputPath, $text, [System.Text.UTF8Encoding]::new($false))
return $OutputPath
