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
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName "WinReinstallStore"
    Show-Header -SubTitle "Store Repair Toolkit"

    # ============================================================================
    # 2. FUNZIONI HELPER LOCALI (Microsoft Store & UniGet UI)
    # ============================================================================

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
            }
        )

        $success = $false
        foreach ($method in $installMethods) {
            Write-StyledMessage -Type 'Info' -Text "Tentativo tramite: $($method.Name)..."
            
            try {
                $processResult = $method.Action.Invoke()
                if ($processResult -and $processResult.ExitCode -eq 0) {
                    Write-StyledMessage -Type 'Success' -Text "Microsoft Store reinstallato tramite $($method.Name)."
                    $success = $true
                    break
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Metodo $($method.Name) fallito: $($_.Exception.Message)"
            }
        }

        if (-not $success) {
            Write-StyledMessage -Type 'Error' -Text "Impossibile reinstallare Microsoft Store tramite i metodi automatici."
            Write-StyledMessage -Type 'Info' -Text "Esecuzione comando di emergenza (Get-AppxPackage reset)..."
            try {
                Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object { Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ForceApplicationShutdown }
                Write-StyledMessage -Type 'Success' -Text "Microsoft Store ripristinato tramite comando di emergenza."
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Comando di emergenza fallito."
            }
        }
    }

    function Install-UniGetUI {
        Write-StyledMessage -Type 'Info' -Text "🔄 Installazione UniGet UI (WinGetUI)..."

        $isWingetReady = [bool](Get-Command winget -ErrorAction SilentlyContinue)
        if (-not $isWingetReady) {
            Write-StyledMessage -Type 'Warning' -Text "Winget non disponibile. UniGet UI richiede Winget."
            return
        }

        try {
            # Verifica se è già installato
            $existing = & winget list --id SomePythonThing.WinGetUI --accept-source-agreements 2>$null
            if ($existing -match "SomePythonThing.WinGetUI") {
                Write-StyledMessage -Type 'Success' -Text "UniGet UI già presente nel sistema."
                return
            }

            Write-StyledMessage -Type 'Info' -Text "Download e installazione silenziosa di UniGet UI..."
            $procParams = @{
                FilePath     = 'winget'
                ArgumentList = @('install', '--id', 'SomePythonThing.WinGetUI', '--silent',
                    '--accept-package-agreements', '--accept-source-agreements')
                PassThru     = $true
                WindowStyle  = 'Hidden'
            }
            $process = Start-Process @procParams
            $process.WaitForExit()

            if ($process.ExitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "UniGet UI installato correttamente."
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "Installazione UniGet UI terminata con codice: $($process.ExitCode)"
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante installazione UniGet UI: $($_.Exception.Message)"
        }
    }

    # ============================================================================
    # 3. ESECUZIONE PRINCIPALE
    # ============================================================================

    Write-StyledMessage -Type 'Info' -Text "Inizio procedura di ripristino Store & Winget..."
    
    # Step 1: Reset Winget (Funzione Core)
    $wingetResult = Reset-Winget -Force
    
    if ($wingetResult) {
        # Step 2: Install Microsoft Store
        Install-MicrosoftStore
        
        # Step 3: Install UniGet UI
        Install-UniGetUI
        
        Write-Host ""
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-StyledMessage -Type 'Success' -Text "Procedura di ripristino completata con successo!"
        Write-StyledMessage -Type 'Info' -Text "Tutti i componenti (Winget, Store, UniGet UI) sono stati elaborati."
        Write-Host ('═' * 80) -ForegroundColor Green
    }
    else {
        Write-StyledMessage -Type 'Error' -Text "La riparazione di Winget è fallita. Impossibile procedere con Store e UniGet UI."
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
}
