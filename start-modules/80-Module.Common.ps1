# ============================================================================
# SHARED HELPERS
# ============================================================================

function Test-CommandExists {
    <#
    .SYNOPSIS
    Returns $true when a command name resolves in the current session.
    #>
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}


function Test-LocalRootedPath {
    <#
    .SYNOPSIS
    Returns the normalized path when it is a fully qualified local path, else $null.

    .DESCRIPTION
    Single source of truth for "is this a usable local path". It rejects exactly
    the three shapes that turn an unresolved known folder into files scattered
    outside the user profile:
      ''            -> not bindable, would fail later at an unrelated place
      'C:'/'C:\'    -> the drive root
      '\PowerShell' -> drive-relative: resolves to <current drive>:\PowerShell
    The three conditions are collapsed into one anchored regex: anything that is
    not "X:\..." fails it, which subsumes the previous separate tests.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $trimmed = $Path.Trim().TrimEnd('\')
    if ($trimmed -notmatch '^[A-Za-z]:[\\/]') { return $null }
    return $trimmed
}


function Remove-PathQuietly {
    <#
    .SYNOPSIS
    Deletes one or more paths, ignoring every failure.

    .DESCRIPTION
    Replaces the 18 hand-written `finally { if (Test-Path ...) { Remove-Item } }`
    blocks. Cleanup must never mask the outcome of the operation it belongs to,
    so nothing here is allowed to throw.
    #>
    param(
        [Parameter(Position = 0)][string[]]$Path
    )

    foreach ($item in $Path) {
        if ([string]::IsNullOrWhiteSpace($item)) { continue }
        Remove-Item -LiteralPath $item -Force -Recurse -ErrorAction SilentlyContinue
    }
}


function Initialize-Directory {
    <#
    .SYNOPSIS
    Creates a directory when it is missing, verifies the result, and returns its path.

    .DESCRIPTION
    The verification is the point of this helper: a silent New-Item failure used to
    let the caller carry on and report success for an artifact that was never
$resolved = Test-LocalRootedPath -Path $Path
    if (-not $resolved) {
        throw "Initialize-Directory: refusing to use '$Path' (empty, relative or drive-root path)."
    }
    if (-not (Test-Path -LiteralPath $resolved)) {
        $null = New-Item -Path $resolved -ItemType Directory -Force -ErrorAction Stop
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Initialize-Directory: '$resolved' is not an accessible directory."
    }
    return $resolved
}


function Get-ToolkitOriginalUserContext {
    <#
    .SYNOPSIS
    Returns the interactive user's context, captured by start.ps1 before elevation.

    .DESCRIPTION
    UAC elevation can switch the process to a *different* administrator account
    (credentials are prompted for). Every user-scoped artifact (Documents profile,
    theme, desktop shortcut) would then land in that other account and the user
    would see nothing, even though each step reported success. start.ps1 exports
    the original identity and paths through environment variables; this helper
    reads them once and reports whether the current identity differs.
    #>
    if ($script:OriginalUserContext) { return $script:OriginalUserContext }
    if ($script:State -and $script:State.UserContext) { return $script:State.UserContext }

    $scope = $script:AppConfig.UserScope
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $originalUser = [Environment]::GetEnvironmentVariable($scope.EnvUser)

$script:OriginalUserContext = [pscustomobject]@{
        CurrentUser     = $currentUser
        OriginalUser    = $originalUser
        AccountSwitched = [bool]($originalUser -and $currentUser -and ($originalUser -ne $currentUser))
        Desktop         = [Environment]::GetEnvironmentVariable($scope.EnvDesktop)
        MyDocuments     = [Environment]::GetEnvironmentVariable($scope.EnvMyDocuments)
    }
    if ($script:State) { $script:State.UserContext = $script:OriginalUserContext }
        CurrentUser     = $currentUser
        OriginalUser    = $originalUser
        AccountSwitched = [bool]($originalUser -and $currentUser -and ($originalUser -ne $currentUser))
        UserProfile     = [Environment]::GetEnvironmentVariable($scope.EnvUserProfile)
        Desktop         = [Environment]::GetEnvironmentVariable($scope.EnvDesktop)
        MyDocuments     = [Environment]::GetEnvironmentVariable($scope.EnvMyDocuments)
    }
    return $script:OriginalUserContext
}


function Get-ToolkitUserFolderPath {
    <#
    .SYNOPSIS
    Resolves, creates and verifies a user known folder (Desktop / MyDocuments).

    .DESCRIPTION
    [Environment]::GetFolderPath returns an EMPTY STRING when a known folder cannot
    be resolved (deleted folder, stale "User Shell Folders" value, brand new or
    freshly cleaned profile). The old code concatenated that empty string with
    "\PowerShell" and wrote the profile to <drive>:\PowerShell while reporting
    success. Resolution is now layered, and every candidate is validated:
      1. the interactive user's folder, when elevation switched account;
      2. GetFolderPath with SpecialFolderOption.Create (creates when missing);
      3. GetFolderPath;
      4. the "User Shell Folders" registry value, environment-expanded;
      5. %USERPROFILE% (or the original user's profile).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Desktop', 'MyDocuments')]
        [string]$Kind,

        [switch]$NoCreate
    )

    $context = Get-ToolkitOriginalUserContext
    $candidates = @()

    if ($context.AccountSwitched) {
        $original = if ($Kind -eq 'Desktop') { $context.Desktop } else { $context.MyDocuments }
        if ($original) { $candidates += $original }
    }

    try { $candidates += [Environment]::GetFolderPath($Kind, [Environment+SpecialFolderOption]::Create) }
    catch { Write-ToolkitLog -Level 'DEBUG' -Message "GetFolderPath($Kind, Create) failed: $($_.Exception.Message)" }
    try { $candidates += [Environment]::GetFolderPath($Kind) }
    catch { Write-ToolkitLog -Level 'DEBUG' -Message "GetFolderPath($Kind) failed: $($_.Exception.Message)" }

    $registryName = if ($Kind -eq 'Desktop') { 'Desktop' } else { 'Personal' }
    try {
        $shellKey = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name $registryName -ErrorAction Stop
        if ($shellKey.$registryName) {
            $candidates += [Environment]::ExpandEnvironmentVariables([string]$shellKey.$registryName)
        }
    }
    catch { Write-ToolkitLog -Level 'DEBUG' -Message "User Shell Folders\$registryName unreadable: $($_.Exception.Message)" }

    $profileRoot = if ($context.AccountSwitched -and $context.UserProfile) { $context.UserProfile } else { $env:USERPROFILE }
    if ($profileRoot) { $candidates += (Join-Path $profileRoot $Kind) }

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $path = Test-LocalRootedPath -Path $candidate
        if (-not $path) { continue }

        if ($NoCreate) {
            if (Test-Path -LiteralPath $path -PathType Container) {
                $script:AppConfig.Paths[$Kind] = $path
                return $path
            }
            continue
        }

        try {
            $resolved = Initialize-Directory -Path $path
            $script:AppConfig.Paths[$Kind] = $resolved
            return $resolved
        }
        catch {
            Write-ToolkitLog -Level 'WARNING' -Message "Known folder candidate rejected for ${Kind}: $path ($($_.Exception.Message))"
        }
    }

    throw "Unable to resolve a usable '$Kind' known folder for user '$($context.CurrentUser)'."
}


function Test-FileHasMinimumSize {
    <#
    .SYNOPSIS
    Returns $true only when the file exists and is at least MinimumBytes long.

    .DESCRIPTION
    Guards against partial downloads and HTML error pages saved as binary assets
    (for example a cached .ico that is smaller than any valid icon).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$MinimumBytes
    )

    $file = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    return [bool]($file -and -not $file.PSIsContainer -and $file.Length -ge $MinimumBytes)
}


function Resolve-ToolkitPowerShellProfileDirectory {
    <#
    .SYNOPSIS
    Creates and returns the PowerShell 7 profile folder and its Themes subfolder.

    .DESCRIPTION
    Returns [pscustomobject]@{ ProfileDirectory; ThemesDirectory; ProfilePath;
    ThemePath }. The folder is created even when the Documents known folder is
    empty or missing (freshly reset or brand new profile), and the result is
    verified instead of assumed, so the profile can no longer be reported as
    installed while it was written outside of the user profile.
    #>
    [CmdletBinding()]
    param()

    $scope = $script:AppConfig.UserScope
    $documents = Get-ToolkitUserFolderPath -Kind 'MyDocuments'
    $profileDirectory = Initialize-Directory -Path (Join-Path $documents $scope.PowerShellProfileFolder)
    $themesDirectory = Initialize-Directory -Path (Join-Path $profileDirectory $scope.ThemesFolderName)

    return [pscustomobject]@{
        ProfileDirectory = $profileDirectory
        ThemesDirectory  = $themesDirectory
        ProfilePath      = (Join-Path $profileDirectory $scope.ProfileFileName)
        ThemePath        = (Join-Path $themesDirectory $scope.ThemeFileName)
    }
}


function Copy-FileAtomically {
    <#
    .SYNOPSIS
    Replaces DestinationPath with SourcePath without ever leaving a half-written file.

    .DESCRIPTION
    The copy is staged next to the destination and swapped in with a single move,
    so a reader always sees either the old file or the new one. Returns the backup
    path when -Backup replaced an existing file, otherwise nothing.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [switch]$Backup
    )

    $targetDir = Split-Path -Path $DestinationPath -Parent
    $null = Initialize-Directory -Path $targetDir
    $stagedPath = Join-Path $targetDir "$([IO.Path]::GetFileName($DestinationPath)).$([guid]::NewGuid()).tmp"
    try {
        Copy-Item -LiteralPath $SourcePath -Destination $stagedPath -Force -ErrorAction Stop
        if ($Backup -and (Test-Path -LiteralPath $DestinationPath -PathType Leaf)) {
            $backupPath = "$DestinationPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            [System.IO.File]::Replace($stagedPath, $DestinationPath, $backupPath, $true)
            return $backupPath
        }
        Move-Item -LiteralPath $stagedPath -Destination $DestinationPath -Force -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $stagedPath) { Remove-Item -LiteralPath $stagedPath -Force -ErrorAction SilentlyContinue }
    }
}


function Get-ArchitectureSpecificValue {
    <#
    .SYNOPSIS
    Picks the value matching the real OS architecture (see Get-SystemArchitecture).

    .DESCRIPTION
    Keeps architecture mappings in one place: each caller passes the three variants
    of the string it needs (asset pattern, registry token, installer name), and X64
    is also the fallback for anything that is neither X86 nor ARM64.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$X64,
        [string]$X86 = $X64,
        [string]$ARM64 = $X64
    )

    switch (Get-SystemArchitecture) {
        'ARM64' { return $ARM64 }
        'X86' { return $X86 }
        default { return $X64 }
    }
}


function Wait-Until {
    <#
    .SYNOPSIS
    Polls a condition until it becomes true or the timeout expires.

    .DESCRIPTION
    Preferred over a fixed Start-Sleep: it returns as soon as the condition
    holds, and it does not give up too early in the slow case.
    #>
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Condition,
        # Defaults come from AppConfig.Timeouts so the timeout of an installer is
        # declared once, next to the other timeouts, instead of at every call site.
        [int]$TimeoutSeconds = 0,
        [int]$IntervalMs = 1000
    )
    if ($TimeoutSeconds -le 0) { $TimeoutSeconds = $script:AppConfig.Timeouts.Condition }
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (& $Condition) { return $true }
        if ((Get-Date) -ge $deadline) { break }
        Start-Sleep -Milliseconds $IntervalMs
    } while ($true)
    return $false
}


function ConvertTo-ProcessArgumentList {
    <#
    .SYNOPSIS
    Splits a command-line string into real argument tokens, honouring quotes.
    #>
    param([Parameter(Mandatory = $true)][string]$Arguments)

    $tokens = [regex]::Matches($Arguments, '"([^"]*)"|''([^'']*)''|(\S+)')
    return @($tokens | ForEach-Object {
            if ($_.Groups[1].Success) { $_.Groups[1].Value }
            elseif ($_.Groups[2].Success) { $_.Groups[2].Value }
            else { $_.Groups[3].Value }
        })
}


function Invoke-DownloadFile {
    <#
    .SYNOPSIS
    Downloads a file with fallback URLs and payload validation.

    .DESCRIPTION
    -Uri accepts a LIST of candidate URLs: the first one that downloads AND passes
    validation wins. This removes the single point of failure that made a 404 on a
    single endpoint fatal (the raw.githubusercontent URL form, a renamed branch, a
    CDN hiccup) and it is also the only way to keep a 404 from being reported as a
    success.
    The payload is validated before $true is returned: the file must exist, reach
    -MinimumBytes, and satisfy -ContentValidator when provided. Partial or error
    payloads are deleted, never left behind for the next step to trust.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Uri,
        [Parameter(Mandatory = $true)][string]$OutFile,
        [switch]$Silent,
        [int]$MinimumBytes = 1,
        [scriptblock]$ContentValidator,
        # A transient network error is common on a freshly installed machine; the
        # previous version tried each URL exactly once and gave up.
        [int]$RetryCount = 2,
        [int]$RetryIntervalSeconds = 2
    )

    $previousProgress = $ProgressPreference
    $failures = @()
    try {
        $ProgressPreference = 'SilentlyContinue'
        $parentDir = Split-Path -Path $OutFile -Parent
        if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
            $null = New-Item -Path $parentDir -ItemType Directory -Force -ErrorAction Stop
        }

        foreach ($candidate in $Uri) {
            if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
            for ($attempt = 0; $attempt -le $RetryCount; $attempt++) {
                try {
                    Remove-PathQuietly -Path $OutFile
                    Invoke-WebRequest -Uri $candidate -OutFile $OutFile -UseBasicParsing -ErrorAction Stop

                    $downloaded = Get-Item -LiteralPath $OutFile -ErrorAction Stop
                    if ($downloaded.PSIsContainer) { throw 'The response is not a file.' }
                    if ($downloaded.Length -lt $MinimumBytes) {
                        throw "Only $($downloaded.Length) bytes received (expected at least $MinimumBytes)."
                    }
                    if ($ContentValidator -and -not (& $ContentValidator $OutFile)) {
                        throw 'The downloaded content did not pass validation.'
                    }

                    Write-ToolkitLog -Level 'INFO' -Message "Downloaded '$candidate' -> $OutFile ($($downloaded.Length) bytes)."
                    return $true
                }
                catch {
                    $failures += "${candidate}: $($_.Exception.Message)"
                    Write-ToolkitLog -Level 'WARNING' -Message "Download attempt failed ($candidate, try $($attempt + 1)/$($RetryCount + 1)): $($_.Exception.Message)"
                    Remove-PathQuietly -Path $OutFile
                    if ($attempt -lt $RetryCount) { Start-Sleep -Seconds $RetryIntervalSeconds }
                }
            }
        }

        $detail = if ($failures.Count -gt 0) { ($failures | Select-Object -Unique) -join ' | ' } else { 'no candidate URL provided' }
        if (-not $Silent) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.downloadError0' -Args @($detail))
        }
        Write-ToolkitLog -Level 'ERROR' -Message "Download failed for $OutFile after $($Uri.Count) candidate(s): $detail"
        return $false
    }
    catch {
        if (-not $Silent) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.downloadError0' -Args @($_.Exception.Message))
        }
        Write-ToolkitLog -Level 'WARNING' -Message "Download failed ($OutFile): $($_.Exception.Message)"
        return $false
    }
    finally {
        $ProgressPreference = $previousProgress
    }
}


function Test-DownloadedSignature {
    <#
    .SYNOPSIS
    Verifies the Authenticode signature of a downloaded file against an allow-list.

    .DESCRIPTION
    Closes the gap where a download was trusted purely because the transfer
    succeeded. Each executable declares the signer it expects
    (AppConfig.DownloadSignatures) and the file is only accepted when
    Get-AuthenticodeSignature reports a Valid status for one of those subjects.

    Matching is by SUBSTRING on the certificate subject, because the exact string
    differs between signer versions ("Microsoft Corporation" vs "Microsoft Windows
    Publisher"), and a prefix match would break on a legitimate re-signing.

    Revocation is deliberately NOT requested: the check would add a network round
    trip per file and would fail on a machine that is offline, turning a valid
    signature into a hard failure.

    Intended for the -ContentValidator of Invoke-DownloadFile: it returns $false,
    so the caller decides whether that is fatal (see New-SignatureValidator).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$ExpectedSigners
    )

    try {
        $signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Signature could not be read for '$Path': $($_.Exception.Message)"
        return $false
    }

    if ($signature.Status -ne 'Valid') {
        Write-ToolkitLog -Level 'WARNING' -Message "Invalid or untrusted signature on '$Path': status=$($signature.Status)"
        return $false
    }

    $subject = [string]$signature.SignerCertificate.Subject
    foreach ($expected in $ExpectedSigners) {
        if ($subject -like "*$expected*") {
            Write-ToolkitLog -Level 'INFO' -Message "Signature verified on '$Path': $subject"
            return $true
        }
    }

    Write-ToolkitLog -Level 'WARNING' -Message "Unexpected signer on '$Path': '$subject' (expected one of: $($ExpectedSigners -join ', '))."
    return $false
}


function New-SignatureValidator {
    <#
    .SYNOPSIS
    Builds the -ContentValidator scriptblock for a signed download.

    .DESCRIPTION
    Returns a validator that checks the signature and, when -BlockOnInvalid is
    set, treats a failure as fatal. The block/warn distinction is deliberate:
      - vc_redist.exe and the Git installer are EXECUTED by the toolkit, so an
        unverifiable file must not run;
      - the .msixbundles are handed to Add-AppxPackage, which validates the
        package signature itself and fails safely, so a bad signature there is
        reported as a warning and the OS takes the decision.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ProfileKey,
        [switch]$BlockOnInvalid
    )

    # ContainsKey, not a truthiness test: @($null).Count is 1, so a missing key
    # would look like a valid single-entry list and silently disable the check.
    if (-not $script:AppConfig.DownloadSignatures.ContainsKey($ProfileKey)) {
        throw "Unknown signature profile '$ProfileKey'. Known: $($script:AppConfig.DownloadSignatures.Keys -join ', ')"
    }
    $signers = @($script:AppConfig.DownloadSignatures[$ProfileKey])
    $block = $BlockOnInvalid.IsPresent

    # The check is captured BY REFERENCE (${function:...}) and invoked with &.
    # Calling it by name inside the closure does not work: GetNewClosure rebinds
    # the scriptblock to a fresh module scope, where a function that was dot-sourced
    # (as the test suites and the fragment loader do) is not visible, and the
    # validator would fail at run time with "command not recognized".
    $signatureCheck = ${function:Test-DownloadedSignature}
    $validator = {
        param($candidatePath)
        $ok = & $signatureCheck -Path $candidatePath -ExpectedSigners $signers
        if (-not $ok -and $block) {
            throw "Signature verification failed for '$candidatePath': the file will not be installed."
        }
        return $ok
    }
    return $validator.GetNewClosure()
}


function Install-RemoteFile {
    <#
    .SYNOPSIS
    Downloads a file and installs it atomically, keeping a backup only if it changed.

    .DESCRIPTION
    Single owner of the "download to temp, then swap in with a backup" sequence
    that the Windows Terminal settings, the PowerShell profile and any other
    distributed file used to repeat. Two behaviours are worth naming:

    - the content is compared with the file already on disk, and an identical
      download is a no-op: the previous code produced a new .bak file on every
      single run, even when nothing had changed, so the backups were pure noise;
    - the backup itself is a move of the previous content, and at most
      -BackupRetention backups are kept per file, so the log folder cannot grow
      without bound.

    Returns $true when the destination now holds the downloaded content.
    #>
    param(
        [Parameter(Mandatory = $true)][string[]]$Url,
        [Parameter(Mandatory = $true)][string]$Destination,
        [int]$MinimumBytes = 1,
        [switch]$Backup,
        [int]$BackupRetention = 3
    )

    $stagedPath = Join-Path $script:AppConfig.Paths.Temp ("wt-stage-{0}.tmp" -f [guid]::NewGuid())
    try {
        if (-not (Invoke-DownloadFile -Uri $Url -OutFile $stagedPath -Silent -MinimumBytes $MinimumBytes)) {
            return $false
        }

        # Identical content: nothing to install, and no pointless backup.
        if ((Test-Path -LiteralPath $Destination -PathType Leaf) -and
            ((Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -eq
             (Get-FileHash -LiteralPath $stagedPath -Algorithm SHA256).Hash)) {
            Write-ToolkitLog -Level 'INFO' -Message "Already up to date, not rewritten: $Destination"
            return $true
        }

        $null = Initialize-Directory -Path (Split-Path -Path $Destination -Parent)
        $backupPath = Copy-FileAtomically -SourcePath $stagedPath -Destination $Destination -Backup

        # Re-read the INSTALLED file rather than trusting the staged one: a
        # truncated swap would otherwise be reported as a successful installation.
        if (-not (Test-FileHasMinimumSize -Path $Destination -MinimumBytes $MinimumBytes)) {
            Write-ToolkitLog -Level 'ERROR' -Message "Installed file is smaller than expected: $Destination"
            return $false
        }
        if ($backupPath) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.existingProfileSaved0' -Args @($backupPath))
            Remove-ExpiredBackups -Path "$Destination.bak.*" -Keep $BackupRetention
        }
        return $true
    }
    finally {
        Remove-PathQuietly -Path $stagedPath
    }
}


function Remove-ExpiredBackups {
    <#
    .SYNOPSIS
    Keeps only the newest -Keep timestamped backups matching a path pattern.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Keep = 3
    )

    $backups = @(Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending)
    if ($backups.Count -le $Keep) { return }
    Remove-PathQuietly -Path @($backups[$Keep..($backups.Count - 1)].FullName)
}


function New-ExternalCommandResult {
    <#
    .SYNOPSIS
    Builds the result object returned by Invoke-ExternalCommand.

    .DESCRIPTION
    Success and failure paths must expose the same members, otherwise a caller
    reading a property would fail under Set-StrictMode.
    #>
    param(
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int[]]$AcceptedExitCodes = @(0),
        [bool]$TimedOut = $false,
        [string]$StdOut = '',
        [string]$StdErr = '',
        [int]$DurationMs = 0,
        [string]$Error = ''
    )

    return [pscustomobject]@{
        ExitCode   = $ExitCode
        TimedOut   = $TimedOut
        Accepted   = (-not $TimedOut) -and ($AcceptedExitCodes -contains $ExitCode)
        StdOut     = $StdOut
        StdErr     = $StdErr
        DurationMs = $DurationMs
        Command    = "$FilePath $($ArgumentList -join ' ')"
        Error      = $Error
    }
}


function Invoke-ExternalCommand {
    <#
    .SYNOPSIS
    Runs an external process with a real timeout and a structured result.

    .DESCRIPTION
    Shared by every installer (WinGet, Git, PowerShell 7, Windows Terminal). The
    process runs detached from the host console and both streams are drained
    asynchronously, so native progress lines never bleed into the toolkit output
    and the timeout stays reachable. Returns ExitCode, TimedOut, Accepted, StdOut,
    StdErr, DurationMs, Command and Error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int]$TimeoutSeconds = 120,
        [int[]]$AcceptedExitCodes = @(0)
    )

    $proc = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $commandLine = "$FilePath $($ArgumentList -join ' ')"
    try {
        # ProcessStartInfo.ArgumentList keeps every token separate, so paths with
        # spaces or quotes survive without manual escaping.
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $FilePath
        foreach ($argument in $ArgumentList) { $psi.ArgumentList.Add([string]$argument) }
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi

        $null = $proc.Start()
        # Read both pipes asynchronously: a synchronous ReadToEnd() would block
        # until the child exits and make the timeout below unreachable.
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()

        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            try { $proc.Kill($true) } catch { try { $proc.Kill() } catch {
                Write-ToolkitLog -Level 'WARNING' -Message "Invoke-ExternalCommand: $($_.Exception.Message)"
            } }
            $null = $proc.WaitForExit()
            Write-ToolkitLog -Level 'ERROR' -Message "External command timed out after $TimeoutSeconds s: $commandLine"
            return New-ExternalCommandResult -ExitCode -2 -TimedOut $true -DurationMs $stopwatch.ElapsedMilliseconds -FilePath $FilePath -ArgumentList $ArgumentList -AcceptedExitCodes $AcceptedExitCodes
        }

        $capturedOut = try { $outTask.GetAwaiter().GetResult() } catch { '' }
        $capturedErr = try { $errTask.GetAwaiter().GetResult() } catch { '' }

        # Both pipes are drained unconditionally (a synchronous read would make
        # the timeout unreachable), so the switch only decided whether the text
        # was kept. It is now kept always and truncated: a verbose installer can
        # emit megabytes, and the head of the output is the part that explains a
        # failure.
        $limit = $script:AppConfig.MaxCapturedOutputChars
        $stdOut = if ($capturedOut.Length -gt $limit) { $capturedOut.Substring(0, $limit) } else { $capturedOut }
        $stdErr = if ($capturedErr.Length -gt $limit) { $capturedErr.Substring(0, $limit) } else { $capturedErr }
        return New-ExternalCommandResult -ExitCode $proc.ExitCode -FilePath $FilePath -ArgumentList $ArgumentList -AcceptedExitCodes $AcceptedExitCodes -StdOut $stdOut -StdErr $stdErr -DurationMs $stopwatch.ElapsedMilliseconds
    }
    catch {
        Write-ToolkitLog -Level 'ERROR' -Message "External command failed ($FilePath): $($_.Exception.Message)"
        return New-ExternalCommandResult -ExitCode -1 -FilePath $FilePath -ArgumentList $ArgumentList -AcceptedExitCodes $AcceptedExitCodes -DurationMs $stopwatch.ElapsedMilliseconds -Error $_.Exception.Message
    }
    finally {
        $stopwatch.Stop()
        if ($proc) { $proc.Dispose() }
    }
}


function Install-FromGitHubRelease {
    <#
    .SYNOPSIS
    Downloads a GitHub release asset and runs it as a silent installer.

    .DESCRIPTION
    Shared by the Git and PowerShell 7 installers. '{INSTALLER}' inside
    -ExecutablePath or -InstallerArguments is replaced with the downloaded file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ReleaseApiUrl,
        [Parameter(Mandatory = $true)][string]$AssetPattern,
        [Parameter(Mandatory = $true)][string]$ExecutablePath,
        [string[]]$InstallerArguments = @(),
        [int[]]$AcceptedExitCodes = @(0),
        [int]$TimeoutSeconds = 300
    )

    $downloadPath = $null
    try {
        $release = Invoke-RestMethod -Uri $ReleaseApiUrl -UseBasicParsing -ErrorAction Stop
        $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
        if (-not $asset) { throw "No release asset matched '$AssetPattern'." }

        # Invoke-DownloadFile also creates the temp folder, so no pre-flight here.
        $downloadPath = Join-Path $script:AppConfig.Paths.Temp $asset.name
        # The installer is EXECUTED by this script, so an unverifiable signature
        # is fatal: the file is deleted and the install never starts.
        if (-not (Invoke-DownloadFile -Uri $asset.browser_download_url -OutFile $downloadPath `
                    -ContentValidator (New-SignatureValidator -ProfileKey 'git' -BlockOnInvalid))) {
            throw "Unable to download the release asset $($asset.name) or its signature is not trusted."
        }

        $installerArgs = @($InstallerArguments | ForEach-Object {
                $_ -replace '\{INSTALLER\}', $downloadPath
            })
        if ($ExecutablePath -eq '{INSTALLER}') { $ExecutablePath = $downloadPath }
        $result = Invoke-ExternalCommand -FilePath $ExecutablePath -ArgumentList $installerArgs `
            -TimeoutSeconds $TimeoutSeconds -AcceptedExitCodes $AcceptedExitCodes
        return [pscustomobject]@{
            Success  = [bool]$result.Accepted
            ExitCode = $result.ExitCode
            Asset    = $asset.name
            TimedOut = $result.TimedOut
        }
    }
    catch {
        return [pscustomobject]@{ Success = $false; ExitCode = -1; Error = $_.Exception.Message; TimedOut = $false }
    }
    finally {
        if ($downloadPath -and (Test-Path $downloadPath)) {
            Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
        }
    }
}


function New-StepResult {
    <#
    .SYNOPSIS
    Builds the single result shape every setup step returns.

    .DESCRIPTION
    Replaces the 18 hand-written [pscustomobject]@{Success;Changed;Message}
    literals, and gives the orchestrator one contract to consume: a step returns a
    StepResult, never a bare boolean. Skipped is carried on the result itself, so
    a step that was not applicable is no longer reported as a failure.
    #>
    param(
        [Parameter(Mandatory = $true)][bool]$Success,
        [bool]$Changed = $false,
        [string]$Message = '',
        [switch]$Skipped
    )

    return [pscustomobject]@{
        Success  = $Success
        Changed  = $Changed
        Message  = $Message
        Skipped  = [bool]$Skipped
        Blocking = $false
    }
}


function Add-SetupResult {
    <#
    .SYNOPSIS
    Records a typed result for one setup step, consumed by Write-SetupSummary.

    .DESCRIPTION
    Accepts either a StepResult (the -Result form, the one every step now returns)
    or the explicit fields, and normalizes both into the same record. A Skipped
    step is no longer recorded as Failed: that is what used to turn "the shortcut
    was not applicable" into a partial-failure exit code.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(ParameterSetName = 'Result')][object]$Result,
        [Parameter(ParameterSetName = 'Fields', Mandatory = $true)][bool]$Success,
        [Parameter(ParameterSetName = 'Fields')][bool]$Changed = $false,
        [Parameter(ParameterSetName = 'Fields')][string]$Message = '',
        [bool]$Blocking = $false,
        [switch]$Skipped
    )

    $stepSkipped = $Skipped.IsPresent
    $stepSuccess = $false
    $stepChanged = $false
    $stepMessage = ''

    if ($PSCmdlet.ParameterSetName -eq 'Result') {
        $stepSuccess = [bool]$Result.Success
        $stepChanged = [bool]$Result.Changed
        $stepMessage = [string]$Result.Message
        $stepSkipped = $stepSkipped -or [bool]$Result.Skipped
        $Blocking = $Blocking -or [bool]$Result.Blocking
    }
    else {
        $stepSuccess = $Success
        $stepChanged = $Changed
        $stepMessage = $Message
    }

    $status = if ($stepSkipped) { 'Skipped' }
    elseif ($stepSuccess) { if ($stepChanged) { 'Changed' } else { 'Succeeded' } }
    else { 'Failed' }

    $script:State.Results.Add([pscustomobject]@{
            Name = $Name; Status = $status; Message = $stepMessage; Blocking = $Blocking
        })
}


function Write-SetupSummary {
    <#
    .SYNOPSIS
    Prints the final Succeeded/Changed/Failed/Skipped summary and returns the
    process exit code: 0 full success, 2 partial success, 1 blocking error.
    #>
    $counts = @{}
    foreach ($status in @('Succeeded', 'Changed', 'Failed', 'Skipped')) {
        $counts[$status] = @($script:State.Results | Where-Object Status -eq $status).Count
    }

    # Localized one-liner: "Execution Summary: Succeeded=N Changed=N Failed=N Skipped=N."
    $counters = @('Succeeded', 'Changed', 'Failed', 'Skipped') | ForEach-Object {
        '{0}={1}' -f (Get-SourceTextLoc "summary.$($_.ToLowerInvariant())"), $counts[$_]
    }
    $summaryText = '{0}: {1}.' -f (Get-SourceTextLoc 'summary.title'), ($counters -join ' ')
    Write-StyledMessage -Type Info -Text $summaryText
    foreach ($result in $script:State.Results | Where-Object Status -eq 'Failed') {
        $level = if ($result.Blocking) { 'Error' } else { 'Warning' }
        Write-StyledMessage -Type $level -Text "$($result.Name): $($result.Message)"
    }
    $hasBlockingFailure = @($script:State.Results | Where-Object { $_.Status -eq 'Failed' -and $_.Blocking }).Count -gt 0
    $hasFailure = @($script:State.Results | Where-Object Status -eq 'Failed').Count -gt 0
    if ($hasBlockingFailure) { return 1 }
    if ($hasFailure) { return 2 }
    return 0
}
