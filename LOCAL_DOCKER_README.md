# Local Docker Configuration

This configuration is optimized for running the bacterial genome assembly pipeline on a high-performance workstation with **22 cores and 64GB RAM** using Docker containers.

## System Requirements

- **CPU**: 22 cores (configuration uses 20, leaving 2 for system overhead)
- **Memory**: 64GB RAM (configuration uses 56GB, leaving 8GB for system overhead)
- **Docker**: Docker Engine installed and running
- **Storage**: Sufficient disk space for input data, databases, and results

## Quick Start

1. **Setup database caching** (one-time setup):
   ```bash
   ./setup_cache.sh
   ```

2. **Prepare your samplesheet** (CSV format with columns: sample, fastq_1, fastq_2)

3. **Run the pipeline with caching**:
   ```bash
   nextflow run main.nf -profile local_docker_cached --input samplesheet.csv --outdir results
   ```

## Resource Allocation

The configuration optimally distributes resources across different pipeline processes:

### High-Resource Processes
- **SPAdes Assembly**: 16 cores, 40GB RAM, 12h timeout
- **SKESA Assembly**: 12 cores, 24GB RAM, 8h timeout
- **GTDB-Tk Classification**: 12 cores, 32GB RAM, 12h timeout

### Medium-Resource Processes
- **Prokka Annotation**: 8 cores, 16GB RAM, 6h timeout
- **CheckM2 Assessment**: 8 cores, 16GB RAM, 6h timeout
- **Kraken Classification**: 8 cores, 20GB RAM, 4h timeout
- **BUSCO Assessment**: 8 cores, 12GB RAM, 4h timeout

### Low-Resource Processes
- **Read Trimming**: 4 cores, 8GB RAM, 3h timeout
- **Host Removal**: 6 cores, 12GB RAM, 4h timeout
- **FastQC**: 2 cores, 4GB RAM, 1h timeout

## Configuration Files

- **`conf/local_docker.config`**: Main configuration file with resource allocations
- **`run_local_docker.sh`**: Example script with common usage patterns

## Usage Examples

### Basic Assembly
```bash
nextflow run main.nf \
    -profile local_docker \
    --input samplesheet.csv \
    --outdir results \
    --assembler spades
```

### Fast Assembly (SKESA)
```bash
nextflow run main.nf \
    -profile local_docker \
    --input samplesheet.csv \
    --outdir results \
    --assembler skesa
```

### Test Run
```bash
nextflow run main.nf -profile local_docker,test
```

### Skip Resource-Intensive Steps
```bash
nextflow run main.nf \
    -profile local_docker \
    --input samplesheet.csv \
    --outdir results \
    --skip_gtdbtk \
    --skip_busco
```

## Performance Tips

1. **Use SKESA for faster assembly** if you don't need the highest quality assemblies
2. **Skip GTDB-Tk** (`--skip_gtdbtk`) if you don't need detailed taxonomic classification
3. **Skip BUSCO** (`--skip_busco`) if you don't need completeness assessment
4. **Monitor system resources** during runs to ensure optimal performance
5. **Use SSD storage** for better I/O performance

## Troubleshooting

### Memory Issues
- Reduce `max_memory` parameter if you encounter out-of-memory errors
- Consider skipping memory-intensive processes like GTDB-Tk

### CPU Issues
- Reduce `max_cpus` parameter if system becomes unresponsive
- Monitor CPU usage to ensure you're not oversubscribing

### Docker Issues
- Ensure Docker daemon is running: `sudo systemctl start docker`
- Check Docker permissions: `sudo usermod -aG docker $USER` (requires logout/login)
- Increase Docker memory limits if needed

## Database Caching

### Automatic Caching (Recommended)
Use the `local_docker_cached` profile for automatic database caching:
```bash
nextflow run main.nf -profile local_docker_cached --input samplesheet.csv --outdir results
```

### Cache Management
- **Setup cache**: `./setup_cache.sh`
- **Check cache status**: `./manage_cache.sh status`
- **Clean work files**: `./manage_cache.sh clean`
- **Backup databases**: `./manage_cache.sh backup`

### Database Downloads (First Run Only)
The pipeline will automatically download and cache required databases:
- **Kraken databases**: ~8GB
- **BLAST 16S database**: ~500MB
- **CheckM2 database**: ~3GB
- **SRA Human Scrubber database**: ~3GB

**Cache Location**: `~/.nextflow_cache/`

Subsequent runs will use cached databases, dramatically reducing startup time.

## Customization

You can override any resource allocation by modifying `conf/local_docker.config` or by passing parameters at runtime:

```bash
nextflow run main.nf \
    -profile local_docker \
    --input samplesheet.csv \
    --outdir results \
    --max_cpus 16 \
    --max_memory 48.GB
```