## Descrizione

<!-- Spiega cosa cambia e perché. Sii conciso ma completo. -->

Fixes # <!-- Rimuovi se non c'è un'issue collegata -->

---

## Tipo di Modifica

<!-- Seleziona tutti i tipi applicabili -->
- [ ] 🐛 Bug fix
- [ ] ✨ Nuova feature
- [ ] ♻️ Refactoring (nessun cambio funzionale)
- [ ] 🧹 Pulizia / Manutenzione
- [ ] 📖 Documentazione

---

## File Modificati

<!-- Elenca ogni file con una riga di descrizione -->
- `tool/NomeFile.ps1` — descrizione della modifica

---

## Test & Verifica

- [ ] Verificato localmente tramite `compiler.ps1`
- [ ] Log di esecuzione allegati (snippet o screenshot)

<details>
<summary>Log / Screenshot</summary>

```
Incolla qui i log rilevanti
```

</details>

---

## Checklist

> L'assenza di una spunta o la violazione di una regola comporta il rifiuto automatico della PR.

- [ ] PR indirizzata a `DEV` — le PR verso `main` vengono chiuse immediatamente
- [ ] Modifica atomica: un solo problema o una sola feature per PR
- [ ] `WinToolkit.ps1` **non** modificato manualmente (gestito dall'automazione CI)
- [ ] Modificati solo file in `/tool/*.ps1` o `WinToolkit-template.ps1`
- [ ] Stile di codice esistente rispettato, nessun debug code lasciato
- [ ] Commit chiari in italiano, max 72 caratteri per riga
