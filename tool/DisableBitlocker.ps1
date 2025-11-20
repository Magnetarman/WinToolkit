function DisableBitlocker {
    <#
    .SYNOPSIS
        Disattiva BitLocker sul drive C:

    .DESCRIPTION
        Questo script disattiva la crittografia BitLocker per il drive di sistema (C:).
        Può essere eseguito in modalità standalone o come parte di un toolkit più ampio.
    #>

    param([bool]$RunStandalone = $true)

    # Configurazione
    $Host.UI.RawUI.WindowTitle = "BitLocker Toolkit By MagnetarMan"

    # Setup logging
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logDir = "$env:LOCALAPPDATA\WinToolkit\logs"

    try {
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logDir\BitLockerToolkit_$dateTime.log" -Append -Force | Out-Null
    }
    catch {
        Write-Warning "Impossibile inizializzare il logging: $_"
    }

    # Caratteri spinner per animazioni
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()

    # Stili messaggi
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    $script:Log = @()

    function Write-StyledMessage {
        param(
            [string]$Type,
            [string]$Text
        )

        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
        if ($Type -in @('Info', 'Warning', 'Error', 'Success')) {
            $script:Log += "[$(Get-Date -Format 'HH:mm:ss')] [$Type] $Text"
        }
    }

    function Center-Text {
        [CmdletBinding()]
        [OutputType([string])]
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
            ''
            '    BitLocker Toolkit By MagnetarMan'
            '       Version 2.4.2 (Build 5)'
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

    # Countdown preparazione
    for ($i = 5; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    Write-StyledMessage Info "🔑 Avvio processo di disattivazione BitLocker per il drive C:..."

    try {
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
    }
    catch {
        Write-StyledMessage Error "Errore imprevisto: $($_.Exception.Message)"
    }

    Write-StyledMessage Info "🎉 Operazione di disattivazione BitLocker completata."

    # Impedisce a Windows di avviare la crittografia automatica del dispositivo.
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
    if (-not (Test-Path -Path $regPath)) {
        New-Item -Path $regPath -ItemType Directory -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "PreventDeviceEncryption" -Type DWord -Value 1 -Force

    Write-StyledMessage Info "Impostazione del Registro di sistema per prevenire la crittografia automatica del dispositivo completata."

    if ($RunStandalone) {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        $null = Read-Host
    }

    try { Stop-Transcript | Out-Null } catch {}
}

DisableBitlocker