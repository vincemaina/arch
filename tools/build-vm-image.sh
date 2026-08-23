#!/usr/bin/env bash
set -euo pipefail

# Build the base image ~/.local/bin/vm clones every machine from - the same
# Arch desktop this repository installs, built by the repository's own
# installer, with no ISO and no wizard. See TASK-69.2.
#
# WHY NOT `install.sh` DIRECTLY
#
# The task this grew from assumed install.sh could simply be pointed at an
# nbd-attached qcow2 - it accepts any block device, and 01-disk.sh already
# handles nbd-shaped partition names. That is true and turned out not to be
# enough: install.sh is written for a live ISO, and running it against THIS
# machine directly has two real hazards, both confirmed by reading the scripts
# rather than assumed.
#
#   1. install.sh ends with `poweroff`. Correct on a live ISO. Fatal here.
#
#   2. Stage 3 runs `bootctl install` inside `arch-chroot`. In its default
#      mode (no -N, no -S - confirmed by reading /usr/bin/arch-chroot),
#      arch-chroot mounts a FRESH sysfs inside the target - not a bind of the
#      host's, a live kernel-populated one - and then conditionally mounts a
#      REAL efivarfs on top of $target/sys/firmware/efi/efivars if that
#      directory exists. It does, on any UEFI-booted host. Unmitigated,
#      bootctl would write real NVRAM boot entries onto whatever machine runs
#      this script - not the qcow2's firmware, the host's.
#
# So this script drives the five numbered install/ stages directly, exactly as
# install.sh itself does, rather than calling install.sh. Every stage script
# is used completely unmodified - see "THE EFIVARS GUARD" below for how stage
# 3's one genuine hazard is neutralised without touching it.
#
# WHY PASSWORDS ARE STILL INTERACTIVE
#
# Stage 3 prompts for a root password and a user password via a real `passwd`,
# same as any other install. That stays exactly as interactive as it has
# always been - this script does not read a password from anywhere, and
# nothing pipes one in. Run this yourself, in your own terminal, and type them
# when asked. See TASK-69.2 and DECISIONS.md for why that stance is
# deliberate.
#
# requires: qemu-img qemu-nbd modprobe udevadm partprobe unshare arch-chroot mountpoint umount chmod mkdir cp readlink dirname basename sed seq cat
#
# Transitively, through the unmodified stage scripts this drives: parted,
# dosfstools (mkfs.fat), btrfs-progs (mkfs.btrfs), arch-install-scripts
# (pacstrap, genfstab, arch-chroot). None of that belongs in setup/packages/ -
# this script and everything it needs is repository build tooling, installed
# by hand once, exactly like backlog. It never reaches the built machine.

die() { echo "build-vm-image: $*" >&2; exit 1; }
msg() { echo "==> $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ $EUID -eq 0 ]] || die "must run as root (it partitions a device, pacstraps and chroots)"

usage() {
    cat <<USAGE
Usage: $0 [--output PATH] [--size SIZE] [--device /dev/nbdN] [--force]

  --output PATH    where the base image goes (default: ~/.local/share/vm/base.qcow2)
  --size SIZE      virtual size for a NEW image (default: 20G; ignored if PATH exists)
  --device DEV     use this nbd device instead of picking a free one
  --force          overwrite an existing image at PATH

Builds the base image ~/.local/bin/vm clones machines from: this repository's
own installer, run against a fresh qcow2 attached over nbd. No ISO, no wizard -
machine identity comes from the repository's own setup/install.conf, exactly
as it would for a fresh install with --no-wizard.

You will be asked for a root password and a user password partway through, by
the real installer's own prompts. That is not this script asking - it is
exactly the same passwd call a fresh install makes, and it is deliberately not
automatable. Run this somewhere you can sit and type them.
USAGE
}

# ----------------------------------------------------------------------
# Isolation: every mount this script makes lives in a private namespace
# ----------------------------------------------------------------------
#
# So that a crash, a kill -9, or Ctrl-C at the wrong moment does not leave
# /mnt/boot or an arch-chroot mount stuck on the REAL machine's mount table,
# needing a human to notice and clean up by hand. The kernel tears down every
# mount in a namespace automatically once the last process using it exits -
# a much stronger guarantee than a trap, which a SIGKILL skips entirely.
#
# This does NOT isolate the nbd device connection itself - that is a block
# device attachment, not a mount, and outlives any namespace. It gets its own
# explicit disconnect below.
#
# The re-exec is guarded by an environment sentinel rather than checking
# `readlink /proc/self/ns/mnt` against init's, because that comparison itself
# needs root and is more moving parts than a flag this script controls fully.
if [[ "${_VM_BUILDER_UNSHARED:-}" != 1 ]]; then
    exec env _VM_BUILDER_UNSHARED=1 \
        unshare --mount --propagation private -- "$0" "$@"
fi

OUTPUT="${XDG_DATA_HOME:-$HOME/.local/share}/vm/base.qcow2"
SIZE="20G"
DEVICE=""
FORCE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) OUTPUT="$2"; shift 2 ;;
        --size)   SIZE="$2"; shift 2 ;;
        --device) DEVICE="$2"; shift 2 ;;
        --force)  FORCE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "unknown argument '$1'" ;;
    esac
done

# mkdir -p first, not just readlink -f: GNU readlink -f only tolerates ONE
# missing trailing path component. On the very first run on a genuinely fresh
# account - before anything has created ~/.local/share at all - the default
# --output has TWO missing levels (share/ and vm/), readlink -f fails silently
# empty, and the naive concatenation below would have quietly resolved to
# /base.qcow2 at the filesystem root. Creating the directory first sidesteps
# the whole question, the same way ~/.local/bin/vm's own ensure_store() does.
mkdir -p "$(dirname "$OUTPUT")"
OUTPUT="$(readlink -f "$(dirname "$OUTPUT")")/$(basename "$OUTPUT")"

# Refuses a target inside the repository outright, so "never commit an image"
# holds structurally rather than by remembering to .gitignore it. The default
# target is already outside the repo; this only fires if --output was pointed
# somewhere it should not be.
case "$OUTPUT" in
    "$REPO_ROOT"/*) die "--output $OUTPUT is inside the repository. Base images are never committed - see checks/session.sh's image ban and CLAUDE.md's theming section for why." ;;
esac

if [[ -e "$OUTPUT" && $FORCE -ne 1 ]]; then
    die "$OUTPUT already exists. Pass --force to rebuild it, or --output for a different path."
fi

# Overwriting the base in place while machines are still cloned from it is the
# exact hazard ~/.local/bin/vm's own header warns about, just reached by
# replacement rather than a direct write: every overlay names this path as its
# backing file, and a new base at the same path invalidates all of them at
# once. Checked by asking qemu-img what each machine's disk actually points
# at, not by assuming the naming convention.
if [[ -e "$OUTPUT" && $FORCE -eq 1 ]]; then
    STORE="$(dirname "$OUTPUT")"
    dependents=()
    if [[ -d "$STORE" ]]; then
        for disk in "$STORE"/*/disk.qcow2; do
            [[ -f "$disk" ]] || continue
            backing="$(qemu-img info --output=json "$disk" 2>/dev/null |
                sed -n 's/.*"backing-filename": *"\([^"]*\)".*/\1/p' | head -1)"
            [[ "$backing" == "$OUTPUT" ]] && dependents+=("$(basename "$(dirname "$disk")")")
        done
    fi
    if [[ ${#dependents[@]} -gt 0 ]]; then
        die "refusing to rebuild $OUTPUT: ${dependents[*]} still clone from it. 'vm rm' them first, or --output a different path and repoint later."
    fi
fi

# ----------------------------------------------------------------------
# Attach a scratch qcow2 over nbd
# ----------------------------------------------------------------------

modprobe nbd max_part=16 2>/dev/null || true

# Defense in depth: even though this script always chooses DEVICE itself
# (auto-picked, or an explicit --device the operator typed), every destructive
# call is guarded again right here. A device path is exactly the kind of value
# a future edit could get wrong in one call site and not another; asserting it
# at the point of use costs nothing and catches that.
assert_nbd() {
    [[ "$1" =~ ^/dev/nbd[0-9]+$ ]] ||
        die "refusing to operate on '$1': not an /dev/nbdN device. This script only ever touches nbd-attached scratch images, never a real disk."
}

# Picking a free device and connecting to it are the SAME step, not two,
# because sysfs cannot tell you which nbd devices are free.
# /sys/class/block/nbdN/size and /sys/block/nbdN/pid both stay at their LAST
# value after a clean `qemu-nbd --disconnect` - confirmed on this machine: a
# device disconnected and verified un-servable by direct I/O (input/output
# error) still reports its old 8G size and its old, now-dead pid, indefinitely.
# Checking either before connecting would eventually mark every device on the
# host "busy forever" after its first use.
#
# The only signal that is actually true for BUSY is whether `qemu-nbd
# --connect` itself succeeds: confirmed separately, in one continuous
# privileged session, that it exits 0 against a free device and exits 1 with
# "Failed to set NBD socket" against a genuinely busy one.
#
# A successful connect is still not the whole story. A device can accept a
# connect and then refuse to serve any I/O at all - confirmed directly on this
# machine: nbd0, after several manual connects and disconnects earlier in this
# same session, kept accepting `--connect` (exit 0) while every single read
# against it failed with "Input/output error", consistently, not
# intermittently - a device left wedged by an earlier connection that did not
# tear down cleanly, not a timing race (five retries with pauses between them
# all failed identically). A neighbouring device (nbd2), asked for under the
# exact same wrapping, worked on the first try - so this is a property of the
# specific device, not of the general mechanism.
#
# So a candidate is only accepted once BOTH have been proven: connect succeeds
# and a real read succeeds. A device that fails the read is disconnected again
# and skipped, exactly like one that failed to connect in the first place -
# from the outside these are indistinguishable "this one doesn't work" cases,
# and treating them differently would mean the auto-picker dying on the first
# wedged device instead of trying the next one.
device_serves_io() {
    dd if="$1" bs=512 count=1 of=/dev/null 2>/dev/null
}

connect_free_device() {
    local n dev
    for n in $(seq 0 15); do
        dev="/dev/nbd$n"
        [[ -e "$dev" ]] || continue
        assert_nbd "$dev"
        if qemu-nbd --connect="$dev" --format=qcow2 "$OUTPUT" 2>/dev/null; then
            partprobe "$dev" 2>/dev/null || true
            udevadm settle
            if device_serves_io "$dev"; then
                printf '%s' "$dev"
                return 0
            fi
            qemu-nbd --disconnect "$dev" >/dev/null 2>&1 || true
        fi
    done
    return 1
}

msg "Building $OUTPUT ($SIZE)"

if [[ ! -e "$OUTPUT" ]]; then
    qemu-img create -f qcow2 "$OUTPUT" "$SIZE" >/dev/null
fi

cleanup() {
    local rc=$?
    if mountpoint -q /mnt 2>/dev/null; then
        umount -R /mnt 2>/dev/null || true
    fi
    if [[ -n "$DEVICE" ]]; then
        assert_nbd "$DEVICE"
        qemu-nbd --disconnect "$DEVICE" >/dev/null 2>&1 || true
    fi
    exit "$rc"
}
trap cleanup EXIT

if [[ -n "$DEVICE" ]]; then
    # An explicit --device fails loudly rather than silently trying another -
    # if a human named one, a different one succeeding quietly would be a
    # surprise, not a convenience. It still gets the same two-part proof.
    assert_nbd "$DEVICE"
    qemu-nbd --connect="$DEVICE" --format=qcow2 "$OUTPUT" ||
        die "$DEVICE did not connect - is it already in use? 'lsblk $DEVICE' to check."
    partprobe "$DEVICE" 2>/dev/null || true
    udevadm settle
    device_serves_io "$DEVICE" ||
        die "$DEVICE connected but is not serving I/O - it may be wedged from an earlier session. Try a different --device, or 'qemu-nbd --disconnect $DEVICE' and retry."
else
    DEVICE="$(connect_free_device)" || die "no usable /dev/nbdN device (0-15 all busy or unresponsive)"
fi
assert_nbd "$DEVICE"

msg "Attached on $DEVICE"

# ----------------------------------------------------------------------
# Stages 1 and 2, unmodified, from the repository checkout
# ----------------------------------------------------------------------
#
# Exactly install.sh's own stages 1 and 2, run the same way it runs them: from
# the repository checkout, before anything is copied anywhere. See
# CLAUDE.md's "two execution contexts" - this script IS the live-ISO context
# for these two stages, the same role install.sh plays there.

assert_nbd "$DEVICE"

msg "[1/5] Partitioning $DEVICE"
# 01-disk.sh asks "Type ERASE to continue" before touching anything - a
# real, useful guard against a mistyped disk path. Piped rather than removed:
# this is our own freshly created scratch image, asserted nbd-only three
# lines above, so the confirmation's job is already done by the guard; typing
# it by hand here would add nothing but a wait.
echo ERASE | "$REPO_ROOT/setup/install/01-disk.sh" "$DEVICE"

msg "[2/5] Installing base Arch system"
"$REPO_ROOT/setup/install/02-base.sh"

msg "Copying setup payload into the target"
mkdir -p /mnt/opt/arch-setup
cp -a "$REPO_ROOT/setup/." /mnt/opt/arch-setup/

# ----------------------------------------------------------------------
# THE EFIVARS GUARD
# ----------------------------------------------------------------------
#
# Cannot mask /sys before chrooting - see the header comment: arch-chroot's
# sysfs mount is fresh and kernel-live, unaffected by anything done to the
# host's own /sys/firmware/efi/efivars beforehand. The mask has to happen
# AFTER arch-chroot's own setup has run (which may have already mounted the
# real efivarfs) and BEFORE the real stage script executes.
#
# A tmpfs mounted at that exact path shadows whatever is there - legal, and
# how e.g. systemd-nspawn hides host EFI variables from containers by
# default. bootctl then sees an empty directory it cannot write real
# variables through, and either skips the NVRAM step with a warning or writes
# harmlessly into the tmpfs - either way, nothing reaches real firmware.
#
# The shadow is explicitly unmounted before this wrapper exits, revealing
# whatever arch-chroot mounted there again, so arch-chroot's own teardown -
# which tracks and unmounts that mount - still succeeds cleanly rather than
# finding its target busy.
#
# Only stage 3 needs this. Stage 4's apply-config.sh runs without --activate
# here (confirmed by reading it: everything host-mutating is gated behind
# that flag and it exits before reaching any of it) and stage 5 never touches
# bootctl at all.

msg "[3/5] Configuring system (you will be asked for two passwords)"
arch-chroot /mnt /bin/bash -c '
    mount -t tmpfs tmpfs /sys/firmware/efi/efivars 2>/dev/null || true
    /opt/arch-setup/install/03-system.sh
    rc=$?
    umount /sys/firmware/efi/efivars 2>/dev/null || true
    exit $rc
'

msg "[4/5] Installing desktop"
arch-chroot /mnt /opt/arch-setup/install/04-desktop.sh

msg "[5/5] Installing user configuration"
arch-chroot /mnt /opt/arch-setup/install/05-dotfiles.sh

msg "Unmounting"
umount -R /mnt

# cleanup() (the EXIT trap) disconnects the nbd device from here.

chmod a-w "$OUTPUT"

echo
echo "Base image built: $OUTPUT"
echo "It is now read-only - writing to it would corrupt every machine cloned"
echo "from it. 'vm new NAME' clones it; 'vm list' shows what already has."
