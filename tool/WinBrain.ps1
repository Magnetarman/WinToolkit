<#
.SYNOPSIS
    Un toolkit di avvio per eseguire script di manutenzione di Windows.
.DESCRIPTION
    Questo script funge da menu principale per un insieme di strumenti di manutenzione e gestione di Windows.
    Permette agli utenti di selezionare ed eseguire vari script PowerShell per compiti specifici.
.NOTES
  Versione 2.0 (Build 40) - 2025-09-04
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
    <#
    .SYNOPSIS
        Backs up your original profile then installs and applies the CTT PowerShell profile.
    #>

    # Remap the automatic built-in $PROFILE variable to the parameter named $PSProfile.
    $PSProfile = $PROFILE

        function Invoke-PSSetup {
            # Define the URL used to download Chris Titus Tech's PowerShell profile.
            $url = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
    
            # Ensure the profile directory exists
            $profileDir = Split-Path -Parent $PSProfile
            if (!(Test-Path $profileDir)) {
                New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
            }
    
            # Get the file hash for the user's current PowerShell profile.
            $OldHash = Get-FileHash $PSProfile -ErrorAction SilentlyContinue

            # Download Chris Titus Tech's PowerShell profile to the 'TEMP' folder.
            Invoke-RestMethod $url -OutFile "$env:TEMP/Microsoft.PowerShell_profile.ps1"

            # Get the file hash for Chris Titus Tech's PowerShell profile.
            $NewHash = Get-FileHash "$env:TEMP/Microsoft.PowerShell_profile.ps1"

            # Store the file hash of Chris Titus Tech's PowerShell profile.
            if (!(Test-Path "$PSProfile.hash")) {
                $NewHash.Hash | Out-File "$PSProfile.hash"
            }

            # Check if the new profile's hash doesn't match the old profile's hash.
            if ($NewHash.Hash -ne $OldHash.Hash) {
                # Check if oldprofile.ps1 exists and use it as a profile backup source.
                if (Test-Path "$env:USERPROFILE\oldprofile.ps1") {
                    Write-Host "===> Backup File Exists... <===" -ForegroundColor Yellow
                    Write-Host "===> Moving Backup File... <===" -ForegroundColor Yellow
                    Copy-Item "$env:USERPROFILE\oldprofile.ps1" "$PSProfile.bak"
                    Write-Host "===> Profile Backup: Done. <===" -ForegroundColor Yellow
                } else {
                    # If oldprofile.ps1 does not exist use $PSProfile as a profile backup source.
                    # Check if the profile backup file has not already been created on the disk.
                    if ((Test-Path $PSProfile) -and (-not (Test-Path "$PSProfile.bak"))) {
                        # Let the user know their PowerShell profile is being backed up.
                        Write-Host "===> Backing Up Profile... <===" -ForegroundColor Yellow

                        # Copy the user's current PowerShell profile to the backup file path.
                        Copy-Item -Path $PSProfile -Destination "$PSProfile.bak"

                        # Let the user know the profile backup has been completed successfully.
                        Write-Host "===> Profile Backup: Done. <===" -ForegroundColor Yellow
                    }
                }

                # Let the user know Chris Titus Tech's PowerShell profile is being installed.
                Write-Host "===> Installing Profile... <===" -ForegroundColor Yellow

                # Start a new hidden PowerShell instance because setup.ps1 does not work in runspaces.
                Start-Process -FilePath "pwsh" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"Invoke-Expression (Invoke-WebRequest `'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1`')`"" -WindowStyle Hidden -Wait

                # Let the user know Chris Titus Tech's PowerShell profile has been installed successfully.
                Write-Host "Profile has been installed. Please restart your shell to reflect the changes!" -ForegroundColor Magenta

                # Let the user know Chris Titus Tech's PowerShell profile has been setup successfully.
                Write-Host "===> Finished Profile Setup <===" -ForegroundColor Yellow
            } else {
                # Let the user know Chris Titus Tech's PowerShell profile is already fully up-to-date.
                Write-Host "Profile is up to date" -ForegroundColor Magenta
            }
        }

        # Check if PowerShell Core is currently installed as a program and is available as a command.
        if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
            # Check if the version of PowerShell Core currently in use is version 7 or higher.
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                # Invoke the PowerShell Profile setup script to install Chris Titus Tech's PowerShell Profile.
                Invoke-PSSetup
            } else {
                # Let the user know that PowerShell 7 is installed but is not currently in use.
                Write-Host "This profile requires Powershell 7, which is currently installed but not used!" -ForegroundColor Red

                # Load the necessary .NET library required to use Windows Forms to show dialog boxes.
                Add-Type -AssemblyName System.Windows.Forms

                # Display the message box asking if the user wants to install PowerShell 7 or not.
                $question = [System.Windows.Forms.MessageBox]::Show(
                    "Profile requires Powershell 7, which is currently installed but not used! Do you want to install the profile for Powershell 7?",
                    "Question",
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Question
                )

                # Proceed with the installation and setup of the profile as the user pressed the 'Yes' button.
                if ($question -eq [System.Windows.Forms.DialogResult]::Yes) {
                    Invoke-PSSetup
                } else {
                    # Let the user know the setup of the profile will not proceed as they pressed the 'No' button.
                    Write-Host "Not proceeding with the profile setup!" -ForegroundColor Magenta
                }
            }
        } else {
            # Let the user know that the profile requires PowerShell Core but it is not currently installed.
            Write-Host "This profile requires Powershell Core, which is currently not installed!" -ForegroundColor Red
        }
        }

    # Call the logic directly instead of using a runspace
    # Remap the automatic built-in $PROFILE variable to the parameter named $PSProfile.
    $PSProfile = $PROFILE

    function Invoke-PSSetup {
        # Define the URL used to download Chris Titus Tech's PowerShell profile.
        $url = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"

        # Get the file hash for the user's current PowerShell profile.
        $OldHash = Get-FileHash $PSProfile -ErrorAction SilentlyContinue

        # Download Chris Titus Tech's PowerShell profile to the 'TEMP' folder.
        Invoke-RestMethod $url -OutFile "$env:TEMP/Microsoft.PowerShell_profile.ps1"

        # Get the file hash for Chris Titus Tech's PowerShell profile.
        $NewHash = Get-FileHash "$env:TEMP/Microsoft.PowerShell_profile.ps1"

        # Store the file hash of Chris Titus Tech's PowerShell profile.
        if (!(Test-Path "$PSProfile.hash")) {
            $NewHash.Hash | Out-File "$PSProfile.hash"
        }

        # Check if the new profile's hash doesn't match the old profile's hash.
        if ($NewHash.Hash -ne $OldHash.Hash) {
            # Check if oldprofile.ps1 exists and use it as a profile backup source.
            if (Test-Path "$env:USERPROFILE\oldprofile.ps1") {
                Write-Host "===> Backup File Exists... <===" -ForegroundColor Yellow
                Write-Host "===> Moving Backup File... <===" -ForegroundColor Yellow
                Copy-Item "$env:USERPROFILE\oldprofile.ps1" "$PSProfile.bak"
                Write-Host "===> Profile Backup: Done. <===" -ForegroundColor Yellow
            } else {
                # If oldprofile.ps1 does not exist use $PSProfile as a profile backup source.
                # Check if the profile backup file has not already been created on the disk.
                if ((Test-Path $PSProfile) -and (-not (Test-Path "$PSProfile.bak"))) {
                    # Let the user know their PowerShell profile is being backed up.
                    Write-Host "===> Backing Up Profile... <===" -ForegroundColor Yellow

                    # Copy the user's current PowerShell profile to the backup file path.
                    Copy-Item -Path $PSProfile -Destination "$PSProfile.bak"

                    # Let the user know the profile backup has been completed successfully.
                    Write-Host "===> Profile Backup: Done. <===" -ForegroundColor Yellow
                }
            }

            # Let the user know Chris Titus Tech's PowerShell profile is being installed.
            Write-Host "===> Installing Profile... <===" -ForegroundColor Yellow

            # Start a new hidden PowerShell instance because setup.ps1 does not work in runspaces.
            Start-Process -FilePath "pwsh" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"Invoke-Expression (Invoke-WebRequest `'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1`')`"" -WindowStyle Hidden -Wait

            # Let the user know Chris Titus Tech's PowerShell profile has been installed successfully.
            Write-Host "Profile has been installed. Please restart your shell to reflect the changes!" -ForegroundColor Magenta

            # Let the user know Chris Titus Tech's PowerShell profile has been setup successfully.
            Write-Host "===> Finished Profile Setup <===" -ForegroundColor Yellow
        } else {
            # Let the user know Chris Titus Tech's PowerShell profile is already fully up-to-date.
            Write-Host "Profile is up to date" -ForegroundColor Magenta
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
        '      Version 2.0 (Build 40)'
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