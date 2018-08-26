#!/bin/bash

# otherwise fakeroot (called by "abuild rootpkg") will hang caused by accidently handled signals.
# when fakeroot receives a signal, a cleanup is executed which causes a deadlock/hang.
# In this case, the (SIG)WINCH signal (for signaling a resize / initializing of the terminal window)
# causes this behavior.
# The initial WINCH signal could be skipped by e.g. a "sleep 2", but resizing the terminal window
# after the initial resize signal can cause the same behavior / hang.
# see https://github.com/moby/moby/issues/27195
sleep 2

workdir=/tmp/workdir

rm -Rf $workdir
mkdir -p $workdir

function show_title
{
  echo "######### $1 ########################################"
}

function create_rootfs
{
  show_title "rootfs"

  outdir=$1
  tmp_initfs=$workdir/initfs
  tmp2_initfs=$workdir/initfs2

  mkdir -p $tmp_initfs $outdir


  sudo apk add --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories --initdb --update --no-script --root $tmp_initfs linux-firmware dahdi-linux linux-vanilla dahdi-linux-vanilla xtables-addons-vanilla mkinitfs #e2fsprogs-extra #alpine-base
  # linux-vanilla xtables-addons

  sudo cp -r /etc/apk/keys $tmp_initfs/etc/apk/
  
  sudo cp /sbin/init $tmp_initfs

  MODLOOP_KERNEL_RELEASE=`ls $tmp_initfs/lib/modules`

  #strip -g $tmp_initfs/bin/* $tmp_initfs/sbin/* $tmp_initfs/lib/* 2>/dev/null

  sudo mkinitfs -F "ata base bootchart cdrom squashfs ext2 ext3 ext4 mmc raid scsi usb virtio" -t $tmp2_initfs -b $tmp_initfs -o $outdir/initramfs-vanilla ${MODLOOP_KERNEL_RELEASE}
}

function create_modloop
{
  show_title "modloop"

  outdir=$1
  tmp_modloop=$workdir/modloop

  mkdir -p $tmp_modloop/tmp $outdir

  sudo apk add --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories --initdb --update --no-script --root $tmp_modloop/tmp linux-firmware dahdi-linux linux-vanilla dahdi-linux-vanilla xtables-addons-vanilla mkinitfs #alpine-base
  # linux-vanilla xtables-addons

  MODLOOP_KERNEL_RELEASE=`ls $tmp_modloop/tmp/lib/modules`
  
  mkdir -p $tmp_modloop/lib/modules/
  
  sudo mv $tmp_modloop/tmp/lib/modules/* $tmp_modloop/lib/modules/
  if [[ -d $tmp_modloop/tmp/lib/firmware ]]
  then
    for FW in `find $tmp_modloop/lib/modules -type f -name "*.ko" | xargs modinfo -F firmware | sort -u`
    do
	  if [[ -e "$tmp_modloop/tmp/lib/firmware/$FW" ]]
	  then
        sudo install -pD "$tmp_modloop/tmp/lib/firmware/$FW" "$tmp_modloop/lib/modules/firmware/$FW"
      fi
    done
  fi  
  
  sudo depmod $MODLOOP_KERNEL_RELEASE -b $tmp_modloop
  sudo mksquashfs $tmp_modloop/lib $outdir/modloop-vanilla -comp xz
}


function create_syslinux_dir
{
  show_title "syslinux"

  outdir=$1
  mkdir -p $outdir
  for f in isolinux.bin ldlinux.c32 libutil.c32 libcom32.c32 mboot.c32
  do
    cp /usr/share/syslinux/$f $outdir/
  done

  cat > $outdir/syslinux.cfg << EOF
timeout 20
prompt 1
default vanilla
label vanilla
    kernel /boot/vmlinuz-vanilla
    append initrd=/boot/initramfs-vanilla modloop=/boot/modloop-vanilla modules=loop,squashfs,sd-mod,usb-storage quiet pkgs=e2fsprogs-extra,util-linux,bash,newt,setup-coreos-installer
EOF
}

function create_boot_files
{
	show_title "boot files"

	# creates System.map-vanilla, config-vanilla and vmlinuz-vanilla in /boot

	outdir=$1
	
	mkdir -p $outdir
	
    sudo apk fetch --stdout --quiet --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories linux-vanilla | tar -C $outdir -xz boot

}


function create_apks
{
  show_title "apks"

  outdir=$1
  
  pkgdir=$outdir/`uname -m`
  mkdir -p $pkgdir
  touch $outdir/.boot_repository
 
####  sudo apk add --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories --initdb --update --no-script --root $tmp_modloop/tmp linux-firmware dahdi-linux linux-vanilla dahdi-linux-vanilla xtables-addons-vanilla mkinitfs #alpine-base
    
  sudo apk fetch --repository /home/build/packages/tmp --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories --output $pkgdir --recursive --update alpine-base e2fsprogs e2fsprogs-extra util-linux newt bash setup-coreos-installer
  
  sudo apk index --description "coreos-setup-`date '+%y%m%d'` `date '+%y%m%d'`" --rewrite-arch `uname -m` -o $pkgdir/APKINDEX.tar.gz $pkgdir/*.apk

  sudo abuild-sign $pkgdir/APKINDEX.tar.gz
}

function create_apk
{
  show_title "apk"

  cd /tmp/apk
  sudo chmod o=rwx /dev/tty*
  abuild -r checksum rootpkg index
#  setsid sh -c 'exec abuild -r checksum rootpkg index <> /dev/tty2 2>&1 > /tmp/abuild.log'
#  cat /tmp/abuild.log
  
  # clear /etc/motd
  
}


function create_iso
{
  tmp_iso=$workdir/iso

  mkdir -p $tmp_iso
  echo "coreos-setup-`date '+%y%m%d' `date '+%y%m%d'" > $tmp_iso/.alpine-release

  create_apk
  create_rootfs $tmp_iso/boot
  create_modloop $tmp_iso/boot
  create_boot_files $tmp_iso
  create_syslinux_dir $tmp_iso/boot/syslinux

  create_apks $tmp_iso/apks
  
  show_title "iso"
  xorrisofs -V "COREOS SETUP" -follow-links -J -l -R -b boot/syslinux/isolinux.bin -c boot/syslinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o /iso/coreos-setup-template.iso $tmp_iso/ && isohybrid /iso/coreos-setup-template.iso
}

create_iso
