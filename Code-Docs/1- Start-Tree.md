# Start.ps1 Tree

## Prompt

Genera un unico e completo script PowerShell, che sia pienamente supportato da PowerShell 5.1, per un'applicazione denominata "Win Toolkit". Lo script deve incorporare tutte le porzioni di codice fornite di seguito, unificandone stile, logica e tono.

Analizza attentamente i blocchi di codice forniti dopo i titoli ### Code, che rappresentano porzioni di script funzionanti ma slegate. Il tuo compito è integrarli in modo coerente e logico nel nuovo script, modificando la logica esistente dove necessario.

Lo script finale dovrà seguire questa struttura e rispettare le seguenti regole:

Struttura e Logica dello Script
Impostazioni e Log:

Mantieni il titolo della finestra della console su "Win Toolkit by MagnetarMan".

Crea una directory di log in $env:localappdata\WinToolkit\logs se non esiste.

Avvia una trascrizione (Start-Transcript) del log in un file con un nome basato sulla data e ora correnti, ad esempio WinToolkit_yyyy-MM-dd_HH-mm-ss.log. Assicurati che il comando non generi errori se il file esiste già e che sia compatibile con PowerShell 5.1.

Funzione di Messaggistica:

Integra la funzione Write-StyledMessage per la visualizzazione di messaggi formattati. Assicurati che l'uso di questa funzione sostituisca tutti i comandi Write-Host o Write-Output esistenti nelle altre sezioni dello script, in modo da avere un'interfaccia utente uniforme e professionale. Ad esempio:

Write-Host "Installing Powershell 7..." diventerà Write-StyledMessage -Type Info -Text "Installing Powershell 7...".

Write-Host "Profile is up to date" -ForegroundColor Magenta diventerà Write-StyledMessage -Type Success -Text "Profile is up to date".

Controllo Amministratore:

Verifica che lo script sia eseguito con i privilegi di amministratore.

Se non è in esecuzione come amministratore, rilancia lo script con il verbo RunAs. La logica per la ricreazione degli argomenti e il rilancio del processo deve essere mantenuta, ma deve essere modificata per utilizzare esclusivamente powershell.exe, visto il requisito di supporto per PowerShell 5.1. Rimuovi qualsiasi riferimento a pwsh o wt.exe.

Utilizza la funzione Write-StyledMessage per l'avviso all'utente, ad esempio: Write-StyledMessage -Type Error -Text "Winutil needs to be run as Administrator. Attempting to relaunch.".

Schermata di Benvenuto:

Pulisci la console (Clear-Host).

Visualizza la schermata di benvenuto "Win Toolkits v2.0" e "By MagnetarMan", mantenendo l'allineamento e i colori originali.

Integrazione Funzioni:

Modifica e integra la logica delle funzioni Invoke-WPFTweakPS7 e Install-CTTPowerShellProfile.

L'obiettivo generale dello script è supportare PowerShell 5.1, quindi le porzioni di codice che installano, verificano o interagiscono specificamente con PowerShell 7 devono essere rese compatibili o gestite in modo appropriato per un ambiente PS 5.1.

La funzione Invoke-WPFTweakPS7 ha una dipendenza da winget e gestisce i file di configurazione di Windows Terminal, che non sono strettamente necessari per uno script che mira a funzionare in PowerShell 5.1. Modifica la logica di questa funzione per concentrarsi esclusivamente sul controllo dell'installazione di PowerShell 7 (Test-Path -Path "$env:ProgramFiles\PowerShell\7") e, se non presente, informare l'utente che è necessario installare PS7 per le funzionalità avanzate, ma senza tentare l'installazione automatica. Questo è fondamentale per la compatibilità con PS5.

La funzione Install-CTTPowerShellProfile deve essere modificata per rimuovere qualsiasi dipendenza da pwsh e Invoke-WPFRunspace. Poiché lo script deve funzionare in PowerShell 5.1, la logica che verifica se il profilo richiede PS7 deve essere mantenuta, ma la chiamata a Start-Process per eseguire setup.ps1 deve essere modificata per usare powershell.exe. Rimuovi completamente l'interazione con System.Windows.Forms.MessageBox e sostituiscila con Write-StyledMessage per un'interfaccia coerente.

Avviso Utente Finale:

Aggiungi un'ultima sezione che utilizza Write-StyledMessage per avvisare l'utente che l'esecuzione dello script è terminata e che la trascrizione del log è stata salvata.

## Check Admin

### Code

```powershell
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "Winutil needs to be run as Administrator. Attempting to relaunch."
    $argList = @()

    $PSBoundParameters.GetEnumerator() | ForEach-Object {
        $argList += if ($_.Value -is [switch] -and $_.Value) {
            "-$($_.Key)"
        } elseif ($_.Value -is [array]) {
            "-$($_.Key) $($_.Value -join ',')"
        } elseif ($_.Value) {
            "-$($_.Key) '$($_.Value)'"
        }
    }

    $script = if ($PSCommandPath) {
        "& { & `'$($PSCommandPath)`' $($argList -join ' ') }"
    } else {
        "&([ScriptBlock]::Create((irm https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/start.ps1))) $($argList -join ' ')"
    }

    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { "$powershellCmd" }

    if ($processCmd -eq "wt.exe") {
        Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    } else {
        Start-Process $processCmd -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    }

    break
}
```

## Cambio Nome Finestra

## Code

```powershell
$Host.UI.RawUI.WindowTitle = "Win Toolkit by MagnetarMan"
```

## Generazione File Log

### Code

```powershell
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\WinToolkit\logs"
[System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
Start-Transcript -Path "$logdir\WinToolkit_$dateTime.log" -Append -NoClobber | Out-Null
```

## Schemata di Benvenuto

### Code

```powershell
Clear-Host
Write-Host ('Win Toolkit v2.0').PadLeft(40) -ForegroundColor Green
Write-Host ('By MagnetarMan').PadLeft(30) -ForegroundColor Red
Write-Host ''

```

## Controllo PS7

### Code

```powershell
  # Verifica versione PowerShell
    $psVersion = $PSVersionTable.PSVersion.Major
    Write-StyledMessage -Type 'Info' -Text "Versione PowerShell rilevata: $($PSVersionTable.PSVersion)"

    if ($psVersion -lt 7) {
        # OPZIONE 1: PowerShell 5 - Installa PowerShell 7
        Write-StyledMessage -Type 'Warning' -Text "PowerShell 5 rilevato. Installazione PowerShell 7 richiesta."

function Invoke-WPFTweakPS7{
        <#
    .SYNOPSIS
        This will edit the config file of the Windows Terminal Replacing the Powershell 5 to Powershell 7 and install Powershell 7 if necessary
    .PARAMETER action
        PS7:           Configures Powershell 7 to be the default Terminal
        PS5:           Configures Powershell 5 to be the default Terminal
    #>
    param (
        [ValidateSet("PS7", "PS5")]
        [string]$action
    )

    switch ($action) {
        "PS7"{
            if (Test-Path -Path "$env:ProgramFiles\PowerShell\7") {
                Write-Host "Powershell 7 is already installed."
            } else {
                Write-Host "Installing Powershell 7..."
                Install-WinUtilProgramWinget -Action Install -Programs @("Microsoft.PowerShell")
            }
            $targetTerminalName = "PowerShell"
        }
        "PS5"{
            $targetTerminalName = "Windows PowerShell"
        }
    }
    # Check if the Windows Terminal is installed and return if not (Prerequisite for the following code)
    if (-not (Get-Command "wt" -ErrorAction SilentlyContinue)) {
        Write-Host "Windows Terminal not installed. Skipping Terminal preference"
        return
    }
    # Check if the Windows Terminal settings.json file exists and return if not (Prereqisite for the following code)
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path -Path $settingsPath)) {
        Write-Host "Windows Terminal Settings file not found at $settingsPath"
        return
    }

    Write-Host "Settings file found."
    $settingsContent = Get-Content -Path $settingsPath | ConvertFrom-Json
    $ps7Profile = $settingsContent.profiles.list | Where-Object { $_.name -eq $targetTerminalName }
    if ($ps7Profile) {
        $settingsContent.defaultProfile = $ps7Profile.guid
        $updatedSettings = $settingsContent | ConvertTo-Json -Depth 100
        Set-Content -Path $settingsPath -Value $updatedSettings
        Write-Host "Default profile updated to " -NoNewline
        Write-Host "$targetTerminalName " -ForegroundColor White -NoNewline
        Write-Host "using the name attribute."
    } else {
        Write-Host "No PowerShell 7 profile found in Windows Terminal settings using the name attribute."
    }
}
}
```

## Add Powershell Profile

### Code

```powershell
function Invoke-WinUtilInstallPSProfile {
    <#
    .SYNOPSIS
        Backs up your original profile then installs and applies the CTT PowerShell profile.
    #>

    Invoke-WPFRunspace -ArgumentList $PROFILE -DebugPreference $DebugPreference -ScriptBlock {
        # Remap the automatic built-in $PROFILE variable to the parameter named $PSProfile.
        param ($PSProfile)

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
}

```

## Avviso Utente

## Code

```powershell
Write-Host "Script di Start eseguito correttamente"
Write-Host "Attenzione il sistema verrà riavviato per rendere effettive le modifiche"
```

## CountDown

## Code

```powershell
# Countdown preparazione
for ($i = 10; $i -gt 0; $i--) {
    Write-Host "Preparazione sistema al riavvio - $i secondi..." -NoNewline -ForegroundColor Yellow
    Start-Sleep 1
}
Write-StyledMessage 'Riavvio in corso...'
Restart-Computer -Force
```
