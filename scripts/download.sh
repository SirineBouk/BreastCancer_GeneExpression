#!/usr/bin/env bash

# Arrêter le script en cas d'erreur
set -euo pipefail

# Déterminer le chemin du projet
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Charger la configuration
source "$PROJECT_DIR/config/config.sh"

CHECKSUM_FILE="$RAW_DIR/checksums.sha256"

error() { echo "ERREUR : $*" >&2; }

# Chemin relatif à la racine du projet (format utilisé dans checksums.sha256)
rel_path() { realpath --relative-to="$PROJECT_DIR" "$1"; }

# ---------------------------------------------------------------
# 1. Vérifier que la configuration fournit toutes les valeurs
# ---------------------------------------------------------------
for var in RAW_DIR RAW_ARCHIVE RAW_URL \
           SERIES_MATRIX MATRIX_URL \
           SERIES_SOFT SERIES_SOFT_URL \
           PLATFORM_SOFT PLATFORM_SOFT_URL; do
    if [[ -z "${!var:-}" ]]; then
        error "la variable $var est absente de config/config.sh"
        exit 1
    fi
done

mkdir -p "$RAW_DIR"

# ---------------------------------------------------------------
# 2. Fonctions utilitaires
# ---------------------------------------------------------------

# Test d'intégrité selon le type de fichier ($2 = nom servant à choisir le test)
check_integrity() {
    local file="$1" name="${2:-$1}"
    case "$name" in
        *.gz)  gzip -t "$file" 2>/dev/null ;;
        *.tar) tar -tf "$file" >/dev/null 2>&1 ;;
        *)     [[ -s "$file" ]] ;;
    esac
}

# Le fichier a-t-il déjà une ligne dans checksums.sha256 ?
has_checksum() {
    local rel
    rel="$(rel_path "$1")"
    [[ -f "$CHECKSUM_FILE" ]] || return 1
    awk -v f="$rel" '$2==f {found=1} END {exit !found}' "$CHECKSUM_FILE"
}

# La somme enregistrée correspond-elle au fichier ?
checksum_ok() {
    local rel
    rel="$(rel_path "$1")"
    ( cd "$PROJECT_DIR" && awk -v f="$rel" '$2==f' "$CHECKSUM_FILE" \
        | sha256sum -c --status - )
}

# Fichier présent et vérifié (somme SHA-256 si connue, sinon test d'intégrité)
is_verified() {
    local file="$1"
    [[ -s "$file" ]] || return 1
    if has_checksum "$file"; then
        checksum_ok "$file"
    else
        check_integrity "$file" "$file"
    fi
}

# Calculer la somme SHA-256 et la (ré)enregistrer dans checksums.sha256
record_checksum() {
    local rel tmp="$CHECKSUM_FILE.tmp"
    rel="$(rel_path "$1")"
    touch "$CHECKSUM_FILE"
    awk -v f="$rel" '$2!=f' "$CHECKSUM_FILE" > "$tmp"
    ( cd "$PROJECT_DIR" && sha256sum "$rel" ) >> "$tmp"
    mv "$tmp" "$CHECKSUM_FILE"
    echo "Somme SHA-256 enregistrée : $rel"
}

# Télécharger un fichier (nom temporaire, reprise, vérification, renommage)
download_file() {
    local url="$1" dest="$2" tmp="$2.part"

    mkdir -p "$(dirname "$dest")"

    # Ne pas retélécharger un fichier déjà présent et vérifié
    if [[ -e "$dest" ]]; then
        if is_verified "$dest"; then
            echo "Déjà présent et vérifié : $dest"
            has_checksum "$dest" || record_checksum "$dest"
            return 0
        fi
        echo "Fichier invalide ou incomplet, nouveau téléchargement : $dest"
        rm -f "$dest"
    fi

    echo "Téléchargement : $url"
    if ! curl -fL --http1.1 -C - \
              --retry 10 --retry-delay 2 --retry-all-errors \
              --connect-timeout 30 \
              -o "$tmp" "$url"; then
        error "échec du téléchargement de $url"
        return 1
    fi

    # Vérifier le fichier temporaire avant de le valider
    if ! check_integrity "$tmp" "$dest"; then
        error "fichier corrompu ou incomplet après téléchargement : $url"
        rm -f "$tmp"
        return 1
    fi

    # Renommer seulement si tout est correct
    mv "$tmp" "$dest" || { error "impossible de renommer $tmp"; return 1; }
    record_checksum "$dest"
    echo "OK : $dest"
}

# ---------------------------------------------------------------
# 3. Téléchargements
# ---------------------------------------------------------------
failed=0

download_file "$RAW_URL"    "$RAW_DIR/$RAW_ARCHIVE"    || failed=1
download_file "$MATRIX_URL"  "$RAW_DIR/$SERIES_MATRIX"  || failed=1
download_file "$SERIES_SOFT_URL"    "$RAW_DIR/$SERIES_SOFT"    || failed=1
download_file "$PLATFORM_SOFT_URL"  "$RAW_DIR/$PLATFORM_SOFT"  || failed=1

if (( failed )); then
    error "au moins un téléchargement a échoué."
    exit 1
fi

# ---------------------------------------------------------------
# 4. Vérification finale des sommes SHA-256
# ---------------------------------------------------------------
echo "Vérification des empreintes SHA-256..."
if ! ( cd "$PROJECT_DIR" && sha256sum -c "$(rel_path "$CHECKSUM_FILE")" ); then
    error "une somme SHA-256 ne correspond pas."
    exit 1
fi

echo "Opération terminée."
