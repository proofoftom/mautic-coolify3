# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a production-ready Coolify service configuration for self-hosted Mautic 6 marketing automation platform. It uses Docker Compose to orchestrate a multi-container stack with support for custom themes and plugins through a git-based workflow.

**Key Components:**
- Mautic 6 (Apache variant with PHP 8.3)
- MariaDB 10.11 database
- RabbitMQ 3 message queue
- Three Mautic services: web, cron, and worker

**Deployment Platform:** Designed specifically for Coolify with auto-generated secrets and Traefik routing.

## Common Commands

### Build and Deploy
```bash
# Build the custom Docker image locally (for testing)
docker compose build

# Start all services locally
docker compose up -d

# View logs for specific service
docker compose logs -f mautic_web
docker compose logs -f mautic_cron
docker compose logs -f mautic_worker

# Stop all services
docker compose down

# Force rebuild with no cache
docker compose build --no-cache
```

### Mautic Console Commands
```bash
# Clear Mautic cache (run inside mautic_web container)
docker compose exec mautic_web php /var/www/html/bin/console cache:clear

# Run migrations manually
docker compose exec mautic_web php /var/www/html/bin/console doctrine:migrations:migrate

# Update segments
docker compose exec mautic_web php /var/www/html/bin/console mautic:segments:update

# Send queued emails
docker compose exec mautic_web php /var/www/html/bin/console mautic:emails:send

# Process message queue
docker compose exec mautic_web php /var/www/html/bin/console messenger:consume mautic
```

### Database Operations
```bash
# Access MariaDB shell
docker compose exec mysql mysql -u root -p

# Backup database
docker compose exec mysql mysqldump -u root -p mautic > backup.sql

# Check if Mautic is installed (query database)
docker compose exec mysql mysql -u root -p -D mautic -e "SELECT COUNT(*) FROM mautic_users;"
```

### Composer
```bash
# Install dependencies (run inside container after modifying composer.json)
docker compose exec mautic_web composer install --no-dev --optimize-autoloader
```

## Architecture

### Multi-Container Setup
The deployment uses 5 containers that communicate over a private Docker network:

1. **mautic_web**: Handles HTTP requests, runs Apache web server, performs automatic installation and site URL updates
2. **mautic_cron**: Runs scheduled Mautic tasks every 5 minutes (segments update, campaign triggers, email sends)
3. **mautic_worker**: Consumes messages from RabbitMQ queue for async processing
4. **mysql**: MariaDB 10.11 database with persistent storage
5. **rabbitmq**: Message queue for async job processing

### Container Roles
The `CONTAINER_ROLE` environment variable determines container behavior:
- `web` (default): Runs installation logic, updates site URL, starts Apache
- `cron`: Skips installation/URL updates, executes cron loop
- `worker`: Skips installation/URL updates, executes queue consumer

This role-based architecture prevents race conditions during deployment.

### Custom Entrypoint Script
`docker-entrypoint-custom.sh` implements smart installation detection:
- Checks for installation marker file (`/var/www/html/config/.installed`)
- Falls back to database table check (`mautic_users` table existence)
- Only web container performs installation and URL updates
- Non-web containers skip directly to their command execution

### Volume Mounts
Persistent data stored in `./volumes/`:
- `mariadb-data/`: Database files
- `rabbitmq-data/`: Message queue data
- `config/`: Mautic configuration files (local.php)
- `logs/`: Application logs
- `media/`: Uploaded files and images
- `cache/`: Symfony cache (cleared on deployment)

### Custom Image Build
`Dockerfile` extends `mautic/mautic:6-apache`:
- Installs composer dependencies from `composer.json`
- Copies themes from `themes/` to `/var/www/html/docroot/themes/`
- Copies plugins from `plugins/` to `/var/www/html/docroot/plugins/`
- Sets proper ownership for www-data user
- Includes custom entrypoint script

## Development Workflow

### Adding Custom Themes
1. Create directory: `themes/your-theme-name/`
2. Add `config.json` with theme metadata
3. Add template files in `html/` subdirectory (e.g., `email.html.twig`, `page.html.twig`)
4. Commit and push to git
5. Redeploy in Coolify (triggers rebuild)
6. Enable theme in Mautic admin (Configuration > Themes)

**Theme Structure Requirements:**
- `config.json`: Must include `name`, `author`, `features` array
- `html/`: Templates using Twig syntax
- Features: `["email"]`, `["page"]`, or `["email", "page"]`

### Adding Custom Plugins
1. Create directory: `plugins/YourPluginBundle/`
2. Create main bundle class: `YourPluginBundle.php` extending `PluginBundleBase`
3. Create `Config/config.php` with plugin configuration
4. Commit and push to git
5. Redeploy in Coolify
6. Enable plugin in Mautic admin (Plugins section)

**Plugin Structure Requirements:**
- Directory must end with `Bundle`
- Main class must extend `Mautic\PluginBundle\Bundle\PluginBundleBase`
- Config file must define plugin metadata

### Adding Composer Dependencies
1. Edit `composer.json` and add package to `require` section
2. Commit and push to git
3. Redeploy in Coolify (Dockerfile runs `composer install` during build)

**Example:** AWS SES email integration via `symfony/amazon-mailer` is already included.

### Git-Based Deployment Cycle
```bash
# Make changes to themes, plugins, or composer.json
git add .
git commit -m "feat: add custom email theme"
git push

# In Coolify UI:
# - Click "Redeploy" button
# - Wait for build completion
# - Verify changes in Mautic admin
```

## Environment Variables

### Coolify Auto-Generated
These are automatically created by Coolify and should NOT be set manually:
- `SERVICE_PASSWORD_64_MYSQLROOT`: MariaDB root password
- `SERVICE_PASSWORD_64_MYSQL`: MariaDB user password  
- `SERVICE_USER_MYSQL`: MariaDB username
- `SERVICE_PASSWORD_64_RABBITMQ`: RabbitMQ password
- `SERVICE_PASSWORD_64_ADMIN`: Mautic admin password (for automatic installation)
- `SERVICE_USER_RABBITMQ`: RabbitMQ username (defaults to "mautic")
- `SERVICE_URL_MAUTIC_80` or `SERVICE_URL_MAUTIC_WEB`: Mautic public URL

### Mautic Configuration
Standard environment variables for Mautic setup:
- `MAUTIC_DB_HOST`: Database host (default: `mysql`)
- `MAUTIC_DB_PORT`: Database port (default: `3306`)
- `MAUTIC_DB_NAME`: Database name (default: `mautic`)
- `MAUTIC_DB_TABLE_PREFIX`: Table prefix (default: `mautic_`)
- `MAUTIC_MESSENGER_DSN`: RabbitMQ connection string (auto-constructed)
- `MAUTIC_URL`: Public URL (from Coolify)
- `DOCKER_MAUTIC_RUN_MIGRATIONS`: Auto-run migrations (default: `true`)
- `MAUTIC_TRUSTED_PROXIES`: Proxy IP ranges for Traefik

### Admin Installation Variables
Used only during first-time automatic installation:
- `MAUTIC_ADMIN_USERNAME`: Admin username (default: `admin`)
- `MAUTIC_ADMIN_EMAIL`: Admin email
- `MAUTIC_ADMIN_PASSWORD`: Admin password (from Coolify secret)
- `MAUTIC_ADMIN_FIRSTNAME`: Admin first name
- `MAUTIC_ADMIN_LASTNAME`: Admin last name

### PHP Configuration
- `PHP_MEMORY_LIMIT`: Memory limit (default: `256M`)
- `PHP_UPLOAD_MAX_FILESIZE`: Max upload size (default: `100M`)
- `PHP_POST_MAX_SIZE`: Max POST size (default: `100M`)

## Important Notes

### Coolify-Specific Patterns
- **No port exposure**: Coolify handles routing via Traefik automatically
- **Secret naming**: Use `SERVICE_PASSWORD_64_*` pattern for auto-generated 64-char passwords
- **URL variable**: Service URL may be `SERVICE_URL_MAUTIC_80` or `SERVICE_URL_MAUTIC_WEB` depending on Coolify version
- **Build context**: Coolify detects Dockerfile and builds custom image automatically on deploy

### Installation Behavior
- First deployment runs automatic installation if database credentials are present
- Subsequent deployments detect existing installation and skip setup wizard
- Installation marker file (`config/.installed`) is created after successful installation
- Only the web container performs installation logic
- Site URL is automatically updated if `MAUTIC_URL` environment variable changes

### Cache and Permissions
- Cache is cleared on every deployment via entrypoint script
- File permissions are automatically fixed for www-data user
- Themes and plugins must be owned by www-data to be writable

### Testing Changes Locally
Before deploying to Coolify, test locally:
1. Copy `.env.example` to `.env` and fill in values
2. Run `docker compose up -d`
3. Access Mautic at `http://localhost`
4. Verify themes/plugins appear in admin
5. Check logs for errors: `docker compose logs -f`

### Troubleshooting Common Issues
- **Theme not showing**: Clear cache, check file permissions, verify `config.json` structure
- **Plugin not activating**: Check logs for PHP errors, verify namespace and class structure
- **Database connection errors**: Verify credentials in environment variables, check MySQL container health
- **Queue worker not processing**: Check RabbitMQ connection, verify `MAUTIC_MESSENGER_DSN` format
- **Site URL issues**: Check `MAUTIC_URL` environment variable, run URL update via entrypoint

### Security Considerations
- All passwords use Coolify's auto-generated 64-character secrets
- Database and RabbitMQ are not exposed publicly (internal Docker network only)
- Traefik handles SSL certificates automatically
- Never commit `.env` file or secrets to git
