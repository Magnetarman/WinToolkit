function WinPSP-Setup {
    <#
    .SYNOPSIS
        Script di setup per l'ambiente di sviluppo PowerShell.
    .DESCRIPTION
        Configura l'ambiente PowerShell installando Nerd Fonts, Oh My Posh,
        zoxide, btop e fastfetch per un'esperienza da terminale ottimizzata.
    #>
    [CmdletBinding()]
    param()

    # ============================================================================
    # INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName "PSP-Setup"
    Show-Header -SubTitle "PSP Setup"

    # ============================================================================
    # FUNZIONI
    # ============================================================================

    function Install-NerdFonts {
        <#
        .SYNOPSIS
            Installa i Nerd Fonts necessari per il terminale.
        #>
        try {
            [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
            $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
            $fontDisplayName = "JetBrainsMono Nerd Font Mono"

            if ($fontFamilies -notcontains $fontDisplayName) {
                Write-StyledMessage -Type 'Info' -Text "⬇️ Download JetBrainsMono Nerd Font..."

                $fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
                $zipFilePath = "$env:TEMP\JetBrainsMono.zip"
                $extractPath = "$env:TEMP\JetBrainsMono"

                Write-StyledMessage -Type 'Info' -Text "Download in corso..."
                Invoke-WebRequest -Uri $fontZipUrl -OutFile $zipFilePath -UseBasicParsing

                Write-StyledMessage -Type 'Info' -Text "Estrazione font..."
                Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force

                Write-StyledMessage -Type 'Info' -Text "Installazione font..."
                Get-ChildItem -Path $extractPath -Recurse -Filter "*.ttf" | ForEach-Object {
                    $fontName = $_.Name
                    $destPath = "C:\Windows\Fonts\$fontName"
                    If (-not(Test-Path $destPath)) {
                        Copy-Item $_.FullName -Destination $destPath
                        Write-StyledMessage -Type 'Info' -Text "Installato: $fontName"
                    }
                }

                Remove-Item -Path $extractPath -Recurse -Force
                Remove-Item -Path $zipFilePath -Force
                Write-StyledMessage -Type 'Success' -Text "JetBrainsMono Nerd Font installato"
                return $true
            }
            else {
                Write-StyledMessage -Type 'Info' -Text "JetBrainsMono Nerd Font già installato"
                return $true
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore installazione font: $($_.Exception.Message)"
            return $false
        }
    }

    function Get-ProfileDir {
        <#
        .SYNOPSIS
            Restituisce il percorso del profilo PowerShell in base all'edizione.
        #>
        if ($PSVersionTable.PSEdition -eq "Core") {
            return "$env:userprofile\Documents\PowerShell"
        }
        elseif ($PSVersionTable.PSEdition -eq "Desktop") {
            return "$env:userprofile\Documents\WindowsPowerShell"
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Edizione PowerShell non supportata: $($PSVersionTable.PSEdition)"
            return $null
        }
    }

    function Install-OhMyPoshTheme {
        <#
        .SYNOPSIS
            Scarica e installa il tema Oh My Posh.
        .PARAMETER ThemeName
            Nome del tema da scaricare.
        .PARAMETER ThemeUrl
            URL completo del tema.
        #>
        param(
            [string]$ThemeName = "atomic",
            [string]$ThemeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/atomic.omp.json"
        )

        $profilePath = Get-ProfileDir
        if (-not $profilePath) {
            return $null
        }

        if (-not (Test-Path -Path $profilePath)) {
            New-Item -Path $profilePath -ItemType "directory" -Force | Out-Null
        }

        $themeFilePath = Join-Path $profilePath "$ThemeName.omp.json"
        try {
            Write-StyledMessage -Type 'Info' -Text "⬇️ Download tema Oh My Posh: $ThemeName..."
            Invoke-RestMethod -Uri $ThemeUrl -OutFile $themeFilePath
            Write-StyledMessage -Type 'Success' -Text "Tema '$ThemeName' installato"
            return $themeFilePath
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore download tema: $($_.Exception.Message)"
            return $null
        }
    }

    # ============================================================================
    # INSTALLAZIONE COMPONENTI
    # ============================================================================

    # Installazione Oh My Posh
    Write-StyledMessage -Type 'Info' -Text "📦 Installazione Oh My Posh..."
    try {
        winget install -e --accept-source-agreements --accept-package-agreements JanDeDobbeleer.OhMyPosh
        Write-StyledMessage -Type 'Success' -Text "Oh My Posh installato"
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore installazione Oh My Posh: $($_.Exception.Message)"
    }

    # Download tema Oh My Posh
    $themeInstalled = Install-OhMyPoshTheme -ThemeName "atomic"

    # Installazione Font
    Write-StyledMessage -Type 'Info' -Text "🔤 Installazione Nerd Fonts..."
    $fontResult = Install-NerdFonts

    # Installazione zoxide
    Write-StyledMessage -Type 'Info' -Text "🦎 Installazione zoxide..."
    try {
        winget install -e --id ajeetdsouza.zoxide
        Write-StyledMessage -Type 'Success' -Text "zoxide installato"
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore installazione zoxide: $($_.Exception.Message)"
    }

    # Installazione btop
    Write-StyledMessage -Type 'Info' -Text "📊 Installazione btop..."
    try {
        winget install -e --id aristocratos.btop4win
        Write-StyledMessage -Type 'Success' -Text "btop installato"
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore installazione btop: $($_.Exception.Message)"
    }

    # Installazione fastfetch
    Write-StyledMessage -Type 'Info' -Text "⚡ Installazione fastfetch..."
    try {
        winget install -e --id Fastfetch-cli.Fastfetch
        Write-StyledMessage -Type 'Success' -Text "fastfetch installato"
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore installazione fastfetch: $($_.Exception.Message)"
    }

    # ============================================================================
    # CONFIGURAZIONE PROFILO POWERSHELL
    # ============================================================================

    Write-StyledMessage -Type 'Info' -Text "⚙️ Configurazione profilo PowerShell..."
    if (-not (Test-Path -Path $PROFILE -PathType Leaf)) {
        try {
            $profilePath = Get-ProfileDir
            if (-not $profilePath) {
                throw "Impossibile determinare il percorso del profilo"
            }
            if (-not (Test-Path -Path $profilePath)) {
                New-Item -Path $profilePath -ItemType "directory" -Force | Out-Null
            }
            Invoke-RestMethod https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Microsoft.PowerShell_profile.ps1 -OutFile $PROFILE
            Write-StyledMessage -Type 'Success' -Text "Profilo PowerShell creato: $PROFILE"
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore creazione profilo: $($_.Exception.Message)"
        }
    }
    else {
        try {
            $backupPath = Join-Path (Split-Path $PROFILE) "oldprofile.ps1"
            Move-Item -Path $PROFILE -Destination $backupPath -Force
            Invoke-RestMethod https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Microsoft.PowerShell_profile.ps1 -OutFile $PROFILE
            Write-StyledMessage -Type 'Success' -Text "Profilo PowerShell aggiornato"
            Write-StyledMessage -Type 'Info' -Text "Backup salvato: $backupPath"
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore aggiornamento profilo: $($_.Exception.Message)"
        }
    }

    # ============================================================================
    # CONFIGURAZIONE WINDOWS TERMINAL SETTINGS.JSON
    # ============================================================================

    Write-StyledMessage -Type 'Info' -Text "⚙️ Configurazione settings.json per Windows Terminal..."
    try {
        $wtSettingsUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/settings.json"
        $wtPath = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Directory -Filter "Microsoft.WindowsTerminal_*" -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if (-not $wtPath) {
            Write-StyledMessage -Type 'Warning' -Text "Directory Windows Terminal non trovata, impossibile configurare settings.json."
        }
        else {
            $wtLocalStateDir = Join-Path $wtPath.FullName "LocalState"
            if (-not (Test-Path $wtLocalStateDir)) {
                New-Item -ItemType Directory -Path $wtLocalStateDir -Force | Out-Null
            }
            $settingsPath = Join-Path $wtLocalStateDir "settings.json"
            
            Write-StyledMessage -Type 'Info' -Text "Download settings.json per Windows Terminal..."
            Invoke-WebRequest $wtSettingsUrl -OutFile $settingsPath -UseBasicParsing
            Write-StyledMessage -Type 'Success' -Text "settings.json configurato: $settingsPath"
        }
    }
    catch [System.Net.WebException] {
        Write-StyledMessage -Type 'Error' -Text "Errore di rete durante il download di settings.json: $($_.Exception.Message)"
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante la configurazione di settings.json: $($_.Exception.Message)"
    }

    # ============================================================================
    # RIEPILOGO
    # ============================================================================"

    Write-Host ""
    Write-StyledMessage -Type 'Success' -Text "✅ Setup PSP completato!"
    Write-StyledMessage -Type 'Info' -Text "💡 Riavvia la sessione di PowerShell per applicare le modifiche"
}
