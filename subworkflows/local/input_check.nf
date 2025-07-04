//
// Check input samplesheet and get read channels
// Adapted from https://github.com/nf-core/mag
//

workflow INPUT_CHECK {

    take:
    ch_input    // channel: path

    main:
    ch_versions = Channel.empty()
    ch_raw_reads = Channel.empty()
    ch_input_rows = Channel.empty()

    // This logic handles directory input, using `params.input` to ensure
    // it always uses the full, correct `gs://` path from the command line.
    if (!ch_input.toString().endsWith(".csv") && !ch_input.toString().endsWith(".tsv") && !ch_input.toString().endsWith(".xlsx")) {
        Channel
            .fromPath( "${params.input}/*_R{1,2}_*.fastq.gz", checkIfExists: false )
            .ifEmpty { exit 1, "Cannot find any reads matching pattern *_R{1,2}_*.fastq.gz in '${params.input}'.\nNB: Path needs to be enclosed in quotes!" }
            // This filter is the critical fix. It removes any null or non-file objects
            // from the channel, preventing the "Cannot get property 'name' on null object" error.
            .filter { it != null && it.isFile() }
            .map { file ->
                // Create a tuple where the first element is a sample ID derived from the filename
                // and the second is the file's full Path object.
                def sample_id = file.name.replaceAll(/_L001_R[12]_001\.fastq\.gz$|_R[12]_001\.fastq\.gz$/, '')
                return [ sample_id, file ]
            }
            .groupTuple() // Group the files by the sample ID
            .map { sample_id, files ->
                // Create the final [meta, [R1, R2]] structure
                def meta = [id: sample_id]
                // Ensure R1 is always first by sorting the file list
                def sorted_files = files.sort()
                return [ meta, sorted_files ]
            }
            .set { ch_raw_reads }
    } else {
        // This block is for samplesheet inputs and will not be executed in your case.
        // It's included to maintain the structure of the original workflow.
        exit 1, "This simplified script is intended for directory input. Samplesheet functionality needs to be restored from the original repo if needed."
    }


    emit:
    raw_reads = ch_raw_reads    // channel: [ val(meta), [reads] ]
    versions  = ch_versions
}
