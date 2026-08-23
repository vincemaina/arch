# Recipes

Worked examples, each one complete: what to edit, what to run, how to check
it took, and — because this repository has shipped that bug before — whether
the change reaches a fresh install, a machine you sync, or both. Read
[How it is put together](07-how-it-is-put-together.md) first if any of
the paths below are unfamiliar; this chapter does not re-explain them.

Every recipe that touches `setup/dotfiles/` ends with `./sync.sh` on a running
machine. None of them run `install.sh` — proving a change survives a fresh
build needs an actual VM rebuild, which is outside the scope of a single edit.

## Previewing a template before you apply it

Several recipes below edit a `.tmpl` file. Before running `sync.sh`, render it
to a scratch directory to catch a template error early and read what a
consumer will actually receive:

```bash
mkdir -p /tmp/render
chezmoi --source ./setup --destination /tmp/render apply --force
```

The `mkdir` is not optional — chezmoi creates directories below the
destination but not the destination itself, and skipping it fails every
template identically with something that looks like a template error and
is not.

This is **not a dry run**. `setup/dotfiles/` contains `run_onchange_` scripts,
and chezmoi runs scripts regardless of `--destination` — rendering to
`/tmp/render` still executes them against the real machine. The mime-defaults
script really does call `xdg-mime`; the theme-reload script really does
restart Waybar. Add `--exclude=scripts` when you only want to see what a
template produces and nothing else to happen:

```bash
chezmoi --source ./setup --destination /tmp/render apply --force --exclude=scripts
```

## 1. Add a package

Add the package name to whichever manifest fits: `setup/packages/base.txt`
for something the core bootable system needs, `desktop.txt` for Sway and
graphical software, `dev.txt` for development and terminal tools.

`base.txt` is read unfiltered by `02-base.sh` — one bare package name per
line, no comments, no blank lines. `desktop.txt` and `dev.txt` are read
through a comment-stripping grep, so a `#` comment above a group of related
packages is fine there. See
[How it is put together](07-how-it-is-put-together.md) → "The package
manifests, and their two parsers" for why that distinction matters more than
it looks like it should.

Apply it:

```bash
./sync.sh
```

Verify:

```bash
pacman -Qi <package>
./checks/packages.sh
```

`checks/packages.sh` also catches manifest hygiene problems — a comment
accidentally added to `base.txt`, a duplicate line, a name with stray
whitespace — that would not show up on the machine you are testing on.

Reaches: **both**. `install.sh` installs it during `02-base.sh` or
`04-desktop.sh` depending on the manifest; `sync.sh` installs it on a machine
that already exists.

## 2. Add or change a dotfile

Add or edit the file under `setup/dotfiles/`, using chezmoi's source naming:
`dot_config/mako/config` becomes `~/.config/mako/config`, `dot_zshrc` becomes
`~/.zshrc`. Make it a `.tmpl` file only if it needs to read theme colours or
another templated value — a plain file is copied as-is.

If it is a template, preview it first (see above). Then:

```bash
./sync.sh
```

`sync.sh` prints every file that differs before applying, and after applying
prints the `chezmoi re-add` command for each one — useful if the difference
turns out to be a local edit worth keeping rather than a change from the
repository.

Verify:

```bash
chezmoi --source ./setup diff       # nothing left pending
cat ~/.config/mako/config           # the file on disk matches what you wrote
```

Reaches: **both**. `05-dotfiles.sh` applies the same dotfiles at install time;
`sync.sh` re-applies them afterwards.

## 3. Add a keybinding

Add a `bindsym` line to
`setup/dotfiles/dot_config/sway/config.d/50-keybindings.conf` (or
`51-modes.conf` if it belongs inside a mode, `52-media-keys.conf` for a
hardware key). Follow the organising rule at the top of that file: `$mod`
chords are for window management only; an application gets a binding only if
it is one of the three already privileged that way, otherwise it goes through
`$mod+space`.

Use `--no-repeat` unless holding the key is the intended gesture — sway
repeats a held binding, and this desktop's repeat rate is fast enough that a
fractionally long press on an unguarded `$mod+q` closes every window on the
workspace. `checks/sway-bindings.sh` fails on a repeatable binding that is not
on its explicit allow-list, so an omission is caught rather than discovered by
holding the key too long.

```
bindsym --no-repeat $mod+n exec ~/.local/bin/some-helper
```

Before syncing, check the binding does not already exist and that nothing
repeats it should not:

```bash
./checks/sway-bindings.sh
```

This reads the repository, not the running system, so it works before you
apply anything. It also prints the full binding table, which doubles as a
reference for what is already taken.

Apply and verify live:

```bash
./sync.sh
swaymsg reload            # or $mod+Shift+c
```

Then press the key combination and confirm the action happens. If it silently
does nothing, `swaymsg -t get_binding_state` and `journalctl --user -b` are
where to look next — see the `desktop-verification` skill for trialling a
binding at runtime before it is even committed to the config.

Reaches: **both**. Sway's config is a dotfile, applied the same way as any
other — `05-dotfiles.sh` at install time, `sync.sh` afterwards.

## 4. Add a theme

Add a new `[themes.<name>]` table to
`setup/dotfiles/.chezmoidata/themes.toml`, copying every key from an existing
theme so nothing is missing — a theme that omits a key any other theme
defines is not caught until someone selects it, at which point every
`chezmoi apply` using it fails with a template error.

Two hard rules, both enforced by `checks/session.sh`:

- **Every theme must declare `mode`**, `light` or `dark`, and it has to match
  the background it declares — a light palette calling itself dark would send
  GTK, neovim and foot the wrong way while looking right in the file.
- **Every theme must define every key every other theme defines**, including
  the sixteen `term.*` ANSI colours.

Writing a light one is not a matter of inverting a dark one. Two values need
aiming at deliberately: `warning` and `info` have to go dark enough to clear
4.5:1 against a near-white background, which the bright amber and blue of a dark
theme do not; and `tertiary` fills the focused workspace disc with `text` on
top, so it flips from a mid-dark colour to a light tint.

There are also two contrast floors checked mechanically:
`muted` against `bg` (the CPU/memory readouts) and `text` against `tertiary`
(the workspace number on its own disc), both at least the ratio the comments
in `themes.toml` state. Names are by role, not by colour — write `accent`,
`urgent`, `muted`, not what hue they happen to be.

Do not select the new theme in `themes.toml` itself unless you want it to
become the tracked default for every machine and the installer — see recipe 8
for how selection actually works.

Verify the theme is well-formed before switching to it:

```bash
./checks/session.sh
```

Its "Themes" section renders `themes.toml` through chezmoi's own data merge
(not a second parser) and checks completeness, darkness by proxy of the
contrast floors, and that the reload script still watches the right three
signals.

To actually see it, switch to it and sync — see recipe 8, "Change a colour",
for the switch mechanism and the reload it triggers.

Reaches: **both**, in the sense that the palette itself is a dotfile
(`.chezmoidata/themes.toml`) reached by `sync.sh` phase 3 and by
`05-dotfiles.sh`. Which theme is *selected*, however, is machine-local — see
recipe 8.

## 5. Add a session component as a systemd user unit

Write the unit to `setup/dotfiles/dot_config/systemd/user/<name>.service`.
Model it on an existing one, e.g. `mako.service`:

```
[Unit]
Description=<what it does>
PartOf=wayland-session@sway.target
After=wayland-session@sway.target
Requisite=wayland-session@sway.target

[Service]
Type=simple
ExecStart=%h/.local/bin/<helper>
Restart=always
RestartSec=1

[Install]
WantedBy=wayland-session@sway.target
```

Bind it to `wayland-session@sway.target`, never `graphical-session.target` —
the generic target is reached by every compositor, and this desktop's
components generally assume sway specifically (calling `swaymsg`, expecting
a sway-shaped bar). See
[How it is put together](07-how-it-is-put-together.md) → "Session
components are systemd user units".

Use `Restart=always`, not `on-failure`. A session component has no legitimate
reason to exit, and `on-failure` treats a clean exit — including a deliberate
`pkill` — as success, which leaves the component dead with nothing to notice.

Enabling has to happen without `systemctl --user enable`, because the
installer chroot has no user session to run that in. Instead, add a committed
symlink under `wayland-session@sway.target.wants/`. chezmoi's `symlink_`
prefix is what turns the source file into a real symlink on apply, and its
content is the relative target — a plain text file, not an actual on-disk
symlink; check an existing one (`symlink_mako.service`) for the exact
convention. Write the target with no trailing newline:

```bash
printf '../%s.service' '<name>' \
    > setup/dotfiles/dot_config/systemd/user/wayland-session@sway.target.wants/symlink_<name>.service
```

Apply and verify:

```bash
./sync.sh
systemctl --user status <name>
systemctl --user show <name> --property=Restart --value   # expect: always
```

`./checks/session.sh` also checks this automatically — its "Session
components" section reads the actual symlinks under
`wayland-session@sway.target.wants/` rather than a hardcoded list, so a newly
added unit is picked up without editing the check.

Reaches: **both**. The unit file and the symlink are both dotfiles under
`setup/dotfiles/`, applied by `05-dotfiles.sh` and by `sync.sh` phase 3 alike.

## 6. Add a machine-wide config file under `/etc`

Put the file under `setup/system/` (there are subdirectories per component —
`greetd/`, `keyd/`, `sysctl.d/`, `tmpfiles.d/` — follow the existing
grouping), then add a `"source:destination"` line to the `CONFIG_FILES` array
in `setup/system/apply-config.sh`:

```bash
CONFIG_FILES=(
    ...
    "mycomponent/config.conf:/etc/mycomponent/config.conf"
)
```

Adding the file under `setup/system/` without adding this line copies
nothing — `apply-config.sh` only ever installs what is in the table, not
everything it finds on disk. Adding the line to a stage script instead of
`apply-config.sh` means the file reaches a fresh install but never a machine
that already exists, which is the exact bug `apply-config.sh` was written to
close — see
[How it is put together](07-how-it-is-put-together.md) → "What
`apply-config.sh` owns".

If the file needs a systemd unit enabled to have any effect, add the unit
name to `ENABLE_UNITS` in the same script — but only once its owning package
is already installed by the time `apply-config.sh` runs; that ordering is why
the call sits in `04-desktop.sh` and not `03-system.sh`.

Apply:

```bash
./sync.sh
```

Verify:

```bash
cat /etc/mycomponent/config.conf     # matches the repository file
systemctl status <unit>              # if you enabled one
```

Remember what `--activate` does and does not restart: `sync.sh` always passes
it, which restarts `earlyoom` and `keyd` and reloads sysctls, but **never
restarts greetd** — a greetd config change applies at the next login, not
immediately, because restarting it would kill the session you are running
`sync.sh` from.

Reaches: **both**. `apply-config.sh` is called by `04-desktop.sh` (no
`--activate`, since there is no running system in the chroot to activate
anything on) and by `sync.sh` (`--activate`, so it also takes effect now).

## 7. Add a helper script to `~/.local/bin`

Create `setup/dotfiles/dot_local/bin/executable_<name>`. The `executable_`
prefix is what makes chezmoi set the execute bit — a script placed there
without it is applied as a plain, non-executable file.

Start it with a `# requires:` header listing every external command it
calls, on the same line:

```bash
#!/usr/bin/env bash
set -euo pipefail

# requires: jq curl notify-send

...
```

This is not optional. `checks/sway-commands.sh` fails a helper with no
`# requires:` header outright, because it has no reliable way to work out
what an arbitrary shell script might call — the header is the one thing
declaring that mechanically rather than by inspection. The bug this closes
was silent: media keys once called `playerctl`, which was in no manifest, so
pressing them did nothing and nothing reported an error anywhere.

Call it by its **absolute path**, `~/.local/bin/<name>` (or `%h/.local/bin/`
in a unit file), from sway config or another unit — never by bare name.
Waybar and every session unit run as systemd user services, whose `PATH`
does not include `~/.local/bin`; only interactive shells get that, via
`.zshrc`. A helper that calls a sibling helper by bare name has the same
problem and fails the same way, silently, from a click that appears to do
nothing.

Apply and verify:

```bash
./sync.sh
which <name>              # ~/.local/bin/<name>, once a new shell has PATH set
<name> --help              # or however it reports itself
./checks/sway-commands.sh  # every command it calls resolves to a declared package
```

Reaches: **both**. It is a dotfile like any other under `dot_local/bin/`.

## 8. Change a colour

Edit the value in `setup/dotfiles/.chezmoidata/themes.toml`, under the theme
you want to change — never in a rendered file (sway's config, the Waybar
stylesheet, and so on). Every consumer holds its own rendered copy read from
this one source; editing a rendered copy directly is overwritten on the next
`sync.sh` and leaves every other consumer still showing the old colour, which
is exactly the kind of drift this repository's theming exists to prevent.

Which theme is *selected* is separate from the palette itself, and it lives
outside the repository — in `~/.config/chezmoi/chezmoi.toml` under `[data]`,
deliberately, so switching leaves no diff to review. Change it with the
switcher rather than by hand:

```bash
theme               # pick one from the launcher
theme <name>         # switch directly
theme --current       # what is selected now
theme --list           # every theme, and which is current
```

`~/.local/bin/wallpaper` works the same way for the background style within a
theme, remembered per theme (`wallpaper --current`, `wallpaper --list`). Both
write through `~/.local/lib/desktop_config.py`, the only thing that reads or
writes `chezmoi.toml` — editing that file by hand risks the nested-table bug
these tools exist to avoid.

Preview the palette change before syncing (see the top of this chapter). Then:

```bash
./sync.sh
```

Applying re-runs `run_onchange_after_reload-theme.sh.tmpl`, because that
script's rendered content embeds the theme name, the wallpaper style and a
hash of the palette — any of the three changing is what tells chezmoi to
re-run it. It reloads sway (which also restarts `swaybg`), reloads mako,
restarts Waybar, and pushes the new colorscheme into any running Neovim.
**foot is the one consumer that cannot be reloaded live** — terminals already
open keep the colours they started with; only new ones pick up the change.

Verify:

```bash
theme --current
wallpaper --current
./checks/session.sh          # "Themes" section: contrast floors, completeness, the live wallpaper matches the selection
```

Reaches: **both**, but only in the sense that the palette itself is a
dotfile. Which theme a fresh install boots with is whatever `theme` is set to
in the tracked `themes.toml` — a machine's own selection in
`chezmoi.toml` is local to that machine and never installed by `install.sh`,
which has no user config to read yet.

## 9. Build (or rebuild) the base VM image

`~/.local/bin/vm` (see [Applications](04-applications.md) → "Virtual
machines") clones every new machine from one base image, and that image is
built by `tools/build-vm-image.sh` — not downloaded, not shipped with the
repository.

```bash
sudo ./tools/build-vm-image.sh
```

Run this yourself, at a real terminal — not through a script that pipes
answers into it. Partway through it asks for a root password and a user
password, the exact same `passwd` prompts a fresh install makes. That is
deliberate — see `DECISIONS.md` → "Passwords" — and this builder does not
weaken it; it drives the real, unmodified installer stages, so the same
interactive prompt is what you get.

What it actually does is run every stage under `setup/install/` in order — the
same numbered scripts `install.sh` runs, completely unmodified — against a scratch
qcow2 attached over `nbd`, so the base image genuinely is a fresh install
built by this repository's own installer, not an approximation of one. It
cannot simply call `install.sh` itself: that script ends by powering off the
machine it ran on, correct on the live ISO `install.sh` expects and wrong on
a running desktop, and stage 3's `bootctl install` would — unmitigated — write
real UEFI boot entries onto the host's firmware rather than the scratch
disk's, since `arch-chroot` mounts a live view of the kernel's EFI state
inside the chroot regardless of which disk you meant. The builder neutralises
this by shadowing that one path with an empty `tmpfs` for the duration of
stage 3 only; nothing about stages 1, 2, 4 or 5 needs it.

Verify:

```bash
vm list                 # shows base.qcow2 and its size
ls -l ~/.local/share/vm/base.qcow2   # mode should have no w bits: it is read-only
vm new probe && vm run probe         # clone it and confirm it boots
```

**Rebuilding an existing base image is refused while any machine still clones
from it** — `vm rm` them first, or pass `--output` for a different path. Every
overlay names the base by absolute path as its backing file; replacing the
file at that path with different content is the same corruption as writing to
it directly, just reached by substitution instead.

Reaches: **neither**, directly — this is a one-time (or occasional) local
build step, not something `sync.sh` or a fresh install does on your behalf.
What it produces, `~/.local/share/vm/base.qcow2`, is what every future `vm
new` reaches for.
