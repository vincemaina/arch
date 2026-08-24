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
| Bluetooth | A bluetooth icon, and the connected device's name when there is one. **Absent entirely unless the bluetooth daemon is running** | Opens the bluetooth menu: connect, pair, or turn it off |
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
- The battery module reads the real charge on laptop hardware. On a machine
  with no battery — a desktop, or a virtual machine — Waybar logs "No
  batteries" and the module shows nothing at all.
- `$mod+Shift+b` hides and shows the bar entirely, giving its strip back to
  the windows. That binding lives with the rest of the keyboard bindings, not
  on the bar itself, since it is not a module.

## Bluetooth

Bluetooth is **off until you turn it on**, on each machine separately, and
the bar is how you can tell which machines you have turned it on.

The reason is that `bluetoothd` is a daemon. Enabled, it runs from the moment
the machine boots to the moment it shuts down, whether or not anything is
ever paired to it — and not every machine this setup builds even has a
bluetooth radio. So the packages are installed everywhere and the daemon is
started nowhere, and starting it is a decision you make per machine.

Turn it on:

```bash
bluetooth on
```

That starts the daemon now and sets it to start at boot. `bluetooth off`
stops it and unsets that. Both ask for your password through the usual
graphical prompt, because starting a system service needs root. There is
also `bluetooth status`, which prints one line describing where this machine
currently stands.

With no argument, `bluetooth` opens a menu — the same one the bar module
opens when you click it, and the same one the launcher opens if you type
"bluetooth". What it offers depends on the state: turn it on, if it is off;
otherwise the paired devices to connect or disconnect, a way to pair
something new, and turning it off again.

### The module is the point

The bluetooth module is invisible whenever the daemon is not running. That is
deliberate rather than a gap:

- On a machine with no bluetooth hardware, there is nothing on the bar to
  explain or ignore.
- On a machine where you have turned bluetooth off, likewise — an "off"
  indicator would be a permanent readout telling you nothing.
- On a machine where you have turned it on, the module is there. **So if you
  can see it, a daemon is running.** If you can see it and you are not using
  bluetooth, that is the reminder that you left it on, and clicking it is how
  you turn it off.

The colour carries the rest. Connected to something, the module sits in the
same quiet colour as the other readings. Running with nothing connected, it
turns the warning colour — not because anything is wrong, but because that
is the state worth noticing: a radio that is up and idle. Powered down or
blocked by rfkill while the daemon still runs, it goes muted.

### Pairing something new

Choose **Pair a new device** from the menu. That opens `bluetoothctl` in a
floating terminal, with the four commands you need printed at the top:

```
scan on
pair <mac>
trust <mac>
connect <mac>
```

Pairing is left to `bluetoothctl` rather than wrapped in a menu because it is
genuinely interactive — devices ask you to confirm a passkey, and some want
trusting before they will reconnect on their own. `trust` is the step people
miss: without it a device pairs, connects, and then fails to come back by
itself the next time it is switched on.

Bluetooth **audio** needs nothing further. The codec support — SBC, AAC,
aptX, LDAC and the headset ones — is part of PipeWire and is already
installed on every machine here, so a paired pair of headphones appears as an
output device as soon as it connects, and the volume module controls it like
any other.

## Power

`$mod+Shift+e`, the small Arch logo at the left of the bar, and the launcher
(type "power") all open the same menu: **Log out**, **Restart**, **Suspend**,
**Power off**. It replaces what used to be a single swaynag prompt asking only
"exit sway?" — that covered a quarter of what leaving a session actually
means, and the other three were reachable only by opening a terminal and
typing `systemctl` at the one moment you are trying to get away from the
keyboard.

Log out ends the Wayland session (`swaymsg exit`) and returns you to the login
screen. Restart, Suspend and Power off go through `systemctl` to systemd-logind
— the same route `bluetooth on`/`off` use to start and stop a service, so the
polkit agent this desktop already runs is what would prompt for a password,
if logind ever asked for one.

**Log out, Restart and Power off ask once more before doing anything.** That
is the swaynag prompt's old reasoning, carried into the new menu rather than
dropped: a stray Enter on the wrong row should not end the session, reboot the
machine, or power it off. The confirmation lists **Cancel** first, so the
accidental answer is also the safe one. **Suspend does not confirm** — it is
fully reversible, waking the machine undoes it completely, and asking twice
would only be friction on the action used most often.

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

## Sounds

The desktop makes four sounds, and no more. They are meant to be told apart
with your back to the screen, so what distinguishes them is how many notes
they have and how low they sit, rather than how loud they are. Which four
sounds they actually are is a choice - see *Sound packs* below.

| Sound | When | What it is |
| --- | --- | --- |
| `notify` | a notification arrived | one high note, quiet |
| `alert` | something is *waiting* for you | two notes rising, bright and loud |
| `complete` | a long task finished | three notes rising, warm |
| `limit` | a control is already at its limit | one low, blunt, short note |

`alert` is the only loud one, and that is the point of it. A password prompt
is a process that has stopped and will wait forever; everything else is
information you can get to when you get to it.

Three things make each of them happen:

- **A notification** plays `notify`. A **critical** one plays `alert`
  instead, and a **low-urgency** one is silent - a program that told the
  desktop you need not act on something should not then make a noise about
  it.
- **The password prompt** plays `alert` when it appears. Ordinary dialogs -
  a file chooser, a save prompt - stay silent, because you opened those
  yourself a fraction of a second earlier and announcing a window you are
  already looking at is noise.
- **Volume and brightness** play `limit` when the key would do nothing:
  volume-up at 100%, volume-down at zero, brightness-up at full. The keys
  clamp rather than running away, and before this they clamped *silently*,
  which is indistinguishable from a key that has stopped working.

A long command finishing in a terminal makes a noise too, and only when you
are not looking at it. The shell rings the terminal bell after any command
that took more than twenty seconds, foot turns that into a notification when
its window is unfocused, and that arrives as `complete`. Watch the terminal
instead and you get a flash of the window rather than a sound. Programs that
are long by nature - an editor, a pager, `btop`, a Claude Code session - are
excluded, because a bell every time you close your editor teaches you to
ignore every bell.

Set your own threshold, or your own exclusions, in
`~/.config/zsh/local.zsh`:

```bash
LONG_COMMAND_SECONDS=60
```

**Do not disturb silences all of it**, including the two sounds that never
pass through the notification daemon. A desktop that went quiet visually and
kept pinging would be a strange one.

The system volume is the only volume control: each sound has a fixed level
relative to it, chosen so that they sit sensibly against each other, and the
one slider moves all four.

### Sound packs

The four sounds are not one fixed set - they are a **pack**, and more than
one exists:

| Pack | What it sounds like |
| --- | --- |
| `chime` | the default: a struck-glass ping, one timbre, four shapes |
| `ps2` | a soft rounded blip that lands from slightly above its pitch, with a little vibrato - a console menu rather than a game |
| `8bit` | square and triangle waves with no pitch bend at all - a real chip could not bend a note, so quick arpeggios do the work instead, the same trick chiptunes have always used to fake a chord on one voice |

Every pack defines the same four events, so switching one never leaves an
event silent - only what it sounds like changes.

```bash
sounds --pack              # pick one from the launcher
sounds --pack ps2          # switch to that pack directly
sounds --packs             # what's available, and which is active
sounds --preview --pack 8bit   # hear a pack before switching to it
```

### Changing them

Nothing audio-shaped is stored in this repository. The sounds are computed on
the machine from a table of frequencies and envelopes - one table per pack -
the same way the wallpapers are computed from a palette, and cached in
`~/.local/share/sounds/<pack>/` - which is disposable, and rebuilt on demand
if you delete it.

```bash
sounds                    # the active pack, then what each event is
sounds --preview          # play the active pack, each event named
sounds --preview alert    # just that one
sounds --regenerate       # build every event of every pack again
```

To use a file of your own for one event, in any pack, and to change your mind
later:

```bash
sounds set complete ~/Music/ding.wav
sounds set complete --default
```

To change what a pack's sounds *are*, edit its entry in the `PACKS` table in
`~/.local/bin/sounds` in the repository and run `./sync.sh`. Each event is a
list of notes with their start times, a decay, a length and a peak level;
`chime`'s notes also carry a `colour` deciding how bright the timbre is, and
`ps2`'s carry a pitch-bend into the note. They are rebuilt whenever that file
changes, so the edit takes effect on its own - for every pack, not only the
one you happen to have selected, so editing one you are not currently using
still reaches it the next time you switch.
