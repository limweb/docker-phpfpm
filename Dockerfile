FROM microsoft/mssql-tools as mssql
FROM php:7.4.0-fpm-alpine3.10
MAINTAINER Jitendra Adhikari <jiten.adhikary@gmail.com>

COPY --from=mssql /opt/microsoft/ /opt/microsoft/
COPY --from=mssql /opt/mssql-tools/ /opt/mssql-tools/
COPY --from=mssql /usr/lib/libmsodbcsql-13.so /usr/lib/libmsodbcsql-13.so

RUN set -xe \
    && apk add --no-cache --virtual .persistent-deps \
        freetds \
        unixodbc \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        unixodbc-dev \
        freetds-dev \
    && docker-php-source extract \
    && docker-php-ext-install pdo_dblib \
    && pecl install \
        sqlsrv \
        pdo_sqlsrv \
    && docker-php-ext-enable --ini-name 30-sqlsrv.ini sqlsrv \
    && docker-php-ext-enable --ini-name 35-pdo_sqlsrv.ini pdo_sqlsrv \
    && docker-php-source delete \
    && apk del .build-deps
    
ENV XHPROF_VERSION=5.0.1
ENV PHALCON_VERSION=4.0.0-rc.3
ENV SWOOLE_VERSION=4.4.12
ENV PECL_EXTENSIONS="ast igbinary imagick lzf mongodb msgpack psr redis ssh2-1.2 uuid xdebug yaml"
ENV PECL_BUNDLE="memcached event"

# deps
RUN \
  apk add -U --virtual temp \
    # dev deps
    autoconf g++ file re2c make zlib-dev libtool pcre-dev libxml2-dev bzip2-dev libzip-dev \
      icu-dev gettext-dev imagemagick-dev openldap-dev libpng-dev gmp-dev yaml-dev postgresql-dev \
      libxml2-dev tidyhtml-dev libmemcached-dev libssh2-dev libevent-dev \
    # prod deps
    && apk add icu gettext imagemagick libzip libbz2 libxml2-utils openldap-back-mdb openldap yaml \
      libpq tidyhtml imap-dev libmemcached libssh2 libevent

# php extensions
RUN \
  docker-php-source extract \
    && pecl channel-update pecl.php.net \
    && pecl install $PECL_EXTENSIONS \
    && cd /usr/src/php/ext/ \
    && for BUNDLE_EXT in $PECL_BUNDLE; do pecl bundle $BUNDLE_EXT; done \
    && docker-php-ext-enable $(echo $PECL_EXTENSIONS | sed -E 's/\-[^ ]+//g') opcache 
    
ENV PHP_EXTENSIONS="bcmath bz2 calendar exif gd gettext gmp imap intl ldap mysqli pcntl pdo_mysql pgsql pdo_pgsql \
  soap sockets swoole swoole_async sysvshm sysvmsg sysvsem tidy zip"
 
RUN \    
   curl -sSLo swoole.tar.gz https://github.com/swoole/swoole-src/archive/v$SWOOLE_VERSION.tar.gz \
      && curl -sSLo swoole_async.tar.gz https://github.com/swoole/ext-async/archive/v$SWOOLE_VERSION.tar.gz \
      && tar xzf swoole.tar.gz && tar xzf swoole_async.tar.gz \
      && mv swoole-src-$SWOOLE_VERSION swoole && mv ext-async-$SWOOLE_VERSION swoole_async \
      && rm -f swoole.tar.gz swoole_async.tar.gz \      
      && docker-php-ext-install -j "$(nproc)" $PHP_EXTENSIONS $PECL_BUNDLE \
    && cd /usr/local/etc/php/conf.d/ \
      && mv docker-php-ext-event.ini docker-php-ext-zevent.ini \
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
