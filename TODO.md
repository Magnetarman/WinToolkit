# To-Do

### V 2.5.0

- Cambiare gestione profilo powershell
  - [ ] aggiungere alla repo in asset nuovo file Microsoft.PowerShell_profile.ps1
  
- Setup profilo `setup.ps1`
  - [ ] Generare codice per la codifica SHA 256
  - [ ] Get-FileHash "C:\Users\User\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" -Algorithm SHA256 | Select-Object Hash
  - [ ] Generare un file hash ed analizzare il modo con cui viene creato per replicare quello di chris
  - [ ] Eliminare ogni riferimento al tool di chris
  - [ ] inserire WinToolkit e Dev
  - [ ] PROFILO PERSONALE AGGIUNGERE RustServer collegamento SSH server rust desk
  - [ ] Fix caricamento profilo https://github.com/ChrisTitusTech/powershell-profile/issues/123
  - [ ] Riscrivere il profilo powershell per scaricare ed utilizzare JetBrains mono al posto di cascadian cove in linea con il setting del terminale che installo dopo così da avere una visualizzazione funzionate
  - [ ] Eliminare funzioni non utilizzate nel profile.ps1 ed adattarlo alle mie esigenze.
  - [ ] Pushare tutto nella cartella asset in modo da poter effettuare dei test.
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

### V 2.5.1

- Funzione WinUpdateDisabler
  - [ ] Add script relativo e funzioni nel template
  - [ ] Disabilita permanentemente Windows Update con possibilità di ripristino
- **?** Deprovvisioning dell'immagine Windows 11 (studio di fattibilità in corso)

### V 2.5.2

- Rework `WinToolkit.ps1`
  - [ ] Aggiungere nello `start.ps1` dopo aver completato le varie installazioni l'installazione del profilo powershell nuovo
  - [ ] Eliminare da WinToolkit la sezione 1 con l'installazione del profilo non più necessaria
