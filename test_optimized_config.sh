#!/bin/bash

# Test script for optimized configuration
# This script validates the configuration without running the full pipeline

set -e

echo "=== Testing Optimized Configuration ==="
echo "Date: $(date)"
echo "System: $(uname -a)"
echo ""

# Check system resources
echo "=== System Resources ==="
echo "CPU cores: $(nproc)"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "Disk space: $(df -h . | tail -1 | awk '{print $4}' | sed 's/G/ GB/')"
echo ""

# Check Nextflow
echo "=== Nextflow Check ==="
if command -v nextflow &> /dev/null; then
    echo "Nextflow version: $(nextflow -version | head -1)"
else
    echo "ERROR: Nextflow not found. Please install Nextflow first."
    exit 1
fi
echo ""

# Check Docker/Singularity
echo "=== Container Runtime Check ==="
if command -v docker &> /dev/null; then
    echo "Docker version: $(docker --version)"
    if docker ps &> /dev/null; then
        echo "Docker is running and accessible"
    else
        echo "WARNING: Docker is installed but not accessible. Check permissions."
    fi
else
    echo "Docker not found"
fi

if command -v singularity &> /dev/null; then
    echo "Singularity version: $(singularity --version)"
else
    echo "Singularity not found"
fi
echo ""

# Test configuration syntax
echo "=== Configuration Syntax Check ==="
cd "$(dirname "$0")"

echo "Testing optimized_docker profile..."
if nextflow config -profile optimized_docker &> /dev/null; then
    echo "✓ optimized_docker profile syntax OK"
else
    echo "✗ optimized_docker profile has syntax errors"
    exit 1
fi

echo "Testing optimized_singularity profile..."
if nextflow config -profile optimized_singularity &> /dev/null; then
    echo "✓ optimized_singularity profile syntax OK"
else
    echo "✗ optimized_singularity profile has syntax errors"
    exit 1
fi
echo ""

# Check resource limits
echo "=== Resource Configuration Check ==="
MAX_CPUS=$(nextflow config -profile optimized_docker | grep 'max_cpus' | awk '{print $3}' | tr -d '"')
MAX_MEMORY=$(nextflow config -profile optimized_docker | grep 'max_memory' | awk '{print $3}' | tr -d '"')

echo "Configured max CPUs: $MAX_CPUS"
echo "Configured max memory: $MAX_MEMORY"

SYSTEM_CPUS=$(nproc)
if [ "$MAX_CPUS" -le "$SYSTEM_CPUS" ]; then
    echo "✓ CPU configuration is within system limits"
else
    echo "⚠ WARNING: Configured CPUs ($MAX_CPUS) exceed system CPUs ($SYSTEM_CPUS)"
fi
echo ""

# Check parameter validation
echo "=== Parameter Validation ==="
echo "Testing Kraken skip parameters..."

# Test skip_kraken parameter
if nextflow config -profile optimized_docker --skip_kraken | grep -q 'skip_kraken.*true'; then
    echo "✓ skip_kraken parameter works"
else
    echo "✗ skip_kraken parameter not working"
fi

# Test skip_kraken1 parameter
if nextflow config -profile optimized_docker --skip_kraken1 | grep -q 'skip_kraken1.*true'; then
    echo "✓ skip_kraken1 parameter works"
else
    echo "✗ skip_kraken1 parameter not working"
fi

# Test skip_kraken2 parameter
if nextflow config -profile optimized_docker --skip_kraken2 | grep -q 'skip_kraken2.*true'; then
    echo "✓ skip_kraken2 parameter works"
else
    echo "✗ skip_kraken2 parameter not working"
fi
echo ""

# Create cache directories
echo "=== Cache Directory Setup ==="
CACHE_DIRS=(
    "$HOME/.nextflow_cache/databases"
    "$HOME/.nextflow_cache/blast"
    "$HOME/.nextflow_cache/kraken"
    "$HOME/.nextflow_cache/checkm2"
    "$HOME/.nextflow_cache/singularity"
)

for dir in "${CACHE_DIRS[@]}"; do
    if mkdir -p "$dir" 2>/dev/null; then
        echo "✓ Created cache directory: $dir"
    else
        echo "⚠ WARNING: Could not create cache directory: $dir"
    fi
done
echo ""

# Test work directory creation
echo "=== Work Directory Test ==="
WORK_DIR="./work/hostile_data"
if mkdir -p "$WORK_DIR" 2>/dev/null; then
    echo "✓ Work directory creation successful: $WORK_DIR"
    rmdir "$WORK_DIR" 2>/dev/null || true
else
    echo "⚠ WARNING: Could not create work directory: $WORK_DIR"
fi
echo ""

echo "=== Configuration Test Complete ==="
echo "The optimized configuration appears to be working correctly."
echo ""
echo "To run the pipeline with optimized settings:"
echo "  nextflow run . -profile optimized_docker --input samplesheet.csv --outdir results --skip_kraken"
echo ""
echo "For more information, see OPTIMIZED_USAGE.md"