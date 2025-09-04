
Clear-Host
Write-Host (Center-Text 'Windows Update Reset Tool v1.1' $width) -ForegroundColor Cyan
Write-Host (Center-Text 'By MagnetarMan' $width) -ForegroundColor DarkGray
Write-Host ''
Write-Host ''

Write-StyledMessage Info 'Esecuzione di WinUpdateReset.ps1...'
Start-Sleep -Seconds 5


Write-StyledMessage Info 'Avvio riparazione servizi Windows Update...'

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
    # Reset services to their default startup type
    Write-StyledMessage Info 'Ripristino tipo di avvio dei servizi...'
    foreach ($service in $criticalServices) {
    Write-StyledMessage Info "Elaborazione servizio: $service"
        try {
            # Set service to Automatic start
            Set-Service -Name $service -StartupType Automatic -ErrorAction Stop
            Start-Service -Name $service -ErrorAction Stop
            Write-StyledMessage Success "Servizio $service configurato correttamente."
        }
        catch {
            Write-StyledMessage Warning "Impossibile configurare $service - $($_.Exception.Message)"
        }
    }

    # Fix registry entries that MicroWin might have modified
    Write-StyledMessage Info 'Ripristino chiavi di registro...'
    $registryPaths = @(
        "HKLM:\SYSTEM\CurrentControlSet\Services",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    )

    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            Write-StyledMessage Info "Elaborazione registro: $path"
            if ($path -like "*CurrentControlSet\Services") {
                # Reset Windows Update service specific registry values
                Set-ItemProperty -Path "$path\wuauserv" -Name "Start" -Value 2 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty -Path "$path\bits" -Name "Start" -Value 2 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty -Path "$path\TrustedInstaller" -Name "Start" -Value 3 -Type DWord -ErrorAction SilentlyContinue
            }
        }
    }

    # Reset Windows Update components
    Write-StyledMessage Info 'Ripristino componenti Windows Update...'
    $commands = @(
        "net stop wuauserv",
        "net stop cryptSvc",
        "net stop bits",
        "net stop msiserver",
        "ren C:\Windows\SoftwareDistribution SoftwareDistribution.old",
        "ren C:\Windows\System32\catroot2 catroot2.old",
        "del /s /q C:\Windows\SoftwareDistribution.old\Download\*",
        "net start wuauserv",
        "net start cryptSvc",
        "net start bits",
        "net start msiserver"
    )

    foreach ($cmd in $commands) {
    Write-StyledMessage Info "Esecuzione: $cmd"
        Start-Process "cmd.exe" -ArgumentList "/c $cmd" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
    }

    # Run DISM and SFC
    Write-StyledMessage Info 'Avvio controllo integrità sistema (DISM/SFC)...'
    Start-Process "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -NoNewWindow
    Start-Process "sfc.exe" -ArgumentList "/scannow" -Wait -NoNewWindow

    Write-StyledMessage Success 'Riparazione completata con successo.'
    Write-StyledMessage Success 'Operazione completata. Riavvia il computer per applicare le modifiche.'
    Write-StyledMessage Warning 'Vuoi riavviare ora il computer? (y/n)'
    $restart = Read-Host 'Risposta'
    if ($restart -eq 'y') {
        Write-StyledMessage Info 'Riavvio in corso...'
        Restart-Computer -Force
    }
}
catch {
    Write-StyledMessage Error "Errore: $($_.Exception.Message)"
    Write-StyledMessage Error 'Si è verificato un errore durante la riparazione. Controlla i messaggi sopra.'
}


Ferma il servizio di Windows Update:

powershell
net stop wuauserv
Ferma il servizio di trasferimento intelligente in background (BITS):

powershell
net stop bits
Pulisci la cartella Download di SoftwareDistribution (elimini i file temporanei degli update):

powershell
Remove-Item -Path C:\Windows\SoftwareDistribution.old\Download\* -Recurse -Force