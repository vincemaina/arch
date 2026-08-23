# Getting work done

A handful of tools exist purely to help you get work done rather than to run
the desktop itself. Most of them have no keybinding — they are reached from
`$mod+space` by name — and none of them is documented anywhere else, which is
the reason this chapter exists.

## Focus music

Run `~/.local/bin/focus-music`, or find "Focus Music" in the launcher. It
shows a list of stations from `~/.config/focus-music/stations` and hands the
chosen one to `mpv` as a background stream — no window, no library, nothing
to manage. Because `mpv-mpris` is loaded (see chapter 4), the bar's media
widget and the hardware playback keys control it exactly as they would
anything else the moment it starts.

Run it again while something is already playing and it does not open a
second stream — it asks "Stop" or "Change station" instead, because stacking
streams is never what pressing the same launcher entry twice means.

**To add a station**, edit
`setup/dotfiles/dot_config/focus-music/stations`. Each line is a name, a tab,
and a direct audio URL:

```text
Chilled downtempo · Groove Salad	https://ice1.somafm.com/groovesalad-128-mp3
```

Comments and blank lines are ignored, and are used in the tracked file to
group stations by mood. Prefer a direct audio stream over a page that has to
be resolved — the radio stations shipped here were each checked returning
audio before being written down, precisely so nothing there depends on a
resolving step that can silently break later. One entry breaks that rule
deliberately: no internet radio station carries Minecraft's soundtrack, so
that station is a YouTube URL which `yt-dlp` resolves each time it starts,
which is why it takes a few seconds to begin and why it is the one station
that can be broken by a change at YouTube's end. `yt-dlp` also lets you point
plain `mpv` at any YouTube or SoundCloud link from a terminal. Run
`./sync.sh` after editing so the change reaches the machine.

## The audio visualiser

"Visualiser" in the launcher opens `cava` in its own terminal
(`app_id=visualiser`). Unlike the bar's other glance tools (the calendar,
`btop`, `nmtui`), this window has no floating rule, so it tiles into your
layout like an ordinary terminal rather than floating over it — worth knowing
if you expect it to behave like the others.

It listens to the default audio output's monitor, not to any particular
player, so it visualises whatever is actually audible on the machine —
focus-music, a video playing in the browser, a notification sound — with no
integration needed. Its colour gradient is drawn from the current theme's
`accent`, `info`, `secondary`, `tertiary` and `urgent` colours.

## The focus timer

A pomodoro timer, run bare for a menu (`~/.local/bin/focus-timer`), from the
launcher's "Focus Timer" entry, or watched live on the bar — the leftmost
cluster of modules carries its own countdown, and clicking it opens the same
menu the command line does.

Defaults are the classic pomodoro numbers: 25 minutes of work, a 5-minute
break, a 15-minute break after every fourth work period, and a 5-minute
postpone if a break lands at a bad moment. They live in
`~/.config/focus-timer/config` as plain `KEY=NUMBER` lines and are yours to
change — edit and `./sync.sh`, no restart needed since the state is read
fresh each time.

**The bar module is not just a readout — it is what drives the timer.** It is
already awake once a second to draw the countdown, and it is what notices a
work period ending and calls back into `focus-timer` to act on it. The
consequence, stated because it is not obvious: **if waybar is not running,
the timer does not advance at all.** That is treated as correct rather than
as a bug — a countdown nobody can see has no business pausing your music in
the background.

**When a work period ends, precisely this happens:** every MPRIS player
`playerctl` currently knows about is checked, and *only the ones actually in
the `Playing` state at that instant* are paused — not every player MPRIS
knows about, and not only `mpv`. Whatever that set turns out to be is
remembered for this break. Only then does a prompt appear — "Take the break",
"Postpone 5 min", or "Stop the timer" — so the music stops the moment the
work period ends rather than only once you answer the prompt, which can sit
on screen for a while. When the break ends (or you stop or postpone), exactly
that remembered set of players is resumed — restoring only what this timer
itself paused, never starting something you had already stopped on your own,
and never touching a player that was already paused when the break began.

State lives under `$XDG_RUNTIME_DIR`, so it is scoped to the current boot — a
crash or reboot never leaves a stuck timer behind.

## Clipboard history

`$mod+v`, or "Clipboard" from the launcher, opens everything you have copied
— text and images both, with real image thumbnails for roughly the most
recent 60 pictures. `Enter` puts the highlighted entry back on the system
clipboard; it does **not** paste it for you. That is deliberate: the correct
paste keystroke differs by application (`Ctrl+Shift+V` in foot,
`Ctrl+V` almost everywhere else, and `Ctrl+V` inside a shell means something
else entirely to readline), and there is no reliable way to ask the focused
window which one it wants — guessing wrong would silently type the wrong
thing, which is worse than one extra keystroke.

`Ctrl+d` forgets the highlighted entry. The last row, "Clear the whole
history", asks for confirmation before wiping everything.

**Worth knowing plainly:** the underlying store (`cliphist`, via
`clipboard-store`) skips anything the source application tags as a password
using the standard `x-kde-passwordManagerHint` mime convention — KeePassXC
and the KDE tools both set it. It has **no way to recognise a secret that
arrives as ordinary text** — a password copied out of a terminal, or out of a
browser's own saved-logins page, looks like any other string and *is*
stored, unencrypted, at `~/.cache/cliphist/db`, alongside the last 750 things
you copied. The per-entry forget and the "clear everything" option exist
because of exactly this.

## Screenshots

Three keys, three different destinations:

| Key | Captures | Goes to |
| --- | --- | --- |
| `Print` | The whole screen | A file |
| `Shift+Print` | A region you drag to select | A file |
| `$mod+Shift+s` | A region you drag to select | The clipboard only, no file |

Files land in your XDG Pictures directory (`xdg-user-dir PICTURES`, falling
back to `~/Pictures` if that is not configured), named
`screenshot-YYYY-MM-DD_HH-MM-SS.png`. The directory is created automatically
if it does not already exist — the earlier version of these bindings wrote
straight into a directory nothing had created, so `grim` failed and the
keypress simply did nothing, which is exactly the kind of silent failure this
repository tries hardest to avoid.

## The notification centre and bell

Notifications pop up (via `mako`) and then vanish after five seconds by
default — this desktop keeps them findable afterwards rather than losing them
the moment they expire.

The bell icon on the bar's left side is hidden until there is something
unseen, and only then shows a count. That count deliberately does **not**
match `makoctl list` (what mako is currently showing on screen) — by the time
you glance at the bar, an ordinary notification has almost always already
expired out of `list` into `history`, so a badge driven only by `list` would
read zero for exactly the case it exists to catch. It instead counts
everything in `list` or `history` newer than the last time you opened the
centre.

Click the bell, or find "Notifications" in the launcher, and you get every
current and past notification in one list: click one to dismiss it, or use
the always-present rows at the bottom to dismiss everything, restore the last
dismissed notification, or toggle do-not-disturb. Opening the centre is what
marks everything as seen and clears the bell's count — the act of looking is
the acknowledgement, there is no separate "mark as read".

Do-not-disturb still receives and records notifications; it only stops them
being drawn. Nothing is lost by turning it on.

## The shortcuts helper

`$mod+Shift+/`, or "Shortcuts" from the launcher, opens a live reference panel
in its own floating, sticky window (parked bottom-right so it stays visible
across workspaces while you work in something else). It is the fastest way
to answer "what works here" for the specific thing you are looking at:

- It **follows focus** by default — switch to neovim and its tab shows
  neovim's actual live keymap; switch to yazi and it shows yazi's; switch to
  a plain terminal or the desktop itself and it shows sway's bindings and the
  bar's click table.
- `Tab` / `Shift+Tab` switch context by hand (and stop following until you
  press `f` again); `/` searches within the current tab; arrow keys or `j`/`k`
  scroll.
- Every context is read from the running system rather than typed out by
  hand — sway's bindings are parsed from the actual config files it loaded,
  and neovim's are asked of a real headless instance — so this panel cannot
  describe a shortcut that does not exist.

`shortcuts --list` prints every context to a terminal in one pass, which is
the quickest way to grep for a specific key from the command line.
