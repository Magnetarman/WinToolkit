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
        [ValidateRange(0, 300)]
        [int]$CountdownSeconds = 30,

        [switch]$SuppressIndividualReboot
    )

    $script:WinCleanerLog = @()

    # Add-CleanerLog: accumula i messaggi nel log interno di WinCleaner per il
    # riepilogo finale ($script:WinCleanerLog) E chiama Write-StyledMessage del
    # framework per il feedback all'utente.
    function Add-CleanerLog {
        param(
            [Parameter(Mandatory = $true, Position = 0)]
            [ValidateSet('Success', 'Info', 'Warning', 'Error', 'Question')]
            [string]$Type,

            [Parameter(Mandatory = $true, Position = 1)]
            [string]$Text
        )

        Clear-ProgressLine

        $script:WinCleanerLog += @{
            Timestamp = Get-Date -Format "HH:mm:ss"
            Type      = $Type
            Text      = $Text
        }

        Write-StyledMessage -Type $Type -Text $Text
    }

    Start-ToolkitSession -ToolName "WinCleaner" -SubTitle "Cleaner Toolkit"
    $timeout = 86400
    $ProgressPreference = 'Continue'

    $VitalExclusions = @(
        "$env:LOCALAPPDATA\WinToolkit"
    )

    function Test-VitalExclusion {
        param([string]$Path)
        if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
        $fullPath = $Path -replace '"', ''
        try {
            if (-not [System.IO.Path]::IsPathRooted($fullPath)) {
                $fullPath = Join-Path (Get-Location) $fullPath
            }
            foreach ($excluded in $VitalExclusions) {
                if ($fullPath -like "$excluded*" -or $fullPath -eq $excluded) {
                    Add-CleanerLog -Type 'Info' -Text "🛡️ PROTEZIONE VITALE ATTIVATA: $fullPath"
                    return $true
                }
            }
        }
        catch { return $false }
        return $false
    }

    function Invoke-CommandAction {
        param($Rule)
        Clear-ProgressLine
        Write-StyledMessage -Type 'Info' -Text "🚀 Esecuzione comando: $($Rule.Name)."
        try {
            $result = Invoke-WithSpinner -Activity $Rule.Name -Command $Rule.Command -Arguments $Rule.Args -TimeoutSeconds $timeout -LogContextKey "Cleaner-$($Rule.Name)"

            if ($result.TimedOut) {
                Write-StyledMessage -Type 'Warning' -Text "Comando timeout dopo $($timeout/3600) ore."
                return $true
            }

            if ($result.ExitCode -eq -2146498554 -or $result.ExitCode -eq 0x800F0818) {
                Add-CleanerLog -Type 'Warning' -Text "ATTENZIONE! - Stai effettuando la pulizia con Windows Update in corso. Aggiorna il sistema e riprova per eseguire la pulizia completa"
                return $false
            }

            $isSuccess = ($result.ExitCode -eq 0)
            Add-CleanerLog -Type ($isSuccess ? 'Info' : 'Warning') -Text ($isSuccess ? "Comando completato." : "Comando completato con codice $($result.ExitCode)")
            return $true
        }
        catch {
            Add-CleanerLog -Type 'Error' -Text "Errore comando: $_"
            return $false
        }
    }

    function Invoke-ServiceAction {
        param($Rule)
        $svcName = $Rule.ServiceName
        $action = $Rule.Action

        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if (-not $svc) { return $true }

            if ($action -eq 'Stop' -and $svc.Status -eq 'Running') {
                Add-CleanerLog -Type 'Info' -Text "⏸️ Arresto servizio $svcName."
                Stop-Service -Name $svcName -Force -ErrorAction Stop *>$null
            }
            elseif ($action -eq 'Start' -and $svc.Status -ne 'Running') {
                Add-CleanerLog -Type 'Info' -Text "▶️ Avvio servizio $svcName."
                Start-Service -Name $svcName -ErrorAction Stop *>$null
            }
            return $true
        }
        catch {
            Add-CleanerLog -Type 'Warning' -Text "Errore servizio $svcName : $_"
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
            $users = Get-LocalUserProfiles
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
                    Add-CleanerLog -Type 'Info' -Text "🔑 Assunzione proprietà per $path."
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
                Add-CleanerLog -Type 'Warning' -Text "Errore rimozione $path : $_"
            }
        }
        if ($count -gt 0) { Write-StyledMessage -Type 'Success' -Text "🗑️ Puliti $count elementi in $($Rule.Name)." }
        return $true
    }

    function Remove-RegistryItem {
        param($Rule)
        $keys = $Rule.Keys
        $recursive = $Rule.Recursive
        $valuesOnly = $Rule.ValuesOnly

        foreach ($rawKey in $keys) {
            $key = $rawKey -replace '^(HKCU|HKLM):\\*', '$1:\'
            if (-not (Test-Path $key)) { continue }
            try {
                if ($valuesOnly) {
                    $item = Get-Item $key -ErrorAction Stop
                    $item.GetValueNames() | ForEach-Object {
                        if ($_ -ne '(default)') { Remove-ItemProperty -LiteralPath $key -Name $_ -Force -ErrorAction SilentlyContinue *>$null }
                    }
                    if ($recursive) {
                        Get-ChildItem $key -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                            $currentKeyPath = $_.PSPath
                            $_.GetValueNames() | ForEach-Object { Remove-ItemProperty -LiteralPath $currentKeyPath -Name $_ -Force -ErrorAction SilentlyContinue *>$null }
                        }
                    }
                    Add-CleanerLog -Type 'Success' -Text "⚙️ Puliti valori in $key"
                }
                else {
                    Remove-Item -Path $key -Recurse:$recursive -Force -ErrorAction Stop
                    Add-CleanerLog -Type 'Success' -Text "🗑️ Rimossa chiave $key"
                }
            }
            catch {
                Add-CleanerLog -Type 'Warning' -Text "Errore registro $key : $_"
            }
        }
        return $true
    }

    function Set-RegistryItem {
        param($Rule)
        $key = $Rule.Key -replace '^(HKCU|HKLM):', '$1:\'
        try {
            Set-RegistryValue -Path $key -Name $Rule.ValueName -Value $Rule.ValueData -Type $Rule.ValueType
            Add-CleanerLog -Type 'Success' -Text "⚙️ Impostato $key\$($Rule.ValueName)"
            return $true
        }
        catch { return $false }
    }

    function Invoke-WinCleanerRule {
        param($Rule)
        Clear-ProgressLine
        switch ($Rule.Type) {
            'File' { return Remove-FileItem -Rule $Rule }
            'Registry' { return Remove-RegistryItem -Rule $Rule }
            'RegSet' { return Set-RegistryItem -Rule $Rule }
            'Service' { return Invoke-ServiceAction -Rule $Rule }
            'Command' { return Invoke-CommandAction -Rule $Rule }
            'ScriptBlock' {
                if ($Rule.ScriptBlock) {
                    & $Rule.ScriptBlock
                    return $true
                }
            }
            'Custom' {
                if ($Rule.ScriptBlock) {
                    & $Rule.ScriptBlock
                    return $true
                }
            }
        }
        return $true
    }

    $Rules = @(
        # --- CleanMgr Auto ---
        @{ Name = "CleanMgr Config"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "🧹 Configurazione CleanMgr."
                $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
                $opts = @(
                    "Active Setup Temp Folders",
                    "BranchCache",
                    "D3D Shader Cache",
                    "Delivery Optimization Files",
                    "Device Driver Packages",
                    "Downloaded Program Files",
                    "Internet Cache Files",
                    "Memory Dump Files",
                    "Old ChkDsk Files",
                    "Recycle Bin",
                    "Temporary Files",
                    "Thumbnail Cache",
                    "Update Cleanup",
                    "Windows Defender",
                    "Windows Error Reporting Files",
                    "Setup Log Files",
                    "System error memory dump files",
                    "System error minidump files",
                    "Temporary Setup Files",
                    "Windows Upgrade Log Files"
                )
                foreach ($o in $opts) {
                    $p = Join-Path $reg $o
                    if (Test-Path $p) { Set-ItemProperty -Path $p -Name "StateFlags0065" -Value 2 -Type DWORD -Force -ErrorAction SilentlyContinue }
                }

                $cleanMgrExecutionRule = @{
                    Name    = "Esecuzione CleanMgr con /sagerun:65";
                    Type    = "Command";
                    Command = "cleanmgr.exe";
                    Args    = @("/sagerun:65");
                }
                Invoke-CommandAction -Rule $cleanMgrExecutionRule

                # cleanmgr.exe /sagerun spawna un processo figlio ed il padre esce subito;
                # bisogna attendere che TUTTE le istanze terminino prima di proseguire,
                # altrimenti CleanMgr lavora in background in parallelo con DISM e altri step.
                Add-CleanerLog -Type 'Info' -Text "⏳ Attesa completamento CleanMgr (può richiedere alcuni minuti)..."
                $cmDeadline = (Get-Date).AddHours(1)
                while ((Get-Process -Name "cleanmgr" -ErrorAction SilentlyContinue) -and (Get-Date) -lt $cmDeadline) {
                    Start-Sleep -Seconds 10
                }
                Add-CleanerLog -Type 'Info' -Text "✅ CleanMgr completato."
            }
        }

        # --- WinSxS ---
        @{ Name = "WinSxS Cleanup"; Type = "Command"; Command = "DISM.exe"; Args = @("/Online", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase") }
        @{ Name = "Minimize DISM"; Type = "RegSet"; Key = "HKLM:\Software\Microsoft\Windows\CurrentVersion\SideBySide\Configuration"; ValueName = "DisableResetbase"; ValueData = 0; ValueType = "DWORD" }

        # --- Error Reports ---
        @{ Name = "Error Reports"; Type = "File"; Paths = @(
                "$env:ProgramData\Microsoft\Windows\WER",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\WER"
            ); FilesOnly = $false
        }

        # --- Event Logs ---
        @{ Name = "Clear Event Logs"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "📜 Pulizia Event Logs (classici + moderni)."

                # Log classici (Application, System, Security, ecc.) via Clear-EventLog
                $classicLogs = Get-EventLog -List -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Log
                foreach ($logName in $classicLogs) {
                    try {
                        Clear-EventLog -LogName $logName -ErrorAction Stop
                        Write-ToolkitLog -Level DEBUG -Message "Clear-EventLog: $logName"
                    }
                    catch {
                        Write-ToolkitLog -Level DEBUG -Message "Clear-EventLog [$logName]: $($_.Exception.Message)"
                    }
                }

                # Log moderni (Vista+) via wevtutil — copre tutto quello che Clear-EventLog non raggiunge
                $wevtErr = $null
                & wevtutil sl 'Microsoft-Windows-LiveId/Operational' /ca:'O:BAG:SYD:(A;;0x1;;;SY)(A;;0x5;;;BA)(A;;0x1;;;LA)' 2>&1 | Out-String -OutVariable wevtErr *>$null
                if ($wevtErr) { Write-ToolkitLog -Level DEBUG -Message "wevtutil sl output: $wevtErr" }
                Get-WinEvent -ListLog * -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    $logName = $_.LogName
                    # I log Analytical/Debug devono essere disabilitati prima di essere cancellati;
                    # wevtutil cl fallisce con "Accesso negato" finché sono attivi.
                    if ($_.LogType -in 'Analytical', 'Debug') {
                        Wevtutil.exe sl $logName /e:false *>$null
                    }
                    $clErr = $null
                    Wevtutil.exe cl $logName 2>&1 | Out-String -OutVariable clErr *>$null
                    if ($LASTEXITCODE -ne 0 -and $clErr) { Write-ToolkitLog -Level DEBUG -Message "Wevtutil cl [$logName]: $clErr" }
                }

                Add-CleanerLog -Type 'Success' -Text "Event Log classici e moderni cancellati."
            }
        }

        # --- Windows Update ---
        @{ Name = "Clear Windows Update cache"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "🔄 Pulizia cache di Windows Update."

                $services = @("wuauserv", "bits")
                foreach ($s in $services) {
                    Invoke-ServiceAction -Rule @{ ServiceName = $s; Action = "Stop" }
                }

                $paths = @(
                    "C:\Windows\SoftwareDistribution\Download",
                    "C:\Windows\SoftwareDistribution\DataStore"
                )
                foreach ($p in $paths) {
                    if (Test-Path $p) {
                        try {
                            Add-CleanerLog -Type 'Info' -Text "🗑️ Rimozione: $p"
                            Remove-Item -Path "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text "Impossibile pulire completamente $p"
                        }
                    }
                }

                foreach ($s in $services) {
                    Invoke-ServiceAction -Rule @{ ServiceName = $s; Action = "Start" }
                }

                Add-CleanerLog -Type 'Success' -Text "Windows Update cache cleared."
            }
        }

        @{ Name = "Windows App/Download Cache - User"; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Microsoft\Windows\AppCache",
                "%LOCALAPPDATA%\Microsoft\Windows\Caches"
            ); PerUser = $true; FilesOnly = $true
        }

        # --- Restore Points ---
        @{ Name = "System Restore Points"; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Add-CleanerLog -Type 'Info' -Text "💾 Pulizia punti di ripristino sistema."

                    Add-CleanerLog -Type 'Info' -Text "🗑️ Analisi e pulizia shadow copies (mantieni ultima)."
                    try {
                        $shadows = Get-CimInstance -ClassName Win32_ShadowCopy -ErrorAction Stop | Sort-Object InstallDate -Descending
                        if ($shadows.Count -gt 1) {
                            $toDelete = $shadows | Select-Object -Skip 1
                            $count = $toDelete.Count
                            Add-CleanerLog -Type 'Info' -Text "Rilevate $($shadows.Count) shadow copies. Rimozione di $count vecchie."

                            foreach ($shadow in $toDelete) {
                                Remove-CimInstance -InputObject $shadow -ErrorAction SilentlyContinue
                            }
                            Add-CleanerLog -Type 'Success' -Text "Vecchie shadow copies rimosse. Ultima copia preservata."
                        }
                        elseif ($shadows.Count -eq 1) {
                            Add-CleanerLog -Type 'Info' -Text "Trovata una sola shadow copy. Nessuna rimozione necessaria."
                        }
                        else {
                            Add-CleanerLog -Type 'Info' -Text "Nessuna shadow copy rilevata."
                        }
                    }
                    catch {
                        Add-CleanerLog -Type 'Warning' -Text "Errore gestione shadow copies: $_"
                    }

                    Add-CleanerLog -Type 'Info' -Text "💡 Protezione sistema mantenuta attiva per sicurezza"
                    Add-CleanerLog -Type 'Success' -Text "Pulizia punti di ripristino completata"
                }
                catch {
                    Add-CleanerLog -Type 'Warning' -Text "Errore durante la pulizia punti di ripristino: $($_.Exception.Message)"
                }
            }
        }

        # --- Prefetch ---
        @{ Name = "Cleanup - Windows Prefetch Cache"; Type = "File"; Paths = @("C:\WINDOWS\Prefetch"); FilesOnly = $false }

        # --- Thumbnails ---
        @{ Name = "Cleanup - Explorer Thumbnail/Icon Cache"; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\Explorer"); PerUser = $true; FilesOnly = $true; TakeOwnership = $true }

        # --- Browser & Web Cache ---
        @{ Name = "WinInet Cache - User"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "🌐 Pulizia cache WinInet/WebCache."

                # CacheTask (taskhostw.exe) mantiene un lock ESE su WebCache\V01.log e IE\CacheStorage\edb.log;
                # deve essere fermato e disabilitato prima della pulizia, altrimenti Remove-Item fallisce.
                $cacheTaskDisabled = $false
                try {
                    $ct = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Wininet\' -TaskName 'CacheTask' -ErrorAction SilentlyContinue
                    if ($ct -and $ct.State -ne 'Disabled') {
                        Stop-ScheduledTask -TaskPath '\Microsoft\Windows\Wininet\' -TaskName 'CacheTask' -ErrorAction SilentlyContinue
                        Disable-ScheduledTask -TaskPath '\Microsoft\Windows\Wininet\' -TaskName 'CacheTask' -ErrorAction SilentlyContinue *>$null
                        $cacheTaskDisabled = $true
                        Start-Sleep -Seconds 2
                    }
                }
                catch { Write-ToolkitLog -Level DEBUG -Message "CacheTask disable error: $_" }

                $users = Get-LocalUserProfiles
                foreach ($u in $users) {
                    $paths = @(
                        "$($u.FullName)\AppData\Local\Microsoft\Windows\INetCache\IE",
                        "$($u.FullName)\AppData\Local\Microsoft\Windows\WebCache",
                        "$($u.FullName)\AppData\Local\Microsoft\Feeds Cache",
                        "$($u.FullName)\AppData\Local\Microsoft\InternetExplorer\DOMStore",
                        "$($u.FullName)\AppData\Local\Microsoft\Internet Explorer"
                    )
                    foreach ($p in $paths) {
                        if (-not (Test-Path $p)) { continue }
                        Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
                        if (Test-Path $p) {
                            # Fallback file-per-file: salta i file ancora bloccati da altri processi
                            Get-ChildItem -Path $p -Recurse -File -Force -ErrorAction SilentlyContinue |
                                ForEach-Object { Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue }
                            Get-ChildItem -Path $p -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                                Sort-Object { $_.FullName.Length } -Descending |
                                ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
                        }
                    }
                }

                if ($cacheTaskDisabled) {
                    try {
                        Enable-ScheduledTask -TaskPath '\Microsoft\Windows\Wininet\' -TaskName 'CacheTask' -ErrorAction SilentlyContinue *>$null
                    }
                    catch { Write-ToolkitLog -Level DEBUG -Message "CacheTask enable error: $_" }
                }

                Add-CleanerLog -Type 'Success' -Text "✅ Cache WinInet/WebCache pulita."
            }
        }
        @{ Name = "Temporary Internet Files"; Type = "File"; Paths = @(
                "%USERPROFILE%\Local Settings\Temporary Internet Files"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Cache/History Cleanup"; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "8") }
        @{ Name = "Form Data Cleanup"; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "2") }
        @{ Name = "Internet Cookies Cleanup"; Type = "File"; Paths = @(
                "%APPDATA%\Microsoft\Windows\Cookies",
                "%LOCALAPPDATA%\Microsoft\Windows\INetCookies"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Cookies Cleanup"; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "1") }
        @{ Name = "Chromium Browsers Cache (Chrome, Edge, Brave, Vivaldi)"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "🌐 Pulizia Cache Browser Chromium."

                $browsers = @(
                    @{ Name = "Google Chrome"; Path = "Google\Chrome\User Data" },
                    @{ Name = "Microsoft Edge"; Path = "Microsoft\Edge\User Data" },
                    @{ Name = "Brave Browser"; Path = "BraveSoftware\Brave-Browser\User Data" },
                    @{ Name = "Vivaldi"; Path = "Vivaldi\User Data" }
                )

                $users = Get-LocalUserProfiles
                foreach ($u in $users) {
                    foreach ($b in $browsers) {
                        $userDataPath = Join-Path "$($u.FullName)\AppData\Local" $b.Path
                        if (Test-Path $userDataPath) {
                            $patterns = @(
                                "$userDataPath\*\Cache",
                                "$userDataPath\*\Code Cache",
                                "$userDataPath\*\GPUCache",
                                "$userDataPath\*\ShaderCache",
                                "$userDataPath\CrashReports"
                            )
                            foreach ($p in $patterns) {
                                Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                }
            }
        }
        @{ Name = "Google Chrome AI OptGuide Model"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "🤖 Pulizia e disattivazione AI Chrome (OptGuide)."

                $users = Get-LocalUserProfiles
                foreach ($u in $users) {
                    $optGuidePath = Join-Path "$($u.FullName)\AppData\Local" "Google\Chrome\User Data\OptGuideOnDeviceModel"
                    if (Test-Path $optGuidePath) {
                        try {
                            Add-CleanerLog -Type 'Info' -Text "🗑️ Rimozione cartella OptGuide: $optGuidePath"
                            Remove-Item -Path $optGuidePath -Recurse -Force -ErrorAction Stop
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text "Errore rimozione $optGuidePath : $_"
                        }
                    }

                    # Ricrea la cartella e imposta come read-only per bloccare Chrome
                    try {
                        if (-not (Test-Path $optGuidePath)) {
                            New-Item -Path $optGuidePath -ItemType Directory -Force -ErrorAction Stop *>$null
                        }
                        $acl = Get-Acl -Path $optGuidePath -ErrorAction Stop
                        $acl.SetAccessRuleProtection($true, $false)
                        $denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                            "Everyone", "Write", "ContainerInherit,ObjectInherit", "None", "Deny"
                        )
                        $acl.AddAccessRule($denyRule)
                        Set-Acl -Path $optGuidePath -AclObject $acl -ErrorAction Stop
                        Add-CleanerLog -Type 'Success' -Text "🔒 Cartella OptGuide impostata in sola lettura: $optGuidePath"
                    }
                    catch {
                        Add-CleanerLog -Type 'Warning' -Text "Errore impostazione read-only per $optGuidePath : $_"
                    }
                }

                $chromePolicyKey = "HKLM:\SOFTWARE\Policies\Google\Chrome"
                try {
                    if (-not (Test-Path $chromePolicyKey)) {
                        New-Item -Path $chromePolicyKey -Force -ErrorAction Stop *>$null
                    }

                    $aiPolicies = @{
                        "GenAILocalFoundationalModelSettings" = 1
                        "AIModeSettings" = 2
                        "GeminiSettings" = 1
                        "HelpMeWriteSettings" = 2
                        "DevToolsGenAiSettings" = 2
                    }

                    foreach ($policy in $aiPolicies.GetEnumerator()) {
                        Set-ItemProperty -Path $chromePolicyKey -Name $policy.Key -Value $policy.Value -Type DWORD -Force -ErrorAction Stop
                        Add-CleanerLog -Type 'Success' -Text "⚙️ Policy Chrome impostata: $($policy.Key) = $($policy.Value)"
                    }
                }
                catch {
                    Add-CleanerLog -Type 'Warning' -Text "Errore impostazione policy Chrome AI: $_"
                }
            }
        }
        @{ Name = "Firefox Browser Cache"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "🦊 Pulizia Firefox (Cache & Crashes)."

                $users = Get-LocalUserProfiles
                foreach ($u in $users) {
                    $cleanPaths = @(
                        "$($u.FullName)\AppData\Local\Mozilla\Firefox\Profiles",
                        "$($u.FullName)\AppData\Local\Mozilla\Firefox\Crash Reports"
                    )
                    foreach ($p in $cleanPaths) {
                        if (Test-Path $p) { Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue }
                    }

                    $msStoreProfiles = Get-ChildItem `
                        "$($u.FullName)\AppData\Local\Packages" `
                        -Directory -Filter "Mozilla.Firefox_*" `
                        -ErrorAction SilentlyContinue
                    foreach ($pkg in $msStoreProfiles) {
                        $msCache = "$($pkg.FullName)\LocalCache\Roaming\Mozilla\Firefox\Profiles"
                        if (Test-Path $msCache) { Remove-Item -Path $msCache -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                }
            }
        }
        @{ Name = "Edge Legacy (HTML) Cache"; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC\*\MicrosoftEdge\Cache",
                "%LOCALAPPDATA%\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC\#!001\MicrosoftEdge\Cache"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Opera & Java Cache"; Type = "File"; Paths = @(
                "%USERPROFILE%\Local Settings\Application Data\Opera\Opera",
                "%LOCALAPPDATA%\Opera\Opera",
                "%APPDATA%\Opera\Opera",
                "%APPDATA%\Sun\Java\Deployment\cache"
            ); PerUser = $true; FilesOnly = $false
        }

        @{ Name = "DNS Flush"; Type = "Command"; Command = "ipconfig"; Args = @("/flushdns") }

        # --- Temp Files ---
        @{ Name = "System Temp Files"; Type = "File"; Paths = @("C:\WINDOWS\Temp"); FilesOnly = $false }
        @{ Name = "User Temp Files"; Type = "File"; Paths = @(
                "%USERPROFILE%\AppData\Local\Temp",
                "%USERPROFILE%\AppData\LocalLow\Temp"
            ); PerUser = $true; FilesOnly = $false
        }
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

        # --- Developer Telemetry ---
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
                    Add-CleanerLog -Type 'Info' -Text "🖨️ Pulizia coda di stampa (Spooler)."

                    Add-CleanerLog -Type 'Info' -Text "⏸️ Arresto servizio Spooler."
                    Stop-Service -Name Spooler -Force -ErrorAction Stop *>$null
                    Add-CleanerLog -Type 'Info' -Text "Servizio Spooler arrestato."
                    Start-Sleep -Seconds 2

                    $printersPath = 'C:\WINDOWS\System32\spool\PRINTERS'
                    if (Test-Path $printersPath) {
                        $files = Get-ChildItem -Path $printersPath -Force -ErrorAction SilentlyContinue
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        Add-CleanerLog -Type 'Info' -Text "Coda di stampa pulita in $printersPath ($($files.Count) file rimossi)"
                    }

                    Add-CleanerLog -Type 'Info' -Text "▶️ Riavvio servizio Spooler."
                    Start-Service -Name Spooler -ErrorAction Stop *>$null
                    Add-CleanerLog -Type 'Info' -Text "Servizio Spooler riavviato."

                    Add-CleanerLog -Type 'Success' -Text "Print Queue Spooler pulito e riavviato con successo."
                }
                catch {
                    Start-Service -Name Spooler -ErrorAction SilentlyContinue
                    Add-CleanerLog -Type 'Warning' -Text "Errore durante la pulizia Spooler: $($_.Exception.Message)"
                }
            }
        }

        # --- SRUM & Defender ---
        @{ Name = "Stop DPS"; Type = "Service"; ServiceName = "DPS"; Action = "Stop" }
        @{ Name = "SRUM Data"; Type = "File"; Paths = @("%SYSTEMROOT%\System32\sru\SRUDB.dat"); FilesOnly = $true; TakeOwnership = $true }
        @{ Name = "Start DPS"; Type = "Service"; ServiceName = "DPS"; Action = "Start" }

        # --- Utility Apps ---
        @{ Name = "Listary Index"; Type = "File"; Paths = @("%APPDATA%\Listary\UserData"); PerUser = $true }
        @{ Name = "WinUtil Data"; Type = "File"; Paths = @("%LOCALAPPDATA%\winutil"); PerUser = $true }

        # --- Legacy Applications & Media ---
        @{ Name = "Flash Player Traces"; Type = "File"; Paths = @("%APPDATA%\Macromedia\Flash Player"); PerUser = $true }

        # --- Enhanced DiagTrack Service Management ---
        @{ Name = "Enhanced DiagTrack Management"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "🔄 Gestione migliorata servizio DiagTrack."

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
                        Write-Verbose "Path collision detected at: '$path'. Generating new path."
                        return Get-UniqueStateFilePath $serviceName
                    }
                    return $path
                }

                function New-EmptyFile($Path) {
                    $parentDirectory = [System.IO.Path]::GetDirectoryName($Path)
                    if (-not (Test-Path $parentDirectory -PathType Container)) {
                        try { New-Item -ItemType Directory -Path $parentDirectory -Force -ErrorAction Stop *>$null }
                        catch { Write-StyledMessage -Type 'Warning' -Text "Failed to create parent directory: $_"; return $false }
                    }
                    try { New-Item -ItemType File -Path $Path -Force -ErrorAction Stop *>$null; return $true }
                    catch { Write-StyledMessage -Type 'Warning' -Text "Failed to create file: $_"; return $false }
                }

                $serviceName = 'DiagTrack'
                Add-CleanerLog -Type 'Info' -Text "Verifica stato servizio $serviceName."

                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if (-not $service) {
                    Add-CleanerLog -Type 'Warning' -Text "Servizio $serviceName non trovato, skip"
                    return
                }

                if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                    Add-CleanerLog -Type 'Info' -Text "Servizio $serviceName attivo, arresto in corso."
                    try {
                        $service | Stop-Service -Force -ErrorAction Stop
                        $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped, [TimeSpan]::FromSeconds(30))
                        $path = Get-UniqueStateFilePath $serviceName
                        if (New-EmptyFile $path) {
                            Add-CleanerLog -Type 'Success' -Text "Servizio arrestato e stato salvato - riavvio automatico abilitato"
                        }
                        else {
                            Add-CleanerLog -Type 'Warning' -Text "Servizio arrestato - riavvio manuale richiesto"
                        }
                    }
                    catch { Write-StyledMessage -Type 'Warning' -Text "Errore durante arresto servizio: $_" }
                }
                else {
                    Add-CleanerLog -Type 'Info' -Text "Servizio $serviceName non attivo, verifica riavvio."
                    $fileGlob = Get-StateFilePath -BaseName $serviceName -Suffix '*'
                    $stateFiles = Get-ChildItem -Path $fileGlob -ErrorAction SilentlyContinue

                    if ($stateFiles.Count -eq 1) {
                        try {
                            Remove-Item -Path $stateFiles[0].FullName -Force -ErrorAction Stop
                            $service | Start-Service -ErrorAction Stop
                            Add-CleanerLog -Type 'Success' -Text "Servizio $serviceName riavviato con successo"
                        }
                        catch { Write-StyledMessage -Type 'Warning' -Text "Errore durante riavvio servizio: $_" }
                    }
                    elseif ($stateFiles.Count -gt 1) {
                        Add-CleanerLog -Type 'Info' -Text "Multiple state files found, servizio non verrà riavviato automaticamente"
                    }
                    else {
                        Add-CleanerLog -Type 'Info' -Text "Servizio $serviceName non era attivo precedentemente"
                    }
                }
            }
        }

        # --- Special Operations ---
        @{ Name = "Credential Manager"; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text "🔑 Pulizia Credenziali."

                $cmdkeyErr = $null
                $targets = & cmdkey /list 2>&1 | Tee-Object -Variable cmdkeyErr | Where-Object { $_ -match '^Target:' }
                if ($cmdkeyErr -and $LASTEXITCODE -ne 0) { Write-ToolkitLog -Level DEBUG -Message "cmdkey list error: $cmdkeyErr" }

                $targets | ForEach-Object {
                    $t = $_.Split(':')[1].Trim()
                    $delErr = $null
                    & cmdkey /delete:$t 2>&1 | Tee-Object -Variable delErr *>$null
                    if ($delErr -and $LASTEXITCODE -ne 0) { Write-ToolkitLog -Level DEBUG -Message "cmdkey delete [$t] error: $delErr" }
                }
            }
        }
        @{ Name = "Regedit Last Key"; Type = "Registry"; Keys = @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit"); ValuesOnly = $true }
        @{ Name = "Windows.old"; Type = "ScriptBlock"; ScriptBlock = {
                $path = "C:\Windows.old"
                if (Test-Path $path) {
                    Add-CleanerLog -Type 'Info' -Text "🗑️ Rilevata cartella Windows.old. Avvio rimozione sicura con Native CleanMgr."

                    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations"
                    if (-not (Test-Path $regKey)) {
                        Add-CleanerLog -Type 'Warning' -Text "Chiave registro 'Previous Installations' non trovata. Tentativo di esecuzione standard."
                    }
                    else {
                        try {
                            Set-ItemProperty -Path $regKey -Name "StateFlags0066" -Value 2 -Type DWORD -Force -ErrorAction Stop
                            Add-CleanerLog -Type 'Info' -Text "✅ Configurazione CleanMgr attivata per Windows.old (StateFlags0066)."
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text "Impossibile scrivere nel registro per CleanMgr: $_"
                        }
                    }

                    $cleanMgrRule = @{
                        Name    = "Rimozione Windows.old (CleanMgr)";
                        Type    = "Command";
                        Command = "cleanmgr.exe";
                        Args    = @("/sagerun:66");
                    }

                    $null = Invoke-CommandAction -Rule $cleanMgrRule

                    if (Test-Path $path) {
                        Add-CleanerLog -Type 'Info' -Text "ℹ️ La cartella Windows.old potrebbe richiedere un riavvio per la rimozione completa."
                    }
                    else {
                        Add-CleanerLog -Type 'Success' -Text "✅ Windows.old rimosso con successo."
                    }
                }
                else {
                    Add-CleanerLog -Type 'Info' -Text "💭 Nessuna cartella Windows.old rilevata."
                }
            }
        }
        @{ Name = "Empty Recycle Bin"; Type = "Custom"; ScriptBlock = {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                Add-CleanerLog -Type 'Success' -Text "🗑️ Cestino svuotato"
            }
        }
    )

    $totalRules = $Rules.Count
    $currentRuleIndex = 0
    $successCount = 0
    $errorCount = 0

    foreach ($rule in $Rules) {
        $currentRuleIndex++
        $percent = [math]::Round(($currentRuleIndex / $totalRules) * 100)

        Clear-ProgressLine
        Show-ProgressBar -Activity "Esecuzione regole" -Status "$($rule.Name)" -Percent $percent -Icon '⚙️'

        $result = Invoke-WinCleanerRule -Rule $rule

        Clear-ProgressLine

        if ($result) { $successCount++ }
        else { $errorCount++ }
    }

    Clear-ProgressLine

    Write-StyledMessage -Type 'Info' -Text "=================================================="
    Write-StyledMessage -Type 'Info' -Text "               RIEPILOGO OPERAZIONI               "
    Write-StyledMessage -Type 'Info' -Text "=================================================="

    $stats = $script:WinCleanerLog | Group-Object Type
    $sCount = ($stats | Where-Object Name -eq 'Success').Count
    $wCount = ($stats | Where-Object Name -eq 'Warning').Count
    $eCount = ($stats | Where-Object Name -eq 'Error').Count

    Write-StyledMessage -Type 'Success' -Text "Operazioni completate con successo: $sCount."
    if ($wCount -gt 0) { Write-StyledMessage -Type 'Warning' -Text "Avvisi generati: $wCount." }
    if ($eCount -gt 0) { Write-StyledMessage -Type 'Error' -Text "Errori riscontrati: $eCount." }

    Write-StyledMessage -Type 'Info' -Text "--------------------------------------------------"
    Write-StyledMessage -Type 'Info' -Text "Dettaglio Errori e Warning:"

    $problems = $script:WinCleanerLog | Where-Object { $_.Type -in 'Warning', 'Error' }
    if ($problems) {
        foreach ($p in $problems) {
            Write-StyledMessage -Type $p.Type -Text $p.Text
        }
    }
    else {
        Write-StyledMessage -Type 'Success' -Text "Nessun problema rilevato."
    }

    Write-StyledMessage -Type 'Info' -Text "=================================================="

    Invoke-ToolkitReboot -Message "Riavvio sistema in" -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
}
