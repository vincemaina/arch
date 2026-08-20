# Decisions

This document records the main technical and architectural decisions behind this Arch Linux setup.

The goal is not to document every command. It is to explain **why the system is built this way**, so that future changes can be judged against the original intent rather than made blindly.

---

## Goals

The system is designed around a few priorities:

- **Minimal** — install only what is useful.
- **Fast** — low idle CPU and memory usage, fast startup, minimal background work.
- **Stable** — prefer simple, mature components over unnecessary complexity.
- **Keyboard-centric** — most common actions should be quick from the keyboard.
- **Understandable** — the system should be simple enough to reason about and repair.
- **Reproducible** — configuration should live in Git rather than only on one machine.
- **Modular** — system setup, packages, and user configuration should remain separate.
- **Easy to rebuild** — a fresh machine or VM should be able to reach the same state with very little manual work.

The current reference VM idles at roughly **550–650 MiB of RAM** with effectively **0% idle CPU**, depending on what is running.

---

# Operating System

## Arch Linux

**Decision:** Use Arch Linux as the base operating system.

### Why

Arch starts from a very small base and leaves most system choices to the user. That fits this project better than a distribution that installs a complete desktop and a larger set of services by default.

The important benefit is not simply lower memory usage. It is that the final system is easier to understand:

- most installed packages exist because we chose them;
- most running services exist because we enabled them;
- there is less distribution-specific desktop configuration to undo;
- the system can be rebuilt from explicit choices stored in this repository.

Arch also has excellent documentation and a large package ecosystem.

### Trade-off

Arch requires more initial configuration and places more responsibility on the user. That is acceptable here because the entire point of this repository is to automate and document that configuration.

---

# Boot and Disk Layout

## UEFI

**Decision:** Target UEFI systems rather than legacy BIOS.

### Why

UEFI is the normal boot environment on modern hardware and keeps the installation aligned with the systems this configuration is likely to run on.

Supporting legacy BIOS would add another boot path and more installer complexity without providing much value.

---

## GPT Partition Table

**Decision:** Use GPT for disk partitioning.

### Why

GPT is the natural pairing with UEFI and avoids the limitations of legacy MBR partitioning.

The installer currently creates:

- a small EFI System Partition;
- one main Btrfs partition using the remaining disk space.

This keeps the disk layout deliberately simple.

---

## Btrfs

**Decision:** Use Btrfs for the main Linux filesystem.

### Why

Btrfs gives useful modern filesystem features without requiring a complicated storage stack:

- subvolumes;
- transparent compression;
- snapshots;
- checksumming;
- flexible use of free space.

It is particularly useful for a system that may be rebuilt, experimented with, or snapshotted frequently.

### Alternatives considered

**ext4** would be simpler and extremely mature, but it does not provide native subvolumes or snapshots.

**ZFS** has strong snapshot and storage features, but adds more complexity than this desktop system needs.

Btrfs provides a good middle ground.

---

## Btrfs subvolumes

**Decision:** Use separate Btrfs subvolumes for:

```text
@
@home
@snapshots
```

mapped to:

```text
/
 /home
 /.snapshots
```

### Why

Subvolumes give logical separation without permanently dividing disk capacity between fixed-size partitions.

This allows future snapshot workflows to treat the operating system and user data differently while all subvolumes continue to share the same free space.

---

## No separate `/home` partition

**Decision:** Use an `@home` Btrfs subvolume rather than a separate physical partition.

### Why

A dedicated `/home` partition would require choosing a size in advance. That creates an unnecessary constraint.

A subvolume provides the separation we care about while allowing root and home to share the same available disk space.

---

## Zstd compression

**Decision:** Mount Btrfs subvolumes with transparent Zstd compression.

### Why

Compression can reduce disk usage and I/O with very little overhead on modern CPUs.

It is a useful default for a general-purpose development machine and requires no application-level configuration.

---

## zram instead of a disk swapfile

**Decision:** Provide swap as a compressed block device in RAM, sized
`min(ram / 2, 8192)` with zstd, and no swap on disk.

### Why

The install previously had no swap of any kind. Without it, memory pressure means
the kernel thrashes the page cache and the desktop stops responding well before
the OOM killer intervenes — the whole-system freeze this setup is meant to avoid.

Compressing pages into RAM costs far less than writing them to the SSD, so the
machine gains usable headroom without a disk write path, and without consuming
space on a 500 GB drive. It also avoids writing memory contents to persistent
storage, which matters more given there is no full-disk encryption.

The size is an expression rather than a figure because the same repository has
to work on both a 16 GB machine and a VM with a fraction of that. Half the
memory, capped at 8 GB.

Two sysctl settings accompany it. `vm.swappiness` is raised well above the
default, which is tuned for the assumption that swapping means touching a disk.
`vm.page-cluster` is set to 0 because swap read-ahead exists to amortise seeks,
and zram has none.

### Alternatives considered

A **swapfile on the Btrfs root** would survive hibernation and provide more
capacity. It was rejected because hibernation is not a requirement here, and the
failure mode being fixed is responsiveness under pressure, where a disk swapfile
is markedly worse. Nothing stops one being added later: zram is given
`swap-priority = 100` so it would still be preferred.

### Trade-off

zram consumes real memory to provide swap, so it is not free capacity — it trades
CPU for effective memory. It also cannot support hibernation.

---

## earlyoom rather than systemd-oomd

**Decision:** Run earlyoom as the userspace out-of-memory handler.

### Why

zram alone delays the problem rather than solving it. Something still has to act
when memory genuinely runs out, and the kernel OOM killer acts far too late.

earlyoom watches `MemAvailable` directly. That signal stays meaningful alongside
zram, whereas approaches that infer pressure from swap usage are misled by a zram
device sitting near-full as a matter of course, which is its normal state rather
than a warning sign.

It is also small and predictable: one process, a hard 50 MB memory cap in its own
unit, and behaviour that can be described in a sentence. For a machine whose goal
is not freezing, a handler that is easy to reason about has real value.

It requires both available memory and free swap to be below their thresholds
before killing, which is the correct interaction with zram: a full zram device
only signifies trouble when memory is low too.

### Alternatives considered

**systemd-oomd** needs no extra package, which is a genuine point in its favour
given the preference for minimalism, and its cgroup and PSI-based approach is the
more modern design. It was rejected because its swap-based rules misfire with
zram and have to be avoided, leaving pressure-based rules that are harder to
reason about and tune than a memory threshold.

**nohang** is more capable than either but is a larger dependency for a problem
that does not need it.

### Trade-off

earlyoom kills a process without asking, and currently does so without notifying
anyone, so an application can vanish with no explanation. The `--avoid` list
keeps the session itself safe and `--prefer` aims at the browser first, but
surfacing the kill to the user is worth adding later.

---

## No full-disk encryption

**Decision:** Do not enable disk encryption by default.

### Why

This system is currently intended primarily for a home development PC where the additional operational complexity is not considered worthwhile.

Encryption can be added later for machines where physical data protection is more important.

This is therefore a deliberate simplicity/usability trade-off, not a claim that encryption is unnecessary in general.

---

# Init and Bootloader

## systemd

**Decision:** Use systemd.

### Why

systemd is the standard init and service-management system on Arch.

Using the distribution default keeps the system straightforward and gives us:

- service management;
- logging through the journal;
- user services;
- device management integration;
- boot analysis tools.

There is no strong reason for this project to replace it.

---

## systemd-boot

**Decision:** Use systemd-boot as the UEFI bootloader.

### Why

The system only needs a straightforward UEFI boot path. systemd-boot is small, simple, and already fits naturally into a systemd-based Arch installation.

It avoids the broader configuration surface of GRUB when features such as BIOS support or complex multi-boot logic are not required.

### Trade-off

GRUB has more features and broader compatibility. If the machine later develops complex multi-boot requirements, revisiting this choice may make sense.

---

## Early microcode via the mkinitcpio hook

**Decision:** Install both `intel-ucode` and `amd-ucode`, and load microcode through
the mkinitcpio `microcode` hook rather than a separate `initrd` line in the boot entry.

### Why

Microcode updates carry CPU errata and security fixes. Arch treats them as required
for every installation, and a machine without them runs known-broken silicon.

Current Arch practice bundles microcode into the initramfs through the `microcode`
hook, replacing the older approach of listing a `*-ucode.img` as the first `initrd`
in the boot entry. Following the current approach keeps the boot entries
vendor-agnostic: nothing in them mentions Intel or AMD at all.

Both vendor packages are installed rather than detecting the CPU during install.
The kernel loads only the image matching the running processor and ignores the
other, so carrying both costs a few megabytes and removes an entire branch from
the installer.

`03-system.sh` confirms the hook is present rather than assuming it. It is part of
the default `HOOKS`, so the check normally does nothing — but if that ever changes,
the installer fails loudly instead of quietly producing a machine without microcode.

### Alternatives considered

Listing `initrd /intel-ucode.img` before the main initramfs in each boot entry is
the older documented method and still works. It was rejected because it puts
vendor-specific detail into every boot entry and duplicates what the hook already
does during image generation.

---

## A fallback boot entry

**Decision:** Generate a second systemd-boot entry using
`initramfs-linux-fallback.img` alongside the default entry.

### Why

The default initramfs is built with `autodetect`, so it contains only the modules
needed by the hardware present when it was generated. That makes it small and quick
to load, and it is the right default — but it also means a hardware change, or a
kernel or initramfs update that goes wrong, can leave the machine unbootable.

mkinitcpio already builds the fallback image on every update at no extra cost.
Not offering it as a boot entry meant the recovery path existed on disk but could
not be reached without the install media.

Boot entries are now rendered from every template in `system/loader/entries/`
rather than by naming files individually, so adding a future entry is a matter of
adding a file.

### Trade-off

The boot menu lists two entries instead of one. `loader.conf` still defaults to the
normal entry with a short timeout, so this costs nothing until it is needed.

---

# Networking

## NetworkManager

**Decision:** Use NetworkManager for networking.

### Why

NetworkManager provides a good balance between automation and control.

It works well for both:

- simple wired networking in VMs;
- Wi-Fi and changing networks on physical machines.

It also provides useful CLI tooling such as `nmcli` while remaining compatible with lightweight desktop setups.

Using something lower-level would save very little while making laptop and Wi-Fi management less convenient.

---

# Graphical Environment

## Wayland

**Decision:** Use Wayland as the native display protocol.

### Why

The system is being built around Sway, which is a Wayland compositor.

Wayland provides the modern Linux desktop stack and avoids designing the system around legacy X11 behaviour.

---

## Sway

**Decision:** Use Sway as the compositor and window manager.

### Why

Sway closely matches the goals of the project:

- very low baseline resource usage;
- keyboard-first workflow;
- automatic tiling;
- simple text configuration;
- mature and predictable behaviour;
- strong compatibility with the i3 configuration model;
- no dependency on a full desktop environment.

It gives much of the productivity of a tiling window manager without adding a large desktop shell.

### Why not GNOME / KDE / COSMIC

Full desktop environments provide more integrated GUI tooling and polish, but also introduce more background components and configuration that this project does not need.

The aim here is not to reproduce a full desktop environment. It is to build a small set of components that covers the required workflow.

---

## A display manager, reversing an earlier decision

**Decision:** Log in graphically through greetd, with ReGreet as the login screen
hosted by cage. The session is launched as `uwsm start -- sway.desktop`.

This reverses the original decision to have no display manager. That entry is
reproduced here rather than deleted, because the reasoning was sound at the time
and it is the change in circumstances that matters:

> **Decision:** Do not install a graphical display manager by default.
>
> The current system logs in through a TTY and starts Sway manually. This keeps
> startup simple and avoids another long-running component. A display manager may
> be added later if automatic graphical login becomes more valuable than the
> simplicity of the current approach.

### Why it changed

When that was written, typing `sway` at a TTY was equivalent to any other way of
starting it. Adopting uwsm made that false. The session now has supervised
components — the bar, notifications, idle handling, the authentication agent —
and they only start when the session is launched through uwsm. Typing plain
`sway` produces a desktop that looks completely normal and is missing all of
them, with nothing on screen indicating it.

That happened during verification of this very setup, which is the strongest
argument available: the failure is silent, plausible, and easy to repeat. A
manual launch is no longer merely inconvenient, it is a way to get a subtly
broken system.

Removing the typed command removes the failure. Nobody types the launch command,
so nobody can get it wrong.

### Why greetd and ReGreet

greetd is a login daemon and nothing else: it authenticates and launches whatever
it is told to. It makes no assumptions about the session, which suits a system
assembled from parts rather than shipped as a desktop environment.

ReGreet reads session entries from the `wayland-sessions` directories, so the
session list is derived rather than maintained by hand. That matters for a
possible second desktop later: adding one becomes installing it, with no login
configuration to update.

It is also GTK, like Waybar and Thunar, so it introduces no second toolkit, and
it is styled with ordinary CSS.

### Alternatives considered

**gtkgreet** is smaller and the traditional sway pairing, but takes its session
list from `/etc/greetd/environments` as literal commands. Every future session
would be a hand-maintained string.

**SDDM** is the most complete and best-tested option, with themes available off
the shelf. It was rejected for pulling Qt6 and QML onto an otherwise GTK system
for the sake of one screen, and because it would close off `cosmic-greeter`,
which is itself built on greetd.

### Trade-off

There is now a long-running component between boot and the desktop, which is
exactly what the original decision avoided. The escape hatch is that greetd only
takes VT 1; the other virtual terminals keep their gettys, so `Ctrl+Alt+F2`
still reaches a plain shell when the session will not start.

---

## Session components bind to the compositor, not the graphical session

**Decision:** Bind Waybar, mako, swayidle and the polkit agent to
`wayland-session@sway.target` rather than `graphical-session.target`.

### Why

`graphical-session.target` is reached by every graphical session. Units wanted by
it start under any compositor, which is correct for something generic and wrong
for everything here: Waybar would try to draw a sway bar on another desktop, and
the idle script calls `swaymsg`, which would not exist there — so the screen
would quietly stop locking.

uwsm creates a per-compositor target for exactly this. Binding to it means these
components start under sway and nowhere else.

Nothing depends on this yet, since sway is the only session installed. It is done
now because the cost is a few lines today and a confusing, silent breakage the
day a second desktop is added. The session entry list is already derived from
`wayland-sessions`, so that day needs no login configuration change — which is
precisely why the units must be correct before it arrives.

---

## Thin borders instead of title bars

**Decision:** Remove normal Sway title bars and use thin borders to indicate focus.

### Why

In a keyboard-driven tiling workflow, title bars consume vertical space without providing much value.

Thin focused-window borders retain the useful visual cue while keeping the interface compact.

---

## GB keyboard layout

**Decision:** Configure the graphical keyboard layout as UK (`gb`) and the console keymap as `uk`.

### Why

The system should match the physical UK ISO keyboard being used.

This is configured explicitly so a new installation behaves correctly immediately rather than relying on environment defaults.

---

# Desktop Components

## uwsm for session management

**Decision:** Launch the compositor through the Universal Wayland Session Manager:

```bash
uwsm start -- sway
```

Session components — the bar, notifications, idle handling — are systemd user
units bound to `graphical-session.target`, not sway `exec` lines.

### Why

Waybar was previously started by hand after login and appeared nowhere in this
repository, so a freshly installed machine came up with no bar at all. The
immediate fix would have been an `exec waybar` line, but sway's `exec` is
fire-and-forget: a component that dies stays dead until the session is restarted,
and nothing orders startup or shuts things down cleanly.

uwsm wraps the compositor in systemd units and starts the standard
`graphical-session.target`, which gives:

- supervision, so a crashed component restarts rather than silently disappearing;
- ordering, through the normal target dependencies;
- clean shutdown, because everything is `PartOf` the session;
- one obvious place to look for what runs alongside the compositor.

Waybar already ships a systemd user unit with `Restart=on-failure`, so it only
needed enabling. mako and swayidle got matching units following the same pattern.

uwsm is in the official `extra` repository, so this needs no AUR support.

### Alternatives considered

**Plain `exec` lines** in the sway config. One line, no dependencies, and the
obvious first instinct. Rejected because there is no supervision: the failure
mode we were trying to fix is precisely a component not running.

**Hand-rolled systemd units** with our own session target, started from the sway
config. No new package, and it was tempting given the preference for keeping
things minimal. Rejected because it reimplements what uwsm already does, and the
maintenance would be ours.

**sway-systemd**, which solves exactly this problem, is only in the AUR. Adding
AUR support is a much larger decision than this task warranted.

### Trade-off

Starting `sway` directly no longer produces a complete desktop. That is a real
footgun until the session starts automatically on login, which is tracked
separately. It is also one more component between login and a working desktop.

---

## Enabling user units by symlink rather than systemctl

**Decision:** Enable session units with symlinks committed under
`dotfiles/dot_config/systemd/user/graphical-session.target.wants/` rather than by
running `systemctl --user enable` during installation.

### Why

`systemctl --user enable` needs a user session to talk to, which does not exist
inside the installer chroot. Enabling a unit is only a symlink into a `.wants`
directory, so committing the symlink achieves the same thing with no special case
in the installer.

It also keeps which units are enabled visible in the repository and applied by the
same chezmoi run as everything else, rather than being machine state set once
during installation and invisible afterwards.

---

## Waybar

**Decision:** Use Waybar as the status bar.

### Why

Waybar is lightweight, native to Wayland, highly configurable, and integrates directly with Sway.

It provides only the information we choose to expose rather than bringing in an entire panel or desktop shell.

Current configuration includes workspace information and useful system status while remaining intentionally compact.

---

## Wofi

**Decision:** Use Wofi as the application launcher.

### Why

Wofi is a small Wayland-native launcher that works well with Sway.

The main use is:

```text
wofi --show drun
```

which provides a simple searchable application launcher.

It covers the required use case without needing a heavier desktop menu system.

---

## Foot

**Decision:** Use Foot as the terminal emulator.

### Why

Foot is lightweight, fast, Wayland-native, and well suited to a minimal Sway environment.

It has a small footprint while still supporting normal terminal features, fonts, colours, padding, and themes.

The visual configuration is intentionally kept in dotfiles so the terminal can look consistent across rebuilt systems.

---

## Mako

**Decision:** Use Mako for desktop notifications.

### Why

Mako is a small Wayland notification daemon designed for compositors such as Sway.

It provides exactly the notification functionality required without pulling in a broader desktop notification framework.

---

## PipeWire

**Decision:** Use PipeWire for audio.

### Why

PipeWire is the modern Linux audio stack and works well for both desktop audio and more advanced routing use cases.

It replaces the need to build around PulseAudio directly while still providing PulseAudio compatibility through `pipewire-pulse`.

---

## WirePlumber

**Decision:** Use WirePlumber as the PipeWire session manager.

### Why

PipeWire needs policy and session management. WirePlumber is the standard modern choice and integrates cleanly with the rest of the desktop audio stack.

---

## XWayland

**Decision:** Install XWayland.

### Why

The desktop is Wayland-native, but some applications may still depend on X11.

XWayland provides compatibility for those applications without requiring the entire desktop to be based on X11.

---

## xdg-desktop-portal and xdg-desktop-portal-wlr

**Decision:** Install the desktop portal stack.

### Why

Wayland applications rely on portals for functionality such as:

- screen sharing;
- screenshots and screen capture permissions;
- file selection integration;
- sandboxed application access.

The WLR backend provides the compositor-specific integration needed by Sway.

---

## polkit-gnome as the authentication agent

**Decision:** Install `polkit-gnome` and run it as a session unit.

### Why

polkit was installed but no authentication agent ran, so any graphical action
needing elevated privileges had nothing to present a password prompt and simply
failed. Sway, unlike a full desktop environment, ships no agent of its own.

`polkit-gnome` depends only on GTK3 and polkit itself. The desktop already pulls
GTK3 in through Waybar and Thunar, so it adds essentially nothing. The Qt-based
agents would drag in a second toolkit for one dialog.

### Trade-off

`polkit-gnome` has not seen an upstream release in a long time. It works and Arch
still ships it, but if that changes, `mate-polkit` is the maintained fork of the
same code and would be a drop-in replacement.

---

## Helper scripts declare what they call

**Decision:** Scripts in `dotfiles/dot_local/bin/` carry a `# requires:` header
listing the external commands they use, and a check enforces it.

### Why

The bug this came from was quiet: the media keys called `playerctl`, which was
never in any manifest, so pressing them did nothing and nothing reported an
error. Screenshots had the same shape — they wrote to a directory nothing
created. Both had been that way since the config was first committed.

`checks/sway-commands.sh` closes that gap by resolving every command the session
invokes back to a declared package. Commands in the sway config and in unit files
can be extracted mechanically, but working out what an arbitrary shell script
might run cannot be done reliably by parsing it.

Declaring dependencies in a header keeps them checkable without guessing. The
check treats a missing header as a failure, so the declaration cannot quietly be
skipped when a new helper is added.

### Trade-off

The header is maintained by hand and can go stale — a command added to a script
without updating it escapes the check. That is a real weakness, but a smaller one
than not checking at all, and the failure is visible in review rather than silent
in use.

---

## polkit

**Decision:** Include polkit support in the desktop stack.

### Why

Some graphical and system-management operations need privilege escalation.

Polkit provides a standard mechanism for this without requiring applications to run as root.

Even if it is sometimes installed transitively, it is considered an intentional capability and should therefore remain part of the desired system state.

---

# Desktop Utilities

## grim + slurp

**Decision:** Use `grim` and `slurp` for screenshots.

### Why

They are small Wayland-native tools that compose well:

- `grim` captures screenshots;
- `slurp` allows interactive region selection.

Together they provide both full-screen and region screenshots without a larger screenshot application.

---

## wl-clipboard

**Decision:** Use `wl-clipboard` for command-line clipboard access.

### Why

`wl-copy` and `wl-paste` are simple Wayland-native tools and integrate naturally with screenshot and terminal workflows.

---

## Thunar

**Decision:** Use Thunar as the graphical file manager.

### Why

A graphical file manager is still useful even in a keyboard-centric system.

Thunar is lightweight, mature, and does not require adopting the rest of XFCE.

---

## GVFS

**Decision:** Install GVFS alongside Thunar.

### Why

GVFS improves file-management integration for removable storage and other mounted resources.

It provides useful desktop functionality without requiring a full desktop environment.

---

## qutebrowser

**Decision:** Use qutebrowser as the default lightweight browser in this setup.

### Why

qutebrowser fits the keyboard-centric philosophy particularly well and integrates naturally into a Sway workflow.

It is also useful as a low-overhead browser for the reference environment.

This is not intended to prevent installing other browsers where required.

---

## btop

**Decision:** Install btop for system monitoring.

### Why

One of the goals of this system is to remain lightweight and understandable.

btop provides an easy way to inspect:

- memory usage;
- CPU usage;
- processes;
- disk activity;
- network activity.

It is useful both for normal monitoring and for catching regressions in the setup.

---

# Fonts

## Noto Fonts

**Decision:** Install Noto fonts and Noto emoji.

### Why

Noto provides broad character coverage and avoids missing glyphs across normal applications.

It is a sensible general-purpose fallback font set.

---

## JetBrains Mono Nerd Font

**Decision:** Use JetBrains Mono Nerd Font where terminal-style UI or icon glyphs are required.

### Why

Waybar configurations often use glyphs from Nerd Fonts.

Using a known Nerd Font avoids missing-icon boxes while also providing a clean monospace font suitable for development and terminal use.

The font choice is primarily visual and can be changed later without affecting the architecture of the system.

---

# Development Environment

## Neovim

**Decision:** Install Neovim as the primary development editor.

### Why

Neovim fits the keyboard-centric workflow and can be configured entirely through version-controlled files.

The base system still includes Vim so an editor is available even before the full development environment is installed.

---

## Terminal utilities

The development package set includes tools such as:

```text
ripgrep
fd
fzf
tree
unzip
zip
man-db
man-pages
less
```

### Why

These are small, broadly useful command-line tools that improve navigation, searching, documentation, and everyday development work without adding significant background overhead.

They are kept separate from the base system so the project can evolve toward different machine profiles later.

---

# Reproducibility

## Git

**Decision:** Store the complete setup in Git.

### Why

The system should be reconstructable from code and configuration rather than memory.

Git gives us:

- history;
- rollback;
- reviewable changes;
- branches;
- reproducible snapshots of system configuration;
- a clear record of why the machine changed.

The repository is treated as the source of truth for the intended setup.

---

## One top-level installer

**Decision:** Expose one obvious entrypoint:

```bash
./install.sh <disk>
```

### Why

The user should not have to remember the internal installation sequence.

The root installer orchestrates the lower-level scripts for:

1. disk setup;
2. base installation;
3. system configuration;
4. desktop installation;
5. dotfile application.

The individual scripts remain separate for maintainability and debugging, but the normal user-facing interface is a single command.

---

## A separate entrypoint for machines that already exist

**Decision:** Add a second root entrypoint alongside the installer:

```bash
./sync.sh
```

`install.sh` builds a machine from the live ISO. `sync.sh` applies the repository
to a machine that is already running it.

### Why

The repository could previously only build a machine from scratch. Every change,
however small, could therefore only be validated by rebuilding — which is the right
test for reproducibility but far too slow to be the only loop available while tuning
a desktop day to day.

Separating the two keeps each honest about what it is:

- installation is destructive, runs once, and needs the live ISO;
- syncing is idempotent, runs constantly, and must never touch the disk.

Keeping them apart means the repeatable operation cannot accidentally inherit a
destructive step. `sync.sh` references none of the numbered install stages.

### Trade-off

There are now two ways to apply the repository, and a change that only works
through one of them is a bug that will not necessarily be caught. Fresh-install
tests remain the stronger check, as recorded under Testing Strategy; `sync.sh` is
for iteration speed, not for proving reproducibility.

---

## `sync.sh` is one flat script

**Decision:** Write the sync path as a single script rather than the numbered
stages used by the installer.

### Why

The installer is split into five stages because they are genuinely distinct,
run in two different environments, and are destructive enough that a failure
needs to be traceable to a specific step.

Syncing has neither property. It reconciles packages and applies dotfiles, both
of which are safe and repeatable, and both run as the same user in the same
place. Splitting that into stages would add indirection without making anything
easier to inspect or debug.

If the sync path grows genuinely separate concerns, this should be revisited.

---

## Packages are added but never removed by sync

**Decision:** `sync.sh` installs declared packages that are missing and does not
remove anything that is installed but undeclared.

### Why

Removal is the one part of reconciliation that can destroy a working system. A
package missing from a manifest is more likely to be an omission in the
repository than a mistake on the machine, and acting on that assumption
automatically would be the wrong default.

Reporting drift rather than fixing it keeps the manifests honest without making
the safe, everyday command capable of breaking the desktop.

---

## `setup/` as the installation payload

**Decision:** Keep everything required to construct Arch under:

```text
setup/
```

while repository-level documentation, backlog, and project-management files remain outside it.

### Why

This creates a clean boundary between:

- the **project**;
- the **payload required to construct the operating system**.

During installation, the entire `setup/` directory can be copied into the new filesystem and used inside `arch-chroot` without needing to copy the whole repository.

---

## Package manifests

**Decision:** Keep package choices in plain text manifests rather than hardcoding long package lists inside shell scripts.

Current categories include:

```text
base
desktop
dev
```

### Why

The manifests answer:

> What software should this type of system have?

while the scripts answer:

> How should that software be installed?

This keeps package selection readable and makes it easier to review changes over time.

The manifests describe **intentional top-level requirements**, not every transitive dependency installed by pacman.

---

## Shell scripts

**Decision:** Use small Bash scripts for installation orchestration.

### Why

Bash is available in the Arch installation environment, is easy to inspect, and is sufficient for the current level of automation.

The installer is deliberately split into ordered stages rather than one large script so failures are easier to locate and individual responsibilities remain clear.

Scripts use:

```bash
set -euo pipefail
```

so unexpected failures stop the installation rather than silently continuing.

---

## Chezmoi

**Decision:** Use chezmoi for user dotfiles.

### Why

System installation and user configuration are different concerns.

Chezmoi is used only for files that belong in the user's home directory, such as:

```text
~/.config/sway/config
~/.config/waybar/config.jsonc
~/.config/waybar/style.css
~/.config/foot/foot.ini
```

This keeps desktop and application configuration version-controlled while allowing system-wide configuration to remain managed by installation scripts.

---

## `.chezmoiroot`

**Decision:** Use `.chezmoiroot` so chezmoi treats only the `dotfiles/` directory as source state.

### Why

The installation payload contains more than dotfiles:

```text
setup/
├── install/
├── packages/
├── system/
└── dotfiles/
```

Chezmoi should not interpret the other directories as files that belong in the user's home directory.

`.chezmoiroot` preserves the single-repository design while clearly defining the dotfile boundary.

---

# Testing Strategy

## VM-first development

**Decision:** Develop and validate the installer in virtual machines before using it on physical hardware.

### Why

The installer performs destructive disk operations.

A VM makes it cheap and safe to:

- wipe disks;
- rebuild repeatedly;
- test installer changes;
- deliberately break things;
- verify that a fresh system reaches the desired state.

The current proof-of-concept was validated by building a second VM from the repository and confirming that Sway, Waybar, applications, shortcuts, and dotfiles were reproduced correctly.

---

## Prefer fresh-install tests over modifying the reference VM

**Decision:** Validate installer changes against new VMs where practical.

### Why

The real question is not whether a script works on an already-configured machine.

It is whether the repository can recreate the system from scratch.

Fresh VMs provide a much stronger test of reproducibility.

---

# Things intentionally not automated yet

Some choices remain deliberately manual or unfinished.

## Passwords

Passwords are entered interactively during installation rather than stored in Git.

A secure unattended secret-management approach can be added later if needed.

---

## Graphical login

Sway is currently started manually after TTY login.

Automatic graphical login or a display manager may be added later, but it is not required for the core setup.

---

## Additional application configuration

Applications such as Foot and Mako should only gain committed config files when there are meaningful customisations worth preserving.

The repository should avoid configuration for configuration's sake.

---

# Guiding principle

When evaluating future changes, prefer the option that best preserves this balance:

> **Minimal enough to stay fast and understandable, automated enough to be reproducible, and practical enough to be pleasant to use every day.**

New tooling should earn its place by solving a real problem. The goal is not to make the smallest possible Arch installation; it is to make a system whose complexity is intentional.
