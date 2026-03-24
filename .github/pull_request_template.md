## 🚀 Pull Request Info

| Tipo di Modifica | Dettaglio |
| :--- | :--- |
| **Branch Destinazione** | `DEV` (Obbligatorio) |
| **Issue Collegata** | Fixes # |
| **Ambito** | [Es. Tooling / UI / Core] |

---

## 📝 Descrizione delle Modifiche
Fornisci un riepilogo tecnico ma leggibile di cosa cambia e perché. Utilizza elenchi puntati se necessario.

---

## 🛑 CHECKLIST DI QUALITÀ (Standard WinToolkit)
*L'assenza di una spunta o la violazione delle regole comporterà il rifiuto automatico della PR.*

- [ ] **Branch di destinazione**: Ho indirizzato la PR a `DEV`. (PR verso `main` saranno chiuse immediatamente).
- [ ] **Atomicità**: Questa PR risolve **UN** singolo problema o aggiunge **UNA** singola feature.
- [ ] **Integrità Build**: Dichiaro di NON aver modificato manualmente `WinToolkit.ps1` (gestito dall'automazione).
- [ ] **Targeting Corretto**: Ho modificato solo i file in `/tool/*.ps1` o `WinToolkit-template.ps1`.
- [ ] **Stile Code**: Ho seguito lo stile di scripting esistente e non ho lasciato debug code.
- [ ] **Lingua e Commit**: Ho scritto commit chiari in italiano (max 72 char per riga).

---

## 🛠️ Dettagli Tecnici & Architetturali
Elenca i file modificati e la logica applicata:
- `file1.ps1` -> Descrizione modifica...
- `file2.ps1` -> Descrizione modifica...

---

## 🧪 Risultati dei Test e Log
È fortemente consigliato includere uno snippet dei log di test o uno screenshot del corretto funzionamento.
- [ ] Ho verificato le modifiche localmente tramite `compiler.ps1`.
- [ ] Ho allegato/incollato i log di successo qui sotto.

---

## 📖 Documentazione (Se applicabile)
- [ ] Ho aggiornato i commenti nel codice (fogli di aiuto/help docs).
- [ ] Ho aggiornato il README o la documentazione esterna se necessario.
