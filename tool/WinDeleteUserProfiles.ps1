#requires -version 5.1
#requires -RunAsAdministrator

function DeleteUserProfilesInWindows11 {
    <#
    .SYNOPSIS
        Rimuove in modo sicuro i profili utente locali non caricati da Windows 11.

    .DESCRIPTION
        Esegue una pulizia controllata dei profili locali presenti in C:\Users utilizzando Win32_UserProfile.
        Esclude profili speciali, profili caricati, account di sistema, profilo utente corrente e nomi protetti.
        La rimozione usa prima Remove-CimInstance, poi una pulizia filesystem di fallback solo se la cartella rimane presente.

    .PARAMETER MaxThreads
        Numero massimo di runspace paralleli. Per Win32_UserProfile viene limitato automaticamente a 4.

    .PARAMETER UsersRoot
        Percorso radice dei profili utente locali.

    .PARAMETER LogFolder
        Cartella in cui salvare il file di log.

    .PARAMETER MinimumProfileAgeDays
        Età minima, in giorni, dell'ultima data di utilizzo del profilo. Default 0 mantiene il comportamento originale.

    .PARAMETER Force
        Salta la richiesta di conferma interattiva.

    .PARAMETER SuppressToolkitSession
        Non richiama Start-ToolkitSession anche se disponibile.

    .EXAMPLE
        DeleteUserProfilesInWindows11

    .EXAMPLE
        DeleteUserProfilesInWindows11 -MinimumProfileAgeDays 30 -Force
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [ValidateRange(1, 16)]
        [int]$MaxThreads = [Math]::Min(4, [Environment]::ProcessorCount),

        [ValidateNotNullOrEmpty()]
        [string]$UsersRoot = 'C:\Users',

        [ValidateNotNullOrEmpty()]
        [string]$LogFolder = 'C:\Temp',

        [ValidateRange(0, 3650)]
        [int]$MinimumProfileAgeDays = 0,

        [switch]$Force,

        [switch]$SuppressToolkitSession
    )

    begin {
        $script:ToolName = 'DeleteUserProfilesInWindows11'
        $script:ToolVersion = '3.0'
        $script:SessionStart = Get-Date
        $script:UsersRoot = [System.IO.Path]::GetFullPath($UsersRoot.TrimEnd('\') + '\')
        $script:LogFolder = [System.IO.Path]::GetFullPath($LogFolder)
        $script:LogFile = Join-Path $script:LogFolder ("{0}_{1}.log" -f $script:ToolName, (Get-Date -Format 'yyyyMMdd_HHmmss'))
        $script:CurrentUser = $env:USERNAME
        $script:ComputerName = $env:COMPUTERNAME
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
        $ErrorActionPreference = 'Stop'
        $ProgressPreference = 'Continue'

        $script:LogQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    }

    process {
        function Write-ToolkitMessage {
            param(
                [ValidateSet('Info', 'Success', 'Warning', 'Error')]
                [string]$Type = 'Info',

                [Parameter(Mandatory = $true)]
                [string]$Text
            )

            if (Get-Command -Name Write-StyledMessage -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type $Type -Text $Text
                return
            }

            $color = switch ($Type) {
                'Success' { 'Green' }
                'Warning' { 'Yellow' }
                'Error'   { 'Red' }
                default   { 'Cyan' }
            }

            Write-Host $Text -ForegroundColor $color
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
                Write-ToolkitMessage -Type 'Warning' -Text "⚠️ Sistema rilevato: $($os.Caption). Lo script è pensato per Windows 11."
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

            Write-ToolkitMessage -Type 'Info' -Text ("🖥️ Computer: {0}" -f $script:ComputerName)
            Write-ToolkitMessage -Type 'Info' -Text ("👤 Utente corrente protetto: {0}" -f $script:CurrentUser)
            Write-ToolkitMessage -Type 'Info' -Text ("📁 Percorso profili: {0}" -f $script:UsersRoot)
            Write-ToolkitMessage -Type 'Info' -Text ("🧵 Thread configurati: {0}" -f $MaxThreads)
            if ($script:MinimumLastUseDate) {
                Write-ToolkitMessage -Type 'Info' -Text ("📅 Soglia ultima attività: profili non usati da almeno {0} giorni." -f $MinimumProfileAgeDays)
            }

            Add-ProfileCleanupLog -Text "Sessione avviata su $script:ComputerName."
        }

        function Get-RemovableUserProfiles {
            $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $script:ProtectedProfileNames | ForEach-Object { [void]$excluded.Add($_) }

            Write-ToolkitMessage -Type 'Info' -Text '🔍 Scansione profili locali in corso.'

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
            Write-ToolkitMessage -Type 'Warning' -Text 'Profili selezionati per la rimozione:'
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

                $userPath = $Profile.LocalPath
                $userName = [System.IO.Path]::GetFileName($userPath)
                $start = Get-Date

                $LogQueue.Enqueue(('{0} [INFO] START - {1} - {2}' -f $start.ToString('yyyy-MM-dd HH:mm:ss'), $userName, $userPath))

                try {
                    Remove-CimInstance -InputObject $Profile -ErrorAction Stop
                    $LogQueue.Enqueue(('{0} [SUCCESS] CIM profile removed - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                }
                catch {
                    $LogQueue.Enqueue(('{0} [WARNING] CIM remove failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))
                }

                if ([System.IO.Directory]::Exists($userPath)) {
                    try {
                        Remove-Item -LiteralPath $userPath -Force -Recurse -ErrorAction Stop
                        $LogQueue.Enqueue(('{0} [SUCCESS] Folder removed - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                    }
                    catch {
                        $LogQueue.Enqueue(('{0} [WARNING] Standard folder cleanup failed - {1} - {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $_.Exception.Message))

                        try {
                            & takeown.exe /F $userPath /R /D Y | Out-Null
                            & icacls.exe $userPath /grant Administrators:F /T /C | Out-Null
                            Remove-Item -LiteralPath $userPath -Force -Recurse -ErrorAction Stop
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
                    $LogQueue.Enqueue(('{0} [SUCCESS] COMPLETED - {1} - {2:hh\:mm\:ss}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName, $duration))
                }
                else {
                    $LogQueue.Enqueue(('{0} [ERROR] FAILED - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $userName))
                }

                return [PSCustomObject]@{
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
                        Write-Progress -Activity 'Rimozione profili utente' -Status "$completed / $total completati" -PercentComplete $percent
                    }

                    Start-Sleep -Milliseconds 500
                } while ($completed -lt $total)

                Write-Progress -Activity 'Rimozione profili utente' -Completed

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

            $targets = @(Get-RemovableUserProfiles)

            if (-not $targets -or $targets.Count -eq 0) {
                Write-Host ''
                Write-ToolkitMessage -Type 'Success' -Text '✅ Nessun profilo rimovibile trovato.'
                Add-ProfileCleanupLog -Level 'SUCCESS' -Text 'Nessun profilo rimovibile trovato.'
                return
            }

            Show-ProfileCleanupPreview -Profiles $targets

            $shouldContinue = $Force -or $PSCmdlet.ShouldContinue(
                ("Saranno rimossi {0} profili locali. Continuare?" -f $targets.Count),
                'Conferma rimozione profili'
            )

            if (-not $shouldContinue) {
                Write-ToolkitMessage -Type 'Warning' -Text 'Operazione annullata dall’utente.'
                Add-ProfileCleanupLog -Level 'WARNING' -Text 'Operazione annullata dall’utente.'
                return
            }

            Write-Host ''
            Write-ToolkitMessage -Type 'Info' -Text '🚀 Avvio rimozione profili.'
            Write-Host ''

            $results = if ($PSCmdlet.ShouldProcess($script:ComputerName, "Rimozione di $($targets.Count) profili utente locali")) {
                @(Invoke-ProfileRemovalBatch -Profiles $targets)
            }
            else {
                @()
            }

            $successCount = @($results | Where-Object { $_.Success }).Count
            $failedCount = @($results | Where-Object { -not $_.Success }).Count
            $script:SessionEnd = Get-Date
            $totalDuration = New-TimeSpan -Start $script:SessionStart -End $script:SessionEnd

            Add-ProfileCleanupLog -Level 'INFO' -Text "Sessione completata. Successi: $successCount. Errori: $failedCount. Durata: $totalDuration."
            Save-ProfileCleanupLog

            Write-Host ''
            Write-Host '====================================================' -ForegroundColor Green
            Write-Host ' COMPLETATO'
            Write-Host '====================================================' -ForegroundColor Green
            Write-Host ''
            Write-ToolkitMessage -Type 'Success' -Text ("✅ Profili rimossi: {0}" -f $successCount)
            if ($failedCount -gt 0) {
                Write-ToolkitMessage -Type 'Warning' -Text ("⚠️ Profili non rimossi: {0}" -f $failedCount)
            }
            Write-ToolkitMessage -Type 'Info' -Text ("⏱️ Durata: {0:hh\:mm\:ss}" -f $totalDuration)
            Write-ToolkitMessage -Type 'Info' -Text ("📄 Log: {0}" -f $script:LogFile)
        }
        catch {
            Add-ProfileCleanupLog -Level 'ERROR' -Text $_.Exception.Message
            try { Save-ProfileCleanupLog } catch { }
            Write-ToolkitMessage -Type 'Error' -Text ("❌ Errore: {0}" -f $_.Exception.Message)
            throw
        }
        finally {
            $ErrorActionPreference = $savedErrorActionPreference
            $ProgressPreference = $savedProgressPreference
        }
    }
}

DeleteUserProfilesInWindows11 @args
