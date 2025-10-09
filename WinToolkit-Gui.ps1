<#
.SYNOPSIS
    WinToolkit-Gui - Interfaccia grafica per WinToolkit
.DESCRIPTION
    Versione grafica del WinToolkit con Windows Forms per una gestione più intuitiva
    di tutti gli strumenti di manutenzione Windows.
.NOTES
    Versione 2.2.3 (Build 7) - GUI Edition - 2025-10-04
#>

param([int]$CountdownSeconds = 10)

# Richiedi privilegi amministrativi se necessario
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"& { `$PSScriptRoot\WinToolkit-Gui.ps1 }`""
    exit
}

# Carica gli assembly necessari per Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# Carica la configurazione se disponibile
$configPath = Join-Path $PSScriptRoot "WinToolkit-Gui-Config.ps1"
if (Test-Path $configPath) {
    try {
        . $configPath
        $guiConfig = Get-WinToolkitConfig
        $categories = Get-WinToolkitCategories
        $scriptDefinitions = Get-WinToolkitScripts
        $advancedSettings = Get-WinToolkitAdvancedSettings
        $exportImportSettings = Get-WinToolkitExportImportSettings
        $reportingSettings = Get-WinToolkitReportingSettings

        # Verifica configurazione
        $configErrors = Test-WinToolkitConfiguration
        if ($configErrors.Count -gt 0) {
            Write-Warning "Errori nella configurazione: $($configErrors -join ', ')"
        }
    }
    catch {
        Write-Warning "Errore nel caricamento configurazione: $($_.Exception.Message)"
    }
}

# Setup logging
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\WinToolkit\logs"
try {
    [System.IO.Directory]::CreateDirectory($logdir) | Out-Null
    Start-Transcript -Path "$logdir\WinToolkit-Gui_$dateTime.log" -Append -Force | Out-Null
}
catch {}

# Nerd Fonts Configuration and Installation
$nerdFontsConfig = @{
    FontName      = "JetBrainsMono NF"
    FontSize      = 9
    FallbackFonts = @("Consolas", "Courier New", "Lucida Console")
    DownloadUrl   = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip"
    InstallPath   = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    FontFileName  = "JetBrainsMonoNerdFont-Regular.ttf"
}

# Version mapping (usato da più funzioni)
$versionMap = @{
    26100 = "24H2"; 22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2"
    19045 = "22H2"; 19044 = "21H2"; 19043 = "21H1"; 19042 = "20H2"
    19041 = "2004"; 18363 = "1909"; 18362 = "1903"; 17763 = "1809"
    17134 = "1803"; 16299 = "1709"; 15063 = "1703"; 14393 = "1607"
    10586 = "1511"; 10240 = "1507"
}

# Utility Functions
# Centralized Update-Log Function (Specification Compliant)
function Update-Log {
    param(
        [string]$Message,
        [int]$Percentage = -1,
        [ValidateSet('Success', 'Warning', 'Error', 'Info')][string]$Type = 'Info'
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $typeIcons = @{
        Success = '✓'
        Warning = '⚠'
        Error   = '✗'
        Info    = 'ℹ'
    }

    $typeColors = @{
        Success = 'Green'
        Warning = 'Yellow'
        Error   = 'Red'
        Info    = 'Cyan'
    }

    $icon = $typeIcons[$Type]
    $color = $typeColors[$Type]
    $logEntry = "[$timestamp] $icon $Message"

    # Update log textbox if available
    if ($global:logTextBox) {
        $global:logTextBox.AppendText("$logEntry`r`n")
        $global:logTextBox.SelectionStart = $global:logTextBox.Text.Length
        $global:logTextBox.ScrollToCaret()
    }

    # Update progress bar if percentage specified
    if ($Percentage -ge 0 -and $global:progressBar) {
        $global:progressBar.Value = $Percentage
        $global:mainForm.Refresh()
    }

    # Console output
    Write-Host $logEntry -ForegroundColor $color
}

function Write-StyledMessage {
    param([ValidateSet('Success', 'Warning', 'Error', 'Info')][string]$type, [string]$text)
    $cleanText = $text -replace '^(✓|⚠|✗|ℹ|🔥|▶|⚙|🧹|📦|📋|📜|🔒|💾|⬇|🔧|⚡|🖼|🌐|🪟|🔄|🗂|📁|🖨|📄|🗑|💭|⏸|▶|💡|⏰|🎉|💻|📊|🛡|🔧|🔑|📦|🧹|ℹ|⚙|▶)\s*', ''
    Update-Log -Message $cleanText -Type $type
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
        Write-StyledMessage -type 'Error' -text "Errore nel recupero informazioni: $($_.Exception.Message)"
        return $null
    }
}

function Update-SystemInfoPanel {
    $sysInfo = Get-SystemInfo
    if ($sysInfo) {
        $buildNumber = $sysInfo.BuildNumber
        $windowsVersion = Get-WindowsVersion $buildNumber

        $windowsEdition = switch -Wildcard ($sysInfo.ProductName) {
            "*Home*" { "🏠 Home" }
            "*Pro*" { "💼 Professional" }
            "*Enterprise*" { "🏢 Enterprise" }
            "*Education*" { "🎓 Education" }
            "*Server*" { "🖥️ Server" }
            default { "💻 $($sysInfo.ProductName)" }
        }

        if ($global:systemInfoLabels) {
            if ($global:systemInfoLabels['Edition']) { $global:systemInfoLabels['Edition'].Text = $windowsEdition }
            if ($global:systemInfoLabels['Version']) { $global:systemInfoLabels['Version'].Text = "Ver. $windowsVersion (Build $buildNumber)" }
            if ($global:systemInfoLabels['ComputerName']) { $global:systemInfoLabels['ComputerName'].Text = $sysInfo.ComputerName }
            if ($global:systemInfoLabels['RAM']) { $global:systemInfoLabels['RAM'].Text = "$($sysInfo.TotalRAM) GB" }
        }
    }
}

# WinToolkit-GUI Color Scheme (Specification Compliant)
$WinToolkitColors = @{
    # Colori di Base
    BackgroundColor      = [System.Drawing.ColorTranslator]::FromHtml("#2D2D30")    # Sfondo principale
    SidebarColor         = [System.Drawing.ColorTranslator]::FromHtml("#252526")    # Sfondo navigazione
    LogBackgroundColor   = [System.Drawing.ColorTranslator]::FromHtml("#1E1E1E")    # Sfondo log

    # Colori di Testo
    TextColor            = [System.Drawing.Color]::WhiteSmoke                       # Testo principale
    TextSecondaryColor   = [System.Drawing.ColorTranslator]::FromHtml("#CCCCCC")   # Testo secondario
    TextMutedColor       = [System.Drawing.Color]::LightGray                       # Testo descrizione

    # Colori di Accento
    AccentColor          = [System.Drawing.ColorTranslator]::FromHtml("#0078D4")    # Azioni primarie
    SuccessColor         = [System.Drawing.Color]::FromArgb(0, 150, 0)             # Operazioni riuscite
    WarningColor         = [System.Drawing.Color]::FromArgb(150, 100, 0)           # Avvertenze
    ErrorColor           = [System.Drawing.Color]::FromArgb(150, 0, 0)             # Errori

    # Colori Pulsanti
    ButtonPrimaryColor   = [System.Drawing.ColorTranslator]::FromHtml("#0078D4")    # Pulsanti primari
    ButtonSecondaryColor = [System.Drawing.ColorTranslator]::FromHtml("#444444")   # Pulsanti secondari
    ButtonDisabledColor  = [System.Drawing.ColorTranslator]::FromHtml("#333333")   # Pulsanti disabilitati

    # Colori Speciali
    BorderColor          = [System.Drawing.ColorTranslator]::FromHtml("#3E3E42")    # Bordi sottili
    HoverColor           = [System.Drawing.ColorTranslator]::FromHtml("#404040")   # Effetto hover
}

# Typography Specification (Segoe UI Required)
$WinToolkitTypography = @{
    PrimaryFont = New-Object System.Drawing.Font("Segoe UI", 9.75)
    LogFont     = New-Object System.Drawing.Font("Consolas", 9)
    HeadingFont = New-Object System.Drawing.Font("Segoe UI", 9.75, [System.Drawing.FontStyle]::Bold)
    SmallFont   = New-Object System.Drawing.Font("Segoe UI", 8.25)
}

# Nerd Fonts Management Functions
function Test-NerdFontsInstalled {
    try {
        # Try to create a test font object with Nerd Fonts
        $testFont = New-Object System.Drawing.Font($nerdFontsConfig.FontName, 12)
        $testFont.Dispose()
        return $true
    }
    catch {
        return $false
    }
}

function Get-AvailableFont {
    param([string]$PreferredFont, [string[]]$FallbackFonts)

    foreach ($font in $FallbackFonts) {
        try {
            $testFont = New-Object System.Drawing.Font($font, 10)
            $testFont.Dispose()
            return $font
        }
        catch {
            continue
        }
    }

    # If no fonts work, return a system default
    return "Microsoft Sans Serif"
}

function Install-NerdFonts {
    Write-StyledMessage -type 'Info' -text "Installazione Nerd Fonts in corso..."

    try {
        # Create temp directory for download
        $tempDir = "$env:TEMP\NerdFonts"
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        # Download Nerd Fonts
        $zipPath = "$tempDir\JetBrainsMono.zip"
        Write-StyledMessage -type 'Info' -text "Downloading Nerd Fonts..."

        Invoke-WebRequest -Uri $nerdFontsConfig.DownloadUrl -OutFile $zipPath -UseBasicParsing

        # Extract the zip file
        Write-StyledMessage -type 'Info' -text "Extracting fonts..."
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempDir)

        # Find the TTF file
        $fontFile = Get-ChildItem $tempDir -Recurse -Filter "*.ttf" | Where-Object {
            $_.Name -like "*$($nerdFontsConfig.FontFileName)*"
        } | Select-Object -First 1

        if (-not $fontFile) {
            Write-StyledMessage -type 'Error' -text "Font file not found in archive"
            return $false
        }

        # Install the font (requires admin privileges)
        Write-StyledMessage -type 'Info' -text "Installing font..."
        try {
            Copy-Item $fontFile.FullName $nerdFontsConfig.InstallPath -Force -ErrorAction Stop

            # Refresh system fonts (Windows specific)
            $shell = New-Object -ComObject Shell.Application
            $fontsFolder = $shell.NameSpace(0x14) # Fonts folder
            $copiedFont = Get-Item "$($nerdFontsConfig.InstallPath)\$($fontFile.Name)" -ErrorAction SilentlyContinue
            if ($copiedFont) {
                $fontsFolder.ParseName($fontFile.Name)
            }
        }
        catch {
            Write-StyledMessage -type 'Warning' -text "Font installation requires administrator privileges. Font copied but may need manual installation."
        }

        # Clean up
        Remove-Item $tempDir -Recurse -Force

        Write-StyledMessage -type 'Success' -text "Nerd Fonts installed successfully"
        return $true
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore nell'installazione Nerd Fonts: $($_.Exception.Message)"
        return $false
    }
}

function Initialize-NerdFonts {
    # Check if Nerd Fonts are installed
    if (-not (Test-NerdFontsInstalled)) {
        Write-StyledMessage -type 'Warning' -text "Nerd Fonts non rilevate. Installazione in corso..."

        # Try to install Nerd Fonts
        $installed = Install-NerdFonts

        if (-not $installed) {
            Write-StyledMessage -type 'Warning' -text "Installazione automatica fallita. Uso font di fallback."
        }
    }
    else {
        Write-StyledMessage -type 'Info' -text "Nerd Fonts rilevate e pronte all'uso"
    }
}

function Get-NerdFont {
    param([int]$Size = $nerdFontsConfig.FontSize)

    $fontName = Get-AvailableFont -PreferredFont $nerdFontsConfig.FontName -FallbackFonts $nerdFontsConfig.FallbackFonts
    return New-Object System.Drawing.Font($fontName, $Size, [System.Drawing.FontStyle]::Regular)
}

# Theme management functions
function Get-CurrentTheme {
    if ($guiConfig -and $guiConfig.Theme.CurrentTheme) {
        return $guiConfig.Theme.CurrentTheme
    }
    return "Dark"
}

function Get-ThemeColors {
    $currentTheme = Get-CurrentTheme
    if ($guiConfig -and $guiConfig.Theme.$currentTheme) {
        return $guiConfig.Theme.$currentTheme
    }
    # Fallback to dark theme colors
    return @{
        BackgroundColor    = [System.Drawing.Color]::FromArgb(45, 45, 48)
        PanelColor         = [System.Drawing.Color]::FromArgb(30, 30, 30)
        ButtonColor        = [System.Drawing.Color]::FromArgb(70, 70, 70)
        AccentColor        = [System.Drawing.Color]::FromArgb(0, 120, 0)
        TextColor          = [System.Drawing.Color]::White
        TextColorSecondary = [System.Drawing.Color]::Yellow
    }
}

function Apply-Theme {
    param([string]$Theme = $null)

    if ($Theme) {
        $guiConfig.Theme.CurrentTheme = $Theme
    }

    $themeColors = Get-ThemeColors

    # Applica i colori del tema a tutti i controlli
    if ($global:mainForm) {
        $global:mainForm.BackColor = $themeColors.BackgroundColor
        $global:mainForm.ForeColor = $themeColors.TextColor
    }

    # Applica colori ai pannelli
    $panels = @($global:systemInfoPanel, $global:controlPanel, $global:logPanel, $global:progressPanel)
    foreach ($panel in $panels) {
        if ($panel) {
            $panel.BackColor = $themeColors.PanelColor
            $panel.ForeColor = $themeColors.TextColor
        }
    }

    # Applica colori ai pulsanti
    $buttons = @($global:refreshButton, $global:executeButton, $global:selectAllButton, $global:deselectAllButton,
        $global:openLogButton, $global:stopButton, $global:pauseButton, $global:resumeButton)
    foreach ($button in $buttons) {
        if ($button) {
            $button.BackColor = $themeColors.ButtonColor
            $button.ForeColor = $themeColors.TextColor
        }
    }

    # Colori speciali per pulsanti di azione
    if ($global:executeButton) { $global:executeButton.BackColor = $themeColors.AccentColor }
    if ($global:stopButton) { $global:stopButton.BackColor = [System.Drawing.Color]::FromArgb(150, 0, 0) }
    if ($global:pauseButton) { $global:pauseButton.BackColor = [System.Drawing.Color]::FromArgb(150, 100, 0) }

    # Applica colori alle tab
    if ($global:tabControl) {
        $global:tabControl.BackColor = $themeColors.PanelColor
        $global:tabControl.ForeColor = $themeColors.TextColor
        foreach ($tabPage in $global:tabControl.Controls) {
            $tabPage.BackColor = $themeColors.PanelColor
            $tabPage.ForeColor = $themeColors.TextColor
        }
    }

    # Aggiorna colori delle label di sistema
    if ($global:systemInfoLabels) {
        foreach ($label in $global:systemInfoLabels.Values) {
            if ($label) {
                $label.ForeColor = $themeColors.TextColor
            }
        }
    }

    # Aggiorna colori del log
    if ($global:logTextBox) {
        $global:logTextBox.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
        $global:logTextBox.ForeColor = $themeColors.TextColor
    }

    # Aggiorna colori della progress bar
    if ($global:progressBar) {
        $global:progressBar.ForeColor = $themeColors.AccentColor
        $global:progressBar.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    }

    # Aggiorna colori della barra di stato
    if ($global:statusStrip) {
        $global:statusStrip.BackColor = $themeColors.PanelColor
        $global:statusStrip.ForeColor = $themeColors.TextColor
        foreach ($item in $global:statusStrip.Items) {
            $item.ForeColor = $themeColors.TextColor
        }
    }

    Write-StyledMessage -type 'Info' -text "Tema cambiato a: $($Theme)"
}

# Configuration Export/Import functions
function Export-WinToolkitConfiguration {
    param([string]$FilePath = $null)

    if (-not $FilePath) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $fileName = "WinToolkit_Config_$timestamp.$($exportImportSettings.ConfigFileExtension)"
        $FilePath = Join-Path $exportImportSettings.DefaultExportPath $fileName
    }

    try {
        # Crea la directory se non esiste
        $configDir = Split-Path $FilePath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        # Raccogli la configurazione corrente
        $exportConfig = @{
            Version          = $guiConfig.Version
            ExportDate       = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Theme            = $guiConfig.Theme.CurrentTheme
            ScriptSelections = @{}
            SystemInfo       = Get-SystemInfo
            AdvancedSettings = $advancedSettings
        }

        # Salva le selezioni degli script
        foreach ($script in $scriptDefinitions) {
            $checkBoxName = "$($script.Name)CheckBox"
            $isChecked = $false
            if ($global:categoryTabs[$script.Category].Controls[$checkBoxName]) {
                $isChecked = $global:categoryTabs[$script.Category].Controls[$checkBoxName].Checked
            }
            $exportConfig.ScriptSelections[$script.Name] = $isChecked
        }

        # Esporta in JSON
        $exportConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $FilePath -Encoding UTF8

        Write-StyledMessage -type 'Success' -text "Configurazione esportata: $FilePath"
        return $true
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore nell'esportazione: $($_.Exception.Message)"
        return $false
    }
}

function Import-WinToolkitConfiguration {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        Write-StyledMessage -type 'Error' -text "File di configurazione non trovato: $FilePath"
        return $false
    }

    try {
        # Importa la configurazione
        $importConfig = Get-Content $FilePath -Encoding UTF8 | ConvertFrom-Json

        # Backup configurazione corrente se abilitato
        if ($exportImportSettings.BackupOnImport) {
            $backupPath = $FilePath -replace "\.$($exportImportSettings.ConfigFileExtension)$", "_backup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').$($exportImportSettings.ConfigFileExtension)"
            Copy-Item $FilePath $backupPath
            Write-StyledMessage -type 'Info' -text "Backup creato: $(Split-Path $backupPath -Leaf)"
        }

        # Applica il tema
        if ($importConfig.Theme) {
            Apply-Theme -Theme $importConfig.Theme
        }

        # Applica le selezioni degli script
        if ($importConfig.ScriptSelections) {
            foreach ($script in $scriptDefinitions) {
                $checkBoxName = "$($script.Name)CheckBox"
                if ($importConfig.ScriptSelections.ContainsKey($script.Name) -and $global:categoryTabs[$script.Category].Controls[$checkBoxName]) {
                    $global:categoryTabs[$script.Category].Controls[$checkBoxName].Checked = $importConfig.ScriptSelections[$script.Name]
                }
            }
        }

        Write-StyledMessage -type 'Success' -text "Configurazione importata: $FilePath"
        return $true
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore nell'importazione: $($_.Exception.Message)"
        return $false
    }
}

# Reporting functions
function New-WinToolkitReport {
    param(
        [string]$Format = "PDF",
        [string]$OutputPath = $null,
        [switch]$IncludeExecutionLog,
        [switch]$IncludeSystemInfo,
        [switch]$IncludeScriptDetails
    )

    if (-not $reportingSettings.Enabled) {
        Write-StyledMessage -type 'Warning' -text "Reporting disabilitato nelle impostazioni"
        return $false
    }

    try {
        # Crea la directory dei report se non esiste
        if (-not $OutputPath) {
            $reportDir = $reportingSettings.ReportDirectory
            if (-not (Test-Path $reportDir)) {
                New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
            }
            $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $extension = $Format.ToLower()
            $fileName = "$($reportingSettings.ReportFilePrefix)$timestamp.$extension"
            $OutputPath = Join-Path $reportDir $fileName
        }

        # Raccogli i dati del report
        $reportData = @{
            GeneratedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Version       = $guiConfig.Version
            Format        = $Format
        }

        if ($IncludeSystemInfo -or $reportingSettings.IncludeSystemInfo) {
            $reportData.SystemInfo = Get-SystemInfo
        }

        if ($IncludeExecutionLog -or $reportingSettings.IncludeExecutionLog) {
            $reportData.ExecutionLog = $global:executionHistory
        }

        if ($IncludeScriptDetails -or $reportingSettings.IncludeScriptDetails) {
            $reportData.ScriptDetails = $scriptDefinitions
            $reportData.ScriptSelections = @{}
            foreach ($script in $scriptDefinitions) {
                $checkBoxName = "$($script.Name)CheckBox"
                $isChecked = $false
                if ($global:categoryTabs[$script.Category].Controls[$checkBoxName]) {
                    $isChecked = $global:categoryTabs[$script.Category].Controls[$checkBoxName].Checked
                }
                $reportData.ScriptSelections[$script.Name] = $isChecked
            }
        }

        switch ($Format) {
            "PDF" {
                return Export-ReportToPDF -Data $reportData -OutputPath $OutputPath
            }
            "Excel" {
                return Export-ReportToExcel -Data $reportData -OutputPath $OutputPath
            }
            default {
                Write-StyledMessage -type 'Error' -text "Formato non supportato: $Format"
                return $false
            }
        }
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore nella generazione del report: $($_.Exception.Message)"
        return $false
    }
}

function Export-ReportToPDF {
    param($Data, $OutputPath)

    try {
        # Crea un documento PDF semplice usando iTextSharp se disponibile
        # Altrimenti crea un file HTML che può essere convertito in PDF
        $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>WinToolkit Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; margin-bottom: 20px; }
        .section { margin-bottom: 20px; }
        .system-info { background-color: #f9f9f9; padding: 10px; border-radius: 5px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>WinToolkit Report</h1>
        <p>Generato il: $($Data.GeneratedDate)</p>
        <p>Versione: $($Data.Version)</p>
    </div>

    <div class="section">
        <h2>Informazioni di Sistema</h2>
        <div class="system-info">
            <table>
                <tr><th>Prodotto</th><td>$($Data.SystemInfo.ProductName)</td></tr>
                <tr><th>Build</th><td>$($Data.SystemInfo.BuildNumber)</td></tr>
                <tr><th>Architettura</th><td>$($Data.SystemInfo.Architecture)</td></tr>
                <tr><th>Nome Computer</th><td>$($Data.SystemInfo.ComputerName)</td></tr>
                <tr><th>RAM Totale</th><td>$($Data.SystemInfo.TotalRAM) GB</td></tr>
                <tr><th>Spazio Disco</th><td>$($Data.SystemInfo.FreePercentage)% libero ($($Data.SystemInfo.TotalDisk) GB)</td></tr>
            </table>
        </div>
    </div>
</body>
</html>
"@

        $htmlContent | Out-File -FilePath $OutputPath.Replace(".pdf", ".html") -Encoding UTF8

        Write-StyledMessage -type 'Success' -text "Report HTML creato: $($OutputPath.Replace('.pdf', '.html'))"
        Write-StyledMessage -type 'Info' -text "Per convertire in PDF, apri il file HTML e stampalo come PDF"

        return $true
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore nella creazione PDF: $($_.Exception.Message)"
        return $false
    }
}

function Export-ReportToExcel {
    param($Data, $OutputPath)

    try {
        # Crea un file CSV come alternativa semplice a Excel
        $csvContent = @"
"WinToolkit Report"
"Generato il:",$($Data.GeneratedDate)
"Versione:",$($Data.Version)
""
"Informazioni di Sistema"
"Prodotto:",$($Data.SystemInfo.ProductName)
"Build:",$($Data.SystemInfo.BuildNumber)
"Architettura:",$($Data.SystemInfo.Architecture)
"Nome Computer:",$($Data.SystemInfo.ComputerName)
"RAM Totale (GB):",$($Data.SystemInfo.TotalRAM)
"Spazio Disco Libero (%):",$($Data.SystemInfo.FreePercentage)
"Spazio Disco Totale (GB):",$($Data.SystemInfo.TotalDisk)
"@

        $csvContent | Out-File -FilePath $OutputPath.Replace(".xlsx", ".csv") -Encoding UTF8

        Write-StyledMessage -type 'Success' -text "Report CSV creato: $($OutputPath.Replace('.xlsx', '.csv'))"
        Write-StyledMessage -type 'Info' -text "Per convertire in Excel, apri il file CSV con Microsoft Excel"

        return $true
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore nella creazione Excel: $($_.Exception.Message)"
        return $false
    }
}

# Script execution functions
function Execute-Script {
    param([string]$ScriptName, [string]$Description)

    $startTime = Get-Date
    Write-StyledMessage -type 'Info' -text "Avvio '$Description'..."

    # Aggiungi alla cronologia
    $historyEntry = @{
        ScriptName  = $ScriptName
        Description = $Description
        StartTime   = $startTime
        EndTime     = $null
        Success     = $false
        Output      = ""
        ErrorOutput = ""
        ExitCode    = $null
    }
    $global:executionHistory.Add($historyEntry)

    try {
        # Crea un nuovo processo PowerShell per eseguire lo script
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command & { $ScriptName }"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        $process.Start() | Out-Null

        # Legge l'output in tempo reale
        $output = $process.StandardOutput.ReadToEnd()
        $errorOutput = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        $endTime = Get-Date
        $duration = $endTime - $startTime

        # Aggiorna la cronologia
        $historyEntry.EndTime = $endTime
        $historyEntry.Success = ($process.ExitCode -eq 0)
        $historyEntry.Output = $output
        $historyEntry.ErrorOutput = $errorOutput
        $historyEntry.ExitCode = $process.ExitCode

        if ($process.ExitCode -eq 0) {
            Write-StyledMessage -type 'Success' -text "Completato: '$Description' ($([Math]::Round($duration.TotalSeconds, 2))s)"
            if ($output) {
                Write-StyledMessage -type 'Info' -text "Output: $output"
            }
            return $true
        }
        else {
            Write-StyledMessage -type 'Error' -text "Errore in '$Description' (Exit Code: $($process.ExitCode)) - Durata: $([Math]::Round($duration.TotalSeconds, 2))s"
            if ($errorOutput) {
                Write-StyledMessage -type 'Error' -text "Error Details: $errorOutput"
            }
            return $false
        }
    }
    catch {
        $endTime = Get-Date
        $duration = $endTime - $startTime

        # Aggiorna la cronologia con l'errore
        $historyEntry.EndTime = $endTime
        $historyEntry.Success = $false
        $historyEntry.Output = ""
        $historyEntry.ErrorOutput = $_.Exception.Message
        $historyEntry.ExitCode = -1

        Write-StyledMessage -type 'Error' -text "Errore nell'esecuzione di '$Description': $($_.Exception.Message) - Durata: $([Math]::Round($duration.TotalSeconds, 2))s"
        return $false
    }
}

function Execute-MultipleScripts {
    param([System.Collections.Generic.List[object]]$Scripts)

    $totalScripts = $Scripts.Count
    $completedScripts = 0
    $startTime = Get-Date

    # Aggiungi sessione alla cronologia
    $sessionEntry = @{
        Type             = "Session"
        StartTime        = $startTime
        EndTime          = $null
        TotalScripts     = $totalScripts
        CompletedScripts = 0
        Success          = $false
        Scripts          = $Scripts
    }
    $global:executionHistory.Add($sessionEntry)

    # Inizializza variabili di controllo
    $global:executionStopped = $false
    $global:executionPaused = $false

    # Abilita/disabilita controlli
    if ($global:stopButton) { $global:stopButton.Enabled = $true }
    if ($global:pauseButton) { $global:pauseButton.Enabled = $true }
    if ($global:resumeButton) { $global:resumeButton.Enabled = $false }
    if ($global:executeButton) { $global:executeButton.Enabled = $false }

    Write-StyledMessage -type 'Info' -text "Avvio esecuzione batch di $totalScripts script..."

    foreach ($script in $Scripts) {
        # Verifica se l'esecuzione è stata interrotta
        if ($global:executionStopped) {
            Write-StyledMessage -type 'Warning' -text "Esecuzione interrotta dopo $completedScripts script"
            break
        }

        # Gestisci pausa
        while ($global:executionPaused -and -not $global:executionStopped) {
            Start-Sleep -Milliseconds 500
        }

        if ($global:executionStopped) {
            break
        }

        $completedScripts++
        Write-StyledMessage -type 'Info' -text "[$completedScripts/$totalScripts] Esecuzione: $($script.Description)"

        if ($global:progressBar) {
            $progress = [Math]::Round(($completedScripts / $totalScripts) * 100)
            $global:progressBar.Value = $progress
            $global:mainForm.Refresh()
        }

        Execute-Script -ScriptName $script.Name -Description $script.Description

        # Piccola pausa tra gli script (se non in pausa)
        if (-not $global:executionPaused -and -not $global:executionStopped) {
            Start-Sleep -Milliseconds 1000
        }
    }

    # Reset controlli
    if ($global:stopButton) { $global:stopButton.Enabled = $false }
    if ($global:pauseButton) { $global:pauseButton.Enabled = $false }
    if ($global:resumeButton) { $global:resumeButton.Enabled = $false }
    if ($global:executeButton) { $global:executeButton.Enabled = $true }

    if ($global:progressBar) {
        $global:progressBar.Value = 100
        $global:mainForm.Refresh()
    }

    $endTime = Get-Date
    $duration = $endTime - $startTime

    # Aggiorna la sessione nella cronologia
    $sessionEntry.EndTime = $endTime
    $sessionEntry.CompletedScripts = $completedScripts
    $sessionEntry.Success = -not $global:executionStopped

    if ($global:executionStopped) {
        Write-StyledMessage -type 'Warning' -text "Esecuzione interrotta! ($completedScripts/$totalScripts script eseguiti) - Durata totale: $([Math]::Round($duration.TotalSeconds, 2))s"
    }
    else {
        Write-StyledMessage -type 'Success' -text "Esecuzione batch completata! ($completedScripts/$totalScripts script eseguiti) - Durata totale: $([Math]::Round($duration.TotalSeconds, 2))s"
    }
}

# Placeholder functions (saranno popolate dal compilatore originale)
function WinInstallPSProfile { Write-StyledMessage 'Info' 'WinInstallPSProfile - Installa profilo PowerShell' }
function WinRepairToolkit { Write-StyledMessage 'Info' 'WinRepairToolkit - Toolkit Riparazione Windows' }
function WinUpdateReset { Write-StyledMessage 'Info' 'WinUpdateReset - Reset Windows Update' }
function WinReinstallStore { Write-StyledMessage 'Info' 'WinReinstallStore - Winget/WinStore Reset' }
function WinBackupDriver { Write-StyledMessage 'Info' 'WinBackupDriver - Backup Driver PC' }
function WinCleaner { Write-StyledMessage 'Info' 'WinCleaner - Pulizia File Temporanei' }
function OfficeToolkit { Write-StyledMessage 'Info' 'OfficeToolkit - Office Toolkit' }
function WinDriverInstall { Write-StyledMessage 'Info' 'WinDriverInstall - Toolkit Driver Grafici' }
function GamingToolkit { Write-StyledMessage 'Info' 'GamingToolkit - Gaming Toolkit' }
function SetRustDesk { Write-StyledMessage 'Info' 'SetRustDesk - Setting RustDesk' }

# Script definitions with modern Unicode icons
$scriptDefinitions = @(
    @{ Name = 'WinInstallPSProfile'; Description = 'Installa profilo PowerShell'; Category = 'Operazioni Preliminari'; Icon = '⚡' },
    @{ Name = 'WinRepairToolkit'; Description = 'Toolkit Riparazione Windows'; Category = 'Windows & Office'; Icon = '🔧' },
    @{ Name = 'WinUpdateReset'; Description = 'Reset Windows Update'; Category = 'Windows & Office'; Icon = '🔄' },
    @{ Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset'; Category = 'Windows & Office'; Icon = '🛒' },
    @{ Name = 'WinBackupDriver'; Description = 'Backup Driver PC'; Category = 'Windows & Office'; Icon = '💾' },
    @{ Name = 'WinCleaner'; Description = 'Pulizia File Temporanei'; Category = 'Windows & Office'; Icon = '🧹' },
    @{ Name = 'OfficeToolkit'; Description = 'Office Toolkit'; Category = 'Windows & Office'; Icon = '📝' },
    @{ Name = 'WinDriverInstall'; Description = 'Toolkit Driver Grafici'; Category = 'Driver & Gaming'; Icon = '🎮' },
    @{ Name = 'GamingToolkit'; Description = 'Gaming Toolkit'; Category = 'Driver & Gaming'; Icon = '🎯' },
    @{ Name = 'SetRustDesk'; Description = 'Setting RustDesk'; Category = 'Supporto'; Icon = '🖥' }
)

# Inizializza Nerd Fonts (dopo la definizione delle funzioni)
Initialize-NerdFonts

# Crea la finestra principale
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "WinToolkit-GUI by MagnetarMan"
$mainForm.Size = New-Object System.Drawing.Size(1000, 700)
$mainForm.MinimumSize = New-Object System.Drawing.Size(800, 600)
$mainForm.StartPosition = "CenterScreen"
$mainForm.Font = $WinToolkitTypography.PrimaryFont
$mainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$mainForm.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSCommandPath)
$mainForm.BackColor = $WinToolkitColors.BackgroundColor
$mainForm.ForeColor = $WinToolkitColors.TextColor

# Crea il layout principale con Sidebar + MainContent + Footer
# 1. Sidebar Navigation Panel (sinistra)
$sidebarPanel = New-Object System.Windows.Forms.Panel
$sidebarPanel.Dock = [System.Windows.Forms.DockStyle]::Left
$sidebarPanel.Width = 180
$sidebarPanel.BackColor = $WinToolkitColors.SidebarColor
$sidebarPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

# 2. Main Content Panel (centro)
$mainContentPanel = New-Object System.Windows.Forms.Panel
$mainContentPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$mainContentPanel.BackColor = $WinToolkitColors.BackgroundColor

# 3. Footer Panel (log + progress - basso)
$footerPanel = New-Object System.Windows.Forms.Panel
$footerPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
$footerPanel.Height = 120
$footerPanel.BackColor = $WinToolkitColors.BackgroundColor
$footerPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

# Aggiungi i pannelli al form nell'ordine corretto
$mainForm.Controls.Add($mainContentPanel)
$mainForm.Controls.Add($footerPanel)
$mainForm.Controls.Add($sidebarPanel)

# Crea le categorie per la navigazione sidebar
$categories = @("Operazioni Preliminari", "Windows & Office", "Driver & Gaming", "Supporto")
$categoryTabs = @{}

# Crea i pulsanti di navigazione nella sidebar (Specification Compliant)
$sidebarButtons = @{}
$yPos = 20

foreach ($category in $categories) {
    $button = New-Object System.Windows.Forms.Button
    $button.Location = New-Object System.Drawing.Point(10, $yPos)
    $button.Size = New-Object System.Drawing.Size(160, 45)
    $button.Text = $category
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = $WinToolkitColors.SidebarColor
    $button.ForeColor = $WinToolkitColors.TextColor
    $button.Font = $WinToolkitTypography.PrimaryFont
    $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $button.Tag = $category

    # Event handler per il cambio modulo
    $button.Add_Click({
            $moduleName = $this.Tag
            Load-Module -ModuleName $moduleName
        })

    $sidebarPanel.Controls.Add($button)
    $sidebarButtons[$category] = $button
    $yPos += 50
}

# Crea il pannello delle informazioni di sistema (nella sidebar, parte bassa)
$systemInfoPanel = New-Object System.Windows.Forms.GroupBox
$systemInfoPanel.Location = New-Object System.Drawing.Point(10, ($yPos + 20))
$systemInfoPanel.Size = New-Object System.Drawing.Size(160, 200)
$systemInfoPanel.Text = "🖥 Sistema"
$systemInfoPanel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$systemInfoPanel.BackColor = $WinToolkitColors.SidebarColor
$systemInfoPanel.ForeColor = $WinToolkitColors.TextColor
$systemInfoPanel.Font = $WinToolkitTypography.PrimaryFont

# Crea le label per le informazioni di sistema (versione compatta per sidebar)
$systemInfoLabels = @{}
$infoItems = @("Edition", "Version", "RAM", "ComputerName")
$yPos = 25

foreach ($item in $infoItems) {
    # Label descrizione
    $labelTitle = New-Object System.Windows.Forms.Label
    $labelTitle.Location = New-Object System.Drawing.Point(10, $yPos)
    $labelTitle.Size = New-Object System.Drawing.Size(60, 18)
    $labelTitle.Text = "$item`:"
    $labelTitle.ForeColor = $WinToolkitColors.TextMutedColor
    $labelTitle.Font = $WinToolkitTypography.SmallFont
    $systemInfoPanel.Controls.Add($labelTitle)

    # Label valore
    $labelValue = New-Object System.Windows.Forms.Label
    $labelValue.Location = New-Object System.Drawing.Point(75, $yPos)
    $labelValue.Size = New-Object System.Drawing.Size(75, 18)
    $labelValue.ForeColor = $WinToolkitColors.TextColor
    $labelValue.Font = $WinToolkitTypography.PrimaryFont
    $systemInfoPanel.Controls.Add($labelValue)

    $systemInfoLabels[$item] = $labelValue
    $yPos += 22
}

$sidebarPanel.Controls.Add($systemInfoPanel)

# Crea il pannello di controllo (nella parte alta del main content)
$controlPanel = New-Object System.Windows.Forms.GroupBox
$controlPanel.Location = New-Object System.Drawing.Point(10, 10)
$controlPanel.Size = New-Object System.Drawing.Size(760, 80)
$controlPanel.Text = "🎮 Controlli"
$controlPanel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$controlPanel.BackColor = $WinToolkitColors.BackgroundColor
$controlPanel.ForeColor = $WinToolkitColors.TextColor
$controlPanel.Font = $WinToolkitTypography.PrimaryFont

# Crea il pannello per i controlli azione (parte destra del main content)
$actionPanel = New-Object System.Windows.Forms.Panel
$actionPanel.Location = New-Object System.Drawing.Point(780, 10)
$actionPanel.Size = New-Object System.Drawing.Size(200, 80)
$actionPanel.BackColor = $WinToolkitColors.BackgroundColor
$actionPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

# Crea il footer panel con log e progress bar (Specification Compliant)
$footerPanel.Controls.Clear()

# Progress Bar nella parte alta del footer
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Dock = [System.Windows.Forms.DockStyle]::Top
$progressBar.Height = 15
$progressBar.BackColor = $WinToolkitColors.BackgroundColor
$progressBar.ForeColor = $WinToolkitColors.AccentColor
$footerPanel.Controls.Add($progressBar)

# Log Box nel resto del footer
$logTextBox = New-Object System.Windows.Forms.RichTextBox
$logTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$logTextBox.BackColor = $WinToolkitColors.LogBackgroundColor
$logTextBox.ForeColor = $WinToolkitColors.TextColor
$logTextBox.ReadOnly = $true
$logTextBox.Font = $WinToolkitTypography.LogFont
$logTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$footerPanel.Controls.Add($logTextBox)

# Salva riferimenti globali
$global:logTextBox = $logTextBox
$global:progressBar = $progressBar

# Variabili globali per controlli avanzati
$global:executionPaused = $false
$global:executionStopped = $false
$global:currentJob = $null
$global:executionHistory = [System.Collections.Generic.List[object]]::new()

# Pulsante per aggiornare informazioni di sistema
$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Location = New-Object System.Drawing.Point(15, 25)
$refreshButton.Size = New-Object System.Drawing.Size(100, 30)
$refreshButton.Text = "🔄 Aggiorna"
$refreshButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$refreshButton.FlatAppearance.BorderSize = 0
$refreshButton.BackColor = $WinToolkitColors.ButtonSecondaryColor
$refreshButton.ForeColor = $WinToolkitColors.TextColor
$refreshButton.Font = $WinToolkitTypography.PrimaryFont
$refreshButton.Add_Click({
        Update-SystemInfoPanel
        Update-Log -Message "Informazioni di sistema aggiornate" -Type Info
    })
$controlPanel.Controls.Add($refreshButton)

# Pulsante per eseguire script selezionati (primario)
$executeButton = New-Object System.Windows.Forms.Button
$executeButton.Location = New-Object System.Drawing.Point(130, 25)
$executeButton.Size = New-Object System.Drawing.Size(120, 30)
$executeButton.Text = "▶ Esegui Selezionati"
$executeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$executeButton.FlatAppearance.BorderSize = 0
$executeButton.BackColor = $WinToolkitColors.AccentColor
$executeButton.ForeColor = $WinToolkitColors.TextColor
$executeButton.Font = $WinToolkitTypography.PrimaryFont
$executeButton.Add_Click({
        $selectedScripts = [System.Collections.Generic.List[object]]::new()

        foreach ($script in $scriptDefinitions) {
            $checkBoxName = "$($script.Name)CheckBox"
            # Cerca la checkbox nel main content panel invece che nelle tab
            $checkBox = $mainContentPanel.Controls | Where-Object { $_.Controls[$checkBoxName] } | ForEach-Object { $_.Controls[$checkBoxName] }
            if ($checkBox -and $checkBox.Checked) {
                $selectedScripts.Add($script)
            }
        }

        if ($selectedScripts.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Seleziona almeno uno script da eseguire.", "Nessuno script selezionato", "OK", "Warning")
            return
        }

        $result = [System.Windows.Forms.MessageBox]::Show(
            "Vuoi eseguire $($selectedScripts.Count) script selezionati?`n`n$([string]::Join('`n', ($selectedScripts | ForEach-Object { $_.Description })))",
            "Conferma esecuzione",
            "YesNo",
            "Question"
        )

        if ($result -eq "Yes") {
            Execute-MultipleScripts -Scripts $selectedScripts
        }
    })
$controlPanel.Controls.Add($executeButton)

# Pulsante per selezionare tutto
$selectAllButton = New-Object System.Windows.Forms.Button
$selectAllButton.Location = New-Object System.Drawing.Point(265, 25)
$selectAllButton.Size = New-Object System.Drawing.Size(100, 30)
$selectAllButton.Text = "☑ Seleziona Tutto"
$selectAllButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$selectAllButton.BackColor = $WinToolkitColors.ButtonSecondaryColor
$selectAllButton.ForeColor = $WinToolkitColors.TextColor
$selectAllButton.Font = $WinToolkitFont
$selectAllButton.Add_Click({
        foreach ($script in $scriptDefinitions) {
            $checkBoxName = "$($script.Name)CheckBox"
            # Cerca la checkbox nel main content panel
            $checkBox = $mainContentPanel.Controls | Where-Object { $_.Controls[$checkBoxName] } | ForEach-Object { $_.Controls[$checkBoxName] }
            if ($checkBox) {
                $checkBox.Checked = $true
            }
        }
    })
$controlPanel.Controls.Add($selectAllButton)

# Pulsante per deselezionare tutto
$deselectAllButton = New-Object System.Windows.Forms.Button
$deselectAllButton.Location = New-Object System.Drawing.Point(15, 45)
$deselectAllButton.Size = New-Object System.Drawing.Size(100, 30)
$deselectAllButton.Text = "☐ Deseleziona"
$deselectAllButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$deselectAllButton.BackColor = $WinToolkitColors.ButtonSecondaryColor
$deselectAllButton.ForeColor = $WinToolkitColors.TextColor
$deselectAllButton.Font = $WinToolkitFont
$deselectAllButton.Add_Click({
        foreach ($script in $scriptDefinitions) {
            $checkBoxName = "$($script.Name)CheckBox"
            # Cerca la checkbox nel main content panel
            $checkBox = $mainContentPanel.Controls | Where-Object { $_.Controls[$checkBoxName] } | ForEach-Object { $_.Controls[$checkBoxName] }
            if ($checkBox) {
                $checkBox.Checked = $false
            }
        }
    })
$controlPanel.Controls.Add($deselectAllButton)

# Campo di ricerca
$searchLabel = New-Object System.Windows.Forms.Label
$searchLabel.Location = New-Object System.Drawing.Point(130, 50)
$searchLabel.Size = New-Object System.Drawing.Size(50, 20)
$searchLabel.Text = "🔍"
$searchLabel.ForeColor = $WinToolkitColors.TextColor
$searchLabel.Font = $WinToolkitFont
$controlPanel.Controls.Add($searchLabel)

$searchTextBox = New-Object System.Windows.Forms.TextBox
$searchTextBox.Location = New-Object System.Drawing.Point(180, 45)
$searchTextBox.Size = New-Object System.Drawing.Size(185, 25)
$searchTextBox.BackColor = $WinToolkitColors.LogBackgroundColor
$searchTextBox.ForeColor = $WinToolkitColors.TextColor
$searchTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$searchTextBox.Font = $WinToolkitFont
$searchTextBox.Add_TextChanged({
        $searchTerm = $searchTextBox.Text.ToLower()
        foreach ($script in $scriptDefinitions) {
            $checkBoxName = "$($script.Name)CheckBox"
            # Cerca nel main content panel invece che nelle tab
            $scriptPanel = $mainContentPanel.Controls | Where-Object { $_.Controls[$checkBoxName] }
            if ($scriptPanel) {
                $visible = $script.Description.ToLower().Contains($searchTerm) -or [string]::IsNullOrEmpty($searchTerm)
                $scriptPanel.Visible = $visible
            }
        }
    })
$controlPanel.Controls.Add($searchTextBox)

# Pulsante per aprire la cartella dei log
$openLogButton = New-Object System.Windows.Forms.Button
$openLogButton.Location = New-Object System.Drawing.Point(265, 45)
$openLogButton.Size = New-Object System.Drawing.Size(100, 30)
$openLogButton.Text = "📂 Log"
$openLogButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$openLogButton.BackColor = $WinToolkitColors.ButtonSecondaryColor
$openLogButton.ForeColor = $WinToolkitColors.TextColor
$openLogButton.Font = $WinToolkitFont
$openLogButton.Add_Click({
        $logDir = "$env:LOCALAPPDATA\WinToolkit\logs"
        if (Test-Path $logDir) {
            Start-Process explorer.exe -ArgumentList $logDir
            Write-StyledMessage -type 'Info' -text "Cartella log aperta"
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Cartella log non trovata. Verrà creata al primo utilizzo.", "Cartella non trovata", "OK", "Information")
        }
    })
$controlPanel.Controls.Add($openLogButton)

# Pulsante per cambiare tema (modern design)
$themeButton = New-Object System.Windows.Forms.Button
$themeButton.Location = New-Object System.Drawing.Point(380, 25)
$themeButton.Size = New-Object System.Drawing.Size(50, 30)
$currentTheme = Get-CurrentTheme
$themeButton.Text = if ($currentTheme -eq "Dark") { "☀" } else { "🌙" }
$themeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$themeButton.BackColor = $WinToolkitColors.ButtonSecondaryColor
$themeButton.ForeColor = $WinToolkitColors.TextColor
$themeButton.Font = $WinToolkitFont
$themeButton.Add_Click({
        $currentTheme = Get-CurrentTheme
        $newTheme = if ($currentTheme -eq "Dark") { "Light" } else { "Dark" }
        Apply-Theme -Theme $newTheme
        $this.Text = if ($newTheme -eq "Dark") { "☀" } else { "🌙" }
        $this.ToolTipText = "$newTheme Mode"
    })
$controlPanel.Controls.Add($themeButton)

# Pulsante per esportare configurazione
$exportConfigButton = New-Object System.Windows.Forms.Button
$exportConfigButton.Location = New-Object System.Drawing.Point(440, 25)
$exportConfigButton.Size = New-Object System.Drawing.Size(80, 30)
$exportConfigButton.Text = "📤 Esporta"
$exportConfigButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$exportConfigButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1E88E5")
$exportConfigButton.ForeColor = $WinToolkitColors.TextColor
$exportConfigButton.Font = $WinToolkitFont
$exportConfigButton.Add_Click({
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "WinToolkit Config Files (*.$($exportImportSettings.ConfigFileExtension))|*.$($exportImportSettings.ConfigFileExtension)"
        $saveDialog.DefaultExt = $exportImportSettings.ConfigFileExtension
        $saveDialog.InitialDirectory = $exportImportSettings.DefaultExportPath
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $saveDialog.FileName = "WinToolkit_Config_$timestamp"

        if ($saveDialog.ShowDialog() -eq "OK") {
            Export-WinToolkitConfiguration -FilePath $saveDialog.FileName
        }
    })
$controlPanel.Controls.Add($exportConfigButton)

# Pulsante per importare configurazione
$importConfigButton = New-Object System.Windows.Forms.Button
$importConfigButton.Location = New-Object System.Drawing.Point(525, 25)
$importConfigButton.Size = New-Object System.Drawing.Size(80, 30)
$importConfigButton.Text = "📥 Importa"
$importConfigButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$importConfigButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFA726")
$importConfigButton.ForeColor = $WinToolkitColors.TextColor
$importConfigButton.Font = $WinToolkitFont
$importConfigButton.Add_Click({
        $openDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openDialog.Filter = "WinToolkit Config Files (*.$($exportImportSettings.ConfigFileExtension))|*.$($exportImportSettings.ConfigFileExtension)"
        $openDialog.InitialDirectory = $exportImportSettings.DefaultExportPath

        if ($openDialog.ShowDialog() -eq "OK") {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Importare la configurazione? Questo sovrascriverà le selezioni attuali.",
                "Conferma importazione",
                "YesNo",
                "Question"
            )

            if ($result -eq "Yes") {
                Import-WinToolkitConfiguration -FilePath $openDialog.FileName
            }
        }
    })
$controlPanel.Controls.Add($importConfigButton)

# Pulsante per generare report
$reportButton = New-Object System.Windows.Forms.Button
$reportButton.Location = New-Object System.Drawing.Point(380, 45)
$reportButton.Size = New-Object System.Drawing.Size(80, 30)
$reportButton.Text = "📊 Report"
$reportButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$reportButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#9C27B0")
$reportButton.ForeColor = $WinToolkitColors.TextColor
$reportButton.Font = $WinToolkitFont
$reportButton.Add_Click({
        $reportDialog = New-Object System.Windows.Forms.Form
        $reportDialog.Text = "Genera Report"
        $reportDialog.Size = New-Object System.Drawing.Size(300, 200)
        $reportDialog.StartPosition = "CenterParent"
        $reportDialog.BackColor = $global:mainForm.BackColor
        $reportDialog.ForeColor = $global:mainForm.ForeColor

        # Radio buttons per formato
        $pdfRadio = New-Object System.Windows.Forms.RadioButton
        $pdfRadio.Location = New-Object System.Drawing.Point(20, 20)
        $pdfRadio.Size = New-Object System.Drawing.Size(80, 20)
        $pdfRadio.Text = "PDF"
        $pdfRadio.Checked = $true

        $excelRadio = New-Object System.Windows.Forms.RadioButton
        $excelRadio.Location = New-Object System.Drawing.Point(20, 45)
        $excelRadio.Size = New-Object System.Drawing.Size(80, 20)
        $excelRadio.Text = "Excel"

        # Checkboxes per opzioni
        $systemInfoCheck = New-Object System.Windows.Forms.CheckBox
        $systemInfoCheck.Location = New-Object System.Drawing.Point(120, 20)
        $systemInfoCheck.Size = New-Object System.Drawing.Size(150, 20)
        $systemInfoCheck.Text = "Includi Info Sistema"
        $systemInfoCheck.Checked = $true

        $executionLogCheck = New-Object System.Windows.Forms.CheckBox
        $executionLogCheck.Location = New-Object System.Drawing.Point(120, 45)
        $executionLogCheck.Size = New-Object System.Drawing.Size(150, 20)
        $executionLogCheck.Text = "Includi Log Esecuzione"
        $executionLogCheck.Checked = $true

        $scriptDetailsCheck = New-Object System.Windows.Forms.CheckBox
        $scriptDetailsCheck.Location = New-Object System.Drawing.Point(120, 70)
        $scriptDetailsCheck.Size = New-Object System.Drawing.Size(150, 20)
        $scriptDetailsCheck.Text = "Includi Dettagli Script"
        $scriptDetailsCheck.Checked = $true

        # Pulsanti
        $generateButton = New-Object System.Windows.Forms.Button
        $generateButton.Location = New-Object System.Drawing.Point(50, 110)
        $generateButton.Size = New-Object System.Drawing.Size(80, 30)
        $generateButton.Text = "Genera"
        $generateButton.Add_Click({
                $format = if ($pdfRadio.Checked) { "PDF" } else { "Excel" }
                $includeSystemInfo = $systemInfoCheck.Checked
                $includeExecutionLog = $executionLogCheck.Checked
                $includeScriptDetails = $scriptDetailsCheck.Checked

                $reportDialog.Close()
                $reportDialog.Dispose()

                New-WinToolkitReport -Format $format -IncludeSystemInfo:$includeSystemInfo -IncludeExecutionLog:$includeExecutionLog -IncludeScriptDetails:$includeScriptDetails
            })

        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Location = New-Object System.Drawing.Point(150, 110)
        $cancelButton.Size = New-Object System.Drawing.Size(80, 30)
        $cancelButton.Text = "Annulla"
        $cancelButton.Add_Click({
                $reportDialog.Close()
                $reportDialog.Dispose()
            })

        $reportDialog.Controls.AddRange(@($pdfRadio, $excelRadio, $systemInfoCheck, $executionLogCheck, $scriptDetailsCheck, $generateButton, $cancelButton))
        $reportDialog.ShowDialog()
    })
$controlPanel.Controls.Add($reportButton)

# Pulsante Stop esecuzione
$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Location = New-Object System.Drawing.Point(440, 45)
$stopButton.Size = New-Object System.Drawing.Size(60, 30)
$stopButton.Text = "⏹ Stop"
$stopButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$stopButton.BackColor = [System.Drawing.Color]::FromArgb(150, 0, 0)
$stopButton.ForeColor = $WinToolkitColors.TextColor
$stopButton.Font = $WinToolkitFont
$stopButton.Enabled = $false
$stopButton.Add_Click({
        $global:executionStopped = $true
        if ($global:currentJob) {
            Stop-Job $global:currentJob -ErrorAction SilentlyContinue
            Remove-Job $global:currentJob -ErrorAction SilentlyContinue
            $global:currentJob = $null
        }
        Write-StyledMessage -type 'Warning' -text "Esecuzione interrotta dall'utente"
        $stopButton.Enabled = $false
        $pauseButton.Enabled = $false
        $resumeButton.Enabled = $false
        $executeButton.Enabled = $true
    })
$controlPanel.Controls.Add($stopButton)

# Pulsante Pause esecuzione
$pauseButton = New-Object System.Windows.Forms.Button
$pauseButton.Location = New-Object System.Drawing.Point(505, 45)
$pauseButton.Size = New-Object System.Drawing.Size(60, 30)
$pauseButton.Text = "⏸ Pausa"
$pauseButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$pauseButton.BackColor = [System.Drawing.Color]::FromArgb(150, 100, 0)
$pauseButton.ForeColor = $WinToolkitColors.TextColor
$pauseButton.Font = $WinToolkitFont
$pauseButton.Enabled = $false
$pauseButton.Add_Click({
        $global:executionPaused = $true
        Write-StyledMessage -type 'Warning' -text "Esecuzione in pausa..."
        $pauseButton.Enabled = $false
        $resumeButton.Enabled = $true
    })
$controlPanel.Controls.Add($pauseButton)

# Pulsante Resume esecuzione
$resumeButton = New-Object System.Windows.Forms.Button
$resumeButton.Location = New-Object System.Drawing.Point(505, 45)
$resumeButton.Size = New-Object System.Drawing.Size(60, 30)
$resumeButton.Text = "▶ Riprendi"
$resumeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$resumeButton.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 0)
$resumeButton.ForeColor = $WinToolkitColors.TextColor
$resumeButton.Font = $WinToolkitFont
$resumeButton.Enabled = $false
$resumeButton.Add_Click({
        $global:executionPaused = $false
        Write-StyledMessage -type 'Info' -text "Esecuzione ripresa"
        $pauseButton.Enabled = $true
        $resumeButton.Enabled = $false
    })
$controlPanel.Controls.Add($resumeButton)

# Salva riferimenti globali per i controlli
$global:stopButton = $stopButton
$global:pauseButton = $pauseButton
$global:resumeButton = $resumeButton

# Aggiungi i controlli al main content panel
$mainContentPanel.Controls.Add($controlPanel)
$mainContentPanel.Controls.Add($actionPanel)

# Load-Module Function (Specification Compliant)
function Load-Module {
    param([string]$ModuleName)

    # 1. Pulisce il contenuto esistente
    $mainContentPanel.Controls.Clear()

    # 2. Reset stato navigazione
    foreach ($category in $categories) {
        $sidebarButtons[$category].BackColor = $WinToolkitColors.SidebarColor
        $sidebarButtons[$category].ForeColor = $WinToolkitColors.TextColor
    }

    # 3. Evidenzia sezione attiva con colore accento
    if ($sidebarButtons.ContainsKey($ModuleName)) {
        $sidebarButtons[$ModuleName].BackColor = $WinToolkitColors.AccentColor
        $sidebarButtons[$ModuleName].ForeColor = $WinToolkitColors.TextColor
    }

    # 4. Carica controlli specifici del modulo
    switch ($ModuleName) {
        "Operazioni Preliminari" {
            $groupBox = New-Object System.Windows.Forms.GroupBox
            $groupBox.Text = "⚡ Operazioni Preliminari"
            $groupBox.Dock = [System.Windows.Forms.DockStyle]::Fill
            $groupBox.BackColor = $WinToolkitColors.BackgroundColor
            $groupBox.ForeColor = $WinToolkitColors.TextColor
            $groupBox.Font = $WinToolkitTypography.PrimaryFont
            $groupBox.Padding = New-Object System.Windows.Forms.Padding(10)

            # Carica controlli specifici
            $scripts = $scriptDefinitions | Where-Object { $_.Category -eq $ModuleName }
            Load-ModuleControls -Scripts $scripts -Parent $groupBox

            $mainContentPanel.Controls.Add($groupBox)
        }
        "Windows & Office" {
            $groupBox = New-Object System.Windows.Forms.GroupBox
            $groupBox.Text = "🔧 Windows & Office"
            $groupBox.Dock = [System.Windows.Forms.DockStyle]::Fill
            $groupBox.BackColor = $WinToolkitColors.BackgroundColor
            $groupBox.ForeColor = $WinToolkitColors.TextColor
            $groupBox.Font = $WinToolkitTypography.PrimaryFont
            $groupBox.Padding = New-Object System.Windows.Forms.Padding(10)

            $scripts = $scriptDefinitions | Where-Object { $_.Category -eq $ModuleName }
            Load-ModuleControls -Scripts $scripts -Parent $groupBox

            $mainContentPanel.Controls.Add($groupBox)
        }
        "Driver & Gaming" {
            $groupBox = New-Object System.Windows.Forms.GroupBox
            $groupBox.Text = "🎮 Driver & Gaming"
            $groupBox.Dock = [System.Windows.Forms.DockStyle]::Fill
            $groupBox.BackColor = $WinToolkitColors.BackgroundColor
            $groupBox.ForeColor = $WinToolkitColors.TextColor
            $groupBox.Font = $WinToolkitTypography.PrimaryFont
            $groupBox.Padding = New-Object System.Windows.Forms.Padding(10)

            $scripts = $scriptDefinitions | Where-Object { $_.Category -eq $ModuleName }
            Load-ModuleControls -Scripts $scripts -Parent $groupBox

            $mainContentPanel.Controls.Add($groupBox)
        }
        "Supporto" {
            $groupBox = New-Object System.Windows.Forms.GroupBox
            $groupBox.Text = "🖥 Supporto"
            $groupBox.Dock = [System.Windows.Forms.DockStyle]::Fill
            $groupBox.BackColor = $WinToolkitColors.BackgroundColor
            $groupBox.ForeColor = $WinToolkitColors.TextColor
            $groupBox.Font = $WinToolkitTypography.PrimaryFont
            $groupBox.Padding = New-Object System.Windows.Forms.Padding(10)

            $scripts = $scriptDefinitions | Where-Object { $_.Category -eq $ModuleName }
            Load-ModuleControls -Scripts $scripts -Parent $groupBox

            $mainContentPanel.Controls.Add($groupBox)
        }
    }

    # 5. Aggiorna log con progresso
    Update-Log -Message "Modulo caricato: $ModuleName" -Percentage 0 -Type Info
}

# Load-ModuleControls Function
function Load-ModuleControls {
    param([array]$Scripts, [System.Windows.Forms.Control]$Parent)

    $currentX = 10
    $currentY = 20
    $itemsPerRow = 2

    foreach ($script in $Scripts) {
        # Crea pannello script
        $scriptPanel = New-Object System.Windows.Forms.Panel
        $scriptPanel.Location = New-Object System.Drawing.Point($currentX, $currentY)
        $scriptPanel.Size = New-Object System.Drawing.Size(280, 80)
        $scriptPanel.BackColor = $WinToolkitColors.BackgroundColor
        $scriptPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

        # Pulsante script
        $scriptButton = New-Object System.Windows.Forms.Button
        $scriptButton.Location = New-Object System.Drawing.Point(10, 10)
        $scriptButton.Size = New-Object System.Drawing.Size(200, 25)
        $scriptButton.Text = "$($script.Icon) $($script.Description)"
        $scriptButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $scriptButton.BackColor = $WinToolkitColors.ButtonSecondaryColor
        $scriptButton.ForeColor = $WinToolkitColors.TextColor
        $scriptButton.Font = $WinToolkitTypography.PrimaryFont
        $scriptButton.Tag = $script.Name
        $scriptButton.Add_Click({
                $scriptName = $this.Tag
                $scriptDef = $scriptDefinitions | Where-Object { $_.Name -eq $scriptName }
                Execute-Script -ScriptName $scriptName -Description $scriptDef.Description
            })
        $scriptPanel.Controls.Add($scriptButton)

        # Checkbox selezione
        $checkBox = New-Object System.Windows.Forms.CheckBox
        $checkBox.Location = New-Object System.Drawing.Point(220, 10)
        $checkBox.Size = New-Object System.Drawing.Size(50, 25)
        $checkBox.BackColor = $WinToolkitColors.BackgroundColor
        $checkBox.ForeColor = $WinToolkitColors.TextColor
        $checkBox.Font = $WinToolkitTypography.PrimaryFont
        $checkBox.Tag = $script.Name
        $scriptPanel.Controls.Add($checkBox)

        # Tooltip
        $toolTip = New-Object System.Windows.Forms.ToolTip
        $toolTip.SetToolTip($scriptButton, "Clicca per eseguire solo questo script")

        $Parent.Controls.Add($scriptPanel)

        # Layout griglia
        $currentX += 290
        if ($currentX + 280 -gt $Parent.Width) {
            $currentX = 10
            $currentY += 90
        }
    }
}

# Funzioni per caricare le sezioni
function Load-PreliminariSection {
    $scripts = $scriptDefinitions | Where-Object { $_.Category -eq "Operazioni Preliminari" }
    Load-ScriptSection -Scripts $scripts -X 10 -Y 100
}

function Load-WindowsOfficeSection {
    $scripts = $scriptDefinitions | Where-Object { $_.Category -eq "Windows & Office" }
    Load-ScriptSection -Scripts $scripts -X 10 -Y 100
}

function Load-DriverGamingSection {
    $scripts = $scriptDefinitions | Where-Object { $_.Category -eq "Driver & Gaming" }
    Load-ScriptSection -Scripts $scripts -X 10 -Y 100
}

function Load-SupportoSection {
    $scripts = $scriptDefinitions | Where-Object { $_.Category -eq "Supporto" }
    Load-ScriptSection -Scripts $scripts -X 10 -Y 100
}

function Load-ScriptSection {
    param([array]$Scripts, [int]$X, [int]$Y)

    $currentX = $X
    $currentY = $Y
    $itemsPerRow = 2

    foreach ($script in $Scripts) {
        # Crea un pannello per ogni script
        $scriptPanel = New-Object System.Windows.Forms.Panel
        $scriptPanel.Location = New-Object System.Drawing.Point($currentX, $currentY)
        $scriptPanel.Size = New-Object System.Drawing.Size(280, 80)
        $scriptPanel.BackColor = $WinToolkitColors.PanelColor
        $scriptPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

        # Pulsante per eseguire il singolo script
        $scriptButton = New-Object System.Windows.Forms.Button
        $scriptButton.Location = New-Object System.Drawing.Point(10, 10)
        $scriptButton.Size = New-Object System.Drawing.Size(200, 25)
        $scriptButton.Text = "$($script.Icon) $($script.Description)"
        $scriptButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $scriptButton.BackColor = $WinToolkitColors.ButtonColor
        $scriptButton.ForeColor = $WinToolkitColors.TextColor
        $scriptButton.Font = $WinToolkitFont
        $scriptButton.Tag = $script.Name
        $scriptButton.Add_Click({
                $scriptName = $this.Tag
                $scriptDef = $scriptDefinitions | Where-Object { $_.Name -eq $scriptName }
                Execute-Script -ScriptName $scriptName -Description $scriptDef.Description
            })
        $scriptPanel.Controls.Add($scriptButton)

        # Checkbox per selezione multipla
        $checkBox = New-Object System.Windows.Forms.CheckBox
        $checkBox.Location = New-Object System.Drawing.Point(220, 10)
        $checkBox.Size = New-Object System.Drawing.Size(50, 25)
        $checkBox.BackColor = $WinToolkitColors.PanelColor
        $checkBox.ForeColor = $WinToolkitColors.TextColor
        $checkBox.Font = $WinToolkitFont
        $checkBox.Tag = $script.Name
        $scriptPanel.Controls.Add($checkBox)

        # Aggiungi tooltip
        $toolTip = New-Object System.Windows.Forms.ToolTip
        $toolTip.SetToolTip($scriptButton, "Clicca per eseguire solo questo script")

        $mainContentPanel.Controls.Add($scriptPanel)

        # Organizza in griglia
        $currentX += 290
        if ($currentX + 280 -gt $mainContentPanel.Width) {
            $currentX = 10
            $currentY += 90
        }
    }
}

# Inizializza il primo modulo al caricamento
Load-Module -ModuleName "Operazioni Preliminari"

# Crea la barra di stato con design moderno (Specification Compliant)
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.BackColor = $WinToolkitColors.BackgroundColor
$statusStrip.ForeColor = $WinToolkitColors.TextColor
$statusStrip.Font = $WinToolkitTypography.PrimaryFont
$statusStrip.Height = 25

$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Pronto - Seleziona gli script da eseguire"
$statusLabel.ForeColor = $WinToolkitColors.TextColor
$statusLabel.Font = $WinToolkitTypography.PrimaryFont
$statusStrip.Items.Add($statusLabel)

$mainForm.Controls.Add($statusStrip)

# Salva i riferimenti globali
$global:mainForm = $mainForm
$global:systemInfoLabels = $systemInfoLabels

# Inizializza le informazioni di sistema
Update-SystemInfoPanel

# Messaggio di benvenuto nel log
Update-Log -Message "WinToolkit-GUI avviato con successo" -Type Info
Update-Log -Message "Versione 2.2.3 (Build 7) - GUI Edition" -Type Info

# Mostra la finestra
[void]$mainForm.ShowDialog()

# Cleanup
try { Stop-Transcript | Out-Null } catch {}

Write-Host "WinToolkit-GUI terminato" -ForegroundColor Green