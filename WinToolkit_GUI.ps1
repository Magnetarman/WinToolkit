<#
.SYNOPSIS
    WinToolkit GUI v2.0
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
$Global:GuiVersion = "2.5.1 (Build 90)"  # Format: CoreVersion.GuiBuildNumber

# =============================================================================
# CONFIGURATION AND CONSTANTS
# =============================================================================
$ScriptTitle = "WinToolkit By MagnetarMan"
$LogDirectory = "$env:LOCALAPPDATA\WinToolkit\logs"
$WindowWidth = 1600  # Increased from 1500 for better readability
$WindowHeight = 1000  # Increased from 950 for better readability
$FontFamily = "JetBrains Mono Nerd Font, Cascadia Code, Consolas, Courier New"
$FontSize = @{Small = 14; Medium = 16; Large = 18; Title = 20 }

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
$localIconBasePath = Join-Path $env:LOCALAPPDATA "WinToolkit\asset\png"
$remoteIconBasePath = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/png"

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

# =============================================================================
# LOGGING AND UTILITY FUNCTIONS
# =============================================================================

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
        Write-UnifiedLog -Type 'Info' -Message "💎 INIZIALIZZAZIONE RISORSE - Caricamento Core Script..." -GuiColor "#00CED1"
        Write-UnifiedLog -Type 'Info' -Message "💎 Attendere prego, operazione in corso..." -GuiColor "#FFA500"

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
                        Write-UnifiedLog -Type 'Info' -Message "📌 Versione Core locale trovata: $localCoreFullVersion (Numerica: $localCoreNumericVersion)" -GuiColor "#00CED1"
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
                Write-UnifiedLog -Type 'Warning' -Message "⚠️ Errore lettura versione cache locale: $($_.Exception.Message)" -GuiColor "#FFA500"
            }
        }

        # 2. Recupera la versione del Core Script remoto
        $remoteCoreNumericVersion = [version]"0.0.0"
        $remoteCoreFullVersion = "Unknown"
        Write-UnifiedLog -Type 'Info' -Message "📡 Recupero versione Core Script remota..." -GuiColor "#00CED1"
        try {
            # Usa Invoke-RestMethod per ottenere il contenuto completo per un parsing robusto
            $remoteRawContent = Invoke-RestMethod -Uri $Global:CoreConfig.RemoteUrl -UseBasicParsing -ErrorAction Stop
            if ($remoteRawContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
                $remoteCoreFullVersion = $matches[1]
                if ($remoteCoreFullVersion -match '(\d+(?:\.\d+){0,3})') {
                    $remoteCoreNumericVersion = [version]$matches[1]
                    Write-UnifiedLog -Type 'Info' -Message "📌 Versione Core remota rilevata: $remoteCoreFullVersion (Numerica: $remoteCoreNumericVersion)" -GuiColor "#00CED1"
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
            Write-UnifiedLog -Type 'Info' -Message "⬆️ Nuova versione Core ($remoteCoreFullVersion) disponibile (attuale: $localCoreFullVersion). Download in corso..." -GuiColor "#00CED1"
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
            Write-UnifiedLog -Type 'Info' -Message "📡 Download Core Script da GitHub..." -GuiColor "#00CED1"
            Write-UnifiedLog -Type 'Info' -Message "🌐 URL: $($Global:CoreConfig.RemoteUrl)" -GuiColor "#808080"

            try {
                $downloadParams = @{
                    Uri             = $Global:CoreConfig.RemoteUrl
                    OutFile         = $Global:CoreConfig.LocalCachePath
                    UseBasicParsing = $true
                    ErrorAction     = 'Stop'
                }

                Invoke-WebRequest @downloadParams
                $coreContent = Get-Content $Global:CoreConfig.LocalCachePath -Raw -Encoding UTF8
                Write-UnifiedLog -Type 'Success' -Message "✅ Core Script scaricato con successo" -GuiColor "#00FF00"
                Write-UnifiedLog -Type 'Info' -Message "💾 Salvato in cache: $($Global:CoreConfig.LocalCachePath)" -GuiColor "#00CED1"
                
                # Estrai versione dal Core appena scaricato (stringa completa per display)
                if ($coreContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
                    $Global:CoreScriptVersion = $matches[1]
                    Write-UnifiedLog -Type 'Success' -Message "📌 Versione Core scaricata: $Global:CoreScriptVersion" -GuiColor "#00FF00"
                }
                else {
                    Write-UnifiedLog -Type 'Warning' -Message "⚠️ Impossibile estrarre versione dal Core appena scaricato." -GuiColor "#FFA500"
                    $Global:CoreScriptVersion = "Unknown"
                }

            }
            catch {
                Write-UnifiedLog -Type 'Warning' -Message "⚠️ Download fallito: $($_.Exception.Message)" -GuiColor "#FFA500"

                if ($cacheExists -and $Global:CoreConfig.FallbackToCache) {
                    Write-UnifiedLog -Type 'Info' -Message "📂 Utilizzo cache locale (scaduta o meno recente, ma disponibile) come fallback..." -GuiColor "#FFA500"
                    $coreContent = Get-Content $Global:CoreConfig.LocalCachePath -Raw -Encoding UTF8
                    $usedCache = $true
                    # Ri-estrai la versione dalla cache come fallback
                    if ($coreContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
                        $Global:CoreScriptVersion = $matches[1]
                        Write-UnifiedLog -Type 'Success' -Message "📌 Versione Core da cache fallback: $Global:CoreScriptVersion" -GuiColor "#00FF00"
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
            throw "Core Script content è vuoto dopo i tentativi di caricamento."
        }

        # NOTE: Loading moved to main scope to fix variable visibility
        $Global:CoreScriptContent = $coreContent
        $Global:CoreScriptLoaded = $true

        Write-UnifiedLog -Type 'Success' -Message "🎉 INIZIALIZZAZIONE COMPLETATA - GUI pronta all'uso" -GuiColor "#00FF00"
        Write-Host ""

        return $true
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "❌ ERRORE CRITICO durante caricamento Core: $($_.Exception.Message)" -GuiColor "#FF0000"
        Write-UnifiedLog -Type 'Info' -Message "💡 Suggerimento: Scarica manualmente WinToolkit.ps1 da:" -GuiColor "#00CED1"
        Write-UnifiedLog -Type 'Info' -Message "   $($Global:CoreConfig.RemoteUrl)" -GuiColor "#808080"
        Write-UnifiedLog -Type 'Info' -Message "   e salvalo in: $($Global:CoreConfig.LocalCachePath)" -GuiColor "#808080"

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

function Ensure-AllEmojiIcons {
    param(
        [Parameter(Mandatory = $true)][hashtable]$EmojiMap,
        [Parameter(Mandatory = $true)][string]$LocalPath,
        [Parameter(Mandatory = $true)][string]$RemotePath
    )
    Write-UnifiedLog -Type 'Info' -Message "🚀 Ensuring all required icons are available locally..." -GuiColor "#00CED1"
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

                Write-UnifiedLog -Type 'Info' -Message "📥 Downloading icon for '$emojiChar' from $remoteIconUri..." -GuiColor "#00CED1"
                try {
                    Invoke-WebRequest -Uri $remoteIconUri -OutFile $localIconFile -UseBasicParsing -ErrorAction Stop | Out-Null
                    Write-UnifiedLog -Type 'Success' -Message "✅ Downloaded: $fileName" -GuiColor "#00FF00"
                }
                catch {
                    Write-UnifiedLog -Type 'Error' -Message "❌ Failed to download icon '$fileName': $($_.Exception.Message)" -GuiColor "#FF0000"
                }
            }
        }
        Write-UnifiedLog -Type 'Success' -Message "🎉 Icon availability check completed." -GuiColor "#00FF00"
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "❌ Error during icon synchronization: $($_.Exception.Message)" -GuiColor "#FF0000"
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
        Write-UnifiedLog -Type 'Info' -Message "📦 Preparazione log errori GUI per la segnalazione..." -GuiColor "#00CED1"
        
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
        
        # Crea il contenuto combinato dei log
        $logContent = "=" * 60 + "`n"
        $logContent += "WinToolkit GUI Error Report`n"
        $logContent += "Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
        $logContent += "Versione GUI: $Global:GuiVersion`n"
        $logContent += "Versione Core: $Global:CoreScriptVersion`n"
        $logContent += "=" * 60 + "`n`n"
        
        foreach ($logFile in $recentLogFiles) {
            $logContent += "--- $($logFile | Split-Path -Leaf) ---`n"
            $logContent += (Get-Content -Path $logFile -ErrorAction SilentlyContinue -Raw)
            $logContent += "`n`n"
        }
        
        # Salva il report temporaneo
        $tempReportPath = Join-Path $env:TEMP "WinToolkit_GUI_ErrorReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $logContent | Out-File -FilePath $tempReportPath -Encoding UTF8 -Force
        
        # Comprimi il report in ZIP sul Desktop
        $zipPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "WinToolkit_GUI_ErrorReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
        if (Get-Command 'Compress-Archive' -ErrorAction SilentlyContinue) {
            Compress-Archive -Path $tempReportPath -DestinationPath $zipPath -Force
            Write-UnifiedLog -Type 'Success' -Message "✅ Report errori GUI compresso: $zipPath" -GuiColor "#00FF00"
        }
        else {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Compress-Archive non disponibile. Report GUI salvato in: $tempReportPath" -GuiColor "#FFA500"
            $zipPath = $tempReportPath # Se non si può zippare, usa il percorso del .txt per il messaggio finale
        }

        # Elimina il report temporaneo se è stato zippato con successo
        if (Test-Path $tempReportPath -PathType Leaf) {
            Remove-Item $tempReportPath -ErrorAction SilentlyContinue
        }
        
        # Apri il browser predefinito alla pagina GitHub Issues
        try {
            Start-Process -FilePath "https://github.com/Magnetarman/WinToolkit/issues/new"
            Write-UnifiedLog -Type 'Info' -Message "🌐 Browser aperto per la segnalazione su GitHub" -GuiColor "#00CED1"
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Impossibile aprire il browser: $($_.Exception.Message)" -GuiColor "#FFA500"
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
        Write-UnifiedLog -Type 'Error' -Message "❌ Errore durante la preparazione dei log GUI: $($_.Exception.Message)" -GuiColor "#FF0000"
    }
}

# =============================================================================
# LOAD ALL TOOL SCRIPTS INTO GLOBAL SCOPE (before any job execution)
# =============================================================================
# NOTE: This section has been removed. All tool functions are now defined
# in the Core Script (WinToolkit.ps1) and are loaded when the Core Script
# is dot-sourced. The job now only needs to load the Core Script to access
# all tool functions.
# $Global:ToolScriptsPath = Join-Path $PSScriptRoot "tool"

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
    Write-Host "[INFO] Logging initialized to $mainLog" -ForegroundColor Cyan
}
catch {
    Write-Host "[ERROR] Failed to initialize logging. $($_.Exception.Message)" -ForegroundColor Red
}

# Create icon cache directory
try {
    if (-not (Test-Path $localIconBasePath)) {
        [System.IO.Directory]::CreateDirectory($localIconBasePath) | Out-Null
    }
}
catch {
    Write-Host "[ERROR] Failed to create icon directory: $($_.Exception.Message)" -ForegroundColor Red
}

# Download and cache all required icons
Ensure-AllEmojiIcons -EmojiMap $emojiMappings -LocalPath $localIconBasePath -RemotePath $remoteIconBasePath

# Check administrator privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Administrator privileges required" -ForegroundColor Red
    exit
}

Write-Host "[INFO] Administrator privileges confirmed" -ForegroundColor Green

# Load WPF assemblies
$assemblies = @("PresentationFramework", "PresentationCore", "WindowsBase", "System.Windows.Forms")
foreach ($assembly in $assemblies) {
    try {
        Add-Type -AssemblyName $assembly -ErrorAction Stop
        Write-Host "[SUCCESS] Loaded: $assembly" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to load: $assembly - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ==========================================
# INITIALIZE CORE SCRIPT (CRITICAL STEP)
# ==========================================

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  WinToolkit GUI v2.0 - GUI Edition" -ForegroundColor White
Write-Host "  Loading Core Script..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

$coreLoaded = Initialize-CoreScript

if (-not $coreLoaded) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  FATAL ERROR: Core Script loading failed" -ForegroundColor Red
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
    Write-UnifiedLog -Type 'Info' -Message "🔌 Caricamento funzioni Core in memoria (Global Scope)..." -GuiColor "#00CED1"
    
    # Dot-sourcing nel scope corrente (Script/Global)
    # Usa il path locale assicurato da Initialize-CoreScript
    . $Global:CoreConfig.LocalCachePath
    
    # Recupera $menuStructure dopo il caricamento
    if ($menuStructure) {
        $Global:MenuStructure = $menuStructure
        Write-UnifiedLog -Type 'Success' -Message "✅ Struttura del menu caricata (categorie: $($Global:MenuStructure.Count))" -GuiColor "#00FF00"
    }
    else {
        Write-UnifiedLog -Type 'Warning' -Message "⚠️ \$menuStructure non trovato dopo il caricamento" -GuiColor "#FFA500"
    }
    
    # Verifica funzioni critiche
    if (Get-Command 'Get-SystemInfo' -ErrorAction SilentlyContinue) {
        Write-UnifiedLog -Type 'Success' -Message "✅ Funzione Get-SystemInfo disponibile" -GuiColor "#00FF00"
    }
    else {
        Write-UnifiedLog -Type 'Error' -Message "❌ Funzione Get-SystemInfo NON trovata!" -GuiColor "#FF0000"
    }

}
catch {
    Write-UnifiedLog -Type 'Error' -Message "❌ Errore durante dot-sourcing Core: $($_.Exception.Message)" -GuiColor "#FF0000"
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
                       Source="/img/WinToolkit-icon.png"
                       Width="48" Height="48" 
                       VerticalAlignment="Center" Margin="0,0,16,0"/>
                
                <!-- Colonna 1: Titolo e Sottotitolo centrati -->
                <StackPanel Grid.Column="1" VerticalAlignment="Center" HorizontalAlignment="Center">
                    <TextBlock Text="$($ScriptTitle)" 
                               FontSize="28" FontWeight="Bold" 
                               Foreground="{StaticResource TextColor}" 
                               FontFamily="{StaticResource PrimaryFont}"
                               TextAlignment="Center"/>
                    <TextBlock Text="GUI Edition v$($Global:GuiVersion) | Core v$($Global:CoreScriptVersion)" 
                               FontSize="16" FontWeight="Normal"
                               Foreground="{StaticResource LabelBlue}" 
                               FontFamily="{StaticResource PrimaryFont}"
                               TextAlignment="Center" Margin="0,4,0,0"/>
                </StackPanel>
                
                <!-- Colonna 2: Pulsante Invia Log Errori (Rosso) - DIMENSIONI RIDOTTE (0.5x) -->
                <Button Grid.Column="2" x:Name="SendErrorLogsButton" 
                        VerticalAlignment="Center" HorizontalAlignment="Right"
                        Background="{StaticResource ErrorButtonColor}" 
                        Foreground="{StaticResource TextColor}"
                        Padding="20,12" BorderThickness="0" Cursor="Hand" 
                        Margin="16,0,0,0" Style="{StaticResource SmallButtonStyle}">
                    <StackPanel Orientation="Horizontal">
                        <Image x:Name="SendErrorLogsImage" Width="28" Height="28" Margin="0,0,8,0"/>
                        <TextBlock Text="Invia Log Errori" VerticalAlignment="Center" 
                                   FontFamily="{StaticResource PrimaryFont}" FontWeight="SemiBold" FontSize="11"/>
                    </StackPanel>
                </Button>
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
                    <TextBlock Text="▬▬ INFORMAZIONI SISTEMA ▬▬" 
                               Foreground="{StaticResource LabelBlue}" 
                               FontSize="14" FontWeight="Bold" 
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
                            <TextBlock Text="Edizione Windows:" Foreground="{StaticResource LabelBlue}" 
                                       FontSize="14" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoEdition" Text="Caricamento..." 
                                   Foreground="{StaticResource TextColor}" FontSize="14" 
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
                            <TextBlock Text="Versione:" Foreground="{StaticResource LabelBlue}" 
                                       FontSize="14" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoVersion" Text="Caricamento..." 
                                   Foreground="{StaticResource TextColor}" FontSize="14" 
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
                            <TextBlock Text="Architettura:" Foreground="{StaticResource LabelBlue}" 
                                       FontSize="14" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoArchitecture" Text="Caricamento..." 
                                   Foreground="{StaticResource TextColor}" FontSize="14" 
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
                            <TextBlock Text="Funzionalità Script" 
                                       Foreground="{StaticResource LabelBlue}" 
                                       FontSize="14" FontWeight="Bold" 
                                       FontFamily="{StaticResource PrimaryFont}" 
                                       VerticalAlignment="Center"/>
                            <TextBlock x:Name="SysInfoScriptCompatibility" Text="Verifica..." 
                                       Foreground="{StaticResource TextColor}" FontSize="14" 
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
                            <TextBlock Text="Stato Bitlocker" 
                                       Foreground="{StaticResource LabelBlue}" 
                                       FontSize="14" FontWeight="Bold" 
                                       FontFamily="{StaticResource PrimaryFont}" 
                                       VerticalAlignment="Center" Margin="0,0,8,0"/>
                            <TextBlock x:Name="SysInfoBitlocker" Text="Verifica..." 
                                       Foreground="{StaticResource TextColor}" FontSize="14" 
                                       FontFamily="{StaticResource PrimaryFont}" 
                                       VerticalAlignment="Center"/>
                        </StackPanel>
                    </Grid>
                </StackPanel>
                
                <!-- Separatore Verde Verticale 2: Tra Funzionalità Script e Hardware -->
                <Border Grid.Column="3" Width="3" Background="{StaticResource SeparatorGreen}" 
                        VerticalAlignment="Stretch" Margin="15,5"/>
                
                <!-- Blocco 3: Hardware Info (Allineamento speculare al blocco 1) -->
                <StackPanel Grid.Column="4" Margin="20,0,0,0">
                    <TextBlock Text="▬▬ HARDWARE ▬▬" 
                               Foreground="{StaticResource LabelBlue}" 
                               FontSize="14" FontWeight="Bold" 
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
                            <TextBlock Text="Nome PC:" Foreground="{StaticResource LabelBlue}" 
                                       FontSize="14" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoComputerName" Text="Caricamento..." 
                                   Foreground="{StaticResource TextColor}" FontSize="14" 
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
                            <TextBlock Text="RAM:" Foreground="{StaticResource LabelBlue}" 
                                       FontSize="14" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoRAM" Text="Caricamento..." 
                                   Foreground="{StaticResource TextColor}" FontSize="14" 
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
                            <TextBlock Text="Disco:" Foreground="{StaticResource LabelBlue}" 
                                       FontSize="14" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Grid.Column="1" x:Name="SysInfoDisk" Text="Caricamento..." 
                                   Foreground="{StaticResource TextColor}" FontSize="14" 
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
                        <TextBlock Text="Funzioni Disponibili" 
                                   Foreground="{StaticResource TextColor}" FontSize="18" 
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
                        <TextBlock Text="Output e Log" 
                                   Foreground="{StaticResource TextColor}" FontSize="18" 
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
                                 FontSize="14"/>
                </Grid>
            </Border>
        </Grid>

        <!-- Task 5: Footer con pulsante Esegui pill-shaped (CornerRadius 20+) -->
        <Border Grid.Row="3" Background="{StaticResource HeaderBackgroundColor}" 
                Padding="16" Margin="16,8,16,16" CornerRadius="12">
            <StackPanel>
                <!-- ProgressBar visibile con altezza 20 e colore azzurro vivido -->
                <ProgressBar x:Name="MainProgressBar"
                             Height="20"
                             Margin="0,0,0,12"
                             Background="{StaticResource PanelBackgroundColor}"
                             BorderBrush="{StaticResource SeparatorGreen}"
                             Foreground="#2196F3"
                             Minimum="0"
                             Maximum="100"
                             Value="0"/>

                <!-- Pulsante Esegui centrato, pill-shaped (CornerRadius 25), azzurro -->
                <Button x:Name="ExecuteButton"
                        Background="{StaticResource ExecuteButtonColor}"
                        Foreground="{StaticResource TextColor}"
                        FontSize="18"
                        FontWeight="Bold"
                        FontFamily="{StaticResource PrimaryFont}"
                        Padding="48,18"
                        BorderThickness="0"
                        HorizontalAlignment="Center"
                        Cursor="Hand"
                        Style="{StaticResource PillButtonStyle}">
                    <StackPanel Orientation="Horizontal">
                        <Image x:Name="ExecuteButtonImage" Width="20" Height="20" Margin="0,0,8,0"/>
                        <TextBlock Text="Esegui Script" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
            </StackPanel>
        </Border>
    </Grid>
</Window>
"@

# Create window
try {
    Write-UnifiedLog -Type 'Info' -Message "Creating WPF window..." -GuiColor "#00CED1"
    $window = [Windows.Markup.XamlReader]::Parse($xaml)
    Write-UnifiedLog -Type 'Success' -Message "Window created successfully" -GuiColor "#00FF00"
}
catch {
    Write-UnifiedLog -Type 'Error' -Message "Failed to create window: $($_.Exception.Message)" -GuiColor "#FF0000"
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
$SysInfoBitlocker = $window.FindName("SysInfoBitlocker")
$ScriptStatusIcon = $window.FindName("ScriptStatusIcon")
$BitlockerImage = $window.FindName("BitlockerImage")
$SysInfoEditionImage = $window.FindName("SysInfoEditionImage")
$SysInfoVersionImage = $window.FindName("SysInfoVersionImage")
$SysInfoArchitectureImage = $window.FindName("SysInfoArchitectureImage")
$SysInfoComputerNameImage = $window.FindName("SysInfoComputerNameImage")
$SysInfoRAMImage = $window.FindName("SysInfoRAMImage")
$SysInfoDiskImage = $window.FindName("SysInfoDiskImage")
$SendErrorLogsButton = $window.FindName("SendErrorLogsButton")
$SendErrorLogsImage = $window.FindName("SendErrorLogsImage")
$ToolIconImage = $window.FindName("ToolIconImage")
$ExecuteButtonImage = $window.FindName("ExecuteButtonImage")
$CategorySystemImage = $window.FindName("CategorySystemImage")
$OutputLogImage = $window.FindName("OutputLogImage")
$progressBar = $window.FindName("MainProgressBar")

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
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not load ExecuteButton icon" -GuiColor "#FFA500"
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
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not load CategorySystem icon" -GuiColor "#FFA500"
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
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not load OutputLog icon" -GuiColor "#FFA500"
        }
    }
    
    Write-UnifiedLog -Type 'Success' -Message "✅ ExecuteButton configurato con stile pill-shaped e icona Play" -GuiColor "#00FF00"
}
catch {
    Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not configure ExecuteButton" -GuiColor "#FFA500"
}

# =============================================================================
# SYSTEM INFORMATION UPDATE (Using Core's Get-SystemInfo) - Task 2
# =============================================================================

function Update-SystemInformationPanel {
    try {
        # Use Core's Get-SystemInfo function
        $sysInfo = Get-SystemInfo

        if (-not $sysInfo) {
            Write-UnifiedLog -Type 'Error' -Message "Failed to retrieve system information from Core" -GuiColor "#FF0000"
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
                $SysInfoDisk.Text = "$($sysInfo.FreePercentage)% Libero ($($sysInfo.FreeDisk) GB / $($sysInfo.TotalDisk) GB)"

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
                    Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not load some icons: $($_.Exception.Message)" -GuiColor "#FFA500"
                }

                # Task 2: Compatibility indicator con status text colorato
                $statusText = ""
            
                if ($sysInfo.BuildNumber -ge 22000) {
                    $statusText = "Completa"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                }
                elseif ($sysInfo.BuildNumber -ge 17763) {
                    $statusText = "Completa"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                }
                elseif ($sysInfo.BuildNumber -ge 10240) {
                    $statusText = "Limitata"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Orange)
                }
                else {
                    $statusText = "Non supportata"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Red)
                }
            
                $SysInfoScriptCompatibility.Text = $statusText
            
                # Aggiorna stato Bitlocker
                try {
                    $blStatus = CheckBitlocker
                    $SysInfoBitlocker.Text = $blStatus
                    
                    # Colorazione status Bitlocker (verde/giallo/rosso) basato sulla stringa returned
                    if ($blStatus -match '(?i)(attiv|protezione|crittograf|completa)') {
                        $SysInfoBitlocker.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                    }
                    elseif ($blStatus -match '(?i)(sospesa|parzial|in corso)') {
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
                    Write-UnifiedLog -Type 'Warning' -Message "⚠️ Could not check Bitlocker status: $($_.Exception.Message)" -GuiColor "#FFA500"
                }
            })

        Write-UnifiedLog -Type 'Success' -Message "System information panel updated (3-block layout)" -GuiColor "#00FF00"
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "Error updating system information: $($_.Exception.Message)" -GuiColor "#FF0000"
    }
}

# =============================================================================
# DYNAMIC MENU GENERATION (From Core's $menuStructure)
# =============================================================================

function Update-ActionsPanel {
    try {
        Write-UnifiedLog -Type 'Info' -Message "🔄 Generating dynamic menu from Core \$menuStructure..." -GuiColor "#00CED1"

        $window.Dispatcher.Invoke([Action] {
                $actionsPanel.Children.Clear()

                if ($Global:MenuStructure.Count -eq 0) {
                    Write-UnifiedLog -Type 'Warning' -Message "⚠️ \$menuStructure is empty, using fallback static menu" -GuiColor "#FFA500"
                    return
                }

                $isFirstCategory = $true

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
                        $categoryEmoji.FontSize = 18
                        $categoryEmoji.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
                        $categoryEmoji.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                        $categoryEmoji.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::White)
                    }
                    $categoryContainer.Children.Add($categoryEmoji) | Out-Null
                
                    # Category Name (Bold, Cyan)
                    $categoryHeader = New-Object System.Windows.Controls.TextBlock
                    $categoryHeader.Text = $category.Name
                    $categoryHeader.FontSize = 14
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
                        $titleRun.Text = $script.Name
                        $titleRun.FontWeight = [System.Windows.FontWeights]::Bold
                        $titleRun.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::White)
                    
                        # Separator (Gray #BDBDBD)
                        $separatorRun = New-Object System.Windows.Documents.Run
                        $separatorRun.Text = " - "
                        $separatorRun.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#BDBDBD"))
                    
                        # Description (Gray #BDBDBD)
                        $descRun = New-Object System.Windows.Documents.Run
                        $descRun.Text = $script.Description
                        $descRun.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#BDBDBD"))
                    
                        $textBlock.Inlines.Add($titleRun)
                        $textBlock.Inlines.Add($separatorRun)
                        $textBlock.Inlines.Add($descRun)
                        $scriptRow.Children.Add($textBlock) | Out-Null
                    
                        $actionsPanel.Children.Add($scriptRow) | Out-Null
                    }
                }

                Write-UnifiedLog -Type 'Success' -Message "✅ Dynamic menu generated: $($Global:MenuStructure.Count) categories" -GuiColor "#00FF00"
            })
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "❌ Error generating dynamic menu: $($_.Exception.Message)" -GuiColor "#FF0000"
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
function Filter-AndFormatJobOutput {
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
    
    # Handle WINTOOLKIT_PROGRESS_TAG
    if ($Line -match '\[WINTOOLKIT_PROGRESS_TAG\].*Percent:\s*(?<Percent>\d+)%') {
        $percent = [int]$matches.Percent
        
        # Log version of progress to OutputTextBox (periodicity to avoid spam)
        if ($Line -match 'Activity:\s*(?<Activity>[^|]+)\| Status:\s*(?<Status>[^|]+)') {
            $activity = $matches.Activity.Trim()
            $status = $matches.Status.Trim()
            # Log to textbox for major milestones
            if ($percent % 25 -eq 0 -or $percent -eq 100) {
                Write-UnifiedLog -Type 'Progress' -Message "🔄 [$activity] $status ($percent%)" -GuiColor "#2196F3"
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

    Write-UnifiedLog -Type 'Info' -Message "🚀 Avvio esecuzione: $scriptName" -GuiColor "#00CED1"
    
    # Define paths needed by the job
    $coreScriptPath = $Global:CoreConfig.LocalCachePath
    $mainLogDirectory = $LogDirectory
    
    Write-UnifiedLog -Type 'Info' -Message "   Core for job: $coreScriptPath" -GuiColor "#808080"
    
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
            Write-Error "Failed to dot-source Core script within job: $($_.Exception.Message)"
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
            Write-Output "[WINTOOLKIT_COUNTDOWN_BYPASS_TAG] Message: $Message | Seconds: $Seconds" # Tag per la GUI
            return $true 
        }

        # Shim Get-UserConfirmation to always confirm actions, preventing user interaction.
        function Get-UserConfirmation {
            param([string]$Message, [string]$DefaultChoice = 'N')
            Write-Debug "[GUI_SHIM] User confirmation bypassed for: '$Message'. Returning 'Yes'."
            Write-Output "[WINTOOLKIT_CONFIRMATION_BYPASS_TAG] Message: $Message" # Tag per la GUI
            return $true # Assume 'Yes' for all user confirmations in GUI mode.
        }

        # Shim Show-Header to prevent raw console output (ASCII art, direct window size checks).
        function Show-Header {
            param([string]$SubTitle = "Menu Principale")
            Write-Debug "[GUI_SHIM] Intestazione: WinToolkit - $SubTitle (bypassed direct console output)"
            Write-Output "[WINTOOLKIT_STYLED_MESSAGE_TAG] Info`: HEADER: $SubTitle" # Invia come messaggio stilizzato per la GUI
        }

        # Shim Write-StyledMessage to redirect styled messages from Core to Write-Output with tags
        function Write-StyledMessage {
            param(
                [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Progress')][string]$Type,
                [string]$Text
            )
            # Output with tagged format for GUI parsing
            Write-Output "[WINTOOLKIT_STYLED_MESSAGE_TAG] $Type`: $Text"
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
            # Output with tagged format for GUI parsing (removed throttling)
            Write-Output "[WINTOOLKIT_PROGRESS_TAG] Activity: $Activity | Status: $Status | Percent: $($intPercent)% | Icon: $Icon | Spinner: $Spinner"
        }

        # Shim Write-Progress to redirect standard PowerShell progress to the GUI
        function Write-Progress {
            param(
                [Parameter(Mandatory=$true)][string]$Activity,
                [string]$Status = "",
                [int]$PercentComplete = -1,
                [switch]$Completed
            )
            if ($Completed) {
                Write-Output "[WINTOOLKIT_PROGRESS_TAG] Activity: $Activity | Status: Completato | Percent: 100%"
            }
            elseif ($PercentComplete -ge 0) {
                Write-Output "[WINTOOLKIT_PROGRESS_TAG] Activity: $Activity | Status: $Status | Percent: $($PercentComplete)%"
            }
        }

        # Shim Write-Host - uses Write-Debug for internal messages, outputs via tag for styled content
        function Write-Host {
            param(
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object] $Object,
                [string] $Separator = " ",
                [string] $ForegroundColor,
                [string] $BackgroundColor,
                [switch] $NoNewline
            )
            
            process {
                # Use $Object to handle direct calls; handle pipeline via $_ if $Object is null (though Mandatory=$true prevents this)
                $target = if ($null -ne $Object) { $Object } else { $_ }
                $output = ($target | Out-String).TrimEnd("`r`n")
                
                if (-not [string]::IsNullOrEmpty($output)) {
                    # If it's already a tagged message, don't double tag it
                    if ($output -match '^\[WINTOOLKIT_.*_TAG\]') {
                        Write-Output $output
                    }
                    else {
                        Write-Output "[WINTOOLKIT_RAW_HOST_OUTPUT_TAG]$output"
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
            Write-Error "Cannot get parameters for function '$CmdName': $($_.Exception.Message)"
            $Global:NeedsFinalReboot = $false
            return @{ Success = $false; RebootRequired = $Global:NeedsFinalReboot; Error = $_.Exception.Message }
        }

        # Execute the function. Redirect all streams to capture everything.
        try {
            if (Get-Command $CmdName -ErrorAction SilentlyContinue) {
                $Global:NeedsFinalReboot = $false 
                Invoke-Expression ("& $CmdName $($argsToPass -join ' ') *>&1")
            }
            else {
                Write-Error "Function '$CmdName' not found after dot-sourcing within job."
                $Global:NeedsFinalReboot = $false
                return @{ Success = $false; RebootRequired = $Global:NeedsFinalReboot; Error = "Function not found." }
            }
        }
        catch {
            Write-Error "Error executing function '$CmdName' within job: $($_.Exception.Message)"
            $Global:NeedsFinalReboot = $false
            return @{ Success = $false; RebootRequired = $Global:NeedsFinalReboot; Error = $_.Exception.Message }
        }
        
        # Return reboot status and success
        return @{ Success = $true; RebootRequired = $Global:NeedsFinalReboot }
    }

    try {
        $Global:ScriptJob = Start-Job -ScriptBlock $jobScriptBlock -ArgumentList $coreScriptPath, $scriptName, $mainLogDirectory -Name "WinToolkit_ScriptJob_$scriptName" -ErrorAction Stop
        $Global:LastJobOutputCount = 0 # Reset output counter for new job
        Write-UnifiedLog -Type 'Info' -Message "   Job PowerShell '$scriptName' avviato (ID: $($Global:ScriptJob.Id))" -GuiColor "#00CED1"
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "❌ Errore avvio job '$scriptName': $($_.Exception.Message)" -GuiColor "#FF0000"
        Process-JobCompletion -JobStatus 'ErrorStarting' -JobName $scriptName
    }
}

# Funzione per processare il completamento del job
function Process-JobCompletion {
    param(
        [string]$JobStatus, # 'Completed', 'Failed', 'Stopped', 'ErrorStarting' (custom)
        [string]$JobName
    )

    $window.Dispatcher.Invoke([Action] {
            # Ricevi l'output finale del job se esiste
            $jobResults = $null
            if ($Global:ScriptJob) {
                $rawOutput = Receive-Job -Job $Global:ScriptJob -ErrorAction SilentlyContinue *>&1
                # Cerca l'oggetto risultato se presente
                $jobResultObject = $rawOutput | Where-Object { $_ -is [hashtable] -and $_.ContainsKey('RebootRequired') } | Select-Object -Last 1
                
                if ($jobResultObject) {
                    $Global:RebootRequired = $Global:RebootRequired -or $jobResultObject.RebootRequired
                    $finalJobOutput = $rawOutput | Where-Object { $_ -isnot [hashtable] }
                }
                else {
                    $finalJobOutput = $rawOutput
                }

                foreach ($line in ($finalJobOutput | Out-String -Stream)) {
                    [void](Filter-AndFormatJobOutput -Line $line)
                }
            }

            if ($JobStatus -eq 'Completed') {
                if ($Global:ScriptJob -and $Global:ScriptJob.HasErrors) {
                    $errorRecords = $Global:ScriptJob | Select-Object -ExpandProperty ChildJobs | Where-Object { $_.HasErrors } | Select-Object -ExpandProperty Error
                    $errorMessages = ($errorRecords | Select-Object -ExpandProperty Exception | Select-Object -ExpandProperty Message) -join "`n"
                    if ([string]::IsNullOrEmpty($errorMessages)) {
                        $errorMessages = "Si sono verificati errori sconosciuti durante l'esecuzione dello script."
                    }
                    Write-UnifiedLog -Type 'Error' -Message "❌ $JobName completato con errori: $errorMessages" -GuiColor "#FF0000"
                }
                else {
                    Write-UnifiedLog -Type 'Success' -Message "✅ Completato: $JobName" -GuiColor "#00FF00"
                }
            }
            elseif ($JobStatus -eq 'Failed' -or $JobStatus -eq 'ErrorStarting') {
                $errorMsg = ($Global:ScriptJob.JobStateInfo.Reason?.Message) -or "Errore sconosciuto"
                Write-UnifiedLog -Type 'Error' -Message "❌ $JobName fallito: $errorMsg" -GuiColor "#FF0000"
            }
            elseif ($JobStatus -eq 'Stopped') {
                Write-UnifiedLog -Type 'Warning' -Message "⚠️ $JobName interrotto" -GuiColor "#FFA500"
            }

            # Pulisci il job solo se esiste
            if ($Global:ScriptJob) {
                Remove-Job -Job $Global:ScriptJob -ErrorAction SilentlyContinue | Out-Null
                $Global:ScriptJob = $null
            }

            # Aggiorna la barra di progresso per lo script completato
            $Global:CurrentScriptIndex++
            if ($Global:SelectedScriptsQueue.Count -gt 0) {
                $progressPercentage = [int]((($Global:CurrentScriptIndex) / $Global:SelectedScriptsQueue.Count) * 100)
                if ($progressBar) { $progressBar.Value = $progressPercentage }
            }
            else {
                if ($progressBar) { $progressBar.Value = 100 }
            }

            # Se ci sono altri script in coda, avvia il prossimo
            if ($Global:CurrentScriptIndex -lt $Global:SelectedScriptsQueue.Count) {
                Write-UnifiedLog -Type 'Info' -Message "⏳ Attesa prossimo script..." -GuiColor "#FFA500"
                Start-NextScriptJob -scriptName $Global:SelectedScriptsQueue[$Global:CurrentScriptIndex]
            }
            else {
                # Tutti gli script completati
                if ($Global:JobMonitorTimer) {
                    $Global:JobMonitorTimer.Stop()
                    $Global:JobMonitorTimer = $null
                }
                $executeButton.IsEnabled = $true
                Write-UnifiedLog -Type 'Success' -Message "🎉 Tutti gli script sono stati eseguiti" -GuiColor "#00FF00"
                if ($progressBar) { $progressBar.Value = 100 }
            
                # Check for reboot requirement
                if ($Global:RebootRequired) {
                    $result = [System.Windows.MessageBox]::Show("Il sistema richiede un riavvio per completare le operazioni. Riavviare ora?", "Riavvio Richiesto", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
                    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                        Restart-Computer -Force
                    }
                }
            }
        })
}

# Gestore del Tick del timer per monitorare il job
function Tick_JobMonitor {
    if ($Global:ScriptJob -and ($Global:ScriptJob.State -eq 'Running' -or $Global:ScriptJob.State -eq 'NotStarted')) {
        # Ricevi l'output disponibile in blocchi per aggiornamenti in tempo reale
        $currentJobOutput = Receive-Job -Job $Global:ScriptJob -Keep -ErrorAction SilentlyContinue *>&1
        
        # Processa solo le nuove linee di output
        $newOutputLines = $currentJobOutput | Select-Object -Skip $Global:LastJobOutputCount
        if ($newOutputLines.Count -gt 0) {
            $window.Dispatcher.Invoke([Action] {
                    foreach ($line in ($newOutputLines | Out-String -Stream)) {
                        [void](Filter-AndFormatJobOutput -Line $line)
                    }
                })
            $Global:LastJobOutputCount = $currentJobOutput.Count
        }
    }
    elseif ($Global:ScriptJob -and ($Global:ScriptJob.State -eq 'Completed' -or $Global:ScriptJob.State -eq 'Failed' -or $Global:ScriptJob.State -eq 'Stopped')) {
        $Global:JobMonitorTimer.Stop()
        Process-JobCompletion -JobStatus $Global:ScriptJob.State -JobName $Global:SelectedScriptsQueue[$Global:CurrentScriptIndex]
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
    
        Write-UnifiedLog -Type 'Info' -Message "🔍 Trovati $($allCheckBoxes.Count) checkbox totali" -GuiColor "#00CED1"
    
        foreach ($checkBox in $allCheckBoxes) {
            try {
                if ($checkBox.IsChecked -eq $true) {
                    $scriptName = $checkBox.Tag
                    if ($scriptName) {
                        $selectedScripts += $scriptName
                        Write-UnifiedLog -Type 'Info' -Message "✅ Script selezionato: $scriptName" -GuiColor "#00FF00"
                    }
                }
            }
            catch {
                Write-UnifiedLog -Type 'Warning' -Message "⚠️ Errore lettura checkbox: $($_.Exception.Message)" -GuiColor "#FFA500"
            }
        }

        if ($selectedScripts.Count -eq 0) {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Nessuno script selezionato" -GuiColor "#FFA500"
            $window.Dispatcher.Invoke([Action] { $executeButton.IsEnabled = $true })
            return
        }

        $Global:SelectedScriptsQueue = $selectedScripts
        $Global:CurrentScriptIndex = 0
        $Global:IsInputWaiting = $false
        $Global:RebootRequired = $false

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
            Write-UnifiedLog -Type 'Error' -Message "❌ Errore invio log: $($_.Exception.Message)" -GuiColor "#FF0000"
        }
    })

# =============================================================================
# CONSOLE MINIMIZATION HELPER
# =============================================================================

function Minimize-Console {
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
        Write-Host "Console minimized" -ForegroundColor Cyan
    }
    catch {
        Write-Host "Could not minimize console (non-critical)" -ForegroundColor Yellow
    }
}

# =============================================================================
# INITIALIZATION AND DISPLAY
# =============================================================================

# Update system info
Update-SystemInformationPanel

# Generate dynamic menu
Update-ActionsPanel

# Show initial log message
Write-UnifiedLog -Type 'Success' -Message "🎉 WinToolkit GUI v2.0 inizializzato correttamente" -GuiColor "#00FF00"
Write-UnifiedLog -Type 'Info' -Message "📌 Core Version: $Global:CoreScriptVersion" -GuiColor "#00CED1"
Write-UnifiedLog -Type 'Info' -Message "💡 Seleziona uno o più script e premi 'Esegui'" -GuiColor "#00CED1"

# Minimize console
Minimize-Console

# Show window
$window.ShowDialog() | Out-Null

# Cleanup on exit
try {
    Stop-Transcript -ErrorAction SilentlyContinue
}
catch {}
