//
// Check input samplesheet and get read channels
// Adapted from https://github.com/nf-core/mag
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULES: Local modules
//
include { CONVERT_SAMPLESHEET_PYTHON } from "../../modules/local/convert_samplesheet_python/main"

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_MERGE_LANE_FILES     } from "./input_merge_lane_files"

def hasExtension(it, extension) {
    it.toString().toLowerCase().endsWith(extension.toLowerCase())
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN INPUT_CHECK WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow INPUT_CHECK {

    take:
    ch_input    // channel: path

    main:
    ch_versions = Channel.empty()

    if (hasExtension(ch_input, "csv")) {
        // Merge lanes if merged_lanes parameter is used
        INPUT_MERGE_LANE_FILES(ch_input)

        // Extracts read files from samplesheet CSV and distribute into channels
        ch_input_rows = INPUT_MERGE_LANE_FILES.out.output
            .splitCsv(header: true)
            .map { row ->
                    if (row.size() == 3) {
                        def id = row.sample
                        def sr1 = row.fastq_1 ? file(row.fastq_1, checkIfExists: true) : false
                        def sr2 = row.fastq_2 ? file(row.fastq_2, checkIfExists: true) : false
                        // Check if given combination is valid
                        if (!id) exit 1, "Invalid input samplesheet: sample can not be empty."
                        if (!sr1) exit 1, "Invalid input samplesheet: fastq_1 can not be empty."
                        if (!sr2) exit 1, "Invalid input samplesheet: fastq_2 can not be empty."
                        return [ id, sr1, sr2 ]
                    } else {
                        exit 1, "Input samplesheet contains row with ${row.size()} column(s). Expects 3."
                    }
                }
        // Separate reads
        ch_raw_reads = ch_input_rows
            .map { id, sr1, sr2 ->
                        def meta = [:]
                        meta.id  = id
                        return [ meta, [ sr1, sr2 ] ]
                }

        // Collect version info
        ch_versions = ch_versions.mix(INPUT_MERGE_LANE_FILES.out.versions)
    } else if (hasExtension(ch_input, "tsv")) {
        // Merge lanes if merged_lanes parameter is used
        INPUT_MERGE_LANE_FILES(ch_input)

        // Extracts read files from samplesheet TSV and distribute into channels
        ch_input_rows = INPUT_MERGE_LANE_FILES.out.output
            .splitCsv(header: true, sep:'\t')
            .map { row ->
                    if (row.size() == 3) {
                        def id = row.sample
                        def sr1 = row.fastq_1 ? file(row.fastq_1, checkIfExists: true) : false
                        def sr2 = row.fastq_2 ? file(row.fastq_2, checkIfExists: true) : false
                        // Check if given combination is valid
                        if (!id) exit 1, "Invalid input samplesheet: sample can not be empty."
                        if (!sr1) exit 1, "Invalid input samplesheet: fastq_1 can not be empty."
                        if (!sr2) exit 1, "Invalid input samplesheet: fastq_2 can not be empty."
                        return [ id, sr1, sr2 ]
                    } else {
                        exit 1, "Input samplesheet contains row with ${row.size()} column(s). Expects 3."
                    }
                }
        // Separate reads
        ch_raw_reads = ch_input_rows
            .map { id, sr1, sr2 ->
                        def meta = [:]
                        meta.id  = id
                        return [ meta, [ sr1, sr2 ] ]
                }

        // Collect version info
        ch_versions = ch_versions.mix(INPUT_MERGE_LANE_FILES.out.versions)
    } else if (hasExtension(ch_input, "xlsx") || hasExtension(ch_input, "xls") || hasExtension(ch_input, "ods")) {
        // Convert samplesehet to TSV format
        CONVERT_SAMPLESHEET_PYTHON(ch_input)

        // Merge lanes if merged_lanes parameter is used
        INPUT_MERGE_LANE_FILES(CONVERT_SAMPLESHEET_PYTHON.out.converted_samplesheet)

        // Extracts read files from TSV samplesheet created
        // in above process and distribute into channels
        ch_input_rows = INPUT_MERGE_LANE_FILES.out.output
            .splitCsv(header: true, sep:'\t')
            .map { row ->
                    if (row.size() == 3) {
                        def id = row.sample
                        def sr1 = row.fastq_1 ? file(row.fastq_1, checkIfExists: true) : false
                        def sr2 = row.fastq_2 ? file(row.fastq_2, checkIfExists: true) : false
                        // Check if given combination is valid
                        if (!id) exit 1, "Invalid input samplesheet: sample can not be empty."
                        if (!sr1) exit 1, "Invalid input samplesheet: fastq_1 can not be empty."
                        if (!sr2) exit 1, "Invalid input samplesheet: fastq_2 can not be empty."
                        return [ id, sr1, sr2 ]
                    } else {
                        exit 1, "Input samplesheet contains row with ${row.size()} column(s). Expects 3."
                    }
                }
        // Separate reads
        ch_raw_reads = ch_input_rows
            .map { id, sr1, sr2 ->
                        def meta = [:]
                        meta.id  = id
                        return [ meta, [ sr1, sr2 ] ]
                }

        // Collect version info
        ch_versions = ch_versions
                        .mix(INPUT_MERGE_LANE_FILES.out.versions)
                        .mix(CONVERT_SAMPLESHEET_PYTHON.out.versions)
       }     else {
        // No samplesheet: glob paired FASTQ files in the input folder
                // No samplesheet: glob FASTQ files and group R1/R2 pairs by sample ID
        ch_raw_reads = Channel.fromPath("${params.input}/*_L001_R{1,2}_001.fastq.gz", checkIfExists: true)
            .map { file ->
                // derive sample ID by stripping the suffix
                def id = file.getName().replaceAll(/_L001_R[12]_001\.fastq\.gz$/, '')
                return tuple(id, file)
            }
            .groupTuple()
            .map { sample_id, reads ->
                def meta = [ id: sample_id ]
                return [ meta, reads ]
            }
        ch_input_rows = Channel.empty()
    }


    // Ensure sample IDs are unique
    ch_input_rows
        .map { id, sr1, sr2 -> id }
        .toList()
        .map { ids -> if( ids.size() != ids.unique().size() ) {exit 1, "ERROR: input samplesheet contains duplicated sample IDs!" } }

    emit:
    raw_reads = ch_raw_reads    // channel: [ val(meta), [reads] ]
    versions  = ch_versions
}
