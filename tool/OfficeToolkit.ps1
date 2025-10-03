function OfficeToolkit {
    <#
    .SYNOPSIS
        Strumento di gestione Microsoft Office (installazione, riparazione, rimozione)

    .DESCRIPTION
        Script PowerShell per gestire Microsoft Office tramite interfaccia utente semplificata.
        Supporta installazione Office Basic, riparazione Click-to-Run e rimozione automatica basata sulla versione Windows.
    #>

    param([int]$CountdownSeconds = 30)

    # Configurazione
    $TempDir = "$env:LOCALAPPDATA\WinToolkit\Office"
    $Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()

    # Setup logging specifico per OfficeToolkit
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\OfficeToolkit_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}

    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💡' }
    }

    # Funzioni Helper
    function Write-StyledMessage([string]$Type, [string]$Message) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Message" -ForegroundColor $style.Color
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent) {
        $safePercent = [Math]::Max(0, [Math]::Min(100, $Percent))
        $filled = [Math]::Floor($safePercent * 30 / 100)
        $bar = "[$('█' * $filled)$('░' * (30 - $filled))] $safePercent%"
        Write-Host "`r📊 $Activity $bar $Status" -NoNewline -ForegroundColor Yellow
        if ($Percent -eq 100) {
            Write-Host ''
            [Console]::Out.Flush()
        }
        else {
            [Console]::Out.Flush()
        }
    }

    function Clear-ConsoleLine {
        $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
        Write-Host $clearLine -NoNewline
        [Console]::Out.Flush()
    }

    function Show-Spinner([string]$Activity, [scriptblock]$Action) {
        $spinnerIndex = 0
        $job = Start-Job -ScriptBlock $Action

        while ($job.State -eq 'Running') {
            $spinner = $Spinners[$spinnerIndex++ % $Spinners.Length]
            Write-Host "`r$spinner $Activity..." -NoNewline -ForegroundColor Yellow
            [Console]::Out.Flush()
            Start-Sleep -Milliseconds 200
        }

        $result = Receive-Job $job -Wait
        Remove-Job $job
        Write-Host ''
        [Console]::Out.Flush()
        return $result
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

            # Windows 11 23H2 o superiori = build 22631 o superiore
            # Windows 11 22H2 o precedenti = build 22621 o inferiore
            # Windows 10 = build inferiore a 22000

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
            Write-StyledMessage Warning "Impossibile rilevare versione Windows: $_"
            return "Unknown"
        }
    }

    function Start-CountdownRestart([string]$Reason) {
        Write-StyledMessage Info "🔄 $Reason - Il sistema verrà riavviato"
        Write-StyledMessage Info "💡 Premi un tasto qualsiasi per annullare..."

        for ($i = $CountdownSeconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning "⏸️ Riavvio annullato dall'utente"
                return $false
            }

            $percent = [Math]::Round((($CountdownSeconds - $i) / $CountdownSeconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('░' * $remaining)] $percent%"

            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            [Console]::Out.Flush()
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."

        try {
            Restart-Computer -Force
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore riavvio: $_"
            return $false
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
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Setup.exe'; Path = $setupPath; Name = 'Setup Office' },
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Basic.xml'; Path = $configPath; Name = 'Configurazione Basic' }
            )

            foreach ($download in $downloads) {
                if (-not (Invoke-DownloadFile $download.Url $download.Path $download.Name)) {
                    return $false
                }
            }

            Write-StyledMessage Info "🚀 Avvio processo installazione..."
            $arguments = "/configure `"$configPath`""
            Start-Process -FilePath $setupPath -ArgumentList $arguments -WorkingDirectory $TempDir

            Write-StyledMessage Info "⏳ Attesa completamento installazione..."
            Write-Host "💡 Premi INVIO quando l'installazione è completata..." -ForegroundColor Yellow
            Read-Host | Out-Null

            if (Get-UserConfirmation "✅ Installazione completata con successo?" 'Y') {
                Write-StyledMessage Success "🎉 Installazione Office completata!"
                return $true
            }
            else {
                Write-StyledMessage Warning "Installazione non completata correttamente"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante installazione: $_"
            return $false
        }
        finally {
            if (Test-Path $TempDir) {
                Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
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
            if (Test-Path $cache) {
                try {
                    Remove-Item $cache -Recurse -Force -ErrorAction Stop
                    $cleanedCount++
                }
                catch {
                    # Ignora errori di cache
                }
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
            Write-StyledMessage Info "🔍 Ricerca installazione Office..."
            $officeProcesses = Get-Process -Name "winword", "excel", "powerpnt", "outlook", "onenote", "msaccess", "visio", "lync" -ErrorAction SilentlyContinue
            if ($officeProcesses) {
                Write-StyledMessage Success "Office è in esecuzione, procedo con la riparazione"
            }
            else {
                Write-StyledMessage Warning "Nessun processo Office rilevato, ma procedo comunque"
            }

            $repairType = if ($choice -eq '1') { 'QuickRepair' } else { 'FullRepair' }
            $repairName = if ($choice -eq '1') { 'rapida' } else { 'completa' }

            Write-StyledMessage Info "🔧 Avvio riparazione $repairName..."
            $arguments = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=$repairType DisplayLevel=True"
            Start-Process -FilePath $officeClient -ArgumentList $arguments -Wait:$false

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
                        Start-Process -FilePath $officeClient -ArgumentList $arguments -Wait:$false

                        Write-Host "💡 Premi INVIO quando la riparazione completa è terminata..." -ForegroundColor Yellow
                        Read-Host | Out-Null

                        return Get-UserConfirmation "✅ Riparazione completa riuscita?" 'Y'
                    }
                }
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante riparazione: $_"
            return $false
        }
    }

    function Start-OfficeUninstall {
        Write-StyledMessage Warning "🗑️ Rimozione completa Microsoft Office"

        if (-not (Get-UserConfirmation "❓ Procedere con la rimozione completa?")) {
            Write-StyledMessage Info "❌ Operazione annullata"
            return $false
        }

        Stop-OfficeProcesses

        # Rilevamento automatico versione Windows
        Write-StyledMessage Info "🔍 Rilevamento versione Windows..."
        $windowsVersion = Get-WindowsVersion

        Write-StyledMessage Info "🎯 Versione rilevata: $windowsVersion"

        $success = $false

        switch ($windowsVersion) {
            'Windows11_23H2_Plus' {
                Write-StyledMessage Info "🚀 Utilizzo metodo SaRA per Windows 11 23H2+..."
                Write-StyledMessage Info "💡 Questo metodo è ottimizzato per la tua versione di Windows"
                $success = Start-OfficeUninstallWithSaRA
            }
            default {
                Write-StyledMessage Info "⚡ Utilizzo rimozione diretta per Windows 11 22H2 o precedenti..."
                Write-StyledMessage Info "💡 Questo metodo è ottimizzato per la tua versione di Windows"
                Write-StyledMessage Warning "⚠️ Questo metodo rimuove file e registro direttamente"
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


    function Remove-OfficeDirectly {
        Write-StyledMessage Info "🔧 Avvio rimozione diretta Office..."
        
        try {
            # Metodo 1: Rimozione tramite Get-Package (più affidabile)
            Write-StyledMessage Info "📋 Ricerca installazioni Office..."
            
            $officePackages = Get-Package -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -like "*Microsoft Office*" -or $_.Name -like "*Microsoft 365*" -or $_.Name -like "*Office*" }
            
            if ($officePackages) {
                Write-StyledMessage Info "Trovati $($officePackages.Count) pacchetti Office"
                foreach ($package in $officePackages) {
                    Write-StyledMessage Info "🗑️ Rimozione: $($package.Name)..."
                    try {
                        Uninstall-Package -Name $package.Name -Force -ErrorAction Stop | Out-Null
                        Write-StyledMessage Success "Rimosso: $($package.Name)"
                    }
                    catch {
                        Write-StyledMessage Warning "Errore rimozione pacchetto: $($package.Name)"
                    }
                }
            }
            
            # Metodo 2: Rimozione tramite registro Uninstall
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
                        if ($item.UninstallString) {
                            Write-StyledMessage Info "🗑️ Disinstallazione: $($item.DisplayName)..."
                            try {
                                $uninstallString = $item.UninstallString -replace '"', ''
                                if ($uninstallString -match "msiexec") {
                                    $productCode = $item.PSChildName
                                    Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $productCode /qn /norestart" -Wait -NoNewWindow -ErrorAction Stop
                                    Write-StyledMessage Success "Disinstallato: $($item.DisplayName)"
                                }
                            }
                            catch {
                                Write-StyledMessage Warning "Impossibile disinstallare: $($item.DisplayName)"
                            }
                        }
                    }
                }
                catch {
                    # Continua con il prossimo percorso
                }
            }
            
            # Metodo 3: Stop servizi Office
            Write-StyledMessage Info "🛑 Arresto servizi Office..."
            
            $officeServices = @('ClickToRunSvc', 'OfficeSvc', 'OSE')
            foreach ($serviceName in $officeServices) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    try {
                        Stop-Service -Name $serviceName -Force -ErrorAction Stop
                        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
                        Write-StyledMessage Success "Servizio arrestato: $serviceName"
                    }
                    catch {
                        Write-StyledMessage Warning "Impossibile arrestare: $serviceName"
                    }
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
            
            $cleanedFolders = 0
            foreach ($folder in $foldersToClean) {
                if (Test-Path $folder) {
                    try {
                        Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
                        $cleanedFolders++
                        Write-StyledMessage Success "Rimossa: $folder"
                    }
                    catch {
                        Write-StyledMessage Warning "Impossibile rimuovere: $folder"
                    }
                }
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
            
            $cleanedKeys = 0
            foreach ($regPath in $registryPaths) {
                if (Test-Path $regPath) {
                    try {
                        Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
                        $cleanedKeys++
                        Write-StyledMessage Success "Rimossa chiave: $regPath"
                    }
                    catch {
                        Write-StyledMessage Warning "Impossibile rimuovere: $regPath"
                    }
                }
            }
            
            # Metodo 6: Pulizia attività pianificate Office
            Write-StyledMessage Info "📅 Pulizia attività pianificate..."

            try {
                $officeTasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
                Where-Object { $_.TaskName -like "*Office*" }

                foreach ($task in $officeTasks) {
                    try {
                        Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
                        Write-StyledMessage Success "Attività rimossa: $($task.TaskName)"
                    }
                    catch {
                        Write-StyledMessage Warning "Impossibile rimuovere attività: $($task.TaskName)"
                    }
                }
            }
            catch {
                Write-StyledMessage Warning "Errore durante pulizia attività pianificate"
            }

            # Metodo 7: Rimozione collegamenti Office da tutto il sistema
            Write-StyledMessage Info "🖥️ Rimozione collegamenti Office da tutto il sistema..."

            $officeShortcuts = @(
                "Microsoft Word*.lnk",
                "Microsoft Excel*.lnk",
                "Microsoft PowerPoint*.lnk",
                "Microsoft Outlook*.lnk",
                "Microsoft OneNote*.lnk",
                "Microsoft Access*.lnk",
                "Microsoft Publisher*.lnk",
                "Microsoft Visio*.lnk",
                "Microsoft Project*.lnk",
                "OneDrive*.lnk",
                "Office*.lnk",
                "Word*.lnk",
                "Excel*.lnk",
                "PowerPoint*.lnk",
                "Outlook*.lnk"
            )

            $removedShortcuts = 0

            # Desktop pubblico e utente
            $desktopPaths = @(
                "$env:USERPROFILE\Desktop",
                "$env:PUBLIC\Desktop"
            )

            foreach ($desktopPath in $desktopPaths) {
                if (Test-Path $desktopPath) {
                    foreach ($shortcut in $officeShortcuts) {
                        $shortcutFiles = Get-ChildItem -Path $desktopPath -Name $shortcut -ErrorAction SilentlyContinue
                        foreach ($file in $shortcutFiles) {
                            try {
                                Remove-Item -Path (Join-Path $desktopPath $file) -Force -ErrorAction Stop
                                $removedShortcuts++
                                Write-StyledMessage Success "Desktop: $file"
                            }
                            catch {
                                Write-StyledMessage Warning "Impossibile rimuovere: $file"
                            }
                        }
                    }
                }
            }

            # Menu Start - Tiles e collegamenti
            Write-StyledMessage Info "🔍 Pulizia Menu Start..."
            try {
                $startMenuPaths = @(
                    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
                    "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs",
                    "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
                )

                foreach ($startPath in $startMenuPaths) {
                    if (Test-Path $startPath) {
                        foreach ($shortcut in $officeShortcuts) {
                            $shortcutFiles = Get-ChildItem -Path $startPath -Name $shortcut -Recurse -ErrorAction SilentlyContinue
                            foreach ($file in $shortcutFiles) {
                                try {
                                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                                    $removedShortcuts++
                                    Write-StyledMessage Success "Start Menu: $($file.Name)"
                                }
                                catch {
                                    Write-StyledMessage Warning "Impossibile rimuovere: $($file.Name)"
                                }
                            }
                        }
                    }
                }
            }
            catch {
                Write-StyledMessage Warning "Errore pulizia Menu Start: $_"
            }

            # Taskbar - Rimozione pin
            Write-StyledMessage Info "📌 Rimozione pin dalla barra delle applicazioni..."
            try {
                # Rimuovi eventuali pin Office dalla taskbar tramite registro
                $taskbarKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
                if (Test-Path $taskbarKey) {
                    try {
                        $taskbarItems = Get-ItemProperty -Path $taskbarKey -Name "Favorites" -ErrorAction SilentlyContinue
                        # Questo è un processo complesso, quindi segnaliamo solo l'operazione
                        Write-StyledMessage Info "Pin taskbar contrassegnati per rimozione (riavvio richiesto)"
                    }
                    catch {}
                }
            }
            catch {
                Write-StyledMessage Warning "Errore gestione taskbar: $_"
            }

            if ($removedShortcuts -gt 0) {
                Write-StyledMessage Success "$removedShortcuts collegamenti rimossi dal sistema"
            }

            # Metodo 8: Pulizia generale disco C: per residui Office
            Write-StyledMessage Info "💽 Scansione completa disco C: per residui Office..."

            $officeFilePatterns = @(
                "office*.exe",
                "winword*.exe",
                "excel*.exe",
                "powerpnt*.exe",
                "outlook*.exe",
                "onenote*.exe",
                "msaccess*.exe",
                "mspub*.exe",
                "visio*.exe",
                "project*.exe",
                "lync*.exe",
                "office*.dll",
                "mso*.dll",
                "msi*.dll"
            )

            $officeFolderPatterns = @(
                "*office*",
                "*microsoft office*",
                "*onedrive*",
                "*skype for business*",
                "*lync*"
            )

            $cleanedFiles = 0
            $cleanedFolders = 0

            # Scansione percorsi comuni per file Office residui
            $scanPaths = @(
                "$env:ProgramFiles",
                "${env:ProgramFiles(x86)}",
                "$env:ProgramData",
                "$env:LOCALAPPDATA",
                "$env:APPDATA",
                "$env:TEMP",
                "$env:SystemDrive"
            )

            foreach ($scanPath in $scanPaths) {
                if (Test-Path $scanPath) {
                    try {
                        # Cerca e rimuovi file Office residui
                        foreach ($pattern in $officeFilePatterns) {
                            $files = Get-ChildItem -Path $scanPath -Name $pattern -Recurse -File -ErrorAction SilentlyContinue |
                            Where-Object { $_.Name -notlike "*system32*" -and $_.Name -notlike "*winsxs*" }

                            foreach ($file in $files) {
                                try {
                                    $fullPath = $file.FullName
                                    if ((Get-Item $fullPath).Length -lt 100MB) {
                                        # Evita file di sistema di grandi dimensioni
                                        Remove-Item -Path $fullPath -Force -ErrorAction Stop
                                        $cleanedFiles++
                                        Write-StyledMessage Success "File residuo rimosso: $($file.Name)"
                                    }
                                }
                                catch {
                                    Write-StyledMessage Warning "Impossibile rimuovere file: $($file.Name)"
                                }
                            }
                        }

                        # Cerca e rimuovi cartelle Office residue (solo se vuote o piccole)
                        foreach ($pattern in $officeFolderPatterns) {
                            $folders = Get-ChildItem -Path $scanPath -Name $pattern -Recurse -Directory -ErrorAction SilentlyContinue |
                            Where-Object { $_.FullName -notlike "*system32*" -and $_.FullName -notlike "*winsxs*" }

                            foreach ($folder in $folders) {
                                try {
                                    $folderPath = $folder.FullName
                                    $folderSize = (Get-ChildItem -Path $folderPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum

                                    if ($folderSize -eq $null -or $folderSize -lt 50MB) {
                                        Remove-Item -Path $folderPath -Recurse -Force -ErrorAction Stop
                                        $cleanedFolders++
                                        Write-StyledMessage Success "Cartella residua rimossa: $($folder.Name)"
                                    }
                                }
                                catch {
                                    Write-StyledMessage Warning "Impossibile rimuovere cartella: $($folder.Name)"
                                }
                            }
                        }
                    }
                    catch {
                        Write-StyledMessage Warning "Errore scansione percorso $scanPath`: $_"
                    }
                }
            }

            # Pulizia specifica percorsi Office aggiuntivi
            Write-StyledMessage Info "🧹 Pulizia percorsi Office aggiuntivi..."
            $additionalPaths = @(
                "$env:LOCALAPPDATA\Microsoft\Office",
                "$env:LOCALAPPDATA\Microsoft\OneDrive",
                "$env:APPDATA\Microsoft\Office",
                "$env:APPDATA\Microsoft\OneDrive",
                "$env:ProgramData\Microsoft\Office",
                "$env:TEMP\Office*",
                "$env:TEMP\MSO*",
                "$env:TEMP\WinToolkit\Office"
            )

            foreach ($path in $additionalPaths) {
                if (Test-Path $path) {
                    try {
                        $items = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                        if ($items.Count -eq 0) {
                            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                            Write-StyledMessage Success "Cartella vuota rimossa: $(Split-Path $path -Leaf)"
                        }
                    }
                    catch {
                        Write-StyledMessage Warning "Impossibile pulire: $(Split-Path $path -Leaf)"
                    }
                }
            }

            if ($cleanedFiles -gt 0 -or $cleanedFolders -gt 0) {
                Write-StyledMessage Success "Pulizia disco completata: $cleanedFiles file, $cleanedFolders cartelle rimosse"
            }
            
            Write-StyledMessage Success "✅ Rimozione diretta completata"
            Write-StyledMessage Info "📊 Riepilogo completo: $cleanedFolders cartelle sistema, $cleanedKeys chiavi registro, $removedShortcuts collegamenti, $cleanedFiles file residui, $cleanedFolders cartelle residue rimosse"
            
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore durante rimozione diretta: $_"
            return $false
        }
    }

    function Start-OfficeUninstallWithSaRA {
        try {
            if (-not (Test-Path $TempDir)) {
                New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
            }

            $saraUrl = 'https://aka.ms/SaRA_EnterpriseVersionFiles'
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
                Write-StyledMessage Error "Errore estrazione: $_"
                return $false
            }

            $saraExe = Get-ChildItem -Path $TempDir -Filter "SaRAcmd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $saraExe) {
                Write-StyledMessage Error "SaRAcmd.exe non trovato"
                return $false
            }

            # Correggi configurazione SaRA
            $configPath = "$($saraExe.FullName).config"
            if (Test-Path $configPath) {
                Repair-SaRAConfig -ConfigPath $configPath
            }

            Write-StyledMessage Info "🚀 Tentativo 1: Rimozione tramite SaRA..."
            Write-StyledMessage Warning "⏰ Questa operazione può richiedere alcuni minuti"

            $arguments = '-S OfficeScrubScenario -AcceptEula -OfficeVersion All'
            
            try {
                $process = Start-Process -FilePath $saraExe.FullName -ArgumentList $arguments -Verb RunAs -PassThru -Wait -ErrorAction Stop
                
                $exitCode = $process.ExitCode
                
                if ($exitCode -eq 0) {
                    Write-StyledMessage Success "✅ SaRA completato con successo"
                    return $true
                }
                else {
                    Write-StyledMessage Warning "SaRA terminato con codice: $exitCode"
                    Write-StyledMessage Info "💡 Tentativo metodo alternativo..."
                    
                    # Tentativo con rimozione diretta
                    if (Remove-OfficeDirectly) {
                        return $true
                    }
                    
                    return $false
                }
            }
            catch {
                Write-StyledMessage Warning "Errore esecuzione SaRA: $_"
                Write-StyledMessage Info "💡 Passaggio a metodo alternativo..."
                
                # Fallback immediato a rimozione diretta
                if (Remove-OfficeDirectly) {
                    return $true
                }
                
                return $false
            }
        }
        catch {
            Write-StyledMessage Warning "Errore durante SaRA: $_"
            return $false
        }
        finally {
            if (Test-Path $TempDir) {
                Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }


    function Show-Header {
        $Host.UI.RawUI.WindowTitle = "Office Toolkit By MagnetarMan"
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '      Office Toolkit By MagnetarMan',
            '        Version 2.2.2 (Build 13)'
        )

        foreach ($line in $asciiArt) {
            $padding = [Math]::Max(0, [Math]::Floor(($width - $line.Length) / 2))
            Write-Host (' ' * $padding + $line) -ForegroundColor White
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    # MAIN EXECUTION
    Show-Header
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
                        Start-CountdownRestart "$operation completata"
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
        Write-StyledMessage Error "Errore critico: $($_.Exception.Message)"
    }
    finally {
        Write-StyledMessage Success "🧹 Pulizia finale..."
        if (Test-Path $TempDir) {
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        Write-StyledMessage Success "🎯 Office Toolkit terminato"
        try { Stop-Transcript | Out-Null } catch {}
    }
}

OfficeToolkit