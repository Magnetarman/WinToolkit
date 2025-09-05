Clear-Host
# --- Schermata di Benvenuto ---
$width = 60
$asciiArt = @(
    '      __        __  _  _   _ '
    '      \ \      / / | || \ | |'
    '       \ \ /\ / /  | ||  \| |'
    '        \ V  V /   | || |\  |'
    '         \_/\_/    |_||_| \_|'
    ''
    '  Update Reset Toolkit By MagnetarMan'
    '       Version 2.0 (Build 8)'
)
foreach ($line in $asciiArt) {
    Write-StyledMessage -Type 'Info' -Text (Center-Text -Text $line -Width $width)
}
Write-Host '' # Spazio

Write-StyledMessage -Type 'Info' -Text 'Esecuzione dello Script di Reset Windows Update...'
Start-Sleep -Seconds 5

Write-StyledMessage -Type 'Info' -Text 'Avvio riparazione servizi Windows Update...'

# Critical services that need to be running for Windows Update
$criticalServices = @(
    'wuauserv',          # Windows Update
    'bits',              # Background Intelligent Transfer
    'cryptsvc',          # Cryptographic Services
    'trustedinstaller',  # Windows Modules Installer
    'appidsvc',          # Application Identity
    'gpsvc',            # Group Policy Client
    'DcomLaunch',       # DCOM Server Process Launcher
    'RpcSs',            # Remote Procedure Call
    'LanmanServer',     # Server
    'LanmanWorkstation', # Workstation
    'EventLog',         # Windows Event Log
    'mpssvc',           # Windows Defender Firewall
    'WinDefend'         # Windows Defender Service
)

try {
    # Stop services before modification
    Write-StyledMessage -Type 'Info' -Text 'Arresto servizi Windows Update...'
    $servicesToStop = @('wuauserv', 'cryptsvc', 'bits', 'msiserver')
    foreach ($service in $servicesToStop) {
        try {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Info' -Text "Servizio $service arrestato."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile arrestare $service - $($_.Exception.Message)"
        }
    }

    # Reset services to their default startup type
    Write-StyledMessage -Type 'Info' -Text 'Ripristino tipo di avvio dei servizi...'
    foreach ($service in $criticalServices) {
        Write-StyledMessage -Type 'Info' -Text "Elaborazione servizio: $service"
        try {
            # Check if service exists
            $serviceObject = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($serviceObject) {
                # Set appropriate startup type based on service
                $startupType = switch ($service) {
                    'trustedinstaller' { 'Manual' }
                    'appidsvc' { 'Manual' }
                    default { 'Automatic' }
                }
                
                Set-Service -Name $service -StartupType $startupType -ErrorAction Stop
                Write-StyledMessage -Type 'Success' -Text "Servizio $service configurato come $startupType."
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "Servizio $service non trovato nel sistema."
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile configurare $service - $($_.Exception.Message)"
        }
    }

    # Fix registry entries
    Write-StyledMessage -Type 'Info' -Text 'Ripristino chiavi di registro...'
    $registryPaths = @(
        "HKLM:\SYSTEM\CurrentControlSet\Services",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    )

    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            Write-StyledMessage -Type 'Info' -Text "Elaborazione registro: $path"
            try {
                if ($path -like "*CurrentControlSet\Services") {
                    # Reset Windows Update service specific registry values
                    $serviceRegPaths = @(
                        @{ Path = "$path\wuauserv"; Value = 2 }        # Automatic
                        @{ Path = "$path\bits"; Value = 2 }           # Automatic  
                        @{ Path = "$path\TrustedInstaller"; Value = 3 } # Manual
                    )
                    
                    foreach ($regPath in $serviceRegPaths) {
                        if (Test-Path $regPath.Path) {
                            Set-ItemProperty -Path $regPath.Path -Name "Start" -Value $regPath.Value -Type DWord -ErrorAction Stop
                            Write-StyledMessage -Type 'Success' -Text "Registro aggiornato: $($regPath.Path)"
                        }
                    }
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore nella modifica del registro $path - $($_.Exception.Message)"
            }
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text "Percorso registro non trovato: $path"
        }
    }

    # Reset Windows Update components
    Write-StyledMessage -Type 'Info' -Text 'Ripristino componenti Windows Update...'
    
    # Create backup directories if they don't exist and remove old ones
    try {
        if (Test-Path "C:\Windows\SoftwareDistribution.old") {
            Remove-Item "C:\Windows\SoftwareDistribution.old" -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path "C:\Windows\System32\catroot2.old") {
            Remove-Item "C:\Windows\System32\catroot2.old" -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Rename current directories
        if (Test-Path "C:\Windows\SoftwareDistribution") {
            Rename-Item "C:\Windows\SoftwareDistribution" "SoftwareDistribution.old" -ErrorAction Stop
            Write-StyledMessage -Type 'Success' -Text "Directory SoftwareDistribution rinominata."
        }
        if (Test-Path "C:\Windows\System32\catroot2") {
            Rename-Item "C:\Windows\System32\catroot2" "catroot2.old" -ErrorAction Stop
            Write-StyledMessage -Type 'Success' -Text "Directory catroot2 rinominata."
        }
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text "Errore durante il backup delle directory - $($_.Exception.Message)"
    }

    # Start essential services
    Write-StyledMessage -Type 'Info' -Text 'Avvio servizi essenziali...'
    $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
    foreach ($service in $essentialServices) {
        try {
            Start-Service -Name $service -ErrorAction Stop
            Write-StyledMessage -Type 'Success' -Text "Servizio $service avviato."
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile avviare $service - $($_.Exception.Message)"
        }
    }

    # Reset Windows Update client
    Write-StyledMessage -Type 'Info' -Text 'Reset del client Windows Update...'
    try {
        Start-Process "cmd.exe" -ArgumentList "/c wuauclt /resetauthorization /detectnow" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        Write-StyledMessage -Type 'Success' -Text "Client Windows Update reimpostato."
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text "Errore durante il reset del client Windows Update."
    }

    Write-StyledMessage -Type 'Success' -Text 'Riparazione completata con successo.'
    Write-StyledMessage -Type 'Success' -Text 'Il sistema necessita di un riavvio per applicare tutte le modifiche.'
    Write-StyledMessage -Type 'Warning' -Text "Attenzione: il sistema verrà riavviato per rendere effettive le modifiche"
    Write-StyledMessage -Type 'Info' -Text "Preparazione al riavvio del sistema..."
    
    for ($i = 10; $i -gt 0; $i--) {
        Write-Host "Preparazione sistema al riavvio - $i secondi..." -NoNewline -ForegroundColor Yellow
        Write-Host "`r" -NoNewline
        Start-Sleep 1
    }
    Write-Host "" # Nuova riga dopo il countdown
    
    Write-StyledMessage -Type 'Info' -Text "Riavvio in corso..."
    try { Stop-Transcript | Out-Null } catch {}
    Restart-Computer -Force
}
catch {
    Write-StyledMessage -Type 'Error' -Text "Errore critico: $($_.Exception.Message)"
    Write-StyledMessage -Type 'Error' -Text 'Si è verificato un errore durante la riparazione. Controlla i messaggi sopra.'
    Write-StyledMessage -Type 'Info' -Text 'Premere un tasto per uscire...'
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}