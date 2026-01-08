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
            Installa e registra i Nerd Fonts necessari per il terminale.
        .DESCRIPTION
            Utilizza il metodo Shell.Application di Windows per installare i font,
            che li registra automaticamente nel sistema senza necessità di modifiche manuali al registro.
        #>
        try {
            # Verifica se il font è già installato utilizzando InstalledFontCollection
            $fontNameCheck = "JetBrainsMono Nerd Font"
            $fonts = [System.Drawing.Text.InstalledFontCollection]::new()
            if ($fonts.Families.Name -contains $fontNameCheck) {
                Write-StyledMessage -Type 'Info' -Text "$fontNameCheck già installato."
                return $true
            }
            
            # Check alternativo: verifica file font nella cartella Fonts di sistema
            $fontsPath = "C:\Windows\Fonts"
            $jetBrainsFonts = Get-ChildItem -Path $fontsPath -Filter "*JetBrainsMono*" -ErrorAction SilentlyContinue
            if ($jetBrainsFonts) {
                Write-StyledMessage -Type 'Info' -Text "File JetBrainsMono già presenti in $fontsPath. Installazione saltata."
                return $true
            }

            Write-StyledMessage -Type 'Info' -Text "⬇️ Download JetBrainsMono Nerd Font..."

            # Forza TLS 1.2 o superiore per risolvere errori SSL
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

            # Interrogazione GitHub API per l'ultima versione di JetBrainsMono Nerd Font
            $fontZipUrl = $null
            try {
                $release = Invoke-RestMethod "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" -ErrorAction Stop
                $asset = $release.assets | Where-Object { $_.name -eq "JetBrainsMono.zip" } | Select-Object -First 1
                if ($asset) {
                    $fontZipUrl = $asset.browser_download_url
                    Write-StyledMessage -Type 'Info' -Text "Trovata ultima versione: $($release.tag_name) da $fontZipUrl"
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "Asset 'JetBrainsMono.zip' non trovato nell'ultima release. Utilizzo URL di fallback."
                    $fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.zip"
                }
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Errore durante il recupero dell'ultima versione da GitHub API: $($_.Exception.Message). Utilizzo URL di fallback."
                $fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.zip"
            }

            if (-not $fontZipUrl) {
                Write-StyledMessage -Type 'Error' -Text "Impossibile determinare l'URL per il download del font. Installazione annullata."
                return $false
            }

            $zipFilePath = "$env:TEMP\JetBrainsMono.zip"
            $extractPath = "$env:TEMP\JetBrainsMono"

            Write-StyledMessage -Type 'Info' -Text "Download in corso..."
            Invoke-WebRequest -Uri $fontZipUrl -OutFile $zipFilePath -UseBasicParsing -ErrorAction Stop

            Write-StyledMessage -Type 'Info' -Text "Estrazione font..."
            Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force

            Write-StyledMessage -Type 'Info' -Text "Installazione font tramite Shell.Application (metodo nativo Windows)..."

            # Metodo Shell.Application - copia e registra automaticamente i font
            # 0x14 = CSIDL_FONTS (cartella font di sistema)
            $shellFontFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)
            
            $fontsInstalled = 0
            Get-ChildItem -Path $extractPath -Recurse -Filter "*.ttf" | ForEach-Object {
                $fontName = $_.Name
                $destPath = "C:\Windows\Fonts\$fontName"
                If (-not(Test-Path $destPath)) {
                    # CopyHere con flag 0x10 (FO_SILENT | FO_NORECURSION) per installazione silenziosa
                    $shellFontFolder.CopyHere($_.FullName, 0x10)
                    $fontsInstalled++
                }
            }

            # Pulizia file temporanei
            Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $zipFilePath -Force -ErrorAction SilentlyContinue

            if ($fontsInstalled -gt 0) {
                Write-StyledMessage -Type 'Success' -Text "Installati $fontsInstalled font JetBrainsMono. Riavvio richiesto per renderli disponibili."
            }
            else {
                Write-StyledMessage -Type 'Info' -Text "Nessun nuovo font installato (già presenti o problema download)."
            }
            return $true
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
        .DESCRIPTION
            Funzione helper per compatibilità cross-edizione (Core vs Desktop).
        #>
        if ($PSVersionTable.PSEdition -eq "Core") {
            return [Environment]::GetFolderPath("MyDocuments") + "\PowerShell"
        }
        elseif ($PSVersionTable.PSEdition -eq "Desktop") {
            return [Environment]::GetFolderPath("MyDocuments") + "\WindowsPowerShell"
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
        .DESCRIPTION
            Scarica il tema nella cartella Themes del profilo PowerShell per una gestione centralizzata.
        .PARAMETER ThemeName
            Nome del tema da scaricare (senza estensione).
        .PARAMETER ThemeUrl
            URL completo del tema .omp.json.
        .OUTPUTS
            String - Percorso completo al file del tema installato, o $null se fallisce.
        #>
        param(
            [string]$ThemeName = "atomic",
            [string]$ThemeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"
        )

        $profileDir = Get-ProfileDir
        if (-not $profileDir) {
            return $null
        }

        # Crea la sottocartella Themes se non esiste
        $themesFolder = Join-Path $profileDir "Themes"
        if (-not (Test-Path -Path $themesFolder)) {
            New-Item -Path $themesFolder -ItemType "directory" -Force | Out-Null
            Write-StyledMessage -Type 'Info' -Text "Creata cartella Themes: $themesFolder"
        }

        $themeFilePath = Join-Path $themesFolder "$ThemeName.omp.json"
        
        # Verifica se il tema esiste già
        if (Test-Path $themeFilePath) {
            Write-StyledMessage -Type 'Info' -Text "Tema '$ThemeName' già presente in: $themeFilePath"
            return $themeFilePath
        }

        try {
            # Forza TLS 1.2 o superiore
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
            
            Write-StyledMessage -Type 'Info' -Text "⬇️ Download tema Oh My Posh: $ThemeName..."
            Invoke-WebRequest -Uri $ThemeUrl -OutFile $themeFilePath -UseBasicParsing -ErrorAction Stop
            Write-StyledMessage -Type 'Success' -Text "Tema '$ThemeName' installato in: $themeFilePath"
            return $themeFilePath
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Impossibile scaricare il tema Oh My Posh. Verifica URL o connessione. Errore: $($_.Exception.Message)"
            return $null
        }
    }

    # ============================================================================
    # INSTALLAZIONE COMPONENTI
    # ============================================================================

    # Forza TLS 1.2 o superiore per tutte le operazioni web
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

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
    if ($themeInstalled) {
        Write-StyledMessage -Type 'Info' -Text "Percorso tema: $themeInstalled"
    }

    # Installazione Font
    Write-StyledMessage -Type 'Info' -Text "🔤 Installazione Nerd Fonts..."
    $fontResult = Install-NerdFonts

    # Installazione zoxide
    Write-StyledMessage -Type 'Info' -Text "🦎 Installazione zoxide..."
    $zoxideResult = winget install -e --id ajeetdsouza.zoxide --accept-source-agreements --accept-package-agreements 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-StyledMessage -Type 'Success' -Text "zoxide installato"
    }
    else {
        Write-StyledMessage -Type 'Error' -Text "Errore installazione zoxide: $zoxideResult"
    }

    # Installazione btop
    Write-StyledMessage -Type 'Info' -Text "📊 Installazione btop..."
    $btopResult = winget install -e --id aristocratos.btop4win --accept-source-agreements --accept-package-agreements 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-StyledMessage -Type 'Success' -Text "btop installato"
    }
    else {
        Write-StyledMessage -Type 'Error' -Text "Errore installazione btop: $btopResult"
    }

    # Installazione fastfetch
    Write-StyledMessage -Type 'Info' -Text "⚡ Installazione fastfetch..."
    $fastfetchResult = winget install -e --id Fastfetch-cli.Fastfetch --accept-source-agreements --accept-package-agreements 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-StyledMessage -Type 'Success' -Text "fastfetch installato"
    }
    else {
        Write-StyledMessage -Type 'Error' -Text "Errore installazione fastfetch: $fastfetchResult"
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
            Invoke-RestMethod https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/Microsoft.PowerShell_profile.ps1 -OutFile $PROFILE -ErrorAction Stop
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
            Invoke-RestMethod https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/Microsoft.PowerShell_profile.ps1 -OutFile $PROFILE -ErrorAction Stop
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
        $wtSettingsUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/asset/settings.json"
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
            Invoke-WebRequest $wtSettingsUrl -OutFile $settingsPath -UseBasicParsing -ErrorAction Stop
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
    # ============================================================================

    Write-Host ""
    Write-StyledMessage -Type 'Success' -Text "✅ Setup PSP completato!"
    Write-StyledMessage -Type 'Info' -Text "💡 Riavvia la sessione di PowerShell per applicare le modifiche"
    
    if ($themeInstalled) {
        Write-Host ""
        Write-StyledMessage -Type 'Info' -Text "📍 Percorso tema Oh My Posh:"
        Write-Host "   $themeInstalled" -ForegroundColor Cyan
    }
}
