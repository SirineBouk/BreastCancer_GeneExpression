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

