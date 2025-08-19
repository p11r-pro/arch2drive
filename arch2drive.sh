#!/bin/bash

# arch2drive - Script avec fichier de configuration
# Usage: arch2drive [fichier_config]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${1:-$SCRIPT_DIR/arch2drive.conf}"

# Vérifier que le fichier de config existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Erreur: Fichier de configuration introuvable: $CONFIG_FILE"
    echo ""
    echo "Créez un fichier arch2drive.conf avec:"
    echo "DIRECTORY=/chemin/vers/votre/dossier"
    echo "PASSWORD=votre_mot_de_passe"
    echo "ARCHIVE_DIRECTORY=./archives"
    echo "GOOGLE_DRIVE_ACCESS_TOKEN=votre_token_access"
    exit 1
fi

echo "📖 Lecture de la configuration: $CONFIG_FILE"

# Lire la configuration avec gestion des fins de ligne Windows
DIRECTORY=""
PASSWORD=""
ARCHIVE_DIRECTORY="."
GOOGLE_DRIVE_ACCESS_TOKEN=""
GOOGLE_DRIVE_REFRESH_TOKEN=""
GOOGLE_DRIVE_CLIENT_ID=""
GOOGLE_DRIVE_CLIENT_SECRET=""

while IFS='=' read -r key value || [ -n "$key" ]; do
    # Supprimer les caractères de retour chariot Windows
    key=$(echo "$key" | tr -d '\r\n' | tr -d '[:space:]')
    value=$(echo "$value" | tr -d '\r\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    # Ignorer les lignes vides et les commentaires
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    
    case "$key" in
        DIRECTORY)
            DIRECTORY="$value"
            ;;
        PASSWORD)
            PASSWORD="$value"
            ;;
        ARCHIVE_DIRECTORY)
            ARCHIVE_DIRECTORY="$value"
            ;;
        GOOGLE_DRIVE_ACCESS_TOKEN)
            GOOGLE_DRIVE_ACCESS_TOKEN="$value"
            ;;
        GOOGLE_DRIVE_REFRESH_TOKEN)
            GOOGLE_DRIVE_REFRESH_TOKEN="$value"
            ;;
        GOOGLE_DRIVE_CLIENT_ID)
            GOOGLE_DRIVE_CLIENT_ID="$value"
            ;;
        GOOGLE_DRIVE_CLIENT_SECRET)
            GOOGLE_DRIVE_CLIENT_SECRET="$value"
            ;;
        *)
            # Ignorer les variables inconnues
            ;;
    esac
done < "$CONFIG_FILE"

# Vérifier que les paramètres essentiels sont définis
if [ -z "$DIRECTORY" ]; then
    echo "❌ Erreur: DIRECTORY non défini dans $CONFIG_FILE"
    exit 1
fi

if [ -z "$PASSWORD" ]; then
    echo "❌ Erreur: PASSWORD non défini dans $CONFIG_FILE"
    exit 1
fi

# Vérification que le répertoire existe
if [ ! -d "$DIRECTORY" ]; then
    echo "❌ Erreur: Le répertoire '$DIRECTORY' n'existe pas."
    exit 1
fi

# Créer le répertoire d'archives si nécessaire
if [ "$ARCHIVE_DIRECTORY" != "." ] && [ ! -d "$ARCHIVE_DIRECTORY" ]; then
    mkdir -p "$ARCHIVE_DIRECTORY"
    echo "📁 Répertoire d'archives créé: $ARCHIVE_DIRECTORY"
fi

# Chercher 7z
if command -v 7z &> /dev/null; then
    SEVENZ="7z"
else
    SEVENZ="/c/Program Files/7-Zip/7z.exe"
    if [ ! -f "$SEVENZ" ]; then
        echo "❌ Erreur: 7-Zip n'est pas trouvé."
        echo "- Pas dans le PATH"
        echo "- Pas dans /c/Program Files/7-Zip/7z.exe"
        echo "Téléchargez 7-Zip depuis: https://www.7-zip.org/"
        exit 1
    fi
fi

echo "✅ 7-Zip trouvé: $SEVENZ"

BASE_NAME=$(basename "$DIRECTORY")
ARCHIVE_NAME="${ARCHIVE_DIRECTORY}/${BASE_NAME}_backup.7z"

echo "🔐 Création de l'archive chiffrée..."
echo "📁 Répertoire source: $DIRECTORY"
echo "📦 Archive de sortie: $ARCHIVE_NAME"

# Créer l'archive avec compression niveau 3 fixe
"$SEVENZ" a -p"$PASSWORD" -mhe=on -mx=3 -ms=on "$ARCHIVE_NAME" "$DIRECTORY"

# Nettoyer la variable mot de passe
unset PASSWORD

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Archive chiffrée créée avec succès: $ARCHIVE_NAME"
    echo "📊 Taille de l'archive: $(du -h "$ARCHIVE_NAME" | cut -f1)"
    echo "🔐 Sécurité: AES-256 + noms de fichiers masqués"
    echo ""
    echo "📖 Instructions de décompression:"
    echo "🪟 Windows: Double-cliquez sur le fichier .7z et entrez le mot de passe"
    echo "🐧 Linux: 7z x \"$ARCHIVE_NAME\" (puis entrez le mot de passe)"
    
    # Upload vers Google Drive si token disponible
    if [ -n "$GOOGLE_DRIVE_ACCESS_TOKEN" ]; then
        echo ""
        echo "☁️  Upload vers Google Drive..."
        
        # Fonction pour rafraîchir le token
        refresh_access_token() {
            if [ -z "$GOOGLE_DRIVE_REFRESH_TOKEN" ] || [ -z "$GOOGLE_DRIVE_CLIENT_ID" ] || [ -z "$GOOGLE_DRIVE_CLIENT_SECRET" ]; then
                echo "❌ Informations manquantes pour rafraîchir le token"
                return 1
            fi
            
            echo "🔄 Rafraîchissement du token d'accès..."
            
            REFRESH_RESPONSE=$(curl -s --ssl-no-revoke \
                -X POST https://oauth2.googleapis.com/token \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -d "client_id=$GOOGLE_DRIVE_CLIENT_ID" \
                -d "client_secret=$GOOGLE_DRIVE_CLIENT_SECRET" \
                -d "refresh_token=$GOOGLE_DRIVE_REFRESH_TOKEN" \
                -d "grant_type=refresh_token")
            
            # Extraire le nouveau token
            NEW_ACCESS_TOKEN=$(echo "$REFRESH_RESPONSE" | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
            
            if [ -n "$NEW_ACCESS_TOKEN" ]; then
                echo "✅ Token rafraîchi avec succès"
                
                # Mettre à jour le token dans le fichier de config
                sed -i.bak "s/^GOOGLE_DRIVE_ACCESS_TOKEN=.*/GOOGLE_DRIVE_ACCESS_TOKEN=$NEW_ACCESS_TOKEN/" "$CONFIG_FILE"
                rm -f "${CONFIG_FILE}.bak" 2>/dev/null
                
                # Mettre à jour la variable locale
                GOOGLE_DRIVE_ACCESS_TOKEN="$NEW_ACCESS_TOKEN"
                return 0
            else
                echo "❌ Échec du rafraîchissement du token"
                echo "📥 Réponse: $REFRESH_RESPONSE"
                return 1
            fi
        }
        
        # Fonction pour tester si le token est valide
        test_token() {
            local response
            local http_code
            
            # Faire la requête et capturer à la fois la réponse et le code HTTP
            response=$(curl -s -w "HTTPSTATUS:%{http_code}" --ssl-no-revoke \
                -H "Authorization: Bearer $GOOGLE_DRIVE_ACCESS_TOKEN" \
                "https://www.googleapis.com/drive/v3/about?fields=user" 2>/dev/null)
            
            # Extraire le code HTTP
            http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
            
            # Vérifier si le code HTTP indique un succès (200-299)
            if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
                return 0  # Token valide
            else
                echo "🔍 Token invalide détecté (HTTP $http_code)"
                return 1  # Token invalide
            fi
        }
        
        # Tester le token actuel
        if ! test_token; then
            echo "⚠️  Token d'accès expiré, tentative de rafraîchissement..."
            if ! refresh_access_token; then
                echo "❌ Impossible de rafraîchir le token"
                echo "💡 Relancez o_auth2_google_drive_token_retriever.sh pour obtenir un nouveau token"
                exit 1
            fi
        fi
        
        # Nom fixe pour l'archive sur Google Drive
        ARCHIVE_FILENAME="${BASE_NAME}_backup.7z"
        
        # Rechercher si le fichier existe déjà à la racine
        echo "🔍 Vérification de l'existence du fichier ($ARCHIVE_FILENAME)..."
        SEARCH_RESULT=$(curl -s --ssl-no-revoke \
            -H "Authorization: Bearer $GOOGLE_DRIVE_ACCESS_TOKEN" \
            "https://www.googleapis.com/drive/v3/files?q=name%3D%27${ARCHIVE_FILENAME}%27%20and%20trashed%3Dfalse" \
            2>/dev/null)
        
        # Extraction simple avec sed : prendre le premier ID trouvé dans la réponse
        EXISTING_FILE_ID=$(echo "$SEARCH_RESULT" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
        
        if [ -n "$EXISTING_FILE_ID" ]; then
            echo "🔄 Remplacement du fichier existant..."
            
            # Mettre à jour le fichier existant avec barre de progression
            UPLOAD_RESULT=$(curl --ssl-no-revoke \
                --progress-bar \
                -X PATCH \
                -H "Authorization: Bearer $GOOGLE_DRIVE_ACCESS_TOKEN" \
                -F "file=@$ARCHIVE_NAME" \
                "https://www.googleapis.com/upload/drive/v3/files/$EXISTING_FILE_ID?uploadType=media")
            
            if [ $? -eq 0 ]; then
                echo "✅ Archive mise à jour avec succès sur Google Drive"
                echo "📁 Emplacement: Racine"
                echo "🆔 ID fichier: $EXISTING_FILE_ID"
            else
                echo "❌ Erreur lors de la mise à jour du fichier existant"
                echo "📥 Debug: $UPLOAD_RESULT"
                exit 1
            fi
        else
            echo "📤 Upload du nouveau fichier à la racine..."
            
            # Créer un nouveau fichier à la racine avec barre de progression
            UPLOAD_RESULT=$(curl --ssl-no-revoke \
                --progress-bar \
                -X POST \
                -H "Authorization: Bearer $GOOGLE_DRIVE_ACCESS_TOKEN" \
                -F "metadata={\"name\":\"$ARCHIVE_FILENAME\"};type=application/json;charset=UTF-8" \
                -F "file=@$ARCHIVE_NAME" \
                "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")
            
            if [ -n "$UPLOAD_RESULT" ] && echo "$UPLOAD_RESULT" | grep -q '"id"'; then
                FILE_ID=$(echo "$UPLOAD_RESULT" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
                echo "✅ Archive uploadée avec succès sur Google Drive"
                echo "📁 Emplacement: Racine"
                echo "🆔 ID fichier: $FILE_ID"
            else
                echo "❌ Erreur lors de l'upload vers Google Drive"
                echo "📥 Debug: $UPLOAD_RESULT"
                exit 1
            fi
        fi
    else
        echo ""
        echo "ℹ️  Token Google Drive non configuré - archive disponible localement uniquement"
        echo "💡 Ajoutez GOOGLE_DRIVE_ACCESS_TOKEN=votre_token dans $CONFIG_FILE pour l'upload automatique"
    fi
else
    echo "❌ Erreur lors de la création de l'archive chiffrée"
    exit 1
fi

exit 0
