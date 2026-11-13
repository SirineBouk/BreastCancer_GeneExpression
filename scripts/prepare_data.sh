#!/bin/bash

# Display informational messages.
log_info() {
    echo "[INFO] $1"
}

# Display successful operation messages.
log_ok() {
    echo "[OK] $1"
}

# Display error messages.
log_error() {
    echo "[ERROR] $1" >&2
}

echo -e "\n[INFO] PRÉPARATION DES DONNÉES POUR L'ANALYSE\n"

# Check that all required files are present

log_info "Vérification des fichiers d'entrée..."
if [ ! -f "data/raw/GSE15852_series_matrix.txt.gz" ]; then
    log_error "Fichier Series Matrix introuvable"
    exit 1
fi

if [ ! -f "data/raw/GPL96.annot.gz" ]; then
    elog_error "Fichier d'annotation GPL96 introuvable"
    exit 1
fi
log_ok "Fichiers nécessaires disponibles."
echo

# Create the output directory data/processed
mkdir -p data/processed


# Extract GEO identifiers and sample information
# Build sample_metadata.csv
log_info "Préparation des métadonnées..."
zcat data/raw/GSE15852_series_matrix.txt.gz | awk -F '\t' '

BEGIN {
    OFS = ","
    print "sample_id", "patient_id", "condition"
}

# Store the GEO sample IDs
/^!Sample_geo_accession/ {
    for (i = 2; i <= NF; i++) {
        ids[i] = $i
    }
    number_ids = NF - 1
}

# Store the sample titles
/^!Sample_title/ {
    for (i = 2; i <= NF; i++) {
        titles[i] = $i
    }
    number_titles = NF - 1
}

END {
    if (number_ids != 86 || number_titles != 86) {
        print "[ERROR] Nombre attendu : 86 échantillons et 86 titres." > "/dev/stderr"
        exit 1
    }

    # Process each sample and extract its metadata
    for (i = 2; i <= 87; i++) {

        sample_id = ids[i]
        title = titles[i]

        gsub(/"/, "", sample_id)
        gsub(/"/, "", title)

        # Separate condition and patient code
        split(title, parts, " ")

        condition = parts[1]
        patient_id = parts[2]

        # Standardize "Cancer" as "Tumor"
        if (condition == "Cancer") {
            condition = "Tumor"
        }

        # Remove the final N or T from the patient code
        sub(/[NT]$/, "", patient_id)

        # Write the sample information as a CSV row
        print sample_id, patient_id, condition
    }
}
' > data/processed/sample_metadata.csv
log_ok "Fichier généré : sample_metadata.csv"

# Validate the generated metadata
awk -F ',' '

NR == 1 {
    next
}

{
    rows++

    sample_id = $1
    patient_id = $2
    condition = $3

    # Check for missing information.
    if (sample_id == "" || patient_id == "") {
        print "[ERROR] Identifiant d'\''échantillon ou de patient manquant." > "/dev/stderr"
        errors = 1
    }

    # Check for duplicate sample IDs.
    if (sample_id != "" && seen_sample[sample_id]++) {
        print "[ERROR] Identifiant d'\''échantillon dupliqué :", sample_id > "/dev/stderr"
        errors = 1
    }

    # Count Normal and Tumor samples for each patient.
    if (condition == "Normal") {
        normal[patient_id]++
        normal_count++
    }
    else if (condition == "Tumor") {
        tumor[patient_id]++
        tumor_count++
    }
    else {
        print "[ERROR] Condition d'\''échantillon invalide :", condition > "/dev/stderr"
        errors = 1
    }

    patients[patient_id] = 1
}

END {

    # Check that every patient has exactly one Normal and one Tumor sample.
    for (patient in patients) {
        patient_count++

        if (normal[patient] != 1 || tumor[patient] != 1) {
            print "[ERROR] Paire incomplète pour le patient :", patient > "/dev/stderr"
            errors = 1
        }
    }

    # Check the expected dataset dimensions.
    if (rows != 86 || patient_count != 43) {
        print "[ERROR] Nombre incorrect d'\''échantillons ou de patients." > "/dev/stderr"
        errors = 1
    }

    if (errors) {
        exit 1
    }

}
' data/processed/sample_metadata.csv || exit 1
log_ok "Validation réussie : 86 échantillons (43 Normaux, 43 Tumoraux)."
echo


# Extract the expression table and create expression_matrix.csv.
log_info "Génération de la matrice d'expression..."
zcat data/raw/GSE15852_series_matrix.txt.gz | awk -F '\t' '

BEGIN {
    OFS = ","
}

# Detect the beginning of the expression table.
/^!series_matrix_table_begin/ {
    in_table = 1
    next
}

# Stop when the end of the expression table is reached.
/^!series_matrix_table_end/ {
    exit
}

# Process the header and expression data.
in_table {

    # Remove quotation marks from every field.
    for (i = 1; i <= NF; i++) {
        gsub(/"/, "", $i)
    }

    # Rename ID_REF to probe_id.
    if ($1 == "ID_REF") {
        $1 = "probe_id"
    }

    # Write the current row.
    print
}

' > data/processed/expression_matrix.csv
log_ok "Fichier généré : expression_matrix.csv"

# Validate the expression matrix.
if [ ! -s "data/processed/expression_matrix.csv" ]; then
    log_error "La matrice d'expression est absente ou vide"
    exit 1
fi

awk -F ',' '

# First file: read the sample IDs from sample_metadata.csv.
FNR == NR {
    if (FNR > 1) {
        expected[++sample_count] = $1
    }
    next
}

# Second file: validate the expression matrix header.
FNR == 1 {

    if ($1 != "probe_id") {
        print "[ERROR] La première colonne doit être probe_id." > "/dev/stderr"
        errors = 1
    }

    if (NF != 87) {
        print "[ERROR] Le nombre attendu de colonnes dans l'\''en-tête est 87." > "/dev/stderr"
        errors = 1
    }

    # Compare the sample IDs with the metadata file.
    for (i = 2; i <= NF; i++) {
        if ($i != expected[i - 1]) {
            print "[ERROR] Identifiant d'\''échantillon incorrect à la colonne", i > "/dev/stderr"
            errors = 1
        }
    }

    next
}

# Validate each expression row.
{
    rows++

    # Check the number of columns.
    if (NF != 87) {
        print "[ERROR] Nombre incorrect de colonnes à la ligne", FNR > "/dev/stderr"
        errors = 1
    }

    # Check for missing or duplicate probe IDs.
    if ($1 == "") {
        print "[ERROR] Identifiant de sonde manquant à la ligne", FNR > "/dev/stderr"
        errors = 1
    }

    if ($1 != "" && seen_probe[$1]++) {
        print "[ERROR] Identifiant de sonde dupliqué :", $1 > "/dev/stderr"
        errors = 1
    }

    # Check that expression values are numeric.
    for (i = 2; i <= NF; i++) {
        if ($i !~ /^-?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][-+]?[0-9]+)?$/) {
            print "[ERROR] Valeur d'\''expression non numérique à la ligne", FNR, "colonne", i > "/dev/stderr"
            errors = 1
        }
    }
}

END {

    if (sample_count != 86) {
        print "[ERROR] Les métadonnées doivent contenir 86 échantillons." > "/dev/stderr"
        errors = 1
    }

    if (rows == 0) {
        print "[ERROR] La matrice d'\''expression ne contient aucune ligne de données." > "/dev/stderr"
        errors = 1
    }

    if (errors) {
        exit 1
    }

}
' data/processed/sample_metadata.csv data/processed/expression_matrix.csv || exit 1
log_ok "Validation réussie : 22283 sondes × 86 échantillons."
echo

# Extract probe annotations and create probe_annotation.csv
log_info "Extraction des annotations des sondes..."
zcat data/raw/GPL96.annot.gz | awk -F '\t' '

BEGIN {
    OFS = ","
}

# Detect the beginning of the annotation table.
/^!platform_table_begin/ {
    in_table = 1
    next
}

# Stop at the end of the annotation table.
/^!platform_table_end/ {
    exit
}

# Skip the header and write our own CSV header.
in_table && !header {
    print "probe_id", "gene_symbol", "entrez_id"
    header = 1
    next
}

# Extract the three required columns.
in_table {
    probe_id = $1
    gene_symbol = $3
    entrez_id = $4

    # Remove quotation marks if present.
    gsub(/"/, "", probe_id)
    gsub(/"/, "", gene_symbol)
    gsub(/"/, "", entrez_id)

    # Write the annotation information.
    print probe_id, gene_symbol, entrez_id
}

' > data/processed/probe_annotation.csv
log_ok "Fichier généré : probe_annotation.csv"

# Validate the probe annotation file
if [ ! -s "data/processed/probe_annotation.csv" ]; then
    log_error "Le fichier d'annotation des sondes est absent ou vide"
    exit 1
fi

awk -F ',' '

NR == 1 {
    if ($1 != "probe_id" || $2 != "gene_symbol" || $3 != "entrez_id") {
        print "[ERROR] En-tête du fichier d'\''annotation incorrect." > "/dev/stderr"
        errors = 1
    }
    next
}

{
    rows++

    # Check that every row has three columns.
    if (NF != 3) {
        print "[ERROR] Nombre incorrect de colonnes à la ligne", NR > "/dev/stderr"
        errors = 1
    }

    # Check for missing probe IDs.
    if ($1 == "") {
        print "[ERROR] Identifiant de sonde manquant à la ligne", NR > "/dev/stderr"
        errors = 1
    }

    # Check for duplicate probe IDs.
    if ($1 != "" && seen[$1]++) {
        print "[ERROR] Identifiant de sonde dupliqué :", $1 > "/dev/stderr"
        errors = 1
    }

    # Count missing gene annotations.
    if ($2 == "" || $3 == "") {
        missing_annotations++
    }
}

END {
    if (rows == 0) {
        print "[ERROR] Aucun enregistrement d'\''annotation trouvé." > "/dev/stderr"
        errors = 1
    }

    if (errors) {
        exit 1
    }

}
' data/processed/probe_annotation.csv || exit 1
log_ok "Validation réussie : 22283 sondes annotées."
echo

# Compare expression probes with annotation records to ensure
# that every probe in the expression matrix has a matching annotation
log_info "Vérification de la correspondance des sondes..."
awk -F ',' '

BEGIN {
    missing = 0
    expression_count = 0
}

NR == FNR {
    if (FNR > 1) {
        annotation[$1] = 1
    }
    next
}

FNR > 1 {
    if (!($1 in annotation)) {
        print "Missing annotation for probe:", $1
        missing++
    }
    expression_count++
}

END {
    if (missing == 0) {
        print "[OK] Correspondance vérifiée.\n"
    }
}
' data/processed/probe_annotation.csv data/processed/expression_matrix.csv
log_ok "PRÉPARATION DES DONNÉES TERMINÉE AVEC SUCCÈS"