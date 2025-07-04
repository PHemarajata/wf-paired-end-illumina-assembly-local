process SUBSAMPLE_READS_TO_DEPTH_SEQKIT {
    label 'process_medium'
    tag { "${meta.id}" }
    container "quay.io/biocontainers/seqkit:2.3.0--h9ee0642_1"

    // This directive forces Nextflow to physically copy the input FASTQ files,
    // which is required for this tool to function correctly on GCB.
    stageInMode = 'copy'

    input:
    tuple val(meta), path(reads), path(fraction)

    output:
    tuple val(meta), path("${meta.id}_subsampled_R{1,2}.fastq.gz"), emit: subsampled_reads
    // FIX: Add the missing 'summary' output channel that the downsampling.nf
    // subworkflow is expecting.
    tuple val(meta), path("${meta.id}.subsampling_summary.tsv")   , emit: summary
    path "versions.yml"                                           , emit: versions

    shell:
    '''
    #!/bin/bash
    set -euo pipefail

    source bash_functions.sh

    FRACTION=`cat !{fraction}`
    msg "INFO: Subsampling !{meta.id} reads using a fraction of ${FRACTION}..."

    # FIX: The 'seqkit sample' command writes its summary to standard error (stderr).
    # We must use '2>' to redirect stderr to the output file, not '>'.
    seqkit \
        sample \
        -p ${FRACTION} \
        -j !{task.cpus} \
        -s !{params.seqkit_seed} \
        -2 \
        !{reads[0]} \
        !{reads[1]} \
        -o !{meta.id}_subsampled_R#.fastq.gz \
        2> !{meta.id}.subsampling_summary.tsv
    
    if [ ! -s "!{meta.id}.subsampling_summary.tsv" ]; then
        echo "ERROR: seqkit sample did not produce a summary file for !{meta.id}." >&2
        exit 1
    fi
    
    # Get process version information
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        seqkit: $(seqkit version | sed 's/seqkit version //')
    END_VERSIONS
    '''
}
