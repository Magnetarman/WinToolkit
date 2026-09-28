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


function Initialize-Directory {
    <#
    .SYNOPSIS
    Creates a directory when it is missing and returns its path.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        $null = New-Item -Path $Path -ItemType Directory -Force
    }
    return $Path
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
        [int]$TimeoutSeconds = 30,
        [int]$IntervalMs = 1000
    )
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
    DRY helper for file download with centralized error handling.
    #>
    param(
        [string]$Uri,
        [string]$OutFile,
        [switch]$Silent
    )

    $previousProgress = $ProgressPreference
    try {
        $ProgressPreference = 'SilentlyContinue'
        if ($OutFile) {
            $parentDir = Split-Path -Path $OutFile -Parent
            if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
                $null = New-Item -Path $parentDir -ItemType Directory -Force -ErrorAction Stop
            }
        }
        $iwrParams = @{
            Uri             = $Uri
            OutFile         = $OutFile
            UseBasicParsing = $true
            ErrorAction     = 'Stop'
        }
        Invoke-WebRequest @iwrParams
        return $true
    }
    catch {
        if (-not $Silent) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.downloadError0' -Args @($_.Exception.Message))
        }
        Write-ToolkitLog -Level 'WARNING' -Message "Download failed ($Uri): $($_.Exception.Message)"
        return $false
    }
    finally {
        $ProgressPreference = $previousProgress
    }
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
        [int[]]$AcceptedExitCodes = @(0),
        [switch]$CaptureOutput
    )

    $proc = $null
    $outTask = $null
    $errTask = $null
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
                Write-Warning "start-modules\80-Module.Common.ps1, Invoke-ExternalCommand: $($_.Exception.Message)"
            } }
            $null = $proc.WaitForExit()
            Write-ToolkitLog -Level 'ERROR' -Message "External command timed out after $TimeoutSeconds s: $commandLine"
            return New-ExternalCommandResult -ExitCode -2 -TimedOut $true -DurationMs $stopwatch.ElapsedMilliseconds -FilePath $FilePath -ArgumentList $ArgumentList -AcceptedExitCodes $AcceptedExitCodes
        }

        $capturedOut = try { $outTask.GetAwaiter().GetResult() } catch { '' }
        $capturedErr = try { $errTask.GetAwaiter().GetResult() } catch { '' }

        $stdOut = if ($CaptureOutput) { $capturedOut } else { '' }
        $stdErr = if ($CaptureOutput) { $capturedErr } else { '' }
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
        if (-not (Invoke-DownloadFile -Uri $asset.browser_download_url -OutFile $downloadPath)) {
            throw "Unable to download the release asset $($asset.name)."
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


function Add-SetupResult {
    <#
    .SYNOPSIS
    Records a typed result for one setup step, consumed by Write-SetupSummary.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Success,
        [bool]$Changed = $false,
        [string]$Message = '',
        [bool]$Blocking = $false
    )
    $status = if ($Success) { if ($Changed) { 'Changed' } else { 'Succeeded' } } else { 'Failed' }
    $script:SetupResults += [pscustomobject]@{
        Name = $Name; Status = $status; Message = $Message; Blocking = $Blocking
    }
}


function Write-SetupSummary {
    <#
    .SYNOPSIS
    Prints the final Succeeded/Changed/Failed/Skipped summary and returns the
    process exit code: 0 full success, 2 partial success, 1 blocking error.
    #>
    $counts = @{}
    foreach ($status in @('Succeeded', 'Changed', 'Failed', 'Skipped')) {
        $counts[$status] = @($script:SetupResults | Where-Object Status -eq $status).Count
    }

    # Localized one-liner: "Execution Summary: Succeeded=N Changed=N Failed=N Skipped=N."
    $counters = @('Succeeded', 'Changed', 'Failed', 'Skipped') | ForEach-Object {
        '{0}={1}' -f (Get-SourceTextLoc "summary.$($_.ToLowerInvariant())"), $counts[$_]
    }
    $summaryText = '{0}: {1}.' -f (Get-SourceTextLoc 'summary.title'), ($counters -join ' ')
    Write-StyledMessage -Type Info -Text $summaryText
    foreach ($result in $script:SetupResults | Where-Object Status -eq 'Failed') {
        $level = if ($result.Blocking) { 'Error' } else { 'Warning' }
        Write-StyledMessage -Type $level -Text "$($result.Name): $($result.Message)"
    }
    $hasBlockingFailure = @($script:SetupResults | Where-Object { $_.Status -eq 'Failed' -and $_.Blocking }).Count -gt 0
    $hasFailure = @($script:SetupResults | Where-Object Status -eq 'Failed').Count -gt 0
    if ($hasBlockingFailure) { return 1 }
    if ($hasFailure) { return 2 }
    return 0
}
