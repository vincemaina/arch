#!/usr/bin/env bash
set -euo pipefail

SETUP_ROOT="/opt/arch-setup"

source "$SETUP_ROOT/install.conf"

USER_HOME="/home/$USERNAME"

echo "==> Applying dotfiles for $USERNAME"

runuser -u "$USERNAME" -- \
    env HOME="$USER_HOME" \
    chezmoi \
        --source "$SETUP_ROOT" \
        apply

echo
echo "Dotfiles installed."
