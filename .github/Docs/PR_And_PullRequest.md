# WinToolkit Pull Request and Contribution Guide

> **Official Contributor Document**
> Repository: [MagnetarMan/WinToolkit](https://github.com/MagnetarMan/WinToolkit)
> Last updated: 2026-07-29

---

## Project Philosophy

### Fundamental Rule: 1 Issue = 1 Single Problem/Bug

Every bug report or feature request must focus on a **single problem**. Do not mix different requests in a single issue to ensure:

- Precise traceability of changes
- Faster and targeted reviews
- Clean merges without conflicts

---

## Contribution Workflow

### Prerequisites

To contribute to the WinToolkit project, you need:

1. An active **GitHub account**
2. A **fork** of the official repository: [MagnetarMan/WinToolkit](https://github.com/MagnetarMan/WinToolkit/fork)

### Branching Rules

> [!WARNING]
> **Branching Restriction Rule**
>
> - Changes can be made on `Dev` branch or dedicated branches (`BUG/*`, `ENHANCEMENT/*`, `FEATURE/*`, `GUI/*`, `Changes/*`)
> - Pull Requests to the `main` branch will be **closed immediately** without notice
> - The `Dev` branch is the only accepted target for PRs
> - Branches `BUG/*`, `ENHANCEMENT/*`, `FEATURE/*`, `GUI/*`, `Changes/*` automatically trigger the lightweight CI pipeline

---

## Development Logic

### File Structure

WinToolkit uses a well-defined modular structure:

| Modification Type            | File Path                 | Description                         |
| ---------------------------- | ------------------------- | ----------------------------------- |
| **Functions/Scripts**        | `/tools/*.ps1`            | Individual toolkit modules          |
| **Global Variables/Aspects** | `WinToolkit-template.ps1` | Main template with global variables |

### ⚠️ ABSOLUTE PROHIBITION: Never Modify `WinToolkit.ps1`

> [!WARNING]
> **Auto Generated File**
>
> The file `WinToolkit.ps1` **must never be modified manually**. This file is the result of an automated **GitHub Actions pipeline** that:
>
> 1. Merges all scripts from the `/tool` folder into the template
> 2. Performs a **Build Bump** (version increment)
> 3. Runs **CI/CD tests**
> 4. Generates **automatic release**
>
> Any direct modification to `WinToolkit.ps1` will be automatically overwritten and **rejected** during the merge process.

### Correct Workflow

```
/tools/                  → Modify individual scripts
WinToolkit-template.ps1  → Modify global variables
WinToolkit.ps1           → NEVER TOUCH (auto-generated)
```

---

## Project Structure

### Overview

WinToolkit is organized in a modular structure that facilitates development, maintenance, and distribution. Below is the complete folder and file organization.

### Complete Tree

```
WinToolkit/
├── .github/                              # GitHub configuration (CI/CD, Actions, Scripts)
│   ├── Docs/                             # Project documentation
│   │   ├── PR_And_PullRequest.md         # PR guide (this document)
│   │   ├── ARCHITECTURE.md               # System architecture
│   │   └── SECURITY.md                   # Security policies
│   ├── ISSUE_TEMPLATE/                   # GitHub issue templates
│   ├── linters/                          # PowerShell linter configuration
│   ├── scripts/                          # Build and test automation scripts
│   ├── tests/                            # Automated project tests
│   │   ├── Unit/                         # Module unit tests
│   │   └── Integration/                  # Integration tests
│   ├── workflows/                        # GitHub Actions CI/CD pipelines
│   ├── CODEOWNERS                        # Codebase owners
│   ├── CODE_OF_CONDUCT.md                # Community code of conduct
│   ├── CONTRIBUTING.md                   # Contribution guidelines
│   ├── dependabot.yml                    # Dependabot configuration
│   ├── FUNDING.yml                       # Funding configuration
│   └── pull_request_template.md          # Pull Request template
│
├── assets/                               # Static assets and external tools
│   ├── Basic.xml                         # Office configuration
│   ├── DDU.zip                           # Display Driver Uninstaller
│   ├── DriverOverrides.json              # Driver Manifest for better match GPU/Driver Version
│   ├── dxwebsetup.exe                    # DirectX Web Setup
│   ├── Microsoft.PowerShell_profile.ps1  # Custom PowerShell profile
│   ├── NVCleanstall_1.19.0.exe           # NVIDIA Driver Cleaner
│   ├── OOSU10.exe                        # O&O ShutUp10 (Windows Debloat)
│   ├── ooshutup10.cfg                    # O&O ShutUp10 configuration
│   ├── png/                              # PNG image assets (excluded from release)
│   ├── settings.json                     # Windows Terminal settings file
│   ├── Setup.exe                         # Office 365 Setup
│   └── speedtest.exe                     # Network speed test
│
├── Docs/                                 # Technical documentation
│   └── Windows Updates and the Shared Servicing Model V1.2.pdf
│
├── images/                               # Images and graphical assets
│   ├── avatar/                           # Contributor avatars
│   │   └── zakkos.jpg
│   ├── Gui.jpg                           # GUI Version screenshot
│   ├── RepairToolkit-old.jpg             # Old UI version screenshot
│   ├── Run-old.jpg                       # Version 1.0 screenshot
│   ├── Run.jpg                           # Main Readme screenshot
│   ├── WinToolkit-Dev.ico                # Dev icon
│   ├── WinToolkit-icon.png               # Readme favicon
│   └── WinToolkit.ico                    # WinToolkit icon
│
├── languages/                            # Localization files
│   ├── ar-SA/
│   ├── bn-BD/
│   ├── en-US/
│   ├── es-ES/
│   ├── fr-FR/
│   ├── hi-IN/
│   ├── id-ID/
│   ├── it-IT/
│   ├── pt-BR/
│   ├── ru-RU/
│   ├── ur-PK/
│   └── zh-CN/
│
├── tools/                                # Toolkit functional modules
│   ├── AutoVideoDriverInstall.ps1        # Automatic video driver detection and install
│   ├── DisableBitlocker.ps1              # BitLocker management
│   ├── GamingToolkit.ps1                 # Gaming optimizations
│   ├── Install-Office.ps1                # Microsoft Office installation
│   ├── Repair-Office.ps1                 # Microsoft Office repair
│   ├── Uninstall-Office.ps1              # Microsoft Office uninstallation
│   ├── VideoDriverInstall.ps1            # Video driver installation
│   ├── VideoDriverReinstall.ps1          # Video driver reinstallation
│   ├── WinBackupDriver.ps1               # System driver backup
│   ├── WinCleaner.ps1                    # Temporary file cleanup
│   ├── WinDebloat.ps1                    # Bloatware removal
│   ├── WinDeleteUserProfiles.ps1         # Delete user profiles
│   ├── WinExportLog.ps1                  # Diagnostic log export
│   ├── WinReinstallStore.ps1             # Microsoft Store reinstallation
│   ├── WinRepairToolkit.ps1              # System repair tools (SFC/DISM)
│   └── WinUpdateReset.ps1                # Windows Update reset
│
├── version.json                          # Single source of truth for version
├── .gitignore                            # Files ignored by Git
├── CHANGELOG.md                          # Change history
├── compiler.ps1                          # Modular build system
├── LICENSE                               # MIT License
├── README.md                             # Main documentation
├── start-offline.ps1                     # Offline mode startup
├── start.ps1                             # Official startup script
├── TODO.md                               # Tasks and future development
├── WinToolkit_GUI.ps1                    # WPF graphical interface version
├── WinToolkit-template.ps1               # Base template with core functions
└── WinToolkit.ps1                        # Final compiled file (DO NOT MODIFY)
```

### Detailed Component Descriptions

#### `/tools/` Folder - Functional Modules

> [!Note]
> **NOTE: Main Development Area**
>
> The `/tools/` folder contains all functional modules of the toolkit. Each PowerShell file represents a specific feature that can be **developed and tested independently**.
>
> The compiler injects each module automatically into the main template during the build phase.

| File                         | Description                                  |
| ---------------------------- | -------------------------------------------- |
| `AutoVideoDriverInstall.ps1` | Automatic video driver detection and install |
| `DisableBitlocker.ps1`       | BitLocker management and disable             |
| `GamingToolkit.ps1`          | Gaming-specific optimizations                |
| `Install-Office.ps1`         | Office installation and configuration        |
| `Repair-Office.ps1`          | Office installation repair                   |
| `Uninstall-Office.ps1`       | Office uninstallation and removal            |
| `VideoDriverInstall.ps1`     | Advanced video driver installation           |
| `VideoDriverReinstall.ps1`   | Video driver reinstallation                  |
| `WinBackupDriver.ps1`        | System driver backup and restore             |
| `WinCleaner.ps1`             | Temporary files and cache cleanup            |
| `WinDebloat.ps1`             | Windows bloatware removal                    |
| `WinDeleteUserProfiles.ps1`  | Delete Windows user profiles                 |
| `WinExportLog.ps1`           | Diagnostic log export for debugging          |
| `WinReinstallStore.ps1`      | Microsoft Store & WinGet reinstallation      |
| `WinRepairToolkit.ps1`       | System repair tools (SFC/DISM)               |
| `WinUpdateReset.ps1`         | Full Windows Update reset                    |

#### `/assets/` Folder - External Resources

Contains third-party executables and tools used by the toolkit. These files are invoked by various modules as needed.

#### `/.github/` Folder - CI/CD Infrastructure

- **workflows/**: GitHub Actions pipelines for CI/CD and automatic distribution
    - `CI_UpdateWinToolkit_Dev.yml`: Adaptive Enterprise pipeline (full Dev, lightweight feature/fix, PR quality gate)
    - `CI_UpdateWinToolkit_Main.yml`: Pipeline for verifying the main branch
    - `Create_Release.yml`: Workflow for release creation and notes generation
    - `Release_Wintoolkit.yml`: Pipeline for creating release branches and merging to main
    - `security.yml`, `stale.yml`: Maintenance workflows
- **scripts/**: PowerShell scripts for build and test automation
    - `Update-Version.ps1`: Project version management
    - `Invoke-Build.ps1`: Official compiler wrapper with compression statistics
    - `Test-CompiledScript.ps1`: Post-compilation validation (syntax, functions, menu, size, encoding)
    - `New-ReleaseNotes.ps1`: Release notes generation
- **tests/**: Automated project tests
    - `WinToolkit.Tests.ps1`: Pester 5 test suite for module and feature validation
    - **Unit/**: Unit tests for individual modules (VideoDriver, GamingToolkit, WinCleaner)
    - **Integration/**: Integration tests (Build.Tests.ps1)
- **linters/**: PSScriptAnalyzer configuration
- **Docs/**: Official project documentation
- **ISSUE_TEMPLATE/**: GitHub issue templates
    - `bug_report.yml`: Bug report template
    - `enhancement.yml`: Enhancement template
    - `feature_request.yml`: New feature request template
- **CODE_OF_CONDUCT.md**: Community code of conduct
- **CONTRIBUTING.md**: Contribution guidelines
- **pull_request_template.md**: Pull Request template
- **CODEOWNERS**: Codebase owners

#### Root Files

| File                      | Role                                                            |
| ------------------------- | --------------------------------------------------------------- |
| `version.json`            | Single source of truth for version and build number             |
| `WinToolkit-template.ps1` | Base template with core functions, logging, and UI (MODIFIABLE) |
| `WinToolkit.ps1`          | Final compiled distributable file (AUTO-GENERATED)              |
| `compiler.ps1`            | Official build system with tokenizer and safe minification      |
| `WinToolkit_GUI.ps1`      | WPF graphical interface version                                 |
| `start.ps1`               | Official entry point for one-liner distribution                 |
| `start-offline.ps1`       | Startup mode without internet connection                        |
| `TODO.md`                 | Tasks and future development                                    |

---

## Compiled Version Testing

After making changes, you must test the compiled version of WinToolkit before opening a Pull Request. Two completely independent test modes are available.

---

### 🟢 Mode 1: Automatic Testing via GitHub Workflows (Recommended)

This mode uses the same official build pipeline directly in your fork, ensuring your code works exactly as in the main repository.

#### ✅ Prerequisites

1. Fork of the WinToolkit repository on your GitHub account
2. `Dev` branch present and up to date in your fork
3. No restrictions on GitHub Actions in your fork

#### 🔄 Pipeline Triggers

The pipeline triggers automatically on:

- **Push to Dev** → Full pipeline: lint → test → build
- **Push to BUG/**, ENHANCEMENT/**, FEATURE/** → Lightweight pipeline: lint → test → build → commit
- **PR to Dev** → Quality gate: lint → test (no build, no deploy)

Triggers are limited to files:

- `tools/*.ps1`
- `WinToolkit-template.ps1`
- `compiler.ps1`
- `start-offline.ps1`
- `start.ps1`
- `.github/workflows/*.yml`
- `.github/tests/*.ps1`
- `.github/scripts/*.ps1`

#### 🛡️ PR Security Guard — Three-Level Policy

Every PR to Dev is automatically analyzed by a three-level security system:

**Level 1 — Allowed (silent)**

- Files in `tools/*`
- `WinToolkit.ps1` (maintainers only)
- ✅ PR proceeds normally without intervention

**Level 2 — Allowed with Warning (manual review)**

- `start.ps1`, `WinToolkit_GUI.ps1`, `WinToolkit-template.ps1`, `assets/*`
- ⚠️ PR remains open, a warning comment is added for the maintainer

**Level 3 — Protected (full block)**

- All other files (`.github/**`, `compiler.ps1`, etc.)
- ⛔ PR closed automatically with access denied comment

> [!WARNING]
> **Rule for external contributors**: You can propose changes **exclusively** to modules in the `tools/` folder. For changes to core files (compiler, CI/CD workflows, build scripts), open an **Issue** describing the proposal.

#### 📋 Setup Steps

1. Go to your fork's page on GitHub
2. Navigate to **Settings > Actions > General**
3. Set **Actions permissions** to `Allow all actions and reusable workflows`
4. Enable **Read and write permissions** in the Workflow permissions section
5. Save changes

#### 🔄 Execution Commands

```bash
# 1. Make sure you are on the Dev branch
git checkout Dev

# 2. Make your changes to modules in /tools/ or the template

# 3. Commit and push directly to the Dev branch of your fork
git add .
git commit -m "- Description of changes"
git push origin Dev
```

#### ⚙️ Automatic Operation

As soon as you push:

1. The `CI_UpdateWinToolkit_Dev.yml` workflow will start automatically
2. The following will run **in your fork**:
    - ✅ Security check on changes (3-level PR Security Guard)
    - ✅ Full linting with PSScriptAnalyzer
    - ✅ Pester 5 test suite (module and feature validation)
    - ✅ AST syntax validation (compiler.ps1 and template)

> [!IMPORTANT]
> **Fundamental Note**: The push pipeline runs lint, test, and build. Official versioning happens exclusively through the `Create_Release.yml` workflow (manually triggered). In forks, the build jobs commit the generated `WinToolkit.ps1` file.

#### ✅ Verify Results

1. Go to the **Actions** tab of your fork
2. Check that the workflow completed successfully (✅)
3. If all checks pass, your code is valid and compatible
4. To get the compiled `WinToolkit.ps1` file, use **Mode 2 Offline**
5. When you open the PR to the official repository, the entire pipeline will run automatically

> [!Tip]
> If the workflow fails, consult the detailed logs to identify the error. The security checks will automatically block PRs that modify files outside the `/tool` folder.

---

### 🔵 Mode 2: Local Offline Test with compiler.ps1

This mode allows you to compile and test WinToolkit completely offline without needing to push to GitHub.

#### ✅ System Prerequisites

- Windows 10 1809+ / Windows 11 22H2+
- PowerShell 5.1 or PowerShell 7+
- Administrator Privileges
- No external dependencies required

#### 📋 Execution Steps

1. Open PowerShell as Administrator
2. Navigate to the repository root folder:

```powershell
cd C:\Path\To\WinToolkit
```

3. Run the official compiler:

```powershell
.\compiler.ps1
```

#### ⚙️ Compilation Phases

The compiler will automatically perform these operations:

1. Prerequisite and folder structure validation
2. Template loading and all modules from `/tools/`
3. Automatic injection of each function into the template
4. Safe minification via official PowerShell parser
5. Final file syntax verification
6. Statistics dashboard generation

#### ✅ Verify Results

At the end of compilation, a report will be displayed with:

- Number of modules processed
- Source size vs final size
- Compression percentage
- Total compilation time

To test the generated file:

```powershell
# Run the compiled file directly
.\WinToolkit.ps1
```

> [!Note]
> In case of errors during compilation, the compiler will display the exact error point and automatically restore the previous state. No corrupted file will be generated.

---

## 🏷️ Pull Request Category Tags

> [!IMPORTANT]
> **Mandatory: Use the correct tags**
>
> When opening a Pull Request, it is essential to categorize it correctly using one of the supported tags.
> Tags allow the maintainer to quickly identify the nature of the change and manage PRs in an orderly manner.
> Incorrect use of tags results in the PR being rejected or deferred until corrected.

### Supported Tags

| Tag           | Category                     | Description                                                                                                       |
| ------------- | ---------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `BUG`         | Bug Fixes                    | Fix for an error or faulty behavior already present in the code. The PR must reference an existing issue.         |
| `ENHANCEMENT` | Feature Improvement          | Modification or improvement of an existing function that increases its quality, speed, or robustness.             |
| `FEATURE`     | New Feature Addition         | Implementation of a new feature previously requested and not yet available in the toolkit.                        |
| `GUI`         | GUI Modification             | Any change to the graphical interface (`WinToolkit_GUI.ps1`) or visual components of the toolkit.                 |
| `Changes`     | External Contributor Changes | Change proposed by an external collaborator not part of the direct development team. Reserved for the maintainer. |

### How to Use Tags

Place the tag at the beginning of the Pull Request title, separated by a `/` or `-` from the description:

```
BUG/fixed crash in WinCleaner during Temp folder cleanup
ENHANCEMENT/optimized sorting algorithm in GamingToolkit
FEATURE/added automatic backup option in WinBackupDriver
GUI/adjusted main window layout of WinToolkit_GUI
Changes/external contributor added new utility script
```

> [!TIP]
> The tag also serves as the branch prefix (e.g., `BUG/fix-name`). You can add a sub-prefix after the tag if needed (e.g., `BUG/fix/fix-name`) but it is **not required**.
> The CI pipeline recognizes both formats and processes the PR correctly.

---

## Commit Standards

### Requirements for Commit Messages

Every commit must follow this structure:

- **Bulleted description** of the changes made.
- **Clear and concise**: maximum 72 characters for the first line.
- **In Italian** to maintain consistency with the project.

### Valid Commit Examples

```bash
# Examples of correct commits
- Added log export function in WinExportLog.ps1.
- Fixed bug in environment variable parsing.
- Implemented support for Windows 11 24H2.
- Optimized cleanup algorithm in `WinCleaner.ps1`.
- Updated documentation for global variables.
```

---

## Bug Reporting

### Bug Reporting Procedure

> [!Note]
> **Useful Information for Resolution**
>
> In case of a bug fix, it is **strongly recommended** to attach the `.zip` file of logs obtained through the toolkit's **"Export Log"** function. This significantly speeds up the debugging and resolution process.

### Information to Include

When reporting a bug, include:

1. **Clear description** of the problem.
2. **Steps to reproduce** the bug.
3. **Expected output** vs **actual output**.
4. **Log .zip file** (if applicable).
5. **Windows operating system version** in use.
6. **WinToolkit version** used.

---

## Milestone Management

### Milestone Types

The project uses two main categories for task management:

| Milestone   | Description                                                         | Type         |
| ----------- | ------------------------------------------------------------------- | ------------ |
| **Dev**     | Working branch for development, testing, and continuous integration | PR Target    |
| **main**    | Distribution branch, contains only compiled `WinToolkit.ps1`        | Release      |
| **Backlog** | Complex issues, new features, architectural discussions             | Low Priority |

### Assignment Criteria

- **Dev**: All contributions go to this branch. Development and testing happen here.
- **main**: Protected branch. The compiled output (`WinToolkit.ps1`) is committed here via release.
- **Backlog**: Complex feature requests, significant refactoring, discussions requiring thorough evaluation.

---

## Quick Steps to Contribute

### Step 1: Fork the Repository

1. Go to [MagnetarMan/WinToolkit](https://github.com/MagnetarMan/WinToolkit)
2. Click the **"Fork"** button in the top right corner
3. Select your GitHub account as the destination

### Step 2: Clone the Fork Locally

```bash
git clone https://github.com/YOUR_USERNAME/WinToolkit.git
cd WinToolkit
```

### Step 3: Configure the Upstream Remote

```bash
git remote add upstream https://github.com/MagnetarMan/WinToolkit.git
```

### Step 4: Create the Working Branch

```bash
git checkout Dev
git pull upstream Dev
git checkout -b BUG/name-of-fix
```

> [!TIP]
> **Branch patterns supported by the pipeline**:
>
> - `BUG/*` → Lightweight pipeline (lint + test + build)
> - `ENHANCEMENT/*` → Lightweight pipeline (lint + test + build)
> - `FEATURE/*` → Lightweight pipeline (lint + test + build)
> - `GUI/*` → Lightweight pipeline (lint + test + build)
> - `Changes/*` → Lightweight pipeline (lint + test + build)
> - `Dev` → Full pipeline (lint + test + build)
>
> Branch names must follow these patterns to automatically trigger CI.

### Step 5: Make the Changes

> [!Note]
> **NOTE: Remember the Development Logic**
>
> - Modify scripts in `/tools/*.ps1` for features.
> - Modify `WinToolkit-template.ps1` for global variables.
> - **NEVER touch `WinToolkit.ps1`**.

### Step 6: Commit the Changes

```bash
git add .
git commit -m "- Clear description of the change
- Second point if needed"
```

### Step 7: Push and Pull Request

```bash
git push origin BUG/name-of-fix
```

1. Go to GitHub in **your** forked repository.
2. Click **"Compare & pull request"**.
3. Make sure the base branch is **`DEV`** (not `main`!).
4. Fill in the PR template with all required details.
5. Click **"Create pull request"**.

---

## Additional Resources

- **Official Documentation**: [README.md](/README.md).
- **Changelog**: [CHANGELOG.md](/CHANGELOG.md).
- **Issue Tracker**: [Issues](https://github.com/MagnetarMan/WinToolkit/issues).

---

## **Thank you for contributing to WinToolkit!**

Your contribution is essential for improving this tool for the entire community.
