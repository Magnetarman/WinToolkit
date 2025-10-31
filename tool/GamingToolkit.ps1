function GamingToolkit {
    <#
    .SYNOPSIS
        Gaming Toolkit - Strumenti di ottimizzazione per il gaming su Windows.
    .DESCRIPTION
        Script completo per ottimizzare le prestazioni del sistema per il gaming
    #>

    param([int]$CountdownSeconds = 30)

    # Configurazione globale
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }
    $script:Log = @()

    # Funzioni helper unificate
    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
        if ($Type -in @('Info', 'Warning', 'Error', 'Success')) {
            $script:Log += "[$(Get-Date -Format 'HH:mm:ss')] [$Type] $Text"
        }
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '░' * (30 - $filled.Length)
        Write-Host "`r$Spinner $Icon $Activity [$filled$empty] $safePercent% $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Clear-ProgressLine {
        Write-Host "`r$(' ' * 120)`r" -NoNewline
    }

    function Test-WingetPackageAvailable([string]$PackageId) {
        try {
            $result = winget search $PackageId 2>&1
            return $LASTEXITCODE -eq 0 -and $result -match $PackageId
        }
        catch { return $false }
    }

    function Invoke-WingetInstallWithProgress([string]$PackageId, [string]$DisplayName, [int]$Step, [int]$Total) {
        Write-StyledMessage 'Info' "[$Step/$Total] 📦 Installazione: $DisplayName..."
        
        if (-not (Test-WingetPackageAvailable $PackageId)) {
            Write-StyledMessage 'Warning' "Pacchetto $DisplayName non disponibile. Saltando."
            return @{ Success = $true; Skipped = $true }
        }

        try {
            $proc = Start-Process -FilePath 'winget' -ArgumentList @('install', '--id', $PackageId, '--silent', '--accept-package-agreements', '--accept-source-agreements') -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\winget_$PackageId.log" -RedirectStandardError "$env:TEMP\winget_err_$PackageId.log"
            
            $spinnerIndex = 0
            $percent = 0
            $startTime = Get-Date
            $timeout = 600

            while (-not $proc.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
                if ($percent -lt 95) { $percent += Get-Random -Minimum 1 -Maximum 2 }
                Show-ProgressBar $DisplayName "($elapsed s)" $percent '📦' $spinner
                Start-Sleep -Milliseconds 700
                $proc.Refresh()
            }

            Clear-ProgressLine

            if (-not $proc.HasExited) {
                Write-StyledMessage 'Warning' "Timeout per $DisplayName. Terminato."
                $proc.Kill()
                return @{ Success = $false; TimedOut = $true }
            }

            $exitCode = $proc.ExitCode
            $successCodes = @(0, 1638, 3010, -1978335189)
            
            if ($exitCode -in $successCodes) {
                Write-StyledMessage 'Success' "Installato: $DisplayName"
                return @{ Success = $true; ExitCode = $exitCode }
            }
            else {
                Write-StyledMessage 'Error' "Errore installazione $DisplayName (codice: $exitCode)"
                return @{ Success = $false; ExitCode = $exitCode }
            }
        }
        catch {
            Clear-ProgressLine
            Write-StyledMessage 'Error' "Eccezione $DisplayName: $($_.Exception.Message)"
            return @{ Success = $false }
        }
        finally {
            Remove-Item "$env:TEMP\winget_$PackageId.log", "$env:TEMP\winget_err_$PackageId.log" -ErrorAction SilentlyContinue
        }
    }

    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi un tasto per annullare...'
        Write-Host ''

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning '⏸️ Riavvio annullato'
                Write-StyledMessage Info "Riavvia manualmente: 'shutdown /r /t 0'"
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $bar = "[$('█' * $filled)$('░' * (20 - $filled))] $percent%"
            Write-Host "`r⏰ Riavvio tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning 'Riavvio sistema...'
        return $true
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        
        @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '    Gaming Toolkit By MagnetarMan',
            '       Version 2.4.0 (Build 35)'
        ) | ForEach-Object {
            if ($_) {
                $padding = [Math]::Max(0, [Math]::Floor(($width - $_.Length) / 2))
                Write-Host (' ' * $padding + $_) -ForegroundColor White
            }
        }
        
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    # Verifica OS e Winget
    $osInfo = Get-ComputerInfo
    $buildNumber = $osInfo.OsBuildNumber
    $isWindows11Pre23H2 = ($buildNumber -ge 22000) -and ($buildNumber -lt 22631)

    if ($isWindows11Pre23H2) {
        Write-StyledMessage 'Warning' "Versione obsoleta rilevata. Winget potrebbe non funzionare."
        $response = Read-Host "Eseguire riparazione Winget? (Y/N)"
        if ($response -match '^[Yy]$') { WinReinstallStore }
    }

    $Host.UI.RawUI.WindowTitle = "Gaming Toolkit By MagnetarMan"

    # Setup logging
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    if (-not (Test-Path $logdir)) { New-Item -Path $logdir -ItemType Directory -Force | Out-Null }
    try {
        Start-Transcript -Path "$logdir\GamingToolkit_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log" -Append | Out-Null
    }
    catch {}

    # Countdown preparazione
    for ($i = 5; $i -gt 0; $i--) {
        Write-Host "`r$($spinners[$i % $spinners.Length]) ⏳ Preparazione - $i s..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    Show-Header

    # Step 1: Verifica Winget
    Write-StyledMessage 'Info' '🔍 Verifica Winget...'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage 'Error' 'Winget non disponibile.'
        Write-StyledMessage 'Info' 'Esegui reset Store/Winget e riprova.'
        Write-Host "`nPremi un tasto..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return
    }
    Write-StyledMessage 'Success' 'Winget funzionante.'

    Write-StyledMessage 'Info' '🔄 Aggiornamento sorgenti Winget...'
    try {
        winget source update | Out-Null
        Write-StyledMessage 'Success' 'Sorgenti aggiornate.'
    }
    catch {
        Write-StyledMessage 'Warning' "Errore aggiornamento sorgenti: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 2: NetFramework
    Write-StyledMessage 'Info' '🔧 Abilitazione NetFramework...'
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs, NetFx3 -NoRestart -All -ErrorAction Stop | Out-Null
        Write-StyledMessage 'Success' 'NetFramework abilitato.'
    }
    catch {
        Write-StyledMessage 'Error' "Errore NetFramework: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 3: Runtime e VCRedist
    $runtimes = @(
        "Microsoft.DotNet.DesktopRuntime.3_1", "Microsoft.DotNet.DesktopRuntime.5",
        "Microsoft.DotNet.DesktopRuntime.6", "Microsoft.DotNet.DesktopRuntime.7",
        "Microsoft.DotNet.DesktopRuntime.8", "Microsoft.DotNet.DesktopRuntime.9",
        "Microsoft.VCRedist.2010.x64", "Microsoft.VCRedist.2010.x86",
        "Microsoft.VCRedist.2012.x64", "Microsoft.VCRedist.2012.x86",
        "Microsoft.VCRedist.2013.x64", "Microsoft.VCRedist.2013.x86",
        "Microsoft.VCLibs.Desktop.14", "Microsoft.VCRedist.2015+.x64", "Microsoft.VCRedist.2015+.x86"
    )

    Write-StyledMessage 'Info' '🔥 Installazione runtime .NET e VCRedist...'
    for ($i = 0; $i -lt $runtimes.Count; $i++) {
        Invoke-WingetInstallWithProgress $runtimes[$i] $runtimes[$i] ($i + 1) $runtimes.Count | Out-Null
        Write-Host ''
    }
    Write-StyledMessage 'Success' 'Runtime completati.'
    Write-Host ''

    # Step 4: DirectX
    Write-StyledMessage 'Info' '🎮 Installazione DirectX...'
    $dxDir = "$env:LOCALAPPDATA\WinToolkit\Directx"
    $dxPath = "$dxDir\dxwebsetup.exe"
    
    if (-not (Test-Path $dxDir)) { New-Item -Path $dxDir -ItemType Directory -Force | Out-Null }

    try {
        Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/dxwebsetup.exe' -OutFile $dxPath -ErrorAction Stop
        Write-StyledMessage 'Success' 'DirectX scaricato.'

        $proc = Start-Process -FilePath $dxPath -PassThru -Verb RunAs
        $spinnerIndex = 0
        $percent = 0
        $startTime = Get-Date

        while (-not $proc.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt 600) {
            $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
            $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
            if ($percent -lt 95) { $percent += Get-Random -Minimum 1 -Maximum 2 }
            Show-ProgressBar "DirectX" "($elapsed s)" $percent '🎮' $spinner 'Yellow'
            Start-Sleep -Milliseconds 700
            $proc.Refresh()
        }

        Clear-ProgressLine

        if (-not $proc.HasExited) {
            Write-StyledMessage 'Warning' "Timeout DirectX."
            $proc.Kill()
        }
        else {
            $exitCode = $proc.ExitCode
            $successCodes = @(0, 3010, 5100, -9, 9, -1442840576)
            if ($exitCode -in $successCodes) {
                Write-StyledMessage 'Success' "DirectX installato (codice: $exitCode)."
            }
            else {
                Write-StyledMessage 'Error' "DirectX errore: $exitCode"
            }
        }

        # Pulizia Bing Toolbar
        Write-StyledMessage 'Info' '🧹 Rimozione Bing Toolbar...'
        $bingProducts = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Bing*" }
        
        if ($bingProducts) {
            foreach ($product in $bingProducts) {
                $product.Uninstall() | Out-Null
                Write-StyledMessage 'Success' "Rimosso: $($product.Name)"
            }
        }

        # Pulizia registro Bing
        @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*Bing*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*Bing*",
            "HKCU:\Software\Microsoft\Internet Explorer\Toolbar\*Bing*"
        ) | ForEach-Object {
            Get-Item -Path $_ -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        Write-StyledMessage 'Success' 'Pulizia Bing completata.'
    }
    catch {
        Clear-ProgressLine
        Write-StyledMessage 'Error' "Errore DirectX: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 5: Client di gioco
    $gameClients = @(
        "Amazon.Games", "GOG.Galaxy", "EpicGames.EpicGamesLauncher",
        "ElectronicArts.EADesktop", "Playnite.Playnite", "Valve.Steam",
        "Ubisoft.Connect", "9MV0B5HZVK9Z"
    )

    Write-StyledMessage 'Info' '🎮 Installazione client di gioco...'
    for ($i = 0; $i -lt $gameClients.Count; $i++) {
        Invoke-WingetInstallWithProgress $gameClients[$i] $gameClients[$i] ($i + 1) $gameClients.Count | Out-Null
        Write-Host ''
    }
    Write-StyledMessage 'Success' 'Client installati.'
    Write-Host ''

    # Step 6: Battle.net
    Write-StyledMessage 'Info' '🎮 Installazione Battle.net...'
    $bnPath = "$env:TEMP\Battle.net-Setup.exe"
    
    try {
        Invoke-WebRequest -Uri 'https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live' -OutFile $bnPath
        Write-StyledMessage 'Success' 'Battle.net scaricato.'

        $proc = Start-Process -FilePath $bnPath -PassThru -Verb RunAs
        $spinnerIndex = 0
        $startTime = Get-Date

        while (-not $proc.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt 900) {
            $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
            $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
            Write-Host "`r$spinner 🎮 Battle.net ($elapsed s)" -NoNewline -ForegroundColor Cyan
            Start-Sleep -Milliseconds 500
            $proc.Refresh()
        }

        Clear-ProgressLine

        if (-not $proc.HasExited) {
            Write-StyledMessage 'Warning' "Timeout Battle.net."
            try { $proc.Kill() } catch {}
        }
        else {
            $exitCode = $proc.ExitCode
            if ($exitCode -in @(0, 3010)) {
                Write-StyledMessage 'Success' "Battle.net installato."
            }
            else {
                Write-StyledMessage 'Warning' "Battle.net: codice $exitCode"
            }
        }

        Write-Host "`nPremi un tasto..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    catch {
        Clear-ProgressLine
        Write-StyledMessage 'Error' "Errore Battle.net: $($_.Exception.Message)"
        Write-Host "`nPremi un tasto..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    Write-Host ''

    # Step 7: Pulizia avvio automatico
    Write-StyledMessage 'Info' '🧹 Pulizia avvio automatico...'
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    @('Steam', 'Battle.net', 'GOG Galaxy') | ForEach-Object {
        if (Get-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue
            Write-StyledMessage 'Success' "Rimosso: $_"
        }
    }

    $startupPath = [Environment]::GetFolderPath('Startup')
    @('Steam.lnk', 'Battle.net.lnk', 'GOG Galaxy.lnk') | ForEach-Object {
        $path = Join-Path $startupPath $_
        if (Test-Path $path) {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
            Write-StyledMessage 'Success' "Rimosso: $_"
        }
    }
    Write-StyledMessage 'Success' 'Pulizia completata.'
    Write-Host ''

    # Step 8: Profilo energetico
    Write-StyledMessage 'Info' '⚡ Configurazione profilo energetico...'
    $ultimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $planName = "WinToolkit Gaming Performance"
    $existingPlan = powercfg -list | Select-String -Pattern $planName

    if ($existingPlan) {
        $guid = ($existingPlan.Line -split '\s+')[3]
        Write-StyledMessage 'Info' "Piano esistente: $guid"
    }
    else {
        $output = powercfg /duplicatescheme $ultimateGUID | Out-String
        if ($output -match "\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b") {
            $guid = $matches[0]
            powercfg /changename $guid $planName "Ottimizzato per Gaming" | Out-Null
            Write-StyledMessage 'Success' "Piano creato."
        }
    }

    if ($guid) {
        powercfg -setactive $guid | Out-Null
        Write-StyledMessage 'Success' "Piano attivato."
    }
    Write-Host ''

    # Step 9: Focus Assist
    Write-StyledMessage 'Info' '🔕 Attivazione Non disturbare...'
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0 -Force
        Write-StyledMessage 'Success' 'Non disturbare attivo.'
    }
    catch {
        Write-StyledMessage 'Error' "Errore: $($_.Exception.Message)"
    }
    Write-Host ''

    # Step 10: Completamento
    Write-Host ('═' * 80) -ForegroundColor Green
    Write-StyledMessage 'Success' 'Gaming Toolkit completato!'
    Write-StyledMessage 'Success' 'Sistema ottimizzato per il gaming.'
    Write-Host ('═' * 80) -ForegroundColor Green
    Write-Host ''

    # Step 11: Riavvio
    Write-Host "Riavvio necessario. Automatico tra $CountdownSeconds secondi..." -ForegroundColor Red
    
    if (Start-InterruptibleCountdown $CountdownSeconds "Riavvio") {
        Write-StyledMessage 'Info' '🔄 Riavvio...'
        Restart-Computer -Force
    }
    else {
        Write-StyledMessage 'Warning' 'Riavvia manualmente per applicare tutte le modifiche.'
        Write-Host "`nPremi un tasto..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
}