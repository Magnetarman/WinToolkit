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
        catch {
            Write-Warning "start.ps1, Get-WorkingPwsh: $($_.Exception.Message)"
        }
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

function Test-DefenderActive {
    <#
    .SYNOPSIS
    Returns $true when real-time protection is currently enabled.
    #>
    try {
        $status = Get-MpComputerStatus -ErrorAction Stop
        return [bool]$status.RealTimeProtectionEnabled
    }
    catch {
        # Defender is not installed or its service is unavailable: nothing to warn about.
        return $false
    }
}

function Request-DefenderPause {
    <#
    .SYNOPSIS
    Warns that Windows Defender is active and waits for the user to disable it.

    .DESCRIPTION
    Active real-time protection interferes with the AppX and WinGet installs this
    starter performs. The check is NOT blocking: the setup continues either way.
    Pressing ENTER three times in a row bypasses it, so a user who keeps Defender
    enabled (by policy, or by choice) is never trapped in a prompt loop. A
    non-interactive session skips the prompt instead of blocking on a key that
    will never arrive.

    The same check is repeated inside start-core.ps1, because this stub can be
    bypassed: the core is a published script that anyone can invoke directly.
    #>
    if (-not (Test-DefenderActive)) { return }

    # Never prompt when input is redirected (piped, scheduled, or CI): the key
    # would never come and the run would hang instead of continuing.
    if ([Console]::IsInputRedirected) {
        Write-Warning 'Windows Defender e attivo: la protezione in tempo reale potrebbe causare il fallimento di alcune installazioni.'
        return
    }

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Write-Host ("[Defender] Protezione in tempo reale attiva: si consiglia di disattivarla temporaneamente. Premi INVIO dopo averlo disattivato, oppure premilo di nuovo per continuare comunque ($attempt/$maxAttempts).") -ForegroundColor Yellow
        $null = Read-Host 'Premi INVIO'
        if (-not (Test-DefenderActive)) {
            Write-Host '[Defender] Protezione in tempo reale disattivata: si prosegue.' -ForegroundColor Green
            return
        }
    }
    Write-Warning 'Windows Defender e ancora attivo: si prosegue comunque. Alcune installazioni potrebbero fallire.'
}

$env:WTOOLKIT_LANGUAGE = $Language
Request-DefenderPause

# Capture the INTERACTIVE user context BEFORE elevating. UAC may switch the process
# to a different administrator account; without this, every user-scoped artifact
# (Documents\PowerShell profile, Oh My Posh theme, desktop shortcut) would be
# written to that other account and the user would see nothing on their own desktop
# even though the log reported every step as successful.
function Get-InteractiveUserContext {
    $desktop = ''
    $documents = ''
    try { $desktop = [Environment]::GetFolderPath('Desktop', [Environment+SpecialFolderOption]::Create) } catch { }
    try { $documents = [Environment]::GetFolderPath('MyDocuments', [Environment+SpecialFolderOption]::Create) } catch { }
    return @{
        User        = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        UserProfile = $env:USERPROFILE
        Desktop     = $desktop
        MyDocuments = $documents
    }
}

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

    $userContext = Get-InteractiveUserContext
    $langArg = "-Language '$($Language.Replace("'", "''"))'"
    $elevatedCommand = @"
try {
    `$env:WTOOLKIT_LANGUAGE = '$($Language.Replace("'", "''"))'
    `$env:WTOOLKIT_ORIGINAL_USER = '$($userContext.User.Replace("'", "''"))'
    `$env:WTOOLKIT_ORIGINAL_USERPROFILE = '$($userContext.UserProfile.Replace("'", "''"))'
    `$env:WTOOLKIT_ORIGINAL_DESKTOP = '$($userContext.Desktop.Replace("'", "''"))'
    `$env:WTOOLKIT_ORIGINAL_MYDOCUMENTS = '$($userContext.MyDocuments.Replace("'", "''"))'
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
