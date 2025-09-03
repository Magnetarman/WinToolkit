#Requires -Version 5.0
<#
.SYNOPSIS
Script di setup automatico per PowerShell 7 e profilo Chris Titus Tech.

.DESCRIPTION
Questo script:
1. Verifica la versione di PowerShell in uso
2. Installa PowerShell 7 se necessario
3. Verifica i privilegi di amministratore
4. Installa il profilo PowerShell di Chris Titus Tech
5. Avvia lo script WinStarter.ps1
#>

# ============================================================================
# FUNZIONI DI UTILITÀ
# ============================================================================

$Host.UI.RawUI.WindowTitle = "Win Toolkits by MagnetarMan"
function Write-StyledMessage {
    <#
    .SYNOPSIS
    Scrive un messaggio formattato sulla console con icone e colori.
    .PARAMETER Type
    Il tipo di messaggio (Success, Warning, Error, Info).
    .PARAMETER Text
    Il testo del messaggio da visualizzare.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Warning', 'Error', 'Info')]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    # Definisce gli stili per ogni tipo di messaggio. L'uso di simboli migliora la leggibilità.
    $styles = @{
        Success = @{ Color = 'Green' ; Icon = '[OK]' }
        Warning = @{ Color = 'Yellow'; Icon = '[!]' }  
        Error   = @{ Color = 'Red'   ; Icon = '[X]' }
        Info    = @{ Color = 'Cyan'  ; Icon = '[i]' }
    }

    $style = $styles[$Type]
    Write-Host "$($style.Icon) $($Text)" -ForegroundColor $style.Color
}

function Center-Text {
    <#
    .SYNOPSIS
    Centra una stringa di testo data una larghezza specifica.
    .PARAMETER Text
    Il testo da centrare.
    .PARAMETER Width
    La larghezza totale del contenitore.
    #>
    param(
        [string]$Text,
        [int]$Width = 60
    )

    if ($Text.Length -ge $Width) { return $Text }

    $padding = ' ' * [Math]::Floor(($Width - $Text.Length) / 2)
    return "$($padding)$($Text)"
}

function Test-AdminPrivileges {
    <#
    .SYNOPSIS
    Verifica se lo script è eseguito con privilegi di amministratore.
    .OUTPUTS
    [bool] True se eseguito come amministratore, False altrimenti.
    #>
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante la verifica dei privilegi: $($_.Exception.Message)"
        return $false
    }
}

function Install-PowerShell7 {
    <#
    .SYNOPSIS
    Installa l'ultima versione di PowerShell 7.
    #>
    try {
        Write-StyledMessage -Type 'Info' -Text "Avvio installazione PowerShell 7..."
        
        # Scarica e installa PowerShell 7 tramite winget se disponibile
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type 'Info' -Text "Utilizzando winget per l'installazione..."
            winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements
        }
        else {
            # Fallback: usa il metodo di installazione tradizionale
            Write-StyledMessage -Type 'Info' -Text "Scaricamento PowerShell 7 dal repository ufficiale..."
            Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
        }
        
        Write-StyledMessage -Type 'Success' -Text "PowerShell 7 installato con successo!"
        return $true
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante l'installazione di PowerShell 7: $($_.Exception.Message)"
        return $false
    }
}

function Install-CTTPowerShellProfile {
    <#
    .SYNOPSIS
    Installa il profilo PowerShell di Chris Titus Tech.
    #>
    try {
        Write-StyledMessage -Type 'Info' -Text "Installazione profilo PowerShell Chris Titus Tech..."
        
        # Crea directory del profilo se non esiste (PRIMA di tutto)
        $profileDir = Split-Path $PROFILE -Parent
        if (!(Test-Path $profileDir)) {
            Write-StyledMessage -Type 'Info' -Text "Creazione directory profilo: $profileDir"
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        
        # URL del profilo di Chris Titus Tech
        $profileUrl = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        $setupUrl = "https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1"
        
        # Ottieni hash del profilo corrente
        $oldHash = $null
        if (Test-Path $PROFILE) {
            $oldHash = Get-FileHash $PROFILE -ErrorAction SilentlyContinue
        }
        
        # Scarica il nuovo profilo
        $tempProfile = "$env:TEMP\Microsoft.PowerShell_profile.ps1"
        Write-StyledMessage -Type 'Info' -Text "Download profilo da GitHub..."
        Invoke-RestMethod $profileUrl -OutFile $tempProfile
        
        # Ottieni hash del nuovo profilo
        $newHash = Get-FileHash $tempProfile
        
        # Controlla se è necessario aggiornare
        if ($oldHash -eq $null -or $newHash.Hash -ne $oldHash.Hash) {
            
            # Backup del profilo esistente
            if ((Test-Path $PROFILE) -and !(Test-Path "$PROFILE.bak")) {
                Write-StyledMessage -Type 'Warning' -Text "Creazione backup del profilo esistente..."
                Copy-Item -Path $PROFILE -Destination "$PROFILE.bak"
                Write-StyledMessage -Type 'Success' -Text "Backup profilo completato"
            }
            
            Write-StyledMessage -Type 'Info' -Text "Installazione del nuovo profilo..."
            
            # Esegui setup in background - modifica per compatibilità con PS5/7
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                Write-StyledMessage -Type 'Info' -Text "Esecuzione setup con PowerShell 7..."
                $setupProcess = Start-Process -FilePath "pwsh" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"Invoke-Expression (Invoke-WebRequest '$setupUrl').Content`"" -WindowStyle Hidden -PassThru
            } else {
                Write-StyledMessage -Type 'Info' -Text "Esecuzione setup con PowerShell 5..."
                $setupProcess = Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"Invoke-Expression (Invoke-WebRequest '$setupUrl').Content`"" -WindowStyle Hidden -PassThru
            }
            
            # Attendi completamento con timeout
            $timeout = 120 # 2 minuti
            Write-StyledMessage -Type 'Info' -Text "Attesa completamento setup (max $timeout secondi)..."
            
            if ($setupProcess.WaitForExit($timeout * 1000)) {
                Write-StyledMessage -Type 'Success' -Text "Setup profilo completato!"
                
                # Salva hash del nuovo profilo DOPO l'installazione
                try {
                    $newHash.Hash | Out-File "$PROFILE.hash" -Encoding UTF8
                    Write-StyledMessage -Type 'Info' -Text "Hash profilo salvato"
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Impossibile salvare hash profilo: $($_.Exception.Message)"
                }
                
                Write-StyledMessage -Type 'Info' -Text "Riavviare PowerShell per applicare le modifiche"
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "Timeout durante setup. Tentativo installazione manuale..."
                try {
                    $setupProcess.Kill()
                }
                catch { }
                
                # Tentativo di installazione manuale diretta
                try {
                    Write-StyledMessage -Type 'Info' -Text "Installazione diretta del profilo..."
                    Copy-Item $tempProfile $PROFILE -Force
                    Write-StyledMessage -Type 'Success' -Text "Profilo copiato direttamente"
                }
                catch {
                    Write-StyledMessage -Type 'Error' -Text "Errore nella copia diretta: $($_.Exception.Message)"
                    return $false
                }
            }
        }
        else {
            Write-StyledMessage -Type 'Info' -Text "Il profilo è già aggiornato"
        }
        
        return $true
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante l'installazione del profilo: $($_.Exception.Message)"
        Write-StyledMessage -Type 'Info' -Text "Dettagli errore: $($_.Exception.StackTrace)"
        return $false
    }
}

function Start-WinStarterScript {
    <#
    .SYNOPSIS
    Avvia lo script WinStarter.ps1 dalla sottocartella tool.
    #>
    try {
        # Determina il percorso dello script corrente
        $currentPath = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
        $winStarterPath = Join-Path $currentPath "tool\WinStarter.ps1"
        
        if (Test-Path $winStarterPath) {
            Write-StyledMessage -Type 'Success' -Text "Avvio WinStarter.ps1..."
            
            # Avvia WinStarter con privilegi amministratore in PowerShell 7
            if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
                Start-Process -FilePath "pwsh" -ArgumentList "-ExecutionPolicy Bypass -File `"$winStarterPath`"" -Verb RunAs
            } else {
                Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy Bypass -File `"$winStarterPath`"" -Verb RunAs
            }
            
            Write-StyledMessage -Type 'Info' -Text "WinStarter.ps1 avviato con successo!"
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "File WinStarter.ps1 non trovato in: $winStarterPath"
            return $false
        }
        
        return $true
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore durante l'avvio di WinStarter.ps1: $($_.Exception.Message)"
        return $false
    }
}

function Request-AdminRestart {
    <#
    .SYNOPSIS
    Richiede il riavvio dello script con privilegi amministratore.
    #>
    Write-StyledMessage -Type 'Warning' -Text "Questo script richiede privilegi di amministratore per funzionare correttamente."
    Write-StyledMessage -Type 'Info' -Text "Premere un tasto per riavviare con privilegi elevati..."
    
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    try {
        # Riavvia lo script corrente con privilegi amministratore
        $currentScript = $MyInvocation.MyCommand.Path
        if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
            Start-Process -FilePath "pwsh" -ArgumentList "-ExecutionPolicy Bypass -File `"$currentScript`"" -Verb RunAs
        } else {
            Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy Bypass -File `"$currentScript`"" -Verb RunAs
        }
        exit
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Impossibile riavviare con privilegi amministratore: $($_.Exception.Message)"
        Write-StyledMessage -Type 'Info' -Text "Riavviare manualmente PowerShell come amministratore ed eseguire nuovamente lo script."
        Read-Host "Premere Invio per uscire"
        exit 1
    }
}

# ============================================================================
# LOGICA PRINCIPALE
# ============================================================================

function Main {
    <#
    .SYNOPSIS
    Funzione principale dello script.
    #>
    
    # Banner iniziale
    Clear-Host
    Write-Host ""
    Write-Host (Center-Text "=====================================" 70) -ForegroundColor Magenta
    Write-Host (Center-Text "POWERSHELL 7 SETUP & PROFILE INSTALLER" 70) -ForegroundColor Magenta
    Write-Host (Center-Text "=====================================" 70) -ForegroundColor Magenta
    Write-Host ""
    
    # Verifica versione PowerShell
    $psVersion = $PSVersionTable.PSVersion.Major
    Write-StyledMessage -Type 'Info' -Text "Versione PowerShell rilevata: $($PSVersionTable.PSVersion)"
    
    if ($psVersion -lt 7) {
        # OPZIONE 1: PowerShell 5 - Installa PowerShell 7
        Write-StyledMessage -Type 'Warning' -Text "PowerShell 5 rilevato. Installazione PowerShell 7 richiesta."
        
        if (Install-PowerShell7) {
            Write-StyledMessage -Type 'Success' -Text "PowerShell 7 installato. Riavvio dello script..."
            Write-StyledMessage -Type 'Info' -Text "Attendere 5 secondi per il riavvio..."
            Start-Sleep -Seconds 5
            
            # Riavvia lo script con PowerShell 7
            try {
                $currentScript = $MyInvocation.MyCommand.Path
                
                # Verifica se pwsh è ora disponibile
                $pwshPath = $null
                $possiblePaths = @(
                    "pwsh",
                    "$env:ProgramFiles\PowerShell\7\pwsh.exe",
                    "$env:ProgramFiles\PowerShell\7-preview\pwsh.exe"
                )
                
                foreach ($path in $possiblePaths) {
                    try {
                        if ($path -eq "pwsh") {
                            if (Get-Command pwsh -ErrorAction SilentlyContinue) {
                                $pwshPath = "pwsh"
                                break
                            }
                        } else {
                            if (Test-Path $path) {
                                $pwshPath = $path
                                break
                            }
                        }
                    } catch { continue }
                }
                
                if ($pwshPath) {
                    Write-StyledMessage -Type 'Info' -Text "Utilizzando PowerShell 7 da: $pwshPath"
                    Start-Process -FilePath $pwshPath -ArgumentList "-ExecutionPolicy Bypass -File `"$currentScript`"" -Verb RunAs
                    Write-StyledMessage -Type 'Info' -Text "Nuova sessione PowerShell 7 avviata. Questo script terminerà ora."
                    Start-Sleep -Seconds 2
                } else {
                    Write-StyledMessage -Type 'Error' -Text "PowerShell 7 installato ma non trovato. Riavviare manualmente."
                    Write-StyledMessage -Type 'Info' -Text "Premere un tasto per uscire..."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
                exit
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Errore nel riavvio: $($_.Exception.Message)"
                Read-Host "Premere Invio per uscire"
                exit 1
            }
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Installazione PowerShell 7 fallita."
            Read-Host "Premere Invio per uscire"
            exit 1
        }
    }
    else {
        # OPZIONE 2: PowerShell 7 - Verifica privilegi amministratore
        Write-StyledMessage -Type 'Success' -Text "PowerShell 7 rilevato."
        
        if (!(Test-AdminPrivileges)) {
            Request-AdminRestart
            return
        }
        
        Write-StyledMessage -Type 'Success' -Text "Privilegi amministratore confermati."
        
        # Installa profilo Chris Titus Tech
        if (Install-CTTPowerShellProfile) {
            Write-StyledMessage -Type 'Success' -Text "Setup profilo PowerShell completato."
            
            # Avvia WinStarter.ps1
            Start-Sleep -Seconds 2
            if (Start-WinStarterScript) {
                Write-StyledMessage -Type 'Success' -Text "Setup completato con successo!"
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text "Setup profilo completato, ma errore nell'avvio di WinStarter.ps1"
            }
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Errore durante l'installazione del profilo."
        }
    }
    
    Write-Host ""
    Write-StyledMessage -Type 'Info' -Text "Operazione completata. Premere un tasto per uscire..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ============================================================================
# ESECUZIONE
# ============================================================================

# Gestione errori globale
trap {
    Write-StyledMessage -Type 'Error' -Text "Errore critico: $($_.Exception.Message)"
    Write-StyledMessage -Type 'Error' -Text "Linea: $($_.InvocationInfo.ScriptLineNumber)"
    Read-Host "Premere Invio per uscire"
    exit 1
}

# Avvia script
Main