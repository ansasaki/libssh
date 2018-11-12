#!/bin/sh
set -e

fetch_from_github() {
    git clone https://github.com/$1/$2.git -b $3 --depth=1
}

install_from_github() {
    echo "Installing $2"
    fetch_from_github $1 $2 $3
    cd $2
    autoreconf -fvi
    ./configure $4 $5
    make
    sudo -E make install
    cd ..
    echo "$2 installed"
    sudo ldconfig
}

install_openssl() {
    echo "Installing $1"
    fetch_from_github openssl openssl $1
    cd openssl
    OPENSSL_DIR=/usr/local
    ./config shared -fPIC --openssldir=${OPENSSL_DIR} --prefix=${OPENSSL_DIR}
    make depend && make
    sudo make install_sw
    cd ..
    echo "$1 installed"
    sudo ldconfig
    SOFTHSM_OPENSSL_DIR="--with-openssl=${OPENSSL_DIR}"
}

export ARCHES="amd64"

export TRIPLES="amd64-linux-gnu"

for arch in ${ARCHES} ; do \
    sudo dpkg --add-architecture $arch ; \
done

export LIBSSH_DEPS="libcmocka-dev \
                 libnss-wrapper \
                 libsocket-wrapper \
                 libssl-dev \
                 libuid-wrapper \
                 libz-dev"

sudo apt-get update -qq

export CC=`which $CC`
mkdir prerequisites
cd prerequisites

if [ -n "${OPENSSL}" ]; then
    # Remove pre-installed OpenSSL
    sudo apt-get remove openssl libssl-dev

    install_openssl ${OPENSSL}
fi

cd ..
rm -rf prerequisites

sudo apt-get install -y \
        cmake \
        dash \
        dpkg-dev \
        dropbear \
        git-core \
        nmap \
        openssh-client \
        openssh-server \
        openssh-sftp-server \
        libcmocka0 \
        libz-dev \
        $(for dep in ${LIBSSH_DEPS} ; do \
            for arch in ${ARCHES} ; do echo $dep:$arch ; done ; \
        done)

