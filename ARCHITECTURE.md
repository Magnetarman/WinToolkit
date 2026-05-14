# Architettura di WinToolkit

Questa guida descrive il sistema di build, la struttura dei branch, l'organizzazione dei moduli e come testare localmente le modifiche.

---

## Struttura dei Branch

WinToolkit usa una separazione deliberata tra branch di sviluppo e branch di distribuzione:

```
Dev (sorgenti)                  main (distribuzione)
├── WinToolkit-template.ps1     ├── WinToolkit.ps1   ← compilato da Dev
├── tool/*.ps1  (13 moduli)     ├── start.ps1
├── compiler.ps1                ├── asset/
├── .github/scripts/            ├── README.md
├── .github/workflows/          ├── CHANGELOG.md
└── .github/tests/              └── LICENSE
```

- **`Dev`** — branch di lavoro per i contributor. Contiene tutti i sorgenti, il compilatore e i workflow CI.
- **`main`** — branch di distribuzione. Gli utenti che clonano il repository ottengono solo il toolkit compilato e funzionante, senza il codice sorgente intermedio.

Il flusso è: modifichi i sorgenti su `Dev` → la pipeline CI compila → l'output `WinToolkit.ps1` viene committato su `main`.

---

## Sistema di Build

### `compiler.ps1` — Il compilatore

`compiler.ps1` è il cuore del sistema. Aggrega `WinToolkit-template.ps1` e i 13 moduli `tool/*.ps1` in un unico file distribuibile `WinToolkit.ps1`.

**Flusso di compilazione in 7 fasi:**

```
WinToolkit-template.ps1  +  tool/*.ps1
             │
             ▼
       compiler.ps1
  ┌────────────────────────────────────────┐
  │ Fase 1: Logging enterprise             │
  │ Fase 2: Validazione prerequisiti       │
  │ Fase 3: Lettura sorgenti               │
  │ Fase 4: Iniezione codice               │
  │   ↳ Trova placeholder nel template     │
  │   ↳ De-incapsula il modulo tool        │
  │   ↳ Inietta corpo della funzione       │
  │   ↳ Aggiunge logging se assente        │
  │ Fase 5: Minificazione opzionale (AST)  │
  │ Fase 6: Scrittura UTF-8 senza BOM      │
  │ Fase 7: Dashboard metriche             │
  └────────────────────────────────────────┘
             │
             ▼
       WinToolkit.ps1 (output)
```

**Come funziona l'iniezione:** il template contiene placeholder del tipo `# [INJECT:NomeFunzione]`. Il compiler trova il placeholder, legge il modulo `tool/NomeFunzione.ps1`, de-incapsula il corpo della funzione (rimuove il wrapper `function NomeFunzione { ... }` esterno) e inietta il codice nel template.

### `.github/scripts/` — Script CI

| Script | Responsabilità |
|--------|---------------|
| `Update-Version.ps1` | Legge `version.json`, incrementa il build number, aggiorna `WinToolkit-template.ps1` e `start.ps1`, pubblica gli output per i job successivi |
| `Invoke-Build.ps1` | Orchestratore CI: valida i prerequisiti, invoca `compiler.ps1`, verifica l'output, pubblica le metriche |
| `Test-CompiledScript.ps1` | Suite di validazione post-build: sintassi AST, disponibilità funzioni, struttura menu, dimensione file, encoding UTF-8 |

### `version.json` — Fonte unica di verità per la versione

```json
{
  "version": "2.5.4",
  "build": 46
}
```

`Update-Version.ps1` legge e scrive questo file come fonte primaria. Gli altri file (`WinToolkit-template.ps1`, `start.ps1`) vengono aggiornati come step derivati.

---

## Struttura dei Moduli Tool

Ogni file in `tool/` è un modulo indipendente che esporta esattamente **una funzione pubblica** con lo stesso nome del file (senza estensione):

```
tool/
├── DisableBitlocker.ps1      → function DisableBitlocker { ... }
├── GamingToolkit.ps1         → function GamingToolkit { ... }
├── Install-Office.ps1        → function Install-Office { ... }
├── Repair-Office.ps1         → function Repair-Office { ... }
├── Uninstall-Office.ps1      → function Uninstall-Office { ... }
├── VideoDriverInstall.ps1    → function VideoDriverInstall { ... }
├── WinBackupDriver.ps1       → function WinBackupDriver { ... }
├── WinCleaner.ps1            → function WinCleaner { ... }
├── WinDebloat.ps1            → function WinDebloat { ... }
├── WinExportLog.ps1          → function WinExportLog { ... }
├── WinReinstallStore.ps1     → function WinReinstallStore { ... }
├── WinRepairToolkit.ps1      → function WinRepairToolkit { ... }
└── WinUpdateReset.ps1        → function WinUpdateReset { ... }
```

I moduli possono definire funzioni helper interne (`function Get-GpuManufacturer`, ecc.) che vengono anch'esse incluse nell'output compilato.

Le funzioni del framework (UI, logging, configurazione) sono definite in `WinToolkit-template.ps1` e disponibili a tutti i moduli a runtime.

---

## Pipeline CI/CD

### `CI_UpdateWinToolkit_Dev.yml` — Pipeline Dev

Attivata su push e PR verso `Dev/*`.

```
push/PR → Dev
      │
      ▼
[pr_security_guard]  ← controllo accessi a 3 livelli sui file modificati
      │
      ├─────────────────┐
      ▼                 ▼
 [linting]         [testing]     ← paralleli
      │                 │
      └─────┬───────────┘
            ▼
         [build]                 ← compila e committa WinToolkit.ps1
```

Il job `pr_security_guard` applica un controllo a 3 livelli:
- `tool/*` — sempre consentito a tutti i contributor
- File sensibili (`.github/scripts/`, workflow) — genera warning, richiede revisione maintainer
- File core (`WinToolkit-template.ps1`, `compiler.ps1`) — bloccati per i non-maintainer

### `Create_Release.yml` — Creazione release

Genera le release notes dal CHANGELOG e prepara gli asset per la distribuzione.

### `Release_Wintoolkit.yml` — Pubblicazione su `main`

Crea il branch `release/vX.Y.Z`, applica le modifiche compilate e prepara la PR verso `main` (creazione PR manuale per scelta architetturale intenzionale).

---

## Come testare localmente

### Prerequisiti

- PowerShell 7+ (`winget install Microsoft.PowerShell`)
- Modulo Pester 5 (`Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser`)
- PSScriptAnalyzer (`Install-Module PSScriptAnalyzer -Scope CurrentUser`)

### Compilare il toolkit

```powershell
# Dalla root del repository (branch Dev)
.\compiler.ps1

# Con minificazione
.\compiler.ps1 -Minify
```

L'output viene scritto in `WinToolkit.ps1`.

### Eseguire i test

```powershell
# Test suite principale
Invoke-Pester .github/tests/WinToolkit.Tests.ps1 -Output Detailed

# Test unitari dei moduli
Invoke-Pester .github/tests/Unit/ -Output Detailed

# Validazione post-build
.github/scripts/Test-CompiledScript.ps1 -ScriptPath WinToolkit.ps1
```

### Eseguire il linter

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .github/linters/PSScriptAnalyzer-settings.psd1
```

### Aggiungere un nuovo modulo

1. Creare `tool/NuovoModulo.ps1` con una funzione pubblica `function NuovoModulo { ... }`
2. Aggiungere il placeholder `# [INJECT:NuovoModulo]` nel punto corretto di `WinToolkit-template.ps1`
3. Aggiungere la voce nel menu principale del template
4. Compilare con `compiler.ps1` e verificare l'output
5. Aggiungere un file di test in `.github/tests/Unit/NuovoModulo.Tests.ps1`

---

## Struttura dei File di Test

```
.github/tests/
├── Unit/
│   ├── VideoDriver.Tests.ps1
│   ├── GamingToolkit.Tests.ps1
│   └── Build.Tests.ps1
├── WinToolkit.Tests.ps1     ← test core del framework
└── TestHelpers.ps1          ← mock condivisi (pianificato)
```

I test usano il pattern dot-source con `-ImportOnly` per caricare il framework senza eseguire il toolkit:

```powershell
. $TemplatePath -ImportOnly   # carica le funzioni del framework
. $ToolPath                   # carica la funzione sotto test
```
