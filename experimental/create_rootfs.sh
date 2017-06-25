#!/bin/sh

outputdir=/tmp/output
workdir=/tmp/workdir

rm -R $workdir
mkdir -p $outputdir $workdir

#apk add squashfs-tools xorriso syslinux abuild gcc

function create_apk_keys
{
  n=`ls /root/.abuild/*.rsa 2>/dev/null | wc -l`
  if [[ "$n" -eq 0 ]]
  then
    abuild-keygen -ian
  fi
}

function create_rootfs
{
  outdir=$1
  tmp_initfs=$workdir/initfs
  tmp2_initfs=$workdir/initfs2

  mkdir -p $tmp_initfs $outdir


  apk add --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories --initdb --update --no-script --root $tmp_initfs linux-firmware dahdi-linux linux-grsec dahdi-linux-grsec xtables-addons-grsec mkinitfs #e2fsprogs-extra #alpine-base
  # linux-grsec xtables-addons

  cp -r /etc/apk/keys $tmp_initfs/etc/apk/
  
  cp /sbin/init $tmp_initfs
  
  cat << EOF > $tmp_initfs/etc/inittab
# /etc/inittab
### ----

::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

# Set up a couple of getty's
tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
tty3::respawn:/sbin/getty 38400 tty3
tty4::respawn:/sbin/getty 38400 tty4
tty5::respawn:/sbin/getty 38400 tty5
tty6::respawn:/sbin/getty 38400 tty6

# Put a getty on the serial port
#ttyS0::respawn:/sbin/getty -L ttyS0 115200 vt100

# Stuff to do for the 3-finger salute
::ctrlaltdel:/sbin/reboot

# Stuff to do before rebooting
::shutdown:/sbin/openrc shutdown
EOF

  MODLOOP_KERNEL_RELEASE=`ls $tmp_initfs/lib/modules`

  #strip -g $tmp_initfs/bin/* $tmp_initfs/sbin/* $tmp_initfs/lib/* 2>/dev/null

  mkinitfs -F "ata base bootchart cdrom squashfs ext2 ext3 ext4 mmc raid scsi usb virtio" -t $tmp2_initfs -b $tmp_initfs -o $outdir/initramfs-grsec ${MODLOOP_KERNEL_RELEASE}
}

function create_modloop
{
  outdir=$1
  tmp_modloop=$workdir/modloop

  mkdir -p $tmp_modloop/tmp $outdir

  apk add --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories --initdb --update --no-script --root $tmp_modloop/tmp linux-firmware dahdi-linux linux-grsec dahdi-linux-grsec xtables-addons-grsec mkinitfs #alpine-base
  # linux-grsec xtables-addons

  MODLOOP_KERNEL_RELEASE=`ls $tmp_modloop/tmp/lib/modules`
  
  mkdir -p $tmp_modloop/lib/modules/
  
  mv $tmp_modloop/tmp/lib/modules/* $tmp_modloop/lib/modules/
  if [[ -d $tmp_modloop/tmp/lib/firmware ]]
  then
    for FW in `find $tmp_modloop/lib/modules -type f -name "*.ko" | xargs modinfo -F firmware | sort -u`
    do
	  if [[ -e "$tmp_modloop/tmp/lib/firmware/$FW" ]]
	  then
        install -pD "$tmp_modloop/tmp/lib/firmware/$FW" "$tmp_modloop/lib/modules/firmware/$FW"
      fi
    done
  fi  
  
  depmod $MODLOOP_KERNEL_RELEASE -b $tmp_modloop
  mksquashfs $tmp_modloop/lib $outdir/modloop-grsec -comp xz
}


function create_syslinux_dir
{
  outdir=$1
  mkdir -p $outdir
  for f in isolinux.bin ldlinux.c32 libutil.c32 libcom32.c32 mboot.c32
  do
    cp /usr/share/syslinux/$f $outdir/
  done

  cat > $outdir/syslinux.cfg << EOF
timeout 20
prompt 1
default grsec
label grsec
    kernel /boot/vmlinuz-grsec
    append initrd=/boot/initramfs-grsec modloop=/boot/modloop-grsec modules=loop,squashfs,sd-mod,usb-storage quiet pkgs=e2fsprogs-extra,util-linux
EOF
}

function create_boot_files
{
	# creates System.map-grsec, config-grsec and vmlinuz-grsec in /boot

	outdir=$1
	
	mkdir -p $outdir
	
    apk fetch --stdout --quiet --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories linux-grsec | tar -C $outdir -xz boot

}


function create_apks
{
  outdir=$1
  
  pkgdir=$outdir/`uname -m`
  mkdir -p $pkgdir
  touch $outdir/.boot_repository
    
  apk fetch --output $pkgdir --recursive alpine-base e2fsprogs e2fsprogs-extra util-linux
  
  apk index --description "coreos-setup-`date '+%y%m%d'` `date '+%y%m%d'`" --rewrite-arch `uname -m` -o $pkgdir/APKINDEX.tar.gz $pkgdir/*.apk

  abuild-sign $pkgdir/APKINDEX.tar.gz
}

function create_apk
{
  cd apk
  abuild checksum
  abuild -r
  
  
  apk fetch --repository /home/build/packages/tmp --stdout setup-coreos-installer | tar xvz -C /tmp/2
  
  
  
#	apk add alpine-sdk
  newapkbuild setup-coreos-installer
  
  abuild checksum
  
  
  install -Dm644 COPYING "$pkgdir"/usr/share/licenses/$pkgname/COPYING
  
  # set /etc/inittab
  # clear /etc/motd
  
  # sudo agetty -a root console 38400
  # 
}


function create_iso
{
  tmp_iso=$workdir/iso

  mkdir -p $tmp_iso
  echo "coreos-setup-`date '+%y%m%d' `date '+%y%m%d'" > $tmp_iso/.alpine-release

#  create_apk_keys
  create_rootfs $tmp_iso/boot
  create_modloop $tmp_iso/boot
  create_boot_files $tmp_iso
  create_syslinux_dir $tmp_iso/boot/syslinux

  create_apks $tmp_iso/apks
  
  xorrisofs -V "COREOS SETUP" -follow-links -J -l -R -b boot/syslinux/isolinux.bin -c boot/syslinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o /iso/coreos-setup.iso $tmp_iso/ && isohybrid /iso/coreos-setup.iso
}

create_iso
