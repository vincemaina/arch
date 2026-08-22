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

# Clear what a previous run left behind, TASK-132.
#
# install.sh only unmounts /mnt on the success path, at the very end. Any
# abort after this stage - a mistyped password in stage 3 was the one that
# found this, but stages 2 to 5 all qualify - therefore leaves the target
# filesystems mounted, and parted and mkfs both refuse a disk whose
# partitions are in use. The second attempt then fails immediately after
# ERASE with an error naming the disk, which reads like a bad device rather
# than the residue of the last run. Rebooting the ISO cleared it and nothing
# said so.
#
# Deliberately after the confirmation: a run stopped at that prompt must
# leave the machine exactly as it found it.
if findmnt -rno TARGET /mnt >/dev/null 2>&1; then
  echo "==> /mnt is still mounted, from a previous run; unmounting"
  umount -R /mnt
fi

# Anything still holding the disk open would produce the same confusing
# error, so say what it is here rather than letting parted report it. Matched
# on the device name, which covers both the vda1/vda2 and nvme0n1p1/p2 forms
# without needing to know which this disk uses yet.
if findmnt -rno TARGET,SOURCE | grep -q "[[:space:]]${DISK}"; then
  echo "Something on $DISK is still mounted, so it cannot be partitioned:" >&2
  findmnt -rno TARGET,SOURCE | grep "[[:space:]]${DISK}" | sed 's/^/    /' >&2
  echo >&2
  echo "Unmount it and run this again." >&2
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
