# Win Toolkit Starter by MagnetarMan

# Impostazione titolo finestra della console
$Host.UI.RawUI.WindowTitle = "Win Toolkit Starter by MagnetarMan"

# Controllo privilegi amministratore
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "Win Toolkit deve essere eseguito come amministratore. Tentativo di riavvio."
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

    # Utilizzo esclusivo di powershell.exe per compatibilità PS 5.1
    Start-Process "powershell" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    break
}

# Creazione directory di log e avvio trascrizione
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\WinToolkit\logs"
try {
    [System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
    Start-Transcript -Path "$logdir\WinToolkit_$dateTime.log" -Append -Force | Out-Null
} catch {
    # Gestione errori silenziosa per compatibilità
}

# Funzione Write-StyledMessage per messaggistica uniforme
function Write-StyledMessage {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Type,
        
        [Parameter(Mandatory=$true)]
        [string]$Text
    )
    
    switch ($Type) {
        'Info'    { Write-Host $Text -ForegroundColor Cyan }
        'Warning' { Write-Host $Text -ForegroundColor Yellow }
        'Error'   { Write-Host $Text -ForegroundColor Red }
        'Success' { Write-Host $Text -ForegroundColor Green }
    }
}

# Schermata di benvenuto
Clear-Host
Write-Host ('Win Toolkit Starter').PadLeft(40) -ForegroundColor Green
Write-Host ('By MagnetarMan').PadLeft(35) -ForegroundColor Red
Write-Host ''

# Controllo versione PowerShell
$psVersion = $PSVersionTable.PSVersion.Major
Write-StyledMessage -Type 'Info' -Text "Versione PowerShell rilevata: $($PSVersionTable.PSVersion)"

if ($psVersion -lt 7) {
    Write-StyledMessage -Type 'Warning' -Text "PowerShell 5 rilevato. PowerShell 7 è raccomandato per funzionalità avanzate."
}

# Funzione per installare PowerShell 7
function Install-PowerShell7 {
    Write-StyledMessage -Type 'Info' -Text "Tentativo installazione PowerShell 7..."
    
    # Verifica se winget è disponibile
    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type 'Info' -Text "Installazione PowerShell 7 tramite winget..."
        try {
            $wingetResult = winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent
            if ($LASTEXITCODE -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "PowerShell 7 installato con successo tramite winget."
                return $true
            } else {
                Write-StyledMessage -Type 'Warning' -Text "Installazione winget fallita. Tentativo installazione diretta..."
            }
        } catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore con winget: $($_.Exception.Message). Tentativo installazione diretta..."
        }
    } else {
        Write-StyledMessage -Type 'Warning' -Text "winget non disponibile. Procedendo con installazione diretta..."
    }
    
    # Installazione diretta da GitHub
    try {
        $ps7Url = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/PowerShell-7.5.2-win-x64.msi"
        $ps7Installer = "$env:TEMP\PowerShell-7.5.2-win-x64.msi"
        
        Write-StyledMessage -Type 'Info' -Text "Download PowerShell 7 da GitHub..."
        Invoke-WebRequest -Uri $ps7Url -OutFile $ps7Installer -UseBasicParsing
        
        Write-StyledMessage -Type 'Info' -Text "Installazione PowerShell 7 in corso..."
        $installArgs = "/i `"$ps7Installer`" /quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1"
        $process = Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text "PowerShell 7 installato con successo."
            # Cleanup
            Remove-Item $ps7Installer -Force -ErrorAction SilentlyContinue
            return $true
        } else {
            Write-StyledMessage -Type 'Error' -Text "Installazione PowerShell 7 fallita. Codice di uscita: $($process.ExitCode)"
            return $false
        }
    } catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante l'installazione di PowerShell 7: $($_.Exception.Message)"
        return $false
    }
}

# Funzione Invoke-WPFTweakPS7 con configurazione Windows Terminal
function Invoke-WPFTweakPS7 {
    <#
    .SYNOPSIS
        Configura Windows Terminal per utilizzare PowerShell 7
    .PARAMETER action
        PS7: Configura per Powershell 7
        PS5: Configura per Powershell 5
    #>
    param (
        [ValidateSet("PS7", "PS5")]
        [string]$action = "PS7"
    )

    switch ($action) {
        "PS7" {
            $targetTerminalName = "PowerShell"
        }
        "PS5" {
            $targetTerminalName = "Windows PowerShell"
        }
    }

    # Configurazione Windows Terminal sempre eseguita
    Write-StyledMessage -Type 'Info' -Text "Configurazione Windows Terminal per $targetTerminalName..."
    
    # Verifica Windows Terminal
    if (-not (Get-Command "wt" -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type 'Warning' -Text "Windows Terminal non installato. Saltando configurazione terminale."
        return
    }
    
    # Verifica file settings.json di Windows Terminal
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path -Path $settingsPath)) {
        Write-StyledMessage -Type 'Warning' -Text "File impostazioni Windows Terminal non trovato."
        return
    }

    try {
        Write-StyledMessage -Type 'Info' -Text "Aggiornamento configurazione Windows Terminal..."
        $settingsContent = Get-Content -Path $settingsPath | ConvertFrom-Json
        $targetProfile = $settingsContent.profiles.list | Where-Object { $_.name -eq $targetTerminalName }
        
        if ($targetProfile) {
            $settingsContent.defaultProfile = $targetProfile.guid
            $updatedSettings = $settingsContent | ConvertTo-Json -Depth 100
            Set-Content -Path $settingsPath -Value $updatedSettings
            Write-StyledMessage -Type 'Success' -Text "Profilo predefinito Windows Terminal aggiornato a $targetTerminalName"
        } else {
            Write-StyledMessage -Type 'Warning' -Text "Profilo $targetTerminalName non trovato nelle impostazioni di Windows Terminal."
        }
    } catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante l'aggiornamento delle impostazioni Windows Terminal: $($_.Exception.Message)"
    }
}

# Funzione Invoke-WinUtilInstallPSProfile con installazione automatica
function Invoke-WinUtilInstallPSProfile {
    <#
    .SYNOPSIS
        Installa automaticamente il profilo PowerShell di Chris Titus Tech per PowerShell 7
    #>
    
    function Invoke-PSSetup {
        $url = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        
        try {
            # Determina il percorso del profilo PowerShell 7
            $ps7ProfilePath = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
            
            # Crea la directory se non esiste
            $ps7ProfileDir = Split-Path $ps7ProfilePath -Parent
            if (!(Test-Path $ps7ProfileDir)) {
                New-Item -ItemType Directory -Path $ps7ProfileDir -Force | Out-Null
                Write-StyledMessage -Type 'Info' -Text "Creata directory profilo PowerShell 7: $ps7ProfileDir"
            }
            
            # Ottieni hash del profilo corrente
            $OldHash = if (Test-Path $ps7ProfilePath) { Get-FileHash $ps7ProfilePath -ErrorAction SilentlyContinue } else { $null }
            
            # Scarica il nuovo profilo
            Write-StyledMessage -Type 'Info' -Text "Download del profilo PowerShell 7..."
            Invoke-WebRequest -Uri $url -OutFile "$env:TEMP/Microsoft.PowerShell_profile.ps1" -UseBasicParsing
            
            # Ottieni hash del nuovo profilo
            $NewHash = Get-FileHash "$env:TEMP/Microsoft.PowerShell_profile.ps1"
            
            # Verifica se è necessario aggiornare
            if (-not $OldHash -or $NewHash.Hash -ne $OldHash.Hash) {
                # Backup del profilo esistente
                if (Test-Path "$env:USERPROFILE\oldprofile.ps1") {
                    Write-StyledMessage -Type 'Warning' -Text "File di backup esistente trovato..."
                    Copy-Item "$env:USERPROFILE\oldprofile.ps1" "$ps7ProfilePath.bak" -Force
                    Write-StyledMessage -Type 'Success' -Text "Backup del profilo completato."
                } elseif ((Test-Path $ps7ProfilePath) -and (-not (Test-Path "$ps7ProfilePath.bak"))) {
                    Write-StyledMessage -Type 'Info' -Text "Creazione backup del profilo PowerShell 7 corrente..."
                    Copy-Item -Path $ps7ProfilePath -Destination "$ps7ProfilePath.bak"
                    Write-StyledMessage -Type 'Success' -Text "Backup del profilo completato."
                }
                
                # Installazione del profilo
                Write-StyledMessage -Type 'Info' -Text "Installazione del profilo PowerShell 7..."
                
                # Verifica se PowerShell 7 è disponibile
                $ps7Path = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
                if (Test-Path $ps7Path) {
                    # Usa PowerShell 7 se disponibile
                    Start-Process -FilePath $ps7Path -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1')`"" -WindowStyle Hidden -Wait
                } else {
                    # Fallback su PowerShell 5.1
                    Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1' -UseBasicParsing)`"" -WindowStyle Hidden -Wait
                }
                
                Write-StyledMessage -Type 'Success' -Text "Profilo PowerShell 7 installato con successo!"
                Write-StyledMessage -Type 'Info' -Text "Il profilo sarà attivo al prossimo avvio di PowerShell 7."
            } else {
                Write-StyledMessage -Type 'Success' -Text "Il profilo PowerShell 7 è già aggiornato."
            }
        } catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante l'installazione del profilo PowerShell 7: $($_.Exception.Message)"
        }
    }
    
    # Verifica se PowerShell 7 è installato o è stato appena installato
    $ps7Installed = Test-Path -Path "$env:ProgramFiles\PowerShell\7"
    
    if ($ps7Installed) {
        Write-StyledMessage -Type 'Success' -Text "PowerShell 7 disponibile. Installazione profilo automatica..."
        Invoke-PSSetup
    } else {
        Write-StyledMessage -Type 'Warning' -Text "PowerShell 7 non disponibile. Installazione profilo saltata."
    }
}

# NUOVA FUNZIONE PER L'INSTALLAZIONE DI GIT
function Install-Git {
    Write-StyledMessage -Type 'Info' -Text "Verifica installazione di Git..."

    if (Get-Command "git" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type 'Success' -Text "Git è già installato. Saltando l'installazione."
        return $true
    }

    Write-StyledMessage -Type 'Info' -Text "Git non trovato. Tentativo di installazione..."

    # Prova a installare con winget
    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type 'Info' -Text "Installazione di Git tramite winget..."
        try {
            winget install Git.Git --accept-source-agreements --accept-package-agreements --silent
            if ($LASTEXITCODE -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "Git installato con successo tramite winget."
                return $true
            } else {
                Write-StyledMessage -Type 'Warning' -Text "Installazione winget fallita. Tentativo di installazione diretta..."
            }
        } catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore con winget: $($_.Exception.Message). Tentativo di installazione diretta..."
        }
    } else {
        Write-StyledMessage -Type 'Warning' -Text "winget non disponibile. Procedendo con installazione diretta..."
    }

    # Fallback: installazione diretta dal file .exe
    try {
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.1/Git-2.51.0-64-bit.exe"
        $gitInstaller = "$env:TEMP\Git-2.51.0-64-bit.exe"

        Write-StyledMessage -Type 'Info' -Text "Download di Git da GitHub..."
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing

        Write-StyledMessage -Type 'Info' -Text "Installazione di Git in corso..."
        # Utilizzo del flag /SILENT per installazione non interattiva
        $installArgs = "/SILENT /NORESTART"
        $process = Start-Process $gitInstaller -ArgumentList $installArgs -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text "Git installato con successo."
            # Pulizia file di installazione
            Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
            return $true
        } else {
            Write-StyledMessage -Type 'Error' -Text "Installazione di Git fallita. Codice di uscita: $($process.ExitCode)"
            return $false
        }
    } catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante l'installazione diretta di Git: $($_.Exception.Message)"
        return $false
    }
}

# Esecuzione delle funzioni principali
Write-StyledMessage -Type 'Info' -Text "Avvio configurazione Win Toolkit..."

# Prima installa Git se necessario
Install-Git

# Variabile per tracciare se è necessario il riavvio
$rebootNeeded = $false

# Poi installa PowerShell 7 se necessario
if (-not (Test-Path -Path "$env:ProgramFiles\PowerShell\7")) {
    Write-StyledMessage -Type 'Info' -Text "PowerShell 7 non trovato. Avvio installazione..."
    $installSuccess = Install-PowerShell7
    if ($installSuccess) {
        Write-StyledMessage -Type 'Success' -Text "PowerShell 7 installato con successo."
        # Imposta la variabile per indicare che il riavvio è necessario
        $rebootNeeded = $true
    } else {
        Write-StyledMessage -Type 'Error' -Text "Installazione PowerShell 7 fallita."
    }
} else {
    Write-StyledMessage -Type 'Success' -Text "PowerShell 7 già presente."
}

# Configura Windows Terminal
Write-StyledMessage -Type 'Info' -Text "Configurazione Windows Terminal..."
Invoke-WPFTweakPS7 -action "PS7"

# Installa profilo PowerShell 7
Write-StyledMessage -Type 'Info' -Text "Configurazione profilo PowerShell 7..."
Invoke-WinUtilInstallPSProfile

# Messaggio di completamento
Write-StyledMessage -Type 'Success' -Text "Script di Start eseguito correttamente"

# Esegui il riavvio solo se l'installazione di PowerShell 7 è avvenuta in questa sessione
if ($rebootNeeded) {
    Write-StyledMessage -Type 'Warning' -Text "Attenzione: il sistema verrà riavviato per rendere effettive le modifiche"

    # Countdown per il riavvio
    Write-StyledMessage -Type 'Info' -Text "Preparazione al riavvio del sistema..."
    for ($i = 10; $i -gt 0; $i--) {
        Write-Host "Preparazione sistema al riavvio - $i secondi..." -NoNewline -ForegroundColor Yellow
        Write-Host "`r" -NoNewline
        Start-Sleep 1
    }

    Write-StyledMessage -Type 'Info' -Text "Riavvio in corso..."

    # Arresto trascrizione prima del riavvio
    try {
        Stop-Transcript | Out-Null
        Write-StyledMessage -Type 'Success' -Text "Trascrizione del log salvata in: $logdir\WinToolkit_$dateTime.log"
    } catch {
        # Gestione errori silenziosa
    }

    # Riavvio del sistema
    Restart-Computer -Force
} else {
    Write-StyledMessage -Type 'Info' -Text "Non è necessario riavviare il sistema in quanto PowerShell 7 era già installato."
}