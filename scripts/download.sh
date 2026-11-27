#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] début du téléchargement des données (Dataset GSE15852 + Matrix + GPL96)..."
mkdir -p data/raw

is_valid(){
    case "$1" in
      *.tar) tar -tf "$1" > /dev/null 2>&1 ;;
      *.gz) gzip -t "$1" > /dev/null 2>&1 ;;
    esac
}


download_file() {
    local url="$1" target="$2" tmp="$2.part"
    if [ -f "$target" ] && is_valid "$target"; then
        echo "[INFO] $target existe déjà et est valide."
        return 0
    fi
    rm -f "$target" "$tmp"
    echo "[INFO] téléchargement de $target..."
    curl -fL--retry 3 "$url" -o "$tmp"
    mv "$tmp" "$target"
    is_valid "$target" || { rm -f "$target"; echo "[ERREUR] fichier invalide " >&2; exit 1; }
}
#1. archive brute raw (.tar)
RAW_URL="https://www.ncbi.nlm.nih.gov/geo/download/?acc=GSE15852&format=file"
TARGET_TAR="data/raw/GSE15852_RAW.tar"
download_file "$RAW_URL" "$TARGET_TAR"


#2. series matrix (.txt.gz)
MATRIX_URL="https://ftp.ncbi.nlm.nih.gov/geo/series/GSE15nnn/GSE15852/matrix/GSE15852_series_matrix.txt.gz"
TARGET_MATRIX="data/raw/GSE15852_series_matrix.txt.gz"
download_file "$MATRIX_URL" "$TARGET_MATRIX"



#3. GPL96 annotation (.annot.gz)
GPL_DIRECT_URL="https://ftp.ncbi.nlm.nih.gov/geo/platforms/GPL96nn/GPL96/annot/GPL96.annot.gz"
TARGET_GPL="data/raw/GPL96.annot.gz"
download_file "$GPL_DIRECT_URL" "$TARGET_GPL"



#4. sommes SHA-256 (enregistrées la 1er fois , verifiées ensuite)
cd data/raw
if [ -f checksums.sha256 ]; then
    echo "[INFO] vérification des fichiers avec checksums.sha256..."
    sha256sum  -c checksums.sha256 
    echo "[OK] fichiers valides et conformes aux sommes enregistrées."
else
    echo "[INFO] calcul des sommes SHA-256 (premiére exécution)..."
    sha256sum GSE15852_RAW.tar GSE15852_series_matrix.txt.gz GPL96.annot.gz > checksums.sha256
    echo "[OK] tous les fichiers ont été téléchargés et vérifiés avec succés dans data/raw/checksums.sha256."
fi