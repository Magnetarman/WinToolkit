# culture="en-US"
ConvertFrom-StringData -StringData @'

# BEGIN language translations

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
language.aiTranslated = true

language.code = en-US

language.name = English

language.nativeName = English
# END language translations

# BEGIN menu translations

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
menu.back = Back to previous menu

menu.changeLanguage = Change language

menu.choice = Selection

menu.chooseLanguage = Choose a language

menu.closing = Closing...

menu.exitSection = Exit

menu.exitToolkit = Exit Toolkit

menu.invalidSelection = No valid selection. Try again.

menu.language = Language

menu.languageChanged = Language changed to {0}.

menu.main = Main Menu

menu.multiPrompt = Enter one or more numbers (for example: 2 3 4 or 2,3,4) to run the operations in sequence

menu.multiPromptShort = Enter one or more numbers

menu.noLanguages = No language files were found.

menu.pressEnter = Press ENTER to return to the menu...

menu.startedInteractive = WinToolkit started in interactive mode

menu.support = Support: Github.com/Magnetarman
# END menu translations

# BEGIN system translations

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
system.architecture = Architecture

system.bitlockerStatus = BitLocker status

system.computerName = PC name

system.disk = Disk

system.edition = Edition

system.free = Free

system.infoTitle = SYSTEM INFORMATION

system.version = Version
# END system translations

# BEGIN bitlocker translations

# -- Affirmative — positive outcomes (success, completion, confirmations)

# -- Affirmative — positive outcomes (success, completion, confirmations)
bitlocker.status.notConfigured = Not configured

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
bitlocker.status.decrypting = Decryption in progress

bitlocker.status.encrypting = Encryption in progress

bitlocker.status.off = Disabled

bitlocker.status.on = Enabled

bitlocker.status.suspended = Suspended

bitlocker.status.unknown = Unknown
# END bitlocker translations

# BEGIN confirm translations

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
confirm.profile.accept = Yes, I understand what I am doing and accept responsibility if files are deleted

confirm.profile.sure = Are you absolutely sure?

confirm.profile.yes = Yes, delete user profiles

# -- Warning — warnings, cautions, recoverable issues

# -- Warning — warnings, cautions, recoverable issues
confirm.profile.warn1 = WARNING: this option will delete all Windows user profiles except the current user.

confirm.profile.warn2 = Data stored in deleted profiles cannot be recovered.
# END confirm translations

# BEGIN run translations

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
run.sequence = Running {0} operations in sequence...

run.start = Starting: {0}

# -- Warning — warnings, cautions, recoverable issues

# -- Warning — warnings, cautions, recoverable issues
run.cancelled = Operation cancelled. Returning to the main menu.

# -- Error — errors, failures, critical issues

# -- Error — errors, failures, critical issues
run.error = Error while running {0}: {1}
# END run translations

# BEGIN summary translations

# -- Affirmative — positive outcomes (success, completion, confirmations)

# -- Affirmative — positive outcomes (success, completion, confirmations)
summary.completed = Completed

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
summary.detail = Detail

summary.operation = Operation

summary.status = Status

summary.title = Execution Summary

# -- Error — errors, failures, critical issues

# -- Error — errors, failures, critical issues
summary.error = Error
# END summary translations

# BEGIN reboot translations

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
reboot.countdown = System restart in

reboot.reminder = Remember to restart the system manually to complete the operations.

reboot.required = A restart is required to complete the operations.
# END reboot translations

# BEGIN gui translations

# -- Affirmative — positive outcomes (success, completion, confirmations)

# -- Affirmative — positive outcomes (success, completion, confirmations)
gui.complete = Complete

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
gui.allExecuted = All scripts have been executed.

gui.architecture = Architecture: 

gui.availableFunctions = Available functions

gui.bitlockerStatus = BitLocker status: 

gui.disk = Disk: 

gui.diskFreeFormat = {0}% free ({1} GB / {2} GB)

gui.executeScripts = Run scripts

gui.initialized = WinToolkit GUI initialized successfully.

gui.instructions = Select one or more scripts and press 'Run scripts'.

gui.languageLabel = Language

gui.limited = Limited

gui.noneSelected = No script selected.

gui.outputLogs = Output and logs

gui.pcName = PC name: 

gui.ram = RAM: 

gui.rebootPrompt = The system requires a restart to complete the operations. Restart now?

gui.rebootTitle = Restart Required

gui.scriptFeatures = Script features: 

gui.systemInfo = System information

gui.unsupported = Unsupported

gui.version = Version: 

gui.windowsEdition = Windows edition: 

# -- Error — errors, failures, critical issues

# -- Error — errors, failures, critical issues
gui.sendErrorLogs = Send error logs
# END gui translations

# BEGIN category translations

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
category.driverGaming = Driver & Gaming

category.office = Office

category.support = Support

category.windows = Windows
# END category translations

# BEGIN script translations

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
script.AutoVideoDriverInstall = Auto install video driver [Nvidia-AMD]

script.DisableBitlocker = Disable BitLocker

script.GamingToolkit = Gaming Toolkit

script.Install-Office = Install Office Basic

script.Repair-Office = Repair Office

script.Uninstall-Office = Remove Office

script.VideoDriverReinstall = Reinstall video driver

script.WinBackupDriver = PC driver backup

script.WinCleaner = Temporary file cleanup

script.WinDeleteUserProfiles = Delete Windows user profiles

script.WinExportLog = Export WinToolkit logs

script.WinReinstallStore = Winget/WinStore reset

script.WinRepairToolkit = Windows repair

script.WinUpdateReset = Reset Windows Update
# END script translations

# BEGIN sourceText translations

# -- Affirmative — positive outcomes (success, completion, confirmations)

# -- Affirmative — positive outcomes (success, completion, confirmations)
sourceText.completed = Completed

sourceText.configured = configured

sourceText.created = created

sourceText.deleted = deleted

sourceText.downloaded = downloaded

sourceText.enabled = enabled

sourceText.operationCompleted = Operation completed!

sourceText.removed = Removed

sourceText.restored = restored

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
sourceText.applyingUnwrapping = Applying unwrapping.

sourceText.automaticRestart = Automatic restart

sourceText.compilerPs1PipelineExecutedWithCode = compiler.ps1 pipeline executed with code

sourceText.coreScriptContentIsEmptyAfterLoadingAttempts = Core Script content is empty after loading attempts.

sourceText.detected = detected

sourceText.detectedInternalFunctionIn = Detected internal function in

sourceText.download = download

sourceText.in = in

sourceText.moduleProcessed = Module processed

sourceText.modules = modules

sourceText.operation = operation

sourceText.pendingOperations = pending operations

sourceText.pressAnyKeyToExit = Press any key to exit

sourceText.pressAnyKeyToExit2 = 'Press any key to exit.'

sourceText.readingSourceTemplate = Reading source template

sourceText.removal = Removal

sourceText.savingStandaloneExecutable = Saving standalone executable

sourceText.sources = sources

sourceText.starting = Starting

sourceText.startingAggregation = Starting aggregation

sourceText.startingSafeMinificationThroughThePowershellTokenizer = Starting safe minification through the PowerShell tokenizer.

sourceText.startingWintoolkitBuildProcess = Starting WinToolkit build process.

sourceText.stopped = stopped

sourceText.summary = Summary

sourceText.summaryBuildDashboard = SUMMARY BUILD DASHBOARD

sourceText.systemRestart = System restart

sourceText.version = Version

# -- Warning — warnings, cautions, recoverable issues

# -- Warning — warnings, cautions, recoverable issues
sourceText.cancelled = cancelled

sourceText.criticalError = Critical error

sourceText.notFound = not found

sourceText.warning = Warning

# -- Error — errors, failures, critical issues

# -- Error — errors, failures, critical issues
sourceText.failed = failed

sourceText.initializationError = Initialization error

sourceText.iOErrorWhileAggregatingModule = I/O error while aggregating module

sourceText.iOErrorWhileReadingSourceFiles = I/O error while reading source files

sourceText.unexpectedError = Unexpected error

sourceText.unexpectedErrorDuringMinification = Unexpected error during minification

sourceText.unknownError = Unknown error
# END sourceText translations

# BEGIN verb translations

# -- Affirmative — positive outcomes (success, completion, confirmations)

# -- Affirmative — positive outcomes (success, completion, confirmations)
verb.complete = Complete

# -- Informational — status, progress, notes

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

# -- Warning — warnings, cautions, recoverable issues
verb.cancel = Cancel

verb.notFound = Not found

verb.notPresent = Not present

verb.warning = Warning

# -- Error — errors, failures, critical issues

# -- Error — errors, failures, critical issues
verb.fail = Fail
# END verb translations

# BEGIN noun translations

# -- Informational — status, progress, notes

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

# -- Error — errors, failures, critical issues
noun.exception = Exception
# END noun translations

# BEGIN toolText translations

# -- Affirmative — positive outcomes (success, completion, confirmations)

# -- Affirmative — positive outcomes (success, completion, confirmations)
toolText.0DeletedCaches = {0} deleted cache.

toolText.0OfficeFoldersRemoved = {0} Office folder removed.

toolText.0OfficeLinksRemoved = {0} Office link removed.

toolText.0OfficeRegistryKeysRemoved = {0} Office registry key removed.

toolText.0OfficeTasksRemoved = {0} Office task removed.

toolText.0Service1ConfiguredAs2 = {0} Service {1} configured as {2}.

toolText.0Service1Restored = {0} Service {1} restored.

toolText.0Service1StartedSuccessfully = {0} Service {1}: Started successfully.

toolText.archiveSavedToDesktop = Archive saved to desktop.

toolText.attemptingFullRepairOnlineAsAFallback = 🌐 Attempting full repair (online) as a fallback.

toolText.autostart0RemovedFromRegistry = Autostart '{0}' removed from registry.

toolText.autostartLink0Removed = Autostart link '{0}' removed.

toolText.autoVideoDriverInstallFinished = 🎯 Auto Video Driver Install finished.

toolText.batchSwitchToNormalModeBatCreatedOnDesktop = Batch 'Switch to Normal Mode.bat' created on Desktop.

toolText.cleaningCompleted = Cleaning completed.

toolText.clientsInstalled = Clients installed.

toolText.completed = COMPLETED

toolText.completedResidualFolder01 = COMPLETED RESIDUAL FOLDER - {0} - {1}

toolText.compressionCompleted0MbReduction1 = Complete compression: {0} MB (Reduction: {1}%).

toolText.criteriaRemoved = ✅ Criteria removed.

toolText.debloatOperationsCompleted = ✅ Debloat operations completed.

toolText.decryptionStartedCompletedSuccessfully = ✅ Decryption started/completed successfully.

toolText.directory0PartiallyDeleted = Directory {0} partially deleted.

toolText.directRemovalCompleted = ✅ Direct removal completed.

toolText.directxDownloaded = DirectX downloaded.

toolText.directxInstallation = 🎮 DirectX installation.

toolText.driverBackupCompletedSuccessfully = 🎉 Driver backup completed successfully!

toolText.driverBackupToolkitFinished = 🎯 Driver Backup Toolkit finished.

toolText.exportCompleted0Driver1Mb = Complete export: {0} driver ({1} MB).

toolText.extractionCompleted = Extraction completed.

toolText.gameClientInstallation = 🎮 Game client installation.

toolText.gamingToolkitCompleted = Gaming Toolkit completed!

toolText.getHelpCompletedSuccessfully = ✅ Get Help completed successfully.

toolText.installationCompleted = ✅ Installation completed.

toolText.installed0 = 'Install {0}'

toolText.installingBattleNet = 🎮 Installing Battle.net.

toolText.logsCompressedSuccessfullySavedFile0OnDesktop = Logs compressed successfully! Saved file: '{0}' on Desktop.

toolText.microsoftStoreReinstalledVia0 = Microsoft Store reinstalled via {0}.

toolText.microsoftStoreRestoredViaEmergencyMethod = Microsoft Store restored via emergency method.

toolText.microsoftStoreSuccessfullyRestored = Microsoft Store successfully restored.

toolText.netframeworkEnabled = NetFramework enabled.

toolText.netframeworkFeatureEnabled0 = Enable NetFramework feature: {0}.

toolText.noRemovableRegisteredProfilesFound = ✅ No removable registered profiles found.

toolText.noRemovableResidualFolderFoundInCUsers = ✅ No removable residual folder found in C:\\Users.

toolText.officeInstallFinished = 🎯 Office Install finished.

toolText.officeRemovalComplete = 🎉 Office removal complete!

toolText.officeRepairComplete = 🎉 Office Repair Complete!

toolText.officeRepairFinished = 🎯 Office Repair finished.

toolText.officeUninstallFinished = 🎯 Office Uninstall finished.

toolText.operationCompleted = 🎉 Operation completed.

toolText.operationsCompletedSuccessfully0 = Complete operations successfully: {0}.

toolText.planActivated = Plan activated.

toolText.planCreated = Plan created.

toolText.registeredProfilesRemoved0 = ✅ Registered profiles removed: {0}

toolText.reinstalled0 = 'Reinstall {0}.'

toolText.reinstallingXboxGameBarApp = 🎮 Reinstalling Xbox Game Bar & App.

toolText.removed0 = 'Remove {0}'

toolText.removed02 = 'Remove {0}.'

toolText.repairCompletedSuccessfully = 🎉 Repair completed successfully!

toolText.residualFoldersRemoved0 = ✅ Residual folders removed: {0}

toolText.restartRecommendedToCompleteCleanupOfUnremovedProfiles = Restart recommended to complete cleanup of unremoved profiles.

toolText.runtimesCompleted = Runtimes completed.

toolText.safeModeConfiguredForNextBoot = Safe mode configured for next boot.

toolText.service0OptimizedSuccessfully = Optimize service {0} successfully.

toolText.serviceOptimization01 = Optimize service: {0} ({1}).

toolText.setupComplete = 🎉 Setup complete.

toolText.stableDriverDownloadedToDesktop0 = Download stable driver to desktop: {0}

toolText.startingOfficeBasicInstallation = 🏢 Starting Office Basic installation.

toolText.systemOptimizedForGaming = System optimized for gaming.

toolText.taskEnabled0 = Task enabled: {0}.

toolText.telemetryAndPrivacyOfficeDisabled = ✅ Telemetry and Privacy Office disabled.

toolText.threadsConfigured0 = 🧵 Configure threads: {0}

toolText.unableToActivatePlan = Unable to activate plan.

toolText.unableToCompletelyDelete0FileInUse = Unable to completely delete {0} - file in use.

toolText.unigetUiInstallationFinishedWithCode0 = UniGet UI installation finished with code: {0}.

toolText.unigetUiInstalled = UniGet UI installed.

toolText.unigetUiInstalledSuccessfully = UniGet UI installed successfully.

toolText.updatedCriteria = ✅ Updated criteria.

toolText.updatedGroupPolicy = ✅ Updated Group Policy.

toolText.updatedSources = Updated sources.

toolText.versionDetected0 = 🎯 Detect version: {0}.

toolText.videoDriverReinstallFinished = 🎯 Video Driver Reinstall finished.

toolText.windowsUpdateHasBeenRestoredToDefaultValues = 🎉 Windows Update has been RESTORED to default values!

toolText.wingetAvailable = ✅ Winget available.

toolText.wingetRestoredAndOperational = Winget restored and operational.

toolText.xboxReinstalled = Xbox reinstalled.

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
toolText.01Starting2 = [{0}/{1}] Starting {2}.

toolText.01Status2 = {0} {1} - Status: {2}

toolText.0Code1 = {0}: code {1}.

toolText.0ItemsNotRemovedMayBeBlockedByOpenSessionsOrHandles = {0} items not removed may be blocked by open sessions or handles.

toolText.0Reverting1To2 = {0} Reverting {1} to {2}.

toolText.0Service1StartingOrDelayed = {0} Service {1}: Starting or delayed.

toolText.0Service1Stopped = {0} Service {1} stopped.

toolText.0ServiceProcessing1 = {0} Service processing: {1}.

toolText.0V1 = {0} v{1}

toolText.alertsGenerated0 = Generate alert: {0}.

toolText.attemptedVia0 = Attempted via: {0}.

toolText.autostartCleaner = 🧹 Autostart cleaner.

toolText.autovideodriverinstallSessionEnded = AutoVideoDriverInstall session ended.

toolText.battleNetProcessDidNotStartProperly = Battle.net: Process did not start properly.

toolText.blockingAutomaticDriversFromWindowsUpdate = Blocking automatic drivers from Windows Update.

toolText.chkdskCommandSentRebootToPerformDeepDiskRepair = Chkdsk command sent. Reboot to perform deep disk repair.

toolText.cleanupGpcacheCacheAndWsusSettings = 🧹 Cleanup GPCache cache and WSUS settings.

toolText.clearEventlog0 = Clear-EventLog: {0}

toolText.clearEventlog01 = Clear-EventLog [{0}]: {1}

toolText.commandTimesOutAfter0Hours = Command times out after {0} hours.

toolText.createBackupAndLogDirectories = Create backup and log directories.

toolText.dduExtractedToDesktop = DDU extracted to Desktop.

toolText.decryptionInProgressInBackground = ⏳ Decryption in progress in background.

toolText.deletingLocalPolicies = ⏳ Deleting local policies.

toolText.directories01 = Directories ({0}/{1})

toolText.directxProcessDidNotStartCorrectly = DirectX: Process did not start correctly.

toolText.disablebitlockerSessionEnded = DisableBitlocker session ended.

toolText.doNotDisturbActive = Do Not Disturb active.

toolText.driverWuLockSet = Driver updates are now blocked.

toolText.elimination0 = Elimination {0}

toolText.emergencyAttemptViaAppxmanifest = Emergency attempt via AppXManifest.

toolText.energyProfileConfiguration = ⚡ Energy profile configuration.

toolText.excludedProfile01 = Excluded profile: {0} ({1}).

toolText.existingPlanFound = Existing plan found.

toolText.extractingDduToDesktop = Extracting DDU to Desktop.

toolText.finalCleaning = 🧹 Final cleaning.

toolText.found0OfficePackages = Find {0} Office package.

toolText.getHelpStartedTheRemovalInAnExternalWindowWaitingForCompletion = ⏳ Get Help started the removal in an external window. Waiting for completion...

toolText.gpuDetected0 = Detect GPU: {0}.

toolText.gpuNotDetectedOnlyDduWillBePlacedOnTheDesktop = GPU not detected: Only DDU will be placed on the Desktop.

toolText.inProgress0Seconds = In progress... ({0} seconds)

toolText.inSafeModeRunDduToCleanTheDriversThenReinstallWithTheDesktopInstallerFinallyUseBatchToRetu = In Safe Mode: Run DDU to clean the drivers, then reinstall with the Desktop installer. Finally use batch to return to normal mode.

toolText.installOfficeSessionEnded = Install-Office session ended.

toolText.intelGpuDownloadDriversManuallyFromIntelIfNecessary = Intel GPU: Download drivers manually from Intel if necessary.

toolText.location0 = Location: {0}

toolText.noFilesToCompressInBackupDirectory = No files to compress in backup directory.

toolText.noKnownStableDriversFoundIUseAutodetectFallback = No known stable drivers found. I use autodetect fallback.

toolText.noLogFilesCopiedCheckPermissionsAndThatTheFilesExist = No log files copied. Check permissions and that the files exist.

toolText.noProblemsDetected = No problems detected.

toolText.noRemovableResidualFoldersFound = No removable residual folders found.

toolText.noteARebootIsRequiredToFullyApplyAllChanges = ⚡ Note: A reboot is required to fully apply all changes.

toolText.noThirdPartyDriversFoundToExport = No third party drivers found to export.

toolText.officeCacheCleaner = 🧹 Office cache cleaner.

toolText.officeFolderCleaning = 🧹 Office folder cleaning.

toolText.performingAWindowsUpdateClientReset = ⚡ Performing a Windows Update client reset...

toolText.policyUpdate = ⏳ Policy update.

toolText.pressAnyKeyToContinue = Press any key to continue.

toolText.profileExcludedDueToTimeThreshold0LastUse1 = Profile excluded due to time threshold: {0}, last use {1}.

toolText.rebootRequiredForDeepRepair = Reboot required for deep repair.

toolText.recommendedReboot0 = Recommend reboot: {0}

toolText.registeredProfilesSelectedForAutomaticRemoval = Registered profiles selected for automatic removal:

toolText.reinstallation0 = Reinstall {0}.

toolText.removalNotCompleted = Removal not completed.

toolText.removingOffice = Removing Office

toolText.removingOldArchive = Removing old archive.

toolText.removingPreviousBackups = Removing previous backups.

toolText.repairOfficeSessionEnded = Repair-Office session ended.

toolText.residualFolderExcludedBecauseItIsStillAssociatedWithWin32Userprofile01 = Residual folder excluded because it is still associated with Win32_UserProfile: {0} ({1}).

toolText.residualFolderExcludedBecauseReparsePointSymlink01 = Residual folder excluded because reparse point/symlink: {0} ({1}).

toolText.residualFolderExcludedForProtectedName01 = Residual folder excluded for protected name: {0} ({1}).

toolText.residualFoldersSelectedForAutomaticRemoval0 = Residual folders selected for automatic removal: {0}

toolText.restartMicrosoftStoreServices = Restart Microsoft Store services.

toolText.restartNotRequired = Restart not required.

toolText.reverted0BakDllTo1Dll = Reverted {0}_BAK.dll to {1}.dll.

toolText.ruleExecution = Rule execution

toolText.serviceStopped0 = Stop service: {0}.

toolText.sessionStartedOn0 = Start session on {0}.

toolText.startingRemovalOfResidualFolders = 🧹 Starting removal of residual folders.

toolText.startingStoreWingetReinstallation = Starting Store & Winget reinstallation.

toolText.startResidualFolder01 = START RESIDUAL FOLDER - {0} - {1}

toolText.storeCacheReset = Store cache reset.

toolText.summaryOfOperations = SUMMARY OF OPERATIONS

toolText.systemHealthyDeepRepairNotNecessary = System healthy. Deep repair not necessary.

toolText.temporaryEnvironmentCleaning = 🧹 Temporary environment cleaning.

toolText.thisOperationMayTakeAFewMinutes = ⏰ This operation may take a few minutes.

toolText.totalSize0Mb = Total size: {0} MB

toolText.uninstallOfficeSessionEnded = Uninstall-Office session ended.

toolText.usingDirectRemovalForWindows1122h2OrEarlier = ⚡ Using direct removal for Windows 11 22H2 or earlier.

toolText.videodriverreinstallSessionEnded = VideoDriverReinstall session ended.

toolText.waitingForResourcesToBeReleased = ⏳ Waiting for resources to be released.

toolText.wevtutilCl01 = Wevtutil cl [{0}]: {1}

toolText.wevtutilSlOutput0 = wevtutil sl output: {0}

toolText.winbackupdriverSessionEnded = WinBackupDriver session ended.

toolText.windebloatSessionEnded = WinDebloat session ended.

toolText.winexportlogSessionEnded = WinExportLog session ended.

# -- Warning — warnings, cautions, recoverable issues

# -- Warning — warnings, cautions, recoverable issues
toolText.0DllNotFoundAndNoBackupAvailable = ⚠️ {0}.dll not found and no backup available.

toolText.0Error0x800f0806PendingOperationsThisIsNotACriticalError = ⚠️ {0}: Error 0x800f0806 (pending operations). This is not a critical error.

toolText.0FilesIgnoredBecauseTheyAreInUseOrNotAccessible = ⚠️ {0} files ignored because they are in use or not accessible.

toolText.0Service1NotFoundOnTheSystem = {0} Service {1} not found on the system.

toolText.0Unable123 = {0} Unable {1} {2} - {3}.

toolText.battleNetTimedOut = Battle.net timed out.

toolText.criticalErrorDuringDriverReinstallation0 = Critical error during driver reinstallation: {0}

toolText.criticalErrorInInstallOffice = Critical error in Install-Office

toolText.criticalErrorInRepairOffice = Critical error in Repair-Office

toolText.criticalErrorInUninstallOffice = Critical error in Uninstall-Office

toolText.criticalErrorRepairingOffice0 = Critical error repairing Office: {0}

toolText.criticalErrorWhileRemovingOffice0 = Critical error while removing Office: {0}

toolText.directxTimeout = DirectX timeout.

toolText.disablingAutomaticEncryptionInTheRegistry = ⚙️ Disabling automatic encryption in the registry.

toolText.driverWuBlockError0IContinueAnyway = ⚠️ Error blocking driver updates: {0}. Continuing anyway.

toolText.failedToExportSfcCbsLogFileInUse = ⚠️ Failed to export SFC CBS log (file in use).

toolText.gethelpcmdExeNotFound = GetHelpCmd.exe not found.

toolText.gpuNotDetectedDriverNotAvailableForAutomaticInstallation = GPU not detected: Driver not available for automatic installation.

toolText.gpupdateCompletedWithCode0IContinueAnyway = ⚠️ Complete gpupdate with code: {0}. Continue anyway.

toolText.gpupdateDidNotRespondIContinueAnyway = ⚠️ gpupdate did not respond. Continuing anyway.

toolText.gpupdateTerminatedWithErrorsOrTimedOut = ⚠️ gpupdate terminated with errors or timed out.

toolText.itemsNotRemoved0 = ⚠️ Items not removed: {0}

toolText.manageBdeExitCode0BitlockerMayAlreadyBeDownOrInError = ⚠️ manage-bde exit code: {0}. BitLocker may already be down or in error.

toolText.nonInteractiveModeNoConfirmationWillBeRequestedBeforeCancellations = ⚠️ Non-interactive mode: no confirmation will be requested before cancellations.

toolText.officeclicktorunExeNotFoundOfficeMayNotBeInstalled = OfficeClickToRun.exe not found. Office may not be installed.

toolText.officePostInstallationConfiguration = ⚙️ Office post-installation configuration.

toolText.officePostRepairSetup = ⚙️ Office post-repair setup.

toolText.pressAnyKeyToExit = ⌨️ Press any key to exit.

toolText.remainingFolderCleanupSkipped = Remaining folder cleanup skipped.

toolText.resetWindowsUpdateSettings = ⚙️ Reset Windows Update settings.

toolText.residualFolderCleanupSkippedForSkipresidualfoldercleanupParameter = Residual folder cleanup skipped for SkipResidualFolderCleanup parameter.

toolText.resourceCleanupAndWindebloatSessionShutdown = ♻️ Resource cleanup and WinDebloat session shutdown.

toolText.resourceCleanupCompleted = ♻️ Resource cleanup completed.

toolText.systemDetected0TheScriptIsDesignedForWindows11 = ⚠️ Detect system: {0}. The script is designed for Windows 11.

toolText.theLogsFolder0WasNotFoundUnableToExport = The logs folder '{0}' was not found. Unable to export.

toolText.unableToCheckBitlockerStatus0 = Unable to check BitLocker status: {0}

toolText.unableToDetectWindowsVersion0 = Unable to detect Windows version: {0}

toolText.unableToDownloadDduAnnulment = Unable to download DDU. Cancelling.

toolText.unableToReinstallMicrosoftStoreViaAutomaticMethods = Unable to reinstall Microsoft Store via automatic methods.

toolText.unableToRemove0FoldersMayBeInUse = Unable to remove {0} folders (may be in use).

toolText.unigetUiRequireManualVerification = ⚠️ UniGet UI require manual verification.

toolText.unlimitedPasswordExpirationSetting = ⚙️ Unlimited password expiration setting.

toolText.waasmedicsvcSettingsReset = ⚙️ WaaSMedicSvc settings reset.

toolText.warningFailedToDeleteGpcacheCache0 = Warning: Failed to delete GPCache cache - {0}.

toolText.warningFailedToRemoveWsusSettings0 = Warning: Failed to remove WSUS settings - {0}.

toolText.warningFailedToRepair0Dll1 = Warning: Failed to repair {0}.dll - {1}.

toolText.warningFailedToRestoreWaasmedicsvc0 = Warning: Failed to restore WaaSMedicSvc - {0}.

toolText.warningTheSystemWillRebootIntoSafeMode = WARNING: The system will reboot into safe mode.

toolText.warningTheSystemWillRestartAutomatically = ⚡ Warning: The system will restart automatically.

toolText.warningUnableToEnableAutomaticRestart0 = Warning: Unable to enable automatic restart - {0}.

toolText.warningUnableToEnableDriver0 = Warning: Unable to enable driver - {0}.

toolText.warningUnableToEnableTaskIn01 = Warning: Unable to enable task in {0} - {1}.

toolText.warningUnableToResetSomePolicies0 = Warning: Unable to reset some policies - {0}.

toolText.warningUnableToResetSomeSettings0 = Warning: Unable to reset some settings - {0}.

toolText.warningUnableToRestoreService01 = Warning: Unable to restore service {0} - {1}.

toolText.warningUnableToRestoreSomeRegistryKeys0 = Warning: Unable to restore some registry keys - {0}

toolText.windowsUpdateClientResetNotCompletedPossibleTimeout = ⚠️ Windows Update client reset not completed (possible timeout).

toolText.windowsUpdateServicesReset = ⚙️ Windows Update Services Reset.

toolText.windowsUpdateSettingsReset = ⚙️ Windows Update settings reset.

toolText.wingetNotAvailableStartingAutomaticRecovery = ⚠️ Winget not available. Starting automatic recovery...

toolText.wingetNotAvailableUnigetUiRequiresWinget = Winget not available. UniGet UI requires Winget.

# -- Error — errors, failures, critical issues

# -- Error — errors, failures, critical issues
toolText.01Installation2 = [{0}/{1}] 📦 Install: {2}

toolText.0CheckScheduledAtNextReboot = 🔧 {0}: Check scheduled at next reboot.

toolText.0DllAlreadyPresentInTheOriginalLocation = 💭 {0}.dll already present in the original location.

toolText.0ErrorsDetectedNewAttempt = 🔄 {0} errors detected. New attempt.

toolText.0ShuttingDown1TookTooLongOrFailed = {0} Shutting down {1} took too long or failed.

toolText.0Status1Starting2 = 📊 {0} - Status: {1} | Starting: {2}.

toolText.archiveMoveError0 = Archive move error: {0}

toolText.attemptFailedILlTryForceDeletion = Attempt failed, I'll try force deletion.

toolText.attempting01SystemRepair = 🔄 Attempting {0}/{1} - System repair.

toolText.cachetaskDisableError0 = CacheTask disable error: {0}

toolText.cachetaskEnableError0 = CacheTask enable error: {0}

toolText.canBeUsedToReinstallAllDriversWithoutRedownloadingThem = 💾 Can be used to reinstall all drivers without redownloading them.

toolText.checkByOpeningSettingsUpdateSecurity = 🔧 Check by opening Settings > Update & Security.

toolText.checkCriticalSystemServices = 🔍 Check critical system services.

toolText.checkPresenceOfLogFolder = 📂 Check presence of log folder.

toolText.checkResidualFoldersInTheUsersDirectory = 🔎 Check residual folders in the users directory.

toolText.checkTheLogsForTechnicalDetails = 💡 Check the logs for technical details.

toolText.checkWingetAvailability = 🔍 Check Winget availability.

toolText.cleaned0ItemsIn1 = 🗑️ Clean {0} items in {1}.

toolText.cleaningScheduledTasks = 📅 Cleaning scheduled tasks.

toolText.cleaningWindowsUpdateStatusBeforeStartingCleanup = 🔧 Cleaning Windows Update status before starting Cleanup...

toolText.cmdkeyDelete0Error1 = cmdkey delete [{0}] error: {1}

toolText.cmdkeyListError0 = cmdkey list error: {0}

toolText.commandExecution0 = 🚀 Execute command: {0}.

toolText.compressingLogsSomeFilesInUseMayBeIgnored = 🗜️ Compressing logs. Some files in use may be ignored.

toolText.computer0 = 🖥️ Computer: {0}

toolText.criticalError0SeeTheLogInLocalappdataWintoolkitLogsOrIn1 = 💥 Critical error: {0}. See the log in %LOCALAPPDATA%\\WinToolkit\\logs or in {1}

toolText.currentUserProtected0 = 👤 Current user protected: {0}

toolText.dduExtractionError0 = DDU extraction error: {0}.

toolText.deletionOfWindowsUpdateComponents = 🗂️ Deletion of Windows Update components.

toolText.detailsOfErrorsAndWarnings = Details of Errors and Warnings:

toolText.detectingGpuConfiguration = 🔍 Detecting GPU configuration...

toolText.directory0Deleted = 🗑️ Directory {0} deleted.

toolText.directory0DeletedForcedMethod = 🗑️ Directory {0} deleted (forced method).

toolText.directory0NotPresent = 💭 Directory {0} not present.

toolText.disasterRecoveryFailed0 = Disaster recovery failed: {0}.

toolText.doNotDisturbActivation = 🔕 Do Not Disturb Activation.

toolText.downloadFailedInstallationCancelled = Download failed. Installation cancelled.

toolText.driversViaWindowsUpdateEnabled = 🖨️ Drivers via Windows Update enabled.

toolText.enableWindowsUpdateAutomaticRestart = 🔄 Enable Windows Update automatic restart.

toolText.enablingDriversViaWindowsUpdate = 🖨️ Enabling drivers via Windows Update.

toolText.enablingNetframework = 🔧 Enabling NetFramework.

toolText.enablingWindowsUpdateAndRelatedServices = 🔧 Enabling Windows Update and related services.

toolText.environmentInitializationError0 = Environment initialization error: {0}

toolText.error = Error!

toolText.errorAlsoDuringOnlineRepair0 = Error also during online repair: {0}.

toolText.errorCopyingFiles0 = Error copying files: {0}.

toolText.errorDuringDirectxInstallation0 = Error during DirectX installation: {0}

toolText.errorDuringDriverInstallation0 = Error during driver installation: {0}

toolText.errorDuringEnergyPlanActivation0 = Error during energy plan activation: {0}.

toolText.errorDuringEnergyPlanDuplication0 = Error during energy plan duplication: {0}

toolText.errorDuringFocusAssistConfiguration0 = Error during Focus Assist configuration: {0}

toolText.errorDuringGetHelpProcess0 = Error during Get Help process: {0}.

toolText.errorDuringQuickRepair0 = Error during quick repair: {0}.

toolText.errorEditingRegistry0 = Error editing registry - {0}.

toolText.errorEnablingNetframeworkFeature0Code1 = Error enabling NetFramework feature {0}: code {1}.

toolText.errorExportingDriver0 = Error exporting driver: {0}

toolText.errorExtractingArchiveGetHelp0 = Error extracting archive Get Help: {0}.

toolText.errorInAutovideodriverinstall = Error in AutoVideoDriverInstall

toolText.errorInstallingBattleNet0 = Error installing Battle.net: {0}

toolText.errorInstallingOffice0 = Error installing Office: {0}

toolText.errorInstallingUnigetUi0 = Error installing UniGet UI: {0}.

toolText.errorInVideodriverreinstall = Error in VideoDriverReinstall

toolText.errorOptimizing01 = Error optimizing {0}: {1}.

toolText.errorRestartingService0 = Error restarting service: {0}

toolText.errorRunningGetHelp0SwitchingToAlternativeMethod = Error running Get Help: {0}. Switching to alternative method.

toolText.errorSchedulingChkdskForDeepRepair = ❌ Error scheduling chkdsk for deep repair.

toolText.errorsEncountered0 = Encounter error: {0}.

toolText.errorStoppingService0 = Error stopping service: {0}

toolText.errorWhileDirectlyRemovingOffice0 = Error while directly removing Office: {0}.

toolText.exception01 = Exception {0} : {1}.

toolText.extractionGetHelp = 📦 Extraction Get Help.

toolText.failedResidualFolder0 = FAILED RESIDUAL FOLDER - {0}

toolText.failedToCreateFile0 = Failed to create file: {0}

toolText.failedToCreateParentDirectory0 = Failed to create parent directory: {0}

toolText.failedToCreateSafeModeBatch0 = Failed to create Safe Mode batch: {0}.

toolText.failedToNormalizeRegisteredProfileLocalpath0 = Failed to normalize registered profile LocalPath: {0}

toolText.finalArchive0 = 📁 Final archive: {0}

toolText.finalCheckOfTheStatusOfTheServices = 🔍 Final check of the status of the services.

toolText.getHelpFailed0AttemptedAlternativeMethod = Get Help failed: {0}. Attempted alternative method.

toolText.gpcacheCacheDeleted = 🗑️ GPCache cache deleted.

toolText.gpcacheCacheNotPresent = 💭 GPCache cache not present.

toolText.individualRestartSuppressedAFinalRebootWillBeHandled = 🚫 Individual restart suppressed. A final reboot will be handled.

toolText.initializingBackupEnvironment = 🗂️ Initializing backup environment.

toolText.initializingDriveCDecryption = 🚀 Initializing drive C: decryption.

toolText.initializingTheWindowsUpdateResetScript = 🔧 Initializing the Windows Update Reset Script.

toolText.installationError0Code1 = Installation error {0} (code: {1}).

toolText.installationFailed = Installation failed.

toolText.installingNetRuntimeAndVcredist = 🔥 Installing .NET runtime and VCRedist.

toolText.lastActivityThresholdProfilesNotUsedForAtLeast0Days = 📅 Last activity threshold: profiles not used for at least {0} days.

toolText.launchQuickRepairOffline = 🔧 Launch quick repair (offline).

toolText.log0 = 📄 Log: {0}

toolText.method0Failed1 = Method {0} failed: {1}.

toolText.method0FailedExitcode1 = Method {0} failed (ExitCode: {1}).

toolText.microsoftStoreNotRestored = ❌ Microsoft Store not restored.

toolText.movingArchiveToDesktop = 📂 Moving archive to desktop.

toolText.noRegistryKeysToRemove = 🔑 No registry keys to remove.

toolText.officeRegistryCleaner = 🔧 Office Registry Cleaner.

toolText.officeResidueCleaning = 💽 Office residue cleaning.

toolText.packetVerificationError01 = Package verification error {0}: {1}

toolText.pendingOperationsRequiringRebootDetectedDismCouldFail = Pending operations requiring reboot detected. DISM could fail.

toolText.persistentErrorsDetectedStartDeepRepair = Persistent errors detected. Start deep repair.

toolText.planCreationError = Plan creation error.

toolText.preparingArchiveCompression = 📦 Preparing archive compression.

toolText.preparingToDownloadTheNecessaryTools = 📥 Preparing to download the necessary tools...

toolText.profilePath0 = 📁 Profile path: {0}

toolText.rebootTheSystemToCompletePendingOperations = 💡 Reboot the system to complete pending operations.

toolText.rehabilitationOfScheduledTasks = 📅 Rehabilitation of scheduled tasks.

toolText.reinstallingMicrosoftStore = 🔄 Reinstalling Microsoft Store.

toolText.remnantFolderRemovalFailed01 = Remnant folder removal failed: {0} - {1}

toolText.removalViaGetHelp = 🚀 Removal via Get Help.

toolText.removingOfficeLinks = 🖥️ Removing Office links.

toolText.resetWaasmedicsvcSettings = 🔧 Reset WaaSMedicSvc settings.

toolText.resetWindowsLocalPolicies = 📋 Reset Windows local policies.

toolText.resetWindowsUpdateRegistrySettings = 📋 Reset Windows Update registry settings.

toolText.resetWingetUnhandledException0 = Reset-Winget unhandled exception: {0}

toolText.restartRecommendedBeforePerformingRepairs = 💡 Restart recommended before performing repairs.

toolText.restorationOfUpdateServices = 🔄 Restoration of update services.

toolText.restoringRenamedDlls = 🔍 Restoring renamed DLLs.

toolText.restoringWindowsUpdateRegistryKeys = 📋 Restoring Windows Update registry keys.

toolText.runspaceError0 = Runspace error: {0}

toolText.safeModeConfigurationError0 = Safe Mode configuration error: {0}.

toolText.scanningRegisteredLocalProfiles = 🔍 Scanning registered local profiles.

toolText.searchForOfficeInstallations = 📋 Search for Office installations.

toolText.searchTheRegistry = 🔍 Search the registry.

toolText.send0DesktopViaTelegramHttpsTMeMagnetarmanOrEmailMeMagnetarmanComForDiagnostics = 📩 Send '{0}' (Desktop) via Telegram [https://t.me/MagnetarMan] or email [me@magnetarman.com] for diagnostics.

toolText.servicesRegistryAndPoliciesHaveBeenConfiguredSuccessfully = 🔄 Services, registry and policies have been configured successfully.

toolText.sessionCompletedProfilesRemoved0ResidualFoldersRemoved1Errors2Duration3 = Session completed. Profiles removed: {0}. Residual folders removed: {1}. Errors: {2}. Duration: {3}.

toolText.sfcLogSavedIn0 = 📄 SFC log saved in: {0}

toolText.sourceUpdateError0 = Source update error: {0}.

toolText.standardResidualFolderRemovalFailed01 = Standard residual folder removal failed: {0} - {1}

toolText.startAutomaticRemovalOf0RegisteredProfiles = 🚀 Start automatic removal of {0} registered profiles.

toolText.startDeepRepairOfDiskCOnNextReboot = 🔧 Start deep repair of disk C: on next reboot.

toolText.startingAutomaticVideoDriverInstallation = 🚀 Starting automatic video driver installation.

toolText.startingCompleteMicrosoftOfficeRemoval = 🗑️ Starting complete Microsoft Office removal.

toolText.startingInstallationProcess = 🚀 Starting installation process.

toolText.startingOfficeDirectRemoval = 🔧 Starting Office Direct Removal.

toolText.startingOfficeRepair = 🔧 Starting Office Repair.

toolText.startingServiceDebloatProcess = 🚀 Starting service debloat process.

toolText.startingVideoDriverReinstallationRepairProcedure = 🔧 Starting video driver reinstallation/repair procedure.

toolText.startingWindowsUpdateServicesRepair = 🛠️ Starting Windows Update Services Repair.

toolText.startOfEssentialServices = 🚀 Start of essential services.

toolText.stoppingOfficeServices = 🛑 Stopping Office services.

toolText.summary0Folders1RegistryKeys2Links3TasksRemoved = 📊 Summary: {0} folder, {1} registry key, {2} link, {3} task removed.

toolText.systemInitialization = 🚀 System initialization.

toolText.theSystemRequiresARebootToApplyAllChanges = 💻 The system requires a reboot to apply all changes.

toolText.tipSomeFilesMayBeRecreatedAfterReboot = 💡 Tip: Some files may be recreated after reboot.

toolText.unableToDownloadAmdInstallerAnnulment = ❌ Unable to download AMD installer. Cancelling.

toolText.unableToDownloadNvcleanstallAnnulment = ❌ Unable to download NVCleanstall. Cancelling.

toolText.unableToMarkDiskDirtyFsutil = ❌ Unable to mark disk dirty (fsutil).

toolText.unexpectedErrorDuringResetWinget0 = Unexpected error during Reset-Winget: {0}.

toolText.unigetUiInstallation = 🔄 UniGet UI installation.

toolText.unknownErrorZipFileWasNotCreated = Unknown error: ZIP file was not created.

toolText.usingGetHelpMethodForWindows1123h2 = 🚀 Using Get Help method for Windows 11 23H2+.

toolText.windowsBuiltInDriversAreNotExported = 💡 Windows built-in drivers are not exported.

toolText.windowsLocalPoliciesRestored = 📋 Windows local policies restored.

toolText.windowsUpdateAutomaticRestartEnabled = 🔄 Windows Update automatic restart enabled.

toolText.windowsUpdateClientResetSuccessfully = 🔄 Windows Update client reset successfully.

toolText.windowsUpdateRegistrySettingsReset = 🔑 Windows Update registry settings reset.

toolText.windowsUpdateServicesStopping = 🛑 Windows Update services stopping.

toolText.windowsUpdateShouldNowWorkNormally = 💡 Windows Update should now work normally.

toolText.windowsVersionDetection = 🔍 Windows version detection.

toolText.wingetRestoreFailed = ❌ Winget restore failed.

toolText.wingetRestoreFailedUnableToProceedWithGamingToolkit = ❌ Winget restore failed. Unable to proceed with Gaming Toolkit.

toolText.wingetSourcesUpdate = 🔄 Winget sources update.

toolText.wsusSettingsNotPresent = 💭 WSUS settings not present.

toolText.wsusSettingsRemoved = 🔑 WSUS settings removed.

toolText.youCanTryAnAlternativeMethodOrManualRemoval = 💡 You can try an alternative method or manual removal.
# END toolText translations

# BEGIN toolText.extra translations

# -- Affirmative — positive outcomes (success, completion, confirmations)

# -- Affirmative — positive outcomes (success, completion, confirmations)
toolText.extra.01Completed = {0} / {1} completed

toolText.extra.chromiumBrowserCacheCleaner = 🌐 Chromium Browser Cache Cleaner.

toolText.extra.cleanmgrCompleted = ✅ CleanMgr completed.

toolText.extra.cleanmgrConfigurationEnabledForWindowsOldStateflags0066 = ✅ CleanMgr configuration enabled for Windows.old (StateFlags0066).

toolText.extra.cleanPrintQueueIn01FilesRemoved = Clean print queue in {0} ({1} files removed)

toolText.extra.cleanupWininetWebcacheCache = 🌐 Cleanup WinInet/WebCache cache.

toolText.extra.commandCompleted = Command completed.

toolText.extra.commandCompletedWithCode0 = Command completed with code {0}

toolText.extra.directxInstalledCode0 = DirectX installed (code: {0}).

toolText.extra.removalCompleted = Removal completed

toolText.extra.repairCompleted = Repair completed

toolText.extra.restorePointCleanupCompleted = Restore point cleanup completed

toolText.extra.service0RestartedSuccessfully = Service {0} restarted successfully

toolText.extra.serviceStoppedAndStateSavedAutoRestartEnabled = Service stopped and state saved - auto restart enabled

toolText.extra.unableToCleanCompletely0 = Unable to clean completely {0}

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
toolText.extra.0ShadowCopiesDetectedRemovingOld1 = {0} shadow copies detected. Removing old {1}

toolText.extra.attentionYouAreCleaningWithWindowsUpdateInProgressRefreshYourSystemAndTryAgainToPerformAFu = ATTENTION! - You are cleaning with Windows Update in progress. Refresh your system and try again to perform a full cleanup

toolText.extra.basicConfiguration = Basic configuration

toolText.extra.battleNetCode0 = Battle.net: code {0}

toolText.extra.checkServiceStatus0 = Check service status {0}.

toolText.extra.cleaning0 = Cleaning {0}

toolText.extra.cleaningAndDisablingAiChromeOptguide = 🤖 Cleaning and disabling AI Chrome (OptGuide).

toolText.extra.cleanmgrConfiguration = 🧹 CleanMgr configuration.

toolText.extra.directxInstallation = DirectX installation

toolText.extra.disasterRecoveryStore = Disaster Recovery Store

toolText.extra.diskCheck = Disk check

toolText.extra.dismDriverExport = DISM driver export

toolText.extra.groupPolicyUpdateMayTake12Minutes = Group Policy Update (may take 1-2 minutes)

toolText.extra.installation0 = Installation {0}

toolText.extra.installingBattleNet = Installing Battle.net

toolText.extra.invalidArchivePath0 = Invalid archive path: {0}

toolText.extra.logProcessing = Log processing

toolText.extra.multipleStateFilesFoundServiceWillNotBeRestartedAutomatically = Multiple state files found, service will not be restarted automatically

toolText.extra.noShadowCopyDetected = No shadow copy detected.

toolText.extra.officeBasicInstallation = Office Basic installation

toolText.extra.onlyOneShadowCopyFoundNoRemovalNecessary = Only one shadow copy found. No removal necessary.

toolText.extra.preparingToRestartTheSystem = Preparing to restart the system

toolText.extra.profilePathDoesNotExist0 = Profile path does not exist: {0}

toolText.extra.rebootingIn = Rebooting in

toolText.extra.rebootRequired = Reboot required

toolText.extra.rebootToApplyChanges = Reboot to apply changes

toolText.extra.remnantCleanupUpdates = Remnant Cleanup Updates

toolText.extra.removal0 = Removal: {0}

toolText.extra.removingOfficeUsingGetHelp = Removing Office using Get Help

toolText.extra.removingRegisteredProfiles = Removing registered profiles

toolText.extra.removingResidualFoldersInCUsers = Removing residual folders in C:\\Users

toolText.extra.restartInSafeModeForDdu = Restart in Safe Mode for DDU

toolText.extra.restartRecommendedAfterProfileCleanup = Restart recommended after profile cleanup

toolText.extra.safeModeConfigurationBcdedit = Safe Mode Configuration (bcdedit)

toolText.extra.service0ActiveStopping = Service {0} active, stopping.

toolText.extra.service0DownCheckRestart = Service {0} down, check restart.

toolText.extra.service0WasNotActivePreviously = Service {0} was not active previously

toolText.extra.serviceStoppedManualRestartRequired = Service stopped - manual restart required

toolText.extra.spoolerServiceRestarted = Spooler service restarted.

toolText.extra.spoolerServiceStopped = Spooler service stopped.

toolText.extra.storeInstallationViaWinget = Store installation via Winget

toolText.extra.systemFileChecker1 = System File Checker (1)

toolText.extra.systemFileChecker2 = System File Checker (2)

toolText.extra.systemRebootIn = System reboot in

toolText.extra.thoroughDiskCheck = Thorough disk check

toolText.extra.unigetUiInstallation = UniGet UI installation

toolText.extra.uninstallation0 = Uninstallation {0}

toolText.extra.waitingForStart0 = Waiting for start {0}

toolText.extra.windowsImageRecovery = Windows Image Recovery

# -- Warning — warnings, cautions, recoverable issues

# -- Warning — warnings, cautions, recoverable issues
toolText.extra.backupDirectoryNotFound0 = Backup directory not found: {0}

toolText.extra.criticalErrorDuringBackup = Critical error during backup

toolText.extra.iTheWindowsOldFolderMayRequireARebootForCompleteRemoval = ℹ️ The Windows.old folder may require a reboot for complete removal.

toolText.extra.registryKeyPreviousInstallationsNotFoundStandardExecutionAttempt = Registry key 'Previous Installations' not found. Standard execution attempt.

toolText.extra.restartingSpoolerService = ▶️ Restarting Spooler service.

toolText.extra.service0NotFoundSkip = Service {0} not found, skip

toolText.extra.startingService0 = ▶️ Starting service {0}.

toolText.extra.stoppingService0 = ⏸️ Stopping service {0}.

toolText.extra.stoppingSpoolerService = ⏸️ Stopping Spooler service.

toolText.extra.timeoutReachedDuringDismExport = Timeout reached during DISM export

# -- Error — errors, failures, critical issues

# -- Error — errors, failures, critical issues
toolText.extra.0NotCompletedAbortedDueToTimeout = {0} NOT completed (aborted due to Timeout).

toolText.extra.analysisAndCleaningOfShadowCopiesKeepLatest = 🗑️ Analysis and cleaning of shadow copies (keep latest).

toolText.extra.chromeAiPolicySettingError0 = Chrome AI policy setting error: {0}

toolText.extra.cleaningCredentials = 🔑 Cleaning Credentials.

toolText.extra.cleaningEventLogsClassicModern = 📜 Cleaning Event Logs (classic + modern).

toolText.extra.cleaningFirefoxCacheCrashes = 🦊 Cleaning Firefox (Cache & Crashes).

toolText.extra.cleanSystemRestorePoints = 💾 Clean system restore points.

toolText.extra.commandError0 = Command error: {0}

toolText.extra.directxError0 = DirectX error: {0}

toolText.extra.errorCleaningRestorePoints0 = Error cleaning restore points: {0}

toolText.extra.errorCleaningSpooler0 = Error cleaning Spooler: {0}

toolText.extra.errorCompressingLogs = Error compressing logs

toolText.extra.errorInInvokeRepaircommand0 = Error in Invoke-RepairCommand [{0}]

toolText.extra.failedToWriteToRegistryForCleanmgr0 = Failed to write to registry for CleanMgr: {0}

toolText.extra.improvedManagementOfDiagtrackService = 🔄 Improved management of DiagTrack service.

toolText.extra.noWindowsOldFolderDetected = 💭 No Windows.old folder detected.

toolText.extra.optguideFolderSetToReadOnly0 = 🔒 OptGuide folder set to read-only: {0}

toolText.extra.printQueueCleaningSpooler = 🖨️ Print queue cleaning (Spooler).

toolText.extra.readOnlySettingErrorFor01 = Read-only setting error for {0} : {1}

toolText.extra.registerError01 = Register error {0} : {1}

toolText.extra.removal02 = 🗑️ Removal: {0}

toolText.extra.removalError01 = Removal error {0} : {1}

toolText.extra.removedKey0 = 🗑️ Removed key {0}

toolText.extra.removingOptguideFolder0 = 🗑️ Removing OptGuide folder: {0}

toolText.extra.serviceError01 = Service Error {0} : {1}

toolText.extra.shadowCopyManagementError0 = Shadow copy management error: {0}

toolText.extra.systemProtectionKeptActiveForSafety = 💡 System protection kept active for safety

toolText.extra.windowsOldFolderDetectedStartingSafeRemovalWithNativeCleanmgr = 🗑️ Windows.old folder detected. Starting safe removal with Native CleanMgr.

toolText.extra.windowsUpdateCacheCleaner = 🔄 Windows Update cache cleaner.
# END toolText.extra translations

# BEGIN toolText.extra2 translations

# -- Affirmative — positive outcomes (success, completion, confirmations)

# -- Affirmative — positive outcomes (success, completion, confirmations)
toolText.extra2.oldShadowCopiesRemovedLastPreservedCopy = Old shadow copies removed. Last preserved copy.

toolText.extra2.printQueueSpoolerCleanedAndRestartedSuccessfully = Print Queue Spooler cleaned and restarted successfully.

toolText.extra2.waitingForCleanmgrToCompleteMayTakeAFewMinutes = ⏳ Waiting for CleanMgr to complete (may take a few minutes)...

toolText.extra2.windowsOldSuccessfullyRemoved = ✅ Windows.old successfully removed.

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
toolText.extra2.desktopDirectoryNotAccessible0 = Desktop directory not accessible: {0}

toolText.extra2.theScriptMustBeRunFromAPowershellConsoleStartedAsAdministrator = The script must be run from a PowerShell console started as administrator.

# -- Warning — warnings, cautions, recoverable issues

# -- Warning — warnings, cautions, recoverable issues
toolText.extra2.set01 = ⚙️ Set {0}\\{1}
# END toolText.extra2 translations

# BEGIN toolText.extra3 translations

# -- Affirmative — positive outcomes (success, completion, confirmations)

# -- Affirmative — positive outcomes (success, completion, confirmations)
toolText.extra3.0CompletedSuccessfully = {0} completed successfully.

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
toolText.extra3.configuring0 = Configuring {0}

toolText.extra3.starting0 = Starting {0}

toolText.extra3.stopping0 = Stopping {0}

# -- Error — errors, failures, critical issues

# -- Error — errors, failures, critical issues
toolText.extra3.0CompletedWith1Errors = {0} completed with {1} errors.
# END toolText.extra3 translations

# BEGIN uiText translations

# -- Affirmative — positive outcomes (success, completion, confirmations)

# -- Affirmative — positive outcomes (success, completion, confirmations)
sourceText.completedSuccessfully = Completed successfully

uiText.battleNetInstalled = Battle.net installed.

uiText.browserOpenForReportingOnGithub = 🌐 Browser open for reporting on GitHub.

uiText.buildCompletedWithMinorAnomaliesOrSkippedModules = The build completed with minor anomalies or skipped modules.

uiText.bypassedUserConfirmationFor0DefaultResponseYes = ✅ Bypass user confirmation for: '{0}'. Default response 'Yes'.

uiText.classicAndModernEventLogsDeleted = Classic and modern Event Logs deleted.

uiText.cleanWininetWebcache = ✅ Clean WinInet/WebCache.

uiText.completed = Completed

uiText.completed0 = Complete: {0}.

uiText.completeOfficeRepairOnline = Complete Office Repair (Online)

uiText.configurationComplete = Configuration complete.

uiText.coreScriptDownloadedSuccessfully = ✅ Core Script downloaded successfully.

uiText.countdownBypassed01Seconds = ⏳ Bypass countdown: '{0}' ({1} seconds).

uiText.deepTestPassedWingetCommunicatesCorrectlyWithRepositories = ✅ Deep test passed: Winget communicates correctly with repositories.

uiText.deepValidationPassedWingetCommunicatesWithRepositories = ✅ Deep validation passed: Winget communicates with repositories.

uiText.downloadCompleted0 = Complete download: {0}.

uiText.downloaded0 = ✅ Download: {0}.

uiText.dynamicMenuGenerated0Categories = ✅ Generate dynamic menu: {0} categories.

uiText.environmentReadyForInstallation = Environment ready for installation.

uiText.executebuttonConfiguredWithPillShapedStyleAndPlayIcon = ✅ ExecuteButton configured with pill-shaped style and Play icon.

uiText.functionsAvailableTuiMenuSuppressed = ✅ Functions available, TUI menu suppressed

uiText.getSysteminfoFunctionAvailable = ✅ Get-SystemInfo function available.

uiText.gitAlreadyInstalled = Git already installed.

uiText.gitInstalledSuccessfully = Git installed successfully.

uiText.gitInstalledViaWinget = Git installed via winget.

uiText.gitIsAlreadyOperational = ✅ Git is already operational.

uiText.iconAvailabilityCheckCompleted = 🎉 Icon availability check completed.

uiText.initializationCompleteGuiReadyToUse = 🎉 INITIALIZATION COMPLETE - GUI ready to use.

uiText.iTryNativeAppxInstallationFromDownloadedBundle = I try native Appx installation from downloaded bundle.

uiText.jetbrainsmonoNerdFontAlreadyInstalled = ✅ JetBrainsMono Nerd Font already installed.

uiText.jobInProgressStoppedAndRemoved = ✅ Job in progress stopped and removed.

uiText.loadedDependencies = Loaded dependencies.

uiText.menuStructureLoadedCategories0 = ✅ Load menu structure (categories: {0}).

uiText.microsoftAppInstallerUpdated = ✅ Microsoft.AppInstaller is present and up to date.

uiText.nerdFontsInstalledSuccessfully = ✅ Nerd Fonts installed successfully.

uiText.noPendingUpdatesDetected = ✅ No pending updates detected

uiText.officeOptimizedTelemetryPrivacyAndScheduledTasksRemoved = ✅ Office optimized: telemetry, privacy and scheduled tasks removed.

uiText.operationalWingetVersion0 = ✅ Operational Winget (version: {0}).

uiText.operationCompleted = 🎉 Operation completed!

uiText.pathAndWingetPermissionsUpdated = PATH and winget permissions updated.

uiText.phase1CompletedOperationalWinget = ✅ Complete phase 1. Operational Winget.

uiText.powershell7AlreadyInstalled = PowerShell 7 already installed.

uiText.powershell7InstalledSuccessfully = PowerShell 7 installed successfully.

uiText.powershell7ProfileConfigured = PowerShell 7 profile configured.

uiText.processed0 = ✅ Process : {0}

uiText.repairWingetpackagemanagerCompletedHigherVersionAlreadyPresent = Repair-WinGetPackageManager completed (higher version already present).

uiText.repairWingetpackagemanagerIgnoredHigherVersionAlreadyPresent = Repair-WinGetPackageManager ignored (higher version already present).

uiText.selectedScript0 = ✅ Select script: {0}.

uiText.shortcutCreatedSuccessfully = Shortcut created successfully.

uiText.success = [SUCCESS]

uiText.successLoaded0 = [SUCCESS] Load: {0}.

uiText.supportLogPackageCreated0 = ✅ Create support log package: {0}.

uiText.systemInformationPanelUpdated3BlockLayout = Update system information panel (3-block layout).

uiText.systemRestartRequiredToCompleteUpdates = ✓ System restart required to complete updates

uiText.unableToDownloadCoreScriptAndNoCacheAvailableConfiguredForFallback = Unable to download Core Script and no cache available/configured for fallback.

uiText.updatedFolderPermissions0 = Update folder permissions: {0}.

uiText.updatedPath0 = Update PATH: {0}.

uiText.updateServicesRestored = Update services restored.

uiText.updateServicesSuccessfullySuspended = Update services successfully suspended.

uiText.url0 = 🌐 URL: {0}.

uiText.validAndUpdatedLocalCacheV0CacheUsage = ✅ Valid and updated local cache (v{0}). Cache usage.

uiText.vcRedistInstalled = VC++ Redist installed.

uiText.visualCRedistributableAlreadyPresent = Visual C++ Redistributable already present.

uiText.visualCRedistributableInstalled = Visual C++ Redistributable installed.

uiText.weStronglyRecommendThatYouCompleteAllOngoingUpdates = We strongly recommend that you complete all ongoing updates,

uiText.windowCreatedSuccessfully = Window created successfully.

uiText.windowsTerminalAppxInstallationSuccessful = Windows Terminal Appx installation successful.

uiText.windowsTerminalInstalledViaWinget = Windows Terminal installed via winget.

uiText.windowsTerminalIsAlreadyInstalled = Windows Terminal is already installed.

uiText.windowsTerminalSetAsDefault = ✅ Windows Terminal set as default.

uiText.windowsTerminalSettingsUpdated0 = Update Windows Terminal settings ({0}).

uiText.windowsUpdateCacheCleared = Windows Update cache cleared.

uiText.wingetAlreadyOperationalNoRepairsNecessary = ✅ Winget already operational. No repairs necessary.

uiText.wingetClientModuleInstalled = WinGet Client module installed.

uiText.wingetCoreInstalled = Winget Core installed.

uiText.wingetCoreSuccessfullyInstalled = Winget Core successfully installed.

uiText.wingetDatabaseRestoredVersion0 = ✅ Restore Winget database (version: {0}).

uiText.wingetInstalledAndWorking = ✅ Winget installed and working.

uiText.wingetIsAlreadyOperational = ✅ Winget is already operational.

uiText.wingetMsixBundleInstallationSuccessful = Winget MSIX Bundle installation successful.

uiText.wingetNotYetReadyAttempt012SRemainWait = ⏳ Winget not yet ready (attempt {0}/{1}, {2} s remain). Wait...

uiText.wingetReadyAndDatabaseUnlockedAttempt01 = ✅ Winget ready and database unlocked (attempt {0}/{1}).

uiText.wingetRestoredQuickly = ✅ Winget restored quickly.

uiText.wingetSuccessfullyRestoredAndTested = ✅ Winget successfully restored and tested.

uiText.wintoolkitProgressTagActivity0StatusCompletedPercent100 = [WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: Completed | Percent: 100%.

# -- Informational — status, progress, notes

# -- Informational — status, progress, notes
cleanerRule.adobeMediaBrowserKey = Adobe Media Browser Key

cleanerRule.cacheHistoryCleanup = Cache/History Cleanup

cleanerRule.chromiumBrowsersCacheChromeEdgeBraveVivaldi = Chromium Browsers Cache (Chrome, Edge, Brave, Vivaldi)

cleanerRule.cleanmgrConfig = CleanMgr Config

cleanerRule.cleanupExplorerThumbnailIconCache = Cleanup - Explorer Thumbnail/Icon Cache

cleanerRule.cleanupWindowsPrefetchCache = Cleanup - Windows Prefetch Cache

cleanerRule.clearEventLogs = Clear Event Logs

cleanerRule.clearWindowsUpdateCache = Clear Windows Update cache

cleanerRule.cookiesCleanup = Cookies Cleanup

cleanerRule.credentialManager = Credential Manager

cleanerRule.developerTelemetryTraces = Developer Telemetry & Traces

cleanerRule.dnsFlush = DNS Flush

cleanerRule.edgeLegacyHtmlCache = Edge Legacy (HTML) Cache

cleanerRule.emptyRecycleBin = Empty Recycle Bin

cleanerRule.enhancedDiagtrackManagement = Enhanced DiagTrack Management

cleanerRule.firefoxBrowserCache = Firefox Browser Cache

cleanerRule.flashPlayerTraces = Flash Player Traces

cleanerRule.formDataCleanup = Form Data Cleanup

cleanerRule.googleChromeAiOptguideModel = Google Chrome AI OptGuide Model

cleanerRule.internetCookiesCleanup = Internet Cookies Cleanup

cleanerRule.listaryIndex = Listary Index

cleanerRule.minimizeDism = Minimize DISM

cleanerRule.operaJavaCache = Opera & Java Cache

cleanerRule.printQueueSpooler = Print Queue (Spooler)

cleanerRule.regeditLastKey = Regedit Last Key

cleanerRule.searchHistoryFiles = Search History Files

cleanerRule.serviceProfilesTemp = Service Profiles Temp

cleanerRule.srumData = SRUM Data

cleanerRule.startDps = Start DPS

cleanerRule.stopDps = Stop DPS

cleanerRule.systemComponentLogs = System & Component Logs

cleanerRule.systemRestorePoints = System Restore Points

cleanerRule.systemTempFiles = System Temp Files

cleanerRule.temporaryInternetFiles = Temporary Internet Files

cleanerRule.userRegistryHistoryValuesOnly = User Registry History - Values Only

cleanerRule.userTempFiles = User Temp Files

cleanerRule.visualStudioLicenses = Visual Studio Licenses

cleanerRule.windowsAppDownloadCacheUser = Windows App/Download Cache - User

cleanerRule.windowsOld = Windows.old

cleanerRule.wininetCacheUser = WinInet Cache - User

cleanerRule.winsxsCleanup = WinSxS Cleanup

cleanerRule.winutilData = WinUtil Data

gui.editionVersionsFormat = GUI Edition v{0} | Core v{1}

gui.hardware = Hardware

sourceText.active = Active

sourceText.automatic = Automatic

sourceText.check = check

sourceText.configure = configure

sourceText.file = file

sourceText.inactive = Inactive

sourceText.manual = Manual

sourceText.start = start

toolText.extra.officeSetup = Office setup

uiText.01Seconds = {0} - {1} seconds

uiText.0In1 = {0} in {1}

uiText.0In12 = {0} in {1}: {2}

uiText.0In1Seconds = {0} in {1} seconds

uiText.0OfficeProcessesClosed = {0} Office processes closed.

uiText.addingStoreViaDism = Adding Store via DISM

uiText.andSaveItIn0 = and save it in: {0}.

uiText.appxManifestStoreRegistration = AppX Manifest Store Registration

uiText.attemptingToInstallPowershell7ViaWinget = Attempt to install PowerShell 7 via Winget.

uiText.attemptingToInstallWindowsTerminalViaWinget = Attempting to install Windows Terminal via winget.

uiText.automaticStartToolkitLogInjectionPolicy0 = Policy: Automatically injecting Start-ToolkitLog for {0}.

uiText.carryingOutBasicChecks = Carrying out basic checks.

uiText.check0 = Check {0}.

uiText.closingInterferingProcesses = Closing interfering processes.

uiText.command0ExitCode1Duration2 = Command {0} (ExitCode: {1}, Duration: {2})

uiText.commandContext = Command context

uiText.commandOutput0 = Command output ({0})

uiText.compatibleSystemRecentWin1110 = Compatible system (recent Win11/10).

uiText.compatibleSystemWin10 = Compatible system (Win10).

uiText.consoleMinimized = Console minimized.

uiText.continuingBuildWithoutMinification = Continuing build without minification.

uiText.coreForJob0 = Core for job: {0}.

uiText.creatingWpfWindow = Creating WPF window.

uiText.dependencyFound0 = Find dependency: {0}.

uiText.desktopShortcutCreation = Desktop shortcut creation.

uiText.detected0StableDriverMatchesFromDriveroverridesJson = Detect {0} stable driver matches from DriverOverrides.json.

uiText.disablingBitlocker = Disabling BitLocker

uiText.download02 = Download {0}

uiText.downloadAndInstallWingetBundleWithDependencies = Download and install Winget Bundle (with dependencies).

uiText.downloadIcona = Download icon.

uiText.downloadMsixbundleDaMicrosoft = Download MSIXBundle from Microsoft.

uiText.downloadWingetDependenciesFromTheOfficialRepository = Download Winget dependencies from the official repository.

uiText.doYouReallyThinkThisScriptCanDoAnythingForThisVersion = Do you really think this script can do anything for this version?

uiText.doYouWantToTakeARiskYN = Do you want to take a risk? [Y/N]

uiText.emptyPrecompiledModule0InsertingDevelopmentStub = Empty precompiled module: '{0}'. Insert development stub.

uiText.esecuzioneRepairWingetpackagemanager = Running Repair-WinGetPackageManager.

uiText.executing0Seconds = Executing... ({0} seconds)

uiText.execution0Sec = ⏳ Execution : {0} sec

uiText.fallbackAperturaMicrosoftStorePerWindowsTerminal = Fallback: Opening Microsoft Store for Windows Terminal.

uiText.fallbackDownloadGitDaGithub = Fallback: Download Git from GitHub...

uiText.fallbackDownloadMsixbundleDirectFromMicrosoft = Fallback: Download MSIXBundle direct from Microsoft.

uiText.fileIgnored01 = Ignore file: {0} - {1}

uiText.functionDevelopmentInProgress = Function development in progress.

uiText.gitInstallation = Git installation...

uiText.guiVersion0 = GUI version: {0}

uiText.info = [INFO]

uiText.infoAdministratorPrivilegesConfirmed = [INFO] Administrator privileges confirmed.

uiText.infoLoggingInitializedTo0 = [INFO] Initialize logging to {0}.

uiText.installingMicrosoftWingetClientModule = Installing Microsoft.WinGet.Client module.

uiText.installingPowershell7InProgress = Install PowerShell 7 in progress.

uiText.installingVisualCRedistributable = Installing Visual C++ Redistributable...

uiText.installingWingetMsixbundleWithDependencies = Installing Winget MSIXBundle (with dependencies)...

uiText.interferingProcessesClosed = Interfering processes closed.

uiText.invalidDriveroverridesJson0 = Invalid DriverOverrides.json: {0}

uiText.loadingCoreScript = Loading Core Script.

uiText.loadingForms = Loading forms

uiText.localCacheExpiredAge0MinutesDownloadToUpdate = ⏰ Local cache expired (age: {0} minutes). Download to update.

uiText.manifestReRegistrationAppxmanifestXmlPreventsLeaks = Manifest re-registration: AppxManifest.xml prevents leaks.

uiText.microsoftAppInstallerPresentForcingUpdate = Microsoft.AppInstaller already present. Forcing update to the latest release.

uiText.moduloWingetClient0 = WinGet Client module: {0}.

uiText.noKnownStableDriversFoundForTheDetectedGpus = No known stable drivers found for the detected GPUs.

uiText.nugetProviderNotInstallable = NuGet provider not installable.

uiText.operationalWingetVersion02 = Operational Winget (version: {0}).

uiText.pendingSystemUpdatesHaveBeenDetected = Pending system updates have been detected:

uiText.phase1CoreRecoveryVcAppxDependenciesMsixbundle = ⚡ Phase 1: Core Recovery (VC++, AppX dependencies, MSIXBundle).

uiText.powershell0 = PowerShell: {0}.

uiText.powershell7InstallatoViaWinget = PowerShell 7 installed via Winget.

uiText.powershellJob0StartedId1 = PowerShell job '{0}' started (ID: {1}).

uiText.preparation = Preparation

uiText.preparingTheNextScript = ⏳ Preparing the next script.

uiText.pressEnterToExit = Press Enter to exit

uiText.puliziaCacheWinget = Clearing Winget cache.

uiText.quickOfficeRepairOffline = Quick Office Repair (Offline)

uiText.rebootYourSystemAndThenRestartWintoolkitBeforeContinuing = reboot your system and then restart WinToolkit before continuing.

uiText.recuperoUltimaReleasePowershell = Retrieving latest PowerShell release.

uiText.reinstallation0 = Reinstall {0}

uiText.repairWingetpackagemanagerCompletato = Repair-WinGetPackageManager completed.

uiText.repairWingetpackagemanagerEseguito = Repair-WinGetPackageManager executed.

uiText.repairWingetpackagemanagerFallito0 = Fail Repair-WinGetPackageManager: {0}.

uiText.reportCoreVersion0 = Core version: {0}

uiText.reportDate0 = Date: {0}

uiText.reRegisterManifestAppxmanifestXml = Re-register manifest: AppxManifest.xml.

uiText.resetAppInstaller = Reset App Installer.

uiText.resetCacheMicrosoftStoreWsreset = Reset cache Microsoft Store (wsreset)

uiText.resetClientUpdate = Reset Client Update

uiText.resetPackageMicrosoftDesktopappinstaller = Reset package Microsoft.DesktopAppInstaller.

uiText.resetStatusFile0 = Reset status file: {0}.

uiText.resettingWindowsUpdateServices = Resetting Windows Update Services.

uiText.resetWingetSources = Reset Winget sources.

uiText.retrieveUrlLatestReleaseOfWindowsTerminal = Retrieve URL latest release of Windows Terminal.

uiText.runningGitInstaller = Running Git installer...

uiText.sendSupportArchive0 = Send the archive on your desktop ({0}) to GitHub, describing the issues you encountered to help improve the tool.

uiText.serviceRestarted0 = Restart service: {0}.

uiText.serviceStop0 = Stop service: {0}...

uiText.startingDownload = Starting download...

uiText.startingPowershellEnvironmentSetupPsp = Starting PowerShell Environment Setup (PSP).

uiText.startingService0 = Start service: {0}...

uiText.startingWinToolkitConfiguration = Starting Win Toolkit configuration.

uiText.system01 = System: {0} ({1})

uiText.systemNotSupportedByWingetWindows101709Required = System not supported by Winget (Windows 10 1709+ required).

uiText.temaOhMyPoshScaricato = Oh My Posh theme downloaded.

uiText.temporarilySuspendWindowsUpdateServicesToAvoidConflicts = Temporarily suspend Windows Update services to avoid conflicts.

uiText.tentativoRepairWingetpackagemanager = Attempting Repair-WinGetPackageManager.

uiText.tentativoRiparazioneWingetRepairWingetpackagemanager = Attempting to repair Winget (Repair-WinGetPackageManager).

uiText.unexpectedBehaviorInSomeOrAllWintoolkitFeatures = unexpected behavior in some or all WinToolkit features.

uiText.userChoices0 = User Choices: {0}

uiText.userConfirmationPrompt0Response1 = User Confirmation Prompt: {0} | Response: {1}

uiText.ver0Build1 = {0} (Build {1})

uiText.verificaPowershell7 = Check PowerShell 7.

uiText.verifyGitInstallation = Verify Git installation...

uiText.visualCRedistributableInstallation = Visual C++ Redistributable installation.

uiText.windebloatToolkit = WinDebloat Toolkit

uiText.windows10Build0NonSupportaWinget = Windows 10 build {0} does not support Winget.

uiText.windows81PartialCompatibility = Windows 8.1: Partial compatibility.

uiText.windowsTerminalConfiguration = Windows Terminal Configuration.

uiText.windowsTerminalInstallationInProgress = Windows Terminal installation in progress.

uiText.windowsUpdateInstallationServiceIsRunning = ✓ Windows update installation service is running

uiText.wingetNotSupportedOnWindows0 = Winget not supported on Windows {0}.

uiText.wingetPresentButNotRespondingCorrectlyExitcode0 = Winget present but not responding correctly (ExitCode: {0}).

uiText.wintoolkitConfirmationBypassTagMessage0 = [WINTOOLKIT_CONFIRMATION_BYPASS_TAG] Message: {0}.

uiText.wintoolkitCountdownBypassTagMessage0Seconds1 = [WINTOOLKIT_COUNTDOWN_BYPASS_TAG] Message: {0} | Seconds: {1}.

uiText.wintoolkitInputBypassTagPrompt0 = [WINTOOLKIT_INPUT_BYPASS_TAG] Prompt: {0}

uiText.wintoolkitProgressTagActivity0Status1Percent100 = [WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: {1} | Percent: 100%.

uiText.wintoolkitProgressTagActivity0Status1Percent2 = [WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: {1} | Percent: {2}%.

uiText.wintoolkitProgressTagActivity0Status1Percent2Icon3Spinner4 = [WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: {1} | Percent: {2}% | Icon: {3} | Spinner: {4}.

uiText.wintoolkitProgressTagActivity0Status1SecondiPercent2 = [WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: {1} seconds. | Percent: {2}%.

uiText.wintoolkitProgressTagActivity0StatusInEsecuzionePercent1 = [WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: Running. | Percent: {1}%.

uiText.wintoolkitProgressTagActivity0StatusRunning1SecondsPercent2 = [WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: Running. ({1} seconds) | Percent: {2}%.

uiText.wintoolkitRawHostOutputTag0 = [WINTOOLKIT_RAW_HOST_OUTPUT_TAG]{0}

uiText.wintoolkitSessionTerminatedByUser = WinToolkit session terminated by user.

uiText.wintoolkitStyledMessageTag01 = [WINTOOLKIT_STYLED_MESSAGE_TAG] {0}: {1}

uiText.wintoolkitStyledMessageTagInfoHeader0 = [WINTOOLKIT_STYLED_MESSAGE_TAG] Info: HEADER: {0}.

# -- Warning — warnings, cautions, recoverable issues

# -- Warning — warnings, cautions, recoverable issues
uiText.01AttemptFailed2ILlTryAgain = ⚠️ Attempt {0}/{1} failed: {2}. Try again...

uiText.0Discontinued = ⚠️ {0} discontinued.

uiText.0IsEmptyUsingFallbackStaticMenu = ⚠️ \\{0} is empty, using fallback static menu.

uiText.0NotFoundAfterLoading = ⚠️ \\{0} not found after loading.

uiText.asset0NotFound = Asset '{0}' not found.

uiText.attentionGitHasNotBeenInstalledOrItMayNotWorkProperly = ⚠️ Attention: Git has not been installed or it may not work properly.

uiText.cannotGetParametersForFunction01 = Cannot get parameters for function '{0}': {1}.

uiText.checkboxReadingError0 = ⚠️ Checkbox reading error: {0}.

uiText.chromePolicySet01 = ⚙️ Set Chrome policy: {0} = {1}

uiText.cleanedValuesIn0 = ⚙️ Clean value in {0}

uiText.compressArchiveNotAvailableGuiReportSavedIn0 = ⚠️ Compress-Archive not available. Save GUI report in: {0}.

uiText.coreScriptNotFoundAt0WithinJob = Core script not found at {0} within job.

uiText.couldNotCheckBitlockerStatus0 = ⚠️ Could not check Bitlocker status: {0}.

uiText.couldNotConfigureExecutebutton = ⚠️ Could not configure ExecuteButton.

uiText.couldNotGetLocalPathForEmoji0Skipping = ⚠️ Could not get local path for emoji '{0}'. Skip.

uiText.couldNotLoadCategorysystemIcon = ⚠️ Could not load CategorySystem icon.

uiText.couldNotLoadExecutebuttonIcon = ⚠️ Could not load ExecuteButton icon.

uiText.couldNotLoadOutputlogIcon = ⚠️ Could not load OutputLog icon.

uiText.couldNotLoadSomeIcons0 = ⚠️ Could not load some icons: {0}.

uiText.couldNotLoadTooliconimage0 = ⚠️ Could not load ToolIconImage: {0}.

uiText.crashAccessViolationExitcode0RipristinoDatabase = ⚠️ Crash ACCESS_VIOLATION (ExitCode: {0}). Restore database.

uiText.crashDetectedExitcode0AccessViolationAdvancedRecoveryAttempt = ⚠️ Detect crash (ExitCode: {0} = ACCESS_VIOLATION). Attempt advanced recovery.

uiText.criticalError0 = Critical error: {0}.

uiText.deepOptimizationOfMicrosoftOffice = ⚙️ Deep optimization of Microsoft Office.

uiText.deepTestFailedExitcode0Details1 = ⚠️ Fail deep test: ExitCode={0}. Details: {1}.

uiText.deepValidationFailedExitcode0Details1 = ⚠️ Fail deep validation (ExitCode={0}). Details: {1}

uiText.downloadFailed0 = ⚠️ Fail download: {0}.

uiText.driveroverridesJsonNotFoundIn0 = DriverOverrides.json not found in {0}

uiText.duration0 = ⏱️ Duration: {0}

uiText.emptyInputTryAgain = ⚠️ Empty input. Try again.

uiText.errorReadingLocalCacheVersion0 = ⚠️ Error reading local cache version: {0}.

uiText.failedToGetRemoteVersion0AForcedDownloadOrFallbackMayBeRequired = ⚠️ Failed to get remote version: {0}. A forced download or fallback may be required.

uiText.failedToLoadOrDownloadWindowIcon0 = ⚠️ Failed to load or download window icon: {0}.

uiText.failedToSetDefaultTerminal0 = ⚠️ Failed to set default terminal: {0}.

uiText.fontInstallationViaWingetQuickMethod = ⬇️ Font installation via WinGet (Quick Method).

uiText.function0NotFoundAfterDotSourcingWithinJob = Function '{0}' not found after dot-sourcing within job.

uiText.iInteractiveInputBypassedFor0DefaultChoiceY = ℹ️ Bypass interactive input for: '{0}'. Default choice 'Y'.

uiText.importantWarning = ⚠️ IMPORTANT WARNING ⚠️

uiText.interactiveInputDetected0NotSupportedInGuiMode = ⚠️ Detect interactive input: {0} - Not supported in GUI mode.

uiText.invalidChoiceEnterNumbersBetween0 = ⚠️ Invalid choice. Enter numbers between {0}.

uiText.microsoftAppInstallerInstallationFailed = ⚠️ Unable to install Microsoft.AppInstaller.

uiText.microsoftAppInstallerNotFoundInstalling = Microsoft.AppInstaller not found. Installing it now.

uiText.newCoreVersion0AvailableCurrent1DownloadInProgress = ⬆️ New Core version ({0}) available (current: {1}). Download in progress.

uiText.noEndpointFoundInTemplateSkipping0 = No endpoint found in template. Skip: {0}.

uiText.noGuiOrCoreLogFilesFoundForReporting = ⚠️ No GUI or Core log files found for reporting.

uiText.noPs1ModulesFound0OperationCanceled = No .ps1 modules found in {0}. Operation canceled.

uiText.pendingRebootDetectedForWindowsUpdates = ⚠️ Pending reboot detected for Windows updates

uiText.persistentCrashAfterDatabaseRestore = ⚠️ Persistent crash after database restore.

uiText.persistentCrashStartingCompleteReinstallationOfWinget = ⚠️ Persistent crash. Starting complete reinstallation of Winget.

uiText.phase1InsufficientStartingPhase2AdvancedRecovery = ⚠️ Phase 1 insufficient. Start Phase 2: Advanced recovery.

uiText.proceedWithCaution = ⚠️ PROCEED WITH CAUTION ⚠️

uiText.quickRecoveryFailedAttemptAdvancedSlowerMethod = ⚠️ Quick recovery failed. Attempt advanced (slower) method.

uiText.repairOperationTimedOut = Timeout: The operation exceeded the time limit and was terminated.

uiText.restoreCompletedButWingetMayNotWork = ⚠️ Restore completed but winget may not work.

uiText.runningCommand01Timeout2S = Run command: {0} {1} (Timeout: {2}s)

uiText.settingWindowsTerminalAsDefaultViaRegistry = ⚙️ Setting Windows Terminal as default via Registry.

uiText.skipped0 = ⚠️ Skip   : {0}

uiText.systemInfoNotAvailable = System info not available.

uiText.systemRebootCancelled = ⏸️ System reboot cancelled.

uiText.templateFileNotFoundIn0 = Template file not found in: {0}

uiText.theGuiCannotContinueWithoutTheCoreScript = The GUI cannot continue without the Core Script.

uiText.timediffMeasure = ⏱️ TIMEDIFF MEASURE

uiText.timeoutAfter0Seconds = Timeout after {0} seconds.

uiText.timeoutReachedAfter0SecondsProcessTermination = Reach timeout after {0} seconds, terminate process...

uiText.toolsFolderNotFoundIn0 = Tools folder not found in: {0}

uiText.unableToCheckWindowsUpdateStatus0 = ⚠️ Unable to check Windows update status: {0}

uiText.unableToClose0 = Unable to close: {0}.

uiText.unableToExtractNumericPartFromLocale0IAssume000ForComparison = ⚠️ Unable to extract numeric part from locale '{0}'. I assume 0.0.0 for comparison.

uiText.unableToExtractNumericPartFromRemoteVersion0IAssume000ForComparison = ⚠️ Unable to extract numeric part from remote version '{0}'. I assume 0.0.0 for comparison.

uiText.unableToExtractRemoteVersionFromCoreScriptIAssume000ForComparison = ⚠️ Unable to extract remote version from Core Script. I assume 0.0.0 for comparison.

uiText.unableToExtractVersionFromLocalCacheIAssume000ForComparison = ⚠️ Unable to extract version from local cache. I assume 0.0.0 for comparison.

uiText.unableToExtractVersionFromNewlyDownloadedCore = ⚠️ Unable to extract version from newly downloaded Core.

uiText.unableToInstallWindowsTerminalViaAnyAutomaticMethod = Unable to install Windows Terminal via any automatic method.

uiText.unableToOpenBrowser0 = ⚠️ Unable to open browser: {0}.

uiText.unableToSetPermissionsOn01 = Unable to set permissions on '{0}': {1}.

uiText.unableToStartExternalProcess = Unable to start external process.

uiText.warn = [WARN]

uiText.warningInstallingSubsequentPackagesViaWingetMayFail = ⚠️ Warning: Installing subsequent packages via Winget may fail.

uiText.windowsTerminalAssetMsixbundleNotFound = Windows Terminal asset .msixbundle not found.

uiText.windowsUpdateInstallationServiceCurrentlyRunning = ⚠️ Windows Update Installation Service currently running

uiText.wingetDidNotRespondWithin0SecondsIContinueAnyway = ⚠️ Winget did not respond within {0} seconds. I continue anyway.

uiText.wingetDoesnTRespondFastRecoveryAttemptCore = ⚠️ Winget doesn't respond. Fast recovery attempt (Core).

uiText.wingetInstalledDeepValidationWithAnomaliesPossibleNetworkOrDbProblems = ⚠️ Winget installed. Deep validation with anomalies (possible network or DB problems).

uiText.wingetNotFoundInPath = Winget not found in PATH.

uiText.wingetNotFoundInSystem = Winget not found in system.

uiText.wingetNotFunctionalAfterAllAttempts = ⚠️ Winget not functional after all attempts.

uiText.wingetReturnedCode0TheFontMayRequireATerminalRestart = ⚠️ WinGet returned code {0}. The font may require a terminal restart.

uiText.wintoolkitStyledMessageTagWarningTimeoutReachedAfter0SecondsTerminatingProcess = [WINTOOLKIT_STYLED_MESSAGE_TAG][Warning] Timeout reached after {0} seconds, terminating process.

# -- Error — errors, failures, critical issues

# -- Error — errors, failures, critical issues
cleanerRule.errorReports = Error Reports

sourceText.completedWithErrors = Completed with errors

uiText.0CompletedWithErrors1 = ❌ Complete {0} with errors: {1}.

uiText.0Failed1 = ❌ Fail {0}: {1}.

uiText.advancedInstallationViaMicrosoftWingetClientModule = 🚀 Advanced installation via Microsoft.WinGet.Client module.

uiText.appxInstallFailed01 = Fail AppX install ({0}): {1}

uiText.archiveCopyFailed = Archive copy failed.

uiText.assetUrlRetrievalError0 = Asset URL retrieval error: {0}.

uiText.cached0 = 💾 Cached: {0}.

uiText.checkForJetbrainsmonoNerdFont = 🔍 Check for JetBrainsMono Nerd Font.

uiText.checkingMicrosoftAppInstallerPackage = 🔍 Checking the Microsoft.AppInstaller package.

uiText.checkWingetFunctionality = 🔍 Check Winget functionality.

uiText.closingOfficeProcesses = 📋 Closing Office processes.

uiText.coreVersion0 = 📌 Core Version: {0}.

uiText.coreVersionDownloaded0 = 📌 Download core version: {0}.

uiText.coreVersionFromFallbackCache0 = 📌 Core version from fallback cache: {0}.

uiText.couldNotMinimizeConsoleNonCritical = Could not minimize console (non-critical).

uiText.criticalErrorDuringSetup0 = ❌ Critical error during setup: {0}.

uiText.criticalErrorInReset0 = ❌ Critical error in reset: {0}

uiText.criticalErrorWhileLoadingCore0 = ❌ CRITICAL ERROR while loading Core: {0}.

uiText.deepTestExecutionOfWingetSearchForPacketsOnTheNetwork = 🔍 Deep test execution of Winget (search for packets on the network).

uiText.deepValidationError0 = Deep validation error: {0}.

uiText.dismExportFailedWithExitcode0 = Fail DISM export (ExitCode: {0}).

uiText.download0 = 📥 Download {0}...

uiText.downloadCoreScriptDaGithub = 📡 Download Core Script from GitHub.

uiText.downloadError0 = Download Error: {0}

uiText.downloadFailedAfter0Attempts1 = ❌ Fail download after {0} attempts: {1}.

uiText.downloadingIconFor0From1 = 📥 Download icon for '{0}' from {1}.

uiText.driveroverridesJsonDownloadFailedUseLocalCacheIfAvailable = DriverOverrides.json download failed, use local cache if available.

uiText.ensuringAllRequiredIconsAreAvailableLocally = 🚀 Ensuring all required icons are available locally.

uiText.error = [ERROR]

uiText.errorAdministratorPrivilegesRequired = [ERROR] Administrator privileges required.

uiText.errorDuring01 = Error during {0}: {1}

uiText.errorDuringDatabaseRestore0 = Error during database restore: {0}.

uiText.errorDuringDotSourcingCore0 = ❌ Error during dot-sourcing Core: {0}.

uiText.errorDuringIconSynchronization0 = ❌ Error during icon synchronization: {0}.

uiText.errorDuringInitializationLoaded0 = ❌ Error during initialization Loaded: {0}.

uiText.errorDuringWingetDeepTest0 = ❌ Error during Winget deep test: {0}.

uiText.errorDuringWingetTest0 = Error during Winget test: {0}.

uiText.errorExecutingFunction0WithinJob1 = Error executing function '{0}' within job: {1}.

uiText.errorFailedToCreateIconDirectory0 = [ERROR] Failed to create icon directory: {0}.

uiText.errorFailedToInitializeLogging0 = [ERROR] Failed to initialize logging. {0}.

uiText.errorFailedToLoad01 = [ERROR] Failed to load: {0} - {1}.

uiText.errorGeneratingDynamicMenu0 = ❌ Error generating dynamic menu: {0}.

uiText.errorInstallingFont0 = Error installing font: {0}.

uiText.errorInterruptingJob0 = ❌ Error interrupting job: {0}.

uiText.errorPreparingGuiLogs0 = ❌ Error preparing GUI logs: {0}.

uiText.errorRestoringDatabase0 = ❌ Error restoring database: {0}.

uiText.errorRestoringWinget0 = Error restoring Winget: {0}.

uiText.errors0 = ❌ Error    : {0}

uiText.errorSendingLog0 = ❌ Error sending log: {0}.

uiText.errorStartingJob01 = ❌ Error starting job '{0}': {1}.

uiText.errorUpdatingSystemInformation0 = Error updating system information: {0}.

uiText.exceptionInStartDeepdiskrepair = Exception in Start-DeepDiskRepair

uiText.exceptionWhileRunningExternalCommand = Exception while running external command

uiText.failedToCreateWindow0 = Failed to create window: {0}.

uiText.failedToDotSourceCoreScriptWithinJob0 = Failed to dot-source Core script within job: {0}.

uiText.failedToDownloadIcon01 = ❌ Failed to download icon '{0}': {1}.

uiText.failedToInstallWingetClientModule0 = Failed to install WinGet Client module: {0}.

uiText.failedToRestart01 = Failed to restart '{0}': {1}.

uiText.failedToRetrieveSystemInformationFromCore = Failed to retrieve system information from Core.

uiText.fatalErrorCoreScriptLoadingFailed = FATAL ERROR: Core Script loading failed.

uiText.finalFile0Kb1Lines = 📄 Final file : {0} KB ({1} line)

uiText.finalTestAfterReinstallation = 🔄 Final test after reinstallation.

uiText.generatingDynamicMenuFromCore0 = 🔄 Generate dynamic menu from Core \{0}.

uiText.getSysteminfoFunctionNotFound = ❌ Get-SystemInfo function NOT found!

uiText.gitInstallationError0 = Git installation error: {0}

uiText.gpuAnalysisErrorReadingWin32Videocontroller0 = GPU Analysis: Error reading Win32_VideoController: {0}

uiText.guiWindowClosedAttemptToStopTheJobInProgress = 🚨 GUI window closed. Attempt to stop the job in progress.

uiText.httpError01 = HTTP Error {0}: {1}

uiText.individualRestartSuppressedAFinalRebootWillBeHandled = 🚫 Individual restart suppressed. A final reboot will be handled.

uiText.installationFailedCode0 = Install failed. Code: {0}

uiText.installationFailedCode02 = Install failed. Code: {0}.

uiText.irreversibleFailureWritingFinalFile0 = Irreversible failure while writing final file to disk: {0}.

uiText.lifeProtectionActivated0 = 🛡️ Activate life protection: {0}

uiText.loadingCoreFunctionsIntoMemoryGlobalScope = 🔌 Loading Core functions into memory (Global Scope).

uiText.localCoreVersionFound0Numeric1 = 📌 Find local Core version: {0} (Numeric: {1}).

uiText.microsoftAppInstallerUpdateError0 = Microsoft.AppInstaller update error: {0}.

uiText.moduleStatistics = 📊 MODULE STATISTICS

uiText.monitoringTimerRestarted = 🔄 Monitoring timer restarted.

uiText.noLocalCacheFoundForcedDownload = 📥 No local cache found. Forced download.

uiText.noteFontsViaWingetRequireRestartingTerminalOrExplorerToBeVisible = 💡 Note: fonts via WinGet require restarting Terminal (or Explorer) to be visible.

uiText.pleaseWaitOperationInProgress = 💎 Please wait, operation in progress.

uiText.powershellInstallationError0 = PowerShell installation error: {0}.

uiText.preparingGuiErrorLogForReporting = 📦 Preparing GUI error log for reporting.

uiText.pressAnyKeyToCancel = 💡 Press any key to cancel...

uiText.profileConfigurationError0 = Profile configuration error: {0}.

uiText.ram0Gb = 💾 RAM: {0} GB

uiText.reduction01LinesRemoved = 📉 Reduce : {0} % ({1} line removed)

uiText.reductionOffFlagMinifyNotDetected = 📉 Reduction  : OFF (Flag -Minify not detected)

uiText.remoteCoreScriptVersionRecovery = 📡 Remote Core Script version recovery.

uiText.remoteCoreVersionDetected0Numeric1 = 📌 Detect remote Core version: {0} (Numeric: {1}).

uiText.repairModuleFailed0 = Fail repair module: {0}.

uiText.repeatTestAfterDatabaseRestore = 🔄 Repeat test after database restore.

uiText.resourceInitializationCoreScriptLoading = 💎 RESOURCE INITIALIZATION - Core Script loading.

uiText.ripristinoDatabaseWinget = 🔧 Restoring Winget database.

uiText.shortcutCreationError0 = Shortcut creation error: {0}.

uiText.sources0Kb1Lines = 📦 Source    : {0} KB ({1} line)

uiText.standardWindowsTerminalInstallationFailed0FallbackToTheMicrosoftStore = Fail standard Windows Terminal installation: {0}. Fallback to Microsoft Store.

uiText.startExecution0 = 🚀 Start execution: {0}.

uiText.startingWingetAdvancedRepair = 🚀 Starting Winget advanced repair...

uiText.startingWingetCoreRecoveryProcedure = 🛠️ Starting Winget (Core) recovery procedure.

uiText.startWingetDatabaseRecovery = 🔧 Start Winget database recovery.

uiText.startWingetInstallationVerificationProcedure = 🚀 Start Winget installation/verification procedure.

uiText.storageAndCompression = 💾 STORAGE AND COMPRESSION

uiText.systemClockResynced = 🕒 System clock resynchronized.

uiText.takingOwnershipFor0 = 🔑 Take ownership for {0}.

uiText.terminalSettingsUpdateError0 = Terminal settings update error: {0}.

uiText.thisMayCauseMalfunctionsErrorsOrBehavior = This may cause malfunctions, errors or behavior

uiText.tipManuallyDownloadWintoolkitPs1From = 💡 Tip: Manually download WinToolkit.ps1 from:

uiText.total0CheckboxesFound = 🔍 Find {0} checkboxes.

uiText.trashEmptied = 🗑️ Trash emptied

uiText.unableToExtractOrInstallDependenciesFromTheOfficialZipError0 = Unable to extract or install dependencies from the official zip. Error: {0}.

uiText.unableToInstallWinget = ❌ Unable to install Winget.

uiText.unhandledException01 = UNHANDLED EXCEPTION: {0} | {1}

uiText.unknownErrorsOccurred = Unknown errors occurred while running the script.

uiText.usingLocalCacheExpiredOrOlderButAvailableAsAFallback = 📂 Using local cache (expired or older, but available) as a fallback.

uiText.windowsTerminalAppxInstallationFailed = Windows Terminal Appx installation failed.

uiText.windowsUpdateStatusCheck = 🔍 Windows update status check...

uiText.wingetAdvancedInstallationError0 = Winget advanced installation error: {0}.

uiText.wingetCommandError0 = Winget command error: {0}.

uiText.wingetCoreInstallationFailed = Winget Core installation failed.

uiText.wingetDeepValidationConnectivityDatabaseIntegrity = 🔍 Winget deep validation (connectivity + database integrity).

uiText.wingetInstallationFailedOrFailedExitcode0FallbackToDirectDownload = Fail Winget installation or fail (ExitCode: {0}). Fallback to direct download.

uiText.wingetInstallationForWindowsTerminalFailed = Winget installation for Windows Terminal failed.

uiText.wingetInstallationForWindowsTerminalFailed0 = Fail Winget installation for Windows Terminal: {0}.

uiText.wingetIntegrityValidationInProgressTimeout0S = 🔍 Winget integrity validation in progress (timeout: {0} s)...

uiText.wingetMsixBundleInstallationFailed = Winget MSIX Bundle installation failed.

uiText.wintoolkitIsReadyOnTheDesktop = WinToolkit is Ready on the Desktop! 🚀

uiText.wintoolkitLoadedInLibraryMode = 📚 WinToolkit loaded in LIBRARY mode

uiText.wintoolkitStyledMessageTagErrorErroreDurante01 = [WINTOOLKIT_STYLED_MESSAGE_TAG][Error] Error during {0}: {1}.
# END uiText translations
'@
