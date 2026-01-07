function WinPSP-Setup {
    <#
    .SYNOPSIS
        Script per l'installazione e configurazione dell'ambiente PowerShell.

    .DESCRIPTION
        Installa e configura Oh My Posh, zoxide, btop, fastfetch, Nerd Fonts (JetBrainsMono),
        tema Oh My Posh "atomic", profilo PowerShell personalizzato e configurazione
        Windows Terminal.
        Richiede PowerShell 7+ e privilegi amministratore.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 300)]
        [int]$CountdownSeconds = 30
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE CON FRAMEWORK GLOBALE
    # ============================================================================

    Initialize-ToolLogging -ToolName "WinPSP-Setup"
    Show-Header -SubTitle "PSP Setup Toolkit"
    $Host.UI.RawUI.WindowTitle = "PSP Setup Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E COSTANTI
    # ============================================================================

    $script:PSPConfig = @{
        GitHubProfileUrl  = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Microsoft.PowerShell_profile.ps1"
        GitHubSettingsUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/settings.json"
        ThemeUrl          = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/atomic.omp.json"
        FontName          = "JetBrainsMono Nerd Font Mono"
    }

    # ============================================================================
    # 3. FUNZIONI CORE
    # ============================================================================

    function Add-ToSystemPath {
        <#
        .SYNOPSIS
            Aggiunge un percorso al PATH di sistema.
        #>
        param([string]$PathToAdd)
        
        try {
            if (-not (Test-Path $PathToAdd)) {
                Write-StyledMessage Warning "Percorso non esistente: $PathToAdd"
                return $false
            }

            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            $pathExists = ($currentPath -split ';') | Where-Object { $_.TrimEnd('\') -ieq $PathToAdd.TrimEnd('\') }

            if ($pathExists) {
                Write-StyledMessage Info "Percorso già nel PATH: $PathToAdd"
                return $true
            }

            $PathToAdd = $PathToAdd.TrimStart(';')
            $newPath = if ($currentPath.EndsWith(';')) { "$currentPath$PathToAdd" } else { "$currentPath;$PathToAdd" }
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            $env:PATH = "$env:PATH;$PathToAdd"

            Write-StyledMessage Success "Percorso aggiunto al PATH: $PathToAdd"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore aggiunta PATH: $($_.Exception.Message)"
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
            Write-StyledMessage Error "Edizione PowerShell non supportata: $($PSVersionTable.PSEdition)"
            return $null
        }
    }

    function Get-RemoteVersion {
        <#
        .SYNOPSIS
            Estrae la versione dall'intestazione del file remoto usando regex.
        #>
        param([string]$Url)
        
        try {
            $content = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop | ForEach-Object Content
            $match = $content -match 'Versione:\s*(\d+\.\d+\.\d+)'
            if ($match) {
                return [version]$Matches[1]
            }
            return $null
        }
        catch {
            Write-StyledMessage Error "Errore recupero versione remota: $($_.Exception.Message)"
            return $null
        }
    }

    function Get-LocalVersion {
        <#
        .SYNOPSIS
            Estrae la versione dall'intestazione del profilo locale.
        #>
        param([string]$ProfilePath)
        
        if (-not (Test-Path $ProfilePath)) { return $null }
        
        try {
            $content = Get-Content -Path $ProfilePath -Raw -ErrorAction Stop
            $match = $content -match 'Versione:\s*(\d+\.\d+\.\d+)'
            if ($match) {
                return [version]$Matches[1]
            }
            return $null
        }
        catch {
            return $null
        }
    }

    function Install-NerdFont {
        <#
        .SYNOPSIS
            Installa il Nerd Font JetBrainsMono se non presente.
        #>
        try {
            [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
            $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name

            if ($fontFamilies -contains $script:PSPConfig.FontName) {
                Write-StyledMessage Info "$($script:PSPConfig.FontName) già installato"
                return $true
            }

            Write-StyledMessage Info "Download JetBrainsMono Nerd Font..."

            $apiUrl = "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
            $releaseInfo = Invoke-RestMethod -Uri $apiUrl
            $fontZipUrl = ($releaseInfo.assets | Where-Object { $_.name -eq "JetBrainsMono.zip" }).browser_download_url

            if (-not $fontZipUrl) {
                Write-StyledMessage Error "Asset JetBrainsMono.zip non trovato"
                return $false
            }

            $zipFilePath = "$env:TEMP\JetBrainsMono.zip"
            $extractPath = "$env:TEMP\JetBrainsMono"

            Invoke-WebRequest -Uri $fontZipUrl -OutFile $zipFilePath -UseBasicParsing
            
            Write-StyledMessage Info "Estrazione font..."
            Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force

            $destination = (New-Object -ComObject Shell.Application).Namespace(0x14)
            Get-ChildItem -Path "$extractPath\JetBrainsMonoNerdFont-*\variable" -Filter "*.ttf" | ForEach-Object {
                If (-not(Test-Path "C:\Windows\Fonts\$($_.Name)")) {
                    $destination.CopyHere($_.FullName, 0x10)
                }
            }

            Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $zipFilePath -Force -ErrorAction SilentlyContinue

            Write-StyledMessage Success "JetBrainsMono Nerd Font installato"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore installazione font: $($_.Exception.Message)"
            return $false
        }
    }

    function Install-OhMyPoshTheme {
        <#
        .SYNOPSIS
            Scarica e installa il tema Oh My Posh atomic.
        #>
        try {
            $profilePath = Get-ProfileDir
            if (-not $profilePath) { return $false }

            if (-not (Test-Path $profilePath)) {
                New-Item -Path $profilePath -ItemType Directory -Force | Out-Null
            }

            $themeFilePath = Join-Path $profilePath "atomic.omp.json"
            Invoke-RestMethod -Uri $script:PSPConfig.ThemeUrl -OutFile $themeFilePath -ErrorAction Stop

            Write-StyledMessage Success "Tema 'atomic' installato"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore download tema: $($_.Exception.Message)"
            return $false
        }
    }

    function Install-WinGetPackage {
        <#
        .SYNOPSIS
            Installa un pacchetto tramite WinGet con feedback visivo.
        #>
        param(
            [string]$Name,
            [string]$Id,
            [string]$Icon
        )
        
        try {
            Write-StyledMessage Info "Installazione $Name..."
            
            $installAction = {
                $process = Start-Process -FilePath "cmd" -ArgumentList "/c winget install -e --id $Id --accept-source-agreements --accept-package-agreements --silent" -NoNewWindow -PassThru -Wait
                return $process.ExitCode
            }
            
            $exitCode = Invoke-WithSpinner -Activity "Installazione $Name" -Timer -Action $installAction -TimeoutSeconds 60
            
            if ($exitCode -eq 0) {
                Show-ProgressBar $Name "Completato" 100 $Icon
                Write-StyledMessage Success "$Name installato"
                return $true
            }
            else {
                Write-StyledMessage Warning "$Name installazione fallita o già presente"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore ${Name}: $($_.Exception.Message)"
            return $false
        }
    }

    function Update-ProfileVersion {
        <#
        .SYNOPSIS
            Gestisce l'aggiornamento del profilo PowerShell con controllo versione.
        #>
        try {
            $localVersion = Get-LocalVersion -ProfilePath $PROFILE
            $remoteVersion = Get-RemoteVersion -Url $script:PSPConfig.GitHubProfileUrl

            if ($null -eq $remoteVersion) {
                Write-StyledMessage Error "Impossibile recuperare versione remota"
                return $false
            }

            if ($null -ne $localVersion -and $localVersion -ge $remoteVersion) {
                Write-StyledMessage Success "Profilo già aggiornato (locale: $localVersion, remoto: $remoteVersion)"
                return $true
            }

            Write-StyledMessage Info "Nuova versione disponibile: $remoteVersion (locale: $($localVersion ?? 'non presente'))"

            # Backup profilo esistente
            if (Test-Path $PROFILE) {
                $backupPath = "$PROFILE.bak"
                Write-StyledMessage Info "Backup profilo esistente..."
                Copy-Item -Path $PROFILE -Destination $backupPath -Force
                Write-StyledMessage Success "Backup salvato: $backupPath"
            }

            # Download nuovo profilo
            Write-StyledMessage Info "Download profilo PowerShell..."
            Invoke-RestMethod -Uri $script:PSPConfig.GitHubProfileUrl -OutFile $PROFILE -ErrorAction Stop
            Write-StyledMessage Success "Profilo PowerShell aggiornato"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore aggiornamento profilo: $($_.Exception.Message)"
            return $false
        }
    }

    function Configure-WindowsTerminal {
        <#
        .SYNOPSIS
            Configura Windows Terminal scaricando settings.json.
        #>
        try {
            $wtPath = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Directory -Filter "Microsoft.WindowsTerminal_*" -ErrorAction SilentlyContinue | Select-Object -First 1
            
            if (-not $wtPath) {
                Write-StyledMessage Warning "Directory Windows Terminal non trovata"
                return $false
            }

            $wtLocalStateDir = Join-Path $wtPath.FullName "LocalState"
            if (-not (Test-Path $wtLocalStateDir)) {
                New-Item -ItemType Directory -Path $wtLocalStateDir -Force | Out-Null
            }

            $settingsPath = Join-Path $wtLocalStateDir "settings.json"

            Invoke-WithSpinner -Activity "Download settings.json Windows Terminal" -Timer -Action {
                Invoke-WebRequest -Uri $script:PSPConfig.GitHubSettingsUrl -OutFile $settingsPath -UseBasicParsing
            } -TimeoutSeconds 10

            Write-StyledMessage Success "settings.json configurato"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore configurazione Windows Terminal: $($_.Exception.Message)"
            return $false
        }
    }

    # ============================================================================
    # 4. ESECUZIONE PRINCIPALE
    # ============================================================================

    try {
        # Controllo privilegi amministratore
        if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-StyledMessage Error "Privilegi amministratore richiesti"
            Write-StyledMessage Info "Riavvia PowerShell come Amministratore"
            Read-Host "Premi INVIO per uscire"
            return
        }

        # Controllo versione PowerShell
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-StyledMessage Warning "Rilevato PowerShell $($PSVersionTable.PSVersion.Major). Consigliato PowerShell 7+"
            $choice = Read-Host "Procedere comunque? (S/N)"
            if ($choice -notmatch '^[SsYy]') {
                Write-StyledMessage Info "Installazione annullata"
                return
            }
        }
        else {
            Write-StyledMessage Success "PowerShell $($PSVersionTable.PSVersion) rilevato"
        }

        Write-StyledMessage Info "🚀 Inizializzazione sistema..."
        Start-Sleep -Seconds 1

        # Installazione pacchetti WinGet
        Write-Host ""
        $packages = @(
            @{ Name = "Oh My Posh"; Id = "JanDeDobbeleer.OhMyPosh"; Icon = "📦" },
            @{ Name = "zoxide"; Id = "ajeetdsouza.zoxide"; Icon = "🦎" },
            @{ Name = "btop"; Id = "btop.btop"; Icon = "📊" },
            @{ Name = "fastfetch"; Id = "Lissy93.fastfetch"; Icon = "⚡" }
        )

        foreach ($package in $packages) {
            Install-WinGetPackage -Name $package.Name -Id $package.Id -Icon $package.Icon
        }

        # Installazione Nerd Fonts
        Write-Host ""
        Write-StyledMessage Info "🔤 Installazione Nerd Fonts..."
        Install-NerdFont

        # Installazione tema Oh My Posh
        Write-Host ""
        Write-StyledMessage Info "🎨 Configurazione tema Oh My Posh..."
        Install-OhMyPoshTheme

        # Aggiornamento profilo PowerShell
        Write-Host ""
        Write-StyledMessage Info "📝 Aggiornamento profilo PowerShell..."
        Update-ProfileVersion

        # Configurazione Windows Terminal
        Write-Host ""
        Write-StyledMessage Info "🖥️ Configurazione Windows Terminal..."
        Configure-WindowsTerminal

        # ============================================================================
        # 5. RIEPILOGO E CHIUSURA
        # ============================================================================

        Write-Host ""
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-StyledMessage Success "✅ PSP Setup completato!"
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-Host ""

        Write-StyledMessage Warning "Riavvio richiesto per:"
        Write-Host "  • PATH oh-my-posh, zoxide, btop, fastfetch" -ForegroundColor Cyan
        Write-Host "  • Font installati" -ForegroundColor Cyan
        Write-Host "  • Attivazione profilo" -ForegroundColor Cyan
        Write-Host "  • Variabili d'ambiente" -ForegroundColor Cyan
        Write-Host ""

        $shouldReboot = Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio sistema"

        if ($shouldReboot) {
            Write-StyledMessage Info "Riavvio in corso..."
            Restart-Computer -Force
        }
        else {
            Write-Host ""
            Write-Host ('═' * 80) -ForegroundColor Yellow
            Write-StyledMessage Warning "⚠️ RIAVVIO POSTICIPATO"
            Write-Host ('═' * 80) -ForegroundColor Yellow
            Write-Host ""
            Write-StyledMessage Error "Il profilo NON funzionerà finché non riavvii!"
            Write-Host ""
            Write-StyledMessage Info "Dopo il riavvio, verifica con:"
            Write-Host "  oh-my-posh --version" -ForegroundColor Cyan
            Write-Host "  zoxide --version" -ForegroundColor Cyan
            Write-Host "  btop --version" -ForegroundColor Cyan
            Write-Host "  fastfetch --version" -ForegroundColor Cyan
            Write-Host ""

            # Salva stato riavvio necessario
            $rebootFlag = "$env:LOCALAPPDATA\WinToolkit\reboot_required.txt"
            "Riavvio necessario per applicare PATH e profilo PowerShell. Eseguito il $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $rebootFlag -Encoding UTF8
            Write-StyledMessage Info "Flag riavvio salvato in: $rebootFlag"
        }
    }
    catch {
        Write-StyledMessage Error "Errore critico: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Controlla i log per dettagli tecnici"
    }
    finally {
        # ============================================================================
        # 6. PULIZIA FINALE
        # ============================================================================

        Write-StyledMessage Info "🧹 Pulizia file temporanei..."
        $tempFiles = @(
            "$env:TEMP\Microsoft.PowerShell_profile.ps1",
            "$env:TEMP\JetBrainsMono.zip",
            "$env:TEMP\JetBrainsMono"
        )

        foreach ($tempFile in $tempFiles) {
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        Write-Host ""
        Write-StyledMessage Success "🎯 PSP Setup Toolkit terminato"
    }
}
