function DisableBitlocker {
    <#
    .SYNOPSIS
        Disattiva BitLocker sul drive C:.

    .DESCRIPTION
        Funzione per disattivare BitLocker sul drive C: e prevenire la crittografia futura.
        Include gestione degli errori e logging dettagliato.

    .PARAMETER RunStandalone
        Specifica se eseguire lo script in modalità standalone.

    .OUTPUTS
        None. La funzione non restituisce output.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$RunStandalone = $true
    )

    # 1. Inizializzazione logging
    Initialize-ToolLogging -ToolName "DisableBitlocker"
    Show-Header -SubTitle "Disattivazione BitLocker"

    # 2. Variabili locali
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"

    # 3. Funzioni helper locali
    function Test-BitLockerStatus {
        param([string]$DriveLetter = "C:")
        try {
            $status = manage-bde -status $DriveLetter
            return $status
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile verificare lo stato BitLocker: $($_.Exception.Message)"
            return $null
        }
    }

    # 4. Blocco try principale
    try {
        Write-StyledMessage -Type 'Info' -Text "Inizializzazione decrittazione drive C:..."

        # Tentativo disattivazione
        $proc = Start-Process manage-bde.exe -ArgumentList "-off C:" -PassThru -Wait -NoNewWindow

        if ($proc.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text "Decrittazione avviata/completata con successo."

            # Check stato
            $status = Test-BitLockerStatus -DriveLetter "C:"
            if ($status -match "Decryption in progress") {
                Write-StyledMessage -Type 'Info' -Text "Decrittazione in corso in background."
            }
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text "Codice uscita manage-bde: $($proc.ExitCode). BitLocker potrebbe essere già disattivo."
        }

        # Prevenzione crittografia futura
        Write-StyledMessage -Type 'Info' -Text "Disabilitazione crittografia automatica nel registro..."
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name "PreventDeviceEncryption" -Type DWord -Value 1 -Force

        Write-StyledMessage -Type 'Success' -Text "Configurazione completata."
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore critico: $($_.Exception.Message)"
    }
    finally {
        # Cleanup
        Write-StyledMessage -Type 'Info' -Text "Pulizia risorse temporanee..."
    }
}
