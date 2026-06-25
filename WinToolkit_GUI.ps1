<#
.SYNOPSIS
    WinToolkit GUI v3.0
.DESCRIPTION
    Refactored WinToolkit GUI that dynamically loads Core Script (WinToolkit.ps1)
    Features: Remote Core loading, dynamic menu generation, output bridging, version sync
.NOTES
    Version: Dynamic (extracted from Core)
    Architecture: Thin Client / Backend separation
    Author: MagnetarMan
#>

#Requires -Version 7.0

# 1. Flag per dire al Core di NON mostrare il menu (CRITICO)
$Global:GuiSessionActive = $true

# =============================================================================
# GUI VERSION CONFIGURATION (Separate from Core Version)
# =============================================================================
$Global:GuiVersion = "3.0.0 (Build 7)"  # Format: CoreVersion.GuiBuildNumber

# =============================================================================
# CONFIGURATION AND CONSTANTS
# =============================================================================
$ScriptTitle = "WinToolkit GUI Edition by MagnetarMan"
$LogDirectory = "$env:LOCALAPPDATA\WinToolkit\logs"
$WindowWidth = 1280     # HD ready resolution in 16:9.
$WindowHeight = 720     # HD ready resolution in 16:9.
$FontFamily = "JetBrains Mono Nerd Font, Cascadia Code, Consolas, Courier New"
$FontSize = @{Small = 14; Medium = 16; Large = 18; Title = 20; Header = 28}

# Emoji mappings for GUI elements
$emojiMappings = @{
    # Header and Branding
    "ToolIcon"                 = "🛠️"
    "SendErrorLogsImage"       = "📡"

    # Funzioni Disponibili - Categorie
    "CategorySystem"           = "⚙️"
    "CategoryMaintenance"      = "🔧"
    "CategoryOptimization"     = "🚀"
    "CategoryRepair"           = "🪛"
    "CategoryBackup"           = "💾"
    "CategoryTweaks"           = "⚡"

    # Script Icons specifici
    "ScriptPowerShell"         = "💻"
    "ScriptWinget"             = "📦"
    "ScriptCleaner"            = "🧹"
    "ScriptRepair"             = "🔧"
    "ScriptBackup"             = "💾"
    "ScriptUpdate"             = "🔄"
    "ScriptDriver"             = "🎮"
    "ScriptNetwork"            = "🌐"
    "ScriptPrivacy"            = "🔒"
    "ScriptPerformance"        = "🔧"
    "ScriptSecurity"           = "🛡️"
    "ScriptDebloat"            = "🔧"
    "ScriptTweak"              = "⚙️"

    # System Info Icons (for Image controls)
    "SysInfoTitleImage"        = "🛠️"
    "SysInfoEditionImage"      = "💿"
    "SysInfoVersionImage"      = "📊"
    "SysInfoArchitectureImage" = "⚙️"
    "SysInfoComputerNameImage" = "🏷️"
    "SysInfoRAMImage"          = "🧠"
    "SysInfoDiskImage"         = "💾"

    # Status LEDs
    "LEDStatusGreen"           = "🟢"
    "LEDStatusYellow"          = "🟡"
    "LEDStatusRed"             = "🧰"

    # Play Icon for Execute Button
    "ExecutePlayImage"         = "▶️"

    # Output e Log
    "OutputLogImage"           = "📋"

    # Execute Button
    "ExecuteButtonImage"       = "▶️"

    # Support Icon (Joystick)
    "SupportImage"             = "🕹️"

    # Bitlocker Icon
    "BitlockerImage"           = "🔒"
}

# =============================================================================
# EMOJI ICONS CONFIGURATION
# =============================================================================
$localIconBasePath = Join-Path $env:LOCALAPPDATA "WinToolkit\assets\png"
$remoteIconBasePath = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/assets/png"

# =============================================================================
# GLOBAL VARIABLES
# =============================================================================
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$mainLog = "$LogDirectory\WinToolkit_GUI_$dateTime.log"
$window = $null
$outputTextBox = $null
$executeButton = $null
$SysInfoEdition = $null
$SysInfoVersion = $null
$SysInfoArchitecture = $null
$SysInfoComputerName = $null
$SysInfoRAM = $null
$SysInfoDisk = $null
$SysInfoScriptCompatibility = $null
$SysInfoScriptCompatibilityImage = $null
$SysInfoBitlocker = $null
$progressBar = $null
$actionsPanel = $null

# Async execution variables (for GUI responsiveness)
$Global:ScriptJob = $null
$Global:JobMonitorTimer = $null
$Global:SelectedScriptsQueue = @()
$Global:CurrentScriptIndex = 0
$Global:LastJobOutputCount = 0
$Global:IsInputWaiting = $false
$Global:RebootRequired = $false
$Global:NeedsFinalReboot = $false
$Global:GuiBridgeTraceMode = $false # Set to $true to see unrecognized job output for debugging

# Global variables to optimize RichTextBox logging
$Global:LastLogEntryType = $null
$Global:LastLogParagraphRef = $null

# =============================================================================
# CORE INTEGRATION CONFIGURATION
# =============================================================================

# Configurazione per il caricamento dinamico del Core Script
$Global:CoreConfig = @{
    RemoteUrl         = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/WinToolkit.ps1"
    LocalCachePath    = "$env:LOCALAPPDATA\WinToolkit\cache\WinToolkit_Core.ps1"
    CacheMaxAge       = 3600 # secondi (1 ora)
    FallbackToCache   = $true
    RequiredFunctions = @('Get-SystemInfo', 'Write-StyledMessage', 'Show-Header', 'Initialize-ToolLogging')
}

# Variabili per il Core Script caricato
$Global:CoreScriptContent = $null
$Global:CoreScriptVersion = "Unknown"
$Global:CoreScriptLoaded = $false
$Global:MenuStructure = @() # Sarà popolato dal Core
$Global:ToolkitLanguage = 'en-US'
$Global:ToolkitLanguageData = $null
$Global:ToolkitDefaultLanguageData = $null

# =============================================================================
# LOGGING AND UTILITY FUNCTIONS
# =============================================================================

function Get-ToolkitLanguageDirectory {
    $candidate = Join-Path $PSScriptRoot 'languages'
    if (Test-Path $candidate) { return $candidate }

    $repoCandidate = Join-Path (Get-Location) 'languages'
    if (Test-Path $repoCandidate) { return $repoCandidate }

    return $candidate
}

function Get-AvailableToolkitLanguages {
    $languageDir = Get-ToolkitLanguageDirectory
    if (-not (Test-Path $languageDir)) { return @() }

    Get-ChildItem -Path $languageDir -Filter '*.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $data = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            [pscustomobject]@{
                Code       = $data.code
                Name       = $data.name
                NativeName = $data.nativeName
                Path       = $_.FullName
            }
        }
        catch {
            Write-Verbose "Invalid language file '$($_.FullName)': $($_.Exception.Message)"
        }
    } | Sort-Object Code
}

function Import-ToolkitLanguageFile {
    param([string]$LanguageCode)

    $languageDir = Get-ToolkitLanguageDirectory
    $languageFile = Join-Path $languageDir "$LanguageCode.json"
    if (-not (Test-Path $languageFile)) { return $null }

    return (Get-Content -LiteralPath $languageFile -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Set-ToolkitLanguage {
    param([string]$LanguageCode = 'en-US')

    $defaultData = Import-ToolkitLanguageFile -LanguageCode 'en-US'
    if ($defaultData) { $Global:ToolkitDefaultLanguageData = $defaultData }

    $languageData = Import-ToolkitLanguageFile -LanguageCode $LanguageCode
    if (-not $languageData) {
        $LanguageCode = 'en-US'
        $languageData = $defaultData
    }

    if ($languageData) {
        $Global:ToolkitLanguage = $LanguageCode
        $Global:ToolkitLanguageData = $languageData
    }
}

function Get-Loc {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [object[]]$Args = @()
    )

    $value = $null
    if ($Global:ToolkitLanguageData -and $Global:ToolkitLanguageData.strings.PSObject.Properties.Name -contains $Key) {
        $value = [string]$Global:ToolkitLanguageData.strings.$Key
    }
    elseif ($Global:ToolkitDefaultLanguageData -and $Global:ToolkitDefaultLanguageData.strings.PSObject.Properties.Name -contains $Key) {
        $value = [string]$Global:ToolkitDefaultLanguageData.strings.$Key
    }
    else {
        $value = $Key
    }

    if ($Args -and $Args.Count -gt 0) { return [string]::Format($value, $Args) }
    return $value
}

function Get-ToolkitMenuText {
    param([object]$Item)

    if ($Item -is [System.Collections.IDictionary]) {
        if ($Item.Contains('DescriptionKey') -and $Item['DescriptionKey']) {
            return (Get-Loc $Item['DescriptionKey'])
        }
        if ($Item.Contains('CategoryKey') -and $Item['CategoryKey']) {
            return (Get-Loc $Item['CategoryKey'])
        }
        if ($Item.Contains('Description')) { return $Item['Description'] }
        if ($Item.Contains('Name')) { return $Item['Name'] }
    }

    if ($Item.PSObject.Properties.Name -contains 'DescriptionKey' -and $Item.DescriptionKey) {
        return (Get-Loc $Item.DescriptionKey)
    }
    if ($Item.PSObject.Properties.Name -contains 'CategoryKey' -and $Item.CategoryKey) {
        return (Get-Loc $Item.CategoryKey)
    }
    if ($Item.PSObject.Properties.Name -contains 'Description') { return $Item.Description }
    if ($Item.PSObject.Properties.Name -contains 'Name') { return $Item.Name }
    return [string]$Item
}

Set-ToolkitLanguage -LanguageCode 'en-US'

function Convert-GuiSourceText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text) -or $Global:ToolkitLanguage -eq 'it-IT') { return $Text }

    $translated = $Text
    $replacements = [ordered]@{
        'INIZIALIZZAZIONE RISORSE - Caricamento Core Script.' = 'RESOURCE INITIALIZATION - Loading Core Script.'
        'Attendere prego, operazione in corso.' = 'Please wait, operation in progress.'
        'Errore lettura versione cache locale' = 'Error reading local cache version'
        'Fallito recupero versione remota' = 'Failed to retrieve remote version'
        'Potrebbe essere necessario un download forzato o fallback.' = 'A forced download or fallback may be required.'
        'Cache locale scaduta' = 'Local cache expired'
        'età' = 'age'
        'minuti' = 'minutes'
        'Download per aggiornare.' = 'Downloading to update.'
        'Core Script scaricato con successo.' = 'Core Script downloaded successfully.'
        'Salvato in cache' = 'Saved to cache'
        'Impossibile estrarre versione' = 'Unable to extract version'
        'Download fallito' = 'Download failed'
        'Utilizzo cache locale' = 'Using local cache'
        'Core Script content è vuoto dopo i tentativi di caricamento.' = 'Core Script content is empty after loading attempts.'
        'INIZIALIZZAZIONE COMPLETATA - GUI pronta all''uso.' = 'INITIALIZATION COMPLETED - GUI ready to use.'
        'ERRORE CRITICO durante caricamento Core' = 'CRITICAL ERROR while loading Core'
        'Suggerimento: Scarica manualmente WinToolkit.ps1 da:' = 'Tip: manually download WinToolkit.ps1 from:'
        'e salvalo in' = 'and save it to'
        'Preparazione log errori GUI per la segnalazione.' = 'Preparing GUI error logs for reporting.'
        'Nessun file log della GUI o del Core trovato per la segnalazione.' = 'No GUI or Core log file found for reporting.'
        'Pacchetto log supporto creato' = 'Support log package created'
        'Browser aperto per la segnalazione su GitHub.' = 'Browser opened for reporting on GitHub.'
        'Impossibile aprire il browser' = 'Unable to open the browser'
        'Operazione completata!' = 'Operation completed!'
        'Caricamento funzioni Core in memoria' = 'Loading Core functions into memory'
        'Struttura del menu caricata' = 'Menu structure loaded'
        'categorie' = 'categories'
        'non trovato dopo il caricamento' = 'not found after loading'
        'Funzione Get-SystemInfo disponibile.' = 'Get-SystemInfo function available.'
        'Funzione Get-SystemInfo NON trovata!' = 'Get-SystemInfo function NOT found!'
        'Errore durante dot-sourcing Core' = 'Error while dot-sourcing Core'
        'Impossibile caricare o scaricare l''icona della finestra' = 'Unable to load or download the window icon'
        'configurato con stile pill-shaped e icona Play.' = 'configured with pill-shaped style and Play icon.'
        'Conferma utente bypassata' = 'User confirmation bypassed'
        'Risposta predefinita' = 'Default response'
        'Input interattivo rilevato' = 'Interactive input detected'
        'Non supportato in modalità GUI.' = 'Not supported in GUI mode.'
        'Avvio esecuzione' = 'Starting execution'
        'Avvio ' = 'Starting '
        'Avvio:' = 'Startup:'
        'Attesa avvio' = 'Waiting for startup'
        'Caricamento moduli' = 'Loading modules'
        'Installazione' = 'Installation'
        'Installato' = 'Installed'
        'Disinstallazione' = 'Uninstallation'
        'Riparazione' = 'Repair'
        'Rimozione' = 'Removal'
        'Pulizia' = 'Cleanup'
        'Eliminazione' = 'Deleting'
        'Verifica' = 'Checking'
        'Validazione' = 'Validation'
        'Rilevamento' = 'Detecting'
        'Configurazione' = 'Configuration'
        'Abilitazione' = 'Enabling'
        'Riabilitazione' = 'Re-enabling'
        'Aggiornamento' = 'Updating'
        'Ripristino' = 'Restoring'
        'Reinstallazione' = 'Reinstallation'
        'Preparazione' = 'Preparing'
        'Estrazione' = 'Extracting'
        'Ricerca' = 'Searching'
        'Arresto' = 'Stopping'
        'Riavvio automatico' = 'Automatic restart'
        'Riavvio del sistema' = 'System restart'
        'Riavvio individuale soppresso' = 'Individual restart suppressed'
        'Verrà gestito un riavvio finale' = 'A final restart will be handled'
        'Riavvio non necessario' = 'Restart not required'
        'Riavvio necessario' = 'Restart required'
        'Riavvio sistema' = 'System restart'
        'Riavvio in' = 'Restart in'
        ' tra ' = ' in '
        'Premi un tasto per continuare' = 'Press any key to continue'
        'Premere un tasto per uscire' = 'Press any key to exit'
        'Premi un tasto qualsiasi per annullare' = 'Press any key to cancel'
        'Completato' = 'Completed'
        'completata' = 'completed'
        'completati' = 'completed'
        'terminato' = 'finished'
        'Errore durante' = 'Error during'
        'Errore critico' = 'Critical error'
        'Errore imprevisto' = 'Unexpected error'
        'Errore avvio job' = 'Error starting job'
        'Errore sconosciuto' = 'Unknown error'
        'fallito' = 'failed'
        'fallita' = 'failed'
        'falliti' = 'failed'
        'annullata' = 'cancelled'
        'annullato' = 'cancelled'
        'già presente' = 'already present'
        'non presente' = 'not present'
        'non trovato' = 'not found'
        'non trovata' = 'not found'
        'Nessuna riparazione necessaria' = 'No repair required'
        'non disponibile' = 'not available'
        'non accessibili' = 'not accessible'
        'Impossibile' = 'Unable to'
        'Avviso' = 'Warning'
        'Attenzione' = 'Warning'
        'Suggerimento' = 'Tip'
        'Nota' = 'Note'
        'Trovati' = 'Found'
        'Rimosso' = 'Removed'
        'Rimossi' = 'Removed'
        'rimosse' = 'removed'
        'eliminata' = 'deleted'
        'eliminati' = 'deleted'
        'eliminato' = 'deleted'
        'rilevata' = 'detected'
        'rilevato' = 'detected'
        'scaricato' = 'downloaded'
        'scaricata' = 'downloaded'
        'scaricare' = 'download'
        'scarica' = 'download'
        'creato' = 'created'
        'creata' = 'created'
        'attivato' = 'enabled'
        'attiva' = 'enabled'
        'abilitato' = 'enabled'
        'abilitati' = 'enabled'
        'configurato' = 'configured'
        'configurata' = 'configured'
        'ripristinate' = 'restored'
        'ripristinato' = 'restored'
        'reimpostato' = 'reset'
        'avviato' = 'started'
        'arrestato' = 'stopped'
        'in uso' = 'in use'
        'in corso' = 'in progress'
        'può richiedere alcuni minuti' = 'may take a few minutes'
        'può impiegare 1-2 minuti' = 'may take 1-2 minutes'
        'cartella' = 'folder'
        'cartelle' = 'folders'
        'chiavi registro' = 'registry keys'
        'chiave di registro' = 'registry key'
        'registro' = 'registry'
        'collegamenti' = 'shortcuts'
        'attività' = 'tasks'
        'attività pianificate' = 'scheduled tasks'
        'criteri di gruppo' = 'group policies'
        'criteri locali' = 'local policies'
        'Criteri' = 'Policies'
        'sorgenti' = 'sources'
        'pacchetto' = 'package'
        'pacchetti' = 'packages'
        'Versione' = 'Version'
        'configurazione GPU' = 'GPU configuration'
        'GPU rilevata' = 'Detected GPU'
        'GPU non rilevata' = 'GPU not detected'
        'driver non disponibile per l''installazione automatica' = 'driver not available for automatic installation'
        'modalità provvisoria' = 'Safe Mode'
        'modalità normale' = 'normal mode'
        'prossimo avvio' = 'next boot'
        'sistema' = 'system'
        'servizio' = 'service'
        'servizi' = 'services'
        'Stato' = 'Status'
        'codice' = 'code'
        'Codice uscita' = 'Exit code'
        'Eccezione' = 'Exception'
        'Tentativo' = 'Attempt'
        'Riepilogo' = 'Summary'
        'operazione' = 'operation'
        'modifiche' = 'changes'
        'valori predefiniti' = 'default values'
        'driver video' = 'video driver'
        'operazioni pendenti' = 'pending operations'
        'operazioni in sospeso' = 'pending operations'
        'Questo non è un errore critico' = 'This is not a critical error'
        'Proseguo comunque' = 'Continuing anyway'
        'Annullamento' = 'Cancelling'
        'metodo alternativo' = 'alternative method'
        'finestra esterna' = 'external window'
        'Attesa completamento' = 'Waiting for completion'
        'metodo forzato' = 'forced method'
        'file ignorati perché in uso o non accessibili' = 'files skipped because they are in use or not accessible'
        'Rilevate operazioni pendenti che richiedono riavvio' = 'Pending operations requiring a restart detected'
        'DISM potrebbe fallire' = 'DISM may fail'
        'Sistema in salute' = 'System is healthy'
        'Riparazione profonda non necessaria' = 'Deep repair not required'
        'riparazione profonda' = 'deep repair'
        'controllo schedulato al prossimo riavvio' = 'check scheduled at next restart'
        'interrotto' = 'stopped'
        'Preparazione prossimo script.' = 'Preparing next script.'
        'checkbox totali.' = 'total checkboxes.'
        'Script selezionato' = 'Selected script'
        'Errore lettura checkbox' = 'Error reading checkbox'
        'Errore invio log' = 'Error sending logs'
        'Errore durante inizializzazione Loaded' = 'Error during Loaded initialization'
        'Finestra GUI chiusa. Tentativo di fermare il job in corso.' = 'GUI window closed. Trying to stop the running job.'
        'Job in corso fermato e rimosso.' = 'Running job stopped and removed.'
        'Errore durante l''interruzione del job' = 'Error while stopping the job'
    }
    foreach ($entry in $replacements.GetEnumerator()) {
        $translated = [regex]::Replace($translated, [regex]::Escape([string]$entry.Key), [string]$entry.Value, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    return $translated
}

function Write-UnifiedLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)][string]$Type, # 'Info', 'Warning', 'Error', 'Success', 'Progress'
        [string]$GuiColor = "#FFFFFF" # Default if not determined by Type
    )

    $consoleColors = @{
        Info     = 'Cyan'
        Warning  = 'Yellow'
        Error    = 'Red'
        Success  = 'Green'
        Progress = 'Magenta'
    }

    $Message = Convert-GuiSourceText -Text $Message
    $currentDateTime = Get-Date -Format 'HH:mm:ss'
    $logPrefix = "[$currentDateTime] [$Type]"
    $formattedMessage = "$logPrefix $Message"

    # Write to console (unchanged)
    try {
        Write-Host "$formattedMessage" -ForegroundColor $consoleColors[$Type]
    }
    catch {
        # Silently fail console output
    }

    # Write to GUI OutputTextBox (if available)
    if ($outputTextBox -and $window -and $window.Dispatcher) {
        try {
            $window.Dispatcher.Invoke([Action] {
                    # Determine Foreground Color and FontWeight based on Type
                    $runForeground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($GuiColor))
                    $runFontWeight = [System.Windows.FontWeights]::Normal

                    switch -Wildcard ($Type.ToLower()) {
                        "error" { $runForeground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#FF5555")); $runFontWeight = [System.Windows.FontWeights]::Bold }
                        "warning" { $runForeground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")) }
                        "success" { $runForeground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#4CAF50")); $runFontWeight = [System.Windows.FontWeights]::Bold }
                        "progress" { $runForeground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#2196F3")) }
                        default { } # Defaults to GuiColor or falls through
                    }

                    $paragraph = $Global:LastLogParagraphRef

                    # Create a new paragraph if:
                    # 1. It's the very first message.
                    # 2. The message Type has changed since the last message.
                    # 3. The last paragraph reference is invalid or not a Paragraph (e.g., after Clear()).
                    if (-not $paragraph -or ($Type -ne $Global:LastLogEntryType) -or (-not ($paragraph -is [System.Windows.Documents.Paragraph]))) {
                        $paragraph = New-Object System.Windows.Documents.Paragraph
                        $paragraph.Margin = New-Object System.Windows.Thickness(0, 2, 0, 2)
                        $outputTextBox.Document.Blocks.Add($paragraph)

                        # Update global tracking variables
                        $Global:LastLogParagraphRef = $paragraph
                        $Global:LastLogEntryType = $Type
                    }

                    # Create a Run for the current message
                    $run = New-Object System.Windows.Documents.Run
                    $run.Text = "${formattedMessage}" + "`n" # Add newline at the end of each run for visual separation
                    $run.Foreground = $runForeground
                    $run.FontWeight = $runFontWeight

                    $paragraph.Inlines.Add($run)
                    $outputTextBox.ScrollToEnd()
                })
        }
        catch {
            # Silently fail GUI logging if there are issues
        }
    }
}

# =============================================================================
# CORE SCRIPT LOADER MODULE
# =============================================================================

function Initialize-CoreScript {
    <#
    .SYNOPSIS
        Carica il Core Script (WinToolkit.ps1) da fonte remota o cache locale.

    .DESCRIPTION
        Gestisce il download del Core Script da GitHub, caching locale, estrazione
        versione, e dot-sourcing delle funzioni nel scope corrente.
        Implementa confronto versione remoto vs locale per ottimizzare i download.

    .OUTPUTS
        Boolean - True se Core caricato con successo, False altrimenti
    #>

    [CmdletBinding()]
    param()

    try {
        # Mostra loading screen
        Write-UnifiedLog -Type 'Info' -Message "💎 INIZIALIZZAZIONE RISORSE - Caricamento Core Script." -GuiColor "#00CED1"
        Write-UnifiedLog -Type 'Info' -Message "💎 Attendere prego, operazione in corso." -GuiColor "#FFA500"

        # Crea directory cache se non esiste
        $cacheDir = Split-Path $Global:CoreConfig.LocalCachePath -Parent
        if (-not (Test-Path $cacheDir)) {
            New-Item -Path $cacheDir -ItemType Directory -Force | Out-Null
        }

        $coreContent = $null
        $usedCache = $false
        $localCoreNumericVersion = [version]"0.0.0" # Versione numerica per il confronto
        $localCoreFullVersion = "Unknown" # Stringa di versione completa per la visualizzazione

        # 1. Recupera la versione del Core Script locale (se esiste la cache)
        if (Test-Path $Global:CoreConfig.LocalCachePath) {
            try {
                # Leggi tutto il contenuto per maggiore robustezza
                $localCacheRawContent = Get-Content $Global:CoreConfig.LocalCachePath -Raw -Encoding UTF8
                if ($localCacheRawContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
                    $localCoreFullVersion = $matches[1]
                    # Estrai la parte numerica per il confronto (es. "2.5.1" da "2.5.1 (Build 6)")
                    if ($localCoreFullVersion -match '(\d+(?:\.\d+){0,3})') {
                        $localCoreNumericVersion = [version]$matches[1]
                        Write-UnifiedLog -Type 'Info' -Message "📌 Versione Core locale trovata: $localCoreFullVersion (Numerica: $localCoreNumericVersion)." -GuiColor "#00CED1"
                    }
                    else {
                        Write-UnifiedLog -Type 'Warning' -Message "⚠️ Impossibile estrarre la parte numerica dalla versione locale '$localCoreFullVersion'. Assumo 0.0.0 per confronto." -GuiColor "#FFA500"
                    }
                }
                else {
                    Write-UnifiedLog -Type 'Warning' -Message "⚠️ Impossibile estrarre la versione dalla cache locale. Assumo 0.0.0 per confronto." -GuiColor "#FFA500"
                }
            }
            catch {
                Write-UnifiedLog -Type 'Warning' -Message "⚠️ Errore lettura versione cache locale: $($_.Exception.Message)." -GuiColor "#FFA500"
            }
        }

        # 2. Recupera la versione del Core Script remoto
        $remoteCoreNumericVersion = [version]"0.0.0"
        $remoteCoreFullVersion = "Unknown"
        Write-UnifiedLog -Type 'Info' -Message "📡 Recupero versione Core Script remota." -GuiColor "#00CED1"
        try {
            # Usa Invoke-RestMethod per ottenere il contenuto completo per un parsing robusto
            $remoteRawContent = Invoke-RestMethod -Uri $Global:CoreConfig.RemoteUrl -UseBasicParsing -ErrorAction Stop
            if ($remoteRawContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
                $remoteCoreFullVersion = $matches[1]
                if ($remoteCoreFullVersion -match '(\d+(?:\.\d+){0,3})') {
                    $remoteCoreNumericVersion = [version]$matches[1]
                    Write-UnifiedLog -Type 'Info' -Message "📌 Versione Core remota rilevata: $remoteCoreFullVersion (Numerica: $remoteCoreNumericVersion)." -GuiColor "#00CED1"
                }
                else {
                    Write-UnifiedLog -Type 'Warning' -Message "⚠️ Impossibile estrarre la parte numerica dalla versione remota '$remoteCoreFullVersion'. Assumo 0.0.0 per confronto." -GuiColor "#FFA500"
                }
            }
            else {
                Write-UnifiedLog -Type 'Warning' -Message "⚠️ Impossibile estrarre versione remota dal Core Script. Assumo 0.0.0 per confronto." -GuiColor "#FFA500"
            }
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Fallito recupero versione remota: $($_.Exception.Message). Potrebbe essere necessario un download forzato o fallback." -GuiColor "#FFA500"
        }

        # 3. Determina se è necessario scaricare il Core Script
        $shouldDownload = $false
        $cacheExists = Test-Path $Global:CoreConfig.LocalCachePath
        $cacheExpired = $false

        if ($cacheExists) {
            $cacheAge = (Get-Date) - (Get-Item $Global:CoreConfig.LocalCachePath).LastWriteTime
            $cacheExpired = ($cacheAge.TotalSeconds -ge $Global:CoreConfig.CacheMaxAge)
        }

        if (-not $cacheExists) {
            Write-UnifiedLog -Type 'Info' -Message "📥 Nessuna cache locale trovata. Download forzato." -GuiColor "#00CED1"
            $shouldDownload = $true
        }
        elseif ($remoteCoreNumericVersion -gt $localCoreNumericVersion) {
            Write-UnifiedLog -Type 'Info' -Message "⬆️ Nuova versione Core ($remoteCoreFullVersion) disponibile (attuale: $localCoreFullVersion). Download in corso." -GuiColor "#00CED1"
            $shouldDownload = $true
        }
        elseif ($cacheExpired) {
            Write-UnifiedLog -Type 'Info' -Message "⏰ Cache locale scaduta (età: $([Math]::Round($cacheAge.TotalMinutes, 1)) minuti). Download per aggiornare." -GuiColor "#FFA500"
            $shouldDownload = $true
        }
        else {
            Write-UnifiedLog -Type 'Success' -Message "✅ Cache locale valida e aggiornata (v$localCoreFullVersion). Utilizzo cache." -GuiColor "#00FF00"
            $coreContent = Get-Content $Global:CoreConfig.LocalCachePath -Raw -Encoding UTF8
            $usedCache = $true
            $Global:CoreScriptVersion = $localCoreFullVersion
        }

        if ($shouldDownload) {
            Write-UnifiedLog -Type 'Info' -Message "📡 Download Core Script da GitHub." -GuiColor "#00CED1"
            Write-UnifiedLog -Type 'Info' -Message "🌐 URL: $($Global:CoreConfig.RemoteUrl)." -GuiColor "#808080"

            try {
                $downloadParams = @{
                    Uri             = $Global:CoreConfig.RemoteUrl
                    OutFile         = $Global:CoreConfig.LocalCachePath
                    UseBasicParsing = $true
                    ErrorAction     = 'Stop'
                }

                Invoke-WebRequest @downloadParams
                $coreContent = Get-Content $Global:CoreConfig.LocalCachePath -Raw -Encoding UTF8
                Write-UnifiedLog -Type 'Success' -Message "✅ Core Script scaricato con successo." -GuiColor "#00FF00"
                Write-UnifiedLog -Type 'Info' -Message "💾 Salvato in cache: $($Global:CoreConfig.LocalCachePath)." -GuiColor "#00CED1"

                # Estrai versione dal Core appena scaricato (stringa completa per display)
                if ($coreContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
                    $Global:CoreScriptVersion = $matches[1]
                    Write-UnifiedLog -Type 'Success' -Message "📌 Versione Core scaricata: $Global:CoreScriptVersion." -GuiColor "#00FF00"
                }
                else {
                    Write-UnifiedLog -Type 'Warning' -Message "⚠️ Impossibile estrarre versione dal Core appena scaricato." -GuiColor "#FFA500"
                    $Global:CoreScriptVersion = "Unknown"
                }

            }
            catch {
                Write-UnifiedLog -Type 'Warning' -Message "⚠️ Download fallito: $($_.Exception.Message)." -GuiColor "#FFA500"

                if ($cacheExists -and $Global:CoreConfig.FallbackToCache) {
                    Write-UnifiedLog -Type 'Info' -Message "📂 Utilizzo cache locale (scaduta o meno recente, ma disponibile) come fallback." -GuiColor "#FFA500"
                    $coreContent = Get-Content $Global:CoreConfig.LocalCachePath -Raw -Encoding UTF8
                    $usedCache = $true
                    # Ri-estrai la versione dalla cache come fallback
                    if ($coreContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
                        $Global:CoreScriptVersion = $matches[1]
                        Write-UnifiedLog -Type 'Success' -Message "📌 Versione Core da cache fallback: $Global:CoreScriptVersion." -GuiColor "#00FF00"
                    }
                }
                else {
                    throw "Impossibile scaricare Core Script e nessuna cache disponibile/configurata per il fallback."
                }
            }
        }

        # Se è stata usata la cache senza download, assicurati che $Global:CoreScriptVersion sia impostato correttamente
        if ($usedCache -and ([string]::IsNullOrEmpty($Global:CoreScriptVersion) -or $Global:CoreScriptVersion -eq "Unknown")) {
            if ($coreContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
                $Global:CoreScriptVersion = $matches[1]
            }
        }

        if (-not $coreContent) {
            throw "Core Script content is empty after loading attempts."
        }

        # NOTE: Loading moved to main scope to fix variable visibility
        $Global:CoreScriptContent = $coreContent
        $Global:CoreScriptLoaded = $true

        Write-UnifiedLog -Type 'Success' -Message "🎉 INIZIALIZZAZIONE COMPLETATA - GUI pronta all'uso." -GuiColor "#00FF00"
        Write-Host ""

        return $true
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "❌ ERRORE CRITICO durante caricamento Core: $($_.Exception.Message)." -GuiColor "#FF0000"
        Write-UnifiedLog -Type 'Info' -Message "💡 Suggerimento: Scarica manualmente WinToolkit.ps1 da:" -GuiColor "#00CED1"
        Write-UnifiedLog -Type 'Info' -Message "   $($Global:CoreConfig.RemoteUrl)" -GuiColor "#808080"
        Write-UnifiedLog -Type 'Info' -Message "   e salvalo in: $($Global:CoreConfig.LocalCachePath)." -GuiColor "#808080"

        $Global:CoreScriptLoaded = $false
        return $false
    }
}

# =============================================================================
# EMOJI ICONS HELPER FUNCTIONS
# =============================================================================

function Get-EmojiIconPath {
    param ([string]$EmojiCharacter)

    if ([string]::IsNullOrEmpty($EmojiCharacter)) {
        return $null
    }

    try {
        $bytes = [System.Text.Encoding]::UTF32.GetBytes($EmojiCharacter)
        if ($bytes.Length -lt 4) {
            return $null
        }
        $codepoint = [BitConverter]::ToUInt32($bytes, 0).ToString("X")
        $fileName = "U+$codepoint.png"
        $fullPath = Join-Path $localIconBasePath $fileName
        return $fullPath
    }
    catch {
        return $null
    }
}

# Funzione helper per caricare icona con fallback a emoji
function Get-IconWithFallback {
    param(
        [string]$EmojiCharacter,
        [string]$FallbackText = "?"
    )

    $iconPath = Get-EmojiIconPath -EmojiCharacter $EmojiCharacter

    # Se il file esiste localmente, restituisci il percorso
    if ($iconPath -and (Test-Path $iconPath)) {
        return $iconPath
    }

    # Altrimenti restituisci null per indicare di usare l'emoji come fallback
    return $null
}

function Split-EmojiAndText {
    param ([string]$InputString)

    $parts = $InputString -split ' ', 2

    if ($parts.Length -ge 2) {
        return @{
            Emoji = $parts[0]
            Text  = $parts[1]
        }
    }
    else {
        return @{
            Emoji = ""
            Text  = $InputString
        }
    }
}

function Test-EmojiIcons {
    param(
        [Parameter(Mandatory = $true)][hashtable]$EmojiMap,
        [Parameter(Mandatory = $true)][string]$LocalPath,
        [Parameter(Mandatory = $true)][string]$RemotePath
    )
    Write-UnifiedLog -Type 'Info' -Message "🚀 Ensuring all required icons are available locally." -GuiColor "#00CED1"
    try {
        foreach ($key in $EmojiMap.Keys) {
            $emojiChar = $EmojiMap[$key]
            $localIconFile = Get-EmojiIconPath -EmojiCharacter $emojiChar

            if ([string]::IsNullOrEmpty($localIconFile)) {
                Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not get local path for emoji '$emojiChar'. Skipping." -GuiColor "#FFA500"
                continue
            }

            if (-not (Test-Path $localIconFile)) {
                $fileName = Split-Path $localIconFile -Leaf
                $remoteIconUri = "$RemotePath/$fileName"

                Write-UnifiedLog -Type 'Info' -Message "📥 Downloading icon for '$emojiChar' from $remoteIconUri." -GuiColor "#00CED1"
                try {
                    Invoke-WebRequest -Uri $remoteIconUri -OutFile $localIconFile -UseBasicParsing -ErrorAction Stop | Out-Null
                    Write-UnifiedLog -Type 'Success' -Message "✅ Downloaded: $fileName." -GuiColor "#00FF00"
                }
                catch {
                    Write-UnifiedLog -Type 'Error' -Message "❌ Failed to download icon '$fileName': $($_.Exception.Message)." -GuiColor "#FF0000"
                }
            }
        }
        Write-UnifiedLog -Type 'Success' -Message "🎉 Icon availability check completed." -GuiColor "#00FF00"
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "❌ Error during icon synchronization: $($_.Exception.Message)." -GuiColor "#FF0000"
    }
}

function Get-AllCheckBoxes {
    <#
    .SYNOPSIS
        Funzione helper per trovare ricorsivamente tutti i CheckBox in un contenitore.
    #>
    param([System.Windows.Controls.Panel]$Container)

    $checkBoxes = @()

    foreach ($child in $Container.Children) {
        if ($child -is [System.Windows.Controls.CheckBox]) {
            $checkBoxes += $child
        }
        elseif ($child -is [System.Windows.Controls.Panel]) {
            # Ricerca ricorsiva in contenitori StackPanel
            $checkBoxes += Get-AllCheckBoxes -Container $child
        }
    }

    return $checkBoxes
}

function Send-ErrorLogs {
    <#
    .SYNOPSIS
        Genera e invia i log degli errori SPECIFICI DELLA GUI e eventuali log recenti del Core
        per facilitare la segnalazione di bug della GUI.
    #>
    try {
        Write-UnifiedLog -Type 'Info' -Message "📦 Preparazione log errori GUI per la segnalazione." -GuiColor "#00CED1"

        # Includi il log principale della GUI e i transcript più recenti del Core
        $recentLogFiles = @($mainLog) # Il log della GUI stessa

        # Cerca i log più recenti dal Core nella directory AppData
        $coreLogDir = "$env:LOCALAPPDATA\WinToolkit\logs"
        if (Test-Path $coreLogDir) {
            # Seleziona gli ultimi 3 log del Core (escludendo quello della GUI se presente due volte)
            $coreTranscripts = Get-ChildItem -Path $coreLogDir -Filter "*.log" -ErrorAction SilentlyContinue |
            Sort-Object -Property LastWriteTime -Descending | Select-Object -First 3
            $recentLogFiles += $coreTranscripts.FullName | Where-Object { $_ -ne $mainLog }
        }
        $recentLogFiles = $recentLogFiles | Select-Object -Unique # Rimuovi duplicati

        if (-not $recentLogFiles) {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Nessun file log della GUI o del Core trovato per la segnalazione." -GuiColor "#FFA500"
            return
        }

        # Crea il contenuto del file di metadati JSON
        $metadata = @{
            Timestamp      = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            GuiVersion     = $Global:GuiVersion
            CoreVersion    = $Global:CoreScriptVersion
            CorrelationId  = if ($Global:CurrentCorrelationId) { $Global:CurrentCorrelationId } else { "N/A" }
            OS             = (Get-CimInstance Win32_OperatingSystem).Caption
            OSVersion      = (Get-CimInstance Win32_OperatingSystem).Version
            MachineName    = $env:COMPUTERNAME
        }
        $metadataPath = Join-Path $env:TEMP "metadata.json"
        $metadata | ConvertTo-Json | Out-File -FilePath $metadataPath -Encoding UTF8 -Force

        # Crea README per il pacchetto log
        $readmeContent = @"
WinToolkit Support Log Package
============================
Timestamp: $($metadata.Timestamp)
CorrelationId: $($metadata.CorrelationId)
GUI Version: $($metadata.GuiVersion)
Core Version: $($metadata.CoreVersion)
OS: $($metadata.OS) ($($metadata.OSVersion))
Machine: $($metadata.MachineName)

Contents:
- metadata.json: Session metadata
- README.txt: This file
- WinToolkit_GUI_ErrorReport_*.txt: Combined log report
- Core logs from %LOCALAPPDATA%\WinToolkit\logs (if included)

Usage:
Attach this zip file when reporting issues. The CorrelationId links logs across tools and GUI sessions.
"@
        $readmePath = Join-Path $env:TEMP "README.txt"
        $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8 -Force

        # Crea il contenuto combinato dei log
        $logContent = "=" * 60 + "`n"
        $logContent += "WinToolkit GUI Error Report`n"
        $logContent += "Data: $($metadata.Timestamp)`n"
        $logContent += "CorrelationId: $($metadata.CorrelationId)`n"
        $logContent += "Versione GUI: $($metadata.GuiVersion)`n"
        $logContent += "Versione Core: $($metadata.CoreVersion)`n"
        $logContent += "=" * 60 + "`n`n"

        foreach ($logFile in $recentLogFiles) {
            $logContent += "--- $($logFile | Split-Path -Leaf) ---`n"
            $logContent += (Get-Content -Path $logFile -ErrorAction SilentlyContinue -Raw)
            $logContent += "`n`n"
        }

        # Salva il report temporaneo
        $tempReportPath = Join-Path $env:TEMP "WinToolkit_GUI_ErrorReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $logContent | Out-File -FilePath $tempReportPath -Encoding UTF8 -Force

        # Comprimi il report e i metadati in ZIP sul Desktop
        $zipPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "WinToolkit_SupportLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
        if (Get-Command 'Compress-Archive' -ErrorAction SilentlyContinue) {
            Compress-Archive -Path $tempReportPath, $metadataPath, $readmePath -DestinationPath $zipPath -Force
            Write-UnifiedLog -Type 'Success' -Message "✅ Pacchetto log supporto creato: $zipPath." -GuiColor "#00FF00"
        }
        else {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Compress-Archive non disponibile. Report GUI salvato in: $tempReportPath." -GuiColor "#FFA500"
            $zipPath = $tempReportPath # Se non si può zippare, usa il percorso del .txt per il messaggio finale
        }

        # Elimina il report temporaneo se è stato zippato con successo
        if (Test-Path $tempReportPath -PathType Leaf) {
            Remove-Item $tempReportPath -ErrorAction SilentlyContinue
        }

        # Apri il browser predefinito alla pagina GitHub Issues
        try {
            Start-Process -FilePath "https://github.com/Magnetarman/WinToolkit/issues/new?template=bug_report.yml"
            Write-UnifiedLog -Type 'Info' -Message "🌐 Browser aperto per la segnalazione su GitHub." -GuiColor "#00CED1"
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Impossibile aprire il browser: $($_.Exception.Message)." -GuiColor "#FFA500"
        }

        # Scrivi messaggio finale nel box Output
        $window.Dispatcher.Invoke([Action] {
                $paragraph = New-Object System.Windows.Documents.Paragraph
                $run = New-Object System.Windows.Documents.Run
                $run.Text = "Invia l'archivio sul tuo desktop ($zipPath) su GitHub indicando le problematiche riscontrate in modo da migliorare il tool"
                $run.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#00FF00"))
                $run.FontWeight = [System.Windows.FontWeights]::Bold
                $paragraph.Inlines.Add($run)
                $outputTextBox.Document.Blocks.Add($paragraph)
                $outputTextBox.ScrollToEnd()
            })

        Write-UnifiedLog -Type 'Success' -Message "🎉 Operazione completata!" -GuiColor "#00FF00"
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "❌ Errore durante la preparazione dei log GUI: $($_.Exception.Message)." -GuiColor "#FF0000"
    }
}

# =============================================================================
# LOAD ALL TOOL SCRIPTS INTO GLOBAL SCOPE (before any job execution)
# =============================================================================
# NOTE: This section has been removed. All tool functions are now defined
# in the Core Script (WinToolkit.ps1) and are loaded when the Core Script
# is dot-sourced. The job now only needs to load the Core Script to access
# all tool functions.
# $Global:ToolScriptsPath = Join-Path $PSScriptRoot "tools"

# function Load-AllToolScripts { ... } # REMOVED - All functions are in Core Script

# Initial load count is 0 since functions are loaded via Core Script
$Global:ToolScriptsLoadedCount = 0

# =============================================================================
# INITIALIZATION
# =============================================================================

# Create log directory
try {
    [System.IO.Directory]::CreateDirectory($LogDirectory) | Out-Null
    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}
    Start-Transcript -Path $mainLog -Append -Force | Out-Null
    Write-Host "[INFO] Logging initialized to $mainLog." -ForegroundColor Cyan
}
catch {
    Write-Host "[ERROR] Failed to initialize logging. $($_.Exception.Message)." -ForegroundColor Red
}

# Create icon cache directory
try {
    if (-not (Test-Path $localIconBasePath)) {
        [System.IO.Directory]::CreateDirectory($localIconBasePath) | Out-Null
    }
}
catch {
    Write-Host "[ERROR] Failed to create icon directory: $($_.Exception.Message)." -ForegroundColor Red
}

# Download and cache all required icons
Test-EmojiIcons -EmojiMap $emojiMappings -LocalPath $localIconBasePath -RemotePath $remoteIconBasePath

# Check administrator privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Administrator privileges required." -ForegroundColor Red
    exit
}

Write-Host "[INFO] Administrator privileges confirmed." -ForegroundColor Green

# Load WPF assemblies
$assemblies = @("PresentationFramework", "PresentationCore", "WindowsBase", "System.Windows.Forms")
foreach ($assembly in $assemblies) {
    try {
        Add-Type -AssemblyName $assembly -ErrorAction Stop
        Write-Host "[SUCCESS] Loaded: $assembly." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to load: $assembly - $($_.Exception.Message)." -ForegroundColor Red
    }
}

# ==========================================
# INITIALIZE CORE SCRIPT (CRITICAL STEP)
# ==========================================

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  WinToolkit GUI v3.0 - GUI Edition" -ForegroundColor White
Write-Host "  Loading Core Script." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

$coreLoaded = Initialize-CoreScript

if (-not $coreLoaded) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  FATAL ERROR: Core Script loading failed." -ForegroundColor Red
    Write-Host "  The GUI cannot continue without the Core Script." -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

# ==========================================
# EXECUTE CORE SCRIPT (SCOPE FIX)
# ==========================================
try {
    Write-UnifiedLog -Type 'Info' -Message "🔌 Caricamento funzioni Core in memoria (Global Scope)." -GuiColor "#00CED1"

    # Dot-sourcing nel scope corrente (Script/Global)
    # Usa il path locale assicurato da Initialize-CoreScript
    . $Global:CoreConfig.LocalCachePath

    # Recupera $menuStructure dopo il caricamento
    if ($menuStructure) {
        $Global:MenuStructure = $menuStructure
        Write-UnifiedLog -Type 'Success' -Message "✅ Struttura del menu caricata (categorie: $($Global:MenuStructure.Count))." -GuiColor "#00FF00"
    }
    else {
        Write-UnifiedLog -Type 'Warning' -Message "⚠️ \$menuStructure non trovato dopo il caricamento." -GuiColor "#FFA500"
    }

    # Verifica funzioni critiche
    if (Get-Command 'Get-SystemInfo' -ErrorAction SilentlyContinue) {
        Write-UnifiedLog -Type 'Success' -Message "✅ Funzione Get-SystemInfo disponibile." -GuiColor "#00FF00"
    }
    else {
        Write-UnifiedLog -Type 'Error' -Message "❌ Funzione Get-SystemInfo NON trovata!" -GuiColor "#FF0000"
    }

}
catch {
    Write-UnifiedLog -Type 'Error' -Message "❌ Errore durante dot-sourcing Core: $($_.Exception.Message)." -GuiColor "#FF0000"
}

# =============================================================================
# GUI LOCALIZATION OVERRIDES
# Re-apply after core dot-sourcing so cached/remote cores cannot overwrite them.
# =============================================================================

function Get-GuiMenuLocalizationKey {
    param([object]$Item)

    $name = $null
    if ($Item -is [System.Collections.IDictionary]) {
        if ($Item.Contains('CategoryKey') -and $Item['CategoryKey']) { return $Item['CategoryKey'] }
        if ($Item.Contains('DescriptionKey') -and $Item['DescriptionKey']) { return $Item['DescriptionKey'] }
        if ($Item.Contains('Name')) { $name = [string]$Item['Name'] }
    }
    else {
        if ($Item.PSObject.Properties.Name -contains 'CategoryKey' -and $Item.CategoryKey) { return $Item.CategoryKey }
        if ($Item.PSObject.Properties.Name -contains 'DescriptionKey' -and $Item.DescriptionKey) { return $Item.DescriptionKey }
        if ($Item.PSObject.Properties.Name -contains 'Name') { $name = [string]$Item.Name }
    }

    switch -Regex ($name) {
        '^Windows$' { return 'category.windows' }
        '^Office$' { return 'category.office' }
        '^Driver & Gaming$' { return 'category.driverGaming' }
        '^(Supporto|Support)$' { return 'category.support' }
        default {
            if (-not [string]::IsNullOrWhiteSpace($name)) { return "script.$name" }
        }
    }

    return $null
}

function Get-ToolkitMenuText {
    param([object]$Item)

    $key = Get-GuiMenuLocalizationKey -Item $Item
    if ($key) {
        $localized = Get-Loc $key
        if ($localized -ne $key) { return $localized }
    }

    if ($Item -is [System.Collections.IDictionary]) {
        if ($Item.Contains('Description')) { return $Item['Description'] }
        if ($Item.Contains('Name')) { return $Item['Name'] }
    }
    else {
        if ($Item.PSObject.Properties.Name -contains 'Description') { return $Item.Description }
        if ($Item.PSObject.Properties.Name -contains 'Name') { return $Item.Name }
    }

    return [string]$Item
}

function Convert-GuiBitlockerStatusToKey {
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

function Get-GuiBitlockerStatusKey {
    $command = Get-Command 'Get-BitlockerStatus' -ErrorAction SilentlyContinue
    if ($command -and $command.Parameters.ContainsKey('Key')) {
        $statusKey = Get-BitlockerStatus -Key
        if ($statusKey -match '^bitlocker\.status\.') { return $statusKey }
    }

    $statusText = if ($command) { Get-BitlockerStatus } else { $null }
    return (Convert-GuiBitlockerStatusToKey -StatusText $statusText)
}

# =============================================================================
# WPF GUI DEFINITION
# =============================================================================

$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="$($ScriptTitle) - v$($Global:CoreScriptVersion)"
    Height="$($WindowHeight)"
    Width="$($WindowWidth)"
    WindowStartupLocation="CenterScreen">

    <Window.Resources>
        <!-- Nuovo Palette Colori da Gui.jpg -->
        <SolidColorBrush x:Key="BackgroundDark" Color="#FF1E1E1E"/>
        <SolidColorBrush x:Key="BackgroundColor" Color="#FF2D2D2D"/>
        <SolidColorBrush x:Key="HeaderBackgroundColor" Color="#FF1A1A1A"/>
        <SolidColorBrush x:Key="PanelBackgroundColor" Color="#FF3D3D3D"/>
        <SolidColorBrush x:Key="TextColor" Color="#FFFFFFFF"/>
        <SolidColorBrush x:Key="LabelBlue" Color="#FF4FC3F7"/>
        <SolidColorBrush x:Key="DescriptionGray" Color="#FFBDBDBD"/>
        <SolidColorBrush x:Key="SeparatorGreen" Color="#FF2E7D32"/>
        <SolidColorBrush x:Key="ExecuteButtonColor" Color="#FF2196F3"/>
        <SolidColorBrush x:Key="ErrorButtonColor" Color="#FFD32F2F"/>
        <SolidColorBrush x:Key="SuccessColor" Color="#FF00FF00"/>
        <SolidColorBrush x:Key="BorderColor" Color="#FF0078D4"/>
        <SolidColorBrush x:Key="OutputBackgroundColor" Color="#FF1A1A1A"/>
        <SolidColorBrush x:Key="LEDGreenColor" Color="#FF4CAF50"/>
        <FontFamily x:Key="PrimaryFont">$FontFamily</FontFamily>

        <!-- Button Styles per CornerRadius (workaround per PowerShell XAML parsing) -->
        <Style x:Key="PillButtonStyle" TargetType="Button">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="25"
                                Padding="{TemplateBinding Padding}"
                                BorderThickness="{TemplateBinding BorderThickness}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                              VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SmallButtonStyle" TargetType="Button">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="8"
                                Padding="{TemplateBinding Padding}"
                                BorderThickness="{TemplateBinding BorderThickness}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                              VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Style per una ProgressBar arrotondata (Pill) -->
        <Style x:Key="PillProgressBarStyle" TargetType="ProgressBar">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid>
                            <Border x:Name="PART_Track"
                                    Background="{TemplateBinding Background}"
                                    BorderBrush="{TemplateBinding BorderBrush}"
                                    BorderThickness="{TemplateBinding BorderThickness}"
                                    CornerRadius="10" />
                            <Border x:Name="PART_Indicator"
                                    Background="{TemplateBinding Foreground}"
                                    CornerRadius="10"
                                    HorizontalAlignment="Left" />
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Background="{StaticResource BackgroundDark}">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Task 1: Header con 3 colonne e CornerRadius -->
        <Border Grid.Row="0" Background="{StaticResource HeaderBackgroundColor}"
                Padding="16" Margin="16,16,16,8" CornerRadius="12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <!-- Colonna 0: Icona Tool -->
                <Image Grid.Column="0" x:Name="ToolIconImage"
                       Source="/images/WinToolkit-icon.png"
                       Width="48" Height="48"
                       VerticalAlignment="Center" Margin="0,0,16,0"/>

                <!-- Colonna 1: Titolo e Sottotitolo centrati -->
                <StackPanel Grid.Column="1" VerticalAlignment="Center" HorizontalAlignment="Center">
                    <TextBlock Text="$($ScriptTitle)"
                               FontSize="$($FontSize.Header)" FontWeight="Bold"
                               Foreground="{StaticResource TextColor}"
                               FontFamily="{StaticResource PrimaryFont}"
                               TextAlignment="Center"/>
                    <TextBlock Text="GUI Edition v$($Global:GuiVersion) | Core v$($Global:CoreScriptVersion)"
                               FontSize="$($FontSize.Medium)" FontWeight="Normal"
                               Foreground="{StaticResource LabelBlue}"
                               FontFamily="{StaticResource PrimaryFont}"
                               TextAlignment="Center" Margin="0,4,0,0"/>
                </StackPanel>

                <!-- Colonna 2: Lingua + Pulsante Invia Log Errori -->
                <StackPanel Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Right" Margin="16,0,0,0">
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,0,0,8">
                        <TextBlock x:Name="LanguageLabelText" Text="Language"
                                   Foreground="{StaticResource LabelBlue}"
                                   FontFamily="{StaticResource PrimaryFont}"
                                   FontWeight="SemiBold"
                                   FontSize="$($FontSize.Small)"
                                   VerticalAlignment="Center"
                                   Margin="0,0,8,0"/>
                        <ComboBox x:Name="LanguageComboBox"
                                  Width="150"
                                  Height="30"
                                  SelectedValuePath="Tag"
                                  FontFamily="{StaticResource PrimaryFont}"
                                  FontSize="$($FontSize.Small)"/>
                    </StackPanel>
                    <Button x:Name="SendErrorLogsButton"
                            VerticalAlignment="Center" HorizontalAlignment="Right"
                            Background="{StaticResource ErrorButtonColor}"
                            Foreground="{StaticResource TextColor}"
                            Padding="20,12" BorderThickness="0" Cursor="Hand"
                            Style="{StaticResource SmallButtonStyle}">
                        <StackPanel Orientation="Horizontal">
                            <Image x:Name="SendErrorLogsImage" Width="28" Height="28" Margin="0,0,8,0"/>
                            <TextBlock x:Name="SendErrorLogsText" Text="Send error logs" VerticalAlignment="Center"
                                       FontFamily="{StaticResource PrimaryFont}" FontWeight="SemiBold" FontSize="$($FontSize.Small)"/>
                        </StackPanel>
                    </Button>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Task 2: Pannello Informazioni Sistema a 3 blocchi (Layout Refactored con Separatori) -->
        <Border Grid.Row="1" Background="{StaticResource OutputBackgroundColor}"
                CornerRadius="8" Padding="16" Margin="16,0,16,8">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto" MinWidth="200"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- Blocco 1: Windows Info (Label azzurre a sinistra, valori bianchi a destra) -->
                <StackPanel Grid.Column="0" Margin="0,0,20,0">
                    <TextBlock x:Name="SysInfoTitleText" Text="▬▬ System information ▬▬"
                               Foreground="{StaticResource LabelBlue}"
                               FontSize="$($FontSize.Medium)" FontWeight="Bold"
                               FontFamily="{StaticResource PrimaryFont}"
                               Margin="0,0,0,12" TextAlignment="Left"/>

                    <!-- Windows Edition Row - Increased font size -->
                    <Grid Margin="0,6,0,6">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Image x:Name="SysInfoEditionImage" Width="16" Height="16" Margin="0,0,5,0"/>
                            <TextBlock x:Name="SysInfoEditionLabel" Text="Windows edition: " Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoEdition" Text="Loading."
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center" TextAlignment="Right"/>
                    </Grid>

                    <!-- Version Row - Increased font size -->
                    <Grid Margin="0,6,0,6">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Image x:Name="SysInfoVersionImage" Width="16" Height="16" Margin="0,0,5,0"/>
                            <TextBlock x:Name="SysInfoVersionLabel" Text="Version: " Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoVersion" Text="Loading."
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center" TextAlignment="Right"/>
                    </Grid>

                    <!-- Architecture Row - Increased font size -->
                    <Grid Margin="0,6,0,6">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Image x:Name="SysInfoArchitectureImage" Width="16" Height="16" Margin="0,0,5,0"/>
                            <TextBlock x:Name="SysInfoArchitectureLabel" Text="Architecture: " Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoArchitecture" Text="Loading."
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center" TextAlignment="Right"/>
                    </Grid>
                </StackPanel>

                <!-- Separatore Verde Verticale 1: Tra Informazioni Sistema e Funzionalità Script -->
                <Border Grid.Column="1" Width="3" Background="{StaticResource SeparatorGreen}"
                        VerticalAlignment="Stretch" Margin="15,5"/>

                <!-- Blocco 2: Script Status (Widget centrale) - Layout semplificato senza LED -->
                <StackPanel Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Center"
                            Margin="20,0" MinWidth="200">

                    <!-- Riga 1: Funzionalità Script con status colorato -->
                    <Grid HorizontalAlignment="Center" Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                            <Image x:Name="SysInfoScriptCompatibilityImage" Width="14" Height="14" Margin="0,0,5,0"
                                   VerticalAlignment="Center"/>
                            <TextBlock x:Name="SysInfoScriptCompatibilityLabel" Text="Script features: "
                                       Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontWeight="Bold"
                                       FontFamily="{StaticResource PrimaryFont}"
                                       VerticalAlignment="Center"/>
                            <TextBlock x:Name="SysInfoScriptCompatibility" Text="Checking."
                                       Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                       FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                       VerticalAlignment="Center" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Grid>

                    <!-- Riga 2: Stato Bitlocker con status colorato - Stessa dimensione della Riga 1 -->
                    <Grid HorizontalAlignment="Center" Margin="0,4,0,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Image x:Name="BitlockerImage" Width="14" Height="14" Margin="0,0,5,0"
                               VerticalAlignment="Center"/>
                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock x:Name="SysInfoBitlockerLabel" Text="BitLocker status: "
                                       Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontWeight="Bold"
                                       FontFamily="{StaticResource PrimaryFont}"
                                       VerticalAlignment="Center" Margin="0,0,8,0"/>
                            <TextBlock x:Name="SysInfoBitlocker" Text="Checking."
                                       Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                       FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                       VerticalAlignment="Center"/>
                        </StackPanel>
                    </Grid>
                </StackPanel>

                <!-- Separatore Verde Verticale 2: Tra Funzionalità Script e Hardware -->
                <Border Grid.Column="3" Width="3" Background="{StaticResource SeparatorGreen}"
                        VerticalAlignment="Stretch" Margin="15,5"/>

                <!-- Blocco 3: Hardware Info (Allineamento speculare al blocco 1) -->
                <StackPanel Grid.Column="4" Margin="20,0,0,0">
                    <TextBlock Text="▬▬ Hardware ▬▬"
                               Foreground="{StaticResource LabelBlue}"
                               FontSize="$($FontSize.Medium)" FontWeight="Bold"
                               FontFamily="{StaticResource PrimaryFont}"
                               Margin="0,0,0,12" TextAlignment="Right"/>

                    <!-- Computer Name Row - Increased font size -->
                    <Grid Margin="0,6,0,6">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Image x:Name="SysInfoComputerNameImage" Width="16" Height="16" Margin="0,0,5,0"/>
                            <TextBlock x:Name="SysInfoComputerNameLabel" Text="PC name: " Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoComputerName" Text="Loading."
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center" TextAlignment="Right"/>
                    </Grid>

                    <!-- RAM Row - Increased font size -->
                    <Grid Margin="0,6,0,6">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Image x:Name="SysInfoRAMImage" Width="16" Height="16" Margin="0,0,5,0"/>
                            <TextBlock x:Name="SysInfoRAMLabel" Text="RAM: " Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoRAM" Text="Loading."
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center" TextAlignment="Right"/>
                    </Grid>

                    <!-- Disk Row - Increased font size -->
                    <Grid Margin="0,6,0,6">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Image x:Name="SysInfoDiskImage" Width="16" Height="16" Margin="0,0,5,0"/>
                            <TextBlock x:Name="SysInfoDiskLabel" Text="Disk: " Foreground="{StaticResource LabelBlue}"
                                       FontSize="$($FontSize.Small)" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoDisk" Text="Loading."
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Small)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center" TextAlignment="Right"/>
                    </Grid>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Main Content - Left Panel con separatori verdi spessi -->
        <Grid Grid.Row="2" Margin="16">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="500"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Left Panel - Actions con separatori verdi spessi -->
            <Border Grid.Column="0" Background="{StaticResource PanelBackgroundColor}"
                    CornerRadius="8" Margin="0,0,8,0" Padding="16">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Header con Icona Gear (CategorySystem) -->
                    <StackPanel Grid.Row="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,0,12">
                        <Image x:Name="CategorySystemImage" Width="24" Height="24" Margin="0,0,8,0"
                               VerticalAlignment="Center"/>
                        <TextBlock x:Name="AvailableFunctionsText" Text="Available functions"
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Large)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center"/>
                    </StackPanel>

                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel x:Name="ActionsPanel" Margin="0,0,0,8"/>
                    </ScrollViewer>
                </Grid>
            </Border>

            <!-- Right Panel - Output -->
            <Border Grid.Column="1" Background="{StaticResource PanelBackgroundColor}"
                    CornerRadius="8" Padding="16">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Header con Icona Taccuino (OutputLog) -->
                    <StackPanel Grid.Row="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,0,12">
                        <Image x:Name="OutputLogImage" Width="24" Height="24" Margin="0,0,8,0"
                               VerticalAlignment="Center"/>
                        <TextBlock x:Name="OutputLogsText" Text="Output and logs"
                                   Foreground="{StaticResource TextColor}" FontSize="$($FontSize.Large)"
                                   FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}"
                                   VerticalAlignment="Center"/>
                    </StackPanel>

                    <RichTextBox x:Name="OutputTextBox"
                                 Grid.Row="1"
                                 Background="{StaticResource OutputBackgroundColor}"
                                 Foreground="{StaticResource TextColor}"
                                 BorderBrush="{StaticResource BorderColor}"
                                 BorderThickness="1"
                                 IsReadOnly="True"
                                 FontFamily="{StaticResource PrimaryFont}"
                                 FontSize="$($FontSize.Small)"/>
                </Grid>
            </Border>
        </Grid>

        <!-- Task 5: Footer con pulsante Esegui pill-shaped (CornerRadius 20+) -->
        <Border Grid.Row="3" Background="{StaticResource HeaderBackgroundColor}"
                Padding="16" Margin="16,8,16,16" CornerRadius="12">
            <StackPanel>
                <!-- ProgressBar visibile con altezza 20 e colore azzurro vivido, resa pill-shaped via Style -->
                <ProgressBar x:Name="MainProgressBar"
                             Height="20"
                             Margin="0,0,0,12"
                             Background="{StaticResource PanelBackgroundColor}"
                             BorderBrush="{StaticResource SeparatorGreen}"
                             BorderThickness="1"
                             Foreground="#2196F3"
                             Minimum="0"
                             Maximum="100"
                             Value="0"
                             Style="{StaticResource PillProgressBarStyle}"/>

                <!-- Pulsante Esegui centrato, pill-shaped (CornerRadius 25), azzurro -->
                <Button x:Name="ExecuteButton"
                        Background="{StaticResource ExecuteButtonColor}"
                        Foreground="{StaticResource TextColor}"
                        FontSize="$($FontSize.Large)"
                        FontWeight="Bold"
                        FontFamily="{StaticResource PrimaryFont}"
                        Padding="48,18"
                        BorderThickness="0"
                        HorizontalAlignment="Center"
                        Cursor="Hand"
                        Style="{StaticResource PillButtonStyle}">
                    <StackPanel Orientation="Horizontal">
                        <Image x:Name="ExecuteButtonImage" Width="20" Height="20" Margin="0,0,8,0"/>
                        <TextBlock x:Name="ExecuteButtonText" Text="Run scripts" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
            </StackPanel>
        </Border>
    </Grid>
</Window>
"@

# Create window
try {
    Write-UnifiedLog -Type 'Info' -Message "Creating WPF window." -GuiColor "#00CED1"
    $window = [Windows.Markup.XamlReader]::Parse($xaml)

    # Setup Window Icon (Favicon & Taskbar) - Remote Fallback
    try {
        $localImgDir = Join-Path $env:LOCALAPPDATA "WinToolkit\images"
        if (-not (Test-Path $localImgDir)) { New-Item -Path $localImgDir -ItemType Directory -Force | Out-Null }

        $iconPath = Join-Path $localImgDir "WinToolkit.ico"
        $iconUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/images/WinToolkit.ico"

        if (-not (Test-Path $iconPath)) {
            Invoke-WebRequest -Uri $iconUrl -OutFile $iconPath -UseBasicParsing -ErrorAction Stop
        }
        else {
            $window.Icon = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$iconPath)
        }
    }
    catch {
        Write-UnifiedLog -Type 'Warning' -Message "⚠️ Impossibile caricare o scaricare l'icona della finestra: $($_.Exception.Message)." -GuiColor "#FFA500"
    }

    Write-UnifiedLog -Type 'Success' -Message "Window created successfully." -GuiColor "#00FF00"
}
catch {
    Write-UnifiedLog -Type 'Error' -Message "Failed to create window: $($_.Exception.Message)." -GuiColor "#FF0000"
    Read-Host "Press Enter to exit"
    exit
}

# Get controls
$actionsPanel = $window.FindName("ActionsPanel")
$outputTextBox = $window.FindName("OutputTextBox")
$executeButton = $window.FindName("ExecuteButton")
$SysInfoEdition = $window.FindName("SysInfoEdition")
$SysInfoVersion = $window.FindName("SysInfoVersion")
$SysInfoArchitecture = $window.FindName("SysInfoArchitecture")
$SysInfoComputerName = $window.FindName("SysInfoComputerName")
$SysInfoRAM = $window.FindName("SysInfoRAM")
$SysInfoDisk = $window.FindName("SysInfoDisk")
$SysInfoScriptCompatibility = $window.FindName("SysInfoScriptCompatibility")
$SysInfoScriptCompatibilityImage = $window.FindName("SysInfoScriptCompatibilityImage")
$SysInfoBitlocker = $window.FindName("SysInfoBitlocker")
$BitlockerImage = $window.FindName("BitlockerImage")
$SysInfoEditionImage = $window.FindName("SysInfoEditionImage")
$SysInfoVersionImage = $window.FindName("SysInfoVersionImage")
$SysInfoArchitectureImage = $window.FindName("SysInfoArchitectureImage")
$SysInfoComputerNameImage = $window.FindName("SysInfoComputerNameImage")
$SysInfoRAMImage = $window.FindName("SysInfoRAMImage")
$SysInfoDiskImage = $window.FindName("SysInfoDiskImage")
$SendErrorLogsButton = $window.FindName("SendErrorLogsButton")
$SendErrorLogsText = $window.FindName("SendErrorLogsText")
$LanguageLabelText = $window.FindName("LanguageLabelText")
$LanguageComboBox = $window.FindName("LanguageComboBox")
$SysInfoTitleText = $window.FindName("SysInfoTitleText")
$SysInfoEditionLabel = $window.FindName("SysInfoEditionLabel")
$SysInfoVersionLabel = $window.FindName("SysInfoVersionLabel")
$SysInfoArchitectureLabel = $window.FindName("SysInfoArchitectureLabel")
$SysInfoScriptCompatibilityLabel = $window.FindName("SysInfoScriptCompatibilityLabel")
$SysInfoBitlockerLabel = $window.FindName("SysInfoBitlockerLabel")
$SysInfoComputerNameLabel = $window.FindName("SysInfoComputerNameLabel")
$SysInfoRAMLabel = $window.FindName("SysInfoRAMLabel")
$SysInfoDiskLabel = $window.FindName("SysInfoDiskLabel")
$AvailableFunctionsText = $window.FindName("AvailableFunctionsText")
$OutputLogsText = $window.FindName("OutputLogsText")
$ExecuteButtonText = $window.FindName("ExecuteButtonText")
$SendErrorLogsImage = $window.FindName("SendErrorLogsImage")
$ToolIconImage = $window.FindName("ToolIconImage")
$ExecuteButtonImage = $window.FindName("ExecuteButtonImage")
$CategorySystemImage = $window.FindName("CategorySystemImage")
$OutputLogImage = $window.FindName("OutputLogImage")
$progressBar = $window.FindName("MainProgressBar")

function Set-TextBlockText {
    param([object]$Control, [string]$Text)
    if ($Control) { $Control.Text = $Text }
}

function Initialize-LanguageComboBox {
    if (-not $LanguageComboBox) { return }

    $LanguageComboBox.Items.Clear()
    foreach ($language in @(Get-AvailableToolkitLanguages)) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = $language.NativeName
        $item.Tag = $language.Code
        $LanguageComboBox.Items.Add($item) | Out-Null
        if ($language.Code -eq $Global:ToolkitLanguage) {
            $LanguageComboBox.SelectedItem = $item
        }
    }

    if (-not $LanguageComboBox.SelectedItem -and $LanguageComboBox.Items.Count -gt 0) {
        $LanguageComboBox.SelectedIndex = 0
    }
}

function Apply-GuiLocalization {
    Set-TextBlockText $LanguageLabelText (Get-Loc 'gui.languageLabel')
    Set-TextBlockText $SendErrorLogsText (Get-Loc 'gui.sendErrorLogs')
    Set-TextBlockText $SysInfoTitleText "▬▬ $(Get-Loc 'gui.systemInfo') ▬▬"
    Set-TextBlockText $SysInfoEditionLabel (Get-Loc 'gui.windowsEdition')
    Set-TextBlockText $SysInfoVersionLabel (Get-Loc 'gui.version')
    Set-TextBlockText $SysInfoArchitectureLabel (Get-Loc 'gui.architecture')
    Set-TextBlockText $SysInfoScriptCompatibilityLabel (Get-Loc 'gui.scriptFeatures')
    Set-TextBlockText $SysInfoBitlockerLabel (Get-Loc 'gui.bitlockerStatus')
    Set-TextBlockText $SysInfoComputerNameLabel (Get-Loc 'gui.pcName')
    Set-TextBlockText $SysInfoRAMLabel (Get-Loc 'gui.ram')
    Set-TextBlockText $SysInfoDiskLabel (Get-Loc 'gui.disk')
    Set-TextBlockText $AvailableFunctionsText (Get-Loc 'gui.availableFunctions')
    Set-TextBlockText $OutputLogsText (Get-Loc 'gui.outputLogs')
    Set-TextBlockText $ExecuteButtonText (Get-Loc 'gui.executeScripts')

    if ($SysInfoScriptCompatibility -and $SysInfoScriptCompatibility.Text -match '^(Complete|Completa)$') {
        $SysInfoScriptCompatibility.Text = Get-Loc 'gui.complete'
    }
    elseif ($SysInfoScriptCompatibility -and $SysInfoScriptCompatibility.Text -match '^(Limited|Limitata)$') {
        $SysInfoScriptCompatibility.Text = Get-Loc 'gui.limited'
    }
    elseif ($SysInfoScriptCompatibility -and $SysInfoScriptCompatibility.Text -match '^(Unsupported|Non supportata)$') {
        $SysInfoScriptCompatibility.Text = Get-Loc 'gui.unsupported'
    }
}

Initialize-LanguageComboBox
Apply-GuiLocalization

if ($LanguageComboBox) {
    $LanguageComboBox.Add_SelectionChanged({
            if (-not $LanguageComboBox.SelectedItem) { return }
            $selectedLanguage = [string]$LanguageComboBox.SelectedItem.Tag
            if ([string]::IsNullOrWhiteSpace($selectedLanguage) -or $selectedLanguage -eq $Global:ToolkitLanguage) { return }

            Set-ToolkitLanguage -LanguageCode $selectedLanguage
            Apply-GuiLocalization
            Update-SystemInformationPanel
            Update-ActionsPanel
        })
}

# Setup ExecuteButton con nuovo stile e inizializza icone
try {
    # Inizializza l'icona del pulsante Esegui
    if ($ExecuteButtonImage) {
        try {
            $playIconPath = Get-EmojiIconPath -EmojiCharacter $emojiMappings.ExecuteButtonImage
            if ($playIconPath -and (Test-Path $playIconPath)) {
                $ExecuteButtonImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri]$playIconPath)
            }
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not load ExecuteButton icon." -GuiColor "#FFA500"
        }
    }

    # Inizializza l'icona CategorySystem (Gear) per "Funzioni Disponibili"
    if ($CategorySystemImage) {
        try {
            $gearIconPath = Get-EmojiIconPath -EmojiCharacter $emojiMappings.CategorySystem
            if ($gearIconPath -and (Test-Path $gearIconPath)) {
                $CategorySystemImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri]$gearIconPath)
            }
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not load CategorySystem icon." -GuiColor "#FFA500"
        }
    }

    # Inizializza l'icona OutputLog (Taccuino)
    if ($OutputLogImage) {
        try {
            $logIconPath = Get-EmojiIconPath -EmojiCharacter $emojiMappings.OutputLogImage
            if ($logIconPath -and (Test-Path $logIconPath)) {
                $OutputLogImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri]$logIconPath)
            }
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not load OutputLog icon." -GuiColor "#FFA500"
        }
    }

    # Inizializza l'icona Tool (WinToolkit logo header) - Remote Fallback
    if ($ToolIconImage) {
        try {
            $localImgDir = Join-Path $env:LOCALAPPDATA "WinToolkit\images"
            if (-not (Test-Path $localImgDir)) { New-Item -Path $localImgDir -ItemType Directory -Force | Out-Null }

            # Qui usiamo la stessa icona scaricata prima, o ne scarichiamo un'altra se serve.
            # In base alla richiesta utente carichiamo WinToolkit.ico
            $toolLogoPath = Join-Path $localImgDir "WinToolkit.ico"
            $toolLogoUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/images/WinToolkit.ico"

            if (-not (Test-Path $toolLogoPath)) {
                Invoke-WebRequest -Uri $toolLogoUrl -OutFile $toolLogoPath -UseBasicParsing -ErrorAction Stop
            }

            if (Test-Path $toolLogoPath) {
                # Usa IconBitmapDecoder per leggere l'ico all'interno delle Image WPF
                $decoder = New-Object System.Windows.Media.Imaging.IconBitmapDecoder(
                    [uri]$toolLogoPath,
                    [System.Windows.Media.Imaging.BitmapCreateOptions]::None,
                    [System.Windows.Media.Imaging.BitmapCacheOption]::Default
                )
                $ToolIconImage.Source = $decoder.Frames[0]
            }
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not load ToolIconImage: $($_.Exception.Message)." -GuiColor "#FFA500"
        }
    }

    Write-UnifiedLog -Type 'Success' -Message "✅ ExecuteButton configurato con stile pill-shaped e icona Play." -GuiColor "#00FF00"
}
catch {
    Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not configure ExecuteButton." -GuiColor "#FFA500"
}

# =============================================================================
# SYSTEM INFORMATION UPDATE (Using Core's Get-SystemInfo) - Task 2
# =============================================================================

function Update-SystemInformationPanel {
    try {
        # Use Core's Get-SystemInfo function
        $sysInfo = Get-SystemInfo

        if (-not $sysInfo) {
            Write-UnifiedLog -Type 'Error' -Message "Failed to retrieve system information from Core." -GuiColor "#FF0000"
            return
        }

        # Update GUI on UI thread
        $window.Dispatcher.Invoke([Action] {
                # Task 2: Update text per il nuovo layout a 3 blocchi
                $SysInfoEdition.Text = $sysInfo.ProductName
                $SysInfoVersion.Text = "$($sysInfo.DisplayVersion) (Build $($sysInfo.BuildNumber))"
                $SysInfoArchitecture.Text = $sysInfo.Architecture
                $SysInfoComputerName.Text = $sysInfo.ComputerName
                $SysInfoRAM.Text = "$($sysInfo.TotalRAM) GB"
                $SysInfoDisk.Text = Get-Loc 'gui.diskFreeFormat' -Args @($sysInfo.FreePercentage, $sysInfo.FreeDisk, $sysInfo.TotalDisk)

                # Set image sources
                try {
                    $SysInfoEditionImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SysInfoEditionImage))
                    $SysInfoVersionImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SysInfoVersionImage))
                    $SysInfoArchitectureImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SysInfoArchitectureImage))
                    $SysInfoComputerNameImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SysInfoComputerNameImage))
                    $SysInfoRAMImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SysInfoRAMImage))
                    $SysInfoDiskImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SysInfoDiskImage))

                    if ($SendErrorLogsImage) {
                        $SendErrorLogsImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri](Get-EmojiIconPath -EmojiCharacter $emojiMappings.SendErrorLogsImage))
                    }
                }
                catch {
                    Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not load some icons: $($_.Exception.Message)." -GuiColor "#FFA500"
                }

                # Task 2: Compatibility indicator con status text colorato
                $statusText = ""
                $statusIconKey = "LEDStatusRed"

                if ($sysInfo.BuildNumber -ge 22000) {
                    $statusText = Get-Loc 'gui.complete'
                    $statusIconKey = "LEDStatusGreen"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                }
                elseif ($sysInfo.BuildNumber -ge 17763) {
                    $statusText = Get-Loc 'gui.complete'
                    $statusIconKey = "LEDStatusGreen"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                }
                elseif ($sysInfo.BuildNumber -ge 10240) {
                    $statusText = Get-Loc 'gui.limited'
                    $statusIconKey = "LEDStatusYellow"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Orange)
                }
                else {
                    $statusText = Get-Loc 'gui.unsupported'
                    $statusIconKey = "LEDStatusRed"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Red)
                }

                $SysInfoScriptCompatibility.Text = $statusText
                if ($SysInfoScriptCompatibilityImage) {
                    $statusIconPath = Get-EmojiIconPath -EmojiCharacter $emojiMappings[$statusIconKey]
                    if ($statusIconPath -and (Test-Path $statusIconPath)) {
                        $SysInfoScriptCompatibilityImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri]$statusIconPath)
                    }
                }

                # Aggiorna stato Bitlocker
                try {
                    $blStatusKey = Get-GuiBitlockerStatusKey
                    $blStatus = Get-Loc $blStatusKey
                    $SysInfoBitlocker.Text = $blStatus

                    # Colorazione status Bitlocker basata su chiave stabile e non sul testo localizzato.
                    if ($blStatusKey -eq 'bitlocker.status.on' -or $blStatusKey -eq 'bitlocker.status.encrypting') {
                        $SysInfoBitlocker.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                    }
                    elseif ($blStatusKey -eq 'bitlocker.status.suspended' -or $blStatusKey -eq 'bitlocker.status.decrypting') {
                        $SysInfoBitlocker.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Orange)
                    }
                    else {
                        # Stati disattivo/non configurato = rosso
                        $SysInfoBitlocker.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Red)
                    }

                    # Carica icona Bitlocker
                    if ($BitlockerImage) {
                        $blIconPath = Get-EmojiIconPath -EmojiCharacter $emojiMappings.BitlockerImage
                        if ($blIconPath -and (Test-Path $blIconPath)) {
                            $BitlockerImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri]$blIconPath)
                        }
                    }
                }
                catch {
                    Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not check Bitlocker status: $($_.Exception.Message)." -GuiColor "#FFA500"
                }
            })

        Write-UnifiedLog -Type 'Success' -Message "System information panel updated (3-block layout)." -GuiColor "#00FF00"
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "Error updating system information: $($_.Exception.Message)." -GuiColor "#FF0000"
    }
}

# =============================================================================
# DYNAMIC MENU GENERATION (From Core's $menuStructure)
# =============================================================================

function Update-ActionsPanel {
    try {
        Write-UnifiedLog -Type 'Info' -Message "🔄 Generating dynamic menu from Core \$menuStructure." -GuiColor "#00CED1"

        $window.Dispatcher.Invoke([Action] {
                $actionsPanel.Children.Clear()

                if ($Global:MenuStructure.Count -eq 0) {
                    Write-UnifiedLog -Type 'Warning' -Message "⚠️ \$menuStructure is empty, using fallback static menu." -GuiColor "#FFA500"
                    return
                }

                foreach ($category in $Global:MenuStructure) {
                    # ========================================
                    # A. CATEGORY HEADER (con Linea Verde + Emoji)
                    # ========================================

                    # Aggiungi linea verde spessa (3px) PRIMA del titolo
                    $greenLine = New-Object System.Windows.Controls.Border
                    $greenLine.Height = 3
                    $greenLine.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#2E7D32"))
                    $greenLine.Margin = New-Object System.Windows.Thickness(0, 5, 0, 10)
                    $actionsPanel.Children.Add($greenLine) | Out-Null

                    # Category container con Emoji + Nome
                    $categoryContainer = New-Object System.Windows.Controls.StackPanel
                    $categoryContainer.Orientation = [System.Windows.Controls.Orientation]::Horizontal
                    $categoryContainer.Margin = '0,0,0,6'

                    # Emoji (SOLO nell'header della categoria)
                    $iconPath = Get-IconWithFallback -EmojiCharacter $category.Icon
                    if ($iconPath) {
                        $categoryEmoji = New-Object System.Windows.Controls.Image
                        $categoryEmoji.Source = New-Object System.Windows.Media.Imaging.BitmapImage([uri]$iconPath)
                        $categoryEmoji.Width = 20
                        $categoryEmoji.Height = 20
                        $categoryEmoji.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
                        $categoryEmoji.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                    }
                    else {
                        $categoryEmoji = New-Object System.Windows.Controls.TextBlock
                        $categoryEmoji.Text = $category.Icon
                        $categoryEmoji.FontSize = $FontSize.Large
                        $categoryEmoji.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
                        $categoryEmoji.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                        $categoryEmoji.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::White)
                    }
                    $categoryContainer.Children.Add($categoryEmoji) | Out-Null

                    # Category Name (Bold, Cyan)
                    $categoryHeader = New-Object System.Windows.Controls.TextBlock
                    $categoryHeader.Text = Get-ToolkitMenuText $category
                    $categoryHeader.FontSize = $FontSize.Small
                    $categoryHeader.FontWeight = 'Bold'
                    $categoryHeader.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Cyan)
                    $categoryHeader.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                    $categoryHeader.FontFamily = New-Object System.Windows.Media.FontFamily($FontFamily)
                    $categoryContainer.Children.Add($categoryHeader) | Out-Null

                    $actionsPanel.Children.Add($categoryContainer) | Out-Null

                    # ========================================
                    # B. SCRIPT ROWS (CheckBox + Text)
                    # ========================================

                    foreach ($script in $category.Scripts) {
                        # Container orizzontale per CheckBox + Text
                        $scriptRow = New-Object System.Windows.Controls.StackPanel
                        $scriptRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal
                        $scriptRow.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Transparent)
                        $scriptRow.Margin = '0,4,0,4'
                        $scriptRow.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

                        # CheckBox
                        $checkBox = New-Object System.Windows.Controls.CheckBox
                        $checkBox.Name = "chk_$($script.Name.Replace(' ', '').Replace('-', '_'))"
                        $checkBox.Tag = $script.Name
                        $checkBox.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#4FC3F7"))
                        $checkBox.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Gray)
                        $checkBox.BorderBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#4FC3F7"))
                        $checkBox.BorderThickness = New-Object System.Windows.Thickness(1)
                        $checkBox.Padding = New-Object System.Windows.Thickness(6, 4, 6, 4)
                        $checkBox.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
                        $checkBox.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                        $checkBox.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
                        $scriptRow.Children.Add($checkBox) | Out-Null

                        # TextBlock unico: <Bold>Nome Script</Bold> - Descrizione
                        $textBlock = New-Object System.Windows.Controls.TextBlock
                        $textBlock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                        $textBlock.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
                        $textBlock.MaxWidth = 320
                        $textBlock.FontFamily = New-Object System.Windows.Media.FontFamily($FontFamily)

                        # Bold Script Name (White)
                        $titleRun = New-Object System.Windows.Documents.Run
                        $titleRun.Text = Get-ToolkitMenuText $script
                        $titleRun.FontWeight = [System.Windows.FontWeights]::Bold
                        $titleRun.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::White)

                        $textBlock.Inlines.Add($titleRun)
                        $scriptRow.Children.Add($textBlock) | Out-Null

                        $actionsPanel.Children.Add($scriptRow) | Out-Null
                    }
                }

                Write-UnifiedLog -Type 'Success' -Message "✅ Dynamic menu generated: $($Global:MenuStructure.Count) categories." -GuiColor "#00FF00"
            })
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "❌ Error generating dynamic menu: $($_.Exception.Message)." -GuiColor "#FF0000"
    }
}

# Task 6: Funzione helper per determinare l'emoji in base al nome dello script
function Get-ScriptEmoji {
    param([string]$ScriptName)

    $nameLower = $ScriptName.ToLower()

    if ($nameLower -match 'powershell|posh') { return $emojiMappings.ScriptPowerShell }
    elseif ($nameLower -match 'winget|install|package') { return $emojiMappings.ScriptWinget }
    elseif ($nameLower -match 'clean|remove|debloat') { return $emojiMappings.ScriptCleaner }
    elseif ($nameLower -match 'repair|fix|restore') { return $emojiMappings.ScriptRepair }
    elseif ($nameLower -match 'backup|driver|export') { return $emojiMappings.ScriptBackup }
    elseif ($nameLower -match 'update|upgrade') { return $emojiMappings.ScriptUpdate }
    elseif ($nameLower -match 'driver|nvidia|amd|gpu') { return $emojiMappings.ScriptDriver }
    elseif ($nameLower -match 'network|tcp|dns|firewall') { return $emojiMappings.ScriptNetwork }
    elseif ($nameLower -match 'privacy|telemetry') { return $emojiMappings.ScriptPrivacy }
    elseif ($nameLower -match 'performance|optimization|tweak') { return $emojiMappings.ScriptPerformance }
    elseif ($nameLower -match 'security|antivirus|defender') { return $emojiMappings.ScriptSecurity }
    elseif ($nameLower -match 'debloat|appx|store') { return $emojiMappings.ScriptDebloat }
    else { return "📄" }
}

# =============================================================================
# HELPER FUNCTION: Filter and format job output
# =============================================================================
function Format-JobOutput {
    param(
        [string]$Line
    )

    # Filtra messaggi vuoti o non significativi
    if (-not $Line.Trim()) { return $false }

    # Handle WINTOOLKIT_STYLED_MESSAGE_TAG
    if ($Line -match '\[WINTOOLKIT_STYLED_MESSAGE_TAG\]\s*(?<Type>\w+)\s*:\s*(?<Text>.*)') {
        $outputType = $matches.Type
        $messageText = $matches.Text
        $guiColor = switch -Wildcard ($outputType.ToLower()) {
            "error" { "#FF5555" }
            "warning" { "#FFB74D" }
            "success" { "#4CAF50" }
            "info" { "#00CED1" }
            "progress" { "#2196F3" }
            default { "#FFFFFF" }
        }
        Write-UnifiedLog -Type $outputType -Message $messageText -GuiColor $guiColor
        return $true
    }

    # Handle WINTOOLKIT_PROGRESS_TAG (Relaxed regex to match anywhere)
    if ($Line -match '\[WINTOOLKIT_PROGRESS_TAG\].*Percent:\s*(?<Percent>\d+)%') {
        $percent = [int]$matches.Percent

        # Log version of progress to OutputTextBox
        if ($Line -match 'Activity:\s*(?<Activity>[^|]+)\| Status:\s*(?<Status>[^|]+)') {
            $activity = $matches.Activity.Trim()
            $status = $matches.Status.Trim()

            # IMPROVED VERBOSITY: Log only if percentage OR status has changed
            if ( ($status -ne $Global:LastLoggedProgress.Status) -or
                ($percent -ne $Global:LastLoggedProgress.Percent)
            ) {
                Write-UnifiedLog -Type 'Progress' -Message "🔄 [$activity] $status ($percent%)." -GuiColor "#2196F3"
                $Global:LastLoggedProgress.Percent = $percent
                $Global:LastLoggedProgress.Status = $status
            }
        }

        $window.Dispatcher.Invoke([Action] {
                if ($progressBar) { $progressBar.Value = $percent }
            })
        return $true
    }

    # Handle WINTOOLKIT_INPUT_BYPASS_TAG (Nuovo)
    if ($Line -match '\[WINTOOLKIT_INPUT_BYPASS_TAG\] Prompt:\s*(?<Prompt>.*)') {
        $promptText = $matches.Prompt
        Write-UnifiedLog -Type 'Info' -Message "ℹ️ Input interattivo bypassato per: '$promptText'. Scelta predefinita 'Y'." -GuiColor "#00CED1"
        return $true
    }

    # Handle WINTOOLKIT_COUNTDOWN_BYPASS_TAG (Nuovo)
    if ($Line -match '\[WINTOOLKIT_COUNTDOWN_BYPASS_TAG\] Message:\s*(?<Message>.*)\s*\|\s*Seconds:\s*(?<Seconds>\d+)') {
        $countdownMessage = $matches.Message
        $countdownSeconds = $matches.Seconds
        Write-UnifiedLog -Type 'Info' -Message "⏳ Conto alla rovescia bypassato: '$countdownMessage' ($countdownSeconds secondi)." -GuiColor "#00CED1"
        return $true
    }

    # Handle WINTOOLKIT_CONFIRMATION_BYPASS_TAG (Nuovo)
    if ($Line -match '\[WINTOOLKIT_CONFIRMATION_BYPASS_TAG\] Message:\s*(?<Message>.*)') {
        $confirmationMessage = $matches.Message
        Write-UnifiedLog -Type 'Info' -Message "✅ Conferma utente bypassata per: '$confirmationMessage'. Risposta predefinita 'Sì'." -GuiColor "#00CED1"
        return $true
    }

    # Handle WINTOOLKIT_RAW_HOST_OUTPUT_TAG
    if ($Line -match '\[WINTOOLKIT_RAW_HOST_OUTPUT_TAG\](?<Text>.*)') {
        $messageText = $matches.Text.Trim()
        if (-not [string]::IsNullOrEmpty($messageText)) {
            # Regex updated to include all common icons from Core's MsgStyles and various script rules
            $styledRawPattern = "^\[(?<Timestamp>\d{2}:\d{2}:\d{2})\]\s*(?<Icon>[✅⚠️❌💎🔄🗂️📁🖨️📄🗑️💭⸏▶️💡⏰🎉💻📊⚙️🛡️🚀📡🔑⏳📦💽🕸️🖨️🎯🔕🔥✨📜💾💽🦊🌐])\s*(?<Rest>.*)$"
            if ($messageText -match $styledRawPattern) {
                $icon = $matches.Icon
                $restOfText = $matches.Rest.Trim()
                $type = 'Info' # Default, will try to infer more precisely
                $guiColor = "#00CED1" # Default Info color

                # Infer type and color from icon and keywords
                switch ($icon) {
                    '✅' { $type = 'Success'; $guiColor = "#4CAF50" }
                    '⚠️' { $type = 'Warning'; $guiColor = "#FFB74D" }
                    '❌' { $type = 'Error'; $guiColor = "#FF5555" }
                    { $_ -in @('💎', 'ℹ️', '💡', '⚙️', '🔑', '⏳', '📦', '🚀', '🛡️', '💽', '🕸️', '🖨️', '🎯', '🔕', '🔥', '✨', '📜', '💾', '🦊', '🌐') } { $type = 'Info'; $guiColor = "#00CED1" }
                    '🔄' { $type = 'Progress'; $guiColor = "#2196F3" }
                }
                # Also try to infer from keywords within the "Rest" part if icon mapping isn't precise
                if ($type -eq 'Info') {
                    if ($restOfText -match '(?i)ERROR|FAILED|ERR|FALLITO|CRITICAL') { $type = 'Error'; $guiColor = "#FF5555" }
                    elseif ($restOfText -match '(?i)WARNING|WARN|ATTENZIONE|IMPOSSIBLE') { $type = 'Warning'; $guiColor = "#FFB74D" }
                    elseif ($restOfText -match '(?i)SUCCESS|COMPLETED|FATTO|OK') { $type = 'Success'; $guiColor = "#4CAF50" }
                }

                # Fix double emoji: if RestOfText already starts with the MUST-HAVE emoji, don't double it
                if ($restOfText.StartsWith($icon)) {
                    Write-UnifiedLog -Type $type -Message "$restOfText" -GuiColor $guiColor
                }
                else {
                    Write-UnifiedLog -Type $type -Message "$icon $restOfText" -GuiColor $guiColor
                }
            }
            # Handle special header/footer lines (No TRACE for these)
            elseif ($messageText -match '^(?:={5,}|-{5,}|_={5,}|_\s*={5,}|╔|╚|═|─|━|┌|┐|└|┘|│|WinToolkit - System Check)') {
                # Ignore decorative lines
            }
            else {
                # Raw output handling with Trace Mode toggle
                if ($Global:GuiBridgeTraceMode) {
                    Write-UnifiedLog -Type 'Info' -Message "[TRACE] $messageText" -GuiColor "#808080"
                }
                else {
                    Write-UnifiedLog -Type 'Info' -Message "$messageText" -GuiColor "#B0B0B0"
                }
            }
        }
        return $true
    }

    # Pattern per banner ASCII e linee decorative (consolidato e migliorato)
    $bannerPatterns = @(
        '^\s*═+\s*$', '^\s*─+\s*$', '^\s*—+\s*$', '^\s*━+\s*$',
        '__        __  _  _   _',
        '\\ \\      / / | || \\ | |',
        '__   __  / /  | || . ` | |',
        '   |/  \|/|  | || |\  | |',
        '   |_||_| |_| |_||_| \_|',
        '╔═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗',
        '^\s*║',
        '╚═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝',
        '──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────',
        'WinToolkit - System Check',
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        '\[Header\]',
        '╦.*╦',
        '╠.*╣',
        '╩.*╩',
        '^\*\*\*\*\*+'
    )

    foreach ($pattern in $bannerPatterns) {
        if ($Line -match $pattern) { return $false }
    }

    # Check for interactive input prompts
    if ($Line -match '\[INPUT\]|\[CHOICE\]|\[CONFIRM\]|\?|\[Y/N\]|premi un tasto per continuare|vuoi rischiare') {
        $Global:IsInputWaiting = $true
        Write-UnifiedLog -Type 'Warning' -Message "⚠️ Input interattivo rilevato: $Line - Non supportato in modalità GUI." -GuiColor "#FFA500"
        return $true
    }

    # Default handling for any other output
    $outputType = 'Info'
    $guiColor = "#B0B0B0"
    if ($Line -match '(?i)ERROR|FAILED|ERR|FALLITO|CRITICAL') { $outputType = 'Error'; $guiColor = "#FF5555" }
    elseif ($Line -match '(?i)WARNING|WARN|ATTENZIONE|IMPOSSIBLE') { $outputType = 'Warning'; $guiColor = "#FFB74D" }
    elseif ($Line -match '(?i)SUCCESS|COMPLETED|FATTO|OK') { $outputType = 'Success'; $guiColor = "#4CAF50" }

    Write-UnifiedLog -Type $outputType -Message $Line.Trim() -GuiColor $guiColor
    return $true
}

# =============================================================================
# SCRIPT EXECUTION - ASYNCHRONOUS IMPLEMENTATION (Using DispatcherTimer)
# =============================================================================

# Funzione per avviare il job per lo script corrente
function Start-NextScriptJob {
    param($scriptName)

    # Disabilita il pulsante di esecuzione e resetta la barra di progresso (se è il primo script)
    $window.Dispatcher.Invoke([Action] {
            $executeButton.IsEnabled = $false
        })

    Write-UnifiedLog -Type 'Info' -Message "🚀 Avvio esecuzione: $scriptName." -GuiColor "#00CED1"

    # Define paths needed by the job
    $coreScriptPath = $Global:CoreConfig.LocalCachePath
    $mainLogDirectory = $LogDirectory

    Write-UnifiedLog -Type 'Info' -Message "   Core for job: $coreScriptPath." -GuiColor "#808080"

    # Define the script block to be executed within the job's isolated runspace
    $jobScriptBlock = {
        param($CorePath, $CmdName, $MainLogDir)

        # Set ErrorActionPreference for the job's runspace
        $ErrorActionPreference = 'Continue'

        # --- FIX: Ensure PATH is fully available for child processes ---
        $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        # --- END FIX ---

        # Ensure logging directory exists for the job process
        try {
            if (-not ([System.IO.Directory]::Exists($MainLogDir))) {
                [System.IO.Directory]::CreateDirectory($MainLogDir) | Out-Null
            }
        }
        catch {}

        # Dot-source the Core script first, as all functions are defined there
        try {
            if (Test-Path $CorePath) {
                $Global:GuiSessionActive = $true
                . $CorePath
            }
            else {
                Write-Error "Core script not found at $CorePath within job."
                $Global:NeedsFinalReboot = $false
                return @{ Success = $false; RebootRequired = $Global:NeedsFinalReboot; Error = "Core script not found." }
            }
        }
        catch {
            Write-Error "Failed to dot-source Core script within job: $($_.Exception.Message)."
            $Global:NeedsFinalReboot = $false
            return @{ Success = $false; RebootRequired = $Global:NeedsFinalReboot; Error = $_.Exception.Message }
        }

        # --- FIX: Suppress Verbose and Debug output streams within the job ---
        $VerbosePreference = 'SilentlyContinue'
        $DebugPreference = 'SilentlyContinue'
        # --- END FIX ---

        # 5. --- REDEFINE (SHIM) CRITICAL UI FUNCTIONS FOR GUI MODE ---
        # These definitions will now override the ones loaded from CorePath,
        # ensuring GUI-specific behavior for output and user interaction.

        # Shim Clear-Host to prevent clearing job output or causing errors in non-console host.
        function Clear-Host { Write-Debug "[GUI_SHIM] Clear-Host bypassed." }

        # Shim Clear-ProgressLine. The original has a ConsoleHost check, but this ensures no raw UI access.
        function Clear-ProgressLine { Write-Debug "[GUI_SHIM] Clear-ProgressLine bypassed." }

        # Shim Read-Host to provide default answers, preventing job blockage.
        function Read-Host {
            param([string]$Prompt)
            Write-Debug "[GUI_SHIM] Interactive prompt bypassed for: '$Prompt'. Returning 'Y'."
            Write-Output "[WINTOOLKIT_INPUT_BYPASS_TAG] Prompt: $Prompt" # Tag per la GUI
            return 'Y' # Default to 'Yes' for most confirmations/choices in GUI mode.
        }

        # Shim Start-InterruptibleCountdown to bypass user interaction and the console UI countdown.
        function Start-InterruptibleCountdown {
            param(
                [int]$Seconds = 30,
                [string]$Message = "Riavvio automatico",
                [switch]$Suppress
            )
            Write-Debug "[GUI_SHIM] Countdown bypassed for '$Message' (durata: $Seconds secondi)."
            Write-Output "[WINTOOLKIT_COUNTDOWN_BYPASS_TAG] Message: $Message | Seconds: $Seconds." # Tag per la GUI
            return $true
        }

        # Shim Get-UserConfirmation to always confirm actions, preventing user interaction.
        function Get-UserConfirmation {
            param([string]$Message, [string]$DefaultChoice = 'N')
            Write-Debug "[GUI_SHIM] User confirmation bypassed for: '$Message'. Returning 'Yes'."
            Write-Output "[WINTOOLKIT_CONFIRMATION_BYPASS_TAG] Message: $Message." # Tag per la GUI
            return $true # Assume 'Yes' for all user confirmations in GUI mode.
        }

        # Shim Show-Header to prevent raw console output (ASCII art, direct window size checks).
        function Show-Header {
            param([string]$SubTitle = "Menu Principale")
            Write-Debug "[GUI_SHIM] Intestazione: WinToolkit - $SubTitle (bypassed direct console output)."
            Write-Output "[WINTOOLKIT_STYLED_MESSAGE_TAG] Info`: HEADER: $SubTitle." # Invia come messaggio stilizzato per la GUI
        }

        # Shim Invoke-WithSpinner - GUI version adapts progress reporting for scripts using Invoke-WithSpinner
        function Invoke-WithSpinner {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true)][string]$Activity,
                [Parameter(Mandatory = $true)][scriptblock]$Action,
                [Parameter(Mandatory = $false)][int]$TimeoutSeconds = 300,
                [Parameter(Mandatory = $false)][int]$UpdateInterval = 500,
                [Parameter(Mandatory = $false)][switch]$Process,
                [Parameter(Mandatory = $false)][switch]$Job,
                [Parameter(Mandatory = $false)][switch]$Timer,
                [Parameter(Mandatory = $false)][scriptblock]$PercentUpdate
            )

            $startTime = Get-Date
            $percent = 0

            try {
                $result = & $Action

                if ($Timer) {
                    $totalSeconds = $TimeoutSeconds
                    for ($i = $totalSeconds; $i -gt 0; $i--) {
                        if ($PercentUpdate) {
                            $percent = & $PercentUpdate
                        }
                        else {
                            $percent = [math]::Round((($totalSeconds - $i) / $totalSeconds) * 100)
                        }
                        # Output via Warning stream to avoid pipeline pollution
                        Write-Warning "[WINTOOLKIT_PROGRESS_TAG] Activity: $Activity | Status: $i secondi. | Percent: $percent%."
                        Start-Sleep -Seconds 1
                    }
                    return $true
                }
                elseif ($Process -and $result -and $result.GetType().Name -eq 'Process') {
                    while (-not $result.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

                        if ($PercentUpdate) {
                            $percent = & $PercentUpdate
                        }
                        else {
                            # Permetti alla percentuale casuale di raggiungere fino a 99% per una progressione più naturale
                            $percent = [math]::Min(99, $percent + (Get-Random -Minimum 1 -Maximum 3))
                        }

                        Write-Warning "[WINTOOLKIT_PROGRESS_TAG] Activity: $Activity | Status: Esecuzione in corso. ($elapsed secondi) | Percent: $percent%."
                        Start-Sleep -Milliseconds $UpdateInterval
                        $result.Refresh()
                    }

                    if (-not $result.HasExited) {
                        Write-Warning "[WINTOOLKIT_STYLED_MESSAGE_TAG][Warning] Timeout raggiunto dopo $TimeoutSeconds secondi, terminazione processo."
                        $result.Kill()
                        Start-Sleep -Seconds 2
                        return @{ Success = $false; TimedOut = $true; ExitCode = -1 }
                    }

                    Write-Warning "[WINTOOLKIT_PROGRESS_TAG] Activity: $Activity | Status: Completed | Percent: 100%."
                    return @{ Success = $true; TimedOut = $false; ExitCode = $result.ExitCode }
                }
                elseif ($Job -and $result -and $result.GetType().Name -eq 'Job') {
                    while ($result.State -eq 'Running') {
                        Write-Warning "[WINTOOLKIT_PROGRESS_TAG] Activity: $Activity | Status: In esecuzione. | Percent: $percent%."
                        Start-Sleep -Milliseconds $UpdateInterval
                        # Allow progress up to 99% for Jobs too
                        if ($percent -lt 99) { $percent += 5 }
                    }
                    $jobResult = Receive-Job $result -Wait
                    return $jobResult
                }
                else {
                    return $result
                }
            }
            catch {
                Write-Warning "[WINTOOLKIT_STYLED_MESSAGE_TAG][Error] Errore durante ${Activity}: $($_.Exception.Message)."
                return @{ Success = $false; Error = $_.Exception.Message }
            }
        }

        # Shim Write-StyledMessage to redirect styled messages from Core to Write-Warning with tags
        function Write-StyledMessage {
            param(
                [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Progress')][string]$Type,
                [string]$Text
            )
            # Use Write-Warning to bypass Success Pipeline (prevent variable pollution)
            Write-Warning "[WINTOOLKIT_STYLED_MESSAGE_TAG] $Type`: $Text"
        }

        # Shim Show-ProgressBar to prevent raw console output for progress bars.
        function Show-ProgressBar {
            param(
                [string]$Activity,
                [string]$Status,
                [int]$Percent,
                [string]$Icon = '⏳',
                [string]$Spinner = '',
                [string]$Color = 'Green'
            )
            # Ensure Percent is an integer
            $intPercent = [int]$Percent
            Write-Warning "[WINTOOLKIT_PROGRESS_TAG] Activity: $Activity | Status: $Status | Percent: $($intPercent)% | Icon: $Icon | Spinner: $Spinner."
        }

        # Shim Write-Progress to redirect standard PowerShell progress to the GUI
        function Write-Progress {
            param(
                [Parameter(Mandatory = $true)][string]$Activity,
                [string]$Status = "",
                [int]$PercentComplete = -1,
                [switch]$Completed
            )
            if ($Completed) {
                Write-Warning "[WINTOOLKIT_PROGRESS_TAG] Activity: $Activity | Status: Completed | Percent: 100%."
            }
            elseif ($PercentComplete -ge 0) {
                Write-Warning "[WINTOOLKIT_PROGRESS_TAG] Activity: $Activity | Status: $Status | Percent: $($PercentComplete)%."
            }
        }

        # Shim Write-Host - uses Write-Warning to bypass Success Pipeline
        function Write-Host {
            param(
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object] $Object,
                [string] $Separator = " ",
                [string] $ForegroundColor,
                [string] $BackgroundColor,
                [switch] $NoNewline
            )

            process {
                # Use $Object to handle direct calls; handle pipeline via $_ if $Object is null
                $target = if ($null -ne $Object) { $Object } else { $_ }
                $output = ($target | Out-String).TrimEnd("`r`n")

                if (-not [string]::IsNullOrEmpty($output)) {
                    # If it's already a tagged message, don't double tag it
                    if ($output -match '\[WINTOOLKIT_.*_TAG\]') {
                        Write-Warning $output
                    }
                    else {
                        Write-Warning "[WINTOOLKIT_RAW_HOST_OUTPUT_TAG]$output"
                    }
                }
            }
        }
        # --- End of REDEFINITIONS ---

        # Build dynamic arguments to avoid interactive prompts
        $argsToPass = @()
        try {
            $commandInfo = Get-Command $CmdName -ErrorAction Stop
            if ($commandInfo.Parameters.ContainsKey('SuppressIndividualReboot')) {
                $argsToPass += '-SuppressIndividualReboot'
            }
            if ($commandInfo.Parameters.ContainsKey('CountdownSeconds')) {
                $argsToPass += '-CountdownSeconds 0'
            }
            if ($commandInfo.Parameters.ContainsKey('RunStandalone')) {
                $argsToPass += '-RunStandalone:$false'
            }
        }
        catch {
            Write-Error "Cannot get parameters for function '$CmdName': $($_.Exception.Message)."
            $Global:NeedsFinalReboot = $false
            return @{ Success = $false; RebootRequired = $Global:NeedsFinalReboot; Error = $_.Exception.Message }
        }

        # Execute the function. Redirect all streams to capture everything.
        try {
            if (Get-Command $CmdName -ErrorAction SilentlyContinue) {
                $Global:NeedsFinalReboot = $false
                $scriptBlock = [ScriptBlock]::Create("& $CmdName $($argsToPass -join ' ') *>&1")
                & $scriptBlock
            }
            else {
                Write-Error "Function '$CmdName' not found after dot-sourcing within job."
                $Global:NeedsFinalReboot = $false
                return @{ Success = $false; RebootRequired = $Global:NeedsFinalReboot; Error = "Function not found." }
            }
        }
        catch {
            Write-Error "Error executing function '$CmdName' within job: $($_.Exception.Message)."
            $Global:NeedsFinalReboot = $false
            return @{ Success = $false; RebootRequired = $Global:NeedsFinalReboot; Error = $_.Exception.Message }
        }

        # Return reboot status and success
        return @{ Success = $true; RebootRequired = $Global:NeedsFinalReboot }
    }

    try {
        $Global:ScriptJob = Start-Job -ScriptBlock $jobScriptBlock -ArgumentList $coreScriptPath, $scriptName, $mainLogDirectory -Name "WinToolkit_ScriptJob_$scriptName" -ErrorAction Stop
        $Global:LastJobOutputCount = 0 # Reset output counter for new job
        Write-UnifiedLog -Type 'Info' -Message "   Job PowerShell '$scriptName' avviato (ID: $($Global:ScriptJob.Id))." -GuiColor "#00CED1"

        # *** FIX: Riavvia JobMonitorTimer per processare output del nuovo job ***
        if ($Global:JobMonitorTimer) {
            if (-not $Global:JobMonitorTimer.IsEnabled) {
                $Global:JobMonitorTimer.Start()
                Write-UnifiedLog -Type 'Info' -Message "🔄 Timer monitoraggio riavviato." -GuiColor "#808080"
            }
        }
        # *** END FIX ***
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "❌ Errore avvio job '$scriptName': $($_.Exception.Message)." -GuiColor "#FF0000"
        Invoke-JobCompletion -JobStatus 'ErrorStarting' -JobName $scriptName
    }
}

# Funzione per processare il completamento del job
function Invoke-JobCompletion {
    param(
        [string]$JobStatus,
        [string]$JobName
    )

    # *** FIX: Separa logica UI (sincrona) da logica job launching (asincrona) ***
    $window.Dispatcher.Invoke([Action] {
            if ($Global:ScriptJob) {
                $rawOutput = Receive-Job -Job $Global:ScriptJob -ErrorAction SilentlyContinue *>&1
                $jobResultObject = $rawOutput | Where-Object { $_ -is [hashtable] -and $_.ContainsKey('RebootRequired') } | Select-Object -Last 1

                if ($jobResultObject) {
                    $Global:RebootRequired = $Global:RebootRequired -or $jobResultObject.RebootRequired
                    $finalJobOutput = $rawOutput | Where-Object { $_ -isnot [hashtable] }
                }
                else {
                    $finalJobOutput = $rawOutput
                }

                foreach ($line in ($finalJobOutput | Out-String -Stream)) {
                    [void](Format-JobOutput -Line $line)
                }
            }

            if ($JobStatus -eq 'Completed') {
                if ($Global:ScriptJob -and $Global:ScriptJob.HasErrors) {
                    $errorRecords = $Global:ScriptJob | Select-Object -ExpandProperty ChildJobs | Where-Object { $_.HasErrors } | Select-Object -ExpandProperty Error
                    $errorMessages = ($errorRecords | Select-Object -ExpandProperty Exception | Select-Object -ExpandProperty Message) -join "
"
                    if ([string]::IsNullOrEmpty($errorMessages)) {
                        $errorMessages = "Si sono verificati errori sconosciuti durante l'esecuzione dello script."
                    }
                    Write-UnifiedLog -Type 'Error' -Message "❌ $JobName completato con errori: $errorMessages." -GuiColor "#FF0000"
                }
                else {
                    Write-UnifiedLog -Type 'Success' -Message "✅ Completato: $JobName." -GuiColor "#00FF00"
                }
            }
            elseif ($JobStatus -eq 'Failed' -or $JobStatus -eq 'ErrorStarting') {
                $errorMsg = if ($Global:ScriptJob.JobStateInfo.Reason) { $Global:ScriptJob.JobStateInfo.Reason.Message } else { "Errore sconosciuto" }
                Write-UnifiedLog -Type 'Error' -Message "❌ $JobName fallito: $errorMsg." -GuiColor "#FF0000"
            }
            elseif ($JobStatus -eq 'Stopped') {
                Write-UnifiedLog -Type 'Warning' -Message "⚠️ $JobName interrotto." -GuiColor "#FFA500"
            }

            if ($Global:ScriptJob) {
                Remove-Job -Job $Global:ScriptJob -ErrorAction SilentlyContinue | Out-Null
                $Global:ScriptJob = $null
            }

            $Global:CurrentScriptIndex++
            if ($Global:SelectedScriptsQueue.Count -gt 0) {
                $progressPercentage = [int]((($Global:CurrentScriptIndex) / $Global:SelectedScriptsQueue.Count) * 100)
                if ($progressBar) { $progressBar.Value = $progressPercentage }
            }
            else {
                if ($progressBar) { $progressBar.Value = 100 }
            }
        })

    # Parte 2: Avvia prossimo job (FUORI da Dispatcher per non bloccare UI)
    if ($Global:CurrentScriptIndex -lt $Global:SelectedScriptsQueue.Count) {
        $window.Dispatcher.Invoke([Action] {
                Write-UnifiedLog -Type 'Info' -Message "⏳ Preparazione prossimo script." -GuiColor "#FFA500"
            })

        Start-Sleep -Milliseconds 200

        Start-NextScriptJob -scriptName $Global:SelectedScriptsQueue[$Global:CurrentScriptIndex]
    }
    else {
        $window.Dispatcher.Invoke([Action] {
                if ($Global:JobMonitorTimer) {
                    $Global:JobMonitorTimer.Stop()
                    $Global:JobMonitorTimer = $null
                }
                $executeButton.IsEnabled = $true
                Write-UnifiedLog -Type 'Success' -Message "🎉 $(Get-Loc 'gui.allExecuted')" -GuiColor "#00FF00"
                if ($progressBar) { $progressBar.Value = 100 }

                if ($Global:RebootRequired) {
                    $result = [System.Windows.MessageBox]::Show((Get-Loc 'gui.rebootPrompt'), (Get-Loc 'gui.rebootTitle'), [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
                    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                        Restart-Computer -Force
                    }
                }
            })
    }
    # *** END FIX ***
}

# Gestore del Tick del timer per monitorare il job
function Tick_JobMonitor {
    if ($Global:ScriptJob -and ($Global:ScriptJob.State -eq 'Running' -or $Global:ScriptJob.State -eq 'NotStarted')) {
        # Ricevi l'output disponibile in blocchi per aggiornamenti in tempo reale
        $currentJobOutput = Receive-Job -Job $Global:ScriptJob -Keep -ErrorAction SilentlyContinue *>&1

        # Processa solo le nuove linee di output
        $newOutputLines = $currentJobOutput | Select-Object -Skip $Global:LastJobOutputCount
        if ($newOutputLines.Count -gt 0) {
            # Safely invoke on Dispatcher (prevent crash if window is closing)
            try {
                if ($window -and $window.Dispatcher) {
                    $window.Dispatcher.Invoke([Action] {
                            foreach ($line in ($newOutputLines | Out-String -Stream)) {
                                [void](Format-JobOutput -Line $line)
                            }
                        })
                }
            }
            catch {
                # Ignore dispatcher errors during shutdown
            }
            $Global:LastJobOutputCount = $currentJobOutput.Count
        }
    }
    elseif ($Global:ScriptJob -and ($Global:ScriptJob.State -eq 'Completed' -or $Global:ScriptJob.State -eq 'Failed' -or $Global:ScriptJob.State -eq 'Stopped')) {
        $Global:JobMonitorTimer.Stop()
        Invoke-JobCompletion -JobStatus $Global:ScriptJob.State -JobName $Global:SelectedScriptsQueue[$Global:CurrentScriptIndex]
    }
}

# ExecuteButton Click Handler - Updated for async execution
$executeButton.Add_Click({
        # Clear previous output
        $window.Dispatcher.Invoke([Action] {
                $outputTextBox.Document.Blocks.Clear()
                $Global:LastLogParagraphRef = $null
                $Global:LastLogEntryType = $null
            })

        # Get selected scripts on UI thread - use recursive search
        $selectedScripts = @()
        $allCheckBoxes = Get-AllCheckBoxes -Container $actionsPanel

        Write-UnifiedLog -Type 'Info' -Message "🔍 Trovati $($allCheckBoxes.Count) checkbox totali." -GuiColor "#00CED1"

        foreach ($checkBox in $allCheckBoxes) {
            try {
                if ($checkBox.IsChecked -eq $true) {
                    $scriptName = $checkBox.Tag
                    if ($scriptName) {
                        $selectedScripts += $scriptName
                        Write-UnifiedLog -Type 'Info' -Message "✅ Script selezionato: $scriptName." -GuiColor "#00FF00"
                    }
                }
            }
            catch {
                Write-UnifiedLog -Type 'Warning' -Message "⚠️ Errore lettura checkbox: $($_.Exception.Message)." -GuiColor "#FFA500"
            }
        }

        if ($selectedScripts.Count -eq 0) {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ $(Get-Loc 'gui.noneSelected')" -GuiColor "#FFA500"
            $window.Dispatcher.Invoke([Action] { $executeButton.IsEnabled = $true })
            return
        }

        $Global:SelectedScriptsQueue = $selectedScripts
        $Global:CurrentScriptIndex = 0
        $Global:IsInputWaiting = $false
        $Global:RebootRequired = $false

        # Reset progress debouncer for new run
        $Global:LastLoggedProgress = @{ Percent = -1; Status = "" }

        # Inizializza e avvia il timer se non già attivo
        if (-not $Global:JobMonitorTimer) {
            $Global:JobMonitorTimer = New-Object System.Windows.Threading.DispatcherTimer
            $Global:JobMonitorTimer.Interval = New-Object System.TimeSpan (0, 0, 0, 0, 500) # 500ms
            $Global:JobMonitorTimer.Add_Tick({ Tick_JobMonitor })
        }
        $Global:JobMonitorTimer.Start()

        # Avvia il primo script
        Start-NextScriptJob -scriptName $Global:SelectedScriptsQueue[$Global:CurrentScriptIndex]
    })

# Add SendErrorLogs button click handler
$SendErrorLogsButton.Add_Click({
        try {
            Send-ErrorLogs
        }
        catch {
            Write-UnifiedLog -Type 'Error' -Message "❌ Errore invio log: $($_.Exception.Message)." -GuiColor "#FF0000"
        }
    })

# =============================================================================
# CONSOLE MINIMIZATION HELPER
# =============================================================================

function Set-ConsoleWindowMinimized {
    <#
    .SYNOPSIS
        Minimizza la finestra della console PowerShell.
    #>
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WindowHelper {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public const int SW_MINIMIZE = 2;

    public static void Minimize() {
        IntPtr handle = System.Diagnostics.Process.GetCurrentProcess().MainWindowHandle;
        if (handle != IntPtr.Zero) {
            ShowWindow(handle, SW_MINIMIZE);
        }
    }
}
"@ -ReferencedAssemblies System.Windows.Forms

        [WindowHelper]::Minimize()
        Write-Host "Console minimized." -ForegroundColor Cyan
    }
    catch {
        Write-Host "Could not minimize console (non-critical)." -ForegroundColor Yellow
    }
}

# =============================================================================
# INITIALIZATION AND DISPLAY
# =============================================================================

# Update system info and generate menu AFTER window is loaded to prevent handle exhaustion
$window.Add_Loaded({
        try {
            # Update system info
            Update-SystemInformationPanel

            # Generate dynamic menu
            Update-ActionsPanel

            # Show initial log message
            Write-UnifiedLog -Type 'Success' -Message "🎉 $(Get-Loc 'gui.initialized')" -GuiColor "#00FF00"
            Write-UnifiedLog -Type 'Info' -Message "📌 Core Version: $Global:CoreScriptVersion." -GuiColor "#00CED1"
            Write-UnifiedLog -Type 'Info' -Message "💡 $(Get-Loc 'gui.instructions')" -GuiColor "#00CED1"

            # Minimize console - DISABLED to prevent handle exhaustion crash (Win32Exception 1816)
            # Set-ConsoleWindowMinimized
        }
        catch {
            Write-UnifiedLog -Type 'Error' -Message "❌ Errore durante inizializzazione Loaded: $($_.Exception.Message)." -GuiColor "#FF0000"
        }
    })

# Cleanup handler for Window Closing to kill running jobs
$window.Add_Closing({
        if ($Global:ScriptJob) {
            Write-UnifiedLog -Type 'Info' -Message "🚨 Finestra GUI chiusa. Tentativo di fermare il job in corso." -GuiColor "#FFA500"
            try {
                Stop-Job -Job $Global:ScriptJob -Force -ErrorAction SilentlyContinue | Out-Null
                Remove-Job -Job $Global:ScriptJob -Force -ErrorAction SilentlyContinue | Out-Null
                $Global:ScriptJob = $null
                Write-UnifiedLog -Type 'Success' -Message "✅ Job in corso fermato e rimosso." -GuiColor "#00FF00"
            }
            catch {
                Write-UnifiedLog -Type 'Error' -Message "❌ Errore durante l'interruzione del job: $($_.Exception.Message)." -GuiColor "#FF0000"
            }
        }
        if ($Global:JobMonitorTimer) {
            $Global:JobMonitorTimer.Stop()
            $Global:JobMonitorTimer = $null
        }
        try {
            Stop-Transcript -ErrorAction SilentlyContinue
        }
        catch {}
    })

# Show window
$window.ShowDialog() | Out-Null

# Cleanup on exit
try {
    Stop-Transcript -ErrorAction SilentlyContinue
}
catch {}
