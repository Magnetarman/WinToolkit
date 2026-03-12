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
    $savedProgressPref = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    # ============================================================================
    # FUNZIONI HELPER LOCALI
    # ============================================================================

    # Trova il percorso ASSOLUTO di winget.exe in WindowsApps (bypass alias 0xc0000022)
    function Get-WingetExecutable {
        # Priorità 1: Alias di esecuzione (localappdata) -> Evita "Accesso Negato" di WindowsApps
        $aliasPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
        if (Test-Path $aliasPath) { return $aliasPath }

        # Priorità 2: Percorso reale in WindowsApps (fallback se alias rotto)
        try {
            $windowsApps = Join-Path $env:ProgramFiles "WindowsApps"
            $wingetGlob = Join-Path $windowsApps "Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe"
            $resolvedPaths = Resolve-Path -Path $wingetGlob -ErrorAction SilentlyContinue | Sort-Object {
                $leaf = Split-Path $_.Path -Leaf
                [version]($leaf -replace '^[^\d]+_((\d+\.)*\d+)_.*', '$1')
            }
            if ($resolvedPaths) {
                $exePath = Join-Path $resolvedPaths[-1].Path 'winget.exe'
                if (Test-Path $exePath) { return $exePath }
            }
        }
        catch { }

        return "winget" # Speranza finale (PATH)
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
        @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
            (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\INetCache")
        ) | ForEach-Object {
            if (Test-Path $_) { 
                $ProgressPreference = 'SilentlyContinue'
                Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue *>$null 
            }
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
                            FilePath     = $wingetExe
                            ArgumentList = @('install', '9WZDNCRFJBMP',
                                '--accept-source-agreements', '--accept-package-agreements',
                                '--silent', '--disable-interactivity')
                            PassThru     = $true
                            WindowStyle  = 'Hidden'
                        }
                        Start-Process @procParams
                    } -TimeoutSeconds 300
                    return @{ ExitCode = $processResult.ExitCode }
                }
            },
            @{
                Name   = 'AppX Manifest'
                Action = {
                    $store = Get-AppxPackage -AllUsers *WindowsStore* -ErrorAction SilentlyContinue | Select-Object -First 1
                    $manifest = if ($store) { Join-Path $store.InstallLocation 'AppxManifest.xml' } else { $null }
                    if (-not $manifest -or -not (Test-Path $manifest)) { return @{ ExitCode = -1 } }
                    
                    $procResult = Invoke-WithSpinner -Activity "Registrazione AppX Manifest Store" -Process -Action {
                        Start-AppxSilentProcess -AppxPath $manifest -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown'
                    } -TimeoutSeconds 120
                    
                    return @{ ExitCode = $procResult.ExitCode }
                }
            },
            @{
                Name   = 'DISM Capability'
                Action = {
                    $result = Invoke-WithSpinner -Activity "Aggiunta Store via DISM" -Process -Action {
                        $procParams = @{
                            FilePath     = 'DISM'
                            ArgumentList = @('/Online', '/Add-Capability', '/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0')
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
                $result = $method.Action.Invoke()
                $isSuccess = $result -and ($result.ExitCode -in @(0, 3010, 1638, -1978335189))
                if ($isSuccess) {
                    Write-StyledMessage -Type 'Success' -Text "Microsoft Store reinstallato tramite $($method.Name)."
                    $success = $true
                    break
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "Metodo $($method.Name) non riuscito (ExitCode: $(if ($result.ExitCode) { $result.ExitCode } else { 'N/A' }))."
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
                $null = Invoke-WithSpinner -Activity "Ripristino di emergenza Store" -Process -Action {
                    $ProgressPreference = 'SilentlyContinue'
                    Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object {
                        Start-AppxSilentProcess -AppxPath "$($_.InstallLocation)\AppXManifest.xml" -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown'
                    }
                } -TimeoutSeconds 300
                Write-StyledMessage -Type 'Success' -Text "Microsoft Store ripristinato tramite metodo di emergenza."
                $success = $true
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
                    ArgumentList = @('uninstall', '--exact', '--id', 'MartiCliment.UniGetUI',
                        '--silent', '--disable-interactivity')
                    PassThru     = $true
                    WindowStyle  = 'Hidden'
                }
                Start-Process @procParams
            } -TimeoutSeconds 120

            $processResult = Invoke-WithSpinner -Activity "Installazione UniGet UI" -Process -Action {
                $procParams = @{
                    FilePath     = $wingetExe
                    ArgumentList = @('install', '--exact', '--id', 'MartiCliment.UniGetUI',
                        '--source', 'winget', '--accept-source-agreements',
                        '--accept-package-agreements', '--silent',
                        '--disable-interactivity', '--force')
                    PassThru     = $true
                    WindowStyle  = 'Hidden'
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

        # Utilizza la funzione Reset-Winget dal template per la riparazione di Winget
        $wingetResult = Reset-Winget -Force
        
        $msgWinget = $wingetResult ? 'ripristinato con successo' : 'processato (potrebbe richiedere verifica manuale)'
        Write-StyledMessage -Type ($wingetResult ? 'Success' : 'Warning') -Text "Winget $msgWinget"

        $storeResult = Install-MicrosoftStore
        if ($storeResult) {
            Write-StyledMessage -Type 'Success' -Text "✅ Microsoft Store ripristinato correttamente."
        } else {
            Write-StyledMessage -Type 'Error' -Text "❌ Microsoft Store non ripristinato — verifica manuale necessaria."
        }

        $unigetResult = Install-UniGetUI
        if ($unigetResult) {
            Write-StyledMessage -Type 'Success' -Text "✅ UniGet UI installato con successo."
        } else {
            Write-StyledMessage -Type 'Warning' -Text "⚠️ UniGet UI processato con avvisi (verifica manuale)."
        }

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
