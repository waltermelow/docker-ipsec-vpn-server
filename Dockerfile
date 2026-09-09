FROM alpine:3.23

# ############################################################################################ #
# Use example:
#     docker run --rm --network none -e VPN_DNS_NAME=name-server.com -e VPN_CLIENT_NAME=new-client-name-1 -v ./ikev2-vpn-data:/etc/ipsec.d ipsec-vpn-server:20260923
#     docker run --rm --network none -e VPN_DNS_NAME=name-server.com -e VPN_CLIENT_NAME=new-client-name-1 -v ./ikev2-vpn-data:/etc/ipsec.d ipsec-vpn-server:20260923 --auto
#     docker run --rm --network none -v ./ikev2-vpn-data:/etc/ipsec.d ipsec-vpn-server:20260923 --addclient "new-client-name-2"
#     docker run --rm --network none -v ./ikev2-vpn-data:/etc/ipsec.d ipsec-vpn-server:20260923 --listclients
#                                                                                              #
# Source Repo 1: https://github.com/hwdsl2/setup-ipsec-vpn                                     #
# Source Repo 2: https://github.com/hwdsl2/docker-ipsec-vpn-server                             #
#                                                                                              #
# Source file 1: https://github.com/hwdsl2/setup-ipsec-vpn/blob/master/extras/ikev2setup.sh    #
# Source file 2: https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/Dockerfile      #
# ############################################################################################ #

ENV SWAN_VER=5.4
WORKDIR /opt/src

RUN set -x \
    && apk add --no-cache \
         bash bind-tools ca-certificates coreutils openssl uuidgen wget xl2tpd iptables iptables-legacy ip6tables \
         iproute2 libcap-ng libcurl libevent linux-pam musl nspr nss nss-tools openrc \
         bison flex gcc make libc-dev bsd-compat-headers linux-pam-dev \
         nss-dev libcap-ng-dev libevent-dev curl-dev nspr-dev \
    && cd /sbin \
    && for fn in iptables iptables-save iptables-restore \
                 ip6tables ip6tables-save ip6tables-restore; do \
         ln -fs xtables-legacy-multi "$fn"; done \
    && cd /opt/src \
    && ( wget -t 3 -T 30 -nv -O libreswan.tar.gz "https://github.com/libreswan/libreswan/archive/v${SWAN_VER}.tar.gz" \
      || wget -t 3 -T 30 -nv -O libreswan.tar.gz "https://download.libreswan.org/libreswan-${SWAN_VER}.tar.gz" ) \
    && tar xzf libreswan.tar.gz \
    && rm -f libreswan.tar.gz \
    && cd "libreswan-${SWAN_VER}" \
    && printf 'WERROR_CFLAGS=-w -s\nUSE_DNSSEC=false\n' > Makefile.inc.local \
    && printf 'FINALNSSDIR=/etc/ipsec.d\nNSSDIR=/etc/ipsec.d\n' >> Makefile.inc.local \
    && make -s base \
    && make -s install-base \
    && cd /opt/src \
    && mkdir -p /run/openrc \
    && touch /run/openrc/softlevel \
    && rm -rf "/opt/src/libreswan-${SWAN_VER}" \
    && apk del --no-cache \
         bison flex gcc make libc-dev bsd-compat-headers linux-pam-dev \
         nss-dev libcap-ng-dev libevent-dev curl-dev nspr-dev

# DML Antes: RUN wget -t 3 -T 30 -nv -O /opt/src/ikev2.sh https://github.com/hwdsl2/setup-ipsec-vpn/raw/ae78dcdc77546a7856dff783a2cbf5305ac56817/extras/ikev2setup.sh
# DML Añadido 'ikev2setup.sh' desde: https://github.com/hwdsl2/setup-ipsec-vpn/blob/master/extras/ikev2setup.sh
COPY ./ikev2setup.sh /opt/src/ikev2.sh
RUN chmod +x /opt/src/ikev2.sh \
    && ln -s /opt/src/ikev2.sh /usr/bin/ikev2.sh
# run.sh: es necesario porque se llama desde ikev2.sh
COPY ./run.sh /opt/src/run.sh
COPY ./LICENSE.md /opt/src/LICENSE.md

# DML Corregir el tipo de fichero de CRLF (Windows) a LF (Unix/Linux)
RUN sed -i 's/\r$//' /opt/src/ikev2.sh /opt/src/run.sh


# run.sh levanta el servidor IPSec StrongSwan
# DML: Comentamos porque no queremos que levante tunel: COPY ./run.sh /opt/src/run.sh
# DML: Comentamos porque no queremos que levante tunel: RUN chmod 755 /opt/src/run.sh

EXPOSE 500/udp 4500/udp

# run.sh levanta el servidor IPSec StrongSwan
# DML: Comentamos porque NO queremos que levante tunel: CMD ["/opt/src/run.sh"]
# CMD ["/bin/sh", "-c", "/opt/src/ikev2.sh --auto"]
# ENTRYPOINT ["/opt/src/ikev2.sh"]
ENTRYPOINT ["/usr/bin/ikev2.sh"]
CMD ["--auto"]

ARG BUILD_DATE
ARG VERSION
ARG VCS_REF
ENV IMAGE_VER=$BUILD_DATE

LABEL maintainer="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.created="$BUILD_DATE" \
    org.opencontainers.image.version="$VERSION" \
    org.opencontainers.image.revision="$VCS_REF" \
    org.opencontainers.image.authors="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.title="IPsec VPN Server on Docker" \
    org.opencontainers.image.description="Docker image to run an IPsec VPN server, with IPsec/L2TP, Cisco IPsec and IKEv2." \
    org.opencontainers.image.url="https://github.com/hwdsl2/docker-ipsec-vpn-server" \
    org.opencontainers.image.source="https://github.com/hwdsl2/docker-ipsec-vpn-server" \
    org.opencontainers.image.documentation="https://github.com/hwdsl2/docker-ipsec-vpn-server"
