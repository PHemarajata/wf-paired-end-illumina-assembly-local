process INFILE_HANDLING_UNIX {

    tag { "${meta.id}" }
    container "ubuntu:jammy"

    // This is the critical directive. It forces Nextflow to physically COPY
    // the input files into this process's working directory. This makes them
    // available as real files for this process's script and for all
    // downstream processes.
    stageInMode = 'copy'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}.Raw_Initial_FastQ_Size_of_File.tsv"), emit: qc_filecheck
    tuple val(meta), path(reads)                                          , emit: input
    path("${meta.id}.Input_FastQ.SHA512-checksums.tsv")                   , emit: checksums
    path(".command.{out,err}")
    path("versions.yml")                                                  , emit: versions

    shell:
    // With stageInMode = 'copy', the 'reads' variables now refer to physical
    // files in the current directory, and the script will work correctly.
    '''
    source bash_functions.sh

    msg "INFO: Read 1: !{reads[0]}"
    msg "INFO: Read 2: !{reads[1]}"

    ### Evaluate Filesize of each Input FastQ file ###
    echo -e "Sample_name\\tQC_step\\tOutcome_(Pass/Fail)" > "!{meta.id}.Raw_Initial_FastQ_Size_of_File.tsv"

    i=1
    for fastq in !{reads}; do
      # Check if input FastQ file meets minimum file size requirement
      if verify_minimum_file_size "${fastq}" 'Raw Initial FastQ Files' "!{params.min_filesize_fastq_input}"; then
        echo -e "!{meta.id}\\tRaw Initial FastQ (R${i}) Filesize\\tPASS" >> "!{meta.id}.Raw_Initial_FastQ_Size_of_File.tsv"
      else
        msg "ERROR: R${i} file for !{meta.id}: ${fastq} is not at least !{params.min_filesize_fastq_input} in size" >&2
        echo -e "!{meta.id}\\tRaw Initial FastQ (R${i}) Filesize\\tFAIL" >> "!{meta.id}.Raw_Initial_FastQ_Size_of_File.tsv"
      fi
      ((i++))
    done

    ### Calculate SHA-512 Checksums of each Input FastQ file ###
    SUMMARY_HEADER=(
      "Sample_name"
      "Checksum_(SHA-512)"
      "File"
    )
    SUMMARY_HEADER=$(printf "%s\\t" "${SUMMARY_HEADER[@]}" | sed 's/\\t$//')

    echo "${SUMMARY_HEADER}" > "!{meta.id}.Input_FastQ.SHA512-checksums.tsv"

    # Now that files are local, this 'find' command will work correctly.
    find . -type f -name '*_R{1,2}_*.fastq.gz' | while read f; do
      echo -ne "!{meta.id}\\t" >> "!{meta.id}.Input_FastQ.SHA512-checksums.tsv"
      BASE="$(basename ${f})"
      HASH=$(zcat "${f}" | awk 'NR%2==0' | paste - - | sort -k1,1 | sha512sum | awk '{print $1}')
      echo -e "${HASH}\\t${BASE}"
    done >> "!{meta.id}.Input_FastQ.SHA512-checksums.tsv"

    # Get process version information
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        find: $(find --version | grep ^find | sed 's/find //1')
        sha512sum: $(sha512sum --version | grep ^sha512sum | sed 's/sha512sum //1')
        ubuntu: $(awk -F ' ' '{print $2,$3}' /etc/issue | tr -d '\\n')
    END_VERSIONS
    '''
}
