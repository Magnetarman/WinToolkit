# To-Do

### V 2.5.1

- Funzione WinUpdateDisabler.
  - [ ] Add script relativo e funzioni nel template.
  - [ ] Disabilita permanentemente Windows Update con possibilità di ripristino.
  
  - Funzione WinRepairToolkit Potenziata. [[Thanks to @zakkos]](https://www.youtube.com/c/zakkos)
    - [x] Fix pulizia non corretta output durante le barre di progressione.
    - [x] Aumentato il Timeout delle funzioni in modo da non far fallire le operazioni anche su sistemi datati e poco potenti.
    - [x] Reso automatico ed "intelligente" l'invocazione della riparazione profonda (Se Checkdisk non genera errori gravi la riparazione profonda non verrà invocata al riavvio del PC)
    
- [x] Adeguamento Repository alle regole di Github.
  - [x] Rinominato CONTRIBUTORS.md => CONTRIBUTING.md.
  - [x] Creazione documento Codice di condotta `CODE_OF_CONDUCT.md`.
  - [x] Eliminata sezione contributori dal readme.
  - [x] Integrata la sezione contributori nel menu di Github.

- [ ] Potenziato `start.ps1` [[Thanks to @Matteoz]](https://t.me/teo180)
  - [x] Logica "Force Portable" per Windows Terminal: Nuova funzione Install-WindowsTerminalManual che permette l'estrazione manuale dei binari dal pacchetto .msixbundle in caso di fallimento dei metodi standard.
  - [x] Centralizzazione URL: Inserito l'endpoint GitHub API per le release di Windows Terminal nella configurazione $script:AppConfig per una gestione dinamica degli aggiornamenti.
  - [x] Sistema di Fallback Multi-Livello: Implementata una catena di installazione resiliente per Windows Terminal (Winget -> Appx Nativo -> Estrazione Manuale -> MS Store).
  - [x] Variabile Globale CustomWTPath: Introdotta per tracciare il percorso dell'eseguibile in caso di installazione portatile non standard.
  - [x] Ottimizzazione Invoke-WinToolkitSetup: Centralizzata la costruzione dello scriptblock di rilancio per garantire coerenza tra i vari passaggi di privilegi e versioni di shell.
  - [x] Logica di Riavvio Intelligente: Migliorato l'avvio finale che ora tenta di lanciare lo script in Windows Terminal + PowerShell 7, con fallback automatico su console legacy in caso di errore.
  - [x] Refactoring Install-WindowsTerminalApp: La funzione ora verifica preventivamente la presenza di installazioni portatili esistenti prima di tentare nuovi download.
  - [x] Gestione Logging: Spostata e protetta la creazione delle directory di log con blocchi try-catch per evitare interruzioni su sistemi con permessi ristretti.
  - [x] Gestione Flusso Reboot: Spostata la logica rebootNeeded al termine della catena di avvio per prevenire la chiusura prematura dello script durante la fase di setup.
  - [x] Resilienza Winget: Migliorato il rilevamento degli errori durante il ripristino di Winget, differenziando tra metodo "veloce" (bundle) e "avanzato" (moduli PowerShell).
  - [x] Aggiunto check ulteriore dell'eseguibile Windows Terminal. In caso di applicativi corrotti viene forzata l'installazione della versione Portable.
  - [x] Aggiunta la modifica dei vari puntatori di Windows alla nuova versione di Windows Terminal portable slegata dallo store di windows e da Winget in modo da garantire il funzionamento anche su sistemi fortemente danneggiati.
  

- Rework Gestione `To-Do.md`.
  - [x] Eliminazione `To-Do.md` dal Ramo main.
  - [x] Redirect con link hardcode al `To-Do.md` nel ramo Dev.
  


### V 2.5.2

- Rework Progetto GUI.
  - [ ] Rendere lo script GUI un semplice wrapper.
  - [ ] Inserire download ultima versione `Wintoolkit.ps1`.
  - [ ] Parsing e popolazione funzionalità.
  - [ ] Concatenzazione script da checkbox.
  - [ ] Avanzamento Barra di progressione.
  - [ ] Redirect Output scripts nel box Logs.
  

### V 2.6 - Auto Debloat

- [ ] Avvio dello script Chris con configurazione personalizzata (`iwr -useb https://christitus.com/win | iex`).
- **?** Deprovvisioning dell'immagine Windows 11 (studio di fattibilità in corso).
  
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

### V 2.10 - Multi Lang Mode - Codename: "Enza"

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
