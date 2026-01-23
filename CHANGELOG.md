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
- **Multi Lang Mode (ITA,Eng) (`V3.2` - Codename: "Enza"):**
- **Bugfix e Conversione per la GUI Mode (`V4.0`)**
- **GUI Mode (`V5.0`):**
  - Win toolkit con tutta la semplicità della GUI
  - Nessun comando da terminale da inserire

### Correzioni

### Modifiche

---

## [2.5.0] - CODENAME: "Deborah" - 2026-01-25 ([#25](https://github.com/MagnetarMan/WinToolkit/issues/25))

### Aggiunte

- **Sezione Informazioni di Sistema** potenziata.

  - Aggiunto il controllo (da Windows 11 25H2 Microsoft lo attiva a propria discrezione) per verificare l'attivazione o meno di BitLocker. In caso affermativo, è stato aggiunto un nuovo script nella sezione "Windows" per la disattivazione di BitLocker in caso di attivazione non desiderata. [[Thanks to @Valeriogalano]](https://github.com/Valeriogalano)
  - Reso interattivo il campo "Disco:" che indica lo spazio disco rimanente.
    - Spazio libero inferiore a 50 GB: testo spazio libero di colore rosso.
    - Spazio libero tra 50 GB e 80 GB: testo spazio libero di colore giallo.
    - Spazio libero superiore a 80 GB: testo spazio libero di colore verde.
    - Corretta la coerenza grafica della pagina principale dello script.
    - Aggiunto il riconoscimento delle nuove Build di Windows (25H2 e la Beta di 26H1).

- **Funzione Disable Bitlocker** aggiunta.

  - Esegue il tool ufficiale Microsoft per disattivare completamente BitLocker dal PC, che viene attivato in modo occulto tramite update da Microsoft senza avvisare adeguatamente l'utente.
  - Viene aggiunta una chiave al registro di Windows che dovrebbe impedire possibili attivazioni occulte future.

- **Funzione Gaming Toolkit** potenziata.

  - Aggiunta l'installazione del nuovo .NET Framework 10, già richiesto da alcune applicazioni per funzionare correttamente.

- Setup profilo PowerShell `WinPSP-Setup.ps1` (integrato nello script `start.ps1`)

  - Eliminazione di ogni riferimento al tool di Chris (implementate funzioni personalizzate + correzione di vari errori di installazione di Chris Titus Tech)
  - Integrazione di WinToolkit e Dev
  - Corretto il caricamento del profilo [[Chris Titus Tech PowerShell Profile #123](https://github.com/ChrisTitusTech/powershell-profile/issues/123)]
  - Riscrittura del profilo PowerShell per scaricare e utilizzare JetBrains Mono al posto di Cascadia Code, in linea con le impostazioni del terminale.
  - Eliminazione delle funzioni non utilizzate nel profile.ps1 e adattamento dello stesso.
  - Installazione di zoxide (verrà configurato al primo avvio del profilo PowerShell)
  - Installazione di fastfetch.
  - Installazione di btop.
  - Potenziamento del profilo con funzione help personalizzata.
  - Caricamento all'avvio del terminale di FastFetch, zoxide e oh-my-posh personalizzato.
  
- Aggiunta funzione di esportazione log.

- Funzione concatenazione script riscritta.

  - Migliorati i messaggi informativi in tutto il toolkit.
  - Adesso la funzione risulta centralizzata.
  - Lo script utilizza delle variabili per capire se sei in modalità avvio script singolo o concatenato.
  - Migliorata la gestione automatizzata dei vari scenari.

### Correzioni

- Script `start.ps1` aggiornato e potenziato [[Thanks to @Matteoz]](https://t.me/teo180).

  - **Gestione Processi:** introdotta nuova funzione helper `Stop-InterferingProcesses` per terminare forzatamente processi conflittuali (es. WinStore.App, wsappx, AppInstaller) prima delle operazioni critiche.
  - **Logging & Error Handling:** aggiunto blocco try/catch sulla gestione del Transcript (log) e sul comando `Restart-Computer` per prevenire crash in fase di chiusura/riavvio.
  - **Timeout & Wait:** ottimizzati i timeout di attesa e incrementato il tempo di controllo per la generazione del file settings.json di Windows Terminal (da 10s a 20s).
  - **Gestione Winget (Refactoring completo):**
    - La funzione `Install-WingetSilent` è stata completamente riscritta per una maggiore robustezza.
    - Inserito un ulteriore check per verificare la corretta installazione di Winget su sistemi obsoleti (Windows 10/11 < 22H2), con successiva installazione forzata di Winget, per avere pieno supporto anche su queste versioni di Windows [[Thanks to @Sicolla]](https://t.me/sicolla).
    - Reinstallazione forzata di Winget. [[Thanks to @asheroto]](https://github.com/asheroto)
    - **Deep Cleaning:** implementata pulizia aggressiva della cache: terminazione processi Winget, rimozione ricorsiva della cartella %TEMP%\WinGet e reset delle sorgenti (`source reset --force`).
    - **Dipendenze:** aggiunta installazione automatica del NuGet PackageProvider e del modulo PowerShell Microsoft.WinGet.Client
    - **Strategia di riparazione potenziata:**
      - Riparazione tramite modulo `Repair-WinGetPackageManager`.
      - Fallback su installazione MSIXBundle (con soppressione errori).
      - Reset esplicito del pacchetto Appx Microsoft.DesktopAppInstaller.
  - **Installazione pacchetti (Git & PowerShell 7):**
    - **Risoluzione dinamica URL:** rimossi i link statici per il download. L'URL di download per Git e PowerShell 7 viene ora risolto dinamicamente interrogando le GitHub API (releases/latest o tag specifici).
    - **Logica di installazione PS7:** invertita la priorità, ora tenta prima il download/installazione diretta (MSI) e usa Winget solo come fallback.
    - Sostituito `Start-Job` con `Start-Process -PassThru + Wait-Process` per una gestione più affidabile del processo di installazione MSI.
    - **Parsing JSON:** migliorata la robustezza del parsing di settings.json per Windows Terminal con gestione specifica degli errori di lettura.
    - **Architettura Centralizzata:** introdotto l'oggetto `$script:AppConfig` per la gestione unificata di URL API, percorsi di installazione e versioning, eliminando variabili sparse e migliorando la manutenibilità.
    - **Auto-Relaunch in PowerShell 7:** implementata logica di rilevamento automatico del motore PS7; lo script è ora in grado di riavviarsi autonomamente nella nuova sessione (se presente o appena installata) per garantire compatibilità con i moduli moderni.
    - **Gestione Ambiente "PowerShell Pro" (PSP):**
      - Introdotta automazione completa per il setup di strumenti CLI avanzati: `Oh-My-Posh`, `zoxide`, `btop` e `fastfetch`.
      - <del>Gestione Nerd Fonts: implementata procedura di download, scompattazione e installazione a livello di sistema dei font (JetBrainsMono) tramite `Shell COM Objects`.<del>
      - Installazione NerdFonts tramite Winget, velocizzando di molto il processo dello script `start.ps1`.
      - Automazione Profilo: configurazione automatica del file `Microsoft.PowerShell_profile.ps1` con integrazione temi e plugin.
    - **Windows Terminal & UI:**
      - Introdotta la sincronizzazione cloud del file `settings.json` per garantire una configurazione visuale coerente.
      - Ottimizzata la creazione della scorciatoia sul Desktop: ora punta direttamente a wt.exe forzando l'elevazione dei privilegi e il profilo PS7.

- **Funzione WinRepairToolkit** riscritta.

  - Refactor del codice per uniformarlo al resto della codebase.
  - Migliorata la scrittura del file Log.
  - Migliorato il processo di riparazione di Windows.
  - Aggiunta nuova funzione che evita la richiesta di cambio password dell'utente corrente dopo un certo periodo di tempo.
  - Aggiunto riempimento progressivo a chkdsk: ora tutti i comandi (inclusi chkdsk) simulano il progresso incrementando la percentuale da 0% a 95% con incrementi casuali di 1-3%. chkdsk mantiene il colore giallo per distinguerlo. [[@pomodori92]](https://github.com/pomodori92)
  - Rallentato "Ripristino immagine Windows" di 1.5x: il ritardo tra gli aggiornamenti della barra di progresso per questo comando è stato aumentato da 600 ms a 900 ms, rendendo il riempimento più lento. [[@pomodori92]](https://github.com/pomodori92)
  - Script potenziato. Integrate 3 nuove funzioni con attivazione condizionale per risolvere e stabilizzare Winget e XAML. [[Articolo problematica KB5062553](https://www.borncity.com/blog/2025/11/21/windows-11-24h2-microsoft-bestaetigt-broken-by-design-durch-update-kb5062553/)]

- **Funzione DisableBitlocker** completata.

  - Refactor del codice per uniformarlo al resto della codebase.
  - Migliorata la scrittura del file Log.

- **Funzione WinInstallPsProfile** aggiornata e potenziata.

  - Migliorata la scrittura del file Log.
  - Refactor del codice per uniformarlo al resto della codebase.
  - Corretta sovrapposizione del testo Winget alle barre di progresso. [[#23](https://github.com/MagnetarMan/WinToolkit/issues/23) [@pomodori92]](https://github.com/pomodori92)
  - Aumentata la verbosità dello script per migliorare la comprensione delle operazioni eseguite.
  - Corretto errore di installazione di oh-my-posh e zoxide. [[#22](https://github.com/MagnetarMan/WinToolkit/issues/22) [@pomodori92]](https://github.com/pomodori92)
  - Corretta l'installazione di PowerShell 7 e Git.
  - Aggiunto secondo tentativo di configurazione di Windows Terminal che spesso fallisce a causa di un problema di lettura del file settings.json nello script `start.ps1`

- **Funzione WinReinstallStore** riscritta e migliorata.

  - Refactor del codice per uniformarlo al resto della codebase.
  - Migliorata la scrittura del file Log.
  - Potenziato lo script di reinstallazione di Winget. Lo script è più aggressivo e completo, rendendo Winget nuovamente funzionante anche su versioni di Windows 11 precedenti alla 24H2.

- **Funzione WinUpdateReset** riscritta.

  - Refactor del codice per uniformarlo al resto della codebase.
  - Migliorata la scrittura del file Log.
  - Eliminazione dei commenti non necessari.
  - Corretta eliminazione non desiderata di account non admin. [[Thanks to @Zakkos]](http://youtube.com/@zakkos)
  - Inseriti messaggi di avvertimento e funzionalità per eseguire comunque l'operazione rischiosa in caso di un ripristino non completo. [[Thanks to @Zakkos]](http://youtube.com/@zakkos)
  - Corretti messaggi di output PowerShell non soppressi correttamente.
  - Corretto spazio eccessivo tra i messaggi.

- **Funzione WinBackupDriver** riscritta.

  - Refactor del codice per uniformarlo al resto della codebase.
  - Migliorata la scrittura del file Log.
  - Eliminazione dei commenti non necessari.
  - Risolto un problema che poteva causare il fallimento della creazione dell'archivio .zip in alcune circostanze.
  - Sostituita la compressione con 7zip (molto più veloce della compressione nativa di Windows).

- **Funzione GamingToolkit** riscritta.

  - Refactor del codice per uniformarlo al resto della codebase.
  - Migliorata la scrittura del file Log.
  - Eliminazione dei commenti non necessari.

- **Funzione SetRustDesk** riscritta.

  - Refactor del codice per uniformarlo al resto della codebase.
  - Migliorata la scrittura del file Log.
  - Eliminazione dei commenti non necessari.

- **Funzione VideoDriverInstall** riscritta.

  - Refactor del codice per uniformarlo al resto della codebase.
  - Migliorata la scrittura del file Log.
  - Eliminazione dei commenti non necessari.
  - Risolto un bug che causava errori di visualizzazione nelle barre di progresso.
  - Uniformati spinner e grafica.
  - Velocizzato il download di DDU.

- **Funzione WinCleaner** riscritta e potenziata.
  - Refactor del codice per uniformarlo al resto della codebase.
  - Migliorata la scrittura del file Log.
  - Eliminazione dei commenti non necessari.
  - Eliminazione pulizia database Windows Defender.
  - Corretto errore di cancellazione della cartella History delle scansioni di Defender.
  - Unificate funzioni di pulizia.
  - Riorganizzato il codice per migliorare la leggibilità e la manutenibilità.
  - Riduzione di oltre 1000 linee di codice, mantenendo tutte le funzionalità.
  - Potenziate funzioni di pulizia. [[Thanks to @Privacy.sexy Project]](https://privacy.sexy/)
  - Corretto il parsing delle chiavi di registro in modo errato in alcune sezioni dello script. [[#24](https://github.com/MagnetarMan/WinToolkit/issues/24) [@pomodori92]](https://github.com/pomodori92)
  - Uniformati spinner e grafica.
  - Aggiunto un blocco delle operazioni durante la "Pulizia Disco" in modo da evitare comportamenti anomali.
  - Uniformazione funzione `Write-StyledMessage`.
  - Eliminata la Funzione Pulizia della taskbar `Quick Access`.
  - Refactor sezione rimozione Shadow Copies.
    - Adesso la funzione di pulizia non disattiva le Shadow Copies di windows.
    - Lo script per recuperare spazio su disco elimina tutti i punti di ripristino presenti tranne l'ultimo in ordine temporale, in modo da avere sempre un punto di ripristino funzionante.
  - Refactor sezione Pulizia `Cache & Logs`.
    - Eliminato pulizia aggressiva di Firefox.
    - Aggiunta pulizia di solo cache e logs dei principali browser utilizzati:
      - Google Chrome
      - Microsoft Edge (Versione Chromium)
      - Edge Legacy (HTML)
      - Brave Browser
      - Vivaldi
      - Firefox
    - Risolto un conflitto di variabili tra lo script principale e `WinCleaner.ps1` che causava report di riepilogo vuoti, in caso di concatenazione script attiva.

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.

- Script `WinToolkit.ps1` riscritto.
  - Logica completamente riscritta, lo script adesso risulta monolitico, integrando le funzionalità grafiche generali, demandando ai singoli script la sola gestione logica e funzionale delle varie operazioni.
  - Questo aggiornamento porta con sé un notevole miglioramento delle prestazioni, una significativa riduzione del codice totale (da oltre 7500 linee a 4300 linee di codice totale, un'ottimizzazione del 42%) e maggiore stabilità dello script, oltre a una maggiore leggibilità e manutenibilità del codice.
  - Modificato l'aspetto grafico del Toolkit, rendendo le varie schermate più compatte e leggibili. [[#21](https://github.com/MagnetarMan/WinToolkit/issues/21) [@pomodori92]](https://github.com/pomodori92)
  - Aggiornato DDU alla versione v18.1.4.0.
  - Funzione grafica Spinner resa globale e ottimizzata nei vari script.
  - Fix errore di visualizzazione percentuale nella barra del countdown.
  - Aggiunta nuova logica di Splatting per Start-Process in tutti gli script per migliorare la leggibilità del codice e la facile espansione futura.
  - Variabili Download, Path, Link ecc. centralizzate.
  - Rese maggiormente descrittive le variabili nei diversi script.

- Revamping `PowerShell Profile.ps1`
  - **Pulizia e rimozione codice inutile:**
    - Rimozione di tutte le funzioni di debug non più necessarie
    - Eliminazione dell'architettura _Override-First_
    - Rimozione del meccanismo di aggiornamento automatico del profilo (`Update-Profile` con confronto SHA256)
    - Eliminazione delle mappature dei comandi Unix-like su PowerShell:
      - `grep`
      - `sed`
      - `which`
      - `export`
      - `pkill`
      - `head`
      - `tail`
    - Rimozione della gestione personalizzata del cestino (COM `Shell.Application`)
    - Eliminazione delle funzioni `uptime` e `hb`
    - Rimozione del codice per syntax highlighting
    - Rimozione del completamento nativo
    - Eliminazione di utility e shortcut non più utilizzate:
      - `sed`
      - `grep`
      - `which`
      - `export`
      - `nf`
      - `docs`
      - `k9`
      - `la`
      - `ll`
      - `cpy`
      - `pst`
      - Git shortcuts
      - Help Function
  - **Configurazione Oh My Posh:**
    - Impostazione del tema `atomic.omp.json` al posto di `cobalt2.omp.json`
    - Download del tema da GitHub se non presente localmente
    - Utilizzo dell'URL remoto come fallback in caso di errore nel download
  - **Gestione editor:**
    - Aggiornamento della _Editor Hierarchy_ mantenendo solo: `zed → code → notepad`
    - Rimozione di tutti gli altri editor
    - Nella sezione _Editor Configuration_ mantenere solo:
      - Visual Studio Code (`code`)
      - Zed (`zed`)
  - **WinToolkit:**
    - Rinomina di **Open WinUtil full-release** in **WinToolkit-Stable**
    - Aggiornamento del link a `https://magnetarman.com/WinToolkit`
    - Rinomina di **Open WinUtil dev-release** in **WinToolkit-Dev**
    - Aggiornamento link a `https://magnetarman.com/WinToolkit-Dev`
    - Aggiornata funzione di richiamo Toolkit e potenziamento per funzionamento Plug and Play.
  - **Varie:**
    - Traduzione di tutti i commenti del file in italiano.

- **Aggiornamento pipeline CI/CD**
  - Reso automatico il controllo dei nomi dei singoli script presenti nella cartella /tool prima dell'esecuzione del `compiler.ps1`.
  - Bump automatico del Build script.
  - Add issue chiusi al changelog.
  - Migliorato il codice di `compiler.ps1` che ora controlla se ci sono righe vuote alla fine dello script e le elimina prima di effettuare il commit finale di aggiornamento.
  - Rimosso script `SetRustdesk.ps1` e relative configurazioni per non conformità al progetto generale. [[Thanks to @pomodori92]](https://github.com/pomodori92)

---

## [2.4.1] - 2025-11-13 ([#20](https://github.com/MagnetarMan/WinToolkit/issues/20))

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

## [2.4.0] (Pixel Debh Part II) - 2025-10-26 ([#19](https://github.com/MagnetarMan/WinToolkit/issues/19))

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

## [2.3.0] (Pixel Debh Part I) - 2025-10-18 ([#18](https://github.com/MagnetarMan/WinToolkit/issues/18))

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

## [2.2.5] - 2025-10-16 ([#17](https://github.com/MagnetarMan/WinToolkit/issues/17))

### Aggiunte

- Aggiunti nuovi Screenshot della V5.0 GUI (In Sviluppo)
- Aggiunto il supporto Emoji per la versione GUI

### Correzioni

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.

---

## [2.2.4] - 2025-10-11 ([#16](https://github.com/MagnetarMan/WinToolkit/issues/16))

### Aggiunte

### Correzioni

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.
- Aumentata la compatilità dello script con versioni precedenti di windows.
- Migliorati i messaggi di avviso.

---

## [2.2.3] - 2025-10-04 ([#15](https://github.com/MagnetarMan/WinToolkit/issues/15))

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

## [2.2.2] - 2025-10-04 ([#14](https://github.com/MagnetarMan/WinToolkit/issues/14))

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

## [2.2.1] - 2025-09-28 ([#13](https://github.com/MagnetarMan/WinToolkit/issues/13))

### Aggiunte

- Aggiunto `CONTRIBUTORS.md`

### Correzioni

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.

---

## [2.2] - 2025-09-24 ([#12](https://github.com/MagnetarMan/WinToolkit/issues/12))

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

## [2.1.1] - 2025-09-22 ([#11](https://github.com/MagnetarMan/WinToolkit/issues/11))

### Aggiunte

- Funzione **`Selezione Multipla`** completa.
- `Github Actions` aggiunto sul canale Dev per la compilazione automatica di WinToolkit.
- Nuovi link attivati nel codice.

### Modifiche

- Aggiornamento della documentazione e del file `README.md`.
- Ottimizzazione dello script `WinToolkit-Template.ps1`.
- Aggiornamento dello script `start.ps1`.

---

## [2.1] - 2025-09-22 ([#10](https://github.com/MagnetarMan/WinToolkit/issues/10))

### Modifiche

- I link di reindirizzamento degli script sono stati cambiati da GitHub a **MagnetarMan.com**.
- Lo script `start.ps1` è stato aggiornato.

---

## [2.1] - 2025-09-19 ([#9](https://github.com/MagnetarMan/WinToolkit/issues/9))

### Aggiunte

- Funzione **`Office Toolkit`** completata.

### Modifiche

- Il file `README.md` è stato aggiornato.
- La funzione **`Informazioni del Sistema`** è stata potenziata.

---

## [2.0.1] - 2025-09-18 ([#8](https://github.com/MagnetarMan/WinToolkit/issues/8))

### Aggiunte

- Potenziamento dello script `WinToolkit.ps1` con le **`Informazioni del Sistema`**.

### Modifiche

- Ottimizzazione generale degli script.
- Aggiornamento dei file `WinReinstallStore.ps1`, `WinRepairToolkit.ps1` e `README.md`.

---

## [2.0.0] - 2025-09-10 ([#7](https://github.com/MagnetarMan/WinToolkit/issues/7))

### Modifiche

- Rework grafico del file `WinToolkit.ps1`.

---

## [2.0.0] - 2025-09-06 ([#6](https://github.com/MagnetarMan/WinToolkit/issues/6))

### Correzioni

- Correzione dello strumento Update Reset.

### Modifiche

- Potenziamento dello script Start Script.

---

## [2.0.0] - 2025-09-06 ([#5](https://github.com/MagnetarMan/WinToolkit/issues/5))

### Modifiche

- Rework del file Readme.md.
- Rework grafico dello script.

---

## [2.0.0] - 2025-09-05 ([#2](https://github.com/MagnetarMan/WinToolkit/issues/2))

- Funzione **`Update Reset`** completata.

---

## [2.0.0] - 2025-09-05 ([#1](https://github.com/MagnetarMan/WinToolkit/issues/1))

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
