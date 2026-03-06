function Install-WingetCore {
    Write-StyledMessage -Type Info -Text "🛠️ Avvio procedura di ripristino Winget (Core)..."

    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    # Helper function per rilevare info OS
    function Get-OSInfoSimple {
        $registryValues = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        $releaseId = $registryValues.ReleaseId
        $installationType = $registryValues.InstallationType
        $version = [System.Environment]::OSVersion.Version
        
        try {
            $osDetails = Get-CimInstance -ClassName Win32_OperatingSystem
            $productType = $osDetails.ProductType
            if ($productType -eq 1) { $type = "Workstation" } 
            elseif ($productType -eq 2 -or $productType -eq 3) { $type = "Server" }
            else { $type = "Unknown" }
        }
        catch { $type = "Unknown" }
        
        return @{
            ReleaseId        = $releaseId
            InstallationType = $installationType
            Version          = $version
            Type             = $type
            NumericVersion   = [int]($osDetails.Caption -replace "[^\d]").Trim()
        }
    }

    # Configurazione Helper interni
    function Get-WingetDownloadUrl {
        param([string]$Match)
        try {
            $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
            $asset = $latest.assets | Where-Object { $_.name -match $Match } | Select-Object -First 1
            if ($asset) { return $asset.browser_download_url }
            throw "Asset '$Match' non trovato."
        }
        catch {
            Write-StyledMessage -Type Warning -Text "Errore recupero URL asset: $($_.Exception.Message)"
            return $null
        }
    }

    $osInfo = Get-OSInfoSimple
    $tempDir = "$env:TEMP\WinToolkitWinget"
    if (-not (Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force *>$null }

    try {
        # 1. Visual C++ Redistributable (usando test avanzato)
        if (-not (Test-VCRedistInstalled)) {
            Write-StyledMessage -Type Info -Text "Installazione Visual C++ Redistributable..."
            $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
            $vcUrl = "https://aka.ms/vs/17/release/vc_redist.$arch.exe"
            $vcFile = Join-Path $tempDir "vc_redist.exe"

            Invoke-WebRequest -Uri $vcUrl -OutFile $vcFile -UseBasicParsing
            $procParams = @{
                FilePath     = $vcFile
                ArgumentList = @("/install", "/quiet", "/norestart")
                Wait         = $true
                NoNewWindow  = $true
            }
            Start-Process @procParams
            Write-StyledMessage -Type Success -Text "Visual C++ Redistributable installato."
        }
        else {
            Write-StyledMessage -Type Success -Text "Visual C++ Redistributable già presente."
        }

        # 2. Dipendenze (UI.Xaml, VCLibs) — Estrazione dal pacchetto ufficiale (Metodo Sicuro)
        Write-StyledMessage -Type Info -Text "Download dipendenze Winget dal repository ufficiale..."
        $depUrl = Get-WingetDownloadUrl -Match 'DesktopAppInstaller_Dependencies.zip'
        if ($depUrl) {
            $depZip = Join-Path $tempDir "dependencies.zip"
            try {
                $iwrDepParams = @{
                    Uri             = $depUrl
                    OutFile         = $depZip
                    UseBasicParsing = $true
                    ErrorAction     = 'Stop'
                }
                Invoke-WebRequest @iwrDepParams

                # Estrazione e installazione mirata per architettura
                $extractPath = Join-Path $tempDir "deps"
                Expand-Archive -Path $depZip -DestinationPath $extractPath -Force

                $archPattern = if ([Environment]::Is64BitOperatingSystem) { "x64|ne" } else { "x86|ne" }
                $appxFiles = Get-ChildItem -Path $extractPath -Recurse -Filter "*.appx" | Where-Object { $_.Name -match $archPattern }

                foreach ($file in $appxFiles) {
                    Write-StyledMessage -Type Info -Text "Installazione dipendenza: $($file.Name)..."
                    Add-AppxPackage -Path $file.FullName -ErrorAction SilentlyContinue -ForceApplicationShutdown
                }
            }
            catch {
                Write-StyledMessage -Type Warning -Text "Impossibile estrarre o installare le dipendenze dallo zip ufficiale. Errore: $($_.Exception.Message)"
            }
        }

        # 3. Winget Bundle
        Write-StyledMessage -Type Info -Text "Download e installazione Winget Bundle..."
        $wingetUrl = Get-WingetDownloadUrl -Match 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        if ($wingetUrl) {
            $wingetFile = Join-Path $tempDir "winget.msixbundle"
            Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetFile -UseBasicParsing

            Add-AppxPackage -Path $wingetFile -ForceApplicationShutdown -ErrorAction Stop
            Write-StyledMessage -Type Success -Text "Winget Core installato con successo."
        }

        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text "Errore durante il ripristino Winget: $($_.Exception.Message)"
        return $false
    }
    finally {
        if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
        $ProgressPreference = $oldProgress
    }
}
