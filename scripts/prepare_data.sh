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

