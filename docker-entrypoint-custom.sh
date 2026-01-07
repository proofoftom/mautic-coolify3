#!/bin/bash
set -e

# Custom Mautic entrypoint script
# - Automatic installation on first deployment using environment variables
# - Skip setup on subsequent deployments (only update code)
# - Only web container runs installation and URL updates
# - Non-web containers skip installation and execute their custom command

# Configuration file locations
LOCAL_CONFIG="/var/www/html/config/local.php"
DOCROOT_LOCAL_CONFIG="/var/www/html/docroot/app/config/local.php"

# Container role - determines which operations this container should perform
CONTAINER_ROLE="${CONTAINER_ROLE:-web}"

# Installation marker file - used for fast "is_installed" check
INSTALL_MARKER_FILE="/var/www/html/config/.installed"

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

update_site_url_if_needed() {
    echo "[mautic_entrypoint]: Checking site URL configuration..."
    
    local expected_url="${MAUTIC_URL:-http://localhost}"
    expected_url="${expected_url%/}"
    
    # Skip if MAUTIC_URL is not set or is empty
    if [ -z "$MAUTIC_URL" ]; then
        echo "[mautic_entrypoint]: MAUTIC_URL not set, skipping site URL update"
        return 0
    fi
    
    local db_host="${MAUTIC_DB_HOST:-mysql}"
    local db_user="$MAUTIC_DB_USER"
    local db_password="$MAUTIC_DB_PASSWORD"
    local db_name="${MAUTIC_DB_NAME:-mautic}"
    local db_table_prefix="${MAUTIC_DB_TABLE_PREFIX:-mautic_}"
    
    # Check if database credentials are available
    if [ -z "$db_user" ] || [ -z "$db_password" ]; then
        echo "[mautic_entrypoint]: Database credentials not available, skipping site URL update"
        return 0
    fi
    
    # Query current site_url from database
    local current_url
    current_url=$(mysql -h"$db_host" -u"$db_user" -p"$db_password" -D"$db_name" -sN -e \
        "SELECT value FROM ${db_table_prefix}config WHERE name = 'site_url';" 2>&1)
    
    # Handle database connection errors
    if [ $? -ne 0 ]; then
        echo "[mautic_entrypoint]: Warning: Failed to query site_url from database, skipping update"
        echo "[mautic_entrypoint]: mysql query error: $current_url"
        return 0
    fi
    
    # Trim trailing slash from current_url if present
    current_url="${current_url%/}"
    
    echo "[mautic_entrypoint]: Current site URL in database: $current_url"
    echo "[mautic_entrypoint]: Expected site URL (MAUTIC_URL): $expected_url"
    
    # Compare URLs and update if different
    if [ "$current_url" != "$expected_url" ]; then
        echo "[mautic_entrypoint]: Site URL mismatch detected, updating to: $expected_url"
        
        # Escape the URL for safe use in SQL to prevent SQL injection
        local escaped_url
        escaped_url=$(printf '%s' "$expected_url" | sed "s/'/\\\\'/g")
        
        echo "[mautic_entrypoint]: DEBUG - Escaped URL: $escaped_url"
        
        # Update site_url in database with escaped value
        local update_result
        update_result=$(mysql -h"$db_host" -u"$db_user" -p"$db_password" -D"$db_name" -e \
            "UPDATE ${db_table_prefix}config SET value = '$escaped_url' WHERE name = 'site_url';" 2>&1)
        
        echo "[mautic_entrypoint]: DEBUG - MySQL update result: $update_result"
        
        if [ $? -eq 0 ]; then
            echo "[mautic_entrypoint]: Site URL successfully updated to: $expected_url"
        else
            echo "[mautic_entrypoint]: Warning: Failed to update site_url in database"
            echo "[mautic_entrypoint]: MySQL exit code: $?"
            return 0
        fi
    else
        echo "[mautic_entrypoint]: Site URL matches MAUTIC_URL, no update needed"
    fi
    
    return 0
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

echo "[mautic_entrypoint]: Container role: $CONTAINER_ROLE"

# Non-web containers skip installation logic and execute their custom command
if [ "$CONTAINER_ROLE" != "web" ]; then
    echo "[mautic_entrypoint]: Non-web container detected - skipping installation and URL updates"
    echo "[mautic_entrypoint]: Clearing cache..."
    clear_cache
    echo "[mautic_entrypoint]: Fixing permissions..."
    fix_permissions
    echo "[mautic_entrypoint]: Executing container command..."
    # Execute the command passed to the container (cron loop, worker loop, etc.)
    exec "$@"
fi

# Web container handles installation and URL updates
echo "[mautic_entrypoint]: Web container detected - handling installation and URL updates"

if is_installed; then
    echo "[mautic_entrypoint]: Existing Mautic installation detected."
    echo "[mautic_entrypoint]: Skipping installation, only updating code..."

    # Update site URL if it doesn't match environment variable
    update_site_url_if_needed

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
