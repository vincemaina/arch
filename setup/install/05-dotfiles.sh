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
echo "==> Setting the login shell"

# Done here rather than at useradd time in 03-system.sh, because zsh comes from
# the dev manifest and is not installed until 04. Setting it earlier would fail
# the same way enabling greetd did.
ZSH_PATH="$(command -v zsh || true)"

if [[ -z "$ZSH_PATH" ]]; then
    echo "zsh is not installed; leaving the login shell alone." >&2
elif [[ "$(getent passwd "$USERNAME" | cut -d: -f7)" == "$ZSH_PATH" ]]; then
    echo "    Already $ZSH_PATH"
elif ! zsh -n "$USER_HOME/.zshrc" 2>/dev/null; then
    # Better to leave a working bash than to hand over a shell whose config
    # errors on every login.
    echo "NOT changing the login shell: $USER_HOME/.zshrc has a syntax error." >&2
    zsh -n "$USER_HOME/.zshrc" || true
else
    chsh -s "$ZSH_PATH" "$USERNAME"
    echo "    Set to $ZSH_PATH"
fi

echo
echo "Dotfiles installed."
