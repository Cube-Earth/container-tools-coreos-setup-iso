#/bin/sh

# https://wiki.alpinelinux.org/wiki/Installing_Alpine_Linux_in_a_chroot#Troubleshooting
# http://wiki.alpinelinux.org/wiki/Chroot

mirror=http://dl-cdn.alpinelinux.org/alpine/

chroot_dir=/tmp/iso
mkdir -p $chroot_dir

download=`wget -O - ${mirror}/latest-stable/main/x86_64 2>/dev/null | sed -e "s/<a href *= *[\"']\([^\"']\+\)[\"'].*<\/a>.*/\1/g" | grep -E '^apk-tools-static-.*\.apk' | sort -r | head -n 1`
wget ${mirror}/latest-stable/main/x86_64/$download
tar -xzf apk-tools-static-*.apk
./sbin/apk.static -X ${mirror}/latest-stable/main -U --allow-untrusted --root ${chroot_dir} --initdb add alpine-base

branch=`wget -O - ${mirror} 2>/dev/null | sed $'s/\\(<a href=\\)/\\\n\\\\1/g' | grep -E '^<a href' | sed "s/^.* href *= *[\"']\([^\"']\+\)[\"'].*\$/\\1/" | grep -E '^v' | sort -r | head -n 1`
branch=${branch%/}

wget https://nl.alpinelinux.org/alpine/v3.6/releases/x86_64/alpine-virt-3.6.1-x86_64.iso
mount -o loop ./alpine-virt-3.6.1-x86_64.iso /media/cdrom
cp -R /media/cdrom/boot ${chroot_dir}/boot


mknod -m 666 ${chroot_dir}/dev/full c 1 7
mknod -m 666 ${chroot_dir}/dev/ptmx c 5 2
mknod -m 644 ${chroot_dir}/dev/random c 1 8
mknod -m 644 ${chroot_dir}/dev/urandom c 1 9
mknod -m 666 ${chroot_dir}/dev/zero c 1 5
mknod -m 666 ${chroot_dir}/dev/tty c 5 0

mknod -m 666 ${chroot_dir}/dev/sda b 8 0
mknod -m 666 ${chroot_dir}/dev/sda1 b 8 1
mknod -m 666 ${chroot_dir}/dev/sda2 b 8 2
mknod -m 666 ${chroot_dir}/dev/sda3 b 8 3
mknod -m 666 ${chroot_dir}/dev/sda4 b 8 4
mknod -m 666 ${chroot_dir}/dev/sda5 b 8 5
mknod -m 666 ${chroot_dir}/dev/sda6 b 8 6

cp /etc/resolv.conf ${chroot_dir}/etc/resolv.conf
## --> clear this before creating a ISO image!

mkdir -p ${chroot_dir}/etc/apk
echo "${mirror}/${branch}/main" > ${chroot_dir}/etc/apk/repositories

mount -t proc none ${chroot_dir}/proc
mount -o bind /sys ${chroot_dir}/sys
#####mount -o bind /dev ${chroot_dir}/dev



chroot ${chroot_dir} /bin/sh -l


/bin/sh

umount ${chroot_dir}/proc
umount ${chroot_dir}/sys
#####umount ${chroot_dir}/dev

xorrisofs -V "COREOS-SETUP" -follow-links -J -l -R -b boot/syslinux/isolinux.bin -c boot/syslinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o /iso/coreos-setup.iso ${chroot_dir}/
isohybrid /iso/coreos-setup.iso

