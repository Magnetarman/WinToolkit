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
        '        Version 2.2.2 (Build 3)'
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
                winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements --silent
                Write-StyledMessage 'Success' "oh-my-posh installato correttamente."
            }
            catch {
                Write-StyledMessage 'Warning' "Installazione oh-my-posh fallita, tentativo alternativo..."
                try {
                    # Fallback: download and install manually
                    $ohMyPoshUrl = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/oh-my-posh.zip"
                    $zipPath = "$env:TEMP\oh-my-posh.zip"
                    Invoke-WebRequest -Uri $ohMyPoshUrl -OutFile $zipPath
                    Expand-Archive -Path $zipPath -DestinationPath "$env:LOCALAPPDATA\Microsoft\WindowsApps" -Force
                    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
                    Write-StyledMessage 'Success' "oh-my-posh installato tramite download diretto."
                }
                catch {
                    Write-StyledMessage 'Error' "Impossibile installare oh-my-posh: $($_.Exception.Message)"
                }
            }

            # Install zoxide
            try {
                Write-StyledMessage 'Info' "Installazione zoxide..."
                winget install ajeetdsouza.zoxide -s winget --accept-package-agreements --accept-source-agreements --silent
                Write-StyledMessage 'Success' "zoxide installato correttamente."
            }
            catch {
                Write-StyledMessage 'Warning' "Installazione zoxide fallita, tentativo tramite cargo..."
                try {
                    # Fallback: install via cargo if Rust is available
                    if (Get-Command cargo -ErrorAction SilentlyContinue) {
                        cargo install zoxide --locked
                        Write-StyledMessage 'Success' "zoxide installato tramite cargo."
                    }
                    else {
                        Write-StyledMessage 'Warning' "Cargo non disponibile. Installa manualmente zoxide da: https://github.com/ajeetdsouza/zoxide"
                    }
                }
                catch {
                    Write-StyledMessage 'Error' "Impossibile installare zoxide: $($_.Exception.Message)"
                }
            }

            # Installazione profilo tramite script ChrisTitusTech
            Write-StyledMessage 'Info' "Installazione profilo PowerShell..."
            try {
                Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1' -UseBasicParsing)
                Write-StyledMessage 'Success' "Profilo PowerShell installato correttamente!"
            }
            catch {
                Write-StyledMessage 'Warning' "Installazione profilo fallita, copia manuale del profilo..."
                Copy-Item -Path $tempProfile -Destination $PROFILE -Force
                Write-StyledMessage 'Success' "Profilo copiato manualmente."
            }

            Write-StyledMessage 'Warning' "Riavvia PowerShell per applicare il nuovo profilo."
            Write-StyledMessage 'Info' "Per vedere tutte le modifiche (font, oh-my-posh, ecc.) è consigliato riavviare il sistema."

            Write-Host ""
            $restart = Read-Host "Vuoi riavviare il sistema ora per applicare tutte le modifiche? (Y/N)"

            if ($restart -match '^[YySs]') {
                Write-StyledMessage 'Warning' "Riavvio del sistema in corso..."
                for ($i = 5; $i -gt 0; $i--) {
                    Write-Host "Riavvio tra $i secondi..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }

                Write-StyledMessage 'Info' "Riavvio del sistema..."
                Restart-Computer -Force
            }
            else {
                Write-StyledMessage 'Info' "Riavvio annullato. Ricorda di riavviare il sistema per vedere tutte le modifiche."
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