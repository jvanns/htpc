#!/usr/bin/env bash

set -eu

declare -i SIZE=$1 # In GB
declare -r IMG_FILE="$2" # Filename of resulting image
declare -r KV="$3" # Target 'guest' kernel version

# Opt for loopback devices unlikely to be used
NAME="`basename $0 | tr a-z A-Z`"
IMG_MOUNT="`mktemp -d -t mkimg.XXXX`"
LOOPDEV="`losetup -f`" # Whole 'disk'
DISK=vdx

cleanup() {
   clear
   echo "$NAME: Beginning cleanup stage..."

   grep -F "$IMG_MOUNT/dev/pts" /proc/mounts && \
   umount -f "$IMG_MOUNT/dev/pts"

   grep -F "$IMG_MOUNT/proc" /proc/mounts && \
   umount -f "$IMG_MOUNT/proc"
  
   grep -F "$IMG_MOUNT/dev" /proc/mounts && \
   umount -f "$IMG_MOUNT/dev"
   
   grep -F "$IMG_MOUNT/sys" /proc/mounts && \
   umount -f "$IMG_MOUNT/sys"

   grep -F "$IMG_MOUNT" /proc/mounts && \
   umount -f "$IMG_MOUNT"

   if [ -e /dev/mapper/$DISK ]
   then
      kpartx -d /dev/mapper/$DISK && dmsetup remove $DISK
   fi

   [ -L /dev/$DISK ] && rm -f /dev/$DISK
   [ -L /dev/${DISK}1 ] && rm -f /dev/${DISK}1

   losetup -d "$LOOPDEV"

   rmdir "$IMG_MOUNT"
}

img_size() {
   stat -c %s "$1"
}

build_device() {
   clear
   echo "$NAME: Generating partitioned image file..."

   rc=0

   # Create device file
   dd if=/dev/zero of="$IMG_FILE" bs=1MB count=$(($SIZE * 1000))
   [ $? -ne 0 ] && return 1

   local -i -r cylinders=$((`img_size "$IMG_FILE"` / (255 * (63 * 512))))

   losetup $LOOPDEV "$IMG_FILE"
   [ $? -ne 0 ] && return 1

   # Fake drive geometry
   fdisk -b 512 -H 255 -S 63 -C $cylinders -cu $LOOPDEV << EOF
d
x
i
0xDEADBEEF
r
n
p
1


t
83
a
1
w
EOF
   rc=$?
   losetup -d $LOOPDEV

   return 0
}

prepare_boot_loader() {
   clear
   echo "$NAME: Preparing bootloader partition device mappings..."

   s=$((`img_size "$IMG_FILE"` / 512))

   losetup $LOOPDEV "$IMG_FILE" && \
   echo "0 $s linear `stat -c %t:%T $LOOPDEV` 0" | dmsetup create $DISK && \
   kpartx -a /dev/mapper/$DISK && \
   ln -s -f /dev/mapper/$DISK /dev/$DISK && \
   ln -s -f /dev/mapper/${DISK}1 /dev/${DISK}1

   return 0
}

format_device() {
   clear
   echo "$NAME: Formatting device with ext4 filesystem..."

   mkfs.ext4 -F -T small -L system /dev/${DISK}1

   return $?
}

mount_device() {
   clear
   echo "$NAME: Mounting device..."

   mount -t ext4 /dev/${DISK}1 "$IMG_MOUNT" && \
   mkdir -m 0755 -p "$IMG_MOUNT"/{etc,dev,sys,proc,dev/pts} && \
   mount -o bind /dev "$IMG_MOUNT/dev" && \
   mount -o bind /sys "$IMG_MOUNT/sys" && \
   mount -o bind /proc "$IMG_MOUNT/proc" && \
   mount -o bind /dev/pts "$IMG_MOUNT/dev/pts"

   return $?
}

bootstrap_system() {
   clear
   echo "$NAME: Bootstrapping system install..."

   local -r flavour=precise

   debootstrap --variant buildd --arch=amd64 $flavour "$IMG_MOUNT" \
   http://archive.ubuntu.com/ubuntu

   return $?
}

install_system() {
   clear 
   echo "$NAME: Post-bootsrap system install..."

   cp -f /etc/mtab "$IMG_MOUNT/etc" && \

   chroot "$IMG_MOUNT" /bin/bash -s <<EOF
apt-get -y update && \
apt-get -y --no-install-recommends install whiptail wget debconf \
linux nano vim devscripts gnupg locales ubuntu-minimal grub-pc \
lvm2 pulseaudio man openssh-server openssh-client
echo -e 'auto eth0\niface eth0 inet dhcp' >> /etc/network/interfaces
echo -e 'kubrick' > /etc/hostname
sync
exit
EOF

   return 0
}

set_root_passwd() {
   clear
   echo "$NAME: Setting default root password..."

   chroot "$IMG_MOUNT" /usr/bin/passwd <<EOF
,BadPA55W0RD.
,BadPA55W0RD.
EOF

   return 0
}

install_boot_loader() {
   clear 
   echo "$NAME: Installing grub boot loader to image..."

   rc=0
   flag=''
   grubdir="$IMG_MOUNT/boot/grub"
   uuid="`blkid -s UUID -o value /dev/${DISK}1`"

   cat > $grubdir/load.cfg <<EOF
set root='(hd0,1)'
search.fs_uuid $uuid root
set prefix=(\$root)/boot/grub
EOF

   cat > $grubdir/grub.cfg <<EOF
insmod ext2
set default="0"
set timeout="3"
set root='(hd0,1)'
search --no-floppy --fs-uuid --set=root $uuid
linux /boot/vmlinuz-${KV} root=UUID=$uuid ro KEYBOARDTYPE=pc KEYTABLE=uk LANG=en_GB
initrd /boot/initrd.img-${KV}
boot
EOF
   
   if [ ! -d /usr/lib/grub/i386-pc/ ]
   then
      mkdir -p /usr/lib/grub/i386-pc/
      cp -f "$IMG_MOUNT"/usr/lib/grub/i386-pc/* /usr/lib/grub/i386-pc/
      flag='hack'
   fi

   export LD_LIBRARY_PATH="$IMG_MOUNT/lib"

   "$IMG_MOUNT"/usr/sbin/grub-install \
   --grub-setup="$IMG_MOUNT"/usr/sbin/grub-setup \
   --grub-probe="$IMG_MOUNT"/usr/sbin/grub-probe \
   --grub-mkimage="$IMG_MOUNT"/usr/bin/grub-mkimage \
   --grub-mkrelpath="$IMG_MOUNT"/usr/bin/grub-mkrelpath \
   --grub-mkdevicemap="$IMG_MOUNT"/usr/sbin/grub-mkdevicemap \
   --no-floppy --root-directory="$IMG_MOUNT" --boot-directory=${grubdir%grub} \
   /dev/${DISK}

   rc=$?

   if [ "$flag" = "hack" ]
   then
      rm -fr /usr/lib/grub/i386-pc/
   fi

   unset LD_LIBRARY_PATH

   return 0
}

trap 'cleanup' 0

build_device && \
prepare_boot_loader && \
format_device && \
mount_device && \
bootstrap_system && \
install_system && \
set_root_passwd && \
install_boot_loader

