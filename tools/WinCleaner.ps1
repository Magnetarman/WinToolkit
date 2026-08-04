function WinCleaner {
    <#
    .SYNOPSIS
        Automatically performs a complete Windows system cleanup.

    .DESCRIPTION
        Performs a complete cleanup using a rule-based engine.
        Protects critical folders and provides unified handling of files, the registry, and services.
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

    Start-ToolkitSession -ToolName "WinCleaner" -SubTitle (Get-Loc 'script.WinCleaner')
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
                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'uiText.lifeProtectionActivated0' -Args @($fullPath))
                    return $true
                }
            }
        }
        catch { return $false }
        return $false
    }

    function Invoke-CommandAction {
        param($Rule)
        $displayName = Get-Loc $Rule.NameKey
        Clear-ProgressLine
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.commandExecution0' -Args @($displayName))
        try {
            $result = Invoke-WithSpinner -Activity $displayName -Command $Rule.Command -Arguments $Rule.Args -TimeoutSeconds $timeout -LogContextKey "Cleaner-$($Rule.Name)"

            if ($result.TimedOut) {
                Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.commandTimesOutAfter0Hours' -Args @($($timeout/3600)))
                return $true
            }

            if ($result.ExitCode -eq -2146498554 -or $result.ExitCode -eq 0x800F0818) {
                Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.attentionYouAreCleaningWithWindowsUpdateInProgressRefreshYourSystemAndTryAgainToPerformAFu')
                return $false
            }

            $isSuccess = ($result.ExitCode -eq 0)
            $messageType = if ($isSuccess) { 'Info' } else { 'Warning' }
            $messageText = if ($isSuccess) {
                Get-Loc 'toolText.extra.commandCompleted'
            }
            else {
                Get-Loc 'toolText.extra.commandCompletedWithCode0' -Args @($result.ExitCode)
            }
            Add-CleanerLog -Type $messageType -Text $messageText
            return $true
        }
        catch {
            Add-CleanerLog -Type 'Error' -Text (Get-Loc 'toolText.extra.commandError0' -Args @($_))
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
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.stoppingService0' -Args @($svcName))
                Stop-Service -Name $svcName -Force -ErrorAction Stop *>$null
            }
            elseif ($action -eq 'Start' -and $svc.Status -ne 'Running') {
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.startingService0' -Args @($svcName))
                Start-Service -Name $svcName -ErrorAction Stop *>$null
            }
            return $true
        }
        catch {
            Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.serviceError01' -Args @($svcName, $_))
            return $false
        }
    }

    function Remove-FileItem {
        param($Rule)
        $displayName = Get-Loc $Rule.NameKey
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
                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'uiText.takingOwnershipFor0' -Args @($path))
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
                Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.removalError01' -Args @($path, $_))
            }
        }
        if ($count -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.cleaned0ItemsIn1' -Args @($count, $displayName)) }
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
                    Add-CleanerLog -Type 'Success' -Text (Get-Loc 'uiText.cleanedValuesIn0' -Args @($key))
                }
                else {
                    Remove-Item -Path $key -Recurse:$recursive -Force -ErrorAction Stop
                    Add-CleanerLog -Type 'Success' -Text (Get-Loc 'toolText.extra.removedKey0' -Args @($key))
                }
            }
            catch {
                Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.registerError01' -Args @($key, $_))
            }
        }
        return $true
    }

    function Set-RegistryItem {
        param($Rule)
        $key = $Rule.Key -replace '^(HKCU|HKLM):', '$1:\'
        try {
            Set-RegistryValue -Path $key -Name $Rule.ValueName -Value $Rule.ValueData -Type $Rule.ValueType
            Add-CleanerLog -Type 'Success' -Text (Get-Loc 'toolText.extra2.set01' -Args @($key, $($Rule.ValueName)))
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
        @{ Name = "CleanMgr Config"; NameKey = 'cleanerRule.cleanmgrConfig'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.cleanmgrConfiguration')
                $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
                $opts = @(
                    "Active Setup Temp Folders",
                    "BranchCache",
                    "D3D Shader Cache",
                    "Delivery Optimization Files",
                    'Device Driver Packages',
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
                    Name    = 'Running CleanMgr with /sagerun:65';
                    Type    = "Command";
                    Command = "cleanmgr.exe";
                    Args    = @("/sagerun:65");
                }
                Invoke-CommandAction -Rule $cleanMgrExecutionRule

                # cleanmgr.exe /sagerun spawna un processo figlio ed il padre esce subito;
                # bisogna attendere che TUTTE le istanze terminino prima di proseguire,
                # altrimenti CleanMgr lavora in background in parallelo con DISM e altri step.
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra2.waitingForCleanmgrToCompleteMayTakeAFewMinutes')
                $cmDeadline = (Get-Date).AddHours(1)
                while ((Get-Process -Name "cleanmgr" -ErrorAction SilentlyContinue) -and (Get-Date) -lt $cmDeadline) {
                    Start-Sleep -Seconds 10
                }
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.cleanmgrCompleted')
            }
        }

        # --- WinSxS ---
        @{ Name = "WinSxS Cleanup"; NameKey = 'cleanerRule.winsxsCleanup'; Type = "Command"; Command = "DISM.exe"; Args = @("/Online", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase") }
        @{ Name = "Minimize DISM"; NameKey = 'cleanerRule.minimizeDism'; Type = "RegSet"; Key = "HKLM:\Software\Microsoft\Windows\CurrentVersion\SideBySide\Configuration"; ValueName = "DisableResetbase"; ValueData = 0; ValueType = "DWORD" }

        # --- Error Reports ---
        @{ Name = "Error Reports"; NameKey = 'cleanerRule.errorReports'; Type = "File"; Paths = @(
                "$env:ProgramData\Microsoft\Windows\WER",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\WER"
            ); FilesOnly = $false
        }

        # --- Event Logs ---
        @{ Name = "Clear Event Logs"; NameKey = 'cleanerRule.clearEventLogs'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.cleaningEventLogsClassicModern')

                # Log classici (Application, System, Security, ecc.) via Clear-EventLog
                $classicLogs = Get-EventLog -List -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Log
                foreach ($logName in $classicLogs) {
                    try {
                        Clear-EventLog -LogName $logName -ErrorAction Stop
                        Write-ToolkitLog -Level DEBUG -Message (Get-Loc 'toolText.clearEventlog0' -Args @($logName))
                    }
                    catch {
                        Write-ToolkitLog -Level DEBUG -Message (Get-Loc 'toolText.clearEventlog01' -Args @($logName, $($_.Exception.Message)))
                    }
                }

                # Log moderni (Vista+) via wevtutil — copre tutto quello che Clear-EventLog non raggiunge
                $wevtErr = $null
                & wevtutil sl 'Microsoft-Windows-LiveId/Operational' /ca:'O:BAG:SYD:(A;;0x1;;;SY)(A;;0x5;;;BA)(A;;0x1;;;LA)' 2>&1 | Out-String -OutVariable wevtErr *>$null
                if ($wevtErr) { Write-ToolkitLog -Level DEBUG -Message (Get-Loc 'toolText.wevtutilSlOutput0' -Args @($wevtErr)) }
                Get-WinEvent -ListLog * -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    $logName = $_.LogName
                    # I log Analytical/Debug devono essere disabilitati prima di essere cancellati;
                    # wevtutil cl fails with "Access denied" while they are active.
                    if ($_.LogType -in 'Analytical', 'Debug') {
                        Wevtutil.exe sl $logName /e:false *>$null
                    }
                    $clErr = $null
                    Wevtutil.exe cl $logName 2>&1 | Out-String -OutVariable clErr *>$null
                    if ($LASTEXITCODE -ne 0 -and $clErr) { Write-ToolkitLog -Level DEBUG -Message (Get-Loc 'toolText.wevtutilCl01' -Args @($logName, $clErr)) }
                }

                Add-CleanerLog -Type 'Success' -Text (Get-Loc 'uiText.classicAndModernEventLogsDeleted')
            }
        }

        # --- Windows Update ---
        @{ Name = "Clear Windows Update cache"; NameKey = 'cleanerRule.clearWindowsUpdateCache'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.windowsUpdateCacheCleaner')

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
                            Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.removal02' -Args @($p))
                            Remove-Item -Path "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.unableToCleanCompletely0' -Args @($p))
                        }
                    }
                }

                foreach ($s in $services) {
                    Invoke-ServiceAction -Rule @{ ServiceName = $s; Action = "Start" }
                }

                Add-CleanerLog -Type 'Success' -Text (Get-Loc 'uiText.windowsUpdateCacheCleared')
            }
        }

        @{ Name = "Windows App/Download Cache - User"; NameKey = 'cleanerRule.windowsAppDownloadCacheUser'; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Microsoft\Windows\AppCache",
                "%LOCALAPPDATA%\Microsoft\Windows\Caches"
            ); PerUser = $true; FilesOnly = $true
        }

        # --- Restore Points ---
        @{ Name = "System Restore Points"; NameKey = 'cleanerRule.systemRestorePoints'; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.cleanSystemRestorePoints')

                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.analysisAndCleaningOfShadowCopiesKeepLatest')
                    try {
                        $shadows = Get-CimInstance -ClassName Win32_ShadowCopy -ErrorAction Stop | Sort-Object InstallDate -Descending
                        if ($shadows.Count -gt 1) {
                            $toDelete = $shadows | Select-Object -Skip 1
                            $count = $toDelete.Count
                            Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.0ShadowCopiesDetectedRemovingOld1' -Args @($($shadows.Count), $count))

                            foreach ($shadow in $toDelete) {
                                Remove-CimInstance -InputObject $shadow -ErrorAction SilentlyContinue
                            }
                            Add-CleanerLog -Type 'Success' -Text (Get-Loc 'toolText.extra2.oldShadowCopiesRemovedLastPreservedCopy')
                        }
                        elseif ($shadows.Count -eq 1) {
                            Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.onlyOneShadowCopyFoundNoRemovalNecessary')
                        }
                        else {
                            Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.noShadowCopyDetected')
                        }
                    }
                    catch {
                        Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.shadowCopyManagementError0' -Args @($_))
                    }

                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.systemProtectionKeptActiveForSafety')
                    Add-CleanerLog -Type 'Success' -Text (Get-Loc 'toolText.extra.restorePointCleanupCompleted')
                }
                catch {
                    Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.errorCleaningRestorePoints0' -Args @($($_.Exception.Message)))
                }
            }
        }

        # --- Prefetch ---
        @{ Name = "Cleanup - Windows Prefetch Cache"; NameKey = 'cleanerRule.cleanupWindowsPrefetchCache'; Type = "File"; Paths = @("C:\WINDOWS\Prefetch"); FilesOnly = $false }

        # --- Thumbnails ---
        @{ Name = "Cleanup - Explorer Thumbnail/Icon Cache"; NameKey = 'cleanerRule.cleanupExplorerThumbnailIconCache'; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\Explorer"); PerUser = $true; FilesOnly = $true; TakeOwnership = $true }

        # --- Browser & Web Cache ---
        @{ Name = "WinInet Cache - User"; NameKey = 'cleanerRule.wininetCacheUser'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.cleanupWininetWebcacheCache')

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
                catch { Write-ToolkitLog -Level DEBUG -Message (Get-Loc 'toolText.cachetaskDisableError0' -Args @($_)) }

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
                    catch { Write-ToolkitLog -Level DEBUG -Message (Get-Loc 'toolText.cachetaskEnableError0' -Args @($_)) }
                }

                Add-CleanerLog -Type 'Success' -Text (Get-Loc 'uiText.cleanWininetWebcache')
            }
        }
        @{ Name = "Temporary Internet Files"; NameKey = 'cleanerRule.temporaryInternetFiles'; Type = "File"; Paths = @(
                "%USERPROFILE%\Local Settings\Temporary Internet Files"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Cache/History Cleanup"; NameKey = 'cleanerRule.cacheHistoryCleanup'; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "8") }
        @{ Name = "Form Data Cleanup"; NameKey = 'cleanerRule.formDataCleanup'; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "2") }
        @{ Name = "Internet Cookies Cleanup"; NameKey = 'cleanerRule.internetCookiesCleanup'; Type = "File"; Paths = @(
                "%APPDATA%\Microsoft\Windows\Cookies",
                "%LOCALAPPDATA%\Microsoft\Windows\INetCookies"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Cookies Cleanup"; NameKey = 'cleanerRule.cookiesCleanup'; Type = "Command"; Command = "RunDll32.exe"; Args = @("InetCpl.cpl", "ClearMyTracksByProcess", "1") }
        @{ Name = "Chromium Browsers Cache (Chrome, Edge, Brave, Vivaldi)"; NameKey = 'cleanerRule.chromiumBrowsersCacheChromeEdgeBraveVivaldi'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.chromiumBrowserCacheCleaner')

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
        @{ Name = "Google Chrome AI OptGuide Model"; NameKey = 'cleanerRule.googleChromeAiOptguideModel'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.cleaningAndDisablingAiChromeOptguide')

                $users = Get-LocalUserProfiles
                foreach ($u in $users) {
                    $optGuidePath = Join-Path "$($u.FullName)\AppData\Local" "Google\Chrome\User Data\OptGuideOnDeviceModel"
                    if (Test-Path $optGuidePath) {
                        try {
                            Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.removingOptguideFolder0' -Args @($optGuidePath))
                            Remove-Item -Path $optGuidePath -Recurse -Force -ErrorAction Stop
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.removalError01' -Args @($optGuidePath, $_))
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
                        Add-CleanerLog -Type 'Success' -Text (Get-Loc 'toolText.extra.optguideFolderSetToReadOnly0' -Args @($optGuidePath))
                    }
                    catch {
                        Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.readOnlySettingErrorFor01' -Args @($optGuidePath, $_))
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
                        Add-CleanerLog -Type 'Success' -Text (Get-Loc 'uiText.chromePolicySet01' -Args @($($policy.Key), $($policy.Value)))
                    }
                }
                catch {
                    Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.chromeAiPolicySettingError0' -Args @($_))
                }
            }
        }
        @{ Name = "Firefox Browser Cache"; NameKey = 'cleanerRule.firefoxBrowserCache'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.cleaningFirefoxCacheCrashes')

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
        @{ Name = "Edge Legacy (HTML) Cache"; NameKey = 'cleanerRule.edgeLegacyHtmlCache'; Type = "File"; Paths = @(
                "%LOCALAPPDATA%\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC\*\MicrosoftEdge\Cache",
                "%LOCALAPPDATA%\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC\#!001\MicrosoftEdge\Cache"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Opera & Java Cache"; NameKey = 'cleanerRule.operaJavaCache'; Type = "File"; Paths = @(
                "%USERPROFILE%\Local Settings\Application Data\Opera\Opera",
                "%LOCALAPPDATA%\Opera\Opera",
                "%APPDATA%\Opera\Opera",
                "%APPDATA%\Sun\Java\Deployment\cache"
            ); PerUser = $true; FilesOnly = $false
        }

        @{ Name = "DNS Flush"; NameKey = 'cleanerRule.dnsFlush'; Type = "Command"; Command = "ipconfig"; Args = @("/flushdns") }

        # --- Temp Files ---
        @{ Name = "System Temp Files"; NameKey = 'cleanerRule.systemTempFiles'; Type = "File"; Paths = @("C:\WINDOWS\Temp"); FilesOnly = $false }
        @{ Name = "User Temp Files"; NameKey = 'cleanerRule.userTempFiles'; Type = "File"; Paths = @(
                "%USERPROFILE%\AppData\Local\Temp",
                "%USERPROFILE%\AppData\LocalLow\Temp"
            ); PerUser = $true; FilesOnly = $false
        }
        @{ Name = "Service Profiles Temp"; NameKey = 'cleanerRule.serviceProfilesTemp'; Type = "File"; Paths = @("%SYSTEMROOT%\ServiceProfiles\LocalService\AppData\Local\Temp"); FilesOnly = $false }

        # --- System & Component Logs ---
        @{ Name = "System & Component Logs"; NameKey = 'cleanerRule.systemComponentLogs'; Type = "File"; Paths = @(
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
        @{ Name = "User Registry History - Values Only"; NameKey = 'cleanerRule.userRegistryHistoryValuesOnly'; Type = "Registry"; Keys = @(
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
        @{ Name = "Adobe Media Browser Key"; NameKey = 'cleanerRule.adobeMediaBrowserKey'; Type = "Registry"; Keys = @("HKCU:\Software\Adobe\MediaBrowser\MRU"); ValuesOnly = $false }

        # --- Developer Telemetry ---
        @{ Name = "Developer Telemetry & Traces"; NameKey = 'cleanerRule.developerTelemetryTraces'; Type = "File"; Paths = @(
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
        @{ Name = "Visual Studio Licenses"; NameKey = 'cleanerRule.visualStudioLicenses'; Type = "Registry"; Keys = @(
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
        @{ Name = "Search History Files"; NameKey = 'cleanerRule.searchHistoryFiles'; Type = "File"; Paths = @("%LOCALAPPDATA%\Microsoft\Windows\ConnectedSearch\History"); PerUser = $true }

        # --- Print Queue (Spooler) ---
        @{ Name = "Print Queue (Spooler)"; NameKey = 'cleanerRule.printQueueSpooler'; Type = "ScriptBlock"; ScriptBlock = {
                try {
                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.printQueueCleaningSpooler')

                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.stoppingSpoolerService')
                    Stop-Service -Name Spooler -Force -ErrorAction Stop *>$null
                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.spoolerServiceStopped')
                    Start-Sleep -Seconds 2

                    $printersPath = 'C:\WINDOWS\System32\spool\PRINTERS'
                    if (Test-Path $printersPath) {
                        $files = Get-ChildItem -Path $printersPath -Force -ErrorAction SilentlyContinue
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.cleanPrintQueueIn01FilesRemoved' -Args @($printersPath, $($files.Count)))
                    }

                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.restartingSpoolerService')
                    Start-Service -Name Spooler -ErrorAction Stop *>$null
                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.spoolerServiceRestarted')

                    Add-CleanerLog -Type 'Success' -Text (Get-Loc 'toolText.extra2.printQueueSpoolerCleanedAndRestartedSuccessfully')
                }
                catch {
                    Start-Service -Name Spooler -ErrorAction SilentlyContinue
                    Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.errorCleaningSpooler0' -Args @($($_.Exception.Message)))
                }
            }
        }

        # --- SRUM & Defender ---
        @{ Name = "Stop DPS"; NameKey = 'cleanerRule.stopDps'; Type = "Service"; ServiceName = "DPS"; Action = "Stop" }
        @{ Name = "SRUM Data"; NameKey = 'cleanerRule.srumData'; Type = "File"; Paths = @("%SYSTEMROOT%\System32\sru\SRUDB.dat"); FilesOnly = $true; TakeOwnership = $true }
        @{ Name = "Start DPS"; NameKey = 'cleanerRule.startDps'; Type = "Service"; ServiceName = "DPS"; Action = "Start" }

        # --- Utility Apps ---
        @{ Name = "Listary Index"; NameKey = 'cleanerRule.listaryIndex'; Type = "File"; Paths = @("%APPDATA%\Listary\UserData"); PerUser = $true }
        @{ Name = "WinUtil Data"; NameKey = 'cleanerRule.winutilData'; Type = "File"; Paths = @("%LOCALAPPDATA%\winutil"); PerUser = $true }

        # --- Legacy Applications & Media ---
        @{ Name = "Flash Player Traces"; NameKey = 'cleanerRule.flashPlayerTraces'; Type = "File"; Paths = @("%APPDATA%\Macromedia\Flash Player"); PerUser = $true }

        # --- Enhanced DiagTrack Service Management ---
        @{ Name = "Enhanced DiagTrack Management"; NameKey = 'cleanerRule.enhancedDiagtrackManagement'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.improvedManagementOfDiagtrackService')

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
                        catch { Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.failedToCreateParentDirectory0' -Args @($_)); return $false }
                    }
                    try { New-Item -ItemType File -Path $Path -Force -ErrorAction Stop *>$null; return $true }
                    catch { Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.failedToCreateFile0' -Args @($_)); return $false }
                }

                $serviceName = 'DiagTrack'
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.checkServiceStatus0' -Args @($serviceName))

                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if (-not $service) {
                    Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.service0NotFoundSkip' -Args @($serviceName))
                    return
                }

                if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.service0ActiveStopping' -Args @($serviceName))
                    try {
                        $service | Stop-Service -Force -ErrorAction Stop
                        $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped, [TimeSpan]::FromSeconds(30))
                        $path = Get-UniqueStateFilePath $serviceName
                        if (New-EmptyFile $path) {
                            Add-CleanerLog -Type 'Success' -Text (Get-Loc 'toolText.extra.serviceStoppedAndStateSavedAutoRestartEnabled')
                        }
                        else {
                            Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.serviceStoppedManualRestartRequired')
                        }
                    }
                    catch { Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.errorStoppingService0' -Args @($_)) }
                }
                else {
                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.service0DownCheckRestart' -Args @($serviceName))
                    $fileGlob = Get-StateFilePath -BaseName $serviceName -Suffix '*'
                    $stateFiles = Get-ChildItem -Path $fileGlob -ErrorAction SilentlyContinue

                    if ($stateFiles.Count -eq 1) {
                        try {
                            Remove-Item -Path $stateFiles[0].FullName -Force -ErrorAction Stop
                            $service | Start-Service -ErrorAction Stop
                            Add-CleanerLog -Type 'Success' -Text (Get-Loc 'toolText.extra.service0RestartedSuccessfully' -Args @($serviceName))
                        }
                        catch { Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.errorRestartingService0' -Args @($_)) }
                    }
                    elseif ($stateFiles.Count -gt 1) {
                        Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.multipleStateFilesFoundServiceWillNotBeRestartedAutomatically')
                    }
                    else {
                        Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.service0WasNotActivePreviously' -Args @($serviceName))
                    }
                }
            }
        }

        # --- Special Operations ---
        @{ Name = "Credential Manager"; NameKey = 'cleanerRule.credentialManager'; Type = "Custom"; ScriptBlock = {
                Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.cleaningCredentials')

                $cmdkeyErr = $null
                $targets = & cmdkey /list 2>&1 | Tee-Object -Variable cmdkeyErr | Where-Object { $_ -match '^Target:' }
                if ($cmdkeyErr -and $LASTEXITCODE -ne 0) { Write-ToolkitLog -Level DEBUG -Message (Get-Loc 'toolText.cmdkeyListError0' -Args @($cmdkeyErr)) }

                $targets | ForEach-Object {
                    $t = $_.Split(':')[1].Trim()
                    $delErr = $null
                    & cmdkey /delete:$t 2>&1 | Tee-Object -Variable delErr *>$null
                    if ($delErr -and $LASTEXITCODE -ne 0) { Write-ToolkitLog -Level DEBUG -Message (Get-Loc 'toolText.cmdkeyDelete0Error1' -Args @($t, $delErr)) }
                }
            }
        }
        @{ Name = "Regedit Last Key"; NameKey = 'cleanerRule.regeditLastKey'; Type = "Registry"; Keys = @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Regedit"); ValuesOnly = $true }
        @{ Name = "Windows.old"; NameKey = 'cleanerRule.windowsOld'; Type = "ScriptBlock"; ScriptBlock = {
                $path = "C:\Windows.old"
                if (Test-Path $path) {
                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.windowsOldFolderDetectedStartingSafeRemovalWithNativeCleanmgr')

                    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations"
                    if (-not (Test-Path $regKey)) {
                        Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.registryKeyPreviousInstallationsNotFoundStandardExecutionAttempt')
                    }
                    else {
                        try {
                            Set-ItemProperty -Path $regKey -Name "StateFlags0066" -Value 2 -Type DWORD -Force -ErrorAction Stop
                            Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.cleanmgrConfigurationEnabledForWindowsOldStateflags0066')
                        }
                        catch {
                            Add-CleanerLog -Type 'Warning' -Text (Get-Loc 'toolText.extra.failedToWriteToRegistryForCleanmgr0' -Args @($_))
                        }
                    }

                    $cleanMgrRule = @{
                        Name    = 'Removing Windows.old (CleanMgr)';
                        Type    = "Command";
                        Command = "cleanmgr.exe";
                        Args    = @("/sagerun:66");
                    }

                    $null = Invoke-CommandAction -Rule $cleanMgrRule

                    if (Test-Path $path) {
                        Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.iTheWindowsOldFolderMayRequireARebootForCompleteRemoval')
                    }
                    else {
                        Add-CleanerLog -Type 'Success' -Text (Get-Loc 'toolText.extra2.windowsOldSuccessfullyRemoved')
                    }
                }
                else {
                    Add-CleanerLog -Type 'Info' -Text (Get-Loc 'toolText.extra.noWindowsOldFolderDetected')
                }
            }
        }
        @{ Name = "Empty Recycle Bin"; NameKey = 'cleanerRule.emptyRecycleBin'; Type = "Custom"; ScriptBlock = {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                Add-CleanerLog -Type 'Success' -Text (Get-Loc 'uiText.trashEmptied')
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

        Write-ProgressUpdate -Activity (Get-Loc 'toolText.ruleExecution') -Status (Get-Loc $rule.NameKey) -Percent $percent -Icon '⚙️'

        $result = Invoke-WinCleanerRule -Rule $rule

        Clear-ProgressLine

        if ($result) { $successCount++ }
        else { $errorCount++ }
    }

    Clear-ProgressLine

    Write-StyledMessage -Type 'Info' -Text "=================================================="
    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.summaryOfOperations')
    Write-StyledMessage -Type 'Info' -Text "=================================================="

    $stats = $script:WinCleanerLog | Group-Object Type
    $sCount = ($stats | Where-Object Name -eq 'Success').Count
    $wCount = ($stats | Where-Object Name -eq 'Warning').Count
    $eCount = ($stats | Where-Object Name -eq 'Error').Count

    Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.operationsCompletedSuccessfully0' -Args @($sCount))
    if ($wCount -gt 0) { Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.alertsGenerated0' -Args @($wCount)) }
    if ($eCount -gt 0) { Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorsEncountered0' -Args @($eCount)) }

    Write-StyledMessage -Type 'Info' -Text "--------------------------------------------------"
    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.detailsOfErrorsAndWarnings')

    $problems = $script:WinCleanerLog | Where-Object { $_.Type -in 'Warning', 'Error' }
    if ($problems) {
        foreach ($p in $problems) {
            Write-StyledMessage -Type $p.Type -Text $p.Text
        }
    }
    else {
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.noProblemsDetected')
    }

    Write-StyledMessage -Type 'Info' -Text "=================================================="

    Invoke-ToolkitReboot -Message (Get-Loc 'toolText.extra.systemRebootIn') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
}
