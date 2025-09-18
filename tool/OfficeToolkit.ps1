function OfficeToolkit {
    param([int]$CountdownSeconds = 30)

    # Variabili globali
    $script:TempDir = "$env:LOCALAPPDATA\WinToolkit\Office"
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }; Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error = @{ Color = 'Red'; Icon = '❌' }; Info = @{ Color = 'Cyan'; Icon = '💎' }
    }

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
        Write-StyledMessage Info '💡 Premi qualsiasi tasto per annullare il riavvio...'
        Write-Host ''
        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Error '⏸️ Riavvio annullato'
                return $false
            }
            $remainingPercent = 100 - [math]::Round((($Seconds - $i) / $Seconds) * 100)
            Show-ProgressBar 'Countdown Riavvio' "$Message - $i sec" $remainingPercent '⏳' '' 'Red'
            Start-Sleep 1
        }
        Write-Host ''
        Write-StyledMessage Warning '⏰ Riavvio sistema...'
        Start-Sleep 1
        return $true
    }

    function Get-OfficeClient {
        $paths = @(
            "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe",
            "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
        )
        return $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
    }

    function Stop-OfficeProcesses {
        $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'msproject', 'lync')
        $closed = 0
        foreach ($process in $processes) {
            $running = Get-Process -Name $process -ErrorAction SilentlyContinue
            if ($running) {
                $running | Stop-Process -Force -ErrorAction SilentlyContinue
                $closed++
            }
        }
        if ($closed -gt 0) { Write-StyledMessage Success "$closed processi Office terminati" }
    }

    function Wait-ProcessCompletion([string]$ProcessName, [string]$Activity, [string]$Icon) {
        $spinnerIndex = 0
        Start-Sleep 3
        do {
            $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            if ($proc) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                Write-Host "`r$spinner $Icon $Activity..." -NoNewline -ForegroundColor Yellow
                Start-Sleep 1
            }
            else {
                Start-Sleep 2
                $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
                if (-not $proc) { break }
            }
        } while ($proc)
        Write-Host ''
    }

    function Invoke-SystemRestart([string]$Reason) {
        Write-StyledMessage Info "🔄 $Reason - Riavvio necessario"
        if (Start-InterruptibleCountdown $CountdownSeconds 'Riavvio automatico') {
            try { Restart-Computer -Force }
            catch { Write-StyledMessage Error "Errore riavvio: $_" }
        }
    }

    function Start-OfficeInstall {
        Write-StyledMessage Info '🏢 Installazione Office Basic...'
        
        # Crea directory e download
        try {
            if (-not (Test-Path $script:TempDir)) { New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null }
            
            $files = @(
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Setup.exe'; Name = 'Setup.exe'; Icon = '⚙️' },
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/Dev/asset/Basic.xml'; Name = 'Basic.xml'; Icon = '📄' }
            )
            
            foreach ($file in $files) {
                $filePath = Join-Path $script:TempDir $file.Name
                $spinnerIndex = 0
                
                try {
                    $webClient = New-Object System.Net.WebClient
                    $webClient.Headers.Add('User-Agent', 'Mozilla/5.0')
                    
                    $downloadTask = $webClient.DownloadFileTaskAsync($file.Url, $filePath)
                    while (-not $downloadTask.IsCompleted) {
                        $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                        Show-ProgressBar "Download $($file.Name)" 'In corso...' 50 $file.Icon $spinner 'Cyan'
                        Start-Sleep -Milliseconds 300
                    }
                    
                    Show-ProgressBar "Download $($file.Name)" 'Completato' 100 $file.Icon
                    Write-Host ''
                    $webClient.Dispose()
                }
                catch {
                    Write-StyledMessage Error "Download fallito: $($file.Name)"
                    return $false
                }
            }
            
            # Avvia installazione
            Write-StyledMessage Info '🚀 Avvio installazione...'
            $setupPath = Join-Path $script:TempDir 'Setup.exe'
            $configPath = Join-Path $script:TempDir 'Basic.xml'
            Start-Process -FilePath $setupPath -ArgumentList "/configure `"$configPath`"" -WorkingDirectory $script:TempDir
            
            # Attesa utente
            $spinnerIndex = 0
            Write-StyledMessage Info '💡 Premi un tasto quando completata...'
            do {
                if ([Console]::KeyAvailable) {
                    [Console]::ReadKey($true) | Out-Null
                    break
                }
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                Write-Host "`r$spinner 🏢 Installazione in corso..." -NoNewline -ForegroundColor Yellow
                Start-Sleep -Milliseconds 500
            } while ($true)
            Write-Host ''
            
            # Conferma
            do {
                $confirm = Read-Host "✅ Installazione completata? [Y/N]"
                if ($confirm.ToLower() -eq 'y') {
                    Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
                    return $true
                }
                elseif ($confirm.ToLower() -eq 'n') { return $false }
                else { Write-StyledMessage Warning 'Risposta non valida.' }
            } while ($true)
        }
        catch {
            Write-StyledMessage Error "Errore installazione: $_"
            return $false
        }
    }

    function Start-OfficeRepair {
        Write-StyledMessage Info '🔧 Riparazione Office...'
        
        Stop-OfficeProcesses
        
        # Pulizia cache
        $caches = @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache.xml",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )
        $cleaned = 0
        foreach ($cache in $caches) {
            if (Test-Path $cache) {
                try {
                    Remove-Item $cache -Recurse -Force
                    $cleaned++
                }
                catch { }
            }
        }
        if ($cleaned -gt 0) { Write-StyledMessage Success "$cleaned cache eliminate" }
        
        # Reset registro
        try {
            $regPath = 'HKCU:\Software\Microsoft\Office\16.0'
            if (Test-Path $regPath) {
                $backupPath = 'HKCU:\Software\Microsoft\Office\Office.16.0.bak'
                if (Test-Path $backupPath) { Remove-Item $backupPath -Recurse -Force }
                Rename-Item -Path $regPath -NewName 'Office.16.0.bak' -Force
                Write-StyledMessage Success 'Registro resettato'
            }
        }
        catch { Write-StyledMessage Warning "Errore registro: $_" }
        
        # Riparazione Click-to-Run
        $client = Get-OfficeClient
        if ($client) {
            try {
                Start-Process -FilePath $client -ArgumentList '/repair Office16' -Verb RunAs
                Write-StyledMessage Success 'Riparazione avviata'
                Wait-ProcessCompletion 'OfficeC2RClient' 'Riparazione Office' '🔧'
                Write-StyledMessage Success 'Riparazione completata!'
                return $true
            }
            catch {
                Write-StyledMessage Error "Errore riparazione: $_"
                return $false
            }
        }
        else {
            Write-StyledMessage Error 'Client Office non trovato'
            return $false
        }
    }

    function Start-OfficeUninstall {
        Write-StyledMessage Warning '🗑️ Rimozione completa Office'
        Write-StyledMessage Warning '⚠️ ATTENZIONE: Rimozione totale del sistema!'
        
        do {
            $confirm = Read-Host "Procedere? [Y/N]"
            if ($confirm.ToLower() -eq 'n') { return $false }
            elseif ($confirm.ToLower() -eq 'y') { break }
            else { Write-StyledMessage Warning 'Risposta non valida.' }
        } while ($true)
        
        Stop-OfficeProcesses
        
        # Disinstallazione tramite Winget
        Write-StyledMessage Info '📦 Ricerca pacchetti Office tramite Winget...'
        try {
            # Cerca tutti i pacchetti Office installati
            $officePackages = winget list --source winget | Select-String -Pattern "Microsoft\.Office|Microsoft365" -AllMatches
            
            if ($officePackages) {
                Write-StyledMessage Success "Trovati $($officePackages.Count) pacchetti Office"
                
                # Disinstalla ogni pacchetto trovato
                foreach ($package in $officePackages) {
                    $packageId = ($package -split '\s+')[0]
                    if ($packageId -match "Microsoft\.Office|Microsoft365") {
                        Write-StyledMessage Info "🗑️ Disinstallazione $packageId..."
                        
                        $spinnerIndex = 0
                        $uninstallProcess = Start-Process -FilePath "winget" -ArgumentList "uninstall --id $packageId --silent --accept-source-agreements" -NoNewWindow -PassThru
                        
                        while (-not $uninstallProcess.HasExited) {
                            $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                            Write-Host "`r$spinner 🗑️ Disinstallazione $packageId..." -NoNewline -ForegroundColor Red
                            Start-Sleep -Milliseconds 500
                        }
                        Write-Host ''
                        
                        if ($uninstallProcess.ExitCode -eq 0) {
                            Write-StyledMessage Success "$packageId rimosso"
                        }
                        else {
                            Write-StyledMessage Warning "Problemi rimuovendo $packageId"
                        }
                    }
                }
            }
            else {
                Write-StyledMessage Info 'Nessun pacchetto Office trovato tramite Winget'
            }
            
            # Disinstallazione alternativa tramite Click-to-Run se Winget fallisce
            Write-StyledMessage Info '🔧 Verifica Click-to-Run per rimozione residui...'
            $client = Get-OfficeClient
            if ($client) {
                try {
                    Write-StyledMessage Info '🗑️ Disinstallazione Click-to-Run...'
                    Start-Process -FilePath $client -ArgumentList '/uninstall Office16' -Verb RunAs -WindowStyle Hidden
                    Wait-ProcessCompletion 'OfficeC2RClient' 'Disinstallazione residui Office' '🗑️'
                    Write-StyledMessage Success 'Click-to-Run completato'
                }
                catch { Write-StyledMessage Warning "Click-to-Run: $_" }
            }
        }
        catch {
            Write-StyledMessage Error "Errore Winget: $_"
            Write-StyledMessage Info 'Tentativo con metodo alternativo...'
            
            # Fallback su Click-to-Run se Winget non funziona
            $client = Get-OfficeClient
            if ($client) {
                try {
                    Start-Process -FilePath $client -ArgumentList '/uninstall Office16' -Verb RunAs
                    Wait-ProcessCompletion 'OfficeC2RClient' 'Disinstallazione Office' '🗑️'
                }
                catch { Write-StyledMessage Error "Errore disinstallazione: $_" }
            }
        }
        
        # Verifica rimozione tramite Winget
        Write-StyledMessage Info '🔍 Verifica rimozione Office...'
        Start-Sleep 2
        try {
            $remainingPackages = winget list --source winget | Select-String -Pattern "Microsoft\.Office|Microsoft365" -AllMatches
            if ($remainingPackages) {
                Write-StyledMessage Warning "$($remainingPackages.Count) pacchetti Office ancora presenti"
                foreach ($remaining in $remainingPackages) {
                    $packageName = ($remaining -split '\s+')[1]
                    Write-StyledMessage Warning "Residuo: $packageName"
                }
            }
            else {
                Write-StyledMessage Success '✅ Nessun pacchetto Office rilevato da Winget'
            }
        }
        catch {
            Write-StyledMessage Warning "Impossibile verificare con Winget: $_"
        }
        
        # Pulizia completa residui (sempre eseguita)
        Write-StyledMessage Info '🧹 Pulizia completa residui sistema...'
        
        # Pulizia registro completa
        $userRegPaths = @(
            'HKCU:\Software\Microsoft\Office',
            'HKCU:\Software\Microsoft\VBA',
            'HKCU:\Software\Classes\Word.Application',
            'HKCU:\Software\Classes\Excel.Application',
            'HKCU:\Software\Classes\PowerPoint.Application',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*Office*'
        )
        
        $systemRegPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Office',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office',
            'HKLM:\SOFTWARE\Microsoft\VBA',
            'HKLM:\SOFTWARE\Classes\Word.Application',
            'HKLM:\SOFTWARE\Classes\Excel.Application',
            'HKLM:\SOFTWARE\Classes\PowerPoint.Application',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*Office*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*Office*'
        )
        
        $removed = 0
        
        # Rimozione chiavi utente (non richiedono privilegi elevati)
        foreach ($regPath in $userRegPaths) {
            if ($regPath -like "*\*Office*") {
                # Gestione pattern con wildcard per chiavi di disinstallazione
                $basePath = $regPath -replace '\*Office\*', ''
                if (Test-Path $basePath) {
                    try {
                        Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Office*" } | ForEach-Object {
                            Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                            $removed++
                        }
                    }
                    catch { }
                }
            }
            else {
                if (Test-Path $regPath) {
                    try {
                        Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
                        $removed++
                    }
                    catch { }
                }
            }
        }
        
        # Rimozione chiavi sistema (richiedono privilegi elevati)
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        foreach ($regPath in $systemRegPaths) {
            if ($regPath -like "*\*Office*") {
                # Gestione pattern con wildcard per chiavi di disinstallazione
                $basePath = $regPath -replace '\*Office\*', ''
                if (Test-Path $basePath) {
                    try {
                        if ($isAdmin) {
                            Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Office*" } | ForEach-Object {
                                Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                                $removed++
                            }
                        }
                    }
                    catch { }
                }
            }
            else {
                if (Test-Path $regPath) {
                    try {
                        if ($isAdmin) {
                            Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
                            $removed++
                        }
                    }
                    catch { }
                }
            }
        }
        
        if ($removed -gt 0) { Write-StyledMessage Success "$removed chiavi registro rimosse" }
        
        # Rimozione cartelle (include cartelle aggiuntive)
        $folders = @(
            "$env:ProgramFiles\Microsoft Office",
            "${env:ProgramFiles(x86)}\Microsoft Office",
            "$env:ProgramData\Microsoft\Office",
            "$env:LOCALAPPDATA\Microsoft\Office",
            "$env:APPDATA\Microsoft\Office",
            "$env:APPDATA\Microsoft\Word",
            "$env:APPDATA\Microsoft\Excel",
            "$env:APPDATA\Microsoft\PowerPoint",
            "$env:LOCALAPPDATA\Microsoft\OneNote",
            "$env:LOCALAPPDATA\Microsoft\Outlook",
            "$env:APPDATA\Microsoft\Outlook",
            "$env:ProgramFiles\WindowsApps\Microsoft.Office*",
            "${env:ProgramFiles(x86)}\WindowsApps\Microsoft.Office*",
            "$env:LOCALAPPDATA\Packages\Microsoft.Office*"
        )
        
        $removedFolders = 0
        foreach ($folder in $folders) {
            if ($folder -like "*Microsoft.Office*") {
                # Gestione cartelle con pattern
                $basePath = Split-Path $folder
                $pattern = Split-Path $folder -Leaf
                if (Test-Path $basePath) {
                    try {
                        Get-ChildItem -Path $basePath -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
                            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                            $removedFolders++
                        }
                    }
                    catch { }
                }
            }
            else {
                if (Test-Path $folder) {
                    try {
                        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
                        $removedFolders++
                    }
                    catch { }
                }
            }
        }
        if ($removedFolders -gt 0) { Write-StyledMessage Success "$removedFolders cartelle rimosse" }
        
        # Pulizia file temporanei e cache estesa
        $tempPaths = @(
            "$env:TEMP\*Office*", 
            "$env:TEMP\*Word*", 
            "$env:TEMP\*Excel*", 
            "$env:TEMP\*PowerPoint*",
            "$env:LOCALAPPDATA\Temp\*Office*",
            "$env:APPDATA\Microsoft\Templates"
        )
        $cleanedTemp = 0
        foreach ($pattern in $tempPaths) {
            if ($pattern -like "*\**") {
                $basePath = Split-Path $pattern
                $filter = Split-Path $pattern -Leaf
                if (Test-Path $basePath) {
                    try {
                        Get-ChildItem -Path $basePath -Filter $filter -ErrorAction SilentlyContinue | ForEach-Object {
                            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                            $cleanedTemp++
                        }
                    }
                    catch { }
                }
            }
            else {
                if (Test-Path $pattern) {
                    try {
                        Remove-Item -Path $pattern -Recurse -Force -ErrorAction SilentlyContinue
                        $cleanedTemp++
                    }
                    catch { }
                }
            }
        }
        if ($cleanedTemp -gt 0) { Write-StyledMessage Success "$cleanedTemp file temporanei rimossi" }
        
        # Verifica finale
        Write-StyledMessage Info '🔍 Verifica finale rimozione...'
        Start-Sleep 1
        try {
            $finalCheck = winget list --source winget 2>$null | Select-String -Pattern "Microsoft\.Office|Microsoft365" -AllMatches
            if ($finalCheck) {
                Write-StyledMessage Warning "⚠️ Alcuni residui Office potrebbero essere ancora presenti"
                Write-StyledMessage Info "💡 Il riavvio dovrebbe completare la rimozione"
            }
            else {
                Write-StyledMessage Success '🎉 Office completamente rimosso dal sistema!'
            }
        }
        catch {
            Write-StyledMessage Success '🎉 Rimozione completa terminata!'
        }
        
        return $true
    }

    # Interfaccia principale
    $Host.UI.RawUI.WindowTitle = "Office Toolkit By MagnetarMan"
    Clear-Host
    
    # Header
    $width = 65
    Write-Host ('═' * $width) -ForegroundColor Green
    $asciiArt = @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        '     Office Toolkit By MagnetarMan',
        '        Version 2.1 (Build 9)'
    )
    $asciiArt | ForEach-Object { 
        $padding = [math]::Max(0, [math]::Floor(($width - $_.Length) / 2))
        Write-Host ((' ' * $padding) + $_) -ForegroundColor White 
    }
    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''
    
    # Preparazione
    for ($i = 3; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione - $i sec..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"
    
    try {
        do {
            # Menu
            Write-StyledMessage Info "🎯 Seleziona un'opzione:"
            Write-Host ''
            Write-Host '  [1]  Installazione Office Basic' -ForegroundColor White
            Write-Host '  [2]  Ripara Office corrotto' -ForegroundColor White
            Write-Host '  [3]  Rimozione completa Office' -ForegroundColor Red
            Write-Host '  [0]  Esci' -ForegroundColor Gray
            Write-Host ''
            
            $choice = Read-Host 'Scelta'
            Write-Host ''
            
            switch ($choice) {
                '1' {
                    if (Start-OfficeInstall) {
                        Invoke-SystemRestart 'Installazione completata'
                    }
                }
                '2' {
                    if (Start-OfficeRepair) {
                        Invoke-SystemRestart 'Riparazione completata'
                    }
                }
                '3' {
                    if (Start-OfficeUninstall) {
                        Invoke-SystemRestart 'Rimozione completata'
                    }
                }
                '0' {
                    Write-StyledMessage Info '👋 Uscita...'
                    return
                }
                default {
                    Write-StyledMessage Warning 'Opzione non valida'
                }
            }
            
            if ($choice -ne '0') {
                Write-Host "`n" + ('─' * 50) + "`n"
            }
            
        } while ($choice -ne '0')
    }
    catch {
        Write-StyledMessage Error "Errore critico: $_"
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
    }
}

# Esecuzione
OfficeToolkit