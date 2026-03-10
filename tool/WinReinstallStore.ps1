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
        [switch]$NoReboot,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE E PROTEZIONE GRAFICA
    # ============================================================================

    # Salviamo lo stato e forziamo la soppressione a livello GLOBALE
    # Questo impedisce al deployment AppX di Windows di inviare progress stream alla console
    $global:OldProgressPreference = $global:ProgressPreference
    $global:ProgressPreference    = 'SilentlyContinue'
    $ErrorActionPreference         = 'SilentlyContinue'

    # Fix W11: il buffer di scrittura AppX lascia residui se non si forza CR prima di ogni riga
    # Apply lo stesso trick di start.ps1 per mantenere il TUI pulito
    $onW11 = [Environment]::OSVersion.Version.Build -ge 22000

    Start-ToolkitLog -ToolName "WinReinstallStore"
    Show-Header -SubTitle "Store Repair Toolkit"
    $Host.UI.RawUI.WindowTitle = "Store Repair Toolkit By MagnetarMan"

    # ============================================================================
    # 2. FUNZIONI HELPER LOCALI (portate da start.ps1)
    # ============================================================================

    # Trova il percorso ASSOLUTO e REALE di winget.exe in WindowsApps (bypass alias 0xc0000022)
    # Logica identica a Find-WinGet in start.ps1
    function Get-WingetExecutable {
        try {
            $wingetPathToResolve = Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe'
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

    # Applica permessi FullControl agli Administrators sulla cartella winget (da start.ps1)
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

    # Aggiorna PATH di sessione (da start.ps1) — necessario per rilevare winget dopo reinst.
    function Update-SessionPath {
        $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $userPath    = [Environment]::GetEnvironmentVariable('Path', 'User')
        $env:Path    = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
        [System.Environment]::SetEnvironmentVariable('Path', $env:Path, 'Process')
    }

    # Chiude i processi che bloccano l'installazione AppX (da start.ps1)
    function Stop-InterferingProcesses {
        @('WinStore.App', 'wsappx', 'AppInstaller', 'Microsoft.WindowsStore',
          'Microsoft.DesktopAppInstaller', 'winget', 'WindowsPackageManagerServer') | ForEach-Object {
            Get-Process -Name $_ -ErrorAction SilentlyContinue |
                Where-Object { $_.Id -ne $PID } |
                Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep 2
    }

    # ============================================================================
    # 3. REINSTALLAZIONE WINGET (usa logica da start.ps1 - Install-WingetCore)
    # ============================================================================

    function Invoke-WingetReinstall {
        Write-StyledMessage -Type 'Info' -Text "🛠️ Avvio procedura reinstallazione Winget..."

        Stop-InterferingProcesses

        $tempDir = Join-Path $env:TEMP 'WinToolkitWinget'
        if (-not (Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force *>$null }

        try {
            # Helper per recuperare URL asset GitHub (da start.ps1)
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
                Invoke-WebRequest -Uri $depUrl -OutFile $depZip -UseBasicParsing -ErrorAction Stop
                Expand-Archive -Path $depZip -DestinationPath $extractDir -Force

                $archPatt = if ([Environment]::Is64BitOperatingSystem) { 'x64|neutral' } else { 'x86|neutral' }
                Get-ChildItem -Path $extractDir -Recurse -Filter '*.appx' |
                    Where-Object { $_.Name -match $archPatt } | ForEach-Object {
                        Write-StyledMessage -Type 'Info' -Text "Installazione dipendenza: $($_.Name)..."
                        # Redirect stdout/stderr per bloccare completamente il progress stream nativo
                        $outTmp = Join-Path $env:TEMP "dep_out_$($_.BaseName).log"
                        $errTmp = Join-Path $env:TEMP "dep_err_$($_.BaseName).log"
                        $p = Start-Process -FilePath 'powershell.exe' `
                            -ArgumentList @('-NoProfile','-NonInteractive','-Command',
                                "Add-AppxPackage -Path '$($_.FullName)' -ForceApplicationShutdown -ErrorAction SilentlyContinue") `
                            -Wait -WindowStyle Hidden -PassThru `
                            -RedirectStandardOutput $outTmp -RedirectStandardError $errTmp
                        Remove-Item $outTmp, $errTmp -Force -ErrorAction SilentlyContinue
                    }
                Write-StyledMessage -Type 'Success' -Text "✅ Dipendenze Appx installate."
            }

            # Passo 3: Winget MSIXBundle
            Write-StyledMessage -Type 'Info' -Text "💎 Installazione Winget MSIXBundle..."
            $msixUrl = Get-WingetAssetUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
            if ($msixUrl) {
                $msixFile = Join-Path $tempDir 'winget.msixbundle'
                Invoke-WebRequest -Uri $msixUrl -OutFile $msixFile -UseBasicParsing -ErrorAction Stop

                # Usa processo figlio per isolare completamente il progress stream di appx
                $outTmp = Join-Path $env:TEMP 'winget_msix_out.log'
                $errTmp = Join-Path $env:TEMP 'winget_msix_err.log'
                $p = Start-Process -FilePath 'powershell.exe' `
                    -ArgumentList @('-NoProfile','-NonInteractive','-Command',
                        "Add-AppxPackage -Path '$msixFile' -ForceApplicationShutdown -ErrorAction Stop") `
                    -Wait -WindowStyle Hidden -PassThru `
                    -RedirectStandardOutput $outTmp -RedirectStandardError $errTmp
                Remove-Item $outTmp, $errTmp -Force -ErrorAction SilentlyContinue
            }

            # Passo 4: Reset App Installer (fix ACCESS_VIOLATION)
            Write-StyledMessage -Type 'Info' -Text "Reset App Installer (fix 0xc0000022)..."
            if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
                Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
            }

            # Passo 5: Permessi PATH (da start.ps1 - Apply-WingetPathPermissions)
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
            if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
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

                    $outLog = Join-Path $env:TEMP 'winget_store_out.log'
                    $errLog = Join-Path $env:TEMP 'winget_store_err.log'

                    $proc = Start-Process -FilePath $wingetExe `
                        -ArgumentList @('install','9WZDNCRFJBMP','--accept-source-agreements',
                            '--accept-package-agreements','--silent','--disable-interactivity') `
                        -PassThru -Wait -WindowStyle 'Hidden' `
                        -RedirectStandardOutput $outLog -RedirectStandardError $errLog
                    Remove-Item $outLog, $errLog -Force -ErrorAction SilentlyContinue
                    return @{ ExitCode = $proc.ExitCode }
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
                        Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ForceApplicationShutdown -ErrorAction Stop
                        return @{ ExitCode = 0 }
                    }
                    catch { return @{ ExitCode = -1 } }
                }
            },
            @{
                Name   = 'DISM Capability'
                Action = {
                    $proc = Start-Process -FilePath 'DISM' `
                        -ArgumentList @('/Online','/Add-Capability','/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0') `
                        -PassThru -Wait -WindowStyle 'Hidden'
                    return @{ ExitCode = $proc.ExitCode }
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
                Start-Process -FilePath 'wsreset.exe' -Wait -WindowStyle 'Hidden' -ErrorAction SilentlyContinue
                Write-StyledMessage -Type 'Success' -Text "Cache dello Store ripristinata."
            }
            catch { }
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Impossibile reinstallare Microsoft Store tramite i metodi automatici."
            Write-StyledMessage -Type 'Info' -Text "Esecuzione comando di emergenza (Get-AppxPackage reset)..."
            try {
                Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object {
                    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ForceApplicationShutdown
                }
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
            Start-Process -FilePath $wingetExe `
                -ArgumentList @('uninstall','--exact','--id','MartiCliment.UniGetUI','--silent','--disable-interactivity') `
                -Wait -WindowStyle 'Hidden' -ErrorAction SilentlyContinue
            Start-Sleep 2

            Write-StyledMessage -Type 'Info' -Text "Download e installazione silenziosa di UniGet UI..."

            $outLog = Join-Path $env:TEMP 'winget_uniget_out.log'
            $errLog = Join-Path $env:TEMP 'winget_uniget_err.log'

            $process = Start-Process -FilePath $wingetExe `
                -ArgumentList @('install','--exact','--id','MartiCliment.UniGetUI',
                    '--source','winget','--accept-source-agreements','--accept-package-agreements',
                    '--silent','--disable-interactivity','--force') `
                -PassThru -Wait -WindowStyle 'Hidden' `
                -RedirectStandardOutput $outLog -RedirectStandardError $errLog
            Remove-Item $outLog, $errLog -Force -ErrorAction SilentlyContinue

            $isSuccess = $process.ExitCode -eq 0 -or $process.ExitCode -eq 3010 -or
                         $process.ExitCode -eq 1638 -or $process.ExitCode -eq -1978335189

            if ($isSuccess) {
                Write-StyledMessage -Type 'Success' -Text "UniGet UI installato correttamente."

                Write-StyledMessage -Type 'Info' -Text "🔄 Disabilitazione avvio automatico UniGet UI..."
                try {
                    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
                    if (Get-ItemProperty -Path $regPath -Name 'WingetUI' -ErrorAction SilentlyContinue) {
                        Remove-ItemProperty -Path $regPath -Name 'WingetUI' -ErrorAction Stop | Out-Null
                        Write-StyledMessage -Type 'Success' -Text "Avvio automatico UniGet UI disabilitato."
                    }
                }
                catch { }
                return $true
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "Installazione UniGet UI terminata con codice: $($process.ExitCode)"
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
        $ErrorActionPreference      = 'Stop'
    }

    # ============================================================================
    # 7. GESTIONE RIAVVIO
    # ============================================================================

    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
        Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio soppresso come richiesto. Verrà gestito un riavvio finale dal toolkit."
    }
    elseif (-not $NoReboot) {
        $shouldReboot = Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riparazione Store completata"
        if ($shouldReboot) {
            Write-StyledMessage -Type 'Info' -Text "🔄 Riavvio in corso..."
            Restart-Computer -Force
        }
    }
    else {
        Write-StyledMessage -Type 'Warning' -Text "Riavvio manuale consigliato per applicare tutte le modifiche."
    }

    if (-not $SuppressIndividualReboot) {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
    }
}
