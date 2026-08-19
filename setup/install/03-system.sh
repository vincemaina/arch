#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/opt/arch-setup"

source "$REPO_ROOT/install.conf"

ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen

echo "LANG=$LOCALE" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

useradd -m -G wheel -s /bin/bash "$USERNAME"

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

systemctl enable NetworkManager

echo
echo "Set root password:"
passwd

echo
echo "Set password for $USERNAME:"
passwd "$USERNAME"

echo
echo "System configuration complete."




bootctl install

install -Dm644 \
  "$REPO_ROOT/system/loader/loader.conf" \
  /boot/loader/loader.conf

ROOT_DEVICE="$(findmnt -no SOURCE /)"
ROOT_DEVICE="${ROOT_DEVICE%%\[*}"

ROOT_UUID="$(blkid -s UUID -o value "$ROOT_DEVICE")"

sed \
  "s/__ROOT_UUID__/$ROOT_UUID/" \
  "$REPO_ROOT/system/loader/arch.conf" \
  > /boot/loader/entries/arch.conf

bootctl status
