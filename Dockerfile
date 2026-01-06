# Custom Mautic 6 image with themes, plugins, and composer dependencies
FROM mautic/mautic:6-apache

# Set working directory
WORKDIR /var/www/html

# Copy composer.json and install additional dependencies
COPY composer.json /tmp/composer.json
RUN composer install --no-dev --optimize-autoloader --working-dir=/var/www/html

# Copy custom themes to themes directory
COPY themes/ /var/www/html/docroot/themes/

# Copy custom plugins to plugins directory
COPY plugins/ /var/www/html/docroot/plugins/

# Set proper ownership for www-data user
RUN chown -R www-data:www-data /var/www/html/docroot/themes && \
    chown -R www-data:www-data /var/www/html/docroot/plugins && \
    chown -R www-data:www-data /var/www/html/vendor

# Create entrypoint script to skip setup on existing installations
RUN echo '#!/bin/bash' > /usr/local/bin/docker-entrypoint.sh && \
    echo 'if [ -f /var/www/html/docroot/app/config/local.php ]; then' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  echo "Mautic already installed, skipping setup..."' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  exec apache2-foreground "$@"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'else' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  echo "First run, executing Mautic setup..."' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  exec /var/www/html/docker-entrypoint.sh "$@"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

# Clear cache to ensure fresh state
RUN rm -rf /var/www/html/var/cache/* && \
    rm -rf /var/www/html/var/log/*

# Set default command
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
