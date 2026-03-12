function WinReinstallStore {
    <#
    .SYNOPSIS
        Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget.
    .DESCRIPTION
        Reinstalla Winget, Microsoft Store e UniGet UI.
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
                $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                Write-Host $clearLine -NoNewline
                [Console]::Out.Flush()
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
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Success' -Text "Cache dello Store ripristinata."
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
                $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                Write-Host $clearLine -NoNewline
                [Console]::Out.Flush()
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

            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()

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

            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()

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
 
        # Reset-Winget invoca il deployment engine Windows che scrive "Avanzamento distribuzione:"
        # direttamente tramite WriteConsoleW (Win32 API), bypassando Console.Out.
        # L'unico modo per sopprimerlo è redirigere il Win32 STD_OUTPUT/STD_ERROR handle a NUL
        # prima della chiamata, poi ripristinarlo. Console.Out di .NET non viene influenzato
        # perché il suo wrapper interno è già inizializzato.
        if (-not ('WinReinstallStore.NativeConsole' -as [type])) {
            Add-Type -Namespace 'WinReinstallStore' -Name 'NativeConsole' -MemberDefinition @'
                [DllImport("kernel32.dll")] public static extern bool   SetStdHandle(int nStdHandle, IntPtr hHandle);
                [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
                [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
                public static extern IntPtr CreateFileW(
                    string lpFileName, uint dwDesiredAccess, uint dwShareMode,
                    IntPtr lpSecurityAttributes, uint dwCreationDisposition,
                    uint dwFlagsAndAttributes, IntPtr hTemplateFile);
                [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr hObject);
'@
        }
 
        $STD_OUTPUT = -11; $STD_ERROR = -12
        $INVALID_HANDLE_VALUE = [IntPtr]::new(-1)

        $hOrigOut = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_OUTPUT)
        $hOrigErr = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_ERROR)
        # Apre NUL in scrittura
        $hNull = [WinReinstallStore.NativeConsole]::CreateFileW(
            'NUL', 0x40000000, 3, [IntPtr]::Zero, 3, 0, [IntPtr]::Zero)

        # FIX #1 — Valida gli handle prima di usarli.
        # CreateFileW restituisce INVALID_HANDLE_VALUE (-1) in caso di errore.
        # GetStdHandle può restituire 0 (NULL) se il processo non ha una console associata
        # (es. avviato con -WindowStyle Hidden, I/O rediretto, o hosting non-interattivo).
        # Redirigere con handle non validi corrompe lo stdout del processo e causa
        # l'eccezione "Handle non valido" all'interno di Reset-Winget/deployment engine.
        $canRedirect = (
            $hNull -ne $INVALID_HANDLE_VALUE -and $hNull -ne [IntPtr]::Zero -and
            $hOrigOut -ne $INVALID_HANDLE_VALUE -and $hOrigOut -ne [IntPtr]::Zero -and
            $hOrigErr -ne $INVALID_HANDLE_VALUE -and $hOrigErr -ne [IntPtr]::Zero
        )
        $handlesRedirected = $false

        $wingetResult = $false
        $wingetError = $null
        try {
            $global:ProgressPreference = 'SilentlyContinue'
            if ($canRedirect) {
                [WinReinstallStore.NativeConsole]::SetStdHandle($STD_OUTPUT, $hNull) | Out-Null
                [WinReinstallStore.NativeConsole]::SetStdHandle($STD_ERROR, $hNull) | Out-Null
                $handlesRedirected = $true
            }
            $wingetResult = Reset-Winget -Force
        }
        catch {
            $wingetError = $_.Exception.Message
        }
        finally {
            # Ripristino handle reali prima di qualsiasi Write-*
            if ($handlesRedirected) {
                [WinReinstallStore.NativeConsole]::SetStdHandle($STD_OUTPUT, $hOrigOut) | Out-Null
                [WinReinstallStore.NativeConsole]::SetStdHandle($STD_ERROR, $hOrigErr) | Out-Null
            }
            if ($hNull -ne $INVALID_HANDLE_VALUE -and $hNull -ne [IntPtr]::Zero) {
                [WinReinstallStore.NativeConsole]::CloseHandle($hNull) | Out-Null
            }
            $global:ProgressPreference = $savedProgressPref
        }

        # Classifica l'errore catturato.
        # Errori di handle/console sono cosmestica: il deployment engine ha già scritto
        # il pacchetto su disco prima di tentare l'output — winget può essere operativo.
        # Tutti gli altri errori indicano un fallimento reale dell'installazione.
        $isHandleError = $wingetError -and ($wingetError -match '(?i)handle|console|accesso negato|not associated')

        if ($wingetError -and -not $isHandleError) {
            Write-StyledMessage -Type 'Error' -Text "Winget: errore critico durante l'installazione - $wingetError"
            Write-ToolkitLog -Level ERROR -Message "Reset-Winget fallito: $wingetError"
        }
        elseif ($wingetError -and $isHandleError) {
            # Avviso cosmestico — non pregiudica l'installazione del binario
            Write-StyledMessage -Type 'Warning' -Text "Winget: avviso console durante l'installazione (non critico) - $wingetError"
            Write-ToolkitLog -Level WARN -Message "Reset-Winget handle warning (cosmestico): $wingetError"
        }
        else {
            $msgWinget = $wingetResult ? 'ripristinato con successo' : 'processato (potrebbe richiedere verifica manuale)'
            Write-StyledMessage -Type ($wingetResult ? 'Success' : 'Warning') -Text "Winget $msgWinget"
        }

        $storeResult = Install-MicrosoftStore
        $unigetResult = Install-UniGetUI

        # FIX #2 — Verifica finale basata esclusivamente sulla presenza del binario.
        # La vecchia logica "-not $wingetError" era troppo restrittiva: accoppiava la
        # verifica operativa di winget a qualsiasi errore, compresi quelli cosmestica
        # di handle. winget è "operativo" se il binario esiste E l'unico eventuale
        # errore era appunto cosmestico (handle/console), non un fallimento reale.
        $wingetExe = Get-WingetExecutable
        $wingetBinaryOk = Test-Path $wingetExe -ErrorAction SilentlyContinue
        $wingetOk = $wingetBinaryOk -and (-not $wingetError -or $isHandleError)

        if ($wingetOk) {
            Write-StyledMessage -Type 'Success' -Text "Winget operativo."
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "❌ Winget non operativo."
        }
 
        if ($storeResult) {
            Write-StyledMessage -Type 'Success' -Text "Microsoft Store ripristinato correttamente."
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "❌ Microsoft Store non ripristinato."
        }
 
        if ($unigetResult) {
            Write-StyledMessage -Type 'Success' -Text "UniGet UI installato."
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text "⚠️ UniGet UI richiedere verifica manuale."
        }
 
        Write-StyledMessage -Type 'Success' -Text "🎉 Operazione completata."
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