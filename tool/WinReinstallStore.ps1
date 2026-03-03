function WinReinstallStore {
    <#
    .SYNOPSIS
        Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget.

    .DESCRIPTION
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI senza output bloccanti in modo completo.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$NoReboot,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName "WinReinstallStore"
    Show-Header -SubTitle "Store Repair Toolkit"

    # ============================================================================
    # 2. FUNZIONI HELPER LOCALI - GESTIONE AMBIENTE E PERCORSI
    # ============================================================================

    function Update-EnvironmentPath {
        <#
        .SYNOPSIS
            Ricarica PATH da Machine e User per rilevare installazioni recenti.
        #>
        $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'

        $env:Path = $newPath
        [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
    }

    function Path-ExistsInEnvironment {
        <#
        .SYNOPSIS
            Controlla se un percorso esiste nella variabile PATH.
        #>
        param (
            [string]$PathToCheck,
            [string]$Scope = 'Both'
        )

        $pathExists = $false

        if ($Scope -eq 'User' -or $Scope -eq 'Both') {
            $userEnvPath = $env:PATH
            if (($userEnvPath -split ';').Contains($PathToCheck)) { $pathExists = $true }
        }

        if ($Scope -eq 'System' -or $Scope -eq 'Both') {
            $systemEnvPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)
            if (($systemEnvPath -split ';').Contains($PathToCheck)) { $pathExists = $true }
        }

        return $pathExists
    }

    function Add-ToEnvironmentPath {
        <#
        .SYNOPSIS
            Aggiunge un percorso alla variabile PATH.
        #>
        param (
            [Parameter(Mandatory = $true)]
            [string]$PathToAdd,
            [ValidateSet('User', 'System')]
            [string]$Scope
        )

        if (-not (Path-ExistsInEnvironment -PathToCheck $PathToAdd -Scope $Scope)) {
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

            if (-not ($env:PATH -split ';').Contains($PathToAdd)) {
                $env:PATH += ";$PathToAdd"
            }
            Write-StyledMessage -Type 'Info' -Text "PATH aggiornato: $PathToAdd"
        }
    }

    function Set-PathPermissions {
        <#
        .SYNOPSIS
            Concede permessi full control al gruppo Administrators sulla cartella specificata.
        #>
        param (
            [string]$FolderPath
        )

        if (-not (Test-Path $FolderPath)) { return }

        try {
            $administratorsGroupSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
            $administratorsGroup = $administratorsGroupSid.Translate([System.Security.Principal.NTAccount])
            $acl = Get-Acl -Path $FolderPath -ErrorAction Stop
            
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $administratorsGroup, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
            )
            
            $acl.SetAccessRule($accessRule)
            Set-Acl -Path $FolderPath -AclObject $acl -ErrorAction Stop
            Write-StyledMessage -Type 'Info' -Text "Permessi cartella aggiornati: $FolderPath"
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile impostare permessi: $($_.Exception.Message)"
        }
    }

    # ============================================================================
    # 2B. FUNZIONI HELPER LOCALI - VERIFICA INSTALLAZIONE
    # ============================================================================

    function Test-VCRedistInstalled {
        <#
        .SYNOPSIS
            Verifica se Visual C++ Redistributable è installato e verifica la versione principale è 14.
        #>
        
        $is64BitOS = [System.Environment]::Is64BitOperatingSystem
        $is64BitProcess = [System.Environment]::Is64BitProcess

        if ($is64BitOS -and -not $is64BitProcess) {
            Write-StyledMessage -Type 'Warning' -Text "Esegui PowerShell nativo (x64)."
            return $false
        }

        $registryPath = [string]::Format(
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\{0}\Microsoft\VisualStudio\14.0\VC\Runtimes\X{1}',
            $(if ($is64BitOS -and $is64BitProcess) { 'WOW6432Node' } else { '' }),
            $(if ($is64BitOS) { '64' } else { '86' })
        )

        $isRegistryExists = Test-Path -Path $registryPath

        $majorVersion = if ($isRegistryExists) {
            (Get-ItemProperty -Path $registryPath -Name 'Major' -ErrorAction SilentlyContinue).Major
        }
        else { 0 }

        $dllPath = [string]::Format('{0}\concrt140.dll', [Environment]::GetFolderPath('System'))
        $dllExists = [System.IO.File]::Exists($dllPath)

        return $isRegistryExists -and $majorVersion -eq 14 -and $dllExists
    }

    function Find-WinGet {
        <#
        .SYNOPSIS
            Trova la posizione dell'eseguibile WinGet.
        #>
        try {
            $wingetPathToResolve = Join-Path -Path $ENV:ProgramFiles -ChildPath 'Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe'
            $resolveWingetPath = Resolve-Path -Path $wingetPathToResolve -ErrorAction Stop | Sort-Object {
                [version]($_.Path -replace '^[^\d]+_((\d+\.)*\d+)_.*', '$1')
            }

            if ($resolveWingetPath) {
                $wingetPath = $resolveWingetPath[-1].Path
            }

            $wingetExe = Join-Path $wingetPath 'winget.exe'

            if (Test-Path -Path $wingetExe) {
                return $wingetExe
            }
            else {
                return $null
            }
        }
        catch {
            return $null
        }
    }

    function Install-NuGetIfRequired {
        <#
        .SYNOPSIS
            Verifica se il provider NuGet è installato e lo installa se necessario.
        #>
        
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            if ($PSVersionTable.PSVersion.Major -lt 7) {
                try {
                    Install-PackageProvider -Name "NuGet" -Force -ForceBootstrap -ErrorAction SilentlyContinue *>$null
                    Write-StyledMessage -Type 'Info' -Text "Provider NuGet installato."
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Impossibile installare provider NuGet."
                }
            }
        }
    }

    # ============================================================================
    # 2C. FUNZIONI HELPER LOCALI - GESTIONE PROCESSI E RIPARAZIONE
    # ============================================================================

    function Invoke-ForceCloseWinget {
        <#
        .SYNOPSIS
            Chiude i processi che bloccano l'installazione di Winget/Store.
            Approccio mirato per evitare di chiudere processi di sistema non necessari.
        #>
        Write-StyledMessage -Type 'Info' -Text "Chiusura processi interferenti..."
        
        # Lista mirata dei processi che bloccano effettivamente l'installazione Appx
        $interferingProcesses = @(
            @{ Name = "WinStore.App"; Description = "Windows Store process" },
            @{ Name = "wsappx"; Description = "AppX deployment service" },
            @{ Name = "AppInstaller"; Description = "App Installer service" },
            @{ Name = "Microsoft.WindowsStore"; Description = "Windows Store" },
            @{ Name = "Microsoft.DesktopAppInstaller"; Description = "Desktop App Installer" },
            @{ Name = "winget"; Description = "Winget CLI" },
            @{ Name = "WindowsPackageManagerServer"; Description = "Windows Package Manager Server" }
        )

        foreach ($proc in $interferingProcesses) {
            Get-Process -Name $proc.Name -ErrorAction SilentlyContinue | 
            Where-Object { $_.Id -ne $PID } | 
            Stop-Process -Force -ErrorAction SilentlyContinue
        }
        
        Start-Sleep 2
        Write-StyledMessage -Type 'Success' -Text "Processi interferenti chiusi."
    }

    function Apply-WingetPathPermissions {
        <#
        .SYNOPSIS
            Applica permessi PATH e aggiunge la cartella winget a PATH.
            Basato su approccio asheroto.
        #>
        
        $wingetFolderPath = $null
        
        try {
            $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
            $wingetDir = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue | 
            Sort-Object Name -Descending | Select-Object -First 1
            
            if ($wingetDir) {
                $wingetFolderPath = $wingetDir.FullName
            }
        }
        catch { }

        if ($wingetFolderPath) {
            Set-PathPermissions -FolderPath $wingetFolderPath
            Add-ToEnvironmentPath -PathToAdd $wingetFolderPath -Scope 'System'
            Add-ToEnvironmentPath -PathToAdd "%LOCALAPPDATA%\Microsoft\WindowsApps" -Scope 'User'
            
            Write-StyledMessage -Type 'Success' -Text "PATH e permessi winget aggiornati."
        }
    }

    function Repair-WingetDatabase {
        <#
        .SYNOPSIS
            Ripara il database di Winget.
        #>
        Write-StyledMessage -Type 'Info' -Text "Avvio ripristino database Winget..."
        
        try {
            # 1. Usa Stop-InterferingProcess come in start.ps1
            Stop-InterferingProcess
            
            $wingetCachePath = "$env:LOCALAPPDATA\WinGet"
            if (Test-Path $wingetCachePath) {
                Write-StyledMessage -Type 'Info' -Text "Pulizia cache Winget..."
                Get-ChildItem -Path $wingetCachePath -Recurse -Force -ErrorAction SilentlyContinue | 
                Where-Object { $_.FullName -notmatch '\\lock\\|\\tmp\\' } |
                ForEach-Object {
                    try { 
                        Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue 
                    }
                    catch { }
                }
            }
            
            $stateFiles = @(
                "$env:LOCALAPPDATA\WinGet\Data\USERTEMPLATE.json",
                "$env:LOCALAPPDATA\WinGet\Data\DEFAULTUSER.json"
            )
            
            foreach ($file in $stateFiles) {
                if (Test-Path $file -PathType Leaf) {
                    Write-StyledMessage -Type 'Info' -Text "Reset file stato: $file"
                    Remove-Item $file -Force -ErrorAction SilentlyContinue
                }
            }
            
            Write-StyledMessage -Type 'Info' -Text "Reset sorgenti Winget..."
            try {
                $null = & winget.exe source reset --force 2>&1
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore durante reset sorgenti Winget: $($_.Exception.Message)"
            }
            
            Update-EnvironmentPath
            
            try {
                if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                    Write-StyledMessage -Type 'Info' -Text "Esecuzione Repair-WinGetPackageManager..."
                    Repair-WinGetPackageManager -Force -Latest *>$null
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Modulo Riparazione non disponibile: $($_.Exception.Message)"
            }
            
            Start-Sleep 2
            $testVersion = & winget --version *>$null
            if ($LASTEXITCODE -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "Database Winget ripristinato (versione: $testVersion)."
                return $true
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "Ripristino completato ma winget potrebbe non funzionare."
                return $true
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante ripristino database: $($_.Exception.Message)"
            return $false
        }
    }

    # ============================================================================
    # 2D. FUNZIONI HELPER LOCALI - VALIDAZIONE E DOWNLOAD
    # ============================================================================

    function Test-WingetDeepValidation {
        <#
        .SYNOPSIS
            Esegue test profondo di winget (ricerca pacchetti in rete).
        #>
        Write-StyledMessage -Type 'Info' -Text "Esecuzione test profondo di Winget (ricerca pacchetti in rete)..."

        try {
            $searchResult = & winget search "Git.Git" --accept-source-agreements 2>&1
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                Write-StyledMessage -Type 'Warning' -Text "Crash rilevato (ExitCode: $exitCode = ACCESS_VIOLATION). Tentativo ripristino database..."
                
                $repairAttempt = Repair-WingetDatabase
                
                if ($repairAttempt) {
                    Write-StyledMessage -Type 'Info' -Text "Ripetizione test dopo ripristino..."
                    Start-Sleep 3
                    $searchResult = & winget search "Git.Git" --accept-source-agreements 2>&1
                    $exitCode = $LASTEXITCODE
                }
            }

            if ($exitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "Test profondo superato: Winget comunica correttamente con i repository."
                return $true
            }
            else {
                $errorDetails = $searchResult | Out-String
                if ($errorDetails.Length -gt 200) { $errorDetails = $errorDetails.Substring(0, 200) + "..." }
                Write-StyledMessage -Type 'Warning' -Text "Test profondo fallito: ExitCode=$exitCode. Dettagli: $errorDetails"
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante il test profondo di Winget: $($_.Exception.Message)"
            return $false
        }
    }

    function Get-WingetDownloadUrl {
        <#
        .SYNOPSIS
            Recupera URL download da GitHub releases.
        #>
        param([string]$Match)
        try {
            $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
            $asset = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
            if ($asset) { return $asset.browser_download_url }
            throw "Asset '$Match' non trovato."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore recupero URL asset: $($_.Exception.Message)"
            return $null
        }
    }

    function Install-WingetCore {
        Write-StyledMessage -Type 'Info' -Text "🚀 Avvio della procedura di reinstallazione e riparazione Winget..."

        $oldProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        # --- FASE 0: Verifica Visual C++ Redistributable ---
        if (-not (Test-VCRedistInstalled)) {
            Write-StyledMessage -Type 'Info' -Text "Installazione Visual C++ Redistributable..."
            $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
            $vcUrl = "https://aka.ms/vs/17/release/vc_redist.$arch.exe"
            $tempDir = "$env:TEMP\WinToolkitWinget"
            if (-not (Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force *>$null }
            $vcFile = Join-Path $tempDir "vc_redist.exe"

            try {
                Invoke-WebRequest -Uri $vcUrl -OutFile $vcFile -UseBasicParsing -ErrorAction Stop
                $procParams = @{
                    FilePath     = $vcFile
                    ArgumentList = @("/install", "/quiet", "/norestart")
                    Wait         = $true
                    NoNewWindow  = $true
                }
                Start-Process @procParams
                Write-StyledMessage -Type 'Success' -Text "Visual C++ Redistributable installato."
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Impossibile installare VC++ Redistributable: $($_.Exception.Message)"
            }
        }
        else {
            Write-StyledMessage -Type 'Success' -Text "Visual C++ Redistributable già presente."
        }

        # --- FASE 0B: Installazione Dipendenze Winget (UI.Xaml, VCLibs) ---
        Write-StyledMessage -Type 'Info' -Text "Download dipendenze Winget dal repository ufficiale..."
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

                $extractPath = Join-Path $tempDir "deps"
                if (Test-Path $extractPath) { Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue }
                Expand-Archive -Path $depZip -DestinationPath $extractPath -Force

                $archPattern = if ([Environment]::Is64BitOperatingSystem) { "x64|ne" } else { "x86|ne" }
                $appxFiles = Get-ChildItem -Path $extractPath -Recurse -Filter "*.appx" | Where-Object { $_.Name -match $archPattern }

                foreach ($file in $appxFiles) {
                    Write-StyledMessage -Type 'Info' -Text "Installazione dipendenza: $($file.Name)..."
                    Add-AppxPackage -Path $file.FullName -ErrorAction SilentlyContinue -ForceApplicationShutdown
                }
                Write-StyledMessage -Type 'Success' -Text "Dipendenze Winget installate."
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Impossibile estrarre/installare dipendenze: $($_.Exception.Message)"
            }
            finally {
                if (Test-Path $depZip) { Remove-Item $depZip -Force -ErrorAction SilentlyContinue }
            }
        }

        # --- FASE 1: Inizializzazione e Pulizia Profonda ---

        # Usa helper avanzato per terminare processi interferenti
        Write-StyledMessage -Type 'Info' -Text "🔄 Chiusura forzata dei processi Winget e correlati..."
        Invoke-ForceCloseWinget

        # Terminazione processi specifici di Winget (taskkill supplementare)
        $null = Invoke-WithSpinner -Activity "Terminazione processi Winget" -Process -Action {
            @("winget", "WindowsPackageManagerServer") | ForEach-Object {
                taskkill /im "$_.exe" /f *>$null
            }
        }

        # Pulizia cartella temporanea
        Write-StyledMessage -Type 'Info' -Text "🔄 Pulizia dei file temporanei (%TEMP%\WinGet)..."
        $tempWingetPath = "$env:TEMP\WinGet"
        if (Test-Path $tempWingetPath) {
            Remove-Item -Path $tempWingetPath -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Write-StyledMessage -Type 'Info' -Text "Cartella temporanea di Winget eliminata."
        }
        else {
            Write-StyledMessage -Type 'Info' -Text "Cartella temporanea di Winget non trovata o già pulita."
        }

        # Reset sorgenti Winget
        Write-StyledMessage -Type 'Info' -Text "🔄 Reset delle sorgenti Winget..."
        try {
            $wingetExePath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
            $null = Invoke-WithSpinner -Activity "Reset sorgenti Winget" -Process -Action {
                if (Test-Path $wingetExePath) {
                    & $wingetExePath source reset --force *>$null
                }
                else {
                    winget source reset --force *>$null
                }
            }
            Write-StyledMessage -Type 'Success' -Text "Sorgenti Winget resettate."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Reset sorgenti Winget non riuscito: $($_.Exception.Message)"
        }

        # --- FASE 2: Installazione Dipendenze e Moduli PowerShell ---

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Installazione Provider NuGet (usando helper)
        Write-StyledMessage -Type 'Info' -Text "🔄 Installazione PackageProvider NuGet..."
        Install-NuGetIfRequired
        
        try {
            $nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
            if (-not $nugetProvider) {
                try {
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                    Write-StyledMessage -Type 'Success' -Text "Provider NuGet installato."
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Provider NuGet: conferma manuale potrebbe essere richiesta. Errore: $($_.Exception.Message)"
                }
            }
            else {
                Write-StyledMessage -Type 'Success' -Text "Provider NuGet già installato."
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore durante l'installazione del provider NuGet: $($_.Exception.Message)"
        }

        # Installazione Modulo Microsoft.WinGet.Client
        Write-StyledMessage -Type 'Info' -Text "🔄 Installazione modulo Microsoft.WinGet.Client..."
        try {
            Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
            Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "Modulo Microsoft.WinGet.Client installato e importato."
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore installazione/import Microsoft.WinGet.Client: $($_.Exception.Message)"
        }

        # --- FASE 3: Riparazione e Reinstallazione del Core di Winget ---

        # Tentativo A — Riparazione via Modulo
        if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type 'Info' -Text "🔄 Riparazione Winget tramite modulo WinGet Client..."
            try {
                $result = Invoke-WithSpinner -Activity "Riparazione Winget (modulo)" -Process -Action {
                    $procParams = @{
                        FilePath     = 'powershell'
                        ArgumentList = @('-NoProfile', '-WindowStyle', 'Hidden', '-Command',
                            'Repair-WinGetPackageManager -Force -Latest 2>$null')
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                } -TimeoutSeconds 180

                if ($result.ExitCode -eq 0) {
                    Write-StyledMessage -Type 'Success' -Text "Winget riparato con successo tramite modulo."
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "Riparazione Winget tramite modulo non riuscita (ExitCode: $($result.ExitCode))."
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore durante la riparazione Winget: $($_.Exception.Message)"
            }
        }

        # Tentativo B — Reinstallazione tramite MSIXBundle (Fallback)
        Update-EnvironmentPath
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Info' -Text "🔄 Installazione Winget tramite MSIXBundle..."
            $tempInstaller = Join-Path $AppConfig.Paths.Temp "WingetInstaller.msixbundle"

            try {
                $null = New-Item -Path $AppConfig.Paths.Temp -ItemType Directory -Force -ErrorAction SilentlyContinue

                # Prova prima con URL dinamico da GitHub, poi fallback a aka.ms
                $wingetUrl = Get-WingetDownloadUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
                if (-not $wingetUrl) {
                    $wingetUrl = $AppConfig.URLs.WingetInstaller
                }

                $iwrParams = @{
                    Uri             = $wingetUrl
                    OutFile         = $tempInstaller
                    UseBasicParsing = $true
                    ErrorAction     = 'Stop'
                }
                Invoke-WebRequest @iwrParams

                $result = Invoke-WithSpinner -Activity "Installazione Winget MSIXBundle" -Process -Action {
                    $procParams = @{
                        FilePath     = 'powershell'
                        ArgumentList = @('-NoProfile', '-WindowStyle', 'Hidden', '-Command',
                            "try { Add-AppxPackage -Path '$tempInstaller' -ForceApplicationShutdown -ErrorAction Stop } catch { exit 1 }; exit 0")
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                } -TimeoutSeconds 120

                if ($result.ExitCode -eq 0) {
                    Write-StyledMessage -Type 'Success' -Text "Winget installato con successo tramite MSIXBundle."
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "Installazione Winget tramite MSIXBundle fallita (ExitCode: $($result.ExitCode))."
                }
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Errore download/install MSIXBundle: $($_.Exception.Message)"
            }
            finally {
                Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue *>$null
            }
        }

        # --- FASE 4: Reset dell'App Installer Appx ---
        try {
            Write-StyledMessage -Type 'Info' -Text "🔄 Reset 'Programma di installazione app'..."

            $result = Invoke-WithSpinner -Activity "Reset App Installer" -Process -Action {
                $procParams = @{
                    FilePath     = 'powershell'
                    ArgumentList = @('-NoProfile', '-WindowStyle', 'Hidden', '-Command',
                        "Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue | Reset-AppxPackage -ErrorAction SilentlyContinue")
                    PassThru     = $true
                    WindowStyle  = 'Hidden'
                }
                Start-Process @procParams
            } -TimeoutSeconds 60

            if ($result.ExitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "App 'Programma di installazione app' resettata con successo."
            }
            else {
                Write-StyledMessage -Type 'Info' -Text "Reset Appx completato (ExitCode: $($result.ExitCode))."
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile resettare App Installer: $($_.Exception.Message)"
        }

        # --- FASE 5: Applica permessi PATH ---
        Apply-WingetPathPermissions

        # --- FASE 6: Verifica Finale ---
        Start-Sleep 2
        Update-EnvironmentPath
        $isWingetAvailable = [bool](Get-Command winget -ErrorAction SilentlyContinue)

        if ($isWingetAvailable) {
            Write-StyledMessage -Type 'Success' -Text "Winget è stato processato e sembra funzionante."
            
            # Test profondo opzionale
            Write-StyledMessage -Type 'Info' -Text "Esecuzione validazione approfondita..."
            $deepTestResult = Test-WingetDeepValidation
            if ($deepTestResult) {
                Write-StyledMessage -Type 'Success' -Text "Validazione approfondita superata."
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "Validazione approfondita fallita - potrebbero esserci problemi di rete o repository."
            }
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Impossibile installare o riparare Winget dopo tutti i tentativi."
        }

        $ProgressPreference = $oldProgress
        
        # Pulizia directory temporanea
        $tempDir = "$env:TEMP\WinToolkitWinget"
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        return $isWingetAvailable
    }

    function Install-MicrosoftStore {
        Write-StyledMessage -Type 'Info' -Text "🔄 Reinstallazione Microsoft Store in corso..."

        # Restart servizi correlati allo Store
        @("AppXSvc", "ClipSVC", "WSService") | ForEach-Object {
            try { Restart-Service $_ -Force -ErrorAction SilentlyContinue *>$null } catch {}
        }

        # Pulizia cache Store
        $cachePaths = @(
            @{ Path = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache"; Description = "Windows Store Local Cache" },
            @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; Description = "Internet Cache" }
        )
        foreach ($cache in $cachePaths) {
            if (Test-Path $cache.Path) { Remove-Item $cache.Path -Recurse -Force -ErrorAction SilentlyContinue *>$null }
        }

        # Metodi di installazione in ordine di preferenza
        $installMethods = @(
            @{
                Name   = "Winget Install"
                Action = {
                    $isWingetReady = [bool](Get-Command winget -ErrorAction SilentlyContinue)
                    if (-not $isWingetReady) { return @{ ExitCode = -1 } }

                    $procParams = @{
                        FilePath     = 'winget'
                        ArgumentList = @('install', '9WZDNCRFJBMP', '--accept-source-agreements',
                            '--accept-package-agreements', '--silent', '--disable-interactivity')
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                }
            },
            @{
                Name   = "AppX Manifest"
                Action = {
                    $store = Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue | Select-Object -First 1
                    if (-not $store) { return @{ ExitCode = -1 } }

                    $manifest = "$($store.InstallLocation)\AppXManifest.xml"
                    if (-not (Test-Path $manifest)) { return @{ ExitCode = -1 } }

                    $procParams = @{
                        FilePath     = 'powershell'
                        ArgumentList = @('-NoProfile', '-WindowStyle', 'Hidden', '-Command',
                            "Add-AppxPackage -DisableDevelopmentMode -Register '$manifest' -ForceApplicationShutdown")
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                }
            },
            @{
                Name   = "DISM Capability"
                Action = {
                    $procParams = @{
                        FilePath     = 'DISM'
                        ArgumentList = @('/Online', '/Add-Capability', '/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0')
                        PassThru     = $true
                        WindowStyle  = 'Hidden'
                    }
                    Start-Process @procParams
                }
            }
        )

        # Codici di uscita considerati successo
        $successCodes = @(0, 3010, 1638, -1978335189)

        $success = $false
        foreach ($method in $installMethods) {
            Write-StyledMessage -Type 'Info' -Text "Tentativo: Installazione Store ($($method.Name))..."
            try {
                $result = Invoke-WithSpinner -Activity "Store: $($method.Name)" -Process -Action $method.Action -TimeoutSeconds 300

                $isSuccess = $result.ExitCode -in $successCodes
                if ($isSuccess) {
                    Write-StyledMessage -Type 'Success' -Text "$($method.Name) completato con successo."

                    Write-StyledMessage -Type 'Info' -Text "Esecuzione wsreset.exe per pulire la cache dello Store..."
                    $procParams = @{
                        FilePath    = 'wsreset.exe'
                        Wait        = $true
                        WindowStyle = 'Hidden'
                        ErrorAction = 'SilentlyContinue'
                    }
                    Start-Process @procParams *>$null

                    Write-StyledMessage -Type 'Success' -Text "Cache dello Store ripristinata."
                    $success = $true
                    break
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "$($method.Name) non riuscito (ExitCode: $($result.ExitCode)). Tentativo prossimo metodo."
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore durante $($method.Name): $($_.Exception.Message)"
            }
        }

        return $success
    }

    function Install-UniGetUI {
        Write-StyledMessage -Type 'Info' -Text "🔄 Reinstallazione UniGet UI in corso..."

        $isWingetReady = [bool](Get-Command winget -ErrorAction SilentlyContinue)
        if (-not $isWingetReady) {
            Write-StyledMessage -Type 'Warning' -Text "Winget non disponibile. Impossibile installare UniGet UI."
            return $false
        }

        $successCodes = @(0, 3010, 1638, -1978335189)

        try {
            # Rimozione versione esistente (ignora errori — potrebbe non essere installata)
            Write-StyledMessage -Type 'Info' -Text "🔄 Rimozione versione esistente UniGet UI..."
            $uninstallParams = @{
                FilePath     = 'winget'
                ArgumentList = @('uninstall', '--exact', '--id', 'MartiCliment.UniGetUI', '--silent', '--disable-interactivity')
                Wait         = $true
                WindowStyle  = 'Hidden'
            }
            Start-Process @uninstallParams *>$null
            Start-Sleep 2

            # Installazione nuova versione
            Write-StyledMessage -Type 'Info' -Text "🔄 Installazione UniGet UI..."
            $installResult = Invoke-WithSpinner -Activity "Installazione UniGet UI" -Process -Action {
                $procParams = @{
                    FilePath     = 'winget'
                    ArgumentList = @('install', '--exact', '--id', 'MartiCliment.UniGetUI', '--source', 'winget',
                        '--accept-source-agreements', '--accept-package-agreements', '--silent',
                        '--disable-interactivity', '--force')
                    PassThru     = $true
                    WindowStyle  = 'Hidden'
                }
                Start-Process @procParams
            } -TimeoutSeconds 300

            $isSuccess = $installResult.ExitCode -in $successCodes
            if ($isSuccess) {
                Write-StyledMessage -Type 'Success' -Text "UniGet UI installata con successo."

                # Disabilitazione avvio automatico
                Write-StyledMessage -Type 'Info' -Text "🔄 Disabilitazione avvio automatico UniGet UI..."
                try {
                    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                    $regKeyName = "WingetUI"
                    if (Get-ItemProperty -Path $regPath -Name $regKeyName -ErrorAction SilentlyContinue) {
                        Remove-ItemProperty -Path $regPath -Name $regKeyName -ErrorAction Stop *>$null
                        Write-StyledMessage -Type 'Success' -Text "Avvio automatico UniGet UI disabilitato."
                    }
                    else {
                        Write-StyledMessage -Type 'Info' -Text "Voce di avvio automatico UniGet UI non trovata — skip."
                    }
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Impossibile disabilitare avvio automatico UniGet UI: $($_.Exception.Message)"
                }
                return $true
            }
            else {
                Write-StyledMessage -Type 'Error' -Text "Installazione UniGet UI fallita (ExitCode: $($installResult.ExitCode))."
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore critico durante installazione UniGet UI: $($_.Exception.Message)"
            return $false
        }
    }

    # ============================================================================
    # 3. ESECUZIONE PRINCIPALE
    # ============================================================================

    Write-StyledMessage -Type 'Info' -Text "🚀 AVVIO REINSTALLAZIONE STORE"

    try {
        $wingetResult = Install-WingetCore
        Write-StyledMessage -Type $(if ($wingetResult) { 'Success' } else { 'Warning' }) -Text "Winget $(if ($wingetResult) { 'installato' } else { 'processato — verifica manuale consigliata' })."

        $storeResult = Install-MicrosoftStore
        if (-not $storeResult) {
            Write-StyledMessage -Type 'Error' -Text "Errore installazione Microsoft Store."
            Write-StyledMessage -Type 'Info' -Text "Verifica: connessione Internet, privilegi Admin, Windows Update."
            return
        }
        Write-StyledMessage -Type 'Success' -Text "Microsoft Store installato."

        $unigetResult = Install-UniGetUI
        Write-StyledMessage -Type $(if ($unigetResult) { 'Success' } else { 'Warning' }) -Text "UniGet UI $(if ($unigetResult) { 'installata' } else { 'processata — verifica manuale consigliata' })."

        Write-StyledMessage -Type 'Success' -Text "🎉 OPERAZIONE COMPLETATA"
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "❌ ERRORE: $($_.Exception.Message)"
        Write-StyledMessage -Type 'Info' -Text "💡 Esegui come Admin, verifica Internet e Windows Update."
    }
    finally {
        try { Stop-Transcript | Out-Null } catch {}
    }

    # ============================================================================
    # 4. GESTIONE RIAVVIO — SEMPRE ULTIMA
    # ============================================================================

    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
        Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
    }
    else {
        if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio necessario per applicare le modifiche") {
            Write-StyledMessage -Type 'Info' -Text "🔄 Riavvio in corso..."
            if (-not $NoReboot) {
                Restart-Computer -Force
            }
        }
    }
}
