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

### zswap is turned off, so this entry describes what actually happens

Everything above was applied correctly and was almost entirely inert until
TASK-89, and it took measuring to notice.

The Arch kernel ships `CONFIG_ZSWAP_DEFAULT_ON=y`, and nothing here turned it
off. **zswap** is a compressed cache that sits *in front of* a swap device: it
compresses pages into its own pool, capped at 20% of RAM, and writes back to the
device behind it only what that pool cannot hold. So every page went into zswap
first, and zram — sized at half of RAM — caught the overflow. On the reference
machine after ten and a half hours:

| counter | pages | meaning |
| --- | --- | --- |
| `zswpout` | 920,911 | compressed into zswap |
| `zswpwb` | 9,415 | ever reached zram — **1.0%** |
| `pswpout` | 9,415 | identical, so every page in zram arrived that way |

zram peaked at 7.0 MiB of a 1,951 MiB device. The sizing expression, zstd, the
priority and both sysctls were all doing exactly what they say, to a device
handling one percent of the traffic.

**Decision: zswap off, zram is the compressed swap.**

The two do not stack usefully. zswap's purpose is to avoid touching a disk — it
absorbs pages in RAM so the slow device behind it is written to less often. That
is a real gain when the device is an SSD. When the device is *also* RAM, the
arrangement costs rather than saves: a page is compressed into zswap, and on
writeback it is decompressed and handed to zram, which compresses it again. Two
compressions and a decompression, both in RAM, to store one page.

So the layer to keep is the one whose premise still holds. This machine has no
disk swap, by the decision above, which removes zswap's reason to exist.

### Trade-off

zswap's pool is a fixed fraction of RAM and zram's is not, so zswap gives a
harder ceiling on how much memory compressed swap can consume. Giving that up
means the sizing question is now zram's alone — which is TASK-72, and which was
unanswerable while it was unclear who was holding the pages.

### Alternatives considered

**Keep both, deliberately.** Would need an argument for why a small pool in
front of a large one in the same memory is worth two compressions per page.
There is not one here; the numbers above are what that arrangement produced.

**zswap only, dropping zram.** zswap is a cache, not a swap device — it needs a
real one behind it, which means a disk swapfile. That is rejected above, and
this would reverse it sideways.

### How it is applied

`/etc/tmpfiles.d/zswap.conf`, written by `setup/system/apply-config.sh`, so it
reaches a fresh install and a sync from the same file.

`zswap.enabled=0` on the kernel command line is the more usual answer and would
have been better if it could reach a running machine. It cannot: the boot
entries under `system/loader/` are rendered with the root UUID at install time
and are deliberately never applied by sync, so a cmdline change would land on
fresh installs and no existing machine. zswap is built in rather than a module,
so modprobe.d has nothing to act on either — but the parameter is writable
through sysfs, and tmpfiles is what systemd provides for writing sysfs at boot.

`checks/session.sh` fails if zswap is ever enabled again, because the kernel
default will re-enable it the moment that file stops being applied.

### The size, revisited now that zram actually holds the pages

`min(ram / 2, 8192)` was chosen before it was clear which layer held anything.
With zswap off it is zram's question alone, so TASK-72 measured it rather than
leaving it merely unchallenged.

On the reference machine, 3.9 GiB of RAM: fifteen hours of ordinary use put
769 MiB into the 1,951 MiB device at a 1.93x compression ratio. A bounded 1.2 GiB
pressure test — tiling real file bytes rather than zeroes, which would have
compressed unrealistically well — drove the device to 99.5% of its *logical*
capacity while using 855 MiB of actual RAM to hold it, 22% of the machine, at
2.11x. Available memory never fell below 30%, well clear of earlyoom's
thresholds, and released cleanly with no OOM kills.

**The size stays**, and the reason is the case the ratio does not cover rather
than the ratio itself. Nothing here sets `mem-limit`, so zram's RAM ceiling is
bounded only by its disksize: compression is what usually keeps it far under
that ceiling, not what enforces it. Against incompressible data the device can
approach its full size in real memory. `ram / 2` is therefore the thing capping
the worst case at half the machine — raising the fraction toward the 100–200%
some guides suggest would raise that ceiling without addressing what actually
filled first here, which was the device's logical swap-slot capacity, not RAM.
That is backstopped by page-cache reclaim, kswapd already reclaiming on the
order of 11 GiB a day on this machine, rather than by a hard failure.

(`mem_limit` cannot be read back to confirm this from the kernel — the sysfs
attribute is write-only. The claim rests on the configuration not setting one.)

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

### The timeout that paid for it, and the ESP that holds it

"A short timeout" was three seconds, and it was invisible. `systemd-analyze`
reports 4.653s for this machine and does not include the menu at all: it
accounts from the kernel onwards unless the bootloader exports
`LoaderTimeInitUSec` into an EFI variable, and OVMF does not. So the real wait
from power-on to a greeter was nearer 7.7s, roughly 39% of it a menu nobody
reads, and every measurement anyone took said 4.653s. TASK-90.

Now one second. **Not zero**, which was the obvious answer and is the wrong one
here: systemd-boot(7) confirms the menu can still be reached with `timeout 0` by
holding space, and then says the deciding part — "depending on the firmware
implementation the time window where key presses are accepted before the boot
loader initializes might be short. If the window is missed, reboot and try
again, possibly repeatedly." This menu exists to reach the fallback entry, which
is wanted on the boot where something has *already* gone wrong. A recovery path
that takes several attempts to hit is the wrong thing to economise on.

One second is a deterministic window and returns two of the three. For a planned
fallback boot, `bootctl set-timeout-oneshot` arms the menu for the next boot
only, from a working system.

Two things on the ESP were examined at the same time and **deliberately left**:

- `initramfs-linux-fallback.img` is 211.6 MiB of the 258 MiB used, because the
  fallback preset drops `autodetect` and includes every module. That is the
  entire point of it, it is an ESP cost rather than a boot cost, and the ESP is
  1 GiB with 765 MiB free. Shrinking the recovery image to save space on a
  partition that has space is the wrong trade.
- `intel-ucode.img` (14.6 MiB) and `amd-ucode.img` (0.3 MiB) both sit there and
  neither is loaded — the `microcode` hook embeds the right one into the image,
  and no loader entry or `/proc/cmdline` names them. They are not deletable in
  any meaningful sense: pacman owns both files and a package update writes them
  back. Both packages are declared deliberately so one repository builds an
  Intel or an AMD machine. 14.9 MiB to avoid fighting the package manager over
  files that cost nothing at boot.

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

## systemd-timesyncd keeps the clock, and the timezone is a fixed answer

**Decision:** Enable `systemd-timesyncd` from `setup/system/apply-config.sh`,
against the Arch NTP pool, with the timezone pinned to whatever `install.conf`
says rather than detected.

### Why

Until TASK-191 this system had no clock discipline at all. `03-system.sh` set
the timezone and ran `hwclock --systohc` once, at install, which writes the
system time *to* the RTC and never reads it back. So the hardware clock drifted
unattended for as long as the machine was off, and the machine then booted with
whatever it had drifted to. The bug was reported the way this class of bug
always is — "the time is wrong after it has been off for a while" — and
`timedatectl` confirmed it exactly: `System clock synchronized: no`, `NTP
service: inactive`.

timesyncd is the option that costs nothing. It ships as part of systemd, so
there is no package to add to `setup/packages/` and no manifest entry that has
to be justified later. It needs no configuration either: Arch compiles
`0..3.arch.pool.ntp.org` in as `FallbackNTP`, which is what the stock empty
`[Time]` section resolves to — so the fix is one unit name in `ENABLE_UNITS`,
in the one file both install paths already call. Once synchronised it also
keeps the RTC honest through the kernel's 11-minute mode, which is what stops
the drift from accumulating again between boots.

The timezone is deliberately *not* detected. Geolocation for a fixed desk is a
network dependency, a privacy question and a failure mode, all bought to answer
a question whose answer never changes. `install.conf` already carries
`TIMEZONE`, the wizard already asks for it, and the zoneinfo database already
knows when Europe/London switches to BST — so a fixed timezone and a synced UTC
clock give a correct wall clock all year with nothing seasonal to maintain.

The RTC stays in UTC, which is the other half of that. A hardware clock in
local time turns every seasonal change into an hour of boot-time error — the
same symptom TASK-191 was filed about, surviving the fix — so `checks/session.sh`
asserts it alongside the rest.

### Trade-off

The clock is only correct once the network is up. A machine that boots with no
connection keeps its drifted time until one arrives, and timesyncd steps rather
than slews on a large offset, so a long-off machine sees a visible jump a few
seconds into the session rather than a gradual correction. Both are acceptable
for a desktop; neither would be for a machine writing ordered timestamps.

### Alternatives considered

**chrony.** Better at exactly what this system does not do: it disciplines a
drifting clock more carefully, copes with intermittent connectivity, and can
serve time to other machines. Rejected because all of that is a package, a
config file and a service to understand, in exchange for accuracy no one here
can perceive. If this machine ever needs to be a time source, that is when to
revisit it.

**`ntpd`.** The reference implementation, and heavier still. Same reasoning,
with a longer history of configuration to get wrong.

**An `hwclock --hctosys` at boot and nothing else.** Rejected outright: it
reads the drifted clock rather than correcting it, which is not a fix, it is
the bug written down.

**Detecting the timezone from the network.** Rejected as described above. The
wizard question stays; it is answered once per machine and is the right place
for it.

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
hosted by cage. The session is launched as `uwsm start -N Sway -D sway -- sway`.

The `.desktop` form this entry used to name - `uwsm start -- sway.desktop` - is
the one thing that must NOT be used, and `system/wayland-sessions/sway-uwsm.desktop`
says so at length: it makes uwsm re-read a desktop entry that points back at
uwsm. The documentation said the opposite of the config for long enough to be
worth noting here rather than quietly correcting.

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

It is also GTK, like Waybar and the GTK portal, so it introduces no second
toolkit, and
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

pavucontrol and qutebrowser each picked their own defaults, so the
desktop looked assembled from parts rather than designed. The bar had been
carefully styled, which made the mismatch elsewhere more obvious rather than
less.

The settings files are the mechanism, and they are the only one. `GTK_THEME` was
set alongside them for a while, on the reasoning that an environment variable
also catches applications started outside a normal desktop session and works
regardless of which GTK version an application uses. Both of those are true, and
they cost more than they were worth: the variable overrides the settings files,
so it fixed every GTK application to one mode for the life of the session and
became the stated reason this desktop could not have a light theme. It is no
longer set, `gtk-3.0/settings.ini` is a template that follows the selected
theme's `mode`, and `checks/session.sh` checks the variable stays unset. See
"Light themes, and the reason that did not survive being checked".

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

### The second half: nothing exists just because

Upstream ships arrow keys alongside `h/j/k/l` so newcomers are not stuck before
learning vim keys. Keeping both is exactly the kind of thing this setup argues
against elsewhere — the same reasoning applied to a bar module or a package
would delete it. The arrow duplicates are gone, as is stacking, which does the
same job as tabbed.

`Alt+Tab`, which had been bound to workspaces, is now unbound: everywhere else in
computing it means "switch window", and applications sometimes want it.
`$mod+Tab` returns to the previous workspace, which was the useful part.

This took 80 bindings to 64, but the count is not the point. Every remaining
binding is there because someone decided it should be.

**And that is the actual rule, which is not "one way to do each thing".** This
section used to be titled that way, and taken literally it is wrong. The test a
binding has to pass is whether it exists for a clear reason, not whether it is
unique. Arrow keys failed that test because their only argument was familiarity
to someone who has not learned the scheme yet. Two bindings that suit genuinely
different hands both pass it.

The worked case is resizing. `$mod+Shift+equal` / `$mod+Shift+minus` on the
keyboard and `$mod+Shift`+wheel on the pointer do exactly the same thing, and
both stay, because **rearranging and sizing windows is a spatial task and
spatial tasks suit a pointer**, while everything else in this scheme is a
discrete one and suits a key. Deleting the wheel gesture to satisfy a slogan
would have made the desktop worse.

The corollary is that stepping through workspaces now has three routes — the
number row, `$mod+Ctrl+h/l`, and bare `$mod`+wheel — where an earlier version of
this section claimed stepping had been removed altogether for duplicating the
number row. It had not; it came back on the home row because the number row is a
stretch, and the wheel was added because that too is a spatial motion you make
without looking. Each has a reason. That is the whole requirement.

### How it is enforced

`checks/sway-bindings.sh` fails if any combination is bound twice, comparing
across all fragments with `set` variables expanded and modifiers sorted, so
`$mod+Shift+q` and `Shift+$mod+q` are recognised as the same binding. It also
prints the full table, which is the practical documentation of the scheme: 64
bindings across four fragments is more than can be held in mind while editing
one of them.

### What Shift means, which is two things

Closing a window is `$mod+q`, not `$mod+Shift+q` as upstream ships it. It is one
of the most frequent actions there is, and Shift is a real cost when repeated
all day.

The session bindings keep Shift deliberately: reload on `$mod+Shift+c` and exit
on `$mod+Shift+e` are rare, and being slightly awkward is a feature when the
consequence of a mistake is losing the session. Shift there marks "you probably
meant this", not "this is the second variant".

Shift carries a second, unrelated meaning in the window cluster, and it is worth
naming because the two look alike and are not: **`$mod+Shift` means "act on this
window rather than move the focus"**. `$mod+h/j/k/l` moves focus and
`$mod+Shift+h/j/k/l` moves the window; resizing joined that group for the same
reason, on `$mod+Shift+equal` / `$mod+Shift+minus` and on `$mod+Shift`+wheel.
Arranging a layout means moving and sizing in the same breath, so both live
under one hand posture held down. A shorter chord would have been cheaper to
press once and more expensive to actually use — "prime" has to mean cheap in the
sequence you really perform, not cheap in isolation.

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
through Waybar and `xdg-desktop-portal-gtk`. Choosing anything else would mean
overriding a
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
uwsm start -N Sway -D sway -- sway
```

Session components — the bar, notifications, idle handling — are systemd user
units bound to `wayland-session@sway.target`, not sway `exec` lines.

Both details were wrong here until TASK-23 checked them against what the machine
actually runs. `graphical-session.target` in particular is not a harmless
simplification: it is reached by *every* compositor, so a unit wanted by it
would also start under a different desktop, which is the specific mistake the
architecture notes warn against.

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
`dotfiles/dot_config/systemd/user/wayland-session@sway.target.wants/` rather than
by running `systemctl --user enable` during installation.

(This entry said `graphical-session.target.wants/` until TASK-23. That directory
does not exist in the repository and has not for some time - the units moved to
the sway-specific target precisely so they would not start under another
compositor, and `.chezmoiremove` still deletes the old one from machines that
have it.)

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

## The everyday browser is on trial, behind a one-line switch

**Superseded by *The everyday browser is firefox* (TASK-183).** The trial ran
and answered, and the answer was neither of the two on trial. The switch itself
survives — it is how `browser --use` still reaches all three — but "not a
decision yet" is no longer true. Kept because the measurements below are still
the only ones taken, and the new entry rests on them.

**Decision:** Not a decision yet, deliberately. `$mod+b` opens whichever of
qutebrowser and vimb a one-line state file names, so the question can be
answered by use rather than by argument.

### Why

TASK-91 chose the *heavy* browser and never asked whether qutebrowser is the
right *light* one — it recorded that it settled the matter "deliberately
without an extensive measurement exercise". TASK-177 did the measurement. Cold
start, keypress to a mapped window, on the balanced power profile:

| | | |
| --- | --- | --- |
| foot | 135 ms | the target: a terminal |
| **vimb** | **354 ms** | webkit2gtk-4.1, 133 MiB |
| netsurf | 432 ms | its own engine |
| epiphany | 843 ms | webkitgtk-6.0, 131 MiB |
| **qutebrowser** | **1673 ms** | qt6-webengine, 282 MiB |

The useful result is not the ranking, it is the floor. vimb is 193 KiB of
browser on top of WebKitGTK, so its 354 ms *is* the engine starting. No
WebKitGTK browser can be faster, and epiphany's extra half second is its own
GTK4 interface rather than anything to do with rendering. There is no lighter
graphical browser to go looking for, and qutebrowser's extra 1.3 s is
QtWebEngine.

What none of that settles is whether WebKitGTK renders the sites actually used
well enough to live with — it is weaker than Blink on recent JavaScript. That
is answered by a week of use, so the switch exists to make the week cheap and
abandoning it cheaper.

### Trade-off

Two browsers' worth of engine installed while the trial runs: webkit2gtk-4.1's
133 MiB on top of qt6-webengine's 282 MiB. That is the price of deciding by
use instead of by argument, and it is refundable.

`$mod+b` also gains a shell process between the keypress and the browser,
where TASK-174 had just removed one. Bash reading a one-line file is a couple
of milliseconds against a 354 ms floor, so it does not show.

### Alternatives considered

**Store the choice in `chezmoi.toml`**, where the theme, wallpaper style and
glow setting all live. Rejected on the grounds that make the rest of this
entry worth having: reading it needs `desktop_config.py`, which shells out to
`chezmoi data` at upwards of 100 ms, and this is the exact path whose latency
is the subject. A switch that made the fast browser slower would be
self-defeating. It is a plain file in `~/.local/state` for the same reason the
sound pack is — see *Sound packs*.

**Switch the xdg-mime handlers too**, so links from other applications follow
the trial. Rejected for now: that is the change that makes reverting expensive,
and it is not needed to answer the question.

**Just switch to vimb.** Rejected as premature. The measurement says vimb is
faster; it does not say vimb is usable, and this repository has a history of
keeping changes that did not work because nobody wrote down that they had not.

---

## Launching an application gives you a new instance of it

**Decision:** `$mod+b` opens a new browser window rather than fetching the one
already open, and the mechanism is qutebrowser's `new_instance_open_target`
rather than the sway binding.

### Why

Every other launch binding answers with a new instance — `$mod+Return` a
terminal, `$mod+e` a file manager — and the browser was the exception. It ran
`~/.local/bin/browser`, which found the most recently focused qutebrowser
window and moved it to the current workspace. That helper existed for a
measured reason: focusing costs 1ms against 553ms for a new window and 942ms
cold, and saving half a second on a key pressed dozens of times a day is a
real argument.

It was still the wrong behaviour. Asking for a browser and being given a
window from somewhere else is a different action wearing the same key, and
when the window arrives from another workspace the effect is that the desktop
rearranged itself unasked. Reaching an existing window is what window
switching is for.

Putting it in qutebrowser's config rather than on the binding is the part
worth keeping. qutebrowser's default `new_instance_open_target` is `tab`, so
*every* launch route — the launcher, `gio open`, a link handed over by another
application, the terminal — opened a tab in the last-focused window and raised
it. `--target window` on the sway binding would have fixed one route and left
the rest disagreeing. Measured before deciding: with one qutebrowser open,
`qutebrowser https://example.com` produced no `window::new` event on sway's
IPC and left the window count unchanged.

### Trade-off

Every browser launch now costs a window creation instead of 1ms. Measured on
this machine at full clock: about 680ms with the process already running, and
about 1050ms from cold.

It also means this repository ships a qutebrowser config file, which it
deliberately did not before. That file has to call `config.load_autoconfig()`
as its first statement or qutebrowser silently ignores `autoconfig.yml` —
which already held a real setting on this machine — so the cost of the file is
one more place where an omission is invisible.

### Alternatives considered

**`--target window` on the sway binding.** Rejected: fixes the keybinding and
leaves the launcher, the default link handler and every inter-application link
still opening tabs. The inconsistency was the complaint.

**Keeping the helper and adding a separate "new window" binding.** Rejected as
two keys for what should be one, and it leaves the surprising behaviour on the
key most likely to be pressed by reflex.

**Keeping the process warm to hide the cost.** Investigated under TASK-134 and
rejected on measurement: a parked blank qutebrowser holds ~238 MiB resident
against a desktop that idles near 350 MiB, and it only ever saves the
difference between cold and warm. It does not touch window-creation time,
which is where the wait actually is.

---

## Two browsers: qutebrowser for everything, firefox for DRM and extensions

**Superseded by *The everyday browser is firefox* (TASK-183), which reversed
which of the two is which.** Everything below about what qt6-webengine cannot
do, and about why firefox rather than a Chromium, is still current and still
the reason firefox is the one installed. Only the ranking changed.

**Decision:** qutebrowser as the everyday browser, firefox declared alongside it
for the things qutebrowser cannot do.

### Why

qutebrowser is keyboard-driven and vim-styled, which is the reason it suits a
desktop where everything else is. It is also not as light as it looks: 11 MiB of
package over 282 MiB of qt6-webengine, so it is a Chromium engine in a very
small coat rather than a small browser.

What it genuinely cannot do is short and unavoidable. qt6-webengine ships **no
Widevine at all**, so DRM video does not play — that is an absent codec, not a
setting. And it has no WebExtension support, so anything that lives as a browser
extension has nowhere to go.

firefox rather than a Chromium, and the field narrows itself:

| | |
| --- | --- |
| brave, google-chrome, ungoogled-chromium | AUR-only, ruled out on TASK-43 |
| chromium | 416 MiB, and Arch's build has no Widevine either |
| vivaldi 434 MiB, librewolf 424 MiB | both larger; librewolf is a firefox derivative that removes in this direction |
| **firefox 295 MiB** | smallest of the full browsers, DRM enabled by default |

### Trade-off

295 MiB for a browser that will be opened rarely, and the Widevine CDM is
fetched at runtime on first DRM playback rather than coming from the manifest —
so that one component is not reproducible from this repository, only its
retrieval is.

### Alternatives considered

**One browser only.** Rejected: qutebrowser cannot play DRM video at all, and
discovering that on a machine with no alternative installed is a bad time to
find out.

**A lighter second browser** — falkon or GNOME Web are both small. Neither
solves the problem: falkon is qt6-webengine again, so it inherits the same
missing Widevine, and Epiphany's WebKit has its own DRM story rather than a
better one. The second browser exists precisely to be the heavy one.

---

## The everyday browser is firefox

**Decision:** firefox is what `$mod+b` opens and where every link from every
other application goes. qutebrowser and vimb stay installed and stay reachable
through `browser --use`, but neither is the default any more.

This reverses *Two browsers: qutebrowser for everything, firefox for DRM and
extensions* and closes *The everyday browser is on trial, behind a one-line
switch*. Both are kept above, marked superseded, because the reasoning in them
is still load-bearing — it is the ranking that moved, not the facts.

### Why

The trial ran. What it found is not in TASK-177's table, because the table
measures the thing that turned out not to be deciding.

Cold start is a cost paid once per window. A site that does not render is a cost
paid at an unpredictable moment, in the middle of doing something else, and the
only remedy is to open a second browser and start over. Weeks of use put the
second cost well above the first, and put firefox as the browser where it does
not arise. WebKitGTK and QtWebEngine are both behind Blink on recent JavaScript
in ways that show up on ordinary sites rather than exotic ones.

**What the measurements say, taken on 2026-08-27 under TASK-177's method** —
exec to window mapped on sway's IPC stream, best of 3, balanced profile, fresh
profile per run, `about:blank`:

| | firefox | qutebrowser |
| --- | --- | --- |
| warm, libraries in page cache | 862 ms | 363 ms |
| first launch, cold from disk | 875 ms | 803 ms |
| idle PSS, blank page | 674 MiB / 19 procs | 108 MiB / 1 proc |

Three things about that table, none of them comfortable:

**Firefox is slower, and by less than expected.** Cold, the two are within
70 ms of each other. Warm, firefox is 2.4× qutebrowser — because qutebrowser's
figure more than halves with a warm cache and firefox's barely moves, its
libraries being resident already on a machine that runs it. Neither pass
reproduces TASK-177's 1673 ms, so that number should not be quoted against
these; it was a different cache state.

**Firefox uses far more memory than this entry originally claimed.** The first
draft said the RAM argument "did not survive". Measured, it is 6× at idle, and
that sentence was wrong. It is left described rather than deleted because the
correction is the useful part.

**The memory comparison is not like-for-like, which is why it did not decide
anything.** qutebrowser on `about:blank` spawned no QtWebEngine renderer at all
— one process, total. firefox pre-spawns its entire content-process pool on
startup. A real page moves qutebrowser up sharply and firefox very little. The
674 MiB is a true number about a state nobody browses in.

So the honest summary is that firefox costs more on both axes than qutebrowser
does, by less than folklore suggests on speed and by more than this entry first
claimed on memory, and it is chosen anyway — on reliability, which is the axis
none of these numbers measure.

That leaves the reason qutebrowser was chosen in the first place: keyboard-
driven browsing on a desktop where everything else is. **Vimium gives firefox
that**, and TASK-183 made it a tracked, force-installed extension rather than
something clicked in on one machine — which is the only version of that answer
this repository can accept. See *Firefox is configured by enterprise policy,
not by a profile file*.

### Trade-off

**The slower launch is now on the most-used binding**, at 862 ms warm against
qutebrowser's 363 ms, and the heavier browser is the resident one. Accepted
because both costs are bounded and predictable, and paid at a moment when you
are already choosing to switch context — unlike the failure they buy off.

**Three browser engines are installed** where the original decision wanted two:
qt6-webengine's 282 MiB, webkit2gtk-4.1's 133 MiB and firefox's own. Two of
them are now kept for a switch nobody is expected to use. That is refundable
whenever someone decides to spend the line — TASK-183 deliberately did not,
because removing a browser on the same day you change which one is default
makes reverting expensive for no gain.

**A machine built offline gets no Vimium** until its first connected launch,
because firefox fetches the extension itself.

### Alternatives considered

**Keep qutebrowser as the default and firefox on `--use`.** This is the status
quo, and it is what the cold-start numbers argue for. Rejected because the
numbers are not what daily use tripped over.

**Remove qutebrowser and vimb in the same change.** Rejected as two decisions
in one commit. The default is what is being changed; what stays installed is a
separate question, and keeping them makes reverting a one-word edit to
`~/.local/state/browser`.

**Leave the xdg-mime handlers on qutebrowser** — the split the trial
deliberately kept, so that `$mod+b` could change without links following.
Rejected now for exactly the reason it was right then: the split exists to make
a trial cheap, and there is no trial any more. Two browsers answering "open
this link" differently depending on where the link came from is a surprise, not
a feature.

---

## Firefox is configured by enterprise policy, not by a profile file

**Decision:** Everything this repository wants to say about how firefox behaves
is said in `/etc/firefox/policies/policies.json`, installed machine-wide by
`setup/system/apply-config.sh`. No `user.js`, no `prefs.js`, nothing under
`~/.mozilla`.

### Why

Making firefox the default browser meant turning it down. Mozilla ships a
browser carrying a VPN promotion, Pocket, telemetry, Normandy studies, sponsored
new-tab shortcuts and Firefox View, and clicking those off in `about:preferences`
is precisely the untracked, one-machine change this repository exists to avoid.

**The obvious chezmoi route does not work.** A firefox profile lives in
`~/.mozilla/firefox/<random>.default-release/`, where `<random>` is eight
characters generated when the profile is created. chezmoi's source state is a
mapping from a path in the repository to a path in the home directory, and it
cannot address a directory whose name it cannot know. There is no glob, and
`profiles.ini` is written by firefox rather than read from us.

A policy file has none of that shape. It is machine-wide, it applies before any
profile exists, it survives a profile reset or a new profile, and it is exactly
the kind of `/etc` file `apply-config.sh` was built to own — so it reaches a
fresh install and a running machine by one route, which is the property that
matters most here.

It also settles the Vimium question in the same file. `ExtensionSettings`
force-installs an add-on by GUID, so the extension that makes firefox
keyboard-driven arrives on a rebuilt machine without a manual step. An extension
installed by hand would have been the same untracked state as a clicked
preference.

**`/etc/firefox/policies/` rather than `/usr/lib/firefox/distribution/`**, which
is the path most documentation names. Firefox reads the `/etc` one first when
its build sets `MOZ_SYSTEM_POLICIES`, and Arch's build does — read out of
`omni.ja` rather than assumed, with the command recorded in
`setup/system/firefox/README.md`. The reason to prefer it has nothing to do with
precedence: pacman owns `/usr/lib/firefox/distribution/`, and a file this
repository drops into a package-owned directory is a file waiting to be
surprised by an upgrade.

### Trade-off

**JSON takes no comments**, and this repository explains its configuration in
comments. So the reasons live in `setup/system/firefox/README.md`, one line per
policy, next to the file rather than in it — a separation that will drift the
moment someone adds a policy without adding its line. Nothing checks it.

**Policies are heavier than preferences.** Several are set with
`"Status": "locked"`, which greys the setting out in `about:preferences`
entirely. That is the point for a promotion; it is a nuisance if you later
disagree with one, and the remedy is editing the repository rather than the
browser.

**Firefox is visibly "managed"** — `about:policies` exists, and an enterprise
badge appears in some surfaces. Cosmetic, and the honest description of what is
happening.

**It does not cover everything.** Firefox View has no policy and no preference
in Firefox 154 — it is a CustomizableUI widget, and the pref every search result
still names for it was removed. Removing the button is a per-profile manual
step, recorded as one in `setup/system/firefox/README.md` rather than left
looking handled.

**Three dead settings were written and removed during TASK-183**, which is worth
recording because each one looked correct at a different depth. Two were
preferences that no longer exist (`browser.tabs.firefox-view`,
`browser.contentblocking.report.vpn.enabled`) — setting a nonexistent pref
through the `Preferences` policy is completely silent. The third was
`DisablePocket`, which is the policy every guide names, is still in
`policies-schema.json`, validates against it, and is listed by Firefox 154 under
`deprecated_policies` with nothing behind it.

So schema validation is necessary and not sufficient here. `about:policies`
lists what Firefox *applied*, and comparing that page against the file is the
check that caught the third one. It can be captured headlessly; the command is
in `setup/system/firefox/README.md`.

### Alternatives considered

**A `user.js` placed by a `run_onchange_` script** that globs for the profile
directory. This would work, and it was the first idea. Rejected: it runs after
the profile exists, so a fresh machine's very first launch is unconfigured and
the first-run tour appears before anything can suppress it; it silently does
nothing if the glob misses, which is this repository's signature failure; and it
cannot install Vimium at all. Two mechanisms would then be needed where one does.

**`policies.json` in `/usr/lib/firefox/distribution/`.** Rejected on package
ownership, above.

**librewolf instead**, which removes much of this at the source. Rejected on
TASK-91 already, on size, and it remains the wrong shape: it is a fork tracking
firefox with a delay, where this is a 70-line file tracking nothing.

**Leave firefox as it ships and click the promotions off.** Rejected — that is
the untracked one-machine state the whole repository is a refusal of.

---

## Clipboard history: cliphist behind rofi, two watchers, no auto-paste

**Decision:** `cliphist` storing the history, rofi showing it, two watcher units
rather than one, and nothing that pastes for you.

### Why

The smallest thing in the official repositories that does the job — 2.3 MiB,
depending only on glibc and `wl-clipboard`, which was already declared. It is
headless, so the interface stays rofi and the clipboard looks like the launcher
rather than like a second application.

**Two watchers, because one cannot see both.** `wl-paste --watch` with no
`--type` asks for text, so a single watcher records URLs and silently drops
every screenshot — measured: a PNG on the clipboard produced three text rows and
no image at all until a second watcher with `--type image` was added. So
`cliphist@.service` is a template with `text` and `image` instances.

The package ships its own unit and it is wrong on all three counts that matter
here — `graphical-session.target` rather than the sway-specific target, a single
text-only watcher, and `Restart=on-failure` where these components use `always`.
It is not used, and the unit file says why.

Images preview because rofi's icon protocol accepts a **file path** as readily
as an icon name, so each image entry is decoded to a temp file and rofi is
handed the path. At the theme's 26px an image is a smudge; 44px with seven rows
is legible in a window the size of the launcher.

### Trade-off

**The history is plaintext on a disk that is deliberately unencrypted.** A
wrapper drops anything whose offered mime types mention a password, which
catches password managers that set the hint — proved in both directions, since
a filter that silently never fires looks identical to one that works. What it
cannot catch is a password copied from a terminal or a browser's saved-logins
page: that is ordinary text and it is stored. Hence a key to forget one entry
and a menu row to wipe the lot, behind a confirmation defaulting to No.

### Alternatives considered

**copyq** — 8.7 MiB before a Qt and KDE dependency tail, draws a KDE-shaped
window next to a GTK-dark desktop, and wants a system tray this desktop does not
have.

**clipman, clipse, greenclip** — all AUR-only, so ruled out by TASK-43. Named
here rather than dropped silently.

**Auto-paste with `wtype`.** It works — verified pasting into foot. Rejected
because it only worked by knowing foot pastes on Ctrl+Shift+V: a browser wants
Ctrl+V, and Ctrl+V in a shell is readline's quoted-insert. Nothing can ask the
focused window which it is, so the feature would fail differently in every
application and silently in some.

---

## rofi, reversing an earlier decision

**Decision:** Use rofi as the application launcher, and build the desktop's own
menus on top of it rather than writing a launcher.

This reverses the choice of wofi. That entry is reproduced below rather than
deleted, in the usual style - the reasoning was fine and it is the requirements
that moved.

> **Decision:** Use Wofi as the application launcher.
>
> Wofi is a small Wayland-native launcher that works well with Sway. The main
> use is `wofi --show drun`, which provides a simple searchable application
> launcher. It covers the required use case without needing a heavier desktop
> menu system.

### Why

"Covers the required use case" stopped being true once the launcher had to do
more than start applications. This desktop now reaches five things through it -
applications, open windows, the theme switcher, the wallpaper picker, file
search and the shortcut reference - and rofi's script mode is what makes each of
those a few lines of shell rather than a program. wofi has no equivalent.

The alternative was writing something Raycast-shaped, and TASK-80 settled that
by asking what would actually have to be built: desktop-entry parsing,
icon-theme lookup, fuzzy matching, a window switcher, and a plugin protocol -
all of which rofi already has, to gain a look. The look turned out to be
expressible in rofi's own theme format, which is where that effort went instead.

### Trade-off

rofi began as an X11 program, and for years the Wayland answer was the
`rofi-wayland` fork - which would have made the launcher the one piece of this
desktop depending on somebody continuing to rebase. That is no longer the
position: rofi 2.0 is the first mainline release with the Wayland backend
merged in, and `rofi` 2.0.0 from `extra` is what is installed. No fork, and no
AUR support needed to get one.

What remains is that rofi is a larger program than the job strictly needs, and
its theme format is a language of its own to learn before the launcher can be
made to look like anything in particular.

### Alternatives considered

**wofi** - what this replaces. Wayland-native and simpler, with no script mode,
so every custom menu would have had to become a separate program.

**fuzzel** - Wayland-native, actively maintained and smaller. It has a dmenu
mode but nothing equivalent to rofi's script protocol, so the five custom modes
would each have needed their own front end. Worth revisiting only if that stops
being true of one of them, not before.

**A custom launcher** - rejected on TASK-80, above.

---

## Foot

**Decision:** Use Foot as the terminal emulator.

### Why

Foot is lightweight, fast, Wayland-native, and well suited to a minimal Sway environment.

It has a small footprint while still supporting normal terminal features, fonts, colours, padding, and themes.

The visual configuration is intentionally kept in dotfiles so the terminal can look consistent across rebuilt systems.

---

## Copy and paste are Ctrl+C and Ctrl+V, in the terminal too

**Decision:** Swap foot's copy and paste onto `Ctrl+C` and `Ctrl+V`, and move
the interrupt and readline's quoted-insert up to `Ctrl+Shift+C` and
`Ctrl+Shift+V`. (TASK-187.)

### Why

Every other application on this desktop copies with `Ctrl+C`. The terminal was
the single exception, and the exception is not free: it is a modifier reached
for many times a day, in the one window you are in most, purely because a
terminal happens to have claimed that key for something else first.

The something else matters, so this is a swap rather than a theft. `Ctrl+Shift+C`
sends `\x03` — literally the byte `Ctrl+C` has always put on the tty — so the
line discipline raises SIGINT exactly as before. Nothing about the interrupt is
emulated or approximated; it moved. Same for `Ctrl+V`: quoted-insert is rare
enough that most people never reach for it and would not notice it vanishing,
which is precisely the kind of silent loss this repository keeps finding, so it
moved to `Ctrl+Shift+V` rather than being dropped.

The frequency argument is the whole case. Copying out of a terminal happens far
more often than interrupting a command, and the more frequent action should have
the easier key.

### Trade-off

**`Ctrl+C` in the terminal now copies unconditionally and never reaches the
program.** There is no "copy if something is selected, otherwise interrupt"
middle ground, and this was checked in foot's source rather than inferred:
`BIND_ACTION_CLIPBOARD_COPY` in 1.27.0's `input.c` calls
`selection_to_clipboard()` and then `return true` with no condition, so the key
is consumed either way. `pipe-selected` is not a way round it — its failure path
`goto pipe_err` also returns true.

So every program that reads `Ctrl+C` as *cancel* rather than *copy* now needs
`Ctrl+Shift+C`: `fzf`, `btop`, neovim for anyone who leaves insert mode that
way, and any command you want to stop. That is a real cost paid by a
less-frequent action to make a more-frequent one cheaper, which is the trade
being made on purpose.

The reverse direction is safe by construction: foot rejects a duplicate binding
at parse time, and it checks `[text-bindings]` against `[key-bindings]` too —
`foot --check-config` reports "already mapped to" and exits non-zero. A config
that parses is therefore proof the swap is complete in both directions, not just
in one.

### Alternatives considered

- **Leave it as foot ships it.** The status quo, and defensible — but it makes
  the terminal the one place the muscle memory fails, and the task asking for
  this named that directly.
- **`Ctrl+C` copies when there is a selection, interrupts otherwise.** What
  several other terminals do, and the obviously nicer answer. foot cannot; see
  the trade-off above.
- **Bind copy to `Ctrl+C` and leave the interrupt with no key.** Rejected
  outright. Losing SIGINT in a terminal is not a trade, it is a break.
- **Do it in keyd instead**, remapping at the input layer. Rejected: keyd is
  global, so it would rewrite `Ctrl+C` for every application on the machine —
  including the ones that already do the right thing. The problem is foot's
  alone and belongs in foot's config.

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

## Bluetooth is installed everywhere and enabled nowhere

**Decision:** Declare `bluez` and `bluez-utils` in the desktop manifest, leave `bluetooth.service` disabled, and make turning it on a per-machine act through `~/.local/bin/bluetooth`. The bar's bluetooth module is invisible whenever the daemon is not running.

### Why

Two facts pull in opposite directions. The manifests describe what *every* machine this repository builds should have, and they are deliberately not machine-dependent — that is what makes a build reproducible. But `bluetoothd` is a daemon, and not every machine has a bluetooth radio, let alone uses one. Enabling it in `apply-config.sh` would start it on every machine ever built by this setup, including desktops with no controller, for as long as they run.

The way out is to notice that these are two separate decisions wearing one name. Installing a package costs disk. Enabling a service costs a process. Only the second one is worth being careful about, and `bluez` already ships its unit disabled, so the careful default is the one you get by doing nothing.

So the package is declared unconditionally — 5.4 MiB, no processes — and the service is opted into on the machines that want it. `checks/session.sh` fails if anything under `setup/` ever enables it, because "enable the service you just installed" is exactly the tidy-up a later reader would make, and it would work silently and everywhere.

That also settles where the state lives without inventing anywhere to put it: whether bluetooth runs is that machine's systemd state, so it leaves no diff and two machines syncing this repository can disagree — the same property the selected theme has, reached by a different mechanism.

### The bar module is the readout, and it is usually absent

Waybar's `bluetooth` module has a `format-no-controller` state, and here it is the empty string, which hides the module entirely. With `bluetoothd` stopped there is no controller on the system bus, so the module simply is not there.

This inverts the usual relationship between a bar and a service. You do not look at the bar to find out whether bluetooth is on; the bar tells you that it is, on the machine where you had forgotten. A radio that is up with nothing connected takes the warning colour — not because anything is wrong, but because an idle daemon is the state this whole arrangement exists to make visible.

The alternative — a module that reads "bluetooth: off" — was rejected as a permanent readout that says nothing, present even on machines with no bluetooth hardware to have an opinion about.

### Trade-off

When bluetooth is off there is nothing on the bar to click, so the way back to the switch is the launcher (or the `bluetooth` command). That is a real cost and is why the desktop entry exists and is documented in the manual; a hidden control is only acceptable when there is a second way in.

There is also deliberately no "start it just for this session". It would be a state you forget you are in, and the bar cannot distinguish it from any other running daemon — so `bluetooth on` sets both the now and the at-boot answer together.

### Alternatives considered

**`blueman`.** The usual graphical bluetooth manager, and the obvious pick. Rejected for the reason TASK-92 removed `network-manager-applet`: it is a tray application and this desktop has no tray, so `busctl --user list` shows nothing for its icon to attach to. It would arrive with `gtk3`, `libnm`, `python-cairo` and `python-gobject` for 7.0 MiB, to be invisible.

**`bluetuith`.** A TUI manager, which would suit this desktop's shape well. AUR-only, which TASK-43 ruled out.

**A rofi menu that also does pairing.** The menu does connect, disconnect and turn-off; pairing opens `bluetoothctl` in a floating terminal instead. Pairing involves an agent, a passkey to compare and often a `trust` step, and a menu that drove that would be reimplementing `bluetoothctl` badly — failing silently the first time a device asked something unexpected, which is this repository's characteristic bug.

**Making the manifest itself machine-dependent** — a `packages/bluetooth.txt` included conditionally. Rejected: it would make the package set differ between machines to save 5.4 MiB, and the thing actually worth varying is the daemon, which varies anyway.

**Enabling `Experimental = true` in `/etc/bluetooth/main.conf`** to get device battery levels in the bar. Not done: it is a system-wide bluez setting turned on for one cosmetic readout, and the corresponding `format-connected-battery` is deliberately left out of the Waybar config rather than configured and left silently non-functional.

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
GTK3 in through Waybar and `xdg-desktop-portal-gtk`, so it adds essentially
nothing. The Qt-based
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

## No graphical file manager, reversing an earlier decision

**Decision:** Drop Thunar. `yazi` on `$mod+e` is the file manager, and a
directory opened from anywhere else gets a shell in it via
`terminal-here.desktop`.

This reverses the original decision, which is reproduced rather than deleted
because it was never wrong on its own terms — it was simply never tested:

> **Decision:** Use Thunar as the graphical file manager.
>
> ### Why
>
> A graphical file manager is still useful even in a keyboard-centric system.
>
> Thunar is lightweight, mature, and does not require adopting the rest of XFCE.

### Why it changed

**Nothing on the desktop can reach it.** `inode/directory` resolves to
`terminal-here.desktop`, not to Thunar. No sway binding, no Waybar click
command, no helper in `dot_local/bin/` and no desktop entry names it. The only
route left is typing "Thunar" into the launcher, where it contributes three
entries nobody wants — the file manager, Bulk Rename and Thunar Preferences.

**It was opened once, during an investigation, and never in work.** Installed
2026-08-20 01:09 and started once at 12:38 the same day, per `pacman.log` and
the journal. `~/.config/Thunar/accels.scm` is 127 lines and every one of them is
a comment: the default keymap, written on first run and never edited.

**The thing it should have been best at does not work here.** Thumbnail previews
need `tumbler`, which is not installed and never was declared. The journal from
its single run says so directly:

```
thunar[17264]: ThunarThumbnailer: Failed to retrieve supported types:
GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown: The name is not activatable
```

So "see a folder of images at a glance" — the strongest argument for keeping a
GUI file manager on a keyboard-driven desktop — was the one thing this
installation of it could not do. `imv` is declared for looking at images.

**It costs 20.53 MiB across seven packages.** `pacman -Rsp thunar` takes thunar,
libexif, exo, libxfce4ui, xfconf, libgtop and libxfce4util with it. None of
those is declared in a manifest; they arrive only as Thunar's dependencies, so
removing the one line removes all seven on a fresh install.

### What is given up

Named concretely, because "nothing" would be untrue:

- **Dragging files between windows.** yazi cannot originate a Wayland drag, so
  attaching a file by dragging it into qutebrowser is gone; the file chooser
  dialog is the route instead.
- **Bulk Rename.** A graphical multi-file rename with a preview column. yazi's
  `r` renames one entry at a time.
- **A mouse-usable file manager.** Someone not already thinking in keystrokes
  has nothing to click.
- **Right-click custom actions** (`uca.xml`), which were never configured.

Thumbnails are deliberately not on that list. They were never working.

### What is not given up

**File dialogs.** Save As and Open come from the FileChooser portal, which is
implemented by `xdg-desktop-portal-gtk` — a separately declared package that
stays. `/usr/share/xdg-desktop-portal/portals/gtk.portal` declares
`org.freedesktop.impl.portal.FileChooser`, the backend is running as
`xdg-desktop-portal-gtk.service`, and `org.freedesktop.portal.FileChooser` is
present on the session bus. Thunar contributes nothing to it: it ships no portal
backend and no GTK or GIO module, and `ldd /usr/lib/xdg-desktop-portal-gtk`
links nothing from XFCE.

### Trade-off

The observation window was two days, not the fortnight the question was framed
around — this machine was built on 2026-08-20. A fortnight would have measured
taste. Reachability measures something stronger and does not need waiting for:
nothing routes to Thunar, so a fortnight of use could only ever have recorded
someone deliberately typing its name.

`sync.sh` never removes packages, so machines already running this setup keep
Thunar until it is removed by hand. `checks/packages.sh` reports the drift.

---

## Thunar returns, and the four file managers it was measured against

**Decision:** Thunar is the file manager on `$mod+e`, with `tumbler` declared
and its keys remapped to vim ones. yazi keeps a binding on `$mod+Ctrl+e` while
TASK-190 decides which of the two stays.

This is the second reversal of the same decision. *No graphical file manager,
reversing an earlier decision* above dropped Thunar; this brings it back. That
section is not deleted and should not be, because it was right about what it
measured — it is simply that what it measured was reachability, and both of the
things it found are fixed here.

### Why it changed again

**The complaint was about shape, not speed.** yazi is quick and keyboard-native
and none of that is in dispute. It suits a small job done and closed. Bulk work
— moving, renaming and organising many files at once — and looking at a
directory of images are what it is weakest at, and both are what a graphical
file manager exists for.

**Both of TASK-44's findings are addressed rather than argued with.** It was
dropped because nothing on the desktop routed to it and because its thumbnails
had never worked. It now has the *primary* key, and `tumbler` is declared in
the manifest instead of being left as an Optional Dep nobody noticed. The
thumbnails were then confirmed by opening a directory of screenshots and
looking at them.

### The comparison

Each candidate was downloaded and unpacked rather than judged on reputation.
Every autostart entry, systemd unit and D-Bus service was extracted and checked
for desktop gating, which matters here because this session has
`xdg-desktop-autostart.target` active — an ungated entry really would start.

| | New pkgs | Added | Rebindable keys | Starts at login |
| --- | --- | --- | --- | --- |
| pcmanfm | 7 | 9.3 MiB | **no** | `menu-cached` |
| pcmanfm-qt | 7 | 9.7 MiB | **no** | — |
| **thunar** | **7** | **20.5 MiB** | **yes** | **—** |
| nemo | 10 | 14.9 MiB | yes | `xapp-sn-watcher` |
| nautilus | 27 | 64.4 MiB | no | — |
| dolphin | 72 | 15.7 MiB+ | yes | — |

**Rebindable keys was the cull.** `Thunar` exports `gtk_accel_map_load`/`save`,
names `Thunar/accels.scm` and carries a Shortcuts Editor. `nemo` has the same
accel-map calls and a `~/.gnome2/accels/nemo`. `pcmanfm` has **no accel-map
symbols at all** — its keys are compiled in — and neither does `pcmanfm-qt`.
So the two cheapest options cannot be given vim keys at any price, and the
requirement is not negotiable.

**Of the two that survived, Thunar starts nothing.** `nemo` hard-depends on
`xapp`, which ships `xapp-sn-watcher.desktop` with **no `OnlyShowIn`** — it
would start at every login whether or not nemo is ever opened, running a
StatusNotifier tray watcher for a tray this desktop does not have. Thunar ships
no autostart entry, and neither `thunar.service` nor `xfconfd.service` has a
`WantedBy=`; both are D-Bus activated.

`nautilus` was ruled out before the package count: it depends on `localsearch`
and `tinysparql`, a background file indexer with three systemd user units.
`dolphin` at 72 packages was never a candidate.

### Trade-off

**Thunar is not the cheapest; it is the only one that answers the
requirement.** 20.5 MiB against pcmanfm's 9.3.

**"Nothing in the background" is true only until it is first opened.** Measured
after closing the window: `tumblerd` at 20.3 MiB and `xfconfd` at 8.4 MiB stay
for the rest of the session — 28.7 MiB that yazi does not cost. Nothing at
login, something after first use. That is the figure TASK-190 should weigh.

**The vim keys are partial, and the missing part is not fixable.** A GtkAccelMap
binds menu *actions*, and moving the selection is not one — the complete action
list was extracted from the binary and there is no move-cursor in it. Cursor
movement belongs to GtkTreeView and GtkIconView, whose keys come from GTK
binding sets reachable only through `-gtk-key-bindings` in `gtk.css`, which is
global to every GTK application and not scopable to one. So `j` and `k` are the
arrow keys, and `gg`/`G` are impossible for a second reason as well: an
accelerator is one chord, never a sequence.

**It will not wear the theme.** `gtk-3.0/settings.ini.tmpl` sets stock
Adwaita/Adwaita-dark and its own comment says the palette does not reach GTK.
Thunar follows the selected theme's light/dark mode and nothing more. Pushing
the palette into GTK would mean templating `gtk.css` from `themes.toml`, which
affects every GTK application and was left out of scope.

### One thing this cost that was not predicted

`accels.scm` is **tracked read-only**, which is not how any other dotfile here
works. Thunar rewrites the file with its own 125-entry dump on every quit, in
hash-table order, so tracking it writable would mean a chezmoi diff after every
session — drift that is pure noise, and noise is how a repository trains you to
stop reading drift reports. `readonly_` makes it 0444, Thunar's save fails
harmlessly, and the repository stays the source of truth. The cost is that
Thunar's own Configure Shortcuts dialog cannot save.

### Alternatives considered

**Keeping yazi alone and adding `g`-prefixed bookmarks.** Cheaper and was
offered first. It answers "shortcuts to places" and does not answer bulk work
or thumbnails, which is what the complaint was actually about.

**Running both permanently.** Two things doing one job is what this repository
argues against. TASK-190 exists so that this is a trial with an end rather than
a decision to have both.

> **This is the alternative that won.** TASK-196 ended the trial by taking it,
> on the grounds that the premise above is wrong here: they are not two things
> doing one job. See *Both file managers stay, behind `explorer --use`* below.

---

## Both file managers stay, behind `explorer --use`

**Decision:** Neither yazi nor Thunar is removed. `~/.local/bin/explorer` picks
which one `$mod+e` opens, from a one-line state file; `$mod+Ctrl+e` opens the
other. The default is yazi.

This answers TASK-190, which was written to delete one of them, and it answers
it in the negative. TASK-189's trial ran as intended and the finding was about
the question rather than the answer.

### Why

TASK-190's premise is this repository's standing argument that two things doing
one job is a smell — the bargain struck for the two browsers (TASK-178) and the
two Escape keys (TASK-110), both of which ended with one thing. The premise is
sound where the two are **interchangeable**, and that is what makes those two
cases work: you want a browser, and the only question is which one.

It does not hold here, and use is what showed it. yazi is what the hand reaches
for — keyboard-native, in a terminal, quick for a small job done and closed,
and shaped like the rest of a desktop that is navigated without a mouse. Thunar
was reached for rarely and specifically, for four things yazi cannot do at all:

- a directory of images as thumbnails
- a bulk rename with a preview column
- dragging a file out into another window, which yazi cannot originate
- a sidebar of mounted drives to click through

Deleting Thunar would not remove a duplicate. It would remove those four
capabilities and leave nothing in their place. That is a different finding from
"Thunar lost", and deleting it on a rule written for a different situation
would have been the rule outranking the evidence it exists to serve.

**So the honest summary is that TASK-190 asked the wrong question.** It asked
which one wins a comparison; the fortnight answered that they were not being
compared, they were being used for different work.

### Trade-off

**20.5 MiB across seven packages, plus `tumbler`, knowingly not reclaimed** —
the exact cost *Thunar returns* measured and TASK-190 was written to recover.
It is paid for a program used a few times a month.

**28.7 MiB resident for the rest of any session Thunar is opened in**
(`tumblerd` and `xfconfd`, both D-Bus activated on first use, neither exiting).
Demoting Thunar to `$mod+Ctrl+e` does not reduce that figure, but it does mean
most sessions never pay it — which is a real improvement on it being the thing
`$mod+e` opens.

**Two keys for one concept**, where the browser needed one. That is the visible
oddity and it is deliberate: making Thunar cost an `explorer --use` and an
`explorer --use` back would price it out of exactly the jobs it is kept for, and
a thing reached for a few times a month is precisely what a second modifier is
for.

**`$mod+e` gains a shell process between the keypress and the window**, the same
few milliseconds `browser` costs. yazi in a `foot` window appears in about
20 ms, so this is the one place in the setup where that overhead is a
measurable fraction — and still far below anything a person perceives.

### Alternatives considered

**Delete Thunar, as TASK-190 specified.** Rejected on the reasoning above. The
ticket is answered rather than quietly abandoned, because an open ticket
contradicting the code is how this repository accumulates configuration that
looks decided and is not.

**Delete yazi and keep Thunar.** Never seriously in play — yazi is where the
work happens, costs nothing extra (it is a terminal program the machine already
has), and starts in a fifth of the time.

**One key, like `browser`.** Rejected: see the trade-off above.

**Pin `$mod+Ctrl+e` to Thunar rather than to "the other one".** Simpler to
describe, and it means both keys open Thunar whenever Thunar is selected — two
bindings doing the same thing, which is worse than the asymmetry it avoids.
`--other` walks the supported list rather than hardcoding "not yazi", so a third
explorer would turn that key into a cycle. That is the moment to revisit it.

**Store the choice in `chezmoi.toml`** with the theme, wallpaper style and glow.
Rejected for the same measured reason as the browser and the sound pack:
`desktop_config.py` shells out to `chezmoi data` at upwards of 100 ms, and this
is on the path between a keypress and a window. See *Sound packs*.

**Switch the `inode/directory` handler too**, so opening a folder from another
application follows the setting. Rejected: that handler is
`terminal-here.desktop` and gives you a terminal in the directory, which is
deliberate and unrelated to which explorer a key opens.

---

## The device sidebar, answered by a popup rather than a second file manager

**Decision:** External and internal drives are mounted from inside yazi, with
`M`, using the upstream `mount.yazi` plugin over `udisks2`. The plugin's code is
**vendored into this repository** rather than fetched by `ya pkg` when the
machine is built.

### Why

Dropping Thunar above left one thing genuinely unanswered, and it is not on that
section's "what is given up" list because nobody had noticed it yet: **a GUI
file manager's left-hand sidebar is where external drives appear.** Take the GUI
file manager away and there is no device list anywhere on the desktop. An
unmounted disk is then not reachable from the file manager at all — you mount it
from a shell and type the path.

yazi cannot grow that sidebar. Its layout is three fixed columns — parent,
current, preview — with no fourth pane concept, so the affordance has nowhere to
live. This is a real limit, not a missing setting.

A popup is the better answer anyway, and not only because it is the possible
one. A sidebar is a permanent strip paid for on every glance at every directory,
in service of something wanted a few times a week. And it cannot do the part
that actually matters here: a drive that is not mounted yet has no path for a
sidebar entry to point at. `M` lists the disks whether they are mounted or not,
mounts one, and `l` steps into where it landed.

**udisks rather than sudo.** `udisksd` runs as root on the system bus and
authorises each request through polkit, and the stock policy already grants
`filesystem-mount` to whoever is sitting at the machine — so a USB stick mounts
with no password, and a partition on a fixed internal disk (`filesystem-mount-system`,
`auth_admin_keep`) asks once. Both verified against
`/usr/share/polkit-1/actions/org.freedesktop.UDisks2.policy` rather than
assumed. The alternative was a sudoers rule for `mount`, which is precisely the
thing udisks exists so that nobody writes. Same shape of reasoning as *Power
profiles switch through a daemon, for privilege rather than scheduling*.

### Why the plugin is vendored

`ya pkg add yazi-rs/plugins:mount` clones from GitHub at the moment it runs. A
fresh install of this system runs from a live ISO through `arch-chroot` and
applies dotfiles from `/opt/arch-setup` — a copy of `setup/` and nothing else.
There is no clone step there and no guarantee of a network.

A plugin fetched at install time is a plugin that is sometimes absent, and an
absent plugin fails in this repository's signature way: yazi prints no error, no
notification and nothing in the task list. `M` simply does nothing, while the
keymap still reads as configured. That is the same failure shape as the media
keys calling an uninstalled binary and the theme `include` pointing at a file
that was never there.

So the code is committed and chezmoi deploys it like any other dotfile. `ya
pkg`'s own `package.toml` manifest is tracked alongside it, so the pinned
revision is machine-readable as well as written down, and `checks/session.sh`
asserts that every `plugin` the keymap names has a `main.lua` behind it.

### Trade-off

**485 lines of somebody else's Lua now live in this repository**, and updating
it is a manual copy rather than a command. That is the cost of the guarantee,
and it is paid in the direction this repository already leans: the repo is the
source of truth, and a change made on the machine is drift.

It also inverts the usual update flow. `chezmoi apply` will *revert* an upgrade
performed in place with `ya pkg upgrade`, so upgrades have to happen in the
repository and reach the machine through `sync.sh`. The procedure is written
down in `setup/dotfiles/dot_config/yazi/plugins/README.md`, next to the code,
because that is where someone about to run `ya pkg upgrade` will be standing.

Vendoring also means nobody upstream can fix a bug for you silently — which
cuts both ways, and is the reason that README says to read the upstream diff
before committing it. `mount.yazi` shells out to `udisksctl` and has a `sudo`
fallback path.

### Alternatives considered

**A graphical file manager, purely for the sidebar.** This is the decision above,
already made and reversed on evidence. Reinstalling Thunar to get a device list
would bring back all four things it was dropped for and cost 20.53 MiB across
seven packages, to solve a problem 28 KiB of Lua solves.

**`udiskie`**, a tray-and-notification auto-mounter. It is the conventional
answer and it works, but it is a resident daemon that mounts things on insertion
whether or not anyone asked, and the desktop it reports into is a tray this
setup does not have. `M` is explicit and costs nothing when not pressed.

**Auto-mounting via a udev rule.** Mounts a drive the moment it is plugged in,
with no session, no policy and no user in the loop. Faster and considerably
harder to reason about when it goes wrong.

**`ntfs-3g`, `exfatprogs`, `dosfstools`.** Considered and *not* declared. `vfat`,
`exfat` and `ntfs3` are all kernel modules shipped in `linux`; those packages
supply `mkfs` and `fsck`, not the ability to mount. Declaring them would have
been three packages bought on an assumption — see *the fix that did not work,
kept anyway* in CLAUDE.md for why that matters.

---

## GVFS

**Decision:** Keep GVFS, which arrived with Thunar and outlived it.

### Why

GIO reaches removable and network volumes through GVFS, and GIO is what the GTK
file chooser uses for anything that is not already a local path. Without it the
portal's dialog can only see paths that are already mounted and visible in the
filesystem.

`pacman -Qi gvfs` lists it as `Optional For: glib2, thunar` and
`Required By: None` — so it was never a Thunar dependency, it was a declared
package that happened to be listed next to one. Removing Thunar does not touch
it.

### Trade-off

5.26 MiB and a `udisks2` dependency for a capability that a machine with no
removable media and no network shares never exercises. It stays because the
failure mode without it is the same silent kind this repository keeps hitting: a
file dialog that simply shows nothing where a USB stick should be, with nothing
to indicate why.

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

## dust rather than a `du` pipeline

**Decision:** Install `dust` for disk-usage archaeology. Do not add a
disk-usage panel to the session.

### Why

`du` answers the question you asked; the trouble is that the question you can
ask it is the wrong one. The reflex is `du -sh ~/*`, which stops at the top
level, and the useful answer is almost never at the top level. Making it useful
means `du -h --max-depth=N ~ | sort -h | tail`, where `N` has to be guessed
before you know where the space is.

Measured on this machine. `du -sh ~/*` reports `.local` at 1.4G and stops.
`dust` ranks the biggest directories at any depth and names the actual culprit
unprompted: three cached Claude Code versions in `~/.local/share/claude/versions`,
969 MiB, 46% of home. It draws a proportion bar beside each so the shape of the
answer is visible without reading the numbers.

It is also faster than the pipeline it replaces, which was the opposite of the
first measurement taken — a cold-cache run of `dust` was compared against a
warm-cache `du` and came out three times slower. Warm on both sides, three runs
each:

| over `/usr` | run 1 | run 2 | run 3 |
| --- | --- | --- | --- |
| `dust -n 20 /usr` | 134 ms | 126 ms | 131 ms |
| `du -h --max-depth=3 /usr \| sort -h \| tail -20` | 219 ms | 219 ms | 217 ms |

Over a home directory both finish in under 30 ms and the difference does not
matter.

**Nothing installed already does this.** `btop` reports filesystem free space,
not per-directory totals. `yazi` shows a size per entry and has no
directory-tree size command — checked by extracting its default bindings from
the binary rather than from memory. `tree` does not aggregate.

It costs 2.97 MiB from `extra`, depending on nothing but `glibc` and `libgcc`.

### Trade-off

This is not a daily tool. It earns its place on the same terms as `eza`, `bat`
and `fd` — a better answer to a question that already gets asked — but it gets
asked monthly rather than hourly, and 3 MiB for a monthly question is the honest
cost.

### Alternatives considered

**`ncdu`** (529 KiB) and **`gdu`** (21 MiB) are interactive browsers: you enter
them, navigate, and can delete in place. That is a second thing shaped like
`yazi`, and `yazi` is already bound to a key. A one-shot ranked report composes
with a shell and a scrollback; a TUI does not.

**`dua-cli`** (3.7 MiB) does both — a one-shot mode and an interactive one — and
is a reasonable alternative that was rejected for being larger while its
one-shot output is a plain list without the proportion bars that make `dust`'s
readable at a glance.

**`diskus`** (814 KiB) is a faster `du -sh` for a single directory and answers
none of this.

**A floating disk-usage window at login** was the original idea and is rejected.
It puts a filesystem walk on the critical path of every login to answer a
question nobody asked at that moment, and `fastfetch` already reports
filesystem usage — its config carries a `disk` module — for anyone who runs it.
What is missing from that report is not the free-space number, it is which
directory to blame, and that is worth one command when the question comes up
rather than a scan every time the machine starts.

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

## The VM rendered in software, and no longer does

**This entry is now history, and is kept because the reasoning still applies to
any machine that has not had the fix.** 3D acceleration was enabled on the
hypervisor, and the running machine agrees: the kernel reports
`[drm] features: +virgl +edid` with two capability sets, and this boot produced
**zero** mentions of llvmpipe or swrast across the whole journal. Everything
below describes the state before that, and remains the right diagnosis if the
symptoms return.

One consequence worth carrying forward: it is still not a fair machine to judge
a compositor's *feel* on. virgl is virtualised GL - enough that sway is no
longer drawn by the CPU, not enough to benchmark anything whose selling point is
motion. TASK-31 leans on this.

### The original entry

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

### It cost a session once, and nothing was done about it

On 2026-08-20 at 23:30 sway segfaulted and the desktop went with it. The machine did not reboot - greetd restarted and logging back in restored everything - but every open window was lost. The coredump is unambiguous: a segfault in libc, seven frames inside `libgallium`, and `wlr_client_buffer_create` beneath them. sway was allocating a buffer for a client window, that call went into Mesa, and it crashed there. On this machine gallium is llvmpipe, so this is a consequence of the arrangement above rather than a separate fault.

Memory pressure was ruled out - earlyoom reported 58% available a minute earlier, nothing was killed - and so was configuration, the crash being inside a library rather than in config parsing, after ninety minutes of running.

**Nothing was changed in the guest, deliberately, and that is the conclusion rather than an omission.** sway has no crash recovery and cannot be given any from outside; a supervisor that restarted it would produce an empty desktop rather than the one that was lost. The fix is not in the guest at all: enabling 3D acceleration on the hypervisor - virtio video with 3D, SPICE display with OpenGL - takes llvmpipe out of the path entirely. That was already the recommendation here for performance; this raises it from "the desktop is CPU-rendered" to "the compositor can crash".

Not reproduced since: one coredump total, across roughly twenty hours of session time over two subsequent boots, both ending in a clean shutdown. A fault seen once is not disproved by that, which is why this is written down instead of closed silently. TASK-48.

---

## Sway stays, and niri is the thing to try when there is hardware to try it on

**Decision:** Remain on sway. Do not adopt SwayFX. Do not install niri yet —
revisit when this setup runs on real hardware rather than in a VM.

### Why

SwayFX is not available: `pacman -Si swayfx` reports no such package, it is
AUR-only, and TASK-43 ruled out the AUR. It is also not wanted — vanilla sway
looks right after the theming work, so the effects it buys are not effects
anyone is asking for. Either ground closes it alone.

niri is a different proposition, and one earlier note here was wrong about it.
It is in `extra` at 24.87 MiB, packaged by an Arch maintainer, with
`xwayland-satellite` beside it and waybar's `niri/*` modules already present in
the installed waybar. So unlike SwayFX it costs no packaging machinery. It also
has shadows, rounded corners, blur and animations, all from official packages —
**the effects were never AUR-only, they were only ever absent from sway.**

The reason to wait is that what niri is actually wanted for is a *motion model*
— scrollable tiling and an overview — and that cannot be judged from a config
diff, nor on this machine. See the entry above: virgl-backed 3D is enough that
sway is no longer CPU-drawn and not enough to be a fair bench for a compositor
whose differentiator is how it moves.

### Trade-off

Staying keeps what sway cannot do: no overview, no effects, and windows that
resize each other when one opens.

### What it would cost, counted rather than estimated

609 lines of compositor config, 69 keybindings and 19 window rules, none of
which port — niri uses KDL and upstream offers no translator. Eight helper
scripts speak sway IPC. Six pieces of repository tooling parse sway's config
syntax or its IPC, the largest being the shortcuts panel at 678 lines, which
reads the sway config directly and subscribes to sway window events.

Three features have no niri equivalent at all: autotiling, whose concept
disappears under scrollable tiling; binding modes; and the scratchpad. A fourth
was counted here until TASK-113 removed it: the workspace greeter, which
assumed numbered static workspaces where niri's are dynamic.

Everything below or beside the compositor survives untouched — keyd, greetd,
uwsm, chezmoi, the palette and its non-sway consumers, the installer.

### Trying it is not a `pacman -S`

Worth writing down because it is the obvious move and it breaks something:
`checks/session.sh` fails any greeter session entry whose `Exec` bypasses uwsm,
and niri ships one. Installing it alongside sway needs a `Hidden=true` mask over
the packaged entry, a `niri-uwsm.desktop` naming the binary rather than the
desktop ID, an `apply-config.sh` entry and a `wayland-session@niri.target.wants/`
set.

### Alternatives considered

**Hyprland** — in the official repositories with effects built in, but a full
configuration rewrite for effects that are not the goal.

**COSMIC** — the only option offering workspaces that span displays, kept in
reserve for that question, which is TASK-34's rather than this one.

### When to reopen

When this runs on real hardware. A second display is deliberately *not* the
trigger: niri's workspaces are per-monitor too, so it does not answer the
spanning question either.

---

## Shells survive a sway crash, deliberately, and nothing else does

**Decision:** Keep interactive shells alive across a sway crash or an in-session
restart with `abduco`. Do not build tooling to capture and replay window layout,
and add nothing for application content beyond what qutebrowser and neovim
already do by default.

### Why

TASK-50 split "recover the session" into three problems with different answers.

Window position is scriptable from `swaymsg -t get_tree` and not worth building:
the tools that would help are AUR-only, declined on TASK-43, and a hand-rolled
relaunch-and-place script is exactly the fragile machinery this repository
avoids — for a fault seen once in roughly twenty hours of session time.

What was *inside* a window is mostly handled already, checked rather than
assumed: qutebrowser now carries a small config that turns `auto_save.session`
on — this paragraph previously said it ran stock "where `auto_save.session`
defaults to true", and that was simply wrong, the default is false, so the
session recovery this claimed to rely on was never enabled (corrected in
TASK-174); neovim already sets `undofile` and has swapfile recovery on. Neither restores layout automatically, and scripting
that on would be new machinery for the rare case rather than the common one.

A terminal's live state is the one genuine gap, and it is cheap to close.
`abduco` is 36.75 KiB and does only detach and reattach — no panes, tabs or
prefix-key layer to reconcile against the Ctrl-heavy scheme TASK-40 built.
`tmux` duplicates sway's own tiling; `zellij` adds that plus default bindings
that collide with readline and fzf.

**The design constraint came from the crash log, not from theory.**
`systemd --user` survives a sway crash intact — the same PID stops and re-reaches
the session target. A process launched the ordinary way does not: the log of the
2026-08-20 crash shows systemd SIGKILLing a process sitting in
`wayland-wm@sway.service`'s own cgroup ten seconds later, as routine unit-stop
cleanup. So the daemon holding each shell's pty must be its own user unit with
no `PartOf` or `BindsTo` on `wayland-session@sway.target` — the mirror image of
how mako, waybar and swayidle are deliberately bound to it.

### Trade-off

This covers a sway crash and a deliberate in-session restart, not a reboot — no
userspace process survives that. Window layout still has to be rebuilt by hand
either way.

Implementation is TASK-98.

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

What can be done is keep applications off XWayland, which `environment.d/10-appearance.conf` already does with `QT_QPA_PLATFORM`, `SDL_VIDEODRIVER` and `MOZ_ENABLE_WAYLAND`. Nothing this setup installs needs XWayland today - qutebrowser and pavucontrol both run natively, and XWayland only started at all when one was deliberately forced onto it - so the limitation currently costs nothing.

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

### What sits below keyd, and why this repository cannot reproduce it

keyd remaps at the evdev layer, which is below xkb and below the console keymap - but it is not the bottom. Laptop firmware sits under it, and firmware is the one layer `install.sh` cannot touch: nothing in this repository is copied into an embedded controller. So a machine can be built perfectly from this repo and still behave wrongly, which is this repository's signature failure mode arriving from a direction no check can reach.

Two firmware settings are worth knowing about, because both change what keyd receives:

- **Which row the top keys send.** Laptops decide in firmware whether the top row is media keys or `F1`-`F12`, usually with an `Fn+Esc` lock and a matching BIOS option. If it is set the wrong way, every media binding in `52-media-keys.conf` does nothing at all - not because the binding is wrong, but because the key is sending `F3` instead of `XF86AudioRaiseVolume`, exactly as instructed.
- **Whether Fn and Control are swapped.** Many laptops offer this, and with it enabled the key a label says is Control is not the key the hardware sends. That makes `Fn+Esc` hard to find, which matters precisely when the lock above needs toggling.

**The rule this produces: measure what the hardware sends before editing anything here.** `sudo keyd monitor` shows what keyd receives and emits, live. Redirected to a file it block-buffers, so a capture killed by a timeout reads as "no events at all" - use `stdbuf -oL keyd monitor`. Every wrong guess in this area has taken longer than that command would have.

On Lenovo hardware these settings are readable and writable from Linux via the `think_lmi` driver, without rebooting into BIOS setup, provided no BIOS admin password is set - `/sys/class/firmware-attributes/thinklmi/`. Other vendors expose the same kind of thing through their own `firmware-attributes` classes or not at all. This is a diagnostic aid, not part of the build.

### Machine-local remapping, in /etc/keyd/local

`default.conf` matches `[ids] *` and is installed on every machine, so it must describe hands rather than hardware. Keyboards vary in layout, in which keys exist, and occasionally in which keys still work, and a remap answering one machine's hardware has no business being installed on someone else's.

`default.conf` therefore ends with `include local`, and `apply-config.sh` creates `/etc/keyd/local` as an empty commented stub if it is absent, never overwriting it. That is the same bargain as `~/.config/zsh/local.zsh` for the shell and chezmoi's config file for the selected theme: the repository owns the general case and provides a place for the specific one, rather than being edited to describe one computer.

It is the last line of the file, so a local binding wins. The stub is created *before* `keyd check` runs, because a missing include would make the config unparseable - and an unparseable keyd config means no usable keyboard on the machine you would need in order to fix it. The file has no `.conf` extension deliberately: keyd loads every `.conf` in `/etc/keyd/` as a config in its own right, which would make it a second competing config needing its own `[ids]` block, rather than an extension of this one.

### Trade-off

A daemon running as root with an exclusive grab on every keyboard. A config it cannot parse means no usable keyboard on the machine you would need in order to fix it, so `apply-config.sh` runs `keyd check` and refuses to enable the unit rather than starting a daemon that would lock the machine out. keyd documents a panic sequence - `backspace+escape+enter` held together - which terminates it and hands the keyboard back.

Bindings are written with `layer(alt)` rather than `leftcontrol = leftalt`. A bare key assignment emits the keycode without the modifier semantics, and keyd warns about exactly this; the direct form would have looked correct and composed wrongly.

### A scroll layer on Caps Lock

Holding Caps Lock makes `j`/`k`/`h`/`l` scroll and `d`/`u` page — everywhere:
the terminal, a GTK dialog, a PDF viewer, and inside a text input field.

**Why not a letter key.** This was first sketched as hold-`f`. keyd's
letter-safe form is `lettermod(scroll, f, 150, 200)`, whose idle gate resolves
any `f` struck soon after the previous key as a plain `f` — which covers mid-word
`f` completely: "off", "affix", "of" are all safe. It does *not* cover an `f`
that starts a word after a pause. That press falls through to `overloadt2`,
which resolves as a hold on any intervening tap, so "For" typed with the normal
rolled overlap can lose its `f` and emit "or". A silently dropped character in
prose, indistinguishable from failing hardware, is this repository's named
failure mode appearing in the user's own typing. Plain `overloadt` trades that
for a visible stall on every sentence-initial `f` instead.

nvim compounds it rather than helping: `f` is find-character, used in exactly
that after-a-pause position, and nvim already has `C-d`, `C-u` and `j`/`k` — so
the layer buys nothing there and costs a core motion. This file is also read by
the console and the greeter, so an ambiguous letter would be ambiguous on the
rescue VT, which the decision above already argues is the context that matters
most.

**Why two mechanisms.** Page Down inside a text field moves the caret, not the
view — which is the case the feature exists for, so Page Down alone does not
answer the request. A mouse wheel event does: it is delivered to the surface
under the pointer and ignores keyboard focus entirely. keyd already runs a
virtual pointer and `/proc/bus/input/devices` reports `B: REL=147` for it, so
REL_WHEEL and REL_HWHEEL are already advertised and no new device is needed.

The cost is the other side of the same coin: a wheel event goes where the
*pointer* is, and sway's default `mouse_warping output` leaves the pointer
behind on keyboard-driven focus changes within one output. So `d` and `u` emit
Page Down and Page Up, which follow keyboard focus. Neither mechanism reaches
everything; the layer carries both deliberately.

**Why `macro2`.** A wheel event has no press and no release, and auto-repeat is
generated by the compositor from a held *key*. A bare `j = scrolldown` emits one
click however long `j` is held. `macro2(250, 40, ...)` makes keyd repeat it, at
sway's own `repeat_delay` and `repeat_rate` from `10-input.conf`.

### Trade-off

**Caps Lock no longer locks caps.** Shift replaces it. Tapping it does nothing,
rather than `overload(scroll, capslock)` keeping the old function — that form
would silently latch caps whenever the layer was entered and left without using
it, which is a worse failure than losing a key nobody presses deliberately.
Keys unbound inside the layer fall through, so Caps Lock plus another letter
still types that letter.

### Alternatives considered

**`f` and other letter keys** — above. **Space (SpaceFn)** has the same tap-hold
problem on the most-struck key of all. **Right Alt** is AltGr, which a `gb`
layout actually uses. **A sway `bindsym`** was never an option: it would not
reach the console, the greeter, or a text field, which is most of the point.

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

**Decision:** Every machine gets a layer above the repository that the repository never sees and never reverts. The tracked config stays fully managed and reaches out to a local file it does not own - `.zshrc` sources `~/.config/zsh/local.zsh`, and the same shape is applied per tool wherever the tool supports it.

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

### An escape hatch nobody is told about is not an escape hatch

TASK-186 was raised as "not possible to override sway display/output settings",
and it was possible the whole time — `config.d/99-local.conf` existed, was
created, and its seeded comment named *"an output line for a monitor you own"*
as the example. The mechanism was not the problem. Being findable was.

What the person actually met was `sync.sh`, reporting the drifted file, offering
`chezmoi re-add`, and then saying *"For changes that should stay on this machine
only, use `~/.config/zsh/local.zsh`"* — one line, naming one tool, written
before this section's own generalisation gave six other tools a local file. So
someone editing their monitor layout was pointed at a shell file that could not
help them, next to a `re-add` command that would have committed one desk's
displays to a repository meant to build anybody's.

That advice is now per-file, and the mapping is **derived from the source rather
than typed out**: every local file is a chezmoi `create_` file, so `sync.sh`
finds them by looking, and a seventh tool getting one needs no edit. `zsh` is
named explicitly because it predates the pattern and is a `.chezmoiignore` entry
instead.

The general lesson is worth more than the fix. A hatch that only its author can
find has the same failure mode as a hatch that does not exist, and it is worse
in one respect: it looks solved. **The place to document an escape hatch is
wherever someone hits the wall it exists for** — which here meant `sync.sh`'s
own output and a warning at the bottom of `20-output.conf`, not only the manual
chapter that already described it correctly and that nobody had reason to open.

### The same shape, everywhere the tool allows it

The shell had a mechanism and nothing else did, which made the repository a cage for every other tool: a machine that wanted to differ either hardcoded itself into shared config or watched `sync.sh` revert it. That is fatal to publishing the build, because a stranger's laptop is not this one. It already bit here - a terminal font raised to 15 on a small laptop panel, reverted to the repository's 10 on the next sync.

Two facts make the general version cheap, and both were measured rather than read:

- **Nothing under `setup/dotfiles/` uses chezmoi's `exact_` prefix**, so chezmoi leaves unknown files in managed directories alone. Drop-ins in `sway/config.d/`, `environment.d/` and systemd `*.d/` already survive a sync. That was working and undocumented, which is its own hazard: an accident nobody wrote down is an accident somebody later "tidies up".
- **chezmoi's `create_` attribute writes a file once and never overwrites it**, even under `apply --force`. So the repository can ship a seeded, commented local file, hand it over on first install, and never touch it again.

Which layer a change belongs to is decided by what the tool can do, not by preference:

| Layer | Mechanism | For |
| --- | --- | --- |
| Base | the repository, naming no machine | everything shared |
| Overrides | a `create_` local file the tracked config includes **last** | additions and overrides - a binding, a tweaked setting |
| Values | machine-local data in chezmoi's own config, read by templates | a value with no include point, or one that appears in several files at once |

The include has to come last, because an override that loses to the file it is overriding is worse than none - it looks configured and does nothing, which is this repository's signature bug.

Tool support, taken from each tool's own manual rather than assumed: `foot` has `include` (absolute path only, so its include line must be templated), `mako` has `include=` and accepts `~/`, sway already globs `config.d/*.conf` so a `99-` file needs no new line at all, git has `[include]`, waybar takes an `include` array and `@import` in CSS, rofi has `@import`, mpv has `include=`, Neovim can `pcall(dofile, ...)`, and keyd has `include` - which is where this pattern was first used, under TASK-133, for a laptop whose Control key had physically died.

**Starship, yazi and GTK's `settings.ini` support no include at all.** Those can only be reached by the values layer, which is the other reason it exists.

**A missing local file must be harmless, and that rules mako out.** The escape hatch only works if deleting the file is survivable, because the file is untracked and looks like clutter. Every mechanism used here degrades safely, and each was measured rather than assumed: `.zshrc` guards with `[[ -r ]]`, sway's `config.d/*.conf` glob matches nothing, git ignores an include it cannot open (exit 0), and foot logs an error and starts anyway - only its `--check-config` returns non-zero.

mako is the exception and is deliberately excluded. A missing include makes it print `Failed to parse config` and exit *before it reaches the bus*, and `mako.service` is `Restart=always`, so the result is a crash-looping daemon and silently no notifications. It offers no conditional include to guard with. The trade was not close either way: mako only accepts `include` among the global options before the first criteria, so a local file could override globals and would still lose to the criteria blocks below - a small win against a dead daemon.

That is the general rule this produces: **an escape hatch whose absence breaks the program is not an escape hatch.** Check the missing-file case before adding a tool to this layer.

A second test turned out to matter just as much: **an override that cannot win is not an override.** Both were measured for every tool considered, and the results decided which got a local file:

| Tool | Missing file | Can a local setting win? | |
| --- | --- | --- | --- |
| zsh | guarded, safe | yes, sourced last | yes |
| sway | glob matches nothing | yes, `99-` sorts last | yes |
| foot | logs an error, starts | yes, `[main]` re-opened at the end | yes |
| git | ignored, exit 0 | yes, last value read wins | yes |
| Neovim | `pcall` returns cleanly | yes, loaded last | yes |
| rofi | exit 0 | yes, last `@import` wins | yes |
| mpv | exit 0 | yes, last value wins | yes |
| mako | **fatal**, exits before the bus | globals only, loses to criteria | no |
| waybar (style) | **fatal**, exit 1 | — | no |
| waybar (config) | safe, keeps running | **no** - the including file wins | no |

waybar fails both tests, for different reasons in each half. A missing CSS `@import` kills it, and it is `Restart=always`, so that is mako's failure again. And its JSON `include` documents the opposite precedence to everything else here - *"in case of duplicate options, the first defined value takes precedence, i.e. including file -> first included file"* - so a local file could add keys but never change one. A file that silently ignores half of what you put in it is worse than no file, because the failure looks like your own mistake.

There is a way to give waybar a real override - make the tracked config a thin wrapper that includes the local file first and the repository's real config second - but `config.jsonc` is named by seven other files here, so it is its own piece of work rather than a line.

### Why this is not the same as machine profiles

Profiles - templating a laptop's battery module in and a VM's out - are a separate mechanism for a separate question, and both are wanted. A profile answers *"this machine is a laptop"*. The local layer answers *"I like this font bigger"*. Collapsing them would mean declaring a profile for every personal preference, which puts the repository back in the way of trying something quickly - exactly what the shell escape hatch was introduced to stop.

### Trade-off

Configuration for this machine is deliberately outside version control, so it is not backed up and not reproducible. That is the point of the category, but it means the local file is the one place in this setup where "it works on my machine" is allowed to be true.

### Alternatives considered

**Leave `.zshrc` unmanaged and check only that an import line is present.** Rejected. It gives up the ability to push a shell change to every machine, which is what the repository is for, and enforcing a line inside an unmanaged file needs a `modify_` script - more machinery for less. Inverting it keeps the shared file managed and puts the escape hatch inside it.

**Require every local change to be folded back in.** Rejected as the only option, though `sync.sh` now prints the `chezmoi re-add` command for each differing file so it is one command when it is the right answer. Insisting on it for everything makes the repository the enemy of trying something quickly.

---

## Switchable themes, and what a theme is allowed to cover

**Decision:** `.chezmoidata/themes.toml` holds a table per theme. Which theme is selected is machine-local, in chezmoi's own config file under `[data]`, and `~/.local/bin/theme` writes it. A theme covers the desktop's own chrome and its wallpaper. It does not re-colour GTK applications from the palette, but it does declare `mode`, and GTK follows that from light to dark — so a theme may be light, and three are. **This last part reverses the original decision; see "Light themes, and the reason that did not survive being checked" below.**

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
| GTK | nothing, per application — each reads `settings.ini` as it starts. The polkit agent and the GTK portal are long-running, so they are restarted |

foot deserves the emphasis because it looks like it should work. `SIGUSR1` switches between the `[colors-dark]` and `[colors-light]` sections already present in the config, which is a different thing from rereading the file, so there is no signal that helps.

Three decisions inside the decision:

**Where the selection lives.** In chezmoi's machine-local config, not the repository. Switching a theme should not produce a commit, and two machines syncing the same repository should be able to disagree. This works because chezmoi merges config data *over* `.chezmoidata` — which was verified in both directions, and with no config file at all, since the installer chroot runs in exactly that case and must still get a theme.

**What triggers the reload.** A `run_onchange_` script, not the switcher. A theme switch is not the only way the colours change: editing a value in `themes.toml` and running `sync.sh` changes them too, and a reload owned by the switcher would not happen then. The rendered script embeds the theme name *and* a hash of the selected palette, so both cases re-run it.

**How far a theme reaches.** GTK applications cannot be recoloured from a palette without shipping real GTK themes, so they get stock Adwaita either way. What they do follow is which end of it: `mode`. *This originally read that they read `GTK_THEME` once at session start and therefore stay Adwaita dark, giving the rule that every theme must be dark. The premise was wrong — see below.*

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

**Let a theme carry GTK too, by declaring light or dark and rewriting `GTK_THEME`.** ~~Rejected for now.~~ **Adopted, by a different mechanism — see the next decision.** The reasoning here was that `environment.d` is read when the user manager starts, so GTK would only catch up after a re-login, making the switch half immediate and half not. That is true of `GTK_THEME` and false of the thing that actually decides. Generating a GTK theme per palette is still rejected, and still the largest option for the least-used surface.

**Committing the generated images anyway.** Rejected on arithmetic. It also has a subtler cost: every theme added would make the repository bigger for everyone who clones it, which turns "add a theme" into a decision rather than a whim.

**Fixed terminal colours across themes.** Rejected. A theme that changes the bar and leaves the terminal in the old palette looks half-applied. The sixteen ANSI colours travel with the theme, but keep their own identities — a theme that made `blue` gold would break every program that assumes a diff is red and green.

---

## Light themes, and the reason that did not survive being checked

**Decision:** Every theme declares `mode`, `light` or `dark`. GTK follows it
through `gtk-3.0/settings.ini`, and `GTK_THEME` is no longer set at all. Three
light themes ship: `paper`, `daylight` and `sepia`.

### Why

The previous decision fixed every theme as dark, and gave a reason: GTK reads
`GTK_THEME` once at session start, so a light desktop would leave every GTK
dialog dark until the next login. The reason was specific, plausible, and
load-bearing — it is why the rule was written into `CLAUDE.md`, the manual and
`themes.toml`'s own header rather than left to be discovered.

It was also wrong, and cheap to check. `GTK_THEME` is the loudest lever, not the
only one. `gtk-3.0/settings.ini` is read by each GTK process **as it starts**,
and it decides whenever `GTK_THEME` is unset. Launching pavucontrol with the
variable unset and a `settings.ini` naming `Adwaita` rendered it fully light
immediately, on the running machine, with no re-login. So the real boundary is
not "needs a re-login" — it is the boundary foot already has and this repository
already documents: **processes started after the switch follow it, ones already
running do not.**

The surface is also far smaller than the rule implied. Of the declared packages
that pull in GTK, `waybar` and `greetd-regreet` are styled by this repository's
own templates and never consult Adwaita, which leaves three that a light theme
could have stranded: the polkit authentication dialog, `pavucontrol`, and the
`xdg-desktop-portal-gtk` file chooser. `pavucontrol` is launched fresh every
time and needs nothing. The other two are drawn by long-running user units, so
`run_onchange_after_reload-theme.sh` restarts them for exactly the reason it
already restarts waybar — and with that, nothing is left holding the old mode.

Writing a light palette is not inverting a dark one, which is the part worth
recording for whoever adds the fourth. Two values have to be aimed at rather
than translated: `warning` and `info` must go dark enough to clear 4.5:1 against
a near-white background, where a dark theme's bright amber and blue measure
around 2:1; and `tertiary` fills the focused workspace disc with `text` on top,
so it inverts from a mid-dark colour under light text to a light tint under dark
text. The existing contrast floors needed no change at all — they sort the two
luminances before dividing, so they were direction-agnostic already.

### Trade-off

A theme switch is now slightly more disruptive than it was. Restarting the
polkit agent and the GTK portal is cheap and both are re-activated on demand,
but if a switch lands while a file chooser is open or a password prompt is
waiting, that dialog closes. A dialog to reopen is a smaller cost than a session
spent half-light, and the alternative — leaving them — is the "configured and
does nothing" failure this repository keeps meeting.

`GTK_THEME` is also now a line that must *stay* absent. Setting it again would
pin GTK to one mode and break nothing loudly; the dialogs would simply stop
following the desktop. `checks/session.sh` checks for it, along with the mode of
every theme against the measured luminance of its own background.

### Alternatives considered

**Keep the rule and refuse light themes.** Rejected once the premise was
checked. A constraint is only worth its cost while its reason holds, and this
one's reason was a hypothesis that had never been tested against the running
system — the failure mode `CLAUDE.md` names, arriving in the documentation
rather than the configuration.

**Ship real GTK themes generated per palette.** Still rejected, unchanged from
last time: much the largest option for the least-used surface. Light-or-dark is
the part that actually matters here, and stock Adwaita provides both.

**Set `GTK_THEME` from the theme instead of removing it.** Rejected. It would
work only after a re-login, which is the very objection that blocked light
themes before, and it would override `settings.ini` — so the immediate mechanism
would stop working in order to keep a variable that adds nothing.

**Restart every GTK application on a switch.** Rejected. There is no list of
them, killing a user's running programs to recolour them is far past what a
theme switch should do, and the two that genuinely matter are units this
repository already owns.

---

## The bar's glow is a setting, remembered per theme

**Decision:** The bar's haloes are optional. Every theme declares a `glow`
default in `themes.toml` — on for the eight dark themes, off for the three
light ones — and `~/.local/bin/glow` overrides that default for one theme on
one machine, storing the answer under `[data.glow]` in chezmoi's own config
next to the wallpaper style. Where the glow stays on, its blur radii dropped
from 5/6/7 pixels to 3/4/5.

### Why

Because it was tuned on one theme and then applied to eleven. The effect —
a `text-shadow` with no offset behind every readout, plus an inset bloom along
the bar's bottom edge — is most of what makes `neon` look like `neon`. Light
needs somewhere dark to be bright against, and on `paper` the same halo
renders as a grey smear under near-black text: not light coming off the glyph,
just a glyph that has gone slightly out of focus.

Per theme rather than one global switch, for the same reason the wallpaper
style is per theme. The right answer genuinely differs between palettes, and a
single setting would mean re-deciding it on every switch. Remembering it means
the choice is made once per theme and never again.

Tracked default plus machine-local override, rather than either alone. The
default has to be tracked because the installer renders the stylesheet in a
chroot with no config file at all, and a theme that shipped without an answer
would fail at render. The override has to be machine-local because choosing
should not produce a diff to explain — the same rule the theme name and the
wallpaper style already follow.

The radii came down independently of the switch. At 5-7px the halo reached
well past its glyph, and on a bar 34 pixels tall neighbouring readouts bled
into one another; the effect is meant to make text look lit, which needs the
light to stay where the text is.

### Trade-off

A third thing that varies per machine, and a third thing the repository cannot
tell you about a running desktop — `glow --current` is the only way to know,
exactly as with `theme --current` and `wallpaper --current`.

It is also a value that must be spelled `on` or `off`. The template asks
`eq ... "on"`, so `true` or `yes` would render as off while looking set, which
is this repository's signature failure. `checks/session.sh` checks both the
declared defaults and whatever the machine has chosen.

### Alternatives considered

**Derive it from `mode` and have no setting at all.** Rejected, though it is
what the defaults amount to today. It answers the common case and forbids the
uncommon one: a dark theme someone wants flat, or `sepia` with a little lift,
would both be unreachable, and the user's request was explicitly for a switch.

**One global on/off, not per theme.** Rejected. It would have to be re-set on
every switch between a theme that wants it and one that does not, which is
precisely the friction the per-theme wallpaper memory already removed.

**Turn the glow down for light themes instead of off.** Rejected as a
substitute for the switch, on the evidence: a dimmer halo on a white
background is still a smear, because the problem is direction rather than
strength. The radius reduction was worth doing on its own merits and was done
everywhere.

**Leave the rules in place and override with `text-shadow: none`.** Rejected.
It would leave a rule to keep in step for every module added later, and this
repository has already been bitten by configuration that looks set and does
nothing. The template emits no rule at all when a theme does not glow.

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

## Neovim as the editor, and how a file gets opened

**Decision:** Neovim is the editor, set as `EDITOR`, `VISUAL` and the handler for the file types that are plainly code. Files are opened from the launcher through `gio open`, not `xdg-open`, and `~/.local/bin/xdg-terminal-exec` supplies the terminal that terminal applications need.

### Why Neovim

The question worth asking was the one on TASK-65: a text editor connected to other tools, or a cohesive environment that subsumes them. That is a real fork, and Emacs is the serious case for the second answer — `org-mode` alone would absorb the notes, todo and calendar-agenda tickets into one system, `org-caldav` covers the Google sync, and `magit` is a strong answer to the git-tool ticket. Four tickets collapsing into one tool is not a small argument.

It was rejected in favour of keeping those as separate, replaceable pieces. Neovim is 30 MiB against Emacs's 264 MiB, was already installed and already the handler for `text/plain`, and starts fast enough to be the thing that opens when you press enter on a file. Helix was the third candidate and is genuinely good with no configuration at all, but has no plugin system yet, which makes it a bet on never needing to extend it.

The cost is accepted rather than hidden: notes, todo and the calendar stay three separate builds, and the editor's own environment — LSP, debugging, git integration — is assembled rather than arriving whole.

### Why the opening chain is what it is

This part was not a preference. Choosing a file in the launcher did nothing at all, and finding out why took tracing rather than reading.

`xdg-open` is a shell script that picks a strategy from the detected desktop. Sway is not one it recognises, so it takes the generic path — and **the generic path parses the desktop entry itself and executes the command directly, ignoring `Terminal=true`**. Traced with `bash -x`, it ends in `env nvim /tmp/file.py`. From a terminal that is arguably correct, and is why `xdg-open` is left alone there. From a launcher there is no terminal, so the editor starts, finds no tty, and dies without reporting anything.

`gio open` is glib's own implementation and honours `Terminal=true` properly: it looks for a program named `xdg-terminal-exec` on `PATH` and runs the command inside it. That program is a freedesktop convention rather than a package here, and is three lines.

Two consequences worth stating, because both were load-bearing:

- **`~/.local/bin` had to go on the session `PATH`.** glib looks for `xdg-terminal-exec` by name, and unlike every previous instance of this problem there is no way to hand it an absolute path. The absolute-path habit that fixed the desktop entries and the bar's click commands cannot fix this one.
- **The same bug had already been shipped.** The `inode/directory` → `yazi.desktop` association was declared, commented as working, and never opened anything. It is the repository's signature failure: configuration that looks correct and does nothing.

### Trade-off

The launcher and the terminal now open files by different routes — `gio` from the launcher, `xdg-open` in a shell. That is deliberate, since the right behaviour genuinely differs, but it means "what opens this file" has two answers and only one of them honours `Terminal=true`.

### Alternatives considered

**Shipping our own desktop entries that name `foot` explicitly**, the way `set $explorer foot --app-id=explorer -e yazi` does. It works, and it fixes one entry at a time forever, including having to shadow entries that packages ship. Supplying `xdg-terminal-exec` fixes the category once.

**Installing a terminal glib recognises without help.** Older glib carried a hardcoded list — `xterm`, `gnome-terminal`, `konsole` — so this would mean installing an X11 terminal on a Wayland system purely to satisfy a lookup.

**Setting `XDG_CURRENT_DESKTOP` to something `xdg-open` recognises**, so it takes a gio path. Rejected as lying to every other program that reads it to decide how to behave.

---

## Neovim autosaves, and that is the whole of the swap-file fix

**Decision:** A modified buffer is written about a second after the last change, in insert mode as well as normal, debounced so a burst of typing is one write. There is deliberately no swap-file handling to go with it.

### Why

The symptom was neovim's `E325: ATTENTION` dialog on opening a notes file — a swap file "modified: YES", which is neovim saying an earlier session died holding changes that never reached the disk. Closing the terminal instead of quitting is all it takes, and this machine had accumulated three of them for one file, plus one for a file that had never been written to disk at all. Between them they held five todo items that no longer existed anywhere else.

`Ctrl+S` had already been added (TASK-171) and is not the answer to this: it depends on remembering, and every other editor the user works in does not.

**The measurement decided the shape.** A stale swap file is only a problem when it holds unsaved changes. `kill -9` on a dirty buffer and reopening the file produces the whole dialog; `kill -9` after a write produces nothing at all — neovim compares the swap against the file, finds them identical, and deletes it on the way in without saying so. Both halves were run, including a negative control that reproduced `E325` on demand, so the claim is not "autosave should help". Saving *is* the fix, which is why there is no `SwapExists` autocmd here guessing which swap files are safe to delete.

**Debounced rather than on leaving insert mode**, which was the other candidate offered. A write on `<Esc>` never lands mid-word, but it also never happens while you are still typing — which is precisely when a terminal gets closed, and precisely what produced the swap files above. On-`<Esc>` would have left the causing case uncovered while looking like a fix, which is this repository's signature failure.

The interesting part is not the timer but the four things it refuses to write, each of which is a way this could have gone wrong quietly:

- **Buffers with no file behind them** — a terminal, the help viewer, the quickfix list, an unnamed scratch buffer. A terminal buffer changes on every line of output, so without this it would be the loudest caller of the whole mechanism.
- **`nomodifiable` and `readonly` buffers**, where writing is a mistake rather than a no-op.
- **Anything mid-completion.** The write dismisses the popup, and the popup being up means this is mid-word by definition. It reschedules instead.
- **A file that has changed on disk since neovim read it.** This is the one worth stating: `:update` does not *fail* there, it asks, modally — *"do you really want to write to it (y/n)?"*. A prompt nobody asked for, arriving a second after you stop typing, eats the next key you press. `git checkout` under an open buffer is enough to cause it, in this repository more than most. So the mtime is compared first and autosave stays out of the way, leaving a deliberate `Ctrl+S` to answer the question.

The write is `silent update` — `update` so an unmodified buffer is left alone, `silent` so "N lines written" does not overwrite the message area once a second. Not `silent!`: that would swallow the errors too, and a write failing quietly every second is exactly the class of bug this repository keeps finding. A write that fails stops autosave for that buffer and says so once, rather than repeating itself for as long as the buffer is open.

### Trade-off

Anything watching the file sees half-finished lines. A dev server or a file watcher will rebuild on a sentence you have not finished. That was put to the user against the on-`<Esc>` alternative and accepted.

More subtly, **"close it without saving" stops being an escape hatch.** The file on disk is no longer a checkpoint you control, so undo is the only way back — which is why `undofile` mattering is not incidental: history survives closing the file, so the escape hatch moved rather than disappeared.

Format-on-save stays off, and autosave makes that argument stronger rather than weaker: reformatting the buffer under the cursor a second after you stop typing would be unusable. `<leader>f` remains the only thing that reformats.

### Alternatives considered

**`autowriteall`.** The built-in answer, and it writes on `:next`, on switching buffers and on quitting — but not on being killed, which is the entire case. It would have fixed nothing here.

**A `SwapExists` autocmd that deletes stale swap files whose process is gone.** The usual recipe, and it treats the symptom: it would have thrown away exactly the five todo items that were recovered from these swaps. The measurement above made it unnecessary as well as unwise.

**An autosave plugin (`auto-save.nvim` and friends).** Around 60 lines of Lua against a dependency, a lockfile entry and someone else's decisions about which buffers to skip — and the buffers to skip are the whole design, as above. The same argument that keeps this configuration off a distribution.

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

## lazygit as the git interface, and delta deliberately not yet

**Decision:** Install lazygit, reached on `$mod+g` and from the launcher through
a helper that opens it on the focused window's repository.

### Why

The alternative was a pager — `git-delta` — and the two are not the same
question, which is what the choice turned on. delta makes a diff readable. It
does not stage a hunk and it does not resolve a conflict, which are the two jobs
that actually send people looking for something better than the CLI.

Compared by driving each against a clone of this repository's real history
rather than by reading feature lists. `tig` shows its status as a list of
filenames with no diff until you press enter; `gitui` leaves the diff pane empty
until a file is selected; lazygit arrives with the diff, the log, the branches
and the stash already drawn. Staging one of three hunks took the same number of
keystrokes as `git add -p` — the difference is that `add -p` asks you to decide
on hunk one before it will show you hunks two and three, and lazygit shows you
all three first.

Conflict resolution is what settled whether a graphical merge tool was also
wanted. It is not: on a real conflicting merge lazygit filters to the
conflicting files and resolves a side in one keypress.

**delta is deliberately absent, and this is the interesting half.** It is cheap
at 5 MiB and it would be the obvious companion — but it is configured in a
gitconfig, and until TASK-37 there was no tracked gitconfig at all. Adding one
for delta alone would have created a second home for git settings a few days
before the first one existed. lazygit ships explicit delta support, so it can be
added to the command line and to lazygit together, and nothing here changes.

### Trade-off

About a second to a full first frame, against a few milliseconds for
`git status`, and it is the largest of the three TUIs at 19 MiB. It depends only
on git and glibc.

### Alternatives considered

**difftastic** — structural diffing, and genuinely better output. Rejected on
size: 114 MiB, six times lazygit, for the reading half of the problem only.

**tig and gitui** — both smaller, both above.

**Nothing, and better git aliases** — the honest baseline. Rejected because
`add -p` deciding blind is the specific friction this is for.

---

## The installer asks, rather than requiring a file to be edited first

**Decision:** `install.sh` runs a wizard before the first destructive step,
asking for the machine identity and writing it into `setup/install.conf`.

### Why

Editing a file before the first install is the one step a new machine cannot
document to itself: you have to know it is required before you have anything to
read. And the failure is delayed rather than loud — a wrong locale or keymap
produces a working installer and a broken machine an hour later.

It runs as step `[0/5]`, ahead of `01-disk.sh`, which is the last moment an
answer can still be changed for free.

Validation is against the live system rather than a regular expression: the
timezone must be a real file under `/usr/share/zoneinfo`, the locale must have a
matching line in `/etc/locale.gen` *and* carry a `.UTF-8` suffix — because
`03-system.sh` uncomments that exact line and then writes `LANG=$LOCALE`
verbatim, so a bare `aa_ER` would generate `aa_ER.utf8` and set an LANG nothing
could resolve — and the keymap must exist under `/usr/share/kbd/keymaps`.

### Trade-off

`install.conf` is now machine-written as well as hand-written, so its
`KEY="value"` quoting is load-bearing in a second way: it has to satisfy
`source` *and* the regex `dot_gitconfig.tmpl` uses to read the same file. The
wizard refuses values containing `"`, `\`, `` ` `` or `$`, renders to a temp
file, sources it back in a clean environment and compares key by key before
replacing anything.

### Alternatives considered

**`dialog` or `whiptail`.** Neither is on the Arch install medium. A wizard that
must install a package before asking its first question is worse than the text
editor it replaces.

**A separate override file** rather than rewriting `install.conf`. Rejected
because that file has two consumers with two different parsers — the stages
`source` it, and `dot_gitconfig.tmpl` parses it — so an override would have
needed changes in both places and would have stranded the git identity.

### The non-interactive path is preserved deliberately

`--no-wizard` skips it, and so does any run whose stdin is not a terminal — so
an existing scripted build keeps working without learning a new flag.
`--wizard` forces it on anyway, which is how answers can be piped in.

---

## Git identity lives in `install.conf`, and is committed

**Decision:** Put `GIT_NAME` and `GIT_EMAIL` in `setup/install.conf` alongside
the other machine identity, and render `~/.gitconfig` from it.

### Why

A machine built from this repository could not commit. With a `HOME` holding no
gitconfig, git refuses with "Author identity unknown" — and nothing under
`setup/` mentioned git configuration at all, so the identity on the reference
machine came from a hand-written file chezmoi did not manage.

Committed rather than prompted, which is the opposite of the entry above, and
the difference is what kind of thing each is. A password is a secret. A name and
an email address are not, and this repository's own history publishes both on
every commit — committing them reveals nothing `git log` does not already. More
practically, prompting answers the question in the one place it can only be
answered once, and leaves `sync.sh` with nothing to apply.

`~/.gitconfig` rather than `~/.config/git/config`, measured rather than assumed:
with both present, `~/.gitconfig` wins. Managing the XDG path would have left a
hand-written file quietly in charge and the managed one inert — the "configured
and does nothing" shape again.

The template fails loudly on a missing or empty value, because git *accepts* an
empty `user.name` and writes unattributable commits rather than complaining.

### Trade-off

Anyone forking this has to edit `install.conf` before their first commit, or the
render stops them. That is the intended failure: the alternative is committing
under someone else's name.

### Alternatives considered

**Machine-local chezmoi data, like the theme.** Rejected: the identity is
per-*person*, not per-machine, and this build has one person — `USERNAME` is
already equally personal and already committed. It would have split one identity
across two files for no gain.

---

## No SSH key or agent is provisioned by the build

**Decision:** The build establishes no SSH key and starts no agent. It does
declare the client.

### Why

Measured first: no agent process, `SSH_AUTH_SOCK` unset, every agent unit
disabled — and `ssh -T git@github.com` authenticates anyway, because the key has
no passphrase and ssh simply reads it from disk. An agent exists to cache a
passphrase, so here it would cache nothing. That is a unit doing nothing, which
this repository has enough of.

Generating a key at first boot is worse than doing nothing: it produces a key
that cannot push until somebody registers it, which *looks* provisioned and is
not — indistinguishable from a working setup until the first push fails.

**What was actually broken was the client.** `openssh` was never declared, and
was held only by `gcr-4 ← gvfs / libnma-common ← network-manager-applet`. `git`
does not depend on openssh, so this repository's own `git@github.com` remote
worked as a side effect of the NetworkManager tray applet's dependency tree —
and removing that applet, which is under discussion on TASK-58 precisely because
this desktop has no tray, would have taken ssh with it. Same shape as the
`polkit` case in TASK-13, and now declared in `base.txt`.

### Trade-off

A new machine still needs `ssh-keygen` and a manual registration step. That step
is interactive whichever way it is reached.

### Alternatives considered

**`gh ssh-key add` to register automatically.** Rejected: `gh` is neither
installed nor declared, so it costs a package plus `gh auth login` — the same
browser step it was meant to remove, one level further away.

**A `gcr-ssh-agent` unit.** Rejected for now rather than on principle. It ships
with the already-installed `gcr-4` and can be enabled unchanged if a passphrase
is ever adopted, at which point it starts having something to do.

---

## Additional application configuration

Applications such as Foot and Mako should only gain committed config files when there are meaningful customisations worth preserving.

The repository should avoid configuration for configuration's sake.

---

## A manual, built as one HTML page

The repository documents itself for whoever is building it, in four places that
all assume you already know how the system was made. `docs/manual/` is the
fifth and is the only one written to be *read*: ten chapters covering how to
use the desktop and how to change it, in `docs/manual/*.md`, assembled by
`tools/manual.sh` into one self-contained HTML page.

`tools/manual-render.py` is a markdown renderer of about 250 lines of standard
library Python, reading a dialect this repository defines.

### Why

**One document, not ten files.** A manual split across a directory is a manual
nobody reads end to end: you open the one file whose name looked relevant and
never find out what the other nine say. One page with a contents column that
stays on screen and links between every chapter is the actual requirement, and
HTML is what delivers it.

**Self-contained matters as much as single.** No stylesheet to fetch, no font to
download, nothing to install to read it. Copy the file to a phone or to the
laptop you are about to install this onto — precisely the moment the machine it
describes does not exist yet — and it still works. A browser will print it if
you want it on paper, which is where the print stylesheet earns its keep, but
paper is the fallback rather than the target.

Writing a renderer rather than installing one is the part that needs justifying,
and the justification is the `setup/` boundary. It is also a smaller job than it
sounds, because the output is HTML rather than PDF: there is no page model, no
font embedding and no typesetting — only markup. The manual is repository
tooling: like `backlog`, `checks/` and `tools/`, it never reaches the built
machine, so nothing it needs may be added to `setup/packages/`. That leaves a
repository-level dependency, and every candidate was disproportionate. None of
pandoc, weasyprint or wkhtmltopdf is installed here; the cheapest costs more
than the document weighs, and `pandoc-cli` alone is a static Haskell binary
larger than the fonts, the icons and the compositor put together.

The input is not arbitrary markdown from the internet. It is ours, written to a
dialect stated in `docs/manual/README.md`, which makes a purpose-built reader a
few hundred lines rather than a research project.

### The property that actually matters

Not that it renders markdown — that it **refuses** what it does not understand,
with a file and a line number. An image silently dropped, or a nested list
flattened, would put this document in the same category as every other bug this
repository has hit: looks correct, does nothing. The renderer treats images, raw
HTML, footnotes, task lists and reference-style links as build failures rather
than as things to approximate.

The same reasoning produced `checks/manual.sh`, which fails when the manual
names a file, a helper script or a `$mod` keybinding that does not exist, and
`tools/shortcuts.sh --markdown`, which generates the entire keyboard reference
from the sway and zsh configuration. Chapter 3 contains no hand-typed shortcut
table, because a hand-kept one is wrong the first time somebody changes a
binding and forgets the document.

### Trade-off

The dialect is narrower than markdown, and a writer who reaches for something
outside it gets a build error rather than a rendered page. That is the intended
direction of failure, but it is a real cost: the manual cannot contain a
diagram, and a screenshot has to be described in words.

The rendered manual is not tracked. `docs/manual/build/` is ignored, so reading
it requires building it — which `sync.sh` now does, installing the result where
the `manual` command and the launcher entry find it. A machine's manual is
therefore as current as its last sync, stale in the same visible way as every
other dotfile rather than in a new invisible one.

### Alternatives considered

**pandoc.** The obvious answer, and the one to revisit if the manual ever needs
something the dialect cannot express. Rejected on size against a document it
would outweigh, and on the `setup/` boundary. Note that it was only ever needed
for PDF; producing HTML never required it.

**`python-markdown`.** About a megabyte, does the job properly, and has table
and fenced-code extensions already. Rejected because it is still a package, and
adding one to the built machine so that repository tooling can run is exactly
the exception `pacman-contrib` already is — one is a documented irregularity,
two is a pattern.

**Markdown only, no build.** Readable on disk and on GitHub, and free. Rejected
because it is the ten-files problem: no single document, no contents column
that follows you, and nothing to hand to someone who does not have the
repository. The chapters stay readable as markdown regardless — the build adds
a way to read them together, it does not replace them.

**A static site generator, or mdbook.** More than is wanted. The output needed
is one file, not a site with navigation and a search index.

---

## Music is searched for, and what is remembered is the search

`focus-music` began as a fixed list of direct audio URLs, on the reasoning that
a station which needs resolving is a station that can break for reasons nobody
can see. TASK-145 met the limit of that: Minecraft's soundtrack is carried by no
internet radio station anywhere, so the only way to have it was a YouTube link.
TASK-147 followed the same road to its end and made search a first-class way in
— type anything, see durations and whether a result is live, play its audio —
because a music feature you can only extend by editing a file and running
`sync.sh` is not one you reach for when a particular song is in your head.

That raises the obvious problem: a growing pile of YouTube ids is a growing pile
of links waiting to rot, discovered one silence at a time. The answer is in what
gets stored. **A kept station records the search text, never the video id it
resolved to**, and the query is run again on every play.

### Why

A video id is a promise that a specific thing will still be there. It is broken
by a deletion, and broken wholesale when a channel restarts a 24/7 broadcast
under a new id — which is not a hypothesis, it is what the evidence in TASK-145
showed that channel doing repeatedly. A search makes no such promise and so
cannot break in that way. It also repairs itself across exactly the failure that
kills ids: the live stream that came back under a new number is found again by
the same words.

Two smaller decisions fall out of it. Nothing is written down unless it is
deliberately kept, so browsing leaves no residue at all. And what is kept goes
in `~/.config/focus-music/stations.local`, which chezmoi does not manage, so
keeping a station on one machine is not a commit and `chezmoi apply` cannot
clobber it — the same machine-local escape hatch the theme selection uses.

### Trade-off

A search can drift. If the video behind it disappears, the next play resolves to
whatever now ranks first for those words, which may not be what was meant. That
is accepted deliberately: drifting to something adjacent is a smaller failure
than silence, and it is visible the moment it happens, which a dead id is not.

Resolving also costs a second or two before sound, where a direct stream starts
immediately. So the tracked radio stations stay direct URLs; search is what you
reach for when nothing carries what you want.

### Alternatives considered

**Store the id and prune dead ones periodically.** This is the version that
needs a chore, and a chore that only matters when it has already been skipped.
The failure is silent and the fix is manual — the exact shape this repository
keeps getting caught by.

**Store nothing at all; search every time.** Very nearly right, and it is the
default. But a stream you return to daily should not have to be retyped daily.

**Resolve a channel's `/live` URL instead of an id, for live streams.** Tested
during TASK-145 and rejected on evidence: the channel checked was serving an
unrelated broadcast on that URL, so it names a slot rather than a thing.

`focus-music --check` covers the remainder — the direct URLs and the one pinned
video id that do exist — by resolving every entry and naming what no longer
answers, so pruning is a decision rather than a discovery.

---

## One mpv, addressed by its socket, holding the queue itself

Playing music used to mean starting a fresh `mpv` and killing whatever was
there. That is fine for one radio station and hopeless for a queue, so mpv is
now started once, idle, listening on a JSON IPC socket under
`$XDG_RUNTIME_DIR`, and every later instruction - queue this, play that now,
reorder, remove, skip, stop - is a message to that socket.
`~/.local/lib/mpv_queue.py` is the only thing that speaks it, on the same
principle as `desktop_config.py` being the only writer of `chezmoi.toml`.

**The queue is mpv's own playlist**, not a list kept alongside it. There is
therefore no second copy of the running order that could drift out of step
with what is actually playing.

### Why

Addressing mpv by a socket fixed a real bug rather than only enabling a
feature. Stopping was `pkill -x mpv`, which kills *every* mpv the user is
running - including one playing a film in another workspace. A socket names
one instance exactly.

### Trade-off

mpv only knows a title for the entry it is playing; everything queued behind
it comes back as a bare URL, which is useless as a queue view. So titles are
remembered in a small map keyed by URL. That map is strictly a lookup and is
pruned against the playlist on every read: it can be incomplete, but it cannot
make the queue lie about its own contents, because order and membership always
come from mpv. Anything queued by something other than this helper simply
shows its URL.

`keep-open=yes` needed the same care. It exists so a dropped stream does not
silently end the music, and it is set globally in `mpv.conf` - which also
governs watching a film. Left alone it means the last track of a queue ends
and mpv sits on it paused forever, with the bar still advertising music that
stopped. Rather than change the global, finite tracks are queued with
`keep-open=no` as a per-file option, so a queue ends cleanly while radio and
films keep the behaviour the config asked for.

### Alternatives considered

**Keep killing and restarting mpv, and hold the queue here.** Then this
repository owns a running order, a current position and a title list, all of
which must be kept in step with a process it does not observe. Every bug in
that class is invisible until the music does the wrong thing.

**`insert-next-play` for "play now".** It reads exactly right and does not do
it: mpv's `-play` suffix means "start playback if nothing is playing", not
"switch to this now", so with music already on it silently behaves like "play
next". Playing something now is an insert followed by an explicit skip. This
was found by testing the behaviour rather than reading the flag name.

## The desktop's sounds are generated, not shipped

Four sounds — `notify`, `alert`, `complete`, `limit` — are computed on the
machine from tables of frequencies, envelopes and levels in
`~/.local/bin/sounds`, cached in `~/.local/share/sounds/`, and played by
`~/.local/bin/play-sound` through `pw-play`. Nothing audio-shaped is tracked in
this repository, and `checks/session.sh` fails if anything ever is. (TASK-154
added a choice of instrument for those four sounds — see *Sound packs* below —
without touching any of the reasoning here.)

### Why

The same argument the wallpapers already settled, for the same reason: audio is
binary, it cannot be diffed or reviewed, and a git repository keeps every
revision of it forever. A set of four sounds is small; a set of four sounds that
somebody re-records twice is not, and the cost arrives silently.

The second reason is the one that actually decided it. What was asked for was a
*subtle* sound for a notification and a *prominent* one for a dialog — which is
a statement about the relationship between two sounds, not about either one.
Generating them makes that relationship something the table states outright: one
timbre, and the meaning carried by how many notes there are and how low they
sit. Count and register do the work, so only `alert` needs to be loud.

`sound-theme-freedesktop` was the alternative and is genuinely already on this
machine — but only as a transitive dependency of `pavucontrol`, which is exactly
the "installed as a dependency" trap this repository has been bitten by before.
Using it would have meant declaring it anyway, and would still have left the
sounds fixed: that set was designed for GNOME around 2008 and its members have
no particular relationship to each other.

### Trade-off

Nobody can hear a sound by reading the diff. A change to the table has to be
listened to, which `sounds --preview` exists for. Against that, a colour in this
repository has exactly the same property and is handled the same way.

The generator is about 350 lines of standard-library Python to avoid roughly
100 KiB of audio, which is a poor trade measured in bytes and a good one
measured in what a future change costs. `sounds set <event> <file>` takes a file
of your own for any event, so nobody is stuck with the generated ones.

### Alternatives considered

**Honour the freedesktop `sound-name` hint.** This would be the better design
and mako cannot do it. foot already *sends* the hint — its default notification
command passes `--hint STRING:sound-name` and `--hint BOOLEAN:suppress-sound` —
but `makoctl list -j` returns id, app name, icon, category, desktop entry,
summary, body, urgency and actions, and hints are among neither those nor the
criteria fields. Measured, not assumed. Reading them would mean a second daemon
eavesdropping on the session bus to choose between four sounds. Urgency and
app-name do the job.

**A daemon subscribed to sway's window events**, to catch the password prompt.
Unnecessary: `for_window [criteria] exec` fires on the window appearing, which
was verified rather than assumed. That is one line of configuration instead of a
fifth supervised session component.

**A sound on every notification, including low urgency.** Low urgency is the
sender saying you need not act on this. Making a noise about it is the
definition of a desktop that cries wolf, so `[urgency=low]` is explicitly
silent.

**A separate volume for system sounds.** Asked about in the ticket, and not
done. Each sound has a fixed level baked into the file, relative to the others;
the system volume moves all four. One slider is what a person expects, and a
second one is a setting to discover, remember and keep in step.

**Leaving do-not-disturb to mako.** mako's `[mode=dnd]` block could silence
notification sounds, but two of the three callers are not mako — the password
prompt and the volume ceiling — and they would have gone on pinging. The check
lives in `play-sound` instead, so one rule covers all of them and cannot drift
between two files.

## Sound packs

Which four sounds play is a choice, not a fixed set. `~/.local/bin/sounds`
holds several **packs** — `chime` (the original), `ps2`, `8bit` — each
defining the same four events with its own instrument: `chime` sums harmonic
partials, `ps2` is a single sine oscillator with a soft downward pitch-bend
onto each note, `8bit` is square and triangle waves with no bend at all,
using quick arpeggios instead — the trick chiptunes have always used to fake
a chord on a chip that can only hold one note. `sounds --pack <name>`
switches; `sounds --pack` opens a picker; an override set with `sounds set`
still wins over whichever pack is active.

### Why

Because a struck-glass ping is one aesthetic and there is no reason to make it
the only one this desktop can have, once sounds are generated rather than
shipped anyway — the marginal cost of a second and third pack is a table of
numbers, not a set of files to record, license or track.

### Where the active pack lives, and where it deliberately does not

**Not `chezmoi.toml`.** The theme, the wallpaper style and the bar's glow all
live there, under `[data]`, because a chezmoi template reads them at apply
time — see *Switchable system-wide themes* and *TASK-152* below. The active
sound pack is read by nothing that renders; it is read by
`~/.local/bin/play-sound`, in bash, on every single notification. Routing
that through `~/.local/lib/desktop_config.py` — which is itself Python — would
mean starting an interpreter on every notification purely to learn one word,
which is exactly the cost `play-sound` is written in shell to avoid (see the
entry above, and TASK-85).

So it lives in one line of plain text at `~/.local/state/soundpack`, written
only by `sounds --pack`, read directly by both `sounds` and `play-sound` with
no interpreter and no parser on the read path. It is still the same *kind* of
machine-local fact CLAUDE.md describes for theme/wallpaper/glow — switching it
leaves no diff, and two machines can disagree — it is just not consumed the
same way, and `~/.local/state/` (XDG state, not config) is the more honest
home for something read on a hot path rather than rendered once.

`play-sound` keeps a short duplicate of the pack list, so an unreadable or
hand-edited state file can fall back to `chime` without starting Python to ask
what the real list is. `checks/session.sh` checks that the two lists agree,
the same shape as the check that already covered the four event names.

### Trade-off

Two places now list the same three pack names — `sounds`, which is
authoritative, and `play-sound`'s fallback `case`. That is exactly the "two
lists that must agree" shape this repository is usually suspicious of, taken
on deliberately because the alternative was slower on every notification, not
occasionally. `checks/session.sh` is what stops it drifting silently, and was
proven to catch a real mismatch before being trusted (see the scripting-traps
skill's note on never trusting a check that has not been watched to fail).

### Alternatives considered

**One `chezmoi.toml` key, read by `play-sound` through `desktop_config.py`
anyway**, accepting the interpreter cost. Rejected on the same measurement
that put `play-sound` in shell in the first place: 30ms of Python startup on
every notification, for a value that changes on the order of once a session.

**A separate `soundpack` helper script**, mirroring `theme`/`wallpaper`/`glow`
each being their own command. Rejected because a pack is a property of the
sounds themselves, not a separate concern — `sounds --pack` keeps one binary
answering every question about what the desktop's sounds are, the same reason
`wallpaper` was not split into a second command when styles were added to it.

## Volume and brightness keys go through a helper that knows their limits

`XF86AudioRaiseVolume` and friends called `wpctl` and `brightnessctl` directly.
They now call `~/.local/bin/volume` and `~/.local/bin/brightness`, which read
the current level before stepping it.

### Why

The clamp at 100% was already there and is load-bearing — see *Volume has a
ceiling* — but a clamp that works says nothing. Holding the key at maximum is
indistinguishable from holding it while audio is routed elsewhere, or while the
keyboard has stopped responding: the reading does not move and nothing explains
why. A step that would change nothing now plays `limit` instead.

Brightness got the same treatment though only volume was asked for. A brightness
key that goes quiet at the top while the volume key answers reads as a bug in
one of them rather than a decision about either.

### Trade-off

Two more helper scripts, and a keypress that now starts a shell rather than
going straight to `wpctl`. Measured at about 11 ms, against a key held down at
five steps a second, which is comfortable.

`volume up` still runs the `wpctl` call even when it reports the limit, because
`-l 1.0` is also what walks an already-over-loud machine back *down* to 100%.
Skipping it would have left such a machine stuck, with a sound and no
correction.

## A long command rings the terminal bell

`.zshrc` rings the bell after any command that took more than twenty seconds,
excluding programs that are long by nature.

### Why

Because the rest of the chain already existed and nobody had connected it. foot
turns a bell into a desktop notification and does it *only when the window is
unfocused*, which is precisely the condition under which you want to be told.
mako then sounds it. The whole integration is one shell hook and one criteria
block; nothing new is supervised, and the focus logic — the hard part — is
foot's.

### Trade-off

A time threshold is a guess. Twenty seconds is long enough that you have
probably looked away and short enough to catch a slow request;
`LONG_COMMAND_SECONDS` in `~/.config/zsh/local.zsh` overrides it per machine.

The ignore list is the part that will need maintaining, and `claude` is on it —
which looks wrong, since a Claude Code response is what prompted the request. It
is correct: from the shell's side a session is one command that runs for an
hour, so the only thing this hook could ring for is quitting it. Claude Code has
its own notification setting for the per-response case, and pointing that at the
terminal bell puts it back on this same chain.

---

## Virtual machines with qemu alone, and clones that cost nothing

**Decision:** Ship the ability to run virtual machines, driven by qemu directly
through `~/.local/bin/vm`. No libvirt, no virt-manager, no daemon. Machines
cloned from the bundled base image are qcow2 **overlays** rather than copies.

### Why

Running something dangerous, or keeping a project's tooling away from the
machine you actually use, previously meant either not doing it or doing it on
the real system. Rebuilding this setup in a VM by hand was always possible and
never happened, because it meant an ISO download and the install wizard every
single time.

**Why qemu on its own.** libvirt and virt-manager do not run virtual machines;
qemu does, and it is the same `qemu-system-x86_64` process with the same `-m`
underneath either arrangement. A 2–4 GiB guest therefore costs the same both
ways, and the entire difference is scaffolding:

| Stack | Host-side overhead |
| --- | --- |
| qemu + a kiosk compositor | ~30 MiB |
| libvirt + `virt-viewer` | ~140 MiB (daemon plus viewer) |
| libvirt + the `virt-manager` GUI | ~250–330 MiB |

That saving is second-order next to the guest and is **not** the reason. The
reasons are fewer moving parts — no daemon, no XML domain definitions, no
`libvirt` group membership, no managed virtual network — and that qemu presents
straight to a Wayland surface instead of going through a SPICE server and a
`spice-gtk` client, which is a latency difference rather than a memory one and
is far more noticeable in use.

**Why overlays.** `qemu-img create -b` makes a disk that names the base as its
backing file and holds only what the guest has written since. A new machine is
therefore a few hundred KB and appears instantly, and returning one to a clean
state is deleting that file rather than reinstalling anything. This is most of
what libvirt's snapshots would have provided, for none of the machinery.

**Why the base image is generated and never committed.** Same rule wallpapers
follow, and for the same reason: a full Arch desktop image is 8–15 GiB, and
`checks/session.sh` already refuses anything image-shaped under
`setup/dotfiles/`. The image is built on the machine by repository tooling.

### Trade-off

**The base image must never be written to.** Modifying a backing file corrupts
every overlay derived from it, and the damage appears in the clones rather than
in the base — a genuinely unpleasant thing to debug. The builder leaves it
read-only and `vm run` warns if it has stopped being so, but this is a real
sharp edge that libvirt's managed storage would have blunted.

**No lifecycle management.** Nothing autostarts a guest at boot, there is no
API, and no snapshot tree beyond the single base-and-overlay relationship. If
any of that is wanted later, it is an argument for revisiting libvirt rather
than for growing `vm` into a daemon.

**qemu is exempt from `earlyoom`.** Killing a guest is a power cut to the
machine inside it, with the filesystem damage that implies, so qemu is in the
`--avoid` list in `setup/system/earlyoom.conf`. The host therefore cannot
reclaim memory from a running guest, which is only safe because `vm` always
passes a fixed `-m`. The cap and the exemption are one decision and must not be
separated. On the 7.5 GiB reference machine the default is half of host RAM.

### Alternatives considered

**libvirt + virt-manager.** The obvious answer. It buys snapshots, autostart,
managed NAT networking and a stable API, at the cost of a persistent daemon, XML
domain definitions, group membership and roughly 150 MiB of disk. None of the
things it buys were wanted; the overlay model covers the one that was.

**GNOME Boxes.** A friendlier front end to the same libvirt stack, and it brings
a large GNOME dependency footprint onto a machine that deliberately has no
desktop environment.

**`systemd-nspawn` containers.** Much cheaper, and genuinely better for
isolating a project's *tooling*. Rejected because it shares the host kernel, so
it does not answer the case this exists for — running something you do not trust
— and it cannot boot a different operating system.

**`qemu-ui-sdl` instead of `qemu-ui-gtk`.** Measured rather than assumed: `gtk3`
is already installed here, so GTK costs only `vte3` at 1.79 MiB while SDL would
cost `sdl2_image`. About 2 MiB apart. GTK was chosen for `zoom-to-fit` and a
menubar that can be switched off, both of which the full-screen login session
needs.

---

## Building the base image with the repository's own installer, not a copy of it

**Decision:** `tools/build-vm-image.sh` builds the bundled base image by
running `setup/install/01-05` — the same numbered stages `install.sh` runs —
against a qcow2 attached over `qemu-nbd`, rather than by writing a parallel
build path or calling `install.sh` itself.

### Why

The alternative to "use the real installer" is a second script that installs
Arch and this repository's configuration by some other means — and a second
implementation is a second thing to keep in sync. Every fix to `03-system.sh`
or every package added to `desktop.txt` would need to be re-learned by
whatever built the image, or the base and a fresh install would quietly
diverge. Running the actual stage scripts means the base image *is* what a
fresh install produces, not an approximation of it, and it doubles as the
scripted fresh-install reproducibility test `DECISIONS.md` already wanted (see
"Prefer fresh-install tests over modifying the reference VM") and had no cheap
way to run.

**Why not `install.sh` itself.** It was the first design, and reading it
closely found two reasons it cannot be pointed at a qcow2 on a running desktop,
only at a live ISO:

- it ends with `poweroff` — right when the whole machine *is* the disposable
  ISO environment, wrong when it is someone's desktop.
- stage 3 runs `bootctl install` inside `arch-chroot`, which — in its default
  mode, confirmed by reading `/usr/bin/arch-chroot` — mounts a **fresh sysfs**
  inside the target (a live kernel view, not a bind of the host's) and then
  conditionally mounts a **real efivarfs** over
  `$target/sys/firmware/efi/efivars` if that directory exists, which it does
  on any UEFI-booted host. Unmitigated, `bootctl` would write real NVRAM boot
  entries onto whichever machine ran the builder.

So the builder drives the five stage scripts directly, the same relationship
`install.sh` itself has to them, just for a different execution context.

**The efivars guard.** Masking the host's `/sys/firmware/efi/efivars` before
chrooting does nothing — a fresh `sysfs` mount inside the chroot reflects the
kernel's live state regardless. The mask has to happen *inside* the chroot,
after `arch-chroot`'s own setup has run and before the real stage script
executes:

```bash
arch-chroot "$MNT" /bin/bash -c '
    mount -t tmpfs tmpfs /sys/firmware/efi/efivars 2>/dev/null || true
    /opt/arch-setup/install/03-system.sh; rc=$?
    umount /sys/firmware/efi/efivars 2>/dev/null || true
    exit $rc'
```

This shadows whatever `arch-chroot` already mounted there — legal, and how
`systemd-nspawn` hides host EFI variables from containers by default — runs
the completely unmodified stage script against the shadow, then unmounts it so
`arch-chroot`'s own teardown (which tracks and unmounts the real mount it made)
still succeeds. `03-system.sh` is never touched; only which command the
builder hands to `arch-chroot` differs.

**Passwords stay interactive**, on purpose. `03-system.sh`'s `passwd` prompts
are exactly what a fresh install prompts for, and nothing pipes an answer into
them — verified rather than assumed, by testing what happens with no stdin at
all: TASK-131's five-attempt bound fails the build cleanly rather than hanging.
Building the actual base image therefore needs a human at a real terminal.

**`/dev/rtc0` gets resynced.** `03-system.sh`'s `hwclock --systohc` writes to
the host's real hardware clock, since `arch-chroot` bind-mounts `/dev` in
full. Accepted rather than masked: it just syncs the RTC to the
already-correct system time, self-correcting and not worth the fragility of
hiding a device other stage-3 commands may need.

**Two bugs in the builder's own nbd handling, found by testing rather than
assumed correct**, both confirmed on this machine:

- `/sys/class/block/nbdN/size` and `/sys/block/nbdN/pid` stay at their last
  value indefinitely after a genuine, verified disconnect. Picking a device by
  checking either would eventually mark every nbd device on the host "busy
  forever" after its first use. The only trustworthy signal is whether
  `qemu-nbd --connect` itself succeeds.
- a device can accept a connect and then serve no I/O at all — a device
  wedged by an earlier connection that did not tear down cleanly. So a
  candidate is proven twice, connects *and* serves a real read, before being
  accepted; one that fails the read is disconnected and skipped exactly like
  one that never connected.

**Two more, found by the first real build rather than a test one.** Every
stage completed correctly — both passwords, the full package set, dotfiles —
and it still went wrong, in a way no scratch test with a discarded image could
have caught:

- `$HOME` under plain `sudo` (no `-E`) is root's, not the operator's. The
  entire base image was written to `/root/.local/share/vm/base.qcow2`,
  invisible to `~/.local/bin/vm`, which reads the real user's home. The image
  itself was completely correct; only its location was wrong, and nothing
  said so. Fixed with `invoking_home()`, which checks `SUDO_USER` (`sudo`)
  then `PKEXEC_UID` resolved through `getent` (`pkexec`) before ever trusting
  `$HOME` directly — and the resolved output path is now printed plainly and
  early, with an explicit warning if it still lands under `/root`, so the same
  mistake would announce itself in the first line rather than twenty minutes
  later.
- the final `umount -R /mnt` hit a transient "target is busy" — something,
  unconfirmed, held a handle into `/mnt` for a moment after the last stage
  returned, and let go almost immediately on its own. Under `set -e` that
  aborted the *entire remaining script*, including `chmod a-w` and the success
  message, even though the build had genuinely finished. A bounded five-attempt
  retry replaces the bare call; a real, non-transient failure still stops the
  script loudly.

Both were recovered rather than rebuilt: the already-complete image was
copied to the right path (plain `cp`, so it genuinely inherits `nodatacow`
from the destination directory rather than carrying the attribute
literally), checksum-verified byte-identical against the original, and fixed
up in place. Twenty-some minutes of `pacstrap` and two typed passwords were
not spent twice.

### Trade-off

**Every clone starts from the machine that built the base image's
`install.conf`** — same hostname, same locale, same git identity. Accepted for
a first version rather than solved: nothing currently gives a clone its own
identity at `vm new` time. A natural follow-up is templating the hostname (and
perhaps the machine ID) into the overlay at clone time, the way `dot_gitconfig.tmpl`
already resolves `install.conf` per machine — not implemented here, and named
rather than silently decided.

---

## A virtual machine session at the login screen

**Decision:** Offer "Virtual machine" as a second session in ReGreet, beside
Sway. Picking it runs `~/.local/bin/vm`'s own menu inside `cage` - the same
kiosk compositor that already hosts the login screen itself - with nothing
else started: no Sway, no Waybar, no notifications, no idle handling.

### Why

The architecture already anticipated this. `regreet.toml` says, in the
comments written for TASK-11: "That is also what will make a second desktop
selectable if one is ever added." ReGreet builds its session picker by
scanning the `wayland-sessions` directories, and `greetd/config.toml`
already forces `XDG_DATA_DIRS` so `/usr/local/share` is searched first - both
existed before this task touched anything. The whole addition is one
selectable desktop entry, one three-line launcher, and one line each in
`apply-config.sh`'s two existing install arrays.

**The reason to want this at all, rather than just running `vm` from inside
Sway** - which already works - **is keyboard input, not resources.** Measured
directly on this machine for TASK-69.1: not running the Sway session saves
roughly 165 MiB, about 2% of this machine's RAM. That is not nothing, but it
is not the argument either. The argument is that Sway intercepts every
`$mod` combination before a client running inside it ever sees the key -
confirmed by this repository's own 76 keybindings - so a guest that wants to
use its own desktop's Super-key shortcuts cannot, from inside a normal Sway
session. `cage` defines no keybindings of any kind: its own `--help` output
and manual page document no configuration mechanism for any, which is a
structural fact about the compositor rather than an assumption about its
current config. A key `cage`'s seat receives has nowhere to go but its one
child.

**This is reasoned from cage's documented absence of a keybinding mechanism,
not measured with a live key-passthrough test**, and that gap is worth being
honest about rather than papering over. The direct way to measure it - inject
a synthetic keypress via a `uinput` device and observe what a guest actually
receives under each compositor, the same technique this repository already
uses to verify `keyd` bindings - needs root to create that device, and this
addition was implemented while root access was unavailable for the session.
The structural argument is strong (there is no code path in `cage` for a
keybinding to intercept anything), but it is still an argument rather than an
observation, and a follow-up with real `uinput` evidence would close the gap
properly rather than replace reasoning with authority.

### Trade-off

**ReGreet's own session picker, not a prompt after the password.** The
original shape imagined was choosing after authenticating; ReGreet shows its
picker on the login form beside the username instead. Same choice, different
order - patching ReGreet to move it would cost more than the difference is
worth.

**The picker remembers the last session per user** (ReGreet's own
`user_to_last_sess` cache), so a boot after picking Virtual machine defaults
back to Virtual machine, not Sway, until the dropdown is changed again. Not
configured or suppressed - it is ReGreet's ordinary behaviour, the same as it
already was for any machine with only one session before this one existed.

**`vm-session` resolves the real user's home through `getent`, not `$HOME`.**
The exact same class of mistake fixed in `tools/build-vm-image.sh` under
`sudo` - trusting an inherited environment variable for a path that has to be
right - would be just as available here: greetd launches the chosen session
as the authenticated user via PAM, which should set `$HOME` correctly, and
"should" was also true right up until it cost a rebuilt base image landing in
`/root`. Settling it outright costs one `getent passwd` call.

---

## Keeping a VM guest's keyboard from double-swapping the host's remap

**Decision:** Ship a systemd drop-in,
`setup/system/keyd/keyd.service.d/override.conf`, that skips starting `keyd`
only inside a guest launched by this repository's own `~/.local/bin/vm` -
identified by a DMI marker the tool sets on the guest, checked with
`ExecCondition=` - rather than giving the guest a different `keyd` config, or
teaching `tools/build-vm-image.sh` to strip `keyd` out of the image it
builds. This is TASK-166's replacement for the first version of this
decision, which used `ConditionVirtualization=!vm`; the trade-off below
records why that version had to change.

### Why

The "Key remapping with keyd" decision above chose `keyd` specifically
because it remaps at the evdev layer, below the compositor, so every
consumer - Sway, the console, the greeter, XWayland - inherits one swap
instead of four independent ones that can drift. `tools/build-vm-image.sh`
(see "Building the base image with the repository's own installer") builds
the VM base image by running the real, unmodified `03-system.sh` and
`04-desktop.sh`, so `apply-config.sh` installs and enables that exact `keyd`
config inside the guest too - correct in isolation, and the reason a guest
booted from this image swapped its own physical keyboard just as reliably as
bare metal.

The trouble is what "below the compositor" means once the compositor is
running a VM. `~/.local/bin/vm` (see "Virtual machines with qemu alone")
presents the guest a `virtio-keyboard` device. QEMU is itself a Wayland
client of the host's Sway, so by the time a keypress reaches QEMU, the host's
own `keyd` has already swapped it - Sway never sees an unswapped keycode to
begin with. QEMU forwards that already-swapped keycode into the guest
unchanged. If the guest's own `keyd` is also active, it swaps the same key
a second time, and the two swaps cancel: the user is left with an unswapped
keyboard precisely in the one place TASK-40 says it should be swapped. This
reads identically to "the fix never applied" while actually being "the fix
applied twice."

**Why a marker-based `ExecCondition` over the alternatives:**

- **A different config baked into the image at build time** would need
  `tools/build-vm-image.sh` to diverge from the real install stages somewhere
  after `04-desktop.sh` runs - exactly the kind of parallel path the previous
  decision rejected `install.sh` itself for needing. It would also need
  re-applying by hand (or by another special case) every time `sync.sh` runs
  inside the guest, since `sync.sh` would otherwise reinstall the ordinary
  swapped `default.conf` and silently undo the fix on the next boot.
- **Stripping `keyd` from the guest entirely** (uninstalling it, or excluding
  it from the image) throws away the one thing that still legitimately needs
  it if this repository is ever installed as a VM's *only* OS, driven by a
  host with no swap of its own - exactly the case this decision now handles
  correctly rather than trading away.
- **A condition on the unit** keeps the package, the config file and the
  `systemctl enable` identical in every context - satisfying the "one source
  of truth" reasoning `keyd` was chosen for in the first place - while making
  whether it *starts* depend on a fact about the running machine, checked
  fresh on every start. That means it self-corrects if `sync.sh` is run
  inside a guest that has an older image's `keyd` already active, with no
  extra logic anywhere in the sync path.

**Why not `ConditionVirtualization`, which is what this decision originally
used:** it can only report the *hypervisor class* - kvm, qemu, and so on -
which is identical whether the running machine is a nested guest of this
repository's own `~/.local/bin/vm` or a top-level VM running this desktop as
its only OS with no host-side `keyd` upstream of it. Those two need opposite
behaviour, and `ConditionVirtualization` cannot tell them apart, because
"is this a VM" was never the question that mattered - "did something already
swap these keys before they reached me" was, and only the second machine can
answer no. `ExecCondition` checks the actual fact instead of a proxy for it:
`~/.local/bin/vm` tags every guest it launches with
`-smbios type=1,family=arch-repo-vm-guest`, readable unprivileged inside the
guest at `/sys/class/dmi/id/product_family`, and the override skips starting
`keyd` only when that field carries the marker. Nothing else sets it, so its
presence means specifically "this machine is one of this repository's own
nested guests" - a top-level VM, or a guest built some other way, now takes
the same path as bare metal. `checks/session.sh`'s TASK-40 section checks the
same marker rather than `systemd-detect-virt`, for the same reason: "keyd is
not running" is the correct state on one of this repository's own nested
guests and the wrong one everywhere else, and the check has to ask the
question that is actually true rather than one merely correlated with it.

### Trade-off

**A guest not launched by `~/.local/bin/vm` - built some other way, or
receiving the same pre-swapped-keycode arrangement from a different tool -
is not recognised**, and gets the bare-metal behaviour (`keyd` starts and
swaps again) rather than the suppressed one. This repository only builds and
launches guests one way, so nothing here currently produces that situation;
if a second guest-launching path is ever added, it would need to set the
same marker or this decision would need revisiting. A machine for which
neither answer fits can still override the unit in
`/etc/systemd/system/keyd.service.d/`, the same escape hatch `/etc/keyd/local`
gives machine-specific keyd bindings elsewhere.

**Not verified against a real running VM guest.** The systemd unit merge was
checked with `systemd-analyze verify --root=...` against a throwaway root
carrying only `keyd.service` and this drop-in, which confirms the directive
parses and applies with no error from the override itself - `systemd-analyze`
got past parsing straight to complaints about the throwaway root's missing
`sysinit.target` and missing `/usr/bin/keyd`, neither of which involves this
change. The marker-absent path (this fix's actual motivating scenario, a
top-level VM) was verified live: on a machine `systemd-detect-virt` reports as
`kvm`, with no `arch-repo-vm-guest` marker set, `keyd.service` previously
failed its start condition and left the keyboard unswapped; after this
change it starts and the swap works. The marker-present path - a real
keypress on a real host, through a real `vm`-launched guest, observed with
`keyd monitor` or `keyd listen` inside the guest the way TASK-40 itself was
verified - was not exercised in this environment and is a real gap between
this decision and TASK-40's own standard of evidence.

---

## Power profiles switch through a daemon, for privilege rather than scheduling

**Decision:** Switch the CPU power profile (Performance/Balanced/Power Saving)
through `power-profiles-daemon` and `powerprofilesctl`, opened from one rofi
menu that both the battery module (laptop) and a new `custom/power-profile`
module (desktop, or any machine with no battery) share.

### Why

A dedicated power-profile button on the bar was rejected before it was ever
drawn: on a laptop it would sit next to the battery module, both about power,
cluttering the bar for no reason a single click can't already cover. So the
battery module's own click opens the profile menu instead, and a machine with
no battery hardware gets a second module - a plug/lightning glyph - that
opens the identical menu. Exactly one of the two is ever visible on a given
machine: `battery` is already invisible with no hardware (Waybar's own "No
batteries" behaviour), and the new module hides itself, the same way, when a
battery *is* present. Neither needs to know what kind of machine it is
running on; each only has to check for a battery.

The first plan for what actually applies a profile was no daemon at all - a
plain script writing `energy_performance_preference` and `platform_profile`
directly, in the shape `theme`/`sounds`/`wallpaper` already use elsewhere in
this setup: set it, leave it, no resident process. That does not survive
contact with what those sysfs attributes actually are: root-only writes. A
script-only approach would mean building a privilege-escalation mechanism of
our own - a udev rule loosening permissions on those specific attributes, or
a sudoers/polkit rule - rather than using the one already vetted for exactly
this: run as root, and authorise a client's request over D-Bus via polkit.
`power-profiles-daemon` is a daemon for that reason alone, not because
switching a profile is ongoing work; it is event-driven, not polling, and its
own real dependencies (`polkit`, `upower`) are already installed here for
other reasons.

### Where the state is shown, not just changed

rofi's `-mesg` widget is never placed by this repository's theme -
`config.rasi` does not list `message` among a window's `children`, so text
passed via `-mesg` is accepted and silently never drawn (see the
`scripting-traps` skill). So the charge percentage and time remaining - the
detail a click on the battery module used to reveal by toggling
`format-alt` - now live in the rofi *prompt* instead, and which profile is
currently active is marked directly in a row's label ("Balanced (current)"),
the same idiom `~/.local/bin/bluetooth` already uses for "is bluetooth on".
Both are widgets the theme actually places.

### Trade-off

The battery module's format-alt charge/time toggle is gone: that detail now
takes one more click (open the menu) to see, rather than a click that stayed
on the battery module itself. Traded for one shared control instead of two
separate ones fighting for the same bar space.

No GNOME integration, and no reaction to ACPI thermal events - both real
things `power-profiles-daemon` can do that this setup does not use. Neither
matters here: nothing else on this desktop consumes its D-Bus service, and a
manual three-way switch is what was asked for.

### Alternatives considered

**TLP.** Manages more hardware surface overall - USB autosuspend, PCIe ASPM,
disk APM, per-AC/battery charge thresholds - but is a static config file
re-applied on AC/battery transitions, not a live "pick one of three modes and
it takes effect now" tool. Making it behave like a three-way switch would
mean scripting on top of a tool never shaped for that, where
`power-profiles-daemon` already exposes exactly `performance` / `balanced` /
`power-saver` through one command.

**A privilege mechanism built by hand** (a udev rule or sudoers entry granting
a plain script write access to the relevant sysfs attributes). See "Why"
above - rejected because it means owning a security surface the daemon
already solves, correctly, for the cost of 141.95 KiB and one small
dependency (`libgudev`).

**A separate power-profile button.** Rejected before being built - see "Why"
above.

---

## The build has a name, and a landing page

**Decision:** Call the system **Swaystone**, and give it one static landing page
under `site/`, published to GitHub Pages by `.github/workflows/pages.yml`.

Until now the repository presented itself as one person's dotfiles. That
undersells what it is. The system is an argument - that a desktop can be light
enough to feel instant *and* considered enough to want to live in, and that the
way to get there is to be deliberate about what earns a place rather than to
own as little as possible. An argument needs somewhere to be made.

### Why

**A name makes it a thing rather than a directory.** "My Arch build" cannot be
recommended, searched for, or referred to in its own repository without
circumlocution. Swaystone carries the compositor it is built on and reads as a
single object - cut, not assembled - which is the closer metaphor for a system
whose whole premise is that its complexity is chosen.

**Static HTML, and no build step.** The page is `index.html`, one stylesheet,
one script and two images. There is no generator to keep working, no
`node_modules`, nothing to install in CI, and no reason the page cannot be
opened straight off disk. A repository arguing for restraint should not need a
toolchain to describe itself.

**Published from `site/`, by Actions, not from `docs/`.** `docs/` already holds
four unrelated things - the manual's sources, the software record, theme
references and wallpaper notes - none of which is a website. Serving that
directory would publish all of it and constrain how it is organised.
Uploading `site/` as a Pages artifact keeps the published surface exactly the
files written to be published.

**The palettes are generated, not transcribed.** `tools/site-themes.py` writes
`site/themes.js` from `setup/dotfiles/.chezmoidata/themes.toml` - the same file
the desktop templates its own colours out of - and the page lets a visitor
apply any of the eleven to the page itself. Copying eleven palettes into a
stylesheet by hand would have been the same failure this repository keeps
finding, one surface further out: something that looks right, and quietly stops
being true.

### Trade-off

**The page asserts numbers, and nothing fails when they drift.** Idle memory,
package count, shortcut count, theme count and boot time are all on the page
and all checkable from the repository, but there is no `checks/site.sh` holding
them to it. `site/README.md` records where each figure comes from so the next
reader can re-derive them. If they start going stale, that check is the fix -
this is exactly the shape of problem the other five were written for.

**Screenshots are a snapshot of an appearance that changes.** The two images
were staged on a throwaway headless output rather than captured off a real
screen, so they show an uncluttered session rather than whatever was open; the
recipe is in `site/README.md` and in the `desktop-verification` skill. They
still have to be re-taken when the desktop's look changes, and nothing will
announce that they should be.

### Alternatives considered

**A README with better screenshots.** Cheaper, and it stays where people
already look. Rejected because GitHub renders a README as documentation for
people who have already decided to look at the repository; the thing missing
was something to send to someone who has not.

**Jekyll or GitHub Pages' default build.** Rejected: it means a Gemfile, a
theme and a build to keep working, in exchange for markdown-to-HTML that is not
needed for a single page. The manual already has its own renderer for the one
place markdown genuinely helps.

**Publishing the manual alongside the landing page.** Deferred rather than
rejected. `tools/manual.sh` already builds `docs/manual/` into one HTML page,
and putting it on the same site is a small change to the workflow. It was left
out to keep the first version to one page with one purpose; the manual is
linked to on GitHub in the meantime.

**Other names.** *Swayze* was the most memorable and was rejected for being a
real person's name, which makes it a joke rather than a project. *Swayve* and
*Swayde* both read well and both say more about surface than about substance.
*Swaystone* was chosen for the half the others lack: solidity, which is the
half of the pitch - stable, no dropped frames, never falls over - that the
lightness half tends to overshadow.

## The editor's first plugin, and the lockfile that had been waiting for it

**Decision:** Install exactly one Neovim plugin —
[render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim)
— through `vim.pack`, pinned by a tracked `nvim-pack-lock.json`, installed at
apply time by a `run_onchange_` script, and coloured from the selected theme
rather than from its own defaults.

### Why

A lot of what gets written on this machine is markdown: every Backlog task, the
manual, this file. Read raw, a link is four times longer than the words it
labels and a heading is a row of hashes. The plugin draws headings, bullets,
links, tables, checkboxes, code panels and callouts, and **un-draws the line
the cursor is on** so that line is ordinary source again — its *anti-conceal*
feature, and the entire reason it was chosen over the alternatives below. There
is no preview window, no second mode and nothing to keep in sync; the buffer is
both the document and the source, depending on where the cursor is.

The prerequisites were already met, which is most of why the cost is small.
Neovim bundles the `markdown` and `markdown_inline` parsers *with* highlight
queries, so the guard in `init.lua` — start treesitter only where both a parser
and a query exist — already turned it on for markdown buffers.

**Measured on this machine, not estimated,** as the mean of nine headless runs
each:

| | Without | With |
| --- | --- | --- |
| Startup, no file | 11.5 ms | 14.4 ms |
| Startup opening a markdown file | 33.1 ms | 48.2 ms |

Three milliseconds on every start, and about fifteen more the first time a
markdown buffer is drawn. The header of `init.lua` sets the budget at the 15 ms
a bare Neovim takes; with the plugin, startup is still inside it.

### Why vim.pack, and why the lockfile is the point

`vim.pack` ships with Neovim 0.12. Installing lazy.nvim or packer to manage one
plugin would mean taking a dependency in order to take a dependency, and the
whole configuration exists to show that 0.12 no longer needs one.

The lockfile is what makes this reproducible rather than merely convenient.
`nvim-pack-lock.json` records the exact revision, it is tracked here, chezmoi
writes it, and `vim.pack` reads it on its first call — so every machine gets
that commit rather than whatever the version range resolved to on the day it
was installed. That is the same argument as `npm ci` for the language servers
and an explicit install reason for pacman packages, one layer further out.
`init.lua` had described this arrangement in the future tense since it was
written; this is the change that made it a description.

Installation is a `run_onchange_` script running `nvim --headless`, hashing both
the lockfile and `plugins.lua`, for the reason the language-server script
already learned: the hash is what connects a script to the files it acts on, and
hashing only one of the two means one kind of change silently does nothing.
Without the script the first `nvim` on a new machine would clone from GitHub
before showing a buffer — which is the install finishing somewhere other than in
the installer.

### Why the theme names every group rather than the wrong ones

The plugin registers its highlight groups as links to groups it hopes exist:
`DiffText` for the level-one heading background, `DiffAdd` for level two. This
theme gives both of those a foreground and no background, so headings would have
arrived as one yellow band and five invisible ones. That much is an ordinary
override.

Naming *all* of them is the less obvious half. `:colorscheme` begins with
`highlight clear`, and the plugin re-derives only its computed colours
afterwards, not its base links — so a group the theme does not name is correct
until the theme is switched and silently gone after. Exactly the failure this
repository keeps finding.

One palette rule came out of this and is worth stating: **`tertiary` is not safe
as a foreground.** On the light themes it is a background — `#c9c9c2` on
`paper`, the focused workspace disc with dark text on it — so a heading painted
with it would be legible on eight themes and invisible on three. Headings use
`accent` and the ANSI colours instead.

### Trade-off

This is the first thing on the built machine fetched from GitHub at install time
rather than from a package manifest; there is no packaged version in the Arch
repositories, and the AUR was ruled out under TASK-43. So it is a plugin's
worth of code that nobody here reviews, bounded in two ways: the version range
cannot cross into a new major, and the revision is pinned and committed.

A machine with no network that has never installed it gets an editor without
markdown rendering rather than an editor that will not start — `vim.pack.add()`
is called inside a `pcall`, and the install script warns rather than aborting.
Both halves fail in the direction of a working editor.

Signs are turned off for headings and code blocks. `signcolumn = 'number'`
(TASK-170) means a sign does not sit beside the line number, it replaces it, so
the defaults would have spent the gutter that task narrowed on a second marker
for something an icon and a full-width band already announce.

### Alternatives considered

**markview.nvim** does the same job and is visually closer to Typora, with
rendered rules, block quotes and LaTeX. It is heavier and more opinionated;
render-markdown is the smaller bet, and its anti-conceal is the feature that was
actually wanted.

**Neovim's own conceal, with no plugin at all.** The bundled `markdown_inline`
queries conceal emphasis markers and link destinations, and `conceallevel=2`
with `concealcursor=''` already reveals them on the cursor's line — so a
meaningful part of this could have been had for two options and no dependency.
What it cannot do is headings, bullets, checkboxes, tables, code panels or
callouts, which is most of what makes a document look like a document.

**A preview in a browser** (`grip`, `glow`) was not seriously considered: a
second window, kept in sync by hand, that cannot be edited.

---

# Guiding principle

When evaluating future changes, prefer the option that best preserves this balance:

> **Minimal enough to stay fast and understandable, automated enough to be reproducible, and practical enough to be pleasant to use every day.**

New tooling should earn its place by solving a real problem. The goal is not to make the smallest possible Arch installation; it is to make a system whose complexity is intentional.
