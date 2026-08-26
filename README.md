<p align="left">
  <img src="./assets/arch-logo.svg" width="180" alt="Arch Linux">
</p>

# Swaystone

A version-controlled, reproducible Arch Linux desktop.

**[swaystone on the web →](https://vincemaina.github.io/arch/)** — what it is and why, on one page.

The goal is a lightweight, minimal system that can be rebuilt from scratch with as little manual configuration as possible. The current setup uses Sway and idles at roughly 550–650 MiB of memory with effectively zero CPU usage.

Small is only half of it. The other half is that a desktop you spend all day in should be worth spending the day in: seventy shortcuts that each had to argue for themselves, eleven palettes applied from a single file, a bar where everything is clickable, and notification sounds generated on the machine rather than shipped. Nothing here is installed to see whether it helps — every package sits on a line in a manifest and has to justify that line.

The repository contains everything needed to reproduce the system: package manifests, installation scripts, system configuration, and user dotfiles.

## Install

> **Warning:** the installer erases and repartitions the target disk. Make sure you specify the correct device.

### 1. Download Arch Linux

Download the latest Arch ISO from the [official Arch Linux download page](https://archlinux.org/download/).

Boot the machine from the ISO.

This setup assumes a **UEFI** system with **Secure Boot turned off** —
`03-system.sh` installs an unsigned boot binary, and a machine with Secure
Boot on will finish the install and then refuse to boot from it.

### 2. Connect to the internet

A wired connection should normally work automatically. On wifi, connect
first:

```bash
iwctl station wlan0 connect "your-network-name"
```

`iwctl device list` shows the interface name if it isn't `wlan0`.

Verify connectivity either way:

```bash
ping -c 3 archlinux.org
```

### 3. Install Git

Git is not included in the Arch live environment:

```bash
pacman -Sy git
```

### 4. Clone this repository

```bash
git clone https://github.com/vincemaina/arch.git Arch
cd Arch
```

### 5. Identify the target disk

```bash
lsblk
```

For example, a virt-manager VM will commonly use:

```text
/dev/vda
```

A physical NVMe drive may instead look like:

```text
/dev/nvme0n1
```

### 6. Run the installer

```bash
./install.sh /dev/vda
```

Replace `/dev/vda` with the disk you actually want to install Arch onto.

The installer asks for this machine's identity first — username, hostname,
timezone, locale, keymap, and the git name and email — defaulting to whatever
`setup/install.conf` already says, so pressing Enter through every question
changes nothing. Answers are validated against the live system rather than a
pattern: a timezone must be a real zoneinfo file, a locale must exist in
`/etc/locale.gen`, a keymap must exist under `/usr/share/kbd/keymaps`. Type `?`
at any of those to list the valid answers, or `?text` to search them.

```bash
./install.sh --no-wizard /dev/vda    # use install.conf exactly as it is
```

A run whose stdin is not a terminal skips the wizard on its own, so a scripted
build needs no new flag. Passwords are still asked for later by stage 03 and are
never stored.

The installer handles the rest, including:

* GPT/UEFI partitioning
* Btrfs and subvolumes
* Base Arch installation
* Locale, timezone and users
* NetworkManager
* systemd-boot
* Sway, the graphical login and desktop packages
* Development utilities
* User configuration and dotfiles

It will prompt for any information that should not be hardcoded, such as passwords.

When installation finishes, the machine powers off. Remove the Arch installation media and boot from the newly installed system.

The machine boots to a graphical login screen. Log in and the desktop starts.

The session is launched through [uwsm](https://wiki.archlinux.org/title/Universal_Wayland_Session_Manager),
which wraps the compositor in systemd units. That is what starts the bar,
notifications and idle handling, restarts them if they fail, and shuts them down
cleanly.

If the session will not start, `Ctrl+Alt+F2` reaches a plain text console. The
login screen only occupies the first virtual terminal.

## Keeping a machine up to date

`install.sh` builds a machine. `sync.sh` updates one that already exists.

Once a machine is running, clone this repository onto it and run:

```bash
./sync.sh
```

That installs any package declared in `setup/packages/` that is missing, applies
machine-wide configuration from `setup/system/`, re-applies the dotfiles, and
reports what changed along with anything that needs to restart before the change
takes effect.

To see what it would do without changing anything:

```bash
./sync.sh --dry-run
```

Run it as your normal user, not as root — the dotfiles belong to your user, and
it uses `sudo` only to install packages.

It is safe to run repeatedly, and it never partitions disks, installs a
bootloader or creates users. Boot entries in particular stay install-time only:
they are rendered with the machine's root UUID, and rewriting them on a running
system is a good way to make it unbootable. Those belong to a fresh install. It also never
removes packages: anything installed by hand and not declared in
`setup/packages/` is left alone.

This is the normal day-to-day loop. Change the repository, run `sync.sh`, see
the result — no rebuild required.

## Checks

Repository checks live in [`checks/`](./checks/) and run on an installed
machine. They exit non-zero on a problem, so they can gate other work. Nothing
in `checks/` reaches the built system — it reads `setup/` and inspects the
machine it is run on.

```bash
./checks/session.sh
```

The one to run after any change. It checks the running machine rather than the
configuration: that swap is active, the OOM handler is running, the session
components are supervised and would restart if they died, and the boot path is
set up as intended. It is read-only, and it finishes by listing the few things
only a human can confirm — whether a keypress really takes a screenshot,
whether a password prompt appears.

```bash
./checks/sway-commands.sh
```

Verifies that every external command the sway session invokes — keybindings,
session units, and helper scripts — is provided by a package declared in
`setup/packages/`. It exists because the config and the manifests could
otherwise drift apart silently: media keys called `playerctl`, which was never
installed, so the keys simply did nothing and nothing reported an error.

```bash
./checks/sway-bindings.sh
```

Prints every sway binding and fails if any key is bound twice — sway does not
warn about that, it just lets the later definition win.

```bash
./checks/manual.sh
```

Fails if [the manual](./docs/manual/README.md) names a file, a helper script or
a `$mod` keybinding that no longer exists. Prose goes stale the same way
configuration does, and in this repository that is the failure that matters: a
chapter describing a binding nobody bound reads exactly like one that is right.

`tools/` is the other half of the distinction: it produces something to read
rather than a verdict, and never exits non-zero for a number someone else has
to judge.

```bash
./tools/shortcuts.sh
```

Every shortcut this setup defines, grouped by the context it applies in,
derived from the actual configuration, with any key that means different things
in different contexts called out. `--markdown` emits the same table for the
manual to embed, so the two cannot disagree.

```bash
./tools/manual.sh --open
```

Renders [`docs/manual/`](./docs/manual/README.md) into one self-contained HTML
page — every chapter, a contents column that stays on screen, and links between
them — and opens it. `./sync.sh` builds it too, and installs the result where
the `manual` command and the launcher entry find it.

## Design

The setup is intentionally:

* **Minimal** — install only what is useful.
* **Reproducible** — configuration should live in Git rather than depend on manual setup.
* **Understandable** — automation should remain simple enough to inspect and modify.
* **Modular** — packages, system configuration and user configuration are kept separate.
* **Safe to evolve** — a new VM can be used to test changes before applying them to a real machine.

## Documentation

| | |
| --- | --- |
| [**`docs/manual/`**](./docs/manual/README.md) | **The manual.** How to use this desktop and how to change it, in ten chapters. The one to read first, and the only one written to be read start to finish. |
| [`FLOW.md`](./FLOW.md) | How the repository becomes a running machine: what runs, in what order, in which environment, and where to change each thing. |
| [`DECISIONS.md`](./DECISIONS.md) | Why each technology and layout was chosen, with the trade-offs and the alternatives rejected. |
| [`docs/software/`](./docs/software/README.md) | Every declared package accounted for, and what the running system measurably costs. |
| [`docs/wallpapers/`](./docs/wallpapers/README.md) | Why wallpapers are generated on the machine rather than tracked, and how. |

## Structure

The project itself contains documentation, development notes and backlog items. Everything required to construct the Arch system lives under [`setup/`](./setup/).

| Area              | Purpose                                    | Managed by                      |
| ----------------- | ------------------------------------------ | ------------------------------- |
| `setup/packages/` | Software that should be installed          | `pacman` / installation scripts |
| `setup/install/`  | Steps used to build the system             | Shell scripts                   |
| `setup/system/`   | Machine-wide OS configuration              | Scripts and templates           |
| `setup/dotfiles/` | User environment and desktop configuration | chezmoi                         |

The root [`install.sh`](./install.sh) orchestrates these components into a complete
installation. The root [`sync.sh`](./sync.sh) applies the same components to a machine
that is already running.
