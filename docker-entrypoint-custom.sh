#!/bin/bash
set -e

# Custom Mautic entrypoint script
# - Automatic installation on first deployment using environment variables
# - Skip setup on subsequent deployments (only update code)
# - File-based lock mechanism to prevent race conditions during installation

# Configuration file locations
LOCAL_CONFIG="/var/www/html/config/local.php"
DOCROOT_LOCAL_CONFIG="/var/www/html/docroot/app/config/local.php"

# Lock file mechanism constants
INSTALL_LOCK_FILE="/var/www/html/config/.install-in-progress"
INSTALL_MARKER_FILE="/var/www/html/config/.installed"
INSTALL_LOCK_TIMEOUT=300  # 5 minutes in seconds

# Acquire install lock using atomic mkdir operation
# Returns: 0 on success, 1 if installation completed by another container, 2 on timeout
acquire_install_lock() {
    local lock_dir="$INSTALL_LOCK_FILE"
    local elapsed=0
    local sleep_interval=2
    
    echo "[mautic_entrypoint]: Attempting to acquire installation lock..."
    
    while [ $elapsed -lt $INSTALL_LOCK_TIMEOUT ]; do
        # Check if installation marker exists (installation completed by another container)
        if [ -f "$INSTALL_MARKER_FILE" ]; then
            echo "[mautic_entrypoint]: Installation marker found - installation already completed by another container"
            return 1
        fi
        
        # Try to create lock directory atomically
        if mkdir "$lock_dir" 2>/dev/null; then
            echo "[mautic_entrypoint]: Installation lock acquired successfully"
            return 0
        fi
        
        # Lock held by another container, wait and retry
        echo "[mautic_entrypoint]: Installation lock held by another container, waiting... (${elapsed}s elapsed)"
        sleep $sleep_interval
        elapsed=$((elapsed + sleep_interval))
    done
    
    echo "[mautic_entrypoint]: Failed to acquire installation lock after ${elapsed}s (timeout)"
    return 2
}

# Release install lock
release_install_lock() {
    local lock_dir="$INSTALL_LOCK_FILE"
    
    if [ -d "$lock_dir" ]; then
        rmdir "$lock_dir" 2>/dev/null && echo "[mautic_entrypoint]: Installation lock released" || echo "[mautic_entrypoint]: Warning: Failed to release installation lock"
    fi
}

# Create installation marker file
create_install_marker() {
    touch "$INSTALL_MARKER_FILE" && echo "[mautic_entrypoint]: Installation marker created" || echo "[mautic_entrypoint]: Warning: Failed to create installation marker"
}

is_installed() {
    # First check for installation marker file (fastest check)
    if [ -f "$INSTALL_MARKER_FILE" ]; then
        echo "[mautic_entrypoint]: Installation detected via marker file"
        return 0
    fi
    
    local db_host="${MAUTIC_DB_HOST:-mysql}"
    local db_user="$MAUTIC_DB_USER"
    local db_password="$MAUTIC_DB_PASSWORD"
    local db_name="${MAUTIC_DB_NAME:-mautic}"
    local db_table_prefix="${MAUTIC_DB_TABLE_PREFIX:-mautic_}"
    
    # Check if database tables exist (more reliable than config files)
    if [ -n "$db_user" ] && [ -n "$db_password" ]; then
        # Check for a core Mautic table like mautic_users
        local table_name="${db_table_prefix}users"
        local table_exists
        
        table_exists=$(mysql -h"$db_host" -u"$db_user" -p"$db_password" -D"$db_name" -sN -e \
            "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$db_name' AND table_name = '$table_name';" 2>/dev/null)
        
        if [ "$table_exists" = "1" ]; then
            echo "[mautic_entrypoint]: Installation detected via database table '$table_name'"
            return 0
        fi
    fi
    
    # Fallback to checking config files if database check fails
    if [ -f "$LOCAL_CONFIG" ] || [ -f "$DOCROOT_LOCAL_CONFIG" ]; then
        echo "[mautic_entrypoint]: Installation detected via config files"
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
    # Try multiple Coolify URL variable patterns (SERVICE_URL_MAUTIC_WEB, COOLIFY_URL, SERVICE_URL_MAUTIC_80)
    SITE_URL="${MAUTIC_URL:-${COOLIFY_URL:-${SERVICE_URL_MAUTIC_WEB:-${SERVICE_URL_MAUTIC_80:-http://localhost}}}"
    
    # Remove trailing slash if present
    SITE_URL="${SITE_URL%/}"
    
    echo "[mautic_entrypoint]: Installing Mautic at: $SITE_URL"
    
    # Run Mautic installer via console command
    php /var/www/html/bin/console mautic:install "$SITE_URL" \
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
        # Create installation marker on success
        create_install_marker
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
        
        # Acquire installation lock to prevent race conditions
        acquire_install_lock
        lock_result=$?
        
        case $lock_result in
            0)
                # Lock acquired, proceed with installation
                echo "[mautic_entrypoint]: Proceeding with installation (lock holder)"
                run_automatic_install
                release_install_lock
                ;;
            1)
                # Installation completed by another container
                echo "[mautic_entrypoint]: Installation completed by another container, skipping..."
                clear_cache
                fix_permissions
                ;;
            2)
                # Timeout waiting for lock
                echo "[mautic_entrypoint]: Timeout waiting for installation lock, checking if installation completed..."
                if is_installed; then
                    echo "[mautic_entrypoint]: Installation completed by another container, proceeding..."
                    clear_cache
                    fix_permissions
                else
                    echo "[mautic_entrypoint]: Error: Installation not completed and lock timeout reached"
                    exit 1
                fi
                ;;
        esac
        
        echo "[mautic_entrypoint]: Starting Apache..."
        exec apache2-foreground
    else
        echo "[mautic_entrypoint]: No database credentials found in environment."
        echo "[mautic_entrypoint]: Please set MAUTIC_DB_USER and MAUTIC_DB_PASSWORD for automatic installation."
        echo "[mautic_entrypoint]: Starting Apache for manual installation..."
        exec apache2-foreground
    fi
fi
