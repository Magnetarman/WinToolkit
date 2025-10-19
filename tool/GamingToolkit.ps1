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
        $timestamp = Get-Date -Format "HH:mm:ss"

        # Rimuovi emoji duplicati dal testo se presenti
        $cleanText = $Text -replace '^(✅|⚠️|❌|💎|🔍|🚀|⚙️|🧹|📦|📋|📜|📝|💾|⬇️|🔧|⚡|🖼️|🌐|🍪|🔄|🗂️|📁|🖨️|📄|🗑️|💭|⏸️|▶️|💡|⏰|🎉|💻|📊|🎮|🕹️|📥|🔗|🛠️|🎯|⭐|🔥|💪|🚀)\s*', ''

        Write-Host "[$timestamp] $($style.Icon) $cleanText" -ForegroundColor $style.Color

        # Log dettagliato per operazioni importanti
        if ($Type -in @('Info', 'Warning', 'Error')) {
            $logEntry = "[$timestamp] [$Type] $cleanText"
            $script:Log += $logEntry
        }
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $barLength = 30
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * $barLength / 100)
        $empty = '░' * ($barLength - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent

        $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
        Write-Host $clearLine -NoNewline
        Write-Host "$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color

        if ($Percent -eq 100) {
            Write-Host ''
            [Console]::Out.Flush()
        }
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
            $bar = "[$('█' * $filled)$('░' * $remaining)] $percent%"

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
            '       Version 2.4.0 (Build 3)'
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

    # Step 0: Winget Installation Check
    Write-StyledMessage 'Info' '🔍 Verifica installazione e funzionalità di Winget...'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage 'Error' '❌ Winget non è installato o non è accessibile nel PATH.'
        Write-StyledMessage 'Warning' '⚠️ Alcune funzioni di Windows potrebbero non essere funzionanti al 100%.'
        Write-StyledMessage 'Info' '💡 Si prega di eseguire lo script di reset dello Store/Winget e riprovare.'
        Write-Host ''
        Write-Host "Premi un tasto per tornare al menu principale..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return # Exit the function if Winget is not found
    }
    Write-StyledMessage 'Success' '✅ Winget è installato e funzionante.'
    Write-Host ''

    # Step 1: Abilitazione NetFramework dalle funzionalità di Windows
    Write-StyledMessage 'Info' '🔧 Abilitazione funzionalità NetFramework (NetFx4-AdvSrvs, NetFx3)...'
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs, NetFx3 -NoRestart -All -ErrorAction Stop | Out-Null
        Write-StyledMessage 'Success' '✅ Funzionalità NetFramework abilitate con successo.'
    }
    catch {
        Write-StyledMessage 'Error' "❌ Errore durante l'abilitazione di NetFramework: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 2: Scarica ed installa pacchetti .NET Runtimes e VCRedist via Winget
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
        try {
            winget install --id "$package" --silent --accept-package-agreements --accept-source-agreements | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-StyledMessage 'Success' "✅ Installato con successo: $package"
            }
            else {
                Write-StyledMessage 'Error' "❌ Errore durante l'installazione di $package. Codice di uscita: $LASTEXITCODE"
            }
        }
        catch {
            Write-StyledMessage 'Error' "❌ Eccezione durante l'installazione di $package"
            Write-StyledMessage 'Error' "   Dettagli: $($_.Exception.Message)"
        }
        Write-Host ''
    }
    Write-Progress -Activity "Installazione pacchetti Winget" -Status "Completato" -PercentComplete 100 -Completed
    Write-StyledMessage 'Success' '✅ Installazione runtime .NET e Visual C++ Redistributables completata.'
    Write-Host ''

    # Step 3: Scarica ed installa DirectX End-User Runtime
    Write-StyledMessage 'Info' '🎮 Installazione DirectX End-User Runtime...'
    $dxTempDir = Join-Path $env:LOCALAPPDATA 'WinToolkit\Directx'
    if (-not (Test-Path $dxTempDir)) {
        New-Item -Path $dxTempDir -ItemType Directory -Force | Out-Null
    }
    $dxInstallerPath = Join-Path $dxTempDir 'dxwebsetup.exe'
    $dxDownloadUrl = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/dxwebsetup.exe'

    Write-StyledMessage 'Info' "⬇️ Download di dxwebsetup.exe in '$dxInstallerPath'..."
    try {
        Invoke-WebRequest -Uri $dxDownloadUrl -OutFile $dxInstallerPath -ErrorAction Stop
        Write-StyledMessage 'Success' '✅ Download di dxwebsetup.exe completato.'

        Write-StyledMessage 'Info' '🚀 Avvio installazione DirectX (silent)...'
        Start-Process -FilePath $dxInstallerPath -ArgumentList '/Q' -Wait -PassThru -ErrorAction Stop | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-StyledMessage 'Success' '✅ Installazione DirectX completata con successo.'
        }
        else {
            Write-StyledMessage 'Error' "❌ Installazione DirectX terminata con codice di uscita: $LASTEXITCODE."
        }
    }
    catch {
        Write-StyledMessage 'Error' "❌ Errore durante il download o l'installazione di DirectX: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 4: Installa i vari client di gioco tramite Winget
    $gameClientsToInstall = @(
        "Amazon.Games",
        "GOG.Galaxy",
        "EpicGames.EpicGamesLauncher",
        "ElectronicArts.EADesktop",
        "Playnite.Playnite",
        "Valve.Steam",
        "Ubisoft.Connect",
        "Microsoft.XboxApp"
    )

    Write-StyledMessage 'Info' '🎮 Installazione client di gioco via Winget...'
    $totalClients = $gameClientsToInstall.Count
    for ($i = 0; $i -lt $totalClients; $i++) {
        $client = $gameClientsToInstall[$i]
        $percentage = [int](($i / $totalClients) * 100)

        Write-Progress -Activity "Installazione client di gioco" -Status "Installazione: $client" -PercentComplete $percentage

        Write-StyledMessage 'Info' "🎯 Tentativo di installazione: $client"
        try {
            winget install --id "$client" --silent --accept-package-agreements --accept-source-agreements | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-StyledMessage 'Success' "✅ Installato con successo: $client"
            }
            else {
                Write-StyledMessage 'Warning' "⚠️ Installazione di $client terminata con codice di uscita: $LASTEXITCODE. Potrebbe essere già installato o aver riscontrato un problema minore."
            }
        }
        catch {
            Write-StyledMessage 'Error' "❌ Eccezione durante l'installazione di $client"
            Write-StyledMessage 'Error' "   Dettagli: $($_.Exception.Message)"
        }
        Write-Host ''
    }
    Write-Progress -Activity "Installazione client di gioco" -Status "Completato" -PercentComplete 100 -Completed
    Write-StyledMessage 'Success' '✅ Installazione client di gioco via Winget completata.'
    Write-Host ''

    # Step 5: Installazione Battle.Net (Download alternativo)
    Write-StyledMessage 'Info' '🎮 Installazione Battle.Net Launcher...'
    $bnInstallerPath = Join-Path $env:TEMP 'Battle.net-Setup.exe'
    $bnDownloadUrl = 'https://downloader.battle.net//download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live'

    Write-StyledMessage 'Info' "⬇️ Download di Battle.net Launcher in '$bnInstallerPath'..."
    try {
        Invoke-WebRequest -Uri $bnDownloadUrl -OutFile $bnInstallerPath -ErrorAction Stop
        Write-StyledMessage 'Success' '✅ Download di Battle.net Launcher completato.'

        Write-StyledMessage 'Info' '🚀 Avvio installazione Battle.net Launcher (silent)...'
        Start-Process -FilePath $bnInstallerPath -ArgumentList '/S' -Wait -PassThru -ErrorAction Stop | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-StyledMessage 'Success' '✅ Installazione Battle.net Launcher completata con successo.'
        }
        else {
            Write-StyledMessage 'Error' "❌ Installazione Battle.net Launcher terminata con codice di uscita: $LASTEXITCODE."
        }
    }
    catch {
        Write-StyledMessage 'Error' "❌ Errore durante il download o l'installazione di Battle.net Launcher: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 6: Pulizia Collegamenti Avvio Automatico Launcher
    Write-StyledMessage 'Info' '🧹 Rimozione collegamenti di avvio automatico per i launcher di gioco...'
    $startupFolders = @(
        Join-Path $env:USERPROFILE 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup',
        Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Startup'
    )
    $launchersToClean = @(
        'Amazon Games', 'GOG Galaxy', 'EpicGamesLauncher', 'EADesktop', 'Playnite', 'Steam', 'Ubisoft Connect', 'Battle.net'
    )

    foreach ($folder in $startupFolders) {
        if (Test-Path $folder) {
            Write-StyledMessage 'Info' "🔍 Ricerca in: $folder"
            foreach ($launcher in $launchersToClean) {
                $linkPath = Get-ChildItem -Path $folder -Filter "$launcher*.lnk" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
                if ($linkPath) {
                    try {
                        Remove-Item -Path $linkPath -Force -ErrorAction Stop
                        Write-StyledMessage 'Success' "✅ Rimosso collegamento di avvio per '$launcher': $linkPath"
                    }
                    catch {
                        Write-StyledMessage 'Error' "❌ Errore durante la rimozione del collegamento per '$launcher' in '$folder': $($_.Exception.Message)"
                    }
                }
                else {
                    Write-StyledMessage 'Info' "💭 Nessun collegamento trovato per '$launcher' in '$folder'."
                }
            }
        }
        else {
            Write-StyledMessage 'Warning' "⚠️ Cartella di avvio non trovata: $folder"
        }
    }
    Write-StyledMessage 'Success' '✅ Pulizia collegamenti di avvio automatico completata.'
    Write-Host ''

    # Step 7: Abilitazione Profilo Energetico Massimo
    Write-StyledMessage 'Info' '⚡ Configurazione profilo energetico Performance Massime...'
    $ultimatePlanGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61" # GUID for Ultimate Performance

    # Check if Ultimate Performance plan is installed
    $ultimatePlan = powercfg -list | Select-String -Pattern "e9a42b02-d5df-448d-aa00-03f14749eb61" -ErrorAction SilentlyContinue
    if ($ultimatePlan) {
        Write-StyledMessage 'Info' "💭 Piano 'Performance Massime' già installato."
    }
    else {
        Write-StyledMessage 'Info' "🔧 Installazione piano 'Performance Massime'..."
        try {
            powercfg -duplicatescheme $ultimatePlanGUID | Out-Null
            Write-StyledMessage 'Success' "✅ Piano 'Performance Massime' installato."
        }
        catch {
            Write-StyledMessage 'Error' "❌ Errore durante l'installazione del piano 'Performance Massime': $($_.Exception.Message)"
        }
    }

    # Set the Ultimate Performance plan as active
    try {
        powercfg -setactive $ultimatePlanGUID | Out-Null
        Write-StyledMessage 'Success' "✅ Piano 'Performance Massime' impostato come attivo."
    }
    catch {
        Write-StyledMessage 'Error' "❌ Errore durante l'attivazione del piano 'Performance Massime': $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 8: Attivazione Profilo Non Disturbare (Focus Assist)
    Write-StyledMessage 'Info' '🔕 Attivazione profilo "Non disturbare" (Focus Assist)...'
    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings"
    $propName = "NOC_GLOBAL_SETTING_SUPPRESSION_ACTIVE"
    try {
        Set-ItemProperty -Path $regPath -Name $propName -Value 1 -Force -ErrorAction Stop
        Write-StyledMessage 'Success' '✅ Profilo "Non disturbare" attivato.'
    }
    catch {
        Write-StyledMessage 'Error' "❌ Errore durante l'attivazione del profilo 'Non disturbare': $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 9: Messaggio di completamento delle operazioni
    Write-Host ('═' * 80) -ForegroundColor Green
    Write-StyledMessage 'Success' '🎉 Tutte le operazioni del Gaming Toolkit sono state completate!'
    Write-StyledMessage 'Success' '🎮 Il sistema è stato ottimizzato per il gaming con tutti i componenti necessari.'
    Write-Host ('═' * 80) -ForegroundColor Green
    Write-Host ''

    # Step 10: Barra di countdown di 30 secondi e richiesta di riavvio
    Write-Host "Il sistema deve essere riavviato per applicare tutte le modifiche." -ForegroundColor Red
    Write-Host "Riavvio automatico in $CountdownSeconds secondi..." -ForegroundColor Red

    $shouldReboot = Start-InterruptibleCountdown $CountdownSeconds "Preparazione riavvio sistema"

    if ($shouldReboot) {
        Write-StyledMessage 'Info' '🔄 Riavvio del sistema...'
        Restart-Computer -Force
    }
    else {
        Write-StyledMessage 'Warning' '⚠️ Riavvio annullato. Le modifiche potrebbero non essere completamente applicate fino al prossimo riavvio.'
        Write-Host ''
        Write-Host "Premi un tasto per tornare al menu principale..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
}