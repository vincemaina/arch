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

`$mod+Shift+equal` and `$mod+Shift+minus` grow and shrink the focused window
in both dimensions at once. Read them as `+` and `-`. They repeat while held,
so a window can be dragged to roughly the size you want without releasing.

They share a modifier with `$mod+Shift+h/j/k/l`, which moves a window, and
that is the reason they are not on bare `$mod`. Arranging a layout means
moving and sizing in the same breath; on `$mod+Shift` the whole operation
happens with one hand posture held down, whereas the shorter chord would mean
releasing Shift between every pair of actions. Cheaper to press once, more
expensive to actually use.

Holding `$mod+Shift` and turning the scroll wheel over a window does exactly
the same thing with the other hand. That is a deliberate duplicate, and one of
very few here: rearranging and sizing windows is a *spatial* task and spatial
tasks suit a pointer, while everything else in this scheme is discrete and
suits a key. Both move in fixed **pixel** steps rather than percentage points, and
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

Note that the wheel gesture is `$mod+Shift`, not bare `$mod`. Bare `$mod` and
the wheel steps between workspaces instead — see
[The desktop](02-the-desktop.md).

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
  rather than keypresses, they work inside a text field, where an arrow or
  Page key would only move the caret. The other half of that is that a wheel
  event goes to whatever is under the **mouse pointer** and ignores keyboard
  focus - so Sway is configured with `mouse_warping container` in
  `setup/dotfiles/dot_config/sway/config.d/10-input.conf`, which puts the
  pointer on whichever window gains focus. That setting exists for this
  feature: with it, scrolling goes where typing goes, unless the pointer has
  since been moved by hand.
- **Hold Caps Lock**, and `d`/`u` send Page Down / Page Up instead. These are
  ordinary key events, so they go to whichever window has **keyboard** focus,
  wherever the pointer happens to be - the answer when the pointer has been
  left over some other window, or over a window on another output.
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
guest's.

The expectation is that this disappears on real hardware, where the device
Sway updates is the keyboard the light is attached to. Read that as an
expectation and not a finding: nothing in this repository records the build
ever running on physical hardware, so nobody has watched the light there. If
you are the first to boot it on metal, look at the Caps Lock light and
correct this paragraph either way.

## Two other ways to press Escape

Escape is the key this desktop asks for most - leaving insert mode in Neovim,
backing out of the Backlog TUI, closing the launcher, cancelling a fuzzy
search - and it is the furthest key on the board from where the hands sit. So
there are two more within reach: **`Ctrl+K` and `Ctrl+;` both send Escape**.

Two keys for one action is the thing this desktop otherwise argues against,
and here it is deliberate and temporary. They are bound together so they can
be compared by using them rather than by reasoning about them, and one will be
removed. If you are reading this and only one is bound, that comparison
finished.

Like the scroll layer, this is keyd rather than Sway, in the same file
(`setup/system/keyd/default.conf`), and for a reason Sway could not have
solved. Sway can only bind a key *away* from an application; it cannot change
what a key means *inside* one. Escape is wanted inside Neovim, inside the
Backlog TUI, inside a browser and inside rofi - and two of those have no
configuration in this repository to change. keyd emits a real Escape key event
at the evdev layer, so every one of them receives exactly what the Escape key
itself sends, with nothing to configure per program.

Remember that keyd has already swapped the modifiers, so the Control here is
physically the key next to the space bar - left thumb, right middle finger,
neither hand leaving the home row.

**`Ctrl+;` costs nothing at all.** There is no ASCII control code for
semicolon, so no terminal program *can* bind it, and nothing on this machine
does. keyd turns it into a real Escape before any terminal sees the chord.

**`Ctrl+K` is not free, and what it costs is worth knowing before it surprises
you.** It meant something in most of these programs already:

| Where | What Ctrl+K was | What to use instead |
| --- | --- | --- |
| zsh | `kill-line` | `Alt+K`, rebound in `~/.zshrc` for exactly this reason |
| Neovim | move to the split above | `Ctrl+W` then `k` |
| fzf | move the selection up | `Ctrl+P`, or the arrow key |
| lazygit | move a commit up in a rebase | `Alt+Up` |
| qutebrowser | kill to end of line, in command and prompt modes | - |
| rofi, yazi, foot | kill to end of the input line | - |
| Firefox | focus the search bar | `Ctrl+L`, which searches too |

The last four traded a kill-to-end-of-line for an Escape that leaves the thing
altogether, which is usually closer to what the key was reached for. The first
three are real losses with real replacements. Sway itself binds no Ctrl+K at
all, and the Backlog TUI binds only Ctrl+S, so the two places this was asked
for cost nothing at all.

One consequence to expect: in fzf, Ctrl+K now **cancels** the search rather
than moving the selection up. That is Escape doing its job, and it is the one
that takes the longest to unlearn.

`tools/shortcuts.sh` reports this the same way it reports the scroll layer -
as a note above the table, because no configuration the tool parses mentions
it. That note reads the key out of the keyd config rather than asserting it,
so changing which key sends Escape changes the report without anyone editing
the report.

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
