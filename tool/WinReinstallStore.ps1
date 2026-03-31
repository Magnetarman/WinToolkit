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
        Write-StyledMessage -Type 'Info' -Text "🔄 Reinstallazione Microsoft Store in corso."

        # Restart servizi Store
        Write-StyledMessage -Type 'Info' -Text "Restart servizi Microsoft Store."
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
                    $processResult = Invoke-WithConsoleRedirection -Action {
                        Invoke-WithSpinner -Activity "Installazione Store tramite Winget" -Process -Action {
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
                    }
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
                    $result = Invoke-WithConsoleRedirection -Action {
                        Invoke-WithSpinner -Activity "Aggiunta Store via DISM" -Process -Action {
                            $procParams = @{
                                FilePath     = 'DISM'
                                ArgumentList = @('/Online', '/Add-Capability', '/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0')
                                PassThru     = $true
                                WindowStyle  = 'Hidden'
                            }
                            Start-Process @procParams
                        } -TimeoutSeconds 300
                    }
                    return @{ ExitCode = $result.ExitCode }
                }
            }
        )

        $success = $false
        foreach ($method in $installMethods) {
            Write-StyledMessage -Type 'Info' -Text "Tentativo tramite: $($method.Name)."
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
                Write-StyledMessage -Type 'Warning' -Text "Metodo $($method.Name) fallito: $($_.Exception.Message)."
            }
        }

        if ($success) {
            $null = Invoke-WithConsoleRedirection -Action {
                Invoke-WithSpinner -Activity "Reset cache Microsoft Store (wsreset)" -Process -Action {
                    $procParams = @{
                        FilePath    = 'wsreset.exe'
                        PassThru    = $true
                        WindowStyle = 'Hidden'
                    }
                    Start-Process @procParams
                } -TimeoutSeconds 120
            }
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Success' -Text "Cache dello Store ripristinata."
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Impossibile reinstallare Microsoft Store tramite metodi automatici."
            Write-StyledMessage -Type 'Info' -Text "Tentativo di emergenza tramite AppXManifest."
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
                Write-StyledMessage -Type 'Error' -Text "Ripristino di emergenza fallito: $($_.Exception.Message)."
            }
        }

        return $success
    }

    # ============================================================================
    # 5. INSTALLAZIONE UNIGET UI
    # ============================================================================

    function Install-UniGetUI {
        Write-StyledMessage -Type 'Info' -Text "🔄 Installazione UniGet UI."

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
                    ArgumentList = @('install', '--exact', '--id', 'Devolutions.UniGetUI',
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
                Write-StyledMessage -Type 'Warning' -Text "Installazione UniGet UI terminata con codice: $($processResult.ExitCode)."
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante installazione UniGet UI: $($_.Exception.Message)."
            return $false
        }
    }

    # ============================================================================
    # 6. ESECUZIONE PRINCIPALE
    # ============================================================================

    function Invoke-WithConsoleRedirection {
        <#
        .SYNOPSIS
            Wrapper che sopprime TUTTO l'output Win32 del deployment engine.
            Aggressivo: redirige stdout, stderr, e sopprime ogni WriteConsoleW.
            Resiliente: se non c'è console reale, esegue l'azione senza redirezione.
        #>
        param([scriptblock]$Action)

        if (-not ('WinReinstallStore.NativeConsole' -as [type])) {
            Add-Type -Namespace 'WinReinstallStore' -Name 'NativeConsole' -MemberDefinition @'
                [DllImport("kernel32.dll")] public static extern bool SetStdHandle(int nStdHandle, IntPtr hHandle);
                [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
                [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
                public static extern IntPtr CreateFileW(
                    string lpFileName, uint dwDesiredAccess, uint dwShareMode,
                    IntPtr lpSecurityAttributes, uint dwCreationDisposition,
                    uint dwFlagsAndAttributes, IntPtr hTemplateFile);
                [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr hObject);
'@
        }

        $STD_OUTPUT = -11
        $STD_ERROR = -12
        $STD_INPUT = -10
        $INVALID_HANDLE_VALUE = [IntPtr]::new(-1)

        $hOrigOut = $null
        $hOrigErr = $null
        $hOrigIn = $null
        $hNullOut = $null
        $hNullIn = $null

        try {
            $hOrigOut = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_OUTPUT)
            $hOrigErr = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_ERROR)
            $hOrigIn = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_INPUT)
        }
        catch {
            return & $Action
        }

        if ($hOrigOut -eq $INVALID_HANDLE_VALUE -or $hOrigOut -eq [IntPtr]::Zero -or
            $hOrigErr -eq $INVALID_HANDLE_VALUE -or $hOrigErr -eq [IntPtr]::Zero) {
            return & $Action
        }

        try {
            $hNullOut = [WinReinstallStore.NativeConsole]::CreateFileW(
                'NUL', 0x40000000, 3, [IntPtr]::Zero, 3, 0x80, [IntPtr]::Zero)
            $hNullIn = [WinReinstallStore.NativeConsole]::CreateFileW(
                'NUL', 0x80000000, 3, [IntPtr]::Zero, 3, 0x80, [IntPtr]::Zero)
        }
        catch {
            return & $Action
        }

        $canRedirect = (
            $hNullOut -ne $INVALID_HANDLE_VALUE -and $hNullOut -ne [IntPtr]::Zero -and
            $hOrigOut -ne $INVALID_HANDLE_VALUE -and $hOrigOut -ne [IntPtr]::Zero -and
            $hOrigErr -ne $INVALID_HANDLE_VALUE -and $hOrigErr -ne [IntPtr]::Zero
        )

        if (-not $canRedirect) {
            return & $Action
        }

        $handlesRedirected = $false
        try {
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_OUTPUT, $hNullOut) | Out-Null
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_ERROR, $hNullOut) | Out-Null
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_INPUT, $hNullIn) | Out-Null
            $handlesRedirected = $true

            $env:POWERSHELL_TELEMETRY_OPTOUT = '1'
            $ProgressPreference = 'SilentlyContinue'

            return & $Action
        }
        finally {
            if ($handlesRedirected) {
                try {
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_OUTPUT, $hOrigOut) | Out-Null
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_ERROR, $hOrigErr) | Out-Null
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_INPUT, $hOrigIn) | Out-Null
                }
                catch { }
            }
            if ($hNullOut -and $hNullOut -ne $INVALID_HANDLE_VALUE -and $hNullOut -ne [IntPtr]::Zero) {
                try { [WinReinstallStore.NativeConsole]::CloseHandle($hNullOut) | Out-Null } catch { }
            }
            if ($hNullIn -and $hNullIn -ne $INVALID_HANDLE_VALUE -and $hNullIn -ne [IntPtr]::Zero) {
                try { [WinReinstallStore.NativeConsole]::CloseHandle($hNullIn) | Out-Null } catch { }
            }
        }
    }

    try {
        Write-StyledMessage -Type 'Progress' -Text "Avvio reinstallazione Store & Winget."

        $wingetResult = $false

        try {
            $global:ProgressPreference = 'SilentlyContinue'
            $wingetResult = Invoke-WithConsoleRedirection -Action { Reset-Winget -Force }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore imprevisto durante Reset-Winget: $($_.Exception.Message)."
            Write-ToolkitLog -Level ERROR -Message "Reset-Winget eccezione non gestita: $($_.Exception.Message)"
        }
        finally {
            $global:ProgressPreference = $savedProgressPref
        }

        if ($wingetResult) {
            Write-StyledMessage -Type 'Success' -Text "Winget ripristinato e operativo."
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "❌ Ripristino Winget fallito."
        }

        $storeResult = Install-MicrosoftStore
        $unigetResult = Install-UniGetUI
 
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
