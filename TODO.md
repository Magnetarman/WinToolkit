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
  - [ ] istallazione di zoxide (verrà configurato al primo avvio del profilo powershell)
  - [ ] Istallazione di fastfetch
  - [ ] Istallazione di btop
  

- Automatizzare creazione changelog
  - [ ] Prende le due versioni
  - [ ] Vede dove e come e cambiato il codice
  - [ ] Produce lista di modifiche basandosi sul changelog tono e stile esistente
  - [x] Add issue chiusi al changelog

- Funzione di concatenazione script rotta
  - [ ] Ripristino funzionalità completa
  - [ ] Unificazione funzionalità script "template"
  - [ ] Se la funzionalità di avvio script multipli è attiva deve saltare la sezione relativa al riavvio del pc presente alla fine di ogni script, eseguire tutte le operazioni ed alla fine proseguire con riavvio del PC.


### V 2.5.1

- Funzione WinUpdateDisabler
  - [ ] Add script relativo e funzioni nel template
  - [ ] Disabilita permanentemente Windows Update con possibilità di ripristino
- **?** Deprovvisioning dell'immagine Windows 11 (studio di fattibilità in corso)

### V 2.5.2

- Rework `WinToolkit.ps1`
  - [ ] Aggiungere nello `start.ps1` dopo aver completato le varie installazioni l'installazione del profilo powershell nuovo
  - [ ] Eliminare da WinToolkit la sezione 1 con l'installazione del profilo non più necessaria
