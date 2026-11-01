#!/usr/bin/env bash

# Arrêter le script en cas d'erreur
set -euo pipefail

# Déterminer le chemin du projet
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Charger la configuration
source "$PROJECT_DIR/config/config.sh"

ARCHIVE="$RAW_DIR/$RAW_ARCHIVE"
MATRIX_GZ="$RAW_DIR/$SERIES_MATRIX"
MATRIX_TXT="${MATRIX_GZ%.gz}"
EXTRACT_DIR="$RAW_DIR/extracted"
TMP_DIR="$RAW_DIR/extracted.tmp"
CHECKSUM_FILE="$RAW_DIR/checksums.sha256"

# ---------------------------------------------------------------
# Journal
# ---------------------------------------------------------------
mkdir -p "$LOGS_DIR"
LOG_FILE="${LOG_FILE:-$LOGS_DIR/run_$(date +%Y%m%d_%H%M%S).log}"

log()   { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
error() { echo "[$(date '+%F %T')] ERREUR : $*" | tee -a "$LOG_FILE" >&2; }

# Nettoyage des fichiers temporaires, même en cas d'échec
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK" "$TMP_DIR" "$MATRIX_TXT.part"' EXIT

# ---------------------------------------------------------------
# Fonctions utilitaires
# ---------------------------------------------------------------

# Vérifier la somme SHA-256 enregistrée pour un fichier
verify_sha256() {
    local file="$1" rel line
    rel="$(realpath --relative-to="$PROJECT_DIR" "$file")"
    line="$(awk -v f="$rel" '$2==f' "$CHECKSUM_FILE" 2>/dev/null || true)"
    if [[ -z "$line" ]]; then
        error "aucune somme SHA-256 enregistrée pour $rel (lancer download.sh)"
        return 1
    fi
    if ( cd "$PROJECT_DIR" && echo "$line" | sha256sum -c --status - ); then
        log "SHA-256 correcte : $rel"
    else
        error "somme SHA-256 incorrecte : $rel (relancer download.sh)"
        return 1
    fi
}

# Comparer un dossier extrait avec la liste du TAR.
# Affiche les problèmes trouvés ; retourne 0 si tout est correct.
check_dir() {
    local dir="$1" f actual problems=0
    while IFS= read -r f; do
        if [[ ! -s "$dir/$f" ]]; then
            echo "manquant ou vide : $f"
            problems=1
        fi
    done < "$WORK/files.txt"
    actual="$(find "$dir" -type f | wc -l)"
    if (( actual != EXPECTED )); then
        echo "nombre de fichiers : $actual au lieu de $EXPECTED"
        problems=1
    fi
    return "$problems"
}

# ---------------------------------------------------------------
# 1. L'archive brute existe
# ---------------------------------------------------------------
if [[ ! -f "$ARCHIVE" ]]; then
    error "archive RAW introuvable : $ARCHIVE (lancer download.sh)"
    exit 1
fi
log "Archive trouvée : $ARCHIVE"

# ---------------------------------------------------------------
# 2. Somme SHA-256 de l'archive, avant extraction
# ---------------------------------------------------------------
log "Vérification SHA-256 de l'archive (quelques secondes)..."
verify_sha256 "$ARCHIVE" || exit 1

# ---------------------------------------------------------------
# 3. Le contenu du TAR peut être listé
# ---------------------------------------------------------------
if ! tar -tf "$ARCHIVE" > "$WORK/all.txt" 2> "$WORK/tar.err"; then
    error "impossible de lister le contenu de l'archive : $(head -n 1 "$WORK/tar.err")"
    exit 1
fi
grep -v '/$' "$WORK/all.txt" > "$WORK/files.txt" || true
EXPECTED="$(wc -l < "$WORK/files.txt")"
if (( EXPECTED == 0 )); then
    error "l'archive ne contient aucun fichier."
    exit 1
fi
log "L'archive contient $EXPECTED fichiers."

# ---------------------------------------------------------------
# 4. Extraction dans data/raw/extracted/ (via un dossier temporaire)
# ---------------------------------------------------------------
if [[ -d "$EXTRACT_DIR" && "${FORCE:-false}" != true ]] \
   && check_dir "$EXTRACT_DIR" > /dev/null; then
    log "Extraction déjà complète : $EXTRACT_DIR"
else
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    log "Extraction en cours..."
    if ! tar -xf "$ARCHIVE" -C "$TMP_DIR" --no-same-owner; then
        error "échec de l'extraction de $ARCHIVE"
        exit 1
    fi

    # Vérifier le dossier temporaire avant de le valider
    if ! problems="$(check_dir "$TMP_DIR")"; then
        error "extraction incomplète : $problems"
        exit 1
    fi

    # Remplacer un ancien dossier extrait éventuel
    if [[ -d "$EXTRACT_DIR" ]]; then
        chmod -R u+w "$EXTRACT_DIR"
        rm -rf "$EXTRACT_DIR"
    fi
    mv "$TMP_DIR" "$EXTRACT_DIR"
    log "Extraction terminée : $EXTRACT_DIR"
fi

# ---------------------------------------------------------------
# 5. Décompression de la matrice GEO (le .gz est conservé)
# ---------------------------------------------------------------
if [[ ! -f "$MATRIX_GZ" ]]; then
    error "matrice GEO introuvable : $MATRIX_GZ (lancer download.sh)"
    exit 1
fi
verify_sha256 "$MATRIX_GZ" || exit 1

if ! gzip -t "$MATRIX_GZ" 2> /dev/null; then
    error "matrice GEO corrompue : $MATRIX_GZ"
    exit 1
fi

if [[ -s "$MATRIX_TXT" ]] && gzip -dc "$MATRIX_GZ" | cmp -s - "$MATRIX_TXT"; then
    log "Matrice déjà décompressée : $MATRIX_TXT"
else
    if [[ -e "$MATRIX_TXT" ]]; then chmod u+w "$MATRIX_TXT"; fi
    gzip -dc "$MATRIX_GZ" > "$MATRIX_TXT.part"
    if [[ ! -s "$MATRIX_TXT.part" ]]; then
        error "la matrice décompressée est vide."
        exit 1
    fi
    mv -f "$MATRIX_TXT.part" "$MATRIX_TXT"
    log "Matrice décompressée : $MATRIX_TXT"
fi

# ---------------------------------------------------------------
# 6. Les fichiers attendus existent et l'extraction n'est pas vide
# ---------------------------------------------------------------
if ! problems="$(check_dir "$EXTRACT_DIR")"; then
    error "vérification des fichiers extraits : $problems"
    exit 1
fi

if ! grep -q '^!series_matrix_table_begin' "$MATRIX_TXT"; then
    error "la matrice GEO ne contient pas de tableau de valeurs."
    exit 1
fi

N_FILES="$(find "$EXTRACT_DIR" -type f | wc -l)"
N_CEL="$(find "$EXTRACT_DIR" -type f -iname '*.cel*' | wc -l)"
N_CHP="$(find "$EXTRACT_DIR" -type f -iname '*.chp*' | wc -l)"

if (( N_CEL + N_CHP == 0 )); then
    error "aucun fichier CEL ou CHP dans $EXTRACT_DIR"
    exit 1
fi

# ---------------------------------------------------------------
# 7. Données brutes en lecture seule (après toutes les vérifications)
# ---------------------------------------------------------------
find "$EXTRACT_DIR" -type f -exec chmod a-w {} + \
    || log "AVERTISSEMENT : chmod impossible sur les fichiers extraits"

for f in "$ARCHIVE" "$MATRIX_GZ" "$MATRIX_TXT" \
         "$RAW_DIR/${SERIES_SOFT:-}" "$RAW_DIR/${PLATFORM_SOFT:-}"; do
    if [[ -f "$f" ]]; then
        chmod a-w "$f" || log "AVERTISSEMENT : chmod impossible sur $f"
    fi
done

if [[ -w "$ARCHIVE" ]]; then
    log "AVERTISSEMENT : les fichiers restent modifiables (système de fichiers sans permissions, ou exécution en root)."
else
    log "Données brutes en lecture seule."
fi

# ---------------------------------------------------------------
# 8. Journal
# ---------------------------------------------------------------
log "Nombre de fichiers extraits : $N_FILES (CEL : $N_CEL, CHP : $N_CHP)"
log "Extraction terminée avec succès."
