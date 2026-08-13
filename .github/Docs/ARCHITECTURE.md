# WinToolkit Architecture

This guide describes the build system, branch structure, module organization, and how to test local changes.

---

## Branch Structure

WinToolkit uses a deliberate separation between development and distribution branches:

```
Dev (sources)                  main (distribution)
├── WinToolkit-template.ps1     ├── WinToolkit.ps1   ← compiled from Dev
├── tool/*.ps1  (13 modules)    ├── start.ps1
├── compiler.ps1                ├── asset/
├── .github/scripts/            ├── README.md
├── .github/workflows/          ├── CHANGELOG.md
└── .github/tests/              └── LICENSE
```

- **`Dev`** — the working branch for contributors. Contains all sources, the compiler, and CI workflows.
- **`main`** — the distribution branch. Users who clone the repository get only the compiled, working toolkit, without the intermediate source code.

The flow is: modify sources on `Dev` → CI pipeline compiles → output `WinToolkit.ps1` is committed to `main`.

---

## Build System

### `compiler.ps1` — The Compiler

`compiler.ps1` is the heart of the system. It aggregates `WinToolkit-template.ps1` and all the `tool/*.ps1` modules into a single distributable `WinToolkit.ps1`.

**Compilation flow in 7 phases:**

```
WinToolkit-template.ps1  +  tool/*.ps1
              │
              ▼
        compiler.ps1
   ┌────────────────────────────────────────┐
   │ Phase 1: Enterprise logging            │
   │ Phase 2: Prerequisite validation       │
   │ Phase 3: Source reading                │
   │ Phase 4: Code injection                │
   │   ↳ Find placeholder in template       │
   │   ↳ De-encapsulate the tool module     │
   │   ↳ Inject function body               │
   │   ↳ Add logging if absent              │
   │ Phase 5: Optional minification (AST)   │
   │ Phase 6: Write UTF-8 without BOM       │
   │ Phase 7: Metrics dashboard             │
   └────────────────────────────────────────┘
              │
              ▼
        WinToolkit.ps1 (output)
```

**How injection works:** the template contains placeholders of the form `# [INJECT:FunctionName]`. The compiler finds the placeholder, reads the module `tool/FunctionName.ps1`, de-encapsulates the function body (removes the outer `function FunctionName { ... }` wrapper) and injects the code into the template.

### `.github/scripts/` — CI Scripts

| Script | Responsibility |
|--------|---------------|
| `Update-Version.ps1` | Reads `version.json`, increments the build number, updates `WinToolkit-template.ps1` and `start.ps1`, publishes outputs for downstream jobs |
| `Invoke-Build.ps1` | CI orchestrator: validates prerequisites, invokes `compiler.ps1`, verifies output, publishes metrics |
| `Test-CompiledScript.ps1` | Post-build validation suite: AST syntax, function availability, menu structure, file size, UTF-8 encoding |

### `version.json` — Single Source of Truth for Versioning

```json
{
  "version": "2.5.5",
  "build": 1
}
```

`Update-Version.ps1` reads and writes this file as the primary source. Other files (`WinToolkit-template.ps1`, `start.ps1`) are updated as derived steps.

---

## Tool Module Structure

Each file in `tool/` is an independent module that exports exactly **one public function** with the same name as the file (without extension):

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
Etc...
```

Modules may define internal helper functions (`function Get-GpuManufacturer`, etc.) that are also included in the compiled output.

Framework functions (UI, logging, configuration) are defined in `WinToolkit-template.ps1` and are available to all modules at runtime.

---

## CI/CD Pipeline

### `CI-WinToolkit-Dev.yml` — Dev Pipeline

Triggered on push and PR to `Dev/*`.

```
push/PR → Dev
      │
      ▼
[pr_security_guard]  ← 3-level access check on modified files
      │
      ├─────────────────┐
      ▼                 ▼
 [linting]         [testing]     ← parallel
      │                 │
      └─────┬───────────┘
            ▼
         [build]                 ← compiles and commits WinToolkit.ps1
```

The `pr_security_guard` job applies a 3-level check:
- `tool/*` — always allowed for all contributors
- Sensitive files (`.github/scripts/`, workflows) — generates warnings, requires maintainer review
- Core files (`WinToolkit-template.ps1`, `compiler.ps1`) — blocked for non-maintainers

### `Release-PreRelease.yml` — Release Creation

Generates release notes from the CHANGELOG and prepares assets for distribution.

### `Release-Stable.yml` — Publishing to `main`

Creates the `release/vX.Y.Z` branch, applies compiled changes, and prepares a PR to `main` (PR creation is manual by intentional architectural choice).

### V4.0 CI/CD modular architecture

The V4.0 pipeline separates orchestration from reusable implementation:

- `_reusable-lint-test.yml`: linting, AST validation and Pester quality gates.
- `_reusable-build-wintoolkit.yml`: cleanup, compilation, artifact tests and commit of `WinToolkit.ps1`.
- `_reusable-build-start.yml`: cleanup, compilation, validation and commit of `start-core.ps1`.
- `_reusable-versioning.yml`: version bump, template validation and commit on the target branch.
- `.github/actions/setup-powershell-modules/`: idempotent Pester/PSScriptAnalyzer setup.
- `.github/actions/validate-syntax/`: shared PowerShell AST validation.
- `.github/actions/pre-build-cleanup/`: shared generated-artifact cleanup.

The Dev orchestrator calls the quality gate plus both reusable build workflows. Main calls the quality gate with template validation disabled and delegates versioning to the reusable versioning workflow. The pre-release workflow delegates versioning and both artifact builds.

### `start.ps1` and `start-core.ps1`

`start.ps1` is an ASCII-safe launcher. It locates/elevates PowerShell 7 and downloads or executes `start-core.ps1`. The core is generated from the ordered fragments in `start-modules/` by `.github/scripts/Invoke-Build-Start.ps1` and validated by `.github/scripts/Test-CompiledStartScript.ps1`.

---

## How to Test Locally

### Prerequisites

- PowerShell 7+ (`winget install Microsoft.PowerShell`)
- Pester 5 module (`Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser`)
- PSScriptAnalyzer (`Install-Module PSScriptAnalyzer -Scope CurrentUser`)

### Building the Toolkit

```powershell
# From the repository root (branch Dev)
.\compiler.ps1

# With minification
.\compiler.ps1 -Minify
```

Output is written to `WinToolkit.ps1`.

### Running Tests

```powershell
# Main test suite
Invoke-Pester .github/tests/WinToolkit.Tests.ps1 -Output Detailed

# Module unit tests
Invoke-Pester .github/tests/Unit/ -Output Detailed

# Post-build validation
.github/scripts/Test-CompiledScript.ps1 -ScriptPath WinToolkit.ps1

# Build and validate start-core.ps1
.github/scripts/Invoke-Build-Start.ps1 -Version '2.6.0 (Build 6)'
.github/scripts/Test-CompiledStartScript.ps1 -ScriptPath start-core.ps1

# Start-module tests
Invoke-Pester .github/tests/StartModules/ -Output Detailed
Invoke-Pester .github/tests/Integration/BuildStart.Tests.ps1 -Output Detailed
```

### Running the Linter

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .github/linters/PSScriptAnalyzer-settings.psd1
```

### Adding a New Module

1. Create `tool/NewModule.ps1` with a public function `function NewModule { ... }`
2. Add the placeholder `# [INJECT:NewModule]` at the correct point in `WinToolkit-template.ps1`
3. Add the entry in the template's main menu
4. Build with `compiler.ps1` and verify the output
5. Add a test file in `.github/tests/Unit/NewModule.Tests.ps1`

---

## Test File Structure

```
.github/tests/
├── Unit/
│   ├── VideoDriver.Tests.ps1
│   ├── GamingToolkit.Tests.ps1
│   └── Build.Tests.ps1
├── WinToolkit.Tests.ps1     ← core framework tests
└── TestHelpers.ps1          ← shared mocks (planned)
```

Tests use a dot-source pattern with `-ImportOnly` to load the framework without executing the toolkit:

```powershell
. $TemplatePath -ImportOnly   # loads framework functions
. $ToolPath                   # loads the function under test
```
