function WinReinstallStore {
    <#
    .SYNOPSIS
        Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget.
    .DESCRIPTION
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI.
        Integra le logiche testate di start.ps1 per risolvere:
        - Bug grafico (UI bleeding AppX progress bar)
        - Errore 0xc0000022 tramite risoluzione percorso eseguibile reale
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # 1. LOGGING — SEMPRE PRIMA
    Start-ToolkitLog -ToolName "WinReinstallStore"

    # 2. HEADER E PROTEZIONE GRAFICA
    Show-Header -SubTitle "Store Repair Toolkit"
    $Host.UI.RawUI.WindowTitle = "Store Repair Toolkit By MagnetarMan"

    # Salviamo lo stato e forziamo la soppressione a livello GLOBALE
    # Questo impedisce al deployment AppX di Windows di inviare progress stream alla console
    $global:OldProgressPreference = $global:ProgressPreference
    $global:ProgressPreference    = 'SilentlyContinue'

    # Fix W11: il buffer di scrittura AppX lascia residui se non si forza CR prima di ogni riga
    $onW11 = [Environment]::OSVersion.Version.Build -ge 22000

    # ============================================================================
    # 2. FUNZIONI HELPER LOCALI
    # ============================================================================

    # Trova il percorso ASSOLUTO e REALE di winget.exe in WindowsApps (bypass alias 0xc0000022)
    function Get-WingetExecutable {
        try {
            $wingetPathToResolve = Join-Path $AppConfig.Paths.ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe'
            $resolvedPaths = Resolve-Path -Path $wingetPathToResolve -ErrorAction Stop | Sort-Object {
                [version]($_.Path -replace '^[^\d]+_((\d+\.)*\d+)_.*', '$1')
            }
            if ($resolvedPaths) {
                $wingetDir = $resolvedPaths[-1].Path
                $exePath   = Join-Path $wingetDir 'winget.exe'
                if (Test-Path $exePath) { return $exePath }
            }
        }
        catch { }

        # Fallback: alias utente (potrebbe non funzionare dopo un reset)
        return "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    }

    # Applica permessi FullControl agli Administrators sulla cartella winget
    function Set-WingetPathPermissions {
        param([string]$FolderPath)
        if (-not (Test-Path $FolderPath)) { return }
        try {
            $adminSid   = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
            $adminGroup = $adminSid.Translate([System.Security.Principal.NTAccount])
            $acl        = Get-Acl -Path $FolderPath -ErrorAction Stop
            $rule       = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $adminGroup, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
            )
            $acl.SetAccessRule($rule)
            Set-Acl -Path $FolderPath -AclObject $acl -ErrorAction Stop
        }
        catch { }
    }

    # Aggiorna PATH di sessione
    function Update-SessionPath {
        $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $userPath    = [Environment]::GetEnvironmentVariable('Path', 'User')
        $env:Path    = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
        [System.Environment]::SetEnvironmentVariable('Path', $env:Path, 'Process')
    }

    # Chiude i processi che bloccano l'installazione AppX
    function Stop-InterferingProcesses {
        $interferingProcesses = @('WinStore.App', 'wsappx', 'AppInstaller', 'Microsoft.WindowsStore',
                                  'Microsoft.DesktopAppInstaller', 'winget', 'WindowsPackageManagerServer')
        
        $null = Invoke-WithSpinner -Activity "Arresto processi interferenti" -Process -Action {
            $interferingProcesses | ForEach-Object {
                Get-Process -Name $_ -ErrorAction SilentlyContinue |
                    Where-Object { $_.Id -ne $PID } |
                    Stop-Process -Force -ErrorAction SilentlyContinue
            }
            Start-Sleep 2
        } -TimeoutSeconds 10
    }

    # ============================================================================
    # 3. REINSTALLAZIONE WINGET
    # ============================================================================

    function Invoke-WingetReinstall {
        Write-StyledMessage -Type 'Info' -Text "🛠️ Avvio procedura reinstallazione Winget..."

        Stop-InterferingProcesses

        $tempDir = Join-Path $AppConfig.Paths.TempFolder 'WinToolkitWinget'
        $null = New-Item -Path $tempDir -ItemType Directory -Force *>$null

        try {
            # Helper per recuperare URL asset GitHub
            function Get-WingetAssetUrl {
                param([string]$Match)
                try {
                    $latest = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' -UseBasicParsing
                    $asset  = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
                    if ($asset) { return $asset.browser_download_url }
                }
                catch { }
                return $null
            }

            # Passo 1: Reset sorgenti se winget è già presente
            $currentWinget = Get-WingetExecutable
            if (Test-Path $currentWinget -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type 'Info' -Text "Reset sorgenti Winget..."
                try { $null = & $currentWinget source reset --force 2>$null } catch { }
            }

            # Passo 2: Dipendenze (UI.Xaml, VCLibs) — da zip ufficiale del repo
            Write-StyledMessage -Type 'Info' -Text "💎 Download dipendenze Appx..."
            $depUrl = Get-WingetAssetUrl -Match 'DesktopAppInstaller_Dependencies.zip'
            if ($depUrl) {
                $depZip     = Join-Path $tempDir 'dependencies.zip'
                $extractDir = Join-Path $tempDir 'deps'
                $iwrParams = @{
                    Uri             = $depUrl
                    OutFile         = $depZip
                    UseBasicParsing = $true
                    ErrorAction     = 'Stop'
                }
                Invoke-WebRequest @iwrParams
                Expand-Archive -Path $depZip -DestinationPath $extractDir -Force *>$null

                $archPatt = if ([Environment]::Is64BitOperatingSystem) { 'x64|neutral' } else { 'x86|neutral' }
                $appxFiles = Get-ChildItem -Path $extractDir -Recurse -Filter '*.appx' | Where-Object { $_.Name -match $archPatt }
                
                foreach ($appx in $appxFiles) {
                    $null = Invoke-WithSpinner -Activity "Installazione dipendenza: $($appx.Name)" -Process -Action {
                        $outTmp = Join-Path $AppConfig.Paths.TempFolder "dep_out_$($appx.BaseName).log"
                        $errTmp = Join-Path $AppConfig.Paths.TempFolder "dep_err_$($appx.BaseName).log"
                        $procParams = @{
                            FilePath               = 'powershell.exe'
                            ArgumentList           = @('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-Command',
                                                        "`$ProgressPreference='SilentlyContinue'; Add-AppxPackage -Path '$($appx.FullName)' -ForceApplicationShutdown -ErrorAction SilentlyContinue")
                            PassThru               = $true
                            WindowStyle            = 'Hidden'
                            RedirectStandardOutput = $outTmp
                            RedirectStandardError  = $errTmp
                        }
                        $p = Start-Process @procParams -Wait
                        Remove-Item $outTmp, $errTmp -Force -ErrorAction SilentlyContinue *>$null
                    } -TimeoutSeconds 300
                }
                Write-StyledMessage -Type 'Success' -Text "✅ Dipendenze Appx installate."
            }

            # Passo 3: Winget MSIXBundle
            Write-StyledMessage -Type 'Info' -Text "💎 Installazione Winget MSIXBundle..."
            $msixUrl = Get-WingetAssetUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
            if ($msixUrl) {
                $msixFile = Join-Path $tempDir 'winget.msixbundle'
                $iwrParams = @{
                    Uri             = $msixUrl
                    OutFile         = $msixFile
                    UseBasicParsing = $true
                    ErrorAction     = 'Stop'
                }
                Invoke-WebRequest @iwrParams

                # Usa processo figlio per isolare completamente il progress stream di appx
                $null = Invoke-WithSpinner -Activity "Installazione Winget MSIXBundle" -Process -Action {
                    $outTmp = Join-Path $AppConfig.Paths.TempFolder 'winget_msix_out.log'
                    $errTmp = Join-Path $AppConfig.Paths.TempFolder 'winget_msix_err.log'
                    $procParams = @{
                        FilePath               = 'powershell.exe'
                        ArgumentList           = @('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-Command',
                                                    "`$ProgressPreference='SilentlyContinue'; Add-AppxPackage -Path '$msixFile' -ForceApplicationShutdown -ErrorAction Stop")
                        PassThru               = $true
                        WindowStyle            = 'Hidden'
                        RedirectStandardOutput = $outTmp
                        RedirectStandardError  = $errTmp
                    }
                    $p = Start-Process @procParams -Wait
                    Remove-Item $outTmp, $errTmp -Force -ErrorAction SilentlyContinue *>$null
                } -TimeoutSeconds 300
            }

            # Passo 4: Reset App Installer (fix ACCESS_VIOLATION)
            Write-StyledMessage -Type 'Info' -Text "Reset App Installer (fix 0xc0000022)..."
            if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
                Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
            }

            # Passo 5: Permessi PATH
            Write-StyledMessage -Type 'Info' -Text "Applicazione permessi PATH Winget..."
            $arch      = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
            $wingetDir = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" `
                -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" `
                -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
            if ($wingetDir) {
                Set-WingetPathPermissions -FolderPath $wingetDir.FullName

                # Aggiunge al PATH di Sistema
                $syspath = [Environment]::GetEnvironmentVariable('PATH','Machine')
                if ($syspath -notmatch [regex]::Escape($wingetDir.FullName)) {
                    [Environment]::SetEnvironmentVariable('PATH', "$syspath;$($wingetDir.FullName)", 'Machine')
                }
            }

            # Path utente con %LOCALAPPDATA%
            $usrPath = [Environment]::GetEnvironmentVariable('PATH','User')
            if ($usrPath -notmatch [regex]::Escape('%LOCALAPPDATA%\Microsoft\WindowsApps')) {
                [Environment]::SetEnvironmentVariable('PATH', "$usrPath;%LOCALAPPDATA%\Microsoft\WindowsApps", 'User')
            }

            Update-SessionPath
            Start-Sleep 3

            # Verifica finale
            $newWinget = Get-WingetExecutable
            if (Test-Path $newWinget -ErrorAction SilentlyContinue) {
                $ver = & $newWinget --version 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-StyledMessage -Type 'Success' -Text "✅ Winget reinstallato e funzionante ($ver)."
                    return $true
                }
            }

            Write-StyledMessage -Type 'Warning' -Text "⚠️ Winget reinstallato ma la verifica finale non è conclusiva."
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "❌ Errore durante reinstallazione Winget: $($_.Exception.Message)"
            return $false
        }
        finally {
            if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue *>$null }
        }
    }

    # ============================================================================
    # 4. INSTALLAZIONE MICROSOFT STORE
    # ============================================================================

    function Install-MicrosoftStore {
        Write-StyledMessage -Type 'Info' -Text "🔄 Reinstallazione Microsoft Store in corso..."

        @('AppXSvc', 'ClipSVC', 'WSService') | ForEach-Object {
            try { Restart-Service $_ -Force -ErrorAction SilentlyContinue *>$null } catch { }
        }

        @("$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
          "$env:LOCALAPPDATA\Microsoft\Windows\INetCache") | ForEach-Object {
            if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue *>$null }
        }

        $wingetExe = Get-WingetExecutable

        $installMethods = @(
            @{
                Name   = 'Winget Install'
                Action = {
                    if (-not (Test-Path $wingetExe -ErrorAction SilentlyContinue)) { return @{ ExitCode = -1 } }

                    $outLog = Join-Path $AppConfig.Paths.TempFolder 'winget_store_out.log'
                    $errLog = Join-Path $AppConfig.Paths.TempFolder 'winget_store_err.log'

                    $processResult = Invoke-WithSpinner -Activity "Installazione tramite Winget" -Process -Action {
                        $procParams = @{
                            FilePath               = $wingetExe
                            ArgumentList           = @('install','9WZDNCRFJBMP','--accept-source-agreements',
                                                        '--accept-package-agreements','--silent','--disable-interactivity')
                            PassThru               = $true
                            WindowStyle            = 'Hidden'
                            RedirectStandardOutput = $outLog
                            RedirectStandardError  = $errLog
                        }
                        Start-Process @procParams
                    } -TimeoutSeconds 300
                    
                    Remove-Item $outLog, $errLog -Force -ErrorAction SilentlyContinue *>$null
                    return @{ ExitCode = $processResult.ExitCode }
                }
            },
            @{
                Name   = 'AppX Manifest'
                Action = {
                    $store = Get-AppxPackage -AllUsers *WindowsStore* -ErrorAction SilentlyContinue | Select-Object -First 1
                    if (-not $store -or -not $store.InstallLocation) { return @{ ExitCode = -1 } }
                    $manifest = Join-Path $store.InstallLocation 'AppxManifest.xml'
                    if (-not (Test-Path $manifest)) { return @{ ExitCode = -1 } }
                    
                    try {
                        $null = Invoke-WithSpinner -Activity "Registrazione AppXManifest" -Process -Action {
                            $outTmp = Join-Path $AppConfig.Paths.TempFolder 'appx_store_out.log'
                            $errTmp = Join-Path $AppConfig.Paths.TempFolder 'appx_store_err.log'
                            $procParams = @{
                                FilePath               = 'powershell.exe'
                                ArgumentList           = @('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-Command',
                                                            "`$ProgressPreference='SilentlyContinue'; Add-AppxPackage -DisableDevelopmentMode -Register '$manifest' -ForceApplicationShutdown -ErrorAction Stop")
                                PassThru               = $true
                                WindowStyle            = 'Hidden'
                                RedirectStandardOutput = $outTmp
                                RedirectStandardError  = $errTmp
                            }
                            $p = Start-Process @procParams -Wait
                            Remove-Item $outTmp, $errTmp -Force -ErrorAction SilentlyContinue *>$null
                        } -TimeoutSeconds 120
                        return @{ ExitCode = 0 }
                    }
                    catch { return @{ ExitCode = -1 } }
                }
            },
            @{
                Name   = 'DISM Capability'
                Action = {
                    $processResult = Invoke-WithSpinner -Activity "Aggiunta DISM Capability" -Process -Action {
                        $procParams = @{
                            FilePath     = 'DISM'
                            ArgumentList = @('/Online','/Add-Capability','/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0')
                            PassThru     = $true
                            WindowStyle  = 'Hidden'
                        }
                        Start-Process @procParams
                    } -TimeoutSeconds 300
                    return @{ ExitCode = $processResult.ExitCode }
                }
            }
        )

        $success = $false
        foreach ($method in $installMethods) {
            Write-StyledMessage -Type 'Info' -Text "Tentativo tramite: $($method.Name)..."
            try {
                $result    = $method.Action.Invoke()
                $isSuccess = $result -and (
                    $result.ExitCode -eq 0 -or $result.ExitCode -eq 3010 -or
                    $result.ExitCode -eq 1638 -or $result.ExitCode -eq -1978335189
                )
                if ($isSuccess) {
                    Write-StyledMessage -Type 'Success' -Text "Microsoft Store reinstallato tramite $($method.Name)."
                    $success = $true
                    break
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "Metodo $($method.Name) non riuscito (ExitCode: $($result.ExitCode ?? 'N/A'))."
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Metodo $($method.Name) fallito: $($_.Exception.Message)"
            }
        }

        if ($success) {
            Write-StyledMessage -Type 'Info' -Text "Esecuzione di wsreset.exe per pulire la cache dello Store..."
            try {
                $null = Invoke-WithSpinner -Activity "Reset cache Microsoft Store (wsreset)" -Process -Action {
                    $procParams = @{
                        FilePath    = 'wsreset.exe'
                        PassThru    = $true
                        WindowStyle = 'Hidden'
                    }
                    Start-Process @procParams
                } -TimeoutSeconds 120
                Write-StyledMessage -Type 'Success' -Text "Cache dello Store ripristinata."
            }
            catch { }
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Impossibile reinstallare Microsoft Store tramite i metodi automatici."
            Write-StyledMessage -Type 'Info' -Text "Esecuzione comando di emergenza (Get-AppxPackage reset)..."
            try {
                $null = Invoke-WithSpinner -Activity "Ripristino di emergenza Store" -Process -Action {
                    $outTmp = Join-Path $AppConfig.Paths.TempFolder 'appx_reset_out.log'
                    $errTmp = Join-Path $AppConfig.Paths.TempFolder 'appx_reset_err.log'
                    $procParams = @{
                        FilePath               = 'powershell.exe'
                        ArgumentList           = @('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-Command',
                                                    "Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object { `$ProgressPreference='SilentlyContinue'; Add-AppxPackage -DisableDevelopmentMode -Register `"`$(`$_.InstallLocation)\AppXManifest.xml`" -ForceApplicationShutdown }")
                        PassThru               = $true
                        WindowStyle            = 'Hidden'
                        RedirectStandardOutput = $outTmp
                        RedirectStandardError  = $errTmp
                    }
                    $p = Start-Process @procParams -Wait
                    Remove-Item $outTmp, $errTmp -Force -ErrorAction SilentlyContinue *>$null
                } -TimeoutSeconds 300
                Write-StyledMessage -Type 'Success' -Text "Microsoft Store ripristinato tramite comando di emergenza."
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Comando di emergenza fallito."
            }
        }

        return $success
    }

    # ============================================================================
    # 5. INSTALLAZIONE UNIGET UI
    # ============================================================================

    function Install-UniGetUI {
        Write-StyledMessage -Type 'Info' -Text "🔄 Installazione UniGet UI..."

        $wingetExe = Get-WingetExecutable
        if (-not (Test-Path $wingetExe -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Warning' -Text "Winget non disponibile o percorso inaccessibile. UniGet UI richiede Winget."
            return $false
        }

        try {
            # Disinstalla versione precedente
            $null = Invoke-WithSpinner -Activity "Disinstallazione versioni precedenti di UniGet UI" -Process -Action {
                $procParams = @{
                    FilePath     = $wingetExe
                    ArgumentList = @('uninstall','--exact','--id','MartiCliment.UniGetUI','--silent','--disable-interactivity')
                    PassThru     = $true
                    WindowStyle  = 'Hidden'
                }
                Start-Process @procParams
            } -TimeoutSeconds 120
            
            Write-StyledMessage -Type 'Info' -Text "Download e installazione silenziosa di UniGet UI..."

            $outLog = Join-Path $AppConfig.Paths.TempFolder 'winget_uniget_out.log'
            $errLog = Join-Path $AppConfig.Paths.TempFolder 'winget_uniget_err.log'

            $processResult = Invoke-WithSpinner -Activity "Installazione UniGet UI" -Process -Action {
                $procParams = @{
                    FilePath               = $wingetExe
                    ArgumentList           = @('install','--exact','--id','MartiCliment.UniGetUI',
                                                '--source','winget','--accept-source-agreements','--accept-package-agreements',
                                                '--silent','--disable-interactivity','--force')
                    PassThru               = $true
                    WindowStyle            = 'Hidden'
                    RedirectStandardOutput = $outLog
                    RedirectStandardError  = $errLog
                    ErrorAction            = 'Stop'
                }
                Start-Process @procParams
            } -TimeoutSeconds 600
            
            Remove-Item $outLog, $errLog -Force -ErrorAction SilentlyContinue *>$null

            $isSuccess = $processResult.ExitCode -eq 0 -or $processResult.ExitCode -eq 3010 -or
                         $processResult.ExitCode -eq 1638 -or $processResult.ExitCode -eq -1978335189

            if ($isSuccess) {
                Write-StyledMessage -Type 'Success' -Text "UniGet UI installato correttamente."

                Write-StyledMessage -Type 'Info' -Text "🔄 Disabilitazione avvio automatico UniGet UI..."
                try {
                    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
                    if (Get-ItemProperty -Path $regPath -Name 'WingetUI' -ErrorAction SilentlyContinue) {
                        Remove-ItemProperty -Path $regPath -Name 'WingetUI' -ErrorAction Stop *>$null
                        Write-StyledMessage -Type 'Success' -Text "Avvio automatico UniGet UI disabilitato."
                    }
                }
                catch { }
                return $true
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "Installazione UniGet UI terminata con codice: $($processResult.ExitCode)"
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante installazione UniGet UI: $($_.Exception.Message)"
            return $false
        }
    }

    # ============================================================================
    # 6. ESECUZIONE PRINCIPALE
    # ============================================================================
    try {
        Write-StyledMessage -Type 'Info' -Text "🚀 AVVIO REINSTALLAZIONE STORE"
        Write-StyledMessage -Type 'Info' -Text "Inizio procedura di ripristino Store & Winget..."

        # Reset Winget: prima prova Reset-Winget del framework, poi Invoke-WingetReinstall se fallisce
        $wingetResult = $false
        if (Get-Command Reset-Winget -ErrorAction SilentlyContinue) {
            $wingetResult = Reset-Winget -Force
        }
        if (-not $wingetResult) {
            Write-StyledMessage -Type 'Warning' -Text "Fallback: reinstallazione Winget da zero..."
            $wingetResult = Invoke-WingetReinstall
        }
        Write-StyledMessage -Type $(if ($wingetResult) { 'Success' } else { 'Warning' }) -Text `
            "Winget $(if ($wingetResult) { 'ripristinato con successo' } else { 'processato (potrebbe richiedere verifica manuale)' })"

        $storeResult = Install-MicrosoftStore
        if (-not $storeResult) {
            Write-StyledMessage -Type 'Error' -Text "Errore installazione Microsoft Store. Verifica connessione o Windows Update."
        }
        else {
            Write-StyledMessage -Type 'Success' -Text "Microsoft Store installato"
        }

        $unigetResult = Install-UniGetUI
        Write-StyledMessage -Type $(if ($unigetResult) { 'Success' } else { 'Warning' }) -Text `
            "UniGet UI $(if ($unigetResult) { 'installato' } else { 'processato (verifica manuale necessaria)' })"

        Write-Host ""
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-StyledMessage -Type 'Success' -Text "🎉 OPERAZIONE COMPLETATA"
        Write-StyledMessage -Type 'Info' -Text "Tutti i componenti (Winget, Store, UniGet UI) sono stati elaborati."
        Write-Host ('═' * 80) -ForegroundColor Green

    }
    finally {
        # Ripristino garantito dello stato grafico di PowerShell
        $global:ProgressPreference = $global:OldProgressPreference
    }

    # ============================================================================
    # 7. GESTIONE RIAVVIO
    # ============================================================================

    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
    }
    else {
        if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio in") {
            Restart-Computer -Force
        }
    }
}
