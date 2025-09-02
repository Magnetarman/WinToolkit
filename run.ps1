# Imposto la ExecutionPolicy per l'utente corrente per permettere l'esecuzione degli script
try {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
} catch {
    Write-Host "⚠️ Impossibile impostare ExecutionPolicy CurrentUser: $_" -ForegroundColor Yellow
}
Write-Host "ExecutionPolicy (CurrentUser): $(Get-ExecutionPolicy -Scope CurrentUser)"
function powershell-update {
	Write-Host "[i] Controllo aggiornamenti PowerShell..." -ForegroundColor Cyan
	$pwshExe = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
	$isPwshInstalled = Test-Path $pwshExe
	if (-not $isPwshInstalled) {
		Write-Host "[i] PowerShell 7 non trovato. Download in corso..." -ForegroundColor Yellow
		$installerUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.4.2-win-x64.msi"
		$installerPath = "$env:TEMP\PowerShell-7-latest.msi"
		Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
		Write-Host "[i] Installazione di PowerShell 7..." -ForegroundColor Yellow
		Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /qn" -Wait
	}
	# Installa dipendenze (moduli utili)
	$modules = @('PSReadLine','ThreadJob')
	foreach ($mod in $modules) {
		try {
			if (-not (Get-Module -ListAvailable -Name $mod)) {
				Write-Host "[i] Installazione modulo $mod..." -ForegroundColor Yellow
				Install-Module -Name $mod -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
			}
	} catch {
            $errMsg = "Errore installazione modulo {0}: {1}" -f $mod, $_.Exception.Message
            Write-Host "[X] $errMsg" -ForegroundColor Red
        }
	}
	# Se PowerShell 7 è ora installato, rilancia lo script
	if (Test-Path $pwshExe) {
		Write-Host "[OK] PowerShell aggiornato. Riavvio script con la nuova versione..." -ForegroundColor Green
		Start-Process -FilePath $pwshExe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Wait
		exit
	} else {
		Write-Host "[X] Aggiornamento PowerShell fallito." -ForegroundColor Red
	}
}

# Funzione per messaggi stilizzati
function Write-StyledMessage([string]$Type, [string]$Text) {
	$style = @{
		Success = @{ Color = 'Green'; Icon = '✅' }; Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
		Error = @{ Color = 'Red'; Icon = '❌' }; Info = @{ Color = 'Cyan'; Icon = '💎' }
	}[$Type]
	Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
}
# Funzione per centrare il testo
function Center-Text($text, $width) {
	$pad = [Math]::Max(0, ($width - $text.Length) / 2)
	return (' ' * [Math]::Floor($pad)) + $text
}
# Funzione per messaggi stilizzati
function Write-StyledMessage([string]$Type, [string]$Text) {
	$style = @{
		Success = @{ Color = 'Green'; Icon = '✅' }; Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
		Error = @{ Color = 'Red'; Icon = '❌' }; Info = @{ Color = 'Cyan'; Icon = '💎' }
	}[$Type]
	Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
}
# Funzione per centrare il testo
function Center-Text($text, $width) {
	$pad = [Math]::Max(0, ($width - $text.Length) / 2)
	return (' ' * [Math]::Floor($pad)) + $text
}

# Schermata di Benvenuto ASCII
$width = 60
$ascii = @(
	' __        __  _  _   _ ',
	' \ \      / / | || \ | |',
	'  \ \ /\ / /  | ||  \| |',
	'   \ V  V /   | || |\  |',
	'    \_/\_/    |_||_| \_|',
	'                         ',
	'    Toolkits By MagnetarMan      '
)
foreach ($line in $ascii) {
	Write-StyledMessage Info (Center-Text $line $width)
}


# Menu di scelta script
$scripts = @(
	@{ Name = 'WinRepairToolkit.ps1'; Description = 'Riparazione Windows' },
	@{ Name = 'WinUpdateReset.ps1'; Description = 'Reset Windows Update' }
)

Write-StyledMessage Warning 'Seleziona lo script da avviare:'
for ($i = 0; $i -lt $scripts.Count; $i++) {
	Write-StyledMessage Info ("[$($i+1)] $($scripts[$i].Description)")
}
Write-StyledMessage Error '[0] Esci'

do {
	$choice = Read-Host 'Inserisci il numero della tua scelta'
	if ($choice -match '^[0-9]+$') {
		$choice = [int]$choice
	} else {
		$choice = -1
	}
	if ($choice -eq 0) {
	Write-StyledMessage Success 'Uscita...'
		exit
	}
	elseif ($choice -ge 1 -and $choice -le $scripts.Count) {
		$scriptName = $scripts[$choice-1].Name
		$scriptPath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ChildPath $scriptName
		if (Test-Path $scriptPath) {
		Write-StyledMessage Info "Avvio di $scriptName..."
			& $scriptPath
		} else {
		Write-StyledMessage Error "Script $scriptName non trovato."
		}
		break
	} else {
	Write-StyledMessage Error 'Scelta non valida. Riprova.'
	}
} while ($true)

# Messaggio di chiusura
Write-Host ''
# Messaggio di chiusura con scelta multipla
Write-StyledMessage Success (Center-Text 'Grazie dell''utilizzo' $width)
Write-Host ''
Write-StyledMessage Warning (Center-Text 'Cosa vuoi fare ora?' $width)
Write-StyledMessage Info (Center-Text '1) Termina il toolkit' $width)
Write-StyledMessage Info (Center-Text '2) Ritorna allo script principale' $width)
Write-StyledMessage Info (Center-Text '3) Riesegui lo script' $width)

do {
	$finalChoice = Read-Host 'Inserisci il numero della tua scelta'
	switch ($finalChoice) {
		'1' {
		Write-StyledMessage Success 'Chiusura del toolkit...'
			exit
		}
		'2' {
			$mainScript = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ChildPath 'run.ps1'
			if (Test-Path $mainScript) {
			Write-StyledMessage Info 'Ritorno allo script principale...'
				& $mainScript
			} else {
				Write-StyledMessage Error 'Script principale non trovato.'
			}
			break
		}
		'3' {
		Write-StyledMessage Info 'Riesecuzione dello script...'
			& $MyInvocation.MyCommand.Definition
			break
		}
		default {
		Write-StyledMessage Error 'Scelta non valida. Riprova.'
		}
	}
} while ($true)
