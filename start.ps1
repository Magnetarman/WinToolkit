<#
.SYNOPSIS
    Script completo per l'applicazione "Win Toolkit", compatibile con PowerShell 5.1.
    Questo script unifica varie funzionalità, gestisce i log, controlla i privilegi di amministratore,
    e modifica il profilo di PowerShell, il tutto con un'interfaccia utente uniforme.
.DESCRIPTION
    Lo script esegue le seguenti operazioni:
    1.  Imposta il titolo della finestra della console.
    2.  Configura e avvia la trascrizione dei log in una directory dedicata.
    3.  Verifica i privilegi di amministratore e, se necessario, si riavvia con privilegi elevati.
    4.  Visualizza una schermata di benvenuto.
    5.  Utilizza una funzione centralizzata 'Write-StyledMessage' per tutti i messaggi all'utente.
    6.  Controlla la presenza di PowerShell 7, informando l'utente se non è installato.
    7.  Installa un profilo PowerShell personalizzato, gestendo backup e aggiornamenti.
    8.  Informa l'utente al termine dell'esecuzione e avvia un riavvio forzato del sistema.
.AUTHOR
    MagnetarMan
.VERSION
    2.0
#>

#--------------------------------------------------------------------------
# Impostazioni Iniziali e Log
#--------------------------------------------------------------------------

# Imposta il titolo della finestra della console
$Host.UI.RawUI.WindowTitle = "Win Toolkit by MagnetarMan"

# Creazione della directory di log e avvio della trascrizione
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\WinToolkit\logs"
if (-not (Test-Path -Path $logdir)) {
    [System.IO.Directory]::CreateDirectory($logdir) | Out-Null
}
Start-Transcript -Path "$logdir\WinToolkit_$dateTime.log" -Append -NoClobber -Force | Out-Null


#--------------------------------------------------------------------------
# Funzione di Messaggistica
#--------------------------------------------------------------------------

function Write-StyledMessage {
    <#
    .SYNOPSIS
        Visualizza un messaggio formattato nella console.
    .PARAMETER Type
        Il tipo di messaggio (Info, Success, Warning, Error). Determina il colore del testo.
    .PARAMETER Text
        Il testo del messaggio da visualizzare.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $color = switch ($Type) {
        "Info"    { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
    }

    Write-Host $Text -ForegroundColor $color
}


#--------------------------------------------------------------------------
# Controllo Privilegi di Amministratore
#--------------------------------------------------------------------------

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-StyledMessage -Type 'Error' -Text "Win Toolkit deve essere eseguito come Amministratore. Tentativo di riavvio."
    
    # Ricostruisce gli argomenti per il nuovo processo
    $argList = @()
    $PSBoundParameters.GetEnumerator() | ForEach-Object {
        $argList += if ($_.Value -is [switch] -and $_.Value) {
            "-$($_.Key)"
        }
        elseif ($_.Value -is [array]) {
            "-$($_.Key) $($_.Value -join ',')"
        }
        elseif ($_.Value) {
            "-$($_.Key) '$($_.Value)'"
        }
    }

    $script = if ($PSCommandPath) {
        "& { & `'$($PSCommandPath)`' $($argList -join ' ') }"
    }
    else {
        # Fallback nel caso lo script sia eseguito da una fonte remota
        "&([ScriptBlock]::Create((irm https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/start.ps1))) $($argList -join ' ')"
    }

    # Rilancia lo script usando esclusivamente powershell.exe per compatibilità con PS 5.1
    Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    
    # Interrompe l'esecuzione dello script corrente non privilegiato
    exit
}


#--------------------------------------------------------------------------
# Schermata di Benvenuto
#--------------------------------------------------------------------------

Clear-Host
Write-Host ('Win Toolkit v2.0').PadLeft(40) -ForegroundColor Green
Write-Host ('By MagnetarMan').PadLeft(30) -ForegroundColor Red
Write-Host ''


#--------------------------------------------------------------------------
# Funzioni Principali
#--------------------------------------------------------------------------

function Check-PowerShell7 {
    <#
    .SYNOPSIS
        Controlla se PowerShell 7 è installato nel sistema.
    .DESCRIPTION
        Questa funzione verifica la presenza della directory di installazione di PowerShell 7
        e informa l'utente sullo stato, senza tentare alcuna installazione.
    #>
    Write-StyledMessage -Type 'Info' -Text "Verifica dell'installazione di PowerShell 7..."
    if (Test-Path -Path "$env:ProgramFiles\PowerShell\7") {
        Write-StyledMessage -Type 'Success' -Text "PowerShell 7 è installato."
    }
    else {
        Write-StyledMessage -Type 'Warning' -Text "PowerShell 7 non è installato. Le funzionalità avanzate potrebbero richiederlo."
    }
}

function Install-CTTPowerShellProfile {
    <#
    .SYNOPSIS
        Installa il profilo PowerShell di Chris Titus Tech.
    .DESCRIPTION
        Esegue il backup del profilo esistente, scarica e installa il nuovo profilo.
        La funzione è stata adattata per essere pienamente compatibile con PowerShell 5.1.
    #>
    Write-StyledMessage -Type 'Info' -Text "Avvio dell'installazione del profilo PowerShell..."

    # Controlla se PowerShell 7 è installato, poiché il profilo lo raccomanda.
    if (-not (Test-Path -Path "$env:ProgramFiles\PowerShell\7")) {
        Write-StyledMessage -Type 'Warning' -Text "Questo profilo funziona al meglio con PowerShell 7, che non è attualmente installato."
    }

    # Definisce l'URL utilizzato per scaricare il profilo PowerShell di Chris Titus Tech.
    $url = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
    $tempProfilePath = "$env:TEMP\Microsoft.PowerShell_profile.ps1"

    # Ottiene l'hash del file per l'attuale profilo PowerShell dell'utente.
    $OldHash = Get-FileHash $PROFILE -ErrorAction SilentlyContinue

    # Scarica il profilo PowerShell di Chris Titus Tech nella cartella 'TEMP'.
    try {
        Invoke-RestMethod $url -OutFile $tempProfilePath -ErrorAction Stop
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Download del profilo da '$url' non riuscito."
        return
    }
    
    # Ottiene l'hash del file per il profilo PowerShell di Chris Titus Tech.
    $NewHash = Get-FileHash $tempProfilePath

    # Controlla se l'hash del nuovo profilo non corrisponde a quello del vecchio profilo.
    if ($NewHash.Hash -ne $OldHash.Hash) {
        # Controlla se il file di backup del profilo non è già stato creato sul disco.
        if ((Test-Path $PROFILE) -and (-not (Test-Path "$PROFILE.bak"))) {
            Write-StyledMessage -Type 'Warning' -Text "===> Backup del profilo in corso... <==="
            Copy-Item -Path $PROFILE -Destination "$PROFILE.bak" -Force
            Write-StyledMessage -Type 'Success' -Text "===> Backup del profilo: completato. <==="
        }

        Write-StyledMessage -Type 'Info' -Text "===> Installazione del profilo in corso... <==="

        # Esegue lo script di setup usando powershell.exe per garantire la compatibilità.
        $setupCommand = "Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1')"
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$setupCommand`"" -WindowStyle Hidden -Wait

        Write-StyledMessage -Type 'Success' -Text "Il profilo è stato installato. Riavvia la shell per applicare le modifiche!"
        Write-StyledMessage -Type 'Success' -Text "===> Configurazione del profilo terminata <==="
    }
    else {
        Write-StyledMessage -Type 'Success' -Text "Il profilo è aggiornato."
    }
}


#--------------------------------------------------------------------------
# Esecuzione dello Script
#--------------------------------------------------------------------------

# Chiama le funzioni definite
Check-PowerShell7
Install-CTTPowerShellProfile


#--------------------------------------------------------------------------
# Avviso Finale e Riavvio
#--------------------------------------------------------------------------

Write-StyledMessage -Type 'Info' -Text "Esecuzione dello script completata con successo."
Write-StyledMessage -Type 'Info' -Text "La trascrizione del log è stata salvata in '$logdir'."
Write-StyledMessage -Type 'Warning' -Text "Il sistema verrà riavviato per applicare tutte le modifiche."

# Countdown per il riavvio
for ($i = 10; $i -gt 0; $i--) {
    Write-Host "`rPreparazione al riavvio del sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
    Start-Sleep 1
}
Write-Host "" # Aggiunge una nuova riga dopo il countdown

Write-StyledMessage -Type 'Info' -Text "Riavvio in corso..."
Restart-Computer -Force