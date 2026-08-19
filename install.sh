#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /dev/vdX"
    exit 1
fi

DISK="$1"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$REPO_ROOT/setup"

echo "==> Setting up disk"
"$SETUP_DIR/install/01-disk.sh" "$DISK"

echo "==> Installing base Arch system"
"$SETUP_DIR/install/02-base.sh"

echo "==> Copying Arch setup into installed system"
mkdir -p /mnt/root/arch-setup
cp -a "$SETUP_DIR/." /mnt/root/arch-setup/

echo "==> Configuring installed system"
arch-chroot /mnt /root/arch-setup/install/03-system.sh

echo
echo "==> Base Arch installation complete"
