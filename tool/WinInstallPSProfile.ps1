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
        $cleanText = $Text -replace '^(✅|⚠️|❌|💎|🔥|🚀|⚙️|🧹|📦|📋|📜|🔒|💾|⬇️|🔧|⚡|🖼️|🌐|🪟|🔄|🗂️|📁|🖨️|📄|🗑️|💭|⏸️|▶️|💡|⏰|🎉|💻|📊|🛡️|🔧|🔑|📦|🧹|💎|⚙️|🚀)\s*', ''

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
        $empty = '░' * (30 - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Add-ToSystemPath {
        param(
            [Parameter(Mandatory = $true)]
            [string]$PathToAdd
        )

        try {
            if (-not (Test-Path $PathToAdd)) {
                Write-StyledMessage 'Warning' "Il percorso non esiste: $PathToAdd"
                return $false
            }

            # Ottieni il PATH attuale dal sistema (Machine)
            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            
            # Verifica se il percorso è già presente
            $pathExists = $false
            foreach ($existingPath in ($currentPath -split ';')) {
                if ($existingPath.TrimEnd('\') -eq $PathToAdd.TrimEnd('\')) {
                    $pathExists = $true
                    break
                }
            }

            if ($pathExists) {
                Write-StyledMessage 'Info' "Il percorso è già nel PATH di sistema: $PathToAdd"
                return $true
            }

            # Aggiungi il nuovo percorso
            $newPath = if ($currentPath.EndsWith(';')) {
                "$currentPath$PathToAdd"
            }
            else {
                "$currentPath;$PathToAdd"
            }
            
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            
            # Aggiorna anche la sessione corrente
            $env:PATH = "$env:PATH;$PathToAdd"
            
            Write-StyledMessage 'Success' "Percorso aggiunto al PATH di sistema: $PathToAdd"
            return $true
        }
        catch {
            Write-StyledMessage 'Error' "Errore nell'aggiunta del percorso al PATH: $($_.Exception.Message)"
            return $false
        }
    }

    function Find-ProgramPath {
        param(
            [string]$ProgramName,
            [string[]]$SearchPaths,
            [string]$ExecutableName
        )

        foreach ($path in $SearchPaths) {
            # Espandi wildcards
            $resolvedPaths = @()
            try {
                $resolvedPaths = Get-ChildItem -Path (Split-Path $path -Parent) -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -like (Split-Path $path -Leaf) }
            }
            catch {
                continue
            }

            foreach ($resolved in $resolvedPaths) {
                $fullPath = Join-Path $resolved.FullName (Split-Path $path -Leaf).Replace('*', '')
                if ($fullPath -notmatch '\*') {
                    $testPath = $fullPath
                }
                else {
                    $testPath = $resolved.FullName
                }

                if (Test-Path "$testPath\$ExecutableName") {
                    return $testPath
                }
            }

            # Prova anche il path diretto senza wildcard
            $directPath = $path -replace '\*.*$', ''
            if (Test-Path "$directPath\$ExecutableName") {
                return $directPath
            }
        }

        return $null
    }

    function Wait-ForInstallation {
        param(
            [string]$ProcessName,
            [int]$TimeoutSeconds = 60
        )

        $elapsed = 0
        while ($elapsed -lt $TimeoutSeconds) {
            $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            if (-not $process) {
                Start-Sleep -Seconds 2
                return $true
            }
            Start-Sleep -Seconds 1
            $elapsed++
        }
        return $false
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
            '      Version 2.2.3 (Build 8)'
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
                
                # Installa oh-my-posh
                $installProcess = Start-Process -FilePath "winget" -ArgumentList "install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements --silent" -NoNewWindow -PassThru

                while (-not $installProcess.HasExited -and $percent -lt 90) {
                    $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                    $percent += 2
                    Show-ProgressBar "Installazione oh-my-posh" "Download e installazione..." $percent '📦' $spinner
                    Start-Sleep -Milliseconds 300
                }

                $installProcess.WaitForExit()
                Start-Sleep -Seconds 2

                Show-ProgressBar "Installazione oh-my-posh" "Completato" 100 '📦'
                Write-Host ''

                # Cerca oh-my-posh in vari percorsi possibili
                $ohMyPoshPaths = @(
                    "$env:LOCALAPPDATA\Programs\oh-my-posh\bin",
                    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\JanDeDobbeleer.OhMyPosh_Microsoft.Winget.Source_*",
                    "$env:ProgramFiles\oh-my-posh\bin",
                    "${env:ProgramFiles(x86)}\oh-my-posh\bin"
                )

                $foundPath = Find-ProgramPath -ProgramName "oh-my-posh" -SearchPaths $ohMyPoshPaths -ExecutableName "oh-my-posh.exe"

                if ($foundPath) {
                    $added = Add-ToSystemPath -PathToAdd $foundPath
                    if ($added) {
                        Write-StyledMessage 'Success' "oh-my-posh trovato e aggiunto al PATH: $foundPath"
                    }
                }
                else {
                    Write-StyledMessage 'Warning' "oh-my-posh installato ma percorso non trovato automaticamente."
                    Write-StyledMessage 'Info' "Provo a cercare in percorsi alternativi..."
                    
                    # Cerca in tutto il sistema
                    $searchResult = Get-ChildItem -Path "$env:LOCALAPPDATA" -Filter "oh-my-posh.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($searchResult) {
                        $foundPath = Split-Path $searchResult.FullName -Parent
                        Add-ToSystemPath -PathToAdd $foundPath
                        Write-StyledMessage 'Success' "oh-my-posh trovato in: $foundPath"
                    }
                    else {
                        Write-StyledMessage 'Warning' "Impossibile localizzare oh-my-posh. Verrà aggiunto al PATH dopo il riavvio."
                    }
                }

                Write-StyledMessage 'Success' "oh-my-posh installato correttamente."
            }
            catch {
                Write-StyledMessage 'Warning' "Installazione oh-my-posh fallita: $($_.Exception.Message)"
            }

            # Install zoxide
            try {
                Write-StyledMessage 'Info' "Installazione zoxide..."
                $spinnerIndex = 0; $percent = 0
                
                # Installa zoxide
                $installProcess = Start-Process -FilePath "winget" -ArgumentList "install ajeetdsouza.zoxide -s winget --accept-package-agreements --accept-source-agreements --silent" -NoNewWindow -PassThru

                while (-not $installProcess.HasExited -and $percent -lt 90) {
                    $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                    $percent += 2
                    Show-ProgressBar "Installazione zoxide" "Download e installazione..." $percent '⚡' $spinner
                    Start-Sleep -Milliseconds 300
                }

                $installProcess.WaitForExit()
                Start-Sleep -Seconds 2

                Show-ProgressBar "Installazione zoxide" "Completato" 100 '⚡'
                Write-Host ''

                # Cerca zoxide in vari percorsi possibili
                $zoxidePaths = @(
                    "$env:LOCALAPPDATA\Programs\zoxide",
                    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\ajeetdsouza.zoxide_Microsoft.Winget.Source_*",
                    "$env:ProgramFiles\zoxide",
                    "${env:ProgramFiles(x86)}\zoxide"
                )

                $foundPath = Find-ProgramPath -ProgramName "zoxide" -SearchPaths $zoxidePaths -ExecutableName "zoxide.exe"

                if ($foundPath) {
                    $added = Add-ToSystemPath -PathToAdd $foundPath
                    if ($added) {
                        Write-StyledMessage 'Success' "zoxide trovato e aggiunto al PATH: $foundPath"
                    }
                }
                else {
                    Write-StyledMessage 'Warning' "zoxide installato ma percorso non trovato automaticamente."
                    Write-StyledMessage 'Info' "Provo a cercare in percorsi alternativi..."
                    
                    # Cerca in tutto il sistema
                    $searchResult = Get-ChildItem -Path "$env:LOCALAPPDATA" -Filter "zoxide.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($searchResult) {
                        $foundPath = Split-Path $searchResult.FullName -Parent
                        Add-ToSystemPath -PathToAdd $foundPath
                        Write-StyledMessage 'Success' "zoxide trovato in: $foundPath"
                    }
                    else {
                        Write-StyledMessage 'Warning' "Impossibile localizzare zoxide. Verrà aggiunto al PATH dopo il riavvio."
                    }
                }

                Write-StyledMessage 'Success' "zoxide installato correttamente."
            }
            catch {
                Write-StyledMessage 'Warning' "Installazione zoxide fallita: $($_.Exception.Message)"
            }

            # Refresh environment variables
            Write-StyledMessage 'Info' "Aggiornamento variabili d'ambiente..."
            $spinnerIndex = 0; $percent = 0
            
            # Forza il refresh delle variabili d'ambiente
            $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
            $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
            $env:PATH = "$machinePath;$userPath"

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
            Write-StyledMessage 'Warning' "Il riavvio è OBBLIGATORIO per:"
            Write-Host "  • Caricare correttamente oh-my-posh nel PATH" -ForegroundColor Cyan
            Write-Host "  • Caricare correttamente zoxide nel PATH" -ForegroundColor Cyan
            Write-Host "  • Applicare tutti i font installati" -ForegroundColor Cyan
            Write-Host "  • Attivare completamente il nuovo profilo PowerShell" -ForegroundColor Cyan
            Write-Host "  • Aggiornare tutte le variabili d'ambiente di sistema" -ForegroundColor Cyan
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
                Write-StyledMessage 'Info' "Se i comandi non funzionano ancora, verifica il PATH con:"
                Write-Host "  `$env:PATH -split ';' | Select-String 'oh-my-posh|zoxide'" -ForegroundColor Cyan
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