#!/bin/bash

# Exit on any error
set -e

# --- 1. Input check ---
if [[ -z "$1" ]]; then
    echo "Usage: $0 /path/to/fastq_dir"
    exit 1
fi

input_dir="${1%/}"  # remove trailing slash
output_csv="$input_dir/fastq_pairs.csv"

# --- 2. Write header ---
echo "sample,fastq_1,fastq_2" > "$output_csv"

# --- 3. Find all R1 files with accepted patterns ---
find "$input_dir" -type f \( \
    -name "*_R1_*.fastq.gz" -o -name "*_R1_*.fq.gz" -o \
    -name "*_1.fastq.gz" -o -name "*_1.fq.gz" \
\) | sort | while read -r r1_file; do

    # Determine R2 file by replacing "_R1_" or "_1" with "_R2_" or "_2"
    if [[ "$r1_file" == *_R1_* ]]; then
        r2_file="${r1_file/_R1_/_R2_}"
    elif [[ "$r1_file" == *_1.fastq.gz ]]; then
        r2_file="${r1_file/_1.fastq.gz/_2.fastq.gz}"
    elif [[ "$r1_file" == *_1.fq.gz ]]; then
        r2_file="${r1_file/_1.fq.gz/_2.fq.gz}"
    else
        continue
    fi

    # Only proceed if matching R2 exists
    if [[ -f "$r2_file" ]]; then
        base_r1=$(basename "$r1_file")

        # Sample name = filename before _R1_ or _1
        if [[ "$base_r1" == *_R1_* ]]; then
            sample_id="${base_r1%%_R1_*}"
        else
            sample_id="${base_r1%%_1.*}"
        fi

        # Check for other replicates
        count=$(find "$input_dir" -type f -name "${sample_id}_R1_*.fastq.gz" -o -name "${sample_id}_1.fastq.gz" | wc -l)
        sample_name="${sample_id}_REP${count}"

        echo "$sample_name,$(realpath "$r1_file"),$(realpath "$r2_file")" >> "$output_csv"
    fi
done

echo "✅ CSV written to: $output_csv"
