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
        @{ Task = 'WinSxS'; Name = 'WinSxS - Assembly sostituiti'; Icon = '📦'; Auto = $false }
        @{ Task = 'ErrorReports'; Name = 'Rapporti errori Windows'; Icon = '📋'; Auto = $false }
        @{ Task = 'EventLogs'; Name = 'Registro eventi Windows'; Icon = '📜'; Auto = $false }
        @{ Task = 'UpdateHistory'; Name = 'Cronologia Windows Update'; Icon = '📝'; Auto = $false }
        @{ Task = 'RestorePoints'; Name = 'Punti ripristino sistema'; Icon = '💾'; Auto = $false }
        @{ Task = 'DownloadCache'; Name = 'Cache download Windows'; Icon = '⬇️'; Auto = $false }
        @{ Task = 'Prefetch'; Name = 'Cache Prefetch Windows'; Icon = '⚡'; Auto = $false }
        @{ Task = 'ThumbnailCache'; Name = 'Cache miniature Explorer'; Icon = '🖼️'; Auto = $false }
        @{ Task = 'WinInetCache'; Name = 'Cache web WinInet'; Icon = '🌐'; Auto = $false }
        @{ Task = 'InternetCookies'; Name = 'Cookie Internet'; Icon = '🍪'; Auto = $false }
        @{ Task = 'DNSFlush'; Name = 'Flush cache DNS'; Icon = '🔄'; Auto = $false }
        @{ Task = 'WindowsTemp'; Name = 'File temporanei Windows'; Icon = '🗂️'; Auto = $false }
        @{ Task = 'UserTemp'; Name = 'File temporanei utente'; Icon = '📁'; Auto = $false }
        @{ Task = 'PrintQueue'; Name = 'Coda di stampa'; Icon = '🖨️'; Auto = $false }
        @{ Task = 'SystemLogs'; Name = 'Log di sistema'; Icon = '📄'; Auto = $false }
        @{ Task = 'WindowsOld'; Name = 'Cartella Windows.old'; Icon = '🗑️'; Auto = $false } )

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
            # Backup dei log attuali
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupPath = "$env:TEMP\EventLogs_Backup_$timestamp.evtx"

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
        $prefetchPath = "C:\WINDOWS\Prefetch"

        try {
            if (Test-Path $prefetchPath) {
                $files = Get-ChildItem -Path $prefetchPath -File -ErrorAction SilentlyContinue
                $files | Remove-Item -Force -ErrorAction SilentlyContinue

                Write-StyledMessage Success "✅ Cache Prefetch pulita ($($files.Count) file)"
                $script:Log += "[Prefetch] ✅ Pulizia completata ($($files.Count) file)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Info "💭 Cache Prefetch non presente"
                $script:Log += "[Prefetch] ℹ️ Directory non presente"
                return @{ Success = $true; ErrorCount = 0 }
            }
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
        Write-StyledMessage Info "🌐 Pulizia cache web WinInet..."
        try {
            # Pulisce la cache WinInet per tutti gli utenti
            $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
            $totalCleaned = 0

            foreach ($user in $users) {
                $localAppData = "$($user.FullName)\AppData\Local\Microsoft\Windows\INetCache"

                # Verifica esclusione cartella WinToolkit
                if (Test-ExcludedPath $localAppData) {
                    continue
                }

                if (Test-Path $localAppData) {
                    try {
                        $files = Get-ChildItem -Path $localAppData -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                            -not (Test-ExcludedPath $_.FullName)
                        }
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        $totalCleaned += $files.Count
                    }
                    catch {
                        Write-StyledMessage Warning " Impossibile pulire cache per utente $($user.Name)"
                    }
                }
            }

            # Forza pulizia cache IE
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 8 2>$null
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 2 2>$null

            Write-StyledMessage Success "✅ Cache WinInet pulita ($totalCleaned file)"
            $script:Log += "[WinInetCache] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
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
            # Pulisce i cookie per tutti gli utenti
            $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
            $totalCleaned = 0

            foreach ($user in $users) {
                $cookiesPaths = @(
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\INetCookies",
                    "$($user.FullName)\AppData\Roaming\Microsoft\Windows\Cookies"
                )

                foreach ($path in $cookiesPaths) {
                    # Verifica esclusione cartella WinToolkit
                    if (Test-ExcludedPath $path) {
                        continue
                    }

                    if (Test-Path $path) {
                        try {
                            $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                                -not (Test-ExcludedPath $_.FullName)
                            }
                            $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                            $totalCleaned += $files.Count
                        }
                        catch {
                            Write-StyledMessage Warning " Impossibile pulire cookie per utente $($user.Name)"
                        }
                    }
                }
            }

            # Forza pulizia cookie IE
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 1 2>$null

            Write-StyledMessage Success "✅ Cookie Internet puliti ($totalCleaned file)"
            $script:Log += "[InternetCookies] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
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
        $tempPath = "C:\WINDOWS\Temp"

        try {
            # Verifica esclusione cartella WinToolkit
            if (Test-ExcludedPath $tempPath) {
                Write-StyledMessage Info "💭 Cartella temporanei Windows esclusa dalla pulizia"
                $script:Log += "[WindowsTemp] ℹ️ Directory esclusa"
                return @{ Success = $true; ErrorCount = 0 }
            }

            if (Test-Path $tempPath) {
                $files = Get-ChildItem -Path $tempPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                    -not (Test-ExcludedPath $_.FullName)
                }
                $totalSize = ($files | Measure-Object -Property Length -Sum).Sum / 1MB
                $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

                Write-StyledMessage Success "✅ File temporanei Windows puliti ($($files.Count) file, $([math]::Round($totalSize, 2)) MB)"
                $script:Log += "[WindowsTemp] ✅ Pulizia completata ($($files.Count) file)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Info "💭 Cartella temporanei Windows non presente"
                $script:Log += "[WindowsTemp] ℹ️ Directory non presente"
                return @{ Success = $true; ErrorCount = 0 }
            }
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
            # Pulisce i file temporanei per tutti gli utenti
            $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
            $totalCleaned = 0
            $totalSize = 0

            foreach ($user in $users) {
                $tempPaths = @(
                    "$($user.FullName)\AppData\Local\Temp",
                    "$($user.FullName)\AppData\LocalLow\Temp"
                )

                foreach ($path in $tempPaths) {
                    if (Test-Path $path) {
                        try {
                            # Verifica esclusione cartella WinToolkit
                            if (Test-ExcludedPath $path) {
                                continue
                            }

                            $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                                -not (Test-ExcludedPath $_.FullName)
                            }
                            $size = ($files | Measure-Object -Property Length -Sum).Sum / 1MB
                            $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                            $totalCleaned += $files.Count
                            $totalSize += $size
                        }
                        catch {
                            Write-StyledMessage Warning " Impossibile pulire temp per utente $($user.Name)"
                        }
                    }
                }
            }

            if ($totalCleaned -gt 0) {
                Write-StyledMessage Success "✅ File temporanei utente puliti ($totalCleaned file, $([math]::Round($totalSize, 2)) MB)"
                $script:Log += "[UserTemp] ✅ Pulizia completata ($totalCleaned file)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Info "💭 Nessun file temporaneo utente da pulire"
                $script:Log += "[UserTemp] ℹ️ Nessun file da pulire"
                return @{ Success = $true; ErrorCount = 0 }
            }
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
            "C:\WINDOWS\Panther",
            "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"
        )

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
                'Prefetch' { Invoke-PrefetchCleanup }
                'ThumbnailCache' { Invoke-ThumbnailCacheCleanup }
                'WinInetCache' { Invoke-WinInetCacheCleanup }
                'InternetCookies' { Invoke-InternetCookiesCleanup }
                'DNSFlush' { Invoke-DNSFlush }
                'WindowsTemp' { Invoke-WindowsTempCleanup }
                'UserTemp' { Invoke-UserTempCleanup }
                'PrintQueue' { Invoke-PrintQueueCleanup }
                'SystemLogs' { Invoke-SystemLogsCleanup }
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