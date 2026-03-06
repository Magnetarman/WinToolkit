function Repair-WingetDatabase {
    Write-StyledMessage -Type Info -Text "🔧 Avvio ripristino database Winget..."
    
    try {
        # 1. Ferma i processi interferenti
        Stop-InterferingProcess
        
        # 2. Pulizia cache locale di Winget
        $wingetCachePath = "$env:LOCALAPPDATA\WinGet"
        if (Test-Path $wingetCachePath) {
            Write-StyledMessage -Type Info -Text "Pulizia cache Winget..."
            Get-ChildItem -Path $wingetCachePath -Recurse -Force -ErrorAction SilentlyContinue | 
            Where-Object { $_.FullName -notmatch '\\lock\\|\\tmp\\' } |
            ForEach-Object {
                try { 
                    Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue 
                }
                catch { }
            }
        }
        
        # 3. Rimuovi file di stato danneggiati (solo JSON)
        $stateFiles = @(
            "$env:LOCALAPPDATA\WinGet\Data\USERTEMPLATE.json",
            "$env:LOCALAPPDATA\WinGet\Data\DEFAULTUSER.json"
        )
        
        foreach ($file in $stateFiles) {
            if (Test-Path $file -PathType Leaf) {
                Write-StyledMessage -Type Info -Text "Reset file stato: $file"
                Remove-Item $file -Force -ErrorAction SilentlyContinue
            }
        }
        
        # 4. Reset delle sorgenti Winget
        Write-StyledMessage -Type Info -Text "Reset sorgenti Winget..."
        try {
            $null = & winget.exe source reset --force 2>&1
        }
        catch {
            # Ignora errori durante il reset
        }
        
        # 5. Aggiorna il PATH
        Update-EnvironmentPath
        
        # 6. Reset completo del pacchetto AppInstaller (Cruciale per ACCESS_VIOLATION)
        Write-StyledMessage -Type Info -Text "Reset pacchetto Microsoft.DesktopAppInstaller..."
        if (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue) {
            Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
        }

        # 7. Riprova con il modulo WinGet se disponibile
        try {
            if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                Write-StyledMessage -Type Info -Text "Esecuzione Repair-WinGetPackageManager..."
                Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
            }
        }
        catch {
            Write-StyledMessage -Type Warning -Text "Modulo Riparazione non disponibile: $($_.Exception.Message)"
        }
        
        # 8. Applica permessi e refresh PATH
        Apply-WingetPathPermissions
        Update-EnvironmentPath
        
        # 9. Verifica che winget risponda
        Start-Sleep 2
        $testVersion = & winget --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-StyledMessage -Type Success -Text "✅ Database Winget ripristinato (versione: $testVersion)."
            return $true
        }
        else {
            Write-StyledMessage -Type Warning -Text "⚠️ Ripristino completato ma winget potrebbe non funzionare."
            return $true
        }
    }
    catch {
        Write-StyledMessage -Type Error -Text "❌ Errore durante ripristino database: $($_.Exception.Message)"
        return $false
    }
}
