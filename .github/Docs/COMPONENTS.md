# WinToolkit Components

WinToolkit groups its features into several functional toolkits. Each one is an independent module compiled into the final `WinToolkit.ps1`.

- **Windows section**:
    - **Windows Repair Toolkit**: Runs an automated sequence of standard Windows commands, such as SFC, CHKDSK, and DISM, to detect and repair system file corruption and disk issues.
    - **Windows Update Reset**: Efficiently fixes common Windows Update issues by resetting key components and restoring service settings.
- **Office section**:
    - **Install Office**: Lets you install a "Basic" Microsoft Office version semi-automatically.
    - **Repair Office**: Repairs existing installations with either quick offline mode or full online mode.
    - **Uninstall Office**: Fully removes the suite from the system by using the official "GetHelpCMD" tool (formerly SaRA).
- **Windows Store Repair**: Reinstalls critical components such as Microsoft Store, WinGet, and UniGet UI, which is useful for updating and managing apps graphically through WinGet.
- **Win Backup Driver**: Simplifies driver backup by automating the export of all installed third-party drivers through DISM for a complete and reliable operation.
- **Cleaner Toolkit**: Frees disk space and optimizes performance through deep cleanup.
- **Video Driver Install**: Simplifies installation, updates, reinstallation, and optimal configuration of GPU drivers for NVIDIA and AMD systems. It also handles previous-driver cleanup and blocks automatic driver updates from Windows Update, which are often a source of instability.

> [!NOTE]
>
> Run the script. After the computer restarts, the system will automatically enter in **Safe Mode**.
>
> Once you have finished your work, such as removing obsolete drivers with DDU, you will find a file named "Switch To Normal Mode.bat" on your desktop. To return to the standard Windows boot mode, double-click this file and restart the computer normally.

- **Gaming Toolkit**: Designed to quickly optimize your Windows PC for maximum gaming performance. It installs essential components such as DirectX, .NET, and Visual C++ Redistributables; installs the most common game clients such as Steam, Epic, and GOG; enables the "Ultimate Performance" power plan; and disables interruptions with "Do not disturb" mode. In short, it prepares your system for distraction-free gaming at full power.

> [!NOTE]
>
> On Windows 11 22H2 or earlier versions, WinToolkit will recommend running the WinGet repair function first. This step is necessary because versions of Windows 11 prior to build 22H2 often have incomplete or non-functional versions of winget.

- **BitLocker Toolkit**: Starts an automated process to disable BitLocker encryption on the system drive (C:). The tool checks the current state and, if BitLocker is active, runs the command to start controlled volume decryption. It also adds a registry entry to help counter possible hidden future reactivation attempts by Microsoft.

---

← Back to [README.md](../../README.md)
