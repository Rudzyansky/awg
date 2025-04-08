FROM golang:1.24 AS awg
ARG AWG_VERSION
RUN apt-get -qq update && apt-get -qq install -y musl-tools ca-certificates wget
ENV CC=/usr/bin/musl-gcc
RUN wget "https://github.com/amnezia-vpn/amneziawg-go/archive/refs/tags/$AWG_VERSION.tar.gz" && \
    tar zxf "$AWG_VERSION.tar.gz" && \
    mv "amneziawg-go-${AWG_VERSION#?}" /awg
WORKDIR /build
WORKDIR /awg
RUN go mod download && \
    go mod verify && \
    go build -ldflags '-linkmode external -extldflags "-fno-PIC -static"' -v -o /build


FROM alpine:3.19 AS awg-tools
ARG AWG_TOOLS_VERSION
RUN apk add ca-certificates git linux-headers build-base wget
RUN wget "https://github.com/amnezia-vpn/amneziawg-tools/archive/refs/tags/$AWG_TOOLS_VERSION.tar.gz" && \
    tar zxf "$AWG_TOOLS_VERSION.tar.gz" && \
    mv "amneziawg-tools-${AWG_TOOLS_VERSION#?}" /awg-tools
WORKDIR /build
WORKDIR /awg-tools/src
RUN make && \
    cp wg /build/awg && \
    cp wg-quick/linux.bash /build/awg-quick


FROM alpine:3.19
RUN apk update && apk add --no-cache bash openrc iptables iptables-legacy iproute2
COPY --from=awg /build/amneziawg-go /usr/bin/amneziawg-go
COPY --from=awg-tools /build/awg /usr/bin/awg
COPY --from=awg-tools /build/awg-quick /usr/bin/awg-quick
ADD wireguard-fs /
RUN chmod +x /etc/init.d/wg-quick /data/pre_up.sh /data/healthcheck.sh

RUN sed -i 's/^\(tty\d\:\:\)/#\1/' /etc/inittab && \
    sed -i \
        -e 's/^#\?rc_env_allow=.*/rc_env_allow="\*"/' \
        -e 's/^#\?rc_sys=.*/rc_sys="docker"/' \
        /etc/rc.conf && \
    sed -i \
        -e 's/VSERVER/DOCKER/' \
        -e 's/checkpath -d "$RC_SVCDIR"/mkdir "$RC_SVCDIR"/' \
        /lib/rc/sh/init.sh && \
    rm  /etc/init.d/hwdrivers \
        /etc/init.d/machine-id
RUN sed -i 's/cmd sysctl -q \(.*\?\)=\(.*\)/[[ "$(sysctl -n \1)" != "\2" ]] \&\& \0/' /usr/bin/awg-quick
RUN ln -s /sbin/iptables-legacy /bin/iptables && \
    ln -s /sbin/iptables-legacy-save /bin/iptables-save && \
    ln -s /sbin/iptables-legacy-restore /bin/iptables-restore
# register /etc/init.d/wg-quick
RUN rc-update add wg-quick default

VOLUME ["/sys/fs/cgroup"]
HEALTHCHECK --interval=15m --timeout=30s CMD ["/data/healthcheck.sh"]
CMD ["/sbin/init"]
