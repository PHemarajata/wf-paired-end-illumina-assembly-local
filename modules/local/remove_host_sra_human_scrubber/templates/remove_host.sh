#!/bin/bash
set -euo pipefail

source bash_functions.sh

# --- EXPLICIT FILE DOWNLOAD ---
# This section uses gsutil to reliably copy the input files from GCS into the
# local working directory. This bypasses Nextflow's fragile symlinking.
R1_FILENAME=$(basename !{reads[0]})
R2_FILENAME=$(basename !{reads[1]})
INPUT_DIR="!{input_dir}"

echo "INFO: Downloading !{R1_FILENAME} from ${INPUT_DIR}..."
gsutil -q cp "${INPUT_DIR}/${R1_FILENAME}" .

echo "INFO: Downloading !{R2_FILENAME} from ${INPUT_DIR}..."
gsutil -q cp "${INPUT_DIR}/${R2_FILENAME}" .

# --- SCRIPT CONTINUES WITH LOCAL FILES ---

MIN_FILESIZE_PARAM="!{params.min_filesize_fastq_sra_human_scrubber_removed}"
if [[ "!{MIN_FILESIZE_PARAM}" == *[ckb] ]]; then
    MIN_FILESIZE_OUTPUT_FASTQ="!{MIN_FILESIZE_PARAM}"
else
    MIN_FILESIZE_OUTPUT_FASTQ="25000k"
fi

msg "INFO: Removing host reads from !{meta.id} ..."

# --- R1 Scrubbing ---
zcat ${R1_FILENAME} | \
    scrub.sh -d !{database} -p !{task.cpus} -x -o "!{meta.id}_R1_scrubbed.fastq" 2> scrub_R1.stderr.txt
gzip -f "!{meta.id}_R1_scrubbed.fastq"

# --- R2 Scrubbing ---
zcat ${R2_FILENAME} | \
    scrub.sh -d !{database} -p !{task.cpus} -x -o "!{meta.id}_R2_scrubbed.fastq" 2> scrub_R2.stderr.txt
gzip -f "!{meta.id}_R2_scrubbed.fastq"

# --- Parsing and Summary ---
R1_COUNT_READS_INPUT=$(grep 'total read count:' scrub_R1.stderr.txt | awk -F: '{print $2}' | sed 's/ //g')
R1_COUNT_READS_REMOVED=$(grep 'spot(s) masked or removed.' scrub_R1.stderr.txt | awk '{print $1}')
R1_COUNT_READS_OUTPUT=$((R1_COUNT_READS_INPUT - R1_COUNT_READS_REMOVED))

R2_COUNT_READS_INPUT=$(grep 'total read count:' scrub_R2.stderr.txt | awk -F: '{print $2}' | sed 's/ //g')
R2_COUNT_READS_REMOVED=$(grep 'spot(s) masked or removed.' scrub_R2.stderr.txt | awk '{print $1}')
R2_COUNT_READS_OUTPUT=$((R2_COUNT_READS_INPUT - R2_COUNT_READS_REMOVED))

COUNT_READS_INPUT=$((R1_COUNT_READS_INPUT + R2_COUNT_READS_INPUT))
COUNT_READS_REMOVED=$((R1_COUNT_READS_REMOVED + R2_COUNT_READS_REMOVED))
COUNT_READS_OUTPUT=$((R1_COUNT_READS_OUTPUT + R2_COUNT_READS_OUTPUT))

# ... (rest of the summary and checksum script is the same) ...
# Validate output files
for file in "!{meta.id}_R1_scrubbed.fastq.gz" "!{meta.id}_R2_scrubbed.fastq.gz"; do
    if verify_minimum_file_size "${file}" 'SRA-Human-Scrubber-removed' "${MIN_FILESIZE_OUTPUT_FASTQ}"; then
        echo -e "!{meta.id}\tSRA-Human-Scrubber-removed FastQ (${file}) File\tPASS" >> "!{meta.id}.SRA_Human_Scrubber_FastQ_File.tsv"
    else
        echo -e "!{meta.id}\tSRA-Human-Scrubber-removed FastQ (${file}) File\tFAIL" >> "!{meta.id}.SRA_Human_Scrubber_FastQ_File.tsv"
    fi
done

# Get process version information
cat <<-END_VERSIONS > versions.yml
"!{task.process}":
    sha512sum: $(sha512sum --version | grep ^sha512sum | sed 's/sha512sum //1')
    sra-human-scrubber: 2.2.1
END_VERSIONS
