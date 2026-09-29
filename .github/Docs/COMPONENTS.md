# WinToolkit Components

WinToolkit is organised as a set of **tools**: independent modules that run one maintenance
operation each. Every tool lives in a single file under `tools/`, is compiled into
`WinToolkit.ps1`, and is offered as a menu entry in both the console script and the GUI.

> **How to read this page**
>
> Each entry lists the function that implements the tool, what it does step by step, and the
> parameters that change its behaviour. Operations that modify the system, remove data or
> change security settings are flagged with a warning.

## Quick reference

| # | Tool | Function | What it does |
|---|------|----------|--------------|
| 1 | Windows Repair | `WinRepairToolkit` | SFC / DISM / CHKDSK repair sequence |
| 2 | Windows Update Reset | `WinUpdateReset` | Rebuilds the update stack (services, cache, policies) |
| 3 | Store Repair | `WinReinstallStore` | Reinstalls Microsoft Store, WinGet, UniGet UI |
| 4 | Driver Backup | `WinBackupDriver` | Exports third-party drivers to a ZIP on the Desktop |
| 5 | Delete User Profiles | `WinDeleteUserProfiles` | Removes unused local profiles and residual folders |
| 6 | Cleaner | `WinCleaner` | Deep cleanup through a rule engine (40+ rules) |
| 7 | Debloat | `WinDebloat` | *Placeholder — no service is currently disabled* |
| 8 | Video Driver Install | `AutoVideoDriverInstall` | Detects the GPU vendor and launches its installer |
| 9 | Video Driver Reinstall | `VideoDriverReinstall` | Reinstalls drivers via DDU in Safe Mode |
| 10 | Office Install | `Install-Office` | Installs Office Basic through the ODT |
| 11 | Office Repair | `Repair-Office` | Click-to-Run quick repair, with online fallback |
| 12 | Office Uninstall | `Uninstall-Office` | Removes Office via GetHelpCMD, or directly on older builds |
| 13 | Gaming | `GamingToolkit` | Installs runtimes, game clients, and tunes the system |
| 14 | BitLocker | `DisableBitlocker` | Decrypts the system drive and blocks re-encryption |
| 15 | Diagnostic Logs | `WinExportLog` | Bundles session logs into a ZIP on the Desktop |

> [!TIP]
>
> The names above are the internal function names. The user-facing entry points are the
> menu options in the script and in the GUI.

> [!WARNING]
>
> **WinDebloat is a placeholder.** The tool loads and runs, but its service list is empty and
> the stop/disable logic is commented out, so it currently changes nothing. It is documented
> here to match the menu entry, not because it performs work.


---

## Windows section

### Windows Repair Toolkit

`WinRepairToolkit` · `tools/WinRepairToolkit.ps1`

Runs an ordered sequence of Microsoft maintenance commands, each one executed and checked
before moving to the next:

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `chkdsk /scan /perf` | Online, non-invasive disk check |
| 2 | `sfc /scannow` | System File Checker (first pass) |
| 3 | `DISM /Online /Cleanup-Image /RestoreHealth` | Repairs the Windows component store |
| 4 | `DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase` | Drops superseded update versions |
| 5 | `sfc /scannow` | Re-verify after the image was repaired |
| 6 | `chkdsk /f /r /x` | Thorough, offline disk repair (non-critical step) |

`/ResetBase` is the significant one: it permanently discards every superseded Windows update,
which frees space but means previously installed updates can no longer be uninstalled.

The `Scannow` logs are saved in the toolkit folder for later inspection, and failed steps are
retried up to `-MaxRetryAttempts` before giving up.

> [!NOTE]
>
> Run the script. After the computer restarts, the system will automatically enter in **Safe Mode**.
>
> Once you have finished your work, such as removing obsolete drivers with DDU, you will find a file named "Switch To Normal Mode.bat" on your desktop. To return to the standard Windows boot mode, double-click this file and restart the computer normally.

| Parameter | Default | Effect |
|-----------|---------|--------|
| `-MaxRetryAttempts` | `3` | How many times a failing step is retried |
| `-CountdownSeconds` | `30` | Seconds before the suggested restart |
| `-SuppressIndividualReboot` | off | Lets the caller own the reboot |

### Windows Update Reset

`WinUpdateReset` · `tools/WinUpdateReset.ps1`

Rebuilds the Windows Update stack from the bottom up, which is the standard fix when updates
stop showing or fail to install. It touches more than the services: caches, policies and
the update registry keys are reset as well.

- **Services**: stops and reconfigures `wuauserv`, `BITS`, `UsoSvc`, `WaaSMedicSvc` and
  `gpsvc`, then restores the correct startup types (`wuauserv` and `BITS` automatic,
  `UsoSvc` and `WaaSMedicSvc` manual).
- **Caches**: clears the SoftwareDistribution download cache and the Group Policy cache
  (`...\WindowsUpdate\UpdatePolicy\GPCache`).
- **Policies**: removes the whole `...\Policies\Microsoft\Windows\WindowsUpdate` key, then
  rewrites the automatic-update policy (`NoAutoUpdate = 0`, `AUOptions = 3`).
- **Side effects**: also clears device-metadata and driver-searching policy values that can
  block legitimate driver installation.

> [!WARNING]
>
> This tool deletes update-related registry keys and caches. Custom update policies
> (WSUS, deferral windows, metered restrictions) are removed and must be reconfigured.

### Windows Store Repair

`WinReinstallStore` · `tools/WinReinstallStore.ps1`

Reinstalls the graphical app-management layer from the Microsoft Store package and from WinGet.
Useful when the Store is broken, when WinGet is missing, or after an update left them in a
non-functional state. UniGet UI is reinstalled as a graphical front-end over WinGet.

> [!NOTE]
>
> On Windows 11 22H2 or earlier versions, WinToolkit will recommend running the WinGet repair function first. This step is necessary because versions of Windows 11 prior to build 22H2 often have incomplete or non-functional versions of winget.

---

## Office section

### Install Office

`Install-Office` · `tools/Install-Office.ps1`

Installs the **Basic** Office experience through the official **Office Deployment Tool**
(ODT): the ODT is downloaded, a configuration file selects the Basic product and the
architecture, and the deployment is executed headlessly. The post-install configuration is
applied afterwards.

### Repair Office

`Repair-Office` · `tools/Repair-Office.ps1`

Repairs an existing installation through the **Click-to-Run** stack. The **Quick Repair**
(offline) path is attempted first because it is fast and works without a network; if it does
not resolve the problem, the tool falls back to **Online Repair**, which re-downloads the
whole product.

### Uninstall Office

`Uninstall-Office` · `tools/Uninstall-Office.ps1`

Removes the whole suite. The strategy depends on the Windows build:

- **Windows 11 23H2 and later**: the official **GetHelpCMD** utility is downloaded and used.
  It is Microsoft's supported removal path and correctly cleans the shared Click-to-Run
  components.
- **Earlier builds**: falls back to `Remove-OfficeDirectly`, which stops the Office services,
  removes the Click-to-Run configuration and deletes the residual product keys and folders
  left behind by a manual uninstall.

> [!WARNING]
>
> Removes all Office products and their data. Export anything you need from Outlook and
> OneDrive before running it.


---

## System Maintenance

### Win Backup Driver

`WinBackupDriver` · `tools/WinBackupDriver.ps1`

Backs up the third-party drivers currently installed on the machine:

1. `dism /Online /Export-Driver` exports the filtered driver set to a staging folder. The
   export runs under a monitored timeout, and a non-zero exit code aborts the backup.
2. A portable 7-Zip is installed if needed and used to compress the folder.
3. The resulting archive is moved to the Desktop with a timestamped name.

Useful before a major driver change, or when reinstalling Windows on a machine whose OEM
drivers are no longer available.

### Delete User Profiles

`WinDeleteUserProfiles` · `tools/WinDeleteUserProfiles.ps1`

Removes local user profiles that are no longer in use, reclaiming the disk space they hold
in `C:\Users`. It is a two-phase cleanup:

1. **Registered profiles** are queried through `Win32_UserProfile`, and every profile that is
   unloaded and eligible is removed together with its `ProfileList` registry key.
2. **Residual folders** left in `C:\Users` — directories no longer associated with any
   profile in the registry or in CIM — are deleted.

**Safety rules built into the tool:**

- the **current user** and their profile are always excluded;
- these names are always protected: `Public`, `Pubblica`, `Default`, `Default User`,
  `All Users`, `defaultuser0`, `WDAGUtilityAccount`, `Administrator`, `Guest`, plus the
  current user and profile folder (the English and Italian names are both covered);
- a profile that is currently **loaded** is never touched.

| Parameter | Default | Effect |
|-----------|---------|--------|
| `-MinimumProfileAgeDays` | `0` | Only remove profiles unused for at least N days |
| `-UsersRoot` | `C:\Users` | Root path to scan |
| `-MaxThreads` | `min(2, CPU)` | Parallel runspaces, capped at 4 by `Win32_UserProfile` |
| `-SkipResidualFolderCleanup` | off | Stops after phase 1, leaving folders untouched |

> [!WARNING]
>
> **This permanently deletes profile data.** Documents, saved games, browser profiles and any
> software storing data under the user folder are lost with it. It is also the one tool
> guarded by an extra confirmation at menu level (`Confirm-UserProfileDeletion`).
>
> Use `-MinimumProfileAgeDays` to protect profiles that were used recently.

### Cleaner Toolkit

`WinCleaner` · `tools/WinCleaner.ps1`

The largest tool in the project: a **rule engine** that applies 40+ cleanup rules, grouped by
the type of action they perform.

| Rule type | Count | What it drives |
|-----------|-------|----------------|
| `File` | 18 | Path-based cleanup (caches, temp folders, leftovers) |
| `Custom` | 10 | Multi-step operations, written as script blocks |
| `Command` | 7 | Calls external tools such as `cleanmgr` and `DISM` |
| `Registry` / `RegSet` / `DWORD` | 6 | Registry value and key removal |
| `Service` | 2 | Print spooler and other service handling |
| `ScriptBlock` | 3 | Free-form PowerShell cleanup |

The rules cover, among others: Chromium browser caches (Chrome, Edge, Brave, Vivaldi), Firefox
cache, Opera and Java caches, Explorer thumbnail cache, Windows Prefetch, the Windows Update
cache, SRUM data, system and component logs, error reports, temporary internet files and
cookies, the Credential Manager, **system restore points**, the print spooler queue, and
Google Chrome's on-device AI model.

Every action is recorded, and the session ends with a summary grouped by outcome, listing any
rule that produced a warning or an error.

> [!WARNING]
>
> **Destructive.** The rules delete caches, logs and traces, clear the Credential Manager,
> remove restore points and empty the Recycle Bin. They are not individually reversible.
> System restore points and browser data included.

### WinDebloat

`WinDebloat` · `tools/WinDebloat.ps1`

> [!WARNING]
>
> **Placeholder — currently performs no change.** The service list is empty and the
> `Stop-Service` / `Set-Service -StartupType Disabled` logic is commented out as
> `PLACEHOLDER` in the source. The tool opens its session, iterates over an empty list and
> reports success without touching the system.

The intended design, visible in the code, is a declarative list of services to disable:

```powershell
# @{ Name = 'DiagTrack'; Description = 'Telemetria'; Action = 'Stop' }
```

Populating that array is all that is needed to make the tool functional.


---

## Video Drivers

### Video Driver Install

`AutoVideoDriverInstall` · `tools/AutoVideoDriverInstall.ps1`

Detects the GPU vendor and fetches the matching official installer to the Desktop, so the user
can run it interactively:

- **AMD**: downloads the *AMD Auto-Detect Tool* (`AMD-Autodetect.exe`), which identifies the
  exact GPU model and fetches the matching driver.
- **NVIDIA**: downloads the corresponding NVIDIA setup package.
- **Intel**: handled on the same path.

Rather than forcing a driver change, the tool prepares the correct installer and hands over:
a wrong or mismatched driver is one of the most common causes of instability, so the decision
to install is left to the user.

> [!NOTE]
>
> On Windows 11 22H2 or earlier versions, WinToolkit will recommend running the WinGet repair function first. This step is necessary because versions of Windows 11 prior to build 22H2 often have incomplete or non-functional versions of winget.

### Video Driver Reinstall

`VideoDriverReinstall` · `tools/VideoDriverReinstall.ps1`

A clean-slate reinstall, intended for a corrupted or unstable driver:

1. **DDU (Display Driver Uninstaller)** is downloaded as a ZIP and extracted to the Desktop.
2. The detected vendor installer is downloaded to the Desktop as well.
3. The system is restarted into **Safe Mode**, where DDU can unload the driver cleanly — the
   only context where a complete removal is actually possible.
4. A "Switch To Normal Mode.bat" file is placed on the Desktop to leave Safe Mode afterwards.

Because the workflow continues **outside** the script, it is the longest manual step in
WinToolkit: run DDU, restart, install the new driver, then run the .bat.

> [!WARNING]
>
> Reboots into Safe Mode and requires manual steps to complete. Do not interrupt the process
> between the Safe Mode restart and the driver installation.

---

## Gaming

### Gaming Toolkit

`GamingToolkit` · `tools/GamingToolkit.ps1`

Prepares a Windows machine for gaming in four steps:

1. **Runtimes**: installs DirectX, .NET and the Visual C++ Redistributables that most games
   require, via `winget`.
2. **Game clients**: installs the common launchers — `Valve.Steam`, `EpicGames.EpicGamesLauncher`,
   `GOG.Galaxy`, `Amazon.Games`, `ElectronicArts.EADesktop` and `Playnite.Playnite`.
3. **Xbox layer**: reinstalls the Xbox Game Bar and the Xbox App from their Store package IDs
   (`9NZKPSTSNW4P`, `9MV0B5HZVK9Z`).
4. **System tuning**:
   - enables the **Ultimate Performance** power plan, duplicating the built-in scheme by GUID
     (`e9a42b02-d5df-448d-aa00-03f14749eb61`) when it is not already present;
   - disables **Do Not Disturb**;
   - removes leftover desktop shortcuts for Steam, Battle.net and GOG Galaxy, and stops their
     background processes so nothing interferes with a full-screen game.

| Parameter | Default | Effect |
|-----------|---------|--------|
| `-CountdownSeconds` | `30` | Seconds before the suggested restart (0–300) |

---

## Security

### BitLocker Toolkit

`DisableBitlocker` · `tools/DisableBitlocker.ps1`

Decrypts the system drive and reduces the chance of it silently coming back:

1. Reads the current BitLocker state with `manage-bde.exe -status C:`. If the volume is not
   protected, the tool reports it and stops without changing anything.
2. If it is active, runs `manage-bde.exe -off C:`, which starts **controlled decryption** —
   the volume stays usable while the data is decrypted in the background.
3. Writes a registry value under `HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker` and the
   policy key `HKLM:\SOFTWARE\Policies\Microsoft\FVE` to help counter a hidden reactivation
   by Windows.

The exit code of `manage-bde` is checked; a non-zero value is reported rather than treated as
success, since it also covers the already-disabled and error cases.

> [!WARNING]
>
> **Reduces the protection of the system drive.** Device encryption and data-at-rest
> protection are lost, and any recovery key held for the volume should be destroyed once
> decryption has completed.

---

## Diagnostics

### Export Diagnostic Logs

`WinExportLog` · `tools/WinExportLog.ps1`

Collects the log files produced during the sessions and bundles them into a timestamped
`WinToolkit_Logs_<yyyyMMdd_HHmmss>.zip` archive, then places it on the Desktop. This is the
recommended artifact to attach when reporting an issue: it contains the session transcripts
needed to diagnose it.

---

## Repository layout

The tools are compiled together with the framework modules into a single distributable file.

| Path | Role |
|------|------|
| `tools/` | The 15 tools documented on this page, one function per file |
| `start-modules/` | Setup modules for `start.ps1` (bootstrapping, winget, environment, localisation) |
| `wintoolkit-modules/` | Runtime modules for the toolkit (UI, logging, processes, menu, office, winget) |
| `start.ps1` | Installer / first-run entry point |
| `start-core.ps1` | Shared core compiled into the main script |
| `WinToolkit.ps1` | **Generated artefact** — the compiled distribution, do not edit by hand |
| `WinToolkit_GUI.ps1` | The graphical front-end |

`WinToolkit.ps1` is produced by the build pipeline from `tools/` and `wintoolkit-modules/`:
changes belong in the sources, never in the generated file.

## Notes

> [!NOTE]
>
> Every tool that changes system state offers an interactive confirmation and, where
> relevant, a reboot countdown. The countdown can be tuned with `-CountdownSeconds`, and
> automatic reboots can be suppressed with `-SuppressIndividualReboot`.
>
> The script also performs an OS compatibility check on startup: Windows 11 and Windows 10
> are fully supported, Windows 8.1 has partial compatibility, and older releases are
> rejected unless the user explicitly chooses to continue at their own risk.
>
> Tool output goes through a localisation layer (`Get-SourceTextLoc`), so user-facing text is
> available in multiple languages and extracted from the source at build time.

> [!TIP]
>
> Run `WinExportLog` after a problem occurs and attach the resulting archive when opening an
> issue.

---

← Back to [README.md](../../README.md)


