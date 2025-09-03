<#
.SYNOPSIS
    Win Toolkit Start Script.
    This script is designed to run on PowerShell 5.1 and provides a unified interface for system
    management tasks. It handles administrative privileges, logs, user messaging, and profile setup.
.DESCRIPTION
    The script first checks for administrator privileges and re-launches itself if necessary.
    It then sets the console window title, creates a log file, and displays a welcome message.
    It includes functions to check for PowerShell 7 and to install a PowerShell profile,
    ensuring compatibility and a consistent user experience.
.AUTHOR
    MagnetarMan
.VERSION
    2.0
#>

# S1: Funzione per la messaggistica
# Questa funzione centralizza tutti i messaggi utente per un'interfaccia coerente.
function Write-StyledMessage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Type,
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    switch ($Type) {
        'Success' { Write-Host "[SUCCESS] $Text" -ForegroundColor Green }
        'Info'    { Write-Host "[INFO] $Text" -ForegroundColor Cyan }
        'Warning' { Write-Host "[WARNING] $Text" -ForegroundColor Yellow }
        'Error'   { Write-Host "[ERROR] $Text" -ForegroundColor Red }
        'Custom'  { Write-Host $Text }
    }
}

# S2: Controllo Amministratore
# Rilancia lo script con privilegi elevati se necessario, utilizzando powershell.exe per la compatibilità con PS5.1.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-StyledMessage -Type Error -Text "Winutil needs to be run as Administrator. Attempting to relaunch."
    
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
        # Fallback per l'esecuzione da internet (non supportato in PowerShell 5.1 in questo contesto)
        # Rimuoviamo il riferimento a `irm` per coerenza.
        "&([ScriptBlock]::Create((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/start.ps1'))) $($argList -join ' ')"
    }
    
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    break
}

# S3: Configurazione Iniziale e Logging
# Imposta il titolo della finestra e avvia la trascrizione per il logging.
$Host.UI.RawUI.WindowTitle = "Win Toolkit by MagnetarMan"
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\WinToolkit\logs"
[System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
Start-Transcript -Path "$logdir\WinToolkit_$dateTime.log" -Append -NoClobber | Out-Null

# S4: Schermata di Benvenuto
# Pulisce la console e visualizza il messaggio di benvenuto.
Clear-Host
Write-Host ('Win Toolkit Starter v2.0').PadLeft(40) -ForegroundColor Green
Write-Host ('By MagnetarMan').PadLeft(40) -ForegroundColor Red
Write-Host ''

# S5: Funzioni ausiliarie per l'installazione e il profilo
# Le funzioni sono definite prima di essere chiamate.
function Invoke-WPFTweakPS7 {
    <#
    .SYNOPSIS
        Installs PowerShell 7 if it's not already installed.
    .PARAMETER action
        PS7: Installs Powershell 7.
        PS5: Configures Powershell 5 to be the default Terminal (functionality removed for PS5.1 support).
    #>
    param (
        [ValidateSet("PS7", "PS5")]
        [string]$action
    )

    if ($action -eq "PS7") {
        if (Test-Path -Path "$env:ProgramFiles\PowerShell\7") {
            Write-StyledMessage -Type Info -Text "PowerShell 7 è già installato. L'installazione non è necessaria."
        } else {
            Write-StyledMessage -Type Info -Text "PowerShell 7 non è installato. Tentativo di installazione automatica..."

            # Controllo e installazione di Winget
            if (-not (Get-Command "winget.exe" -ErrorAction SilentlyContinue)) {
                Write-StyledMessage -Type Warning -Text "Winget non è stato trovato. Tentativo di installarlo da Microsoft Store."
                try {
                    Start-Process -FilePath "ms-windows-store://pdp/?productid=9NBLGGH4NNS1" -Wait
                    Write-StyledMessage -Type Success -Text "Installazione di Winget avviata. Riavvia lo script una volta completata."
                    return
                }
                catch {
                    Write-StyledMessage -Type Error -Text "Impossibile avviare l'installazione di Winget da Microsoft Store. Procedo con il metodo di fallback."
                }
            }

            # Tentativo di installazione di PowerShell 7 con Winget
            Write-StyledMessage -Type Info -Text "Tentativo di installazione di PowerShell 7 con Winget..."
            try {
                Start-Process -FilePath "winget.exe" -ArgumentList "install Microsoft.PowerShell --source winget --accept-package-agreements" -Wait -NoNewWindow
                if ($LASTEXITCODE -eq 0) {
                    Write-StyledMessage -Type Success -Text "Installazione di PowerShell 7 completata con successo tramite Winget."
                } else {
                    Write-StyledMessage -Type Warning -Text "Installazione di PowerShell 7 tramite Winget fallita. Codice di uscita: $LASTEXITCODE. Passaggio al metodo manuale..."
                    $winget_failed = $true
                }
            } catch {
                Write-StyledMessage -Type Error -Text "Si è verificato un errore durante il tentativo di installazione con Winget. Passaggio al metodo manuale."
                $winget_failed = $true
            }

            # Fallback: scarica e installa l'MSI se l'installazione di Winget fallisce o se winget non è presente.
            if ($winget_failed -or (-not (Test-Path -Path "$env:ProgramFiles\PowerShell\7"))) {
                Write-StyledMessage -Type Info -Text "Scarico l'installer MSI di PowerShell 7.5.2 dal repository GitHub..."
                $url = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/PowerShell-7.5.2-win-x64.msi"
                $msiPath = "$env:TEMP\PowerShell-7.5.2-win-x64.msi"

                try {
                    Invoke-WebRequest -Uri $url -OutFile $msiPath
                    Write-StyledMessage -Type Success -Text "Download completato. Avvio dell'installazione MSI..."
                    
                    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /quiet /norestart" -Wait
                    
                    if (Test-Path -Path "$env:ProgramFiles\PowerShell\7") {
                        Write-StyledMessage -Type Success -Text "PowerShell 7 è stato installato con successo tramite MSI."
                    } else {
                        Write-StyledMessage -Type Error -Text "L'installazione tramite MSI è fallita. Si prega di installare PowerShell 7 manualmente."
                    }
                } catch {
                    Write-StyledMessage -Type Error -Text "Si è verificato un errore durante il download o l'installazione del file MSI: $_"
                    Write-StyledMessage -Type Error -Text "L'installazione automatica di PowerShell 7 non è riuscita. Installare manualmente."
                }
            }
        }
    }
}

# S6: Esecuzione delle operazioni
# La logica principale dello script.
$psVersion = $PSVersionTable.PSVersion.Major
Write-StyledMessage -Type Info -Text "Versione PowerShell rilevata: $($PSVersionTable.PSVersion)"

if ($psVersion -lt 7) {
    Write-StyledMessage -Type Warning -Text "PowerShell 5 rilevato. Installazione PowerShell 7 richiesta per funzionalità complete."
    Invoke-WPFTweakPS7
}

Invoke-WinUtilInstallPSProfile

# S7: Avviso finale e riavvio
# Avvisa l'utente della fine dello script e avvia il conto alla rovescia per il riavvio.
Write-StyledMessage -Type Info -Text "Script di Start eseguito correttamente."
Write-StyledMessage -Type Info -Text "La trascrizione del log è stata salvata in $logdir."
Write-StyledMessage -Type Warning -Text "Attenzione: il sistema verrà riavviato per rendere effettive le modifiche."

for ($i = 10; $i -gt 0; $i--) {
    Write-Host "Preparazione sistema al riavvio - $i secondi..." -NoNewline -ForegroundColor Yellow
    Start-Sleep 1
}
Write-Host ""
Write-StyledMessage -Type Info -Text "Riavvio in corso..."
# Questo comando riavvia il sistema.
# Restart-Computer -Force
# Decommentare la riga sopra per abilitare il riavvio.