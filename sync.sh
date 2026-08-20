#!/usr/bin/env bash
set -euo pipefail

# Applies this repository to a machine that is already running it.
#
# install.sh builds a machine from the Arch live ISO and is destructive.
# sync.sh is its counterpart for a machine that already exists: it installs
# declared packages that are missing and re-applies the dotfiles.
#
# It deliberately does not partition disks, install a bootloader or create
# users. Those steps belong to a fresh install and are not repeatable.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SOURCE="$REPO_ROOT/setup"

DRY_RUN=false

usage() {
    cat <<'USAGE'
Usage: ./sync.sh [--dry-run]

Applies this repository to the machine it is run on:

  * installs any package listed in setup/packages/ that is missing
  * re-applies the dotfiles in setup/dotfiles/ using chezmoi
  * reports what changed and what must restart for it to take effect

Options:
  -n, --dry-run   Show what would change, change nothing
  -h, --help      Show this message

Never partitions disks, installs a bootloader or creates users.
Use install.sh from the Arch live ISO to build a machine from scratch.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=true ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            echo >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

if [[ $EUID -eq 0 ]]; then
    echo "Run sync.sh as your normal user, not as root." >&2
    echo "Dotfiles belong to your user; sudo is used only to install packages." >&2
    exit 1
fi

for cmd in pacman chezmoi; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Required command not found: $cmd" >&2
        echo "sync.sh runs on an installed system, not the live ISO." >&2
        exit 1
    fi
done

echo "========================================"
echo " Syncing this machine with the repo"
echo "========================================"
echo
echo "Repository: $REPO_ROOT"
if $DRY_RUN; then
    echo "Mode:       dry run, nothing will be changed"
fi
echo

PACKAGES_INSTALLED=false
HINTS=()

add_hint() {
    local hint="$1"
    local existing
    for existing in ${HINTS+"${HINTS[@]}"}; do
        [[ "$existing" == "$hint" ]] && return 0
    done
    HINTS+=("$hint")
}

# ----------------------------------------------------------------------
# Packages
# ----------------------------------------------------------------------

echo "==> Reconciling packages"

mapfile -t WANTED < <(
    grep -hEv '^[[:space:]]*(#|$)' "$SETUP_SOURCE"/packages/*.txt | sort -u
)

if [[ ${#WANTED[@]} -eq 0 ]]; then
    echo "No packages declared in $SETUP_SOURCE/packages/" >&2
    exit 1
fi

echo "    ${#WANTED[@]} packages declared"

# pacman -T prints only what is not already satisfied, and understands
# packages provided under another name rather than installed directly.
mapfile -t MISSING < <(pacman -T -- "${WANTED[@]}" || true)

if [[ ${#MISSING[@]} -eq 0 ]]; then
    echo "    Nothing missing"
else
    echo "    ${#MISSING[@]} missing:"
    printf '      %s\n' "${MISSING[@]}"

    if $DRY_RUN; then
        echo "    Would install the above"
    else
        echo
        sudo pacman -S --needed "${MISSING[@]}"
        PACKAGES_INSTALLED=true
        add_hint "Newly installed packages may need a fresh login before the session picks them up."
    fi
fi

# ----------------------------------------------------------------------
# Machine-wide configuration
# ----------------------------------------------------------------------

echo
echo "==> Applying machine-wide configuration"

# The same script the installer runs, so a change under setup/system/ reaches
# a running machine instead of only ever arriving on a freshly installed one.
# --activate makes it take effect now rather than at the next boot.
if $DRY_RUN; then
    echo "    Would run system/apply-config.sh --activate as root"
else
    sudo "$SETUP_SOURCE/system/apply-config.sh" --activate
fi

# ----------------------------------------------------------------------
# Dotfiles
# ----------------------------------------------------------------------

echo
echo "==> Applying dotfiles"

# --source points at setup/ rather than setup/dotfiles/ because
# setup/.chezmoiroot redirects chezmoi to the dotfiles directory itself.
mapfile -t CHANGED < <(
    chezmoi --source "$SETUP_SOURCE" status | sed 's/^..[[:space:]]*//'
)

if [[ ${#CHANGED[@]} -eq 0 ]]; then
    echo "    Already up to date"
else
    echo "    ${#CHANGED[@]} file(s) differ:"
    printf '      %s\n' "${CHANGED[@]}"

    if $DRY_RUN; then
        echo
        chezmoi --source "$SETUP_SOURCE" diff
    else
        chezmoi --source "$SETUP_SOURCE" apply
        echo "    Applied"
    fi

    for file in "${CHANGED[@]}"; do
        case "$file" in
            .config/sway/*)
                add_hint "sway: reload the config with \$mod+Shift+c, or run 'swaymsg reload'."
                ;;
            .config/waybar/*)
                add_hint "waybar: restart it to pick up the change."
                ;;
            .config/mako/*)
                add_hint "mako: run 'makoctl reload'."
                ;;
            .config/foot/*)
                add_hint "foot: new terminals use the new config; existing windows keep the old one."
                ;;
            .bashrc|.bash_profile|.profile|.config/environment.d/*)
                add_hint "shell: open a new terminal, or log in again for environment changes."
                ;;
        esac
    done
fi

# ----------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------

echo
echo "========================================"
if $DRY_RUN; then
    echo " Dry run complete, nothing changed"
elif [[ ${#MISSING[@]} -eq 0 && ${#CHANGED[@]} -eq 0 ]]; then
    echo " Already in sync"
else
    echo " Sync complete"
fi
echo "========================================"

if ! $DRY_RUN && [[ ${#HINTS[@]} -gt 0 ]]; then
    echo
    echo "To take effect:"
    printf '  * %s\n' "${HINTS[@]}"
fi

if $PACKAGES_INSTALLED; then
    echo
    echo "Note: packages were installed but none were removed."
    echo "Anything installed by hand and not declared in setup/packages/ is left alone."
fi
