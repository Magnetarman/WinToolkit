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
        Write-Error "Impossibile trovare o installare PowerShell 7 richiesto per continuare."
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
    Read-Host -Prompt 'Elevazione fallita. Premi INVIO per chiudere'
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

function Test-WindowsUpdateBlocked {
    # Returns $true when Windows updates are still in progress or a reboot is
    # still pending, which means dependency/core installation must be blocked.

    # 1. Reboot still required (CBS / Windows Update / pending file renames).
    $rebootPending =
        (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
        (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
        ((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations)

    if ($rebootPending) { return $true }

    # 2. Updates still being installed right now (operation in progress).
    try {
        $session  = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()

        $count = $searcher.GetTotalHistoryCount()
        if ($count -gt 0) {
            $history = $searcher.QueryHistory(0, $count)
            foreach ($entry in $history) {
                # Operation 1 = installation, ResultCode 1 = still in progress.
                if ($entry.Operation -eq 1 -and $entry.ResultCode -eq 1) {
                    return $true
                }
            }
        }

        # 3. Pending software updates not yet installed.
        $result = $searcher.Search("IsInstalled=0 and Type='Software'")
        if ($result -and $result.Updates -and $result.Updates.Count -gt 0) {
            return $true
        }
    }
    catch {
        # If the Windows Update API cannot be queried, be conservative and block.
        return $true
    }

    return $false
}

Write-Host ''
Write-Host 'Controllo aggiornamenti di Windows in corso...' -ForegroundColor Cyan
Write-Host 'Per evitare conflitti, l''installazione delle dipendenze e di start-core' -ForegroundColor Yellow
Write-Host 'resta sospesa finche'' gli aggiornamenti di Windows non risultano completati.' -ForegroundColor Yellow

while (Test-WindowsUpdateBlocked) {
    Write-Host ''
    Write-Host "Aggiornamenti di Windows ancora in corso o riavvio necessario. Nuovo controllo tra 5 secondi..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}

Write-Host ''
Write-Host 'Aggiornamenti di Windows completati. Prosecuzione dell''installazione.' -ForegroundColor Green

$coreCommand = '$s = irm ''' + $CoreScriptUrl + '''; & ([scriptblock]::Create($s))'
$coreProcess = Start-Process -FilePath $pwsh -ArgumentList @(
    '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $coreCommand
) -Wait -PassThru
exit $coreProcess.ExitCode
