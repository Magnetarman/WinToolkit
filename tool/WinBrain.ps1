<#
.SYNOPSIS
    Un toolkit di avvio per eseguire script di manutenzione di Windows.
.DESCRIPTION
    Questo script funge da menu principale per un insieme di strumenti di manutenzione e gestione di Windows.
    Permette agli utenti di selezionare ed eseguire vari script PowerShell per compiti specifici.
.NOTES
  Versione 2.0 (Build 54) - 2025-09-04
#>
# Imposta il titolo della finestra di PowerShell per un'identificazione immediata.
$Host.UI.RawUI.WindowTitle = "Win Toolkit by MagnetarMan v2.0"

# Imposta una gestione degli errori più rigorosa per lo script.
# 'Stop' interrompe l'esecuzione in caso di errore, permettendo una gestione controllata tramite try/catch.
$ErrorActionPreference = 'Stop'

# Creazione directory di log e avvio trascrizione
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\WinToolkit\logs"
try {
    [System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
    Start-Transcript -Path "$logdir\WinToolkit_$dateTime.log" -Append -Force | Out-Null
} catch {
    # Gestione errori silenziosa per compatibilità
}

function Write-StyledMessage {
    <#
    .SYNOPSIS
        Scrive un messaggio formattato sulla console con icone e colori.
    .PARAMETER Type
        Il tipo di messaggio (Success, Warning, Error, Info).
    .PARAMETER Text
        Il testo del messaggio da visualizzare.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Warning', 'Error', 'Info')]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    # Definisce gli stili per ogni tipo di messaggio. L'uso degli emoji migliora la leggibilità.
    $styles = @{
        Success = @{ Color = 'Green' ; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'   ; Icon = '❌' }
        Info    = @{ Color = 'Cyan'  ; Icon = '💎' }
    }

    $style = $styles[$Type]
    Write-Host "$($style.Icon) $($Text)" -ForegroundColor $style.Color
}

function Center-Text {
    <#
    .SYNOPSIS
        Centra una stringa di testo data una larghezza specifica.
    .PARAMETER Text
        Il testo da centrare.
    .PARAMETER Width
        La larghezza totale del contenitore.
    #>
    param(
        [string]$Text,
        [int]$Width = 60
    )

    if ($Text.Length -ge $Width) { return $Text }

    $padding = ' ' * [Math]::Floor(($Width - $Text.Length) / 2)
    return "$($padding)$($Text)"
}

# Funzione per installare il profilo PowerShell
function WinInstallPSProfile {
    <#
    .SYNOPSIS
        Installa il profilo PowerShell di Chris Titus Tech.
    #>
    
    Write-StyledMessage 'Info' "Installazione del profilo PowerShell in corso..."
    
    # URL del profilo e dello script di setup
    $profileUrl = 'https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1'
    $setupUrl = 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1'
    
    try {
        # Verifica se PowerShell 7+ è disponibile
        if (-not (Get-Command "pwsh" -ErrorAction SilentlyContinue)) {
            Write-StyledMessage 'Error' "Questo profilo richiede PowerShell Core, che non è attualmente installato!"
            return
        }
        
        # Verifica la versione di PowerShell
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-StyledMessage 'Warning' "Questo profilo richiede PowerShell 7 o superiore. Versione attuale: $($PSVersionTable.PSVersion)"
            
            # Chiedi conferma per procedere comunque
            $choice = Read-Host "Vuoi procedere comunque con l'installazione per PowerShell 7? (S/N)"
            if ($choice -notmatch '^[SsYy]') {
                Write-StyledMessage 'Info' "Installazione annullata dall'utente."
                return
            }
        }
        
        # Ottieni l'hash del profilo corrente (se esiste)
        $currentProfile = $PROFILE
        $oldHash = $null
        if (Test-Path $currentProfile) {
            $oldHash = Get-FileHash $currentProfile -ErrorAction SilentlyContinue
        }
        
        # Scarica il nuovo profilo nella cartella TEMP per confronto
        $tempProfile = "$env:TEMP\Microsoft.PowerShell_profile.ps1"
        Invoke-RestMethod $profileUrl -OutFile $tempProfile -UseBasicParsing
        
        # Ottieni l'hash del nuovo profilo
        $newHash = Get-FileHash $tempProfile
        
        # Controlla se il profilo è già aggiornato
        if ($oldHash -and $newHash.Hash -eq $oldHash.Hash) {
            Write-StyledMessage 'Info' "Il profilo è già aggiornato alla versione più recente."
            Remove-Item $tempProfile -Force
            return
        }
        
        # Backup del profilo esistente
        if ((Test-Path $currentProfile) -and (-not (Test-Path "$currentProfile.bak"))) {
            Write-StyledMessage 'Info' "Backup del profilo esistente in corso..."
            Copy-Item -Path $currentProfile -Destination "$currentProfile.bak" -Force
            Write-StyledMessage 'Success' "Backup del profilo completato."
        }
        
        # Esegui lo script di setup di Chris Titus Tech
        Write-StyledMessage 'Info' "Esecuzione dello script di installazione..."
        
        $setupCommand = "Invoke-Expression (Invoke-WebRequest '$setupUrl' -UseBasicParsing).Content"
        
        Start-Process -FilePath "pwsh" `
                      -ArgumentList @(
                          "-ExecutionPolicy", "Bypass",
                          "-NoProfile",
                          "-Command", $setupCommand
                      ) `
                      -WindowStyle Hidden -Wait
        
        # Salva l'hash del nuovo profilo per confronti futuri
        $hashFile = "$currentProfile.hash"
        $newHash.Hash | Out-File $hashFile -Force
        
        # Pulisci il file temporaneo
        Remove-Item $tempProfile -Force -ErrorAction SilentlyContinue
        
        Write-StyledMessage 'Success' "Profilo PowerShell installato correttamente!"
        Write-StyledMessage 'Warning' "Riavvia PowerShell per applicare il nuovo profilo."
        
    }
    catch {
        Write-StyledMessage 'Error' "Errore durante l'installazione del profilo: $($_.Exception.Message)"
        
        # Pulisci i file temporanei in caso di errore
        if (Test-Path "$env:TEMP\Microsoft.PowerShell_profile.ps1") {
            Remove-Item "$env:TEMP\Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
        }
    }
}




# Ciclo principale del programma: mostra il menu e attende una scelta.
# L'uso di un ciclo `while ($true)` semplifica la logica per tornare al menu principale.
while ($true) {
    Clear-Host

    # --- Schermata di Benvenuto ---
    $width = 60
    $asciiArt = @(
        ' __        __  _  _   _ '
        ' \ \      / / | || \ | |'
        '  \ \ /\ / /  | ||  \| |'
        '   \ V  V /   | || |\  |'
        '    \_/\_/    |_||_| \_|'
        ''
        '    Toolkits By MagnetarMan'
        '      Version 2.0 (Build 54)'
    )
    foreach ($line in $asciiArt) {
        Write-StyledMessage 'Info' (Center-Text -Text $line -Width $width)
    }
    Write-Host '' # Spazio

    # --- Definizione e visualizzazione del menu ---
    $scripts = @(
        [pscustomobject]@{ Name = 'WinInstallPSProfile'; Description = 'Installa il profilo PowerShell. - Fortemente Consigliato' ; Action = 'RunFunction' }
        [pscustomobject]@{ Name = 'WinRepairToolkit.ps1'; Description = 'Avvia il Toolkit di Riparazione Windows.' ; Action = 'RunFile' }
        [pscustomobject]@{ Name = 'WinUpdateReset.ps1'  ; Description = 'Esegui il Reset di Windows Update.'       ; Action = 'RunFile' }
        [pscustomobject]@{ Name = 'WinReinstallStore.ps1'; Description = 'Reinstalla Winget ed il Windows Store.'  ; Action = 'RunFile' }
        ) 

    Write-StyledMessage 'Warning' 'Seleziona lo script da avviare:'
    for ($i = 0; $i -lt $scripts.Count; $i++) {
        Write-StyledMessage 'Info' ("[$($i + 1)] $($scripts[$i].Description)")
    }
    Write-StyledMessage 'Error' '[0] Esci dal Toolkit'
    Write-Host '' # Spazio

    # --- Logica di gestione della scelta utente ---
    $userChoice = Read-Host "Inserisci il numero della tua scelta"

    if ($userChoice -eq '0') {
        Write-StyledMessage 'Warning' 'In caso di problemi, contatta MagnetarMan su GitHub.'
        Write-StyledMessage 'Success' 'Grazie per aver usato il toolkit. Chiusura in corso...'
        Start-Sleep -Seconds 2
        break # Esce dal ciclo while ($true) e termina lo script.
    }

    # Verifica se l'input è un numero valido e rientra nel range delle opzioni.
    if (($userChoice -match '^\d+$') -and ([int]$userChoice -ge 1) -and ([int]$userChoice -le $scripts.Count)) {
        $selectedIndex = [int]$userChoice - 1
        $selectedItem = $scripts[$selectedIndex]

        Write-StyledMessage 'Info' "Avvio di '$($selectedItem.Description)'..."
        try {
            if ($selectedItem.Action -eq 'RunFile') {
                $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath $selectedItem.Name
                if (Test-Path $scriptPath) {
                    & $scriptPath
                } else {
                    Write-StyledMessage 'Error' "Script '$($selectedItem.Name)' non trovato nella directory '$($PSScriptRoot)'."
                }
            } elseif ($selectedItem.Action -eq 'RunFunction') {
                Invoke-Expression "$($selectedItem.Name)"
            }
        }
        catch {
            Write-StyledMessage 'Error' "Si è verificato un errore durante l'esecuzione dell'opzione selezionata."
            Write-StyledMessage 'Error' "Dettagli: $($_.Exception.Message)"
        }
        
        # Pausa prima di tornare al menu principale
        Write-Host "`nPremi un tasto per tornare al menu principale..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    else {
        Write-StyledMessage 'Error' 'Scelta non valida. Riprova.'
        Start-Sleep -Seconds 2
    }
}
