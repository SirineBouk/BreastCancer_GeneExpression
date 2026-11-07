#!/bin/bash

# Check that all required files are present

if [ ! -f "data/raw/GSE15852_series_matrix.txt.gz" ]; then
    echo "Series Matrix file not found."
    exit 1
fi

if [ ! -f "data/raw/GPL96.annot.gz" ]; then
    echo "GPL96 annotation file not found."
    exit 1
fi

# Create the output directory data/processed

mkdir -p data/processed


# Extract GEO identifiers and sample information
# Build sample_metadata.csv

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
        print "Error: expected 86 samples and 86 titles." > "/dev/stderr"
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
        print "Error: missing sample or patient ID." > "/dev/stderr"
        errors = 1
    }

    # Check for duplicate sample IDs.
    if (sample_id != "" && seen_sample[sample_id]++) {
        print "Error: duplicate sample ID:", sample_id > "/dev/stderr"
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
        print "Error: invalid condition:", condition > "/dev/stderr"
        errors = 1
    }

    patients[patient_id] = 1
}

END {

    # Check that every patient has exactly one Normal and one Tumor sample.
    for (patient in patients) {
        patient_count++

        if (normal[patient] != 1 || tumor[patient] != 1) {
            print "Error: incomplete pair for patient:", patient > "/dev/stderr"
            errors = 1
        }
    }

    # Check the expected dataset dimensions.
    if (rows != 86 || patient_count != 43) {
        print "Error: incorrect number of samples or patients." > "/dev/stderr"
        errors = 1
    }

    if (errors) {
        exit 1
    }

    print "Metadata validation successful!"
    print "Total samples:", rows
    print "Total patients:", patient_count
    print "Normal samples:", normal_count
    print "Tumor samples:", tumor_count
}
' data/processed/sample_metadata.csv || exit 1


# Extract the expression table and create expression_matrix.csv.

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

# Validate the expression matrix.

if [ ! -s "data/processed/expression_matrix.csv" ]; then
    echo "Error: expression matrix is missing or empty." >&2
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
        print "Error: first column must be probe_id." > "/dev/stderr"
        errors = 1
    }

    if (NF != 87) {
        print "Error: expected 87 columns in the header." > "/dev/stderr"
        errors = 1
    }

    # Compare the sample IDs with the metadata file.
    for (i = 2; i <= NF; i++) {
        if ($i != expected[i - 1]) {
            print "Error: sample ID mismatch at column", i > "/dev/stderr"
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
        print "Error: incorrect number of columns at line", FNR > "/dev/stderr"
        errors = 1
    }

    # Check for missing or duplicate probe IDs.
    if ($1 == "") {
        print "Error: missing probe ID at line", FNR > "/dev/stderr"
        errors = 1
    }

    if ($1 != "" && seen_probe[$1]++) {
        print "Error: duplicate probe ID:", $1 > "/dev/stderr"
        errors = 1
    }

    # Check that expression values are numeric.
    for (i = 2; i <= NF; i++) {
        if ($i !~ /^-?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][-+]?[0-9]+)?$/) {
            print "Error: invalid expression value at line", FNR, "column", i > "/dev/stderr"
            errors = 1
        }
    }
}

END {

    if (sample_count != 86) {
        print "Error: metadata must contain 86 samples." > "/dev/stderr"
        errors = 1
    }

    if (rows == 0) {
        print "Error: expression matrix contains no data rows." > "/dev/stderr"
        errors = 1
    }

    if (errors) {
        exit 1
    }

    print "Expression matrix validation successful!"
    print "Number of samples:", sample_count
    print "Number of probes:", rows
}
' data/processed/sample_metadata.csv data/processed/expression_matrix.csv || exit 1

# Extract probe annotations and create probe_annotation.csv

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

# Validate the probe annotation file

if [ ! -s "data/processed/probe_annotation.csv" ]; then
    echo "Error: probe annotation file is missing or empty." >&2
    exit 1
fi

awk -F ',' '

NR == 1 {
    if ($1 != "probe_id" || $2 != "gene_symbol" || $3 != "entrez_id") {
        print "Error: incorrect annotation header." > "/dev/stderr"
        errors = 1
    }
    next
}

{
    rows++

    # Check that every row has three columns.
    if (NF != 3) {
        print "Error: incorrect number of columns at line", NR > "/dev/stderr"
        errors = 1
    }

    # Check for missing probe IDs.
    if ($1 == "") {
        print "Error: missing probe ID at line", NR > "/dev/stderr"
        errors = 1
    }

    # Check for duplicate probe IDs.
    if ($1 != "" && seen[$1]++) {
        print "Error: duplicate probe ID:", $1 > "/dev/stderr"
        errors = 1
    }

    # Count missing gene annotations.
    if ($2 == "" || $3 == "") {
        missing_annotations++
    }
}

END {
    if (rows == 0) {
        print "Error: no annotation records found." > "/dev/stderr"
        errors = 1
    }

    if (errors) {
        exit 1
    }

    print "Probe annotation validation successful!"
    print "Number of annotated probes:", rows
    print "Missing gene annotations:", missing_annotations
}
' data/processed/probe_annotation.csv || exit 1

# Compare expression probes with annotation records to ensure
# that every probe in the expression matrix has a matching annotation
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
    print "Expression probes:", expression_count
    print "Probes without annotation records:", missing
    
    if (missing == 0) {
    print "All expression probes have matching annotation records!"
}
}
' data/processed/probe_annotation.csv data/processed/expression_matrix.csv