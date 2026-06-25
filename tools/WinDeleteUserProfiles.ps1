function WinDeleteUserProfiles {
    <#
    .SYNOPSIS
        Rimuove in modo sicuro i profili utente locali non caricati e le cartelle residue in C:\Users.

    .DESCRIPTION
        Esegue una pulizia controllata dei profili locali presenti in C:\Users utilizzando Win32_UserProfile.
        Esclude profili speciali, profili caricati, account di sistema, profilo utente corrente e nomi protetti.
        Dopo la cancellazione dei profili registrati, controlla la cartella utenti e rimuove eventuali directory residue
        non più associate a profili presenti nel registro/CIM, sempre rispettando le esclusioni protette.

        Lo script non chiede conferme interattive prima delle cancellazioni.

    .PARAMETER MaxThreads
        Numero massimo di runspace paralleli. Per Win32_UserProfile viene limitato automaticamente a 4.

    .PARAMETER CountdownSeconds
        Secondi del countdown prima di un eventuale riavvio consigliato.

    .PARAMETER SuppressIndividualReboot
        Sopprime il riavvio individuale e delega il riavvio finale al toolkit.

    .PARAMETER UsersRoot
        Percorso radice dei profili utente locali.

    .PARAMETER LogFolder
        Cartella in cui salvare il file di log.

    .PARAMETER MinimumProfileAgeDays
        Età minima, in giorni, dell'ultima data di utilizzo del profilo. Default 0 mantiene il comportamento originale.

    .PARAMETER SkipResidualFolderCleanup
        Salta la pulizia finale delle cartelle residue in C:\Users.

    .PARAMETER SuppressToolkitSession
        Non richiama Start-ToolkitSession anche se disponibile.

    .EXAMPLE
        WinDeleteUserProfiles

    .EXAMPLE
        WinDeleteUserProfiles -MinimumProfileAgeDays 30
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(1, 16)]
        [int]$MaxThreads = [Math]::Min(2, [Environment]::ProcessorCount),

        [ValidateRange(0, 3600)]
        [int]$CountdownSeconds = 30,

        [switch]$SuppressIndividualReboot,

        [ValidateNotNullOrEmpty()]
        [string]$UsersRoot = 'C:\Users',

        [ValidateNotNullOrEmpty()]
        [string]$LogFolder = 'C:\Temp',

        [ValidateRange(0, 3650)]
        [int]$MinimumProfileAgeDays = 0,

        [switch]$SkipResidualFolderCleanup,

        [switch]$SuppressToolkitSession
    )

    begin {
        $script:ToolName = 'WinDeleteUserProfiles'
        $script:ToolVersion = '3.1'
        $script:SessionStart = Get-Date
        $script:UsersRoot = [System.IO.Path]::GetFullPath($UsersRoot.TrimEnd('\') + '\')
        $script:LogFolder = [System.IO.Path]::GetFullPath($LogFolder)
        $script:LogFile = Join-Path $script:LogFolder ("{0}_{1}.log" -f $script:ToolName, (Get-Date -Format 'yyyyMMdd_HHmmss'))
        $script:CurrentUser = $env:USERNAME
        $script:ComputerName = $env:COMPUTERNAME
        $script:CountdownSeconds = $CountdownSeconds
        $script:SuppressIndividualReboot = $SuppressIndividualReboot
        $script:RebootRecommended = $false
        $script:MinimumLastUseDate = if ($MinimumProfileAgeDays -gt 0) { (Get-Date).AddDays(-$MinimumProfileAgeDays) } else { $null }

        $script:ProtectedProfileNames = @(
            'Public',
            'Pubblica',
            'Default',
            'Default User',
            'All Users',
            'defaultuser0',
            'WDAGUtilityAccount',
            'Administrator',
            'Guest',
            $script:CurrentUser
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        $savedErrorActionPreference = $ErrorActionPreference
        $savedProgressPreference = $ProgressPreference
        $savedConfirmPreference = $ConfirmPreference

        $ErrorActionPreference = 'Stop'
        $ProgressPreference = 'Continue'
        $ConfirmPreference = 'None'

        $script:LogQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    }

    process {
        if (-not (Get-Command -Name Write-StyledMessage -ErrorAction SilentlyContinue)) {
            function Write-StyledMessage {
                param(
                    [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Progress')]
                    [string]$Type = 'Info',

                    [Parameter(Mandatory = $true)]
                    [string]$Text
                )

                $color = switch ($Type) {
                    'Success' { 'Green' }
                    'Warning' { 'Yellow' }
                    'Error'   { 'Red' }
                    default   { 'Cyan' }
                }

                Write-Host $Text -ForegroundColor $color
            }
        }


        function Add-ProfileCleanupLog {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Text,

                [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
                [string]$Level = 'INFO'
            )

            $script:LogQueue.Enqueue(
                ('{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Text)
            )
        }


        function Set-ProfileCleanupRebootRecommended {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Reason
            )

            $script:RebootRecommended = $true
            Add-ProfileCleanupLog -Level 'WARNING' -Text "Riavvio consigliato: $Reason"
        }


        function Invoke-ProfileCleanupReboot {
            if (-not $script:RebootRecommended) {
                return
            }

            if (Get-Command -Name Invoke-ToolkitReboot -ErrorAction SilentlyContinue) {
                Invoke-ToolkitReboot -Message 'Riavvio consigliato dopo pulizia profili' -Seconds $script:CountdownSeconds -SuppressIndividualReboot:$script:SuppressIndividualReboot
                return
            }

            if ($script:SuppressIndividualReboot) {
                $Global:NeedsFinalReboot = $true
                Write-StyledMessage -Type 'Info' -Text '🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale.'
                return
            }

            if (Get-Command -Name Start-InterruptibleCountdown -ErrorAction SilentlyContinue) {
                if (Start-InterruptibleCountdown -Seconds $script:CountdownSeconds -Message 'Riavvio consigliato dopo pulizia profili') {
                    Restart-Computer -Force
                }
                return
            }

            Write-StyledMessage -Type 'Warning' -Text 'Riavvio consigliato per completare la pulizia dei profili non rimossi.'
        }


        function Test-IsAdministrator {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = [Security.Principal.WindowsPrincipal]::new($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }


        function Initialize-ProfileCleanupSession {
            [System.IO.Directory]::CreateDirectory($script:LogFolder) | Out-Null

            if (-not (Test-IsAdministrator)) {
                throw 'Lo script deve essere eseguito da una console PowerShell avviata come amministratore.'
            }

            if (-not (Test-Path -LiteralPath $script:UsersRoot -PathType Container)) {
                throw "Il percorso profili non esiste: $script:UsersRoot"
            }

            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($os -and $os.Caption -notmatch 'Windows 11') {
                Write-StyledMessage -Type 'Warning' -Text "⚠️ Sistema rilevato: $($os.Caption). Lo script è pensato per Windows 11."
            }

            if (-not $SuppressToolkitSession -and (Get-Command -Name Start-ToolkitSession -ErrorAction SilentlyContinue)) {
                Start-ToolkitSession -ToolName $script:ToolName -SubTitle 'Profile Cleanup Toolkit'
            }
            else {
                Write-Host ''
                Write-Host '====================================================' -ForegroundColor Cyan
                Write-Host (" {0} v{1}" -f $script:ToolName, $script:ToolVersion)
                Write-Host '====================================================' -ForegroundColor Cyan
                Write-Host ''
            }

            Write-StyledMessage -Type 'Info' -Text ("🖥️ Computer: {0}" -f $script:ComputerName)
            Write-StyledMessage -Type 'Info' -Text ("👤 Utente corrente protetto: {0}" -f $script:CurrentUser)
            Write-StyledMessage -Type 'Info' -Text ("📁 Percorso profili: {0}" -f $script:UsersRoot)
            Write-StyledMessage -Type 'Info' -Text ("🧵 Thread configurati: {0}" -f $MaxThreads)
            Write-StyledMessage -Type 'Warning' -Text '⚠️ Modalità non interattiva: nessuna conferma verrà richiesta prima delle cancellazioni.'

            if ($script:MinimumLastUseDate) {
                Write-StyledMessage -Type 'Info' -Text ("📅 Soglia ultima attività: profili non usati da almeno {0} giorni." -f $MinimumProfileAgeDays)
            }

            Add-ProfileCleanupLog -Text "Sessione avviata su $script:ComputerName."
        }


        function New-ProtectedNameSet {
            $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $script:ProtectedProfileNames | ForEach-Object { [void]$excluded.Add($_) }
            return ,$excluded
        }


        function Get-RegisteredProfilePathSet {
            $pathSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

            Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.LocalPath -and
                    $_.LocalPath.StartsWith($script:UsersRoot, [System.StringComparison]::OrdinalIgnoreCase)
                } |
                ForEach-Object {
                    try {
                        [void]$pathSet.Add([System.IO.Path]::GetFullPath($_.LocalPath).TrimEnd('\'))
                    }
                    catch {
                        Add-ProfileCleanupLog -Level 'WARNING' -Text "Impossibile normalizzare LocalPath profilo registrato: $($_.LocalPath)"
                    }
                }

            return ,$pathSet
        }


        function Get-RemovableUserProfiles {
            $excluded = New-ProtectedNameSet

            Write-StyledMessage -Type 'Info' -Text '🔍 Scansione profili locali registrati in corso.'

            $profiles = Get-CimInstance -ClassName Win32_UserProfile | Where-Object {
                -not $_.Special -and
                -not $_.Loaded -and
                $_.LocalPath -and
                $_.LocalPath.StartsWith($script:UsersRoot, [System.StringComparison]::OrdinalIgnoreCase)
            }

            foreach ($profile in $profiles) {
                $profileName = [System.IO.Path]::GetFileName($profile.LocalPath)

                if ($excluded.Contains($profileName)) {
                    Add-ProfileCleanupLog -Text "Profilo escluso: $profileName ($($profile.LocalPath))."
                    continue
                }

                if ($script:MinimumLastUseDate -and $profile.LastUseTime) {
                    $lastUse = $profile.LastUseTime
                    if ($lastUse -gt $script:MinimumLastUseDate) {
                        Add-ProfileCleanupLog -Text "Profilo escluso per soglia temporale: $profileName, ultimo uso $lastUse."
                        continue
                    }
                }

                $profile
            }
        }


        function Show-ProfileCleanupPreview {
            param(
                [Parameter(Mandatory = $true)]
                [array]$Profiles
            )

            Write-Host ''
            Write-StyledMessage -Type 'Warning' -Text 'Profili registrati selezionati per la rimozione automatica:'
            Write-Host ''

            $Profiles |
                Select-Object @{Name='User'; Expression={ [System.IO.Path]::GetFileName($_.LocalPath) }},
                              @{Name='Loaded'; Expression={ $_.Loaded }},
                              @{Name='LastUseTime'; Expression={ $_.LastUseTime }},
                              @{Name='Path'; Expression={ $_.LocalPath }} |
                Format-Table -AutoSize

            Write-Host ''
        }


        function Invoke-ProfileRemovalBatch {
            param(
                [Parameter(Mandatory = $true)]
                [array]$Profiles
            )

            $pool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
            $pool.Open()

            $jobs = [System.Collections.Generic.List[object]]::new()

            $scriptBlock = {
                param($Profile, $LogQueue)

                $ConfirmPreference = 'None'
                $ErrorActionPreference = 'Stop'

                $userPath = $Profile.LocalPath
                $userName = [System.IO.Path]::GetFileName($userPath)
                $start = Get-Date

                $LogQueue.Enqueue(('{0} [INFO] START PROFILE - {1} - {2}' -f $start.ToString('yyyy-MM-dd HH:mm:ss'), $userName, $userPath))

                try {
                    Remove-CimInstance -InputObject $Profile -ErrorAction Stop -Confirm:$false
                    $LogQueue.Enqueue(('{0} [SUCCESS] CIM profile removed - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                }
                catch {
                    $LogQueue.Enqueue(('{0} [WARNING] CIM remove failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))
                }

                if ([System.IO.Directory]::Exists($userPath)) {
                    try {
                        $tempEmpty = Join-Path $env:TEMP "EmptyFolder"

                        if (-not (Test-Path $tempEmpty)) {
                            New-Item -ItemType Directory -Path $tempEmpty | Out-Null
                        }
                        robocopy $tempEmpty $userPath /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
                        Remove-Item -LiteralPath $userPath -Force -Recurse -ErrorAction SilentlyContinue

                        $LogQueue.Enqueue(('{0} [SUCCESS] Folder removed - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                    }
                    catch {
                        $LogQueue.Enqueue(('{0} [WARNING] Standard folder cleanup failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))

                        try {
                            try {
                                & takeown.exe /F $userPath /R /D S | Out-Null
                            }
                            catch {
                                try {
                                    & takeown.exe /F $userPath /R /D Y | Out-Null
                                }
                                catch {
                                    $LogQueue.Enqueue(('{0} [ERROR] takeown failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))
                                }
                            }
                            & icacls.exe $userPath /grant Administrators:F /T /C | Out-Null
                            Remove-Item -LiteralPath $userPath -Force -Recurse -ErrorAction Stop -Confirm:$false
                            $LogQueue.Enqueue(('{0} [SUCCESS] Folder removed after ACL reset - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                        }
                        catch {
                            $LogQueue.Enqueue(('{0} [ERROR] Cleanup failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))
                        }
                    }
                }

                $success = -not [System.IO.Directory]::Exists($userPath)
                $duration = New-TimeSpan -Start $start -End (Get-Date)

                if ($success) {
                    $LogQueue.Enqueue(('{0} [SUCCESS] COMPLETED PROFILE - {1} - {2:hh\:mm\:ss}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $duration))
                }
                else {
                    $LogQueue.Enqueue(('{0} [ERROR] FAILED PROFILE - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                }

                return [PSCustomObject]@{
                    Type     = 'Profile'
                    UserName = $userName
                    Path     = $userPath
                    Success  = $success
                    Duration = $duration
                }
            }

            try {
                foreach ($profile in $Profiles) {
                    $ps = [PowerShell]::Create()
                    $ps.RunspacePool = $pool

                    [void]$ps.AddScript($scriptBlock, $true).
                        AddArgument($profile).
                        AddArgument($script:LogQueue)

                    $handle = $ps.BeginInvoke()

                    $jobs.Add([PSCustomObject]@{
                        PowerShell = $ps
                        Handle     = $handle
                    })
                }

                $total = $jobs.Count
                $lastPercent = -1

                do {
                    $completed = ($jobs | Where-Object { $_.Handle.IsCompleted }).Count
                    $percent = if ($total -gt 0) { [math]::Floor(($completed / $total) * 100) } else { 100 }

                    if ($percent -ne $lastPercent) {
                        $lastPercent = $percent
                        Write-Progress -Activity 'Rimozione profili registrati' -Status "$completed / $total completati" -PercentComplete $percent
                    }

                    Start-Sleep -Milliseconds 500
                } while ($completed -lt $total)

                Write-Progress -Activity 'Rimozione profili registrati' -Completed

                $results = foreach ($job in $jobs) {
                    try {
                        $job.PowerShell.EndInvoke($job.Handle)
                    }
                    catch {
                        Add-ProfileCleanupLog -Level 'ERROR' -Text "Errore runspace: $($_.Exception.Message)"
                    }
                    finally {
                        $job.PowerShell.Commands.Clear()
                        $job.PowerShell.Dispose()
                    }
                }

                return $results
            }
            finally {
                if ($pool) {
                    $pool.Close()
                    $pool.Dispose()
                }
            }
        }


        function Get-ResidualUserFolders {
            $excluded = New-ProtectedNameSet
            $registeredProfilePaths = Get-RegisteredProfilePathSet

            Write-StyledMessage -Type 'Info' -Text '🔎 Controllo cartelle residue nella directory utenti.'

            $folders = Get-ChildItem -Path $UsersRoot -Directory -Force |
                Where-Object {
                    -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
                }

            foreach ($folder in $folders) {
                $folderName = $folder.Name
                $folderPath = [System.IO.Path]::GetFullPath($folder.FullName).TrimEnd('\')

                if ($excluded.Contains($folderName)) {
                    Add-ProfileCleanupLog -Text "Cartella residua esclusa per nome protetto: $folderName ($folderPath)."
                    continue
                }

                if ($registeredProfilePaths.Contains($folderPath)) {
                    Add-ProfileCleanupLog -Text "Cartella residua esclusa perché ancora associata a Win32_UserProfile: $folderName ($folderPath)."
                    continue
                }

                if ($folder.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                    Add-ProfileCleanupLog -Level 'WARNING' -Text "Cartella residua esclusa perché reparse point/symlink: $folderName ($folderPath)."
                    continue
                }

                [PSCustomObject]@{
                    Name = $folderName
                    Path = $folderPath
                }
            }
        }


        function Remove-ResidualUserFolders {
            param(
                [Parameter(Mandatory = $true)]
                [array]$Folders
            )

            $results = [System.Collections.Generic.List[object]]::new()
            $total = $Folders.Count
            $index = 0

            foreach ($folder in $Folders) {
                $index++
                $percent = if ($total -gt 0) { [math]::Floor(($index / $total) * 100) } else { 100 }

                Write-Progress `
                    -Activity 'Rimozione cartelle residue in C:\Users' `
                    -Status ("{0} / {1} - {2}" -f $index, $total, $folder.Name) `
                    -PercentComplete $percent

                $start = Get-Date
                $success = $false

                Add-ProfileCleanupLog -Text "START RESIDUAL FOLDER - $($folder.Name) - $($folder.Path)"

                $folderPath = $folder.Path

                try {
                    Remove-Item -LiteralPath $folderPath -Force -Recurse -ErrorAction Stop -Confirm:$false
                    $success = -not [System.IO.Directory]::Exists($folderPath)
                }
                catch {
                    Add-ProfileCleanupLog -Level 'WARNING' -Text "Rimozione standard cartella residua fallita: $folderPath - $($_.Exception.Message)"

                    try {
                        & takeown.exe /F $folderPath /R /D Y | Out-Null
                        & icacls.exe $folderPath /grant Administrators:F /T /C | Out-Null
                        Remove-Item -LiteralPath $folderPath -Force -Recurse -ErrorAction Stop -Confirm:$false
                        $success = -not [System.IO.Directory]::Exists($folderPath)
                    }
                    catch {
                        Add-ProfileCleanupLog -Level 'ERROR' -Text "Rimozione cartella residua fallita: $folderPath - $($_.Exception.Message)"
                        $success = $false
                    }
                }

                $duration = New-TimeSpan -Start $start -End (Get-Date)

                if ($success) {
                    Add-ProfileCleanupLog -Level 'SUCCESS' -Text "COMPLETED RESIDUAL FOLDER - $($folder.Name) - $($duration.ToString())"
                }
                else {
                    Add-ProfileCleanupLog -Level 'ERROR' -Text "FAILED RESIDUAL FOLDER - $($folder.Name)"
                }

                $results.Add([PSCustomObject]@{
                    Type     = 'ResidualFolder'
                    UserName = $folder.Name
                    Path     = $folder.Path
                    Success  = $success
                    Duration = $duration
                }) | Out-Null
            }

            Write-Progress -Activity 'Rimozione cartelle residue in C:\Users' -Completed

            return $results
        }


        function Save-ProfileCleanupLog {
            $logLines = [System.Collections.Generic.List[string]]::new()
            $line = $null

            while ($script:LogQueue.TryDequeue([ref]$line)) {
                $logLines.Add($line)
            }

            $logLines | Set-Content -LiteralPath $script:LogFile -Encoding UTF8
        }

        try {
            Initialize-ProfileCleanupSession

            $profileResults = @()
            $residualResults = @()

            $targets = @(Get-RemovableUserProfiles)

            if ($targets -and $targets.Count -gt 0) {
                Show-ProfileCleanupPreview -Profiles $targets

                Write-Host ''
                Write-StyledMessage -Type 'Info' -Text ("🚀 Avvio rimozione automatica di {0} profili registrati." -f $targets.Count)
                Write-Host ''

                $profileResults = @(Invoke-ProfileRemovalBatch -Profiles $targets)
            }
            else {
                Write-Host ''
                Write-StyledMessage -Type 'Success' -Text '✅ Nessun profilo registrato rimovibile trovato.'
                Add-ProfileCleanupLog -Level 'SUCCESS' -Text 'Nessun profilo registrato rimovibile trovato.'
            }

            if (-not $SkipResidualFolderCleanup) {
                $residualFolders = @(Get-ResidualUserFolders)

                if ($residualFolders -and $residualFolders.Count -gt 0) {
                    Write-Host ''
                    Write-StyledMessage -Type 'Warning' -Text ("Cartelle residue selezionate per la rimozione automatica: {0}" -f $residualFolders.Count)
                    $residualFolders | Select-Object Name, Path | Format-Table -AutoSize

                    Write-Host ''
                    Write-StyledMessage -Type 'Info' -Text '🧹 Avvio rimozione cartelle residue.'
                    Write-Host ''

                    $residualResults = @(Remove-ResidualUserFolders -Folders $residualFolders)
                }
                else {
                    Write-StyledMessage -Type 'Success' -Text '✅ Nessuna cartella residua rimovibile trovata in C:\Users.'
                    Add-ProfileCleanupLog -Level 'SUCCESS' -Text 'Nessuna cartella residua rimovibile trovata.'
                }
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text 'Pulizia cartelle residue saltata per parametro SkipResidualFolderCleanup.'
                Add-ProfileCleanupLog -Level 'WARNING' -Text 'Pulizia cartelle residue saltata.'
            }

            $allResults = @($profileResults) + @($residualResults)
            $successCount = @($allResults | Where-Object { $_.Success }).Count
            $failedCount = @($allResults | Where-Object { -not $_.Success }).Count
            $profileSuccessCount = @($profileResults | Where-Object { $_.Success }).Count
            $residualSuccessCount = @($residualResults | Where-Object { $_.Success }).Count

            if ($failedCount -gt 0) {
                Set-ProfileCleanupRebootRecommended -Reason "$failedCount elementi non rimossi potrebbero essere bloccati da sessioni o handle aperti."
            }

            $script:SessionEnd = Get-Date
            $totalDuration = New-TimeSpan -Start $script:SessionStart -End $script:SessionEnd

            Add-ProfileCleanupLog -Level 'INFO' -Text "Sessione completata. Profili rimossi: $profileSuccessCount. Cartelle residue rimosse: $residualSuccessCount. Errori: $failedCount. Durata: $totalDuration."
            Save-ProfileCleanupLog

            Write-Host ''
            Write-Host '====================================================' -ForegroundColor Green
            Write-Host ' COMPLETED'
            Write-Host '====================================================' -ForegroundColor Green
            Write-Host ''
            Write-StyledMessage -Type 'Success' -Text ("✅ Profili registrati rimossi: {0}" -f $profileSuccessCount)
            Write-StyledMessage -Type 'Success' -Text ("✅ Cartelle residue rimosse: {0}" -f $residualSuccessCount)
            if ($failedCount -gt 0) {
                Write-StyledMessage -Type 'Warning' -Text ("⚠️ Elementi non rimossi: {0}" -f $failedCount)
            }
            Write-StyledMessage -Type 'Info' -Text ("⏱️ Durata: {0:hh\:mm\:ss}" -f $totalDuration)
            Write-StyledMessage -Type 'Info' -Text ("📄 Log: {0}" -f $script:LogFile)

            Invoke-ProfileCleanupReboot
        }
        catch {
            Add-ProfileCleanupLog -Level 'ERROR' -Text $_.Exception.Message
            try { Save-ProfileCleanupLog } catch { }
            Write-StyledMessage -Type 'Error' -Text ("❌ Errore: {0}" -f $_.Exception.Message)
            throw
        }
        finally {
            $ErrorActionPreference = $savedErrorActionPreference
            $ProgressPreference = $savedProgressPreference
            $ConfirmPreference = $savedConfirmPreference
        }
    }
}
