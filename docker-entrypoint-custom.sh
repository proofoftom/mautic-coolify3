#!/bin/bash
set -e

# Custom Mautic entrypoint script
# - Automatic installation on first deployment using environment variables
# - Skip setup on subsequent deployments (only update code)

# Configuration file locations
LOCAL_CONFIG="/var/www/html/config/local.php"
DOCROOT_LOCAL_CONFIG="/var/www/html/docroot/app/config/local.php"

is_installed() {
    if [ -f "$LOCAL_CONFIG" ] || [ -f "$DOCROOT_LOCAL_CONFIG" ]; then
        return 0
    fi
    return 1
}

clear_cache() {
    echo "[mautic_entrypoint]: Clearing Mautic cache..."
    rm -rf /var/www/html/var/cache/* 2>/dev/null || true
    rm -rf /var/www/html/docroot/var/cache/* 2>/dev/null || true
}

fix_permissions() {
    echo "[mautic_entrypoint]: Fixing file permissions..."
    chown -R www-data:www-data /var/www/html/docroot/themes 2>/dev/null || true
    chown -R www-data:www-data /var/www/html/docroot/plugins 2>/dev/null || true
    chown -R www-data:www-data /var/www/html/config 2>/dev/null || true
    chown -R www-data:www-data /var/www/html/var 2>/dev/null || true
}

wait_for_db() {
    echo "[mautic_entrypoint]: Waiting for database to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if mysqladmin ping -h"${MAUTIC_DB_HOST:-mysql}" -u"${MAUTIC_DB_USER}" -p"${MAUTIC_DB_PASSWORD}" --silent 2>/dev/null; then
            echo "[mautic_entrypoint]: Database is ready!"
            return 0
        fi
        echo "[mautic_entrypoint]: Waiting for database... (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "[mautic_entrypoint]: Database connection timeout!"
    return 1
}

run_automatic_install() {
    echo "[mautic_entrypoint]: Running automatic Mautic installation..."
    
    # Wait for database
    wait_for_db || exit 1
    
    # Build site URL from environment
    SITE_URL="${MAUTIC_URL:-http://localhost}"
    
    # Remove trailing slash if present
    SITE_URL="${SITE_URL%/}"
    
    echo "[mautic_entrypoint]: Installing Mautic at: $SITE_URL"
    
    # Run Mautic installer via console command
    cd /var/www/html/docroot
    
    php bin/console mautic:install "$SITE_URL" \
        --db_driver=pdo_mysql \
        --db_host="${MAUTIC_DB_HOST:-mysql}" \
        --db_port="${MAUTIC_DB_PORT:-3306}" \
        --db_name="${MAUTIC_DB_NAME:-mautic}" \
        --db_user="${MAUTIC_DB_USER}" \
        --db_password="${MAUTIC_DB_PASSWORD}" \
        --db_table_prefix="${MAUTIC_DB_TABLE_PREFIX:-mautic_}" \
        --admin_firstname="${MAUTIC_ADMIN_FIRSTNAME:-Admin}" \
        --admin_lastname="${MAUTIC_ADMIN_LASTNAME:-User}" \
        --admin_username="${MAUTIC_ADMIN_USERNAME:-admin}" \
        --admin_email="${MAUTIC_ADMIN_EMAIL:-admin@example.com}" \
        --admin_password="${MAUTIC_ADMIN_PASSWORD:-mautic}" \
        --force \
        --no-interaction
    
    local install_result=$?
    
    if [ $install_result -eq 0 ]; then
        echo "[mautic_entrypoint]: Mautic installation completed successfully!"
    else
        echo "[mautic_entrypoint]: Mautic installation failed with code: $install_result"
        exit $install_result
    fi
    
    # Clear cache after installation
    clear_cache
    
    # Fix permissions after installation
    fix_permissions
}

# =========== MAIN EXECUTION ===========

if is_installed; then
    echo "[mautic_entrypoint]: Existing Mautic installation detected."
    echo "[mautic_entrypoint]: Skipping installation, only updating code..."
    
    # Clear cache to pick up theme/plugin changes
    clear_cache
    
    # Fix permissions
    fix_permissions
    
    echo "[mautic_entrypoint]: Starting Apache..."
    exec apache2-foreground
else
    echo "[mautic_entrypoint]: No existing installation found."
    
    # Check if we have required environment variables for automatic install
    if [ -n "$MAUTIC_DB_USER" ] && [ -n "$MAUTIC_DB_PASSWORD" ]; then
        echo "[mautic_entrypoint]: Database credentials found, running automatic installation..."
        run_automatic_install
        
        echo "[mautic_entrypoint]: Starting Apache..."
        exec apache2-foreground
    else
        echo "[mautic_entrypoint]: No database credentials found in environment."
        echo "[mautic_entrypoint]: Please set MAUTIC_DB_USER and MAUTIC_DB_PASSWORD for automatic installation."
        echo "[mautic_entrypoint]: Starting Apache for manual installation..."
        exec apache2-foreground
    fi
fi
