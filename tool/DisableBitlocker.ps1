function DisableBitlocker {
    <#
    .SYNOPSIS
        Disattiva BitLocker sul drive C:

    .DESCRIPTION
        Questo script disattiva la crittografia BitLocker per il drive di sistema (C:).
        Può essere eseguito in modalità standalone o come parte di un toolkit più ampio.
    #>

    param([bool]$RunStandalone = $true)

    $Host.UI.RawUI.WindowTitle = "BitLocker Toolkit By MagnetarMan"
    $script:Log = @()

    # Setup logging
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logDir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logDir\BitLockerToolkit_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}

    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    function Write-StyledMessage {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('Success', 'Warning', 'Error', 'Info')]
            [string]$Type,
            
            [Parameter(Mandatory = $true)]
            [string]$Text
        )

        $style = $MsgStyles[$Type]
        $timestamp = Get-Date -Format "HH:mm:ss"
        
        # Rimuovi emoji duplicati dal testo per il log
        $cleanText = $Text -replace '^[✅⚠️❌💎🔍🚀⚙️🧹📦📋📜📝💾⬇️🔧⚡🖼️🌐🍪🔄🗂️📁🖨️📄🗑️💭⏸️▶️💡⏰🎉💻📊]\s*', ''

        Write-Host "[$timestamp] $($style.Icon) $Text" -ForegroundColor $style.Color

        # Log automatico
        if ($Type -in @('Info', 'Warning', 'Error', 'Success')) {
            $logEntry = "[$timestamp] [$Type] $cleanText"
            $script:Log += $logEntry
        }
    }

    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )
    
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    
        return (' ' * $padding + $Text)
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ '
            '      \ \      / / | || \ | |'
            '       \ \ /\ / /  | ||  \| |'
            '        \ V  V /   | || |\  |'
            '         \_/\_/    |_||_| \_|'
            '',
            '    BitLocker Toolkit By MagnetarMan',
            '       Version 2.4.2 (Build 6)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    Show-Header

    for ($i = 5; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    try {
        Write-StyledMessage Info "🔑 Avvio processo di disattivazione BitLocker per il drive C:..."

        $commandOutput = & manage-bde.exe -off C: 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            if ($commandOutput -match "Decryption in progress") {
                Write-StyledMessage Success "Disattivazione BitLocker avviata con successo."
            }
            elseif ($commandOutput -match "Volume C: is not BitLocker protected") {
                Write-StyledMessage Info "BitLocker è già disattivato sul drive C:."
            }
            else {
                Write-StyledMessage Success "Comando manage-bde completato."
            }

            Write-StyledMessage Info "📋 Output completo di manage-bde:"
            foreach ($line in $commandOutput) {
                Write-Host "   $line" -ForegroundColor DarkGray
            }
        }
        else {
            Write-StyledMessage Error "Errore nell'esecuzione di manage-bde (Exit code: $exitCode)"
            Write-StyledMessage Info "📋 Output di errore:"
            foreach ($line in $commandOutput) {
                Write-Host "   $line" -ForegroundColor Red
            }
        }

        Write-StyledMessage Info "🎉 Operazione di disattivazione BitLocker completata."

        # Impedisce a Windows di avviare la crittografia automatica del dispositivo.
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
        if (-not (Test-Path -Path $regPath)) {
            New-Item -Path $regPath -ItemType Directory -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name "PreventDeviceEncryption" -Type DWord -Value 1 -Force

        Write-StyledMessage Info "Impostazione del Registro di sistema per prevenire la crittografia automatica del dispositivo completata."

    }
    catch {
        Write-StyledMessage Error "Errore imprevisto: $($_.Exception.Message)"
    }
    finally {
        if ($RunStandalone) {
            Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
            Read-Host
        }
        try { Stop-Transcript | Out-Null } catch {}
    }
}

DisableBitlocker