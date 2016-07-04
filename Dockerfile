FROM alpine:3.4

ENV OPENRESTY_VERSION 1.9.15.1
ENV OPENRESTY_PREFIX /opt/openresty
ENV NGINX_PREFIX /opt/openresty/nginx
ENV VAR_PREFIX /var/nginx
ENV LAPIS_VERSION 1.5.0

RUN echo "==> Installing dependencies..." \
 && apk update \
 && apk add --virtual build-deps \
    make gcc musl-dev \
    pcre-dev openssl-dev zlib-dev ncurses-dev readline-dev \
    curl perl \
 && mkdir -p /root/ngx_openresty \
 && cd /root/ngx_openresty \
 && echo "==> Downloading OpenResty..." \
 && curl -sSL http://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar -xvz \
 && cd openresty-* \
 && echo "==> Configuring OpenResty..." \
 && readonly NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
 && echo "using upto $NPROC threads" \
 && ./configure \
    --prefix=$OPENRESTY_PREFIX \
    --http-client-body-temp-path=$VAR_PREFIX/client_body_temp \
    --http-proxy-temp-path=$VAR_PREFIX/proxy_temp \
    --http-log-path=$VAR_PREFIX/access.log \
    --error-log-path=$VAR_PREFIX/error.log \
    --pid-path=$VAR_PREFIX/nginx.pid \
    --lock-path=$VAR_PREFIX/nginx.lock \
    --with-luajit \
    --with-pcre-jit \
    --with-ipv6 \
    --with-http_ssl_module \
    --without-http_ssi_module \
    --without-http_userid_module \
    --without-http_uwsgi_module \
    --without-http_scgi_module \
    -j${NPROC} \
 && echo "==> Building OpenResty..." \
 && make -j${NPROC} \
 && echo "==> Installing OpenResty..." \
 && make install \
 && echo "==> Finishing..." \
 && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/nginx \
 && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/openresty \
 && ln -sf $OPENRESTY_PREFIX/bin/resty /usr/local/bin/resty \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* $OPENRESTY_PREFIX/luajit/bin/lua \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* /usr/local/bin/lua \
 && apk del build-deps \
 && apk add \
    libpcrecpp libpcre16 libpcre32 openssl libssl1.0 pcre libgcc libstdc++ \
 && rm -rf /root/ngx_openresty

RUN echo "==> Installing luarocks..." \
    && apk add --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted \
       lua5.1 luarocks5.1 \
    && ln -s /usr/bin/lua5.1 /usr/bin/lua \
    && ln -s /usr/bin/luarocks-5.1 /usr/bin/luarocks

RUN apk update \
    && apk add --virtual luarocks luarocks gcc lua5.1-dev musl-dev openssl-dev git curl unzip \
    && export C_INCLUDE_PATH=/usr/include/lua5.2/ \
    && cd /tmp \
    && luarocks install --server=http://rocks.moonscript.org/manifests/leafo lapis $LAPIS_VERSION \
    && luarocks install moonscript \
    #&& luarocks install lapis-console \
    && apk del luarocks \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/.cache

ENV LAPIS_OPENRESTY $OPENRESTY_PREFIX/nginx/sbin/nginx

EXPOSE 8080
EXPOSE 80

WORKDIR $NGINX_PREFIX/

ONBUILD RUN rm -rf conf/* html/*

# Sample lapis project
RUN cd $NGINX_PREFIX \
    && lapis new \
    && moonc *.moon 

ENTRYPOINT ["lapis"]
CMD ["server", "production"]
