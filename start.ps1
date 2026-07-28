<#
.SYNOPSIS
    Script di inizio che installa e configura WinToolkit.
.DESCRIPTION
    Verifica, installa e configura alcuni software, per poi creare una scorciatoia di avvio di WinToolkit sul desktop.
.NOTES
    Compatibile con PowerShell 5.1+
#>

[CmdletBinding()]
param(
    [string]$Language = 'en-US',
    [string]$OfflineModeDir
)

# --- CONFIGURAZIONE GLOBALE ---

$script:AppConfig = @{
    MsgStyles       = @{
        Success = @{ Icon = '✅'; Color = 'Green' }
        Warning = @{ Icon = '⚠️'; Color = 'Yellow' }
        Error   = @{ Icon = '❌'; Color = 'Red' }
        Info    = @{ Icon = '💎'; Color = 'Cyan' }
    }
    # ============================================================================
    # HEADER CONFIGURATION - Modifica qui per aggiornare titolo e versione
    # ============================================================================
    Header          = @{
        Title   = "Toolkit Starter By MagnetarMan"
        Version = "Version 2.5.4 (Build 28)"
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
# FUNZIONI DI UTILITÀ & SUPPORTO WINGET
# ============================================================================



function Test-VCRedistInstalled {
    <#
    .SYNOPSIS
    Checks if Visual C++ Redistributable is installed and verifies the major version is 14.
    #>

    $64BitOS = [System.Environment]::Is64BitOperatingSystem
    $checksPassed = 0
    
    # Controlliamo sempre la versione 32bit (esiste sempre su tutti i sistemi)
    $registryPath32 = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86'
    $dllPath32 = "$env:windir\syswow64\concrt140.dll"
    
    if ((Test-Path -Path $registryPath32) -and 
        ((Get-ItemProperty -Path $registryPath32 -Name 'Major' -ErrorAction SilentlyContinue).Major -eq 14) -and
        [System.IO.File]::Exists($dllPath32)) {
        $checksPassed++
    }

    # Se il sistema è 64bit controlliamo ANCHE la versione 64bit
    if ($64BitOS) {
        $registryPath64 = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'
        $dllPath64 = "$env:windir\system32\concrt140.dll"

        if ((Test-Path -Path $registryPath64) -and 
            ((Get-ItemProperty -Path $registryPath64 -Name 'Major' -ErrorAction SilentlyContinue).Major -eq 14) -and
            [System.IO.File]::Exists($dllPath64)) {
            $checksPassed++
        }
    }

    # Su sistema 32bit: basta che sia presente la versione 32bit
    # Su sistema 64bit: devono essere presenti ENTRAMBE le versioni 32 + 64 bit
    $requiredChecks = if ($64BitOS) { 2 } else { 1 }
    
    return $checksPassed -eq $requiredChecks
}

function Get-WinGetFolder {
    <#
    .SYNOPSIS
    Trova la cartella di installazione ufficiale di Winget piu' recente.
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
    Ottiene il percorso valido di winget.exe, con fallback diretto.
    #>
    # Prova prima il percorso standard alias
    $aliasPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    if (Test-Path $aliasPath) {
        return $aliasPath
    }

    # Fallback: percorso diretto nella cartella di installazione
    $wingetFolder = Get-WinGetFolder
    if ($wingetFolder) {
        $exePath = Join-Path $wingetFolder "winget.exe"
        if (Test-Path $exePath) {
            return $exePath
        }
    }

    return $null
}

function Test-WingetCompatibility {
    <#
    .SYNOPSIS
    Verifica la compatibilità del sistema operativo con Winget.
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
    Verifica che Winget sia presente nel PATH e funzioni correttamente.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.checkWingetFunctionality')

    # Aggiorna il PATH per rilevare installazioni recenti
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

    # Lista mirata dei processi che bloccano effettivamente l'installazione Appx
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
    Sospende temporaneamente i servizi di Windows Update e correlati per evitare conflitti con Winget.
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
    Ripristina i servizi di Windows Update e correlati.
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
                # Ignora avvertimenti di avvio in corso e servizi delayed
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
    Esegue un ripristino completo del database e delle configurazioni di Winget.
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

        # 3. Rimuovi file di stato danneggiati (solo JSON)
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

        # 4. Reset delle sorgenti Winget
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetWingetSources')
        try {
            $null = & winget.exe source reset --force 2>&1
        }
        catch {}    # Ignora errori durante il reset

        # 5. Reset completo del pacchetto AppInstaller (Cruciale per ACCESS_VIOLATION)
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetPackageMicrosoftDesktopappinstaller')
        if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
            Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
        }

        # 6. Re-registrazione manifest AppInstaller
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

        # 7. Riprova con il modulo WinGet se disponibile
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

        # 9. Verifica che winget risponda
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
    Esegue un test approfondito di connettività e funzionalità di Winget.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.deepTestExecutionOfWingetSearchForPacketsOnTheNetwork')

    try {
        # Testa connettività ai repository, integrità del DB locale e parser Winget
        # Esegue ricerca diretta per ottenere ExitCode corretto
        $searchResult = & winget search "Git.Git" --accept-source-agreements 2>&1
        $exitCode = $LASTEXITCODE

        # Check for access violation crash (0xC0000005 = -1073741819 or 3221225781)
        if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.crashDetectedExitcode0AccessViolationAdvancedRecoveryAttempt' -Args @($exitCode))

            # 1. Prova prima il ripristino DB + Reset Appx
            $null = Repair-WingetDatabase

            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.repeatTestAfterDatabaseRestore')
            Start-Sleep 3
            $searchResult = & winget search "Git.Git" --accept-source-agreements 2>&1
            $exitCode = $LASTEXITCODE

            # 2. Se crasha ancora, prova la reinstallazione completa
            if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.persistentCrashStartingCompleteReinstallationOfWinget')
                $null = Install-WingetPackage -Force

                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.finalTestAfterReinstallation')
                Start-Sleep 3
                $searchResult = & winget search "Git.Git" --accept-source-agreements 2>&1
                $exitCode = $LASTEXITCODE
            }
        }

        if ($exitCode -eq 0) {
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
    Esegue l'installazione minima e dipendenze core di Winget.
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

                # Estrazione e installazione mirata per architettura
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
            if (Start-AppxSilentProcess -AppxPath $wingetFile -DependencyPaths $deps -Flags '-ForceApplicationShutdown') {
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
    Procedura completa di installazione e ripristino di Winget.
    #>
    param([switch]$Force)

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startWingetInstallationVerificationProcedure')

    if (-not (Test-WingetCompatibility)) {
        return $false
    }

    # Usa la funzione avanzata ForceClose
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

        # Fallback finale: installazione via MSIXBundle
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
            if (Start-AppxSilentProcess -AppxPath $tempInstaller -Flags '-ForceApplicationShutdown') {
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
    Verifica e installa Git con fallback a download diretto.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.verifyGitInstallation')

    Update-EnvironmentPath

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitAlreadyInstalled')
        return $true
    }

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.gitInstallation')

    # 1. Tentativo via winget (Prioritario)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $result = Invoke-WingetCommand -Arguments "install Git.Git --accept-source-agreements --accept-package-agreements --silent"

        if ($result.ExitCode -eq 0) {
            Start-Sleep 3
            Update-EnvironmentPath

            if (Get-Command git -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitInstalledViaWinget')
                return $true
            }
        }
    }

    # 2. Fallback: download diretto da GitHub
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
    Formatta un testo centrato rispetto alla larghezza specificata.
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
    Visualizza l'header grafico dello script con titolo e versione.
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
    $candidates = @(
        (Join-Path $PSScriptRoot 'languages'),
        (Join-Path (Split-Path $PSScriptRoot -Parent) 'languages'),
        (Join-Path (Get-Location) 'languages')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $candidates[0]
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
        [object[]]$Args = @()
    )

    $value = $null
    if ($script:SourceTextLanguageData -and $script:SourceTextLanguageData.ContainsKey($Key)) {
        $value = [string]$script:SourceTextLanguageData[$Key]
    }
    elseif ($script:SourceTextDefaultLanguageData -and $script:SourceTextDefaultLanguageData.ContainsKey($Key)) {
        $value = [string]$script:SourceTextDefaultLanguageData[$Key]
    }
    else {
        $value = $Key
    }
    if ($Args.Count -gt 0) { return [string]::Format($value, $Args) }
    return $value
}

Initialize-SourceTextLocalization -LanguageCode $Language

function Write-StyledMessage {
    <#
    .SYNOPSIS
    Scrive un messaggio formattato con timestamp, icona e colore, e lo salva nel log.
    #>
    param(
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Progress')]
        [string]$Type,
        [string]$Text
    )
    # FIX: Windows 11 Indentation Issue
    if ([Environment]::OSVersion.Version.Build -ge 22000) { $Text = "`r$Text" }

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
        Inizializza il file di log strutturato per un tool specifico.
    #>
    param([string]$ToolName)

    # Pulizia residui transcript
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
    # Rimuovi tutti i caratteri ANSI/colori prima di salvare su file
    $clean = $clean -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
    $line = "[$ts] [$Level] $clean"
    try { Add-Content -Path $Global:CurrentLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}

function Start-AppxSilentProcess {
    <#
    .SYNOPSIS
        Installa AppX in background sopprimendo le barre di progresso native.
    #>
    param(
        [string]$AppxPath,
        [string]$Flags = '-ForceApplicationShutdown',
        [string[]]$DependencyPaths = @()
    )

    $errFile = Join-Path $env:TEMP "AppxError_$([guid]::NewGuid()).txt"
    $depString = ""
    if ($DependencyPaths.Count -gt 0) {
        $depString = "-DependencyPackagePath " + (($DependencyPaths | ForEach-Object { "'$($_ -replace "'", "''")'" }) -join ", ")
    }

    $cmd = @"
`$ProgressPreference = 'SilentlyContinue';
`$ErrorActionPreference = 'SilentlyContinue';
try {
    Add-AppxPackage -Path '$($AppxPath -replace "'", "''")' $depString $Flags -ErrorAction Stop | Out-Null
}
catch {
    if (`$_.Exception.Message -match '0x80073D06' -or `$_.Exception.Message -match 'versione successiva') {
        exit 0
    }
    if (`$_.Exception.Message -match '0x80073CF9' -or ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)) {
        try {
            Add-AppxProvisionedPackage -Online -PackagePath '$($AppxPath -replace "'", "''")' $depString -SkipLicense -ErrorAction Stop | Out-Null
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
    $proc.WaitForExit()

    if ($proc.ExitCode -ne 0) {
        if (Test-Path $errFile) {
            $errMsg = Get-Content $errFile -Raw
            Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.appxInstallFailed01' -Args @($AppxPath, $errMsg))
            Remove-Item $errFile -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
    return $true
}



function Update-EnvironmentPath {
    <#
    .SYNOPSIS
    Ricarica le variabili PATH di sistema e utente nella sessione corrente.
    #>
    # Ricarica PATH da Machine e User per rilevare installazioni avvenute nel processo corrente
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'

    # Aggiorna la sessione PowerShell corrente
    $env:Path = $newPath
    # Forza il refresh a livello di processo per i componenti .NET avviati successivamente
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
}

function Invoke-DownloadFile {
    <#
    .SYNOPSIS
    Helper DRY per download file con gestione errori centralizzata.
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
    Aggiunge un percorso alla variabile d'ambiente PATH nello scope specificato.
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
    Esegue un comando Winget con gestione della compatibilità tra versioni.
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

        # Verifichiamo la versione di winget per retrocompatibilità
        # --disable-interactivity è supportato dalla versione 1.4+
        $versionRaw = (& $wingetExe --version 2>$null) | Out-String
        $isModern = $versionRaw -match 'v1\.[4-9]' -or $versionRaw -match 'v[2-9]'

        # Aggiungiamo il flag solo se supportato (v1.4+)
        $finalArgs = if ($isModern) { "$Arguments --disable-interactivity" } else { $Arguments }

        $procParams = @{
            FilePath     = $wingetExe
            ArgumentList = $finalArgs -split ' '
            Wait         = $true
            PassThru     = $true
            NoNewWindow  = $true
        }
        $process = Start-Process @procParams
        return @{ ExitCode = $process.ExitCode }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetCommandError0' -Args @($($_.Exception.Message)))
        return @{ ExitCode = -1 }
    }
}

function Test-PathInEnvironment {
    <#
    .SYNOPSIS
    Verifica se un percorso è presente nella variabile PATH dell'ambiente specificato.
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
    Verifica e installa PowerShell 7 con fallback a download diretto.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.verificaPowershell7')

    $ps7Path64 = "$env:SystemDrive\Program Files\PowerShell\7"
    $ps7Path32 = "$env:SystemDrive\Program Files (x86)\PowerShell\7"

    if ((Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7AlreadyInstalled')
        return $true
    }

    # 1. Tentativo via Winget (Prioritario)
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

    # 2. Fallback: download diretto MSI da GitHub
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
    Verifica e installa Windows Terminal con diversi metodi di fallback.
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
                Arguments = "install --id 9N0DX20HK701 --source msstore --accept-source-agreements --accept-package-agreements --silent"
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

        if (Start-AppxSilentProcess -AppxPath $tempFile -Flags '-ForceApplicationShutdown') {
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
    Verifica e installa JetBrainsMono Nerd Font tramite Winget.
    #>
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.checkForJetbrainsmonoNerdFont')

        # Controllo rapido se il font è già registrato nel sistema
        $fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $installed = Get-ItemProperty -Path $fontRegistryPath -ErrorAction SilentlyContinue |
        Get-Member -MemberType NoteProperty |
        Where-Object Name -like "*JetBrainsMono*"

        if ($installed) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.jetbrainsmonoNerdFontAlreadyInstalled')
            return $true
        }

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.fontInstallationViaWingetQuickMethod')

        # Utilizzo della funzione helper esistente per coerenza logica
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
    Restituisce il percorso della cartella profilo PowerShell corretta per l'edizione corrente.
    #>
    if ($PSVersionTable.PSEdition -eq "Core") {
        return [Environment]::GetFolderPath("MyDocuments") + "\PowerShell"
    }
    return [Environment]::GetFolderPath("MyDocuments") + "\WindowsPowerShell"
}

function Install-PspEnvironment {
    <#
    .SYNOPSIS
    Configura l'ambiente PowerShell con tool, temi e profilo personalizzato.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingPowershellEnvironmentSetupPsp')

    # ============================================================================
    # ESECUZIONE SETUP PSP
    # ============================================================================

    # 1. Installazione Tool via Winget
    $tools = @(
        @{ Id = "JanDeDobbeleer.OhMyPosh"; Name = "Oh My Posh" },
        @{ Id = "ajeetdsouza.zoxide"; Name = "zoxide" },
        @{ Id = "aristocratos.btop4win"; Name = "btop" },
        @{ Id = "Fastfetch-cli.Fastfetch"; Name = "fastfetch" }
    )

    foreach ($tool in $tools) {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.check0' -Args @($($tool.Name)))
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Invoke-WingetCommand -Arguments "install -e --id $($tool.Id) --accept-source-agreements --accept-package-agreements --silent" *>$null
        }
    }

    # 2. Installazione Tema Oh My Posh
    # Sempre nella cartella PowerShell 7 (il profilo è specifico per PS7 e Windows Terminal)
    $ps7ProfileDir = [Environment]::GetFolderPath('MyDocuments') + '\PowerShell'
    $themesFolder = Join-Path $ps7ProfileDir 'Themes'
    if (-not (Test-Path $themesFolder)) {
        New-Item -Path $themesFolder -ItemType Directory -Force *>$null
    }

    $themePath = Join-Path $themesFolder 'atomic.omp.json'
    if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.OhMyPoshTheme -OutFile $themePath) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.temaOhMyPoshScaricato')
    }

    # 3. Installazione Font
    Install-NerdFontsLocal *>$null

    # 4. Configurazione Profilo (sempre nella cartella PowerShell 7)
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

    # 5. Configurazione Settings Windows Terminal (stable e preview)
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
        $link.Description = "Win Toolkit - SOPRAVVIVI A Windows"
        $link.Save()

        # Abilita esecuzione come amministratore
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
# FUNZIONE PRINCIPALE
# ============================================================================

function Test-SystemReadiness {
    <#
    .SYNOPSIS
    Esegue i controlli pre-flight sull'ambiente di sistema.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.performingSystemIntegrityChecks')

    # 1. Verifica Windows Defender
    $defenderReady = $false
    try {
        $status = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($null -eq $status -or $status.RealTimeProtectionEnabled -eq $false) {
            $defenderReady = $true
        }
    }
    catch {
        $defenderReady = $true # Se non può leggere lo stato, assumiamo sia spento o rimosso
    }

    # 2. Verifica Windows Update (Aggiornamenti pendenti)
    $updatesReady = $false
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.checkingWindowsUpdateLocalScan')
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $searcher.Online = $false # Impedisce la ricerca in rete che causa il blocco
        # Cerca aggiornamenti non installati
        $result = $searcher.Search("IsInstalled=0 and IsHidden=0")
        if ($result.Updates.Count -eq 0) {
            $updatesReady = $true
        }
    }
    catch {
        $updatesReady = $true # Fallback se il servizio update è bloccato
    }

    return @{
        Defender = $defenderReady
        Updates  = $updatesReady
        Count    = if ($null -eq $result) { 0 } else { $result.Updates.Count }
    }
}

function Invoke-WinToolkitSetup {
    <#
    .SYNOPSIS
    Funzione principale che orchestra l'intero processo di installazione e configurazione di WinToolkit.
    #>
    [CmdletBinding()]
    param()

    try {
        $Host.UI.RawUI.WindowTitle = "Toolkit Starter by MagnetarMan"

        # Inizializza Logging
        Start-ToolkitLog "WinToolkitStarter"

        # Costruzione argomenti per riavvio
        $argList = ($PSBoundParameters.GetEnumerator() | ForEach-Object {
                if ($_.Value -is [switch] -and $_.Value) { "-$($_.Key)" }
                elseif ($_.Value -is [array]) { "-$($_.Key) $($_.Value -join ',')" }
                elseif ($_.Value) { "-$($_.Key) '$($_.Value)'" }
            } | Where-Object { $_ }) -join ' '

        $startUrl = $script:AppConfig.URLs.StartScript

        # Blocco di riavvio standard
        $scriptBlockForRelaunch = if ($PSCommandPath) {
            "& '$PSCommandPath' $argList"
        }
        else {
            "`$s = irm '$startUrl'; & ([scriptblock]::Create(`$s)) $argList"
        }

        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.rebootWithAdministratorPrivileges')
            $procParams = @{
                FilePath     = 'powershell'
                ArgumentList = @( '-ExecutionPolicy', 'Bypass', '-NoProfile', '-Command', "`"$scriptBlockForRelaunch`"" )
                Verb         = 'RunAs'
            }
            Start-Process @procParams
            exit
        }

        # --- PRE-FLIGHT CHECK ---
        while ($true) {
            Show-Header -Title $script:AppConfig.Header.Title -Version $script:AppConfig.Header.Version
            $check = Test-SystemReadiness

            # Windows Defender SEMPRE obbligatorio
            if (-not $check.Defender) {
                Write-Host "`n" + ("!" * $script:AppConfig.Layout.Width) -ForegroundColor Red
                Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.requiredWindowsDefenderIsOn')
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.disableRealTimeProtectionToAvoidCrashes')
                Write-Host ("!" * $script:AppConfig.Layout.Width) -ForegroundColor Red

                Write-Host ("`n" + (Get-SourceTextLoc 'uiText.keyPressRetryTheChecks')) -ForegroundColor Cyan
                Write-Host (Get-SourceTextLoc 'uiText.escExitTheScript') -ForegroundColor Red

                $key = [Console]::ReadKey($true)
                if ($key.Key -eq 'Escape') { exit }
                Clear-Host
                continue
            }

            # Se Defender è ok, controlla aggiornamenti: solo avviso, prosegue automaticamente
            if (-not $check.Updates) {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.thereAre0WindowsUpdatesPendingPossibleProblemsDuringInstallation' -Args @($($check.Count)))
            }

            # Tutti i controlli superati
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.environmentReadyForInstallation')
            break
        }

        # Sospensione servizi Windows Update per garantire stabilità a Winget
        Invoke-StopUpdateServices
        # --- FINE PRE-FLIGHT CHECK ---

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.powershell0' -Args @($($PSVersionTable.PSVersion)))
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.powershell7RecommendedForAdvancedFeatures')
        }

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingWinToolkitConfiguration')
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.carryingOutBasicChecks')

        # Aggiorna PATH prima del check iniziale per rilevare winget già installato
        Update-EnvironmentPath

        if (-not (Test-WingetFunctionality)) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetDoesnTRespondFastRecoveryAttemptCore')
            $coreSuccess = Install-WingetCore
            Update-EnvironmentPath

            if ($coreSuccess -and (Test-WingetFunctionality)) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetRestoredQuickly')
            }
            else {
                Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.quickRecoveryFailedAttemptAdvancedSlowerMethod')
                $null = Install-WingetPackage
                Update-EnvironmentPath

                if (-not (Test-WingetFunctionality)) {
                    Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFunctionalAfterAllAttempts')
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.theScriptWillContinueButPackageInstallationMayFail')
                }
            }
        }
        else {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetIsAlreadyOperational')
        }

        # Verifica in modo approfondito che Winget funzioni correttamente.
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

        # Controllo e installazione PowerShell 7
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

        # SEMPRE eseguito: Installazione ambiente PSP e profilo
        Install-PspEnvironment
        
        New-ToolkitDesktopShortcut

        # Ripristino servizi in caso di successo
        Invoke-StartUpdateServices

        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.configurationComplete')

        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wintoolkitIsReadyOnTheDesktop')
        Start-Sleep 3
        exit
    }
    catch {
        # Ripristino servizi in caso di errore
        Invoke-StartUpdateServices
        
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.criticalErrorDuringSetup0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.unhandledException01' -Args @($($_.Exception.Message), $($_.ScriptStackTrace)))
        Write-Host (Get-SourceTextLoc 'sourceText.pressAnyKeyToExit2')
        $null = [Console]::ReadKey($true)
        exit 1
    }
}

Invoke-WinToolkitSetup
