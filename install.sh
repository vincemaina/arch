#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This installer must be run as root."
    exit 1
fi

usage() {
    cat <<'USAGE'
Usage: install.sh [--wizard|--no-wizard] /dev/vdX

  --no-wizard   do not ask anything: use setup/install.conf exactly as it is.
  --wizard      ask, even when stdin is not a terminal (answers can be piped).

With neither flag the wizard runs when stdin is a terminal and is skipped when
it is not, so a scripted build needs no new flag to keep working.

Example: install.sh /dev/vda
USAGE
}

DISK=""
WIZARD="auto"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --wizard) WIZARD="yes"; shift ;;
        --no-wizard) WIZARD="no"; shift ;;
        -*) usage >&2; echo "Unknown option: $1" >&2; exit 1 ;;
        *)
            if [[ -n "$DISK" ]]; then
                usage >&2
                echo "Only one disk may be given." >&2
                exit 1
            fi
            DISK="$1"
            shift
            ;;
    esac
done

if [[ -z "$DISK" ]]; then
    usage >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SOURCE="$REPO_ROOT/setup"
TARGET_SETUP="/mnt/opt/arch-setup"

echo "========================================"
echo " Arch Linux automated setup"
echo "========================================"
echo
echo "Target disk: $DISK"
echo

# The wizard runs before 01-disk.sh, because it is the last point at which an
# answer can still be changed: everything after this erases the disk. It only
# rewrites setup/install.conf, which is then copied into the target system with
# the rest of setup/, so every later stage - and dot_gitconfig.tmpl - reads the
# answers the same way it always did.
#
# Skipping it leaves the committed setup/install.conf untouched, which is the
# whole non-interactive path: --no-wizard, or simply having no terminal on
# stdin, and nothing about the install changes.
if [[ "$WIZARD" == "auto" ]]; then
    if [[ -t 0 ]]; then
        WIZARD="yes"
    else
        WIZARD="no"
        SKIP_REASON="stdin is not a terminal"
    fi
fi

if [[ "$WIZARD" == "yes" ]]; then
    echo "==> [0/5] Machine identity"
    "$SETUP_SOURCE/install/00-wizard.sh" "$SETUP_SOURCE/install.conf"
else
    echo "==> [0/5] Wizard skipped (${SKIP_REASON:---no-wizard}); using install.conf as it is."
fi

echo
echo "==> Machine identity for this build"
sed -n 's/^\([A-Z_]*\)="\(.*\)"[[:space:]]*$/    \1 = \2/p' \
    "$SETUP_SOURCE/install.conf"

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
