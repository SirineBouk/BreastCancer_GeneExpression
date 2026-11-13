#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] début du téléchargement des données (Dataset GSE15852 + Matrix + GPL96)..."
mkdir -p data/raw

#1. archive brute raw (.tar)
RAW_URL="https://www.ncbi.nlm.nih.gov/geo/download/?acc=GSE15852&format=file"
TARGET_TAR="data/raw/GSE15852_RAW.tar"

if [ -f "$TARGET_TAR" ]; then  
    echo "[INFO] l'archive brute existe déjà localement."
else
    echo "[INFO] téléchargement de l'archive RAW..."
    curl -L "$RAW_URL" -o "$TARGET_TAR"
fi  

#2. series matrix (.txt.gz)
MATRIX_URL="https://ftp.ncbi.nlm.nih.gov/geo/series/GSE15nnn/GSE15852/matrix/GSE15852_series_matrix.txt.gz"
TARGET_MATRIX="data/raw/GSE15852_series_matrix.txt.gz"

if [ -f "$TARGET_MATRIX" ]; then
    echo "[INFO] le fichier series_matrix existe déjà localement."
else 
    echo "[INFO] téléchargement du fichier series matrix..."
    curl -L "$MATRIX_URL" -o "$TARGET_MATRIX"
fi 

#3. GPL96 annotation (.annot.gz)
GPL_DIRECT_URL="https://ftp.ncbi.nlm.nih.gov/geo/platforms/GPLnnn/GPL96/annot/GPL96.annot.gz"
TARGET_GPL="data/raw/GPL96.annot.gz"

if [ -f "$TARGET_GPL" ]; then
    echo "[INFO] le fichier GPL96.annot.gz existe déjà localement."
else
    echo "[INFO] téléchargement des annotations GPL96..."
    curl -L "$GPL_DIRECT_URL" -o "$TARGET_GPL"
fi 

echo "[INFO] calcul des sommes SHA-256 pour tous les fichiers..."
sha256sum data/raw/GSE15852_RAW.tar data/raw/GSE15852_series_matrix.txt.gz data/raw/GPL96.annot.gz > data/raw/checksums.sha256

echo "[OK] tous les fichiers ont été téléchargés et vérifiés avec succés dans data/raw !"
