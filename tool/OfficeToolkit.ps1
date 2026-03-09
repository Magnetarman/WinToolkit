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
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Start-ToolkitLog -ToolName "OfficeToolkit"
    Show-Header -SubTitle "Office Toolkit"
    $Host.UI.RawUI.WindowTitle = "Office Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    $tempDir = $AppConfig.Paths.OfficeTemp

    # ============================================================================
    # 3. FUNZIONI HELPER LOCALI
    # ============================================================================

    function Invoke-SilentRemoval {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,
            [switch]$Recurse
        )

        if (-not (Test-Path $Path)) { return $false }

        try {
            if ($Recurse) {
                $removeParams = @{
                    Path        = $Path
                    Recurse     = $true
                    Force       = $true
                    ErrorAction = 'SilentlyContinue'
                }
                Remove-Item @removeParams *>$null
            }
            else {
                $removeParams = @{
                    Path        = $Path
                    Force       = $true
                    ErrorAction = 'SilentlyContinue'
                }
                Remove-Item @removeParams *>$null
            }

            Clear-ProgressLine

            return $true
        }
        catch {
            return $false
        }
    }



    function Apply-OfficePostConfig {
        Write-StyledMessage -Type 'Info' -Text "⚙️ Configurazione post-installazione/riparazione Office..."

        # Array di configurazione per Telemetria ed Esperienze Connesse
        $telemetryKeys = @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "disconnectedstate"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "usercontentdisabled"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "downloadcontentdisabled"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 }
        )

        foreach ($reg in $telemetryKeys) {
            if (-not (Test-Path $reg.Path)) { 
                $null = New-Item -Path $reg.Path -Force
            }
            $regParams = @{
                Path  = $reg.Path
                Name  = $reg.Name
                Value = $reg.Value
                Type  = 'DWord'
                Force = $true
            }
            Set-ItemProperty @regParams
        }

        # Fix per disabilitare il popup di Opt-In all'avvio e le notifiche di crash
        $regPathFeedback = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"
        if (-not (Test-Path $regPathFeedback)) { 
            $null = New-Item $regPathFeedback -Force
        }
        $feedbackParams = @{
            Path  = $regPathFeedback
            Name  = "ShownOptIn"
            Value = 1
            Type  = 'DWord'
            Force = $true
        }
        Set-ItemProperty @feedbackParams

        Write-StyledMessage -Type 'Success' -Text "✅ Telemetria e Privacy Office disabilitate in modo profondo"
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

            return $buildNumber -ge 22631 ? "Windows11_23H2_Plus" : ($buildNumber -ge 22000 ? "Windows11_22H2_Or_Older" : "Windows10_Or_Older")
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile rilevare versione Windows: $_"
            return "Unknown"
        }
    }


    function Stop-OfficeProcesses {
        $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
        $closed = 0

        Write-StyledMessage -Type 'Info' -Text "📋 Chiusura processi Office..."
        foreach ($processName in $processes) {
            $runningProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($runningProcesses) {
                try {
                    $runningProcesses | Stop-Process -Force -ErrorAction Stop
                    $closed++
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Impossibile chiudere: $processName"
                }
            }
        }

        if ($closed -gt 0) {
            Write-StyledMessage -Type 'Success' -Text "$closed processi Office chiusi"
        }
    }

    function Invoke-DownloadFile([string]$Url, [string]$OutputPath, [string]$Description) {
        try {
            Write-StyledMessage -Type 'Info' -Text "📥 Download $Description..."
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $OutputPath)
            $webClient.Dispose()

                Write-StyledMessage -Type ($success ? 'Success' : 'Error') -Text ($success ? "Download completato: $Description" : "File non trovato dopo download: $Description")
                return $success
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore download $Description`: $_"
            return $false
        }
    }

    function Start-OfficeInstallation {
        Write-StyledMessage -Type 'Info' -Text "🏢 Avvio installazione Office Basic..."

        try {
            if (-not (Test-Path $tempDir)) {
                $null = New-Item -ItemType Directory -Path $tempDir -Force
            }

            $setupPath = Join-Path $tempDir 'Setup.exe'
            $configPath = Join-Path $tempDir 'Basic.xml'

            $downloads = @(
                @{ Url = $AppConfig.URLs.OfficeSetup; Path = $setupPath; Name = 'Setup Office' },
                @{ Url = $AppConfig.URLs.OfficeBasicConfig; Path = $configPath; Name = 'Configurazione Basic' }
            )

            foreach ($download in $downloads) {
                if (-not (Invoke-DownloadFile $download.Url $download.Path $download.Name)) {
                    return $false
                }
            }

            Write-StyledMessage -Type 'Info' -Text "🚀 Avvio processo installazione..."
            $arguments = "/configure `"$configPath`""

            $processTimeoutSeconds = 86400    # Timer di 24 ore in secondi.
            $result = Invoke-WithSpinner -Activity "Installazione Office Basic" -Process -Action {
                $procParams = @{
                    FilePath         = $setupPath
                    ArgumentList     = $arguments
                    WorkingDirectory = $tempDir
                    PassThru         = $true
                    WindowStyle      = 'Hidden'
                    ErrorAction      = 'Stop'
                }
                Start-Process @procParams
            } -TimeoutSeconds $processTimeoutSeconds -UpdateInterval 1000

            if (-not $result.Success) {
                Write-StyledMessage -Type 'Error' -Text "Installazione fallita o scaduta (fase di setup iniziale)"
                return $false
            }

            # L'attesa è già gestita da Invoke-WithSpinner sul processo Setup.exe.
            # Il ciclo do-while su OfficeClickToRun è stato rimosso per evitare freeze.

            # Configurazione post-installazione centralizzata
            Apply-OfficePostConfig

            Write-StyledMessage -Type 'Success' -Text "Installazione completata"
            Write-StyledMessage -Type 'Info' -Text "Riavvio non necessario"
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante installazione Office: $($_.Exception.Message)"
            return $false
        }
        finally {
            Invoke-SilentRemoval -Path $tempDir -Recurse
        }
    }

    function Start-OfficeRepair {
        Write-StyledMessage -Type 'Info' -Text "🔧 Avvio riparazione Office..."
        Stop-OfficeProcesses

        Write-StyledMessage -Type 'Info' -Text "🧹 Pulizia cache Office..."
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
            Write-StyledMessage -Type 'Success' -Text "$cleanedCount cache eliminate"
        }

        $officeClient = (Test-Path "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe") ? "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe" : "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"

        try {
            $processTimeoutSeconds = 86400 # Attesa indefinita (24 ore)
            Write-StyledMessage -Type 'Info' -Text "🔧 Avvio riparazione rapida (offline)..."
            $argumentsQuick = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=QuickRepair DisplayLevel=True"

            $resultQuick = Invoke-WithSpinner -Activity "Riparazione Rapida Office (Offline)" -Process -Action {
                $procParams = @{
                    FilePath     = $officeClient
                    ArgumentList = $argumentsQuick
                    PassThru     = $true
                    ErrorAction  = 'Stop'
                }
                # Avvia il processo e lo restituisce direttamente a Invoke-WithSpinner
                return Start-Process @procParams
            } -TimeoutSeconds $processTimeoutSeconds -UpdateInterval 1000

            # Ripristina configurazione post-riparazione (la riparazione può sovrascrivere le impostazioni)
            Apply-OfficePostConfig
            Write-StyledMessage -Type 'Success' -Text "🎉 Riparazione Office completata!"
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante riparazione Office: $($_.Exception.Message)"
            # Tentativo riparazione online come fallback
            try {
                Write-StyledMessage -Type 'Info' -Text "🌐 Tentativo riparazione completa (online) come fallback..."
                $processTimeoutSeconds = 86400
                $argumentsFull = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True"

                $resultFull = Invoke-WithSpinner -Activity "Riparazione Completa Office (Online)" -Process -Action {
                    $procParams = @{
                        FilePath     = $officeClient
                        ArgumentList = $argumentsFull
                        PassThru     = $true
                        ErrorAction  = 'Stop'
                    }
                    # Avvia il processo e lo restituisce direttamente a Invoke-WithSpinner
                    return Start-Process @procParams
                } -TimeoutSeconds $processTimeoutSeconds -UpdateInterval 1000

                Apply-OfficePostConfig
                Write-StyledMessage -Type 'Success' -Text "🎉 Riparazione Office completata!"
                return $true
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Errore anche durante riparazione online: $($_.Exception.Message)"
                return $false
            }
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
        Write-StyledMessage -Type 'Info' -Text "🔧 Avvio rimozione diretta Office..."

        try {
            # Metodo 1: Rimozione pacchetti
            Write-StyledMessage -Type 'Info' -Text "📋 Ricerca installazioni Office..."

            $officePackages = Get-Package -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*Microsoft Office*" -or $_.Name -like "*Microsoft 365*" -or $_.Name -like "*Office*" }

            if ($officePackages) {
                Write-StyledMessage -Type 'Info' -Text "Trovati $($officePackages.Count) pacchetti Office"
                foreach ($package in $officePackages) {
                    try {
                        $null = Uninstall-Package -Name $package.Name -Force -ErrorAction Stop
                        Write-StyledMessage -Type 'Success' -Text "Rimosso: $($package.Name)"
                    }
                    catch {}
                }
            }

            # Metodo 2: Rimozione tramite registro
            Write-StyledMessage -Type 'Info' -Text "🔍 Ricerca nel registro..."

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
                                $spinnerActivity = "Rimozione: $($item.DisplayName)"
                                $null = Invoke-WithSpinner -Activity $spinnerActivity -Process -Action {
                                    $procParams = @{
                                        FilePath     = 'msiexec.exe'
                                        ArgumentList = @('/x', $productCode, '/qn', '/norestart')
                                        PassThru     = $true
                                        WindowStyle  = 'Hidden'
                                        ErrorAction  = 'Stop'
                                    }
                                    Start-Process @procParams
                                } -TimeoutSeconds 1800 -UpdateInterval 1000
                            }
                            catch {}
                        }
                    }
                }
                catch {}
            }

            # Metodo 3: Stop servizi Office
            Write-StyledMessage -Type 'Info' -Text "🛑 Arresto servizi Office..."

            $officeServices = @('ClickToRunSvc', 'OfficeSvc', 'OSE')
            $stoppedServices = 0
            foreach ($serviceName in $officeServices) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    try {
                        Stop-Service -Name $serviceName -Force -ErrorAction Stop
                        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
                        Write-StyledMessage -Type 'Success' -Text "Servizio arrestato: $serviceName"
                        $stoppedServices++
                    }
                    catch {}
                }
            }

            # Metodo 4: Pulizia cartelle Office
            Write-StyledMessage -Type 'Info' -Text "🧹 Pulizia cartelle Office..."

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
                Write-StyledMessage -Type 'Success' -Text "$($folderResult.Count) cartelle Office rimosse"
            }

            if ($folderResult.Failed.Count -gt 0) {
                Write-StyledMessage -Type 'Warning' -Text "Impossibile rimuovere $($folderResult.Failed.Count) cartelle (potrebbero essere in uso)"
            }

            # Metodo 5: Pulizia registro Office
            Write-StyledMessage -Type 'Info' -Text "🔧 Pulizia registro Office..."

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
                Write-StyledMessage -Type 'Success' -Text "$($regResult.Count) chiavi registro Office rimosse"
            }

            # Metodo 6: Pulizia attività pianificate
            Write-StyledMessage -Type 'Info' -Text "📅 Pulizia attività pianificate..."

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
                    Write-StyledMessage -Type 'Success' -Text "$tasksRemoved attività Office rimosse"
                }
            }
            catch {}

            # Metodo 7: Rimozione collegamenti
            Write-StyledMessage -Type 'Info' -Text "🖥️ Rimozione collegamenti Office..."

            $officeShortcuts = @(
                "Microsoft Word*.lnk", "Microsoft Excel*.lnk", "Microsoft PowerPoint*.lnk",
                "Microsoft Outlook*.lnk", "Microsoft OneNote*.lnk", "Microsoft Access*.lnk",
                "Office*.lnk", "Word*.lnk", "Excel*.lnk", "PowerPoint*.lnk", "Outlook*.lnk"
            )

            $desktopPaths = @(
                $AppConfig.Paths.Desktop,
                "$env:PUBLIC\Desktop",
                "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs"
            )

            $shortcutsRemoved = 0
            foreach ($desktopPath in $desktopPaths) {
                if (Test-Path $desktopPath) {
                    foreach ($shortcut in $officeShortcuts) {
                        $gciParams = @{
                            Path        = $desktopPath
                            Filter      = $shortcut
                            Recurse     = $true
                            ErrorAction = 'SilentlyContinue'
                        }
                        $shortcutFiles = Get-ChildItem @gciParams
                        foreach ($file in $shortcutFiles) {
                            if (Invoke-SilentRemoval -Path $file.FullName) {
                                $shortcutsRemoved++
                            }
                        }
                    }
                }
            }

            if ($shortcutsRemoved -gt 0) {
                Write-StyledMessage -Type 'Success' -Text "$shortcutsRemoved collegamenti Office rimossi"
            }

            # Metodo 8: Pulizia residui aggiuntivi
            Write-StyledMessage -Type 'Info' -Text "💽 Pulizia residui Office..."

            $additionalPaths = @(
                "$env:LOCALAPPDATA\Microsoft\OneDrive",
                "$env:APPDATA\Microsoft\OneDrive",
                "$env:TEMP\Office*",
                "$env:TEMP\MSO*"
            )

            $residualsResult = Remove-ItemsSilently -Paths $additionalPaths -ItemType "residuo"

            Write-StyledMessage -Type 'Success' -Text "✅ Rimozione diretta completata"
            Write-StyledMessage -Type 'Info' -Text "📊 Riepilogo: $($folderResult.Count) cartelle, $($regResult.Count) chiavi registro, $shortcutsRemoved collegamenti, $tasksRemoved attività rimosse"

            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante rimozione diretta Office: $($_.Exception.Message)"
            return $false
        }
    }

    function Start-OfficeUninstallWithSaRA {
        try {
            if (-not (Test-Path $tempDir)) {
                $null = New-Item -ItemType Directory -Path $tempDir -Force
            }

            $saraUrl = $AppConfig.URLs.SaRAInstaller
            $saraZipPath = Join-Path $tempDir 'SaRA.zip'

            if (-not (Invoke-DownloadFile $saraUrl $saraZipPath 'Microsoft SaRA')) {
                return $false
            }

            Write-StyledMessage -Type 'Info' -Text "📦 Estrazione SaRA..."
            try {
                Expand-Archive -Path $saraZipPath -DestinationPath $tempDir -Force
                Write-StyledMessage -Type 'Success' -Text "Estrazione completata"
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Errore durante estrazione archivio SaRA: $($_.Exception.Message)"
                return $false
            }

            $gciParamsExe = @{
                Path        = $tempDir
                Filter      = "SaRAcmd.exe"
                Recurse     = $true
                ErrorAction = 'SilentlyContinue'
            }
            $saraExe = Get-ChildItem @gciParamsExe | Select-Object -First 1
            if (-not $saraExe) {
                Write-StyledMessage -Type 'Error' -Text "SaRAcmd.exe non trovato"
                return $false
            }

            Write-StyledMessage -Type 'Info' -Text "🚀 Rimozione tramite SaRA..."
            Write-StyledMessage -Type 'Warning' -Text "⏰ Questa operazione può richiedere alcuni minuti"

            $arguments = '-S OfficeScrubScenario -AcceptEula -OfficeVersion All'

            try {
                $processTimeoutSeconds = 86400 # Attesa indefinita (24 ore)
                $result = Invoke-WithSpinner -Activity "Rimozione Office tramite SaRA" -Process -Action {
                    $procParams = @{
                        FilePath     = $saraExe.FullName
                        ArgumentList = $arguments
                        Verb         = 'RunAs'
                        PassThru     = $true
                        ErrorAction  = 'Stop'
                    }
                    Start-Process @procParams
                } -TimeoutSeconds $processTimeoutSeconds -UpdateInterval 1000

                if ($result.ExitCode -eq 0) {
                    Write-StyledMessage -Type 'Success' -Text "✅ SaRA completato con successo"
                    return $true
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "SaRA terminato con codice: $($result.ExitCode)"
                    Write-StyledMessage -Type 'Info' -Text "💡 Tentativo metodo alternativo..."
                    return Remove-OfficeDirectly
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore durante esecuzione SaRA: $($_.Exception.Message)"
                Write-StyledMessage -Type 'Info' -Text "💡 Passaggio a metodo alternativo..."
                return Remove-OfficeDirectly
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore durante processo SaRA: $($_.Exception.Message)"
            return $false
        }
        finally {
            Invoke-SilentRemoval -Path $tempDir -Recurse
        }
    }

    function Start-OfficeUninstall {
        Write-StyledMessage -Type 'Warning' -Text "🗑️ Avvio rimozione completa Microsoft Office..."

        Stop-OfficeProcesses

        Write-StyledMessage -Type 'Info' -Text "🔍 Rilevamento versione Windows..."
        $windowsVersion = Get-WindowsVersion
        Write-StyledMessage -Type 'Info' -Text "🎯 Versione rilevata: $windowsVersion"

        $success = $false

        switch ($windowsVersion) {
            'Windows11_23H2_Plus' {
                Write-StyledMessage -Type 'Info' -Text "🚀 Utilizzo metodo SaRA per Windows 11 23H2+..."
                $success = Start-OfficeUninstallWithSaRA
            }
            default {
                Write-StyledMessage -Type 'Info' -Text "⚡ Utilizzo rimozione diretta per Windows 11 22H2 o precedenti..."
                $success = Remove-OfficeDirectly
            }
        }

        if ($success) {
            Write-StyledMessage -Type 'Success' -Text "🎉 Rimozione Office completata!"
            return $true
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Rimozione non completata"
            Write-StyledMessage -Type 'Info' -Text "💡 Puoi provare un metodo alternativo o rimozione manuale"
            return $false
        }
    }

    # MAIN EXECUTION
    Write-StyledMessage -Type 'Progress' -Text "⏳ Inizializzazione sistema..."
    Start-Sleep 2
    Write-StyledMessage -Type 'Success' -Text "✅ Sistema pronto"

    $needsReboot = $false
    $lastOperation = ''

    try {
        do {
            Write-StyledMessage -Type 'Info' -Text "🎯 Seleziona un'opzione:"
            Write-StyledMessage -Type 'Info' -Text "  [1]  🏢 Installazione Office (Basic Version)"
            Write-StyledMessage -Type 'Info' -Text "  [2]  🔧 Ripara Office"
            Write-StyledMessage -Type 'Info' -Text "  [3]  🗑️ Rimozione completa Office"
            Write-StyledMessage -Type 'Info' -Text "  [0]  ❌ Esci"

            $choice = Read-Host 'Scelta [0-3]'

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
                    Write-StyledMessage -Type 'Info' -Text "👋 Uscita dal toolkit..."
                    break
                }
                default {
                    Write-StyledMessage -Type 'Warning' -Text "Opzione non valida. Seleziona 0-3."
                    continue
                }
            }

            if ($choice -in @('1', '2', '3')) {
                if ($success) {
                    if ($choice -ne '1') {
                        Write-StyledMessage -Type 'Success' -Text "🎉 $operation completata!"
                        # Automazione completa: imposta il riavvio necessario senza prompt interattivo
                        $needsReboot = $true
                        $lastOperation = $operation
                        Write-StyledMessage -Type 'Info' -Text "💡 Il sistema verrà riavviato automaticamente alla fine del processo."
                    }
                }
                else {
                    Write-StyledMessage -Type 'Error' -Text "$operation non riuscita"
                    Write-StyledMessage -Type 'Info' -Text "💡 Controlla i log per dettagli o contatta il supporto"
                }
                Write-StyledMessage -Type 'Info' -Text ('─' * 50)
            }

        } while ($choice -ne '0')
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore critico durante esecuzione OfficeToolkit: $($_.Exception.Message)"
        Write-ToolkitLog -Level ERROR -Message "Errore critico in OfficeToolkit" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text "🧹 Pulizia finale..."
        Invoke-SilentRemoval -Path $tempDir -Recurse

        Write-StyledMessage -Type 'Success' -Text "🎯 Office Toolkit terminato"
        Write-ToolkitLog -Level INFO -Message "OfficeToolkit sessione terminata."
    }

    # ============================================================================
    # 4. GESTIONE RIAVVIO — SEMPRE ULTIMA
    # ============================================================================
    if ($needsReboot) {
        if ($SuppressIndividualReboot) {
            $Global:NeedsFinalReboot = $true
            Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
        }
        else {
            if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "$lastOperation completata") {
                Restart-Computer -Force
            }
        }
    }
}
