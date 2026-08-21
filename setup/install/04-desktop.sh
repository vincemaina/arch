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

echo "==> Marking every declared package as explicitly installed"

# `pacman -S --needed` skips a package that is already installed, and does NOT
# change its install reason while skipping it. A manifest entry that something
# in base.txt already pulled in as a dependency therefore stays marked as a
# dependency - so `pacman -Rns` on whatever pulled it in would take it, which is
# precisely what packages/README.md says listing it prevents. polkit is the
# example that file gives, and polkit was in exactly that state. TASK-13.
#
# Idempotent: a package already explicit is left alone. Only packages actually
# installed are passed, because a name satisfied by a provider under a different
# name is not installed under the declared one and `pacman -D` errors on it.
mapfile -t DECLARED_DEPS < <(
    comm -12 <(LC_ALL=C pacman -Qdq | sort) \
             <(printf '%s\n' "${DESKTOP_PACKAGES[@]}" "${DEV_PACKAGES[@]}" | sort -u)
)

if [[ ${#DECLARED_DEPS[@]} -gt 0 ]]; then
    printf '    %s\n' "${DECLARED_DEPS[@]}"
    pacman -D --asexplicit --noconfirm -- "${DECLARED_DEPS[@]}" >/dev/null
fi

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
