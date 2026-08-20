#!/usr/bin/env bash
set -euo pipefail

SETUP_ROOT="/opt/arch-setup"

echo "==> Reading desktop package manifest"

mapfile -t DESKTOP_PACKAGES < <(
    grep -Ev '^[[:space:]]*(#|$)' \
        "$SETUP_ROOT/packages/desktop.txt"
)

echo "==> Reading development package manifest"

mapfile -t DEV_PACKAGES < <(
    grep -Ev '^[[:space:]]*(#|$)' \
        "$SETUP_ROOT/packages/dev.txt"
)

echo "==> Installing desktop packages"

pacman -S --needed --noconfirm "${DESKTOP_PACKAGES[@]}"

echo "==> Installing development packages"

pacman -S --needed --noconfirm "${DEV_PACKAGES[@]}"

echo
echo "==> Installing machine-wide configuration"

# Deliberately here rather than in 03-system.sh, even though this is system
# rather than desktop configuration. apply-config.sh enables units that come
# from the desktop manifest - greetd among them - and 03 runs before any of
# those packages exist, so enabling them there fails and aborts the install
# partway through. sync.sh reconciles packages before configuration for the
# same reason.
#
# No --activate: there is no running system inside the chroot to apply to.
"$SETUP_ROOT/system/apply-config.sh"

echo
echo "Desktop installation complete."
