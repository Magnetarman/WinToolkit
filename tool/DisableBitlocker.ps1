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

    Initialize-ToolLogging -ToolName "DisableBitlocker"
    Show-Header -SubTitle "Disable BitLocker Toolkit"
    $Host.UI.RawUI.WindowTitle = "Disable BitLocker Toolkit By MagnetarMan"

    # ============================================================================
    # 2. CONFIGURAZIONE E VARIABILI LOCALI
    # ============================================================================

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
    $Global:DisableBitlockerLog = @()

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

        # Tentativo disattivazione
        $procParams = @{
            FilePath     = 'manage-bde.exe'
            ArgumentList = @('-off', 'C:')
            PassThru     = $true
            Wait         = $true
            NoNewWindow  = $true
        }
        $proc = Start-Process @procParams

        if ($proc.ExitCode -eq 0) {
            Write-StyledMessage -Type 'Success' -Text "✅ Decrittazione avviata/completata con successo."
            Start-Sleep -Seconds 2

            # Check stato
            $status = Test-BitLockerStatus -DriveLetter "C:"
            if ($status -match "Decryption in progress" -or $status -match "Decriptazione in corso") {
                Write-StyledMessage -Type 'Info' -Text "⏳ Decrittazione in corso in background."
            }
        }
        else {
            Write-StyledMessage -Type 'Warning' -Text "⚠️ Codice uscita manage-bde: $($proc.ExitCode). BitLocker potrebbe essere già disattivo o in errore."
        }

        # Prevenzione crittografia futura
        Write-StyledMessage -Type 'Info' -Text "⚙️ Disabilitazione crittografia automatica nel registro..."
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name "PreventDeviceEncryption" -Type DWord -Value 1 -Force

        Write-StyledMessage -Type 'Success' -Text "🎉 Configurazione completata."
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "❌ Errore critico in DisableBitlocker: $($_.Exception.Message)"
    }
    finally {
        Write-StyledMessage -Type 'Info' -Text "♻️ Pulizia risorse Completata."
        if (-not $SuppressIndividualReboot) {
            Write-Host "`nPremi Enter per terminare..." -ForegroundColor Gray
            Read-Host | Out-Null
        }
        try { Stop-Transcript | Out-Null } catch {}
    }
}
