#!/usr/bin/env bash

# ==========================================
# SCRIPT PRINCIPAL DU PROJET
# ==========================================

# 1. Activer la gestion stricte des erreurs
set -euo pipefail

# 2. Déterminer le chemin absolu du projet
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 3. Charger la configuration
source "$PROJECT_DIR/config/config.sh"

# 4. Lire les options
FORCE=false

usage() {
    echo "Utilisation : ./run.sh [-h] [-f]"
    echo "-h : afficher l'aide"
    echo "-f : forcer le recalcul"
}

while getopts ":hf" option; do
    case "$option" in
        h)
            usage
            exit 0
            ;;
        f)
            FORCE=true
            ;;
        \?)
            echo "Option invalide : -$OPTARG"
            usage
            exit 1
            ;;
    esac
done
# ==========================================
# 5. FONCTIONS REUTILISABLES
# ==========================================

# Afficher et enregistrer les messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Afficher une erreur et arrêter le programme
die() {
    log "ERREUR : $*"
    exit 1
}

# Nettoyer les fichiers temporaires
cleanup() {
    log "Nettoyage des fichiers temporaires..."
}

# Exécuter une étape du pipeline
run_step() {
    local description="$1"
    shift
    echo  
    log "Début : $description"

    "$@" || die "Échec : $description"

    log "Terminé : $description"
}
# ==========================================
# 6. JOURNALISATION ET GESTION DES ERREURS
# ==========================================

# Créer le dossier des journaux
mkdir -p "$LOGS_DIR"

# Créer un fichier journal horodaté
LOG_FILE="$LOGS_DIR/run_$(date '+%Y%m%d_%H%M%S').log"

# Rediriger les messages vers le terminal et le fichier journal
exec > >(tee -a "$LOG_FILE") 2>&1

# Gérer les erreurs
trap 'die "Erreur à la ligne $LINENO"' ERR

# Gérer les interruptions (Ctrl + C)
trap 'log "Exécution interrompue"; exit 130' INT

# Nettoyer à la fin du script
trap cleanup EXIT

log "Initialisation du projet"
# ==========================================
# 7. EXECUTION DU PIPELINE
# ==========================================

log "Début du pipeline"

run_step "Préparation de l'environnement" \
   source "$PROJECT_DIR/scripts/setup.sh" 
run_step "Téléchargement des données" \
    bash "$PROJECT_DIR/scripts/download.sh"

run_step "Extraction des données" \
    bash "$PROJECT_DIR/scripts/extract.sh"

run_step "Préparation des données" \
    bash "$PROJECT_DIR/scripts/prepare_data.sh"

run_step "Analyse des données" \
    python3 "$PROJECT_DIR/scripts/analyze.py"

run_step "Validation des résultats" \
    bash "$PROJECT_DIR/scripts/validate.sh"

run_step "Archivage des résultats" \
    bash "$PROJECT_DIR/scripts/archive.sh"

log "Pipeline terminé avec succès"
# Execute cleanup manually
trap - EXIT
cleanup

# Resume final
echo 
echo "Pipeline termine avec succes."
echo ""
echo "Resume :"
echo "  Jeu de donnees        : GSE15852"
echo "  Echantillons          : 86"
echo "  Tumeurs               : 43"
echo "  Tissus normaux        : 43"
echo "  Paires completes      : 43"
echo 
echo "  Fichier des resultats : results/tables/differentially_expressed_genes.csv"
echo "  Figures               : results/figures/"
echo "  Journal               : $LOG_FILE"
echo "  Archive               : ${ARCHIVE_DIR}/results_$(date '+%Y%m%d_%H%M%S').tar.gz"
echo 

exit 0 