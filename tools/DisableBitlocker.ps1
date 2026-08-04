function DisableBitlocker {
    <#
    .SYNOPSIS
        Disattiva BitLocker sul drive C: e previene la crittografia futura.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "DisableBitlocker" -SubTitle (Get-SourceTextLoc 'script.DisableBitlocker')

    $regPath = $AppConfig.Registry.BitLocker
    $timeout = 3600

    function Test-BitLockerStatus {
        param([string]$DriveLetter = "C:")
        try { return manage-bde -status $DriveLetter }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.unableToCheckBitlockerStatus0' -Args @($($_.Exception.Message)))
            return $null
        }
    }

    try {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.initializingDriveCDecryption')

        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.disablingBitlocker') -Command 'manage-bde.exe' `
            -Arguments @('-off', 'C:') -TimeoutSeconds $timeout -LogContextKey "Bitlocker-Disable"

        if ($result.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.decryptionStartedCompletedSuccessfully')
            Start-Sleep -Seconds 2
            $status = Test-BitLockerStatus -DriveLetter "C:"
            if ($status -match "Decryption in progress" -or $status -match 'Decryption in progress.') {
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.decryptionInProgressInBackground')
            }
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.manageBdeExitCode0BitlockerMayAlreadyBeDownOrInError' -Args @($($result.ExitCode)))
        }

        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.disablingAutomaticEncryptionInTheRegistry')
        Set-RegistryValue -Path $regPath -Name "PreventDeviceEncryption" -Value 1

        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.setupComplete')
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "DisableBitlocker"
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.resourceCleanupCompleted')
        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.rebootingIn') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.disablebitlockerSessionEnded')
    }
}
