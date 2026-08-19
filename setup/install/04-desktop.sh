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
echo "Desktop installation complete."
