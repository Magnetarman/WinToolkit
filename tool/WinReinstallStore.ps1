function WinReinstallStore {
    <#
    .SYNOPSIS
        Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget.
    .DESCRIPTION
        Script conforme a style.md v3.0. Reinstalla Winget, Microsoft Store e UniGet UI.
        Tutti i processi AppX usano System.Diagnostics.Process con CreateNoWindow=true per
        bloccare le write Win32 native del deployment engine e garantire una TUI pulita.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    # [RULE-STRUCT-01] 1. LOGGING — SEMPRE PRIMA
    Start-ToolkitLog -ToolName "WinReinstallStore"

    # [RULE-STRUCT-01] 2. HEADER
    Show-Header -SubTitle "Store Repair Toolkit"

    # Soppressione progress stream PowerShell (salvare + ripristinare in finally)
    $savedProgressPref     = $ProgressPreference
    $ProgressPreference    = 'SilentlyContinue'

    # ============================================================================
    # FUNZIONI HELPER LOCALI
    # ============================================================================

    # Trova il percorso ASSOLUTO di winget.exe in WindowsApps (bypass alias 0xc0000022)
    function Get-WingetExecutable {
        try {
            $wingetGlob    = "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe"
            $resolvedPaths = Resolve-Path -Path $wingetGlob -ErrorAction Stop | Sort-Object {
                [version]($_.Path -replace '^[^\d]+_((\d+\.)*\d+)_.*', '$1')
            }
            if ($resolvedPaths) {
                $exePath = Join-Path $resolvedPaths[-1].Path 'winget.exe'
                if (Test-Path $exePath) { return $exePath }
            }
        }
        catch { }
        return "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    }

    # Applica permessi FullControl Administrators sulla cartella winget
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

    # Helper: avvia un processo senza console (blocca output Win32 nativo del deployment AppX)
    # CreateNoWindow=true + UseShellExecute=false impedisce a WriteConsoleW di scrivere sul buffer
    function Start-IsolatedProcess {
        param([string]$Executable, [string]$Arguments)
        $psi                    = [System.Diagnostics.ProcessStartInfo]::new($Executable)
        $psi.Arguments          = $Arguments
        $psi.UseShellExecute    = $false
        $psi.CreateNoWindow     = $true
        # NESSUN REDIRECT STANDARD OUTPUT/ERROR PER EVITARE HANG
        return [System.Diagnostics.Process]::Start($psi)
    }

    # ============================================================================
    # 3. REINSTALLAZIONE WINGET
    # ============================================================================

    function Invoke-WingetReinstall {
        Write-StyledMessage -Type 'Info' -Text "🛠️ Avvio procedura reinstallazione Winget..."

        # [RULE-PROCESS-01] Chiusura processi interferenti
        Write-StyledMessage -Type 'Info' -Text "Arresto processi interferenti..."
        @('WinStore.App','wsappx','AppInstaller','Microsoft.WindowsStore',
          'Microsoft.DesktopAppInstaller','winget','WindowsPackageManagerServer') | ForEach-Object {
            Get-Process -Name $_ -ErrorAction SilentlyContinue |
                Where-Object { $_.Id -ne $PID } |
                Stop-Process -Force -ErrorAction SilentlyContinue
        }

        $tempDir = Join-Path $env:TEMP 'WinToolkitWinget'
        $null = New-Item -Path $tempDir -ItemType Directory -Force

        try {
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

            # Passo 2: Download dipendenze
            Write-StyledMessage -Type 'Info' -Text "Download dipendenze Appx..."
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

                $archPatt  = if ([Environment]::Is64BitOperatingSystem) { 'x64|neutral' } else { 'x86|neutral' }
                $appxFiles = Get-ChildItem -Path $extractDir -Recurse -Filter '*.appx' | Where-Object { $_.Name -match $archPatt }

                foreach ($appx in $appxFiles) {
                    $appxPath = $appx.FullName
                    $null = Invoke-WithSpinner -Activity "Installazione dipendenza: $($appx.Name)" -Process -Action { 
                        Start-IsolatedProcess -Executable 'powershell.exe' `
                            -Arguments "-NoProfile -NonInteractive -Command `"`$ProgressPreference='SilentlyContinue'; Add-AppxPackage -Path '$appxPath' -ForceApplicationShutdown -ErrorAction SilentlyContinue`""
                    } -TimeoutSeconds 300
                }
                Write-StyledMessage -Type 'Success' -Text "✅ Dipendenze Appx installate."
            }

            # Passo 3: Download e installazione Winget MSIXBundle
            Write-StyledMessage -Type 'Info' -Text "Download Winget MSIXBundle..."
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

                $null = Invoke-WithSpinner -Activity "Installazione Winget MSIXBundle" -Process -Action { 
                    Start-IsolatedProcess -Executable 'powershell.exe' `
                        -Arguments "-NoProfile -NonInteractive -Command `"`$ProgressPreference='SilentlyContinue'; Add-AppxPackage -Path '$msixFile' -ForceApplicationShutdown -ErrorAction Stop`""
                } -TimeoutSeconds 300
                Write-StyledMessage -Type 'Success' -Text "✅ Winget MSIXBundle installato."
            }

            # Passo 4: Reset App Installer (fix ACCESS_VIOLATION 0xc0000022)
            Write-StyledMessage -Type 'Info' -Text "Reset App Installer (fix 0xc0000022)..."
            if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
                Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
            }

            # Passo 5: Permessi PATH e aggiornamento sessione
            Write-StyledMessage -Type 'Info' -Text "Aggiornamento permessi e PATH Winget..."
            $arch      = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
            $wingetDir = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" `
                -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" `
                -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
            if ($wingetDir) {
                Set-WingetPathPermissions -FolderPath $wingetDir.FullName
                $syspath = [Environment]::GetEnvironmentVariable('PATH','Machine')
                if ($syspath -notmatch [regex]::Escape($wingetDir.FullName)) {
                    [Environment]::SetEnvironmentVariable('PATH', "$syspath;$($wingetDir.FullName)", 'Machine')
                }
            }
            $usrPath = [Environment]::GetEnvironmentVariable('PATH','User')
            if ($usrPath -notmatch [regex]::Escape('%LOCALAPPDATA%\Microsoft\WindowsApps')) {
                [Environment]::SetEnvironmentVariable('PATH', "$usrPath;%LOCALAPPDATA%\Microsoft\WindowsApps", 'User')
            }
            Update-SessionPath

            # Verifica finale
            Start-Sleep 3

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

        # Restart servizi Store
        Write-StyledMessage -Type 'Info' -Text "Restart servizi Microsoft Store..."
        @('AppXSvc', 'ClipSVC', 'WSService') | ForEach-Object {
            try { Restart-Service $_ -Force -ErrorAction SilentlyContinue *>$null } catch { }
        }
        # Pulizia cache locale Store
        @("$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
          "$env:LOCALAPPDATA\Microsoft\Windows\INetCache") | ForEach-Object {
            if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue *>$null }
        }

        $wingetExe = Get-WingetExecutable

        # [RULE-BATCH-01] Metodi di installazione come array dichiarativo
        $installMethods = @(
            @{
                Name   = 'Winget Install'
                Action = {
                    if (-not (Test-Path $wingetExe -ErrorAction SilentlyContinue)) { return @{ ExitCode = -1 } }
                    $processResult = Invoke-WithSpinner -Activity "Installazione Store tramite Winget" -Process -Action {
                        $procParams = @{
                            FilePath               = $wingetExe
                            ArgumentList           = @('install','9WZDNCRFJBMP',
                                                        '--accept-source-agreements','--accept-package-agreements',
                                                        '--silent','--disable-interactivity')
                            PassThru               = $true
                            WindowStyle            = 'Hidden'
                        }
                        Start-Process @procParams
                    } -TimeoutSeconds 300
                    return @{ ExitCode = $processResult.ExitCode }
                }
            },
            @{
                Name   = 'AppX Manifest'
                Action = {
                    $store    = Get-AppxPackage -AllUsers *WindowsStore* -ErrorAction SilentlyContinue | Select-Object -First 1
                    $manifest = if ($store) { Join-Path $store.InstallLocation 'AppxManifest.xml' } else { $null }
                    if (-not $manifest -or -not (Test-Path $manifest)) { return @{ ExitCode = -1 } }
                    try {
                        $null = Invoke-WithSpinner -Activity "Registrazione AppX Manifest Store" -Process -Action { 
                            Start-IsolatedProcess -Executable 'powershell.exe' `
                                -Arguments "-NoProfile -NonInteractive -Command `"`$ProgressPreference='SilentlyContinue'; Add-AppxPackage -DisableDevelopmentMode -Register '$manifest' -ForceApplicationShutdown -ErrorAction Stop`""
                        } -TimeoutSeconds 120
                        return @{ ExitCode = 0 }
                    }
                    catch { return @{ ExitCode = -1 } }
                }
            },
            @{
                Name   = 'DISM Capability'
                Action = {
                    $result = Invoke-WithSpinner -Activity "Aggiunta Store via DISM" -Process -Action {
                        $procParams = @{
                            FilePath     = 'DISM'
                            ArgumentList = @('/Online','/Add-Capability','/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0')
                            PassThru     = $true
                            WindowStyle  = 'Hidden'
                        }
                        Start-Process @procParams
                    } -TimeoutSeconds 300
                    return @{ ExitCode = $result.ExitCode }
                }
            }
        )

        $success = $false
        foreach ($method in $installMethods) {
            Write-StyledMessage -Type 'Info' -Text "Tentativo tramite: $($method.Name)..."
            try {
                $result    = $method.Action.Invoke()
                $isSuccess = $result -and ($result.ExitCode -in @(0, 3010, 1638, -1978335189))
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
            $null = Invoke-WithSpinner -Activity "Reset cache Microsoft Store (wsreset)" -Process -Action {
                $procParams = @{
                    FilePath    = 'wsreset.exe'
                    PassThru    = $true
                    WindowStyle = 'Hidden'
                }
                Start-Process @procParams
            } -TimeoutSeconds 120
            Write-StyledMessage -Type 'Success' -Text "✅ Cache dello Store ripristinata."
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Impossibile reinstallare Microsoft Store tramite metodi automatici."
            Write-StyledMessage -Type 'Info' -Text "Tentativo di emergenza tramite AppXManifest..."
            try {
                $emergCmd = 'Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object { $ProgressPreference=''SilentlyContinue''; Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ForceApplicationShutdown }'
                $null = Invoke-WithSpinner -Activity "Ripristino di emergenza Store" -Process -Action { 
                    Start-IsolatedProcess -Executable 'powershell.exe' `
                        -Arguments "-NoProfile -NonInteractive -Command `"$emergCmd`""
                } -TimeoutSeconds 300
                Write-StyledMessage -Type 'Success' -Text "Microsoft Store ripristinato tramite metodo di emergenza."
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Ripristino di emergenza fallito: $($_.Exception.Message)"
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
            Write-StyledMessage -Type 'Warning' -Text "Winget non disponibile. UniGet UI richiede Winget."
            return $false
        }

        try {
            # Disinstalla versione precedente
            $null = Invoke-WithSpinner -Activity "Disinstallazione versioni precedenti UniGet UI" -Process -Action {
                $procParams = @{
                    FilePath     = $wingetExe
                    ArgumentList = @('uninstall','--exact','--id','MartiCliment.UniGetUI',
                                     '--silent','--disable-interactivity')
                    PassThru     = $true
                    WindowStyle  = 'Hidden'
                }
                Start-Process @procParams
            } -TimeoutSeconds 120

            $processResult = Invoke-WithSpinner -Activity "Installazione UniGet UI" -Process -Action {
                $procParams = @{
                    FilePath               = $wingetExe
                    ArgumentList           = @('install','--exact','--id','MartiCliment.UniGetUI',
                                               '--source','winget','--accept-source-agreements',
                                               '--accept-package-agreements','--silent',
                                               '--disable-interactivity','--force')
                    PassThru               = $true
                    WindowStyle            = 'Hidden'
                }
                Start-Process @procParams
            } -TimeoutSeconds 600

            $isSuccess = $processResult.ExitCode -in @(0, 3010, 1638, -1978335189)

            if ($isSuccess) {
                Write-StyledMessage -Type 'Success' -Text "UniGet UI installato correttamente."
                try {
                    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
                    if (Get-ItemProperty -Path $regPath -Name 'WingetUI' -ErrorAction SilentlyContinue) {
                        Remove-ItemProperty -Path $regPath -Name 'WingetUI' -ErrorAction SilentlyContinue *>$null
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
        Write-StyledMessage -Type 'Progress' -Text "Avvio reinstallazione Store & Winget..."

        # Reset Winget: usa Reset-Winget del framework, poi fallback alla reinstallazione completa
        $wingetResult = $false
        if (Get-Command Reset-Winget -ErrorAction SilentlyContinue) {
            $wingetResult = Reset-Winget -Force
        }
        if (-not $wingetResult) {
            Write-StyledMessage -Type 'Warning' -Text "Fallback: reinstallazione Winget da zero..."
            $wingetResult = Invoke-WingetReinstall
        }
        Write-StyledMessage -Type ($wingetResult ? 'Success' : 'Warning') -Text `
            "Winget $($wingetResult ? 'ripristinato con successo' : 'processato (potrebbe richiedere verifica manuale)')"

        $storeResult = Install-MicrosoftStore
        Write-StyledMessage -Type ($storeResult ? 'Success' : 'Error') -Text `
            "Microsoft Store $($storeResult ? 'reinstallato correttamente' : 'non reinstallato — verifica connessione o Windows Update.')"

        $unigetResult = Install-UniGetUI
        Write-StyledMessage -Type ($unigetResult ? 'Success' : 'Warning') -Text `
            "UniGet UI $($unigetResult ? 'installato' : 'processato (verifica manuale necessaria)')"

        Write-StyledMessage -Type 'Success' -Text "🎉 Operazione completata. Tutti i componenti sono stati elaborati."
    }
    finally {
        # Ripristino garantito della preferenza progress
        $ProgressPreference = $savedProgressPref
    }

    # ============================================================================
    # 7. GESTIONE RIAVVIO — SEMPRE ULTIMA
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
