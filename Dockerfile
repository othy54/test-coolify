FROM php:8.3-apache

# Système + extensions PHP
RUN apt-get update && apt-get install -y \
    git unzip curl gnupg ca-certificates libzip-dev libicu-dev libonig-dev \
    && docker-php-ext-install pdo pdo_mysql mysqli zip intl opcache \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Node 20 (pour build Sage)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html


# 1) Dépendances PHP Bedrock
COPY composer.json composer.lock* ./
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader

# 2) Code projet
COPY . .

# 3) Build assets Sage
WORKDIR /var/www/html/web/app/themes/sage
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader \
    && npm ci \
    && npm run build

# 4) Apache docroot -> /web
WORKDIR /var/www/html
RUN sed -ri -e 's!/var/www/html!/var/www/html/web!g' /etc/apache2/sites-available/000-default.conf \
    && sed -ri -e 's!/var/www/!/var/www/html/web/!g' /etc/apache2/apache2.conf

RUN chown -R www-data:www-data /var/www/html

EXPOSE 80
CMD ["apache2-foreground"]