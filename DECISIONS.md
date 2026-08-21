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

## One palette, defined once, templated everywhere

**Decision:** A neon palette on a near-black background, defined in
`dotfiles/.chezmoidata/themes.toml`, with every themed file a chezmoi template
that reads from it.

### Why

The desktop looked unfinished because it was not one design. The bar was
Catppuccin Mocha with two Nord colours mixed in. The terminal included a Tokyo
Night theme that foot does not ship, so it silently had no theme at all. Nothing
else was themed. Three half-applied styles read as "boring" far more than any
one of them would have.

The obvious fix, picking a palette and editing four files, would have decayed the
same way: colours copied into sway, Waybar CSS, foot and swaylock drift apart the
first time one is changed and another forgotten. That is exactly what had already
happened.

chezmoi is already applying these files, and it templates. So the palette is data
and the configs are views of it. Changing a colour is one edit followed by
`sync.sh`.

Names are by role — `accent`, `urgent`, `muted` — rather than by colour, so
swapping palettes later does not leave a variable called `orange` holding
something blue.

The sixteen ANSI terminal colours live in the same file rather than pointing foot
at one of its bundled themes, for the same reason: a palette split across two
places is one someone will half-update. It also means the palette is not limited
to themes foot happens to ship, which is what broke the terminal originally.

The palette changed once already, from Gruvbox to this, and the cost was editing
one file. That is the design working.

### Trade-off

Four files are now templates, so they cannot be read as literal config without
rendering them, and a template error breaks them all at once rather than one.
That is mitigated by the failure being loud — chezmoi refuses to apply — and by
being able to render into a scratch directory to check. Doing exactly that caught
a real bug: swaylock wants its colours without a leading `#`, unlike every other
consumer.

---

## Saturation is checked, not eyeballed

**Decision:** Every foreground colour is measured against the background, and
anything below a 4.5:1 contrast ratio is adjusted rather than shipped.

### Why

A near-black background with saturated accents is the palette most likely to
look striking in a screenshot and be tiring to actually use. The failure is not
obvious while choosing colours, because the eye is drawn to the bright accents
and skips over the dim text that will be read all day.

Measuring caught two real problems in the first draft. The muted grey used for
the cpu and memory readouts came in at 4.45:1, marginally too low for something
meant to be glanced at constantly. Terminal `bright_black` measured 2.77:1 -
and most colour schemes use `bright_black` for code comments, so that is a
palette that makes comments hard to read while looking perfectly fine
everywhere else.

Both were lightened until they measured above 4.5:1. Bright accents are left
saturated, since they are used for small marks - a focus border, a workspace
pill - rather than for text.

---

## Colour identifies, state escalates

**Decision:** Every bar module is a coloured pill. Colour tells you which
readout you are looking at; a module changes to a warning or urgent colour when
it needs attention.

This revises an earlier decision here, which said everything should be
foreground grey until it needed attention and that only the focused workspace,
an active mode and a failing battery were allowed to be bright.

### Why it changed

That rule was defensible in the abstract and wrong in practice. It produced a
bar that read as austere rather than minimal, and it threw away what colour is
genuinely useful for on a status bar: telling six readouts apart at a glance, so
the bar is scanned rather than read left to right. The version it replaced -
inconsistent as it was - looked better.

The reference setups collected under `docs/themes/` are unanimous on this. Every
one of them gives each module its own colour, most as a filled pill. That is a
strong enough signal to override a principle derived from first principles.

The useful half of the original idea survives: because resting colours are
stable and familiar, a module changing colour is immediately obvious. Escalation
works precisely because the baseline is not grey but is predictable.

Windows still follow the stricter rule. Only the focused one takes the accent
border, because there the question really is binary - which window has focus -
rather than which of several things am I looking at.

---


## Applications are made to match, not left to guess

**Decision:** Set a dark GTK theme, an icon set and a UI font centrally, and
tell toolkits to run natively on Wayland, through `environment.d` and GTK
settings files.

### Why

Thunar, pavucontrol and qutebrowser each picked their own defaults, so the
desktop looked assembled from parts rather than designed. The bar had been
carefully styled, which made the mismatch elsewhere more obvious rather than
less.

`GTK_THEME` is set as well as the settings files. The settings files are the
correct mechanism and cover applications that read them; the environment
variable also catches ones started outside a normal desktop session, and works
regardless of which GTK version an application happens to use.

The Wayland variables are about correctness as much as appearance. An
application falling back to XWayland renders blurry on a scaled output and loses
native input handling, so `QT_QPA_PLATFORM` lists Wayland first with X11 as a
fallback, and window decorations are disabled because sway draws the border.

`xdg-desktop-portal-gtk` is installed alongside the wlroots portal so that file
chooser dialogs are the GTK one every other application uses, rather than a bare
toolkit default.

### What this does not cover

qutebrowser's own interface - its tab bar, status line and completion menu - is
themed in qutebrowser's configuration, not by any GTK or Qt setting. Making it
match the palette needs a qutebrowser config, which does not exist yet. The Qt
platform theme plumbing that would let a Qt application follow a system theme is
also not set up; it is a larger piece of machinery than the one Qt application
here justifies.

---

## Thin borders instead of title bars

**Decision:** Remove normal Sway title bars and use thin borders to indicate focus.

### Why

In a keyboard-driven tiling workflow, title bars consume vertical space without providing much value.

Thin focused-window borders retain the useful visual cue while keeping the interface compact.

---

## One organising principle for keybindings

**Decision:** `$mod` is for window management, nothing else may take a `$mod`
chord, and there is one binding per action.

Applications are not bound at all. They are launched from `$mod+space`.

### Why

The bindings had grown by accretion: the upstream defaults, plus a browser and a
file manager bolted on. Those two took `$mod+b` and `$mod+e`, which were already
`splith` and `layout toggle split` — so two core layout commands silently stopped
existing. sway does not warn about a duplicate; the later definition just wins.

The underlying problem is that a finite namespace was being shared between two
things that grow at different rates. Window management commands are a fixed set
you learn once. Applications are unbounded. Letting applications into `$mod`
guarantees the collision recurs, and relocating them to another modifier only
postpones it.

Not binding applications at all removes the competition. Launching costs one
extra keystroke through the launcher, and in exchange the layout commands can
never be shadowed again and the scheme has no growth problem.

The terminal on `$mod+Return` is the deliberate exception: on a tiling desktop it
is less an application than the thing windows are usually made of.

### The second half: one way to do each thing

Upstream ships arrow keys alongside `h/j/k/l` so newcomers are not stuck before
learning vim keys. Keeping both is exactly the kind of thing this setup argues
against elsewhere — the same reasoning applied to a bar module or a package
would delete it. The arrow duplicates are gone, as is stacking, which does the
same job as tabbed.

Prev/next workspace stepping duplicated the numbered bindings and is gone too.
`Alt+Tab`, which had been bound to workspaces, is now unbound: everywhere else in
computing it means "switch window", and applications sometimes want it.
`$mod+Tab` returns to the previous workspace, which was the useful part.

This took 80 bindings to 64, but the count is not the point. Every remaining
binding is there because someone decided it should be.

### How it is enforced

`checks/sway-bindings.sh` fails if any combination is bound twice, comparing
across all fragments with `set` variables expanded and modifiers sorted, so
`$mod+Shift+q` and `Shift+$mod+q` are recognised as the same binding. It also
prints the full table, which is the practical documentation of the scheme: 64
bindings across four fragments is more than can be held in mind while editing
one of them.

### Shift is reserved for the infrequent

Closing a window is `$mod+q`, not `$mod+Shift+q` as upstream ships it. It is one
of the most frequent actions there is, and Shift is a real cost when repeated
all day.

The session bindings keep Shift deliberately: reload on `$mod+Shift+c` and exit
on `$mod+Shift+e` are rare, and being slightly awkward is a feature when the
consequence of a mistake is losing the session. Shift here marks "you probably
meant this", not "this is the second variant".

The cost is that a window is now one easy chord from closing, with no
confirmation. That is the same bargain every editor makes with its close
shortcut.

### Trade-off

Launching a frequently-used application is now two keystrokes and a few letters
rather than one chord. That is a real cost paid every day, accepted because the
alternative is a namespace that collides again as soon as a third application
seems worth binding.

Tapping `$mod` alone to open the launcher would remove even that cost, but sway
cannot distinguish a tap from a hold: a release binding on the modifier also
fires after every `$mod` chord. Doing it properly needs a dual-role key daemon
such as `keyd` intercepting input below the compositor, which was judged too
much machinery for one keystroke.

---

## Input tuned for holding keys down

**Decision:** Key repeat at 250ms delay and 40 per second, rather than the
defaults of 600ms and 25.

### Why

The defaults are conservative because they assume a key held down is usually a
mistake. On a keyboard-driven desktop the opposite is true: holding a direction
key to move through a list, or backspace through a line, is routine, and 600ms
of nothing followed by a slow repeat is felt every time.

250ms is still long enough not to fire on a deliberate single press. 40 per
second is quick without overshooting the thing being aimed at. Both are worth
adjusting by feel; the point is that they are now a decision rather than an
inherited default.

The touchpad block is configured but matches nothing until the setup runs on a
laptop, since `input type:touchpad` applies only to devices that exist. Natural
scrolling is the one genuine preference in it and is a single line to flip.

---

## One cursor theme, set in three places

**Decision:** Use Adwaita at size 24, declared in the sway seat, in
`environment.d`, and in the GTK settings.

### Why

Three declarations look redundant but cover three different consumers. sway
tells the compositor and the windows it spawns. `XCURSOR_THEME` covers XWayland
clients and anything started as a user unit rather than by sway. GTK reads its
own setting and ignores both.

Miss one and the cursor changes size or shape as the pointer crosses between
windows, which is the sort of small inconsistency that makes a desktop feel
assembled rather than designed.

Adwaita because GTK applications expect it, and the desktop is already GTK
through Waybar and Thunar. Choosing anything else would mean overriding a
default that is otherwise correct everywhere.

Note that `environment.d` is read when the user manager starts, so a change
there needs a fresh login rather than a config reload.

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

## zsh, without a framework

**Decision:** Use zsh as the login shell, with `zsh-autosuggestions`,
`zsh-syntax-highlighting` and `zsh-completions` sourced directly. No Oh My Zsh.
`starship` for the prompt.

### Why

bash with no configuration was the least considered part of a system otherwise
built around living in a terminal: a default prompt, no completion beyond the
built-ins, a small unshared history, and `fzf`, `ripgrep` and `fd` installed but
wired to nothing.

zsh over fish because commands are copied from the ArchWiki constantly while
learning Arch, and fish is not POSIX — `export FOO=bar` and most snippets fail
as written. fish is the nicer shell to use and the worse one to paste into.

**Oh My Zsh was rejected deliberately.** It is the usual answer and it does work,
but it is a self-updating git clone rather than a package, which cuts against a
repository whose premise is that the machine is reproducible from manifests. It
commonly costs a few hundred milliseconds of startup. And it would be a framework
managing what is genuinely three `source` lines, since the two plugins that
matter are packaged.

**Powerlevel10k was rejected** for being AUR-only here and now in maintenance
mode by its author's own description. starship does the same job as an official
package configured by one file — which means the prompt is templated from the
palette and matches the desktop — and works on any shell, so a later change of
shell does not mean a new prompt to learn.

### Startup time is a constraint, not an aspiration

A shell that takes noticeably long to appear is worse than a plain one, and the
cost creeps up one addition at a time. `checks/session.sh` measures interactive
startup and fails past 400ms, so the budget is enforced rather than hoped for.

### The login shell is changed last, and only if the config parses

`sync.sh` sets the login shell after applying dotfiles, and only when
`zsh -n ~/.zshrc` succeeds. Switching first would hand over a shell whose
configuration does not exist yet, and a syntax error would otherwise become the
thing greeting every login. The installer does the same check.

---

## Tools take their colours from the terminal

**Decision:** `eza` and `bat` are configured to use ANSI colours rather than
carrying their own themes.

### Why

Both can be themed independently, which would mean two more places holding a
copy of the palette and two more things to forget when it changes. Setting
`BAT_THEME=ansi` makes them use the sixteen colours foot already gets from
`.chezmoidata/themes.toml`, so they follow the desktop for free.

### Trade-off

Aliasing `ls` and `cat` means the muscle memory does not transfer to a machine
without these tools. Both are aliases rather than replacements, so the real
commands remain a `command ls` away.



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

## The VM renders in software, and that is the hypervisor's doing

**Decision:** Accept software rendering inside the virtual machine. Do not chase the `failed to create dri2 screen` warnings from inside the guest.

### Why

Three independent signals agree, so this is established rather than inferred:

```
[drm] features: -virgl +edid -resource_blob -host_visible     (kernel, at boot)
Refusing to try glamor on llvmpipe                            (Xwayland)
libEGL warning: egl: failed to create dri2 screen             (Mesa)
```

`-virgl` is the cause. The virtio GPU is presented without 3D acceleration, so Mesa has no hardware path to a DRI screen and falls back to llvmpipe, the LLVM software rasteriser. The warnings are the symptom of that, not a fault in the configuration.

Nothing in the guest can fix it. 3D has to be enabled on the hypervisor side - in virt-manager, *Video* set to `virtio` with 3D acceleration, which also requires *Display* `spice` with OpenGL enabled.

The presence of `/dev/dri/renderD128` is a red herring worth recording, because it looks like evidence of acceleration and is not: the render node exists while `number of cap sets: 0` says there is nothing behind it.

### Trade-off

The desktop is drawn by the CPU. It is perfectly usable at this resolution, and it is why this VM is a poor place to judge anything about smoothness, animation or compositor performance. A judgement about how a compositor *feels* - which TASK-31 will need - should not be made here.

### What this means for real hardware

The same warning on a physical machine would mean no acceleration there either, which would be a genuine problem rather than a VM artefact. `checks/session.sh` distinguishes the two: software rendering on a virtio GPU reporting `-virgl` is reported as expected, while software rendering on anything else is a failure.

### Alternatives considered

**Declaring Vulkan or Mesa driver packages** to force a different path. Rejected: there is no hardware path to select. `mesa` is now declared explicitly, but for the reason `polkit` is - the desktop relies on it directly and a dependency change should not remove it silently - not because declaring it changes rendering.

---

## Workspaces stay per-output, as sway does them

**Decision:** Keep sway's model, where each workspace belongs to exactly one output. Do not script a spanning or synchronised workspace layer on top of it.

### Why

The wanted model was the GNOME and macOS one: a workspace spans every display, so it holds a whole task across both screens and one shortcut moves between them. Sway does not work that way, and the difference is structural rather than a setting.

Demonstrated on two real outputs, using `swaymsg create_output` to add a second one without needing physical hardware. Switching to a workspace that lives on the current output behaves as expected. Switching to one that lives on the *other* output does not bring it over - it moves focus to that output instead. The switch sends you to the workspace rather than bringing the workspace to you.

A promising-looking dead end, recorded so it is not tried twice: `workspace <name> output A B` does not span. sway(5) says "the first available will be used" - it is a priority list with failover.

What could be built is a script that switches every output together, giving grouped workspaces on top of sway's model. Rejected for three reasons. This machine has one display, so the problem is anticipated rather than felt, while the number-row reach that prompted the discussion is felt daily. The seams are predictable - workspace naming, the bar, output hotplug, `back_and_forth` - and each is a place for the abstraction to leak. And it would be discarded entirely if the compositor changes, which is an open question in its own right.

### Trade-off

The multi-display complaint is deferred, not answered. When a second display arrives it will still be true that a workspace is half a workspace, and that will have to be faced then - by living with it, by scripting around it, or by changing compositor.

### The cost of the model that was wanted

Worth recording, because the request had not accounted for it. Where workspaces do span displays, both screens switch together: a video or reference document on the second screen cannot stay put while the first changes. KDE has had spanning virtual desktops for two decades and is adding per-screen desktops in Plasma 6.7 after twenty-one years of requests, which is fair evidence that the model has real costs rather than being straightforwardly better.

### Alternatives considered

**niri.** Does not solve this - its workspaces are per-monitor vertical stacks, same as sway in that respect. It does have a first-class overview with workspace reordering, which sway lacks entirely.

**COSMIC.** The only option found that offers the wanted model natively, as an explicit "workspaces span multiple displays" setting, alongside an overview and per-workspace tiling.

**Hyprland.** Per-monitor by default, overview via plugins.

Any of these means changing compositor, which belongs to that decision rather than this one, and has been recorded there.

---

## XWayland and scaled outputs

**Decision:** Accept that XWayland clients blur on a scaled output, and minimise how many there are rather than trying to fix the scaling.

### Why

`sway-output(5)` states it directly: *"HiDPI isn't supported with Xwayland clients (windows will blur)"*. An X11 client renders at the unscaled size and the compositor scales the buffer up, so on an output at scale 2 it is drawing at half resolution. No compositor setting changes this; it is an upstream limitation, not a missing option.

Measured rather than assumed. On a headless output at 1280x800 scale 2, the same GTK application was launched twice, once with `GDK_BACKEND=wayland` and once with `GDK_BACKEND=x11`, and confirmed to take different paths - sway reported `shell=xdg_shell` against `shell=xwayland`. The XWayland window had visibly softer text, and picked up different icons besides, which suggests the theme resolution differs by backend as well as the scaling.

What can be done is keep applications off XWayland, which `environment.d/10-appearance.conf` already does with `QT_QPA_PLATFORM`, `SDL_VIDEODRIVER` and `MOZ_ENABLE_WAYLAND`. Nothing this setup installs needs XWayland today - qutebrowser, Thunar and pavucontrol all run natively, and XWayland only started at all when one was deliberately forced onto it - so the limitation currently costs nothing.

### Trade-off

The moment an X11-only application is genuinely needed on a scaled display, it will look worse than everything around it and there will be no configuration answer. That is a real cost, deferred rather than avoided.

### Alternatives considered

**`scale_filter nearest`.** Only changes how the upscale looks, not that it happens: sharper but blockier. The default `smart` already uses nearest at integer scales, which is the sensible choice, and reaching for `nearest` would only matter at a fractional scale.

**`xwayland disable`.** Removes the blurry-window problem by removing X11 support entirely. Rejected: it converts a cosmetic problem into an application that simply will not run, and the compositor loads XWayland lazily anyway, so an unused XWayland costs nothing.

---

## Key remapping with keyd

**Decision:** Swap left Alt and left Control with `keyd`, a system-wide remapping daemon, rather than setting `xkb_options` per context.

### Why

Left Control is the modifier reached for most often - copy, paste, word-wise motion, terminal signals, every readline binding - and it sits in the far bottom corner under the weakest finger. Left Alt sits under a stronger finger and is used far less.

The swap itself is a stock xkb option. The problem is that four things on this system read a keyboard configuration independently:

| Context | Reads |
| --- | --- |
| sway | `xkb_options` in `config.d/10-input.conf` |
| The console | `/etc/vconsole.conf`, written from `install.conf` |
| The greeter | its own configuration, before any user session |
| XWayland | a separate path to the keymap |

Setting the option in each means four places that can drift apart, and getting three of four right is worse than doing nothing: the one most easily forgotten is the console, which is what `Ctrl+Alt+F2` reaches when the session will not start - exactly when muscle memory is least available.

keyd remaps at the evdev layer, below xkb and below the console keymap, so all four inherit one file. It does not keep the four in agreement; it removes three of them. `keyd` is in `extra`, which matters because this repository has no AUR support at all.

A useful property of the swap specifically: `Ctrl+Alt+F2` still needs the same two physical keys, because both of its modifiers moved.

**Universal, not per-machine.** The config matches `[ids] *`, so it applies to every keyboard on every machine built from this repository. The swap is a property of the hands rather than of the hardware, and a per-machine setting would mean the modifier moving depending on which machine was in front of you - the opposite of what building muscle memory needs. An external keyboard that is already laid out differently is the one case that would need its own section, keyed by the device id `keyd -m` reports, and that is a local exception rather than a reason to make the whole setting per-machine.

### Trade-off

A daemon running as root with an exclusive grab on every keyboard. A config it cannot parse means no usable keyboard on the machine you would need in order to fix it, so `apply-config.sh` runs `keyd check` and refuses to enable the unit rather than starting a daemon that would lock the machine out. keyd documents a panic sequence - `backspace+escape+enter` held together - which terminates it and hands the keyboard back.

Bindings are written with `layer(alt)` rather than `leftcontrol = leftalt`. A bare key assignment emits the keycode without the modifier semantics, and keyd warns about exactly this; the direct form would have looked correct and composed wrongly.

### Alternatives considered

**udev hwdb.** A `KEYBOARD_KEY_*` remap in `/etc/udev/hwdb.d/` is also evdev-level and system-wide, and needs no package at all, since it is built into systemd. Rejected because it does not grow: it is a static scancode remap, and TASK-19 anticipates a keyboard-driven interaction layer that would want layers and tap-hold. Paying for the daemon once was judged better than doing hwdb now and migrating later. For a single permanent swap and nothing more, hwdb would have been the more principled choice.

**`xkb_options` in sway alone.** Rejected: it covers the session and leaves the console, the greeter and the recovery path unswapped.

---

## Default applications are set, not declared

**Decision:** Set default applications with `xdg-mime` from a chezmoi `run_onchange_` script, rather than shipping `~/.config/mimeapps.list` as a dotfile.

### Why

`mimeapps.list` is a **shared** file, which is the whole difficulty. This repository wants to say what opens an image. Applications write to the same file at runtime to register themselves - Claude Code puts its `claude-cli://` handler there, and browsers and mail clients do the same on install.

chezmoi owns a file completely. Shipping `mimeapps.list` as a dotfile would mean every `sync.sh` overwrites the live file with the repository's copy, silently deleting anything an application had registered since. Links would stop working and nothing would report it - the failure mode this repository keeps finding, and one that would recur for every future application rather than once.

`xdg-mime default` changes only the entries it is given and leaves the rest of the file alone, which is exactly the semantics a shared file needs.

The alternative of shipping the file *including* the known runtime entries was rejected: it bakes an application's private detail into the system build, and it only works until the next application registers something.

### Trade-off

This is the first thing in `setup/dotfiles/` that executes rather than being copied, so `chezmoi apply` now runs code. That is a real change in what applying dotfiles means, and it was taken deliberately rather than by accident. The mitigations: `run_onchange_` runs the script only when the script itself changes, not on every sync; it is a readable shell script in the repository like everything else; and it fails loudly if a `.desktop` file it names does not exist, rather than setting a default that points at nothing.

Because the file is only edited rather than owned, a mapping changed by hand will not be reverted. That is a feature here - the same reasoning as the machine-local drop-in - but it does mean the repository describes the defaults it sets and not the full state of the file.

### Alternatives considered

**Ship `mimeapps.list` as a dotfile.** Rejected, as above: clobbers runtime registrations.

**Set it by hand once.** Rejected: it is then not reproducible, which is the point of the repository.

---

## Machine-local dotfile changes

**Decision:** Ship a drop-in the repository does not own. `.zshrc` is fully managed and sources `~/.config/zsh/local.zsh`, which `.chezmoiignore` keeps chezmoi from ever writing, diffing or removing.

### Why

Editing a chezmoi-managed file on one machine leaves it diverged with no route back except remembering to fold the change in by hand. The next sync then asks a question at the worst possible moment, and the honest answer is usually "not now".

Three kinds of divergence were being conflated, and only the middle one was expressible:

| Kind | Belongs in | Survives a rebuild |
| --- | --- | --- |
| Universal | the repository | yes |
| Per-machine but declared | chezmoi templates and profiles | yes |
| Machine-local scratch | `~/.config/zsh/local.zsh` | no |

The third had no mechanism at all, so anything in it had to be typed into a managed file. That is what produced the conflict, and it also hid a real bug: a `PATH` line added by hand was not machine-local at all. `dot_local/bin/` installs executables and nothing ever put that directory on `PATH`, so every machine built from this repository had helper scripts that could not be run by name.

The rule that decides the column: **put things in the local file that you are content to lose when the machine is rebuilt.** Anything you would be annoyed to lose is universal or declared per-machine, and belongs in git.

### Trade-off

Configuration for this machine is deliberately outside version control, so it is not backed up and not reproducible. That is the point of the category, but it means the local file is the one place in this setup where "it works on my machine" is allowed to be true.

### Alternatives considered

**Leave `.zshrc` unmanaged and check only that an import line is present.** Rejected. It gives up the ability to push a shell change to every machine, which is what the repository is for, and enforcing a line inside an unmanaged file needs a `modify_` script - more machinery for less. Inverting it keeps the shared file managed and puts the escape hatch inside it.

**Require every local change to be folded back in.** Rejected as the only option, though `sync.sh` now prints the `chezmoi re-add` command for each differing file so it is one command when it is the right answer. Insisting on it for everything makes the repository the enemy of trying something quickly.

---

## Switchable themes, and what a theme is allowed to cover

**Decision:** `.chezmoidata/themes.toml` holds a table per theme. Which theme is selected is machine-local, in chezmoi's own config file under `[data]`, and `~/.local/bin/theme` writes it. A theme covers the desktop's own chrome and its wallpaper. It does not cover GTK applications, which fixes every theme as a dark theme.

### Why

One palette already drove the whole desktop: sway, waybar, foot, rofi, mako, swaylock and starship are all templates reading the same values, so changing a colour meant editing one file. What did not exist was a second palette, or any way to move between them.

The mechanism is the interesting part, because **nothing here reads colours at runtime.** Every consumer holds a copy rendered at apply time, so there is no variable to set — switching means re-rendering and then persuading each consumer to reload, and they do not reload the same way.

| Consumer | How it picks up a change |
| --- | --- |
| sway | `swaymsg reload`, which also restarts swaybg, so the wallpaper follows |
| mako | `makoctl reload` |
| waybar | no stylesheet reload exists; the unit is restarted |
| rofi, swaylock | nothing — read on every launch |
| starship | nothing — read per prompt |
| foot | **cannot.** Terminals already open keep their colours |

foot deserves the emphasis because it looks like it should work. `SIGUSR1` switches between the `[colors-dark]` and `[colors-light]` sections already present in the config, which is a different thing from rereading the file, so there is no signal that helps.

Three decisions inside the decision:

**Where the selection lives.** In chezmoi's machine-local config, not the repository. Switching a theme should not produce a commit, and two machines syncing the same repository should be able to disagree. This works because chezmoi merges config data *over* `.chezmoidata` — which was verified in both directions, and with no config file at all, since the installer chroot runs in exactly that case and must still get a theme.

**What triggers the reload.** A `run_onchange_` script, not the switcher. A theme switch is not the only way the colours change: editing a value in `themes.toml` and running `sync.sh` changes them too, and a reload owned by the switcher would not happen then. The rendered script embeds the theme name *and* a hash of the selected palette, so both cases re-run it.

**How far a theme reaches.** GTK applications read `GTK_THEME` once at session start and cannot be recoloured from a palette without shipping real GTK themes. They stay Adwaita dark. The price is a rule: **every theme in `themes.toml` must be a dark theme**, because a light one would leave every dialog looking like it belonged to a different computer. That rule is the whole reason the boundary is written down rather than left to be discovered.

The wallpaper is part of a theme, generated from it rather than chosen, and generated **on the machine** rather than committed. The bar, the borders and the glow were tuned to sit against the background; a palette swap that left the old picture behind would clash with itself. And committing the images does not scale: three themes at one image each was already 7.8M of tracked PNG, and eight themes with four styles apiece would be around 90M, growing by roughly ten megabytes per theme added. That is precisely backwards, because the whole point of the arrangement is that adding a theme should be free. `~/.local/bin/wallpaper` renders and caches them, which is why it is the one piece of the theming machinery that lives in the dotfiles rather than in `tools/`.

Within a theme the background style is chosen separately - four generated styles, or a path to an image of your own - and remembered per theme, so switching away and back returns what you had rather than resetting.

One writer, not two. `theme` and `wallpaper` both record machine-local choices, and for a while each carried its own copy of the TOML writer. They disagreed: the theme switcher's copy flattened nested tables, so choosing a wallpaper and then switching theme turned `[data.wallpaper]` into a string, and every subsequent `chezmoi apply` died inside the sway template. The bug was not that a writer was wrong, it was that there were two. `~/.local/lib/desktop_config.py` is now the only one.

### Trade-off

`palette.toml` used to mean "the colours". `themes.toml` means "the colours available", and what the desktop is actually wearing is now a machine-local fact that git does not record. Reading the repository no longer tells you what a given machine looks like — `theme --current` does.

Switching is also not instant. It is a `chezmoi apply` plus a set of reloads, measured at 0.6s when the wallpaper is already cached and about 2s the first time a theme-and-style pair is used, since the image is rendered then. It is a rebuild rather than a variable assignment, and any terminal already open keeps its old colours until it is reopened.

Generating rather than committing also means the images are not reproducible from the repository alone in the sense a checked-in file would be - they are reproducible from the generator, which is deterministic and seeded, but a machine with no `python3` would have no wallpaper. `python3` is already a hard dependency of half the helper scripts, so this adds no new one.

### Alternatives considered

**A script that rewrites the palette in place.** Rejected. It makes the repository's state depend on which theme was last chosen, so the machine holds a modified tracked file forever and the next real diff is buried under it.

**Colours read at runtime instead of rendered.** Not available. None of these programs support it; the closest is foot's two-section toggle, which is a light/dark switch and not a palette.

**Let a theme carry GTK too, by declaring light or dark and rewriting `GTK_THEME`.** Rejected for now. `environment.d` is read when the user manager starts, so GTK would only catch up after a re-login — a switch that is half immediate and half not is worse than one with a stated boundary. Generating a GTK theme per palette was rejected as much the largest option for the least-used surface.

**Committing the generated images anyway.** Rejected on arithmetic. It also has a subtler cost: every theme added would make the repository bigger for everyone who clones it, which turns "add a theme" into a decision rather than a whim.

**Fixed terminal colours across themes.** Rejected. A theme that changes the bar and leaves the terminal in the old palette looks half-applied. The sixteen ANSI colours travel with the theme, but keep their own identities — a theme that made `blue` gold would break every program that assumes a diff is red and green.

---

## The bar reports and responds

**Decision:** Every module in the bar does something relevant when clicked. The centre carries the date, the time, and whatever is playing — not the focused window's title.

### Why

A readout you can only look at teaches you to stop looking. The bar already knew the answers to "why is this slow" and "what am I connected to", and clicking either one did nothing, so the next step was always a terminal. Clicking a reading now opens the thing that explains it: cpu and memory open btop, the network module opens nmtui, the clock opens a calendar.

The window title went because it was the least useful thing on the bar. Sway already says which window is focused, by drawing the accent border around it, and the title was usually a truncated path repeated from the window itself. The date and time earn that space — they are the thing most often wanted at a glance, and they were squeezed into the right-hand run of readouts. What is playing earns the rest of it, and had nowhere to appear at all.

Windows opened from the bar **toggle**. Clicking the clock twice should put the calendar away, not open a second one, and without that a stray double-click leaves clutter to tidy up. `~/.local/bin/sway-toggle-window` addresses one window by `app_id`, which is deliberately not sway's scratchpad: the scratchpad is a single global stack shared by everything, so showing the calendar would hide whatever else was in it.

### Trade-off

The `app_id` now ties three files together — the command that sets it, the toggle that matches on it, and the `for_window` rule that floats it. Nothing about that coupling is visible when reading any one of them, and when they disagree the window simply tiles rather than erroring. `checks/session.sh` checks it for that reason.

Losing the window title also loses the one case it was good for: a tabbed container, where several windows share a space and only the focused one's title distinguishes them. Sway draws tab labels itself, so the information is still on screen, just not in the bar.

### Alternatives considered

**A calendar application.** Rejected. There is nothing to integrate with — no mail, no events, no accounts — so it would be a large GTK dependency rendering what `cal` already prints. The rule that new tooling must earn its place decides it.

**A custom script polling `playerctl` for the media display.** Unnecessary: waybar here links `libplayerctl`, so the built-in `mpris` module does it, follows whichever player is active through `playerctld`, and hides itself entirely when nothing is playing.

**Binding the media controls explicitly.** Rejected once the manual was read. `waybar-mpris(5)` already binds left to play-pause, middle to previous and right to next, and its bindings act on the player the module is following. Overriding them with `playerctl` would have sent the same commands by a longer route, and a config line that changes nothing is how a file stops being readable.

**Scroll bindings on the media module.** Dropped: the manual documents no scroll handling for it, and configuring something undocumented is indistinguishable from configuring nothing.

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
