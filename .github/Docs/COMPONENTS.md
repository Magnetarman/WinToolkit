# WinToolkit Components

WinToolkit groups its features into functional **toolkits**. Each one is an independent
module that gets compiled into the final `WinToolkit.ps1`, and can be run on its own.

## Quick reference

| # | Toolkit | Function | What it does |
|---|---------|----------|--------------|
| 1 | Windows Repair | `WinRepairToolkit` | SFC / DISM / CHKDSK repair cycles |
| 2 | Windows Update Reset | `WinUpdateReset` | Resets the update services and components |
| 3 | Office Install | `Install-Office` | Installs a "Basic" Microsoft Office |
| 4 | Office Repair | `Repair-Office` | Quick offline or full online repair |
| 5 | Office Uninstall | `Uninstall-Office` | Full removal via the official GetHelpCMD tool |
| 6 | Store Repair | `WinReinstallStore` | Reinstalls Microsoft Store, WinGet, UniGet UI |
| 7 | Driver Backup | `WinBackupDriver` | Exports installed third-party drivers via DISM |
| 8 | Debloat | `WinDebloat` | Disables and optimises telemetry services |
| 9 | Cleaner | `WinCleaner` | Deep cleanup of files, registry and services |
| 10 | Video Driver Install | `AutoVideoDriverInstall` | Installs and configures GPU drivers |
| 11 | Video Driver Reinstall | `VideoDriverReinstall` | Reinstalls drivers with a previous-driver cleanup |
| 12 | Gaming | `GamingToolkit` | Optimises the system for gaming |
| 13 | BitLocker | `DisableBitlocker` | Controlled decryption of the system drive |
| 14 | Diagnostic Logs | `WinExportLog` | Bundles the session logs into a ZIP on the Desktop |

> [!TIP]
>
> The entry points above are the internal function names. The user-facing entry points are
> the menu options exposed by the script and by the GUI; see [Notes](#notes) at the end of
> this page.

---

## Windows section

### Windows Repair Toolkit

`WinRepairToolkit`

Runs an automated sequence of standard Windows commands — `SFC`, `DISM` and `CHKDSK` — to
detect and repair system file corruption and disk issues. Repair attempts are retried, and a
deep disk repair can be started separately.

> [!NOTE]
>
> Run the script. After the computer restarts, the system will automatically enter in **Safe Mode**.
>
> Once you have finished your work, such as removing obsolete drivers with DDU, you will find a file named "Switch To Normal Mode.bat" on your desktop. To return to the standard Windows boot mode, double-click this file and restart the computer normally.

### Windows Update Reset

`WinUpdateReset`

Efficiently fixes common Windows Update issues by resetting the update components
(`wuauserv`, `bits`, `cryptsvc`, `trustedinstaller`, `msiserver`) and restoring the service
startup types and dependencies.

---

## Office section

### Install Office

`Install-Office`

Installs a "Basic" Microsoft Office version semi-automatically, then applies the
post-installation configuration.

### Repair Office

`Repair-Office`

Repairs an existing installation in **quick offline** mode or in **full online** mode,
depending on how thorough the repair needs to be.

### Uninstall Office

`Uninstall-Office`

Fully removes the suite from the system through the official **GetHelpCMD** tool
(formerly SaRA), which handles the removal of the shared components and the leftover
registry entries that a manual uninstall leaves behind.

---

## System Maintenance

### Windows Store Repair

`WinReinstallStore`

Reinstalls critical components such as Microsoft Store, WinGet, and UniGet UI. Useful when
the graphical app management layer is broken, or to update those tools to a working version.

### Win Backup Driver

`WinBackupDriver`

Simplifies driver backup by automating the export of all installed third-party drivers
through DISM, then compresses the result into an archive placed on the Desktop.

### WinDebloat

`WinDebloat`

Disables and optimises the services commonly used for telemetry, so that the system stops
reporting usage data and spends fewer resources in the background.

### Cleaner Toolkit

`WinCleaner`

Frees disk space and optimises performance through a deep cleanup. Each action is applied
through a **rule engine** that handles files, registry keys and services, and the outcome is
summarised at the end of the session.

---

## Video Drivers

### Video Driver Install

`AutoVideoDriverInstall`

Simplifies installation, updates, reinstallation, and optimal configuration of GPU drivers
for NVIDIA and AMD systems.

> [!NOTE]
>
> On Windows 11 22H2 or earlier versions, WinToolkit will recommend running the WinGet repair function first. This step is necessary because versions of Windows 11 prior to build 22H2 often have incomplete or non-functional versions of winget.

### Video Driver Reinstall

`VideoDriverReinstall`

Performs a clean driver replacement: it removes the previous driver, installs the new one,
and applies the same optimal configuration as the automatic install. Both toolkits also
block automatic driver updates from Windows Update, which are often a source of instability.

---

## Gaming

### Gaming Toolkit

`GamingToolkit`

Designed to quickly optimize your Windows PC for maximum gaming performance. It installs
essential components such as DirectX, .NET, and Visual C++ Redistributables; installs the most
common game clients such as Steam, Epic, and GOG; enables the "Ultimate Performance" power
plan; and disables interruptions with "Do not disturb" mode. In short, it prepares your
system for distraction-free gaming at full power.

---

## Security

### BitLocker Toolkit

`DisableBitlocker`

Starts an automated process to disable BitLocker encryption on the system drive (`C:`). The
tool checks the current state and, if BitLocker is active, runs the command to start
controlled volume decryption. It also adds a registry entry to help counter possible hidden
future reactivation attempts by Microsoft.

---

## Diagnostics

### Export Diagnostic Logs

`WinExportLog`

Collects the log files produced during the sessions and bundles them into a timestamped
`WinToolkit_Logs_<date>.zip` archive, then places it on the Desktop. This is the recommended
artifact to attach when reporting an issue.

---

## Notes

> [!NOTE]
>
> Every toolkit that changes system state offers an interactive confirmation and, where
> relevant, a reboot countdown. The countdown can be tuned with `-CountdownSeconds`, and
> automatic reboots can be suppressed with `-SuppressIndividualReboot`.
>
> The script also performs an OS compatibility check on startup: Windows 11 and Windows 10
> are fully supported, Windows 8.1 has partial compatibility, and older releases are
> rejected unless the user explicitly chooses to continue at their own risk.
>
> Run `WinExportLog` after a problem occurs and attach the resulting archive when opening
> an issue: it contains the session transcripts needed to diagnose it.

---

← Back to [README.md](../../README.md)

