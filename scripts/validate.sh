#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MATRIX="$PROJECT_DIR/data/processed/expression_matrix.csv"
METADATA="$PROJECT_DIR/data/processed/sample_metadata.csv"
RESULTS="$PROJECT_DIR/results/tables/differentially_expressed_genes.csv"
FIGURE="$PROJECT_DIR/results/figures/volcano_plot.png"
REQUIRED_COLUMNS="probe_id mean_tumor mean_normal log2fc statistic p_value fdr significant"

fail() {
  echo "[ERREUR] $1" >&2
  exit 1
}

# Les fichiers existent et ne sont pas vides
for f in "$MATRIX" "$METADATA" "$RESULTS" "$FIGURE"; do
  [ -s "$f" ] || fail "Fichier manquant ou vide : $f"
done

# Les colonnes obligatoires sont présentes dans le CSV des résultats
HEADER="$(head -n 1 "$RESULTS" | tr -d '\r')"
for col in $REQUIRED_COLUMNS; do
  echo "$HEADER" | tr ',' '\n' | grep -qx "$col" || fail "Colonne manquante dans le CSV : $col"
done

# Il y a au moins une ligne de données
[ "$(wc -l < "$RESULTS")" -ge 2 ] || fail "Le CSV ne contient aucune ligne de résultats"

echo "[OK] Validation réussie"