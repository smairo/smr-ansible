#!/bin/bash
loadkeys fi

# Wlan
iwctl
station list
station wlan0 get-networks
station wlan0 connect SSID_NAME

# Disk
lsblk
fdisk /dev/nvme*
#echo $drive_val
#fdisk -l /dev/$drive_val

cryptsetup -y -v --type luks2 luksFormat /dev/$drive_valp2
cryptsetup luksOpen /dev/$drive_valp2 cryptlvm

pvcreate /dev/mapper/cryptlvm
vgcreate vg /dev/mapper/cryptlvm
lvcreate -n lvswap -L 64G vg
lvcreate -n lvroot -l 100%FREE vg

mkfs.fat -F 32 /dev/nvme0*
mkswap /dev/vg/lvswap
mkfs.xfs /dev/vg/lvroot

swapon /dev/vg/lvswap
mount /dev/vg/lvroot /mnt
mkdir -p /mnt/boot
mount /dev/$drive_valp1 /mnt/boot

# Minimal
pacstrap -K /mnt base linux linux-firmware amd-ucode intel-ucode \
    git nano sudo networkmanager nvidia-open wget

genfstab /mnt > /mnt/etc/fstab
arch-chroot /mnt
