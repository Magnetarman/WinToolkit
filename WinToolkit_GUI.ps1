<#
.SYNOPSIS
    WinToolkit GUI - Version 5.0 (GUI Edition) [Build 41 - ALPHA]
.DESCRIPTION
    Enhanced WinToolkit GUI with modern interface, logo integration, progress tracking, and email error reporting
.NOTES
    Version 5.0.0 - GUI Edition with enhanced features and modern UI [Build 42 - ALPHA]
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION AND CONSTANTS
# =============================================================================
$ScriptVersion = "5.0 (GUI Edition) [Build 42 - ALPHA]"
$ScriptTitle = "WinToolKit By MagnetarMan"
$SupportEmail = "me@magnetarman.com"
$LogDirectory = "$env:LOCALAPPDATA\WinToolkit\logs"
$WindowWidth = 1500
$WindowHeight = 950
$FontFamily = "Cascadia Code"
$FontSize = @{Small = 12; Medium = 14; Large = 16; Title = 18 }

# =============================================================================
# EMOJI ICONS CONFIGURATION
# =============================================================================
# Percorso base per le icone emoji - facilmente modificabile per GitHub Raw
# Per utilizzare icone da GitHub Raw, sostituire con:
# $iconBasePath = "https://raw.githubusercontent.com/TuoUtente/TuoRepo/main/asset/png"
$iconBasePath = Join-Path $PSScriptRoot "asset/png"

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
$SysInfoEditionValueImage = $null
$SysInfoEditionLabelImage = $null
$SysInfoArchitectureImage = $null
$SysInfoRAM = $null
$SysInfoDisk = $null
$SysInfoScriptCompatibility = $null
$ScriptCompatibilityIndicator = $null

# =============================================================================
# LOGGING AND UTILITY FUNCTIONS
# =============================================================================

# Unified logging function that handles GUI, transcript, and console output
function Write-UnifiedLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)][string]$Type, # e.g., 'Info', 'Warning', 'Error', 'Success'
        [string]$GuiColor = "#FFFFFF" # Default white for GUI
    )

    $consoleColors = @{
        Info    = 'Cyan'
        Warning = 'Yellow'
        Error   = 'Red'
        Success = 'Green'
    }

    $currentDateTime = Get-Date -Format 'HH:mm:ss'
    $formattedMessage = "[$Type] $Message"

    # 1. Write to GUI OutputTextBox (if available)
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

    # 2. Write to Start-Transcript (and console via Write-Verbose/Write-Error)
    try {
        switch ($Type) {
            'Error' { Write-Error $formattedMessage -ErrorAction Continue }
            'Warning' { Write-Warning $formattedMessage -ErrorAction Continue }
            default { Write-Verbose $formattedMessage -Verbose } # Use -Verbose to ensure it goes to transcript
        }
    }
    catch {
        # Fallback if transcript is not available
    }

    # 3. Write to console directly (for immediate feedback, even if transcript is off or verbose not set)
    try {
        Write-Host $formattedMessage -ForegroundColor $consoleColors[$Type]
    }
    catch {
        # Silently fail console output
    }
}


# =============================================================================
# EMOJI ICONS HELPER FUNCTIONS
# =============================================================================

# Funzione Helper per ottenere il percorso dell'icona dall'emoji
function Get-EmojiIconPath {
    param (
        [string]$EmojiCharacter
    )

    try {
        # Converte il carattere nel suo codepoint esadecimale completo
        $bytes = [System.Text.Encoding]::UTF32.GetBytes($EmojiCharacter)
        $codepoint = [BitConverter]::ToUInt32($bytes, 0).ToString("X")
        $fileName = "U+$codepoint.png"
        $fullPath = Join-Path $iconBasePath $fileName

        Write-UnifiedLog -Type 'Info' -Message "Emoji '$EmojiCharacter' -> Codepoint: $codepoint -> File: $fileName" -GuiColor "#00CED1"

        return $fullPath
    }
    catch {
        Write-UnifiedLog -Type 'Warning' -Message "Error processing emoji '$EmojiCharacter': $($_.Exception.Message)" -GuiColor "#FFA500"
        return $null
    }
}

# Funzione Helper per estrarre emoji e testo da una stringa
function Split-EmojiAndText {
    param (
        [string]$InputString
    )

    # Split on the first space to separate emoji from text
    $parts = $InputString -split ' ', 2

    if ($parts.Length -ge 2) {
        $emoji = $parts[0]
        $text = $parts[1]
        return @{
            Emoji = $emoji
            Text  = $text
        }
    }
    else {
        # If no space found, consider the whole string as text
        return @{
            Emoji = ""
            Text  = $InputString
        }
    }
}

# =============================================================================
# LOGGING INITIALIZATION
# =============================================================================

try {
    [System.IO.Directory]::CreateDirectory($LogDirectory) | Out-Null

    # Stop any existing transcript to avoid file lock issues
    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}

    Start-Transcript -Path $mainLog -Append -Force | Out-Null
    Write-UnifiedLog -Type 'Info' -Message "Logging initialized to $mainLog" -GuiColor "#00CED1"
}
catch {
    Write-UnifiedLog -Type 'Error' -Message "Failed to initialize logging. $($_.Exception.Message)" -GuiColor "#FF0000"
    # Fallback for logging if transcript failed
    Add-Content -Path "C:\temp\WinToolkit_Error_Fallback.log" -Value "[$([DateTime]::Now)] ERROR: Failed to initialize logging: $($_.Exception.Message)"
}

# =============================================================================
# INITIALIZATION AND VALIDATION
# =============================================================================

# Check administrator privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-UnifiedLog -Type 'Error' -Message "Administrator privileges required" -GuiColor "#FF0000"
    exit
}

Write-UnifiedLog -Type 'Info' -Message "Administrator privileges confirmed" -GuiColor "#00CED1"

# Load WPF assemblies
$assemblies = @("PresentationFramework", "PresentationCore", "WindowsBase", "System.Windows.Forms")
foreach ($assembly in $assemblies) {
    try {
        Add-Type -AssemblyName $assembly -ErrorAction Stop
        Write-UnifiedLog -Type 'Success' -Message "Loaded: $assembly" -GuiColor "#00FF00"
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "Failed to load: $assembly - $($_.Exception.Message)" -GuiColor "#FF0000"
    }
}

# Version mapping (usato da più funzioni)
$versionMap = @{
    26100 = "24H2"; 22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2"
    19045 = "22H2"; 19044 = "21H2"; 19043 = "21H1"; 19042 = "20H2"
    19041 = "2004"; 18363 = "1909"; 18362 = "1903"; 17763 = "1809"
    17134 = "1803"; 16299 = "1709"; 15063 = "1703"; 14393 = "1607"
    10586 = "1511"; 10240 = "1507"
}

function Get-WindowsVersion {
    param([int]$buildNumber)

    foreach ($build in ($versionMap.Keys | Sort-Object -Descending)) {
        if ($buildNumber -ge $build) { return $versionMap[$build] }
    }
    return "N/A"
}

function Get-SystemInfo {
    $systemInfo = @{}

    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $systemInfo.ProductName = $osInfo.Caption -replace 'Microsoft ', ''
        $systemInfo.BuildNumber = [int]$osInfo.BuildNumber
        $systemInfo.Architecture = $osInfo.OSArchitecture
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "Error retrieving OS info: $($_.Exception.Message)" -GuiColor "#FF0000"
    }

    try {
        $computerInfo = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $systemInfo.ComputerName = $computerInfo.Name
        $systemInfo.TotalRAM = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "Error retrieving Computer info: $($_.Exception.Message)" -GuiColor "#FF0000"
    }

    try {
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        $systemInfo.TotalDisk = [Math]::Round($diskInfo.Size / 1GB, 0)
        $systemInfo.FreePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "Error retrieving Disk info: $($_.Exception.Message)" -GuiColor "#FF0000"
    }

    # Return the partially filled object, or null if nothing worked
    if ($systemInfo.Keys.Count -gt 0) {
        return [PSCustomObject]$systemInfo
    }
    return $null
}

# =============================================================================
# WPF GUI DEFINITION
# =============================================================================

# Enhanced XAML with logo and improved styling
$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="$($ScriptTitle) - Version $($ScriptVersion)"
    Height="$($WindowHeight)"
    Width="$($WindowWidth)"
    WindowStartupLocation="CenterScreen"
    FontFamily="Cascadia Code">

    <Window.Resources>
        <SolidColorBrush x:Key="BackgroundColor" Color="#FF2D2D2D"/>
        <SolidColorBrush x:Key="HeaderBackgroundColor" Color="#FF1A1A1A"/>
        <SolidColorBrush x:Key="PanelBackgroundColor" Color="#FF3D3D3D"/>
        <SolidColorBrush x:Key="TextColor" Color="#FFFFFFFF"/>
        <SolidColorBrush x:Key="AccentColor" Color="#FF0078D4"/>
        <SolidColorBrush x:Key="SuccessColor" Color="#FF00FF00"/>
        <SolidColorBrush x:Key="WarningColor" Color="#FFFFA500"/>
        <SolidColorBrush x:Key="ErrorColor" Color="#FFFF0000"/>
        <SolidColorBrush x:Key="InfoColor" Color="#FF4FC3F7"/>
        <SolidColorBrush x:Key="ButtonHoverColor" Color="#FF005A9E"/>
        <SolidColorBrush x:Key="ButtonPressedColor" Color="#FF004080"/>
        <SolidColorBrush x:Key="ErrorButtonColor" Color="#FFDC143C"/>
        <SolidColorBrush x:Key="ErrorButtonHoverColor" Color="#FFB22222"/>
        <SolidColorBrush x:Key="ErrorButtonPressedColor" Color="#FF8B0000"/>
        <SolidColorBrush x:Key="BorderColor" Color="#FF0078D4"/>
        <SolidColorBrush x:Key="OutputBackgroundColor" Color="#FF1A1A1A"/>
        <SolidColorBrush x:Key="YellowColor" Color="#FFFFFF00"/>
        <FontFamily x:Key="PrimaryFont">Cascadia Code</FontFamily>
    </Window.Resources>

    <Grid Background="{StaticResource BackgroundColor}">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header with Logo -->
        <Border Grid.Row="0" Background="{StaticResource HeaderBackgroundColor}" Padding="16">
            <StackPanel>
                <!-- Existing Header Grid -->
                <Grid Margin="0,0,0,10">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <!-- Logo -->
                    <Image Grid.Column="0"
                           x:Name="AppLogo"
                           Width="48"
                           Height="48"
                           Margin="0,0,16,0"
                           Stretch="Uniform"/>

                    <!-- Title and Version -->
                    <StackPanel Grid.Column="1" VerticalAlignment="Center">
                        <TextBlock Text="WinToolKit By MagnetarMan"
                                   Foreground="{StaticResource TextColor}"
                                   FontSize="18"
                                   FontWeight="Bold"
                                   FontFamily="{StaticResource PrimaryFont}"
                                   HorizontalAlignment="Center"/>
                        <TextBlock Text="V $($ScriptVersion)"
                                   Foreground="{StaticResource AccentColor}"
                                   FontSize="12"
                                   FontFamily="{StaticResource PrimaryFont}"
                                   HorizontalAlignment="Center"/>
                    </StackPanel>

                    <!-- Send Error Logs Button -->
                    <Button x:Name="SendErrorLogsButton"
                            Grid.Column="2"
                            Background="{StaticResource ErrorButtonColor}"
                            Foreground="{StaticResource TextColor}"
                            FontSize="13"
                            FontFamily="Cascadia Code"
                            Padding="8,4"
                            BorderThickness="0"
                            Cursor="Hand"
                            ToolTip="Invia log di errore a me@magnetarman.com">
                        <Button.Content>
                            <StackPanel Orientation="Horizontal">
                                <Image x:Name="SendErrorLogsImage" Width="24" Height="24" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Invia Log Errori" Foreground="{StaticResource TextColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button.Content>
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border Background="{TemplateBinding Background}"
                                        CornerRadius="8"
                                        Padding="{TemplateBinding Padding}">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter Property="Background" Value="{StaticResource ErrorButtonHoverColor}"/>
                                    </Trigger>
                                    <Trigger Property="IsPressed" Value="True">
                                        <Setter Property="Background" Value="{StaticResource ErrorButtonPressedColor}"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                </Grid>

                <!-- System Information Panel -->
                <Border Background="{StaticResource PanelBackgroundColor}" CornerRadius="8" Padding="12" Margin="0,8,0,0">
                    <StackPanel>
                        <TextBlock Foreground="{StaticResource TextColor}"
                                   FontSize="14"
                                   FontWeight="Bold"
                                   HorizontalAlignment="Center"
                                   Margin="0,0,0,10">
                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                <Image x:Name="SysInfoTitleImage1" Width="16" Height="16" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                <TextBlock Text="INFORMAZIONI SISTEMA" Foreground="{StaticResource TextColor}" FontSize="14" FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                                <Image x:Name="SysInfoTitleImage2" Width="16" Height="16" Margin="4,0,0,0" VerticalAlignment="Center"/>
                            </StackPanel>
                        </TextBlock>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <!-- Left Section: Edition, Version, Architecture -->
                            <Border Grid.Column="0" Background="{StaticResource OutputBackgroundColor}" CornerRadius="6" Padding="8" Margin="0,0,8,0">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>

                                    <!-- Edizione Windows -->
                                    <Grid Grid.Row="0">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" Orientation="Horizontal" Margin="0,1,8,1">
                                            <Image x:Name="SysInfoEditionLabelImage" Width="16" Height="16" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                            <TextBlock Text="Edizione Windows:" Foreground="{StaticResource InfoColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" FontWeight="Bold" VerticalAlignment="Center"/>
                                        </StackPanel>
                                        <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,1,0,1">
                                            <Image x:Name="SysInfoEditionValueImage" Width="16" Height="16" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                            <TextBlock x:Name="SysInfoEdition" Text="Caricamento..." Foreground="{StaticResource TextColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                                        </StackPanel>
                                    </Grid>

                                    <!-- Separatore -->
                                    <Border Grid.Row="1" Height="1" Background="{StaticResource BorderColor}" Margin="2,3,2,3" Opacity="0.3"/>

                                    <!-- Versione -->
                                    <Grid Grid.Row="2">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" Orientation="Horizontal" Margin="0,1,8,1">
                                            <Image x:Name="SysInfoVersionImage" Width="16" Height="16" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                            <TextBlock Text="Versione:" Foreground="{StaticResource InfoColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" FontWeight="Bold" VerticalAlignment="Center"/>
                                        </StackPanel>
                                        <TextBlock Grid.Column="1" x:Name="SysInfoVersion" Text="Caricamento..." Foreground="{StaticResource TextColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" Margin="0,1,0,1" TextAlignment="Right"/>
                                    </Grid>

                                    <!-- Separatore -->
                                    <Border Grid.Row="3" Height="1" Background="{StaticResource BorderColor}" Margin="2,3,2,3" Opacity="0.3"/>

                                    <!-- Architettura -->
                                    <Grid Grid.Row="4">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" Orientation="Horizontal" Margin="0,1,8,1">
                                            <Image x:Name="SysInfoArchitectureImage" Width="16" Height="16" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                            <TextBlock Text="Architettura:" Foreground="{StaticResource InfoColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" FontWeight="Bold" VerticalAlignment="Center"/>
                                        </StackPanel>
                                        <TextBlock Grid.Column="1" x:Name="SysInfoArchitecture" Text="Caricamento..." Foreground="{StaticResource TextColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" Margin="0,1,0,1" TextAlignment="Right"/>
                                    </Grid>
                                </Grid>
                            </Border>

                            <!-- Center Section: Script Compatibility -->
                            <Border Grid.Column="1" Background="{StaticResource OutputBackgroundColor}" CornerRadius="6" Padding="8" Margin="4,0">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>

                                    <!-- Funzionalità Script -->
                                    <Grid Grid.Row="0">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" Orientation="Horizontal" Margin="0,1,8,1">
                                            <Image x:Name="SysInfoScriptImage" Width="16" Height="16" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                            <TextBlock Text="Funzionalità Script:" Foreground="{StaticResource InfoColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" FontWeight="Bold" VerticalAlignment="Center"/>
                                        </StackPanel>
                                        <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,1,0,1">
                                            <Border x:Name="ScriptCompatibilityIndicator"
                                                    Width="16" Height="16" CornerRadius="7"
                                                    BorderBrush="{StaticResource AccentColor}"
                                                    BorderThickness="1"
                                                    Background="{StaticResource TextColor}"
                                                    Margin="0,0,6,0"/>
                                            <TextBlock x:Name="SysInfoScriptCompatibility"
                                                       Text="Caricamento..."
                                                       Foreground="{StaticResource TextColor}"
                                                       FontSize="13"
                                                       FontFamily="{StaticResource PrimaryFont}"
                                                       VerticalAlignment="Center"
                                                       TextWrapping="Wrap"
                                                       MaxWidth="300"/>
                                        </StackPanel>
                                    </Grid>
                                </Grid>
                            </Border>

                            <!-- Right Section: Computer Name, RAM, Disk -->
                            <Border Grid.Column="2" Background="{StaticResource OutputBackgroundColor}" CornerRadius="6" Padding="8" Margin="8,0,0,0">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>

                                    <!-- Nome PC -->
                                    <Grid Grid.Row="0">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" Orientation="Horizontal" Margin="0,1,8,1">
                                            <Image x:Name="SysInfoComputerNameImage" Width="16" Height="16" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                            <TextBlock Text="Nome PC:" Foreground="{StaticResource InfoColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" FontWeight="Bold" VerticalAlignment="Center"/>
                                        </StackPanel>
                                        <TextBlock Grid.Column="1" x:Name="SysInfoComputerName" Text="Caricamento..." Foreground="{StaticResource TextColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" Margin="0,1,0,1" TextAlignment="Right"/>
                                    </Grid>

                                    <!-- Separatore -->
                                    <Border Grid.Row="1" Height="1" Background="{StaticResource BorderColor}" Margin="2,3,2,3" Opacity="0.3"/>

                                    <!-- RAM -->
                                    <Grid Grid.Row="2">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" Orientation="Horizontal" Margin="0,1,8,1">
                                            <Image x:Name="SysInfoRAMImage" Width="16" Height="16" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                            <TextBlock Text="RAM:" Foreground="{StaticResource InfoColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" FontWeight="Bold" VerticalAlignment="Center"/>
                                        </StackPanel>
                                        <TextBlock Grid.Column="1" x:Name="SysInfoRAM" Text="Caricamento..." Foreground="{StaticResource TextColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" Margin="0,1,0,1" TextAlignment="Right"/>
                                    </Grid>

                                    <!-- Separatore -->
                                    <Border Grid.Row="3" Height="1" Background="{StaticResource BorderColor}" Margin="2,3,2,3" Opacity="0.3"/>

                                    <!-- Disco -->
                                    <Grid Grid.Row="4">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" Orientation="Horizontal" Margin="0,1,8,1">
                                            <Image x:Name="SysInfoDiskImage" Width="16" Height="16" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                            <TextBlock Text="Disco:" Foreground="{StaticResource InfoColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" FontWeight="Bold" VerticalAlignment="Center"/>
                                        </StackPanel>
                                        <TextBlock Grid.Column="1" x:Name="SysInfoDisk" Text="Caricamento..." Foreground="{StaticResource TextColor}" FontSize="13" FontFamily="{StaticResource PrimaryFont}" Margin="0,1,0,1" TextAlignment="Right"/>
                                    </Grid>
                                </Grid>
                            </Border>
                        </Grid>
                    </StackPanel>
                </Border>
            </StackPanel>
        </Border>

        <!-- Main Content -->
        <Grid Grid.Row="1" Margin="16">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>


            <!-- Content Area -->
            <Grid Grid.Row="1">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="500"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- Left Panel - Actions -->
                <Border Grid.Column="0" Background="{StaticResource PanelBackgroundColor}" CornerRadius="8" Margin="0,0,8,0">
                    <Grid Margin="8">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <TextBlock Grid.Row="0" Foreground="{StaticResource TextColor}"
                                   FontSize="14"
                                   FontWeight="Bold"
                                   FontFamily="{StaticResource PrimaryFont}"
                                   Margin="0,0,0,12">
                            <StackPanel Orientation="Horizontal">
                                <Image x:Name="FunzioniDisponibiliImage" Width="16" Height="16" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Funzioni Disponibili" Foreground="{StaticResource TextColor}" FontSize="14" FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                            </StackPanel>
                        </TextBlock>

                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                            <StackPanel x:Name="ActionsPanel" Margin="0,0,0,8"/>
                        </ScrollViewer>
                    </Grid>
                </Border>

                <!-- Right Panel - Output and Log -->
                <Border Grid.Column="1" Background="{StaticResource PanelBackgroundColor}" CornerRadius="8">
                    <Grid Margin="8">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <TextBlock Grid.Row="0" Foreground="{StaticResource TextColor}"
                                   FontSize="14"
                                   FontWeight="Bold"
                                   FontFamily="{StaticResource PrimaryFont}"
                                   Margin="0,0,0,8">
                            <StackPanel Orientation="Horizontal">
                                <Image x:Name="OutputLogImage" Width="16" Height="16" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Output e Log" Foreground="{StaticResource TextColor}" FontSize="14" FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                            </StackPanel>
                        </TextBlock>

                        <RichTextBox x:Name="OutputTextBox"
                                     Grid.Row="1"
                                     Background="{StaticResource OutputBackgroundColor}"
                                     Foreground="{StaticResource TextColor}"
                                     BorderBrush="{StaticResource BorderColor}"
                                     BorderThickness="1"
                                     IsReadOnly="True"
                                     FontFamily="{StaticResource PrimaryFont}"/>
                    </Grid>
                </Border>
            </Grid>
        </Grid>

        <!-- Bottom Section - Execute Button -->
        <Border Grid.Row="2" Background="{StaticResource HeaderBackgroundColor}" CornerRadius="8" Margin="16,8,16,16">
            <Button x:Name="ExecuteButton"
                    Background="{StaticResource AccentColor}"
                    Foreground="{StaticResource TextColor}"
                    FontSize="16"
                    FontWeight="Bold"
                    FontFamily="{StaticResource PrimaryFont}"
                    Padding="20,12"
                    BorderThickness="0"
                    HorizontalAlignment="Center"
                    Cursor="Hand"
                    Margin="16">
                <Button.Content>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                        <Image x:Name="ExecuteButtonImage" Width="20" Height="20" Margin="0,0,8,0" VerticalAlignment="Center"/>
                        <TextBlock Text="Esegui Script" Foreground="{StaticResource TextColor}" FontSize="16" FontWeight="Bold" FontFamily="{StaticResource PrimaryFont}" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button.Content>
                <Button.Template>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="8"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="{StaticResource ButtonHoverColor}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="{StaticResource ButtonPressedColor}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Button.Template>
            </Button>
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
    exit
}

# Get controls
$appLogo = $window.FindName("AppLogo")
$actionsPanel = $window.FindName("ActionsPanel")
$outputTextBox = $window.FindName("OutputTextBox")
$executeButton = $window.FindName("ExecuteButton")
$executeButtonImage = $window.FindName("ExecuteButtonImage")
$sendErrorLogsButton = $window.FindName("SendErrorLogsButton")
$sendErrorLogsImage = $window.FindName("SendErrorLogsImage")
$funzioniDisponibiliImage = $window.FindName("FunzioniDisponibiliImage")
$outputLogImage = $window.FindName("OutputLogImage")
$sysInfoTitleImage1 = $window.FindName("SysInfoTitleImage1")
$sysInfoTitleImage2 = $window.FindName("SysInfoTitleImage2")
$sysInfoEditionLabelImage = $window.FindName("SysInfoEditionLabelImage")
$sysInfoEditionValueImage = $window.FindName("SysInfoEditionValueImage")
$sysInfoVersionImage = $window.FindName("SysInfoVersionImage")
$sysInfoScriptImage = $window.FindName("SysInfoScriptImage")
$sysInfoArchitectureImage = $window.FindName("SysInfoArchitectureImage")
$sysInfoComputerNameImage = $window.FindName("SysInfoComputerNameImage")
$sysInfoRAMImage = $window.FindName("SysInfoRAMImage")
$sysInfoDiskImage = $window.FindName("SysInfoDiskImage")
$SysInfoEdition = $window.FindName("SysInfoEdition")
$SysInfoVersion = $window.FindName("SysInfoVersion")
$SysInfoArchitecture = $window.FindName("SysInfoArchitecture")
$SysInfoComputerName = $window.FindName("SysInfoComputerName")
$SysInfoRAM = $window.FindName("SysInfoRAM")
$SysInfoDisk = $window.FindName("SysInfoDisk")
$SysInfoScriptCompatibility = $window.FindName("SysInfoScriptCompatibility")
$ScriptCompatibilityIndicator = $window.FindName("ScriptCompatibilityIndicator")

# Load and set logos and emoji images
try {
    $logoPath = "$PSScriptRoot\img\WinToolkit.ico"
    if (Test-Path $logoPath) {
        $appLogo.Source = New-Object System.Windows.Media.Imaging.BitmapImage
        $appLogo.Source.BeginInit()
        $appLogo.Source.UriSource = New-Object System.Uri($logoPath)
        $appLogo.Source.EndInit()

        Write-UnifiedLog -Type 'Success' -Message "Logos loaded successfully" -GuiColor "#00FF00"
    }
    else {
        Write-UnifiedLog -Type 'Warning' -Message "Logo file not found: $logoPath" -GuiColor "#FFA500"
    }

    # Load emoji images for static elements
    $emojiMappings = @{
        "SendErrorLogsImage"       = "📡"
        "FunzioniDisponibiliImage" = "⚙️"
        "OutputLogImage"           = "📋"
        "ExecuteButtonImage"       = "▶️"
        "SysInfoTitleImage1"       = "🖥️"
        "SysInfoTitleImage2"       = "🖥️"
        "SysInfoEditionLabelImage" = "💻"
        "SysInfoEditionValueImage" = ""
        "SysInfoVersionImage"      = "📊"
        "SysInfoScriptImage"       = "✨"
        "SysInfoArchitectureImage" = "⚡"
        "SysInfoComputerNameImage" = "🏷️"
        "SysInfoRAMImage"          = "🧠"
        "SysInfoDiskImage"         = "💾"
    }

    foreach ($mapping in $emojiMappings.GetEnumerator()) {
        $imageControl = Get-Variable -Name $mapping.Key -ValueOnly -ErrorAction SilentlyContinue
        if ($imageControl) {
            $iconPath = Get-EmojiIconPath -EmojiCharacter $mapping.Value
            if ($iconPath -and (Test-Path $iconPath)) {
                try {
                    $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
                    $bitmapImage.BeginInit()
                    $bitmapImage.UriSource = [System.Uri]($iconPath)
                    $bitmapImage.EndInit()
                    $imageControl.Source = $bitmapImage
                    Write-UnifiedLog -Type 'Success' -Message "Loaded emoji image for $($mapping.Key): $iconPath" -GuiColor "#00FF00"
                }
                catch {
                    Write-UnifiedLog -Type 'Warning' -Message "Failed to load emoji image for $($mapping.Key): $($_.Exception.Message)" -GuiColor "#FFA500"
                    $imageControl.Visibility = 'Collapsed'
                }
            }
            else {
                Write-UnifiedLog -Type 'Warning' -Message "Emoji icon file not found for $($mapping.Key): $iconPath" -GuiColor "#FFA500"
                $imageControl.Visibility = 'Collapsed'
            }
        }
    }
}
catch {
    Write-UnifiedLog -Type 'Warning' -Message "Error loading logos or emoji images: $($_.Exception.Message)" -GuiColor "#FFA500"
}

if (-not $appLogo) {
    Write-UnifiedLog -Type 'Warning' -Message "AppLogo not found" -GuiColor "#FFA500"
}
if (-not $actionsPanel) {
    Write-UnifiedLog -Type 'Warning' -Message "ActionsPanel not found" -GuiColor "#FFA500"
}
if (-not $outputTextBox) {
    Write-UnifiedLog -Type 'Warning' -Message "OutputTextBox not found" -GuiColor "#FFA500"
}
if (-not $executeButton) {
    Write-UnifiedLog -Type 'Warning' -Message "ExecuteButton not found" -GuiColor "#FFA500"
}
if (-not $sendErrorLogsButton) {
    Write-UnifiedLog -Type 'Warning' -Message "SendErrorLogsButton not found" -GuiColor "#FFA500"
}
if (-not $SysInfoEditionLabelImage) {
    Write-UnifiedLog -Type 'Warning' -Message "SysInfoEditionLabelImage not found" -GuiColor "#FFA500"
}
if (-not $SysInfoEditionValueImage) {
    Write-UnifiedLog -Type 'Warning' -Message "SysInfoEditionValueImage not found" -GuiColor "#FFA500"
}
if (-not $SysInfoEdition) {
    Write-UnifiedLog -Type 'Warning' -Message "SysInfoEdition not found" -GuiColor "#FFA500"
}
if (-not $SysInfoVersion) {
    Write-UnifiedLog -Type 'Warning' -Message "SysInfoVersion not found" -GuiColor "#FFA500"
}
if (-not $SysInfoArchitectureImage) {
    Write-UnifiedLog -Type 'Warning' -Message "SysInfoArchitectureImage not found" -GuiColor "#FFA500"
}
if (-not $SysInfoArchitecture) {
    Write-UnifiedLog -Type 'Warning' -Message "SysInfoArchitecture not found" -GuiColor "#FFA500"
}
if (-not $SysInfoComputerName) {
    Write-UnifiedLog -Type 'Warning' -Message "SysInfoComputerName not found" -GuiColor "#FFA500"
}
if (-not $SysInfoRAM) {
    Write-UnifiedLog -Type 'Warning' -Message "SysInfoRAM not found" -GuiColor "#FFA500"
}
if (-not $SysInfoDisk) {
    Write-UnifiedLog -Type 'Warning' -Message "SysInfoDisk not found" -GuiColor "#FFA500"
}
if (-not $SysInfoScriptCompatibility) {
    Write-UnifiedLog -Type 'Warning' -Message "SysInfoScriptCompatibility not found" -GuiColor "#FFA500"
}
if (-not $ScriptCompatibilityIndicator) {
    Write-UnifiedLog -Type 'Warning' -Message "ScriptCompatibilityIndicator not found" -GuiColor "#FFA500"
}


# Function to update the system information panel in the GUI
function Update-SystemInformationPanel {
    try {
        # Initialize UI elements with a loading state on the UI thread
        $window.Dispatcher.Invoke([Action] {
                $SysInfoEdition.Text = "Caricamento..."
                $SysInfoVersion.Text = "Caricamento..."
                $SysInfoArchitecture.Text = "Caricamento..."
                $SysInfoComputerName.Text = "Caricamento..."
                $SysInfoRAM.Text = "Caricamento..."
                $SysInfoDisk.Text = "Caricamento..."
                $SysInfoScriptCompatibility.Text = "Caricamento..."

                # Reset specific images/indicators
                $SysInfoEditionValueImage.Source = $null # Clear existing image
                $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::White) # Default
                $ScriptCompatibilityIndicator.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Gray) # Default indicator color
            })

        $sysInfo = Get-SystemInfo
        if (-not $sysInfo) {
            Write-UnifiedLog -Type 'Error' -Message "Failed to retrieve system information." -GuiColor "#FF0000"
            $window.Dispatcher.Invoke([Action] {
                    $SysInfoEdition.Text = "N/A"
                    $SysInfoVersion.Text = "N/A"
                    $SysInfoArchitecture.Text = "N/A"
                    $SysInfoComputerName.Text = "N/A"
                    $SysInfoRAM.Text = "N/A"
                    $SysInfoDisk.Text = "N/A"
                    $SysInfoScriptCompatibility.Text = "Errore di recupero"

                    $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Red)
                    $ScriptCompatibilityIndicator.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Red)
                })
            return
        }

        $buildNumber = $sysInfo.BuildNumber
        $windowsVersion = Get-WindowsVersion $buildNumber

        # Edition detection and emoji
        $windowsEditionEmoji = ""
        $windowsEditionText = $sysInfo.ProductName -replace 'Microsoft ', ''
        switch -Wildcard ($sysInfo.ProductName) {
            "*Home*" { $windowsEditionEmoji = "🏠"; $windowsEditionText = "Home" }
            "*Pro*" { $windowsEditionEmoji = "💼"; $windowsEditionText = "Professional" }
            "*Enterprise*" { $windowsEditionEmoji = "🏢"; $windowsEditionText = "Enterprise" }
            "*Education*" { $windowsEditionEmoji = "🎓"; $windowsEditionText = "Education" }
            "*Server*" { $windowsEditionEmoji = "🖥️"; $windowsEditionText = "Server" }
            default { $windowsEditionEmoji = "💻"; $windowsEditionText = $sysInfo.ProductName } # Fallback, keep full product name
        }

        # Determine Script Compatibility based on WinOSCheck logic
        $scriptCompatibilityText = "Non rilevato"
        $scriptCompatibilityDescription = ""
        $scriptCompatibilityColor = [System.Windows.Media.Colors]::White # Default color

        $isWin11 = $buildNumber -ge 22000
        $isWin10 = ($buildNumber -ge 10240) -and ($buildNumber -lt 22000)
        $isWin81 = $buildNumber -eq 9600
        $isWin8 = $buildNumber -eq 9200

        if ($isWin11 -and $buildNumber -ge 22621) {
            $scriptCompatibilityText = "Completa"
            $scriptCompatibilityDescription = "Massima velocità ed efficienza"
            $scriptCompatibilityColor = [System.Windows.Media.Color]::FromArgb(0xFF, 0x00, 0xFF, 0x00) # Success (LimeGreen)
        }
        elseif ($isWin11 -and $buildNumber -ge 22000) {
            $scriptCompatibilityText = "Compatibile con eccezioni"
            $scriptCompatibilityDescription = "Supporto completo con lievi ottimizzazioni"
            $scriptCompatibilityColor = [System.Windows.Media.Color]::FromArgb(0xFF, 0xFF, 0xFF, 0x00) # Yellow
        }
        elseif ($isWin10 -and $buildNumber -ge 17763) {
            $scriptCompatibilityText = "Completa"
            $scriptCompatibilityDescription = "Massima velocità ed efficienza"
            $scriptCompatibilityColor = [System.Windows.Media.Color]::FromArgb(0xFF, 0x00, 0xFF, 0x00) # Success (LimeGreen)
        }
        elseif ($isWin10 -and $buildNumber -lt 17763) {
            $scriptCompatibilityText = "Sconsigliata (troppo vecchia)"
            $scriptCompatibilityDescription = "Possibili problemi di affidabilità"
            $scriptCompatibilityColor = [System.Windows.Media.Color]::FromArgb(0xFF, 0xFF, 0x00, 0x00) # Error (Red)
        }
        elseif ($isWin81) {
            $scriptCompatibilityText = "Parziale (obsoleta)"
            $scriptCompatibilityDescription = "Funzionamento con workaround"
            $scriptCompatibilityColor = [System.Windows.Media.Color]::FromArgb(0xFF, 0xFF, 0xA5, 0x00) # Warning (Orange)
        }
        elseif ($isWin8) {
            $scriptCompatibilityText = "Non supportata (obsoleta)"
            $scriptCompatibilityDescription = "Gravi problemi di affidabilità"
            $scriptCompatibilityColor = [System.Windows.Media.Color]::FromArgb(0xFF, 0xFF, 0x00, 0x00) # Error (Red)
        }
        else {
            $scriptCompatibilityText = "Estremamente obsoleta (non supportata)"
            $scriptCompatibilityDescription = "Funzionalità limitate o nulle"
            $scriptCompatibilityColor = [System.Windows.Media.Color]::FromArgb(0xFF, 0x8B, 0x00, 0x00) # DarkRed custom color
        }

        # Update GUI elements on the UI thread
        $window.Dispatcher.Invoke([Action] {
                $SysInfoEdition.Text = $windowsEditionText
                if ($SysInfoEditionValueImage -and $windowsEditionEmoji) {
                    $iconPath = Get-EmojiIconPath -EmojiCharacter $windowsEditionEmoji
                    if ($iconPath -and (Test-Path $iconPath)) {
                        try {
                            $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
                            $bitmapImage.BeginInit()
                            $bitmapImage.UriSource = [System.Uri]($iconPath)
                            $bitmapImage.EndInit()
                            $SysInfoEditionValueImage.Source = $bitmapImage
                            $SysInfoEditionValueImage.Visibility = 'Visible'
                        }
                        catch {
                            Write-UnifiedLog -Type 'Warning' -Message "Failed to load edition emoji image: $($_.Exception.Message)" -GuiColor "#FFA500"
                            $SysInfoEditionValueImage.Visibility = 'Collapsed'
                        }
                    }
                    else {
                        Write-UnifiedLog -Type 'Warning' -Message "Edition emoji icon file not found: $iconPath" -GuiColor "#FFA500"
                        $SysInfoEditionValueImage.Visibility = 'Collapsed'
                    }
                }
                else {
                    $SysInfoEditionValueImage.Visibility = 'Collapsed' # Hide if no emoji
                }

                $SysInfoVersion.Text = "Ver. $windowsVersion (Build $buildNumber)"
                $SysInfoArchitecture.Text = $sysInfo.Architecture
                $SysInfoComputerName.Text = $sysInfo.ComputerName
                $SysInfoRAM.Text = "$($sysInfo.TotalRAM) GB"
                $SysInfoDisk.Text = "$($sysInfo.FreePercentage)% Libero ($($sysInfo.TotalDisk) GB)"
                $SysInfoScriptCompatibility.Text = "$scriptCompatibilityText - $scriptCompatibilityDescription"

                $SysInfoScriptCompatibility.Foreground = New-Object System.Windows.Media.SolidColorBrush($scriptCompatibilityColor)
                $ScriptCompatibilityIndicator.Background = New-Object System.Windows.Media.SolidColorBrush($scriptCompatibilityColor)
            })
        Write-UnifiedLog -Type 'Success' -Message "System information panel updated." -GuiColor "#00FF00"
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "Error updating system information panel: $($_.Exception.Message)" -GuiColor "#FF0000"
    }
}


# Function to send error logs via email (improved version)
function Send-ErrorLogs {
    try {
        $logDir = $LogDirectory
        $logFiles = Get-ChildItem -Path $logDir -Filter "*.log" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

        if ($logFiles.Count -eq 0) {
            Write-UnifiedLog -Type 'Warning' -Message "No error logs found to send." -GuiColor "#FFA500"
            return
        }

        Write-UnifiedLog -Type 'Info' -Message "Preparing error logs for sending..." -GuiColor "#00CED1"

        # Generate timestamp for zip file
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $zipFileName = "WinToolkit_Logs_$timestamp.zip"
        $zipFilePath = Join-Path $logDir $zipFileName

        # Create zip file with logs
        try {
            # Filter out files that might be in use or not readable
            $validLogFiles = $logFiles | Where-Object {
                try {
                    # Test if file is readable and not in use
                    $fileStream = [System.IO.File]::Open($_, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
                    $fileStream.Close()
                    return $true
                }
                catch {
                    Write-UnifiedLog -Type 'Warning' -Message "Skipping file $($_.Name): $($_.Exception.Message)" -GuiColor "#FFA500"
                    return $false
                }
            }

            if ($validLogFiles.Count -eq 0) {
                Write-UnifiedLog -Type 'Warning' -Message "No valid log files found to compress." -GuiColor "#FFA500"
                return
            }

            Compress-Archive -Path $validLogFiles -DestinationPath $zipFilePath -Force
            Write-UnifiedLog -Type 'Success' -Message "Error logs compressed to: $zipFilePath" -GuiColor "#00FF00"
        }
        catch {
            Write-UnifiedLog -Type 'Error' -Message "Failed to create zip file: $($_.Exception.Message)" -GuiColor "#FF0000"
            return
        }

        # Open the directory containing the zip file
        try {
            Start-Process $logDir
            Write-UnifiedLog -Type 'Info' -Message "Opened log folder. Please manually attach the file '$zipFileName' to an email." -GuiColor "#00CED1"
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message "Could not open log folder: $($_.Exception.Message)" -GuiColor "#FFA500"
        }

        # Provide a simple mailto link (without attachments for reliability)
        try {
            $mailto = "mailto:$($SupportEmail)?subject=WinToolkit - Error Logs&body=Error logs attached manually from WinToolkit GUI"
            Start-Process $mailto
            Write-UnifiedLog -Type 'Info' -Message "Email client opened for manual attachment." -GuiColor "#00CED1"
        }
        catch {
            Write-UnifiedLog -Type 'Warning' -Message "Could not open email client: $($_.Exception.Message)" -GuiColor "#FFA500"
        }
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "Error during log preparation: $($_.Exception.Message)" -GuiColor "#FF0000"
    }
}

# Function to populate actions panel
function Update-ActionsPanel {
    try {
        $window.Dispatcher.Invoke([Action] {
                $actionsPanel.Children.Clear()

                $functions = @(
                    @{ Name = "WinInstallPSProfile"; Description = "💙 Installa profilo PowerShell - oh-my-posh, zoxide e configurazioni avanzate" },
                    @{ Name = "WinRepairToolkit"; Description = "🔧 Toolkit Riparazione Windows - chkdsk, SFC, DISM e controlli approfonditi" },
                    @{ Name = "WinUpdateReset"; Description = "🔄 Reset Windows Update - ripristina componenti e servizi di aggiornamento" },
                    @{ Name = "WinReinstallStore"; Description = "🛒 Winget/WinStore Reset - reinstalla Microsoft Store e gestore pacchetti" },
                    @{ Name = "WinBackupDriver"; Description = "💾 Backup Driver PC - esporta tutti i driver di terze parti in archivio" },
                    @{ Name = "WinCleaner"; Description = "🧹 Pulizia File Temporanei - rimuove cache, log e file inutili dal sistema" },
                    @{ Name = "OfficeToolkit"; Description = "📊 Office Toolkit - gestisce installazione, riparazione e rimozione Office" },
                    @{ Name = "SetRustDesk"; Description = "🖥️ Setting RustDesk - configura controllo remoto con modalità MagnetarMan" }
                )

                foreach ($function in $functions) {
                    $checkBox = New-Object System.Windows.Controls.CheckBox

                    # Estrai emoji e testo dalla descrizione
                    $splitResult = Split-EmojiAndText -InputString $function.Description
                    $emoji = $splitResult.Emoji
                    $text = $splitResult.Text

                    # Crea il contenuto dinamico (StackPanel, Image, TextBlock)
                    $stackPanel = New-Object System.Windows.Controls.StackPanel
                    $stackPanel.Orientation = 'Horizontal'

                    # Crea l'immagine solo se abbiamo un emoji valido
                    if ($emoji -and $emoji.Length -gt 0) {
                        $image = New-Object System.Windows.Controls.Image
                        $image.Width = 16
                        $image.Height = 16
                        $image.Margin = '0,0,8,0'

                        # Ottieni il percorso dell'icona
                        $iconPath = Get-EmojiIconPath -EmojiCharacter $emoji

                        if ($iconPath -and (Test-Path $iconPath)) {
                            try {
                                $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
                                $bitmapImage.BeginInit()
                                $bitmapImage.UriSource = [System.Uri]($iconPath)
                                $bitmapImage.EndInit()
                                $image.Source = $bitmapImage

                                Write-UnifiedLog -Type 'Success' -Message "Icon loaded successfully for $($function.Name): $iconPath" -GuiColor "#00FF00"
                            }
                            catch {
                                Write-UnifiedLog -Type 'Warning' -Message "Failed to load icon for $($function.Name): $($_.Exception.Message)" -GuiColor "#FFA500"
                                # Se l'immagine non si carica, nascondila
                                $image.Visibility = 'Collapsed'
                            }
                        }
                        else {
                            Write-UnifiedLog -Type 'Warning' -Message "Icon file not found for $($function.Name): $iconPath" -GuiColor "#FFA500"
                            # Se il file non esiste, nascondi l'immagine
                            $image.Visibility = 'Collapsed'
                        }

                        $stackPanel.Children.Add($image) | Out-Null
                    }

                    # Crea il TextBlock con il testo
                    $textBlock = New-Object System.Windows.Controls.TextBlock
                    $textBlock.Text = $text
                    $textBlock.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(0xFF, 0xFF, 0xFF, 0xFF))
                    $textBlock.FontSize = 13
                    $textBlock.FontFamily = [System.Windows.Media.FontFamily]::new("Cascadia Code")
                    $textBlock.TextWrapping = [System.Windows.TextWrapping]::Wrap
                    $textBlock.Margin = "4"
                    $textBlock.Padding = "2"
                    $textBlock.VerticalAlignment = 'Center'
                    $textBlock.MaxWidth = 400

                    $stackPanel.Children.Add($textBlock) | Out-Null

                    $checkBox.Content = $stackPanel
                    $checkBox.Tag = $function.Name

                    $actionsPanel.Children.Add($checkBox) | Out-Null

                    # Add green separator after each checkbox (except for the last one)
                    if ($function -ne $functions[-1]) {
                        $separator = New-Object System.Windows.Controls.Border
                        $separator.Height = 2
                        $separator.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(0xFF, 0x00, 0xFF, 0x00)) # Green color
                        $separator.Margin = "4,2,4,8"
                        $actionsPanel.Children.Add($separator) | Out-Null
                    }
                }
            })

        Write-UnifiedLog -Type 'Success' -Message "Actions panel updated with emoji icons" -GuiColor "#00FF00"
    }
    catch {
        Write-UnifiedLog -Type 'Error' -Message "Error updating actions panel: $($_.Exception.Message)" -GuiColor "#FF0000"
    }
}

# Async script execution function to prevent UI blocking
function Execute-ScriptAsync {
    try {
        # Disable button to prevent re-execution
        $window.Dispatcher.Invoke([Action] { $executeButton.IsEnabled = $false })
        Write-UnifiedLog -Type 'Info' -Message "Starting script execution in background..." -GuiColor "#00CED1"

        # Get selected checkboxes
        $selectedCheckboxes = $window.Dispatcher.Invoke([Func[object]] {
                $result = @()
                foreach ($child in $actionsPanel.Children) {
                    if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                        $result += $child.Tag
                    }
                }
                return $result
            })

        if ($selectedCheckboxes.Count -eq 0) {
            $window.Dispatcher.Invoke([Action] { $executeButton.IsEnabled = $true })
            Write-UnifiedLog -Type 'Warning' -Message "No functions selected!" -GuiColor "#FFA500"
            return
        }

        Write-UnifiedLog -Type 'Info' -Message "Starting execution of $($selectedCheckboxes.Count) selected function(s)..." -GuiColor "#00CED1"

        # Start a background job
        $job = Start-Job -ScriptBlock {
            param($selectedFunctions, $scriptRoot, $mainLog)

            # Function to send output back to main thread
            function Write-JobOutput {
                param($message, $color, $type = 'Output')
                Write-Output ([PSCustomObject]@{ Message = $message; Color = $color; Type = $type })
            }

            $totalFunctions = $selectedFunctions.Count
            $completedFunctions = 0

            foreach ($functionName in $selectedFunctions) {
                $completedFunctions++
                Write-JobOutput -Message "[$completedFunctions/$totalFunctions] Executing: $functionName" -Color "#00CED1" -Type 'Progress'

                try {
                    switch ($functionName) {
                        "WinInstallPSProfile" {
                            Write-JobOutput -Message "Executing WinInstallPSProfile logic..." -Color "#ADD8E6" -Type 'Info'
                            # Simulate work - replace with actual function call
                            Start-Sleep -Seconds 2
                        }
                        "WinRepairToolkit" {
                            Write-JobOutput -Message "Executing WinRepairToolkit logic..." -Color "#ADD8E6" -Type 'Info'
                            Start-Sleep -Seconds 3
                        }
                        "WinUpdateReset" {
                            Write-JobOutput -Message "Executing WinUpdateReset logic..." -Color "#ADD8E6" -Type 'Info'
                            Start-Sleep -Seconds 2
                        }
                        "WinReinstallStore" {
                            Write-JobOutput -Message "Executing WinReinstallStore logic..." -Color "#ADD8E6" -Type 'Info'
                            Start-Sleep -Seconds 4
                        }
                        "WinBackupDriver" {
                            Write-JobOutput -Message "Executing WinBackupDriver logic..." -Color "#ADD8E6" -Type 'Info'
                            Start-Sleep -Seconds 3
                        }
                        "WinCleaner" {
                            Write-JobOutput -Message "Executing WinCleaner logic..." -Color "#ADD8E6" -Type 'Info'
                            Start-Sleep -Seconds 5
                        }
                        "OfficeToolkit" {
                            Write-JobOutput -Message "Executing OfficeToolkit logic..." -Color "#ADD8E6" -Type 'Info'
                            Start-Sleep -Seconds 4
                        }
                        "SetRustDesk" {
                            Write-JobOutput -Message "Executing SetRustDesk logic..." -Color "#ADD8E6" -Type 'Info'
                            Start-Sleep -Seconds 2
                        }
                        default {
                            Write-JobOutput -Message "Unknown function: $functionName" -Color "#FFA500" -Type 'Warning'
                        }
                    }
                    Write-JobOutput -Message "Completed: $functionName" -Color "#00FF00" -Type 'Success'
                }
                catch {
                    Write-JobOutput -Message "Error in $functionName`: $($_.Exception.Message)" -Color "#FF0000" -Type 'Error'
                }
            }
            Write-JobOutput -Message "Script execution completed!" -Color "#00FF00" -Type 'Success'
        } -ArgumentList $selectedCheckboxes, $PSScriptRoot, $mainLog -ErrorAction Stop

        # Register a handler to process job output
        Register-ObjectEvent -InputObject $job -EventName StateChanged -Action {
            if ($job.State -eq 'Completed' -or $job.State -eq 'Failed' -or $job.State -eq 'Stopped') {
                try {
                    # Process results from the job
                    $jobOutput = Receive-Job -Job $job -Keep
                    foreach ($item in $jobOutput) {
                        if ($item -is [PSCustomObject] -and $item.Type -eq 'Output') {
                            $window.Dispatcher.Invoke([Action] {
                                    $paragraph = New-Object System.Windows.Documents.Paragraph
                                    $run = New-Object System.Windows.Documents.Run
                                    $run.Text = "$(Get-Date -Format 'HH:mm:ss'): $($item.Message)"
                                    $run.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($item.Color))
                                    $paragraph.Inlines.Add($run)
                                    $outputTextBox.Document.Blocks.Add($paragraph)
                                    $outputTextBox.ScrollToEnd()
                                })
                        }
                    }

                    # Clean up
                    Remove-Job -Job $job -Force
                    $window.Dispatcher.Invoke([Action] { $executeButton.IsEnabled = $true })
                    Write-UnifiedLog -Type 'Success' -Message "Script execution finished." -GuiColor "#00FF00"
                }
                catch {
                    Write-UnifiedLog -Type 'Error' -Message "Error processing job results: $($_.Exception.Message)" -GuiColor "#FF0000"
                }
                finally {
                    # Clean up event registration
                    Unregister-Event -SourceIdentifier $job.Id -ErrorAction SilentlyContinue
                }
            }
        } -SourceIdentifier "JobStateChanged_$($job.Id)"
    }
    catch {
        # Re-enable button if there was an error
        try { $window.Dispatcher.Invoke([Action] { $executeButton.IsEnabled = $true }) } catch {}
        Write-UnifiedLog -Type 'Error' -Message "Error starting script execution: $($_.Exception.Message)" -GuiColor "#FF0000"
    }
}

# Legacy synchronous function for backward compatibility
function Execute-Script {
    Execute-ScriptAsync
}

# =============================================================================
# APPLICATION LOGIC
# =============================================================================

# Event handlers
try {
    $executeButton.Add_Click({
            try {
                Execute-Script
            }
            catch {
                Write-UnifiedLog -Type 'Error' -Message "Error in execute script: $($_.Exception.Message)" -GuiColor "#FF0000"
            }
        })

    $sendErrorLogsButton.Add_Click({
            try {
                Send-ErrorLogs
            }
            catch {
                Write-UnifiedLog -Type 'Error' -Message "Error sending error logs: $($_.Exception.Message)" -GuiColor "#FF0000"
            }
        })

    Write-UnifiedLog -Type 'Success' -Message "Event handlers registered" -GuiColor "#00FF00"
}
catch {
    Write-UnifiedLog -Type 'Error' -Message "Error registering event handlers: $($_.Exception.Message)" -GuiColor "#FF0000"
}

# Window loaded event
$window.Add_Loaded({
        try {
            Write-UnifiedLog -Type 'Info' -Message "Window loaded, initializing..." -GuiColor "#00CED1"

            Update-ActionsPanel
            Update-SystemInformationPanel # Add this line
            Write-UnifiedLog -Type 'Info' -Message "$($ScriptTitle) - V $($ScriptVersion)" -GuiColor "#00FF00"
            Write-UnifiedLog -Type 'Success' -Message "GUI initialized successfully" -GuiColor "#00FF00"
        }
        catch {
            Write-UnifiedLog -Type 'Error' -Message "Error initializing GUI: $($_.Exception.Message)" -GuiColor "#FF0000"
        }
    })

# Show window
try {
    Write-UnifiedLog -Type 'Info' -Message "Showing GUI window..." -GuiColor "#00CED1"
    $window.ShowDialog() | Out-Null
    Write-UnifiedLog -Type 'Success' -Message "GUI closed normally" -GuiColor "#00FF00"
}
catch {
    Write-UnifiedLog -Type 'Error' -Message "Error showing GUI: $($_.Exception.Message)" -GuiColor "#FF0000"
}

# Cleanup
try {
    # Stop transcript and close any open file handles
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null

    # Small delay to ensure file handles are released
    Start-Sleep -Milliseconds 500

    Write-UnifiedLog -Type 'Success' -Message "Cleanup completed" -GuiColor "#00FF00"
}
catch {
    Write-UnifiedLog -Type 'Warning' -Message "Failed to stop transcript during cleanup: $($_.Exception.Message)" -GuiColor "#FFA500"
}

Write-Host ""
Write-Host "$($ScriptTitle) - V $($ScriptVersion)" -ForegroundColor Cyan
Write-Host "Log file: $mainLog" -ForegroundColor Cyan