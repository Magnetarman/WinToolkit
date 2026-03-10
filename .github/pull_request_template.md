## Descrizione della Pull Request
Fornisci un recap rapido ma accurato del motivo per cui apri questa PR.

Link all'Issue relativa (se applicabile): Fixes #

---

## 🛑 CHECKLIST OBBLIGATORIA (Regole di Contribuzione)
Prima di inviare la PR o richiedere review, assicurati di soddisfare tutti i punti. Assenza della spunta o violazione causerà **rifiuto automatico**.

- [ ] **Branch di destinazione DEV**: Ho indirizzato questa PR **ESCLUSIVAMENTE** al branch `DEV`. (Le PR dirette al `main` verranno chiuse senza preavviso).
- [ ] **Singolo Contributo**: Questa PR risolve **UN** singolo bug o aggiunge **UNA** singola e ben delimitata feature.
- [ ] **Nessuna modifica a `WinToolkit.ps1`**: Dichiaro di NON aver pre-compilato o toccato il file `WinToolkit.ps1` (poiché viene ricostruito dall'automazione nel branch DEV in modo autonomo).
- [ ] **Modifica Cartelle e Moduli Consentiti**: Ho effettuato modifiche negli script isolati dentro `/tool/*.ps1` oppure all'interno del file base test (`WinToolkit-template.ps1` per le root config).
- [ ] **Standard Commit**: Ho strutturato i miei commit in lingua italiana e adoperato presentazioni a pallini / bullet list, mantenendo chiarezza (max 72 char. alla riga 1).

---

## Dettaglio Architetturale Modifiche

Indica quali path ai tool o sezioni dei template hai revisionato e la ratio:
- `/tool/NomeScript.ps1` -> Aggiunta / Rimossa logica X...
- `WinToolkit-template.ps1` -> Modificate le variabilli di riferimento per Y...

## Verifica Log e Debug (Opzionale / Fortemente Consigliata se fixing code)
Se hai sistemato comandi base script, puoi incollare il pezzo di Log con success-output o trascinarne file sezioni interessate generate dopo che hai eseguito compilazione e test locali per conto tuo prima della PR .
*(Sei in grado di compilare ed emulare il Run per provare le tue funzioni in test sandbox usando `compiler.ps1` localmente al momento)*

## Note aggiuntive per il Maintainer e Reviewers
Scrivi pure qui note finali se c'è altro da tenere a mente per testare al meglio la tua request.
