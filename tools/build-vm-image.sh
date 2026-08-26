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
# install.sh itself does, rather than calling install.sh. No stage script is
# edited or patched at build time - see "THE EFIVARS GUARD" below for how stage
# 3's one genuine hazard is neutralised without touching it.
#
# That used to read "every stage script is used completely unmodified", and
# TASK-69.4 made it untrue in one specific way worth stating rather than
# glossing: 03-system.sh now carries a branch that exists solely for this
# builder, taken when GUEST_PRESET_PASSWORD is set in the environment. The file
# on disk is the same file a real install runs; what differs is which path
# through it a guest build takes.
#
# WHY PASSWORDS ARE NO LONGER INTERACTIVE FOR GUESTS
#
# This block used to say the opposite, and said it emphatically: that stage 3
# prompts for both passwords the same as any other install, and that this
# script reads a password from nowhere. That is no longer true, and leaving it
# would be the exact failure this repository keeps naming - a comment stating a
# stance the code has stopped taking.
#
# A guest is built with a fixed username and a fixed password, both written
# down in plain text further down this file. The reasoning, in full, is beside
# them under "Guest identity"; the short version is that a guest already logs
# ITSELF in, sits behind the host's own login, and is explicitly not for
# confidential work - so the credential is not defending anything. What it buys
# is a guest that can be driven without a human at the keyboard: sudo, and
# sshd.
#
# FOR REAL MACHINES NOTHING HAS CHANGED. install.sh never sets
# GUEST_PRESET_PASSWORD and has no flag that reaches it, so a real install
# still prompts for both passwords via a real `passwd` and still stores neither.
# setup/install.conf is not written to by this script at all, and the build
# asserts that it was not. See TASK-69.2, TASK-69.4 and DECISIONS.md.
#
# requires: qemu-img qemu-nbd modprobe udevadm partprobe unshare arch-chroot mountpoint umount chmod mkdir cp readlink dirname basename sed seq cat getent mktemp
#
# Transitively, through the unmodified stage scripts this drives: parted,
# dosfstools (mkfs.fat), btrfs-progs (mkfs.btrfs), arch-install-scripts
# (pacstrap, genfstab, arch-chroot). None of that belongs in setup/packages/ -
# this script and everything it needs is repository build tooling, installed
# by hand once, exactly like backlog. It never reaches the built machine.

die() { echo "build-vm-image: $*" >&2; exit 1; }
warn() { echo "build-vm-image: WARNING: $*" >&2; }
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

The guest is built as user "user" with password "password", and root has the
same password. Both are fixed and deliberately weak: a guest logs itself in
already, sits behind this machine's own login, and is not for confidential
work - the credential exists so a guest can be driven without a human at the
keyboard. Nothing is asked during the build, and it can be left unattended.

A real install is unaffected and still prompts for both passwords.
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

# $HOME is root's, not the operator's, the moment this runs under `sudo`
# without -E, or under `pkexec` at all - both reset the environment rather
# than preserving it. A first real build on this machine wrote a complete
# 5.4 GiB base image to /root/.local/share/vm/base.qcow2, invisible to
# ~/.local/bin/vm, which reads the REAL user's home - and $HOME was the only
# place that mistake could come from, since it is the only thing this script
# reads to decide where to write.
#
# So the default output path is resolved against whoever actually asked for
# this, not against whatever $HOME resolved to after the privilege escalation:
# `sudo` sets SUDO_USER, `pkexec` sets PKEXEC_UID (a uid, not a name), and
# only if neither is set - a genuine root login, not an escalation - does
# root's own $HOME apply.
invoking_home() {
    local user=""
    if [[ -n "${SUDO_USER:-}" ]]; then
        user="$SUDO_USER"
    elif [[ -n "${PKEXEC_UID:-}" ]]; then
        user="$(getent passwd "$PKEXEC_UID" 2>/dev/null | cut -d: -f1)"
    fi
    if [[ -n "$user" ]]; then
        local home
        home="$(getent passwd "$user" 2>/dev/null | cut -d: -f6)"
        [[ -n "$home" ]] && { printf '%s' "$home"; return 0; }
    fi
    printf '%s' "$HOME"
}

OUTPUT="${XDG_DATA_HOME:-$(invoking_home)/.local/share}/vm/base.qcow2"
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

# Said plainly and early, not just folded into the first progress line: WHERE
# this is about to write is exactly the thing that went wrong the first time
# this ran on this machine. A path under /root here means invoking_home()
# could not work out who really asked, and is worth stopping to check before
# spending the next twenty minutes writing to the wrong home entirely.
msg "Output: $OUTPUT"
case "$OUTPUT" in
    /root/*) warn "this is under /root. If you meant this to reach your own account, that did not happen - Ctrl-C now and pass --output explicitly." ;;
esac

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
    # CRITICAL: disconnecting a device that is STILL MOUNTED discards
    # whatever the filesystem had buffered and not yet flushed, and can
    # leave the filesystem's own metadata inconsistent - this is not
    # theoretical, it is exactly how a real base.qcow2 lost its filesystem
    # signatures entirely on this machine, confirmed by `blkid -p` finding
    # nothing recognisable on either partition afterwards, while `qemu-img
    # check` still reported the qcow2 container itself as structurally
    # sound. The corruption was findable only at the filesystem level,
    # because that is exactly the layer this used to skip checking.
    #
    # So: if umount above did not actually succeed, do NOT disconnect.
    # A connected-but-orphaned nbd device is an annoyance - `qemu-nbd
    # --disconnect /dev/nbdN` once whatever was holding it releases - not
    # data loss. That trade is correct every time.
    if mountpoint -q /mnt 2>/dev/null; then
        warn "/mnt is still mounted - NOT disconnecting $DEVICE, to avoid discarding unflushed writes and corrupting it. Once whatever is holding it releases (check with 'fuser -vm /mnt'), unmount by hand and then 'qemu-nbd --disconnect $DEVICE'."
    elif [[ -n "$DEVICE" ]]; then
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
# Guest identity: fixed, weak, and deliberately not the repository's
# ----------------------------------------------------------------------
#
# A guest is not a machine anyone logs into as themselves. It already logs
# ITSELF in - see the auto-login block near the foot of this script - so a
# password here is not a line of defence in front of anything: the guest sits
# behind the HOST's login, and these images are explicitly not for confidential
# work. What a credential buys is the ability to drive a guest without a human
# at the keyboard: sudo, and enabling sshd. Without one, every command inside a
# guest has to be typed into a qemu window and read back off the screen.
#
# So this is a real weakening, scoped to guests, decided deliberately. See
# TASK-69.4 and DECISIONS.md's "Passwords" section, which records both this and
# the unchanged stance for real machines.
#
# THE OVERRIDE REACHES THE STAGES THROUGH THE COPY, NEVER THE REPOSITORY.
# 03-system.sh and 05-dotfiles.sh both `source "$SETUP_ROOT/install.conf"`,
# and SETUP_ROOT is /opt/arch-setup - the copy made immediately above, not
# $REPO_ROOT/setup/install.conf. Rewriting the copy therefore reaches every
# stage while the repository's own file stays byte-identical, which matters
# more than it looks: that file names the user of every REAL machine this
# repository installs, including the one being read on right now.
#
# The quoting style is load-bearing in two directions - `source` has to accept
# it and dot_gitconfig.tmpl's regex has to match it - so the replacement keeps
# the exact KEY="value" shape the wizard writes. See setup/install.conf.
GUEST_USERNAME="user"
GUEST_PASSWORD="password"

# Recorded before the edit so the assertion afterwards compares against what
# was actually there, rather than against a guess about what it should say.
REPO_USERNAME_LINE="$(grep '^USERNAME=' "$REPO_ROOT/setup/install.conf")"

msg "Overriding guest identity: user '$GUEST_USERNAME' (the repository's own install.conf is untouched)"
sed -i "s/^USERNAME=\".*\"\$/USERNAME=\"$GUEST_USERNAME\"/" /mnt/opt/arch-setup/install.conf

# Assert rather than trust, in both directions. A silent no-op on the copy
# would build an image whose auto-login names an account the stages never
# created - a guest that boots to a greeter it cannot get past, discovered
# only after a full pacstrap. And a sed that somehow reached the repository's
# own file would rename the user of every real machine built afterwards.
#
# `if ! ...` rather than `... || die`, and a comparison rather than a grep for
# the guest name: a machine whose real configured username happened to be
# "user" would make the naive check fire on a file nothing had touched.
if ! grep -qx "USERNAME=\"$GUEST_USERNAME\"" /mnt/opt/arch-setup/install.conf; then
    die "failed to override USERNAME in the copied install.conf"
fi
if [[ "$(grep '^USERNAME=' "$REPO_ROOT/setup/install.conf")" != "$REPO_USERNAME_LINE" ]]; then
    die "the repository's own install.conf changed during the build - it must never be written to"
fi

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

# GUEST_PRESET_PASSWORD is read by 03-system.sh, which uses chpasswd instead of
# its interactive passwd when it is set, and takes exactly the old interactive
# path when it is not. Nothing but this line sets it: install.sh has no flag
# that reaches it, so a real install is unaffected.
#
# Passed through the environment rather than on the command line, so it does not
# appear in `ps` output for the duration of the build. That is tidiness, not
# secrecy - the value is "password" and is written down in this file, in
# DECISIONS.md and in the guest's own documentation.
#
# arch-chroot's default path is a plain `chroot` with no `env -i` (its
# --reset-env is only on the -S systemd-run path, which this script does not
# use), so the variable is inherited by the stage script. Checked in
# /usr/bin/arch-chroot rather than assumed.
msg "[3/5] Configuring system (guest passwords are preset - you will NOT be asked)"
GUEST_PRESET_PASSWORD="$GUEST_PASSWORD" arch-chroot /mnt /bin/bash -c '
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

# The guest's identity is GUEST_USERNAME, set where the copied install.conf was
# overridden above - NOT whatever $REPO_ROOT/setup/install.conf says. This line
# used to source that file, which was correct only while the two agreed. Now
# that a guest is built as a different user, sourcing it would point the two
# steps below - the wallpaper check and the auto-login block - at an account
# 03-system.sh never created, and the build would ship a guest that boots to a
# greeter it cannot get past. The failure would appear at first boot of a clone,
# a long way from the cause.
#
# install.conf is still the source of everything else about a guest; only the
# username differs, and only because this builder deliberately overrode it.
USERNAME="$GUEST_USERNAME"

# ----------------------------------------------------------------------
# Guest-only: guarantee the wallpaper actually exists
# ----------------------------------------------------------------------
#
# Reproduced directly, not assumed: a machine cloned from a base image built
# without this step boots to sway's own "There are errors in your config
# file" banner, permanently - a black screen, no waybar, no wallpaper, and it
# does NOT self-heal. Confirmed by mounting a freshly cloned, never-booted
# guest's disk read-only: ~/.local/share/wallpapers/ does not exist at all.
# sway's rendered config names that exact path as the background image
# (`output * bg .../abyss-mesh.png fill`), and a background image that does
# not exist is what sway treats as a config error, not a runtime warning -
# which is why the failure is total rather than just a missing picture.
#
# run_onchange_after_reload-theme.sh.tmpl is SUPPOSED to generate this during
# 05-dotfiles.sh's chezmoi apply - its own comment says so explicitly
# ("the installer runs this in a chroot where there is no sway at all...
# getting that wrong would mean every fresh machine's first login had no
# wallpaper") - and on this build it evidently did not, or failed silently:
# the script backs the generation call with `|| echo ... >&2`, a warning
# easily lost in a pacstrap-and-apply build's scrollback rather than a hard
# stop. Whether that is a bug in the mechanism itself, one that would equally
# affect a genuine `install.sh` run on real hardware, is being tracked
# separately (TASK-157) - not fixed here, because this builder cannot safely
# diagnose the chroot-vs-real-session difference on its own.
#
# What this step CAN do reliably is verify the outcome and refuse to ship a
# base image that would fail this way: call --ensure explicitly, as the
# actual user rather than root, and fail the whole build loudly if the file
# still is not there - the same "prove it, do not assume it" standard this
# builder already holds itself to elsewhere.
msg "Ensuring the wallpaper exists (a missing one is a sway config error, not a missing picture)"
arch-chroot /mnt runuser -u "$USERNAME" -- env HOME="/home/$USERNAME" \
    "/home/$USERNAME/.local/bin/wallpaper" --ensure
WALLPAPER_FILE="$(arch-chroot /mnt runuser -u "$USERNAME" -- env HOME="/home/$USERNAME" \
    "/home/$USERNAME/.local/bin/wallpaper" --path)"
if [[ ! -f "/mnt$WALLPAPER_FILE" ]]; then
    die "wallpaper --ensure reported success but $WALLPAPER_FILE does not exist - refusing to ship a base image whose first boot would show a config-error screen. See TASK-157."
fi

# ----------------------------------------------------------------------
# Guest-only: auto-login
# ----------------------------------------------------------------------
#
# A real machine keeps its interactive login prompt - that is deliberate, see
# DECISIONS.md's "Passwords" section, and install.sh is never touched to weaken
# it. A GUEST is different: it has already sat behind the HOST's own login
# (either the real desktop, or the "Virtual machine" session at the greeter),
# so asking again inside the guest is a second password for the same person in
# the same sitting, not a second line of defence. This block is added ONLY to
# the guest's own config, by this builder, never to setup/system/greetd/ itself
# - a real install is completely unaffected by it.
#
# greetd's `initial_session` runs once per boot, gated on a runfile under
# /run - tmpfs, cleared on every boot - so it fires again every single time
# `vm run` starts a fresh qemu instance, and a manual logout within that same
# boot falls back to the normal password prompt rather than looping.
#
# USERNAME comes from this repository's own install.conf, the same source
# 03-system.sh reads it from - not hardcoded, so a machine with a different
# configured username still gets a guest that logs itself in as the right
# person.
msg "Configuring guest auto-login (base image only, never the repository's own config)"
cat >> /mnt/etc/greetd/config.toml <<EOF

[initial_session]
command = "uwsm start -N Sway -D sway -- sway"
user = "$USERNAME"
EOF

# ----------------------------------------------------------------------
# Guest-only: sshd, so a guest can be driven from the host
# ----------------------------------------------------------------------
#
# openssh is already in packages/base.txt and is therefore already installed
# here; what it is not is enabled, on a guest or anywhere else. A real machine
# keeps it that way - this enables it in the GUEST's own filesystem only, the
# same way the auto-login above is written only here.
#
# On its own this achieves nothing observable, which is worth stating because it
# was assumed otherwise once. qemu's user-mode networking gives a guest no
# inbound route at all, so an sshd listening inside one is unreachable from the
# host until `vm` forwards a host port to it. Both halves are needed and both
# landed together; see the SSH_PORT block in dot_local/bin/executable_vm.
#
# The pairing with a known password is deliberate and is only defensible because
# that forward is bound to 127.0.0.1. See DECISIONS.md -> "Passwords".
msg "Enabling sshd in the guest (base image only - a real install leaves it disabled)"
arch-chroot /mnt systemctl enable sshd.service

msg "Unmounting"
# "target is busy" on the first attempt is real, observed behaviour on this
# machine - the very first full build hit it here, after every install stage
# had genuinely finished correctly. Something (a keyring agent from pacman's
# signature checks is the likely culprit, going by what runs during stage 2,
# though it was not caught in the act) still had a handle into /mnt for a
# moment after 05-dotfiles.sh returned. It let go on its own almost
# immediately - a second attempt moments later, made by this exact retry loop
# during testing, succeeded - so this is a short bounded retry, not a
# `|| true`: a real failure to unmount should still stop the script before
# `chmod a-w`, not be silently swallowed.
#
# Getting this wrong the first time cost something real: `set -e` on a bare
# `umount -R /mnt` meant the ENTIRE remaining tail of the script - chmod a-w
# and the success message - never ran, even though every stage had already
# finished. The image was completely built and simply left writable and
# unannounced. Nothing was lost, but it read like a failed build.
#
# 5 attempts at 1s each was not always enough - a second real build hit the
# same busy condition and it had not cleared even after 5s, though it did
# clear shortly after (confirmed: /mnt was freely unmountable moments later,
# by hand). 15 attempts at 2s (up to 30s) gives real headroom without
# changing the fundamental contract: still a bounded retry, still a hard
# die() if it genuinely never clears - see cleanup() above for why running
# out of patience here must never mean disconnecting a still-mounted device.
umount_err="$(mktemp)"
for attempt in $(seq 1 15); do
    if umount -R /mnt 2>"$umount_err"; then
        break
    fi
    if (( attempt == 15 )); then
        cat "$umount_err" >&2
        rm -f "$umount_err"
        die "/mnt would not unmount after 15 attempts (30s). 'fuser -vm /mnt' from another terminal shows what still has it open."
    fi
    sleep 2
done
rm -f "$umount_err"

# cleanup() (the EXIT trap) disconnects the nbd device from here.

chmod a-w "$OUTPUT"

echo
echo "Base image built: $OUTPUT"
echo "It is now read-only - writing to it would corrupt every machine cloned"
echo "from it. 'vm new NAME' clones it; 'vm list' shows what already has."
