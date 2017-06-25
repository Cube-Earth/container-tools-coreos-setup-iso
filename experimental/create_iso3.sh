#!/bin/sh
apk add build-base apk-tools alpine-conf busybox fakeroot syslinux xorriso alpine-sdk sudo
#apk add mtools dosfstools grub-efi
apk update
addgroup sudo
adduser build abuild
adduser build sudo
echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
#useradd build -G abuild
#addgroup abuild
#adduser -D -g '' -G abuild -s /sbin/nologin build

su -s /bin/sh build
abuild-keygen -ian

git clone git://git.alpinelinux.org/aports
export PROFILENAME=coreos_setup

cat << EOF > /tmp/aports/scripts/mkimg.$PROFILENAME.sh
profile_$PROFILENAME() {
  profile_standard
  kernel_flavors="grsec"
  kernel_cmdline="unionfs_size=512M console=tty0 console=ttyS0,115200"
  syslinux_serial="0 115200"
  kernel_addons="zfs spl"
  apks="\$apks e2fsprogs util-linux"
  local _k _a
  for _k in \$kernel_flavors; do
    apks="\$apks linux-\$_k"
    for _a in \$kernel_addons; do
      apks="\$apks \$_a-\$_k"
    done
  done
  apks="\$apks linux-firmware"
}
EOF

chmod +x /tmp/aports/scripts/mkimg.$PROFILENAME.sh
mkdir -p /iso

cd aports/scripts

sh mkimage.sh --tag v3.5 \
	--outdir /iso \
	--arch x86_64 \
	--repository http://dl-cdn.alpinelinux.org/alpine/v3.5/main \
	--profile $PROFILENAME
