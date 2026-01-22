<#
.SYNOPSIS
    WinToolkit GUI v2.0 - GUI Edition
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
# CONFIGURATION AND CONSTANTS
# =============================================================================
$ScriptTitle = "WinToolkit By MagnetarMan"
$SupportEmail = "me@magnetarman.com"
$LogDirectory = "$env:LOCALAPPDATA\WinToolkit\logs"
$WindowWidth = 1500
$WindowHeight = 950
$FontFamily = "JetBrains Mono Nerd Font, Cascadia Code, Consolas, Courier New" # Con fallback
$FontSize = @{Small = 12; Medium = 14; Large = 16; Title = 18 }

# Emoji mappings for GUI elements
$emojiMappings = @{
    "SendErrorLogsImage"       = "📡"
    "FunzioniDisponibiliImage" = "⚙️"
    "OutputLogImage"           = "📋"
    "ExecuteButtonImage"       = "▶️"
    "SysInfoTitleImage1"       = "🖥️"
    "SysInfoTitleImage2"       = "🖥️"
    "SysInfoEditionLabelImage" = "💻"
    "SysInfoVersionImage"      = "📊"
    "SysInfoScriptImage"       = "✨"
    "SysInfoArchitectureImage" = "⚡"
    "SysInfoComputerNameImage" = "🏷️"
    "SysInfoRAMImage"          = "🧠"
    "SysInfoDiskImage"         = "💾"
}

# =============================================================================
# EMOJI ICONS CONFIGURATION
# =============================================================================
$localIconBasePath = Join-Path $env:LOCALAPPDATA "WinToolkit\asset\png"
$remoteIconBasePath = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/main/asset/png"

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
$ScriptCompatibilityIndicator = $null
$progressBar = $null
$actionsPanel = $null

# =============================================================================
# CORE INTEGRATION CONFIGURATION
# =============================================================================

# Configurazione per il caricamento dinamico del Core Script
$Global:CoreConfig = @{
    RemoteUrl          = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/WinToolkit.ps1"
    LocalCachePath     = "$env:LOCALAPPDATA\WinToolkit\cache\WinToolkit_Core.ps1"
    CacheMaxAge        = 3600 # secondi (1 ora)
    FallbackToCache    = $true
    RequiredFunctions  = @('Get-SystemInfo', 'Write-StyledMessage', 'Show-Header', 'Initialize-ToolLogging')
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

    # Write to GUI OutputTextBox (if available)
    if ($outputTextBox -and $window -and $window.Dispatcher) {
        try {
            $window.Dispatcher.Invoke([Action] {
                    $paragraph = New-Object System.Windows.Documents.Paragraph
                    $run = New-Object System.Windows.Documents.Run
                    $run.Text = "${currentDateTime}: $formattedMessage"
                    $run.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($GuiColor))
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
        Write-UnifiedLog -Type 'Info' -Message "🔄 INIZIALIZZAZIONE RISORSE - Caricamento Core Script..." -GuiColor "#00CED1"
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
    } else {
         Write-UnifiedLog -Type 'Error' -Message "❌ Funzione Get-SystemInfo NON trovata!" -GuiColor "#FF0000"
    }

} catch {
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
        <SolidColorBrush x:Key="BackgroundColor" Color="#FF2D2D2D"/>
        <SolidColorBrush x:Key="HeaderBackgroundColor" Color="#FF1A1A1A"/>
        <SolidColorBrush x:Key="PanelBackgroundColor" Color="#FF3D3D3D"/>
        <SolidColorBrush x:Key="TextColor" Color="#FFFFFFFF"/>
        <SolidColorBrush x:Key="AccentColor" Color="#FF0078D4"/>
        <SolidColorBrush x:Key="SuccessColor" Color="#FF00FF00"/>
        <SolidColorBrush x:Key="BorderColor" Color="#FF0078D4"/>
        <SolidColorBrush x:Key="OutputBackgroundColor" Color="#FF1A1A1A"/>
        <SolidColorBrush x:Key="InfoColor" Color="#FF4FC3F7"/>
        <FontFamily x:Key="PrimaryFont">$FontFamily</FontFamily>
    </Window.Resources>

    <Grid Background="{StaticResource BackgroundColor}">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="{StaticResource HeaderBackgroundColor}" Padding="16" Margin="16,16,16,8">
            <StackPanel>
                <TextBlock Text="$($ScriptTitle)" FontSize="24" FontWeight="Bold" Foreground="{StaticResource TextColor}" FontFamily="{StaticResource PrimaryFont}" HorizontalAlignment="Center"/>
                <TextBlock Text="GUI Edition - Core v$($Global:CoreScriptVersion)" FontSize="14" Foreground="{StaticResource InfoColor}" FontFamily="{StaticResource PrimaryFont}" HorizontalAlignment="Center" Margin="0,4,0,0"/>

                <!-- System Info Panel -->
                <Border Background="{StaticResource OutputBackgroundColor}" CornerRadius="6" Padding="12" Margin="0,12,0,0">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <!-- Column 1: Edition, Version, Architecture -->
                        <StackPanel Grid.Column="0" Margin="0,0,8,0">
                            <TextBlock x:Name="SysInfoEdition" Text="Caricamento..." Foreground="{StaticResource TextColor}" FontSize="12" FontFamily="{StaticResource PrimaryFont}"/>
                            <TextBlock x:Name="SysInfoVersion" Text="Caricamento..." Foreground="{StaticResource TextColor}" FontSize="12" FontFamily="{StaticResource PrimaryFont}" Margin="0,4,0,0"/>
                            <TextBlock x:Name="SysInfoArchitecture" Text="Caricamento..." Foreground="{StaticResource TextColor}" FontSize="12" FontFamily="{StaticResource PrimaryFont}" Margin="0,4,0,0"/>
                        </StackPanel>

                        <!-- Column 2: Compatibility -->
                        <StackPanel Grid.Column="1" Margin="8,0">
                            <TextBlock x:Name="SysInfoScriptCompatibility" Text="Caricamento..." Foreground="{StaticResource TextColor}" FontSize="12" FontFamily="{StaticResource PrimaryFont}" TextWrapping="Wrap"/>
                        </StackPanel>

                        <!-- Column 3: Computer Name, RAM, Disk -->
                        <StackPanel Grid.Column="2" Margin="8,0,0,0">
                            <TextBlock x:Name="SysInfoComputerName" Text="Caricamento..." Foreground="{StaticResource TextColor}" FontSize="12" FontFamily="{StaticResource PrimaryFont}"/>
                            <TextBlock x:Name="SysInfoRAM" Text="Caricamento..." Foreground="{StaticResource TextColor}" FontSize="12" FontFamily="{StaticResource PrimaryFont}" Margin="0,4,0,0"/>
                            <TextBlock x:Name="SysInfoDisk" Text="Caricamento..." Foreground="{StaticResource TextColor}" FontSize="12" FontFamily="{StaticResource PrimaryFont}" Margin="0,4,0,0"/>
                        </StackPanel>
                    </Grid>
                </Border>
            </StackPanel>
        </Border>

        <!-- Main Content -->
        <Grid Grid.Row="1" Margin="16">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="500"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Left Panel - Actions -->
            <Border Grid.Column="0" Background="{StaticResource PanelBackgroundColor}" CornerRadius="8" Margin="0,0,8,0" Padding="12">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <TextBlock Grid.Row="0" Text="⚙️  Funzioni Disponibili" Foreground="{StaticResource TextColor}" FontSize="16" FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}" Margin="0,0,0,12"/>

                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel x:Name="ActionsPanel" Margin="0,0,0,8"/>
                    </ScrollViewer>
                </Grid>
            </Border>

            <!-- Right Panel - Output -->
            <Border Grid.Column="1" Background="{StaticResource PanelBackgroundColor}" CornerRadius="8" Padding="12">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <TextBlock Grid.Row="0" Text="📋 Output e Log" Foreground="{StaticResource TextColor}" FontSize="16" FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}" Margin="0,0,0,8"/>

                    <RichTextBox x:Name="OutputTextBox"
                                 Grid.Row="1"
                                 Background="{StaticResource OutputBackgroundColor}"
                                 Foreground="{StaticResource TextColor}"
                                 BorderBrush="{StaticResource BorderColor}"
                                 BorderThickness="1"
                                 IsReadOnly="True"
                                 FontFamily="{StaticResource PrimaryFont}"
                                 FontSize="12"/>
                </Grid>
            </Border>
        </Grid>

        <!-- Bottom Section - Execute Button -->
        <Border Grid.Row="2" Background="{StaticResource HeaderBackgroundColor}" Padding="16" Margin="16,8,16,16">
            <StackPanel>
                <ProgressBar x:Name="MainProgressBar"
                             Height="20"
                             Margin="0,0,0,10"
                             Background="{StaticResource PanelBackgroundColor}"
                             BorderBrush="{StaticResource AccentColor}"
                             Foreground="{StaticResource SuccessColor}"
                             Minimum="0"
                             Maximum="100"
                             Value="0"/>

                <Button x:Name="ExecuteButton"
                        Content="▶️  Esegui Script Selezionati"
                        Background="{StaticResource AccentColor}"
                        Foreground="{StaticResource TextColor}"
                        FontSize="16"
                        FontWeight="Bold"
                        FontFamily="{StaticResource PrimaryFont}"
                        Padding="20,12"
                        BorderThickness="0"
                        HorizontalAlignment="Center"
                        Cursor="Hand"/>
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
$progressBar = $window.FindName("MainProgressBar")

# =============================================================================
# SYSTEM INFORMATION UPDATE (Using Core's Get-SystemInfo)
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
                $SysInfoEdition.Text = "💻 Edizione: $($sysInfo.ProductName)"
                $SysInfoVersion.Text = "🆔 Versione: $($sysInfo.DisplayVersion) (Build $($sysInfo.BuildNumber))"
                $SysInfoArchitecture.Text = "🔑 Architettura: $($sysInfo.Architecture)"
                $SysInfoComputerName.Text = "🔧 Nome PC: $($sysInfo.ComputerName)"
                $SysInfoRAM.Text = "🧠 RAM: $($sysInfo.TotalRAM) GB"
                $SysInfoDisk.Text = "💾 Disco: $($sysInfo.FreePercentage)% Libero ($($sysInfo.FreeDisk) GB / $($sysInfo.TotalDisk) GB)"

                # Compatibility indicator
                if ($sysInfo.BuildNumber -ge 22000) {
                    $SysInfoScriptCompatibility.Text = "✅ Completa - Sistema Windows 11"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                }
                elseif ($sysInfo.BuildNumber -ge 17763) {
                    $SysInfoScriptCompatibility.Text = "✅ Completa - Sistema Windows 10"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::LimeGreen)
                }
                else {
                    $SysInfoScriptCompatibility.Text = "⚠️ Parziale - Sistema obsoleto"
                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Orange)
                }
            })

        Write-UnifiedLog -Type 'Success' -Message "System information panel updated using Core function" -GuiColor "#00FF00"
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

                foreach ($category in $Global:MenuStructure) {
                    # Category header
                    $categoryHeader = New-Object System.Windows.Controls.TextBlock
                    $categoryHeader.Text = "$($category.Icon) $($category.Name)"
                    $categoryHeader.FontSize = 14
                    $categoryHeader.FontWeight = 'Bold'
                    $categoryHeader.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Cyan)
                    $categoryHeader.Margin = '0,8,0,4'
                    $actionsPanel.Children.Add($categoryHeader) | Out-Null

                    # Scripts in category
                    foreach ($script in $category.Scripts) {
                        $checkBox = New-Object System.Windows.Controls.CheckBox
                        $checkBox.Content = $script.Description
                        $checkBox.Tag = $script.Name
                        $checkBox.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::White)
                        $checkBox.FontSize = 12
                        $checkBox.Margin = '16,4,0,4'
                        $actionsPanel.Children.Add($checkBox) | Out-Null
                    }
                }

                Write-UnifiedLog -Type 'Success' -Message "✅ Dynamic menu generated: $($Global:MenuStructure.Count) categories" -GuiColor "#00FF00"
            })
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "❌ Error generating dynamic menu: $($_.Exception.Message)" -GuiColor "#FF0000"
    }
}

# =============================================================================
# SCRIPT EXECUTION (Using Core's concatenation logic)
# =============================================================================

$executeButton.Add_Click({
        try {
            # Get selected scripts
            $selectedScripts = @()
            foreach ($child in $actionsPanel.Children) {
                if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                    $selectedScripts += $child.Tag
                }
            }

            if ($selectedScripts.Count -eq 0) {
                Write-UnifiedLog -Type 'Warning' -Message "⚠️ Nessuno script selezionato" -GuiColor "#FFA500"
                return
            }

            # Execute scripts using Core's concatenation logic
            Write-UnifiedLog -Type 'Info' -Message "🚀 Esecuzione di $($selectedScripts.Count) script..." -GuiColor "#00CED1"

            foreach ($scriptName in $selectedScripts) {
                Write-UnifiedLog -Type 'Info' -Message "▶️ Avvio: $scriptName" -GuiColor "#00CED1"

                try {
                    # Invoke the function from Core (already loaded via dot-sourcing)
                    if ($selectedScripts.Count -gt 1) {
                        # Use concatenation logic: suppress individual reboots
                        Invoke-Expression "$scriptName -SuppressIndividualReboot"
                    }
                    else {
                        # Single execution: normal behavior
                        Invoke-Expression $scriptName
                    }

                    Write-UnifiedLog -Type 'Success' -Message "✅ Completato: $scriptName" -GuiColor "#00FF00"
                }
                catch {
                    Write-UnifiedLog -Type 'Error' -Message "❌ Errore in $scriptName`: $($_.Exception.Message)" -GuiColor "#FF0000"
                }
            }

            Write-UnifiedLog -Type 'Success' -Message "🎉 Tutti gli script sono stati eseguiti" -GuiColor "#00FF00"
        }
        catch {
            Write-UnifiedLog -Type 'Error' -Message "❌ Errore durante esecuzione: $($_.Exception.Message)" -GuiColor "#FF0000"
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
