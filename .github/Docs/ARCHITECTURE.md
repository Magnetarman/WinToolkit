# WinToolkit Architecture

This guide describes the build system, branch structure, module organization, and how to test local changes.

---

## Branch Structure

WinToolkit uses a deliberate separation between development and distribution branches:

```
Dev (sources)                  main (distribution)
├── wintoolkit-modules/        ├── WinToolkit.ps1   ← compiled from Dev
├── tools/*.ps1  (15 modules)  ├── start.ps1
├── compiler.ps1               ├── assets/
├── .github/scripts/           ├── README.md
├── .github/workflows/         ├── .github/Docs/CHANGELOG.md
└── .github/tests/             └── LICENSE
```

- **`Dev`** — the working branch for contributors. Contains all sources, the compiler, and CI workflows.
- **`main`** — the distribution branch. Users who clone the repository get only the compiled, working toolkit, without the intermediate source code.

The flow is: modify sources on `Dev` → CI pipeline compiles → output `WinToolkit.ps1` is committed to `main`.

---

## Build System

### `compiler.ps1` — The Compiler

`compiler.ps1` is the heart of the system. It aggregates `wintoolkit-modules/` and all the `tools/*.ps1` modules into a single distributable `WinToolkit.ps1`.

**Compilation flow in 7 phases:**

```
wintoolkit-modules/  +  tools/*.ps1
               │
               ▼
         compiler.ps1
    ┌────────────────────────────────────────┐
    │ Phase 1: Enterprise logging            │
    │ Phase 2: Prerequisite validation       │
    │ Phase 3: Source reading                │
    │   ↳ wintoolkit-modules/*.ps1 assembled │
    │   ↳ in memory into the core template   │
    │ Phase 4: Code injection                │
    │   ↳ Find stub function in template     │
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

**How injection works:** the core template (assembled from `wintoolkit-modules/*.ps1`, ordered by file name) contains empty stub placeholders of the form `function FunctionName {}` — declared in `wintoolkit-modules/87-Placeholder.Compiler.ps1`. For every file `tools/FunctionName.ps1`, the compiler locates the matching stub function in the assembled template, de-encapsulates the tool module's body (removes the outer `function FunctionName { ... }` wrapper when present) and replaces the stub body with the tool code. If the tool lacks its own logging call, the compiler injects `Start-ToolkitLog` automatically.

### `.github/scripts/` — CI Scripts

| Script                         | Responsibility                                                                                                                                                        |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Update-Version.ps1`           | Reads `$ToolkitVersion` from `wintoolkit-modules/`, increments the build number, aligns `start-modules/00-Skeleton.Header.ps1`, publishes outputs for downstream jobs |
| `Update-PipelineVersion.ps1`   | Reads `PIPELINE_VERSION` (single source of truth) and aligns the version token in every workflow, action and pipeline script; `-Check` fails on drift         |
| `Format-FunctionSpacing.ps1`   | Source-only blank-line normalizer for `start-modules/` and `wintoolkit-modules/`; refuses every other path, so compiled artifacts are never reformatted        |
| `Minify-Source.ps1`            | Tokenizer-safe minifier (comments, whitespace, blank lines) with syntax verification and rollback                                                                      |
| `Invoke-Build.ps1`             | CI orchestrator: validates prerequisites, invokes `compiler.ps1`, verifies output, publishes metrics                                                                  |
| `Invoke-Build-Start.ps1`       | Concatenates the ordered `start-modules/*.ps1` fragments into `start-core.ps1` and publishes size metrics; the artifact is emitted compact and is never reformatted |
| `Test-CompiledScript.ps1`      | Post-build validation suite: AST syntax, function availability, menu structure, file size, UTF-8 encoding                                                             |
| `Test-CompiledStartScript.ps1` | Validates `start-core.ps1`: AST syntax, expected functions, no duplicate SOURCE markers, no `Import-Module`, minimum size                                             |

### `$ToolkitVersion` — Single Source of Truth for Versioning

The authoritative version lives in a single place: the `$ToolkitVersion` variable in
`wintoolkit-modules/`.

```powershell
$ToolkitVersion = "2.6.0 (Build 5)"
```

`Update-Version.ps1` reads that variable, bumps the build number, and writes it back.
Any other file carrying a version string — currently
`start-modules/00-Skeleton.Header.ps1` — is **aligned to** the template, never the
other way around. Every forced alignment is reported through the `aligned_sources`
output so it is traceable in CI.

There is no `version.json`: the separate JSON source was removed in V4.0 precisely
because two sources of truth could drift apart.

### `$PIPELINE_VERSION` — Single Source of Truth for the CI/CD Version

The pipeline version is managed the same way, with its own single source of truth: the
`PIPELINE_VERSION` variable in the `env:` block of `.github/workflows/CI-WinToolkit-Dev.yml`
(near the top of the file).

```yaml
env:
  # SINGLE SOURCE OF TRUTH for the CI/CD pipeline version.
  PIPELINE_VERSION: "4.1.0"
```

**That variable is the only place to edit.** Every other version number is aligned to it,
and hand-editing a version in a workflow, action or pipeline script header is always a
mistake: the CI gate fails on it.

**What it covers — and nothing else:**

| Scope                 | Files                                                                 | Token            |
| --------------------- | ---------------------------------------------------------------------- | ---------------- |
| `.yml`                | `.github/workflows/*.yml` (12) and `.github/actions/*/action.yml` (3)   | `WinToolkit ... V4.1.0` |
| `.ps1`                | `.github/scripts/*.ps1` and `.github/tests/**/*.ps1` (22, in total)     | `# WinToolkit CI/CD V4.1.0` |
| Application sources   | `start-modules/`, `wintoolkit-modules/`, `tools/`, `WinToolkit.ps1`, `start-core.ps1` | untouched — they carry the product version, not the pipeline version |

**How it propagates:**

1. **On every CI run, including pull requests**, the `Align pipeline version` step in
   `_reusable-lint-test.yml` runs the script in write mode: drift is **corrected in place and
   the run continues**. The pipeline adapts to the single source of truth, it never blocks on
   it, and the corrected files are already valid for the rest of that same run because the
   rewrite is byte-level.
2. **On every push to `Dev`**, the `sync-pipeline-version` job (in `CI-WinToolkit-Dev.yml`)
   delegates to `_reusable-pipeline-version.yml`, which checks out `Dev`, runs the same
   script, validates the YAML and commits **only the files it changed**. The commit message
   carries `[skip ci]`, so a cosmetic alignment never starts a new run that would cancel the
   one in progress, and the commit step is `continue-on-error`: a push refused by branch
   protection leaves the run green and the next push re-aligns.
3. **Locally**, the same script provides the manual path:

```powershell
# Preview the alignment without writing anything
.\.github\scripts\Update-PipelineVersion.ps1 -WhatIf

# Align everything to the canonical value (no-op when already aligned)
.\.github\scripts\Update-PipelineVersion.ps1

# Bump and align in one step (the canonical value is updated too)
.\.github\scripts\Update-PipelineVersion.ps1 -Version 4.2.0

# Diagnostic only: fails when something drifted (never used in CI)
.\.github\scripts\Update-PipelineVersion.ps1 -Check
```

The rewrite is byte-level: only the version token changes, while encoding, BOM and line
endings are preserved exactly. The script is idempotent, so an aligned repository produces
no commit and no noise in the run summary.

A pipeline script without the header is treated the same way: it is **inserted**, not
rejected. The header lands on the first line with BOM and line endings preserved, so a brand
new `.ps1` can never stay unversioned and can never fail the pipeline because of it.

> [!NOTE]
> The only version-related failure the pipeline can still raise is a genuine tool bug: after
> the alignment, every `.ps1` under `.github` is parsed and a syntax error fails the job. That
> protects against the alignment itself corrupting a script.

---

## Tool Module Structure

Each file in `tools/` is an independent module that exports exactly **one public function** with the same name as the file (without extension):

```
tools/
├── AutoVideoDriverInstall.ps1 → function AutoVideoDriverInstall { ... }
├── DisableBitlocker.ps1       → function DisableBitlocker { ... }
├── GamingToolkit.ps1          → function GamingToolkit { ... }
├── Install-Office.ps1         → function Install-Office { ... }
├── Repair-Office.ps1          → function Repair-Office { ... }
├── Uninstall-Office.ps1       → function Uninstall-Office { ... }
├── VideoDriverReinstall.ps1   → function VideoDriverReinstall { ... }
├── WinBackupDriver.ps1        → function WinBackupDriver { ... }
├── WinCleaner.ps1             → function WinCleaner { ... }
├── WinDebloat.ps1             → function WinDebloat { ... }
├── WinDeleteUserProfiles.ps1  → function WinDeleteUserProfiles { ... }
├── WinExportLog.ps1           → function WinExportLog { ... }
├── WinReinstallStore.ps1      → function WinReinstallStore { ... }
├── WinRepairToolkit.ps1       → function WinRepairToolkit { ... }
└── WinUpdateReset.ps1         → function WinUpdateReset { ... }
```

Modules may define internal helper functions (`function Get-GpuManufacturer`, etc.) that are also included in the compiled output.

Framework functions (UI, logging, configuration) are defined in `wintoolkit-modules/` and are available to all modules at runtime.

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
   ├─ pipeline version gate
   ├─ fragment spacing
   ├─ PSScriptAnalyzer
   └─ AST validation    │
      │                 │
      └─────┬───────────┘
            ▼
         [build]                 ← compiles and commits WinToolkit.ps1
            │
            ▼
 [build-start]                 ← compiles and commits start-core.ps1

push to Dev only:
[sync-pipeline-version]        ← aligns PIPELINE_VERSION across .github and commits
```

The `sync-pipeline-version` job runs in parallel with the quality gate and the builds: it
touches only workflow/action/script version tokens, so it never competes with the compiled
artifacts. It commits nothing when the repository is already aligned.

The `pr_security_guard` job applies a 3-level check:

- `tools/*` — always allowed for all contributors
- Sensitive files (`.github/scripts/`, workflows) — generates warnings, requires maintainer review
- Core files (`wintoolkit-modules/`, `compiler.ps1`) — blocked for non-maintainers

### `Release-PreRelease.yml` — Release Creation

Generates release notes from the CHANGELOG and prepares assets for distribution.

### `Release-Stable.yml` — Publishing to `main`

Creates the `release/vX.Y.Z` branch, applies compiled changes, and prepares a PR to `main` (PR creation is manual by intentional architectural choice).

### `Top-Contributors.yml` — Top Contributors Update

Automatically updates the "Top 10 Contributors" section in the README on `main`.

```
schedule/workflow_dispatch
       │
       ▼
  [validate]  ← official repo + admin/maintainer permissions
       │
       ▼
  [update-contributors]  ← GitHub API queries (commits + PRs on Dev)
       │
       ├─ Calculates rankings (PRs primary, commits secondary)
       ├─ Excludes bots (github-actions[bot], dependabot[bot])
       ├─ Updates README between HTML markers
       └─ Creates/updates PR toward main
```

Trigger:
- Schedule: every Monday at 06:00 Italian time (runtime CET/CEST check)
- Manual: `workflow_dispatch` with admin/maintainer permission check

The script `.github/scripts/Get-TopContributors.ps1` queries the GitHub APIs with pagination, calculates the ranking, and updates the README. Because `main` has active branch protection, direct push is blocked and a PR is mandatory to deliver changes.

### V4.1 CI/CD modular architecture

The V4.1 pipeline separates orchestration from reusable implementation. Its version is the
one declared by `PIPELINE_VERSION` and is never written by hand in the files below:

- `_reusable-lint-test.yml`: pipeline version gate, fragment spacing, linting, AST validation and Pester quality gates.
- `_reusable-build-wintoolkit.yml`: cleanup, compilation, artifact tests and commit of `WinToolkit.ps1`.
- `_reusable-build-start.yml`: cleanup, compilation, validation and commit of `start-core.ps1`.
- `_reusable-versioning.yml`: version bump, template validation and commit on the target branch.
- `_reusable-pipeline-version.yml`: reads `PIPELINE_VERSION`, aligns the version in every workflow, action and pipeline script, and commits only the changed files.
- `.github/actions/setup-powershell-modules/`: idempotent Pester/PSScriptAnalyzer setup.
- `.github/actions/validate-syntax/`: shared PowerShell AST validation.
- `.github/actions/pre-build-cleanup/`: shared generated-artifact cleanup.

The Dev orchestrator calls the quality gate plus both reusable build workflows, and — on
pushes to `Dev` — the pipeline version sync. Main calls the quality gate with template
validation disabled and delegates versioning to the reusable versioning workflow. The
pre-release workflow delegates versioning and both artifact builds.

### `start.ps1` and `start-core.ps1`

`start.ps1` is an ASCII-safe launcher. It locates/elevates PowerShell 7 and downloads or executes `start-core.ps1`. The core is generated from the ordered fragments in `start-modules/` by `.github/scripts/Invoke-Build-Start.ps1` and validated by `.github/scripts/Test-CompiledStartScript.ps1`.

Compiled artifacts are **machine-only**: they are read by the PowerShell host, never by a
human or an AI reviewer, so they must stay as compact as possible. The build therefore
never reformats them — no blank-line injection, no comment restoration, no re-reading of
the fragments. The same rule applies to `WinToolkit.ps1`.

Readability is a property of the **sources**, handled by a separate tool:

```powershell
# Normalize blank-line spacing in the source fragments only
.\.github\scripts\Format-FunctionSpacing.ps1 -Path start-modules -WhatIf
.\.github\scripts\Format-FunctionSpacing.ps1 -Path start-modules,wintoolkit-modules
```

`Format-FunctionSpacing.ps1` caps consecutive blank lines, trims trailing whitespace and
keeps a single final newline; it never adds blank lines, so compliant files are a no-op.
Its scope is enforced by a hard guard: it accepts only files under `start-modules\` and
`wintoolkit-modules\` and refuses `WinToolkit.ps1`, `start-core.ps1` and everything else.
Here-string payloads and block comments are copied verbatim, and a file whose formatting
would break its syntax is left untouched. The same normalization runs in CI through the
`Normalize fragment spacing` step of `_reusable-lint-test.yml`.

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

### Maintaining the Pipeline

```powershell
# Preview: which files would be aligned to PIPELINE_VERSION
.\.github\scripts\Update-PipelineVersion.ps1 -WhatIf

# Align (no-op when already aligned)
.\.github\scripts\Update-PipelineVersion.ps1

# Bump the pipeline version everywhere, canonical value included
.\.github\scripts\Update-PipelineVersion.ps1 -Version 4.2.0

# Gate: fails if any workflow, action or pipeline script drifted
.\.github\scripts\Update-PipelineVersion.ps1 -Check

# Normalize blank-line spacing in the source fragments (never the artifacts)
.\.github\scripts\Format-FunctionSpacing.ps1 -Path start-modules,wintoolkit-modules -WhatIf
```

### Running the Linter

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .github/linters/PSScriptAnalyzer-settings.psd1
```

### Adding a New Module

1. Create `tools/NewModule.ps1` with a public function `function NewModule { ... }`
2. Add the placeholder `# [INJECT:NewModule]` at the correct point in `wintoolkit-modules/`
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
