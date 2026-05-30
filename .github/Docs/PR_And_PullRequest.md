# Guida ai Pull Request e Contributi per WinToolkit

> **Documento Ufficiale per i Contributori**  
> Repository: [MagnetarMan/WinToolkit](https://github.com/MagnetarMan/WinToolkit)  
> Ultimo aggiornamento: 2026-05-22

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

> [!WARNING]
> **Regola Limitazione sul Branching**
>
> - Le modifiche possono essere effettuate su branch `Dev` o su branch dedicati (`feature/*`, `fix/*`, `feat/*`, `hotfix/*`)
> - Le Pull Request verso il branch `main` verranno **chiuse immediatamente** senza preavviso
> - Il branch `Dev` è l'unico branch accettato come target per le PR
> - I branch `feature/*`, `fix/*`, `feat/*`, `hotfix/*` attivano automaticamente la pipeline leggera CI

---

## Logica di Sviluppo

### Struttura dei File

WinToolkit utilizza una struttura modulare ben definita:

| Tipo di Modifica              | Percorso File             | Descrizione                               |
| ----------------------------- | ------------------------- | ----------------------------------------- |
| **Funzioni/Script**           | `/tool/*.ps1`             | Moduli individuali del toolkit            |
| **Variabili/Aspetti Globali** | `WinToolkit-template.ps1` | Template principale con variabili globali |

### ⚠️ DIVIETO ASSOLUTO: Non Modificare Mai `WinToolkit.ps1`

> [!WARNING]
> **File Generato Automaticamente**
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
│   │   ├── PR_And_PullRequest.md         # Guida alle PR (questo documento)
│   │   ├── ARCHITECTURE.md               # Architettura del sistema
│   │   └── SECURITY.md                   # Politiche di sicurezza
│   ├── ISSUE_TEMPLATE/                   # Template per le issue GitHub
│   ├── linters/                          # Configurazione linter PowerShell
│   ├── scripts/                          # Script di automazione build e test
│   ├── tests/                            # Test automatizzati progetto
│   │   ├── Unit/                         # Test unitari moduli
│   │   └── Integration/                  # Test di integrazione
│   ├── workflows/                        # Pipeline CI/CD GitHub Actions
│   ├── CODEOWNERS                        # Proprietari del codebase
│   ├── CODE_OF_CONDUCT.md                # Codice di condotta della community
│   ├── CONTRIBUTING.md                   # Linee guida per i contributi
│   ├── dependabot.yml                    # Configurazione Dependabot
│   ├── FUNDING.yml                       # Configurazione funding
│   └── pull_request_template.md          # Template per le Pull Request
│
├── asset/                                # Risorse statiche e strumenti esterni
│   ├── 7zr.exe                           # Estrazione archivi 7-Zip (CLI)
│   ├── AMD-Autodetect.exe                # Tool rilevamento driver AMD
│   ├── Basic.xml                         # Configurazione Office
│   ├── DDU.zip                           # Display Driver Uninstaller
│   ├── dxwebsetup.exe                    # DirectX Web Setup
│   ├── Microsoft.PowerShell_profile.ps1  # Profilo PowerShell personalizzato
│   ├── NVCleanstall_1.19.0.exe           # NVIDIA Driver Cleaner
│   ├── OOSU10.exe                        # O&O ShutUp10 (Debloat Windows)
│   ├── OOSU10.cfg                        # Configurazione O&O ShutUp10
│   ├── Setup.exe                         # Setup Office 365
│   └── speedtest.exe                     # Test velocità rete
│
├── Docs/                                 # Documentazione tecnica
│   └── Windows Updates and the Shared Servicing Model V1.2.pdf
│
├── img/                                  # Immagini e risorse grafiche
│   ├── avatar/                           # Avatar contributori
│   │   └── zakkos.jpg
│   ├── Gui.jpg                           # Screenshot GUI Version
│   ├── RepairToolkit-old.jpg           # Screenshot versione vecchia UI
│   ├── Run-old.jpg                       # Screenshot ver. 1.0
│   ├── Run.jpg                           # Screenshot principale Readme
│   ├── WinToolkit-Dev.ico                # Icona Dev
│   ├── WinToolkit-icon.png               # Favicon Readme
│   └── WinToolkit.ico                    # Icona WinToolkit
│
├── tool/                                 # Moduli funzionali del toolkit
│   ├── DisableBitlocker.ps1              # Gestione BitLocker
│   ├── GamingToolkit.ps1                 # Ottimizzazioni gaming
│   ├── Install-Office.ps1                # Installazione Microsoft Office
│   ├── Repair-Office.ps1                 # Riparazione Microsoft Office
│   ├── Uninstall-Office.ps1              # Disinstallazione Microsoft Office
│   ├── VideoDriverInstall.ps1            # Installazione driver video
│   ├── WinBackupDriver.ps1               # Backup driver di sistema
│   ├── WinCleaner.ps1                    # Pulizia file temporanei
│   ├── WinDebloat.ps1                    # Rimozione bloatware
│   ├── WinExportLog.ps1                  # Esportazione log diagnostici
│   ├── WinReinstallStore.ps1             # Reinstallazione Microsoft Store
│   ├── WinRepairToolkit.ps1              # Strumenti riparazione sistema
│   └── WinUpdateReset.ps1                # Reset Windows Update
│
├── version.json                          # Fonte unica di verità per versione
├── .gitignore                            # File ignorati da Git
├── CHANGELOG.md                          # Storico modifiche
├── compiler.ps1                          # Sistema di compilazione modulare
├── LICENSE                               # Licenza MIT
├── README.md                             # Documentazione principale
├── start-offline.ps1                     # Avvio modalità offline
├── start.ps1                             # Script di avvio principale
├── TODO.md                               # Task e sviluppi futuri
├── WinToolkit_GUI.ps1                    # Versione con interfaccia grafica WPF
├── WinToolkit-template.ps1               # Template base con funzioni core
└── WinToolkit.ps1                        # File compilato finale (NON MODIFICARE)
```

### Descrizione Dettagliata dei Componenti

#### Cartella `/tool/` - Moduli Funzionali

> [!Note]
> **NOTA: Area Principale di Sviluppo**
>
> La cartella `/tool/` contiene tutti i moduli funzionali del toolkit. Ogni file PowerShell rappresenta una funzionalità specifica **sviluppabile e testabile indipendentemente**.
>
> Il compilatore inietta automaticamente ogni modulo nel template principale durante la fase di build.

| File                     | Descrizione                                |
| ------------------------ | ------------------------------------------ |
| `DisableBitlocker.ps1`   | Gestione e disabilitazione BitLocker       |
| `GamingToolkit.ps1`      | Ottimizzazioni specifiche per il gaming    |
| `Install-Office.ps1`     | Installazione e configurazione Office      |
| `Repair-Office.ps1`      | Riparazione installazioni Office           |
| `Uninstall-Office.ps1`   | Disinstallazione e rimozione Office        |
| `VideoDriverInstall.ps1` | Installazione driver video avanzata        |
| `WinBackupDriver.ps1`    | Backup e ripristino driver di sistema      |
| `WinCleaner.ps1`         | Pulizia file temporanei e cache            |
| `WinDebloat.ps1`         | Rimozione bloatware Windows                |
| `WinExportLog.ps1`       | Esportazione log diagnostici per debug     |
| `WinReinstallStore.ps1`  | Reinstallazione Microsoft Store & WinGet   |
| `WinRepairToolkit.ps1`   | Strumenti di riparazione sistema (SFC/DISM)|
| `WinUpdateReset.ps1`     | Reset completo Windows Update              |

#### Cartella `/asset/` - Risorse Esterne

Contiene eseguibili e strumenti di terze parti utilizzati dal toolkit. Questi file vengono richiamati dai vari moduli in caso di necessità.

#### Cartella `/.github/` - Infrastruttura CI/CD

- **workflows/**: Pipeline GitHub Actions per CI/CD e distribuzione automatica
    - `CI_UpdateWinToolkit_Dev.yml`: Pipeline Enterprise adattiva (Dev completa, feature/fix leggera, PR gate di qualità)
    - `CI_UpdateWinToolkit_Main.yml`: Pipeline per verifica su branch main
    - `Create_Release.yml`: Workflow per creazione release e generazione note
    - `Release_Wintoolkit.yml`: Pipeline per creazione branch release e merge in main
    - `security.yml`, `stale.yml`: Workflow di manutenzione
- **scripts/**: Script PowerShell per build e test automatici
    - `Update-Version.ps1`: Gestione versione del progetto
    - `Invoke-Build.ps1`: Wrapper ufficiale del compilatore con statistiche compressione
    - `Test-CompiledScript.ps1`: Validazione post-compilazione (sintassi, funzioni, menu, dimensione, encoding)
    - `New-ReleaseNotes.ps1`: Generazione note di release
- **tests/**: Test automatizzati progetto
    - `WinToolkit.Tests.ps1`: Test suite Pester 5 per validazione moduli e funzionalità
    - **Unit/**: Test unitari per singoli moduli (VideoDriver, GamingToolkit, WinCleaner)
    - **Integration/**: Test di integrazione (Build.Tests.ps1)
- **linters/**: Configurazione PSScriptAnalyzer
- **Docs/**: Documentazione ufficiale progetto
- **ISSUE_TEMPLATE/**: Template per le issue GitHub
    - `bug_report.yml`: Template per segnalazione bug
    - `enhancement.yml`: Template per miglioramenti
    - `feature_request.yml`: Template per nuove funzionalità
- **CODE_OF_CONDUCT.md**: Codice di condotta della community
- **CONTRIBUTING.md**: Linee guida per i contributi
- **pull_request_template.md**: Template per le Pull Request
- **CODEOWNERS**: Proprietari del codebase

#### File Radice

| File                      | Ruolo                                                                  |
| ------------------------- | ---------------------------------------------------------------------- |
| `version.json`            | Fonte unica di verità per versione e build number                     |
| `WinToolkit-template.ps1` | Template base con funzioni core, logging e UI (MODIFICABILE)          |
| `WinToolkit.ps1`          | File compilato finale distribuito (GENERATO AUTOMATICAMENTE)          |
| `compiler.ps1`            | Sistema di compilazione ufficiale con tokenizer e minificazione sicura|
| `WinToolkit_GUI.ps1`      | Versione con interfaccia grafica WPF                                   |
| `start.ps1`               | Entry point ufficiale per distribuzione one-liner                       |
| `start-offline.ps1`       | Modalità di avvio senza connessione internet                           |
| `TODO.md`                 | Task e sviluppi futuri                                                 |

---

## 🧪 Test delle Versioni Compilate

Dopo aver effettuato delle modifiche, è obbligatorio testare la versione compilata di WinToolkit prima di aprire una Pull Request. Sono disponibili due modalità di test completamente autonome.

---

### 🟢 Modalità 1: Test Automatico tramite GitHub Workflows (Consigliato)

Questa modalità utilizza la stessa pipeline ufficiale di build direttamente nella tua fork, garantendo che il tuo codice funzioni esattamente come nel repository principale.

#### ✅ Prerequisiti

1. Fork del repository WinToolkit sul tuo account GitHub
2. Branch `Dev` presente e aggiornato nel tuo fork
3. Nessuna restrizione sulle GitHub Actions nella tua fork

#### 🔄 Trigger della Pipeline

La pipeline si attiva automaticamente su:

- **Push su Dev** → Pipeline completa: lint → test → build
- **Push su feature/fix/feat/hotfix/*** → Pipeline leggera: lint → test → build → commit
- **PR verso Dev** → Gate di qualità: lint → test (no build, no deploy)

I trigger sono limitati ai file:

- `tool/*.ps1`
- `WinToolkit-template.ps1`
- `compiler.ps1`
- `start-offline.ps1`
- `start.ps1`
- `.github/workflows/*.yml`
- `.github/tests/*.ps1`
- `.github/scripts/*.ps1`

#### 🛡️ PR Security Guard — Politica a Tre Livelli

Ogni PR verso Dev viene analizzata automaticamente da un sistema di sicurezza a tre livelli:

**Livello 1 — Consentiti (silenzioso)**

- File in `tool/*`
- `WinToolkit.ps1` (solo per maintainer)
- ✅ PR procede normalmente senza interventi

**Livello 2 — Consentiti con Warning (revisione manuale)**

- `start.ps1`, `WinToolkit_GUI.ps1`, `WinToolkit-template.ps1`, `asset/*`
- ⚠️ PR rimane aperta, viene aggiunto un commento di avviso per il maintainer

**Livello 3 — Protetti (blocco totale)**

- Tutti gli altri file (`.github/**`, `compiler.ps1`, ecc.)
- ⛔ PR chiusa automaticamente con commento di accesso negato

> [!WARNING]
> **Regola per i contributori esterni**: Puoi proporre modifiche **esclusivamente** ai moduli nella cartella `tool/`. Per modifiche ai file core (compiler, workflow CI/CD, script di build), apri una **Issue** descrivendo la proposta.

#### 📋 Passaggi Configurazione

1. Vai nella pagina del tuo fork su GitHub
2. Naviga in **Settings > Actions > General**
3. Imposta **Actions permissions** su `Allow all actions and reusable workflows`
4. Abilita **Read and write permissions** nella sezione Workflow permissions
5. Salva le modifiche

#### 🔄 Comandi Esecuzione

```bash
# 1. Assicurati di essere sul branch Dev
git checkout Dev

# 2. Effettua le tue modifiche ai moduli in /tool/ o al template

# 3. Committa e pusha direttamente sul branch Dev del tuo fork
git add .
git commit -m "- Descrizione modifiche"
git push origin Dev
```

#### ⚙️ Funzionamento Automatico

Appena pushati:

1. Il workflow `CI_UpdateWinToolkit_Dev.yml` si avvierà automaticamente
2. Verranno eseguiti **nella tua fork**:
    - ✅ Controllo sicurezza sulle modifiche (PR Security Guard a 3 livelli)
    - ✅ Linting completo con PSScriptAnalyzer
    - ✅ Test suite Pester 5 (validazione moduli e funzionalità)
    - ✅ Validazione sintassi AST (compiler.ps1 e template)

> [!IMPORTANT]
> **Nota Fondamentale**: La pipeline su push esegue lint, test e build. Il versioning ufficiale avviene esclusivamente tramite il workflow `Create_Release.yml` (manualmente attivato). Nelle fork, i job di build committano il file `WinToolkit.ps1` generato.

#### ✅ Verifica Risultato

1. Vai nella tab **Actions** del tuo fork
2. Controlla che il workflow sia completato con successo (✅)
3. Se tutti i controlli passano, il tuo codice è valido e compatibile
4. Per ottenere il file `WinToolkit.ps1` compilato usa la **Modalità 2 Offline**
5. Quando aprirai la PR verso il repository ufficiale, l'intera pipeline verrà eseguita automaticamente

> [!Tip]
> Se il workflow fallisce, consulta i log dettagliati per identificare l'errore. I controlli di sicurezza bloccheranno automaticamente PR che modificano file al di fuori della cartella `/tool`.

---

### 🔵 Modalità 2: Test Offline Locale con compiler.ps1

Questa modalità permette di compilare e testare WinToolkit completamente offline senza necessità di pushare su GitHub.

#### ✅ Prerequisiti Sistema

- Windows 10 1809+ / Windows 11 22H2+
- PowerShell 5.1 o PowerShell 7+
- Privilegi Amministratore
- Nessuna dipendenza esterna richiesta

#### 📋 Passaggi Esecuzione

1. Apri PowerShell come Amministratore
2. Naviga nella cartella root del repository:

```powershell
cd C:\Percorso\A\WinToolkit
```

3. Esegui il compilatore ufficiale:

```powershell
.\compiler.ps1
```

#### ⚙️ Fasi Compilazione

Il compilatore eseguirà automaticamente queste operazioni:

1. Validazione prerequisiti e struttura cartelle
2. Caricamento template e tutti i moduli da `/tool/`
3. Iniezione automatica di ogni funzione nel template
4. Minificazione sicura tramite parser ufficiale PowerShell
5. Verifica sintassi file finale
6. Generazione dashboard statistiche

#### ✅ Verifica Risultato

Al termine della compilazione verrà mostrato un report con:

- Numero moduli processati
- Dimensione sorgente vs finale
- Percentuale di compressione
- Tempo totale compilazione

Per testare il file generato:

```powershell
# Esegui direttamente il file compilato
.\WinToolkit.ps1
```

> [!Note]
> In caso di errori durante la compilazione, il compilatore mostrerà l'esatto punto di errore e ripristinerà automaticamente lo stato precedente. Non verrà generato un file corrotto.

---

## 🏷️ Tag per la Categorizzazione delle Pull Request

> [!IMPORTANT]
> **Obbligatorio: Usa i tag corretti**
>
> Quando apri una Pull Request, è fondamentale categorizzarla correttamente tramite uno dei tag supportati.
> I tag permettono al maintainer di identificare rapidamente la natura della modifica e di gestire le PR in modo ordinato.
> L'uso scorretto dei tag comporta il rifiuto o il rinvio della PR fino alla correzione.

### Tag Supportati

| Tag                | Categoria                                    | Descrizione                                                                                                            |
| ------------------ | -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `BUG`              | Bug Fixes                                    | Correzione di un errore o comportamento difettoso già presente nel codice. La PR deve riferirsi a una issue esistente. |
| `ENHANCEMENT`      | Miglioramento Funzione                       | Modifica o miglioramento di una funzione già esistente che ne aumenta la qualità, la velocità o la robustezza.         |
| `FEATURE`          | Aggiunta Funzionalità Richiesta non presente | Implementazione di una nuova funzionalità precedentemente richiesta e non ancora disponibile nel toolkit.              |
| `GUI`              | Modifica GUI                                 | Qualsiasi modifica all'interfaccia grafica (`WinToolkit_GUI.ps1`) o ai componenti visuali del toolkit.                 |
| `External Changes` | Modifiche dei Contributori Esterni           | Modifica proposta da un collaboratore esterno che non fa parte del team di sviluppo diretto. Riservato al maintainer.  |

### Come Usare i Tag

Inserisci il tag all'inizio del titolo della Pull Request, separato da uno `/` o `-` dalla descrizione:

```
BUG/corretto crash su WinCleaner durante pulizia cartella Temp
ENHANCEMENT/ottimizzato algoritmo ordinamento in GamingToolkit
FEATURE/aggiunta opzione backup automatico in WinBackupDriver
GUI/aggiustato layout finestra principale di WinToolkit_GUI
```

> [!TIP]
> È possibile combinare il tag con il prefisso del branch (es. `fix/BUG/nome`) ma **non è obbligatorio**.
> La pipeline CI riconosce entrambe le forme e processa la PR correttamente.

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

> [!Note]
> **Informazioni Utili per la Risoluzione**
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
| **Dev**                  | Branch di lavoro per sviluppo, test e integrazione continua   | Target PR      |
| **main**                 | Branch di distribuzione, contiene solo WinToolkit.ps1 compilato| Release        |
| **Backlog**              | Problemi complessi, nuove feature, discussioni architecturali | Bassa Priorità |

### Criteri di Assegnazione

- **Dev**: Tutti i contributi vanno diretti a questo branch. Qui si svolge lo sviluppo e i test.
- **main**: Branch protetto. L'output compilato (`WinToolkit.ps1`) viene qui committato tramite release.
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
git checkout Dev
git pull upstream Dev
git checkout -b fix/nome-del-fix
```

> [!TIP]
> **Pattern di branch supportati dalla pipeline**:
>
> - `fix/*` o `bugfix/*` → Pipeline leggera (lint + test + build)
> - `feature/*` o `feat/*` → Pipeline leggera (lint + test + build)
> - `hotfix/*` → Pipeline leggera (lint + test + build)
> - `BUG/*`, `ENHANCEMENT/*`, `FEATURE/*` → Pipeline leggera (lint + test + build)
> - `Dev` → Pipeline completa (lint + test + build)
>
> I nomi dei branch devono seguire questi pattern per attivare automaticamente la CI.

### Step 5: Effettua le Modifiche

> [!Note]
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

- **Documentazione Ufficiale**: [README.md](/README.md).
- **Changelog**: [CHANGELOG.md](/CHANGELOG.md).
- **Issue Tracker**: [Issues](https://github.com/MagnetarMan/WinToolkit/issues).

---

## **Grazie per contribuire a WinToolkit!**

Il tuo contributo è fondamentale per migliorare questo strumento per tutta la comunità.
