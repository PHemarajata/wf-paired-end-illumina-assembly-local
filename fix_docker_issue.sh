#!/bin/bash

echo "🔧 Docker Issue Fix Script v2"
echo "============================="
echo ""

# Function to check command with timeout
check_with_timeout() {
    local cmd="$1"
    local timeout_duration="$2"
    local description="$3"
    
    echo "⏳ $description (timeout: ${timeout_duration}s)..."
    
    if timeout "$timeout_duration" bash -c "$cmd" >/dev/null 2>&1; then
        echo "✅ $description - SUCCESS"
        return 0
    else
        echo "❌ $description - FAILED or TIMEOUT"
        return 1
    fi
}

# Check if we're in the right directory
if [ ! -f "main.nf" ]; then
    echo "❌ Error: Please run this script from the pipeline directory (where main.nf is located)"
    exit 1
fi
echo "✅ Found main.nf - in correct directory"

# Check if Docker is running (with timeout)
echo "🐳 Checking Docker status..."
if check_with_timeout "docker info" 10 "Docker daemon check"; then
    echo "✅ Docker is running"
else
    echo "❌ Error: Docker is not running or not accessible. Please:"
    echo "   1. Start Docker: sudo systemctl start docker"
    echo "   2. Add user to docker group: sudo usermod -aG docker \$USER"
    echo "   3. Log out and back in"
    exit 1
fi

# Check if bash_functions.sh exists
if [ ! -f "bin/bash_functions.sh" ]; then
    echo "❌ Error: bin/bash_functions.sh not found. This file is required for the pipeline."
    exit 1
fi
echo "✅ bash_functions.sh found"

# Check if Docker profiles exist
echo "🔍 Checking available Docker profiles..."
if grep -q "docker_working" nextflow.config; then
    echo "✅ docker_working profile found"
else
    echo "⚠️  docker_working profile not found in nextflow.config"
fi

if grep -q "local_docker_fixed" nextflow.config; then
    echo "✅ local_docker_fixed profile found"
else
    echo "⚠️  local_docker_fixed profile not found in nextflow.config"
fi

# Clean up any failed work directories
echo ""
echo "🧹 Cleaning up failed work directories..."
if [ -d "${HOME}/.nextflow_cache/work" ]; then
    # Count failed directories
    failed_count=$(find "${HOME}/.nextflow_cache/work" -name ".exitcode" -exec grep -l "1" {} \; 2>/dev/null | wc -l)
    if [ "$failed_count" -gt 0 ]; then
        echo "   Found $failed_count failed work directories"
        find "${HOME}/.nextflow_cache/work" -name ".exitcode" -exec grep -l "1" {} \; 2>/dev/null | xargs -I {} dirname {} | xargs rm -rf 2>/dev/null
        echo "✅ Cleaned up failed work directories"
    else
        echo "ℹ️  No failed work directories found"
    fi
else
    echo "ℹ️  No work directory found to clean"
fi

# Check available profiles
echo ""
echo "📋 Available Docker profiles:"
echo "   - docker_working     (recommended - fixes the bash_functions.sh issue)"
echo "   - local_docker_fixed (full-featured with resource optimization)"
echo "   - docker             (original - has issues)"
echo ""

# Provide usage instructions
echo "🚀 To run the pipeline with the fix:"
echo ""
echo "   nextflow run main.nf -profile docker_working --input your_samplesheet.csv --outdir results"
echo ""
echo "   Or with resource optimization:"
echo "   nextflow run main.nf -profile local_docker_fixed --input your_samplesheet.csv --outdir results"
echo ""

# Test Docker mounting (with timeout and better error handling)
echo "🧪 Testing Docker volume mounting..."
echo "   This test checks if Docker can access the pipeline files..."

# First check if ubuntu:jammy image is available
if check_with_timeout "docker image inspect ubuntu:jammy" 5 "Checking ubuntu:jammy image"; then
    echo "✅ ubuntu:jammy image is available"
    
    # Test the actual mounting
    if check_with_timeout "docker run --rm -v \"$(pwd):$(pwd)\" -w \"$(pwd)\" ubuntu:jammy test -f bin/bash_functions.sh" 15 "Docker volume mounting test"; then
        echo "✅ Docker volume mounting test passed"
        echo ""
        echo "🎉 The fix should work! You can now run the pipeline with the docker_working profile."
        test_passed=true
    else
        echo "❌ Docker volume mounting test failed"
        test_passed=false
    fi
else
    echo "⚠️  ubuntu:jammy image not found locally"
    echo "   Attempting to pull image (this may take a few minutes)..."
    
    if check_with_timeout "docker pull ubuntu:jammy" 120 "Pulling ubuntu:jammy image"; then
        echo "✅ Successfully pulled ubuntu:jammy image"
        
        # Now test mounting
        if check_with_timeout "docker run --rm -v \"$(pwd):$(pwd)\" -w \"$(pwd)\" ubuntu:jammy test -f bin/bash_functions.sh" 15 "Docker volume mounting test"; then
            echo "✅ Docker volume mounting test passed"
            echo ""
            echo "🎉 The fix should work! You can now run the pipeline with the docker_working profile."
            test_passed=true
        else
            echo "❌ Docker volume mounting test failed"
            test_passed=false
        fi
    else
        echo "❌ Failed to pull ubuntu:jammy image"
        echo "   This might be due to network issues or Docker configuration problems."
        test_passed=false
    fi
fi

# Final recommendations
echo ""
if [ "${test_passed:-false}" = "true" ]; then
    echo "🎯 RECOMMENDED NEXT STEPS:"
    echo "   1. Run: nextflow run main.nf -profile docker_working --input your_samplesheet.csv --outdir results"
    echo "   2. Monitor the first few processes to ensure they complete successfully"
    echo "   3. Check .nextflow.log for any issues"
else
    echo "🔧 TROUBLESHOOTING STEPS:"
    echo "   1. Check Docker permissions: sudo usermod -aG docker \$USER (then logout/login)"
    echo "   2. Restart Docker: sudo systemctl restart docker"
    echo "   3. Check Docker settings and available disk space"
    echo "   4. Try running without Docker: nextflow run main.nf --input your_samplesheet.csv --outdir results"
fi

echo ""
echo "📖 For more details, see: DOCKER_TROUBLESHOOTING.md"
echo "🐛 If issues persist, check the pipeline logs: tail -f .nextflow.log"