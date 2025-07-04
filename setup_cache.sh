#!/bin/bash

# Setup script for database caching
# This creates persistent cache directories for databases

echo "Setting up Nextflow database cache directories..."

# Create cache directories
CACHE_BASE="${HOME}/.nextflow_cache"
mkdir -p "${CACHE_BASE}/databases"
mkdir -p "${CACHE_BASE}/blast"
mkdir -p "${CACHE_BASE}/kraken"
mkdir -p "${CACHE_BASE}/checkm2"
mkdir -p "${CACHE_BASE}/busco"
mkdir -p "${CACHE_BASE}/gtdb"
mkdir -p "${CACHE_BASE}/cat"

# Set appropriate permissions
chmod 755 "${CACHE_BASE}"
chmod 755 "${CACHE_BASE}"/*

echo "Cache directories created at:"
echo "  Main cache: ${CACHE_BASE}"
echo "  Databases:  ${CACHE_BASE}/databases"
echo "  BLAST:      ${CACHE_BASE}/blast"
echo "  Kraken:     ${CACHE_BASE}/kraken"
echo "  CheckM2:    ${CACHE_BASE}/checkm2"
echo "  BUSCO:      ${CACHE_BASE}/busco"
echo "  GTDB:       ${CACHE_BASE}/gtdb"
echo "  CAT:        ${CACHE_BASE}/cat"
echo ""
echo "Total cache directory size:"
du -sh "${CACHE_BASE}" 2>/dev/null || echo "0B (empty)"
echo ""
echo "To use cached databases, run pipeline with:"
echo "nextflow run main.nf -profile local_docker --input samplesheet.csv --outdir results"
echo ""
echo "Databases will be automatically cached on first download and reused in subsequent runs."