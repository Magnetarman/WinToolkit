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

#Requires -Version 5.1

# 1. Flag per dire al Core di NON mostrare il menu (CRITICO)
$Global:GuiSessionActive = $true

# =============================================================================
# GUI VERSION CONFIGURATION (Separate from Core Version)
# =============================================================================
$Global:GuiVersion = "2.5.1 (Build 45)"  # Format: CoreVersion.GuiBuildNumber

# =============================================================================
# CONFIGURATION AND CONSTANTS
# =============================================================================
$ScriptTitle = "WinToolkit By MagnetarMan"
$SupportEmail = "me@magnetarman.com"
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
$ScriptStatusIcon = $null
$ScriptCompatibilityIndicator = $null
$progressBar = $null
$actionsPanel = $null

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
        [Parameter(Mandatory = $true)][string]$Type, # 'Info', 'Warning', 'Error', 'Success'
        [string]$GuiColor = "#FFFFFF"
    )

    $consoleColors = @{
        Info    = 'Cyan'
        Warning = 'Yellow'
        Error   = 'Red'
        Success = 'Green'
    }

    $currentDateTime = Get-Date -Format 'HH:mm:ss'
    $formattedMessage = "[$Type] $Message"

    # Write to GUI OutputTextBox (if available) - With improved parsing
    if ($outputTextBox -and $window -and $window.Dispatcher) {
        try {
            $window.Dispatcher.Invoke([Action] {
                    # Create styled paragraph
                    $paragraph = New-Object System.Windows.Documents.Paragraph
                    $paragraph.Margin = New-Object System.Windows.Thickness(0, 2, 0, 2)
                    
                    # Parse message for special patterns and apply colors
                    $run = New-Object System.Windows.Documents.Run
                    $run.Text = "${currentDateTime}: $formattedMessage"
                    
                    # Set color based on type
                    switch -Wildcard ($Type.ToLower()) {
                        "error" { $run.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#FF5555")); $run.FontWeight = [System.Windows.FontWeights]::Bold }
                        "warning" { $run.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")) }
                        "success" { $run.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#4CAF50")); $run.FontWeight = [System.Windows.FontWeights]::Bold }
                        default { $run.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($GuiColor)) }
                    }
                    
                    $paragraph.Inlines.Add($run)
                    $outputTextBox.Document.Blocks.Add($paragraph)
                    $outputTextBox.ScrollToEnd()
                })
        }
        catch {
            # Silently fail GUI logging if there are issues
        }
    }

    # Write to console
    try {
        Write-Host $formattedMessage -ForegroundColor $consoleColors[$Type]
    }
    catch {
        # Silently fail console output
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

        # Verifica cache esistente
        $cacheExists = Test-Path $Global:CoreConfig.LocalCachePath
        $cacheValid = $false

        if ($cacheExists) {
            $cacheAge = (Get-Date) - (Get-Item $Global:CoreConfig.LocalCachePath).LastWriteTime
            $cacheValid = ($cacheAge.TotalSeconds -lt $Global:CoreConfig.CacheMaxAge)

            if ($cacheValid) {
                Write-UnifiedLog -Type 'Success' -Message "✅ Cache locale valida trovata" -GuiColor "#00FF00"
            }
            else {
                Write-UnifiedLog -Type 'Info' -Message "⏰ Cache locale scaduta (età: $([Math]::Round($cacheAge.TotalMinutes, 1)) minuti)" -GuiColor "#FFA500"
            }
        }

        # Tentativo download remoto se cache non valida
        if (-not $cacheValid) {
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
            }
            catch {
                Write-UnifiedLog -Type 'Warning' -Message "⚠️ Download fallito: $($_.Exception.Message)" -GuiColor "#FFA500"

                if ($cacheExists -and $Global:CoreConfig.FallbackToCache) {
                    Write-UnifiedLog -Type 'Info' -Message "📂 Utilizzo cache locale (scaduta ma disponibile)..." -GuiColor "#FFA500"
                    $coreContent = Get-Content $Global:CoreConfig.LocalCachePath -Raw -Encoding UTF8
                    $usedCache = $true
                }
                else {
                    throw "Impossibile scaricare Core Script e nessuna cache disponibile."
                }
            }
        }
        else {
            # Usa cache valida
            Write-UnifiedLog -Type 'Info' -Message "📂 Utilizzo cache locale valida..." -GuiColor "#00CED1"
            $coreContent = Get-Content $Global:CoreConfig.LocalCachePath -Raw -Encoding UTF8
            $usedCache = $true
        }

        if (-not $coreContent) {
            throw "Core Script content è vuoto"
        }

        # Estrai versione dal Core
        Write-UnifiedLog -Type 'Info' -Message "🔍 Estrazione versione dal Core Script..." -GuiColor "#00CED1"
        if ($coreContent -match '\$ToolkitVersion\s*=\s*"([^"]+)"') {
            $Global:CoreScriptVersion = $matches[1]
            Write-UnifiedLog -Type 'Success' -Message "📌 Versione Core rilevata: $Global:CoreScriptVersion" -GuiColor "#00FF00"
        }
        else {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Impossibile estrarre versione dal Core (pattern non trovato)" -GuiColor "#FFA500"
            $Global:CoreScriptVersion = "Unknown"
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
        Genera e invia i log degli errori.
    #>
    try {
        Write-UnifiedLog -Type 'Info' -Message "📦 Preparazione log errori..." -GuiColor "#00CED1"
        
        # Esegui la funzione WinExportLog se disponibile
        if (Get-Command 'WinExportLog' -ErrorAction SilentlyContinue) {
            try {
                WinExportLog
                Write-UnifiedLog -Type 'Success' -Message "✅ WinExportLog eseguita con successo" -GuiColor "#00FF00"
            }
            catch {
                Write-UnifiedLog -Type 'Warning' -Message "⚠️ WinExportLog ha generato un errore: $($_.Exception.Message)" -GuiColor "#FFA500"
            }
        }
        else {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Funzione WinExportLog non disponibile" -GuiColor "#FFA500"
        }
        
        # Trova i file log più recenti
        $logFiles = Get-ChildItem -Path $LogDirectory -Filter "*.log" -ErrorAction SilentlyContinue | 
        Sort-Object -Property LastWriteTime -Descending | 
        Select-Object -First 5
        
        if (-not $logFiles) {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Nessun file log trovato" -GuiColor "#FFA500"
            return
        }
        
        # Crea contenuto combinato dei log
        $logContent = "=" * 60 + "`n"
        $logContent += "WinToolkit Error Report`n"
        $logContent += "Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
        $logContent += "Versione Core: $Global:CoreScriptVersion`n"
        $logContent += "=" * 60 + "`n`n"
        
        foreach ($logFile in $logFiles) {
            $logContent += "--- $($logFile.Name) ---`n"
            $logContent += Get-Content -Path $logFile.FullName -ErrorAction SilentlyContinue -Raw
            $logContent += "`n`n"
        }
        
        # Salva report temporaneo
        $tempReport = "$env:TEMP\WinToolkit_ErrorReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $logContent | Out-File -FilePath $tempReport -Encoding UTF8 -Force
        
        # Comprimi il report in ZIP sul Desktop
        $zipPath = "$env:USERPROFILE\Desktop\WinToolkit_ErrorReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
        if (Get-Command 'Compress-Archive' -ErrorAction SilentlyContinue) {
            Compress-Archive -Path $tempReport -DestinationPath $zipPath -Force
            Write-UnifiedLog -Type 'Success' -Message "✅ Report compresso: $zipPath" -GuiColor "#00FF00"
        }
        
        Write-UnifiedLog -Type 'Success' -Message "✅ Report errori creato: $tempReport" -GuiColor "#00FF00"
        
        # Apri il browser predefinito alla pagina GitHub Issues
        try {
            Start-Process -FilePath "https://github.com/Magnetarman/WinToolkit/issues/new"
            Write-UnifiedLog -Type 'Info' -Message "🌐 Browser aperto per la segnalazione su GitHub" -GuiColor "#00CED1"
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message "⚠️ Impossibile aprire il browser: $($_.Exception.Message)" -GuiColor "#FFA500"
        }
        
        # Scrivi messaggio verde e grassetto nel box Output
        $window.Dispatcher.Invoke([Action] {
                $paragraph = New-Object System.Windows.Documents.Paragraph
                $run = New-Object System.Windows.Documents.Run
                $run.Text = "Invia l'archivio compresso sul tuo desktop su GitHub indicando le problematiche riscontrate in modo da migliorare il tool"
                $run.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#00FF00"))
                $run.FontWeight = [System.Windows.FontWeights]::Bold
                $paragraph.Inlines.Add($run)
                $outputTextBox.Document.Blocks.Add($paragraph)
                $outputTextBox.ScrollToEnd()
            })
        
        Write-UnifiedLog -Type 'Success' -Message "🎉 Operazione completata!" -GuiColor "#00FF00"
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "❌ Errore durante preparazione log: $($_.Exception.Message)" -GuiColor "#FF0000"
    }
}

function CheckBitlocker {
    <#
    .SYNOPSIS
        Controlla lo stato di Bitlocker.
    #>
    try {
        $out = & manage-bde -status C: 2>&1
        if ($out -match "Stato protezione:\s*(.*)") { return $matches[1].Trim() }
        return "Non configurato"
    }
    catch { return "Disattivato" }
}

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
        Write-UnifiedLog -Type 'Success' -Message "✅ \$menuStructure caricato (categorie: $($Global:MenuStructure.Count))" -GuiColor "#00FF00"
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
        
        <!-- CheckBox Style base (senza CornerRadius custom che causa problemi) -->
        <Style x:Key="CheckBoxStyle" TargetType="CheckBox">
            <Setter Property="Foreground" Value="{StaticResource LabelBlue}"/>
            <Setter Property="Background" Value="Gray"/>
            <Setter Property="BorderBrush" Value="{StaticResource LabelBlue}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="4"/>
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
                
                <!-- Colonna 2: Pulsante Invia Log Errori (Rosso) -->
                <Button Grid.Column="2" x:Name="SendErrorLogsButton" 
                        VerticalAlignment="Center" HorizontalAlignment="Right"
                        Background="{StaticResource ErrorButtonColor}" 
                        Foreground="{StaticResource TextColor}"
                        Padding="12,8" BorderThickness="0" Cursor="Hand" 
                        Margin="16,0,0,0" Style="{StaticResource SmallButtonStyle}">
                    <StackPanel Orientation="Horizontal">
                        <Image x:Name="SendErrorLogsImage" Width="16" Height="16" Margin="0,0,8,0"/>
                        <TextBlock Text="Invia Log Errori" VerticalAlignment="Center" 
                                   FontFamily="{StaticResource PrimaryFont}" FontWeight="SemiBold"/>
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
                
                <!-- Blocco 2: Script Status (Widget centrale con LED) - Layout modificato con 2 righe -->
                <StackPanel Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Center" 
                            Margin="20,0" MinWidth="200">
                    
                    <!-- Riga 1: Funzionalità Script con status e LED -->
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
                        <Grid Grid.Column="1" VerticalAlignment="Center" Margin="12,0,0,0">
                            <Ellipse Width="16" Height="16" Fill="#FF1E1E1E" 
                                     Stroke="{StaticResource LabelBlue}" StrokeThickness="1"/>
                            <Ellipse x:Name="ScriptCompatibilityLED" Width="10" Height="10" 
                                     Fill="{StaticResource LEDGreenColor}" HorizontalAlignment="Center" 
                                     VerticalAlignment="Center"/>
                        </Grid>
                    </Grid>
                    
                    <!-- Riga 2: Stato Bitlocker con LED colorato - Stessa dimensione della Riga 1 -->
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
                        <!-- LED Bitlocker - Verde se disattivato, Rosso se attivato -->
                        <Grid Grid.Column="1" VerticalAlignment="Center" Margin="140,0,0,0">
                            <Ellipse Width="16" Height="16" x:Name="BitlockerLEDOuter" Fill="#FF1E1E1E" 
                                     Stroke="{StaticResource LabelBlue}" StrokeThickness="1"/>
                            <Ellipse x:Name="BitlockerLED" Width="10" Height="10" 
                                     Fill="{StaticResource LEDGreenColor}" HorizontalAlignment="Center" 
                                     VerticalAlignment="Center"/>
                        </Grid>
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
                                 IsReadOnly="False"
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
$ScriptCompatibilityLED = $window.FindName("ScriptCompatibilityLED")
$progressBar = $window.FindName("MainProgressBar")
$SysInfoEditionImage = $window.FindName("SysInfoEditionImage")
$SysInfoVersionImage = $window.FindName("SysInfoVersionImage")
$SysInfoArchitectureImage = $window.FindName("SysInfoArchitectureImage")
$SysInfoScriptImage = $window.FindName("SysInfoScriptImage")
$SysInfoComputerNameImage = $window.FindName("SysInfoComputerNameImage")
$SysInfoRAMImage = $window.FindName("SysInfoRAMImage")
$SysInfoDiskImage = $window.FindName("SysInfoDiskImage")
$SendErrorLogsButton = $window.FindName("SendErrorLogsButton")
$SendErrorLogsImage = $window.FindName("SendErrorLogsImage")
$ScriptStatusIcon = $window.FindName("ScriptStatusIcon")
$BitlockerImage = $window.FindName("BitlockerImage")
$BitlockerLED = $window.FindName("BitlockerLED")
$SysInfoBitlocker = $window.FindName("SysInfoBitlocker")
$ToolIconImage = $window.FindName("ToolIconImage")
$ExecuteButtonImage = $window.FindName("ExecuteButtonImage")
$CategorySystemImage = $window.FindName("CategorySystemImage")
$OutputLogImage = $window.FindName("OutputLogImage")

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

                # Task 2: Compatibility indicator con LED colorato (Solo "Completa", "Limitata", "Non supportata")
                $ledColor = $null
                $statusText = ""
                $ledBrush = $null
            
                if ($sysInfo.BuildNumber -ge 22000) {
                    $ledBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                    $statusText = "Completa"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                }
                elseif ($sysInfo.BuildNumber -ge 17763) {
                    $ledBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                    $statusText = "Completa"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                }
                elseif ($sysInfo.BuildNumber -ge 10240) {
                    $ledBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Orange)
                    $statusText = "Limitata"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Orange)
                }
                else {
                    $ledBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Red)
                    $statusText = "Non supportata"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Red)
                }
            
                $SysInfoScriptCompatibility.Text = $statusText
            
                # Aggiorna il colore del LED (UNICO indicatore visivo)
                if ($ScriptCompatibilityLED) {
                    try {
                        $ScriptCompatibilityLED.Fill = $ledBrush
                    }
                    catch {
                        # Fallback: usa il colore predefinito
                    }
                }
            
                # Aggiorna stato Bitlocker
                try {
                    $blStatus = CheckBitlocker
                    $SysInfoBitlocker.Text = $blStatus
                
                    # Colore in base allo stato (VERDE se disattivato, ROSSO se attivato)
                    $bitlockerLedBrush = $null
                    if ($blStatus -match 'Disattivato|Non configurato|Off') {
                        $SysInfoBitlocker.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                        $bitlockerLedBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                    }
                    elseif ($blStatus -match 'Sospeso') {
                        $SysInfoBitlocker.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Orange)
                        $bitlockerLedBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Orange)
                    }
                    else {
                        $SysInfoBitlocker.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Red)
                        $bitlockerLedBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Red)
                    }
                
                    # Aggiorna LED Bitlocker
                    if ($BitlockerLED) {
                        try {
                            $BitlockerLED.Fill = $bitlockerLedBrush
                        }
                        catch {
                            # Fallback: usa il colore predefinito
                        }
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
                    
                        # CheckBox con:
                        # - Foreground celeste (#4FC3F7)
                        # - VerticalAlignment Center
                        # - Margin 0,0,10,0
                        # - Gray internal background con forma arrotondata
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
# SCRIPT EXECUTION (Using Core's concatenation logic)
# =============================================================================

$executeButton.Add_Click({
        # Disable button to prevent re-clicks while busy
        $executeButton.IsEnabled = $false
        $progressBar.Value = 0 # Reset progress bar
        
        # Clear previous output
        $window.Dispatcher.Invoke([Action] {
                $outputTextBox.Document.Blocks.Clear()
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
            $executeButton.IsEnabled = $true
            return
        }

        Write-UnifiedLog -Type 'Info' -Message "🚀 Esecuzione di $($selectedScripts.Count) script..." -GuiColor "#00CED1"

        # Execute scripts synchronously on UI thread with progress updates
        $totalScripts = $selectedScripts.Count
        $scriptIndex = 0
        
        foreach ($scriptName in $selectedScripts) {
            $scriptIndex++
            $progressPercentage = [int]((($scriptIndex - 1) / $totalScripts) * 100)
            
            Write-UnifiedLog -Type 'Info' -Message "▶️ Avvio ($scriptIndex/$totalScripts): $scriptName" -GuiColor "#00CED1"
            $progressBar.Value = $progressPercentage
            
            try {
                # Verify function exists before calling
                if (Get-Command $scriptName -ErrorAction SilentlyContinue) {
                    # Invoke the function from Core with output capturing
                    $scriptOutput = @()
                    
                    # Run script and capture output
                    if ($totalScripts -gt 1) {
                        # For multiple scripts, use job to capture output and send Enter between scripts
                        $job = Start-Job -ScriptBlock {
                            param($ScriptName, $SuppressReboot)
                            try {
                                # Capture all output
                                $output = & $ScriptName @($SuppressReboot) 2>&1 | Out-String
                                return $output
                            }
                            catch {
                                return "ERROR: $($_.Exception.Message)"
                            }
                        } -ArgumentList @($scriptName, $true)
                        
                        $job | Wait-Job | Out-Null
                        $scriptOutput = Receive-Job -Job $job
                        Remove-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
                    }
                    else {
                        $job = Start-Job -ScriptBlock {
                            param($ScriptName)
                            try {
                                $output = & $ScriptName 2>&1 | Out-String
                                return $output
                            }
                            catch {
                                return "ERROR: $($_.Exception.Message)"
                            }
                        } -ArgumentList $scriptName
                        
                        $job | Wait-Job | Out-Null
                        $scriptOutput = Receive-Job -Job $job
                        Remove-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
                    }
                    
                    # Display captured output in the log
                    if ($scriptOutput -and $scriptOutput.Trim()) {
                        Write-UnifiedLog -Type 'Info' -Message "--- Output di $scriptName ---" -GuiColor "#00CED1"
                        foreach ($line in ($scriptOutput -split "`n")) {
                            if ($line.Trim()) {
                                Write-UnifiedLog -Type 'Info' -Message $line.Trim() -GuiColor "#FFFFFF"
                            }
                        }
                    }
                    
                    # Send Enter key between scripts if multiple scripts selected
                    if ($scriptIndex -lt $totalScripts) {
                        Write-UnifiedLog -Type 'Info' -Message "⏳ Attesa conferma per prossimo script..." -GuiColor "#FFA500"
                        Start-Sleep -Milliseconds 500
                    }
                    
                    Write-UnifiedLog -Type 'Success' -Message "✅ Completato: $scriptName" -GuiColor "#00FF00"
                }
                else {
                    Write-UnifiedLog -Type 'Error' -Message "❌ Funzione non trovata: $scriptName" -GuiColor "#FF0000"
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-UnifiedLog -Type 'Error' -Message "❌ Errore in $scriptName`: $errorMsg" -GuiColor "#FF0000"
            }
            
            # Update progress bar after each script
            $progressPercentage = [int](($scriptIndex / $totalScripts) * 100)
            $progressBar.Value = $progressPercentage
        }

        Write-UnifiedLog -Type 'Success' -Message "🎉 Tutti gli script sono stati eseguiti" -GuiColor "#00FF00"
        $progressBar.Value = 100
        $executeButton.IsEnabled = $true
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

# Show window
$window.ShowDialog() | Out-Null

# Cleanup on exit
try {
    Stop-Transcript -ErrorAction SilentlyContinue
}
catch {}
