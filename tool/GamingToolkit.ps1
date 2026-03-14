function GamingToolkit {
    <#
    .SYNOPSIS
        Gaming Toolkit - Strumenti di ottimizzazione per il gaming su Windows.

    .DESCRIPTION
        Script completo per ottimizzare le prestazioni del sistema per il gaming.
        Include installazione di runtime, client di gioco e configurazione del sistema.

    .PARAMETER CountdownSeconds
        Numero di secondi per il countdown prima del riavvio.

    .OUTPUTS
        None. La funzione non restituisce output.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,
        
        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Start-ToolkitLog -ToolName "GamingToolkit"
    Show-Header -SubTitle "Gaming Toolkit"
    $Host.UI.RawUI.WindowTitle = "Gaming Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    $osInfo = Get-ComputerInfo
    $buildNumber = $osInfo.OsBuildNumber
    $isWindows11Pre23H2 = ($buildNumber -ge 22000) -and ($buildNumber -lt 22631)
    $timeout = 3600    # Un'ora in secondi

    # ============================================================================
    # 3. FUNZIONI HELPER LOCALI
    # ============================================================================
    function Test-WingetPackageAvailable([string]$PackageId) {
        try {
            $searchResult = winget search --id $PackageId --accept-source-agreements 2>&1
            $outputStr = $searchResult -join ' '
            if ($outputStr -match [regex]::Escape($PackageId)) {
                return $true
            }
            $listResult = winget list --id $PackageId --accept-source-agreements 2>&1
            $listStr = $listResult -join ' '
            if ($listStr -match [regex]::Escape($PackageId)) {
                return $true
            }
            return $false
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-StyledMessage -Type 'Warning' -Text ("Errore verifica pacchetto {0}: {1}" -f $PackageId, $errorMessage)
            return $false
        }
    }

    function Invoke-WingetInstallWithProgress([string]$PackageId, [string]$DisplayName, [int]$Step, [int]$Total) {
        Write-StyledMessage -Type 'Info' -Text "[$Step/$Total] 📦 Installazione: $DisplayName..."

        $outFile = "$env:TEMP\winget_$PackageId.log"
        $errFile = "$env:TEMP\winget_err_$PackageId.log"

        try {
            $result = Invoke-WithSpinner -Activity "Installazione $DisplayName" -Process -Action {
                $procParams = @{
                    FilePath               = 'winget'
                    ArgumentList           = @('install', '--id', $PackageId, '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements')
                    PassThru               = $true
                    NoNewWindow            = $true
                    RedirectStandardOutput = $outFile
                    RedirectStandardError  = $errFile
                }
                Start-Process @procParams
            } -TimeoutSeconds $timeout -UpdateInterval 700

            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)

            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text "Installato: $DisplayName"
                return @{ Success = $true; ExitCode = $exitCode }
            }
            else {
                Write-StyledMessage -Type 'Error' -Text "Errore installazione $DisplayName (codice: $exitCode)"
                return @{ Success = $false; ExitCode = $exitCode }
            }
        }
        catch {
            Write-Host "`r$(' ' * 120)" -NoNewline
            Write-Host "`r" -NoNewline
            Write-StyledMessage -Type 'Error' -Text "Eccezione $DisplayName : $($_.Exception.Message)"
            return @{ Success = $false }
        }
        finally {
            Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
        }
    }

    if ($isWindows11Pre23H2) {
        Write-StyledMessage Warning "Versione obsoleta rilevata. Winget potrebbe non funzionare."
        $response = Read-Host "Eseguire riparazione Winget? (Y/N)"
        if ($response -match '^[Yy]$') { WinReinstallStore }
    }

    $Host.UI.RawUI.WindowTitle = "Gaming Toolkit By MagnetarMan"

    # Countdown preparazione
    Invoke-WithSpinner -Activity "Preparazione" -Timer -Action { Start-Sleep 5 } -TimeoutSeconds 5

    Show-Header -SubTitle "Gaming Toolkit"

    # Step 1: Verifica Winget
    Write-StyledMessage Info '🔍 Verifica Winget...'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage Error 'Winget non disponibile.'
        Write-StyledMessage Info 'Esegui reset Store/Winget e riprova.'
        Write-StyledMessage -Type 'Info' -Text 'Premi un tasto per continuare...'
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return
    }
    Write-StyledMessage Success 'Winget funzionante.'

    Write-StyledMessage Info '🔄 Aggiornamento sorgenti Winget...'
    try {
        winget source update | Out-Null
        Write-StyledMessage Success 'Sorgenti aggiornate.'
    }
    catch {
        Write-StyledMessage Warning "Errore aggiornamento sorgenti: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 2: NetFramework
    Write-StyledMessage Info '🔧 Abilitazione NetFramework...'
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs, NetFx3 -NoRestart -All -ErrorAction Stop | Out-Null
        Write-StyledMessage Success 'NetFramework abilitato.'
    }
    catch {
        Write-StyledMessage Error "Errore durante abilitazione NetFramework: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 3: Runtime e VCRedist
    $runtimes = @(
        "Microsoft.DotNet.DesktopRuntime.3_1",
        "Microsoft.DotNet.DesktopRuntime.5",
        "Microsoft.DotNet.DesktopRuntime.6",
        "Microsoft.DotNet.DesktopRuntime.7",
        "Microsoft.DotNet.DesktopRuntime.8",
        "Microsoft.DotNet.DesktopRuntime.9",
        "Microsoft.DotNet.DesktopRuntime.10",
        "Microsoft.VCRedist.2010.x64",
        "Microsoft.VCRedist.2010.x86",
        "Microsoft.VCRedist.2012.x64",
        "Microsoft.VCRedist.2012.x86",
        "Microsoft.VCRedist.2013.x64",
        "Microsoft.VCRedist.2013.x86",
        "Microsoft.VCLibs.Desktop.14",
        "Microsoft.VCRedist.2015+.x64",
        "Microsoft.VCRedist.2015+.x86"
    )

    Write-StyledMessage Info '🔥 Installazione runtime .NET e VCRedist...'
    for ($runtimeIndex = 0; $runtimeIndex -lt $runtimes.Count; $runtimeIndex++) {
        Invoke-WingetInstallWithProgress $runtimes[$runtimeIndex] $runtimes[$runtimeIndex] ($runtimeIndex + 1) $runtimes.Count | Out-Null
        Write-Host ''
    }
    Write-StyledMessage Success 'Runtime completati.'
    Write-Host ''

    # Step 4: DirectX
    Write-StyledMessage Info '🎮 Installazione DirectX...'
    $dxDir = "$env:LOCALAPPDATA\WinToolkit\Directx"
    $dxPath = "$dxDir\dxwebsetup.exe"

    if (-not (Test-Path $dxDir)) { New-Item -Path $dxDir -ItemType Directory -Force | Out-Null }

    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.DirectXWebSetup -OutFile $dxPath -ErrorAction Stop
        Write-StyledMessage Success 'DirectX scaricato.'

        # Usa la funzione globale Invoke-WithSpinner per monitorare il processo DirectX
        $result = Invoke-WithSpinner -Activity "Installazione DirectX" -Process -Action {
            $procParams = @{
                FilePath     = $dxPath
                PassThru     = $true
            }
            Start-Process @procParams
        } -TimeoutSeconds $timeout -UpdateInterval 700

        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline

        if ($null -eq $result) {
            Write-StyledMessage Error "DirectX: processo non avviato correttamente."
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage Warning "Timeout DirectX."
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 3010, 5100, -9, 9, -1442840576)
            Write-StyledMessage -Type ($exitCode -in $successCodes ? 'Success' : 'Error') -Text ($exitCode -in $successCodes ? "DirectX installato (codice: $exitCode)." : "DirectX errore: $exitCode")
        }
    }
    catch {
        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline
        Write-StyledMessage Error "Errore durante installazione DirectX: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 5: Client di gioco
    $gameClients = @(
        "Amazon.Games", "GOG.Galaxy", "EpicGames.EpicGamesLauncher",
        "ElectronicArts.EADesktop", "Playnite.Playnite", "Valve.Steam",
        "Ubisoft.Connect", "9MV0B5HZVK9Z"
    )

    Write-StyledMessage Info '🎮 Installazione client di gioco...'
    for ($clientIndex = 0; $clientIndex -lt $gameClients.Count; $clientIndex++) {
        Invoke-WingetInstallWithProgress $gameClients[$clientIndex] $gameClients[$clientIndex] ($clientIndex + 1) $gameClients.Count | Out-Null
        Write-Host ''
    }
    Write-StyledMessage Success 'Client installati.'
    Write-Host ''

    # Step 6: Battle.net
    Write-StyledMessage Info '🎮 Installazione Battle.net...'
    $bnPath = "$env:TEMP\Battle.net-Setup.exe"

    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.BattleNetInstaller -OutFile $bnPath -ErrorAction Stop
        Write-StyledMessage Success 'Battle.net scaricato.'

        # Usa la funzione globale Invoke-WithSpinner per monitorare il processo Battle.net
        $result = Invoke-WithSpinner -Activity "Installazione Battle.net" -Process -Action {
            $procParams = @{
                FilePath     = $bnPath
                ArgumentList = '--quiet'
                PassThru     = $true
                Verb         = 'RunAs'
                WindowStyle  = 'Hidden'
            }
            Start-Process @procParams
        } -TimeoutSeconds $timeout -UpdateInterval 500

        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline

        if ($null -eq $result) {
            Write-StyledMessage Error "Battle.net: processo non avviato correttamente."
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage Warning "Timeout Battle.net."
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            Write-StyledMessage -Type ($exitCode -in @(0, 3010) ? 'Success' : 'Warning') -Text ($exitCode -in @(0, 3010) ? "Battle.net installato." : "Battle.net: codice $exitCode")
        }

        Write-StyledMessage -Type 'Info' -Text 'Premi un tasto per continuare...'
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    catch {
        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline
        Write-StyledMessage Error "Errore durante installazione Battle.net: $($_.Exception.Message)"
        Write-StyledMessage -Type 'Info' -Text 'Premi un tasto per continuare...'
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    Write-Host ''

    # Step 7: Pulizia avvio automatico
    Write-StyledMessage Info '🧹 Pulizia avvio automatico...'
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    @('Steam', 'Battle.net', 'GOG Galaxy', 'GogGalaxy', 'GalaxyClient') | ForEach-Object {
        if (Get-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue
            Write-StyledMessage Success "Rimosso: $_"
        }
    }

    $startupPath = [Environment]::GetFolderPath('Startup')
    @('Steam.lnk', 'Battle.net.lnk', 'GOG Galaxy.lnk') | ForEach-Object {
        $path = Join-Path $startupPath $_
        if (Test-Path $path) {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
            Write-StyledMessage Success "Rimosso: $_"
        }
    }
    Write-StyledMessage Success 'Pulizia completata.'
    Write-Host ''

    # Step 8: Profilo energetico
    Write-StyledMessage Info '⚡ Configurazione profilo energetico...'
    $ultimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $planName = "WinToolkit Gaming Performance"
    $guid = $null

    $existingPlan = powercfg -list | Select-String -Pattern $planName -ErrorAction SilentlyContinue
    if ($existingPlan) {
        $guid = ($existingPlan.Line -split '\s+')[3]
        Write-StyledMessage Info "Piano esistente trovato."
    }
    else {
        try {
            $output = powercfg /duplicatescheme $ultimateGUID | Out-String
            if ($output -match "\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b") {
                $guid = $matches[0]
                powercfg /changename $guid $planName "Ottimizzato per Gaming dal WinToolkit" | Out-Null
                Write-StyledMessage Success "Piano creato."
            }
            else {
                Write-StyledMessage Error "Errore creazione piano."
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante duplicazione piano energetico: $($_.Exception.Message)"
        }
    }

    if ($guid) {
        try {
            powercfg -setactive $guid | Out-Null
            Write-StyledMessage Success "Piano attivato."
        }
        catch {
            Write-StyledMessage Error "Errore durante attivazione piano energetico: $($_.Exception.Message)"
        }
    }
    else {
        Write-StyledMessage Error "Impossibile attivare piano."
    }
    Write-Host ''

    # Step 9: Focus Assist
    Write-StyledMessage Info '🔕 Attivazione Non disturbare...'
    try {
        Set-ItemProperty -Path $AppConfig.Registry.FocusAssist -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0 -Force
        Write-StyledMessage Success 'Non disturbare attivo.'
    }
    catch {
        Write-StyledMessage Error "Errore durante configurazione Focus Assist: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 10: Completamento
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)
    Write-StyledMessage -Type 'Success' -Text 'Gaming Toolkit completato!'
    Write-StyledMessage -Type 'Success' -Text 'Sistema ottimizzato per il gaming.'
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)
    Write-Host ''

    # Step 11: Riavvio
    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
        Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
    }
    else {
        if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio necessario") {
            Write-StyledMessage Info '🔄 Riavvio...'
            Restart-Computer -Force
        }
        else {
            Write-StyledMessage Warning 'Riavvia manualmente per applicare tutte le modifiche.'
            Write-StyledMessage -Type 'Info' -Text 'Premi un tasto per continuare...'
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
    }
}
