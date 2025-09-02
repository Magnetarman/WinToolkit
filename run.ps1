<#
.SYNOPSIS
    Un toolkit di avvio per eseguire script di manutenzione di Windows.
.DESCRIPTION
    Questo script funge da menu principale per un insieme di strumenti di manutenzione.
    All'avvio, verifica la presenza di PowerShell 7 e, se necessario, ne gestisce l'installazione e l'aggiornamento.
    Successivamente, presenta un menu interattivo per lanciare gli script associati.
.AUTHOR
    MagnetarMan (Refactored by Gemini)
.VERSION
    2.0
#>

# =================================================================================
# CONFIGURAZIONE INIZIALE E BEST PRACTICES
# =================================================================================

# Imposta il titolo della finestra di PowerShell per un'identificazione immediata.
$Host.UI.RawUI.WindowTitle = "Win Toolkits by MagnetarMan v2.0"

# Abilita funzionalità avanzate per lo script, come i parametri comuni (-Verbose, -Debug).
[CmdletBinding()]
param()

# Imposta una gestione degli errori più rigorosa per lo script.
# 'Stop' interrompe l'esecuzione in caso di errore, permettendo una gestione controllata tramite try/catch.
$ErrorActionPreference = 'Stop'

# =================================================================================
# DEFINIZIONE DELLE FUNZIONI
# Spostate in cima per una chiara separazione tra definizioni e logica esecutiva.
# =================================================================================

#region Funzioni di Utilità

function Invoke-WinUtilInstallPSProfile {
    # Concise, consistent routine per stile del toolkit.
    Write-Host "[i] Verifica profilo PowerShell (CTT)..." -ForegroundColor Cyan
    try {
        $psProfile = $PROFILE
        $temp = Join-Path $env:TEMP 'Microsoft.PowerShell_profile.ps1'
        $url = 'https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1'

        $oldHash = if (Test-Path $psProfile) { (Get-FileHash $psProfile -Algorithm SHA256).Hash } else { $null }

        try {
            Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing -Headers @{ 'User-Agent' = 'Mozilla/5.0' } -ErrorAction Stop
        } catch {
            Write-Host "[!] Impossibile scaricare profilo: $_" -ForegroundColor Yellow
            return
        }

        $newHash = (Get-FileHash $temp -Algorithm SHA256).Hash
        if ($newHash -ne $oldHash) {
            if ((Test-Path $psProfile) -and (-not (Test-Path "$psProfile.bak"))) {
                Copy-Item -Path $psProfile -Destination "$psProfile.bak" -Force
                Write-Host "[i] Backup profilo creato" -ForegroundColor Yellow
            }

            Write-Host "[i] Installazione profilo..." -ForegroundColor Yellow
            try {
                Start-Process -FilePath pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command \"Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1' -UseBasicParsing).Content\"" -WindowStyle Hidden -Wait
                Write-Host "[OK] Profilo installato. Riavvia la shell per applicare le modifiche." -ForegroundColor Green
            } catch {
                Write-Host "[X] Installazione profilo fallita: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "[i] Profilo già aggiornato" -ForegroundColor Magenta
        }
    } catch {
        Write-Host "[X] Errore profilo: $_" -ForegroundColor Red
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

#endregion Funzioni di Utilità

#region Gestione Aggiornamento PowerShell

function Ensure-PowerShellModern {
    <#
    .SYNOPSIS
        Verifica la presenza di PowerShell 7+, lo installa se assente
        e riavvia lo script corrente con la versione aggiornata.
    #>
    $requiredPSMajorVersion = 7
    $pwshExePath = Join-Path $env:ProgramFiles "PowerShell\$($requiredPSMajorVersion)\pwsh.exe"

    # Se stiamo già eseguendo la versione richiesta o una superiore, non fare nulla.
    if ($PSVersionTable.PSVersion.Major -ge $requiredPSMajorVersion) {
        Write-StyledMessage 'Info' "PowerShell versione $($PSVersionTable.PSVersion.Major) già in uso."
        return
    }

    # Se PowerShell 7+ non è installato, procedi con il download e l'installazione.
    if (-not (Test-Path $pwshExePath)) {
        Write-StyledMessage 'Warning' "PowerShell $requiredPSMajorVersion non trovato. Inizio download e installazione..."

        $installerUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/PowerShell-7.5.2-win-x64.msi"
        $installerPath = Join-Path $env:TEMP 'PowerShell-latest.msi'

        # Forza TLS 1.2 per la compatibilità con GitHub.
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        try {
            Write-StyledMessage 'Info' "Tentativo di download con Invoke-WebRequest..."
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing -Headers @{ 'User-Agent' = 'Mozilla/5.0' }
        }
        catch {
            Write-StyledMessage 'Warning' "Invoke-WebRequest fallito. Tentativo con BITS..."
            try {
                Start-BitsTransfer -Source $installerUrl -Destination $installerPath
            }
            catch {
                Write-StyledMessage 'Error' "Download di PowerShell fallito. Errore: $($_.Exception.Message)"
                return # Interrompe la funzione se il download fallisce
            }
        }

        if (Test-Path $installerPath) {
            Write-StyledMessage 'Info' "Installazione di PowerShell $requiredPSMajorVersion in corso (silenziosa)..."
            Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /qn" -Wait
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
    }

    # Se l'installazione è andata a buon fine (o era già presente) e siamo in una versione vecchia, riavvia.
    if (Test-Path $pwshExePath) {
        Write-StyledMessage 'Success' "PowerShell $requiredPSMajorVersion rilevato. Riavvio lo script per utilizzare la versione corretta..."
        $scriptArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`""
        Start-Process -FilePath $pwshExePath -ArgumentList $scriptArgs
        exit # Termina la sessione corrente
    }
    else {
        Write-StyledMessage 'Error' "Installazione di PowerShell $requiredPSMajorVersion fallita. Lo script potrebbe non funzionare correttamente."
    }
}

function Install-RequiredModules {
    <#
    .SYNOPSIS
        Installa i moduli PowerShell necessari per il toolkit.
    #>
    $modules = @('PSReadLine', 'ThreadJob')

    foreach ($module in $modules) {
        try {
            if (-not (Get-Module -ListAvailable -Name $module)) {
                Write-StyledMessage 'Info' "Installazione modulo richiesto: $module..."
                Install-Module -Name $module -Force -Scope CurrentUser -AllowClobber -Repository PSGallery
            }
        }
        catch {
            Write-StyledMessage 'Error' "Impossibile installare il modulo '$module'. Errore: $($_.Exception.Message)"
        }
    }
}

#endregion Gestione Aggiornamento PowerShell

# =================================================================================
# BLOCCO DI ESECUZIONE PRINCIPALE
# =================================================================================

# Esegue il controllo e l'aggiornamento di PowerShell una sola volta all'avvio.
Ensure-PowerShellModern
Install-RequiredModules

# Esegui routine profilo (CTT) subito
Invoke-WinUtilInstallPSProfile

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
    )
    foreach ($line in $asciiArt) {
        Write-StyledMessage 'Info' (Center-Text -Text $line -Width $width)
    }
    Write-Host '' # Spazio

    # --- Definizione e visualizzazione del menu ---
    $scripts = @(
        [pscustomobject]@{ Name = 'WinRepairToolkit.ps1'; Description = 'Avvia il Toolkit di Riparazione Windows' }
        [pscustomobject]@{ Name = 'WinUpdateReset.ps1'  ; Description = 'Esegui il Reset di Windows Update' }
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
        Write-StyledMessage 'Success' 'Grazie per aver usato il toolkit. Chiusura in corso...'
        Start-Sleep -Seconds 2
        break # Esce dal ciclo while ($true) e termina lo script.
    }

    # Verifica se l'input è un numero valido e rientra nel range delle opzioni.
    if (($userChoice -match '^\d+$') -and ([int]$userChoice -ge 1) -and ([int]$userChoice -le $scripts.Count)) {
        $selectedIndex = [int]$userChoice - 1
        $selectedScript = $scripts[$selectedIndex]
        $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath $selectedScript.Name

        if (Test-Path $scriptPath) {
            Write-StyledMessage 'Info' "Avvio di '$($selectedScript.Description)'..."
            try {
                # Esegue lo script selezionato.
                & $scriptPath
            }
            catch {
                Write-StyledMessage 'Error' "Si è verificato un errore durante l'esecuzione di '$($selectedScript.Name)'."
                Write-StyledMessage 'Error' "Dettagli: $($_.Exception.Message)"
            }
        }
        else {
            Write-StyledMessage 'Error' "Script '$($selectedScript.Name)' non trovato nella directory '$($PSScriptRoot)'."
        }
        
        # Pausa prima di tornare al menu principale
        Write-Host "`nPremi un tasto per tornare al menu principale..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    else {
        Write-StyledMessage 'Error' 'Scelta non valida. Riprova.'
        Start-Sleep -Seconds 2
    }
} # Fine del ciclo while