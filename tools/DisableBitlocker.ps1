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

    Start-ToolkitSession -ToolName "DisableBitlocker" -SubTitle "Disable BitLocker Toolkit"

    $regPath = $AppConfig.Registry.BitLocker
    $timeout = 3600

    function Test-BitLockerStatus {
        param([string]$DriveLetter = "C:")
        try { return manage-bde -status $DriveLetter }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile verificare lo stato BitLocker: $($_.Exception.Message)"
            return $null
        }
    }

    try {
        Write-StyledMessage -Type 'Info' -Text "🚀 Inizializzazione decrittazione drive C:."

        $result = Invoke-WithSpinner -Activity "Disattivazione BitLocker" -Command 'manage-bde.exe' `
            -Arguments @('-off', 'C:') -TimeoutSeconds $timeout -LogContextKey "Bitlocker-Disable"

        if ($result.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text "✅ Decrittazione avviata/completata con successo."
            Start-Sleep -Seconds 2
            $status = Test-BitLockerStatus -DriveLetter "C:"
            if ($status -match "Decryption in progress" -or $status -match "Decriptazione in corso.") {
                Write-StyledMessage -Type 'Info' -Text "⏳ Decrittazione in corso in background."
            }
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text "⚠️ Codice uscita manage-bde: $($result.ExitCode). BitLocker potrebbe essere già disattivo o in errore."
        }

        Write-StyledMessage -Type 'Info' -Text "⚙️ Disabilitazione crittografia automatica nel registro."
        Set-RegistryValue -Path $regPath -Name "PreventDeviceEncryption" -Value 1

        Write-StyledMessage -Type 'Success' -Text "🎉 Configurazione completata."
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName "DisableBitlocker"
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text "♻️ Pulizia risorse completata."
        Invoke-ToolkitReboot -Message "Riavvio in" -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
        Write-ToolkitLog -Level INFO -Message "DisableBitlocker sessione terminata."
    }
}
