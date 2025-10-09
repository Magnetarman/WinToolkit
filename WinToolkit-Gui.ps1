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
function Write-StyledMessage {
    param([ValidateSet('Success', 'Warning', 'Error', 'Info')][string]$type, [string]$text)
    $config = @{
        Success = @{ Icon = '✓'; Color = 'Green' }
        Warning = @{ Icon = '⚠'; Color = 'Yellow' }
        Error   = @{ Icon = '✗'; Color = 'Red' }
        Info    = @{ Icon = 'ℹ'; Color = 'Cyan' }
    }

    $timestamp = Get-Date -Format "HH:mm:ss"
    $cleanText = $text -replace '^(✓|⚠|✗|ℹ|🔥|▶|⚙|🧹|📦|📋|📜|🔒|💾|⬇|🔧|⚡|🖼|🌐|🪟|🔄|🗂|📁|🖨|📄|🗑|💭|⏸|▶|💡|⏰|🎉|💻|📊|🛡|🔧|🔑|📦|🧹|ℹ|⚙|▶)\s*', ''
    $message = "[$timestamp] $($config[$type].Icon) $cleanText"

    if ($global:logTextBox) {
        $global:logTextBox.AppendText("$message`r`n")
        $global:logTextBox.SelectionStart = $global:logTextBox.Text.Length
        $global:logTextBox.ScrollToCaret()
    }

    Write-Host $message -ForegroundColor $config[$type].Color
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
            $global:systemInfoLabels['Edition'].Text = $windowsEdition
            $global:systemInfoLabels['Version'].Text = "Ver. $windowsVersion (Build $buildNumber)"
            $global:systemInfoLabels['Architecture'].Text = $sysInfo.Architecture
            $global:systemInfoLabels['ComputerName'].Text = $sysInfo.ComputerName
            $global:systemInfoLabels['RAM'].Text = "$($sysInfo.TotalRAM) GB"
            $global:systemInfoLabels['Disk'].Text = "$($sysInfo.FreePercentage)% Libero ($($sysInfo.TotalDisk) GB)"
        }
    }
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
$mainForm.Size = New-Object System.Drawing.Size(1280, 900)
$mainForm.MinimumSize = New-Object System.Drawing.Size(1000, 700)
$mainForm.StartPosition = "CenterScreen"
$mainForm.Font = Get-NerdFont -Size 10
$mainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$mainForm.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSCommandPath)

# Inizializza il tema
Apply-Theme

# Crea il TabControl principale con design moderno
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 10)
$tabControl.Size = New-Object System.Drawing.Size(1240, 650)
$tabControl.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$tabControl.ForeColor = [System.Drawing.Color]::White
$tabControl.Font = Get-NerdFont -Size 9
$tabControl.ItemSize = New-Object System.Drawing.Size(120, 35)
$tabControl.Padding = New-Object System.Drawing.Point(10, 5)

# Crea le categorie come tab con design moderno
$categories = @("Operazioni Preliminari", "Windows & Office", "Driver & Gaming", "Supporto")
$categoryTabs = @{}

foreach ($category in $categories) {
    $tabPage = New-Object System.Windows.Forms.TabPage
    $tabPage.Text = $category
    $tabPage.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
    $tabPage.ForeColor = [System.Drawing.Color]::White
    $tabPage.Font = Get-NerdFont -Size 9
    $tabPage.Padding = New-Object System.Windows.Forms.Padding(10)

    $categoryTabs[$category] = $tabPage
    $tabControl.Controls.Add($tabPage)
}

$mainForm.Controls.Add($tabControl)

# Crea il pannello delle informazioni di sistema con design moderno
$systemInfoPanel = New-Object System.Windows.Forms.GroupBox
$systemInfoPanel.Location = New-Object System.Drawing.Point(10, 670)
$systemInfoPanel.Size = New-Object System.Drawing.Size(420, 160)
$systemInfoPanel.Text = "🖥 Informazioni Sistema"
$systemInfoPanel.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$systemInfoPanel.ForeColor = [System.Drawing.Color]::White
$systemInfoPanel.Font = Get-NerdFont -Size 9

# Crea le label per le informazioni di sistema
$systemInfoLabels = @{}
$infoItems = @("Edition", "Version", "Architecture", "ComputerName", "RAM", "Disk")
$yPos = 25

foreach ($item in $infoItems) {
    $labelTitle = New-Object System.Windows.Forms.Label
    $labelTitle.Location = New-Object System.Drawing.Point(15, $yPos)
    $labelTitle.Size = New-Object System.Drawing.Size(80, 20)
    $labelTitle.Text = "$item`:"
    $labelTitle.ForeColor = [System.Drawing.Color]::Yellow
    $labelTitle.Font = Get-NerdFont -Size 9
    $systemInfoPanel.Controls.Add($labelTitle)

    $labelValue = New-Object System.Windows.Forms.Label
    $labelValue.Location = New-Object System.Drawing.Point(100, $yPos)
    $labelValue.Size = New-Object System.Drawing.Size(280, 20)
    $labelValue.ForeColor = [System.Drawing.Color]::White
    $labelValue.Font = Get-NerdFont -Size 9
    $systemInfoPanel.Controls.Add($labelValue)

    $systemInfoLabels[$item] = $labelValue
    $yPos += 25
}

$mainForm.Controls.Add($systemInfoPanel)

# Crea il pannello di controllo con design moderno
$controlPanel = New-Object System.Windows.Forms.GroupBox
$controlPanel.Location = New-Object System.Drawing.Point(440, 670)
$controlPanel.Size = New-Object System.Drawing.Size(400, 160)
$controlPanel.Text = "🎮 Controlli"
$controlPanel.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$controlPanel.ForeColor = [System.Drawing.Color]::White
$controlPanel.Font = Get-NerdFont -Size 9

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
$refreshButton.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
$refreshButton.ForeColor = [System.Drawing.Color]::White
$refreshButton.FlatStyle = "Flat"
$refreshButton.Font = Get-NerdFont -Size 9
$refreshButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$refreshButton.Add_Click({
        Update-SystemInfoPanel
        Write-StyledMessage -type 'Info' -text "Informazioni di sistema aggiornate"
    })
$controlPanel.Controls.Add($refreshButton)

# Pulsante per eseguire script selezionati
$executeButton = New-Object System.Windows.Forms.Button
$executeButton.Location = New-Object System.Drawing.Point(130, 25)
$executeButton.Size = New-Object System.Drawing.Size(120, 30)
$executeButton.Text = "▶ Esegui Selezionati"
$executeButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 0)
$executeButton.ForeColor = [System.Drawing.Color]::White
$executeButton.FlatStyle = "Flat"
$executeButton.Font = Get-NerdFont -Size 9
$executeButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$executeButton.Add_Click({
        $selectedScripts = [System.Collections.Generic.List[object]]::new()

        foreach ($script in $scriptDefinitions) {
            $checkBoxName = "$($script.Name)CheckBox"
            if ($categoryTabs[$script.Category].Controls[$checkBoxName] -and $categoryTabs[$script.Category].Controls[$checkBoxName].Checked) {
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
$selectAllButton.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
$selectAllButton.ForeColor = [System.Drawing.Color]::White
$selectAllButton.FlatStyle = "Flat"
$selectAllButton.Font = Get-NerdFont -Size 9
$selectAllButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$selectAllButton.Add_Click({
        foreach ($script in $scriptDefinitions) {
            $checkBoxName = "$($script.Name)CheckBox"
            if ($categoryTabs[$script.Category].Controls[$checkBoxName]) {
                $categoryTabs[$script.Category].Controls[$checkBoxName].Checked = $true
            }
        }
    })
$controlPanel.Controls.Add($selectAllButton)

# Pulsante per deselezionare tutto
$deselectAllButton = New-Object System.Windows.Forms.Button
$deselectAllButton.Location = New-Object System.Drawing.Point(15, 65)
$deselectAllButton.Size = New-Object System.Drawing.Size(100, 30)
$deselectAllButton.Text = "☐ Deseleziona"
$deselectAllButton.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
$deselectAllButton.ForeColor = [System.Drawing.Color]::White
$deselectAllButton.FlatStyle = "Flat"
$deselectAllButton.Font = Get-NerdFont -Size 9
$deselectAllButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$deselectAllButton.Add_Click({
        foreach ($script in $scriptDefinitions) {
            $checkBoxName = "$($script.Name)CheckBox"
            if ($categoryTabs[$script.Category].Controls[$checkBoxName]) {
                $categoryTabs[$script.Category].Controls[$checkBoxName].Checked = $false
            }
        }
    })
$controlPanel.Controls.Add($deselectAllButton)

# Campo di ricerca
$searchLabel = New-Object System.Windows.Forms.Label
$searchLabel.Location = New-Object System.Drawing.Point(130, 70)
$searchLabel.Size = New-Object System.Drawing.Size(50, 20)
$searchLabel.Text = "🔍"
$searchLabel.ForeColor = [System.Drawing.Color]::White
$controlPanel.Controls.Add($searchLabel)

$searchTextBox = New-Object System.Windows.Forms.TextBox
$searchTextBox.Location = New-Object System.Drawing.Point(180, 65)
$searchTextBox.Size = New-Object System.Drawing.Size(185, 25)
$searchTextBox.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
$searchTextBox.ForeColor = [System.Drawing.Color]::White
$searchTextBox.BorderStyle = "FixedSingle"
$searchTextBox.Font = Get-NerdFont -Size 9
$searchTextBox.Add_TextChanged({
        $searchTerm = $searchTextBox.Text.ToLower()
        foreach ($script in $scriptDefinitions) {
            $checkBoxName = "$($script.Name)CheckBox"
            if ($categoryTabs[$script.Category].Controls[$checkBoxName]) {
                $visible = $script.Description.ToLower().Contains($searchTerm) -or [string]::IsNullOrEmpty($searchTerm)
                $categoryTabs[$script.Category].Controls[$checkBoxName].Visible = $visible
                $categoryTabs[$script.Category].Controls[$checkBoxName].Parent.Controls["$($script.Name)Button"].Visible = $visible
            }
        }
    })
$controlPanel.Controls.Add($searchTextBox)

# Pulsante per aprire la cartella dei log
$openLogButton = New-Object System.Windows.Forms.Button
$openLogButton.Location = New-Object System.Drawing.Point(265, 65)
$openLogButton.Size = New-Object System.Drawing.Size(100, 30)
$openLogButton.Text = "📂 Log"
$openLogButton.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
$openLogButton.ForeColor = [System.Drawing.Color]::White
$openLogButton.FlatStyle = "Flat"
$openLogButton.Font = Get-NerdFont -Size 9
$openLogButton.Cursor = [System.Windows.Forms.Cursors]::Hand
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
$themeButton.Location = New-Object System.Drawing.Point(15, 105)
$themeButton.Size = New-Object System.Drawing.Size(50, 30)
$currentTheme = Get-CurrentTheme
$themeButton.Text = if ($currentTheme -eq "Dark") { "☀" } else { "🌙" }
$themeButton.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
$themeButton.ForeColor = [System.Drawing.Color]::White
$themeButton.FlatStyle = "Flat"
$themeButton.Font = Get-NerdFont -Size 12
$themeButton.Add_Click({
        $currentTheme = Get-CurrentTheme
        $newTheme = if ($currentTheme -eq "Dark") { "Light" } else { "Dark" }
        Apply-Theme -Theme $newTheme
        $this.Text = if ($newTheme -eq "Dark") { "☀" } else { "🌙" }
        $this.ToolTipText = "$newTheme Mode"
    })
$themeButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$controlPanel.Controls.Add($themeButton)

# Pulsante per esportare configurazione
$exportConfigButton = New-Object System.Windows.Forms.Button
$exportConfigButton.Location = New-Object System.Drawing.Point(130, 105)
$exportConfigButton.Size = New-Object System.Drawing.Size(100, 30)
$exportConfigButton.Text = "📤 Esporta"
$exportConfigButton.BackColor = [System.Drawing.Color]::FromArgb(0, 100, 150)
$exportConfigButton.ForeColor = [System.Drawing.Color]::White
$exportConfigButton.FlatStyle = "Flat"
$exportConfigButton.Font = Get-NerdFont -Size 9
$exportConfigButton.Cursor = [System.Windows.Forms.Cursors]::Hand
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
$importConfigButton.Location = New-Object System.Drawing.Point(245, 105)
$importConfigButton.Size = New-Object System.Drawing.Size(100, 30)
$importConfigButton.Text = "📥 Importa"
$importConfigButton.BackColor = [System.Drawing.Color]::FromArgb(150, 100, 0)
$importConfigButton.ForeColor = [System.Drawing.Color]::White
$importConfigButton.FlatStyle = "Flat"
$importConfigButton.Font = Get-NerdFont -Size 9
$importConfigButton.Cursor = [System.Windows.Forms.Cursors]::Hand
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
$reportButton.Location = New-Object System.Drawing.Point(15, 145)
$reportButton.Size = New-Object System.Drawing.Size(100, 30)
$reportButton.Text = "📊 Report"
$reportButton.BackColor = [System.Drawing.Color]::FromArgb(100, 50, 100)
$reportButton.ForeColor = [System.Drawing.Color]::White
$reportButton.FlatStyle = "Flat"
$reportButton.Font = Get-NerdFont -Size 9
$reportButton.Cursor = [System.Windows.Forms.Cursors]::Hand
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
$stopButton.Location = New-Object System.Drawing.Point(130, 65)
$stopButton.Size = New-Object System.Drawing.Size(60, 30)
$stopButton.Text = "⏹ Stop"
$stopButton.BackColor = [System.Drawing.Color]::FromArgb(150, 0, 0)
$stopButton.ForeColor = [System.Drawing.Color]::White
$stopButton.FlatStyle = "Flat"
$stopButton.Font = Get-NerdFont -Size 9
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
$pauseButton.Location = New-Object System.Drawing.Point(195, 65)
$pauseButton.Size = New-Object System.Drawing.Size(60, 30)
$pauseButton.Text = "⏸ Pausa"
$pauseButton.BackColor = [System.Drawing.Color]::FromArgb(150, 100, 0)
$pauseButton.ForeColor = [System.Drawing.Color]::White
$pauseButton.FlatStyle = "Flat"
$pauseButton.Font = Get-NerdFont -Size 9
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
$resumeButton.Location = New-Object System.Drawing.Point(195, 65)
$resumeButton.Size = New-Object System.Drawing.Size(60, 30)
$resumeButton.Text = "▶ Riprendi"
$resumeButton.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 0)
$resumeButton.ForeColor = [System.Drawing.Color]::White
$resumeButton.FlatStyle = "Flat"
$resumeButton.Font = Get-NerdFont -Size 9
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

$mainForm.Controls.Add($controlPanel)

# Crea il pannello del log con design moderno
$logPanel = New-Object System.Windows.Forms.GroupBox
$logPanel.Location = New-Object System.Drawing.Point(850, 670)
$logPanel.Size = New-Object System.Drawing.Size(400, 160)
$logPanel.Text = "📋 Log"
$logPanel.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$logPanel.ForeColor = [System.Drawing.Color]::White
$logPanel.Font = Get-NerdFont -Size 9

$logTextBox = New-Object System.Windows.Forms.RichTextBox
$logTextBox.Location = New-Object System.Drawing.Point(10, 20)
$logTextBox.Size = New-Object System.Drawing.Size(380, 130)
$logTextBox.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
$logTextBox.ForeColor = [System.Drawing.Color]::White
$logTextBox.ReadOnly = $true
$logTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logTextBox.BorderStyle = "None"
$logPanel.Controls.Add($logTextBox)

# Salva il riferimento globale per il log
$global:logTextBox = $logTextBox

$mainForm.Controls.Add($logPanel)

# Crea il pannello della progress bar con design moderno
$progressPanel = New-Object System.Windows.Forms.GroupBox
$progressPanel.Location = New-Object System.Drawing.Point(10, 840)
$progressPanel.Size = New-Object System.Drawing.Size(1240, 50)
$progressPanel.Text = "📊 Progresso"
$progressPanel.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$progressPanel.ForeColor = [System.Drawing.Color]::White
$progressPanel.Font = Get-NerdFont -Size 9

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 20)
$progressBar.Size = New-Object System.Drawing.Size(1220, 20)
$progressBar.Style = "Continuous"
$progressBar.ForeColor = [System.Drawing.Color]::Lime
$progressPanel.Controls.Add($progressBar)

# Salva il riferimento globale per la progress bar
$global:progressBar = $progressBar

$mainForm.Controls.Add($progressPanel)

# Crea i controlli per ogni categoria
foreach ($script in $scriptDefinitions) {
    $category = $script.Category
    $tabPage = $categoryTabs[$category]

    # Crea un pannello per ogni script con design moderno
    $scriptPanel = New-Object System.Windows.Forms.Panel
    $scriptPanel.Size = New-Object System.Drawing.Size(280, 80)
    $scriptPanel.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    $scriptPanel.BorderStyle = "FixedSingle"

    # Pulsante per eseguire il singolo script con design moderno
    $scriptButton = New-Object System.Windows.Forms.Button
    $scriptButton.Location = New-Object System.Drawing.Point(10, 10)
    $scriptButton.Size = New-Object System.Drawing.Size(200, 25)
    $scriptButton.Text = "$($script.Icon) $($script.Description)"
    $scriptButton.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
    $scriptButton.ForeColor = [System.Drawing.Color]::White
    $scriptButton.FlatStyle = "Flat"
    $scriptButton.Font = Get-NerdFont -Size 8
    $scriptButton.Tag = $script.Name
    $scriptButton.Add_Click({
            $scriptName = $this.Tag
            $scriptDef = $scriptDefinitions | Where-Object { $_.Name -eq $scriptName }
            Execute-Script -ScriptName $scriptName -Description $scriptDef.Description
        })
    $scriptPanel.Controls.Add($scriptButton)

    # Nome del controllo per riferimento
    $scriptButton.Name = "$($script.Name)Button"

    # Checkbox per selezione multipla con design moderno
    $checkBox = New-Object System.Windows.Forms.CheckBox
    $checkBox.Location = New-Object System.Drawing.Point(220, 10)
    $checkBox.Size = New-Object System.Drawing.Size(50, 25)
    $checkBox.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    $checkBox.ForeColor = [System.Drawing.Color]::White
    $checkBox.Font = Get-NerdFont -Size 8
    $checkBox.Tag = $script.Name
    $checkBox.Name = "$($script.Name)CheckBox"
    $scriptPanel.Controls.Add($checkBox)

    # Descrizione del tooltip
    $toolTip = New-Object System.Windows.Forms.ToolTip
    $toolTip.SetToolTip($scriptButton, "Clicca per eseguire solo questo script")

    $tabPage.Controls.Add($scriptPanel)
}

# Organizza i controlli nelle tab con layout a griglia
$xPos = 10
$yPos = 10
$itemsPerRow = 2

foreach ($category in $categories) {
    $tabPage = $categoryTabs[$category]
    $xPos = 10
    $yPos = 10

    $categoryScripts = $scriptDefinitions | Where-Object { $_.Category -eq $category }

    foreach ($script in $categoryScripts) {
        $buttonName = "$($script.Name)Button"
        if ($tabPage.Controls.ContainsKey($buttonName)) {
            $scriptButton = $tabPage.Controls[$buttonName]
            $scriptPanel = $scriptButton.Parent
            $scriptPanel.Location = New-Object System.Drawing.Point($xPos, $yPos)

            $xPos += 290
            if ($xPos + 280 -gt $tabPage.Width) {
                $xPos = 10
                $yPos += 90
            }
        }
    }
}

# Crea la barra di stato con design moderno
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$statusStrip.ForeColor = [System.Drawing.Color]::White
$statusStrip.Font = Get-NerdFont -Size 9
$statusStrip.Height = 25

$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Pronto - Seleziona gli script da eseguire"
$statusLabel.ForeColor = [System.Drawing.Color]::White
$statusLabel.Font = Get-NerdFont -Size 9
$statusStrip.Items.Add($statusLabel)

$mainForm.Controls.Add($statusStrip)

# Salva i riferimenti globali
$global:mainForm = $mainForm
$global:systemInfoLabels = $systemInfoLabels

# Inizializza le informazioni di sistema
Update-SystemInfoPanel

# Messaggio di benvenuto nel log
Write-StyledMessage -type 'Info' -text "WinToolkit-GUI avviato con successo"
Write-StyledMessage -type 'Info' -text "Versione 2.2.3 (Build 7) - GUI Edition"

# Mostra la finestra
[void]$mainForm.ShowDialog()

# Cleanup
try { Stop-Transcript | Out-Null } catch {}

Write-Host "WinToolkit-GUI terminato" -ForegroundColor Green