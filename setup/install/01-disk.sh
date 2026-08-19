#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /dev/vdX"
  exit 1
fi

DISK="$1"

echo "WARNING: this will ERASE everything on $DISK"
read -rp "Type ERASE to continue: " confirm

if [[ "$confirm" != "ERASE" ]]; then
  echo "Aborted."
  exit 1
fi

# Create GPT:
# 1 GiB EFI partition
# remaining space Btrfs root partition
parted -s "$DISK" \
  mklabel gpt \
  mkpart ESP fat32 1MiB 1025MiB \
  set 1 esp on \
  mkpart primary btrfs 1025MiB 100%

# Handle nvme-style partition names as well as vda/sda.
if [[ "$DISK" =~ [0-9]$ ]]; then
  EFI="${DISK}p1"
  ROOT="${DISK}p2"
else
  EFI="${DISK}1"
  ROOT="${DISK}2"
fi

mkfs.fat -F32 "$EFI"
mkfs.btrfs -f "$ROOT"

mount "$ROOT" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots

umount /mnt

mount -o subvol=@,compress=zstd "$ROOT" /mnt

mkdir -p /mnt/home
mkdir -p /mnt/.snapshots
mkdir -p /mnt/boot

mount -o subvol=@home,compress=zstd "$ROOT" /mnt/home
mount -o subvol=@snapshots,compress=zstd "$ROOT" /mnt/.snapshots
mount "$EFI" /mnt/boot

echo
echo "Disk setup complete."
findmnt -R /mnt
