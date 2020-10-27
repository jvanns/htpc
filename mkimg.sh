#!/usr/bin/env bash

set -u

declare -i SIZE=$1 # In GB
declare -r IMG_FILE="$2" # Filename of resulting image
declare -r SYSFILES="${3:-''}" # Optional system files to restore

# Opt for loopback devices unlikely to be used
NAME="`basename $0 | tr a-z A-Z`"
IMG_MOUNT="`mktemp -d -t mkimg.XXXX`"
LOOPDEV="`losetup -f`" # Whole 'disk'
DISK=vdx

cleanup() {
   echo "$NAME: Beginning cleanup stage..."

   grep -F "$IMG_MOUNT" /proc/mounts | awk '{print $2}' | while read mount
   do
      umount -f "$mount"
   done

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
   echo "$NAME: Generating partitioned image file..."

   rc=0

   # Create device file
   dd if=/dev/zero of="$IMG_FILE" bs=1MB count=$(($SIZE * 1000))
   [ $? -ne 0 ] && return 1

   local -i -r cylinders=$((`img_size "$IMG_FILE"` / (255 * (63 * 512))))

   losetup $LOOPDEV "$IMG_FILE"
   [ $? -ne 0 ] && return 1

   # Fake drive geometry
   fdisk -b 512 -H 255 -S 63 -C $cylinders -c -u $LOOPDEV <<EOF
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
w
EOF
   rc=$?
   losetup -d $LOOPDEV

   return $rc
}

prepare_boot_loader() {
   echo "$NAME: Preparing bootloader partition device mappings..."

   s=$((`img_size "$IMG_FILE"` / 512))

   losetup $LOOPDEV "$IMG_FILE" && \
   echo "0 $s linear `stat -c %t:%T $LOOPDEV` 0" | dmsetup create $DISK && \
   kpartx -sa /dev/mapper/$DISK && \
   ln -s -f /dev/mapper/$DISK /dev/$DISK && \
   ln -s -f /dev/mapper/${DISK}1 /dev/${DISK}1

   return 0
}

format_device() {
   echo "$NAME: Formatting device with ext4 filesystem..."

   mkfs.ext4 -F -T small -L system /dev/${DISK}1

   return $?
}

mount_device() {
   echo "$NAME: Mounting device..."

   if [ "$1" = "host" ]; then
      mkdir -m 0755 -p "$IMG_MOUNT"/{dev,sys,proc} && \
      mount -R /dev "$IMG_MOUNT/dev" && \
      mount -R /sys "$IMG_MOUNT/sys" && \
      mount -R /proc "$IMG_MOUNT/proc"
   elif [ "$1" = "root" ]; then
      mount -t ext4 /dev/${DISK}1 "$IMG_MOUNT"
   fi

   return $?
}

bootstrap_system() {
   echo "$NAME: Bootstrapping system install..."

   local -r flavour=focal

   debootstrap --no-check-certificate --arch=amd64 $flavour "$IMG_MOUNT" \
   http://archive.ubuntu.com/ubuntu

   return $?
}

install_system() {
   echo "$NAME: Post-bootsrap system install..."

   chroot "$IMG_MOUNT" /bin/bash -s <<EOF
export LC_ALL=C
export LANG=en_GB.UTF-8
export LANGUAGE=en_GB.UTF-8
export DEBIAN_FRONTEND=noninteractive
#
apt-get -y install "language-pack-${LANG%%_*}"
locale-gen "$LANG"
update-locale LANG="$LANG"
#
apt-get -y update
apt-get -y --no-install-recommends install whiptail wget debconf \
nano vim devscripts gnupg locales ubuntu-minimal grub-pc \
lvm2 pulseaudio man openssh-server openssh-client pciutils \
linux-generic initramfs-tools net-tools software-properties-common \
dkms git bc rsync wpasupplicant wireless-tools xinit xserver-xorg-legacy \
xserver-xorg xserver-xorg-video-radeon samba dbus-x11
#
groupadd -f -g 1000 media
useradd -c 'HTPC Media Account' -d /home/media \
   -g 1000 -u 1000 -M -s /bin/bash media
echo -e 'kubrick' > /etc/hostname
#
add-apt-repository -n ppa:team-xbmc/ppa
add-apt-repository -n ppa:libretro/stable
add-apt-repository -n multiverse
add-apt-repository -n universe
add-apt-repository -n main
#
echo -e 'Package: kodi*\\nPin-Priority: 500\\nPin: origin ppa.launchpad.net' > /etc/apt/preferences
apt-get -y update
apt-get -y install libvdpau-va-gl1 kodi retroarch*
#
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y autoremove
apt-get clean all
#
sed -i "s/^allowed_users=.*/allowed_users=anybody/" /etc/X11/Xwrapper.config
echo 'needs_root_rights=yes' >> /etc/X11/Xwrapper.config
usermod -a -G audio,video,games,pulse,tty media
sync
exit
EOF

   if [ -f "$SYSFILES" ]; then
      cd "$IMG_MOUNT"
      tar -xzv --owner=root --group=root -f "$SYSFILES"
   fi

   return 0
}

set_root_passwd() {
   echo "$NAME: Setting default root password..."

   chroot "$IMG_MOUNT" /usr/bin/passwd <<EOF
,BadPA55W0RD.
,BadPA55W0RD.
EOF

   return 0
}

install_boot_loader() {
   echo "$NAME: Installing grub boot loader to image..."

   rc=0
   flag=''
   grubdir="$IMG_MOUNT/boot/grub"
   uuid="`blkid -s UUID -o value /dev/${DISK}1`"
   kver="`/bin/ls -t1 ${IMG_MOUNT}/boot/vmlinuz-* | head -n1 | sed 's/.*vmlinuz-//'`"

   cat > $grubdir/load.cfg <<EOF
set root='(hd0,1)'
search.fs_uuid $uuid root
set prefix=(\$root)/boot/grub
EOF

   cat > $grubdir/device.map <<EOF
(hd0) /dev/${DISK}
EOF

   cat > $grubdir/grub.cfg <<EOF
insmod ext2
set default="0"
set timeout="3"
set root='(hd0,1)'
search --no-floppy --fs-uuid --set=root $uuid
linux /boot/vmlinuz-${kver} root=UUID=$uuid ro KEYBOARDTYPE=pc KEYTABLE=uk LANG=en_GB
initrd /boot/initrd.img-${kver}
boot
EOF

   echo "Installing grub for Linux ${kver}..."
   chroot "$IMG_MOUNT" /usr/sbin/grub-install \
      --grub-mkdevicemap=/boot/grub/device.map \
      --boot-directory=/boot \
      --root-directory=/ \
      --target=i386-pc \
      --no-floppy \
      "${LOOPDEV}"
   rc=$?

   if [ -r "${IMG_MOUNT}/etc/fstab" ]; then
      sed -i "/\t\/\t/ c\UUID=$uuid\t/\text4\terrors=remount-ro\t0\t1" "${IMG_MOUNT}/etc/fstab"
   else
      echo -e "UUID=$uuid\t/\text4\terrors=remount-ro\t0\t1" > "${IMG_MOUNT}/etc/fstab"
   fi

   rm -f "${grubdir}/device.map"

   return $rc
}

trap 'cleanup' 0

build_device
prepare_boot_loader
format_device
mount_device root
bootstrap_system
mount_device host
install_system
set_root_passwd
install_boot_loader
