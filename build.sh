#!/bin/bash

EJABBERD_VERSION="21.04"

set -e

build_container=$(buildah from --override-arch="" alpine:latest)
build_mount=$(buildah mount $build_container)
runtime_container=$(buildah from --override-arch="" alpine:latest)
runtime_mount=$(buildah mount $runtime_container)

echo "======================================================================="
echo "build_container=$build_container"
echo "build_mount=$build_mount"
echo ""
echo "runtime_container=$runtime_container"
echo "runtime_mount=$runtime_mount"
echo "======================================================================="

ERLANG_PKGS="erlang"


#
# Build Container
#

buildah run $build_container apk upgrade --update musl
buildah run $build_container apk add build-base git zlib-dev openssl-dev yaml-dev \
    expat-dev sqlite-dev gd-dev jpeg-dev libpng-dev libwebp-dev autoconf automake \
    bash elixir file curl linux-pam-dev
buildah run $build_container apk add $ERLANG_PKGS
buildah run $build_container rm -rf /var/cache/apk/*

buildah run $build_container addgroup -S ejabberd
buildah run $build_container adduser -D -S -G ejabberd --home /var/lib/ejabberd ejabberd

buildah run $build_container git clone https://github.com/processone/ejabberd /opt/ejabberd-src
buildah config --workingdir /opt/ejabberd-src $build_container
buildah run $build_container git checkout $EJABBERD_VERSION
buildah run $build_container sh ./autogen.sh
buildah run $build_container ./configure \
                                   --enable-user=ejabberd  \
                                   --enable-group=ejabberd \
                                   --enable-sqlite         \
                                   --enable-zlib           \
                                   --enable-stun           \
                                   --sysconfdir=/etc       \
                                   --localstatedir=/var
buildah run $build_container make
buildah run $build_container make install


#
# Runtime Container
#

buildah run $runtime_container apk upgrade --update musl
buildah run $runtime_container apk add busybox expat freetds gd jpeg libgd libpng \
    libcrypto1.1 libgcc libgd libjpeg-turbo libpng libssl1.1 libstdc++ libwebp    \
    musl ncurses-libs openssl python3 sqlite sqlite-libs util-linux yaml zlib
buildah run $runtime_container apk add $ERLANG_PKGS
buildah run $runtime_container rm -rf /var/cache/apk/*

buildah run $runtime_container addgroup -S ejabberd
buildah run $runtime_container adduser -D -S -G ejabberd --home /var/lib/ejabberd ejabberd

for d in /etc/ejabberd /var/lib/ejabberd /var/log/ejabberd /usr/local; do
    mkdir -p $runtime_mount/$d
    rsync -a $build_mount/$d/ $runtime_mount/$d/
done


# Image configuration
buildah config --user ejabberd:ejabberd $runtime_container
buildah config --workingdir /var/lib/ejabberd $runtime_container
buildah config --entrypoint '["/usr/local/sbin/ejabberdctl"]' $runtime_container
buildah config --cmd foreground $runtime_container

# Volumes
buildah config --volume /etc/ejabberd $runtime_container
buildah config --volume /var/lib/ejabberd $runtime_container
buildah config --volume /var/log/ejabberd $runtime_container

# Ports
buildah config --port 5222 $runtime_container
buildah config --port 5269 $runtime_container
buildah config --port 5280 $runtime_container
buildah config --port 5443 $runtime_container

# Commit
ARCH=$(buildah info --format {{".host.arch"}})
if [[ $ARCH -eq arm ]]; then
  case $(grep -i -m1 "CPU architecture" /proc/cpuinfo | cut -f3 -d" ") in
    7) VARIANT="v7";;
  esac
  ARCH="$ARCH$VARIANT"
fi
TAG="$ARCH-$EJABBERD_VERSION"
buildah commit $runtime_container ejabberd:$TAG

# Clean up
buildah unmount $build_container
buildah unmount $runtime_container
buildah rm $build_container $runtime_container

