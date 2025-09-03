# Win-Toolkit

## Bugfix

### run.ps1

- [ ] Rendere il Tool online come Chris per bypassare i problemi di esecuzione

## Versione Publica

- [ ] Avvio script Chris con config personalizzata iwr -useb https://christitus.com/win | iex
- [ ] Aggiungere esecuzione di Tron Script
- [ ] Download ultima versione di DDU
  - [ ] Estrazione
  - [ ] Posizionamento nella cartella Downloads
  - [ ] Riavvio modalità provvisoria
  - [ ] Installazione Driver (Nvidia / AMD)
- [ ] Installazione Office Personalizzata
- [ ] Riparazione Office
- [ ] Installazione Store
- [ ] Reset Rust Desk
- [ ] Scarica immagine di Windows 23H2 Microwin

## Versione Privata

- [ ] Attivazione windows irm https://massgrave.dev/get | iex
- [ ] "Emergency Mode" => Scarica il necessario in modo da poter facilmente ricreare ovunque "MagnetarMan Secret Box"

## Installazione Store

winget.exe install 9WZDNCRFJBMP

Chiede se funziona tutto

Metodo 2 (Manifest Windows)

Get-AppxPackage -allusers Microsoft.WindowsStore | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($\_.InstallLocation)\AppXManifest.xml"}

Metodo 3 (Dism)

DISM /Online /Add-Capability /CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0

Metodo 4 (PowerShell Invoke-WebRequest Mode)

Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx
Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx -OutFile Microsoft.UI.Xaml.2.7.x64.appx
Add-AppxPackage Microsoft.VCLibs.x64.14.00.Desktop.appx
Add-AppxPackage Microsoft.UI.Xaml.2.7.x64.appx
Add-AppxPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle

---

Aggiungere nel Readme che a causa di limitazioni delle impostazioni di Windows per eseguire correttamente lo script bisogna eseguire questa procedura:

1. Aprire il terminale di windows andando in start => digitare "terminale" nella barra di ricerca => [Tasto destro del mouse => Eseguire come amministratore]
2. Incollare singolarmente questi comandi
3. Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy Bypass
4. Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass
5. Alle richieste di conferma inserire il carattere s e premere invio tutte e due le volte
6. Controllare nelle proprietà del file "run.ps1" che il file non risulti bloccato.
7. Proseguire con la regolare esecuzione dello script

## Reset Rust Desk

Cancellare cartella %APPDATA%\RustDesk\config

## Prompt Principale

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

Mantenendo questo Tono e Stile creami uno script in linguaggio powershell che esegua le seguenti operazioni logiche.

Genera un codice pulito facile da modificare e chiaro da leggere. Comportati come se fossi uno sviluppatore Senior in creazione di script per powershell, genera un codice professionale.

run.ps1 =>

- Controlla se è eseguito su powershell 5 o 7.
  - Opzione 1
    - Se viene eseguito su powershell 5 procede all'installazione dell'ultima versione di powershell 7 ed alla sua installazione.
  - Opzione 2
  - Se viene eseguito su Powershell 7 assicurati che lo script sia stato avviato in modalità amministratore, altrimenti segnalalo all'utente con un messaggio di allerta chiaro e scrivi di premere un tasto. Alla pressione del tasto verrà avviata una nuova istanza di powershell 7 in modalità amministratore e lo script "run.ps1" partirà da 0. Una volta che ti sei accertato che sei su powershell 7 e che sei in modalità amministratore.
- Installa il Profilo Powershell di Chris Tech Titus partendo da questo codice e riadattandolo per essere funzionante al 100% nello script che stai generando:
- Installazione Profilo Powershell (TNKS @ChrisTitusTech)
  - Completata L'installazione di Powershell 7 e del profilo powershell avvia una nuova instanza con privilegi di amministratore in powershell 7 lanciando lo script denominato "WinStarter.ps1" posizionato nella sotto cartella tool quindi il percorso sarà /tool/WinStarter.ps1. La sotto cartella tool si trova nello stesso percorso in cui si trova questo script per cui adegua la logica in modo il tutto funzioni
  - Se powershell 7 è gia installato e quindi troviamo nell'opzione 2 lancia lo script denominato "WinStarter.ps1" posizionato nella sotto cartella tool quindi il percorso sarà /tool/WinStarter.ps1. La sotto cartella tool si trova nello stesso percorso in cui si trova questo script per cui adegua la logica in modo il tutto funzioni

=> MagnetarMan Mode

- Avvio utility di chris con le opzioni suggerite
- Reinstallazione Store e Winget
- Scelta ed installazione Driver Video (AMD, Nvidia)
- Installazione Offile Personalizzato (Word, Excel, PowerPoint)
- Reset Rust Desk (Kill Processo Rustdesk se in esecuzione, Pulizia cartella Profilo)
- Controllo Disco con opzione Disco Dirty attiva
- Riavvio Sistema
