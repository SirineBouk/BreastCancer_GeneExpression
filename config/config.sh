
#!/usr/bin/env bash

# ============================================================
# CONFIGURATION GENERALE DU PROJET
# ============================================================

# Chemin absolu du projet
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Dossiers principaux
DATA_DIR="$PROJECT_DIR/data"
RAW_DIR="$DATA_DIR/raw"
PROCESSED_DIR="$DATA_DIR/processed"

RESULTS_DIR="$PROJECT_DIR/results"
LOGS_DIR="$PROJECT_DIR/logs"

# Fichiers GEO
GEO_ACCESSION="GSE15852"

RAW_ARCHIVE="GSE15852_RAW.tar"
SERIES_MATRIX="GSE15852_series_matrix.txt.gz"

# Fichiers de téléchargement
RAW_URL="https://ftp.ncbi.nlm.nih.gov/geo/series/GSE15nnn/GSE15852/suppl/GSE15852_RAW.tar"
MATRIX_URL="https://ftp.ncbi.nlm.nih.gov/geo/series/GSE15nnn/GSE15852/matrix/GSE15852_series_matrix.txt.gz"

# Plateforme GEO
PLATFORM="GPL96"

# Options générales
FORCE=false
VERBOSE=false
# Fichiers d'annotations GEO
SERIES_SOFT="GSE15852_family.soft.gz"
PLATFORM_SOFT="GPL96.annot.gz"

# URLs des annotations
SERIES_SOFT_URL="https://ftp.ncbi.nlm.nih.gov/geo/series/GSE15nnn/GSE15852/soft/GSE15852_family.soft.gz"

PLATFORM_SOFT_URL="https://ftp.ncbi.nlm.nih.gov/geo/platforms/GPLnnn/GPL96/annot/GPL96.annot.gz"
