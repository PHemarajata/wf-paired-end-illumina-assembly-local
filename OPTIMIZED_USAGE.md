# Optimized Configuration for High-Performance Workstation

This document describes the optimized configuration for running the bacterial genome assembly pipeline on a high-performance workstation with 22 cores and 64GB RAM.

## Quick Start

### Using Docker (Recommended)
```bash
nextflow run . -profile optimized_docker \
    --input samplesheet.csv \
    --outdir results \
    --skip_kraken1 \
    --skip_kraken2
```

### Using Singularity
```bash
nextflow run . -profile optimized_singularity \
    --input samplesheet.csv \
    --outdir results \
    --skip_kraken1 \
    --skip_kraken2
```

## Key Optimizations

### Resource Allocation
- **CPU Usage**: Optimized for 20 cores (leaving 2 for system overhead)
- **Memory Usage**: Optimized for 56GB (leaving 8GB for system overhead)
- **Assembly Processes**: Up to 18 cores and 48GB RAM for SPAdes
- **Taxonomic Classification**: Up to 10 cores and 24GB RAM for Kraken

### Fixed Issues
1. **Hostile Permission Issues**: Fixed container environment variables and directory permissions
2. **Export Command Errors**: Corrected Java heap size configuration
3. **Kraken Skip Options**: Added granular control over Kraken1 and Kraken2

## Configuration Options

### Kraken Classification Control
```bash
# Skip both Kraken1 and Kraken2
--skip_kraken

# Skip only Kraken1
--skip_kraken1

# Skip only Kraken2
--skip_kraken2

# Run both (default)
# No additional flags needed
```

### Container Selection
```bash
# Use Docker (recommended for most systems)
-profile optimized_docker

# Use Singularity (for HPC environments)
-profile optimized_singularity
```

## Resource Requirements by Process

| Process | CPUs | Memory | Time |
|---------|------|--------|------|
| SPAdes Assembly | 18 | 48GB | 12h |
| SKESA Assembly | 12 | 24GB | 8h |
| Kraken1/2 Classification | 10 | 24GB | 4h |
| CheckM2 Assessment | 10 | 20GB | 6h |
| GTDB-Tk Classification | 16 | 40GB | 12h |
| Prokka Annotation | 8 | 16GB | 6h |
| Host Removal (Hostile) | 6 | 12GB | 4h |

## Database Caching

The optimized configuration includes persistent database caching to speed up subsequent runs:

```bash
# Databases are cached in:
~/.nextflow_cache/databases/
~/.nextflow_cache/blast/
~/.nextflow_cache/kraken/
~/.nextflow_cache/checkm2/
```

## Example Commands

### Basic Assembly with Kraken Classification
```bash
nextflow run . -profile optimized_docker \
    --input samplesheet.csv \
    --outdir results \
    --assembler spades
```

### Assembly without Taxonomic Classification (Fastest)
```bash
nextflow run . -profile optimized_docker \
    --input samplesheet.csv \
    --outdir results \
    --assembler skesa \
    --skip_kraken
```

### Full Analysis with Custom Databases
```bash
nextflow run . -profile optimized_docker \
    --input samplesheet.csv \
    --outdir results \
    --assembler spades \
    --kraken2_db /path/to/kraken2/db \
    --checkm2_db /path/to/checkm2/db \
    --gtdb_db /path/to/gtdb/db
```

### Resume Failed Run
```bash
nextflow run . -profile optimized_docker \
    --input samplesheet.csv \
    --outdir results \
    -resume
```

## Troubleshooting

### Hostile Permission Issues
If you encounter permission errors with the hostile tool:
1. Ensure Docker is running with proper permissions
2. The optimized configuration automatically handles this by setting proper environment variables

### Memory Issues
If processes fail due to memory constraints:
1. Reduce the number of parallel samples
2. Use SKESA instead of SPAdes (lower memory requirements)
3. Skip memory-intensive processes like GTDB-Tk

### Disk Space
Ensure adequate disk space:
- Input data: ~2-10GB per sample
- Working directory: ~20-50GB per sample
- Output data: ~5-15GB per sample
- Database cache: ~50-200GB (one-time download)

## Performance Tips

1. **Use SKESA for faster assembly**: `--assembler skesa`
2. **Skip taxonomic classification for speed**: `--skip_kraken`
3. **Use local databases**: Download databases locally instead of URLs
4. **Enable resume**: Always use `-resume` for interrupted runs
5. **Monitor resources**: Use `htop` or `top` to monitor system usage

## Container Management

### Docker
```bash
# Clean up old containers
docker system prune -f

# Check container usage
docker stats
```

### Singularity
```bash
# Clean cache
singularity cache clean

# Check cache usage
singularity cache list
```

## Support

For issues specific to this optimized configuration, check:
1. System resources with `htop`
2. Docker/Singularity logs
3. Nextflow work directory for process-specific errors
4. Pipeline log files in the output directory