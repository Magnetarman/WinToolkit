#Requires -Version 5.0
<#
.SYNOPSIS
Script di setup automatico per PowerShell 7 e profilo Chris Titus Tech.

.DESCRIPTION
Questo script:
1. Verifica la versione di PowerShell in uso
2. Installa PowerShell 7 se necessario
3. Verifica i privilegi di amministratore
4. Installa il profilo PowerShell di Chris Titus Tech
5. Avvia lo script WinStarter.ps1
#>

# ============================================================================
# FUNZIONI DI UTILITÀ
# ============================================================================

$Host.UI.RawUI.WindowTitle = "Win Toolkits by MagnetarMan"
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

    # Definisce gli stili per ogni tipo di messaggio. L'uso di simboli migliora la leggibilità.
    $styles = @{
        Success = @{ Color = 'Green' ; Icon = '[OK]' }
        Warning = @{ Color = 'Yellow'; Icon = '[!]' }  
        Error   = @{ Color = 'Red'   ; Icon = '[X]' }
        Info    = @{ Color = 'Cyan'  ; Icon = '[i]' }
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

function Test-AdminPrivileges {
    <#
    .SYNOPSIS
    Verifica se lo script è eseguito con privilegi di amministratore.
    .OUTPUTS
    [bool] True se eseguito come amministratore, False altrimenti.
    #>
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante la verifica dei privilegi: $($_.Exception.Message)"
        return $false
    }
}

function Install-PowerShell7 {
    <#
    .SYNOPSIS
    Installa l'ultima versione di PowerShell 7.
    #>
    try {
        Write-StyledMessage -Type 'Info' -Text "Avvio installazione PowerShell 7..."
        
        # Scarica e installa PowerShell 7 tramite winget se disponibile
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type 'Info' -Text "Utilizzando winget per l'installazione..."
            winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements
        }
        else {
            # Fallback: usa il metodo di installazione tradizionale
            Write-StyledMessage -Type 'Info' -Text "Scaricamento PowerShell 7 dal repository ufficiale..."
            Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
        }
        
        Write-StyledMessage -Type 'Success' -Text "PowerShell 7 installato con successo!"
        return $true
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante l'installazione di PowerShell 7: $($_.Exception.Message)"
        return $false
    }
}

function Install-CTTPowerShellProfile {
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

function Start-WinStarterScript {
    <#
    .SYNOPSIS
    Avvia lo script WinStarter.ps1 dalla sottocartella tool.
    #>
    try {
        # Determina il percorso dello script corrente
        $currentPath = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
        $winStarterPath = Join-Path $currentPath "tool\WinStarter.ps1"
        
        if (Test-Path $winStarterPath) {
            Write-StyledMessage -Type 'Success' -Text "Avvio WinStarter.ps1..."
            
            # Avvia WinStarter con privilegi amministratore in PowerShell 7
            if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
                Start-Process -FilePath "pwsh" -ArgumentList "-ExecutionPolicy Bypass -File `"$winStarterPath`"" -Verb RunAs
            } else {
                Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy Bypass -File `"$winStarterPath`"" -Verb RunAs
            }
            
            Write-StyledMessage -Type 'Info' -Text "WinStarter.ps1 avviato con successo!"
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "File WinStarter.ps1 non trovato in: $winStarterPath"
            return $false
        }
        
        return $true
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante l'avvio di WinStarter.ps1: $($_.Exception.Message)"
        return $false
    }
}

function Request-AdminRestart {
    <#
    .SYNOPSIS
    Richiede il riavvio dello script con privilegi amministratore.
    #>
    Write-StyledMessage -Type 'Warning' -Text "Questo script richiede privilegi di amministratore per funzionare correttamente."
    Write-StyledMessage -Type 'Info' -Text "Premere un tasto per riavviare con privilegi elevati..."
    
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    try {
        # Riavvia lo script corrente con privilegi amministratore
        $currentScript = $MyInvocation.MyCommand.Path
        if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
            Start-Process -FilePath "pwsh" -ArgumentList "-ExecutionPolicy Bypass -File `"$currentScript`"" -Verb RunAs
        } else {
            Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy Bypass -File `"$currentScript`"" -Verb RunAs
        }
        exit
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Impossibile riavviare con privilegi amministratore: $($_.Exception.Message)"
        Write-StyledMessage -Type 'Info' -Text "Riavviare manualmente PowerShell come amministratore ed eseguire nuovamente lo script."
        Read-Host "Premere Invio per uscire"
        exit 1
    }
}

# ============================================================================
# LOGICA PRINCIPALE
# ============================================================================

function Main {
    <#
    .SYNOPSIS
    Funzione principale dello script.
    #>
    
    # Banner iniziale
    Clear-Host
    Write-Host ""
    Write-Host (Center-Text "=====================================" 70) -ForegroundColor Magenta
    Write-Host (Center-Text "POWERSHELL 7 SETUP & PROFILE INSTALLER" 70) -ForegroundColor Magenta
    Write-Host (Center-Text "=====================================" 70) -ForegroundColor Magenta
    Write-Host ""
    
    # Verifica versione PowerShell
    $psVersion = $PSVersionTable.PSVersion.Major
    Write-StyledMessage -Type 'Info' -Text "Versione PowerShell rilevata: $($PSVersionTable.PSVersion)"
    
    if ($psVersion -lt 7) {
        # OPZIONE 1: PowerShell 5 - Installa PowerShell 7
        Write-StyledMessage -Type 'Warning' -Text "PowerShell 5 rilevato. Installazione PowerShell 7 richiesta."
        
        if (Install-PowerShell7) {
            Write-StyledMessage -Type 'Success' -Text "PowerShell 7 installato. Riavvio dello script..."
            Write-StyledMessage -Type 'Info' -Text "Attendere 5 secondi per il riavvio..."
            Start-Sleep -Seconds 5
            
            # Riavvia lo script con PowerShell 7
            try {
                $currentScript = $MyInvocation.MyCommand.Path
                
                # Verifica se pwsh è ora disponibile
                $pwshPath = $null
                $possiblePaths = @(
                    "pwsh",
                    "$env:ProgramFiles\PowerShell\7\pwsh.exe",
                    "$env:ProgramFiles\PowerShell\7-preview\pwsh.exe"
                )
                
                foreach ($path in $possiblePaths) {
                    try {
                        if ($path -eq "pwsh") {
                            if (Get-Command pwsh -ErrorAction SilentlyContinue) {
                                $pwshPath = "pwsh"
                                break
                            }
                        } else {
                            if (Test-Path $path) {
                                $pwshPath = $path
                                break
                            }
                        }
                    } catch { continue }
                }
                
                if ($pwshPath) {
                    Write-StyledMessage -Type 'Info' -Text "Utilizzando PowerShell 7 da: $pwshPath"
                    Start-Process -FilePath $pwshPath -ArgumentList "-ExecutionPolicy Bypass -File `"$currentScript`"" -Verb RunAs
                    Write-StyledMessage -Type 'Info' -Text "Nuova sessione PowerShell 7 avviata. Questo script terminerà ora."
                    Start-Sleep -Seconds 2
                } else {
                    Write-StyledMessage -Type 'Error' -Text "PowerShell 7 installato ma non trovato. Riavviare manualmente."
                    Write-StyledMessage -Type 'Info' -Text "Premere un tasto per uscire..."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
                exit
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Errore nel riavvio: $($_.Exception.Message)"
                Read-Host "Premere Invio per uscire"
                exit 1
            }
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Installazione PowerShell 7 fallita."
            Read-Host "Premere Invio per uscire"
            exit 1
        }
    }
    else {
        # OPZIONE 2: PowerShell 7 - Verifica privilegi amministratore
        Write-StyledMessage -Type 'Success' -Text "PowerShell 7 rilevato."
        
        if (!(Test-AdminPrivileges)) {
            Request-AdminRestart
            return
        }
        
        Write-StyledMessage -Type 'Success' -Text "Privilegi amministratore confermati."
        
        # Installa profilo Chris Titus Tech
        if (Install-CTTPowerShellProfile) {
            Write-StyledMessage -Type 'Success' -Text "Setup profilo PowerShell completato."
            
            # Avvia WinStarter.ps1
            Start-Sleep -Seconds 2
            if (Start-WinStarterScript) {
                Write-StyledMessage -Type 'Success' -Text "Setup completato con successo!"
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "Setup profilo completato, ma errore nell'avvio di WinStarter.ps1"
            }
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Errore durante l'installazione del profilo."
        }
    }
    
    Write-Host ""
    Write-StyledMessage -Type 'Info' -Text "Operazione completata. Premere un tasto per uscire..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ============================================================================
# ESECUZIONE
# ============================================================================

# Gestione errori globale
trap {
    Write-StyledMessage -Type 'Error' -Text "Errore critico: $($_.Exception.Message)"
    Write-StyledMessage -Type 'Error' -Text "Linea: $($_.InvocationInfo.ScriptLineNumber)"
    Read-Host "Premere Invio per uscire"
    exit 1
}

# Avvia script
Main