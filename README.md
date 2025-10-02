<p align="center">
	<img src="img/WinToolkit-icon.png" alt="WinToolkit-banner" width="160">
</p>
<br>
<p align="center">
	<em><code>🛠️ WinToolkit: La Soluzione Definitiva per SOPRAVVIVERE A WINDOWS.</code></em>
    <br>
    <br>
    WinToolkit è una suite di script PowerShell potente e compatta, progettata per offrire a professionisti IT, amministratori di sistema e utenti esperti un controllo granulare sulla manutenzione e sulla risoluzione dei problemi di Windows e della Suite Office. Questo toolkit intuitivo aggrega gli strumenti di riparazione di sistema più efficaci in un'unica interfaccia, automatizzando i processi complessi per ottimizzare le prestazioni e ripristinare la stabilità del sistema con pochi passaggi automatizzati.
     <br>
     <br>
    <b> OS Supportati:</b> Windows 10 versione 1809 (build 17763) e successivi.
</p>
<br>
<p align="center">
<img src="https://img.shields.io/badge/version-2.2.2-dgreen.svg?style=for-the-badge" alt="versione">
<img src="https://img.shields.io/github/last-commit/Magnetarman/WinToolkit?style=for-the-badge&logo=git&logoColor=white&color=0080ff" alt="last-commit">
<img src="https://img.shields.io/github/actions/workflow/status/Magnetarman/WinToolkit/CI_UpdateWinToolkit_Dev.yml?branch=Dev&style=for-the-badge&label=Update%20WinToolkit.ps1" alt="Update WinToolkit">
<img src="https://img.shields.io/github/license/Magnetarman/WinToolkit?style=for-the-badge&logo=opensourceinitiative&logoColor=white&color=0080ff" alt="license">
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
| <img src="img/OfficeToolkit.jpg" alt="OfficeToolkit-banner" width="800"> | <img src="img/StoreRepair.jpg" alt="StoreRepair-banner" width="800"> |

</div>

---

## 👾 Features

> [!Warning]
>
> A causa di limitazione tecniche e tecnologiche, il Toolkit su sistemi precedenti come **Windows 10 Pre 1809**, **Windows 8.1** e **Windows 8** risulta **parzialmente supportato**. Per avviare il toolkit è richiesto il download e l'installazione manuale di [Powershell 7](https://github.com/PowerShell/PowerShell/releases/tag/v7.5.3). Avviare successivamente Powershell 7 ed inserire i comandi di Bypass per l'esecuzione di script non firmati `Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy Bypass` & `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass`. L'unico metodo di avvio supportato è **l'avvio Classico**, altri metodi non sono supportati. L'esecuzione del Toolkit su sistemi non supportati è sconsigliato, potrebbero verificarsi errori di runtime oppure gli script potrebbero non funzionare correttamente, eseguitelo a vostro rischio e pericolo.

- **Interfaccia Intuitiva**: Nonostante la sua potenza, il toolkit presenta un menu interattivo e facile da utilizzare, che guida l'utente nella scelta dello strumento più adatto per il problema.
- **Cartella di lavoro unica**: Le operazioni del programma sono centralizzate in un'unica cartella di lavoro, situata in `%localappdata%\WinToolkit`. È importante mantenere questa directory per garantire la corretta visualizzazione e il funzionamento dell'icona di collegamento sul desktop. Lo strumento è concepito per operare in modo completamente autonomo e online, eliminando la necessità di creare cartelle temporanee aggiuntive per la sua esecuzione.
- **Log Dettagliati**: Tutte le operazioni sono registrate in un file di log salvato nel percorso `%localappdata%\WinToolkit\logs`, fornendo un riassunto chiaro delle azioni eseguite, degli errori riscontrati e dei risultati finali.

### ℹ️ Descrizione Funzioni Toolkit

- **Windows Repair Toolkit**: Avvia una sequenza automatizzata di comandi standard di Windows come sfc, chkdsk e DISM per individuare e correggere la corruzione dei file di sistema e i problemi del disco. Il tool esegue più tentativi e genera un log dettagliato garantendo una tracciabilità completa delle operazioni.
- **Windows Update Reset**: Risolve in modo efficiente i problemi comuni di Windows Update resettando i componenti chiave e ripristinando le impostazioni dei servizi. Questo script blocca e riavvia i servizi di aggiornamento, rinomina e cancella le directory di cache e ripara il registro di sistema, garantendo che il tuo sistema possa scaricare e installare gli aggiornamenti essenziali senza intoppi.
- **Office Toolkit**: Strumento di gestione completo per Microsoft Office che semplifica l'installazione, la riparazione e la rimozione dei prodotti. Con la sua interfaccia intuitiva, ti guida attraverso ogni operazione, rendendo la gestione di Office accessibile a tutti. È possibile installare una versione "Basic" di Microsoft Office in modo semi-automatico, riparare le installazioni esistenti con due diverse modalità (Riparazione Rapida offline e Riparazione Completa online), oppure rimuovere completamente il software dal sistema utilizzando l'efficace tool ufficiale Microsoft Support and Recovery Assistant (SaRA). Questo garantisce la risoluzione dei problemi più comuni, dai malfunzionamenti minori ai conflitti più complessi che richiedono una pulizia completa, offrendo un'esperienza professionale e affidabile.
- **Windows Store Repair**: Esegue una reinstallazione di componenti critici come Microsoft Store, Winget, e UniGet UI (Utile per aggiornare e gestire le app in modo grafico utilizzando Winget). Lo script esegue questa operazione in modo silenzioso, provando più metodi (Winget, DISM e registrazione del manifest) per garantire il successo. Il processo include anche la pulizia della cache e il riavvio dei servizi necessari per una riparazione pulita e funzionale.
- **Win Backup Driver**: Un versatile script PowerShell progettato per semplificare il processo di backup dei driver. Questo strumento automatizza l'esportazione di tutti i driver di terze parti installati, utilizzando il comando DISM per garantire un'operazione completa e affidabile. Una volta esportati, i driver vengono compressi in un singolo file ZIP, che viene automaticamente salvato sul desktop con un nome basato sulla data per una facile identificazione. Ideale per la preparazione di una nuova installazione di Windows, eliminando la necessità di scaricare ogni componente singolarmente.
- **Set Rust Desk**: Semplifica il processo di installazione e configurazione di RustDesk sui sistemi Windows per il supporto tecnico. Lo script procede all'installazione silenziosa di RustDesk, alla cancellazione di eventuali configurazioni precedenti e al download di file di configurazione personalizzati per garantire che il software sia preconfigurato per il supporto tecnico remoto. L'intero processo è progettato per essere completamente automatizzato e si conclude con un riavvio del sistema opzionale e annullabile dall'utente per finalizzare tutte le modifiche.
- **Cleaner Toolkit**: Il suo scopo è liberare spazio su disco e ottimizzare le prestazioni eseguendo una pulizia profonda attraverso una serie di azioni automatizzate. Lo script non solo utilizza la Pulizia Disco avanzata (CleanMgr), ma interviene manualmente per eliminare i file di sistema obsoleti, come gli assembly di WinSxS, la cache Prefetch, e i vari log (eventi, errori, sistema). Inoltre, rimuove file temporanei di sistema e utente, svuota le cache di navigazione web, inclusi cookie e cache WinInet, cancella la cronologia di Windows Update, e pulisce la coda di stampa. Infine, per assicurare l'applicazione completa delle modifiche e la massimizzazione dello spazio recuperato, lo script svuota la cache DNS e richiede un riavvio del sistema al termine dell'intero processo.

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
>
> **P.S** Ti consiglio di avere circa 50 Gigabyte di spazio libero sul tuo disco rigido (SSD o HDD) prima di iniziare. È essenziale capire che questo spazio non è per lo strumento: il toolkit è totalmente online, pesa pochissimi kilobyte e non scarica 50 GB di dati. Questo ampio margine di 50 GB è necessario esclusivamente per garantire la stabilità e il corretto funzionamento di Windows durante le operazioni di riparazione. Quando il sistema operativo lavora su componenti critici, ha bisogno di spazio vitale per gestire diversi processi in background: ad esempio, Windows crea e gestisce file temporanei e copie di backup interne durante la manutenzione. Soprattutto, lo spazio è cruciale per la gestione del file di paging (o memoria virtuale), che Windows utilizza come "sostituto" temporaneo della RAM quando la memoria fisica si esaurisce; se questo spazio è insufficiente, si possono verificare errori di sistema. Avere un margine così ampio previene anche i problemi legati alla cache e assicura che il sistema non sia rallentato o instabile, poiché operare con poco spazio libero (tipicamente meno del 10−15%) è una causa comune di malfunzionamenti generici in Windows. In sintesi, i 50 GB sono una misura cautelativa per fornire a Windows l'ambiente di lavoro ideale per completare le operazioni senza interruzioni dovute a una gestione inefficiente dello spazio su disco.

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
> Per gli utenti esperti che desiderano avviare il toolkit direttamente, è consigliabile installare il profilo PowerShell e utilizzare PowerShell 7 o versioni successive. Questa versione moderna è necessaria per garantire la massima compatibilità, eseguire correttamente le operazioni del tool e prevenire errori di runtime o l'errata applicazione delle modifiche.

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
