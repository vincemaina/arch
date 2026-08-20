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

# grep -c rather than grep -q, deliberately. grep -q exits at the first match
# and closes the pipe; the writer then takes SIGPIPE and exits 141, and this
# script sets pipefail, so the pipeline reports failure while the thing being
# checked is perfectly fine. grep -c reads its input to the end, so there is no
# early close. This bit only ever passed because swapon's output is one line
# and it finished writing before grep could exit.
if [[ "$(swapon --show=NAME --noheadings 2>/dev/null | grep -c zram)" -gt 0 ]]; then
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

    # Deliberately not checked here: whether the polkit agent is registered with
    # polkitd. An earlier version inferred that from the agent's cgroup, on the
    # theory that a process under user@UID.service has no logind session to
    # register against. That was disproved - the agent registers fine from there
    # - so the check was reporting a failure on a working system. Registration
    # can only really be confirmed by asking for an authentication, which is in
    # the manual list below.
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

# The preset has to be able to produce the fallback at all. Listing it in
# PRESETS is not enough: mkinitcpio takes the path from fallback_image, and
# with that unset it skips the image with a warning and still exits 0. Checking
# only that a file exists passes on configuration that can never rebuild it.
for preset in /etc/mkinitcpio.d/*.preset; do
    [[ -e "$preset" ]] || continue
    grep -qE "^PRESETS=.*'fallback'" "$preset" || continue

    if grep -qE "^fallback_(image|uki)=" "$preset"; then
        pass "$(basename "$preset") lists the fallback and sets its destination"
    else
        fail "$(basename "$preset") lists the fallback preset but sets no fallback_image, so mkinitcpio skips it and exits 0"
    fi

    # Built with autodetect, the fallback carries modules only for the hardware
    # present when it was built - the hardware that may be why it is needed.
    if grep -qE '^fallback_options=.*-S[[:space:]]+[^"]*autodetect' "$preset"; then
        pass "$(basename "$preset") builds the fallback without autodetect"
    else
        fail "$(basename "$preset") does not skip autodetect for the fallback, so it is close to a copy of the default rather than a recovery image"
    fi
done

# An entry that references a missing image looks fine in the boot menu and
# fails only when chosen, which is the worst time to find out.
for img in /boot/initramfs-linux.img /boot/initramfs-linux-fallback.img; do
    if [[ -s "$img" ]]; then
        pass "$(basename "$img") exists ($(du -h "$img" | cut -f1))"
    else
        fail "$img is missing or empty, so any entry referencing it will not boot"
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
section "Wallpaper (TASK-3)"

# swaybg fails quietly when its image is missing: the output is simply left
# blank, which looks like a deliberately plain desktop rather than a fault.
wallpaper="$(grep -oE '^output \* bg [^ ]+' "$HOME/.config/sway/config.d/30-appearance.conf" 2>/dev/null | awk '{print $4}')"

if [[ -z "$wallpaper" ]]; then
    skip "no wallpaper configured"
elif [[ ! -s "$wallpaper" ]]; then
    fail "$wallpaper is configured as the background but is missing or empty"
elif ! command -v swaybg &>/dev/null; then
    fail "swaybg is not installed, so sway cannot draw a background at all"
elif pgrep -x swaybg >/dev/null; then
    pass "swaybg is running with $(basename "$wallpaper")"
else
    fail "swaybg is not running, so the background is not being drawn"
fi

# ----------------------------------------------------------------------
section "Graphics (TASK-26)"

# Whether the desktop is drawn by the GPU or by the CPU. The distinction is
# invisible until it is not: software rendering works, and then drops frames
# under load, which is the opposite of the goal here.
#
# grep -c rather than grep -q throughout: see the note on swapon above.
software="$(journalctl --user -b --no-pager 2>/dev/null | grep -ci 'llvmpipe\|swrast')"
virgl="$(journalctl -b -k --no-pager 2>/dev/null | grep -c '\[drm\] features:.*-virgl')"
virtio="$(journalctl -b -k --no-pager 2>/dev/null | grep -c 'virtio-vga\|virtio_gpu')"

if [[ "$software" -eq 0 ]]; then
    pass "no software-rendering fallback reported this session"
elif [[ "$virgl" -gt 0 ]]; then
    # Expected, and not a fault to fix from inside the guest: 3D has to be
    # enabled on the hypervisor side. virt-manager calls it Video virtio with
    # 3D acceleration, and it needs Display spice with OpenGL on.
    skip "software rendering, because the virtio GPU reports -virgl (3D off in the VM's configuration, not fixable from in here)"
elif [[ "$virtio" -gt 0 ]]; then
    skip "software rendering on a virtio GPU; check whether 3D acceleration is enabled on the host"
else
    fail "software rendering on what looks like real hardware - the GPU driver or Mesa is not doing its job, and this is a genuine problem rather than a VM artefact"
fi

section "Audio (TASK-41)"

if ! command -v wpctl &>/dev/null; then
    skip "wpctl not available"
elif ! vol="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)"; then
    skip "no default audio sink"
else
    # Above 1.0 is software amplification: it clips rather than usefully
    # increasing loudness, and the volume keys used to have no ceiling at all,
    # so a machine could be found sitting at 105% or very much worse.
    level="$(awk '{print $2}' <<<"$vol")"
    if awk -v v="$level" 'BEGIN { exit !(v <= 1.0) }'; then
        pass "sink volume is ${level} (at or below 100%)"
    else
        fail "sink volume is ${level}, above 100%; that is amplification and it clips. Press volume-down, which now clamps"
    fi
fi

section "Key remapping (TASK-40)"

# keyd remaps below xkb and below the console keymap, so this one check covers
# sway, the console, the greeter and XWayland at once. That is the reason it
# was chosen over setting xkb_options in four places that can drift apart.
if ! command -v keyd &>/dev/null; then
    fail "keyd is not installed, so left Alt and left Control are not swapped anywhere"
else
    # keyd check is a real gate - it exits non-zero on a config it cannot
    # parse - and a config that does not parse means no usable keyboard.
    if keyd check /etc/keyd/default.conf &>/dev/null; then
        pass "/etc/keyd/default.conf parses"
    else
        fail "/etc/keyd/default.conf does not parse; keyd would leave this machine without a keyboard"
    fi

    # Both directions, or the swap is a move: one key doubled and the other
    # function unreachable. layer(...) rather than a bare key assignment,
    # which emits the keycode without the modifier semantics.
    for want in "leftcontrol = layer(alt)" "leftalt = layer(control)"; do
        if grep -qF "$want" /etc/keyd/default.conf 2>/dev/null; then
            pass "maps ${want}"
        else
            fail "/etc/keyd/default.conf does not map ${want}"
        fi
    done

    if systemctl is-active --quiet keyd; then
        pass "keyd is running"
    else
        fail "keyd is not running, so the keyboard is unswapped despite the config"
    fi

    if systemctl is-enabled --quiet keyd 2>/dev/null; then
        pass "keyd is enabled at boot"
    else
        fail "keyd is not enabled, so the swap is lost at the next reboot"
    fi

    # The daemon can be running and still have grabbed nothing, which looks
    # identical from systemctl and leaves the keyboard unremapped.
    # Counted rather than tested with grep -q: see the note on swapon above.
    # journalctl writes plenty, so grep -q reliably closed the pipe under it and
    # this check reported that keyd had grabbed nothing while it was working.
    # Unique device ids, not match lines: keyd logs a match every time it
    # restarts, so counting lines would claim six keyboards where there is one.
    matched="$(journalctl -u keyd -b --no-pager 2>/dev/null \
        | grep "DEVICE: match" | awk '{print $4}' | sort -u | grep -c .)"
    if [[ "$matched" -gt 0 ]]; then
        pass "keyd grabbed $matched keyboard device(s)"
    else
        fail "keyd matched no input device this boot, so nothing is being remapped"
    fi
fi

section "Input (TASK-18)"

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    skip "not in a Wayland session"
elif ! command -v swaymsg &>/dev/null; then
    skip "swaymsg not available"
else
    # Asks the compositor what it actually applied, rather than trusting that
    # the file on disk took effect.
    inputs="$(swaymsg -t get_inputs 2>/dev/null)"

    for want in repeat_delay:250 repeat_rate:40; do
        name="${want%%:*}"
        expected="${want#*:}"
        got="$(grep -o "\"$name\": *[0-9]*" <<<"$inputs" | head -1 | grep -oE '[0-9]+$')"
        if [[ "$got" == "$expected" ]]; then
            pass "$name is $got"
        else
            fail "$name is ${got:-unreported}, expected $expected; reload sway with \$mod+Shift+c"
        fi
    done

    # environment.d is read when the user manager starts, so this stays wrong
    # until the next login even after a successful sync.
    if [[ "${XCURSOR_THEME:-}" == "Adwaita" ]]; then
        pass "XCURSOR_THEME is Adwaita (size ${XCURSOR_SIZE:-unset})"
    else
        fail "XCURSOR_THEME is ${XCURSOR_THEME:-unset}; XWayland apps will draw a different cursor. Needs a fresh login."
    fi
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
section "Shell (TASK-22)"

if ! command -v zsh &>/dev/null; then
    fail "zsh is not installed"
else
    login_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
    if [[ "$login_shell" == "$(command -v zsh)" ]]; then
        pass "login shell is $login_shell"
    else
        fail "login shell is $login_shell, not zsh"
    fi

    # A shell that takes noticeably long to appear is worse than a plain one.
    # Measured rather than assumed, because plugins are exactly what makes this
    # go wrong and the cost creeps up one addition at a time.
    start_ns="$(date +%s%N)"
    zsh -i -c exit >/dev/null 2>&1
    end_ns="$(date +%s%N)"
    startup_ms=$(( (end_ns - start_ns) / 1000000 ))

    if [[ $startup_ms -lt 200 ]]; then
        pass "interactive shell starts in ${startup_ms}ms"
    elif [[ $startup_ms -lt 400 ]]; then
        pass "interactive shell starts in ${startup_ms}ms (noticeable; worth watching)"
    else
        fail "interactive shell takes ${startup_ms}ms, which is felt every time a terminal opens"
    fi
fi

# ----------------------------------------------------------------------
section "Terminal config (TASK-28)"

# foot validates its own config and reports deprecated options, which is how a
# renamed section is meant to be caught - rather than by noticing a warning
# scrolling past every time a terminal opens.
if command -v foot &>/dev/null; then
    if foot_out="$(foot --check-config 2>&1)"; then
        if [[ -n "$foot_out" ]]; then
            fail "foot config has warnings:"
            sed 's/^/          /' <<<"$foot_out"
        else
            pass "foot config is valid with no deprecation warnings"
        fi
    else
        fail "foot rejected its config:"
        sed 's/^/          /' <<<"$foot_out"
    fi
else
    skip "foot not installed"
fi

# ----------------------------------------------------------------------
section "Dotfile references (TASK-28)"

# A config that includes a file which is not there fails silently: foot simply
# uses its default colours and says nothing. That is how the terminal came to
# have no colour scheme while appearing to be configured for one.

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/setup/dotfiles"
missing_refs=0
checked_refs=0

while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    checked_refs=$((checked_refs + 1))

    # A glob that matches nothing is legitimate - sway's include of
    # /etc/sway/config.d/* is fine on a machine with no drop-ins - so for those
    # only the containing directory has to exist.
    if [[ "$ref" == *[\*\?]* ]]; then
        if [[ -d "$(dirname "$ref")" ]]; then
            pass "$ref (directory exists; matching nothing is allowed)"
        else
            missing_refs=$((missing_refs + 1))
            fail "$ref is included by a dotfile but its directory does not exist"
        fi
    elif [[ -e "$ref" ]]; then
        pass "$ref exists"
    else
        missing_refs=$((missing_refs + 1))
        fail "$ref is included by a dotfile but does not exist"
    fi
done < <(
    grep -rhoE '^[[:space:]]*(include[[:space:]]*=[[:space:]]*|include[[:space:]]+)/[^[:space:]]+' \
        "$DOTFILES" 2>/dev/null |
        sed -E 's/^[[:space:]]*include[[:space:]]*=?[[:space:]]*//' |
        sort -u
)

if [[ $checked_refs -eq 0 ]]; then
    skip "no absolute include paths found in the dotfiles"
elif [[ $missing_refs -eq 0 ]]; then
    pass "every absolute path a dotfile includes exists"
fi

# An icon that has been lost in editing leaves an empty string, which looks
# exactly like a configured one in the file and renders as nothing on screen.
# The bar lost most of its icons this way without anything reporting it.
if empty_icons="$(grep -rnE '"(format-icons|format-muted|format-charging|format)"[^,]*""' "$DOTFILES" 2>/dev/null)"; then
    fail "icon strings that are empty, so they render as nothing:"
    sed 's/^/          /' <<<"$empty_icons"
else
    pass "no empty icon strings in the dotfiles"
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
