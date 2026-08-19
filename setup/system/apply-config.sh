#!/usr/bin/env bash
set -euo pipefail

# Installs machine-wide configuration from this repository.
#
# Called by install/03-system.sh during a fresh install, and by sync.sh on a
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
)

for mapping in "${CONFIG_FILES[@]}"; do
    src="${mapping%%:*}"
    dest="${mapping#*:}"
    echo "    $dest"
    install -Dm644 "$SYSTEM_ROOT/$src" "$dest"
done

# Enabling works inside the installer chroot; starting does not, because there
# is no running system there to start anything on.
systemctl enable earlyoom

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

# zram is created by a generator, so the device only appears after the
# generators are re-run. A resize of an in-use device is refused, which is
# correct: it holds swapped-out pages.
if swapon --show=NAME --noheadings | grep -q zram; then
    echo "    zram is already active; a size change needs a reboot"
elif ! systemctl start systemd-zram-setup@zram0.service; then
    echo "    WARNING: could not start zram; it will be created at next boot" >&2
fi
