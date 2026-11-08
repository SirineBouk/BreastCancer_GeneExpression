#!/usr/bin/env bash
set euo pipefail

echo "[INFO] début de l'extraction des données brutes..."
TARGET_TAR="data/raw/GSE15852_RAW.tar"
TARGET_MATRIX="data/raw/GSE15852_series_matrix.txt.gz"
EXTRACT_DIR="data/raw/extracted"

#1. vérifier que l'archive existe 
if [ ! -f "$TARGET_TAR" ]; then
    echo "[ERREUR] l'archive $TARGET_TAR est introuvable." >&2
    exit 1
fi

#2. vérification des sommes de controle SHA-256
echo "[INFO] vérification de l'intégrité via SHA-256..."
sha256sum --check --status data/raw/checksums.sha256

#3. vérifier si les fichiers sont déjà extraits, sinon les extraire
if [ -d "$EXTRACT_DIR" ] && [ "$(ls -A "$EXTRACT_DIR")" ]; then
    echo "[INFO] le dossier $EXTRACT_DIR existe déjà et n'est pas vide. extraction ignorée."
else
    mkdir -p "$EXTRACT_DIR"
    echo "[INFO] extraction de l'archive dans $EXTRACT_DIR..."
    tar -xf "$TARGET_TAR" -C "$EXTRACT_DIR"

#3.1. sécurité : rendre les données brutes extraites en lecture seule 
    chmod -R -w "$EXTRACT_DIR"
fi

#4. décompression de la matrice GEO (.gz) si elle est présente
TARGET_MATRIX_DECOMPRESSED="data/raw/GSE15852_series_matrix.txt"

if [ -f "$TARGET_MATRIX" ]; then
   if [ -f "$TARGET_MATRIX_DECOMPRESSED" ]; then
       echo "[INFO] le fichier de matrice décompressé existe déjà . décompression ignorée."
    else 
       echo "[INFO] décompression de la matrice series_matrix..."
       gunzip -k "$TARGET_MATRIX"
    fi 
else
   echo "[ERREUR] le fichier de matrice compressé est introuvable." >&2
   exit 1
fi

echo "[ok] extraction, décompression et verouillage des données brutes terminés avec succés."