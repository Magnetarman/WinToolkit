function OutlookRepair {
    <#
.SYNOPSIS
    Automatizza la manutenzione e la riparazione dei profili di Microsoft Outlook Classic.
.DESCRIPTION
    Lo script si aggancia al profilo Outlook corrente tramite COM, distingue gli account
    cloud (Exchange/IMAP) dagli archivi locali (POP3/PST) e applica una logica di
    riparazione differenziata:
      * Account cloud -> svuota la cartella "Posta Eliminata" in modo sicuro.
      * Archivio locale PST -> avvia SCANPST.EXE (GUI, richiede interazione manuale).
.NOTES
    Nome file   : OutlookRepair.ps1
    Autore      : Ingegneria del Software e Sistemista Windows
    Versione    : 1.0.0
    Richiede    : PowerShell 5.1 o superiore, Microsoft Outlook installato.
#>

    [CmdletBinding()]
    param(
        [switch]
        # Esegue SCANPST senza attendere la chiusura della GUI.
        $NoWaitForScanPst,

        [switch]
        # Ignora i prompt di conferma e prosegue dove possibile.
        $Force
    )

    # -----------------------------------------------------------------------------
    # Inizializzazione rigida e gestione errori
    # -----------------------------------------------------------------------------
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # -----------------------------------------------------------------------------
    # Colori standard aziendali per l'output dell'operatore
    # -----------------------------------------------------------------------------
    $ColorHeader = 'Cyan'
    $ColorSuccess = 'Green'
    $ColorWarning = 'Yellow'
    $ColorDetail = 'Gray'
    $ColorError = 'Red'

    # -----------------------------------------------------------------------------
    # Percorsi standard di SCANPST.EXE (Office Click-to-Run, 64-bit e 32-bit)
    # -----------------------------------------------------------------------------
    $ScanPstCandidatePaths = @(
        "${env:ProgramFiles}\Microsoft Office\root\Office16\SCANPST.EXE",
        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\SCANPST.EXE"
    )

    # -----------------------------------------------------------------------------
    # Costanti del modello oggetto Outlook
    # -----------------------------------------------------------------------------
    $olFolderDeletedItems = 3   # Posta Eliminata
    $olStoreExchange = 1   # Exchange
    $olStoreImap = 2   # IMAP
    $olStoreExchangeOther = 3   # Exchange (variante)

    # -----------------------------------------------------------------------------
    # Variabili globali di script
    # -----------------------------------------------------------------------------
    $script:ScanPstPath = $null

    # -----------------------------------------------------------------------------
    # Helper di output colorato e coerente
    # -----------------------------------------------------------------------------
    function Write-Log {
        <#
    .SYNOPSIS
        Scrive un messaggio a schermo con il colore associato al livello.
    .PARAMETER Message
        Testo da visualizzare.
    .PARAMETER Level
        Livello di severità: Header, Success, Warning, Detail, Error.
    #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)][string]$Message,
            [ValidateSet('Header', 'Success', 'Warning', 'Detail', 'Error')]
            [string]$Level = 'Detail'
        )

        $color = switch ($Level) {
            'Header' { $ColorHeader }
            'Success' { $ColorSuccess }
            'Warning' { $ColorWarning }
            'Error' { $ColorError }
            default { $ColorDetail }
        }

        Write-Host $Message -ForegroundColor $color
    }

    # -----------------------------------------------------------------------------
    # Test-IsOutlookRunning
    # -----------------------------------------------------------------------------
    function Test-IsOutlookRunning {
        <#
    .SYNOPSIS
        Verifica se un processo OUTLOOK.EXE è attivo nel sistema.
    .RETURN VALUE
        Booleano: $true se Outlook risulta in esecuzione.
    #>
        [CmdletBinding()]
        param()

        try {
            $process = Get-Process -Name 'OUTLOOK' -ErrorAction SilentlyContinue
            return $null -ne $process
        }
        catch {
            Write-Log -Message "Impossibile verificare lo stato di Outlook: $($_.Exception.Message)" -Level Warning
            return $false
        }
    }

    # -----------------------------------------------------------------------------
    # Get-ScanPstPath
    # -----------------------------------------------------------------------------
    function Get-ScanPstPath {
        <#
    .SYNOPSIS
        Cerca l'eseguibile SCANPST.EXE nei percorsi standard di Office.
    .RETURN VALUE
        Percorso completo di SCANPST.EXE se trovato, altrimenti $null.
    #>
        [CmdletBinding()]
        param()

        foreach ($candidatePath in $ScanPstCandidatePaths) {
            try {
                if (Test-Path -LiteralPath $candidatePath -PathType Leaf -ErrorAction Stop) {
                    return $candidatePath
                }
            }
            catch {
                # Percorso non valido o inaccessibile: si prova il successivo.
            }
        }

        return $null
    }

    # -----------------------------------------------------------------------------
    # Connect-Outlook
    # -----------------------------------------------------------------------------
    function Connect-Outlook {
        <#
    .SYNOPSIS
        Si aggancia a un'istanza attiva di Outlook oppure ne avvia una nuova tramite COM.
    .RETURN VALUE
        Oggetto COM Outlook.Application, oppure $null in caso di fallimento.
    #>
        [CmdletBinding()]
        param()

        # Tentativo di aggancio a istanza già attiva
        try {
            $outlook = [Runtime.Interopservices.Marshal]::GetActiveObject('Outlook.Application')
            Write-Log -Message 'Outlook già in esecuzione: aggancio all'istanza attiva.' -Level Success
        return $outlook
    }
    catch {
        Write-Log -Message 'Outlook non in esecuzione: avvio nuova istanza COM in background...' -Level Warning
    }

    # Avvio nuova istanza COM
    try {
        $outlook = New-Object -ComObject Outlook.Application
        # Forzare l'inizializzazione del Namespace per validare l'oggetto
        $null = $outlook.GetNamespace('MAPI')
        Write-Log -Message 'Istanza COM di Outlook creata con successo.' -Level Success
        return $outlook
    }
    catch {
        Write-Log -Message "Impossibile creare l'oggetto COM di Outlook: $($_.Exception.Message)" -Level Error
        return $null
    }
}

# -----------------------------------------------------------------------------
# Release-ComObject
# -----------------------------------------------------------------------------
function Release-ComObject {
    <#
    .SYNOPSIS
        Rilascia in modo pulito un oggetto COM per evitare processi zombie.
    .PARAMETER ComObject
        Oggetto COM da rilasciare.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$ComObject
    )

    if ($null -eq $ComObject) { return }

    try {
        while ([System.Runtime.Interopservices.Marshal]::ReleaseComObject($ComObject) -gt 0) {
            # Ciclo di rilascio completo dei riferimenti COM
        }
    }
    catch {
        # Errori di release non bloccanti: l'oggetto potrebbe essere già rilasciato.
    }

    [System.Runtime.Interopservices.Marshal]::FinalReleaseComObject($ComObject) 2>$null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

# -----------------------------------------------------------------------------
# Repair-CloudAccount
# -----------------------------------------------------------------------------
function Repair-CloudAccount {
    <#
    .SYNOPSIS
        Esegue l'approccio aggressivo e sicuro per account cloud (Exchange/IMAP).
        Svuota la cartella "Posta Eliminata" dello store specificato.
    .PARAMETER Store
        Oggetto Store di Outlook da trattare.
    .PARAMETER Namespace
        Oggetto Namespace MAPI di Outlook.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][object]$Namespace
    )

    $storeName = $null
    try { $storeName = $Store.DisplayName } catch { $storeName = 'Sconosciuto' }

    try {
        Write-Log -Message "[$storeName] Account cloud (Exchange/IMAP): avvio pulizia cache locale." -Level Header

        # Accesso alla cartella predefinita "Posta Eliminata"
        $deletedFolder = $null
        try {
            $deletedFolder = $Namespace.GetDefaultFolder($olFolderDeletedItems)
        }
        catch {
            Write-Log -Message "[$storeName] Impossibile accedere alla cartella 'Posta Eliminata': $($_.Exception.Message)" -Level Warning
            return
        }

        if ($null -eq $deletedFolder) {
            Write-Log -Message "[$storeName] Cartella 'Posta Eliminata' non disponibile, salto." -Level Warning
            return
        }

        $items = $null
        try {
            $items = $deletedFolder.Items
        }
        catch {
            Write-Log -Message "[$storeName] Impossibile enumerare gli elementi di 'Posta Eliminata': $($_.Exception.Message)" -Level Warning
            Release-ComObject -ComObject $deletedFolder
            return
        }

        $itemCount = 0
        try { $itemCount = $items.Count } catch { $itemCount = 0 }

        if ($itemCount -eq 0) {
            Write-Log -Message "[$storeName] 'Posta Eliminata' già vuota." -Level Success
            Release-ComObject -ComObject $items
            Release-ComObject -ComObject $deletedFolder
            return
        }

        Write-Log -Message "[$storeName] Trovati $itemCount elementi da rimuovere definitivamente." -Level Detail

        # Ciclo inverso per preservare la validità degli indici durante la rimozione
        for ($i = $itemCount; $i -ge 1; $i--) {
            $item = $null
            try {
                $item = $items.Item($i)
                $item.Delete()
            }
            catch {
                Write-Log -Message "[$storeName] Impossibile eliminare l'elemento $i: $($_.Exception.Message)" -Level Warning
            }
            finally {
                if ($null -ne $item) {
                    Release-ComObject -ComObject $item
                }
            }
        }

        Write-Log -Message "[$storeName] Pulizia di 'Posta Eliminata' completata." -Level Success
    }
    catch {
        Write-Log -Message "[$storeName] Errore critico durante la pulizia cloud: $($_.Exception.Message)" -Level Error
    }
    finally {
        if ($null -ne $items) { Release-ComObject -ComObject $items }
        if ($null -ne $deletedFolder) { Release-ComObject -ComObject $deletedFolder }
    }
}

# -----------------------------------------------------------------------------
# Repair-Pop3PstAccount
# -----------------------------------------------------------------------------
function Repair-Pop3PstAccount {
    <#
    .SYNOPSIS
        Esegue l'approccio conservativo per archivi locali (POP3/PST).
            Verifica il file PST e, se disponibile, avvia SCANPST.EXE.
            .PARAMETER Store
            Oggetto Store di Outlook da trattare.
            .PARAMETER ScanPstPath
            Percorso di SCANPST.EXE, o $null se non trovato.
            #>
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true)][object]$Store,
                [string]$ScanPstPath
            )

            $storeName = $null
            try { $storeName = $Store.DisplayName } catch { $storeName = 'Sconosciuto' }

            try {
                Write-Log -Message "[$storeName] Archivio locale (POP3/PST): approccio conservativo attivato." -Level Warning

                # Estrazione del percorso fisico del file PST
                $pstPath = $null
                try {
                    $pstPath = $Store.FilePath
                }
                catch {
                    Write-Log -Message "[$storeName] Impossibile ottenere il percorso del file PST dallo store." -Level Warning
                    return
                }

                if ([string]::IsNullOrWhiteSpace($pstPath)) {
                    Write-Log -Message "[$storeName] Percorso PST vuoto, salto per sicurezza." -Level Warning
                    return
                }

                # Zero False Positivi: il file deve esistere e avere estensione .pst
                if (-not (Test-Path -LiteralPath $pstPath -PathType Leaf -ErrorAction SilentlyContinue)) {
                    Write-Log -Message "[$storeName] File PST non trovato sul disco: $pstPath" -Level Warning
                    return
                }

                if (-not $pstPath.EndsWith('.pst', [System.StringComparison]::OrdinalIgnoreCase)) {
                    Write-Log -Message "[$storeName] Estensione non PST rilevata ($pstPath): salto per evitare falsi positivi." -Level Warning
                    return
                }

                Write-Log -Message "[$storeName] File PST individuato: $pstPath" -Level Detail

                if (-not $ScanPstPath) {
                    Write-Log -Message "[$storeName] SCANPST.EXE non disponibile: impossibile avviare la riparazione PST." -Level Warning
                    return
                }

                # Avvio SCANPST.EXE. La GUI richiede il clic manuale su "Avvia" per restrizioni Microsoft.
                Write-Log -Message "[$storeName] Avvio SCANPST.EXE per il file: $pstPath" -Level Header
                Write-Log -Message 'NOTA: la finestra di SCANPST si apre e richiede il clic manuale sul pulsante "Avvia".' -Level Warning

                $arguments = "-file `"$pstPath`""
                try {
                    $process = Start-Process -FilePath $ScanPstPath -ArgumentList $arguments -PassThru -ErrorAction Stop
                    Write-Log -Message "[$storeName] SCANPST.EXE avviato (PID $($process.Id))." -Level Success

                    if (-not $NoWaitForScanPst) {
                        Write-Log -Message 'Attendere il termine della riparazione prima di chiudere lo script.' -Level Detail
                    }
                }
                catch {
                    Write-Log -Message "[$storeName] Impossibile avviare SCANPST.EXE: $($_.Exception.Message)" -Level Error
                }
            }
            catch {
                Write-Log -Message "[$storeName] Errore durante la gestione dell'archivio PST: $($_.Exception.Message)" -Level Error
            }
        }

        # -----------------------------------------------------------------------------
        # Flusso principale
        # -----------------------------------------------------------------------------
        try {
            Write-Log -Message '========================================' -Level Header
            Write-Log -Message 'Outlook Classic Repair Tool' -Level Header
            Write-Log -Message "Versione: 1.0.0 | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Detail
            Write-Log -Message '========================================' -Level Header

            # 1. Inizializzazione e ricerca di SCANPST.EXE
            Write-Log -Message '[1/6] Ricerca di SCANPST.EXE...' -Level Header
            $script:ScanPstPath = Get-ScanPstPath
            if ($null -eq $script:ScanPstPath) {
                Write-Log -Message 'SCANPST.EXE non trovato nei percorsi standard. La pulizia IMAP/Exchange procederà comunque.' -Level Warning
            }
            else {
                Write-Log -Message "SCANPST.EXE trovato: $script:ScanPstPath" -Level Success
            }

            # 2. Aggancio all'interfaccia COM di Outlook
            Write-Log -Message '[2/6] Connessione a Outlook (COM)...' -Level Header
            $outlook = Connect-Outlook
            if ($null -eq $outlook) {
                Write-Log -Message 'Impossibile proseguire senza un oggetto COM di Outlook valido.' -Level Error
                exit 1
            }

            # 3. Recupero del Namespace MAPI
            Write-Log -Message '[3/6] Recupero del Namespace MAPI...' -Level Header
            $namespace = $null
            try {
                $namespace = $outlook.GetNamespace('MAPI')
                Write-Log -Message 'Namespace MAPI ottenuto con successo.' -Level Success
            }
            catch {
                Write-Log -Message "Impossibile ottenere il Namespace MAPI: $($_.Exception.Message)" -Level Error
                Release-ComObject -ComObject $outlook
                exit 1
            }

            # 4-5. Ciclo di scansione degli Store e ramo di riparazione differenziato
            Write-Log -Message '[4-5/6] Scansione degli Store configurati...' -Level Header
            $stores = $null
            try {
                $stores = $namespace.Stores
            }
            catch {
                Write-Log -Message "Impossibile accedere alla raccolta Stores: $($_.Exception.Message)" -Level Error
                Release-ComObject -ComObject $namespace
                Release-ComObject -ComObject $outlook
                exit 1
            }

            $storeCount = 0
            try { $storeCount = $stores.Count } catch { $storeCount = 0 }
            Write-Log -Message "Store configurati nel profilo corrente: $storeCount" -Level Detail

            for ($i = 1; $i -le $storeCount; $i++) {
                $store = $null
                try {
                    $store = $stores.Item($i)
                }
                catch {
                    Write-Log -Message "Impossibile accedere allo store $i, salto." -Level Warning
                    continue
                }

                $storeType = -1
                try {
                    $storeType = $store.ExchangeStoreType
                }
                catch {
                    # Proprietà non disponibile: trattiamo come archivio locale sconosciuto.
                }

                Write-Log -Message "--- Store [$i]: $($store.DisplayName) | ExchangeStoreType=$storeType ---" -Level Detail

                # Ramo A: account cloud (Exchange = 1 o 3, IMAP = 2)
                if ($storeType -in @($olStoreExchange, $olStoreImap, $olStoreExchangeOther)) {
                    Repair-CloudAccount -Store $store -Namespace $namespace
                }
                # Ramo B: archivio locale (POP3/PST = 0 o altri valori)
                else {
                    Repair-Pop3PstAccount -Store $store -ScanPstPath $script:ScanPstPath
                }

                Release-ComObject -ComObject $store
            }

            # 6. Chiusura pulita e garbage collection
            Write-Log -Message '[6/6] Rilascio oggetti COM e chiusura...' -Level Header
            Release-ComObject -ComObject $namespace
            Release-ComObject -ComObject $outlook

            Write-Log -Message 'Operazione completata con successo.' -Level Success
            Write-Log -Message '========================================' -Level Header
        }
        catch {
            Write-Log -Message "Errore critico non gestito: $($_.Exception.Message)" -Level Error
            exit 1
        }

    }