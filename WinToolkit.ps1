<#
.SYNOPSIS
    Un toolkit per eseguire script di manutenzione e gestione di Windows.
.DESCRIPTION
    Questo script funge da menu principale per un insieme di strumenti di manutenzione e gestione di Windows.
    Permette agli utenti di selezionare ed eseguire vari script PowerShell per compiti specifici.
.NOTES
  Versione 2.1 (Build 1) - 2025-09-17
#>

param([int]$CountdownSeconds = 10)
# Imposta il titolo della finestra di PowerShell per un'identificazione immediata.
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan"

# Imposta una gestione degli errori più rigorosa per lo script.
# 'Stop' interrompe l'esecuzione in caso di errore, permettendo una gestione controllata tramite try/catch.
$ErrorActionPreference = 'Stop'

# Creazione directory di log e avvio trascrizione
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\WinToolkit\logs"
try {
    [System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
    Start-Transcript -Path "$logdir\WinToolkit_$dateTime.log" -Append -Force | Out-Null
}
catch {
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
        Info    = @{ Color = 'White'  ; Icon = '💎' }
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

# Installazione del profilo PowerShell
function WinInstallPSProfile {
 
}

# Riparazione di Windows
function WinRepairToolkit {
  
}

# Reset di Windows Update
function WinUpdateReset {

}

function WinReinstallStore {

}

#function WinBackupDriver {}


function OfficeToolkit {
     
}

#function ResetRustDesk {}

function WinBackupDriver {
    
}

#function WinDriverInstall {}

#function GamingToolkit{}


# Ciclo principale del programma: mostra il menu e attende una scelta.
while ($true) {
    Clear-Host
    $width = 65
    Write-Host ('═' * $width) -ForegroundColor Green
    $asciiArt = @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        '       Toolkit By MagnetarMan',
        '       Version 2.1 (Build 1)'
    )
    foreach ($line in $asciiArt) {
        Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
    }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''

    # --- Definizione e visualizzazione del menu organizzato per categorie ---
    $menuStructure = @(
        @{
            'Name'    = 'Operazioni Preliminari'
            'Icon'    = '⚠️'
            'Scripts' = @(
                [pscustomobject]@{ Name = 'WinInstallPSProfile'; Description = 'Installa il profilo PowerShell.'; Action = 'RunFunction' }
            )
        },
        @{
            'Name'    = 'Backup & Tool'
            'Icon'    = '📦'
            'Scripts' = @(
                [pscustomobject]@{ Name = 'ResetRustDesk'; Description = 'Reset Rust Desk. - Planned V2.2'; Action = 'RunFunction' }
                [pscustomobject]@{ Name = 'WinBackupDriver'; Description = 'Backup Driver PC. - Planned V2.2'; Action = 'RunFunction' }
                [pscustomobject]@{ Name = 'OfficeToolkit'; Description = 'Office Toolkit. - Planned V2.1'; Action = 'RunFunction' }
            )
        },
        @{
            'Name'    = 'Riparazione Windows'
            'Icon'    = '🔧'
            'Scripts' = @(
                [pscustomobject]@{ Name = 'WinRepairToolkit'; Description = 'Toolkit Riparazione Windows.'; Action = 'RunFunction' }
                [pscustomobject]@{ Name = 'WinUpdateReset'; Description = 'Reset di Windows Update.'; Action = 'RunFunction' }
                [pscustomobject]@{ Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset. - Planned V2.2'; Action = 'RunFunction' }
            )
        },
        @{
            'Name'    = 'Driver & Gaming'
            'Icon'    = '🎮'
            'Scripts' = @(
                [pscustomobject]@{ Name = 'WinDriverInstall'; Description = 'Toolkit Driver Grafici. - Planned V2.3'; Action = 'RunFunction' }
                [pscustomobject]@{ Name = 'GamingToolkit'; Description = 'Gaming Toolkit. - Planned V2.4'; Action = 'RunFunction' }
            )
        }
    )

    # Aggiorna anche il ciclo foreach per questa struttura:
    $allScripts = @()
    $scriptIndex = 1

    foreach ($category in $menuStructure) {
        # Visualizzazione del titolo della categoria
        $categoryTitle = "=== $($category.Icon) $($category.Name) $($category.Icon) ==="
        Write-Host $categoryTitle -ForegroundColor DarkYellow
        Write-Host ''
    
        # Visualizzazione degli script della categoria
        foreach ($script in $category.Scripts) {
            $allScripts += $script
            Write-StyledMessage 'Info' "[$scriptIndex] $($script.Description)"
            $scriptIndex++
        }
    
        Write-Host '' # Spazio tra le categorie
    }

    # Sezione di uscita
    Write-Host "=== Uscita ===" -ForegroundColor Red
    Write-Host ''
    Write-StyledMessage 'Error' '[0] Esci dal Toolkit'
    Write-Host ''

    # --- Logica di gestione della scelta utente ---
    $userChoice = Read-Host "Quale opzione vuoi eseguire? (0-$($allScripts.Count))"

    if ($userChoice -eq '0') {
        Write-StyledMessage 'Warning' 'In caso di problemi, contatta MagnetarMan su Github => Github.com/Magnetarman.'
        Write-StyledMessage 'Success' 'Grazie per aver usato il toolkit. Chiusura in corso...'
        Start-Sleep -Seconds 5
        break # Esce dal ciclo while ($true) e termina lo script.
    }

    # Verifica se l'input è un numero valido e rientra nel range delle opzioni.
    if (($userChoice -match '^\d+$') -and ([int]$userChoice -ge 1) -and ([int]$userChoice -le $allScripts.Count)) {
        $selectedIndex = [int]$userChoice - 1
        $selectedItem = $allScripts[$selectedIndex]

        Write-StyledMessage 'Info' "Avvio di '$($selectedItem.Description)'..."
        try {
            if ($selectedItem.Action -eq 'RunFile') {
                $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath $selectedItem.Name
                if (Test-Path $scriptPath) {
                    & $scriptPath
                }
                else {
                    Write-StyledMessage 'Error' "Script '$($selectedItem.Name)' non trovato nella directory '$($PSScriptRoot)'."
                }
            }
            elseif ($selectedItem.Action -eq 'RunFunction') {
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
        Start-Sleep -Seconds 3
    }
}
