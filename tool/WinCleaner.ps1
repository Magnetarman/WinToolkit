function WinCleaner {
    <#
    .SYNOPSIS
        Script automatico per la pulizia completa del sistema Windows.

    .DESCRIPTION
        Esegue una pulizia completa utilizzando un motore basato su regole.
        Include protezione vitale per cartelle critiche e gestione unificata di file, registro e servizi.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 300)]
        [int]$CountdownSeconds = 30
    )

    # ============================================================================
    # 1. CONFIGURAZIONE E INIZIALIZZAZIONE
    # ============================================================================

    $Host.UI.RawUI.WindowTitle = "Cleaner Toolkit By MagnetarMan"
    $Log = @()
    $CurrentAttempt = 0

    # Setup Logging
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logDir = "$env:LOCALAPPDATA\WinToolkit\logs"
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
    Start-Transcript -Path "$logDir\WinCleaner_$dateTime.log" -Append -Force | Out-Null

    # Risorse UI
    $Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    # Percorsi Vitali (NON TOCCARE)
    $VitalExclusions = @(
        "$env:LOCALAPPDATA\WinToolkit"
    )

    # ============================================================================
    # 2. FUNZIONI CORE
    # ============================================================================

    function Write-StyledMessage {
        param([string]$Type, [string]$Text)
        $style = $script:MsgStyles[$Type]
        $timestamp = Get-Date -Format "HH:mm:ss"
        $cleanText = $Text -replace '^[✅⚠️❌💎🔍🚀⚙️🧹📦📋📜📝💾⬇️🔧⚡🖼️🌐🍪🔄🗂️📁🖨️📄🗑️💭⏸️▶️💡⏰🎉💻📊]\s*', ''
        Write-Host "[$timestamp] $($style.Icon) $cleanText" -ForegroundColor $style.Color
        if ($Type -in @('Info', 'Warning', 'Error')) { $Log += "[$timestamp] [$Type] $cleanText" }
    }

    function Test-VitalExclusion {
        param([string]$Path)
        if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
        $fullPath = $Path -replace '"', '' # Remove quotes
        try {
            if (-not [System.IO.Path]::IsPathRooted($fullPath)) {
                $fullPath = Join-Path (Get-Location) $fullPath
            }
            foreach ($excluded in $VitalExclusions) {
                if ($fullPath -like "$excluded*" -or $fullPath -eq $excluded) {
                    Write-StyledMessage Info "🛡️ PROTEZIONE VITALE ATTIVATA: $fullPath"
                    return $true
                }
            }
        }
        catch { return $false }
        return $false
    }

    function Show-ProgressBar {
        param($Activity, $Status, $Percent, $Icon, $Spinner = '')
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '▒' * (30 - $filled.Length)
        Write-Host "`r$Spinner $Icon $Activity [$filled$empty] $safePercent% $Status" -NoNewline -ForegroundColor Green
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Start-ProcessWithTimeout {
        param(
            [Parameter(Mandatory = $true)]
            [string]$FilePath,

            [Parameter(Mandatory = $false)]
            [string[]]$ArgumentList = @(),

            [Parameter(Mandatory = $false)]
            [int]$TimeoutSeconds = 300,

            [Parameter(Mandatory = $false)]
            [string]$Activity = "Processo in esecuzione",

            [Parameter(Mandatory = $false)]
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

            if ($Hidden) {
                $processParams.WindowStyle = 'Hidden'
            }
            else {
                $processParams.NoNewWindow = $true
            }

            $proc = Start-Process @processParams

            while (-not $proc.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
                $spinner = $Spinners[$spinnerIndex++ % $Spinners.Length]
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

                if ($percent -lt 90) {
                    $percent += Get-Random -Minimum 1 -Maximum 3
                }

                Show-ProgressBar -Activity $Activity -Status "In esecuzione... ($elapsed secondi)" -Percent $percent -Icon '⏳' -Spinner $spinner
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

    function Clear-ProgressLine {
        Write-Host "`r$(' ' * 120)" -NoNewline
        Write-Host "`r" -NoNewline
    }

    function Start-InterruptibleCountdown {
        param(
            [Parameter(Mandatory = $true)]
            [int]$Seconds,

            [Parameter(Mandatory = $true)]
            [string]$Message
        )

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

    function Invoke-CommandAction {
        param($Rule)
        Write-StyledMessage Info "🚀 Esecuzione comando: $($Rule.Name)"
        try {
            # Use timeout for potentially long-running commands
            $timeoutCommands = @("DISM.exe", "cleanmgr.exe")
            if ($Rule.Command -in $timeoutCommands) {
                $result = Start-ProcessWithTimeout -FilePath $Rule.Command -ArgumentList $Rule.Args -TimeoutSeconds 900 -Activity $Rule.Name -Hidden
                if ($result.TimedOut) {
                    Write-StyledMessage Warning "Comando timeout dopo 15 minuti"
                    return $true # Non-fatal
                }
                if ($result.ExitCode -eq 0) { return $true }
                Write-StyledMessage Warning "Comando completato con codice $($result.ExitCode)"
                return $true # Non-fatal
            }
            else {
                $proc = Start-Process -FilePath $Rule.Command -ArgumentList $Rule.Args -PassThru -WindowStyle Hidden -Wait
                if ($proc.ExitCode -eq 0) { return $true }
                Write-StyledMessage Warning "Comando completato con codice $($proc.ExitCode)"
                return $true # Non-fatal
            }
        }
        catch {
            Write-StyledMessage Error "Errore comando: $_"
            return $false
        }
    }

    function Invoke-ServiceAction {
        param($Rule)
        $svcName = $Rule.ServiceName
        $action = $Rule.Action # Start/Stop
        
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if (-not $svc) { return $true }

            if ($action -eq 'Stop' -and $svc.Status -eq 'Running') {
                Write-StyledMessage Info "⏸️ Arresto servizio $svcName..."
                Stop-Service -Name $svcName -Force -ErrorAction Stop
            }
            elseif ($action -eq 'Start' -and $svc.Status -ne 'Running') {
                Write-StyledMessage Info "▶️ Avvio servizio $svcName..."
                Start-Service -Name $svcName -ErrorAction Stop
            }
            return $true
        }
        catch {
            Write-StyledMessage Warning "Errore servizio $svcName : $_"
            return $false
        }
    }

    function Remove-FileItem {
        param($Rule)
        $paths = $Rule.Paths
        $isPerUser = $Rule.PerUser
        $filesOnly = $Rule.FilesOnly
        $takeOwn = $Rule.TakeOwnership
        
        $targetPaths = @()
        if ($isPerUser) {
            $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^(Public|Default|All Users)$' }
            foreach ($user in $users) {
                foreach ($p in $paths) {
                    $targetPaths += $p -replace '%USERPROFILE%', $user.FullName `
                        -replace '%APPDATA%', "$($user.FullName)\AppData\Roaming" `
                        -replace '%LOCALAPPDATA%', "$($user.FullName)\AppData\Local" `
                        -replace '%TEMP%', "$($user.FullName)\AppData\Local\Temp"
                }
            }
        }
        else {
            foreach ($p in $paths) { $targetPaths += [Environment]::ExpandEnvironmentVariables($p) }
        }

        $count = 0
        foreach ($path in $targetPaths) {
            if (Test-VitalExclusion $path) { continue }
            if (-not (Test-Path $path)) { continue }

            try {
                if ($takeOwn) {
                    Write-StyledMessage Info "🔑 Assunzione proprietà per $path..."
                    $takeownResult = & cmd /c "takeown /F `"$path`" /R /A /D Y 2>&1"
                    if ($LASTEXITCODE -ne 0) {
                        Write-StyledMessage Warning "Errore takeown: $takeownResult"
                    }

                    $adminSID = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
                    $adminAccount = $adminSID.Translate([System.Security.Principal.NTAccount]).Value
                    $icaclsResult = & cmd /c "icacls `"$path`" /T /grant `"${adminAccount}:F`" 2>&1"
                    if ($LASTEXITCODE -ne 0) {
                        Write-StyledMessage Warning "Errore icacls: $icaclsResult"
                    }
                }

                if ($filesOnly) {
                    $items = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
                    $items | Remove-Item -Force -ErrorAction SilentlyContinue
                    $count += $items.Count
                }
                else {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    $count++
                }
            }
            catch {
                Write-StyledMessage Warning "Errore rimozione $path : $_"
            }
        }
        if ($count -gt 0) { Write-StyledMessage Success "🗑️ Puliti $count elementi in $($Rule.Name)" }
        return $true
    }

    function Remove-RegistryItem {
        param($Rule)
        $keys = $Rule.Keys
        $recursive = $Rule.Recursive
        $valuesOnly = $Rule.ValuesOnly # If true, clear values but keep key

        foreach ($rawKey in $keys) {
            $key = $rawKey -replace '^(HKCU|HKLM):', '$1:\'
            if (-not (Test-Path $key)) { continue }

            try {
                if ($valuesOnly) {
                    $item = Get-Item $key -ErrorAction Stop
                    $item.GetValueNames() | ForEach-Object { 
                        if ($_ -ne '(default)') { Remove-ItemProperty -LiteralPath $key -Name $_ -Force -ErrorAction SilentlyContinue }
                    }
                    if ($recursive) {
                        Get-ChildItem $key -Recurse | ForEach-Object {
                            $_.GetValueNames() | ForEach-Object { Remove-ItemProperty -LiteralPath $_.PSPath -Name $_ -Force -ErrorAction SilentlyContinue }
                        }
                    }
                    Write-StyledMessage Success "⚙️ Puliti valori in $key"
                }
                else {
                    Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop
                    Write-StyledMessage Success "🗑️ Rimossa chiave $key"
                }
            }
            catch {
                Write-StyledMessage Warning "Errore registro $key : $_"
            }
        }
        return $true
    }

    function Set-RegistryItem {
        param($Rule)
        $key = $Rule.Key -replace '^(HKCU|HKLM):', '$1:\'
        try {
            if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
            Set-ItemProperty -Path $key -Name $Rule.ValueName -Value $Rule.ValueData -Type $Rule.ValueType -Force
            Write-StyledMessage Success "⚙️ Impostato $key\$($Rule.ValueName)"
            return $true
        }
        catch { return $false }
    }

    function Invoke-WinCleanerRule {
        param($Rule)
        switch ($Rule.Type) {
            'File' { return Remove-FileItem -Rule $Rule }
            'Registry' { return Remove-RegistryItem -Rule $Rule }
            'RegSet' { return Set-RegistryItem -Rule $Rule }
            'Service' { return Invoke-ServiceAction -Rule $Rule }
            'Command' { return Invoke-CommandAction -Rule $Rule }
            'ScriptBlock' { 
                # Operazioni multi-passo complesse
                if ($Rule.ScriptBlock) { 
                    & $Rule.ScriptBlock 
                    return $true
                }
            }
            'Custom' { 
                # Operazioni complesse specializzate
                if ($Rule.ScriptBlock) { 
                    & $Rule.ScriptBlock 
                    return $true
                }
            }
        }
        return $true
    }

    # ============================================================================
    # 3. DEFINIZIONE REGOLE
    # ============================================================================

    $Rules = @(
        # --- CleanMgr Auto ---
        @{ Name = "CleanMgr Config"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage Info "🧹 Configurazione CleanMgr..."
                $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
                $opts = @("Active Setup Temp Folders", "BranchCache", "D3D Shader Cache", "Delivery Optimization Files",
                    "Downloaded Program Files", "Internet Cache Files", "Memory Dump Files", "Recycle Bin",
                    "Temporary Files", "Thumbnail Cache", "Windows Error Reporting Files", "Setup Log Files",
                    "System error memory dump files", "System error minidump files", "Temporary Setup Files",
                    "Windows Upgrade Log Files")
                foreach ($o in $opts) { 
                    $p = Join-Path $reg $o
                    if (Test-Path $p) { Set-ItemProperty -Path $p -Name "StateFlags0065" -Value 2 -Type DWORD -Force -ErrorAction SilentlyContinue }
                }
                Start-Process 'cleanmgr.exe' -ArgumentList '/sagerun:65' -WindowStyle Minimized
            }
        }

        # --- WinSxS ---
        @{ Name = "WinSxS Cleanup"; Type = "Command"; Command = "DISM.exe"; Args = @("/Online", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase") }
        @{ Name = "Minimize DISM"; Type = "RegSet"; Key = "HKLM:\Software\Microsoft\Windows\CurrentVersion\SideBySide\Configuration"; ValueName = "DisableResetbase"; ValueData = 0; ValueType = "DWORD" }

        # --- Error Reports ---
        @{ Name = "Error Reports"; Type = "File"; Paths = @("$env:ProgramData\Microsoft\Windows\WER", "$env:ALLUSERSPROFILE\Microsoft\Windows\WER"); FilesOnly = $false }

        # --- Event Logs ---
        @{ Name = "Clear Event Logs"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage Info "📜 Pulizia Event Logs..."
                & wevtutil sl 'Microsoft-Windows-LiveId/Operational' /ca:'O:BAG:SYD:(A;;0x1;;;SY)(A;;0x5;;;BA)(A;;0x1;;;LA)' 2>$null
                Get-WinEvent -ListLog * -Force -ErrorAction SilentlyContinue | ForEach-Object { Wevtutil.exe cl $_.LogName 2>$null }
            }
        }

        # --- Windows Update ---
        @{ Name = "Windows Update Cleanup"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage Info "🔄 Pulizia cache Windows Update..."
                try {
                    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2

                    $paths = @("C:\WINDOWS\SoftwareDistribution\DataStore", "C:\WINDOWS\SoftwareDistribution\Download")
                    foreach ($p in $paths) {
                        if (Test-Path $p) {
                            Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }

                    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
                    Write-StyledMessage Success "✅ Cache Windows Update pulita"
                }
                catch {
                    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
                    Write-StyledMessage Warning "Errore pulizia Windows Update: $_"
                }
            }
        }

        # --- Windows App/Download Cache ---
        @{ Name = "Windows App/Download Cache - System"; Type = "File"; Paths = @("C:\WINDOWS\SoftwareDistribution\Download"); FilesOnly = $true }
        @{ Name = "Windows App/Download Cache - User"; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\AppCache", "%LOCALAPPDATA%\Microsoft\Windows\Caches"); PerUser = $true; FilesOnly = $true }

        # --- Restore Points ---
        @{ Name = "System Restore Points"; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Write-StyledMessage Info "💾 Pulizia punti di ripristino sistema..."
                    
                    Write-StyledMessage Info "🗑️ Rimozione shadow copies per liberare spazio VSS..."
                    $vssResult = & vssadmin delete shadows /all /quiet 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-StyledMessage Success "✅ Shadow copies rimosse con successo"
                    }
                    else {
                        Write-StyledMessage Warning "⚠️ VSSAdmin completato con warnings: $vssResult"
                    }
                    
                    Write-StyledMessage Info "💡 Protezione sistema mantenuta attiva per sicurezza"
                    Write-StyledMessage Success "✅ Pulizia punti di ripristino completata"
                }
                catch {
                    Write-StyledMessage Warning "⚠️ Errore durante la pulizia punti di ripristino: $($_.Exception.Message)"
                }
            }
        }

        # --- Prefetch ---
        @{ Name = "Cleanup - Windows Prefetch Cache"; Type = "File"; Paths = @("C:\WINDOWS\Prefetch"); FilesOnly = $false }

        # --- Thumbnails ---
        @{ Name = "Cleanup - Explorer Thumbnail/Icon Cache"; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\Explorer"); PerUser = $true; FilesOnly = $true; TakeOwnership = $true }

        # --- Browser & Web Cache (Consolidato) ---
        @{ Name = "WinInet & Internet Cache"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage Info "🌐 Pulizia WinInet Cache..."
                
                # WinInet Cache paths
                $winInetPaths = @("$env:LOCALAPPDATA\Microsoft\Windows\INetCache\IE", "$env:LOCALAPPDATA\Microsoft\Windows\WebCache", 
                    "$env:LOCALAPPDATA\Microsoft\Feeds Cache", "$env:LOCALAPPDATA\Microsoft\InternetExplorer\DOMStore",
                    "$env:LOCALAPPDATA\Microsoft\Internet Explorer")
                foreach ($p in $winInetPaths) { if (Test-Path $p) { Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue } }
            
                # Per-user Temp Internet Files
                $users = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notmatch '^(Public|Default|All Users)$' }
                foreach ($u in $users) {
                    $p = "$($u.FullName)\Local Settings\Temporary Internet Files"
                    if (Test-Path $p) { Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue }
                }
            
                & RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 8 2>$null
                & RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 2 2>$null
            }
        }
        @{ Name = "Internet Cookies"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage Info "🍪 Pulizia Cookie..."
                
                $cookiePaths = @("%APPDATA%\Microsoft\Windows\Cookies", "%LOCALAPPDATA%\Microsoft\Windows\INetCookies")
                $users = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notmatch '^(Public|Default|All Users)$' }
                foreach ($u in $users) {
                    foreach ($rawP in $cookiePaths) {
                        $p = $rawP -replace '%APPDATA%', "$($u.FullName)\AppData\Roaming" `
                            -replace '%LOCALAPPDATA%', "$($u.FullName)\AppData\Local"
                        if (Test-Path $p) { Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                }
                & RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 1 2>$null
            }
        }
        @{ Name = "Chrome Browser Cache"; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Google\Chrome\User Data\Crashpad\reports",
                "%LOCALAPPDATA%\Google\CrashReports"
            ); PerUser = $true; FilesOnly = $true 
        }
        @{ Name = "Chrome SRT Logs"; Type = "File"; Paths = @("%LOCALAPPDATA%\Google\Chrome\User Data\Software Reporter Tool"); PerUser = $true }
        @{ Name = "Firefox Browser Data"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage Info "🦊 Pulizia Firefox..."
                
                $users = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notmatch '^(Public|Default|All Users)$' }
                foreach ($u in $users) {
                    # Standard Firefox profiles
                    $profiles = Get-ChildItem "$($u.FullName)\AppData\Roaming\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
                    foreach ($prof in $profiles) {
                        $files = @("downloads.rdf", "downloads.sqlite", "places.sqlite", "favicons.sqlite")
                        foreach ($f in $files) {
                            $fp = Join-Path $prof.FullName $f
                            if (Test-Path $fp) { Remove-Item -Path $fp -Force -ErrorAction SilentlyContinue }
                        }
                    }
                    # Cache folders
                    $cache = "$($u.FullName)\AppData\Local\Mozilla\Firefox\Profiles"
                    if (Test-Path $cache) { Remove-Item -Path $cache -Recurse -Force -ErrorAction SilentlyContinue }

                    # Microsoft Store Firefox (UWP)
                    $msStoreProfiles = Get-ChildItem "$($u.FullName)\AppData\Local\Packages" -Directory -Filter "Mozilla.Firefox_*" -ErrorAction SilentlyContinue
                    foreach ($pkg in $msStoreProfiles) {
                        $msCache = "$($pkg.FullName)\LocalCache\Roaming\Mozilla\Firefox\Profiles"
                        if (Test-Path $msCache) { Remove-Item -Path $msCache -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                }
            }
        }
        @{ Name = "Opera & Java Cache"; Type = "File"; Paths = @(
                "%USERPROFILE%\Local Settings\Application Data\Opera\Opera",
                "%LOCALAPPDATA%\Opera\Opera",
                "%APPDATA%\Opera\Opera",
                "%APPDATA%\Sun\Java\Deployment\cache"
            ); PerUser = $true 
        }

        @{ Name = "DNS Flush"; Type = "Command"; Command = "ipconfig"; Args = @("/flushdns") }

        # --- Temp Files (Consolidato) ---
        @{ Name = "System Temp Files"; Type = "File"; Paths = @("C:\WINDOWS\Temp"); FilesOnly = $false }
        @{ Name = "User Temp Files"; Type = "File"; Paths = @("%TEMP%", "%USERPROFILE%\AppData\Local\Temp", "%USERPROFILE%\AppData\LocalLow\Temp"); PerUser = $true; FilesOnly = $false }
        @{ Name = "Service Profiles Temp"; Type = "File"; Paths = @("%SYSTEMROOT%\ServiceProfiles\LocalService\AppData\Local\Temp"); FilesOnly = $false }

        # --- System & Component Logs (Consolidato) ---
        @{ Name = "System & Component Logs"; Type = "File"; Paths = @(
                "C:\WINDOWS\Logs",
                "C:\WINDOWS\System32\LogFiles",
                "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
                "%SYSTEMROOT%\Temp\CBS",
                "%SYSTEMROOT%\Logs\waasmedic",
                "%SYSTEMROOT%\Logs\SIH",
                "%SYSTEMROOT%\Traces\WindowsUpdate",
                "%SYSTEMROOT%\Panther",
                "%SYSTEMROOT%\comsetup.log",
                "%SYSTEMROOT%\DtcInstall.log",
                "%SYSTEMROOT%\PFRO.log",
                "%SYSTEMROOT%\setupact.log",
                "%SYSTEMROOT%\setuperr.log",
                "%SYSTEMROOT%\inf\setupapi.app.log",
                "%SYSTEMROOT%\inf\setupapi.dev.log",
                "%SYSTEMROOT%\inf\setupapi.offline.log",
                "%SYSTEMROOT%\Performance\WinSAT\winsat.log",
                "%SYSTEMROOT%\debug\PASSWD.LOG",
                "%SYSTEMROOT%\System32\catroot2\dberr.txt",
                "%SYSTEMROOT%\System32\catroot2.log",
                "%SYSTEMROOT%\System32\catroot2.jrs",
                "%SYSTEMROOT%\System32\catroot2.edb",
                "%SYSTEMROOT%\System32\catroot2.chk",
                "%SYSTEMROOT%\Logs\DISM\DISM.log",
                "%PROGRAMDATA%\Microsoft\Diagnosis\ETLLogs\AutoLogger\AutoLogger-Diagtrack-Listener.etl"
            ); FilesOnly = $true; TakeOwnership = $true 
        }

        # --- User Registry History (Consolidato) ---
        @{ Name = "User Registry History - Values Only"; Type = "Registry"; Keys = @(
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedMRU",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRULegacy",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Paint\Recent File List",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Wordpad\Recent File List",
                "HKCU:\Software\Microsoft\MediaPlayer\Player\RecentFileList",
                "HKCU:\Software\Microsoft\MediaPlayer\Player\RecentURLList",
                "HKCU:\Software\Gabest\Media Player Classic\Recent File List",
                "HKCU:\Software\Microsoft\Direct3D\MostRecentApplication",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths",
                "HKCU:\Software\Microsoft\Search Assistant\ACMru",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\SearchHistory",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Map Network Drive MRU"
            ); ValuesOnly = $true; Recursive = $true 
        }
        @{ Name = "Adobe Media Browser Key"; Type = "Registry"; Keys = @("HKCU:\Software\Adobe\MediaBrowser\MRU"); ValuesOnly = $false }

        # --- Developer Telemetry (Consolidato) ---
        @{ Name = "Developer Telemetry & Traces"; Type = "File"; Paths = @(
                "%USERPROFILE%\.dotnet\TelemetryStorageService",
                "%LOCALAPPDATA%\Microsoft\CLR_v4.0\UsageTraces",
                "%LOCALAPPDATA%\Microsoft\CLR_v4.0_32\UsageTraces",
                "%LOCALAPPDATA%\Microsoft\VSCommon\14.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSCommon\15.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSCommon\16.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSCommon\17.0\SQM",
                "%LOCALAPPDATA%\Microsoft\VSApplicationInsights",
                "%TEMP%\Microsoft\VSApplicationInsights",
                "%APPDATA%\vstelemetry",
                "%TEMP%\VSFaultInfo",
                "%TEMP%\VSFeedbackPerfWatsonData",
                "%TEMP%\VSFeedbackVSRTCLogs",
                "%TEMP%\VSFeedbackIntelliCodeLogs",
                "%TEMP%\VSRemoteControl",
                "%TEMP%\Microsoft\VSFeedbackCollector",
                "%TEMP%\VSTelem",
                "%TEMP%\VSTelem.Out",
                "%PROGRAMDATA%\Microsoft\VSApplicationInsights",
                "%PROGRAMDATA%\vstelemetry"
            ); PerUser = $true; FilesOnly = $false 
        }
        @{ Name = "Visual Studio Licenses"; Type = "Registry"; Keys = @(
                "HKLM:\SOFTWARE\Classes\Licenses\77550D6B-6352-4E77-9DA3-537419DF564B",
                "HKLM:\SOFTWARE\Classes\Licenses\E79B3F9C-6543-4897-BBA5-5BFB0A02BB5C",
                "HKLM:\SOFTWARE\Classes\Licenses\4D8CFBCB-2F6A-4AD2-BABF-10E28F6F2C8F",
                "HKLM:\SOFTWARE\Classes\Licenses\5C505A59-E312-4B89-9508-E162F8150517",
                "HKLM:\SOFTWARE\Classes\Licenses\41717607-F34E-432C-A138-A3CFD7E25CDA",
                "HKLM:\SOFTWARE\Classes\Licenses\B16F0CF0-8AD1-4A5B-87BC-CB0DBE9C48FC",
                "HKLM:\SOFTWARE\Classes\Licenses\10D17DBA-761D-4CD8-A627-984E75A58700",
                "HKLM:\SOFTWARE\Classes\Licenses\1299B4B9-DFCC-476D-98F0-F65A2B46C96D"
            ); ValuesOnly = $false 
        }

        # --- Search History Files ---
        @{ Name = "Search History Files"; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\ConnectedSearch\History"); PerUser = $true }

        # --- Print Queue (Spooler) ---
        @{ Name = "Print Queue (Spooler)"; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Write-StyledMessage Info "🖨️ Pulizia coda di stampa (Spooler)..."
                    
                    Write-StyledMessage Info "⏸️ Arresto servizio Spooler..."
                    Stop-Service -Name Spooler -Force -ErrorAction Stop | Out-Null
                    Write-StyledMessage Info "✅ Servizio Spooler arrestato."
                    Start-Sleep -Seconds 2

                    $printersPath = 'C:\WINDOWS\System32\spool\PRINTERS'
                    if (Test-Path $printersPath) {
                        $files = Get-ChildItem -Path $printersPath -Force -ErrorAction SilentlyContinue
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        Write-StyledMessage Info "✅ Coda di stampa pulita in $printersPath ($($files.Count) file rimossi)"
                    }

                    Write-StyledMessage Info "▶️ Riavvio servizio Spooler..."
                    Start-Service -Name Spooler -ErrorAction Stop | Out-Null
                    Write-StyledMessage Info "✅ Servizio Spooler riavviato."
                    
                    Write-StyledMessage Success "✅ Print Queue Spooler pulito e riavviato con successo."
                }
                catch {
                    Start-Service -Name Spooler -ErrorAction SilentlyContinue
                    Write-StyledMessage Warning "⚠️ Errore durante la pulizia Spooler: $($_.Exception.Message)"
                }
            }
        }

        # --- SRUM & Defender ---
        @{ Name = "Stop DPS"; Type = "Service"; ServiceName = "DPS"; Action = "Stop" }
        @{ Name = "SRUM Data"; Type = "File"; Paths = @("%SYSTEMROOT%\System32\sru\SRUDB.dat"); FilesOnly = $true; TakeOwnership = $true }
        @{ Name = "Start DPS"; Type = "Service"; ServiceName = "DPS"; Action = "Start" }
        @{ Name = "Defender History"; Type = "File"; Paths = @("%ProgramData%\Microsoft\Windows Defender\Scans\History"); FilesOnly = $false; TakeOwnership = $true }

        # --- Utility Apps ---
        @{ Name = "Listary Index"; Type = "File"; Paths = @("%APPDATA%\Listary\UserData"); PerUser = $true }
        @{ Name = "Quick Access"; Type = "File"; Paths = @("%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations", "%APPDATA%\Microsoft\Windows\Recent\CustomDestinations", "%APPDATA%\Microsoft\Windows\Recent Items"); PerUser = $true }

        # --- Special Operations ---
        @{ Name = "Credential Manager"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage Info "🔑 Pulizia Credenziali..."
                & cmdkey /list 2>$null | Where-Object { $_ -match '^Target:' } | ForEach-Object { 
                    $t = $_.Split(':')[1].Trim()
                    & cmdkey /delete:$t 2>$null 
                }
            }
        }
        @{ Name = "Regedit Last Key"; Type = "Registry"; Keys = @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit"); ValuesOnly = $true }
        @{ Name = "Windows.old"; Type = "ScriptBlock"; ScriptBlock = {
                $path = "C:\Windows.old"
                if (Test-Path $path) {
                    try {
                        Write-StyledMessage Info "🗑️ Rimozione Windows.old..."
                        
                        Write-StyledMessage Info "1. Assunzione proprietà (Take Ownership)..."
                        $takeownResult = & cmd /c "takeown /F `"$path`" /R /A /D Y 2>&1"
                        if ($LASTEXITCODE -ne 0) {
                            Write-StyledMessage Warning "❌ Errore durante l'assunzione della proprietà: $takeownResult"
                        }
                        else {
                            Write-StyledMessage Info "✅ Proprietà assunta."
                        }
                        Start-Sleep -Milliseconds 500
                        
                        Write-StyledMessage Info "2. Assegnazione permessi di Controllo Completo..."
                        $icaclsResult = & cmd /c "icacls `"$path`" /T /grant Administrators:F 2>&1"
                        if ($LASTEXITCODE -ne 0) {
                            Write-StyledMessage Warning "❌ Errore durante l'assegnazione permessi: $icaclsResult"
                        }
                        else {
                            Write-StyledMessage Info "✅ Permessi di controllo completo assegnati."
                        }
                        Start-Sleep -Milliseconds 500
                        
                        Write-StyledMessage Info "3. Rimozione forzata della cartella..."
                        Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                        
                        if (Test-Path -Path $path) {
                            Write-StyledMessage Error "❌ ERRORE: La cartella $path non è stata rimossa."
                        }
                        else {
                            Write-StyledMessage Success "✅ La cartella Windows.old è stata rimossa con successo."
                        }
                    }
                    catch {
                        Write-StyledMessage Error "❌ ERRORE durante la rimozione di Windows.old: $($_.Exception.Message)"
                    }
                }
                else {
                    Write-StyledMessage Info "💭 La cartella Windows.old non è presente."
                }
            }
        }
        @{ Name = "Empty Recycle Bin"; Type = "Custom"; ScriptBlock = {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                Write-StyledMessage Success "🗑️ Cestino svuotato"
            }
        }
    )

    # ============================================================================
    # 4. ESECUZIONE PRINCIPALE
    # ============================================================================

    function Show-Header {
        Clear-Host
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-Host "    WIN CLEANER TOOLKIT - OPTIMIZED ENGINE" -ForegroundColor White
        Write-Host ('═' * 80) -ForegroundColor Green
        Write-Host ''
    }

    Show-Header
    Write-StyledMessage Info "🚀 Avvio procedura di pulizia ottimizzata..."
    
    $totalSteps = $Rules.Count
    $currentStep = 0

    foreach ($rule in $Rules) {
        $currentStep++
        Show-ProgressBar -Activity "Esecuzione regole" -Status $rule.Name -Percent ([int](($currentStep / $totalSteps) * 100)) -Icon '⚙️'
        Invoke-WinCleanerRule -Rule $rule
        Start-Sleep -Milliseconds 200
    }

    # ============================================================================
    # 5. COMPLETAMENTO
    # ============================================================================

    Write-Host ''
    Write-StyledMessage Success "🎉 Pulizia completata con successo!"
    
    if ($CountdownSeconds -gt 0) {
        $shouldReboot = Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Preparazione riavvio sistema"
        if ($shouldReboot) {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
            Restart-Computer -Force
        }
        else {
            Write-StyledMessage Success "✅ Pulizia completata. Sistema non riavviato."
            Write-StyledMessage Info "💡 Riavvia quando possibile per applicare tutte le modifiche."
        }
    }
}