#!/bin/bash

# Cache management script for bacterial genome assembly pipeline
# Helps manage database caches to save download time

CACHE_BASE="${HOME}/.nextflow_cache"

show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup     - Create cache directories"
    echo "  status    - Show cache status and sizes"
    echo "  clean     - Clean work directory cache (keeps databases)"
    echo "  purge     - Remove all cached data (WARNING: will re-download everything)"
    echo "  backup    - Create backup of cached databases"
    echo "  restore   - Restore cached databases from backup"
    echo ""
}

setup_cache() {
    echo "Setting up cache directories..."
    mkdir -p "${CACHE_BASE}"/{databases,blast,kraken,checkm2,busco,gtdb,cat,work,tmp}
    chmod 755 "${CACHE_BASE}" "${CACHE_BASE}"/*
    echo "Cache directories created at: ${CACHE_BASE}"
}

show_status() {
    echo "Cache Status Report"
    echo "==================="
    echo "Base cache directory: ${CACHE_BASE}"
    echo ""
    
    if [ ! -d "${CACHE_BASE}" ]; then
        echo "❌ Cache not initialized. Run: $0 setup"
        return 1
    fi
    
    echo "Directory sizes:"
    for dir in databases blast kraken checkm2 busco gtdb cat work; do
        if [ -d "${CACHE_BASE}/${dir}" ]; then
            size=$(du -sh "${CACHE_BASE}/${dir}" 2>/dev/null | cut -f1)
            count=$(find "${CACHE_BASE}/${dir}" -type f 2>/dev/null | wc -l)
            echo "  📁 ${dir}: ${size} (${count} files)"
        else
            echo "  📁 ${dir}: Not found"
        fi
    done
    
    echo ""
    total_size=$(du -sh "${CACHE_BASE}" 2>/dev/null | cut -f1)
    echo "Total cache size: ${total_size}"
    
    echo ""
    echo "Available databases:"
    [ -d "${CACHE_BASE}/blast" ] && find "${CACHE_BASE}/blast" -name "*.n*" 2>/dev/null | head -3 | sed 's/^/  🧬 /'
    [ -d "${CACHE_BASE}/kraken" ] && find "${CACHE_BASE}/kraken" -name "*.k2d" 2>/dev/null | head -3 | sed 's/^/  🦠 /'
    [ -d "${CACHE_BASE}/checkm2" ] && find "${CACHE_BASE}/checkm2" -name "*.dmnd" 2>/dev/null | head -3 | sed 's/^/  ✅ /'
}

clean_work() {
    echo "Cleaning work directory cache..."
    if [ -d "${CACHE_BASE}/work" ]; then
        rm -rf "${CACHE_BASE}/work"/*
        echo "✅ Work directory cleaned"
    fi
    if [ -d "${CACHE_BASE}/tmp" ]; then
        rm -rf "${CACHE_BASE}/tmp"/*
        echo "✅ Temp directory cleaned"
    fi
    echo "Database caches preserved"
}

purge_all() {
    echo "⚠️  WARNING: This will remove ALL cached data!"
    echo "You will need to re-download all databases (~15GB+)"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        echo "Purging all cache data..."
        rm -rf "${CACHE_BASE}"
        echo "✅ All cache data removed"
    else
        echo "❌ Purge cancelled"
    fi
}

backup_cache() {
    backup_dir="${HOME}/nextflow_cache_backup_$(date +%Y%m%d_%H%M%S)"
    echo "Creating backup at: ${backup_dir}"
    
    if [ -d "${CACHE_BASE}" ]; then
        cp -r "${CACHE_BASE}" "${backup_dir}"
        echo "✅ Backup created: ${backup_dir}"
        echo "Backup size: $(du -sh "${backup_dir}" | cut -f1)"
    else
        echo "❌ No cache to backup"
    fi
}

restore_cache() {
    echo "Available backups:"
    ls -la "${HOME}"/nextflow_cache_backup_* 2>/dev/null || {
        echo "❌ No backups found"
        return 1
    }
    
    echo ""
    read -p "Enter backup directory path: " backup_path
    
    if [ -d "$backup_path" ]; then
        echo "Restoring from: $backup_path"
        rm -rf "${CACHE_BASE}"
        cp -r "$backup_path" "${CACHE_BASE}"
        echo "✅ Cache restored"
    else
        echo "❌ Backup directory not found"
    fi
}

# Main script logic
case "${1:-}" in
    setup)
        setup_cache
        ;;
    status)
        show_status
        ;;
    clean)
        clean_work
        ;;
    purge)
        purge_all
        ;;
    backup)
        backup_cache
        ;;
    restore)
        restore_cache
        ;;
    *)
        show_usage
        exit 1
        ;;
esac