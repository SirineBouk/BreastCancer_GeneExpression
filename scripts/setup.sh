#!/usr/bin/env bash

# Arrêter le script en cas d'erreur
set -euo pipefail

# ---------------------------------------------------------------
# 1. Charger la configuration commune
# ---------------------------------------------------------------
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config/config.sh"

if [[ ! -r "$CONFIG_FILE" ]]; then
    echo "ERREUR : configuration introuvable ou illisible : $CONFIG_FILE" >&2
    exit 1
fi
source "$CONFIG_FILE"

# Valeurs par défaut si la config ne définit pas ces variables
FIGURES_DIR="${FIGURES_DIR:-$RESULTS_DIR/figures}"
TABLES_DIR="${TABLES_DIR:-$RESULTS_DIR/tables}"
ARCHIVE_DIR="${ARCHIVE_DIR:-$RESULTS_DIR/archive}"
REQUIREMENTS_FILE="${REQUIREMENTS_FILE:-$PROJECT_DIR/requirements.txt}"
PYTHON="${PYTHON:-python3}"

# ---------------------------------------------------------------
# Journal et compteur d'erreurs
# ---------------------------------------------------------------
mkdir -p "$LOGS_DIR"
LOG_FILE="${LOG_FILE:-$LOGS_DIR/run_$(date +%Y%m%d_%H%M%S).log}"

log()   { local m="[$(date '+%F %T')] $*"; echo "$m"; echo "$m" >> "$LOG_FILE" 2>/dev/null || true; }
error() { local m="[$(date '+%F %T')] ERREUR : $*"; echo "$m" >&2; echo "$m" >> "$LOG_FILE" 2>/dev/null || true; }

errors=0
fail() { error "$*"; errors=$((errors + 1)); }

# ---------------------------------------------------------------
# 2. Créer les dossiers du projet
# ---------------------------------------------------------------
for dir in "$RAW_DIR" "$PROCESSED_DIR" \
           "$FIGURES_DIR" "$TABLES_DIR" "$ARCHIVE_DIR" \
           "$LOGS_DIR"; do
    if mkdir -p "$dir" 2>/dev/null; then
        log "Dossier prêt : $dir"
    else
        fail "impossible de créer le dossier : $dir"
    fi
done

# ---------------------------------------------------------------
# 3. Vérifier bash, puis les commandes nécessaires
# ---------------------------------------------------------------
if (( BASH_VERSINFO[0] < 4 )); then
    fail "bash 4 ou plus récent requis (version actuelle : $BASH_VERSION)"
else
    log "Bash disponible : $BASH_VERSION"
fi

# Commandes demandées par le cahier des charges :
#   tar sha256sum gzip awk grep sed cut sort uniq
# Commandes utilisées par nos scripts et par l'examen de la matrice GEO :
#   tr paste diff head tail wc find cmp realpath mktemp tee date df chmod mv cp rm
REQUIRED_CMDS=(tar sha256sum gzip awk grep sed cut sort uniq \
               tr paste diff head tail wc find cmp realpath mktemp \
               tee date df chmod mv cp rm)

for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
        fail "commande manquante : $cmd (installer avec : sudo apt install coreutils tar gzip gawk grep sed findutils diffutils)"
    fi
done

if command -v curl > /dev/null 2>&1; then
    log "Téléchargement : curl disponible."
elif command -v wget > /dev/null 2>&1; then
    log "AVERTISSEMENT : seul wget est disponible ; download.sh utilise curl (sudo apt install curl)."
else
    fail "ni curl ni wget n'est installé (sudo apt install curl)"
fi

# awk fonctionne-t-il avec les fonctions utilisées pour la matrice GEO ?
# (séparateur de tabulation, tableaux associatifs, delete, getline)
if command -v awk > /dev/null 2>&1; then
    awk_test="$(printf 'a\tb\n' | awk -F'\t' '{ t["x"]=$2; delete t; print NF }' 2>/dev/null || true)"
    if [[ "$awk_test" != "2" ]]; then
        fail "awk ne fonctionne pas comme attendu (installer gawk : sudo apt install gawk)"
    fi
fi

# ---------------------------------------------------------------
# 4. Vérifier Python 3
# ---------------------------------------------------------------
python_ok=false
if ! command -v "$PYTHON" > /dev/null 2>&1; then
    fail "Python 3 introuvable : $PYTHON (sudo apt install python3 python3-pip python3-venv)"
elif ! "$PYTHON" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)'; then
    fail "Python 3.8 ou plus récent requis (trouvé : $("$PYTHON" --version 2>&1))"
else
    python_ok=true
    log "Python disponible : $("$PYTHON" --version 2>&1)"
fi

# ---------------------------------------------------------------
# 5. Vérifier les bibliothèques de requirements.txt
# ---------------------------------------------------------------
if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
    fail "fichier introuvable : $REQUIREMENTS_FILE"
elif [[ "$python_ok" == true ]]; then
    missing=()
    n_packages=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Enlever commentaires et espaces
        pkg="$(echo "${line%%#*}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        if [[ -z "$pkg" || "$pkg" == -* ]]; then continue; fi
        # Garder seulement le nom (sans version, extras ni marqueurs)
        name="$(echo "$pkg" | sed -E 's/[][<>=!~;@ ].*$//')"
        if [[ -z "$name" ]]; then continue; fi
        n_packages=$((n_packages + 1))
        if ! "$PYTHON" -c 'import sys, importlib.metadata as m; m.version(sys.argv[1])' \
             "$name" > /dev/null 2>&1; then
            missing+=("$name")
        fi
    done < "$REQUIREMENTS_FILE"

    if (( ${#missing[@]} > 0 )); then
        fail "bibliothèques Python manquantes : ${missing[*]} (installer avec : $PYTHON -m pip install -r requirements.txt)"
    else
        log "Bibliothèques Python présentes ($n_packages vérifiées)."
    fi
fi

# ---------------------------------------------------------------
# 6. Vérifier les droits d'accès
# ---------------------------------------------------------------
for dir in "$RAW_DIR" "$PROCESSED_DIR" "$FIGURES_DIR" \
           "$TABLES_DIR" "$ARCHIVE_DIR" "$LOGS_DIR"; do
    if [[ -d "$dir" ]] && [[ ! -w "$dir" || ! -x "$dir" ]]; then
        fail "droits insuffisants (écriture/accès) sur : $dir"
    fi
done

for f in "$CONFIG_FILE" "$REQUIREMENTS_FILE"; do
    if [[ -f "$f" && ! -r "$f" ]]; then
        fail "fichier illisible : $f"
    fi
done

# Espace disque (avertissement seulement : archive 1 Go + extraction)
free_kb="$(df -Pk "$PROJECT_DIR" | awk 'NR==2 {print $4}')"
if [[ "$free_kb" =~ ^[0-9]+$ ]] && (( free_kb < 3145728 )); then
    log "AVERTISSEMENT : moins de 3 Go d'espace libre ($((free_kb / 1024)) Mo)."
fi

# ---------------------------------------------------------------
# 7. Résultat
# ---------------------------------------------------------------
if (( errors > 0 )); then
    error "$errors problème(s) détecté(s). Corriger puis relancer setup.sh."
    exit 1
fi

log "Environnement prêt."
