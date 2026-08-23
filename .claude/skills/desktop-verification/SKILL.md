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

## Measure it when looking is not enough

Some changes are real but too small to judge by eye - a 3px shadow, whether a
gradient is actually rendering. `grim -t ppm` writes raw pixels that about ten
lines of Python can read with no image library installed:

```bash
grim -t ppm -g "300,0 40x40" probe.ppm
```

The header is `P6 <w> <h> <max>` followed by raw RGB, so mean brightness per
row is a few lines. That settled two questions in one session: whether a
`box-shadow` on `window#waybar` did anything (it did not - GTK clips it at the
surface edge) and whether the replacement did (it did: one row of near-black
between bar and wallpaper).

The same trick detects animation. Capture several frames a fraction of a second
apart and count bytes that differ; a static bar gives zero.

## Never test CSS on the live bar

GTK's CSS parser is stricter than a browser's. One unknown property does not
get skipped - waybar exits and the bar disappears. `background-clip: text` is
enough to do it.

Test in a throwaway instance on a throwaway output instead, which cannot touch
the real one:

```bash
swaymsg create_output                       # HEADLESS-n
# config.jsonc with "output": "HEADLESS-1"
waybar -c /tmp/test/config.jsonc -s /tmp/test/test.css &
grim -o HEADLESS-1 shot.png
```

Test one property per run. A parse error on the first stops everything after it
being evaluated, so a batch of five tells you nothing about four of them.

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

**A freshly created headless output can be powered off**, and `grim` cannot
read one that is: it fails outright with `no supported format found` rather
than a black or blank frame, which at least announces itself. Confirmed
directly - the identical output, identical everything else, failed every time
without this line and succeeded every time with it:

```bash
swaymsg output HEADLESS-1 dpms on
```

Add it right after setting resolution, before anything is launched on the
output.

**Even powered on, a captured frame that is a flat, uniform colour is not
proof of an empty output** - it can also mean the client's own surface is not
being read back, while the compositor's own background layer is. Found this
way: a client launched with forced, unambiguous colours (bright red
background, black text - no theme, no contrast question left to chance)
still produced the exact same flat capture as a workspace with nothing on
it at all. `swaymsg -t get_tree` told the true story - a correctly sized,
correctly positioned window, present and undamaged by any error in its own
log - that `grim` was not seeing. This is the same shape of failure the
keyd probe in `scripting-traps` describes: an apparatus that looks like it is
measuring and is not, and the fix is the same - **prove the apparatus is
connected to what it claims to observe before trusting a negative result
from it.** Cross-check a suspiciously uniform capture against the tree
(`get_tree`, filtering for the app_id and reading its `rect`) rather than
concluding the window failed to render.

This was seen with a plain top-level `foot` window, launched directly under
Sway - not nested, not through `cage` - so it is not specific to either.
What it does and does not affect is not yet mapped: a qemu `-display gtk`
window captured cleanly under the exact same headless-output recipe in a
different session (see TASK-69.1's boot screenshot), so this is not a
blanket "grim cannot capture headless outputs" finding - something about
which clients successfully read back through `wlr-screencopy` on this
backend, or some other precondition not yet identified, is the open
question. Until it is, treat an unexpectedly flat capture as **inconclusive,
not negative** - check the tree, and do not report a rendering failure on
the strength of a screenshot alone.

**Unplug it, and put the focus back.** This has gone wrong twice, both times
leaving the user worse off than before the test:

- An output left plugged in **strands whatever workspace landed on it**. Sway
  keeps the workspace assigned to an output nobody can see, so a real window -
  in one case the user's own terminal - simply vanishes. `output HEADLESS-n
  unplug` migrates the workspace back and recovers it.
- Focus left on the headless output means **the user's keystrokes go somewhere
  invisible**. They are typing at a window they cannot see, with no clue why.

So the last two lines are not optional tidying, they are the test:

```bash
swaymsg 'focus output Virtual-1'; swaymsg workspace 1   # give the screen back
swaymsg 'output HEADLESS-1 unplug'                      # then remove it
```

Do both even if the test failed, and especially if something else is running
concurrently - the other agent's output is not yours to unplug, but focus
belongs to whoever is sitting at the machine.

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
