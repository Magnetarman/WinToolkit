<#
.SYNOPSIS
    Configurazione per WinToolkit-GUI
.DESCRIPTION
    File di configurazione centralizzato per definire script, categorie e impostazioni
.NOTES
    Modifica questo file per aggiungere nuovi script o modificare le categorie esistenti
#>

# Configurazione generale
$config = @{
    Version     = "2.2.3"
    Build       = "7"
    GuiEdition  = $true
    WindowTitle = "WinToolkit-GUI by MagnetarMan"
    WindowSize  = @{ Width = 1200; Height = 800 }
    Theme       = @{
        BackgroundColor    = [System.Drawing.Color]::FromArgb(45, 45, 48)
        PanelColor         = [System.Drawing.Color]::FromArgb(30, 30, 30)
        ButtonColor        = [System.Drawing.Color]::FromArgb(70, 70, 70)
        AccentColor        = [System.Drawing.Color]::FromArgb(0, 120, 0)
        TextColor          = [System.Drawing.Color]::White
        TextColorSecondary = [System.Drawing.Color]::Yellow
    }
}

# Definizione delle categorie
$categories = @(
    @{
        Name        = "Operazioni Preliminari"
        Icon        = "🪄"
        Description = "Script di preparazione e configurazione iniziale"
        Color       = [System.Drawing.Color]::FromArgb(100, 50, 150)
    },
    @{
        Name        = "Windows & Office"
        Icon        = "🔧"
        Description = "Strumenti per Windows e Microsoft Office"
        Color       = [System.Drawing.Color]::FromArgb(50, 100, 150)
    },
    @{
        Name        = "Driver & Gaming"
        Icon        = "🎮"
        Description = "Driver grafici e ottimizzazioni gaming"
        Color       = [System.Drawing.Color]::FromArgb(150, 50, 100)
    },
    @{
        Name        = "Supporto"
        Icon        = "🕹️"
        Description = "Strumenti di supporto e utility"
        Color       = [System.Drawing.Color]::FromArgb(100, 150, 50)
    }
)

# Definizione degli script disponibili
$scriptDefinitions = @(
    # Operazioni Preliminari
    @{
        Name              = "WinInstallPSProfile"
        Description       = "Installa profilo PowerShell"
        Category          = "Operazioni Preliminari"
        Icon              = "⚡"
        Tooltip           = "Installa e configura il profilo PowerShell personalizzato con oh-my-posh, zoxide e altre utilità"
        RequiresAdmin     = $true
        EstimatedDuration = "5-10 minuti"
    },

    # Windows & Office
    @{
        Name              = "WinRepairToolkit"
        Description       = "Toolkit Riparazione Windows"
        Category          = "Windows & Office"
        Icon              = "🔧"
        Tooltip           = "Esegue una serie di strumenti di riparazione di Windows (chkdsk, SFC, DISM) in sequenza"
        RequiresAdmin     = $true
        EstimatedDuration = "15-30 minuti"
    },
    @{
        Name              = "WinUpdateReset"
        Description       = "Reset Windows Update"
        Category          = "Windows & Office"
        Icon              = "🔄"
        Tooltip           = "Ripara i problemi comuni di Windows Update e reinstalla componenti critici"
        RequiresAdmin     = $true
        EstimatedDuration = "10-15 minuti"
    },
    @{
        Name              = "WinReinstallStore"
        Description       = "Winget/WinStore Reset"
        Category          = "Windows & Office"
        Icon              = "🛒"
        Tooltip           = "Reinstalla automaticamente Winget, Microsoft Store e UniGet UI"
        RequiresAdmin     = $true
        EstimatedDuration = "10-20 minuti"
    },
    @{
        Name              = "WinBackupDriver"
        Description       = "Backup Driver PC"
        Category          = "Windows & Office"
        Icon              = "💾"
        Tooltip           = "Esegue il backup completo di tutti i driver di terze parti installati"
        RequiresAdmin     = $true
        EstimatedDuration = "5-15 minuti"
    },
    @{
        Name              = "WinCleaner"
        Description       = "Pulizia File Temporanei"
        Category          = "Windows & Office"
        Icon              = "🧹"
        Tooltip           = "Esegue una pulizia completa e automatica del sistema Windows"
        RequiresAdmin     = $true
        EstimatedDuration = "10-30 minuti"
    },
    @{
        Name              = "OfficeToolkit"
        Description       = "Office Toolkit"
        Category          = "Windows & Office"
        Icon              = "📝"
        Tooltip           = "Gestisce Microsoft Office: installazione, riparazione e rimozione"
        RequiresAdmin     = $false
        EstimatedDuration = "5-20 minuti"
    },

    # Driver & Gaming
    @{
        Name              = "WinDriverInstall"
        Description       = "Toolkit Driver Grafici"
        Category          = "Driver & Gaming"
        Icon              = "🎮"
        Tooltip           = "Toolkit per l'installazione e configurazione driver GPU (in sviluppo)"
        RequiresAdmin     = $true
        EstimatedDuration = "10-25 minuti"
        Status            = "In sviluppo - V2.3"
    },
    @{
        Name              = "GamingToolkit"
        Description       = "Gaming Toolkit"
        Category          = "Driver & Gaming"
        Icon              = "🎯"
        Tooltip           = "Ottimizzazioni per il gaming su Windows (in sviluppo)"
        RequiresAdmin     = $true
        EstimatedDuration = "5-15 minuti"
        Status            = "In sviluppo - V2.4"
    },

    # Supporto
    @{
        Name              = "SetRustDesk"
        Description       = "Setting RustDesk"
        Category          = "Supporto"
        Icon              = "🖥️"
        Tooltip           = "Configura ed installa RustDesk con configurazioni personalizzate"
        RequiresAdmin     = $true
        EstimatedDuration = "5-15 minuti"
    }
)

# Impostazioni avanzate
$advancedSettings = @{
    Logging       = @{
        Enabled          = $true
        MaxLogSize       = 10MB
        LogRetentionDays = 30
        LogDirectory     = "$env:LOCALAPPDATA\WinToolkit\logs"
    }
    Execution     = @{
        DefaultTimeout      = 1800  # secondi
        RetryAttempts       = 2
        PauseBetweenScripts = 1000  # millisecondi
        ShowProgressBar     = $true
        ShowDetailedOutput  = $true
    }
    UI            = @{
        RefreshInterval          = 5000  # millisecondi
        AnimationEnabled         = $true
        ConfirmMultipleExecution = $true
        ShowTooltips             = $true
        ShowEstimatedDuration    = $true
    }
    Compatibility = @{
        CheckWindowsVersion     = $true
        MinWindowsBuild         = 10240
        RequireAdministrator    = $false
        CheckInternetConnection = $true
    }
}

# Funzione per ottenere la configurazione
function Get-WinToolkitConfig {
    return $config
}

# Funzione per ottenere le categorie
function Get-WinToolkitCategories {
    return $categories
}

# Funzione per ottenere gli script
function Get-WinToolkitScripts {
    return $scriptDefinitions
}

# Funzione per ottenere le impostazioni avanzate
function Get-WinToolkitAdvancedSettings {
    return $advancedSettings
}

# Funzione per validare la configurazione
function Test-WinToolkitConfiguration {
    $errors = @()

    # Verifica che tutte le categorie esistano
    foreach ($script in $scriptDefinitions) {
        $categoryExists = $categories | Where-Object { $_.Name -eq $script.Category }
        if (-not $categoryExists) {
            $errors += "Categoria non trovata: $($script.Category)"
        }
    }

    # Verifica che tutti gli script esistano come funzioni
    foreach ($script in $scriptDefinitions) {
        $functionExists = Get-Command $script.Name -ErrorAction SilentlyContinue
        if (-not $functionExists) {
            $errors += "Funzione non trovata: $($script.Name)"
        }
    }

    return $errors
}

# Esporta le configurazioni se caricato come modulo
if ($MyInvocation.ScriptName) {
    Export-ModuleMember -Function Get-WinToolkitConfig, Get-WinToolkitCategories, Get-WinToolkitScripts, Get-WinToolkitAdvancedSettings, Test-WinToolkitConfiguration
}