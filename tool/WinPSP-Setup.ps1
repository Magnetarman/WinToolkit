function WinPSP-Setup {
    <#
    .SYNOPSIS
        Script professionale per l'installazione e configurazione dell'ambiente PowerShell.

    .DESCRIPTION
        Installa e configura:
        - Oh My Posh, zoxide, btop, fastfetch tramite WinGet
        - Nerd Fonts (JetBrainsMono)
        - Tema Oh My Posh "atomic"
        - Profilo PowerShell personalizzato
        - Configurazione Windows Terminal
        
        Richiede PowerShell 7+ e privilegi amministratore.
    #>
    [CmdletBinding()]
    param()

    # ============================================================================
    # METADATA
    # ============================================================================
    
    $ScriptName = "WinPSP-Setup"
    $ScriptVersion = "1.0.0"
    $GitHubProfileUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Microsoft.PowerShell_profile.ps1"
    $GitHubSettingsUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/settings.json"

    # ============================================================================
    # INIZIALIZZAZIONE
    # ============================================================================

    Initialize-ToolLogging -ToolName $ScriptName
    Show-Header -SubTitle "WinPSP Setup v$ScriptVersion"

    # ============================================================================
    # HELPER FUNCTIONS
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

    function Find-ProgramPath {
        <#
        .SYNOPSIS
            Trova il percorso di un programma cercando in più percorsi.
        #>
        param(
            [string]$ProgramName,
            [string[]]$SearchPaths,
            [string]$ExecutableName
        )
        
        foreach ($path in $SearchPaths) {
            $resolvedPaths = @()
            try {
                $resolvedPaths = Get-ChildItem -Path (Split-Path $path -Parent) -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like (Split-Path $path -Leaf) }
            }
            catch { continue }

            foreach ($resolved in $resolvedPaths) {
                $testPath = $resolved.FullName
                if (Test-Path "$testPath\$ExecutableName") { return $testPath }
            }

            $directPath = $path -replace '\*.*', ''
            if (Test-Path "$directPath\$ExecutableName") { return $directPath }
        }
        return $null
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

    # ============================================================================
    # CHECK INIZIALI
    # ============================================================================

    # Controllo privilegi amministratore
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-StyledMessage Warning "Richiesti privilegi amministratore"
        Write-StyledMessage Info "Riavvio come amministratore..."

        try {
            $scriptPath = $MyInvocation.MyCommand.Definition
            Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { $scriptPath }`""
            return
        }
        catch {
            Write-StyledMessage Error "Impossibile elevare privilegi: $($_.Exception.Message)"
            return
        }
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

    # ============================================================================
    # INSTALLAZIONE CORE (WINGET)
    # ============================================================================

    $packages = @(
        @{ Name = "Oh My Posh"; Id = "JanDeDobbeleer.OhMyPosh"; Icon = "📦" },
        @{ Name = "zoxide"; Id = "ajeetdsouza.zoxide"; Icon = "🦎" },
        @{ Name = "btop"; Id = "btop.btop"; Icon = "📊" },
        @{ Name = "fastfetch"; Id = "Lissy93.fastfetch"; Icon = "⚡" }
    )

    Write-StyledMessage Info "Installazione pacchetti tramite WinGet..."
    
    foreach ($package in $packages) {
        try {
            Write-StyledMessage Info "Installazione $($package.Name)..."
            
            $installAction = {
                $process = Start-Process -FilePath "cmd" -ArgumentList "/c winget install -e --id $($package.Id) --accept-source-agreements --accept-package-agreements --silent" -NoNewWindow -PassThru -Wait
                return $process.ExitCode
            }
            
            $exitCode = Invoke-WithSpinner -Activity "Installazione $($package.Name)" -Timer -Action $installAction -TimeoutSeconds 60
            
            if ($exitCode -eq 0) {
                Show-ProgressBar $package.Name "Completato" 100 $package.Icon
                Write-StyledMessage Success "$($package.Name) installato"
            }
            else {
                Write-StyledMessage Warning "$($package.Name) installazione fallita o già presente"
            }
        }
        catch {
            Write-StyledMessage Error "Errore $($package.Name): $($_.Exception.Message)"
        }
    }

    # ============================================================================
    # RISORSE ESTETICHE
    # ============================================================================

    # Installazione Nerd Fonts
    Write-StyledMessage Info "Installazione Nerd Fonts..."
    
    try {
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
        $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
        $fontDisplayName = "JetBrainsMono Nerd Font Mono"

        if ($fontFamilies -notcontains $fontDisplayName) {
            Write-StyledMessage Info "Download JetBrainsMono Nerd Font..."

            $apiUrl = "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
            $releaseInfo = Invoke-RestMethod -Uri $apiUrl
            $fontZipUrl = ($releaseInfo.assets | Where-Object { $_.name -eq "JetBrainsMono.zip" }).browser_download_url

            if (-not $fontZipUrl) {
                Write-StyledMessage Error "Asset JetBrainsMono.zip non trovato"
            }
            else {
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
            }
        }
        else {
            Write-StyledMessage Info "JetBrainsMono Nerd Font già installato"
        }
    }
    catch {
        Write-StyledMessage Error "Errore installazione font: $($_.Exception.Message)"
    }

    # Installazione tema Oh My Posh
    Write-StyledMessage Info "Download tema Oh My Posh 'atomic'..."
    
    try {
        $profilePath = Get-ProfileDir
        if ($profilePath) {
            if (-not (Test-Path $profilePath)) {
                New-Item -Path $profilePath -ItemType Directory -Force | Out-Null
            }

            $themeFilePath = Join-Path $profilePath "atomic.omp.json"
            $themeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/atomic.omp.json"

            Invoke-RestMethod -Uri $themeUrl -OutFile $themeFilePath -ErrorAction Stop
            Write-StyledMessage Success "Tema 'atomic' installato"
        }
    }
    catch {
        Write-StyledMessage Error "Errore download tema: $($_.Exception.Message)"
    }

    # ============================================================================
    # LOGICA AVANZATA DEL PROFILO (VERSIONING)
    # ============================================================================

    Write-StyledMessage Info "Controllo versione profilo PowerShell..."

    $localVersion = Get-LocalVersion -ProfilePath $PROFILE
    $remoteVersion = Get-RemoteVersion -Url $GitHubProfileUrl

    if ($null -eq $remoteVersion) {
        Write-StyledMessage Error "Impossibile recuperare versione remota"
    }
    elseif ($null -ne $localVersion -and $localVersion -ge $remoteVersion) {
        Write-StyledMessage Success "Profilo già aggiornato (locale: $localVersion, remoto: $remoteVersion)"
    }
    else {
        Write-StyledMessage Info "Nuova versione disponibile: $remoteVersion (locale: $($localVersion ?? 'non presente'))"

        # Backup profilo esistente
        if (Test-Path $PROFILE) {
            $backupPath = "$PROFILE.bak"
            Write-StyledMessage Info "Backup profilo esistente..."
            Copy-Item -Path $PROFILE -Destination $backupPath -Force
            Write-StyledMessage Success "Backup salvato: $backupPath"
        }

        # Download nuovo profilo
        try {
            Write-StyledMessage Info "Download profilo PowerShell..."
            Invoke-RestMethod -Uri $GitHubProfileUrl -OutFile $PROFILE -ErrorAction Stop
            Write-StyledMessage Success "Profilo PowerShell aggiornato"
        }
        catch {
            Write-StyledMessage Error "Errore download profilo: $($_.Exception.Message)"
        }
    }

    # ============================================================================
    # CONFIGURAZIONE WINDOWS TERMINAL
    # ============================================================================

    Write-StyledMessage Info "Configurazione Windows Terminal..."

    try {
        $wtPath = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Directory -Filter "Microsoft.WindowsTerminal_*" -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if (-not $wtPath) {
            Write-StyledMessage Warning "Directory Windows Terminal non trovata"
        }
        else {
            $wtLocalStateDir = Join-Path $wtPath.FullName "LocalState"
            if (-not (Test-Path $wtLocalStateDir)) {
                New-Item -ItemType Directory -Path $wtLocalStateDir -Force | Out-Null
            }

            $settingsPath = Join-Path $wtLocalStateDir "settings.json"

            Invoke-WithSpinner -Activity "Download settings.json Windows Terminal" -Timer -Action {
                Invoke-WebRequest -Uri $GitHubSettingsUrl -OutFile $settingsPath -UseBasicParsing
            } -TimeoutSeconds 10

            Write-StyledMessage Success "settings.json configurato"
        }
    }
    catch {
        Write-StyledMessage Error "Errore configurazione Windows Terminal: $($_.Exception.Message)"
    }

    # ============================================================================
    # RIEPILOGO E CHIUSURA
    # ============================================================================

    Write-Host ""
    Write-Host ('═' * 80) -ForegroundColor Green
    Write-StyledMessage Success "Setup PSP completato!"
    Write-Host ('═' * 80) -ForegroundColor Green
    Write-Host ""

    Write-StyledMessage Warning "Riavvio richiesto per:"
    Write-Host "  • PATH oh-my-posh, zoxide, btop, fastfetch" -ForegroundColor Cyan
    Write-Host "  • Font installati" -ForegroundColor Cyan
    Write-Host "  • Attivazione profilo" -ForegroundColor Cyan
    Write-Host "  • Variabili d'ambiente" -ForegroundColor Cyan
    Write-Host ""

    $shouldReboot = Start-InterruptibleCountdown 30 "Riavvio sistema"

    if ($shouldReboot) {
        Write-StyledMessage Info "Riavvio in corso..."
        Restart-Computer -Force
    }
    else {
        Write-Host ""
        Write-Host ('═' * 80) -ForegroundColor Yellow
        Write-StyledMessage Warning "RIAVVIO POSTICIPATO"
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

    # ============================================================================
    # PULIZIA
    # ============================================================================

    $tempFiles = @(
        "$env:TEMP\Microsoft.PowerShell_profile.ps1",
        "$env:TEMP\JetBrainsMono.zip"
    )

    foreach ($tempFile in $tempFiles) {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}
