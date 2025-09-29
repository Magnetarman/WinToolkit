function WinCleaner {
    <#
    .SYNOPSIS
        Script automatico per la pulizia completa del sistema Windows.

    .DESCRIPTION
        Questo script esegue una pulizia completa e automatica del sistema Windows,
        utilizzando cleanmgr.exe con configurazione automatica (/sageset e /sagerun)
        e pulendo manualmente tutti i componenti specificati:
        - WinSxS Assemblies sostituiti
        - Rapporti Errori Windows
        - Registro Eventi Windows
        - Cronologia Installazioni Windows Update
        - Punti di Ripristino del sistema
        - Cache Download Windows
        - Cache .NET
        - Prefetch Windows
        - Cache Miniature Explorer
        - Cache web WinInet
        - Cookie Internet
    #>

    param([int]$CountdownSeconds = 30)

    $Host.UI.RawUI.WindowTitle = "Cleaner Toolkit By MagnetarMan"
    $script:Log = @(); $script:CurrentAttempt = 0
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
        @{ Task = 'DotNetCache'; Name = 'Cache .NET Framework'; Icon = '🔧'; Auto = $false }
        @{ Task = 'Prefetch'; Name = 'Cache Prefetch Windows'; Icon = '⚡'; Auto = $false }
        @{ Task = 'ThumbnailCache'; Name = 'Cache miniature Explorer'; Icon = '🖼️'; Auto = $false }
        @{ Task = 'WinInetCache'; Name = 'Cache web WinInet'; Icon = '🌐'; Auto = $false }
        @{ Task = 'InternetCookies'; Name = 'Cookie Internet'; Icon = '🍪'; Auto = $false }
    )

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '▒' * (30 - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -eq 100) { Write-Host '' }
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
        Write-StyledMessage Info "🧹 Configurazione pulizia automatica CleanMgr..."
        $percent = 0; $spinnerIndex = 0

        try {
            # Configurazione sageset:1 con tutte le opzioni
            Write-StyledMessage Info "⚙️ Configurazione opzioni pulizia (sageset:1)..."
            Start-Process 'cleanmgr.exe' -ArgumentList '/d C: /sageset:1' -Wait -WindowStyle Hidden

            # Esecuzione sagerun:1
            Write-StyledMessage Info "🚀 Avvio pulizia automatica (sagerun:1)..."
            $proc = Start-Process 'cleanmgr.exe' -ArgumentList '/sagerun:1' -NoNewWindow -PassThru

            while (-not $proc.HasExited) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                if ($percent -lt 95) { $percent += Get-Random -Minimum 1 -Maximum 3 }
                Show-ProgressBar "Pulizia CleanMgr" 'Esecuzione in corso...' $percent '🧹' $spinner
                Start-Sleep -Milliseconds 800
                $proc.Refresh()
            }

            Show-ProgressBar "Pulizia CleanMgr" 'Completato con successo' 100 '🧹'
            Write-Host ''
            Write-StyledMessage Success "✅ Pulizia automatica CleanMgr completata"

            $script:Log += "[CleanMgrAuto] ✅ Pulizia automatica completata"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Error "Errore durante pulizia CleanMgr: $_"
            $script:Log += "[CleanMgrAuto] ❌ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WinSxSCleanup {
        Write-StyledMessage Info "📦 Pulizia componenti WinSxS sostituiti..."
        $percent = 0; $spinnerIndex = 0

        try {
            $proc = Start-Process 'DISM.exe' -ArgumentList '/Online /Cleanup-Image /StartComponentCleanup /ResetBase' -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\dism_out.txt" -RedirectStandardError "$env:TEMP\dism_err.txt"

            while (-not $proc.HasExited) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                if ($percent -lt 95) { $percent += Get-Random -Minimum 1 -Maximum 2 }
                Show-ProgressBar "WinSxS Cleanup" 'Analisi componenti...' $percent '📦' $spinner
                Start-Sleep -Milliseconds 1000
                $proc.Refresh()
            }

            $exitCode = $proc.ExitCode
            Show-ProgressBar "WinSxS Cleanup" 'Completato' 100 '📦'
            Write-Host ''

            if ($exitCode -eq 0) {
                Write-StyledMessage Success "✅ Componenti WinSxS puliti con successo"
                $script:Log += "[WinSxS] ✅ Pulizia completata"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Warning "⚠️ Pulizia WinSxS completata con warnings (Exit code: $exitCode)"
                $script:Log += "[WinSxS] ⚠️ Completato con warnings (Exit code: $exitCode)"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante pulizia WinSxS: $_"
            $script:Log += "[WinSxS] ❌ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
        finally {
            Remove-Item "$env:TEMP\dism_out.txt", "$env:TEMP\dism_err.txt" -ErrorAction SilentlyContinue
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
            if (Test-Path $path) {
                try {
                    $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
                    $files | Remove-Item -Force -ErrorAction SilentlyContinue
                    $totalCleaned += $files.Count
                    Write-StyledMessage Info "🗑️ Rimosso $($files.Count) file da $path"
                }
                catch {
                    Write-StyledMessage Warning "⚠️ Impossibile pulire $path - $_"
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
            Write-StyledMessage Warning "⚠️ Errore durante pulizia registro eventi: $_"
            $script:Log += "[EventLogs] ⚠️ Errore: $_"
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
            try {
                if (Test-Path $path) {
                    if (Test-Path -Path $path -PathType Container) {
                        $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
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
                Write-StyledMessage Warning "⚠️ Impossibile rimuovere $path - $_"
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
            Write-StyledMessage Warning "⚠️ Errore durante disattivazione punti ripristino: $_"
            $script:Log += "[RestorePoints] ⚠️ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DownloadCacheCleanup {
        Write-StyledMessage Info "⬇️ Pulizia cache download Windows..."
        $downloadPath = "C:\WINDOWS\SoftwareDistribution\Download"

        try {
            if (Test-Path $downloadPath) {
                $files = Get-ChildItem -Path $downloadPath -Recurse -File -ErrorAction SilentlyContinue
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
            Write-StyledMessage Warning "⚠️ Errore durante pulizia cache download: $_"
            $script:Log += "[DownloadCache] ⚠️ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DotNetCacheCleanup {
        Write-StyledMessage Info "🔧 Pulizia cache .NET Framework..."
        $dotnetPaths = @(
            "C:\WINDOWS\assembly",
            "$env:WINDIR\Microsoft.NET"
        )

        $totalCleaned = 0
        foreach ($path in $dotnetPaths) {
            try {
                if (Test-Path $path) {
                    $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
                    $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    $totalCleaned += $files.Count
                    Write-StyledMessage Info "🗑️ Pulita cache .NET: $path"
                }
            }
            catch {
                Write-StyledMessage Warning "⚠️ Impossibile pulire $path - $_"
            }
        }

        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Cache .NET pulita ($totalCleaned file)"
            $script:Log += "[DotNetCache] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessuna cache .NET da pulire"
            $script:Log += "[DotNetCache] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
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
            Write-StyledMessage Warning "⚠️ Errore durante pulizia Prefetch: $_"
            $script:Log += "[Prefetch] ⚠️ Errore: $_"
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
            foreach ($pattern in $thumbnailFiles) {
                try {
                    $files = Get-ChildItem -Path $path -Name $pattern -ErrorAction SilentlyContinue
                    $files | ForEach-Object {
                        $fullPath = Join-Path $path $_
                        Remove-Item -Path $fullPath -Force -ErrorAction SilentlyContinue
                        if (-not (Test-Path $fullPath)) { $totalCleaned++ }
                    }
                }
                catch {
                    Write-StyledMessage Warning "⚠️ Impossibile rimuovere alcuni file in $path"
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
                if (Test-Path $localAppData) {
                    try {
                        $files = Get-ChildItem -Path $localAppData -Recurse -File -ErrorAction SilentlyContinue
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        $totalCleaned += $files.Count
                    }
                    catch {
                        Write-StyledMessage Warning "⚠️ Impossibile pulire cache per utente $($user.Name)"
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
            Write-StyledMessage Warning "⚠️ Errore durante pulizia cache WinInet: $_"
            $script:Log += "[WinInetCache] ⚠️ Errore: $_"
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
                    if (Test-Path $path) {
                        try {
                            $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
                            $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                            $totalCleaned += $files.Count
                        }
                        catch {
                            Write-StyledMessage Warning "⚠️ Impossibile pulire cookie per utente $($user.Name)"
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
            Write-StyledMessage Warning "⚠️ Errore durante pulizia cookie: $_"
            $script:Log += "[InternetCookies] ⚠️ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
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
                'DotNetCache' { Invoke-DotNetCacheCleanup }
                'Prefetch' { Invoke-PrefetchCleanup }
                'ThumbnailCache' { Invoke-ThumbnailCacheCleanup }
                'WinInetCache' { Invoke-WinInetCacheCleanup }
                'InternetCookies' { Invoke-InternetCookiesCleanup }
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
            $script:Log += "[$($Task.Name)] ❌ Errore fatale: $_"
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
            '       Version 2.2 (Build 8)'
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
        Write-Host ('═' * 65) -ForegroundColor Green
        Write-StyledMessage Success "🎉 Pulizia completata con successo!"
        Write-StyledMessage Success "💻 Completati $successCount/$($CleanupTasks.Count) task di pulizia"
        if ($totalErrors -gt 0) {
            Write-StyledMessage Warning "⚠️ $totalErrors errori durante la pulizia"
        }
        Write-StyledMessage Info "🔄 Il sistema verrà riavviato per applicare tutte le modifiche"
        Write-Host ('═' * 65) -ForegroundColor Green
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
        Write-StyledMessage Error '❌ Si è verificato un errore durante la pulizia.'
        Write-Host ('═' * 65) -ForegroundColor Red
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
    }
}

WinCleaner