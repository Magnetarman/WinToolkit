<#
.SYNOPSIS
    Incrementa il numero di build nel template WinToolkit.

.DESCRIPTION
    Questo script legge il file WinToolkit-template.ps1, estrae la versione corrente,
    incrementa il numero di build e salva il file aggiornato.

.EXAMPLE
    .\Update-Version.ps1 -TemplatePath "WinToolkit-template.ps1"

.NOTES
    Autore: WinToolkit CI/CD
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TemplatePath = "WinToolkit-template.ps1"
)

# --- Best Practices PowerShell ---
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Variabili per output ---
$script:NewVersion = $null
$script:BuildNumber = $null
$script:OldVersion = $null

function Write-StatusMessage {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )

    $colors = @{
        'Info'    = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $colors[$Type]
}

try {
    Write-StatusMessage -Message "========================================" -Type Info
    Write-StatusMessage -Message "  INCREMENTO NUMERO BUILD" -Type Info
    Write-StatusMessage -Message "========================================" -Type Info

    # Verifica che il file esista
    if (-not (Test-Path $TemplatePath)) {
        Write-StatusMessage -Message "❌ File $TemplatePath non trovato" -Type Error
        exit 1
    }

    # Leggi il contenuto del file
    Write-StatusMessage -Message "📖 Lettura file: $TemplatePath" -Type Info
    $content = Get-Content -Path $TemplatePath -Raw

    # Trova la riga con la versione e estrai il numero di build
    $versionPattern = '\$ToolkitVersion\s*=\s*[''"](.+?)[''"]'

    if ($content -match $versionPattern) {
        $script:OldVersion = $matches[1]
        Write-StatusMessage -Message "📋 Versione attuale: $script:OldVersion" -Type Success

        # Estrai il numero di build (numero tra parentesi)
        $buildPattern = 'Build\s+(\d+)'

        if ($script:OldVersion -match $buildPattern) {
            $currentBuild = [int]$matches[1]
            $script:BuildNumber = $currentBuild + 1

            # Costruisci la nuova versione mantenendo lo stesso formato
            $script:NewVersion = $script:OldVersion -replace "Build\s+$currentBuild", "Build $script:BuildNumber"

            Write-StatusMessage -Message "🔄 Incremento build: $currentBuild → $script:BuildNumber" -Type Warning
            Write-StatusMessage -Message "🆕 Nuova versione: $script:NewVersion" -Type Success

            # Sostituisci la riga della versione
            $newLine = "`$ToolkitVersion = `"$script:NewVersion`""
            $content = $content -replace '\$ToolkitVersion\s*=\s*[''"](.+?)[''"]', $newLine

            # Scrivi il file aggiornato con encoding UTF8
            $content | Set-Content -Path $TemplatePath -Encoding UTF8

            Write-StatusMessage -Message "✅ Versione incrementata con successo" -Type Success
        }
        else {
            Write-StatusMessage -Message "❌ Impossibile trovare il numero di build nella versione" -Type Error
            exit 1
        }
    }
    else {
        Write-StatusMessage -Message "❌ Impossibile trovare la riga della versione nel template" -Type Error
        exit 1
    }

    # Output per GitHub Actions
    Write-Output "new_version=$script:NewVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "build_number=$script:BuildNumber" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "old_version=$script:OldVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append

    Write-StatusMessage -Message "========================================" -Type Info
    Write-StatusMessage -Message "  COMPLETATO" -Type Info
    Write-StatusMessage -Message "========================================" -Type Info

    exit 0
}
catch {
    Write-StatusMessage -Message "❌ ERRORE: $($_.Exception.Message)" -Type Error
    Write-StatusMessage -Message "Stack Trace: $($_.ScriptStackTrace)" -Type Error
    exit 1
}
