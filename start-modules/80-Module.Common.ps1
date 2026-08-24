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
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.downloadError0' -Args @($($_.Exception.Message)))
        }
        Write-ToolkitLog -Level 'WARNING' -Message "Download failed ($Uri): $($_.Exception.Message)"
        return $false
    }
    finally {
        $ProgressPreference = $previousProgress
    }
}

function Invoke-ExternalCommand {
    <#
    .SYNOPSIS
    Runs an external process with a real timeout and structured result.

    .DESCRIPTION
    Shared by every installer (WinGet, Git, PowerShell 7, Windows Terminal).
    Returns ExitCode, TimedOut, Accepted, StdOut, StdErr and DurationMs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int]$TimeoutSeconds = 120,
        [int[]]$AcceptedExitCodes = @(0),
        [switch]$CaptureOutput
    )

    $outFile = $null
    $errFile = $null
    $proc = $null
    $outTask = $null
    $errTask = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        # Run detached from the host console. Redirect stdout/stderr to temp
        # files (not the host) so native progress/activity lines (e.g. winget
        # "Deployment operation progress") never bleed into the main toolkit
        # output. The streams are drained asynchronously: a synchronous
        # ReadToEnd() would block until the child exits, which would make the
        # timeout below unreachable.
        $outFile = Join-Path $env:TEMP "ext_$([guid]::NewGuid()).out"
        $errFile = Join-Path $env:TEMP "ext_$([guid]::NewGuid()).err"

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $FilePath
        # ProcessStartInfo.ArgumentList keeps each token separate, so paths
        # containing spaces or quotes survive without manual escaping.
        foreach ($argument in $ArgumentList) { $psi.ArgumentList.Add([string]$argument) }
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi

        $null = $proc.Start()
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()

        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            try { $proc.Kill($true) } catch { try { $proc.Kill() } catch { } }
            $null = $proc.WaitForExit()
            Write-ToolkitLog -Level 'ERROR' -Message "External command timed out after $TimeoutSeconds s: $FilePath $($ArgumentList -join ' ')"
            return [pscustomobject]@{
                ExitCode = -2; TimedOut = $true; Accepted = $false
                StdOut = ''; StdErr = ''; DurationMs = $stopwatch.ElapsedMilliseconds
                Command = "$FilePath $($ArgumentList -join ' ')"
            }
        }

        $capturedOut = try { $outTask.GetAwaiter().GetResult() } catch { '' }
        $capturedErr = try { $errTask.GetAwaiter().GetResult() } catch { '' }
        Set-Content -Path $outFile -Value $capturedOut -Encoding UTF8 -ErrorAction SilentlyContinue
        Set-Content -Path $errFile -Value $capturedErr -Encoding UTF8 -ErrorAction SilentlyContinue

        $stdOut = if ($CaptureOutput) { $capturedOut } else { '' }
        $stdErr = if ($CaptureOutput) { $capturedErr } else { '' }
        return [pscustomobject]@{
            ExitCode   = $proc.ExitCode
            TimedOut   = $false
            Accepted   = ($AcceptedExitCodes -contains $proc.ExitCode)
            StdOut     = $stdOut
            StdErr     = $stdErr
            DurationMs = $stopwatch.ElapsedMilliseconds
            Command    = "$FilePath $($ArgumentList -join ' ')"
        }
    }
    catch {
        Write-ToolkitLog -Level 'ERROR' -Message "External command failed ($FilePath): $($_.Exception.Message)"
        return [pscustomobject]@{
            ExitCode = -1; TimedOut = $false; Accepted = $false; Error = $_.Exception.Message
            StdOut = ''; StdErr = ''; DurationMs = $stopwatch.ElapsedMilliseconds
            Command = "$FilePath $($ArgumentList -join ' ')"
        }
    }
    finally {
        $stopwatch.Stop()
        if ($proc) { $proc.Dispose() }
        if ($outFile -and (Test-Path $outFile)) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }
        if ($errFile -and (Test-Path $errFile)) { Remove-Item $errFile -Force -ErrorAction SilentlyContinue }
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

        $tempDir = $script:AppConfig.Paths.Temp
        if (-not (Test-Path $tempDir)) { $null = New-Item -Path $tempDir -ItemType Directory -Force -ErrorAction Stop }
        $downloadPath = Join-Path $tempDir $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop

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
    Write-StyledMessage -Type Info -Text "Riepilogo: Successi=$($counts.Succeeded) Modificati=$($counts.Changed) Falliti=$($counts.Failed) Saltati=$($counts.Skipped)."
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