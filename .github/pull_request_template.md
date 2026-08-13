## Description

<!-- Explain what changed and why. Be concise but complete. -->

Fixes # <!-- Remove if no linked issue -->

---

## Type of Change

<!-- Select all applicable types -->
- [ ] 🐛 Bug fix
- [ ] ✨ New feature
- [ ] ♻️ Refactoring (no functional change)
- [ ] 🧹 Cleanup / Maintenance
- [ ] 📖 Documentation

---

## Files Modified

<!-- List every file with a one-line description -->
- `tools/NomeFile.ps1` — description of the change

---

## Tests & Verification

- [ ] Verified locally via the relevant build/test command
- [ ] If CI/CD changed, validated the affected workflow/action and updated the tracking document
- [ ] Execution logs attached (snippet or screenshot)

<details>
<summary>Log / Screenshot</summary>

```
Paste relevant logs here
```

</details>

---

## Checklist

> Missing a checkbox or violating a rule will result in automatic PR rejection.

- [ ] PR targets `Dev` unless this is an authorized maintainer release change
- [ ] Atomic change: one issue or one feature per PR
- [ ] `WinToolkit.ps1` **not** modified manually (handled by CI automation)
- [ ] Generated artifacts (`WinToolkit.ps1`, `start-core.ps1`) are not edited manually
- [ ] Changes to `.github/`, `start.ps1` or `start-modules/` include the required maintainer review
- [ ] Existing code style respected, no debug code left behind
- [ ] Clear commits in Italian, max 72 characters per line
