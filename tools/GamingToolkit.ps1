function GamingToolkit {
    <#
    .SYNOPSIS
        Gaming Toolkit - Windows gaming optimization tools.

    .DESCRIPTION
        Optimizes system performance for gaming.
        Includes runtime and game client installation plus system configuration.

    .PARAMETER CountdownSeconds
        Number of seconds in the countdown before restarting.

    .OUTPUTS
        None. The function does not return output.
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateRange(0, 300)]
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "GamingToolkit" -SubTitle (Get-Loc 'script.GamingToolkit')

    $timeout = 3600

    function Test-WingetPackageAvailable([string]$PackageId) {
        try {
            $searchResult = winget search --id $PackageId --accept-source-agreements 2>&1
            $outputStr = $searchResult -join ' '
            if ($outputStr -match [regex]::Escape($PackageId)) {
                return $true
            }
            $listResult = winget list --id $PackageId --accept-source-agreements 2>&1
            $listStr = $listResult -join ' '
            if ($listStr -match [regex]::Escape($PackageId)) {
                return $true
            }
            return $false
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.packetVerificationError01' -Args @($PackageId, $errorMessage))
            return $false
        }
    }

    function Invoke-WingetInstallWithProgress([string]$PackageId, [string]$DisplayName, [int]$Step, [int]$Total) {
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.01Installation2' -Args @($Step, $Total, $DisplayName))

        $outFile = "$env:TEMP\winget_$PackageId.log"
        $errFile = "$env:TEMP\winget_err_$PackageId.log"

        try {
            $result = Invoke-WithSpinner -Activity (Get-Loc 'toolText.extra.installation0' -Args @($DisplayName)) -Command 'winget' -Arguments @('install', '--id', $PackageId, '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements') -TimeoutSeconds $timeout -LogContextKey "Gaming-Install-$PackageId"

            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)

            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.installed0' -Args @($DisplayName))
                return @{ Success = $true; ExitCode = $exitCode }
            }
            else {
                Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.installationError0Code1' -Args @($DisplayName, $exitCode))
                return @{ Success = $false; ExitCode = $exitCode }
            }
        }
        catch {
            Clear-ProgressLine
            Clear-ProgressLine
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.exception01' -Args @($DisplayName, $($_.Exception.Message)))
            return @{ Success = $false }
        }
        finally {
            Remove-ItemSafely -Path $outFile
            Remove-ItemSafely -Path $errFile
        }
    }

    # Countdown preparazione
    Invoke-WithSpinner -Activity (Get-Loc 'uiText.preparation') -Timer -Action { Start-Sleep 5 } -TimeoutSeconds 5

    Show-Header -SubTitle (Get-Loc 'script.GamingToolkit')

    # Step 1: Verifica e ripristino automatico Winget
    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.checkWingetAvailability')
    Update-EnvironmentPath
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.wingetNotAvailableStartingAutomaticRecovery')
        $resetOk = Reset-Winget
        Update-EnvironmentPath
        if (-not $resetOk -or -not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.wingetRestoreFailedUnableToProceedWithGamingToolkit')
            Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.pressAnyKeyToContinue')
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
    }
    Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.wingetAvailable')

    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.wingetSourcesUpdate')
    try {
        winget source update *>$null
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.updatedSources')
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.sourceUpdateError0' -Args @($($_.Exception.Message)))
    }

    # Step 2: NetFramework
    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.enablingNetframework')
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs, NetFx3 -NoRestart -All -ErrorAction Stop *>$null
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.netframeworkEnabled')
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorEnablingNetframework0' -Args @($($_.Exception.Message)))
    }

    # Step 3: Runtime e VCRedist
    $runtimes = @(
        "Microsoft.DotNet.DesktopRuntime.3_1",
        "Microsoft.DotNet.DesktopRuntime.5",
        "Microsoft.DotNet.DesktopRuntime.6",
        "Microsoft.DotNet.DesktopRuntime.7",
        "Microsoft.DotNet.DesktopRuntime.8",
        "Microsoft.DotNet.DesktopRuntime.9",
        "Microsoft.DotNet.DesktopRuntime.10",
        "Microsoft.VCRedist.2010.x64",
        "Microsoft.VCRedist.2010.x86",
        "Microsoft.VCRedist.2012.x64",
        "Microsoft.VCRedist.2012.x86",
        "Microsoft.VCRedist.2013.x64",
        "Microsoft.VCRedist.2013.x86",
        "Microsoft.VCLibs.Desktop.14",
        "Microsoft.VCRedist.2015+.x64",
        "Microsoft.VCRedist.2015+.x86"
    )

    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.installingNetRuntimeAndVcredist')
    for ($runtimeIndex = 0; $runtimeIndex -lt $runtimes.Count; $runtimeIndex++) {
        Invoke-WingetInstallWithProgress $runtimes[$runtimeIndex] $runtimes[$runtimeIndex] ($runtimeIndex + 1) $runtimes.Count *>$null
    }
    Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.runtimesCompleted')

    # Step 4: DirectX
    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.directxInstallation')
    $dxDir = Join-Path $AppConfig.Paths.LocalAppData "WinToolkit\Directx"
    $dxPath = "$dxDir\dxwebsetup.exe"

    if (-not (Test-Path $dxDir)) { New-Item -Path $dxDir -ItemType Directory -Force *>$null }

    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.DirectXWebSetup -OutFile $dxPath -ErrorAction Stop
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.directxDownloaded')

        $result = Invoke-WithSpinner -Activity (Get-Loc 'toolText.extra.directxInstallation') -Command $dxPath -TimeoutSeconds $timeout -LogContextKey "Gaming-DirectX"

        Clear-ProgressLine
        Clear-ProgressLine

        if ($null -eq $result) {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.directxProcessDidNotStartCorrectly')
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.directxTimeout')
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 3010, 5100, -9, 9, -1442840576)
            $messageType = if ($exitCode -in $successCodes) { 'Success' } else { 'Error' }
            $messageText = if ($exitCode -in $successCodes) {
                Get-Loc 'toolText.extra.directxInstalledCode0' -Args @($exitCode)
            }
            else {
                Get-Loc 'toolText.extra.directxError0' -Args @($exitCode)
            }
            Write-StyledMessage -Type $messageType -Text $messageText
        }
    }
    catch {
        Clear-ProgressLine
        Clear-ProgressLine
        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorDuringDirectxInstallation0' -Args @($($_.Exception.Message)))
    }

    # Step 5: Client di gioco
    $gameClients = @(
        "Amazon.Games", "GOG.Galaxy", "EpicGames.EpicGamesLauncher",
        "ElectronicArts.EADesktop", "Playnite.Playnite", "Valve.Steam",
        "Ubisoft.Connect"
    )

    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.gameClientInstallation')
    for ($clientIndex = 0; $clientIndex -lt $gameClients.Count; $clientIndex++) {
        Invoke-WingetInstallWithProgress $gameClients[$clientIndex] $gameClients[$clientIndex] ($clientIndex + 1) $gameClients.Count *>$null
    }
    Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.clientsInstalled')

    # Step 5b: Xbox Game Bar & Xbox App
    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.reinstallingXboxGameBarApp')

    $xboxPackages = @("9NZKPSTSNW4P", "9MV0B5HZVK9Z")

    foreach ($pkg in $xboxPackages) {
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.reinstallation0' -Args @($pkg))

        $outFile = "$env:TEMP\winget_$pkg.log"
        $errFile = "$env:TEMP\winget_err_$pkg.log"

        try {
            $result = Invoke-WithSpinner -Activity (Get-Loc 'uiText.reinstallation0' -Args @($pkg)) -Process -Action {
                $procParams = @{
                    FilePath               = 'winget'
                    ArgumentList           = @('install', '--id', $pkg, '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements', '--force')
                    PassThru               = $true
                    NoNewWindow            = $true
                    RedirectStandardOutput = $outFile
                    RedirectStandardError  = $errFile
                }
                Start-Process @procParams
            } -TimeoutSeconds $timeout -UpdateInterval 700

            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)

            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.reinstalled0' -Args @($pkg))
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.0Code1' -Args @(${pkg}, $exitCode))
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.error01' -Args @($pkg, $($_.Exception.Message)))
        }
        finally {
            Remove-ItemSafely -Path $outFile
            Remove-ItemSafely -Path $errFile
        }
    }
    Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.xboxReinstalled')

    # Step 6: Battle.net
    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.installingBattleNet')
    $bnPath = "$env:TEMP\Battle.net-Setup.exe"

    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.BattleNetInstaller -OutFile $bnPath -ErrorAction Stop
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.battleNetDownloaded')

        $result = Invoke-WithSpinner -Activity (Get-Loc 'toolText.extra.installingBattleNet') -Command $bnPath -Arguments '--quiet' -TimeoutSeconds $timeout -LogContextKey "Gaming-BattleNet"

        Clear-ProgressLine
        Clear-ProgressLine

        if ($null -eq $result) {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.battleNetProcessDidNotStartProperly')
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage -Type 'Warning' -Text (Get-Loc 'toolText.battleNetTimedOut')
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $messageType = if ($exitCode -in @(0, 3010)) { 'Success' } else { 'Warning' }
            $messageText = if ($exitCode -in @(0, 3010)) {
                Get-Loc 'uiText.battleNetInstalled'
            }
            else {
                Get-Loc 'toolText.extra.battleNetCode0' -Args @($exitCode)
            }
            Write-StyledMessage -Type $messageType -Text $messageText
        }

        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.pressAnyKeyToContinue')
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    catch {
        Clear-ProgressLine
        Clear-ProgressLine
        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorInstallingBattleNet0' -Args @($($_.Exception.Message)))
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.pressAnyKeyToContinue')
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }

    # Step 7: Pulizia avvio automatico
    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.autostartCleaner')
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    @('Steam', 'Battle.net', 'GOG Galaxy', 'GogGalaxy', 'GalaxyClient') | ForEach-Object {
        if (Get-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.removed0' -Args @($_))
        }
    }

    $startupPath = $AppConfig.Paths.Startup
    @('Steam.lnk', 'Battle.net.lnk', 'GOG Galaxy.lnk') | ForEach-Object {
        $path = Join-Path $startupPath $_
        Remove-ItemSafely -Path $path
        if (-not (Test-Path $path)) {
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.removed0' -Args @($_))
        }
    }
    Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.cleaningCompleted')

    # Step 8: Profilo energetico
    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.energyProfileConfiguration')
    $ultimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $planName = "WinToolkit Gaming Performance"
    $guid = $null

    $existingPlan = powercfg -list | Select-String -Pattern $planName -ErrorAction SilentlyContinue
    if ($existingPlan) {
        $guid = ($existingPlan.Line -split '\s+')[3]
        Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.existingPlanFound')
    }
    else {
        try {
            $output = powercfg /duplicatescheme $ultimateGUID | Out-String
            if ($output -match "\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b") {
                $guid = $matches[0]
                powercfg /changename $guid $planName 'Optimized for Gaming by WinToolkit' *>$null
                Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.planCreated')
            }
            else {
                Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.planCreationError')
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorDuringEnergyPlanDuplication0' -Args @($($_.Exception.Message)))
        }
    }

    if ($guid) {
        try {
            powercfg -setactive $guid *>$null
            Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.planActivated')
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorDuringEnergyPlanActivation0' -Args @($($_.Exception.Message)))
        }
    }
    else {
        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.unableToActivatePlan')
    }

    # Step 9: Focus Assist
    Write-StyledMessage -Type 'Info' -Text (Get-Loc 'toolText.doNotDisturbActivation')
    try {
        Set-ItemProperty -Path $AppConfig.Registry.FocusAssist -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0 -Force
        Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.doNotDisturbActive')
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-Loc 'toolText.errorDuringFocusAssistConfiguration0' -Args @($($_.Exception.Message)))
    }

    # Step 10: Completamento
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)
    Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.gamingToolkitCompleted')
    Write-StyledMessage -Type 'Success' -Text (Get-Loc 'toolText.systemOptimizedForGaming')
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)

    Invoke-ToolkitReboot -Message (Get-Loc 'toolText.extra.rebootRequired') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
}
