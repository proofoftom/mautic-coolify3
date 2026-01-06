# Custom Mautic 6 image with themes, plugins, and composer dependencies
FROM mautic/mautic:6-apache

# Set working directory
WORKDIR /var/www/html

# Copy composer.json and install additional dependencies
COPY composer.json /tmp/composer.json
RUN composer install --no-dev --optimize-autoloader --working-dir=/var/www/html

# Copy custom themes to the themes directory
COPY themes/ /var/www/html/docroot/themes/

# Copy custom plugins to the plugins directory
COPY plugins/ /var/www/html/docroot/plugins/

# Set proper ownership for www-data user
RUN chown -R www-data:www-data /var/www/html/docroot/themes && \
    chown -R www-data:www-data /var/www/html/docroot/plugins && \
    chown -R www-data:www-data /var/www/html/vendor

# Clear cache to ensure fresh state
RUN rm -rf /var/www/html/var/cache/* && \
    rm -rf /var/www/html/var/log/*

# Set default command
CMD ["apache2-foreground"]
