#!/bin/bash

# Chargement depuis arch2drive.conf
CONFIG_FILE="arch2drive.conf"

if [ -f "$CONFIG_FILE" ]; then
    echo "📄 Fichier $CONFIG_FILE chargé"
    
    # Lire les paramètres depuis le fichier de config
    while IFS='=' read -r key value || [ -n "$key" ]; do
        key=$(echo "$key" | tr -d '\r\n' | tr -d '[:space:]')
        value=$(echo "$value" | tr -d '\r\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        
        case "$key" in
            GOOGLE_DRIVE_CLIENT_ID)
                CLIENT_ID="$value"
                ;;
            GOOGLE_DRIVE_CLIENT_SECRET)
                CLIENT_SECRET="$value"
                ;;
        esac
    done < "$CONFIG_FILE"
fi

# OAuth2 pour Desktop Application (sans redirect URI)
CLIENT_ID="${CLIENT_ID:-}"
CLIENT_SECRET="${CLIENT_SECRET:-}"
SCOPE="https://www.googleapis.com/auth/drive"

# Vérification des variables requises
if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "❌ Erreur : CLIENT_ID et CLIENT_SECRET sont requis"
    echo ""
    echo "💡 Ajoutez ces lignes dans arch2drive.conf :"
    echo "GOOGLE_DRIVE_CLIENT_ID=votre_client_id.apps.googleusercontent.com"
    echo "GOOGLE_DRIVE_CLIENT_SECRET=votre_client_secret"
    echo ""
    exit 1
fi

# Vérifier la connectivité
echo "🌐 Test de connectivité..."
if curl -s --max-time 5 --ssl-no-revoke https://accounts.google.com > /dev/null; then
    echo "✅ Connexion Google OK"
else
    echo "❌ Problème de connectivité"
    exit 1
fi

# URL d'autorisation
AUTH_URL="https://accounts.google.com/o/oauth2/v2/auth"
AUTH_URL="${AUTH_URL}?client_id=${CLIENT_ID}"
AUTH_URL="${AUTH_URL}&redirect_uri=urn:ietf:wg:oauth:2.0:oob"
AUTH_URL="${AUTH_URL}&scope=${SCOPE}"
AUTH_URL="${AUTH_URL}&response_type=code"
AUTH_URL="${AUTH_URL}&access_type=offline"
AUTH_URL="${AUTH_URL}&prompt=consent"

echo ""
echo "🌐 Ouvrez cette URL :"
echo ""
echo "$AUTH_URL"
echo ""
read -p "📋 Code d'autorisation reçu: " AUTH_CODE

AUTH_CODE=$(echo "$AUTH_CODE" | tr -d '[:space:]')

if [ -z "$AUTH_CODE" ]; then
    echo "❌ Code vide"
    exit 1
fi

echo ""
echo "🔄 Tentative d'échange du token..."
echo "📤 Envoi de la requête..."

# Requête avec verbose pour diagnostic
TOKEN_RESPONSE=$(curl -s -w "HTTP_CODE:%{http_code}\nTIME:%{time_total}\n" \
    --ssl-no-revoke \
    -X POST https://oauth2.googleapis.com/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "code=${AUTH_CODE}" \
    -d "grant_type=authorization_code" \
    -d "redirect_uri=urn:ietf:wg:oauth:2.0:oob")

echo ""
echo "📥 RÉPONSE COMPLÈTE :"
echo "===================="
echo "$TOKEN_RESPONSE"
echo "===================="
echo ""

# Extraire le code HTTP
HTTP_CODE=$(echo "$TOKEN_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
echo "📊 Code HTTP: $HTTP_CODE"

# Analyser la réponse et extraire les tokens
JSON_PART=$(echo "$TOKEN_RESPONSE" | head -n -2)

if [ "$HTTP_CODE" = "200" ]; then
    echo ""
    echo "✅ Tokens récupérés avec succès !"
    
    # Extraire les tokens
    ACCESS_TOKEN=$(echo "$JSON_PART" | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    REFRESH_TOKEN=$(echo "$JSON_PART" | sed -n 's/.*"refresh_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    
    if [ -n "$ACCESS_TOKEN" ]; then
        echo "📝 Sauvegarde des tokens dans arch2drive.conf..."
        
        # Mettre à jour arch2drive.conf avec les tokens
        if [ -f "$CONFIG_FILE" ]; then
            # Supprimer les anciennes entrées de tokens
            sed -i.bak '/^GOOGLE_DRIVE_ACCESS_TOKEN=/d' "$CONFIG_FILE"
            sed -i.bak '/^GOOGLE_DRIVE_REFRESH_TOKEN=/d' "$CONFIG_FILE"
            rm -f "${CONFIG_FILE}.bak" 2>/dev/null
        fi
        
        # Ajouter les nouveaux tokens
        echo "GOOGLE_DRIVE_ACCESS_TOKEN=$ACCESS_TOKEN" >> "$CONFIG_FILE"
        if [ -n "$REFRESH_TOKEN" ]; then
            echo "GOOGLE_DRIVE_REFRESH_TOKEN=$REFRESH_TOKEN" >> "$CONFIG_FILE"
        fi
        
        echo "✅ Tokens sauvegardés dans $CONFIG_FILE"
        echo "🔑 Access Token: ${ACCESS_TOKEN:0:20}..."
        if [ -n "$REFRESH_TOKEN" ]; then
            echo "🔄 Refresh Token: ${REFRESH_TOKEN:0:20}..."
        fi
    else
        echo "❌ Impossible d'extraire l'access token"
    fi
else
    echo "❌ Erreur lors de la récupération des tokens (HTTP $HTTP_CODE)"
fi

echo ""
echo "🔍 Processus terminé."

