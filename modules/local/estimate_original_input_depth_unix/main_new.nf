process ESTIMATE_ORIGINAL_INPUT_DEPTH_UNIX {

    tag { "${meta.id}" }
    container "ubuntu:jammy"

    // This is the critical fix. It forces Nextflow to physically COPY the
    // input text files from the upstream processes into this job's working
    // directory, instead of using symbolic links that cannot be read.
    stageInMode = 'copy'

    input:
    tuple val(meta), path(bp)
    tuple val(meta2), path(size)

    output:
    tuple val(meta), path("${meta.id}.initial_depth.txt")            , emit: initial_depth
    tuple val(meta), path("${meta.id}.fraction_of_reads_to_use.txt") , emit: fraction
    path("versions.yml")                                             , emit: versions

    shell:
    '''
    source bash_functions.sh

    # With stageInMode='copy', !{bp} and !{size} now refer to physical files
    # in the current directory, and the cat command will succeed.
    bp=$(cat !{bp})
    size=$(cat !{size})

    # Add a check for division by zero
    if [ "${size}" -eq "0" ]; then
        msg "ERROR: Estimated genome size is zero, cannot calculate depth." >&2
        initial_depth=0
    else
        initial_depth=$(( ${bp} / ${size} ))
    fi
    
    msg "INFO: Estimated coverage depth of !{meta.id}: ${initial_depth}x"

    # Calculate the fraction of reads to subsample
    fraction_of_reads_to_use=$(awk \
        -v OFMT='%.6f' \
        -v initial_depth="${initial_depth}" \
        -v want_depth="!{params.depth}" \
        'BEGIN { if (initial_depth > 0) {i = want_depth / initial_depth} else {i=0}; print i}')

    if ! [[ ${fraction_of_reads_to_use} =~ ^[0-9.]+$ ]]; then
      msg "ERROR: unable to calculate fraction of reads to use: ${fraction_of_reads_to_use}" >&2
      exit 1
    fi
    msg "INFO: Fraction of reads to use: ${fraction_of_reads_to_use}"

    echo -n "${initial_depth}" > "!{meta.id}.initial_depth.txt"
    echo -n "${fraction_of_reads_to_use}" > "!{meta.id}.fraction_of_reads_to_use.txt"

    # Get process version information
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        ubuntu: $(awk -F ' ' '{print $2,$3}' /etc/issue | tr -d '\n')
    END_VERSIONS
    '''
}
