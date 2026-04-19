<#
.SYNOPSIS
    Script di inizio che installa e configura WinToolkit.
.DESCRIPTION
    Verifica, installa e configura alcuni software, per poi creare una scorciatoia di avvio di WinToolkit sul desktop.
.NOTES
    Compatibile con PowerShell 5.1+
#>

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
        Version = "Version 2.5.4 (Build 22)"
    }
    URLs            = @{
        StartScript             = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/start.ps1"
        WingetMSIX              = "https://aka.ms/getwinget"
        GitRelease              = "https://api.github.com/repos/git-for-windows/git/releases/latest"
        PowerShellRelease       = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        OhMyPoshTheme           = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
        PowerShellProfile       = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/Microsoft.PowerShell_profile.ps1"
        WindowsTerminalSettings = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/settings.json"
        ToolkitIcon             = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/img/WinToolkit.ico"
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
    $64BitProcess = [System.Environment]::Is64BitProcess

    # Check registry
    $registryPath = [string]::Format(
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\{0}\Microsoft\VisualStudio\14.0\VC\Runtimes\X{1}',
        $(if ($64BitOS -and $64BitProcess) { 'WOW6432Node' } else { '' }),
        $(if ($64BitOS) { '64' } else { '86' })
    )

    $registryExists = Test-Path -Path $registryPath

    # Check major version
    $majorVersion = if ($registryExists) {
        (Get-ItemProperty -Path $registryPath -Name 'Major' -ErrorAction SilentlyContinue).Major
    }
    else { 0 }

    # Check DLL exists
    $dllPath = [string]::Format('{0}\system32\concrt140.dll', $env:windir)
    $dllExists = [System.IO.File]::Exists($dllPath)

    return $registryExists -and $majorVersion -eq 14 -and $dllExists
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
        Write-StyledMessage -Type Error -Text "Winget non supportato su Windows $($osInfo.Version.Major)."
        return $false
    }
    if ($osInfo.Version.Major -eq 10 -and $build -lt 16299) {
        Write-StyledMessage -Type Error -Text "Windows 10 build $build non supporta Winget."
        return $false
    }
    return $true
}

function Test-WingetFunctionality {
    <#
    .SYNOPSIS
    Verifica che Winget sia presente nel PATH e funzioni correttamente.
    #>
    Write-StyledMessage -Type Info -Text "🔍 Verifica funzionalità Winget."

    # Aggiorna il PATH per rilevare installazioni recenti
    Update-EnvironmentPath

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Warning -Text "Winget non trovato nel PATH."
        return $false
    }

    try {
        # Usa --version: locale, immediato, non richiede connessione internet
        $versionOutput = (& winget --version 2>$null) | Out-String
        if ($LASTEXITCODE -eq 0 -and $versionOutput -match 'v\d+\.\d+') {
            Write-StyledMessage -Type Success -Text "✅ Winget operativo (versione: $($versionOutput.Trim()))."
            return $true
        }
        Write-StyledMessage -Type Warning -Text "Winget presente ma non risponde correttamente (ExitCode: $LASTEXITCODE)."
        return $false
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Errore durante test Winget: $($_.Exception.Message)."
        return $false
    }
}

function Invoke-ForceCloseWinget {
    <#
    .SYNOPSIS
    Closes the processes that actually block Appx installation.
    Safe approach that avoids killing system-critical processes.
    #>
    Write-StyledMessage -Type Info -Text "Chiusura processi interferenti."

    # Lista mirata dei processi che bloccano effettivamente l'installazione Appx
    $interferingProcesses = $script:AppConfig.WingetProcesses

    foreach ($procName in $interferingProcesses) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -ne $PID } |  # Don't kill ourselves
        Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep 2
    Write-StyledMessage -Type Success -Text "Processi interferenti chiusi."
}

function Invoke-StopUpdateServices {
    <#
    .SYNOPSIS
    Sospende temporaneamente i servizi di Windows Update e correlati per evitare conflitti con Winget.
    #>
    Write-StyledMessage -Type Info -Text "Sospensione temporanea servizi Windows Update per evitare conflitti."
    $services = $script:AppConfig.UpdateServices
    foreach ($svc in $services) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text "Arresto servizio: $svc..."
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        }
    }
    Write-StyledMessage -Type Success -Text "Servizi di aggiornamento sospesi correttamente."
}

function Invoke-StartUpdateServices {
    <#
    .SYNOPSIS
    Ripristina i servizi di Windows Update e correlati.
    #>
    Write-StyledMessage -Type Info -Text "Ripristino servizi Windows Update."
    $services = $script:AppConfig.UpdateServices
    foreach ($svc in $services) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text "Avvio servizio: $svc..."
            try {
                Start-Service -Name $svc -ErrorAction Stop
            }
            catch {
                # Ignora avvertimenti di avvio in corso e servizi delayed
                if ($_.Exception.Message -notmatch 'in corso') {
                    Write-ToolkitLog -Level 'Warning' -Message "Avvio servizio $svc: $($_.Exception.Message)"
                }
            }
        }
    }
    Write-StyledMessage -Type Success -Text "Servizi di aggiornamento ripristinati."
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

        Write-StyledMessage -Type Success -Text "PATH e permessi winget aggiornati."
    }
}

function Repair-WingetDatabase {
    <#
    .SYNOPSIS
    Esegue un ripristino completo del database e delle configurazioni di Winget.
    #>
    Write-StyledMessage -Type Info -Text "🔧 Avvio ripristino database Winget."

    try {
        # 1. Ferma i processi interferenti
        Invoke-ForceCloseWinget

        # 2. Pulizia cache locale di Winget
        $wingetCachePath = "$env:LOCALAPPDATA\WinGet"
        if (Test-Path $wingetCachePath) {
            Write-StyledMessage -Type Info -Text "Pulizia cache Winget."
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
                Write-StyledMessage -Type Info -Text "Reset file stato: $file."
                Remove-Item $file -Force -ErrorAction SilentlyContinue
            }
        }

        # 4. Reset delle sorgenti Winget
        Write-StyledMessage -Type Info -Text "Reset sorgenti Winget."
        try {
            $null = & winget.exe source reset --force 2>&1
        }
        catch {}    # Ignora errori durante il reset

        # 5. Reset completo del pacchetto AppInstaller (Cruciale per ACCESS_VIOLATION)
        Write-StyledMessage -Type Info -Text "Reset pacchetto Microsoft.DesktopAppInstaller."
        if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
            Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
        }

        # 6. Re-registrazione manifest AppInstaller
        try {
            $manifest = (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue).InstallLocation
            if ($manifest) {
                $manifestXml = Join-Path $manifest 'AppxManifest.xml'
                if (Test-Path $manifestXml) {
                    Write-StyledMessage -Type Info -Text "Re-registrazione manifest: AppxManifest.xml."
                    Start-AppxSilentProcess -AppxPath $manifestXml -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown' | Out-Null
                }
            }
        }
        catch { }

        # 7. Riprova con il modulo WinGet se disponibile
        try {
            if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Info -Text "Esecuzione Repair-WinGetPackageManager."
                Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
            }
        }
        catch {
            if ($_.Exception.Message -match '0x80073D06' -or $_.Exception.Message -match 'versione successiva') {
                Write-StyledMessage -Type Info -Text "Repair-WinGetPackageManager completato (versione superiore già presente)."
            }
            else {
                Write-StyledMessage -Type Warning -Text "Modulo Riparazione fallito: $($_.Exception.Message)."
            }
        }

        # 8. Applica permessi e refresh PATH
        Set-WingetPathPermissions
        Update-EnvironmentPath

        # 9. Verifica che winget risponda
        Start-Sleep 2
        $testVersion = & winget --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-StyledMessage -Type Warning -Text "⚠️ Ripristino completato ma winget potrebbe non funzionare."
        }
        else {
            Write-StyledMessage -Type Success -Text "✅ Database Winget ripristinato (versione: $testVersion)."
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text "❌ Errore durante ripristino database: $($_.Exception.Message)."
        return $false
    }
}

function Test-WingetDeepValidation {
    <#
    .SYNOPSIS
    Esegue un test approfondito di connettività e funzionalità di Winget.
    #>
    Write-StyledMessage -Type Info -Text "🔍 Esecuzione test profondo di Winget (ricerca pacchetti in rete)."

    try {
        # Testa connettività ai repository, integrità del DB locale e parser Winget
        # Esegue ricerca diretta per ottenere ExitCode corretto
        $searchResult = & winget search "Git.Git" --accept-source-agreements 2>&1
        $exitCode = $LASTEXITCODE

        # Check for access violation crash (0xC0000005 = -1073741819 or 3221225781)
        if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
            Write-StyledMessage -Type Warning -Text "⚠️ Crash rilevato (ExitCode: $exitCode = ACCESS_VIOLATION). Tentativo ripristino avanzato."

            # 1. Prova prima il ripristino DB + Reset Appx
            $null = Repair-WingetDatabase

            Write-StyledMessage -Type Info -Text "🔄 Ripetizione test dopo ripristino database."
            Start-Sleep 3
            $searchResult = & winget search "Git.Git" --accept-source-agreements 2>&1
            $exitCode = $LASTEXITCODE

            # 2. Se crasha ancora, prova la reinstallazione completa
            if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                Write-StyledMessage -Type Warning -Text "⚠️ Crash persistente. Avvio reinstallazione completa Winget."
                $null = Install-WingetPackage -Force

                Write-StyledMessage -Type Info -Text "🔄 Test finale dopo reinstallazione."
                Start-Sleep 3
                $searchResult = & winget search "Git.Git" --accept-source-agreements 2>&1
                $exitCode = $LASTEXITCODE
            }
        }

        if ($exitCode -eq 0) {
            Write-StyledMessage -Type Success -Text "✅ Test profondo superato: Winget comunica correttamente con i repository."
            return $true
        }
        # Logga i dettagli per debug
        $errorDetails = $searchResult | Out-String
        if ($errorDetails.Length -gt 200) {
            $errorDetails = $errorDetails.Substring(0, 200) + "."
        }
        Write-StyledMessage -Type Warning -Text "⚠️ Test profondo fallito: ExitCode=$exitCode. Dettagli: $errorDetails."
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text "❌ Errore durante il test profondo di Winget: $($_.Exception.Message)."
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
        throw "Asset '$Match' non trovato."
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Errore recupero URL asset: $($_.Exception.Message)."
        return $null
    }
}

function Install-WingetCore {
    <#
    .SYNOPSIS
    Esegue l'installazione minima e dipendenze core di Winget.
    #>
    Write-StyledMessage -Type Info -Text "🛠️ Avvio procedura di ripristino Winget (Core)."

    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    $tempDir = "$env:TEMP\WinToolkitWinget"
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force *>$null
    }

    try {
        # 1. Visual C++ Redistributable (usando test avanzato)
        if (-not (Test-VCRedistInstalled)) {
            Write-StyledMessage -Type Info -Text "Installazione Visual C++ Redistributable."
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
            Write-StyledMessage -Type Success -Text "Visual C++ Redistributable installato."
        }
        else {
            Write-StyledMessage -Type Success -Text "Visual C++ Redistributable già presente."
        }

        # 2. Dipendenze (UI.Xaml, VCLibs) — Estrazione dal pacchetto ufficiale (Metodo Sicuro)
        Write-StyledMessage -Type Info -Text "Download dipendenze Winget dal repository ufficiale."
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
                    Write-StyledMessage -Type Info -Text "Trovata dipendenza: $($file.Name)."
                    $dependencies += $file.FullName
                }
            }
            catch {
                Write-StyledMessage -Type Warning -Text "Impossibile estrarre o installare le dipendenze dallo zip ufficiale. Errore: $($_.Exception.Message)."
            }
        }

        # 3. Winget Bundle
        Write-StyledMessage -Type Info -Text "Download e installazione Winget Bundle (con dipendenze)."
        $wingetUrl = Get-WingetDownloadUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        if ($wingetUrl) {
            $wingetFile = Join-Path $tempDir "winget.msixbundle"
            Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetFile -UseBasicParsing

            $deps = if ($dependencies) { $dependencies } else { @() }
            if (Start-AppxSilentProcess -AppxPath $wingetFile -DependencyPaths $deps -Flags '-ForceApplicationShutdown') {
                Write-StyledMessage -Type Success -Text "Winget Core installato con successo."
            }
            else {
                throw "Installazione Winget Core fallita."
            }
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore durante il ripristino Winget: $($_.Exception.Message)."
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

    Write-StyledMessage -Type Info -Text "🚀 Avvio procedura installazione/verifica Winget."

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
            Write-StyledMessage -Type Info -Text "Installazione modulo Microsoft.WinGet.Client."
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
                Write-StyledMessage -Type Success -Text "Modulo WinGet Client installato."
            }
            catch {
                Write-StyledMessage -Type Warning -Text "Modulo WinGet Client: $($_.Exception.Message)."
            }
        }
        Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue

        # Riparazione via modulo
        if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text "Tentativo riparazione Winget (Repair-WinGetPackageManager)."
            try {
                Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                Write-StyledMessage -Type Success -Text "Repair-WinGetPackageManager eseguito."
            }
            catch {
                if ($_.Exception.Message -match '0x80073D06' -or $_.Exception.Message -match 'versione successiva') {
                    Write-StyledMessage -Type Info -Text "Repair-WinGetPackageManager ignorato (versione superiore già presente)."
                }
                else {
                    Write-StyledMessage -Type Warning -Text "Repair-WinGetPackageManager fallito: $($_.Exception.Message)."
                }
            }
            Start-Sleep 3
        }

        # Fallback finale: installazione via MSIXBundle
        if (-not (Get-Command winget -ErrorAction SilentlyContinue) -or $Force) {
            Write-StyledMessage -Type Info -Text "Download MSIXBundle da Microsoft."

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
                Write-StyledMessage -Type Success -Text "Installazione Winget MSIX Bundle riuscita."
            }
            else {
                Write-StyledMessage -Type Warning -Text "Installazione Winget MSIX Bundle fallita."
            }
            Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
            Start-Sleep 3
        }

        # Reset App Installer
        Write-StyledMessage -Type Info -Text "Reset App Installer."
        try {
            Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
        }
        catch {}

        # Applica permessi PATH e registrazione (basato su asheroto)
        Set-WingetPathPermissions
        Start-Sleep 2
        Update-EnvironmentPath

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Success -Text "✅ Winget installato e funzionante."
            return $true
        }
        Write-StyledMessage -Type Error -Text "❌ Impossibile installare Winget."
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore critico: $($_.Exception.Message)."
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
    Write-StyledMessage -Type Info -Text "Verifica installazione Git..."

    Update-EnvironmentPath

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Success -Text "Git già installato."
        return $true
    }

    Write-StyledMessage -Type Info -Text "Installazione Git..."

    # 1. Tentativo via winget (Prioritario)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $result = Invoke-WingetCommand -Arguments "install Git.Git --accept-source-agreements --accept-package-agreements --silent"

        if ($result.ExitCode -eq 0) {
            Start-Sleep 3
            Update-EnvironmentPath

            if (Get-Command git -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Success -Text "Git installato via winget."
                return $true
            }
        }
    }

    # 2. Fallback: download diretto da GitHub
    try {
        Write-StyledMessage -Type Info -Text "Fallback: Download Git da GitHub..."
        $release = Invoke-RestMethod -Uri $script:AppConfig.URLs.GitRelease -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -like "*64-bit.exe" } | Select-Object -First 1

        if (-not $asset) {
            Write-StyledMessage -Type Error -Text "Asset Git 64-bit non trovato."
            return $false
        }

        $tempDir = $script:AppConfig.Paths.Temp
        if (-not (Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force | Out-Null }
        $installerPath = Join-Path $tempDir $asset.name

        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -UseBasicParsing

        Write-StyledMessage -Type Info -Text "Esecuzione installer Git..."

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
            Write-StyledMessage -Type Success -Text "Git installato con successo."
            return $true
        }

        Write-StyledMessage -Type Error -Text "Installazione fallita. Codice: $($process.ExitCode)"
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore installazione Git: $($_.Exception.Message)"
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

function Write-StyledMessage {
    <#
    .SYNOPSIS
    Scrive un messaggio formattato con timestamp, icona e colore, e lo salva nel log.
    #>
    param(
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
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
Username       : $([Environment]::UserDomainName + '\' + [Environment]::UserName)
Machine        : $($env:COMPUTERNAME) ($($os.Caption) $($os.Version))
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
            Write-ToolkitLog -Level 'ERROR' -Message "AppX install failed ($AppxPath): $errMsg"
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
            Write-StyledMessage -Type Warning -Text "Errore download: $($_.Exception.Message)"
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
        Write-StyledMessage -Type Success -Text "PATH aggiornato: $PathToAdd."
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
            Write-StyledMessage -Type Warning -Text "Winget non trovato nel sistema."
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
        Write-StyledMessage -Type Warning -Text "Errore comando Winget: $($_.Exception.Message)."
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
        Write-StyledMessage -Type Info -Text "Permessi cartella aggiornati: $FolderPath."
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Impossibile impostare permessi: $($_.Exception.Message)."
    }
}



function Install-PowerShellCore {
    <#
    .SYNOPSIS
    Verifica e installa PowerShell 7 con fallback a download diretto.
    #>
    Write-StyledMessage -Type Info -Text "Verifica PowerShell 7."

    $ps7Path64 = "$env:SystemDrive\Program Files\PowerShell\7"
    $ps7Path32 = "$env:SystemDrive\Program Files (x86)\PowerShell\7"

    if ((Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Success -Text "PowerShell 7 già installato."
        return $true
    }

    # 1. Tentativo via Winget (Prioritario)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Info -Text "Tentativo installazione PowerShell 7 via Winget."
        $iwcParams = @{
            Arguments = "install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements --silent"
        }
        $result = Invoke-WingetCommand @iwcParams

        if ($result.ExitCode -eq 0) {
            Start-Sleep 3
            if ((Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Get-Command pwsh -ErrorAction SilentlyContinue)) {
                Write-StyledMessage -Type Success -Text "PowerShell 7 installato via Winget."
                return $true
            }
        }
        Write-StyledMessage -Type Warning -Text "Installazione Winget fallita o non riuscita (ExitCode: $($result.ExitCode)). Fallback al download diretto."
    }

    # 2. Fallback: download diretto MSI da GitHub
    try {
        Write-StyledMessage -Type Info -Text "Recupero ultima release PowerShell."
        $release = Invoke-RestMethod -Uri $script:AppConfig.URLs.PowerShellRelease -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -like "*win-x64.msi" } | Select-Object -First 1

        if (-not $asset) {
            Write-StyledMessage -Type Error -Text "Asset PowerShell 7 win-x64.msi non trovato."
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

        Write-StyledMessage -Type Info -Text "Download installer."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -UseBasicParsing

        Write-StyledMessage -Type Info -Text "Installazione PowerShell 7 in corso."

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
            Write-StyledMessage -Type Success -Text "PowerShell 7 installato con successo."
            return $true
        }
        Write-StyledMessage -Type Error -Text "Installazione fallita. Codice: $($process.ExitCode)."
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore installazione PowerShell: $($_.Exception.Message)."
        return $false
    }
}

function Install-WindowsTerminalApp {
    <#
    .SYNOPSIS
    Verifica e installa Windows Terminal con diversi metodi di fallback.
    #>
    Write-StyledMessage -Type Info -Text "Configurazione Windows Terminal."

    if (Get-Command "wt.exe" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Success -Text "Windows Terminal è già installato."
        return $true
    }

    Write-StyledMessage -Type Info -Text "Installazione Windows Terminal in corso."
    try {
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            Write-StyledMessage -Type Info -Text "Tentativo installazione Windows Terminal via winget."
            $iwcParams = @{
                Arguments = "install --id 9N0DX20HK701 --source msstore --accept-source-agreements --accept-package-agreements --silent"
            }
            $result = Invoke-WingetCommand @iwcParams
            Start-Sleep 3
            if ($result.ExitCode -eq 0 -and (Get-Command "wt.exe" -ErrorAction SilentlyContinue)) {
                Write-StyledMessage -Type Success -Text "Windows Terminal installato via winget."
                return $true
            }
            Write-StyledMessage -Type Warning -Text "Installazione Winget per Windows Terminal non riuscita."
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Installazione Winget per Windows Terminal fallita: $($_.Exception.Message)."
    }

    try {
        Write-StyledMessage -Type Info -Text "Recupero URL ultima release di Windows Terminal."
        $latestRel = Invoke-RestMethod -Uri $script:AppConfig.URLs.TerminalRelease -UseBasicParsing
        $asset = $latestRel.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1

        if (-not $asset) {
            throw "Asset .msixbundle di Windows Terminal non trovato."
        }
        $downloadUrl = $asset.browser_download_url

        Write-StyledMessage -Type Info -Text "Provo installazione nativa Appx da bundle scaricato."
        $tempFile = Join-Path $env:TEMP "WinTerminal.msixbundle"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing

        if (Start-AppxSilentProcess -AppxPath $tempFile -Flags '-ForceApplicationShutdown') {
            Write-StyledMessage -Type Success -Text "Installazione Appx di Windows Terminal riuscita."
        }
        else {
            throw "Installazione Appx di Windows Terminal fallita."
        }
        $null = Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Installazione Standard di Windows Terminal fallita: $($_.Exception.Message). Fallback al Microsoft Store."
    }

    if (-not (Get-Command "wt.exe" -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Info -Text "Fallback: Apertura Microsoft Store per Windows Terminal."
        Start-Process "ms-windows-store://pdp/?ProductId=9N0DX20HK701"
        Start-Sleep 5
        return $false
    }
    Write-StyledMessage -Type Error -Text "Impossibile installare Windows Terminal tramite qualsiasi metodo automatico."
    return $false
}

function Install-NerdFontsLocal {
    <#
    .SYNOPSIS
    Verifica e installa JetBrainsMono Nerd Font tramite Winget.
    #>
    try {
        Write-StyledMessage -Type Info -Text "🔍 Verifica presenza JetBrainsMono Nerd Font."

        # Controllo rapido se il font è già registrato nel sistema
        $fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $installed = Get-ItemProperty -Path $fontRegistryPath -ErrorAction SilentlyContinue |
        Get-Member -MemberType NoteProperty |
        Where-Object Name -like "*JetBrainsMono*"

        if ($installed) {
            Write-StyledMessage -Type Success -Text "✅ JetBrainsMono Nerd Font già installato."
            return $true
        }

        Write-StyledMessage -Type Info -Text "⬇️ Installazione font tramite WinGet (Metodo Rapido)."

        # Utilizzo della funzione helper esistente per coerenza logica
        $result = Invoke-WingetCommand -Arguments "install --id DEVCOM.JetBrainsMonoNerdFont --source winget --accept-source-agreements --accept-package-agreements --silent"

        if ($result.ExitCode -ne 0) {
            Write-StyledMessage -Type Warning -Text "⚠️ WinGet ha restituito codice $($result.ExitCode). Il font potrebbe richiedere un riavvio del terminale."
            return $false
        }
        Write-StyledMessage -Type Success -Text "✅ Nerd Fonts installati con successo."
        Write-StyledMessage -Type Warning -Text "💡 Nota: i font via WinGet richiedono il riavvio del Terminale (o di Explorer) per essere visibili."
        return $true
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Errore durante l'installazione font: $($_.Exception.Message)."
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
    Write-StyledMessage -Type Info -Text "Avvio configurazione ambiente PowerShell (PSP)."

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
        Write-StyledMessage -Type Info -Text "Verifica $($tool.Name)."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Invoke-WingetCommand -Arguments "install -e --id $($tool.Id) --accept-source-agreements --accept-package-agreements --silent" *>$null
        }
    }

    # 2. Installazione Tema Oh My Posh
    $profileDir = Get-ProfileDirLocal
    if ($profileDir) {
        $themesFolder = Join-Path $profileDir "Themes"
        if (-not (Test-Path $themesFolder)) {
            New-Item -Path $themesFolder -ItemType Directory -Force *>$null
        }

        $themePath = Join-Path $themesFolder "atomic.omp.json"
        if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.OhMyPoshTheme -OutFile $themePath) {
            Write-StyledMessage -Type Success -Text "Tema Oh My Posh scaricato."
        }
    }

    # 3. Installazione Font
    Install-NerdFontsLocal *>$null

    # 4. Configurazione Profilo
    if ($profileDir) {
        if (-not (Test-Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force *>$null
        }
        $targetProfile = $PROFILE
        if (-not $targetProfile) {
            $targetProfile = Join-Path $profileDir "Microsoft.PowerShell_profile.ps1"
        }
        try {
            if (Test-Path $targetProfile) {
                Move-Item -Path $targetProfile -Destination "$targetProfile.bak" -Force -ErrorAction SilentlyContinue
            }
            if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.PowerShellProfile -OutFile $targetProfile) {
                Write-StyledMessage -Type Success -Text "Profilo PowerShell configurato."
            }
        }
        catch {
            Write-StyledMessage -Type Warning -Text "Errore configurazione profilo: $($_.Exception.Message)."
        }
    }

    # 5. Configurazione Settings Windows Terminal
    try {
        $wtPath = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Directory -Filter "Microsoft.WindowsTerminal_*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($wtPath) {
            $settingsPath = Join-Path $wtPath.FullName "LocalState\settings.json"
            if (Test-Path (Join-Path $wtPath.FullName "LocalState")) {
                if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.WindowsTerminalSettings -OutFile $settingsPath) {
                    Write-StyledMessage -Type Success -Text "Settings Windows Terminal aggiornati."
                }
            }
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text "Errore aggiornamento settings terminal: $($_.Exception.Message)."
    }
}

function New-ToolkitDesktopShortcut {
    Write-StyledMessage -Type Info -Text "Creazione scorciatoia desktop."

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
            Write-StyledMessage -Type Info -Text "Download icona."
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

        Write-StyledMessage -Type Success -Text "Scorciatoia creata con successo."
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore creazione scorciatoia: $($_.Exception.Message)."
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
    Write-StyledMessage -Type Info -Text "Esecuzione controlli di integrità sistema..."

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
        Write-StyledMessage -Type Info -Text "Controllo Windows Update (Scansione locale)..."
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
    param(
        [switch]$Resume
    )

    try {
        $isResumeSetup = ($Resume.IsPresent -or $env:WINTOOLKIT_RESUME -eq '1')
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
            "iex (irm '$startUrl') $argList"
        }

        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-StyledMessage -Type Info -Text "Riavvio con privilegi amministratore."
            $procParams = @{
                FilePath     = 'powershell'
                ArgumentList = @( '-ExecutionPolicy', 'Bypass', '-NoProfile', '-Command', "`"$scriptBlockForRelaunch`"" )
                Verb         = 'RunAs'
            }
            Start-Process @procParams
            exit
        }

        # --- PRE-FLIGHT CHECK (solo prima esecuzione, non durante Resume) ---
        if (-not $isResumeSetup) {
            while ($true) {
                Show-Header -Title $script:AppConfig.Header.Title -Version $script:AppConfig.Header.Version
                $check = Test-SystemReadiness

                # Windows Defender SEMPRE obbligatorio
                if (-not $check.Defender) {
                    Write-Host "`n" + ("!" * $script:AppConfig.Layout.Width) -ForegroundColor Red
                    Write-StyledMessage -Type Error -Text "OBBLIGATORIO: Windows Defender è ATTIVO."
                    Write-StyledMessage -Type Info -Text "Disabilita la protezione in tempo reale per evitare blocchi."
                    Write-Host ("!" * $script:AppConfig.Layout.Width) -ForegroundColor Red

                    Write-Host "`n[Pressione tasto] Riprova i controlli" -ForegroundColor Cyan
                    Write-Host "[ESC] Esci dallo script" -ForegroundColor Red

                    $key = [Console]::ReadKey($true)
                    if ($key.Key -eq 'Escape') { exit }
                    Clear-Host
                    continue
                }

                # Se Defender è ok, controlla aggiornamenti: solo avviso, prosegue automaticamente
                if (-not $check.Updates) {
                    Write-StyledMessage -Type Warning -Text "⚠️ Ci sono $($check.Count) aggiornamenti Windows pendenti. Possibili problemi durante installazione."
                }

                # Tutti i controlli superati
                Write-StyledMessage -Type Success -Text "Ambiente pronto per l'installazione."
                break
            }

            # Sospensione servizi Windows Update per garantire stabilità a Winget
            Invoke-StopUpdateServices
        }
        # --- FINE PRE-FLIGHT CHECK ---

        Write-StyledMessage -Type Info -Text "PowerShell: $($PSVersionTable.PSVersion)."
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-StyledMessage -Type Warning -Text "PowerShell 7 raccomandato per funzionalità avanzate."
        }

        Write-StyledMessage -Type Info -Text "Avvio configurazione Win Toolkit."
        if (-not $isResumeSetup) {
            Write-StyledMessage -Type Info -Text "Esecuzione controlli base."

            # Aggiorna PATH prima del check iniziale per rilevare winget già installato
            Update-EnvironmentPath

            if (-not (Test-WingetFunctionality)) {
                Write-StyledMessage -Type Warning -Text "⚠️ Winget non risponde. Tentativo di ripristino veloce (Core)."
                $coreSuccess = Install-WingetCore
                Update-EnvironmentPath

                if ($coreSuccess -and (Test-WingetFunctionality)) {
                    Write-StyledMessage -Type Success -Text "✅ Winget ripristinato velocemente."
                }
                else {
                    Write-StyledMessage -Type Warning -Text "⚠️ Ripristino veloce fallito. Tentativo metodo avanzato (più lento)."
                    $null = Install-WingetPackage
                    Update-EnvironmentPath

                    if (-not (Test-WingetFunctionality)) {
                        Write-StyledMessage -Type Warning -Text "⚠️ Winget non funzionale dopo tutti i tentativi."
                        Write-StyledMessage -Type Info -Text "Lo script proseguirà, ma l'installazione di pacchetti potrebbe fallire."
                    }
                }
            }
            else {
                Write-StyledMessage -Type Success -Text "✅ Winget è già operativo."
            }

            # Verifica in modo approfondito che Winget funzioni correttamente.
            if (-not $(Test-WingetDeepValidation)) {
                Write-StyledMessage -Type Warning -Text "⚠️ Attenzione: l'installazione dei pacchetti successivi via Winget potrebbe fallire."
            }

            # Installa Git
            if (Install-GitPackage) {
                Write-StyledMessage -Type Success -Text "✅ Git è già operativo."
            }
            else {
                Write-StyledMessage -Type Warning -Text "⚠️ Attenzione: Git non è stato installato oppure potrebbe non funzionare correttamente."
            }

            # Controllo e installazione PowerShell 7
            if (-not (Test-Path "$env:ProgramFiles\PowerShell\7") -and -not (Test-Path "${env:ProgramFiles(x86)}\PowerShell\7") -and -not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
                Install-PowerShellCore
            }
            else {
                Write-StyledMessage -Type Success -Text "PowerShell 7 già presente."
            }
        }

        $pwshExe64 = "$env:SystemDrive\Program Files\PowerShell\7\pwsh.exe"
        $pwshExe32 = "$env:SystemDrive\Program Files (x86)\PowerShell\7\pwsh.exe"
        $pwshExe = if (Test-Path $pwshExe64) { $pwshExe64 } elseif (Test-Path $pwshExe32) { $pwshExe32 } else { $null }

        if ($PSVersionTable.PSVersion.Major -lt 7 -and $pwshExe) {
            Write-StyledMessage -Type Info -Text "✨ Rilevata PowerShell 7. Upgrade dell'ambiente di esecuzione."
            Start-Sleep 2
            $env:WINTOOLKIT_RESUME = "1"

            $procParams = @{
                FilePath     = $pwshExe
                ArgumentList = @("-ExecutionPolicy", "Bypass", "-NoExit", "-Command", "`"$scriptBlockForRelaunch`"")
                Verb         = "RunAs"
            }
            Start-Process @procParams
            Write-StyledMessage -Type Success -Text "Script riavviato su PowerShell 7. Chiusura sessione legacy."
            exit
        }

        # Installazioni core Windows Terminal
        $wtInstalled = Install-WindowsTerminalApp

        # Imposta Windows Terminal come terminale predefinito
        $isWtExecutable = [bool](Get-Command 'wt.exe' -ErrorAction SilentlyContinue)
        if ($wtInstalled -and $isWtExecutable) {
            Write-StyledMessage -Type Info -Text "⚙️ Impostazione Windows Terminal come predefinito via Registry."
            try {
                $registryPath = $script:AppConfig.Registry.TerminalStartup
                if (-not (Test-Path $registryPath)) { $null = New-Item -Path $registryPath -Force }

                Set-ItemProperty -Path $registryPath -Name 'DelegationTerminal' -Value $script:AppConfig.WindowsTerminal.DelegationTerminalClsid -Force
                Set-ItemProperty -Path $registryPath -Name 'DelegationConsole' -Value $script:AppConfig.WindowsTerminal.DelegationConsoleClsid -Force
                Write-StyledMessage -Type Success -Text "✅ Windows Terminal impostato come predefinito."
            }
            catch {
                Write-StyledMessage -Type Warning -Text "⚠️ Impossibile impostare terminale predefinito: $($_.Exception.Message)."
            }
        }

        # SEMPRE eseguito: Installazione ambiente PSP e profilo
        Install-PspEnvironment
        
        New-ToolkitDesktopShortcut

        Write-StyledMessage -Type Success -Text "Configurazione completata."

        if ($isResumeSetup) {
            Write-StyledMessage -Type Info -Text "Installazione ripresa, sessione completata."
        }

        if ($rebootNeeded) {
            Write-StyledMessage -Type Warning -Text "Riavvio necessario tra 10 secondi."
            Start-Sleep 10
            Restart-Computer -Force
        }
        else {
            Write-StyledMessage -Type Success -Text "WinToolkit è Pronto sul Desktop! 🚀"
            Start-Sleep 3
            exit
        }
    }
    catch {
        # Ripristino servizi in caso di errore
        Invoke-StartUpdateServices
        
        Write-StyledMessage -Type Error -Text "❌ Errore critico durante il setup: $($_.Exception.Message)."
        Write-ToolkitLog -Level 'ERROR' -Message "ECCEZIONE UNHANDLED: $($_.Exception.Message) `n $($_.ScriptStackTrace)"
        Write-Host "Premi un tasto per uscire."
        $null = [Console]::ReadKey($true)
        exit 1
    }
}

Invoke-WinToolkitSetup
