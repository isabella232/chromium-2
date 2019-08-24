FROM debian:jessie

RUN apt-get update -y

RUN apt-get install -y \
    build-essential \
    curl \
    git \
    lsb-base \
    lsb-release \
    sudo

# Setup a proper build environment
WORKDIR /
RUN git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git && \
    echo Etc/UTC > /etc/timezone && \
    echo tzdata tzdata/Areas select Etc | debconf-set-selections && \
    echo tzdata tzdata/Zones/Etc UTC | debconf-set-selections && \
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections

ENV PATH=/depot_tools:$PATH

# Checkout the appropriate sources
RUN mkdir -p /chromium

WORKDIR /chromium
RUN fetch --nohooks chromium

# Take commit from https://omahaproxy.appspot.com/
ARG VERSION=f5a1ee45b812b96c33344099823899840b77b2e0

WORKDIR /chromium/src
RUN git checkout $VERSION

# The following is separate run statements to take advantage of caching when single lines need to change during debugging
RUN ./build/install-build-deps.sh --no-arm --no-prompt --no-syms --no-chromeos-fonts
RUN gclient sync --with_branch_heads
RUN gclient runhooks
RUN gn gen out/Default
COPY build-args.gn /chromium/src/out/Default/args.gn
RUN gn gen out/Default
RUN echo "deb [check-valid-until=no] http://archive.debian.org/debian jessie-backports main" >> /etc/apt/sources.list
RUN apt-get -o Acquire::Check-Valid-Until=false -y update && \
    apt-get install -o Acquire::Check-Valid-Until=false -y -t jessie-backports ca-certificates-java openjdk-8-jdk && \
    rm -rf /usr/bin/java && \
    ln -s /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java /usr/bin/java
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/bin
RUN autoninja -C out/Default chrome
WORKDIR /chromium/src/out
RUN mv Default chrome-linux && zip -r /chrome-linux-${VERSION}.zip chrome-linux