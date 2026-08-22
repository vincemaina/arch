# The desktop

This chapter explains the window model Sway uses, the workspaces it arranges
them into, everything the bar shows and does, and how notifications work. It
assumes nothing - if you have never used a tiling window manager, start at
the top.

## Tiling, and why new windows split

Most window managers let windows overlap and leave you to arrange them by
dragging. Sway does not: every window normally occupies its own share of the
screen, with no overlap, and the screen is divided by *splitting* it each
time a new window opens. Open a second window and the first one shrinks to
make room; close it and the space is given back.

A newly opened window splits the container that currently has focus. This
setup runs a small always-on program, `autotiling`, that decides the split
*direction* for you: it looks at the shape of the focused container and
splits side-by-side if it is wider than it is tall, and top-to-bottom if it
is taller than it is wide. That is why you do not need to choose "split
horizontally" or "split vertically" yourself - the commands for that exist in
Sway but this configuration does not bind them to anything.

### Containers, and the parent

Every split creates a **container**: a node that holds the windows either
side of it. Containers can nest - a container split left-right can have one
side split again, top-to-bottom, and so on - which is why a Sway layout is
best thought of as a tree rather than a grid. `$mod+a` moves focus from the
current window to its **parent container**, which is how you select the
whole group rather than one window inside it, for example to change the
group's own layout rather than a single window's.

### Tabbed layout

A container can also be **tabbed**: instead of splitting the space between
its children, it shows one window at a time with a row of tab labels across
the top, drawn by Sway itself. `$mod+t` toggles the focused container
between its split layout and tabbed. This is useful for windows you want
grouped but do not want fighting each other for screen space - several
terminals doing related work, for instance.

Sway also has a *stacked* layout, which does the same job as tabbed with a
row of title bars instead of a tab strip. It is deliberately not bound here:
having two ways to do the same thing was judged worse than picking one, and
tabbed is what remains.

### Floating windows

Not everything tiles. A window can be **floating** instead - positioned and
sized freely, drawn over the tiled windows rather than taking a share of
them. This desktop floats a window by rule for anything meant to be
glanced at and closed rather than worked in: image viewers, the file
explorer, the browser, dialogs, the small windows the bar opens (the
calendar, `btop`, `nmtui`), and the shortcut panel - which floats the same
way but is reached from the keyboard rather than by clicking anything on
the bar.

`$mod+Shift+space` toggles the focused window between floating and tiled.
Drag a floating window with `$mod` and the left mouse button, resize it with
`$mod` and the right button, from anywhere inside the window rather than
having to aim at its edge. `$mod+Shift` and the scroll wheel resizes the
focused window - floating or tiled - in fixed pixel steps at a 16:9 ratio,
which is the coarse alternative to dragging a corner: a few clicks to make
something bigger without aiming at anything. `$mod+Shift+equal` and
`$mod+Shift+minus` do the same from the keyboard, and both are documented in
[The keyboard](03-the-keyboard.md). A single tiled window with no neighbour
has nothing to shrink to make room, so the gesture correctly does nothing
there.

### Fullscreen

`$mod+f` makes the focused window fill the output, hiding the bar and every
other window on the workspace. The same chord returns it.

### The scratchpad

The scratchpad is a single hidden holding area shared by the whole session,
independent of any workspace. `$mod+Ctrl+Shift+minus` sends the focused
window there, removing it from view entirely. `$mod+Ctrl+minus` brings the
next scratchpad window back, cycling through whatever is stored if there is
more than one. It is the place to put a window you want kept running but out
of the way - nothing else on this desktop shows what is in it, which is why
the bar carries a count (see below).

Those are three-key combinations because the scratchpad lost its shorter ones.
`$mod+Shift+minus` and `$mod+Shift+equal` now shrink and grow the focused
window, which is used far more often, and the principle applied here is that
the shortest shortcuts belong to the most frequent actions rather than to
whichever feature claimed them first. See [The keyboard](03-the-keyboard.md).

## Workspaces

Ten workspaces are bound directly: `$mod+1` through `$mod+9`, then `$mod+0`
for the tenth. `$mod+Shift+<number>` sends the focused window to that
workspace without following it. `$mod+Ctrl+h` and `$mod+Ctrl+l` step to the
previous or next workspace **on the current output**; `$mod+Ctrl+j` jumps
back to whichever workspace you were on before the current one
(`back_and_forth`), which is the fast way to bounce between two you are
working across.

Holding `$mod` and turning the scroll wheel steps the same way — up for the
previous workspace, down for the next. Three routes to the workspace next
door is more duplication than this desktop usually allows, and each earns it
differently: the number row is exact but a stretch, the home-row pair is for
stepping without looking, and the wheel is there because this is a spatial
motion and your hand may already be on the mouse.

One thing to expect from the wheel and the `$mod+Ctrl` pair alike: **they step
through the workspaces that exist, not one to ten.** A workspace is created
when you first use it and destroyed when its last window closes, so on a
machine with three in use the wheel visits three. The number row is what
reaches an empty one.

Workspaces belong to one output each in Sway's model - this repository keeps
that rather than scripting something that spans displays, and
[DECISIONS.md](../../DECISIONS.md) records what was tried and why it was
rejected, if you have more than one monitor and want to know what to expect.

## The bar

Waybar sits across the top of the screen. Every module is a coloured pill -
colour tells you which reading you are looking at, and a module changing to
a warning or urgent colour is what tells you something needs attention. It
is also fully clickable: nothing on it is decoration only. The table below
records exactly what each module shows and what clicking it does, read left
to right as the bar itself is laid out.

| Module | Shows | Click |
| --- | --- | --- |
| Workspaces | Every workspace, current one highlighted | Switch to the one clicked |
| Mode | The active binding mode's name (for example "resize") while one is active | - |
| Scratchpad | How many windows are stashed, hidden when there are none | `scratchpad show` - brings one back |
| Notifications (bell) | Count of notifications you have not yet seen, hidden at zero | Opens the notification centre and marks everything seen |
| Focus timer | The running timer's countdown, hidden when no timer is running | Opens the timer menu: stop it, or skip to the next phase |
| Clock | Date and time together | Opens a three-month calendar |
| mpris (now playing) | Track and artist for whatever is playing, hidden when nothing is | Left click: play/pause. Middle: previous track. Right: next track |
| Caffeine (idle inhibitor) | A cup icon, muted when off and warning-coloured when on | Toggle: stop the screen locking and sleeping, or let it again |
| Network | Ethernet or Wi-Fi icon, with signal strength on Wi-Fi | Opens `nmtui` to change connection |
| CPU | Usage percentage | Opens `btop` |
| Memory | Usage percentage, tooltip shows used of total | Opens `btop` - the same window CPU opens, since `btop` already shows both |
| Volume | Icon and percentage, "muted" when muted | Left: `pavucontrol`. Right: toggle mute. Scroll: volume up/down in 5% steps, capped at 100% |
| Battery | Charge icon and percentage | Toggles to showing time remaining instead, and back |

A few things worth knowing about that table rather than assuming from it:

- The three modules that open a window - CPU/memory, network, and the
  calendar and shortcut panel elsewhere - all **toggle**. Clicking a second
  time closes the window rather than opening a duplicate.
- The window title used to sit in the centre of the bar and was removed:
  Sway already marks the focused window with an accent border, so the title
  was rarely worth the space. The clock and now-playing module took it
  instead.
- This machine reported "No batteries" in Waybar's own log at the time this
  manual was checked, which is expected for a VM - the battery module has
  nothing to show here. On real laptop hardware it will read the actual
  charge.
- `$mod+Shift+b` hides and shows the bar entirely, giving its strip back to
  the windows. That binding lives with the rest of the keyboard bindings, not
  on the bar itself, since it is not a module.

## Notifications

**mako** is the notification daemon, running as a supervised session unit
like the bar. A notification appears top-right and disappears on its own
after five seconds by default; a critical one stays until you dismiss it.
Do-not-disturb mode still receives and records notifications, it only stops
drawing them, so nothing is lost by turning it on.

mako keeps notifications after they disappear - `list` is what is currently
on screen, `history` is what has already expired - and the **notification
centre** (reachable from the launcher as "Notifications", or by clicking the
bell) is a single view over both: dismiss one, restore one from history, or
toggle do-not-disturb.

The bell on the bar exists because "what did I miss" otherwise has no
answer: mako's default five-second timeout means a notification is usually
already out of `list` and into `history` by the time you glance at the bar,
so a badge driven by `list` alone would read zero for the exact case it
exists to catch. It counts unseen notifications instead - everything newer
than the last time you opened the centre - and disappears entirely at zero
rather than sitting at a permanent 0.
