#!/usr/bin/env nextflow
nextflow.enable.dsl = 2
//
// Downsample reads to a specified depth
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULES: Local modules
//
include { CALCULATE_METRICS_FASTQ_SEQKIT as CALC_STATS_DOWNSAMPLE_FQ_SEQKIT } from "../../modules/local/calculate_metrics_fastq_seqkit/main"
include { CALCULATE_METRICS_FASTQ_SEQTK  as CALC_STATS_DOWNSAMPLE_FQ_SEQTK  } from "../../modules/local/calculate_metrics_fastq_seqtk/main"
include { COUNT_TOTAL_BP_INPUT_READS_SEQKIT                                } from "../../modules/local/count_total_bp_input_reads_seqkit/main"
include { COUNT_TOTAL_BP_INPUT_READS_SEQTK                                 } from "../../modules/local/count_total_bp_input_reads_seqtk/main"
include { ESTIMATE_GENOME_SIZE_KMC                                         } from "../../modules/local/estimate_genome_size_kmc/main"
include { ESTIMATE_ORIGINAL_INPUT_DEPTH_UNIX                               } from "../../modules/local/estimate_original_input_depth_unix/main"
include { SUBSAMPLE_READS_TO_DEPTH_SEQKIT                                  } from "../../modules/local/subsample_reads_to_depth_seqkit/main"
include { SUBSAMPLE_READS_TO_DEPTH_SEQTK                                   } from "../../modules/local/subsample_reads_to_depth_seqtk/main"

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Convert params.assembler to lowercase
def toLower(it) {
    it.toString().toLowerCase()
}

// Check QC filechecks for a failure
def qcfilecheck(process, qcfile, inputfile) {
    qcfile.map{ meta, file -> [ meta, [file] ] }
            .join(inputfile)
            .map{ meta, qc, input ->
                data = []
                qc.flatten().each{ data += it.readLines() }

                if ( data.any{ it.contains('FAIL') } ) {
                    line = data.last().split('\t')
                    log.warn("${line[1]} QC check failed during process ${process} for sample ${line.first()}")
                } else {
                    [ meta, input ]
                }
            }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN DOWNSAMPLING WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DOWNSAMPLE {
    take:
    ch_reads // channel: [ val(meta), [ reads(R1, R2) ] ]

    main:
    ch_versions = Channel.empty()
    ch_qc_filechecks = Channel.empty()
    ch_output_summary_files = Channel.empty()
    ch_total_bp = Channel.empty()

    if (params.subsample) {
        log.info "Estimating if the input exceeds ${params.depth}x"

        // PROCESS: run KMC to get k-mer counts for genome size estimation
        ESTIMATE_GENOME_SIZE_KMC (
            ch_reads
        )
        ch_versions = ch_versions.mix(ESTIMATE_GENOME_SIZE_KMC.out.versions)

        if ( toLower(params.subsample_tool) == "seqkit" ) {
            // PROCESS: Calculate total bp for each sample with SeqKit
            COUNT_TOTAL_BP_INPUT_READS_SEQKIT (
                ch_reads
            )
            ch_versions = ch_versions.mix(COUNT_TOTAL_BP_INPUT_READS_SEQKIT.out.versions)
            ch_total_bp = COUNT_TOTAL_BP_INPUT_READS_SEQKIT.out.input_total_bp
        } else {
            // PROCESS: Calculate total bp for each sample with Seqtk
            COUNT_TOTAL_BP_INPUT_READS_SEQTK (
                ch_reads
            )
            ch_versions = ch_versions.mix(COUNT_TOTAL_BP_INPUT_READS_SEQTK.out.versions)
            ch_total_bp = COUNT_TOTAL_BP_INPUT_READS_SEQTK.out.output
        }
        
        // --- FIX: Explicitly join the two channels before passing to the next process ---
        ch_for_depth_estimation = ch_total_bp.join(ESTIMATE_GENOME_SIZE_KMC.out.genome_size)

        // PROCESS: use total bp and est. genome size to calc initial depth
        ESTIMATE_ORIGINAL_INPUT_DEPTH_UNIX (
            ch_for_depth_estimation
        )
        ch_versions = ch_versions.mix(ESTIMATE_ORIGINAL_INPUT_DEPTH_UNIX.out.versions)

        // Split reads into two channels: one for subsampling and one to skip
        ESTIMATE_ORIGINAL_INPUT_DEPTH_UNIX.out.fraction
            .join(ch_reads)
            .branch { meta, fraction, reads ->
                // FIX: This block now uses the correct branch syntax
                def ff = new File(fraction.toString())
                def is_above = false
                if (ff.exists() && ff.size() > 0) {
                    def fraction_val = ff.getText('UTF-8').toFloat()
                    if (fraction_val < 1.0) {
                        is_above = true
                    }
                }
                
                above_depth: is_above
                below_depth: !is_above
            }
            .set { ch_split_subsample }

        // Re-add the fraction value to the above_depth channel, as it's consumed by branch
        ch_subsample_input = ch_split_subsample.above_depth.join(ESTIMATE_ORIGINAL_INPUT_DEPTH_UNIX.out.fraction)
                                                          .map { meta, reads, frac_file -> [meta, reads, frac_file] }

        // Subsample reads that are above the desired depth
        if ( toLower(params.subsample_tool) == "seqkit" ) {
            SUBSAMPLE_READS_TO_DEPTH_SEQKIT(
                ch_subsample_input
            )
            ch_versions = ch_versions.mix(SUBSAMPLE_READS_TO_DEPTH_SEQKIT.out.versions)

            ch_subsampled_reads_summary = SUBSAMPLE_READS_TO_DEPTH_SEQKIT.out.summary
                                                .collectFile(
                                                    name:       "Summary.Subsampled_Reads.tsv",
                                                    keepHeader: true,
                                                    sort:       true,
                                                    storeDir:   "${params.outdir}/Summaries"
                                                )
            ch_output_summary_files = ch_output_summary_files.mix(ch_subsampled_reads_summary)

            ch_final_reads = SUBSAMPLE_READS_TO_DEPTH_SEQKIT.out.subsampled_reads
                                .mix(ch_split_subsample.below_depth.map{ meta, reads -> [ meta, reads ] })

            CALC_STATS_DOWNSAMPLE_FQ_SEQKIT(
                ch_final_reads,
                "Subsampled_Reads"
            )
            ch_versions = ch_versions.mix(CALC_STATS_DOWNSAMPLE_FQ_SEQKIT.out.versions)
            ch_downsample_metrics = CALC_STATS_DOWNSAMPLE_FQ_SEQKIT.out.output
                                        .collectFile(
                                            name:       "Summary.Subsampled_Reads.Metrics.tsv",
                                            keepHeader: true,
                                            sort:       true,
                                            storeDir:   "${params.outdir}/Summaries"
                                        )
            ch_output_summary_files = ch_output_summary_files.mix(ch_downsample_metrics)

        } else {
            SUBSAMPLE_READS_TO_DEPTH_SEQTK(
                ch_subsample_input
            )
            ch_versions = ch_versions.mix(SUBSAMPLE_READS_TO_DEPTH_SEQTK.out.versions)
            ch_final_reads = SUBSAMPLE_READS_TO_DEPTH_SEQTK.out.subsampled_reads
                                .mix(ch_split_subsample.below_depth.map{ meta, reads -> [ meta, reads ] })
        }
    } else {
        ch_final_reads = ch_reads
    }

    emit:
    reads                = ch_final_reads
    versions             = ch_versions
    output_summary_files = ch_output_summary_files
}
