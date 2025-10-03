function WinInstallPSProfile {
    <#
    .SYNOPSIS
        Script per installare il profilo PowerShell di ChrisTitusTech.
    .DESCRIPTION
        Questo script scarica e installa il profilo PowerShell personalizzato di ChrisTitusTech, che include configurazioni per oh-my-posh, font, e altre utilità.
        Lo script verifica se è in esecuzione con privilegi di amministratore e, in caso contrario, si rilancia con i permessi necessari.
        Inoltre, controlla se PowerShell Core è installato e se la versione di PowerShell è 7 o superiore.
        Se il profilo esistente è diverso dalla versione più recente disponibile online, lo aggiorna e crea un backup del profilo precedente.
        Al termine dell'installazione, offre la possibilità di riavviare il sistema per applicare tutte le modifiche.
    #>
    $Host.UI.RawUI.WindowTitle = "InstallPSProfile by MagnetarMan"
    $script:Log = @(); $script:CurrentAttempt = 0

    # Setup logging specifico per WinInstallPSProfile
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
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

        # Rimuovi emoji duplicati dal testo se presenti
        $cleanText = $Text -replace '^(✅|⚠️|❌|💎|🔍|🚀|⚙️|🧹|📦|📋|📜|📝|💾|⬇️|🔧|⚡|🖼️|🌐|🍪|🔄|🗂️|📁|🖨️|📄|🗑️|💭|⏸️|▶️|💡|⏰|🎉|💻|📊|🛡️|🔧|🔍|📦|🧹|💎|⚙️|🚀)\s*', ''

        Write-Host "[$timestamp] $($style.Icon) $cleanText" -ForegroundColor $style.Color

        # Log dettagliato per operazioni importanti
        if ($Type -in @('Info', 'Warning', 'Error')) {
            $logEntry = "[$timestamp] [$Type] $cleanText"
            $script:Log += $logEntry
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
            '      Version 2.2.2 (Build 5)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    Show-Header

    for ($i = 5; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-StyledMessage 'Warning' "L'installazione del profilo PowerShell richiede privilegi di amministratore."
        Write-StyledMessage 'Info' "Riavvio come amministratore..."

        try {
            $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { WinInstallPSProfile }`""
            Start-Process PowerShell -Verb RunAs -ArgumentList $arguments
            return
        }
        catch {
            Write-StyledMessage 'Error' "Impossibile elevare i privilegi: $($_.Exception.Message)"
            Write-StyledMessage 'Error' "Esegui PowerShell come amministratore e riprova."
            return
        }
    }
    
    try {
        Write-StyledMessage 'Info' "Installazione del profilo PowerShell in corso..."
        Write-Host ''

        if (-not (Get-Command "pwsh" -ErrorAction SilentlyContinue)) {
            Write-StyledMessage 'Error' "Questo profilo richiede PowerShell Core, che non è attualmente installato!"
            return
        }

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-StyledMessage 'Warning' "Questo profilo richiede PowerShell 7 o superiore."
            $choice = Read-Host "Vuoi procedere comunque con l'installazione per PowerShell 7? (S/N)"
            if ($choice -notmatch '^[SsYy]') {
                Write-StyledMessage 'Info' "Installazione annullata dall'utente."
                return
            }
        }
        
        $profileUrl = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        $oldHash = $null
        if (Test-Path $PROFILE) {
            $oldHash = Get-FileHash $PROFILE -ErrorAction SilentlyContinue
        }

        Write-StyledMessage 'Info' "Controllo aggiornamenti profilo..."
        $tempProfile = "$env:TEMP\Microsoft.PowerShell_profile.ps1"
        Invoke-RestMethod $profileUrl -OutFile $tempProfile -UseBasicParsing
        $newHash = Get-FileHash $tempProfile

        $profileDir = Split-Path $PROFILE -Parent
        if (!(Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }

        if (!(Test-Path "$PROFILE.hash")) {
            $newHash.Hash | Out-File "$PROFILE.hash"
        }
        
        if ($newHash.Hash -ne $oldHash.Hash) {
            if ((Test-Path $PROFILE) -and (-not (Test-Path "$PROFILE.bak"))) {
                Write-StyledMessage 'Info' "Backup del profilo esistente..."
                Copy-Item -Path $PROFILE -Destination "$PROFILE.bak" -Force
                Write-StyledMessage 'Success' "Backup completato."
            }

            Write-StyledMessage 'Info' "Installazione dipendenze (oh-my-posh, zoxide, ecc.)..."
            Write-Host ''

            # Install oh-my-posh
            try {
                Write-StyledMessage 'Info' "Installazione oh-my-posh..."
                $spinnerIndex = 0; $percent = 0
                $ohMyPoshInstalled = winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements --silent 2>&1

                while ($percent -lt 90) {
                    $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                    $percent += Get-Random -Minimum 5 -Maximum 15
                    Show-ProgressBar "Installazione oh-my-posh" "Download e installazione..." $percent '📦' $spinner
                    Start-Sleep -Milliseconds 300
                }

                # Aggiungi oh-my-posh al PATH della sessione corrente
                $ohMyPoshPath = "$env:LOCALAPPDATA\Programs\oh-my-posh\bin"
                if (Test-Path $ohMyPoshPath) {
                    $env:PATH = "$ohMyPoshPath;$env:PATH"
                }

                Show-ProgressBar "Installazione oh-my-posh" "Completato" 100 '📦'
                Write-Host ''
                Write-StyledMessage 'Success' "oh-my-posh installato correttamente."
            }
            catch {
                Write-StyledMessage 'Warning' "Installazione oh-my-posh fallita: $($_.Exception.Message)"
            }

            # Install zoxide
            try {
                Write-StyledMessage 'Info' "Installazione zoxide..."
                $spinnerIndex = 0; $percent = 0
                $zoxideInstalled = winget install ajeetdsouza.zoxide -s winget --accept-package-agreements --accept-source-agreements --silent 2>&1

                while ($percent -lt 90) {
                    $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                    $percent += Get-Random -Minimum 5 -Maximum 15
                    Show-ProgressBar "Installazione zoxide" "Download e installazione..." $percent '⚡' $spinner
                    Start-Sleep -Milliseconds 300
                }

                # Aggiungi zoxide al PATH della sessione corrente
                $zoxidePath = "$env:LOCALAPPDATA\Programs\zoxide"
                if (Test-Path $zoxidePath) {
                    $env:PATH = "$zoxidePath;$env:PATH"
                }

                Show-ProgressBar "Installazione zoxide" "Completato" 100 '⚡'
                Write-Host ''
                Write-StyledMessage 'Success' "zoxide installato correttamente."
            }
            catch {
                Write-StyledMessage 'Warning' "Installazione zoxide fallita: $($_.Exception.Message)"
            }

            # Refresh environment variables
            Write-StyledMessage 'Info' "Aggiornamento variabili d'ambiente..."
            $spinnerIndex = 0; $percent = 0
            $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            while ($percent -lt 90) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                $percent += Get-Random -Minimum 10 -Maximum 20
                Show-ProgressBar "Aggiornamento PATH" "Caricamento variabili..." $percent '🔧' $spinner
                Start-Sleep -Milliseconds 200
            }
            Show-ProgressBar "Aggiornamento PATH" "Completato" 100 '🔧'
            Write-Host ''

            # Installazione profilo tramite script ChrisTitusTech
            Write-StyledMessage 'Info' "Installazione profilo PowerShell..."
            try {
                $spinnerIndex = 0; $percent = 0
                while ($percent -lt 90) {
                    $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                    $percent += Get-Random -Minimum 3 -Maximum 8
                    Show-ProgressBar "Installazione profilo" "Configurazione PowerShell..." $percent '⚙️' $spinner
                    Start-Sleep -Milliseconds 400
                }

                Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1' -UseBasicParsing).Content
                Show-ProgressBar "Installazione profilo" "Completato" 100 '⚙️'
                Write-Host ''
                Write-StyledMessage 'Success' "Profilo PowerShell installato correttamente!"
            }
            catch {
                Write-StyledMessage 'Warning' "Installazione profilo fallita, copia manuale del profilo..."
                Copy-Item -Path $tempProfile -Destination $PROFILE -Force
                Write-StyledMessage 'Success' "Profilo copiato manualmente."
            }

            Write-Host ""
            Write-Host ('═' * 80) -ForegroundColor Green
            Write-StyledMessage 'Warning' "Il riavvio è necessario per:"
            Write-Host "  • Caricare correttamente oh-my-posh nel PATH" -ForegroundColor Cyan
            Write-Host "  • Caricare correttamente zoxide nel PATH" -ForegroundColor Cyan
            Write-Host "  • Applicare tutti i font installati" -ForegroundColor Cyan
            Write-Host "  • Attivare completamente il nuovo profilo PowerShell" -ForegroundColor Cyan
            Write-Host ""
            Write-StyledMessage 'Info' "Il sistema verrà riavviato per applicare tutte le modifiche"
            Write-Host ('═' * 80) -ForegroundColor Green
            Write-Host ""

            $shouldReboot = Start-InterruptibleCountdown 30 "Preparazione riavvio sistema"

            if ($shouldReboot) {
                Write-StyledMessage 'Info' "Riavvio in corso..."
                Restart-Computer -Force
            }
            else {
                Write-Host ""
                Write-Host ('═' * 80) -ForegroundColor Yellow
                Write-StyledMessage 'Warning' "RIAVVIO POSTICIPATO"
                Write-Host ('═' * 80) -ForegroundColor Yellow
                Write-Host ""
                Write-StyledMessage 'Error' "IMPORTANTE: Il profilo NON funzionerà correttamente finché non riavvii!"
                Write-Host ""
                Write-StyledMessage 'Info' "Dopo il riavvio, apri PowerShell e verifica l'installazione con:"
                Write-Host "  oh-my-posh --version" -ForegroundColor Cyan
                Write-Host "  zoxide --version" -ForegroundColor Cyan
                Write-Host ""
            }
        }
        else {
            Write-StyledMessage 'Info' "Il profilo è già aggiornato alla versione più recente."
        }

        Remove-Item $tempProfile -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host ''
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage 'Error' "Errore durante l'installazione del profilo: $($_.Exception.Message)"
        Write-StyledMessage 'Error' "Si è verificato un errore durante l'installazione."
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