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

Copying out of it is mostly foot's own doing: `Ctrl+Shift+C` copies the
selection, `Ctrl+Shift+V` pastes. `Ctrl+Shift+A` is this setup's addition — it
puts the **whole** terminal on the clipboard, scrollback included, and tells
you how many lines it took.

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
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | Move between splits |
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

Completion is on and triggers automatically as you type — not only on
`Ctrl-X Ctrl-O` — for any server that supports it.

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

## The browsers: qutebrowser and firefox

Two browsers, for two different jobs, and the system default-application
mapping already sends links to the right one: qutebrowser handles
`http://`, `https://` and `.html` by default; firefox does not open anything
automatically and is reached deliberately.

**qutebrowser** is the everyday, keyboard-driven browser and the one you
should reach for first. `$mod+b` does not simply launch it — it runs
`~/.local/bin/browser`, which finds the most recently focused qutebrowser
window (if any) and moves it to your current workspace instead of opening a
new one. Measured on this machine: a cold start takes roughly 940ms; focusing
an existing window takes about 1ms. qutebrowser is *not* started at login to
save that cost once a day — its QtWebEngine footprint is the single largest
resident thing this desktop can run, and that trade was rejected on purpose.
Its window floats and opens at 1500×900.

Closing qutebrowser's *last* window quits the whole process, so the next
`$mod+b` press pays the full startup cost again — this is why the helper
never uses the same close-toggle mechanism the bar's glance-and-close windows
use.

This repository ships no qutebrowser configuration file, so it runs on
qutebrowser's own defaults: vim-style navigation (`hjkl` to scroll, `o` to
open a URL, `O` to open one in a new tab, `d` to close a tab, `u` to reopen
it, `/` to search the page, `f` to click a link by hint). Those were not
re-verified against a running session for this chapter — press `:bind` inside
qutebrowser for the authoritative, current list. `Ctrl+Tab` is the one
exception worth knowing: sway claims it globally for switching between tiled
and floating windows, so qutebrowser's own tab-cycling on that chord never
reaches it.

**firefox** exists for exactly what qutebrowser structurally cannot do:
Widevine DRM (Netflix and similar) and WebExtensions. qutebrowser's
QtWebEngine ships zero Widevine files — this is not a missing setting, there
is no codec to enable. firefox has no keybinding of its own and is not the
default handler for anything; open it by name from `$mod+space`.

## The file manager: yazi

`$mod+e` opens yazi in its own floating terminal (1100×700). Navigation is
yazi's own vim-style scheme — confirmed live with `shortcuts --mode yazi`,
which is also the fastest way to see the full current list without leaving
the keyboard.

Two things are specific to this setup rather than yazi defaults:

- `Enter` on a directory moves into it; `Enter` on a file opens it in neovim
  and returns to yazi when you quit. Both use `Enter` because a small wrapper
  script (`~/.local/bin/yazi-open`) decides which one you meant — yazi's own
  default rule for a directory would otherwise try to *edit* it.
- `o` opens a terminal at the entry under the cursor; `Ctrl+o` opens one in
  the directory you are standing in. Either closes yazi behind it — the
  terminal is a place to go and do something, and yazi has done its job by
  finding the location.

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
starting whenever the machine it is running on is itself a VM, which is
every guest built from this image. Nothing to configure; it is why the swap
"just works" the same way in a guest as it does everywhere else, rather than
a coincidence worth relying on.

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
