#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! mountpoint -q /mnt; then
  echo "/mnt is not mounted."
  echo "Run install/01-disk.sh first."
  exit 1
fi

mapfile -t BASE_PACKAGES < "$REPO_ROOT/packages/base.txt"

pacstrap -K /mnt "${BASE_PACKAGES[@]}"

genfstab -U /mnt > /mnt/etc/fstab

echo
echo "Base installation complete."
echo
cat /mnt/etc/fstab
