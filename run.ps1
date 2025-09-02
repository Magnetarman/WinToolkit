# Set PowerShell window title
$Host.UI.RawUI.WindowTitle = "Win Toolkits by MagnetarMan"

# Imposto la ExecutionPolicy per l'utente corrente per permettere l'esecuzione degli script

# Funzione per messaggi stilizzati
function Write-StyledMessage([string]$Type, [string]$Text) {
	$style = @{
		Success = @{ Color = 'Green'; Icon = '[OK]' }; Warning = @{ Color = 'Yellow'; Icon = '[!]' }
		Error = @{ Color = 'Red'; Icon = '[X]' }; Info = @{ Color = 'Cyan'; Icon = '[i]' }
	}[$Type]
	Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
}

# Funzione per centrare il testo (disponibile subito)
function Center-Text($text, $width) {
	$pad = [Math]::Max(0, ($width - $text.Length) / 2)
	return (' ' * [Math]::Floor($pad)) + $text
}

function powershell-update {
	Write-Host "[i] Controllo aggiornamenti PowerShell..." -ForegroundColor Cyan
	$pwshExe = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
	$isPwshInstalled = Test-Path $pwshExe
	if (-not $isPwshInstalled) {
		Write-StyledMessage Info 'PowerShell 7 non trovato. Download in corso...'
		$installerUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/PowerShell-7.5.2-win-x64.msi"
		$installerPath = Join-Path $env:TEMP 'PowerShell-7-latest.msi'
		# Forza TLS1.2 per GitHub
		try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
		try {
			$wc = New-Object System.Net.WebClient
			$wc.Headers.Add('User-Agent','Mozilla/5.0')
			$wc.DownloadFile($installerUrl, $installerPath)
		} catch {
			# Fallback a Invoke-WebRequest con header se WebClient fallisce
			try {
				Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing -Headers @{ 'User-Agent' = 'Mozilla/5.0' } -ErrorAction Stop
			} catch {
				Write-StyledMessage Error "Download PowerShell con WebClient/Invoke-WebRequest fallito: $_"
			}
		}
		# Ulteriore fallback con BITS se il file non esiste
		if (-not (Test-Path $installerPath)) {
			try {
				Write-StyledMessage Info 'Tentativo di download con BITS...'
				Start-BitsTransfer -Source $installerUrl -Destination $installerPath -ErrorAction Stop
			} catch {
				Write-StyledMessage Error "Download PowerShell non riuscito (BITS): $_"
			}
		}
		if (Test-Path $installerPath) {
			Write-StyledMessage Info 'Installazione di PowerShell 7...'
			Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /qn" -Wait
		} else {
			Write-StyledMessage Error 'Installazione saltata: file di installazione non trovato.'
		}
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
	# Se PowerShell 7 è installato E la versione corrente è più vecchia, rilancia lo script
if ((Test-Path $pwshExe) -and ($PSVersionTable.PSVersion.Major -lt 7)) {
    Write-Host "[OK] PowerShell 7 rilevato. Riavvio script con la versione corretta..." -ForegroundColor Green
    Start-Process -FilePath $pwshExe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# Questo messaggio verrà mostrato solo se l'aggiornamento è fallito e PS7 non è stato trovato
if (-not (Test-Path $pwshExe)) {
    Write-Host "[X] Aggiornamento PowerShell fallito o PowerShell 7 non trovato." -ForegroundColor Red
}
}

# Esegui subito il controllo/aggiornamento PowerShell all'avvio
powershell-update

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
