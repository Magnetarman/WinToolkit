# culture="it-IT"
ConvertFrom-StringData -StringData @'

# BEGIN language translations
# -- Informational — status, progress, notes

language.aiTranslated = false
language.code = it-IT
language.name = Italian
language.nativeName = Italiano

# END language translations


# BEGIN menu translations
# -- Informational — status, progress, notes

menu.back = Torna al menu precedente
menu.changeLanguage = Cambia lingua
menu.choice = Selezione
menu.chooseLanguage = Scegli una lingua
menu.closing = Chiusura in corso...
menu.exitSection = Uscita
menu.exitToolkit = Esci dal Toolkit
menu.invalidSelection = Nessuna selezione valida. Riprova.
menu.language = Lingua
menu.languageChanged = Lingua cambiata in {0}.
menu.main = Menu Principale
menu.multiPrompt = Inserisci uno o più numeri (es: 2 3 4 oppure 2,3,4) per eseguire le operazioni in sequenza
menu.multiPromptShort = Inserisci uno o più numeri
menu.noLanguages = Nessun file lingua trovato.
menu.pressEnter = Premi INVIO per tornare al menu...
menu.startedInteractive = WinToolkit avviato in modalità interattiva
menu.support = Per supporto: Github.com/Magnetarman

# END menu translations


# BEGIN system translations
# -- Informational — status, progress, notes

system.architecture = Architettura
system.bitlockerStatus = Stato Bitlocker
system.computerName = Nome PC
system.disk = Disco
system.edition = Edizione
system.free = Libero
system.infoTitle = INFORMAZIONI DI SISTEMA
system.ram = RAM
system.version = Versione

# END system translations


# BEGIN bitlocker translations
# -- Affirmative — positive outcomes (success, completion, confirmations)

bitlocker.status.notConfigured = Non configurato

# -- Informational — status, progress, notes

bitlocker.status.decrypting = Decrittografia in corso
bitlocker.status.encrypting = Crittografia in corso
bitlocker.status.off = Disattivato
bitlocker.status.on = Attivato
bitlocker.status.suspended = Sospeso
bitlocker.status.unknown = Sconosciuto

# END bitlocker translations


# BEGIN confirm translations
# -- Informational — status, progress, notes

confirm.profile.sure = Sei proprio sicuro?

# -- Warning — warnings, cautions, recoverable issues

confirm.profile.accept = Sì, sono sicuro di ciò che sto facendo e me ne assumo la responsabilità in caso di cancellazione di file
confirm.profile.warn1 = ATTENZIONE: eseguendo questa opzione verranno cancellati tutti i profili utenti di Windows, escluso l'utente attuale.
confirm.profile.warn2 = I dati contenuti nei profili eliminati saranno irrecuperabili.
confirm.profile.yes = Sì, cancella i profili utenti

# END confirm translations


# BEGIN run translations
# -- Informational — status, progress, notes

run.sequence = Esecuzione sequenziale di {0} operazioni...
run.start = Avvio: {0}

# -- Warning — warnings, cautions, recoverable issues

run.cancelled = Operazione annullata. Ritorno al menu principale.

# -- Error — errors, failures, critical issues

run.error = Errore durante {0}: {1}

# END run translations


# BEGIN summary translations
# -- Affirmative — positive outcomes (success, completion, confirmations)

summary.completed = Completato

# -- Informational — status, progress, notes

summary.detail = Dettaglio
summary.operation = Operazione
summary.status = Stato
summary.title = Riepilogo Esecuzione

# -- Error — errors, failures, critical issues

summary.error = Errore

# END summary translations


# BEGIN reboot translations
# -- Informational — status, progress, notes

reboot.countdown = Riavvio sistema in
reboot.reminder = Ricorda di riavviare il sistema manualmente per completare le operazioni.
reboot.required = È necessario un riavvio per completare le operazioni.

# END reboot translations


# BEGIN gui translations
# -- Affirmative — positive outcomes (success, completion, confirmations)

gui.complete = Completa

# -- Informational — status, progress, notes

gui.allExecuted = Tutti gli script sono stati eseguiti.
gui.architecture = Architettura: 
gui.availableFunctions = Funzioni disponibili
gui.bitlockerStatus = Stato Bitlocker: 
gui.checking = Verifica.
gui.disk = Disco: 
gui.diskFreeFormat = {0}% libero ({1} GB / {2} GB)
gui.executeScripts = Esegui script
gui.initialized = WinToolkit GUI inizializzato correttamente.
gui.instructions = Seleziona uno o più script e premi 'Esegui script'.
gui.languageLabel = Lingua
gui.limited = Limitata
gui.loading = Caricamento.
gui.noneSelected = Nessuno script selezionato.
gui.outputLogs = Output e log
gui.pcName = Nome PC: 
gui.ram = RAM: 
gui.rebootPrompt = Il sistema richiede un riavvio per completare le operazioni. Riavviare ora?
gui.rebootTitle = Riavvio Richiesto
gui.scriptFeatures = Funzionalità script: 
gui.systemInfo = Informazioni di sistema
gui.unsupported = Non supportata
gui.version = Versione: 
gui.windowsEdition = Edizione Windows: 

# -- Error — errors, failures, critical issues

gui.sendErrorLogs = Invia log errori

# END gui translations


# BEGIN category translations
# -- Informational — status, progress, notes

category.driverGaming = Driver & Gaming
category.office = Office
category.support = Supporto
category.windows = Windows

# END category translations


# BEGIN script translations
# -- Informational — status, progress, notes

script.AutoVideoDriverInstall = Auto Install Driver Video [Nvidia-AMD]
script.DisableBitlocker = Disabilita Bitlocker
script.GamingToolkit = Gaming Toolkit
script.Install-Office = Installa Office Basic
script.Repair-Office = Ripara Office
script.Uninstall-Office = Rimuovi Office
script.VideoDriverReinstall = Reinstalla Driver Video
script.WinBackupDriver = Backup Driver PC
script.WinCleaner = Pulizia File Temporanei
script.WinExportLog = Esporta Log WinToolkit
script.WinReinstallStore = Winget/WinStore Reset
script.WinRepairToolkit = Riparazione Windows
script.WinUpdateReset = Reset Windows Update

# -- Warning — warnings, cautions, recoverable issues

script.WinDeleteUserProfiles = Cancella profili utenti di Windows

# END script translations


# BEGIN sourceText translations
# -- Affirmative — positive outcomes (success, completion, confirmations)

sourceText.alreadyInstalled = già installato
sourceText.alreadyPresent = già presente
sourceText.completed = Completato
sourceText.completed2 = completata
sourceText.completed3 = completati
sourceText.completed4 = completato
sourceText.configured = configurato
sourceText.configured2 = configurata
sourceText.configuredWithPillShapedStyleAndPlayIcon = configurato con stile pill-shaped e icona Play.
sourceText.coreScriptDownloadedSuccessfully = Core Script scaricato con successo.
sourceText.created = creato
sourceText.created2 = creata
sourceText.deleted = eliminata
sourceText.deleted2 = eliminati
sourceText.deleted3 = eliminato
sourceText.downloaded = scaricato
sourceText.downloaded2 = scaricata
sourceText.enabled = attivato
sourceText.enabled2 = attiva
sourceText.enabled3 = abilitato
sourceText.enabled4 = abilitati
sourceText.finished = terminato
sourceText.gitIsAlreadyWorking = Git è già operativo.
sourceText.initializationCompletedGuiReadyToUse = INIZIALIZZAZIONE COMPLETATA - GUI pronta all'uso.
sourceText.installed = Installato
sourceText.menuStructureLoaded = Struttura del menu caricata
sourceText.minificationCompleted = Minificazione completata
sourceText.newerVersionAlreadyPresent = versione superiore già presente
sourceText.operationCompleted = Operazione completata!
sourceText.removed = Rimosso
sourceText.removed2 = Rimossi
sourceText.removed3 = rimosse
sourceText.requiredWindowsDefenderIsEnabled = OBBLIGATORIO: Windows Defender è ATTIVO.
sourceText.resourcesAreReadyStartingTheMainScriptInOfflineMode = Risorse pronte. Avvio dello script principale in modalità offline.
sourceText.restored = ripristinate
sourceText.restored2 = ripristinato
sourceText.runningJobStoppedAndRemoved = Job in corso fermato e rimosso.
sourceText.savedToCache = Salvato in cache
sourceText.supportLogPackageCreated = Pacchetto log supporto creato
sourceText.userConfirmationBypassed = Conferma utente bypassata
sourceText.wingetIsAlreadyWorking = Winget è già operativo.
sourceText.wintoolkitIsReadyOnTheDesktop = WinToolkit è Pronto sul Desktop!

# -- Informational — status, progress, notes

sourceText.aFinalRestartWillBeHandled = Verrà gestito un riavvio finale
sourceText.aForcedDownloadOrFallbackMayBeRequired = Potrebbe essere necessario un download forzato o fallback.
sourceText.age = età
sourceText.alternativeMethod = metodo alternativo
sourceText.andSaveItTo = e salvalo in
sourceText.applyingUnwrapping = Applicazione de-incapsulamento.
sourceText.attempt = Tentativo
sourceText.attempts = tentativi
sourceText.automaticRestart = Riavvio automatico
sourceText.browserOpenedForReportingOnGithub = Browser aperto per la segnalazione su GitHub.
sourceText.categories = categorie
sourceText.changes = modifiche
sourceText.checking = Verifica
sourceText.checkingForMainScript = Verifica presenza script principale
sourceText.checkingWingetFunctionality = Verifica funzionalità Winget.
sourceText.checkScheduledAtNextRestart = controllo schedulato al prossimo riavvio
sourceText.cleaningWingetCache = Pulizia cache Winget.
sourceText.cleanup = Pulizia
sourceText.code = codice
sourceText.compilerPs1PipelineExecutedWithCode = Pipeline compiler.ps1 eseguita con codice
sourceText.configuration = Configurazione
sourceText.continuingAnyway = Proseguo comunque
sourceText.coreScriptContentIsEmptyAfterLoadingAttempts = Core Script content è vuoto dopo i tentativi di caricamento.
sourceText.deepRepair = riparazione profonda
sourceText.deepRepairNotRequired = Riparazione profonda non necessaria
sourceText.defaultResponse = Risposta predefinita
sourceText.defaultValues = valori predefiniti
sourceText.deleting = Eliminazione
sourceText.detected = rilevata
sourceText.detected2 = rilevato
sourceText.detected3 = Rilevati
sourceText.detectedGpu = GPU rilevata
sourceText.detectedInternalFunctionIn = Rilevata funzione interna in
sourceText.detecting = Rilevamento
sourceText.directory = Directory
sourceText.diskC = Disco C
sourceText.download = scaricare
sourceText.download2 = scarica
sourceText.downloadingToUpdate = Download per aggiornare.
sourceText.downloadOf = Download di
sourceText.enabling = Abilitazione
sourceText.execution = Esecuzione
sourceText.exitCode = Codice uscita
sourceText.externalWindow = finestra esterna
sourceText.extracting = Estrazione
sourceText.finalFile = File Finale
sourceText.flagMinifyNotDetected = Flag -Minify non rilevato
sourceText.folder = cartella
sourceText.folders = cartelle
sourceText.forcedMethod = metodo forzato
sourceText.found = Trovati
sourceText.getSysteminfoFunctionAvailable = Funzione Get-SystemInfo disponibile.
sourceText.gpuConfiguration = configurazione GPU
sourceText.gpuNotDetected = GPU non rilevata
sourceText.groupPolicies = criteri di gruppo
sourceText.guiWindowClosedTryingToStopTheRunningJob = Finestra GUI chiusa. Tentativo di fermare il job in corso.
sourceText.in = tra
sourceText.individualRestartSuppressed = Riavvio individuale soppresso
sourceText.inProgress = in corso
sourceText.installation = Installazione
sourceText.interactiveInputDetected = Input interattivo rilevato
sourceText.inUse = in uso
sourceText.loadingCoreFunctionsIntoMemory = Caricamento funzioni Core in memoria
sourceText.loadingModules = Caricamento moduli
sourceText.localCacheExpired = Cache locale scaduta
sourceText.localPolicies = criteri locali
sourceText.mayTake12Minutes = può impiegare 1-2 minuti
sourceText.mayTakeAFewMinutes = può richiedere alcuni minuti
sourceText.minutes = minuti
sourceText.moduleProcessed = Modulo processato
sourceText.modules = moduli
sourceText.moduleStatistics = STATISTICHE MODULI
sourceText.nextBoot = prossimo avvio
sourceText.noGuiOrCoreLogFileFoundForReporting = Nessun file log della GUI o del Core trovato per la segnalazione.
sourceText.noRepairRequired = Nessuna riparazione necessaria
sourceText.normalMode = modalità normale
sourceText.notAccessible = non accessibili
sourceText.note = Nota
sourceText.notSupportedInGuiMode = Non supportato in modalità GUI.
sourceText.of = di
sourceText.on = su
sourceText.operatingSystem = Sistema Operativo
sourceText.operation = operazione
sourceText.package = pacchetto
sourceText.packages = pacchetti
sourceText.pendingOperations = operazioni pendenti
sourceText.pendingOperations2 = operazioni in sospeso
sourceText.pendingOperationsRequiringARestartDetected = Rilevate operazioni pendenti che richiedono riavvio
sourceText.pleaseWaitOperationInProgress = Attendere prego, operazione in corso.
sourceText.policies = Criteri
sourceText.powershell7IsRecommendedForAdvancedFeatures = PowerShell 7 raccomandato per funzionalità avanzate.
sourceText.preparing = Preparazione
sourceText.preparingNextScript = Preparazione prossimo script.
sourceText.pressAnyKeyToContinue = Premi un tasto per continuare
sourceText.pressAnyKeyToExit = Premere un tasto per uscire
sourceText.pressAnyKeyToExit2 = Premi un tasto per uscire.
sourceText.pressEnterToExit = Premi Enter per uscire.
sourceText.processed = Processati
sourceText.readingSourceTemplate = Lettura template originario
sourceText.reduction = Riduzione
sourceText.reEnabling = Riabilitazione
sourceText.registry = registro
sourceText.registryKey = chiave di registro
sourceText.registryKeys = chiavi registro
sourceText.reinstallation = Reinstallazione
sourceText.removal = Rimozione
sourceText.repair = Riparazione
sourceText.reset = reimpostato
sourceText.resourceInitializationLoadingCoreScript = INIZIALIZZAZIONE RISORSE - Caricamento Core Script.
sourceText.restart = Riavvio
sourceText.restartIn = Riavvio in
sourceText.restartingWithAdministratorPrivileges = Riavvio con privilegi amministratore.
sourceText.restartNotRequired = Riavvio non necessario
sourceText.restartRequired = Riavvio necessario
sourceText.restoring = Ripristino
sourceText.runningSystemIntegrityChecks = Esecuzione controlli di integrità sistema
sourceText.safeMode = modalità provvisoria
sourceText.savingStandaloneExecutable = Salvataggio eseguibile stand-alone
sourceText.scheduledTasks = attività pianificate
sourceText.searching = Ricerca
sourceText.searchingForTheLatestWindowsTerminalInstallerOnGithub = Ricerca installer Windows Terminal più recente su GitHub.
sourceText.selectedScript = Script selezionato
sourceText.service = servizio
sourceText.services = servizi
sourceText.shortcuts = collegamenti
sourceText.sources = sorgenti
sourceText.sources2 = Sorgenti
sourceText.started = avviato
sourceText.starting = Avvio
sourceText.starting2 = Avvio
sourceText.startingAggregation = Inizio aggregazione
sourceText.startingConfiguration = Avvio configurazione
sourceText.startingExecution = Avvio esecuzione
sourceText.startingInstallation = Avvio installazione
sourceText.startingOfflineEnvironmentPreparation = Avvio preparazione ambiente offline.
sourceText.startingProcess = Avvio processo
sourceText.startingRemoval = Avvio rimozione
sourceText.startingRepair = Avvio riparazione
sourceText.startingSafeMinificationThroughThePowershellTokenizer = Avvio minificazione sicura via tokenizer PowerShell.
sourceText.startingService = Avvio servizio
sourceText.startingWingetDatabaseRestore = Avvio ripristino database Winget.
sourceText.startingWintoolkitBuildProcess = Avvio processo di build WinToolkit.
sourceText.startup = Avvio:
sourceText.status = Stato
sourceText.stopped = arrestato
sourceText.stopped2 = interrotto
sourceText.stopping = Arresto
sourceText.storageAndCompression = STORAGE E COMPRESSIONE
sourceText.succeeded = riuscita
sourceText.summary = Riepilogo
sourceText.summaryBuildDashboard = BUILD DASHBOARD RIEPILOGATIVA
sourceText.system = sistema
sourceText.systemIsHealthy = Sistema in salute
sourceText.systemRestart = Riavvio del sistema
sourceText.systemRestart2 = Riavvio sistema
sourceText.tasks = attività
sourceText.theSourceContains = Il sorgente contiene
sourceText.tip = Suggerimento
sourceText.tipManuallyDownloadWintoolkitPs1From = Suggerimento: Scarica manualmente WinToolkit.ps1 da:
sourceText.totalCheckboxes = checkbox totali.
sourceText.uninstallation = Disinstallazione
sourceText.updating = Aggiornamento
sourceText.user = Utente
sourceText.usingLocalCache = Utilizzo cache locale
sourceText.validation = Validazione
sourceText.version = Versione
sourceText.videoDriver = driver video
sourceText.waitingForCompletion = Attesa completamento
sourceText.waitingForStartup = Attesa avvio
sourceText.wingetIsPresentButIsNotRespondingCorrectly = Winget presente ma non risponde correttamente

# -- Warning — warnings, cautions, recoverable issues

sourceText.cancelled = annullata
sourceText.cancelled2 = annullato
sourceText.cancelling = Annullamento
sourceText.driverNotAvailableForAutomaticInstallation = driver non disponibile per l'installazione automatica
sourceText.filesSkippedBecauseTheyAreInUseOrNotAccessible = file ignorati perché in uso o non accessibili
sourceText.getSysteminfoFunctionNotFound = Funzione Get-SystemInfo NON trovata!
sourceText.internetConnectionNotAvailableOfflineMode = Connessione Internet: Non disponibile (modalità offline).
sourceText.isNotPresentIn = modificato non è presente in
sourceText.notAvailable = non disponibile
sourceText.notFound = non trovato
sourceText.notFound2 = non trovata
sourceText.notFoundAfterLoading = non trovato dopo il caricamento
sourceText.notPresent = non presente
sourceText.pressAnyKeyToCancel = Premi un tasto qualsiasi per annullare
sourceText.skipped = Saltati
sourceText.unableTo = Impossibile
sourceText.unableToExtractVersion = Impossibile estrarre versione
sourceText.unableToLoadOrDownloadTheWindowIcon = Impossibile caricare o scaricare l'icona della finestra
sourceText.unableToOpenTheBrowser = Impossibile aprire il browser
sourceText.warning = Avviso
sourceText.warning2 = Attenzione
sourceText.warningGitWasNotInstalledOrMayNotWorkCorrectly = Attenzione: Git non è stato installato oppure potrebbe non funzionare correttamente.

# -- Error — errors, failures, critical issues

sourceText.criticalError = Errore critico
sourceText.criticalErrorDuringSetup = Errore critico durante il setup
sourceText.criticalErrorWhileLoadingCore = ERRORE CRITICO durante caricamento Core
sourceText.dismMayFail = DISM potrebbe fallire
sourceText.downloadFailed = Download fallito
sourceText.errorDuring = Errore durante
sourceText.errorDuringLoadedInitialization = Errore durante inizializzazione Loaded
sourceText.errorReadingCheckbox = Errore lettura checkbox
sourceText.errorReadingLocalCacheVersion = Errore lettura versione cache locale
sourceText.errorRetrievingSystemInformation = Errore nel recupero informazioni sistema
sourceText.errorRetrievingTheWindowsTerminalReleaseFromGithub = Errore nel recupero release Windows Terminal da GitHub
sourceText.errors = Errori
sourceText.errorSendingLogs = Errore invio log
sourceText.errorStartingJob = Errore avvio job
sourceText.errorTheScript = Errore: Lo script
sourceText.errorWhileDotSourcingCore = Errore durante dot-sourcing Core
sourceText.errorWhileStoppingTheJob = Errore durante l'interruzione del job
sourceText.errorWhileTestingWinget = Errore durante test Winget
sourceText.exception = Eccezione
sourceText.failed = fallito
sourceText.failed2 = fallita
sourceText.failed3 = falliti
sourceText.failedAfter = fallito dopo
sourceText.failedFor = fallito per
sourceText.failedToRetrieveRemoteVersion = Fallito recupero versione remota
sourceText.initializationError = Errore di inzializzazione
sourceText.installationError = Errore installazione
sourceText.iOErrorWhileAggregatingModule = Errore I/O aggregando il modulo
sourceText.iOErrorWhileReadingSourceFiles = Errore I/O durante la lettura dei file sorgente
sourceText.noSyntaxErrorsDetected = nessun errore di sintassi rilevato
sourceText.offlineResourcePreparationFailedCannotContinue = La preparazione delle risorse offline è fallita. Impossibile procedere.
sourceText.postMinificationSyntaxErrorSRollingBackToOriginalSource = errore/i sintassi post-minificazione - rollback al sorgente originale.
sourceText.preExistingParseErrorSMinificationAppliedAnyway = errore/i di parse pre-esistenti. Minificazione applicata comunque.
sourceText.preparingGuiErrorLogsForReporting = Preparazione log errori GUI per la segnalazione.
sourceText.quickRepairFailedTryingAdvancedMethod = Ripristino veloce fallito. Tentativo metodo avanzato
sourceText.repairModuleFailed = Modulo Riparazione fallito
sourceText.shortcutCreationError = Errore creazione scorciatoia
sourceText.theScriptWillContinueButPackageInstallationMayFail = Lo script proseguirà, ma l'installazione di pacchetti potrebbe fallire.
sourceText.thisIsNotACriticalError = Questo non è un errore critico
sourceText.unexpectedError = Errore imprevisto
sourceText.unexpectedErrorDuringMinification = Errore imprevisto durante la minificazione
sourceText.unknownError = Errore sconosciuto

# END sourceText translations


# BEGIN verb translations
# -- Affirmative — positive outcomes (success, completion, confirmations)

verb.complete = Complete

# -- Informational — status, progress, notes

verb.active = Active
verb.backup = Backup
verb.block = Block
verb.check = Check
verb.clean = Clean
verb.compress = Compress
verb.configure = Configure
verb.copy = Copy
verb.create = Create
verb.delete = Delete
verb.detect = Detect
verb.disable = Disable
verb.download = Download
verb.enable = Enable
verb.export = Export
verb.extract = Extract
verb.found = Found
verb.inactive = Inactive
verb.inProgress = In progress
verb.install = Install
verb.move = Move
verb.note = Note
verb.notRequired = Not required
verb.operational = Operational
verb.prepare = Prepare
verb.present = Present
verb.reenable = Re-enable
verb.reinstall = Reinstall
verb.remove = Remove
verb.repair = Repair
verb.required = Required
verb.reset = Reset
verb.restart = Restart
verb.restore = Restore
verb.run = Run
verb.search = Search
verb.skip = Skip
verb.start = Start
verb.stop = Stop
verb.tip = Tip
verb.uninstall = Uninstall
verb.update = Update
verb.wait = Wait

# -- Warning — warnings, cautions, recoverable issues

verb.cancel = Cancel
verb.notFound = Not found
verb.notPresent = Not present
verb.warning = Warning

# -- Error — errors, failures, critical issues

verb.fail = Fail

# END verb translations


# BEGIN noun translations
# -- Informational — status, progress, notes

noun.archive = Archive
noun.attempt = Attempt
noun.cache = Cache
noun.change = Change
noun.code = Code
noun.component = Component
noun.computer = Computer
noun.directory = Directory
noun.disk = Disk
noun.driver = Driver
noun.exitCode = Exit code
noun.file = File
noun.folder = Folder
noun.font = Font
noun.gpu = GPU
noun.icon = Icon
noun.log = Log
noun.operation = Operation
noun.package = Package
noun.pendingOperation = Pending operation
noun.policy = Policy
noun.profile = Profile
noun.registry = Registry
noun.registryKey = Registry key
noun.script = Script
noun.service = Service
noun.shortcut = Shortcut
noun.status = Status
noun.summary = Summary
noun.system = System
noun.task = Task
noun.tool = Tool
noun.update = Update
noun.user = User
noun.version = Version
noun.videoDriver = Video driver
noun.window = Window

# -- Error — errors, failures, critical issues

noun.exception = Exception

# END noun translations


# BEGIN toolText translations
# -- Affirmative — positive outcomes (success, completion, confirmations)

toolText.0DeletedCaches = {0} cache eliminate.
toolText.0ItemsNotRemovedMayBeBlockedByOpenSessionsOrHandles = {0} elementi non rimossi potrebbero essere bloccati da sessioni o handle aperti.
toolText.0OfficeFoldersRemoved = {0} cartelle Office rimosse.
toolText.0OfficeLinksRemoved = {0} collegamenti Office rimossi.
toolText.0OfficeRegistryKeysRemoved = {0} chiavi registro Office rimosse.
toolText.0OfficeTasksRemoved = {0} attività Office rimosse.
toolText.0Service1ConfiguredAs2 = {0} Servizio {1} configurato come {2}.
toolText.0Service1Restored = {0} Servizio {1} ripristinato.
toolText.0Service1StartedSuccessfully = {0} Servizio {1}: avviato correttamente.
toolText.archiveSavedToDesktop = Archivio salvato sul desktop.
toolText.attemptingFullRepairOnlineAsAFallback = 🌐 Tentativo riparazione completa (online) come fallback.
toolText.autostart0RemovedFromRegistry = Avvio automatico '{0}' rimosso dal registro.
toolText.autostartLink0Removed = Collegamento avvio automatico '{0}' rimosso.
toolText.autoVideoDriverInstallFinished = 🎯 Auto Video Driver Install terminato.
toolText.batchSwitchToNormalModeBatCreatedOnDesktop = Batch 'Switch to Normal Mode.bat' creato sul Desktop.
toolText.battleNetDownloaded = Battle.net scaricato.
toolText.cleaningCompleted = Pulizia completata.
toolText.clientsInstalled = Client installati.
toolText.completed = COMPLETED
toolText.completed2 = Completato!
toolText.completedResidualFolder01 = CARTELLA RESIDUO COMPLETATA - {0} - {1}
toolText.compressionCompleted0MbReduction1 = Compressione completata: {0} MB (Riduzione: {1}%).
toolText.criteriaRemoved = ✅ Criteri eliminati.
toolText.debloatOperationsCompleted = ✅ Operazioni di debloat completate.
toolText.decryptionStartedCompletedSuccessfully = ✅ Decrittazione avviata/completata con successo.
toolText.directory0PartiallyDeleted = Directory {0} parzialmente eliminata.
toolText.directRemovalCompleted = ✅ Rimozione diretta completata.
toolText.directxDownloaded = DirectX scaricato.
toolText.directxInstallation = 🎮 Installazione DirectX.
toolText.driverBackupCompletedSuccessfully = 🎉 Backup driver completato con successo!
toolText.driverBackupToolkitFinished = 🎯 Driver Backup Toolkit terminato.
toolText.exportCompleted0Driver1Mb = Esportazione completata: {0} driver ({1} MB).
toolText.extractionCompleted = Estrazione completata.
toolText.gameClientInstallation = 🎮 Installazione client di gioco.
toolText.gamingToolkitCompleted = Gaming Toolkit completato!
toolText.getHelpCompletedSuccessfully = ✅ Get Help completato con successo.
toolText.installationCompleted = ✅ Installazione completata.
toolText.installed0 = Installato: {0}
toolText.installingBattleNet = 🎮 Installazione Battle.net.
toolText.logsCompressedSuccessfullySavedFile0OnDesktop = Log compressi con successo! File salvato: '{0}' sul Desktop.
toolText.microsoftStoreReinstalledVia0 = Microsoft Store reinstallato tramite {0}.
toolText.microsoftStoreRestoredViaEmergencyMethod = Microsoft Store ripristinato tramite metodo di emergenza.
toolText.microsoftStoreSuccessfullyRestored = Microsoft Store ripristinato correttamente.
toolText.netframeworkEnabled = NetFramework abilitato.
toolText.netframeworkFeatureEnabled0 = Feature NetFramework abilitata: {0}.
toolText.noRemovableRegisteredProfilesFound = ✅ Nessun profilo registrato rimovibile trovato.
toolText.noRemovableResidualFolderFoundInCUsers = ✅ Nessuna cartella residua rimovibile trovata in C:\\Users.
toolText.officeclicktorunExeNotFoundOfficeMayNotBeInstalled = OfficeClickToRun.exe non trovato. Office potrebbe non essere installato.
toolText.officeInstallFinished = 🎯 Office Install terminato.
toolText.officeRemovalComplete = 🎉 Rimozione Office completata!
toolText.officeRepairComplete = 🎉 Riparazione Office completata!
toolText.officeRepairFinished = 🎯 Office Repair terminato.
toolText.officeUninstallFinished = 🎯 Office Uninstall terminato.
toolText.operationCompleted = 🎉 Operazione completata.
toolText.operationsCompletedSuccessfully0 = Operazioni completate con successo: {0}.
toolText.planActivated = Piano attivato.
toolText.planCreated = Piano creato.
toolText.registeredProfilesRemoved0 = ✅ Profili registrati rimossi: {0}
toolText.reinstalled0 = Reinstallato: {0}.
toolText.reinstallingXboxGameBarApp = 🎮 Reinstallazione Xbox Game Bar & App.
toolText.removalNotCompleted = Rimozione non completata.
toolText.removed0 = Rimosso: {0}
toolText.removed02 = Rimosso: {0}.
toolText.repairCompletedSuccessfully = 🎉 Riparazione completata con successo!
toolText.residualFoldersRemoved0 = ✅ Cartelle residue rimosse: {0}
toolText.restartRecommendedToCompleteCleanupOfUnremovedProfiles = Riavvio consigliato per completare la pulizia dei profili non rimossi.
toolText.runtimesCompleted = Runtime completati.
toolText.safeModeConfiguredForNextBoot = Modalità provvisoria configurata per il prossimo avvio.
toolText.service0OptimizedSuccessfully = Servizio {0} ottimizzato correttamente.
toolText.serviceOptimization01 = Ottimizzazione servizio: {0} ({1}).
toolText.setupComplete = 🎉 Configurazione completata.
toolText.stableDriverDownloadedToDesktop0 = Driver stabile scaricato sul desktop: {0}
toolText.startingOfficeBasicInstallation = 🏢 Avvio installazione Office Basic.
toolText.systemOptimizedForGaming = Sistema ottimizzato per il gaming.
toolText.taskEnabled0 = Task abilitato: {0}.
toolText.telemetryAndPrivacyOfficeDisabled = ✅ Telemetria e Privacy Office disabilitate.
toolText.threadsConfigured0 = 🧵 Thread configurati: {0}
toolText.unableToActivatePlan = Impossibile attivare piano.
toolText.unableToCompletelyDelete0FileInUse = Impossibile eliminare completamente {0} - file in uso.
toolText.unigetUiInstallationFinishedWithCode0 = Installazione UniGet UI terminata con codice: {0}.
toolText.unigetUiInstalled = UniGet UI installato.
toolText.unigetUiInstalledSuccessfully = UniGet UI installato correttamente.
toolText.updatedCriteria = ✅ Criteri aggiornati.
toolText.updatedGroupPolicy = ✅ Criteri di gruppo aggiornati.
toolText.updatedSources = Sorgenti aggiornate.
toolText.versionDetected0 = 🎯 Versione rilevata: {0}.
toolText.videoDriverReinstallFinished = 🎯 Video Driver Reinstall terminato.
toolText.windowsUpdateHasBeenRestoredToDefaultValues = 🎉 Windows Update è stato RIPRISTINATO ai valori predefiniti!
toolText.wingetAvailable = ✅ Winget disponibile.
toolText.wingetRestoredAndOperational = Winget ripristinato e operativo.
toolText.xboxReinstalled = Xbox reinstallati.

# -- Informational — status, progress, notes

toolText.01Starting2 = [{0}/{1}] Avvio {2}.
toolText.01Status2 = {0} {1} - Stato: {2}
toolText.0Code1 = {0}: codice {1}.
toolText.0Reverting1To2 = {0} Ripristino {1} a {2}.
toolText.0Service1StartingOrDelayed = {0} Servizio {1}: avvio in corso o ritardato.
toolText.0Service1Stopped = {0} Servizio {1} arrestato.
toolText.0ServiceProcessing1 = {0} Elaborazione servizio: {1}.
toolText.0V1 = {0} v{1}
toolText.alertsGenerated0 = Avvisi generati: {0}.
toolText.attemptedVia0 = Tentativo tramite: {0}.
toolText.autostartCleaner = 🧹 Pulizia avvio automatico.
toolText.autovideodriverinstallSessionEnded = AutoVideoDriverInstall sessione terminata.
toolText.battleNetProcessDidNotStartProperly = Battle.net: processo non avviato correttamente.
toolText.blockingAutomaticDriversFromWindowsUpdate = Blocco driver automatici da Windows Update.
toolText.chkdskCommandSentRebootToPerformDeepDiskRepair = Comando chkdsk inviato. Riavvia per eseguire la riparazione profonda del disco.
toolText.cleanupGpcacheCacheAndWsusSettings = 🧹 Pulizia cache GPCache e impostazioni WSUS.
toolText.createBackupAndLogDirectories = Directory backup e log create.
toolText.dduExtractedToDesktop = DDU estratto sul Desktop.
toolText.decryptionInProgressInBackground = ⏳ Decrittazione in corso in background.
toolText.deletingLocalPolicies = ⏳ Eliminazione criteri locali.
toolText.directories01 = Directory ({0}/{1})
toolText.directxProcessDidNotStartCorrectly = DirectX: processo non avviato correttamente.
toolText.disablebitlockerSessionEnded = DisableBitlocker sessione terminata.
toolText.doNotDisturbActive = Non disturbare attivo.
toolText.driverWuLockSet = Blocco WU driver impostato.
toolText.elimination0 = Eliminazione {0}
toolText.emergencyAttemptViaAppxmanifest = Tentativo di emergenza tramite AppXManifest.
toolText.energyProfileConfiguration = ⚡ Configurazione profilo energetico.
toolText.excludedProfile01 = Profilo escluso: {0} ({1}).
toolText.existingPlanFound = Piano esistente trovato.
toolText.extractingDduToDesktop = Estrazione DDU sul Desktop.
toolText.finalCleaning = 🧹 Pulizia finale.
toolText.found0OfficePackages = Trovati {0} pacchetti Office.
toolText.getHelpStartedTheRemovalInAnExternalWindowWaitingForCompletion = ⏳ Get Help ha avviato la rimozione in una finestra esterna. Attesa completamento...
toolText.gpuDetected0 = GPU rilevata: {0}.
toolText.gpuNotDetectedOnlyDduWillBePlacedOnTheDesktop = GPU non rilevata: solo DDU verrà posizionato sul Desktop.
toolText.inProgress0Seconds = In corso... ({0} secondi)
toolText.inSafeModeRunDduToCleanTheDriversThenReinstallWithTheDesktopInstallerFinallyUseBatchToRetu = In Safe Mode: esegui DDU per pulire i driver, poi reinstalla con l'installer sul Desktop. Infine usa il batch per tornare alla modalità normale.
toolText.installOfficeSessionEnded = Install-Office sessione terminata.
toolText.intelGpuDownloadDriversManuallyFromIntelIfNecessary = GPU Intel: scarica driver manualmente da Intel se necessario.
toolText.location0 = Posizione: {0}
toolText.noFilesToCompressInBackupDirectory = Nessun file da comprimere nella directory backup.
toolText.noKnownStableDriversFoundIUseAutodetectFallback = Nessun driver stabile conosciuto trovato. Uso fallback autodetect.
toolText.noLogFilesCopiedCheckPermissionsAndThatTheFilesExist = Nessun file log copiato. Verifica i permessi e che i file esistano.
toolText.noProblemsDetected = Nessun problema rilevato.
toolText.noRemovableRegisteredProfilesFound2 = Nessun profilo registrato rimovibile trovato.
toolText.noRemovableResidualFoldersFound = Nessuna cartella residua rimovibile trovata.
toolText.noteARebootIsRequiredToFullyApplyAllChanges = ⚡ Nota: È necessario un riavvio per applicare completamente tutte le modifiche.
toolText.noThirdPartyDriversFoundToExport = Nessun driver di terze parti trovato da esportare.
toolText.officeCacheCleaner = 🧹 Pulizia cache Office.
toolText.officeFolderCleaning = 🧹 Pulizia cartelle Office.
toolText.performingAWindowsUpdateClientReset = ⚡ Esecuzione reset client Windows Update...
toolText.policyUpdate = ⏳ Aggiornamento criteri.
toolText.pressAnyKeyToContinue = Premi un tasto per continuare.
toolText.profileExcludedDueToTimeThreshold0LastUse1 = Profilo escluso per soglia temporale: {0}, ultimo uso {1}.
toolText.rebootRequiredForDeepRepair = Riavvio necessario per riparazione profonda.
toolText.recommendedReboot0 = Riavvio consigliato: {0}
toolText.registeredProfilesSelectedForAutomaticRemoval = Profili registrati selezionati per la rimozione automatica:
toolText.reinstallation0 = Reinstallazione: {0}.
toolText.removingOffice = Rimozione Office
toolText.removingOldArchive = Rimozione archivio precedente.
toolText.removingPreviousBackups = Rimozione backup precedenti.
toolText.repairOfficeSessionEnded = Repair-Office sessione terminata.
toolText.residualFolderExcludedBecauseItIsStillAssociatedWithWin32Userprofile01 = Cartella residua esclusa perché ancora associata a Win32_UserProfile: {0} ({1}).
toolText.residualFolderExcludedBecauseReparsePointSymlink01 = Cartella residua esclusa perché reparse point/symlink: {0} ({1}).
toolText.residualFolderExcludedForProtectedName01 = Cartella residua esclusa per nome protetto: {0} ({1}).
toolText.residualFoldersSelectedForAutomaticRemoval0 = Cartelle residue selezionate per la rimozione automatica: {0}
toolText.restartMicrosoftStoreServices = Restart servizi Microsoft Store.
toolText.restartNotRequired = Riavvio non necessario.
toolText.reverted0BakDllTo1Dll = Ripristinato {0}_BAK.dll a {1}.dll.
toolText.ruleExecution = Esecuzione regole
toolText.serviceStopped0 = Servizio arrestato: {0}.
toolText.sessionStartedOn0 = Sessione avviata su {0}.
toolText.startingRemovalOfResidualFolders = 🧹 Avvio rimozione cartelle residue.
toolText.startingStoreWingetReinstallation = Avvio reinstallazione Store & Winget.
toolText.startResidualFolder01 = AVVIO CARTELLA RESIDUO - {0} - {1}
toolText.storeCacheReset = Cache dello Store ripristinata.
toolText.summaryOfOperations = RIEPILOGO OPERAZIONI
toolText.systemHealthyDeepRepairNotNecessary = Sistema in salute. Riparazione profonda non necessaria.
toolText.temporaryEnvironmentCleaning = 🧹 Pulizia ambiente temporaneo.
toolText.thisOperationMayTakeAFewMinutes = ⏰ Questa operazione può richiedere alcuni minuti.
toolText.totalSize0Mb = Dimensione totale: {0} MB
toolText.uninstallOfficeSessionEnded = Uninstall-Office sessione terminata.
toolText.usingDirectRemovalForWindows1122h2OrEarlier = ⚡ Utilizzo rimozione diretta per Windows 11 22H2 o precedenti.
toolText.videodriverreinstallSessionEnded = VideoDriverReinstall sessione terminata.
toolText.waitingForResourcesToBeReleased = ⏳ Attesa liberazione risorse.
toolText.wevtutilCl01 = Wevtutil cl [{0}]: {1}
toolText.wevtutilSlOutput0 = uscita wevtutil sl: {0}
toolText.winbackupdriverSessionEnded = WinBackupDriver sessione terminata.
toolText.windebloatSessionEnded = WinDebloat sessione terminata.
toolText.winexportlogSessionEnded = WinExportLog sessione terminata.

# -- Warning — warnings, cautions, recoverable issues

toolText.0DllNotFoundAndNoBackupAvailable = ⚠️ {0}.dll non trovato e nessun backup disponibile.
toolText.0Error0x800f0806PendingOperationsThisIsNotACriticalError = ⚠️ {0}: Errore 0x800f0806 (operazioni pendenti). Questo non è un errore critico.
toolText.0FilesIgnoredBecauseTheyAreInUseOrNotAccessible = ⚠️ {0} file ignorati perché in uso o non accessibili.
toolText.0Service1NotFoundOnTheSystem = {0} Servizio {1} non trovato nel sistema.
toolText.0Unable123 = {0} Impossibile {1} {2} - {3}.
toolText.battleNetTimedOut = Timeout Battle.net.
toolText.clearEventlog0 = Cancella registro eventi: {0}
toolText.clearEventlog01 = Cancella registro eventi [{0}]: {1}
toolText.commandTimesOutAfter0Hours = Comando timeout dopo {0} ore.
toolText.directxTimeout = Timeout DirectX.
toolText.disablingAutomaticEncryptionInTheRegistry = ⚙️ Disabilitazione crittografia automatica nel registro.
toolText.driverWuBlockError0IContinueAnyway = ⚠️  Errore blocco WU driver: {0}. Proseguo comunque.
toolText.duration0 = ⏱️ Durata: {0}
toolText.failedToExportSfcCbsLogFileInUse = ⚠️ Impossibile esportare il log CBS di SFC (file in uso).
toolText.gethelpcmdExeNotFound = GetHelpCmd.exe non trovato.
toolText.gpuNotDetectedDriverNotAvailableForAutomaticInstallation = GPU non rilevata: driver non disponibile per l'installazione automatica.
toolText.gpupdateCompletedWithCode0IContinueAnyway = ⚠️  gpupdate completato con codice: {0}. Proseguo comunque.
toolText.gpupdateDidNotRespondIContinueAnyway = ⚠️  gpupdate non ha risposto. Proseguo comunque.
toolText.gpupdateTerminatedWithErrorsOrTimedOut = ⚠️ gpupdate terminato con errori o timeout.
toolText.itemsNotRemoved0 = ⚠️ Elementi non rimossi: {0}
toolText.manageBdeExitCode0BitlockerMayAlreadyBeDownOrInError = ⚠️ Codice uscita manage-bde: {0}. BitLocker potrebbe essere già disattivo o in errore.
toolText.nonInteractiveModeNoConfirmationWillBeRequestedBeforeCancellations = ⚠️ Modalità non interattiva: nessuna conferma verrà richiesta prima delle cancellazioni.
toolText.officePostInstallationConfiguration = ⚙️ Configurazione post-installazione Office.
toolText.officePostRepairSetup = ⚙️ Configurazione post-riparazione Office.
toolText.pendingOperationsRequiringRebootDetectedDismCouldFail2 = ⚠️ Rilevate operazioni pendenti che richiedono riavvio. DISM potrebbe fallire.
toolText.pressAnyKeyToExit = ⌨️ Premere un tasto per uscire.
toolText.remainingFolderCleanupSkipped = Pulizia cartelle residue saltata.
toolText.resetWindowsUpdateSettings = ⚙️ Ripristino impostazioni Windows Update.
toolText.residualFolderCleanupSkippedForSkipresidualfoldercleanupParameter = Pulizia cartelle residue saltata per parametro SkipResidualFolderCleanup.
toolText.resourceCleanupAndWindebloatSessionShutdown = ♻️ Pulizia risorse e chiusura sessione WinDebloat.
toolText.resourceCleanupCompleted = ♻️ Pulizia risorse completata.
toolText.systemDetected0TheScriptIsDesignedForWindows11 = ⚠️ Sistema rilevato: {0}. Lo script è pensato per Windows 11.
toolText.theLogsFolder0WasNotFoundUnableToExport = La cartella dei log '{0}' non è stata trovata. Impossibile esportare.
toolText.unableToCheckBitlockerStatus0 = Impossibile verificare lo stato BitLocker: {0}
toolText.unableToDetectWindowsVersion0 = Impossibile rilevare versione Windows: {0}
toolText.unableToDownloadDduAnnulment = Impossibile scaricare DDU. Annullamento.
toolText.unableToReinstallMicrosoftStoreViaAutomaticMethods = Impossibile reinstallare Microsoft Store tramite metodi automatici.
toolText.unableToRemove0FoldersMayBeInUse = Impossibile rimuovere {0} cartelle (potrebbero essere in uso).
toolText.unigetUiRequireManualVerification = ⚠️ UniGet UI richiedere verifica manuale.
toolText.unlimitedPasswordExpirationSetting = ⚙️ Impostazione scadenza password illimitata.
toolText.waasmedicsvcSettingsReset = ⚙️ Impostazioni WaaSMedicSvc ripristinate.
toolText.warningTheSystemWillRebootIntoSafeMode = ATTENZIONE: Il sistema si riavvierà in modalità provvisoria.
toolText.warningTheSystemWillRestartAutomatically = ⚡ Attenzione: il sistema verrà riavviato automaticamente.
toolText.warningUnableToEnableAutomaticRestart0 = Avviso: Impossibile abilitare riavvio automatico - {0}.
toolText.warningUnableToEnableDriver0 = Avviso: Impossibile abilitare driver - {0}.
toolText.warningUnableToEnableTaskIn01 = Avviso: Impossibile abilitare task in {0} - {1}.
toolText.warningUnableToResetSomePolicies0 = Avviso: Impossibile ripristinare alcuni criteri - {0}.
toolText.warningUnableToResetSomeSettings0 = Avviso: Impossibile ripristinare alcune impostazioni - {0}.
toolText.warningUnableToRestoreService01 = Avviso: Impossibile ripristinare servizio {0} - {1}.
toolText.warningUnableToRestoreSomeRegistryKeys0 = Avviso: Impossibile ripristinare alcune chiavi di registro - {0}
toolText.windowsUpdateClientResetNotCompletedPossibleTimeout = ⚠️ Reset client Windows Update non completato (possibile timeout).
toolText.windowsUpdateServicesReset = ⚙️ Ripristino configurazione servizi Windows Update.
toolText.windowsUpdateSettingsReset = ⚙️ Impostazioni Windows Update ripristinate.
toolText.wingetNotAvailableStartingAutomaticRecovery = ⚠️ Winget non disponibile. Avvio ripristino automatico...
toolText.wingetNotAvailableUnigetUiRequiresWinget = Winget non disponibile. UniGet UI richiede Winget.

# -- Error — errors, failures, critical issues

toolText.01Installation2 = [{0}/{1}] 📦 Installazione: {2}
toolText.0CheckScheduledAtNextReboot = 🔧 {0}: controllo schedulato al prossimo riavvio.
toolText.0DllAlreadyPresentInTheOriginalLocation = 💭 {0}.dll già presente nella posizione originale.
toolText.0ErrorsDetectedNewAttempt = 🔄 {0} errori rilevati. Nuovo tentativo.
toolText.0ShuttingDown1TookTooLongOrFailed = {0} Arresto di {1} ha richiesto troppo tempo o è fallito.
toolText.0Status1Starting2 = 📊 {0} - Stato: {1} | Avvio: {2}.
toolText.archiveMoveError0 = Errore spostamento archivio: {0}
toolText.attemptFailedILlTryForceDeletion = Tentativo fallito, provo con eliminazione forzata.
toolText.attempting01SystemRepair = 🔄 Tentativo {0}/{1} - Riparazione sistema.
toolText.cachetaskDisableError0 = Errore di disabilitazione di CacheTask: {0}
toolText.cachetaskEnableError0 = Errore di abilitazione CacheTask: {0}
toolText.canBeUsedToReinstallAllDriversWithoutRedownloadingThem = 💾 Utilizzabile per reinstallare tutti i driver senza riscaricarli.
toolText.checkByOpeningSettingsUpdateSecurity = 🔧 Verifica aprendo Impostazioni > Aggiornamento e sicurezza.
toolText.checkCriticalSystemServices = 🔍 Verifica servizi di sistema critici.
toolText.checkPresenceOfLogFolder = 📂 Verifica presenza cartella log.
toolText.checkResidualFoldersInTheUsersDirectory = 🔎 Controllo cartelle residue nella directory utenti.
toolText.checkTheLogsForTechnicalDetails = 💡 Controlla i log per dettagli tecnici.
toolText.checkWingetAvailability = 🔍 Verifica disponibilità Winget.
toolText.cleaned0ItemsIn1 = 🗑️ Puliti {0} elementi in {1}.
toolText.cleaningScheduledTasks = 📅 Pulizia attività pianificate.
toolText.cleaningWindowsUpdateStatusBeforeStartingCleanup = 🔧 Pulizia stato Windows Update prima di avviare Cleanup...
toolText.cmdkeyDelete0Error1 = tasto cmdeliminazione errore [{0}]: {1}
toolText.cmdkeyListError0 = errore nell'elenco dei tasti cmd: {0}
toolText.commandExecution0 = 🚀 Esecuzione comando: {0}.
toolText.compressingLogsSomeFilesInUseMayBeIgnored = 🗜️ Compressione dei log in corso. Potrebbe essere ignorato qualche file in uso.
toolText.computer0 = 🖥️ Computer: {0}
toolText.criticalError0SeeTheLogInLocalappdataWintoolkitLogsOrIn1 = 💥 Errore critico: {0}. Consulta il log in %LOCALAPPDATA%\\WinToolkit\\logs o in {1}
toolText.criticalErrorDuringDriverReinstallation0 = Errore critico durante reinstallazione driver: {0}
toolText.criticalErrorInInstallOffice = Errore critico in Install-Office
toolText.criticalErrorInRepairOffice = Errore critico in Repair-Office
toolText.criticalErrorInUninstallOffice = Errore critico in Uninstall-Office
toolText.criticalErrorRepairingOffice0 = Errore critico durante riparazione Office: {0}
toolText.criticalErrorWhileRemovingOffice0 = Errore critico durante rimozione Office: {0}
toolText.currentUserProtected0 = 👤 Utente corrente protetto: {0}
toolText.dduExtractionError0 = Errore estrazione DDU: {0}.
toolText.deletionOfWindowsUpdateComponents = 🗂️ Eliminazione componenti Windows Update.
toolText.detailsOfErrorsAndWarnings = Dettaglio Errori e Warning:
toolText.detectingGpuConfiguration = 🔍 Rilevamento configurazione GPU in corso...
toolText.directory0Deleted = 🗑️ Directory {0} eliminata.
toolText.directory0DeletedForcedMethod = 🗑️ Directory {0} eliminata (metodo forzato).
toolText.directory0NotPresent = 💭 Directory {0} non presente.
toolText.disasterRecoveryFailed0 = Ripristino di emergenza fallito: {0}.
toolText.doNotDisturbActivation = 🔕 Attivazione Non disturbare.
toolText.downloadFailedInstallationCancelled = Download fallito. Installazione annullata.
toolText.driversViaWindowsUpdateEnabled = 🖨️ Driver tramite Windows Update abilitati.
toolText.enableWindowsUpdateAutomaticRestart = 🔄 Abilitazione riavvio automatico Windows Update.
toolText.enablingDriversViaWindowsUpdate = 🖨️ Abilitazione driver tramite Windows Update.
toolText.enablingNetframework = 🔧 Abilitazione NetFramework.
toolText.enablingWindowsUpdateAndRelatedServices = 🔧 Abilitazione Windows Update e servizi correlati.
toolText.environmentInitializationError0 = Errore inizializzazione ambiente: {0}
toolText.error = Errore!
toolText.error0 = ❌ Errore: {0}
toolText.error01 = Errore {0} : {1}.
toolText.errorAlsoDuringOnlineRepair0 = Errore anche durante riparazione online: {0}.
toolText.errorCopyingFiles0 = Errore durante la copia dei file: {0}.
toolText.errorDuringDirectxInstallation0 = Errore durante installazione DirectX: {0}
toolText.errorDuringDriverInstallation0 = Errore durante installazione driver: {0}
toolText.errorDuringEnergyPlanActivation0 = Errore durante attivazione piano energetico: {0}.
toolText.errorDuringEnergyPlanDuplication0 = Errore durante duplicazione piano energetico: {0}
toolText.errorDuringFocusAssistConfiguration0 = Errore durante configurazione Focus Assist: {0}
toolText.errorDuringGetHelpProcess0 = Errore durante processo Get Help: {0}.
toolText.errorDuringQuickRepair0 = Errore durante riparazione rapida: {0}.
toolText.errorEditingRegistry0 = Errore durante la modifica del registro - {0}.
toolText.errorEnablingNetframework0 = Errore durante abilitazione NetFramework: {0}.
toolText.errorEnablingNetframeworkFeature0Code1 = Errore abilitazione feature NetFramework {0}: codice {1}.
toolText.errorExportingDriver0 = Errore durante esportazione driver: {0}
toolText.errorExtractingArchiveGetHelp0 = Errore durante estrazione archivio Get Help: {0}.
toolText.errorInAutovideodriverinstall = Errore in AutoVideoDriverInstall
toolText.errorInstallingBattleNet0 = Errore durante installazione Battle.net: {0}
toolText.errorInstallingOffice0 = Errore durante installazione Office: {0}
toolText.errorInstallingUnigetUi0 = Errore durante installazione UniGet UI: {0}.
toolText.errorInVideodriverreinstall = Errore in VideoDriverReinstall
toolText.errorOptimizing01 = Errore durante l'ottimizzazione di {0}: {1}.
toolText.errorRestartingService0 = Errore durante riavvio servizio: {0}
toolText.errorRunningGetHelp0SwitchingToAlternativeMethod = Errore durante esecuzione Get Help: {0}. Passaggio a metodo alternativo.
toolText.errorSchedulingChkdskForDeepRepair = ❌ Errore durante la schedulazione di chkdsk per la riparazione profonda.
toolText.errorsEncountered0 = Errori riscontrati: {0}.
toolText.errorStoppingService0 = Errore durante arresto servizio: {0}
toolText.errorWhileDirectlyRemovingOffice0 = Errore durante rimozione diretta Office: {0}.
toolText.exception01 = Eccezione {0} : {1}.
toolText.extractionGetHelp = 📦 Estrazione Get Help.
toolText.failedResidualFolder0 = CARTELLA RESIDUA ERRATA - {0}
toolText.failedToCreateFile0 = Impossibile creare il file: {0}
toolText.failedToCreateParentDirectory0 = Impossibile creare la directory principale: {0}
toolText.failedToCreateSafeModeBatch0 = Impossibile creare batch Safe Mode: {0}.
toolText.failedToNormalizeRegisteredProfileLocalpath0 = Impossibile normalizzare LocalPath profilo registrato: {0}
toolText.finalArchive0 = 📁 Archivio finale: {0}
toolText.finalCheckOfTheStatusOfTheServices = 🔍 Verifica finale dello stato dei servizi.
toolText.getHelpFailed0AttemptedAlternativeMethod = Get Help fallito: {0}. Tentativo metodo alternativo.
toolText.gpcacheCacheDeleted = 🗑️ Cache GPCache eliminata.
toolText.gpcacheCacheNotPresent = 💭 Cache GPCache non presente.
toolText.individualRestartSuppressedAFinalRebootWillBeHandled = 🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale.
toolText.initializingBackupEnvironment = 🗂️ Inizializzazione ambiente backup.
toolText.initializingDriveCDecryption = 🚀 Inizializzazione decrittazione drive C:.
toolText.initializingTheWindowsUpdateResetScript = 🔧 Inizializzazione dello Script di Reset Windows Update.
toolText.installationError0Code1 = Errore installazione {0} (codice: {1}).
toolText.installationFailed = Installazione fallita.
toolText.installingNetRuntimeAndVcredist = 🔥 Installazione runtime .NET e VCRedist.
toolText.lastActivityThresholdProfilesNotUsedForAtLeast0Days = 📅 Soglia ultima attività: profili non usati da almeno {0} giorni.
toolText.launchQuickRepairOffline = 🔧 Avvio riparazione rapida (offline).
toolText.log0 = 📄 Log: {0}
toolText.method0Failed1 = Metodo {0} fallito: {1}.
toolText.method0FailedExitcode1 = Metodo {0} non riuscito (ExitCode: {1}).
toolText.microsoftStoreNotRestored = ❌ Microsoft Store non ripristinato.
toolText.movingArchiveToDesktop = 📂 Spostamento archivio su desktop.
toolText.noRegistryKeysToRemove = 🔑 Nessuna chiave di registro da rimuovere.
toolText.officeRegistryCleaner = 🔧 Pulizia registro Office.
toolText.officeResidueCleaning = 💽 Pulizia residui Office.
toolText.packetVerificationError01 = Errore verifica pacchetto {0}: {1}
toolText.pendingOperationsRequiringRebootDetectedDismCouldFail = Rilevate operazioni pendenti che richiedono riavvio. DISM potrebbe fallire.
toolText.persistentErrorsDetectedStartDeepRepair = Rilevati errori persistenti. Avvio riparazione profonda.
toolText.planCreationError = Errore creazione piano.
toolText.preparingArchiveCompression = 📦 Preparazione compressione archivio.
toolText.preparingToDownloadTheNecessaryTools = 📥 Preparazione download strumenti necessari...
toolText.profilePath0 = 📁 Percorso profili: {0}
toolText.rebootTheSystemToCompletePendingOperations = 💡 Riavviare il sistema per completare le operazioni in sospeso.
toolText.rehabilitationOfScheduledTasks = 📅 Riabilitazione task pianificati.
toolText.reinstallingMicrosoftStore = 🔄 Reinstallazione Microsoft Store in corso.
toolText.remnantFolderRemovalFailed01 = Rimozione cartella residua fallita: {0} - {1}
toolText.removalViaGetHelp = 🚀 Rimozione tramite Get Help.
toolText.removingOfficeLinks = 🖥️ Rimozione collegamenti Office.
toolText.resetWaasmedicsvcSettings = 🔧 Ripristino impostazioni WaaSMedicSvc.
toolText.resetWindowsLocalPolicies = 📋 Ripristino criteri locali Windows.
toolText.resetWindowsUpdateRegistrySettings = 📋 Ripristino impostazioni registro Windows Update.
toolText.resetWingetUnhandledException0 = Reset-Winget eccezione non gestita: {0}
toolText.restartRecommendedBeforePerformingRepairs = 💡 Consigliato riavviare prima di eseguire le riparazioni.
toolText.restorationOfUpdateServices = 🔄 Ripristino servizi di update.
toolText.restoringRenamedDlls = 🔍 Ripristino DLL rinominate.
toolText.restoringWindowsUpdateRegistryKeys = 📋 Ripristino chiavi di registro Windows Update.
toolText.runspaceError0 = Errore runspace: {0}
toolText.safeModeConfigurationError0 = Errore configurazione Safe Mode: {0}.
toolText.scanningRegisteredLocalProfiles = 🔍 Scansione profili locali registrati in corso.
toolText.searchForOfficeInstallations = 📋 Ricerca installazioni Office.
toolText.searchTheRegistry = 🔍 Ricerca nel registro.
toolText.send0DesktopViaTelegramHttpsTMeMagnetarmanOrEmailMeMagnetarmanComForDiagnostics = 📩 Invia '{0}' (Desktop) via Telegram [https://t.me/MagnetarMan] o email [me@magnetarman.com] per la diagnostica.
toolText.servicesRegistryAndPoliciesHaveBeenConfiguredSuccessfully = 🔄 Servizi, registro e criteri sono stati configurati correttamente.
toolText.sessionCompletedProfilesRemoved0ResidualFoldersRemoved1Errors2Duration3 = Sessione completata. Profili rimossi: {0}. Cartelle residue rimosse: {1}. Errori: {2}. Durata: {3}.
toolText.sfcLogSavedIn0 = 📄 Log SFC salvato in: {0}
toolText.sourceUpdateError0 = Errore aggiornamento sorgenti: {0}.
toolText.standardResidualFolderRemovalFailed01 = Rimozione standard cartella residua fallita: {0} - {1}
toolText.startAutomaticRemovalOf0RegisteredProfiles = 🚀 Avvio rimozione automatica di {0} profili registrati.
toolText.startDeepRepairOfDiskCOnNextReboot = 🔧 Avvio riparazione profonda del disco C: al prossimo riavvio.
toolText.startingAutomaticVideoDriverInstallation = 🚀 Avvio installazione automatica driver video.
toolText.startingCompleteMicrosoftOfficeRemoval = 🗑️ Avvio rimozione completa Microsoft Office.
toolText.startingInstallationProcess = 🚀 Avvio processo installazione.
toolText.startingOfficeDirectRemoval = 🔧 Avvio rimozione diretta Office.
toolText.startingOfficeRepair = 🔧 Avvio riparazione Office.
toolText.startingServiceDebloatProcess = 🚀 Avvio processo di debloat dei servizi.
toolText.startingVideoDriverReinstallationRepairProcedure = 🔧 Avvio procedura reinstallazione/riparazione driver video.
toolText.startingWindowsUpdateServicesRepair = 🛠️ Avvio riparazione servizi Windows Update.
toolText.startOfEssentialServices = 🚀 Avvio servizi essenziali.
toolText.stoppingOfficeServices = 🛑 Arresto servizi Office.
toolText.summary0Folders1RegistryKeys2Links3TasksRemoved = 📊 Riepilogo: {0} cartelle, {1} chiavi registro, {2} collegamenti, {3} attività rimosse.
toolText.systemInitialization = 🚀 Inizializzazione sistema.
toolText.theSystemRequiresARebootToApplyAllChanges = 💻 Il sistema necessita di un riavvio per applicare tutte le modifiche.
toolText.tipSomeFilesMayBeRecreatedAfterReboot = 💡 Suggerimento: Alcuni file potrebbero essere ricreati dopo il riavvio.
toolText.unableToDownloadAmdInstallerAnnulment = ❌ Impossibile scaricare installer AMD. Annullamento.
toolText.unableToDownloadNvcleanstallAnnulment = ❌ Impossibile scaricare NVCleanstall. Annullamento.
toolText.unableToMarkDiskDirtyFsutil = ❌ Impossibile marcare il disco come dirty (fsutil).
toolText.unexpectedErrorDuringResetWinget0 = Errore imprevisto durante Reset-Winget: {0}.
toolText.unigetUiInstallation = 🔄 Installazione UniGet UI.
toolText.unknownErrorZipFileWasNotCreated = Errore sconosciuto: il file ZIP non è stato creato.
toolText.usingGetHelpMethodForWindows1123h2 = 🚀 Utilizzo metodo Get Help per Windows 11 23H2+.
toolText.warningFailedToDeleteGpcacheCache0 = Avviso: Impossibile eliminare cache GPCache - {0}.
toolText.warningFailedToRemoveWsusSettings0 = Avviso: Impossibile rimuovere impostazioni WSUS - {0}.
toolText.warningFailedToRepair0Dll1 = Avviso: Impossibile ripristinare {0}.dll - {1}.
toolText.warningFailedToRestoreWaasmedicsvc0 = Avviso: Impossibile ripristinare WaaSMedicSvc - {0}.
toolText.windowsBuiltInDriversAreNotExported = 💡 I driver integrati di Windows non vengono esportati.
toolText.windowsLocalPoliciesRestored = 📋 Criteri locali Windows ripristinati.
toolText.windowsUpdateAutomaticRestartEnabled = 🔄 Riavvio automatico Windows Update abilitato.
toolText.windowsUpdateClientResetSuccessfully = 🔄 Client Windows Update reimpostato correttamente.
toolText.windowsUpdateRegistrySettingsReset = 🔑 Impostazioni registro Windows Update ripristinate.
toolText.windowsUpdateServicesStopping = 🛑 Arresto servizi Windows Update.
toolText.windowsUpdateShouldNowWorkNormally = 💡 Windows Update dovrebbe ora funzionare normalmente.
toolText.windowsVersionDetection = 🔍 Rilevamento versione Windows.
toolText.wingetRestoreFailed = ❌ Ripristino Winget fallito.
toolText.wingetRestoreFailedUnableToProceedWithGamingToolkit = ❌ Ripristino Winget fallito. Impossibile procedere con Gaming Toolkit.
toolText.wingetSourcesUpdate = 🔄 Aggiornamento sorgenti Winget.
toolText.wsusSettingsNotPresent = 💭 Impostazioni WSUS non presenti.
toolText.wsusSettingsRemoved = 🔑 Impostazioni WSUS rimosse.
toolText.youCanTryAnAlternativeMethodOrManualRemoval = 💡 Puoi provare un metodo alternativo o rimozione manuale.

# END toolText translations


# BEGIN toolText.extra translations
# -- Affirmative — positive outcomes (success, completion, confirmations)

toolText.extra.01Completed = {0} / {1} completati
toolText.extra.0Completed = {0} completato
toolText.extra.chromiumBrowserCacheCleaner = 🌐 Pulizia Cache Browser Chromium.
toolText.extra.cleanmgrCompleted = ✅ CleanMgr completato.
toolText.extra.cleanmgrConfigurationEnabledForWindowsOldStateflags0066 = ✅ Configurazione CleanMgr attivata per Windows.old (StateFlags0066).
toolText.extra.cleanPrintQueueIn01FilesRemoved = Coda di stampa pulita in {0} ({1} file rimossi)
toolText.extra.cleanupWininetWebcacheCache = 🌐 Pulizia cache WinInet/WebCache.
toolText.extra.commandCompleted = Comando completato.
toolText.extra.commandCompletedWithCode0 = Comando completato con codice {0}
toolText.extra.directxInstalledCode0 = DirectX installato (codice: {0}).
toolText.extra.removalCompleted = Rimozione completata
toolText.extra.repairCompleted = Riparazione completata
toolText.extra.restorePointCleanupCompleted = Pulizia punti di ripristino completata
toolText.extra.service0RestartedSuccessfully = Servizio {0} riavviato con successo
toolText.extra.serviceStoppedAndStateSavedAutoRestartEnabled = Servizio arrestato e stato salvato - riavvio automatico abilitato
toolText.extra.unableToCleanCompletely0 = Impossibile pulire completamente {0}

# -- Informational — status, progress, notes

toolText.extra.0ShadowCopiesDetectedRemovingOld1 = Rilevate {0} shadow copies. Rimozione di {1} vecchie.
toolText.extra.attentionYouAreCleaningWithWindowsUpdateInProgressRefreshYourSystemAndTryAgainToPerformAFu = ATTENZIONE! - Stai effettuando la pulizia con Windows Update in corso. Aggiorna il sistema e riprova per eseguire la pulizia completa
toolText.extra.automaticRestart = Riavvio automatico
toolText.extra.autoVideoDriverInstall = Installazione automatica del driver video
toolText.extra.basicConfiguration = Configurazione Basic
toolText.extra.battleNetCode0 = Battle.net: codice {0}
toolText.extra.checkServiceStatus0 = Verifica stato servizio {0}.
toolText.extra.cleaning0 = Pulizia {0}
toolText.extra.cleaningAndDisablingAiChromeOptguide = 🤖 Pulizia e disattivazione AI Chrome (OptGuide).
toolText.extra.cleanmgrConfiguration = 🧹 Configurazione CleanMgr.
toolText.extra.dduDisplayDriverUninstaller = DDU (programma di disinstallazione del driver dello schermo)
toolText.extra.deviceDriverPackages = Pacchetti driver di dispositivo
toolText.extra.directxInstallation = Installazione DirectX
toolText.extra.disasterRecoveryStore = Ripristino di emergenza Store
toolText.extra.diskCheck = Controllo disco
toolText.extra.dismDriverExport = Esportazione driver DISM
toolText.extra.driverBackupToolkit = Kit di strumenti per il backup dei driver
toolText.extra.exitCode0 = Codice uscita: {0}
toolText.extra.groupPolicyUpdateMayTake12Minutes = Aggiornamento criteri di gruppo (può impiegare 1-2 minuti)
toolText.extra.installation0 = Installazione {0}
toolText.extra.installingBattleNet = Installazione Battle.net
toolText.extra.invalidArchivePath0 = Percorso archivio non valido: {0}
toolText.extra.logProcessing = Elaborazione registro
toolText.extra.multipleStateFilesFoundServiceWillNotBeRestartedAutomatically = Multiple state files found, servizio non verrà riavviato automaticamente
toolText.extra.noShadowCopyDetected = Nessuna shadow copy rilevata.
toolText.extra.officeBasicInstallation = Installazione Office Basic
toolText.extra.onlyOneShadowCopyFoundNoRemovalNecessary = Trovata una sola shadow copy. Nessuna rimozione necessaria.
toolText.extra.preparingToRestartTheSystem = Preparazione riavvio sistema
toolText.extra.profilePathDoesNotExist0 = Il percorso profili non esiste: {0}
toolText.extra.rebootingIn = Riavvio in
toolText.extra.rebootRequired = Riavvio necessario
toolText.extra.rebootToApplyChanges = Riavvio per applicare le modifiche
toolText.extra.remnantCleanupUpdates = Pulizia Residui Aggiornamenti
toolText.extra.removal0 = Rimozione: {0}
toolText.extra.removingOfficeUsingGetHelp = Rimozione Office tramite Get Help
toolText.extra.removingRegisteredProfiles = Rimozione profili registrati
toolText.extra.removingResidualFoldersInCUsers = Rimozione cartelle residue in C:\\Users
toolText.extra.removingWindowsOldCleanmgr = Rimozione Windows.old (CleanMgr)
toolText.extra.restartInSafeModeForDdu = Riavvio in Safe Mode per DDU
toolText.extra.restartRecommendedAfterProfileCleanup = Riavvio consigliato dopo pulizia profili
toolText.extra.runningCleanmgrWithSagerun65 = Esecuzione CleanMgr con /sagerun:65
toolText.extra.safeModeConfigurationBcdedit = Configurazione Safe Mode (bcdedit)
toolText.extra.service0ActiveStopping = Servizio {0} attivo, arresto in corso.
toolText.extra.service0DownCheckRestart = Servizio {0} non attivo, verifica riavvio.
toolText.extra.service0WasNotActivePreviously = Servizio {0} non era attivo precedentemente
toolText.extra.serviceStoppedManualRestartRequired = Servizio arrestato - riavvio manuale richiesto
toolText.extra.spoolerServiceRestarted = Servizio Spooler riavviato.
toolText.extra.spoolerServiceStopped = Servizio Spooler arrestato.
toolText.extra.storeInstallationViaWinget = Installazione Store tramite Winget
toolText.extra.systemFileChecker1 = Controllo file di sistema (1)
toolText.extra.systemFileChecker2 = Controllo file di sistema (2)
toolText.extra.systemRebootIn = Riavvio sistema in
toolText.extra.thoroughDiskCheck = Controllo disco approfondito
toolText.extra.unigetUiInstallation = Installazione UniGet UI
toolText.extra.uninstallation0 = Disinstallazione {0}
toolText.extra.videoDriverReinstall = Reinstallazione del driver video
toolText.extra.waitingForStart0 = Attesa avvio {0}
toolText.extra.windowsImageRecovery = Ripristino immagine Windows

# -- Warning — warnings, cautions, recoverable issues

toolText.extra.backupDirectoryNotFound0 = Directory backup non trovata: {0}
toolText.extra.iTheWindowsOldFolderMayRequireARebootForCompleteRemoval = ℹ️ La cartella Windows.old potrebbe richiedere un riavvio per la rimozione completa.
toolText.extra.registryKeyPreviousInstallationsNotFoundStandardExecutionAttempt = Chiave registro 'Previous Installations' non trovata. Tentativo di esecuzione standard.
toolText.extra.restartingSpoolerService = ▶️ Riavvio servizio Spooler.
toolText.extra.service0NotFoundSkip = Servizio {0} non trovato, skip
toolText.extra.startingService0 = ▶️ Avvio servizio {0}.
toolText.extra.stoppingService0 = ⏸️ Arresto servizio {0}.
toolText.extra.stoppingSpoolerService = ⏸️ Arresto servizio Spooler.
toolText.extra.timeoutReachedDuringDismExport = Timeout raggiunto durante l'esportazione DISM

# -- Error — errors, failures, critical issues

toolText.extra.0NotCompletedAbortedDueToTimeout = {0} NON completato (interrotto per Timeout).
toolText.extra.analysisAndCleaningOfShadowCopiesKeepLatest = 🗑️ Analisi e pulizia shadow copies (mantieni ultima).
toolText.extra.chromeAiPolicySettingError0 = Errore impostazione policy Chrome AI: {0}
toolText.extra.cleaningCredentials = 🔑 Pulizia Credenziali.
toolText.extra.cleaningEventLogsClassicModern = 📜 Pulizia Event Logs (classici + moderni).
toolText.extra.cleaningFirefoxCacheCrashes = 🦊 Pulizia Firefox (Cache & Crashes).
toolText.extra.cleanSystemRestorePoints = 💾 Pulizia punti di ripristino sistema.
toolText.extra.commandError0 = Errore comando: {0}
toolText.extra.criticalErrorDuringBackup = Errore critico durante backup
toolText.extra.directxError0 = DirectX errore: {0}
toolText.extra.errorCleaningRestorePoints0 = Errore durante la pulizia punti di ripristino: {0}
toolText.extra.errorCleaningSpooler0 = Errore durante la pulizia Spooler: {0}
toolText.extra.errorCompressingLogs = Errore durante la compressione dei log
toolText.extra.errorInInvokeRepaircommand0 = Errore in Invoke-RepairCommand [{0}]
toolText.extra.failedToWriteToRegistryForCleanmgr0 = Impossibile scrivere nel registro per CleanMgr: {0}
toolText.extra.genericErrorOrAbendExitcode0 = Errore generico o terminazione anomala (ExitCode: {0}).
toolText.extra.improvedManagementOfDiagtrackService = 🔄 Gestione migliorata servizio DiagTrack.
toolText.extra.noWindowsOldFolderDetected = 💭 Nessuna cartella Windows.old rilevata.
toolText.extra.optguideFolderSetToReadOnly0 = 🔒 Cartella OptGuide impostata in sola lettura: {0}
toolText.extra.printQueueCleaningSpooler = 🖨️ Pulizia coda di stampa (Spooler).
toolText.extra.readOnlySettingErrorFor01 = Errore impostazione read-only per {0} : {1}
toolText.extra.registerError01 = Errore registro {0} : {1}
toolText.extra.removal02 = 🗑️ Rimozione: {0}
toolText.extra.removalError01 = Errore rimozione {0} : {1}
toolText.extra.removedKey0 = 🗑️ Rimossa chiave {0}
toolText.extra.removingOptguideFolder0 = 🗑️ Rimozione cartella OptGuide: {0}
toolText.extra.serviceError01 = Errore servizio {0} : {1}
toolText.extra.shadowCopyManagementError0 = Errore gestione shadow copies: {0}
toolText.extra.systemProtectionKeptActiveForSafety = 💡 Protezione sistema mantenuta attiva per sicurezza
toolText.extra.windowsOldFolderDetectedStartingSafeRemovalWithNativeCleanmgr = 🗑️ Rilevata cartella Windows.old. Avvio rimozione sicura con Native CleanMgr.
toolText.extra.windowsUpdateCacheCleaner = 🔄 Pulizia cache di Windows Update.

# END toolText.extra translations


# BEGIN toolText.extra2 translations
# -- Affirmative — positive outcomes (success, completion, confirmations)

toolText.extra2.oldShadowCopiesRemovedLastPreservedCopy = Vecchie shadow copies rimosse. Ultima copia preservata.
toolText.extra2.optimizedForGamingByWintoolkit = Ottimizzato per Gaming dal WinToolkit
toolText.extra2.printQueueSpoolerCleanedAndRestartedSuccessfully = Print Queue Spooler pulito e riavviato con successo.
toolText.extra2.waitingForCleanmgrToCompleteMayTakeAFewMinutes = ⏳ Attesa completamento CleanMgr (può richiedere alcuni minuti)...
toolText.extra2.windowsOldSuccessfullyRemoved = ✅ Windows.old rimosso con successo.

# -- Informational — status, progress, notes

toolText.extra2.decryptionInProgress = Decriptazione in corso.
toolText.extra2.desktopDirectoryNotAccessible0 = Directory desktop non accessibile: {0}
toolText.extra2.parametersNotSupportedByTheToolVersion = Parametri non supportati dalla versione del tool
toolText.extra2.theScriptMustBeRunFromAPowershellConsoleStartedAsAdministrator = Lo script deve essere eseguito da una console PowerShell avviata come amministratore.

# -- Warning — warnings, cautions, recoverable issues

toolText.extra2.set01 = ⚙️ Impostato {0}\\{1}

# END toolText.extra2 translations


# BEGIN toolText.extra3 translations
# -- Affirmative — positive outcomes (success, completion, confirmations)

toolText.extra3.0CompletedSuccessfully = {0} completed successfully.

# -- Informational — status, progress, notes

toolText.extra3.configuring0 = Configuring {0}
toolText.extra3.starting0 = Starting {0}
toolText.extra3.stopping0 = Stopping {0}

# -- Error — errors, failures, critical issues

toolText.extra3.0CompletedWith1Errors = {0} completato con errori {1}.

# END toolText.extra3 translations


# BEGIN uiText translations
# -- Affirmative — positive outcomes (success, completion, confirmations)

sourceText.completedSuccessfully = Completato con successo
uiText.0AlreadyPresent = {0} già presente.
uiText.0DownloadComplete = Download di '{0}' completato.
uiText.allOfflineResourcesHaveBeenSuccessfullyPrepared = Tutte le risorse offline sono state preparate con successo.
uiText.battleNetInstalled = Battle.net installato.
uiText.browserOpenForReportingOnGithub = 🌐 Browser aperto per la segnalazione su GitHub.
uiText.buildCompletedWithMinorAnomaliesOrSkippedModules = La build è stata completata con anomalie minori o moduli saltati.
uiText.bypassedUserConfirmationFor0DefaultResponseYes = ✅ Conferma utente bypassata per: '{0}'. Risposta predefinita 'Sì'.
uiText.classicAndModernEventLogsDeleted = Event Log classici e moderni cancellati.
uiText.cleanWininetWebcache = ✅ Cache WinInet/WebCache pulita.
uiText.completed = Completato
uiText.completed0 = ✅ Completato: {0}.
uiText.completeOfficeRepairOnline = Riparazione Completa Office (Online)
uiText.configurationComplete = Configurazione completata.
uiText.coreScriptDownloadedSuccessfully = ✅ Core Script scaricato con successo.
uiText.countdownBypassed01Seconds = ⏳ Conto alla rovescia bypassato: '{0}' ({1} secondi).
uiText.createdOfflineResourceDirectory0 = Creata directory risorse offline: {0}.
uiText.deepTestPassedWingetCommunicatesCorrectlyWithRepositories = ✅ Test profondo superato: Winget comunica correttamente con i repository.
uiText.deepValidationPassedWingetCommunicatesWithRepositories = ✅ Validazione profonda superata: Winget comunica con i repository.
uiText.downloadCompleted0 = Download completato: {0}.
uiText.downloaded0 = ✅ Scaricato: {0}.
uiText.dynamicMenuGenerated0Categories = ✅ Menu dinamico generato: {0} categorie.
uiText.environmentReadyForInstallation = Ambiente pronto per l'installazione.
uiText.executebuttonConfiguredWithPillShapedStyleAndPlayIcon = ✅ ExecuteButton configurato con stile pill-shaped e icona Play.
uiText.functionsAvailableTuiMenuSuppressed = ✅ Funzioni disponibili, menu TUI soppresso
uiText.getSysteminfoFunctionAvailable = ✅ Funzione Get-SystemInfo disponibile.
uiText.git251064BitExeAlreadyExists = Git-2.51.0-64-bit.exe già presente.
uiText.gitAlreadyInstalled = Git già installato.
uiText.gitInstalledSuccessfully = Git installato con successo.
uiText.gitInstalledViaWinget = Git installato via winget.
uiText.gitIsAlreadyOperational = ✅ Git è già operativo.
uiText.iconAvailabilityCheckCompleted = 🎉 Verifica disponibilità icona completata.
uiText.initializationCompleteGuiReadyToUse = 🎉 INIZIALIZZAZIONE COMPLETATA - GUI pronta all'uso.
uiText.internetConnectionAvailable = 🌐 Connessione Internet: Disponibile.
uiText.internetConnectionNotAvailableOfflineMode = 🌐 Connessione Internet: Non disponibile (modalità offline).
uiText.iTryNativeAppxInstallationFromDownloadedBundle = Provo installazione nativa Appx da bundle scaricato.
uiText.jetbrainsmonoNerdFontAlreadyInstalled = ✅ JetBrainsMono Nerd Font già installato.
uiText.jobInProgressStoppedAndRemoved = ✅ Job in corso fermato e rimosso.
uiText.loadedDependencies = Dipendenze caricate.
uiText.menuStructureLoadedCategories0 = ✅ Struttura del menu caricata (categorie: {0}).
uiText.microsoftAppInstallerUpdated = ✅ Microsoft.AppInstaller presente e aggiornato.
uiText.nerdFontsInstalledSuccessfully = ✅ Nerd Fonts installati con successo.
uiText.noPendingUpdatesDetected = ✅ Nessun aggiornamento pendente rilevato
uiText.officeOptimizedTelemetryPrivacyAndScheduledTasksRemoved = ✅ Office ottimizzato: telemetria, privacy e task pianificati rimossi.
uiText.operationalWingetVersion0 = ✅ Winget operativo (versione: {0}).
uiText.operationCompleted = 🎉 Operazione completata!
uiText.pathAndWingetPermissionsUpdated = PATH e permessi winget aggiornati.
uiText.pathAndWingetPermissionsUpdated2 = PATH e permessi Winget aggiornati.
uiText.phase1CompletedOperationalWinget = ✅ Fase 1 completata. Winget operativo.
uiText.powershell752WinX64MsiAlreadyPresent = PowerShell-7.5.2-win-x64.msi già presente.
uiText.powershell7AlreadyInstalled = PowerShell 7 già installato.
uiText.powershell7AlreadyPresent = PowerShell 7 già presente.
uiText.powershell7InstalledSuccessfully = PowerShell 7 installato con successo.
uiText.powershell7ProfileConfigured = Profilo PowerShell 7 configurato.
uiText.processed0 = ✅ Elaborato: {0}
uiText.removed0CommentTokens = Rimossi i token dei commenti {0}.
uiText.repairWingetpackagemanagerCompletedHigherVersionAlreadyPresent = Repair-WinGetPackageManager completato (versione superiore già presente).
uiText.repairWingetpackagemanagerIgnoredHigherVersionAlreadyPresent = Repair-WinGetPackageManager ignorato (versione superiore già presente).
uiText.resourcesReadyStartingTheMainScriptInOfflineMode = Risorse pronte. Avvio dello script principale in modalità offline.
uiText.selectedScript0 = ✅ Script selezionato: {0}.
uiText.shortcutCreatedSuccessfully = Scorciatoia creata con successo.
uiText.someOfflineResourcesWereNotDownloadedCheckTheConnectionAndTryAgain = Alcune risorse offline non sono state scaricate. Verificare la connessione e riprovare.
uiText.success = [SUCCESSO]
uiText.successLoaded0 = [SUCCESSO] Caricato: {0}.
uiText.supportLogPackageCreated0 = ✅ Pacchetto log supporto creato: {0}.
uiText.systemInformationPanelUpdated3BlockLayout = Pannello delle informazioni di sistema aggiornato (layout a 3 blocchi).
uiText.systemRestartRequiredToCompleteUpdates = ✓ È necessario riavviare il sistema per completare gli aggiornamenti
uiText.unableToDownloadCoreScriptAndNoCacheAvailableConfiguredForFallback = Impossibile scaricare Core Script e nessuna cache disponibile/configurata per il fallback.
uiText.updatedFolderPermissions0 = Permessi cartella aggiornati: {0}.
uiText.updatedPath0 = PATH aggiornato: {0}.
uiText.updateServicesRestored = Servizi di aggiornamento ripristinati.
uiText.updateServicesSuccessfullySuspended = Servizi di aggiornamento sospesi correttamente.
uiText.url0 = 🌐 URL: {0}.
uiText.validAndUpdatedLocalCacheV0CacheUsage = ✅ Cache locale valida e aggiornata (v{0}). Utilizzo cache.
uiText.vcRedistInstalled = VC++ Redist installato.
uiText.visualCRedistributableAlreadyPresent = Visual C++ Redistributable già presente.
uiText.visualCRedistributableInstalled = Visual C++ Redistributable installato.
uiText.weStronglyRecommendThatYouCompleteAllOngoingUpdates = Si consiglia vivamente di completare tutti gli aggiornamenti in corso,
uiText.windowCreatedSuccessfully = Finestra creata con successo.
uiText.windowsTerminalAppxInstallationSuccessful = Installazione Appx di Windows Terminal riuscita.
uiText.windowsTerminalInstalledViaWinget = Windows Terminal installato via winget.
uiText.windowsTerminalInstaller0AlreadyPresent = Windows Terminal installer ({0}) già presente.
uiText.windowsTerminalIsAlreadyInstalled = Windows Terminal è già installato.
uiText.windowsTerminalSetAsDefault = ✅ Windows Terminal impostato come predefinito.
uiText.windowsTerminalSettingsUpdated0 = Settings Windows Terminal aggiornati ({0}).
uiText.windowsUpdateCacheCleared = La cache di Windows Update è stata cancellata.
uiText.wingetAlreadyOperationalNoRepairsNecessary = ✅ Winget già operativo. Nessuna riparazione necessaria.
uiText.wingetClientModuleInstalled = Modulo WinGet Client installato.
uiText.wingetCoreInstalled = Winget Core installato.
uiText.wingetCoreSuccessfullyInstalled = Winget Core installato con successo.
uiText.wingetDatabaseRestoredVersion0 = ✅ Database Winget ripristinato (versione: {0}).
uiText.wingetInstalledAndWorking = ✅ Winget installato e funzionante.
uiText.wingetinstallerMsixbundleAlreadyPresent = WingetInstaller.msixbundle già presente.
uiText.wingetIsAlreadyOperational = ✅ Winget è già operativo.
uiText.wingetMsixBundleInstallationSuccessful = Installazione Winget MSIX Bundle riuscita.
uiText.wingetNotYetReadyAttempt012SRemainWait = ⏳ Winget non ancora pronto (tentativo {0}/{1}, restano {2} s). Attesa...
uiText.wingetReadyAndDatabaseUnlockedAttempt01 = ✅ Winget pronto e database sbloccato (tentativo {0}/{1}).
uiText.wingetRestoredQuickly = ✅ Winget ripristinato velocemente.
uiText.wingetSuccessfullyRestoredAndTested = ✅ Winget ripristinato e testato con successo.
uiText.wintoolkitIcoAlreadyPresent = WinToolkit.ico già presente.
uiText.wintoolkitProgressTagActivity0StatusCompletedPercent100 = [WINTOOLKIT_PROGRESS_TAG] Attività: {0} | Stato: Completato | Percentuale: 100%.

# -- Informational — status, progress, notes

cleanerRule.adobeMediaBrowserKey = Chiave del browser Adobe Media
cleanerRule.cacheHistoryCleanup = Pulizia della cache/cronologia
cleanerRule.chromiumBrowsersCacheChromeEdgeBraveVivaldi = Cache dei browser Chromium (Chrome, Edge, Brave, Vivaldi)
cleanerRule.cleanmgrConfig = Configurazione CleanMgr
cleanerRule.cleanupExplorerThumbnailIconCache = Pulizia: cache delle miniature/icone di Explorer
cleanerRule.cleanupWindowsPrefetchCache = Pulizia: cache di precaricamento di Windows
cleanerRule.clearWindowsUpdateCache = Svuota la cache di Windows Update
cleanerRule.cookiesCleanup = Pulizia dei cookie
cleanerRule.credentialManager = Gestore credenziali
cleanerRule.developerTelemetryTraces = Telemetria e tracce per sviluppatori
cleanerRule.dnsFlush = Svuotamento DNS
cleanerRule.edgeLegacyHtmlCache = Cache Edge Legacy (HTML).
cleanerRule.emptyRecycleBin = Cestino vuoto
cleanerRule.enhancedDiagtrackManagement = Gestione DiagTrack migliorata
cleanerRule.firefoxBrowserCache = Cache del browser Firefox
cleanerRule.flashPlayerTraces = Tracce di Flash Player
cleanerRule.formDataCleanup = Pulizia dei dati del modulo
cleanerRule.googleChromeAiOptguideModel = Modello OptGuide AI di Google Chrome
cleanerRule.internetCookiesCleanup = Pulizia dei cookie di Internet
cleanerRule.listaryIndex = Indice Listario
cleanerRule.minimizeDism = Riduci al minimo DISM
cleanerRule.operaJavaCache = Cache di Opera e Java
cleanerRule.printQueueSpooler = Coda di stampa (Spooler)
cleanerRule.regeditLastKey = Regedit ultima chiave
cleanerRule.searchHistoryFiles = Cerca file di cronologia
cleanerRule.serviceProfilesTemp = Profili di servizio Temp
cleanerRule.srumData = Dati SRUM
cleanerRule.startDps = Avvia DPS
cleanerRule.stopDps = Interrompi il DPS
cleanerRule.systemComponentLogs = Registri di sistema e componenti
cleanerRule.systemRestorePoints = Punti di ripristino del sistema
cleanerRule.systemTempFiles = File temporanei di sistema
cleanerRule.temporaryInternetFiles = File temporanei Internet
cleanerRule.userRegistryHistoryValuesOnly = Cronologia del registro utenti: solo valori
cleanerRule.userTempFiles = File temporanei dell'utente
cleanerRule.visualStudioLicenses = Licenze di Visual Studio
cleanerRule.windowsAppDownloadCacheUser = Cache download/app Windows - Utente
cleanerRule.windowsOld = Windows.vecchio
cleanerRule.wininetCacheUser = Cache WinInet - Utente
cleanerRule.winsxsCleanup = Pulizia WinSxS
cleanerRule.winutilData = Dati WinUtil
gui.editionVersionsFormat = Edizione GUI v{0} | Core v{1}
gui.hardware = Hardware
sourceText.active = Attivo
sourceText.automatic = Automatico
sourceText.check = controllo
sourceText.configure = configurare
sourceText.file = file
sourceText.inactive = Inattivo
sourceText.lines = linee
sourceText.manual = Manuale
sourceText.start = inizio
toolText.extra.officeSetup = Configurazione dell'ufficio
uiText.01Seconds = {0} - {1} secondi
uiText.0In1 = {0} in {1}
uiText.0In12 = {0} in {1}: {2}
uiText.0In1Seconds = {0} tra {1} secondi
uiText.0OfficeProcessesClosed = {0} processi Office chiusi.
uiText.addingStoreViaDism = Aggiunta Store via DISM
uiText.andSaveItIn0 = e salvalo in: {0}.
uiText.appxManifestStoreRegistration = Registrazione AppX Manifest Store
uiText.attemptingToInstallPowershell7ViaWinget = Tentativo installazione PowerShell 7 via Winget.
uiText.attemptingToInstallWindowsTerminalViaWinget = Tentativo installazione Windows Terminal via winget.
uiText.automaticStartToolkitLogInjectionPolicy0 = Politica: inserimento automatico di Start-ToolkitLog per {0}.
uiText.byMagnetarmanWinToolkitProject = Di MagnetarMan - Progetto Win Toolkit.
uiText.carryingOutBasicChecks = Esecuzione controlli base.
uiText.check0 = Verifica {0}.
uiText.checkForMainScriptStartPs1In0 = Verifica presenza script principale 'start.ps1' in {0}.
uiText.checkingWindowsUpdateLocalScan = Controllo Windows Update (Scansione locale)...
uiText.closingInterferingProcesses = Chiusura processi interferenti.
uiText.closingInterferingProcesses2 = Chiusura processi interferenti...
uiText.command0ExitCode1Duration2 = Comando {0} (Codice di uscita: {1}, Durata: {2})
uiText.commandContext = Contesto del comando
uiText.commandOutput0 = Uscita di comando ({0})
uiText.compatibleSystemRecentWin1110 = Sistema compatibile (Win11/10 recente).
uiText.compatibleSystemWin10 = Sistema compatibile (Win10).
uiText.consoleMinimized = Console ridotta a icona.
uiText.continuingBuildWithoutMinification = Continuare a costruire senza minimizzare.
uiText.coreForJob0 = Base per il lavoro: {0}.
uiText.cpu0 = ⚡ CPU: {0}
uiText.creatingWpfWindow = Creazione della finestra WPF.
uiText.dependencyFound0 = Trovata dipendenza: {0}.
uiText.desktopShortcutCreation = Creazione scorciatoia desktop.
uiText.detected0StableDriverMatchesFromDriveroverridesJson = Rilevate {0} corrispondenze driver stabili da DriverOverrides.json.
uiText.disablingBitlocker = Disattivazione BitLocker
uiText.download02 = Scarica {0}
uiText.download0From1 = Download '{0}' da '{1}'.
uiText.downloadAndInstallWingetBundleWithDependencies = Download e installazione Winget Bundle (con dipendenze).
uiText.downloadIcona = Scarica l'icona.
uiText.downloadInstaller = Scarica il programma di installazione.
uiText.downloadMsixbundleDaMicrosoft = Scarica MSIXBundle da Microsoft.
uiText.downloadWingetDependenciesFromTheOfficialRepository = Download dipendenze Winget dal repository ufficiale.
uiText.downloadWingetDependenciesFromTheOfficialRepository2 = Download dipendenze Winget dal repository ufficiale...
uiText.doYouReallyThinkThisScriptCanDoAnythingForThisVersion = Davvero pensi che questo script possa fare qualcosa per questa versione?
uiText.doYouWantToTakeARiskYN = Vuoi rischiare? [Y/N]
uiText.emptyPrecompiledModule0InsertingDevelopmentStub = Modulo precompilato vuoto: '{0}'. Inserimento stub di sviluppo.
uiText.escExitTheScript = [ESC] Esci dallo script
uiText.esecuzioneRepairWingetpackagemanager = Esecuzione di Repair-WinGetPackageManager.
uiText.executing0Seconds = Esecuzione in corso... ({0} secondi)
uiText.execution0Sec = ⏳ Esecuzione: {0} sec
uiText.existingOfflineResourceDirectory0 = Directory risorse offline esistente: {0}.
uiText.fallbackAperturaMicrosoftStorePerWindowsTerminal = Fallback: Apertura Microsoft Store per terminale Windows.
uiText.fallbackDownloadGitDaGithub = Fallback: scarica Git da GitHub...
uiText.fallbackDownloadMsixbundleDirectFromMicrosoft = Fallback: Download MSIXBundle diretto da Microsoft.
uiText.fileIgnored01 = File ignorato: {0} - {1}
uiText.functionDevelopmentInProgress = Sviluppo delle funzioni in corso.
uiText.gitInstallation = Installazione Git...
uiText.guiVersion0 = Versione GUI: {0}
uiText.info = [INFORMAZIONI]
uiText.infoAdministratorPrivilegesConfirmed = [INFO] Privilegi di amministratore confermati.
uiText.infoLoggingInitializedTo0 = [INFO] Registrazione inizializzata su {0}.
uiText.installingMicrosoftWingetClientModule = Installazione modulo Microsoft.WinGet.Client.
uiText.installingPowershell7InProgress = Installazione PowerShell 7 in corso.
uiText.installingVisualCRedistributable = Installazione Visual C++ Redistributable...
uiText.installingWingetMsixbundleWithDependencies = Installazione Winget MSIXBundle (con dipendenze)...
uiText.interferingProcessesClosed = Processi interferenti chiusi.
uiText.invalidDriveroverridesJson0 = DriverOverrides.json non valido: {0}
uiText.keyPressRetryTheChecks = [Pressione tasto] Riprova i controlli
uiText.line01 = Linea {0}: {1}.
uiText.loadingCoreScript = Caricamento dello script principale.
uiText.loadingForms = Caricamento moduli
uiText.localCacheExpiredAge0MinutesDownloadToUpdate = ⏰ Cache locale scaduta (età: {0} minuti). Download per aggiornare.
uiText.makeSureYouHaveCopiedTheModifiedMainScriptAfterStep2IntoThisDirectory = Assicurati di aver copiato lo script principale modificato (dopo Step 2) in questa directory.
uiText.manifestReRegistrationAppxmanifestXmlPreventsLeaks = Re-registrazione manifest: AppxManifest.xml previene leak.
uiText.microsoftAppInstallerPresentForcingUpdate = Microsoft.AppInstaller già presente. Aggiornamento forzato all'ultima release.
uiText.moduloWingetClient0 = Client Modulo WinGet: {0}.
uiText.noKnownStableDriversFoundForTheDetectedGpus = Nessun driver stabile conosciuto trovato per le GPU rilevate.
uiText.noMsixBundleAssetsFoundForWindowsTerminal = Nessun asset MSIX bundle trovato per Windows Terminal.
uiText.nugetProviderNotInstallable = NuGet provider non installabile.
uiText.operationalWingetVersion02 = Winget operativo (versione: {0}).
uiText.pendingSystemUpdatesHaveBeenDetected = Sono stati rilevati aggiornamenti di sistema pendenti:
uiText.performingSystemIntegrityChecks = Esecuzione controlli di integrità sistema...
uiText.phase1CoreRecoveryVcAppxDependenciesMsixbundle = ⚡ Fase 1: Ripristino Core (VC++, dipendenze AppX, MSIXBundle).
uiText.powershell0 = PowerShell: {0}.
uiText.powershell7InstallatoViaWinget = PowerShell 7 installato tramite Winget.
uiText.powershell7RecommendedForAdvancedFeatures = PowerShell 7 raccomandato per funzionalità avanzate.
uiText.powershellJob0StartedId1 = Job PowerShell '{0}' avviato (ID: {1}).
uiText.preparation = Preparazione
uiText.preparingOfflineResourcesForWinToolkitStarter = Preparazione Risorse Offline per Win Toolkit Starter
uiText.preparingTheNextScript = ⏳ Preparazione prossimo script.
uiText.pressEnterToExit = Premere Invio per uscire
uiText.puliziaCacheWinget = Pulizia cache Winget.
uiText.quickOfficeRepairOffline = Riparazione Rapida Office (Offline)
uiText.ram0Gb2 = 🧠 RAM: {0}GB
uiText.rebootWithAdministratorPrivileges = Riavvio con privilegi amministratore.
uiText.rebootYourSystemAndThenRestartWintoolkitBeforeContinuing = riavviare il sistema e poi riavviare WinToolkit prima di proseguire.
uiText.recuperoUltimaReleasePowershell = Recupero ultima versione di PowerShell.
uiText.reinstallation0 = Reinstallazione {0}
uiText.repairWingetpackagemanagerCompletato = Riparazione-WinGetPackageManager completata.
uiText.repairWingetpackagemanagerEseguito = Repair-WinGetPackageManager eseguito.
uiText.reportCoreVersion0 = Versione principale: {0}
uiText.reportDate0 = Data: {0}
uiText.requiredWindowsDefenderIsOn = OBBLIGATORIO: Windows Defender è ATTIVO.
uiText.reRegisterManifestAppxmanifestXml = Re-registrazione manifest: AppxManifest.xml.
uiText.resetAppInstaller = Reimposta il programma di installazione dell'app.
uiText.resetCacheMicrosoftStoreWsreset = Reimposta cache Microsoft Store (wsreset)
uiText.resetClientUpdate = Reimposta aggiornamento client
uiText.resetPackageMicrosoftDesktopappinstaller = Reset pacchetto Microsoft.DesktopAppInstaller.
uiText.resetStatusFile0 = Reset file stato: {0}.
uiText.resettingWindowsUpdateServices = Ripristino servizi Windows Update.
uiText.resetWingetSources = Reset sorgenti Winget.
uiText.retrieveUrlLatestReleaseOfWindowsTerminal = Recupero URL ultima release di Windows Terminal.
uiText.runningGitInstaller = Esecuzione installer Git...
uiText.scriptStartOfflineVersione241Build3 = Script Start-Offline Versione 2.4.1 Build 3.
uiText.searchForLatestWindowsTerminalInstallerOnGithub = Ricerca installer Windows Terminal più recente su GitHub.
uiText.sendSupportArchive0 = Invia l'archivio sul tuo desktop ({0}) a GitHub, descrivendo i problemi riscontrati per contribuire a migliorare lo strumento.
uiText.serviceRestarted0 = Servizio riavviato: {0}.
uiText.serviceStop0 = Arresto servizio: {0}...
uiText.startingDownload = Avvio download in corso...
uiText.startingOfflineEnvironmentPreparation = Avvio preparazione ambiente offline.
uiText.startingPowershellEnvironmentSetupPsp = Avvio configurazione ambiente PowerShell (PSP).
uiText.startingService0 = Avvio servizio: {0}...
uiText.startingService01 = Avvio del servizio {0}: {1}
uiText.startingWinToolkitConfiguration = Avvio configurazione Win Toolkit.
uiText.system01 = Sistema: {0} ({1})
uiText.systemNotSupportedByWingetWindows101709Required = Sistema non supportato da Winget (richiesto Windows 10 1709+).
uiText.temaOhMyPoshScaricato = Tema Oh My Posh scaricato.
uiText.temporarilySuspendWindowsUpdateServicesToAvoidConflicts = Sospensione temporanea servizi Windows Update per evitare conflitti.
uiText.tentativoRepairWingetpackagemanager = Tentativo Repair-WinGetPackageManager.
uiText.tentativoRiparazioneWingetRepairWingetpackagemanager = Tentativo di riparazione Winget (Repair-WinGetPackageManager).
uiText.trace0 = [TRACCE] {0}
uiText.unexpectedBehaviorInSomeOrAllWintoolkitFeatures = comportamento imprevisto in alcune o tutte le funzionalità di WinToolkit.
uiText.userChoices0 = Scelte dell'utente: {0}
uiText.userConfirmationPrompt0Response1 = Richiesta di conferma dell'utente: {0} | Risposta: {1}
uiText.ver0Build1 = {0} (Build {1})
uiText.verificaPowershell7 = Verifica PowerShell 7.
uiText.verifyGitInstallation = Verifica installazione Git...
uiText.visualCRedistributableInstallation = Installazione Visual C++ Redistributable.
uiText.windebloatToolkit = Kit degli strumenti WinDebloat
uiText.windows10Build0NonSupportaWinget = La build di Windows 10 {0} non supporta Winget.
uiText.windows81PartialCompatibility = Windows 8.1: Compatibilità parziale.
uiText.windowsTerminalConfiguration = Configurazione Windows Terminal.
uiText.windowsTerminalInstallationInProgress = Installazione Windows Terminal in corso.
uiText.windowsUpdateInstallationServiceIsRunning = ✓ Il servizio di installazione degli aggiornamenti di Windows è in esecuzione
uiText.wingetNotSupportedOnWindows0 = Winget non supportato su Windows {0}.
uiText.wingetPresentButNotRespondingCorrectlyExitcode0 = Winget presente ma non risponde correttamente (ExitCode: {0}).
uiText.wintoolkitConfirmationBypassTagMessage0 = [WINTOOLKIT_CONFIRMATION_BYPASS_TAG] Messaggio: {0}.
uiText.wintoolkitCountdownBypassTagMessage0Seconds1 = [WINTOOLKIT_COUNTDOWN_BYPASS_TAG] Messaggio: {0} | Secondi: {1}.
uiText.wintoolkitGuiV30GuiEdition = WinToolkit GUI v3.0 - Edizione GUI
uiText.wintoolkitInputBypassTagPrompt0 = [WINTOOLKIT_INPUT_BYPASS_TAG] Richiesta: {0}
uiText.wintoolkitProgressTagActivity0Status1Percent100 = [WINTOOLKIT_PROGRESS_TAG] Attività: {0} | Stato: {1} | Percentuale: 100%.
uiText.wintoolkitProgressTagActivity0Status1Percent2 = [WINTOOLKIT_PROGRESS_TAG] Attività: {0} | Stato: {1} | Percentuale: {2}%.
uiText.wintoolkitProgressTagActivity0Status1Percent2Icon3Spinner4 = [WINTOOLKIT_PROGRESS_TAG] Attività: {0} | Stato: {1} | Percentuale: {2}% | Icona: {3} | Spinner: {4}.
uiText.wintoolkitProgressTagActivity0Status1SecondiPercent2 = [WINTOOLKIT_PROGRESS_TAG] Attività: {0} | Stato: {1} secondi. | Percentuale: {2}%.
uiText.wintoolkitProgressTagActivity0StatusInEsecuzionePercent1 = [WINTOOLKIT_PROGRESS_TAG] Attività: {0} | Stato: In esecuzione. | Percentuale: {1}%.
uiText.wintoolkitProgressTagActivity0StatusRunning1SecondsPercent2 = [WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: Esecuzione in corso. ({1} secondi) | Percent: {2}%.
uiText.wintoolkitRawHostOutputTag0 = [WINTOOLKIT_RAW_HOST_OUTPUT_TAG]{0}
uiText.wintoolkitSessionTerminatedByUser = Sessione WinToolkit terminata dall'utente.
uiText.wintoolkitStyledMessageTag01 = [WINTOOLKIT_STYLED_MESSAGE_TAG] {0}: {1}
uiText.wintoolkitStyledMessageTagInfoHeader0 = [WINTOOLKIT_STYLED_MESSAGE_TAG] Informazioni: INTESTAZIONE: {0}.

# -- Warning — warnings, cautions, recoverable issues

cleanerRule.clearEventLogs = Cancella registri eventi
uiText.01AttemptFailed2ILlTryAgain = ⚠️  Tentativo {0}/{1} fallito: {2}. Riprovo...
uiText.0Discontinued = ⚠️ {0} interrotto.
uiText.0IsEmptyUsingFallbackStaticMenu = ⚠️ \\{0} è vuoto, utilizzando il menu statico di fallback.
uiText.0NotFoundAfterLoading = ⚠️ \\{0} non trovato dopo il caricamento.
uiText.64BitGitAssetNotFound = Asset Git 64-bit non trovato.
uiText.asset0NotFound = Asset '{0}' non trovato.
uiText.attentionGitHasNotBeenInstalledOrItMayNotWorkProperly = ⚠️ Attenzione: Git non è stato installato oppure potrebbe non funzionare correttamente.
uiText.build01 = 🏗️ Compila: {0} ({1})
uiText.cannotGetParametersForFunction01 = Impossibile ottenere i parametri per la funzione '{0}': {1}.
uiText.checkboxReadingError0 = ⚠️ Errore lettura checkbox: {0}.
uiText.chromePolicySet01 = ⚙️ Policy Chrome impostata: {0} = {1}
uiText.cleanedValuesIn0 = ⚙️ Puliti valori in {0}
uiText.compressArchiveNotAvailableGuiReportSavedIn0 = ⚠️ Compress-Archive non disponibile. Report GUI salvato in: {0}.
uiText.coreScriptNotFoundAt0WithinJob = Script principale non trovato in {0} all'interno del lavoro.
uiText.couldNotCheckBitlockerStatus0 = ⚠️ Impossibile verificare lo stato di Bitlocker: {0}.
uiText.couldNotConfigureExecutebutton = ⚠️ Impossibile configurare ExecuteButton.
uiText.couldNotGetLocalPathForEmoji0Skipping = ⚠️ Impossibile ottenere il percorso locale per l'emoji '{0}'. Saltare.
uiText.couldNotLoadCategorysystemIcon = ⚠️ Impossibile caricare l'icona CategorySystem.
uiText.couldNotLoadExecutebuttonIcon = ⚠️ Impossibile caricare l'icona ExecuteButton.
uiText.couldNotLoadOutputlogIcon = ⚠️ Impossibile caricare l'icona OutputLog.
uiText.couldNotLoadSomeIcons0 = ⚠️ Impossibile caricare alcune icone: {0}.
uiText.couldNotLoadTooliconimage0 = ⚠️ Impossibile caricare ToolIconImage: {0}.
uiText.crashAccessViolationExitcode0RipristinoDatabase = ⚠️ Arresto anomalo di ACCESS_VIOLATION (codice di uscita: {0}). Banca dati Ripristino.
uiText.crashDetectedExitcode0AccessViolationAdvancedRecoveryAttempt = ⚠️ Crash rilevato (ExitCode: {0} = ACCESS_VIOLATION). Tentativo ripristino avanzato.
uiText.deepOptimizationOfMicrosoftOffice = ⚙️ Ottimizzazione profonda di Microsoft Office.
uiText.deepTestFailedExitcode0Details1 = ⚠️ Test profondo fallito: ExitCode={0}. Dettagli: {1}.
uiText.deepValidationFailedExitcode0Details1 = ⚠️ Validazione profonda fallita (ExitCode={0}). Dettagli: {1}
uiText.downloadFailed0 = ⚠️ Download fallito: {0}.
uiText.driveroverridesJsonNotFoundIn0 = DriverOverrides.json non trovato in {0}
uiText.duration0 = ⏱️ Durata: {0}
uiText.emptyInputTryAgain = ⚠️ Input vuoto. Riprova.
uiText.errorReadingLocalCacheVersion0 = ⚠️ Errore lettura versione cache locale: {0}.
uiText.failedToGetRemoteVersion0AForcedDownloadOrFallbackMayBeRequired = ⚠️ Fallito recupero versione remota: {0}. Potrebbe essere necessario un download forzato o fallback.
uiText.failedToLoadOrDownloadWindowIcon0 = ⚠️ Impossibile caricare o scaricare l'icona della finestra: {0}.
uiText.failedToSetDefaultTerminal0 = ⚠️ Impossibile impostare terminale predefinito: {0}.
uiText.fontInstallationViaWingetQuickMethod = ⬇️ Installazione font tramite WinGet (Metodo Rapido).
uiText.function0NotFoundAfterDotSourcingWithinJob = Funzione '{0}' non trovata dopo il dot-sourcing all'interno del lavoro.
uiText.iInteractiveInputBypassedFor0DefaultChoiceY = ℹ️ Input interattivo bypassato per: '{0}'. Scelta predefinita 'Y'.
uiText.importantWarning = ⚠️AVVERTENZA IMPORTANTE⚠️
uiText.interactiveInputDetected0NotSupportedInGuiMode = ⚠️ Input interattivo rilevato: {0} - Non supportato in modalità GUI.
uiText.invalidChoiceEnterNumbersBetween0 = ⚠️ Scelta non valida. Inserisci numeri compresi tra {0}.
uiText.microsoftAppInstallerInstallationFailed = ⚠️ Impossibile installare Microsoft.AppInstaller.
uiText.microsoftAppInstallerNotFoundInstalling = Microsoft.AppInstaller non trovato. Installazione in corso.
uiText.newCoreVersion0AvailableCurrent1DownloadInProgress = ⬆️ Nuova versione Core ({0}) disponibile (attuale: {1}). Download in corso.
uiText.noEndpointFoundInTemplateSkipping0 = Nessun endpoint trovato nel modello. Saltare: {0}.
uiText.noGuiOrCoreLogFilesFoundForReporting = ⚠️ Nessun file log della GUI o del Core trovato per la segnalazione.
uiText.noPs1ModulesFound0OperationCanceled = Nessun modulo .ps1 trovato in {0}. Operazione annullata.
uiText.pendingRebootDetectedForWindowsUpdates = ⚠️ Rilevato riavvio pendente per aggiornamenti Windows
uiText.persistentCrashAfterDatabaseRestore = ⚠️ Crash persistente dopo ripristino database.
uiText.persistentCrashStartingCompleteReinstallationOfWinget = ⚠️ Crash persistente. Avvio reinstallazione completa Winget.
uiText.phase1InsufficientStartingPhase2AdvancedRecovery = ⚠️ Fase 1 insufficiente. Avvio Fase 2: Ripristino Avanzato.
uiText.powershell7AssetsWinX64MsiNotFound = Asset PowerShell 7 win-x64.msi non trovato.
uiText.proceedWithCaution = ⚠️PROCEDERE CON ATTENZIONE⚠️
uiText.quickRecoveryFailedAttemptAdvancedSlowerMethod = ⚠️ Ripristino veloce fallito. Tentativo metodo avanzato (più lento).
uiText.repairOperationTimedOut = Timeout: l'operazione ha superato il limite di tempo ed è stata terminata.
uiText.restoreCompletedButWingetMayNotWork = ⚠️ Ripristino completato ma winget potrebbe non funzionare.
uiText.runningCommand01Timeout2S = Comando in esecuzione: {0} {1} (Timeout: {2}s)
uiText.settingWindowsTerminalAsDefaultViaRegistry = ⚙️ Impostazione Windows Terminal come predefinito via Registry.
uiText.skipped0 = ⚠️ Saltato: {0}
uiText.systemInfoNotAvailable = Info sistema non disponibili.
uiText.systemRebootCancelled = ⏸️ Riavvio del sistema annullato.
uiText.templateFileNotFoundIn0 = File template non trovato in: {0}
uiText.theGuiCannotContinueWithoutTheCoreScript = La GUI non può continuare senza lo script principale.
uiText.thereAre0WindowsUpdatesPendingPossibleProblemsDuringInstallation = ⚠️ Ci sono {0} aggiornamenti Windows pendenti. Possibili problemi durante installazione.
uiText.timediffMeasure = ⏱️ MISURA TIMEDIFF
uiText.timeoutAfter0Seconds = Timeout dopo {0} secondi.
uiText.timeoutReachedAfter0SecondsProcessTermination = Timeout raggiunto dopo {0} secondi, terminazione processo...
uiText.toolsFolderNotFoundIn0 = Cartella tools non trovata in: {0}
uiText.unableToCheckWindowsUpdateStatus0 = ⚠️ Impossibile verificare stato aggiornamenti Windows: {0}
uiText.unableToClose0 = Impossibile chiudere: {0}.
uiText.unableToExtractNumericPartFromLocale0IAssume000ForComparison = ⚠️ Impossibile estrarre la parte numerica dalla versione locale '{0}'. Assumo 0.0.0 per confronto.
uiText.unableToExtractNumericPartFromRemoteVersion0IAssume000ForComparison = ⚠️ Impossibile estrarre la parte numerica dalla versione remota '{0}'. Assumo 0.0.0 per confronto.
uiText.unableToExtractRemoteVersionFromCoreScriptIAssume000ForComparison = ⚠️ Impossibile estrarre versione remota dal Core Script. Assumo 0.0.0 per confronto.
uiText.unableToExtractVersionFromLocalCacheIAssume000ForComparison = ⚠️ Impossibile estrarre la versione dalla cache locale. Assumo 0.0.0 per confronto.
uiText.unableToExtractVersionFromNewlyDownloadedCore = ⚠️ Impossibile estrarre versione dal Core appena scaricato.
uiText.unableToInstallWindowsTerminalViaAnyAutomaticMethod = Impossibile installare Windows Terminal tramite qualsiasi metodo automatico.
uiText.unableToOpenBrowser0 = ⚠️ Impossibile aprire il browser: {0}.
uiText.unableToSetPermissions0 = Impossibile impostare permessi: {0}.
uiText.unableToSetPermissionsOn01 = Impossibile impostare permessi su '{0}': {1}.
uiText.unableToStartExternalProcess = Impossibile avviare il processo esterno.
uiText.warn = [AVVISARE]
uiText.warningInstallingSubsequentPackagesViaWingetMayFail = ⚠️ Attenzione: l'installazione dei pacchetti successivi via Winget potrebbe fallire.
uiText.windowsTerminalAssetMsixbundleNotFound = Asset .msixbundle di Windows Terminal non trovato.
uiText.windowsUpdateInstallationServiceCurrentlyRunning = ⚠️ Servizio installazione aggiornamenti Windows attualmente in esecuzione
uiText.wingetDidNotRespondWithin0SecondsIContinueAnyway = ⚠️ Winget non ha risposto entro {0} secondi. Proseguo comunque.
uiText.wingetDoesnTRespondFastRecoveryAttemptCore = ⚠️ Winget non risponde. Tentativo di ripristino veloce (Core).
uiText.wingetInstalledDeepValidationWithAnomaliesPossibleNetworkOrDbProblems = ⚠️ Winget installato. Validazione profonda con anomalie (possibili problemi di rete o DB).
uiText.wingetNotFoundInPath = Winget non trovato nel PATH.
uiText.wingetNotFoundInSystem = Winget non trovato nel sistema.
uiText.wingetNotFunctionalAfterAllAttempts = ⚠️ Winget non funzionale dopo tutti i tentativi.
uiText.wingetReturnedCode0TheFontMayRequireATerminalRestart = ⚠️ WinGet ha restituito codice {0}. Il font potrebbe richiedere un riavvio del terminale.
uiText.wintoolkitStyledMessageTagWarningTimeoutReachedAfter0SecondsTerminatingProcess = [WINTOOLKIT_STYLED_MESSAGE_TAG][Warning] Timeout raggiunto dopo {0} secondi, terminazione processo.

# -- Error — errors, failures, critical issues

cleanerRule.errorReports = Rapporti di errore
sourceText.completedWithErrors = Completato con errori
uiText.0AttemptBy1FailedFor23 = Tentativo {0} di {1} fallito per '{2}': {3}.
uiText.0CompletedWithErrors1 = ❌ {0} completato con errori: {1}.
uiText.0Failed1 = ❌ {0} fallito: {1}.
uiText.advancedInstallationViaMicrosoftWingetClientModule = 🚀 Installazione avanzata tramite modulo Microsoft.WinGet.Client.
uiText.appxInstallFailed01 = Installazione di AppX non riuscita ({0}): {1}
uiText.archiveCopyFailed = Copia dell'archivio non riuscita.
uiText.assetUrlRetrievalError0 = Errore recupero URL asset: {0}.
uiText.cached0 = 💾 Salvato in cache: {0}.
uiText.checkForJetbrainsmonoNerdFont = 🔍 Verifica presenza JetBrainsMono Nerd Font.
uiText.checkingMicrosoftAppInstallerPackage = 🔍 Verifica del pacchetto Microsoft.AppInstaller.
uiText.checkWingetFunctionality = 🔍 Verifica funzionalità Winget.
uiText.closingOfficeProcesses = 📋 Chiusura processi Office.
uiText.coreVersion0 = 📌 Versione principale: {0}.
uiText.coreVersionDownloaded0 = 📌 Versione Core scaricata: {0}.
uiText.coreVersionFromFallbackCache0 = 📌 Versione Core da cache fallback: {0}.
uiText.couldNotMinimizeConsoleNonCritical = Impossibile minimizzare la console (non critico).
uiText.criticalError0 = Errore critico: {0}.
uiText.criticalErrorDuringSetup0 = ❌ Errore critico durante il setup: {0}.
uiText.criticalErrorInReset0 = ❌ Errore critico nel reset: {0}
uiText.criticalErrorWhileLoadingCore0 = ❌ ERRORE CRITICO durante caricamento Core: {0}.
uiText.deepTestExecutionOfWingetSearchForPacketsOnTheNetwork = 🔍 Esecuzione test profondo di Winget (ricerca pacchetti in rete).
uiText.deepValidationError0 = Errore validazione profonda: {0}.
uiText.disableRealTimeProtectionToAvoidCrashes = Disabilita la protezione in tempo reale per evitare blocchi.
uiText.diskC0TotalGb1FreeGb = 🗄️  Disco C: {0} GB totale, {1} GB liberi
uiText.dismExportFailedWithExitcode0 = Esportazione DISM non riuscita con ExitCode: {0}.
uiText.download0 = 📥 Scarica {0}...
uiText.downloadCoreScriptDaGithub = 📡 Scarica Core Script da GitHub.
uiText.downloadError0 = Errore download: {0}
uiText.downloadFailedAfter0Attempts1 = ❌ Download fallito dopo {0} tentativi: {1}.
uiText.downloadingIconFor0From1 = 📥 Icona di download per '{0}' da {1}.
uiText.downloadOf0FailedAfter1Attempts = Download di '{0}' fallito dopo {1} tentativi.
uiText.driveroverridesJsonDownloadFailedUseLocalCacheIfAvailable = Download DriverOverrides.json fallito, uso cache locale se disponibile.
uiText.ensuringAllRequiredIconsAreAvailableLocally = 🚀 Garantire che tutte le icone richieste siano disponibili localmente.
uiText.error = [ERRORE]
uiText.errorAdministratorPrivilegesRequired = [ERRORE] Sono richiesti privilegi di amministratore.
uiText.errorDuring01 = Errore durante {0}: {1}
uiText.errorDuringDatabaseRestore0 = Errore durante ripristino database: {0}.
uiText.errorDuringDotSourcingCore0 = ❌ Errore durante dot-sourcing Core: {0}.
uiText.errorDuringIconSynchronization0 = ❌ Errore durante la sincronizzazione delle icone: {0}.
uiText.errorDuringInitializationLoaded0 = ❌ Errore durante inizializzazione Loaded: {0}.
uiText.errorDuringWingetDeepTest0 = ❌ Errore durante il test profondo di Winget: {0}.
uiText.errorDuringWingetTest0 = Errore durante test Winget: {0}.
uiText.errorExecutingFunction0WithinJob1 = Errore durante l'esecuzione della funzione '{0}' all'interno del lavoro: {1}.
uiText.errorFailedToCreateIconDirectory0 = [ERRORE] Impossibile creare la directory delle icone: {0}.
uiText.errorFailedToInitializeLogging0 = [ERRORE] Impossibile inizializzare la registrazione. {0}.
uiText.errorFailedToLoad01 = [ERRORE] Impossibile caricare: {0} - {1}.
uiText.errorGeneratingDynamicMenu0 = ❌ Errore durante la generazione del menu dinamico: {0}.
uiText.errorGettingWindowsTerminalReleaseFromGithub0 = Errore nel recupero release Windows Terminal da GitHub: {0}.
uiText.errorInstallingFont0 = Errore durante l'installazione font: {0}.
uiText.errorInterruptingJob0 = ❌ Errore durante l'interruzione del job: {0}.
uiText.errorModifiedScriptStartPs1IsMissingFrom0 = Errore: Lo script 'start.ps1' modificato non è presente in '{0}'.
uiText.errorPreparingGuiLogs0 = ❌ Errore durante la preparazione dei log GUI: {0}.
uiText.errorRestoringDatabase0 = ❌ Errore durante ripristino database: {0}.
uiText.errorRestoringWinget0 = Errore durante il ripristino Winget: {0}.
uiText.errorRetrievingSystemInformation0 = Errore nel recupero informazioni sistema: {0}.
uiText.errors0 = ❌ Errori: {0}
uiText.errorSendingLog0 = ❌ Errore invio log: {0}.
uiText.errorStartingJob01 = ❌ Errore avvio job '{0}': {1}.
uiText.errorUpdatingSystemInformation0 = Errore durante l'aggiornamento delle informazioni di sistema: {0}.
uiText.exceptionInStartDeepdiskrepair = Eccezione in Start-DeepDiskRepair
uiText.exceptionWhileRunningExternalCommand = Eccezione durante l'esecuzione del comando esterno
uiText.failedToCreateWindow0 = Impossibile creare la finestra: {0}.
uiText.failedToDotSourceCoreScriptWithinJob0 = Impossibile eseguire il dot-source dello script Core all'interno del lavoro: {0}.
uiText.failedToDownloadIcon01 = ❌ Impossibile scaricare l'icona '{0}': {1}.
uiText.failedToInstallWingetClientModule0 = Impossibile installare modulo WinGet Client: {0}.
uiText.failedToRestart01 = Impossibile riavviare '{0}': {1}.
uiText.failedToRetrieveSystemInformationFromCore = Impossibile recuperare le informazioni di sistema da Core.
uiText.fatalErrorCoreScriptLoadingFailed = ERRORE IRREVERSIBILE: caricamento dello script principale non riuscito.
uiText.finalFile0Kb1Lines = 📄 File finale: {0} KB ({1} righe)
uiText.finalTestAfterReinstallation = 🔄 Test finale dopo reinstallazione.
uiText.generatingDynamicMenuFromCore0 = 🔄 Generazione del menu dinamico dal Core \\{0}.
uiText.getSysteminfoFunctionNotFound = ❌ Funzione Get-SystemInfo NON trovata!
uiText.gitInstallationError0 = Errore installazione Git: {0}
uiText.gpuAnalysisErrorReadingWin32Videocontroller0 = Analisi GPU: errore durante lettura Win32_VideoController: {0}
uiText.guiWindowClosedAttemptToStopTheJobInProgress = 🚨 Finestra GUI chiusa. Tentativo di fermare il job in corso.
uiText.httpError01 = Errore HTTP {0}: {1}
uiText.individualRestartSuppressedAFinalRebootWillBeHandled = 🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale.
uiText.installationFailedCode0 = Installazione fallita. Codice: {0}
uiText.installationFailedCode02 = Installazione fallita. Codice: {0}.
uiText.irreversibleFailureWritingFinalFile0 = Errore irreversibile durante la scrittura del file finale sul disco: {0}.
uiText.lifeProtectionActivated0 = 🛡️ PROTEZIONE VITALE ATTIVATA: {0}
uiText.loadingCoreFunctionsIntoMemoryGlobalScope = 🔌 Caricamento funzioni Core in memoria (Global Scope).
uiText.localCoreVersionFound0Numeric1 = 📌 Versione Core locale trovata: {0} (Numerica: {1}).
uiText.microsoftAppInstallerUpdateError0 = Errore durante l'aggiornamento di Microsoft.AppInstaller: {0}.
uiText.moduleStatistics = 📊 STATISTICHE DEL MODULO
uiText.monitoringTimerRestarted = 🔄 Timer monitoraggio riavviato.
uiText.noLocalCacheFoundForcedDownload = 📥 Nessuna cache locale trovata. Download forzato.
uiText.noteFontsViaWingetRequireRestartingTerminalOrExplorerToBeVisible = 💡 Nota: i font via WinGet richiedono il riavvio del Terminale (o di Explorer) per essere visibili.
uiText.offlineResourcePreparationFailedUnableToProceed = La preparazione delle risorse offline è fallita. Impossibile procedere.
uiText.operatingSystem0 = 🖥️  Sistema Operativo: {0}
uiText.pleaseWaitOperationInProgress = 💎 Attendere prego, operazione in corso.
uiText.powershell02 = 🔧 PowerShell: {0}
uiText.powershellInstallationError0 = Errore installazione PowerShell: {0}.
uiText.preparingGuiErrorLogForReporting = 📦 Preparazione log errori GUI per la segnalazione.
uiText.pressAnyKeyToCancel = 💡 Premi un tasto qualsiasi per annullare...
uiText.profileConfigurationError0 = Errore configurazione profilo: {0}.
uiText.ram0Gb = 💾 RAM: {0} GB
uiText.reduction01LinesRemoved = 📉 Riduzione: {0} % ({1} righe rimosse)
uiText.reductionOffFlagMinifyNotDetected = 📉 Riduzione: OFF (Flag -Minify non rilevato)
uiText.remoteCoreScriptVersionRecovery = 📡 Recupero versione Core Script remota.
uiText.remoteCoreVersionDetected0Numeric1 = 📌 Versione Core remota rilevata: {0} (Numerica: {1}).
uiText.repairModuleFailed0 = Modulo Riparazione fallito: {0}.
uiText.repairWingetpackagemanagerFallito0 = Errore di riparazione di WinGetPackageManager: {0}.
uiText.repeatTestAfterDatabaseRestore = 🔄 Ripetizione test dopo ripristino database.
uiText.resourceInitializationCoreScriptLoading = 💎 INIZIALIZZAZIONE RISORSE - Caricamento Core Script.
uiText.ripristinoDatabaseWinget = 🔧Ripristino database Winget.
uiText.shortcutCreationError0 = Errore creazione scorciatoia: {0}.
uiText.sources0Kb1Lines = 📦 Fonti: {0} KB ({1} righe)
uiText.standardWindowsTerminalInstallationFailed0FallbackToTheMicrosoftStore = Installazione Standard di Windows Terminal fallita: {0}. Fallback al Microsoft Store.
uiText.startExecution0 = 🚀 Avvio esecuzione: {0}.
uiText.startingWingetAdvancedRepair = 🚀 Avvio riparazione avanzata Winget...
uiText.startingWingetCoreRecoveryProcedure = 🛠️ Avvio procedura di ripristino Winget (Core).
uiText.startWingetDatabaseRecovery = 🔧 Avvio ripristino database Winget.
uiText.startWingetInstallationVerificationProcedure = 🚀 Avvio procedura installazione/verifica Winget.
uiText.storageAndCompression = 💾 STOCCAGGIO E COMPRESSIONE
uiText.systemClockResynced = 🕒 Orologio di sistema risincronizzato.
uiText.takingOwnershipFor0 = 🔑 Assunzione proprietà per {0}.
uiText.terminalSettingsUpdateError0 = Errore aggiornamento settings terminal: {0}.
uiText.theScriptWillContinueButPackageInstallationMayFail = Lo script proseguirà, ma l'installazione di pacchetti potrebbe fallire.
uiText.thisMayCauseMalfunctionsErrorsOrBehavior = Questo potrebbe causare malfunzionamenti, errori o comportamenti
uiText.tipManuallyDownloadWintoolkitPs1From = 💡 Suggerimento: Scarica manualmente WinToolkit.ps1 da:
uiText.total0CheckboxesFound = 🔍 Trovati {0} checkbox totali.
uiText.trashEmptied = 🗑️ Cestino svuotato
uiText.unableToExtractOrInstallDependenciesFromTheOfficialZipError0 = Impossibile estrarre o installare le dipendenze dallo zip ufficiale. Errore: {0}.
uiText.unableToInstallWinget = ❌ Impossibile installare Winget.
uiText.unhandledException01 = ECCEZIONE NON GESTITA: {0} | {1}
uiText.unknownErrorsOccurred = Si sono verificati errori sconosciuti durante l'esecuzione dello script.
uiText.user0On1 = 👤 Utente: {0} su {1}
uiText.usingLocalCacheExpiredOrOlderButAvailableAsAFallback = 📂 Utilizzo cache locale (scaduta o meno recente, ma disponibile) come fallback.
uiText.windowsTerminalAppxInstallationFailed = Installazione di Windows Terminal Appx non riuscita.
uiText.windowsUpdateStatusCheck = 🔍 Controllo stato aggiornamenti Windows...
uiText.winget0 = 📦 Ala: {0}
uiText.wingetAdvancedInstallationError0 = Errore installazione avanzata Winget: {0}.
uiText.wingetCommandError0 = Errore comando Winget: {0}.
uiText.wingetCoreInstallationFailed = L'installazione di Winget Core non è riuscita.
uiText.wingetDeepValidationConnectivityDatabaseIntegrity = 🔍 Validazione profonda Winget (connettività + integrità database).
uiText.wingetInstallationFailedOrFailedExitcode0FallbackToDirectDownload = Installazione Winget fallita o non riuscita (ExitCode: {0}). Fallback al download diretto.
uiText.wingetInstallationForWindowsTerminalFailed = Installazione Winget per Windows Terminal non riuscita.
uiText.wingetInstallationForWindowsTerminalFailed0 = Installazione Winget per Windows Terminal fallita: {0}.
uiText.wingetIntegrityValidationInProgressTimeout0S = 🔍 Validazione integrità Winget in corso (timeout: {0} s)...
uiText.wingetMsixBundleInstallationFailed = Installazione Winget MSIX Bundle fallita.
uiText.wingetNotAvailable = 📦 Winget: Non disponibile.
uiText.wintoolkitIsReadyOnTheDesktop = WinToolkit è Pronto sul Desktop! 🚀
uiText.wintoolkitLoadedInLibraryMode = 📚 WinToolkit caricato in modalità LIBRERIA
uiText.wintoolkitStyledMessageTagErrorErroreDurante01 = [WINTOOLKIT_STYLED_MESSAGE_TAG][Errore] Errore durante {0}: {1}.

# END uiText translations

'@
