---
name: desktop-verification
description: How to see and prove a change to this sway desktop - screenshots you can actually look at, throwaway outputs that do not disturb the user's screen, live runtime bindings for trialling shortcuts, and asking each program what it applied rather than reading the config back. Use whenever changing sway, waybar, rofi, mako, foot or anything else visual, or when a change "should" work but has not been observed working.
---

# Verifying a desktop change

The failure this repository keeps hitting is configuration that looks correct
and does nothing. Reading the file back proves nothing. These are the ways to
actually find out, all used successfully.

## Look at it

`grim` is installed. Capture, then **read the image** - the tool can see it.

```bash
grim -o Virtual-1 /path/to/shot.png
```

Then Read that path. This has caught things no check could: a rofi theme
rendering in stock cream, an unreadable 40px row height, a config error dialog,
and text that was blurrier than it should have been.

For anything that opens a window and waits - rofi, a launcher, a dialog - the
program blocks, so background it, sleep, capture, then kill:

```bash
rofi -show combi >/dev/null 2>&1 &
sleep 2.5
grim -o Virtual-1 shot.png
pkill -x rofi
```

`rofi -show combi -filter "text"` prefills the search, which is how to prove a
particular entry is findable without typing.

## Test without disturbing the user's screen

`swaymsg create_output` makes a headless output with real workspace semantics.
Put windows on it, set its scale, screenshot it, then unplug it. The visible
display is never touched.

```bash
swaymsg create_output                       # appears as HEADLESS-n
swaymsg output HEADLESS-1 scale 2 resolution 1280x800
swaymsg 'focus output HEADLESS-1'; swaymsg workspace 90
# ... launch things, grim -o HEADLESS-1 ...
swaymsg 'output HEADLESS-1 unplug'
```

This is how XWayland scaling was measured and how multi-output workspace
behaviour was demonstrated, neither of which needed real hardware.

## Trial a keybinding before committing it

`swaymsg bindsym ...` and `swaymsg unbindsym ...` change bindings at runtime
only. Nothing touches the repository, and `swaymsg reload` reverts everything.
Four different workspace-navigation schemes were tried this way in twenty
minutes; only the surviving one was written down.

## Ask the program, do not read the config

| Question | Ask |
| --- | --- |
| What theme did rofi apply? | `rofi -dump-theme` |
| What config does rofi have? | `rofi -dump-config` |
| What does sway have? | `swaymsg -t get_outputs / get_inputs / get_tree / get_workspaces` |
| Is the foot config valid? | `foot --check-config --config <file>` |
| What is mako holding? | `makoctl list -j`, `makoctl history -j` |
| What did the session log? | `journalctl --user -b` |
| What did the kernel see? | `journalctl -b -k` |

`rofi -dump-theme` is the one that solved a problem reading the theme file
could not: rofi styles elements by *state* (`element selected.active`) and a
state rule beats the `*` wildcard, so wildcard colours silently did nothing.

Two things sway cannot tell you: it has no IPC to enumerate keybindings
(`get_config` returns only the top-level file), which is why
`checks/sway-bindings.sh` parses files instead; and `get_tree` does not report
window opacity.

## Test a config without applying it

`foot --config=/tmp/test.ini -e sh -c '...'` runs one terminal with a different
config. Copy the real one, change a line, launch, screenshot, compare.

## Then run the checks

`./checks/session.sh` after any change. It has found real problems on most runs.
