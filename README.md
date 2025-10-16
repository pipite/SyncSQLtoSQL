# Vue d'ensemble

**SyncSQLtoSQL.ps1** est un script PowerShell de synchronisation de bases de données SQL Server

Le script synchronise les données entre une base de données maître (source) et une base de données esclave (destination).

* Source de données provenant de bases de données **SQL Server**
* Synchronise les tables spécifiées entre les deux bases
* Gère les opérations d'insertion, mise à jour et suppression
* Supporte deux modes de transaction : **OneByOne** ou **AllInOne**
* Nécessite **PowerShell 7 ou supérieur**

## Comment installer ce script

* PowerShell 7 ou supérieur
* Accès à la base de données SQL Server

Recuperer le script sur GitLAB, et déposer les fichiers dans un répertoire du serveur de Script.

### Modules externes

Recuperer les modules nécessaire sur GitLAB, et les déposer dans le répertoire Modules du script.

* **Ini.ps1** : Gestion des fichiers de configuration .ini
* **Log.ps1** : Gestion des logs et messages (LOG, ERR, WRN, DBG, MOD)
* **Encode.ps1** : Encodage/décodage des mots de passe
* **SendEmail.ps1** : Envoi d'emails de notification
* **StrConvert.ps1** : Conversion de chaînes de caractères et encodage UTF-8
* **SQLServer - TransactionOneByOne.ps1** : Module de transaction SQL (mode OneByOne)
* **SQLServer - TransactionAllInOne.ps1** : Module de transaction SQL (mode AllInOne)
* **SQL - Transaction.ps1**

Paramétrer le fichier SyncSQLtoSQL.ini

## Sources des données  

|                   Paramètres .ini                   |                    Description                     |
| --------------------------------------------------- | -------------------------------------------------- |
| [**SQL_Master**]                                    | Base de données maître (source)                   |
| [**SQL_Slave**]                                     | Base de données esclave (destination)             |


## Tables synchronisées

Les tables à synchroniser sont définies dans les paramètres de configuration :

|                   Paramètres .ini                   |            Tables            |
| --------------------------------------------------- | ---------------------------- |
| [SQL_Master][table] / [SQL_Slave][table]           | annuaire_acteur,annuaire_entite |


## Principe du traitement

Le script effectue une **synchronisation unidirectionnelle des données de la base maître vers la base esclave**.

* Charge les données depuis la **base SQL Server maître**
* Charge les données depuis la **base SQL Server esclave**
* Compare les données et identifie les différences
* Applique les modifications nécessaires sur la base esclave :
    * **INSERT** : Ajoute les nouveaux enregistrements
    * **UPDATE** : Met à jour les enregistrements modifiés
    * **DELETE** : Supprime les enregistrements orphelins (si AllowDelete = yes)
* Mode simulation disponible avec ApplyUpdate = no
* Gestion des transactions SQL :
    * **OneByOne** : Chaque requête SQL est exécutée individuellement (continue en cas d'erreur)
    * **AllInOne** : Toutes les requêtes sont exécutées dans une seule transaction (rollback en cas d'erreur)

**Nota important** : *La synchronisation se base sur la clé primaire ID des tables.*

# Traitements

Le script principal **SyncSQLtoSQL.ps1** effectue les traitements suivants :

* **LoadIni** : Chargement de la configuration
* **Query_BDD_MASTER** : Chargement des données maître
* **Query_BDD_SLAVE** : Chargement des données esclave
* **Update_BDD_SLAVE** : Synchronisation des données

## Modules utilisés

Le script utilise les modules PowerShell suivants (situés dans le répertoire `Modules\`) :

* **Ini.ps1** : Gestion des fichiers de configuration .ini
* **Log.ps1** : Gestion des logs et messages (LOG, ERR, WRN, DBG, MOD)
* **Encode.ps1** : Encodage/décodage des mots de passe
* **SendEmail.ps1** : Envoi d'emails de notification
* **StrConvert.ps1** : Conversion de chaînes de caractères et encodage UTF-8
* **SQLServer - TransactionOneByOne.ps1** : Module de transaction SQL (mode OneByOne)
* **SQLServer - TransactionAllInOne.ps1** : Module de transaction SQL (mode AllInOne)

Le module de transaction SQL chargé dépend du paramètre `[start][TransacSQL]` défini dans le fichier .ini.

### LoadIni

Charge la configuration depuis le fichier .ini et initialise l'environnement.

* Charge le fichier de configuration (par défaut : `SyncSQLtoSQL.ini`)
* Initialise les chemins des fichiers de logs
* Crée les fichiers de logs nécessaires
* Supprime le fichier OneShot de la précédente exécution
* Supporte le paramètre `$rootpath$` pour définir les chemins relatifs

### Query_BDD_MASTER

Charge en mémoire le contenu des tables de la **base de données maître** et les convertit en hash tables.

* Se connecte à la base SQL Server maître définie dans [**SQL_Master**]
* Récupère toutes les données des tables spécifiées dans le paramètre [SQL_Master][table]
* Traite chaque table individuellement (supporte plusieurs tables séparées par des virgules)
* Utilise la clé primaire ID pour indexer les données
* Applique le formatage de date défini dans [SQL_Master][SQLformatDate]
* Stocke les données dans la variable `$script:BDDMASTER`

### Query_BDD_SLAVE

Charge en mémoire le contenu des tables de la **base de données esclave** et les convertit en hash tables.

* Se connecte à la base SQL Server esclave définie dans [**SQL_Slave**]
* Récupère toutes les données des tables spécifiées dans le paramètre [SQL_Slave][table]
* Traite chaque table individuellement (supporte plusieurs tables séparées par des virgules)
* Utilise la clé primaire ID pour indexer les données
* Applique le formatage de date défini dans [SQL_Slave][SQLformatDate]
* Stocke les données dans la variable `$script:BDDSLAVE`

### Update_BDD_SLAVE

Effectue la synchronisation des données entre les bases maître et esclave.

* **Comparaison** : Compare les hash tables maître et esclave pour identifier les différences
* **Insertion** : Ajoute les nouveaux enregistrements présents dans la base maître
* **Mise à jour** : Modifie les enregistrements existants qui ont été modifiés dans la base maître
* **Suppression** : Supprime les enregistrements orphelins absents de la base maître (si [SQL_Slave][AllowDelete] = yes)
* **Mode simulation** : Si [start][ApplyUpdate] = no, simule les opérations sans les appliquer
* **Gestion des transactions** : Utilise le mode défini dans [start][TransacSQL] :
    * **OneByOne** : Exécute chaque requête individuellement, continue même en cas d'erreur
    * **AllInOne** : Exécute toutes les requêtes dans une transaction unique, rollback en cas d'erreur
* **Rechargement** : Recharge les données modifiées en mémoire après chaque table synchronisée
* **Ordre d'exécution** : DELETE → UPDATE → INSERT (pour éviter les conflits de clés)

**Nota** : *La synchronisation préserve l'intégrité des données en utilisant des transactions SQL.* 

# Fichiers de LOGS

Les fichiers de logs sont définis dans la section `[intf]` du fichier .ini et sont stockés dans le répertoire `logs\`.

## SyncSQLtoSQL-OneShot.log

Contient les logs du dernier traitement de synchronisation.

* Réinitialisé à chaque exécution
* Contient tous les messages LOG, ERR, WRN, DBG selon la configuration
* Chemin par défaut : `$rootpath$\logs\SyncSQLtoSQL-OneShot.log`

## SyncSQLtoSQL-Cumul.err

Contient le cumul des erreurs constatées dans tous les traitements de synchronisation.

* Cumulé à chaque exécution (non réinitialisé)
* Contient uniquement les messages d'erreur (ERR)
* Peut inclure les warnings (WRN) si `[start][warntoerr] = yes`
* Chemin par défaut : `$rootpath$\logs\SyncSQLtoSQL-Cumul.err`

## SyncSQLtoSQL-Cumul.mod

Contient le cumul des modifications appliquées sur la base de données esclave.

* Cumulé à chaque exécution (non réinitialisé)
* Contient toutes les requêtes SQL exécutées (INSERT, UPDATE, DELETE)
* Utile pour l'audit et le suivi des modifications
* Chemin par défaut : `$rootpath$\logs\SyncSQLtoSQL-Cumul.mod`

# Utilisation

## Exécution du script

```powershell
# Utiliser le fichier .ini par défaut (SyncSQLtoSQL.ini)
.\SyncSQLtoSQL.ps1

# Utiliser un fichier .ini spécifique
.\SyncSQLtoSQL.ps1 MonFichier.ini
```

## Paramètres de configuration

Le fichier de configuration .ini doit être placé dans le même répertoire que le script.

# Exemple de fichier .ini

```ini
# -----------------------------------------------------------------------------------------------------------------------------
#    SyncSQLtoSQL.ini - Necessite Powershell 7 ou +
#      Ce script synchronise les tables d'une base SQL Server esclave avec les données maître
# -----------------------------------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------
#     Parametrage du comportement du script SyncSQLtoSQL.ps1
# -------------------------------------------------------------------

[start]
# Le parametre "ApplyUpdate" yes/no : permet de simuler sans modifier la base Slave si ApplyUpdate = no
ApplyUpdate = yes

# Le parametre "TransacSQL" OneByOne/AllInOne : définit le mode de transaction
#   - OneByOne : Chaque requête est exécutée individuellement (continue en cas d'erreur)
#   - AllInOne : Toutes les requêtes sont exécutées dans une transaction unique (rollback en cas d'erreur)
TransacSQL  = OneByOne

# Le parametre "logtoscreen" contrôle l'affichage de toutes les infos de log/error/warning dans la console
logtoscreen = yes

# Le parametre "debug" contrôle l'affichage des infos de debug dans la console
debug       = no

# Le parametre "warntoerr" permet d'inclure ou pas les warnings dans le fichier SyncSQLtoSQL-Cumul.err
warntoerr   = yes

# -------------------------------------------------------------------
#     Chemin des fichiers de LOGS
# -------------------------------------------------------------------
[intf]
name = Synchronisation base SQL Server Master To Slave

# ----  Réinitialisé à chaque execution  ----

# Chemin du fichier log : 
pathfilelog   = $rootpath$\logs\SyncSQLtoSQL-OneShot.log

# ----  Cumulé à chaque execution  ----

# Chemin du fichier des modifications SQL
pathfilemod = $rootpath$\logs\SyncSQLtoSQL-Cumul.mod

# Chemin du fichier d'erreur
pathfileerr   = $rootpath$\logs\SyncSQLtoSQL-Cumul.err

# -------------------------------------------------------------------
#     Parametrage de la base SQL Server MASTER (source)
# -------------------------------------------------------------------
[SQL_Master]                                                                       
server        = WIN-09T11CB4M65\TEST
database      = admin
table         = annuaire_acteur,annuaire_entite
login         = sa
password      = !Plmuvimvmhpb2
SQLformatDate = dd/MM/yyyy HH:mm:ss

# -------------------------------------------------------------------
#     Parametrage de la base SQL Server SLAVE (destination)
# -------------------------------------------------------------------
[SQL_Slave]                                                                       
server        = PITHOME
database      = admin
table         = annuaire_acteur,annuaire_entite
login         = sa
password      = !Plmuvimvmhpb2
AllowDelete   = yes
SQLformatDate = dd/MM/yyyy HH:mm:ss

# -------------------------------------------------------------------
#     Parametrage des Emails
# -------------------------------------------------------------------

# Parametre pour l'envoi de mails
[email]
sendemail    = no
destinataire = admin@example.com
Subject      = Synchronisation SQL Server
emailmode    = SMTP
UseSSL       = false

# Login pour SMTP
expediteur   = noreply@example.com
server       = smtp.example.com
port         = 25
password     = 
```

## Description des paramètres

### Section [start]

| Paramètre | Valeurs | Description |
|-----------|---------|-------------|
| ApplyUpdate | yes/no | Active ou désactive l'application des modifications (mode simulation si "no") |
| TransacSQL | OneByOne/AllInOne | Mode de transaction SQL |
| logtoscreen | yes/no | Affiche les logs dans la console |
| debug | yes/no | Active le mode debug (affichage des messages DBG) |
| warntoerr | yes/no | Inclut les warnings dans le fichier d'erreurs cumulées |

### Section [SQL_Master] et [SQL_Slave]

| Paramètre | Description |
|-----------|-------------|
| server | Nom du serveur SQL Server (peut inclure l'instance : `SERVER\INSTANCE`) |
| database | Nom de la base de données |
| table | Liste des tables à synchroniser (séparées par des virgules) |
| login | Login de connexion SQL Server |
| password | Mot de passe (peut être encodé) |
| SQLformatDate | Format de date pour la conversion (ex: `dd/MM/yyyy HH:mm:ss`) |
| AllowDelete | yes/no (uniquement pour SQL_Slave) - Autorise la suppression des enregistrements orphelins |
