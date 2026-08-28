# How it is put together

This chapter is the mental model. Read it before changing anything under
`setup/`. It does not repeat [FLOW.md](../../FLOW.md), which walks the same
ground stage by stage — it explains the shape underneath, so you can predict
where a change belongs without re-deriving it from the scripts each time.
[DECISIONS.md](../../DECISIONS.md) has the rationale for individual choices;
this chapter assumes them and gets on with where things live.

## Two entrypoints, two lifecycles

[`install.sh`](../../install.sh) builds a machine from a booted Arch live ISO.
It is destructive — it erases the target disk — and it is not meant to be run
twice against the same machine.

[`sync.sh`](../../sync.sh) applies this repository to a machine that is
already running it. It is safe to run repeatedly: it installs packages that
are missing, applies machine-wide configuration, re-applies dotfiles, and sets
the login shell. It never partitions a disk, installs a bootloader, or creates
a user — those are one-time, install-time decisions.

The practical consequence: a change is not proven until it has been tested
both ways it can be exercised. `sync.sh` tells you the change works on a
machine that already exists. Only a fresh VM build tells you it works on a
machine that does not yet exist. See `DECISIONS.md` → "Testing Strategy" for
why the second one is the real test and the first one is not a substitute for
it.

## Two execution contexts, one payload

`install.sh` runs its five stages in two different places, and the repository
is copied between them partway through:

| Stages | Run in | Sees the repository as |
| --- | --- | --- |
| `00-wizard.sh`, `01-disk.sh`, `02-base.sh` | the live ISO | `setup/` inside the git clone |
| `cp -a setup/. /mnt/opt/arch-setup/` | the live ISO | — |
| `03-system.sh`, `04-desktop.sh`, `05-dotfiles.sh` | `arch-chroot /mnt` | `/opt/arch-setup` |

Only `setup/` crosses that boundary. Nothing above it — `README.md`,
`DECISIONS.md`, `CLAUDE.md`, `docs/`, `checks/`, `tools/`, `backlog/` — is
copied, so none of it exists inside the chroot. That is why stages 3 to 5
hardcode `SETUP_ROOT=/opt/arch-setup` rather than deriving a path from where
the script itself lives: deriving it would work when you run the stage by
hand from a live checkout, then fail during a real install, because the two
contexts disagree about where `setup/` is.

This is the single fact that predicts where a new script's paths may point.
A script that only ever runs in stages 3–5, or is called by them, may
reference `/opt/arch-setup` and nothing else — the clone is not there. A
script that runs in stage 1 or 2 sees the clone and may use paths relative to
it. `sync.sh` and everything under `checks/` and `tools/` are a third context
again: they run on a fully installed machine, from a git clone, as the normal
user — never inside a chroot, never against `/opt/arch-setup`.

## The `setup/` boundary

Nothing outside `setup/` ends up on the built machine. That is not a style
preference, it is the mechanism above: the `cp -a` only copies `setup/`, and
that is the one and only path anything reaches the chroot by. A stage that
needs a file at install time and reaches outside `setup/` for it will work
when you test it by hand against your live clone and fail — or worse, silently
use a stale copy — during a real install from the ISO.

Two things follow:

- Tools used to develop and manage this repository — `backlog`, this
  `docs/manual/`, `checks/`, `tools/` — must never be added to
  `setup/packages/*.txt`. Those manifests describe what the built machine
  should have installed, not what is convenient for working on the repo.
- Anything a chroot stage genuinely needs at install time has to be moved
  into `setup/` first. If you find yourself referencing `../checks/` or
  `../../DECISIONS.md` from inside a stage-3-to-5 script, that reference is
  already wrong — chroot only ever sees `/opt/arch-setup`.

## What `apply-config.sh` owns

[`setup/system/apply-config.sh`](../../setup/system/apply-config.sh) is the
single source of truth for everything machine-wide that both the installer
and `sync.sh` need. It is called from two places — `04-desktop.sh` at the end
of a fresh install, and `sync.sh` with `--activate` — and that is deliberate:
a machine-wide config file added anywhere else reaches only one of the two
paths, which is a bug this repository has already shipped once and now checks
for.

It owns:

- The `CONFIG_FILES` table: which repository file under `setup/system/`
  installs to which path under `/etc` (or `/usr/local/share`).
- The console keymap: `/etc/vconsole.conf`, from `KEYMAP` in `install.conf` —
  the one thing it reads out of machine identity rather than copying a file
  under `setup/system/`, so a wrong wizard answer can still be corrected by
  `sync.sh` instead of needing a hand-typed fix.
- Rendering the greeter's stylesheet from the selected theme, as the invoking
  user rather than root, so it reflects that machine's own theme choice
  rather than the tracked default.
- Installing `xdg-terminal-exec` to `/usr/local/bin/` — the one helper looked
  up by name on `PATH` rather than referenced by absolute path.
- Validating and enabling `keyd`, refusing to enable it on a config that does
  not parse.
- Enabling `earlyoom`, `greetd`, `keyd` and `systemd-timesyncd` — the last of
  which is what keeps this machine's clock right. It costs no package, since
  timesyncd is part of systemd, and no configuration, since Arch compiles the
  Arch NTP pool in as the fallback. Before it was enabled the clock was set
  once at install and then left to drift for as long as the machine was
  switched off.
- The initramfs story: adding the `microcode` hook, re-enabling the
  `fallback` preset, and regenerating only when something changed.
- Disabling `NetworkManager-wait-online`.

`--activate` is the entire difference between the installer's call and
`sync.sh`'s. Without it, the script only writes files and enables units —
which is all a chroot can do, since there is no running system inside it to
restart anything on. With it, the change also takes effect now:
`sysctl --system`, a `daemon-reload`, restarts of `earlyoom`, `keyd` and
`systemd-vconsole-setup`, and a start of `systemd-timesyncd` — so a machine
that has been off for a while has its clock corrected during the sync rather
than at the next boot.
Failures after `--activate` warn rather than abort the sync, because the
configuration is already written and one service refusing to restart should
not fail everything else that follows it.

**greetd is deliberately never restarted**, activated or not. It owns the
session of whoever is running `sync.sh` — restarting it would end that
session. A greeter config change applies at the next login, not immediately;
`apply-config.sh` says so when it notices greetd is running.

Bootloader templates under `setup/system/loader/` are the one thing
`apply-config.sh` does not own and never will: they are rendered with the
machine's real root UUID at install time, and `sync.sh` must never touch them
— rewriting a boot entry on a system that is currently booted from it is a
good way to make it unbootable.

## How chezmoi is rooted

[`setup/.chezmoiroot`](../../setup/.chezmoiroot) contains the single word
`dotfiles`. That one file is what keeps `setup/install/`, `setup/packages/`
and `setup/system/` from being interpreted as home-directory content: every
chezmoi invocation in this repository passes `--source setup` (or, inside the
chroot, `--source /opt/arch-setup`), and `.chezmoiroot` redirects it to
`setup/dotfiles/` before it looks for anything to apply.

Inside `setup/dotfiles/`, filenames use chezmoi's source naming:
`dot_config/sway/config` becomes `~/.config/sway/config`, `executable_theme`
becomes `~/.local/bin/theme` with the execute bit set. Nothing besides
creating the right `dot_*` or `executable_*` path is needed to add new user
config — chezmoi discovers it on the next apply.

A file ending `.tmpl` is rendered rather than copied verbatim. Templates are
how every themed file — sway's appearance config, the Waybar stylesheet, foot,
rofi, mako, swaylock, starship, the greeter stylesheet — reads the selected
palette from `.chezmoidata/themes.toml` instead of carrying its own hardcoded
colours.

A file named `run_onchange_*` is a script, not a config file, and chezmoi
re-runs it exactly when its *rendered* content changes — which is why the
theme reload script embeds the theme name, the wallpaper style, the glow
setting, the bar size and a hash of the palette as comments near its top:
those five lines are what changing a colour, switching a theme, or resizing
the bar actually invalidates, and deleting one of them silently stops the
script from re-running in the case it exists to cover.

## The package manifests, and their two parsers

`setup/packages/base.txt`, `desktop.txt` and `dev.txt` list one Arch package
per line, but two different pieces of code read them, and they do not agree:

- `02-base.sh` reads `base.txt` with a bare `mapfile` and **no filtering**.
  Every line becomes a package name handed to `pacstrap`. A comment or a
  blank line in `base.txt` is not skipped — it is passed to `pacstrap` as a
  package name, and the install fails.
- `04-desktop.sh` reads `desktop.txt` and `dev.txt` — and `sync.sh` reads
  **all three**, `base.txt` included — through
  `grep -Ev '^[[:space:]]*(#|$)'`, which strips comments and blank lines.

The asymmetry is the trap: a comment added to `base.txt` breaks a fresh
install the next time someone runs `install.sh`, but `sync.sh` strips it out
and keeps working, so nothing on the machine you are testing on ever shows the
problem. `checks/packages.sh` catches exactly this — see its "Manifest
hygiene" section — which is why it is worth running after touching any
manifest, not only after adding a package.

Manifests declare *intentional top-level* packages, not every transitive
dependency. A dependency is still worth listing explicitly when the system
relies on that capability directly — `polkit` is the example both
`packages/README.md` and `DECISIONS.md` give — so that a change elsewhere in
the dependency graph cannot silently remove it. Listing it is not sufficient
by itself: `pacman -T` reports an already-satisfied package as satisfied
regardless of why it is installed, so both `install.sh` and `sync.sh` also
mark every declared package explicit after installing it, and
`checks/packages.sh` fails if one drifts back to being marked as a dependency.

## `sync.sh`'s phases, in order

`sync.sh` runs four phases, and the order encodes two rules that were both
learned by breaking them:

1. **Packages.** Every manifest, comment-stripped, resolved with `pacman -T`
   against what is missing, installed with `pacman -S --needed`, then any
   declared package pacman still has marked as a dependency is switched to
   explicit. Nothing is ever removed.
2. **Machine-wide configuration.** `apply-config.sh --activate`, as root.
3. **Dotfiles.** `chezmoi status`, so the run reports what differs before
   touching it, then `apply`.
4. **Login shell.** Switched to zsh only if `zsh -n ~/.zshrc` parses clean.

Packages before configuration, because a systemd unit only exists once its
package is installed — `apply-config.sh` enables units, and enabling one
whose package is not yet present is a hard failure, not a no-op. Configuration
before dotfiles, so the machine-wide pieces a themed dotfile might assume
(chezmoi itself, the greeter, the initramfs) are already in place. Dotfiles
before the login shell, because switching a user's shell before that shell's
rc file exists hands them a broken login the next time they open a terminal.

`sync.sh --dry-run` runs phase 1's diff and phase 3's `chezmoi diff` and
changes nothing — it is the way to see what a sync would do before doing it.

## Session components are systemd user units

Waybar, mako, swayidle, the polkit agent and autotiling are not started from
sway's `exec` — they are systemd **user units**,
defined in `setup/dotfiles/dot_config/systemd/user/` (Waybar's unit ships
with its package; the repository carries only a drop-in override for it), and
enabled by a committed symlink in `wayland-session@sway.target.wants/` rather
than by running `systemctl --user enable`, because there is no user session
inside the installer chroot to run that command in.

They are bound to **`wayland-session@sway.target`**, a target uwsm creates
specifically for this compositor — never to the generic
`graphical-session.target`, which every compositor reaches. A unit wanted by
the generic target starts under any desktop; sway is the only session this
repository installs today, but a component that assumes sway — Waybar drawing
a sway-shaped bar, swayidle calling `swaymsg` — would silently fail on a
different one the day a second session is added. Binding to the specific
target is what makes that a non-event rather than a surprise. See
`DECISIONS.md` → "Session components bind to the compositor, not the
graphical session".

An `exec` line in sway's config gets no supervision at all: no restart on
crash, no ordering relative to the rest of the session. A plain `sway`
launch — one not wrapped by `uwsm start`, as `sway.desktop`'s `Hidden` entry
exists to prevent — reaches no session target and starts none of this, which
looks like a working, blank desktop rather than an error.

## Where a change belongs

| Changing | Edit | Reaches |
| --- | --- | --- |
| Which packages exist | `setup/packages/*.txt` | both, via `sync.sh` phase 1 / a fresh install |
| Anything under `/etc` | `setup/system/` and the `CONFIG_FILES` table in `apply-config.sh` | both |
| Anything under `~` | `setup/dotfiles/` (chezmoi source naming) | both |
| A session component | a unit in `dot_config/systemd/user/` plus a symlink in `wayland-session@sway.target.wants/` | both |
| Machine identity | `setup/install.conf` | fresh install only |
| Disk layout, bootloader, user creation | `setup/install/01-disk.sh` to `03-system.sh` | fresh install only |
| Colours | `setup/dotfiles/.chezmoidata/themes.toml` | both, via `sync.sh` phase 3 |

The next chapter works through each of these as a complete recipe: what to
edit, what to run, and how to tell the change actually took.
