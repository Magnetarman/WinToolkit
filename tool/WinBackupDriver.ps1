function WinBackupDriver {
    <#
    .SYNOPSIS
        Strumento di backup completo per i driver di sistema Windows.

    .DESCRIPTION
        Script PowerShell per eseguire il backup completo di tutti i driver di terze parti
        installati sul sistema. Il processo include l'esportazione tramite DISM, compressione
        in formato ZIP e spostamento automatico sul desktop con nomenclatura data-based.
        Ideale per il backup pre-format o per la migrazione dei driver su un nuovo sistema.
    #>
    param([int]$CountdownSeconds = 10)
    
    $Host.UI.RawUI.WindowTitle = "Driver Backup Toolkit By MagnetarMan"
    $dt = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    
    try {
        if (-not (Test-Path $logdir)) { New-Item $logdir -ItemType Directory -Force | Out-Null }
        Start-Transcript "$logdir\WinBackupDriver_$dt.log" -Append -Force | Out-Null
    }
    catch {}
    
    $BackupDir = "$env:LOCALAPPDATA\WinToolkit\Driver Backup"
    $ZipName = "DriverBackup_$dt"
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
    $FinalZipPath = "$DesktopPath\$ZipName.zip"
    $MsgStyles = @{
        Success = @{Color = 'Green'; Icon = '✅' }; Warning = @{Color = 'Yellow'; Icon = '⚠️' }
        Error = @{Color = 'Red'; Icon = '❌' }; Info = @{Color = 'Cyan'; Icon = '💎' }
        Progress = @{Color = 'Magenta'; Icon = '🔄' }
    }
    
    function Center-Text([string]$Text, [int]$Width = $Host.UI.RawUI.BufferSize.Width) {
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }
    
    function Write-Msg([string]$Type, [string]$Text) {
        $s = $MsgStyles[$Type]
        Write-Host "$($s.Icon) $Text" -ForegroundColor $s.Color
    }
    
    function Show-Progress([string]$Activity, [string]$Status, [int]$Percent) {
        $p = [Math]::Max(0, [Math]::Min(100, $Percent))
        $filled = [Math]::Floor($p * 30 / 100)
        $bar = "[$(('█' * $filled) + ('░' * (30 - $filled)))] $p%"
        Write-Host "`r🔄 $Activity $bar $Status" -NoNewline -ForegroundColor Magenta
        if ($p -eq 100) { Write-Host '' }
    }
    
    function Show-Header {
        Clear-Host
        $w = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($w - 1)) -ForegroundColor Green
        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '   Driver Backup Toolkit By MagnetarMan',
            '       Version 2.4.2 (Build 3)'
        )
        foreach ($line in $asciiArt) {
            if ($line) { Write-Host (Center-Text $line $w) -ForegroundColor White } else { Write-Host '' }
        }
        Write-Host ('═' * ($w - 1)) -ForegroundColor Green
        Write-Host ''
    }
    
    function Test-Admin {
        $u = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($u)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    
    function Export-Drivers {
        Write-Msg Info "💾 Avvio esportazione driver di terze parti..."
        try {
            if (Test-Path $BackupDir) {
                Write-Msg Warning "Cartella backup esistente trovata, rimozione in corso..."
                $pos = [Console]::CursorTop
                $ErrorActionPreference = 'SilentlyContinue'
                $ProgressPreference = 'SilentlyContinue'
                Remove-Item $BackupDir -Recurse -Force -EA SilentlyContinue *>$null
                [Console]::SetCursorPosition(0, $pos)
                Write-Host ("`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r") -NoNewline
                [Console]::Out.Flush()
                $ErrorActionPreference = 'Continue'
                $ProgressPreference = 'Continue'
                Start-Sleep 1
            }
            
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            Write-Msg Success "Cartella backup creata: $BackupDir"
            Write-Msg Info "🔧 Esecuzione DISM per esportazione driver..."
            Write-Msg Info "💡 Questa operazione può richiedere diversi minuti..."
            
            $proc = Start-Process 'dism.exe' -ArgumentList @('/online', '/export-driver', "/destination:`"$BackupDir`"") -NoNewWindow -PassThru -Wait
            
            if ($proc.ExitCode -eq 0) {
                $drivers = Get-ChildItem $BackupDir -Recurse -File -EA SilentlyContinue
                if ($drivers -and $drivers.Count -gt 0) {
                    Write-Msg Success "Driver esportati con successo!"
                    Write-Msg Info "Driver trovati: $($drivers.Count)"
                }
                else {
                    Write-Msg Warning "Nessun driver di terze parti trovato da esportare"
                    Write-Msg Info "💡 I driver integrati di Windows non vengono esportati"
                }
                return $true
            }
            Write-Msg Error "Errore durante esportazione DISM (Exit code: $($proc.ExitCode))"
            return $false
        }
        catch {
            Write-Msg Error "Errore durante esportazione driver: $_"
            return $false
        }
    }
    
    function Compress-Backup {
        Write-Msg Info "📦 Compressione cartella backup..."
        try {
            if (-not (Test-Path $BackupDir)) {
                Write-Msg Error "Cartella backup non trovata"
                return $false
            }
            
            $files = Get-ChildItem $BackupDir -Recurse -File -EA SilentlyContinue
            if (-not $files -or $files.Count -eq 0) {
                Write-Msg Warning "Nessun file da comprimere nella cartella backup"
                return $false
            }
            
            $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
            $totalMB = [Math]::Round($totalSize / 1MB, 2)
            Write-Msg Info "Dimensione totale: $totalMB MB"
            
            $tempZip = "$env:TEMP\$ZipName.zip"
            if (Test-Path $tempZip) { Remove-Item $tempZip -Force -EA SilentlyContinue }
            
            Write-Msg Info "🔄 Compressione in corso..."
            $job = Start-Job -ScriptBlock {
                param($b, $t)
                Compress-Archive -Path $b -DestinationPath $t -CompressionLevel Optimal -Force
            } -ArgumentList $BackupDir, $tempZip
            
            $prog = 0
            while ($job.State -eq 'Running') {
                $prog += Get-Random -Minimum 1 -Maximum 5
                if ($prog -gt 95) { $prog = 95 }
                Show-Progress "Compressione" "Elaborazione file..." $prog
                Start-Sleep -Milliseconds 500
            }
            
            Receive-Job $job -Wait | Out-Null
            Remove-Job $job
            Show-Progress "Compressione" "Completato!" 100
            Write-Host ''
            
            if (Test-Path $tempZip) {
                $zipMB = [Math]::Round((Get-Item $tempZip).Length / 1MB, 2)
                Write-Msg Success "Compressione completata!"
                Write-Msg Info "Archivio creato: $tempZip ($zipMB MB)"
                return $tempZip
            }
            Write-Msg Error "File ZIP non creato"
            return $false
        }
        catch {
            Write-Msg Error "Errore durante compressione: $_"
            return $false
        }
    }
    
    function Move-ToDesktop([string]$ZipPath) {
        Write-Msg Info "📂 Spostamento archivio sul desktop..."
        try {
            if (-not (Test-Path $ZipPath)) {
                Write-Msg Error "File ZIP non trovato: $ZipPath"
                return $false
            }
            Move-Item $ZipPath $FinalZipPath -Force -EA Stop
            if (Test-Path $FinalZipPath) {
                Write-Msg Success "Archivio spostato sul desktop!"
                Write-Msg Info "Posizione: $FinalZipPath"
                return $true
            }
            Write-Msg Error "Errore durante spostamento sul desktop"
            return $false
        }
        catch {
            Write-Msg Error "Errore spostamento: $_"
            return $false
        }
    }
    
    function Show-Summary {
        Write-Host ''
        Write-Msg Success "🎉 Backup driver completato con successo!"
        Write-Host ''
        Write-Msg Info "📁 Posizione archivio:"
        Write-Host "  $FinalZipPath" -ForegroundColor Cyan
        Write-Host ''
        Write-Msg Info "💡 IMPORTANTE:"
        Write-Msg Info "  📄 Salva questo archivio in un luogo sicuro!"
        Write-Msg Info "  💾 Potrai utilizzarlo per reinstallare tutti i driver"
        Write-Msg Info "  🔧 Senza doverli riscaricare singolarmente"
        Write-Host ''
    }
    
    Show-Header
    
    if (-not (Test-Admin)) {
        Write-Msg Error " Questo script richiede privilegi amministrativi!"
        Write-Msg Info "💡 Riavvia PowerShell come Amministratore e riprova"
        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        return
    }
    
    Write-Host "⏳ Inizializzazione sistema..." -ForegroundColor Yellow
    Start-Sleep 2
    Write-Host "✅ Sistema pronto`n" -ForegroundColor Green
    
    try {
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Msg Info "📋 FASE 1: ESPORTAZIONE DRIVER"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''
        
        if (-not (Export-Drivers)) {
            Write-Msg Error "Esportazione driver fallita"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }
        
        Write-Host ''
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Msg Info "📋 FASE 2: COMPRESSIONE ARCHIVIO"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''
        
        $zip = Compress-Backup
        if (-not $zip) {
            Write-Msg Error "Compressione fallita"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }
        
        Write-Host ''
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Msg Info "📋 FASE 3: SPOSTAMENTO DESKTOP"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''
        
        if (-not (Move-ToDesktop $zip)) {
            Write-Msg Error "Spostamento sul desktop fallito"
            Write-Msg Warning "💡 L'archivio potrebbe essere ancora nella cartella temporanea"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }
        
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Msg Info "📋 BACKUP COMPLETATO"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''
        Show-Summary
        
    }
    catch {
        Write-Msg Error "Errore critico durante il backup: $($_.Exception.Message)"
        Write-Msg Info "💡 Controlla i log per dettagli o contatta il supporto"
    }
    finally {
        Write-Msg Info "🧹 Pulizia cartella temporanea..."
        if (Test-Path $BackupDir) {
            $pos = [Console]::CursorTop
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            Remove-Item $BackupDir -Recurse -Force -EA SilentlyContinue *>$null
            [Console]::SetCursorPosition(0, $pos)
            Write-Host ("`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r") -NoNewline
            [Console]::Out.Flush()
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
        }
        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        Write-Msg Success "🎯 Driver Backup Toolkit terminato"
        try { Stop-Transcript | Out-Null } catch {}
    }
}

WinBackupDrivernsole]::Out.Flush()
            
# Reset delle preferenze
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'
}

Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
Read-Host | Out-Null
Write-StyledMessage Success "🎯 Driver Backup Toolkit terminato"
try { Stop-Transcript | Out-Null } catch {}
}
}

WinBackupDrivernsole]::Out.Flush()
            
# Reset delle preferenze
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'
}

Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
Read-Host | Out-Null
Write-StyledMessage Success "🎯 Driver Backup Toolkit terminato"
try { Stop-Transcript | Out-Null } catch {}
}
}

WinBackupDrivernsole]::Out.Flush()
            
# Reset delle preferenze
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'
}

Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
Read-Host | Out-Null
Write-StyledMessage Success "🎯 Driver Backup Toolkit terminato"
try { Stop-Transcript | Out-Null } catch {}
}
}

WinBackupDrivernsole]::Out.Flush()
            
# Reset delle preferenze
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'
}

Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
Read-Host | Out-Null
Write-StyledMessage Success "🎯 Driver Backup Toolkit terminato"
try { Stop-Transcript | Out-Null } catch {}
}
}

WinBackupDriver