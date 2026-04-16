# Guida ai Pull Request e Contributi per WinToolkit

> **Documento Ufficiale per i Contributori**  
> Repository: [MagnetarMan/WinToolkit](https://github.com/MagnetarMan/WinToolkit)  
> Ultimo aggiornamento: 2026-04-14

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
> - **Tutte le modifiche DEVONO essere effettuate sul branch `DEV`**
> - Le Pull Request verso il branch `main` verranno **chiuse immediatamente** senza preavviso
> - Il branch `DEV` è l'unico branch accettato per contributi esterni

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
│   ├── linters/                          # Configurazione linter PowerShell
│   ├── scripts/                          # Script di automazione build e test
│   └── workflows/                        # Pipeline CI/CD GitHub Actions
│
├── asset/                                # Risorse statiche e strumenti esterni
│   ├── png/                              # Icone e immagini UI
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
│   └── WinToolkit.ico                    # Icona Wintoolkit
│
├── To-Do/                                # Note di sviluppo, bug tracking, idee
│
├── tool/                                 # Moduli funzionali del toolkit
│   ├── DisableBitlocker.ps1              # Gestione e disabilitazione BitLocker
│   ├── GamingToolkit.ps1                 # Ottimizzazioni specifiche per il gaming
│   ├── OfficeToolkit.ps1                 # Strumenti per gestione Microsoft Office
│   ├── VideoDriverInstall.ps1            # Installazione driver video avanzata
│   ├── WinBackupDriver.ps1               # Backup e ripristino driver di sistema
│   ├── WinCleaner.ps1                    # Pulizia file temporanei e cache
│   ├── WinDebloat.ps1                    # Rimozione bloatware Windows
│   ├── WinExportLog.ps1                  # Esportazione log per debug
│   ├── WinReinstallStore.ps1             # Reinstallazione Microsoft Store & Winget
│   ├── WinRepairToolkit.ps1              # Strumenti di riparazione sistema
│   └── WinUpdateReset.ps1                # Reset completo Windows Update
│
├── .gitignore                            # File ignorati da Git
├── CHANGELOG.md                          # Storico modifiche
├── compiler.ps1                          # Sistema di compilazione modulare ufficiale
├── LICENSE                               # Licenza MIT
├── README.md                             # Documentazione principale
├── start-offline.ps1                     # Avvio modalità offline
├── start.ps1                             # Script di avvio principale
├── TODO.md                               # Task e sviluppi futuri
├── WinToolkit_GUI.ps1                    # Versione WinToolkit GUI (WPF)
├── WinToolkit-template.ps1               # Template base con funzioni core (MODIFICABILE)
└── WinToolkit.ps1                        # File compilato finale (NON MODIFICARE MAI)
```

### Descrizione Dettagliata dei Componenti

#### Cartella `/tool/` - Moduli Funzionali

> [!Note]
> **NOTA: Area Principale di Sviluppo**
>
> La cartella `/tool/` contiene tutti i moduli funzionali del toolkit. Ogni file PowerShell rappresenta una funzionalità specifica **sviluppabile e testabile indipendentemente**.
>
> Il compilatore inietta automaticamente ogni modulo nel template principale durante la fase di build.

| File                     | Descrizione                                   |
| ------------------------ | --------------------------------------------- |
| `DisableBitlocker.ps1`   | Gestione e disabilitazione BitLocker          |
| `GamingToolkit.ps1`      | Ottimizzazioni specifiche per il gaming       |
| `OfficeToolkit.ps1`      | Strumenti per la gestione di Microsoft Office |
| `VideoDriverInstall.ps1` | Installazione driver video avanzata           |
| `WinBackupDriver.ps1`    | Backup e ripristino driver di sistema         |
| `WinCleaner.ps1`         | Pulizia file temporanei e cache               |
| `WinDebloat.ps1`         | Rimozione bloatware e telemetria Windows      |
| `WinExportLog.ps1`       | Esportazione log diagnostici per debug        |
| `WinReinstallStore.ps1`  | Reinstallazione Microsoft Store & WinGet      |
| `WinRepairToolkit.ps1`   | Strumenti di riparazione sistema (SFC/DISM)   |
| `WinUpdateReset.ps1`     | Reset completo servizi e cache Windows Update |

#### Cartella `/asset/` - Risorse Esterne

Contiene eseguibili e strumenti di terze parti utilizzati dal toolkit. Questi file vengono richiamati dai vari moduli in caso di necessità.

#### Cartella `/.github/` - Infrastruttura CI/CD

- **workflows/**: Pipeline GitHub Actions per CI/CD e distribuzione automatica
  - `CI_UpdateWinToolkit_Dev.yml`: Pipeline Dev automatica su ogni push/PR
  - `Release_Wintoolkit.yml`: Pipeline manuale per release stabili
- **scripts/**: Script PowerShell per build, versioning e test automatici
  - `Update-Version.ps1`: Incremento automatico numero build
  - `Invoke-Build.ps1`: Wrapper ufficiale del compilatore
  - `Test-CompiledScript.ps1`: Validazione post-compilazione
- **linters/**: Configurazione PSScriptAnalyzer
- **Docs/**: Documentazione ufficiale progetto

#### File Radice

| File                      | Ruolo                                                                 |
| ------------------------- | --------------------------------------------------------------------- |
| `WinToolkit-template.ps1` | Template base con funzioni core, logging e UI (MODIFICABILE)          |
| `WinToolkit.ps1`          | File compilato finale distribuito (GENERATO AUTOMATICAMENTE)          |
| `compiler.ps1`            | Sistema di compilazione ufficiale con tokenizer e minificazione sicura |
| `WinToolkit_GUI.ps1`      | Versione con interfaccia grafica WPF                                  |
| `start.ps1`               | Entry point ufficiale per distribuzione one-liner                     |
| `start-offline.ps1`       | Modalità di avvio senza connessione internet                          |

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
   - ✅ Controllo sicurezza sulle modifiche
   - ✅ Linting completo con PSScriptAnalyzer
   - ✅ Validazione sintassi compiler.ps1

> [!IMPORTANT]
> **Nota Fondamentale**: I job di versioning, build e generazione release sono **disabilitati automaticamente nelle fork** per motivi di sicurezza. Questo è il comportamento previsto confermato alle righe 249, 310 e 418 del workflow ufficiale.

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
