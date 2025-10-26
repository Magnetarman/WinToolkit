function GamingToolkit {
    <#
    .SYNOPSIS
        Gaming Toolkit - Strumenti di ottimizzazione per il gaming su Windows.

    .DESCRIPTION
        Script completo per ottimizzare le prestazioni del sistema per il gaming:
        - Abilitazione funzionalità NetFramework
        - Installazione runtime .NET e Visual C++ Redistributables
        - Installazione DirectX End-User Runtime
        - Installazione client di gioco tramite Winget
        - Configurazione profilo energetico Performance Massime
        - Attivazione profilo Non disturbare (Focus Assist)
        - Pulizia collegamenti avvio automatico launcher
    #>

    param([int]$CountdownSeconds = 30)

    # OS Version Check
    $osInfo = Get-ComputerInfo
    # $isWindows11 = $osInfo.WindowsProductName -like "*Windows 11*" # <-- REMOVE OR COMMENT OUT THIS LINE
    $buildNumber = $osInfo.OsBuildNumber

    # New OS Classification Variables for robust detection
    $isWindows11BuildRange = ($buildNumber -ge 22000) # True for all Windows 11 builds (build 22000 and higher)
    $isWindows11Pre23H2 = $isWindows11BuildRange -and ($buildNumber -lt 22631) # True for Windows 11 builds older than 23H2 (e.g., 21H2, 22H2)
    $isWindows10OrOlder = -not $isWindows11BuildRange # True for any build less than 22000 (i.e., Windows 10 or earlier)

    if ($isWindows11Pre23H2) {
        $message = "Rilevata versione obsoleta. A Causa di questo Winget potrebbe non funzionare correttamente impedendo a questo script di funzionare. Scrivi Y se vuoi eseguire la funzione di riparazione in modo da rendere funzionante Winget, altrimenti se lo hai già fatto o se vuoi proseguire scrivi N."
        Write-Host $message -ForegroundColor Yellow
        $response = Read-Host "Y/N"
        if ($response -eq 'Y' -or $response -eq 'y') {
            WinReinstallStore
        }
        # If 'N' or other, proceed with the script anyway
    }

    $Host.UI.RawUI.WindowTitle = "Gaming Toolkit By MagnetarMan"

    # Setup logging specifico per GamingToolkit
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\GamingToolkit_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}

    $script:Log = @(); $script:CurrentAttempt = 0
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color

        # Log dettagliato per operazioni importanti
        if ($Type -in @('Info', 'Warning', 'Error')) {
            $timestamp = Get-Date -Format "HH:mm:ss"
            $logEntry = "[$timestamp] [$Type] $Text"
            $script:Log += $logEntry
        }
    }

    function Test-WingetPackageAvailable {
        param([string]$PackageId)
        try {
            $searchResult = winget search $PackageId 2>&1
            return $LASTEXITCODE -eq 0 -and $searchResult -match $PackageId
        }
        catch {
            return $false
        }
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '▒' * (30 - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi un tasto qualsiasi per annullare...'
        Write-Host ''

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning '⏸️ Riavvio automatico annullato'
                Write-StyledMessage Info "🔄 Puoi riavviare manualmente: 'shutdown /r /t 0' o dal menu Start."
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning '⏰ Tempo scaduto: il sistema verrà riavviato ora.'
        Start-Sleep 1
        return $true
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '    Gaming Toolkit By MagnetarMan',
            '       Version 2.4.0 (Build 18)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )

        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }

    Show-Header

    # Step 0: Install Microsoft.Winget.Client and Microsoft.AppInstaller
    Write-StyledMessage 'Info' '📥 Installazione Microsoft.Winget.Client e Microsoft.AppInstaller via Winget...'
    $wingetPackagesToInstall = @(
        "Microsoft.Winget.Client",
        "Microsoft.AppInstaller"
    )

    $totalWingetPackages = $wingetPackagesToInstall.Count
    for ($i = 0; $i -lt $totalWingetPackages; $i++) {
        $package = $wingetPackagesToInstall[$i]
        $percentage = [int](($i / $totalWingetPackages) * 100)

        Write-Progress -Activity "Installazione pacchetti Winget" -Status "Installazione: $package" -PercentComplete $percentage

        Write-StyledMessage 'Info' "🎯 Tentativo di installazione: $package"
        if (Test-WingetPackageAvailable $package) {
            try {
                winget install --id "$package" --silent --accept-package-agreements --accept-source-agreements | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-StyledMessage 'Success' "Installato con successo: $package"
                }
                elseif ($LASTEXITCODE -eq -1073741819 -or $LASTEXITCODE -eq -1978335189) {
                    Write-StyledMessage 'Warning' "Installazione di $package terminata con codice di uscita: $LASTEXITCODE. Potrebbe essere già installato o incompatibile."
                }
                else {
                    Write-StyledMessage 'Error' "Errore durante l'installazione di $package. Codice di uscita: $LASTEXITCODE"
                }
            }
            catch {
                Write-StyledMessage 'Error' "Eccezione durante l'installazione di $package"
                Write-StyledMessage 'Error' "   Dettagli: $($_.Exception.Message)"
            }
        }
        else {
            Write-StyledMessage 'Warning' "Pacchetto $package non disponibile in Winget. Saltando."
        }
        Write-Host ''
    }
    Write-Progress -Activity "Installazione pacchetti Winget" -Status "Completato" -PercentComplete 100 -Completed
    Write-StyledMessage 'Success' 'Installazione Microsoft.Winget.Client e Microsoft.AppInstaller completata.'
    Write-Host ''

    # Step 1: Winget Installation Check
    Write-StyledMessage 'Info' '🔍 Verifica installazione e funzionalità di Winget...'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage 'Error' 'Winget non è installato o non è accessibile nel PATH.'
        Write-StyledMessage 'Warning' 'Alcune funzioni di Windows potrebbero non essere funzionanti al 100%.'
        Write-StyledMessage 'Info' 'Si prega di eseguire lo script di reset dello Store/Winget e riprovare.'
        Write-Host ''
        Write-Host "Premi un tasto per tornare al menu principale..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return # Exit the function if Winget is not found
    }
    Write-StyledMessage 'Success' 'Winget è installato e funzionante.'

    # Update Winget sources to ensure latest package list
    Write-StyledMessage 'Info' '🔄 Aggiornamento sorgenti Winget per garantire la disponibilità dei pacchetti...'
    try {
        winget source update | Out-Null
        Write-StyledMessage 'Success' 'Sorgenti Winget aggiornate.'
    }
    catch {
        Write-StyledMessage 'Warning' "Errore durante l'aggiornamento delle sorgenti Winget: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 2: Abilitazione NetFramework dalle funzionalità di Windows
    Write-StyledMessage 'Info' '🔧 Abilitazione funzionalità NetFramework (NetFx4-AdvSrvs, NetFx3)...'
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs, NetFx3 -NoRestart -All -ErrorAction Stop | Out-Null
        Write-StyledMessage 'Success' 'Funzionalità NetFramework abilitate con successo.'
    }
    catch {
        Write-StyledMessage 'Error' "Errore durante l'abilitazione di NetFramework: $($_.Exception.Message)"
    }
    Write-Host ''


    # Step 3: Scarica ed installa pacchetti .NET Runtimes e VCRedist via Winget
    $packagesToInstall_Runtimes = @(
        "Microsoft.DotNet.DesktopRuntime.3_1",
        "Microsoft.DotNet.DesktopRuntime.5",
        "Microsoft.DotNet.DesktopRuntime.6",
        "Microsoft.DotNet.DesktopRuntime.7",
        "Microsoft.DotNet.DesktopRuntime.8",
        "Microsoft.DotNet.DesktopRuntime.9",
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

    Write-StyledMessage 'Info' '📥 Installazione runtime .NET e Visual C++ Redistributables via Winget...'
    $totalPackages = $packagesToInstall_Runtimes.Count
    for ($i = 0; $i -lt $totalPackages; $i++) {
        $package = $packagesToInstall_Runtimes[$i]
        $percentage = [int](($i / $totalPackages) * 100)

        Write-Progress -Activity "Installazione pacchetti Winget" -Status "Installazione: $package" -PercentComplete $percentage

        Write-StyledMessage 'Info' "🎯 Tentativo di installazione: $package"
        if (Test-WingetPackageAvailable $package) {
            try {
                winget install --id "$package" --silent --accept-package-agreements --accept-source-agreements | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-StyledMessage 'Success' "Installato con successo: $package"
                }
                elseif ($LASTEXITCODE -eq -1073741819 -or $LASTEXITCODE -eq -1978335189) {
                    Write-StyledMessage 'Warning' "Installazione di $package terminata con codice di uscita: $LASTEXITCODE. Potrebbe essere già installato o incompatibile."
                }
                else {
                    Write-StyledMessage 'Error' "Errore durante l'installazione di $package. Codice di uscita: $LASTEXITCODE"
                }
            }
            catch {
                Write-StyledMessage 'Error' "Eccezione durante l'installazione di $package"
                Write-StyledMessage 'Error' "   Dettagli: $($_.Exception.Message)"
            }
        }
        else {
            Write-StyledMessage 'Warning' "Pacchetto $package non disponibile in Winget. Saltando."
        }
        Write-Host ''
    }
    Write-Progress -Activity "Installazione pacchetti Winget" -Status "Completato" -PercentComplete 100 -Completed
    Write-StyledMessage 'Success' 'Installazione runtime .NET e Visual C++ Redistributables completata.'
    Write-Host ''

    # Step 4: Scarica ed installa DirectX End-User Runtime
    Write-StyledMessage 'Info' '🎮 Installazione DirectX End-User Runtime...'
    $dxTempDir = "$env:LOCALAPPDATA\WinToolkit\Directx"
    if (-not (Test-Path $dxTempDir)) {
        New-Item -Path $dxTempDir -ItemType Directory -Force | Out-Null
    }
    $dxInstallerPath = "$dxTempDir\dxwebsetup.exe"
    $dxDownloadUrl = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/dxwebsetup.exe'

    Write-StyledMessage 'Info' "⬇️ Download di dxwebsetup.exe in '$dxInstallerPath'..."
    try {
        Invoke-WebRequest -Uri $dxDownloadUrl -OutFile $dxInstallerPath -ErrorAction Stop
        Write-StyledMessage 'Success' 'Download di dxwebsetup.exe completato.'

        Write-StyledMessage 'Info' '🚀 Avvio installazione DirectX (silent)...'
        Start-Process -FilePath $dxInstallerPath -ArgumentList '/Q' -Wait -PassThru -ErrorAction Stop | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-StyledMessage 'Success' 'Installazione DirectX completata con successo.'
        }
        elseif ($LASTEXITCODE -eq -1073741819 -or $LASTEXITCODE -eq -1978335189) {
            Write-StyledMessage 'Warning' "Installazione DirectX terminata con codice di uscita: $LASTEXITCODE. Potrebbe essere già installato o incompatibile."
        }
        else {
            Write-StyledMessage 'Error' "Installazione DirectX terminata con codice di uscita: $LASTEXITCODE."
        }
    }
    catch {
        Write-StyledMessage 'Error' "Errore durante il download o l'installazione di DirectX: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 5: Installa i vari client di gioco tramite Winget
    $gameClientsToInstall = @(
        "Amazon.Games",
        "GOG.Galaxy",
        "EpicGames.EpicGamesLauncher",
        "ElectronicArts.EADesktop",
        "Playnite.Playnite",
        "Valve.Steam",
        "Ubisoft.Connect",
        "9MV0B5HZVK9Z"
    )

    Write-StyledMessage 'Info' '🎮 Installazione client di gioco via Winget...'
    $totalClients = $gameClientsToInstall.Count
    for ($i = 0; $i -lt $totalClients; $i++) {
        $client = $gameClientsToInstall[$i]
        $percentage = [int](($i / $totalClients) * 100)

        Write-Progress -Activity "Installazione client di gioco" -Status "Installazione: $client" -PercentComplete $percentage

        if (Test-WingetPackageAvailable $client) {
            try {
                winget install --id "$client" --silent --accept-package-agreements --accept-source-agreements | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-StyledMessage 'Success' "Installato con successo: $client"
                }
                elseif ($LASTEXITCODE -eq -1073741819 -or $LASTEXITCODE -eq -1978335189) {
                    Write-StyledMessage 'Warning' "Installazione di $client terminata con codice di uscita: $LASTEXITCODE. Potrebbe essere già installato o incompatibile."
                }
                else {
                    Write-StyledMessage 'Warning' "Installazione di $client terminata con codice di uscita: $LASTEXITCODE. Potrebbe essere già installato o aver riscontrato un problema minore."
                }
            }
            catch {
                Write-StyledMessage 'Error' "Eccezione durante l'installazione di $client"
                Write-StyledMessage 'Error' "   Dettagli: $($_.Exception.Message)"
            }
        }
        else {
            Write-StyledMessage 'Warning' "Pacchetto $client non disponibile in Winget. Saltando."
        }
        Write-Host ''
    }
    Write-Progress -Activity "Installazione client di gioco" -Status "Completato" -PercentComplete 100 -Completed
    Write-StyledMessage 'Success' 'Installazione client di gioco via Winget completata.'
    Write-Host ''

    # Step 6: Installazione Battle.Net (Download alternativo)
    Write-StyledMessage 'Info' '🎮 Installazione Battle.Net Launcher...'
    $bnInstallerPath = "$env:TEMP\Battle.net-Setup.exe"
    $bnDownloadUrl = 'https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live'

    Write-StyledMessage 'Info' "⬇️ Download di Battle.net Launcher in '$bnInstallerPath'..."
    try {
        Invoke-WebRequest -Uri $bnDownloadUrl -OutFile $bnInstallerPath -ErrorAction Stop
        Write-StyledMessage 'Success' 'Download di Battle.net Launcher completato.'

        Write-StyledMessage 'Info' '🚀 Avvio installazione Battle.net Launcher (silent)...'
        Start-Process -FilePath $bnInstallerPath -ArgumentList '/S' -PassThru -ErrorAction Stop | Out-Null
        Write-StyledMessage 'Info' 'Installazione Battle.net Launcher avviata. Essendo un installazione esterna, attendi il completamento e premi un tasto per proseguire con il resto dello script.'
        Write-Host ''
        Write-Host "Premi un tasto quando l'installazione di Battle.net è completa..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        Write-StyledMessage 'Success' 'Installazione Battle.net Launcher completata. Proseguimento con il resto dello script.'
    }
    catch {
        Write-StyledMessage 'Error' "Errore durante il download o l'avvio dell'installazione di Battle.net Launcher: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 7: Pulizia Chiavi di Avvio Automatico nel Registro e Collegamenti Startup
    Write-StyledMessage 'Info' '🧹 Rimozione chiavi di avvio automatico nel registro per i launcher di gioco...'
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $regKeysToClean = @('Steam', 'Battle.net', 'GOG Galaxy')

    foreach ($keyName in $regKeysToClean) {
        try {
            if (Test-Path -Path $runKey -ErrorAction SilentlyContinue) {
                # Check if the property exists before attempting to remove it
                if (Get-ItemProperty -Path $runKey -Name $keyName -ErrorAction SilentlyContinue) {
                    Remove-ItemProperty -Path $runKey -Name $keyName -ErrorAction Stop
                    Write-StyledMessage 'Success' "Rimosso chiave di avvio automatico per '$keyName' dal registro."
                }
                else {
                    Write-StyledMessage 'Info' "💭 Chiave di avvio automatico per '$keyName' non trovata nel registro (non necessaria rimozione)."
                }
            }
            else {
                Write-StyledMessage 'Warning' "Percorso del registro '$runKey' non trovato."
            }
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante la rimozione della chiave di registro per '$keyName': $($_.Exception.Message)"
        }
    }
    Write-Host ''

    Write-StyledMessage 'Info' '🧹 Rimozione collegamenti di avvio automatico dalla cartella Startup per i launcher di gioco...'
    $startupPath = [Environment]::GetFolderPath('Startup')
    $linkNamesToClean = @('Steam.lnk', 'Battle.net.lnk', 'GOG Galaxy.lnk')

    foreach ($linkName in $linkNamesToClean) {
        $fullPath = Join-Path -Path $startupPath -ChildPath $linkName
        try {
            if (Test-Path -Path $fullPath -PathType Leaf -ErrorAction SilentlyContinue) {
                Remove-Item -Path $fullPath -Force -ErrorAction Stop
                Write-StyledMessage 'Success' "Rimosso collegamento di avvio automatico per '$linkName' dalla cartella Startup."
            }
            else {
                Write-StyledMessage 'Info' "💭 Collegamento di avvio automatico per '$linkName' non trovato nella cartella Startup (non necessaria rimozione)."
            }
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante la rimozione del collegamento per '$linkName': $($_.Exception.Message)"
        }
    }
    Write-Host ''

    Write-StyledMessage 'Success' 'Pulizia chiavi e collegamenti di avvio automatico completata.'
    Write-Host ''

    # Step 8: Abilitazione Profilo Energetico Massimo
    $ultimateTemplateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61" # GUID for the hidden Ultimate Performance template
    $customUltimatePlanName = "WinToolkit Gaming Performance" # A unique, identifiable name for our duplicated plan
    $activePlanGUID = $null # Variable to store the GUID of the plan we'll activate

    Write-StyledMessage 'Info' '⚡ Configurazione profilo energetico Performance Massime...'

    # Check if a custom "WinToolkit Gaming Performance" plan already exists
    $existingPlan = powercfg -list | Select-String -Pattern "$customUltimatePlanName" -ErrorAction SilentlyContinue

    if ($existingPlan) {
        # Extract GUID of the existing custom plan
        # The GUID is typically the 4th token in the output line (index 3 for 0-based array)
        $activePlanGUID = ($existingPlan.Line -split '\s+')[3]
        Write-StyledMessage 'Info' "💭 Piano '$customUltimatePlanName' già presente. GUID: $activePlanGUID"
    }
    else {
        Write-StyledMessage 'Info' "🔧 Installazione e configurazione piano '$customUltimatePlanName'..."
        try {
            # Duplicate the hidden Ultimate Performance plan
            $duplicateOutput = powercfg /duplicatescheme $ultimateTemplateGUID | Out-String # Capture output for GUID extraction

            # Extract the newly generated GUID from the output
            if ($duplicateOutput -match "\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b") {
                $newlyCreatedGUID = $matches[0]
                Write-StyledMessage 'Info' "GUID del nuovo piano generato: $newlyCreatedGUID"

                # Rename the newly created plan for better identification
                powercfg /changename $newlyCreatedGUID "$customUltimatePlanName" "Ottimizzato per Gaming dal WinToolkit" | Out-Null
                $activePlanGUID = $newlyCreatedGUID
                Write-StyledMessage 'Success' "Piano '$customUltimatePlanName' installato e rinominato."
            }
            else {
                Write-StyledMessage 'Error' "Errore: Impossibile estrarre il GUID dal nuovo piano energetico creato."
            }
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante la duplicazione o rinomina del piano energetico: $($_.Exception.Message)"
        }
    }

    # Now, activate the plan if its GUID was successfully identified or created
    if ($null -ne $activePlanGUID) {
        try {
            powercfg -setactive $activePlanGUID | Out-Null
            Write-StyledMessage 'Success' "Piano '$customUltimatePlanName' impostato come attivo."
        }
        catch {
            Write-StyledMessage 'Error' "Errore durante l'attivazione del piano '$customUltimatePlanName': $($_.Exception.Message)"
        }
    }
    else {
        Write-StyledMessage 'Error' "Impossibile attivare il piano energetico: nessun GUID disponibile per '$customUltimatePlanName'."
    }
    Write-Host ''

    # Step 9: Attivazione Profilo Non Disturbare (Focus Assist)
    Write-StyledMessage 'Info' '🔕 Attivazione profilo "Non disturbare" (Focus Assist)...'
    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings"
    $propName = "NOC_GLOBAL_SETTING_SUPPRESSION"
    try {
        Set-ItemProperty -Path $regPath -Name $propName -Value 1 -Force -ErrorAction Stop
        Write-StyledMessage 'Success' 'Profilo "Non disturbare" attivato.'
    }
    catch {
        Write-StyledMessage 'Error' "Errore durante l'attivazione del profilo 'Non disturbare': $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 10: Messaggio di completamento delle operazioni
    Write-Host ('═' * 80) -ForegroundColor Green
    Write-StyledMessage 'Success' '🎉 Tutte le operazioni del Gaming Toolkit sono state completate!'
    Write-StyledMessage 'Success' '🎮 Il sistema è stato ottimizzato per il gaming con tutti i componenti necessari.'
    Write-Host ('═' * 80) -ForegroundColor Green
    Write-Host ''

    # Step 11: Barra di countdown di 30 secondi e richiesta di riavvio
    Write-Host "Il sistema deve essere riavviato per applicare tutte le modifiche." -ForegroundColor Red
    Write-Host "Riavvio automatico in $CountdownSeconds secondi..." -ForegroundColor Red

    $shouldReboot = Start-InterruptibleCountdown $CountdownSeconds "Preparazione riavvio sistema"

    if ($shouldReboot) {
        Write-StyledMessage 'Info' '🔄 Riavvio del sistema...'
        Restart-Computer -Force
    }
    else {
        Write-StyledMessage 'Warning' 'Riavvio annullato. Le modifiche potrebbero non essere completamente applicate fino al prossimo riavvio.'
        Write-Host ''
        Write-Host "Premi un tasto per tornare al menu principale..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
}