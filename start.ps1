# Win Toolkit Starter by MagnetarMan
# Versione 1.5 (Build 20) - 2025-09-04
# Impostazione titolo finestra della console
$Host.UI.RawUI.WindowTitle = "Win Toolkit Starter V1.6 by MagnetarMan"

# Funzione per mostrare messaggi stilizzati
function Write-StyledMessage {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Type,
        
        [Parameter(Mandatory=$true)]
        [string]$Text
    )
    
    switch ($Type) {
        'Info'    { Write-Host $Text -ForegroundColor Cyan }
        'Warning' { Write-Host $Text -ForegroundColor Yellow }
        'Error'   { Write-Host $Text -ForegroundColor Red }
        'Success' { Write-Host $Text -ForegroundColor Green }
    }
}

# Funzione per installare Git
function Install-Git {
    Write-StyledMessage -Type 'Info' -Text "Verifica installazione di Git..."

    if (Get-Command "git" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type 'Success' -Text "Git è già installato. Saltando l'installazione."
        return $true
    }

    Write-StyledMessage -Type 'Info' -Text "Git non trovato. Tentativo di installazione..."

    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type 'Info' -Text "Installazione di Git tramite winget..."
        try {
            winget install Git.Git --accept-source-agreements --accept-package-agreements --silent
            return $LASTEXITCODE -eq 0
        } catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore con winget: $($_.Exception.Message). Tentativo di installazione diretta..."
        }
    } else {
        Write-StyledMessage -Type 'Warning' -Text "winget non disponibile. Procedendo con installazione diretta..."
    }

    try {
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.1/Git-2.51.0-64-bit.exe"
        $gitInstaller = "$env:TEMP\Git-2.51.0-64-bit.exe"
        Write-StyledMessage -Type 'Info' -Text "Download di Git da GitHub..."
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing
        
        Write-StyledMessage -Type 'Info' -Text "Installazione di Git in corso..."
        $installArgs = "/SILENT /NORESTART"
        $process = Start-Process $gitInstaller -ArgumentList $installArgs -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text "Git installato con successo."
            Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
            return $true
        } else {
            Write-StyledMessage -Type 'Error' -Text "Installazione di Git fallita. Codice di uscita: $($process.ExitCode)"
            return $false
        }
    } catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante l'installazione diretta di Git: $($_.Exception.Message)"
        return $false
    }
}

# Funzione per installare PowerShell 7
function Install-PowerShell7 {
    Write-StyledMessage -Type 'Info' -Text "Tentativo installazione PowerShell 7..."
    
    if (Test-Path -Path "$env:ProgramFiles\PowerShell\7") {
        Write-StyledMessage -Type 'Success' -Text "PowerShell 7 è già installato. Saltando l'installazione."
        return $true
    }

    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type 'Info' -Text "Installazione PowerShell 7 tramite winget..."
        try {
            winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent
            if ($LASTEXITCODE -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "PowerShell 7 installato con successo tramite winget."
                return $true
            }
        } catch {}
    }

    try {
        $ps7Url = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/PowerShell-7.5.2-win-x64.msi"
        $ps7Installer = "$env:TEMP\PowerShell-7.5.2-win-x64.msi"
        Write-StyledMessage -Type 'Info' -Text "Download PowerShell 7 da GitHub..."
        Invoke-WebRequest -Uri $ps7Url -OutFile $ps7Installer -UseBasicParsing
        
        Write-StyledMessage -Type 'Info' -Text "Installazione PowerShell 7 in corso..."
        $installArgs = "/i `"$ps7Installer`" /quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1"
        $process = Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text "PowerShell 7 installato con successo."
            Remove-Item $ps7Installer -Force -ErrorAction SilentlyContinue
            return $true
        } else {
            Write-StyledMessage -Type 'Error' -Text "Installazione PowerShell 7 fallita. Codice di uscita: $($process.ExitCode)"
            return $false
        }
    } catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante l'installazione di PowerShell 7: $($_.Exception.Message)"
        return $false
    }
}

# Funzione per configurare Windows Terminal
function Invoke-WPFTweakPS7 {
    param ([ValidateSet("PS7", "PS5")][string]$action = "PS7")
    
    $targetTerminalName = "PowerShell" # Nome corretto per PowerShell 7 in Windows Terminal
    Write-StyledMessage -Type 'Info' -Text "Configurazione Windows Terminal per $targetTerminalName..."
    
    if (-not (Get-Command "wt" -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type 'Warning' -Text "Windows Terminal non installato. Saltando configurazione terminale."
        return
    }
    
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path -Path $settingsPath)) {
        Write-StyledMessage -Type 'Warning' -Text "File impostazioni Windows Terminal non trovato."
        return
    }

    try {
        $settingsContent = Get-Content -Path $settingsPath | ConvertFrom-Json
        $targetProfile = $settingsContent.profiles.list | Where-Object { $_.name -eq $targetTerminalName }
        
        if ($targetProfile) {
            $settingsContent.defaultProfile = $targetProfile.guid
            $updatedSettings = $settingsContent | ConvertTo-Json -Depth 100
            Set-Content -Path $settingsPath -Value $updatedSettings
            Write-StyledMessage -Type 'Success' -Text "Profilo predefinito Windows Terminal aggiornato a $targetTerminalName"
        } else {
            Write-StyledMessage -Type 'Warning' -Text "Profilo $targetTerminalName non trovato nelle impostazioni di Windows Terminal."
        }
    } catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante l'aggiornamento delle impostazioni Windows Terminal: $($_.Exception.Message)"
    }
}

# Funzione per creare la scorciatoia sul desktop
# Funzione per creare la scorciatoia sul desktop
function ToolKit-Desktop {
    Write-StyledMessage -Type 'Info' -Text "Creazione scorciatoia sul desktop..."
    
    try {
        # Determina il percorso del desktop dell'utente corrente
        $desktopPath = [System.Environment]::GetFolderPath('Desktop')
        $shortcutPath = Join-Path -Path $desktopPath -ChildPath "Win Toolkit.lnk"
        
        # Crea un oggetto WScript.Shell per la creazione della scorciatoia
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        
        # Imposta la destinazione del file eseguibile (TargetPath)
        $Shortcut.TargetPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
        
        # Imposta gli argomenti della riga di comando (Arguments)
        $Shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Magnetarman/WinToolkit/Dev/tool/WinBrain.ps1 | iex"'
        
        $Shortcut.Save()
        
        Write-StyledMessage -Type 'Success' -Text "Scorciatoia 'Win Toolkit.lnk' creata con successo sul desktop."
    } catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante la creazione della scorciatoia: $($_.Exception.Message)"
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
            } elseif ($_.Value -is [array]) {
                "-$($_.Key) $($_.Value -join ',')"
            } elseif ($_.Value) {
                "-$($_.Key) '$($_.Value)'"
            }
        }
        $script = if ($PSCommandPath) {
            "& { & `'$($PSCommandPath)`' $($argList -join ' ') }"
        } else {
            "&([ScriptBlock]::Create((irm https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/start.ps1))) $($argList -join ' ')"
        }
        Start-Process "powershell" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
        return
    }

    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:localappdata\WinToolkit\logs"
    try {
        [System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
        Start-Transcript -Path "$logdir\WinToolkit_$dateTime.log" -Append -Force | Out-Null
    } catch {}

    Clear-Host
    Write-Host ('Win Toolkit Starter').PadLeft(40) -ForegroundColor Green
    Write-Host ('By MagnetarMan').PadLeft(35) -ForegroundColor Red
    Write-Host ''
    
    Write-StyledMessage -Type 'Info' -Text "Versione PowerShell rilevata: $($PSVersionTable.PSVersion)"
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-StyledMessage -Type 'Warning' -Text "PowerShell 5 rilevato. PowerShell 7 è raccomandato per funzionalità avanzate."
    }

    Write-StyledMessage -Type 'Info' -Text "Avvio configurazione Win Toolkit..."

    $rebootNeeded = $false
    
    Install-Git
    
    $ps7Installed = (Test-Path -Path "$env:ProgramFiles\PowerShell\7")
    if (-not $ps7Installed) {
        $installSuccess = Install-PowerShell7
        if ($installSuccess) {
            $rebootNeeded = $true
        }
    } else {
        Write-StyledMessage -Type 'Success' -Text "PowerShell 7 già presente."
    }

    Invoke-WPFTweakPS7 -action "PS7"
    ToolKit-Desktop
    
    Write-StyledMessage -Type 'Success' -Text "Script di Start eseguito correttamente."
    
    if ($rebootNeeded) {
        Write-StyledMessage -Type 'Warning' -Text "Attenzione: il sistema verrà riavviato per rendere effettive le modifiche"
        Write-StyledMessage -Type 'Info' -Text "Preparazione al riavvio del sistema..."
        for ($i = 10; $i -gt 0; $i--) {
            Write-Host "Preparazione sistema al riavvio - $i secondi..." -NoNewline -ForegroundColor Yellow
            Write-Host "`r" -NoNewline
            Start-Sleep 1
        }
        Write-StyledMessage -Type 'Info' -Text "Riavvio in corso..."
        try { Stop-Transcript | Out-Null } catch {}
        Restart-Computer -Force
    } else {
        Write-StyledMessage -Type 'Info' -Text "Non è necessario riavviare il sistema in quanto PowerShell 7 era già installato."
        try { Stop-Transcript | Out-Null } catch {}
    }
}

# Avvia lo script principale
Start-WinToolkit