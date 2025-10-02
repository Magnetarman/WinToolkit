<#
.SYNOPSIS
    Script di Start per Win Toolkit.
.DESCRIPTION
    Questo script funge da punto di ingresso per l'installazione e la configurazione di Win Toolkit V2.0.
    Verifica la presenza di Git e PowerShell 7, installandoli se necessario, e configura Windows Terminal.
    Crea inoltre una scorciatoia sul desktop per avviare Win Toolkit con privilegi amministrativi.
.NOTES
  Versione 2.2.2 (Build 28) - 2025-10-03
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
$Host.UI.RawUI.WindowTitle = "Toolkit Starter by MagnetarMan"

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

# Funzione per verificare se Winget è disponibile e funzionante
function Test-WingetAvailable {
    try {
        $wingetTest = winget --version 2>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Funzione per reinstallare Winget silenziosamente
function Install-WingetSilent {
    Write-StyledMessage -type 'Info' -text "Verifica disponibilità Winget..."

    # Prima verifica se Winget è già disponibile e funzionante
    if (Test-WingetAvailable) {
        Write-StyledMessage -type 'Success' -text "Winget è già disponibile e funzionante."
        return $true
    }

    Write-StyledMessage -type 'Warning' -text "Winget non trovato o non funzionante. Tentativo di installazione/riparazione..."

    # Verifica compatibilità Windows per Winget
    $osInfo = [System.Environment]::OSVersion
    $buildNumber = $osInfo.Version.Build

    # Winget richiede Windows 10 1709+ o Windows 11
    if ($osInfo.Version.Major -eq 10 -and $buildNumber -lt 16299) {
        Write-StyledMessage -type 'Error' -text "Windows 10 build $buildNumber non supporta Winget. È richiesto Windows 10 1709 o successivo."
        return $false
    }

    if ($osInfo.Version.Major -lt 10) {
        Write-StyledMessage -type 'Error' -text "Winget non è supportato su Windows $($osInfo.Version.Major). È richiesto Windows 10 o successivo."
        return $false
    }

    $originalPos = [Console]::CursorTop
    try {
        # Soppressione completa dell'output
        $ErrorActionPreference = 'SilentlyContinue'
        $ProgressPreference = 'SilentlyContinue'
        $VerbosePreference = 'SilentlyContinue'

        # Tentativo di riparazione per Windows 11 24H2+ (build 26100+)
        if ($buildNumber -ge 26100) {
            Write-StyledMessage -type 'Info' -text "Rilevato Windows 11 24H2+. Tentativo riparazione Winget..."
            try {
                if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                    $null = Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                    Start-Sleep 5
                    if (Test-WingetAvailable) {
                        Write-StyledMessage -type 'Success' -text "Winget riparato con successo su Windows 11 24H2+."
                        return $true
                    }
                }
            }
            catch {
                Write-StyledMessage -type 'Warning' -text "Riparazione automatica fallita. Procedendo con installazione completa..."
            }
        }

        # Installazione tramite Microsoft Store / App Installer (metodo universale)
        Write-StyledMessage -type 'Info' -text "Download e installazione Winget in corso..."
        $url = "https://aka.ms/getwinget"
        $temp = "$env:TEMP\WingetInstaller.msixbundle"

        # Rimuovi file esistente se presente
        if (Test-Path $temp) {
            Remove-Item $temp -Force *>$null
        }

        # Download del installer
        try {
            Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing -TimeoutSec 30 *>$null
        }
        catch {
            Write-StyledMessage -type 'Error' -text "Errore durante il download di Winget: $($_.Exception.Message)"
            return $false
        }

        # Installazione tramite PowerShell nascosto
        $installScript = @"
try {
    Add-AppxPackage -Path '$temp' -ForceApplicationShutdown -ErrorAction Stop
    exit 0
} catch {
    exit 1
}
"@

        $process = Start-Process powershell -ArgumentList @(
            "-NoProfile", "-WindowStyle", "Hidden", "-Command", $installScript
        ) -Wait -PassThru -WindowStyle Hidden

        # Pulizia file temporaneo
        Remove-Item $temp -Force -ErrorAction SilentlyContinue *>$null

        # Verifica installazione
        Start-Sleep 3
        if (Test-WingetAvailable) {
            Write-StyledMessage -type 'Success' -text "Winget installato con successo."
            return $true
        }
        else {
            Write-StyledMessage -type 'Error' -text "Installazione completata ma Winget non è disponibile. Codice uscita: $($process.ExitCode)"
            return $false
        }
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore durante l'installazione di Winget: $($_.Exception.Message)"
        return $false
    }
    finally {
        # Reset cursore e preferenze
        try {
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
        }
        catch {}

        # Reset delle preferenze
        $ErrorActionPreference = 'Continue'
        $ProgressPreference = 'Continue'
        $VerbosePreference = 'SilentlyContinue'
    }
}

# Funzione per installare Git
function Install-Git {
    Write-StyledMessage -type 'Info' -text "Verifica installazione di Git..."

    # Verifica se Git è già disponibile nel PATH aggiornato
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (Get-Command "git" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -type 'Success' -text "Git è già installato. Saltando l'installazione."
        return $true
    }

    Write-StyledMessage -type 'Info' -text "Git non trovato. Tentativo di installazione..."

    # Verifica se Winget è disponibile e funzionante
    $wingetAvailable = $false
    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        try {
            $wingetTest = winget --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                $wingetAvailable = $true
            }
        }
        catch {
            $wingetAvailable = $false
        }
    }

    if ($wingetAvailable) {
        Write-StyledMessage -type 'Info' -text "Tentativo installazione Git tramite winget..."
        try {
            $wingetOutput = winget install Git.Git --accept-source-agreements --accept-package-agreements --silent 2>&1
            $exitCode = $LASTEXITCODE

            # Verifica se l'installazione ha avuto successo
            Start-Sleep -Seconds 5
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            if (Get-Command "git" -ErrorAction SilentlyContinue) {
                Write-StyledMessage -type 'Success' -text "Git installato con successo tramite winget."
                return $true
            }

            # Se winget restituisce errore, passa all'installazione diretta
            if ($exitCode -ne 0) {
                Write-StyledMessage -type 'Warning' -text "winget ha restituito codice errore: $exitCode. Tentativo installazione diretta..."
            }
            else {
                Write-StyledMessage -type 'Warning' -text "winget completato ma Git non trovato. Tentativo installazione diretta..."
            }
        }
        catch {
            Write-StyledMessage -type 'Warning' -text "Errore durante l'esecuzione di winget: $($_.Exception.Message). Tentativo installazione diretta..."
        }
    }
    else {
        Write-StyledMessage -type 'Warning' -text "winget non disponibile o non funzionante. Procedendo con installazione diretta..."
    }

    # Installazione diretta da GitHub
    Write-StyledMessage -type 'Info' -text "Avvio installazione diretta di Git..."

    try {
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.1/Git-2.51.0-64-bit.exe"
        $gitInstaller = "$env:TEMP\Git-2.51.0-64-bit.exe"

        Write-StyledMessage -type 'Info' -text "Download di Git da GitHub..."

        # Verifica se il file esiste già e rimuovilo
        if (Test-Path $gitInstaller) {
            Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
        }

        # Download con timeout e retry
        $downloadSuccess = $false
        $maxRetries = 3
        for ($i = 1; $i -le $maxRetries; $i++) {
            try {
                Write-StyledMessage -type 'Info' -text "Tentativo di download $i di $maxRetries..."
                Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing -TimeoutSec 60
                $downloadSuccess = $true
                break
            }
            catch {
                Write-StyledMessage -type 'Warning' -text "Tentativo $i fallito: $($_.Exception.Message)"
                if ($i -lt $maxRetries) {
                    Start-Sleep -Seconds 2
                }
            }
        }

        if (-not $downloadSuccess) {
            Write-StyledMessage -type 'Error' -text "Impossibile scaricare Git dopo $maxRetries tentativi."
            return $false
        }

        # Verifica che il file sia stato scaricato correttamente
        if (-not (Test-Path $gitInstaller)) {
            Write-StyledMessage -type 'Error' -text "File installer non trovato dopo il download."
            return $false
        }

        Write-StyledMessage -type 'Info' -text "Installazione di Git in corso..."
        $installArgs = "/SILENT /NORESTART /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS"
        $process = Start-Process $gitInstaller -ArgumentList $installArgs -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-StyledMessage -type 'Success' -text "Git installato con successo."

            # Pulizia file temporaneo
            Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue

            # Aggiorna il PATH della sessione corrente
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            # Verifica finale
            if (Get-Command "git" -ErrorAction SilentlyContinue) {
                Write-StyledMessage -type 'Success' -text "Git è ora disponibile nel PATH."
                return $true
            }
            else {
                Write-StyledMessage -type 'Warning' -text "Installazione completata ma Git non trovato nel PATH. Potrebbe essere necessario un riavvio."
                return $true
            }
        }
        else {
            Write-StyledMessage -type 'Error' -text "Installazione di Git fallita. Codice di uscita: $($process.ExitCode)"
            Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
            return $false
        }
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore durante l'installazione diretta di Git: $($_.Exception.Message)"
        return $false
    }
}

# Funzione per installare PowerShell 7
function Install-PowerShell7 {
    Write-StyledMessage -type 'Info' -text "Tentativo installazione PowerShell 7..."
    
    if (Test-Path -Path "$env:ProgramFiles\PowerShell\7") {
        Write-StyledMessage -type 'Success' -text "PowerShell 7 è già installato. Saltando l'installazione."
        return $true
    }

    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -type 'Info' -text "Installazione PowerShell 7 tramite winget..."
        try {
            $wingetOutput = winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent 2>&1
            $exitCode = $LASTEXITCODE

            # Verifica se PowerShell 7 è stato effettivamente installato
            Start-Sleep -Seconds 3
            if (Test-Path -Path "$env:ProgramFiles\PowerShell\7") {
                Write-StyledMessage -type 'Success' -text "PowerShell 7 installato con successo tramite winget."
                return $true
            }

            if ($exitCode -eq 0) {
                Write-StyledMessage -type 'Success' -text "PowerShell 7 installato con successo tramite winget."
                return $true
            }
            else {
                Write-StyledMessage -type 'Warning' -text "winget ha restituito codice errore: $exitCode. Tentativo installazione diretta..."
            }
        }
        catch {
            Write-StyledMessage -type 'Warning' -text "Errore con winget: $($_.Exception.Message). Tentativo installazione diretta..."
        }
    }

    try {
        $ps7Url = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/PowerShell-7.5.2-win-x64.msi"
        $ps7Installer = "$env:TEMP\PowerShell-7.5.2-win-x64.msi"
        Write-StyledMessage -type 'Info' -text "Download PowerShell 7 da GitHub..."
        # Funzione per download ottimizzato con retry e metodi multipli
        function Invoke-OptimizedDownload {
            param(
                [string]$Url,
                [string]$OutputPath,
                [int]$MaxRetries = 3
            )

            $methods = @("WebClient", "BITS-Simple", "BITS", "Curl", "Invoke-WebRequest")
            $lastError = $null

            foreach ($method in $methods) {
                $bitsJob = $null
                for ($retry = 1; $retry -le $MaxRetries; $retry++) {
                    try {
                        Write-StyledMessage -type 'Info' -text "Download tentativo $retry/3 con metodo: $method"

                        switch ($method) {
                            "BITS-Simple" {
                                if (Get-Command "Start-BitsTransfer" -ErrorAction SilentlyContinue) {
                                    try {
                                        Write-StyledMessage -type 'Info' -text "Tentativo download BITS semplice..."
                                        Start-BitsTransfer -Source $Url -Destination $OutputPath -ErrorAction Stop
                                        Write-StyledMessage -type 'Success' -text "Download BITS completato."
                                        return $true
                                    }
                                    catch {
                                        Write-StyledMessage -type 'Warning' -text "BITS semplice fallito: $($_.Exception.Message)"
                                        throw
                                    }
                                }
                            }
                            "BITS" {
                                if (Get-Command "Start-BitsTransfer" -ErrorAction SilentlyContinue) {
                                    try {
                                        Write-StyledMessage -type 'Info' -text "Avvio trasferimento BITS..."
                                        $bitsJob = Start-BitsTransfer -Source $Url -Destination $OutputPath -ErrorAction Stop

                                        # Attendere il completamento del job BITS
                                        while ($bitsJob.JobState -in @("Connecting", "Transferring", "Queued")) {
                                            Start-Sleep -Seconds 2
                                            $bitsJob = Get-BitsTransfer -JobId $bitsJob.JobId -ErrorAction SilentlyContinue
                                            if ($bitsJob) {
                                                $progress = 0
                                                if ($bitsJob.BytesTotal -gt 0) {
                                                    $progress = [math]::Round((($bitsJob.BytesTransferred / $bitsJob.BytesTotal) * 100), 1)
                                                }
                                                Write-Progress -Activity "Download PowerShell 7 (BITS)" -Status "$progress% completato ($([math]::Round($bitsJob.BytesTransferred/1MB, 2)) MB / $([math]::Round($bitsJob.BytesTotal/1MB, 2)) MB)" -PercentComplete $progress
                                            }
                                        }

                                        Write-Progress -Activity "Download PowerShell 7 (BITS)" -Completed

                                        # Verifica stato finale
                                        if ($bitsJob.JobState -eq "Transferred") {
                                            Complete-BitsTransfer -BitsJob $bitsJob -ErrorAction Stop
                                            Write-StyledMessage -type 'Success' -text "Trasferimento BITS completato con successo."
                                            return $true
                                        }
                                        else {
                                            throw "BITS transfer failed with state: $($bitsJob.JobState)"
                                        }
                                    }
                                    catch {
                                        Write-StyledMessage -type 'Warning' -text "BITS transfer failed: $($_.Exception.Message)"
                                        # Cleanup BITS job se esiste ancora
                                        try {
                                            if ($bitsJob) {
                                                Remove-BitsTransfer -BitsJob $bitsJob -ErrorAction SilentlyContinue
                                            }
                                        }
                                        catch {
                                            Write-StyledMessage -type 'Warning' -text "Errore durante cleanup BITS: $($_.Exception.Message)"
                                        }
                                        throw
                                    }
                                }
                            }
                            "WebClient" {
                                $webClient = New-Object System.Net.WebClient
                                $webClient.DownloadFile($Url, $OutputPath)
                                return $true
                            }
                            "Curl" {
                                if (Get-Command "curl.exe" -ErrorAction SilentlyContinue) {
                                    curl.exe -L -o $OutputPath $Url --progress-bar -S
                                    if ($LASTEXITCODE -eq 0) {
                                        return $true
                                    }
                                }
                            }
                            "Invoke-WebRequest" {
                                Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -TimeoutSec 600 -ErrorAction Stop
                                return $true
                            }
                        }
                    }
                    catch {
                        $lastError = $_.Exception.Message
                        Write-StyledMessage -type 'Warning' -text "Tentativo $retry fallito con $method`: $($_.Exception.Message)"

                        # Rimuovi file parziale se esiste
                        if (Test-Path $OutputPath) {
                            Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
                        }

                        if ($retry -lt $MaxRetries) {
                            $waitSeconds = [math]::Pow(2, $retry)  # Exponential backoff
                            Write-StyledMessage -type 'Info' -text "Attesa $waitSeconds secondi prima del prossimo tentativo..."
                            Start-Sleep -Seconds $waitSeconds
                        }
                    }
                }
            }

            # Cleanup eventuali BITS jobs pendenti prima di uscire
            try {
                Get-BitsTransfer -AllUsers -ErrorAction SilentlyContinue | Remove-BitsTransfer -ErrorAction SilentlyContinue
            }
            catch {}

            Write-StyledMessage -type 'Error' -text "Tutti i tentativi di download sono falliti. Ultimo errore: $lastError"
            return $false
        }

        # Esegui il download ottimizzato
        if (-not (Invoke-OptimizedDownload -Url $ps7Url -OutputPath $ps7Installer)) {
            return $false
        }

        # Verifica che il file sia stato scaricato correttamente
        if (-not (Test-Path $ps7Installer)) {
            Write-StyledMessage -type 'Error' -text "File installer non trovato dopo il download."
            return $false
        }

        # Verifica dimensione del file (PowerShell 7 MSI dovrebbe essere > 100MB)
        $fileSize = (Get-Item $ps7Installer).Length
        if ($fileSize -lt 100MB) {
            Write-StyledMessage -type 'Error' -text "File installer scaricato è troppo piccolo ($([math]::Round($fileSize/1MB, 2)) MB). Possibile download incompleto."
            Remove-Item $ps7Installer -Force -ErrorAction SilentlyContinue
            return $false
        }

        Write-StyledMessage -type 'Success' -text "Download completato. Dimensione file: $([math]::Round($fileSize/1MB, 2)) MB"

        # Verifica se ci sono processi msiexec in esecuzione che potrebbero interferire
        $existingMsiExec = Get-Process -Name "msiexec" -ErrorAction SilentlyContinue
        if ($existingMsiExec) {
            Write-StyledMessage -type 'Warning' -text "Rilevati $($existingMsiExec.Count) processi MSI esistenti in esecuzione. Possibile conflitto."
        }

        # Verifica connessione di rete
        try {
            $connectionTest = Test-Connection -ComputerName "github.com" -Count 1 -ErrorAction Stop
            Write-StyledMessage -type 'Success' -text "Connessione di rete verificata. Latenza: $($connectionTest.ResponseTime)ms"
        }
        catch {
            Write-StyledMessage -type 'Warning' -text "Possibili problemi di connessione di rete: $($_.Exception.Message)"
        }
        
        Write-StyledMessage -type 'Info' -text "Installazione PowerShell 7 in corso..."
        $installArgs = "/i `"$ps7Installer`" /quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1"

        # Usa un job per monitorare il processo con timeout
        $job = Start-Job -ScriptBlock {
            param($installer, $args)
            $process = Start-Process "msiexec.exe" -ArgumentList $args -Wait -PassThru
            return @{
                ExitCode  = $process.ExitCode
                ProcessId = $process.Id
            }
        } -ArgumentList $ps7Installer, $installArgs

        # Attendere il completamento con timeout di 10 minuti (600 secondi)
        $timeoutSeconds = 600
        $jobResult = $null
        $completed = $false

        try {
            Write-StyledMessage -type 'Info' -text "Monitoraggio installazione in corso (timeout: $timeoutSeconds secondi)..."
            $jobResult = Wait-Job -Job $job -Timeout $timeoutSeconds
            $completed = $true
        }
        catch {
            Write-StyledMessage -type 'Warning' -text "Timeout raggiunto durante l'installazione. Possibile processo bloccato."
            $completed = $false
        }

        if ($completed -and $jobResult.State -eq 'Completed') {
            $result = Receive-Job -Job $job
            if ($result.ExitCode -eq 0) {
                Write-StyledMessage -type 'Success' -text "PowerShell 7 installato con successo."
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                Remove-Item $ps7Installer -Force -ErrorAction SilentlyContinue
                return $true
            }
            else {
                Write-StyledMessage -type 'Error' -text "Installazione PowerShell 7 fallita. Codice di uscita: $($result.ExitCode)"
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                return $false
            }
        }
        else {
            # Timeout o errore - termina il processo se ancora in esecuzione
            Write-StyledMessage -type 'Warning' -text "Tentativo di terminazione processo di installazione..."
            try {
                $runningProcess = Get-Process -Name "msiexec" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*PowerShell-7*" }
                if ($runningProcess) {
                    Stop-Process -Id $runningProcess.Id -Force -ErrorAction SilentlyContinue
                    Write-StyledMessage -type 'Info' -text "Processo msiexec terminato forzatamente."
                }
            }
            catch {
                Write-StyledMessage -type 'Warning' -text "Impossibile terminare il processo: $($_.Exception.Message)"
            }

            # Cleanup del job
            try {
                if ($job) {
                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-StyledMessage -type 'Warning' -text "Errore durante la pulizia del job: $($_.Exception.Message)"
            }

            # Cleanup del file installer
            if (Test-Path $ps7Installer) {
                Remove-Item $ps7Installer -Force -ErrorAction SilentlyContinue
            }

            # Verifica se PowerShell 7 è stato installato nonostante il timeout
            Start-Sleep -Seconds 5
            if (Test-Path -Path "$env:ProgramFiles\PowerShell\7") {
                Write-StyledMessage -type 'Success' -text "PowerShell 7 è stato installato nonostante il timeout. Possibile completamento ritardato."
                return $true
            }

            Write-StyledMessage -type 'Error' -text "Installazione PowerShell 7 interrotta per timeout o errore."
            return $false
        }
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore durante l'installazione di PowerShell 7: $($_.Exception.Message)"
        return $false
    }
}

# Funzione per installare e configurare Windows Terminal
function Install-WindowsTerminal {
    Write-StyledMessage -type 'Info' -text "Configurazione Windows Terminal..."
    
    $wtInstalled = Get-Command "wt" -ErrorAction SilentlyContinue
    if ($wtInstalled) {
        Write-StyledMessage -type 'Success' -text "Windows Terminal già presente. Verifica configurazione..."
    }

    # Tentativo 1: winget (metodo più affidabile)
    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        Write-StyledMessage -type 'Info' -text "Installazione tramite winget..."
        try {
            $wingetOutput = winget install --id 9N0DX20HK701 --source msstore --accept-source-agreements --accept-package-agreements --silent 2>&1
            $exitCode = $LASTEXITCODE

            # Verifica se Windows Terminal è stato installato
            Start-Sleep -Seconds 3
            if (Get-Command "wt" -ErrorAction SilentlyContinue) {
                Write-StyledMessage -type 'Success' -text "Windows Terminal installato tramite winget."
            }
            elseif ($exitCode -ne 0) {
                Write-StyledMessage -type 'Warning' -text "winget ha restituito codice errore: $exitCode. Tentativo download diretto..."
            }
        }
        catch {
            Write-StyledMessage -type 'Warning' -text "Installazione winget fallita: $($_.Exception.Message). Tentativo download diretto..."
        }
    }

    # Tentativo 2: Microsoft Store
    if (-not (Get-Command "wt" -ErrorAction SilentlyContinue)) {
        try {
            Write-StyledMessage -type 'Info' -text "Tentativo installazione tramite Microsoft Store..."
            Start-Process "ms-windows-store://pdp/?ProductId=9N0DX20HK701"
            Start-Sleep -Seconds 5
        }
        catch {
            Write-StyledMessage -type 'Warning' -text "Impossibile aprire Microsoft Store."
        }
    }

    # Tentativo 3: GitHub Release
    if (-not (Get-Command "wt" -ErrorAction SilentlyContinue)) {
        try {
            Write-StyledMessage -type 'Info' -text "Download ultima versione da GitHub..."
            $releaseUrl = "https://api.github.com/repos/microsoft/terminal/releases/latest"
            $release = Invoke-RestMethod -Uri $releaseUrl -UseBasicParsing
            $asset = $release.assets | Where-Object { $_.name -like "*Win10*msixbundle" } | Select-Object -First 1
            
            if ($asset) {
                $installerPath = "$env:TEMP\$($asset.name)"
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -UseBasicParsing
                Add-AppxPackage -Path $installerPath
                Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                Write-StyledMessage -type 'Success' -text "Windows Terminal installato da GitHub."
            }
        }
        catch {
            Write-StyledMessage -type 'Warning' -text "Installazione da GitHub fallita: $($_.Exception.Message)"
        }
    }

    # Imposta Windows Terminal come applicazione terminale predefinita
    try {
        $terminalPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
        if (Test-Path $terminalPath) {
            $registryPath = "HKCU:\Console\%%Startup"
            if (-not (Test-Path $registryPath)) {
                New-Item -Path $registryPath -Force | Out-Null
            }
            Set-ItemProperty -Path $registryPath -Name "DelegationConsole" -Value "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}" -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $registryPath -Name "DelegationTerminal" -Value "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}" -Force -ErrorAction SilentlyContinue
            Write-StyledMessage -type 'Success' -text "Windows Terminal impostato come terminale predefinito."
        }
    }
    catch {
        Write-StyledMessage -type 'Warning' -text "Impossibile impostare terminale predefinito: $($_.Exception.Message)"
    }

    # Configura PowerShell 7 come profilo predefinito con esecuzione amministratore
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (Test-Path $settingsPath) {
        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            $ps7Profile = $settings.profiles.list | Where-Object { $_.name -eq "PowerShell" }
            
            if ($ps7Profile) {
                $settings.defaultProfile = $ps7Profile.guid
                $ps7Profile | Add-Member -NotePropertyName "elevate" -NotePropertyValue $true -Force
                
                $settings | ConvertTo-Json -Depth 100 | Set-Content $settingsPath -Force
                Write-StyledMessage -type 'Success' -text "PowerShell 7 configurato come profilo predefinito con privilegi amministratore."
            }
            else {
                Write-StyledMessage -type 'Warning' -text "Profilo PowerShell 7 non trovato in Windows Terminal."
            }
        }
        catch {
            Write-StyledMessage -type 'Error' -text "Errore configurazione settings.json: $($_.Exception.Message)"
        }
    }
    else {
        Write-StyledMessage -type 'Warning' -text "File settings.json non trovato. Avviare Windows Terminal almeno una volta."
    }
}

# Funzione per creare la scorciatoia sul desktop
function ToolKit-Desktop {
    Write-StyledMessage -type 'Info' -text "Creazione scorciatoia sul desktop..."
    
    try {
        # Determina il percorso del desktop dell'utente corrente
        $desktopPath = [System.Environment]::GetFolderPath('Desktop')
        $shortcutPath = Join-Path -Path $desktopPath -ChildPath "Win Toolkit.lnk"
        
        # Percorso per salvare l'icona
        $iconDir = "$env:LOCALAPPDATA\WinToolkit"
        $iconPath = Join-Path -Path $iconDir -ChildPath "WinToolkit.ico"
        
        # Crea la directory se non esiste
        if (-not (Test-Path -Path $iconDir)) {
            New-Item -Path $iconDir -ItemType Directory -Force | Out-Null
        }
        
        # Scarica l'icona da GitHub solo se non esiste già
        if (-not (Test-Path -Path $iconPath)) {
            Write-StyledMessage -type 'Info' -text "Download icona in corso..."
            $iconUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/img/WinToolkit.ico"
            Invoke-WebRequest -Uri $iconUrl -OutFile $iconPath -UseBasicParsing
            Write-StyledMessage -type 'Success' -text "Icona scaricata e salvata in $iconDir."
        }
        else {
            Write-StyledMessage -type 'Info' -text "Icona già presente in $iconDir."
        }
        
        # Crea un oggetto WScript.Shell per la creazione della scorciatoia
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        
        # Imposta la destinazione del file eseguibile (TargetPath) - Windows Terminal
        $Shortcut.TargetPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
        
        # Imposta gli argomenti della riga di comando (Arguments)
        $Shortcut.Arguments = 'pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://magnetarman.com/WinToolkit | iex"'
        
        # Imposta la directory di lavoro
        $Shortcut.WorkingDirectory = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
        
        # Imposta l'icona personalizzata
        $Shortcut.IconLocation = $iconPath

        # Imposta la descrizione della scorciatoia
        $Shortcut.Description = "Win Toolkit - SOPRAVVIVI A Windows"
        
        # Salva la scorciatoia prima di modificare le proprietà avanzate
        $Shortcut.Save()
        
        # Modifica il file .lnk per abilitare l'esecuzione come amministratore
        $bytes = [System.IO.File]::ReadAllBytes($shortcutPath)
        # Il byte 21 contiene i flag della scorciatoia. Impostiamo il bit 5 (valore 32 o 0x20) per "Esegui come amministratore"
        $bytes[21] = $bytes[21] -bor 32
        [System.IO.File]::WriteAllBytes($shortcutPath, $bytes)
        
        Write-StyledMessage -type 'Success' -text "Scorciatoia 'Win Toolkit.lnk' creata con successo sul desktop."
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore durante la creazione della scorciatoia: $($_.Exception.Message)"
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
            "&([ScriptBlock]::Create((irm https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/start.ps1))) $($argList -join ' ')"
        }
        Start-Process "powershell" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
        return
    }

    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
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
        '        Version 2.2.2 (Build 28)'
    )
    foreach ($line in $asciiArt) {
        Write-Host (Center-text -text $line -width $width) -ForegroundColor White
    }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''
    
    Write-StyledMessage -type 'Info' -text "Versione PowerShell rilevata: $($PSVersionTable.PSVersion)"
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-StyledMessage -type 'Warning' -text "PowerShell 5 rilevato. PowerShell 7 è raccomandato per funzionalità avanzate."
    }

    Write-StyledMessage -type 'Info' -text "Avvio configurazione Win Toolkit..."

    $rebootNeeded = $false
  
    Install-WingetSilent

    Install-Git
    
    $ps7Installed = (Test-Path -Path "$env:ProgramFiles\PowerShell\7")
    if (-not $ps7Installed) {
        $installSuccess = Install-PowerShell7
        if ($installSuccess) {
            $rebootNeeded = $true
        }
    }
    else {
        Write-StyledMessage -type 'Success' -text "PowerShell 7 già presente."
    }

    Install-WindowsTerminal
    ToolKit-Desktop
    
    Write-StyledMessage -type 'Success' -text "Script di Start eseguito correttamente."
    
    if ($rebootNeeded) {
        Write-StyledMessage -type 'Warning' -text "Attenzione: il sistema verrà riavviato per rendere effettive le modifiche"
        Write-StyledMessage -type 'Info' -text "Preparazione al riavvio del sistema..."
        for ($i = 10; $i -gt 0; $i--) {
            Write-Host "Preparazione sistema al riavvio - $i secondi..." -NoNewline -ForegroundColor Yellow
            Write-Host "`r" -NoNewline
            Start-Sleep 1
        }
        Write-StyledMessage -type 'Info' -text "Riavvio in corso..."
        try { Stop-Transcript | Out-Null } catch {}
        Restart-Computer -Force
    }
    else {
        Write-StyledMessage -type 'Info' -text "Non è necessario riavviare il sistema in quanto PowerShell 7 era già installato."
        try { Stop-Transcript | Out-Null } catch {}
    }
}

Start-WinToolkit