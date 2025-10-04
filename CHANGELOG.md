# Changelog

Tutte le modifiche significative apportate a questo progetto saranno documentate in questo file.

Il formato si basa su [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) e questo progetto aderisce al [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## In lavorazione

Questo è lo stato attuale del progetto, che include le funzionalità in fase di sviluppo.

### Aggiunte

- **Potenziamento Avvisi compatibilità Windows (`V2.2.3`):**
  - Windows 11 (dalla versione 24H2 in poi): Tutto bene (Verde). Lo script funziona alla massima velocità ed efficienza perché usa le funzioni più recenti.
  - Windows 11 (prima della 24H2) o Windows 10: Attenzione, possibile rischio (Giallo). Il sistema non è completamente aggiornato, ma lo script farà del suo meglio per funzionare. Userà soluzioni alternative (workaround) e funzioni di riserva per garantire la massima compatibilità, anche se con un'efficienza leggermente inferiore.
  - Windows 10 (prima della 1809) o Windows 8.1: Sconsigliato, sistema troppo vecchio (Rosso). Lo script potrebbe avere gravi problemi di affidabilità. Chiedi con una richiesta specifica se proseguire oppure terminare lo script.
  - Qualsiasi Windows precedente a Windows 8.1: sistema troppo vecchio (Rosso). Scrivi un messaggio sul terminale "Davvero pensi che questo script possa fare qualcosa per questa versione di Windows ? E' già un miracolo che tu riesca a vedere questo messaggio di errore senza che il pc sia esploso 🤣. Aggiorna Windows o passa a linux" parte un countdown di 10 secondi ed il terminale si chiude. **[Tnks @pomodori92]**
- **Funzione Driver & Gaming (`V2.3`):**
  - Scelta Driver Video (AMD/NVIDIA).
  - Installazione Driver Ottimizzato (Nvidia).
  - Download ultima versione di DDU, con estrazione e posizionamento
    nella cartella Downloads, seguito da riavvio in modalità
    provvisoria.
- **Funzione Gaming Ready (`V2.4`):**
  - Installazione client di gioco (Amazon, Gog Galaxy, Epic Games,
    Steam).
  - Installazione di Playnite e applicazione di un tema
    personalizzato.
  - Installazione/Aggiornamento di Directx.
  - Installazione/Aggiornamento di Microsoft C++ Package.
- **Funzione Auto Debloat (`V2.5`):**
  - Avvio dello script Chris con configurazione personalizzata
    (`iwr -useb https://christitus.com/win | iex`).
- **Funzione Security Update (`V2.6`):**
  - Download ed esecuzione di Tron Script con intervento minimo.
- **Funzione Security Update (`V2.7`):**
  - Reset dei servizi Windows **[Tnks @sicolla]**
  - Riparazione avanzata Windows Search **[Tnks @sicolla]**
  - Pulizia Cache dei Browser
  - Potenziamento Toolkit di Riparazione Windows **[Tnks @Progressfy]**
- **MagnetarMan Mode (`V3.0`):**
  - Avvio Script Chris con configurazione personalizzata.
  - Installazione programmi: Brave Browser, Google Chrome,
    Betterbird, Fan Control, PowerToys, Uniget, Crystal Disk Info,
    HwInfo, Rust Desk, Client Giochi (Amazon, Gog Galaxy, Epic
    Games, Steam).
  - Installazione .NET Runtime (dalla 4.8 alla 9.0).
  - Installazione Microsoft C++ Package.
  - Installazione/Aggiornamento Directx.
  - Installazione Playnite (Lancher/Aggregatore).
  - Installazione Revo Uninstaller.
  - Installazione Tree Size.
  - Installazione Glary Utilities.
  - Pulizia del sistema.
  - Applicazione Sfondo "MagnetarMan".
  - Riavvio del PC per completare le modifiche.

### Correzioni

### Modifiche

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
- Migliorato Supporto script `start.ps1` per Windows 10 22H2 e versioni precedenti. **[Tnks @sicolla]**
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
