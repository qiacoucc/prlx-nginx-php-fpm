FROM alpine:3.7

ENV PHP_VERSION 7.2

RUN apk add --no-cache bash supervisor

RUN apk --no-cache add ca-certificates openssl && \
  echo "@php https://php.codecasts.rocks/v3.7/php-$PHP_VERSION" >> /etc/apk/repositories

# Install nginx

ENV NGINX_VERSION 1.13.9
ENV VTS_VERSION 0.1.15

RUN GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
  && CONFIG="\
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-http_xslt_module=dynamic \
    --with-http_image_filter_module=dynamic \
    --with-http_geoip_module=dynamic \
    --with-http_perl_module=dynamic \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-stream_realip_module \
    --with-stream_geoip_module=dynamic \
    --with-http_slice_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-compat \
    --with-file-aio \
    --with-http_v2_module \
                --add-module=/usr/src/nginx-module-vts-$VTS_VERSION \
  " \
  && apk add --no-cache --virtual .build-deps \
    gcc \
    libc-dev \
    make \
    openssl-dev \
    pcre-dev \
    zlib-dev \
    linux-headers \
    curl \
    gnupg \
    libxslt-dev \
    gd-dev \
    geoip-dev \
    perl-dev \
  && curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
  && curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
  && curl -fSL https://github.com/vozlt/nginx-module-vts/archive/v$VTS_VERSION.tar.gz  -o nginx-modules-vts.tar.gz \
  && export GNUPGHOME="$(mktemp -d)" \
  && found=''; \
  for server in \
    ha.pool.sks-keyservers.net \
    hkp://keyserver.ubuntu.com:80 \
    hkp://p80.pool.sks-keyservers.net:80 \
    pgp.mit.edu \
  ; do \
    echo "Fetching GPG key $GPG_KEYS from $server"; \
    gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
  done; \
  test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
  gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
  && rm -r "$GNUPGHOME" nginx.tar.gz.asc \
  && mkdir -p /usr/src \
  && tar -zxC /usr/src -f nginx.tar.gz \
  && tar -zxC /usr/src -f nginx-modules-vts.tar.gz \
  && rm nginx.tar.gz nginx-modules-vts.tar.gz \
  && cd /usr/src/nginx-$NGINX_VERSION \
  && ./configure $CONFIG --with-debug \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && mv objs/nginx objs/nginx-debug \
  && mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
  && mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
  && mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
  && mv objs/ngx_http_perl_module.so objs/ngx_http_perl_module-debug.so \
  && mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
  && ./configure $CONFIG \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && make install \
  && rm -rf /etc/nginx/html/ \
  && mkdir /etc/nginx/conf.d/ \
  && mkdir -p /usr/share/nginx/html/ \
  && install -m644 html/index.html /usr/share/nginx/html/ \
  && install -m644 html/50x.html /usr/share/nginx/html/ \
  && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
  && install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
  && install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
  && install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
  && install -m755 objs/ngx_http_perl_module-debug.so /usr/lib/nginx/modules/ngx_http_perl_module-debug.so \
  && install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
  && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
  && strip /usr/sbin/nginx* \
  && strip /usr/lib/nginx/modules/*.so \
  && rm -rf /usr/src/nginx-$NGINX_VERSION \
  \
  # Bring in gettext so we can get `envsubst`, then throw
  # the rest away. To do this, we need to install `gettext`
  # then move `envsubst` out of the way so `gettext` can
  # be deleted completely, then move `envsubst` back.
  && apk add --no-cache --virtual .gettext gettext \
  && mv /usr/bin/envsubst /tmp/ \
  \
  && runDeps="$( \
    scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
      | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
      | sort -u \
      | xargs -r apk info --installed \
      | sort -u \
  )" \
  && apk add --no-cache --virtual .nginx-rundeps $runDeps \
  && apk add --no-cache logrotate \
  && apk del .build-deps \
  && apk del .gettext \
  && mv /tmp/envsubst /usr/local/bin/ \
  \
  # forward request and error logs to docker log collector
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

# Nginx temp upload dir
RUN mkdir -p /var/nginx-uploads && chown nobody:nobody /var/nginx-uploads

RUN mkdir -p /var/cache/nginx/client_temp && \
  mkdir -p /var/cache/nginx/proxy_temp && \
  mkdir -p /var/cache/nginx/fastcgi_temp && \
  mkdir -p /var/cache/nginx/uwsgi_temp && \
  mkdir -p /var/cache/nginx/scgi_temp

RUN chown -R nobody:nobody /var/cache/nginx/client_temp && \
 chown -R nobody:nobody /var/cache/nginx/proxy_temp && \
 chown -R nobody:nobody /var/cache/nginx/fastcgi_temp && \
 chown -R nobody:nobody /var/cache/nginx/uwsgi_temp && \
 chown -R nobody:nobody /var/cache/nginx/scgi_temp

# php-fpm-exporter for prometheus
ADD https://github.com/bakins/php-fpm-exporter/releases/download/v0.3.3/php-fpm-exporter.linux.amd64 /usr/local/bin/php-fpm-exporter

RUN chmod +x /usr/local/bin/php-fpm-exporter

# nginx exporter for prometheus
ADD https://github.com/hnlq715/nginx-vts-exporter/releases/download/v0.9.1/nginx-vts-exporter-0.9.1.linux-amd64.tar.gz /tmp/nginx-exporter

RUN cd /tmp && \
  gzip -dc /tmp/nginx-exporter | tar xf - && \
  cd /tmp/nginx-vts-* && \
  chmod +x nginx-vts-exporter && \
  mv nginx-vts-exporter /usr/local/bin/nginx-vts-exporter

RUN chmod +x /usr/local/bin/nginx-vts-exporter

# Add PHP public keys 
ADD https://php.codecasts.rocks/php-alpine.rsa.pub /etc/apk/keys/php-alpine.rsa.pub

RUN apk add --no-cache \
  php7@php \
  php7-common@php \
  php7-curl@php \
  php7-dom@php \
  php7-exif@php \
  php7-ftp@php \
  php7-gd@php \
  php7-iconv@php \
  php7-mbstring@php \
  php7-mysqli@php \
  php7-mysqlnd@php \
  php7-openssl@php \
  php7-pdo@php \
  php7-session@php \
  php7-posix@php \
  php7-soap@php \
  php7-zip@php \
  php7-ldap@php \
  php7-bcmath@php \
  php7-calendar@php \
  php7-gettext@php \
  php7-json@php \
  php7-pcntl@php \
  php7-apcu@php \
  php7-phar@php \
  php7-sockets@php \
  php7-tidy@php \
  php7-wddx@php \
  php7-xmlreader@php \
  php7-zip@php \
  php7-zlib@php \
  php7-xsl@php \
  php7-opcache@php \
  php7-imagick@php \
  php7-ctype@php \ 
  php7-pdo_mysql@php \ 
  php7-pdo_sqlite@php \ 
  php7-sqlite3@php \ 
  php7-redis@php \ 
  php7-fpm@php \
  supervisor 

# These only exist in 7.1, not 7.2
#RUN apk add --no-cache php7-mcrypt@php \
#  php7-xmlrpc@php

RUN mkdir -p /src; \
  ln -s /etc/php7 /etc/php; \
  ln -s /usr/bin/php7 /usr/bin/php

# Supervisor
ADD conf/supervisord.conf /etc/supervisord.conf

# Scripts
ADD scripts/start.sh /start.sh
RUN chmod 755 /start.sh

ADD conf/nginx.conf /etc/nginx/nginx.conf

ADD conf/nginx-site.conf /etc/nginx/sites-enabled/site.conf
ADD conf/nginx-status.conf /etc/nginx/sites-enabled/status.conf

# Test Nginx
RUN nginx -c /etc/nginx/nginx.conf -t

## PHP
ADD conf/php-fpm.conf /etc/php7/php-fpm.conf
ADD conf/php.ini /etc/php7/php.ini
ADD conf/php-www.conf /etc/php7/php-fpm.d/www.conf

# Test PHP-FPM
RUN /usr/sbin/php-fpm7 --fpm-config /etc/php7/php-fpm.conf -t

RUN apk add --no-cache nano curl

CMD ["/start.sh"]