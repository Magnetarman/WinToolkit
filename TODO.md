# To-Do


### V 2.5.1

- Adeguamento Repository alle regole di Github.
  - [x] Rinominato CONTRIBUTORS.md => CONTRIBUTING.md.
  - [x] Creazione documento Codice di condotta `CODE_OF_CONDUCT.md`.
  - [x] Eliminata sezione contributori dal readme.
  - [x] Integrata la sezione contributori nel menu di Github.

- Funzione WinRepairToolkit Potenziata. [[Thanks to @zakkos]](https://www.youtube.com/c/zakkos)
  - [x] Fix pulizia non corretta output durante le barre di progressione.
  - [x] Aumentato il Timeout delle funzioni in modo da non far fallire le operazioni anche su sistemi datati e poco potenti.
  - [x] Reso automatico ed "intelligente" l'invocazione della riparazione profonda (Se Checkdisk non genera errori gravi la riparazione profonda non verrà invocata al riavvio del PC).

- `start.ps1` potenziato.
  - [x] Refactoring del codice con maggiore coerenza strutturale e leggibilità.
  - [x] Ottimizzazione del flusso di esecuzione dello script e riduzione dei passaggi ridondanti.
  - [x] Migliore organizzazione delle chiamate alle funzioni già esistenti (nessuna funzione rimossa o aggiunta, ma rivista la logica interna).
  - [x] Migliorata la verifica della compatibilità e della versione di winget.
  - [x] Aggiunti controlli e tentativi automatici di ripristino del package manager.
  - [x] Rafforzata la gestione degli errori durante installazioni via winget.
  - [x] Logging più chiaro sugli esiti delle installazioni (successo/fallimento).
  - [x] Maggiore robustezza nei processi di installazione (Git, PowerShell, Windows Terminal, Nerd Fonts, ecc.).
  - [x] Migliorata la gestione dei fallback quando un’installazione non va a buon fine.
  - [x] Ridotti i casi di blocco dello script in presenza di prerequisiti mancanti.
  - [x] Incremento dei blocchi try/catch per una gestione più sicura delle eccezioni.
  - [x] Messaggi di errore più esplicativi e contestualizzati.
  - [x] Miglior gestione dei processi interferenti e dei timeout.
  - [x] Messaggistica più chiara e uniforme tramite Write-StyledMessage.
  - [x] Miglioramento dei feedback a schermo durante tutte le fasi dello script.
  - [x] Distinzione più netta tra messaggi informativi, warning, errori e successi.
  - [x] Migliorata la retrocompatibilità con ambienti Windows differenti.
  - [x] Rafforzati i controlli su prerequisiti di sistema (es. VC Redist, profili locali, terminale).

- Profilo Powershell Aggiornato. `V 2.5.1.10`
  - [x] Aggiunto comando per effettuare uno speedtest del PC.
    - [x] Inserito Salvataggio risultati in documento .txt sul desktop.
  - [x] Eliminate Funzioni Ridondanti.
  - [x] Riorganizzata sezione help per maggiore chiarezza.
  - [x] Aggiunta funzione offline di reset delle risorse di rete. [[Thanks to @ChrisTitusTech]](https://github.com/ChrisTitusTech)
  - [x] Aggiunta funzione di aggiornamento del profilo Powershell personalizzato.
    - [x] `start.ps1` non più necessario per aggiornare il profilo powershell.
  - [x] Find-File: Resa compatibile con la pipeline di PowerShell.
    - [x] Eliminata la funzione wrapper `EditProfile` che duplicava `EditPSProfile`.
    - [x] Documentazione aggiornata per riflettere il singolo comando disponibile.
  - [x] Get-PreferredEditor: Migliorata la ricerca degli editor.
    - [x] Prioritizzata la ricerca nel $PATH rispetto ai percorsi hardcoded.
    - [x] Maggiore compatibilità con installazioni tramite Scoop, Chocolatey e altri package manager.
  - [x] Aggiornamento PowerShell: Aggiunto controllo privilegi amministratore.
    - [x] Il sistema ora verifica preventivamente i privilegi prima di tentare l'aggiornamento.
    - [x] Messaggi di errore più chiari e informativi per l'utente.
  - [x] Get-ProfileDir: Semplificata la logica di rilevamento directory profilo.
    - [x] Utilizzo di Split-Path -Parent $PROFILE per maggiore affidabilità.
    - [x] Codice più pulito e meno soggetto a errori.
  
- Rework Gestione `To-Do.md`.
  - [x] Eliminazione `To-Do.md` dal Ramo main.
  - [x] Redirect con link hardcode al `To-Do.md` nel ramo Dev.


### V 2.5.2

- `WinToolkit.ps1` Aggiornato.
  - [ ] Aggiunti nuovi script.
  - [ ] Riorganizzato il menu principale per maggiore chiarezza.

- `WinReinstallStore.ps1` Aggiornato.
  - [ ] Fix Output non correttamente soppresso. 

- Aggiunta Funzione `WinUpdateDisabler.ps1`.
  - [ ] Add script relativo e funzioni nel template.
  - [ ] Disabilita permanentemente Windows Update con possibilità di ripristino.

- Aggiunta Funzione `WinUpdateSet.ps1` (Windows Home non supportato).
  - [ ] Add script relativo e funzioni nel template.
  - [ ] Imposta tramite criteri di gruppo gli Update di windows.


### V 2.6 - Debloat

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
