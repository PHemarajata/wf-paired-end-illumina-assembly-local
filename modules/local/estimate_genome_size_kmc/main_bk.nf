process ESTIMATE_GENOME_SIZE_KMC {
    label 'process_medium'
    tag { "${meta.id}" }
    container 'staphb/kmc:3.2.1--h9f5acd7_1'

    // This directive forces Nextflow to physically copy the input FASTQ files,
    // which is required for this tool to function correctly on GCB.
    stageInMode = 'copy'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}.genome_size.txt"), emit: genome_size
    path "versions.yml"                               , emit: versions

    shell:
    '''
    #!/bin/bash
    set -euo pipefail

    # Create a file containing the list of input FASTQ files.
    # This is a more robust method than using process substitution e.g. @<()
    echo "!{reads[0]}" > file.list
    echo "!{reads[1]}" >> file.list

    # Run KMC to count k-mers
    kmc \
        -k27 \
        -m!{task.memory.giga} \
        -ci1 \
        -t!{task.cpus} \
        -fm \
        @file.list \
        kmc_db \
        .

    # Transform KMC output to a histogram format
    kmc_tools \
        transform \
        kmc_db \
        histogram \
        kmc_db.hist

    # Use genomesize.py script to estimate genome size from the k-mer histogram
    genomesize.py \
        -c 27 \
        -g \
        kmc_db.hist \
        | tail -n 1 \
        | cut -f 2 \
        > !{meta.id}.genome_size.txt

    # Add a check to ensure the output file is not empty. If it is,
    # the process will fail with a clear error message, preventing
    # downstream errors.
    if [ ! -s "!{meta.id}.genome_size.txt" ]; then
        echo "Error: genomesize.py did not produce a valid output for !{meta.id}." >&2
        exit 1
    fi

    # Get process version information
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        kmc: \$(kmc 2>&1 | grep KMC | sed 's/KMC //; s/,.*//')
        genomesize.py: 0.1.0
    END_VERSIONS
    '''
}
