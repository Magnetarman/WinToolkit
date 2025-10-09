# WinToolkit-GUI

## Descrizione

WinToolkit-GUI è la versione grafica del celebre WinToolkit di MagnetarMan, completamente riscritta con un'interfaccia moderna basata su Windows Forms per PowerShell. Questa versione mantiene tutte le funzionalità dell'originale ma offre un'esperienza utente molto più intuitiva e accattivante.

## ✨ Caratteristiche principali

### 🎨 Interfaccia moderna

- Design scuro professionale simile alle moderne applicazioni Windows
- Interfaccia tabulata per organizzare gli script per categorie
- Layout responsivo e personalizzabile
- Icone e colori intuitivi per ogni funzione

### ⚡ Funzionalità avanzate

- **Selezione multipla**: Seleziona più script da eseguire in sequenza
- **Ricerca in tempo reale**: Filtra gli script per nome o descrizione
- **Log integrato**: Visualizza i log in tempo reale con colori
- **Progress bar**: Monitora l'avanzamento delle esecuzioni batch
- **Controlli avanzati**: Pausa, riprendi e stop durante l'esecuzione

### 📊 Informazioni di sistema

- Pannello informativo sempre visibile con dettagli del sistema
- Rilevamento automatico versione Windows e compatibilità
- Monitoraggio risorse di sistema in tempo reale

## 🚀 Come usare

### Prerequisiti

- Windows 10/11
- PowerShell 5.1 o superiore
- Diritti amministrativi (per alcuni script)

### Avvio

1. Esegui `WinToolkit-Gui.ps1` come amministratore
2. Se non hai i privilegi necessari, lo script li richiederà automaticamente

### Utilizzo base

1. **Seleziona gli script** usando le checkbox nelle varie categorie
2. **Cerca script specifici** usando la barra di ricerca
3. **Esegui singoli script** cliccando sui pulsanti colorati
4. **Esegui batch** usando il pulsante "▶️ Esegui Selezionati"

### Controlli avanzati

- **🔄 Aggiorna**: Aggiorna le informazioni di sistema
- **☑️ Seleziona Tutto**: Seleziona tutti gli script disponibili
- **☐ Deseleziona**: Deseleziona tutti gli script
- **📂 Log**: Apre la cartella contenente i file di log
- **⏸️ Pausa**: Sospende temporaneamente l'esecuzione batch
- **▶️ Riprendi**: Riprende l'esecuzione dopo la pausa
- **⏹️ Stop**: Interrompe definitivamente l'esecuzione

## 📂 Struttura delle categorie

### 🪄 Operazioni Preliminari

- **WinInstallPSProfile**: Installa profilo PowerShell personalizzato

### 🔧 Windows & Office

- **WinRepairToolkit**: Toolkit completo per riparazione Windows
- **WinUpdateReset**: Reset e riparazione Windows Update
- **WinReinstallStore**: Reinstallazione Winget e Microsoft Store
- **WinBackupDriver**: Backup completo driver di sistema
- **WinCleaner**: Pulizia avanzata file temporanei
- **OfficeToolkit**: Gestione completa Microsoft Office

### 🎮 Driver & Gaming

- **WinDriverInstall**: Toolkit driver grafici (in sviluppo)
- **GamingToolkit**: Ottimizzazioni gaming (in sviluppo)

### 🕹️ Supporto

- **SetRustDesk**: Configurazione avanzata RustDesk

## ⚙️ Configurazione

### File di configurazione

Il file `WinToolkit-Gui-Config.ps1` permette di personalizzare:

- Temi e colori dell'interfaccia
- Comportamento degli script
- Impostazioni avanzate di logging
- Timeout e limiti di esecuzione

### Personalizzazione

Modifica il file di configurazione per:

- Aggiungere nuovi script
- Cambiare categorie esistenti
- Personalizzare temi e colori
- Modificare impostazioni avanzate

## 📋 Log e debug

### Sistema di logging

- Log automatici salvati in `%LOCALAPPDATA%\WinToolkit\logs\`
- Log in tempo reale nell'interfaccia grafica
- Rotazione automatica dei file di log
- Dettagli completi di esecuzione

### Risoluzione problemi

1. Controlla i log per errori dettagliati
2. Verifica i privilegi amministrativi
3. Assicurati che PowerShell possa eseguire script
4. Controlla la connessione internet per script che la richiedono

## 🔧 Script di esempio

Ecco come aggiungere un nuovo script nella configurazione:

```powershell
@{
    Name = "MioScript"
    Description = "Descrizione del mio script"
    Category = "Categoria Personalizzata"
    Icon = "🚀"
    Tooltip = "Descrizione dettagliata dello script"
    RequiresAdmin = $true
    EstimatedDuration = "5-10 minuti"
}
```

## 🎯 Funzionalità future

- [ ] Temi completamente personalizzabili
- [ ] Plugin system per script aggiuntivi
- [ ] Export/Import configurazioni
- [ ] Scheduling automatico script
- [ ] Integrazione con Task Scheduler
- [ ] Report dettagliati in formato PDF/Excel

## 🆘 Supporto

Per supporto e segnalazione bug:

- Repository: [GitHub.com/Magnetarman](https://github.com/Magnetarman)
- Documentazione: Consulta i log per dettagli tecnici
- Community: Forum e discussioni sul repository

## 📜 Cronologia versioni

- **v2.2.3 (Build 7)** - GUI Edition
  - Interfaccia grafica completa
  - Sistema di tab per categorie
  - Selezione multipla script
  - Log in tempo reale
  - Controlli avanzati (pausa/stop/riprendi)

## ⚖️ Licenza

Questo progetto mantiene la stessa licenza dell'originale WinToolkit.

---

**Creato da MagnetarMan** | **GUI Edition by Code Assistant** | **Versione 2.2.3 (Build 7)**
