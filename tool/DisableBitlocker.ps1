function DisableBitlocker {
    <#
.SYNOPSIS
    Disattiva BitLocker sul drive C:.
#>
    param([bool]$RunStandalone = $true)

    Initialize-ToolLogging -ToolName "DisableBitlocker"
    Show-Header -SubTitle "Disattivazione BitLocker"

    Write-StyledMessage -Type 'Info' -Text "Inizializzazione decrittazione drive C:..."

    try {
        # Tentativo disattivazione
        $proc = Start-Process manage-bde.exe -ArgumentList "-off C:" -PassThru -Wait -NoNewWindow
    
        if ($proc.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text "Decrittazione avviata/completata con successo."
        
            # Check stato
            $status = manage-bde -status C:
            if ($status -match "Decryption in progress") {
                Write-StyledMessage -Type 'Info' -Text "Decrittazione in corso in background."
            }
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text "Codice uscita manage-bde: $($proc.ExitCode). BitLocker potrebbe essere già disattivo."
        }

        # Prevenzione crittografia futura
        Write-StyledMessage -Type 'Info' -Text "Disabilitazione crittografia automatica nel registro..."
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "PreventDeviceEncryption" -Type DWord -Value 1 -Force
    
        Write-StyledMessage -Type 'Success' -Text "Configurazione completata."
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore critico: $($_.Exception.Message)"
    }
}

DisableBitlocker