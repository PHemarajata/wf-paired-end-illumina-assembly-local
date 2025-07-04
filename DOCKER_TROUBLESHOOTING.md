# Docker Troubleshooting Guide

## Problem Description

The pipeline processes are failing silently with empty `.command.out`, `.command.err`, and `.command.log` files. The Docker containers are starting but the commands inside them are failing immediately.

## Root Cause

The issue is that the `bash_functions.sh` file (located in `bin/bash_functions.sh`) is not accessible inside the Docker containers. Many of the pipeline's modules source this file with:

```bash
source bash_functions.sh
```

But the `bin/` directory is not mounted in the Docker containers, causing the sourcing to fail and the entire script to exit.

## Solutions

### Solution 1: Use the Working Docker Profile (Recommended)

Use the `docker_working` profile which properly mounts the project directory:

```bash
nextflow run main.nf -profile docker_working --input your_samplesheet.csv --outdir results
```

### Solution 2: Fix the Existing Docker Profile

If you want to keep using the existing `docker` profile, you need to modify it to include the project directory mount.

Add this to your `nextflow.config` in the docker profile section:

```groovy
docker {
    enabled = true
    fixOwnership = true
    runOptions = "-u \$(id -u):\$(id -g)"
    runOptions = "${docker.runOptions} -v \${projectDir}:\${projectDir}"
    docker.cacheDir = "${params.profile_cache_dir}"
    includeConfig "conf/base.config"
}
```

### Solution 3: Manual Fix for Current Run

If you want to fix your current failing run without restarting:

1. **Stop the current run** (Ctrl+C)
2. **Clean the work directory**:
   ```bash
   rm -rf ~/.nextflow_cache/work/*
   ```
3. **Use the working profile**:
   ```bash
   nextflow run main.nf -profile docker_working --input your_samplesheet.csv --outdir results
   ```

## Verification

To verify the fix is working, check that the first few processes complete successfully:

```bash
# Monitor the pipeline
tail -f .nextflow.log

# Check a work directory for successful execution
ls -la ~/.nextflow_cache/work/[first-few-chars-of-hash]/[full-hash]/.command.*
```

You should see:
- `.command.out` with actual output
- `.command.err` either empty or with normal stderr
- `.command.log` with execution logs
- Exit code 0 in `.exitcode`

## Available Profiles

1. **`docker_working`** - Basic Docker with proper mounting (recommended for troubleshooting)
2. **`local_docker_fixed`** - Full-featured Docker with resource optimization and caching
3. **`docker`** - Original Docker profile (has the mounting issue)

## Common Docker Issues

### Issue: Permission Denied
```bash
# Fix: Ensure Docker daemon is running and user has permissions
sudo systemctl start docker
sudo usermod -aG docker $USER
# Log out and back in
```

### Issue: Out of Memory
```bash
# Fix: Increase Docker memory limits or reduce max_memory parameter
nextflow run main.nf -profile docker_working --max_memory 32.GB --input samplesheet.csv --outdir results
```

### Issue: Container Not Found
```bash
# Fix: Pull containers manually
docker pull ubuntu:jammy
docker pull staphb/trimmomatic
# etc.
```

## Debug Commands

To debug a specific failing process:

```bash
# Find the work directory of a failed process
find ~/.nextflow_cache/work -name ".command.run" -exec grep -l "PROCESS_NAME" {} \;

# Check the actual command that was run
cat ~/.nextflow_cache/work/[hash]/.command.sh

# Try running the Docker command manually
# (copy the docker run command from .command.run and execute it)
```

## Prevention

To prevent this issue in the future:
1. Always test new Docker configurations with a small test dataset first
2. Use the `docker_working` profile for reliable execution
3. Monitor the first few processes to ensure they complete successfully
4. Keep the `bin/` directory and its contents intact in the pipeline directory