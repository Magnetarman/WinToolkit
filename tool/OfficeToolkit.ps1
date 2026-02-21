function OfficeToolkit {
    <#
    .SYNOPSIS
        Strumento di gestione Microsoft Office (installazione, riparazione, rimozione)

    .DESCRIPTION
        Script PowerShell per gestire Microsoft Office tramite interfaccia utente semplificata.
        Supporta installazione Office Basic, riparazione Click-to-Run e rimozione automatica basata sulla versione Windows.

    .PARAMETER CountdownSeconds
        Numero di secondi per il countdown prima del riavvio.

    .OUTPUTS
        None. La funzione non restituisce output.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,
        
        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # 1. Inizializzazione logging
    Initialize-ToolLogging -ToolName "OfficeToolkit"
    Show-Header -SubTitle "Office Toolkit"

    # Configurazione
    $TempDir = $AppConfig.Paths.OfficeTemp

    # Funzioni Helper Locali
    function Clear-ConsoleLine {
        $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
        Write-Host $clearLine -NoNewline
        [Console]::Out.Flush()
    }

    function Invoke-SilentRemoval {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,
            [switch]$Recurse
        )

        if (-not (Test-Path $Path)) { return $false }

        try {
            $originalPos = [Console]::CursorTop
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'

            if ($Recurse) {
                Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue *>$null
            }
            else {
                Remove-Item $Path -Force -ErrorAction SilentlyContinue *>$null
            }

            [Console]::SetCursorPosition(0, $originalPos)
            Clear-ConsoleLine

            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'

            return $true
        }
        catch {
            return $false
        }
    }



    function Get-UserConfirmation([string]$Message, [string]$DefaultChoice = 'N') {
        do {
            $response = Read-Host "$Message [Y/N]"
            if ([string]::IsNullOrEmpty($response)) { $response = $DefaultChoice }
            $response = $response.ToUpper()
        } while ($response -notin @('Y', 'N'))
        return $response -eq 'Y'
    }

    function Get-WindowsVersion {
        try {
            $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
            $buildNumber = [int]$osInfo.BuildNumber

            if ($buildNumber -ge 22631) {
                return "Windows11_23H2_Plus"
            }
            elseif ($buildNumber -ge 22000) {
                return "Windows11_22H2_Or_Older"
            }
            else {
                return "Windows10_Or_Older"
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile rilevare versione Windows: $_"
            return "Unknown"
        }
    }


    function Stop-OfficeProcesses {
        $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
        $closed = 0

        Write-StyledMessage Info "📋 Chiusura processi Office..."
        foreach ($processName in $processes) {
            $runningProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($runningProcesses) {
                try {
                    $runningProcesses | Stop-Process -Force -ErrorAction Stop
                    $closed++
                }
                catch {
                    Write-StyledMessage Warning "Impossibile chiudere: $processName"
                }
            }
        }

        if ($closed -gt 0) {
            Write-StyledMessage Success "$closed processi Office chiusi"
        }
    }

    function Invoke-DownloadFile([string]$Url, [string]$OutputPath, [string]$Description) {
        try {
            Write-StyledMessage Info "📥 Download $Description..."
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $OutputPath)
            $webClient.Dispose()

            if (Test-Path $OutputPath) {
                Write-StyledMessage Success "Download completato: $Description"
                return $true
            }
            else {
                Write-StyledMessage Error "File non trovato dopo download: $Description"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore download $Description`: $_"
            return $false
        }
    }

    function Start-OfficeInstallation {
        Write-StyledMessage Info "🏢 Avvio installazione Office Basic..."

        try {
            if (-not (Test-Path $TempDir)) {
                New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
            }

            $setupPath = Join-Path $TempDir 'Setup.exe'
            $configPath = Join-Path $TempDir 'Basic.xml'

            $downloads = @(
                @{ Url = $AppConfig.URLs.OfficeSetup; Path = $setupPath; Name = 'Setup Office' },
                @{ Url = $AppConfig.URLs.OfficeBasicConfig; Path = $configPath; Name = 'Configurazione Basic' }
            )

            foreach ($download in $downloads) {
                if (-not (Invoke-DownloadFile $download.Url $download.Path $download.Name)) {
                    return $false
                }
            }

            Write-StyledMessage Info "🚀 Avvio processo installazione..."
            $arguments = "/configure `"$configPath`""
            $procParams = @{
                FilePath         = $setupPath
                ArgumentList     = $arguments
                WorkingDirectory = $TempDir
            }
            Start-Process @procParams

            Write-StyledMessage Info "⏳ Attesa completamento installazione..."
            Write-Host "💡 Premi INVIO quando l'installazione è completata..." -ForegroundColor Yellow
            Read-Host | Out-Null

            if (Get-UserConfirmation "✅ Installazione completata con successo?" 'Y') {
                # Nuove configurazioni post-installazione: Disabilitazione Telemetria e Notifiche Crash
                Write-StyledMessage Info "⚙️ Configurazione post-installazione Office..."

                # Configurazione telemetria Office
                Write-StyledMessage Info "⚙️ Disabilitazione telemetria Office..."
                $RegPathTelemetry = $AppConfig.Registry.OfficeTelemetry
                if (-not (Test-Path $RegPathTelemetry)) { New-Item $RegPathTelemetry -Force | Out-Null }
                Set-ItemProperty -Path $RegPathTelemetry -Name "DisableTelemetry" -Value 1 -Type DWord -Force
                Write-StyledMessage Success "✅ Telemetria Office disabilitata"

                # Configurazione notifiche crash Office
                Write-StyledMessage Info "⚙️ Disabilitazione notifiche crash Office..."
                $RegPathFeedback = $AppConfig.Registry.OfficeFeedback
                if (-not (Test-Path $RegPathFeedback)) { New-Item $RegPathFeedback -Force | Out-Null }
                Set-ItemProperty -Path $RegPathFeedback -Name "OnBootNotify" -Value 0 -Type DWord -Force
                Write-StyledMessage Success "✅ Notifiche crash Office disabilitate"
                # Fine nuove configurazioni

                Write-StyledMessage Success "🎉 Installazione Office completata!"
                return $true
            }
            else {
                Write-StyledMessage Warning "Installazione non completata correttamente"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante installazione Office: $($_.Exception.Message)"
            return $false
        }
        finally {
            Invoke-SilentRemoval -Path $TempDir -Recurse
        }
    }

    function Start-OfficeRepair {
        Write-StyledMessage Info "🔧 Avvio riparazione Office..."
        Stop-OfficeProcesses

        Write-StyledMessage Info "🧹 Pulizia cache Office..."
        $caches = @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )

        $cleanedCount = 0
        foreach ($cache in $caches) {
            if (Invoke-SilentRemoval -Path $cache -Recurse) {
                $cleanedCount++
            }
        }

        if ($cleanedCount -gt 0) {
            Write-StyledMessage Success "$cleanedCount cache eliminate"
        }

        Write-StyledMessage Info "🎯 Tipo di riparazione:"
        Write-Host "  [1] 🚀 Riparazione rapida (offline)" -ForegroundColor Green
        Write-Host "  [2] 🌐 Riparazione completa (online)" -ForegroundColor Yellow

        do {
            $choice = Read-Host "Scelta [1-2]"
        } while ($choice -notin @('1', '2'))

        try {
            $repairType = if ($choice -eq '1') { 'QuickRepair' } else { 'FullRepair' }
            $repairName = if ($choice -eq '1') { 'rapida' } else { 'completa' }

            Write-StyledMessage Info "🔧 Avvio riparazione $repairName..."
            $arguments = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=$repairType DisplayLevel=True"

            $officeClient = "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
            if (-not (Test-Path $officeClient)) {
                $officeClient = "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"
            }

            $procParams = @{
                FilePath     = $officeClient
                ArgumentList = $arguments
            }
            Start-Process @procParams

            Write-StyledMessage Info "⏳ Attesa completamento riparazione..."
            Write-Host "💡 Premi INVIO quando la riparazione è completata..." -ForegroundColor Yellow
            Read-Host | Out-Null

            if (Get-UserConfirmation "✅ Riparazione completata con successo?" 'Y') {
                Write-StyledMessage Success "🎉 Riparazione Office completata!"
                return $true
            }
            else {
                Write-StyledMessage Warning "Riparazione non completata correttamente"
                if ($choice -eq '1') {
                    if (Get-UserConfirmation "🌐 Tentare riparazione completa online?" 'Y') {
                        Write-StyledMessage Info "🌐 Avvio riparazione completa..."
                        $arguments = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True"
                        $procParams = @{
                            FilePath     = $officeClient
                            ArgumentList = $arguments
                        }
                        Start-Process @procParams

                        Write-Host "💡 Premi INVIO quando la riparazione completa è terminata..." -ForegroundColor Yellow
                        Read-Host | Out-Null

                        return Get-UserConfirmation "✅ Riparazione completa riuscita?" 'Y'
                    }
                }
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante riparazione Office: $($_.Exception.Message)"
            return $false
        }
    }

    function Remove-ItemsSilently {
        param(
            [string[]]$Paths,
            [string]$ItemType = "cartella"
        )

        $removed = @()
        $failed = @()

        foreach ($path in $Paths) {
            if (Test-Path $path) {
                if (Invoke-SilentRemoval -Path $path -Recurse) {
                    $removed += $path
                }
                else {
                    $failed += $path
                }
            }
        }

        return @{
            Removed = $removed
            Failed  = $failed
            Count   = $removed.Count
        }
    }

    function Remove-OfficeDirectly {
        Write-StyledMessage Info "🔧 Avvio rimozione diretta Office..."

        try {
            # Metodo 1: Rimozione pacchetti
            Write-StyledMessage Info "📋 Ricerca installazioni Office..."

            $officePackages = Get-Package -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*Microsoft Office*" -or $_.Name -like "*Microsoft 365*" -or $_.Name -like "*Office*" }

            if ($officePackages) {
                Write-StyledMessage Info "Trovati $($officePackages.Count) pacchetti Office"
                foreach ($package in $officePackages) {
                    try {
                        Uninstall-Package -Name $package.Name -Force -ErrorAction Stop | Out-Null
                        Write-StyledMessage Success "Rimosso: $($package.Name)"
                    }
                    catch {}
                }
            }

            # Metodo 2: Rimozione tramite registro
            Write-StyledMessage Info "🔍 Ricerca nel registro..."

            $uninstallKeys = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )

            foreach ($keyPath in $uninstallKeys) {
                try {
                    $items = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue |
                    Where-Object { $_.DisplayName -like "*Office*" -or $_.DisplayName -like "*Microsoft 365*" }

                    foreach ($item in $items) {
                        if ($item.UninstallString -and $item.UninstallString -match "msiexec") {
                            try {
                                $productCode = $item.PSChildName
                                $procParams = @{
                                    FilePath     = 'msiexec.exe'
                                    ArgumentList = @('/x', $productCode, '/qn', '/norestart')
                                    Wait         = $true
                                    NoNewWindow  = $true
                                    ErrorAction  = 'Stop'
                                }
                                Start-Process @procParams
                            }
                            catch {}
                        }
                    }
                }
                catch {}
            }

            # Metodo 3: Stop servizi Office
            Write-StyledMessage Info "🛑 Arresto servizi Office..."

            $officeServices = @('ClickToRunSvc', 'OfficeSvc', 'OSE')
            $stoppedServices = 0
            foreach ($serviceName in $officeServices) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    try {
                        Stop-Service -Name $serviceName -Force -ErrorAction Stop
                        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
                        Write-StyledMessage Success "Servizio arrestato: $serviceName"
                        $stoppedServices++
                    }
                    catch {}
                }
            }

            # Metodo 4: Pulizia cartelle Office
            Write-StyledMessage Info "🧹 Pulizia cartelle Office..."

            $foldersToClean = @(
                "$env:ProgramFiles\Microsoft Office",
                "${env:ProgramFiles(x86)}\Microsoft Office",
                "$env:ProgramFiles\Microsoft Office 15",
                "${env:ProgramFiles(x86)}\Microsoft Office 15",
                "$env:ProgramFiles\Microsoft Office 16",
                "${env:ProgramFiles(x86)}\Microsoft Office 16",
                "$env:ProgramData\Microsoft\Office",
                "$env:LOCALAPPDATA\Microsoft\Office",
                "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun",
                "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun"
            )

            $folderResult = Remove-ItemsSilently -Paths $foldersToClean -ItemType "cartella"

            if ($folderResult.Count -gt 0) {
                Write-StyledMessage Success "$($folderResult.Count) cartelle Office rimosse"
            }

            if ($folderResult.Failed.Count -gt 0) {
                Write-StyledMessage Warning "Impossibile rimuovere $($folderResult.Failed.Count) cartelle (potrebbero essere in uso)"
            }

            # Metodo 5: Pulizia registro Office
            Write-StyledMessage Info "🔧 Pulizia registro Office..."

            $registryPaths = @(
                "HKCU:\Software\Microsoft\Office",
                "HKLM:\SOFTWARE\Microsoft\Office",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office",
                "HKCU:\Software\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun"
            )

            $regResult = Remove-ItemsSilently -Paths $registryPaths -ItemType "chiave"

            if ($regResult.Count -gt 0) {
                Write-StyledMessage Success "$($regResult.Count) chiavi registro Office rimosse"
            }

            # Metodo 6: Pulizia attività pianificate
            Write-StyledMessage Info "📅 Pulizia attività pianificate..."

            try {
                $officeTasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
                Where-Object { $_.TaskName -like "*Office*" }

                $tasksRemoved = 0
                foreach ($task in $officeTasks) {
                    try {
                        Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
                        $tasksRemoved++
                    }
                    catch {}
                }

                if ($tasksRemoved -gt 0) {
                    Write-StyledMessage Success "$tasksRemoved attività Office rimosse"
                }
            }
            catch {}

            # Metodo 7: Rimozione collegamenti
            Write-StyledMessage Info "🖥️ Rimozione collegamenti Office..."

            $officeShortcuts = @(
                "Microsoft Word*.lnk", "Microsoft Excel*.lnk", "Microsoft PowerPoint*.lnk",
                "Microsoft Outlook*.lnk", "Microsoft OneNote*.lnk", "Microsoft Access*.lnk",
                "Office*.lnk", "Word*.lnk", "Excel*.lnk", "PowerPoint*.lnk", "Outlook*.lnk"
            )

            $desktopPaths = @(
                "$env:USERPROFILE\Desktop",
                "$env:PUBLIC\Desktop",
                "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs"
            )

            $shortcutsRemoved = 0
            foreach ($desktopPath in $desktopPaths) {
                if (Test-Path $desktopPath) {
                    foreach ($shortcut in $officeShortcuts) {
                        $shortcutFiles = Get-ChildItem -Path $desktopPath -Filter $shortcut -Recurse -ErrorAction SilentlyContinue
                        foreach ($file in $shortcutFiles) {
                            if (Invoke-SilentRemoval -Path $file.FullName) {
                                $shortcutsRemoved++
                            }
                        }
                    }
                }
            }

            if ($shortcutsRemoved -gt 0) {
                Write-StyledMessage Success "$shortcutsRemoved collegamenti Office rimossi"
            }

            # Metodo 8: Pulizia residui aggiuntivi
            Write-StyledMessage Info "💽 Pulizia residui Office..."

            $additionalPaths = @(
                "$env:LOCALAPPDATA\Microsoft\OneDrive",
                "$env:APPDATA\Microsoft\OneDrive",
                "$env:TEMP\Office*",
                "$env:TEMP\MSO*"
            )

            $residualsResult = Remove-ItemsSilently -Paths $additionalPaths -ItemType "residuo"

            Write-StyledMessage Success "✅ Rimozione diretta completata"
            Write-StyledMessage Info "📊 Riepilogo: $($folderResult.Count) cartelle, $($regResult.Count) chiavi registro, $shortcutsRemoved collegamenti, $tasksRemoved attività rimosse"

            return $true
        }
        catch {
            Write-StyledMessage Error "Errore durante rimozione diretta Office: $($_.Exception.Message)"
            return $false
        }
    }

    function Start-OfficeUninstallWithSaRA {
        try {
            if (-not (Test-Path $TempDir)) {
                New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
            }

            $saraUrl = $AppConfig.URLs.SaRAInstaller
            $saraZipPath = Join-Path $TempDir 'SaRA.zip'

            if (-not (Invoke-DownloadFile $saraUrl $saraZipPath 'Microsoft SaRA')) {
                return $false
            }

            Write-StyledMessage Info "📦 Estrazione SaRA..."
            try {
                Expand-Archive -Path $saraZipPath -DestinationPath $TempDir -Force
                Write-StyledMessage Success "Estrazione completata"
            }
            catch {
                Write-StyledMessage Error "Errore durante estrazione archivio SaRA: $($_.Exception.Message)"
                return $false
            }

            $saraExe = Get-ChildItem -Path $TempDir -Filter "SaRAcmd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $saraExe) {
                Write-StyledMessage Error "SaRAcmd.exe non trovato"
                return $false
            }

            Write-StyledMessage Info "🚀 Rimozione tramite SaRA..."
            Write-StyledMessage Warning "⏰ Questa operazione può richiedere alcuni minuti"

            $arguments = '-S OfficeScrubScenario -AcceptEula -OfficeVersion All'

            try {
                $procParams = @{
                    FilePath     = $saraExe.FullName
                    ArgumentList = $arguments
                    Verb         = 'RunAs'
                    PassThru     = $true
                    Wait         = $true
                    ErrorAction  = 'Stop'
                }
                $process = Start-Process @procParams

                if ($process.ExitCode -eq 0) {
                    Write-StyledMessage Success "✅ SaRA completato con successo"
                    return $true
                }
                else {
                    Write-StyledMessage Warning "SaRA terminato con codice: $($process.ExitCode)"
                    Write-StyledMessage Info "💡 Tentativo metodo alternativo..."
                    return Remove-OfficeDirectly
                }
            }
            catch {
                Write-StyledMessage Warning "Errore durante esecuzione SaRA: $($_.Exception.Message)"
                Write-StyledMessage Info "💡 Passaggio a metodo alternativo..."
                return Remove-OfficeDirectly
            }
        }
        catch {
            Write-StyledMessage Warning "Errore durante processo SaRA: $($_.Exception.Message)"
            return $false
        }
        finally {
            Invoke-SilentRemoval -Path $TempDir -Recurse
        }
    }

    function Start-OfficeUninstall {
        Write-StyledMessage Warning "🗑️ Rimozione completa Microsoft Office"

        if (-not (Get-UserConfirmation "❓ Procedere con la rimozione completa?")) {
            Write-StyledMessage Info "❌ Operazione annullata"
            return $false
        }

        Stop-OfficeProcesses

        Write-StyledMessage Info "🔍 Rilevamento versione Windows..."
        $windowsVersion = Get-WindowsVersion
        Write-StyledMessage Info "🎯 Versione rilevata: $windowsVersion"

        $success = $false

        switch ($windowsVersion) {
            'Windows11_23H2_Plus' {
                Write-StyledMessage Info "🚀 Utilizzo metodo SaRA per Windows 11 23H2+..."
                $success = Start-OfficeUninstallWithSaRA
            }
            default {
                Write-StyledMessage Info "⚡ Utilizzo rimozione diretta per Windows 11 22H2 o precedenti..."
                Write-StyledMessage Warning "Questo metodo rimuove file e registro direttamente"
                if (Get-UserConfirmation "Confermi rimozione diretta?" 'Y') {
                    $success = Remove-OfficeDirectly
                }
            }
        }

        if ($success) {
            Write-StyledMessage Success "🎉 Rimozione Office completata!"
            return $true
        }
        else {
            Write-StyledMessage Error "Rimozione non completata"
            Write-StyledMessage Info "💡 Puoi provare un metodo alternativo o rimozione manuale"
            return $false
        }
    }

    # MAIN EXECUTION
    Write-Host "⏳ Inizializzazione sistema..." -ForegroundColor Yellow
    Start-Sleep 2
    Write-Host "✅ Sistema pronto`n" -ForegroundColor Green

    try {
        do {
            Write-StyledMessage Info "🎯 Seleziona un'opzione:"
            Write-Host ''
            Write-Host '  [1]  🏢 Installazione Office (Basic Version)' -ForegroundColor White
            Write-Host '  [2]  🔧 Ripara Office' -ForegroundColor White
            Write-Host '  [3]  🗑️ Rimozione completa Office' -ForegroundColor Yellow
            Write-Host '  [0]  ❌ Esci' -ForegroundColor Red
            Write-Host ''

            $choice = Read-Host 'Scelta [0-3]'
            Write-Host ''

            $success = $false
            $operation = ''

            switch ($choice) {
                '1' {
                    $operation = 'Installazione'
                    $success = Start-OfficeInstallation
                }
                '2' {
                    $operation = 'Riparazione'
                    $success = Start-OfficeRepair
                }
                '3' {
                    $operation = 'Rimozione'
                    $success = Start-OfficeUninstall
                }
                '0' {
                    Write-StyledMessage Info "👋 Uscita dal toolkit..."
                    return
                }
                default {
                    Write-StyledMessage Warning "Opzione non valida. Seleziona 0-3."
                    continue
                }
            }

            if ($choice -in @('1', '2', '3')) {
                if ($success) {
                    Write-StyledMessage Success "🎉 $operation completata!"
                    if (Get-UserConfirmation "🔄 Riavviare ora per finalizzare?" 'Y') {
                        if ($SuppressIndividualReboot) {
                            $Global:NeedsFinalReboot = $true
                            Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
                        }
                        else {
                            Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "$operation completata"
                            Restart-Computer -Force
                        }
                    }
                    else {
                        Write-StyledMessage Info "💡 Riavvia manualmente quando possibile"
                    }
                }
                else {
                    Write-StyledMessage Error "$operation non riuscita"
                    Write-StyledMessage Info "💡 Controlla i log per dettagli o contatta il supporto"
                }
                Write-Host "`n" + ('─' * 50) + "`n"
            }

        } while ($choice -ne '0')
    }
    catch {
        Write-StyledMessage Error "Errore critico durante esecuzione OfficeToolkit: $($_.Exception.Message)"
    }
    finally {
        Write-StyledMessage Success "🧹 Pulizia finale..."
        Invoke-SilentRemoval -Path $TempDir -Recurse

        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        Write-StyledMessage Success "🎯 Office Toolkit terminato"
        try { Stop-Transcript | Out-Null } catch {}
    }
}
