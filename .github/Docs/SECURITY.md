# Security Policy

## Versioni Supportate

| Versione | Supportata         |
| -------- | ------------------ |
| 2.5.x    | ✅ Sì              |
| < 2.5    | ❌ No              |

## Segnalazione di Vulnerabilità

> [!CAUTION]
> **NON aprire issue pubbliche per vulnerabilità di sicurezza.**
> Aprire un'issue pubblica espone gli utenti a rischi prima che una fix sia disponibile.

### Come segnalare

Inviare una **segnalazione privata** tramite uno dei seguenti canali:

- **GitHub Security Advisories:** usa la funzione [Report a vulnerability](../../security/advisories/new) direttamente in questo repository.
- **Email:** [me@magnetarman.com](mailto:me@magnetarman.com) — indicare nell'oggetto `[SECURITY] WinToolkit`.

### Cosa includere nella segnalazione

Per accelerare la verifica e la risoluzione, fornire:

1. Descrizione chiara della vulnerabilità
2. Passi per riprodurla (step-by-step)
3. Impatto potenziale stimato
4. Versione di WinToolkit interessata
5. Eventuale proof-of-concept (solo in privato)

### Tempi di risposta

| Fase                          | Tempistica      |
| ----------------------------- | --------------- |
| Conferma ricezione            | Entro 72 ore    |
| Valutazione iniziale          | Entro 7 giorni  |
| Fix e rilascio patch          | Entro 30 giorni |
| Divulgazione pubblica (CVE)   | Dopo il fix     |

### Scope

Sono considerati **in scope**:

- Esecuzione di codice arbitrario tramite il toolkit
- Escalation di privilegi non intenzionale
- Verifica checksum assente o bypassabile per i binari distribuiti
- Vulnerabilità nei workflow CI/CD che permettono compromissione della supply chain

Sono considerati **out of scope**:

- Comportamenti attesi che richiedono già privilegi amministrativi
- Problemi nelle versioni non supportate (< 2.5)
- Vulnerabilità nelle dipendenze di terze parti non gestite da questo progetto

---

Grazie per contribuire alla sicurezza di WinToolkit.
