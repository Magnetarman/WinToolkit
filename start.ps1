# Win Toolkit by MagnetarMan
# Completo script PowerShell compatibile con PowerShell 5.1

# Impostazione titolo finestra della console
$Host.UI.RawUI.WindowTitle = "Win Toolkit by MagnetarMan"

# Controllo privilegi amministratore
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
Write-Host ('Win Toolkit Starter v2.0').PadLeft(40) -ForegroundColor Green
Write-Host ('By MagnetarMan').PadLeft(40) -ForegroundColor Red
Write-Host ''

# Controllo versione PowerShell
$psVersion = $PSVersionTable.PSVersion.Major
Write-StyledMessage -Type 'Info' -Text "Versione PowerShell rilevata: $($PSVersionTable.PSVersion)"

if ($psVersion -lt 7) {
    Write-StyledMessage -Type 'Warning' -Text "PowerShell 5 rilevato. PowerShell 7 è raccomandato per funzionalità avanzate."
}

# Funzione Invoke-WPFTweakPS7 modificata per PS 5.1
function Invoke-WPFTweakPS7 {
    <#
    .SYNOPSIS
        Verifica l'installazione di PowerShell 7 e informa l'utente
    .PARAMETER action
        PS7: Verifica configurazione per Powershell 7
        PS5: Mantiene configurazione per Powershell 5
    #>
    param (
        [ValidateSet("PS7", "PS5")]
        [string]$action = "PS7"
    )

    switch ($action) {
        "PS7" {
            if (Test-Path -Path "$env:ProgramFiles\PowerShell\7") {
                Write-StyledMessage -Type 'Success' -Text "PowerShell 7 è già installato."
            } else {
                Write-StyledMessage -Type 'Warning' -Text "PowerShell 7 non trovato. È necessario installare PS7 per le funzionalità avanzate."
                Write-StyledMessage -Type 'Info' -Text "Puoi scaricarlo da: https://github.com/PowerShell/PowerShell/releases"
                return
            }
            $targetTerminalName = "PowerShell"
        }
        "PS5" {
            $targetTerminalName = "Windows PowerShell"
        }
    }

    # Verifica Windows Terminal (opzionale)
    if (-not (Get-Command "wt" -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type 'Warning' -Text "Windows Terminal non installato. Configurazione terminale saltata."
        return
    }

    # Verifica file settings.json di Windows Terminal
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path -Path $settingsPath)) {
        Write-StyledMessage -Type 'Warning' -Text "File impostazioni Windows Terminal non trovato."
        return
    }

    try {
        Write-StyledMessage -Type 'Info' -Text "File impostazioni trovato. Aggiornamento configurazione..."
        $settingsContent = Get-Content -Path $settingsPath | ConvertFrom-Json
        $targetProfile = $settingsContent.profiles.list | Where-Object { $_.name -eq $targetTerminalName }
        
        if ($targetProfile) {
            $settingsContent.defaultProfile = $targetProfile.guid
            $updatedSettings = $settingsContent | ConvertTo-Json -Depth 100
            Set-Content -Path $settingsPath -Value $updatedSettings
            Write-StyledMessage -Type 'Success' -Text "Profilo predefinito aggiornato a $targetTerminalName"
        } else {
            Write-StyledMessage -Type 'Warning' -Text "Profilo $targetTerminalName non trovato nelle impostazioni di Windows Terminal."
        }
    } catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante l'aggiornamento delle impostazioni: $($_.Exception.Message)"
    }
}

# Funzione Invoke-WinUtilInstallPSProfile modificata per PS 5.1
function Invoke-WinUtilInstallPSProfile {
    <#
    .SYNOPSIS
        Installa e applica il profilo PowerShell di Chris Titus Tech
    #>
    
    function Invoke-PSSetup {
        $url = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        
        try {
            # Ottieni hash del profilo corrente
            $OldHash = if (Test-Path $PROFILE) { Get-FileHash $PROFILE -ErrorAction SilentlyContinue } else { $null }
            
            # Scarica il nuovo profilo
            Write-StyledMessage -Type 'Info' -Text "Download del profilo PowerShell..."
            Invoke-RestMethod $url -OutFile "$env:TEMP/Microsoft.PowerShell_profile.ps1"
            
            # Ottieni hash del nuovo profilo
            $NewHash = Get-FileHash "$env:TEMP/Microsoft.PowerShell_profile.ps1"
            
            # Memorizza hash del nuovo profilo
            if (!(Test-Path "$PROFILE.hash")) {
                $NewHash.Hash | Out-File "$PROFILE.hash"
            }
            
            # Verifica se è necessario aggiornare
            if (-not $OldHash -or $NewHash.Hash -ne $OldHash.Hash) {
                # Backup del profilo esistente
                if (Test-Path "$env:USERPROFILE\oldprofile.ps1") {
                    Write-StyledMessage -Type 'Warning' -Text "File di backup esistente trovato..."
                    Copy-Item "$env:USERPROFILE\oldprofile.ps1" "$PROFILE.bak" -Force
                    Write-StyledMessage -Type 'Success' -Text "Backup del profilo completato."
                } elseif ((Test-Path $PROFILE) -and (-not (Test-Path "$PROFILE.bak"))) {
                    Write-StyledMessage -Type 'Info' -Text "Creazione backup del profilo corrente..."
                    Copy-Item -Path $PROFILE -Destination "$PROFILE.bak"
                    Write-StyledMessage -Type 'Success' -Text "Backup del profilo completato."
                }
                
                # Installazione del profilo
                Write-StyledMessage -Type 'Info' -Text "Installazione del profilo PowerShell..."
                
                # Uso di powershell.exe invece di pwsh per compatibilità PS 5.1
                Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1')`"" -WindowStyle Hidden -Wait
                
                Write-StyledMessage -Type 'Success' -Text "Profilo installato. Riavvia la shell per vedere i cambiamenti!"
                Write-StyledMessage -Type 'Success' -Text "Setup del profilo completato."
            } else {
                Write-StyledMessage -Type 'Success' -Text "Il profilo è già aggiornato."
            }
        } catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante l'installazione del profilo: $($_.Exception.Message)"
        }
    }
    
    # Verifica se PowerShell Core è disponibile
    if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Invoke-PSSetup
        } else {
            Write-StyledMessage -Type 'Warning' -Text "Questo profilo richiede PowerShell 7, che è installato ma non in uso!"
            Write-StyledMessage -Type 'Info' -Text "Vuoi procedere con l'installazione del profilo per PowerShell 7? (S/N)"
            
            $response = Read-Host
            if ($response -match '^[Ss]$') {
                Invoke-PSSetup
            } else {
                Write-StyledMessage -Type 'Warning' -Text "Setup del profilo annullato."
            }
        }
    } else {
        Write-StyledMessage -Type 'Error' -Text "Questo profilo richiede PowerShell Core, che non è attualmente installato!"
        Write-StyledMessage -Type 'Info' -Text "Scaricalo da: https://github.com/PowerShell/PowerShell/releases"
    }
}

# Esecuzione delle funzioni principali
Write-StyledMessage -Type 'Info' -Text "Avvio configurazione Win Toolkit..."

# Installa PowerShell 7 e configura Windows Terminal
Invoke-WPFTweakPS7 -action "PS7"

# Installazione automatica profilo PowerShell 7
Write-StyledMessage -Type 'Info' -Text "Configurazione profilo PowerShell 7..."
Invoke-WinUtilInstallPSProfile

# Messaggio di completamento
Write-StyledMessage -Type 'Success' -Text "Script di Start eseguito correttamente"
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