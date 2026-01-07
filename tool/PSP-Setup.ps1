
# Funzione per l'installazione dei Nerd Fonts
function Install-NerdFonts {
    try {
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
        $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
        $fontDisplayName = "JetBrainsMono Nerd Font Mono"

        if ($fontFamilies -notcontains $fontDisplayName) {
            # Ottieni l'URL dell'ultima release tramite API GitHub
            $apiUrl = "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
            $releaseInfo = Invoke-RestMethod -Uri $apiUrl
            $fontZipUrl = ($releaseInfo.assets | Where-Object { $_.name -eq "JetBrainsMono.zip" }).browser_download_url

            if (-not $fontZipUrl) {
                Write-Error "Impossibile trovare l'asset JetBrainsMono.zip nella release più recente"
                return
            }

            $zipFilePath = "$env:TEMP\JetBrainsMono.zip"
            $extractPath = "$env:TEMP\JetBrainsMono"

            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFileAsync((New-Object System.Uri($fontZipUrl)), $zipFilePath)

            while ($webClient.IsBusy) {
                Start-Sleep -Seconds 2
            }

            Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force
            $destination = (New-Object -ComObject Shell.Application).Namespace(0x14)
            Get-ChildItem -Path "$extractPath\JetBrainsMonoNerdFont-*\variable" -Filter "*.ttf" | ForEach-Object {
                If (-not(Test-Path "C:\Windows\Fonts\$($_.Name)")) {
                    $destination.CopyHere($_.FullName, 0x10)
                }
            }

            Remove-Item -Path $extractPath -Recurse -Force
            Remove-Item -Path $zipFilePath -Force
        }
        else {
            Write-Host "Font $fontDisplayName già installato"
        }
    }
    catch {
        Write-Error "Impossibile scaricare o installare il font $fontDisplayName. Errore: $_"
    }
}

# Funzione helper per la compatibilità tra edizioni di PowerShell
function Get-ProfileDir {
    if ($PSVersionTable.PSEdition -eq "Core") {
        return "$env:userprofile\Documents\PowerShell"
    }
    elseif ($PSVersionTable.PSEdition -eq "Desktop") {
        return "$env:userprofile\Documents\WindowsPowerShell"
    }
    else {
        Write-Error "Edizione PowerShell non supportata: $($PSVersionTable.PSEdition)"
        break
    }
}

# Creazione o aggiornamento del profilo PowerShell
if (!(Test-Path -Path $PROFILE -PathType Leaf)) {
    try {
        $profilePath = Get-ProfileDir
        if (!(Test-Path -Path $profilePath)) {
            New-Item -Path $profilePath -ItemType "directory" -Force
        }
        Invoke-RestMethod https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Microsoft.PowerShell_profile.ps1 -OutFile $PROFILE
        Write-Host "Il profilo PowerShell è stato creato in [$PROFILE]."

    }
    catch {
        Write-Error "Impossibile creare o aggiornare il profilo. Errore: $_"
    }
}
else {
    try {
        $backupPath = Join-Path (Split-Path $PROFILE) "oldprofile.ps1"
        Move-Item -Path $PROFILE -Destination $backupPath -Force
        Invoke-RestMethod https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Microsoft.PowerShell_profile.ps1 -OutFile $PROFILE
        Write-Host "✅ Il profilo PowerShell in [$PROFILE] è stato aggiornato."
        Write-Host "📦 Il vecchio profilo è stato salvato in [$backupPath]"

    }
    catch {
        Write-Error "❌ Impossibile salvare e aggiornare il profilo. Errore: $_"
    }
}

# Funzione per scaricare il tema Oh My Posh localmente
function Install-OhMyPoshTheme {
    param (
        [string]$ThemeName = "atomic",
        [string]$ThemeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/atomic.omp.json"
    )
    $profilePath = Get-ProfileDir
    if (!(Test-Path -Path $profilePath)) {
        New-Item -Path $profilePath -ItemType "directory"
    }
    $themeFilePath = Join-Path $profilePath "$ThemeName.omp.json"
    try {
        Invoke-RestMethod -Uri $ThemeUrl -OutFile $themeFilePath
        Write-Host "Il tema Oh My Posh '$ThemeName' è stato scaricato in [$themeFilePath]"
        return $themeFilePath
    }
    catch {
        Write-Error "Impossibile scaricare il tema Oh My Posh. Errore: $_"
        return $null
    }
}

# Installazione Oh My Posh
try {
    winget install -e --accept-source-agreements --accept-package-agreements JanDeDobbeleer.OhMyPosh
}
catch {
    Write-Error "Impossibile installare Oh My Posh. Errore: $_"
}

# Download del tema Oh My Posh
$themeInstalled = Install-OhMyPoshTheme -ThemeName "atomic"

# Installazione Font
Install-NerdFonts

# Installazione zoxide
try {
    winget install -e --id ajeetdsouza.zoxide
    Write-Host "zoxide installato con successo."
}
catch {
    Write-Error "Impossibile installare zoxide. Errore: $_"
}

# Installazione btop
try {
    winget install -e --id btop.btop
    Write-Host "btop installato con successo."
}
catch {
    Write-Error "Impossibile installare btop. Errore: $_"
}

# Installazione fastfetch
try {
    winget install -e --id Lissy93.fastfetch
    Write-Host "Fastfetch installato con successo."
}
catch {
    Write-Error "Impossibile installare Fastfetch. Errore: $_"
}

# Verifica finale e messaggio all'utente
if ((Test-Path -Path $PROFILE) -and (winget list --name "OhMyPosh" -e) -and ($fontFamilies -contains "JetBrainsMono Nerd Font Mono") -and $themeInstalled) {
    Write-Host "Setup completato con successo. Riavviare la sessione di PowerShell per applicare le modifiche."
}
else {
    Write-Warning "Setup completato con errori. Controllare i messaggi di errore sopra."
}
