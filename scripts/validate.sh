#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MATRIX="$PROJECT_DIR/data/processed/expression_matrix.csv"
RESULTS="$PROJECT_DIR/results/tables/differentially_expressed_genes.csv"
FIGURE="$PROJECT_DIR/results/figures/volcano_plot.png"
REQUIRED_COLUMNS="probe_id,gene_symbol,mean_log2_fc,p_value,fdr"

fail() {
  echo "[ERREUR] $1" >&2
  exit 1
}

# Les fichiers existent et ne sont pas vides
for f in "$MATRIX" "$RESULTS" "$FIGURE"; do
  [ -s "$f" ] || fail "Fichier manquant ou vide : $f"
done

# Les colonnes du CSV sont les bonnes
HEADER="$(head -n 1 "$RESULTS" | tr -d '\r')"
[ "$HEADER" = "$REQUIRED_COLUMNS" ] || fail "Colonnes inattendues. Attendu : $REQUIRED_COLUMNS / Trouvé : $HEADER"

echo "[OK] Validation réussie"