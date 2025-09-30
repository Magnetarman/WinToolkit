<#
.SYNOPSIS
    Script di Start per Win Toolkit V2.
.DESCRIPTION
    Questo script funge da punto di ingresso per l'installazione e la configurazione di Win Toolkit V2.0.
    Verifica la presenza di Git e PowerShell 7, installandoli se necessario, e configura Windows Terminal.
    Crea inoltre una scorciatoia sul desktop per avviare Win Toolkit con privilegi amministrativi.
.NOTES
  Versione 2.2.2 (Build 4) - 2025-09-30
#>

function Center-text {
    param(
        [string]$text,
        [int]$width = 80
    )
    $padding = [math]::Max(0, [math]::Floor(($width - $text.Length) / 2))
    return (" " * $padding) + $text
}


# Impostazione titolo finestra della console
$Host.UI.RawUI.WindowTitle = "Win Toolkit Starter by MagnetarMan"

# Funzione per mostrare messaggi stilizzati
function Write-StyledMessage {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$type,

        [Parameter(Mandatory = $true)]
        [string]$text
    )

    switch ($type) {
        'Info' { Write-Host $text -ForegroundColor Cyan }
        'Warning' { Write-Host $text -ForegroundColor Yellow }
        'Error' { Write-Host $text -ForegroundColor Red }
        'Success' { Write-Host $text -ForegroundColor Green }
    }
}

# Funzione helper per installazione tramite winget
function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$Name
    )
    try {
        winget install $PackageId --accept-source-agreements --accept-package-agreements --silent 2>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        Write-StyledMessage -type 'Warning' -text "Errore con winget per $Name. Tentativo alternativo..."
        return $false
    }
}

# Funzione per installare Git
function Install-Git {
    Write-StyledMessage -type 'Info' -text "Verifica Git..."

    if (Get-Command "git" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -type 'Success' -text "Git già presente."
        return $true
    }

    # Metodo 1: winget
    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -type 'Info' -text "Installazione Git tramite winget..."
        if (Install-WingetPackage -PackageId "Git.Git" -Name "Git") {
            Write-StyledMessage -type 'Success' -text "Git installato."
            return $true
        }
    }

    # Metodo 2: Download diretto
    try {
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.1/Git-2.51.0-64-bit.exe"
        $gitInstaller = "$env:TEMP\Git-2.51.0-64-bit.exe"

        Write-StyledMessage -type 'Info' -text "Download Git..."
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing

        Write-StyledMessage -type 'Info' -text "Installazione Git..."
        $process = Start-Process $gitInstaller -ArgumentList "/SILENT /NORESTART" -Wait -PassThru

        $success = $process.ExitCode -eq 0
        if ($success) {
            Write-StyledMessage -type 'Success' -text "Git installato."
            Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-StyledMessage -type 'Error' -text "Installazione Git fallita (codice: $($process.ExitCode))"
        }
        return $success
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore installazione Git: $($_.Exception.Message)"
        return $false
    }
}

# Funzione per installare PowerShell 7
function Install-PowerShell7 {
    Write-StyledMessage -type 'Info' -text "Verifica PowerShell 7..."

    if (Test-Path -Path "$env:ProgramFiles\PowerShell\7") {
        Write-StyledMessage -type 'Success' -text "PowerShell 7 già presente."
        return $true
    }

    # Metodo 1: winget
    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -type 'Info' -text "Installazione PowerShell 7 tramite winget..."
        if (Install-WingetPackage -PackageId "Microsoft.PowerShell" -Name "PowerShell 7") {
            Write-StyledMessage -type 'Success' -text "PowerShell 7 installato."
            return $true
        }
    }

    # Metodo 2: Download diretto
    try {
        $ps7Url = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/PowerShell-7.5.2-win-x64.msi"
        $ps7Installer = "$env:TEMP\PowerShell-7.5.2-win-x64.msi"

        Write-StyledMessage -type 'Info' -text "Download PowerShell 7..."
        Invoke-WebRequest -Uri $ps7Url -OutFile $ps7Installer -UseBasicParsing

        Write-StyledMessage -type 'Info' -text "Installazione PowerShell 7..."
        $installArgs = "/i `"$ps7Installer`" /quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1"
        $process = Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru

        $success = $process.ExitCode -eq 0
        if ($success) {
            Write-StyledMessage -type 'Success' -text "PowerShell 7 installato."
            Remove-Item $ps7Installer -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-StyledMessage -type 'Error' -text "Installazione PowerShell 7 fallita (codice: $($process.ExitCode))"
        }
        return $success
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore installazione PowerShell 7: $($_.Exception.Message)"
        return $false
    }
}

# Funzione per installare Windows Terminal
function Install-WindowsTerminal {
    Write-StyledMessage -type 'Info' -text "Verifica Windows Terminal..."

    if (Get-Command "wt" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -type 'Success' -text "Windows Terminal già presente."
        return $true
    }

    # Metodo 1: winget
    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -type 'Info' -text "Installazione Windows Terminal tramite winget..."
        if (Install-WingetPackage -PackageId "Microsoft.WindowsTerminal" -Name "Windows Terminal") {
            Write-StyledMessage -type 'Success' -text "Windows Terminal installato."
            return $true
        }
    }

    # Metodo 2: Microsoft Store
    try {
        Write-StyledMessage -type 'Info' -text "Apertura Microsoft Store per Windows Terminal..."
        Start-Process "wsreset.exe" -Wait
        Start-Process "ms-windows-store://pdp/?productid=9N0DX20HK701"
        Write-StyledMessage -type 'Info' -text "Store aperto. Installare manualmente se necessario."
        return $true
    }
    catch {
        Write-StyledMessage -type 'Warning' -text "Errore Store: $($_.Exception.Message). Download diretto..."
    }

    # Metodo 3: Download diretto
    try {
        $wtUrl = "https://github.com/microsoft/terminal/releases/download/v1.21.3231.0/Microsoft.WindowsTerminal_1.21.3231.0_x64.zip"
        $wtZip = "$env:TEMP\Microsoft.WindowsTerminal_1.21.3231.0_x64.zip"
        $wtExtractPath = "$env:TEMP\WindowsTerminal"

        Write-StyledMessage -type 'Info' -text "Download Windows Terminal..."
        Invoke-WebRequest -Uri $wtUrl -OutFile $wtZip -UseBasicParsing

        Write-StyledMessage -type 'Info' -text "Installazione Windows Terminal..."
        Expand-Archive -Path $wtZip -DestinationPath $wtExtractPath -Force

        $msixbundle = Get-ChildItem -Path $wtExtractPath -Name "*.msixbundle" | Select-Object -First 1
        if ($msixbundle) {
            $msixPath = Join-Path -Path $wtExtractPath -ChildPath $msixbundle
            Add-AppxPackage -Path $msixPath
            Write-StyledMessage -type 'Success' -text "Windows Terminal installato."

            # Pulizia
            Remove-Item $wtZip, $wtExtractPath -Recurse -Force -ErrorAction SilentlyContinue
            return $true
        }
        else {
            Write-StyledMessage -type 'Error' -text "File installazione non trovato."
            return $false
        }
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore installazione Windows Terminal: $($_.Exception.Message)"
        return $false
    }
}

# Funzione per configurare Windows Terminal
function Invoke-WPFTweakPS7 {
    param ([ValidateSet("PS7", "PS5")][string]$action = "PS7")

    $targetTerminalName = "PowerShell"
    Write-StyledMessage -type 'Info' -text "Configurazione Windows Terminal per $targetTerminalName..."

    if (-not (Get-Command "wt" -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -type 'Warning' -text "Windows Terminal non presente. Saltando configurazione."
        return
    }

    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path -Path $settingsPath)) {
        Write-StyledMessage -type 'Warning' -text "File impostazioni non trovato."
        return
    }

    try {
        $settingsContent = Get-Content -Path $settingsPath | ConvertFrom-Json
        $targetProfile = $settingsContent.profiles.list | Where-Object { $_.name -eq $targetTerminalName }

        if ($targetProfile) {
            $settingsContent.defaultProfile = $targetProfile.guid

            # Abilita modalità amministratore per PowerShell 7
            if ($action -eq "PS7") {
                $ps7Profile = $settingsContent.profiles.list | Where-Object { $_.name -eq "PowerShell" -and $_.commandline -like "*pwsh*" }
                if ($ps7Profile) {
                    $ps7Profile.elevate = $true
                    Write-StyledMessage -type 'Success' -text "Modalità amministratore abilitata per PowerShell 7"
                }
            }

            $settingsContent | ConvertTo-Json -Depth 100 | Set-Content -Path $settingsPath
            Write-StyledMessage -type 'Success' -text "Profilo predefinito aggiornato a $targetTerminalName"
        }
        else {
            Write-StyledMessage -type 'Warning' -text "Profilo $targetTerminalName non trovato."
        }
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore configurazione: $($_.Exception.Message)"
    }
}

# Funzione per impostare Windows Terminal come terminal predefinito
function Set-WindowsTerminalAsDefault {
    Write-StyledMessage -type 'Info' -text "Impostazione Windows Terminal come terminal predefinito..."

    try {
        # Percorso di Windows Terminal
        $wtPath = Get-Command "wt.exe" -ErrorAction SilentlyContinue
        if (-not $wtPath) {
            Write-StyledMessage -type 'Warning' -text "Windows Terminal non trovato nel PATH."
            return $false
        }

        $wtFullPath = $wtPath.Source
        Write-StyledMessage -type 'Info' -text "Windows Terminal trovato: $wtFullPath"

        # Imposta Windows Terminal come handler predefinito per console
        $regPaths = @(
            "HKCU:\Console\%%Startup",
            "HKCR:\Directory\shell\cmd",
            "HKCR:\Directory\Background\shell\cmd",
            "HKCR:\Drive\shell\cmd"
        )

        foreach ($regPath in $regPaths) {
            try {
                if (-not (Test-Path $regPath)) {
                    New-Item -Path $regPath -Force | Out-Null
                }

                # Crea la chiave command se non esiste
                $commandPath = Join-Path -Path $regPath -ChildPath "command"
                if (-not (Test-Path $commandPath)) {
                    New-Item -Path $commandPath -Force | Out-Null
                }

                # Imposta il comando per avviare Windows Terminal
                Set-ItemProperty -Path $regPath -Name "(Default)" -Value "Apri in Windows Terminal" -Type String
                Set-ItemProperty -Path $commandPath -Name "(Default)" -Value "`"$wtFullPath`" %1" -Type ExpandString

                Write-StyledMessage -type 'Info' -text "Configurato: $regPath"
            }
            catch {
                Write-StyledMessage -type 'Warning' -text "Errore configurazione $regPath`: $($_.Exception.Message)"
            }
        }

        Write-StyledMessage -type 'Success' -text "Windows Terminal impostato come terminal predefinito"
        return $true
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore impostazione terminal predefinito: $($_.Exception.Message)"
        return $false
    }
}

# Funzione per creare la scorciatoia sul desktop
function ToolKit-Desktop {
    Write-StyledMessage -type 'Info' -text "Creazione scorciatoia desktop..."

    try {
        $desktopPath = [System.Environment]::GetFolderPath('Desktop')
        $shortcutPath = Join-Path -Path $desktopPath -ChildPath "Win Toolkit.lnk"
        $iconPath = Join-Path -Path $env:TEMP -ChildPath "WinToolkit.ico"

        # Verifica se wt.exe è disponibile nel PATH
        $wtPath = Get-Command "wt.exe" -ErrorAction SilentlyContinue
        if (-not $wtPath) {
            Write-StyledMessage -type 'Warning' -text "Windows Terminal non trovato nel PATH. Installazione necessaria."
            return $false
        }

        # Download icona se non presente
        if (-not (Test-Path -Path $iconPath)) {
            Write-StyledMessage -type 'Info' -text "Download icona..."
            try {
                $iconUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/img/WinToolkit.ico"
                Invoke-WebRequest -Uri $iconUrl -OutFile $iconPath -UseBasicParsing
            }
            catch {
                Write-StyledMessage -type 'Warning' -text "Download icona fallito. Utilizzo icona predefinita."
                $iconPath = ""
            }
        }

        # Crea scorciatoia
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)

        $Shortcut.TargetPath = 'wt.exe'
        $Shortcut.Arguments = 'pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://magnetarman.com/WinToolkit | iex"'
        $Shortcut.WorkingDirectory = "%USERPROFILE%"
        if ($iconPath -and (Test-Path $iconPath)) {
            $Shortcut.IconLocation = $iconPath
        }
        $Shortcut.Description = "Win Toolkit - SOPRAVVIVI A Windows"
        $Shortcut.Save()

        # Abilita esecuzione come amministratore
        $bytes = [System.IO.File]::ReadAllBytes($shortcutPath)
        $bytes[21] = $bytes[21] -bor 32
        [System.IO.File]::WriteAllBytes($shortcutPath, $bytes)

        Write-StyledMessage -type 'Success' -text "Scorciatoia creata con privilegi amministratore."
        return $true
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore creazione scorciatoia: $($_.Exception.Message)"
        return $false
    }
}

# Logica di esecuzione principale
function Start-WinToolkit {
    param(
        [switch]$InstallProfileOnly
    )

    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Output "Win Toolkit deve essere eseguito come amministratore. Tentativo di riavvio."
        $argList = @()
        $PSBoundParameters.GetEnumerator() | ForEach-Object {
            $argList += if ($_.Value -is [switch] -and $_.Value) {
                "-$($_.Key)"
            }
            elseif ($_.Value -is [array]) {
                "-$($_.Key) $($_.Value -join ',')"
            }
            elseif ($_.Value) {
                "-$($_.Key) '$($_.Value)'"
            }
        }
        $script = if ($PSCommandPath) {
            "& { & `'$($PSCommandPath)`' $($argList -join ' ') }"
        }
        else {
            "&([ScriptBlock]::Create((irm https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/start.ps1))) $($argList -join ' ')"
        }
        Start-Process "powershell" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
        return
    }

    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:localappdata\WinToolkit\logs"
    try {
        [System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
        Start-Transcript -Path "$logdir\WinToolkitStarter_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}

    Clear-Host
    $width = 65
    Write-Host ('═' * $width) -ForegroundColor Green
    $asciiArt = @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        '     Toolkit Starter By MagnetarMan',
        '        Version 2.2.2 (Build 4)'
    )
    foreach ($line in $asciiArt) {
        Write-Host (Center-text -text $line -width $width) -ForegroundColor White
    }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''
    
    Write-StyledMessage -type 'Info' -text "Versione PowerShell: $($PSVersionTable.PSVersion)"
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-StyledMessage -type 'Warning' -text "PowerShell 5 rilevato. PowerShell 7 raccomandato."
    }

    Write-StyledMessage -type 'Info' -text "Configurazione Win Toolkit..."
    $rebootNeeded = $false

    Install-Git

    if (-not (Test-Path "$env:ProgramFiles\PowerShell\7")) {
        if (Install-PowerShell7) { $rebootNeeded = $true }
    }
    else {
        Write-StyledMessage -type 'Success' -text "PowerShell 7 già presente."
    }

    Install-WindowsTerminal
    Invoke-WPFTweakPS7 -action "PS7"
    Set-WindowsTerminalAsDefault
    ToolKit-Desktop

    Write-StyledMessage -type 'Success' -text "Configurazione completata."

    if ($rebootNeeded) {
        Write-StyledMessage -type 'Warning' -text "Riavvio necessario per PowerShell 7"
        for ($i = 10; $i -gt 0; $i--) {
            Write-Host "Riavvio in $i secondi..." -NoNewline -ForegroundColor Yellow
            Write-Host "`r" -NoNewline
            Start-Sleep 1
        }
        try { Stop-Transcript | Out-Null } catch {}
        Restart-Computer -Force
    }
    else {
        Write-StyledMessage -type 'Info' -text "Riavvio non necessario."
        try { Stop-Transcript | Out-Null } catch {}
    }
}

# Avvia lo script principale
Start-WinToolkit