

# ==============================================================================
# SEZIONE 7 · PROCESSI ED ESECUZIONE
# Chiusura processi, esecuzione comandi esterni con log, spinner, countdown.
# ==============================================================================

function Stop-ToolkitProcesses {
    <#
    .SYNOPSIS
        Chiude in modo forzato e silenzioso i processi specificati.
    #>
    param([string[]]$ProcessNames)
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.closingInterferingProcesses')
    foreach ($procName in $ProcessNames) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -ne $PID } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
}

function Invoke-ExternalCommandWithLog {
    <#
    .SYNOPSIS
        Executes an external command with structured logging and full STDOUT/STDERR capture.
    .DESCRIPTION
        Standardized wrapper for external processes.
        Logga comando, argomenti, exit code, durata ed eventuali errori.
        Restituisce un oggetto con Success, ExitCode, StdOut, StdErr, Elapsed.
        Non scrive mai direttamente su console.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory,
        [int]$TimeoutSeconds = 0,
        [string]$LogContextKey = '',
        [string]$Activity = '',
        [int]$UpdateInterval = 500,
        [string]$Tool = $Global:CurrentToolName,
        [string]$Step = 'ExternalCommand'
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $startTime = Get-Date
    $argString = $Arguments -join ' '

    Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'uiText.runningCommand01Timeout2S' -Args @($Command, $argString, ${TimeoutSeconds}))
    Write-ToolkitLog -Level 'DEBUG' -Message (Get-SourceTextLoc 'uiText.commandContext') -Context @{
        Tool = $Tool; Step = $Step; WorkingDir = $WorkingDirectory; ContextKey = $LogContextKey
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Command
    $psi.Arguments = $argString
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $outText = ""; $errText = ""; $success = $false; $exitCode = $null; $timedOut = $false

    try {
        if (-not $proc.Start()) { throw (Get-SourceTextLoc 'uiText.unableToStartExternalProcess') }

        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()

        if ($Activity) {
            $spinnerIndex = 0; $percent = 0
            while (-not $proc.HasExited -and ($TimeoutSeconds -eq 0 -or ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds)) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                if ($percent -lt 90) { $percent += Get-Random -Minimum 1 -Maximum 3 }
                Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.executing0Seconds' -Args @($elapsed)) -Percent $percent -Icon '⏳' -Spinner $spinner
                Start-Sleep -Milliseconds $UpdateInterval
                $proc.Refresh()
            }
            if (-not $proc.HasExited -and $TimeoutSeconds -gt 0) {
                try { $proc.Kill() } catch {}
                throw (Get-SourceTextLoc 'uiText.timeoutAfter0Seconds' -Args @($TimeoutSeconds))
            }
            Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
            if (-not $Global:GuiSessionActive) { Write-Host "" }
        }
        else {
            if ($TimeoutSeconds -gt 0) {
                if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
                    try { $proc.Kill() } catch {}
                    throw (Get-SourceTextLoc 'uiText.timeoutAfter0Seconds' -Args @($TimeoutSeconds))
                }
            }
            else { $proc.WaitForExit() }
        }

        try { [System.Threading.Tasks.Task]::WaitAll($outTask, $errTask) } catch {}
        if ($outTask.Status -eq 'RanToCompletion') { $outText = $outTask.Result }
        if ($errTask.Status -eq 'RanToCompletion') { $errText = $errTask.Result }

        $exitCode = $proc.ExitCode
        $success = ($exitCode -eq 0)
    }
    catch {
        $exitCode = if ($null -ne $exitCode) { $exitCode } else { -1 }
        if ($_.Exception.Message -match 'Timeout') { $timedOut = $true }
        Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.exceptionWhileRunningExternalCommand') -Context @{
            Command = $Command; Arguments = $Arguments; WorkingDir = $WorkingDirectory
            TimeoutSec = $TimeoutSeconds; ContextKey = $LogContextKey
            Exception = $_.Exception.Message; Stack = $_.ScriptStackTrace
        }
    }
    finally {
        $stopwatch.Stop()
        if ($null -eq $outText) { $outText = "" }
        if ($null -eq $errText) { $errText = "" }

        $maxLen = 8000
        $outLogged = if ($outText.Length -gt $maxLen) { $outText.Substring(0, $maxLen) + "`n[...output truncated...]" } else { $outText }
        $errLogged = if ($errText.Length -gt $maxLen) { $errText.Substring(0, $maxLen) + "`n[...stderr truncated...]" } else { $errText }

        $statusMsg = if ($success) { Get-SourceTextLoc 'sourceText.completedSuccessfully' } else { Get-SourceTextLoc 'sourceText.completedWithErrors' }
        Write-ToolkitLog -Level 'INFO'  -Message (Get-SourceTextLoc 'uiText.command0ExitCode1Duration2' -Args @($statusMsg, $exitCode, $($stopwatch.Elapsed.ToString('hh\:mm\:ss'))))
        Write-ToolkitLog -Level 'DEBUG' -Message (Get-SourceTextLoc 'uiText.commandOutput0' -Args @($Command)) -Context @{
            ContextKey = $LogContextKey; StdOutSnippet = $outLogged; StdErrSnippet = $errLogged
        }
        if ($proc) { $proc.Dispose() }
    }

    [pscustomobject]@{
        Success  = $success
        ExitCode = $exitCode
        StdOut   = $outText
        StdErr   = $errText
        Elapsed  = $stopwatch.Elapsed
        TimedOut = $timedOut
    }
}

function Invoke-WithSpinner {
    <#
    .SYNOPSIS
        Executes an action with automatic spinner animation.
    .DESCRIPTION
        Higher-order function that automatically manages spinner
        animation for async operations, processes, jobs or timers.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Activity,
        [scriptblock]$Action,
        [int]$TimeoutSeconds = 300,
        [int]$UpdateInterval = 500,
        [switch]$Process,
        [switch]$Job,
        [switch]$Timer,
        [scriptblock]$PercentUpdate,
        [string]$Command,
        [string[]]$Arguments = @(),
        [string]$LogContextKey = ''
    )

    $startTime = Get-Date
    $spinnerIndex = 0
    $percent = 0

    if ($Command) {
        return Invoke-ExternalCommandWithLog -Command $Command -Arguments $Arguments `
            -TimeoutSeconds $TimeoutSeconds -Activity $Activity -UpdateInterval $UpdateInterval -LogContextKey $LogContextKey
    }

    try {
        $result = & $Action

        if ($Timer) {
            $totalSeconds = $TimeoutSeconds
            for ($i = $totalSeconds; $i -gt 0; $i--) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                $percent = if ($PercentUpdate) { & $PercentUpdate } else { [math]::Round((($totalSeconds - $i) / $totalSeconds) * 100) }
                Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.01Seconds' -Args @($Activity, $i)) -Status '' -Percent $percent -Icon '⏳' -Spinner $spinner -Color 'Yellow'
                Start-Sleep -Seconds 1
            }
            if (-not $Global:GuiSessionActive) { Write-Host '' }
            return $true
        }
        elseif ($Process -and $result -and $result.GetType().Name -eq 'Process') {
            while (-not $result.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                $percent = if ($PercentUpdate) { & $PercentUpdate } elseif ($percent -lt 90) { $percent + (Get-Random -Minimum 1 -Maximum 3) } else { $percent }
                Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.executing0Seconds' -Args @($elapsed)) -Percent $percent -Icon '⏳' -Spinner $spinner
                Start-Sleep -Milliseconds $UpdateInterval
                $result.Refresh()
            }
            if (-not $result.HasExited) {
                Write-ProgressUpdate -Activity $Activity -Status '' -Percent 0
                if (-not $Global:GuiSessionActive) { Write-Host "" }
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.timeoutReachedAfter0SecondsProcessTermination' -Args @($TimeoutSeconds))
                $result.Kill(); Start-Sleep -Seconds 2
                return @{ Success = $false; TimedOut = $true; ExitCode = -1 }
            }
            Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
            if (-not $Global:GuiSessionActive) { Write-Host "" }
            return @{ Success = $true; TimedOut = $false; ExitCode = $result.ExitCode }
        }
        elseif ($Job -and $result -is [System.Management.Automation.Job]) {
            try {
                while ($result.State -eq 'Running' -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                    $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                    $percent = if ($PercentUpdate) { & $PercentUpdate } elseif ($percent -lt 90) { $percent + (Get-Random -Minimum 1 -Maximum 3) } else { $percent }
                    Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.executing0Seconds' -Args @($elapsed)) -Percent $percent -Icon '⏳' -Spinner $spinner
                    Start-Sleep -Milliseconds $UpdateInterval
                }

                if ($result.State -eq 'Running') {
                    Stop-Job -Job $result -ErrorAction SilentlyContinue
                    throw (Get-SourceTextLoc 'uiText.timeoutAfter0Seconds' -Args @($TimeoutSeconds))
                }

                if ($result.State -eq 'Failed') {
                    $failureReason = $result.ChildJobs[0].JobStateInfo.Reason
                    if ($failureReason) { throw $failureReason }
                    throw (Get-SourceTextLoc 'uiText.errorDuring01' -Args @($Activity, $result.State))
                }

                $jobResult = Receive-Job -Job $result -Wait -ErrorAction Stop
                Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
                if (-not $Global:GuiSessionActive) { Write-Host '' }
                return $jobResult
            }
            finally {
                Remove-Job -Job $result -Force -ErrorAction SilentlyContinue
            }
        }
        else {
            Start-Sleep -Seconds $TimeoutSeconds
            return $result
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'uiText.errorDuring01' -Args @(${Activity}, $($_.Exception.Message)))
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Start-InterruptibleCountdown {
    <#
    .SYNOPSIS
        Conto alla rovescia interrompibile dall'utente con pressione di un tasto.
    #>
    param([int]$Seconds = 30, [string]$Message, [switch]$Suppress)
    if ($Suppress) { return $true }
    if ([string]::IsNullOrWhiteSpace($Message)) { $Message = Get-SourceTextLoc 'sourceText.automaticRestart' }

    Write-StyledMessage -Type 'Info' -Text ("💡 " + (Get-SourceTextLoc 'uiText.pressAnyKeyToCancel'))
    Write-Host ''
    for ($i = $Seconds; $i -gt 0; $i--) {
        if ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
            Write-Host "`n"
            Write-StyledMessage -Type 'Warning' -Text ("⏸️ " + (Get-SourceTextLoc 'uiText.systemRebootCancelled'))
            return $false
        }
        $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
        Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.0In1Seconds' -Args @($Message, $i)) -Status '' -Percent $percent -Icon '⏰' -Color 'Red'
        Start-Sleep 1
    }
    Write-Host "`n"
    return $true
}


function Start-ToolkitSession {
    <#
    .SYNOPSIS
        Standard initialization for every tool: log, header, window title.
        Replaces the identical 3-line block present in all tools.
    #>
    param([string]$ToolName, [string]$SubTitle = $ToolName)
    Start-ToolkitLog -ToolName $ToolName
    Show-Header -SubTitle $SubTitle
    try { $Host.UI.RawUI.WindowTitle = "$SubTitle By MagnetarMan" } catch {}
}

function Invoke-ToolkitReboot {
    <#
    .SYNOPSIS
        Centralized reboot management: suppressed (multi-script) or interruptible countdown.
        Replaces the 9-line if/else block present in 11 tools.
    #>
    param(
        [string]$Message,
        [int]$Seconds = 30,
        [switch]$SuppressIndividualReboot
    )
    if ([string]::IsNullOrWhiteSpace($Message)) { $Message = Get-SourceTextLoc 'sourceText.operationCompleted' }
    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
        Write-StyledMessage -Type 'Info' -Text ("🚫 " + (Get-SourceTextLoc 'uiText.individualRestartSuppressedAFinalRebootWillBeHandled'))
    }
    else {
        if (Start-InterruptibleCountdown -Seconds $Seconds -Message $Message) {
            Restart-Computer -Force
        }
    }
}

function Remove-ItemSafely {
    <#
    .SYNOPSIS
        Silently removes a path (file or directory) without exceptions.
        Versione generalizzata di Invoke-OfficeSilentRemoval.
    #>
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$Recurse)
    if (-not (Test-Path $Path)) { return $false }
    try {
        $params = @{ Path = $Path; Force = $true; ErrorAction = 'SilentlyContinue' }
        if ($Recurse) { $params['Recurse'] = $true }
        Remove-Item @params *>$null
        Clear-ProgressLine
        return $true
    }
    catch { return $false }
}

function Invoke-ToolkitDownload {
    <#
    .SYNOPSIS
        Download di un file con retry automatico, barra di progresso, referrer AMD e messaggi standardizzati.
    .DESCRIPTION
        Implementa download con visualizzazione della barra di progresso in tempo reale.
        Supporta URL AMD con referrer per aggirare i blocchi.
        Retry automatico e fallback robusti per connessioni instabili.
    #>
    param(
        [string]$Uri,
        [string]$OutputPath,
        [string]$Description,
        [int]$MaxRetries = 3,
        [switch]$NoSpinner
    )
    
    if ([string]::IsNullOrWhiteSpace($Description)) { $Description = Get-SourceTextLoc 'sourceText.file' }
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-StyledMessage -Type 'Info' -Text ("📥 " + (Get-SourceTextLoc 'uiText.download0' -Args @($Description)))
            
            # Creare parent directory se non esiste
            $parentDir = Split-Path -Parent $OutputPath
            if (-not (Test-Path $parentDir)) {
                New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
            }
            
            # Create HttpClient with 5 minute timeout
            $handler = New-Object System.Net.Http.HttpClientHandler
            $handler.AllowAutoRedirect = $true
            $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
            
            $httpClient = New-Object System.Net.Http.HttpClient($handler)
            $httpClient.Timeout = [TimeSpan]::FromSeconds(300)
            
            # Add custom headers
            $httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
            if ($Uri -match 'drivers\.amd\.com|amd-software') {
                $httpClient.DefaultRequestHeaders.Add("Referer", "https://www.amd.com")
            }
            
            # Perform HEAD request to get the size
            $totalBytes = 0
            try {
                $headRequest = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Head, $Uri)
                $headResponse = $httpClient.SendAsync($headRequest).Result
                if ($headResponse.Content.Headers.ContentLength -gt 0) {
                    $totalBytes = $headResponse.Content.Headers.ContentLength
                }
                $headResponse.Dispose()
            }
            catch {}  # Continue even if HEAD fails
            
            # Perform the GET download
            $getRequest = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $Uri)
            $getResponse = $httpClient.SendAsync($getRequest, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
            
            if (-not $getResponse.IsSuccessStatusCode) {
                throw (Get-SourceTextLoc 'uiText.httpError01' -Args @($($getResponse.StatusCode), $($getResponse.ReasonPhrase)))
            }
            
            # Try to get the size from the GET response if HEAD failed
            if ($totalBytes -eq 0 -and $getResponse.Content.Headers.ContentLength -gt 0) {
                $totalBytes = $getResponse.Content.Headers.ContentLength
            }

            # === NEW LOGIC: Fake progress bar disconnected from download ===
            $isUnknownSize = ($totalBytes -eq 0)
            $fakeProgressStart = $null
            if ($isUnknownSize -and -not $Global:GuiSessionActive) {
                $fakeProgressStart = Get-Date
                # Show fake bar immediately (before starting to read data)
                Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.download02' -Args @($Description)) `
                    -Status (Get-SourceTextLoc 'uiText.startingDownload') `
                    -Percent 8 -Icon '📥' -Color 'Cyan'
                Start-Sleep -Milliseconds 120   # small visual delay to make the bar appear
            }
            
            # Read the stream and write with progress tracking
            $contentStream = $getResponse.Content.ReadAsStreamAsync().Result
            $fileStream = [System.IO.File]::Create($OutputPath)
            $buffer = New-Object byte[] 8192
            $totalRead = 0
            $lastPercent = -1
            $lastProgressTime = Get-Date
            
            try {
                while ($true) {
                    $read = $contentStream.Read($buffer, 0, $buffer.Length)
                    if ($read -eq 0) { break }
                    
                    $fileStream.Write($buffer, 0, $read)
                    $totalRead += $read
                    
                    # Progress state calculation (DRY: logic here, rendering delegated)
                    if (-not $Global:GuiSessionActive) {
                        $currentDisplay = if ($totalRead -gt 1048576) {
                            "$([Math]::Round($totalRead / 1048576, 1)) MB"
                        }
                        else {
                            "$([Math]::Round($totalRead / 1024, 1)) KB"
                        }
                        
                        if ($totalBytes -gt 0) {
                            $percent = [Math]::Round(($totalRead / $totalBytes) * 100)
                            $totalDisplay = if ($totalBytes -gt 1048576) {
                                "$([Math]::Round($totalBytes / 1048576, 1)) MB"
                            }
                            else {
                                "$([Math]::Round($totalBytes / 1024, 1)) KB"
                            }
                            $status = "($currentDisplay / $totalDisplay)"
                            $icon = '📥'
                            $col = 'Cyan'
                        }
                        else {
                            # === Barra COMPLETAMENTE SCOLLEGATA dal download ===
                            # Use only elapsed time since the fake bar appeared
                            if ($fakeProgressStart) {
                                $elapsed = ((Get-Date) - $fakeProgressStart).TotalSeconds
                                # Rampa uniforme e prevedibile - max 95% durante il download
                                # (100% is forced only when the file is written to disk)
                                $percent = [math]::Min(95, [math]::Floor(8 + ($elapsed * 1.52)))
                            }
                            else {
                                $percent = 50   # fallback
                            }
                            $status = "$currentDisplay scaricati"
                            $icon = '📥'
                            $col = 'Cyan'
                        }
                        
                        $now = Get-Date
                        $timeSinceLast = ($now - $lastProgressTime).TotalMilliseconds
                        $shouldUpdate = $false

                        if ($lastPercent -eq -1) {
                            # First update: always show immediately (0% or first chunk)
                            $shouldUpdate = $true
                        }
                        elseif ($totalBytes -gt 0) {
                            # Known size: rate-limited + percent change (smooth, non-schizzofrenico)
                            if ($percent -ne $lastPercent -and $timeSinceLast -gt 250) {
                                $shouldUpdate = $true
                            }
                        }
                        else {
                            if ($timeSinceLast -gt 400 -or $percent -ne $lastPercent) {
                                $shouldUpdate = $true
                            }
                        }

                        if ($shouldUpdate) {
                            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.download02' -Args @($Description)) -Status $status -Percent $percent -Icon $icon -Color $col
                            $lastPercent = $percent
                            $lastProgressTime = $now
                        }
                    }
                }
            }
            finally {
                $fileStream.Dispose()
                $contentStream.Dispose()
            }
            
            $httpClient.Dispose()
            $handler.Dispose()
            
            if (Test-Path $OutputPath) {
                if ($totalBytes -gt 0) {
                    Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.download02' -Args @($Description)) -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅' -Color 'Green'
                }
                else {
                    Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.download02' -Args @($Description)) -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅' -Color 'Green'
                    if (-not $Global:GuiSessionActive) { Write-Host "" }
                }
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.downloadCompleted0' -Args @($Description))
                return $true
            }
        }
        catch {
            # Pulire in caso di errore
            if (Test-Path $OutputPath) {
                Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
            }
            
            if ($attempt -lt $MaxRetries) {
                Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'uiText.01AttemptFailed2ILlTryAgain' -Args @($attempt, $MaxRetries, $($_.Exception.Message))))
                Start-Sleep -Seconds 2
            }
        }
    }
    Write-StyledMessage -Type 'Error' -Text ((Get-SourceTextLoc 'uiText.downloadFailedAfter0Attempts1' -Args @($MaxRetries, $Description)))
    return $false
}

function Restart-ServiceSafely {
    <#
    .SYNOPSIS
        Stop + Start of a Windows service with standardized error handling.
    #>
    param([string]$Name, [int]$WaitSeconds = 1)
    try {
        Stop-Service -Name $Name -Force -ErrorAction Stop
        Start-Sleep -Seconds $WaitSeconds
        Start-Service -Name $Name -ErrorAction Stop
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.serviceRestarted0' -Args @($Name))
        return $true
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.failedToRestart01' -Args @($Name, $($_.Exception.Message)))
        return $false
    }
}

