#!/bin/bash

VERSION=$(\
    curl -fsSL 'https://www.libressl.org/' \
        | grep 'The latest stable release is' \
        | perl -p -e 's/^.+? release is ([0-9.]+).*$/$1/' \
)

echo "LIBRESSL_VERSION := "$VERSION
