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

    RULES = [
        ("muted", "bg", 4.5, "the cpu and memory readouts against the background"),
        ("text", "tertiary", 3.5, "the workspace number against its own disc"),
    ]
    poor = []
    for name, palette in themes.items():
        for fg, bg, floor, what in RULES:
            ratio = contrast(palette[fg], palette[bg])
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
