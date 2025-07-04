process COUNT_TOTAL_BP_INPUT_READS_SEQKIT {
    tag { "${meta.id}" }
    container "quay.io/biocontainers/seqkit:2.3.0--h9ee0642_1"

    // This directive forces Nextflow to physically copy the input FASTQ files,
    // which is required for this tool to function correctly on GCB.
    stageInMode = 'copy'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}.input_total_bp.txt"), emit: input_total_bp
    path "versions.yml"                                  , emit: versions

    shell:
    '''
    #!/bin/bash
    set -euo pipefail

    # Use seqkit to get statistics from the FASTQ files
    seqkit stats !{reads[0]} !{reads[1]} -T -j !{task.cpus} > !{meta.id}.seqkit_stats.txt

    # This awk command is a more robust way to sum the 6th column (base pairs).
    # It correctly handles empty files and ensures a '0' is printed if there's no input,
    # preventing the process from failing silently.
    awk 'FNR > 1 { sum += $6 } END { print sum+0 }' !{meta.id}.seqkit_stats.txt > !{meta.id}.input_total_bp.txt

    # Get process version information
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        seqkit: \$(seqkit version | sed 's/seqkit version //')
    END_VERSIONS
    '''
}
