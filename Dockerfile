FROM php:7.4.0-fpm-alpine3.10

MAINTAINER Jitendra Adhikari <jiten.adhikary@gmail.com>

ENV XHPROF_VERSION=5.0.1
ENV PHALCON_VERSION=4.0.0-rc.3
ENV PECL_EXTENSIONS="ast igbinary imagick psr redis uuid xdebug yaml"
ENV PHP_EXTENSIONS="bcmath bz2 calendar exif gd gettext gmp intl ldap mysqli pcntl pdo_mysql pgsql pdo_pgsql soap zip"

# deps
RUN \
  apk add -U --virtual temp \
    autoconf g++ file re2c make zlib-dev libtool pcre-dev libxml2-dev bzip2-dev libzip-dev \
      icu-dev gettext-dev imagemagick-dev openldap-dev libpng-dev gmp-dev yaml-dev postgresql-dev \
    && apk add icu gettext imagemagick libzip libbz2 libxml2-utils openldap-back-mdb openldap yaml libpq

# php extensions
RUN \
  docker-php-source extract \
    && pecl channel-update pecl.php.net \
    && pecl install $PECL_EXTENSIONS \
    && docker-php-ext-enable ${PECL_EXTENSIONS//[-\.0-9]/} opcache \
    && docker-php-ext-install -j "$(nproc)" $PHP_EXTENSIONS \
    && pecl clear-cache

# tideways_xhprof
RUN \
  curl -sSLo /tmp/xhprof.tar.gz https://github.com/tideways/php-xhprof-extension/archive/v$XHPROF_VERSION.tar.gz \
    && tar xzf /tmp/xhprof.tar.gz && cd php-xhprof-extension-$XHPROF_VERSION \
    && phpize && ./configure \
    && make && make install \
    && docker-php-ext-enable tideways_xhprof

# phalcon
RUN \
  curl -sSLo /tmp/phalcon.tar.gz https://codeload.github.com/phalcon/cphalcon/tar.gz/v$PHALCON_VERSION \
    && cd /tmp/ && tar xzf phalcon.tar.gz \
    && cd cphalcon-$PHALCON_VERSION/build && sh install \
    && docker-php-ext-enable phalcon --ini-name docker-php-ext-phalcon.ini

# composer
RUN \
  curl -sSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# cleanup
RUN \
  apk del temp \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man/* \
    && docker-php-source delete
