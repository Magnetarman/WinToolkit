# To-Do

### V 2.5.4
- `start.ps1` Aggiornato.
  - [x] Rimossa variabile `$rebootNeeded`.
  - [x] Spostati CLSID Windows Terminal e lista processi interferenti Winget in `$script:AppConfig`.
  - [x] Rimosso stile Progress da `$Global:MsgStyle`.
  - [x] Eliminata funzione `Install-NuGetIfRequired` e il suo pre-check ridondante in `Install-WingetPackage`.
  - [x] Rimossa una chiamata ridondante a `Update-EnvironmentPath` prima del fallback MSIX.
  - [x] Rimosso if con warning non bloccante in `Test-VCRedistInstalled`.
  - [x] Corretta numerazione passi in `Repair-WingetDatabase`.
  - [x] Aggiunto countdown di 5 secondi prima della chiusura dello script. Adesso alla fine dell'installazione lo script si chiude automaticamente se ogni operazione è stata eseguita con successo.
  - [x] Sostituito valore non valido Progress con Info nel parametro -Type di Write-StyledMessage (risolve errore ValidateSet runtime).
  - [x] Install-GitPackage - Sostituite 3 occorrenze di aggiornamento PATH inline con la funzione Update-EnvironmentPath esistente.
  - [x] Invoke-WinToolkitSetup - Rimossa duplicazione codice rilevamento percorso pwsh.exe (ora rilevato una sola volta).
  - [x] Estrazione funzioni annidate:
    - [x] Get-WingetDownloadUrl estratta da Install-WingetCore.
    - [x] Install-NerdFontsLocal estratta da Install-PspEnvironment.
    - [x] Get-ProfileDirLocal estratta da Install-PspEnvironment.
  - [x] Aggiunta lista UpdateServices in $script:AppConfig e aggiornate Invoke-StopUpdateServices / Invoke-StartUpdateServices.
  - [x] Spostato $Global:MsgStyles all'interno di AppConfig eliminando scope globale non necessario.
  - [x] Corretto pattern ProgressPreference in Install-WingetPackage (ora salva e ripristina valore originale).
  - [x] Uniformato operatore negazione da ! a -not per coerenza.
  - [x] Corretta numerazione passi mancante (#6) in Repair-WingetDatabase.
  - [x] Aggiunto Layout.Width in configurazione, rimossi magic number 65 hardcoded.
  - [x] Rimossa inizializzazione superflua $downloadUrl = $null a riga 1127.
  - [x] Aggiunto blocco .SYNOPSIS a tutte le 20 funzioni presenti.
  - [x] Riorganizzato il codice in modo più pulito e lineare.
  - [x] Rimuovi tutti i caratteri ANSI/colori prima di salvare su file. [[Thanks To @Ennio Costanzi]]()
  - [x] Corretti errori di parsing funzione non correttamente inizializzata. [[Thanks To @Ennio Costanzi]]()

- `WinToolkit-template.ps1` Aggiornato.
  - [x] Contrassegnata come `[DEPRECATA]` la funzione `Get-UserConfirmation` per futura rimozione.
  - [x] Sostituita la chiusura dei processi duplicata nel ripristino di Winget integrando la funzione `Stop-ToolkitProcesses`.
  - [x] Consolidata e de-duplicata registrazione `AppxManifest.xml` tramite funzione interna dedicata.
  - [x] Aggiunto caching a `Get-SystemInfo` azzerando latenze CIM durante il ricarico del menu principale.
  - [x] Inserita funzione `Initialize-ToolkitPaths` centralizzata per i folder log/temp, chiamata fuori ciclo prima della UI.
  - [x] Ottimizzato wrapper custom `Read-Host` tramite interruzione bloccante `ReadKey()` cancellando overhead della CPU nel polling loop.
  - [x] Uniformati link e blocchi di configurazioni `AppConfig` centrali.
  - [x] Gestione Servizi: Aggiunte le funzioni Invoke-StopUpdateServices e Invoke-StartUpdateServices per sospendere temporaneamente wuauserv, bits, cryptsvc e dosvc.
  - [x] Integrazione: Il sistema ora arresta i servizi subito dopo i controlli preliminari e li riavvia automaticamente in ogni scenario di uscita (completamento, riavvio in PowerShell 7/Terminal o errore critico).
  - [x] Feedback Utente: Inseriti messaggi di stato per informare correttamente l'utente durante l'arresto e il riavvio dei servizi.
  - [x] Introdotta funzione `Test-WindowsUpdateStatus` per rilevare gli aggiornamenti di Windows in sospeso e l'attività del programma di installazione.
  - [x] Rimuovi tutti i caratteri ANSI/colori prima di salvare su file. [[Thanks To @Ennio Costanzi]]()

- `WinRepairToolkit` Aggiornato.
  - [x] Improve AppX registration and chkdsk handling. [[Thanks To @Ennio Costanzi]]()
  - [x] Controllo iniziale stato sistema: Aggiunta funzione Test-PendingOperations che verifica chiavi di registro per reboot pendente e avvisa l'utente prima di iniziare le riparazioni.
  - [x] Pulizia stato DISM: Esecuzione automatica di DISM /CancelCommands prima di ogni operazione /StartComponentCleanup per annullare operazioni pendenti.
  - [x] Gestione specifica errore: 0x800f0806 viene riconosciuto come non critico, viene mostrato un avviso informativo e non viene conteggiato come errore.
  - [x] Supporto codice exit 3010: DISM /ResetBase che ritorna 3010 (reboot richiesto) viene considerato successo
  Esclusione errore dal conteggio: 0x800f0806 viene saltato nella logica di rilevazione errori generale.

- Profilo Powershell Aggiornato.
  - [x] Aggiunta Funzione caricamento WinToolkit-GUI.

- `compiler.ps1` Aggiornato.
  - [x] Corretti errori di parsing funzione non correttamente inizializzata.


### V 2.6 - Debloat

- `WinToolkit.ps1` Aggiornato.
  - [ ] Aggiunti nuovi script.
  - [ ] Riorganizzato il menu principale per maggiore chiarezza.

- Aggiunta Funzione `WinUpdateDisabler.ps1`.
  - [ ] Add script relativo e funzioni nel template.
  - [ ] Disabilita permanentemente Windows Update con possibilità di ripristino.

- Aggiunta Funzione `WinUpdateSet.ps1` (Windows Home non supportato).
  - [ ] Add script relativo e funzioni nel template.
  - [ ] Imposta tramite criteri di gruppo gli Update di windows.

- <del>Avvio dello script Chris con configurazione personalizzata (`iwr -useb https://christitus.com/win | iex`).</del>
  - **Questa funzione a causa di lacune nel debloat di Windows 11 ramo *Germanium* 24H2/25H2 verrà corretta ed integrata in uno script nuovo denominato `WinDebloat.ps1`**
- Aggiunta Funzione `WinDebloat.ps1`.
  - [ ] Aggiunta Disattivazione Servizi superflui.


### V 2.7 - Security Update

- [ ] Download ed esecuzione di Tron Script con intervento minimo.
- [ ] Reset dei servizi Windows **[Thanks to @sicolla]**.
- [ ] Riparazione avanzata Windows Search **[Thanks to @sicolla]**.


### V 2.8 - WinDownloader

- [ ] Download script preconfigurati dal sito UUP Dump.
  - [ ] Avvio Creazione automatica ISO di Windows 10/11.
    - <del>Windows 11 25H2</del> **(Instabile)**
    - [ ] Windows 11 24H2.
    - [ ] Windows 11 23H2.
    - [ ] Windows 10 22H2.
    - [ ] Windows 10 21H2.
  - [ ] Implementazione Download ISO Ufficiale di Windows 8.1.
  - [ ] Implementazione Download ISO Ufficiale di Windows 7 SP1.
  - [ ] Implementazione Download ISO Ufficiale di Windows XP SP3.
  - [ ] Download Automatico di Rufus.
  - [ ] Creazione di dispositivo USB Bootable.
  - [ ] Inserimento funzione Blocco selettivo Update Windows.


### V 2.9 - OFFLINE MODE 

- [ ] Possibilità di avviare il download delle ultime risorse necessarie al toolkit.
- [ ] Salvataggio in file .7z da estrarre.
- [ ] L'archivio conterrà tutto il necessario ad utilizzare Wintoolkit in modalità offline senza rete.


### V 2.10 - Multi Lang Mode

- [ ] Conversione Readme.md in inglese.
- [ ] Possibilità di scegliere la lingua all'avvio di Wintoolkit.


### V X.X - MagnetarMan Mode

- [ ] Avvio Script Chris con configurazione personalizzata.
  - [ ] Installazione programmi: Brave Browser, Google Chrome, Betterbird, Fan Control, PowerToys, Uniget, Crystal Disk Info, HwInfo, Rust Desk, Client Giochi (Amazon, Gog Galaxy, Epic Games, Steam).
  - [ ] Installazione .NET Runtime (dalla 4.8 alla 9.0).
  - [ ] Installazione Microsoft C++ Package.
  - [ ] Installazione/Aggiornamento Directx.
  - [ ] Installazione Playnite (Launcher/Aggregatore).
  - [ ] Installazione Revo Uninstaller.
  - [ ] Installazione Tree Size.
  - [ ] Installazione Glary Utilities.
  - [ ] Pulizia del sistema.
  - [ ] Applicazione Sfondo "MagnetarMan".
  - [ ] Riavvio del PC per completare le modifiche.


### V X.X - GUI

- Rework Progetto GUI.
- [ ] Rendere lo script GUI un semplice wrapper.
- [ ] Inserire download ultima versione `Wintoolkit.ps1`.
- [ ] Parsing e popolazione funzionalità.
- [ ] Concatenzazione script da checkbox.
- [ ] Avanzamento Barra di progressione.
- [ ] Redirect Output scripts nel box Logs.
- **?** Deprovvisioning dell'immagine Windows 11 (studio di fattibilità in corso).
