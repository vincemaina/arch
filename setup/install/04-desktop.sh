#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sudo pacman -Syu --needed
sudo pacman -S --needed - < "$REPO_ROOT/packages/desktop.txt"
sudo pacman -S --needed - < "$REPO_ROOT/packages/dev.txt"
