# Guida ai Pull Request e Contributi per WinToolkit

> **Documento Ufficiale per i Contributori**  
> Repository: [MagnetarMan/WinToolkit](https://github.com/MagnetarMan/WinToolkit)  
> Ultimo aggiornamento: 2026-03-05

---

## Philosophy di Progetto

### Regola Fondamentale: 1 Issue = 1 Singolo Problema/Bug

Ogni segnalazione o richiesta di feature deve concentrarsi su un **singolo problema**. Non mescolare richieste diverse in un'unica issue per garantire:

- Tracciabilità precisa delle modifiche
- Revisioni più rapide e mirate
- Merge puliti e senza conflitti

---

## Workflow di Contribuzione

### Prerequisiti

Per contribuire al progetto WinToolkit, è necessario disporre di:

1. **Account GitHub** attivo
2. **Fork** della repository ufficiale: [MagnetarMan/WinToolkit](https://github.com/MagnetarMan/WinToolkit/fork)

### Regole di Branching

> **⚠️ IMPORTANTE: Regola Limitazione sul Branching**

- **Tutte le modifiche DEVONO essere effettuate sul branch `DEV`**
- Le Pull Request verso il branch `main` verranno **chiuse immediatamente** senza preavviso
- Il branch `DEV` è l'unico branch accettato per contributi esterni

---

## Logica di Sviluppo

### Struttura dei File

WinToolkit utilizza una struttura modulare ben definita:

| Tipo di Modifica              | Percorso File             | Descrizione                               |
| ----------------------------- | ------------------------- | ----------------------------------------- |
| **Funzioni/Script**           | `/tool/*.ps1`             | Moduli individuali del toolkit            |
| **Variabili/Aspetti Globali** | `WinToolkit-template.ps1` | Template principale con variabili globali |

### ⚠️ DIVIETO ASSOLUTO: Non Modificare Mai `WinToolkit.ps1`

> **WARNING: File Generato Automaticamente**
>
> Il file `WinToolkit.ps1` **NON deve mai essere modificato manualmente**. Questo file è il risultato di una **pipeline automatizzata** GitHub Actions che:
>
> 1. Unisce tutti gli script dalla cartella `/tool` nel template
> 2. Esegue il **Build Bump** (incremento versione)
> 3. Esegue i **test CI/CD**
> 4. Genera la **release automatica**
>
> Qualsiasi modifica diretta a `WinToolkit.ps1` verrà sovrascritta automaticamente e sarà **respinta** durante il processo di merge.

### Flusso di Lavoro Corretto

```
/tool/                   → Modificare gli script individuali
WinToolkit-template.ps1  → Modificare variabili globali
WinToolkit.ps1           → NON TOCCARE MAI (generato automaticamente)
```

---

## Struttura del Progetto

### Panoramica

WinToolkit è organizzato in una struttura modulare che facilita lo sviluppo, la manutenzione e la distribuzione. Di seguito viene descritta l'organizzazione completa delle cartelle e dei file.

### Albero Completo

```
WinToolkit/
├── .github/                              # Configurazione GitHub (CI/CD, Actions, Scripts)
│   ├── Docs/                             # Documentazione del progetto
│   ├── linters/                          # Configurazione linter PowerShell
│   ├── scripts/                          # Script di automazione build e test
│   └── workflows/                        # Pipeline CI/CD GitHub Actions
│
├── asset/                                # Risorse statiche e strumenti esterni
│   ├── png/                              # Icone e immagini UI (formato emoji Unicode)
│   ├── 7zr.exe                           # Estrazione archivi 7-Zip (Versione CLI)
│   ├── AMD-Autodetect.exe                # Tool rilevamento automatico driver AMD
│   ├── Basic.xml                         # File Configurazione installazione Office
│   ├── DDU.zip                           # Display Driver Uninstaller
│   ├── dxwebsetup.exe                    # DirectX Web Setup
│   ├── Microsoft.PowerShell_profile.ps1  # Profilo PowerShell personalizzato
│   ├── NVCleanstall_1.19.0.exe           # NVIDIA Driver Cleaner
│   ├── OOSU10.exe                        # O&O ShutUp10 (Debloat di Windows)
│   ├── Setup.exe                         # Programma setup di Office 365
│   ├── speedtest.exe                     # Tool test velocità rete
│   └── settings.json                     # Configurazioni Windows Terminal
│
├── Docs/                                 # Documentazione tecnica
│   └── Windows Updates and the Shared Servicing Model V1.2.pdf
│
├── img/                                  # Immagini e risorse grafiche
│   ├── avatar/                           # Avatar sezione readme "Parlano di Wintoolkit"
│   ├── Gui.jpg                           # Screenshot WinToolkit GUI Version
│   ├── RepairToolkit-old.jpg             # Screenshot WinToolkit versione vecchia UI
│   ├── Run-old.jpg                       # Screenshot Sezione "Dove tutto è iniziato (ver. 1.0)"
│   ├── Run.jpg                           # Screenshot Principale nel Readme.md
│   ├── WinToolkit-icon.png               # Favicon del Readme.md
│   └── WinToolkit.ico                    # Icona Wintoolkit utilizzata durante la creazione del collegamento in start.ps1
│
├── tool/                                 # Moduli funzionali del toolkit
│   ├── DisableBitlocker.ps1              # Disabilitazione BitLocker
│   ├── GamingToolkit.ps1                 # Ottimizzazioni gaming
│   ├── OfficeToolkit.ps1                 # Gestione Microsoft Office
│   ├── VideoDriverInstall.ps1            # Installazione driver video
│   ├── WinBackupDriver.ps1               # Backup driver
│   ├── WinCleaner.ps1                    # Pulizia sistema
│   ├── WinDebloat.ps1                    # Rimozione bloatware
│   ├── WinExportLog.ps1                  # Esportazione log
│   ├── WinReinstallStore.ps1             # Reinstallazione Microsoft Store & Winget
│   ├── WinRepairToolkit.ps1              # Riparazione sistema
│   └── WinUpdateReset.ps1                # Reset Windows Update
│
├── .gitignore                            # File ignorati da Git
├── CHANGELOG.md                          # Storico modifiche
├── compiler.ps1                          # Script compilatore/builder
├── LICENSE                               # Licenza MIT
├── README.md                             # Documentazione principale
├── start-offline.ps1                     # Avvio modalità offline
├── start.ps1                             # Script di avvio principale
├── TODO.md                               # Task e sviluppi futuri
├── WinToolkit_GUI.ps1                    # Versione WinToolkit GUI
├── WinToolkit-template.ps1               # Template con variabili globali
└── WinToolkit.ps1                        # File compilato (NON MODIFICARE)
```

### Descrizione Dettagliata dei Componenti

#### Cartella `/tool/` - Moduli Funzionali

> **NOTA: Area Principale di Sviluppo**
>
> La cartella `/tool/` contiene tutti i moduli funzionali del toolkit. Ogni file PowerShell rappresenta una funzionalità specifica che non può essere sviluppata e testata indipendentemente.

| File                     | Descrizione                                   |
| ------------------------ | --------------------------------------------- |
| `DisableBitlocker.ps1`   | Gestione e disabilitazione BitLocker          |
| `GamingToolkit.ps1`      | Ottimizzazioni specifiche per il gaming       |
| `OfficeToolkit.ps1`      | Strumenti per la gestione di Microsoft Office |
| `VideoDriverInstall.ps1` | Installazione driver video avanzata           |
| `WinBackupDriver.ps1`    | Backup dei driver di sistema                  |
| `WinCleaner.ps1`         | Pulizia file temporanei e cache               |
| `WinDebloat.ps1`         | Rimozione bloatware Windows                   |
| `WinExportLog.ps1`       | Esportazione log per debug                    |
| `WinReinstallStore.ps1`  | Reinstallazione Microsoft Store               |
| `WinRepairToolkit.ps1`   | Strumenti di riparazione sistema              |
| `WinUpdateReset.ps1`     | Reset Windows Update & Winget                 |

#### Cartella `/asset/` - Risorse Esterne

Contiene eseguibili e strumenti di terze parti utilizzati dal toolkit. Questi file vengono richiamati dai vari moduli in caso di necessita'.

#### Cartella `/.github/` - Infrastruttura CI/CD

- **workflows/**: Pipeline GitHub Actions per CI/CD
- **scripts/**: Script PowerShell per build e test
- **linters/**: Configurazione PSScriptAnalyzer
- **Docs/**: Documentazione progetto

#### File Radice

| File                      | Ruolo                                            |
| ------------------------- | ------------------------------------------------ |
| `WinToolkit-template.ps1` | Template con variabili globali (MODIFICABILE)    |
| `WinToolkit.ps1`          | File compilato finale (GENERATO AUTOMATICAMENTE) |
| `compiler.ps1`            | Script che assembla i moduli nel file finale     |
| `WinToolkit_GUI.ps1`      | Versione GUI                                     |

---

## Standard dei Commit

### Requisiti per i Messaggi di Commit

Ogni commit deve seguire questa struttura:

- **Descrizione in elenco puntato** delle modifiche effettuate.
- **Chiara e concisa**: massimo 72 caratteri per la prima riga.
- **In italiano** per mantenere coerenza con il progetto.

### Esempi di Commit Validi

```bash
# Esempi di commit corretti
- Aggiunta funzione di esportazione log in WinExportLog.ps1.
- Corretto bug sul parsing delle variabili d'ambiente.
- Implementato supporto per Windows 11 24H2.
- Ottimizzato algoritmo di pulizia in `WinCleaner.ps1`.
- Aggiornata documentazione delle variabili globali.
```

---

## Bug Reporting

### Procedura di Segnalazione Bug

> **NOTA: Informazioni Utili per la Risoluzione**
>
> In caso di bug fix, è **caldamente consigliato** allegare il file `.zip` dei log ottenuto tramite la funzione **"Export Log"** del toolkit. Questo accelera significativamente il processo di debug e risoluzione.

### Informazioni da Includere

Quando segnali un bug, includi:

1. **Descrizione chiara** del problema.
2. **Passaggi per riprodurre** il bug.
3. **Output atteso** vs **output effettivo**.
4. **File .zip dei log** (se applicabile).
5. **Versione del sistema operativo** Windows in uso.
6. **Versione di WinToolkit** utilizzata.

---

## Gestione Milestone

### Tipologie di Milestone

Il progetto utilizza due categorie principali per la gestione delle task:

| Milestone                | Descrizione                                                   | Tipologia      |
| ------------------------ | ------------------------------------------------------------- | -------------- |
| **Versione in sviluppo** | Quick fixes, correzioni urgenti, miglioramenti incrementali   | Priorità Alta  |
| **Backlog**              | Problemi complessi, nuove feature, discussioni architecturali | Bassa Priorità |

### Criteri di Assegnazione

- **Versione in sviluppo**: Bug critici, hotfix, piccole migliorie che possono essere implementate rapidamente.
- **Backlog**: Feature request complesse, refactoring significativi, discussioni che richiedono valutazione approfondita.

---

## Passi Rapidi per Contribuire

### Step 1: Fork della Repository

1. Accedi a [MagnetarMan/WinToolkit](https://github.com/MagnetarMan/WinToolkit)
2. Clicca sul pulsante **"Fork"** in alto a destra
3. Seleziona il tuo account GitHub come destinazione

### Step 2: Clona il Fork Locale

```bash
git clone https://github.com/TUO_USERNAME/WinToolkit.git
cd WinToolkit
```

### Step 3: Configura il Remote Upstream

```bash
git remote add upstream https://github.com/MagnetarMan/WinToolkit.git
```

### Step 4: Crea il Branch di Lavoro

```bash
git checkout DEV
git pull upstream DEV
git checkout -b fix/nome-del-fix
```

### Step 5: Effettua le Modifiche

> **NOTA: Ricorda la Logica di Sviluppo**
>
> - Modifica gli script in `/tool/*.ps1` per le funzionalità.
> - Modifica `WinToolkit-template.ps1` per le variabili globali.
> - **NON toccare mai `WinToolkit.ps1`**.

### Step 6: Committa le Modifiche

```bash
git add .
git commit -m "- Descrizione chiara della modifica
- Secondo punto se necessario"
```

### Step 7: Push e Pull Request

```bash
git push origin fix/nome-del-fix
```

1. Vai su GitHub nella **tua** repository forked.
2. Clicca su **"Compare & pull request"**.
3. Assicurati che il branch base sia **`DEV`** (non `main`!).
4. Compila il template della PR con tutti i dettagli richiesti.
5. Clicca **"Create pull request"**.

---

## Risorse Aggiuntive

- **Documentazione Ufficiale**: [README.md](./README.md).
- **Changelog**: [CHANGELOG.md](./CHANGELOG.md).
- **Issue Tracker**: [Issues](https://github.com/MagnetarMan/WinToolkit/issues).

---

> **Grazie per contribuire a WinToolkit!**
>
> Il tuo contributo è fondamentale per migliorare questo strumento per tutta la comunità.
