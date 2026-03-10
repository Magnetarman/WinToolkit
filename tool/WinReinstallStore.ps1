function WinReinstallStore {
<#
.SYNOPSIS
    Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget.
.DESCRIPTION
    Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI.
    Utilizza la funzione centralizzata Reset-Winget del framework.
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
    
    # Salviamo lo stato e forziamo la soppressione a livello GLOBALE per bloccare le UI AppX
    $global:OldProgressPreference = $global:ProgressPreference
    $global:ProgressPreference = 'SilentlyContinue'
    $ErrorActionPreference = 'SilentlyContinue'

    Start-ToolkitLog -ToolName "WinReinstallStore"
    Show-Header -SubTitle "Store Repair Toolkit"
    $Host.UI.RawUI.WindowTitle = "Store Repair Toolkit By MagnetarMan"

    # ============================================================================
    # 2. FUNZIONI HELPER LOCALI
    # ============================================================================

    # Helper per bypassare l'Errore 0xc0000022 risolvendo il percorso assoluto
    function Get-WingetExecutable {
        $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
        $wingetDir = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        
        if ($wingetDir) {
            $exePath = Join-Path $wingetDir.FullName "winget.exe"
            if (Test-Path $exePath) { return $exePath }
        }
        # Fallback all'alias
        return "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    }

    function Install-MicrosoftStore {
        Write-StyledMessage -Type 'Info' -Text "🔄 Reinstallazione Microsoft Store in corso..."

        # Restart servizi
        @("AppXSvc", "ClipSVC", "WSService") | ForEach-Object {
            try { Restart-Service $_ -Force -ErrorAction SilentlyContinue *>$null } catch {}
        }

        # Pulizia cache
        @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
        ) | ForEach-Object {
            if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue *>$null }
        }

        $wingetExe = Get-WingetExecutable

        $installMethods = @(
            @{
                Name   = "Winget Install"
                Action = {
                    if (-not (Test-Path $wingetExe -ErrorAction SilentlyContinue)) { return @{ ExitCode = -1 } }

                    # Redirezione I/O per prevenire leak grafici
                    $outLog = Join-Path $env:TEMP "winget_store_out.log"
                    $errLog = Join-Path $env:TEMP "winget_store_err.log"

                    $procParams = @{
                        FilePath               = $wingetExe
                        ArgumentList           = @('install', '9WZDNCRFJBMP', '--accept-source-agreements', '--accept-package-agreements', '--silent', '--disable-interactivity')
                        PassThru               = $true
                        Wait                   = $true
                        WindowStyle            = 'Hidden'
                        RedirectStandardOutput = $outLog
                        RedirectStandardError  = $errLog
                    }
                    $proc = Start-Process @procParams
                    return @{ ExitCode = $proc.ExitCode }
                }
            },
            @{
                Name   = "AppX Manifest"
                Action = {
                    $store = Get-AppxPackage -AllUsers *WindowsStore* -ErrorAction SilentlyContinue | Select-Object -First 1
                    if (-not $store -or -not $store.InstallLocation) { return @{ ExitCode = -1 } }

                    $manifest = Join-Path $store.InstallLocation "AppxManifest.xml"
                    if (-not (Test-Path $manifest)) { return @{ ExitCode = -1 } }

                    try {
                        Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ForceApplicationShutdown -ErrorAction Stop
                        return @{ ExitCode = 0 }
                    }
                    catch {
                        return @{ ExitCode = -1 }
                    }
                }
            },
            @{
                Name   = "DISM Capability"
                Action = {
                    $procParams = @{
                        FilePath     = 'DISM'
                        ArgumentList = @('/Online', '/Add-Capability', '/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0')
                        PassThru     = $true
                        Wait         = $true
                        WindowStyle  = 'Hidden'
                    }
                    $proc = Start-Process @procParams
                    return @{ ExitCode = $proc.ExitCode }
                }
            }
        )

        $success = $false
        foreach ($method in $installMethods) {
            Write-StyledMessage -Type 'Info' -Text "Tentativo tramite: $($method.Name)..."

            try {
                $processResult = $method.Action.Invoke()
                $isSuccess = $processResult -and (
                    $processResult.ExitCode -eq 0 -or
                    $processResult.ExitCode -eq 3010 -or
                    $processResult.ExitCode -eq 1638 -or
                    $processResult.ExitCode -eq -1978335189
                )

                if ($isSuccess) {
                    Write-StyledMessage -Type 'Success' -Text "Microsoft Store reinstallato tramite $($method.Name)."
                    $success = $true
                    break
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "Metodo $($method.Name) non riuscito (ExitCode: $($processResult.ExitCode ?? 'N/A'))."
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
            } catch {}
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

    function Install-UniGetUI {
        Write-StyledMessage -Type 'Info' -Text "🔄 Installazione UniGet UI..."

        $wingetExe = Get-WingetExecutable
        if (-not (Test-Path $wingetExe -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Warning' -Text "Winget non disponibile o percorso inaccessibile. UniGet UI richiede Winget."
            return $false
        }

        try {
            # Disinstalla versione precedente
            Start-Process -FilePath $wingetExe -ArgumentList @('uninstall', '--exact', '--id', 'MartiCliment.UniGetUI', '--silent', '--disable-interactivity') -Wait -WindowStyle 'Hidden' -ErrorAction SilentlyContinue
            Start-Sleep 2

            Write-StyledMessage -Type 'Info' -Text "Download e installazione silenziosa di UniGet UI..."
            
            $outLog = Join-Path $env:TEMP "winget_uniget_out.log"
            $errLog = Join-Path $env:TEMP "winget_uniget_err.log"

            $procParams = @{
                FilePath               = $wingetExe
                ArgumentList           = @('install', '--exact', '--id', 'MartiCliment.UniGetUI', '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements', '--silent', '--disable-interactivity', '--force')
                PassThru               = $true
                Wait                   = $true
                WindowStyle            = 'Hidden'
                RedirectStandardOutput = $outLog
                RedirectStandardError  = $errLog
            }
            $process = Start-Process @procParams

            $isSuccess = $process.ExitCode -eq 0 -or $process.ExitCode -eq 3010 -or $process.ExitCode -eq 1638 -or $process.ExitCode -eq -1978335189

            if ($isSuccess) {
                Write-StyledMessage -Type 'Success' -Text "UniGet UI installato correttamente."

                Write-StyledMessage -Type 'Info' -Text "🔄 Disabilitazione avvio automatico UniGet UI..."
                try {
                    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                    $regKeyName = "WingetUI"
                    if (Get-ItemProperty -Path $regPath -Name $regKeyName -ErrorAction SilentlyContinue) {
                        Remove-ItemProperty -Path $regPath -Name $regKeyName -ErrorAction Stop | Out-Null
                        Write-StyledMessage -Type 'Success' -Text "Avvio automatico UniGet UI disabilitato."
                    }
                }
                catch {}
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
    # 3. ESECUZIONE PRINCIPALE
    # ============================================================================
    try {
        Write-StyledMessage -Type 'Info' -Text "🚀 AVVIO REINSTALLAZIONE STORE"
        Write-StyledMessage -Type 'Info' -Text "Inizio procedura di ripristino Store & Winget..."

        $wingetResult = Reset-Winget -Force
        Write-StyledMessage -Type $(if ($wingetResult) { 'Success' } else { 'Warning' }) -Text "Winget $(if ($wingetResult) { 'ripristinato con successo' } else { 'processato (potrebbe richiedere verifica manuale)' })"

        $storeResult = Install-MicrosoftStore
        if (-not $storeResult) {
            Write-StyledMessage -Type 'Error' -Text "Errore installazione Microsoft Store. Verifica connessione o Windows Update."
        }
        else {
            Write-StyledMessage -Type 'Success' -Text "Microsoft Store installato"
        }

        $unigetResult = Install-UniGetUI
        Write-StyledMessage -Type $(if ($unigetResult) { 'Success' } else { 'Warning' }) -Text "UniGet UI $(if ($unigetResult) { 'installato' } else { 'processato (verifica manuale necessaria)' })"

        Write-Host ""
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-StyledMessage -Type 'Success' -Text "🎉 OPERAZIONE COMPLETATA"
        Write-StyledMessage -Type 'Info' -Text "Tutti i componenti (Winget, Store, UniGet UI) sono stati elaborati."
        Write-Host ('═' * 80) -ForegroundColor Green

    } finally {
        # Ripristina lo stato grafico di PowerShell
        $global:ProgressPreference = $global:OldProgressPreference
        $ErrorActionPreference = 'Stop'
    }

    # ============================================================================
    # 4. GESTIONE RIAVVIO
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
