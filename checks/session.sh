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
elif ! systemctl --user is-active --quiet 'wayland-session@sway.target'; then
    # Check this first and stop. Without the session target nothing below can
    # have started, and reporting four separate failures obscures the single
    # cause. A plain `sway` gives a working compositor with no session layer
    # at all, and nothing on screen says so.
    fail "this session was not started through uwsm, so no session components are running"
    echo "        Launch it with:  uwsm start -- sway"
    echo "        Plain 'sway' gives a compositor with no bar, notifications,"
    echo "        idle handling or authentication agent, and looks fine."
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

    pass "wayland-session@sway.target is active (session started through uwsm)"

    # Session components are bound to the sway-specific target rather than
    # graphical-session.target, which every compositor reaches. Anything still
    # wanted by the generic target would start under a different desktop too.
    leaked="$(ls "$HOME/.config/systemd/user/graphical-session.target.wants" 2>/dev/null)"
    if [[ -n "$leaked" ]]; then
        fail "still enabled under graphical-session.target, so these would start under any compositor: ${leaked//$'\n'/ }"
    else
        pass "no session units are wanted by the generic graphical-session.target"
    fi

    # A running polkit agent is not the same as a registered one. The agent
    # registers itself against its own logind session, and a process under
    # user@UID.service may have no session to register against - in which case
    # it runs happily forever while polkit reports no agents at all.
    agent_pid="$(systemctl --user show polkit-agent --property=MainPID --value 2>/dev/null)"
    if [[ -n "$agent_pid" && "$agent_pid" != "0" && -r "/proc/$agent_pid/cgroup" ]]; then
        cgroup="$(cat "/proc/$agent_pid/cgroup")"
        if grep -q 'session-[0-9]*\.scope' <<<"$cgroup"; then
            pass "polkit agent is inside a logind session scope"
        else
            fail "polkit agent is outside any logind session scope, so it may not be registered with polkit; verify with: pkexec --disable-internal-agent true"
        fi
    else
        skip "could not locate the polkit agent process to check its session"
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
section "Login screen (TASK-15)"

# Replicates how ReGreet discovers sessions, so a greeter that would offer the
# wrong session is caught here rather than at the next boot. ReGreet derives its
# search path from XDG_DATA_DIRS, falling back to /usr/share alone; the first
# match for a given <type>/<filename> wins; and a Hidden or NoDisplay entry
# claims that name before being skipped, which is how a local entry suppresses a
# packaged one.

GREETD_CONF=/etc/greetd/config.toml

if [[ ! -r "$GREETD_CONF" ]]; then
    skip "cannot read $GREETD_CONF"
else
    greeter_cmd="$(grep -E '^command[[:space:]]*=' "$GREETD_CONF" | head -1 | cut -d= -f2-)"

    if [[ "$greeter_cmd" =~ XDG_DATA_DIRS=([^[:space:]\"]+) ]]; then
        parents="${BASH_REMATCH[1]}"
        pass "greeter searches $parents"
    else
        parents="/usr/share"
        fail "greeter sets no XDG_DATA_DIRS, so it only scans /usr/share and will miss local session entries"
    fi

    declare -A claimed=()
    offered=0
    non_uwsm=0

    IFS=':' read -ra parent_dirs <<<"$parents"
    for parent in "${parent_dirs[@]}"; do
        for kind in xsessions wayland-sessions; do
            dir="$parent/$kind"
            [[ -d "$dir" ]] || continue
            for entry in "$dir"/*.desktop; do
                [[ -e "$entry" ]] || continue
                key="$kind/$(basename "$entry")"
                [[ -n "${claimed[$key]:-}" ]] && continue
                claimed[$key]=1
                if grep -qiE '^(Hidden|NoDisplay)[[:space:]]*=[[:space:]]*true' "$entry"; then
                    continue
                fi
                name="$(grep -m1 '^Name=' "$entry" | cut -d= -f2-)"
                exec_cmd="$(grep -m1 '^Exec=' "$entry" | cut -d= -f2-)"
                offered=$((offered + 1))
                if [[ "$exec_cmd" == *uwsm* ]]; then
                    pass "offers \"$name\" -> $exec_cmd"

                    # An Exec that names a .desktop ID is resolved through the
                    # XDG hierarchy, where /usr/local/share precedes /usr/share.
                    # If that lands on one of our own Hidden masking entries the
                    # session refuses to start and the login screen loops, with
                    # no way in. This locked a machine out once.
                    if [[ "$exec_cmd" =~ ([A-Za-z0-9._+-]+\.desktop) ]]; then
                        ref="${BASH_REMATCH[1]}"
                        resolved=""
                        for p in /usr/local/share /usr/share; do
                            for k in xsessions wayland-sessions; do
                                if [[ -z "$resolved" && -e "$p/$k/$ref" ]]; then
                                    resolved="$p/$k/$ref"
                                fi
                            done
                        done
                        if [[ -z "$resolved" ]]; then
                            fail "  ...but $ref resolves to nothing, so the session cannot start"
                        elif grep -qiE '^(Hidden|NoDisplay)[[:space:]]*=[[:space:]]*true' "$resolved"; then
                            fail "  ...but $ref resolves to $resolved, which is hidden; the session will refuse to start and bounce back to the login screen"
                        else
                            pass "  and $ref resolves to $resolved"
                        fi
                    fi
                else
                    non_uwsm=$((non_uwsm + 1))
                    fail "offers \"$name\" -> $exec_cmd, which bypasses uwsm and yields a session with no components"
                fi
            done
        done
    done

    if [[ $offered -eq 0 ]]; then
        fail "the greeter would offer no sessions at all"
    elif [[ $non_uwsm -eq 0 ]]; then
        pass "every session the greeter offers goes through uwsm"
    fi
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
  3. Run:  pkexec --disable-internal-agent true  Expect: a graphical password
                                                dialog. Entering your password
                                                exits silently; cancelling says
                                                "Request dismissed". Either one
                                                proves the polkit agent is wired
                                                up. Without the flag, pkexec
                                                uses its own text prompt and
                                                tells you nothing about the
                                                graphical agent.
  4. Open a terminal and run:  tail /dev/zero   Expect: it gets killed after a
                                                while and the desktop stays
                                                responsive throughout.
                                                Then: journalctl -u earlyoom

MANUAL

[[ $FAIL -eq 0 ]]
