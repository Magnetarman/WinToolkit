
# Function to install Nerd Fonts
function Install-NerdFonts {
    param (
        [string]$FontName = "CascadiaCode",
        [string]$FontDisplayName = "CaskaydiaCove NF",
        [string]$Version = "3.2.1"
    )

    try {
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
        $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
        if ($fontFamilies -notcontains "${FontDisplayName}") {
            $fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v${Version}/${FontName}.zip"
            $zipFilePath = "$env:TEMP\${FontName}.zip"
            $extractPath = "$env:TEMP\${FontName}"

            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFileAsync((New-Object System.Uri($fontZipUrl)), $zipFilePath)

            while ($webClient.IsBusy) {
                Start-Sleep -Seconds 2
            }

            Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force
            $destination = (New-Object -ComObject Shell.Application).Namespace(0x14)
            Get-ChildItem -Path $extractPath -Recurse -Filter "*.ttf" | ForEach-Object {
                If (-not(Test-Path "C:\Windows\Fonts\$($_.Name)")) {
                    $destination.CopyHere($_.FullName, 0x10)
                }
            }

            Remove-Item -Path $extractPath -Recurse -Force
            Remove-Item -Path $zipFilePath -Force
        }
        else {
            Write-Host "Font ${FontDisplayName} already installed"
        }
    }
    catch {
        Write-Error "Failed to download or install ${FontDisplayName} font. Error: $_"
    }
}

# Helper function for cross-edition compatibility
function Get-ProfileDir {
    if ($PSVersionTable.PSEdition -eq "Core") {
        return "$env:userprofile\Documents\PowerShell"
    }
    elseif ($PSVersionTable.PSEdition -eq "Desktop") {
        return "$env:userprofile\Documents\WindowsPowerShell"
    }
    else {
        Write-Error "Unsupported PowerShell edition: $($PSVersionTable.PSEdition)"
        break
    }
}


# Profile creation or update
if (!(Test-Path -Path $PROFILE -PathType Leaf)) {
    try {
        $profilePath = Get-ProfileDir
        if (!(Test-Path -Path $profilePath)) {
            New-Item -Path $profilePath -ItemType "directory" -Force
        }
        Invoke-RestMethod https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Microsoft.PowerShell_profile.ps1 -OutFile $PROFILE
        Write-Host "The profile @ [$PROFILE] has been created."

    }
    catch {
        Write-Error "Failed to create or update the profile. Error: $_"
    }
}
else {
    try {
        $backupPath = Join-Path (Split-Path $PROFILE) "oldprofile.ps1"
        Move-Item -Path $PROFILE -Destination $backupPath -Force
        Invoke-RestMethod https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Microsoft.PowerShell_profile.ps1 -OutFile $PROFILE
        Write-Host "✅ PowerShell profile at [$PROFILE] has been updated."
        Write-Host "📦 Your old profile has been backed up to [$backupPath]"

    }
    catch {
        Write-Error "❌ Failed to backup and update the profile. Error: $_"
    }
}

# Function to download Oh My Posh theme locally
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
        Write-Host "Oh My Posh theme '$ThemeName' has been downloaded to [$themeFilePath]"
        return $themeFilePath
    }
    catch {
        Write-Error "Failed to download Oh My Posh theme. Error: $_"
        return $null
    }
}

# OMP Install
try {
    winget install -e --accept-source-agreements --accept-package-agreements JanDeDobbeleer.OhMyPosh
}
catch {
    Write-Error "Failed to install Oh My Posh. Error: $_"
}

# Download Oh My Posh theme locally
$themeInstalled = Install-OhMyPoshTheme -ThemeName "atomic"

# Font Install
Install-NerdFonts -FontName "CascadiaCode" -FontDisplayName "CaskaydiaCove NF"

# Final check and message to the user
if ((Test-Path -Path $PROFILE) -and (winget list --name "OhMyPosh" -e) -and ($fontFamilies -contains "CaskaydiaCove NF") -and $themeInstalled) {
    Write-Host "Setup completed successfully. Please restart your PowerShell session to apply changes."
}
else {
    Write-Warning "Setup completed with errors. Please check the error messages above."
}



# zoxide Install
try {
    winget install -e --id ajeetdsouza.zoxide
    Write-Host "zoxide installed successfully."
}
catch {
    Write-Error "Failed to install zoxide. Error: $_"
}