#!/usr/bin/env bash
set -euo pipefail

# Installs machine-wide configuration from this repository.
#
# Called by install/04-desktop.sh during a fresh install, and by sync.sh on a
# machine that already exists. Defining the destinations once is the point: a
# change here has to reach both paths, or the two drift and a setting that
# works on a new machine never arrives on the running one.
#
# Everything here must be safe to run repeatedly on a live system.
#
# Bootloader configuration is deliberately absent. Boot entries are rendered
# from templates with the root UUID substituted, which is install-time work,
# and rewriting them on a running machine is a good way to make it unbootable.
#
# Must run as root.

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ACTIVATE=false
[[ "${1:-}" == "--activate" ]] && ACTIVATE=true

if [[ $EUID -ne 0 ]]; then
    echo "apply-config.sh must run as root." >&2
    exit 1
fi

# repository file : destination
CONFIG_FILES=(
    "zram-generator.conf:/etc/systemd/zram-generator.conf"
    "sysctl.d/99-zram.conf:/etc/sysctl.d/99-zram.conf"
    "earlyoom.conf:/etc/default/earlyoom"
    "greetd/config.toml:/etc/greetd/config.toml"
    "greetd/regreet.toml:/etc/greetd/regreet.toml"
    # Local session entries. /usr/local/share is the directory the desktop
    # entry spec reserves for these, and it takes precedence over /usr/share,
    # which is what lets sway.desktop hide the packaged entry rather than
    # replace a file pacman owns.
    "wayland-sessions/sway-uwsm.desktop:/usr/local/share/wayland-sessions/sway-uwsm.desktop"
    "wayland-sessions/sway.desktop:/usr/local/share/wayland-sessions/sway.desktop"
)

for mapping in "${CONFIG_FILES[@]}"; do
    src="${mapping%%:*}"
    dest="${mapping#*:}"
    echo "    $dest"
    install -Dm644 "$SYSTEM_ROOT/$src" "$dest"
done

# Enabling works inside the installer chroot; starting does not, because there
# is no running system there to start anything on.
#
# A unit only exists once its package is installed, so this must run after the
# manifests have been applied. Checking first turns an ordering mistake into a
# clear message rather than an install that aborts partway through with
# "Unit greetd.service does not exist".
#
# greetd owns VT 1 and replaces the getty there. The other VTs keep theirs, so
# Ctrl+Alt+F2 remains the way to reach a plain shell if the session will not
# start.
ENABLE_UNITS=(earlyoom greetd)

for unit in "${ENABLE_UNITS[@]}"; do
    # Checked by file rather than with systemctl, because this also runs inside
    # the installer chroot where there is no manager to ask.
    if [[ ! -e "/usr/lib/systemd/system/$unit.service" \
       && ! -e "/etc/systemd/system/$unit.service" ]]; then
        echo "Cannot enable $unit: no unit file for it exists." >&2
        echo "Its package is not installed yet, so this ran too early." >&2
        exit 1
    fi
    systemctl enable "$unit"
done

# ----------------------------------------------------------------------
# initramfs
# ----------------------------------------------------------------------
#
# Lives here rather than in the installer so a change reaches a machine that
# already exists. Regenerating takes a while, so it only happens when something
# actually changed or an expected image is missing.

REGENERATE=false

# Microcode is loaded through the mkinitcpio hook, which bundles it into the
# initramfs, rather than through a separate initrd line in the boot entry. The
# hook is part of the default HOOKS, so this usually only confirms it.
if ! grep -qE '^HOOKS=.*\bmicrocode\b' /etc/mkinitcpio.conf; then
    echo "    Adding the microcode hook after autodetect"
    sed -i -E 's/^(HOOKS=.*\bautodetect\b)/\1 microcode/' /etc/mkinitcpio.conf
    REGENERATE=true
fi

if ! grep -qE '^HOOKS=.*\bmicrocode\b' /etc/mkinitcpio.conf; then
    echo "Could not add the microcode hook to /etc/mkinitcpio.conf." >&2
    grep -E '^HOOKS=' /etc/mkinitcpio.conf >&2
    exit 1
fi

# mkinitcpio v40 stopped building the fallback image by default, shipping
# PRESETS=('default') where it used to include 'fallback'. The bootloader
# offers a fallback entry, and an entry pointing at an image that does not
# exist is worse than no entry at all: it looks like a recovery path right up
# until the moment it is needed.
for preset in /etc/mkinitcpio.d/*.preset; do
    [[ -e "$preset" ]] || continue
    if grep -qE "^PRESETS=\\('default'\\)" "$preset"; then
        echo "    Enabling the fallback image in $(basename "$preset")"
        sed -i -E "s/^PRESETS=\\('default'\\)/PRESETS=('default' 'fallback')/" "$preset"
        REGENERATE=true
    fi
done

# Catches the case where the preset is already correct but the image was never
# built, which is the state a machine installed before this fix is left in.
for img in /boot/initramfs-linux.img /boot/initramfs-linux-fallback.img; do
    if [[ ! -s "$img" ]]; then
        echo "    $img is missing"
        REGENERATE=true
    fi
done

if $REGENERATE; then
    echo "    Regenerating initramfs"
    mkinitcpio -P
else
    echo "    initramfs images are present and configuration is unchanged"
fi

# NetworkManager-wait-online holds network-online.target until a connection is
# up. Nothing on this system orders after that target, so the wait buys nothing
# and can stall boot for many seconds on wireless or a slow DHCP lease.
if [[ -e /usr/lib/systemd/system/NetworkManager-wait-online.service ]]; then
    systemctl disable NetworkManager-wait-online.service
fi

if ! $ACTIVATE; then
    exit 0
fi

# --activate is for the sync path, where the machine is running and the point
# is for the change to take effect now rather than at the next boot. Failures
# are reported rather than fatal: the configuration is already written, and a
# service that will not restart should not fail the whole sync.

echo
echo "    Applying to the running system"

if ! sysctl --system >/dev/null; then
    echo "    WARNING: sysctl --system failed; settings apply at next boot" >&2
fi

systemctl daemon-reload

if ! systemctl restart earlyoom; then
    echo "    WARNING: could not restart earlyoom" >&2
fi

# Deliberately not restarted: greetd owns the active session, and restarting it
# would kill the desktop of whoever is running this.
if systemctl is-active --quiet greetd; then
    echo "    greetd is running; login screen changes apply at next boot"
fi

# zram is created by a generator, so the device only appears after the
# generators are re-run. A resize of an in-use device is refused, which is
# correct: it holds swapped-out pages.
if swapon --show=NAME --noheadings | grep -q zram; then
    echo "    zram is already active; a size change needs a reboot"
elif ! systemctl start systemd-zram-setup@zram0.service; then
    echo "    WARNING: could not start zram; it will be created at next boot" >&2
fi
