

# ==============================================================================
# SEZIONE 9 · INTERAZIONE UTENTE
# Input validato, conferme e selezioni di menu.
# ==============================================================================

function Get-UserConfirmation {
    <#
    .SYNOPSIS
        Requests user confirmation (Yes/No) in a standardized way.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [switch]$DefaultYes,
        [ValidateSet('Info', 'Warning', 'Question')][string]$Level = 'Question'
    )

    $choices = if ($DefaultYes) { "[S/n]" } else { "[s/N]" }
    $fullPrompt = "$Prompt $choices"

    if ($Global:GuiSessionActive) {
        Write-StyledMessage -Type $Level -Text $fullPrompt
        return $true
    }

    Write-StyledMessage -Type $Level -Text "${fullPrompt}: " -NoNewline
    $response = Read-Host
    Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'uiText.userConfirmationPrompt0Response1' -Args @($Prompt, $response))

    if ([string]::IsNullOrWhiteSpace($response)) { return $DefaultYes }
    return $response -match '^[sS]'
}

function Read-ValidatedChoice {
    <#
    .SYNOPSIS
        Legge e valida scelte numeriche dall'utente (singole o multiple).
    #>
    param(
        [int[]]$ValidRange,
        [int]$Min,
        [int]$Max,
        [switch]$AllowZero,
        [string]$Prompt = "Seleziona un'opzione",
        [string]$RawInput
    )

    $currentInput = if ($PSBoundParameters.ContainsKey('RawInput')) { $RawInput } else { $null }
    while ($true) {
        $userInput = if ($null -ne $currentInput) {
            $val = $currentInput; $currentInput = $null; $val
        }
        else {
            Write-StyledMessage -Type 'Question' -Text "${Prompt}: " -NoNewline
            Microsoft.PowerShell.Utility\Read-Host
        }

        if ([string]::IsNullOrWhiteSpace($userInput)) {
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.emptyInputTryAgain'))
            continue
        }

        $choices = $userInput -split '[\s,]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }

        if ($choices.Count -gt 0) {
            $isValid = $true
            foreach ($c in $choices) {
                if ($null -ne $ValidRange) { if ($c -notin $ValidRange) { $isValid = $false; break } }
                else {
                    if ($AllowZero -and $c -eq 0) { continue }
                    if ($null -ne $Min -and $c -lt $Min) { $isValid = $false; break }
                    if ($null -ne $Max -and $c -gt $Max) { $isValid = $false; break }
                }
            }
            if ($isValid) {
                Write-ToolkitLog -Level 'INFO' -Message (Get-SourceTextLoc 'uiText.userChoices0' -Args @($($choices -join ',')))
                return $choices
            }
        }

        $rangeStr = if ($null -ne $ValidRange) { "$($ValidRange[0]) e $($ValidRange[-1])" } else { "$Min e $Max" }
        Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.invalidChoiceEnterNumbersBetween0' -Args @($rangeStr)))
    }
}


# SECTION 10 · SYSTEM VERIFICATION AND COMPATIBILITY
# Pre-execution checks: OS, pending updates.
# ==============================================================================

function WinOSCheck {
    if ($Global:GuiSessionActive) { return }
    Show-Header -SubTitle (Get-SourceTextLoc 'system.infoTitle')
    $si = Get-SystemInfo
    if (-not $si) { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.systemInfoNotAvailable'); return }

    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'uiText.system01' -Args @($($si.ProductName), $($si.DisplayVersion)))

    if ($si.BuildNumber -ge 22000) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.compatibleSystemRecentWin1110') }
    elseif ($si.BuildNumber -ge 17763) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.compatibleSystemWin10') }
    elseif ($si.BuildNumber -eq 9600) { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.windows81PartialCompatibility') }
    else {
        Write-StyledMessage -Type 'Error' -Text "$(Get-CenteredText ('🤣 ' + (Get-SourceTextLoc 'sourceText.criticalError').ToUpperInvariant() + ' 🤣') 65)"
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'uiText.doYouReallyThinkThisScriptCanDoAnythingForThisVersion')
        Write-Host ("  " + (Get-SourceTextLoc 'uiText.doYouWantToTakeARiskYN')) -ForegroundColor Yellow
        if ((Read-Host) -notmatch '^[Yy]$') { exit }
    }
    Start-Sleep -Seconds 2
}

function Test-WindowsUpdateStatus {
    <#
    .SYNOPSIS
        Checks Windows Update status and warns about pending operations.
    .DESCRIPTION
        Checks pending reboot and TrustedInstaller service status.
        Uses PSWindowsUpdate if available, otherwise falls back to registry and native services.
    #>
    try {
        if ($Global:GuiSessionActive) { return }
        Write-StyledMessage -Type 'Info' -Text ("🔍 " + (Get-SourceTextLoc 'uiText.windowsUpdateStatusCheck'))

        $pendingReboot = $false
        $installerRunning = $false

        if (Get-Module -ListAvailable -Name PSWindowsUpdate -ErrorAction SilentlyContinue) {
            Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
            try {
                $rebootStatus = Get-WURebootStatus -ErrorAction SilentlyContinue
                if ($rebootStatus -and $rebootStatus.RebootRequired) {
                    $pendingReboot = $true
                    Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'uiText.pendingRebootDetectedForWindowsUpdates'))
                }
            }
            catch {
                Write-Warning "wintoolkit-modules\80-Module.UserInteraction.ps1, Test-WindowsUpdateStatus 1: $($_.Exception.Message)"
            }
            try {
                $installerStatus = Get-WUInstallerStatus -ErrorAction SilentlyContinue
                if ($installerStatus -and $installerStatus.IsBusy) {
                    $installerRunning = $true
                    Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'uiText.windowsUpdateInstallationServiceCurrentlyRunning'))
                }
            }
            catch {
                Write-Warning "wintoolkit-modules\80-Module.UserInteraction.ps1, Test-WindowsUpdateStatus 2: $($_.Exception.Message)"
            }
        }
        else {
            $regPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootRequired",
                "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"
            )
            foreach ($path in $regPaths) {
                if (Test-Path $path -ErrorAction SilentlyContinue) { $pendingReboot = $true; break }
            }
            $trustedInstaller = Get-Service -Name TrustedInstaller -ErrorAction SilentlyContinue
            if ($trustedInstaller -and $trustedInstaller.Status -eq 'Running') { $installerRunning = $true }
        }

        if ($pendingReboot -or $installerRunning) {
            $width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 }
            Write-Host ""
            Write-Host ('═' * ($width - 1)) -ForegroundColor Yellow
            Write-Host ""
            Write-Host (Get-CenteredText (Get-SourceTextLoc 'uiText.importantWarning')) -ForegroundColor Yellow
            Write-Host ""
            Write-Host (" " + (Get-SourceTextLoc 'uiText.pendingSystemUpdatesHaveBeenDetected')) -ForegroundColor Yellow
            if ($pendingReboot) { Write-Host ("  " + (Get-SourceTextLoc 'uiText.systemRestartRequiredToCompleteUpdates')) -ForegroundColor Yellow }
            if ($installerRunning) { Write-Host ("  " + (Get-SourceTextLoc 'uiText.windowsUpdateInstallationServiceIsRunning')) -ForegroundColor Yellow }
            Write-Host ""
            Write-Host (" " + (Get-SourceTextLoc 'uiText.thisMayCauseMalfunctionsErrorsOrBehavior')) -ForegroundColor Yellow
            Write-Host (" " + (Get-SourceTextLoc 'uiText.unexpectedBehaviorInSomeOrAllWintoolkitFeatures')) -ForegroundColor Yellow
            Write-Host ""
            Write-Host (Get-CenteredText (Get-SourceTextLoc 'uiText.proceedWithCaution')) -ForegroundColor Red
            Write-Host ""
            Write-Host (" " + (Get-SourceTextLoc 'uiText.weStronglyRecommendThatYouCompleteAllOngoingUpdates')) -ForegroundColor Yellow
            Write-Host (" " + (Get-SourceTextLoc 'uiText.rebootYourSystemAndThenRestartWintoolkitBeforeContinuing')) -ForegroundColor Yellow
            Write-Host ""
            Write-Host ('═' * ($width - 1)) -ForegroundColor Yellow
            Write-Host ""
            Start-Sleep -Seconds 5
        }
        else {
            Write-StyledMessage -Type 'Success' -Text ((Get-SourceTextLoc 'uiText.noPendingUpdatesDetected'))
        }
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text ((Get-SourceTextLoc 'uiText.unableToCheckWindowsUpdateStatus0' -Args @($($_.Exception.Message))))
    }
}
