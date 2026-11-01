#!/usr/bin/env bash

# Préparation de l'environnement du projet

# Charger la configuration
source "$(dirname "$0")/../config/config.sh"

# Créer les dossiers nécessaires
mkdir -p "$RAW_DIR"
mkdir -p "$PROCESSED_DIR"
mkdir -p "$RESULTS_DIR"
mkdir -p "$LOGS_DIR"

echo "Les dossiers du projet sont prêts."

# Vérifier les outils nécessaires
for outil in wget curl tar sha256sum python3; do
    if command -v "$outil" >/dev/null 2>&1; then
        echo "$outil : disponible"
    else
        echo "ERREUR : $outil n'est pas installé."
        exit 1
    fi
done

echo "Préparation de l'environnement terminée."