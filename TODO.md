# To-Do

### V 2.5.2

- `OfficeToolkit.ps1` Riscritto.
  - [x] Semplificata logica generale dello script.
  - [x] Meno richieste inutili e maggiore automazione.
  - [x] Reso il debloat di office parametrizzabile.
  - [x] Risolto un'errore che portava lo script di riparazione a non effettuare il debloat a riparazione avvenuta
  - [x] Riscritta la funzione per disabilitare la telemetria di office aggiornando percorsi e chiavi.
  - [x] Aggiornata l'implementazione grafica del Toolkit ai nuovi standard.
  - [x] Automatizzate le operazioni di installazione/rimozione di Office.
  - [x] Migliorato il detect dei processi di installazione per non causare Race Condition.

- `start.ps1` Aggiornato.
  - [x] Aggiornate sezione .SYNOPSIS e .DESCRIPTION [[#39](https://github.com/MagnetarMan/WinToolkit/issues/39) [@pomodori92]](https://github.com/pomodori92).
  - [x] Aggiornata funzione di aggiornamento del Profilo powershell rendendola maggiormente robusta.
  - [x] Rifattorizzata la funzione di creazione del collegamento di WinToolkit.
  - [x] Nuova Update-EnvironmentPath (L111): ricarica $env:Path da Machine+User per rilevare winget appena installato senza riavviare lo script.
  - [x] Fix bug critico $tempDir: nel fallback MSIXBundle di Install-WingetPackage la variabile non esisteva in quello scope — ora usa $AppConfig.Paths.Temp con splatting
  - [x] Rafforzamento Install-WingetCore.
  - [x] Potenziamento Gestione del Terminale Predefinito.
  - [x] Ottimizzazione Path.
  - [x] PATH refresh nell'orchestrazione: Update-EnvironmentPath chiamata prima del check iniziale e dopo ogni tentativo di install — elimina i falsi negativi post-installazione.
  - [x] Fix Write-Host nel countdown reboot → Write-StyledMessage -Type Warning.
  - [x] Aggionato Show-Header [[#40](https://github.com/MagnetarMan/WinToolkit/issues/40) [@pomodori92]](https://github.com/pomodori92).
  - [x] Introdotta la generazione dinamica dell’icona desktop all’avvio del ramo di sviluppo.
  - [x] Rimosse le configurazioni hardcoded, migliorando flessibilità e manutenibilità del codice.
  - [x] Ottimizzata la gestione del processo per garantire maggiore coerenza tra ambienti e versioni.
  - [x] Modificata l'installazione di Powershell7 preferendo la veloce installazione tramite Winget ed utilizza come fallback il download e l'installazione diretta.

- `WinRepairToolkit.ps1` Aggiornato.
  - [x] Aggiunto nuovo check per le funzioni addizionali Registrazione AppX (Client CBS), Registrazione AppX (UI Xaml CBS), Registrazione AppX (Client Core), in modo che vengano eseguite solo su sistemi interessati dalla problematica (Windows 11 24H2 e superiori).
  - [x] Aggiunto una GESTIONE INTERRUZIONI (CTRL+C), che invece di interrompere bruscamente il Toolkit mitiga l'effetto permettendo la copia corretta dei messaggi di stato nel terminale.

- `WinToolkit-template.ps1` Aggiornato.
  - [x] La funzione `Initialize-ToolLogging` usa path hardcoded. Fix applicato.
  - [x] `Invoke-Expression` è un anti-pattern di sicurezza. Fix applicato.
  - [x] Aggiornato Show-Header in modo da allineare la [PR #40](https://github.com/MagnetarMan/WinToolkit/issues/40).

- `WinReinstallStore.ps1` Aggiornato.
  - [x] Helper locali ridondanti rimossi: Clear-ProgressLine, Stop-InterferingProcesses, Test-WingetAvailable erano tutti già disponibili globalmente nel template.
  - [x] $ErrorActionPreference globale eliminato in tutte e 3 le funzioni → -ErrorAction SilentlyContinue per operazione.
  - [x] Write-StyledMessage corretta da sintassi posizionale Write-StyledMessage Info "..." a Write-StyledMessage -Type 'Info' -Text "...".
  - [x] Invoke-WithSpinner adottato per tutti i processi lunghi: Repair-WinGetPackageManager, MSIXBundle, App Installer reset, Store install, UniGetUI install.
  - [x] Fix catch vuoto in Install-UniGetUI → logga l'eccezione con Write-StyledMessage -Type 'Error'.
  - [x] Write-Host nel finally rimosso → gestione riavvio delegata a Start-InterruptibleCountdown.
  - [x] Risolti i problemi che potrebbero causare rotture grafiche dello script durante l'esecuzione.
  - [x] Adeguato lo script alle linee generali di stile del progetto. 

- `WinCleaner.ps1` Aggiornato.
  - [x] Aumentato il comando di Timeout a 24h [[#45](https://github.com/Magnetarman/WinToolkit/issues/45) [@pomodori92]](https://github.com/pomodori92).
  - [x] Aggiunto check per verifica dell'errore -2146498554 con inserimento di avvertimento per l'utente.
  - [x] Migliorata la cancellazione dei Residui di Windows Update. i servizi adesso vengono correttamente stoppati, viene effettuata la pulizia ed infine i servizi vengono riavviati.

- `Microsoft.PowerShell_profile.ps1` Potenziato.
  - [x] Potenziata e resa completa la funzion PS-Reset.
  - [x] Esegue ora un rollback completo dell'ambiente in modo da resettare il sistema su cui è stato avviato WinToolkit.

- Pipeline CI/CD Riscritta e potenziata.
  - [x] `compiler.ps1` Aggiornato.
  - [x] Logging aggiornato TimeStamp + Enum-based.
  - [x] Aggiunto Motore di Minificazione, che elimina lo splatting e compatta il codice per massimizzare l'ottimizzazione a discapito della lettura.
  - [x] Rimozione dei commenti in blocco.
  - [x] Dashboard di Compilazione finale riscritta totalmente e potenziate.
  - [x] Encoding è forzato rigorosamente a UTF8-NoBOM via UTF8Encoding $false per migliorare il supporto.
  - [x] Lo script ora accetta -StripComments dalla riga di comando o da pipeline CI/CD.
  - [x] L'etichetta di $warningCount nel box di riepilogo è ora più descrittiva.
  - [x] Blocco di assemblaggio potenziato. Adesso esegue una Validazione, StripComments e Logging injection.
  - [x] Aggiunta una suite di test estensiva prima della compilazione in modo da evitare errori di sintassi.
  - [x] Migliorata la struttura all'interno della cartela .github in modo da migliorare la manutenzione e la leggibilità del codice della Pipeline CI/CD. 
  - [x] Aggiornata PiPeline CI/CD in modo da integrare una creazione di Pre-Release ad ogni rilascio in dev, con citazione di eventuali PR effettuati dagli utenti.[[Requested by @Pomodori92]](https://github.com/pomodori92).

- `WinUpdateReset.ps1` Aggiornato.
  - [x] Migliorata l'esecuzione dello script riducendo il codice boilerplate.
  - [x] Aggiornata la visualizzazione per essere il tema con il resto del progetto.
  - [x] Risolto un bug che causava scritte non allineate durante l'esecuzione.

- `WinBackupDriver.ps1` Aggiornato.
  - [x] Risolto un problema per cui su PC poco potenti il timeout rendeva nulla la funzionalità dello script. Maggiorati a 800 secondi i timeout.
  - [x] Risolto il problema della richiesta doppio escape.

- `WinToolkit-GUI.ps1` Aggiornato.
  - [x] Risolto un bug Grafico dovuto a modifiche nel ramo V 2.5.0.
  - [x] Aggiornata Funzione check bitlooker.
  - [x] Aggiunto download e caricamento Favicon ToolKit.
  - [x] Migliorata la grafica della barra di avanzamento personalizzata.
  - [x] Resa maggiormente fluida l'animazione di riempimento della barra di avanzamento personalizzata.  


### V 2.6 - Debloat

- `WinToolkit.ps1` Aggiornato.
  - [ ] Aggiunti nuovi script.
  - [ ] Riorganizzato il menu principale per maggiore chiarezza.

- Aggiunta Funzione `WinUpdateDisabler.ps1`.
  - [ ] Add script relativo e funzioni nel template.
  - [ ] Disabilita permanentemente Windows Update con possibilità di ripristino.

- Aggiunta Funzione `WinUpdateSet.ps1` (Windows Home non supportato).
  - [ ] Add script relativo e funzioni nel template.
  - [ ] Imposta tramite criteri di gruppo gli Update di windows.

- <del>Avvio dello script Chris con configurazione personalizzata (`iwr -useb https://christitus.com/win | iex`).</del>
  - **Questa funzione a causa di lacune nel debloat di Windows 11 ramo *Germanium* 24H2/25H2 verrà corretta ed integrata in uno script nuovo denominato `WinDebloat.ps1`**
- Aggiunta Funzione `WinDebloat.ps1`.
  - [ ] Aggiunta Disattivazione Servizi superflui.


### V 2.7 - Security Update

- [ ] Download ed esecuzione di Tron Script con intervento minimo.
- [ ] Reset dei servizi Windows **[Thanks to @sicolla]**.
- [ ] Riparazione avanzata Windows Search **[Thanks to @sicolla]**.


### V 2.8 - WinDownloader

- [ ] Download script preconfigurati dal sito UUP Dump.
  - [ ] Avvio Creazione automatica ISO di Windows 10/11.
    - <del>Windows 11 25H2</del> **(Instabile)**
    - [ ] Windows 11 24H2.
    - [ ] Windows 11 23H2.
    - [ ] Windows 10 22H2.
    - [ ] Windows 10 21H2.
  - [ ] Implementazione Download ISO Ufficiale di Windows 8.1.
  - [ ] Implementazione Download ISO Ufficiale di Windows 7 SP1.
  - [ ] Implementazione Download ISO Ufficiale di Windows XP SP3.
  - [ ] Download Automatico di Rufus.
  - [ ] Creazione di dispositivo USB Bootable.
  - [ ] Inserimento funzione Blocco selettivo Update Windows.


### V 2.9 - OFFLINE MODE 

- [ ] Possibilità di avviare il download delle ultime risorse necessarie al toolkit.
- [ ] Salvataggio in file .7z da estrarre.
- [ ] L'archivio conterrà tutto il necessario ad utilizzare Wintoolkit in modalità offline senza rete.


### V 2.10 - Multi Lang Mode

- [ ] Conversione Readme.md in inglese.
- [ ] Possibilità di scegliere la lingua all'avvio di Wintoolkit.


### V X.X - MagnetarMan Mode

- [ ] Avvio Script Chris con configurazione personalizzata.
  - [ ] Installazione programmi: Brave Browser, Google Chrome, Betterbird, Fan Control, PowerToys, Uniget, Crystal Disk Info, HwInfo, Rust Desk, Client Giochi (Amazon, Gog Galaxy, Epic Games, Steam).
  - [ ] Installazione .NET Runtime (dalla 4.8 alla 9.0).
  - [ ] Installazione Microsoft C++ Package.
  - [ ] Installazione/Aggiornamento Directx.
  - [ ] Installazione Playnite (Launcher/Aggregatore).
  - [ ] Installazione Revo Uninstaller.
  - [ ] Installazione Tree Size.
  - [ ] Installazione Glary Utilities.
  - [ ] Pulizia del sistema.
  - [ ] Applicazione Sfondo "MagnetarMan".
  - [ ] Riavvio del PC per completare le modifiche.


### V X.X - GUI

- Rework Progetto GUI.
- [ ] Rendere lo script GUI un semplice wrapper.
- [ ] Inserire download ultima versione `Wintoolkit.ps1`.
- [ ] Parsing e popolazione funzionalità.
- [ ] Concatenzazione script da checkbox.
- [ ] Avanzamento Barra di progressione.
- [ ] Redirect Output scripts nel box Logs.
- **?** Deprovvisioning dell'immagine Windows 11 (studio di fattibilità in corso).
