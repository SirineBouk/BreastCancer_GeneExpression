#!/usr/bin/env bash
set -euo pipefail

# Dossier racine du projet
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_DIR="$PROJECT_DIR/results/archive"

# Vérifier que les dossiers à archiver existent
for d in results/tables results/figures; do
  if [ ! -d "$PROJECT_DIR/$d" ]; then
    echo "[ERREUR] Dossier introuvable : $d" >&2
    exit 1
  fi
done

mkdir -p "$ARCHIVE_DIR"

DATE="$(date +%Y%m%d_%H%M%S)"
ARCHIVE="$ARCHIVE_DIR/results_${DATE}.tar.gz"

# Créer l'archive
tar -czf "$ARCHIVE" -C "$PROJECT_DIR" results/tables results/figures

# Vérifier qu'elle est lisible
tar -tzf "$ARCHIVE" > /dev/null

echo "[OK] Archive créée : $ARCHIVE"