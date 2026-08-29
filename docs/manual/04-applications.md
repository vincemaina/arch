# Applications

This chapter covers what is installed to do the day-to-day work of the desktop,
and how to drive each one. Every helper script named below lives in
`~/.local/bin/` (source: `setup/dotfiles/dot_local/bin/executable_*`). Package
choices and their measured cost are in
[docs/software/README.md](../software/README.md); this chapter is about using
what is already there, not why it was chosen.

## The terminal: foot

Open one with `$mod+Return`. It opens floating if the window you are looking
at is floating, and tiled otherwise — a terminal opened from a floating window
stays floating, one opened from a tile joins the tiling layout.

foot is rendered at `alpha=0.90`, so the wallpaper shows faintly through the
background behind your text. Only the background fades; the glyphs themselves
stay fully opaque, which is different from sway fading the whole window and is
why text stays sharp. A finished command that outlives your attention flashes
the window and, if it is not focused, raises a desktop notification — mpv
finishing a build, or a long command completing on another workspace.

Copy and paste are `Ctrl+C` and `Ctrl+V`, the same keys as everywhere else on
this desktop. That is not how foot ships — it puts them on `Ctrl+Shift+C` and
`Ctrl+Shift+V`, leaving `Ctrl+C` for the interrupt — so this setup swaps the
two pairs round. **The interrupt is now `Ctrl+Shift+C`**: that is the key that
stops a runaway command, and it sends exactly the same byte to the terminal as
`Ctrl+C` used to. `Ctrl+Shift+V` is readline's quoted-insert, which `Ctrl+V`
used to be.

**`Ctrl+C` copies whether or not anything is selected, and never reaches the
program.** foot has no way to make it interrupt when there is no selection —
the action consumes the key unconditionally — so anything that reads `Ctrl+C`
as *cancel* rather than *copy* wants `Ctrl+Shift+C` here: `fzf`, `btop`, a
command you want to stop, and neovim if you use `Ctrl+C` to leave insert mode.
This was the deliberate trade of the swap; it is written up in
[DECISIONS.md](../../DECISIONS.md).

`Ctrl+Shift+A` is this setup's other addition — it puts the **whole** terminal
on the clipboard, scrollback included, and tells you how many lines it took.

It is not really select-all, however much the key suggests it: foot has no
select-all action and no way to script a selection, so nothing highlights
when you press it, and the notification is the only sign it worked. Since
selecting everything in a terminal is nearly always the first
half of copying everything, `Ctrl+Shift+A` goes straight to the second half —
there is nothing to follow it with.

**Surprise:** foot cannot reload its colours. Switching the desktop theme
(chapter 5) updates every other consumer live, but a terminal that is already
open keeps the palette it started with — only a new one picks up the change.

## The shell: zsh and the prompt

Interactive shells run zsh with no framework — no Oh My Zsh, just a handful of
`source` lines in `~/.zshrc` for the two packaged plugins
(`zsh-autosuggestions`, `zsh-syntax-highlighting`) plus `starship` for the
prompt.

Worth knowing:

- History is shared and large: 50,000 lines, written as you type (not on
  exit) and deduplicated, so a command run in one terminal is available in
  every other one immediately. It lives at `~/.local/state/zsh/history`.
- `j <fragment>` jumps to your best-matching recent directory (zoxide, bound
  to `j` instead of its default `z`). `jf <fragment>` lists candidates to
  choose from instead of jumping straight there.
- `Ctrl+R` is fuzzy history search, `Ctrl+T` fuzzy-finds a file to insert,
  `Alt+C` fuzzy-changes directory — all fzf, all searching hidden files but
  skipping `.git`.
- `ls`, `ll`, `la` and `lt` are aliased to `eza`; `cat` is aliased to `bat`
  with paging off. Both take their colours from the terminal palette, so they
  follow the theme automatically.

**Surprise, and a load-bearing one:** `~/.local/bin` is only added to `PATH`
by `.zshrc`, which means it is on `PATH` for an interactive shell and nowhere
else — not for waybar, not for sway's own `exec`, not for rofi. Every helper
script this manual describes is called by absolute path from anywhere other
than a terminal for exactly this reason. If you write a new script and it
works when you type its name but not when a keybinding runs it, this is why.

Anything you want on this machine specifically and are content to lose on a
rebuild goes in `~/.config/zsh/local.zsh`, sourced last and not tracked by
chezmoi.

The prompt (starship) shows the directory, the git branch and status (ahead
or behind count, modified/staged/untracked counts), and how long the last
command took — but only if it took more than two seconds. Its colours come
from the selected theme, read fresh on every prompt, so a theme switch needs
no reload here.

## The editor: neovim

`nvim <file>` from any terminal, or `Enter` on a file in yazi (below). There
is no plugin manager doing anything at the moment and no distribution
underneath it — the configuration is built directly on what neovim 0.12
ships: `vim.lsp.config` for language servers, built-in treesitter, and native
completion.

**Nearly every default keybinding neovim ships has been deliberately
deleted** — 69 of them, on startup, confirmed by reading `g:removed_default_mappings`
from a live instance — and only what is listed below (or set by
you) survives. If you know another neovim configuration's muscle memory,
assume none of it works here except vim's own grammar (`dd`, `ciw`, `yy`,
`%`, and so on, which are commands, not mappings, and are untouched).

Verified by asking a headless neovim what is actually mapped (`shortcuts
--mode nvim` does this on the live system) rather than reading the config:

| Key | Does |
| --- | --- |
| `<Space>` | Leader |
| `<Esc>` | Clear search highlight |
| `<C-s>` | Write the file, from normal or insert mode |
| `<C-q>` | Quit neovim, from normal or insert mode |
| `<C-l>` | Move to the split on the right |
| `gc` / `gcc` | Comment a motion / comment this line |
| `J` | Join lines, keeping the cursor in place |
| `n` / `N` | Next / previous search match, centred |
| `gd` / `gD` | Go to definition / declaration |
| `grr` | Find references |
| `gri` / `grt` | Go to implementation / type definition |
| `grn` | Rename the symbol under the cursor |
| `gra` | Code actions (normal and visual mode) |
| `gO` | List symbols in this document |
| `K` | Hover documentation |
| `]d` / `[d` | Next / previous diagnostic |
| `<leader>d` | Diagnostic under the cursor |
| `<leader>q` | List every diagnostic in this file |
| `<leader>f` | Format the buffer |

**Only one direction of split movement is bound, and the missing three are
not an oversight.** `Ctrl+K`, `Ctrl+J` and `Ctrl+H` are Escape, Enter and
Backspace on this machine, rewritten below the compositor, so neovim never
sees the chord — a mapping for them here would look right in the file and
could never fire. **`Ctrl+W` then `k`, `j` or `h`** reaches those three
splits, and is now the only thing that does. See
[The keyboard](03-the-keyboard.md) for what each of those chords cost
elsewhere and what replaced it.

Completion is on and triggers automatically as you type — not only on
`Ctrl-X Ctrl-O` — for any server that supports it.

**Markdown lists continue themselves.** Enter inside a bullet, a numbered item
or a checkbox starts the next one: same marker, same indent, the number
incremented, the box unticked. Enter again on an item you have not typed
anything into clears the marker instead — which is how a list ends, without
deleting anything by hand. It is the one binding missing from the table above,
and deliberately so: it exists only in markdown buffers, and the table is
derived from the ones that exist everywhere.

There is no column of `~` below the last line of a file. The missing line
number already says the line is not there, and it says it in the same column.

**Which language servers attach depends on the file, and is worth checking
directly rather than assuming.** Verified live on this machine:

| Filetype | Servers that attach |
| --- | --- |
| Python | `pyright` (types, navigation, hover), `ruff` (lint and format) |
| JavaScript / TypeScript (+ JSX/TSX) | `ts_ls` |
| HTML | `vscode-html-language-server`, plus `emmet` |
| CSS / SCSS / Less | `vscode-css-language-server`, plus `emmet` |
| JSON / JSONC | `vscode-json-language-server` |
| Markdown | `marksman` |

A server still attaches to a file outside any project - neovim's default
falls back to a rootless "single file" mode rather than refusing, so a
scratch file with no `.git` or other project marker anywhere above it (e.g.
`/tmp/test.md`) gets a client too, just with no workspace root behind it.
Opening the same file inside a git checkout attaches it with that checkout as
the root instead. Both were confirmed by running headlessly and asking
`vim.lsp.get_clients()` what attached and with what `root_dir`.

**The file saves itself.** A buffer with unsaved changes is written about a
second after you stop typing, in insert mode as well as in normal mode — the
same behaviour other editors call autosave-after-delay. Typing continuously
does not write continuously: the second is counted from the last keystroke, so
a burst of typing is one write at the end of it. `Ctrl+S` still works and is
still the right thing to press when you want to be certain, but it is no longer
the only thing standing between you and the swap-file dialog neovim shows when
a session dies holding changes that never reached the disk.

Four cases are deliberately left alone. Buffers with no file behind them — a
scratch buffer, a terminal, the help viewer — have nothing to write. Read-only
files are not written. Nothing is written while the completion popup is up,
because the write would dismiss it. And if the file has changed on disk since
neovim read it, autosave stays out of the way entirely: writing there raises a
modal *"do you really want to write to it?"*, and a prompt arriving a second
after you stopped typing would eat the next key you pressed. `git checkout`
under an open buffer is enough to cause it. That one is left for a deliberate
`Ctrl+S` to answer.

**`Ctrl+Q` leaves.** It closes every window, so it ends the editor rather than
the split you are in, and it works from insert mode as well as normal mode.
Anything still unsaved gets the *"Save changes to …?"* prompt rather than
being discarded — though with autosave above, the buffers that reach that
prompt are the ones autosave deliberately leaves alone.

It costs one thing, and it is worth knowing before you reach for it: `Ctrl+Q`
used to be how you entered **blockwise visual** mode. That is vim's own alias
for `Ctrl+V`, and `Ctrl+V` does not reach neovim in this terminal because foot
takes it for paste. **Blockwise visual is `Ctrl+Shift+V` here** — the same
modifier the interrupt and quoted-insert moved to, and for the same reason.
In any other terminal `Ctrl+V` still works.

**Formatting is not automatic.** `<leader>f` formats the buffer: through the
attached language server if one offers formatting (`ruff` for Python, `ts_ls`
for JS/TS, the `vscode-*` servers for HTML/CSS/JSON), or through `prettier`
for markdown specifically, since `marksman` does not format. Nothing formats
on save, deliberately — opening a file to read it should not risk reformatting
the whole thing on an unrelated save.

Treesitter highlighting is enabled only where both a parser and a highlight
query are actually present — Python, JavaScript, bash, Lua, Markdown, C, vim
and vimdoc. TypeScript, SQL, HTML, CSS, JSON, YAML and TOML have no parser
package yet and fall back to plain regex highlighting, which is a known gap,
not a bug.

## The browser: firefox

**firefox is the browser.** `$mod+b` opens it, and every link clicked
anywhere else — in a notification, from the launcher, from another
application — opens in it too. There is nothing to configure to get that;
it is what the system default-application mapping already says.

Every launch gives you a new window, the same as `$mod+e` for the file
manager and `$mod+Return` for the terminal. Reaching a window you already
have open is what window switching is for, not what the launch key does. The
window floats and opens at 1500×900.

That is not firefox's own default, which adds a *tab* to whichever window you
used last and raises it — easy to mistake for the key doing nothing at all.
`$mod+b` goes through `~/.local/bin/browser`, which adds `--new-window`.

A link arriving from somewhere else deliberately does **not** get that, and
lands in a tab of the window you already have. Opening a link is a different
intention from asking for a browser, and the two behave differently on purpose.

Starting it is not fast: a little under a second, and closer to 1.2 seconds if
nothing of it is in memory yet. If it feels far worse than that, check the
power profile before anything else — on `power-saver` this machine clocks down
to 800MHz and multiplies every figure by about three. That is the battery icon
in the bar.

**Keyboard navigation is Vimium**, a browser extension that is installed for
you rather than something you add. It gives firefox the vim-style browsing the
desktop is otherwise built around: `j` and `k` to scroll, `f` to click a link
by hint, `/` to search the page, `o` to open a URL, `x` to close a tab, `X` to
reopen one, `?` for the full list at any time. Press `?` rather than trusting
this paragraph — it is the authoritative list and it is one key away.

Vimium arrives over the network on first launch, so a machine set up without a
connection will not have it until the first time firefox starts with one.

**firefox is turned down.** No Pocket, no telemetry, no Normandy studies, no
VPN promotion, no sponsored shortcuts on the new tab page, no first-run tour,
and no update nagging — firefox is a pacman package here, so `sync.sh` updates
it and its own updater could not. None of that was clicked off in
`about:preferences`; it is a policy file the repository installs, which is why
it is the same on every machine built from it and survives resetting your
profile. Some settings are therefore greyed out, and `about:policies` lists
exactly what is in force.

One thing on that list is *not* handled: the **Firefox View** button at the
left of the tab strip. Recent firefox has no policy or preference for it.
Right-click it and choose *Remove from Toolbar*; that is stored in your
profile, so it is a step to repeat on a rebuilt machine.

**Two other browsers are installed**, and `$mod+b` will open either if you ask
it to:

```
browser --current          which one $mod+b opens
browser --list             all three, marking the selected one
browser --use qutebrowser  switch
browser --use vimb
browser --use firefox
```

The choice is one line in `~/.local/state/browser` and survives logging out.
Links from other applications do not follow it — those stay with firefox.

`qutebrowser` was the everyday browser until firefox replaced it, and is
keyboard-driven in its own right rather than through an extension; press
`:bind` inside it for its keys. `vimb` is a very small browser on the same
engine GNOME Web uses, with no tab bar or address bar at all. Both start
faster than firefox — qutebrowser in about 360ms with a warm cache — and both
are on weaker engines that struggle where firefox does not, which is the
trade that made firefox the default.

`Ctrl+Tab` is worth knowing in any of them: sway claims it globally for
switching between tiled and floating windows, so a browser's own tab-cycling
on that chord never reaches it.

## The file managers: yazi and Thunar

**There are two, deliberately, and both stay.** They were on a clock for a
while — one of them was going to be deleted — and the answer turned out to be
that they are not two versions of one tool. yazi is keyboard-native and quick
for a small job done and closed, which is the shape of nearly everything. Thunar
has thumbnails, a bulk rename with a preview column, a sidebar of drives, and a
mouse you can drag a file out of into another window. yazi cannot do any of
those at all. Deleting either would delete a capability rather than a duplicate.

**`$mod+e` opens the one you have selected. `$mod+Ctrl+e` opens the other.** So
the everyday one is under your hand and the other is one extra modifier away,
without switching anything:

```
explorer --current      which one $mod+e opens
explorer --list         both, marking the selected one
explorer --use yazi     switch
explorer --use thunar
```

Out of the box that is yazi on `$mod+e` and Thunar on `$mod+Ctrl+e`. Selecting
Thunar swaps them, and both keys follow immediately — there is no sway reload,
because the keys run a helper that reads the setting at the moment you press
them.

The choice is one line in `~/.local/state/explorer` and survives logging out.
It is machine-local and deliberately not in the repository, the same as your
theme, so switching leaves no diff and `explorer --current` is the only way to
find out what a given machine is set to. Opening a folder from another
application does not follow it — that stays with `terminal-here.desktop`, which
gives you a terminal in the directory.

This is the same arrangement `browser --use` gives the three browsers, with one
difference: browsers get a single key, because you want *a* browser and the
question is only which. These two get a key each at once, because you reach for
them for different jobs rather than interchangeably.

### Thunar

Opens floating at 1100×700, the same size as yazi — so the window does not
change shape depending on which one a key is currently set to.

Its keys have been remapped to vim ones, in
`~/.config/Thunar/accels.scm`:

| | |
| --- | --- |
| `h` / `l` | up a level / open |
| `Shift+H` / `Shift+L` | back / forward through history |
| `y` `d` `p` | copy, cut, paste |
| `x` | to the wastebasket |
| `r` | rename |
| `u` / `Ctrl+R` | undo / redo |
| `/` | search |
| `.` | show hidden files |
| `t` / `q` | new tab / close window |

**`j` and `k` are missing, and cannot be added.** Thunar's keys are GTK
accelerators, which fire menu actions — and moving the selection is not a menu
action. Cursor movement belongs to the list widget, whose keys can only be
changed globally for every GTK application on the machine. So the cursor moves
with the arrow keys. `gg` and `G` are gone for a second reason as well: an
accelerator is one chord, never a sequence, so no two-key motion is
expressible.

That limit is the honest difference between a keyboard-native file manager and
a graphical one wearing vim keys, and it is why yazi is the default rather than
this one.

The file is **read-only on purpose**, because Thunar rewrites it on every quit
and that would mean drift after every session. To change a binding, edit it in
the repository and run `sync.sh`. Thunar's own Configure Shortcuts dialog will
not save.

One collision worth knowing: Thunar's stock key for showing hidden files is
`Ctrl+H`, and on this machine that never arrives — keyd rewrites `Ctrl+H` to
Backspace, which Thunar reads as *go back*. That is why hidden files are on `.`
instead.

### yazi

The default, so `$mod+e` unless you have said otherwise. Opens in its own
floating terminal (1100×700). Navigation is
yazi's own vim-style scheme — confirmed live with `shortcuts --mode yazi`,
which is also the fastest way to see the full current list without leaving
the keyboard.

Two things are specific to this setup rather than yazi defaults:

- `Enter` on a directory moves into it; `Enter` on a file opens it in neovim
  and returns to yazi when you quit. `o` does the same thing, because that is
  yazi's own binding for it. Both use one wrapper script
  (`~/.local/bin/yazi-open`) to decide which one you meant — yazi's own default
  rule for a directory would otherwise try to *edit* it.
- `Ctrl+o` opens a terminal in the directory you are standing in, and closes
  yazi behind it — the terminal is a place to go and do something, and yazi has
  done its job by finding the location. `o` used to open one at the entry under
  the cursor; it was given back to yazi, and nothing is bound to that now.
- `M` opens the mount manager: every disk on the machine and every partition
  on it, mounted or not. `j` and `k` move, `m` mounts, `u` unmounts, `e` ejects,
  `l` steps into the mount point of the highlighted partition, and `q` closes
  it. A drive it mounts lands under `/run/media/`, and `l` takes you there.

### Why there is no sidebar

Every graphical file manager keeps a list of places down its left-hand edge,
and external drives appear in it. yazi has no such list and cannot be given
one: its layout is three fixed columns — the parent directory, the current
one, and the preview — with no fourth pane to put one in.

`M` is the answer to what that list was for. It is a popup rather than a
permanent strip, which suits a thing you want a few times a week rather than
constantly, and it does the part a sidebar cannot anyway: a drive that is not
mounted yet has no path to click on.

Plugging in a USB stick and mounting it asks for no password. Mounting a
partition on one of the machine's own internal disks — a Windows partition on
a dual-boot machine, say — asks once, because those are two different polkit
rules and only the removable one is granted to whoever is sitting at the
machine. Both are the stock udisks policy, not something set here.

The plugin behind `M` is [mount.yazi](https://github.com/yazi-rs/plugins),
written by yazi's own authors. It is the one piece of third-party code this
setup vendors — copied into the repository rather than downloaded when the
machine is built, because a fresh install has no guarantee of a network and a
plugin that is not there does nothing at all and says nothing about it. See
`setup/dotfiles/dot_config/yazi/plugins/README.md` for how to update it.

## The git tool: lazygit

`$mod+g`, or the "Git" entry in the launcher, runs `~/.local/bin/git-ui`,
which opens `lazygit` in its own terminal for the repository containing the
*focused window's* working directory — not `$HOME`, which is not a
repository. It walks the process tree of whatever window has focus down to
its newest child process and reads that process's current directory, so it
is almost always right about "the repository I am looking at." If nothing
focused is inside a repository, you get a desktop notification saying so
instead of a window offering to `git init` your home directory.

lazygit runs on its own default keybindings, shown live at the bottom of
every panel — there is no repository-specific keymap to learn separately.
One setting worth knowing: the command log stays on, so every keypress prints
the literal `git` command it just ran, which doubles as a way to learn git
itself rather than only lazygit.

## The calendar

Click the clock in the bar, or run `~/.local/bin/calendar`. It opens a small
floating terminal (`cal -3`) showing last month, this month and next — no
calendar application, because there is no mail or event data on this machine
to integrate with one against. Clicking the clock again closes it, the same
toggle-by-`app_id` mechanism every glance-and-close window on the bar uses.

**Surprise:** every other terminal on this desktop is translucent
(`alpha=0.90`); this one is rendered fully opaque. Small dense text read for
two seconds was hard to read with whatever was behind it showing through, so
the override applies to this window specifically.

## Media: mpv

mpv is installed as a background *audio* player, not a general video player,
and `~/.config/mpv/mpv.conf` says so explicitly with `video=no`.

**Surprise worth knowing before you reach for it:** because that setting is
global, it applies to every invocation of mpv on this machine, not only the
focus-music helper in the next chapter. Running `mpv some-movie.mp4` plays
the audio track only and opens no window — pass `--video=auto` to get video
back for that one run.

What it does get you for free: `mpv-mpris` makes any stream mpv plays
controllable from the bar's media widget and the hardware playback keys
(play/pause, next, previous, stop), and `yt-dlp` is installed so a YouTube or
SoundCloud link works as an mpv target too, resolved on the fly. mpv's own
keybindings apply inside the terminal it runs in — space to pause, arrow keys
to seek, `9`/`0` for volume, `q` to quit — and were not modified here.

## Virtual machines

For running something you do not trust, or keeping a project's tooling off the
machine you are sitting at. `~/.local/bin/vm` is the whole interface, and with
no arguments it opens a menu of the machines you have.

```bash
vm                    # the menu: pick a machine and start it
vm list               # what exists, how big it is, what it is based on
vm new scratch        # a new machine, cloned from the base image
vm run scratch        # start it
vm reset scratch      # throw away everything it has written
vm rm scratch         # delete it
vm --current          # what is running right now
```

Machines live in `~/.local/share/vm`, one directory each, holding a disk, that
machine's own UEFI variable store, and a `vm.conf` naming how much memory and
how many CPUs it gets. Edit that file and the next `vm run` picks it up.

**A new machine costs almost nothing and appears instantly.** It is not a copy
of the base image but an *overlay* on it — a nearly empty file that records only
what the guest has written since it was made. That is also why `vm reset` is
instant: it deletes the overlay and makes a fresh one, rather than reinstalling
anything.

**Surprise worth knowing:** the flip side of that is that the base image must
never be modified. Every machine cloned from it reads through to it, so writing
to it corrupts all of them at once — and the damage shows up in the clones,
which is a confusing place to meet it. The image is left read-only, and
`vm run` says something if it has stopped being so.

The other thing worth knowing is that a guest is **exempt from the
out-of-memory killer**. Everywhere else on this machine, `earlyoom` kills the
biggest reasonable thing when memory runs short; killing a running guest would
be a power cut to the machine inside it, so qemu is excluded. What keeps that
safe is the memory cap in `vm.conf` — a guest cannot grow into memory the host
is no longer allowed to reclaim. Raise that number thoughtfully.

**Where the base image comes from.** It is not downloaded or shipped with the
repository — nothing image-shaped is tracked here, the same rule wallpapers
follow. `tools/build-vm-image.sh` builds it, on the machine, using this
repository's own installer against a scratch disk attached over `nbd`, rather
than an ISO. It asks for a root password and a user password partway through —
the same prompts a fresh install makes — so it needs a real terminal to run in,
not a script driving it. See
[Recipes](08-recipes.md) → "Build (or rebuild) the base VM image" for how.

**The left Alt / left Control swap (see [The keyboard](03-the-keyboard.md))
still works inside a guest, and only because the guest's own copy of it is
switched off.** The base image is built from this same repository, so a
freshly cloned machine has `keyd` installed and enabled exactly like the
host - but by the time a keypress reaches a guest window, the host's `keyd`
has already swapped it, and a second swap inside the guest would cancel the
first. `setup/system/keyd/keyd.service.d/override.conf` keeps `keyd` from
starting whenever the machine it is running on carries the marker `vm` sets
on every guest it launches, which is every guest built from this image.
Nothing to configure; it is why the swap "just works" the same way in a
guest as it does everywhere else, rather than a coincidence worth relying
on. This is deliberately not "whenever the machine is a VM at all" - a
top-level VM running this desktop as its only OS, with no host-side `keyd`
above it, gets the swap applied exactly like bare metal. See `DECISIONS.md`
→ "Keeping a VM guest's keyboard from double-swapping the host's remap".

Machines that are not this setup work too:

```bash
vm new debian --blank 20G --iso ~/Downloads/debian.iso
```

That gives a machine with an empty disk and the installer attached. Clear the
`ISO` line in its `vm.conf` once it is installed, or it boots the installer
again every time.

## Booting a virtual machine at the login screen

The login screen offers a second session alongside Sway: pick **Virtual
machine** instead of logging in normally, and the machine boots straight into
a guest with nothing else running - no Sway, no Waybar, no notifications, no
idle handling. See [Getting started](01-getting-started.md) → "From power
button to desktop" for where this fits in the boot sequence.

It runs the same menu as `vm` with no arguments, hosted by `cage` - the kiosk
compositor that already draws the login screen itself, so this session costs
no additional package. Whatever you pick behaves exactly as it does from
inside Sway: `vm new` clones from the base image, an existing machine boots
straight in. Exiting the guest - shutting it down, or closing its window -
returns you to the login screen, because that is cage's entire lifecycle:
it runs one thing, and ends when that thing does.

**Why a separate session rather than just running `vm` from inside Sway**,
which already works: a guest running under Sway shares the keyboard with
every Sway keybinding. `$mod`-anything is intercepted by Sway before the
guest ever sees it, which matters if the guest's own desktop wants to use
Super for anything. `cage` defines no keybindings of its own - confirmed by
its own `--help` and manual page, which document no configuration mechanism
for any - so a key that reaches cage's compositor reaches the guest, full
stop. This is the strongest reason for a separate session existing at all;
see `DECISIONS.md` for how it was checked and what a live measurement would
still add.

**The picker remembers your last choice per user.** ReGreet caches the last
session you started and preselects it next time - so a boot after using the
Virtual machine session opens back to Virtual machine, not Sway, until you
change the dropdown again. This is ReGreet's own behaviour, not something
configured here.

**Screen brightness follows from the same fact.** "Every Sway keybinding"
above includes the brightness keys in `52-media-keys.conf`, so a guest run
with `vm run` from inside Sway already responds to them exactly as the rest
of the desktop does - Sway intercepts the key and adjusts the host's real
backlight before the guest ever sees it; nothing guest-side is involved, and
nothing needed to change for this to work. The picture is the opposite in
the two contexts cage hosts before any Sway session exists - ReGreet itself,
and this "Virtual machine" login session: cage's own lack of a keybinding
mechanism, cited above, cuts both ways, so a brightness key reaches the one
client directly and nothing on the host reads it as a shortcut. This was
looked at directly rather than assumed - see TASK-162 in `backlog/` - and
left unsolved on purpose: the only real fix is a new daemon reading raw input
below any compositor, which would then have to detect whether Sway currently
owns the seat to avoid double-handling the same key press once you *have*
logged in. That is a lot of new, privileged, always-running machinery for a
screen seen for a few seconds at a time, so it was not built. If you meet
this screen too dim or too bright, the fix today is a normal login, adjust
it there, then switch sessions - the level Sway leaves the backlight at
carries over to whatever runs next, cage-hosted or not, because it is the
one physical panel underneath all of it.

**One boot-time exception to "carries over": a fixed floor of about 70%,
applied once, before the greeter appears.** The backlight is real kernel
state - TASK-162's finding above, that it "carries over to whatever runs
next" - and that cuts the other way if a session ends with the panel left
near-black: a crash or a dead battery leaves that same near-black level
sitting there through the next boot and into the greeter, which looks like a
dead screen rather than a login prompt turned down low. `brightness-floor.service`
resets brightness to the floor early in boot, ordered before
`greetd.service` so it runs before the greeter is shown, and it always wins
over whatever was last set - even a deliberately low value from the previous
session. It is `Type=oneshot`: it runs once at boot and then does nothing,
so it never fights the brightness keybinding (`XF86MonBrightness{Up,Down}`
in `52-media-keys.conf`) once a session is running, and adjusting brightness
during a session is unaffected and does not carry over any less than before -
only a boot in between resets it back to the floor.
