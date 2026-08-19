#!/usr/bin/env bash
set -uo pipefail

# Checks that a running machine actually matches what this repository intends.
#
# checks/sway-commands.sh verifies the configuration is coherent. This one
# verifies the live system: that swap exists, the OOM handler is running, the
# session components are supervised, and the boot path is set up as intended.
#
# Read-only. It inspects and reports; it changes nothing.
#
# A few things cannot be checked by a script at all - whether a keypress
# produces a screenshot, whether a password prompt appears. Those are listed
# at the end for a human to try.

PASS=0
FAIL=0
SKIP=0

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; FAIL=$((FAIL + 1)); }
skip() { printf '  \033[33mSKIP\033[0m  %s\n' "$*"; SKIP=$((SKIP + 1)); }

section() { printf '\n==> %s\n' "$*"; }

# ----------------------------------------------------------------------
section "Compressed swap (TASK-9)"

if swapon --show=NAME --noheadings 2>/dev/null | grep -q zram; then
    size="$(swapon --show=NAME,SIZE --noheadings | awk '/zram/ {print $2}')"
    pass "zram is active as swap (${size})"

    if command -v zramctl &>/dev/null; then
        algo="$(zramctl --output NAME,ALGORITHM --noheadings 2>/dev/null | awk '/zram/ {print $2}')"
        if [[ "$algo" == zstd* ]]; then
            pass "compression algorithm is zstd"
        else
            fail "compression algorithm is '${algo:-unknown}', expected zstd"
        fi
    else
        skip "zramctl not available, cannot check the algorithm"
    fi
else
    fail "no zram swap device is active (expected /dev/zram0)"
fi

swappiness="$(sysctl -n vm.swappiness 2>/dev/null)"
if [[ "$swappiness" == "180" ]]; then
    pass "vm.swappiness is 180"
else
    fail "vm.swappiness is ${swappiness:-unset}, expected 180"
fi

page_cluster="$(sysctl -n vm.page-cluster 2>/dev/null)"
if [[ "$page_cluster" == "0" ]]; then
    pass "vm.page-cluster is 0"
else
    fail "vm.page-cluster is ${page_cluster:-unset}, expected 0"
fi

# ----------------------------------------------------------------------
section "Out-of-memory handling (TASK-9)"

if systemctl is-active --quiet earlyoom; then
    pass "earlyoom is running"

    # Inspect the running process, not `systemctl show ExecStart`: that
    # reports the command line as written in the unit file, where the
    # arguments are still the literal string $EARLYOOM_ARGS. Only the process
    # itself shows what the expansion actually produced.
    cmdline="$(ps -C earlyoom -o args= 2>/dev/null | head -1)"

    if [[ -z "$cmdline" ]]; then
        skip "could not read the earlyoom command line"
    elif ! grep -q -- '--avoid' <<<"$cmdline"; then
        fail "earlyoom is running without its avoid/prefer patterns; is /etc/default/earlyoom applied?"
    elif grep -qE -- "--avoid[[:space:]]+['\"]" <<<"$cmdline"; then
        fail "earlyoom's regexes arrived quoted, so they will never match"
    else
        pass "earlyoom is running with its avoid/prefer patterns"
    fi
else
    fail "earlyoom is not running"
fi

# ----------------------------------------------------------------------
section "Session components (TASK-11)"

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    skip "not running inside a Wayland session; run this from a terminal in sway"
else
    for unit in waybar mako swayidle polkit-agent; do
        if systemctl --user is-active --quiet "$unit"; then
            restart="$(systemctl --user show "$unit" --property=Restart --value 2>/dev/null)"
            if [[ "$restart" == "on-failure" || "$restart" == "always" ]]; then
                pass "$unit is running and is restarted on failure"
            else
                fail "$unit is running but Restart=${restart:-no}, so a crash would be permanent"
            fi
        else
            fail "$unit is not running"
        fi
    done

    if systemctl --user is-active --quiet graphical-session.target; then
        pass "graphical-session.target is active (session started through uwsm)"
    else
        fail "graphical-session.target is inactive; was sway started with 'uwsm start -- sway'?"
    fi
fi

# ----------------------------------------------------------------------
section "Boot path (TASK-8)"

if grep -qE '^HOOKS=.*\bmicrocode\b' /etc/mkinitcpio.conf 2>/dev/null; then
    pass "the microcode hook is present in mkinitcpio HOOKS"
else
    fail "the microcode hook is missing from /etc/mkinitcpio.conf"
fi

for pkg in intel-ucode amd-ucode; do
    if pacman -Qq "$pkg" &>/dev/null; then
        pass "$pkg is installed"
    else
        fail "$pkg is not installed"
    fi
done

entries=(/boot/loader/entries/*.conf)
if [[ -e "${entries[0]}" ]]; then
    if [[ -e /boot/loader/entries/arch-fallback.conf ]]; then
        pass "both boot entries exist (${#entries[@]} total)"
    else
        fail "no fallback boot entry (found: ${entries[*]##*/}); boot entries are install-time only, so this needs a machine built by the current install.sh"
    fi
else
    skip "/boot/loader/entries is empty or unreadable; needs a fresh install"
fi

# ----------------------------------------------------------------------
section "Screenshot helper (TASK-10)"

if [[ -x "$HOME/.local/bin/sway-screenshot" ]]; then
    if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        skip "cannot capture outside a Wayland session"
    else
        shot="$("$HOME/.local/bin/sway-screenshot" screen 2>&1)"
        if [[ -s "$shot" ]]; then
            pass "captured a screenshot to $shot"
            rm -f "$shot"
        else
            fail "sway-screenshot did not produce a file: $shot"
        fi
    fi
else
    fail "$HOME/.local/bin/sway-screenshot is missing or not executable"
fi

# ----------------------------------------------------------------------
printf '\n========================================\n'
printf ' %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
printf '========================================\n'

cat <<'MANUAL'

Still needs a human, because no script can observe them:

  1. Press the volume and playback keys.        Expect: volume changes; with
                                                something playing, it pauses.
  2. Press Print, then Shift+Print.             Expect: a file appears in your
                                                pictures directory; Shift+Print
                                                lets you drag a region first.
  3. Do something needing a password in a GUI   Expect: a password dialog.
     app, e.g. change a setting in pavucontrol
     that needs privileges.
  4. Open a terminal and run:  tail /dev/zero   Expect: it gets killed after a
                                                while and the desktop stays
                                                responsive throughout.
                                                Then: journalctl -u earlyoom

MANUAL

[[ $FAIL -eq 0 ]]
