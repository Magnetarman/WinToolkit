function WinInstallPSProfile {
    <#
    .SYNOPSIS
        Script per installare il profilo PowerShell di ChrisTitusTech.
    .DESCRIPTION
        Installa e configura il profilo PowerShell personalizzato con oh-my-posh, zoxide e altre utilità.
        Richiede privilegi di amministratore e PowerShell 7+.
    #>
    $Host.UI.RawUI.WindowTitle = "InstallPSProfile by MagnetarMan"
    $script:Log = @()

    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path $logdir)) { New-Item -Path $logdir -ItemType Directory -Force | Out-Null }
        Start-Transcript -Path "$logdir\WinInstallPSProfile_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}

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
        $cleanText = $Text -replace '^(✅|⚠️|❌|💎|🔥|🚀|⚙️|🧹|📦|📋|📜|🔒|💾|⬇️|🔧|⚡|🖼️|🌐|🪟|🔄|🗂️|📁|🖨️|📄|🗑️|💭|⏸️|▶️|💡|⏰|🎉|💻|📊|🛡️|🔧|🔑|📦|🧹|💎|⚙️|🚀)\s*', ''
        Write-Host "[$timestamp] $($style.Icon) $cleanText" -ForegroundColor $style.Color
        if ($Type -in @('Info', 'Warning', 'Error')) { $script:Log += "[$timestamp] [$Type] $cleanText" }
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '░' * (30 - $filled.Length)
        Write-Host "`r$Spinner $Icon $Activity [$filled$empty] $safePercent% $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Add-ToSystemPath([string]$PathToAdd) {
        try {
            if (-not (Test-Path $PathToAdd)) {
                Write-StyledMessage 'Warning' "Percorso non esistente: $PathToAdd"
                return $false
            }

            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            $pathExists = ($currentPath -split ';') | Where-Object { $_.TrimEnd('\') -eq $PathToAdd.TrimEnd('\') }
            
            if ($pathExists) {
                Write-StyledMessage 'Info' "Percorso già nel PATH: $PathToAdd"
                return $true
            }

            $newPath = if ($currentPath.EndsWith(';')) { "$currentPath$PathToAdd" } else { "$currentPath;$PathToAdd" }
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            $env:PATH = "$env:PATH;$PathToAdd"
            
            Write-StyledMessage 'Success' "Percorso aggiunto al PATH: $PathToAdd"
            return $true
        }
        catch {
            Write-StyledMessage 'Error' "Errore aggiunta PATH: $($_.Exception.Message)"
            return $false
        }
    }

    function Find-ProgramPath([string]$ProgramName, [string[]]$SearchPaths, [string]$ExecutableName) {
        foreach ($path in $SearchPaths) {
            $resolvedPaths = @()
            try {
                $resolvedPaths = Get-ChildItem -Path (Split-Path $path -Parent) -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -like (Split-Path $path -Leaf) }
            }
            catch { continue }

            foreach ($resolved in $resolvedPaths) {
                $testPath = if ($resolved.FullName -notmatch '\*') { $resolved.FullName } else { $resolved.FullName }
                if (Test-Path "$testPath\$ExecutableName") { return $testPath }
            }

            $directPath = $path -replace '\*.*$', ''
            if (Test-Path "$directPath\$ExecutableName") { return $directPath }
        }
        return $null
    }

    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi un tasto per annullare...'
        Write-Host ''

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning '⏸️ Riavvio annullato'
                Write-StyledMessage Info "🔄 Riavvia manualmente: 'shutdown /r /t 0'"
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $bar = "[$('█' * $filled)$('░' * (20 - $filled))] $percent%"
            Write-Host "`r⏰ Riavvio tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning '⏰ Riavvio in corso...'
        Start-Sleep 1
        return $true
    }

    function Center-Text([string]$Text, [int]$Width = $Host.UI.RawUI.BufferSize.Width) {
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
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
            '   InstallPSProfile By MagnetarMan',
            '      Version 2.2.4 (Build 1)'
        )

        foreach ($line in $asciiArt) {
            if ($line) { Write-Host (Center-Text $line $width) -ForegroundColor White }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    Show-Header

    for ($i = 5; $i -gt 0; $i--) {
        Write-Host "`r$($spinners[$i % $spinners.Length]) ⏳ Preparazione - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-StyledMessage 'Warning' "Richiesti privilegi amministratore"
        Write-StyledMessage 'Info' "Riavvio come amministratore..."

        try {
            Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { WinInstallPSProfile }`""
            return
        }
        catch {
            Write-StyledMessage 'Error' "Impossibile elevare privilegi: $($_.Exception.Message)"
            return
        }
    }
    
    try {
        Write-StyledMessage 'Info' "Installazione profilo PowerShell..."
        Write-Host ''

        if (-not (Get-Command "pwsh" -ErrorAction SilentlyContinue)) {
            Write-StyledMessage 'Error' "PowerShell Core non installato!"
            return
        }

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-StyledMessage 'Warning' "Richiesto PowerShell 7+"
            $choice = Read-Host "Procedere comunque? (S/N)"
            if ($choice -notmatch '^[SsYy]') {
                Write-StyledMessage 'Info' "Installazione annullata"
                return
            }
        }
        
        $profileUrl = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        $oldHash = if (Test-Path $PROFILE) { Get-FileHash $PROFILE -ErrorAction SilentlyContinue } else { $null }

        Write-StyledMessage 'Info' "Controllo aggiornamenti..."
        $tempProfile = "$env:TEMP\Microsoft.PowerShell_profile.ps1"
        Invoke-RestMethod $profileUrl -OutFile $tempProfile -UseBasicParsing
        $newHash = Get-FileHash $tempProfile

        $profileDir = Split-Path $PROFILE -Parent
        if (!(Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
        if (!(Test-Path "$PROFILE.hash")) { $newHash.Hash | Out-File "$PROFILE.hash" }
        
        if ($newHash.Hash -ne $oldHash.Hash) {
            if ((Test-Path $PROFILE) -and (-not (Test-Path "$PROFILE.bak"))) {
                Write-StyledMessage 'Info' "Backup profilo esistente..."
                Copy-Item -Path $PROFILE -Destination "$PROFILE.bak" -Force
                Write-StyledMessage 'Success' "Backup completato"
            }

            Write-StyledMessage 'Info' "Installazione dipendenze..."
            Write-Host ''

            # oh-my-posh
            try {
                Write-StyledMessage 'Info' "Installazione oh-my-posh..."
                $spinnerIndex = 0; $percent = 0
                
                $installProcess = Start-Process -FilePath "winget" -ArgumentList "install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements --silent" -NoNewWindow -PassThru

                while (-not $installProcess.HasExited -and $percent -lt 90) {
                    Show-ProgressBar "oh-my-posh" "Installazione..." $percent '📦' $spinners[$spinnerIndex++ % $spinners.Length]
                    $percent += 2
                    Start-Sleep -Milliseconds 300
                }

                $installProcess.WaitForExit()
                Start-Sleep -Seconds 2
                Show-ProgressBar "oh-my-posh" "Completato" 100 '📦'
                Write-Host ''

                $ohMyPoshPaths = @(
                    "$env:LOCALAPPDATA\Programs\oh-my-posh\bin",
                    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\JanDeDobbeleer.OhMyPosh_Microsoft.Winget.Source_*",
                    "$env:ProgramFiles\oh-my-posh\bin"
                )

                $foundPath = Find-ProgramPath "oh-my-posh" $ohMyPoshPaths "oh-my-posh.exe"

                if ($foundPath) {
                    Add-ToSystemPath $foundPath | Out-Null
                    Write-StyledMessage 'Success' "oh-my-posh configurato: $foundPath"
                }
                else {
                    $searchResult = Get-ChildItem -Path "$env:LOCALAPPDATA" -Filter "oh-my-posh.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($searchResult) {
                        $foundPath = Split-Path $searchResult.FullName -Parent
                        Add-ToSystemPath $foundPath | Out-Null
                        Write-StyledMessage 'Success' "oh-my-posh trovato: $foundPath"
                    }
                    else {
                        Write-StyledMessage 'Warning' "oh-my-posh installato, PATH disponibile dopo riavvio"
                    }
                }
            }
            catch {
                Write-StyledMessage 'Warning' "Errore oh-my-posh: $($_.Exception.Message)"
            }

            # zoxide
            try {
                Write-StyledMessage 'Info' "Installazione zoxide..."
                $spinnerIndex = 0; $percent = 0
                
                $installProcess = Start-Process -FilePath "winget" -ArgumentList "install ajeetdsouza.zoxide -s winget --accept-package-agreements --accept-source-agreements --silent" -NoNewWindow -PassThru

                while (-not $installProcess.HasExited -and $percent -lt 90) {
                    Show-ProgressBar "zoxide" "Installazione..." $percent '⚡' $spinners[$spinnerIndex++ % $spinners.Length]
                    $percent += 2
                    Start-Sleep -Milliseconds 300
                }

                $installProcess.WaitForExit()
                Start-Sleep -Seconds 2
                Show-ProgressBar "zoxide" "Completato" 100 '⚡'
                Write-Host ''

                $zoxidePaths = @(
                    "$env:LOCALAPPDATA\Programs\zoxide",
                    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\ajeetdsouza.zoxide_Microsoft.Winget.Source_*",
                    "$env:ProgramFiles\zoxide"
                )

                $foundPath = Find-ProgramPath "zoxide" $zoxidePaths "zoxide.exe"

                if ($foundPath) {
                    Add-ToSystemPath $foundPath | Out-Null
                    Write-StyledMessage 'Success' "zoxide configurato: $foundPath"
                }
                else {
                    $searchResult = Get-ChildItem -Path "$env:LOCALAPPDATA" -Filter "zoxide.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($searchResult) {
                        $foundPath = Split-Path $searchResult.FullName -Parent
                        Add-ToSystemPath $foundPath | Out-Null
                        Write-StyledMessage 'Success' "zoxide trovato: $foundPath"
                    }
                    else {
                        Write-StyledMessage 'Warning' "zoxide installato, PATH disponibile dopo riavvio"
                    }
                }
            }
            catch {
                Write-StyledMessage 'Warning' "Errore zoxide: $($_.Exception.Message)"
            }

            # Refresh PATH
            Write-StyledMessage 'Info' "Aggiornamento variabili d'ambiente..."
            $spinnerIndex = 0; $percent = 0
            $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
            $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
            $env:PATH = "$machinePath;$userPath"

            while ($percent -lt 90) {
                Show-ProgressBar "PATH" "Aggiornamento..." $percent '🔧' $spinners[$spinnerIndex++ % $spinners.Length]
                $percent += Get-Random -Minimum 10 -Maximum 20
                Start-Sleep -Milliseconds 200
            }
            Show-ProgressBar "PATH" "Completato" 100 '🔧'
            Write-Host ''

            # Setup profilo
            Write-StyledMessage 'Info' "Configurazione profilo PowerShell..."
            try {
                $spinnerIndex = 0; $percent = 0
                while ($percent -lt 90) {
                    Show-ProgressBar "Profilo" "Setup..." $percent '⚙️' $spinners[$spinnerIndex++ % $spinners.Length]
                    $percent += Get-Random -Minimum 3 -Maximum 8
                    Start-Sleep -Milliseconds 400
                }

                Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1' -UseBasicParsing).Content
                Show-ProgressBar "Profilo" "Completato" 100 '⚙️'
                Write-Host ''
                Write-StyledMessage 'Success' "Profilo installato!"
            }
            catch {
                Write-StyledMessage 'Warning' "Fallback: copia manuale profilo"
                Copy-Item -Path $tempProfile -Destination $PROFILE -Force
                Write-StyledMessage 'Success' "Profilo copiato"
            }

            Write-Host ""
            Write-Host ('═' * 80) -ForegroundColor Green
            Write-StyledMessage 'Warning' "Riavvio OBBLIGATORIO per:"
            Write-Host "  • PATH oh-my-posh e zoxide" -ForegroundColor Cyan
            Write-Host "  • Font installati" -ForegroundColor Cyan
            Write-Host "  • Attivazione profilo" -ForegroundColor Cyan
            Write-Host "  • Variabili d'ambiente" -ForegroundColor Cyan
            Write-Host ('═' * 80) -ForegroundColor Green
            Write-Host ""

            $shouldReboot = Start-InterruptibleCountdown 30 "Riavvio sistema"

            if ($shouldReboot) {
                Write-StyledMessage 'Info' "Riavvio..."
                Restart-Computer -Force
            }
            else {
                Write-Host ""
                Write-Host ('═' * 80) -ForegroundColor Yellow
                Write-StyledMessage 'Warning' "RIAVVIO POSTICIPATO"
                Write-Host ('═' * 80) -ForegroundColor Yellow
                Write-Host ""
                Write-StyledMessage 'Error' "Il profilo NON funzionerà finché non riavvii!"
                Write-Host ""
                Write-StyledMessage 'Info' "Dopo il riavvio, verifica con:"
                Write-Host "  oh-my-posh --version" -ForegroundColor Cyan
                Write-Host "  zoxide --version" -ForegroundColor Cyan
                Write-Host ""
            }
        }
        else {
            Write-StyledMessage 'Info' "Profilo già aggiornato"
        }

        Remove-Item $tempProfile -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host ''
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage 'Error' "Errore installazione: $($_.Exception.Message)"
        Write-Host ('═' * 65) -ForegroundColor Red
        if (Test-Path "$env:TEMP\Microsoft.PowerShell_profile.ps1") {
            Remove-Item "$env:TEMP\Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
        }
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
        try { Stop-Transcript | Out-Null } catch {}
    }
}

WinInstallPSProfile