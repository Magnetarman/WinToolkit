<#
.SYNOPSIS
    Starter script that installs and configures WinToolkit.
.DESCRIPTION
    Verifies, installs and configures some software, then creates a WinToolkit shortcut on the desktop.
.NOTES
    This file is executed by the ASCII-safe start.ps1 stub under PowerShell 7+.
#>

[CmdletBinding()]
param(
    [string]$Language = $(if ($env:WTOOLKIT_LANGUAGE) { $env:WTOOLKIT_LANGUAGE } else { 'en-US' }),
    [string]$OfflineModeDir = $env:WTOOLKIT_OFFLINE_MODE_DIR
)

# --- GLOBAL CONFIGURATION ---

$script:AppConfig = @{
    MsgStyles       = @{
        Success = @{ Icon = '✅'; Color = 'Green' }
        Warning = @{ Icon = '⚠️'; Color = 'Yellow' }
        Error   = @{ Icon = '❌'; Color = 'Red' }
        Info    = @{ Icon = '💎'; Color = 'Cyan' }
    }
    # ============================================================================
    # HEADER CONFIGURATION - Modify here to update title and version
    # ============================================================================
    Header          = @{
        Title   = "Toolkit Starter By MagnetarMan"
        Version = "Version 2.6.0 (Build 5)"
    }
    URLs            = @{
        StartScript             = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/start.ps1"
        WingetMSIX              = "https://aka.ms/getwinget"
        GitRelease              = "https://api.github.com/repos/git-for-windows/git/releases/latest"
        PowerShellRelease       = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        OhMyPoshTheme           = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
        PowerShellProfile       = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/assets/Microsoft.PowerShell_profile.ps1"
        WindowsTerminalSettings = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/assets/settings.json"
        ToolkitIcon             = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/images/WinToolkit.ico"
        TerminalRelease         = "https://api.github.com/repos/microsoft/terminal/releases/latest"
        WebInstaller            = "https://magnetarman.com/WinToolkit-Dev"
    }
    Paths           = @{
        Logs          = "$env:LOCALAPPDATA\WinToolkit\logs"
        WinToolkitDir = "$env:LOCALAPPDATA\WinToolkit"
        Temp          = "$env:TEMP\WinToolkitSetup"
        Packages      = "$env:LOCALAPPDATA\Packages"
        Desktop       = [Environment]::GetFolderPath('Desktop')
        wtExe         = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
        wtDir         = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    }
    Registry        = @{
        TerminalStartup = "HKCU:\Console\%%Startup"
    }
    WindowsTerminal = @{
        DelegationTerminalClsid = "{E12F0936-0E6F-548E-A9F6-B20C69A27D17}"
        DelegationConsoleClsid  = "{B23D10C0-31E3-401A-97EF-4BB30B62E10B}"
    }
    WingetProcesses = @(
        'WinStore.App',
        'wsappx',
        'AppInstaller',
        'Microsoft.WindowsStore',
        'Microsoft.DesktopAppInstaller',
        'winget',
        'WindowsPackageManagerServer'
    )
    UpdateServices  = @('wuauserv', 'bits', 'cryptsvc', 'dosvc')
    Layout          = @{
        Width = 65
    }
}

# ============================================================================
# UTILITY FUNCTIONS & WINGET SUPPORT
# ============================================================================



function Test-VCRedistInstalled {
    <#
    .SYNOPSIS
    Checks if Visual C++ Redistributable is installed and verifies the major version is 14.
    #>

    $64BitOS = [System.Environment]::Is64BitOperatingSystem
    $checksPassed = 0

    # Always check the 32-bit version (exists on all systems)
    $registryPath32 = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86'
    $dllPath32 = "$env:windir\syswow64\concrt140.dll"

    if ((Test-Path -Path $registryPath32) -and
        ((Get-ItemProperty -Path $registryPath32 -Name 'Major' -ErrorAction SilentlyContinue).Major -eq 14) -and
        [System.IO.File]::Exists($dllPath32)) {
        $checksPassed++
    }

    # If the system is 64-bit we also check the 64-bit version
    if ($64BitOS) {
        $registryPath64 = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'
        $dllPath64 = "$env:windir\system32\concrt140.dll"

        if ((Test-Path -Path $registryPath64) -and
            ((Get-ItemProperty -Path $registryPath64 -Name 'Major' -ErrorAction SilentlyContinue).Major -eq 14) -and
            [System.IO.File]::Exists($dllPath64)) {
            $checksPassed++
        }
    }

    # On 32-bit systems: 32-bit version is enough
    # On 64-bit systems: BOTH 32 + 64 bit versions must be present
    $requiredChecks = if ($64BitOS) { 2 } else { 1 }

    return $checksPassed -eq $requiredChecks
}

function Get-WinGetFolder {
    <#
    .SYNOPSIS
    Finds the latest official Winget installation folder.
    #>
    try {
        $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
        $wingetDir = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.Name -replace '^[^\d]+_((\d+\.)*\d+)_.*', '$1') } -Descending | Select-Object -First 1

        if ($wingetDir) {
            return $wingetDir.FullName
        }
        return $null
    }
    catch {
        return $null
    }
}

function Get-WinGetExecutable {
    <#
    .SYNOPSIS
    Gets the valid path of winget.exe, with direct fallback.
    #>
    # Try the standard alias path first
    $aliasPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    if (Test-Path $aliasPath) {
        return $aliasPath
    }

    # Fallback: direct path in the installation folder
    $wingetFolder = Get-WinGetFolder
    if ($wingetFolder) {
        $exePath = Join-Path $wingetFolder "winget.exe"
        if (Test-Path $exePath) {
            return $exePath
        }
    }

    return $null
}

function Reset-WingetSources {
    <#
    .SYNOPSIS
    Resets Winget sources to force repository metadata refresh.
    #>
    try {
        $wingetExe = Get-WinGetExecutable
        if ($wingetExe) {
            $null = & $wingetExe source reset --force 2>&1
        }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Winget source reset failed: $($_.Exception.Message)"
    }
}

function Repair-WingetMsStoreSource {
    <#
    .SYNOPSIS
    Detects and fixes msstore certificate pinning failure (0x8a15005e).
    #>
    try {
        $wingetExe = Get-WinGetExecutable
        if (-not $wingetExe) { return }

        $output = & $wingetExe source update --source msstore --accept-source-agreements 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0 -and $output -match '0x8a15005e') {
            Write-StyledMessage -Type Warning -Text "Detected msstore certificate pinning failure (0x8a15005e). Resetting Winget sources to default..."
            $null = & $wingetExe source reset --force 2>&1
            Update-EnvironmentPath
            Write-StyledMessage -Type Success -Text "Winget sources reset completed. Using 'winget' source only."
        }
    }
    catch {
        # Silently ignore - not critical
    }
}

function Repair-SystemClock {
    try {
        $w32Time = Get-Service w32time -ErrorAction SilentlyContinue
        if ($w32Time -and $w32Time.Status -ne 'Running') {
            Start-Service w32time -ErrorAction SilentlyContinue | Out-Null
        }
        w32tm /resync /force 2>&1 | Out-Null
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.systemClockResynced')
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "System clock resync failed: $($_.Exception.Message)"
    }
}

function Reset-SchannelSettings {
    try {
        $schannelPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL'
        if (-not (Test-Path $schannelPath)) { return }

        $tls12Path = Join-Path $schannelPath 'Protocols\TLS 1.2'
        if (Test-Path $tls12Path) {
            foreach ($mode in @('Client', 'Server')) {
                $modePath = Join-Path $tls12Path $mode
                if (Test-Path $modePath) {
                    $enabled = (Get-ItemProperty -Path $modePath -Name 'Enabled' -ErrorAction SilentlyContinue).Enabled
                    if ($enabled -eq 0) {
                        Set-ItemProperty -Path $modePath -Name 'Enabled' -Value 1 -Type DWord -Force
                        Write-ToolkitLog -Level 'INFO' -Message "Re-enabled TLS 1.2 $mode"
                    }
                }
            }
        }

        $cipherPath = Join-Path $schannelPath 'Ciphers'
        if (Test-Path $cipherPath) {
            Get-ChildItem $cipherPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $prop = Get-ItemProperty -Path $_.FullName -Name 'Enabled' -ErrorAction SilentlyContinue
                if ($prop -and $prop.Enabled -eq 0) {
                    Remove-ItemProperty -Path $_.FullName -Name 'Enabled' -ErrorAction SilentlyContinue
                    Write-ToolkitLog -Level 'INFO' -Message "Removed disabled cipher: $($_.PSChildName)"
                }
            }
        }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "SCHANNEL reset failed: $($_.Exception.Message)"
    }
}

function Reset-HostsFile {
    try {
        $hostsPath = 'C:\Windows\System32\drivers\etc\hosts'
        if (-not (Test-Path $hostsPath)) { return }

        $lines = Get-Content $hostsPath -ErrorAction SilentlyContinue
        if (-not $lines) { return }

        $hasOverrides = $false
        $newLines = @()
        foreach ($line in $lines) {
            if ($line -match '(?i)microsoft\.com|storeedgefd|winget\.azureedge\.net') {
                $hasOverrides = $true
                continue
            }
            $newLines += $line
        }

        if ($hasOverrides) {
            $hostsHeader = @(
                '# Copyright (c) 1993-2009 Microsoft Corp.',
                '# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.',
                '#',
                '# This file contains the mappings of IP addresses to host names. Each',
                '# entry should be kept on an individual line. The IP address should',
                '# be placed in the first column followed by the corresponding host name.',
                '# The IP address and the host name should be separated by at least one',
                '# space.',
                '#',
                '# Additionally, comments (such as these) may be inserted on individual',
                '# lines or following the machine name denoted by a ''#'' symbol.',
                '#',
                '# For example:',
                '#      102.54.94.97     rhino.acme.com          # source server',
                '#       38.25.63.10     x.acme.com              # x client host'
            )
            $finalContent = $hostsHeader + ($newLines | Where-Object { $_.Trim() -ne '' })
            Set-Content -Path $hostsPath -Value $finalContent -Encoding ASCII -Force
            Write-ToolkitLog -Level 'INFO' -Message "Hosts file reset: removed Microsoft/Store/Winget overrides"
        }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Hosts file reset failed: $($_.Exception.Message)"
    }
}

function Repair-AppInstaller {
    try {
        $pkg = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue
        if ($pkg) {
            $pkg | Reset-AppxPackage 2>$null | Out-Null
        }
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            $tempFile = Join-Path $env:TEMP 'WingetInstaller.msixbundle'
            Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile $tempFile -UseBasicParsing -ErrorAction Stop
            Start-AppxSilentProcess -AppxPath $tempFile -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.DesktopAppInstaller'
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "App Installer repair failed: $($_.Exception.Message)"
    }
}

function Test-WingetCompatibility {
    <#
    .SYNOPSIS
    Checks OS compatibility with Winget.
    #>
    $osInfo = [Environment]::OSVersion
    $build = $osInfo.Version.Build

    if ($osInfo.Version.Major -lt 10) {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.wingetNotSupportedOnWindows0' -Args @($($osInfo.Version.Major)))
        return $false
    }
    if ($osInfo.Version.Major -eq 10 -and $build -lt 16299) {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.windows10Build0NonSupportaWinget' -Args @($build))
        return $false
    }
    return $true
}

function Test-WingetFunctionality {
    <#
    .SYNOPSIS
    Verifies that Winget is present in PATH and works correctly.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.checkWingetFunctionality')

    # Update PATH to detect recent installations
    Update-EnvironmentPath

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInPath')
        return $false
    }

    try {
        # Usa --version: locale, immediato, non richiede connessione internet
        $versionOutput = (& winget --version 2>$null) | Out-String
        if ($LASTEXITCODE -eq 0 -and $versionOutput -match 'v\d+\.\d+') {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.operationalWingetVersion0' -Args @($($versionOutput.Trim())))
            return $true
        }
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetPresentButNotRespondingCorrectlyExitcode0' -Args @($LASTEXITCODE))
        return $false
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.errorDuringWingetTest0' -Args @($($_.Exception.Message)))
        return $false
    }
}

function Invoke-ForceCloseWinget {
    <#
    .SYNOPSIS
    Closes the processes that actually block Appx installation.
    Safe approach that avoids killing system-critical processes.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.closingInterferingProcesses')

    # Targeted list of processes that actually block Appx installation
    $interferingProcesses = $script:AppConfig.WingetProcesses

    foreach ($procName in $interferingProcesses) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -ne $PID } |  # Don't kill ourselves
        Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep 2
    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.interferingProcessesClosed')
}

function Invoke-StopUpdateServices {
    <#
    .SYNOPSIS
    Temporarily suspends Windows Update and related services to avoid conflicts with Winget.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.temporarilySuspendWindowsUpdateServicesToAvoidConflicts')
    $services = $script:AppConfig.UpdateServices
    foreach ($svc in $services) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.serviceStop0' -Args @($svc))
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        }
    }
    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updateServicesSuccessfullySuspended')
}

function Invoke-StartUpdateServices {
    <#
    .SYNOPSIS
    Restores Windows Update and related services.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resettingWindowsUpdateServices')
    $services = $script:AppConfig.UpdateServices
    foreach ($svc in $services) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingService0' -Args @($svc))
            try {
                Start-Service -Name $svc -ErrorAction Stop
            }
            catch {
                # Ignore startup-in-progress warnings and delayed services
                if ($_.Exception.Message -notmatch 'in corso') {
                    Write-ToolkitLog -Level 'Warning' -Message (Get-SourceTextLoc 'uiText.startingService01' -Args @(${svc}, $($_.Exception.Message)))
                }
            }
        }
    }
    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updateServicesRestored')
}

function Set-WingetPathPermissions {
    <#
    .SYNOPSIS
    Applies PATH permissions and adds winget folder to PATH.
    Based on asheroto's Apply-PathPermissionsFixAndAddPath.
    #>

    $wingetFolderPath = $null

    try {
        $wingetFolderPath = Get-WinGetFolder
    }
    catch { }

    if ($wingetFolderPath) {
        # Fix permissions
        Set-PathPermissions -FolderPath $wingetFolderPath

        # Add to system PATH
        Add-ToEnvironmentPath -PathToAdd $wingetFolderPath -Scope 'System'

        # Add user PATH with literal %LOCALAPPDATA%
        Add-ToEnvironmentPath -PathToAdd "%LOCALAPPDATA%\Microsoft\WindowsApps" -Scope 'User'

        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.pathAndWingetPermissionsUpdated')
    }
}

function Repair-WingetDatabase {
    <#
    .SYNOPSIS
    Performs a complete Winget database and configuration restore.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startWingetDatabaseRecovery')

    try {
        # 1. Ferma i processi interferenti
        Invoke-ForceCloseWinget

        # 2. Pulizia cache locale di Winget
        $wingetCachePath = "$env:LOCALAPPDATA\WinGet"
        if (Test-Path $wingetCachePath) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.puliziaCacheWinget')
            Get-ChildItem -Path $wingetCachePath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\lock\\|\\tmp\\' } |
            ForEach-Object {
                try {
                    Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
                }
                catch {}
            }
        }

        # 3. Remove corrupted state files (JSON only)
        $stateFiles = @(
            "$env:LOCALAPPDATA\WinGet\Data\USERTEMPLATE.json",
            "$env:LOCALAPPDATA\WinGet\Data\DEFAULTUSER.json"
        )

        foreach ($file in $stateFiles) {
            if (Test-Path $file -PathType Leaf) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetStatusFile0' -Args @($file))
                Remove-Item $file -Force -ErrorAction SilentlyContinue
            }
        }

        # 4. Reset Winget sources
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetWingetSources')
        try {
            $null = & winget.exe source reset --force 2>&1
        }
        catch {}    # Ignore errors during reset

        # 5. Full reset of the AppInstaller package (Crucial for ACCESS_VIOLATION)
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetPackageMicrosoftDesktopappinstaller')
        if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
            Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
        }

        # 6. Re-register AppInstaller manifest
        try {
            $manifest = (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue).InstallLocation
            if ($manifest) {
                $manifestXml = Join-Path $manifest 'AppxManifest.xml'
                if (Test-Path $manifestXml) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.reRegisterManifestAppxmanifestXml')
                    Start-AppxSilentProcess -AppxPath $manifestXml -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown' | Out-Null
                }
            }
        }
        catch { }

        # 7. Retry with WinGet module if available
        try {
            if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.esecuzioneRepairWingetpackagemanager')
                Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
            }
        }
        catch {
            if ($_.Exception.Message -match '0x80073D06' -or $_.Exception.Message -match 'versione successiva') {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerCompletedHigherVersionAlreadyPresent')
            }
            else {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.repairModuleFailed0' -Args @($($_.Exception.Message)))
            }
        }

        # 8. Applica permessi e refresh PATH
        Set-WingetPathPermissions
        Update-EnvironmentPath

        # 9. Verify winget responds
        Start-Sleep 2
        $testVersion = & winget --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.restoreCompletedButWingetMayNotWork')
        }
        else {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetDatabaseRestoredVersion0' -Args @($testVersion))
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorRestoringDatabase0' -Args @($($_.Exception.Message)))
        return $false
    }
}

function Test-WingetDeepValidation {
    <#
    .SYNOPSIS
    Performs an in-depth connectivity and functionality test of Winget.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.deepTestExecutionOfWingetSearchForPacketsOnTheNetwork')

    try {
        $wingetExe = Get-WinGetExecutable
        if (-not $wingetExe) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInSystem')
            return $false
        }

        # Tests connectivity to repositories, local DB integrity and Winget parser
        # Performs direct search to obtain correct ExitCode
        $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
        $exitCode = $LASTEXITCODE

        # Check for access violation crash (0xC0000005 = -1073741819 or 3221225781)
        if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.crashDetectedExitcode0AccessViolationAdvancedRecoveryAttempt' -Args @($exitCode))

            # 1. Try DB restore + Appx reset first
            $null = Repair-WingetDatabase

            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.repeatTestAfterDatabaseRestore')
            Start-Sleep 3
            $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
            $exitCode = $LASTEXITCODE

            # 2. If it still crashes, try complete reinstall
            if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.persistentCrashStartingCompleteReinstallationOfWinget')
                $null = Install-WingetPackage -Force

                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.finalTestAfterReinstallation')
                Start-Sleep 3
                $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
                $exitCode = $LASTEXITCODE
            }
        }

        if ($exitCode -eq 0) {
            # Controllo freschezza sorgenti
            try {
                $null = & $wingetExe source update --accept-source-agreements 2>&1
            }
            catch {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'toolText.sourceUpdateError0' -Args @($($_.Exception.Message)))
            }
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.deepTestPassedWingetCommunicatesCorrectlyWithRepositories')
            return $true
        }
        # Logga i dettagli per debug
        $errorDetails = $searchResult | Out-String
        if ($errorDetails.Length -gt 200) {
            $errorDetails = $errorDetails.Substring(0, 200) + "."
        }
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.deepTestFailedExitcode0Details1' -Args @($exitCode, $errorDetails))
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorDuringWingetDeepTest0' -Args @($($_.Exception.Message)))
        return $false
    }
}

# ============================================================================
# FUNZIONI DI INSTALLAZIONE
# ============================================================================

function Get-WingetDownloadUrl {
    <#
    .SYNOPSIS
    Recupera l'URL di download dell'ultimo asset di Winget CLI da GitHub.
    #>
    param([string]$Match)
    try {
        $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
        $asset = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
        if ($asset) {
            return $asset.browser_download_url
        }
        throw (Get-SourceTextLoc 'uiText.asset0NotFound' -Args @($Match))
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.assetUrlRetrievalError0' -Args @($($_.Exception.Message)))
        return $null
    }
}

function Install-WingetCore {
    <#
    .SYNOPSIS
    Performs the minimal Winget installation and core dependencies.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingWingetCoreRecoveryProcedure')

    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    $tempDir = "$env:TEMP\WinToolkitWinget"
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force *>$null
    }

    try {
        # 1. Visual C++ Redistributable (usando test avanzato)
        if (-not (Test-VCRedistInstalled)) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.visualCRedistributableInstallation')
            $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
            $vcUrl = "https://aka.ms/vs/17/release/vc_redist.$arch.exe"
            $vcFile = Join-Path $tempDir "vc_redist.exe"

            Invoke-WebRequest -Uri $vcUrl -OutFile $vcFile -UseBasicParsing
            $procParams = @{
                FilePath     = $vcFile
                ArgumentList = @("/install", "/quiet", "/norestart")
                Wait         = $true
                NoNewWindow  = $true
            }
            Start-Process @procParams
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.visualCRedistributableInstalled')
        }
        else {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.visualCRedistributableAlreadyPresent')
        }

        # 2. Dipendenze (UI.Xaml, VCLibs) — Estrazione dal pacchetto ufficiale (Metodo Sicuro)
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadWingetDependenciesFromTheOfficialRepository')
        $depUrl = Get-WingetDownloadUrl -Match 'DesktopAppInstaller_Dependencies.zip'
        if ($depUrl) {
            $depZip = Join-Path $tempDir "dependencies.zip"
            try {
                $iwrDepParams = @{
                    Uri             = $depUrl
                    OutFile         = $depZip
                    UseBasicParsing = $true
                    ErrorAction     = 'Stop'
                }
                Invoke-WebRequest @iwrDepParams

                # Architecture-targeted extraction and installation
                $extractPath = Join-Path $tempDir "deps"
                Expand-Archive -Path $depZip -DestinationPath $extractPath -Force

                $archPattern = if ([Environment]::Is64BitOperatingSystem) { "x64|ne" } else { "x86|ne" }
                $appxFiles = Get-ChildItem -Path $extractPath -Recurse -Filter "*.appx" | Where-Object { $_.Name -match $archPattern }

                $dependencies = @()
                foreach ($file in $appxFiles) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.dependencyFound0' -Args @($($file.Name)))
                    $dependencies += $file.FullName
                }
            }
            catch {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.unableToExtractOrInstallDependenciesFromTheOfficialZipError0' -Args @($($_.Exception.Message)))
            }
        }

        # 3. Winget Bundle
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadAndInstallWingetBundleWithDependencies')
        $wingetUrl = Get-WingetDownloadUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        if ($wingetUrl) {
            $wingetFile = Join-Path $tempDir "winget.msixbundle"
            Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetFile -UseBasicParsing

            $deps = if ($dependencies) { $dependencies } else { @() }
            if (Start-AppxSilentProcess -AppxPath $wingetFile -DependencyPaths $deps -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.DesktopAppInstaller') {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetCoreSuccessfullyInstalled')
            }
            else {
                throw (Get-SourceTextLoc 'uiText.wingetCoreInstallationFailed')
            }
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorRestoringWinget0' -Args @($($_.Exception.Message)))
        return $false
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        $ProgressPreference = $oldProgress
    }
}

function Install-WingetPackage {
    <#
    .SYNOPSIS
    Complete Winget installation and restore procedure.
    #>
    param([switch]$Force)

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startWingetInstallationVerificationProcedure')

    if (-not (Test-WingetCompatibility)) {
        return $false
    }

    # Use the advanced ForceClose function
    Invoke-ForceCloseWinget

    try {
        $oldProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        # Pulizia temporanei
        $tempPath = "$env:TEMP\WinGet"
        if (Test-Path $tempPath) {
            Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Reset sorgenti se Winget esiste
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            try {
                $null = & "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" source reset --force 2>$null
            }
            catch {}
        }

        if (-not (Get-Module -ListAvailable Microsoft.WinGet.Client) -or $Force) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingMicrosoftWingetClientModule')
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetClientModuleInstalled')
            }
            catch {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.moduloWingetClient0' -Args @($($_.Exception.Message)))
            }
        }
        Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue

        # Riparazione via modulo
        if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.tentativoRiparazioneWingetRepairWingetpackagemanager')
            try {
                Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerEseguito')
            }
            catch {
                if ($_.Exception.Message -match '0x80073D06' -or $_.Exception.Message -match 'versione successiva') {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerIgnoredHigherVersionAlreadyPresent')
                }
                else {
                    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerFallito0' -Args @($($_.Exception.Message)))
                }
            }
            Start-Sleep 3
        }

        # Final fallback: installation via MSIXBundle
        if (-not (Get-Command winget -ErrorAction SilentlyContinue) -or $Force) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadMsixbundleDaMicrosoft')

            $msixTempDir = $script:AppConfig.Paths.Temp
            if (-not (Test-Path $msixTempDir)) {
                $null = New-Item -Path $msixTempDir -ItemType Directory -Force
            }
            $tempInstaller = Join-Path $msixTempDir "WingetInstaller.msixbundle"

            $iwrParams = @{
                Uri             = $script:AppConfig.URLs.WingetMSIX
                OutFile         = $tempInstaller
                UseBasicParsing = $true
                ErrorAction     = 'Stop'
            }
            Invoke-WebRequest @iwrParams
            if (Start-AppxSilentProcess -AppxPath $tempInstaller -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.DesktopAppInstaller') {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetMsixBundleInstallationSuccessful')
            }
            else {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetMsixBundleInstallationFailed')
            }
            Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
            Start-Sleep 3
        }

        # Reset App Installer
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetAppInstaller')
        try {
            Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
        }
        catch {}

        # Applica permessi PATH e registrazione (basato su asheroto)
        Set-WingetPathPermissions
        Start-Sleep 2
        Update-EnvironmentPath

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetInstalledAndWorking')
            return $true
        }
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.unableToInstallWinget')
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.criticalError0' -Args @($($_.Exception.Message)))
        return $false
    }
    finally {
        $ProgressPreference = $oldProgress
    }
}

function Install-GitPackage {
    <#
    .SYNOPSIS
    Verifies and installs Git with direct download fallback.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.verifyGitInstallation')

    Update-EnvironmentPath

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitAlreadyInstalled')
        return $true
    }

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.gitInstallation')

    # 1. Attempt via winget (Priority)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $result = Invoke-WingetCommand -Arguments "install Git.Git --source winget --accept-source-agreements --accept-package-agreements --silent"

        if ($result.ExitCode -eq 0) {
            Start-Sleep 3
            Update-EnvironmentPath

            if (Get-Command git -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitInstalledViaWinget')
                return $true
            }
        }
    }

    # 2. Fallback: direct download from GitHub
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.fallbackDownloadGitDaGithub')
        $release = Invoke-RestMethod -Uri $script:AppConfig.URLs.GitRelease -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -like "*64-bit.exe" } | Select-Object -First 1

        if (-not $asset) {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.64BitGitAssetNotFound')
            return $false
        }

        $tempDir = $script:AppConfig.Paths.Temp
        if (-not (Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force | Out-Null }
        $installerPath = Join-Path $tempDir $asset.name

        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -UseBasicParsing

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.runningGitInstaller')

        $procParams = @{
            FilePath     = $installerPath
            ArgumentList = @("/SILENT", "/NORESTART", "/CLOSEAPPLICATIONS")
            Wait         = $true
            PassThru     = $true
        }
        $process = Start-Process @procParams

        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

        if ($process.ExitCode -eq 0) {
            Update-EnvironmentPath
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitInstalledSuccessfully')
            return $true
        }

        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.installationFailedCode0' -Args @($($process.ExitCode)))
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.gitInstallationError0' -Args @($($_.Exception.Message)))
        return $false
    }
}

function Format-CenteredText {
    <#
    .SYNOPSIS
    Formats text centered to the specified width.
    #>
    param(
        [string]$Text,
        [int]$Width = 80
    )
    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    return (" " * $padding) + $Text
}

function Show-Header {
    <#
    .SYNOPSIS
    Displays the script graphical header with title and version.
    #>
    param(
        [string]$Title,
        [string]$Version
    )
    Clear-Host
    $width = $script:AppConfig.Layout.Width
    Write-Host ('═' * $width) -ForegroundColor Green
    @(
        '      __        __  _   _   _ ',
        '      \ \      / / | | | \ | |',
        '       \ \ /\ / /  | | |  \| |',
        '        \ V  V /   | | | |\  |',
        '         \_/\_/    |_| |_| \_|',
        '',
        $Title,
        $Version
    ) | ForEach-Object { Write-Host (Format-CenteredText -Text $_ -Width $width) -ForegroundColor White }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''
}

$script:SourceTextLanguageData = $null
$script:SourceTextDefaultLanguageData = $null

function Get-SourceTextLanguageDirectory {
    $root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $candidates = @(
        (Join-Path $root 'languages'),
        (Join-Path (Split-Path $root -Parent) 'languages'),
        (Join-Path (Get-Location) 'languages'),
        (Join-Path $env:LOCALAPPDATA 'WinToolkit\languages')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $candidates[-1]
}

function Get-RemoteAvailableCultures {
    param([string]$GitHubApiUrl = 'https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=Dev')
    try {
        $response = Invoke-RestMethod -Uri $GitHubApiUrl -UseBasicParsing -ErrorAction Stop
        return @($response | Where-Object { $_.type -eq 'dir' } | ForEach-Object { $_.name })
    }
    catch {
        return @()
    }
}

function Invoke-SourceTextLanguagePreparation {
    [CmdletBinding()]
    param(
        [string]$ScriptRoot,
        [string]$RemoteBaseUrl = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/languages',
        [string]$GitHubApiUrl = 'https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=Dev',
        [int]$CacheMaxAgeDays = 7
    )
    $localDir = Join-Path $env:LOCALAPPDATA 'WinToolkit\languages'
    $remoteCultures = Get-RemoteAvailableCultures -GitHubApiUrl $GitHubApiUrl
    $needDownload = $false
    if (-not (Test-Path $localDir)) {
        $needDownload = $true
    }
    else {
        $oldestFile = Get-ChildItem -Path $localDir -Recurse -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -First 1
        if ($oldestFile) {
            $age = (Get-Date) - $oldestFile.LastWriteTime
            if ($age.TotalDays -ge $CacheMaxAgeDays) { $needDownload = $true }
        }
        else { $needDownload = $true }
        if (-not $needDownload) {
            foreach ($culture in $remoteCultures) {
                $localFile = Join-Path $localDir $culture 'WinToolkit.psd1'
                if (-not (Test-Path $localFile)) { $needDownload = $true; break }
            }
        }
    }
    if ($needDownload -and $remoteCultures.Count -gt 0) {
        if (-not (Test-Path $localDir)) { New-Item -Path $localDir -ItemType Directory -Force | Out-Null }
        foreach ($culture in $remoteCultures) {
            $cultureDir = Join-Path $localDir $culture
            $localFile = Join-Path $cultureDir 'WinToolkit.psd1'
            if (-not (Test-Path $cultureDir)) { New-Item -Path $cultureDir -ItemType Directory -Force | Out-Null }
            try {
                $remoteUrl = "$RemoteBaseUrl/$culture/WinToolkit.psd1"
                Invoke-WebRequest -Uri $remoteUrl -OutFile $localFile -UseBasicParsing -ErrorAction Stop | Out-Null
            }
            catch {
                if (-not (Test-Path $localFile)) {
                    try {
                        $localFileFallback = Join-Path $ScriptRoot 'languages' $culture 'WinToolkit.psd1'
                        if (Test-Path $localFileFallback) { Copy-Item -Path $localFileFallback -Destination $localFile -Force }
                    }
                    catch {}
                }
            }
        }
    }
    return $localDir
}

function Get-SourceTextAutoDetectedLanguage {
    param([string]$AvailableCultures = 'en-US', [string]$SystemUICulture = ($PSUICulture.ToString()))
    $normalizedSystem = $SystemUICulture.ToLowerInvariant()
    $availableList = @($AvailableCultures -split '[\s,]+' | Where-Object { $_ })
    if ($availableList -contains $normalizedSystem) { return $normalizedSystem }
    $neutralSystem = $normalizedSystem.Split('-')[0]
    foreach ($culture in $availableList) {
        if ($culture.Split('-')[0] -eq $neutralSystem) { return $culture }
    }
    return 'en-US'
}

function Import-SourceTextLanguageFile {
    param([string]$LanguageCode)

    $languageDirectory = Get-SourceTextLanguageDirectory
    if (-not (Test-Path $languageDirectory)) { return $null }
    try {
        $localizedData = $null
        Import-LocalizedData -BindingVariable localizedData -BaseDirectory $languageDirectory -FileName 'WinToolkit.psd1' -UICulture $LanguageCode -ErrorAction Stop
        return $localizedData
    }
    catch {
        return $null
    }
}

function Initialize-SourceTextLocalization {
    param([string]$LanguageCode)

    $script:SourceTextDefaultLanguageData = Import-SourceTextLanguageFile -LanguageCode 'en-US'
    $script:SourceTextLanguageData = Import-SourceTextLanguageFile -LanguageCode $LanguageCode
    if (-not $script:SourceTextLanguageData) {
        $script:SourceTextLanguageData = $script:SourceTextDefaultLanguageData
    }
}

function Get-SourceTextLoc {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Alias('Args')][object[]]$Arguments = @()
    )

    $value = $null
    if ($script:SourceTextLanguageData -and $script:SourceTextLanguageData.ContainsKey($Key)) {
        $value = [string]$script:SourceTextLanguageData[$Key]
    }
    elseif ($script:SourceTextDefaultLanguageData -and $script:SourceTextDefaultLanguageData.ContainsKey($Key)) {
        $value = [string]$script:SourceTextDefaultLanguageData[$Key]
    }
    else {
        $value = "[MISSING TRANSLATION: $Key]"
    }
    if ($Arguments.Count -gt 0) { return [string]::Format($value, $Arguments) }
    return $value
}

$preparedDir = Invoke-SourceTextLanguagePreparation -ScriptRoot $PSScriptRoot
if ($Language -eq 'en-US') {
    $availableCultures = @()
    if ($preparedDir -and (Test-Path $preparedDir)) {
        $availableCultures = @(Get-ChildItem -Path $preparedDir -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName 'WinToolkit.psd1') } | ForEach-Object { $_.Name })
    }
    $Language = Get-SourceTextAutoDetectedLanguage -AvailableCultures ($availableCultures -join ',')
}
Initialize-SourceTextLocalization -LanguageCode $Language

function Write-StyledMessage {
    <#
    .SYNOPSIS
    Writes a formatted message with timestamp, icon and color, and saves it to the log.
    #>
    param(
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Progress')]
        [string]$Type,
        [string]$Text
    )

    $style = $script:AppConfig.MsgStyles[$Type]
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color

    # Mirror to log file
    $logLevel = switch ($Type) {
        'Success' { 'SUCCESS' }
        'Warning' { 'WARNING' }
        'Error' { 'ERROR' }
        default { 'INFO' }
    }
    Write-ToolkitLog -Level $logLevel -Message $Text
}

function Start-ToolkitLog {
    <#
    .SYNOPSIS
        Initializes the structured log file for a specific tool.
    #>
    param([string]$ToolName)

    # Clean up leftover transcripts
    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}

    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = $script:AppConfig.Paths.Logs
    if (-not (Test-Path $logdir)) {
        New-Item -Path $logdir -ItemType Directory -Force | Out-Null
    }
    $Global:CurrentLogFile = "$logdir\${ToolName}_$dateTime.log"
    Start-Transcript -Path "$logdir\${ToolName}_$dateTime.transcript.log" -Append -Force | Out-Null

    # Raccolta metadati
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $psVer = $PSVersionTable.PSVersion.ToString()

    $header = @"
[START LOG HEADER]
Start time     : $dateTime
ToolName       : $ToolName
OS             : $($os.Caption) $($os.Version)
PSVersion      : $psVer
ToolkitVersion : $($script:AppConfig.Header.Version)
[END LOG HEADER]

"@
    try { Add-Content -Path $Global:CurrentLogFile -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}

function Write-ToolkitLog {
    <#
    .SYNOPSIS
        Scrive una riga di log strutturata SOLO su file.
    #>
    param(
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',
        [string]$Message
    )
    if (-not $Global:CurrentLogFile) { return }

    $ts = Get-Date -Format "HH:mm:ss"
    $clean = $Message -replace '^\s+', ''
    # Remove all ANSI/color characters before saving to file
    $clean = $clean -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
    $line = "[$ts] [$Level] $clean"
    try { Add-Content -Path $Global:CurrentLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}

function Start-AppxSilentProcess {
    <#
    .SYNOPSIS
        Installs AppX in the background suppressing native progress bars.
    #>
    param(
        [string]$AppxPath,
        [string]$Flags = '-ForceApplicationShutdown',
        [string[]]$DependencyPaths = @(),
        [string]$ExpectedPackageName,
        [int]$TimeoutSeconds = 120
    )

    $errFile = Join-Path $env:TEMP "AppxError_$([guid]::NewGuid()).txt"
    $dependencyPathString = ""
    $dependencyPackagePathString = ""
    if ($DependencyPaths.Count -gt 0) {
        $quotedDependencies = (($DependencyPaths | ForEach-Object { "'$($_ -replace "'", "''")'" }) -join ", ")
        $dependencyPathString = "-DependencyPath $quotedDependencies"
        $dependencyPackagePathString = "-DependencyPackagePath $quotedDependencies"
    }

    $cmd = @"
`$ProgressPreference = 'SilentlyContinue';
`$ErrorActionPreference = 'SilentlyContinue';
try {
    Add-AppxPackage -Path '$($AppxPath -replace "'", "''")' $dependencyPathString $Flags -ErrorAction Stop | Out-Null
}
catch {
    if (`$_.Exception.Message -match '0x80073D06' -or `$_.Exception.Message -match 'versione successiva') {
        exit 0
    }
    if (`$_.Exception.Message -match '0x80073CF9' -or ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)) {
        try {
            Add-AppxProvisionedPackage -Online -PackagePath '$($AppxPath -replace "'", "''")' $dependencyPackagePathString -SkipLicense -ErrorAction Stop | Out-Null
            exit 0
        }
        catch {
            `$_.Exception.Message | Out-File '$errFile' -Encoding UTF8; exit 1
        }
    }
    `$_.Exception.Message | Out-File '$errFile' -Encoding UTF8; exit 1
}
exit 0
"@
    $encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -NonInteractive -EncodedCommand $encodedCmd"
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false

    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            $proc.Kill()
            $proc.WaitForExit()
            Write-ToolkitLog -Level 'ERROR' -Message "AppX installation timeout after $TimeoutSeconds seconds: $AppxPath"
            return $false
        }

        if ($proc.ExitCode -ne 0) {
            if (Test-Path $errFile) {
                $errMsg = Get-Content $errFile -Raw
                Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.appxInstallFailed01' -Args @($AppxPath, $errMsg))
            }
            return $false
        }

        if ($ExpectedPackageName -and
            -not (Get-AppxPackage -Name $ExpectedPackageName -ErrorAction SilentlyContinue)) {
            Write-ToolkitLog -Level 'ERROR' -Message "AppX command succeeded but package verification failed: $ExpectedPackageName"
            return $false
        }
        return $true
    }
    finally {
        $proc.Dispose()
        if (Test-Path $errFile) {
            Remove-Item $errFile -Force -ErrorAction SilentlyContinue
        }
    }
}



function Update-EnvironmentPath {
    <#
    .SYNOPSIS
    Reloads system and user PATH variables in the current session.
    #>
    # Reload PATH from Machine and User to detect installations in the current process
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'

    # Update the current PowerShell session
    $env:Path = $newPath
    # Force process-level refresh for .NET components started later
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
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

    try {
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
        return $false
    }
}

function Add-ToEnvironmentPath {
    <#
    .SYNOPSIS
    Adds a path to the PATH environment variable in the specified scope.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$PathToAdd,
        [ValidateSet('User', 'System')]
        [string]$Scope
    )

    # Check if path already exists
    if (-not (Test-PathInEnvironment -PathToCheck $PathToAdd -Scope $Scope)) {
        if ($Scope -eq 'System') {
            $systemEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)
            $systemEnvPath += ";$PathToAdd"
            [System.Environment]::SetEnvironmentVariable('PATH', $systemEnvPath, [System.EnvironmentVariableTarget]::Machine)
        }
        elseif ($Scope -eq 'User') {
            $userEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::User)
            $userEnvPath += ";$PathToAdd"
            [System.Environment]::SetEnvironmentVariable('PATH', $userEnvPath, [System.EnvironmentVariableTarget]::User)
        }

        # Update current process
        if (-not ($env:PATH -split ';').Contains($PathToAdd)) {
            $env:PATH += ";$PathToAdd"
        }
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.updatedPath0' -Args @($PathToAdd))
    }
}

function Invoke-WingetCommand {
    <#
    .SYNOPSIS
    Executes a Winget command with cross-version compatibility handling.
    #>
    param(
        [string]$Arguments,
        [int]$TimeoutSeconds = 120
    )

    try {
        $wingetExe = Get-WinGetExecutable
        if (-not $wingetExe) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInSystem')
            return @{ ExitCode = -1 }
        }

        # Check winget version for backward compatibility
        # --disable-interactivity is supported from version 1.4+
        $versionRaw = (& $wingetExe --version 2>$null) | Out-String
        $isModern = $versionRaw -match 'v1\.[4-9]' -or $versionRaw -match 'v[2-9]'

        # Add the flag only if supported (v1.4+)
        $finalArgs = if ($isModern) { "$Arguments --disable-interactivity" } else { $Arguments }

        $procParams = @{
            FilePath     = $wingetExe
            ArgumentList = $finalArgs -split ' '
            PassThru     = $true
            NoNewWindow  = $true
        }
        $process = Start-Process @procParams
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            $process.WaitForExit()
            Write-ToolkitLog -Level 'ERROR' -Message "Winget timeout after $TimeoutSeconds seconds: $Arguments"
            return @{ ExitCode = -2; TimedOut = $true }
        }
        return @{ ExitCode = $process.ExitCode; TimedOut = $false }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetCommandError0' -Args @($($_.Exception.Message)))
        return @{ ExitCode = -1 }
    }
}

function Test-PathInEnvironment {
    <#
    .SYNOPSIS
    Checks if a path is present in the PATH variable of the specified environment.
    #>
    param (
        [string]$PathToCheck,
        [string]$Scope = 'Both'
    )

    $pathExists = $false

    if ($Scope -eq 'User' -or $Scope -eq 'Both') {
        $userEnvPath = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::User)
        if (($userEnvPath -split ';').Contains($PathToCheck)) {
            $pathExists = $true
        }
    }
    if ($Scope -eq 'System' -or $Scope -eq 'Both') {
        $systemEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)
        if (($systemEnvPath -split ';').Contains($PathToCheck)) {
            $pathExists = $true
        }
    }
    return $pathExists
}

function Set-PathPermissions {
    <#
    .SYNOPSIS
    Grants full control permissions for the Administrators group on the specified directory path.
    #>
    param (
        [string]$FolderPath
    )

    if (-not (Test-Path $FolderPath)) {
        return
    }

    try {
        $administratorsGroupSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
        $administratorsGroup = $administratorsGroupSid.Translate([System.Security.Principal.NTAccount])
        $acl = Get-Acl -Path $FolderPath -ErrorAction Stop

        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $administratorsGroup, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
        )

        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $FolderPath -AclObject $acl -ErrorAction Stop
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.updatedFolderPermissions0' -Args @($FolderPath))
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.unableToSetPermissions0' -Args @($($_.Exception.Message)))
    }
}



function Install-PowerShellCore {
    <#
    .SYNOPSIS
    Verifies and installs PowerShell 7 with direct download fallback.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.verificaPowershell7')

    $ps7Path64 = "$env:SystemDrive\Program Files\PowerShell\7"
    $ps7Path32 = "$env:SystemDrive\Program Files (x86)\PowerShell\7"

    if ((Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7AlreadyInstalled')
        return $true
    }

    # 1. Attempt via Winget (Priority)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.attemptingToInstallPowershell7ViaWinget')
        $iwcParams = @{
            Arguments = "install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements --silent"
        }
        $result = Invoke-WingetCommand @iwcParams

        if ($result.ExitCode -eq 0) {
            Start-Sleep 3
            if ((Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Get-Command pwsh -ErrorAction SilentlyContinue)) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7InstallatoViaWinget')
                return $true
            }
        }
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstallationFailedOrFailedExitcode0FallbackToDirectDownload' -Args @($($result.ExitCode)))
    }

    # 2. Fallback: direct MSI download from GitHub
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.recuperoUltimaReleasePowershell')
        $release = Invoke-RestMethod -Uri $script:AppConfig.URLs.PowerShellRelease -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -like "*win-x64.msi" } | Select-Object -First 1

        if (-not $asset) {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.powershell7AssetsWinX64MsiNotFound')
            return $false
        }

        $tempDir = $script:AppConfig.Paths.Temp
        if (-not (Test-Path $tempDir)) {
            $niParams = @{
                Path     = $tempDir
                ItemType = 'Directory'
                Force    = $true
            }
            $null = New-Item @niParams *>$null
        }
        $installerPath = Join-Path $tempDir $asset.name

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadInstaller')
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -UseBasicParsing

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingPowershell7InProgress')

        $procParams = @{
            FilePath     = "msiexec.exe"
            ArgumentList = @(
                "/i", "`"$installerPath`"",
                "/norestart",
                "/passive",
                "ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1",
                "ENABLE_PSREMOTING=1",
                "REGISTER_MANIFEST=1"
            )
            Wait         = $true
            PassThru     = $true
        }

        $process = Start-Process @procParams
        $null = Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

        Start-Sleep 3

        if ((Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Get-Command pwsh -ErrorAction SilentlyContinue) -or $process.ExitCode -eq 0) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7InstalledSuccessfully')
            return $true
        }
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.installationFailedCode02' -Args @($($process.ExitCode)))
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.powershellInstallationError0' -Args @($($_.Exception.Message)))
        return $false
    }
}

function Install-WindowsTerminalApp {
    <#
    .SYNOPSIS
    Verifies and installs Windows Terminal with multiple fallback methods.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.windowsTerminalConfiguration')

    if (Get-Command "wt.exe" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalIsAlreadyInstalled')
        return $true
    }

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.windowsTerminalInstallationInProgress')
    try {
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.attemptingToInstallWindowsTerminalViaWinget')
            $iwcParams = @{
                Arguments = "install --id 9N0DX20HK701 --source winget --accept-source-agreements --accept-package-agreements --silent"
            }
            $result = Invoke-WingetCommand @iwcParams
            Start-Sleep 3
            if ($result.ExitCode -eq 0 -and (Get-Command "wt.exe" -ErrorAction SilentlyContinue)) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalInstalledViaWinget')
                return $true
            }
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstallationForWindowsTerminalFailed')
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstallationForWindowsTerminalFailed0' -Args @($($_.Exception.Message)))
    }

    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.retrieveUrlLatestReleaseOfWindowsTerminal')
        $latestRel = Invoke-RestMethod -Uri $script:AppConfig.URLs.TerminalRelease -UseBasicParsing
        $asset = $latestRel.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1

        if (-not $asset) {
            throw (Get-SourceTextLoc 'uiText.windowsTerminalAssetMsixbundleNotFound')
        }
        $downloadUrl = $asset.browser_download_url

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.iTryNativeAppxInstallationFromDownloadedBundle')
        $tempFile = Join-Path $env:TEMP "WinTerminal.msixbundle"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing

        if (Start-AppxSilentProcess -AppxPath $tempFile -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.WindowsTerminal') {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalAppxInstallationSuccessful')
        }
        else {
            throw (Get-SourceTextLoc 'uiText.windowsTerminalAppxInstallationFailed')
        }
        $null = Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.standardWindowsTerminalInstallationFailed0FallbackToTheMicrosoftStore' -Args @($($_.Exception.Message)))
    }

    if (-not (Get-Command "wt.exe" -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.fallbackAperturaMicrosoftStorePerWindowsTerminal')
        Start-Process "ms-windows-store://pdp/?ProductId=9N0DX20HK701"
        Start-Sleep 5
        return $false
    }
    Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.unableToInstallWindowsTerminalViaAnyAutomaticMethod')
    return $false
}

function Install-NerdFontsLocal {
    <#
    .SYNOPSIS
    Verifies and installs JetBrainsMono Nerd Font via Winget.
    #>
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.checkForJetbrainsmonoNerdFont')

        # Quick check if the font is already registered in the system
        $fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $installed = Get-ItemProperty -Path $fontRegistryPath -ErrorAction SilentlyContinue |
        Get-Member -MemberType NoteProperty |
        Where-Object Name -like "*JetBrainsMono*"

        if ($installed) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.jetbrainsmonoNerdFontAlreadyInstalled')
            return $true
        }

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.fontInstallationViaWingetQuickMethod')

        # Use existing helper function for logical consistency
        $result = Invoke-WingetCommand -Arguments "install --id DEVCOM.JetBrainsMonoNerdFont --source winget --accept-source-agreements --accept-package-agreements --silent"

        if ($result.ExitCode -ne 0) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetReturnedCode0TheFontMayRequireATerminalRestart' -Args @($($result.ExitCode)))
            return $false
        }
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.nerdFontsInstalledSuccessfully')
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.noteFontsViaWingetRequireRestartingTerminalOrExplorerToBeVisible')
        return $true
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.errorInstallingFont0' -Args @($($_.Exception.Message)))
        return $false
    }
}

function Get-ProfileDirLocal {
    <#
    .SYNOPSIS
    Returns the correct PowerShell profile folder path for the current edition.
    #>
    if ($PSVersionTable.PSEdition -eq "Core") {
        return [Environment]::GetFolderPath("MyDocuments") + "\PowerShell"
    }
    return [Environment]::GetFolderPath("MyDocuments") + "\WindowsPowerShell"
}

function Install-PspEnvironment {
    <#
    .SYNOPSIS
    Configures the PowerShell environment with tools, themes and custom profile.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingPowershellEnvironmentSetupPsp')

    # ============================================================================
    # PSP SETUP EXECUTION
    # ============================================================================

    # 1. Tool Installation via Winget
    $tools = @(
        @{ Id = "JanDeDobbeleer.OhMyPosh"; Name = "Oh My Posh" },
        @{ Id = "ajeetdsouza.zoxide"; Name = "zoxide" },
        @{ Id = "aristocratos.btop4win"; Name = "btop" },
        @{ Id = "Fastfetch-cli.Fastfetch"; Name = "fastfetch" }
    )

    foreach ($tool in $tools) {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.check0' -Args @($($tool.Name)))
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Invoke-WingetCommand -Arguments "install -e --id $($tool.Id) --source winget --accept-source-agreements --accept-package-agreements --silent" *>$null
        }
    }

    # 2. Oh My Posh Theme Installation
    # Always in the PowerShell 7 folder (the profile is specific to PS7 and Windows Terminal)
    $ps7ProfileDir = [Environment]::GetFolderPath('MyDocuments') + '\PowerShell'
    $themesFolder = Join-Path $ps7ProfileDir 'Themes'
    if (-not (Test-Path $themesFolder)) {
        New-Item -Path $themesFolder -ItemType Directory -Force *>$null
    }

    $themePath = Join-Path $themesFolder 'atomic.omp.json'
    if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.OhMyPoshTheme -OutFile $themePath) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.temaOhMyPoshScaricato')
    }

    # 3. Font Installation
    Install-NerdFontsLocal *>$null

    # 4. Profile Configuration (always in the PowerShell 7 folder)
    if (-not (Test-Path $ps7ProfileDir)) {
        New-Item -Path $ps7ProfileDir -ItemType Directory -Force *>$null
    }
    $targetProfile = Join-Path $ps7ProfileDir 'Microsoft.PowerShell_profile.ps1'
    try {
        if (Test-Path $targetProfile) {
            Move-Item -Path $targetProfile -Destination "$targetProfile.bak" -Force -ErrorAction SilentlyContinue
        }
        if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.PowerShellProfile -OutFile $targetProfile) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7ProfileConfigured')
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.profileConfigurationError0' -Args @($($_.Exception.Message)))
    }

    # 5. Windows Terminal Settings Configuration (stable and preview)
    try {
        $wtPackages = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Directory `
            -Filter 'Microsoft.WindowsTerminal*' -ErrorAction SilentlyContinue
        foreach ($wtPkg in $wtPackages) {
            $localStatePath = Join-Path $wtPkg.FullName 'LocalState'
            if (Test-Path $localStatePath) {
                $settingsPath = Join-Path $localStatePath 'settings.json'
                if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.WindowsTerminalSettings -OutFile $settingsPath) {
                    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalSettingsUpdated0' -Args @($($wtPkg.Name)))
                }
            }
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.terminalSettingsUpdateError0' -Args @($($_.Exception.Message)))
    }
}

function New-ToolkitDesktopShortcut {
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.desktopShortcutCreation')

    try {
        $desktop = $script:AppConfig.Paths.Desktop
        $shortcut = Join-Path $desktop "Win Toolkit.lnk"
        $iconDir = $script:AppConfig.Paths.WinToolkitDir
        $icon = Join-Path $iconDir "WinToolkit.ico"

        if (-not (Test-Path $iconDir)) {
            $niParams = @{
                Path     = $iconDir
                ItemType = 'Directory'
                Force    = $true
            }
            $null = New-Item @niParams *>$null
        }

        if (-not (Test-Path $icon)) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadIcona')
            Invoke-DownloadFile -Uri $script:AppConfig.URLs.ToolkitIcon -OutFile $icon
        }

        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcut)
        $link.TargetPath = $script:AppConfig.Paths.wtExe
        $link.Arguments = 'pwsh -ExecutionPolicy Bypass -Command "irm ' + $script:AppConfig.URLs.WebInstaller + ' | iex"'
        $link.WorkingDirectory = $script:AppConfig.Paths.wtDir
        $link.IconLocation = $icon
        $link.Description = "Win Toolkit - Master Windows with Ease"
        $link.Save()

        # Enable run as administrator
        $bytes = [IO.File]::ReadAllBytes($shortcut)
        $bytes[21] = $bytes[21] -bor 32
        [IO.File]::WriteAllBytes($shortcut, $bytes)

        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.shortcutCreatedSuccessfully')
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.shortcutCreationError0' -Args @($($_.Exception.Message)))
    }
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

function Test-SystemReadiness {
    <#
    .SYNOPSIS
    Performs pre-flight checks on the system environment.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.performingSystemIntegrityChecks')

    # 1. Check Windows Defender. A failed status query is not proof that
    # Defender is disabled: fail safe and let the caller stop explicitly.
    $defenderEnabled = $false
    $defenderCheckSucceeded = $false
    try {
        $status = Get-MpComputerStatus -ErrorAction Stop
        $defenderEnabled = [bool]$status.RealTimeProtectionEnabled
        $defenderCheckSucceeded = $true
    }
    catch {
        Write-ToolkitLog -Level 'ERROR' -Message "Unable to read Windows Defender status: $($_.Exception.Message)"
    }

    # 2. Check Windows Update (Pending updates)
    $updatesReady = $false
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.checkingWindowsUpdateLocalScan')
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $searcher.Online = $false # Prevents network search that causes the lock
        # Search for uninstalled updates
        $result = $searcher.Search("IsInstalled=0 and IsHidden=0")
        if ($result.Updates.Count -eq 0) {
            $updatesReady = $true
        }
    }
    catch {
        $updatesReady = $true # Fallback if the update service is blocked
    }

    return @{
        Defender                = $defenderEnabled
        DefenderCheckSucceeded  = $defenderCheckSucceeded
        Updates                 = $updatesReady
        Count                   = if ($null -eq $result) { 0 } else { $result.Updates.Count }
    }
}

function Add-TemporaryDefenderExclusion {
    <#
    .SYNOPSIS
    Adds a narrow, temporary Defender exclusion for WinToolkit's download area.

    Existing exclusions are preserved and are never removed by the cleanup.
    #>
    [CmdletBinding()]
    param()

    $path = [IO.Path]::GetFullPath($script:AppConfig.Paths.Temp)
    if (-not (Test-Path -LiteralPath $path)) {
        $null = New-Item -Path $path -ItemType Directory -Force -ErrorAction Stop
    }

    try {
        $preference = Get-MpPreference -ErrorAction Stop
        $existingPaths = @($preference.ExclusionPath | ForEach-Object {
                if ($_){ [IO.Path]::GetFullPath($_).TrimEnd('\') }
            })
        $alreadyExcluded = $existingPaths | Where-Object {
            $_ -and $_.Equals($path.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)
        }

        if (-not $alreadyExcluded) {
            Add-MpPreference -ExclusionPath $path -ErrorAction Stop
            $script:TemporaryDefenderExclusionAdded = $true
            Write-ToolkitLog -Level 'INFO' -Message "Temporary Defender exclusion added: $path"
            Write-StyledMessage -Type Info -Text "Protezione Defender attiva: esclusione temporanea limitata a $path."
        }
        else {
            $script:TemporaryDefenderExclusionAdded = $false
            Write-ToolkitLog -Level 'INFO' -Message "Defender exclusion already existed: $path"
        }

        $verified = Get-MpPreference -ErrorAction Stop
        $verifiedPaths = @($verified.ExclusionPath | ForEach-Object {
                if ($_){ [IO.Path]::GetFullPath($_).TrimEnd('\') }
            })
        if (-not ($verifiedPaths | Where-Object {
                    $_ -and $_.Equals($path.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)
                })) {
            throw "Defender exclusion was not visible after adding it."
        }

        $script:TemporaryDefenderExclusionPath = $path
    }
    catch {
        throw "Unable to establish a verified temporary Defender exclusion: $($_.Exception.Message)"
    }
}

function Remove-TemporaryDefenderExclusion {
    <#
    .SYNOPSIS
    Removes only the Defender exclusion created by this process and verifies it.
    #>
    [CmdletBinding()]
    param()

    if (-not $script:TemporaryDefenderExclusionAdded -or
        [string]::IsNullOrWhiteSpace($script:TemporaryDefenderExclusionPath)) {
        return
    }

    $path = $script:TemporaryDefenderExclusionPath
    try {
        Remove-MpPreference -ExclusionPath $path -ErrorAction Stop
        $preference = Get-MpPreference -ErrorAction Stop
        $stillPresent = @($preference.ExclusionPath) | Where-Object {
            $_ -and ([IO.Path]::GetFullPath($_).TrimEnd('\')).Equals(
                $path.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)
        }
        if ($stillPresent) {
            throw "Defender exclusion is still present after removal."
        }
        Write-ToolkitLog -Level 'INFO' -Message "Temporary Defender exclusion removed and verified: $path"
    }
    catch {
        Write-ToolkitLog -Level 'ERROR' -Message "Unable to verify Defender exclusion removal for '$path': $($_.Exception.Message)"
        Write-StyledMessage -Type Error -Text "Impossibile verificare il ripristino dell'esclusione temporanea Defender: $($_.Exception.Message)"
    }
    finally {
        $script:TemporaryDefenderExclusionAdded = $false
        $script:TemporaryDefenderExclusionPath = $null
    }
}

function Invoke-WinToolkitSetup {
    <#
    .SYNOPSIS
    Main function that orchestrates the entire WinToolkit installation and configuration process.
    #>
    [CmdletBinding()]
    param()

    try {
        $Host.UI.RawUI.WindowTitle = "Toolkit Starter by MagnetarMan"

        # Initialize Logging
        Start-ToolkitLog "WinToolkitStarter"

        # Build restart arguments
        $argList = ($PSBoundParameters.GetEnumerator() | ForEach-Object {
                if ($_.Value -is [switch] -and $_.Value) { "-$($_.Key)" }
                elseif ($_.Value -is [array]) { "-$($_.Key) $($_.Value -join ',')" }
                elseif ($_.Value) { "-$($_.Key) '$($_.Value)'" }
            } | Where-Object { $_ }) -join ' '

        $startUrl = $script:AppConfig.URLs.StartScript

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            throw 'start-core.ps1 requires PowerShell 7 or later. Run start.ps1 instead.'
        }
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'start-core.ps1 must be started by the elevated start.ps1 stub.'
        }

        Repair-SystemClock
        Reset-SchannelSettings
        Reset-HostsFile
        Repair-AppInstaller

        # --- PRE-FLIGHT CHECK ---
        while ($true) {
            Show-Header -Title $script:AppConfig.Header.Title -Version $script:AppConfig.Header.Version
            $check = Test-SystemReadiness

            # A status query failure is a hard stop; an active Defender is
            # handled with a narrow temporary exclusion below.
            if (-not $check.DefenderCheckSucceeded) {
                Write-Host "`n" + ("!" * $script:AppConfig.Layout.Width) -ForegroundColor Red
                Write-StyledMessage -Type Error -Text "Impossibile verificare in sicurezza lo stato di Windows Defender."
                Write-StyledMessage -Type Info -Text "Correggi l'accesso ai cmdlet Defender e riprova; la protezione non viene disattivata."
                Write-Host ("!" * $script:AppConfig.Layout.Width) -ForegroundColor Red

                Write-Host ("`n" + (Get-SourceTextLoc 'uiText.keyPressRetryTheChecks')) -ForegroundColor Cyan
                Write-Host (Get-SourceTextLoc 'uiText.escExitTheScript') -ForegroundColor Red

                $key = [Console]::ReadKey($true)
                if ($key.Key -eq 'Escape') { exit }
                Clear-Host
                continue
            }

            # If Defender is ok, check updates: warning only, proceeds automatically
            if (-not $check.Updates) {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.thereAre0WindowsUpdatesPendingPossibleProblemsDuringInstallation' -Args @($($check.Count)))
            }

            # All checks passed
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.environmentReadyForInstallation')
            break
        }

        Add-TemporaryDefenderExclusion

        # Suspend Windows Update services to ensure Winget stability
        Invoke-StopUpdateServices
        # --- END PRE-FLIGHT CHECK ---

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.powershell0' -Args @($($PSVersionTable.PSVersion)))
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.powershell7RecommendedForAdvancedFeatures')
        }

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingWinToolkitConfiguration')
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.carryingOutBasicChecks')

        # Update PATH before initial check to detect already installed winget
        Update-EnvironmentPath

        Repair-WingetMsStoreSource

        if (-not (Test-WingetFunctionality)) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetDoesnTRespondFastRecoveryAttemptCore')
            $coreSuccess = Install-WingetCore
            Update-EnvironmentPath

            if ($coreSuccess -and (Test-WingetFunctionality)) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetRestoredQuickly')
                Reset-WingetSources
            }
            else {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.quickRecoveryFailedAttemptAdvancedSlowerMethod')
                $null = Install-WingetPackage
                Update-EnvironmentPath

                if (-not (Test-WingetFunctionality)) {
                    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFunctionalAfterAllAttempts')
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.theScriptWillContinueButPackageInstallationMayFail')
                }
                else {
                    Reset-WingetSources
                }
            }
        }
        else {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetIsAlreadyOperational')
        }

        # Thoroughly verify that Winget works correctly.
        if (-not $(Test-WingetDeepValidation)) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.warningInstallingSubsequentPackagesViaWingetMayFail')
        }

        # Installa Git
        if (Install-GitPackage) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitIsAlreadyOperational')
        }
        else {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.attentionGitHasNotBeenInstalledOrItMayNotWorkProperly')
        }

        # Check and install PowerShell 7
        if (-not (Test-Path "$env:ProgramFiles\PowerShell\7") -and -not (Test-Path "${env:ProgramFiles(x86)}\PowerShell\7") -and -not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
            Install-PowerShellCore
        }
        else {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7AlreadyPresent')
        }


        # Installazioni core Windows Terminal
        $wtInstalled = Install-WindowsTerminalApp

        # Imposta Windows Terminal come terminale predefinito
        $isWtExecutable = [bool](Get-Command 'wt.exe' -ErrorAction SilentlyContinue)
        if ($wtInstalled -and $isWtExecutable) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.settingWindowsTerminalAsDefaultViaRegistry')
            try {
                $registryPath = $script:AppConfig.Registry.TerminalStartup
                if (-not (Test-Path $registryPath)) { $null = New-Item -Path $registryPath -Force }

                Set-ItemProperty -Path $registryPath -Name 'DelegationTerminal' -Value $script:AppConfig.WindowsTerminal.DelegationTerminalClsid -Force
                Set-ItemProperty -Path $registryPath -Name 'DelegationConsole' -Value $script:AppConfig.WindowsTerminal.DelegationConsoleClsid -Force
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalSetAsDefault')
            }
            catch {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.failedToSetDefaultTerminal0' -Args @($($_.Exception.Message)))
            }
        }

        # ALWAYS executed: PSP environment and profile installation
        Install-PspEnvironment

        New-ToolkitDesktopShortcut

        # Restore services on success
        Invoke-StartUpdateServices

        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.configurationComplete')

        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wintoolkitIsReadyOnTheDesktop')
        Start-Sleep 3
        exit
    }
    catch {
        # Restore services on error
        Invoke-StartUpdateServices

        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.criticalErrorDuringSetup0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.unhandledException01' -Args @($($_.Exception.Message), $($_.ScriptStackTrace)))
        Write-Host (Get-SourceTextLoc 'sourceText.pressAnyKeyToExit2')
        $null = [Console]::ReadKey($true)
        exit 1
    }
    finally {
        Remove-TemporaryDefenderExclusion
    }
}

Invoke-WinToolkitSetup
