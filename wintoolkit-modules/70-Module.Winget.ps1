
# ==============================================================================
# SEZIONE 8 · WINGET — INSTALLAZIONE E RIPRISTINO
# Risoluzione eseguibile, installazione AppX silenziosa, validazione e reset.
# ==============================================================================

function Get-WingetExecutable {
    <#
    .SYNOPSIS
        Risolve il percorso di winget.exe privilegiando l'App Execution Alias.
    #>
    $aliasPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path $aliasPath) { return $aliasPath }

    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $wingetDir = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" `
        -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1

    if ($wingetDir) {
        $exe = Join-Path $wingetDir.FullName "winget.exe"
        if (Test-Path $exe) { return $exe }
    }
    return "winget"
}

function Start-AppxSilentProcess {
    <#
    .SYNOPSIS
        Installa un AppX tramite System.Diagnostics.Process (CreateNoWindow=true).
        Blocca le write Win32 native del deployment engine e gestisce il downgrade.
    #>
    param(
        [string]$AppxPath,
        [string]$Flags = '-ForceApplicationShutdown',
        [string[]]$DependencyPaths = @()
    )

    $pathParam = if ($Flags -match '-Register') { "" } else { "-Path '$($AppxPath -replace "'", "''")'" }
    $depString = ""
    if ($DependencyPaths.Count -gt 0) {
        $depString = "-DependencyPackagePath " + (($DependencyPaths | ForEach-Object { "'$($_ -replace "'", "''")'" }) -join ", ")
    }

    $cmd = @"
`$ProgressPreference = 'SilentlyContinue';
`$ErrorActionPreference = 'SilentlyContinue';
try {
    Add-AppxPackage $pathParam $depString $Flags -ErrorAction Stop | Out-Null
}
catch {
    if (`$_.Exception.Message -match '0x80073D06' -or `$_.Exception.Message -match 'versione successiva') { exit 0 }
    if (`$_.Exception.Message -match '0x80073CF9' -or ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)) {
        try {
            if ('$pathParam' -eq '') { exit 1 }
            Add-AppxProvisionedPackage -Online -PackagePath '$($AppxPath -replace "'", "''")' $depString -SkipLicense -ErrorAction Stop | Out-Null
            exit 0
        }
        catch { exit 1 }
    }
    exit 1
}
exit 0
"@
    $encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -NonInteractive -EncodedCommand $encodedCmd"
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    return [System.Diagnostics.Process]::Start($psi)
}

function Wait-WingetReady {
    <#
    .SYNOPSIS
        Polls for up to 5 minutes to verify that Winget is ready and the database is unlocked.
    #>
    param([int]$MaxWaitSeconds = 300, [int]$PollIntervalSeconds = 5)

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.wingetIntegrityValidationInProgressTimeout0S' -Args @($MaxWaitSeconds))
    $wingetExe = Get-WingetExecutable
    $maxRetries = [Math]::Floor($MaxWaitSeconds / $PollIntervalSeconds)

    for ($i = 1; $i -le $maxRetries; $i++) {
        try {
            $versionProc = Start-Process -FilePath $wingetExe -ArgumentList '--version' `
                -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
            $dbProc = Start-Process -FilePath $wingetExe `
                -ArgumentList 'list', 'NonExistentApp_WinToolkitCheck', '--accept-source-agreements' `
                -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
            if ($versionProc.ExitCode -eq 0 -and $dbProc.ExitCode -eq 0) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetReadyAndDatabaseUnlockedAttempt01' -Args @($i, $maxRetries))
                return $true
            }
        }
        catch {}
        $remaining = $MaxWaitSeconds - ($i * $PollIntervalSeconds)
        Write-StyledMessage -Type Progress -Text (Get-SourceTextLoc 'uiText.wingetNotYetReadyAttempt012SRemainWait' -Args @($i, $maxRetries, $remaining))
        Start-Sleep -Seconds $PollIntervalSeconds
    }
    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetDidNotRespondWithin0SecondsIContinueAnyway' -Args @($MaxWaitSeconds))
    return $false
}

function Reset-Winget {
    <#
    .SYNOPSIS
        Verifies, restores and tests the Winget installation.
    .DESCRIPTION
        Integrated two-phase procedure for complete Winget repair.

        Phase 1 — Core Restore (fast):
          VC++ Redistributable, AppX dependencies from official repo, main MSIXBundle.

        Phase 2 — Advanced Restore (if Phase 1 is insufficient):
          Microsoft.WinGet.Client, Repair-WinGetPackageManager, database restore,
          permissions and PATH reset.

        Includes deep post-installation validation with ACCESS_VIOLATION detection.
    #>
    param([switch]$Force)

    $ProgressPreference = 'SilentlyContinue'
    $OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

    # ── Helper privati ────────────────────────────────────────────────────────

    function Test-VCRedistInstalled {
        $64BitOS = [System.Environment]::Is64BitOperatingSystem
        $registryPath = [string]::Format(
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\{0}\Microsoft\VisualStudio\14.0\VC\Runtimes\X{1}',
            $(if ($64BitOS) { 'WOW6432Node' } else { '' }),
            $(if ($64BitOS) { '64' } else { '86' })
        )
        $major = (Get-ItemProperty -Path $registryPath -Name 'Major' -ErrorAction SilentlyContinue).Major
        $dllPath = [string]::Format('{0}\system32\concrt140.dll', $env:windir)
        return (Test-Path $registryPath) -and ($major -ge 14) -and (Test-Path $dllPath)
    }

    function Register-AppxManifest {
        try {
            $manifest = (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue).InstallLocation
            if ($manifest) {
                $manifestXml = Join-Path $manifest 'AppxManifest.xml'
                if (Test-Path $manifestXml) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.manifestReRegistrationAppxmanifestXmlPreventsLeaks')
                    Start-AppxSilentProcess -AppxPath $manifestXml -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown' | Out-Null
                }
            }
        }
        catch {}
    }

    function Get-LatestAssetUrl {
        param([string]$Match)
        try {
            $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing -ErrorAction Stop
            $asset = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
            if ($asset) { return $asset.browser_download_url }
            return $null
        }
        catch { return $null }
    }

    function Test-WingetCompatibility {
        $os = [Environment]::OSVersion.Version
        if ($os.Major -lt 10 -or ($os.Major -eq 10 -and $os.Build -lt 16299)) {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.systemNotSupportedByWingetWindows101709Required')
            return $false
        }
        return $true
    }

    function Test-WingetFunctionality {
        Update-EnvironmentPath
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInPath')
            return $false
        }
        try {
            $versionOutput = (& (Get-WingetExecutable) --version 2>$null) | Out-String
            if ($LASTEXITCODE -eq 0 -and $versionOutput -match 'v\d+\.\d+') {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.operationalWingetVersion02' -Args @($($versionOutput.Trim())))
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

    function Test-PathInEnvironment {
        param([string]$PathToCheck, [string]$Scope = 'Both')
        $found = $false
        if ($Scope -in 'User', 'Both') { if (($env:PATH -split ';').Contains($PathToCheck)) { $found = $true } }
        if ($Scope -in 'System', 'Both') {
            $syspath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
            if (($syspath -split ';').Contains($PathToCheck)) { $found = $true }
        }
        return $found
    }

    function Add-ToEnvironmentPath {
        param([string]$PathToAdd, [ValidateSet('User', 'System')][string]$Scope)
        if (Test-PathInEnvironment -PathToCheck $PathToAdd -Scope $Scope) { return }
        if ($Scope -eq 'System') {
            $cur = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
            [Environment]::SetEnvironmentVariable('PATH', "$cur;$PathToAdd", 'Machine')
        }
        else {
            $cur = [Environment]::GetEnvironmentVariable('PATH', 'User')
            [Environment]::SetEnvironmentVariable('PATH', "$cur;$PathToAdd", 'User')
        }
        if (-not ($env:PATH -split ';').Contains($PathToAdd)) { $env:PATH += ";$PathToAdd" }
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.updatedPath0' -Args @($PathToAdd))
    }

    function Set-PathPermissions {
        param([string]$FolderPath)
        if (-not (Test-Path $FolderPath)) { return }
        try {
            $sid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
            $group = $sid.Translate([System.Security.Principal.NTAccount])
            $acl = Get-Acl -Path $FolderPath -ErrorAction Stop
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $group, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $acl.SetAccessRule($rule)
            Set-Acl -Path $FolderPath -AclObject $acl -ErrorAction Stop
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.updatedFolderPermissions0' -Args @($FolderPath))
        }
        catch { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.unableToSetPermissionsOn01' -Args @($FolderPath, $($_.Exception.Message))) }
    }

    function Set-WingetPathPermissions {
        $wingetFolderPath = $null
        try {
            $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
            $wingetDir = Get-ChildItem "$env:ProgramFiles\WindowsApps" `
                -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
            if ($wingetDir) { $wingetFolderPath = $wingetDir.FullName }
        }
        catch {}
        if ($wingetFolderPath) {
            Set-PathPermissions -FolderPath $wingetFolderPath
            Add-ToEnvironmentPath -PathToAdd $wingetFolderPath -Scope 'System'
            Add-ToEnvironmentPath -PathToAdd '%LOCALAPPDATA%\Microsoft\WindowsApps' -Scope 'User'
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.pathAndWingetPermissionsUpdated')
        }
    }

    function _Repair-WingetDatabase {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.ripristinoDatabaseWinget')
        try {
            Stop-ToolkitProcesses -ProcessNames $AppConfig.WingetProcesses

            $cachePath = "$env:LOCALAPPDATA\WinGet"
            if (Test-Path $cachePath) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.puliziaCacheWinget')
                Get-ChildItem -Path $cachePath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '\\lock\\|\\tmp\\' } |
                ForEach-Object { try { Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue } catch {} }
            }

            @("$env:LOCALAPPDATA\WinGet\Data\USERTEMPLATE.json",
                "$env:LOCALAPPDATA\WinGet\Data\DEFAULTUSER.json") | ForEach-Object {
                if (Test-Path $_ -PathType Leaf) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetStatusFile0' -Args @($_))
                    Remove-Item $_ -Force -ErrorAction SilentlyContinue
                }
            }

            try { $null = & (Get-WingetExecutable) source reset --force 2>&1 } catch {}

            if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
                Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
            }

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
            catch {}

            try {
                if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.esecuzioneRepairWingetpackagemanager')
                    Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                }
            }
            catch {
                if ($_.Exception.Message -match '0x80073D06' -or $_.Exception.Message -match 'versione successiva') {
                    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerCompletedHigherVersionAlreadyPresent')
                }
                else { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerFallito0' -Args @($($_.Exception.Message))) }
            }

            Set-WingetPathPermissions
            Update-EnvironmentPath
            return $true
        }
        catch {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorDuringDatabaseRestore0' -Args @($($_.Exception.Message)))
            return $false
        }
    }

    function _Install-WingetAdvanced {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.advancedInstallationViaMicrosoftWingetClientModule')
        try {
            if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
                if ($PSVersionTable.PSVersion.Major -lt 7) {
                    try { Install-PackageProvider -Name 'NuGet' -Force -ForceBootstrap -ErrorAction SilentlyContinue *>$null }
                    catch { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.nugetProviderNotInstallable') }
                }
            }

            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingMicrosoftWingetClientModule')
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
                Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetClientModuleInstalled')
            }
            catch { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.failedToInstallWingetClientModule0' -Args @($($_.Exception.Message))) }

            if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.tentativoRepairWingetpackagemanager')
                try {
                    Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerCompletato')
                }
                catch {
                    if ($_.Exception.Message -match '0x80073D06' -or $_.Exception.Message -match 'versione successiva') {
                        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerIgnoredHigherVersionAlreadyPresent')
                    }
                    else { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerFallito0' -Args @($($_.Exception.Message))) }
                }
                Start-Sleep 3
            }

            Update-EnvironmentPath
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.fallbackDownloadMsixbundleDirectFromMicrosoft')
                $tempDir = $AppConfig.Paths.Temp
                if (-not (Test-Path $tempDir)) { $null = New-Item -Path $tempDir -ItemType Directory -Force }
                $tempInstaller = Join-Path $tempDir "WingetInstaller.msixbundle"
                Invoke-WebRequest -Uri $AppConfig.URLs.WingetInstaller -OutFile $tempInstaller -UseBasicParsing -ErrorAction Stop
                Start-AppxSilentProcess -AppxPath $tempInstaller -Flags '-ForceApplicationShutdown'
                Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
                Start-Sleep 3
            }

            try { Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null } catch {}
            Set-WingetPathPermissions
            Update-EnvironmentPath
            return $true
        }
        catch {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.wingetAdvancedInstallationError0' -Args @($($_.Exception.Message)))
            return $false
        }
    }

    function Test-WingetDeepValidation {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.wingetDeepValidationConnectivityDatabaseIntegrity')
        try {
            $wingetExe = Get-WingetExecutable
            $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.crashAccessViolationExitcode0RipristinoDatabase' -Args @($exitCode))
                $null = _Repair-WingetDatabase
                Start-Sleep 3
                $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
                $exitCode = $LASTEXITCODE
                if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.persistentCrashAfterDatabaseRestore')
                    return $false
                }
            }

            if ($exitCode -eq 0) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.deepValidationPassedWingetCommunicatesWithRepositories')
                return $true
            }
            $details = ($searchResult | Out-String).Trim()
            if ($details.Length -gt 200) { $details = $details.Substring(0, 200) + "..." }
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.deepValidationFailedExitcode0Details1' -Args @($exitCode, $details))
            return $false
        }
        catch {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.deepValidationError0' -Args @($($_.Exception.Message)))
            return $false
        }
    }

    # ── Orchestrazione principale ─────────────────────────────────────────────

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingWingetAdvancedRepair')
    if (-not (Test-WingetCompatibility)) { return $false }
    if (-not $Force -and (Test-WingetFunctionality)) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetAlreadyOperationalNoRepairsNecessary')
        return $true
    }

    Stop-ToolkitProcesses -ProcessNames $AppConfig.WingetProcesses

    try {
        # Fase 1: Ripristino Core
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.phase1CoreRecoveryVcAppxDependenciesMsixbundle')

        if (-not (Test-VCRedistInstalled) -or $Force) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingVisualCRedistributable')
            $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
            $vcUrl = "https://aka.ms/vs/17/release/vc_redist.$arch.exe"
            $vcFile = Join-Path $AppConfig.Paths.Temp "vc_redist.exe"
            if (-not (Test-Path $AppConfig.Paths.Temp)) { $null = New-Item $AppConfig.Paths.Temp -ItemType Directory -Force }
            Invoke-WebRequest -Uri $vcUrl -OutFile $vcFile -UseBasicParsing
            Start-Process -FilePath $vcFile -ArgumentList "/install", "/quiet", "/norestart" -Wait
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.vcRedistInstalled')
        }

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadWingetDependenciesFromTheOfficialRepository')
        $depUrl = Get-LatestAssetUrl -Match 'DesktopAppInstaller_Dependencies.zip'
        if ($depUrl) {
            $depZip = Join-Path $AppConfig.Paths.Temp "dependencies.zip"
            $depDir = Join-Path $AppConfig.Paths.Temp "deps"
            Invoke-WebRequest -Uri $depUrl -OutFile $depZip -UseBasicParsing
            Expand-Archive -Path $depZip -DestinationPath $depDir -Force
            $archPattern = if ([Environment]::Is64BitOperatingSystem) { "x64|ne" } else { "x86|ne" }
            $script:WingetDependencies = @()
            Get-ChildItem $depDir -Recurse -Filter "*.appx" |
            Where-Object { $_.Name -match $archPattern } |
            ForEach-Object { Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.dependencyFound0' -Args @($($_.Name))); $script:WingetDependencies += $_.FullName }
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.loadedDependencies')
        }

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingWingetMsixbundleWithDependencies')
        $bundleUrl = Get-LatestAssetUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        if ($bundleUrl) {
            $bundleFile = Join-Path $AppConfig.Paths.Temp "winget.msixbundle"
            Invoke-WebRequest -Uri $bundleUrl -OutFile $bundleFile -UseBasicParsing
            $deps = if ($script:WingetDependencies) { $script:WingetDependencies } else { @() }
            Start-AppxSilentProcess -AppxPath $bundleFile -DependencyPaths $deps -Flags '-ForceApplicationShutdown'
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetCoreInstalled')
        }

        Register-AppxManifest
        Update-EnvironmentPath

        if (Test-WingetFunctionality) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.phase1CompletedOperationalWinget')
        }
        else {
            # Fase 2: Ripristino Avanzato
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.phase1InsufficientStartingPhase2AdvancedRecovery')
            $null = _Install-WingetAdvanced
            $null = _Repair-WingetDatabase
            Update-EnvironmentPath
        }

        Start-Sleep -Seconds 3
        try {
            Start-Process -FilePath (Get-WingetExecutable) -ArgumentList 'source', 'reset', '--force' `
                -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        }
        catch {}

        $deepOk = Test-WingetDeepValidation
        if ($deepOk) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetSuccessfullyRestoredAndTested')
            return $true
        }
        else {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstalledDeepValidationWithAnomaliesPossibleNetworkOrDbProblems')
            return $true
        }
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.criticalErrorInReset0' -Args @($($_.Exception.Message)))
        return $false
    }
    finally {
        if (Test-Path $AppConfig.Paths.Temp) { Remove-Item $AppConfig.Paths.Temp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
