<#
.SYNOPSIS
    Un toolkit di avvio per eseguire script di manutenzione di Windows.
.DESCRIPTION
    Questo script funge da menu principale per un insieme di strumenti di manutenzione e gestione di Windows.
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
        [pscustomobject]@{ Name = 'WinRepairToolkit.ps1'; Description = 'Avvia il Toolkit di Riparazione Windows.' }
        [pscustomobject]@{ Name = 'WinUpdateReset.ps1'  ; Description = 'Esegui il Reset di Windows Update.' }
        [pscustomobject]@{ Name = 'WinReinstallStore.ps1'  ; Description = 'Reinstalla Winget ed il Windows Store.' }
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