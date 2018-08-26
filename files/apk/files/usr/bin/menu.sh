#!/bin/bash

function show_error
{
  whiptail --title "Error" --msgbox "$1. Choose Ok to shutdown." 10 60
  poweroff
  tail -f < /dev/null
}

function mount_oemfs
{
cdrom_dev=`blkid | grep -e 'TYPE="iso9660"' | cut -d: -f1`
[[ -z "$cdrom_dev" ]] && show_error "No CD ROM found!"

cdrom_dir=`mount | awk -v d="$cdrom_dev" 'match(\$0, "^" d " on") { print gensub(/^.* on (.*) type .*/, "\\\\1", "g", \$0) }'`

root_dev=`blkid | grep -e 'LABEL="ROOT"' | cut -d: -f1`
[[ -z "$root_dev" ]] && show_error "No CoreOS installation found!"

oem_dev=`blkid | grep -e 'LABEL="OEM"' | cut -d: -f1`
[[ -z "$oem_dev" ]] && show_error "No CoreOS installation found!"

mkdir -p /mnt/oemfs
mount $oem_dev /mnt/oemfs
}

function apply_profile
{
  oemfs_dir=/mnt/oemfs

  cp "$cdrom_dir"/profiles/$1.ign $oemfs_dir/$1.ign
  
  if [[ ! -f /mnt/oemfs/grub.cfg ]]
  then
    cat > $oemfs_dir/grub.cfg << EOF
set linux_append="coreos.config.url=oem:///$1.ign"
EOF
  elif ! grep -E '^set linux_append=".*"$' $oemfs_dir/grub.cfg > /dev/null 2>&1
  then
    show_error "Malformed grub.cfg"
  elif grep -E '[ \"]coreos\.config\.url=' $oemfs_dir/grub.cfg > /dev/null 2>&1
  then
	sed -i -re "s#([ \"]coreos\.config\.url=)([^ \"]+)#\\1oem:///$1.ign#" $oemfs_dir/grub.cfg
  else
	sed -i -re "s#\"\$# coreos.config.url=oem:///$a.ign\"#" $oemfs_dir/grub.cfg
  fi
  
  umount $oemfs_dir
  
  e2fsck -f $root_dev
  tune2fs -U 00000000-0000-0000-0000-000000000001 $root_dev
  
  umount /dev/loop0    # uses/blocks CD ROM devices
  umount $cdrom_dev
  eject -s $cdrom_dev

  if blkid | grep -e 'TYPE="iso9660"' 2>/dev/null | cut -d: -f1 | grep $cdrom_dev > /dev/null 2>&1
  then
    whiptail --title "Reboot" --msgbox "CD could not be ejected. Please eject manually. Choose Ok to shutdown." 10 60
    poweroff
  else
    whiptail --title "Reboot" --msgbox "CD has been ejected successfully. Choose Ok to reboot." 10 60    
    reboot
  fi
  tail -f < /dev/null
}

mount_oemfs

let i=0
e=()
while read -r line; do
	let i=$i+1
	e+=("$i" "$line")
done < <( ls -1 "$cdrom_dir"/profiles/*.ign | xargs -n1 -I{} basename "{}" .ign | sort )

option=$(whiptail --title "Configure CoreOS" --menu "Choose the intended purpose of this host:" 15 60 5 \
"${e[@]}" \
"S" "Exit to Shell" 3>&1 1>&2 2>&3)

[[ "$?" -eq 0 ]] || show_error "Cancelled by user"

case $option in
  
  S)
  while echo "New shell launched ..."
  do
    /bin/sh
  done
  ;;

  *)
  apply_profile ${e[2*$option-1]}
  ;;


esac

show_error "Invalid option chosen"
