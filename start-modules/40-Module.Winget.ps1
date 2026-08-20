# ============================================================================
# WINGET AND APPX
# ============================================================================

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

    # Use the command resolver as a second stable-alias lookup.
    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source -and (Test-Path -LiteralPath $command.Source)) {
        return $command.Source
    }

    return $null
}

function Register-WingetAppExecutionAlias {
    <#
    .SYNOPSIS
    Registers the stable App Installer execution alias without using a versioned path.
    #>
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop
        Write-ToolkitLog -Level 'INFO' -Message 'App Installer execution alias registered by family name.'
        return $true
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Unable to register App Installer execution alias: $($_.Exception.Message)"
        return $false
    }
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
        # Add-AppxPackage uses -DependencyPath; Add-AppxProvisionedPackage uses
        # -DependencyPackagePath. They are not interchangeable.
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
    if (`$_.Exception.Message -match '0x80073D06') {
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

function Reset-AppxPackageSilently {
    <#
    .SYNOPSIS
        Resets an AppX package without leaking the native "Deployment operation
        progress" activity to the host console. Add-AppxPackage/Reset-AppxPackage
        write that activity even when stderr is suppressed, which causes a stuck
        progress line to bleed into the main output.
    #>
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$Package
    )
    process {
        $previousProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            $Package | Reset-AppxPackage -ErrorAction SilentlyContinue 2>$null | Out-Null
        }
        finally {
            $ProgressPreference = $previousProgress
        }
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

        $result = Invoke-ExternalCommand -FilePath $wingetExe -ArgumentList (ConvertTo-ProcessArgumentList -Arguments $finalArgs) -TimeoutSeconds $TimeoutSeconds
        if ($result.TimedOut) {
            Write-ToolkitLog -Level 'ERROR' -Message "Winget timeout after $TimeoutSeconds seconds: $Arguments"
        }
        return $result
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetCommandError0' -Args @($($_.Exception.Message)))
        return @{ ExitCode = -1 }
    }
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
        # Non critical: the caller keeps working with the remaining sources.
        Write-ToolkitLog -Level 'DEBUG' -Message "msstore source repair skipped: $($_.Exception.Message)"
    }
}

function Repair-AppInstaller {
    <#
    .SYNOPSIS
    Repairs the App Installer package and re-registers its execution alias.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess('Microsoft.DesktopAppInstaller', 'Repair App Installer')) { return }

    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'App Installer already exposes winget.' }
        }
        $changed = $false
        $pkg = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue
        if ($pkg) {
            $pkg | Reset-AppxPackageSilently
            $changed = $true
        }
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            $tempFile = Join-Path $env:TEMP 'WingetInstaller.msixbundle'
            Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile $tempFile -UseBasicParsing -ErrorAction Stop
            if (-not (Start-AppxSilentProcess -AppxPath $tempFile -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.DesktopAppInstaller')) {
                throw 'App Installer package installation failed.'
            }
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            $changed = $true
        }
        if (-not (Register-WingetAppExecutionAlias)) { throw 'App Installer execution alias registration failed.' }
        return [pscustomobject]@{ Success = $true; Changed = $changed; Message = 'App Installer repaired and alias registered.' }
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "App Installer repair failed: $($_.Exception.Message)"
        return [pscustomobject]@{ Success = $false; Changed = $false; Message = $_.Exception.Message }
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
    # WinGet requires Windows 10 1809 (build 17763) or newer.
    if ($osInfo.Version.Major -eq 10 -and $build -lt 17763) {
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
    Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.checkWingetFunctionality'))

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
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.operationalWingetVersion0' -Args @($($versionOutput.Trim()))))
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

function Test-WingetAppInstaller {
    <#
    .SYNOPSIS
    Ensures the Microsoft.AppInstaller package is present and up to date.

    .DESCRIPTION
    After Winget is confirmed functional, the Microsoft.AppInstaller package
    must be present (and current) so that Winget stays fully functional and on
    the latest release/support. When the package is missing it is installed,
    and when already present it is force-updated to the latest release.
    #>
    $wingetExe = Get-WinGetExecutable
    if (-not $wingetExe) {
        return $false
    }

    Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.checkingMicrosoftAppInstallerPackage'))

    $present = [bool](Get-AppxPackage -Name 'Microsoft.AppInstaller' -ErrorAction SilentlyContinue)

    try {
        if (-not $present) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerNotFoundInstalling')
            $null = & $wingetExe install --id Microsoft.AppInstaller --source winget --accept-package-agreements --accept-source-agreements --force 2>&1
        }
        else {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerPresentForcingUpdate')
            $null = & $wingetExe upgrade --id Microsoft.AppInstaller --source winget --accept-package-agreements --accept-source-agreements --force 2>&1
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerUpdateError0' -Args @($($_.Exception.Message)))
    }

    $ok = [bool](Get-AppxPackage -Name 'Microsoft.AppInstaller' -ErrorAction SilentlyContinue)
    if ($ok) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerUpdated'))
    }
    else {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.microsoftAppInstallerInstallationFailed'))
    }
    return $ok
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

function Set-WingetPathPermissions {
    <#
    .SYNOPSIS
    Registers the App Installer alias and adds only the stable user alias path.

    .DESCRIPTION
    The versioned WindowsApps directory is intentionally never added to the
    machine PATH: it changes on every App Installer update and would silently
    go stale. The stable per-user alias directory is used instead.
    #>

    $aliasRegistered = Register-WingetAppExecutionAlias
    Add-ToEnvironmentPath -PathToAdd "%LOCALAPPDATA%\Microsoft\WindowsApps" -Scope 'User'
    if ($aliasRegistered) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.pathAndWingetPermissionsUpdated')
    }
}

function Repair-WingetDatabase {
    <#
    .SYNOPSIS
    Performs a complete Winget database and configuration restore.
    #>
    Write-StyledMessage -Type Info -Text ("🔧 " + (Get-SourceTextLoc 'uiText.startWingetDatabaseRecovery'))

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
            Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackageSilently
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
            if ($_.Exception.Message -match '0x80073D06') {
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
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.restoreCompletedButWingetMayNotWork'))
        }
        else {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetDatabaseRestoredVersion0' -Args @($testVersion)))
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorRestoringDatabase0' -Args @($($_.Exception.Message))))
        return $false
    }
}

function Test-WingetDeepValidation {
    <#
    .SYNOPSIS
    Performs an in-depth connectivity and functionality test of Winget.
    #>
    Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.deepTestExecutionOfWingetSearchForPacketsOnTheNetwork'))

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

        # Check for access violation crash (0xC0000005)
        if ($exitCode -eq $script:EXITCODE_ACCESS_VIOLATION_SIGNED -or $exitCode -eq $script:EXITCODE_ACCESS_VIOLATION) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.crashDetectedExitcode0AccessViolationAdvancedRecoveryAttempt' -Args @($exitCode)))

            # 1. Try DB restore + Appx reset first
            $null = Repair-Winget -Level FullDatabase

            Write-StyledMessage -Type Info -Text ("🔄 " + (Get-SourceTextLoc 'uiText.repeatTestAfterDatabaseRestore'))
            Start-Sleep 3
            $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
            $exitCode = $LASTEXITCODE

            # 2. If it still crashes, try complete reinstall
            if ($exitCode -eq $script:EXITCODE_ACCESS_VIOLATION_SIGNED -or $exitCode -eq $script:EXITCODE_ACCESS_VIOLATION) {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.persistentCrashStartingCompleteReinstallationOfWinget'))
                $null = Repair-Winget -Level FullReinstall

                Write-StyledMessage -Type Info -Text ("🔄 " + (Get-SourceTextLoc 'uiText.finalTestAfterReinstallation'))
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
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.deepTestPassedWingetCommunicatesCorrectlyWithRepositories'))
            return $true
        }
        # Logga i dettagli per debug
        $errorDetails = $searchResult | Out-String
        if ($errorDetails.Length -gt 200) {
            $errorDetails = $errorDetails.Substring(0, 200) + "."
        }
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.deepTestFailedExitcode0Details1' -Args @($exitCode, $errorDetails)))
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorDuringWingetDeepTest0' -Args @($($_.Exception.Message))))
        return $false
    }
}

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
    Write-StyledMessage -Type Info -Text ("🛠️ " + (Get-SourceTextLoc 'uiText.startingWingetCoreRecoveryProcedure'))

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
            $arch = switch (Get-SystemArchitecture) {
                'ARM64' { 'arm64' }
                'X86' { 'x86' }
                default { 'x64' }
            }
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
        $dependencies = @()
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

                $archPattern = switch (Get-SystemArchitecture) {
                    'ARM64' { 'arm64|neutral|ne' }
                    'X86' { 'x86|neutral|ne' }
                    default { 'x64|neutral|ne' }
                }
                $appxFiles = Get-ChildItem -Path $extractPath -Recurse -Filter "*.appx" | Where-Object { $_.Name -match $archPattern }

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
        if (-not $wingetUrl) {
            # No bundle URL means nothing was installed: never report success.
            throw (Get-SourceTextLoc 'uiText.wingetCoreInstallationFailed')
        }

        $wingetFile = Join-Path $tempDir "winget.msixbundle"
        Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetFile -UseBasicParsing

        if (Start-AppxSilentProcess -AppxPath $wingetFile -DependencyPaths $dependencies -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.DesktopAppInstaller') {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetCoreSuccessfullyInstalled')
        }
        else {
            throw (Get-SourceTextLoc 'uiText.wingetCoreInstallationFailed')
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

    Write-StyledMessage -Type Info -Text ("🚀 " + (Get-SourceTextLoc 'uiText.startWingetInstallationVerificationProcedure'))

    if (-not (Test-WingetCompatibility)) {
        return $false
    }

    # Use the advanced ForceClose function
    Invoke-ForceCloseWinget

    $oldProgress = $ProgressPreference
    try {
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
            # NuGet provider and Microsoft.WinGet.Client change the user's
            # PowerShell environment permanently: keep this visible on screen.
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetClientModuleInstalled')
            }
            catch {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.moduloWingetClient0' -Args @($($_.Exception.Message)))
            }
        }
        # Loads the Microsoft.WinGet.Client module installed above from the
        # PowerShell Gallery. This is an external, installed module, not one of
        # the start-modules source fragments: those are concatenated at build
        # time and are never imported at runtime (irm|iex distribution).
        Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue

        # Riparazione via modulo
        if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.tentativoRiparazioneWingetRepairWingetpackagemanager')
            try {
                Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerEseguito')
            }
            catch {
                if ($_.Exception.Message -match '0x80073D06') {
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
            Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackageSilently
        }
        catch {}

        # Applica permessi PATH e registrazione (basato su asheroto)
        Set-WingetPathPermissions
        Start-Sleep 2
        Update-EnvironmentPath

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetInstalledAndWorking'))
            return $true
        }
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.unableToInstallWinget'))
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

function Repair-Winget {
    <#
    .SYNOPSIS
    Central entry point for WinGet recovery operations.

    The level describes the observed failure, while implementation details
    remain behind this dispatcher.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [WingetRepairLevel]$Level
    )

    Write-ToolkitLog -Level 'INFO' -Message "Starting WinGet repair level: $Level"
    switch ($Level) {
        'SourceReset' {
            Reset-WingetSources
            return $true
        }
        'MsStoreCert' {
            Repair-WingetMsStoreSource
            return $true
        }
        'AppxReset' {
            $result = Repair-AppInstaller
            return [bool]$result.Success
        }
        'CoreInstall' {
            return [bool](Install-WingetCore)
        }
        'FullDatabase' {
            return [bool](Repair-WingetDatabase)
        }
        'FullReinstall' {
            return [bool](Install-WingetPackage -Force)
        }
        default {
            throw "Unsupported WinGet repair level: $Level"
        }
    }
}
