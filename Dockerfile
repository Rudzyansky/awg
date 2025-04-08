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
RUN apk --no-cache add iproute2 iptables bash
COPY --from=awg /build/amneziawg-go /usr/bin/amneziawg-go
COPY --from=awg-tools /build/awg /usr/bin/awg
COPY --from=awg-tools /build/awg-quick /usr/bin/awg-quick
RUN ln -s /usr/bin/awg /usr/bin/wg && \
    ln -s /usr/bin/awg-quick /usr/bin/wg-quick
