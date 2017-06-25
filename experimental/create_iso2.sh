#!/bin/sh
# based on https://wiki.alpinelinux.org/wiki/How_to_make_a_custom_ISO_image
apk update
apk add alpine-sdk xorriso syslinux
abuild-keygen -ian
git clone git://git.alpinelinux.org/alpine-iso
cd alpine-iso

cat >> coreos-setup.conf.mk << EOF
ALPINE_NAME   := coreos-setup
KERNEL_FLAVOR := grsec
EOF

cat >> coreos-setup.packages << EOF
alpine-base
e2fsprogs
util-linux
EOF

make PROFILE=coreos-setup iso
