param([int]$CountdownSeconds = 30, [switch]$ImportOnly, [string]$Language = 'en-US')
function Read-Host {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [Object]$Prompt,
        [switch]$AsSecureString,
        [switch]$MaskInput
    )
    if ($Host.Name -ne 'ConsoleHost' -or $Global:GuiSessionActive) {
        if ($Prompt) { return Microsoft.PowerShell.Utility\Read-Host -Prompt $Prompt }
        return Microsoft.PowerShell.Utility\Read-Host
    }
    $oldTreatControlC = [console]::TreatControlCAsInput
    try { [console]::TreatControlCAsInput = $true } catch {
        Write-Warning "wintoolkit-modules\00-Skeleton.Header.ps1, Read-Host 1: $($_.Exception.Message)"
    }
    try {
        if ($Prompt) { Write-Host "${Prompt}: " -NoNewline -ForegroundColor Cyan }
        $inputString = ""
        while ($true) {
            $keyInfo = [console]::ReadKey($true)
            if ($keyInfo.Modifiers -match "Control" -and $keyInfo.Key -eq "C") {
                Write-Host ""
                return $null
            }
            if ($keyInfo.Key -eq "Enter") {
                Write-Host ""
                if ($AsSecureString) {
                    $secure = New-Object System.Security.SecureString
                    foreach ($char in $inputString.ToCharArray()) { $secure.AppendChar($char) }
                    return $secure
                }
                if ($null -eq $inputString) { return "" }
                return $inputString
            }
            if ($keyInfo.Key -eq "Backspace") {
                if ($inputString.Length -gt 0) {
                    $inputString = $inputString.Substring(0, $inputString.Length - 1)
                    Write-Host "`b `b" -NoNewline
                }
            }
            else {
                if (-not [char]::IsControl($keyInfo.KeyChar)) {
                    $inputString += $keyInfo.KeyChar
                    if ($AsSecureString -or $MaskInput) { Write-Host "*" -NoNewline -ForegroundColor Yellow }
                    else { Write-Host $keyInfo.KeyChar -NoNewline }
                }
            }
        }
    }
    catch {
        if ($Prompt) { return Microsoft.PowerShell.Utility\Read-Host -Prompt $Prompt }
        return Microsoft.PowerShell.Utility\Read-Host
    }
    finally {
        try { [console]::TreatControlCAsInput = $oldTreatControlC } catch {
            Write-Warning "wintoolkit-modules\00-Skeleton.Header.ps1, Read-Host 2: $($_.Exception.Message)"
        }
    }
}
$ErrorActionPreference = 'Stop'
try { $Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan" } catch {
    Write-Warning "wintoolkit-modules\00-Skeleton.Header.ps1, script scope: $($_.Exception.Message)"
}
$ToolkitVersion = "2.6.0 (Build 5)"
$Branch = 'Dev'
$GitHubRepoRawBase = @{
    Dev  = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev"
    main = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main"
}
$GitHubRepoBase = @{
    Dev  = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev"
    main = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/main"
}
$RepoRawBase = $GitHubRepoRawBase[$Branch]
$RepoBase    = $GitHubRepoBase[$Branch]
$AppConfig = @{
    Branch          = $Branch
    ToolkitVersion = $ToolkitVersion
    URLs            = @{
        GetHelpInstaller      = "https://aka.ms/SaRA_EnterpriseVersionFiles"
        AMDInstaller          = "https://drivers.amd.com/drivers/installer/26.10/whql/amd-software-adrenalin-edition-26.5.2-minimalsetup-260513_web.exe"
        WingetInstaller       = "https://aka.ms/getwinget"
        VCRedist86            = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
        VCRedist64            = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    }
    Paths           = @{
        Root                 = "$env:LOCALAPPDATA\WinToolkit"
        Logs                 = "$env:LOCALAPPDATA\WinToolkit\logs"
        Temp                 = "$env:TEMP\WinToolkit"
        Drivers              = "$env:LOCALAPPDATA\WinToolkit\Drivers"
        OfficeTemp           = "$env:LOCALAPPDATA\WinToolkit\Office"
        DriverBackupTemp     = "$env:TEMP\DriverBackup_Temp"
        DriverBackupLogs     = "$env:LOCALAPPDATA\WinToolkit\logs"
        GamingDirectX        = "$env:LOCALAPPDATA\WinToolkit\Directx"
        GamingDirectXSetup   = "$env:LOCALAPPDATA\WinToolkit\Directx\dxwebsetup.exe"
        BattleNetSetup       = "$env:TEMP\Battle.net-Setup.exe"
        Desktop              = [Environment]::GetFolderPath('Desktop')
        Startup              = [Environment]::GetFolderPath('Startup')
        TempFolder           = $env:TEMP
        LocalAppData         = $env:LOCALAPPDATA
        System32             = "$env:windir\System32"
        SoftwareDistribution = "$env:windir\SoftwareDistribution"
        Catroot2             = "$env:windir\System32\catroot2"
    }
    Registry        = @{
        WindowsUpdatePolicies = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ExcludeWUDrivers      = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\ExcludeWUDriversInQualityUpdate"
        OfficeTelemetry       = "HKLM:\SOFTWARE\Microsoft\Office\Common\ClientTelemetry"
        DisableTelemetry      = "HKLM:\SOFTWARE\Microsoft\Office\Common\ClientTelemetry\DisableTelemetry"
        OfficeFeedback        = "HKLM:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback"
        OnBootNotify          = "HKLM:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback\OnBootNotify"
        BitLocker             = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
        BitLockerStatus       = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"
        FocusAssist           = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
        NoGlobalToasts        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\NOC_GLOBAL_SETTING_TOASTS_ENABLED"
        StartupRun            = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        WindowsTerminal       = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    }
    WindowsTerminal = @{
        DelegationTerminalClsid = "{E12F0936-0E6F-548E-A9F6-B20C69A27D17}"
        DelegationConsoleClsid  = "{B23D10C0-31E3-401A-97EF-4BB30B62E10B}"
    }
    WingetProcesses = @(
        'WinStore.App', 'wsappx', 'AppInstaller',
        'Microsoft.WindowsStore', 'Microsoft.DesktopAppInstaller',
        'winget', 'WindowsPackageManagerServer'
    )
}
$AppConfig.URLs.OfficeSetup           = "$RepoRawBase/assets/Setup.exe"
$AppConfig.URLs.OfficeBasicConfig     = "$RepoRawBase/assets/Basic.xml"
$AppConfig.URLs.NVCleanstall          = "$RepoRawBase/assets/NVCleanstall_1.19.0.exe"
$AppConfig.URLs.DDUZip                = "$RepoRawBase/assets/DDU.zip"
$AppConfig.URLs.DriverOverridesJson   = "$RepoRawBase/assets/DriverOverrides.json"
$AppConfig.URLs.DirectXWebSetup       = "$RepoRawBase/assets/dxwebsetup.exe"
$AppConfig.URLs.LanguagesRawUrl = "$RepoBase/languages"
$AppConfig.URLs.LanguagesApiUrl = "https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=$Branch"
$Global:Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
$Global:MsgStyles = @{
    Success  = @{ Icon = '✅'; Color = 'Green' }
    Warning  = @{ Icon = '⚠️'; Color = 'Yellow' }
    Error    = @{ Icon = '❌'; Color = 'Red' }
    Info     = @{ Icon = '💎'; Color = 'Cyan' }
    Progress = @{ Icon = '🔄'; Color = 'Magenta' }
    Question = @{ Icon = '❓'; Color = 'Cyan' }
}
$Global:ExecutionLog = @()
$Global:NeedsFinalReboot = $false
$Global:SourceTextLanguage = 'en-US'
$Global:SourceTextLanguageData = $null
$Global:SourceTextDefaultLanguageData = $null
$Global:SourceTextEmbeddedLanguageData = @{
    'en-US' = @{
        'bitlocker.status.decrypting' = 'Decryption in progress'
        'bitlocker.status.encrypting' = 'Encryption in progress'
        'bitlocker.status.notConfigured' = 'Not configured'
        'bitlocker.status.off' = 'Disabled'
        'bitlocker.status.on' = 'Enabled'
        'bitlocker.status.suspended' = 'Suspended'
        'bitlocker.status.unknown' = 'Unknown'
        'category.driverGaming' = 'Driver & Gaming'
        'category.office' = 'Office'
        'category.support' = 'Support'
        'category.windows' = 'Windows'
        'cleanerRule.adobeMediaBrowserKey' = 'Adobe Media Browser Key'
        'cleanerRule.cacheHistoryCleanup' = 'Cache/History Cleanup'
        'cleanerRule.chromiumBrowsersCacheChromeEdgeBraveVivaldi' = 'Chromium Browsers Cache (Chrome, Edge, Brave, Vivaldi)'
        'cleanerRule.cleanmgrConfig' = 'CleanMgr Config'
        'cleanerRule.cleanupExplorerThumbnailIconCache' = 'Cleanup - Explorer Thumbnail/Icon Cache'
        'cleanerRule.cleanupWindowsPrefetchCache' = 'Cleanup - Windows Prefetch Cache'
        'cleanerRule.clearEventLogs' = 'Clear Event Logs'
        'cleanerRule.clearWindowsUpdateCache' = 'Clear Windows Update cache'
        'cleanerRule.cookiesCleanup' = 'Cookies Cleanup'
        'cleanerRule.credentialManager' = 'Credential Manager'
        'cleanerRule.developerTelemetryTraces' = 'Developer Telemetry & Traces'
        'cleanerRule.dnsFlush' = 'DNS Flush'
        'cleanerRule.edgeLegacyHtmlCache' = 'Edge Legacy (HTML) Cache'
        'cleanerRule.emptyRecycleBin' = 'Empty Recycle Bin'
        'cleanerRule.enhancedDiagtrackManagement' = 'Enhanced DiagTrack Management'
        'cleanerRule.errorReports' = 'Error Reports'
        'cleanerRule.firefoxBrowserCache' = 'Firefox Browser Cache'
        'cleanerRule.flashPlayerTraces' = 'Flash Player Traces'
        'cleanerRule.formDataCleanup' = 'Form Data Cleanup'
        'cleanerRule.googleChromeAiOptguideModel' = 'Google Chrome AI OptGuide Model'
        'cleanerRule.internetCookiesCleanup' = 'Internet Cookies Cleanup'
        'cleanerRule.listaryIndex' = 'Listary Index'
        'cleanerRule.minimizeDism' = 'Minimize DISM'
        'cleanerRule.operaJavaCache' = 'Opera & Java Cache'
        'cleanerRule.printQueueSpooler' = 'Print Queue (Spooler)'
        'cleanerRule.regeditLastKey' = 'Regedit Last Key'
        'cleanerRule.searchHistoryFiles' = 'Search History Files'
        'cleanerRule.serviceProfilesTemp' = 'Service Profiles Temp'
        'cleanerRule.srumData' = 'SRUM Data'
        'cleanerRule.startDps' = 'Start DPS'
        'cleanerRule.stopDps' = 'Stop DPS'
        'cleanerRule.systemComponentLogs' = 'System & Component Logs'
        'cleanerRule.systemRestorePoints' = 'System Restore Points'
        'cleanerRule.systemTempFiles' = 'System Temp Files'
        'cleanerRule.temporaryInternetFiles' = 'Temporary Internet Files'
        'cleanerRule.userRegistryHistoryValuesOnly' = 'User Registry History - Values Only'
        'cleanerRule.userTempFiles' = 'User Temp Files'
        'cleanerRule.visualStudioLicenses' = 'Visual Studio Licenses'
        'cleanerRule.windowsAppDownloadCacheUser' = 'Windows App/Download Cache - User'
        'cleanerRule.windowsOld' = 'Windows.old'
        'cleanerRule.wininetCacheUser' = 'WinInet Cache - User'
        'cleanerRule.winsxsCleanup' = 'WinSxS Cleanup'
        'cleanerRule.winutilData' = 'WinUtil Data'
        'confirm.profile.accept' = 'Yes, I accept permanent deletion of local accounts and profile data'
        'confirm.profile.sure' = 'Are you absolutely sure?'
        'confirm.profile.warn1' = 'WARNING: this option permanently deletes eligible Windows user profiles and local accounts, including accounts whose profiles are already gone. Current, built-in/system, and active users are excluded.'
        'confirm.profile.warn2' = 'Deleted local accounts and data stored in deleted profiles cannot be recovered.'
        'confirm.profile.yes' = 'Yes, delete local accounts and user profiles'
        'gui.allExecuted' = 'All scripts have been executed.'
        'gui.architecture' = 'Architecture:'
        'gui.availableFunctions' = 'Available functions'
        'gui.bitlockerStatus' = 'BitLocker status:'
        'gui.complete' = 'Complete'
        'gui.disk' = 'Disk:'
        'gui.diskFreeFormat' = '{0}% free ({1} GB / {2} GB)'
        'gui.editionVersionsFormat' = 'GUI Edition v{0} | Core v{1}'
        'gui.executeScripts' = 'Run scripts'
        'gui.hardware' = 'Hardware'
        'gui.initialized' = 'WinToolkit GUI initialized successfully.'
        'gui.instructions' = 'Select one or more scripts and press ''Run scripts''.'
        'gui.languageLabel' = 'Language'
        'gui.limited' = 'Limited'
        'gui.noneSelected' = 'No script selected.'
        'gui.outputLogs' = 'Output and logs'
        'gui.pcName' = 'PC name:'
        'gui.ram' = 'RAM:'
        'gui.rebootPrompt' = 'The system requires a restart to complete the operations. Restart now?'
        'gui.rebootTitle' = 'Restart Required'
        'gui.scriptFeatures' = 'Script features:'
        'gui.sendErrorLogs' = 'Send error logs'
        'gui.systemInfo' = 'System information'
        'gui.unsupported' = 'Unsupported'
        'gui.version' = 'Version:'
        'gui.windowsEdition' = 'Windows edition:'
        'language.aiTranslated' = 'true'
        'language.code' = 'en-US'
        'language.name' = 'English'
        'language.nativeName' = 'English'
        'menu.back' = 'Back to previous menu'
        'menu.changeLanguage' = 'Change language'
        'menu.choice' = 'Selection'
        'menu.chooseLanguage' = 'Choose a language'
        'menu.closing' = 'Closing...'
        'menu.exitSection' = 'Exit'
        'menu.exitToolkit' = 'Exit Toolkit'
        'menu.invalidSelection' = 'No valid selection. Try again.'
        'menu.language' = 'Language'
        'menu.languageChanged' = 'Language changed to {0}.'
        'menu.main' = 'Main Menu'
        'menu.multiPrompt' = 'Enter one or more numbers (for example: 2 3 4 or 2,3,4) to run the operations in sequence'
        'menu.multiPromptShort' = 'Enter one or more numbers'
        'menu.noLanguages' = 'No language files were found.'
        'menu.pressEnter' = 'Press ENTER to return to the menu...'
        'menu.startedInteractive' = 'WinToolkit started in interactive mode'
        'menu.support' = 'Support: Github.com/Magnetarman'
        'noun.archive' = 'Archive'
        'noun.attempt' = 'Attempt'
        'noun.cache' = 'Cache'
        'noun.change' = 'Change'
        'noun.code' = 'Code'
        'noun.component' = 'Component'
        'noun.computer' = 'Computer'
        'noun.directory' = 'Directory'
        'noun.disk' = 'Disk'
        'noun.driver' = 'Driver'
        'noun.exception' = 'Exception'
        'noun.exitCode' = 'Exit code'
        'noun.file' = 'File'
        'noun.folder' = 'Folder'
        'noun.font' = 'Font'
        'noun.gpu' = 'GPU'
        'noun.icon' = 'Icon'
        'noun.log' = 'Log'
        'noun.operation' = 'Operation'
        'noun.package' = 'Package'
        'noun.pendingOperation' = 'Pending operation'
        'noun.policy' = 'Policy'
        'noun.profile' = 'Profile'
        'noun.registry' = 'Registry'
        'noun.registryKey' = 'Registry key'
        'noun.script' = 'Script'
        'noun.service' = 'Service'
        'noun.shortcut' = 'Shortcut'
        'noun.status' = 'Status'
        'noun.summary' = 'Summary'
        'noun.system' = 'System'
        'noun.task' = 'Task'
        'noun.tool' = 'Tool'
        'noun.update' = 'Update'
        'noun.user' = 'User'
        'noun.version' = 'Version'
        'noun.videoDriver' = 'Video driver'
        'noun.window' = 'Window'
        'reboot.countdown' = 'System restart in'
        'reboot.reminder' = 'Remember to restart the system manually to complete the operations.'
        'reboot.required' = 'A restart is required to complete the operations.'
        'run.cancelled' = 'Operation cancelled. Returning to the main menu.'
        'run.error' = 'Error while running {0}: {1}'
        'run.sequence' = 'Running {0} operations in sequence...'
        'run.start' = 'Starting: {0}'
        'script.AutoVideoDriverInstall' = 'Auto install video driver [Nvidia-AMD]'
        'script.DisableBitlocker' = 'Disable BitLocker'
        'script.GamingToolkit' = 'Gaming Toolkit'
        'script.Install-Office' = 'Install Office Basic'
        'script.Repair-Office' = 'Repair Office'
        'script.Uninstall-Office' = 'Remove Office'
        'script.VideoDriverReinstall' = 'Reinstall video driver'
        'script.WinBackupDriver' = 'PC driver backup'
        'script.WinCleaner' = 'Temporary file cleanup'
        'script.WinDeleteUserProfiles' = 'Delete Windows accounts, user profiles and residual folders'
        'script.WinExportLog' = 'Export WinToolkit logs'
        'script.WinReinstallStore' = 'Winget/WinStore reset'
        'script.WinRepairToolkit' = 'Windows repair'
        'script.WinUpdateReset' = 'Reset Windows Update'
        'sourceText.active' = 'Active'
        'sourceText.applyingUnwrapping' = 'Applying unwrapping.'
        'sourceText.automatic' = 'Automatic'
        'sourceText.automaticRestart' = 'Automatic restart'
        'sourceText.cancelled' = 'cancelled'
        'sourceText.check' = 'check'
        'sourceText.compilerPs1PipelineExecutedWithCode' = 'compiler.ps1 pipeline executed with code'
        'sourceText.completed' = 'Completed'
        'sourceText.completedSuccessfully' = 'Completed successfully'
        'sourceText.completedWithErrors' = 'Completed with errors'
        'sourceText.configure' = 'configure'
        'sourceText.configured' = 'configured'
        'sourceText.coreScriptContentIsEmptyAfterLoadingAttempts' = 'Core Script content is empty after loading attempts.'
        'sourceText.created' = 'created'
        'sourceText.criticalError' = 'Critical error'
        'sourceText.deleted' = 'deleted'
        'sourceText.detected' = 'detected'
        'sourceText.detectedInternalFunctionIn' = 'Detected internal function in'
        'sourceText.download' = 'download'
        'sourceText.downloaded' = 'downloaded'
        'sourceText.enabled' = 'enabled'
        'sourceText.failed' = 'failed'
        'sourceText.file' = 'file'
        'sourceText.in' = 'in'
        'sourceText.inactive' = 'Inactive'
        'sourceText.initializationError' = 'Initialization error'
        'sourceText.iOErrorWhileAggregatingModule' = 'I/O error while aggregating module'
        'sourceText.iOErrorWhileReadingSourceFiles' = 'I/O error while reading source files'
        'sourceText.manual' = 'Manual'
        'sourceText.moduleProcessed' = 'Module processed'
        'sourceText.modules' = 'modules'
        'sourceText.notFound' = 'not found'
        'sourceText.operation' = 'operation'
        'sourceText.operationCompleted' = 'Operation completed!'
        'sourceText.pendingOperations' = 'pending operations'
        'sourceText.pressAnyKeyToExit' = 'Press any key to exit'
        'sourceText.pressAnyKeyToExit2' = '''Press any key to exit.'''
        'sourceText.readingSourceTemplate' = 'Reading source template'
        'sourceText.removal' = 'Removal'
        'sourceText.removed' = 'Removed'
        'sourceText.restored' = 'restored'
        'sourceText.savingStandaloneExecutable' = 'Saving standalone executable'
        'sourceText.sources' = 'sources'
        'sourceText.start' = 'start'
        'sourceText.starting' = 'Starting'
        'sourceText.startingAggregation' = 'Starting aggregation'
        'sourceText.startingSafeMinificationThroughThePowershellTokenizer' = 'Starting safe minification through the PowerShell tokenizer.'
        'sourceText.startingWintoolkitBuildProcess' = 'Starting WinToolkit build process.'
        'sourceText.stopped' = 'stopped'
        'sourceText.summary' = 'Summary'
        'sourceText.summaryBuildDashboard' = 'SUMMARY BUILD DASHBOARD'
        'sourceText.systemRestart' = 'System restart'
        'sourceText.unexpectedError' = 'Unexpected error'
        'sourceText.unexpectedErrorDuringMinification' = 'Unexpected error during minification'
        'sourceText.unknownError' = 'Unknown error'
        'sourceText.version' = 'Version'
        'sourceText.warning' = 'Warning'
        'summary.changed' = 'Changed'
        'summary.completed' = 'Completed'
        'summary.detail' = 'Detail'
        'summary.error' = 'Error'
        'summary.failed' = 'Failed'
        'summary.operation' = 'Operation'
        'summary.skipped' = 'Skipped'
        'summary.status' = 'Status'
        'summary.succeeded' = 'Succeeded'
        'summary.title' = 'Execution Summary'
        'system.architecture' = 'Architecture'
        'system.bitlockerStatus' = 'BitLocker status'
        'system.computerName' = 'PC name'
        'system.disk' = 'Disk'
        'system.edition' = 'Edition'
        'system.free' = 'Free'
        'system.infoTitle' = 'SYSTEM INFORMATION'
        'system.version' = 'Version'
        'toolText.01Installation2' = '[{0}/{1}] Install: {2}'
        'toolText.01Starting2' = '[{0}/{1}] Starting {2}.'
        'toolText.01Status2' = '{0} {1} - Status: {2}'
        'toolText.0CheckScheduledAtNextReboot' = '{0}: Check scheduled at next reboot.'
        'toolText.0Code1' = '{0}: code {1}.'
        'toolText.0DeletedCaches' = '{0} deleted cache.'
        'toolText.0DllAlreadyPresentInTheOriginalLocation' = '{0}.dll already present in the original location.'
        'toolText.0DllNotFoundAndNoBackupAvailable' = '{0}.dll not found and no backup available.'
        'toolText.0Error0x800f0806PendingOperationsThisIsNotACriticalError' = '{0}: Error 0x800f0806 (pending operations). This is not a critical error.'
        'toolText.0ErrorsDetectedNewAttempt' = '{0} errors detected. New attempt.'
        'toolText.0FilesIgnoredBecauseTheyAreInUseOrNotAccessible' = '{0} files ignored because they are in use or not accessible.'
        'toolText.0ItemsNotRemovedMayBeBlockedByOpenSessionsOrHandles' = '{0} items not removed may be blocked by open sessions or handles.'
        'toolText.0OfficeFoldersRemoved' = '{0} Office folder removed.'
        'toolText.0OfficeLinksRemoved' = '{0} Office link removed.'
        'toolText.0OfficeRegistryKeysRemoved' = '{0} Office registry key removed.'
        'toolText.0OfficeTasksRemoved' = '{0} Office task removed.'
        'toolText.0Reverting1To2' = '{0} Reverting {1} to {2}.'
        'toolText.0Service1ConfiguredAs2' = '{0} Service {1} configured as {2}.'
        'toolText.0Service1NotFoundOnTheSystem' = '{0} Service {1} not found on the system.'
        'toolText.0Service1Restored' = '{0} Service {1} restored.'
        'toolText.0Service1StartedSuccessfully' = '{0} Service {1}: Started successfully.'
        'toolText.0Service1StartingOrDelayed' = '{0} Service {1}: Starting or delayed.'
        'toolText.0Service1Stopped' = '{0} Service {1} stopped.'
        'toolText.0ServiceProcessing1' = '{0} Service processing: {1}.'
        'toolText.0ShuttingDown1TookTooLongOrFailed' = '{0} Shutting down {1} took too long or failed.'
        'toolText.0Status1Starting2' = '{0} - Status: {1} | Starting: {2}.'
        'toolText.0Unable123' = '{0} Unable {1} {2} - {3}.'
        'toolText.0V1' = '{0} v{1}'
        'toolText.alertsGenerated0' = 'Generate alert: {0}.'
        'toolText.archiveMoveError0' = 'Archive move error: {0}'
        'toolText.archiveSavedToDesktop' = 'Archive saved to desktop.'
        'toolText.attemptedVia0' = 'Attempted via: {0}.'
        'toolText.attemptFailedILlTryForceDeletion' = 'Attempt failed, I''ll try force deletion.'
        'toolText.attempting01SystemRepair' = 'Attempting {0}/{1} - System repair.'
        'toolText.attemptingFullRepairOnlineAsAFallback' = 'Attempting full repair (online) as a fallback.'
        'toolText.autostart0RemovedFromRegistry' = 'Autostart ''{0}'' removed from registry.'
        'toolText.autostartCleaner' = 'Autostart cleaner.'
        'toolText.autostartLink0Removed' = 'Autostart link ''{0}'' removed.'
        'toolText.autoVideoDriverInstallFinished' = 'Auto Video Driver Install finished.'
        'toolText.autovideodriverinstallSessionEnded' = 'AutoVideoDriverInstall session ended.'
        'toolText.batchSwitchToNormalModeBatCreatedOnDesktop' = 'Batch ''Switch to Normal Mode.bat'' created on Desktop.'
        'toolText.battleNetProcessDidNotStartProperly' = 'Battle.net: Process did not start properly.'
        'toolText.battleNetTimedOut' = 'Battle.net timed out.'
        'toolText.blockingAutomaticDriversFromWindowsUpdate' = 'Blocking automatic drivers from Windows Update.'
        'toolText.cachetaskDisableError0' = 'CacheTask disable error: {0}'
        'toolText.cachetaskEnableError0' = 'CacheTask enable error: {0}'
        'toolText.canBeUsedToReinstallAllDriversWithoutRedownloadingThem' = 'Can be used to reinstall all drivers without redownloading them.'
        'toolText.checkByOpeningSettingsUpdateSecurity' = 'Check by opening Settings > Update & Security.'
        'toolText.checkCriticalSystemServices' = 'Check critical system services.'
        'toolText.checkPresenceOfLogFolder' = 'Check presence of log folder.'
        'toolText.checkResidualFoldersInTheUsersDirectory' = 'Check residual folders in the users directory.'
        'toolText.checkTheLogsForTechnicalDetails' = 'Check the logs for technical details.'
        'toolText.checkWingetAvailability' = 'Check Winget availability.'
        'toolText.chkdskCommandSentRebootToPerformDeepDiskRepair' = 'Chkdsk command sent. Reboot to perform deep disk repair.'
        'toolText.cimProfileDetectionFailed0' = 'Failed to detect profiles via CIM: {0}.'
        'toolText.cimProfileRemoved0' = 'CIM profile removed: {0}.'
        'toolText.cimRemoveFailed01' = 'CIM remove failed: {0} - {1}.'
        'toolText.cleaned0ItemsIn1' = 'Clean {0} items in {1}.'
        'toolText.cleaningCompleted' = 'Cleaning completed.'
        'toolText.cleaningScheduledTasks' = 'Cleaning scheduled tasks.'
        'toolText.cleaningWindowsUpdateStatusBeforeStartingCleanup' = 'Cleaning Windows Update status before starting Cleanup...'
        'toolText.cleanupFailed01' = 'Cleanup failed: {0} - {1}.'
        'toolText.cleanupGpcacheCacheAndWsusSettings' = 'Cleanup GPCache cache and WSUS settings.'
        'toolText.clearEventlog0' = 'Clear-EventLog: {0}'
        'toolText.clearEventlog01' = 'Clear-EventLog [{0}]: {1}'
        'toolText.clientsInstalled' = 'Clients installed.'
        'toolText.cmdkeyDelete0Error1' = 'cmdkey delete [{0}] error: {1}'
        'toolText.cmdkeyListError0' = 'cmdkey list error: {0}'
        'toolText.commandExecution0' = 'Execute command: {0}.'
        'toolText.commandTimesOutAfter0Hours' = 'Command times out after {0} hours.'
        'toolText.completed' = 'COMPLETED'
        'toolText.completedProfile01' = 'COMPLETED PROFILE - {0} - {1:hh:mm:ss}'
        'toolText.completedResidualFolder01' = 'COMPLETED RESIDUAL FOLDER - {0} - {1}'
        'toolText.compressingLogsSomeFilesInUseMayBeIgnored' = 'Compressing logs. Some files in use may be ignored.'
        'toolText.compressionCompleted0MbReduction1' = 'Complete compression: {0} MB (Reduction: {1}%).'
        'toolText.computer0' = 'Computer: {0}'
        'toolText.couldNotEnumerateRegistryProfileList0' = 'Could not enumerate registry ProfileList: {0}.'
        'toolText.createBackupAndLogDirectories' = 'Create backup and log directories.'
        'toolText.criteriaRemoved' = 'Criteria removed.'
        'toolText.criticalError0SeeTheLogInLocalappdataWintoolkitLogsOrIn1' = 'Critical error: {0}. See the log in %LOCALAPPDATA%\WinToolkit\logs or in {1}'
        'toolText.criticalErrorDuringDriverReinstallation0' = 'Critical error during driver reinstallation: {0}'
        'toolText.criticalErrorInInstallOffice' = 'Critical error in Install-Office'
        'toolText.criticalErrorInRepairOffice' = 'Critical error in Repair-Office'
        'toolText.criticalErrorInUninstallOffice' = 'Critical error in Uninstall-Office'
        'toolText.criticalErrorRepairingOffice0' = 'Critical error repairing Office: {0}'
        'toolText.criticalErrorWhileRemovingOffice0' = 'Critical error while removing Office: {0}'
        'toolText.currentUserProtected0' = 'Current user protected: {0}'
        'toolText.dduExtractedToDesktop' = 'DDU extracted to Desktop.'
        'toolText.dduExtractionError0' = 'DDU extraction error: {0}.'
        'toolText.debloatOperationsCompleted' = 'Debloat operations completed.'
        'toolText.decryptionInProgressInBackground' = 'Decryption in progress in background.'
        'toolText.decryptionStartedCompletedSuccessfully' = 'Decryption started/completed successfully.'
        'toolText.deletingLocalPolicies' = 'Deleting local policies.'
        'toolText.deletionOfWindowsUpdateComponents' = 'Deletion of Windows Update components.'
        'toolText.detailsOfErrorsAndWarnings' = 'Details of Errors and Warnings:'
        'toolText.detectingGpuConfiguration' = 'Detecting GPU configuration...'
        'toolText.directories01' = 'Directories ({0}/{1})'
        'toolText.directory0Deleted' = 'Directory {0} deleted.'
        'toolText.directory0DeletedForcedMethod' = 'Directory {0} deleted (forced method).'
        'toolText.directory0NotPresent' = 'Directory {0} not present.'
        'toolText.directory0PartiallyDeleted' = 'Directory {0} partially deleted.'
        'toolText.directRemovalCompleted' = 'Direct removal completed.'
        'toolText.directxDownloaded' = 'DirectX downloaded.'
        'toolText.directxInstallation' = 'DirectX installation.'
        'toolText.directxProcessDidNotStartCorrectly' = 'DirectX: Process did not start correctly.'
        'toolText.directxTimeout' = 'DirectX timeout.'
        'toolText.disablebitlockerSessionEnded' = 'DisableBitlocker session ended.'
        'toolText.disablingAutomaticEncryptionInTheRegistry' = 'Disabling automatic encryption in the registry.'
        'toolText.disasterRecoveryFailed0' = 'Disaster recovery failed: {0}.'
        'toolText.doNotDisturbActivation' = 'Do Not Disturb Activation.'
        'toolText.doNotDisturbActive' = 'Do Not Disturb active.'
        'toolText.downloadFailedInstallationCancelled' = 'Download failed. Installation cancelled.'
        'toolText.driverBackupCompletedSuccessfully' = 'Driver backup completed successfully!'
        'toolText.driverBackupToolkitFinished' = 'Driver Backup Toolkit finished.'
        'toolText.driversViaWindowsUpdateEnabled' = 'Drivers via Windows Update enabled.'
        'toolText.driverWuBlockError0IContinueAnyway' = 'Error blocking driver updates: {0}. Continuing anyway.'
        'toolText.driverWuLockSet' = 'Driver updates are now blocked.'
        'toolText.elimination0' = 'Elimination {0}'
        'toolText.emergencyAttemptViaAppxmanifest' = 'Emergency attempt via AppXManifest.'
        'toolText.enableWindowsUpdateAutomaticRestart' = 'Enable Windows Update automatic restart.'
        'toolText.enablingDriversViaWindowsUpdate' = 'Enabling drivers via Windows Update.'
        'toolText.enablingNetframework' = 'Enabling NetFramework.'
        'toolText.enablingWindowsUpdateAndRelatedServices' = 'Enabling Windows Update and related services.'
        'toolText.energyProfileConfiguration' = 'Energy profile configuration.'
        'toolText.environmentInitializationError0' = 'Environment initialization error: {0}'
        'toolText.error' = 'Error!'
        'toolText.errorAlsoDuringOnlineRepair0' = 'Error also during online repair: {0}.'
        'toolText.errorCopyingFiles0' = 'Error copying files: {0}.'
        'toolText.errorDuringDirectxInstallation0' = 'Error during DirectX installation: {0}'
        'toolText.errorDuringDriverInstallation0' = 'Error during driver installation: {0}'
        'toolText.errorDuringEnergyPlanActivation0' = 'Error during energy plan activation: {0}.'
        'toolText.errorDuringEnergyPlanDuplication0' = 'Error during energy plan duplication: {0}'
        'toolText.errorDuringFocusAssistConfiguration0' = 'Error during Focus Assist configuration: {0}'
        'toolText.errorDuringGetHelpProcess0' = 'Error during Get Help process: {0}.'
        'toolText.errorDuringQuickRepair0' = 'Error during quick repair: {0}.'
        'toolText.errorEditingRegistry0' = 'Error editing registry - {0}.'
        'toolText.errorEnablingNetframeworkFeature0Code1' = 'Error enabling NetFramework feature {0}: code {1}.'
        'toolText.errorExportingDriver0' = 'Error exporting driver: {0}'
        'toolText.errorExtractingArchiveGetHelp0' = 'Error extracting archive Get Help: {0}.'
        'toolText.errorInAutovideodriverinstall' = 'Error in AutoVideoDriverInstall'
        'toolText.errorInstallingBattleNet0' = 'Error installing Battle.net: {0}'
        'toolText.errorInstallingOffice0' = 'Error installing Office: {0}'
        'toolText.errorInstallingUnigetUi0' = 'Error installing UniGet UI: {0}.'
        'toolText.errorInVideodriverreinstall' = 'Error in VideoDriverReinstall'
        'toolText.errorOptimizing01' = 'Error optimizing {0}: {1}.'
        'toolText.errorRestartingService0' = 'Error restarting service: {0}'
        'toolText.errorRunningGetHelp0SwitchingToAlternativeMethod' = 'Error running Get Help: {0}. Switching to alternative method.'
        'toolText.errorSchedulingChkdskForDeepRepair' = 'Error scheduling chkdsk for deep repair.'
        'toolText.errorsEncountered0' = 'Encounter error: {0}.'
        'toolText.errorStoppingService0' = 'Error stopping service: {0}'
        'toolText.errorWhileDirectlyRemovingOffice0' = 'Error while directly removing Office: {0}.'
        'toolText.exception01' = 'Exception {0} : {1}.'
        'toolText.excludedProfile01' = 'Excluded profile: {0} ({1}).'
        'toolText.excludedProfileBecauseSidMatchesCurrentUser0' = 'Excluded profile because SID matches current user: {0} ({1}).'
        'toolText.existingPlanFound' = 'Existing plan found.'
        'toolText.exportCompleted0Driver1Mb' = 'Complete export: {0} driver ({1} MB).'
        'toolText.extra.01Completed' = '{0} / {1} completed'
        'toolText.extra.0NotCompletedAbortedDueToTimeout' = '{0} NOT completed (aborted due to Timeout).'
        'toolText.extra.0ShadowCopiesDetectedRemovingOld1' = '{0} shadow copies detected. Removing old {1}'
        'toolText.extra.analysisAndCleaningOfShadowCopiesKeepLatest' = 'Analysis and cleaning of shadow copies (keep latest).'
        'toolText.extra.attentionYouAreCleaningWithWindowsUpdateInProgressRefreshYourSystemAndTryAgainToPerformAFu' = 'ATTENTION! - You are cleaning with Windows Update in progress. Refresh your system and try again to perform a full cleanup'
        'toolText.extra.backupDirectoryNotFound0' = 'Backup directory not found: {0}'
        'toolText.extra.basicConfiguration' = 'Basic configuration'
        'toolText.extra.battleNetCode0' = 'Battle.net: code {0}'
        'toolText.extra.checkServiceStatus0' = 'Check service status {0}.'
        'toolText.extra.chromeAiPolicySettingError0' = 'Chrome AI policy setting error: {0}'
        'toolText.extra.chromiumBrowserCacheCleaner' = 'Chromium Browser Cache Cleaner.'
        'toolText.extra.cleaning0' = 'Cleaning {0}'
        'toolText.extra.cleaningAndDisablingAiChromeOptguide' = 'Cleaning and disabling AI Chrome (OptGuide).'
        'toolText.extra.cleaningCredentials' = 'Cleaning Credentials.'
        'toolText.extra.cleaningEventLogsClassicModern' = 'Cleaning Event Logs (classic + modern).'
        'toolText.extra.cleaningFirefoxCacheCrashes' = 'Cleaning Firefox (Cache & Crashes).'
        'toolText.extra.cleanmgrCompleted' = 'CleanMgr completed.'
        'toolText.extra.cleanmgrConfiguration' = 'CleanMgr configuration.'
        'toolText.extra.cleanmgrConfigurationEnabledForWindowsOldStateflags0066' = 'CleanMgr configuration enabled for Windows.old (StateFlags0066).'
        'toolText.extra.cleanPrintQueueIn01FilesRemoved' = 'Clean print queue in {0} ({1} files removed)'
        'toolText.extra.cleanSystemRestorePoints' = 'Clean system restore points.'
        'toolText.extra.cleanupWininetWebcacheCache' = 'Cleanup WinInet/WebCache cache.'
        'toolText.extra.commandCompleted' = 'Command completed.'
        'toolText.extra.commandCompletedWithCode0' = 'Command completed with code {0}'
        'toolText.extra.commandError0' = 'Command error: {0}'
        'toolText.extra.criticalErrorDuringBackup' = 'Critical error during backup'
        'toolText.extra.directxError0' = 'DirectX error: {0}'
        'toolText.extra.directxInstallation' = 'DirectX installation'
        'toolText.extra.directxInstalledCode0' = 'DirectX installed (code: {0}).'
        'toolText.extra.disasterRecoveryStore' = 'Disaster Recovery Store'
        'toolText.extra.diskCheck' = 'Disk check'
        'toolText.extra.dismDriverExport' = 'DISM driver export'
        'toolText.extra.errorCleaningRestorePoints0' = 'Error cleaning restore points: {0}'
        'toolText.extra.errorCleaningSpooler0' = 'Error cleaning Spooler: {0}'
        'toolText.extra.errorCompressingLogs' = 'Error compressing logs'
        'toolText.extra.errorInInvokeRepaircommand0' = 'Error in Invoke-RepairCommand [{0}]'
        'toolText.extra.failedToWriteToRegistryForCleanmgr0' = 'Failed to write to registry for CleanMgr: {0}'
        'toolText.extra.groupPolicyUpdateMayTake12Minutes' = 'Group Policy Update (may take 1-2 minutes)'
        'toolText.extra.improvedManagementOfDiagtrackService' = 'Improved management of DiagTrack service.'
        'toolText.extra.installation0' = 'Installation {0}'
        'toolText.extra.installingBattleNet' = 'Installing Battle.net'
        'toolText.extra.invalidArchivePath0' = 'Invalid archive path: {0}'
        'toolText.extra.iTheWindowsOldFolderMayRequireARebootForCompleteRemoval' = 'The Windows.old folder may require a reboot for complete removal.'
        'toolText.extra.logProcessing' = 'Log processing'
        'toolText.extra.multipleStateFilesFoundServiceWillNotBeRestartedAutomatically' = 'Multiple state files found, service will not be restarted automatically'
        'toolText.extra.noShadowCopyDetected' = 'No shadow copy detected.'
        'toolText.extra.noWindowsOldFolderDetected' = 'No Windows.old folder detected.'
        'toolText.extra.officeBasicInstallation' = 'Office Basic installation'
        'toolText.extra.officeSetup' = 'Office setup'
        'toolText.extra.onlyOneShadowCopyFoundNoRemovalNecessary' = 'Only one shadow copy found. No removal necessary.'
        'toolText.extra.optguideFolderSetToReadOnly0' = 'OptGuide folder set to read-only: {0}'
        'toolText.extra.preparingToRestartTheSystem' = 'Preparing to restart the system'
        'toolText.extra.printQueueCleaningSpooler' = 'Print queue cleaning (Spooler).'
        'toolText.extra.profilePathDoesNotExist0' = 'Profile path does not exist: {0}'
        'toolText.extra.readOnlySettingErrorFor01' = 'Read-only setting error for {0} : {1}'
        'toolText.extra.rebootingIn' = 'Rebooting in'
        'toolText.extra.rebootRequired' = 'Reboot required'
        'toolText.extra.rebootToApplyChanges' = 'Reboot to apply changes'
        'toolText.extra.registerError01' = 'Register error {0} : {1}'
        'toolText.extra.registryKeyPreviousInstallationsNotFoundStandardExecutionAttempt' = 'Registry key ''Previous Installations'' not found. Standard execution attempt.'
        'toolText.extra.remnantCleanupUpdates' = 'Remnant Cleanup Updates'
        'toolText.extra.removal0' = 'Removal: {0}'
        'toolText.extra.removal02' = 'Removal: {0}'
        'toolText.extra.removalCompleted' = 'Removal completed'
        'toolText.extra.removalError01' = 'Removal error {0} : {1}'
        'toolText.extra.removedKey0' = 'Removed key {0}'
        'toolText.extra.removingOfficeUsingGetHelp' = 'Removing Office using Get Help'
        'toolText.extra.removingOptguideFolder0' = 'Removing OptGuide folder: {0}'
        'toolText.extra.removingRegisteredProfiles' = 'Removing registered profiles'
        'toolText.extra.removingResidualFoldersInCUsers' = 'Removing residual folders in C:\Users'
        'toolText.extra.repairCompleted' = 'Repair completed'
        'toolText.extra.restartingSpoolerService' = 'Restarting Spooler service.'
        'toolText.extra.restartInSafeModeForDdu' = 'Restart in Safe Mode for DDU'
        'toolText.extra.restartRecommendedAfterProfileCleanup' = 'Restart recommended after profile cleanup'
        'toolText.extra.restorePointCleanupCompleted' = 'Restore point cleanup completed'
        'toolText.extra.safeModeConfigurationBcdedit' = 'Safe Mode Configuration (bcdedit)'
        'toolText.extra.service0ActiveStopping' = 'Service {0} active, stopping.'
        'toolText.extra.service0DownCheckRestart' = 'Service {0} down, check restart.'
        'toolText.extra.service0NotFoundSkip' = 'Service {0} not found, skip'
        'toolText.extra.service0RestartedSuccessfully' = 'Service {0} restarted successfully'
        'toolText.extra.service0WasNotActivePreviously' = 'Service {0} was not active previously'
        'toolText.extra.serviceError01' = 'Service Error {0} : {1}'
        'toolText.extra.serviceStoppedAndStateSavedAutoRestartEnabled' = 'Service stopped and state saved - auto restart enabled'
        'toolText.extra.serviceStoppedManualRestartRequired' = 'Service stopped - manual restart required'
        'toolText.extra.shadowCopyManagementError0' = 'Shadow copy management error: {0}'
        'toolText.extra.spoolerServiceRestarted' = 'Spooler service restarted.'
        'toolText.extra.spoolerServiceStopped' = 'Spooler service stopped.'
        'toolText.extra.startingService0' = 'Starting service {0}.'
        'toolText.extra.stoppingService0' = 'Stopping service {0}.'
        'toolText.extra.stoppingSpoolerService' = 'Stopping Spooler service.'
        'toolText.extra.storeInstallationViaWinget' = 'Store installation via Winget'
        'toolText.extra.systemFileChecker1' = 'System File Checker (1)'
        'toolText.extra.systemFileChecker2' = 'System File Checker (2)'
        'toolText.extra.systemProtectionKeptActiveForSafety' = 'System protection kept active for safety'
        'toolText.extra.systemRebootIn' = 'System reboot in'
        'toolText.extra.thoroughDiskCheck' = 'Thorough disk check'
        'toolText.extra.timeoutReachedDuringDismExport' = 'Timeout reached during DISM export'
        'toolText.extra.unableToCleanCompletely0' = 'Unable to clean completely {0}'
        'toolText.extra.unigetUiInstallation' = 'UniGet UI installation'
        'toolText.extra.uninstallation0' = 'Uninstallation {0}'
        'toolText.extra.waitingForStart0' = 'Waiting for start {0}'
        'toolText.extra.windowsImageRecovery' = 'Windows Image Recovery'
        'toolText.extra.windowsOldFolderDetectedStartingSafeRemovalWithNativeCleanmgr' = 'Windows.old folder detected. Starting safe removal with Native CleanMgr.'
        'toolText.extra.windowsUpdateCacheCleaner' = 'Windows Update cache cleaner.'
        'toolText.extra2.desktopDirectoryNotAccessible0' = 'Desktop directory not accessible: {0}'
        'toolText.extra2.oldShadowCopiesRemovedLastPreservedCopy' = 'Old shadow copies removed. Last preserved copy.'
        'toolText.extra2.printQueueSpoolerCleanedAndRestartedSuccessfully' = 'Print Queue Spooler cleaned and restarted successfully.'
        'toolText.extra2.set01' = 'Set {0}\{1}'
        'toolText.extra2.theScriptMustBeRunFromAPowershellConsoleStartedAsAdministrator' = 'The script must be run from a PowerShell console started as administrator.'
        'toolText.extra2.waitingForCleanmgrToCompleteMayTakeAFewMinutes' = 'Waiting for CleanMgr to complete (may take a few minutes)...'
        'toolText.extra2.windowsOldSuccessfullyRemoved' = 'Windows.old successfully removed.'
        'toolText.extra3.0CompletedSuccessfully' = '{0} completed successfully.'
        'toolText.extra3.0CompletedWith1Errors' = '{0} completed with {1} errors.'
        'toolText.extra3.configuring0' = 'Configuring {0}'
        'toolText.extra3.starting0' = 'Starting {0}'
        'toolText.extra3.stopping0' = 'Stopping {0}'
        'toolText.extractingDduToDesktop' = 'Extracting DDU to Desktop.'
        'toolText.extractionCompleted' = 'Extraction completed.'
        'toolText.extractionGetHelp' = 'Extraction Get Help.'
        'toolText.failedProfile0' = 'FAILED PROFILE - {0}'
        'toolText.failedResidualFolder0' = 'FAILED RESIDUAL FOLDER - {0}'
        'toolText.failedToCreateFile0' = 'Failed to create file: {0}'
        'toolText.failedToCreateParentDirectory0' = 'Failed to create parent directory: {0}'
        'toolText.failedToCreateSafeModeBatch0' = 'Failed to create Safe Mode batch: {0}.'
        'toolText.failedToExportSfcCbsLogFileInUse' = 'Failed to export SFC CBS log (file in use).'
        'toolText.failedToNormalizeRegisteredProfileLocalpath0' = 'Failed to normalize registered profile LocalPath: {0}'
        'toolText.failedToRemoveRegistryEntryForSid01' = 'Failed to remove registry entry for SID: {0} - {1}.'
        'toolText.finalArchive0' = 'Final archive: {0}'
        'toolText.finalCheckOfTheStatusOfTheServices' = 'Final check of the status of the services.'
        'toolText.finalCleaning' = 'Final cleaning.'
        'toolText.folderRemoved0' = 'Folder removed: {0}.'
        'toolText.folderRemovedAfterAclReset0' = 'Folder removed after ACL reset: {0}.'
        'toolText.found0OfficePackages' = 'Find {0} Office package.'
        'toolText.gameClientInstallation' = 'Game client installation.'
        'toolText.gamingToolkitCompleted' = 'Gaming Toolkit completed!'
        'toolText.gethelpcmdExeNotFound' = 'GetHelpCmd.exe not found.'
        'toolText.getHelpCompletedSuccessfully' = 'Get Help completed successfully.'
        'toolText.getHelpFailed0AttemptedAlternativeMethod' = 'Get Help failed: {0}. Attempted alternative method.'
        'toolText.getHelpStartedTheRemovalInAnExternalWindowWaitingForCompletion' = 'Get Help started the removal in an external window. Waiting for completion...'
        'toolText.gpcacheCacheDeleted' = 'GPCache cache deleted.'
        'toolText.gpcacheCacheNotPresent' = 'GPCache cache not present.'
        'toolText.gpuDetected0' = 'Detect GPU: {0}.'
        'toolText.gpuNotDetectedDriverNotAvailableForAutomaticInstallation' = 'GPU not detected: Driver not available for automatic installation.'
        'toolText.gpuNotDetectedOnlyDduWillBePlacedOnTheDesktop' = 'GPU not detected: Only DDU will be placed on the Desktop.'
        'toolText.gpupdateCompletedWithCode0IContinueAnyway' = 'Complete gpupdate with code: {0}. Continue anyway.'
        'toolText.gpupdateDidNotRespondIContinueAnyway' = 'gpupdate did not respond. Continuing anyway.'
        'toolText.gpupdateTerminatedWithErrorsOrTimedOut' = 'gpupdate terminated with errors or timed out.'
        'toolText.individualRestartSuppressedAFinalRebootWillBeHandled' = 'Individual restart suppressed. A final reboot will be handled.'
        'toolText.initializingBackupEnvironment' = 'Initializing backup environment.'
        'toolText.initializingDriveCDecryption' = 'Initializing drive C: decryption.'
        'toolText.initializingTheWindowsUpdateResetScript' = 'Initializing the Windows Update Reset Script.'
        'toolText.inProgress0Seconds' = 'In progress... ({0} seconds)'
        'toolText.inSafeModeRunDduToCleanTheDriversThenReinstallWithTheDesktopInstallerFinallyUseBatchToRetu' = 'In Safe Mode: Run DDU to clean the drivers, then reinstall with the Desktop installer. Finally use batch to return to normal mode.'
        'toolText.installationCompleted' = 'Installation completed.'
        'toolText.installationError0Code1' = 'Installation error {0} (code: {1}).'
        'toolText.installationFailed' = 'Installation failed.'
        'toolText.installed0' = '''Install {0}'''
        'toolText.installingBattleNet' = 'Installing Battle.net.'
        'toolText.installingNetRuntimeAndVcredist' = 'Installing .NET runtime and VCRedist.'
        'toolText.installOfficeSessionEnded' = 'Install-Office session ended.'
        'toolText.intelGpuDownloadDriversManuallyFromIntelIfNecessary' = 'Intel GPU: Download drivers manually from Intel if necessary.'
        'toolText.itemsNotRemoved0' = 'Items not removed: {0}'
        'toolText.lastActivityThresholdProfilesNotUsedForAtLeast0Days' = 'Last activity threshold: profiles not used for at least {0} days.'
        'toolText.launchQuickRepairOffline' = 'Launch quick repair (offline).'
        'toolText.localAccountProtected0' = 'Local account {0} is protected or in use; deletion was skipped.'
        'toolText.localAccountRemovalFailed01' = 'Failed to remove local account {0}: {1}'
        'toolText.localAccountRemoved01' = 'Local account removed: {0} ({1}).'
        'toolText.localAccountsRemoved0' = 'Local accounts removed: {0}'
        'toolText.localAccountsSelectedForAutomaticRemoval0' = 'Local accounts selected for automatic removal: {0}'
        'toolText.localAccountStillExists0' = 'Local account still exists after deletion: {0}'
        'toolText.location0' = 'Location: {0}'
        'toolText.log0' = 'Log: {0}'
        'toolText.logsCompressedSuccessfullySavedFile0OnDesktop' = 'Logs compressed successfully! Saved file: ''{0}'' on Desktop.'
        'toolText.manageBdeExitCode0BitlockerMayAlreadyBeDownOrInError' = 'manage-bde exit code: {0}. BitLocker may already be down or in error.'
        'toolText.method0Failed1' = 'Method {0} failed: {1}.'
        'toolText.method0FailedExitcode1' = 'Method {0} failed (ExitCode: {1}).'
        'toolText.microsoftStoreNotRestored' = 'Microsoft Store not restored.'
        'toolText.microsoftStoreReinstalledVia0' = 'Microsoft Store reinstalled via {0}.'
        'toolText.microsoftStoreRestoredViaEmergencyMethod' = 'Microsoft Store restored via emergency method.'
        'toolText.microsoftStoreSuccessfullyRestored' = 'Microsoft Store successfully restored.'
        'toolText.movingArchiveToDesktop' = 'Moving archive to desktop.'
        'toolText.netframeworkEnabled' = 'NetFramework enabled.'
        'toolText.netframeworkFeatureEnabled0' = 'Enable NetFramework feature: {0}.'
        'toolText.noFilesToCompressInBackupDirectory' = 'No files to compress in backup directory.'
        'toolText.noKnownStableDriversFoundIUseAutodetectFallback' = 'No known stable drivers found. I use autodetect fallback.'
        'toolText.noLogFilesCopiedCheckPermissionsAndThatTheFilesExist' = 'No log files copied. Check permissions and that the files exist.'
        'toolText.nonInteractiveModeNoConfirmationWillBeRequestedBeforeCancellations' = 'Non-interactive mode: no confirmation will be requested before cancellations.'
        'toolText.noProblemsDetected' = 'No problems detected.'
        'toolText.noRegistryKeysToRemove' = 'No registry keys to remove.'
        'toolText.noRemovableRegisteredProfilesFound' = 'No removable registered profiles found.'
        'toolText.noRemovableResidualFolderFoundInCUsers' = 'No removable residual folder found in C:\Users.'
        'toolText.noRemovableResidualFoldersFound' = 'No removable residual folders found.'
        'toolText.noteARebootIsRequiredToFullyApplyAllChanges' = 'Note: A reboot is required to fully apply all changes.'
        'toolText.noThirdPartyDriversFoundToExport' = 'No third party drivers found to export.'
        'toolText.officeCacheCleaner' = 'Office cache cleaner.'
        'toolText.officeclicktorunExeNotFoundOfficeMayNotBeInstalled' = 'OfficeClickToRun.exe not found. Office may not be installed.'
        'toolText.officeFolderCleaning' = 'Office folder cleaning.'
        'toolText.officeInstallFinished' = 'Office Install finished.'
        'toolText.officePostInstallationConfiguration' = 'Office post-installation configuration.'
        'toolText.officePostRepairSetup' = 'Office post-repair setup.'
        'toolText.officeRegistryCleaner' = 'Office Registry Cleaner.'
        'toolText.officeRemovalComplete' = 'Office removal complete!'
        'toolText.officeRepairComplete' = 'Office Repair Complete!'
        'toolText.officeRepairFinished' = 'Office Repair finished.'
        'toolText.officeResidueCleaning' = 'Office residue cleaning.'
        'toolText.officeUninstallFinished' = 'Office Uninstall finished.'
        'toolText.operationCompleted' = 'Operation completed.'
        'toolText.operationsCompletedSuccessfully0' = 'Complete operations successfully: {0}.'
        'toolText.packetVerificationError01' = 'Package verification error {0}: {1}'
        'toolText.pendingOperationsRequiringRebootDetectedDismCouldFail' = 'Pending operations requiring reboot detected. DISM could fail.'
        'toolText.performingAWindowsUpdateClientReset' = 'Performing a Windows Update client reset...'
        'toolText.persistentErrorsDetectedStartDeepRepair' = 'Persistent errors detected. Start deep repair.'
        'toolText.planActivated' = 'Plan activated.'
        'toolText.planCreated' = 'Plan created.'
        'toolText.planCreationError' = 'Plan creation error.'
        'toolText.policyUpdate' = 'Policy update.'
        'toolText.preparingArchiveCompression' = 'Preparing archive compression.'
        'toolText.preparingToDownloadTheNecessaryTools' = 'Preparing to download the necessary tools...'
        'toolText.pressAnyKeyToContinue' = 'Press any key to continue.'
        'toolText.pressAnyKeyToExit' = 'Press any key to exit.'
        'toolText.profileExcludedDueToTimeThreshold0LastUse1' = 'Profile excluded due to time threshold: {0}, last use {1}.'
        'toolText.profilePath0' = 'Profile path: {0}'
        'toolText.rebootRequiredForDeepRepair' = 'Reboot required for deep repair.'
        'toolText.rebootTheSystemToCompletePendingOperations' = 'Reboot the system to complete pending operations.'
        'toolText.recommendedReboot0' = 'Recommend reboot: {0}'
        'toolText.registeredProfilesRemoved0' = 'Registered profiles removed: {0}'
        'toolText.registeredProfilesSelectedForAutomaticRemoval' = 'Registered profiles selected for automatic removal:'
        'toolText.registryEntryRemovedForSid01' = 'Registry entry removed for SID: {0} ({1}).'
        'toolText.rehabilitationOfScheduledTasks' = 'Rehabilitation of scheduled tasks.'
        'toolText.reinstallation0' = 'Reinstall {0}.'
        'toolText.reinstalled0' = '''Reinstall {0}.'''
        'toolText.reinstallingMicrosoftStore' = 'Reinstalling Microsoft Store.'
        'toolText.reinstallingXboxGameBarApp' = 'Reinstalling Xbox Game Bar & App.'
        'toolText.remainingFolderCleanupSkipped' = 'Remaining folder cleanup skipped.'
        'toolText.remnantFolderRemovalFailed01' = 'Remnant folder removal failed: {0} - {1}'
        'toolText.removalNotCompleted' = 'Removal not completed.'
        'toolText.removalViaGetHelp' = 'Removal via Get Help.'
        'toolText.removed0' = '''Remove {0}'''
        'toolText.removed02' = '''Remove {0}.'''
        'toolText.removingOffice' = 'Removing Office'
        'toolText.removingOfficeLinks' = 'Removing Office links.'
        'toolText.removingOldArchive' = 'Removing old archive.'
        'toolText.removingPreviousBackups' = 'Removing previous backups.'
        'toolText.repairCompletedSuccessfully' = 'Repair completed successfully!'
        'toolText.repairOfficeSessionEnded' = 'Repair-Office session ended.'
        'toolText.resetWaasmedicsvcSettings' = 'Reset WaaSMedicSvc settings.'
        'toolText.resetWindowsLocalPolicies' = 'Reset Windows local policies.'
        'toolText.resetWindowsUpdateRegistrySettings' = 'Reset Windows Update registry settings.'
        'toolText.resetWindowsUpdateSettings' = 'Reset Windows Update settings.'
        'toolText.resetWingetUnhandledException0' = 'Reset-Winget unhandled exception: {0}'
        'toolText.residualFolderCleanupSkippedForSkipresidualfoldercleanupParameter' = 'Residual folder cleanup skipped for SkipResidualFolderCleanup parameter.'
        'toolText.residualFolderExcludedBecauseItIsStillAssociatedWithWin32Userprofile01' = 'Residual folder excluded because it is still associated with Win32_UserProfile: {0} ({1}).'
        'toolText.residualFolderExcludedBecauseReparsePointSymlink01' = 'Residual folder excluded because reparse point/symlink: {0} ({1}).'
        'toolText.residualFolderExcludedBecauseSidStillRegistered01' = 'Residual folder excluded because SID is still registered in ProfileList: {0} ({1}).'
        'toolText.residualFolderExcludedForProtectedName01' = 'Residual folder excluded for protected name: {0} ({1}).'
        'toolText.residualFoldersRemoved0' = 'Residual folders removed: {0}'
        'toolText.residualFoldersSelectedForAutomaticRemoval0' = 'Residual folders selected for automatic removal: {0}'
        'toolText.resourceCleanupAndWindebloatSessionShutdown' = 'Resource cleanup and WinDebloat session shutdown.'
        'toolText.resourceCleanupCompleted' = 'Resource cleanup completed.'
        'toolText.restartMicrosoftStoreServices' = 'Restart Microsoft Store services.'
        'toolText.restartNotRequired' = 'Restart not required.'
        'toolText.restartRecommendedBeforePerformingRepairs' = 'Restart recommended before performing repairs.'
        'toolText.restartRecommendedToCompleteCleanupOfUnremovedProfiles' = 'Restart recommended to complete cleanup of unremoved profiles.'
        'toolText.restorationOfUpdateServices' = 'Restoration of update services.'
        'toolText.restoringRenamedDlls' = 'Restoring renamed DLLs.'
        'toolText.restoringWindowsUpdateRegistryKeys' = 'Restoring Windows Update registry keys.'
        'toolText.reverted0BakDllTo1Dll' = 'Reverted {0}_BAK.dll to {1}.dll.'
        'toolText.ruleExecution' = 'Rule execution'
        'toolText.runspaceError0' = 'Runspace error: {0}'
        'toolText.runtimesCompleted' = 'Runtimes completed.'
        'toolText.safeModeConfigurationError0' = 'Safe Mode configuration error: {0}.'
        'toolText.safeModeConfiguredForNextBoot' = 'Safe mode configured for next boot.'
        'toolText.scanningRegisteredLocalProfiles' = 'Scanning registered local profiles.'
        'toolText.searchForOfficeInstallations' = 'Search for Office installations.'
        'toolText.searchTheRegistry' = 'Search the registry.'
        'toolText.send0DesktopViaTelegramHttpsTMeMagnetarmanOrEmailMeMagnetarmanComForDiagnostics' = 'Send ''{0}'' (Desktop) via Telegram [https://t.me/MagnetarMan] or email [me@magnetarman.com] for diagnostics.'
        'toolText.service0OptimizedSuccessfully' = 'Optimize service {0} successfully.'
        'toolText.serviceOptimization01' = 'Optimize service: {0} ({1}).'
        'toolText.servicesRegistryAndPoliciesHaveBeenConfiguredSuccessfully' = 'Services, registry and policies have been configured successfully.'
        'toolText.serviceStopped0' = 'Stop service: {0}.'
        'toolText.sessionCompletedProfilesRemoved0ResidualFoldersRemoved1Errors2Duration3' = 'Session completed. Profiles removed: {0}. Residual folders removed: {1}. Errors: {2}. Duration: {3}.'
        'toolText.sessionStartedOn0' = 'Start session on {0}.'
        'toolText.setupComplete' = 'Setup complete.'
        'toolText.sfcLogSavedIn0' = 'SFC log saved in: {0}'
        'toolText.sourceUpdateError0' = 'Source update error: {0}.'
        'toolText.stableDriverDownloadedToDesktop0' = 'Download stable driver to desktop: {0}'
        'toolText.standardFolderCleanupFailed01' = 'Standard folder cleanup failed: {0} - {1}'
        'toolText.standardResidualFolderRemovalFailed01' = 'Standard residual folder removal failed: {0} - {1}'
        'toolText.startAutomaticRemovalOf0RegisteredProfiles' = 'Start automatic removal of {0} registered profiles.'
        'toolText.startDeepRepairOfDiskCOnNextReboot' = 'Start deep repair of disk C: on next reboot.'
        'toolText.startingAutomaticVideoDriverInstallation' = 'Starting automatic video driver installation.'
        'toolText.startingCompleteMicrosoftOfficeRemoval' = 'Starting complete Microsoft Office removal.'
        'toolText.startingInstallationProcess' = 'Starting installation process.'
        'toolText.startingOfficeBasicInstallation' = 'Starting Office Basic installation.'
        'toolText.startingOfficeDirectRemoval' = 'Starting Office Direct Removal.'
        'toolText.startingOfficeRepair' = 'Starting Office Repair.'
        'toolText.startingRemovalOfResidualFolders' = 'Starting removal of residual folders.'
        'toolText.startingServiceDebloatProcess' = 'Starting service debloat process.'
        'toolText.startingStoreWingetReinstallation' = 'Starting Store & Winget reinstallation.'
        'toolText.startingVideoDriverReinstallationRepairProcedure' = 'Starting video driver reinstallation/repair procedure.'
        'toolText.startingWindowsUpdateServicesRepair' = 'Starting Windows Update Services Repair.'
        'toolText.startOfEssentialServices' = 'Start of essential services.'
        'toolText.startResidualFolder01' = 'START RESIDUAL FOLDER - {0} - {1}'
        'toolText.stoppingOfficeServices' = 'Stopping Office services.'
        'toolText.storeCacheReset' = 'Store cache reset.'
        'toolText.summary0Folders1RegistryKeys2Links3TasksRemoved' = 'Summary: {0} folder, {1} registry key, {2} link, {3} task removed.'
        'toolText.summaryOfOperations' = 'SUMMARY OF OPERATIONS'
        'toolText.systemDetected0TheScriptIsDesignedForWindows11' = 'Detect system: {0}. The script is designed for Windows 11.'
        'toolText.systemHealthyDeepRepairNotNecessary' = 'System healthy. Deep repair not necessary.'
        'toolText.systemInitialization' = 'System initialization.'
        'toolText.systemOptimizedForGaming' = 'System optimized for gaming.'
        'toolText.taskEnabled0' = 'Task enabled: {0}.'
        'toolText.telemetryAndPrivacyOfficeDisabled' = 'Telemetry and Privacy Office disabled.'
        'toolText.temporaryEnvironmentCleaning' = 'Temporary environment cleaning.'
        'toolText.theLogsFolder0WasNotFoundUnableToExport' = 'The logs folder ''{0}'' was not found. Unable to export.'
        'toolText.theSystemRequiresARebootToApplyAllChanges' = 'The system requires a reboot to apply all changes.'
        'toolText.thisOperationMayTakeAFewMinutes' = 'This operation may take a few minutes.'
        'toolText.threadsConfigured0' = 'Configure threads: {0}'
        'toolText.tipSomeFilesMayBeRecreatedAfterReboot' = 'Tip: Some files may be recreated after reboot.'
        'toolText.totalSize0Mb' = 'Total size: {0} MB'
        'toolText.unableToActivatePlan' = 'Unable to activate plan.'
        'toolText.unableToCheckBitlockerStatus0' = 'Unable to check BitLocker status: {0}'
        'toolText.unableToCompletelyDelete0FileInUse' = 'Unable to completely delete {0} - file in use.'
        'toolText.unableToDetectWindowsVersion0' = 'Unable to detect Windows version: {0}'
        'toolText.unableToDownloadAmdInstallerAnnulment' = 'Unable to download AMD installer. Cancelling.'
        'toolText.unableToDownloadDduAnnulment' = 'Unable to download DDU. Cancelling.'
        'toolText.unableToDownloadNvcleanstallAnnulment' = 'Unable to download NVCleanstall. Cancelling.'
        'toolText.unableToMarkDiskDirtyFsutil' = 'Unable to mark disk dirty (fsutil).'
        'toolText.unableToReinstallMicrosoftStoreViaAutomaticMethods' = 'Unable to reinstall Microsoft Store via automatic methods.'
        'toolText.unableToRemove0FoldersMayBeInUse' = 'Unable to remove {0} folders (may be in use).'
        'toolText.unexpectedErrorDuringResetWinget0' = 'Unexpected error during Reset-Winget: {0}.'
        'toolText.unigetUiInstallation' = 'UniGet UI installation.'
        'toolText.unigetUiInstallationFinishedWithCode0' = 'UniGet UI installation finished with code: {0}.'
        'toolText.unigetUiInstalled' = 'UniGet UI installed.'
        'toolText.unigetUiInstalledSuccessfully' = 'UniGet UI installed successfully.'
        'toolText.unigetUiRequireManualVerification' = 'UniGet UI require manual verification.'
        'toolText.uninstallOfficeSessionEnded' = 'Uninstall-Office session ended.'
        'toolText.unknownErrorZipFileWasNotCreated' = 'Unknown error: ZIP file was not created.'
        'toolText.unlimitedPasswordExpirationSetting' = 'Unlimited password expiration setting.'
        'toolText.updatedCriteria' = 'Updated criteria.'
        'toolText.updatedGroupPolicy' = 'Updated Group Policy.'
        'toolText.updatedSources' = 'Updated sources.'
        'toolText.usingDirectRemovalForWindows1122h2OrEarlier' = 'Using direct removal for Windows 11 22H2 or earlier.'
        'toolText.usingGetHelpMethodForWindows1123h2' = 'Using Get Help method for Windows 11 23H2+.'
        'toolText.versionDetected0' = 'Detect version: {0}.'
        'toolText.videoDriverReinstallFinished' = 'Video Driver Reinstall finished.'
        'toolText.videodriverreinstallSessionEnded' = 'VideoDriverReinstall session ended.'
        'toolText.waasmedicsvcSettingsReset' = 'WaaSMedicSvc settings reset.'
        'toolText.waitingForResourcesToBeReleased' = 'Waiting for resources to be released.'
        'toolText.warningFailedToDeleteGpcacheCache0' = 'Warning: Failed to delete GPCache cache - {0}.'
        'toolText.warningFailedToRemoveWsusSettings0' = 'Warning: Failed to remove WSUS settings - {0}.'
        'toolText.warningFailedToRepair0Dll1' = 'Warning: Failed to repair {0}.dll - {1}.'
        'toolText.warningFailedToRestoreWaasmedicsvc0' = 'Warning: Failed to restore WaaSMedicSvc - {0}.'
        'toolText.warningTheSystemWillRebootIntoSafeMode' = 'WARNING: The system will reboot into safe mode.'
        'toolText.warningTheSystemWillRestartAutomatically' = 'Warning: The system will restart automatically.'
        'toolText.warningUnableToEnableAutomaticRestart0' = 'Warning: Unable to enable automatic restart - {0}.'
        'toolText.warningUnableToEnableDriver0' = 'Warning: Unable to enable driver - {0}.'
        'toolText.warningUnableToEnableTaskIn01' = 'Warning: Unable to enable task in {0} - {1}.'
        'toolText.warningUnableToResetSomePolicies0' = 'Warning: Unable to reset some policies - {0}.'
        'toolText.warningUnableToResetSomeSettings0' = 'Warning: Unable to reset some settings - {0}.'
        'toolText.warningUnableToRestoreService01' = 'Warning: Unable to restore service {0} - {1}.'
        'toolText.warningUnableToRestoreSomeRegistryKeys0' = 'Warning: Unable to restore some registry keys - {0}'
        'toolText.wevtutilCl01' = 'Wevtutil cl [{0}]: {1}'
        'toolText.wevtutilSlOutput0' = 'wevtutil sl output: {0}'
        'toolText.winbackupdriverSessionEnded' = 'WinBackupDriver session ended.'
        'toolText.windebloatSessionEnded' = 'WinDebloat session ended.'
        'toolText.winDeleteUserProfilesSessionEnded' = 'WinDeleteUserProfiles session ended.'
        'toolText.windowsBuiltInDriversAreNotExported' = 'Windows built-in drivers are not exported.'
        'toolText.windowsLocalPoliciesRestored' = 'Windows local policies restored.'
        'toolText.windowsUpdateAutomaticRestartEnabled' = 'Windows Update automatic restart enabled.'
        'toolText.windowsUpdateClientResetNotCompletedPossibleTimeout' = 'Windows Update client reset not completed (possible timeout).'
        'toolText.windowsUpdateClientResetSuccessfully' = 'Windows Update client reset successfully.'
        'toolText.windowsUpdateHasBeenRestoredToDefaultValues' = 'Windows Update has been RESTORED to default values!'
        'toolText.windowsUpdateRegistrySettingsReset' = 'Windows Update registry settings reset.'
        'toolText.windowsUpdateServicesReset' = 'Windows Update Services Reset.'
        'toolText.windowsUpdateServicesStopping' = 'Windows Update services stopping.'
        'toolText.windowsUpdateSettingsReset' = 'Windows Update settings reset.'
        'toolText.windowsUpdateShouldNowWorkNormally' = 'Windows Update should now work normally.'
        'toolText.windowsVersionDetection' = 'Windows version detection.'
        'toolText.winexportlogSessionEnded' = 'WinExportLog session ended.'
        'toolText.wingetAvailable' = 'Winget available.'
        'toolText.wingetNotAvailableStartingAutomaticRecovery' = 'Winget not available. Starting automatic recovery...'
        'toolText.wingetNotAvailableUnigetUiRequiresWinget' = 'Winget not available. UniGet UI requires Winget.'
        'toolText.wingetRestoredAndOperational' = 'Winget restored and operational.'
        'toolText.wingetRestoreFailed' = 'Winget restore failed.'
        'toolText.wingetRestoreFailedUnableToProceedWithGamingToolkit' = 'Winget restore failed. Unable to proceed with Gaming Toolkit.'
        'toolText.wingetSourcesUpdate' = 'Winget sources update.'
        'toolText.wsusSettingsNotPresent' = 'WSUS settings not present.'
        'toolText.wsusSettingsRemoved' = 'WSUS settings removed.'
        'toolText.xboxReinstalled' = 'Xbox reinstalled.'
        'toolText.youCanTryAnAlternativeMethodOrManualRemoval' = 'You can try an alternative method or manual removal.'
        'uiText.01AttemptFailed2ILlTryAgain' = 'Attempt {0}/{1} failed: {2}. Try again...'
        'uiText.01Seconds' = '{0} - {1} seconds'
        'uiText.0CompletedWithErrors1' = 'Complete {0} with errors: {1}.'
        'uiText.0Discontinued' = '{0} discontinued.'
        'uiText.0Failed1' = 'Fail {0}: {1}.'
        'uiText.0In1' = '{0} in {1}'
        'uiText.0In12' = '{0} in {1}: {2}'
        'uiText.0In1Seconds' = '{0} in {1} seconds'
        'uiText.0IsEmptyUsingFallbackStaticMenu' = '\{0} is empty, using fallback static menu.'
        'uiText.0NotFoundAfterLoading' = '\{0} not found after loading.'
        'uiText.0OfficeProcessesClosed' = '{0} Office processes closed.'
        'uiText.addingStoreViaDism' = 'Adding Store via DISM'
        'uiText.advancedInstallationViaMicrosoftWingetClientModule' = 'Advanced installation via Microsoft.WinGet.Client module.'
        'uiText.andSaveItIn0' = 'and save it in: {0}.'
        'uiText.appxInstallFailed01' = 'Fail AppX install ({0}): {1}'
        'uiText.appxManifestStoreRegistration' = 'AppX Manifest Store Registration'
        'uiText.archiveCopyFailed' = 'Archive copy failed.'
        'uiText.asset0NotFound' = 'Asset ''{0}'' not found.'
        'uiText.assetUrlRetrievalError0' = 'Asset URL retrieval error: {0}.'
        'uiText.attemptingNativeAppxInstallFromBundle' = 'I try native Appx installation from downloaded bundle.'
        'uiText.attemptingPackageManagerRepair' = 'Attempting Repair-WinGetPackageManager.'
        'uiText.attemptingToInstallPowershell7ViaWinget' = 'Attempt to install PowerShell 7 via Winget.'
        'uiText.attemptingToInstallWindowsTerminalViaWinget' = 'Attempting to install Windows Terminal via winget.'
        'uiText.attemptingWingetRepairViaPackageManager' = 'Attempting to repair Winget (Repair-WinGetPackageManager).'
        'uiText.attentionGitHasNotBeenInstalledOrItMayNotWorkProperly' = 'Attention: Git has not been installed or it may not work properly.'
        'uiText.automaticStartToolkitLogInjectionPolicy0' = 'Policy: Automatically injecting Start-ToolkitLog for {0}.'
        'uiText.battleNetInstalled' = 'Battle.net installed.'
        'uiText.browserOpenForReportingOnGithub' = 'Browser open for reporting on GitHub.'
        'uiText.buildCompletedWithMinorAnomaliesOrSkippedModules' = 'The build completed with minor anomalies or skipped modules.'
        'uiText.bypassedUserConfirmationFor0DefaultResponseYes' = 'Bypass user confirmation for: ''{0}''. Default response ''Yes''.'
        'uiText.cached0' = 'Cached: {0}.'
        'uiText.cannotGetParametersForFunction01' = 'Cannot get parameters for function ''{0}'': {1}.'
        'uiText.carryingOutBasicChecks' = 'Carrying out basic checks.'
        'uiText.check0' = 'Check {0}.'
        'uiText.checkboxReadingError0' = 'Checkbox reading error: {0}.'
        'uiText.checkForJetbrainsmonoNerdFont' = 'Check for JetBrainsMono Nerd Font.'
        'uiText.checkingMicrosoftAppInstallerPackage' = 'Checking the Microsoft.AppInstaller package.'
        'uiText.checkingPowershell7' = 'Check PowerShell 7.'
        'uiText.checkWingetFunctionality' = 'Check Winget functionality.'
        'uiText.chromePolicySet01' = 'Set Chrome policy: {0} = {1}'
        'uiText.classicAndModernEventLogsDeleted' = 'Classic and modern Event Logs deleted.'
        'uiText.cleanedValuesIn0' = 'Clean value in {0}'
        'uiText.cleanWininetWebcache' = 'Clean WinInet/WebCache.'
        'uiText.clearingWingetCache' = 'Clearing Winget cache.'
        'uiText.closingInterferingProcesses' = 'Closing interfering processes.'
        'uiText.closingOfficeProcesses' = 'Closing Office processes.'
        'uiText.command0ExitCode1Duration2' = 'Command {0} (ExitCode: {1}, Duration: {2})'
        'uiText.commandContext' = 'Command context'
        'uiText.commandOutput0' = 'Command output ({0})'
        'uiText.compatibleSystemRecentWin1110' = 'Compatible system (recent Win11/10).'
        'uiText.compatibleSystemWin10' = 'Compatible system (Win10).'
        'uiText.completed' = 'Completed'
        'uiText.completed0' = 'Complete: {0}.'
        'uiText.completeOfficeRepairOnline' = 'Complete Office Repair (Online)'
        'uiText.compressArchiveNotAvailableGuiReportSavedIn0' = 'Compress-Archive not available. Save GUI report in: {0}.'
        'uiText.configurationComplete' = 'Configuration complete.'
        'uiText.consoleMinimized' = 'Console minimized.'
        'uiText.continuingBuildWithoutMinification' = 'Continuing build without minification.'
        'uiText.coreForJob0' = 'Core for job: {0}.'
        'uiText.coreScriptDownloadedSuccessfully' = 'Core Script downloaded successfully.'
        'uiText.coreScriptNotFoundAt0WithinJob' = 'Core script not found at {0} within job.'
        'uiText.coreVersion0' = 'Core Version: {0}.'
        'uiText.coreVersionDownloaded0' = 'Download core version: {0}.'
        'uiText.coreVersionFromFallbackCache0' = 'Core version from fallback cache: {0}.'
        'uiText.couldNotCheckBitlockerStatus0' = 'Could not check Bitlocker status: {0}.'
        'uiText.couldNotConfigureExecutebutton' = 'Could not configure ExecuteButton.'
        'uiText.couldNotGetLocalPathForEmoji0Skipping' = 'Could not get local path for emoji ''{0}''. Skip.'
        'uiText.couldNotLoadCategorysystemIcon' = 'Could not load CategorySystem icon.'
        'uiText.couldNotLoadExecutebuttonIcon' = 'Could not load ExecuteButton icon.'
        'uiText.couldNotLoadOutputlogIcon' = 'Could not load OutputLog icon.'
        'uiText.couldNotLoadSomeIcons0' = 'Could not load some icons: {0}.'
        'uiText.couldNotLoadTooliconimage0' = 'Could not load ToolIconImage: {0}.'
        'uiText.couldNotMinimizeConsoleNonCritical' = 'Could not minimize console (non-critical).'
        'uiText.countdownBypassed01Seconds' = 'Bypass countdown: ''{0}'' ({1} seconds).'
        'uiText.crashAccessViolationExitcode0RipristinoDatabase' = 'Crash ACCESS_VIOLATION (ExitCode: {0}). Restore database.'
        'uiText.crashDetectedExitcode0AccessViolationAdvancedRecoveryAttempt' = 'Detect crash (ExitCode: {0} = ACCESS_VIOLATION). Attempt advanced recovery.'
        'uiText.creatingWpfWindow' = 'Creating WPF window.'
        'uiText.criticalError0' = 'Critical error: {0}.'
        'uiText.criticalErrorDuringSetup0' = 'Critical error during setup: {0}.'
        'uiText.criticalErrorInReset0' = 'Critical error in reset: {0}'
        'uiText.criticalErrorWhileLoadingCore0' = 'CRITICAL ERROR while loading Core: {0}.'
        'uiText.deepOptimizationOfMicrosoftOffice' = 'Deep optimization of Microsoft Office.'
        'uiText.deepTestExecutionOfWingetSearchForPacketsOnTheNetwork' = 'Deep test execution of Winget (search for packets on the network).'
        'uiText.deepTestFailedExitcode0Details1' = 'Fail deep test: ExitCode={0}. Details: {1}.'
        'uiText.deepTestPassedWingetCommunicatesCorrectlyWithRepositories' = 'Deep test passed: Winget communicates correctly with repositories.'
        'uiText.deepValidationError0' = 'Deep validation error: {0}.'
        'uiText.deepValidationFailedExitcode0Details1' = 'Fail deep validation (ExitCode={0}). Details: {1}'
        'uiText.deepValidationPassedWingetCommunicatesWithRepositories' = 'Deep validation passed: Winget communicates with repositories.'
        'uiText.defaultTerminalNotSupportedOnThisBuild' = 'This Windows build does not support setting the default terminal: step skipped.'
        'uiText.defenderActiveDisablePrompt0' = 'Windows Defender is active. It is recommended to disable real-time protection temporarily. Press ENTER once you have disabled it, or press it again to continue anyway ({0}/{1}).'
        'uiText.defenderActiveNonInteractive0' = 'Windows Defender is active. Real-time protection may cause some installations to fail.'
        'uiText.defenderDisabledContinuing0' = 'Windows Defender is disabled: continuing with the installation.'
        'uiText.defenderPressEnterAfterDisabling0' = 'Press ENTER after disabling Windows Defender, or press it again to continue anyway.'
        'uiText.defenderStillActiveContinuing0' = 'Windows Defender is still active: continuing anyway. Some installations may fail.'
        'uiText.dependencyFound0' = 'Find dependency: {0}.'
        'uiText.desktopShortcutCreation' = 'Desktop shortcut creation.'
        'uiText.detected0StableDriverMatchesFromDriveroverridesJson' = 'Detect {0} stable driver matches from DriverOverrides.json.'
        'uiText.disablingBitlocker' = 'Disabling BitLocker'
        'uiText.dismExportFailedWithExitcode0' = 'Fail DISM export (ExitCode: {0}).'
        'uiText.dosvcNotRestoredKnownLimitation' = 'Windows Update service dosvc (Delivery Optimization) could not be restored: known Windows limitation. Setup continues.'
        'uiText.download0' = 'Download {0}...'
        'uiText.download02' = 'Download {0}'
        'uiText.downloadAndInstallWingetBundle' = 'Download and install Winget Bundle (with dependencies).'
        'uiText.downloadCompleted0' = 'Complete download: {0}.'
        'uiText.downloadCoreScriptFromGitHub' = 'Download Core Script from GitHub.'
        'uiText.downloaded0' = 'Download: {0}.'
        'uiText.downloadError0' = 'Download Error: {0}'
        'uiText.downloadFailed0' = 'Fail download: {0}.'
        'uiText.downloadFailedAfter0Attempts1' = 'Fail download after {0} attempts: {1}.'
        'uiText.downloadIcon' = 'Download icon.'
        'uiText.downloadingIconFor0From1' = 'Download icon for ''{0}'' from {1}.'
        'uiText.downloadMsixBundleFromMicrosoft' = 'Download MSIXBundle from Microsoft.'
        'uiText.downloadWingetDependencies' = 'Download Winget dependencies from the official repository.'
        'uiText.doYouReallyThinkThisScriptCanDoAnythingForThisVersion' = 'Do you really think this script can do anything for this version?'
        'uiText.doYouWantToTakeARiskYN' = 'Do you want to take a risk? [Y/N]'
        'uiText.driveroverridesJsonDownloadFailedUseLocalCacheIfAvailable' = 'DriverOverrides.json download failed, use local cache if available.'
        'uiText.driveroverridesJsonNotFoundIn0' = 'DriverOverrides.json not found in {0}'
        'uiText.duration0' = 'Duration: {0}'
        'uiText.dynamicMenuGenerated0Categories' = 'Generate dynamic menu: {0} categories.'
        'uiText.elevationSwitchedAccount0' = 'Elevation switched account: setup started by {0} is running as {1}. Profile, theme and desktop shortcut are installed for {0}.'
        'uiText.emptyInputTryAgain' = 'Empty input. Try again.'
        'uiText.emptyPrecompiledModule0InsertingDevelopmentStub' = 'Empty precompiled module: ''{0}''. Insert development stub.'
        'uiText.ensuringAllRequiredIconsAreAvailableLocally' = 'Ensuring all required icons are available locally.'
        'uiText.environmentReadyForInstallation' = 'Environment ready for installation.'
        'uiText.error' = '[ERROR]'
        'uiText.errorAdministratorPrivilegesRequired' = '[ERROR] Administrator privileges required.'
        'uiText.errorDuring01' = 'Error during {0}: {1}'
        'uiText.errorDuringDatabaseRestore0' = 'Error during database restore: {0}.'
        'uiText.errorDuringDotSourcingCore0' = 'Error during dot-sourcing Core: {0}.'
        'uiText.errorDuringIconSynchronization0' = 'Error during icon synchronization: {0}.'
        'uiText.errorDuringInitializationLoaded0' = 'Error during initialization Loaded: {0}.'
        'uiText.errorDuringWingetDeepTest0' = 'Error during Winget deep test: {0}.'
        'uiText.errorDuringWingetTest0' = 'Error during Winget test: {0}.'
        'uiText.errorExecutingFunction0WithinJob1' = 'Error executing function ''{0}'' within job: {1}.'
        'uiText.errorFailedToCreateIconDirectory0' = '[ERROR] Failed to create icon directory: {0}.'
        'uiText.errorFailedToInitializeLogging0' = '[ERROR] Failed to initialize logging. {0}.'
        'uiText.errorFailedToLoad01' = '[ERROR] Failed to load: {0} - {1}.'
        'uiText.errorGeneratingDynamicMenu0' = 'Error generating dynamic menu: {0}.'
        'uiText.errorInstallingFont0' = 'Error installing font: {0}.'
        'uiText.errorInterruptingJob0' = 'Error interrupting job: {0}.'
        'uiText.errorPreparingGuiLogs0' = 'Error preparing GUI logs: {0}.'
        'uiText.errorReadingLocalCacheVersion0' = 'Error reading local cache version: {0}.'
        'uiText.errorRestoringDatabase0' = 'Error restoring database: {0}.'
        'uiText.errorRestoringWinget0' = 'Error restoring Winget: {0}.'
        'uiText.errors0' = 'Error : {0}'
        'uiText.errorSendingLog0' = 'Error sending log: {0}.'
        'uiText.errorStartingJob01' = 'Error starting job ''{0}'': {1}.'
        'uiText.errorUpdatingSystemInformation0' = 'Error updating system information: {0}.'
        'uiText.exceptionInStartDeepdiskrepair' = 'Exception in Start-DeepDiskRepair'
        'uiText.exceptionWhileRunningExternalCommand' = 'Exception while running external command'
        'uiText.executebuttonConfiguredWithPillShapedStyleAndPlayIcon' = 'ExecuteButton configured with pill-shaped style and Play icon.'
        'uiText.executing0Seconds' = 'Executing... ({0} seconds)'
        'uiText.execution0Sec' = 'Execution : {0} sec'
        'uiText.existingProfileSaved0' = 'Existing profile saved in {0}.'
        'uiText.failedToCreateWindow0' = 'Failed to create window: {0}.'
        'uiText.failedToDotSourceCoreScriptWithinJob0' = 'Failed to dot-source Core script within job: {0}.'
        'uiText.failedToDownloadIcon01' = 'Failed to download icon ''{0}'': {1}.'
        'uiText.failedToGetRemoteVersion0AForcedDownloadOrFallbackMayBeRequired' = 'Failed to get remote version: {0}. A forced download or fallback may be required.'
        'uiText.failedToInstallWingetClientModule0' = 'Failed to install WinGet Client module: {0}.'
        'uiText.failedToLoadOrDownloadWindowIcon0' = 'Failed to load or download window icon: {0}.'
        'uiText.failedToRestart01' = 'Failed to restart ''{0}'': {1}.'
        'uiText.failedToRetrieveSystemInformationFromCore' = 'Failed to retrieve system information from Core.'
        'uiText.failedToSetDefaultTerminal0' = 'Failed to set default terminal: {0}.'
        'uiText.fallbackAperturaMicrosoftStorePerWindowsTerminal' = 'Fallback: Opening Microsoft Store for Windows Terminal.'
        'uiText.fallbackDownloadGitFromGitHub' = 'Fallback: Download Git from GitHub...'
        'uiText.fallbackDownloadMsixBundleDirect' = 'Fallback: Download MSIXBundle direct from Microsoft.'
        'uiText.fatalErrorCoreScriptLoadingFailed' = 'FATAL ERROR: Core Script loading failed.'
        'uiText.fileIgnored01' = 'Ignore file: {0} - {1}'
        'uiText.finalFile0Kb1Lines' = 'Final file : {0} KB ({1} line)'
        'uiText.finalTestAfterReinstallation' = 'Final test after reinstallation.'
        'uiText.fontInstallationViaWingetQuickMethod' = 'Font installation via WinGet (Quick Method).'
        'uiText.forcedReinstallAppInstaller0' = 'Reinstalling the Microsoft.DesktopAppInstaller package (forced).'
        'uiText.function0NotFoundAfterDotSourcingWithinJob' = 'Function ''{0}'' not found after dot-sourcing within job.'
        'uiText.functionDevelopmentInProgress' = 'Function development in progress.'
        'uiText.functionsAvailableTuiMenuSuppressed' = 'Functions available, TUI menu suppressed'
        'uiText.generatingDynamicMenuFromCore0' = 'Generate dynamic menu from Core {0}.'
        'uiText.getSysteminfoFunctionAvailable' = 'Get-SystemInfo function available.'
        'uiText.getSysteminfoFunctionNotFound' = 'Get-SystemInfo function NOT found!'
        'uiText.gitAlreadyInstalled' = 'Git already installed.'
        'uiText.gitInstallation' = 'Git installation...'
        'uiText.gitInstallationError0' = 'Git installation error: {0}'
        'uiText.gitInstalledSuccessfully' = 'Git installed successfully.'
        'uiText.gitInstalledViaWinget' = 'Git installed via winget.'
        'uiText.gitIsAlreadyOperational' = 'Git is already operational.'
        'uiText.gpuAnalysisErrorReadingWin32Videocontroller0' = 'GPU Analysis: Error reading Win32_VideoController: {0}'
        'uiText.guiVersion0' = 'GUI version: {0}'
        'uiText.guiWindowClosedAttemptToStopTheJobInProgress' = 'GUI window closed. Attempt to stop the job in progress.'
        'uiText.hostsFileModifiedBackupSaved0' = 'Hosts file modified; backup saved in {0}.'
        'uiText.hostsFileResetOnlyOnSourceFailure0' = 'The WinGet or Store sources are not reachable: removing the hosts overrides that block them. The privacy entries you added yourself are kept.'
        'uiText.httpError01' = 'HTTP Error {0}: {1}'
        'uiText.iconAvailabilityCheckCompleted' = 'Icon availability check completed.'
        'uiText.iInteractiveInputBypassedFor0DefaultChoiceY' = 'Bypass interactive input for: ''{0}''. Default choice ''Y''.'
        'uiText.importantWarning' = 'IMPORTANT WARNING'
        'uiText.individualRestartSuppressedAFinalRebootWillBeHandled' = 'Individual restart suppressed. A final reboot will be handled.'
        'uiText.info' = '[INFO]'
        'uiText.infoAdministratorPrivilegesConfirmed' = '[INFO] Administrator privileges confirmed.'
        'uiText.infoLoggingInitializedTo0' = '[INFO] Initialize logging to {0}.'
        'uiText.initializationCompleteGuiReadyToUse' = 'INITIALIZATION COMPLETE - GUI ready to use.'
        'uiText.installationFailedCode0' = 'Install failed. Code: {0}'
        'uiText.installationFailedCode02' = 'Install failed. Code: {0}.'
        'uiText.installingMicrosoftWingetClientModule' = 'Installing Microsoft.WinGet.Client module.'
        'uiText.installingPowershell7InProgress' = 'Install PowerShell 7 in progress.'
        'uiText.installingVisualCRedistributable' = 'Installing Visual C++ Redistributable...'
        'uiText.installingWingetMsixbundleWithDependencies' = 'Installing Winget MSIXBundle (with dependencies)...'
        'uiText.interactiveInputDetected0NotSupportedInGuiMode' = 'Detect interactive input: {0} - Not supported in GUI mode.'
        'uiText.interferingProcessesClosed' = 'Interfering processes closed.'
        'uiText.invalidChoiceEnterNumbersBetween0' = 'Invalid choice. Enter numbers between {0}.'
        'uiText.invalidDriveroverridesJson0' = 'Invalid DriverOverrides.json: {0}'
        'uiText.irreversibleFailureWritingFinalFile0' = 'Irreversible failure while writing final file to disk: {0}.'
        'uiText.jetbrainsmonoNerdFontAlreadyInstalled' = 'JetBrainsMono Nerd Font already installed.'
        'uiText.jobInProgressStoppedAndRemoved' = 'Job in progress stopped and removed.'
        'uiText.lifeProtectionActivated0' = 'Activate life protection: {0}'
        'uiText.loadedDependencies' = 'Loaded dependencies.'
        'uiText.loadingCoreFunctionsIntoMemoryGlobalScope' = 'Loading Core functions into memory (Global Scope).'
        'uiText.loadingCoreScript' = 'Loading Core Script.'
        'uiText.loadingForms' = 'Loading forms'
        'uiText.localCacheExpiredAge0MinutesDownloadToUpdate' = 'Local cache expired (age: {0} minutes). Download to update.'
        'uiText.localCoreVersionFound0Numeric1' = 'Find local Core version: {0} (Numeric: {1}).'
        'uiText.manifestReRegistrationAppxmanifestXmlPreventsLeaks' = 'Manifest re-registration: AppxManifest.xml prevents leaks.'
        'uiText.menuStructureLoadedCategories0' = 'Load menu structure (categories: {0}).'
        'uiText.microsoftAppInstallerInstallationFailed' = 'Unable to install Microsoft.AppInstaller.'
        'uiText.microsoftAppInstallerNotFoundInstalling' = 'Microsoft.AppInstaller not found. Installing it now.'
        'uiText.microsoftAppInstallerPresentForcingUpdate' = 'Microsoft.AppInstaller already present. Forcing update to the latest release.'
        'uiText.microsoftAppInstallerUpdated' = 'Microsoft.AppInstaller is present and up to date.'
        'uiText.microsoftAppInstallerUpdateError0' = 'Microsoft.AppInstaller update error: {0}.'
        'uiText.moduleStatistics' = 'MODULE STATISTICS'
        'uiText.moduloWingetClient0' = 'WinGet Client module: {0}.'
        'uiText.monitoringTimerRestarted' = 'Monitoring timer restarted.'
        'uiText.nerdFontsInstalledSuccessfully' = 'Nerd Fonts installed successfully.'
        'uiText.newCoreVersion0AvailableCurrent1DownloadInProgress' = 'New Core version ({0}) available (current: {1}). Download in progress.'
        'uiText.noEndpointFoundInTemplateSkipping0' = 'No endpoint found in template. Skip: {0}.'
        'uiText.noGuiOrCoreLogFilesFoundForReporting' = 'No GUI or Core log files found for reporting.'
        'uiText.noKnownStableDriversFoundForTheDetectedGpus' = 'No known stable drivers found for the detected GPUs.'
        'uiText.noLocalCacheFoundForcedDownload' = 'No local cache found. Forced download.'
        'uiText.noPendingUpdatesDetected' = 'No pending updates detected'
        'uiText.noPs1ModulesFound0OperationCanceled' = 'No .ps1 modules found in {0}. Operation canceled.'
        'uiText.noteFontsViaWingetRequireRestartingTerminalOrExplorerToBeVisible' = 'Note: fonts via WinGet require restarting Terminal (or Explorer) to be visible.'
        'uiText.nugetProviderNotInstallable' = 'NuGet provider not installable.'
        'uiText.officeOptimizedTelemetryPrivacyAndScheduledTasksRemoved' = 'Office optimized: telemetry, privacy and scheduled tasks removed.'
        'uiText.ohMyPoshThemeDownloaded' = 'Oh My Posh theme downloaded.'
        'uiText.ohMyPoshThemeDownloadFailed0' = 'The Oh My Posh theme could not be downloaded or validated at {0}.'
        'uiText.operationalWingetVersion0' = 'Operational Winget (version: {0}).'
        'uiText.operationalWingetVersion02' = 'Operational Winget (version: {0}).'
        'uiText.operationCompleted' = 'Operation completed!'
        'uiText.pathAndWingetPermissionsUpdated' = 'PATH and winget permissions updated.'
        'uiText.pendingRebootDetectedForWindowsUpdates' = 'Pending reboot detected for Windows updates'
        'uiText.pendingSystemUpdatesHaveBeenDetected' = 'Pending system updates have been detected:'
        'uiText.persistentCrashAfterDatabaseRestore' = 'Persistent crash after database restore.'
        'uiText.persistentCrashStartingCompleteReinstallationOfWinget' = 'Persistent crash. Starting complete reinstallation of Winget.'
        'uiText.phase1CompletedOperationalWinget' = 'Complete phase 1. Operational Winget.'
        'uiText.phase1CoreRecoveryVcAppxDependenciesMsixbundle' = 'Phase 1: Core Recovery (VC++, AppX dependencies, MSIXBundle).'
        'uiText.phase1InsufficientStartingPhase2AdvancedRecovery' = 'Phase 1 insufficient. Start Phase 2: Advanced recovery.'
        'uiText.pleaseWaitOperationInProgress' = 'Please wait, operation in progress.'
        'uiText.powershell0' = 'PowerShell: {0}.'
        'uiText.powershell7AlreadyInstalled' = 'PowerShell 7 already installed.'
        'uiText.powershell7InstallatoViaWinget' = 'PowerShell 7 installed via Winget.'
        'uiText.powershell7InstalledSuccessfully' = 'PowerShell 7 installed successfully.'
        'uiText.powershell7ProfileConfigured' = 'PowerShell 7 profile configured.'
        'uiText.powershellInstallationError0' = 'PowerShell installation error: {0}.'
        'uiText.powershellJob0StartedId1' = 'PowerShell job ''{0}'' started (ID: {1}).'
        'uiText.preparation' = 'Preparation'
        'uiText.preparingGuiErrorLogForReporting' = 'Preparing GUI error log for reporting.'
        'uiText.preparingTheNextScript' = 'Preparing the next script.'
        'uiText.pressAnyKeyToCancel' = 'Press any key to cancel...'
        'uiText.pressEnterToExit' = 'Press Enter to exit'
        'uiText.previousInterruptionDetectedRestoringUpdateServices' = 'Previous interruption detected: restoring Windows Update services state.'
        'uiText.proceedWithCaution' = 'PROCEED WITH CAUTION'
        'uiText.processed0' = 'Process : {0}'
        'uiText.profileConfigurationError0' = 'Profile configuration error: {0}.'
        'uiText.profileDirectoryUnavailable0' = 'Unable to prepare the PowerShell profile directory: {0}'
        'uiText.profileNotInstalled0' = 'The PowerShell profile was not installed at {0}.'
        'uiText.quickOfficeRepairOffline' = 'Quick Office Repair (Offline)'
        'uiText.quickRecoveryFailedAttemptAdvancedSlowerMethod' = 'Quick recovery failed. Attempt advanced (slower) method.'
        'uiText.quickRecoveryFailedAttemptForcedPackageReinstall' = 'WinGet is still not working: attempting a forced reinstall of Microsoft.DesktopAppInstaller and Microsoft.WinGet.Client.'
        'uiText.ram0Gb' = 'RAM: {0} GB'
        'uiText.rebootYourSystemAndThenRestartWintoolkitBeforeContinuing' = 'reboot your system and then restart WinToolkit before continuing.'
        'uiText.reduction01LinesRemoved' = 'Reduce : {0} % ({1} line removed)'
        'uiText.reductionOffFlagMinifyNotDetected' = 'Reduction : OFF (Flag -Minify not detected)'
        'uiText.reinstallation0' = 'Reinstall {0}'
        'uiText.remoteCoreScriptVersionRecovery' = 'Remote Core Script version recovery.'
        'uiText.remoteCoreVersionDetected0Numeric1' = 'Detect remote Core version: {0} (Numeric: {1}).'
        'uiText.repairModuleFailed0' = 'Fail repair module: {0}.'
        'uiText.repairOperationTimedOut' = 'Timeout: The operation exceeded the time limit and was terminated.'
        'uiText.repairWingetpackagemanagerCompletato' = 'Repair-WinGetPackageManager completed.'
        'uiText.repairWingetpackagemanagerCompletedHigherVersionAlreadyPresent' = 'Repair-WinGetPackageManager completed (higher version already present).'
        'uiText.repairWingetpackagemanagerEseguito' = 'Repair-WinGetPackageManager executed.'
        'uiText.repairWingetpackagemanagerFallito0' = 'Fail Repair-WinGetPackageManager: {0}.'
        'uiText.repairWingetpackagemanagerIgnoredHigherVersionAlreadyPresent' = 'Repair-WinGetPackageManager ignored (higher version already present).'
        'uiText.repeatTestAfterDatabaseRestore' = 'Repeat test after database restore.'
        'uiText.reportCoreVersion0' = 'Core version: {0}'
        'uiText.reportDate0' = 'Date: {0}'
        'uiText.reRegisterManifestAppxmanifestXml' = 'Re-register manifest: AppxManifest.xml.'
        'uiText.resetAppInstaller' = 'Reset App Installer.'
        'uiText.resetClientUpdate' = 'Reset Client Update'
        'uiText.resetPackageMicrosoftDesktopappinstaller' = 'Reset package Microsoft.DesktopAppInstaller.'
        'uiText.resetStatusFile0' = 'Reset status file: {0}.'
        'uiText.resettingMicrosoftStoreCache' = 'Reset cache Microsoft Store (wsreset)'
        'uiText.resettingWindowsUpdateServices' = 'Resetting Windows Update Services.'
        'uiText.resetWingetSources' = 'Reset Winget sources.'
        'uiText.resourceInitializationCoreScriptLoading' = 'RESOURCE INITIALIZATION - Core Script loading.'
        'uiText.restoreCompletedButWingetMayNotWork' = 'Restore completed but winget may not work.'
        'uiText.retrieveUrlLatestReleaseOfWindowsTerminal' = 'Retrieve URL latest release of Windows Terminal.'
        'uiText.retrievingLatestPowershellRelease' = 'Retrieving latest PowerShell release.'
        'uiText.ripristinoDatabaseWinget' = 'Restoring Winget database.'
        'uiText.runningCommand01Timeout2S' = 'Run command: {0} {1} (Timeout: {2}s)'
        'uiText.runningGitInstaller' = 'Running Git installer...'
        'uiText.runningPackageManagerRepair' = 'Running Repair-WinGetPackageManager.'
        'uiText.schannelCipherReenabled0' = 'SCHANNEL cipher {0} re-enabled.'
        'uiText.schannelTls12ModeReactivated0' = 'SCHANNEL TLS 1.2 {0} re-activated.'
        'uiText.selectedScript0' = 'Select script: {0}.'
        'uiText.sendSupportArchive0' = 'Send the archive on your desktop ({0}) to GitHub, describing the issues you encountered to help improve the tool.'
        'uiText.serviceRestarted0' = 'Restart service: {0}.'
        'uiText.serviceStop0' = 'Stop service: {0}...'
        'uiText.settingWindowsTerminalAsDefaultViaRegistry' = 'Setting Windows Terminal as default via Registry.'
        'uiText.shortcutCreatedSuccessfully' = 'Shortcut created successfully.'
        'uiText.shortcutCreationError0' = 'Shortcut creation error: {0}.'
        'uiText.skipped0' = 'Skip : {0}'
        'uiText.sources0Kb1Lines' = 'Source : {0} KB ({1} line)'
        'uiText.standardWindowsTerminalInstallationFailed0FallbackToTheMicrosoftStore' = 'Fail standard Windows Terminal installation: {0}. Fallback to Microsoft Store.'
        'uiText.startExecution0' = 'Start execution: {0}.'
        'uiText.startingDownloadProcess' = 'Starting download...'
        'uiText.startingPowershellEnvironmentSetupPsp' = 'Starting PowerShell Environment Setup (PSP).'
        'uiText.startingService0' = 'Start service: {0}...'
        'uiText.startingWingetAdvancedRepair' = 'Starting Winget advanced repair...'
        'uiText.startingWingetCoreRecoveryProcedure' = 'Starting Winget (Core) recovery procedure.'
        'uiText.startingWingetInstallVerification' = 'Start Winget installation/verification procedure.'
        'uiText.startingWinToolkitSetup' = 'Starting Win Toolkit configuration.'
        'uiText.startWingetDatabaseRecovery' = 'Start Winget database recovery.'
        'uiText.storageAndCompression' = 'STORAGE AND COMPRESSION'
        'uiText.success' = '[SUCCESS]'
        'uiText.successLoaded0' = '[SUCCESS] Load: {0}.'
        'uiText.supportLogPackageCreated0' = 'Create support log package: {0}.'
        'uiText.system01' = 'System: {0} ({1})'
        'uiText.systemClockResynced' = 'System clock resynchronized.'
        'uiText.systemInfoNotAvailable' = 'System info not available.'
        'uiText.systemInformationPanelUpdated3BlockLayout' = 'Update system information panel (3-block layout).'
        'uiText.systemNotSupportedByWingetWindows101709Required' = 'System not supported by Winget (Windows 10 1709+ required).'
        'uiText.systemRebootCancelled' = 'System reboot cancelled.'
        'uiText.systemRestartRequiredToCompleteUpdates' = 'System restart required to complete updates'
        'uiText.takingOwnershipFor0' = 'Take ownership for {0}.'
        'uiText.templateFileNotFoundIn0' = 'Template file not found in: {0}'
        'uiText.temporarilySuspendWindowsUpdateServicesToAvoidConflicts' = 'Temporarily suspend Windows Update services to avoid conflicts.'
        'uiText.terminalSettingsUpdateError0' = 'Terminal settings update error: {0}.'
        'uiText.theGuiCannotContinueWithoutTheCoreScript' = 'The GUI cannot continue without the Core Script.'
        'uiText.thisMayCauseMalfunctionsErrorsOrBehavior' = 'This may cause malfunctions, errors or behavior'
        'uiText.timediffMeasure' = 'TIMEDIFF MEASURE'
        'uiText.timeoutAfter0Seconds' = 'Timeout after {0} seconds.'
        'uiText.timeoutReachedAfter0SecondsProcessTermination' = 'Reach timeout after {0} seconds, terminate process...'
        'uiText.tipManuallyDownloadWintoolkitPs1From' = 'Tip: Manually download WinToolkit.ps1 from:'
        'uiText.toolsFolderNotFoundIn0' = 'Tools folder not found in: {0}'
        'uiText.total0CheckboxesFound' = 'Find {0} checkboxes.'
        'uiText.trashEmptied' = 'Trash emptied'
        'uiText.unableToCheckWindowsUpdateStatus0' = 'Unable to check Windows update status: {0}'
        'uiText.unableToClose0' = 'Unable to close: {0}.'
        'uiText.unableToDownloadCoreScriptAndNoCacheAvailableConfiguredForFallback' = 'Unable to download Core Script and no cache available/configured for fallback.'
        'uiText.unableToExtractNumericPartFromLocale0IAssume000ForComparison' = 'Unable to extract numeric part from locale ''{0}''. I assume 0.0.0 for comparison.'
        'uiText.unableToExtractNumericPartFromRemoteVersion0IAssume000ForComparison' = 'Unable to extract numeric part from remote version ''{0}''. I assume 0.0.0 for comparison.'
        'uiText.unableToExtractOrInstallDependenciesFromTheOfficialZipError0' = 'Unable to extract or install dependencies from the official zip. Error: {0}.'
        'uiText.unableToExtractRemoteVersionFromCoreScriptIAssume000ForComparison' = 'Unable to extract remote version from Core Script. I assume 0.0.0 for comparison.'
        'uiText.unableToExtractVersionFromLocalCacheIAssume000ForComparison' = 'Unable to extract version from local cache. I assume 0.0.0 for comparison.'
        'uiText.unableToExtractVersionFromNewlyDownloadedCore' = 'Unable to extract version from newly downloaded Core.'
        'uiText.unableToInstallWindowsTerminalViaAnyAutomaticMethod' = 'Unable to install Windows Terminal via any automatic method.'
        'uiText.unableToInstallWinget' = 'Unable to install Winget.'
        'uiText.unableToOpenBrowser0' = 'Unable to open browser: {0}.'
        'uiText.unableToSetPermissionsOn01' = 'Unable to set permissions on ''{0}'': {1}.'
        'uiText.unableToStartExternalProcess' = 'Unable to start external process.'
        'uiText.unexpectedBehaviorInSomeOrAllWintoolkitFeatures' = 'unexpected behavior in some or all WinToolkit features.'
        'uiText.unhandledException01' = 'UNHANDLED EXCEPTION: {0} | {1}'
        'uiText.unknownErrorsOccurred' = 'Unknown errors occurred while running the script.'
        'uiText.updatedFolderPermissions0' = 'Update folder permissions: {0}.'
        'uiText.updatedPath0' = 'Update PATH: {0}.'
        'uiText.updateServicesRestored' = 'Update services restored.'
        'uiText.updateServicesRestoreIncomplete0' = 'Windows Update services restore incomplete: {0}'
        'uiText.updateServicesSuccessfullySuspended' = 'Update services successfully suspended.'
        'uiText.url0' = 'URL: {0}.'
        'uiText.userChoices0' = 'User Choices: {0}'
        'uiText.userConfirmationPrompt0Response1' = 'User Confirmation Prompt: {0} | Response: {1}'
        'uiText.userScopeAligned0' = 'The tools installed during setup were added to the PATH of {0} ({1}). Open a new terminal to use them.'
        'uiText.userScopeAlreadyAligned0' = 'The PATH of {0} already contains the installed tools.'
        'uiText.userScopeNotAligned0' = 'The tools were installed in the elevated account and could not be added to the PATH of {0} ({1}). Run start.ps1 again from your own session to install them for your user.'
        'uiText.usingLocalCacheExpiredOrOlderButAvailableAsAFallback' = 'Using local cache (expired or older, but available) as a fallback.'
        'uiText.validAndUpdatedLocalCacheV0CacheUsage' = 'Valid and updated local cache (v{0}). Cache usage.'
        'uiText.vcRedistInstalled' = 'VC++ Redist installed.'
        'uiText.ver0Build1' = '{0} (Build {1})'
        'uiText.verifyGitInstallation' = 'Verify Git installation...'
        'uiText.visualCRedistributableAlreadyPresent' = 'Visual C++ Redistributable already present.'
        'uiText.visualCRedistributableInstallation' = 'Visual C++ Redistributable installation.'
        'uiText.visualCRedistributableInstalled' = 'Visual C++ Redistributable installed.'
        'uiText.warn' = '[WARN]'
        'uiText.warningInstallingSubsequentPackagesViaWingetMayFail' = 'Warning: Installing subsequent packages via Winget may fail.'
        'uiText.weStronglyRecommendThatYouCompleteAllOngoingUpdates' = 'We strongly recommend that you complete all ongoing updates,'
        'uiText.windebloatToolkit' = 'WinDebloat Toolkit'
        'uiText.windowCreatedSuccessfully' = 'Window created successfully.'
        'uiText.windows10Build0NonSupportaWinget' = 'Windows 10 build {0} does not support Winget.'
        'uiText.windows81PartialCompatibility' = 'Windows 8.1: Partial compatibility.'
        'uiText.windowsTerminalAppxInstallationFailed' = 'Windows Terminal Appx installation failed.'
        'uiText.windowsTerminalAppxInstallationSuccessful' = 'Windows Terminal Appx installation successful.'
        'uiText.windowsTerminalAssetMsixbundleNotFound' = 'Windows Terminal asset .msixbundle not found.'
        'uiText.windowsTerminalConfiguration' = 'Windows Terminal Configuration.'
        'uiText.windowsTerminalInstallationInProgress' = 'Windows Terminal installation in progress.'
        'uiText.windowsTerminalInstalledViaWinget' = 'Windows Terminal installed via winget.'
        'uiText.windowsTerminalIsAlreadyInstalled' = 'Windows Terminal is already installed.'
        'uiText.windowsTerminalSetAsDefault' = 'Windows Terminal set as default.'
        'uiText.windowsTerminalSettingsOverwrittenBackup0' = 'Windows Terminal settings overwritten with the distributed version; backup: {0}.'
        'uiText.windowsTerminalSettingsUpdated0' = 'Update Windows Terminal settings ({0}).'
        'uiText.windowsUpdateCacheCleared' = 'Windows Update cache cleared.'
        'uiText.windowsUpdateInstallationServiceCurrentlyRunning' = 'Windows Update Installation Service currently running'
        'uiText.windowsUpdateInstallationServiceIsRunning' = 'Windows update installation service is running'
        'uiText.windowsUpdateStatusCheck' = 'Windows update status check...'
        'uiText.wingetAdvancedInstallationError0' = 'Winget advanced installation error: {0}.'
        'uiText.wingetAlreadyOperationalNoRepairsNecessary' = 'Winget already operational. No repairs necessary.'
        'uiText.wingetClientModuleInstalled' = 'WinGet Client module installed.'
        'uiText.wingetCommandError0' = 'Winget command error: {0}.'
        'uiText.wingetCoreInstallationFailed' = 'Winget Core installation failed.'
        'uiText.wingetCoreInstalled' = 'Winget Core installed.'
        'uiText.wingetCoreSuccessfullyInstalled' = 'Winget Core successfully installed.'
        'uiText.wingetDatabaseRestoredVersion0' = 'Restore Winget database (version: {0}).'
        'uiText.wingetDeepValidationConnectivityDatabaseIntegrity' = 'Winget deep validation (connectivity + database integrity).'
        'uiText.wingetDidNotRespondWithin0SecondsIContinueAnyway' = 'Winget did not respond within {0} seconds. I continue anyway.'
        'uiText.wingetDoesnTRespondFastRecoveryAttemptCore' = 'Winget doesn''t respond. Fast recovery attempt (Core).'
        'uiText.wingetInstallationFailedOrFailedExitcode0FallbackToDirectDownload' = 'Fail Winget installation or fail (ExitCode: {0}). Fallback to direct download.'
        'uiText.wingetInstallationForWindowsTerminalFailed' = 'Winget installation for Windows Terminal failed.'
        'uiText.wingetInstallationForWindowsTerminalFailed0' = 'Fail Winget installation for Windows Terminal: {0}.'
        'uiText.wingetInstalledAndWorking' = 'Winget installed and working.'
        'uiText.wingetInstalledDeepValidationWithAnomaliesPossibleNetworkOrDbProblems' = 'Winget installed. Deep validation with anomalies (possible network or DB problems).'
        'uiText.wingetIntegrityValidationInProgressTimeout0S' = 'Winget integrity validation in progress (timeout: {0} s)...'
        'uiText.wingetIsAlreadyOperational' = 'Winget is already operational.'
        'uiText.wingetMsixBundleInstallationFailed' = 'Winget MSIX Bundle installation failed.'
        'uiText.wingetMsixBundleInstallationSuccessful' = 'Winget MSIX Bundle installation successful.'
        'uiText.wingetNotFoundInPath' = 'Winget not found in PATH.'
        'uiText.wingetNotFoundInSystem' = 'Winget not found in system.'
        'uiText.wingetNotFunctionalAfterAllAttempts' = 'Winget not functional after all attempts.'
        'uiText.wingetNotSupportedOnWindows0' = 'Winget not supported on Windows {0}.'
        'uiText.wingetNotYetReadyAttempt012SRemainWait' = 'Winget not yet ready (attempt {0}/{1}, {2} s remain). Wait...'
        'uiText.wingetPresentButNotRespondingCorrectlyExitcode0' = 'Winget present but not responding correctly (ExitCode: {0}).'
        'uiText.wingetReadyAndDatabaseUnlockedAttempt01' = 'Winget ready and database unlocked (attempt {0}/{1}).'
        'uiText.wingetRestoredQuickly' = 'Winget restored quickly.'
        'uiText.wingetReturnedCode0TheFontMayRequireATerminalRestart' = 'WinGet returned code {0}. The font may require a terminal restart.'
        'uiText.wingetRpcFailureDetected' = 'WinGet failed with error 0x800706BA: the App Installer deployment server is unavailable, so packages cannot be installed.'
        'uiText.wingetRpcRecovered' = 'WinGet recovered after re-registering the App Installer package.'
        'uiText.wingetRpcRecoveryFailed' = 'WinGet is still unusable: the App Installer deployment server cannot be reached.'
        'uiText.wingetSuccessfullyRestoredAndTested' = 'Winget successfully restored and tested.'
        'uiText.wintoolkitConfirmationBypassTagMessage0' = '[WINTOOLKIT_CONFIRMATION_BYPASS_TAG] Message: {0}.'
        'uiText.wintoolkitCountdownBypassTagMessage0Seconds1' = '[WINTOOLKIT_COUNTDOWN_BYPASS_TAG] Message: {0} | Seconds: {1}.'
        'uiText.wintoolkitInputBypassTagPrompt0' = '[WINTOOLKIT_INPUT_BYPASS_TAG] Prompt: {0}'
        'uiText.wintoolkitIsReadyOnTheDesktop' = 'WinToolkit is Ready on the Desktop!'
        'uiText.wintoolkitLoadedInLibraryMode' = 'WinToolkit loaded in LIBRARY mode'
        'uiText.wintoolkitProgressTagActivity0Status1Percent100' = '[WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: {1} | Percent: 100%.'
        'uiText.wintoolkitProgressTagActivity0Status1Percent2' = '[WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: {1} | Percent: {2}%.'
        'uiText.wintoolkitProgressTagActivity0Status1Percent2Icon3Spinner4' = '[WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: {1} | Percent: {2}% | Icon: {3} | Spinner: {4}.'
        'uiText.wintoolkitProgressTagActivity0Status1SecondiPercent2' = '[WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: {1} seconds. | Percent: {2}%.'
        'uiText.wintoolkitProgressTagActivity0StatusCompletedPercent100' = '[WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: Completed | Percent: 100%.'
        'uiText.wintoolkitProgressTagActivity0StatusInEsecuzionePercent1' = '[WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: Running. | Percent: {1}%.'
        'uiText.wintoolkitProgressTagActivity0StatusRunning1SecondsPercent2' = '[WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: Running. ({1} seconds) | Percent: {2}%.'
        'uiText.wintoolkitRawHostOutputTag0' = '[WINTOOLKIT_RAW_HOST_OUTPUT_TAG]{0}'
        'uiText.wintoolkitSessionTerminatedByUser' = 'WinToolkit session terminated by user.'
        'uiText.wintoolkitStyledMessageTag01' = '[WINTOOLKIT_STYLED_MESSAGE_TAG] {0}: {1}'
        'uiText.wintoolkitStyledMessageTagErrorErroreDurante01' = '[WINTOOLKIT_STYLED_MESSAGE_TAG][Error] Error during {0}: {1}.'
        'uiText.wintoolkitStyledMessageTagInfoHeader0' = '[WINTOOLKIT_STYLED_MESSAGE_TAG] Info: HEADER: {0}.'
        'uiText.wintoolkitStyledMessageTagWarningTimeoutReachedAfter0SecondsTerminatingProcess' = '[WINTOOLKIT_STYLED_MESSAGE_TAG][Warning] Timeout reached after {0} seconds, terminating process.'
        'verb.active' = 'Active'
        'verb.backup' = 'Backup'
        'verb.block' = 'Block'
        'verb.cancel' = 'Cancel'
        'verb.check' = 'Check'
        'verb.clean' = 'Clean'
        'verb.complete' = 'Complete'
        'verb.compress' = 'Compress'
        'verb.configure' = 'Configure'
        'verb.copy' = 'Copy'
        'verb.create' = 'Create'
        'verb.delete' = 'Delete'
        'verb.detect' = 'Detect'
        'verb.disable' = 'Disable'
        'verb.download' = 'Download'
        'verb.enable' = 'Enable'
        'verb.export' = 'Export'
        'verb.extract' = 'Extract'
        'verb.fail' = 'Fail'
        'verb.found' = 'Found'
        'verb.inactive' = 'Inactive'
        'verb.inProgress' = 'In progress'
        'verb.install' = 'Install'
        'verb.move' = 'Move'
        'verb.note' = 'Note'
        'verb.notFound' = 'Not found'
        'verb.notPresent' = 'Not present'
        'verb.notRequired' = 'Not required'
        'verb.operational' = 'Operational'
        'verb.prepare' = 'Prepare'
        'verb.present' = 'Present'
        'verb.reenable' = 'Re-enable'
        'verb.reinstall' = 'Reinstall'
        'verb.remove' = 'Remove'
        'verb.repair' = 'Repair'
        'verb.required' = 'Required'
        'verb.reset' = 'Reset'
        'verb.restart' = 'Restart'
        'verb.restore' = 'Restore'
        'verb.run' = 'Run'
        'verb.search' = 'Search'
        'verb.skip' = 'Skip'
        'verb.start' = 'Start'
        'verb.stop' = 'Stop'
        'verb.tip' = 'Tip'
        'verb.uninstall' = 'Uninstall'
        'verb.update' = 'Update'
        'verb.wait' = 'Wait'
        'verb.warning' = 'Warning'
    }
    'it-IT' = @{
        'bitlocker.status.decrypting' = 'Decrittografia in corso'
        'bitlocker.status.encrypting' = 'Crittografia in corso'
        'bitlocker.status.notConfigured' = 'Non configurato'
        'bitlocker.status.off' = 'Disattivato'
        'bitlocker.status.on' = 'Attivato'
        'bitlocker.status.suspended' = 'Sospeso'
        'bitlocker.status.unknown' = 'Sconosciuto'
        'category.driverGaming' = 'Driver & Gaming'
        'category.office' = 'Office'
        'category.support' = 'Supporto'
        'category.windows' = 'Windows'
        'cleanerRule.adobeMediaBrowserKey' = 'Chiave del browser Adobe Media'
        'cleanerRule.cacheHistoryCleanup' = 'Pulizia della cache/cronologia'
        'cleanerRule.chromiumBrowsersCacheChromeEdgeBraveVivaldi' = 'Cache dei browser Chromium (Chrome, Edge, Brave, Vivaldi)'
        'cleanerRule.cleanmgrConfig' = 'Configurazione CleanMgr'
        'cleanerRule.cleanupExplorerThumbnailIconCache' = 'Pulizia: cache delle miniature/icone di Explorer'
        'cleanerRule.cleanupWindowsPrefetchCache' = 'Pulizia: cache di precaricamento di Windows'
        'cleanerRule.clearEventLogs' = 'Cancella registri eventi'
        'cleanerRule.clearWindowsUpdateCache' = 'Svuota la cache di Windows Update'
        'cleanerRule.cookiesCleanup' = 'Pulizia dei cookie'
        'cleanerRule.credentialManager' = 'Gestore credenziali'
        'cleanerRule.developerTelemetryTraces' = 'Telemetria e tracce per sviluppatori'
        'cleanerRule.dnsFlush' = 'Svuotamento DNS'
        'cleanerRule.edgeLegacyHtmlCache' = 'Cache Edge Legacy (HTML).'
        'cleanerRule.emptyRecycleBin' = 'Cestino vuoto'
        'cleanerRule.enhancedDiagtrackManagement' = 'Gestione DiagTrack migliorata'
        'cleanerRule.errorReports' = 'Rapporti di errore'
        'cleanerRule.firefoxBrowserCache' = 'Cache del browser Firefox'
        'cleanerRule.flashPlayerTraces' = 'Tracce di Flash Player'
        'cleanerRule.formDataCleanup' = 'Pulizia dei dati del modulo'
        'cleanerRule.googleChromeAiOptguideModel' = 'Modello OptGuide AI di Google Chrome'
        'cleanerRule.internetCookiesCleanup' = 'Pulizia dei cookie di Internet'
        'cleanerRule.listaryIndex' = 'Indice Listario'
        'cleanerRule.minimizeDism' = 'Riduci al minimo DISM'
        'cleanerRule.operaJavaCache' = 'Cache di Opera e Java'
        'cleanerRule.printQueueSpooler' = 'Coda di stampa (Spooler)'
        'cleanerRule.regeditLastKey' = 'Regedit ultima chiave'
        'cleanerRule.searchHistoryFiles' = 'Cerca file di cronologia'
        'cleanerRule.serviceProfilesTemp' = 'Profili di servizio Temp'
        'cleanerRule.srumData' = 'Dati SRUM'
        'cleanerRule.startDps' = 'Avvia DPS'
        'cleanerRule.stopDps' = 'Interrompi il DPS'
        'cleanerRule.systemComponentLogs' = 'Registri di sistema e componenti'
        'cleanerRule.systemRestorePoints' = 'Punti di ripristino del sistema'
        'cleanerRule.systemTempFiles' = 'File temporanei di sistema'
        'cleanerRule.temporaryInternetFiles' = 'File temporanei Internet'
        'cleanerRule.userRegistryHistoryValuesOnly' = 'Cronologia del registro utenti: solo valori'
        'cleanerRule.userTempFiles' = 'File temporanei dell''utente'
        'cleanerRule.visualStudioLicenses' = 'Licenze di Visual Studio'
        'cleanerRule.windowsAppDownloadCacheUser' = 'Cache download/app Windows - Utente'
        'cleanerRule.windowsOld' = 'Windows.vecchio'
        'cleanerRule.wininetCacheUser' = 'Cache WinInet - Utente'
        'cleanerRule.winsxsCleanup' = 'Pulizia WinSxS'
        'cleanerRule.winutilData' = 'Dati WinUtil'
        'confirm.profile.accept' = 'Sì, accetto l''eliminazione definitiva degli account locali e dei dati dei profili'
        'confirm.profile.sure' = 'Sei proprio sicuro?'
        'confirm.profile.warn1' = 'ATTENZIONE: questa opzione elimina definitivamente i profili utenti di Windows e gli account locali idonei, inclusi gli account i cui profili sono già stati eliminati. Sono esclusi l''utente corrente, gli account predefiniti o di sistema e gli utenti attivi.'
        'confirm.profile.warn2' = 'Gli account locali eliminati e i dati contenuti nei profili eliminati saranno irrecuperabili.'
        'confirm.profile.yes' = 'Sì, elimina gli account locali e i profili utenti'
        'gui.allExecuted' = 'Tutti gli script sono stati eseguiti.'
        'gui.architecture' = 'Architettura:'
        'gui.availableFunctions' = 'Funzioni disponibili'
        'gui.bitlockerStatus' = 'Stato Bitlocker:'
        'gui.complete' = 'Completa'
        'gui.disk' = 'Disco:'
        'gui.diskFreeFormat' = '{0}% libero ({1} GB / {2} GB)'
        'gui.editionVersionsFormat' = 'Edizione GUI v{0} | Core v{1}'
        'gui.executeScripts' = 'Esegui script'
        'gui.hardware' = 'Hardware'
        'gui.initialized' = 'WinToolkit GUI inizializzato correttamente.'
        'gui.instructions' = 'Seleziona uno o più script e premi ''Esegui script''.'
        'gui.languageLabel' = 'Lingua'
        'gui.limited' = 'Limitata'
        'gui.noneSelected' = 'Nessuno script selezionato.'
        'gui.outputLogs' = 'Output e log'
        'gui.pcName' = 'Nome PC:'
        'gui.ram' = 'RAM:'
        'gui.rebootPrompt' = 'Il sistema richiede un riavvio per completare le operazioni. Riavviare ora?'
        'gui.rebootTitle' = 'Riavvio Richiesto'
        'gui.scriptFeatures' = 'Funzionalità script:'
        'gui.sendErrorLogs' = 'Invia log errori'
        'gui.systemInfo' = 'Informazioni di sistema'
        'gui.unsupported' = 'Non supportata'
        'gui.version' = 'Versione:'
        'gui.windowsEdition' = 'Edizione Windows:'
        'language.aiTranslated' = 'false'
        'language.code' = 'it-IT'
        'language.name' = 'Italian'
        'language.nativeName' = 'Italiano'
        'menu.back' = 'Torna al menu precedente'
        'menu.changeLanguage' = 'Cambia lingua'
        'menu.choice' = 'Selezione'
        'menu.chooseLanguage' = 'Scegli una lingua'
        'menu.closing' = 'Chiusura in corso...'
        'menu.exitSection' = 'Uscita'
        'menu.exitToolkit' = 'Esci dal Toolkit'
        'menu.invalidSelection' = 'Nessuna selezione valida. Riprova.'
        'menu.language' = 'Lingua'
        'menu.languageChanged' = 'Lingua cambiata in {0}.'
        'menu.main' = 'Menu Principale'
        'menu.multiPrompt' = 'Inserisci uno o più numeri (es: 2 3 4 oppure 2,3,4) per eseguire le operazioni in sequenza'
        'menu.multiPromptShort' = 'Inserisci uno o più numeri'
        'menu.noLanguages' = 'Nessun file lingua trovato.'
        'menu.pressEnter' = 'Premi INVIO per tornare al menu...'
        'menu.startedInteractive' = 'WinToolkit avviato in modalità interattiva'
        'menu.support' = 'Per supporto: Github.com/Magnetarman'
        'noun.archive' = 'Archive'
        'noun.attempt' = 'Attempt'
        'noun.cache' = 'Cache'
        'noun.change' = 'Change'
        'noun.code' = 'Code'
        'noun.component' = 'Component'
        'noun.computer' = 'Computer'
        'noun.directory' = 'Directory'
        'noun.disk' = 'Disk'
        'noun.driver' = 'Driver'
        'noun.exception' = 'Exception'
        'noun.exitCode' = 'Exit code'
        'noun.file' = 'File'
        'noun.folder' = 'Folder'
        'noun.font' = 'Font'
        'noun.gpu' = 'GPU'
        'noun.icon' = 'Icon'
        'noun.log' = 'Log'
        'noun.operation' = 'Operation'
        'noun.package' = 'Package'
        'noun.pendingOperation' = 'Pending operation'
        'noun.policy' = 'Policy'
        'noun.profile' = 'Profile'
        'noun.registry' = 'Registry'
        'noun.registryKey' = 'Registry key'
        'noun.script' = 'Script'
        'noun.service' = 'Service'
        'noun.shortcut' = 'Shortcut'
        'noun.status' = 'Status'
        'noun.summary' = 'Summary'
        'noun.system' = 'System'
        'noun.task' = 'Task'
        'noun.tool' = 'Tool'
        'noun.update' = 'Update'
        'noun.user' = 'User'
        'noun.version' = 'Version'
        'noun.videoDriver' = 'Video driver'
        'noun.window' = 'Window'
        'reboot.countdown' = 'Riavvio sistema in'
        'reboot.reminder' = 'Ricorda di riavviare il sistema manualmente per completare le operazioni.'
        'reboot.required' = 'È necessario un riavvio per completare le operazioni.'
        'run.cancelled' = 'Operazione annullata. Ritorno al menu principale.'
        'run.error' = 'Errore durante {0}: {1}'
        'run.sequence' = 'Esecuzione sequenziale di {0} operazioni...'
        'run.start' = 'Avvio: {0}'
        'script.AutoVideoDriverInstall' = 'Auto Install Driver Video [Nvidia-AMD]'
        'script.DisableBitlocker' = 'Disabilita Bitlocker'
        'script.GamingToolkit' = 'Gaming Toolkit'
        'script.Install-Office' = 'Installa Office Basic'
        'script.Repair-Office' = 'Ripara Office'
        'script.Uninstall-Office' = 'Rimuovi Office'
        'script.VideoDriverReinstall' = 'Reinstalla Driver Video'
        'script.WinBackupDriver' = 'Backup Driver PC'
        'script.WinCleaner' = 'Pulizia File Temporanei'
        'script.WinDeleteUserProfiles' = 'Elimina gli account Windows, i profili utenti e le cartelle residue'
        'script.WinExportLog' = 'Esporta Log WinToolkit'
        'script.WinReinstallStore' = 'Winget/WinStore Reset'
        'script.WinRepairToolkit' = 'Riparazione Windows'
        'script.WinUpdateReset' = 'Reset Windows Update'
        'sourceText.active' = 'Attivo'
        'sourceText.applyingUnwrapping' = 'Applicazione de-incapsulamento.'
        'sourceText.automatic' = 'Automatico'
        'sourceText.automaticRestart' = 'Riavvio automatico'
        'sourceText.cancelled' = 'annullata'
        'sourceText.check' = 'controllo'
        'sourceText.compilerPs1PipelineExecutedWithCode' = 'Pipeline compiler.ps1 eseguita con codice'
        'sourceText.completed' = 'Completato'
        'sourceText.completedSuccessfully' = 'Completato con successo'
        'sourceText.completedWithErrors' = 'Completato con errori'
        'sourceText.configure' = 'configurare'
        'sourceText.configured' = 'configurato'
        'sourceText.coreScriptContentIsEmptyAfterLoadingAttempts' = 'Core Script content è vuoto dopo i tentativi di caricamento.'
        'sourceText.created' = 'creato'
        'sourceText.criticalError' = 'Errore critico'
        'sourceText.deleted' = 'eliminata'
        'sourceText.detected' = 'rilevata'
        'sourceText.detectedInternalFunctionIn' = 'Rilevata funzione interna in'
        'sourceText.download' = 'scaricare'
        'sourceText.downloaded' = 'scaricato'
        'sourceText.enabled' = 'attivato'
        'sourceText.failed' = 'fallito'
        'sourceText.file' = 'file'
        'sourceText.in' = 'tra'
        'sourceText.inactive' = 'Inattivo'
        'sourceText.initializationError' = 'Errore di inzializzazione'
        'sourceText.iOErrorWhileAggregatingModule' = 'Errore I/O aggregando il modulo'
        'sourceText.iOErrorWhileReadingSourceFiles' = 'Errore I/O durante la lettura dei file sorgente'
        'sourceText.manual' = 'Manuale'
        'sourceText.moduleProcessed' = 'Modulo processato'
        'sourceText.modules' = 'moduli'
        'sourceText.notFound' = 'non trovato'
        'sourceText.operation' = 'operazione'
        'sourceText.operationCompleted' = 'Operazione completata!'
        'sourceText.pendingOperations' = 'operazioni pendenti'
        'sourceText.pressAnyKeyToExit' = 'Premere un tasto per uscire'
        'sourceText.pressAnyKeyToExit2' = 'Premi un tasto per uscire.'
        'sourceText.readingSourceTemplate' = 'Lettura template originario'
        'sourceText.removal' = 'Rimozione'
        'sourceText.removed' = 'Rimosso'
        'sourceText.restored' = 'ripristinate'
        'sourceText.savingStandaloneExecutable' = 'Salvataggio eseguibile stand-alone'
        'sourceText.sources' = 'sorgenti'
        'sourceText.start' = 'inizio'
        'sourceText.starting' = 'Avvio'
        'sourceText.startingAggregation' = 'Inizio aggregazione'
        'sourceText.startingSafeMinificationThroughThePowershellTokenizer' = 'Avvio minificazione sicura via tokenizer PowerShell.'
        'sourceText.startingWintoolkitBuildProcess' = 'Avvio processo di build WinToolkit.'
        'sourceText.stopped' = 'arrestato'
        'sourceText.summary' = 'Riepilogo'
        'sourceText.summaryBuildDashboard' = 'BUILD DASHBOARD RIEPILOGATIVA'
        'sourceText.systemRestart' = 'Riavvio del sistema'
        'sourceText.unexpectedError' = 'Errore imprevisto'
        'sourceText.unexpectedErrorDuringMinification' = 'Errore imprevisto durante la minificazione'
        'sourceText.unknownError' = 'Errore sconosciuto'
        'sourceText.version' = 'Versione'
        'sourceText.warning' = 'Avviso'
        'summary.changed' = 'Modificato'
        'summary.completed' = 'Completato'
        'summary.detail' = 'Dettaglio'
        'summary.error' = 'Errore'
        'summary.failed' = 'Fallito'
        'summary.operation' = 'Operazione'
        'summary.skipped' = 'Saltato'
        'summary.status' = 'Stato'
        'summary.succeeded' = 'Riuscito'
        'summary.title' = 'Riepilogo Esecuzione'
        'system.architecture' = 'Architettura'
        'system.bitlockerStatus' = 'Stato Bitlocker'
        'system.computerName' = 'Nome PC'
        'system.disk' = 'Disco'
        'system.edition' = 'Edizione'
        'system.free' = 'Libero'
        'system.infoTitle' = 'INFORMAZIONI DI SISTEMA'
        'system.version' = 'Versione'
        'toolText.01Installation2' = '[{0}/{1}] Installazione: {2}'
        'toolText.01Starting2' = '[{0}/{1}] Avvio {2}.'
        'toolText.01Status2' = '{0} {1} - Stato: {2}'
        'toolText.0CheckScheduledAtNextReboot' = '{0}: controllo schedulato al prossimo riavvio.'
        'toolText.0Code1' = '{0}: codice {1}.'
        'toolText.0DeletedCaches' = '{0} cache eliminate.'
        'toolText.0DllAlreadyPresentInTheOriginalLocation' = '{0}.dll già presente nella posizione originale.'
        'toolText.0DllNotFoundAndNoBackupAvailable' = '{0}.dll non trovato e nessun backup disponibile.'
        'toolText.0Error0x800f0806PendingOperationsThisIsNotACriticalError' = '{0}: Errore 0x800f0806 (operazioni pendenti). Questo non è un errore critico.'
        'toolText.0ErrorsDetectedNewAttempt' = '{0} errori rilevati. Nuovo tentativo.'
        'toolText.0FilesIgnoredBecauseTheyAreInUseOrNotAccessible' = '{0} file ignorati perché in uso o non accessibili.'
        'toolText.0ItemsNotRemovedMayBeBlockedByOpenSessionsOrHandles' = '{0} elementi non rimossi potrebbero essere bloccati da sessioni o handle aperti.'
        'toolText.0OfficeFoldersRemoved' = '{0} cartelle Office rimosse.'
        'toolText.0OfficeLinksRemoved' = '{0} collegamenti Office rimossi.'
        'toolText.0OfficeRegistryKeysRemoved' = '{0} chiavi registro Office rimosse.'
        'toolText.0OfficeTasksRemoved' = '{0} attività Office rimosse.'
        'toolText.0Reverting1To2' = '{0} Ripristino {1} a {2}.'
        'toolText.0Service1ConfiguredAs2' = '{0} Servizio {1} configurato come {2}.'
        'toolText.0Service1NotFoundOnTheSystem' = '{0} Servizio {1} non trovato nel sistema.'
        'toolText.0Service1Restored' = '{0} Servizio {1} ripristinato.'
        'toolText.0Service1StartedSuccessfully' = '{0} Servizio {1}: avviato correttamente.'
        'toolText.0Service1StartingOrDelayed' = '{0} Servizio {1}: avvio in corso o ritardato.'
        'toolText.0Service1Stopped' = '{0} Servizio {1} arrestato.'
        'toolText.0ServiceProcessing1' = '{0} Elaborazione servizio: {1}.'
        'toolText.0ShuttingDown1TookTooLongOrFailed' = '{0} Arresto di {1} ha richiesto troppo tempo o è fallito.'
        'toolText.0Status1Starting2' = '{0} - Stato: {1} | Avvio: {2}.'
        'toolText.0Unable123' = '{0} Impossibile {1} {2} - {3}.'
        'toolText.0V1' = '{0} v{1}'
        'toolText.alertsGenerated0' = 'Avvisi generati: {0}.'
        'toolText.archiveMoveError0' = 'Errore spostamento archivio: {0}'
        'toolText.archiveSavedToDesktop' = 'Archivio salvato sul desktop.'
        'toolText.attemptedVia0' = 'Tentativo tramite: {0}.'
        'toolText.attemptFailedILlTryForceDeletion' = 'Tentativo fallito, provo con eliminazione forzata.'
        'toolText.attempting01SystemRepair' = 'Tentativo {0}/{1} - Riparazione sistema.'
        'toolText.attemptingFullRepairOnlineAsAFallback' = 'Tentativo riparazione completa (online) come fallback.'
        'toolText.autostart0RemovedFromRegistry' = 'Avvio automatico ''{0}'' rimosso dal registro.'
        'toolText.autostartCleaner' = 'Pulizia avvio automatico.'
        'toolText.autostartLink0Removed' = 'Collegamento avvio automatico ''{0}'' rimosso.'
        'toolText.autoVideoDriverInstallFinished' = 'Auto Video Driver Install terminato.'
        'toolText.autovideodriverinstallSessionEnded' = 'AutoVideoDriverInstall sessione terminata.'
        'toolText.batchSwitchToNormalModeBatCreatedOnDesktop' = 'Batch ''Switch to Normal Mode.bat'' creato sul Desktop.'
        'toolText.battleNetProcessDidNotStartProperly' = 'Battle.net: processo non avviato correttamente.'
        'toolText.battleNetTimedOut' = 'Timeout Battle.net.'
        'toolText.blockingAutomaticDriversFromWindowsUpdate' = 'Blocco driver automatici da Windows Update.'
        'toolText.cachetaskDisableError0' = 'Errore di disabilitazione di CacheTask: {0}'
        'toolText.cachetaskEnableError0' = 'Errore di abilitazione CacheTask: {0}'
        'toolText.canBeUsedToReinstallAllDriversWithoutRedownloadingThem' = 'Utilizzabile per reinstallare tutti i driver senza riscaricarli.'
        'toolText.checkByOpeningSettingsUpdateSecurity' = 'Verifica aprendo Impostazioni > Aggiornamento e sicurezza.'
        'toolText.checkCriticalSystemServices' = 'Verifica servizi di sistema critici.'
        'toolText.checkPresenceOfLogFolder' = 'Verifica presenza cartella log.'
        'toolText.checkResidualFoldersInTheUsersDirectory' = 'Controllo cartelle residue nella directory utenti.'
        'toolText.checkTheLogsForTechnicalDetails' = 'Controlla i log per dettagli tecnici.'
        'toolText.checkWingetAvailability' = 'Verifica disponibilità Winget.'
        'toolText.chkdskCommandSentRebootToPerformDeepDiskRepair' = 'Comando chkdsk inviato. Riavvia per eseguire la riparazione profonda del disco.'
        'toolText.cimProfileDetectionFailed0' = 'Rilevazione profili tramite CIM non riuscita: {0}.'
        'toolText.cimProfileRemoved0' = 'Profilo CIM rimosso: {0}.'
        'toolText.cimRemoveFailed01' = 'Rimozione CIM non riuscita: {0} - {1}.'
        'toolText.cleaned0ItemsIn1' = 'Puliti {0} elementi in {1}.'
        'toolText.cleaningCompleted' = 'Pulizia completata.'
        'toolText.cleaningScheduledTasks' = 'Pulizia attività pianificate.'
        'toolText.cleaningWindowsUpdateStatusBeforeStartingCleanup' = 'Pulizia stato Windows Update prima di avviare Cleanup...'
        'toolText.cleanupFailed01' = 'Pulizia non riuscita: {0} - {1}.'
        'toolText.cleanupGpcacheCacheAndWsusSettings' = 'Pulizia cache GPCache e impostazioni WSUS.'
        'toolText.clearEventlog0' = 'Cancella registro eventi: {0}'
        'toolText.clearEventlog01' = 'Cancella registro eventi [{0}]: {1}'
        'toolText.clientsInstalled' = 'Client installati.'
        'toolText.cmdkeyDelete0Error1' = 'tasto cmdeliminazione errore [{0}]: {1}'
        'toolText.cmdkeyListError0' = 'errore nell''elenco dei tasti cmd: {0}'
        'toolText.commandExecution0' = 'Esecuzione comando: {0}.'
        'toolText.commandTimesOutAfter0Hours' = 'Comando timeout dopo {0} ore.'
        'toolText.completed' = 'COMPLETED'
        'toolText.completedProfile01' = 'PROFILO COMPLETATO - {0} - {1:hh:mm:ss}'
        'toolText.completedResidualFolder01' = 'CARTELLA RESIDUO COMPLETATA - {0} - {1}'
        'toolText.compressingLogsSomeFilesInUseMayBeIgnored' = 'Compressione dei log in corso. Potrebbe essere ignorato qualche file in uso.'
        'toolText.compressionCompleted0MbReduction1' = 'Compressione completata: {0} MB (Riduzione: {1}%).'
        'toolText.computer0' = 'Computer: {0}'
        'toolText.couldNotEnumerateRegistryProfileList0' = 'Impossibile enumerare il ProfileList del registro: {0}.'
        'toolText.createBackupAndLogDirectories' = 'Directory backup e log create.'
        'toolText.criteriaRemoved' = 'Criteri eliminati.'
        'toolText.criticalError0SeeTheLogInLocalappdataWintoolkitLogsOrIn1' = 'Errore critico: {0}. Consulta il log in %LOCALAPPDATA%\WinToolkit\logs o in {1}'
        'toolText.criticalErrorDuringDriverReinstallation0' = 'Errore critico durante reinstallazione driver: {0}'
        'toolText.criticalErrorInInstallOffice' = 'Errore critico in Install-Office'
        'toolText.criticalErrorInRepairOffice' = 'Errore critico in Repair-Office'
        'toolText.criticalErrorInUninstallOffice' = 'Errore critico in Uninstall-Office'
        'toolText.criticalErrorRepairingOffice0' = 'Errore critico durante riparazione Office: {0}'
        'toolText.criticalErrorWhileRemovingOffice0' = 'Errore critico durante rimozione Office: {0}'
        'toolText.currentUserProtected0' = 'Utente corrente protetto: {0}'
        'toolText.dduExtractedToDesktop' = 'DDU estratto sul Desktop.'
        'toolText.dduExtractionError0' = 'Errore estrazione DDU: {0}.'
        'toolText.debloatOperationsCompleted' = 'Operazioni di debloat completate.'
        'toolText.decryptionInProgressInBackground' = 'Decrittazione in corso in background.'
        'toolText.decryptionStartedCompletedSuccessfully' = 'Decrittazione avviata/completata con successo.'
        'toolText.deletingLocalPolicies' = 'Eliminazione criteri locali.'
        'toolText.deletionOfWindowsUpdateComponents' = 'Eliminazione componenti Windows Update.'
        'toolText.detailsOfErrorsAndWarnings' = 'Dettaglio Errori e Warning:'
        'toolText.detectingGpuConfiguration' = 'Rilevamento configurazione GPU in corso...'
        'toolText.directories01' = 'Directory ({0}/{1})'
        'toolText.directory0Deleted' = 'Directory {0} eliminata.'
        'toolText.directory0DeletedForcedMethod' = 'Directory {0} eliminata (metodo forzato).'
        'toolText.directory0NotPresent' = 'Directory {0} non presente.'
        'toolText.directory0PartiallyDeleted' = 'Directory {0} parzialmente eliminata.'
        'toolText.directRemovalCompleted' = 'Rimozione diretta completata.'
        'toolText.directxDownloaded' = 'DirectX scaricato.'
        'toolText.directxInstallation' = 'Installazione DirectX.'
        'toolText.directxProcessDidNotStartCorrectly' = 'DirectX: processo non avviato correttamente.'
        'toolText.directxTimeout' = 'Timeout DirectX.'
        'toolText.disablebitlockerSessionEnded' = 'DisableBitlocker sessione terminata.'
        'toolText.disablingAutomaticEncryptionInTheRegistry' = 'Disabilitazione crittografia automatica nel registro.'
        'toolText.disasterRecoveryFailed0' = 'Ripristino di emergenza fallito: {0}.'
        'toolText.doNotDisturbActivation' = 'Attivazione Non disturbare.'
        'toolText.doNotDisturbActive' = 'Non disturbare attivo.'
        'toolText.downloadFailedInstallationCancelled' = 'Download fallito. Installazione annullata.'
        'toolText.driverBackupCompletedSuccessfully' = 'Backup driver completato con successo!'
        'toolText.driverBackupToolkitFinished' = 'Driver Backup Toolkit terminato.'
        'toolText.driversViaWindowsUpdateEnabled' = 'Driver tramite Windows Update abilitati.'
        'toolText.driverWuBlockError0IContinueAnyway' = 'Errore blocco WU driver: {0}. Proseguo comunque.'
        'toolText.driverWuLockSet' = 'Blocco WU driver impostato.'
        'toolText.elimination0' = 'Eliminazione {0}'
        'toolText.emergencyAttemptViaAppxmanifest' = 'Tentativo di emergenza tramite AppXManifest.'
        'toolText.enableWindowsUpdateAutomaticRestart' = 'Abilitazione riavvio automatico Windows Update.'
        'toolText.enablingDriversViaWindowsUpdate' = 'Abilitazione driver tramite Windows Update.'
        'toolText.enablingNetframework' = 'Abilitazione NetFramework.'
        'toolText.enablingWindowsUpdateAndRelatedServices' = 'Abilitazione Windows Update e servizi correlati.'
        'toolText.energyProfileConfiguration' = 'Configurazione profilo energetico.'
        'toolText.environmentInitializationError0' = 'Errore inizializzazione ambiente: {0}'
        'toolText.error' = 'Errore!'
        'toolText.errorAlsoDuringOnlineRepair0' = 'Errore anche durante riparazione online: {0}.'
        'toolText.errorCopyingFiles0' = 'Errore durante la copia dei file: {0}.'
        'toolText.errorDuringDirectxInstallation0' = 'Errore durante installazione DirectX: {0}'
        'toolText.errorDuringDriverInstallation0' = 'Errore durante installazione driver: {0}'
        'toolText.errorDuringEnergyPlanActivation0' = 'Errore durante attivazione piano energetico: {0}.'
        'toolText.errorDuringEnergyPlanDuplication0' = 'Errore durante duplicazione piano energetico: {0}'
        'toolText.errorDuringFocusAssistConfiguration0' = 'Errore durante configurazione Focus Assist: {0}'
        'toolText.errorDuringGetHelpProcess0' = 'Errore durante processo Get Help: {0}.'
        'toolText.errorDuringQuickRepair0' = 'Errore durante riparazione rapida: {0}.'
        'toolText.errorEditingRegistry0' = 'Errore durante la modifica del registro - {0}.'
        'toolText.errorEnablingNetframeworkFeature0Code1' = 'Errore abilitazione feature NetFramework {0}: codice {1}.'
        'toolText.errorExportingDriver0' = 'Errore durante esportazione driver: {0}'
        'toolText.errorExtractingArchiveGetHelp0' = 'Errore durante estrazione archivio Get Help: {0}.'
        'toolText.errorInAutovideodriverinstall' = 'Errore in AutoVideoDriverInstall'
        'toolText.errorInstallingBattleNet0' = 'Errore durante installazione Battle.net: {0}'
        'toolText.errorInstallingOffice0' = 'Errore durante installazione Office: {0}'
        'toolText.errorInstallingUnigetUi0' = 'Errore durante installazione UniGet UI: {0}.'
        'toolText.errorInVideodriverreinstall' = 'Errore in VideoDriverReinstall'
        'toolText.errorOptimizing01' = 'Errore durante l''ottimizzazione di {0}: {1}.'
        'toolText.errorRestartingService0' = 'Errore durante riavvio servizio: {0}'
        'toolText.errorRunningGetHelp0SwitchingToAlternativeMethod' = 'Errore durante esecuzione Get Help: {0}. Passaggio a metodo alternativo.'
        'toolText.errorSchedulingChkdskForDeepRepair' = 'Errore durante la schedulazione di chkdsk per la riparazione profonda.'
        'toolText.errorsEncountered0' = 'Errori riscontrati: {0}.'
        'toolText.errorStoppingService0' = 'Errore durante arresto servizio: {0}'
        'toolText.errorWhileDirectlyRemovingOffice0' = 'Errore durante rimozione diretta Office: {0}.'
        'toolText.exception01' = 'Eccezione {0} : {1}.'
        'toolText.excludedProfile01' = 'Profilo escluso: {0} ({1}).'
        'toolText.excludedProfileBecauseSidMatchesCurrentUser0' = 'Profilo escluso perché il SID corrisponde all''utente corrente: {0} ({1}).'
        'toolText.existingPlanFound' = 'Piano esistente trovato.'
        'toolText.exportCompleted0Driver1Mb' = 'Esportazione completata: {0} driver ({1} MB).'
        'toolText.extra.01Completed' = '{0} / {1} completati'
        'toolText.extra.0NotCompletedAbortedDueToTimeout' = '{0} NON completato (interrotto per Timeout).'
        'toolText.extra.0ShadowCopiesDetectedRemovingOld1' = 'Rilevate {0} shadow copies. Rimozione di {1} vecchie.'
        'toolText.extra.analysisAndCleaningOfShadowCopiesKeepLatest' = 'Analisi e pulizia shadow copies (mantieni ultima).'
        'toolText.extra.attentionYouAreCleaningWithWindowsUpdateInProgressRefreshYourSystemAndTryAgainToPerformAFu' = 'ATTENZIONE! - Stai effettuando la pulizia con Windows Update in corso. Aggiorna il sistema e riprova per eseguire la pulizia completa'
        'toolText.extra.backupDirectoryNotFound0' = 'Directory backup non trovata: {0}'
        'toolText.extra.basicConfiguration' = 'Configurazione Basic'
        'toolText.extra.battleNetCode0' = 'Battle.net: codice {0}'
        'toolText.extra.checkServiceStatus0' = 'Verifica stato servizio {0}.'
        'toolText.extra.chromeAiPolicySettingError0' = 'Errore impostazione policy Chrome AI: {0}'
        'toolText.extra.chromiumBrowserCacheCleaner' = 'Pulizia Cache Browser Chromium.'
        'toolText.extra.cleaning0' = 'Pulizia {0}'
        'toolText.extra.cleaningAndDisablingAiChromeOptguide' = 'Pulizia e disattivazione AI Chrome (OptGuide).'
        'toolText.extra.cleaningCredentials' = 'Pulizia Credenziali.'
        'toolText.extra.cleaningEventLogsClassicModern' = 'Pulizia Event Logs (classici + moderni).'
        'toolText.extra.cleaningFirefoxCacheCrashes' = 'Pulizia Firefox (Cache & Crashes).'
        'toolText.extra.cleanmgrCompleted' = 'CleanMgr completato.'
        'toolText.extra.cleanmgrConfiguration' = 'Configurazione CleanMgr.'
        'toolText.extra.cleanmgrConfigurationEnabledForWindowsOldStateflags0066' = 'Configurazione CleanMgr attivata per Windows.old (StateFlags0066).'
        'toolText.extra.cleanPrintQueueIn01FilesRemoved' = 'Coda di stampa pulita in {0} ({1} file rimossi)'
        'toolText.extra.cleanSystemRestorePoints' = 'Pulizia punti di ripristino sistema.'
        'toolText.extra.cleanupWininetWebcacheCache' = 'Pulizia cache WinInet/WebCache.'
        'toolText.extra.commandCompleted' = 'Comando completato.'
        'toolText.extra.commandCompletedWithCode0' = 'Comando completato con codice {0}'
        'toolText.extra.commandError0' = 'Errore comando: {0}'
        'toolText.extra.criticalErrorDuringBackup' = 'Errore critico durante backup'
        'toolText.extra.directxError0' = 'DirectX errore: {0}'
        'toolText.extra.directxInstallation' = 'Installazione DirectX'
        'toolText.extra.directxInstalledCode0' = 'DirectX installato (codice: {0}).'
        'toolText.extra.disasterRecoveryStore' = 'Ripristino di emergenza Store'
        'toolText.extra.diskCheck' = 'Controllo disco'
        'toolText.extra.dismDriverExport' = 'Esportazione driver DISM'
        'toolText.extra.errorCleaningRestorePoints0' = 'Errore durante la pulizia punti di ripristino: {0}'
        'toolText.extra.errorCleaningSpooler0' = 'Errore durante la pulizia Spooler: {0}'
        'toolText.extra.errorCompressingLogs' = 'Errore durante la compressione dei log'
        'toolText.extra.errorInInvokeRepaircommand0' = 'Errore in Invoke-RepairCommand [{0}]'
        'toolText.extra.failedToWriteToRegistryForCleanmgr0' = 'Impossibile scrivere nel registro per CleanMgr: {0}'
        'toolText.extra.groupPolicyUpdateMayTake12Minutes' = 'Aggiornamento criteri di gruppo (può impiegare 1-2 minuti)'
        'toolText.extra.improvedManagementOfDiagtrackService' = 'Gestione migliorata servizio DiagTrack.'
        'toolText.extra.installation0' = 'Installazione {0}'
        'toolText.extra.installingBattleNet' = 'Installazione Battle.net'
        'toolText.extra.invalidArchivePath0' = 'Percorso archivio non valido: {0}'
        'toolText.extra.iTheWindowsOldFolderMayRequireARebootForCompleteRemoval' = 'ℹ La cartella Windows.old potrebbe richiedere un riavvio per la rimozione completa.'
        'toolText.extra.logProcessing' = 'Elaborazione registro'
        'toolText.extra.multipleStateFilesFoundServiceWillNotBeRestartedAutomatically' = 'Multiple state files found, servizio non verrà riavviato automaticamente'
        'toolText.extra.noShadowCopyDetected' = 'Nessuna shadow copy rilevata.'
        'toolText.extra.noWindowsOldFolderDetected' = 'Nessuna cartella Windows.old rilevata.'
        'toolText.extra.officeBasicInstallation' = 'Installazione Office Basic'
        'toolText.extra.officeSetup' = 'Configurazione dell''ufficio'
        'toolText.extra.onlyOneShadowCopyFoundNoRemovalNecessary' = 'Trovata una sola shadow copy. Nessuna rimozione necessaria.'
        'toolText.extra.optguideFolderSetToReadOnly0' = 'Cartella OptGuide impostata in sola lettura: {0}'
        'toolText.extra.preparingToRestartTheSystem' = 'Preparazione riavvio sistema'
        'toolText.extra.printQueueCleaningSpooler' = 'Pulizia coda di stampa (Spooler).'
        'toolText.extra.profilePathDoesNotExist0' = 'Il percorso profili non esiste: {0}'
        'toolText.extra.readOnlySettingErrorFor01' = 'Errore impostazione read-only per {0} : {1}'
        'toolText.extra.rebootingIn' = 'Riavvio in'
        'toolText.extra.rebootRequired' = 'Riavvio necessario'
        'toolText.extra.rebootToApplyChanges' = 'Riavvio per applicare le modifiche'
        'toolText.extra.registerError01' = 'Errore registro {0} : {1}'
        'toolText.extra.registryKeyPreviousInstallationsNotFoundStandardExecutionAttempt' = 'Chiave registro ''Previous Installations'' non trovata. Tentativo di esecuzione standard.'
        'toolText.extra.remnantCleanupUpdates' = 'Pulizia Residui Aggiornamenti'
        'toolText.extra.removal0' = 'Rimozione: {0}'
        'toolText.extra.removal02' = 'Rimozione: {0}'
        'toolText.extra.removalCompleted' = 'Rimozione completata'
        'toolText.extra.removalError01' = 'Errore rimozione {0} : {1}'
        'toolText.extra.removedKey0' = 'Rimossa chiave {0}'
        'toolText.extra.removingOfficeUsingGetHelp' = 'Rimozione Office tramite Get Help'
        'toolText.extra.removingOptguideFolder0' = 'Rimozione cartella OptGuide: {0}'
        'toolText.extra.removingRegisteredProfiles' = 'Rimozione profili registrati'
        'toolText.extra.removingResidualFoldersInCUsers' = 'Rimozione cartelle residue in C:\Users'
        'toolText.extra.repairCompleted' = 'Riparazione completata'
        'toolText.extra.restartingSpoolerService' = '▶ Riavvio servizio Spooler.'
        'toolText.extra.restartInSafeModeForDdu' = 'Riavvio in Safe Mode per DDU'
        'toolText.extra.restartRecommendedAfterProfileCleanup' = 'Riavvio consigliato dopo pulizia profili'
        'toolText.extra.restorePointCleanupCompleted' = 'Pulizia punti di ripristino completata'
        'toolText.extra.safeModeConfigurationBcdedit' = 'Configurazione Safe Mode (bcdedit)'
        'toolText.extra.service0ActiveStopping' = 'Servizio {0} attivo, arresto in corso.'
        'toolText.extra.service0DownCheckRestart' = 'Servizio {0} non attivo, verifica riavvio.'
        'toolText.extra.service0NotFoundSkip' = 'Servizio {0} non trovato, skip'
        'toolText.extra.service0RestartedSuccessfully' = 'Servizio {0} riavviato con successo'
        'toolText.extra.service0WasNotActivePreviously' = 'Servizio {0} non era attivo precedentemente'
        'toolText.extra.serviceError01' = 'Errore servizio {0} : {1}'
        'toolText.extra.serviceStoppedAndStateSavedAutoRestartEnabled' = 'Servizio arrestato e stato salvato - riavvio automatico abilitato'
        'toolText.extra.serviceStoppedManualRestartRequired' = 'Servizio arrestato - riavvio manuale richiesto'
        'toolText.extra.shadowCopyManagementError0' = 'Errore gestione shadow copies: {0}'
        'toolText.extra.spoolerServiceRestarted' = 'Servizio Spooler riavviato.'
        'toolText.extra.spoolerServiceStopped' = 'Servizio Spooler arrestato.'
        'toolText.extra.startingService0' = '▶ Avvio servizio {0}.'
        'toolText.extra.stoppingService0' = 'Arresto servizio {0}.'
        'toolText.extra.stoppingSpoolerService' = 'Arresto servizio Spooler.'
        'toolText.extra.storeInstallationViaWinget' = 'Installazione Store tramite Winget'
        'toolText.extra.systemFileChecker1' = 'Controllo file di sistema (1)'
        'toolText.extra.systemFileChecker2' = 'Controllo file di sistema (2)'
        'toolText.extra.systemProtectionKeptActiveForSafety' = 'Protezione sistema mantenuta attiva per sicurezza'
        'toolText.extra.systemRebootIn' = 'Riavvio sistema in'
        'toolText.extra.thoroughDiskCheck' = 'Controllo disco approfondito'
        'toolText.extra.timeoutReachedDuringDismExport' = 'Timeout raggiunto durante l''esportazione DISM'
        'toolText.extra.unableToCleanCompletely0' = 'Impossibile pulire completamente {0}'
        'toolText.extra.unigetUiInstallation' = 'Installazione UniGet UI'
        'toolText.extra.uninstallation0' = 'Disinstallazione {0}'
        'toolText.extra.waitingForStart0' = 'Attesa avvio {0}'
        'toolText.extra.windowsImageRecovery' = 'Ripristino immagine Windows'
        'toolText.extra.windowsOldFolderDetectedStartingSafeRemovalWithNativeCleanmgr' = 'Rilevata cartella Windows.old. Avvio rimozione sicura con Native CleanMgr.'
        'toolText.extra.windowsUpdateCacheCleaner' = 'Pulizia cache di Windows Update.'
        'toolText.extra2.desktopDirectoryNotAccessible0' = 'Directory desktop non accessibile: {0}'
        'toolText.extra2.oldShadowCopiesRemovedLastPreservedCopy' = 'Vecchie shadow copies rimosse. Ultima copia preservata.'
        'toolText.extra2.printQueueSpoolerCleanedAndRestartedSuccessfully' = 'Print Queue Spooler pulito e riavviato con successo.'
        'toolText.extra2.set01' = 'Impostato {0}\{1}'
        'toolText.extra2.theScriptMustBeRunFromAPowershellConsoleStartedAsAdministrator' = 'Lo script deve essere eseguito da una console PowerShell avviata come amministratore.'
        'toolText.extra2.waitingForCleanmgrToCompleteMayTakeAFewMinutes' = 'Attesa completamento CleanMgr (può richiedere alcuni minuti)...'
        'toolText.extra2.windowsOldSuccessfullyRemoved' = 'Windows.old rimosso con successo.'
        'toolText.extra3.0CompletedSuccessfully' = '{0} completed successfully.'
        'toolText.extra3.0CompletedWith1Errors' = '{0} completato con errori {1}.'
        'toolText.extra3.configuring0' = 'Configuring {0}'
        'toolText.extra3.starting0' = 'Starting {0}'
        'toolText.extra3.stopping0' = 'Stopping {0}'
        'toolText.extractingDduToDesktop' = 'Estrazione DDU sul Desktop.'
        'toolText.extractionCompleted' = 'Estrazione completata.'
        'toolText.extractionGetHelp' = 'Estrazione Get Help.'
        'toolText.failedProfile0' = 'PROFILO FALLITO - {0}'
        'toolText.failedResidualFolder0' = 'CARTELLA RESIDUA ERRATA - {0}'
        'toolText.failedToCreateFile0' = 'Impossibile creare il file: {0}'
        'toolText.failedToCreateParentDirectory0' = 'Impossibile creare la directory principale: {0}'
        'toolText.failedToCreateSafeModeBatch0' = 'Impossibile creare batch Safe Mode: {0}.'
        'toolText.failedToExportSfcCbsLogFileInUse' = 'Impossibile esportare il log CBS di SFC (file in uso).'
        'toolText.failedToNormalizeRegisteredProfileLocalpath0' = 'Impossibile normalizzare LocalPath profilo registrato: {0}'
        'toolText.failedToRemoveRegistryEntryForSid01' = 'Impossibile rimuovere la voce del registro per SID: {0} - {1}.'
        'toolText.finalArchive0' = 'Archivio finale: {0}'
        'toolText.finalCheckOfTheStatusOfTheServices' = 'Verifica finale dello stato dei servizi.'
        'toolText.finalCleaning' = 'Pulizia finale.'
        'toolText.folderRemoved0' = 'Cartella rimossa: {0}.'
        'toolText.folderRemovedAfterAclReset0' = 'Cartella rimossa dopo reimpostazione ACL: {0}.'
        'toolText.found0OfficePackages' = 'Trovati {0} pacchetti Office.'
        'toolText.gameClientInstallation' = 'Installazione client di gioco.'
        'toolText.gamingToolkitCompleted' = 'Gaming Toolkit completato!'
        'toolText.gethelpcmdExeNotFound' = 'GetHelpCmd.exe non trovato.'
        'toolText.getHelpCompletedSuccessfully' = 'Get Help completato con successo.'
        'toolText.getHelpFailed0AttemptedAlternativeMethod' = 'Get Help fallito: {0}. Tentativo metodo alternativo.'
        'toolText.getHelpStartedTheRemovalInAnExternalWindowWaitingForCompletion' = 'Get Help ha avviato la rimozione in una finestra esterna. Attesa completamento...'
        'toolText.gpcacheCacheDeleted' = 'Cache GPCache eliminata.'
        'toolText.gpcacheCacheNotPresent' = 'Cache GPCache non presente.'
        'toolText.gpuDetected0' = 'GPU rilevata: {0}.'
        'toolText.gpuNotDetectedDriverNotAvailableForAutomaticInstallation' = 'GPU non rilevata: driver non disponibile per l''installazione automatica.'
        'toolText.gpuNotDetectedOnlyDduWillBePlacedOnTheDesktop' = 'GPU non rilevata: solo DDU verrà posizionato sul Desktop.'
        'toolText.gpupdateCompletedWithCode0IContinueAnyway' = 'gpupdate completato con codice: {0}. Proseguo comunque.'
        'toolText.gpupdateDidNotRespondIContinueAnyway' = 'gpupdate non ha risposto. Proseguo comunque.'
        'toolText.gpupdateTerminatedWithErrorsOrTimedOut' = 'gpupdate terminato con errori o timeout.'
        'toolText.individualRestartSuppressedAFinalRebootWillBeHandled' = 'Riavvio individuale soppresso. Verrà gestito un riavvio finale.'
        'toolText.initializingBackupEnvironment' = 'Inizializzazione ambiente backup.'
        'toolText.initializingDriveCDecryption' = 'Inizializzazione decrittazione drive C:.'
        'toolText.initializingTheWindowsUpdateResetScript' = 'Inizializzazione dello Script di Reset Windows Update.'
        'toolText.inProgress0Seconds' = 'In corso... ({0} secondi)'
        'toolText.inSafeModeRunDduToCleanTheDriversThenReinstallWithTheDesktopInstallerFinallyUseBatchToRetu' = 'In Safe Mode: esegui DDU per pulire i driver, poi reinstalla con l''installer sul Desktop. Infine usa il batch per tornare alla modalità normale.'
        'toolText.installationCompleted' = 'Installazione completata.'
        'toolText.installationError0Code1' = 'Errore installazione {0} (codice: {1}).'
        'toolText.installationFailed' = 'Installazione fallita.'
        'toolText.installed0' = 'Installato: {0}'
        'toolText.installingBattleNet' = 'Installazione Battle.net.'
        'toolText.installingNetRuntimeAndVcredist' = 'Installazione runtime .NET e VCRedist.'
        'toolText.installOfficeSessionEnded' = 'Install-Office sessione terminata.'
        'toolText.intelGpuDownloadDriversManuallyFromIntelIfNecessary' = 'GPU Intel: scarica driver manualmente da Intel se necessario.'
        'toolText.itemsNotRemoved0' = 'Elementi non rimossi: {0}'
        'toolText.lastActivityThresholdProfilesNotUsedForAtLeast0Days' = 'Soglia ultima attività: profili non usati da almeno {0} giorni.'
        'toolText.launchQuickRepairOffline' = 'Avvio riparazione rapida (offline).'
        'toolText.localAccountProtected0' = 'L''account locale {0} è protetto o in uso; eliminazione ignorata.'
        'toolText.localAccountRemovalFailed01' = 'Impossibile rimuovere l''account locale {0}: {1}'
        'toolText.localAccountRemoved01' = 'Account locale rimosso: {0} ({1}).'
        'toolText.localAccountsRemoved0' = 'Account locali rimossi: {0}'
        'toolText.localAccountsSelectedForAutomaticRemoval0' = 'Account locali selezionati per la rimozione automatica: {0}'
        'toolText.localAccountStillExists0' = 'L''account locale esiste ancora dopo l''eliminazione: {0}'
        'toolText.location0' = 'Posizione: {0}'
        'toolText.log0' = 'Log: {0}'
        'toolText.logsCompressedSuccessfullySavedFile0OnDesktop' = 'Log compressi con successo! File salvato: ''{0}'' sul Desktop.'
        'toolText.manageBdeExitCode0BitlockerMayAlreadyBeDownOrInError' = 'Codice uscita manage-bde: {0}. BitLocker potrebbe essere già disattivo o in errore.'
        'toolText.method0Failed1' = 'Metodo {0} fallito: {1}.'
        'toolText.method0FailedExitcode1' = 'Metodo {0} non riuscito (ExitCode: {1}).'
        'toolText.microsoftStoreNotRestored' = 'Microsoft Store non ripristinato.'
        'toolText.microsoftStoreReinstalledVia0' = 'Microsoft Store reinstallato tramite {0}.'
        'toolText.microsoftStoreRestoredViaEmergencyMethod' = 'Microsoft Store ripristinato tramite metodo di emergenza.'
        'toolText.microsoftStoreSuccessfullyRestored' = 'Microsoft Store ripristinato correttamente.'
        'toolText.movingArchiveToDesktop' = 'Spostamento archivio su desktop.'
        'toolText.netframeworkEnabled' = 'NetFramework abilitato.'
        'toolText.netframeworkFeatureEnabled0' = 'Feature NetFramework abilitata: {0}.'
        'toolText.noFilesToCompressInBackupDirectory' = 'Nessun file da comprimere nella directory backup.'
        'toolText.noKnownStableDriversFoundIUseAutodetectFallback' = 'Nessun driver stabile conosciuto trovato. Uso fallback autodetect.'
        'toolText.noLogFilesCopiedCheckPermissionsAndThatTheFilesExist' = 'Nessun file log copiato. Verifica i permessi e che i file esistano.'
        'toolText.nonInteractiveModeNoConfirmationWillBeRequestedBeforeCancellations' = 'Modalità non interattiva: nessuna conferma verrà richiesta prima delle cancellazioni.'
        'toolText.noProblemsDetected' = 'Nessun problema rilevato.'
        'toolText.noRegistryKeysToRemove' = 'Nessuna chiave di registro da rimuovere.'
        'toolText.noRemovableRegisteredProfilesFound' = 'Nessun profilo registrato rimovibile trovato.'
        'toolText.noRemovableResidualFolderFoundInCUsers' = 'Nessuna cartella residua rimovibile trovata in C:\Users.'
        'toolText.noRemovableResidualFoldersFound' = 'Nessuna cartella residua rimovibile trovata.'
        'toolText.noteARebootIsRequiredToFullyApplyAllChanges' = 'Nota: È necessario un riavvio per applicare completamente tutte le modifiche.'
        'toolText.noThirdPartyDriversFoundToExport' = 'Nessun driver di terze parti trovato da esportare.'
        'toolText.officeCacheCleaner' = 'Pulizia cache Office.'
        'toolText.officeclicktorunExeNotFoundOfficeMayNotBeInstalled' = 'OfficeClickToRun.exe non trovato. Office potrebbe non essere installato.'
        'toolText.officeFolderCleaning' = 'Pulizia cartelle Office.'
        'toolText.officeInstallFinished' = 'Office Install terminato.'
        'toolText.officePostInstallationConfiguration' = 'Configurazione post-installazione Office.'
        'toolText.officePostRepairSetup' = 'Configurazione post-riparazione Office.'
        'toolText.officeRegistryCleaner' = 'Pulizia registro Office.'
        'toolText.officeRemovalComplete' = 'Rimozione Office completata!'
        'toolText.officeRepairComplete' = 'Riparazione Office completata!'
        'toolText.officeRepairFinished' = 'Office Repair terminato.'
        'toolText.officeResidueCleaning' = 'Pulizia residui Office.'
        'toolText.officeUninstallFinished' = 'Office Uninstall terminato.'
        'toolText.operationCompleted' = 'Operazione completata.'
        'toolText.operationsCompletedSuccessfully0' = 'Operazioni completate con successo: {0}.'
        'toolText.packetVerificationError01' = 'Errore verifica pacchetto {0}: {1}'
        'toolText.pendingOperationsRequiringRebootDetectedDismCouldFail' = 'Rilevate operazioni pendenti che richiedono riavvio. DISM potrebbe fallire.'
        'toolText.performingAWindowsUpdateClientReset' = 'Esecuzione reset client Windows Update...'
        'toolText.persistentErrorsDetectedStartDeepRepair' = 'Rilevati errori persistenti. Avvio riparazione profonda.'
        'toolText.planActivated' = 'Piano attivato.'
        'toolText.planCreated' = 'Piano creato.'
        'toolText.planCreationError' = 'Errore creazione piano.'
        'toolText.policyUpdate' = 'Aggiornamento criteri.'
        'toolText.preparingArchiveCompression' = 'Preparazione compressione archivio.'
        'toolText.preparingToDownloadTheNecessaryTools' = 'Preparazione download strumenti necessari...'
        'toolText.pressAnyKeyToContinue' = 'Premi un tasto per continuare.'
        'toolText.pressAnyKeyToExit' = 'Premere un tasto per uscire.'
        'toolText.profileExcludedDueToTimeThreshold0LastUse1' = 'Profilo escluso per soglia temporale: {0}, ultimo uso {1}.'
        'toolText.profilePath0' = 'Percorso profili: {0}'
        'toolText.rebootRequiredForDeepRepair' = 'Riavvio necessario per riparazione profonda.'
        'toolText.rebootTheSystemToCompletePendingOperations' = 'Riavviare il sistema per completare le operazioni in sospeso.'
        'toolText.recommendedReboot0' = 'Riavvio consigliato: {0}'
        'toolText.registeredProfilesRemoved0' = 'Profili registrati rimossi: {0}'
        'toolText.registeredProfilesSelectedForAutomaticRemoval' = 'Profili registrati selezionati per la rimozione automatica:'
        'toolText.registryEntryRemovedForSid01' = 'Voce del registro rimossa per SID: {0} ({1}).'
        'toolText.rehabilitationOfScheduledTasks' = 'Riabilitazione task pianificati.'
        'toolText.reinstallation0' = 'Reinstallazione: {0}.'
        'toolText.reinstalled0' = 'Reinstallato: {0}.'
        'toolText.reinstallingMicrosoftStore' = 'Reinstallazione Microsoft Store in corso.'
        'toolText.reinstallingXboxGameBarApp' = 'Reinstallazione Xbox Game Bar & App.'
        'toolText.remainingFolderCleanupSkipped' = 'Pulizia cartelle residue saltata.'
        'toolText.remnantFolderRemovalFailed01' = 'Rimozione cartella residua fallita: {0} - {1}'
        'toolText.removalNotCompleted' = 'Rimozione non completata.'
        'toolText.removalViaGetHelp' = 'Rimozione tramite Get Help.'
        'toolText.removed0' = 'Rimosso: {0}'
        'toolText.removed02' = 'Rimosso: {0}.'
        'toolText.removingOffice' = 'Rimozione Office'
        'toolText.removingOfficeLinks' = 'Rimozione collegamenti Office.'
        'toolText.removingOldArchive' = 'Rimozione archivio precedente.'
        'toolText.removingPreviousBackups' = 'Rimozione backup precedenti.'
        'toolText.repairCompletedSuccessfully' = 'Riparazione completata con successo!'
        'toolText.repairOfficeSessionEnded' = 'Repair-Office sessione terminata.'
        'toolText.resetWaasmedicsvcSettings' = 'Ripristino impostazioni WaaSMedicSvc.'
        'toolText.resetWindowsLocalPolicies' = 'Ripristino criteri locali Windows.'
        'toolText.resetWindowsUpdateRegistrySettings' = 'Ripristino impostazioni registro Windows Update.'
        'toolText.resetWindowsUpdateSettings' = 'Ripristino impostazioni Windows Update.'
        'toolText.resetWingetUnhandledException0' = 'Reset-Winget eccezione non gestita: {0}'
        'toolText.residualFolderCleanupSkippedForSkipresidualfoldercleanupParameter' = 'Pulizia cartelle residue saltata per parametro SkipResidualFolderCleanup.'
        'toolText.residualFolderExcludedBecauseItIsStillAssociatedWithWin32Userprofile01' = 'Cartella residua esclusa perché ancora associata a Win32_UserProfile: {0} ({1}).'
        'toolText.residualFolderExcludedBecauseReparsePointSymlink01' = 'Cartella residua esclusa perché reparse point/symlink: {0} ({1}).'
        'toolText.residualFolderExcludedBecauseSidStillRegistered01' = 'Cartella residua esclusa perché il SID è ancora registrato in ProfileList: {0} ({1}).'
        'toolText.residualFolderExcludedForProtectedName01' = 'Cartella residua esclusa per nome protetto: {0} ({1}).'
        'toolText.residualFoldersRemoved0' = 'Cartelle residue rimosse: {0}'
        'toolText.residualFoldersSelectedForAutomaticRemoval0' = 'Cartelle residue selezionate per la rimozione automatica: {0}'
        'toolText.resourceCleanupAndWindebloatSessionShutdown' = 'Pulizia risorse e chiusura sessione WinDebloat.'
        'toolText.resourceCleanupCompleted' = 'Pulizia risorse completata.'
        'toolText.restartMicrosoftStoreServices' = 'Restart servizi Microsoft Store.'
        'toolText.restartNotRequired' = 'Riavvio non necessario.'
        'toolText.restartRecommendedBeforePerformingRepairs' = 'Consigliato riavviare prima di eseguire le riparazioni.'
        'toolText.restartRecommendedToCompleteCleanupOfUnremovedProfiles' = 'Riavvio consigliato per completare la pulizia dei profili non rimossi.'
        'toolText.restorationOfUpdateServices' = 'Ripristino servizi di update.'
        'toolText.restoringRenamedDlls' = 'Ripristino DLL rinominate.'
        'toolText.restoringWindowsUpdateRegistryKeys' = 'Ripristino chiavi di registro Windows Update.'
        'toolText.reverted0BakDllTo1Dll' = 'Ripristinato {0}_BAK.dll a {1}.dll.'
        'toolText.ruleExecution' = 'Esecuzione regole'
        'toolText.runspaceError0' = 'Errore runspace: {0}'
        'toolText.runtimesCompleted' = 'Runtime completati.'
        'toolText.safeModeConfigurationError0' = 'Errore configurazione Safe Mode: {0}.'
        'toolText.safeModeConfiguredForNextBoot' = 'Modalità provvisoria configurata per il prossimo avvio.'
        'toolText.scanningRegisteredLocalProfiles' = 'Scansione profili locali registrati in corso.'
        'toolText.searchForOfficeInstallations' = 'Ricerca installazioni Office.'
        'toolText.searchTheRegistry' = 'Ricerca nel registro.'
        'toolText.send0DesktopViaTelegramHttpsTMeMagnetarmanOrEmailMeMagnetarmanComForDiagnostics' = 'Invia ''{0}'' (Desktop) via Telegram [https://t.me/MagnetarMan] o email [me@magnetarman.com] per la diagnostica.'
        'toolText.service0OptimizedSuccessfully' = 'Servizio {0} ottimizzato correttamente.'
        'toolText.serviceOptimization01' = 'Ottimizzazione servizio: {0} ({1}).'
        'toolText.servicesRegistryAndPoliciesHaveBeenConfiguredSuccessfully' = 'Servizi, registro e criteri sono stati configurati correttamente.'
        'toolText.serviceStopped0' = 'Servizio arrestato: {0}.'
        'toolText.sessionCompletedProfilesRemoved0ResidualFoldersRemoved1Errors2Duration3' = 'Sessione completata. Profili rimossi: {0}. Cartelle residue rimosse: {1}. Errori: {2}. Durata: {3}.'
        'toolText.sessionStartedOn0' = 'Sessione avviata su {0}.'
        'toolText.setupComplete' = 'Configurazione completata.'
        'toolText.sfcLogSavedIn0' = 'Log SFC salvato in: {0}'
        'toolText.sourceUpdateError0' = 'Errore aggiornamento sorgenti: {0}.'
        'toolText.stableDriverDownloadedToDesktop0' = 'Driver stabile scaricato sul desktop: {0}'
        'toolText.standardFolderCleanupFailed01' = 'Pulizia standard cartella fallita: {0} - {1}.'
        'toolText.standardResidualFolderRemovalFailed01' = 'Rimozione standard cartella residua fallita: {0} - {1}'
        'toolText.startAutomaticRemovalOf0RegisteredProfiles' = 'Avvio rimozione automatica di {0} profili registrati.'
        'toolText.startDeepRepairOfDiskCOnNextReboot' = 'Avvio riparazione profonda del disco C: al prossimo riavvio.'
        'toolText.startingAutomaticVideoDriverInstallation' = 'Avvio installazione automatica driver video.'
        'toolText.startingCompleteMicrosoftOfficeRemoval' = 'Avvio rimozione completa Microsoft Office.'
        'toolText.startingInstallationProcess' = 'Avvio processo installazione.'
        'toolText.startingOfficeBasicInstallation' = 'Avvio installazione Office Basic.'
        'toolText.startingOfficeDirectRemoval' = 'Avvio rimozione diretta Office.'
        'toolText.startingOfficeRepair' = 'Avvio riparazione Office.'
        'toolText.startingRemovalOfResidualFolders' = 'Avvio rimozione cartelle residue.'
        'toolText.startingServiceDebloatProcess' = 'Avvio processo di debloat dei servizi.'
        'toolText.startingStoreWingetReinstallation' = 'Avvio reinstallazione Store & Winget.'
        'toolText.startingVideoDriverReinstallationRepairProcedure' = 'Avvio procedura reinstallazione/riparazione driver video.'
        'toolText.startingWindowsUpdateServicesRepair' = 'Avvio riparazione servizi Windows Update.'
        'toolText.startOfEssentialServices' = 'Avvio servizi essenziali.'
        'toolText.startResidualFolder01' = 'AVVIO CARTELLA RESIDUO - {0} - {1}'
        'toolText.stoppingOfficeServices' = 'Arresto servizi Office.'
        'toolText.storeCacheReset' = 'Cache dello Store ripristinata.'
        'toolText.summary0Folders1RegistryKeys2Links3TasksRemoved' = 'Riepilogo: {0} cartelle, {1} chiavi registro, {2} collegamenti, {3} attività rimosse.'
        'toolText.summaryOfOperations' = 'RIEPILOGO OPERAZIONI'
        'toolText.systemDetected0TheScriptIsDesignedForWindows11' = 'Sistema rilevato: {0}. Lo script è pensato per Windows 11.'
        'toolText.systemHealthyDeepRepairNotNecessary' = 'Sistema in salute. Riparazione profonda non necessaria.'
        'toolText.systemInitialization' = 'Inizializzazione sistema.'
        'toolText.systemOptimizedForGaming' = 'Sistema ottimizzato per il gaming.'
        'toolText.taskEnabled0' = 'Task abilitato: {0}.'
        'toolText.telemetryAndPrivacyOfficeDisabled' = 'Telemetria e Privacy Office disabilitate.'
        'toolText.temporaryEnvironmentCleaning' = 'Pulizia ambiente temporaneo.'
        'toolText.theLogsFolder0WasNotFoundUnableToExport' = 'La cartella dei log ''{0}'' non è stata trovata. Impossibile esportare.'
        'toolText.theSystemRequiresARebootToApplyAllChanges' = 'Il sistema necessita di un riavvio per applicare tutte le modifiche.'
        'toolText.thisOperationMayTakeAFewMinutes' = 'Questa operazione può richiedere alcuni minuti.'
        'toolText.threadsConfigured0' = 'Thread configurati: {0}'
        'toolText.tipSomeFilesMayBeRecreatedAfterReboot' = 'Suggerimento: Alcuni file potrebbero essere ricreati dopo il riavvio.'
        'toolText.totalSize0Mb' = 'Dimensione totale: {0} MB'
        'toolText.unableToActivatePlan' = 'Impossibile attivare piano.'
        'toolText.unableToCheckBitlockerStatus0' = 'Impossibile verificare lo stato BitLocker: {0}'
        'toolText.unableToCompletelyDelete0FileInUse' = 'Impossibile eliminare completamente {0} - file in uso.'
        'toolText.unableToDetectWindowsVersion0' = 'Impossibile rilevare versione Windows: {0}'
        'toolText.unableToDownloadAmdInstallerAnnulment' = 'Impossibile scaricare installer AMD. Annullamento.'
        'toolText.unableToDownloadDduAnnulment' = 'Impossibile scaricare DDU. Annullamento.'
        'toolText.unableToDownloadNvcleanstallAnnulment' = 'Impossibile scaricare NVCleanstall. Annullamento.'
        'toolText.unableToMarkDiskDirtyFsutil' = 'Impossibile marcare il disco come dirty (fsutil).'
        'toolText.unableToReinstallMicrosoftStoreViaAutomaticMethods' = 'Impossibile reinstallare Microsoft Store tramite metodi automatici.'
        'toolText.unableToRemove0FoldersMayBeInUse' = 'Impossibile rimuovere {0} cartelle (potrebbero essere in uso).'
        'toolText.unexpectedErrorDuringResetWinget0' = 'Errore imprevisto durante Reset-Winget: {0}.'
        'toolText.unigetUiInstallation' = 'Installazione UniGet UI.'
        'toolText.unigetUiInstallationFinishedWithCode0' = 'Installazione UniGet UI terminata con codice: {0}.'
        'toolText.unigetUiInstalled' = 'UniGet UI installato.'
        'toolText.unigetUiInstalledSuccessfully' = 'UniGet UI installato correttamente.'
        'toolText.unigetUiRequireManualVerification' = 'UniGet UI richiedere verifica manuale.'
        'toolText.uninstallOfficeSessionEnded' = 'Uninstall-Office sessione terminata.'
        'toolText.unknownErrorZipFileWasNotCreated' = 'Errore sconosciuto: il file ZIP non è stato creato.'
        'toolText.unlimitedPasswordExpirationSetting' = 'Impostazione scadenza password illimitata.'
        'toolText.updatedCriteria' = 'Criteri aggiornati.'
        'toolText.updatedGroupPolicy' = 'Criteri di gruppo aggiornati.'
        'toolText.updatedSources' = 'Sorgenti aggiornate.'
        'toolText.usingDirectRemovalForWindows1122h2OrEarlier' = 'Utilizzo rimozione diretta per Windows 11 22H2 o precedenti.'
        'toolText.usingGetHelpMethodForWindows1123h2' = 'Utilizzo metodo Get Help per Windows 11 23H2+.'
        'toolText.versionDetected0' = 'Versione rilevata: {0}.'
        'toolText.videoDriverReinstallFinished' = 'Video Driver Reinstall terminato.'
        'toolText.videodriverreinstallSessionEnded' = 'VideoDriverReinstall sessione terminata.'
        'toolText.waasmedicsvcSettingsReset' = 'Impostazioni WaaSMedicSvc ripristinate.'
        'toolText.waitingForResourcesToBeReleased' = 'Attesa liberazione risorse.'
        'toolText.warningFailedToDeleteGpcacheCache0' = 'Avviso: Impossibile eliminare cache GPCache - {0}.'
        'toolText.warningFailedToRemoveWsusSettings0' = 'Avviso: Impossibile rimuovere impostazioni WSUS - {0}.'
        'toolText.warningFailedToRepair0Dll1' = 'Avviso: Impossibile ripristinare {0}.dll - {1}.'
        'toolText.warningFailedToRestoreWaasmedicsvc0' = 'Avviso: Impossibile ripristinare WaaSMedicSvc - {0}.'
        'toolText.warningTheSystemWillRebootIntoSafeMode' = 'ATTENZIONE: Il sistema si riavvierà in modalità provvisoria.'
        'toolText.warningTheSystemWillRestartAutomatically' = 'Attenzione: il sistema verrà riavviato automaticamente.'
        'toolText.warningUnableToEnableAutomaticRestart0' = 'Avviso: Impossibile abilitare riavvio automatico - {0}.'
        'toolText.warningUnableToEnableDriver0' = 'Avviso: Impossibile abilitare driver - {0}.'
        'toolText.warningUnableToEnableTaskIn01' = 'Avviso: Impossibile abilitare task in {0} - {1}.'
        'toolText.warningUnableToResetSomePolicies0' = 'Avviso: Impossibile ripristinare alcuni criteri - {0}.'
        'toolText.warningUnableToResetSomeSettings0' = 'Avviso: Impossibile ripristinare alcune impostazioni - {0}.'
        'toolText.warningUnableToRestoreService01' = 'Avviso: Impossibile ripristinare servizio {0} - {1}.'
        'toolText.warningUnableToRestoreSomeRegistryKeys0' = 'Avviso: Impossibile ripristinare alcune chiavi di registro - {0}'
        'toolText.wevtutilCl01' = 'Wevtutil cl [{0}]: {1}'
        'toolText.wevtutilSlOutput0' = 'uscita wevtutil sl: {0}'
        'toolText.winbackupdriverSessionEnded' = 'WinBackupDriver sessione terminata.'
        'toolText.windebloatSessionEnded' = 'WinDebloat sessione terminata.'
        'toolText.winDeleteUserProfilesSessionEnded' = 'WinDeleteUserProfiles sessione terminata.'
        'toolText.windowsBuiltInDriversAreNotExported' = 'I driver integrati di Windows non vengono esportati.'
        'toolText.windowsLocalPoliciesRestored' = 'Criteri locali Windows ripristinati.'
        'toolText.windowsUpdateAutomaticRestartEnabled' = 'Riavvio automatico Windows Update abilitato.'
        'toolText.windowsUpdateClientResetNotCompletedPossibleTimeout' = 'Reset client Windows Update non completato (possibile timeout).'
        'toolText.windowsUpdateClientResetSuccessfully' = 'Client Windows Update reimpostato correttamente.'
        'toolText.windowsUpdateHasBeenRestoredToDefaultValues' = 'Windows Update è stato RIPRISTINATO ai valori predefiniti!'
        'toolText.windowsUpdateRegistrySettingsReset' = 'Impostazioni registro Windows Update ripristinate.'
        'toolText.windowsUpdateServicesReset' = 'Ripristino configurazione servizi Windows Update.'
        'toolText.windowsUpdateServicesStopping' = 'Arresto servizi Windows Update.'
        'toolText.windowsUpdateSettingsReset' = 'Impostazioni Windows Update ripristinate.'
        'toolText.windowsUpdateShouldNowWorkNormally' = 'Windows Update dovrebbe ora funzionare normalmente.'
        'toolText.windowsVersionDetection' = 'Rilevamento versione Windows.'
        'toolText.winexportlogSessionEnded' = 'WinExportLog sessione terminata.'
        'toolText.wingetAvailable' = 'Winget disponibile.'
        'toolText.wingetNotAvailableStartingAutomaticRecovery' = 'Winget non disponibile. Avvio ripristino automatico...'
        'toolText.wingetNotAvailableUnigetUiRequiresWinget' = 'Winget non disponibile. UniGet UI richiede Winget.'
        'toolText.wingetRestoredAndOperational' = 'Winget ripristinato e operativo.'
        'toolText.wingetRestoreFailed' = 'Ripristino Winget fallito.'
        'toolText.wingetRestoreFailedUnableToProceedWithGamingToolkit' = 'Ripristino Winget fallito. Impossibile procedere con Gaming Toolkit.'
        'toolText.wingetSourcesUpdate' = 'Aggiornamento sorgenti Winget.'
        'toolText.wsusSettingsNotPresent' = 'Impostazioni WSUS non presenti.'
        'toolText.wsusSettingsRemoved' = 'Impostazioni WSUS rimosse.'
        'toolText.xboxReinstalled' = 'Xbox reinstallati.'
        'toolText.youCanTryAnAlternativeMethodOrManualRemoval' = 'Puoi provare un metodo alternativo o rimozione manuale.'
        'uiText.01AttemptFailed2ILlTryAgain' = 'Tentativo {0}/{1} fallito: {2}. Riprovo...'
        'uiText.01Seconds' = '{0} - {1} secondi'
        'uiText.0CompletedWithErrors1' = '{0} completato con errori: {1}.'
        'uiText.0Discontinued' = '{0} interrotto.'
        'uiText.0Failed1' = '{0} fallito: {1}.'
        'uiText.0In1' = '{0} in {1}'
        'uiText.0In12' = '{0} in {1}: {2}'
        'uiText.0In1Seconds' = '{0} tra {1} secondi'
        'uiText.0IsEmptyUsingFallbackStaticMenu' = '\{0} è vuoto, utilizzando il menu statico di fallback.'
        'uiText.0NotFoundAfterLoading' = '\{0} non trovato dopo il caricamento.'
        'uiText.0OfficeProcessesClosed' = '{0} processi Office chiusi.'
        'uiText.addingStoreViaDism' = 'Aggiunta Store via DISM'
        'uiText.advancedInstallationViaMicrosoftWingetClientModule' = 'Installazione avanzata tramite modulo Microsoft.WinGet.Client.'
        'uiText.andSaveItIn0' = 'e salvalo in: {0}.'
        'uiText.appxInstallFailed01' = 'Installazione di AppX non riuscita ({0}): {1}'
        'uiText.appxManifestStoreRegistration' = 'Registrazione AppX Manifest Store'
        'uiText.archiveCopyFailed' = 'Copia dell''archivio non riuscita.'
        'uiText.asset0NotFound' = 'Asset ''{0}'' non trovato.'
        'uiText.assetUrlRetrievalError0' = 'Errore recupero URL asset: {0}.'
        'uiText.attemptingNativeAppxInstallFromBundle' = 'Provo installazione nativa Appx da bundle scaricato.'
        'uiText.attemptingPackageManagerRepair' = 'Tentativo Repair-WinGetPackageManager.'
        'uiText.attemptingToInstallPowershell7ViaWinget' = 'Tentativo installazione PowerShell 7 via Winget.'
        'uiText.attemptingToInstallWindowsTerminalViaWinget' = 'Tentativo installazione Windows Terminal via winget.'
        'uiText.attemptingWingetRepairViaPackageManager' = 'Tentativo di riparazione Winget (Repair-WinGetPackageManager).'
        'uiText.attentionGitHasNotBeenInstalledOrItMayNotWorkProperly' = 'Attenzione: Git non è stato installato oppure potrebbe non funzionare correttamente.'
        'uiText.automaticStartToolkitLogInjectionPolicy0' = 'Politica: inserimento automatico di Start-ToolkitLog per {0}.'
        'uiText.battleNetInstalled' = 'Battle.net installato.'
        'uiText.browserOpenForReportingOnGithub' = 'Browser aperto per la segnalazione su GitHub.'
        'uiText.buildCompletedWithMinorAnomaliesOrSkippedModules' = 'La build è stata completata con anomalie minori o moduli saltati.'
        'uiText.bypassedUserConfirmationFor0DefaultResponseYes' = 'Conferma utente bypassata per: ''{0}''. Risposta predefinita ''Sì''.'
        'uiText.cached0' = 'Salvato in cache: {0}.'
        'uiText.cannotGetParametersForFunction01' = 'Impossibile ottenere i parametri per la funzione ''{0}'': {1}.'
        'uiText.carryingOutBasicChecks' = 'Esecuzione controlli base.'
        'uiText.check0' = 'Verifica {0}.'
        'uiText.checkboxReadingError0' = 'Errore lettura checkbox: {0}.'
        'uiText.checkForJetbrainsmonoNerdFont' = 'Verifica presenza JetBrainsMono Nerd Font.'
        'uiText.checkingMicrosoftAppInstallerPackage' = 'Verifica del pacchetto Microsoft.AppInstaller.'
        'uiText.checkingPowershell7' = 'Verifica PowerShell 7.'
        'uiText.checkWingetFunctionality' = 'Verifica funzionalità Winget.'
        'uiText.chromePolicySet01' = 'Policy Chrome impostata: {0} = {1}'
        'uiText.classicAndModernEventLogsDeleted' = 'Event Log classici e moderni cancellati.'
        'uiText.cleanedValuesIn0' = 'Puliti valori in {0}'
        'uiText.cleanWininetWebcache' = 'Cache WinInet/WebCache pulita.'
        'uiText.clearingWingetCache' = 'Pulizia cache Winget.'
        'uiText.closingInterferingProcesses' = 'Chiusura processi interferenti.'
        'uiText.closingOfficeProcesses' = 'Chiusura processi Office.'
        'uiText.command0ExitCode1Duration2' = 'Comando {0} (Codice di uscita: {1}, Durata: {2})'
        'uiText.commandContext' = 'Contesto del comando'
        'uiText.commandOutput0' = 'Uscita di comando ({0})'
        'uiText.compatibleSystemRecentWin1110' = 'Sistema compatibile (Win11/10 recente).'
        'uiText.compatibleSystemWin10' = 'Sistema compatibile (Win10).'
        'uiText.completed' = 'Completato'
        'uiText.completed0' = 'Completato: {0}.'
        'uiText.completeOfficeRepairOnline' = 'Riparazione Completa Office (Online)'
        'uiText.compressArchiveNotAvailableGuiReportSavedIn0' = 'Compress-Archive non disponibile. Report GUI salvato in: {0}.'
        'uiText.configurationComplete' = 'Configurazione completata.'
        'uiText.consoleMinimized' = 'Console ridotta a icona.'
        'uiText.continuingBuildWithoutMinification' = 'Continuare a costruire senza minimizzare.'
        'uiText.coreForJob0' = 'Base per il lavoro: {0}.'
        'uiText.coreScriptDownloadedSuccessfully' = 'Core Script scaricato con successo.'
        'uiText.coreScriptNotFoundAt0WithinJob' = 'Script principale non trovato in {0} all''interno del lavoro.'
        'uiText.coreVersion0' = 'Versione principale: {0}.'
        'uiText.coreVersionDownloaded0' = 'Versione Core scaricata: {0}.'
        'uiText.coreVersionFromFallbackCache0' = 'Versione Core da cache fallback: {0}.'
        'uiText.couldNotCheckBitlockerStatus0' = 'Impossibile verificare lo stato di Bitlocker: {0}.'
        'uiText.couldNotConfigureExecutebutton' = 'Impossibile configurare ExecuteButton.'
        'uiText.couldNotGetLocalPathForEmoji0Skipping' = 'Impossibile ottenere il percorso locale per l''emoji ''{0}''. Saltare.'
        'uiText.couldNotLoadCategorysystemIcon' = 'Impossibile caricare l''icona CategorySystem.'
        'uiText.couldNotLoadExecutebuttonIcon' = 'Impossibile caricare l''icona ExecuteButton.'
        'uiText.couldNotLoadOutputlogIcon' = 'Impossibile caricare l''icona OutputLog.'
        'uiText.couldNotLoadSomeIcons0' = 'Impossibile caricare alcune icone: {0}.'
        'uiText.couldNotLoadTooliconimage0' = 'Impossibile caricare ToolIconImage: {0}.'
        'uiText.couldNotMinimizeConsoleNonCritical' = 'Impossibile minimizzare la console (non critico).'
        'uiText.countdownBypassed01Seconds' = 'Conto alla rovescia bypassato: ''{0}'' ({1} secondi).'
        'uiText.crashAccessViolationExitcode0RipristinoDatabase' = 'Arresto anomalo di ACCESS_VIOLATION (codice di uscita: {0}). Banca dati Ripristino.'
        'uiText.crashDetectedExitcode0AccessViolationAdvancedRecoveryAttempt' = 'Crash rilevato (ExitCode: {0} = ACCESS_VIOLATION). Tentativo ripristino avanzato.'
        'uiText.creatingWpfWindow' = 'Creazione della finestra WPF.'
        'uiText.criticalError0' = 'Errore critico: {0}.'
        'uiText.criticalErrorDuringSetup0' = 'Errore critico durante il setup: {0}.'
        'uiText.criticalErrorInReset0' = 'Errore critico nel reset: {0}'
        'uiText.criticalErrorWhileLoadingCore0' = 'ERRORE CRITICO durante caricamento Core: {0}.'
        'uiText.deepOptimizationOfMicrosoftOffice' = 'Ottimizzazione profonda di Microsoft Office.'
        'uiText.deepTestExecutionOfWingetSearchForPacketsOnTheNetwork' = 'Esecuzione test profondo di Winget (ricerca pacchetti in rete).'
        'uiText.deepTestFailedExitcode0Details1' = 'Test profondo fallito: ExitCode={0}. Dettagli: {1}.'
        'uiText.deepTestPassedWingetCommunicatesCorrectlyWithRepositories' = 'Test profondo superato: Winget comunica correttamente con i repository.'
        'uiText.deepValidationError0' = 'Errore validazione profonda: {0}.'
        'uiText.deepValidationFailedExitcode0Details1' = 'Validazione profonda fallita (ExitCode={0}). Dettagli: {1}'
        'uiText.deepValidationPassedWingetCommunicatesWithRepositories' = 'Validazione profonda superata: Winget comunica con i repository.'
        'uiText.defaultTerminalNotSupportedOnThisBuild' = 'Questa build di Windows non supporta l''impostazione del terminale predefinito: passaggio saltato.'
        'uiText.defenderActiveDisablePrompt0' = 'Windows Defender è attivo. Si consiglia di disattivare temporaneamente la protezione in tempo reale. Premi INVIO dopo averlo disattivato, oppure premilo di nuovo per continuare comunque ({0}/{1}).'
        'uiText.defenderActiveNonInteractive0' = 'Windows Defender è attivo. La protezione in tempo reale potrebbe causare il fallimento di alcune installazioni.'
        'uiText.defenderDisabledContinuing0' = 'Windows Defender è disattivato: si prosegue con l''installazione.'
        'uiText.defenderPressEnterAfterDisabling0' = 'Premi INVIO dopo aver disattivato Windows Defender, oppure premilo di nuovo per continuare comunque.'
        'uiText.defenderStillActiveContinuing0' = 'Windows Defender è ancora attivo: si prosegue comunque. Alcune installazioni potrebbero fallire.'
        'uiText.dependencyFound0' = 'Trovata dipendenza: {0}.'
        'uiText.desktopShortcutCreation' = 'Creazione scorciatoia desktop.'
        'uiText.detected0StableDriverMatchesFromDriveroverridesJson' = 'Rilevate {0} corrispondenze driver stabili da DriverOverrides.json.'
        'uiText.disablingBitlocker' = 'Disattivazione BitLocker'
        'uiText.dismExportFailedWithExitcode0' = 'Esportazione DISM non riuscita con ExitCode: {0}.'
        'uiText.dosvcNotRestoredKnownLimitation' = 'Servizio Windows Update dosvc (Ottimizzazione recapito) non è stato ripristinato: limite noto di Windows. Il setup prosegue.'
        'uiText.download0' = 'Scarica {0}...'
        'uiText.download02' = 'Scarica {0}'
        'uiText.downloadAndInstallWingetBundle' = 'Download e installazione Winget Bundle (con dipendenze).'
        'uiText.downloadCompleted0' = 'Download completato: {0}.'
        'uiText.downloadCoreScriptFromGitHub' = 'Scarica Core Script da GitHub.'
        'uiText.downloaded0' = 'Scaricato: {0}.'
        'uiText.downloadError0' = 'Errore download: {0}'
        'uiText.downloadFailed0' = 'Download fallito: {0}.'
        'uiText.downloadFailedAfter0Attempts1' = 'Download fallito dopo {0} tentativi: {1}.'
        'uiText.downloadIcon' = 'Scarica l''icona.'
        'uiText.downloadingIconFor0From1' = 'Icona di download per ''{0}'' da {1}.'
        'uiText.downloadMsixBundleFromMicrosoft' = 'Scarica MSIXBundle da Microsoft.'
        'uiText.downloadWingetDependencies' = 'Download dipendenze Winget dal repository ufficiale.'
        'uiText.doYouReallyThinkThisScriptCanDoAnythingForThisVersion' = 'Davvero pensi che questo script possa fare qualcosa per questa versione?'
        'uiText.doYouWantToTakeARiskYN' = 'Vuoi rischiare? [Y/N]'
        'uiText.driveroverridesJsonDownloadFailedUseLocalCacheIfAvailable' = 'Download DriverOverrides.json fallito, uso cache locale se disponibile.'
        'uiText.driveroverridesJsonNotFoundIn0' = 'DriverOverrides.json non trovato in {0}'
        'uiText.duration0' = 'Durata: {0}'
        'uiText.dynamicMenuGenerated0Categories' = 'Menu dinamico generato: {0} categorie.'
        'uiText.elevationSwitchedAccount0' = 'L''elevazione ha cambiato account: l''installazione avviata da {0} è in esecuzione come {1}. Profilo, tema e scorciatoia desktop vengono installati per {0}.'
        'uiText.emptyInputTryAgain' = 'Input vuoto. Riprova.'
        'uiText.emptyPrecompiledModule0InsertingDevelopmentStub' = 'Modulo precompilato vuoto: ''{0}''. Inserimento stub di sviluppo.'
        'uiText.ensuringAllRequiredIconsAreAvailableLocally' = 'Garantire che tutte le icone richieste siano disponibili localmente.'
        'uiText.environmentReadyForInstallation' = 'Ambiente pronto per l''installazione.'
        'uiText.error' = '[ERRORE]'
        'uiText.errorAdministratorPrivilegesRequired' = '[ERRORE] Sono richiesti privilegi di amministratore.'
        'uiText.errorDuring01' = 'Errore durante {0}: {1}'
        'uiText.errorDuringDatabaseRestore0' = 'Errore durante ripristino database: {0}.'
        'uiText.errorDuringDotSourcingCore0' = 'Errore durante dot-sourcing Core: {0}.'
        'uiText.errorDuringIconSynchronization0' = 'Errore durante la sincronizzazione delle icone: {0}.'
        'uiText.errorDuringInitializationLoaded0' = 'Errore durante inizializzazione Loaded: {0}.'
        'uiText.errorDuringWingetDeepTest0' = 'Errore durante il test profondo di Winget: {0}.'
        'uiText.errorDuringWingetTest0' = 'Errore durante test Winget: {0}.'
        'uiText.errorExecutingFunction0WithinJob1' = 'Errore durante l''esecuzione della funzione ''{0}'' all''interno del lavoro: {1}.'
        'uiText.errorFailedToCreateIconDirectory0' = '[ERRORE] Impossibile creare la directory delle icone: {0}.'
        'uiText.errorFailedToInitializeLogging0' = '[ERRORE] Impossibile inizializzare la registrazione. {0}.'
        'uiText.errorFailedToLoad01' = '[ERRORE] Impossibile caricare: {0} - {1}.'
        'uiText.errorGeneratingDynamicMenu0' = 'Errore durante la generazione del menu dinamico: {0}.'
        'uiText.errorInstallingFont0' = 'Errore durante l''installazione font: {0}.'
        'uiText.errorInterruptingJob0' = 'Errore durante l''interruzione del job: {0}.'
        'uiText.errorPreparingGuiLogs0' = 'Errore durante la preparazione dei log GUI: {0}.'
        'uiText.errorReadingLocalCacheVersion0' = 'Errore lettura versione cache locale: {0}.'
        'uiText.errorRestoringDatabase0' = 'Errore durante ripristino database: {0}.'
        'uiText.errorRestoringWinget0' = 'Errore durante il ripristino Winget: {0}.'
        'uiText.errors0' = 'Errori: {0}'
        'uiText.errorSendingLog0' = 'Errore invio log: {0}.'
        'uiText.errorStartingJob01' = 'Errore avvio job ''{0}'': {1}.'
        'uiText.errorUpdatingSystemInformation0' = 'Errore durante l''aggiornamento delle informazioni di sistema: {0}.'
        'uiText.exceptionInStartDeepdiskrepair' = 'Eccezione in Start-DeepDiskRepair'
        'uiText.exceptionWhileRunningExternalCommand' = 'Eccezione durante l''esecuzione del comando esterno'
        'uiText.executebuttonConfiguredWithPillShapedStyleAndPlayIcon' = 'ExecuteButton configurato con stile pill-shaped e icona Play.'
        'uiText.executing0Seconds' = 'Esecuzione in corso... ({0} secondi)'
        'uiText.execution0Sec' = 'Esecuzione: {0} sec'
        'uiText.existingProfileSaved0' = 'Profilo esistente salvato in {0}.'
        'uiText.failedToCreateWindow0' = 'Impossibile creare la finestra: {0}.'
        'uiText.failedToDotSourceCoreScriptWithinJob0' = 'Impossibile eseguire il dot-source dello script Core all''interno del lavoro: {0}.'
        'uiText.failedToDownloadIcon01' = 'Impossibile scaricare l''icona ''{0}'': {1}.'
        'uiText.failedToGetRemoteVersion0AForcedDownloadOrFallbackMayBeRequired' = 'Fallito recupero versione remota: {0}. Potrebbe essere necessario un download forzato o fallback.'
        'uiText.failedToInstallWingetClientModule0' = 'Impossibile installare modulo WinGet Client: {0}.'
        'uiText.failedToLoadOrDownloadWindowIcon0' = 'Impossibile caricare o scaricare l''icona della finestra: {0}.'
        'uiText.failedToRestart01' = 'Impossibile riavviare ''{0}'': {1}.'
        'uiText.failedToRetrieveSystemInformationFromCore' = 'Impossibile recuperare le informazioni di sistema da Core.'
        'uiText.failedToSetDefaultTerminal0' = 'Impossibile impostare terminale predefinito: {0}.'
        'uiText.fallbackAperturaMicrosoftStorePerWindowsTerminal' = 'Fallback: Apertura Microsoft Store per terminale Windows.'
        'uiText.fallbackDownloadGitFromGitHub' = 'Fallback: scarica Git da GitHub...'
        'uiText.fallbackDownloadMsixBundleDirect' = 'Fallback: Download MSIXBundle diretto da Microsoft.'
        'uiText.fatalErrorCoreScriptLoadingFailed' = 'ERRORE IRREVERSIBILE: caricamento dello script principale non riuscito.'
        'uiText.fileIgnored01' = 'File ignorato: {0} - {1}'
        'uiText.finalFile0Kb1Lines' = 'File finale: {0} KB ({1} righe)'
        'uiText.finalTestAfterReinstallation' = 'Test finale dopo reinstallazione.'
        'uiText.fontInstallationViaWingetQuickMethod' = 'Installazione font tramite WinGet (Metodo Rapido).'
        'uiText.forcedReinstallAppInstaller0' = 'Reinstallazione forzata del pacchetto Microsoft.DesktopAppInstaller.'
        'uiText.function0NotFoundAfterDotSourcingWithinJob' = 'Funzione ''{0}'' non trovata dopo il dot-sourcing all''interno del lavoro.'
        'uiText.functionDevelopmentInProgress' = 'Sviluppo delle funzioni in corso.'
        'uiText.functionsAvailableTuiMenuSuppressed' = 'Funzioni disponibili, menu TUI soppresso'
        'uiText.generatingDynamicMenuFromCore0' = 'Generazione del menu dinamico dal Core \{0}.'
        'uiText.getSysteminfoFunctionAvailable' = 'Funzione Get-SystemInfo disponibile.'
        'uiText.getSysteminfoFunctionNotFound' = 'Funzione Get-SystemInfo NON trovata!'
        'uiText.gitAlreadyInstalled' = 'Git già installato.'
        'uiText.gitInstallation' = 'Installazione Git...'
        'uiText.gitInstallationError0' = 'Errore installazione Git: {0}'
        'uiText.gitInstalledSuccessfully' = 'Git installato con successo.'
        'uiText.gitInstalledViaWinget' = 'Git installato via winget.'
        'uiText.gitIsAlreadyOperational' = 'Git è già operativo.'
        'uiText.gpuAnalysisErrorReadingWin32Videocontroller0' = 'Analisi GPU: errore durante lettura Win32_VideoController: {0}'
        'uiText.guiVersion0' = 'Versione GUI: {0}'
        'uiText.guiWindowClosedAttemptToStopTheJobInProgress' = 'Finestra GUI chiusa. Tentativo di fermare il job in corso.'
        'uiText.hostsFileModifiedBackupSaved0' = 'File hosts modificato; backup salvato in {0}.'
        'uiText.hostsFileResetOnlyOnSourceFailure0' = 'Le sorgenti WinGet o Store non sono raggiungibili: vengono rimosse le voci di hosts che le bloccano. Le voci di privacy che hai aggiunto tu vengono mantenute.'
        'uiText.httpError01' = 'Errore HTTP {0}: {1}'
        'uiText.iconAvailabilityCheckCompleted' = 'Verifica disponibilità icona completata.'
        'uiText.iInteractiveInputBypassedFor0DefaultChoiceY' = 'ℹ Input interattivo bypassato per: ''{0}''. Scelta predefinita ''Y''.'
        'uiText.importantWarning' = 'AVVERTENZA IMPORTANTE'
        'uiText.individualRestartSuppressedAFinalRebootWillBeHandled' = 'Riavvio individuale soppresso. Verrà gestito un riavvio finale.'
        'uiText.info' = '[INFORMAZIONI]'
        'uiText.infoAdministratorPrivilegesConfirmed' = '[INFO] Privilegi di amministratore confermati.'
        'uiText.infoLoggingInitializedTo0' = '[INFO] Registrazione inizializzata su {0}.'
        'uiText.initializationCompleteGuiReadyToUse' = 'INIZIALIZZAZIONE COMPLETATA - GUI pronta all''uso.'
        'uiText.installationFailedCode0' = 'Installazione fallita. Codice: {0}'
        'uiText.installationFailedCode02' = 'Installazione fallita. Codice: {0}.'
        'uiText.installingMicrosoftWingetClientModule' = 'Installazione modulo Microsoft.WinGet.Client.'
        'uiText.installingPowershell7InProgress' = 'Installazione PowerShell 7 in corso.'
        'uiText.installingVisualCRedistributable' = 'Installazione Visual C++ Redistributable...'
        'uiText.installingWingetMsixbundleWithDependencies' = 'Installazione Winget MSIXBundle (con dipendenze)...'
        'uiText.interactiveInputDetected0NotSupportedInGuiMode' = 'Input interattivo rilevato: {0} - Non supportato in modalità GUI.'
        'uiText.interferingProcessesClosed' = 'Processi interferenti chiusi.'
        'uiText.invalidChoiceEnterNumbersBetween0' = 'Scelta non valida. Inserisci numeri compresi tra {0}.'
        'uiText.invalidDriveroverridesJson0' = 'DriverOverrides.json non valido: {0}'
        'uiText.irreversibleFailureWritingFinalFile0' = 'Errore irreversibile durante la scrittura del file finale sul disco: {0}.'
        'uiText.jetbrainsmonoNerdFontAlreadyInstalled' = 'JetBrainsMono Nerd Font già installato.'
        'uiText.jobInProgressStoppedAndRemoved' = 'Job in corso fermato e rimosso.'
        'uiText.lifeProtectionActivated0' = 'PROTEZIONE VITALE ATTIVATA: {0}'
        'uiText.loadedDependencies' = 'Dipendenze caricate.'
        'uiText.loadingCoreFunctionsIntoMemoryGlobalScope' = 'Caricamento funzioni Core in memoria (Global Scope).'
        'uiText.loadingCoreScript' = 'Caricamento dello script principale.'
        'uiText.loadingForms' = 'Caricamento moduli'
        'uiText.localCacheExpiredAge0MinutesDownloadToUpdate' = 'Cache locale scaduta (età: {0} minuti). Download per aggiornare.'
        'uiText.localCoreVersionFound0Numeric1' = 'Versione Core locale trovata: {0} (Numerica: {1}).'
        'uiText.manifestReRegistrationAppxmanifestXmlPreventsLeaks' = 'Re-registrazione manifest: AppxManifest.xml previene leak.'
        'uiText.menuStructureLoadedCategories0' = 'Struttura del menu caricata (categorie: {0}).'
        'uiText.microsoftAppInstallerInstallationFailed' = 'Impossibile installare Microsoft.AppInstaller.'
        'uiText.microsoftAppInstallerNotFoundInstalling' = 'Microsoft.AppInstaller non trovato. Installazione in corso.'
        'uiText.microsoftAppInstallerPresentForcingUpdate' = 'Microsoft.AppInstaller già presente. Aggiornamento forzato all''ultima release.'
        'uiText.microsoftAppInstallerUpdated' = 'Microsoft.AppInstaller presente e aggiornato.'
        'uiText.microsoftAppInstallerUpdateError0' = 'Errore durante l''aggiornamento di Microsoft.AppInstaller: {0}.'
        'uiText.moduleStatistics' = 'STATISTICHE DEL MODULO'
        'uiText.moduloWingetClient0' = 'Client Modulo WinGet: {0}.'
        'uiText.monitoringTimerRestarted' = 'Timer monitoraggio riavviato.'
        'uiText.nerdFontsInstalledSuccessfully' = 'Nerd Fonts installati con successo.'
        'uiText.newCoreVersion0AvailableCurrent1DownloadInProgress' = 'Nuova versione Core ({0}) disponibile (attuale: {1}). Download in corso.'
        'uiText.noEndpointFoundInTemplateSkipping0' = 'Nessun endpoint trovato nel modello. Saltare: {0}.'
        'uiText.noGuiOrCoreLogFilesFoundForReporting' = 'Nessun file log della GUI o del Core trovato per la segnalazione.'
        'uiText.noKnownStableDriversFoundForTheDetectedGpus' = 'Nessun driver stabile conosciuto trovato per le GPU rilevate.'
        'uiText.noLocalCacheFoundForcedDownload' = 'Nessuna cache locale trovata. Download forzato.'
        'uiText.noPendingUpdatesDetected' = 'Nessun aggiornamento pendente rilevato'
        'uiText.noPs1ModulesFound0OperationCanceled' = 'Nessun modulo .ps1 trovato in {0}. Operazione annullata.'
        'uiText.noteFontsViaWingetRequireRestartingTerminalOrExplorerToBeVisible' = 'Nota: i font via WinGet richiedono il riavvio del Terminale (o di Explorer) per essere visibili.'
        'uiText.nugetProviderNotInstallable' = 'NuGet provider non installabile.'
        'uiText.officeOptimizedTelemetryPrivacyAndScheduledTasksRemoved' = 'Office ottimizzato: telemetria, privacy e task pianificati rimossi.'
        'uiText.ohMyPoshThemeDownloaded' = 'Tema Oh My Posh scaricato.'
        'uiText.ohMyPoshThemeDownloadFailed0' = 'Il tema Oh My Posh non è stato scaricato o validato in {0}.'
        'uiText.operationalWingetVersion0' = 'Winget operativo (versione: {0}).'
        'uiText.operationalWingetVersion02' = 'Winget operativo (versione: {0}).'
        'uiText.operationCompleted' = 'Operazione completata!'
        'uiText.pathAndWingetPermissionsUpdated' = 'PATH e permessi winget aggiornati.'
        'uiText.pendingRebootDetectedForWindowsUpdates' = 'Rilevato riavvio pendente per aggiornamenti Windows'
        'uiText.pendingSystemUpdatesHaveBeenDetected' = 'Sono stati rilevati aggiornamenti di sistema pendenti:'
        'uiText.persistentCrashAfterDatabaseRestore' = 'Crash persistente dopo ripristino database.'
        'uiText.persistentCrashStartingCompleteReinstallationOfWinget' = 'Crash persistente. Avvio reinstallazione completa Winget.'
        'uiText.phase1CompletedOperationalWinget' = 'Fase 1 completata. Winget operativo.'
        'uiText.phase1CoreRecoveryVcAppxDependenciesMsixbundle' = 'Fase 1: Ripristino Core (VC++, dipendenze AppX, MSIXBundle).'
        'uiText.phase1InsufficientStartingPhase2AdvancedRecovery' = 'Fase 1 insufficiente. Avvio Fase 2: Ripristino Avanzato.'
        'uiText.pleaseWaitOperationInProgress' = 'Attendere prego, operazione in corso.'
        'uiText.powershell0' = 'PowerShell: {0}.'
        'uiText.powershell7AlreadyInstalled' = 'PowerShell 7 già installato.'
        'uiText.powershell7InstallatoViaWinget' = 'PowerShell 7 installato tramite Winget.'
        'uiText.powershell7InstalledSuccessfully' = 'PowerShell 7 installato con successo.'
        'uiText.powershell7ProfileConfigured' = 'Profilo PowerShell 7 configurato.'
        'uiText.powershellInstallationError0' = 'Errore installazione PowerShell: {0}.'
        'uiText.powershellJob0StartedId1' = 'Job PowerShell ''{0}'' avviato (ID: {1}).'
        'uiText.preparation' = 'Preparazione'
        'uiText.preparingGuiErrorLogForReporting' = 'Preparazione log errori GUI per la segnalazione.'
        'uiText.preparingTheNextScript' = 'Preparazione prossimo script.'
        'uiText.pressAnyKeyToCancel' = 'Premi un tasto qualsiasi per annullare...'
        'uiText.pressEnterToExit' = 'Premere Invio per uscire'
        'uiText.previousInterruptionDetectedRestoringUpdateServices' = 'Rilevata una precedente interruzione: ripristino dello stato dei servizi Windows Update.'
        'uiText.proceedWithCaution' = 'PROCEDERE CON ATTENZIONE'
        'uiText.processed0' = 'Elaborato: {0}'
        'uiText.profileConfigurationError0' = 'Errore configurazione profilo: {0}.'
        'uiText.profileDirectoryUnavailable0' = 'Impossibile preparare la cartella del profilo PowerShell: {0}'
        'uiText.profileNotInstalled0' = 'Il profilo PowerShell non è stato installato in {0}.'
        'uiText.quickOfficeRepairOffline' = 'Riparazione Rapida Office (Offline)'
        'uiText.quickRecoveryFailedAttemptAdvancedSlowerMethod' = 'Ripristino veloce fallito. Tentativo metodo avanzato (più lento).'
        'uiText.quickRecoveryFailedAttemptForcedPackageReinstall' = 'WinGet continua a non funzionare: tento una reinstallazione forzata di Microsoft.DesktopAppInstaller e Microsoft.WinGet.Client.'
        'uiText.ram0Gb' = 'RAM: {0} GB'
        'uiText.rebootYourSystemAndThenRestartWintoolkitBeforeContinuing' = 'riavviare il sistema e poi riavviare WinToolkit prima di proseguire.'
        'uiText.reduction01LinesRemoved' = 'Riduzione: {0} % ({1} righe rimosse)'
        'uiText.reductionOffFlagMinifyNotDetected' = 'Riduzione: OFF (Flag -Minify non rilevato)'
        'uiText.reinstallation0' = 'Reinstallazione {0}'
        'uiText.remoteCoreScriptVersionRecovery' = 'Recupero versione Core Script remota.'
        'uiText.remoteCoreVersionDetected0Numeric1' = 'Versione Core remota rilevata: {0} (Numerica: {1}).'
        'uiText.repairModuleFailed0' = 'Modulo Riparazione fallito: {0}.'
        'uiText.repairOperationTimedOut' = 'Timeout: l''operazione ha superato il limite di tempo ed è stata terminata.'
        'uiText.repairWingetpackagemanagerCompletato' = 'Riparazione-WinGetPackageManager completata.'
        'uiText.repairWingetpackagemanagerCompletedHigherVersionAlreadyPresent' = 'Repair-WinGetPackageManager completato (versione superiore già presente).'
        'uiText.repairWingetpackagemanagerEseguito' = 'Repair-WinGetPackageManager eseguito.'
        'uiText.repairWingetpackagemanagerFallito0' = 'Errore di riparazione di WinGetPackageManager: {0}.'
        'uiText.repairWingetpackagemanagerIgnoredHigherVersionAlreadyPresent' = 'Repair-WinGetPackageManager ignorato (versione superiore già presente).'
        'uiText.repeatTestAfterDatabaseRestore' = 'Ripetizione test dopo ripristino database.'
        'uiText.reportCoreVersion0' = 'Versione principale: {0}'
        'uiText.reportDate0' = 'Data: {0}'
        'uiText.reRegisterManifestAppxmanifestXml' = 'Re-registrazione manifest: AppxManifest.xml.'
        'uiText.resetAppInstaller' = 'Reimposta il programma di installazione dell''app.'
        'uiText.resetClientUpdate' = 'Reimposta aggiornamento client'
        'uiText.resetPackageMicrosoftDesktopappinstaller' = 'Reset pacchetto Microsoft.DesktopAppInstaller.'
        'uiText.resetStatusFile0' = 'Reset file stato: {0}.'
        'uiText.resettingMicrosoftStoreCache' = 'Reimposta cache Microsoft Store (wsreset)'
        'uiText.resettingWindowsUpdateServices' = 'Ripristino servizi Windows Update.'
        'uiText.resetWingetSources' = 'Reset sorgenti Winget.'
        'uiText.resourceInitializationCoreScriptLoading' = 'INIZIALIZZAZIONE RISORSE - Caricamento Core Script.'
        'uiText.restoreCompletedButWingetMayNotWork' = 'Ripristino completato ma winget potrebbe non funzionare.'
        'uiText.retrieveUrlLatestReleaseOfWindowsTerminal' = 'Recupero URL ultima release di Windows Terminal.'
        'uiText.retrievingLatestPowershellRelease' = 'Recupero ultima versione di PowerShell.'
        'uiText.ripristinoDatabaseWinget' = 'Ripristino database Winget.'
        'uiText.runningCommand01Timeout2S' = 'Comando in esecuzione: {0} {1} (Timeout: {2}s)'
        'uiText.runningGitInstaller' = 'Esecuzione installer Git...'
        'uiText.runningPackageManagerRepair' = 'Esecuzione di Repair-WinGetPackageManager.'
        'uiText.schannelCipherReenabled0' = 'SCHANNEL cipher {0} riabilitato.'
        'uiText.schannelTls12ModeReactivated0' = 'SCHANNEL TLS 1.2 {0} riattivato.'
        'uiText.selectedScript0' = 'Script selezionato: {0}.'
        'uiText.sendSupportArchive0' = 'Invia l''archivio sul tuo desktop ({0}) a GitHub, descrivendo i problemi riscontrati per contribuire a migliorare lo strumento.'
        'uiText.serviceRestarted0' = 'Servizio riavviato: {0}.'
        'uiText.serviceStop0' = 'Arresto servizio: {0}...'
        'uiText.settingWindowsTerminalAsDefaultViaRegistry' = 'Impostazione Windows Terminal come predefinito via Registry.'
        'uiText.shortcutCreatedSuccessfully' = 'Scorciatoia creata con successo.'
        'uiText.shortcutCreationError0' = 'Errore creazione scorciatoia: {0}.'
        'uiText.skipped0' = 'Saltato: {0}'
        'uiText.sources0Kb1Lines' = 'Fonti: {0} KB ({1} righe)'
        'uiText.standardWindowsTerminalInstallationFailed0FallbackToTheMicrosoftStore' = 'Installazione Standard di Windows Terminal fallita: {0}. Fallback al Microsoft Store.'
        'uiText.startExecution0' = 'Avvio esecuzione: {0}.'
        'uiText.startingDownloadProcess' = 'Avvio download in corso...'
        'uiText.startingPowershellEnvironmentSetupPsp' = 'Avvio configurazione ambiente PowerShell (PSP).'
        'uiText.startingService0' = 'Avvio servizio: {0}...'
        'uiText.startingWingetAdvancedRepair' = 'Avvio riparazione avanzata Winget...'
        'uiText.startingWingetCoreRecoveryProcedure' = 'Avvio procedura di ripristino Winget (Core).'
        'uiText.startingWingetInstallVerification' = 'Avvio procedura installazione/verifica Winget.'
        'uiText.startingWinToolkitSetup' = 'Avvio configurazione Win Toolkit.'
        'uiText.startWingetDatabaseRecovery' = 'Avvio ripristino database Winget.'
        'uiText.storageAndCompression' = 'STOCCAGGIO E COMPRESSIONE'
        'uiText.success' = '[SUCCESSO]'
        'uiText.successLoaded0' = '[SUCCESSO] Caricato: {0}.'
        'uiText.supportLogPackageCreated0' = 'Pacchetto log supporto creato: {0}.'
        'uiText.system01' = 'Sistema: {0} ({1})'
        'uiText.systemClockResynced' = 'Orologio di sistema risincronizzato.'
        'uiText.systemInfoNotAvailable' = 'Info sistema non disponibili.'
        'uiText.systemInformationPanelUpdated3BlockLayout' = 'Pannello delle informazioni di sistema aggiornato (layout a 3 blocchi).'
        'uiText.systemNotSupportedByWingetWindows101709Required' = 'Sistema non supportato da Winget (richiesto Windows 10 1709+).'
        'uiText.systemRebootCancelled' = 'Riavvio del sistema annullato.'
        'uiText.systemRestartRequiredToCompleteUpdates' = 'È necessario riavviare il sistema per completare gli aggiornamenti'
        'uiText.takingOwnershipFor0' = 'Assunzione proprietà per {0}.'
        'uiText.templateFileNotFoundIn0' = 'File template non trovato in: {0}'
        'uiText.temporarilySuspendWindowsUpdateServicesToAvoidConflicts' = 'Sospensione temporanea servizi Windows Update per evitare conflitti.'
        'uiText.terminalSettingsUpdateError0' = 'Errore aggiornamento settings terminal: {0}.'
        'uiText.theGuiCannotContinueWithoutTheCoreScript' = 'La GUI non può continuare senza lo script principale.'
        'uiText.thisMayCauseMalfunctionsErrorsOrBehavior' = 'Questo potrebbe causare malfunzionamenti, errori o comportamenti'
        'uiText.timediffMeasure' = 'MISURA TIMEDIFF'
        'uiText.timeoutAfter0Seconds' = 'Timeout dopo {0} secondi.'
        'uiText.timeoutReachedAfter0SecondsProcessTermination' = 'Timeout raggiunto dopo {0} secondi, terminazione processo...'
        'uiText.tipManuallyDownloadWintoolkitPs1From' = 'Suggerimento: Scarica manualmente WinToolkit.ps1 da:'
        'uiText.toolsFolderNotFoundIn0' = 'Cartella tools non trovata in: {0}'
        'uiText.total0CheckboxesFound' = 'Trovati {0} checkbox totali.'
        'uiText.trashEmptied' = 'Cestino svuotato'
        'uiText.unableToCheckWindowsUpdateStatus0' = 'Impossibile verificare stato aggiornamenti Windows: {0}'
        'uiText.unableToClose0' = 'Impossibile chiudere: {0}.'
        'uiText.unableToDownloadCoreScriptAndNoCacheAvailableConfiguredForFallback' = 'Impossibile scaricare Core Script e nessuna cache disponibile/configurata per il fallback.'
        'uiText.unableToExtractNumericPartFromLocale0IAssume000ForComparison' = 'Impossibile estrarre la parte numerica dalla versione locale ''{0}''. Assumo 0.0.0 per confronto.'
        'uiText.unableToExtractNumericPartFromRemoteVersion0IAssume000ForComparison' = 'Impossibile estrarre la parte numerica dalla versione remota ''{0}''. Assumo 0.0.0 per confronto.'
        'uiText.unableToExtractOrInstallDependenciesFromTheOfficialZipError0' = 'Impossibile estrarre o installare le dipendenze dallo zip ufficiale. Errore: {0}.'
        'uiText.unableToExtractRemoteVersionFromCoreScriptIAssume000ForComparison' = 'Impossibile estrarre versione remota dal Core Script. Assumo 0.0.0 per confronto.'
        'uiText.unableToExtractVersionFromLocalCacheIAssume000ForComparison' = 'Impossibile estrarre la versione dalla cache locale. Assumo 0.0.0 per confronto.'
        'uiText.unableToExtractVersionFromNewlyDownloadedCore' = 'Impossibile estrarre versione dal Core appena scaricato.'
        'uiText.unableToInstallWindowsTerminalViaAnyAutomaticMethod' = 'Impossibile installare Windows Terminal tramite qualsiasi metodo automatico.'
        'uiText.unableToInstallWinget' = 'Impossibile installare Winget.'
        'uiText.unableToOpenBrowser0' = 'Impossibile aprire il browser: {0}.'
        'uiText.unableToSetPermissionsOn01' = 'Impossibile impostare permessi su ''{0}'': {1}.'
        'uiText.unableToStartExternalProcess' = 'Impossibile avviare il processo esterno.'
        'uiText.unexpectedBehaviorInSomeOrAllWintoolkitFeatures' = 'comportamento imprevisto in alcune o tutte le funzionalità di WinToolkit.'
        'uiText.unhandledException01' = 'ECCEZIONE NON GESTITA: {0} | {1}'
        'uiText.unknownErrorsOccurred' = 'Si sono verificati errori sconosciuti durante l''esecuzione dello script.'
        'uiText.updatedFolderPermissions0' = 'Permessi cartella aggiornati: {0}.'
        'uiText.updatedPath0' = 'PATH aggiornato: {0}.'
        'uiText.updateServicesRestored' = 'Servizi di aggiornamento ripristinati.'
        'uiText.updateServicesRestoreIncomplete0' = 'Ripristino servizi Windows Update incompleto: {0}'
        'uiText.updateServicesSuccessfullySuspended' = 'Servizi di aggiornamento sospesi correttamente.'
        'uiText.url0' = 'URL: {0}.'
        'uiText.userChoices0' = 'Scelte dell''utente: {0}'
        'uiText.userConfirmationPrompt0Response1' = 'Richiesta di conferma dell''utente: {0} | Risposta: {1}'
        'uiText.userScopeAligned0' = 'I tool installati durante l''installazione sono stati aggiunti al PATH di {0} ({1}). Apri un nuovo terminale per usarli.'
        'uiText.userScopeAlreadyAligned0' = 'Il PATH di {0} contiene già i tool installati.'
        'uiText.userScopeNotAligned0' = 'I tool sono stati installati nell''account elevato e non è stato possibile aggiungerli al PATH di {0} ({1}). Esegui di nuovo start.ps1 dalla tua sessione per installarli per il tuo utente.'
        'uiText.usingLocalCacheExpiredOrOlderButAvailableAsAFallback' = 'Utilizzo cache locale (scaduta o meno recente, ma disponibile) come fallback.'
        'uiText.validAndUpdatedLocalCacheV0CacheUsage' = 'Cache locale valida e aggiornata (v{0}). Utilizzo cache.'
        'uiText.vcRedistInstalled' = 'VC++ Redist installato.'
        'uiText.ver0Build1' = '{0} (Build {1})'
        'uiText.verifyGitInstallation' = 'Verifica installazione Git...'
        'uiText.visualCRedistributableAlreadyPresent' = 'Visual C++ Redistributable già presente.'
        'uiText.visualCRedistributableInstallation' = 'Installazione Visual C++ Redistributable.'
        'uiText.visualCRedistributableInstalled' = 'Visual C++ Redistributable installato.'
        'uiText.warn' = '[AVVISARE]'
        'uiText.warningInstallingSubsequentPackagesViaWingetMayFail' = 'Attenzione: l''installazione dei pacchetti successivi via Winget potrebbe fallire.'
        'uiText.weStronglyRecommendThatYouCompleteAllOngoingUpdates' = 'Si consiglia vivamente di completare tutti gli aggiornamenti in corso,'
        'uiText.windebloatToolkit' = 'Kit degli strumenti WinDebloat'
        'uiText.windowCreatedSuccessfully' = 'Finestra creata con successo.'
        'uiText.windows10Build0NonSupportaWinget' = 'La build di Windows 10 {0} non supporta Winget.'
        'uiText.windows81PartialCompatibility' = 'Windows 8.1: Compatibilità parziale.'
        'uiText.windowsTerminalAppxInstallationFailed' = 'Installazione di Windows Terminal Appx non riuscita.'
        'uiText.windowsTerminalAppxInstallationSuccessful' = 'Installazione Appx di Windows Terminal riuscita.'
        'uiText.windowsTerminalAssetMsixbundleNotFound' = 'Asset .msixbundle di Windows Terminal non trovato.'
        'uiText.windowsTerminalConfiguration' = 'Configurazione Windows Terminal.'
        'uiText.windowsTerminalInstallationInProgress' = 'Installazione Windows Terminal in corso.'
        'uiText.windowsTerminalInstalledViaWinget' = 'Windows Terminal installato via winget.'
        'uiText.windowsTerminalIsAlreadyInstalled' = 'Windows Terminal è già installato.'
        'uiText.windowsTerminalSetAsDefault' = 'Windows Terminal impostato come predefinito.'
        'uiText.windowsTerminalSettingsOverwrittenBackup0' = 'Impostazioni Windows Terminal sovrascritte con la versione distribuita; backup: {0}.'
        'uiText.windowsTerminalSettingsUpdated0' = 'Settings Windows Terminal aggiornati ({0}).'
        'uiText.windowsUpdateCacheCleared' = 'La cache di Windows Update è stata cancellata.'
        'uiText.windowsUpdateInstallationServiceCurrentlyRunning' = 'Servizio installazione aggiornamenti Windows attualmente in esecuzione'
        'uiText.windowsUpdateInstallationServiceIsRunning' = 'Il servizio di installazione degli aggiornamenti di Windows è in esecuzione'
        'uiText.windowsUpdateStatusCheck' = 'Controllo stato aggiornamenti Windows...'
        'uiText.wingetAdvancedInstallationError0' = 'Errore installazione avanzata Winget: {0}.'
        'uiText.wingetAlreadyOperationalNoRepairsNecessary' = 'Winget già operativo. Nessuna riparazione necessaria.'
        'uiText.wingetClientModuleInstalled' = 'Modulo WinGet Client installato.'
        'uiText.wingetCommandError0' = 'Errore comando Winget: {0}.'
        'uiText.wingetCoreInstallationFailed' = 'L''installazione di Winget Core non è riuscita.'
        'uiText.wingetCoreInstalled' = 'Winget Core installato.'
        'uiText.wingetCoreSuccessfullyInstalled' = 'Winget Core installato con successo.'
        'uiText.wingetDatabaseRestoredVersion0' = 'Database Winget ripristinato (versione: {0}).'
        'uiText.wingetDeepValidationConnectivityDatabaseIntegrity' = 'Validazione profonda Winget (connettività + integrità database).'
        'uiText.wingetDidNotRespondWithin0SecondsIContinueAnyway' = 'Winget non ha risposto entro {0} secondi. Proseguo comunque.'
        'uiText.wingetDoesnTRespondFastRecoveryAttemptCore' = 'Winget non risponde. Tentativo di ripristino veloce (Core).'
        'uiText.wingetInstallationFailedOrFailedExitcode0FallbackToDirectDownload' = 'Installazione Winget fallita o non riuscita (ExitCode: {0}). Fallback al download diretto.'
        'uiText.wingetInstallationForWindowsTerminalFailed' = 'Installazione Winget per Windows Terminal non riuscita.'
        'uiText.wingetInstallationForWindowsTerminalFailed0' = 'Installazione Winget per Windows Terminal fallita: {0}.'
        'uiText.wingetInstalledAndWorking' = 'Winget installato e funzionante.'
        'uiText.wingetInstalledDeepValidationWithAnomaliesPossibleNetworkOrDbProblems' = 'Winget installato. Validazione profonda con anomalie (possibili problemi di rete o DB).'
        'uiText.wingetIntegrityValidationInProgressTimeout0S' = 'Validazione integrità Winget in corso (timeout: {0} s)...'
        'uiText.wingetIsAlreadyOperational' = 'Winget è già operativo.'
        'uiText.wingetMsixBundleInstallationFailed' = 'Installazione Winget MSIX Bundle fallita.'
        'uiText.wingetMsixBundleInstallationSuccessful' = 'Installazione Winget MSIX Bundle riuscita.'
        'uiText.wingetNotFoundInPath' = 'Winget non trovato nel PATH.'
        'uiText.wingetNotFoundInSystem' = 'Winget non trovato nel sistema.'
        'uiText.wingetNotFunctionalAfterAllAttempts' = 'Winget non funzionale dopo tutti i tentativi.'
        'uiText.wingetNotSupportedOnWindows0' = 'Winget non supportato su Windows {0}.'
        'uiText.wingetNotYetReadyAttempt012SRemainWait' = 'Winget non ancora pronto (tentativo {0}/{1}, restano {2} s). Attesa...'
        'uiText.wingetPresentButNotRespondingCorrectlyExitcode0' = 'Winget presente ma non risponde correttamente (ExitCode: {0}).'
        'uiText.wingetReadyAndDatabaseUnlockedAttempt01' = 'Winget pronto e database sbloccato (tentativo {0}/{1}).'
        'uiText.wingetRestoredQuickly' = 'Winget ripristinato velocemente.'
        'uiText.wingetReturnedCode0TheFontMayRequireATerminalRestart' = 'WinGet ha restituito codice {0}. Il font potrebbe richiedere un riavvio del terminale.'
        'uiText.wingetRpcFailureDetected' = 'WinGet non è riuscito con errore 0x800706BA: il server di distribuzione di App Installer non è disponibile, quindi i pacchetti non possono essere installati.'
        'uiText.wingetRpcRecovered' = 'WinGet è stato ripristinato dopo la registrazione del pacchetto App Installer.'
        'uiText.wingetRpcRecoveryFailed' = 'WinGet resta inutilizzabile: il server di distribuzione di App Installer non è raggiungibile.'
        'uiText.wingetSuccessfullyRestoredAndTested' = 'Winget ripristinato e testato con successo.'
        'uiText.wintoolkitConfirmationBypassTagMessage0' = '[WINTOOLKIT_CONFIRMATION_BYPASS_TAG] Messaggio: {0}.'
        'uiText.wintoolkitCountdownBypassTagMessage0Seconds1' = '[WINTOOLKIT_COUNTDOWN_BYPASS_TAG] Messaggio: {0} | Secondi: {1}.'
        'uiText.wintoolkitInputBypassTagPrompt0' = '[WINTOOLKIT_INPUT_BYPASS_TAG] Richiesta: {0}'
        'uiText.wintoolkitIsReadyOnTheDesktop' = 'WinToolkit è Pronto sul Desktop!'
        'uiText.wintoolkitLoadedInLibraryMode' = 'WinToolkit caricato in modalità LIBRERIA'
        'uiText.wintoolkitProgressTagActivity0Status1Percent100' = '[WINTOOLKIT_PROGRESS_TAG] Attività: {0} | Stato: {1} | Percentuale: 100%.'
        'uiText.wintoolkitProgressTagActivity0Status1Percent2' = '[WINTOOLKIT_PROGRESS_TAG] Attività: {0} | Stato: {1} | Percentuale: {2}%.'
        'uiText.wintoolkitProgressTagActivity0Status1Percent2Icon3Spinner4' = '[WINTOOLKIT_PROGRESS_TAG] Attività: {0} | Stato: {1} | Percentuale: {2}% | Icona: {3} | Spinner: {4}.'
        'uiText.wintoolkitProgressTagActivity0Status1SecondiPercent2' = '[WINTOOLKIT_PROGRESS_TAG] Attività: {0} | Stato: {1} secondi. | Percentuale: {2}%.'
        'uiText.wintoolkitProgressTagActivity0StatusCompletedPercent100' = '[WINTOOLKIT_PROGRESS_TAG] Attività: {0} | Stato: Completato | Percentuale: 100%.'
        'uiText.wintoolkitProgressTagActivity0StatusInEsecuzionePercent1' = '[WINTOOLKIT_PROGRESS_TAG] Attività: {0} | Stato: In esecuzione. | Percentuale: {1}%.'
        'uiText.wintoolkitProgressTagActivity0StatusRunning1SecondsPercent2' = '[WINTOOLKIT_PROGRESS_TAG] Activity: {0} | Status: Esecuzione in corso. ({1} secondi) | Percent: {2}%.'
        'uiText.wintoolkitRawHostOutputTag0' = '[WINTOOLKIT_RAW_HOST_OUTPUT_TAG]{0}'
        'uiText.wintoolkitSessionTerminatedByUser' = 'Sessione WinToolkit terminata dall''utente.'
        'uiText.wintoolkitStyledMessageTag01' = '[WINTOOLKIT_STYLED_MESSAGE_TAG] {0}: {1}'
        'uiText.wintoolkitStyledMessageTagErrorErroreDurante01' = '[WINTOOLKIT_STYLED_MESSAGE_TAG][Errore] Errore durante {0}: {1}.'
        'uiText.wintoolkitStyledMessageTagInfoHeader0' = '[WINTOOLKIT_STYLED_MESSAGE_TAG] Informazioni: INTESTAZIONE: {0}.'
        'uiText.wintoolkitStyledMessageTagWarningTimeoutReachedAfter0SecondsTerminatingProcess' = '[WINTOOLKIT_STYLED_MESSAGE_TAG][Warning] Timeout raggiunto dopo {0} secondi, terminazione processo.'
        'verb.active' = 'Active'
        'verb.backup' = 'Backup'
        'verb.block' = 'Block'
        'verb.cancel' = 'Cancel'
        'verb.check' = 'Check'
        'verb.clean' = 'Clean'
        'verb.complete' = 'Complete'
        'verb.compress' = 'Compress'
        'verb.configure' = 'Configure'
        'verb.copy' = 'Copy'
        'verb.create' = 'Create'
        'verb.delete' = 'Delete'
        'verb.detect' = 'Detect'
        'verb.disable' = 'Disable'
        'verb.download' = 'Download'
        'verb.enable' = 'Enable'
        'verb.export' = 'Export'
        'verb.extract' = 'Extract'
        'verb.fail' = 'Fail'
        'verb.found' = 'Found'
        'verb.inactive' = 'Inactive'
        'verb.inProgress' = 'In progress'
        'verb.install' = 'Install'
        'verb.move' = 'Move'
        'verb.note' = 'Note'
        'verb.notFound' = 'Not found'
        'verb.notPresent' = 'Not present'
        'verb.notRequired' = 'Not required'
        'verb.operational' = 'Operational'
        'verb.prepare' = 'Prepare'
        'verb.present' = 'Present'
        'verb.reenable' = 'Re-enable'
        'verb.reinstall' = 'Reinstall'
        'verb.remove' = 'Remove'
        'verb.repair' = 'Repair'
        'verb.required' = 'Required'
        'verb.reset' = 'Reset'
        'verb.restart' = 'Restart'
        'verb.restore' = 'Restore'
        'verb.run' = 'Run'
        'verb.search' = 'Search'
        'verb.skip' = 'Skip'
        'verb.start' = 'Start'
        'verb.stop' = 'Stop'
        'verb.tip' = 'Tip'
        'verb.uninstall' = 'Uninstall'
        'verb.update' = 'Update'
        'verb.wait' = 'Wait'
        'verb.warning' = 'Warning'
    }
}
$Global:SourceTextPreparedLanguagesDir = $null
$Global:SourceTextKeyAliases = @{}
function Get-SourceTextLanguageDirectory {
    if ($Global:SourceTextPreparedLanguagesDir -and (Test-Path $Global:SourceTextPreparedLanguagesDir)) {
        return $Global:SourceTextPreparedLanguagesDir
    }
    $root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $candidate = Join-Path $root 'languages'
    if (Test-Path $candidate) { return $candidate }
    $repoCandidate = Join-Path (Get-Location) 'languages'
    if (Test-Path $repoCandidate) { return $repoCandidate }
    return $candidate
}
function Get-AvailableSourceTextLanguages {
    $languageDir = Get-SourceTextLanguageDirectory
    if (-not (Test-Path $languageDir)) { return @() }
    Get-ChildItem -Path $languageDir -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName 'WinToolkit.psd1') } |
    ForEach-Object {
        try {
            $data = Import-SourceTextLanguageFile -LanguageCode $_.Name
            [pscustomobject]@{
                Code         = if ($data.ContainsKey('language.code')) { $data['language.code'] } else { $_.Name }
                Name         = if ($data.ContainsKey('language.name')) { $data['language.name'] } else { $_.Name }
                NativeName   = if ($data.ContainsKey('language.nativeName')) { $data['language.nativeName'] } else { $_.Name }
                AiTranslated = if ($data.ContainsKey('language.aiTranslated')) { $data['language.aiTranslated'] -eq 'true' } else { $false }
                Path         = $_.FullName
            }
        }
        catch {
            Write-Verbose "Invalid language file '$($_.FullName)': $($_.Exception.Message)"
        }
    } | Sort-Object Code
}
function Import-SourceTextLanguageFile {
    param([string]$LanguageCode)
    if ($Global:SourceTextEmbeddedLanguageData -and $Global:SourceTextEmbeddedLanguageData.ContainsKey($LanguageCode)) {
        return $Global:SourceTextEmbeddedLanguageData[$LanguageCode].Clone()
    }
    $directories = @()
    if ($PSScriptRoot) {
        $directories += Join-Path $PSScriptRoot 'languages'
        if ((Split-Path $PSScriptRoot -Leaf) -eq 'wintoolkit-modules') {
            $directories += Join-Path (Split-Path $PSScriptRoot -Parent) 'languages'
        }
    }
    $directories += Join-Path (Get-Location).Path 'languages'
    $directories += Get-SourceTextLanguageDirectory
    foreach ($languageDir in ($directories | Select-Object -Unique)) {
        try {
            $localizedData = $null
            Import-LocalizedData -BindingVariable localizedData -BaseDirectory $languageDir -FileName 'WinToolkit.psd1' -UICulture $LanguageCode -ErrorAction Stop
            return $localizedData
        }
        catch {
            continue
        }
    }
    return $null
}
function Set-SourceTextLanguage {
    param([string]$LanguageCode = 'en-US')
    $defaultData = Import-SourceTextLanguageFile -LanguageCode 'en-US'
    if ($defaultData) { $Global:SourceTextDefaultLanguageData = $defaultData }
    $languageData = Import-SourceTextLanguageFile -LanguageCode $LanguageCode
    if (-not $languageData) {
        $LanguageCode = 'en-US'
        $languageData = $defaultData
    }
    if ($languageData) {
        $Global:SourceTextLanguage = $LanguageCode
        $Global:SourceTextLanguageData = $languageData
    }
}
function Get-SourceTextLoc {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Alias('Args')][object[]]$Arguments = @()
    )
    $k = $Key
    if ($Global:SourceTextKeyAliases -and $Global:SourceTextKeyAliases.ContainsKey($k)) {
        $k = $Global:SourceTextKeyAliases[$k]
    }
    $value = $null
    if ($Global:SourceTextLanguageData -and $Global:SourceTextLanguageData.ContainsKey($k)) {
        $value = [string]$Global:SourceTextLanguageData[$k]
    }
    elseif ($Global:SourceTextDefaultLanguageData -and $Global:SourceTextDefaultLanguageData.ContainsKey($k)) {
        $value = [string]$Global:SourceTextDefaultLanguageData[$k]
    }
    else {
        if ($k -match '^(.*?)(\d+)$') {
            $stem = $Matches[1]
            if ($Global:SourceTextLanguageData -and $Global:SourceTextLanguageData.ContainsKey($stem)) {
                $value = [string]$Global:SourceTextLanguageData[$stem]
            }
            elseif ($Global:SourceTextDefaultLanguageData -and $Global:SourceTextDefaultLanguageData.ContainsKey($stem)) {
                $value = [string]$Global:SourceTextDefaultLanguageData[$stem]
            }
        }
    }
    if ($null -eq $value) { $value = $Key }
    if ($null -ne $Arguments -and $Arguments.Count -gt 0) { return [string]::Format($value, $Arguments) }
    return $value
}
function Format-SourceText {
    [CmdletBinding()]
    param(
        [string]$Verb,
        [string]$Noun,
        [object[]]$Arguments = @()
    )
    $parts = @()
    if ($Verb) { $parts += (Get-SourceTextLoc "verb.$Verb") }
    if ($Noun) { $parts += (Get-SourceTextLoc "noun.$Noun") }
    $text = ($parts -join ' ').Trim()
    if ($Arguments -and $Arguments.Count -gt 0) { return [string]::Format($text, $Arguments) }
    return $text
}
function Get-SourceTextMenuText {
    param([object]$Item)
    if ($Item -is [System.Collections.IDictionary]) {
        if ($Item.Contains('DescriptionKey') -and $Item['DescriptionKey']) {
            return (Get-SourceTextLoc $Item['DescriptionKey'])
        }
        if ($Item.Contains('CategoryKey') -and $Item['CategoryKey']) {
            return (Get-SourceTextLoc $Item['CategoryKey'])
        }
        if ($Item.Contains('Description')) { return $Item['Description'] }
        if ($Item.Contains('Name')) { return $Item['Name'] }
    }
    if ($Item.PSObject.Properties.Name -contains 'DescriptionKey' -and $Item.DescriptionKey) {
        return (Get-SourceTextLoc $Item.DescriptionKey)
    }
    if ($Item.PSObject.Properties.Name -contains 'CategoryKey' -and $Item.CategoryKey) {
        return (Get-SourceTextLoc $Item.CategoryKey)
    }
    if ($Item.PSObject.Properties.Name -contains 'Description') { return $Item.Description }
    if ($Item.PSObject.Properties.Name -contains 'Name') { return $Item.Name }
    return [string]$Item
}
function Get-RemoteAvailableCultures {
    param([string]$GitHubApiUrl = "https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=$Branch")
    try {
        $response = Invoke-RestMethod -Uri $GitHubApiUrl -UseBasicParsing -ErrorAction Stop
        return @($response | Where-Object { $_.type -eq 'dir' } | ForEach-Object { $_.name })
    }
    catch {
        return @()
    }
}
function Invoke-SourceTextLanguagePruning {
    [CmdletBinding()]
    param(
        [string]$LocalDir,
        [string[]]$AllowedCultures
    )
    if (-not (Test-Path $LocalDir)) { return }
    $allowed = @('en-US') + @($AllowedCultures | Where-Object { $_ -and $_.Trim() })
    $allowed = @($allowed | Select-Object -Unique)
    if ($allowed.Count -le 1) { return }
    foreach ($dir in (Get-ChildItem -Path $LocalDir -Directory -ErrorAction SilentlyContinue)) {
        if ($allowed -notcontains $dir.Name) {
            try {
                Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction Stop
                Write-Verbose "Pruned obsolete language directory: $($dir.Name)"
            }
            catch {
                Write-Verbose "Failed to prune language directory '$($dir.FullName)': $($_.Exception.Message)"
            }
        }
    }
}
function Invoke-SourceTextLanguagePreparation {
    [CmdletBinding()]
    param(
        [string]$ScriptRoot,
        [string]$RemoteBaseUrl = "$RepoBase/languages",
        [string]$GitHubApiUrl = "https://api.github.com/repos/Magnetarman/WinToolkit/contents/languages?ref=$Branch"
    )
    $localDir = Join-Path $env:LOCALAPPDATA 'WinToolkit\languages'
    $remoteCultures = Get-RemoteAvailableCultures -GitHubApiUrl $GitHubApiUrl
    if ($remoteCultures.Count -le 0) { return $localDir }
    if (-not (Test-Path $localDir)) { New-Item -Path $localDir -ItemType Directory -Force | Out-Null }
    Invoke-SourceTextLanguagePruning -LocalDir $localDir -AllowedCultures $remoteCultures
    foreach ($culture in (@('en-US') + $remoteCultures | Select-Object -Unique)) {
        $cultureDir = Join-Path $localDir $culture
        $localFile = Join-Path $cultureDir 'WinToolkit.psd1'
        if (-not (Test-Path $cultureDir)) { New-Item -Path $cultureDir -ItemType Directory -Force | Out-Null }
        try {
            $remoteUrl = "$RemoteBaseUrl/$culture/WinToolkit.psd1"
            $temporaryFile = "$localFile.$([guid]::NewGuid()).tmp"
            try {
                Invoke-WebRequest -Uri $remoteUrl -OutFile $temporaryFile -UseBasicParsing -ErrorAction Stop | Out-Null
                Move-Item -LiteralPath $temporaryFile -Destination $localFile -Force -ErrorAction Stop
            }
            finally {
                if (Test-Path -LiteralPath $temporaryFile) { Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue }
            }
        }
        catch {
            if (-not (Test-Path $localFile)) {
                try {
                    $localFileFallback = Join-Path $ScriptRoot 'languages' $culture 'WinToolkit.psd1'
                    if (Test-Path $localFileFallback) { Copy-Item -LiteralPath $localFileFallback -Destination $localFile -Force }
                }
                catch {
                    Write-Warning "wintoolkit-modules\10-Module.Localization.ps1, Invoke-SourceTextLanguagePreparation: $($_.Exception.Message)"
                }
            }
        }
    }
    return $localDir
}
function Get-SourceTextAutoDetectedLanguage {
    param([string]$AvailableCultures = 'en-US', [string]$SystemUICulture = ($PSUICulture.ToString()))
    $normalizedSystem = $SystemUICulture.ToLowerInvariant()
    $availableList = @($AvailableCultures -split '[\s,]+' | Where-Object { $_ })
    if ($availableList -contains $normalizedSystem) { return $normalizedSystem }
    $neutralSystem = $normalizedSystem.Split('-')[0]
    foreach ($culture in $availableList) {
        if ($culture.Split('-')[0] -eq $neutralSystem) { return $culture }
    }
    return 'en-US'
}
$Global:SourceTextPreparedLanguagesDir = Invoke-SourceTextLanguagePreparation -ScriptRoot $PSScriptRoot
if ($Language -eq 'en-US') {
    $availableCultures = @()
    if ($Global:SourceTextPreparedLanguagesDir -and (Test-Path $Global:SourceTextPreparedLanguagesDir)) {
        $availableCultures = @(Get-ChildItem -Path $Global:SourceTextPreparedLanguagesDir -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName 'WinToolkit.psd1') } | ForEach-Object { $_.Name })
    }
    $Language = Get-SourceTextAutoDetectedLanguage -AvailableCultures ($availableCultures -join ',')
}
Set-SourceTextLanguage -LanguageCode $Language
function Clear-ProgressLine {
    if ($Host.Name -eq 'ConsoleHost') {
        try {
            $rawUI = $Host.UI.RawUI
            if ($Global:ProgressLineStart) {
                $startRow = [math]::Max(0, [int]$Global:ProgressLineStart.Y)
                $endRow = [math]::Min(
                    $rawUI.BufferSize.Height - 1,
                    $startRow + [math]::Max(1, [int]$Global:ProgressLineRows) - 1
                )
                $rectangle = [System.Management.Automation.Host.Rectangle]::new(
                    0, $startRow, $rawUI.BufferSize.Width - 1, $endRow
                )
                $blankCell = [System.Management.Automation.Host.BufferCell]::new(
                    ' ', $rawUI.ForegroundColor, $rawUI.BackgroundColor,
                    [System.Management.Automation.Host.BufferCellType]::Complete
                )
                try {
                    $rawUI.SetBufferContents($rectangle, $blankCell)
                }
                catch {
                    $blankLine = ' ' * $rawUI.BufferSize.Width
                    for ($row = $startRow; $row -le $endRow; $row++) {
                        $rawUI.CursorPosition = [System.Management.Automation.Host.Coordinates]::new(0, $row)
                        Write-Host $blankLine -NoNewline
                    }
                }
                $rawUI.CursorPosition = $Global:ProgressLineStart
                $Global:ProgressLineStart = $null
                $Global:ProgressLineRows = 0
                return
            }
            $width = $rawUI.WindowSize.Width - 1
            Write-Host "`r$(' ' * $width)`r" -NoNewline
        }
        catch {
            Write-Host "`r                                                                                `r" -NoNewline
            $Global:ProgressLineStart = $null
            $Global:ProgressLineRows = 0
        }
    }
}
function Get-CenteredText {
    param([string]$Text, [int]$Width = 0)
    if ($Width -eq 0) { $Width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 } }
    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    return (' ' * $padding + $Text)
}
function Write-StyledMessage {
    param(
        [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Progress', 'Question')][string]$Type,
        [string]$Text,
        [switch]$NoNewline
    )
    $style = $Global:MsgStyles[$Type]
    $timestamp = Get-Date -Format "HH:mm:ss"
    $displayText = $Text
    Write-Host "[$timestamp] $($style.Icon) $displayText" -ForegroundColor $style.Color -NoNewline:$NoNewline
    $logLevel = switch ($Type) {
        'Success' { 'SUCCESS' } 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' }
    }
    Write-ToolkitLog -Level $logLevel -Message $displayText
}
function Show-ProgressBar {
    param([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon = '⏳', [string]$Spinner = '', [string]$Color = 'Green')
    $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
    $filled = '█' * [math]::Floor($safePercent * 30 / 100)
    $empty = '░' * (30 - $filled.Length)
    $bar = "[$filled$empty] {0,3}%" -f $safePercent
    if (-not $Global:GuiSessionActive) {
        $progressLine = "$Spinner $Icon $Activity $bar"
        if ($Status) { $progressLine += " $Status" }
        $startPosition = $null
        if ($Host.Name -eq 'ConsoleHost') {
            try {
                $cursor = $Host.UI.RawUI.CursorPosition
                $startPosition = [System.Management.Automation.Host.Coordinates]::new(0, $cursor.Y)
            }
            catch {
                Write-Warning "wintoolkit-modules\20-Module.UI.ps1, Show-ProgressBar: $($_.Exception.Message)"
            }
        }
        Write-Host "`r$progressLine" -NoNewline -ForegroundColor $Color
        if ($Percent -ge 100) {
            Write-Host ''
            $Global:ProgressLineStart = $null
            $Global:ProgressLineRows = 0
        }
        elseif ($startPosition) {
            $endPosition = $Host.UI.RawUI.CursorPosition
            $Global:ProgressLineStart = $startPosition
            $Global:ProgressLineRows = [math]::Max(1, $endPosition.Y - $startPosition.Y + 1)
        }
    }
}
function Write-ProgressUpdate {
    param(
        [string]$Activity,
        [string]$Status = '',
        [int]$Percent = 0,
        [string]$Icon = '⏳',
        [string]$Color = 'Green',
        [string]$Spinner = ''
    )
    if ($Global:GuiSessionActive) { return }
    Clear-ProgressLine
    Show-ProgressBar -Activity $Activity -Status $Status -Percent $Percent -Icon $Icon -Spinner $Spinner -Color $Color
}
function Get-SpinnerChar {
    param([ref]$Index)
    if (-not $Global:Spinners -or $Global:Spinners.Length -eq 0) { return '' }
    $position = $Index.Value % $Global:Spinners.Length
    $Index.Value++
    return $Global:Spinners[$position]
}
function Show-Header {
    param([string]$SubTitle)
    if ($Global:GuiSessionActive) { return }
    if ([string]::IsNullOrWhiteSpace($SubTitle)) { $SubTitle = Get-SourceTextLoc 'menu.main' }
    try { Clear-Host } catch {
        Write-Warning "wintoolkit-modules\20-Module.UI.ps1, Show-Header: $($_.Exception.Message)"
    }
    $width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 }
    $asciiArt = @(
        '      __        __  _   _   _ ',
        '      \ \      / / | | | \ | |',
        '       \ \ /\ / /  | | |  \| |',
        '        \ V  V /   | | | |\  |',
        '         \_/\_/    |_| |_| \_|',
        '',
        "       WinToolkit - $SubTitle",
        ("       " + (Get-SourceTextLoc 'sourceText.version') + " $ToolkitVersion")
    )
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    foreach ($line in $asciiArt) { Write-Host (Get-CenteredText $line $width) -ForegroundColor White }
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    Write-Host ''
}
function Show-ConsoleTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object[]]$Rows,
        [Parameter(Mandatory = $true)][hashtable[]]$Columns,
        [string]$Title = ''
    )
    $widths = @{}
    foreach ($col in $Columns) { $widths[$col.Key] = $col.Header.Length }
    foreach ($row in $Rows) {
        foreach ($col in $Columns) {
            $val = if ($row -is [hashtable]) { "$($row[$col.Key])" } else { "$($row.$($col.Key))" }
            if ($val.Length -gt $widths[$col.Key]) { $widths[$col.Key] = $val.Length }
        }
    }
    $sep = '+' + (($Columns | ForEach-Object { '-' * ($widths[$_.Key] + 2) }) -join '+') + '+'
    if ($Title) {
        $totalWidth = $sep.Length
        $paddedTitle = " $Title "
        $pad = [Math]::Max(0, [Math]::Floor(($totalWidth - $paddedTitle.Length) / 2))
        Write-Host ('=' * $totalWidth) -ForegroundColor Cyan
        Write-Host ((' ' * $pad) + $paddedTitle) -ForegroundColor Cyan
        Write-Host ('=' * $totalWidth) -ForegroundColor Cyan
    }
    Write-Host $sep -ForegroundColor DarkGray
    $headerLine = '|'
    foreach ($col in $Columns) { $headerLine += ' ' + $col.Header.PadRight($widths[$col.Key]) + ' |' }
    Write-Host $headerLine -ForegroundColor Cyan
    Write-Host $sep -ForegroundColor DarkGray
    foreach ($row in $Rows) {
        $line = '|'
        foreach ($col in $Columns) {
            $val = if ($row -is [hashtable]) { "$($row[$col.Key])" } else { "$($row.$($col.Key))" }
            $line += ' ' + $val.PadRight($widths[$col.Key]) + ' |'
        }
        $rowColor = 'White'
        $statusColumn = $Columns | Where-Object { $_.Key -eq 'Status' -or $_.Key -eq 'Stato' } | Select-Object -First 1
        $statusKey = if ($statusColumn) { $statusColumn.Key } else { $null }
        if ($statusKey) {
            $statusVal = if ($row -is [hashtable]) { "$($row[$statusKey])" } else { "$($row.$statusKey)" }
            if ($statusVal -match '✅|OK|Successo|Completato') { $rowColor = 'Green' }
            elseif ($statusVal -match '⚠️|Warning|Parziale') { $rowColor = 'Yellow' }
            elseif ($statusVal -match '❌|Errore|Fallito') { $rowColor = 'Red' }
        }
        Write-Host $line -ForegroundColor $rowColor
    }
    Write-Host $sep -ForegroundColor DarkGray
}
function Start-ToolkitLog {
    param([string]$ToolName)
    $Global:CurrentToolName = $ToolName
    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {
        Write-Warning "wintoolkit-modules\30-Module.Logging.ps1, Start-ToolkitLog 1: $($_.Exception.Message)"
    }
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = $AppConfig.Paths.Logs
    if (-not (Test-Path $logdir)) { New-Item -Path $logdir -ItemType Directory -Force | Out-Null }
    $Global:CurrentLogFile = "$logdir\${ToolName}_$dateTime.log"
    $Global:CurrentCorrelationId = [guid]::NewGuid().ToString()
    $os = Get-CimInstance Win32_OperatingSystem  -ErrorAction SilentlyContinue
    $psVer = $PSVersionTable.PSVersion.ToString()
    $psEd = $PSVersionTable.PSEdition
    $psCompat = ($PSVersionTable.PSCompatibleVersions | ForEach-Object { $_.ToString() }) -join ', '
    $gitId = if ($PSVersionTable.GitCommitId) { $PSVersionTable.GitCommitId } else { 'N/A' }
    $wsManVer = if ($PSVersionTable.WSManStackVersion) { $PSVersionTable.WSManStackVersion.ToString() } else { 'N/A' }
    $remoteVer = if ($PSVersionTable.PSRemotingProtocolVersion) { $PSVersionTable.PSRemotingProtocolVersion.ToString() } else { 'N/A' }
    $serVer = if ($PSVersionTable.SerializationVersion) { $PSVersionTable.SerializationVersion.ToString() } else { 'N/A' }
    $build = [int]$os.BuildNumber
    $dispVer = Get-WindowsDisplayVersion -Build $build
    $header = @"
[START LOG HEADER]
Start time              : $dateTime
CorrelationId           : $($Global:CurrentCorrelationId)
ToolName                : $ToolName
PSVersion               : $psVer
PSEdition               : $psEd
GitCommitId             : $gitId
ToolkitVersion          : $($Global:ToolkitVersion)
OS                      : $($os.Caption)
    Version                 : Version $dispVer (OS build $($os.BuildNumber))
Platform                : $([Environment]::OSVersion.Platform)
PSCompatibleVersions    : $psCompat
PSRemotingProtocolVersion: $remoteVer
SerializationVersion    : $serVer
WSManStackVersion       : $wsManVer
[END LOG HEADER]
"@
    try { Add-Content -Path $Global:CurrentLogFile -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue } catch {
        Write-Warning "wintoolkit-modules\30-Module.Logging.ps1, Start-ToolkitLog 2: $($_.Exception.Message)"
    }
}
function Write-ToolkitLog {
    param(
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',
        [string]$Message,
        [hashtable]$Context = @{}
    )
    if (-not $Global:CurrentLogFile) { return }
    $ts = Get-Date -Format "HH:mm:ss"
    $clean = $Message -replace '^\s+', ''
    $clean = $clean -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
    $line = "[$ts] [$Level] $clean"
    if ($Context.Count -gt 0) {
        try { $line += " | Context: " + ($Context | ConvertTo-Json -Compress -Depth 3) } catch {
            Write-Warning "wintoolkit-modules\30-Module.Logging.ps1, Write-ToolkitLog 1: $($_.Exception.Message)"
        }
    }
    try {
        $mutex = New-Object System.Threading.Mutex($false, "Global\WinToolkitLogMutex")
        $hasHandle = $false
        try {
            $hasHandle = $mutex.WaitOne(5000)
            if ($hasHandle) { Add-Content -Path $Global:CurrentLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue }
        }
        finally {
            if ($hasHandle) { $mutex.ReleaseMutex() }
            $mutex.Dispose()
        }
    }
    catch {
        Write-Warning "wintoolkit-modules\30-Module.Logging.ps1, Write-ToolkitLog 2: $($_.Exception.Message)"
    }
}
function Write-ToolkitError {
    param(
        [System.Management.Automation.ErrorRecord]$Record,
        [string]$ToolName,
        [string]$Message
    )
    if ([string]::IsNullOrWhiteSpace($Message)) { $Message = Get-SourceTextLoc 'sourceText.criticalError' }
    Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'uiText.0In12' -Args @($Message, ${ToolName}, $($Record.Exception.Message)))
    Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'uiText.0In1' -Args @($Message, $ToolName)) -Context @{
        Line      = $Record.InvocationInfo.ScriptLineNumber
        Exception = $Record.Exception.GetType().FullName
        Stack     = $Record.ScriptStackTrace
    }
}
function Get-WindowsDisplayVersion {
    param([int]$Build = 0)
    if ($Build -le 0) {
        try { $Build = [int](Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).BuildNumber } catch { $Build = 0 }
    }
    $ntKey = $null
    try { $ntKey = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue } catch { $ntKey = $null }
    if ($ntKey) {
        if ($ntKey.DisplayVersion) {
            $displayVersion = ([string]$ntKey.DisplayVersion).Trim()
            if ($displayVersion) { return $displayVersion }
        }
        if ($ntKey.ReleaseId -and $Build -lt 22000) {
            $releaseId = ([string]$ntKey.ReleaseId).Trim()
            if ($releaseId) { return $releaseId }
        }
    }
    $versionMap = @{
        28000 = "26H1"; 26300 = "26H2"; 26200 = "25H2"; 26100 = "24H2"
        22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2"
        19045 = "22H2"; 19044 = "21H2"; 19043 = "21H1"; 19042 = "20H2"
        19041 = "2004"; 18363 = "1909"; 18362 = "1903"; 17763 = "1809"
        17134 = "1803"; 16299 = "1709"; 15063 = "1703"; 14393 = "1607"
        10586 = "1511"; 10240 = "1507"
    }
    foreach ($key in ($versionMap.Keys | Sort-Object -Descending)) {
        if ($Build -ge $key) { return $versionMap[$key] }
    }
    return "N/A"
}
function Get-WindowsCompatibility {
    param([int]$Build)
    if ($Build -ge 22000) { return 'Windows11' }
    if ($Build -ge 17763) { return 'Windows10' }
    if ($Build -eq 9600)   { return 'Windows81' }
    return 'Unsupported'
}
function Get-SystemInfo {
    if ($Global:SystemInfoCache) { return $Global:SystemInfoCache }
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $computerInfo = Get-CimInstance Win32_ComputerSystem
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $build = [int]$osInfo.BuildNumber
        $ver = Get-WindowsDisplayVersion -Build $build
        $Global:SystemInfoCache = @{
            ProductName    = $osInfo.Caption -replace 'Microsoft ', ''
            BuildNumber    = $build
            DisplayVersion = $ver
            Compatibility  = Get-WindowsCompatibility -Build $build
            Architecture   = $osInfo.OSArchitecture
            ComputerName   = $computerInfo.Name
            TotalRAM       = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
            TotalDisk      = [Math]::Round($diskInfo.Size / 1GB, 0)
            FreeDisk       = [Math]::Round($diskInfo.FreeSpace / 1GB, 0)
            FreePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)
        }
        return $Global:SystemInfoCache
    }
    catch { return $null }
}
function Convert-BitlockerStatusToKey {
    param([string]$StatusText)
    if ([string]::IsNullOrWhiteSpace($StatusText)) { return 'bitlocker.status.notConfigured' }
    $normalized = $StatusText.Trim().ToLowerInvariant()
    if ($normalized -match 'decritt|decrypt') { return 'bitlocker.status.decrypting' }
    if ($normalized -match 'crittografia in corso|encrypt') { return 'bitlocker.status.encrypting' }
    if ($normalized -match 'sospes|suspend') { return 'bitlocker.status.suspended' }
    if ($normalized -match 'non configur|not configured') { return 'bitlocker.status.notConfigured' }
    if ($normalized -match 'disattiv|protection off|off|disabled') { return 'bitlocker.status.off' }
    if ($normalized -match 'attiv|protection on|on|enabled') { return 'bitlocker.status.on' }
    return 'bitlocker.status.unknown'
}
function Get-BitlockerStatus {
    param([switch]$Key)
    try {
        $out = & manage-bde -status C: 2>&1
        $statusText = $null
        if ($out -match "(?im)^\s*(Stato protezione|Protection Status):\s*(.*)$") {
            $statusText = $matches[2].Trim()
        }
        $statusKey = Convert-BitlockerStatusToKey -StatusText $statusText
        if ($Key) { return $statusKey }
        return (Get-SourceTextLoc $statusKey)
    }
    catch {
        if ($Key) { return 'bitlocker.status.off' }
        return (Get-SourceTextLoc 'bitlocker.status.off')
    }
}
function Get-LocalUserProfiles {
    return Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '^(Public|Default|Default User|All Users)$' }
}
function Initialize-ToolkitPaths {
    foreach ($path in $AppConfig.Paths.Values) {
        if (-not (Test-Path $path -PathType Leaf) -and $path -notmatch "\.exe$|\.zip$|\.msixbundle$") {
            try {
                if (-not (Test-Path $path)) { $null = New-Item -Path $path -ItemType Directory -Force -ErrorAction SilentlyContinue }
            }
            catch {
                Write-Warning "wintoolkit-modules\50-Module.Environment.ps1, Initialize-ToolkitPaths: $($_.Exception.Message)"
            }
        }
    }
}
function Update-EnvironmentPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
    $env:Path = $newPath
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
}
function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if (-not (Test-Path $Path)) { $null = New-Item -Path $Path -Force }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}
function Stop-ToolkitProcesses {
    param([string[]]$ProcessNames)
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.closingInterferingProcesses')
    foreach ($procName in $ProcessNames) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -ne $PID } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
}
function Invoke-ExternalCommandWithLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory,
        [int]$TimeoutSeconds = 0,
        [string]$LogContextKey = '',
        [string]$Activity = '',
        [int]$UpdateInterval = 500,
        [string]$Tool = $Global:CurrentToolName,
        [string]$Step = 'ExternalCommand'
    )
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $startTime = Get-Date
    $argString = $Arguments -join ' '
    Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'uiText.runningCommand01Timeout2S' -Args @($Command, $argString, ${TimeoutSeconds}))
    Write-ToolkitLog -Level 'DEBUG' -Message (Get-SourceTextLoc 'uiText.commandContext') -Context @{
        Tool = $Tool; Step = $Step; WorkingDir = $WorkingDirectory; ContextKey = $LogContextKey
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Command
    $psi.Arguments = $argString
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $outText = ""; $errText = ""; $success = $false; $exitCode = $null; $timedOut = $false
    try {
        if (-not $proc.Start()) { throw (Get-SourceTextLoc 'uiText.unableToStartExternalProcess') }
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()
        if ($Activity) {
            $spinnerIndex = 0; $percent = 0
            while (-not $proc.HasExited -and ($TimeoutSeconds -eq 0 -or ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds)) {
                $spinner = Get-SpinnerChar -Index ([ref]$spinnerIndex)
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                if ($percent -lt 90) { $percent += Get-Random -Minimum 1 -Maximum 3 }
                Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.executing0Seconds' -Args @($elapsed)) -Percent $percent -Icon '⏳' -Spinner $spinner
                Start-Sleep -Milliseconds $UpdateInterval
                $proc.Refresh()
            }
            if (-not $proc.HasExited -and $TimeoutSeconds -gt 0) {
                try { $proc.Kill() } catch {
                    Write-Warning "wintoolkit-modules\60-Module.Processes.ps1, Invoke-ExternalCommandWithLog 1: $($_.Exception.Message)"
                }
                throw (Get-SourceTextLoc 'uiText.timeoutAfter0Seconds' -Args @($TimeoutSeconds))
            }
            Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
            if (-not $Global:GuiSessionActive) { Write-Host "" }
        }
        else {
            if ($TimeoutSeconds -gt 0) {
                if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
                    try { $proc.Kill() } catch {
                        Write-Warning "wintoolkit-modules\60-Module.Processes.ps1, Invoke-ExternalCommandWithLog 2: $($_.Exception.Message)"
                    }
                    throw (Get-SourceTextLoc 'uiText.timeoutAfter0Seconds' -Args @($TimeoutSeconds))
                }
            }
            else { $proc.WaitForExit() }
        }
        try { [System.Threading.Tasks.Task]::WaitAll($outTask, $errTask) } catch {
            Write-Warning "wintoolkit-modules\60-Module.Processes.ps1, Invoke-ExternalCommandWithLog 3: $($_.Exception.Message)"
        }
        if ($outTask.Status -eq 'RanToCompletion') { $outText = $outTask.Result }
        if ($errTask.Status -eq 'RanToCompletion') { $errText = $errTask.Result }
        $exitCode = $proc.ExitCode
        $success = ($exitCode -eq 0)
    }
    catch {
        $exitCode = if ($null -ne $exitCode) { $exitCode } else { -1 }
        if ($_.Exception.Message -match 'Timeout') { $timedOut = $true }
        if ($proc -and -not $proc.HasExited) {
            try { $proc.Kill() } catch {
                Write-Warning "wintoolkit-modules\60-Module.Processes.ps1, Invoke-ExternalCommandWithLog 4: $($_.Exception.Message)"
            }
        }
        Write-ToolkitLog -Level 'ERROR' -Message (Get-SourceTextLoc 'uiText.exceptionWhileRunningExternalCommand') -Context @{
            Command = $Command; Arguments = $Arguments; WorkingDir = $WorkingDirectory
            TimeoutSec = $TimeoutSeconds; ContextKey = $LogContextKey
            Exception = $_.Exception.Message; Stack = $_.ScriptStackTrace
        }
    }
    finally {
        $stopwatch.Stop()
        if ($null -eq $outText) { $outText = "" }
        if ($null -eq $errText) { $errText = "" }
        $maxLen = 8000
        $outLogged = if ($outText.Length -gt $maxLen) { $outText.Substring(0, $maxLen) + "`n[...output truncated...]" } else { $outText }
        $errLogged = if ($errText.Length -gt $maxLen) { $errText.Substring(0, $maxLen) + "`n[...stderr truncated...]" } else { $errText }
        $statusMsg = if ($success) { Get-SourceTextLoc 'sourceText.completedSuccessfully' } else { Get-SourceTextLoc 'sourceText.completedWithErrors' }
        Write-ToolkitLog -Level 'INFO'  -Message (Get-SourceTextLoc 'uiText.command0ExitCode1Duration2' -Args @($statusMsg, $exitCode, $($stopwatch.Elapsed.ToString('hh\:mm\:ss'))))
        Write-ToolkitLog -Level 'DEBUG' -Message (Get-SourceTextLoc 'uiText.commandOutput0' -Args @($Command)) -Context @{
            ContextKey = $LogContextKey; StdOutSnippet = $outLogged; StdErrSnippet = $errLogged
        }
        if ($proc) { $proc.Dispose() }
    }
    [pscustomobject]@{
        Success  = $success
        ExitCode = $exitCode
        StdOut   = $outText
        StdErr   = $errText
        Elapsed  = $stopwatch.Elapsed
        TimedOut = $timedOut
    }
}
function Invoke-WithSpinner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Activity,
        [scriptblock]$Action,
        [int]$TimeoutSeconds = 300,
        [int]$UpdateInterval = 500,
        [switch]$Process,
        [switch]$Job,
        [switch]$Timer,
        [scriptblock]$PercentUpdate,
        [string]$Command,
        [string[]]$Arguments = @(),
        [string]$LogContextKey = ''
    )
    $startTime = Get-Date
    $spinnerIndex = 0
    $percent = 0
    if ($Command) {
        return Invoke-ExternalCommandWithLog -Command $Command -Arguments $Arguments `
            -TimeoutSeconds $TimeoutSeconds -Activity $Activity -UpdateInterval $UpdateInterval -LogContextKey $LogContextKey
    }
    try {
        $result = & $Action
        if ($Timer) {
            $totalSeconds = $TimeoutSeconds
            for ($i = $totalSeconds; $i -gt 0; $i--) {
                $spinner = Get-SpinnerChar -Index ([ref]$spinnerIndex)
                $percent = if ($PercentUpdate) { & $PercentUpdate } else { [math]::Round((($totalSeconds - $i) / $totalSeconds) * 100) }
                Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.01Seconds' -Args @($Activity, $i)) -Status '' -Percent $percent -Icon '⏳' -Spinner $spinner -Color 'Yellow'
                Start-Sleep -Seconds 1
            }
            if (-not $Global:GuiSessionActive) { Write-Host '' }
            return $true
        }
        elseif ($Process -and $result -and $result.GetType().Name -eq 'Process') {
            while (-not $result.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                $spinner = Get-SpinnerChar -Index ([ref]$spinnerIndex)
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                $percent = if ($PercentUpdate) { & $PercentUpdate } elseif ($percent -lt 90) { $percent + (Get-Random -Minimum 1 -Maximum 3) } else { $percent }
                Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.executing0Seconds' -Args @($elapsed)) -Percent $percent -Icon '⏳' -Spinner $spinner
                Start-Sleep -Milliseconds $UpdateInterval
                $result.Refresh()
            }
            if (-not $result.HasExited) {
                Write-ProgressUpdate -Activity $Activity -Status '' -Percent 0
                if (-not $Global:GuiSessionActive) { Write-Host "" }
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.timeoutReachedAfter0SecondsProcessTermination' -Args @($TimeoutSeconds))
                $result.Kill(); Start-Sleep -Seconds 2
                return @{ Success = $false; TimedOut = $true; ExitCode = -1 }
            }
            Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
            if (-not $Global:GuiSessionActive) { Write-Host "" }
            return @{ Success = $true; TimedOut = $false; ExitCode = $result.ExitCode }
        }
        elseif ($Job -and $result -is [System.Management.Automation.Job]) {
            try {
                while ($result.State -eq 'Running' -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                    $spinner = Get-SpinnerChar -Index ([ref]$spinnerIndex)
                    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                    $percent = if ($PercentUpdate) { & $PercentUpdate } elseif ($percent -lt 90) { $percent + (Get-Random -Minimum 1 -Maximum 3) } else { $percent }
                    Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.executing0Seconds' -Args @($elapsed)) -Percent $percent -Icon '⏳' -Spinner $spinner
                    Start-Sleep -Milliseconds $UpdateInterval
                }
                if ($result.State -eq 'Running') {
                    Stop-Job -Job $result -ErrorAction SilentlyContinue
                    throw (Get-SourceTextLoc 'uiText.timeoutAfter0Seconds' -Args @($TimeoutSeconds))
                }
                if ($result.State -eq 'Failed') {
                    $failureReason = $result.ChildJobs[0].JobStateInfo.Reason
                    if ($failureReason) { throw $failureReason }
                    throw (Get-SourceTextLoc 'uiText.errorDuring01' -Args @($Activity, $result.State))
                }
                $jobResult = Receive-Job -Job $result -Wait -ErrorAction Stop
                Write-ProgressUpdate -Activity $Activity -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
                if (-not $Global:GuiSessionActive) { Write-Host '' }
                return $jobResult
            }
            finally {
                Remove-Job -Job $result -Force -ErrorAction SilentlyContinue
            }
        }
        else {
            Start-Sleep -Seconds $TimeoutSeconds
            return $result
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'uiText.errorDuring01' -Args @(${Activity}, $($_.Exception.Message)))
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}
function Start-InterruptibleCountdown {
    param([int]$Seconds = 30, [string]$Message, [switch]$Suppress)
    if ($Suppress) { return $true }
    if ([string]::IsNullOrWhiteSpace($Message)) { $Message = Get-SourceTextLoc 'sourceText.automaticRestart' }
    Write-StyledMessage -Type 'Info' -Text ("💡 " + (Get-SourceTextLoc 'uiText.pressAnyKeyToCancel'))
    Write-Host ''
    for ($i = $Seconds; $i -gt 0; $i--) {
        if ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
            Write-Host "`n"
            Write-StyledMessage -Type 'Warning' -Text ("⏸️ " + (Get-SourceTextLoc 'uiText.systemRebootCancelled'))
            return $false
        }
        $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
        Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.0In1Seconds' -Args @($Message, $i)) -Status '' -Percent $percent -Icon '⏰' -Color 'Red'
        Start-Sleep 1
    }
    Write-Host "`n"
    return $true
}
function Start-ToolkitSession {
    param([string]$ToolName, [string]$SubTitle = $ToolName)
    Start-ToolkitLog -ToolName $ToolName
    Show-Header -SubTitle $SubTitle
    try { $Host.UI.RawUI.WindowTitle = "$SubTitle By MagnetarMan" } catch {
        Write-Warning "wintoolkit-modules\60-Module.Processes.ps1, Start-ToolkitSession: $($_.Exception.Message)"
    }
}
function Invoke-ToolkitReboot {
    param(
        [string]$Message,
        [int]$Seconds = 30,
        [switch]$SuppressIndividualReboot
    )
    if ([string]::IsNullOrWhiteSpace($Message)) { $Message = Get-SourceTextLoc 'sourceText.operationCompleted' }
    if ($SuppressIndividualReboot) {
        $Global:NeedsFinalReboot = $true
        Write-StyledMessage -Type 'Info' -Text ("🚫 " + (Get-SourceTextLoc 'uiText.individualRestartSuppressedAFinalRebootWillBeHandled'))
    }
    else {
        if (Start-InterruptibleCountdown -Seconds $Seconds -Message $Message) {
            Restart-Computer -Force
        }
    }
}
function Remove-ItemSafely {
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$Recurse)
    if (-not (Test-Path $Path)) { return $false }
    try {
        $params = @{ Path = $Path; Force = $true; ErrorAction = 'SilentlyContinue' }
        if ($Recurse) { $params['Recurse'] = $true }
        Remove-Item @params *>$null
        Clear-ProgressLine
        return $true
    }
    catch { return $false }
}
function Invoke-ToolkitDownload {
    param(
        [string]$Uri,
        [string]$OutputPath,
        [string]$Description,
        [int]$MaxRetries = 3,
        [switch]$NoSpinner
    )
    if ([string]::IsNullOrWhiteSpace($Description)) { $Description = Get-SourceTextLoc 'sourceText.file' }
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-StyledMessage -Type 'Info' -Text ("📥 " + (Get-SourceTextLoc 'uiText.download0' -Args @($Description)))
            $parentDir = Split-Path -Parent $OutputPath
            if (-not (Test-Path $parentDir)) {
                New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
            }
            $handler = New-Object System.Net.Http.HttpClientHandler
            $handler.AllowAutoRedirect = $true
            $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
            $httpClient = New-Object System.Net.Http.HttpClient($handler)
            $httpClient.Timeout = [TimeSpan]::FromSeconds(300)
            $httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
            if ($Uri -match 'drivers\.amd\.com|amd-software') {
                $httpClient.DefaultRequestHeaders.Add("Referer", "https://www.amd.com")
            }
            $totalBytes = 0
            try {
                $headRequest = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Head, $Uri)
                $headResponse = $httpClient.SendAsync($headRequest).Result
                if ($headResponse.Content.Headers.ContentLength -gt 0) {
                    $totalBytes = $headResponse.Content.Headers.ContentLength
                }
                $headResponse.Dispose()
            }
            catch {
                Write-Warning "wintoolkit-modules\60-Module.Processes.ps1, Invoke-ToolkitDownload: $($_.Exception.Message)"
            }
            $getRequest = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $Uri)
            $getResponse = $httpClient.SendAsync($getRequest, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
            if (-not $getResponse.IsSuccessStatusCode) {
                throw (Get-SourceTextLoc 'uiText.httpError01' -Args @($($getResponse.StatusCode), $($getResponse.ReasonPhrase)))
            }
            if ($totalBytes -eq 0 -and $getResponse.Content.Headers.ContentLength -gt 0) {
                $totalBytes = $getResponse.Content.Headers.ContentLength
            }
            $isUnknownSize = ($totalBytes -eq 0)
            $fakeProgressStart = $null
            if ($isUnknownSize -and -not $Global:GuiSessionActive) {
                $fakeProgressStart = Get-Date
                Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.download02' -Args @($Description)) `
                    -Status (Get-SourceTextLoc 'uiText.startingDownloadProcess') `
                    -Percent 8 -Icon '📥' -Color 'Cyan'
                Start-Sleep -Milliseconds 120
            }
            $contentStream = $getResponse.Content.ReadAsStreamAsync().Result
            $fileStream = [System.IO.File]::Create($OutputPath)
            $buffer = New-Object byte[] 8192
            $totalRead = 0
            $lastPercent = -1
            $lastProgressTime = Get-Date
            try {
                while ($true) {
                    $read = $contentStream.Read($buffer, 0, $buffer.Length)
                    if ($read -eq 0) { break }
                    $fileStream.Write($buffer, 0, $read)
                    $totalRead += $read
                    if (-not $Global:GuiSessionActive) {
                        $currentDisplay = if ($totalRead -gt 1048576) {
                            "$([Math]::Round($totalRead / 1048576, 1)) MB"
                        }
                        else {
                            "$([Math]::Round($totalRead / 1024, 1)) KB"
                        }
                        if ($totalBytes -gt 0) {
                            $percent = [Math]::Round(($totalRead / $totalBytes) * 100)
                            $totalDisplay = if ($totalBytes -gt 1048576) {
                                "$([Math]::Round($totalBytes / 1048576, 1)) MB"
                            }
                            else {
                                "$([Math]::Round($totalBytes / 1024, 1)) KB"
                            }
                            $status = "($currentDisplay / $totalDisplay)"
                            $icon = '📥'
                            $col = 'Cyan'
                        }
                        else {
                            if ($fakeProgressStart) {
                                $elapsed = ((Get-Date) - $fakeProgressStart).TotalSeconds
                                $percent = [math]::Min(95, [math]::Floor(8 + ($elapsed * 1.52)))
                            }
                            else {
                                $percent = 50
                            }
                            $status = "$currentDisplay scaricati"
                            $icon = '📥'
                            $col = 'Cyan'
                        }
                        $now = Get-Date
                        $timeSinceLast = ($now - $lastProgressTime).TotalMilliseconds
                        $shouldUpdate = $false
                        if ($lastPercent -eq -1) {
                            $shouldUpdate = $true
                        }
                        elseif ($totalBytes -gt 0) {
                            if ($percent -ne $lastPercent -and $timeSinceLast -gt 250) {
                                $shouldUpdate = $true
                            }
                        }
                        else {
                            if ($timeSinceLast -gt 400 -or $percent -ne $lastPercent) {
                                $shouldUpdate = $true
                            }
                        }
                        if ($shouldUpdate) {
                            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.download02' -Args @($Description)) -Status $status -Percent $percent -Icon $icon -Color $col
                            $lastPercent = $percent
                            $lastProgressTime = $now
                        }
                    }
                }
            }
            finally {
                $fileStream.Dispose()
                $contentStream.Dispose()
            }
            $httpClient.Dispose()
            $handler.Dispose()
            if (Test-Path $OutputPath) {
                if ($totalBytes -gt 0) {
                    Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.download02' -Args @($Description)) -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅' -Color 'Green'
                }
                else {
                    Write-ProgressUpdate -Activity (Get-SourceTextLoc 'uiText.download02' -Args @($Description)) -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅' -Color 'Green'
                    if (-not $Global:GuiSessionActive) { Write-Host "" }
                }
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.downloadCompleted0' -Args @($Description))
                return $true
            }
        }
        catch {
            if (Test-Path $OutputPath) {
                Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
            }
            if ($attempt -lt $MaxRetries) {
                Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'uiText.01AttemptFailed2ILlTryAgain' -Args @($attempt, $MaxRetries, $($_.Exception.Message))))
                Start-Sleep -Seconds 2
            }
        }
    }
    Write-StyledMessage -Type 'Error' -Text ((Get-SourceTextLoc 'uiText.downloadFailedAfter0Attempts1' -Args @($MaxRetries, $Description)))
    return $false
}
function Restart-ServiceSafely {
    param([string]$Name, [int]$WaitSeconds = 1)
    try {
        Stop-Service -Name $Name -Force -ErrorAction Stop
        Start-Sleep -Seconds $WaitSeconds
        Start-Service -Name $Name -ErrorAction Stop
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.serviceRestarted0' -Args @($Name))
        return $true
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.failedToRestart01' -Args @($Name, $($_.Exception.Message)))
        return $false
    }
}
function Get-WingetExecutable {
    $aliasPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path $aliasPath) { return $aliasPath }
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $wingetDir = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" `
        -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
    if ($wingetDir) {
        $exe = Join-Path $wingetDir.FullName "winget.exe"
        if (Test-Path $exe) { return $exe }
    }
    return "winget"
}
function Start-AppxSilentProcess {
    param(
        [string]$AppxPath,
        [string]$Flags = '-ForceApplicationShutdown',
        [string[]]$DependencyPaths = @()
    )
    $pathParam = if ($Flags -match '-Register') { "" } else { "-Path '$($AppxPath -replace "'", "''")'" }
    $depString = ""
    if ($DependencyPaths.Count -gt 0) {
        $depString = "-DependencyPackagePath " + (($DependencyPaths | ForEach-Object { "'$($_ -replace "'", "''")'" }) -join ", ")
    }
    $cmd = @"
`$ProgressPreference = 'SilentlyContinue';
`$ErrorActionPreference = 'SilentlyContinue';
try {
    Add-AppxPackage $pathParam $depString $Flags -ErrorAction Stop | Out-Null
}
catch {
    if (`$_.Exception.Message -match '0x80073D06' -or `$_.Exception.Message -match 'versione successiva') { exit 0 }
    if (`$_.Exception.Message -match '0x80073CF9' -or ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)) {
        try {
            if ('$pathParam' -eq '') { exit 1 }
            Add-AppxProvisionedPackage -Online -PackagePath '$($AppxPath -replace "'", "''")' $depString -SkipLicense -ErrorAction Stop | Out-Null
            exit 0
        }
        catch { exit 1 }
    }
    exit 1
}
exit 0
"@
    $encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -NonInteractive -EncodedCommand $encodedCmd"
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    return [System.Diagnostics.Process]::Start($psi)
}
function Wait-WingetReady {
    param([int]$MaxWaitSeconds = 300, [int]$PollIntervalSeconds = 5)
    Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.wingetIntegrityValidationInProgressTimeout0S' -Args @($MaxWaitSeconds)))
    $wingetExe = Get-WingetExecutable
    $maxRetries = [Math]::Floor($MaxWaitSeconds / $PollIntervalSeconds)
    for ($i = 1; $i -le $maxRetries; $i++) {
        try {
            $versionProc = Start-Process -FilePath $wingetExe -ArgumentList '--version' `
                -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
            $dbProc = Start-Process -FilePath $wingetExe `
                -ArgumentList 'list', 'NonExistentApp_WinToolkitCheck', '--accept-source-agreements' `
                -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
            if ($versionProc.ExitCode -eq 0 -and $dbProc.ExitCode -eq 0) {
                Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.wingetReadyAndDatabaseUnlockedAttempt01' -Args @($i, $maxRetries)))
                return $true
            }
        }
        catch {
            Write-Warning "wintoolkit-modules\70-Module.Winget.ps1, Wait-WingetReady: $($_.Exception.Message)"
        }
        $remaining = $MaxWaitSeconds - ($i * $PollIntervalSeconds)
        Write-StyledMessage -Type Progress -Text ("⏳ " + (Get-SourceTextLoc 'uiText.wingetNotYetReadyAttempt012SRemainWait' -Args @($i, $maxRetries, $remaining)))
        Start-Sleep -Seconds $PollIntervalSeconds
    }
    Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.wingetDidNotRespondWithin0SecondsIContinueAnyway' -Args @($MaxWaitSeconds)))
    return $false
}
function Reset-Winget {
    param([switch]$Force)
    $ProgressPreference = 'SilentlyContinue'
    $OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    function Test-VCRedistInstalled {
        $64BitOS = [System.Environment]::Is64BitOperatingSystem
        $registryPath = [string]::Format(
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\{0}\Microsoft\VisualStudio\14.0\VC\Runtimes\X{1}',
            $(if ($64BitOS) { 'WOW6432Node' } else { '' }),
            $(if ($64BitOS) { '64' } else { '86' })
        )
        $major = (Get-ItemProperty -Path $registryPath -Name 'Major' -ErrorAction SilentlyContinue).Major
        $dllPath = [string]::Format('{0}\system32\concrt140.dll', $env:windir)
        return (Test-Path $registryPath) -and ($major -ge 14) -and (Test-Path $dllPath)
    }
    function Register-AppxManifest {
        try {
            $manifest = (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue).InstallLocation
            if ($manifest) {
                $manifestXml = Join-Path $manifest 'AppxManifest.xml'
                if (Test-Path $manifestXml) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.manifestReRegistrationAppxmanifestXmlPreventsLeaks')
                    Start-AppxSilentProcess -AppxPath $manifestXml -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown' | Out-Null
                }
            }
        }
        catch {
            Write-Warning "wintoolkit-modules\70-Module.Winget.ps1, Register-AppxManifest: $($_.Exception.Message)"
        }
    }
    function Get-LatestAssetUrl {
        param([string]$Match)
        try {
            $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing -ErrorAction Stop
            $asset = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
            if ($asset) { return $asset.browser_download_url }
            return $null
        }
        catch { return $null }
    }
    function Test-WingetCompatibility {
        $os = [Environment]::OSVersion.Version
        if ($os.Major -lt 10 -or ($os.Major -eq 10 -and $os.Build -lt 16299)) {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.systemNotSupportedByWingetWindows101709Required')
            return $false
        }
        return $true
    }
    function Test-WingetFunctionality {
        Update-EnvironmentPath
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetNotFoundInPath')
            return $false
        }
        try {
            $versionOutput = (& (Get-WingetExecutable) --version 2>$null) | Out-String
            if ($LASTEXITCODE -eq 0 -and $versionOutput -match 'v\d+\.\d+') {
                Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.operationalWingetVersion02' -Args @($($versionOutput.Trim()))))
                return $true
            }
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetPresentButNotRespondingCorrectlyExitcode0' -Args @($LASTEXITCODE))
            return $false
        }
        catch {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.errorDuringWingetTest0' -Args @($($_.Exception.Message)))
            return $false
        }
    }
    function Test-PathInEnvironment {
        param([string]$PathToCheck, [string]$Scope = 'Both')
        $found = $false
        if ($Scope -in 'User', 'Both') { if (($env:PATH -split ';').Contains($PathToCheck)) { $found = $true } }
        if ($Scope -in 'System', 'Both') {
            $syspath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
            if (($syspath -split ';').Contains($PathToCheck)) { $found = $true }
        }
        return $found
    }
    function Add-ToEnvironmentPath {
        param([string]$PathToAdd, [ValidateSet('User', 'System')][string]$Scope)
        if (Test-PathInEnvironment -PathToCheck $PathToAdd -Scope $Scope) { return }
        if ($Scope -eq 'System') {
            $cur = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
            [Environment]::SetEnvironmentVariable('PATH', "$cur;$PathToAdd", 'Machine')
        }
        else {
            $cur = [Environment]::GetEnvironmentVariable('PATH', 'User')
            [Environment]::SetEnvironmentVariable('PATH', "$cur;$PathToAdd", 'User')
        }
        if (-not ($env:PATH -split ';').Contains($PathToAdd)) { $env:PATH += ";$PathToAdd" }
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.updatedPath0' -Args @($PathToAdd))
    }
    function Set-PathPermissions {
        param([string]$FolderPath)
        if (-not (Test-Path $FolderPath)) { return }
        try {
            $sid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
            $group = $sid.Translate([System.Security.Principal.NTAccount])
            $acl = Get-Acl -Path $FolderPath -ErrorAction Stop
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $group, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $acl.SetAccessRule($rule)
            Set-Acl -Path $FolderPath -AclObject $acl -ErrorAction Stop
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.updatedFolderPermissions0' -Args @($FolderPath))
        }
        catch { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.unableToSetPermissionsOn01' -Args @($FolderPath, $($_.Exception.Message))) }
    }
    function Set-WingetPathPermissions {
        $wingetFolderPath = $null
        try {
            $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
            $wingetDir = Get-ChildItem "$env:ProgramFiles\WindowsApps" `
                -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
            if ($wingetDir) { $wingetFolderPath = $wingetDir.FullName }
        }
        catch {
            Write-Warning "wintoolkit-modules\70-Module.Winget.ps1, Set-WingetPathPermissions: $($_.Exception.Message)"
        }
        if ($wingetFolderPath) {
            Set-PathPermissions -FolderPath $wingetFolderPath
            Add-ToEnvironmentPath -PathToAdd $wingetFolderPath -Scope 'System'
            Add-ToEnvironmentPath -PathToAdd '%LOCALAPPDATA%\Microsoft\WindowsApps' -Scope 'User'
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.pathAndWingetPermissionsUpdated')
        }
    }
    function _Repair-WingetDatabase {
        Write-StyledMessage -Type Info -Text ("🔧 " + (Get-SourceTextLoc 'uiText.ripristinoDatabaseWinget'))
        try {
            Stop-ToolkitProcesses -ProcessNames $AppConfig.WingetProcesses
            $cachePath = "$env:LOCALAPPDATA\WinGet"
            if (Test-Path $cachePath) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.clearingWingetCache')
                Get-ChildItem -Path $cachePath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '\\lock\\|\\tmp\\' } |
                ForEach-Object { try { Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue } catch {
                    Write-Warning "wintoolkit-modules\70-Module.Winget.ps1, _Repair-WingetDatabase 1: $($_.Exception.Message)"
                } }
            }
            @("$env:LOCALAPPDATA\WinGet\Data\USERTEMPLATE.json",
                "$env:LOCALAPPDATA\WinGet\Data\DEFAULTUSER.json") | ForEach-Object {
                if (Test-Path $_ -PathType Leaf) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.resetStatusFile0' -Args @($_))
                    Remove-Item $_ -Force -ErrorAction SilentlyContinue
                }
            }
            try { $null = & (Get-WingetExecutable) source reset --force 2>&1 } catch {
                Write-Warning "wintoolkit-modules\70-Module.Winget.ps1, _Repair-WingetDatabase 2: $($_.Exception.Message)"
            }
            if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
                Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
            }
            try {
                $manifest = (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue).InstallLocation
                if ($manifest) {
                    $manifestXml = Join-Path $manifest 'AppxManifest.xml'
                    if (Test-Path $manifestXml) {
                        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.reRegisterManifestAppxmanifestXml')
                        Start-AppxSilentProcess -AppxPath $manifestXml -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown' | Out-Null
                    }
                }
            }
            catch {
                Write-Warning "wintoolkit-modules\70-Module.Winget.ps1, _Repair-WingetDatabase 3: $($_.Exception.Message)"
            }
            try {
                if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.runningPackageManagerRepair')
                    Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                }
            }
            catch {
                if ($_.Exception.Message -match '0x80073D06' -or $_.Exception.Message -match 'versione successiva') {
                    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerCompletedHigherVersionAlreadyPresent')
                }
                else { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerFallito0' -Args @($($_.Exception.Message))) }
            }
            Set-WingetPathPermissions
            Update-EnvironmentPath
            return $true
        }
        catch {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.errorDuringDatabaseRestore0' -Args @($($_.Exception.Message)))
            return $false
        }
    }
    function _Install-WingetAdvanced {
        Write-StyledMessage -Type Info -Text ("🚀 " + (Get-SourceTextLoc 'uiText.advancedInstallationViaMicrosoftWingetClientModule'))
        try {
            if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
                if ($PSVersionTable.PSVersion.Major -lt 7) {
                    try { Install-PackageProvider -Name 'NuGet' -Force -ForceBootstrap -ErrorAction SilentlyContinue *>$null }
                    catch { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.nugetProviderNotInstallable') }
                }
            }
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingMicrosoftWingetClientModule')
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
                Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
                Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetClientModuleInstalled')
            }
            catch { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.failedToInstallWingetClientModule0' -Args @($($_.Exception.Message))) }
            if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.attemptingPackageManagerRepair')
                try {
                    Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerCompletato')
                }
                catch {
                    if ($_.Exception.Message -match '0x80073D06' -or $_.Exception.Message -match 'versione successiva') {
                        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerIgnoredHigherVersionAlreadyPresent')
                    }
                    else { Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.repairWingetpackagemanagerFallito0' -Args @($($_.Exception.Message))) }
                }
                Start-Sleep 3
            }
            Update-EnvironmentPath
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.fallbackDownloadMsixBundleDirect')
                $tempDir = $AppConfig.Paths.Temp
                if (-not (Test-Path $tempDir)) { $null = New-Item -Path $tempDir -ItemType Directory -Force }
                $tempInstaller = Join-Path $tempDir "WingetInstaller.msixbundle"
                Invoke-WebRequest -Uri $AppConfig.URLs.WingetInstaller -OutFile $tempInstaller -UseBasicParsing -ErrorAction Stop
                Start-AppxSilentProcess -AppxPath $tempInstaller -Flags '-ForceApplicationShutdown'
                Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
                Start-Sleep 3
            }
            try { Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null } catch {
                Write-Warning "wintoolkit-modules\70-Module.Winget.ps1, _Install-WingetAdvanced: $($_.Exception.Message)"
            }
            Set-WingetPathPermissions
            Update-EnvironmentPath
            return $true
        }
        catch {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.wingetAdvancedInstallationError0' -Args @($($_.Exception.Message)))
            return $false
        }
    }
    function Test-WingetDeepValidation {
        Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.wingetDeepValidationConnectivityDatabaseIntegrity'))
        try {
            $wingetExe = Get-WingetExecutable
            $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
            $exitCode = $LASTEXITCODE
            if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.crashAccessViolationExitcode0RipristinoDatabase' -Args @($exitCode)))
                $null = _Repair-WingetDatabase
                Start-Sleep 3
                $searchResult = & $wingetExe search "Git.Git" --accept-source-agreements 2>&1
                $exitCode = $LASTEXITCODE
                if ($exitCode -eq -1073741819 -or $exitCode -eq 3221225781) {
                    Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.persistentCrashAfterDatabaseRestore'))
                    return $false
                }
            }
            if ($exitCode -eq 0) {
                Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.deepValidationPassedWingetCommunicatesWithRepositories'))
                return $true
            }
            $details = ($searchResult | Out-String).Trim()
            if ($details.Length -gt 200) { $details = $details.Substring(0, 200) + "..." }
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.deepValidationFailedExitcode0Details1' -Args @($exitCode, $details)))
            return $false
        }
        catch {
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.deepValidationError0' -Args @($($_.Exception.Message)))
            return $false
        }
    }
    Write-StyledMessage -Type Info -Text ("🚀 " + (Get-SourceTextLoc 'uiText.startingWingetAdvancedRepair'))
    if (-not (Test-WingetCompatibility)) { return $false }
    if (-not $Force -and (Test-WingetFunctionality)) {
        Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.wingetAlreadyOperationalNoRepairsNecessary'))
        return $true
    }
    Stop-ToolkitProcesses -ProcessNames $AppConfig.WingetProcesses
    try {
        Write-StyledMessage -Type Info -Text ("⚡ " + (Get-SourceTextLoc 'uiText.phase1CoreRecoveryVcAppxDependenciesMsixbundle'))
        if (-not (Test-VCRedistInstalled) -or $Force) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingVisualCRedistributable')
            $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
            $vcUrl = "https://aka.ms/vs/17/release/vc_redist.$arch.exe"
            $vcFile = Join-Path $AppConfig.Paths.Temp "vc_redist.exe"
            if (-not (Test-Path $AppConfig.Paths.Temp)) { $null = New-Item $AppConfig.Paths.Temp -ItemType Directory -Force }
            Invoke-WebRequest -Uri $vcUrl -OutFile $vcFile -UseBasicParsing
            Start-Process -FilePath $vcFile -ArgumentList "/install", "/quiet", "/norestart" -Wait
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.vcRedistInstalled')
        }
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadWingetDependencies')
        $depUrl = Get-LatestAssetUrl -Match 'DesktopAppInstaller_Dependencies.zip'
        if ($depUrl) {
            $depZip = Join-Path $AppConfig.Paths.Temp "dependencies.zip"
            $depDir = Join-Path $AppConfig.Paths.Temp "deps"
            Invoke-WebRequest -Uri $depUrl -OutFile $depZip -UseBasicParsing
            Expand-Archive -Path $depZip -DestinationPath $depDir -Force
            $archPattern = if ([Environment]::Is64BitOperatingSystem) { "x64|ne" } else { "x86|ne" }
            $script:WingetDependencies = @()
            Get-ChildItem $depDir -Recurse -Filter "*.appx" |
            Where-Object { $_.Name -match $archPattern } |
            ForEach-Object { Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.dependencyFound0' -Args @($($_.Name))); $script:WingetDependencies += $_.FullName }
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.loadedDependencies')
        }
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingWingetMsixbundleWithDependencies')
        $bundleUrl = Get-LatestAssetUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        if ($bundleUrl) {
            $bundleFile = Join-Path $AppConfig.Paths.Temp "winget.msixbundle"
            Invoke-WebRequest -Uri $bundleUrl -OutFile $bundleFile -UseBasicParsing
            $deps = if ($script:WingetDependencies) { $script:WingetDependencies } else { @() }
            Start-AppxSilentProcess -AppxPath $bundleFile -DependencyPaths $deps -Flags '-ForceApplicationShutdown'
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.wingetCoreInstalled')
        }
        Register-AppxManifest
        Update-EnvironmentPath
        if (Test-WingetFunctionality) {
            Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.phase1CompletedOperationalWinget'))
        }
        else {
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.phase1InsufficientStartingPhase2AdvancedRecovery'))
            $null = _Install-WingetAdvanced
            $null = _Repair-WingetDatabase
            Update-EnvironmentPath
        }
        Start-Sleep -Seconds 3
        try {
            Start-Process -FilePath (Get-WingetExecutable) -ArgumentList 'source', 'reset', '--force' `
                -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "wintoolkit-modules\70-Module.Winget.ps1, Reset-Winget: $($_.Exception.Message)"
        }
        $deepOk = Test-WingetDeepValidation
        if ($deepOk) {
            Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.wingetSuccessfullyRestoredAndTested'))
            return $true
        }
        else {
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.wingetInstalledDeepValidationWithAnomaliesPossibleNetworkOrDbProblems'))
            return $true
        }
    }
    catch {
        Write-StyledMessage -Type Error -Text ((Get-SourceTextLoc 'uiText.criticalErrorInReset0' -Args @($($_.Exception.Message))))
        return $false
    }
    finally {
        if (Test-Path $AppConfig.Paths.Temp) { Remove-Item $AppConfig.Paths.Temp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
function Get-UserConfirmation {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [switch]$DefaultYes,
        [ValidateSet('Info', 'Warning', 'Question')][string]$Level = 'Question'
    )
    $choices = if ($DefaultYes) { "[S/n]" } else { "[s/N]" }
    $fullPrompt = "$Prompt $choices"
    if ($Global:GuiSessionActive) {
        Write-StyledMessage -Type $Level -Text $fullPrompt
        return $true
    }
    Write-StyledMessage -Type $Level -Text "${fullPrompt}: " -NoNewline
    $response = Read-Host
    Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'uiText.userConfirmationPrompt0Response1' -Args @($Prompt, $response))
    if ([string]::IsNullOrWhiteSpace($response)) { return $DefaultYes }
    return $response -match '^[sS]'
}
function Read-ValidatedChoice {
    param(
        [int[]]$ValidRange,
        [int]$Min,
        [int]$Max,
        [switch]$AllowZero,
        [string]$Prompt = "Seleziona un'opzione",
        [string]$RawInput
    )
    $currentInput = if ($PSBoundParameters.ContainsKey('RawInput')) { $RawInput } else { $null }
    while ($true) {
        $userInput = if ($null -ne $currentInput) {
            $val = $currentInput; $currentInput = $null; $val
        }
        else {
            Write-StyledMessage -Type 'Question' -Text "${Prompt}: " -NoNewline
            Microsoft.PowerShell.Utility\Read-Host
        }
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.emptyInputTryAgain'))
            continue
        }
        $choices = $userInput -split '[\s,]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
        if ($choices.Count -gt 0) {
            $isValid = $true
            foreach ($c in $choices) {
                if ($null -ne $ValidRange) { if ($c -notin $ValidRange) { $isValid = $false; break } }
                else {
                    if ($AllowZero -and $c -eq 0) { continue }
                    if ($null -ne $Min -and $c -lt $Min) { $isValid = $false; break }
                    if ($null -ne $Max -and $c -gt $Max) { $isValid = $false; break }
                }
            }
            if ($isValid) {
                Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'uiText.userChoices0' -Args @($($choices -join ',')))
                return $choices
            }
        }
        $rangeStr = if ($null -ne $ValidRange) { "$($ValidRange[0]) e $($ValidRange[-1])" } else { "$Min e $Max" }
        Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.invalidChoiceEnterNumbersBetween0' -Args @($rangeStr)))
    }
}
function WinOSCheck {
    if ($Global:GuiSessionActive) { return }
    Show-Header -SubTitle (Get-SourceTextLoc 'system.infoTitle')
    $si = Get-SystemInfo
    if (-not $si) { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.systemInfoNotAvailable'); return }
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'uiText.system01' -Args @($($si.ProductName), $($si.DisplayVersion)))
    switch ($si.Compatibility) {
        'Windows11'    { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.compatibleSystemRecentWin1110') }
        'Windows10'    { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.compatibleSystemWin10') }
        'Windows81'    { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.windows81PartialCompatibility') }
        default {
            Write-StyledMessage -Type 'Error' -Text "$(Get-CenteredText ('🤣 ' + (Get-SourceTextLoc 'sourceText.criticalError').ToUpperInvariant() + ' 🤣') 65)"
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'uiText.doYouReallyThinkThisScriptCanDoAnythingForThisVersion')
            Write-Host ("  " + (Get-SourceTextLoc 'uiText.doYouWantToTakeARiskYN')) -ForegroundColor Yellow
            if ((Read-Host) -notmatch '^[Yy]$') { exit }
        }
    }
    Start-Sleep -Seconds 2
}
function Test-WindowsUpdateStatus {
    try {
        if ($Global:GuiSessionActive) { return }
        Write-StyledMessage -Type 'Info' -Text ("🔍 " + (Get-SourceTextLoc 'uiText.windowsUpdateStatusCheck'))
        $pendingReboot = $false
        $installerRunning = $false
        if (Get-Module -ListAvailable -Name PSWindowsUpdate -ErrorAction SilentlyContinue) {
            Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
            try {
                $rebootStatus = Get-WURebootStatus -ErrorAction SilentlyContinue
                if ($rebootStatus -and $rebootStatus.RebootRequired) {
                    $pendingReboot = $true
                    Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'uiText.pendingRebootDetectedForWindowsUpdates'))
                }
            }
            catch {
                Write-Warning "wintoolkit-modules\80-Module.UserInteraction.ps1, Test-WindowsUpdateStatus 1: $($_.Exception.Message)"
            }
            try {
                $installerStatus = Get-WUInstallerStatus -ErrorAction SilentlyContinue
                if ($installerStatus -and $installerStatus.IsBusy) {
                    $installerRunning = $true
                    Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'uiText.windowsUpdateInstallationServiceCurrentlyRunning'))
                }
            }
            catch {
                Write-Warning "wintoolkit-modules\80-Module.UserInteraction.ps1, Test-WindowsUpdateStatus 2: $($_.Exception.Message)"
            }
        }
        else {
            $regPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootRequired",
                "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"
            )
            foreach ($path in $regPaths) {
                if (Test-Path $path -ErrorAction SilentlyContinue) { $pendingReboot = $true; break }
            }
            $trustedInstaller = Get-Service -Name TrustedInstaller -ErrorAction SilentlyContinue
            if ($trustedInstaller -and $trustedInstaller.Status -eq 'Running') { $installerRunning = $true }
        }
        if ($pendingReboot -or $installerRunning) {
            $width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 }
            Write-Host ""
            Write-Host ('═' * ($width - 1)) -ForegroundColor Yellow
            Write-Host ""
            Write-Host (Get-CenteredText (Get-SourceTextLoc 'uiText.importantWarning')) -ForegroundColor Yellow
            Write-Host ""
            Write-Host (" " + (Get-SourceTextLoc 'uiText.pendingSystemUpdatesHaveBeenDetected')) -ForegroundColor Yellow
            if ($pendingReboot) { Write-Host ("  " + (Get-SourceTextLoc 'uiText.systemRestartRequiredToCompleteUpdates')) -ForegroundColor Yellow }
            if ($installerRunning) { Write-Host ("  " + (Get-SourceTextLoc 'uiText.windowsUpdateInstallationServiceIsRunning')) -ForegroundColor Yellow }
            Write-Host ""
            Write-Host (" " + (Get-SourceTextLoc 'uiText.thisMayCauseMalfunctionsErrorsOrBehavior')) -ForegroundColor Yellow
            Write-Host (" " + (Get-SourceTextLoc 'uiText.unexpectedBehaviorInSomeOrAllWintoolkitFeatures')) -ForegroundColor Yellow
            Write-Host ""
            Write-Host (Get-CenteredText (Get-SourceTextLoc 'uiText.proceedWithCaution')) -ForegroundColor Red
            Write-Host ""
            Write-Host (" " + (Get-SourceTextLoc 'uiText.weStronglyRecommendThatYouCompleteAllOngoingUpdates')) -ForegroundColor Yellow
            Write-Host (" " + (Get-SourceTextLoc 'uiText.rebootYourSystemAndThenRestartWintoolkitBeforeContinuing')) -ForegroundColor Yellow
            Write-Host ""
            Write-Host ('═' * ($width - 1)) -ForegroundColor Yellow
            Write-Host ""
            Start-Sleep -Seconds 5
        }
        else {
            Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'uiText.noPendingUpdatesDetected'))
        }
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'uiText.unableToCheckWindowsUpdateStatus0' -Args @($($_.Exception.Message))))
    }
}
function Invoke-OfficeSilentRemoval {
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$Recurse)
    return Remove-ItemSafely -Path $Path -Recurse:$Recurse
}
function Stop-OfficeProcesses {
    $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
    $closed = 0
    Write-StyledMessage -Type 'Info' -Text ("📋 " + (Get-SourceTextLoc 'uiText.closingOfficeProcesses'))
    foreach ($processName in $processes) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($running) {
            try { $running | Stop-Process -Force -ErrorAction Stop; $closed++ }
            catch { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.unableToClose0' -Args @($processName)) }
        }
    }
    if ($closed -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.0OfficeProcessesClosed' -Args @($closed)) }
}
function Invoke-OfficeDownloadFile([string]$Url, [string]$OutputPath, [string]$Description) {
    return Invoke-ToolkitDownload -Uri $Url -OutputPath $OutputPath -Description $Description
}
function Set-OfficePostConfig {
    Write-StyledMessage -Type 'Info' -Text ("⚙️ " + (Get-SourceTextLoc 'uiText.deepOptimizationOfMicrosoftOffice'))
    $registrySettings = @(
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "disconnectedstate"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "usercontentdisabled"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "downloadcontentdisabled"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"; Name = "ShownOptIn"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback"; Name = "Enabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Graphics"; Name = "DisableAnimations"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Graphics"; Name = "DisableHardwareAcceleration"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"; Name = "DisableBootToStartScreen"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\LinkedIn"; Name = "ShowLinkedInIntegration"; Value = 0 }
    )
    foreach ($reg in $registrySettings) {
        if (-not (Test-Path $reg.Path)) { $null = New-Item -Path $reg.Path -Force }
        Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type 'DWord' -Force
    }
    $tasksToDisable = @(
        "OfficeTelemetryAgentLogon", "OfficeTelemetryAgentFallback",
        "OfficeBackgroundTaskHandlerRegistration", "OfficeBackgroundTaskHandlerLogon",
        "OfficeFeatureUpdates", "OfficeFeatureUpdatesLogon"
    )
    foreach ($tName in $tasksToDisable) {
        Get-ScheduledTask | Where-Object { $_.TaskName -eq $tName } | Disable-ScheduledTask -ErrorAction SilentlyContinue
    }
    Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'uiText.officeOptimizedTelemetryPrivacyAndScheduledTasksRemoved'))
}
function VcardAnalizer {
    [CmdletBinding()]
    param(
        [string]$OverridesPath
    )
    $assetCacheDir = Join-Path $AppConfig.Paths.Root 'assets'
    if (-not (Test-Path $assetCacheDir)) {
        $null = New-Item -Path $assetCacheDir -ItemType Directory -Force
    }
    $defaultLocalOverrides = Join-Path $assetCacheDir 'DriverOverrides.json'
    $resolvedOverridesPath = if ($OverridesPath) { $OverridesPath } else { $defaultLocalOverrides }
    $analysis = [pscustomobject]@{
        Cards               = @()
        Matches             = @()
        PrimaryManufacturer = 'Unknown'
        OverridesLoaded     = $false
        OverridesSource     = $resolvedOverridesPath
    }
    try {
        $cards = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        foreach ($card in $cards) {
            $name = [string]$card.Name
            $caption = [string]$card.Caption
            $pnpId = [string]$card.PNPDeviceID
            $manufacturer = 'Unknown'
            if ($name -match 'NVIDIA|GeForce|Quadro|Tesla' -or $caption -match 'NVIDIA') { $manufacturer = 'NVIDIA' }
            elseif ($name -match 'AMD|Radeon|ATI' -or $caption -match 'AMD|ATI') { $manufacturer = 'AMD' }
            elseif ($name -match 'Intel|Iris|UHD|HD Graphics' -or $caption -match 'Intel') { $manufacturer = 'Intel' }
            $analysis.Cards += [pscustomobject]@{
                Name         = $name
                Caption      = $caption
                PnpDeviceID  = $pnpId
                Manufacturer = $manufacturer
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.gpuAnalysisErrorReadingWin32Videocontroller0' -Args @($($_.Exception.Message)))
    }
    if ($analysis.Cards.Count -gt 0) {
        $analysis.PrimaryManufacturer = ($analysis.Cards | Select-Object -First 1).Manufacturer
    }
    $overrides = @()
    $remoteUrl = $AppConfig.URLs.DriverOverridesJson
    try {
        if (Invoke-ToolkitDownload -Uri $remoteUrl -OutputPath $defaultLocalOverrides -Description 'Driver Overrides JSON') {
            $resolvedOverridesPath = $defaultLocalOverrides
            $analysis.OverridesSource = $resolvedOverridesPath
        }
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.driveroverridesJsonDownloadFailedUseLocalCacheIfAvailable')
    }
    if (Test-Path $resolvedOverridesPath) {
        try {
            $jsonRaw = Get-Content -Path $resolvedOverridesPath -Raw -Encoding UTF8
            $parsed = $jsonRaw | ConvertFrom-Json -ErrorAction Stop
            if ($parsed -is [System.Array]) { $overrides = $parsed }
            elseif ($parsed) { $overrides = @($parsed) }
            $analysis.OverridesLoaded = $true
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.invalidDriveroverridesJson0' -Args @($($_.Exception.Message)))
        }
    }
    else {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.driveroverridesJsonNotFoundIn0' -Args @($resolvedOverridesPath))
    }
    foreach ($gpu in $analysis.Cards) {
        foreach ($ovr in $overrides) {
            $namePattern = [string]$ovr.NamePattern
            $pnpPattern = [string]$ovr.PnpIdPattern
            $manufacturer = [string]$ovr.Manufacturer
            $nameMatches = $false
            $pnpMatches = $false
            $mfrMatches = $false
            if (-not [string]::IsNullOrWhiteSpace($namePattern) -and -not [string]::IsNullOrWhiteSpace($gpu.Name)) {
                $nameMatches = $gpu.Name -match $namePattern
            }
            if (-not [string]::IsNullOrWhiteSpace($pnpPattern) -and -not [string]::IsNullOrWhiteSpace($gpu.PnpDeviceID)) {
                $pnpMatches = $gpu.PnpDeviceID -like $pnpPattern
            }
            if (-not [string]::IsNullOrWhiteSpace($manufacturer) -and $gpu.Manufacturer -ne 'Unknown') {
                $mfrMatches = $gpu.Manufacturer -eq $manufacturer
            }
            if (($nameMatches -or $pnpMatches) -and ($mfrMatches -or [string]::IsNullOrWhiteSpace($manufacturer))) {
                $analysis.Matches += [pscustomobject]@{
                    Key          = [string]$ovr.Key
                    Manufacturer = [string]$ovr.Manufacturer
                    NamePattern  = [string]$ovr.NamePattern
                    PnpIdPattern = [string]$ovr.PnpIdPattern
                    DownloadUrl  = [string]$ovr.DownloadUrl
                    FileName     = [string]$ovr.FileName
                    DisplayName  = [string]$ovr.DisplayName
                    MatchedGpu   = [string]$gpu.Name
                    MatchedPnpId = [string]$gpu.PnpDeviceID
                }
            }
        }
    }
    if ($analysis.Matches.Count -gt 0) {
        $analysis.Matches = @($analysis.Matches | Group-Object Key | ForEach-Object { $_.Group | Select-Object -First 1 })
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.detected0StableDriverMatchesFromDriveroverridesJson' -Args @($($analysis.Matches.Count)))
    }
    else {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.noKnownStableDriversFoundForTheDetectedGpus')
    }
    $Global:VcardAnalysisResult = $analysis
    return $analysis
}
function WinRepairToolkit {
    [CmdletBinding()]
    param(
        [int]$MaxRetryAttempts = 3,
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "WinRepairToolkit" -SubTitle (Get-SourceTextLoc 'script.WinRepairToolkit')
    $script:CurrentAttempt = 0
    $sysInfo = Get-SystemInfo
    $RepairTools = @(
        @{ Tool = 'chkdsk'; Args = @('/scan', '/perf'); Name = 'Disk check'; NameKey = 'toolText.extra.diskCheck'; Icon = '💽' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'System File Checker (1)'; NameKey = 'toolText.extra.systemFileChecker1'; Icon = '🗂️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Name = 'Windows Image Recovery'; NameKey = 'toolText.extra.windowsImageRecovery'; Icon = '🛠️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'); Name = 'Remnant Cleanup Updates'; NameKey = 'toolText.extra.remnantCleanupUpdates'; Icon = '🕸️' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'System File Checker (2)'; NameKey = 'toolText.extra.systemFileChecker2'; Icon = '🗂️' }
        @{ Tool = 'chkdsk'; Args = @('/f', '/r', '/x'); Name = 'Thorough disk check'; NameKey = 'toolText.extra.thoroughDiskCheck'; Icon = '💽'; IsCritical = $false }
    )
    function Invoke-RepairCommand {
        param([hashtable]$Config, [int]$Step, [int]$Total)
        $displayName = Get-SourceTextLoc $Config.NameKey
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.01Starting2' -Args @($Step, $Total, $displayName))
        $isChkdsk = ($Config.Tool -ieq 'chkdsk')
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()
        try {
            $processTimeoutSeconds = 600
            switch ($Config.Name) {
                'Windows Image Recovery'   { $processTimeoutSeconds = 10800 }
                'System File Checker (1)' { $processTimeoutSeconds = 3600 }
                'System File Checker (2)' { $processTimeoutSeconds = 10800 }
                'Remnant Cleanup Updates' { $processTimeoutSeconds = 3600 }
                'Disk check' { $processTimeoutSeconds = 900 }
                'Thorough disk check'  { $processTimeoutSeconds = 3600 }
            }
            $spinnerUpdateInterval = if ($Config.Name -eq 'Windows Image Recovery') { 900 } else { 600 }
            if ($Config.Tool -ieq 'DISM' -and $Config.Args -contains '/StartComponentCleanup') {
                Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.cleaningWindowsUpdateStatusBeforeStartingCleanup'))
                Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                Start-Sleep 1
                Remove-ItemSafely -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\SessionsPending' -Recurse
                Start-Sleep 1
            }
            $commandToRun = $Config.Tool
            $argsToRun = $Config.Args
            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
                $drive = $Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1
                if ($null -eq $drive) { $drive = $env:SystemDrive }
                $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }
                $commandToRun = 'cmd.exe'
                $argsToRun = @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ')")
            }
            $spinnerResult = Invoke-WithSpinner -Activity $displayName `
                -Command $commandToRun `
                -Arguments $argsToRun `
                -TimeoutSeconds $processTimeoutSeconds `
                -UpdateInterval $spinnerUpdateInterval `
                -LogContextKey "Repair-$($Config.Tool)"
            $exitCode = $spinnerResult.ExitCode
            $results = ($spinnerResult.StdOut + "`n" + $spinnerResult.StdErr) -split "`n"
            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r') -and ($results -join ' ').ToLower() -match 'schedule|next time.*restart|volume.*in use') {
                Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.0CheckScheduledAtNextReboot' -Args @($displayName)))
                return @{ Success = $true; ErrorCount = 0 }
            }
            $isTimeout = ($spinnerResult.TimedOut -eq $true) -or ($null -eq $exitCode) -or ($exitCode -eq -1)
            if ($isChkdsk -and $exitCode -eq 3) {
                Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.0CheckScheduledAtNextReboot' -Args @($displayName)))
                return @{ Success = $true; ErrorCount = 0 }
            }
            if (($Config.Tool -ieq 'DISM') -and ($results -match '0x800f0806')) {
                Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.0Error0x800f0806PendingOperationsThisIsNotACriticalError' -Args @($displayName)))
                Write-StyledMessage -Type 'Info' -Text ("💡 " + (Get-SourceTextLoc 'toolText.rebootTheSystemToCompletePendingOperations'))
                return @{ Success = $true; ErrorCount = 0 }
            }
            $hasDismSuccess = (-not $isTimeout) -and ($Config.Tool -ieq 'DISM') -and ($results -match '(?i)completed successfully')
            if (($Config.Tool -ieq 'DISM') -and ($Config.Args -contains '/ResetBase') -and $exitCode -eq 3010) {
                $hasDismSuccess = $true
            }
            $isChkdskScan = $isChkdsk -and ($Config.Args -contains '/scan')
            $chkdskCompleted = (-not $isTimeout) -and $isChkdskScan -and (($results -join ' ') -match '(?i)(scansione.*completata|scan.*completed|successfully scanned)')
            $isSuccess = (-not $isTimeout) -and (($exitCode -eq 0) -or $exitCode -eq 3010 -or $hasDismSuccess -or $chkdskCompleted)
            $errors = $warnings = @()
            if (-not $isSuccess) {
                if ($isTimeout) {
                    $errors += Get-SourceTextLoc 'uiText.repairOperationTimedOut'
                }
                foreach ($line in ($results | Where-Object { $_ -and ![string]::IsNullOrWhiteSpace($_.Trim()) })) {
                    $trim = $line.Trim()
                    if ($trim -match '^\[=+\s*\d+' -or $trim -match '(?i)version:|deployment image') { continue }
                    if ($isChkdsk) {
                        if ($trim -match '(?i)(stage|fase|percent complete|verificat|scanned|scanning|errors found.*corrected|volume label)') { continue }
                        if ($trim -match '(?i)(cannot|unable to|access denied|critical|fatal|corrupt file system|bad sectors)') {
                            $errors += $trim
                        }
                    }
                    else {
                        if ($trim -match '0x800f0806') {
                        }
                        elseif ($trim -match '(?i)(errore|error|failed|impossibile|corrotto|corruption)') { $errors += $trim }
                        elseif ($trim -match '(?i)(warning|avviso|attenzione)') { $warnings += $trim }
                    }
                }
                if ($errors.Count -eq 0 -and -not $isTimeout) {
                    $errors += "Generic error or abend (ExitCode: $exitCode)."
                }
            }
            $success = $isSuccess -and ($errors.Count -eq 0)
            if ($isTimeout) {
                $message = Get-SourceTextLoc 'toolText.extra.0NotCompletedAbortedDueToTimeout' -Args @($displayName)
            }
            else {
                $message = if ($success) {
                    Get-SourceTextLoc 'toolText.extra3.0CompletedSuccessfully' -Args @($displayName)
                }
                else {
                    Get-SourceTextLoc 'toolText.extra3.0CompletedWith1Errors' -Args @($displayName, $errors.Count)
                }
            }
            Write-StyledMessage -Type 'Success' -Text $message
            if ($Config.Tool -ieq 'sfc') {
                $cbsLogPath = "C:\Windows\Logs\CBS\CBS.log"
                if (Test-Path $cbsLogPath) {
                    try {
                        $safeStepName = $Config.Name -replace '[^a-zA-Z0-9]', '_'
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                        $destLogName = "SFC_CBS_${safeStepName}_${timestamp}.log"
                        $destLogPath = Join-Path $AppConfig.Paths.Logs $destLogName
                        Copy-Item -Path $cbsLogPath -Destination $destLogPath -Force -ErrorAction SilentlyContinue
                        if (Test-Path $destLogPath) {
                            Write-StyledMessage -Type 'Info' -Text ("📄 " + (Get-SourceTextLoc 'toolText.sfcLogSavedIn0' -Args @($destLogName)))
                        }
                    }
                    catch {
                        Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.failedToExportSfcCbsLogFileInUse'))
                    }
                }
            }
            return @{ Success = $success; ErrorCount = $errors.Count }
        }
        catch {
            Write-ToolkitError -Record $_ -ToolName "WinRepairToolkit" -Message (Get-SourceTextLoc 'toolText.extra.errorInInvokeRepaircommand0' -Args @($($Config.Tool)))
            return @{ Success = $false; ErrorCount = 1 }
        }
    }
    function Start-RepairCycle {
        param([int]$Attempt = 1)
        $script:CurrentAttempt = $Attempt
        Write-StyledMessage -Type 'Info' -Text ("🔄 " + (Get-SourceTextLoc 'toolText.attempting01SystemRepair' -Args @($Attempt, $MaxRetryAttempts)))
        $totalErrors = $successCount = 0
        for ($toolIndex = 0; $toolIndex -lt $RepairTools.Count; $toolIndex++) {
            $result = Invoke-RepairCommand -Config $RepairTools[$toolIndex] -Step ($toolIndex + 1) -Total $RepairTools.Count
            if ($result.Success) { $successCount++ }
            if (!$result.Success -and !($RepairTools[$toolIndex].ContainsKey('IsCritical') -and !$RepairTools[$toolIndex].IsCritical)) {
                $totalErrors += $result.ErrorCount
            }
            Start-Sleep 1
        }
        if ($totalErrors -gt 0 -and $Attempt -lt $MaxRetryAttempts) {
            Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.0ErrorsDetectedNewAttempt' -Args @($totalErrors)))
            Start-Sleep 3
            return Start-RepairCycle -Attempt ($Attempt + 1)
        }
        return @{ Success = ($totalErrors -eq 0); TotalErrors = $totalErrors; AttemptsUsed = $Attempt }
    }
    function Start-DeepDiskRepair {
        Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.startDeepRepairOfDiskCOnNextReboot'))
        try {
            $fsutilResult = Invoke-ExternalCommandWithLog -Command 'fsutil.exe' -Arguments @('dirty', 'set', 'C:') -TimeoutSeconds 300 -LogContextKey 'DeepDiskRepair-Fsutil'
            if (-not $fsutilResult.Success) {
                Write-StyledMessage -Type 'Error' -Text ((Get-SourceTextLoc 'toolText.unableToMarkDiskDirtyFsutil'))
                return $false
            }
            $chkdskResult = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'echo Y | chkdsk C: /f /r /v /x /b') -TimeoutSeconds 7200 -LogContextKey 'DeepDiskRepair-Chkdsk'
            if (-not $chkdskResult.Success) {
                Write-StyledMessage -Type 'Error' -Text ((Get-SourceTextLoc 'toolText.errorSchedulingChkdskForDeepRepair'))
                return $false
            }
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.chkdskCommandSentRebootToPerformDeepDiskRepair')
            return $true
        }
        catch {
            Write-ToolkitError -Record $_ -ToolName "WinRepairToolkit" -Message (Get-SourceTextLoc 'uiText.exceptionInStartDeepdiskrepair')
            return $false
        }
    }
    function Test-PendingOperations {
        $pendingRebootKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
            'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
        )
        foreach ($key in $pendingRebootKeys) {
            if (Test-Path $key) {
                $values = Get-ItemProperty $key -ErrorAction SilentlyContinue
                if ($values -and $values.PSObject.Properties.Count -gt 1) {
                    return $true
                }
            }
        }
        return $false
    }
    if (Test-PendingOperations) {
        Write-ToolkitLog -Level WARNING -Message (Get-SourceTextLoc 'toolText.pendingOperationsRequiringRebootDetectedDismCouldFail') -Context @{
            Tool = 'WinRepairToolkit'
            Step = 'PreExecutionCheck'
        }
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.pendingOperationsRequiringRebootDetectedDismCouldFail')
        Write-StyledMessage -Type 'Info' -Text ("💡 " + (Get-SourceTextLoc 'toolText.restartRecommendedBeforePerformingRepairs'))
    }
    try {
        $repairResult = Start-RepairCycle
        $deepRepairScheduled = $false
        if ($repairResult.TotalErrors -gt 0) {
            Write-ToolkitLog -Level WARNING -Message (Get-SourceTextLoc 'toolText.persistentErrorsDetectedStartDeepRepair') -Context @{
                Tool = 'WinRepairToolkit'
                Step = 'RepairCycle'
                TotalErrors = $repairResult.TotalErrors
            }
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.persistentErrorsDetectedStartDeepRepair')
            $deepRepairScheduled = Start-DeepDiskRepair
        }
        else {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.systemHealthyDeepRepairNotNecessary')
        }
        Write-StyledMessage -Type 'Info' -Text ("⚙️ " + (Get-SourceTextLoc 'toolText.unlimitedPasswordExpirationSetting'))
        $null = Invoke-ExternalCommandWithLog -Command 'net' -Arguments @('accounts', '/maxpwage:unlimited') -TimeoutSeconds 30 -LogContextKey 'Repair-NetAccounts'
        if ($deepRepairScheduled) { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.rebootRequiredForDeepRepair') }
        if ($SuppressIndividualReboot) {
            if ($deepRepairScheduled) {
                $Global:NeedsFinalReboot = $true
                Write-StyledMessage -Type 'Info' -Text ("🚫 " + (Get-SourceTextLoc 'toolText.individualRestartSuppressedAFinalRebootWillBeHandled'))
            }
        }
        else {
            if (Start-InterruptibleCountdown $CountdownSeconds 'Automatic restart') {
                Restart-Computer -Force
            }
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinRepairToolkit"
    }
    finally {
    }
}
function WinUpdateReset {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "WinUpdateReset" -SubTitle (Get-SourceTextLoc 'script.WinUpdateReset')
    function Set-ServiceStatus {
        param (
            [Parameter(Mandatory = $true)][string]$Name,
            [Parameter(Mandatory = $true)][ValidateSet('Running', 'Stopped')][string]$Status,
            [switch]$Wait,
            [int]$TimeoutSeconds = 10
        )
        $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if (-not $service) { return $false }
        if ($service.Status -eq $Status) { return $true }
        try {
            if ($Status -eq 'Running') { Start-Service -Name $Name -ErrorAction Stop }
            else { Stop-Service -Name $Name -Force -ErrorAction Stop }
        }
        catch { return $false }
        if ($Wait) {
            $timeout = $TimeoutSeconds
            while ((Get-Service -Name $Name -ErrorAction SilentlyContinue).Status -ne $Status -and $timeout -gt 0) {
                Start-Sleep -Seconds 1
                $timeout--
            }
            return ((Get-Service -Name $Name -ErrorAction SilentlyContinue).Status -eq $Status)
        }
        return $true
    }
    function Show-ServiceProgress([string]$Activity, [int]$Current, [int]$Total) {
        Invoke-WithSpinner -Activity $Activity -Timer -Action { Start-Sleep -Milliseconds 200 } -TimeoutSeconds 1 *>$null
    }
    function Manage-Service($serviceName, $action, $config, $currentStep, $totalSteps) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            if (-not $service) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Service1NotFoundOnTheSystem' -Args @($serviceIcon, $serviceName))
                return
            }
            switch ($action) {
                'Stop' {
                    Show-ServiceProgress (Get-SourceTextLoc 'toolText.extra3.stopping0' -Args @($serviceName)) $currentStep $totalSteps
                    $success = Set-ServiceStatus -Name $serviceName -Status 'Stopped' -Wait -TimeoutSeconds 10
                    if ($success) {
                        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0Service1Stopped' -Args @($serviceIcon, $serviceName))
                    }
                    else {
                        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0ShuttingDown1TookTooLongOrFailed' -Args @($serviceIcon, $serviceName))
                    }
                }
                'Configure' {
                    Show-ServiceProgress (Get-SourceTextLoc 'toolText.extra3.configuring0' -Args @($serviceName)) $currentStep $totalSteps
                    Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop *>$null
                    $startupTypeText = if ($config.Type -eq 'Automatic') { Get-SourceTextLoc 'sourceText.automatic' } else { Get-SourceTextLoc 'sourceText.manual' }
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0Service1ConfiguredAs2' -Args @($serviceIcon, $serviceName, $startupTypeText))
                }
                'Start' {
                    Show-ServiceProgress (Get-SourceTextLoc 'toolText.extra3.starting0' -Args @($serviceName)) $currentStep $totalSteps
                    Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.waitingForStart0' -Args @($serviceName)) -Timer -Action { Start-Sleep -Milliseconds 200 } -TimeoutSeconds 1 *>$null
                    $success = Set-ServiceStatus -Name $serviceName -Status 'Running' -Wait -TimeoutSeconds 10
                    Clear-ProgressLine
                    if ($success) {
                        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0Service1StartedSuccessfully' -Args @($serviceIcon, ${serviceName}))
                    }
                    else {
                        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Service1StartingOrDelayed' -Args @($serviceIcon, ${serviceName}))
                    }
                }
                'Check' {
                    $status = if ($service.Status -eq 'Running') { '🟢 ' + (Get-SourceTextLoc 'sourceText.active') } else { '🔴 ' + (Get-SourceTextLoc 'sourceText.inactive') }
                    $serviceIcon = if ($null -ne $config.Icon) { $config.Icon } else { '⚙️' }
                    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.01Status2' -Args @($serviceIcon, $serviceName, $status))
                }
            }
        }
        catch {
            $actionText = switch ($action) {
                'Configure' { Get-SourceTextLoc 'sourceText.configure' }
                'Start' { Get-SourceTextLoc 'sourceText.start' }
                'Check' { Get-SourceTextLoc 'sourceText.check' }
                default { $action.ToLower() }
            }
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Unable123' -Args @($serviceIcon, $actionText, $serviceName, $($_.Exception.Message)))
        }
    }
    function Remove-DirectorySafely([string]$path, [string]$displayName) {
        if (-not (Test-Path $path)) {
            Clear-ProgressLine
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Info' -Text ("💭 " + (Get-SourceTextLoc 'toolText.directory0NotPresent' -Args @($displayName)))
            return $true
        }
        try {
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Clear-ProgressLine
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Success' -Text ("🗑️ " + (Get-SourceTextLoc 'toolText.directory0Deleted' -Args @($displayName)))
            return $true
        }
        catch {
            Clear-ProgressLine
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.attemptFailedILlTryForceDeletion')
            try {
                $tempDir = [System.IO.Path]::GetTempPath() + "empty_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                $null = New-Item -ItemType Directory -Path $tempDir -Force
                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.cleaning0' -Args @($displayName)) -Command 'robocopy.exe' -Arguments @("`"$tempDir`"", "`"$path`"", '/MIR', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/NC') -TimeoutSeconds 300 -LogContextKey 'RemoveDirectorySafely-Robocopy'
                Remove-Item $tempDir -Force -ErrorAction SilentlyContinue *>$null
                Remove-Item $path -Force -ErrorAction SilentlyContinue *>$null
                Clear-ProgressLine
                [Console]::Out.Flush()
                if (-not (Test-Path $path)) {
                    Write-StyledMessage -Type 'Success' -Text ("🗑️ " + (Get-SourceTextLoc 'toolText.directory0DeletedForcedMethod' -Args @($displayName)))
                    return $true
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.directory0PartiallyDeleted' -Args @($displayName))
                    return $false
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.unableToCompletelyDelete0FileInUse' -Args @($displayName))
                return $false
            }
        }
    }
    Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.initializingTheWindowsUpdateResetScript'))
    Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.loadingForms') -Timer -Action { Start-Sleep 2 } -TimeoutSeconds 2 *>$null
    Write-StyledMessage -Type 'Info' -Text ("🛠️ " + (Get-SourceTextLoc 'toolText.startingWindowsUpdateServicesRepair'))
    $serviceConfig = @{
        'wuauserv'         = @{ Type = 'Automatic'; Critical = $true; Icon = '🔄'; DisplayName = 'Windows Update' }
        'bits'             = @{ Type = 'Automatic'; Critical = $true; Icon = '📡'; DisplayName = 'Background Intelligent Transfer' }
        'cryptsvc'         = @{ Type = 'Automatic'; Critical = $true; Icon = '🔐'; DisplayName = 'Cryptographic Services' }
        'trustedinstaller' = @{ Type = 'Manual'; Critical = $true; Icon = '🛡️'; DisplayName = 'Windows Modules Installer' }
        'msiserver'        = @{ Type = 'Manual'; Critical = $false; Icon = '📦'; DisplayName = 'Windows Installer' }
    }
    $systemServices = @(
        @{ Name = 'appidsvc'; Icon = '🆔'; Display = 'Application Identity' },
        @{ Name = 'gpsvc'; Icon = '📋'; Display = 'Group Policy Client' },
        @{ Name = 'DcomLaunch'; Icon = '🚀'; Display = 'DCOM Server Process Launcher' },
        @{ Name = 'RpcSs'; Icon = '📞'; Display = 'Remote Procedure Call' },
        @{ Name = 'LanmanServer'; Icon = '🖥️'; Display = 'Server' },
        @{ Name = 'LanmanWorkstation'; Icon = '💻'; Display = 'Workstation' },
        @{ Name = 'EventLog'; Icon = '📄'; Display = 'Windows Event Log' },
        @{ Name = 'mpssvc'; Icon = '🛡️'; Display = 'Windows Defender Firewall' },
        @{ Name = 'WinDefend'; Icon = '🔒'; Display = 'Windows Defender Service' }
    )
    try {
        Write-StyledMessage -Type 'Info' -Text ("🛑 " + (Get-SourceTextLoc 'toolText.windowsUpdateServicesStopping'))
        $stopServices = @('wuauserv', 'cryptsvc', 'bits', 'msiserver')
        for ($serviceIndex = 0; $serviceIndex -lt $stopServices.Count; $serviceIndex++) {
            Manage-Service $stopServices[$serviceIndex] 'Stop' $serviceConfig[$stopServices[$serviceIndex]] ($serviceIndex + 1) $stopServices.Count
        }
        Write-StyledMessage -Type 'Info' -Text ("🧹 " + (Get-SourceTextLoc 'toolText.cleanupGpcacheCacheAndWsusSettings'))
        try {
            if (Test-Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache") {
                Remove-Item "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache" -Recurse -Force -ErrorAction Stop
                Write-StyledMessage -Type 'Success' -Text ("🗑️ " + (Get-SourceTextLoc 'toolText.gpcacheCacheDeleted'))
            } else {
                Write-StyledMessage -Type 'Info' -Text ("💭 " + (Get-SourceTextLoc 'toolText.gpcacheCacheNotPresent'))
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningFailedToDeleteGpcacheCache0' -Args @($($_.Exception.Message)))
        }
        try {
            if (Test-Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate") {
                Remove-Item "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate" -Recurse -Force -ErrorAction Stop
                Write-StyledMessage -Type 'Success' -Text ("🔑 " + (Get-SourceTextLoc 'toolText.wsusSettingsRemoved'))
            } else {
                Write-StyledMessage -Type 'Info' -Text ("💭 " + (Get-SourceTextLoc 'toolText.wsusSettingsNotPresent'))
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningFailedToRemoveWsusSettings0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text ("⏳ " + (Get-SourceTextLoc 'toolText.waitingForResourcesToBeReleased'))
        Start-Sleep -Seconds 3
        Write-StyledMessage -Type 'Info' -Text ("⚙️ " + (Get-SourceTextLoc 'toolText.windowsUpdateServicesReset'))
        $criticalServices = $serviceConfig.Keys | Where-Object { $serviceConfig[$_].Critical }
        for ($criticalIndex = 0; $criticalIndex -lt $criticalServices.Count; $criticalIndex++) {
            $serviceName = $criticalServices[$criticalIndex]
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0ServiceProcessing1' -Args @($($serviceConfig[$serviceName].Icon), $serviceName))
            Manage-Service $serviceName 'Configure' $serviceConfig[$serviceName] ($criticalIndex + 1) $criticalServices.Count
        }
        Write-StyledMessage -Type 'Info' -Text ("🔍 " + (Get-SourceTextLoc 'toolText.checkCriticalSystemServices'))
        for ($systemIndex = 0; $systemIndex -lt $systemServices.Count; $systemIndex++) {
            $sysService = $systemServices[$systemIndex]
            Manage-Service $sysService.Name 'Check' @{ Icon = $sysService.Icon } ($systemIndex + 1) $systemServices.Count
        }
        Write-StyledMessage -Type 'Info' -Text ("📋 " + (Get-SourceTextLoc 'toolText.restoringWindowsUpdateRegistryKeys'))
        Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.logProcessing') -Timer -Action { Start-Sleep 1 } -TimeoutSeconds 1 *>$null
        try {
            @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update",
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            ) | Where-Object { Test-Path $_ } | ForEach-Object {
                Remove-Item $_ -Recurse -Force -ErrorAction Stop *>$null
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.completed')
            }
            if (-not @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update", "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate") | Where-Object { Test-Path $_ }) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.completed')
                Write-StyledMessage -Type 'Info' -Text ("🔑 " + (Get-SourceTextLoc 'toolText.noRegistryKeysToRemove'))
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.error')
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorEditingRegistry0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text ("🗂️ " + (Get-SourceTextLoc 'toolText.deletionOfWindowsUpdateComponents'))
        $directories = @(
            @{ Path = $AppConfig.Paths.SoftwareDistribution; Name = "SoftwareDistribution" },
            @{ Path = $AppConfig.Paths.Catroot2; Name = "catroot2" },
            @{ Path = Join-Path $AppConfig.Paths.System32 "WaaSMedicSvc.dll"; Name = "WaaSMedicSvc.dll" },
            @{ Path = Join-Path $AppConfig.Paths.System32 "wuaueng.dll"; Name = "wuaueng.dll" },
            @{ Path = Join-Path $AppConfig.Paths.System32 "WaaSMedicSvc_BAK.dll"; Name = "WaaSMedicSvc_BAK.dll" },
            @{ Path = Join-Path $AppConfig.Paths.System32 "wuaueng_BAK.dll"; Name = "wuaueng_BAK.dll" },
            @{ Path = Join-Path $AppConfig.Paths.SoftwareDistribution "Download"; Name = "Download" },
            @{ Path = Join-Path $AppConfig.Paths.SoftwareDistribution "DataStore"; Name = "DataStore" },
            @{ Path = Join-Path $AppConfig.Paths.SoftwareDistribution "Backup"; Name = "Backup" }
        )
        for ($dirIndex = 0; $dirIndex -lt $directories.Count; $dirIndex++) {
            $dir = $directories[$dirIndex]
            $percent = [math]::Round((($dirIndex + 1) / $directories.Count) * 100)
            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.directories01' -Args @($($dirIndex + 1), $($directories.Count))) -Status (Get-SourceTextLoc 'toolText.elimination0' -Args @($($dir.Name))) -Percent $percent -Icon '🗑️' -Color 'Yellow'
            Start-Sleep -Milliseconds 300
            $success = Remove-DirectorySafely -path $dir.Path -displayName $dir.Name
            if (-not $success) {
                Write-StyledMessage -Type 'Info' -Text ("💡 " + (Get-SourceTextLoc 'toolText.tipSomeFilesMayBeRecreatedAfterReboot'))
            }
            Clear-ProgressLine
            [Console]::Out.Flush()
            Start-Sleep -Milliseconds 500
        }
        [Console]::Out.Flush()
        Write-StyledMessage -Type 'Info' -Text ("🚀 " + (Get-SourceTextLoc 'toolText.startOfEssentialServices'))
        $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
        for ($essentialIndex = 0; $essentialIndex -lt $essentialServices.Count; $essentialIndex++) {
            Manage-Service $essentialServices[$essentialIndex] 'Start' $serviceConfig[$essentialServices[$essentialIndex]] ($essentialIndex + 1) $essentialServices.Count
        }
        Write-StyledMessage -Type 'Info' -Text ("⚡ " + (Get-SourceTextLoc 'toolText.performingAWindowsUpdateClientReset'))
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.resetClientUpdate') -Command 'cmd.exe' -Arguments @('/c', 'wuauclt', '/resetauthorization', '/detectnow') -TimeoutSeconds 60 -LogContextKey 'UpdateReset-Wuauclt'
        if ($result.Success) {
            Write-StyledMessage -Type 'Success' -Text ("🔄 " + (Get-SourceTextLoc 'toolText.windowsUpdateClientResetSuccessfully'))
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.windowsUpdateClientResetNotCompletedPossibleTimeout'))
        }
        Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.enablingWindowsUpdateAndRelatedServices'))
        Write-StyledMessage -Type 'Info' -Text ("📋 " + (Get-SourceTextLoc 'toolText.resetWindowsUpdateRegistrySettings'))
        try {
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 0
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 3
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 1
            Write-StyledMessage -Type 'Success' -Text ("🔑 " + (Get-SourceTextLoc 'toolText.windowsUpdateRegistrySettingsReset'))
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToRestoreSomeRegistryKeys0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.resetWaasmedicsvcSettings'))
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Type DWord -Value 3 -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "FailureActions" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text ("⚙️ " + (Get-SourceTextLoc 'toolText.waasmedicsvcSettingsReset'))
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningFailedToRestoreWaasmedicsvc0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text ("🔄 " + (Get-SourceTextLoc 'toolText.restorationOfUpdateServices'))
        $services = @(
            @{Name = "BITS"; StartupType = "Manual"; Icon = "📡" },
            @{Name = "wuauserv"; StartupType = "Manual"; Icon = "🔄" },
            @{Name = "UsoSvc"; StartupType = "Automatic"; Icon = "🚀" },
            @{Name = "uhssvc"; StartupType = "Disabled"; Icon = "⭕" },
            @{Name = "WaaSMedicSvc"; StartupType = "Manual"; Icon = "🛡️" }
        )
        foreach ($service in $services) {
            try {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.0Reverting1To2' -Args @($($service.Icon), $($service.Name), $($service.StartupType)))
                $serviceObj = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
                if ($serviceObj) {
                    Set-Service -Name $service.Name -StartupType $service.StartupType -ErrorAction SilentlyContinue *>$null
                    $null = Invoke-ExternalCommandWithLog -Command 'sc.exe' -Arguments @('failure', "$($service.Name)", 'reset= 86400', 'actions= restart/60000/restart/60000/restart/60000') -TimeoutSeconds 30 -LogContextKey "ServiceFailureReset-$($service.Name)"
                    if ($service.StartupType -eq "Automatic") {
                        Set-ServiceStatus -Name $service.Name -Status "Running" -Wait -TimeoutSeconds 5 *>$null
                    }
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0Service1Restored' -Args @($($service.Icon), $($service.Name)))
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToRestoreService01' -Args @($($service.Name), $($_.Exception.Message)))
            }
        }
        Write-StyledMessage -Type 'Info' -Text ("🔍 " + (Get-SourceTextLoc 'toolText.restoringRenamedDlls'))
        $dlls = @("WaaSMedicSvc", "wuaueng")
        foreach ($dll in $dlls) {
            $dllPath = Join-Path $AppConfig.Paths.System32 "$dll.dll"
            $backupPath = Join-Path $AppConfig.Paths.System32 "${dll}_BAK.dll"
            if ((Test-Path $backupPath) -and !(Test-Path $dllPath)) {
                try {
                    $null = Invoke-ExternalCommandWithLog -Command 'takeown.exe' -Arguments @('/f', "`"$backupPath`"") -TimeoutSeconds 30 -LogContextKey "DLLRestore-Takeown-$dll"
                    $null = Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$backupPath`"", '/grant', '*S-1-1-0:F') -TimeoutSeconds 30 -LogContextKey "DLLRestore-IcaclsGrant-$dll"
                    Rename-Item -Path $backupPath -NewName "$dll.dll" -ErrorAction SilentlyContinue *>$null
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.reverted0BakDllTo1Dll' -Args @(${dll}, $dll))
                    $null = Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$dllPath`"", '/setowner', '"NT SERVICE\TrustedInstaller"') -TimeoutSeconds 30 -LogContextKey "DLLRestore-IcaclsOwner-$dll"
                    $null = Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$dllPath`"", '/remove', '*S-1-1-0') -TimeoutSeconds 30 -LogContextKey "DLLRestore-IcaclsRemove-$dll"
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningFailedToRepair0Dll1' -Args @($dll, $($_.Exception.Message)))
                }
            }
            elseif (Test-Path $dllPath) {
                Write-StyledMessage -Type 'Info' -Text ("💭 " + (Get-SourceTextLoc 'toolText.0DllAlreadyPresentInTheOriginalLocation' -Args @($dll)))
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.0DllNotFoundAndNoBackupAvailable' -Args @($dll)))
            }
        }
        Write-StyledMessage -Type 'Info' -Text ("📅 " + (Get-SourceTextLoc 'toolText.rehabilitationOfScheduledTasks'))
        $taskPaths = @(
            '\Microsoft\Windows\InstallService\*'
            '\Microsoft\Windows\UpdateOrchestrator\*'
            '\Microsoft\Windows\UpdateAssistant\*'
            '\Microsoft\Windows\WaaSMedic\*'
            '\Microsoft\Windows\WindowsUpdate\*'
            '\Microsoft\WindowsUpdate\*'
        )
        foreach ($taskPath in $taskPaths) {
            try {
                $tasks = Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue
                foreach ($task in $tasks) {
                    Enable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue *>$null
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.taskEnabled0' -Args @($($task.TaskName)))
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToEnableTaskIn01' -Args @($taskPath, $($_.Exception.Message)))
            }
        }
        Write-StyledMessage -Type 'Info' -Text ("🖨️ " + (Get-SourceTextLoc 'toolText.enablingDriversViaWindowsUpdate'))
        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontPromptForWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontSearchWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DriverUpdateWizardWuSearchEnabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text ("🖨️ " + (Get-SourceTextLoc 'toolText.driversViaWindowsUpdateEnabled'))
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToEnableDriver0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text ("🔄 " + (Get-SourceTextLoc 'toolText.enableWindowsUpdateAutomaticRestart'))
        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text ("🔄 " + (Get-SourceTextLoc 'toolText.windowsUpdateAutomaticRestartEnabled'))
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToEnableAutomaticRestart0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text ("⚙️ " + (Get-SourceTextLoc 'toolText.resetWindowsUpdateSettings'))
        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "BranchReadinessLevel" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferQualityUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text ("⚙️ " + (Get-SourceTextLoc 'toolText.windowsUpdateSettingsReset'))
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToResetSomeSettings0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text ("📋 " + (Get-SourceTextLoc 'toolText.resetWindowsLocalPolicies'))
        try {
            Write-StyledMessage -Type 'Info' -Text ("⏳حذف " + (Get-SourceTextLoc 'toolText.deletingLocalPolicies'))
            $null = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'RD', '/S', '/Q', "`"$(Join-Path $AppConfig.Paths.System32 "GroupPolicy")`"") -TimeoutSeconds 30 -LogContextKey 'GPReset-RD'
            Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.criteriaRemoved'))
            Write-StyledMessage -Type 'Info' -Text ("⏳ " + (Get-SourceTextLoc 'toolText.policyUpdate'))
            $gpResult = Invoke-ExternalCommandWithLog -Command 'gpupdate.exe' -Arguments @('/force') -TimeoutSeconds 60 -LogContextKey 'GPReset-GPUpdate'
            if (-not $gpResult.Success) {
                Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.gpupdateTerminatedWithErrorsOrTimedOut'))
            }
            else {
                Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.updatedCriteria'))
            }
            Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKCU:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKCU:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue *>$null
            Write-StyledMessage -Type 'Success' -Text ("📋 " + (Get-SourceTextLoc 'toolText.windowsLocalPoliciesRestored'))
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.warningUnableToResetSomePolicies0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Success' -Text ("🎉 " + (Get-SourceTextLoc 'toolText.windowsUpdateHasBeenRestoredToDefaultValues'))
        Write-StyledMessage -Type 'Success' -Text ("🔄 " + (Get-SourceTextLoc 'toolText.servicesRegistryAndPoliciesHaveBeenConfiguredSuccessfully'))
        Write-StyledMessage -Type 'Warning' -Text ("⚡ " + (Get-SourceTextLoc 'toolText.noteARebootIsRequiredToFullyApplyAllChanges'))
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Info' -Text ("🔍 " + (Get-SourceTextLoc 'toolText.finalCheckOfTheStatusOfTheServices'))
        $verificationServices = @('wuauserv', 'BITS', 'UsoSvc', 'WaaSMedicSvc')
        foreach ($service in $verificationServices) {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc) {
                $status = if ($svc.Status -eq 'Running') { '🟢 ' + (Get-SourceTextLoc 'sourceText.active').ToUpperInvariant() } else { '🔴 ' + (Get-SourceTextLoc 'sourceText.inactive').ToUpperInvariant() }
                $startup = if ($svc.StartType -eq 'Automatic') { Get-SourceTextLoc 'sourceText.automatic' } elseif ($svc.StartType -eq 'Manual') { Get-SourceTextLoc 'sourceText.manual' } else { [string]$svc.StartType }
                Write-StyledMessage -Type 'Info' -Text ("📊 " + (Get-SourceTextLoc 'toolText.0Status1Starting2' -Args @($service, $status, $startup)))
            }
        }
        Write-StyledMessage -Type 'Info' -Text ("💡 " + (Get-SourceTextLoc 'toolText.windowsUpdateShouldNowWorkNormally'))
        Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.checkByOpeningSettingsUpdateSecurity'))
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Write-StyledMessage -Type 'Success' -Text ("🎉 " + (Get-SourceTextLoc 'toolText.repairCompletedSuccessfully'))
        Write-StyledMessage -Type 'Success' -Text ("💻 " + (Get-SourceTextLoc 'toolText.theSystemRequiresARebootToApplyAllChanges'))
        Write-StyledMessage -Type 'Warning' -Text ("⚡ " + (Get-SourceTextLoc 'toolText.warningTheSystemWillRestartAutomatically'))
        Write-StyledMessage -Type 'Info' -Text ('─' * 60)
        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.preparingToRestartTheSystem') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text '═════════════════════════════════════════════════════════════════'
        Write-StyledMessage -Type 'Error' -Text ("💥 " + (Get-SourceTextLoc 'toolText.criticalError0SeeTheLogInLocalappdataWintoolkitLogsOrIn1' -Args @($($_.Exception.Message), $Global:CurrentLogFile)))
        Write-StyledMessage -Type 'Info' -Text ("⌨️ " + (Get-SourceTextLoc 'toolText.pressAnyKeyToExit'))
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-ToolkitError -Record $_ -ToolName "WinUpdateReset"
    }
    finally {
    }
}
function WinReinstallStore {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "WinReinstallStore" -SubTitle (Get-SourceTextLoc 'script.WinReinstallStore')
    $savedProgressPref = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    function Install-MicrosoftStore {
        Write-StyledMessage -Type 'Info' -Text ("🔄 " + (Get-SourceTextLoc 'toolText.reinstallingMicrosoftStore'))
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.restartMicrosoftStoreServices')
        @('AppXSvc', 'ClipSVC', 'WSService') | ForEach-Object {
            try { Restart-Service $_ -Force -ErrorAction SilentlyContinue *>$null } catch {
                Write-Warning "tools\WinReinstallStore.ps1, Install-MicrosoftStore: $($_.Exception.Message)"
            }
        }
        @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
            (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\INetCache")
        ) | ForEach-Object { Remove-ItemSafely -Path $_ -Recurse }
        $wingetExe = Get-WingetExecutable
        $installMethods = @(
            @{
                Name   = 'Winget Install'
                Action = {
                    if (-not (Test-Path $wingetExe -ErrorAction SilentlyContinue)) { return @{ ExitCode = -1 } }
                    $processResult = Invoke-WithConsoleRedirection -Action {
                        Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.storeInstallationViaWinget') -Command $wingetExe -Arguments @('install', '9WZDNCRFJBMP', '--accept-source-agreements', '--accept-package-agreements', '--silent', '--disable-interactivity') -TimeoutSeconds 300 -LogContextKey "Store-Winget-Install"
                    }
                    return @{ ExitCode = $processResult.ExitCode }
                }
            },
            @{
                Name   = 'AppX Manifest'
                Action = {
                    $store = Get-AppxPackage -AllUsers *WindowsStore* -ErrorAction SilentlyContinue | Select-Object -First 1
                    $manifest = if ($store) { Join-Path $store.InstallLocation 'AppxManifest.xml' } else { $null }
                    if (-not $manifest -or -not (Test-Path $manifest)) { return @{ ExitCode = -1 } }
                    $procResult = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.appxManifestStoreRegistration') -Process -Action {
                        Start-AppxSilentProcess -AppxPath $manifest -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown'
                    } -TimeoutSeconds 120
                    return @{ ExitCode = $procResult.ExitCode }
                }
            },
            @{
                Name   = 'DISM Capability'
                Action = {
                    $result = Invoke-WithConsoleRedirection -Action {
                        Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.addingStoreViaDism') -Command 'DISM' -Arguments @('/Online', '/Add-Capability', '/CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0') -TimeoutSeconds 300 -LogContextKey "Store-DISM-Add"
                    }
                    return @{ ExitCode = $result.ExitCode }
                }
            }
        )
        $success = $false
        foreach ($method in $installMethods) {
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.attemptedVia0' -Args @($($method.Name)))
            try {
                $result = $method.Action.Invoke()
                Clear-ProgressLine
                [Console]::Out.Flush()
                $isSuccess = $result -and ($result.ExitCode -in @(0, 3010, 1638, -1978335189))
                if ($isSuccess) {
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.microsoftStoreReinstalledVia0' -Args @($($method.Name)))
                    $success = $true
                    break
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.method0FailedExitcode1' -Args @($($method.Name), $(if ($result.ExitCode) { $result.ExitCode } else { 'N/A' })))
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.method0Failed1' -Args @($($method.Name), $($_.Exception.Message)))
            }
        }
        if ($success) {
            $null = Invoke-WithConsoleRedirection -Action {
                Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.resettingMicrosoftStoreCache') -Command 'wsreset.exe' -TimeoutSeconds 120 -LogContextKey "Store-WSReset"
            }
            Clear-ProgressLine
            [Console]::Out.Flush()
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.storeCacheReset')
        }
        else {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToReinstallMicrosoftStoreViaAutomaticMethods')
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.emergencyAttemptViaAppxmanifest')
            try {
                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.disasterRecoveryStore') -Process -Action {
                    $ProgressPreference = 'SilentlyContinue'
                    Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object {
                        Start-AppxSilentProcess -AppxPath "$($_.InstallLocation)\AppXManifest.xml" -Flags '-DisableDevelopmentMode -Register -ForceApplicationShutdown'
                    }
                } -TimeoutSeconds 300
                Clear-ProgressLine
                [Console]::Out.Flush()
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.microsoftStoreRestoredViaEmergencyMethod')
                $success = $true
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.disasterRecoveryFailed0' -Args @($($_.Exception.Message)))
            }
        }
        return $success
    }
    function Install-UniGetUI {
        Write-StyledMessage -Type 'Info' -Text ("🔄 " + (Get-SourceTextLoc 'toolText.unigetUiInstallation'))
        $wingetExe = Get-WingetExecutable
        if (-not (Test-Path $wingetExe -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.wingetNotAvailableUnigetUiRequiresWinget')
            return $false
        }
        try {
            foreach ($oldId in @('MartiCliment.UniGetUI', 'Devolutions.UniGetUI')) {
                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.uninstallation0' -Args @($oldId)) -Command $wingetExe -Arguments @('uninstall', '--exact', '--id', $oldId, '--silent', '--disable-interactivity') -TimeoutSeconds 120 -LogContextKey "Store-UniGet-Uninstall"
                Clear-ProgressLine
                [Console]::Out.Flush()
            }
            $processResult = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.unigetUiInstallation') -Command $wingetExe -Arguments @('install', '--exact', '--id', 'Devolutions.UniGetUI', '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements', '--silent', '--disable-interactivity', '--force') -TimeoutSeconds 600 -LogContextKey "Store-UniGet-Install"
            Clear-ProgressLine
            [Console]::Out.Flush()
            $isSuccess = $processResult.ExitCode -in @(0, 3010, 1638, -1978335189)
            if ($isSuccess) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.unigetUiInstalledSuccessfully')
                try {
                    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
                    foreach ($runName in @('WingetUI', 'UniGetUI', 'UniGet UI')) {
                        if (Get-ItemProperty -Path $regPath -Name $runName -ErrorAction SilentlyContinue) {
                            Remove-ItemProperty -Path $regPath -Name $runName -ErrorAction SilentlyContinue *>$null
                            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.autostart0RemovedFromRegistry' -Args @($runName))
                        }
                    }
                    $startupFolder = [Environment]::GetFolderPath('Startup')
                    foreach ($lnkName in @('UniGetUI.lnk', 'WingetUI.lnk', 'UniGet UI.lnk')) {
                        $lnkPath = Join-Path $startupFolder $lnkName
                        if (Test-Path $lnkPath) {
                            Remove-Item $lnkPath -Force -ErrorAction SilentlyContinue *>$null
                            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.autostartLink0Removed' -Args @($lnkName))
                        }
                    }
                }
                catch {
                    Write-Warning "tools\WinReinstallStore.ps1, Install-UniGetUI: $($_.Exception.Message)"
                }
                return $true
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.unigetUiInstallationFinishedWithCode0' -Args @($($processResult.ExitCode))))
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorInstallingUnigetUi0' -Args @($($_.Exception.Message)))
            return $false
        }
    }
    function Invoke-WithConsoleRedirection {
        param([scriptblock]$Action)
        if (-not ('WinReinstallStore.NativeConsole' -as [type])) {
            Add-Type -Namespace 'WinReinstallStore' -Name 'NativeConsole' -MemberDefinition @'
                [DllImport("kernel32.dll")] public static extern bool SetStdHandle(int nStdHandle, IntPtr hHandle);
                [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
                [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
                public static extern IntPtr CreateFileW(
                    string lpFileName, uint dwDesiredAccess, uint dwShareMode,
                    IntPtr lpSecurityAttributes, uint dwCreationDisposition,
                    uint dwFlagsAndAttributes, IntPtr hTemplateFile);
                [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr hObject);
'@
        }
        $STD_OUTPUT = -11
        $STD_ERROR = -12
        $STD_INPUT = -10
        $INVALID_HANDLE_VALUE = [IntPtr]::new(-1)
        $hOrigOut = $null
        $hOrigErr = $null
        $hOrigIn = $null
        $hNullOut = $null
        $hNullIn = $null
        try {
            $hOrigOut = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_OUTPUT)
            $hOrigErr = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_ERROR)
            $hOrigIn = [WinReinstallStore.NativeConsole]::GetStdHandle($STD_INPUT)
        }
        catch {
            return & $Action
        }
        if ($hOrigOut -eq $INVALID_HANDLE_VALUE -or $hOrigOut -eq [IntPtr]::Zero -or
            $hOrigErr -eq $INVALID_HANDLE_VALUE -or $hOrigErr -eq [IntPtr]::Zero) {
            return & $Action
        }
        try {
            $hNullOut = [WinReinstallStore.NativeConsole]::CreateFileW(
                'NUL', 0x40000000, 3, [IntPtr]::Zero, 3, 0x80, [IntPtr]::Zero)
            $hNullIn = [WinReinstallStore.NativeConsole]::CreateFileW(
                'NUL', 0x80000000, 3, [IntPtr]::Zero, 3, 0x80, [IntPtr]::Zero)
        }
        catch {
            return & $Action
        }
        $canRedirect = (
            $hNullOut -ne $INVALID_HANDLE_VALUE -and $hNullOut -ne [IntPtr]::Zero -and
            $hOrigOut -ne $INVALID_HANDLE_VALUE -and $hOrigOut -ne [IntPtr]::Zero -and
            $hOrigErr -ne $INVALID_HANDLE_VALUE -and $hOrigErr -ne [IntPtr]::Zero
        )
        if (-not $canRedirect) {
            return & $Action
        }
        $handlesRedirected = $false
        try {
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_OUTPUT, $hNullOut) *>$null
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_ERROR, $hNullOut) *>$null
            [WinReinstallStore.NativeConsole]::SetStdHandle($STD_INPUT, $hNullIn) *>$null
            $handlesRedirected = $true
            $env:POWERSHELL_TELEMETRY_OPTOUT = '1'
            $ProgressPreference = 'SilentlyContinue'
            return & $Action
        }
        finally {
            if ($handlesRedirected) {
                try {
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_OUTPUT, $hOrigOut) *>$null
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_ERROR, $hOrigErr) *>$null
                    [WinReinstallStore.NativeConsole]::SetStdHandle($STD_INPUT, $hOrigIn) *>$null
                }
                catch {
                    Write-Warning "tools\WinReinstallStore.ps1, Invoke-WithConsoleRedirection 1: $($_.Exception.Message)"
                }
            }
            if ($hNullOut -and $hNullOut -ne $INVALID_HANDLE_VALUE -and $hNullOut -ne [IntPtr]::Zero) {
                try { [WinReinstallStore.NativeConsole]::CloseHandle($hNullOut) *>$null } catch {
                    Write-Warning "tools\WinReinstallStore.ps1, Invoke-WithConsoleRedirection 2: $($_.Exception.Message)"
                }
            }
            if ($hNullIn -and $hNullIn -ne $INVALID_HANDLE_VALUE -and $hNullIn -ne [IntPtr]::Zero) {
                try { [WinReinstallStore.NativeConsole]::CloseHandle($hNullIn) *>$null } catch {
                    Write-Warning "tools\WinReinstallStore.ps1, Invoke-WithConsoleRedirection 3: $($_.Exception.Message)"
                }
            }
        }
    }
    try {
        Write-StyledMessage -Type 'Progress' -Text (Get-SourceTextLoc 'toolText.startingStoreWingetReinstallation')
        $wingetResult = $false
        try {
            $ProgressPreference = 'SilentlyContinue'
            $wingetResult = Invoke-WithConsoleRedirection -Action { Reset-Winget -Force }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unexpectedErrorDuringResetWinget0' -Args @($($_.Exception.Message)))
            Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.resetWingetUnhandledException0' -Args @($($_.Exception.Message)))
        }
        finally {
            $ProgressPreference = $savedProgressPref
        }
        if ($wingetResult) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.wingetRestoredAndOperational')
        }
        else {
            Write-StyledMessage -Type 'Error' -Text ((Get-SourceTextLoc 'toolText.wingetRestoreFailed'))
        }
        $storeResult = Install-MicrosoftStore
        $unigetResult = Install-UniGetUI
        if ($storeResult) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.microsoftStoreSuccessfullyRestored')
        }
        else {
            Write-StyledMessage -Type 'Error' -Text ((Get-SourceTextLoc 'toolText.microsoftStoreNotRestored'))
        }
        if ($unigetResult) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.unigetUiInstalled')
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.unigetUiRequireManualVerification'))
        }
        Write-StyledMessage -Type 'Success' -Text ("🎉 " + (Get-SourceTextLoc 'toolText.operationCompleted'))
    }
    finally {
        $ProgressPreference = $savedProgressPref
    }
    Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.rebootingIn') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
}
function WinBackupDriver {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 10,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "WinBackupDriver" -SubTitle (Get-SourceTextLoc 'script.WinBackupDriver')
    $timeout = 86400
    $script:BackupConfig = @{
        DateTime    = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        BackupDir   = $AppConfig.Paths.DriverBackupTemp
        ArchiveName = "DriverBackup"
        DesktopPath = $AppConfig.Paths.Desktop
        TempPath    = $AppConfig.Paths.TempFolder
        LogsDir     = $AppConfig.Paths.DriverBackupLogs
    }
    $script:FinalArchivePath = "$($script:BackupConfig.DesktopPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).zip"
    function Initialize-BackupEnvironment {
        Write-StyledMessage -Type 'Info' -Text ("🗂️ " + (Get-SourceTextLoc 'toolText.initializingBackupEnvironment'))
        try {
            if (Test-Path $script:BackupConfig.BackupDir) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.removingPreviousBackups')
                $null = Remove-ItemSafely -Path $script:BackupConfig.BackupDir -Recurse
            }
            New-Item -ItemType Directory -Path $script:BackupConfig.BackupDir -Force *>$null
            New-Item -ItemType Directory -Path $script:BackupConfig.LogsDir   -Force *>$null
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.createBackupAndLogDirectories')
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.environmentInitializationError0' -Args @($_))
            return $false
        }
    }
    function Export-SystemDrivers {
        try {
            $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.dismDriverExport') -Command 'dism.exe' `
                -Arguments @('/online', '/export-driver', "/destination:`"$($script:BackupConfig.BackupDir)`"") `
                -TimeoutSeconds $timeout -LogContextKey "Backup-DISM"
            if ($result.TimedOut)       { throw (Get-SourceTextLoc 'toolText.extra.timeoutReachedDuringDismExport') }
            if ($result.ExitCode -ne 0) { throw (Get-SourceTextLoc 'uiText.dismExportFailedWithExitcode0' -Args @($($result.ExitCode))) }
            $exportedDrivers = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
            if (-not $exportedDrivers -or $exportedDrivers.Count -eq 0) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.noThirdPartyDriversFoundToExport')
                Write-StyledMessage -Type 'Info'    -Text ("💡 " + (Get-SourceTextLoc 'toolText.windowsBuiltInDriversAreNotExported'))
                return $true
            }
            $totalSizeMB = [Math]::Round(($exportedDrivers | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.exportCompleted0Driver1Mb' -Args @($($exportedDrivers.Count), $totalSizeMB))
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorExportingDriver0' -Args @($_))
            return $false
        }
    }
    function Compress-BackupArchive {
        if (-not (Test-Path $script:BackupConfig.BackupDir)) {
            throw (Get-SourceTextLoc 'toolText.extra.backupDirectoryNotFound0' -Args @($($script:BackupConfig.BackupDir)))
        }
        Write-StyledMessage -Type 'Info' -Text ("📦 " + (Get-SourceTextLoc 'toolText.preparingArchiveCompression'))
        $backupFiles = Get-ChildItem -Path $script:BackupConfig.BackupDir -Recurse -File -ErrorAction SilentlyContinue
        if (-not $backupFiles) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.noFilesToCompressInBackupDirectory')
            return $null
        }
        $totalSizeMB = [Math]::Round(($backupFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.totalSize0Mb' -Args @($totalSizeMB))
        $archivePath = "$($script:BackupConfig.TempPath)\$($script:BackupConfig.ArchiveName)_$($script:BackupConfig.DateTime).zip"
        $sourcePath  = Join-Path $script:BackupConfig.BackupDir '*'
        $compressionAction = {
            Start-Job -ScriptBlock {
                param([string]$SourcePath, [string]$DestinationPath)
                $ErrorActionPreference = 'Stop'
                Compress-Archive -Path $SourcePath -DestinationPath $DestinationPath `
                    -CompressionLevel Optimal -Force -ErrorAction Stop
                return $true
            } -ArgumentList $sourcePath, $archivePath
        }.GetNewClosure()
        $compressionSucceeded = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.preparingArchiveCompression') `
            -Job -TimeoutSeconds 800 -Action $compressionAction
        if ($compressionSucceeded -eq $true -and (Test-Path $archivePath -PathType Leaf)) {
            $compressedSizeMB  = [Math]::Round((Get-Item $archivePath).Length / 1MB, 2)
            $compressionRatio  = if ($totalSizeMB -gt 0) { [Math]::Round((1 - $compressedSizeMB / $totalSizeMB) * 100, 1) } else { 0 }
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.compressionCompleted0MbReduction1' -Args @($compressedSizeMB, $compressionRatio))
            return $archivePath
        }
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unknownErrorZipFileWasNotCreated')
        return $null
    }
    function Move-ArchiveToDesktop {
        param([string]$ArchivePath)
        if ([string]::IsNullOrWhiteSpace($ArchivePath) -or -not (Test-Path $ArchivePath)) {
            throw (Get-SourceTextLoc 'toolText.extra.invalidArchivePath0' -Args @($ArchivePath))
        }
        Write-StyledMessage -Type 'Info' -Text ("📂 " + (Get-SourceTextLoc 'toolText.movingArchiveToDesktop'))
        try {
            if (-not (Test-Path $script:BackupConfig.DesktopPath)) {
                throw (Get-SourceTextLoc 'toolText.extra2.desktopDirectoryNotAccessible0' -Args @($($script:BackupConfig.DesktopPath)))
            }
            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.removingOldArchive')
                $null = Remove-ItemSafely -Path $script:FinalArchivePath
            }
            Copy-Item -Path $ArchivePath -Destination $script:FinalArchivePath -Force -ErrorAction Stop
            if (Test-Path $script:FinalArchivePath) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.archiveSavedToDesktop')
                Write-StyledMessage -Type 'Info'    -Text (Get-SourceTextLoc 'toolText.location0' -Args @($script:FinalArchivePath))
                return $true
            }
            throw (Get-SourceTextLoc 'uiText.archiveCopyFailed')
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.archiveMoveError0' -Args @($_))
            return $false
        }
    }
    try {
        Write-StyledMessage -Type 'Info' -Text ("🚀 " + (Get-SourceTextLoc 'toolText.systemInitialization'))
        Start-Sleep -Seconds 1
        if (-not (Initialize-BackupEnvironment)) { return }
        if (-not (Export-SystemDrivers))         { return }
        $compressedArchive = Compress-BackupArchive
        if (-not $compressedArchive) { return }
        if (Move-ArchiveToDesktop -ArchivePath $compressedArchive) {
            Write-StyledMessage -Type 'Success' -Text ("🎉 " + (Get-SourceTextLoc 'toolText.driverBackupCompletedSuccessfully'))
            Write-StyledMessage -Type 'Info'    -Text ("📁 " + (Get-SourceTextLoc 'toolText.finalArchive0' -Args @($script:FinalArchivePath)))
            Write-StyledMessage -Type 'Info'    -Text ("💾 " + (Get-SourceTextLoc 'toolText.canBeUsedToReinstallAllDriversWithoutRedownloadingThem'))
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinBackupDriver" -Message (Get-SourceTextLoc 'toolText.extra.criticalErrorDuringBackup')
        Write-StyledMessage -Type 'Info' -Text ("💡 " + (Get-SourceTextLoc 'toolText.checkTheLogsForTechnicalDetails'))
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text ("🧹 " + (Get-SourceTextLoc 'toolText.temporaryEnvironmentCleaning'))
        $null = Remove-ItemSafely -Path $script:BackupConfig.BackupDir -Recurse
        Write-StyledMessage -Type 'Success' -Text ("🎯 " + (Get-SourceTextLoc 'toolText.driverBackupToolkitFinished'))
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.winbackupdriverSessionEnded')
    }
}
function WinDriverInstall {}
function WinDebloat {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "WinDebloat" -SubTitle (Get-SourceTextLoc 'uiText.windebloatToolkit')
    $DebloatServices = @(
    )
    $rebootRequired = $false
    function Invoke-ServiceOptimization {
        param([hashtable]$ServiceConfig)
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.serviceOptimization01' -Args @($($ServiceConfig.Name), $($ServiceConfig.Description)))
        try {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.service0OptimizedSuccessfully' -Args @($($ServiceConfig.Name)))
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorOptimizing01' -Args @($($ServiceConfig.Name), $($_.Exception.Message)))
            return $false
        }
    }
    try {
        Write-StyledMessage -Type 'Info' -Text ("🚀 " + (Get-SourceTextLoc 'toolText.startingServiceDebloatProcess'))
        foreach ($service in $DebloatServices) { Invoke-ServiceOptimization -ServiceConfig $service }
        Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.debloatOperationsCompleted'))
        if ($rebootRequired) {
            Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.rebootToApplyChanges') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinDebloat"
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text ("♻️ " + (Get-SourceTextLoc 'toolText.resourceCleanupAndWindebloatSessionShutdown'))
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.windebloatSessionEnded')
    }
}
function WinCleaner {
    [CmdletBinding()]
    param(
        [ValidateRange(0, 300)]
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    $script:WinCleanerLog = @()
    function Add-CleanerLog {
        param(
            [Parameter(Mandatory = $true, Position = 0)]
            [ValidateSet('Success', 'Info', 'Warning', 'Error', 'Question')]
            [string]$Type,
            [Parameter(Mandatory = $true, Position = 1)]
            [string]$Text
        )
        Clear-ProgressLine
        $script:WinCleanerLog += @{
            Timestamp = Get-Date -Format "HH:mm:ss"
            Type      = $Type
            Text      = $Text
        }
        Write-StyledMessage -Type $Type -Text $Text
    }
    Start-ToolkitSession -ToolName "WinCleaner" -SubTitle (Get-SourceTextLoc 'script.WinCleaner')
    $timeout = 86400
    $ProgressPreference = 'Continue'
    $VitalExclusions = @(
        "$env:LOCALAPPDATA\WinToolkit"
    )
    function Test-VitalExclusion {
        param([string]$Path)
        if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
        $fullPath = $Path -replace '"', ''
        try {
            if (-not [System.IO.Path]::IsPathRooted($fullPath)) {
                $fullPath = Join-Path (Get-Location) $fullPath
            }
            foreach ($excluded in $VitalExclusions) {
                if ($fullPath -like "$excluded*" -or $fullPath -eq $excluded) {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'uiText.lifeProtectionActivated0' -Args @($fullPath))
                    return $true
                }
            }
        }
        catch { return $false }
        return $false
    }
    function Invoke-CommandAction {
        param($Rule)
        $displayName = if ($Rule.NameKey) { Get-SourceTextLoc $Rule.NameKey } else { $Rule.Name }
        Clear-ProgressLine
        Write-StyledMessage -Type 'Info' -Text ("🚀 " + (Get-SourceTextLoc 'toolText.commandExecution0' -Args @($displayName)))
        try {
            $result = Invoke-WithSpinner -Activity $displayName -Command $Rule.Command -Arguments $Rule.Args -TimeoutSeconds $timeout -LogContextKey "Cleaner-$($Rule.Name)"
            if ($result.TimedOut) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.commandTimesOutAfter0Hours' -Args @($($timeout/3600)))
                return $true
            }
            if ($result.ExitCode -eq -2146498554 -or $result.ExitCode -eq 0x800F0818) {
                Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.attentionYouAreCleaningWithWindowsUpdateInProgressRefreshYourSystemAndTryAgainToPerformAFu')
                return $false
            }
            $isSuccess = ($result.ExitCode -eq 0)
            $messageType = if ($isSuccess) { 'Info' } else { 'Warning' }
            $messageText = if ($isSuccess) {
                Get-SourceTextLoc 'toolText.extra.commandCompleted'
            }
            else {
                Get-SourceTextLoc 'toolText.extra.commandCompletedWithCode0' -Args @($result.ExitCode)
            }
            Add-CleanerLog -Type $messageType -Text $messageText
            return $true
        }
        catch {
            Add-CleanerLog -Type 'Error' -Text (Get-SourceTextLoc 'toolText.extra.commandError0' -Args @($_))
            return $false
        }
    }
    function Invoke-ServiceAction {
        param($Rule)
        $svcName = $Rule.ServiceName
        $action = $Rule.Action
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if (-not $svc) { return $true }
            if ($action -eq 'Stop' -and $svc.Status -eq 'Running') {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.stoppingService0' -Args @($svcName))
                Stop-Service -Name $svcName -Force -ErrorAction Stop *>$null
            }
            elseif ($action -eq 'Start' -and $svc.Status -ne 'Running') {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.startingService0' -Args @($svcName))
                Start-Service -Name $svcName -ErrorAction Stop *>$null
            }
            return $true
        }
        catch {
            Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.serviceError01' -Args @($svcName, $_))
            return $false
        }
    }
    function Remove-FileItem {
        param($Rule)
        $displayName = Get-SourceTextLoc $Rule.NameKey
        $paths = $Rule.Paths
        $isPerUser = $Rule.PerUser
        $filesOnly = $Rule.FilesOnly
        $takeOwn = $Rule.TakeOwnership
        $targetPaths = @()
        if ($isPerUser) {
            $users = Get-LocalUserProfiles
            foreach ($user in $users) {
                foreach ($p in $paths) {
                    $targetPaths += $p -replace '%USERPROFILE%', $user.FullName `
                        -replace '%APPDATA%', "$($user.FullName)\AppData\Roaming" `
                        -replace '%LOCALAPPDATA%', "$($user.FullName)\AppData\Local" `
                        -replace '%TEMP%', "$($user.FullName)\AppData\Local\Temp"
                }
            }
        }
        else {
            foreach ($p in $paths) { $targetPaths += [Environment]::ExpandEnvironmentVariables($p) }
        }
        $count = 0
        foreach ($path in $targetPaths) {
            if (Test-VitalExclusion $path) { continue }
            if (-not (Test-Path $path)) { continue }
            try {
                if ($takeOwn) {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'uiText.takingOwnershipFor0' -Args @($path))
                    $null = & cmd /c "takeown /F `"$path`" /R /A >nul 2>&1"
                    $adminSID = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
                    $adminAccount = $adminSID.Translate([System.Security.Principal.NTAccount]).Value
                    $null = & cmd /c "icacls `"$path`" /T /grant `"${adminAccount}:F`" >nul 2>&1"
                }
                if ($filesOnly) {
                    $files = Get-ChildItem -Path $path -File -Force -ErrorAction SilentlyContinue
                    foreach ($file in $files) {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    }
                }
                else {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                }
                $count++
            }
            catch {
                Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.removalError01' -Args @($path, $_))
            }
        }
        if ($count -gt 0) { Write-StyledMessage -Type 'Success' -Text ("🗑️ " + (Get-SourceTextLoc 'toolText.cleaned0ItemsIn1' -Args @($count, $displayName))) }
        return $true
    }
    function Remove-RegistryItem {
        param($Rule)
        $keys = $Rule.Keys
        $recursive = $Rule.Recursive
        $valuesOnly = $Rule.ValuesOnly
        foreach ($rawKey in $keys) {
            $key = $rawKey -replace '^(HKCU|HKLM):\\*', '$1:\'
            if (-not (Test-Path $key)) { continue }
            try {
                if ($valuesOnly) {
                    $item = Get-Item $key -ErrorAction Stop
                    $item.GetValueNames() | ForEach-Object {
                        if ($_ -ne '(default)') { Remove-ItemProperty -LiteralPath $key -Name $_ -Force -ErrorAction SilentlyContinue *>$null }
                    }
                    if ($recursive) {
                        Get-ChildItem $key -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                            $currentKeyPath = $_.PSPath
                            $_.GetValueNames() | ForEach-Object { Remove-ItemProperty -LiteralPath $currentKeyPath -Name $_ -Force -ErrorAction SilentlyContinue *>$null }
                        }
                    }
                    Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'uiText.cleanedValuesIn0' -Args @($key))
                }
                else {
                    Remove-Item -Path $key -Recurse:$recursive -Force -ErrorAction Stop
                    Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra.removedKey0' -Args @($key))
                }
            }
            catch {
                Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.registerError01' -Args @($key, $_))
            }
        }
        return $true
    }
    function Set-RegistryItem {
        param($Rule)
        $key = $Rule.Key -replace '^(HKCU|HKLM):', '$1:\'
        try {
            Set-RegistryValue -Path $key -Name $Rule.ValueName -Value $Rule.ValueData -Type $Rule.ValueType
            Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra2.set01' -Args @($key, $($Rule.ValueName)))
            return $true
        }
        catch { return $false }
    }
    function Invoke-WinCleanerRule {
        param($Rule)
        Clear-ProgressLine
        switch ($Rule.Type) {
            'File' { return Remove-FileItem -Rule $Rule }
            'Registry' { return Remove-RegistryItem -Rule $Rule }
            'RegSet' { return Set-RegistryItem -Rule $Rule }
            'Service' { return Invoke-ServiceAction -Rule $Rule }
            'Command' { return Invoke-CommandAction -Rule $Rule }
            'ScriptBlock' {
                if ($Rule.ScriptBlock) {
                    & $Rule.ScriptBlock
                    return $true
                }
            }
            'Custom' {
                if ($Rule.ScriptBlock) {
                    & $Rule.ScriptBlock
                    return $true
                }
            }
        }
        return $true
    }
    $Rules = @(
        @{ Name = "CleanMgr Config"; NameKey = 'cleanerRule.cleanmgrConfig'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleanmgrConfiguration')
                $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
                $opts = @(
                    "Active Setup Temp Folders",
                    "BranchCache",
                    "D3D Shader Cache",
                    "Delivery Optimization Files",
                    'Device Driver Packages',
                    "Downloaded Program Files",
                    "Internet Cache Files",
                    "Memory Dump Files",
                    "Old ChkDsk Files",
                    "Recycle Bin",
                    "Temporary Files",
                    "Thumbnail Cache",
                    "Update Cleanup",
                    "Windows Defender",
                    "Windows Error Reporting Files",
                    "Setup Log Files",
                    "System error memory dump files",
                    "System error minidump files",
                    "Temporary Setup Files",
                    "Windows Upgrade Log Files"
                )
                foreach ($o in $opts) {
                    $p = Join-Path $reg $o
                    if (Test-Path $p) { Set-ItemProperty -Path $p -Name "StateFlags0065" -Value 2 -Type DWORD -Force -ErrorAction SilentlyContinue }
                }
                $cleanMgrExecutionRule = @{
                    Name    = 'Running CleanMgr with /sagerun:65';
                    Type    = "Command";
                    Command = "cleanmgr.exe";
                    Args    = @("/sagerun:65");
                }
                Invoke-CommandAction -Rule $cleanMgrExecutionRule
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra2.waitingForCleanmgrToCompleteMayTakeAFewMinutes')
                $cmDeadline = (Get-Date).AddHours(1)
                while ((Get-Process -Name "cleanmgr" -ErrorAction SilentlyContinue) -and (Get-Date) -lt $cmDeadline) {
                    Start-Sleep -Seconds 10
                }
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleanmgrCompleted')
            }
        }
        @{ Name = "WinSxS Cleanup"; NameKey = 'cleanerRule.winsxsCleanup'; Type = "Command"; Command = "DISM.exe"; Args = @("/Online", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase") }
        @{ Name = "Minimize DISM"; NameKey = 'cleanerRule.minimizeDism'; Type = "RegSet"; Key = "HKLM:\Software\Microsoft\Windows\CurrentVersion\SideBySide\Configuration"; ValueName = "DisableResetbase"; ValueData = 0; ValueType = "DWORD" }
        @{ Name = "Error Reports"; NameKey = 'cleanerRule.errorReports'; Type = "File"; Paths = @(
                "$env:ProgramData\Microsoft\Windows\WER",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\WER"
            ); FilesOnly = $false
        }
        @{ Name = "Clear Event Logs"; NameKey = 'cleanerRule.clearEventLogs'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleaningEventLogsClassicModern')
                $classicLogs = Get-EventLog -List -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Log
                foreach ($logName in $classicLogs) {
                    try {
                        Clear-EventLog -LogName $logName -ErrorAction Stop
                        Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.clearEventlog0' -Args @($logName))
                    }
                    catch {
                        Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.clearEventlog01' -Args @($logName, $($_.Exception.Message)))
                    }
                }
                $wevtErr = $null
                & wevtutil sl 'Microsoft-Windows-LiveId/Operational' /ca:'O:BAG:SYD:(A;;0x1;;;SY)(A;;0x5;;;BA)(A;;0x1;;;LA)' 2>&1 | Out-String -OutVariable wevtErr *>$null
                if ($wevtErr) { Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.wevtutilSlOutput0' -Args @($wevtErr)) }
                Get-WinEvent -ListLog * -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    $logName = $_.LogName
                    if ($_.LogType -in 'Analytical', 'Debug') {
                        Wevtutil.exe sl $logName /e:false *>$null
                    }
                    $clErr = $null
                    Wevtutil.exe cl $logName 2>&1 | Out-String -OutVariable clErr *>$null
                    if ($LASTEXITCODE -ne 0 -and $clErr) { Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.wevtutilCl01' -Args @($logName, $clErr)) }
                }
                Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'uiText.classicAndModernEventLogsDeleted')
            }
        }
        @{ Name = "Clear Windows Update cache"; NameKey = 'cleanerRule.clearWindowsUpdateCache'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.windowsUpdateCacheCleaner')
                $services = @("wuauserv", "bits")
                foreach ($s in $services) {
                    Invoke-ServiceAction -Rule @{ ServiceName = $s; Action = "Stop" }
                }
                $paths = @(
                    "C:\Windows\SoftwareDistribution\Download",
                    "C:\Windows\SoftwareDistribution\DataStore"
                )
                foreach ($p in $paths) {
                    if (Test-Path $p) {
                        try {
                            Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.removal02' -Args @($p))
                            Remove-Item -Path "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.unableToCleanCompletely0' -Args @($p))
                        }
                    }
                }
                foreach ($s in $services) {
                    Invoke-ServiceAction -Rule @{ ServiceName = $s; Action = "Start" }
                }
                Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'uiText.windowsUpdateCacheCleared')
            }
        }
        @{ Name = "Windows App/Download Cache - User"; NameKey = 'cleanerRule.windowsAppDownloadCacheUser'; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Microsoft\Windows\AppCache",
                "%LOCALAPPDATA%\Microsoft\Windows\Caches"
            ); PerUser = $true; FilesOnly = $true
        }
        @{ Name = "System Restore Points"; NameKey = 'cleanerRule.systemRestorePoints'; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleanSystemRestorePoints')
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.analysisAndCleaningOfShadowCopiesKeepLatest')
                    try {
                        $shadows = Get-CimInstance -ClassName Win32_ShadowCopy -ErrorAction Stop | Sort-Object InstallDate -Descending
                        if ($shadows.Count -gt 1) {
                            $toDelete = $shadows | Select-Object -Skip 1
                            $count = $toDelete.Count
                            Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.0ShadowCopiesDetectedRemovingOld1' -Args @($($shadows.Count), $count))
                            foreach ($shadow in $toDelete) {
                                Remove-CimInstance -InputObject $shadow -ErrorAction SilentlyContinue
                            }
                            Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra2.oldShadowCopiesRemovedLastPreservedCopy')
                        }
                        elseif ($shadows.Count -eq 1) {
                            Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.onlyOneShadowCopyFoundNoRemovalNecessary')
                        }
                        else {
                            Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.noShadowCopyDetected')
                        }
                    }
                    catch {
                        Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.shadowCopyManagementError0' -Args @($_))
                    }
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.systemProtectionKeptActiveForSafety')
                    Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra.restorePointCleanupCompleted')
                }
                catch {
                    Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.errorCleaningRestorePoints0' -Args @($($_.Exception.Message)))
                }
            }
        }
        @{ Name = "Cleanup - Windows Prefetch Cache"; NameKey = 'cleanerRule.cleanupWindowsPrefetchCache'; Type = "File"; Paths = @("C:\WINDOWS\Prefetch"); FilesOnly = $false }
        @{ Name = "Cleanup - Explorer Thumbnail/Icon Cache"; NameKey = 'cleanerRule.cleanupExplorerThumbnailIconCache'; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\Explorer"); PerUser = $true; FilesOnly = $true; TakeOwnership = $true }
        @{ Name = "WinInet Cache - User"; NameKey = 'cleanerRule.wininetCacheUser'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleanupWininetWebcacheCache')
                $cacheTaskDisabled = $false
                try {
                    $ct = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Wininet\' -TaskName 'CacheTask' -ErrorAction SilentlyContinue
                    if ($ct -and $ct.State -ne 'Disabled') {
                        Stop-ScheduledTask -TaskPath '\Microsoft\Windows\Wininet\' -TaskName 'CacheTask' -ErrorAction SilentlyContinue
                        Disable-ScheduledTask -TaskPath '\Microsoft\Windows\Wininet\' -TaskName 'CacheTask' -ErrorAction SilentlyContinue *>$null
                        $cacheTaskDisabled = $true
                        Start-Sleep -Seconds 2
                    }
                }
                catch { Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.cachetaskDisableError0' -Args @($_)) }
                $users = Get-LocalUserProfiles
                foreach ($u in $users) {
                    $paths = @(
                        "$($u.FullName)\AppData\Local\Microsoft\Windows\INetCache\IE",
                        "$($u.FullName)\AppData\Local\Microsoft\Windows\WebCache",
                        "$($u.FullName)\AppData\Local\Microsoft\Feeds Cache",
                        "$($u.FullName)\AppData\Local\Microsoft\InternetExplorer\DOMStore",
                        "$($u.FullName)\AppData\Local\Microsoft\Internet Explorer"
                    )
                    foreach ($p in $paths) {
                        if (-not (Test-Path $p)) { continue }
                        Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
                        if (Test-Path $p) {
                            Get-ChildItem -Path $p -Recurse -File -Force -ErrorAction SilentlyContinue |
                                ForEach-Object { Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue }
                            Get-ChildItem -Path $p -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                                Sort-Object { $_.FullName.Length } -Descending |
                                ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
                        }
                    }
                }
                if ($cacheTaskDisabled) {
                    try {
                        Enable-ScheduledTask -TaskPath '\Microsoft\Windows\Wininet\' -TaskName 'CacheTask' -ErrorAction SilentlyContinue *>$null
                    }
                    catch { Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.cachetaskEnableError0' -Args @($_)) }
                }
                Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'uiText.cleanWininetWebcache')
            }
        }
        @{ Name = "Temporary Internet Files"; NameKey = 'cleanerRule.temporaryInternetFiles'; Type = "File"; Paths = @(
                "%USERPROFILE%\Local Settings\Temporary Internet Files"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Cache/History Cleanup"; NameKey = 'cleanerRule.cacheHistoryCleanup'; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "8") }
        @{ Name = "Form Data Cleanup"; NameKey = 'cleanerRule.formDataCleanup'; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "2") }
        @{ Name = "Internet Cookies Cleanup"; NameKey = 'cleanerRule.internetCookiesCleanup'; Type = "File"; Paths = @(
                "%APPDATA%\Microsoft\Windows\Cookies",
                "%LOCALAPPDATA%\Microsoft\Windows\INetCookies"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Cookies Cleanup"; NameKey = 'cleanerRule.cookiesCleanup'; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "1") }
        @{ Name = "Chromium Browsers Cache (Chrome, Edge, Brave, Vivaldi)"; NameKey = 'cleanerRule.chromiumBrowsersCacheChromeEdgeBraveVivaldi'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.chromiumBrowserCacheCleaner')
                $browsers = @(
                    @{ Name = "Google Chrome"; Path = "Google\Chrome\User Data" },
                    @{ Name = "Microsoft Edge"; Path = "Microsoft\Edge\User Data" },
                    @{ Name = "Brave Browser"; Path = "BraveSoftware\Brave-Browser\User Data" },
                    @{ Name = "Vivaldi"; Path = "Vivaldi\User Data" }
                )
                $users = Get-LocalUserProfiles
                foreach ($u in $users) {
                    foreach ($b in $browsers) {
                        $userDataPath = Join-Path "$($u.FullName)\AppData\Local" $b.Path
                        if (Test-Path $userDataPath) {
                            $patterns = @(
                                "$userDataPath\*\Cache",
                                "$userDataPath\*\Code Cache",
                                "$userDataPath\*\GPUCache",
                                "$userDataPath\*\ShaderCache",
                                "$userDataPath\CrashReports"
                            )
                            foreach ($p in $patterns) {
                                Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                }
            }
        }
        @{ Name = "Google Chrome AI OptGuide Model"; NameKey = 'cleanerRule.googleChromeAiOptguideModel'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleaningAndDisablingAiChromeOptguide')
                $users = Get-LocalUserProfiles
                foreach ($u in $users) {
                    $optGuidePath = Join-Path "$($u.FullName)\AppData\Local" "Google\Chrome\User Data\OptGuideOnDeviceModel"
                    if (Test-Path $optGuidePath) {
                        try {
                            Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.removingOptguideFolder0' -Args @($optGuidePath))
                            Remove-Item -Path $optGuidePath -Recurse -Force -ErrorAction Stop
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.removalError01' -Args @($optGuidePath, $_))
                        }
                    }
                    try {
                        if (-not (Test-Path $optGuidePath)) {
                            New-Item -Path $optGuidePath -ItemType Directory -Force -ErrorAction Stop *>$null
                        }
                        $acl = Get-Acl -Path $optGuidePath -ErrorAction Stop
                        $acl.SetAccessRuleProtection($true, $false)
                        $denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                            "Everyone", "Write", "ContainerInherit,ObjectInherit", "None", "Deny"
                        )
                        $acl.AddAccessRule($denyRule)
                        Set-Acl -Path $optGuidePath -AclObject $acl -ErrorAction Stop
                        Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra.optguideFolderSetToReadOnly0' -Args @($optGuidePath))
                    }
                    catch {
                        Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.readOnlySettingErrorFor01' -Args @($optGuidePath, $_))
                    }
                }
                $chromePolicyKey = "HKLM:\SOFTWARE\Policies\Google\Chrome"
                try {
                    if (-not (Test-Path $chromePolicyKey)) {
                        New-Item -Path $chromePolicyKey -Force -ErrorAction Stop *>$null
                    }
                    $aiPolicies = @{
                        "GenAILocalFoundationalModelSettings" = 1
                        "AIModeSettings" = 2
                        "GeminiSettings" = 1
                        "HelpMeWriteSettings" = 2
                        "DevToolsGenAiSettings" = 2
                    }
                    foreach ($policy in $aiPolicies.GetEnumerator()) {
                        Set-ItemProperty -Path $chromePolicyKey -Name $policy.Key -Value $policy.Value -Type DWORD -Force -ErrorAction Stop
                        Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'uiText.chromePolicySet01' -Args @($($policy.Key), $($policy.Value)))
                    }
                }
                catch {
                    Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.chromeAiPolicySettingError0' -Args @($_))
                }
            }
        }
        @{ Name = "Firefox Browser Cache"; NameKey = 'cleanerRule.firefoxBrowserCache'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleaningFirefoxCacheCrashes')
                $users = Get-LocalUserProfiles
                foreach ($u in $users) {
                    $cleanPaths = @(
                        "$($u.FullName)\AppData\Local\Mozilla\Firefox\Profiles",
                        "$($u.FullName)\AppData\Local\Mozilla\Firefox\Crash Reports"
                    )
                    foreach ($p in $cleanPaths) {
                        if (Test-Path $p) { Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                    $msStoreProfiles = Get-ChildItem `
                        "$($u.FullName)\AppData\Local\Packages" `
                        -Directory -Filter "Mozilla.Firefox_*" `
                        -ErrorAction SilentlyContinue
                    foreach ($pkg in $msStoreProfiles) {
                        $msCache = "$($pkg.FullName)\LocalCache\Roaming\Mozilla\Firefox\Profiles"
                        if (Test-Path $msCache) { Remove-Item -Path $msCache -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                }
            }
        }
        @{ Name = "Edge Legacy (HTML) Cache"; NameKey = 'cleanerRule.edgeLegacyHtmlCache'; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC\*\MicrosoftEdge\Cache",
                "%LOCALAPPDATA%\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC\#!001\MicrosoftEdge\Cache"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Opera & Java Cache"; NameKey = 'cleanerRule.operaJavaCache'; Type = "File"; Paths = @(
                "%USERPROFILE%\Local Settings\Application Data\Opera\Opera",
                "%LOCALAPPDATA%\Opera\Opera",
                "%APPDATA%\Opera\Opera",
                "%APPDATA%\Sun\Java\Deployment\cache"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "DNS Flush"; NameKey = 'cleanerRule.dnsFlush'; Type = "Command"; Command = "ipconfig"; Args = @("/flushdns") }
        @{ Name = "System Temp Files"; NameKey = 'cleanerRule.systemTempFiles'; Type = "File"; Paths = @("C:\WINDOWS\Temp"); FilesOnly = $false }
        @{ Name = "User Temp Files"; NameKey = 'cleanerRule.userTempFiles'; Type = "File"; Paths = @(
                "%USERPROFILE%\AppData\Local\Temp",
                "%USERPROFILE%\AppData\LocalLow\Temp"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Service Profiles Temp"; NameKey = 'cleanerRule.serviceProfilesTemp'; Type = "File"; Paths = @("%SYSTEMROOT%\ServiceProfiles\LocalService\AppData\Local\Temp"); FilesOnly = $false }
        @{ Name = "System & Component Logs"; NameKey = 'cleanerRule.systemComponentLogs'; Type = "File"; Paths = @(
                "C:\WINDOWS\Logs",
                "C:\WINDOWS\System32\LogFiles",
                "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
                "%SYSTEMROOT%\Logs\waasmedic",
                "%SYSTEMROOT%\Logs\SIH",
                "%SYSTEMROOT%\Logs\NetSetup",
                "%SYSTEMROOT%\System32\LogFiles\setupcln",
                "%SYSTEMROOT%\Panther",
                "%SYSTEMROOT%\comsetup.log",
                "%SYSTEMROOT%\DtcInstall.log",
                "%SYSTEMROOT%\PFRO.log",
                "%SYSTEMROOT%\setupact.log",
                "%SYSTEMROOT%\setuperr.log",
                "%SYSTEMROOT%\inf\setupapi.app.log",
                "%SYSTEMROOT%\inf\setupapi.dev.log",
                "%SYSTEMROOT%\inf\setupapi.offline.log",
                "%SYSTEMROOT%\Performance\WinSAT\winsat.log",
                "%SYSTEMROOT%\debug\PASSWD.LOG"
            ); FilesOnly = $true
        }
        @{ Name = "User Registry History - Values Only"; NameKey = 'cleanerRule.userRegistryHistoryValuesOnly'; Type = "Registry"; Keys = @(
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRULegacy",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Paint\Recent File List",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Wordpad\Recent File List",
                "HKCU:\Software\Microsoft\MediaPlayer\Player\RecentFileList",
                "HKCU:\Software\Microsoft\MediaPlayer\Player\RecentURLList",
                "HKCU:\Software\Gabest\Media Player Classic\Recent File List",
                "HKCU:\Software\Microsoft\Direct3D\MostRecentApplication",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths",
                "HKCU:\Software\Microsoft\Search Assistant\ACMru",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\SearchHistory",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Map Network Drive MRU"
            ); ValuesOnly = $true; Recursive = $true
        }
        @{ Name = "Adobe Media Browser Key"; NameKey = 'cleanerRule.adobeMediaBrowserKey'; Type = "Registry"; Keys = @("HKCU:\Software\Adobe\MediaBrowser\MRU"); ValuesOnly = $false }
        @{ Name = "Developer Telemetry & Traces"; NameKey = 'cleanerRule.developerTelemetryTraces'; Type = "File"; Paths = @(
                "%USERPROFILE%\.dotnet\TelemetryStorageService",
                "%LOCALAPPDATA%\Microsoft\CLR_v4.0\UsageTraces",
                "%LOCALAPPDATA%\Microsoft\CLR_v4.0_32\UsageTraces",
                "%LOCALAPPDATA%\Microsoft\VSCommon\14.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSCommon\15.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSCommon\16.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSCommon\17.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSApplicationInsights",
                "%TEMP%\Microsoft\VSApplicationInsights",
                "%APPDATA%\vstelemetry",
                "%TEMP%\VSFaultInfo",
                "%TEMP%\VSFeedbackPerfWatsonData",
                "%TEMP%\VSFeedbackVSRTCLogs",
                "%TEMP%\VSFeedbackIntelliCodeLogs",
                "%TEMP%\VSRemoteControl",
                "%TEMP%\Microsoft\VSFeedbackCollector",
                "%TEMP%\VSTelem",
                "%TEMP%\VSTelem.Out",
                "%PROGRAMDATA%\Microsoft\VSApplicationInsights",
                "%PROGRAMDATA%\vstelemetry"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Visual Studio Licenses"; NameKey = 'cleanerRule.visualStudioLicenses'; Type = "Registry"; Keys = @(
                "HKLM:\SOFTWARE\Classes\Licenses\77550D6B-6352-4E77-9DA3-537419DF564B",
                "HKLM:\SOFTWARE\Classes\Licenses\E79B3F9C-6543-4897-BBA5-5BFB0A02BB5C",
                "HKLM:\SOFTWARE\Classes\Licenses\4D8CFBCB-2F6A-4AD2-BABF-10E28F6F2C8F",
                "HKLM:\SOFTWARE\Classes\Licenses\5C505A59-E312-4B89-9508-E162F8150517",
                "HKLM:\SOFTWARE\Classes\Licenses\41717607-F34E-432C-A138-A3CFD7E25CDA",
                "HKLM:\SOFTWARE\Classes\Licenses\B16F0CF0-8AD1-4A5B-87BC-CB0DBE9C48FC",
                "HKLM:\SOFTWARE\Classes\Licenses\10D17DBA-761D-4CD8-A627-984E75A58700",
                "HKLM:\SOFTWARE\Classes\Licenses\1299B4B9-DFCC-476D-98F0-F65A2B46C96D"
            ); ValuesOnly = $false
        }
        @{ Name = "Search History Files"; NameKey = 'cleanerRule.searchHistoryFiles'; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\ConnectedSearch\History"); PerUser = $true }
        @{ Name = "Print Queue (Spooler)"; NameKey = 'cleanerRule.printQueueSpooler'; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.printQueueCleaningSpooler')
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.stoppingSpoolerService')
                    Stop-Service -Name Spooler -Force -ErrorAction Stop *>$null
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.spoolerServiceStopped')
                    Start-Sleep -Seconds 2
                    $printersPath = 'C:\WINDOWS\System32\spool\PRINTERS'
                    if (Test-Path $printersPath) {
                        $files = Get-ChildItem -Path $printersPath -Force -ErrorAction SilentlyContinue
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleanPrintQueueIn01FilesRemoved' -Args @($printersPath, $($files.Count)))
                    }
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.restartingSpoolerService')
                    Start-Service -Name Spooler -ErrorAction Stop *>$null
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.spoolerServiceRestarted')
                    Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra2.printQueueSpoolerCleanedAndRestartedSuccessfully')
                }
                catch {
                    Start-Service -Name Spooler -ErrorAction SilentlyContinue
                    Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.errorCleaningSpooler0' -Args @($($_.Exception.Message)))
                }
            }
        }
        @{ Name = "Stop DPS"; NameKey = 'cleanerRule.stopDps'; Type = "Service"; ServiceName = "DPS"; Action = "Stop" }
        @{ Name = "SRUM Data"; NameKey = 'cleanerRule.srumData'; Type = "File"; Paths = @("%SYSTEMROOT%\System32\sru\SRUDB.dat"); FilesOnly = $true; TakeOwnership = $true }
        @{ Name = "Start DPS"; NameKey = 'cleanerRule.startDps'; Type = "Service"; ServiceName = "DPS"; Action = "Start" }
        @{ Name = "Listary Index"; NameKey = 'cleanerRule.listaryIndex'; Type = "File"; Paths = @("%APPDATA%\Listary\UserData"); PerUser = $true }
        @{ Name = "WinUtil Data"; NameKey = 'cleanerRule.winutilData'; Type = "File"; Paths = @("%LOCALAPPDATA%\winutil"); PerUser = $true }
        @{ Name = "Flash Player Traces"; NameKey = 'cleanerRule.flashPlayerTraces'; Type = "File"; Paths = @("%APPDATA%\Macromedia\Flash Player"); PerUser = $true }
        @{ Name = "Enhanced DiagTrack Management"; NameKey = 'cleanerRule.enhancedDiagtrackManagement'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.improvedManagementOfDiagtrackService')
                function Get-StateFilePath($BaseName, $Suffix) {
                    $escapedBaseName = $BaseName.Split([IO.Path]::GetInvalidFileNameChars()) -Join '_'
                    $uniqueFilename = $escapedBaseName, $Suffix -Join '-'
                    $path = [IO.Path]::Combine($env:APPDATA, 'WinToolkit', 'state', $uniqueFilename)
                    return $path
                }
                function Get-UniqueStateFilePath($BaseName) {
                    $suffix = New-Guid
                    $path = Get-StateFilePath -BaseName $BaseName -Suffix $suffix
                    if (Test-Path -Path $path) {
                        Write-Verbose "Path collision detected at: '$path'. Generating new path."
                        return Get-UniqueStateFilePath $serviceName
                    }
                    return $path
                }
                function New-EmptyFile($Path) {
                    $parentDirectory = [System.IO.Path]::GetDirectoryName($Path)
                    if (-not (Test-Path $parentDirectory -PathType Container)) {
                        try { New-Item -ItemType Directory -Path $parentDirectory -Force -ErrorAction Stop *>$null }
                        catch { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.failedToCreateParentDirectory0' -Args @($_)); return $false }
                    }
                    try { New-Item -ItemType File -Path $Path -Force -ErrorAction Stop *>$null; return $true }
                    catch { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.failedToCreateFile0' -Args @($_)); return $false }
                }
                $serviceName = 'DiagTrack'
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.checkServiceStatus0' -Args @($serviceName))
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if (-not $service) {
                    Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.service0NotFoundSkip' -Args @($serviceName))
                    return
                }
                if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.service0ActiveStopping' -Args @($serviceName))
                    try {
                        $service | Stop-Service -Force -ErrorAction Stop
                        $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped, [TimeSpan]::FromSeconds(30))
                        $path = Get-UniqueStateFilePath $serviceName
                        if (New-EmptyFile $path) {
                            Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra.serviceStoppedAndStateSavedAutoRestartEnabled')
                        }
                        else {
                            Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.serviceStoppedManualRestartRequired')
                        }
                    }
                    catch { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorStoppingService0' -Args @($_)) }
                }
                else {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.service0DownCheckRestart' -Args @($serviceName))
                    $fileGlob = Get-StateFilePath -BaseName $serviceName -Suffix '*'
                    $stateFiles = Get-ChildItem -Path $fileGlob -ErrorAction SilentlyContinue
                    if ($stateFiles.Count -eq 1) {
                        try {
                            Remove-Item -Path $stateFiles[0].FullName -Force -ErrorAction Stop
                            $service | Start-Service -ErrorAction Stop
                            Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra.service0RestartedSuccessfully' -Args @($serviceName))
                        }
                        catch { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorRestartingService0' -Args @($_)) }
                    }
                    elseif ($stateFiles.Count -gt 1) {
                        Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.multipleStateFilesFoundServiceWillNotBeRestartedAutomatically')
                    }
                    else {
                        Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.service0WasNotActivePreviously' -Args @($serviceName))
                    }
                }
            }
        }
        @{ Name = "Credential Manager"; NameKey = 'cleanerRule.credentialManager'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleaningCredentials')
                $cmdkeyErr = $null
                $targets = & cmdkey /list 2>&1 | Tee-Object -Variable cmdkeyErr | Where-Object { $_ -match '^Target:' }
                if ($cmdkeyErr -and $LASTEXITCODE -ne 0) { Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.cmdkeyListError0' -Args @($cmdkeyErr)) }
                $targets | ForEach-Object {
                    $t = $_.Split(':')[1].Trim()
                    $delErr = $null
                    & cmdkey /delete:$t 2>&1 | Tee-Object -Variable delErr *>$null
                    if ($delErr -and $LASTEXITCODE -ne 0) { Write-ToolkitLog -Level DEBUG -Message (Get-SourceTextLoc 'toolText.cmdkeyDelete0Error1' -Args @($t, $delErr)) }
                }
            }
        }
        @{ Name = "Regedit Last Key"; NameKey = 'cleanerRule.regeditLastKey'; Type = "Registry"; Keys = @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit"); ValuesOnly = $true }
        @{ Name = "Windows.old"; NameKey = 'cleanerRule.windowsOld'; Type = "ScriptBlock"; ScriptBlock = {
                $path = "C:\Windows.old"
                if (Test-Path $path) {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.windowsOldFolderDetectedStartingSafeRemovalWithNativeCleanmgr')
                    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations"
                    if (-not (Test-Path $regKey)) {
                        Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.registryKeyPreviousInstallationsNotFoundStandardExecutionAttempt')
                    }
                    else {
                        try {
                            Set-ItemProperty -Path $regKey -Name "StateFlags0066" -Value 2 -Type DWORD -Force -ErrorAction Stop
                            Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.cleanmgrConfigurationEnabledForWindowsOldStateflags0066')
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.failedToWriteToRegistryForCleanmgr0' -Args @($_))
                        }
                    }
                    $cleanMgrRule = @{
                        Name    = 'Removing Windows.old (CleanMgr)';
                        Type    = "Command";
                        Command = "cleanmgr.exe";
                        Args    = @("/sagerun:66");
                    }
                    $null = Invoke-CommandAction -Rule $cleanMgrRule
                    if (Test-Path $path) {
                        Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.iTheWindowsOldFolderMayRequireARebootForCompleteRemoval')
                    }
                    else {
                        Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extra2.windowsOldSuccessfullyRemoved')
                    }
                }
                else {
                    Add-CleanerLog -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extra.noWindowsOldFolderDetected')
                }
            }
        }
        @{ Name = "Empty Recycle Bin"; NameKey = 'cleanerRule.emptyRecycleBin'; Type = "Custom"; ScriptBlock = {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                Add-CleanerLog -Type 'Success' -Text (Get-SourceTextLoc 'uiText.trashEmptied')
            }
        }
    )
    $totalRules = $Rules.Count
    $currentRuleIndex = 0
    $successCount = 0
    $errorCount = 0
    foreach ($rule in $Rules) {
        $currentRuleIndex++
        $percent = [math]::Round(($currentRuleIndex / $totalRules) * 100)
        Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.ruleExecution') -Status (Get-SourceTextLoc $rule.NameKey) -Percent $percent -Icon '⚙️'
        $result = Invoke-WinCleanerRule -Rule $rule
        Clear-ProgressLine
        if ($result) { $successCount++ }
        else { $errorCount++ }
    }
    Clear-ProgressLine
    Write-StyledMessage -Type 'Info' -Text "=================================================="
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.summaryOfOperations')
    Write-StyledMessage -Type 'Info' -Text "=================================================="
    $stats = $script:WinCleanerLog | Group-Object Type
    $sCount = ($stats | Where-Object Name -eq 'Success').Count
    $wCount = ($stats | Where-Object Name -eq 'Warning').Count
    $eCount = ($stats | Where-Object Name -eq 'Error').Count
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.operationsCompletedSuccessfully0' -Args @($sCount))
    if ($wCount -gt 0) { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.alertsGenerated0' -Args @($wCount)) }
    if ($eCount -gt 0) { Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorsEncountered0' -Args @($eCount)) }
    Write-StyledMessage -Type 'Info' -Text "--------------------------------------------------"
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.detailsOfErrorsAndWarnings')
    $problems = $script:WinCleanerLog | Where-Object { $_.Type -in 'Warning', 'Error' }
    if ($problems) {
        foreach ($p in $problems) {
            Write-StyledMessage -Type $p.Type -Text $p.Text
        }
    }
    else {
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.noProblemsDetected')
    }
    Write-StyledMessage -Type 'Info' -Text "=================================================="
    Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.systemRebootIn') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
}
function DisableBitlocker {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "DisableBitlocker" -SubTitle (Get-SourceTextLoc 'script.DisableBitlocker')
    $regPath = $AppConfig.Registry.BitLocker
    $timeout = 3600
    function Test-BitLockerStatus {
        param([string]$DriveLetter = "C:")
        try { return manage-bde -status $DriveLetter }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.unableToCheckBitlockerStatus0' -Args @($($_.Exception.Message)))
            return $null
        }
    }
    try {
        Write-StyledMessage -Type 'Info' -Text ("🚀 " + (Get-SourceTextLoc 'toolText.initializingDriveCDecryption'))
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.disablingBitlocker') -Command 'manage-bde.exe' `
            -Arguments @('-off', 'C:') -TimeoutSeconds $timeout -LogContextKey "Bitlocker-Disable"
        if ($result.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.decryptionStartedCompletedSuccessfully'))
            Start-Sleep -Seconds 2
            $status = Test-BitLockerStatus -DriveLetter "C:"
            if ($status -match "Decryption in progress" -or $status -match 'Decryption in progress.') {
                Write-StyledMessage -Type 'Info' -Text ("⏳ " + (Get-SourceTextLoc 'toolText.decryptionInProgressInBackground'))
            }
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.manageBdeExitCode0BitlockerMayAlreadyBeDownOrInError' -Args @($($result.ExitCode))))
        }
        Write-StyledMessage -Type 'Info' -Text ("⚙️ " + (Get-SourceTextLoc 'toolText.disablingAutomaticEncryptionInTheRegistry'))
        Set-RegistryValue -Path $regPath -Name "PreventDeviceEncryption" -Value 1
        Write-StyledMessage -Type 'Success' -Text ("🎉 " + (Get-SourceTextLoc 'toolText.setupComplete'))
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "DisableBitlocker"
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text ("♻️ " + (Get-SourceTextLoc 'toolText.resourceCleanupCompleted'))
        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.rebootingIn') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.disablebitlockerSessionEnded')
    }
}
function WinDeleteUserProfiles {
    [CmdletBinding()]
    param(
        [ValidateRange(0, 3600)]
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot,
        [ValidateNotNullOrEmpty()]
        [string]$UsersRoot = 'C:\Users',
        [ValidateRange(0, 3650)]
        [int]$MinimumProfileAgeDays = 0,
        [switch]$SkipResidualFolderCleanup
    )
    $script:ToolName = 'WinDeleteUserProfiles'
    $usersRoot = [System.IO.Path]::GetFullPath($UsersRoot.TrimEnd('\') + '\')
    $currentUser = $env:USERNAME
    $computerName = $env:COMPUTERNAME
    $currentUserSid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    $currentUserProfilePath = (Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { $_.SID -eq $currentUserSid } | Select-Object -First 1 -ExpandProperty LocalPath -ErrorAction SilentlyContinue)
    if ($currentUserProfilePath -and $currentUserProfilePath.StartsWith($usersRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $currentUserFolder = [System.IO.Path]::GetFileName($currentUserProfilePath)
    }
    else {
        $currentUserFolder = $currentUser
    }
    $minimumLastUseDate = if ($MinimumProfileAgeDays -gt 0) { (Get-Date).AddDays(-$MinimumProfileAgeDays) } else { $null }
    $rebootRecommended = $false
    $protectedProfileNames = @(
        'Public',
        'Pubblica',
        'Default',
        'Default User',
        'All Users',
        'defaultuser0',
        'DefaultAccount',
        'WDAGUtilityAccount',
        'WSIAccount',
        'Administrator',
        'Guest',
        $currentUser,
        $currentUserFolder
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    function Write-ProfileCleanupMessage {
        param(
            [ValidateSet('Info', 'Warning', 'Error', 'Success')]
            [string]$Type = 'Info',
            [Parameter(Mandatory = $true)]
            [string]$Text
        )
        if ($Global:ProgressLineStart) { Clear-ProgressLine }
        Write-StyledMessage -Type $Type -Text $Text
    }
    function Write-ProfileCleanupTable {
        [CmdletBinding()]
        param([Parameter(ValueFromPipeline = $true)][object]$InputObject)
        begin { $rows = [System.Collections.Generic.List[object]]::new() }
        process { if ($null -ne $InputObject) { $rows.Add($InputObject) } }
        end {
            $table = $rows | Format-Table -AutoSize | Out-String -Width 4096
            foreach ($line in ($table -split '\r?\n')) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-ProfileCleanupMessage -Type 'Info' -Text $line.TrimEnd()
                }
            }
        }
    }
    function New-ProtectedNameSet {
        $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $protectedProfileNames | ForEach-Object { [void]$excluded.Add($_) }
        return , $excluded
    }
    function Test-ProtectedLocalAccount {
        param([Parameter(Mandatory = $true)][object]$Account)
        $sid = [string]$Account.SID
        if ($sid -eq $currentUserSid -or $sid -notmatch '^S-1-5-21-\d+-\d+-\d+-(\d+)$') {
            return $true
        }
        if ([uint64]$Matches[1] -lt 1000) { return $true }
        $excluded = New-ProtectedNameSet
        return $excluded.Contains($Account.Name)
    }
    function Get-ProtectedLocalAccountSids {
        param([Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Accounts)
        $protectedSids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $activeNames = @(Get-CimInstance -ClassName Win32_LoggedOnUser -ErrorAction Stop |
            Where-Object { $_.Antecedent.Domain -eq $computerName } | ForEach-Object { $_.Antecedent.Name })
        $serviceNames = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop | ForEach-Object { $_.StartName })
        foreach ($account in $Accounts) {
            if ((Test-ProtectedLocalAccount -Account $account) -or $activeNames -contains $account.Name -or
                $serviceNames -contains $account.Name -or $serviceNames -contains ".\$($account.Name)" -or
                $serviceNames -contains "$computerName\$($account.Name)" -or $serviceNames -contains "$($account.Name)@$computerName") {
                [void]$protectedSids.Add([string]$account.SID)
            }
        }
        return , $protectedSids
    }
    function Get-RemovableLocalAccounts {
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [array]$Accounts,
            [AllowEmptyCollection()]
            [array]$ProfileResults = @()
        )
        $remainingProfiles = @(Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop)
        $profileListKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
        $registeredSids = @(Get-ChildItem -LiteralPath $profileListKey -ErrorAction Stop |
            ForEach-Object { $_.PSChildName -replace '\.bak$', '' })
        $removedProfileSids = @($ProfileResults | Where-Object { $_.Success } | ForEach-Object { $_.Sid })
        $failedProfileSids = @($ProfileResults | Where-Object { -not $_.Success } | ForEach-Object { $_.Sid })
        $protectedSids = Get-ProtectedLocalAccountSids -Accounts $Accounts
        foreach ($account in $Accounts) {
            $sid = [string]$account.SID
            if ($protectedSids.Contains($sid)) { continue }
            if ($failedProfileSids -contains $sid -or $registeredSids -contains $sid -or
                @($remainingProfiles | Where-Object { $_.SID -eq $sid }).Count -gt 0) { continue }
            if ($removedProfileSids -notcontains $sid) {
                if (-not $usersRoot.Equals($profilesDirectory, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
                if ($minimumLastUseDate -and (-not $account.LastLogon -or $account.LastLogon -gt $minimumLastUseDate)) { continue }
            }
            $accountPath = [System.IO.Path]::GetFullPath((Join-Path $usersRoot $account.Name))
            if (-not $accountPath.StartsWith($usersRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
                (Test-Path -LiteralPath $accountPath -ErrorAction Stop)) { continue }
            $account
        }
    }
    function Remove-LocalUserAccounts {
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [array]$Accounts,
            [AllowEmptyCollection()]
            [array]$ProfileResults = @()
        )
        foreach ($account in $Accounts) {
            $start = Get-Date
            $sid = [string]$account.SID
            $success = $false
            if (Test-ProtectedLocalAccount -Account $account) { continue }
            try {
                $currentAccount = Get-LocalUser -SID $sid -ErrorAction Stop
                $eligibleAccounts = @(Get-RemovableLocalAccounts -Accounts @($currentAccount) -ProfileResults $ProfileResults)
                if ($eligibleAccounts.Count -ne 1) {
                    throw (Get-SourceTextLoc 'toolText.localAccountProtected0' -Args @($account.Name))
                }
                Remove-LocalUser -SID $sid -ErrorAction Stop -Confirm:$false
                if (@(Get-LocalUser -ErrorAction Stop | Where-Object { [string]$_.SID -eq $sid }).Count -gt 0) {
                    throw (Get-SourceTextLoc 'toolText.localAccountStillExists0' -Args @($sid))
                }
                $success = $true
                Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.localAccountRemoved01' -Args @($account.Name, $sid))
            }
            catch {
                Write-ProfileCleanupMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.localAccountRemovalFailed01' -Args @($account.Name, $_.Exception.Message))
            }
            [PSCustomObject]@{
                Type     = 'LocalAccount'
                UserName = $account.Name
                Sid      = $sid
                Success  = $success
                Duration = New-TimeSpan -Start $start -End (Get-Date)
            }
        }
    }
    function Remove-ProfileRegistryEntries {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Sid,
            [Parameter(Mandatory = $true)]
            [string]$UserName
        )
        if ([string]::IsNullOrWhiteSpace($Sid) -or $Sid -eq 'NULL') {
            return $false
        }
        $profileRegKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $Sid
        if (-not (Test-Path -LiteralPath $profileRegKey)) {
            return $true
        }
        try {
            Remove-Item -LiteralPath $profileRegKey -Recurse -Force -ErrorAction Stop
            Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.registryEntryRemovedForSid01' -Args @($UserName, $Sid))
            return $true
        }
        catch {
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.failedToRemoveRegistryEntryForSid01' -Args @($UserName, $($_.Exception.Message)))
            return $false
        }
    }
    function Get-RegisteredProfilePathSet {
        $pathSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        try {
            $cimProfiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop
        }
        catch {
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.cimProfileDetectionFailed0' -Args @($($_.Exception.Message)))
            return , $pathSet
        }
        $cimProfiles |
        Where-Object {
            $_.LocalPath -and
            $_.LocalPath.StartsWith($usersRoot, [System.StringComparison]::OrdinalIgnoreCase)
        } |
        ForEach-Object {
            try {
                [void]$pathSet.Add([System.IO.Path]::GetFullPath($_.LocalPath).TrimEnd('\'))
            }
            catch {
                Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.failedToNormalizeRegisteredProfileLocalpath0' -Args @($($_.LocalPath)))
            }
        }
        return , $pathSet
    }
    function Get-RemovableUserProfiles {
        $excluded = New-ProtectedNameSet
        Write-ProfileCleanupMessage -Type 'Info' -Text ("🔍 " + (Get-SourceTextLoc 'toolText.scanningRegisteredLocalProfiles'))
        try {
            $profiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop
        }
        catch {
            Write-ProfileCleanupMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.cimProfileDetectionFailed0' -Args @($($_.Exception.Message))))
            return
        }
        $profiles = $profiles | Where-Object {
            -not $_.Special -and
            -not $_.Loaded -and
            $_.LocalPath -and
            $_.LocalPath.StartsWith($usersRoot, [System.StringComparison]::OrdinalIgnoreCase)
        }
        foreach ($profileItem in $profiles) {
            $profileName = [System.IO.Path]::GetFileName($profileItem.LocalPath)
            if ($excluded.Contains($profileName)) {
                Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.excludedProfile01' -Args @($profileName, $($profileItem.LocalPath)))
                continue
            }
            if ($protectedAccountSids -and $protectedAccountSids.Contains($profileItem.SID)) {
                Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.excludedProfile01' -Args @($profileName, $profileItem.LocalPath))
                continue
            }
            if ($profileItem.SID -eq $currentUserSid) {
                Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.excludedProfileBecauseSidMatchesCurrentUser0' -Args @($profileName, $profileItem.SID))
                continue
            }
            if ($minimumLastUseDate -and $profileItem.LastUseTime) {
                $lastUse = $profileItem.LastUseTime
                if ($lastUse -gt $minimumLastUseDate) {
                    Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.profileExcludedDueToTimeThreshold0LastUse1' -Args @($profileName, $lastUse))
                    continue
                }
            }
            $profileItem
        }
    }
    function Remove-UserProfile {
        param(
            [Parameter(Mandatory = $true)]
            [object]$ProfileItem
        )
        $ErrorActionPreference = 'Stop'
        $userPath = $ProfileItem.LocalPath
        $userName = [System.IO.Path]::GetFileName($userPath)
        $userSid = $ProfileItem.SID
        $start = Get-Date
        Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startResidualFolder01' -Args @($userName, $userPath))
        try {
            Remove-CimInstance -InputObject $ProfileItem -ErrorAction Stop -Confirm:$false
            Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.cimProfileRemoved0' -Args @($userName))
        }
        catch {
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.cimRemoveFailed01' -Args @($userName, $($_.Exception.Message)))
        }
        if ([System.IO.Directory]::Exists($userPath)) {
            try {
                $tempEmpty = Join-Path $env:TEMP "EmptyFolder"
                if (-not (Test-Path $tempEmpty)) {
                    New-Item -ItemType Directory -Path $tempEmpty | Out-Null
                }
                Invoke-ExternalCommandWithLog -Command 'robocopy.exe' `
                    -Arguments @("`"$tempEmpty`"", "`"$userPath`"", '/MIR', '/XJ', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP') `
                    -LogContextKey "ProfileCleanup-Robocopy-$userName" | Out-Null
                Remove-Item -LiteralPath $userPath -Recurse -Force -ErrorAction Stop -Confirm:$false
                Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.folderRemoved0' -Args @($userName))
            }
            catch {
                Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.standardFolderCleanupFailed01' -Args @($userName, $($_.Exception.Message)))
                try {
                    Invoke-ExternalCommandWithLog -Command 'takeown.exe' -Arguments @('/F', "`"$userPath`"", '/R', '/D', 'Y') -LogContextKey "ProfileCleanup-TakeOwn-$userName" | Out-Null
                    Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$userPath`"", '/grant', '*S-1-5-32-544:F', '/T', '/C') -LogContextKey "ProfileCleanup-Icacls-$userName" | Out-Null
                    Remove-Item -LiteralPath $userPath -Recurse -Force -ErrorAction Stop -Confirm:$false
                    Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.folderRemovedAfterAclReset0' -Args @($userName))
                }
                catch {
                    Write-ProfileCleanupMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.cleanupFailed01' -Args @($userName, $($_.Exception.Message)))
                }
            }
        }
        $folderGone = -not [System.IO.Directory]::Exists($userPath)
        $registrySuccess = $false
        if ($folderGone -and $userSid) {
            $registrySuccess = Remove-ProfileRegistryEntries -Sid $userSid -UserName $userName
        }
        $success = $folderGone -and $registrySuccess
        $duration = New-TimeSpan -Start $start -End (Get-Date)
        if ($success) {
            Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.completedProfile01' -Args @($userName, $duration.ToString()))
        }
        else {
            Write-ProfileCleanupMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.failedProfile0' -Args @($userName))
        }
        return [PSCustomObject]@{
            Type     = 'Profile'
            UserName = $userName
            Path     = $userPath
            Sid      = $userSid
            Success  = $success
            Duration = $duration
        }
    }
    function Invoke-ProfileRemovalBatch {
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [array]$Profiles
        )
        $results = [System.Collections.Generic.List[object]]::new()
        $total = $Profiles.Count
        $completed = 0
        try {
            foreach ($profileItem in $Profiles) {
                $userName = [System.IO.Path]::GetFileName($profileItem.LocalPath)
                $start = Get-Date
                $percent = if ($total -gt 0) { [math]::Floor(($completed / $total) * 100) } else { 100 }
                Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingRegisteredProfiles') -Status ("{0} / {1} - {2}" -f ($completed + 1), $total, $userName) -Percent $percent -Icon '🗑️'
                try {
                    $result = Remove-UserProfile -ProfileItem $profileItem
                }
                catch {
                    Write-ProfileCleanupMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.cleanupFailed01' -Args @($userName, $_.Exception.Message))
                    $result = [PSCustomObject]@{
                        Type     = 'Profile'
                        UserName = $userName
                        Path     = $profileItem.LocalPath
                        Sid      = $profileItem.SID
                        Success  = $false
                        Duration = New-TimeSpan -Start $start -End (Get-Date)
                    }
                }
                $results.Add($result)
                $completed++
                $percent = if ($total -gt 0) { [math]::Floor(($completed / $total) * 100) } else { 100 }
                Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingRegisteredProfiles') -Status (Get-SourceTextLoc 'toolText.extra.01Completed' -Args @($completed, $total)) -Percent $percent -Icon '🗑️'
            }
            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingRegisteredProfiles') -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
            return $results
        }
        finally {
            Clear-ProgressLine
        }
    }
    function Get-ResidualUserFolders {
        $excluded = New-ProtectedNameSet
        $registeredProfilePaths = Get-RegisteredProfilePathSet
        Write-ProfileCleanupMessage -Type 'Info' -Text ("🔎 " + (Get-SourceTextLoc 'toolText.checkResidualFoldersInTheUsersDirectory'))
        $folders = Get-ChildItem -Path $usersRoot -Directory -Force |
        Where-Object {
            -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
        }
        $profileListKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
        $registeredSids = @()
        try {
            $registeredSids = Get-ChildItem -Path $profileListKey -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName }
        }
        catch {
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.couldNotEnumerateRegistryProfileList0' -Args @($($_.Exception.Message)))
        }
        foreach ($folder in $folders) {
            $folderName = $folder.Name
            $folderPath = [System.IO.Path]::GetFullPath($folder.FullName).TrimEnd('\')
            if ($excluded.Contains($folderName)) {
                Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.residualFolderExcludedForProtectedName01' -Args @($folderName, $folderPath))
                continue
            }
            if ($registeredProfilePaths.Contains($folderPath)) {
                Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.residualFolderExcludedBecauseItIsStillAssociatedWithWin32Userprofile01' -Args @($folderName, $folderPath))
                continue
            }
            if ($registeredSids -contains $folderName) {
                Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.residualFolderExcludedBecauseSidStillRegistered01' -Args @($folderName, $folderPath))
                continue
            }
            if ($folder.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.residualFolderExcludedBecauseReparsePointSymlink01' -Args @($folderName, $folderPath))
                continue
            }
            [PSCustomObject]@{
                Name = $folderName
                Path = $folderPath
            }
        }
    }
    function Remove-ResidualUserFolders {
        param(
            [Parameter(Mandatory = $true)]
            [array]$Folders
        )
        $results = [System.Collections.Generic.List[object]]::new()
        $total = $Folders.Count
        $index = 0
        foreach ($folder in $Folders) {
            $index++
            $percent = if ($total -gt 0) { [math]::Floor(($index / $total) * 100) } else { 100 }
            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingResidualFoldersInCUsers') -Status ("{0} / {1} - {2}" -f $index, $total, $folder.Name) -Percent $percent -Icon '🗑️'
            $start = Get-Date
            $success = $false
            Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.startResidualFolder01' -Args @($($folder.Name), $($folder.Path)))
            $folderPath = $folder.Path
            try {
                Remove-Item -LiteralPath $folderPath -Force -Recurse -ErrorAction Stop -Confirm:$false
                $success = -not [System.IO.Directory]::Exists($folderPath)
            }
            catch {
                Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.standardResidualFolderRemovalFailed01' -Args @($folderPath, $($_.Exception.Message)))
                try {
                    Invoke-ExternalCommandWithLog -Command 'takeown.exe' -Arguments @('/F', "`"$folderPath`"", '/R', '/D', 'Y') -LogContextKey "ResidualTakeOwn-$($folder.Name)" | Out-Null
                    Invoke-ExternalCommandWithLog -Command 'icacls.exe' -Arguments @("`"$folderPath`"", '/grant', '*S-1-5-32-544:F', '/T', '/C') -LogContextKey "ResidualIcacls-$($folder.Name)" | Out-Null
                    Remove-Item -LiteralPath $folderPath -Recurse -Force -ErrorAction Stop -Confirm:$false
                    $success = -not [System.IO.Directory]::Exists($folderPath)
                }
                catch {
                    Write-ProfileCleanupMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.remnantFolderRemovalFailed01' -Args @($folderPath, $($_.Exception.Message)))
                    $success = $false
                }
            }
            $duration = New-TimeSpan -Start $start -End (Get-Date)
            if ($success) {
                Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.completedResidualFolder01' -Args @($($folder.Name), $duration.ToString()))
            }
            else {
                Write-ProfileCleanupMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.failedResidualFolder0' -Args @($($folder.Name)))
            }
            $results.Add([PSCustomObject]@{
                    Type     = 'ResidualFolder'
                    UserName = $folder.Name
                    Path     = $folder.Path
                    Success  = $success
                    Duration = $duration
                }) | Out-Null
        }
        Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.extra.removingResidualFoldersInCUsers') -Status (Get-SourceTextLoc 'uiText.completed') -Percent 100 -Icon '✅'
        Clear-ProgressLine
        return $results
    }
    Start-ToolkitSession -ToolName $script:ToolName -SubTitle (Get-SourceTextLoc 'script.WinDeleteUserProfiles')
    try {
        if (-not (Test-Path -LiteralPath $usersRoot -PathType Container)) {
            throw (Get-SourceTextLoc 'toolText.extra.profilePathDoesNotExist0' -Args @($usersRoot))
        }
        Get-Command Remove-LocalUser -ErrorAction Stop | Out-Null
        $localAccounts = @(Get-LocalUser -ErrorAction Stop)
        $profilesDirectoryValue = Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -Name 'ProfilesDirectory' -ErrorAction Stop
        $profilesDirectory = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($profilesDirectoryValue).TrimEnd('\') + '\')
        $protectedAccountSids = Get-ProtectedLocalAccountSids -Accounts $localAccounts
        foreach ($account in $localAccounts) {
            if ($protectedAccountSids.Contains([string]$account.SID)) {
                $protectedProfileNames += $account.Name
            }
        }
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os -and $os.Caption -notmatch 'Windows 11') {
            Write-ProfileCleanupMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.systemDetected0TheScriptIsDesignedForWindows11' -Args @($($os.Caption))))
        }
        Write-ProfileCleanupMessage -Type 'Info' -Text ("🖥️ " + (Get-SourceTextLoc 'toolText.computer0' -Args @($computerName)))
        Write-ProfileCleanupMessage -Type 'Info' -Text ("👤 " + (Get-SourceTextLoc 'toolText.currentUserProtected0' -Args @($currentUser)))
        Write-ProfileCleanupMessage -Type 'Info' -Text ("📁 " + (Get-SourceTextLoc 'toolText.profilePath0' -Args @($usersRoot)))
        Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.nonInteractiveModeNoConfirmationWillBeRequestedBeforeCancellations')
        if ($minimumLastUseDate) {
            Write-ProfileCleanupMessage -Type 'Info' -Text ("📅 " + (Get-SourceTextLoc 'toolText.lastActivityThresholdProfilesNotUsedForAtLeast0Days' -Args @($MinimumProfileAgeDays)))
        }
        Write-ProfileCleanupMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.sessionStartedOn0' -Args @($computerName))
        $profileResults = @()
        $residualResults = @()
        $accountResults = @()
        $targets = @(Get-RemovableUserProfiles)
        if ($targets -and $targets.Count -gt 0) {
            Write-Host ''
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.registeredProfilesSelectedForAutomaticRemoval')
            Write-Host ''
            $targets |
            Select-Object @{Name = 'User'; Expression = { [System.IO.Path]::GetFileName($_.LocalPath) } },
            @{Name = 'Loaded'; Expression = { $_.Loaded } },
            @{Name = 'LastUseTime'; Expression = { $_.LastUseTime } },
            @{Name = 'Path'; Expression = { $_.LocalPath } } |
            Write-ProfileCleanupTable
            Write-Host ''
            Write-ProfileCleanupMessage -Type 'Info' -Text ("🚀 " + (Get-SourceTextLoc 'toolText.startAutomaticRemovalOf0RegisteredProfiles' -Args @($targets.Count)))
            Write-Host ''
            $profileResults = @(Invoke-ProfileRemovalBatch -Profiles $targets)
        }
        else {
            Write-Host ''
            Write-ProfileCleanupMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.noRemovableRegisteredProfilesFound'))
        }
        if (-not $SkipResidualFolderCleanup) {
            $residualFolders = @(Get-ResidualUserFolders)
            if ($residualFolders -and $residualFolders.Count -gt 0) {
                Write-Host ''
                Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.residualFoldersSelectedForAutomaticRemoval0' -Args @($residualFolders.Count))
                $residualFolders | Select-Object Name, Path | Write-ProfileCleanupTable
                Write-Host ''
                Write-ProfileCleanupMessage -Type 'Info' -Text ("🧹 " + (Get-SourceTextLoc 'toolText.startingRemovalOfResidualFolders'))
                Write-Host ''
                $residualResults = @(Remove-ResidualUserFolders -Folders $residualFolders)
            }
            else {
                Write-ProfileCleanupMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.noRemovableResidualFolderFoundInCUsers'))
            }
        }
        else {
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.residualFolderCleanupSkippedForSkipresidualfoldercleanupParameter')
        }
        $accountTargets = @(Get-RemovableLocalAccounts -Accounts $localAccounts -ProfileResults $profileResults)
        if ($accountTargets.Count -gt 0) {
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.localAccountsSelectedForAutomaticRemoval0' -Args @($accountTargets.Count))
            $accountTargets | Select-Object Name, SID | Write-ProfileCleanupTable
            $accountResults = @(Remove-LocalUserAccounts -Accounts $accountTargets -ProfileResults $profileResults)
        }
        $allResults = @($profileResults) + @($residualResults) + @($accountResults)
        $failedCount = @($allResults | Where-Object { -not $_.Success }).Count
        $profileSuccessCount = @($profileResults | Where-Object { $_.Success }).Count
        $residualSuccessCount = @($residualResults | Where-Object { $_.Success }).Count
        $accountSuccessCount = @($accountResults | Where-Object { $_.Success }).Count
        if ($failedCount -gt 0) {
            $rebootRecommended = $true
            Write-ProfileCleanupMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.extra.restartRecommendedAfterProfileCleanup'))
            Write-ProfileCleanupMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.recommendedReboot0' -Args @((Get-SourceTextLoc 'toolText.0ItemsNotRemovedMayBeBlockedByOpenSessionsOrHandles' -Args @($failedCount))))
        }
        Write-ProfileCleanupMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.registeredProfilesRemoved0' -Args @($profileSuccessCount)))
        Write-ProfileCleanupMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.residualFoldersRemoved0' -Args @($residualSuccessCount)))
        Write-ProfileCleanupMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.localAccountsRemoved0' -Args @($accountSuccessCount))
        if ($failedCount -gt 0) {
            Write-ProfileCleanupMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.itemsNotRemoved0' -Args @($failedCount)))
        }
        if ($rebootRecommended) {
            Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.restartRecommendedAfterProfileCleanup') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName $script:ToolName
        throw
    }
    finally {
        Write-ProfileCleanupMessage -Type 'Info' -Text ("♻️ " + (Get-SourceTextLoc 'toolText.winDeleteUserProfilesSessionEnded'))
    }
}
function Install-Office {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "OfficeInstall" -SubTitle (Get-SourceTextLoc 'script.Install-Office')
    $tempDir = $AppConfig.Paths.OfficeTemp
    function Set-OfficePostConfig {
        Write-StyledMessage -Type 'Info' -Text ("⚙️ " + (Get-SourceTextLoc 'toolText.officePostInstallationConfiguration'))
        foreach ($reg in @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";         Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "disconnectedstate";     Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "usercontentdisabled";   Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "downloadcontentdisabled"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";         Value = 0 }
        )) { Set-RegistryValue -Path $reg.Path -Name $reg.Name -Value $reg.Value }
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General" -Name "ShownOptIn" -Value 1
        Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.telemetryAndPrivacyOfficeDisabled'))
    }
    try {
        Write-StyledMessage -Type 'Info' -Text ("🏢 " + (Get-SourceTextLoc 'toolText.startingOfficeBasicInstallation'))
        if (-not (Test-Path $tempDir)) {
            $null = New-Item -ItemType Directory -Path $tempDir -Force
        }
        $setupPath  = Join-Path $tempDir 'Setup.exe'
        $configPath = Join-Path $tempDir 'Basic.xml'
        foreach ($dl in @(
            @{ Url = $AppConfig.URLs.OfficeSetup;       Path = $setupPath;  Name = (Get-SourceTextLoc 'toolText.extra.officeSetup') },
            @{ Url = $AppConfig.URLs.OfficeBasicConfig; Path = $configPath; Name = (Get-SourceTextLoc 'toolText.extra.basicConfiguration') }
        )) {
            if (-not (Invoke-ToolkitDownload -Uri $dl.Url -OutputPath $dl.Path -Description $dl.Name)) {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.downloadFailedInstallationCancelled')
                return
            }
        }
        Write-StyledMessage -Type 'Info' -Text ("🚀 " + (Get-SourceTextLoc 'toolText.startingInstallationProcess'))
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.officeBasicInstallation') -Command $setupPath `
            -Arguments "/configure `"$configPath`"" -TimeoutSeconds 86400 -LogContextKey "Office-Install"
        Clear-ProgressLine
        if (-not $result.Success) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.installationFailed')
            return
        }
        Set-OfficePostConfig
        Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.installationCompleted'))
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.restartNotRequired')
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorInstallingOffice0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.criticalErrorInInstallOffice') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Remove-ItemSafely -Path $tempDir -Recurse
        Write-StyledMessage -Type 'Success' -Text ("🎯 " + (Get-SourceTextLoc 'toolText.officeInstallFinished'))
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.installOfficeSessionEnded')
    }
}
function Repair-Office {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "OfficeRepair" -SubTitle (Get-SourceTextLoc 'script.Repair-Office')
    function Set-OfficePostConfig {
        Write-StyledMessage -Type 'Info' -Text ("⚙️ " + (Get-SourceTextLoc 'toolText.officePostRepairSetup'))
        foreach ($reg in @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";           Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "disconnectedstate";       Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "usercontentdisabled";     Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy";  Name = "downloadcontentdisabled"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common";          Name = "sendtelemetry";           Value = 0 }
        )) { Set-RegistryValue -Path $reg.Path -Name $reg.Name -Value $reg.Value }
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General" -Name "ShownOptIn" -Value 1
        Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.telemetryAndPrivacyOfficeDisabled'))
    }
    $needsReboot = $false
    try {
        Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.startingOfficeRepair'))
        Stop-ToolkitProcesses -ProcessNames @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
        Write-StyledMessage -Type 'Info' -Text ("🧹 " + (Get-SourceTextLoc 'toolText.officeCacheCleaner'))
        $cleanedCount = 0
        foreach ($cache in @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )) {
            if (Remove-ItemSafely -Path $cache -Recurse) { $cleanedCount++ }
        }
        if ($cleanedCount -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0DeletedCaches' -Args @($cleanedCount)) }
        $officeClient64 = "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
        $officeClient32 = "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
        $officeClient = if (Test-Path $officeClient64) { $officeClient64 } else { $officeClient32 }
        if (-not (Test-Path $officeClient)) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.officeclicktorunExeNotFoundOfficeMayNotBeInstalled')
            return
        }
        try {
            Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.launchQuickRepairOffline'))
            $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.quickOfficeRepairOffline') -Command $officeClient `
                -Arguments "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=QuickRepair DisplayLevel=True" `
                -TimeoutSeconds 86400 -LogContextKey "Office-Repair-Quick"
            Set-OfficePostConfig
            Write-StyledMessage -Type 'Success' -Text ("🎉 " + (Get-SourceTextLoc 'toolText.officeRepairComplete'))
            $needsReboot = $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringQuickRepair0' -Args @($($_.Exception.Message)))
            try {
                Write-StyledMessage -Type 'Info' -Text ("🌐 " + (Get-SourceTextLoc 'toolText.attemptingFullRepairOnlineAsAFallback'))
                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.completeOfficeRepairOnline') -Command $officeClient `
                    -Arguments "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True" `
                    -TimeoutSeconds 86400 -LogContextKey "Office-Repair-Full"
                Set-OfficePostConfig
                Write-StyledMessage -Type 'Success' -Text ("🎉 " + (Get-SourceTextLoc 'toolText.officeRepairComplete'))
                $needsReboot = $true
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorAlsoDuringOnlineRepair0' -Args @($($_.Exception.Message)))
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.criticalErrorRepairingOffice0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.criticalErrorInRepairOffice') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text ("🎯 " + (Get-SourceTextLoc 'toolText.officeRepairFinished'))
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.repairOfficeSessionEnded')
    }
    if ($needsReboot) {
        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.repairCompleted') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
function Uninstall-Office {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "OfficeUninstall" -SubTitle (Get-SourceTextLoc 'script.Uninstall-Office')
    $tempDir = $AppConfig.Paths.OfficeTemp
    function Get-WindowsVersion {
        try {
            $buildNumber = [int](Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
            if ($buildNumber -ge 22631) { return "Windows11_23H2_Plus" }
            if ($buildNumber -ge 22000) { return "Windows11_22H2_Or_Older" }
            return "Windows10_Or_Older"
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.unableToDetectWindowsVersion0' -Args @($_))
            return "Unknown"
        }
    }
    function Remove-ItemsSilently {
        param([string[]]$Paths, [string]$ItemType = "folder")
        $removed = @()
        $failed  = @()
        foreach ($path in $Paths) {
            if (Test-Path $path) {
                if (Remove-ItemSafely -Path $path -Recurse) { $removed += $path }
                else { $failed += $path }
            }
        }
        return @{ Removed = $removed; Failed = $failed; Count = $removed.Count }
    }
    function Remove-OfficeDirectly {
        Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.startingOfficeDirectRemoval'))
        try {
            Write-StyledMessage -Type 'Info' -Text ("📋 " + (Get-SourceTextLoc 'toolText.searchForOfficeInstallations'))
            $officePackages = Get-Package -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*Microsoft Office*" -or $_.Name -like "*Microsoft 365*" -or $_.Name -like "*Office*" }
            if ($officePackages) {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.found0OfficePackages' -Args @($($officePackages.Count)))
                foreach ($package in $officePackages) {
                    try {
                        $null = Uninstall-Package -Name $package.Name -Force -ErrorAction Stop
                        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.removed02' -Args @($($package.Name)))
                    }
                    catch {
                        Write-Warning "tools\Uninstall-Office.ps1, Remove-OfficeDirectly 1: $($_.Exception.Message)"
                    }
                }
            }
            Write-StyledMessage -Type 'Info' -Text ("🔍 " + (Get-SourceTextLoc 'toolText.searchTheRegistry'))
            foreach ($keyPath in @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )) {
                try {
                    $items = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue |
                        Where-Object { $_.DisplayName -like "*Office*" -or $_.DisplayName -like "*Microsoft 365*" }
                    foreach ($item in $items) {
                        if ($item.UninstallString -and $item.UninstallString -match "msiexec") {
                            try {
                                $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.removal0' -Args @($($item.DisplayName))) -Command 'msiexec.exe' `
                                    -Arguments @('/x', $item.PSChildName, '/qn', '/norestart') -TimeoutSeconds 1800 `
                                    -LogContextKey "Office-Uninstall-MSI-$($item.PSChildName)"
                            }
                            catch {
                                Write-Warning "tools\Uninstall-Office.ps1, Remove-OfficeDirectly 2: $($_.Exception.Message)"
                            }
                        }
                    }
                }
                catch {
                    Write-Warning "tools\Uninstall-Office.ps1, Remove-OfficeDirectly 3: $($_.Exception.Message)"
                }
            }
            Write-StyledMessage -Type 'Info' -Text ("🛑 " + (Get-SourceTextLoc 'toolText.stoppingOfficeServices'))
            $stoppedServices = 0
            foreach ($serviceName in @('ClickToRunSvc', 'OfficeSvc', 'OSE')) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    try {
                        Stop-Service  -Name $serviceName -Force -ErrorAction Stop
                        Set-Service   -Name $serviceName -StartupType Disabled -ErrorAction Stop
                        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.serviceStopped0' -Args @($serviceName))
                        $stoppedServices++
                    }
                    catch {
                        Write-Warning "tools\Uninstall-Office.ps1, Remove-OfficeDirectly 4: $($_.Exception.Message)"
                    }
                }
            }
            Write-StyledMessage -Type 'Info' -Text ("🧹 " + (Get-SourceTextLoc 'toolText.officeFolderCleaning'))
            $folderResult = Remove-ItemsSilently -Paths @(
                "$env:ProgramFiles\Microsoft Office",
                "${env:ProgramFiles(x86)}\Microsoft Office",
                "$env:ProgramFiles\Microsoft Office 15",
                "${env:ProgramFiles(x86)}\Microsoft Office 15",
                "$env:ProgramFiles\Microsoft Office 16",
                "${env:ProgramFiles(x86)}\Microsoft Office 16",
                "$env:ProgramData\Microsoft\Office",
                "$env:LOCALAPPDATA\Microsoft\Office",
                "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun",
                "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun"
            ) -ItemType "folder"
            if ($folderResult.Count -gt 0)        { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0OfficeFoldersRemoved' -Args @($($folderResult.Count))) }
            if ($folderResult.Failed.Count -gt 0)  { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.unableToRemove0FoldersMayBeInUse' -Args @($($folderResult.Failed.Count))) }
            Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.officeRegistryCleaner'))
            $regResult = Remove-ItemsSilently -Paths @(
                "HKCU:\Software\Microsoft\Office",
                "HKLM:\SOFTWARE\Microsoft\Office",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office",
                "HKCU:\Software\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun"
            ) -ItemType "registry key"
            if ($regResult.Count -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0OfficeRegistryKeysRemoved' -Args @($($regResult.Count))) }
            Write-StyledMessage -Type 'Info' -Text ("📅 " + (Get-SourceTextLoc 'toolText.cleaningScheduledTasks'))
            $tasksRemoved = 0
            try {
                $officeTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*Office*" }
                foreach ($task in $officeTasks) {
                    try { Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop; $tasksRemoved++ }
                    catch {
                        Write-Warning "tools\Uninstall-Office.ps1, Remove-OfficeDirectly 5: $($_.Exception.Message)"
                    }
                }
                if ($tasksRemoved -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0OfficeTasksRemoved' -Args @($tasksRemoved)) }
            }
            catch {
                Write-Warning "tools\Uninstall-Office.ps1, Remove-OfficeDirectly 6: $($_.Exception.Message)"
            }
            Write-StyledMessage -Type 'Info' -Text ("🖥️ " + (Get-SourceTextLoc 'toolText.removingOfficeLinks'))
            $shortcutsRemoved = 0
            foreach ($desktopPath in @(
                $AppConfig.Paths.Desktop,
                "$env:PUBLIC\Desktop",
                "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs"
            )) {
                if (Test-Path $desktopPath) {
                    foreach ($shortcut in @(
                        "Microsoft Word*.lnk", "Microsoft Excel*.lnk", "Microsoft PowerPoint*.lnk",
                        "Microsoft Outlook*.lnk", "Microsoft OneNote*.lnk", "Microsoft Access*.lnk",
                        "Office*.lnk", "Word*.lnk", "Excel*.lnk", "PowerPoint*.lnk", "Outlook*.lnk"
                    )) {
                        foreach ($file in (Get-ChildItem -Path $desktopPath -Filter $shortcut -Recurse -ErrorAction SilentlyContinue)) {
                            if (Remove-ItemSafely -Path $file.FullName) { $shortcutsRemoved++ }
                        }
                    }
                }
            }
            if ($shortcutsRemoved -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0OfficeLinksRemoved' -Args @($shortcutsRemoved)) }
            Write-StyledMessage -Type 'Info' -Text ("💽 " + (Get-SourceTextLoc 'toolText.officeResidueCleaning'))
            $null = Remove-ItemsSilently -Paths @(
                "$env:LOCALAPPDATA\Microsoft\OneDrive",
                "$env:APPDATA\Microsoft\OneDrive",
                "$env:TEMP\Office*",
                "$env:TEMP\MSO*"
            ) -ItemType "residuo"
            Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.directRemovalCompleted'))
            Write-StyledMessage -Type 'Info' -Text ("📊 " + (Get-SourceTextLoc 'toolText.summary0Folders1RegistryKeys2Links3TasksRemoved' -Args @($($folderResult.Count), $($regResult.Count), $shortcutsRemoved, $tasksRemoved)))
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorWhileDirectlyRemovingOffice0' -Args @($($_.Exception.Message)))
            return $false
        }
    }
    function Start-OfficeUninstallWithGetHelp {
        try {
            if (-not (Test-Path $tempDir)) { $null = New-Item -ItemType Directory -Path $tempDir -Force }
            $getHelpZipPath = Join-Path $tempDir 'GetHelp.zip'
            if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.GetHelpInstaller -OutputPath $getHelpZipPath -Description 'Microsoft Get Help')) {
                return $false
            }
            Write-StyledMessage -Type 'Info' -Text ("📦 " + (Get-SourceTextLoc 'toolText.extractionGetHelp'))
            try {
                Expand-Archive -Path $getHelpZipPath -DestinationPath $tempDir -Force
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.extractionCompleted')
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorExtractingArchiveGetHelp0' -Args @($($_.Exception.Message)))
                return $false
            }
            $getHelpExe = Get-ChildItem -Path $tempDir -Filter "GetHelpCmd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $getHelpExe) {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.gethelpcmdExeNotFound')
                return $false
            }
            Write-StyledMessage -Type 'Info' -Text ("🚀 " + (Get-SourceTextLoc 'toolText.removalViaGetHelp'))
            Write-StyledMessage -Type 'Warning' -Text ("⏰ " + (Get-SourceTextLoc 'toolText.thisOperationMayTakeAFewMinutes'))
            try {
                $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.removingOfficeUsingGetHelp') -Command $getHelpExe.FullName `
                    -Arguments '-S OfficeScrubScenario -AcceptEula' `
                    -TimeoutSeconds 86400 -LogContextKey "Office-Uninstall-GetHelp"
                $outputStr    = $result.StdOut + $result.StdErr
                $isInvalidArgs = $outputStr -match "Error: Invalid command line arguments" -or $outputStr -match "Usage: GetHelpCmd\.exe"
                if ($result.ExitCode -eq 0 -and -not $isInvalidArgs) {
                    $blockingProcesses = @('Setup', 'GetHelpCmd', 'OfficeClickToRun', 'Integrator', 'OfficeScrub', 'cscript')
                    $waitStart         = Get-Date
                    Start-Sleep -Seconds 12
                    if (Get-Process -Name $blockingProcesses -ErrorAction SilentlyContinue) {
                        Write-StyledMessage -Type 'Info' -Text ("⏳ " + (Get-SourceTextLoc 'toolText.getHelpStartedTheRemovalInAnExternalWindowWaitingForCompletion'))
                        $spinnerIndex = 0
                        while ((Get-Process -Name $blockingProcesses -ErrorAction SilentlyContinue) -and ((Get-Date) - $waitStart).TotalSeconds -lt 2700) {
                            $elapsed = [math]::Round(((Get-Date) - $waitStart).TotalSeconds, 1)
                            $spinner = Get-SpinnerChar -Index ([ref]$spinnerIndex)
                            Write-ProgressUpdate -Activity (Get-SourceTextLoc 'toolText.removingOffice') -Status (Get-SourceTextLoc 'toolText.inProgress0Seconds' -Args @($elapsed)) -Percent 90 -Icon '⏳' -Spinner $spinner
                            Start-Sleep -Milliseconds 500
                        }
                        Clear-ProgressLine
                    }
                    Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.getHelpCompletedSuccessfully'))
                    return $true
                }
                else {
                    $reason = if ($isInvalidArgs) { 'Parameters not supported by the tool version' } else { "Exit code: $($result.ExitCode)" }
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.getHelpFailed0AttemptedAlternativeMethod' -Args @($reason))
                    return Remove-OfficeDirectly
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorRunningGetHelp0SwitchingToAlternativeMethod' -Args @($($_.Exception.Message)))
                return Remove-OfficeDirectly
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorDuringGetHelpProcess0' -Args @($($_.Exception.Message)))
            return $false
        }
        finally {
            Remove-ItemSafely -Path $tempDir -Recurse
        }
    }
    $needsReboot = $false
    try {
        Write-StyledMessage -Type 'Warning' -Text ("🗑️ " + (Get-SourceTextLoc 'toolText.startingCompleteMicrosoftOfficeRemoval'))
        Stop-ToolkitProcesses -ProcessNames @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
        Write-StyledMessage -Type 'Info' -Text ("🔍 " + (Get-SourceTextLoc 'toolText.windowsVersionDetection'))
        $windowsVersion = Get-WindowsVersion
        Write-StyledMessage -Type 'Info' -Text ("🎯 " + (Get-SourceTextLoc 'toolText.versionDetected0' -Args @($windowsVersion)))
        $success = switch ($windowsVersion) {
            'Windows11_23H2_Plus' {
                Write-StyledMessage -Type 'Info' -Text ("🚀 " + (Get-SourceTextLoc 'toolText.usingGetHelpMethodForWindows1123h2'))
                Start-OfficeUninstallWithGetHelp
            }
            default {
                Write-StyledMessage -Type 'Info' -Text ("⚡ " + (Get-SourceTextLoc 'toolText.usingDirectRemovalForWindows1122h2OrEarlier'))
                Remove-OfficeDirectly
            }
        }
        $removalProgressText = Get-SourceTextLoc 'sourceText.removal'
        Write-Progress -Activity $removalProgressText -Completed -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Host ""
        if ($success) {
            Write-StyledMessage -Type 'Success' -Text ("🎉 " + (Get-SourceTextLoc 'toolText.officeRemovalComplete'))
            $needsReboot = $true
        }
        else {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.removalNotCompleted')
            Write-StyledMessage -Type 'Info' -Text ("💡 " + (Get-SourceTextLoc 'toolText.youCanTryAnAlternativeMethodOrManualRemoval'))
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.criticalErrorWhileRemovingOffice0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.criticalErrorInUninstallOffice') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text ("🧹التنظيف " + (Get-SourceTextLoc 'toolText.finalCleaning'))
        Remove-ItemSafely -Path $tempDir -Recurse
        Write-StyledMessage -Type 'Success' -Text ("🎯 " + (Get-SourceTextLoc 'toolText.officeUninstallFinished'))
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.uninstallOfficeSessionEnded')
    }
    if ($needsReboot) {
        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.removalCompleted') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
function AutoVideoDriverInstall {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "AutoVideoDriverInstall" -SubTitle (Get-SourceTextLoc 'script.AutoVideoDriverInstall')
    $desktopPath = $AppConfig.Paths.Desktop
    function Set-BlockWindowsUpdateDrivers {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.blockingAutomaticDriversFromWindowsUpdate')
        try {
            Set-RegistryValue -Path $AppConfig.Registry.WindowsUpdatePolicies -Name "ExcludeWUDriversInQualityUpdate" -Value 1
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.driverWuLockSet')
            $gpupdateResult = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.groupPolicyUpdateMayTake12Minutes') -Command 'gpupdate.exe' -Arguments '/force' -LogContextKey "Video-GPUpdate" -TimeoutSeconds 180
            if ($gpupdateResult -and $gpupdateResult.ExitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.updatedGroupPolicy'))
            }
            elseif ($gpupdateResult) {
                Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.gpupdateCompletedWithCode0IContinueAnyway' -Args @($($gpupdateResult.ExitCode))))
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.gpupdateDidNotRespondIContinueAnyway'))
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.driverWuBlockError0IContinueAnyway' -Args @($($_.Exception.Message))))
        }
    }
    try {
        Write-StyledMessage -Type 'Info' -Text ("🚀 " + (Get-SourceTextLoc 'toolText.startingAutomaticVideoDriverInstallation'))
        Set-BlockWindowsUpdateDrivers
        Write-StyledMessage -Type 'Info' -Text ("🔍 " + (Get-SourceTextLoc 'toolText.detectingGpuConfiguration'))
        $gpuAnalysis = VcardAnalizer
        $gpuManufacturer = $gpuAnalysis.PrimaryManufacturer
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.gpuDetected0' -Args @($gpuManufacturer))
        $stableDownloadDone = $false
        if ($gpuAnalysis.Matches.Count -gt 0) {
            foreach ($match in $gpuAnalysis.Matches) {
                if ([string]::IsNullOrWhiteSpace($match.DownloadUrl)) { continue }
                $targetName = if (-not [string]::IsNullOrWhiteSpace($match.FileName)) { $match.FileName } else { "$($match.Key).exe" }
                $targetPath = Join-Path $desktopPath $targetName
                $displayName = if (-not [string]::IsNullOrWhiteSpace($match.DisplayName)) { $match.DisplayName } else { $match.Key }
                if (Invoke-ToolkitDownload -Uri $match.DownloadUrl -OutputPath $targetPath -Description $displayName) {
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.stableDriverDownloadedToDesktop0' -Args @($displayName))
                    $stableDownloadDone = $true
                }
            }
        }
        if (-not $stableDownloadDone) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.noKnownStableDriversFoundIUseAutodetectFallback')
            switch ($gpuManufacturer) {
                'AMD' {
                    $amdPath = Join-Path $desktopPath "AMD-Autodetect.exe"
                    if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.AMDInstaller -OutputPath $amdPath -Description "AMD Auto-Detect Tool")) {
                        Write-StyledMessage -Type 'Error' -Text ((Get-SourceTextLoc 'toolText.unableToDownloadAmdInstallerAnnulment'))
                        return
                    }
                }
                'NVIDIA' {
                    $nvidiaPath = Join-Path $desktopPath "NVCleanstall_1.19.0.exe"
                    if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.NVCleanstall -OutputPath $nvidiaPath -Description "NVCleanstall")) {
                        Write-StyledMessage -Type 'Error' -Text ((Get-SourceTextLoc 'toolText.unableToDownloadNvcleanstallAnnulment'))
                        return
                    }
                }
                'Intel' {
                    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.intelGpuDownloadDriversManuallyFromIntelIfNecessary')
                }
                default {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.gpuNotDetectedDriverNotAvailableForAutomaticInstallation')
                }
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringDriverInstallation0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.errorInAutovideodriverinstall') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text ("🎯 " + (Get-SourceTextLoc 'toolText.autoVideoDriverInstallFinished'))
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.autovideodriverinstallSessionEnded')
    }
}
function VideoDriverReinstall {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "VideoDriverReinstall" -SubTitle (Get-SourceTextLoc 'script.VideoDriverReinstall')
    $driverToolsPath = $AppConfig.Paths.Drivers
    $desktopPath     = $AppConfig.Paths.Desktop
    function Set-BlockWindowsUpdateDrivers {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.blockingAutomaticDriversFromWindowsUpdate')
        try {
            Set-RegistryValue -Path $AppConfig.Registry.WindowsUpdatePolicies -Name "ExcludeWUDriversInQualityUpdate" -Value 1
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.driverWuLockSet')
            $gpupdateResult = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.groupPolicyUpdateMayTake12Minutes') -Command 'gpupdate.exe' -Arguments '/force' -LogContextKey "Video-GPUpdate" -TimeoutSeconds 180
            if ($gpupdateResult -and $gpupdateResult.ExitCode -eq 0) {
                Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.updatedGroupPolicy'))
            }
            elseif ($gpupdateResult) {
                Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.gpupdateCompletedWithCode0IContinueAnyway' -Args @($($gpupdateResult.ExitCode))))
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.gpupdateDidNotRespondIContinueAnyway'))
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.driverWuBlockError0IContinueAnyway' -Args @($($_.Exception.Message))))
        }
    }
    $needsReboot = $false
    try {
        Write-StyledMessage -Type 'Warning' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.startingVideoDriverReinstallationRepairProcedure'))
        Set-BlockWindowsUpdateDrivers
        Write-StyledMessage -Type 'Info' -Text ("📥 " + (Get-SourceTextLoc 'toolText.preparingToDownloadTheNecessaryTools'))
        $dduZipPath = Join-Path $driverToolsPath "DDU.zip"
        if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.DDUZip -OutputPath $dduZipPath -Description 'DDU (Display Driver Uninstaller)')) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToDownloadDduAnnulment')
            return
        }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.extractingDduToDesktop')
        try {
            Expand-Archive -Path $dduZipPath -DestinationPath $desktopPath -Force
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.dduExtractedToDesktop')
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.dduExtractionError0' -Args @($($_.Exception.Message)))
            return
        }
        $gpuAnalysis = VcardAnalizer
        $gpuManufacturer = $gpuAnalysis.PrimaryManufacturer
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.gpuDetected0' -Args @($gpuManufacturer))
        $stableDownloadDone = $false
        if ($gpuAnalysis.Matches.Count -gt 0) {
            foreach ($match in $gpuAnalysis.Matches) {
                if ([string]::IsNullOrWhiteSpace($match.DownloadUrl)) { continue }
                $targetName = if (-not [string]::IsNullOrWhiteSpace($match.FileName)) { $match.FileName } else { "$($match.Key).exe" }
                $targetPath = Join-Path $desktopPath $targetName
                $displayName = if (-not [string]::IsNullOrWhiteSpace($match.DisplayName)) { $match.DisplayName } else { $match.Key }
                if (Invoke-ToolkitDownload -Uri $match.DownloadUrl -OutputPath $targetPath -Description $displayName) {
                    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.stableDriverDownloadedToDesktop0' -Args @($displayName))
                    $stableDownloadDone = $true
                }
            }
        }
        if (-not $stableDownloadDone) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.noKnownStableDriversFoundIUseAutodetectFallback')
            switch ($gpuManufacturer) {
                'AMD' {
                    $amdPath = Join-Path $desktopPath "AMD-Autodetect.exe"
                    if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.AMDInstaller -OutputPath $amdPath -Description "AMD Auto-Detect Tool")) {
                        Write-StyledMessage -Type 'Error' -Text ((Get-SourceTextLoc 'toolText.unableToDownloadAmdInstallerAnnulment'))
                        return
                    }
                }
                'NVIDIA' {
                    $nvidiaPath = Join-Path $desktopPath "NVCleanstall_1.19.0.exe"
                    if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.NVCleanstall -OutputPath $nvidiaPath -Description "NVCleanstall")) {
                        Write-StyledMessage -Type 'Error' -Text ((Get-SourceTextLoc 'toolText.unableToDownloadNvcleanstallAnnulment'))
                        return
                    }
                }
                'Intel' {
                    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.intelGpuDownloadDriversManuallyFromIntelIfNecessary')
                }
                default {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.gpuNotDetectedOnlyDduWillBePlacedOnTheDesktop')
                }
            }
        }
        $batchPath = Join-Path $desktopPath "Switch to Normal Mode.bat"
        try {
            Set-Content -Path $batchPath -Value 'bcdedit /deletevalue {current} safeboot' -Encoding ASCII
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.batchSwitchToNormalModeBatCreatedOnDesktop')
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.failedToCreateSafeModeBatch0' -Args @($($_.Exception.Message)))
        }
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.warningTheSystemWillRebootIntoSafeMode')
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.inSafeModeRunDduToCleanTheDriversThenReinstallWithTheDesktopInstallerFinallyUseBatchToRetu')
        try {
            $null = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.safeModeConfigurationBcdedit') -Command 'bcdedit.exe' `
                -Arguments '/set {current} safeboot minimal' -LogContextKey "Video-BCDEdit"
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.safeModeConfiguredForNextBoot')
            $needsReboot = $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.safeModeConfigurationError0' -Args @($($_.Exception.Message)))
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.criticalErrorDuringDriverReinstallation0' -Args @($($_.Exception.Message)))
        Write-ToolkitLog -Level ERROR -Message (Get-SourceTextLoc 'toolText.errorInVideodriverreinstall') -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text ("🎯 " + (Get-SourceTextLoc 'toolText.videoDriverReinstallFinished'))
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.videodriverreinstallSessionEnded')
    }
    if ($needsReboot) {
        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.restartInSafeModeForDdu') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
function GamingToolkit {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateRange(0, 300)]
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "GamingToolkit" -SubTitle (Get-SourceTextLoc 'script.GamingToolkit')
    $timeout = 3600
    function Test-WingetPackageAvailable([string]$PackageId) {
        try {
            $searchResult = winget search --id $PackageId --accept-source-agreements 2>&1
            $outputStr = $searchResult -join ' '
            if ($outputStr -match [regex]::Escape($PackageId)) {
                return $true
            }
            $listResult = winget list --id $PackageId --accept-source-agreements 2>&1
            $listStr = $listResult -join ' '
            if ($listStr -match [regex]::Escape($PackageId)) {
                return $true
            }
            return $false
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.packetVerificationError01' -Args @($PackageId, $errorMessage))
            return $false
        }
    }
    function Invoke-WingetInstallWithProgress([string]$PackageId, [string]$DisplayName, [int]$Step, [int]$Total) {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.01Installation2' -Args @($Step, $Total, $DisplayName))
        $outFile = "$env:TEMP\winget_$PackageId.log"
        $errFile = "$env:TEMP\winget_err_$PackageId.log"
        try {
            $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.installation0' -Args @($DisplayName)) -Command 'winget' -Arguments @('install', '--id', $PackageId, '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements') -TimeoutSeconds $timeout -LogContextKey "Gaming-Install-$PackageId"
            $exitCode = if ($null -ne $result -and ($result.PSObject.Properties.Name -contains 'ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)
            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.installed0' -Args @($DisplayName))
                return @{ Success = $true; ExitCode = $exitCode }
            }
            else {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.installationError0Code1' -Args @($DisplayName, $exitCode))
                return @{ Success = $false; ExitCode = $exitCode }
            }
        }
        catch {
            Clear-ProgressLine
            Clear-ProgressLine
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.exception01' -Args @($DisplayName, $($_.Exception.Message)))
            return @{ Success = $false }
        }
        finally {
            Remove-ItemSafely -Path $outFile
            Remove-ItemSafely -Path $errFile
        }
    }
    Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.preparation') -Timer -Action { Start-Sleep 5 } -TimeoutSeconds 5
    Show-Header -SubTitle (Get-SourceTextLoc 'script.GamingToolkit')
    Write-StyledMessage -Type 'Info' -Text ("🔍 " + (Get-SourceTextLoc 'toolText.checkWingetAvailability'))
    Update-EnvironmentPath
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'toolText.wingetNotAvailableStartingAutomaticRecovery'))
        $resetOk = Reset-Winget
        Update-EnvironmentPath
        if (-not $resetOk -or -not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Error' -Text ((Get-SourceTextLoc 'toolText.wingetRestoreFailedUnableToProceedWithGamingToolkit'))
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.pressAnyKeyToContinue')
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
    }
    Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'toolText.wingetAvailable'))
    Write-StyledMessage -Type 'Info' -Text ("🔄 " + (Get-SourceTextLoc 'toolText.wingetSourcesUpdate'))
    try {
        winget source update *>$null
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.updatedSources')
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.sourceUpdateError0' -Args @($($_.Exception.Message)))
    }
    Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.enablingNetframework'))
    $netFxFeatures = @('NetFx4-AdvSrvs', 'NetFx3')
    $netFxFailed = $false
    foreach ($feature in $netFxFeatures) {
        try {
            $dismResult = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.netframeworkFeatureEnabled0' -Args @($feature)) -Command 'dism.exe' -Arguments @('/Online', '/Enable-Feature', "/FeatureName:$feature", '/All', '/NoRestart') -TimeoutSeconds $timeout -LogContextKey "Gaming-NetFx-$feature"
            $exitCode = if ($null -ne $dismResult -and ($dismResult.PSObject.Properties.Name -contains 'ExitCode')) { $dismResult.ExitCode } else { -1 }
            if ($exitCode -in @(0, 3010)) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.netframeworkFeatureEnabled0' -Args @($feature))
            }
            else {
                $netFxFailed = $true
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorEnablingNetframeworkFeature0Code1' -Args @($feature, $exitCode))
            }
        }
        catch {
            $netFxFailed = $true
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorEnablingNetframeworkFeature0Code1' -Args @($feature, $($_.Exception.Message)))
        }
    }
    if (-not $netFxFailed) {
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.netframeworkEnabled')
    }
    $runtimes = @(
        "Microsoft.DotNet.DesktopRuntime.3_1",
        "Microsoft.DotNet.DesktopRuntime.5",
        "Microsoft.DotNet.DesktopRuntime.6",
        "Microsoft.DotNet.DesktopRuntime.7",
        "Microsoft.DotNet.DesktopRuntime.8",
        "Microsoft.DotNet.DesktopRuntime.9",
        "Microsoft.DotNet.DesktopRuntime.10",
        "Microsoft.VCRedist.2010.x64",
        "Microsoft.VCRedist.2010.x86",
        "Microsoft.VCRedist.2012.x64",
        "Microsoft.VCRedist.2012.x86",
        "Microsoft.VCRedist.2013.x64",
        "Microsoft.VCRedist.2013.x86",
        "Microsoft.VCLibs.Desktop.14",
        "Microsoft.VCRedist.2015+.x64",
        "Microsoft.VCRedist.2015+.x86"
    )
    Write-StyledMessage -Type 'Info' -Text ("🔥 " + (Get-SourceTextLoc 'toolText.installingNetRuntimeAndVcredist'))
    for ($runtimeIndex = 0; $runtimeIndex -lt $runtimes.Count; $runtimeIndex++) {
        Invoke-WingetInstallWithProgress $runtimes[$runtimeIndex] $runtimes[$runtimeIndex] ($runtimeIndex + 1) $runtimes.Count *>$null
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.runtimesCompleted')
    Write-StyledMessage -Type 'Info' -Text ("🎮 " + (Get-SourceTextLoc 'toolText.directxInstallation'))
    $dxDir = Join-Path $AppConfig.Paths.LocalAppData "WinToolkit\Directx"
    $dxPath = "$dxDir\dxwebsetup.exe"
    if (-not (Test-Path $dxDir)) { New-Item -Path $dxDir -ItemType Directory -Force *>$null }
    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.DirectXWebSetup -OutFile $dxPath -ErrorAction Stop
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.directxDownloaded')
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.directxInstallation') -Command $dxPath -TimeoutSeconds $timeout -LogContextKey "Gaming-DirectX"
        Clear-ProgressLine
        Clear-ProgressLine
        if ($null -eq $result) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.directxProcessDidNotStartCorrectly')
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.directxTimeout')
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 3010, 5100, -9, 9, -1442840576)
            $messageType = if ($exitCode -in $successCodes) { 'Success' } else { 'Error' }
            $messageText = if ($exitCode -in $successCodes) {
                Get-SourceTextLoc 'toolText.extra.directxInstalledCode0' -Args @($exitCode)
            }
            else {
                Get-SourceTextLoc 'toolText.extra.directxError0' -Args @($exitCode)
            }
            Write-StyledMessage -Type $messageType -Text $messageText
        }
    }
    catch {
        Clear-ProgressLine
        Clear-ProgressLine
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringDirectxInstallation0' -Args @($($_.Exception.Message)))
    }
    $gameClients = @(
        "Amazon.Games", "GOG.Galaxy", "EpicGames.EpicGamesLauncher",
        "ElectronicArts.EADesktop", "Playnite.Playnite", "Valve.Steam",
        "Ubisoft.Connect"
    )
    Write-StyledMessage -Type 'Info' -Text ("🎮 " + (Get-SourceTextLoc 'toolText.gameClientInstallation'))
    for ($clientIndex = 0; $clientIndex -lt $gameClients.Count; $clientIndex++) {
        Invoke-WingetInstallWithProgress $gameClients[$clientIndex] $gameClients[$clientIndex] ($clientIndex + 1) $gameClients.Count *>$null
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.clientsInstalled')
    Write-StyledMessage -Type 'Info' -Text ("🎮 " + (Get-SourceTextLoc 'toolText.reinstallingXboxGameBarApp'))
    $xboxPackages = @("9NZKPSTSNW4P", "9MV0B5HZVK9Z")
    foreach ($pkg in $xboxPackages) {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.reinstallation0' -Args @($pkg))
        $outFile = "$env:TEMP\winget_$pkg.log"
        $errFile = "$env:TEMP\winget_err_$pkg.log"
        try {
            $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.reinstallation0' -Args @($pkg)) -Process -Action {
                $procParams = @{
                    FilePath               = 'winget'
                    ArgumentList           = @('install', '--id', $pkg, '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements', '--force')
                    PassThru               = $true
                    NoNewWindow            = $true
                    RedirectStandardOutput = $outFile
                    RedirectStandardError  = $errFile
                }
                Start-Process @procParams
            } -TimeoutSeconds $timeout -UpdateInterval 700
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)
            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.reinstalled0' -Args @($pkg))
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Code1' -Args @(${pkg}, $exitCode))
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.error' -Args @($pkg, $($_.Exception.Message)))
        }
        finally {
            Remove-ItemSafely -Path $outFile
            Remove-ItemSafely -Path $errFile
        }
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.xboxReinstalled')
    Write-StyledMessage -Type 'Info' -Text ("🎮 " + (Get-SourceTextLoc 'toolText.installingBattleNet'))
    $battleNetPkg = "Blizzard.BattleNet"
    $outFile = "$env:TEMP\winget_$battleNetPkg.log"
    $errFile = "$env:TEMP\winget_err_$battleNetPkg.log"
    $battleNetInstallRoot = Join-Path ${env:ProgramFiles(x86)} "Battle.net"
    if (-not (Test-Path $battleNetInstallRoot)) {
        New-Item -Path $battleNetInstallRoot -ItemType Directory -Force *>$null
    }
    try {
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.installingBattleNet') -Process -Action {
            $procParams = @{
                FilePath               = 'winget'
                ArgumentList           = @('install', '--id', $battleNetPkg, '--exact', '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements', '--force', '--location', $battleNetInstallRoot)
                PassThru               = $true
                NoNewWindow            = $true
                RedirectStandardOutput = $outFile
                RedirectStandardError  = $errFile
            }
            Start-Process @procParams
        } -TimeoutSeconds $timeout -UpdateInterval 700
        Clear-ProgressLine
        Clear-ProgressLine
        if ($null -eq $result) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.battleNetProcessDidNotStartProperly')
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.battleNetTimedOut')
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)
            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.battleNetInstalled')
            }
            else {
                $errDetail = ''
                if (Test-Path $errFile) { $errDetail = (Get-Content -Path $errFile -Raw -ErrorAction SilentlyContinue) }
                if ([string]::IsNullOrWhiteSpace($errDetail) -and (Test-Path $outFile)) { $errDetail = (Get-Content -Path $outFile -Raw -ErrorAction SilentlyContinue) }
                if (-not [string]::IsNullOrWhiteSpace($errDetail)) {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.battleNetCode0' -Args @($exitCode))
                    Write-StyledMessage -Type 'Warning' -Text ($errDetail.Trim() -split "`n" | Select-Object -First 5 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() } | Join-String -Separator "`n")
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.battleNetCode0' -Args @($exitCode))
                }
            }
        }
    }
    catch {
        Clear-ProgressLine
        Clear-ProgressLine
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorInstallingBattleNet0' -Args @($($_.Exception.Message)))
    }
    finally {
        Remove-ItemSafely -Path $outFile
        Remove-ItemSafely -Path $errFile
    }
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.pressAnyKeyToContinue')
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Write-StyledMessage -Type 'Info' -Text ("🧹 " + (Get-SourceTextLoc 'toolText.autostartCleaner'))
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    @('Steam', 'Battle.net', 'GOG Galaxy', 'GogGalaxy', 'GalaxyClient') | ForEach-Object {
        if (Get-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.removed0' -Args @($_))
        }
    }
    $startupPath = $AppConfig.Paths.Startup
    @('Steam.lnk', 'Battle.net.lnk', 'GOG Galaxy.lnk') | ForEach-Object {
        $path = Join-Path $startupPath $_
        Remove-ItemSafely -Path $path
        if (-not (Test-Path $path)) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.removed0' -Args @($_))
        }
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.cleaningCompleted')
    Write-StyledMessage -Type 'Info' -Text ("⚡ " + (Get-SourceTextLoc 'toolText.energyProfileConfiguration'))
    $ultimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $planName = "WinToolkit Gaming Performance"
    $guid = $null
    $existingPlan = powercfg -list | Select-String -Pattern $planName -ErrorAction SilentlyContinue
    if ($existingPlan) {
        $guid = ($existingPlan.Line -split '\s+')[3]
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.existingPlanFound')
    }
    else {
        try {
            $output = powercfg /duplicatescheme $ultimateGUID | Out-String
            if ($output -match "\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b") {
                $guid = $matches[0]
                powercfg /changename $guid $planName 'Optimized for Gaming by WinToolkit' *>$null
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.planCreated')
            }
            else {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.planCreationError')
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringEnergyPlanDuplication0' -Args @($($_.Exception.Message)))
        }
    }
    if ($guid) {
        try {
            powercfg -setactive $guid *>$null
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.planActivated')
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringEnergyPlanActivation0' -Args @($($_.Exception.Message)))
        }
    }
    else {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToActivatePlan')
    }
    Write-StyledMessage -Type 'Info' -Text ("🔕 " + (Get-SourceTextLoc 'toolText.doNotDisturbActivation'))
    try {
        Set-ItemProperty -Path $AppConfig.Registry.FocusAssist -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0 -Force
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.doNotDisturbActive')
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringFocusAssistConfiguration0' -Args @($($_.Exception.Message)))
    }
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.gamingToolkitCompleted')
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.systemOptimizedForGaming')
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)
    Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.rebootRequired') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
}
function WinExportLog {
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )
    Start-ToolkitSession -ToolName "WinExportLog" -SubTitle (Get-SourceTextLoc 'script.WinExportLog')
    $logSourcePath = $AppConfig.Paths.Logs
    $desktopPath   = $AppConfig.Paths.Desktop
    $timestamp     = Get-Date -Format "yyyyMMdd_HHmmss"
    $zipFileName   = "WinToolkit_Logs_$timestamp.zip"
    $zipFilePath   = Join-Path $desktopPath $zipFileName
    $tempFolder    = Join-Path $AppConfig.Paths.TempFolder "WinToolkit_Logs_Temp_$timestamp"
    try {
        Write-StyledMessage -Type 'Info' -Text ("📂 " + (Get-SourceTextLoc 'toolText.checkPresenceOfLogFolder'))
        if (-not (Test-Path $logSourcePath -PathType Container)) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.theLogsFolder0WasNotFoundUnableToExport' -Args @($logSourcePath))
            return
        }
        Write-StyledMessage -Type 'Info' -Text ("🗜️ " + (Get-SourceTextLoc 'toolText.compressingLogsSomeFilesInUseMayBeIgnored'))
        $null = Remove-ItemSafely -Path $tempFolder -Recurse
        New-Item -ItemType Directory -Path $tempFolder -Force *>$null
        $filesCopied  = 0
        $filesSkipped = 0
        try {
            Get-ChildItem -Path $logSourcePath -File | ForEach-Object {
                try {
                    Copy-Item $_.FullName -Destination $tempFolder -Force -ErrorAction Stop
                    $filesCopied++
                }
                catch {
                    $filesSkipped++
                    Write-Debug (Get-SourceTextLoc 'uiText.fileIgnored01' -Args @($_.Name, $_.Exception.Message))
                }
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorCopyingFiles0' -Args @($($_.Exception.Message)))
        }
        if ($filesCopied -gt 0) {
            $sourcePath = Join-Path $tempFolder '*'
            $compressionAction = {
                Start-Job -ScriptBlock {
                    param([string]$SourcePath, [string]$DestinationPath)
                    $ErrorActionPreference = 'Stop'
                    Compress-Archive -Path $SourcePath -DestinationPath $DestinationPath `
                        -CompressionLevel Optimal -Force -ErrorAction Stop
                    return $true
                } -ArgumentList $sourcePath, $zipFilePath
            }.GetNewClosure()
            $compressionSucceeded = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.compressingLogsSomeFilesInUseMayBeIgnored') `
                -Job -TimeoutSeconds 300 -Action $compressionAction
            if ($compressionSucceeded -eq $true -and (Test-Path $zipFilePath -PathType Leaf)) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.logsCompressedSuccessfullySavedFile0OnDesktop' -Args @($zipFileName))
                if ($filesSkipped -gt 0) {
                    Write-StyledMessage -Type 'Info' -Text ("⚠️ " + (Get-SourceTextLoc 'toolText.0FilesIgnoredBecauseTheyAreInUseOrNotAccessible' -Args @($filesSkipped)))
                }
                Write-StyledMessage -Type 'Info' -Text ("📩 " + (Get-SourceTextLoc 'toolText.send0DesktopViaTelegramHttpsTMeMagnetarmanOrEmailMeMagnetarmanComForDiagnostics' -Args @($zipFileName)))
            }
            else {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unknownErrorZipFileWasNotCreated')
            }
        }
        else {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.noLogFilesCopiedCheckPermissionsAndThatTheFilesExist')
        }
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "WinExportLog" -Message (Get-SourceTextLoc 'toolText.extra.errorCompressingLogs')
    }
    finally {
        $null = Remove-ItemSafely -Path $tempFolder -Recurse
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.winexportlogSessionEnded')
    }
}
$menuStructure = @(
    @{ 'Name' = 'Windows'; 'CategoryKey' = 'category.windows'; 'Icon' = '🔧'; 'Scripts' = @(
            [pscustomobject]@{Name = 'WinRepairToolkit'; Description = 'Windows Repair'; DescriptionKey = 'script.WinRepairToolkit'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinUpdateReset'; Description = 'Reset Windows Update'; DescriptionKey = 'script.WinUpdateReset'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset'; DescriptionKey = 'script.WinReinstallStore'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinBackupDriver'; Description = 'Backup Driver PC'; DescriptionKey = 'script.WinBackupDriver'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinCleaner'; Description = 'Temporary File Cleanup'; DescriptionKey = 'script.WinCleaner'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'DisableBitlocker'; Description = 'Disable BitLocker'; DescriptionKey = 'script.DisableBitlocker'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinDeleteUserProfiles'; Description = 'Delete Windows User Profiles'; DescriptionKey = 'script.WinDeleteUserProfiles'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Office'; 'CategoryKey' = 'category.office'; 'Icon' = '🏢'; 'Scripts' = @(
            [pscustomobject]@{Name = 'Install-Office'; Description = 'Install Office Basic'; DescriptionKey = 'script.Install-Office'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'Repair-Office'; Description = 'Repair Office'; DescriptionKey = 'script.Repair-Office'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'Uninstall-Office'; Description = 'Remove Office'; DescriptionKey = 'script.Uninstall-Office'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Driver & Gaming'; 'CategoryKey' = 'category.driverGaming'; 'Icon' = '🎮'; 'Scripts' = @(
            [pscustomobject]@{Name = 'AutoVideoDriverInstall'; Description = 'Auto Install Driver Video [Nvidia-AMD]'; DescriptionKey = 'script.AutoVideoDriverInstall'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'VideoDriverReinstall'; Description = 'Reinstall Video Driver'; DescriptionKey = 'script.VideoDriverReinstall'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'GamingToolkit'; Description = 'Gaming Toolkit'; DescriptionKey = 'script.GamingToolkit'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Support'; 'CategoryKey' = 'category.support'; 'Icon' = '🕹️'; 'Scripts' = @(
            [pscustomobject]@{Name = 'WinExportLog'; Description = 'Export WinToolkit Logs'; DescriptionKey = 'script.WinExportLog'; Action = 'RunFunction' }
        )
    }
)
if (-not $ImportOnly) {
    Initialize-ToolkitPaths
    WinOSCheck
    Test-WindowsUpdateStatus
}
if (-not $ImportOnly -and -not $Global:GuiSessionActive) {
    Write-Host ""
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'menu.startedInteractive')
    Write-Host ""
    function Confirm-UserProfileDeletion {
        Write-Host ''
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'confirm.profile.warn1')
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'confirm.profile.warn2')
        Write-Host ''
        Write-Host "💎 [1] $(Get-SourceTextLoc 'confirm.profile.yes')" -ForegroundColor White
        Write-Host "[INVIO] $(Get-SourceTextLoc 'menu.back')" -ForegroundColor Gray
        $firstConfirm = Microsoft.PowerShell.Utility\Read-Host (Get-SourceTextLoc 'menu.choice')
        if ($firstConfirm -ne '1') {
            return $false
        }
        Write-Host ''
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'confirm.profile.sure')
        Write-Host ''
        Write-Host "💎 [1] $(Get-SourceTextLoc 'confirm.profile.accept')" -ForegroundColor White
        Write-Host "[INVIO] $(Get-SourceTextLoc 'menu.back')" -ForegroundColor Gray
        $secondConfirm = Microsoft.PowerShell.Utility\Read-Host (Get-SourceTextLoc 'menu.choice')
        return ($secondConfirm -eq '1')
    }
    function Show-LanguageMenu {
        while ($true) {
            Show-Header -SubTitle (Get-SourceTextLoc 'menu.language')
            Write-Host ''
            Write-Host "==== 🌐 $(Get-SourceTextLoc 'menu.chooseLanguage') 🌐 ====" -ForegroundColor Cyan
            Write-Host ''
            $languages = @(Get-AvailableSourceTextLanguages)
            if ($languages.Count -eq 0) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'menu.noLanguages')
                Start-Sleep -Seconds 2
                return
            }
            for ($i = 0; $i -lt $languages.Count; $i++) {
                $marker = if ($languages[$i].Code -eq $Global:SourceTextLanguage) { '*' } else { ' ' }
                $aiTag = if ($languages[$i].AiTranslated) { ' [AI Trad.]' } else { '' }
                Write-Host "💎 [$($i + 1)] $marker $($languages[$i].NativeName) ($($languages[$i].Code))$aiTag" -ForegroundColor White
            }
            Write-Host ''
            Write-Host "↩️ [0] $(Get-SourceTextLoc 'menu.back')" -ForegroundColor Gray
            Write-Host ''
            $choice = Microsoft.PowerShell.Utility\Read-Host (Get-SourceTextLoc 'menu.choice')
            if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq '0') { return }
            $parsed = 0
            if ([int]::TryParse($choice, [ref]$parsed) -and $parsed -ge 1 -and $parsed -le $languages.Count) {
                $selectedLanguage = $languages[$parsed - 1]
                Set-SourceTextLanguage -LanguageCode $selectedLanguage.Code
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'menu.languageChanged' -Args @($selectedLanguage.NativeName))
                Start-Sleep -Seconds 1
                return
            }
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'menu.invalidSelection')
            Start-Sleep -Seconds 1
        }
    }
    :MainMenu while ($true) {
        Show-Header -SubTitle (Get-SourceTextLoc 'menu.main')
        $width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 }
        Write-Host ''
        Write-Host "==== 💻 $(Get-SourceTextLoc 'system.infoTitle') 💻 ====" -ForegroundColor Cyan
        Write-Host ''
        $si = Get-SystemInfo
        if ($si) {
            $editionIcon = if ($si.ProductName -match "Pro") { "🔧" } else { "💻" }
            Write-Host "💻 $(Get-SourceTextLoc 'system.edition'): $editionIcon $($si.ProductName)" -ForegroundColor White
            Write-Host "🆔 $(Get-SourceTextLoc 'system.version'): " -NoNewline -ForegroundColor White
            Write-Host (Get-SourceTextLoc 'uiText.ver0Build1' -Args @($($si.DisplayVersion), $($si.BuildNumber))) -ForegroundColor Green
            Write-Host "🔑 $(Get-SourceTextLoc 'system.architecture'): $($si.Architecture)"  -ForegroundColor White
            Write-Host "🔧 $(Get-SourceTextLoc 'system.computerName'): $($si.ComputerName)"       -ForegroundColor White
            Write-Host "🧠 $(Get-SourceTextLoc 'uiText.ram0Gb' -Args @($($si.TotalRAM)))" -ForegroundColor White
            Write-Host "💾 $(Get-SourceTextLoc 'system.disk'): " -NoNewline -ForegroundColor White
            $diskFreeGB = $si.FreeDisk
            $displayString = "$($si.FreePercentage)% $(Get-SourceTextLoc 'system.free') ($($diskFreeGB) GB)"
            $diskColor = if ($diskFreeGB -lt 50) { "Red" } elseif ($diskFreeGB -le 80) { "Yellow" } else { "Green" }
            Write-Host $displayString -ForegroundColor $diskColor -NoNewline
            Write-Host ""
            $blStatusKey = Get-BitlockerStatus -Key
            $blStatus = Get-SourceTextLoc $blStatusKey
            $blColor = if ($blStatusKey -in @('bitlocker.status.off', 'bitlocker.status.notConfigured')) { 'Green' } elseif ($blStatusKey -in @('bitlocker.status.suspended', 'bitlocker.status.decrypting')) { 'Yellow' } else { 'Red' }
            Write-Host "🔒 $(Get-SourceTextLoc 'system.bitlockerStatus'): " -NoNewline -ForegroundColor White
            Write-Host "$blStatus" -ForegroundColor $blColor
        }
        Write-Host ('*' * 50) -ForegroundColor Red
        Write-Host ""
        $allScripts = @(); $idx = 1
        $languageMenuIndex = $null
        foreach ($cat in $menuStructure) {
            Write-Host "==== $($cat.Icon) $(Get-SourceTextMenuText $cat) $($cat.Icon) ====" -ForegroundColor Cyan
            Write-Host ""
            foreach ($s in $cat.Scripts) {
                $allScripts += $s
                Write-Host "💎 [$idx] $(Get-SourceTextMenuText $s)" -ForegroundColor White
                $idx++
            }
            if ($cat.Name -eq 'Support' -and -not $Global:GuiSessionActive) {
                $languageMenuIndex = $idx
                Write-Host "`e[1m🌐 [$idx] $(Get-SourceTextLoc 'menu.changeLanguage')`e[0m" -ForegroundColor Yellow
                $idx++
            }
            Write-Host ""
        }
        Write-Host "==== $(Get-SourceTextLoc 'menu.exitSection') ====" -ForegroundColor Red
        Write-Host ""
        Write-Host "❌ [0] $(Get-SourceTextLoc 'menu.exitToolkit')" -ForegroundColor Red
        Write-Host ""
        $rawInput = Microsoft.PowerShell.Utility\Read-Host (Get-SourceTextLoc 'menu.multiPrompt')
        if ($rawInput -eq [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('V2luZG93cyDDqCB1bmEgbWVyZGE='))) {
            Start-Process ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly93d3cueW91dHViZS5jb20vd2F0Y2g/dj15QVZVT2tlNGtvYw==')))
            continue
        }
        $maxMenuOption = $allScripts.Count + $(if ($null -ne $languageMenuIndex) { 1 } else { 0 })
        $rawSelections = Read-ValidatedChoice -Prompt (Get-SourceTextLoc 'menu.multiPromptShort') -Min 0 -Max $maxMenuOption -AllowZero -RawInput $rawInput
        $c = if ($rawSelections.Count -gt 0) { $rawSelections[0] } else { '' }
        if ($c -eq 0 -or $c -eq '0') {
            Write-StyledMessage -type 'Warning' -text (Get-SourceTextLoc 'menu.support')
            Write-StyledMessage -type 'Success' -text (Get-SourceTextLoc 'menu.closing')
            Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'uiText.wintoolkitSessionTerminatedByUser')
            Start-Sleep -Seconds 3
            break
        }
        if ($null -ne $languageMenuIndex -and $rawSelections -contains $languageMenuIndex) {
            Show-LanguageMenu
            continue
        }
        $selections = @($rawSelections | Where-Object { $_ -ge 1 -and $_ -le $maxMenuOption })
        if ($selections.Count -eq 0) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'menu.invalidSelection')
            Start-Sleep -Seconds 2
            continue
        }
        $Global:ExecutionLog = @()
        $Global:NeedsFinalReboot = $false
        $isMultiScript = ($selections.Count -gt 1)
        Write-Host ''
        if ($isMultiScript) {
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'run.sequence' -Args @($selections.Count))
            Write-Host ''
        }
        foreach ($sel in $selections) {
            $scriptToRun = $allScripts[$sel - 1]
            $scriptDescription = Get-SourceTextMenuText $scriptToRun
            if ($scriptToRun.Name -eq 'WinDeleteUserProfiles' -and -not (Confirm-UserProfileDeletion)) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'run.cancelled')
                Start-Sleep -Seconds 2
                continue MainMenu
            }
            Write-StyledMessage -Type 'Progress' -Text (Get-SourceTextLoc 'run.start' -Args @($scriptDescription))
            Write-Host ''
            try {
                if ($isMultiScript) { & ([scriptblock]::Create("$($scriptToRun.Name) -SuppressIndividualReboot")) }
                else { & $ExecutionContext.InvokeCommand.GetCommand($scriptToRun.Name, 'Function') }
                $Global:ExecutionLog += @{ Name = $scriptDescription; Success = $true }
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'run.error' -Args @($scriptDescription, $_.Exception.Message))
                $Global:ExecutionLog += @{ Name = $scriptDescription; Success = $false; Error = $_.Exception.Message }
            }
            Write-Host ''
        }
        if ($isMultiScript) {
            Write-Host ''
            $tableRows = $Global:ExecutionLog | ForEach-Object {
                @{ Operation = $_.Name; Status = if ($_.Success) { "✅ $(Get-SourceTextLoc 'summary.completed')" } else { "❌ $(Get-SourceTextLoc 'summary.error')" }; Detail = if ($_.Error) { $_.Error } else { '' } }
            }
            Show-ConsoleTable -Rows $tableRows -Columns @(
                @{ Header = (Get-SourceTextLoc 'summary.operation'); Key = 'Operation' },
                @{ Header = (Get-SourceTextLoc 'summary.status'); Key = 'Status' },
                @{ Header = (Get-SourceTextLoc 'summary.detail'); Key = 'Detail' }
            ) -Title "📊 $(Get-SourceTextLoc 'summary.title')"
            Write-Host ''
        }
        if ($Global:NeedsFinalReboot) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'reboot.required')
            if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message (Get-SourceTextLoc 'reboot.countdown')) {
                Restart-Computer -Force
            }
            else {
                Write-Host ''
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'reboot.reminder')
            }
        }
        Write-Host "`n$(Get-SourceTextLoc 'menu.pressEnter')" -ForegroundColor Gray
        $null = Read-Host
    }
}
else {
    Write-Verbose "═══════════════════════════════════════════════════════════"
    Write-Verbose ("  " + (Get-SourceTextLoc 'uiText.wintoolkitLoadedInLibraryMode'))
    Write-Verbose ("  " + (Get-SourceTextLoc 'uiText.functionsAvailableTuiMenuSuppressed'))
    Write-Verbose ("  💎 " + (Get-SourceTextLoc 'sourceText.version') + ": $ToolkitVersion")
    Write-Verbose "═══════════════════════════════════════════════════════════"
    $Global:menuStructure = $menuStructure
}
