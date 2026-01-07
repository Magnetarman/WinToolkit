# To-Do

### V 2.5.0

- Cambiare gestione profilo powershell
  - [ ] aggiungere alla repo in asset nuovo file Microsoft.PowerShell_profile.ps1
  
- Setup profilo `setup.ps1`
  - [x] Generare codice per la codifica SHA 256
  - [x] Get-FileHash "C:\Users\User\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" -Algorithm SHA256 | Select-Object Hash
  - [x] Generare un file hash ed analizzare il modo con cui viene creato per replicare quello di chris
  - [x] Eliminare ogni riferimento al tool di chris
  - [x] inserire WinToolkit e Dev
  - [ ] PROFILO PERSONALE AGGIUNGERE RustServer collegamento SSH server rust desk
  - [x] Fix caricamento profilo https://github.com/ChrisTitusTech/powershell-profile/issues/123
  - [ ] Riscrivere il profilo powershell per scaricare ed utilizzare JetBrains mono al posto di cascadian cove in linea con il setting del terminale che installo dopo così da avere una visualizzazione funzionate
  - [x] Eliminare funzioni non utilizzate nel profile.ps1 ed adattarlo alle mie esigenze.
  - [x] Pushare tutto nella cartella asset in modo da poter effettuare dei test.
  - [x] Creazione label gialla nelle issue "waiting user check"

- Automatizzare creazione changelog
  - [ ] Prende le due versioni
  - [ ] Vede dove e come e cambiato il codice
  - [ ] Produce lista di modifiche basandosi sul changelog tono e stile esistente
  - [x] Add issue chiusi al changelog

- Aggiungere funzione di esportazione log
  - [x] Esegue una compressione in .zip della cartella %LOCALAPPDATA%\WinToolkit\logs
  - [x] Ignora eventuali file in uso
  - [x] Posiziona sul desktop il file .zip appena creato ed avvisa l'utente di inviare via telegram o email lo zip con i log presente sul desktop in modo da poter controllare e risolvere eventuali errori

- Fix Windows Repair
  - [x] Moltiplicare per 2 il tempo di riempimento della barra finta del terzo passaggio (Ripristino immagine di windows).
  - [x] Aggiungere queste righe alla riparazione del sistema operativo
    - [x] Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\appxmanifest.xml' -DisableDevelopmentMode
    - [x] Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe\appxmanifest.xml' -DisableDevelopmentMode
    - [x] Add-AppxPackage -Register -Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.Core_cw5n1h2txyewy\appxmanifest.xml' -DisableDevelopmentMode

- Funzione di concatenazione script rotta
  - [ ] Ripristino funzionalità completa
  - [ ] Unificazione funzionalità script "template"
  - [ ] Se la funzionalità di avvio script multipli è attiva deve saltare la sezione relativa al riavvio del pc presente alla fine di ogni script, eseguire tutte le operazioni ed alla fine proseguire con riavvio del PC.

- Fix Video Driver install
  - [x] Barre di progressione con problemi di output

- Funzione Spinner
  - [x] Centralizzata nello script `WinToolkit-Template.ps1`
  - [x] Aggiornato codice dei vari script per richiamare la nuova funzione globale
  - [x] Eliminato codice ridondante e duplicato 
  
- Revamping `Poweshell Profile.ps1`
  - [x] Eliminare tutto il codice relativo alle funzioni di debug non più necessarie
  - [x] Elimina tutto il codice relativo all'architettura Architettura "Override-First" non più necessario
  - [x] Elimina tutto il codice relativo all' Update-Profile: Esegue un confronto di hash SHA256 (Get-FileHash) tra il file $PROFILE locale e la versione remota su GitHub. Se differiscono, scarica e sovrascrive.
  - [x] Elimina tutto il codice relativo alla Gestione File: grep, sed, which, export, pkill, head, tail sono mappati su logiche PowerShell (es. grep usa Select-String). 
  - [x] Elimina tutto il codice relativo a trash: Invece di usare Remove-Item (che elimina permanentemente), lo script istanzia l'oggetto COM Shell.Application per invocare il metodo ParseName().InvokeVerb('delete'), spostando i file nel Cestino di Windows.
  - [x] Elimina tutto il codice relativo a uptime
  - [x] Elimina tutto il codice relativo a hb
  - [x] Elimina tutto il codice relativo a Syntax Highlighting
  - [x] Elimina tutto il codice relativo a Completamento Nativo
  - [x] Modifica il codice relativo alla sezione Oh My Posh
    - [x] Tenta di caricare il tema atomic.omp.json al posto di cobalt2.omp.json
    - [x] se mancante, lo scarica da GitHub. il link al profilo è questo $themeUrl https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/atomic.omp.json Se il download fallisce, punta direttamente all'URL remoto come ultima risorsa.
  - [x] modifica la sezione di codice Editor Hierarchy. nei controlli dei vari editor deve esserci zed -> code -> notepad. Elimina tutti gli altri non più utili.
  - [x] Nella sezione # Editor Configuration elimina tutto il codice relativo agli altri editor, deve rimanere solo quello relativo a VSCode (code) ed aggiungi il codice relativo per Zed code (zed)
  - [x] Modificare la sezione # Open WinUtil full-release in #Open WinToolkit Stable cambiando il link da https://christitus.com/win a https://magnetarman.com/WinToolkit
  - [x] Modificare la sezione # Open WinUtil dev-release in #Open WinToolkit Dev cambiando il codice totalmente e richiamando solo il comando Invoke-Expression (Invoke-RestMethod https://magnetarman.com/WinToolkit-Dev)
  - [x] Modifica la lingua di tutti i commenti # traducendo in italiano il testo.
  - [x] Aggiungi installazione dtop da winget
  - Elimina le seguenti funzioni inutili
    - [x] function sed
    - [x] function grep
    - [x] function which($name)
    - [x] function export($name, $value)
    - [x] function nf
    - [x] function docs
    - [x] function k9
    - [x] function la
    - [x] function ll
    - [x] # Git Shortcuts
    - [x] function cpy
    - [x] function pst
    - [x] # Help Function

### V 2.5.1

- Funzione WinUpdateDisabler
  - [ ] Add script relativo e funzioni nel template
  - [ ] Disabilita permanentemente Windows Update con possibilità di ripristino
- **?** Deprovvisioning dell'immagine Windows 11 (studio di fattibilità in corso)

### V 2.5.2

- Rework `WinToolkit.ps1`
  - [ ] Aggiungere nello `start.ps1` dopo aver completato le varie installazioni l'installazione del profilo powershell nuovo
  - [ ] Eliminare da WinToolkit la sezione 1 con l'installazione del profilo non più necessaria
