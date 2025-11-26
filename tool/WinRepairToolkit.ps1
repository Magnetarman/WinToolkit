function WinRepairToolkit {
    <#
.SYNOPSIS
    Esegue riparazioni standard di Windows (SFC, DISM, Chkdsk).
#>
    param([int]$MaxRetryAttempts = 3)

    Initialize-ToolLogging -ToolName "WinRepairToolkit"
    Show-Header -SubTitle "Repair Toolkit"

    $RepairTools = @(
        @{ Tool = 'chkdsk'; Args = @('/scan', '/perf'); Name = 'Controllo Disco (Scan)'; Icon = '💽' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'SFC - File di Sistema'; Icon = '🗂️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Name = 'DISM - RestoreHealth'; Icon = '🛠️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'); Name = 'DISM - ComponentCleanup'; Icon = '🕸️' }
    )

    function Invoke-RepairStep {
        param($Config, $Step, $Total)
        Write-StyledMessage -Type 'Info' -Text "[$Step/$Total] Avvio $($Config.Name)..."
    
        $outFile = [System.IO.Path]::GetTempFileName()
    
        try {
            $proc = Start-Process $Config.Tool -ArgumentList $Config.Args -RedirectStandardOutput $outFile -NoNewWindow -PassThru
        
            $spinnerIndex = 0
            while (-not $proc.HasExited) {
                $spinner = $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length]
                Write-Host "`r$spinner Esecuzione in corso..." -NoNewline -ForegroundColor Yellow
                Start-Sleep -Milliseconds 500
            }
            Write-Host "" 
        
            $output = Get-Content $outFile -ErrorAction SilentlyContinue
        
            if ($proc.ExitCode -eq 0 -or ($output -match "successfully")) {
                Write-StyledMessage -Type 'Success' -Text "$($Config.Name): Completato."
                return $true
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "$($Config.Name): Possibili errori (Exit: $($proc.ExitCode))."
                return $false
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore esecuzione: $_"
            return $false
        }
        finally {
            Remove-Item $outFile -ErrorAction SilentlyContinue
        }
    }

    # Ciclo principale
    $attempt = 1
    $errors = 0

    foreach ($tool in $RepairTools) {
        $res = Invoke-RepairStep -Config $tool -Step $attempt -Total $RepairTools.Count
        if (-not $res) { $errors++ }
        $attempt++
    }

    # Opzione Deep Repair
    Write-Host ""
    Write-StyledMessage -Type 'Info' -Text "Riepilogo: $errors errori rilevati dai tool."
    Write-Host "  Vuoi programmare un CHKDSK profondo al riavvio? [S/N]" -ForegroundColor Yellow
    $resp = Read-Host 

    if ($resp -eq 'S') {
        Start-Process 'fsutil.exe' -ArgumentList 'dirty', 'set', 'C:' -NoNewWindow -Wait
        Write-StyledMessage -Type 'Success' -Text "Volume C: marcato come dirty. Chkdsk partirà al riavvio."
    }

    # Set Password policy (bonus feature originale)
    Write-StyledMessage -Type 'Info' -Text "Impostazione scadenza password illimitata..."
    Start-Process "net" -ArgumentList "accounts", "/maxpwage:unlimited" -NoNewWindow -Wait | Out-Null

    if (Start-InterruptibleCountdown -Seconds 30 -Message "Riavvio per applicare riparazioni") {
        Restart-Computer -Force
    }
}

WinRepairToolkit