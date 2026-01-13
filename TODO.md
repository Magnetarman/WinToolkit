# To-Do

### V 2.5.0
  
- Funzione di concatenazione script rotta
  - [x] Ripristino funzionalità completa
  - [x] Unificazione funzionalità script "template"
  - [x] Se la funzionalità di avvio script multipli è attiva deve saltare la sezione relativa al riavvio del pc presente alla fine di ogni script, eseguire tutte le operazioni ed alla fine proseguire con riavvio del PC.

### V 2.5.1

- Funzione WinUpdateDisabler
  - [ ] Add script relativo e funzioni nel template
  - [ ] Disabilita permanentemente Windows Update con possibilità di ripristino
- **?** Deprovvisioning dell'immagine Windows 11 (studio di fattibilità in corso)

### V 2.5.2

- Rework `WinToolkit.ps1`
  - [ ] Aggiungere nello `start.ps1` dopo aver completato le varie installazioni l'installazione del profilo powershell nuovo
  - [ ] Eliminare da WinToolkit la sezione 1 con l'installazione del profilo non più necessaria
