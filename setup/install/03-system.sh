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

echo "==> Configuring console keyboard"
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "==> Creating user"

if ! id "$USERNAME" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash "$USERNAME"
fi

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

echo "==> Enabling NetworkManager"
systemctl enable NetworkManager

echo "==> Configuring memory pressure handling"

# Compressed swap in RAM. zram-generator is a generator, not a service: it
# reads this at boot and creates the device, so there is nothing to enable.
install -Dm644 \
    "$SETUP_ROOT/system/zram-generator.conf" \
    /etc/systemd/zram-generator.conf

install -Dm644 \
    "$SETUP_ROOT/system/sysctl.d/99-zram.conf" \
    /etc/sysctl.d/99-zram.conf

# Kills a runaway process while the desktop is still responsive, rather than
# leaving the kernel to act once the machine is already thrashing.
install -Dm644 \
    "$SETUP_ROOT/system/earlyoom.conf" \
    /etc/default/earlyoom

systemctl enable earlyoom

echo
echo "Set root password:"
passwd

echo
echo "Set password for $USERNAME:"
passwd "$USERNAME"

echo
echo "==> Ensuring early CPU microcode"

# Current Arch practice loads microcode through the mkinitcpio hook, which
# bundles it into the initramfs, rather than through a separate initrd line
# in the bootloader entry. The hook is part of the default HOOKS, so this
# normally only confirms it; if that ever stops being true we would rather
# fail here than quietly produce a system with no microcode updates.
if ! grep -qE '^HOOKS=.*\bmicrocode\b' /etc/mkinitcpio.conf; then
    echo "    Adding the microcode hook after autodetect"
    sed -i -E 's/^(HOOKS=.*\bautodetect\b)/\1 microcode/' /etc/mkinitcpio.conf
fi

if ! grep -qE '^HOOKS=.*\bmicrocode\b' /etc/mkinitcpio.conf; then
    echo "Could not add the microcode hook to /etc/mkinitcpio.conf." >&2
    echo "Current HOOKS line:" >&2
    grep -E '^HOOKS=' /etc/mkinitcpio.conf >&2
    exit 1
fi

grep -E '^HOOKS=' /etc/mkinitcpio.conf | sed 's/^/    /'

echo
echo "==> Regenerating initramfs"
mkinitcpio -P

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
