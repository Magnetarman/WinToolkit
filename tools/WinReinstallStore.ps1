function WinReinstallStore {
    <#
    .SYNOPSIS
        Automatically reinstalls Microsoft Store on Windows 10/11 using Winget.
    .DESCRIPTION
        Reinstalls Winget, Microsoft Store, and UniGet UI.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "WinReinstallStore" -SubTitle (Get-SourceTextLoc 'script.WinReinstallStore')

    $savedProgressPref = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    function Install-MicrosoftStore {
        Write-StyledMessage -Type 'Info' -Text ("🔄 " + (Get-SourceTextLoc 'toolText.reinstallingMicrosoftStore'))

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.restartMicrosoftStoreServices')
        @('AppXSvc', 'ClipSVC', 'WSService') | ForEach-Object {
            try { Restart-Service $_ -Force -ErrorAction SilentlyContinue *>$null } catch { }
        }

        @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
            (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\INetCache")
        ) | ForEach-Object { Remove-ItemSafely -Path $_ -Recurse }

        $wingetExe = Get-WingetExecutable

        $installMethods = @(
            @{
                Name   = 'Winget Install'
                Action = {
                    if (-not (Test-Path $wingetExe -ErrorAction SilentlyContinue)) { return @{ ExitCode = -1 } }
                    $processResult = Invoke-WithConsoleRedirection -Action {
                        Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.storeInstallationViaWinget') -Command $wingetExe -Arguments @('install', '9WZDNCRFJBMP', '--accept-source-agreements', '--accept-package-agreements', '--silent', '--disable-interactivity') -TimeoutSeconds 300 -LogContextKey "Store-Winget-Install"
                    }
                    return @{ ExitCode = $processResult.ExitCode }
                }
            },
            @{
                Name   = 'AppX Manifest'
                Action = {
                    $store = Get-AppxPackage -AllUsers *WindowsStore* -ErrorAction SilentlyContinue | Select-Object -First 1
                    $manifest = if ($store) { Join-Path $store.InstallLocation 'AppxManifest.xml' } else { $null }
                    if (-not $manifest -or -not (Test-Path $manifest)) { return @{ ExitCode = -1 } }

                    $procResult = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.appxManifestStoreRegistration') -Process -Action {
                        Start-AppxSilentProcess -AppxPath $manifest -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown'
                    } -TimeoutSeconds 120

                    return @{ ExitCode = $procResult.ExitCode }
                }
            },
            @{
                Name   = 'DISM Capability'
                Action = {
                    $result = Invoke-WithConsoleRedirection -Action {
                        Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.addingStoreViaDism') -Command 'DISM' -Arguments @('/Online', '/Add-Capability', '/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0') -TimeoutSeconds 300 -LogContextKey "Store-DISM-Add"
                    }
                    return @{ ExitCode = $result.ExitCode }
                }
            }
        )

        $success = $false
        foreach ($method in $installMethods) {
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.attemptedVia0' -Args @($($method.Name)))
            try {
                $result = $method.Action.Invoke()
                Clear-ProgressLine
                [Console]::Out.Flush()
                $isSuccess = $result -and ($result.ExitCode -in @(0, 3010, 1638, -1978335189))
                if ($isSuccess) {
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.microsoftStoreReinstalledVia0' -Args @($($method.Name)))
                    $success = $true
                    break
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.method0FailedExitcode1' -Args @($($method.Name), $(if ($result.ExitCode) { $result.ExitCode } else { 'N/A' })))
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.method0Failed1' -Args @($($method.Name), $($_.Exception.Message)))
            }
        }

        if ($success) {
            $null = Invoke-WithConsoleRedirection -Action {
                Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.resetCacheMicrosoftStoreWsreset') -Command 'wsreset.exe' -TimeoutSeconds 120 -LogContextKey "Store-WSReset"
            }
            Clear-ProgressLine
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.storeCacheReset')
        }
        else {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToReinstallMicrosoftStoreViaAutomaticMethods')
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.emergencyAttemptViaAppxmanifest')
            try {
                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.disasterRecoveryStore') -Process -Action {
                    $ProgressPreference = 'SilentlyContinue'
                    Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object {
                        Start-AppxSilentProcess -AppxPath "$($_.InstallLocation)\AppXManifest.xml" -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown'
                    }
                } -TimeoutSeconds 300
                Clear-ProgressLine
                [Console]::Out.Flush()
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.microsoftStoreRestoredViaEmergencyMethod')
                $success = $true
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.disasterRecoveryFailed0' -Args @($($_.Exception.Message)))
            }
        }

        return $success
    }

    function Install-UniGetUI {
        Write-StyledMessage -Type 'Info' -Text ("🔄 " + (Get-SourceTextLoc 'toolText.unigetUiInstallation'))

        $wingetExe = Get-WingetExecutable
        if (-not (Test-Path $wingetExe -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.wingetNotAvailableUnigetUiRequiresWinget')
            return $false
        }

        try {
            # Disinstalla versioni precedenti (entrambi i vecchi ID)
            foreach ($oldId in @('MartiCliment.UniGetUI', 'Devolutions.UniGetUI')) {
                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.uninstallation0' -Args @($oldId)) -Command $wingetExe -Arguments @('uninstall', '--exact', '--id', $oldId, '--silent', '--disable-interactivity') -TimeoutSeconds 120 -LogContextKey "Store-UniGet-Uninstall"
                Clear-ProgressLine
                [Console]::Out.Flush()
            }

            $processResult = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.unigetUiInstallation') -Command $wingetExe -Arguments @('install', '--exact', '--id', 'Devolutions.UniGetUI', '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements', '--silent', '--disable-interactivity', '--force') -TimeoutSeconds 600 -LogContextKey "Store-UniGet-Install"

            Clear-ProgressLine
            [Console]::Out.Flush()

            $isSuccess = $processResult.ExitCode -in @(0, 3010, 1638, -1978335189)

            if ($isSuccess) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.unigetUiInstalledSuccessfully')
                try {
                    # Rimuove avvio automatico da registro (tutti i nomi noti: vecchio WingetUI e nuovo UniGetUI)
                    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
                    foreach ($runName in @('WingetUI', 'UniGetUI', 'UniGet UI')) {
                        if (Get-ItemProperty -Path $regPath -Name $runName -ErrorAction SilentlyContinue) {
                            Remove-ItemProperty -Path $regPath -Name $runName -ErrorAction SilentlyContinue *>$null
                            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.autostart0RemovedFromRegistry' -Args @($runName))
                        }
                    }
                    # Rimuove collegamento dalla cartella Startup
                    $startupFolder = [Environment]::GetFolderPath('Startup')
                    foreach ($lnkName in @('UniGetUI.lnk', 'WingetUI.lnk', 'UniGet UI.lnk')) {
                        $lnkPath = Join-Path $startupFolder $lnkName
                        if (Test-Path $lnkPath) {
                            Remove-Item $lnkPath -Force -ErrorAction SilentlyContinue *>$null
                            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.autostartLink0Removed' -Args @($lnkName))
                        }
                    }
                }
                catch { }
                return $true
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.unigetUiInstallationFinishedWithCode0' -Args @($($processResult.ExitCode))))
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorInstallingUnigetUi0' -Args @($($_.Exception.Message)))
            return $false
        }
    }

    function Invoke-WithConsoleRedirection {
        <#
        .SYNOPSIS
            Suppresses all Win32 output from the deployment engine.
            Redirects stdout and stderr and suppresses every WriteConsoleW call.
            If no real console exists, runs the action without redirection.
        #>
        param([scriptblock]$Action)

        if (-not ('WinReinstallStore.NativeConsole' -as [type])) {
            Add-Type -Namespace 'WinReinstallStore' -Name 'NativeConsole' -MemberDefinition @'
                [DllImport("kernel32.dll")] public static extern bool SetStdHandle(int nStdHandle, IntPtr hHandle);
                [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
                [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
                public static extern IntPtr CreateFileW(
                    string lpFileName, uint dwDesiredAccess, uint dwShareMode,
                    IntPtr lpSecurityAttributes, uint dwCreationDisposition,
                    uint dwFlagsAndAttributes, IntPtr hTemplateFile);
                [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr hObject);
'@
        }

        $STD_OUTPUT = -11
        $STD_ERROR = -12
        $STD_INPUT = -10
        $INVALID_HANDLE_VALUE = [IntPtr]::new(-1)

        $hOrigOut = $null
        $hOrigErr = $null
        $hOrigIn = $null
        $hNullOut = $null
        $hNullIn = $null

        try {
            $hOrigOut = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_OUTPUT)
            $hOrigErr = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_ERROR)
            $hOrigIn = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_INPUT)
        }
        catch {
            return & $Action
        }

        if ($hOrigOut -eq $INVALID_HANDLE_VALUE -or $hOrigOut -eq [IntPtr]::Zero -or
            $hOrigErr -eq $INVALID_HANDLE_VALUE -or $hOrigErr -eq [IntPtr]::Zero) {
            return & $Action
        }

        try {
            $hNullOut = [WinReinstallStore.NativeConsole]::CreateFileW(
                'NUL', 0x40000000, 3, [IntPtr]::Zero, 3, 0x80, [IntPtr]::Zero)
            $hNullIn = [WinReinstallStore.NativeConsole]::CreateFileW(
                'NUL', 0x80000000, 3, [IntPtr]::Zero, 3, 0x80, [IntPtr]::Zero)
        }
        catch {
            return & $Action
        }

        $canRedirect = (
            $hNullOut -ne $INVALID_HANDLE_VALUE -and $hNullOut -ne [IntPtr]::Zero -and
            $hOrigOut -ne $INVALID_HANDLE_VALUE -and $hOrigOut -ne [IntPtr]::Zero -and
            $hOrigErr -ne $INVALID_HANDLE_VALUE -and $hOrigErr -ne [IntPtr]::Zero
        )

        if (-not $canRedirect) {
            return & $Action
        }

        $handlesRedirected = $false
        try {
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_OUTPUT, $hNullOut) *>$null
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_ERROR, $hNullOut) *>$null
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_INPUT, $hNullIn) *>$null
            $handlesRedirected = $true

            $env:POWERSHELL_TELEMETRY_OPTOUT = '1'
            $ProgressPreference = 'SilentlyContinue'

            return & $Action
        }
        finally {
            if ($handlesRedirected) {
                try {
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_OUTPUT, $hOrigOut) *>$null
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_ERROR, $hOrigErr) *>$null
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_INPUT, $hOrigIn) *>$null
                }
                catch { }
            }
            if ($hNullOut -and $hNullOut -ne $INVALID_HANDLE_VALUE -and $hNullOut -ne [IntPtr]::Zero) {
                try { [WinReinstallStore.NativeConsole]::CloseHandle($hNullOut) *>$null } catch { }
            }
            if ($hNullIn -and $hNullIn -ne $INVALID_HANDLE_VALUE -and $hNullIn -ne [IntPtr]::Zero) {
                try { [WinReinstallStore.NativeConsole]::CloseHandle($hNullIn) *>$null } catch { }
            }
        }
    }

    try {
        Write-StyledMessage -Type 'Progress' -Text (Get-SourceTextLoc 'toolText.startingStoreWingetReinstallation')

        $wingetResult = $false

        try {
            $ProgressPreference = 'SilentlyContinue'
            $wingetResult = Invoke-WithConsoleRedirection -Action { Reset-Winget -Force }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unexpectedErrorDuringResetWinget0' -Args @($($_.Exception.Message)))
            Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.resetWingetUnhandledException0' -Args @($($_.Exception.Message)))
        }
        finally {
            $ProgressPreference = $savedProgressPref
        }

        if ($wingetResult) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.wingetRestoredAndOperational')
        }
        else {
            Write-StyledMessage -Type 'Error' -Text ((Get-SourceTextLoc 'toolText.wingetRestoreFailed'))
        }

        $storeResult = Install-MicrosoftStore
        $unigetResult = Install-UniGetUI

        if ($storeResult) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.microsoftStoreSuccessfullyRestored')
        }
        else {
            Write-StyledMessage -Type 'Error' -Text ((Get-SourceTextLoc 'toolText.microsoftStoreNotRestored'))
        }

        if ($unigetResult) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.unigetUiInstalled')
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.unigetUiRequireManualVerification'))
        }

        Write-StyledMessage -Type 'Success' -Text ("🎉 " + (Get-SourceTextLoc 'toolText.operationCompleted'))
    }
    finally {
        $ProgressPreference = $savedProgressPref
    }

    Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.rebootingIn') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
}
