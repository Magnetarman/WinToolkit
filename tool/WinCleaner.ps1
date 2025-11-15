function WinCleaner {
    <#
    .SYNOPSIS
        Script automatico per la pulizia completa del sistema Windows.

    .DESCRIPTION
        Questo script esegue una pulizia completa e automatica del sistema Windows,
        utilizzando cleanmgr.exe con configurazione automatica (/sageset e /sagerun)
        e pulendo manualmente tutti i componenti specificati.

        POLITICA ESCLUSIONI VITALI:
        - %LOCALAPPDATA%\WinToolkit: CARTELLA VITALE - Contiene toolkit, log e dati essenziali
        Queste cartelle sono protette e NON verranno mai cancellate durante la pulizia.
        - WinSxS Assemblies sostituiti
        - Rapporti Errori Windows
        - Registro Eventi Windows
        - Cronologia Installazioni Windows Update
        - Punti di Ripristino del sistema
        - Cache Download Windows
        - Prefetch Windows
        - Cache Miniature Explorer
        - Cache web WinInet
        - Cookie Internet
        - Cache DNS
        - File Temporanei Windows
        - File Temporanei Utente
        - Coda di Stampa
        - Log di Sistema
    #>

    param([int]$CountdownSeconds = 30)

    $Host.UI.RawUI.WindowTitle = "Cleaner Toolkit By MagnetarMan"
    $script:Log = @(); $script:CurrentAttempt = 0

    # Setup logging specifico per WinCleaner
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\WinCleaner_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    $CleanupTasks = @(
        @{ Task = 'CleanMgrAuto'; Name = 'Pulizia automatica CleanMgr'; Icon = '🧹'; Auto = $true }
        @{ Task = 'WinSxS'; Name = 'WinSxS - Assembly sostituiti'; Icon = '📦'; Auto = $true }
        @{ Task = 'ErrorReports'; Name = 'Rapporti errori Windows'; Icon = '📋'; Auto = $true }
        @{ Task = 'EventLogs'; Name = 'Registro eventi Windows'; Icon = '📜'; Auto = $true }
        @{ Task = 'UpdateHistory'; Name = 'Cronologia Windows Update'; Icon = '📝'; Auto = $true }
        @{ Task = 'RestorePoints'; Name = 'Punti ripristino sistema'; Icon = '💾'; Auto = $true }
        @{ Task = 'DownloadCache'; Name = 'Cache download Windows'; Icon = '⬇️'; Auto = $true }
        @{ Task = 'PrefetchCleanup'; Name = 'Cache Prefetch Windows'; Icon = '⚡'; Auto = $true }
        @{ Task = 'ThumbnailCache'; Name = 'Cache miniature Explorer'; Icon = '🖼️'; Auto = $true }
        @{ Task = 'WinInetCacheCleanup'; Name = 'Cache web e file temporanei Internet'; Icon = '🌐'; Auto = $true }
        @{ Task = 'InternetCookiesCleanup'; Name = 'Cookie Internet'; Icon = '🍪'; Auto = $true }
        @{ Task = 'DNSFlush'; Name = 'Flush cache DNS'; Icon = '🔄'; Auto = $true }
        @{ Task = 'WindowsTempCleanup'; Name = 'File temporanei Windows'; Icon = '🗂️'; Auto = $true }
        @{ Task = 'UserTempCleanup'; Name = 'File temporanei utente'; Icon = '📁'; Auto = $true }
        @{ Task = 'PrintQueue'; Name = 'Coda di stampa'; Icon = '🖨️'; Auto = $true }
        @{ Task = 'SystemLogs'; Name = 'Log di sistema'; Icon = '📄'; Auto = $true }

        # Nuovi task di pulizia
        @{ Task = 'QuickAccessAndRecentFilesCleanup'; Name = 'Accesso Rapido e File Recenti'; Icon = '📁'; Auto = $true }
        @{ Task = 'RegeditHistoryCleanup'; Name = 'Cronologia Regedit'; Icon = '⚙️'; Auto = $true }
        @{ Task = 'ComDlg32HistoryCleanup'; Name = 'Cronologia Finestre di Dialogo File'; Icon = '📜'; Auto = $true }
        @{ Task = 'AdobeMediaBrowserCleanup'; Name = 'Cronologia Adobe Media Browser'; Icon = '🖼️'; Auto = $true }
        @{ Task = 'PaintAndWordPadHistoryCleanup'; Name = 'Cronologia Paint e WordPad'; Icon = '🎨'; Auto = $true }
        @{ Task = 'NetworkDriveHistoryCleanup'; Name = 'Cronologia Mappatura Unità di Rete'; Icon = '🌐'; Auto = $true }
        @{ Task = 'WindowsSearchHistoryCleanup'; Name = 'Cronologia Ricerca Windows'; Icon = '🔍'; Auto = $true }
        @{ Task = 'MediaPlayerHistoryCleanup'; Name = 'Cronologia Media Player'; Icon = '🎵'; Auto = $true }
        @{ Task = 'DirectXHistoryCleanup'; Name = 'Cronologia Applicazioni DirectX'; Icon = '🎮'; Auto = $true }
        @{ Task = 'RunCommandHistoryCleanup'; Name = 'Cronologia comandi Esegui'; Icon = '▶️'; Auto = $true }
        @{ Task = 'FileExplorerAddressBarHistoryCleanup'; Name = 'Cronologia Barra Indirizzi Esplora File'; Icon = '📂'; Auto = $true }
        @{ Task = 'ListarySearchIndexCleanup'; Name = 'Indice Ricerca Listary'; Icon = '📊'; Auto = $true }
        @{ Task = 'JavaCacheCleanup'; Name = 'Cache Java'; Icon = '☕'; Auto = $true }
        @{ Task = 'DotnetTelemetryCleanup'; Name = 'Telemetria Dotnet CLI'; Icon = '🌐'; Auto = $true }
        @{ Task = 'ChromeCleanup'; Name = 'Dati e Crash Report Chrome'; Icon = '🌐'; Auto = $true }
        @{ Task = 'FirefoxCleanup'; Name = 'Cronologia e Profili Firefox'; Icon = '🦊'; Auto = $true }
        @{ Task = 'SafariCleanup'; Name = 'Dati e Cache Safari'; Icon = '🍎'; Auto = $true }
        @{ Task = 'OperaCleanup'; Name = 'Dati e Cronologia Opera'; Icon = '🅾️'; Auto = $true }
        @{ Task = 'CLRUsageTracesCleanup'; Name = 'Tracce di Utilizzo .NET CLR'; Icon = '💻'; Auto = $true }
        @{ Task = 'VisualStudioTelemetryRootCleanup'; Name = 'Telemetria Visual Studio'; Icon = '💻'; Auto = $true }
        @{ Task = 'VisualStudioLicensesCleanup'; Name = 'Licenze Visual Studio'; Icon = '💻'; Auto = $true }
        @{ Task = 'WindowsSystemProfilesTempCleanup'; Name = 'Temp Profili di Servizio Windows'; Icon = '👤'; Auto = $true }
        @{ Task = 'SystemLogFileCleanup'; Name = 'Log di Sistema e Applicazioni Varie'; Icon = '📄'; Auto = $true }
        @{ Task = 'MinimizeDISMResetBase'; Name = 'Minimizza Dati Aggiornamenti DISM'; Icon = '📊'; Auto = $true }
        @{ Task = 'WindowsUpdateFilesCleanup'; Name = 'File Temporanei Windows Update'; Icon = '🔄'; Auto = $true }
        @{ Task = 'DiagTrackLogsCleanup'; Name = 'Log di Tracciamento Diagnostica'; Icon = '🚫'; Auto = $true }
        @{ Task = 'DefenderProtectionHistoryCleanup'; Name = 'Cronologia Protezione Defender'; Icon = '🛡️'; Auto = $true }
        @{ Task = 'SystemResourceUsageMonitorCleanup'; Name = 'Dati SRUM'; Icon = '📈'; Auto = $true }
        @{ Task = 'CredentialManagerCleanup'; Name = 'Credenziali Windows'; Icon = '🔑'; Auto = $true }
        @{ Task = 'RecycleBinEmpty'; Name = 'Svuota Cestino'; Icon = '🗑️'; Auto = $true }
        @{ Task = 'WindowsOld'; Name = 'Cartella Windows.old'; Icon = '🗑️'; Auto = $true } )

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        $timestamp = Get-Date -Format "HH:mm:ss"

        # Rimuovi emoji duplicati dal testo se presenti
        $cleanText = $Text -replace '^(✅|||💎|🔍|🚀|⚙️|🧹|📦|📋|📜|📝|💾|⬇️|🔧|⚡|🖼️|🌐|🍪|🔄|🗂️|📁|🖨️|📄|🗑️|💭|⏸️|▶️|💡|⏰|🎉|💻|📊|❌)\s*', ''

        Write-Host "[$timestamp] $($style.Icon) $cleanText" -ForegroundColor $style.Color

        # Log dettagliato per operazioni importanti
        if ($Type -in @('Info', 'Warning', 'Error')) {
            $logEntry = "[$timestamp] [$Type] $cleanText"
            $script:Log += $logEntry
        }
    }

    function Test-ExcludedPath {
        param([string]$Path)

        # Esclusioni tassative - QUESTE CARTELLE SONO VITALI E NON DEVONO MAI ESSERE CANCELLATE
        $excludedPaths = @(
            "$env:LOCALAPPDATA\WinToolkit"  # CARTELLA VITALE: Contiene toolkit, log e dati essenziali
        )

        $fullPath = $Path
        if (-not [System.IO.Path]::IsPathRooted($Path)) {
            $fullPath = Join-Path (Get-Location) $Path
        }

        foreach ($excluded in $excludedPaths) {
            $excludedFull = $excluded
            if (-not [System.IO.Path]::IsPathRooted($excluded)) {
                $excludedFull = [Environment]::ExpandEnvironmentVariables($excluded)
            }

            # Verifica se il path è dentro una directory esclusa
            if ($fullPath -like "$excludedFull*" -or $fullPath -eq $excludedFull) {
                Write-StyledMessage Info "🛡️ CARTELLA VITALE PROTETTA: $fullPath"
                $script:Log += "[EXCLUSION] 🛡️ Cartella vitale protetta dalla pulizia: $fullPath"
                return $true
            }
        }

        return $false
    }

    function Start-ProcessWithTimeout {
        param(
            [string]$FilePath,
            [string[]]$ArgumentList,
            [int]$TimeoutSeconds = 300,
            [string]$Activity = "Processo in esecuzione",
            [switch]$Hidden
        )

        $startTime = Get-Date
        $spinnerIndex = 0
        $percent = 0

        try {
            $processParams = @{
                FilePath     = $FilePath
                ArgumentList = $ArgumentList
                PassThru     = $true
            }

            # Usa WindowStyle Hidden OPPURE NoNewWindow, non entrambi
            if ($Hidden) {
                $processParams.Add('WindowStyle', 'Hidden')
            }
            else {
                $processParams.Add('NoNewWindow', $true)
            }

            $proc = Start-Process @processParams

            while (-not $proc.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                if ($percent -lt 90) { $percent += Get-Random -Minimum 1 -Maximum 3 }
                Show-ProgressBar $Activity "In esecuzione... ($elapsed secondi)" $percent '⏳' $spinner
                Start-Sleep -Milliseconds 500
                $proc.Refresh()
            }

            if (-not $proc.HasExited) {
                Clear-ProgressLine
                Write-StyledMessage Warning "Timeout raggiunto dopo $TimeoutSeconds secondi, terminazione processo..."
                $proc.Kill()
                Start-Sleep -Seconds 2
                return @{ Success = $false; TimedOut = $true; ExitCode = -1 }
            }

            Clear-ProgressLine
            return @{ Success = $true; TimedOut = $false; ExitCode = $proc.ExitCode }
        }
        catch {
            Clear-ProgressLine
            Write-StyledMessage Error "Errore nell'avvio del processo: $($_.Exception.Message)"
            return @{ Success = $false; TimedOut = $false; ExitCode = -1 }
        }
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '▒' * (30 - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Clear-ProgressLine {
        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline
    }

    function Invoke-DeletePaths([string[]]$Paths, [string]$Description, [string]$Icon, [switch]$Recursive = $true, [switch]$FilesOnly = $false, [switch]$TakeOwnership = $false, [switch]$PerUser = $false) {
        $totalCleaned = 0
        $errorCount = 0
        $pathsToProcess = @()

        if ($PerUser) {
            $users = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notmatch 'Public|Default|All Users' }
            foreach ($user in $users) {
                foreach ($path in $Paths) {
                    $expandedPath = $path -replace '%USERPROFILE%', $user.FullName -replace '%APPDATA%', "$($user.FullName)\AppData\Roaming" -replace '%LOCALAPPDATA%', "$($user.FullName)\AppData\Local"
                    $pathsToProcess += $expandedPath
                }
            }
        } else {
            foreach ($path in $Paths) {
                $expandedPath = [System.Environment]::ExpandEnvironmentVariables($path)
                $pathsToProcess += $expandedPath
            }
        }

        foreach ($currentPath in $pathsToProcess) {
            if (Test-ExcludedPath $currentPath) {
                Write-StyledMessage Info "🛡️ Percorso escluso: $currentPath"
                continue
            }

            if ($TakeOwnership) {
                Write-StyledMessage Info "🔑 Assunzione proprietà per $currentPath..."
                $takeownResult = cmd /c "takeown /F ""$currentPath"" /R /A /D Y 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Write-StyledMessage Warning "❌ Errore takeown: $takeownResult"
                    $errorCount++
                }
                $icaclsResult = cmd /c "icacls ""$currentPath"" /T /grant ""$([System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544').Translate([System.Security.Principal.NTAccount]).Value):F"" 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Write-StyledMessage Warning "❌ Errore icacls: $icaclsResult"
                    $errorCount++
                }
            }

            try {
                if (Test-Path $currentPath) {
                    if ($FilesOnly) {
                        $items = Get-ChildItem -Path $currentPath -Recurse -File -ErrorAction SilentlyContinue
                        $items | Remove-Item -Force -ErrorAction SilentlyContinue
                        $totalCleaned += $items.Count
                    } else {
                        Remove-Item -Path $currentPath -Recurse:$Recursive -Force -ErrorAction SilentlyContinue
                        $totalCleaned++
                    }
                    Write-StyledMessage Success "🗑️ Pulito: $currentPath ($totalCleaned elementi)"
                }
            } catch {
                Write-StyledMessage Warning "❌ Errore pulizia $currentPath : $_"
                $errorCount++
            }
        }

        return @{ Success = ($errorCount -eq 0); ErrorCount = $errorCount }
    }

    function Invoke-ClearRegistryKeyValues([string]$KeyPath, [string]$Description, [string]$Icon, [switch]$Recursive = $false) {
        $totalCleaned = 0
        $errorCount = 0

        $expandedKeyPath = [System.Environment]::ExpandEnvironmentVariables($KeyPath)
        $formattedKeyPath = $expandedKeyPath -replace '^HKCU:', 'HKCU:\' -replace '^HKLM:', 'HKLM:\'

        if (Test-Path -LiteralPath $formattedKeyPath) {
            try {
                $key = Get-Item -LiteralPath $formattedKeyPath -ErrorAction SilentlyContinue
                $valueNames = $key.GetValueNames()
                foreach ($valueName in $valueNames) {
                    if ($valueName -eq '(default)') {
                        $key.OpenSubKey('', $true).DeleteValue('')
                    } else {
                        Remove-ItemProperty -LiteralPath $formattedKeyPath -Name $valueName -ErrorAction SilentlyContinue
                    }
                    $totalCleaned++
                }
                if ($Recursive) {
                    $subKeys = Get-ChildItem -Path $formattedKeyPath -ErrorAction SilentlyContinue
                    foreach ($subKey in $subKeys) {
                        Invoke-ClearRegistryKeyValues -KeyPath $subKey.PSPath -Description "$Description (sottochiave)" -Icon $Icon -Recursive
                    }
                }
                Write-StyledMessage Success "🗑️ Puliti valori registro: $formattedKeyPath ($totalCleaned valori)"
            } catch {
                Write-StyledMessage Warning "❌ Errore pulizia registro $formattedKeyPath : $_"
                $errorCount++
            }
        } else {
            Write-StyledMessage Info "💭 Chiave registro non esistente: $formattedKeyPath"
        }

        return @{ Success = ($errorCount -eq 0); ErrorCount = $errorCount }
    }

    function Invoke-RemoveRegistryKeyFull([string]$KeyPath, [string]$Description, [string]$Icon) {
        $errorCount = 0

        $expandedKeyPath = [System.Environment]::ExpandEnvironmentVariables($KeyPath)
        $formattedKeyPath = $expandedKeyPath -replace '^HKCU:', 'HKCU:\' -replace '^HKLM:', 'HKLM:\'

        if (Test-Path -LiteralPath $formattedKeyPath) {
            try {
                Remove-Item -LiteralPath $formattedKeyPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-StyledMessage Success "🗑️ Rimossa chiave registro: $formattedKeyPath"
            } catch {
                Write-StyledMessage Warning "❌ Errore rimozione chiave registro $formattedKeyPath : $_"
                $errorCount++
            }
        } else {
            Write-StyledMessage Info "💭 Chiave registro non esistente: $formattedKeyPath"
        }

        return @{ Success = ($errorCount -eq 0); ErrorCount = $errorCount }
    }

    function Invoke-SetRegistryKeyValue([string]$KeyPath, [string]$ValueName, [object]$ValueData, [string]$ValueType, [string]$Description, [string]$Icon) {
        $errorCount = 0

        $expandedKeyPath = [System.Environment]::ExpandEnvironmentVariables($KeyPath)
        $formattedKeyPath = $expandedKeyPath -replace '^HKCU:', 'HKCU:\' -replace '^HKLM:', 'HKLM:\'

        try {
            if (-not (Test-Path $formattedKeyPath)) {
                New-Item -Path $formattedKeyPath -Force -ErrorAction SilentlyContinue | Out-Null
            }
            Set-ItemProperty -LiteralPath $formattedKeyPath -Name $ValueName -Value $ValueData -Type $ValueType -Force -ErrorAction SilentlyContinue
            Write-StyledMessage Success "⚙️ Impostato valore registro: $formattedKeyPath\$ValueName"
        } catch {
            Write-StyledMessage Warning "❌ Errore impostazione valore registro $formattedKeyPath\$ValueName : $_"
            $errorCount++
        }

        return @{ Success = ($errorCount -eq 0); ErrorCount = $errorCount }
    }

    function Invoke-ServiceControl([string]$ServiceName, [string]$Action, [string]$Description, [string]$Icon) {
        $errorCount = 0

        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-StyledMessage Info "💭 Servizio $ServiceName non trovato"
            return @{ Success = $true; ErrorCount = 0 }
        }

        $stateFile = [IO.Path]::Combine($env:LOCALAPPDATA, 'WinToolkit', 'service_state', "$ServiceName.tmp")

        if ($Action -eq 'Stop') {
            if ($service.Status -eq 'Running') {
                Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
                WaitForStatus -ServiceName $ServiceName -Status 'Stopped' -Timeout 30
                if (-not (Test-Path (Split-Path $stateFile))) {
                    New-Item -ItemType Directory -Path (Split-Path $stateFile) -Force | Out-Null
                }
                New-Item -ItemType File -Path $stateFile -Force | Out-Null
                Write-StyledMessage Success "⏸️ Servizio $ServiceName fermato"
            }
        } elseif ($Action -eq 'Start') {
            if (Test-Path $stateFile) {
                Remove-Item $stateFile -Force
                Start-Service -Name $ServiceName -ErrorAction SilentlyContinue
                WaitForStatus -ServiceName $ServiceName -Status 'Running' -Timeout 30
                Write-StyledMessage Success "▶️ Servizio $ServiceName avviato"
            } elseif ($service.Status -ne 'Running') {
                Start-Service -Name $ServiceName -ErrorAction SilentlyContinue
                WaitForStatus -ServiceName $ServiceName -Status 'Running' -Timeout 30
                Write-StyledMessage Success "▶️ Servizio $ServiceName avviato"
            }
        }

        return @{ Success = ($errorCount -eq 0); ErrorCount = $errorCount }
    }

    function WaitForStatus([string]$ServiceName, [string]$Status, [int]$Timeout = 30) {
        $timer = [Diagnostics.Stopwatch]::StartNew()
        while ($timer.Elapsed.TotalSeconds -lt $Timeout) {
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($service.Status -eq $Status) {
                $timer.Stop()
                return $true
            }
            Start-Sleep -Milliseconds 500
        }
        $timer.Stop()
        return $false
    }
    }

    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi un tasto qualsiasi per annullare...'
        Write-Host ''

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning '⏸️ Riavvio automatico annullato'
                Write-StyledMessage Info "🔄 Puoi riavviare manualmente: 'shutdown /r /t 0' o dal menu Start."
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning '⏰ Tempo scaduto: il sistema verrà riavviato ora.'
        Start-Sleep 1
        return $true
    }

    function Invoke-CleanMgrAuto {
        Write-StyledMessage Info "🧹 Pulizia disco tramite CleanMgr..."
        $percent = 0; $spinnerIndex = 0

        try {
            Write-StyledMessage Info "⚙️ Verifica configurazione CleanMgr nel registro..."
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"

            # Verifica se esistono già configurazioni valide
            $existingConfigs = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue |
            Where-Object {
                $stateFlag = $null
                try {
                    $stateFlag = Get-ItemProperty -Path $_.PSPath -Name "StateFlags0065" -ErrorAction SilentlyContinue
                }
                catch {}
                $stateFlag -and $stateFlag.StateFlags0065 -eq 2
            }

            # Conta quante opzioni valide sono configurate
            $validOptions = 0
            Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $stateFlag = Get-ItemProperty -Path $_.PSPath -Name "StateFlags0065" -ErrorAction SilentlyContinue
                    if ($stateFlag -and $stateFlag.StateFlags0065 -eq 2) { $validOptions++ }
                }
                catch {}
            }

            if (-not $existingConfigs -or $validOptions -lt 3) {
                Write-StyledMessage Info "📝 Configurazione opzioni di pulizia nel registro..."
                
                # Abilita tutte le opzioni di pulizia disponibili con StateFlags0065
                $cleanOptions = @(
                    "Active Setup Temp Folders",
                    "BranchCache",
                    "D3D Shader Cache",
                    "Delivery Optimization Files",
                    "Downloaded Program Files",
                    "Internet Cache Files",
                    "Memory Dump Files",
                    "Recycle Bin",
                    "Setup Log Files",
                    "System error memory dump files",
                    "System error minidump files",
                    "Temporary Files",
                    "Temporary Setup Files",
                    "Thumbnail Cache",
                    "Windows Error Reporting Files",
                    "Windows Upgrade Log Files"
                )

                $configuredCount = 0
                $availableOptions = @()

                # Prima verifica quali opzioni sono effettivamente disponibili
                foreach ($option in $cleanOptions) {
                    $optionPath = Join-Path $regPath $option
                    if (Test-Path $optionPath) {
                        $availableOptions += $option
                    }
                }

                Write-StyledMessage Info "📋 Trovate $($availableOptions.Count) opzioni di pulizia disponibili"

                # Configura solo le opzioni disponibili
                foreach ($option in $availableOptions) {
                    $optionPath = Join-Path $regPath $option
                    try {
                        Set-ItemProperty -Path $optionPath -Name "StateFlags0065" -Value 2 -Type DWORD -Force -ErrorAction Stop
                        $configuredCount++
                        Write-StyledMessage Info "✅ Configurata: $option"
                    }
                    catch {
                        Write-StyledMessage Warning "❌ Impossibile configurare: $option - $($_.Exception.Message)"
                    }
                }

                Write-StyledMessage Info "✅ Configurate $configuredCount opzioni di pulizia"
            }
            else {
                Write-StyledMessage Info "✅ Configurazione esistente trovata nel registro"
            }

            # Verifica se ci sono effettivamente file da pulire
            Write-StyledMessage Info "🔍 Verifica se ci sono file da pulire..."
            $startTime = Get-Date
            $testProc = Start-Process 'cleanmgr.exe' -ArgumentList '/sagerun:65' -PassThru -WindowStyle Hidden -Wait

            if ($testProc.ExitCode -eq 0 -and (Get-Date) - $startTime -lt [TimeSpan]::FromSeconds(5)) {
                Write-StyledMessage Info "💨 CleanMgr completato rapidamente - probabilmente nessun file da pulire"
                Write-StyledMessage Success "✅ Verifica pulizia completata - sistema già pulito"
                return @{ Success = $true; ErrorCount = 0 }
            }

            # Esecuzione pulizia con configurazione automatica (se necessario)
            Write-StyledMessage Info "🚀 Avvio pulizia disco (questo può richiedere diversi minuti)..."
            $proc = Start-Process 'cleanmgr.exe' -ArgumentList '/sagerun:65' -PassThru -WindowStyle Minimized

            Write-StyledMessage Info "🔍 Processo CleanMgr avviato (PID: $($proc.Id))"
            
            # Attendi che il processo si stabilizzi
            Start-Sleep -Seconds 3
            
            # Timeout di sicurezza (15 minuti max per CleanMgr)
            $timeout = 900
            $lastCheck = Get-Date
            
            while (-not $proc.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 0)
                
                # Verifica se il processo è ancora attivo
                try {
                    $proc.Refresh()
                    $cpuUsage = (Get-Process -Id $proc.Id -ErrorAction Stop).CPU
                    
                    # Aggiorna percentuale in base al tempo trascorso (stima)
                    if ($elapsed -lt 60) {
                        $percent = [math]::Min(30, $elapsed / 2)
                    }
                    elseif ($elapsed -lt 180) {
                        $percent = 30 + (($elapsed - 60) / 4)
                    }
                    else {
                        $percent = [math]::Min(95, 60 + (($elapsed - 180) / 10))
                    }
                    
                    Show-ProgressBar "Pulizia CleanMgr" "Analisi e pulizia in corso... ($elapsed s)" ([int]$percent) '🧹' $spinner
                    Start-Sleep -Milliseconds 1000
                }
                catch {
                    # Processo terminato
                    break
                }
            }

            if (-not $proc.HasExited) {
                Clear-ProgressLine
                Write-StyledMessage Warning "Timeout raggiunto dopo $([math]::Round($timeout/60, 0)) minuti"
                try {
                    $proc.Kill()
                    Start-Sleep -Seconds 2
                }
                catch {
                    # Processo già terminato
                }
                $script:Log += "[CleanMgrAuto] Timeout dopo $timeout secondi"
                return @{ Success = $true; ErrorCount = 0 }
            }

            $exitCode = $proc.ExitCode
            Clear-ProgressLine
            Show-ProgressBar "Pulizia CleanMgr" 'Completato' 100 '🧹'
            Write-Host ''
            
            if ($exitCode -eq 0) {
                Write-StyledMessage Success "Pulizia disco completata con successo"
                $script:Log += "[CleanMgrAuto] ✅ Pulizia completata (Exit code: $exitCode, Durata: $([math]::Round(((Get-Date) - $startTime).TotalSeconds, 0))s)"
            }
            else {
                Write-StyledMessage Warning "Pulizia disco completata con warnings (Exit code: $exitCode)"
                $script:Log += "[CleanMgrAuto] Completato con warnings (Exit code: $exitCode)"
            }
            
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Clear-ProgressLine
            Write-StyledMessage Error "Errore durante pulizia CleanMgr: $($_.Exception.Message)"
            Write-StyledMessage Info "💡 Suggerimento: Eseguire manualmente 'cleanmgr.exe' per verificare"
            $script:Log += "[CleanMgrAuto] Errore: $($_.Exception.Message)"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WinSxSCleanup {
        Write-StyledMessage Info "📦 Pulizia componenti WinSxS sostituiti..."
        $percent = 0; $spinnerIndex = 0

        try {
            Write-StyledMessage Info "🔍 Avvio analisi componenti WinSxS..."

            $result = Start-ProcessWithTimeout -FilePath 'DISM.exe' -ArgumentList '/Online /Cleanup-Image /StartComponentCleanup /ResetBase' -TimeoutSeconds 900 -Activity "WinSxS Cleanup" -Hidden

            if ($result.TimedOut) {
                Write-StyledMessage Warning "Pulizia WinSxS interrotta per timeout"
                $script:Log += "[WinSxS]  Timeout dopo 15 minuti"
                return @{ Success = $true; ErrorCount = 0 }
            }

            $exitCode = $result.ExitCode

            if ($exitCode -eq 0) {
                Write-StyledMessage Success "✅ Componenti WinSxS puliti con successo"
                $script:Log += "[WinSxS] ✅ Pulizia completata (Exit code: $exitCode)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Warning "Pulizia WinSxS completata con warnings (Exit code: $exitCode)"
                $script:Log += "[WinSxS]  Completato con warnings (Exit code: $exitCode)"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante pulizia WinSxS: $($_.Exception.Message)"
            $script:Log += "[WinSxS]  Errore: $($_.Exception.Message)"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ErrorReportsCleanup {
        Write-StyledMessage Info "📋 Pulizia rapporti errori Windows..."
        $werPaths = @(
            "$env:ProgramData\Microsoft\Windows\WER",
            "$env:ALLUSERSPROFILE\Microsoft\Windows\WER"
        )

        $totalCleaned = 0
        foreach ($path in $werPaths) {
            # Verifica esclusione cartella WinToolkit
            if (Test-ExcludedPath $path) {
                continue
            }

            if (Test-Path $path) {
                try {
                    $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                        -not (Test-ExcludedPath $_.FullName)
                    }
                    $files | Remove-Item -Force -ErrorAction SilentlyContinue
                    $totalCleaned += $files.Count
                    Write-StyledMessage Info "🗑️ Rimosso $($files.Count) file da $path"
                }
                catch {
                    Write-StyledMessage Warning "Impossibile pulire $path - $_"
                }
            }
        }

        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Rapporti errori puliti ($totalCleaned file)"
            $script:Log += "[ErrorReports] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessun rapporto errori da pulire"
            $script:Log += "[ErrorReports] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
        }
    }

    function Invoke-EventLogsCleanup {
        Write-StyledMessage Info "📜 Pulizia registro eventi Windows..."
        try {
            Write-StyledMessage Info "⚙️ Impostazione permessi per log eventi specifici..."
            $permResult = Start-ProcessWithTimeout -FilePath 'wevtutil.exe' -ArgumentList "sl Microsoft-Windows-LiveId/Operational /ca:O:BAG:SYD:(A;;0x1;;;SY)(A;;0x5;;;BA)(A;;0x1;;;LA)" -TimeoutSeconds 30 -Activity "Impostazione permessi log LiveId" -Hidden
            if (-not $permResult.Success) {
                Write-StyledMessage Warning "❌ Impossibile impostare permessi per Microsoft-Windows-LiveId/Operational."
            }

            wevtutil el | ForEach-Object {
                wevtutil cl $_ 2>$null
            }

            Write-StyledMessage Success "✅ Registro eventi pulito"
            $script:Log += "[EventLogs] ✅ Pulizia completata"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia registro eventi: $_"
            $script:Log += "[EventLogs]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-UpdateHistoryCleanup {
        Write-StyledMessage Info "📝 Pulizia cronologia Windows Update..."
        $updatePaths = @(
            "C:\WINDOWS\SoftwareDistribution\DataStore\DataStore.edb",
            "C:\WINDOWS\SoftwareDistribution\DataStore\DataStore.jfm",
            "C:\WINDOWS\SoftwareDistribution\DataStore\Logs"
        )

        $totalCleaned = 0
        foreach ($path in $updatePaths) {
            # Verifica esclusione cartella WinToolkit
            if (Test-ExcludedPath $path) {
                continue
            }

            try {
                if (Test-Path $path) {
                    if (Test-Path -Path $path -PathType Container) {
                        $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                            -not (Test-ExcludedPath $_.FullName)
                        }
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        $totalCleaned += $files.Count
                        Write-StyledMessage Info "🗑️ Rimossa directory: $path"
                    }
                    else {
                        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                        $totalCleaned++
                        Write-StyledMessage Info "🗑️ Rimosso file: $path"
                    }
                }
            }
            catch {
                Write-StyledMessage Warning " Impossibile rimuovere $path - $_"
            }
        }

        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Cronologia Update pulita ($totalCleaned elementi)"
            $script:Log += "[UpdateHistory] ✅ Pulizia completata ($totalCleaned elementi)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessuna cronologia Update da pulire"
            $script:Log += "[UpdateHistory] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
        }
    }

    function Invoke-RestorePointsCleanup {
        Write-StyledMessage Info "💾 Disattivazione punti ripristino sistema..."
        try {
            # Disattiva la protezione del sistema
            vssadmin delete shadows /all /quiet 2>$null

            # Disattiva la protezione del sistema per il disco C:
            Disable-ComputerRestore -Drive "C:" -ErrorAction SilentlyContinue

            Write-StyledMessage Success "✅ Punti ripristino disattivati"
            $script:Log += "[RestorePoints] ✅ Disattivazione completata"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning " Errore durante disattivazione punti ripristino: $_"
            $script:Log += "[RestorePoints]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DownloadCacheCleanup {
        Write-StyledMessage Info "⬇️ Pulizia cache download Windows..."
        $downloadPath = "C:\WINDOWS\SoftwareDistribution\Download"

        try {
            # Verifica esclusione cartella WinToolkit
            if (Test-ExcludedPath $downloadPath) {
                Write-StyledMessage Info "💭 Cache download esclusa dalla pulizia"
                $script:Log += "[DownloadCache] ℹ️ Directory esclusa"
                return @{ Success = $true; ErrorCount = 0 }
            }

            if (Test-Path $downloadPath) {
                $files = Get-ChildItem -Path $downloadPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                    -not (Test-ExcludedPath $_.FullName)
                }
                $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

                Write-StyledMessage Success "✅ Cache download pulita ($($files.Count) file)"
                $script:Log += "[DownloadCache] ✅ Pulizia completata ($($files.Count) file)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Info "💭 Cache download non presente"
                $script:Log += "[DownloadCache] ℹ️ Directory non presente"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Warning " Errore durante pulizia cache download: $_"
            $script:Log += "[DownloadCache]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }


    function Invoke-PrefetchCleanup {
        Write-StyledMessage Info "⚡ Pulizia cache Prefetch Windows..."
        try {
            $result = Invoke-DeletePaths -Paths @("C:\WINDOWS\Prefetch", "$env:SYSTEMROOT\Prefetch") -Description "Cache Prefetch Windows" -Icon '⚡'

            Write-StyledMessage Success "✅ Cache Prefetch pulita"
            $script:Log += "[Prefetch] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning " Errore durante pulizia Prefetch: $_"
            $script:Log += "[Prefetch]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ThumbnailCacheCleanup {
        Write-StyledMessage Info "🖼️ Pulizia cache miniature Explorer..."
        $thumbnailPaths = @(
            "$env:APPDATA\Microsoft\Windows\Explorer",
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        )

        $totalCleaned = 0
        $thumbnailFiles = @(
            "iconcache_*.db", "thumbcache_*.db", "ExplorerStartupLog*.etl",
            "NotifyIcon", "RecommendationsFilterList.json"
        )

        foreach ($path in $thumbnailPaths) {
            # Verifica esclusione cartella WinToolkit
            if (Test-ExcludedPath $path) {
                continue
            }

            foreach ($pattern in $thumbnailFiles) {
                try {
                    $files = Get-ChildItem -Path $path -Name $pattern -ErrorAction SilentlyContinue | Where-Object {
                        $fullPath = Join-Path $path $_
                        -not (Test-ExcludedPath $fullPath)
                    }
                    $files | ForEach-Object {
                        $fullPath = Join-Path $path $_
                        Remove-Item -Path $fullPath -Force -ErrorAction SilentlyContinue
                        if (-not (Test-Path $fullPath)) { $totalCleaned++ }
                    }
                }
                catch {
                    Write-StyledMessage Warning " Impossibile rimuovere alcuni file in $path"
                }
            }
        }

        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Cache miniature pulita ($totalCleaned file)"
            $script:Log += "[ThumbnailCache] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessuna cache miniature da pulire"
            $script:Log += "[ThumbnailCache] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
        }
    }

    function Invoke-WinInetCacheCleanup {
        Write-StyledMessage Info "🌐 Pulizia cache web WinInet e file temporanei Internet..."
        try {
            $result1 = Invoke-DeletePaths -Paths @("$env:LOCALAPPDATA\Microsoft\Windows\INetCache\IE", "$env:LOCALAPPDATA\Microsoft\Windows\WebCache", "$env:LOCALAPPDATA\Microsoft\Feeds Cache", "$env:LOCALAPPDATA\Microsoft\InternetExplorer\DOMStore", "$env:LOCALAPPDATA\Microsoft\Internet Explorer") -Description "Cache WinInet e dati Internet Explorer" -Icon '🌐'
            $result2 = Invoke-DeletePaths -Paths @("%USERPROFILE%\Local Settings\Temporary Internet Files", "%LOCALAPPDATA%\Microsoft\Windows\Temporary Internet Files") -Description "File Temporanei Internet (per tutti gli utenti)" -Icon '🌐' -TakeOwnership $true -PerUser $true

            # Forza pulizia cache IE
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 8 2>$null
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 2 2>$null

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount
            Write-StyledMessage Success "✅ Cache WinInet e file temporanei Internet puliti"
            $script:Log += "[WinInetCache] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning " Errore durante pulizia cache WinInet: $_"
            $script:Log += "[WinInetCache]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-InternetCookiesCleanup {
        Write-StyledMessage Info "🍪 Pulizia cookie Internet..."
        try {
            $result = Invoke-DeletePaths -Paths @("%APPDATA%\Microsoft\Windows\Cookies", "%LOCALAPPDATA%\Microsoft\Windows\INetCookies") -Description "Cookie Internet (per tutti gli utenti)" -Icon '🍪' -PerUser $true

            # Forza pulizia cookie IE
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 1 2>$null

            Write-StyledMessage Success "✅ Cookie Internet puliti"
            $script:Log += "[InternetCookies] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning " Errore durante pulizia cookie: $_"
            $script:Log += "[InternetCookies]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DNSFlush {
        Write-StyledMessage Info "🔄 Flush cache DNS..."
        try {
            # Esegue il flush della cache DNS
            $result = ipconfig /flushdns 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-StyledMessage Success "✅ Cache DNS svuotata con successo"
                $script:Log += "[DNSFlush] ✅ Flush completato"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Warning " Flush DNS completato con warnings"
                $script:Log += "[DNSFlush]  Completato con warnings"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Warning " Errore durante flush DNS: $_"
            $script:Log += "[DNSFlush]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WindowsTempCleanup {
        Write-StyledMessage Info "🗂️ Pulizia file temporanei Windows..."
        try {
            $result = Invoke-DeletePaths -Paths @("C:\WINDOWS\Temp", "$env:SYSTEMROOT\Temp") -Description "File temporanei di sistema Windows" -Icon '🗂️'

            Write-StyledMessage Success "✅ File temporanei Windows puliti"
            $script:Log += "[WindowsTemp] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning " Errore durante pulizia file temporanei Windows: $_"
            $script:Log += "[WindowsTemp]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-UserTempCleanup {
        Write-StyledMessage Info "📁 Pulizia file temporanei utente..."
        try {
            $result = Invoke-DeletePaths -Paths @("%USERPROFILE%\AppData\Local\Temp", "%USERPROFILE%\AppData\LocalLow\Temp", "%TEMP%") -Description "File temporanei utente" -Icon '📁' -PerUser $true

            Write-StyledMessage Success "✅ File temporanei utente puliti"
            $script:Log += "[UserTemp] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning " Errore durante pulizia file temporanei utente: $_"
            $script:Log += "[UserTemp]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-PrintQueueCleanup {
        Write-StyledMessage Info "🖨️ Pulizia coda di stampa..."
        try {
            # Ferma il servizio spooler
            Write-StyledMessage Info "⏸️ Arresto servizio spooler..."
            Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2

            # Pulisce la coda di stampa
            $spoolPath = "C:\WINDOWS\System32\spool\PRINTERS"
            $totalCleaned = 0

            if (Test-Path $spoolPath) {
                $files = Get-ChildItem -Path $spoolPath -File -ErrorAction SilentlyContinue
                $files | Remove-Item -Force -ErrorAction SilentlyContinue
                $totalCleaned = $files.Count
            }

            # Riavvia il servizio spooler
            Write-StyledMessage Info "▶️ Riavvio servizio spooler..."
            Start-Service -Name Spooler -ErrorAction SilentlyContinue

            if ($totalCleaned -gt 0) {
                Write-StyledMessage Success "✅ Coda di stampa pulita ($totalCleaned file)"
                $script:Log += "[PrintQueue] ✅ Pulizia completata ($totalCleaned file)"
            }
            else {
                Write-StyledMessage Info "💭 Nessun file in coda di stampa"
                $script:Log += "[PrintQueue] ℹ️ Nessun file da pulire"
            }

            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            # Assicura che il servizio spooler sia riavviato anche in caso di errore
            Start-Service -Name Spooler -ErrorAction SilentlyContinue
            Write-StyledMessage Warning " Errore durante pulizia coda di stampa: $_"
            $script:Log += "[PrintQueue]  Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-SystemLogsCleanup {
        Write-StyledMessage Info "📄 Pulizia log di sistema..."
        $logPaths = @(
            "C:\WINDOWS\Logs",
            "C:\WINDOWS\System32\LogFiles",
            "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"
        )

    function Invoke-QuickAccessAndRecentFilesCleanup {
        Write-StyledMessage Info "📁 Pulizia Accesso Rapido e File Recenti..."
        try {
            $result = Invoke-DeletePaths -Paths @("%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations", "%APPDATA%\Microsoft\Windows\Recent\CustomDestinations", "%APPDATA%\Microsoft\Windows\Recent Items") -Description 'Pulizia Accesso Rapido e File Recenti' -Icon '📁' -PerUser $true

            Write-StyledMessage Success "✅ Accesso Rapido e File Recenti puliti"
            $script:Log += "[QuickAccessAndRecentFiles] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Accesso Rapido e File Recenti: $_"
            $script:Log += "[QuickAccessAndRecentFiles] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-RegeditHistoryCleanup {
        Write-StyledMessage Info "⚙️ Pulizia cronologia Regedit..."
        try {
            Remove-ItemProperty -LiteralPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit' -Name 'LastKey' -ErrorAction SilentlyContinue
            $result = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites' -Description 'Valori Preferiti Regedit' -Icon '⚙️'

            Write-StyledMessage Success "✅ Cronologia Regedit pulita"
            $script:Log += "[RegeditHistory] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia Regedit: $_"
            $script:Log += "[RegeditHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ComDlg32HistoryCleanup {
        Write-StyledMessage Info "📜 Pulizia cronologia finestre di dialogo file..."
        try {
            $result1 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedMRU' -Description 'Cronologia finestre di dialogo file' -Icon '📜' -Recursive $true
            $result2 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU' -Description 'Cronologia PIDL finestre di dialogo' -Icon '📜' -Recursive $true
            $result3 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRULegacy' -Description 'Cronologia PIDL legacy' -Icon '📜' -Recursive $true
            $result4 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs' -Description 'Documenti recenti' -Icon '📜' -Recursive $true
            $result5 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU' -Description 'MRU Apri/Salva' -Icon '📜' -Recursive $true
            $result6 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU' -Description 'PIDL Apri/Salva' -Icon '📜' -Recursive $true

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount + $result4.ErrorCount + $result5.ErrorCount + $result6.ErrorCount
            Write-StyledMessage Success "✅ Cronologia finestre di dialogo pulita"
            $script:Log += "[ComDlg32History] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia finestre di dialogo: $_"
            $script:Log += "[ComDlg32History] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-AdobeMediaBrowserCleanup {
        Write-StyledMessage Info "🖼️ Pulizia cronologia Adobe Media Browser..."
        try {
            $result = Invoke-RemoveRegistryKeyFull -KeyPath 'HKCU\Software\Adobe\MediaBrowser\MRU' -Description 'Chiave Cronologia Adobe Media Browser' -Icon '🖼️'

            Write-StyledMessage Success "✅ Cronologia Adobe Media Browser pulita"
            $script:Log += "[AdobeMediaBrowser] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Adobe Media Browser: $_"
            $script:Log += "[AdobeMediaBrowser] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-PaintAndWordPadHistoryCleanup {
        Write-StyledMessage Info "🎨 Pulizia cronologia Paint e WordPad..."
        try {
            $result1 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Applets\Paint\Recent File List' -Description 'Cronologia file recenti Paint' -Icon '🎨'
            $result2 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Wordpad\Recent File List' -Description 'Cronologia file recenti WordPad' -Icon '🎨'

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount
            Write-StyledMessage Success "✅ Cronologia Paint e WordPad pulita"
            $script:Log += "[PaintAndWordPadHistory] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia Paint e WordPad: $_"
            $script:Log += "[PaintAndWordPadHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-NetworkDriveHistoryCleanup {
        Write-StyledMessage Info "🌐 Pulizia cronologia mappatura unità di rete..."
        try {
            $result = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Map Network Drive MRU' -Description 'Cronologia mappatura unità di rete' -Icon '🌐'

            Write-StyledMessage Success "✅ Cronologia mappatura unità di rete pulita"
            $script:Log += "[NetworkDriveHistory] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia unità di rete: $_"
            $script:Log += "[NetworkDriveHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WindowsSearchHistoryCleanup {
        Write-StyledMessage Info "🔍 Pulizia cronologia ricerca Windows..."
        try {
            $result1 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\Search Assistant\ACMru' -Description 'Cronologia registro ricerca Windows' -Icon '🔍' -Recursive $true
            $result2 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery' -Description 'Query WordWheel' -Icon '🔍' -Recursive $true
            $result3 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\SearchHistory' -Description 'Cronologia ricerca' -Icon '🔍' -Recursive $true
            $result4 = Invoke-DeletePaths -Paths @("%LOCALAPPDATA%\Microsoft\Windows\ConnectedSearch\History") -Description 'Cartella cronologia ricerca Windows' -Icon '🔍' -PerUser $true

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount + $result4.ErrorCount
            Write-StyledMessage Success "✅ Cronologia ricerca Windows pulita"
            $script:Log += "[WindowsSearchHistory] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia ricerca Windows: $_"
            $script:Log += "[WindowsSearchHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-MediaPlayerHistoryCleanup {
        Write-StyledMessage Info "🎵 Pulizia cronologia Media Player..."
        try {
            $result1 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\MediaPlayer\Player\RecentFileList' -Description 'Cronologia Media Player' -Icon '🎵'
            $result2 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\MediaPlayer\Player\RecentURLList' -Description 'URL recenti Media Player' -Icon '🎵'
            $result3 = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Gabest\Media Player Classic\Recent File List' -Description 'MPC cronologia' -Icon '🎵'

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount
            Write-StyledMessage Success "✅ Cronologia Media Player pulita"
            $script:Log += "[MediaPlayerHistory] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia Media Player: $_"
            $script:Log += "[MediaPlayerHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DirectXHistoryCleanup {
        Write-StyledMessage Info "🎮 Pulizia cronologia applicazioni DirectX..."
        try {
            $result = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\Direct3D\MostRecentApplication' -Description 'Cronologia applicazioni DirectX' -Icon '🎮'

            Write-StyledMessage Success "✅ Cronologia DirectX pulita"
            $script:Log += "[DirectXHistory] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia DirectX: $_"
            $script:Log += "[DirectXHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-RunCommandHistoryCleanup {
        Write-StyledMessage Info "▶️ Pulizia cronologia comandi Esegui..."
        try {
            $result = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU' -Description 'Cronologia comandi Esegui' -Icon '▶️'

            Write-StyledMessage Success "✅ Cronologia comandi Esegui pulita"
            $script:Log += "[RunCommandHistory] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia Esegui: $_"
            $script:Log += "[RunCommandHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-FileExplorerAddressBarHistoryCleanup {
        Write-StyledMessage Info "📂 Pulizia cronologia barra indirizzi Esplora File..."
        try {
            $result = Invoke-ClearRegistryKeyValues -KeyPath 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths' -Description 'Cronologia barra indirizzi Esplora File' -Icon '📂'

            Write-StyledMessage Success "✅ Cronologia barra indirizzi pulita"
            $script:Log += "[FileExplorerAddressBarHistory] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia barra indirizzi: $_"
            $script:Log += "[FileExplorerAddressBarHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-VisualStudioLicensesCleanup {
        Write-StyledMessage Info "💻 Pulizia licenze Visual Studio..."
        try {
            $result1 = Invoke-RemoveRegistryKeyFull -KeyPath 'HKLM\SOFTWARE\Classes\Licenses\77550D6B-6352-4E77-9DA3-537419DF564B' -Description 'Licenza Visual Studio 2010' -Icon '💻'
            $result2 = Invoke-RemoveRegistryKeyFull -KeyPath 'HKLM\SOFTWARE\Classes\Licenses\E79B3F9C-6543-4897-BBA5-5BFB0A02BB5C' -Description 'Licenza Visual Studio 2013' -Icon '💻'
            $result3 = Invoke-RemoveRegistryKeyFull -KeyPath 'HKLM\SOFTWARE\Classes\Licenses\4D8CFBCB-2F6A-4AD2-BABF-10E28F6F2C8F' -Description 'Licenza Visual Studio 2015' -Icon '💻'
            $result4 = Invoke-RemoveRegistryKeyFull -KeyPath 'HKLM\SOFTWARE\Classes\Licenses\5C505A59-E312-4B89-9508-E162F8150517' -Description 'Licenza Visual Studio 2017' -Icon '💻'
            $result5 = Invoke-RemoveRegistryKeyFull -KeyPath 'HKLM\SOFTWARE\Classes\Licenses\41717607-F34E-432C-A138-A3CFD7E25CDA' -Description 'Licenza Visual Studio 2019' -Icon '💻'
            $result6 = Invoke-RemoveRegistryKeyFull -KeyPath 'HKLM\SOFTWARE\Classes\Licenses\B16F0CF0-8AD1-4A5B-87BC-CB0DBE9C48FC' -Description 'Licenza Visual Studio 2022' -Icon '💻'
            $result7 = Invoke-RemoveRegistryKeyFull -KeyPath 'HKLM\SOFTWARE\Classes\Licenses\10D17DBA-761D-4CD8-A627-984E75A58700' -Description 'Licenza Visual Studio 2022' -Icon '💻'
            $result8 = Invoke-RemoveRegistryKeyFull -KeyPath 'HKLM\SOFTWARE\Classes\Licenses\1299B4B9-DFCC-476D-98F0-F65A2B46C96D' -Description 'Licenza Visual Studio 2022' -Icon '💻'

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount + $result4.ErrorCount + $result5.ErrorCount + $result6.ErrorCount + $result7.ErrorCount + $result8.ErrorCount
            Write-StyledMessage Success "✅ Licenze Visual Studio pulite"
            $script:Log += "[VisualStudioLicenses] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia licenze Visual Studio: $_"
            $script:Log += "[VisualStudioLicenses] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ListarySearchIndexCleanup {
        Write-StyledMessage Info "📊 Pulizia indice di ricerca Listary..."
        try {
            $result = Invoke-DeletePaths -Paths @("%APPDATA%\Listary\UserData") -Description 'Indice di ricerca Listary' -Icon '📊' -PerUser $true

            Write-StyledMessage Success "✅ Indice Listary pulito"
            $script:Log += "[ListarySearchIndex] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia indice Listary: $_"
            $script:Log += "[ListarySearchIndex] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-JavaCacheCleanup {
        Write-StyledMessage Info "☕ Pulizia cache Java..."
        try {
            $result = Invoke-DeletePaths -Paths @("%APPDATA%\Sun\Java\Deployment\cache") -Description 'Cache Java' -Icon '☕' -PerUser $true

            Write-StyledMessage Success "✅ Cache Java pulita"
            $script:Log += "[JavaCache] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cache Java: $_"
            $script:Log += "[JavaCache] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DotnetTelemetryCleanup {
        Write-StyledMessage Info "🌐 Pulizia telemetria Dotnet CLI..."
        try {
            $result = Invoke-DeletePaths -Paths @("%USERPROFILE%\.dotnet\TelemetryStorageService") -Description 'Telemetria Dotnet CLI' -Icon '🌐' -PerUser $true

            Write-StyledMessage Success "✅ Telemetria Dotnet pulita"
            $script:Log += "[DotnetTelemetry] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia telemetria Dotnet: $_"
            $script:Log += "[DotnetTelemetry] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ChromeCleanup {
        Write-StyledMessage Info "🌐 Pulizia dati e crash report Chrome..."
        try {
            $result1 = Invoke-DeletePaths -Paths @("%LOCALAPPDATA%\Google\Chrome\User Data\Crashpad\reports", "%LOCALAPPDATA%\Google\CrashReports") -Description 'Crash Report Chrome' -Icon '🌐'
            $result2 = Invoke-DeletePaths -Paths @("%LOCALAPPDATA%\Google\Software Reporter Tool\*.log") -Description 'Log Software Reporter Tool di Google' -Icon '🌐' -FilesOnly $true
            $result3 = Invoke-DeletePaths -Paths @("%USERPROFILE%\Local Settings\Application Data\Google\Chrome\User Data", "%LOCALAPPDATA%\Google\Chrome\User Data") -Description 'Dati utente Chrome' -Icon '🌐' -TakeOwnership $true -PerUser $true

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount
            Write-StyledMessage Success "✅ Dati Chrome puliti"
            $script:Log += "[ChromeCleanup] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Chrome: $_"
            $script:Log += "[ChromeCleanup] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-FirefoxCleanup {
        Write-StyledMessage Info "🦊 Pulizia cronologia e profili Firefox..."
        try {
            $result1 = Invoke-DeletePaths -Paths @("%USERPROFILE%\Local Settings\Application Data\Mozilla\Firefox\Profiles\*\downloads.rdf", "%APPDATA%\Mozilla\Firefox\Profiles\*\downloads.rdf", "%LOCALAPPDATA%\Packages\Mozilla.Firefox_n80bbvh6b1yt2\LocalCache\Roaming\Mozilla\Firefox\Profiles\*\downloads.rdf") -Description 'Cronologia download Firefox (RDF)' -Icon '🦊' -FilesOnly $true -PerUser $true
            $result2 = Invoke-DeletePaths -Paths @("%USERPROFILE%\Local Settings\Application Data\Mozilla\Firefox\Profiles\*\downloads.sqlite", "%APPDATA%\Mozilla\Firefox\Profiles\*\downloads.sqlite", "%LOCALAPPDATA%\Packages\Mozilla.Firefox_n80bbvh6b1yt2\LocalCache\Roaming\Mozilla\Firefox\Profiles\*\downloads.sqlite") -Description 'Cronologia download Firefox (SQLite)' -Icon '🦊' -FilesOnly $true -PerUser $true
            $result3 = Invoke-DeletePaths -Paths @("%USERPROFILE%\Local Settings\Application Data\Mozilla\Firefox\Profiles\*\places.sqlite", "%APPDATA%\Mozilla\Firefox\Profiles\*\places.sqlite", "%LOCALAPPDATA%\Packages\Mozilla.Firefox_n80bbvh6b1yt2\LocalCache\Roaming\Mozilla\Firefox\Profiles\*\places.sqlite") -Description 'Cronologia navigazione Firefox' -Icon '🦊' -FilesOnly $true -PerUser $true
            $result4 = Invoke-DeletePaths -Paths @("%USERPROFILE%\Local Settings\Application Data\Mozilla\Firefox\Profiles\*\favicons.sqlite", "%APPDATA%\Mozilla\Firefox\Profiles\*\favicons.sqlite", "%LOCALAPPDATA%\Packages\Mozilla.Firefox_n80bbvh6b1yt2\LocalCache\Roaming\Mozilla\Firefox\Profiles\*\favicons.sqlite") -Description 'Favicons Firefox' -Icon '🦊' -FilesOnly $true -PerUser $true
            $result5 = Invoke-DeletePaths -Paths @("%LOCALAPPDATA%\Mozilla\Firefox\Profiles", "%APPDATA%\Mozilla\Firefox\Profiles", "%LOCALAPPDATA%\Packages\Mozilla.Firefox_n80bbvh6b1yt2\LocalCache\Roaming\Mozilla\Firefox\Profiles") -Description 'Profili utente Firefox' -Icon '🦊' -PerUser $true

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount + $result4.ErrorCount + $result5.ErrorCount
            Write-StyledMessage Success "✅ Firefox pulito"
            $script:Log += "[FirefoxCleanup] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Firefox: $_"
            $script:Log += "[FirefoxCleanup] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-SafariCleanup {
        Write-StyledMessage Info "🍎 Pulizia dati e cache Safari..."
        try {
            $result1 = Invoke-DeletePaths -Paths @("%USERPROFILE%\Local Settings\Application Data\Safari\WebpageIcons.db", "%LOCALAPPDATA%\Apple Computer\Safari\WebpageIcons.db") -Description 'Webpage Icons Safari' -Icon '🍎' -FilesOnly $true -PerUser $true
            $result2 = Invoke-DeletePaths -Paths @("%USERPROFILE%\Local Settings\Application Data\Apple Computer\Safari\Cache.db", "%LOCALAPPDATA%\Apple Computer\Safari\Cache.db") -Description 'Cache Safari' -Icon '🍎' -FilesOnly $true -PerUser $true
            $result3 = Invoke-DeletePaths -Paths @("%USERPROFILE%\Local Settings\Application Data\Apple Computer\Safari\Cookies.db", "%LOCALAPPDATA%\Apple Computer\Safari\Cookies.db") -Description 'Cookie Safari' -Icon '🍎' -FilesOnly $true -PerUser $true
            $result4 = Invoke-DeletePaths -Paths @("%USERPROFILE%\Local Settings\Application Data\Apple Computer\Safari", "%APPDATA%\Apple Computer\Safari") -Description 'Dati utente Safari' -Icon '🍎' -TakeOwnership $true -PerUser $true

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount + $result4.ErrorCount
            Write-StyledMessage Success "✅ Safari pulito"
            $script:Log += "[SafariCleanup] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Safari: $_"
            $script:Log += "[SafariCleanup] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-OperaCleanup {
        Write-StyledMessage Info "🅾️ Pulizia dati e cronologia Opera..."
        try {
            $result = Invoke-DeletePaths -Paths @("%USERPROFILE%\Local Settings\Application Data\Opera\Opera", "%LOCALAPPDATA%\Opera\Opera", "%APPDATA%\Opera\Opera") -Description 'Dati utente Opera' -Icon '🅾️' -PerUser $true

            Write-StyledMessage Success "✅ Opera pulito"
            $script:Log += "[OperaCleanup] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Opera: $_"
            $script:Log += "[OperaCleanup] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-SystemLogFileCleanup {
        Write-StyledMessage Info "📄 Pulizia log di sistema e applicazioni varie..."
        try {
            $result1 = Invoke-DeletePaths -Paths @("%SYSTEMROOT%\Temp\CBS", "%SYSTEMROOT%\Logs\waasmedic", "%SYSTEMROOT%\Logs\SIH", "%SYSTEMROOT%\Traces\WindowsUpdate", "%SYSTEMROOT%\Logs\NetSetup", "%SYSTEMROOT%\System32\LogFiles\setupcln") -Description 'Log di sistema vari' -Icon '📄'
            $result2 = Invoke-DeletePaths -Paths @("%SYSTEMROOT%\Panther") -Description 'Cartella log Panther' -Icon '📄'
            $result3 = Invoke-DeletePaths -Paths @("%SYSTEMROOT%\comsetup.log", "%SYSTEMROOT%\DtcInstall.log", "%SYSTEMROOT%\PFRO.log", "%SYSTEMROOT%\setupact.log", "%SYSTEMROOT%\setuperr.log", "%SYSTEMROOT%\inf\setupapi.app.log", "%SYSTEMROOT%\inf\setupapi.dev.log", "%SYSTEMROOT%\inf\setupapi.offline.log", "%SYSTEMROOT%\Performance\WinSAT\winsat.log", "%SYSTEMROOT%\debug\PASSWD.LOG", "%SYSTEMROOT%\System32\catroot2\dberr.txt", "%SYSTEMROOT%\System32\catroot2.log", "%SYSTEMROOT%\System32\catroot2.jrs", "%SYSTEMROOT%\System32\catroot2.edb", "%SYSTEMROOT%\System32\catroot2.chk", "%SYSTEMROOT%\Logs\CBS\CBS.log", "%SYSTEMROOT%\Logs\DISM\DISM.log") -Description 'File log di sistema specifici' -Icon '📄' -FilesOnly $true

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount
            Write-StyledMessage Success "✅ Log di sistema puliti"
            $script:Log += "[SystemLogFileCleanup] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia log di sistema: $_"
            $script:Log += "[SystemLogFileCleanup] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-CLRUsageTracesCleanup {
        Write-StyledMessage Info "💻 Pulizia tracce di utilizzo .NET CLR..."
        try {
            $result = Invoke-DeletePaths -Paths @("%LOCALAPPDATA%\Microsoft\CLR_v4.0\UsageTraces", "%LOCALAPPDATA%\Microsoft\CLR_v4.0_32\UsageTraces") -Description 'Tracce di utilizzo .NET CLR' -Icon '💻' -PerUser $true

            Write-StyledMessage Success "✅ Tracce .NET CLR pulite"
            $script:Log += "[CLRUsageTraces] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia tracce .NET CLR: $_"
            $script:Log += "[CLRUsageTraces] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-RecycleBinEmpty {
        Write-StyledMessage Info "🗑️ Svuotamento cestino..."
        try {
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(0xA)
            $recycleBin.Items() | ForEach-Object { $_.InvokeVerb("delete") }

            Write-StyledMessage Success "✅ Cestino svuotato"
            $script:Log += "[RecycleBinEmpty] ✅ Svuotamento completato"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning "Errore durante svuotamento cestino: $_"
            $script:Log += "[RecycleBinEmpty] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-CredentialManagerCleanup {
        Write-StyledMessage Info "🔑 Pulizia credenziali Windows..."
        try {
            $credentials = cmdkey /list 2>$null | Where-Object { $_ -match '^Target:' } | ForEach-Object { $_.Split(':')[1].Trim() }
            foreach ($cred in $credentials) {
                cmdkey /delete:$cred 2>$null | Out-Null
            }

            Write-StyledMessage Success "✅ Credenziali pulite"
            $script:Log += "[CredentialManager] ✅ Pulizia completata"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia credenziali: $_"
            $script:Log += "[CredentialManager] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-MinimizeDISMResetBase {
        Write-StyledMessage Info "📊 Minimizzazione dati aggiornamenti DISM..."
        try {
            $result = Invoke-SetRegistryKeyValue -KeyPath 'HKLM\Software\Microsoft\Windows\CurrentVersion\SideBySide\Configuration' -ValueName 'DisableResetbase' -ValueData 0 -ValueType DWORD -Description 'Valore DisableResetbase per DISM' -Icon '📊'

            Write-StyledMessage Success "✅ DISM configurato"
            $script:Log += "[MinimizeDISMResetBase] ✅ Configurazione completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante configurazione DISM: $_"
            $script:Log += "[MinimizeDISMResetBase] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WindowsUpdateFilesCleanup {
        Write-StyledMessage Info "🔄 Pulizia file temporanei Windows Update..."
        try {
            $result1 = Invoke-ServiceControl -ServiceName 'wuauserv' -Action 'Stop' -Description 'Servizio Windows Update' -Icon '🔄'
            $result2 = Invoke-DeletePaths -Paths @("%SYSTEMROOT%\SoftwareDistribution") -Description 'Cartella SoftwareDistribution' -Icon '🔄'
            $result3 = Invoke-ServiceControl -ServiceName 'wuauserv' -Action 'Start' -Description 'Servizio Windows Update' -Icon '🔄'

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount
            Write-StyledMessage Success "✅ File Windows Update puliti"
            $script:Log += "[WindowsUpdateFiles] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia Windows Update: $_"
            $script:Log += "[WindowsUpdateFiles] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DiagTrackLogsCleanup {
        Write-StyledMessage Info "🚫 Pulizia log di tracciamento diagnostica..."
        try {
            $result1 = Invoke-ServiceControl -ServiceName 'DiagTrack' -Action 'Stop' -Description 'Servizio di Tracciamento Diagnostica' -Icon '🚫'
            $result2 = Invoke-DeletePaths -Paths @("%PROGRAMDATA%\Microsoft\Diagnosis\ETLLogs\AutoLogger\AutoLogger-Diagtrack-Listener.etl", "%PROGRAMDATA%\Microsoft\Diagnosis\ETLLogs\ShutdownLogger\AutoLogger-Diagtrack-Listener.etl") -Description 'Log di tracciamento diagnostica' -Icon '🚫' -FilesOnly $true -TakeOwnership $true
            $result3 = Invoke-ServiceControl -ServiceName 'DiagTrack' -Action 'Start' -Description 'Servizio di Tracciamento Diagnostica' -Icon '🚫'

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount
            Write-StyledMessage Success "✅ Log DiagTrack puliti"
            $script:Log += "[DiagTrackLogs] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia DiagTrack: $_"
            $script:Log += "[DiagTrackLogs] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DefenderProtectionHistoryCleanup {
        Write-StyledMessage Info "🛡️ Pulizia cronologia protezione Windows Defender..."
        try {
            $result = Invoke-DeletePaths -Paths @("%ProgramData%\Microsoft\Windows Defender\Scans\History") -Description 'Cronologia protezione Windows Defender' -Icon '🛡️' -TakeOwnership $true

            Write-StyledMessage Success "✅ Cronologia Defender pulita"
            $script:Log += "[DefenderProtectionHistory] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia cronologia Defender: $_"
            $script:Log += "[DefenderProtectionHistory] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-SystemResourceUsageMonitorCleanup {
        Write-StyledMessage Info "📈 Pulizia dati SRUM..."
        try {
            $result1 = Invoke-ServiceControl -ServiceName 'DPS' -Action 'Stop' -Description 'Servizio Monitoraggio Utilizzo Risorse' -Icon '📈'
            $result2 = Invoke-DeletePaths -Paths @("%SYSTEMROOT%\System32\sru\SRUDB.dat") -Description 'Database SRUM' -Icon '📈' -FilesOnly $true -TakeOwnership $true
            $result3 = Invoke-ServiceControl -ServiceName 'DPS' -Action 'Start' -Description 'Servizio Monitoraggio Utilizzo Risorse' -Icon '📈'

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount + $result3.ErrorCount
            Write-StyledMessage Success "✅ Dati SRUM puliti"
            $script:Log += "[SystemResourceUsageMonitor] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia SRUM: $_"
            $script:Log += "[SystemResourceUsageMonitor] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-VisualStudioTelemetryRootCleanup {
        Write-StyledMessage Info "💻 Pulizia telemetria Visual Studio..."
        try {
            $result1 = Invoke-DeletePaths -Paths @("%LOCALAPPDATA%\Microsoft\VSCommon\14.0\SQM", "%LOCALAPPDATA%\Microsoft\VSCommon\15.0\SQM", "%LOCALAPPDATA%\Microsoft\VSCommon\16.0\SQM", "%LOCALAPPDATA%\Microsoft\VSCommon\17.0\SQM", "%LOCALAPPDATA%\Microsoft\VSApplicationInsights", "%TEMP%\Microsoft\VSApplicationInsights", "%APPDATA%\vstelemetry", "%TEMP%\VSFaultInfo", "%TEMP%\VSFeedbackPerfWatsonData", "%TEMP%\VSFeedbackVSRTCLogs", "%TEMP%\VSFeedbackIntelliCodeLogs", "%TEMP%\VSRemoteControl", "%TEMP%\Microsoft\VSFeedbackCollector", "%TEMP%\VSTelem", "%TEMP%\VSTelem.Out") -Description 'Telemetria Visual Studio per-utente' -Icon '💻' -PerUser $true
            $result2 = Invoke-DeletePaths -Paths @("%PROGRAMDATA%\Microsoft\VSApplicationInsights", "%PROGRAMDATA%\vstelemetry") -Description 'Telemetria Visual Studio globale' -Icon '💻'

            $totalErrors = $result1.ErrorCount + $result2.ErrorCount
            Write-StyledMessage Success "✅ Telemetria Visual Studio pulita"
            $script:Log += "[VisualStudioTelemetry] ✅ Pulizia completata"
            return @{ Success = ($totalErrors -eq 0); ErrorCount = $totalErrors }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia telemetria Visual Studio: $_"
            $script:Log += "[VisualStudioTelemetry] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WindowsSystemProfilesTempCleanup {
        Write-StyledMessage Info "👤 Pulizia temp profili di servizio Windows..."
        try {
            $result = Invoke-DeletePaths -Paths @("%SYSTEMROOT%\ServiceProfiles\LocalService\AppData\Local\Temp") -Description 'Temp profili di servizio Windows' -Icon '👤'

            Write-StyledMessage Success "✅ Temp profili servizio puliti"
            $script:Log += "[WindowsSystemProfilesTemp] ✅ Pulizia completata"
            return @{ Success = ($result.ErrorCount -eq 0); ErrorCount = $result.ErrorCount }
        }
        catch {
            Write-StyledMessage Warning "Errore durante pulizia temp profili servizio: $_"
            $script:Log += "[WindowsSystemProfilesTemp] Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

        $totalCleaned = 0
        $totalSize = 0

        foreach ($path in $logPaths) {
            # Verifica esclusione cartella WinToolkit
            if (Test-ExcludedPath $path) {
                continue
            }

            if (Test-Path $path) {
                try {
                    $files = Get-ChildItem -Path $path -Recurse -File -Include "*.log", "*.etl", "*.txt" -ErrorAction SilentlyContinue | Where-Object {
                        -not (Test-ExcludedPath $_.FullName)
                    }
                    $size = ($files | Measure-Object -Property Length -Sum).Sum / 1MB
                    $files | Remove-Item -Force -ErrorAction SilentlyContinue
                    $totalCleaned += $files.Count
                    $totalSize += $size
                    Write-StyledMessage Info "🗑️ Puliti log da: $path"
                }
                catch {
                    Write-StyledMessage Warning " Impossibile pulire alcuni log in $path"
                }
            }
        }

        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Log di sistema puliti ($totalCleaned file, $([math]::Round($totalSize, 2)) MB)"
            $script:Log += "[SystemLogs] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessun log di sistema da pulire"
            $script:Log += "[SystemLogs] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
        }
    }
    
    function Invoke-WindowsOldCleanup {
        Write-StyledMessage Info "🗑️ Pulizia cartella Windows.old..."
        $windowsOldPath = "C:\Windows.old"
        $errorCount = 0
    
        try {
            if (Test-Path -Path $windowsOldPath) {
                Write-StyledMessage Info "🔍 Trovata cartella Windows.old. Tentativo di rimozione forzata..."
                $script:Log += "[WindowsOld] 🔍 Trovata cartella Windows.old. Tentativo di rimozione forzata..."
    
                # 1. Assumere la proprietà (Take Ownership)
                Write-StyledMessage Info "1. Assunzione della proprietà (Take Ownership)..."
                $takeownResult = cmd /c takeown /F $windowsOldPath /R /A /D Y 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-StyledMessage Warning "❌ Errore durante l'assunzione della proprietà: $takeownResult"
                    $script:Log += "[WindowsOld] ❌ Errore takeown: $takeownResult"
                    $errorCount++
                }
                else {
                    Write-StyledMessage Info "✅ Proprietà assunta."
                    $script:Log += "[WindowsOld] ✅ Proprietà assunta."
                }
                Start-Sleep -Milliseconds 500 # Give system a moment
    
                # 2. Assegnare i permessi di controllo completo agli amministratori
                Write-StyledMessage Info "2. Assegnazione dei permessi di Controllo Completo (Full Control)..."
                $icaclsResult = cmd /c icacls $windowsOldPath /T /grant Administrators:F 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-StyledMessage Warning "❌ Errore durante l'assegnazione permessi: $icaclsResult"
                    $script:Log += "[WindowsOld] ❌ Errore icacls: $icaclsResult"
                    $errorCount++
                }
                else {
                    Write-StyledMessage Info "✅ Permessi di controllo completo assegnati agli Amministratori."
                    $script:Log += "[WindowsOld] ✅ Permessi di controllo completo assegnati agli Amministratori."
                }
                Start-Sleep -Milliseconds 500 # Give system a moment
    
                # 3. Rimuovere la cartella con la forzatura
                Write-StyledMessage Info "3. Rimozione forzata della cartella..."
                try {
                    Remove-Item -Path $windowsOldPath -Recurse -Force -ErrorAction Stop
                }
                catch {
                    Write-StyledMessage Error "❌ ERRORE durante la rimozione di Windows.old: $($_.Exception.Message)"
                    $script:Log += "[WindowsOld] ❌ ERRORE durante la rimozione: $($_.Exception.Message)"
                    $errorCount++
                }
                
                # 4. Verifica finale
                if (Test-Path -Path $windowsOldPath) {
                    Write-StyledMessage Error "❌ ERRORE: La cartella $windowsOldPath non è stata rimossa."
                    $script:Log += "[WindowsOld] ❌ Cartella non rimossa dopo tentativi forzati."
                    $errorCount++
                }
                else {
                    Write-StyledMessage Success "✅ La cartella Windows.old è stata rimossa con successo."
                    $script:Log += "[WindowsOld] ✅ Rimozione completata."
                }
            }
            else {
                Write-StyledMessage Info "💭 La cartella Windows.old non è presente. Nessuna azione necessaria."
                $script:Log += "[WindowsOld] ℹ️ Non presente, nessuna azione."
            }
        }
        catch {
            Write-StyledMessage Error "Errore fatale durante la pulizia di Windows.old: $($_.Exception.Message)"
            $script:Log += "[WindowsOld] 💥 Errore fatale: $($_.Exception.Message)"
            $errorCount++
        }
    
        return @{ Success = ($errorCount -eq 0); ErrorCount = $errorCount }
    }
    
    function Invoke-CleanupTask([hashtable]$Task, [int]$Step, [int]$Total) {
        Write-StyledMessage Info "[$Step/$Total] Avvio $($Task.Name)..."
        $percent = 0; $spinnerIndex = 0

        try {
            $result = switch ($Task.Task) {
                'CleanMgrAuto' { Invoke-CleanMgrAuto }
                'WinSxS' { Invoke-WinSxSCleanup }
                'ErrorReports' { Invoke-ErrorReportsCleanup }
                'EventLogs' { Invoke-EventLogsCleanup }
                'UpdateHistory' { Invoke-UpdateHistoryCleanup }
                'RestorePoints' { Invoke-RestorePointsCleanup }
                'DownloadCache' { Invoke-DownloadCacheCleanup }
                'PrefetchCleanup' { Invoke-PrefetchCleanup }
                'ThumbnailCache' { Invoke-ThumbnailCacheCleanup }
                'WinInetCacheCleanup' { Invoke-WinInetCacheCleanup }
                'InternetCookiesCleanup' { Invoke-InternetCookiesCleanup }
                'DNSFlush' { Invoke-DNSFlush }
                'WindowsTempCleanup' { Invoke-WindowsTempCleanup }
                'UserTempCleanup' { Invoke-UserTempCleanup }
                'PrintQueue' { Invoke-PrintQueueCleanup }
                'SystemLogs' { Invoke-SystemLogsCleanup }
                'QuickAccessAndRecentFilesCleanup' { Invoke-QuickAccessAndRecentFilesCleanup }
                'RegeditHistoryCleanup' { Invoke-RegeditHistoryCleanup }
                'ComDlg32HistoryCleanup' { Invoke-ComDlg32HistoryCleanup }
                'AdobeMediaBrowserCleanup' { Invoke-AdobeMediaBrowserCleanup }
                'PaintAndWordPadHistoryCleanup' { Invoke-PaintAndWordPadHistoryCleanup }
                'NetworkDriveHistoryCleanup' { Invoke-NetworkDriveHistoryCleanup }
                'WindowsSearchHistoryCleanup' { Invoke-WindowsSearchHistoryCleanup }
                'MediaPlayerHistoryCleanup' { Invoke-MediaPlayerHistoryCleanup }
                'DirectXHistoryCleanup' { Invoke-DirectXHistoryCleanup }
                'RunCommandHistoryCleanup' { Invoke-RunCommandHistoryCleanup }
                'FileExplorerAddressBarHistoryCleanup' { Invoke-FileExplorerAddressBarHistoryCleanup }
                'ListarySearchIndexCleanup' { Invoke-ListarySearchIndexCleanup }
                'JavaCacheCleanup' { Invoke-JavaCacheCleanup }
                'DotnetTelemetryCleanup' { Invoke-DotnetTelemetryCleanup }
                'ChromeCleanup' { Invoke-ChromeCleanup }
                'FirefoxCleanup' { Invoke-FirefoxCleanup }
                'SafariCleanup' { Invoke-SafariCleanup }
                'OperaCleanup' { Invoke-OperaCleanup }
                'CLRUsageTracesCleanup' { Invoke-CLRUsageTracesCleanup }
                'VisualStudioTelemetryRootCleanup' { Invoke-VisualStudioTelemetryRootCleanup }
                'VisualStudioLicensesCleanup' { Invoke-VisualStudioLicensesCleanup }
                'WindowsSystemProfilesTempCleanup' { Invoke-WindowsSystemProfilesTempCleanup }
                'SystemLogFileCleanup' { Invoke-SystemLogFileCleanup }
                'MinimizeDISMResetBase' { Invoke-MinimizeDISMResetBase }
                'WindowsUpdateFilesCleanup' { Invoke-WindowsUpdateFilesCleanup }
                'DiagTrackLogsCleanup' { Invoke-DiagTrackLogsCleanup }
                'DefenderProtectionHistoryCleanup' { Invoke-DefenderProtectionHistoryCleanup }
                'SystemResourceUsageMonitorCleanup' { Invoke-SystemResourceUsageMonitorCleanup }
                'CredentialManagerCleanup' { Invoke-CredentialManagerCleanup }
                'RecycleBinEmpty' { Invoke-RecycleBinEmpty }
                'WindowsOld' { Invoke-WindowsOldCleanup }
            }

            if ($result.Success) {
                Write-StyledMessage Success "$($Task.Icon) $($Task.Name) completato con successo"
            }
            else {
                Write-StyledMessage Warning "$($Task.Icon) $($Task.Name) completato con errori"
            }

            return $result
        }
        catch {
            Write-StyledMessage Error "Errore durante $($Task.Name): $_"
            $script:Log += "[$($Task.Name)]  Errore fatale: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )

        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))

        return (' ' * $padding + $Text)
    }

    function Show-Header {
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
            '    Cleaner Toolkit By MagnetarMan',
            '       Version 2.3.0 (Build 8)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    Show-Header

    for ($i = 5; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    try {
        Write-StyledMessage Info '🧹 Avvio pulizia completa del sistema...'
        Write-Host ''

        $totalErrors = $successCount = 0
        for ($i = 0; $i -lt $CleanupTasks.Count; $i++) {
            $result = Invoke-CleanupTask $CleanupTasks[$i] ($i + 1) $CleanupTasks.Count
            if ($result.Success) { $successCount++ }
            $totalErrors += $result.ErrorCount
            Start-Sleep 1
        }

        Write-Host ''
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-StyledMessage Success "🎉 Pulizia completata con successo!"
        Write-StyledMessage Success "💻 Completati $successCount/$($CleanupTasks.Count) task di pulizia"

        if ($totalErrors -gt 0) {
            Write-StyledMessage Warning " $totalErrors errori durante la pulizia"
        }

        # Mostra riepilogo dettagliato
        Write-Host ''
        Write-StyledMessage Info "📊 RIEPILOGO OPERAZIONI:"
        foreach ($logEntry in $script:Log) {
            if ($logEntry -match '✅|||ℹ️') {
                Write-Host "  $logEntry" -ForegroundColor Gray
            }
        }

        Write-StyledMessage Info "🔄 Il sistema verrà riavviato per applicare tutte le modifiche"
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-Host ''

        $shouldReboot = Start-InterruptibleCountdown $CountdownSeconds "Preparazione riavvio sistema"

        if ($shouldReboot) {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
            Restart-Computer -Force
        }
        else {
            Write-StyledMessage Success "✅ Pulizia completata. Sistema non riavviato."
            Write-StyledMessage Info "💡 Riavvia quando possibile per applicare tutte le modifiche."
        }
    }
    catch {
        Write-Host ''
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage Error "💥 Errore critico: $($_.Exception.Message)"
        Write-StyledMessage Error ' Si è verificato un errore durante la pulizia.'
        Write-Host ('═' * 65) -ForegroundColor Red
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
        try { Stop-Transcript | Out-Null } catch {}
    }
}

WinCleaner