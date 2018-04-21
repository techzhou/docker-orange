FROM centos:7
MAINTAINER Syhily, syhily@gmail.com

# Docker Build Arguments, For further upgrade
ENV ORANGE_PATH="/usr/local/orange"
ARG LOR_VERSION="0.3.4"
ARG LR_VERSION="2.4.4"
ENV ORANGE_VERSION="0.7.0-dev"

ADD docker-entrypoint.sh docker-entrypoint.sh

#  1) Set the bootstrap scripts
#  2) Install yum dependencies
#  3) Cleanup
#  4) Install lor
#  5) Install orange
#  6) Cleanup
#  7) dnsmasq
#  8) Add User
#  9) Add configuration file & bootstrap file
# 10) Fix file permission
RUN \
    chmod 755 docker-entrypoint.sh \
    && mv docker-entrypoint.sh /usr/local/bin \

    && yum-config-manager --add-repo https://openresty.org/yum/cn/centos/OpenResty.repo \
    && yum install -y epel-release \
    && yum install -y dnsmasq openresty openresty-resty make telnet gcc lua-devel unzip \

    && yum clean all \

    && ln -s /usr/local/openresty/nginx/sbin/nginx /usr/local/bin/nginx \

    && cd /tmp \
    && curl -fSL https://github.com/sumory/lor/archive/v${LOR_VERSION}.tar.gz -o lor.tar.gz \
    && tar zxf lor.tar.gz \
    && cd /tmp/lor-${LOR_VERSION} \
    && make install \

    && cd /tmp \
    && curl -fSL https://github.com/sumory/orange/archive/v${ORANGE_VERSION}.tar.gz -o orange.tar.gz \
    && tar zxf orange.tar.gz \
    && cd orange-${ORANGE_VERSION} \
    && make install \
    
    && cd /tmp \
    && curl -fSL https://luarocks.org/releases/luarocks-${LR_VERSION}.tar.gz -o luarocks.tar.gz \
    && tar zxf luarocks.tar.gz \
    && cd luarocks-${LR_VERSION} \
    && ./configure --prefix=/usr/local/openresty/luajit \
    --with-lua=/usr/local/openresty/luajit \
    --lua-suffix=jit-2.1.0-beta3 \
    --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 \
    && make bootstrap \
    && /usr/local/openresty/luajit/bin/luarocks install penlight \
    && /usr/local/openresty/luajit/bin/luarocks install lua-resty-dns-client \
    && /usr/local/openresty/luajit/bin/luarocks install lua-resty-http \
    && /usr/local/openresty/luajit/bin/luarocks install luasocket \

    && cd / \
    && rm -rf /tmp/* \

    && echo "user=root" > /etc/dnsmasq.conf \
    && echo 'domain-needed' >> /etc/dnsmasq.conf \
    && echo 'listen-address=127.0.0.1' >> /etc/dnsmasq.conf \
    && echo 'resolv-file=/etc/resolv.dnsmasq.conf' >> /etc/dnsmasq.conf \
    && echo 'conf-dir=/etc/dnsmasq.d' >> /etc/dnsmasq.conf \
    # This upstream dns server will cause some issues
    && echo 'INTERNAL_DNS' >> /etc/resolv.dnsmasq.conf \
    && echo 'nameserver 8.8.8.8' >> /etc/resolv.dnsmasq.conf \
    && echo 'nameserver 8.8.4.4' >> /etc/resolv.dnsmasq.conf \

    && useradd www \
    && echo "www:www" | chpasswd \
    && echo "www   ALL=(ALL)       ALL" >> /etc/sudoers \
    && mkdir -p ${ORANGE_PATH}/logs \
    && chown -R www:www ${ORANGE_PATH}/*

EXPOSE 7777 80 9999

# Daemon
ENTRYPOINT ["docker-entrypoint.sh"]
