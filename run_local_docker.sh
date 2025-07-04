#!/bin/bash

# Example script to run the bacterial genome assembly pipeline locally with Docker
# Optimized for 22-core, 64GB RAM workstation with database caching

# Setup cache directories (run once)
echo "Setting up cache directories..."
./setup_cache.sh

echo "Starting pipeline with database caching enabled..."

# Basic usage example:
# Replace 'your_samplesheet.csv' with your actual samplesheet
# Replace 'results' with your desired output directory

nextflow run main.nf \
    -profile local_docker \
    --input your_samplesheet.csv \
    --outdir results \
    --assembler spades \
    --max_cpus 20 \
    --max_memory 56.GB \
    --max_time 48.h

# Alternative with SKESA assembler (faster, less memory intensive):
# nextflow run main.nf \
#     -profile local_docker \
#     --input your_samplesheet.csv \
#     --outdir results \
#     --assembler skesa \
#     --max_cpus 20 \
#     --max_memory 56.GB \
#     --max_time 48.h

# For testing with provided test data:
# nextflow run main.nf -profile local_docker,test

# Additional useful parameters:
# --host_remove both                    # Remove human contamination (default)
# --trim_reads_tool trimmomatic         # Read trimming tool (default)
# --depth 100                           # Subsampling depth (default)
# --skip_gtdbtk                         # Skip GTDB-Tk classification (saves time/resources)
# --skip_busco                          # Skip BUSCO assessment (saves time)
# --create_excel_outputs                # Create Excel summary files

echo "Pipeline configuration optimized for:"
echo "- 22-core workstation (using 20 cores, leaving 2 for system)"
echo "- 64GB RAM (using 56GB, leaving 8GB for system overhead)"
echo "- Docker containers for reproducibility"
echo ""
echo "Key resource allocations:"
echo "- Assembly (SPAdes): 16 cores, 40GB RAM"
echo "- Assembly (SKESA): 12 cores, 24GB RAM"
echo "- Annotation: 8 cores, 16GB RAM"
echo "- Classification: 8 cores, 20GB RAM"
echo ""
echo "To run: bash run_local_docker.sh"