<p align="center">
	<img src="images/WinToolkit-icon.png" alt="WinToolkit-banner" width="160">
	<h1>WinToolkit: Master Windows with <em>Ease</em></h1>
</p>
<p>
	<img src="https://img.shields.io/github/v/release/Magnetarman/WinToolkit?style=for-the-badge&label=version&color=brightgreen" alt="version">
	<img src="https://img.shields.io/github/downloads/Magnetarman/WinToolkit/latest/WinToolkit.ps1?style=for-the-badge&logo=github&logoColor=white&color=0080ff&label=Downloads" alt="downloads-main">
	<img src="https://img.shields.io/github/license/Magnetarman/WinToolkit?style=for-the-badge&logo=opensourceinitiative&logoColor=white&color=0080ff" alt="license">
</p>

<img src="images/Run.jpg" alt="Run-banner" width="800">

WinToolkit is a powerful and compact suite of PowerShell scripts, inspired by the outstanding work of [@ChrisTitusTech](https://github.com/ChrisTitusTech/) [Wintutil](https://github.com/ChrisTitusTech/winutil), designed to provide IT professionals, system administrators, and power users with granular yet automated control over the maintenance and troubleshooting of Windows and the Office suite. This intuitive toolkit brings together the most effective system repair tools in a single interface, automating complex processes to optimize performance and restore system stability in just a few automated steps. This project was translated using an AI-powered workflow.

---

## ⚙️ Minimum Requirements

> [!IMPORTANT]
> Before starting the toolkit, make sure you meet these requirements:
>
> - **Internet connection**;
> - **free disk space**: >= 50 GB [(see the FAQ section)](.github/Docs/FAQ.md);
> - **Windows >= 10 (1809)**.

| Windows Versions      | Supported    |
| :-------------------- | :----------- |
| Windows 11 >= 22H2    | 🟢 Yes       |
| Windows 10 >= 1809    | 🟢 Yes       |
| Windows 11 <= 21H2    | 🟡 Partially |
| Windows 10 <= 1809    | 🔴 No        |
| Windows 8.1           | 🔴 No        |
| Windows 8 and earlier | 🔴 No        |

## 🚀 How To Run WinToolkit

Install the WinToolkit executable on your desktop by following these steps:

1. Press the `Windows` key on your keyboard or open Windows Search.
2. Type `PowerShell` in the search field.
3. Copy and paste the following command into the PowerShell window:

```powershell
irm https://magnetarman.com/winstart | iex
```

6. After terminal window finish the jobs and auto-close itself, you will find the `Win Toolkit` shortcut on the desktop. Use it to start the script as administrator with a simple double-click.

### ⚙️ For Advanced Users

> [!WARNING]
> If you are starting WinToolkit from a partially supported Windows version, PowerShell 7 or later is recommended. This modern version is required for maximum compatibility, correct tool execution, and to prevent runtime errors or incorrect application of changes.

1. Install PowerShell 7 or later from the [Microsoft Store](https://www.microsoft.com/store/apps/9MZ1SNWT0N5D) or from [GitHub](https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-windows?view=powershell-7.5#msi).
2. Press the `Windows` key on your keyboard or open Windows Search.
3. Type `PowerShell` in the search field.
4. Right-click `PowerShell`.
5. Click `Run as administrator` from the drop-down menu.
6. Copy and paste the following command into the PowerShell window:

```powershell
irm https://magnetarman.com/WinToolkit | iex
```

### 👨‍💻 For Beta Testers

> [!CAUTION]
> Running development versions is **risky and may damage your system.** These builds include features that are still under development and/or testing. If you are unsure or do not know what you are doing, use the recommended execution path.

```powershell
irm https://magnetarman.com/winstart-dev | iex
```

## 🪟 GUI - Graphical Interface

> [!CAUTION]
> The GUI version is available as an ALPHA build, so it may change significantly. This version is highly unstable; use it at your own risk.

```powershell
irm https://magnetarman.com/Wintoolkit-gui | iex
```

## 🌐 Languages

WinToolkit uses the PowerShell 7 script internationalization layout. To add a new language, create a culture folder under `languages`, for example `languages\fr-FR`, then add `WinToolkit.psd1` inside it. Copy the schema from `languages\en-US\WinToolkit.psd1` or `languages\it-IT\WinToolkit.psd1`, translate the values, and keep `language.code` aligned with the folder name.

---

## 👾 [Components](.github/Docs/COMPONENTS.md)

---

## 📌 [Changelog](.github/Docs/CHANGELOG.md)

---

## 📽️ Talks About WinToolkit

| Channel Image                                                            | Link                                                                                                                          |
| :----------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------- |
| <img src="/images/avatar/zakkos.jpg" alt="Zakkos-WinToolkit" width="80"> | <a href="https://www.youtube.com/watch?v=nUKLeYqe1ZI"> WINTOOLKIT 2.5: Dominare Windows 11 con PowerShell by MagnetarMan </a> |

---

## 💀 Wintoolkit Genesis

<div align="center">

|                                                                 |                                                                                      |
| :-------------------------------------------------------------: | :----------------------------------------------------------------------------------: |
| <img src="images/Run-old.jpg" alt="Run-banner-Old" width="800"> | <img src="images/RepairToolkit-old.jpg" alt="Repair-Toolkit-banner-Old" width="800"> |

</div>

---

## 💖 Support The Project!

If WinToolkit has helped you, consider actively supporting the project through a donation, or you can [contribute](#-contribute).

### 👛 Make A Donation

Your donation is not only a thank-you, but a direct investment in the future and development of this tool.

To make a donation, click the Sponsor button in the top-right corner to learn how.

🚀 Continuous development: donations allow me to dedicate more time and resources to keeping the current version updated and compatible, and to implementing powerful new features.

🏆 Join the Hall of Fame: every donor will be included in a new dedicated section inside the contributors list as thanks for your valuable support.

---

## 🏗️ [Architecture And Development](.github/Docs/ARCHITECTURE.md)

> [!NOTE]
> This section is for **contributors and advanced users** who want to understand how WinToolkit works internally, how to modify it, or how to test changes before opening a PR.

> [!WARNING]
> WinToolkit uses a custom build system: sources live on the **`Dev`** branch and are automatically compiled by the CI pipeline into a single distributable file on **`main`**. End users clone `main` and get the toolkit ready to use for stable versions; contributors work on `Dev` with an unstable version of the script.

---

### 🔰 Contribute

If you cannot donate, you can still help me improve WinToolkit through these actions:

⭐ **Star the project**: starring the project helps it become more visible on GitHub.

> [!WARNING]
> Before opening pull requests or issues, [PLEASE READ THE GUIDE CAREFULLY](.github/Docs/PR_And_PullRequest.md).

🐛 **[Report an issue](https://github.com/Magnetarman/WinToolkit/issues)**: report a bug you found or request new features.

💡 **[Submit a pull request](https://github.com/Magnetarman/WinToolkit/pulls)**: submit your bug fix or your new feature.

💬 **[Join the Discussions](https://t.me/GlitchTalkGroup)**: share your ideas, provide feedback, or ask questions. **[IT Language Only, for now.]**

Thank you from the heart for your support!

---

## 🎉 Milestones

[![RepoStars](https://repostars.dev/api/embed?repo=Magnetarman%2FWinToolkit&theme=dark)](https://repostars.dev/?repos=Magnetarman%2FWinToolkit&theme=dark)

---

<!-- TOP_CONTRIBUTORS_START -->

## 👥 Top 10 Contributors

| Rank | Contributor                                                                                                                                                                                              | Commits | PRs |
| :--- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------ | :-- |
| 1    | <img src="https://avatars.githubusercontent.com/u/40738529?v=4" width="24" height="24" alt="Magnetarman" style="border-radius:50%;vertical-align:middle;"> [Magnetarman](https://github.com/magnetarman) | 2459    | 0   |
| 2    | <img src="https://avatars.githubusercontent.com/u/45762339?v=4" width="24" height="24" alt="pomodori92" style="border-radius:50%;vertical-align:middle;"> [pomodori92](https://github.com/pomodori92)    | 23      | 0   |

<!-- TOP_CONTRIBUTORS_END -->

---

## 🎗 Author

Created with ❤️ by [Magnetarman](https://magnetarman.com/).
