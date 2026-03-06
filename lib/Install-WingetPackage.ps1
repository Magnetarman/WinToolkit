function Install-WingetPackage {
    Write-StyledMessage -Type Info -Text "🚀 Avvio procedura installazione/verifica Winget..."

    if (-not (Test-WingetCompatibility)) { return $false }

    # Usa la funzione avanzata ForceClose
    Invoke-ForceCloseWinget

    try {
        $ProgressPreference = 'SilentlyContinue'

        # Pulizia temporanei
        $tempPath = "$env:TEMP\WinGet"
        if (Test-Path $tempPath) {
            Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-StyledMessage -Type Info -Text "Cache temporanea eliminata."
        }

        # Reset sorgenti se Winget esiste
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text "Reset sorgenti Winget..."
            try {
                $null = & "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" source reset --force 2>$null
            }
            catch { }
        }

        # Installa NuGet se richiesto (basato su asheroto)
        Write-StyledMessage -Type Info -Text "Verifica/installazione NuGet provider..."
        Install-NuGetIfRequired

        # Fallback: Installazione dipendenze NuGet
        Write-StyledMessage -Type Info -Text "Installazione modulo Microsoft.WinGet.Client..."
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop *>$null
            Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Confirm:$false -ErrorAction Stop *>$null
            Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
            Write-StyledMessage -Type Success -Text "Modulo WinGet Client installato."
        }
        catch {
            Write-StyledMessage -Type Warning -Text "Modulo WinGet Client: $($_.Exception.Message)"
        }

        # Riparazione via modulo
        Write-StyledMessage -Type Info -Text "Tentativo riparazione Winget (Repair-WinGetPackageManager)..."
        if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
            try {
                Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                Write-StyledMessage -Type Success -Text "Repair-WinGetPackageManager eseguito."
            }
            catch {
                Write-StyledMessage -Type Warning -Text "Repair-WinGetPackageManager fallito: $($_.Exception.Message)"
            }
            Start-Sleep 3
        }

        # Fallback finale: installazione via MSIXBundle
        Update-EnvironmentPath
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type Info -Text "Download MSIXBundle da Microsoft..."
            $msixTempDir = $script:AppConfig.Paths.Temp
            if (-not (Test-Path $msixTempDir)) { $null = New-Item -Path $msixTempDir -ItemType Directory -Force }
            $tempInstaller = Join-Path $msixTempDir "WingetInstaller.msixbundle"

            $iwrParams = @{
                Uri             = $script:AppConfig.URLs.WingetMSIX
                OutFile         = $tempInstaller
                UseBasicParsing = $true
                ErrorAction     = 'Stop'
            }
            Invoke-WebRequest @iwrParams
            Add-AppxPackage -Path $tempInstaller -ForceApplicationShutdown -ErrorAction Stop
            Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
            Start-Sleep 3
        }

        # Reset App Installer
        Write-StyledMessage -Type Info -Text "Reset App Installer..."
        try {
            Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Reset-AppxPackage 2>$null
        }
        catch { }

        # Applica permessi PATH e registrazione (basato su asheroto)
        Apply-WingetPathPermissions

        Start-Sleep 2

        Update-EnvironmentPath
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Success -Text "✅ Winget installato e funzionante."
            return $true
        }

        Write-StyledMessage -Type Error -Text "❌ Impossibile installare Winget."
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore critico: $($_.Exception.Message)"
        return $false
    }
    finally {
        $ProgressPreference = 'Continue'
    }
}
