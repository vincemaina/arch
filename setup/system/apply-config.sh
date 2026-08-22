#!/usr/bin/env bash
set -euo pipefail

# Installs machine-wide configuration from this repository.
#
# Called by install/04-desktop.sh during a fresh install, and by sync.sh on a
# machine that already exists. Defining the destinations once is the point: a
# change here has to reach both paths, or the two drift and a setting that
# works on a new machine never arrives on the running one.
#
# Everything here must be safe to run repeatedly on a live system.
#
# Bootloader configuration is deliberately absent. Boot entries are rendered
# from templates with the root UUID substituted, which is install-time work,
# and rewriting them on a running machine is a good way to make it unbootable.
#
# Must run as root.

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ACTIVATE=false
[[ "${1:-}" == "--activate" ]] && ACTIVATE=true

if [[ $EUID -ne 0 ]]; then
    echo "apply-config.sh must run as root." >&2
    exit 1
fi

# repository file : destination
CONFIG_FILES=(
    "zram-generator.conf:/etc/systemd/zram-generator.conf"
    "sysctl.d/99-zram.conf:/etc/sysctl.d/99-zram.conf"
    # Turns zswap off, so the zram device above is the compressed swap rather
    # than a fallback behind a smaller pool that catches 99% of the traffic.
    # The file itself explains why it is tmpfiles and not the kernel cmdline.
    "tmpfiles.d/zswap.conf:/etc/tmpfiles.d/zswap.conf"
    "earlyoom.conf:/etc/default/earlyoom"
    "keyd/default.conf:/etc/keyd/default.conf"
    "greetd/config.toml:/etc/greetd/config.toml"
    "greetd/regreet.toml:/etc/greetd/regreet.toml"
    # Local session entries. /usr/local/share is the directory the desktop
    # entry spec reserves for these, and it takes precedence over /usr/share,
    # which is what lets sway.desktop hide the packaged entry rather than
    # replace a file pacman owns.
    "wayland-sessions/sway-uwsm.desktop:/usr/local/share/wayland-sessions/sway-uwsm.desktop"
    "wayland-sessions/sway.desktop:/usr/local/share/wayland-sessions/sway.desktop"
)

for mapping in "${CONFIG_FILES[@]}"; do
    src="${mapping%%:*}"
    dest="${mapping#*:}"
    echo "    $dest"
    install -Dm644 "$SYSTEM_ROOT/$src" "$dest"
done

# /etc/vconsole.conf, from KEYMAP in install.conf.
#
# TASK-115: this used to be written once, by 03-system.sh, and only there -
# machine identity rather than system configuration, so it fell outside what
# this script owned, and sync.sh had no path to correct it if the wizard
# answer was wrong. It is exactly the kind of machine-wide file this script
# exists to own, so it moves here rather than gaining a second writer:
# 03-system.sh no longer touches it, and it is written once, during install,
# when 04-desktop.sh calls this script.
#
# install.conf is machine identity, sourced rather than copied like the files
# above, so a value substitution rather than a straight file install.
INSTALL_CONF="$SYSTEM_ROOT/../install.conf"

if [[ -f "$INSTALL_CONF" ]]; then
    # shellcheck source=/dev/null
    source "$INSTALL_CONF"
fi

if [[ -n "${KEYMAP:-}" ]]; then
    echo "    /etc/vconsole.conf"
    echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
else
    echo "    WARNING: KEYMAP not found in $INSTALL_CONF; leaving /etc/vconsole.conf alone" >&2
fi

# The greeter's stylesheet, RENDERED rather than copied.
#
# ReGreet reads /etc/greetd/regreet.css by default, so nothing on the cage
# command line has to name it. The colours come from .chezmoidata/themes.toml -
# the same single source sway, the bar, foot, rofi, mako, swaylock, the prompt
# and the editor all read - instead of being copied into this file by hand.
#
# WHICH THEME, AND WHY IT IS RENDERED AS THE INVOKING USER.
#
# The selected theme is machine-local, in the user's own chezmoi config, so
# rendering as root would always produce the tracked default no matter what the
# machine is actually wearing. SUDO_USER is who ran ./sync.sh, so rendering as
# them follows the theme they picked. A fresh install has no SUDO_USER and no
# user config, and correctly gets the tracked default - which is right for a
# machine nobody has logged into yet.
#
# The greeter therefore lags a theme switch until the next sync. Deliberate:
# ~/.local/bin/theme has no root, and prompting for a password on every theme
# switch to repaint a screen seen once a day is the worse trade.
#
# Failing to render is a warning, not fatal. A greeter with last sync's colours
# still logs you in; a sync that aborts here leaves the rest of the machine
# unconfigured.
GREETER_CSS_SRC="$SYSTEM_ROOT/greetd/regreet.css.tmpl"
GREETER_DOTFILES="$(cd "$SYSTEM_ROOT/.." && pwd)/dotfiles"

if [[ -f "$GREETER_CSS_SRC" ]] && command -v chezmoi >/dev/null; then
    echo "    /etc/greetd/regreet.css"
    greeter_css_tmp="$(mktemp)"
    if [[ -n "${SUDO_USER:-}" ]] && id "$SUDO_USER" &>/dev/null; then
        render_ok=false
        runuser -u "$SUDO_USER" -- chezmoi --source "$GREETER_DOTFILES" \
            execute-template < "$GREETER_CSS_SRC" > "$greeter_css_tmp" &&
            render_ok=true
    else
        render_ok=false
        chezmoi --source "$GREETER_DOTFILES" \
            execute-template < "$GREETER_CSS_SRC" > "$greeter_css_tmp" &&
            render_ok=true
    fi

    # A truncated stylesheet is worse than an old one - GTK stops at the first
    # parse error and leaves everything after it unstyled, which looks like a
    # half-themed greeter rather than a failure.
    if $render_ok && [[ -s "$greeter_css_tmp" ]] &&
       ! grep -q '{{' "$greeter_css_tmp"; then
        install -Dm644 "$greeter_css_tmp" /etc/greetd/regreet.css
    else
        echo "    WARNING: could not render the greeter stylesheet; leaving the existing one" >&2
    fi
    rm -f "$greeter_css_tmp"
fi

# Executables, which need a different mode from the config files above.
#
# xdg-terminal-exec is here rather than in the dotfiles for one reason: glib
# looks it up BY NAME on PATH when it has to run a Terminal=true desktop entry,
# and there is nowhere to give it an absolute path. Every other helper this
# repository installs is reached by absolute path precisely because ~/.local/bin
# is not on the session PATH; this is the one that cannot be. /usr/local/bin is
# on the default PATH of every process, so it is found without anything being
# arranged.
EXECUTABLES=(
    "bin/xdg-terminal-exec:/usr/local/bin/xdg-terminal-exec"
)

for mapping in "${EXECUTABLES[@]}"; do
    src="${mapping%%:*}"
    dest="${mapping#*:}"
    echo "    $dest"
    install -Dm755 "$SYSTEM_ROOT/$src" "$dest"
done

# Enabling works inside the installer chroot; starting does not, because there
# is no running system there to start anything on.
#
# A unit only exists once its package is installed, so this must run after the
# manifests have been applied. Checking first turns an ordering mistake into a
# clear message rather than an install that aborts partway through with
# "Unit greetd.service does not exist".
#
# greetd owns VT 1 and replaces the getty there. The other VTs keep theirs, so
# Ctrl+Alt+F2 remains the way to reach a plain shell if the session will not
# start.
# keyd grabs every keyboard on the machine, so a config it cannot parse is the
# difference between a remapped keyboard and no keyboard at all - on the machine
# you would need in order to fix it. keyd check is a real gate: it exits
# non-zero on a bad config. Validate before the unit is ever enabled or started.
#
# The panic sequence, should it ever be needed: backspace+escape+enter, held
# together, forces keyd to terminate and hands the keyboard back.
if command -v keyd &>/dev/null; then
    if ! keyd check /etc/keyd/default.conf; then
        echo "Refusing to enable keyd: /etc/keyd/default.conf does not parse." >&2
        echo "Enabling it would leave this machine without a usable keyboard." >&2
        exit 1
    fi
fi

ENABLE_UNITS=(earlyoom greetd keyd)

for unit in "${ENABLE_UNITS[@]}"; do
    # Checked by file rather than with systemctl, because this also runs inside
    # the installer chroot where there is no manager to ask.
    if [[ ! -e "/usr/lib/systemd/system/$unit.service" \
       && ! -e "/etc/systemd/system/$unit.service" ]]; then
        echo "Cannot enable $unit: no unit file for it exists." >&2
        echo "Its package is not installed yet, so this ran too early." >&2
        exit 1
    fi
    systemctl enable "$unit"
done

# ----------------------------------------------------------------------
# initramfs
# ----------------------------------------------------------------------
#
# Lives here rather than in the installer so a change reaches a machine that
# already exists. Regenerating takes a while, so it only happens when something
# actually changed or an expected image is missing.

REGENERATE=false

# Microcode is loaded through the mkinitcpio hook, which bundles it into the
# initramfs, rather than through a separate initrd line in the boot entry. The
# hook is part of the default HOOKS, so this usually only confirms it.
if ! grep -qE '^HOOKS=.*\bmicrocode\b' /etc/mkinitcpio.conf; then
    echo "    Adding the microcode hook after autodetect"
    sed -i -E 's/^(HOOKS=.*\bautodetect\b)/\1 microcode/' /etc/mkinitcpio.conf
    REGENERATE=true
fi

if ! grep -qE '^HOOKS=.*\bmicrocode\b' /etc/mkinitcpio.conf; then
    echo "Could not add the microcode hook to /etc/mkinitcpio.conf." >&2
    grep -E '^HOOKS=' /etc/mkinitcpio.conf >&2
    exit 1
fi

# mkinitcpio v40 stopped building the fallback image by default, shipping
# PRESETS=('default') where it used to include 'fallback'. The bootloader
# offers a fallback entry, and an entry pointing at an image that does not
# exist is worse than no entry at all: it looks like a recovery path right up
# until the moment it is needed.
# Three lines have to be uncommented, not one. Enabling the preset alone gets
# the fallback listed and still built nothing: mkinitcpio takes the image path
# from ${preset}_image, and with that commented out it prints "No image or UKI
# specified. Skipping image" and carries on, exiting 0. Every visible signal -
# the preset, the boot entry, this script's own output - said the image existed.
#
# fallback_options matters as much as the path. "-S autodetect" is what makes
# the fallback a fallback: without it the image is built with autodetect and
# contains modules only for the hardware present at build time, which is
# precisely the hardware that may have stopped working. A fallback that is a
# copy of the default is not a recovery path.
#
# Each rewrite matches the exact stock commented form, so a preset that is
# already correct or has been customised by hand is left alone.
for preset in /etc/mkinitcpio.d/*.preset; do
    [[ -e "$preset" ]] || continue

    if grep -qE "^PRESETS=\\('default'\\)" "$preset"; then
        echo "    Enabling the fallback preset in $(basename "$preset")"
        sed -i -E "s/^PRESETS=\\('default'\\)/PRESETS=('default' 'fallback')/" "$preset"
        REGENERATE=true
    fi

    # Only meaningful once the preset lists fallback; a preset that genuinely
    # only wants the default image should not have these forced on.
    grep -qE "^PRESETS=.*'fallback'" "$preset" || continue

    for setting in fallback_image fallback_options; do
        if grep -qE "^#${setting}=" "$preset" && ! grep -qE "^${setting}=" "$preset"; then
            echo "    Uncommenting ${setting} in $(basename "$preset")"
            sed -i -E "s/^#(${setting}=)/\\1/" "$preset"
            REGENERATE=true
        fi
    done

    # A fallback with no destination is the silent case above. Catch it here,
    # where it can still be reported, rather than letting mkinitcpio skip it.
    if ! grep -qE "^fallback_(image|uki)=" "$preset"; then
        echo "Cannot build the fallback image: $preset lists the fallback" >&2
        echo "preset but sets no fallback_image or fallback_uki." >&2
        exit 1
    fi
done

# Catches the case where the preset is already correct but the image was never
# built, which is the state a machine installed before this fix is left in.
EXPECTED_IMAGES=(
    /boot/initramfs-linux.img
    /boot/initramfs-linux-fallback.img
)

for img in "${EXPECTED_IMAGES[@]}"; do
    if [[ ! -s "$img" ]]; then
        echo "    $img is missing"
        REGENERATE=true
    fi
done

if $REGENERATE; then
    echo "    Regenerating initramfs"
    mkinitcpio -P

    # mkinitcpio warns rather than fails when it skips a preset, so a zero exit
    # says nothing about which images were actually produced. Ask the
    # filesystem instead. This is the check that would have caught the fallback
    # never being built, months before it was needed.
    for img in "${EXPECTED_IMAGES[@]}"; do
        if [[ ! -s "$img" ]]; then
            echo "mkinitcpio reported success but $img was not produced." >&2
            echo "Check the preset in /etc/mkinitcpio.d/ for a skipped image." >&2
            exit 1
        fi
    done
else
    echo "    initramfs images are present and configuration is unchanged"
fi

# NetworkManager-wait-online holds network-online.target until a connection is
# up. Nothing on this system orders after that target, so the wait buys nothing
# and can stall boot for many seconds on wireless or a slow DHCP lease.
if [[ -e /usr/lib/systemd/system/NetworkManager-wait-online.service ]]; then
    systemctl disable NetworkManager-wait-online.service
fi

if ! $ACTIVATE; then
    exit 0
fi

# --activate is for the sync path, where the machine is running and the point
# is for the change to take effect now rather than at the next boot. Failures
# are reported rather than fatal: the configuration is already written, and a
# service that will not restart should not fail the whole sync.

echo
echo "    Applying to the running system"

if ! sysctl --system >/dev/null; then
    echo "    WARNING: sysctl --system failed; settings apply at next boot" >&2
fi

systemctl daemon-reload

if ! systemctl restart earlyoom; then
    echo "    WARNING: could not restart earlyoom" >&2
fi

# Safe to restart, unlike greetd: keyd owns no session. It re-grabs the
# keyboards on start, so the remap applies to the session already running
# rather than waiting for a reboot.
if ! systemctl restart keyd; then
    echo "    WARNING: could not restart keyd; key remapping is unchanged" >&2
fi

# Also safe: systemd-vconsole-setup owns no session either, and the keymap it
# loads is a single kernel-wide table shared by every virtual console, not
# per-VT state. Restarting it re-reads /etc/vconsole.conf and reapplies now,
# rather than leaving a corrected KEYMAP stranded until the next boot.
if [[ -n "${KEYMAP:-}" ]] && ! systemctl restart systemd-vconsole-setup.service; then
    echo "    WARNING: could not reapply the console keymap; it applies at next boot" >&2
fi

# Deliberately not restarted: greetd owns the active session, and restarting it
# would kill the desktop of whoever is running this.
if systemctl is-active --quiet greetd; then
    echo "    greetd is running; login screen changes apply at next boot"
fi

# zswap, which is on by default in the Arch kernel and would otherwise stay on
# until the next boot. Writing the sysfs parameter through tmpfiles rather than
# by hand means the same file is the authority at boot and now.
#
# Pages already held in zswap are not lost by this: they stay compressed until
# something faults them in, and nothing new enters the pool afterwards.
if ! systemd-tmpfiles --create /etc/tmpfiles.d/zswap.conf; then
    echo "    WARNING: could not turn zswap off; it applies at next boot" >&2
elif [[ "$(cat /sys/module/zswap/parameters/enabled 2>/dev/null)" == "N" ]]; then
    echo "    zswap is off, so zram is the compressed swap"
else
    echo "    WARNING: zswap is still enabled after writing the parameter" >&2
fi

# zram is created by a generator, so the device only appears after the
# generators are re-run. A resize of an in-use device is refused, which is
# correct: it holds swapped-out pages.
if swapon --show=NAME --noheadings | grep -q zram; then
    echo "    zram is already active; a size change needs a reboot"
elif ! systemctl start systemd-zram-setup@zram0.service; then
    echo "    WARNING: could not start zram; it will be created at next boot" >&2
fi
