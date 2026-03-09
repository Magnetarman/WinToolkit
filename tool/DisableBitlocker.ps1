function DisableBitlocker {
    <#
    .SYNOPSIS
        Disattiva BitLocker sul drive C:.

    .DESCRIPTION
        Funzione per disattivare BitLocker sul drive C: e prevenire la crittografia futura.
        Include gestione degli errori e logging dettagliato.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$CountdownSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressIndividualReboot
    )

    # ============================================================================
    # 1. INIZIALIZZAZIONE
    # ============================================================================

    Start-ToolkitLog -ToolName "DisableBitlocker"
    Show-Header -SubTitle "Disable BitLocker Toolkit"
    $Host.UI.RawUI.WindowTitle = "Disable BitLocker Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    $regPath = $AppConfig.Registry.BitLocker
    $timeout = 3.600 # Un'ora in secondi

    # ============================================================================
    # 3. FUNZIONI HELPER LOCALI
    # ============================================================================

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

    # ============================================================================
    # 4. LOGICA PRINCIPALE (TRY-CATCH-FINALLY)
    # ============================================================================

    try {
        Write-StyledMessage -Type 'Info' -Text "🚀 Inizializzazione decrittazione drive C:..."

        # Tentativo disattivazione con spinner
        $result = Invoke-WithSpinner -Activity "Disattivazione BitLocker" -Process -Action {
            $procParams = @{
                FilePath     = 'manage-bde.exe'
                ArgumentList = @('-off', 'C:')
                PassThru     = $true
                WindowStyle  = 'Hidden'
            }
            Start-Process @procParams
        } -TimeoutSeconds $timeout

        if ($result.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text "✅ Decrittazione avviata/completata con successo."
            Start-Sleep -Seconds 2

            # Check stato
            $status = Test-BitLockerStatus -DriveLetter "C:"
            if ($status -match "Decryption in progress" -or $status -match "Decriptazione in corso") {
                Write-StyledMessage -Type 'Info' -Text "⏳ Decrittazione in corso in background."
            }
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text "⚠️ Codice uscita manage-bde: $($result.ExitCode). BitLocker potrebbe essere già disattivo o in errore."
        }

        # Prevenzione crittografia futura
        Write-StyledMessage -Type 'Info' -Text "⚙️ Disabilitazione crittografia automatica nel registro..."
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force *>$null
        }
        Set-ItemProperty -Path $regPath -Name "PreventDeviceEncryption" -Type DWord -Value 1 -Force

        Write-StyledMessage -Type 'Success' -Text "🎉 Configurazione completata."
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "❌ Errore critico in DisableBitlocker: $($_.Exception.Message)"
        Write-ToolkitLog -Level ERROR -Message "Errore critico in DisableBitlocker" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text "♻️ Pulizia risorse Completata."
        if ($SuppressIndividualReboot) {
            $Global:NeedsFinalReboot = $true
        }
        else {
            if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Riavvio in") {
                Restart-Computer -Force
            }
        }
        Write-ToolkitLog -Level INFO -Message "DisableBitlocker sessione terminata."
    }
}
