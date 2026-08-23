# Making it yours

The desktop's appearance — colours, wallpaper, what starts automatically, the
bar — is split cleanly into two kinds of thing, and the split matters for how
you change it:

- **Tracked in the repository:** the palettes themselves
  (`setup/dotfiles/.chezmoidata/themes.toml`), the wallpaper generator, the
  bar's configuration. Changing these means editing a file and running
  `./sync.sh`, and every machine built from this repository gets the change.
- **Machine-local, in `~/.config/chezmoi/chezmoi.toml`:** *which* theme is
  selected, and which wallpaper style is chosen for each theme. Changing
  these leaves no `git diff` at all — that is deliberate, so two machines
  syncing the same repository can legitimately disagree about which theme
  they are wearing.

One file writes the machine-local half: `~/.local/lib/desktop_config.py`. Both
`theme` and `wallpaper` call into it rather than editing
`~/.config/chezmoi/chezmoi.toml` themselves — they used to each carry their
own copy of that logic, and the two disagreed about nested TOML tables, which
is the kind of bug that corrupts a config file rather than merely failing.

## Themes

Switch with `theme` (opens a picker in the launcher, showing each theme's
description), `theme <name>` directly, or the "Theme" entry from
`$mod+space`. `theme --list` shows every theme with the current one marked;
`theme --current` prints just the name — the only reliable way to find out
what a machine is actually wearing, since git no longer tells you.

Switching moves sway's borders, the bar, the terminal, the launcher,
notifications, the lock screen, the prompt and the wallpaper together, as one
palette. **Every theme is a dark theme, without exception.** GTK applications
read `GTK_THEME` once at session start (set to `Adwaita:dark` in
`environment.d`) and cannot be recoloured after that, so a light theme in
`themes.toml` would leave every GTK dialog looking like it belonged to a
different, lighter computer for the rest of the session. `checks/session.sh`
enforces that every theme defines every colour key every other theme does, and
two minimum-contrast floors, so a new theme fails at check time rather than
rendering with a missing or unreadable colour.

Colours are named by role — `accent`, `urgent`, `muted`, and so on — not by
the colour itself, so a theme is a mapping from sixteen ANSI terminal slots
and a dozen semantic roles to actual hex values, all living in one TOML file
per theme inside `themes.toml`.

**What actually happens on a switch:** the theme name is written to
`chezmoi.toml`, then `chezmoi apply --force` re-renders every `.tmpl` file
that reads `.theme` — sway's appearance config, the waybar stylesheet, foot,
rofi, mako, swaylock, lazygit, cava, starship. Nothing here reads colours at
runtime; every consumer holds a rendered copy, so a render alone would leave
the running session still showing the old colours until each piece reloads.
That reload is a separate script
(`run_onchange_after_reload-theme.sh.tmpl`) that chezmoi runs automatically
whenever the rendered theme name, wallpaper style, or a hash of the selected
palette changes — which is also why editing a colour directly in
`themes.toml` and running `sync.sh` reloads everything too, not only a named
`theme` switch. It, in order:

1. Generates the new wallpaper first if it is not already cached (see below),
   so the reload below does not show a black desktop while it renders.
2. Runs `swaymsg reload`, which also restarts `swaybg` and picks up the new
   wallpaper.
3. Runs `makoctl reload`.
4. Restarts `waybar.service` — waybar has no live reload for its stylesheet,
   so this is a full restart, back in well under a second.
5. Nudges any neovim instance that happens to be running, over its own
   built-in RPC socket, to re-run `:colorscheme arch` — so an editor open
   during a theme switch actually changes colour without being restarted.

rofi and swaylock need nothing: they read their configuration fresh on every
launch. **foot is the one consumer that cannot reload at all** — a terminal
window already open keeps the colours it started with; only a newly opened
one gets the new theme. This is a foot limitation, not a bug in the reload
script.

To see what a theme edit will actually render before touching a live
machine:

```bash
mkdir -p /tmp/render
chezmoi --source ./setup --destination /tmp/render apply --force --exclude=scripts
```

The `mkdir` is required — chezmoi creates directories below the destination
you give it but not the destination itself. `--exclude=scripts` matters too:
without it, rendering to a scratch directory still *runs* every
`run_onchange_` script against your real, running system — the theme reload
script really does restart your waybar even though the rendered files went
to `/tmp`.

## Wallpapers

Run `wallpaper` for a picker, `wallpaper <style>` to set one directly, or the
"Wallpaper" entry from the launcher. `wallpaper --list` shows what is
available and which is current; `wallpaper --current` prints just the style
name; `wallpaper --path` prints where the actual image file is.

There are four generated styles — `mesh` (soft overlapping colour fields, the
default), `aurora` (vertical curtains of light), `contour` (topographic
lines) and `grid` (a perspective horizon) — all built by
`~/.local/bin/wallpaper` at 1920×1080 from the *current theme's own palette*,
in pure Python with no dependency beyond the standard library. **No image is
tracked anywhere in this repository.** Generated wallpapers are cached at
`~/.local/share/wallpapers/<theme>-<style>.png`; the cache is disposable —
deleting a file costs a second or two to regenerate and nothing else.
`checks/session.sh` fails if any image file ever lands inside
`setup/dotfiles/` at all, so this stays true rather than merely intentional.
See [docs/wallpapers/README.md](../wallpapers/README.md) for how the four
styles are actually drawn.

The style chosen is remembered **per theme**, not globally — switching back
to a theme you used before restores the wallpaper you last picked for it,
rather than resetting to `mesh` every time. That preference is written by the
same `desktop_config.py` helper, under `chezmoi.toml`'s
`[data.wallpaper.<theme>]`, so it is machine-local exactly like the theme
choice itself.

**Images of your own** are the other half of the picker, reached through its
"Image..." entry:

- **Paste a URL** and it is downloaded (`curl`, capped at 50MB and 60
  seconds), checked by magic bytes rather than trusted by extension — a 404
  page saved with a `.jpg` name is rejected rather than becoming your
  wallpaper — and saved into the library named by a hash of its own content.
  Pasting the same picture again, even from a different URL, lands on the
  file already there instead of creating a duplicate; this is deliberate,
  content-addressed deduplication, not an accident of naming.
- **Drop a file** into `~/Pictures/wallpapers` (or wherever
  `xdg-user-dir PICTURES` actually points, plus `/wallpapers`) with a file
  manager and it appears in the picker with nothing else to do.
- **A path directly**: `wallpaper ~/pics/foo.png` or `wallpaper <url>` from a
  terminal does the same thing without opening the picker.

An image of your own does not follow theme colours the way a generated style
does — that is expected, not a bug, since there is no palette to derive it
from. It also lives outside the generated cache, in `~/Pictures/wallpapers`
rather than `~/.local/share/wallpapers`, precisely because it is *not*
disposable: a picture you downloaded or made should not sit somewhere a
cleanup of the generated cache would reasonably empty.

## Startup toggles

`startup` controls what the session starts with, for a small, deliberately
limited set of components: `waybar`, `autotiling`, `mako` and `swayidle`. Run
it bare for a launcher picker, `startup --list` to see current state and
memory cost for each, or `startup <component> on|off` to flip one.

It tracks **two separate questions**, because "do I want this at all" and
"get it out of my way for ten minutes" are different requests:

```bash
startup waybar off              # off now, and off at every future login
startup mako --now off          # stopped right now; still starts next login
startup mako --autostart off    # off at the next login only; leave it running now
```

Only components whose absence is *visible and recoverable* are offered.
Notably absent on purpose: the polkit authentication agent, whose absence is
invisible — a privilege prompt would simply not appear and the action would
silently do nothing, which is the exact failure mode this whole system tries
hardest to avoid. `startup --list` explains what is withheld and why, in the
same place you would look for what is offered.

## The bar

`$mod+Shift+b` hides waybar and gives its strip back to the tiled windows;
the same chord brings it back. This is a signal to the running process
(`SIGUSR1`), not a stop-and-restart — waybar's session state, and its
reserved layer-shell strip, come back exactly as they were rather than
starting cold. If waybar is not running at all (switched off at login via
`startup`), the same chord starts it instead.

Every module in the bar does something when clicked — a readout you can only
look at trains you to stop reading it. In short: workspaces switch to the one
clicked; the notification bell opens the notification centre; the focus timer
opens its stop/skip menu; the clock opens the calendar; the media widget
play/pauses on a left click, middle goes back a track and right skips
forward; CPU and memory both
open the same `btop` window; the network reading opens `nmtui`; audio opens
`pavucontrol` and scroll changes the volume; battery swaps to showing time
remaining. The definitive, current copy of this table is the comment block
at the top of `waybar/config.jsonc.tmpl` — reproduced here for orientation
rather than as the source of truth, since that file is what actually renders.

## Changes this machine keeps

Everything above is tracked in the repository, which means `./sync.sh` will
put it back the way the repository says. That is the point — it is how one
change reaches every machine — but it makes the obvious move, editing the
file, the wrong one. Your edit survives until the next sync and then quietly
disappears.

So each machine has a layer of its own, above the repository, that sync never
touches. There are two kinds, and which one you want depends on what you are
changing.

**A setting you want to add or override** goes in that tool's local file. It
is created for you on first install, it is never rewritten, and the tracked
config reads it *last* — so whatever you put there wins.

| Tool | Your file |
| --- | --- |
| The shell | `~/.config/zsh/local.zsh` |
| Sway | any `~/.config/sway/config.d/99-*.conf` |
| Session environment | any `~/.config/environment.d/99-*.conf` |
| keyd (system-wide remapping) | `/etc/keyd/local` |

Editing keyd's file needs `sudo`, and `sudo keyd check` before `sudo keyd
reload` — a config keyd cannot parse leaves the machine with no working
keyboard, and the way out is holding Backspace, Escape and Enter together.

**A value that appears in more than one place** is not an override but a
setting, and lives with the theme in chezmoi's own config at
`~/.config/chezmoi/chezmoi.toml`. Nothing there is tracked, which is why
switching theme leaves no diff in git.

Font size is the worked example. One family and four sizes cover every
surface, so raising the terminal font is one command rather than an edit in
five files:

```bash
python3 ~/.local/lib/desktop_config.py set data.font.terminal 15
./sync.sh
```

The keys are `family`, `terminal` (the terminal), `desktop` (window titles
and notifications), `menu` (the launcher) and `bar` (Waybar, in pixels
because CSS has no points). Set one and the rest keep the repository's
defaults — the merge is per key, not per table. Only `desktop_config.py`
should write that file; two separate writers disagreed about nested tables
once and broke every subsequent sync.

Already-open terminals keep the old size. foot reads its config when it
starts and has no reload.

The dividing line, and it is worth applying honestly: **put things in the
local layer that you are content to lose if this machine is rebuilt.**
Anything you would be annoyed to lose belongs in the repository, where it is
backed up and reaches your other machines. `./sync.sh --dry-run` prints the
`chezmoi re-add` command for anything that has diverged, so folding a change
back in is one command when that turns out to be the right answer.
