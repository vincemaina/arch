#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This installer must be run as root."
    exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /dev/vdX"
    echo "Example: $0 /dev/vda"
    exit 1
fi

DISK="$1"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SOURCE="$REPO_ROOT/setup"
TARGET_SETUP="/mnt/opt/arch-setup"

echo "========================================"
echo " Arch Linux automated setup"
echo "========================================"
echo
echo "Target disk: $DISK"
echo

echo "==> [1/5] Preparing disk"
"$SETUP_SOURCE/install/01-disk.sh" "$DISK"

echo
echo "==> [2/5] Installing base Arch system"
"$SETUP_SOURCE/install/02-base.sh"

echo
echo "==> Copying setup payload into target system"
mkdir -p "$TARGET_SETUP"
cp -a "$SETUP_SOURCE/." "$TARGET_SETUP/"

echo
echo "==> [3/5] Configuring system"
arch-chroot /mnt /opt/arch-setup/install/03-system.sh

echo
echo "==> [4/5] Installing desktop"
arch-chroot /mnt /opt/arch-setup/install/04-desktop.sh

echo
echo "==> [5/5] Installing user configuration"
arch-chroot /mnt /opt/arch-setup/install/05-dotfiles.sh

echo
echo "========================================"
echo " Installation complete"
echo "========================================"
echo
echo "Unmounting filesystems..."

umount -R /mnt

echo
echo "The VM will now power off."
echo "Remove the Arch ISO before starting it again."

sleep 3
poweroff
