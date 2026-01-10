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

    # Initialize global execution log BEFORE any function calls
    $global:ExecutionLog = @()

    
    
    # ============================================================================
    # FUNZIONI GLOBALI LOCALI
    # ============================================================================

    function Clear-ProgressLine {
        if ($Host.Name -eq 'ConsoleHost') {
            try {
                $width = $Host.UI.RawUI.WindowSize.Width - 1
                Write-Host "`r$(' ' * $width)" -NoNewline
                Write-Host "`r" -NoNewline
            }
            catch {
                # Fallback for non-console hosts or errors
                Write-Host "`r                                                                                `r" -NoNewline
            }
        }
    }

    function Write-StyledMessage {
        param(
            [Parameter(Mandatory = $true, Position = 0)]
            [ValidateSet('Success', 'Info', 'Warning', 'Error', 'Question')]
            [string]$Type,

            [Parameter(Mandatory = $true, Position = 1)]
            [string]$Text
        )

        Clear-ProgressLine

        # Add to execution log
        $logEntry = @{
            Timestamp = Get-Date -Format "HH:mm:ss"
            Type      = $Type
            Text      = $Text
        }
        $global:ExecutionLog += $logEntry

        $colorMap = @{
            'Success'  = 'Green'
            'Info'     = 'Cyan'
            'Warning'  = 'Yellow'
            'Error'    = 'Red'
            'Question' = 'White'
        }

        $iconMap = @{
            'Success'  = '✅'
            'Info'     = 'ℹ️'
            'Warning'  = '⚠️'
            'Error'    = '❌'
            'Question' = '❓'
        }

        $color = $colorMap[$Type]
        $icon = $iconMap[$Type]

        Write-Host "[$($logEntry.Timestamp)] $icon $Text" -ForegroundColor $color
    }

    # ============================================================================
    # 1. INIZIALIZZAZIONE CON FRAMEWORK GLOBALE
    # ============================================================================

    Initialize-ToolLogging -ToolName "WinCleaner"
    Show-Header -SubTitle "Cleaner Toolkit"
    $Host.UI.RawUI.WindowTitle = "Cleaner Toolkit By MagnetarMan"

    $ProgressPreference = 'Continue'

    # ============================================================================
    # 2. ESCLUSIONI VITALI
    # ============================================================================

    $VitalExclusions = @(
        "$env:LOCALAPPDATA\WinToolkit"
    )

    # ============================================================================
    # 3. FUNZIONI CORE
    # ============================================================================

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
                    Write-StyledMessage -Type 'Info' -Text "🛡️ PROTEZIONE VITALE ATTIVATA: $fullPath"
                    return $true
                }
            }
        }
        catch { return $false }
        return $false
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

        $processParams = @{
            FilePath     = $FilePath
            ArgumentList = $ArgumentList
            PassThru     = $true
            ErrorAction  = 'Stop'
        }

        if ($Hidden) {
            $processParams.WindowStyle = 'Hidden'
        }
        else {
            $processParams.NoNewWindow = $true
        }

        $proc = Start-Process @processParams

        # Usa la funzione globale Invoke-WithSpinner per monitorare il processo
        $result = Invoke-WithSpinner -Activity $Activity -Process -Action { $proc } -TimeoutSeconds $TimeoutSeconds -UpdateInterval 500

        return $result
    }

    function Invoke-CommandAction {
        param($Rule)
        Write-StyledMessage -Type 'Info' -Text "🚀 Esecuzione comando: $($Rule.Name)"
        try {
            # Use timeout for potentially long-running commands
            $timeoutCommands = @("DISM.exe", "cleanmgr.exe")
            if ($Rule.Command -in $timeoutCommands) {
                $result = Start-ProcessWithTimeout -FilePath $Rule.Command -ArgumentList $Rule.Args -TimeoutSeconds 900 -Activity $Rule.Name -Hidden
                if ($result.TimedOut) {
                    Write-StyledMessage -Type 'Warning' -Text "Comando timeout dopo 15 minuti"
                    return $true # Non-fatal
                }
                if ($result.ExitCode -eq 0) { return $true }
                Write-StyledMessage -Type 'Warning' -Text "Comando completato con codice $($result.ExitCode)"
                return $true # Non-fatal
            }
            else {
                $proc = Start-Process -FilePath $Rule.Command -ArgumentList $Rule.Args -PassThru -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
                if ($proc.ExitCode -eq 0) { return $true }
                # Suppress warning if exit code is null (process failed to start)
                if ($null -ne $proc.ExitCode) {
                    Write-StyledMessage -Type 'Warning' -Text "Comando completato con codice $($proc.ExitCode)"
                }
                return $true # Non-fatal
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore comando: $_"
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
                Write-StyledMessage -Type 'Info' -Text "⏸️ Arresto servizio $svcName..."
                Stop-Service -Name $svcName -Force -ErrorAction Stop | Out-Null
            }
            elseif ($action -eq 'Start' -and $svc.Status -ne 'Running') {
                Write-StyledMessage -Type 'Info' -Text "▶️ Avvio servizio $svcName..."
                Start-Service -Name $svcName -ErrorAction Stop | Out-Null
            }
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore servizio $svcName : $_"
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
                    Write-StyledMessage -Type 'Info' -Text "🔑 Assunzione proprietà per $path..."
                    $null = & cmd /c "takeown /F `"$path`" /R /A >nul 2>&1"

                    $adminSID = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
                    $adminAccount = $adminSID.Translate([System.Security.Principal.NTAccount]).Value
                    $null = & cmd /c "icacls `"$path`" /T /grant `"${adminAccount}:F`" >nul 2>&1"
                }

                if ($filesOnly) {
                    $files = Get-ChildItem -Path $path -File -Force -ErrorAction SilentlyContinue
                    foreach ($file in $files) {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    }
                }
                else {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                }
                $count++
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore rimozione $path : $_"
            }
        }
        if ($count -gt 0) { Write-StyledMessage -Type 'Success' -Text "🗑️ Puliti $count elementi in $($Rule.Name)" }
        return $true
    }

    function Remove-RegistryItem {
        param($Rule)
        $keys = $Rule.Keys
        $recursive = $Rule.Recursive
        $valuesOnly = $Rule.ValuesOnly # If true, clear values but keep key

        foreach ($rawKey in $keys) {
            $key = $rawKey -replace '^(HKCU|HKLM):\\*', '$1:\'
            if (-not (Test-Path $key)) { continue }
            try {
                if ($valuesOnly) {
                    $item = Get-Item $key -ErrorAction Stop
                    $item.GetValueNames() | ForEach-Object {
                        if ($_ -ne '(default)') { Remove-ItemProperty -LiteralPath $key -Name $_ -Force -ErrorAction SilentlyContinue | Out-Null }
                    }
                    if ($recursive) {
                        Get-ChildItem $key -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                            $currentKeyPath = $_.PSPath
                            $_.GetValueNames() | ForEach-Object { Remove-ItemProperty -LiteralPath $currentKeyPath -Name $_ -Force -ErrorAction SilentlyContinue | Out-Null }
                        }
                    }
                    Write-StyledMessage -Type 'Success' -Text "⚙️ Puliti valori in $key"
                }
                else {
                    Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop | Out-Null
                    Write-StyledMessage -Type 'Success' -Text "🗑️ Rimossa chiave $key"
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore registro $key : $_"
            }
        }
        return $true
    }

    function Set-RegistryItem {
        param($Rule)
        $key = $Rule.Key -replace '^(HKCU|HKLM):', '$1:\'
        try {
            if (-not (Test-Path $key)) { New-Item -Path $key -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $key -Name $Rule.ValueName -Value $Rule.ValueData -Type $Rule.ValueType -Force -ErrorAction SilentlyContinue | Out-Null
            Write-StyledMessage -Type 'Success' -Text "⚙️ Impostato $key\$($Rule.ValueName)"
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
    # 4. DEFINIZIONE REGOLE
    # ============================================================================

    $Rules = @(
        # --- CleanMgr Auto ---
        @{ Name = "CleanMgr Config"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage -Type 'Info' -Text "🧹 Configurazione CleanMgr..."
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
                
                # Esegui cleanmgr.exe attendendo il completamento, sfruttando Invoke-CommandAction
                # che include già logica di timeout per cleanmgr.exe e gestisce la visualizzazione.
                $cleanMgrExecutionRule = @{
                    Name    = "Esecuzione CleanMgr con /sagerun:65";
                    Type    = "Command";
                    Command = "cleanmgr.exe";
                    Args    = @("/sagerun:65");
                }
                Invoke-CommandAction -Rule $cleanMgrExecutionRule
            }
        }

        # --- WinSxS ---
        @{ Name = "WinSxS Cleanup"; Type = "Command"; Command = "DISM.exe"; Args = @("/Online", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase") }
        @{ Name = "Minimize DISM"; Type = "RegSet"; Key = "HKLM:\Software\Microsoft\Windows\CurrentVersion\SideBySide\Configuration"; ValueName = "DisableResetbase"; ValueData = 0; ValueType = "DWORD" }

        # --- Error Reports ---
        @{ Name = "Error Reports"; Type = "File"; Paths = @("$env:ProgramData\Microsoft\Windows\WER", "$env:ALLUSERSPROFILE\Microsoft\Windows\WER"); FilesOnly = $false }

        # --- Event Logs ---
        @{ Name = "Clear Event Logs"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage -Type 'Info' -Text "📜 Pulizia Event Logs..."
                & wevtutil sl 'Microsoft-Windows-LiveId/Operational' /ca:'O:BAG:SYD:(A;;0x1;;;SY)(A;;0x5;;;BA)(A;;0x1;;;LA)' 2>$null
                Get-WinEvent -ListLog * -Force -ErrorAction SilentlyContinue | ForEach-Object { Wevtutil.exe cl $_.LogName 2>$null }
            }
        }

        # --- Windows Update ---
        @{ Name = "Stop - Windows Update Service"; Type = "Service"; ServiceName = "wuauserv"; Action = "Stop" }
        @{ Name = "Cleanup - Windows Update Cache"; Type = "File"; Paths = @("C:\WINDOWS\SoftwareDistribution\DataStore", "C:\WINDOWS\SoftwareDistribution\Download"); FilesOnly = $false }
        @{ Name = "Start - Windows Update Service"; Type = "Service"; ServiceName = "wuauserv"; Action = "Start" }

        # --- Windows App/Download Cache ---
        @{ Name = "Windows App/Download Cache - System"; Type = "File"; Paths = @("C:\WINDOWS\SoftwareDistribution\Download"); FilesOnly = $true }
        @{ Name = "Windows App/Download Cache - User"; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\AppCache", "%LOCALAPPDATA%\Microsoft\Windows\Caches"); PerUser = $true; FilesOnly = $true }

        # --- Restore Points ---
        @{ Name = "System Restore Points"; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Write-StyledMessage -Type 'Info' -Text "💾 Pulizia punti di ripristino sistema..."

                    # Write-StyledMessage -Type 'Info' -Text "🗑️ Rimozione shadow copies per liberare spazio VSS..."
                    # $vssResult = & vssadmin delete shadows /all /quiet 2>&1
                    # if ($LASTEXITCODE -eq 0) {
                    #     Write-StyledMessage -Type 'Success' -Text "Shadow copies rimosse con successo"
                    # }
                    # else {
                    #     Write-StyledMessage -Type 'Warning' -Text "VSSAdmin completato con warnings: $vssResult"
                    # }

                    Write-StyledMessage -Type 'Info' -Text "💡 Protezione sistema mantenuta attiva per sicurezza"
                    Write-StyledMessage -Type 'Success' -Text "Pulizia punti di ripristino completata"
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Errore durante la pulizia punti di ripristino: $($_.Exception.Message)"
                }
            }
        }

        # --- Prefetch ---
        @{ Name = "Cleanup - Windows Prefetch Cache"; Type = "File"; Paths = @("C:\WINDOWS\Prefetch"); FilesOnly = $false }

        # --- Thumbnails ---
        @{ Name = "Cleanup - Explorer Thumbnail/Icon Cache"; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\Explorer"); PerUser = $true; FilesOnly = $true; TakeOwnership = $true }

        # --- Browser & Web Cache (Consolidato) ---
        @{ Name = "WinInet Cache - User"; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Microsoft\Windows\INetCache\IE",
                "%LOCALAPPDATA%\Microsoft\Windows\WebCache",
                "%LOCALAPPDATA%\Microsoft\Feeds Cache",
                "%LOCALAPPDATA%\Microsoft\InternetExplorer\DOMStore",
                "%LOCALAPPDATA%\Microsoft\Internet Explorer"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Temporary Internet Files"; Type = "File"; Paths = @("%USERPROFILE%\Local Settings\Temporary Internet Files"); PerUser = $true; FilesOnly = $false }
        @{ Name = "Cache/History Cleanup"; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "8") }
        @{ Name = "Form Data Cleanup"; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "2") }
        @{ Name = "Internet Cookies Cleanup"; Type = "File"; Paths = @(
                "%APPDATA%\Microsoft\Windows\Cookies",
                "%LOCALAPPDATA%\Microsoft\Windows\INetCookies"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Cookies Cleanup"; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "1") }
        @{ Name = "Chrome Browser Cache & Logs"; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Google\Chrome\User Data\Crashpad\reports",
                "%LOCALAPPDATA%\Google\CrashReports",
                "%LOCALAPPDATA%\Google\Chrome\User Data\Software Reporter Tool"
            ); PerUser = $true; FilesOnly = $true
        }
        @{ Name = "Firefox Browser Data"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage -Type 'Info' -Text "🦊 Pulizia Firefox..."

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
            ); PerUser = $true; FilesOnly = $false
        }

        @{ Name = "DNS Flush"; Type = "Command"; Command = "ipconfig"; Args = @("/flushdns") }

        # --- Temp Files (Consolidato) ---
        @{ Name = "System Temp Files"; Type = "File"; Paths = @("C:\WINDOWS\Temp"); FilesOnly = $false }
        @{ Name = "User Temp Files"; Type = "File"; Paths = @("%TEMP%", "%USERPROFILE%\AppData\Local\Temp", "%USERPROFILE%\AppData\LocalLow\Temp"); PerUser = $true; FilesOnly = $false }
        @{ Name = "Service Profiles Temp"; Type = "File"; Paths = @("%SYSTEMROOT%\ServiceProfiles\LocalService\AppData\Local\Temp"); FilesOnly = $false }

        # --- System & Component Logs ---
        @{ Name = "System & Component Logs"; Type = "File"; Paths = @(
                "C:\WINDOWS\Logs",
                "C:\WINDOWS\System32\LogFiles",
                "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
                "%SYSTEMROOT%\Logs\waasmedic",
                "%SYSTEMROOT%\Logs\SIH",
                "%SYSTEMROOT%\Logs\NetSetup",
                "%SYSTEMROOT%\System32\LogFiles\setupcln",
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
                "%SYSTEMROOT%\debug\PASSWD.LOG"
            ); FilesOnly = $true
        }

        # --- User Registry History ---
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
                    Write-StyledMessage -Type 'Info' -Text "🖨️ Pulizia coda di stampa (Spooler)..."

                    Write-StyledMessage -Type 'Info' -Text "⏸️ Arresto servizio Spooler..."
                    Stop-Service -Name Spooler -Force -ErrorAction Stop | Out-Null
                    Write-StyledMessage -Type 'Info' -Text "Servizio Spooler arrestato."
                    Start-Sleep -Seconds 2

                    $printersPath = 'C:\WINDOWS\System32\spool\PRINTERS'
                    if (Test-Path $printersPath) {
                        $files = Get-ChildItem -Path $printersPath -Force -ErrorAction SilentlyContinue
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        Write-StyledMessage -Type 'Info' -Text "Coda di stampa pulita in $printersPath ($($files.Count) file rimossi)"
                    }

                    Write-StyledMessage -Type 'Info' -Text "▶️ Riavvio servizio Spooler..."
                    Start-Service -Name Spooler -ErrorAction Stop | Out-Null
                    Write-StyledMessage -Type 'Info' -Text "Servizio Spooler riavviato."

                    Write-StyledMessage -Type 'Success' -Text "Print Queue Spooler pulito e riavviato con successo."
                }
                catch {
                    Start-Service -Name Spooler -ErrorAction SilentlyContinue
                    Write-StyledMessage -Type 'Warning' -Text "Errore durante la pulizia Spooler: $($_.Exception.Message)"
                }
            }
        }

        # --- SRUM & Defender ---
        @{ Name = "Stop DPS"; Type = "Service"; ServiceName = "DPS"; Action = "Stop" }
        @{ Name = "SRUM Data"; Type = "File"; Paths = @("%SYSTEMROOT%\System32\sru\SRUDB.dat"); FilesOnly = $true; TakeOwnership = $true }
        @{ Name = "Start DPS"; Type = "Service"; ServiceName = "DPS"; Action = "Start" }

        # --- Utility Apps ---
        @{ Name = "Listary Index"; Type = "File"; Paths = @("%APPDATA%\Listary\UserData"); PerUser = $true }
        @{ Name = "Quick Access"; Type = "File"; Paths = @("%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations", "%APPDATA%\Microsoft\Windows\Recent\CustomDestinations", "%APPDATA%\Microsoft\Windows\Recent Items"); PerUser = $true }

        # --- Legacy Applications & Media ---
        @{ Name = "Flash Player Traces"; Type = "File"; Paths = @("%APPDATA%\Macromedia\Flash Player"); PerUser = $true }

        # --- Enhanced DiagTrack Service Management ---
        @{ Name = "Enhanced DiagTrack Management"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage -Type 'Info' -Text "🔄 Gestione migliorata servizio DiagTrack..."

                function Get-StateFilePath($BaseName, $Suffix) {
                    $escapedBaseName = $BaseName.Split([IO.Path]::GetInvalidFileNameChars()) -Join '_'
                    $uniqueFilename = $escapedBaseName, $Suffix -Join '-'
                    $path = [IO.Path]::Combine($env:APPDATA, 'WinToolkit', 'state', $uniqueFilename)
                    return $path
                }

                function Get-UniqueStateFilePath($BaseName) {
                    $suffix = New-Guid
                    $path = Get-StateFilePath -BaseName $BaseName -Suffix $suffix
                    if (Test-Path -Path $path) {
                        Write-Verbose "Path collision detected at: '$path'. Generating new path..."
                        return Get-UniqueStateFilePath $serviceName
                    }
                    return $path
                }

                function New-EmptyFile($Path) {
                    $parentDirectory = [System.IO.Path]::GetDirectoryName($Path)
                    if (-not (Test-Path $parentDirectory -PathType Container)) {
                        try { New-Item -ItemType Directory -Path $parentDirectory -Force -ErrorAction Stop | Out-Null }
                        catch { Write-StyledMessage -Type 'Warning' -Text "Failed to create parent directory: $_"; return $false }
                    }
                    try { New-Item -ItemType File -Path $Path -Force -ErrorAction Stop | Out-Null; return $true }
                    catch { Write-StyledMessage -Type 'Warning' -Text "Failed to create file: $_"; return $false }
                }

                $serviceName = 'DiagTrack'
                Write-StyledMessage -Type 'Info' -Text "Verifica stato servizio $serviceName..."

                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if (-not $service) {
                    Write-StyledMessage -Type 'Warning' -Text "Servizio $serviceName non trovato, skip"
                    return
                }

                if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                    Write-StyledMessage -Type 'Info' -Text "Servizio $serviceName attivo, arresto in corso..."
                    try {
                        $service | Stop-Service -Force -ErrorAction Stop
                        $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped, [TimeSpan]::FromSeconds(30))
                        $path = Get-UniqueStateFilePath $serviceName
                        if (New-EmptyFile $path) {
                            Write-StyledMessage -Type 'Success' -Text "Servizio arrestato e stato salvato - riavvio automatico abilitato"
                        }
                        else {
                            Write-StyledMessage -Type 'Warning' -Text "Servizio arrestato - riavvio manuale richiesto"
                        }
                    }
                    catch { Write-StyledMessage -Type 'Warning' -Text "Errore durante arresto servizio: $_" }
                }
                else {
                    Write-StyledMessage -Type 'Info' -Text "Servizio $serviceName non attivo, verifica riavvio..."
                    $fileGlob = Get-StateFilePath -BaseName $serviceName -Suffix '*'
                    $stateFiles = Get-ChildItem -Path $fileGlob -ErrorAction SilentlyContinue

                    if ($stateFiles.Count -eq 1) {
                        try {
                            Remove-Item -Path $stateFiles[0].FullName -Force -ErrorAction Stop
                            $service | Start-Service -ErrorAction Stop
                            Write-StyledMessage -Type 'Success' -Text "Servizio $serviceName riavviato con successo"
                        }
                        catch { Write-StyledMessage -Type 'Warning' -Text "Errore durante riavvio servizio: $_" }
                    }
                    elseif ($stateFiles.Count -gt 1) {
                        Write-StyledMessage -Type 'Info' -Text "Multiple state files found, servizio non verrà riavviato automaticamente"
                    }
                    else {
                        Write-StyledMessage -Type 'Info' -Text "Servizio $serviceName non era attivo precedentemente"
                    }
                }
            }
        }

        # --- Special Operations ---
        @{ Name = "Credential Manager"; Type = "Custom"; ScriptBlock = {
                Write-StyledMessage -Type 'Info' -Text "🔑 Pulizia Credenziali..."
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
                        Write-StyledMessage -Type 'Info' -Text "🗑️ Rimozione Windows.old..."

                        Write-StyledMessage -Type 'Info' -Text "1. Assunzione proprietà (Take Ownership)..."
                        $null = & cmd /c "takeown /F `"$path`" /R /A >nul 2>&1"

                        Write-StyledMessage -Type 'Info' -Text "2. Assegnazione permessi di Controllo Completo..."
                        $adminSID = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
                        $adminAccount = $adminSID.Translate([System.Security.Principal.NTAccount]).Value
                        $null = & cmd /c "icacls `"$path`" /T /grant `"${adminAccount}:F`" >nul 2>&1"

                        Write-StyledMessage -Type 'Info' -Text "3. Rimozione forzata della cartella..."
                        Remove-Item -Path $path -Recurse -Force -ErrorAction Stop

                        if (Test-Path -Path $path) {
                            Write-StyledMessage -Type 'Error' -Text "ERRORE: La cartella $path non è stata rimossa."
                        }
                        else {
                            Write-StyledMessage -Type 'Success' -Text "✅ La cartella Windows.old è stata rimossa con successo."
                        }
                    }
                    catch {
                        Write-StyledMessage -Type 'Error' -Text "ERRORE durante la rimozione di Windows.old: $($_.Exception.Message)"
                    }
                }
                else {
                    Write-StyledMessage -Type 'Info' -Text "💭 La cartella Windows.old non è presente."
                }
            }
        }
        @{ Name = "Empty Recycle Bin"; Type = "Custom"; ScriptBlock = {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                Write-StyledMessage -Type 'Success' -Text "🗑️ Cestino svuotato"
            }
        }
    )

    # ============================================================================
    # 5. ESECUZIONE REGOLE
    # ============================================================================

    $totalRules = $Rules.Count
    $currentRuleIndex = 0
    $successCount = 0
    $warningCount = 0
    $errorCount = 0

    foreach ($rule in $Rules) {
        $currentRuleIndex++
        $percent = [math]::Round(($currentRuleIndex / $totalRules) * 100)

        # Clear line before showing progress to avoid ghosting
        Clear-ProgressLine
        Show-ProgressBar -Activity "Esecuzione regole" -Status "$($rule.Name)" -Percent $percent -Icon '⚙️'

        $result = Invoke-WinCleanerRule -Rule $rule

        # Clear progress bar line after rule execution to ensure next log message is clean
        Clear-ProgressLine

        if ($result) {
            $successCount++
        }
        else {
            $errorCount++
        }
    }

    # ============================================================================
    # 6. RIEPILOGO OPERAZIONI
    # ============================================================================

    Clear-ProgressLine
    Write-Host "`n"
    Write-StyledMessage -Type 'Info' -Text "=================================================="
    Write-StyledMessage -Type 'Info' -Text "               RIEPILOGO OPERAZIONI               "
    Write-StyledMessage -Type 'Info' -Text "=================================================="

    # Group logs by type for summary stats
    $stats = $global:ExecutionLog | Group-Object Type
    $sCount = ($stats | Where-Object Name -eq 'Success').Count
    $wCount = ($stats | Where-Object Name -eq 'Warning').Count
    $eCount = ($stats | Where-Object Name -eq 'Error').Count

    Write-StyledMessage -Type 'Success' -Text "✅ Operazioni completate con successo: $sCount"
    if ($wCount -gt 0) { Write-StyledMessage -Type 'Warning' -Text "⚠️ Avvisi generati: $wCount" }
    if ($eCount -gt 0) { Write-StyledMessage -Type 'Error' -Text "❌ Errori riscontrati: $eCount" }

    Write-StyledMessage -Type 'Info' -Text "--------------------------------------------------"
    Write-StyledMessage -Type 'Info' -Text "Dettaglio Errori e Warning:"

    $problems = $global:ExecutionLog | Where-Object { $_.Type -in 'Warning', 'Error' }
    if ($problems) {
        foreach ($p in $problems) {
            $icon = if ($p.Type -eq 'Error') { '❌' } else { '⚠️' }
            Write-Host "[$($p.Timestamp)] $icon $($p.Text)" -ForegroundColor ($p.Type -eq 'Error' ? 'Red' : 'Yellow')
        }
    }
    else {
        Write-StyledMessage -Type 'Success' -Text "Nessun problema rilevato."
    }

    Write-StyledMessage -Type 'Info' -Text "=================================================="
    Write-Host "`n"

    $shouldReboot = Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio sistema in"
    if ($shouldReboot) {
        Restart-Computer -Force
    }
}
