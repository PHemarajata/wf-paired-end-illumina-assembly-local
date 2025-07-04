process REMOVE_HOST_SRA_HUMAN_SCRUBBER {

    label "process_medium"
    tag { "${meta.id}" }
    container "quay.io/biocontainers/sra-human-scrubber@sha256:2f6b6635af9ba3190fc2f96640b21f0285483bd1f50d6be229228c52fb747055"

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

    script:
    def min_filesize_param = params.min_filesize_fastq_sra_human_scrubber_removed ?: ''
    def min_filesize_output_fastq = (min_filesize_param && min_filesize_param.matches(".*[ckb]\$")) ? min_filesize_param : "25000k"
    """
    #!/bin/bash
    set -euo pipefail

    source bash_functions.sh

    echo "--- DIAGNOSTIC INFORMATION ---"
    echo "R1 file path: ${reads[0]}"
    echo "R2 file path: ${reads[1]}"
    echo "Min filesize being used: ${min_filesize_output_fastq}"
    echo "------------------------------"

    if [ ! -f "${reads[0]}" ]; then
        echo "FATAL ERROR: R1 input file not found at path: ${reads[0]}" >&2
        exit 1
    fi
    if [ ! -f "${reads[1]}" ]; then
        echo "FATAL ERROR: R2 input file not found at path: ${reads[1]}" >&2
        exit 1
    fi

    msg "INFO: Removing host reads from ${meta.id} using SRA Human Scrubber with ${task.memory} RAM ..."

    if [[ "${reads[0]}" =~ \\.gz\$ ]]; then
        msg "INFO: Removing host reads from GZ compressed R1 file ${reads[0]} ..."
        zcat "${reads[0]}" | \\
            scrub.sh \\
            -d "${database}" \\
            -p "${task.cpus}" \\
            -x \\
            -o "${meta.id}_R1_scrubbed.fastq" \\
            2> scrub_R1.stderr.txt
    else
        msg "INFO: Removing host reads from uncompressed R1 file ${reads[0]} ..."
        scrub.sh \\
            -i "${reads[0]}" \\
            -d "${database}" \\
            -p "${task.cpus}" \\
            -x \\
            -o "${meta.id}_R1_scrubbed.fastq" \\
            2> scrub_R1.stderr.txt
    fi
    gzip -f "${meta.id}_R1_scrubbed.fastq"
    msg "INFO: Completed host reads removal from R1 file of ${meta.id}"

    if [[ "${reads[1]}" =~ \\.gz\$ ]]; then
        msg "INFO: Removing host reads from GZ compressed R2 file ${reads[1]} ..."
        zcat "${reads[1]}" | \\
            scrub.sh \\
            -d "${database}" \\
            -p "${task.cpus}" \\
            -x \\
            -o "${meta.id}_R2_scrubbed.fastq" \\
            2> scrub_R2.stderr.txt
    else
        msg "INFO: Removing host reads from uncompressed R2 file ${reads[1]} ..."
        scrub.sh \\
            -i "${reads[1]}" \\
            -d "${database}" \\
            -p "${task.cpus}" \\
            -x \\
            -o "${meta.id}_R2_scrubbed.fastq" \\
            2> scrub_R2.stderr.txt
    fi
    gzip -f "${meta.id}_R2_scrubbed.fastq"
    msg "INFO: Completed host reads removal from R2 file of ${meta.id}"

    R1_COUNT_READS_INPUT=\$(grep 'total read count:' scrub_R1.stderr.txt | awk -F ':' '{print \$2}' | sed 's/ //g')
    R1_COUNT_READS_REMOVED=\$(grep 'spot(s) masked or removed.' scrub_R1.stderr.txt | awk '{print \$1}')
    R1_COUNT_READS_OUTPUT=\$((R1_COUNT_READS_INPUT - R1_COUNT_READS_REMOVED))

    R2_COUNT_READS_INPUT=\$(grep 'total read count:' scrub_R2.stderr.txt | awk -F ':' '{print \$2}' | sed 's/ //g')
    R2_COUNT_READS_REMOVED=\$(grep 'spot(s) masked or removed.' scrub_R2.stderr.txt | awk '{print \$1}')
    R2_COUNT_READS_OUTPUT=\$((R2_COUNT_READS_INPUT - R2_COUNT_READS_REMOVED))

    COUNT_READS_INPUT=\$((R1_COUNT_READS_INPUT + R2_COUNT_READS_INPUT))
    COUNT_READS_REMOVED=\$((R1_COUNT_READS_REMOVED + R2_COUNT_READS_REMOVED))
    COUNT_READS_OUTPUT=\$((R1_COUNT_READS_OUTPUT + R2_COUNT_READS_OUTPUT))
    PERCENT_REMOVED=\$(echo "\${COUNT_READS_REMOVED}" "\${COUNT_READS_INPUT}" | awk '{proportion=\$1/\$2} END{printf("%.6f", proportion*100)}')
    PERCENT_OUTPUT=\$(echo "\${COUNT_READS_REMOVED}" "\${COUNT_READS_INPUT}" | awk '{proportion=\$1/\$2} END{printf("%.6f", 100-(proportion*100))}')

    for file in "${meta.id}_R1_scrubbed.fastq.gz" "${meta.id}_R2_scrubbed.fastq.gz"; do
        if verify_minimum_file_size "\${file}" 'SRA-Human-Scrubber-removed FastQ Files' "${min_filesize_output_fastq}"; then
            echo -e "${meta.id}\\tSRA-Human-Scrubber-removed FastQ (\${file}) File\\tPASS" >> "${meta.id}.SRA_Human_Scrubber_FastQ_File.tsv"
        else
            echo -e "${meta.id}\\tSRA-Human-Scrubber-removed FastQ (\${file}) File\\tFAIL" >> "${meta.id}.SRA_Human_Scrubber_FastQ_File.tsv"
        fi
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sha512sum: \$(sha512sum --version | grep ^sha512sum | sed 's/sha512sum //1')
        sra-human-scrubber: 2.2.1
    END_VERSIONS
    """
}
