# arch2drive

Script d'archivage automatique qui crée des archives chiffrées 7z d'un répertoire avec upload vers Google Drive et planification quotidienne.

## Description

`arch2drive` est un ensemble de scripts qui permet de :
- Créer des archives 7z chiffrées avec AES-256
- Masquer les noms de fichiers dans l'archive
- Uploader automatiquement vers Google Drive
- Remplacer l'archive existante (nom fixe)
- Programmer l'exécution automatique tous les jours à 12h00
- Gérer la configuration via un fichier simple

## Structure des fichiers
```
arch2drive/
 ├── arch2drive.sh # Script bash principal
 ├── arch2drive.conf # Fichier de configuration unique
 ├── o_auth2_google_drive_token_retriever.sh # Générateur de token OAuth2
 ├── run_arch2drive.bat # Lanceur Windows (manuel)
 ├── schedule_arch2drive.bat # Scheduler automatique
 ├── start_schedule_arch2drive_hidden.vbs # Lanceur invisible du scheduler
 ├── scheduler.log # Logs du scheduler (créé automatiquement)
 └── README.md # Cette documentation
``` 

## Prérequis

- **Windows** avec Git Bash installé
- **7-Zip** installé dans `C:\Program Files\7-Zip\` ou disponible dans le PATH
- Droits d'écriture dans le répertoire de destination des archives
- **Compte Google** (optionnel, pour l'upload vers Google Drive)

## Installation

1. **Cloner ou télécharder** ce projet dans un répertoire (ex: `C:\Scripts\arch2drive\`)

2. **Créer le fichier de configuration** `arch2drive.conf` :
```
# Configuration pour arch2drive
DIRECTORY=C:/Users/VotreNom/Documents/DossierASauvegarder
PASSWORD=votre_mot_de_passe_secret
ARCHIVE_DIRECTORY=./archives
# Configuration Google Drive (optionnel)
GOOGLE_DRIVE_CLIENT_ID=votre_client_id.apps.googleusercontent.com
GOOGLE_DRIVE_CLIENT_SECRET=votre_client_secret
 ```

3. **Configuration Google Drive** (optionnel) :
   - Créer un projet sur [Google Cloud Console](https://console.cloud.google.com/)
   - Activer l'API Google Drive
   - Créer des identifiants OAuth2 pour application de bureau
   - Ajouter CLIENT_ID et CLIENT_SECRET dans `arch2drive.conf`
   - Lancer `o_auth2_google_drive_token_retriever.sh` pour obtenir les tokens

4. **Tester l'installation** :
```
cmd
# Double-cliquer sur run_arch2drive.bat
# ou en ligne de commande :
run_arch2drive.bat
``` 

5. **Activer la planification automatique** :
- Ouvrir le dossier de démarrage : `Windows + R` → `shell:startup`
- **Créer un raccourci** vers `start_schedule_arch2drive_hidden.vbs` dans ce dossier
- Redémarrer Windows ou double-cliquer sur le raccourci pour démarrer

## Configuration Google Drive

### Étape 1 : Création du projet Google Cloud
1. Aller sur [Google Cloud Console](https://console.cloud.google.com/)
2. Créer un nouveau projet ou sélectionner un projet existant
3. Aller dans "APIs & Services" → "Library"
4. Chercher et activer "Google Drive API"

### Étape 2 : Création des identifiants OAuth2
1. Aller dans "APIs & Services" → "Credentials"
2. Cliquer sur "Create Credentials" → "OAuth client ID"
3. Choisir "Desktop application"
4. Donner un nom à votre application
5. Copier le CLIENT_ID et CLIENT_SECRET généré

### Étape 3 : Configuration des tokens
1. Ajouter CLIENT_ID et CLIENT_SECRET dans `arch2drive.conf`
2. Lancer `o_auth2_google_drive_token_retriever.sh`
3. Autoriser l'application dans votre navigateur
4. Les tokens sont automatiquement sauvegardés dans `arch2drive.conf`

## Gestion du scheduler

### Démarrer le scheduler
- **Automatique** : Au démarrage de Windows (via le raccourci dans startup)
- **Manuel** : Double-cliquer sur `start_schedule_arch2drive_hidden.vbs` ou son raccourci

### Arrêter le scheduler
#### Via le Gestionnaire des tâches
1. **Ouvrir le Gestionnaire des tâches** : `Ctrl + Shift + Échap`
2. **Onglet "Processus"** → Rechercher `cmd.exe` ou `schedule_arch2drive.bat`
3. **Cliquer sur le processus** → "Fin de tâche"

## Configuration
### Fichier `arch2drive.conf`

| Paramètre | Description | Exemple |
| --- | --- | --- |
| `DIRECTORY` | Répertoire source à archiver | `C:/Users/John/Documents` |
| `PASSWORD` | Mot de passe pour chiffrer l'archive | `MonMotDePasse123!` |
| `ARCHIVE_DIRECTORY` | Répertoire de destination des archives | `./archives` ou `C:/Backups` |
| `GOOGLE_DRIVE_CLIENT_ID` | ID client OAuth2 Google | `123456.apps.googleusercontent.com` |
| `GOOGLE_DRIVE_CLIENT_SECRET` | Secret client OAuth2 Google | `GOCSPX-abcdef123456` |
| `GOOGLE_DRIVE_ACCESS_TOKEN` | Token d'accès (généré automatiquement) | `ya29.a0AfH6SMC...` |
| `GOOGLE_DRIVE_REFRESH_TOKEN` | Token de rafraîchissement (généré automatiquement) | `1//0GWthWrNHKuK9C...` |

## Utilisation
### Exécution manuelle
```
cmd
# Lancer une sauvegarde immédiatement
run_arch2drive.bat
``` 
### Exécution programmée
Le scheduler s'exécute automatiquement tous les jours à 12h00 une fois le raccourci placé dans le dossier de démarrage.

### Logs
- **Execution manuelle** : Affiché dans la console
- **Execution programmée** : Enregistré dans `scheduler.log`

## Format des archives
Les archives créées ont les caractéristiques suivantes :
- **Format** : 7z
- **Chiffrement** : AES-256
- **Compression** : Niveau 3 (équilibré vitesse/taille)
- **Noms masqués** : Les noms de fichiers sont chiffrés
- **Nom fixe** : `{NomDuDossier}_backup.7z`
- **Emplacement Google Drive** : Racine (remplace l'archive existante)

## Décompression
### Windows
1. **Double-cliquer** sur le fichier `.7z`
2. **Entrer le mot de passe** quand demandé
3. **Extraire** les fichiers

### Linux/Mac
```
bash
# Extraire l'archive
7z x nom_archive_backup.7z
# Entrer le mot de passe quand demandé
``` 

## Sécurité
- Les mots de passe sont nettoyés de la mémoire après utilisation
- Le fichier de configuration contient des informations sensibles - **sécurisez-le** :
    - Placez-le dans un répertoire avec accès restreint
    - Définissez des permissions appropriées
    - N'ajoutez jamais `arch2drive.conf` au contrôle de version
- Les tokens Google Drive ont une durée de vie limitée mais sont gérés automatiquement

## Dépannage
### 7-Zip non trouvé
```
❌ Erreur: 7-Zip n'est pas trouvé.
``` 
**Solution** : Installer 7-Zip depuis [https://www.7-zip.org/](https://www.7-zip.org/)

### Répertoire source introuvable
```
❌ Erreur: Le répertoire 'X:\path' n'existe pas.
``` 
**Solution** : Vérifier le chemin dans `arch2drive.conf`

### Problème Google Drive
```
❌ Erreur lors de l'upload vers Google Drive
``` 
**Solutions** :
1. Vérifier la connexion Internet
2. Régénérer les tokens avec `o_auth2_google_drive_token_retriever.sh`
3. Vérifier que l'API Google Drive est activée
4. Contrôler les quotas API dans Google Cloud Console

### Le scheduler ne fonctionne pas
1. Vérifier que le raccourci vers `start_schedule_arch2drive_hidden.vbs` est dans le dossier de démarrage
2. Consulter les logs dans `scheduler.log`
3. Tester manuellement avec `run_arch2drive.bat`
4. Vérifier dans le Gestionnaire des tâches qu'un processus `cmd.exe` avec `schedule_arch2drive.bat` est actif

### Comment savoir si le scheduler fonctionne
1. **Gestionnaire des tâches** → Rechercher un processus `cmd.exe` avec la ligne de commande contenant `schedule_arch2drive`
2. **Vérifier les logs** : Ouvrir `scheduler.log` pour voir la dernière activité
3. **Test** : Modifier temporairement l'heure cible dans le script pour tester

## Exemples
### Configuration basique (local uniquement)
```
DIRECTORY=C:/Users/John/Documents
PASSWORD=SecretPassword123
ARCHIVE_DIRECTORY=./archives
``` 

### Configuration complète avec Google Drive
```
# Sauvegarde de plusieurs projets
DIRECTORY=C:/Projects/ImportantWork
PASSWORD=SuperSecretBackupKey2024!
ARCHIVE_DIRECTORY=D:/Backups/Daily
# Configuration Google Drive
GOOGLE_DRIVE_CLIENT_ID=123456789.apps.googleusercontent.com
GOOGLE_DRIVE_CLIENT_SECRET=GOCSPX-abcdefghijklmnop
GOOGLE_DRIVE_ACCESS_TOKEN=ya29.a0AfH6SMC...
GOOGLE_DRIVE_REFRESH_TOKEN=1//0GWthWrNHKuK9C...
``` 

## Fonctionnalités avancées
- **Nom d'archive fixe** : Remplace automatiquement l'archive existante
- **Upload à la racine** : Simplifie l'organisation sur Google Drive  
- **Barre de progression** : Affichage de l'avancement durant l'upload
- **Gestion automatique des tokens** : Les tokens expirés sont détectés

## Limitations
- Fonctionne uniquement sur Windows avec Git Bash
- Une seule exécution par jour (12h00)
- Pas de rotation automatique des anciennes archives (une seule archive par projet)
- Configuration en texte clair (mot de passe et tokens visibles)
- Upload uniquement à la racine de Google Drive

## Licence
Ce projet est fourni "tel quel" sans garantie. Utilisez à vos propres risques.
