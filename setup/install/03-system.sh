#!/usr/bin/env bash
set -euo pipefail

SETUP_ROOT="/opt/arch-setup"

source "$SETUP_ROOT/install.conf"

echo "==> Configuring timezone"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

echo "==> Configuring locale"
sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen

echo "LANG=$LOCALE" > /etc/locale.conf

echo "==> Configuring hostname"
echo "$HOSTNAME" > /etc/hostname

# Console keymap (KEYMAP) is deliberately not written here. It used to be, and
# only here, which was the bug TASK-115 closed: sync.sh had no path to correct
# it afterwards. system/apply-config.sh now owns /etc/vconsole.conf, so it
# reaches both a fresh install (04-desktop.sh calls it) and a running machine
# (sync.sh calls it with --activate) from one place.

echo "==> Creating user"

if ! id "$USERNAME" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash "$USERNAME"
fi

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

echo "==> Enabling NetworkManager"
systemctl enable NetworkManager

echo
echo "Set root password:"
passwd

echo
echo "Set password for $USERNAME:"
passwd "$USERNAME"

echo
echo "==> Installing systemd-boot"
bootctl install

install -Dm644 \
    "$SETUP_ROOT/system/loader/loader.conf" \
    /boot/loader/loader.conf

mkdir -p /boot/loader/entries

ROOT_DEVICE="$(findmnt -no SOURCE /)"
ROOT_DEVICE="${ROOT_DEVICE%%\[*}"

ROOT_UUID="$(blkid -s UUID -o value "$ROOT_DEVICE")"

for entry in "$SETUP_ROOT"/system/loader/entries/*.conf; do
    echo "    $(basename "$entry")"
    sed \
        "s/__ROOT_UUID__/$ROOT_UUID/" \
        "$entry" \
        > "/boot/loader/entries/$(basename "$entry")"
done

echo
echo "==> Bootloader status"
bootctl status

echo
echo "System configuration complete."
