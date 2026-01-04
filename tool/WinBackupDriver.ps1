function WinBackupDriver {
    <#
    .SYNOPSIS
        Strumento di backup completo per i driver di sistema Windows.
    .DESCRIPTION
        Script PowerShell per eseguire il backup completo di tutti i driver di terze parti
        installati sul sistema. Il processo include l'esportazione tramite DISM, compressione
        in formato ZIP e spostamento automatico sul desktop.
    #>
    param([int]$CountdownSeconds = 10)

    Initialize-ToolLogging -ToolName "WinBackupDriver"
    Show-Header -SubTitle "Driver Backup Toolkit"

    $dt = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $BackupDir = "$env:LOCALAPPDATA\WinToolkit\Driver Backup"
    $ZipName = "DriverBackup_$dt"
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
    $FinalZipPath = "$DesktopPath\$ZipName.zip"

    function Test-Admin {
        return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Export-Drivers {
        Write-StyledMessage Info "💾 Avvio esportazione driver di terze parti..."
        try {
            if (Test-Path $BackupDir) {
                Write-StyledMessage Warning "Rimozione backup precedenti..."
                Remove-Item $BackupDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            }

            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            Write-StyledMessage Success "Cartella backup preparata: $BackupDir"

            $procResult = Invoke-WithSpinner -Activity "Esportazione driver (DISM)" -Process -Action {
                Start-Process 'dism.exe' -ArgumentList @('/online', '/export-driver', "/destination:`"$BackupDir`"") -NoNewWindow -PassThru
            }

            if ($procResult.Success -and $procResult.ExitCode -eq 0) {
                $drivers = Get-ChildItem $BackupDir -Recurse -File -ErrorAction SilentlyContinue
                if ($drivers) {
                    Write-StyledMessage Success "Esportazione completata: $($drivers.Count) driver trovati."
                    return $true
                }
                Write-StyledMessage Warning "Nessun driver di terze parti trovato."
                return $true
            }
            Write-StyledMessage Error "Esportazione DISM fallita (ExitCode: $($procResult.ExitCode))."
            return $false
        }
        catch {
            Write-StyledMessage Error "Errore export: $_"
            return $false
        }
    }

    function Install-7ZipPortable {
        $7zDir = "$env:LOCALAPPDATA\WinToolkit\7zip"
        $7zExe = "$7zDir\7zr.exe"
        if (Test-Path $7zExe) { return $7zExe }

        New-Item -ItemType Directory -Path $7zDir -Force | Out-Null
        $urls = @("https://www.7-zip.org/a/7zr.exe", "https://github.com/Magnetarman/WinToolkit/raw/Dev/asset/7zr.exe")

        foreach ($url in $urls) {
            Write-StyledMessage Info "Download 7-Zip da: $(($url -split '/')[2])"
            $job = Start-Job -ScriptBlock {
                param($u, $f)
                try { 
                    Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing -ErrorAction Stop
                    return $true 
                }
                catch { return $false }
            } -ArgumentList $url, $7zExe

            if (Invoke-WithSpinner -Activity "Scaricamento 7-Zip" -Job -Action { $job }) {
                if (Test-Path $7zExe) {
                    Write-StyledMessage Success "7-Zip Portable scaricato."
                    return $7zExe
                }
            }
        }
        Write-StyledMessage Error "Download 7-Zip fallito."
        return $null
    }

    function Get-7ZipExecutable {
        $paths = @(
            "$env:ProgramFiles\7-Zip\7z.exe",
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
            "$env:LOCALAPPDATA\7-Zip\7z.exe"
        )
        foreach ($p in $paths) { if (Test-Path $p) { Write-StyledMessage Success "7-Zip trovato: $p"; return $p } }
        return Install-7ZipPortable
    }

    function Compress-With7Zip {
        param([string]$SevenZipPath)
        
        Write-StyledMessage Info "📦 Preparazione compressione..."
        if (-not (Test-Path $BackupDir)) { Write-StyledMessage Error "Cartella backup non trovata."; return $null }

        $files = Get-ChildItem $BackupDir -Recurse -File -EA SilentlyContinue
        if (-not $files) { Write-StyledMessage Warning "Nessun file da comprimere."; return $null }

        $totalMB = [Math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-StyledMessage Info "Dimensione totale: $totalMB MB"

        $tempZip = "$env:TEMP\$ZipName.zip"
        $stderrFile = "$env:TEMP\7z_error_$($PID).log"
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force }

        $7zArgs = @('a', '-tzip', '-mx9', '-mmt', "`"$tempZip`"", "`"$BackupDir\*`"")
        
        $res = Invoke-WithSpinner -Activity "Compressione 7-Zip (Ultra)" -Process -Action {
            Start-Process $SevenZipPath -ArgumentList $7zArgs -NoNewWindow -PassThru -RedirectStandardError $stderrFile
        }

        if ($res.Success -and $res.ExitCode -eq 0 -and (Test-Path $tempZip)) {
            $zipMB = [Math]::Round((Get-Item $tempZip).Length / 1MB, 2)
            Write-StyledMessage Success "Compressione completata: $zipMB MB"
            Remove-Item $stderrFile -ErrorAction SilentlyContinue
            return $tempZip
        }

        Write-StyledMessage Error "Compressione fallita (Code: $($res.ExitCode))"
        if (Test-Path $stderrFile) { Write-StyledMessage Error "Dettagli: $(Get-Content $stderrFile)" }
        Remove-Item $stderrFile -ErrorAction SilentlyContinue
        return $null
    }

    function Move-ToDesktop([string]$ZipPath) {
        if ([string]::IsNullOrWhiteSpace($ZipPath) -or -not (Test-Path $ZipPath)) { return $false }
        
        Write-StyledMessage Info "📂 Spostamento su Desktop..."
        try {
            if (-not (Test-Path $DesktopPath)) { throw "Desktop non trovato" }
            Copy-Item $ZipPath $FinalZipPath -Force -ErrorAction Stop
            if (Test-Path $FinalZipPath) {
                Remove-Item $ZipPath -Force
                Write-StyledMessage Success "Archivio salvato: $FinalZipPath"
                return $true
            }
        }
        catch {
            Write-StyledMessage Error "Errore spostamento: $_"
        }
        return $false
    }

    # --- MAIN EXECUTION ---
    if (-not (Test-Admin)) {
        Write-StyledMessage Error "Richiesti privilegi di amministratore."
        Read-Host "Premi INVIO per uscire"
        return
    }

    try {
        Write-Host ""
        if (Export-Drivers) {
            Write-Host ""
            $7zPath = Get-7ZipExecutable
            if ($7zPath) {
                Write-Host ""
                $zip = Compress-With7Zip -SevenZipPath $7zPath
                if ($zip) {
                    Write-Host ""
                    Move-ToDesktop $zip | Out-Null
                    Write-Host ""
                    Write-StyledMessage Success "🎉 Backup completato!"
                    Write-StyledMessage Info "Conservare il file: $FinalZipPath"
                }
            }
        }
    }
    catch {
        Write-StyledMessage Error "Errore critico: $_"
    }
    finally {
        if (Test-Path $BackupDir) { Remove-Item $BackupDir -Recurse -Force -EA SilentlyContinue }
        Write-Host "`nPremi INVIO per terminare..." -ForegroundColor Gray
        Read-Host | Out-Null
        try { Stop-Transcript | Out-Null } catch {}
    }
}
