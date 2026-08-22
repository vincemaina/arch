# The keyboard

This chapter is prose around a generated reference, not a hand-typed list.
The tables below come straight from `tools/shortcuts.sh`, which reads the
actual configuration rather than a copy of it - so this chapter cannot drift
out of date the way a typed list would. If you want to check it yourself:

```bash
./tools/shortcuts.sh
```

## The modifier convention

Sway's config sets `$mod` to `Mod4`, which is the Super (Windows) key. Every
binding in the table below that starts with `Mod4` is a `$mod` chord. The
one organising rule behind almost all of them: `$mod` is for window
management, and nothing else is allowed to take a `$mod` chord - applications
are launched through `$mod+space` instead of being bound individually, so the
small number of window-management letters never gets shadowed by whatever
was installed most recently.

## The left Alt / left Control swap

Before Sway, or anything else, sees a keypress, **keyd** has already
remapped it. It swaps the **left** Control and **left** Alt keys - only the
left-hand copies; the right-hand Ctrl and Alt are untouched. Physically:
press the key labelled Ctrl in the bottom-left corner and the system
receives Alt; press the key labelled Alt next to it and the system receives
Control.

So wherever this manual, or any program's own help, says "Ctrl", the key to
reach for is physically the one labelled Alt - and vice versa. This is done
below the compositor deliberately, because four separate things on this
machine read a keyboard configuration on their own (Sway, the text console,
the login greeter, and XWayland), and keyd remaps at the layer underneath
all of them so one file covers every context instead of four being kept in
agreement by hand. That matters most for `Ctrl+Alt+F2`, which reaches the
plain-text console when the graphical session will not start - exactly the
moment a mismatched swap would be most disorienting, and exactly the case
that motivated fixing this below the compositor rather than only inside it.

The reasoning for the swap itself - Control is the modifier reached for most
often and sits under the weakest finger, Alt is used far less and sits under
a stronger one - is in
[DECISIONS.md](../../DECISIONS.md) if you want the full argument.

## Modes

A **mode** temporarily changes what keys do, shown by a name appearing in
the bar's mode module while it is active. Only one is defined here:
`$mod+r` enters **resize** mode, where `h`/`j`/`k`/`l` shrink or grow the
focused window in 10px steps, and `Return` or `Escape` returns to the normal
("default") mode. This was confirmed against the running compositor rather
than assumed from the config file:

```bash
swaymsg -t get_binding_modes
# ["default", "resize"]
```

## Resizing without aiming

There are three ways to resize, and two of them are new enough to be worth
naming explicitly.

`$mod+equal` and `$mod+minus` grow and shrink the focused window in both
dimensions at once. Read them as `+` and `-`. They repeat while held, so a
window can be dragged to roughly the size you want without releasing.

Holding `$mod` and turning the scroll wheel over a window does the same thing
by hand. Both move in fixed **pixel** steps rather than percentage points, and
the steps are 16:9, so a window keeps roughly its shape instead of creeping
square over several presses. The unit is not a detail: a floating window
ignores a percentage resize entirely, so a binding written in `ppt` would look
correct, work when tried on a tiled window, and silently do nothing on every
floating one.

Both work on tiled and floating windows alike. A single tiled window with no
neighbour has nothing to take space from, so it correctly does nothing there -
that is Sway's model, not a fault.

`$mod+r` enters resize mode, described above, which is the one to use when you
want one edge moved rather than the whole window scaled.

## Media keys

The hardware keys for volume, microphone mute, playback, and screen
brightness all work while the screen is locked, which is the point of
putting them on dedicated keys rather than a chord. Volume is capped at
100% deliberately - raising it further is digital amplification that clips
the waveform rather than making anything louder, and the tool used here has
no upper bound unless one is given.

## The Caps Lock scroll layer

This one appears in no per-tool help, including Sway's own config, because
it does not come from Sway at all. It is defined in keyd, below the
compositor, in `setup/system/keyd/default.conf`:

- **Hold Caps Lock**, and `j`/`k`/`h`/`l` emit real mouse-wheel scroll
  events - down, up, left, right. Because these are genuine wheel events
  rather than keypresses, they scroll whatever is under the **mouse
  pointer**, regardless of which window has keyboard focus, and they work
  inside a text field where an arrow or Page key would only move the caret.
- **Hold Caps Lock**, and `d`/`u` send Page Down / Page Up instead, which go
  to whichever window has **keyboard** focus - the case the wheel keys
  cannot reach, since sway's default pointer behaviour leaves the mouse
  behind on a keyboard-driven focus change.
- **Tapping** Caps Lock on its own still toggles caps lock normally. The
  layer only engages on a hold, or when another key is struck while it is
  held down.

`tools/shortcuts.sh` builds its table by parsing Sway's configuration, and
this layer lives entirely outside that - which is exactly why it is called
out here in prose instead of appearing as a row below. The script itself
knows this and prints a note about it when keyd is active and configured
this way, which is where the description above was checked against, along
with the config file's own comments.

**Known limitation:** on a virtual machine, the physical Caps Lock LED does
not follow this state. What gets typed is correct - tapping Caps Lock really
does toggle caps - but the indicator light does not change. This was
established by watching `/sys/class/leds` across real key presses rather
than assumed: both the emulated keyboard's LED and keyd's own virtual one
change together, so the swap and the daemon are not the cause. The machine
is a KVM guest with an emulated keyboard, and the LED belongs to the
*host*, which keeps its own Caps Lock state and is never told about the
guest's. On real hardware, the device Sway updates is the physical
keyboard, so the light works as expected and this does not apply.

## The generated reference

Everything below is produced by `tools/shortcuts.sh` from the live
configuration: every Sway window-management and system binding, the resize
mode, the hardware keys, and the terminal's own line-editing shortcuts
(zsh), followed by a check for any key that means two different things in
different contexts. It also lists what is not covered yet - qutebrowser,
neovim, rofi and foot are not parsed by the tool, either because they have
no configuration in this repository to read or because that parsing has not
been written - so a gap in the table below is a gap in the tool, not a claim
that those programs have no shortcuts of their own.

{{shortcuts}}
