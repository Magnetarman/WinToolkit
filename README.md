<p align="center">
	<img src="img/WinToolkit-icon.png" alt="WinToolkit-banner" width="160">
</p>
<br>
<p align="center">
	<em><code>🛠️ WinToolkit: La Soluzione Definitiva per SOPRAVVIVERE A WINDOWS.</code></em>
    <br>
    <br>
    WinToolkit è una suite di script PowerShell potente e compatta, progettata per offrire a professionisti IT, amministratori di sistema e utenti esperti un controllo granulare sulla manutenzione e sulla risoluzione dei problemi di Windows e della Suite Office. Questo toolkit intuitivo aggrega gli strumenti di riparazione di sistema più efficaci in un'unica interfaccia, automatizzando i processi complessi per ottimizzare le prestazioni e ripristinare la stabilità del sistema con pochi passaggi automatizzati.
</p>
<br>
<p align="center">
<img src="https://img.shields.io/badge/version-2.2.2-dgreen.svg?style=for-the-badge" alt="versione">
<img src="https://img.shields.io/github/last-commit/Magnetarman/WinToolkit?style=for-the-badge&logo=git&logoColor=white&color=0080ff" alt="last-commit">
<img src="https://img.shields.io/github/actions/workflow/status/Magnetarman/WinToolkit/CI_UpdateWinToolkit_Dev.yml?branch=Dev&style=for-the-badge&label=Compiler%20Ramo%20Dev" alt="Update WinToolkit">
<img src="https://img.shields.io/github/license/Magnetarman/WinToolkit?style=for-the-badge&logo=opensourceinitiative&logoColor=white&color=0080ff" alt="license">
</p>
<p align="center">
  <br>
     <br>
    <b>🪟 Versioni di Windows Supportate: 🪟</b><br><br>
    <b>🔴 Windows 7 - Non Supportato.</b><br>
    <b>🔴 Windows 8 - Non Supportato.</b><br>
    <b>🟠 Windows 8.1 - Supporto Parziale.</b><br>
    <b>🟠 Windows 10 (< 1809) - Supporto Parziale.</b><br>
    <b>🟡 Windows 10 (> 1809) - Supporto Completo con eccezioni.</b><br>
    <b>🟡 Windows 11 (< 23H2) - Supporto Completo con eccezioni.</b><br>
    <b>🟢 Windows 11 (> 23H2) - Supporto Completo.</b><br>
</p>
</br>

## 👨‍💻 Status Commit

|                                                                               Ramo Release                                                                                |                                                                                Ramo Dev                                                                                 |
| :-----------------------------------------------------------------------------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
| <p align="center"><img src="https://img.shields.io/github/commit-activity/t/MagnetarMan/WinToolkit/main?style=for-the-badge&color=0080ff" alt="Commit Activity Main"></p> | <p align="center"><img src="https://img.shields.io/github/commit-activity/t/MagnetarMan/WinToolkit/Dev?style=for-the-badge&color=CC0033" alt="Commit Activity Dev"></p> |

## 📸 ScreenShot

> [!Note]
> Gli screenshot sottostanti dei vari strumenti integrati sono forniti a scopo puramente dimostrativo. Avviando lo script sul tuo PC, l'aspetto e le configurazioni dei tool si adatteranno automaticamente alle impostazioni della tua PowerShell. WinToolkit non modifica o sovrascrive alcuna configurazione esistente.

<div align="center">

|                                                                          |                                                                      |
| :----------------------------------------------------------------------: | :------------------------------------------------------------------: |
|       <img src="img/Starter.jpg" alt="Starter-banner" width="800">       |         <img src="img/Run.jpg" alt="Run-banner" width="800">         |
| <img src="img/RepairToolkit.jpg" alt="RepairToolkit-banner" width="800"> | <img src="img/UpdateReset.jpg" alt="UpdateReset-banner" width="800"> |
|   <img src="img/StoreRepair.jpg" alt="StoreRepair-banner" width="800">   |  <img src="img/WinCleaner.jpg" alt="WinCleaner-banner" width="800">  |
| <img src="img/OfficeToolkit.jpg" alt="OfficeToolkit-banner" width="800"> | <img src="img/SetRustDesk.jpg" alt="SetRustDesk-banner" width="800"> |

</div>

---

## 👾 Features

- **Interfaccia Intuitiva**: Nonostante la sua potenza, il toolkit presenta un menu interattivo e facile da utilizzare, che guida l'utente nella scelta dello strumento più adatto per il problema.
- **Cartella di lavoro unica**: Le operazioni del programma sono centralizzate in un'unica cartella di lavoro, situata in `%localappdata%\WinToolkit`. È importante mantenere questa directory per garantire la corretta visualizzazione e il funzionamento dell'icona di collegamento sul desktop. Lo strumento è concepito per operare in modo completamente autonomo e online, eliminando la necessità di creare cartelle temporanee aggiuntive per la sua esecuzione.
- **Log Dettagliati**: Tutte le operazioni sono registrate in un file di log salvato nel percorso `%localappdata%\WinToolkit\logs`, fornendo un riassunto chiaro delle azioni eseguite, degli errori riscontrati e dei risultati finali.

### ℹ️ Descrizione Funzioni Toolkit

- **Windows Repair Toolkit**: Avvia una sequenza automatizzata di comandi standard di Windows come sfc, chkdsk e DISM per individuare e correggere la corruzione dei file di sistema e i problemi del disco.
- **Windows Update Reset**: Risolve in modo efficiente i problemi comuni di Windows Update resettando i componenti chiave e ripristinando le impostazioni dei servizi.
- **Office Toolkit**: Strumento di gestione completo per Microsoft Office che semplifica l'installazione, la riparazione e la rimozione dei prodotti. È possibile installare una versione "Basic" di Microsoft Office in modo semi-automatico, riparare le installazioni esistenti con due diverse modalità (Riparazione Rapida offline e Riparazione Completa online), oppure rimuovere completamente il software dal sistema utilizzando l'efficace tool ufficiale Microsoft Support and Recovery Assistant (SaRA).
- **Windows Store Repair**: Esegue una reinstallazione di componenti critici come Microsoft Store, Winget, e UniGet UI (Utile per aggiornare e gestire le app in modo grafico utilizzando Winget).
- **Win Backup Driver**: Un versatile script PowerShell progettato per semplificare il processo di backup dei driver. Questo strumento automatizza l'esportazione di tutti i driver di terze parti installati, utilizzando il comando DISM per garantire un'operazione completa e affidabile.
- **Cleaner Toolkit**: Il suo scopo è liberare spazio su disco e ottimizzare le prestazioni eseguendo una pulizia profonda attraverso una serie di azioni automatizzate.
- **Set Rust Desk**: Semplifica il processo di installazione e configurazione di RustDesk sui sistemi Windows per il supporto tecnico.

> [!IMPORTANT]
>
> **Lo script di setting di Rust Desk è destinato esclusivamente alle macchine che richiedono assistenza tecnica futura da parte mia. Verrà installa una versione personalizzata di RustDesk preconfigurata per l'assistenza tecnica remota.**

### 🤔 Perché WinToolkit?

Sia che tu stia gestendo un parco macchine aziendale o che tu voglia semplicemente mantenere il tuo PC personale in perfette condizioni, WinToolkit ti permette di:

- **Risparmiare Tempo**: Automatizza ore di lavoro manuale di diagnostica e riparazione.
- **Prevenire Malfunzionamenti**: Esegui manutenzioni preventive per evitare problemi futuri.
- **Agire da Esperto**: Sfrutta la potenza degli strumenti di sistema ufficiali Microsoft con un'interfaccia semplice e sicura. Nessun Software Terzo, nessuno script aggressivo o non perfettamente documentato ed utilizzato dai supporti ufficiali.

---

## 📁 Struttura Cartelle

```sh
└── WinToolkit/
    └── img
        ├── RepairToolkit.jpg
        ├── Run.jpg
        ├── Starter.jpg
        ├── Office-Toolkit.jpg
        ├── WinToolkit-icon.png
        └── StoreRepair.jpg
    ├── CHANGELOG.md
    ├── CONTRIBUTORS.md
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

## 🚀 Avviare il Toolkit

> [!IMPORTANT]
> Prima di avviare il toolkit, assicurati che il tuo ambiente di Runtime soddisfi i seguenti requisiti:
>
> - **Windows Defender** di 24H2 potrebbe rilevare come pericoloso questo script. **E' fortemente consigliata la disattivazione temporanea durante le operazioni**.
> - **Richiesta Connessione ad internet durante l'esecuzione del Tool**.
> - Richiesto intervento manuale minimo.
> - **Spazio su disco Consigliato**: 50GB Liberi.

### 💾 Perche almeno 50 GB liberi ?

È fondamentale capire che questo spazio non serve per lo strumento (che è online e pesa pochissimi kilobyte), né per scaricare dati. I 50 GB servono esclusivamente a Windows per garantire la sua stabilità e il corretto funzionamento durante le operazioni di riparazione.

#### Perché è Necessario Questo Ampio Margine?

Quando il sistema operativo lavora su componenti critici, ha bisogno di spazio vitale per gestire diversi processi in background:

- File Temporanei e Backup Interni: Windows crea e gestisce file temporanei, copie di backup interne e cache durante la manutenzione.
- Gestione del File di Paging (Memoria Virtuale): Lo spazio è cruciale per il file di paging, che Windows utilizza come "sostituto" temporaneo della RAM quando la memoria fisica si esaurisce. Se questo spazio è insufficiente, si possono verificare gravi errori di sistema.
- Prevenzione di Malfunzionamenti: Operare con poco spazio libero (tipicamente meno del 10–15% dello spazio totale) è una causa comune di rallentamenti e malfunzionamenti generici in Windows. Avere un margine così ampio previene questi problemi e assicura che il sistema non diventi instabile.

In sintesi, i 50 GB sono una misura cautelativa per fornire a Windows l'ambiente di lavoro ideale e completare le operazioni senza interruzioni o errori dovuti alla gestione inefficiente dello spazio su disco.

### ⚙️ Avvio **Consigliato**

Installa L'eseguibile del Toolkit sul Desktop seguendo queste istruzioni:

1. Premi il Tasto Windows sulla tastiera.
2. Digita `Powershell` nel campo della ricerca.
3. Click col tasto destro del mouse sulla voce Powershell.
4. Click sulla voce `Esegui come Amministratore` dal menù a tendina.
5. inserisci il comando sottostante per avviare lo script di start nella finestra Powershell:

```powershell
 irm https://magnetarman.com/winstart | iex
```

6. Al riavvio del tuo PC troverai la scorciatoia `Win Toolkit` sul desktop da cui avviare comodamente lo script in modalità amministratore con un semplice doppio click sull'icona.

### ⚙️ Avvio Classico

> [!CAUTION]
> Per gli utenti esperti che desiderano avviare il toolkit direttamente oppure utilizzano il ToolKit su versioni parzialmente supportate come Windows 8.1 & Windows 10 < 1809, è consigliabile installare il profilo PowerShell e utilizzare PowerShell 7 o versioni successive. Questa versione moderna è necessaria per garantire la massima compatibilità, eseguire correttamente le operazioni del tool e prevenire errori di runtime o l'errata applicazione delle modifiche.

1. Premi il Tasto Windows sulla tastiera.
2. Digita `Powershell` nel campo della ricerca.
3. Click col tasto destro del mouse sulla voce Powershell.
4. Click sulla voce `Esegui come Amministratore` dal menù a tendina.
5. inserisci il comando sottostante per avviare lo script di start nella finestra Powershell:

```powershell
 irm https://magnetarman.com/WinToolkit | iex
```

### ⚙️ Avvio Toolkit [Ramo `Dev`]

> [!WARNING]
> Avviare il Toolkit dal ramo `Dev` è **rischioso**. **Potrebbe causare danni al tuo sistema.** Sono presenti funzionalità in corso di sviluppo e/o in fase di test. Per utenti non esperti si consiglia **fortemente** di eseguire il ramo stabile del toolkit `main`.

1. Premi il Tasto Windows sulla tastiera.
2. Digita Powershell nel campo della ricerca.
3. Click col tasto destro del mouse sulla voce Powershell.
4. Click sulla voce `Esegui come Amministratore` dal menù a tendina.
5. Inserisci il comando sottostante per avviare lo script di start nella finestra Powershell:

```powershell
irm https://magnetarman.com/WinToolkit-Dev | iex
```

---

## 📌 Changelog Progetto

Per un resoconto dettagliato di ogni modifica, correzione e funzionalità introdotta, consulta il changelog completo a [QUI](/CHANGELOG.md).

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

## 🌟 Lista dei Contributori

Guarda la lista delle fantastiche persone che hanno deciso di investire le loro energie per migliorare questo progetto [QUI](/CONTRIBUTORS.md).

---

## 🎗 Licenza

Creato con ❤️ da [Magnetarman](https://magnetarman.com/). Licenza MIT. Se trovi questo progetto utile, considera di lasciare una ⭐

---

## 🙌 Personalizzazioni

Segui le istruzioni che il tool ti comunicherà a video per personalizzare le funzioni.
