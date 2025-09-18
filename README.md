<p align="center">
	<img src="img/WinToolkit-icon.png" alt="WinToolkit-banner" width="160">
</p>
<br>
<p align="center">
	<em><code>🛠️ WinToolkit: La Soluzione Definitiva per SOPRAVVIVERE A WINDOWS.</code></em>
    <br>
    <br>
    <code>WinToolkit è una suite di script PowerShell potente e compatta, progettata per offrire a professionisti IT, amministratori di sistema e utenti esperti un controllo granulare sulla manutenzione e sulla risoluzione dei problemi di Windows. Questo toolkit intuitivo aggrega gli strumenti di riparazione di sistema più efficaci in un'unica interfaccia, automatizzando i processi complessi per ottimizzare le prestazioni e ripristinare la stabilità del sistema con pochi clic.</code>
</p>
<br>

<p align="center">
<img src="https://img.shields.io/badge/version-2.0.1 (Build 3)-dgreen.svg?style=for-the-badge" alt="versione">
<img src="https://img.shields.io/github/last-commit/Magnetarman/WinToolkit?style=for-the-badge&logo=git&logoColor=white&color=0080ff" alt="last-commit">
<img src="https://img.shields.io/github/languages/top/Magnetarman/WinToolkit?style=for-the-badge&color=0080ff" alt="repo-top-language">
<img src="https://img.shields.io/github/license/Magnetarman/WinToolkit?style=for-the-badge&logo=opensourceinitiative&logoColor=white&color=0080ff" alt="license">
</p>
</br>

## 👨‍💻 Status Commit Totali

|                                                                               Ramo Release                                                                                |                                                                                Ramo Dev                                                                                 |
| :-----------------------------------------------------------------------------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
| <p align="center"><img src="https://img.shields.io/github/commit-activity/t/MagnetarMan/WinToolkit/main?style=for-the-badge&color=0080ff" alt="Commit Activity Main"></p> | <p align="center"><img src="https://img.shields.io/github/commit-activity/t/MagnetarMan/WinToolkit/Dev?style=for-the-badge&color=CC0033" alt="Commit Activity Dev"></p> |

## 📸 ScreenShot

<div align="center">

|                                                                          |                                                                      |
| :----------------------------------------------------------------------: | :------------------------------------------------------------------: |
|       <img src="img/Starter.jpg" alt="Starter-banner" width="800">       |         <img src="img/Run.jpg" alt="Run-banner" width="800">         |
| <img src="img/RepairToolkit.jpg" alt="RepairToolkit-banner" width="800"> | <img src="img/UpdateReset.jpg" alt="UpdateReset-banner" width="800"> |

</div>

---

## 👾 Features

> [!Note]
> Ramo `main` <br> La versione 2.0 del Toolkit è in fase **RELEASE**.
>
> Ramo `Dev` <br> **Attenzione:** Avviare il Toolkit dal ramo `Dev` è **rischioso**. **Potrebbe causare danni al tuo sistema.**

> [!Tip]
> per far funzionare lo script nel ramo `Dev` basta scaricare il progetto, aprire PowerShell nella cartella principale e lanciare il file `compiler.ps1`. A quel punto farà tutto da solo: prende i vari pezzi di codice che si trovano nella cartella tool, li mette al posto giusto e crea il file finale `WinToolkit.ps1`, pronto per essere utilizzato. In pratica ti consegna direttamente la versione completa e ordinata del programma.

- **Interfaccia Intuitiva**: Nonostante la sua potenza, il toolkit presenta un menu interattivo e facile da usare, che guida l'utente nella scelta dello strumento più adatto per il problema.
- **Aggiornamenti Automatici**: Il tool può verificare e installare automaticamente l'ultima versione di PowerShell, assicurando che tutti gli script funzionino con le funzionalità più recenti e in modo efficiente.
- **Riparazione del Sistema Completa**: Avvia una sequenza automatizzata di comandi standard di Windows come sfc, chkdsk e DISM per individuare e correggere la corruzione dei file di sistema e i problemi del disco. Il tool esegue più tentativi e genera un log dettagliato sul desktop, garantendo una tracciabilità completa delle operazioni.
- **Ripristino di Windows Update**: Risolve in modo efficiente i problemi comuni di Windows Update resettando i componenti chiave e ripristinando le impostazioni dei servizi. Questo script blocca e riavvia i servizi di aggiornamento, rinomina le directory di cache e ripara il registro di sistema, garantendo che il tuo sistema possa scaricare e installare gli aggiornamenti essenziali senza intoppi.
- **Log Dettagliati**: Tutte le operazioni sono registrate in un file di log salvato nel percorso `%localappdata%\WinToolkit\logs` (Inserisci il percorso senza apici dopo aver digitato `esegui` nel menu start di windows per accedere alla cartella dei log), fornendo un riassunto chiaro e professionale delle azioni eseguite, degli errori riscontrati e dei risultati finali.

### Perché usare WinToolkit?

Sia che tu stia gestendo un parco macchine aziendale o che tu voglia semplicemente mantenere il tuo PC personale in perfette condizioni, WinToolkit ti permette di:

- **Risparmiare Tempo**: Automatizza ore di lavoro manuale di diagnostica e riparazione.
- **Prevenire Malfunzionamenti**: Esegui manutenzioni preventive per evitare problemi futuri.
- **Agire da Esperto**: Sfrutta la potenza degli strumenti di sistema professionali con un'interfaccia semplice e sicura.

---

## 📁 Struttura Cartelle

```sh
└── WinToolkit/
    └── img
        ├── WinToolkit-icon.png
        ├── RepairToolkit.jpeg
        ├── Run.jpeg
        └── Starter.png
    ├── LICENSE
    ├── README.md
    ├── start.ps1
    └── WinToolkit.ps1
```

### 📂 Index Progetto

<details open>
	<summary><b><code>WinToolKit</code></b></summary>
		<blockquote>
			<table>
				<tr>
					<td><b><a href='https://github.com/Magnetarman/WinToolkit/blob/main/start.ps1'>start.ps1</a></b></td>
					<td><code>❯ Script di Start. Installa tutto il necessario automaticamente per far funzionare al meglio il ToolKit, Crea una scorciatoia sul Dekstop per avviare il Toolkit ed infine riavvia il PC per apportare le modifiche.</code></td>
				<tr>
					<td><b><a href='https://github.com/Magnetarman/WinToolkit/blob/main/WinToolkit.ps1'>WinToolkit.ps1</a></b></td>
					<td><code>❯ All'interno di questo script sono contenute tutte le funzioni ed il codice del tool.</code></td>
				</tr>
				</tr>
			</table>
		</blockquote>
</details>

---

## 🚀 Getting Started

### ☑️ Prerequisiti

Prima di avviare il tool, assicurati che il tuo ambiente di Runtime soddisfi i seguenti requisiti:

- **Windows Defender** di 24H2 potrebbe rilevare come pericoloso questo script. **E' fortemente consigliata la disattivazione temporanea durante le operazioni**
- **Richiesta Connessione ad internet durante l'esecuzione del Tool**
- Richiesto intervento manuale minimo.
- **Spazio su disco necessario**: 50GB Liberi (Windows durante le operazioni di riparazione occuperà temporaneamente dello spazio. L'indicazione di 50GB è sovrastimata ed utile per avere un certo margine di spazio libero ulteriore per il corretto funzionamento del Sistema)

### ⚙️ Installazione per Neofiti _Consigliata_

Avvia il Toolkit eseguendo il seguente metodo:

1. Avvia Powershell in modalità Amministratore ed inserisci il comando per avviare lo script di start:

```powershell
 irm https://raw.githubusercontent.com/Magnetarman/WinToolkit/main/start.ps1 | iex
```

2. Al riavvio del tuo PC troverai la scorciatoia `Win Toolkit V2.0` sul desktop da cui avviare comodamente lo script in modalità amministratore.

### ⚙️ Installazione Classica

Avvia il Toolkit eseguendo il seguente metodo:

1. Clona la repository WinToolkit:

```powershell
 git clone https://github.com/Magnetarman/WinToolkit
```

2. Utilizza il terminale per Navigare fino alla cartella:

```powershell
 cd WinToolkit
```

3. Lancia il Toolkit:

```powershell
 ./WinToolkit.ps1
```

---

## 📌 Project Roadmap

- [x] **`V1.0`**: <strike>Release Privata</strike>
- [x] **`V1.1.0`**: <strike>Refactor Struttura in forma modulare.</strike>
- [x] **`V2.0.0`**: <strike>**RELEASE Pubblica**. Refator totale progetto per future implementazioni.</strike>
- [x] **`V2.0.0 (Build 68)`**: <strike> Funzione **Repair Toolkit** Completa.</strike>
- [x] **`V2.0.0 (Build 71)`**: <strike> Funzione **Update Reset** Completa.</strike>
- [x] **`V2.0.0 (Build 72)`**: <strike> Readme Rework, Rework Grafico Script.</strike>
- [x] **`V2.0.0 (Build 73)`**: <strike> Start Script Potenziato, Fix Tool "WinUpdate Reset".</strike>
- [x] **`V2.0.0 (Build 82)`**: <strike> Rework Grafico **WinToolkit.ps1**.</strike>
- [x] **`V2.0.1 (Build 3)`**: <strike> Ottimizzazione Script **WinReinstallStore.ps1**, **WinRepairToolkit.ps1**. Aggiornamento Readme.</strike>
- [ ] **`V2.1`**: Funzione **Office Toolkit** Completa.
- [ ] **`V2.2`**: Sezione **Windows Repair Plus** Completa.
- [ ] **`V2.3`**: Sezione **Driver & Gaming** Completa.
- [ ] **`V2.4`**: Sezione **Gaming Ready** Completa.
- [ ] **`V3.0.0`**: Finalizzazione "MagnetarMan Mode".

## 👌 Update Pianificati

### V2.1 - "Office Toolkit"

- [ ] Installazione Office Personalizzata tramite xml automatico (Versione Base con Solo Word, Excel, PowerPoint).
  - [ ] Riparazione Installazione Office corrotta e reinstallazione forzata.

### V2.2 - "Windows Repair Plus"

- [x] Reinstallazione Forzata Microsoft Store & Winget.
  - [x] Installazione di Uniget.
- [ ] Reset Rust Desk.
- [ ] Backup Driver Installati => Compressione in file .zip => Posizionamento archivio sul desktop.

### V2.3 - "Driver & Gaming"

- [ ] Scelta Driver Video (AMD/NVIDIA).
- [ ] Installazione Driver Ottimizzato (Nvidia).
- [ ] Download ultima versione di DDU.
  - [ ] Estrazione.
  - [ ] Posizionamento nella cartella Downloads.
  - [ ] Riavvio modalità provvisoria.

### V2.4 - "Gaming Ready"

- [ ] Installazione client di gioco (Amazon, Gog Galaxy, Epic Games, Steam).
- [ ] Installazione Playnite ed applicazione Tema personalizzato.
- [ ] Installazione/Aggiornamento Directx.
- [ ] Installazione/Aggiornamento Microsoft C++ Package.

### V2.5 - "Auto Debloat"

- [ ] Avvio script Chris con config personalizzata iwr -useb https://christitus.com/win | iex

### V2.6 - "Security Update"

- [ ] Aggiungere esecuzione di Tron Script ed esecuzione con intervento minimo

### V3.0 - "MagnetarMan Mode"

- [ ] Finalizzazione "MagnetarMan Mode"
  - [ ] Avvio Script Chris con configurazione personalizzata
  - [ ] Installazione Programmi
    - [ ] Brave Browser
    - [ ] Google Chrome
    - [ ] Betterbird
    - [ ] Fan Control
    - [ ] PowerToys
    - [ ] Uniget
    - [ ] Crystal Disk info
    - [ ] HwInfo
    - [ ] Rust Desk
    - [ ] Client Giochi (Amazon, Gog Galaxy, Epic Games, Steam)
  - [ ] Installazione .NET Runtime (Dalla 4 alla 9.0)
  - [ ] Installazione Microsoft C++ Package
  - [ ] Installazione/Aggiornamento Directx
  - [ ] Playnite (Lancher/Aggregatore)
  - [ ] Revo Unistaller
  - [ ] Tree Size
  - [ ] Glary Utilities
  - [ ] Pulizia Sistema
  - [ ] Applicazione Sfondo "MagnetarMan"
  - [ ] Riavvio PC per completare le modifiche

## 🕹️ TO DO

- [ ] Download immagine di Windows 23H2 Microwin
  - [ ] Posizionamento nella cartella download, pronta per essere utilizzata

---

## 🔰 Come Contribuire

- **💬 [Partecipa alle Discussioni](https://t.me/GlitchTalkGroup)**: Condividi le tue idee, fornisci feedback o fai domande.
- **🐛 [Segnala Problemi](https://github.com/Magnetarman/WinToolkit/issues)**: Segnala i bug trovati o richiedi nuove funzionalità per il progetto `WinToolkit`.
- **💡 [ Invia Pull Request](https://github.com/Magnetarman/WinToolkit/issues)**: Revisiona le Pull Request (PR) aperte e invia le tue.

<details closed>
<summary>Linee Guida</summary>

1. **Esegui il Fork della Repository**: Inizia facendo il "fork" della repository del progetto sul tuo account GitHub.
2. **Clona in Locale**: Clona la repository di cui hai fatto il fork sulla tua macchina locale usando un client Git.

```powershell
   git clone https://github.com/Magnetarman/WinToolkit
```

3. **Crea un Nuovo Branch**: Lavora sempre su un nuovo "branch", dandogli un nome descrittivo.

```powershell
git checkout -b new-feature-x
```

4. **Apporta le Tue Modifiche**: Sviluppa e testa le tue modifiche in locale.
5. **Esegui il Commit delle Tue Modifiche**: Fai il "commit" con un messaggio chiaro che descriva i tuoi aggiornamenti.

```powershell
  git commit -m 'Implementata nuova funzionalità x.'
```

6. **Esegui il Push su GitHub**: Fai il "push" delle modifiche sulla tua repository "fork".

```powershell
   git push origin nuova-funzionalita-x
```

7. **Invia una Pull Request**: Crea una "Pull Request" (PR) verso la repository originale del progetto. Descrivi chiaramente le modifiche e le loro motivazioni.
8. **Revisione**: Una volta che la tua PR sarà revisionata e approvata, verrà unita ("merged") nel branch principale. Congratulazioni per il tuo contributo!
</details>

---

## 🎗 Licenza

Creato con ❤️ da [Magnetarman](https://magnetarman.com/). Licenza MIT. Se trovi questo progetto utile, considera di lasciare una ⭐

---

## 🙌 Personalizzazioni

Segui le istruzioni che il tool ti comunicherà a video per personalizzare le funzioni.
