# WinToolkit launcher. Keep this file ASCII-only and compatible with Windows PowerShell 5.1.
[CmdletBinding()]
param(
    [string]$Language = 'Auto',

    # Diagnostics only: print the detected identity context and exit without
    # installing anything. Used by the Pester suite and by manual triage.
    [switch]$PrintContext
)

# Result codes reported by the launcher. The PROCESS exit code stays 0 on an
# unsupported machine, so an automated invocation is never red for a condition
# that is not an error; the dedicated code is printed on a stable, greppable line
# ("[WinToolkit] result=<code> reason=<reason>") and in the log.
$script:LauncherResultCodes = @{
    Ready                    = 0
    UnsupportedInteractiveUser = 4
}

$CoreScriptUrl = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/start-core.ps1'
$StubScriptUrl = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/start.ps1'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}


function Get-AccountShortName {
    <#
    .SYNOPSIS
    Returns the bare account name, without domain or host prefix.

    .DESCRIPTION
    Win32_ComputerSystem.UserName has no prefix, WindowsIdentity.Name always has
    one, and the two are compared to decide whether the account that launched the
    script is the account signed in to Windows.
    #>
    param([string]$AccountName)

    if ([string]::IsNullOrWhiteSpace($AccountName)) { return '' }
    $trimmed = $AccountName.Trim()
    $index = $trimmed.LastIndexOf('\')
    if ($index -ge 0) { $trimmed = $trimmed.Substring($index + 1) }
    return $trimmed
}


function Get-AccountSid {
    <#
    .SYNOPSIS
    Returns the SID of an account, or $null when it cannot be resolved.
    #>
    param([string]$AccountName)

    if ([string]::IsNullOrWhiteSpace($AccountName)) { return $null }
    try {
        $account = New-Object Security.Principal.NTAccount($AccountName.Trim())
        return $account.Translate([Security.Principal.SecurityIdentifier]).Value
    }
    catch {
        return $null
    }
}


function Get-LocalAdministratorGroupName {
    <#
    .SYNOPSIS
    Returns the local Administrators group name, in the current system language.

    .DESCRIPTION
    Get-LocalGroup -SID is the authoritative source: it returns the real local
    name ("Administrators", "Amministratori", "Administratoren"...), which is what
    both Get-LocalGroupMember and net.exe accept. Translating the well-known SID
    alone is NOT enough: on a localized system it yields "BUILTIN\Administrators",
    a name that neither of them resolves. The translation, stripped of that
    prefix, and finally the literal English name are kept as fallbacks for systems
    without the LocalAccounts module.
    #>
    try {
        $group = Get-LocalGroup -SID 'S-1-5-32-544' -ErrorAction Stop
        if ($group -and $group.Name) { return $group.Name }
    }
    catch {
        Write-Verbose "Get-LocalGroup -SID failed, falling back to SID translation: $($_.Exception.Message)"
    }

    try {
        $sid = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
        $name = [string]$sid.Translate([Security.Principal.NTAccount]).Value
        $index = $name.LastIndexOf('\')
        if ($index -ge 0) { $name = $name.Substring($index + 1) }
        if ($name) { return $name }
    }
    catch {
        Write-Verbose "SID translation failed: $($_.Exception.Message)"
    }

    # Last resort: Windows always resolves the English name of a well-known group.
    return 'Administrators'
}


function Test-LocalAdministrator {
    <#
    .SYNOPSIS
    Returns $true when the account is a member of the local Administrators group.

    .DESCRIPTION
    Membership is compared by SID, never by name, so a display name that looks
    like a group cannot produce a false positive. When the LocalAccounts module
    is unavailable the check falls back to net.exe, which also expands the
    domain groups that Get-LocalGroupMember does not resolve.
    #>
    param([string]$AccountName)

    if ([string]::IsNullOrWhiteSpace($AccountName)) { return $false }

    $targetSid = Get-AccountSid -AccountName $AccountName
    $groupName = Get-LocalAdministratorGroupName

    if ($targetSid -and $groupName) {
        try {
            $members = @(Get-LocalGroupMember -Group $groupName -ErrorAction Stop)
            foreach ($member in $members) {
                if ($member.SID -and $member.SID.Value -eq $targetSid) { return $true }
            }
            return $false
        }
        catch {
            Write-Verbose "Get-LocalGroupMember failed, falling back to net.exe: $($_.Exception.Message)"
        }
    }

    if (-not $groupName) { return $false }

    try {
        $members = @(& net.exe localgroup "$groupName" 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $members) { return $false }
        foreach ($line in $members) {
            $candidate = ($line -replace '^\s+', '').Trim()
            if (-not $candidate) { continue }
            if ($candidate -match '^-{2,}\s*$') { continue }
            # Header and completion lines, in the languages this script ships.
            if ($candidate -match '^(Alias|Gruppo|Group|Command|Al )') { continue }
            if ((Get-AccountShortName $candidate) -ieq (Get-AccountShortName $AccountName)) { return $true }
        }
        return $false
    }
    catch {
        Write-Verbose "net.exe localgroup failed: $($_.Exception.Message)"
        return $false
    }
}


function Get-InteractiveUserName {
    <#
    .SYNOPSIS
    Returns the account signed in to Windows, which is NOT necessarily the one
    running this process.

    .DESCRIPTION
    With UAC credentials the console session keeps the standard account while the
    elevated process runs as an administrator: they are two different users, and
    every personalized artifact belongs to the session owner. Falls back to the
    current account when the console owner cannot be read.
    #>
    try {
        $system = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $name = [string]$system.UserName
        if (-not [string]::IsNullOrWhiteSpace($name)) { return $name.Trim() }
    }
    catch {
        Write-Verbose "Win32_ComputerSystem.UserName unavailable: $($_.Exception.Message)"
    }
    return [Security.Principal.WindowsIdentity]::GetCurrent().Name
}


function Get-InteractiveUserContext {
    <#
    .SYNOPSIS
    Returns the identity and the user-scoped paths of the signed-in account.

    .DESCRIPTION
    Exported through the WTOOLKIT_ORIGINAL_* variables so that user-scoped
    artifacts (Documents profile, theme, desktop shortcut) land in the account
    that will use the machine. The profile root is read from Win32_UserProfile,
    because it is not always C:\Users\<name>.
    #>
    $user = Get-InteractiveUserName
    $desktop = ''
    $documents = ''
    $userProfile = ''

    try { $desktop = [Environment]::GetFolderPath('Desktop', [Environment+SpecialFolderOption]::Create) } catch { }
    try { $documents = [Environment]::GetFolderPath('MyDocuments', [Environment+SpecialFolderOption]::Create) } catch { }

    $sid = Get-AccountSid -AccountName $user
    if ($sid) {
        try {
            $profile = Get-CimInstance -ClassName Win32_UserProfile -Filter "SID='$sid'" -ErrorAction Stop
            if ($profile.LocalPath) { $userProfile = $profile.LocalPath }
        }
        catch {
            Write-Verbose "Win32_UserProfile unavailable for ${user}: $($_.Exception.Message)"
        }
    }
    if (-not $userProfile) {
        # Valid because the launcher only reaches this point when the signed-in
        # account is the one running the process.
        $userProfile = $env:USERPROFILE
    }

    return @{
        User        = $user
        UserProfile = $userProfile
        Desktop     = $desktop
        MyDocuments = $documents
    }
}


function Get-InteractiveUserSupport {
    <#
    .SYNOPSIS
    Decides whether this account/machine combination is supported.

    .DESCRIPTION
    The toolkit personalizes PowerShell, Windows Terminal and the desktop, and
    every one of those is written under the account that runs the process. A
    standard account elevated with administrator credentials therefore gets a log
    full of successes and, after the reboot, a machine that looks untouched. The
    only supported configuration is: the signed-in account IS the account running
    the script, and it is a local administrator.
    #>
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $interactiveUser = Get-InteractiveUserName
    $isAdmin = Test-LocalAdministrator -AccountName $interactiveUser
    $sameAccount = (Get-AccountShortName $currentUser) -ieq (Get-AccountShortName $interactiveUser)

    $reason = $null
    if (-not $isAdmin) { $reason = 'NotLocalAdministrator' }
    elseif (-not $sameAccount) { $reason = 'AccountMismatch' }

    return [pscustomobject]@{
        CurrentUser        = $currentUser
        InteractiveUser    = $interactiveUser
        InteractiveIsAdmin = $isAdmin
        SameAccount        = $sameAccount
        Supported          = (-not $reason)
        Reason             = $reason
    }
}


function Get-LauncherLogPath {
    <#
    .SYNOPSIS
    Returns the path of the launcher diagnostic log, or $null when it cannot be created.

    .DESCRIPTION
    The file name reuses the scheme of the core logger (10-Module.Logging.ps1:
    <Tool>_<yyyyMMdd-HHmmss>_<pid>.log) and the same folder, so a user asked to
    send their logs ends up with one consistent set of files.

    The launcher runs BEFORE elevation and is the only script that still has to
    work on a machine where nothing is installed yet, so every failure here is
    swallowed: a log that cannot be created must never be the reason the launcher
    stops working.
    #>
    try {
        $logDir = Join-Path $env:LOCALAPPDATA 'WinToolkit\logs'
        if (-not (Test-Path -LiteralPath $logDir)) {
            $null = New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop
        }
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        return (Join-Path $logDir "WinToolkitLauncher_${stamp}_$PID.log")
    }
    catch {
        Write-Verbose "Launcher log unavailable: $($_.Exception.Message)"
        return $null
    }
}


function Write-LauncherLog {
    <#
    .SYNOPSIS
    Appends lines to the launcher log, on a best-effort basis.

    .DESCRIPTION
    Never throws and never writes to the console: the log is a diagnostic aid,
    and a read-only or missing folder must degrade to "no log" instead of
    breaking the launcher the user is trying to run.
    #>
    param(
        [AllowNull()][string]$Path,
        [AllowEmptyCollection()][string[]]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (-not $Line) { return }

    try {
        Add-Content -LiteralPath $Path -Value $Line -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Verbose "Launcher log write failed: $($_.Exception.Message)"
    }
}


function Write-LauncherLogHeader {
    <#
    .SYNOPSIS
    Writes the launcher log header: the context needed to triage a failed run.

    .DESCRIPTION
    Written on EVERY launcher start, on a refused run as well as on a successful
    one, so the file alone answers "what ran, as whom, against which artifact".

    CoreUrl is recorded on purpose: the launcher always downloads start-core.ps1
    from the branch hardcoded at the top of this file, so a user reporting a
    problem is very often running an artifact that does not match the sources
    they are editing. That single line is what makes the mismatch visible.

    ASCII only: this file runs under Windows PowerShell 5.1 before elevation.
    #>
    param(
        [Parameter(Mandatory = $true)][object]$Support,
        [AllowNull()][string]$Path
    )

    $osVersion = $null
    $osBuild = $null
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $osVersion = $os.Version
        $osBuild = $os.BuildNumber
    }
    catch {
        Write-Verbose "OS information unavailable: $($_.Exception.Message)"
    }

    Write-LauncherLog -Path $Path -Line @(
        '================================================================'
        '[START WINTOOLKIT LAUNCHER]'
        ("StartTime      : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        ("Launcher       : {0}" -f $PSCommandPath)
        ("CoreUrl        : {0}" -f $CoreScriptUrl)
        ("PSVersion      : {0} ({1})" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)
        ("OS             : {0} (build {1})" -f $(if ($osVersion) { $osVersion } else { 'unknown' }),
            $(if ($osBuild) { $osBuild } else { 'unknown' }))
        ("SignedInUser   : {0}" -f $Support.InteractiveUser)
        ("RunningAs      : {0}" -f $Support.CurrentUser)
        ("Elevated       : {0}" -f (Test-IsAdministrator))
        ("SameAccount    : {0}" -f $Support.SameAccount)
        ("LocalAdmin     : {0}" -f $Support.InteractiveIsAdmin)
        ("Supported      : {0}" -f $Support.Supported)
        ("Reason         : {0}" -f $(if ($Support.Reason) { $Support.Reason } else { 'none' }))
        ("LogFile        : {0}" -f $(if ($Path) { $Path } else { 'unavailable' }))
        '================================================================'
    )
}


function Write-InteractiveUserSupport {
    <#
    .SYNOPSIS
    Reports the detected identity context and stops the run on an unsupported
    machine, before anything is installed or changed.

    .DESCRIPTION
    A refused run used to leave the user with nothing on screen to read (the
    window closed with the console) and, before this log existed, with nothing on
    disk either. The reason and the identity context are therefore appended to the
    launcher log before exiting, and on an interactive console the exit waits for
    a keypress so the explanation is still readable.

    The wait is skipped when the input is redirected (CI, scheduled task,
    irm|iex): there is no console to hold open there, and a missing keypress
    would hang the run forever.
    #>
    param(
        [Parameter(Mandatory = $true)][object]$Support,
        [AllowNull()][string]$LogPath
    )

    Write-Host ("[WinToolkit] Signed-in user : {0} (local administrator: {1})" -f
        $Support.InteractiveUser, $(if ($Support.InteractiveIsAdmin) { 'yes' } else { 'no' }))
    Write-Host ("[WinToolkit] Running as      : {0}" -f $Support.CurrentUser)

    if ($Support.Supported) { return }

    Write-Host ''
    Write-Host 'WinToolkit: unsupported configuration, nothing has been installed.' -ForegroundColor Yellow
    Write-Host ''
    if ($Support.Reason -eq 'NotLocalAdministrator') {
        Write-Host 'The signed-in Windows account is not a member of the local Administrators'
        Write-Host 'group. This script personalizes PowerShell, Windows Terminal and the'
        Write-Host 'desktop, and an elevated standard account would receive every setting in'
        Write-Host 'the administrator profile instead, with nothing left after the reboot.'
    }
    else {
        Write-Host 'The script is running under a different account than the one signed in to'
        Write-Host 'Windows. Every personal setting would be written to the wrong profile.'
    }
    Write-Host ''
    Write-Host 'What to do: open PowerShell from the signed-in account and run this script'
    Write-Host 'again. Do not use "Run as administrator" with a different user.'
    Write-Host ''
    Write-Host ("[WinToolkit] result={0} reason={1}" -f $script:LauncherResultCodes.UnsupportedInteractiveUser, $Support.Reason)

    # The refusal is the one event that leaves no other trace behind, so it is
    # written to the log explicitly: reason and result code close the file.
    Write-LauncherLog -Path $LogPath -Line @(
        '[GATE] Refused: unsupported configuration. Nothing has been installed.'
        ("[GATE] Reason        : {0}" -f $Support.Reason)
        ("[GATE] result        : {0}" -f $script:LauncherResultCodes.UnsupportedInteractiveUser)
        '[END WINTOOLKIT LAUNCHER]'
    )

    if ($LogPath) {
        Write-Host ("[WinToolkit] Log          : {0}" -f $LogPath)
    }

    # Hold an interactive console open: the window would otherwise close on exit
    # and the explanation above would disappear with it.
    if (-not [Console]::IsInputRedirected) {
        $null = Read-Host -Prompt 'Premi INVIO per chiudere'
    }

    exit 0
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


function Get-PwshVersion {
    <#
    .SYNOPSIS
    Returns the version of a PowerShell 7 executable, or $null when it cannot be
    read. The version is queried from the host itself, not from the file metadata.
    #>
    param([string]$Path)

    if (-not $Path) { return $null }
    try {
        $raw = & $Path -NoLogo -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()' 2>$null
        if ($LASTEXITCODE -eq 0 -and $raw) {
            $value = ([string]$raw[0]).Trim()
            if ($value -match '^\d+\.\d+\.\d+') { return [version]$Matches[0] }
        }
    }
    catch {
        Write-Verbose "Could not read the PowerShell version from ${Path}: $($_.Exception.Message)"
    }
    return $null
}


function Get-LatestPowerShellVersion {
    <#
    .SYNOPSIS
    Returns the latest stable PowerShell 7 version, or $null when the release feed
    cannot be read. "latest" excludes pre-releases, so this is the stable line.
    #>
    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -UseBasicParsing -ErrorAction Stop
        $tag = [string]$release.tag_name
        if ($tag -match '^v?(\d+\.\d+\.\d+)') { return [version]$Matches[1] }
    }
    catch {
        Write-Verbose "PowerShell release feed unavailable: $($_.Exception.Message)"
    }
    return $null
}


function Sync-PowerShellVersion {
    <#
    .SYNOPSIS
    Brings an ALREADY installed PowerShell 7 up to the latest available release
    and returns the executable to use from now on.

    .DESCRIPTION
    start.ps1 used to install PowerShell 7 only when it was missing, so a system
    with an outdated build kept it forever and every new session greeted the user
    with "A new PowerShell stable release is available". WinGet decides on its own
    whether an update exists: exit code 0 covers both "updated" and "nothing to
    do". When WinGet is unavailable the release feed is used to report the gap
    without changing anything.
    #>
    param([string]$Path)

    $current = Get-PwshVersion -Path $Path
    if (-not $current) {
        Write-Host '[WinToolkit] PowerShell 7 version unknown, skipping the version check.' -ForegroundColor Yellow
        return $Path
    }
    Write-Host ("[WinToolkit] PowerShell 7 installed: {0}" -f $current)

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        $process = Start-Process -FilePath $winget.Source -ArgumentList @(
            'upgrade', '--id', 'Microsoft.PowerShell', '--exact',
            '--accept-source-agreements', '--accept-package-agreements',
            '--silent', '--disable-interactivity'
        ) -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0) {
            # The running host keeps the bits it already loaded: the new build is
            # used from the next session, so the path is resolved again here.
            $refreshed = Get-WorkingPwsh
            $updated = Get-PwshVersion -Path $refreshed
            if ($updated) {
                if ($updated -gt $current) {
                    Write-Host ("[WinToolkit] PowerShell 7 updated: {0} -> {1}. The new build is used from the next session." -f $current, $updated) -ForegroundColor Green
                }
                else {
                    Write-Host '[WinToolkit] PowerShell 7 is already up to date.' -ForegroundColor Green
                }
                if ($refreshed) { return $refreshed }
                return $Path
            }
        }
        Write-Host '[WinToolkit] WinGet could not update PowerShell 7, falling back to the release feed.' -ForegroundColor Yellow
    }

    $latest = Get-LatestPowerShellVersion
    if ($latest -and $latest -gt $current) {
        Write-Host ("[WinToolkit] PowerShell 7 {0} is installed but {1} is available." -f $current, $latest) -ForegroundColor Yellow
        Write-Host "[WinToolkit] Run: winget upgrade --id Microsoft.PowerShell --exact"
    }
    else {
        Write-Host '[WinToolkit] PowerShell 7 is already up to date.' -ForegroundColor Green
    }
    return $Path
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

# ---------------------------------------------------------------------------
# Launcher diagnostic log.
#
# Created BEFORE the gate, so a refused run leaves a file behind too: that is
# exactly the case that used to leave the user with an empty screen and no
# evidence at all. Best-effort throughout: a machine where the folder cannot be
# created must still run the launcher.
# ---------------------------------------------------------------------------
$launcherLogPath = Get-LauncherLogPath

# ---------------------------------------------------------------------------
# Supported configuration gate.
#
# It runs BEFORE anything is installed or changed, Defender included, because
# the toolkit personalizes the account that runs the process: when that account
# is not the account signed in to Windows, every setting would be written to
# the wrong profile and the run would still report success.
# ---------------------------------------------------------------------------
$support = Get-InteractiveUserSupport

# The header is written here, after the context is known, and on every run:
# refused or successful alike.
Write-LauncherLogHeader -Support $support -Path $launcherLogPath

if ($PrintContext) {
    # Diagnostics only: the context is printed and the launcher exits without
    # touching the machine. The Pester suite asserts on this output.
    Write-Host ("[WinToolkit] Signed-in user : {0}" -f $support.InteractiveUser)
    Write-Host ("[WinToolkit] Running as      : {0}" -f $support.CurrentUser)
    Write-Host ("[WinToolkit] Local admin     : {0}" -f $support.InteractiveIsAdmin)
    Write-Host ("[WinToolkit] Same account    : {0}" -f $support.SameAccount)
    Write-Host ("[WinToolkit] Supported       : {0}" -f $support.Supported)
    Write-Host ("[WinToolkit] Reason          : {0}" -f $(if ($support.Reason) { $support.Reason } else { 'none' }))
    Write-Host ("[WinToolkit] result={0}" -f $(if ($support.Supported) { $script:LauncherResultCodes.Ready } else { $script:LauncherResultCodes.UnsupportedInteractiveUser }))
    if ($launcherLogPath) {
        Write-Host ("[WinToolkit] Log          : {0}" -f $launcherLogPath)
    }
    exit 0
}

Write-InteractiveUserSupport -Support $support -LogPath $launcherLogPath

$env:WTOOLKIT_LANGUAGE = $Language
Request-DefenderPause

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
if ($pwsh) {
    # Already installed: make sure it is the latest build, not just any build.
    $pwsh = Sync-PowerShellVersion -Path $pwsh
}
else {
    $pwsh = Install-Pwsh
}

$coreCommand = '$s = irm ''' + $CoreScriptUrl + '''; & ([scriptblock]::Create($s))'
$coreProcess = Start-Process -FilePath $pwsh -ArgumentList @(
    '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $coreCommand
) -Wait -PassThru
exit $coreProcess.ExitCode
