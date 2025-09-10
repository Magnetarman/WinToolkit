function WinInstallPSProfile {
    $Host.UI.RawUI.WindowTitle = "InstallPSProfile by MagnetarMan"
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
        '        Version 2.0 (Build 5)'
    )
    foreach ($line in $asciiArt) {
        Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
    }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''

    # Controlla se lo script è eseguito come amministratore
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-StyledMessage 'Warning' "L'installazione del profilo PowerShell richiede privilegi di amministratore."
        Write-StyledMessage 'Info' "Riavvio come amministratore..."
        
        # Rilancia lo script corrente come amministratore
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
        # Verifica se PowerShell Core è disponibile
        if (-not (Get-Command "pwsh" -ErrorAction SilentlyContinue)) {
            Write-StyledMessage 'Error' "Questo profilo richiede PowerShell Core, che non è attualmente installato!"
            return
        }
        
        # Verifica la versione di PowerShell
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-StyledMessage 'Warning' "Questo profilo richiede PowerShell 7 o superiore."
            
            # Chiedi conferma per procedere comunque
            $choice = Read-Host "Vuoi procedere comunque con l'installazione per PowerShell 7? (S/N)"
            if ($choice -notmatch '^[SsYy]') {
                Write-StyledMessage 'Info' "Installazione annullata dall'utente."
                return
            }
        }
        
        # URL del profilo per il controllo degli aggiornamenti
        $profileUrl = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        
        # Ottieni l'hash del profilo corrente (se esiste)
        $oldHash = $null
        if (Test-Path $PROFILE) {
            $oldHash = Get-FileHash $PROFILE -ErrorAction SilentlyContinue
        }
        
        # Scarica il nuovo profilo nella cartella TEMP per confronto
        Write-StyledMessage 'Info' "Controllo aggiornamenti profilo..."
        $tempProfile = "$env:TEMP\Microsoft.PowerShell_profile.ps1"
        Invoke-RestMethod $profileUrl -OutFile $tempProfile -UseBasicParsing
        
        # Ottieni l'hash del nuovo profilo
        $newHash = Get-FileHash $tempProfile
        
        # Crea la directory del profilo se non esiste
        $profileDir = Split-Path $PROFILE -Parent
        if (!(Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        
        # Salva l'hash per riferimenti futuri
        if (!(Test-Path "$PROFILE.hash")) {
            $newHash.Hash | Out-File "$PROFILE.hash"
        }
        
        # Controlla se il profilo deve essere aggiornato
        if ($newHash.Hash -ne $oldHash.Hash) {
            
            # Backup del profilo esistente
            if ((Test-Path $PROFILE) -and (-not (Test-Path "$PROFILE.bak"))) {
                Write-StyledMessage 'Info' "Backup del profilo esistente..."
                Copy-Item -Path $PROFILE -Destination "$PROFILE.bak" -Force
                Write-StyledMessage 'Success' "Backup completato."
            }
            
            # QUESTO È IL PUNTO CRUCIALE: esegui lo script di SETUP, non solo scaricare il profilo
            Write-StyledMessage 'Info' "Installazione profilo e dipendenze (oh-my-posh, font, ecc.)..."
            
            # Esegui lo script di setup che installa tutto (oh-my-posh, font, dipendenze)
            Start-Process -FilePath "pwsh" `
                          -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1')`"" `
                          -Wait
            
            Write-StyledMessage 'Success' "Profilo PowerShell installato correttamente!"
            Write-StyledMessage 'Warning' "Riavvia PowerShell per applicare il nuovo profilo."
            Write-StyledMessage 'Info' "Per vedere tutte le modifiche (font, oh-my-posh, ecc.) è consigliato riavviare il sistema."
            
            # Chiedi se riavviare il sistema
            Write-Host ""
            $restart = Read-Host "Vuoi riavviare il sistema ora per applicare tutte le modifiche? (Y/N)"
            
            if ($restart -match '^[YySs]') {
                Write-StyledMessage 'Warning' "Riavvio del sistema in corso..."
                
                # Countdown di 5 secondi
                for ($i = 5; $i -gt 0; $i--) {
                    Write-Host "Riavvio tra $i secondi..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
                
                # Riavvia il sistema
                Write-StyledMessage 'Info' "Riavvio del sistema..."
                Restart-Computer -Force
            } else {
                Write-StyledMessage 'Info' "Riavvio annullato. Ricorda di riavviare il sistema per vedere tutte le modifiche."
            }
        } else {
            Write-StyledMessage 'Info' "Il profilo è già aggiornato alla versione più recente."
        }
        
        # Pulisci il file temporaneo
        Remove-Item $tempProfile -Force -ErrorAction SilentlyContinue
        
    }
    catch {
        Write-StyledMessage 'Error' "Errore durante l'installazione del profilo: $($_.Exception.Message)"
        
        # Pulisci i file temporanei in caso di errore
        if (Test-Path "$env:TEMP\Microsoft.PowerShell_profile.ps1") {
            Remove-Item "$env:TEMP\Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
        }
    }
}