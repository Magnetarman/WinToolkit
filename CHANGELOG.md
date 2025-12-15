# Changelog

Tutte le modifiche significative apportate a questo progetto saranno documentate in questo file.

Il formato si basa su [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) e questo progetto aderisce al [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## Versioni Pianificate [In sviluppo]

Questo è lo stato attuale del progetto, che include le funzionalità in fase di sviluppo.

### Aggiunte

- **Funzione Auto Debloat (`V2.6`):**
  - Avvio dello script Chris con configurazione personalizzata
    (`iwr -useb https://christitus.com/win | iex`).
- **Funzione Security Update (`V2.7`):**
  - Download ed esecuzione di Tron Script con intervento minimo.
- **Funzione Security Update+ (`V2.8`):**
  - Reset dei servizi Windows **[Thanks to @sicolla]**
  - Riparazione avanzata Windows Search **[Thanks to @sicolla]**
  - Pulizia Cache dei Browser
  - Potenziamento Toolkit di Riparazione Windows **[Thanks to @Progressfy]**
- **Funzione WinDownloader (`V2.9`):**
  - Download script preconfigurati dal sito UUP Dump.
  - Avvio Creazione automatica ISO di Windows 10/11
    - <del>Windows 11 25H2</del> **(Instabile)**
    - Windows 11 24H2
    - Windows 11 23H2
    - Windows 10 22H2
    - Windows 10 21H2
  - Implementazione Download ISO Ufficiale di Windows 8.1
  - Implementazione Download ISO Ufficiale di Windows 7 SP1
  - Implementazione Download ISO Ufficiale di Windows XP SP3
- **Funzione WinDownloader+ (`V2.10`):**
  - Potenziamento Funzione WinDownloader
  - Download Automatico di Rufus
  - Creazione di dispositivo USB Bootable
  - Inserimento funzione Blocco selettivo Update Windows
- **MagnetarMan Mode (`V3.0`):**
  - Avvio Script Chris con configurazione personalizzata.
  - Installazione programmi: Brave Browser, Google Chrome,
    Betterbird, Fan Control, PowerToys, Uniget, Crystal Disk Info,
    HwInfo, Rust Desk, Client Giochi (Amazon, Gog Galaxy, Epic
    Games, Steam).
  - Installazione .NET Runtime (dalla 4.8 alla 9.0).
  - Installazione Microsoft C++ Package.
  - Installazione/Aggiornamento Directx.
  - Installazione Playnite (Launcher/Aggregatore).
  - Installazione Revo Uninstaller.
  - Installazione Tree Size.
  - Installazione Glary Utilities.
  - Pulizia del sistema.
  - Applicazione Sfondo "MagnetarMan".
  - Riavvio del PC per completare le modifiche.
- **OFFLINE MODE (`V3.1`):**
- **Bugfix e Conversione per la GUI Mode (`V4.0`)**
- **GUI Mode (`V5.0`):**
  - Win toolkit con tutta la semplicità della GUI
  - Nessun comando da terminale da inserire

### Correzioni

### Modifiche

---

## [2.5.0] - 2025-12-04 (#21)

### Aggiunte

- Funzione **Win Cleaner** Potenziata.
  - Potenziamento della funzione di pulizia in varie aree del sistema. [Thanks to @Privacy.sexy Project](https://privacy.sexy/)
- Sezione **Informazioni di Sistema** Potenziata.
  - Aggiunto il check (da Windows 25H2 Microsoft lo attiva a sua discrezione) per verificare l'attivazione o meno di bitlocker. In caso affermativo è stata aggiunta un nuovo script nella sezione "Windows" di disattivazione di bitlocker in caso di attivazione non voluta. **[Thanks to @Valeriogalano]**
  - Reso il campo "Disco:" che indica lo spazio disco rimanente interattivo.
    - Spazio libero inferiore ai 50GB: Testo spazio libero di colore rosso.
    - Spazio libero tra 50GB e 80GB: Testo spazio libero di colore giallo.
    - Spazio libero oltre 80GB: Testo spazio libero di colore verde.
    - Fix coerenza grafica pagina principale script.
- Funzione **Disable Bitlocker** Aggiunta.
  - Esegue il tool ufficiale Microsoft per disattivare completamente Bitlocker dal PC, che viene occultamente attivato tramite update da Microsoft senza avvisare in modo consono l'utente.
  - Viene aggiunta una chiave al registro di Windows registro che dovrebbe impedire possibili attivazioni occulte future.
- Funzione **Gaming Toolkit** Potenziata.
  - Aggiunta l'installazione del nuovo .Net Framework 10, già richiesto da alcune app per funzionare correttamente.

### Correzioni

- Script **start.ps1** aggiornato e potenziato.
  - Gestione Processi: Introdotta nuova funzione helper Stop-InterferingProcesses per terminare forzatamente processi conflittuali (es. WinStore.App, wsappx, AppInstaller) prima delle operazioni critiche.
  - Logging & Error Handling: Aggiunto blocco try/catch sulla gestione del Transcript (log) e sul comando Restart-Computer per prevenire crash in fase di chiusura/riavvio.
  - Timeout & Wait: Ottimizzati i timeout di attesa e incrementato il tempo di check per la generazione del file settings.json di Windows Terminal (da 10s a 20s).
  - Gestione Winget (Refactoring Completo).
    - La funzione Install-WingetSilent è stata completamente riscritta per una maggiore robustezza.
    - Deep Cleaning: Implementata pulizia aggressiva della cache: terminazione processi Winget, rimozione ricorsiva cartella %TEMP%\WinGet e reset delle sorgenti (source reset --force).
    - Dipendenze: Aggiunta installazione automatica del NuGet PackageProvider e del modulo PowerShell Microsoft.WinGet.Client
    - Strategia di Riparazione Potenziata.
    - Riparazione tramite modulo Repair-WinGetPackageManager.
    - Fallback su installazione MSIXBundle (con soppressione errori).
    - Reset esplicito del pacchetto Appx Microsoft.DesktopAppInstaller.
  - Installazione Pacchetti (Git & PowerShell 7).
    - Risoluzione Dinamica URL: Rimossi i link statici per il download. L'URL di download per Git e PowerShell 7 viene ora risolto dinamicamente interrogando le GitHub API (releases/latest o tag specifici).
    - Logica di Installazione PS7, Invertita la priorità: ora tenta prima il download/installazione diretta (MSI) e usa Winget solo come fallback.
    - Sostituito Start-Job con Start-Process -PassThru + Wait-Process per una gestione più affidabile del processo di installazione MSI.
    - Parsing JSON: Migliorata la robustezza del parsing di settings.json per Windows Terminal con gestione specifica degli errori di lettura.
- Funzione **WinRepairToolkit** riscritta.
  - Refactor Codice per uniformarlo al resto della codebase.
  - Migliorata scrittura file Log.
  - Migliorato processo di riparazione di Windows.
  - Aggiunta nuova funzione che evita la richiesta dopo tot tempo di cambio password dell'utente corrente.
- Funzione **DisableBitlocker** completa.
  - Refactor Codice per uniformarlo al resto della codebase.
  - Migliorata scrittura file Log.
- Funzione **WinInstallPsProfile** Aggiornata e Potenziata.

  - Refactor Codice per uniformarlo al resto della codebase.
  - Fix Sovrapposizione Testo Winget alle barre di progressione. **([#23](https://github.com/Magnetarman/WinToolkit/issues/23)) [@pomodori92]**
  - Migliorata scrittura file Log.
  - Aumentata verbosità script per migliorare la comprensione delle operazioni generate.
  - Fix Errore installazione oh-my-posh e zoxide. **([#22](https://github.com/Magnetarman/WinToolkit/issues/22)) [@pomodori92]**
  - Fix installazione Powershell 7 e Git.
  - Aggiunto secondo tentativo di configurazione di Windows Terminal che spesso fallisce a causa di un problema di lettura del file settings.json nello script `start.ps1`

- Funzione **WinReinstallStore** Riscritta e migliorata.
  - Refactor Codice per uniformarlo al resto della codebase.
  - Migliorata scrittura file Log.
  - Potenziato lo script di reinstallazione di Winget. Lo script è più aggressivo e completo rendendo winget nuovamente funzionante anche su versioni di Windows 11 più vecchie di 24H2.
- Funzione **WinUpdateReset** Riscritta.
  - Refactor Codice per uniformarlo al resto della codebase.
  - Migliorata scrittura file Log.
  - Eliminazione dei commenti non necessari.
  - Fix eliminazione non voluta account non admin. [Thanks to @Zakkos]
  - Inserita messaggi di avvertimento e funzionalità per eseguire comunque l'operazione rischiosa in caso di un ripristino non completo. [Thanks to @Zakkos]
- Funzione **WinBackupDriver** Riscritta.
  - Refactor Codice per uniformarlo al resto della codebase.
  - Migliorata scrittura file Log.
  - Eliminazione dei commenti non necessari.
- Funzione **GamingToolkit** Riscritta.
  - Refactor Codice per uniformarlo al resto della codebase.
  - Migliorata scrittura file Log.
  - Eliminazione dei commenti non necessari.
- Funzione **SetRustDesk** Riscritta.
  - Refactor Codice per uniformarlo al resto della codebase.
  - Migliorata scrittura file Log.
  - Eliminazione dei commenti non necessari.
- Funzione **VideoDriverInstall** Riscritta.
  - Refactor Codice per uniformarlo al resto della codebase.
  - Migliorata scrittura file Log.
  - Eliminazione dei commenti non necessari.
- Funzione **WinCleaner** Riscritta e potenziata.
  - Refactor Codice per uniformarlo al resto della codebase.
  - Migliorata scrittura file Log.
  - Eliminazione dei commenti non necessari.
  - Eliminazione pulizia database Windows Defender.
  - Fix errore cancellazione cartella History delle scansioni di Defender.
  - Unificate funzioni di pulizia.
  - Riorganizzato il codice per migliorare la leggibilità e la manutenibilità.
  - Riduzione di oltre 1000 linee di codice, mantenendo tutte le funzionalità.
  - Potenziate funzioni di pulizia. [Thanks To @Privacy.sexy Project]
  - Fix parsing chiavi di registro in modo errato in alcune sezioni dello script. **([#24](https://github.com/Magnetarman/WinToolkit/issues/24)) [@pomodori92]**

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.
- Script `WinToolkit` riscritto.
  - Logica completamente riscritta, lo script adesso risulterà monolitico, integrando le funzionalità grafiche generali, demandando ai singoli script la sola gestione logica e funzionale delle varie operazioni.
  - Questo aggiornamento porta con sè un notevole miglioramento delle prestazioni, una significativa riduzione del codice totale (da +7500 linee a 4300 linee di codice totale, un'ottimizzazione del 42%) e maggiore stabilità dello script, oltre a una maggiore leggibilità e manutenibilità del codice.
  - Modificato l'aspetto grafico del Toolkit rendendo le varie schermate più compatte e leggibili. **([#21](https://github.com/Magnetarman/WinToolkit/issues/21)) [@pomodori92]**

---

## [2.4.1] - 2025-11-13 (#20)

### Aggiunte

- Funzione **Office Toolkit** Potenziata.
  - Disattivazione della telemetria generale.
  - Disattivazione invio crash report.

### Correzioni

- Fix Funzione **Gaming Toolkit**.
  - Potenziamento della funzione di pulizia all'avvio. il Lauche Gog Galaxy nonostante la pulizia continuava ad essere inserito nelle app di avvio. Con il fix aggiunto questa problematica viene risolta.
- Fix Funzione **Reinstall Store**.
  - Eliminazione dalle app all'avvio del sistema di Uniget UI.

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.
- Aggiunta sezione Supporto Progetto.
- Riorganizzazione e semplificazione sezioni del file `README.md`.
- Fix bug avvio modalità provvisioria in `VideoDriverInstall.ps1`.
  - A causa di un Bug di un cumulativo di Windows 24H2 e 25H2 la modalità di avvio avanzata ingnora gli input di tastiera e mouse. Per questo motivo è stata scelta una via alternativa (Legacy con il richiamo di MSConfig) per il riavvio diretto in Modalità Provvisoria.

---

## [2.4.0] (Pixel Debh Part II) - 2025-10-26 (#19)

### Aggiunte

- Funzione **Gaming Toolkit** Completa.
  - Attivazione .Net Framework (3, 4 e 4.8)
  - Installazione Tramite Winget dei Net Framework (5, 6, 7, 8, 9)
  - Installazione/Aggiornamento di Microsoft C++ Package.
  - Installazione/Aggiornamento di Directx.
  - Installazione client di gioco (Amazon Games, Gog Galaxy, Epic Games, Steam).
  - Installazione di Playnite.
- Aggiunto ScreenShot del Gaming Toolkit al `Readme.md`.

### Correzioni

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.
- **Aggiunto Messaggio di Avviso per l'utilizzo del Gaming Toolkit**. A causa dell'installazione non completa di Winget nei sistemi precedenti a Windows 11 23H2 lo script consiglierà di effettuare la funzione riparazione Winget e poi procedere in modo da avere funzionalità Massime. Per Windows 11 superiori a 23H2 lo script verrà eseguito normalmente.

---

## [2.3.0] (Pixel Debh Part I) - 2025-10-18 (#18)

### Aggiunte

- Funzione **Video Driver Install** Completa.

### Correzioni

- Fix duplicazione in `CONTRIBUTORS.md`.
- Fix Errore date in `CHANGELOG.md`.
- Fix Pulizia troppo aggressiva di `Wincleaner.ps1` (Rompeva il funzionamento di .Net Framework).

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.
- Potenziamento script `WinCleaner.ps1` con cacellazione della cartella Windows.old.

---

## [2.2.5] - 2025-10-16 (#17)

### Aggiunte

- Aggiunti nuovi Screenshot della V5.0 GUI (In Sviluppo)
- Aggiunto il supporto Emoji per la versione GUI

### Correzioni

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.

---

## [2.2.4] - 2025-10-11 (#16)

### Aggiunte

### Correzioni

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.
- Aumentata la compatilità dello script con versioni precedenti di windows.
- Migliorati i messaggi di avviso.

---

## [2.2.3] - 2025-10-04 (#15)

### Aggiunte

- Aggiunti Screeshot delle nuove Funzionalità.
- Potenziamento Avvisi compatibilità Windows. **[Thanks to @pomodori92]**
- Aggiunto Avviso di Compatibilità nello script `WinToolkit.ps1`.

### Correzioni

- Correzione Aspetto Screenshot nel `Readme.md`.
- Correzione del blocco grafico del terminale per lo script `SetRustDesk.ps1`.
- Correzione cancellazione accidentale cartella WinToolkit durante la pulizia di `Wincleaner.ps1`

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.
- Aggiornati tutti gli ScreenShot presenti nel `README.md`.
- Semplificate alcune sezioni del `README.md` per una maggiore comprensione.
- Aggiornamento `CONTRIBUTORS.md`.

---

## [2.2.2] - 2025-10-04 (#14)

### Aggiunte

- Aggiunta Funzione `WinCleaner`.

### Correzioni

- Correzione del blocco grafico del terminale per lo script `WinReinstallStore.ps1`.
- Correzione del blocco grafico del terminale per lo script `WinBackupDriver.ps1`.
- Correzione di alcuni problemi di affidabilità (Windows 11 Pre 24H2) nello script `start.ps1`.
- Correzione di alcuni problemi di affidabilità (Windows 11 Pre 24H2) nella funzione `InstallPSProfile`.
- Correzione di alcuni problemi di affidabilità (Windows 11 Pre 24H2) nella funzione `OfficeToolkit`.
- Correzione del blocco grafico del terminale per lo script `OfficeToolkit.ps1`.
- Errore applicazione configurazione corretta script `SetRustdesk.ps1`.

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.
- Aggiornamento `CONTRIBUTORS.md`.
- Migliorato Supporto script `start.ps1` per Windows 10 22H2 e versioni precedenti. **[Thanks to @sicolla]**
- Migliorato Supporto script `start.ps1` per Windows 11 pre 24H2.
- Migliorate Sezioni `WinToolkit-Template.ps1`.
- Potenziamento Script `WinUpdateReset.ps1`.
- Eliminata la pulizia forzata del terminale in `WinReinstallStore.ps1`.
- Aggiornamento Tono e Stile generale degli script.

---

## [2.2.1] - 2025-09-28 (#13)

### Aggiunte

- Aggiunto `CONTRIBUTORS.md`

### Correzioni

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.

---

## [2.2] - 2025-09-24 (#12)

### Aggiunte

- Funzione **Windows Repair Plus** completata.
- Funzione **Set RustDesk** completata.
- Funzione **WinBackupDriver** completata.

### Correzioni

- Correzione del blocco grafico del terminale per lo script `Update Reset`.
- Correzione del blocco grafico del terminale per lo script `WinReinstallStore`.
- Fix di alcuni errori di battitura (`Typo`).
- Fix Spaziatura Testo Ascii nei vari tool.
- Fix Messaggio poco chiaro in `OfficeToolkit`

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.
- Aggiornamento dello script `start.ps1`.
- Aggiornamento dello script `WinToolkit-template.ps1`.
- Reinstallazione forzata di Microsoft Store & Winget.
- Installazione di Uniget.
- Set di Rust Desk (funzione espansa rispetto al progetto originale).
  - Controllo Versione
  - Installazione ultima versione di Rust Desk
  - Copia configurazione "MagnetarMan" Ready per supporto remoto
  - Riavvio del PC ed Applicazione delle modifiche
- Aggiornamento della documentazione con il nuovo screenshot per la funzione `WinReinstallStore`.
- Creazione file `CHANGELOG.md` con link nel `README.md` con il changelog esaustivo dei cambiamenti
- Ottimizzazione script `OfficeToolkit`
- Ottimizzazione script `WinToolkit-template`
- Ottimizzazione script `SetRustDesk`
- Ottimizzazione script `WinInstallaPsProfile`
- Ottimizzazione script `WinReinstallStore`
- Ottimizzazione script `WinRepairToolkit`
- Ottimizzazione script `WinUpdateReset`

---

## [2.1.1] - 2025-09-22 (#11)

### Aggiunte

- Funzione **`Selezione Multipla`** completa.
- `Github Actions` aggiunto sul canale Dev per la compilazione automatica di WinToolkit.
- Nuovi link attivati nel codice.

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.
- Ottimizzazione dello script `WinToolkit-Template.ps1`.
- Aggiornamento dello script `start.ps1`.

---

## [2.1] - 2025-09-22 (#10)

### Modifiche

- I link di reindirizzamento degli script sono stati cambiati da GitHub a **MagnetarMan.com**.
- Lo script `start.ps1` è stato aggiornato.

---

## [2.1] - 2025-09-19 (#9)

### Aggiunte

- Funzione **`Office Toolkit`** completata.

### Modifiche

- Il file `README.md` è stato aggiornato.
- La funzione **`Informazioni del Sistema`** è stata potenziata.

---

## [2.0.1] - 2025-09-18 (#8)

### Aggiunte

- Potenziamento dello script `WinToolkit.ps1` con le **`Informazioni del Sistema`**.

### Modifiche

- Ottimizzazione generale degli script.
- Aggiornamento dei file `WinReinstallStore.ps1`, `WinRepairToolkit.ps1` e `README.md`.

---

## [2.0.0] - 2025-09-10 (#7)

### Modifiche

- Rework grafico del file `WinToolkit.ps1`.

---

## [2.0.0] - 2025-09-06 (#6)

### Correzioni

- Correzione dello strumento Update Reset.

### Modifiche

- Potenziamento dello script Start Script.

---

## [2.0.0] - 2025-09-06 (#5)

### Modifiche

- Rework del file Readme.md.
- Rework grafico dello script.

---

## [2.0.0] - 2025-09-05 (#2)

- Funzione **`Update Reset`** completata.

---

## [2.0.0] - 2025-09-05 (#1)

### Aggiunte

- Funzione **`Repair Toolkit`** completata.

---

## [2.0.0] - 2025-09-02

- **Rilascio Pubblico**: Ristrutturazione completa del progetto per facilitare le future implementazioni.

---

## [1.1.0]

- Refactoring della struttura in forma modulare.

---

## [1.0]

- **Rilascio Privato** del progetto.
