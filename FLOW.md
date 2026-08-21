# Flow

How this repository becomes a running machine, and how a running machine is
kept in step with it afterwards.

[`README.md`](./README.md) is the instructions. This is the explanation: what
runs, in what order, in which environment, and where to change each thing.
[`DECISIONS.md`](./DECISIONS.md) is why any of it was chosen.

## The two entrypoints

| | [`install.sh`](./install.sh) | [`sync.sh`](./sync.sh) |
| --- | --- | --- |
| Run from | a booted Arch live ISO | the installed machine |
| Run as | root | your normal user |
| Target | an empty disk | the machine it runs on |
| Repeatable | no — it erases the disk | yes, that is the point |
| Partitions, bootloader, users | yes | never |
| Packages | installs everything declared | installs what is missing, removes nothing |

`install.sh` is for building a machine. `sync.sh` is for every day after that.
A change is not worth a full rebuild until it is worth a reproducibility test.

## Install: three environments, one payload

The five stages under [`setup/install/`](./setup/install/) do not all run in the
same place. Stages 1 and 2 run in the live ISO against the git clone. Between
stages 2 and 3, `install.sh` copies `setup/` into the new filesystem. Stages 3
to 5 then run inside `arch-chroot /mnt`, where the clone does not exist and the
copy is the only thing there is.

| Step | Runs in | Sees the repository as |
| --- | --- | --- |
| [`01-disk.sh`](./setup/install/01-disk.sh) | live ISO | `setup/` in the clone |
| [`02-base.sh`](./setup/install/02-base.sh) | live ISO | `setup/` in the clone |
| `cp -a setup/. /mnt/opt/arch-setup/` | live ISO | — |
| [`03-system.sh`](./setup/install/03-system.sh) | chroot | `/opt/arch-setup` |
| [`04-desktop.sh`](./setup/install/04-desktop.sh) | chroot | `/opt/arch-setup` |
| [`05-dotfiles.sh`](./setup/install/05-dotfiles.sh) | chroot | `/opt/arch-setup` |

Two consequences that catch people out:

- Stages 3 to 5 hardcode `SETUP_ROOT=/opt/arch-setup`. A path relative to the
  clone works when the stage is run by hand on a live system and fails during a
  real install.
- Only `setup/` is copied. `README.md`, `DECISIONS.md`, `CLAUDE.md`, `docs/`,
  `checks/`, `tools/` and `backlog/` are repository tooling and never reach the
  built machine. Anything a stage genuinely needs at install time has to live
  under `setup/`.

### 1. Disk

`01-disk.sh` takes the target device, demands the word `ERASE`, and builds
GPT/UEFI: a 1 GiB FAT32 ESP and a Btrfs root filling the rest. It creates the
subvolumes `@`, `@home` and `@snapshots`, then mounts them at `/mnt`,
`/mnt/home` and `/mnt/.snapshots` with `compress=zstd`, and the ESP at
`/mnt/boot`.

It detects nvme-style names: a device ending in a digit gets `p1`/`p2`
partition suffixes rather than `1`/`2`.

### 2. Base system

`02-base.sh` refuses to run unless `/mnt` is a mountpoint, reads
[`setup/packages/base.txt`](./setup/packages/base.txt), `pacstrap -K`s it into
`/mnt`, and writes `/mnt/etc/fstab` from `genfstab -U`.

It reads the manifest with a bare `mapfile` and no filtering, so `base.txt`
must stay one package per line with no comments and no blank lines — anything
else is handed to pacstrap as a package name. This is the one manifest with
that restriction, and the mistake does not show up on a machine you are testing
with `sync.sh`, which strips comments from every manifest including this one.

### 3. System configuration

`03-system.sh` sources [`setup/install.conf`](./setup/install.conf) for
`USERNAME`, `HOSTNAME`, `TIMEZONE`, `LOCALE` and `KEYMAP`, then:

- links `/etc/localtime` and syncs the hardware clock
- uncomments the locale, runs `locale-gen`, writes `/etc/locale.conf`
- writes `/etc/hostname` and `/etc/vconsole.conf`
- creates the user with `-G wheel`, and `/etc/sudoers.d/wheel` at mode 440
- enables NetworkManager
- prompts for the root and user passwords, interactively — they are never stored
- runs `bootctl install`, copies `loader.conf`, and renders each entry in
  [`setup/system/loader/entries/`](./setup/system/loader/entries/) with
  `__ROOT_UUID__` replaced by the real root UUID from `findmnt` and `blkid`

The user is created with `/bin/bash`. The login shell is changed in stage 5,
because zsh comes from the dev manifest and does not exist yet here.

Bootloader entries are rendered **only** at install time. `sync.sh` never
touches them: they carry a machine-specific UUID, and rewriting them on a
running system is a good way to make it unbootable.

### 4. Desktop and development packages

`04-desktop.sh` reads [`desktop.txt`](./setup/packages/desktop.txt) and
[`dev.txt`](./setup/packages/dev.txt) through
`grep -Ev '^[[:space:]]*(#|$)'` — so those two, unlike `base.txt`, may carry
comments and blank lines, and do — and installs each with
`pacman -S --needed --noconfirm`.

It then calls [`setup/system/apply-config.sh`](./setup/system/apply-config.sh),
with no `--activate`, because there is no running system inside a chroot to
apply anything to.

The call is here rather than in stage 3 on purpose. `apply-config.sh` enables
units — greetd among them — and a unit only exists once its package is
installed. Enabling greetd before the desktop manifest is installed aborts the
install partway through.

### 5. Dotfiles

`05-dotfiles.sh` runs chezmoi as the target user via `runuser`, with `HOME` set
explicitly, pointing `--source` at `/opt/arch-setup`.

`--source` names `setup/`, not `setup/dotfiles/`, because
[`setup/.chezmoiroot`](./setup/.chezmoiroot) contains `dotfiles` and redirects
chezmoi there. That is what keeps `install/`, `packages/` and `system/` from
being interpreted as home-directory content.

It then sets the login shell to zsh — but only after `zsh -n ~/.zshrc` parses.
Handing over a shell whose rc file errors on every login is worse than leaving
bash in place.

Finally `install.sh` unmounts `/mnt` and powers the machine off.

## What `apply-config.sh` owns

Everything machine-wide that both the installer and `sync.sh` need. Defining it
once is the point: a change that reaches only the installer can never arrive on
a machine that already exists.

- Installs each file in its `CONFIG_FILES` table to its `/etc` destination —
  zram-generator, the zram sysctls, earlyoom's arguments, keyd's map, greetd
  and ReGreet, and the two session desktop entries under
  `/usr/local/share/wayland-sessions/`
- Installs `xdg-terminal-exec` to `/usr/local/bin/`, the one helper that has to
  be found by name on `PATH` rather than by absolute path
- Validates keyd's config with `keyd check` before enabling it, and refuses
  rather than leaving the machine without a keyboard
- Enables `earlyoom`, `greetd` and `keyd`
- Adds the `microcode` mkinitcpio hook, re-enables the `fallback` preset that
  mkinitcpio v40 stopped shipping, and regenerates the initramfs only if
  something changed or an expected image is missing
- Disables `NetworkManager-wait-online`, which nothing here orders after

`--activate` is the entire difference between the two callers. Without it the
script writes files and enables units, which is all a chroot can do. With it,
the change also takes effect now: `sysctl --system`, `daemon-reload`, and
restarts of earlyoom and keyd. Failures there warn rather than abort — the
configuration is already written.

**greetd is deliberately never restarted.** It owns the session of whoever is
running `sync.sh`.

## First boot

1. systemd-boot shows the entries from `/boot/loader/entries/`, defaulting to
   `arch.conf` after a 3 second timeout. `arch-fallback.conf` boots the same
   kernel with the fallback initramfs.
2. systemd starts, `zram0` is created by the generator from
   `/etc/systemd/zram-generator.conf`, and earlyoom and keyd start.
3. greetd takes VT 1 and runs `cage -s -- regreet`: cage is the kiosk
   compositor, ReGreet is the login screen. The other VTs keep their gettys,
   so **`Ctrl+Alt+F2` still reaches a plain text console** if the session will
   not start.
4. ReGreet lists sessions from `XDG_DATA_DIRS`, which greetd's config sets
   explicitly to `/usr/local/share:/usr/share`. That ordering is what lets this
   repository's entries win: `sway-uwsm.desktop` is offered, and
   `sway.desktop` is a `Hidden` entry that suppresses the packaged one so a
   plain non-uwsm session cannot be picked.
5. Logging in runs `uwsm start -N Sway -D sway -- sway`. uwsm wraps the
   compositor in systemd units and reaches `wayland-session@sway.target`.
6. That target pulls in the session components, each enabled by a committed
   symlink in
   `setup/dotfiles/dot_config/systemd/user/wayland-session@sway.target.wants/`.

Symlinks rather than `systemctl --user enable`, because there is no user
session inside the installer chroot to run that in.

The compositor binary is named directly rather than as `sway.desktop`, because
resolving that entry ID through `XDG_DATA_DIRS` finds the `Hidden` file
described above and uwsm refuses to start a hidden session — bouncing straight
back to the login screen with no way in.

## Keeping a machine in step

`sync.sh` runs four phases in a fixed order, and the order is the interesting
part.

1. **Packages.** Every manifest under `setup/packages/` through the
   comment-stripping grep, then `pacman -T` to find what is genuinely missing —
   which understands packages provided under another name — then
   `pacman -S --needed`. Nothing is ever removed.

   It then marks any declared package that pacman has recorded as a
   *dependency* with `pacman -D --asexplicit`. That step is what makes the
   promise in `setup/packages/README.md` true: a package listed in a manifest
   because the system uses it directly — `polkit` is the example — is reported
   as satisfied by `pacman -T` when something else already pulled it in, so
   without this it stays marked as a dependency and `pacman -Rns` on whatever
   pulled it in would still take it away.
2. **Machine-wide configuration.** `apply-config.sh --activate`, as root.
3. **Dotfiles.** `chezmoi status` first, so the run reports what differs before
   changing it, then `apply`. Without a terminal it uses `--error-on-conflict`
   and explains itself rather than blocking forever on a prompt nobody can
   answer. Afterwards it prints the `chezmoi re-add` line for each changed file,
   because a file differs either because the repository moved on or because you
   edited it here, and the second case is one command away from being kept.
4. **Login shell.** Last, and only if `zsh -n ~/.zshrc` parses — the same guard
   stage 5 uses, for the same reason.

Packages before configuration, because a unit only exists once its package is
installed. Configuration before dotfiles. Dotfiles before the login shell,
because switching shells before its rc exists hands over a broken shell.

`sync.sh` also records the path of this checkout with `theme --record-source`,
outside the "something changed" branch — the recorded path is wrong exactly
when the repository has been moved or re-cloned, which is exactly when nothing
else differs.

`./sync.sh --dry-run` prints the package diff and a `chezmoi diff` and changes
nothing.

## Where to change what

| To change | Edit | Reaches a machine via |
| --- | --- | --- |
| Which packages exist | `setup/packages/*.txt` | `sync.sh`, phase 1 |
| Anything under `/etc` | `setup/system/` **and** the table in `apply-config.sh` | `sync.sh`, phase 2 |
| Anything under `~` | `setup/dotfiles/` (chezmoi source naming) | `sync.sh`, phase 3 |
| Machine identity | `setup/install.conf` | fresh install only |
| Disk layout, bootloader, users | `setup/install/01`–`03` | fresh install only |
| Colours | `setup/dotfiles/.chezmoidata/themes.toml` | `sync.sh`, phase 3 |

Adding a file under `setup/system/` without adding it to the `CONFIG_FILES`
table copies nothing. Adding it to a stage script instead of `apply-config.sh`
means it can never reach a running machine — that has already happened once,
and [`checks/session.sh`](./checks/session.sh) caught it.

## Verifying

After any change, on the machine:

```bash
./checks/session.sh          # does the running machine match what the repo intends?
./checks/sway-commands.sh    # is every command the session invokes declared?
./checks/sway-bindings.sh    # is any key bound twice?
```

A real reproducibility test is a fresh VM built from the repository, not a
`sync.sh` on a machine that is already configured — a script that works on an
already-configured machine proves nothing about a rebuild. See
`DECISIONS.md` → "Testing Strategy".
