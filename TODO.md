# To-Do

### V 2.5.3
- `WinReinstallStore.ps1` migliorato.
  - [x] Risolto Bug invalidante nella riparazione di Winget.
  - [x] Aggiornata la Pipeline di ripristino Store e Winget per adattarla alle modifiche di Windows 24H2 e 25H2.
  - [x] Fix id installazione UnigetUI causa cambio sviluppatore.

- `WinToolkit.ps1` Aggiornato.
  - [x] Centralizzata funzione di riparazione Winget.
  - [x] Eliminato codice ridondante.  

- `start.ps1` migliorato.  
  - [x] Risolto Bug invalidante nella riparazione di Winget.
  - [x] Aggiornata la Pipeline di ripristino Store e Winget per adattarla alle modifiche di Windows 24H2 e 25H2.
  - [x] Aggiunto check dello script di start interattivo per la verifica di aggiornamenti Windows in corso e Defender attivo.

- Aggiornata Pipeline CI/CD.
  - [x] Fix corretto azzeramento lista contributori dopo release pubblica.
  - [x] Creata Github action manuale per creazione Pull request di passaggio a Dev a main automatizzata.    


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
