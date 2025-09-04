<#
.SYNOPSIS
    Un toolkit di avvio per eseguire script di manutenzione di Windows.
.DESCRIPTION
    Questo script funge da menu principale per un insieme di strumenti di manutenzione e gestione di Windows.
    Permette agli utenti di selezionare ed eseguire vari script PowerShell per compiti specifici.
.NOTES
  Versione 2.0 (Build 37) - 2025-09-04
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

# Funzione per installare il profilo PowerShell
function Invoke-WinUtilInstallPSProfile {
    Write-StyledMessage -Type 'Info' -Text "Avvio configurazione profilo PowerShell 7..."
    
    # Define the URL used to download Chris Titus Tech's PowerShell profile.
    $url = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"

    # Define the path to the PowerShell profile to make sure it's not null.
    $profilePath = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    $profileDir = Split-Path -Path $profilePath -Parent
    
    # Check if PowerShell Core (pwsh) is installed and available as a command.
    if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
        # Ensure the directory for the new profile exists.
        if (-not (Test-Path $profileDir)) {
            Write-StyledMessage -Type 'Info' -Text "Creazione della directory del profilo: $profileDir"
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        }
        
        # Get the file hash for the user's current PowerShell profile, but only if the file exists.
        $OldHash = $null
        if (Test-Path $profilePath) {
            try {
                $OldHash = Get-FileHash $profilePath -ErrorAction SilentlyContinue
            } catch {
                Write-StyledMessage -Type 'Warning' -Text "Impossibile ottenere l'hash del profilo esistente. Proveremo a reinstallare."
            }
        }

        # Download Chris Titus Tech's PowerShell profile to the 'TEMP' folder.
        $tempProfilePath = "$env:TEMP\Microsoft.PowerShell_profile.ps1"
        try {
            Invoke-RestMethod $url -OutFile $tempProfilePath
        } catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante il download del profilo. Controlla la tua connessione a Internet."
            return
        }

        # Get the file hash for Chris Titus Tech's PowerShell profile.
        $NewHash = Get-FileHash $tempProfilePath

        # Compare the hashes. If no old profile existed, this will be true.
        if (-not $OldHash -or ($NewHash.Hash -ne $OldHash.Hash)) {
            Write-StyledMessage -Type 'Info' -Text "Il profilo non esiste o non è aggiornato. Installazione in corso."
            
            # Perform profile backup logic.
            if (Test-Path "$env:USERPROFILE\oldprofile.ps1") {
                Write-Host "===> Backup File Exists... <===" -ForegroundColor Yellow
                Write-Host "===> Moving Backup File... <===" -ForegroundColor Yellow
                Copy-Item "$env:USERPROFILE\oldprofile.ps1" "$profilePath.bak"
                Write-Host "===> Profile Backup: Done. <===" -ForegroundColor Yellow
            } elseif ((Test-Path $profilePath) -and (-not (Test-Path "$profilePath.bak"))) {
                Write-Host "===> Backing Up Profile... <===" -ForegroundColor Yellow
                Copy-Item -Path $profilePath -Destination "$profilePath.bak"
                Write-Host "===> Profile Backup: Done. <===" -ForegroundColor Yellow
            }

            # Let the user know Chris Titus Tech's PowerShell profile is being installed.
            Write-Host "===> Installing Profile... <===" -ForegroundColor Yellow

            # Start a new hidden PowerShell instance for setup.
            Start-Process -FilePath "pwsh" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"Invoke-Expression (Invoke-WebRequest `'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1`')`"" -WindowStyle Hidden -Wait

            # Let the user know Chris Titus Tech's PowerShell profile has been installed successfully.
            Write-Host "Profile has been installed. Please restart your shell to reflect the changes!" -ForegroundColor Magenta

            # Let the user know Chris Titus Tech's PowerShell profile has been setup successfully.
            Write-Host "===> Finished Profile Setup <===" -ForegroundColor Yellow
        } else {
            # Let the user know Chris Titus Tech's PowerShell profile is already fully up-to-date.
            Write-Host "Profile is up to date" -ForegroundColor Magenta
        }
    } else {
        # Let the user know that the profile requires PowerShell Core but it is not currently installed.
        Write-Host "This profile requires Powershell Core, which is currently not installed!" -ForegroundColor Red
    }
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
        '       Version 2.0 (Build 37)'
    )
    foreach ($line in $asciiArt) {
        Write-StyledMessage 'Info' (Center-Text -Text $line -Width $width)
    }
    Write-Host '' # Spazio

    # --- Definizione e visualizzazione del menu ---
    $scripts = @(
        [pscustomobject]@{ Name = 'Invoke-WinUtilInstallPSProfile'; Description = 'Installa il profilo PowerShell. - Fortemente Consigliato'    ; Action = 'RunFunction' }
        [pscustomobject]@{ Name = 'WinRepairToolkit.ps1'; Description = 'Avvia il Toolkit di Riparazione Windows.' ; Action = 'RunFile' }
        [pscustomobject]@{ Name = 'WinUpdateReset.ps1'  ; Description = 'Esegui il Reset di Windows Update.'       ; Action = 'RunFile' }
        [pscustomobject]@{ Name = 'WinReinstallStore.ps1'; Description = 'Reinstalla Winget ed il Windows Store.'    ; Action = 'RunFile' }
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