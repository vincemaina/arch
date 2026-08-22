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

# Passwords, asked here and stored nowhere - see the foot of install.conf.
#
# A bare `passwd` under `set -e` was the whole bug in TASK-131: passwd exits
# non-zero when the two entries do not match, so one typo ended the stage,
# arch-chroot returned non-zero, and install.sh gave up - having already
# erased the disk in stage 1 and pacstrapped the base system in stage 2. The
# cheapest mistake available cost the entire install.
#
# Bounded rather than an unconditional `until`: passwd reading from a pipe or
# a closed stdin fails instantly and forever, and an install with no terminal
# would otherwise spin here rather than failing. Five attempts is generous for
# a human - passwd already retries internally before it returns at all - and
# finite for everything else. Exhausting them still fails the stage, because a
# machine whose root password was never set is not one to carry on building.
set_password() {
    local who="$1"
    local attempt

    for (( attempt = 1; attempt <= 5; attempt++ )); do
        if passwd "$who"; then
            return 0
        fi

        if (( attempt < 5 )); then
            echo
            echo "That did not take - the two entries most likely did not match."
            echo "Try again ($attempt of 5)."
        fi
    done

    echo >&2
    echo "Could not set the password for $who after 5 attempts." >&2
    return 1
}

echo
echo "Set root password:"
set_password root

echo
echo "Set password for $USERNAME:"
set_password "$USERNAME"

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
