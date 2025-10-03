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
    Clear-Host
    $width = 65
    Write-Host ('═' * $width) -ForegroundColor Green

    $asciiArt = @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        '   Install PSProfile By MagnetarMan',
        '        Version 2.2.2 (Build 4)'
    )

    foreach ($line in $asciiArt) {
        Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
    }

    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''

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
    
    Write-StyledMessage 'Info' "Installazione del profilo PowerShell in corso..."

    try {
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

            # Install oh-my-posh
            try {
                Write-StyledMessage 'Info' "Installazione oh-my-posh..."
                $ohMyPoshInstalled = winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements --silent 2>&1
                
                # Aggiungi oh-my-posh al PATH della sessione corrente
                $ohMyPoshPath = "$env:LOCALAPPDATA\Programs\oh-my-posh\bin"
                if (Test-Path $ohMyPoshPath) {
                    $env:PATH = "$ohMyPoshPath;$env:PATH"
                }
                
                Write-StyledMessage 'Success' "oh-my-posh installato correttamente."
            }
            catch {
                Write-StyledMessage 'Warning' "Installazione oh-my-posh fallita: $($_.Exception.Message)"
            }

            # Install zoxide
            try {
                Write-StyledMessage 'Info' "Installazione zoxide..."
                $zoxideInstalled = winget install ajeetdsouza.zoxide -s winget --accept-package-agreements --accept-source-agreements --silent 2>&1
                
                # Aggiungi zoxide al PATH della sessione corrente
                $zoxidePath = "$env:LOCALAPPDATA\Programs\zoxide"
                if (Test-Path $zoxidePath) {
                    $env:PATH = "$zoxidePath;$env:PATH"
                }
                
                Write-StyledMessage 'Success' "zoxide installato correttamente."
            }
            catch {
                Write-StyledMessage 'Warning' "Installazione zoxide fallita: $($_.Exception.Message)"
            }

            # Refresh environment variables
            Write-StyledMessage 'Info' "Aggiornamento variabili d'ambiente..."
            $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            # Installazione profilo tramite script ChrisTitusTech
            Write-StyledMessage 'Info' "Installazione profilo PowerShell..."
            try {
                Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1' -UseBasicParsing).Content
                Write-StyledMessage 'Success' "Profilo PowerShell installato correttamente!"
            }
            catch {
                Write-StyledMessage 'Warning' "Installazione profilo fallita, copia manuale del profilo..."
                Copy-Item -Path $tempProfile -Destination $PROFILE -Force
                Write-StyledMessage 'Success' "Profilo copiato manualmente."
            }

            Write-Host ""
            Write-StyledMessage 'Warning' "═══════════════════════════════════════════════════════════════"
            Write-StyledMessage 'Warning' "  ATTENZIONE: È NECESSARIO RIAVVIARE IL SISTEMA!"
            Write-StyledMessage 'Warning' "═══════════════════════════════════════════════════════════════"
            Write-Host ""
            Write-StyledMessage 'Info' "Il riavvio è necessario per:"
            Write-Host "  • Caricare correttamente oh-my-posh nel PATH" -ForegroundColor Cyan
            Write-Host "  • Caricare correttamente zoxide nel PATH" -ForegroundColor Cyan
            Write-Host "  • Applicare tutti i font installati" -ForegroundColor Cyan
            Write-Host "  • Attivare completamente il nuovo profilo PowerShell" -ForegroundColor Cyan
            Write-Host ""

            $restart = Read-Host "Vuoi riavviare il sistema ORA per applicare tutte le modifiche? (S/N)"

            if ($restart -match '^[SsYy]') {
                Write-StyledMessage 'Warning' "Riavvio del sistema in corso..."
                for ($i = 5; $i -gt 0; $i--) {
                    Write-Host "Riavvio tra $i secondi... (Premi Ctrl+C per annullare)" -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }

                Write-StyledMessage 'Info' "Riavvio del sistema..."
                Restart-Computer -Force
            }
            else {
                Write-Host ""
                Write-StyledMessage 'Warning' "═══════════════════════════════════════════════════════════════"
                Write-StyledMessage 'Warning' "  RIAVVIO POSTICIPATO"
                Write-StyledMessage 'Warning' "═══════════════════════════════════════════════════════════════"
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
        Write-StyledMessage 'Error' "Errore durante l'installazione del profilo: $($_.Exception.Message)"
        if (Test-Path "$env:TEMP\Microsoft.PowerShell_profile.ps1") {
            Remove-Item "$env:TEMP\Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
        }
        try { Stop-Transcript | Out-Null } catch {}
    }
}

WinInstallPSProfile