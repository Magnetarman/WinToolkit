# WinToolkit launcher. Keep this file ASCII-only and compatible with Windows PowerShell 5.1.
[CmdletBinding()]
param(
    [string]$Language = 'Auto'
)

$CoreScriptUrl = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/start-core.ps1'
$StubScriptUrl = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/start.ps1'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WorkingPwsh {
    $candidates = @()
    $command = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($command -and $command.Source) { $candidates += $command.Source }
    $candidates += (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe')
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'PowerShell\7\pwsh.exe')
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        try {
            $version = & $candidate -NoLogo -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.Major' 2>$null
            if ($LASTEXITCODE -eq 0 -and [int]$version -ge 7) { return $candidate }
        }
        catch { }
    }
    return $null
}

function Install-Pwsh {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        $wingetProcess = Start-Process -FilePath $winget.Source -ArgumentList @(
            'install', '--id', 'Microsoft.PowerShell', '--source', 'winget',
            '--accept-source-agreements', '--accept-package-agreements', '--silent'
        ) -Wait -PassThru -NoNewWindow
        if ($wingetProcess.ExitCode -eq 0) {
            $installed = Get-WorkingPwsh
            if ($installed) { return $installed }
        }
    }

    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -UseBasicParsing -ErrorAction Stop
    $asset = $release.assets | Where-Object { $_.name -match 'win-x64\.msi$' } | Select-Object -First 1
    if (-not $asset) { throw 'No PowerShell 7 x64 MSI was found in the latest release.' }

    $msiPath = Join-Path $env:TEMP 'WinToolkit-PowerShell7.msi'
    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $msiPath -UseBasicParsing -ErrorAction Stop
        $msiProcess = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', $msiPath, '/qn', '/norestart') -Wait -PassThru
        if ($msiProcess.ExitCode -notin @(0, 3010)) { throw "PowerShell 7 MSI failed with exit code $($msiProcess.ExitCode)." }
    }
    finally {
        Remove-Item -LiteralPath $msiPath -Force -ErrorAction SilentlyContinue
    }

    $installed = Get-WorkingPwsh
    if (-not $installed) { throw 'PowerShell 7 installation completed but pwsh could not be verified.' }
    return $installed
}

$env:WTOOLKIT_LANGUAGE = $Language

if (-not (Test-IsAdministrator)) {
    # Always relaunch the elevated process on PowerShell 7 (installing it first
    # if needed). This avoids running the (UTF-8 + emoji) core under Windows
    # PowerShell 5.1, which cannot parse the file reliably (see design notes).
    $elevatedHost = Get-WorkingPwsh
    if (-not $elevatedHost) { $elevatedHost = Install-Pwsh }
    if (-not $elevatedHost) {
        Write-Error "Could not find or install the required PowerShell 7 to continue."
        Read-Host -Prompt 'Premi INVIO per chiudere'
        exit 1
    }

    $langArg = "-Language '$($Language.Replace("'", "''"))'"
    $elevatedCommand = @"
try {
    `$env:WTOOLKIT_LANGUAGE = '$($Language.Replace("'", "''"))'
    if ('$PSCommandPath') {
        & '$($PSCommandPath.Replace("'", "''"))' $langArg
    }
    else {
        `$s = irm '$($StubScriptUrl.Replace("'", "''"))'; & ([scriptblock]::Create(`$s)) $langArg
    }
    exit `$LASTEXITCODE
}
catch {
    Write-Error "`$_"
    Read-Host -Prompt 'Elevation failed. Press ENTER to close'
    exit 1
}
"@

    $elevatedProcess = Start-Process -FilePath $elevatedHost -ArgumentList @(
        '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $elevatedCommand
    ) -Verb RunAs -PassThru
    if ($elevatedProcess) { $elevatedProcess.WaitForExit() }
    exit 0
}

$pwsh = Get-WorkingPwsh
if (-not $pwsh) { $pwsh = Install-Pwsh }

$coreCommand = '$s = irm ''' + $CoreScriptUrl + '''; & ([scriptblock]::Create($s))'
$coreProcess = Start-Process -FilePath $pwsh -ArgumentList @(
    '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $coreCommand
) -Wait -PassThru
exit $coreProcess.ExitCode