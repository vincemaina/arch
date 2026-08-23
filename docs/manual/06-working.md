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
second stream. It asks what to do with what is on instead: stop it, play
something else, look at the queue, skip to the next track, or keep the
current one.

### The queue

Pick a station or a search result while something is already playing and you
are asked where it should go:

| | |
| --- | --- |
| **Play now** | start it immediately, and keep everything already queued behind it |
| **Play next** | put it directly after what is playing |
| **Add to queue** | put it at the end |

With nothing playing there is no question — it just plays.

**Queue (n)** in the menu opens the queue itself. The track playing is marked
with `>`, and choosing any entry offers to play it now, move it up or down,
or remove it. **Clear the queue** drops everything except what is currently
playing, so the music does not stop when you tidy up.

The queue is `mpv`'s own playlist rather than a list kept beside it, so there
is no second copy that can disagree about what is lined up. One consequence
is worth knowing: a track that has finished stays in the list above the one
playing, as history, rather than disappearing.

When the last track ends, the music stops and the bar clears. A radio station
never ends, so it plays until you stop it.

The queue is not lost when it finishes. Open `focus-music` again and it says
how many tracks have played out, and offers to play the queue again, open it,
start something else, or stop. Starting something else at that point replaces
the finished tracks rather than stacking on top of them, so the list does not
grow all day.

### Searching YouTube

The first entry in the list is **Search YouTube...**. Choose it, type
anything — a song, an album, an artist, one of the 24/7 study streams — and
the results come back saying how long each one is, or `LIVE` where it is a
live broadcast rather than a recording:

```text
LIVE      lofi hip hop radio - beats to relax/study to
10:00:00  chill music for work - lofi beats to stay productive
1:01:14   1 A.M Study Session
```

Choosing one plays its audio exactly the way a station plays: the same
background `mpv`, the same bar widget, the same playback keys, no window. It
takes a second or two to start, because `yt-dlp` has to resolve the page
first. Channels are filtered out of the results — only things that actually
play are offered.

### Keeping one, and why it keeps the search

Nothing you search for is written down. To keep what is playing, run
`focus-music` again and choose **Keep this station**. It is appended to
`~/.config/focus-music/stations.local`, a file that exists only on this
machine and that chezmoi does not manage — so keeping something is not a
repository change, and `chezmoi apply` will not clobber it. Delete a line to
forget it.

What gets written there is the *search*, not the link:

```text
lofi hip hop radio	search:lofi hip hop radio
```

A video id is a link, and links rot. The video is deleted, or the channel
restarts its 24/7 broadcast under a new id and every id anyone wrote down for
it dies at once — which is not hypothetical, it is what the comments in the
tracked station list describe. A search cannot rot: it is resolved again
every time you press play, so the entry still works after the thing behind it
has moved.

The trade-off is real and worth knowing. A search can drift onto a different
video if the original disappears. Silence would be worse.

### Adding a station by hand

Edit `setup/dotfiles/dot_config/focus-music/stations`. Each line is a name, a
tab, and a target. A target is either a direct audio URL:

```text
Chilled downtempo · Groove Salad	https://ice1.somafm.com/groovesalad-128-mp3
```

or a search, resolved through YouTube when it is played:

```text
Minecraft soundtrack	search:minecraft soundtrack full album
```

Comments and blank lines are ignored, and are used in the tracked file to
group stations by mood. Prefer a direct audio stream where one exists — the
radio stations shipped here were each checked returning audio before being
written down, and they start instantly because nothing has to be resolved
first. Reach for a search when no station carries what you want, which is how
the Minecraft entry got there. Run `./sync.sh` after editing so the change
reaches the machine.

### Checking that nothing has gone dead

```bash
focus-music --check
```

resolves every entry in both files and reports what each one did: a direct
stream is asked for a byte of audio, a YouTube link and a saved search are
both put through `yt-dlp`. Anything that no longer answers is named, and the
command exits non-zero.

```text
  stream   ok             Chilled downtempo · Groove Salad
  youtube  GONE           Something that was deleted
  search   ok             lofi hip hop radio
```

This is the counterweight to a list that can grow: searches look after
themselves, and this is how the handful of real links get pruned on purpose
rather than discovered dead halfway through a working afternoon.

## Spotify

`$mod+m`, or "Spotify" in the launcher, opens a picker: your playlists, your
liked songs, saved albums, followed artists, top tracks, and a search. Choose
something and it plays. No window opens at any point.

Spotify Premium is required — the streaming library this uses cannot play
without it — and you sign in once per machine. The first time you run the
picker it says you are not signed in and offers to do it; a terminal opens,
prints a URL, and your browser takes you through Spotify's normal
authorisation page. After that the tokens live in `~/.cache/spotify-player`
and nothing asks again.

Run it again while music is playing and, like `focus-music`, it offers what
is useful about what is on rather than a bare list to start something else
from:

| | |
| --- | --- |
| **Pause** / **Resume** | whichever applies |
| **Next**, **Previous** | skip |
| **Shuffle** | toggle shuffle |
| **Like this track** | save it to your library |
| **Play something else** | back to the picker |
| **Open the full app** | the library window, below |
| **Stop** | stop playing and shut the player down |

### The library window

`$mod+Shift+m` opens the full Spotify interface in its own floating window,
and pressing it again closes it. **The music does not stop when it closes.**

That is worth stating plainly, because it is the whole shape of this: the
thing playing music is a small background daemon, and both the picker and
this window are remote controls for it. Closing a remote control does not
stop the music. The daemon starts the first time you play something and stops
when you choose **Stop**, so a machine that is not playing music has no
Spotify process running at all.

The window is the place to browse properly — album art, an artist's
discography, a playlist's full track list — and the picker is the place to
start something you already know you want.

### It behaves like everything else that plays

Spotify appears in the bar's now-playing module with a Spotify icon, and
everything in the rest of this chapter applies to it unchanged: the bar
clicks play, pause and skip it, the media keys do the same, `media` seeks
inside a track, and the focus timer pauses it when a break starts and resumes
it afterwards.

None of that is Spotify-specific. All of it works through MPRIS, the same
mechanism `focus-music` uses for `mpv`, which is why adding Spotify needed no
change to the bar, to `media` or to the timer.

### Checking it over

```bash
spotify --check
```

says whether the player is installed, what it was compiled with, whether you
are signed in, whether the daemon is running, and what is playing. When the
daemon is up it also counts your Spotify Connect devices and the MPRIS
players on the machine — both should be one, and counting them is how that
claim is kept honest rather than assumed.

## Controlling whatever is playing

The bar already controls playback and has since the beginning: **left click**
the now-playing module to play or pause, **middle click** for the previous
track, **right click** for the next one. Those are waybar's own defaults, and
they act on whatever is playing — focus-music, a video in the browser,
anything that speaks MPRIS. The keyboard's media keys do the same, on a
keyboard that has them; this one is a ThinkPad, whose F row has volume and
brightness and no play, previous or next at all.

What none of that offers is seeking. "Media Controls" in the launcher, or
`~/.local/bin/media`, opens a menu for the player that is currently going:

| | |
| --- | --- |
| **Play/Pause**, **Next**, **Previous** | the same as the bar clicks, for when a menu is easier to find than a mouse button |
| **Seek...** | jump around inside the current track |
| **Choose player** | only appears when more than one thing is playing |
| **Stop** | stop that player |

**Seek** shows where you are and how long the track is, with a bar:

```text
████████████░░░░░░░░░░░░  1:23 / 3:45
```

Choose one of the jumps — back a minute, back ten seconds, forward ten
seconds, forward a minute, or back to the start — or just type where you want
to be and press Enter. A timestamp like `2:30` or `1:02:03` goes to that
point; a percentage like `40%` goes proportionally through the track. That is
the difference between usable and not on a ten-hour upload.

A live radio stream has no position and no length, so there is nothing to seek
in. The menu says so rather than appearing to work.

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
