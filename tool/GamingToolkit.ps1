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

    param(
        [ValidateRange(0, 300)]
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "GamingToolkit" -SubTitle "Gaming Toolkit"

    $timeout = 3600

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
        Write-StyledMessage -Type 'Info' -Text "[$Step/$Total] 📦 Installazione: $DisplayName"

        $outFile = "$env:TEMP\winget_$PackageId.log"
        $errFile = "$env:TEMP\winget_err_$PackageId.log"

        try {
            $result = Invoke-WithSpinner -Activity "Installazione $DisplayName" -Command 'winget' -Arguments @('install', '--id', $PackageId, '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements') -TimeoutSeconds $timeout -LogContextKey "Gaming-Install-$PackageId"

            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)

            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text "Installato: $DisplayName"
                return @{ Success = $true; ExitCode = $exitCode }
            }
            else {
                Write-StyledMessage -Type 'Error' -Text "Errore installazione $DisplayName (codice: $exitCode)."
                return @{ Success = $false; ExitCode = $exitCode }
            }
        }
        catch {
            Clear-ProgressLine
            Clear-ProgressLine
            Write-StyledMessage -Type 'Error' -Text "Eccezione $DisplayName : $($_.Exception.Message)."
            return @{ Success = $false }
        }
        finally {
            Remove-ItemSafely -Path $outFile
            Remove-ItemSafely -Path $errFile
        }
    }

    # Countdown preparazione
    Invoke-WithSpinner -Activity "Preparazione" -Timer -Action { Start-Sleep 5 } -TimeoutSeconds 5

    Show-Header -SubTitle "Gaming Toolkit"

    # Step 1: Verifica e ripristino automatico Winget
    Write-StyledMessage -Type 'Info' -Text '🔍 Verifica disponibilità Winget.'
    Update-EnvironmentPath
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type 'Warning' -Text '⚠️ Winget non disponibile. Avvio ripristino automatico...'
        $resetOk = Reset-Winget
        Update-EnvironmentPath
        if (-not $resetOk -or -not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Error' -Text '❌ Ripristino Winget fallito. Impossibile procedere con Gaming Toolkit.'
            Write-StyledMessage -Type 'Info' -Text 'Premi un tasto per continuare.'
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
    }
    Write-StyledMessage -Type 'Success' -Text '✅ Winget disponibile.'

    Write-StyledMessage -Type 'Info' -Text '🔄 Aggiornamento sorgenti Winget.'
    try {
        winget source update *>$null
        Write-StyledMessage -Type 'Success' -Text 'Sorgenti aggiornate.'
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text "Errore aggiornamento sorgenti: $($_.Exception.Message)."
    }

    # Step 2: NetFramework
    Write-StyledMessage -Type 'Info' -Text '🔧 Abilitazione NetFramework.'
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs, NetFx3 -NoRestart -All -ErrorAction Stop *>$null
        Write-StyledMessage -Type 'Success' -Text 'NetFramework abilitato.'
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante abilitazione NetFramework: $($_.Exception.Message)."
    }

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

    Write-StyledMessage -Type 'Info' -Text '🔥 Installazione runtime .NET e VCRedist.'
    for ($runtimeIndex = 0; $runtimeIndex -lt $runtimes.Count; $runtimeIndex++) {
        Invoke-WingetInstallWithProgress $runtimes[$runtimeIndex] $runtimes[$runtimeIndex] ($runtimeIndex + 1) $runtimes.Count *>$null
    }
    Write-StyledMessage -Type 'Success' -Text 'Runtime completati.'

    # Step 4: DirectX
    Write-StyledMessage -Type 'Info' -Text '🎮 Installazione DirectX.'
    $dxDir = Join-Path $AppConfig.Paths.LocalAppData "WinToolkit\Directx"
    $dxPath = "$dxDir\dxwebsetup.exe"

    if (-not (Test-Path $dxDir)) { New-Item -Path $dxDir -ItemType Directory -Force *>$null }

    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.DirectXWebSetup -OutFile $dxPath -ErrorAction Stop
        Write-StyledMessage -Type 'Success' -Text 'DirectX scaricato.'

        $result = Invoke-WithSpinner -Activity "Installazione DirectX" -Command $dxPath -TimeoutSeconds $timeout -LogContextKey "Gaming-DirectX"

        Clear-ProgressLine
        Clear-ProgressLine

        if ($null -eq $result) {
            Write-StyledMessage -Type 'Error' -Text "DirectX: processo non avviato correttamente."
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage -Type 'Warning' -Text "Timeout DirectX."
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 3010, 5100, -9, 9, -1442840576)
            Write-StyledMessage -Type ($exitCode -in $successCodes ? 'Success' : 'Error') -Text ($exitCode -in $successCodes ? "DirectX installato (codice: $exitCode)." : "DirectX errore: $exitCode")
        }
    }
    catch {
        Clear-ProgressLine
        Clear-ProgressLine
        Write-StyledMessage -Type 'Error' -Text "Errore durante installazione DirectX: $($_.Exception.Message)"
    }

    # Step 5: Client di gioco
    $gameClients = @(
        "Amazon.Games", "GOG.Galaxy", "EpicGames.EpicGamesLauncher",
        "ElectronicArts.EADesktop", "Playnite.Playnite", "Valve.Steam",
        "Ubisoft.Connect"
    )

    Write-StyledMessage -Type 'Info' -Text '🎮 Installazione client di gioco.'
    for ($clientIndex = 0; $clientIndex -lt $gameClients.Count; $clientIndex++) {
        Invoke-WingetInstallWithProgress $gameClients[$clientIndex] $gameClients[$clientIndex] ($clientIndex + 1) $gameClients.Count *>$null
    }
    Write-StyledMessage -Type 'Success' -Text 'Client installati.'

    # Step 5b: Xbox Game Bar & Xbox App
    Write-StyledMessage -Type 'Info' -Text '🎮 Reinstallazione Xbox Game Bar & App.'

    $xboxPackages = @("9NZKPSTSNW4P", "9MV0B5HZVK9Z")

    foreach ($pkg in $xboxPackages) {
        Write-StyledMessage -Type 'Info' -Text "Reinstallazione: $pkg."

        $outFile = "$env:TEMP\winget_$pkg.log"
        $errFile = "$env:TEMP\winget_err_$pkg.log"

        try {
            $result = Invoke-WithSpinner -Activity "Reinstallazione $pkg" -Process -Action {
                $procParams = @{
                    FilePath               = 'winget'
                    ArgumentList           = @('install', '--id', $pkg, '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements', '--force')
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
                Write-StyledMessage -Type 'Success' -Text "Reinstallato: $pkg."
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "${pkg}: codice $exitCode."
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore $pkg : $($_.Exception.Message)."
        }
        finally {
            Remove-ItemSafely -Path $outFile
            Remove-ItemSafely -Path $errFile
        }
    }
    Write-StyledMessage -Type 'Success' -Text 'Xbox reinstallati.'

    # Step 6: Battle.net
    Write-StyledMessage -Type 'Info' -Text '🎮 Installazione Battle.net.'
    $bnPath = "$env:TEMP\Battle.net-Setup.exe"

    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.BattleNetInstaller -OutFile $bnPath -ErrorAction Stop
        Write-StyledMessage -Type 'Success' -Text 'Battle.net scaricato.'

        $result = Invoke-WithSpinner -Activity "Installazione Battle.net" -Command $bnPath -Arguments '--quiet' -TimeoutSeconds $timeout -LogContextKey "Gaming-BattleNet"

        Clear-ProgressLine
        Clear-ProgressLine

        if ($null -eq $result) {
            Write-StyledMessage -Type 'Error' -Text "Battle.net: processo non avviato correttamente."
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage -Type 'Warning' -Text "Timeout Battle.net."
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            Write-StyledMessage -Type ($exitCode -in @(0, 3010) ? 'Success' : 'Warning') -Text ($exitCode -in @(0, 3010) ? "Battle.net installato." : "Battle.net: codice $exitCode")
        }

        Write-StyledMessage -Type 'Info' -Text 'Premi un tasto per continuare.'
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    catch {
        Clear-ProgressLine
        Clear-ProgressLine
        Write-StyledMessage -Type 'Error' -Text "Errore durante installazione Battle.net: $($_.Exception.Message)"
        Write-StyledMessage -Type 'Info' -Text 'Premi un tasto per continuare.'
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }

    # Step 7: Pulizia avvio automatico
    Write-StyledMessage -Type 'Info' -Text '🧹 Pulizia avvio automatico.'
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    @('Steam', 'Battle.net', 'GOG Galaxy', 'GogGalaxy', 'GalaxyClient') | ForEach-Object {
        if (Get-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text "Rimosso: $_"
        }
    }

    $startupPath = $AppConfig.Paths.Startup
    @('Steam.lnk', 'Battle.net.lnk', 'GOG Galaxy.lnk') | ForEach-Object {
        $path = Join-Path $startupPath $_
        Remove-ItemSafely -Path $path
        if (-not (Test-Path $path)) {
            Write-StyledMessage -Type 'Success' -Text "Rimosso: $_"
        }
    }
    Write-StyledMessage -Type 'Success' -Text 'Pulizia completata.'

    # Step 8: Profilo energetico
    Write-StyledMessage -Type 'Info' -Text '⚡ Configurazione profilo energetico.'
    $ultimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $planName = "WinToolkit Gaming Performance"
    $guid = $null

    $existingPlan = powercfg -list | Select-String -Pattern $planName -ErrorAction SilentlyContinue
    if ($existingPlan) {
        $guid = ($existingPlan.Line -split '\s+')[3]
        Write-StyledMessage -Type 'Info' -Text "Piano esistente trovato."
    }
    else {
        try {
            $output = powercfg /duplicatescheme $ultimateGUID | Out-String
            if ($output -match "\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b") {
                $guid = $matches[0]
                powercfg /changename $guid $planName "Ottimizzato per Gaming dal WinToolkit" *>$null
                Write-StyledMessage -Type 'Success' -Text "Piano creato."
            }
            else {
                Write-StyledMessage -Type 'Error' -Text "Errore creazione piano."
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante duplicazione piano energetico: $($_.Exception.Message)"
        }
    }

    if ($guid) {
        try {
            powercfg -setactive $guid *>$null
            Write-StyledMessage -Type 'Success' -Text "Piano attivato."
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante attivazione piano energetico: $($_.Exception.Message)."
        }
    }
    else {
        Write-StyledMessage -Type 'Error' -Text "Impossibile attivare piano."
    }

    # Step 9: Focus Assist
    Write-StyledMessage -Type 'Info' -Text '🔕 Attivazione Non disturbare.'
    try {
        Set-ItemProperty -Path $AppConfig.Registry.FocusAssist -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0 -Force
        Write-StyledMessage -Type 'Success' -Text 'Non disturbare attivo.'
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante configurazione Focus Assist: $($_.Exception.Message)"
    }

    # Step 10: Completamento
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)
    Write-StyledMessage -Type 'Success' -Text 'Gaming Toolkit completato!'
    Write-StyledMessage -Type 'Success' -Text 'Sistema ottimizzato per il gaming.'
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)

    Invoke-ToolkitReboot -Message "Riavvio necessario" -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
}
