#!/usr/bin/env bash
set euo pipefail

echo "[INFO] début de l'extraction des données brutes..."
TARGET_TAR="data/raw/GSE15852_RAW.tar"
EXTRACT_DIR="data/raw/extracted"

#1. vérifier que l'archive existe 
if [ ! -f "$TARGET_TAR" ]; then
    echo "[ERREUR] l'archive $TARGET_TAR est introuvable." >&2
    exit 1
fi

#2. vérification des sommes de controle SHA-256
echo "[INFO] vérification de l'intégrité via SHA-256..."
sha256sum --check --status data/raw/checksums.sha256

#3. création du dossier d'extraction 
mkdir -p "$EXTRACT_DIR"
echo "[INFO] extraction de l'archive dans $EXTRACT_DIR..."
tar -xf "$TARGET_TAR" -C "$EXTRACT_DIR"

#4. sécurité : rendre les données brutes extraites en lecture seule 
chmod -R -w "$EXTRACT_DIR"
echo "[ok] extraction et verouillage des données brutes terminés avec succés."