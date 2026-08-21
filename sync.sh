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
  * applies machine-wide configuration from setup/system/
  * re-applies the dotfiles in setup/dotfiles/ using chezmoi
  * sets the login shell, once its configuration is in place and valid
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

# DECLARED IS NOT THE SAME AS EXPLICITLY INSTALLED, and until TASK-13 nothing
# noticed the difference.
#
# packages/README.md promises that listing a package which something else also
# depends on - polkit is the example it gives - stops a dependency-graph change
# removing it silently. That promise was never kept by anything. `pacman -T`
# above reports such a package as satisfied, so it is never in MISSING and
# pacman is never told it is wanted in its own right; `pacman -S --needed`
# skips an installed package without changing its install reason either. So it
# stayed marked "installed as a dependency", and `pacman -Rns` on whatever
# pulled it in would still have taken it.
#
# Four packages on this machine were in exactly that state: polkit, mesa,
# adwaita-cursors and xdg-desktop-portal-gtk.
#
# Marking them is the whole fix, and it is idempotent - a package already
# explicit is left alone, so this is a no-op on a machine that is in order.
mapfile -t DEP_MARKED < <(
    comm -12 <(LC_ALL=C pacman -Qdq 2>/dev/null | sort) \
             <(printf '%s\n' "${WANTED[@]}" | sort -u) || true
)

if [[ ${#DEP_MARKED[@]} -gt 0 ]]; then
    echo "    ${#DEP_MARKED[@]} declared but marked as dependencies:"
    printf '      %s\n' "${DEP_MARKED[@]}"
    if $DRY_RUN; then
        echo "    Would mark the above as explicitly installed"
    else
        sudo pacman -D --asexplicit -- "${DEP_MARKED[@]}" >/dev/null
        echo "    Marked as explicitly installed, so removing what pulled them in cannot take them"
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
        # chezmoi prompts when a target has been edited since it last wrote it.
        # That is useful in a terminal and fatal without one: over ssh or from a
        # script it blocks forever on a question nobody can answer. Fail loudly
        # instead, naming the file, so the run ends rather than hangs.
        if [[ -t 0 ]]; then
            chezmoi --source "$SETUP_SOURCE" apply
        elif ! chezmoi --source "$SETUP_SOURCE" apply --error-on-conflict; then
            # --error-on-conflict exits 1 and prints nothing, which under set -e
            # would end the run with no explanation at all. Say what happened.
            echo >&2
            echo "A file above was changed on this machine since chezmoi last" >&2
            echo "wrote it, and there is no terminal here to ask which version" >&2
            echo "to keep. Nothing was changed. Either:" >&2
            echo >&2
            echo "  * run sync.sh from a terminal and answer the prompt, or" >&2
            echo "  * keep the local version:  chezmoi --source $SETUP_SOURCE re-add ~/<file>, or" >&2
            echo "  * discard it:              chezmoi --source $SETUP_SOURCE apply --force ~/<file>" >&2
            exit 1
        fi
        echo "    Applied"
    fi

    # A file differs either because the repository moved on, or because it was
    # edited here. In the second case the change is one command away from being
    # kept, and otherwise it is one sync away from being lost.
    echo
    echo "    If any of those differ because you changed them on this machine:"
    for file in "${CHANGED[@]}"; do
        echo "      chezmoi --source $SETUP_SOURCE re-add ~/$file"
    done
    echo "    For changes that should stay on this machine only, use"
    echo "    ~/.config/zsh/local.zsh, which chezmoi deliberately ignores."

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
            .zshrc|.config/starship.toml)
                add_hint "shell: open a new terminal to pick up the change."
                ;;
            .config/environment.d/*)
                add_hint "environment: read when the user manager starts, so this needs a fresh login."
                ;;
        esac
    done
fi

# Tell the theme switcher where this checkout is.
#
# ~/.local/bin/theme is launched from a menu, not from inside the repository,
# and this setup always drives chezmoi with an explicit --source. Without a
# recorded path it falls back to /opt/arch-setup - the copy install.sh leaves
# behind - which works but renders from whatever the templates looked like at
# install time. Recording it here points it at the live clone instead.
#
# Deliberately outside the "something changed" branch above: the recorded path
# is wrong after the repository is moved or re-cloned, and that is exactly when
# nothing else differs.
if ! $DRY_RUN && [[ -x "$HOME/.local/bin/theme" ]]; then
    "$HOME/.local/bin/theme" --record-source "$SETUP_SOURCE"
fi

# ----------------------------------------------------------------------
# Login shell
# ----------------------------------------------------------------------
#
# After the dotfiles, deliberately. Switching the login shell before its
# configuration is in place would hand the user a shell whose rc file does not
# exist yet, and the config is checked for syntax errors before the switch so a
# broken zshrc cannot become the thing that greets them at every login.

echo
echo "==> Checking the login shell"

# id -un rather than $USER: the environment variable is not guaranteed to be
# set in every context a script might run in, and an unset one would abort.
ME="$(id -un)"
WANT_SHELL="$(command -v zsh || true)"
HAVE_SHELL="$(getent passwd "$ME" | cut -d: -f7)"

if [[ -z "$WANT_SHELL" ]]; then
    echo "    zsh is not installed, leaving $HAVE_SHELL alone"
elif [[ "$HAVE_SHELL" == "$WANT_SHELL" ]]; then
    echo "    Already $WANT_SHELL"
elif ! zsh -n "$HOME/.zshrc" 2>/dev/null; then
    echo "    NOT changing the login shell: ~/.zshrc has a syntax error" >&2
    zsh -n "$HOME/.zshrc" || true
elif $DRY_RUN; then
    echo "    Would change $HAVE_SHELL to $WANT_SHELL"
else
    sudo chsh -s "$WANT_SHELL" "$ME"
    echo "    Changed $HAVE_SHELL to $WANT_SHELL"
    add_hint "login shell: applies to new login sessions, not this terminal."
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
