# SyncSQL-MasterToSlave.ps1


# --------------------------------------------------------
#               Chargement fichier .ini
# --------------------------------------------------------

function LoadIni {
	# initialisation variables liste des logs
	$script:pathfilelog = @()
	$script:pathfileerr = @()
	$script:pathfileina = @()
	$script:pathfiledlt = @()
	$script:pathfilemod = @()
	
	# sections de base du fichier .ini
	$script:cfg = @{
        "start"                   = @{}
        "intf"                    = @{}
        "email"                   = @{}
    }
    # Recuperation des parametres passes au script 
    $script:execok  = $false

    if (-not(Test-Path $($script:cfgFile) -PathType Leaf)) { Write-Host "Fichier de parametrage $script:cfgFile innexistant"; exit 1 }
    Write-Host "Fichier de parametrage $script:cfgFile"

    # Initialisation des sections parametres.
    $script:start    = [System.Diagnostics.Stopwatch]::startNew()
    $script:MailErr  = $false
    $script:WARNING  = 0
    $script:ERREUR   = 0
	
	$script:emailtxt = New-Object 'System.Collections.Generic.List[string]'

	$script:cfg = Add-IniFiles $script:cfg $script:cfgFile

	# Recherche des chemins de tous les fichiers et verification de leur existence
	if (-not ($script:cfg["intf"].ContainsKey("rootpath")) ) {
		$script:cfg["intf"]["rootpath"] = $PSScriptRoot
	}
	$script:cfg["intf"]["pathfilelog"] 	= GetFilePath $script:cfg["intf"]["pathfilelog"]
	$script:cfg["intf"]["pathfileerr"]	= GetFilePath $script:cfg["intf"]["pathfileerr"]
	$script:cfg["intf"]["pathfilemod"]  = GetFilePath $script:cfg["intf"]["pathfilemod"]

	# Suppression des fichiers One_Shot
	if ((Test-Path $($script:cfg["intf"]["pathfilelog"]) -PathType Leaf)) { Remove-Item -Path $script:cfg["intf"]["pathfilelog"]}    

	# Création des fichiers innexistants
	$null = New-Item -type file $($script:cfg["intf"]["pathfilelog"]) -Force;
	if (-not(Test-Path $($script:cfg["intf"]["pathfileerr"]) -PathType Leaf)) { $null = New-Item -type file $($script:cfg["intf"]["pathfileerr"]) -Force; }
	if (-not(Test-Path $($script:cfg["intf"]["pathfilemod"]) -PathType Leaf)) { $null = New-Item -type file $($script:cfg["intf"]["pathfilemod"]) -Force; }
}
function Query_BDD_MASTER {
    $script:Master = Get-BDDConnectionParams "SQL_Master"
	$script:BDDMASTER = @{}
	
	# Récupération de la liste des tables à synchroniser
	$tables = $script:Master.table -split ','
	
	foreach ($table in $tables) {
		$table = $table.Trim()
		LOG "Query_BDD_MASTER" "Traitement de la table Master: $table"
		
		# Création d'une copie des paramètres avec la table spécifique
		$tableParams = $script:Master.Clone()
		$tableParams.table = $table
		
		# Initialisation de la hashtable pour cette table si elle n'existe pas
		if (-not $script:BDDMASTER.ContainsKey($table)) {
			$script:BDDMASTER[$table] = @{}
		}
		
		Query_BDDTable -params $tableParams -functionName "Query_BDD_MASTER" -keyColumns @("ID") -targetVariable $script:BDDMASTER[$table] -UseFrmtDateOUT
	}
}

function Query_BDD_SLAVE {
    $script:Slave = Get-BDDConnectionParams "SQL_Slave"
	$script:BDDSLAVE = @{}
	
	# Récupération de la liste des tables à synchroniser
	$tables = $script:Slave.table -split ','
	
	foreach ($table in $tables) {
		$table = $table.Trim()
		LOG "Query_BDD_SLAVE" "Traitement de la table Slave: $table"
		
		# Création d'une copie des paramètres avec la table spécifique
		$tableParams = $script:Slave.Clone()
		$tableParams.table = $table
		
		# Initialisation de la hashtable pour cette table si elle n'existe pas
		if (-not $script:BDDSLAVE.ContainsKey($table)) {
			$script:BDDSLAVE[$table] = @{}
		}
		
		Query_BDDTable -params $tableParams -functionName "Query_BDD_SLAVE" -keyColumns @("ID") -targetVariable $script:BDDSLAVE[$table] -UseFrmtDateOUT
	}
}

function Update_BDD_SLAVE {
	# Récupération de la liste des tables à synchroniser
	$tables = $script:Slave.table -split ','
	
	foreach ($table in $tables) {
		$table = $table.Trim()
		
		# Vérification que les données existent pour cette table
		if ($script:BDDMASTER.ContainsKey($table) -and $script:BDDSLAVE.ContainsKey($table)) {
			Update_BDDTable $script:BDDMASTER[$table] $script:BDDSLAVE[$table] @("ID") $table "Update_BDD_SLAVE" { 
				# Recharger uniquement cette table spécifique
				$tableParams = $script:Slave.Clone()
				$tableParams.table = $table
				Query_BDDTable -params $tableParams -functionName "Update_BDD_SLAVE" -keyColumns @("ID") -targetVariable $script:BDDSLAVE[$table] -UseFrmtDateOUT
			}
		} else {
			WRN "Update_BDD_SLAVE" "Données manquantes pour la table $table - synchronisation ignorée"
		}
	}
}

function Get-BDDConnectionParams {
    param ($section)
    return @{
        server      = $script:cfg[$section]["server"]
        database    = $script:cfg[$section]["database"]
        login       = $script:cfg[$section]["login"]
        table       = $script:cfg[$section]["table"]
        password    = Encode $script:cfg[$section]["password"]
        datefrmtout = $script:cfg[$section]["SQLformatDate"]
    }
}

# Fonction utilitaire pour effectuer une requête BDD standard
function Query_BDDTable {
    param(
        [hashtable]$params,
        [string]$functionName,
        [array]$keyColumns,
        [hashtable]$targetVariable,
        [switch]$UseFrmtDateOUT
    )
    
    LOG $functionName "Chargement de la table [$($params.table)] en memoire" -CRLF
    
    # Vider la hashtable cible
    $targetVariable.Clear()
    
    # Paramètres pour QueryTable
    $queryParams = @{
        server = $params.server
        database = $params.database
        table = $params.table
        login = $params.login
        password = $params.password
        keycolumns = $keyColumns
    }
    
    # Ajouter le format de date si demandé
    if ($UseFrmtDateOUT) {
        $queryParams.frmtdateOUT = $params.datefrmtout
    }
    
    # Exécuter la requête et affecter le résultat
    $result = QueryTable @queryParams
    
    # Copier le résultat dans la variable cible
    foreach ($key in $result.Keys) {
        $targetVariable[$key] = $result[$key]
    }
}
# Fonction utilitaire pour effectuer une mise à jour BDD standard
function Update_BDDTable {
    param(
        [hashtable]$sourceData,
        [hashtable]$targetData,
        [array]$keyColumns,
        [string]$tableName,
        [string]$functionName,
        [scriptblock]$reloadFunction
    )
    
    $params = Get-BDDConnectionParams "SQL_Slave"
    
    LOG $functionName "Update de la table $tableName" -CRLF
    
	if ( $script:cfg["SQL_Slave"]["AllowDelete"] -eq 'yes' ) {
    	UpdateTable $sourceData $targetData $keyColumns $params.server $params.database $tableName $params.login $params.password $script:cfg["start"]["ApplyUpdate"] -allowDelete
	} else {
    	UpdateTable $sourceData $targetData $keyColumns $params.server $params.database $tableName $params.login $params.password $script:cfg["start"]["ApplyUpdate"]
	}
    # Recharger les modifs en memoire
    if ($reloadFunction) {
        & $reloadFunction
    }
}
# --------------------------------------------------------
#               Main
# --------------------------------------------------------

# Chargement des modules
. "$PSScriptRoot\Modules\Ini.ps1" > $null 
. "$PSScriptRoot\Modules\Log.ps1" > $null 
. "$PSScriptRoot\Modules\Encode.ps1"     > $null 
. "$PSScriptRoot\Modules\SendEmail.ps1"  > $null 
. "$PSScriptRoot\Modules\StrConvert.ps1" > $null  

# Détermination du fichier de configuration
if ($args.Count -gt 0 -and $args[0]) {
    # Si un paramètre est passé, l'utiliser comme nom du fichier .ini
    $script:cfgFile = "$PSScriptRoot\$($args[0])"
} else {
    # Sinon, utiliser le nom du script avec l'extension .ini
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
    $script:cfgFile = "$PSScriptRoot\$scriptName.ini"
}

LoadIni

SetConsoleToUFT8

Add-Type -AssemblyName System.Web

. "$PSScriptRoot\Modules\SQL - Transaction.ps1" > $null
if ($script:cfg["start"]["TransacSQL"] -eq "AllInOne" ) {
	. "$PSScriptRoot\Modules\SQLServer - TransactionAllInOne.ps1" > $null
} else {
	. "$PSScriptRoot\Modules\SQLServer - TransactionOneByOne.ps1" > $null
}

LOG "MAIN" "Synchronisation SQL >> SQL" -CRLF...

Query_BDD_MASTER
Query_BDD_SLAVE
Update_BDD_SLAVE

QUIT "MAIN" "Process terminé"


