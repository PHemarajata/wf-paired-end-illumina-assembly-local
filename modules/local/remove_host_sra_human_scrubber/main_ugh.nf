process REMOVE_HOST_SRA_HUMAN_SCRUBBER {

    label "process_medium"
    tag { "${meta.id}" }
    container "quay.io/biocontainers/sra-human-scrubber@sha256:2f6b6635af9ba3190fc2f96640b21f0285483bd1f50d6be229228c52fb747055"

    // This is the critical directive. It tells Nextflow to physically COPY the
    // input files into the working directory, not symlink them. This is the
    // most robust solution for cloud executors and resolves the file-not-found issue.
    stageInMode = 'copy'

    input:
    tuple val(meta), path(reads)
    path(database)

    output:
    tuple val(meta), path("${meta.id}.SRA_Human_Scrubber_FastQ_File.tsv"), emit: qc_filecheck
    tuple val(meta), path("${meta.id}_R*_scrubbed.fastq.gz")             , emit: host_removed_reads
    path("${meta.id}.SRA_Human_Scrubber_Removal.tsv")                    , emit: summary
    path("${meta.id}.SRA_Human_Scrubber_FastQ.SHA512-checksums.tsv")     , emit: checksums
    path(".command.{out,err}")
    path("versions.yml")                                                 , emit: versions

    shell:
    // With stageInMode='copy', the `reads` files are now physically present in
    // the current directory, so we can refer to them by their simple names.
    '''
    #!/bin/bash
    set -euo pipefail

    source bash_functions.sh

    R1_FILENAME="!{reads[0]}"
    R2_FILENAME="!{reads[1]}"

    echo "--- DIAGNOSTIC INFORMATION ---"
    echo "Staging mode is 'copy'. Directory content:"
    ls -laR
    echo "------------------------------"

    # Remove Host Reads
    msg "INFO: Removing host reads from !{meta.id} ..."

    # --- R1 Scrubbing ---
    if [[ "${R1_FILENAME}" == *.gz ]]; then
        zcat ${R1_FILENAME} | \
            scrub.sh -d !{database} -p !{task.cpus} -x -o "!{meta.id}_R1_scrubbed.fastq" 2> scrub_R1.stderr.txt
    else
        scrub.sh -i ${R1_FILENAME} -d !{database} -p !{task.cpus} -x -o "!{meta.id}_R1_scrubbed.fastq" 2> scrub_R1.stderr.txt
    fi
    gzip -f "!{meta.id}_R1_scrubbed.fastq"

    # --- R2 Scrubbing ---
    if [[ "${R2_FILENAME}" == *.gz ]]; then
        zcat ${R2_FILENAME} | \
            scrub.sh -d !{database} -p !{task.cpus} -x -o "!{meta.id}_R2_scrubbed.fastq" 2> scrub_R2.stderr.txt
    else
        scrub.sh -i ${R2_FILENAME} -d !{database} -p !{task.cpus} -x -o "!{meta.id}_R2_scrubbed.fastq" 2> scrub_R2.stderr.txt
    fi
    gzip -f "!{meta.id}_R2_scrubbed.fastq"

    # --- Parsing and Summary (with robust checks for empty files) ---
    R1_COUNT_READS_INPUT=$(grep 'total read count:' scrub_R1.stderr.txt | awk -F: '{print $2}' | sed 's/ //g' || echo 0)
    R1_COUNT_READS_REMOVED=$(grep 'spot(s) masked or removed.' scrub_R1.stderr.txt | awk '{print $1}' || echo 0)
    [[ -z "${R1_COUNT_READS_INPUT}" ]] && R1_COUNT_READS_INPUT=0
    [[ -z "${R1_COUNT_READS_REMOVED}" ]] && R1_COUNT_READS_REMOVED=0
    R1_COUNT_READS_OUTPUT=$((R1_COUNT_READS_INPUT - R1_COUNT_READS_REMOVED))

    R2_COUNT_READS_INPUT=$(grep 'total read count:' scrub_R2.stderr.txt | awk -F: '{print $2}' | sed 's/ //g' || echo 0)
    R2_COUNT_READS_REMOVED=$(grep 'spot(s) masked or removed.' scrub_R2.stderr.txt | awk '{print $1}' || echo 0)
    [[ -z "${R2_COUNT_READS_INPUT}" ]] && R2_COUNT_READS_INPUT=0
    [[ -z "${R2_COUNT_READS_REMOVED}" ]] && R2_COUNT_READS_REMOVED=0
    R2_COUNT_READS_OUTPUT=$((R2_COUNT_READS_INPUT - R2_COUNT_READS_REMOVED))

    COUNT_READS_INPUT=$((R1_COUNT_READS_INPUT + R2_COUNT_READS_INPUT))
    COUNT_READS_REMOVED=$((R1_COUNT_READS_REMOVED + R2_COUNT_READS_REMOVED))
    COUNT_READS_OUTPUT=$((R1_COUNT_READS_OUTPUT + R2_COUNT_READS_OUTPUT))
    PERCENT_REMOVED=$(awk -v r="${COUNT_READS_REMOVED}" -v i="${COUNT_READS_INPUT}" 'BEGIN {if (i>0) {printf "%.6f", r/i*100} else {print "0.000000"} }')
    PERCENT_OUTPUT=$(awk -v r="${COUNT_READS_REMOVED}" -v i="${COUNT_READS_INPUT}" 'BEGIN {if (i>0) {printf "%.6f", 100-(r/i*100)} else {print "100.000000"} }')

    # Get process version information
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        sha512sum: \$(sha512sum --version | grep ^sha512sum | sed 's#sha512sum ##1')
        sra-human-scrubber: 2.2.1
    END_VERSIONS
    '''
}
