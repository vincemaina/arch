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

# The repository this check is running from, derived from the script rather than
# the working directory - session.sh is meant to be runnable from anywhere.
CHECKS_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

    # zswap must be OFF, or the zram device above is not the compressed swap -
    # it is a fallback behind a smaller pool that catches almost everything.
    #
    # This is not hypothetical tidiness. Measured before it was turned off:
    # 920,911 pages compressed into zswap and 9,415 - one percent - ever
    # reached zram, which peaked at 7 MiB of a 1,951 MiB device. Every setting
    # TASK-9 chose was correctly applied and doing almost nothing, and no check
    # noticed for as long as this section has existed. The Arch kernel enables
    # zswap by default, so this reverts the moment /etc/tmpfiles.d/zswap.conf
    # stops being applied.
    zswap_state="$(cat /sys/module/zswap/parameters/enabled 2>/dev/null)"
    if [[ -z "$zswap_state" ]]; then
        skip "this kernel has no zswap parameter, so nothing sits in front of zram"
    elif [[ "$zswap_state" == "N" ]]; then
        pass "zswap is off, so zram is the compressed swap rather than a fallback"
    else
        fail "zswap is enabled, so it compresses into its own pool first and zram only sees the writeback - run ./sync.sh, or reboot if it has already run"
    fi

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
    # The units the repository actually enables, read from the committed
    # symlinks rather than listed here.
    #
    # This was a hardcoded four - waybar, mako, swayidle, polkit-agent - while
    # eight were enabled. autotiling and greeting had been added and never
    # joined it, and the cliphist watchers would have been the third and fourth
    # to slip past. A list of things to check, maintained by hand beside the
    # list of things that exist, drifts in exactly one direction: the check
    # stays green while covering less.
    #
    # Read from the repository, not from ~/.config, so a unit that failed to
    # apply is a missing unit rather than a shorter list.
    mapfile -t SESSION_UNITS < <(
        find "$CHECKS_REPO/setup/dotfiles/dot_config/systemd/user/wayland-session@sway.target.wants" \
             -maxdepth 1 -name 'symlink_*.service' -printf '%f\n' 2>/dev/null |
        sed 's/^symlink_//; s/\.service$//' | sort
    )
    # Fall back to the historical list if that directory is unreadable, so this
    # degrades to what it used to do rather than to checking nothing.
    [[ ${#SESSION_UNITS[@]} -gt 0 ]] ||
        SESSION_UNITS=(waybar mako swayidle polkit-agent)

    for unit in "${SESSION_UNITS[@]}"; do
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
section "Themes (TASK-46)"

# The themes live in the repository; which one is selected lives on the machine,
# in chezmoi's config under [data]. Everything below asks chezmoi rather than
# reading themes.toml directly, so what is checked is what the templates
# actually see - reading the TOML here would be a second implementation of the
# merge, and the two would drift.
THEME_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/setup"

if ! command -v chezmoi &>/dev/null; then
    skip "chezmoi is not installed, so themes cannot be checked"
elif ! theme_data="$(chezmoi --source "$THEME_SOURCE" data 2>/dev/null)"; then
    fail "chezmoi could not read $THEME_SOURCE, so no template can render"
else
    # One python pass reporting one line per finding, because starting an
    # interpreter per assertion to re-parse the same JSON is most of the runtime
    # of this section.
    # The JSON goes via a file rather than a pipe. `python3 -` reads its
    # program from stdin, and a heredoc is stdin - so piping the data in as
    # well silently loses it, and json.load sees an empty string. That is what
    # the first version of this did.
    theme_json="$(mktemp)"
    printf '%s' "$theme_data" > "$theme_json"

    while IFS='|' read -r verdict message; do
        case "$verdict" in
            pass) pass "$message" ;;
            fail) fail "$message" ;;
            skip) skip "$message" ;;
        esac
    done < <(python3 - "$THEME_SOURCE" "$theme_json" <<'PYEOF'
import json, os, sys

source, theme_json = sys.argv[1], sys.argv[2]
with open(theme_json) as fh:
    data = json.load(fh)
themes = data.get("themes") or {}
selected = data.get("theme")
out = []

def say(verdict, message):
    out.append(f"{verdict}|{message}")

if not themes:
    say("fail", "themes.toml defines no themes")
elif selected not in themes:
    say("fail", f"the selected theme {selected!r} is not one of: {', '.join(themes)}")
else:
    say("pass", f"selected theme {selected!r} is one of {len(themes)}: {', '.join(sorted(themes))}")

    # A template reads one theme's keys. A theme missing one of them is not a
    # problem until it is selected, at which point every apply fails with a
    # template error - so it is checked for every theme, not just this one.
    reference = {k for k in themes[selected] if k != "term"}
    reference_term = set(themes[selected].get("term", {}))
    incomplete = []
    for name, palette in themes.items():
        missing = reference - set(palette)
        missing |= {f"term.{k}" for k in reference_term - set(palette.get("term", {}))}
        if missing:
            incomplete.append(f"{name} is missing {', '.join(sorted(missing))}")
    if incomplete:
        for problem in incomplete:
            say("fail", problem)
    else:
        say("pass", f"all {len(themes)} themes define the same keys")

    # Two contrast rules that were learned by breaking them. `muted` carries the
    # cpu and memory readouts; `text` is the workspace number sitting on a disc
    # filled with `tertiary`, which a first draft of the ember theme left at
    # 2.76:1 - legible in the file, barely there on screen.
    def luminance(value):
        value = value.lstrip("#")
        channels = [int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
        channels = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
                    for c in channels]
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]

    def contrast(a, b):
        high, low = sorted((luminance(a), luminance(b)), reverse=True)
        return (high + 0.05) / (low + 0.05)

    # The editor's colours are checked here too, and were not until the editor
    # started using them. A comment sitting at the conventional near-invisible
    # grey is the single most common thing wrong with a dark colourscheme, and
    # arch.lua.tmpl said this file enforced a floor on it while this file had
    # never heard of it - a comment describing a hypothesis as an outcome, which
    # is the failure mode CLAUDE.md names.
    #
    # Comments come from term.bright_black, hence the dotted lookup. The
    # diagnostic severities reuse the same role colours as the bar, so an error
    # in the editor is the red of an urgent notification - which means checking
    # them here covers both.
    RULES = [
        ("muted", "bg", 4.5, "the cpu and memory readouts against the background"),
        ("text", "tertiary", 3.5, "the workspace number against its own disc"),
        ("term.bright_black", "bg", 4.5, "comments in the editor"),
        ("urgent", "bg", 4.5, "error diagnostics in the editor"),
        ("warning", "bg", 4.5, "warning diagnostics in the editor"),
        ("info", "bg", 4.5, "hint and info diagnostics in the editor"),
    ]

    def colour(palette, path):
        # The sixteen ANSI colours are stored without a leading #, unlike the
        # roles - the terminal wants them bare. Everything doing arithmetic on
        # them has to put it back.
        if "." in path:
            section, key = path.split(".")
            return "#" + palette[section][key].lstrip("#")
        return palette[path]

    poor = []
    for name, palette in themes.items():
        for fg, bg, floor, what in RULES:
            ratio = contrast(colour(palette, fg), colour(palette, bg))
            if ratio < floor:
                poor.append(f"{name}: {fg} on {bg} is {ratio:.2f}:1, under {floor}:1 - {what}")
    if poor:
        for problem in poor:
            say("fail", problem)
    else:
        say("pass", "every theme keeps its readouts above the contrast floor")

    # No theme ships an image any more: they are generated on the machine from
    # the palette and cached. Three themes at one image each was already 7.8M of
    # tracked PNG, and the arrangement this replaced would have grown by about
    # 10M per theme - so a tracked image here is a regression worth catching
    # rather than a stylistic preference.
    generator = os.path.join(source, "dotfiles", "dot_local", "bin",
                             "executable_wallpaper")
    if not os.access(generator, os.X_OK):
        say("fail", "the wallpaper generator is missing or not executable, so no "
                    "theme can produce a background")
    else:
        say("pass", "the wallpaper generator ships and is executable")

    tracked = []
    for root, _, files in os.walk(os.path.join(source, "dotfiles")):
        tracked += [f for f in files if f.lower().endswith((".png", ".jpg", ".jpeg"))]
    if tracked:
        say("fail", f"{len(tracked)} image(s) are tracked in setup/dotfiles/ "
                    f"({', '.join(sorted(tracked)[:3])}...) - wallpapers are "
                    f"generated now, and committing them grows with every theme")
    else:
        say("pass", "no wallpaper images are tracked; a new theme costs no bytes")

    # The one that catches a switch that only half happened: the theme and style
    # selected in the config against the image swaybg is actually displaying.
    # These disagree when something was applied without the session reloading.
    chosen = data.get("wallpaper")
    style = chosen.get(selected, "mesh") if isinstance(chosen, dict) else "mesh"
    running = ""
    try:
        with os.popen("pgrep -a swaybg 2>/dev/null") as fh:
            for line in fh:
                parts = line.split()
                if "-i" in parts:
                    running = parts[parts.index("-i") + 1]
    except OSError:
        pass

    expected = (style if style.startswith("/")
                else os.path.expanduser(
                    f"~/.local/share/wallpapers/{selected}-{style}.png"))
    if not running:
        say("skip", "swaybg is not running, so the live theme cannot be confirmed")
    elif running != expected:
        say("fail", f"selected theme is {selected} in {style}, which is "
                    f"{os.path.basename(expected)}, but swaybg is showing "
                    f"{os.path.basename(running)} - the session was not reloaded")
    elif not os.path.isfile(running):
        say("fail", f"swaybg was told to show {os.path.basename(running)}, which "
                    f"does not exist - run 'wallpaper --regenerate'")
    else:
        say("pass", f"the desktop is showing {selected} in the {style} style")

print("\n".join(out))
PYEOF
    )
    rm -f "$theme_json"
fi

# The reload script is what makes a switch visible rather than merely written,
# and run_onchange_ decides to re-run it by comparing the rendered script. The
# two lines carrying the theme name and the palette hash are therefore what
# triggers it at all - they read like comments and are not.
reload_template="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/setup/dotfiles/run_onchange_after_reload-theme.sh.tmpl"
if [[ ! -f "$reload_template" ]]; then
    fail "nothing reloads the session after a theme change"
elif [[ "$(grep -c '{{ .theme }}\|dig "wallpaper"\|sha256sum' "$reload_template")" -lt 3 ]]; then
    fail "$(basename "$reload_template") no longer embeds the theme name, the wallpaper style and the palette hash, so chezmoi will not re-run it in every case that needs it"
else
    pass "the reload script re-runs on a theme switch, a wallpaper change and a colour edit"
fi

# ----------------------------------------------------------------------
section "Bar interaction (TASK-53)"

# Two invisible failures live here, and both have already happened elsewhere in
# this repository.
#
# A click command that cannot be found does nothing and reports nothing: waybar
# runs as a systemd user service whose PATH is /usr/bin and friends, and
# ~/.local/bin is put on PATH by .zshrc, which applies to interactive shells
# only. So a bare command name works when tested in a terminal and is silently
# inert from the bar. The desktop entries learned this first; the bar learned it
# again.
#
# And a window opened without a matching floating rule tiles instead, shoving
# the workspace around for something being looked at for ten seconds. The app_id
# ties three separate files together and nothing else checks that they agree.
bar_check="$(mktemp)"
cat > "$bar_check" <<'BARCHECK_EOF'
import json
import os
import re
import shutil
import sys

# Emits "verdict|message" lines for session.sh to turn into PASS/FAIL.
home = os.path.expanduser("~")
config_path = os.path.join(home, ".config", "waybar", "config.jsonc")
sway_dir = os.path.join(home, ".config", "sway", "config.d")

out = []


def say(verdict, message):
    out.append(f"{verdict}|{message}")


if not os.path.isfile(config_path):
    say("skip", "waybar is not configured on this machine")
    print("\n".join(out))
    sys.exit(0)

raw = open(config_path).read()
config = json.loads(re.sub(r"^\s*//.*$", "", raw, flags=re.M))

# waybar's PATH, taken from the running process rather than assumed. This is the
# whole point of the check: ~/.local/bin is put on PATH by .zshrc, which applies
# to interactive shells and to nothing else, so a bare command name in an
# on-click works when tested in a terminal and does nothing at all from the bar.
# waybar reports nothing when a click command cannot be found.
waybar_path = None
for pid in os.listdir("/proc"):
    if not pid.isdigit():
        continue
    try:
        with open(f"/proc/{pid}/comm") as fh:
            if fh.read().strip() != "waybar":
                continue
        with open(f"/proc/{pid}/environ") as fh:
            env = dict(p.split("=", 1) for p in fh.read().split("\0") if "=" in p)
        waybar_path = env.get("PATH")
        break
    except OSError:
        continue

search_path = waybar_path or "/usr/local/sbin:/usr/local/bin:/usr/bin"

actions = []
for name, body in config.items():
    if not isinstance(body, dict):
        continue
    for key, command in body.items():
        if key.startswith("on-click") or key.startswith("on-scroll"):
            actions.append((name, key, command))

unresolved = []
for name, key, command in actions:
    binary = command.split()[0]
    if binary.startswith("/"):
        if not os.access(binary, os.X_OK):
            unresolved.append(f"{name}.{key} runs {binary}, which is not executable")
    elif not shutil.which(binary, path=search_path):
        unresolved.append(
            f"{name}.{key} runs bare '{binary}', which is not on waybar's PATH "
            f"- it will do nothing and say nothing")

if not actions:
    say("fail", "no module in the bar does anything when clicked")
elif unresolved:
    for problem in unresolved:
        say("fail", problem)
else:
    where = "on waybar's own PATH" if waybar_path else "on the default PATH"
    say("pass", f"all {len(actions)} click actions resolve {where}")

# Every module the bar displays should respond to a click. Two are excluded and
# both are deliberate: sway/mode only exists while a mode is active, and
# idle_inhibitor toggles itself without needing a command.
displayed = (config.get("modules-left", []) + config.get("modules-center", [])
             + config.get("modules-right", []))
BUILT_IN = {"sway/workspaces", "sway/mode", "idle_inhibitor", "mpris"}
inert = []
for name in displayed:
    if name in BUILT_IN:
        continue
    body = config.get(name, {})
    if not any(k.startswith("on-") or k == "format-alt" for k in body):
        inert.append(name)
if inert:
    say("fail", f"nothing happens when you click: {', '.join(inert)}")
else:
    say("pass", f"every one of the {len(displayed)} modules responds to a click")

# The app_id coupling. sway-toggle-window finds a window by app_id, the command
# sets that app_id, and a for_window rule floats it. Nothing enforces that the
# three agree, and when they do not the window tiles instead - shoving the
# workspace around for something being looked at for ten seconds.
rules = ""
if os.path.isdir(sway_dir):
    for entry in sorted(os.listdir(sway_dir)):
        rules += open(os.path.join(sway_dir, entry)).read()

# Both the direct calls in the bar's config and the indirect ones: clicking the
# clock runs ~/.local/bin/calendar, which calls the toggle itself, so the app_id
# never appears in the waybar config at all.
searched = raw
bin_dir = os.path.join(home, ".local", "bin")
if os.path.isdir(bin_dir):
    for entry in sorted(os.listdir(bin_dir)):
        try:
            searched += open(os.path.join(bin_dir, entry)).read()
        except (OSError, UnicodeDecodeError):
            continue

# Comments are not invocations.
#
# This scans source text for calls to sway-toggle-window and takes the next
# token as the app_id. A helper that merely MENTIONS the toggle - explaining in
# a comment why it does NOT use it - had its next token, a bare "#", read as an
# app_id, and this failed asking why nothing floats a window called "#". The
# scripting-traps entry "a replace can match a comment about the section", one
# layer up: here it is a check matching a comment about the thing it checks.
#
# Whole comment lines only, rather than everything after a "#" anywhere: a
# click command can legitimately contain one, and cutting there would silently
# shorten the command being examined.
searched = "\n".join(
    line for line in searched.splitlines()
    if not line.lstrip().startswith(("#", "//"))
)

toggled = set(re.findall(r"sway-toggle-window[\"']?\s+(\S+)", searched))
toggled = {a.strip('"\'\\') for a in toggled if not a.startswith(("-", "$", "<"))}
unfloated = [
    app for app in sorted(toggled)
    if not re.search(rf'for_window\s*\[app_id="{re.escape(app)}"\]\s*floating enable', rules)
]
mismatched = [
    app for app in sorted(toggled)
    if f"--app-id={app}" not in searched
]

if not toggled:
    say("skip", "no module opens a window, so there is no app_id to check")
elif unfloated:
    say("fail", f"opened by the bar but no rule floats it: {', '.join(unfloated)} "
                f"- it will tile and shove the workspace around")
elif mismatched:
    say("fail", f"toggled by app_id but the command never sets it: {', '.join(mismatched)}")
else:
    say("pass", f"every window the bar opens ({', '.join(sorted(toggled))}) is "
                f"floated by a matching rule")

print("\n".join(out))
BARCHECK_EOF

while IFS='|' read -r verdict message; do
    case "$verdict" in
        pass) pass "$message" ;;
        fail) fail "$message" ;;
        skip) skip "$message" ;;
    esac
done < <(python3 "$bar_check")
rm -f "$bar_check"

# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
section "Terminal windows (TASK-88)"

# The app_id ties two files together, and nothing else notices when they
# disagree - the window simply tiles.
#
# `terminal` sets an app_id for its floating windows and 40-window-rules.conf
# has to float and centre it. This used to also guard against a second,
# regressed app_id - `terminal --greeting` shared `floating-term`'s id until
# TASK-88 split them, because sharing it meant a selector like
# `swaymsg [app_id=greeting] kill` matched most of the terminals on the
# machine, including the one being worked in. TASK-113 removed the greeting
# terminal outright, so that risk cannot recur and the guard went with it.
while IFS='|' read -r verdict message; do
    [[ -z "$verdict" ]] && continue
    case "$verdict" in
        pass) pass "$message" ;;
        fail) fail "$message" ;;
        skip) skip "$message" ;;
    esac
done < <(python3 - "$HOME/.local/bin/terminal" \
                  "$HOME/.config/sway/config.d/40-window-rules.conf" <<'TERMCHECK_EOF'
import re, sys, pathlib

term_path, rules_path = (pathlib.Path(p) for p in sys.argv[1:3])
out = []
def say(verdict, message): out.append(f"{verdict}|{message}")

if not term_path.exists():
    say("skip", "the terminal helper is not installed")
elif not rules_path.exists():
    say("skip", "the window rules are not installed")
else:
    term = term_path.read_text()
    rules = rules_path.read_text()
    set_ids = set(re.findall(r"--app-id=([\w-]+)", term))
    floated = set(re.findall(r'for_window\s*\[app_id="([\w-]+)"\]\s*floating enable', rules))
    centred = set(re.findall(r'for_window\s*\[app_id="([\w-]+)"\]\s*move position center', rules))

    if not set_ids:
        say("fail", "the terminal helper sets no app_id, so no rule can match it")
    else:
        missing_float = sorted(set_ids - floated)
        missing_centre = sorted(set_ids - centred)
        if missing_float:
            say("fail", f"terminal sets app_id {', '.join(missing_float)} but no rule floats it")
        elif missing_centre:
            say("fail", f"terminal sets app_id {', '.join(missing_centre)} but no rule centres it")
        else:
            say("pass", f"every app_id the terminal sets ({', '.join(sorted(set_ids))}) is floated and centred by a matching rule")

print("\n".join(out))
TERMCHECK_EOF
)

# ----------------------------------------------------------------------
section "Opening files (TASK-47)"

# Choosing a file in the launcher has to end with a window. Every link in that
# chain fails silently, and one of them was broken for months without anyone
# noticing: the association from inode/directory to yazi was declared, believed,
# and opened nothing at all.
#
# The chain is: rofi hands the path to `gio open`; gio resolves the mime type to
# a desktop entry; if that entry is Terminal=true, glib looks for a program
# called xdg-terminal-exec on PATH to run it in. A break anywhere produces no
# error, because there is no terminal to print one to.

if ! command -v gio &>/dev/null; then
    skip "gio is not installed, so the launcher cannot open anything"
else
    # rofi must ask gio rather than xdg-open. xdg-open takes its generic path on
    # sway - a desktop it does not recognise - and that path executes the
    # desktop entry's command directly, ignoring Terminal=true, so the editor
    # starts with no tty and dies.
    rofi_config="$HOME/.config/rofi/config.rasi"
    if [[ ! -f "$rofi_config" ]]; then
        skip "rofi is not configured, so the file finder cannot be checked"
    elif grep -A3 'recursivebrowser' "$rofi_config" | grep -q 'command:.*gio open'; then
        pass "the file finder opens files with gio, which honours Terminal=true"
    else
        fail "the file finder does not use 'gio open' - xdg-open ignores Terminal=true on sway, so choosing a file in the launcher will do nothing"
    fi
fi

# glib looks this up BY NAME on PATH and there is nowhere to give it an absolute
# path - the one case the absolute-path habit that fixes everything else here
# cannot cover. Which is why it is installed to /usr/local/bin rather than to
# ~/.local/bin: the latter is not on the session PATH, and putting it there
# through environment.d did not work, so the helper existed and was never found.
#
# Checked against the session's PATH rather than this shell's. An interactive
# shell has ~/.local/bin from .zshrc, so a check against $PATH here would pass
# while every launcher stayed broken.
xte="$(command -v xdg-terminal-exec 2>/dev/null || true)"
session_path="$(systemctl --user show-environment 2>/dev/null | sed -n 's/^PATH=//p')"

if [[ -z "$xte" ]]; then
    fail "xdg-terminal-exec is not installed, so every Terminal=true entry - the editor, the file manager - opens nothing. Run ./sync.sh"
elif [[ -z "$session_path" ]]; then
    skip "no user session to confirm xdg-terminal-exec is reachable from"
else
    reachable=false
    while IFS= read -r dir; do
        [[ -x "$dir/xdg-terminal-exec" ]] && reachable=true && break
    done < <(printf '%s' "$session_path" | tr ':' '\n')
    if $reachable; then
        pass "xdg-terminal-exec is at $xte, on the session's own PATH"
    else
        fail "xdg-terminal-exec exists at $xte but is not on the session PATH, so nothing launched from the bar or launcher can find it"
    fi
fi

# An association pointing at a desktop entry that does not exist resolves
# cleanly and then does nothing, which is the shape of the yazi bug.
missing_handlers=""
for pair in "text/plain:an ordinary text file" \
            "text/x-shellscript:a shell script" \
            "application/json:a JSON file" \
            "inode/directory:a directory"; do
    mime="${pair%%:*}"
    what="${pair#*:}"
    handler="$(xdg-mime query default "$mime" 2>/dev/null)"
    if [[ -z "$handler" ]]; then
        missing_handlers+="  nothing opens $what ($mime)"$'\n'
        continue
    fi
    # No pipe, and `|| true`. `grep -q` closes the pipe at the first match and
    # find exits 141 under pipefail; and find exits 1 for a missing directory -
    # /usr/local/share/applications does not exist here - even when it found
    # what it was asked for. Between them, an entry in the LAST directory
    # searched was reported as not installed while sitting right there.
    found_handler="$(find /usr/share/applications /usr/local/share/applications \
                          "$HOME/.local/share/applications" \
                          -maxdepth 1 -name "$handler" -print -quit 2>/dev/null || true)"
    if [[ -z "$found_handler" ]]; then
        missing_handlers+="  $what opens with $handler, which is not installed"$'\n'
    fi
done
if [[ -n "$missing_handlers" ]]; then
    fail "some file types open nothing:"$'\n'"${missing_handlers%$'\n'}"
else
    pass "text, shell scripts, JSON and directories each open with an installed application"
fi

# Distinguishing "not configured" from "configured but not yet in effect"
# matters, because they need different things doing. environment.d is read when
# the user manager starts, so a value added there is correct on disk and absent
# from the running session until the next login - and telling someone their
# configuration is missing when it is merely pending sends them to fix a file
# that is already right.
declared_editor="$(sed -n 's/^EDITOR=//p' "$HOME/.config/environment.d/"*.conf 2>/dev/null | tail -1)"
if [[ -n "${EDITOR:-}" ]] && command -v "${EDITOR%% *}" &>/dev/null; then
    pass "EDITOR is $EDITOR, so git and systemctl edit agree with the launcher"
elif [[ -n "$declared_editor" ]] && command -v "${declared_editor%% *}" &>/dev/null; then
    skip "EDITOR is set to $declared_editor in environment.d but not in this session - log out and in"
elif [[ -n "$declared_editor" ]]; then
    fail "EDITOR is set to '$declared_editor' in environment.d, which is not installed"
else
    fail "EDITOR is unset, so git and systemctl edit fall back to their own default rather than the chosen editor"
fi

# The GTK accessibility bridge, suppressed - and BOTH variables are required.
#
# GTK3 honours NO_AT_BRIDGE and ignores GTK_A11Y; GTK4 is the other way round.
# Measured on this machine rather than taken from documentation, because either
# one alone is a half fix that looks exactly like a whole one: the session goes
# on activating at-spi from whichever toolkit was not covered, and nothing says
# so. Hence checking for two, not for either.
#
# What it buys: at-spi2-registryd was D-Bus activated into app.slice, which is
# not bound to wayland-session@sway.target, so one was left behind by every
# login and they accumulated until reboot. Nothing here uses a screen reader.
# TASK-95.
#
# Same pending-login distinction as EDITOR above: environment.d is read when the
# user manager starts, so declared-but-not-live is a skip rather than a failure.
declared_a11y="$(cat "$HOME/.config/environment.d/"*.conf 2>/dev/null |
    grep -c -E '^(NO_AT_BRIDGE=1|GTK_A11Y=none)$' || true)"
live_a11y="$(systemctl --user show-environment 2>/dev/null |
    grep -c -E '^(NO_AT_BRIDGE|GTK_A11Y)=' || true)"
if [[ "$declared_a11y" -lt 2 ]]; then
    fail "the GTK accessibility bridge is not suppressed: environment.d must set BOTH NO_AT_BRIDGE=1 (GTK3) and GTK_A11Y=none (GTK4) - either alone leaves half the session activating at-spi"
elif [[ "$live_a11y" -eq 2 ]]; then
    pass "NO_AT_BRIDGE and GTK_A11Y are both in this session, so no GTK application asks for the accessibility bus"
else
    skip "the accessibility bridge is suppressed in environment.d but not in this session - log out and in"
fi

# ----------------------------------------------------------------------
section "Editor (TASK-24)"

if ! command -v nvim &>/dev/null; then
    skip "neovim is not installed"
elif [[ ! -f "$HOME/.config/nvim/init.lua" ]]; then
    fail "neovim has no configuration, so it starts as a bare editor"
else
    # Loading it is the check. A Lua file that parses can still throw at
    # runtime - the treesitter guard here did exactly that, looking correct in
    # the file and printing a stack trace on every python file opened.
    nvim_errors="$(nvim --headless -c quit 2>&1 | head -3)"
    if [[ -n "$nvim_errors" ]]; then
        fail "neovim prints errors on startup: $nvim_errors"
    else
        pass "neovim loads its configuration without errors"
    fi

    # Opening a file of each kind, because the failure above only appeared on a
    # FileType event and a bare start does not fire one.
    editor_probe="$(mktemp -d)"
    : > "$editor_probe/probe.py"; : > "$editor_probe/probe.md"; : > "$editor_probe/probe.sql"
    probe_errors=""
    for f in "$editor_probe"/probe.*; do
        out="$(nvim --headless "$f" -c quit 2>&1 | head -2)"
        [[ -n "$out" ]] && probe_errors+="  ${f##*/}: ${out}"$'\n'
    done
    rm -rf "$editor_probe"
    if [[ -n "$probe_errors" ]]; then
        fail "opening a file errors:"$'\n'"${probe_errors%$'\n'}"
    else
        pass "opening python, markdown and sql files produces no errors"
    fi

    # Every file gets SOME highlighting - the invariant that actually matters.
    #
    # The check above only looks for errors, and this failed without one:
    # installing a parser made vim.treesitter.start() succeed, which DISABLES
    # regex syntax highlighting, and Arch keeps the highlight queries in
    # /usr/share/tree-sitter rather than on nvim's runtimepath - so python files
    # opened completely grey and nothing said why. Worse than before the parser
    # was installed, and the checks were green throughout.
    #
    # So this asserts the thing a person would notice: treesitter is on with a
    # query, or vim's own syntax is. Never neither.
    hl_probe="$(mktemp -d)"
    printf 'import os\n' > "$hl_probe/p.py"
    printf 'const a = 1;\n' > "$hl_probe/p.js"
    printf '#!/bin/bash\necho hi\n' > "$hl_probe/p.sh"
    printf '# Title\n' > "$hl_probe/p.md"
    unhighlighted=""
    for f in "$hl_probe"/p.*; do
        # Treesitter being ACTIVE is not the same as treesitter highlighting
        # anything: with a parser and no query, highlighter.active is still set
        # and the file is blank. A first version of this check tested exactly
        # that and passed while the bug was reintroduced. So the query has to be
        # confirmed too.
        result="$(nvim --headless "$f" -c 'lua
local b = vim.api.nvim_get_current_buf()
local ts = false
if vim.treesitter.highlighter.active[b] ~= nil then
  local lang = vim.treesitter.language.get_lang(vim.bo.filetype)
  local ok, query = pcall(vim.treesitter.query.get, lang, "highlights")
  ts = ok and query ~= nil
end
local regex = vim.b.current_syntax ~= nil
io.write((ts or regex) and "ok" or "none")' -c quit 2>/dev/null)"
        [[ "$result" == "ok" ]] || unhighlighted+="${f##*/} "
    done
    rm -rf "$hl_probe"
    if [[ -n "$unhighlighted" ]]; then
        fail "these open with no highlighting at all: ${unhighlighted}- a parser without its query disables regex syntax and replaces it with nothing"
    else
        pass "python, javascript, shell and markdown all open highlighted"
    fi

    # The editor follows the theme, and lets the terminal through.
    #
    # Checked against the selected theme's actual values rather than "a
    # colorscheme is loaded", because loading the wrong one would pass that.
    theme_fg="$(chezmoi --source "$THEME_SOURCE" data 2>/dev/null |
        python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["themes"][d["theme"]]["text"].lstrip("#").lower())' 2>/dev/null)"
    editor_colours="$(nvim --headless -c 'lua
local n = vim.api.nvim_get_hl(0, { name = "Normal" })
io.write(string.format("%s %s %s", tostring(vim.g.colors_name),
  n.fg and string.format("%06x", n.fg) or "none",
  n.bg and "opaque" or "transparent"))' -c quit 2>/dev/null)"
    read -r cs_name cs_fg cs_bg <<<"$editor_colours"

    if [[ "$cs_name" != "arch" ]]; then
        fail "the editor is using the '$cs_name' colourscheme, not the generated one"
    elif [[ -n "$theme_fg" && "$cs_fg" != "$theme_fg" ]]; then
        fail "the editor's foreground is #$cs_fg but the selected theme's text is #$theme_fg - it is not following the theme"
    else
        pass "the editor uses the selected theme's colours"
    fi

    if [[ "$cs_bg" == "transparent" ]]; then
        pass "the editor has no background of its own, so the terminal shows through"
    else
        fail "the editor paints its own background, so it will not match the other terminal tools"
    fi

    # Every keybinding was chosen, and a description is the proof.
    #
    # Neovim ships 87 global mappings before any configuration, and none of them
    # was chosen - which is the opposite of how sway's bindings work here, where
    # the full table is printed and a duplicate fails. Those are deleted unless
    # explicitly kept, and the enforceable half is this: a description is
    # something a person wrote, so a mapping without one arrived without being
    # chosen. A plugin adding its own defaults fails this check.
    #
    # <Plug> mappings are excluded because they cannot be typed - they are
    # internal targets other mappings point at, not shortcuts anyone can press.
    undescribed="$(nvim --headless -c 'lua
local out = {}
for _, mode in ipairs({"n","i","v","x","o","s","c","t"}) do
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    if not m.lhs:match("^<Plug>") and (m.desc == nil or m.desc == "") then
      out[#out+1] = mode .. " " .. m.lhs
    end
  end
end
io.write(table.concat(out, ", "))' -c quit 2>/dev/null)"
    if [[ -n "$undescribed" ]]; then
        fail "editor keybindings with no description, so nobody chose them: $undescribed"
    else
        pass "every editor keybinding carries a description, so all of them were chosen"
    fi

    # Every language server the editor declares is actually there.
    #
    # lua/lsp.lua only enables a server whose executable it can find, which is
    # deliberate - a missing one would otherwise throw on every matching file
    # with an error about a command that could not be spawned, saying nothing
    # about the cause. The cost of that kindness is silence: the editor works,
    # with less of it, and nothing says so. This is what says so.
    #
    # It asks the module rather than re-listing the servers here, so adding one
    # to lsp.lua is enough and this check cannot drift from it.
    lsp_missing="$(nvim --headless -c 'lua
local ok, m = pcall(require, "lsp")
if not ok then io.write("MODULE") return end
local enabled = {}
for _, n in ipairs(m.enabled or {}) do enabled[n] = true end
local out = {}
for _, n in ipairs(m.expected or {}) do
  if not enabled[n] then out[#out+1] = n end
end
table.sort(out)
io.write(table.concat(out, " "))' -c quit 2>/dev/null)"
    if [[ "$lsp_missing" == "MODULE" ]]; then
        fail "the editor's lsp module does not load, so no language server is configured"
    elif [[ -n "$lsp_missing" ]]; then
        fail "language servers declared but not installed: $lsp_missing - run ./sync.sh"
    else
        pass "every language server the editor declares is installed"
    fi

    # The npm servers specifically, because they are the ones not installed by
    # pacman and therefore the ones a rebuilt machine can quietly lack. npm ci
    # installs from the lockfile, so a mismatch here means the run_onchange
    # script has not run - which is exactly what happened when it hashed
    # package.json without the lockfile.
    npm_servers_dir="$HOME/.local/lib/language-servers"
    if [[ ! -d "$npm_servers_dir/node_modules" ]]; then
        fail "the npm language servers are not installed in $npm_servers_dir - run ./sync.sh"
    else
        npm_missing=""
        for bin in vscode-html-language-server vscode-css-language-server \
                   vscode-json-language-server emmet-language-server; do
            [[ -x "$npm_servers_dir/node_modules/.bin/$bin" ]] || npm_missing+="$bin "
        done
        if [[ -n "$npm_missing" ]]; then
            fail "npm language servers missing from the lockfile install: ${npm_missing}- run ./sync.sh"
        else
            pass "the npm language servers are installed where the editor looks for them"
        fi
    fi

    # Parsers are declared packages rather than runtime downloads, so a missing
    # one is package drift rather than something neovim should fix itself.
    missing_parsers=""
    for parser in python javascript bash; do
        [[ -f "/usr/lib/tree_sitter/$parser.so" ]] || missing_parsers+="$parser "
    done
    if [[ -n "$missing_parsers" ]]; then
        fail "declared treesitter parsers not installed: ${missing_parsers}- run ./sync.sh"
    else
        pass "the declared treesitter parsers are installed"
    fi
fi

# ----------------------------------------------------------------------
section "Shortcut reference (TASK-68)"

# The point of deriving the list rather than writing one is that it cannot go
# stale. That only holds if each source still yields anything - a parser that
# silently returns nothing looks exactly like a context with no shortcuts.
if [[ ! -x "$HOME/.local/bin/shortcuts" ]]; then
    fail "the shortcuts helper is not installed"
else
    empty_contexts=""
    for context in sway nvim yazi desktop; do
        count="$(timeout 40 "$HOME/.local/bin/shortcuts" --mode "$context" 2>/dev/null | grep -c . || true)"
        [[ "${count:-0}" -lt 3 ]] && empty_contexts+="$context "
    done
    if [[ -n "$empty_contexts" ]]; then
        fail "these contexts list nothing, so their parser has stopped working: $empty_contexts"
    else
        pass "every shortcut context lists bindings derived from live config"
    fi
fi

# ----------------------------------------------------------------------
section "Desktop entries"

# A desktop entry whose Exec cannot be resolved fails silently: Terminal=false
# means nothing is printed anywhere, so the launcher entry simply does nothing.
# The trap is that ~/.local/bin is on PATH for interactive shells only - it
# comes from .zshrc - and not on the PATH sway and rofi hand to what they
# spawn, so a bare command name works when tested from a terminal and fails
# from the launcher. Absolute paths are the fix; this is the check.
shopt -s nullglob
entries=("$HOME/.local/share/applications"/*.desktop)
if [[ ${#entries[@]} -eq 0 ]]; then
    skip "no desktop entries of our own"
else
    for entry in "${entries[@]}"; do
        # Quotes are legal in Exec and some applications use them, so strip
        # them rather than reporting a perfectly good absolute path as missing.
        cmd="$(sed -n 's/^Exec=//p' "$entry" | head -1 | awk '{print $1}' | tr -d '"'"'"'"')"
        name="$(basename "$entry")"
        [[ -n "$cmd" ]] || { fail "$name has no Exec"; continue; }
        if [[ "$cmd" == /* ]]; then
            if [[ -x "$cmd" ]]; then
                pass "$name -> $cmd"
            else
                fail "$name points at $cmd, which is not executable"
            fi
        elif command -v "$cmd" &>/dev/null; then
            # Resolvable here, but this shell has ~/.local/bin on PATH and the
            # session does not, so a bare name is only safe outside it.
            case "$(command -v "$cmd")" in
                "$HOME"/*) fail "$name runs '$cmd' by name, but it lives under \$HOME and will not resolve on the session PATH - use an absolute path" ;;
                *)         pass "$name -> $cmd" ;;
            esac
        else
            fail "$name runs '$cmd', which does not exist"
        fi
    done
fi

section "XDG autostart (TASK-93)"

# The other way a process joins this session. uwsm reaches
# xdg-desktop-autostart.target through wayland-session-xdg-autostart@sway.target,
# so a .desktop file in an autostart directory - shipped by a package, named
# nowhere in setup/ - becomes a running process at login. A package update can
# add one; a package added for one reason can bring one for another.
#
# setup/system/xdg-autostart.txt is the set this repository has acknowledged.
# Anything that will actually start and is not in it is a failure here.
#
# The verdict comes from the real implementations rather than a second copy of
# their rules: the generator itself is run into a temporary directory, and each
# unit it emits is judged by running its own ExecCondition - which for
# OnlyShowIn/NotShowIn is systemd-xdg-autostart-condition, the same binary
# systemd would run. So Hidden, X-systemd-skip, TryExec, the GNOME phase key
# and the show-in filters are all honoured by construction.
AUTOSTART_SETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/setup"
AUTOSTART_GENERATOR=/usr/lib/systemd/user-generators/systemd-xdg-autostart-generator

if [[ ! -x "$AUTOSTART_GENERATOR" ]]; then
    skip "systemd-xdg-autostart-generator is not installed, so no autostart entry can start"
else
    while IFS='|' read -r verdict message; do
        case "$verdict" in
            pass) pass "$message" ;;
            fail) fail "$message" ;;
            skip) skip "$message" ;;
        esac
    done < <(python3 - "$AUTOSTART_SETUP" "$AUTOSTART_GENERATOR" <<'PYEOF'
import os, shlex, shutil, subprocess, sys, tempfile

setup, generator = sys.argv[1], sys.argv[2]
manifest = os.path.join(setup, "system", "xdg-autostart.txt")
out = []

def say(verdict, message):
    out.append(f"{verdict}|{message}")

def run(argv, **kw):
    return subprocess.run(argv, capture_output=True, text=True, **kw)

# The user manager's environment, not this shell's. Both the generator and the
# show-in helper run there, and the two disagree on this machine:
# XDG_CURRENT_DESKTOP is "sway:wlroots" in a terminal and "sway" in the manager,
# which is exactly the value a NotShowIn= would be matched against.
env = dict(os.environ)
for line in run(["systemctl", "--user", "show-environment"]).stdout.splitlines():
    if "=" not in line:
        continue
    key, value = line.split("=", 1)
    if key in ("XDG_CONFIG_HOME", "XDG_CONFIG_DIRS", "XDG_CURRENT_DESKTOP"):
        # show-environment shell-quotes a value that needs it; these three do
        # not on any machine here, but stripping is cheaper than being wrong.
        env[key] = value.strip('"\'')

desktops = env.get("XDG_CURRENT_DESKTOP", "") or "(unset)"

# The directories the generator scans, in its order: the user's first, then
# the system ones, and the first file of a given name wins.
config_home = env.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
config_dirs = [d for d in (env.get("XDG_CONFIG_DIRS") or "/etc/xdg").split(":") if d]
present = {}
for directory in [os.path.join(d, "autostart") for d in [config_home] + config_dirs]:
    try:
        names = sorted(os.listdir(directory))
    except OSError:
        continue
    for name in names:
        if name.endswith(".desktop"):
            present.setdefault(name, os.path.join(directory, name))

def keys_of(path):
    keys = {}
    try:
        with open(path, errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if "=" in line and not line.startswith(("[", "#")):
                    k, v = line.split("=", 1)
                    keys.setdefault(k.strip(), v.strip())
    except OSError:
        pass
    return keys

# Why an entry produced no unit. The generator does not say in its exit status,
# and the answer belongs in the report: "present but inert" is only reassuring
# with the reason attached.
def inert_because(keys):
    if keys.get("Hidden", "").lower() == "true":
        return "Hidden=true"
    if keys.get("X-systemd-skip", "").lower() == "true":
        return "X-systemd-skip=true"
    if keys.get("X-GNOME-Autostart-Phase"):
        return "X-GNOME-Autostart-Phase=" + keys["X-GNOME-Autostart-Phase"]
    tryexec = keys.get("TryExec")
    if tryexec and not (os.path.isabs(tryexec) and os.access(tryexec, os.X_OK)
                        or shutil.which(tryexec)):
        return f"TryExec={tryexec}, which does not resolve"
    return "the generator emitted no unit for it"

acknowledged = []
if not os.path.isfile(manifest):
    say("fail", f"{os.path.relpath(manifest, os.path.dirname(setup))} is missing, "
                f"so nothing records which autostart entries this repository accepts")
else:
    with open(manifest) as fh:
        for line in fh:
            line = line.split("#", 1)[0].strip()
            if line:
                acknowledged.append(line)

# Run the real generator into a scratch directory. It writes only there, and
# nothing reads what it writes but this check.
tmp = tempfile.mkdtemp(prefix="session-check-autostart.")
starts = {}
try:
    result = run([generator, tmp, tmp, tmp], env=env)
    if result.returncode != 0:
        say("fail", f"systemd-xdg-autostart-generator exited {result.returncode}: "
                    f"{result.stderr.strip().splitlines()[-1] if result.stderr.strip() else 'no output'}")
    for unit in sorted(os.listdir(tmp)):
        if not unit.endswith(".service"):
            continue
        source, conditions = "", []
        with open(os.path.join(tmp, unit), errors="replace") as fh:
            for line in fh:
                if line.startswith("SourcePath="):
                    source = line.split("=", 1)[1].strip()
                elif line.startswith("ExecCondition="):
                    conditions.append(line.split("=", 1)[1].strip())

        blocked = ""
        for condition in conditions:
            argv = shlex.split(condition)
            if not argv:
                continue
            argv[0] = argv[0].lstrip("-:+!@")
            if not os.access(argv[0], os.X_OK):
                # The helper is missing, so the unit would fail rather than be
                # skipped. That is a different fault; treat the entry as
                # starting, because the alternative is excusing it silently.
                continue
            code = run(argv, env=env).returncode
            if code != 0:
                keys = keys_of(source)
                shown = keys.get("OnlyShowIn") or keys.get("NotShowIn") or condition
                blocked = (f"{'OnlyShowIn' if keys.get('OnlyShowIn') else 'NotShowIn'}"
                           f"={shown} does not match XDG_CURRENT_DESKTOP={desktops}")
                break

        name = os.path.basename(source) or unit
        present.setdefault(name, source)
        starts[name] = blocked
finally:
    shutil.rmtree(tmp, ignore_errors=True)

if not present:
    say("pass", "no XDG autostart entries are installed at all")

for name in sorted(present):
    path = present[name]
    owner = ""
    if shutil.which("pacman"):
        owner = run(["pacman", "-Qoq", path]).stdout.strip().replace("\n", ", ")
    owned = f" (from {owner})" if owner else ""

    if name in starts and not starts[name]:
        if name in acknowledged:
            say("pass", f"{name}{owned} starts under {desktops}, and is acknowledged")
        else:
            keys = keys_of(path)
            say("fail", f"{name}{owned} will start under {desktops} - running "
                        f"'{keys.get('Exec', '?')}' - and setup/system/xdg-autostart.txt "
                        f"does not acknowledge it; add it there once you know what it does, "
                        f"or remove the package that ships it")
    else:
        reason = starts.get(name) or inert_because(keys_of(path))
        seen = "acknowledged" if name in acknowledged else "not acknowledged, and does not need to be"
        say("pass", f"{name}{owned} is present but does not start: {reason} ({seen})")

for name in acknowledged:
    if name not in present:
        say("fail", f"{name} is acknowledged in setup/system/xdg-autostart.txt but no "
                    f"autostart directory contains it any more - drop the line, so the "
                    f"file keeps meaning what it says")

print("\n".join(out))
PYEOF
    )
fi

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
section "Sway config reaches the running session"

# A binding written to disk that the running sway has never been told about is
# a key that does nothing, and nothing reports it. That happened: $mod+v was
# added, synced, and did nothing, because sync applies dotfiles and only the
# THEME reload script restarts sway - a binding change moves no theme value, so
# it never fired.
#
# run_onchange_after_reload-sway.sh.tmpl fixes it by hashing each file sway
# reads. This is the drift that fix introduces: add a file to config.d/ and
# forget its hash line, and reloads silently stop covering it.
#
# 30-appearance.conf.tmpl is deliberately excluded there - it is rendered from
# the palette, and the theme reload already covers every way that changes.
sway_reload_tmpl="$CHECKS_REPO/setup/dotfiles/run_onchange_after_reload-sway.sh.tmpl"
sway_config_dir="$CHECKS_REPO/setup/dotfiles/dot_config/sway/config.d"

if [[ ! -f "$sway_reload_tmpl" ]]; then
    fail "no sway reload script, so a keybinding change reaches disk and not the running session"
elif [[ ! -d "$sway_config_dir" ]]; then
    skip "the sway config directory is not in this checkout"
else
    unhashed=""
    for f in "$sway_config_dir"/*.conf; do
        [[ -f "$f" ]] || continue
        base="$(basename "$f")"
        grep -qF "$base" "$sway_reload_tmpl" || unhashed+="$base "
    done
    if [[ -n "$unhashed" ]]; then
        fail "sway config files the reload script does not hash: ${unhashed}- editing one would reach disk and not the running session"
    else
        pass "every sway config file is hashed by the reload script, so a change reloads the session"
    fi
fi

# ----------------------------------------------------------------------
section "Where a bare chezmoi command looks (TASK-121.1)"

# Everything in this repository drives chezmoi with an explicit --source. A
# human does not: `chezmoi status` typed into a terminal reads sourceDir from
# ~/.config/chezmoi/chezmoi.toml, which sync.sh records.
#
# chezmoi does not check that the recorded directory exists, and the two
# commands you would reach for disagree about saying so. Measured against
# chezmoi 2.72 with a sourceDir that does not exist:
#
#   chezmoi managed  ->  no output, exit 0     <- indistinguishable from healthy
#   chezmoi status   ->  "no such file", exit 1
#
# So the silent one is `managed`, and `managed` is what tooling calls. This
# check asks it, because zero managed files is the exact state that made the
# stale-dotfile check below recommend deleting seven live config files.
if ! command -v chezmoi &>/dev/null; then
    skip "chezmoi is not installed"
else
    recorded_source="$(chezmoi source-path 2>/dev/null || true)"
    managed_count="$(chezmoi managed 2>/dev/null | wc -l)"
    # What to tell someone to record. Not $CHECKS_REPO blindly: these checks are
    # often run from a worktree, and advising the path that causes this bug is
    # how a check hands you a fix worse than the fault. `git worktree list`
    # puts the main working tree first.
    suggest_repo="$(git -C "$CHECKS_REPO" worktree list --porcelain 2>/dev/null |
                    sed -n '1{s/^worktree //p;}')"
    [[ -n "$suggest_repo" && -d "$suggest_repo/setup" ]] || suggest_repo="$CHECKS_REPO"
    if (( managed_count > 0 )); then
        # A worktree is a checkout with a deadline. It answers today and
        # vanishes with the task, so this is the one failure worth reporting
        # while everything still works.
        if [[ "$recorded_source" == *"/.claude/worktrees/"* ]]; then
            fail "a bare chezmoi command looks inside a git worktree: $recorded_source"$'\n'"        that directory is deleted with the task, and chezmoi will then find nothing without saying so"$'\n'"        repair it with: theme --record-source $suggest_repo/setup"
        else
            pass "a bare chezmoi command finds $managed_count managed files in ${recorded_source:-its default source}"
        fi
    else
        fail "a bare chezmoi command manages nothing, so anything not passing --source silently does nothing: ${recorded_source:-no source recorded}"$'\n'"        repair it with: theme --record-source $suggest_repo/setup"
    fi
fi

# ----------------------------------------------------------------------
section "Dotfiles this repository stopped shipping (TASK-94)"

# chezmoi apply NEVER removes a file the source state has stopped shipping. So
# deleting a dotfile from setup/dotfiles/ removes it from a fresh install and
# from nowhere else - every machine that already had it keeps it, and quietly
# stops matching what a rebuild would produce.
#
# Two were live when this was written, both in ~/.config/environment.d, which is
# the worst place for it: the user manager reads *.conf in lexicographic order
# and the last one wins, so a leftover 10-cursor.conf sorted AFTER the
# 10-appearance.conf that replaced it and overrode it. On that machine only.
# No diff would have shown it and no check was looking.
#
# The fix for a specific file is .chezmoiremove. This is the half that notices
# when somebody forgets: it replays every deletion under setup/dotfiles/ out of
# git history, works out what target path each source name meant, and reports
# any that still exist on disk while no longer being managed.
#
# The false positive to avoid, which is most of what a naive version finds: a
# file deleted and re-added under a different source name - a plain file
# becoming a .tmpl, or gaining an executable_ prefix - is still managed, just
# from a different source. So this compares against `chezmoi managed`, which
# knows the target paths, rather than against git alone.
#
# Only the two-commit form of that reaches here at all: renaming a file within
# a single commit is recorded as a rename, and --diff-filter=D does not report
# it. Both forms exist in this repository's history and both were exercised
# against this check before it was trusted - a probe deleted and re-added as a
# .tmpl, another re-added with an executable_ prefix, and a third deleted for
# good, with all three present on disk. Only the third was reported.
if ! command -v chezmoi &>/dev/null; then
    skip "chezmoi is not installed"
elif ! git -C "$CHECKS_REPO" rev-parse --git-dir &>/dev/null; then
    skip "not a git checkout, so there is no deletion history to replay"
else
    # The exit status is read, and that is not decoration. This script runs
    # without `set -e`, so a python that gives up returns an EMPTY orphan list -
    # which reads as "nothing is stale" and prints a green PASS. That is the
    # same silent-success shape as the bare `chezmoi managed` this check was
    # fixed for: the answer was never computed, and the check said everything
    # was fine. Ask, and fail loudly when the answer is missing.
    orphans="$(
        git -C "$CHECKS_REPO" log --diff-filter=D --name-only --format= -- setup/dotfiles/ 2>/dev/null |
        sort -u |
        CHEZMOI_SOURCE_DIR="$CHECKS_REPO/setup/dotfiles" \
        CHEZMOI_ROOT="$CHECKS_REPO/setup" python3 -c '
import os, subprocess, sys

home = os.path.expanduser("~")
source_dir = os.environ.get("CHEZMOI_SOURCE_DIR", "")
chezmoi_root = os.environ.get("CHEZMOI_ROOT", "")

# --source is not optional here, and leaving it off is how this check produced
# a destructive false positive. chezmoi reads sourceDir from the local
# ~/.config/chezmoi/chezmoi.toml, which sync.sh records - and a sync run from
# inside a git worktree records that worktree path. Once the worktree is
# removed, bare `chezmoi managed` returns NOTHING, every file reads as
# unmanaged, and this check tells you to add half the dotfiles to
# .chezmoiremove. It has to ask about the checkout being checked, not about
# whatever the machine last happened to record.
#
# Pointed at setup/ rather than setup/dotfiles/, because .chezmoiroot redirects
# it the rest of the way - the same way sync.sh calls it.
managed = set()
try:
    result = subprocess.run(["chezmoi", "--source", chezmoi_root, "managed"],
                            capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        # Never fall through to an empty set. An empty managed list makes every
        # deleted-then-readded file look like an orphan, which is the failure
        # this comment exists to describe.
        sys.exit(3)
    managed = set(result.stdout.split())
except Exception:
    sys.exit(3)
# `chezmoi managed` INCLUDES everything listed in .chezmoiremove, because
# managing a file removal is a kind of managing it. Reasonable of chezmoi and
# fatal here: without this, a file queued for removal counts as still managed,
# this check reads it as a re-add under another source name, and it never fires
# for the exact files it was written for. Found only by putting a stale file
# back and watching the check pass.
try:
    with open(os.path.join(source_dir, ".chezmoiremove")) as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith("#"):
                managed.discard(line)
except OSError:
    pass

# chezmoi source names encode the target. Strip the attribute prefixes and the
# template suffix, and turn dot_ back into a leading dot.
PREFIXES = ("encrypted_", "private_", "readonly_", "executable_", "symlink_",
            "empty_", "modify_", "create_", "remove_")

def target(source):
    parts = source.split("/")
    out = []
    for part in parts:
        changed = True
        while changed:
            changed = False
            for pre in PREFIXES:
                if part.startswith(pre):
                    part = part[len(pre):]
                    changed = True
        if part.endswith(".tmpl"):
            part = part[:-len(".tmpl")]
        if part.startswith("dot_"):
            part = "." + part[len("dot_"):]
        out.append(part)
    return "/".join(out)

stale = []
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("setup/dotfiles/"):
        continue
    rel = line[len("setup/dotfiles/"):]
    base = rel.split("/")[-1]
    # Scripts and chezmoi metadata are not target files at all.
    if base.startswith((".chezmoi", "run_")):
        continue
    t = target(rel)
    if t in managed:
        continue                      # re-added under another source name
    if os.path.lexists(os.path.join(home, t)):
        stale.append(t)

print(" ".join(sorted(set(stale))))
'
    )"
    orphan_status=$?
    if (( orphan_status != 0 )); then
        fail "could not work out which dotfiles are stale: chezmoi could not be asked what it manages from $CHECKS_REPO/setup"$'\n'"        this check reports nothing rather than guessing, because the guess would be \"delete them\""
    elif [[ -n "$orphans" ]]; then
        fail "deleted from setup/dotfiles/ but still on this machine: $orphans"$'\n'"        add them to setup/dotfiles/.chezmoiremove, then run ./sync.sh"
    else
        pass "every dotfile this repository has deleted is gone from this machine too"
    fi
fi

# ----------------------------------------------------------------------
section "Screenshot helper (TASK-10)"

if [[ -x "$HOME/.local/bin/sway-screenshot" ]]; then
    if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        skip "cannot capture outside a Wayland session"
    elif pgrep -x swaylock >/dev/null 2>&1; then
        # A LOCKED SCREEN MAKES grim WAIT, NOT FAIL.
        #
        # swaylock takes an exclusive lock on every output, and a screencopy
        # request against a locked output is not refused - it is queued until
        # the output is readable again. So grim sits there using no CPU, and
        # this check, and anything running it, hangs indefinitely. It looks like
        # a broken helper and it is a working one waiting for the screen to come
        # back. TASK-96.
        #
        # Refusing to try is the honest answer: the helper cannot be tested
        # while the screen is locked, and nothing here can unlock it.
        skip "the screen is locked, and a capture would block until it is not"
    else
        # Bounded even so. The lock is the known cause of a hang, but it is the
        # known one - a check that can wait forever is worse than one that is
        # sometimes wrong.
        shot="$(timeout 15 "$HOME/.local/bin/sway-screenshot" screen 2>&1)"
        capture_status=$?
        if [[ $capture_status -eq 124 ]]; then
            fail "sway-screenshot did not return within 15s - something is holding the output"
        elif [[ -s "$shot" ]]; then
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
  5. In a NEW terminal, press Ctrl+Shift+A.     Expect: a notification saying
                                                how many lines were copied, and
                                                that many lines on the
                                                clipboard. A new terminal
                                                because foot reads its config
                                                once, at startup. No script can
                                                press this: sway has no
                                                key-injection IPC, and foot
                                                ignores swaymsg's synthetic
                                                clicks, so the keypress itself
                                                is the one link in the chain
                                                nothing here can test.

MANUAL

[[ $FAIL -eq 0 ]]
