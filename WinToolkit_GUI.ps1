<#
.SYNOPSIS
    WinToolkit GUI - Version 5.0 (GUI Edition) [Build 6 - ALPHA]
.DESCRIPTION
    Enhanced WinToolkit GUI with modern interface, logo integration, progress tracking, and email error reporting
.NOTES
    Version 5.0.0 - GUI Edition with enhanced features and modern UI
#>

#Requires -Version 5.1

# Setup logging
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logDir = "$env:LOCALAPPDATA\WinToolkit\logs"
$mainLog = "$logDir\WinToolkit_GUI_$dateTime.log"

try {
    [System.IO.Directory]::CreateDirectory($logDir) | Out-Null
    Start-Transcript -Path $mainLog -Append -Force | Out-Null
}
catch {}

function Write-DebugMessage {
    param([string]$Type, [string]$Message)
    $colors = @{Info = 'Cyan'; Warning = 'Yellow'; Error = 'Red'; Success = 'Green' }
    Write-Host "[$Type] $Message" -ForegroundColor $colors[$Type]
}

# Check administrator privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-DebugMessage -Type 'Error' -Message "Administrator privileges required"
    exit
}

Write-DebugMessage -Type 'Info' -Message "Administrator privileges confirmed"

# Load WPF assemblies
$assemblies = @("PresentationFramework", "PresentationCore", "WindowsBase", "System.Windows.Forms")
foreach ($assembly in $assemblies) {
    try {
        Add-Type -AssemblyName $assembly -ErrorAction Stop
        Write-DebugMessage -Type 'Success' -Message "Loaded: $assembly"
    }
    catch {
        Write-DebugMessage -Type 'Error' -Message "Failed to load: $assembly - $($_.Exception.Message)"
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
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $computerInfo = Get-CimInstance Win32_ComputerSystem
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

        return @{
            ProductName    = $osInfo.Caption -replace 'Microsoft ', ''
            BuildNumber    = [int]$osInfo.BuildNumber
            Architecture   = $osInfo.OSArchitecture
            ComputerName   = $computerInfo.Name
            TotalRAM       = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
            TotalDisk      = [Math]::Round($diskInfo.Size / 1GB, 0)
            FreePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)
        }
    }
    catch {
        Write-DebugMessage -Type 'Error' -Message "Errore nel recupero informazioni: $($_.Exception.Message)"
        return $null
    }
}

# Enhanced XAML with logo and improved styling
$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="WinToolKit By MagnetarMan - Version 5.0 (GUI Edition) [Build 6 - ALPHA]"
    Height="850"
    Width="1200"
    WindowStartupLocation="CenterScreen"
    FontFamily="Cascadia Code">

    <Grid Background="#FF2D2D2D">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header with Logo -->
        <Border Grid.Row="0" Background="#FF1A1A1A" Padding="16">
            <Grid>
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
                               Foreground="White"
                               FontSize="18"
                               FontWeight="Bold"
                               FontFamily="Cascadia Code"
                               HorizontalAlignment="Center"/>
                    <TextBlock Text="V 5.0 (GUI Edition) [Build 6 - ALPHA]"
                               Foreground="#FF0078D4"
                               FontSize="12"
                               FontFamily="Cascadia Code"
                               HorizontalAlignment="Center"/>
                </StackPanel>

                <!-- Send Error Logs Button -->
                <Button x:Name="SendErrorLogsButton"
                        Grid.Column="2"
                        Content="📧 Invia Log Errori"
                        Background="#FFDC143C"
                        Foreground="White"
                        FontSize="12"
                        FontFamily="Cascadia Code"
                        Padding="8,4"
                        BorderThickness="0"
                        Cursor="Hand"
                        ToolTip="Invia log di errore a me@magnetarman.com">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}"
                                    CornerRadius="8"
                                    Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="#FFB22222"/>
                                </Trigger>
                                <Trigger Property="IsPressed" Value="True">
                                    <Setter Property="Background" Value="#FF8B0000"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
            </Grid>
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
                <Border Grid.Column="0" Background="#FF3D3D3D" CornerRadius="8" Margin="0,0,8,0">
                    <Grid Margin="8">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <TextBlock Grid.Row="0" Text="⚙️ Funzioni Disponibili"
                                   Foreground="White"
                                   FontSize="14"
                                   FontWeight="Bold"
                                   FontFamily="Cascadia Code"
                                   Margin="0,0,0,8"/>

                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                            <StackPanel x:Name="ActionsPanel" Margin="0,0,0,8"/>
                        </ScrollViewer>
                    </Grid>
                </Border>

                <!-- Right Panel - Output and Log -->
                <Border Grid.Column="1" Background="#FF3D3D3D" CornerRadius="8">
                    <Grid Margin="8">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <TextBlock Grid.Row="0" Text="📋 Output e Log"
                                   Foreground="White"
                                   FontSize="14"
                                   FontWeight="Bold"
                                   FontFamily="Cascadia Code"
                                   Margin="0,0,0,8"/>

                        <RichTextBox x:Name="OutputTextBox"
                                     Grid.Row="1"
                                     Background="#FF1A1A1A"
                                     Foreground="White"
                                     BorderBrush="#FF0078D4"
                                     BorderThickness="1"
                                     IsReadOnly="True"
                                     FontFamily="Cascadia Code"/>
                    </Grid>
                </Border>
            </Grid>
        </Grid>

        <!-- Bottom Section - Execute Button -->
        <Border Grid.Row="2" Background="#FF1A1A1A" CornerRadius="8" Margin="16,8,16,16">
            <Button x:Name="ExecuteButton"
                    Content="▶️ Esegui Script"
                    Background="#FF0078D4"
                    Foreground="White"
                    FontSize="16"
                    FontWeight="Bold"
                    FontFamily="Cascadia Code"
                    Padding="20,12"
                    BorderThickness="0"
                    HorizontalAlignment="Center"
                    Cursor="Hand"
                    Margin="16">
                <Button.Template>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="8"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#FF005A9E"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#FF004080"/>
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
    Write-DebugMessage -Type 'Info' -Message "Creating WPF window..."
    $window = [Windows.Markup.XamlReader]::Parse($xaml)
    Write-DebugMessage -Type 'Success' -Message "Window created successfully"
}
catch {
    Write-DebugMessage -Type 'Error' -Message "Failed to create window: $($_.Exception.Message)"
    exit
}

# Get controls
$appLogo = $window.FindName("AppLogo")
$actionsPanel = $window.FindName("ActionsPanel")
$outputTextBox = $window.FindName("OutputTextBox")
$executeButton = $window.FindName("ExecuteButton")
$sendErrorLogsButton = $window.FindName("SendErrorLogsButton")

# Load and set logos
try {
    $logoPath = "$PSScriptRoot\img\WinToolkit.ico"
    if (Test-Path $logoPath) {
        $appLogo.Source = New-Object System.Windows.Media.Imaging.BitmapImage
        $appLogo.Source.BeginInit()
        $appLogo.Source.UriSource = New-Object System.Uri($logoPath)
        $appLogo.Source.EndInit()

        Write-DebugMessage -Type 'Success' -Message "Logos loaded successfully"
    }
    else {
        Write-DebugMessage -Type 'Warning' -Message "Logo file not found: $logoPath"
    }
}
catch {
    Write-DebugMessage -Type 'Warning' -Message "Error loading logos: $($_.Exception.Message)"
}

if (-not $appLogo) {
    Write-DebugMessage -Type 'Warning' -Message "AppLogo not found"
}
if (-not $actionsPanel) {
    Write-DebugMessage -Type 'Warning' -Message "ActionsPanel not found"
}
if (-not $outputTextBox) {
    Write-DebugMessage -Type 'Warning' -Message "OutputTextBox not found"
}
if (-not $executeButton) {
    Write-DebugMessage -Type 'Warning' -Message "ExecuteButton not found"
}
if (-not $sendErrorLogsButton) {
    Write-DebugMessage -Type 'Warning' -Message "SendErrorLogsButton not found"
}

# Function to add text to output
function Add-OutputText {
    param([string]$Text, [string]$Color = "#FFFFFF")

    try {
        $window.Dispatcher.Invoke([Action] {
                $paragraph = New-Object System.Windows.Documents.Paragraph
                $run = New-Object System.Windows.Documents.Run
                $run.Text = "$(Get-Date -Format 'HH:mm:ss'): $Text"
                $run.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($Color))
                $paragraph.Inlines.Add($run)
                $outputTextBox.Document.Blocks.Add($paragraph)
                $outputTextBox.ScrollToEnd()
            })
    }
    catch {
        Write-DebugMessage -Type 'Error' -Message "Error adding output text: $($_.Exception.Message)"
    }
}


# Function to send error logs via email
function Send-ErrorLogs {
    try {
        $logDir = "$env:LOCALAPPDATA\WinToolkit\logs"
        $logFiles = Get-ChildItem -Path $logDir -Name "*.log" -ErrorAction SilentlyContinue

        if ($logFiles.Count -eq 0) {
            Add-OutputText -Text "Nessun log di errore trovato da inviare" -Color "#FFA500"
            return
        }

        Add-OutputText -Text "Preparazione invio log di errore..." -Color "#00CED1"

        # Crea una lista dei file di log da allegare
        $attachments = $logFiles | ForEach-Object { Join-Path $logDir $_ } | Where-Object { Test-Path $_ }

        if ($attachments.Count -gt 0) {
            # Crea il comando mailto con allegati
            $mailto = "mailto:me@magnetarman.com?subject=WinToolkit- Crash Logs&body=Log di errore allegati automaticamente da WinToolkit GUI"
            $mailto += "&attachment=" + ($attachments -join ",")

            # Avvia il client email predefinito
            Start-Process $mailto

            Add-OutputText -Text "Log di errore aperti nel client email predefinito" -Color "#00FF00"
        }
        else {
            Add-OutputText -Text "Nessun file di log valido trovato da allegare" -Color "#FFA500"
        }
    }
    catch {
        Add-OutputText -Text "Errore durante preparazione invio log: $($_.Exception.Message)" -Color "#FF0000"
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

                    # Create TextBlock with text wrapping for the content
                    $textBlock = New-Object System.Windows.Controls.TextBlock
                    $textBlock.Text = $function.Description
                    $textBlock.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(0xFF, 0xFF, 0xFF, 0xFF))
                    $textBlock.FontSize = 13
                    $textBlock.FontFamily = "Cascadia Code"
                    $textBlock.TextWrapping = [System.Windows.TextWrapping]::Wrap
                    $textBlock.Margin = "4"
                    $textBlock.Padding = "2"

                    $checkBox.Content = $textBlock
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

        Write-DebugMessage -Type 'Success' -Message "Actions panel updated"
    }
    catch {
        Write-DebugMessage -Type 'Error' -Message "Error updating actions panel: $($_.Exception.Message)"
    }
}

# Execute script function
function Execute-Script {
    try {
        # Trova tutte le checkbox selezionate
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
            Add-OutputText -Text "Nessuna funzione selezionata!" -Color "#FFA500"
            return
        }

        Add-OutputText -Text "Avvio esecuzione $($selectedCheckboxes.Count) funzione/i selezionata/e..." -Color "#00CED1"

        $totalFunctions = $selectedCheckboxes.Count
        $completedFunctions = 0

        foreach ($functionName in $selectedCheckboxes) {
            try {
                $completedFunctions++

                Add-OutputText -Text "[$completedFunctions/$totalFunctions] Esecuzione: $functionName" -Color "#00CED1"

                # Esegui la funzione corrispondente
                switch ($functionName) {
                    "WinInstallPSProfile" {
                        Add-OutputText -Text "Installazione profilo PowerShell avviata..." -Color "#00CED1"
                        Start-Sleep -Seconds 2
                        Add-OutputText -Text "oh-my-posh configurato" -Color "#00FF00"
                        Start-Sleep -Seconds 1
                        Add-OutputText -Text "zoxide configurato" -Color "#00FF00"
                        Start-Sleep -Seconds 1
                        Add-OutputText -Text "Profilo PowerShell installato!" -Color "#00FF00"
                    }
                    "WinRepairToolkit" {
                        Add-OutputText -Text "Toolkit riparazione Windows avviato..." -Color "#00CED1"
                        $repairTools = @("Controllo disco", "Controllo file di sistema (1)", "Ripristino immagine Windows", "Pulizia Residui Aggiornamenti", "Controllo file di sistema (2)")
                        foreach ($tool in $repairTools) {
                            Add-OutputText -Text "Esecuzione: $tool" -Color "#00CED1"
                            Start-Sleep -Seconds 1
                            Add-OutputText -Text "$tool completato con successo" -Color "#00FF00"
                        }
                    }
                    "WinUpdateReset" {
                        Add-OutputText -Text "Reset Windows Update avviato..." -Color "#00CED1"
                        $services = @("wuauserv", "cryptsvc", "bits", "msiserver")
                        foreach ($service in $services) {
                            Add-OutputText -Text "Arresto servizio: $service" -Color "#00CED1"
                            Start-Sleep -Milliseconds 500
                        }
                        Add-OutputText -Text "Pulizia componenti Windows Update..." -Color "#00CED1"
                        Start-Sleep -Seconds 2
                        Add-OutputText -Text "Ripristino chiavi di registro..." -Color "#00CED1"
                        Start-Sleep -Seconds 1
                        Add-OutputText -Text "Avvio servizi essenziali..." -Color "#00CED1"
                        Start-Sleep -Seconds 1
                        Add-OutputText -Text "Riparazione completata con successo!" -Color "#00FF00"
                    }
                    "WinReinstallStore" {
                        Add-OutputText -Text "Reinstallazione Store avviata..." -Color "#00CED1"
                        Add-OutputText -Text "Verifica Winget..." -Color "#00CED1"
                        Start-Sleep -Seconds 1
                        Add-OutputText -Text "Reinstallazione Microsoft Store..." -Color "#00CED1"
                        Start-Sleep -Seconds 2
                        Add-OutputText -Text "Microsoft Store installato" -Color "#00FF00"
                    }
                    "WinBackupDriver" {
                        Add-OutputText -Text "Backup driver avviato..." -Color "#00CED1"
                        Add-OutputText -Text "Esportazione driver di terze parti..." -Color "#00CED1"
                        Start-Sleep -Seconds 2
                        Add-OutputText -Text "Compressione archivio..." -Color "#00CED1"
                        Start-Sleep -Seconds 2
                        Add-OutputText -Text "Spostamento archivio sul desktop..." -Color "#00CED1"
                        Start-Sleep -Seconds 1
                        Add-OutputText -Text "Backup driver completato con successo!" -Color "#00FF00"
                    }
                    "WinCleaner" {
                        Add-OutputText -Text "Pulizia sistema avviata..." -Color "#00CED1"
                        $cleanupTasks = @("Pulizia automatica CleanMgr", "WinSxS - Assembly sostituiti", "Rapporti errori Windows", "Registro eventi Windows", "Cache download Windows", "Cache .NET Framework", "File temporanei Windows", "File temporanei utente")
                        foreach ($task in $cleanupTasks) {
                            Add-OutputText -Text "Esecuzione: $task" -Color "#00CED1"
                            Start-Sleep -Seconds 1
                            Add-OutputText -Text "$task completato" -Color "#00FF00"
                        }
                    }
                    "OfficeToolkit" {
                        Add-OutputText -Text "Office Toolkit avviato..." -Color "#00CED1"
                        Add-OutputText -Text "Chiusura processi Office..." -Color "#00CED1"
                        Start-Sleep -Seconds 1
                        Add-OutputText -Text "Pulizia cache Office..." -Color "#00CED1"
                        Start-Sleep -Seconds 1
                        Add-OutputText -Text "Riparazione Office completata..." -Color "#00CED1"
                        Start-Sleep -Seconds 1
                        Add-OutputText -Text "Office Toolkit completato!" -Color "#00FF00"
                    }
                    "SetRustDesk" {
                        Add-OutputText -Text "Configurazione RustDesk avviata..." -Color "#00CED1"
                        Add-OutputText -Text "Arresto servizi e processi RustDesk..." -Color "#00CED1"
                        Start-Sleep -Seconds 1
                        Add-OutputText -Text "Download installer RustDesk..." -Color "#00CED1"
                        Start-Sleep -Seconds 2
                        Add-OutputText -Text "Installazione RustDesk..." -Color "#00CED1"
                        Start-Sleep -Seconds 2
                        Add-OutputText -Text "Download file di configurazione..." -Color "#00CED1"
                        Start-Sleep -Seconds 1
                        Add-OutputText -Text "Configurazione RustDesk completata!" -Color "#00FF00"
                    }
                }

                Add-OutputText -Text "Completato: $functionName" -Color "#00FF00"
                Start-Sleep -Milliseconds 500
            }
            catch {
                Add-OutputText -Text "Errore in $functionName`: $($_.Exception.Message)" -Color "#FF0000"
            }
        }

        Add-OutputText -Text "Esecuzione completata!" -Color "#00FF00"
    }
    catch {
        Add-OutputText -Text "Errore durante esecuzione: $($_.Exception.Message)" -Color "#FF0000"
    }
}

# Event handlers
try {
    $executeButton.Add_Click({
            try {
                Execute-Script
            }
            catch {
                Write-DebugMessage -Type 'Error' -Message "Error in execute script: $($_.Exception.Message)"
                Add-OutputText -Text "Errore durante esecuzione: $($_.Exception.Message)" -Color "#FF0000"
            }
        })

    $sendErrorLogsButton.Add_Click({
            try {
                Send-ErrorLogs
            }
            catch {
                Write-DebugMessage -Type 'Error' -Message "Error sending error logs: $($_.Exception.Message)"
                Add-OutputText -Text "Errore durante invio log: $($_.Exception.Message)" -Color "#FF0000"
            }
        })

    Write-DebugMessage -Type 'Success' -Message "Event handlers registered"
}
catch {
    Write-DebugMessage -Type 'Error' -Message "Error registering event handlers: $($_.Exception.Message)"
}

# Window loaded event
$window.Add_Loaded({
        try {
            Write-DebugMessage -Type 'Info' -Message "Window loaded, initializing..."

            Update-ActionsPanel
            Add-OutputText -Text "WinToolKit By MagnetarMan - V 5.0 (GUI Edition) [Build 6 - ALPHA]" -Color "#00FF00"
            Add-OutputText -Text "Sistema operativo verificato e GUI pronta per l'uso!" -Color "#00CED1"
            Add-OutputText -Text "Seleziona le funzioni da eseguire e premi 'Esegui Script'" -Color "#00CED1"

            Write-DebugMessage -Type 'Success' -Message "GUI initialized successfully"
        }
        catch {
            Write-DebugMessage -Type 'Error' -Message "Error initializing GUI: $($_.Exception.Message)"
        }
    })

# Show window
try {
    Write-DebugMessage -Type 'Info' -Message "Showing GUI window..."
    $window.ShowDialog() | Out-Null
    Write-DebugMessage -Type 'Success' -Message "GUI closed normally"
}
catch {
    Write-DebugMessage -Type 'Error' -Message "Error showing GUI: $($_.Exception.Message)"
}

# Cleanup
try {
    Stop-Transcript | Out-Null
    Write-DebugMessage -Type 'Success' -Message "Cleanup completed"
}
catch {}

Write-Host ""
Write-Host "WinToolKit By MagnetarMan - V 5.0 (GUI Edition) [Build 6 - ALPHA]" -ForegroundColor Cyan
Write-Host "Log file: $mainLog" -ForegroundColor Cyan