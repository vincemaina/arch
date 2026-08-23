# Installing on a new machine

This chapter takes you from a blank disk to a running desktop. It covers what
`install.sh` does and what to expect on the way; it does not re-derive why the
disk is laid out this way or why each stage runs where it does — that
reasoning lives in [DECISIONS.md](../../DECISIONS.md) and
[FLOW.md](../../FLOW.md).

## What you need first

- An Arch Linux installation ISO, booted on the target machine. Download it
  from the official Arch download page.
- A **UEFI** machine, with **Secure Boot turned off** in firmware. This
  installer does not support legacy BIOS, and `03-system.sh` installs an
  unsigned boot binary (`bootctl install`) — a machine with Secure Boot on
  will finish the install and then refuse to boot from it.
- A target disk you are prepared to lose everything on. There is no
  confirmation beyond the one the installer itself asks for (see below).
- A network connection. The live ISO needs one to fetch packages; a wired
  connection normally works without any setup. On wifi, connect with `iwctl`
  first — see below.
- `git`, which is not on the live ISO by default: `pacman -Sy git`.

On wifi, connect before doing anything else:

```bash
iwctl station wlan0 connect "your-network-name"
```

`iwctl device list` shows the interface name if it isn't `wlan0`.
`ping -c 3 archlinux.org` confirms either kind of connection is up.

Clone the repository onto the live system and run the installer from inside
it:

```bash
git clone https://github.com/vincemaina/arch.git Arch
cd Arch
```

## This erases the target disk

`install.sh` partitions and formats whatever disk you give it. There is no
undo. `01-disk.sh`, the stage that does this, will not proceed until you type
the word `ERASE` at its prompt — but everything before that point, including
the identity wizard, has already run, so do not treat that prompt as your
only chance to stop and check the disk name.

Find the right device name with `lsblk` before you run anything. A
virt-manager VM commonly presents its disk as `/dev/vda`. A physical NVMe
drive looks like `/dev/nvme0n1` instead, and matters for how you write the
device name in commands you type by hand — see the ESP/root naming note
below, which the installer handles for you but which you should recognise if
you ever need to act on the partitions directly.

```bash
./install.sh /dev/vda        # or /dev/nvme0n1 on real hardware
```

The installer detects the nvme-style naming itself: a device name ending in a
digit gets `p1`/`p2` partition suffixes (`/dev/nvme0n1p1`), while one that
does not gets `1`/`2` directly (`/dev/vda1`). You do not need to work this out
by hand for the install to succeed — it only matters if you go looking for
the partitions afterwards.

## The identity wizard

Before anything touches the disk, `setup/install/00-wizard.sh` asks for this
machine's identity: username, hostname, timezone, locale, keymap, and the git
name and email used for commits made on this machine. It runs on the live
ISO, against your repository checkout, and is the last point at which an
answer can still be changed — everything after it erases the disk.

Every existing value in `setup/install.conf` is offered as the default, so
**pressing Enter through the whole wizard changes nothing**. This matters if
you are re-running the installer on a machine whose `install.conf` is already
correct: you can accept every default without retyping it.

Answers are checked against the live system, not just a pattern: a timezone
has to be a real zoneinfo file, a locale has to exist in `/etc/locale.gen`,
a keymap has to exist under `/usr/share/kbd/keymaps`. Type `?` at any prompt
to list valid answers, or `?text` to search them.

Two ways to skip the wizard entirely and use `install.conf` exactly as
committed:

```bash
./install.sh --no-wizard /dev/vda
```

or simply run the installer with no terminal on stdin — a scripted or piped
build skips the wizard automatically, with no flag needed.

**Passwords are never asked here and never stored in the repository.** Stage
03 (`03-system.sh`) prompts for the root password and the new user's password
interactively, at the point the accounts are created. Mistyping one — so that
the two entries disagree — re-asks rather than ending the install; it used to
end it, after the disk had already been erased.

## If a run stops partway

Any stage after the first can fail, and the target's filesystems are left
mounted on `/mnt` when one does — `install.sh` only unmounts them on the way
out of a successful run.

Simply run `install.sh` again. Stage 01 clears those leftovers itself, after
you confirm with `ERASE` and before it writes anything. Earlier this was the
point at which a second attempt failed, with an error saying the disk's
partitions were in use: the disk was fine, and what was holding it was the
previous run. If something the installer cannot clear is holding the disk, it
now says what.

## The five stages

`install.sh` runs five numbered stages in order, moving from the live ISO
into a chroot on the target machine partway through. Each stage's exact
responsibilities, and the two-environment mechanics that make stage
scripting easy to get wrong, are documented in [FLOW.md](../../FLOW.md) —
read that before touching any stage script. In brief:

1. **Disk** (`01-disk.sh`) — partitions the disk and creates the Btrfs
   subvolumes described below.
2. **Base system** (`02-base.sh`) — `pacstrap`s the base package set and
   writes `/etc/fstab`.
3. **System configuration** (`03-system.sh`) — timezone, locale, hostname,
   the user account, sudo, NetworkManager, and the bootloader. Asks for the
   root and user passwords here.
4. **Desktop** (`04-desktop.sh`) — installs the desktop and development
   package sets, then applies machine-wide configuration (zram, earlyoom,
   keyd, greetd, the console keymap, the boot hooks).
5. **Dotfiles** (`05-dotfiles.sh`) — applies your user configuration with
   chezmoi, then switches the login shell to zsh once its config is
   confirmed to parse.

When it finishes, `install.sh` unmounts the new system and powers the machine
off. Remove the installation media before starting it again.

## Disk layout

The disk ends up as GPT with two partitions:

| Partition | Size | Filesystem | Mounted at |
| --- | --- | --- | --- |
| ESP | 1 GiB | FAT32 | `/boot` |
| Root | remaining space | Btrfs | `/`, `/home`, `/.snapshots` |

The Btrfs partition is split into three subvolumes — `@`, `@home`,
`@snapshots` — mounted at `/`, `/home` and `/.snapshots` respectively, all
with `compress=zstd`.

Two things about this layout are deliberate, not oversights:

- **There is no separate `/home` partition.** `@home` is a subvolume, not a
  physical partition, so root and home share the same free space rather than
  each being boxed into a size chosen in advance.
- **There is no full-disk encryption.** This build targets a home
  development machine where the operational cost of encryption is judged not
  worth it. Nothing about the layout rules it out later on hardware where
  that trade-off is different.

Both are explained at more length, with the alternatives that were
considered, in [DECISIONS.md](../../DECISIONS.md).

## First boot

systemd-boot shows a one-second boot menu (`arch.conf` is the default entry;
`arch-fallback.conf` boots the same kernel with a fallback initramfs if
something is wrong with the normal one). After that, greetd starts ReGreet on
the first virtual terminal. The other virtual terminals still carry plain text
consoles — **`Ctrl+Alt+F2`** reaches one if the graphical session will not
start.

Log in, and the session should come up through uwsm into Sway with a bar,
notifications, idle handling and a running authentication agent. If you
instead get a bare compositor with none of that, the session was not started
through uwsm — see the troubleshooting notes in
[Keeping it healthy](10-keeping-it-healthy.md).

First things to do on a freshly installed machine:

- Run `./checks/session.sh` from the repository. It is read-only and checks
  swap, the OOM handler, session units, the boot path, the wallpaper and the
  selected theme against what the repository intends. If the screen is
  locked when you run it, its screenshot check will wait rather than fail —
  see [Keeping it healthy](10-keeping-it-healthy.md) for why.
- Check which theme and wallpaper style are active with `theme --current` and
  `wallpaper --current`. Git no longer tells you which one a machine is
  wearing; these commands do.
- Work through the manual checks `checks/session.sh` prints at the end —
  volume and playback keys, both screenshot bindings, a polkit prompt, and
  the OOM handler under real memory pressure. None of these can be verified
  by a script.

## Real hardware versus a VM

This repository has so far been built and rebuilt almost entirely inside a
KVM/QEMU virtual machine, and a handful of things observed there are
specifically artefacts of that environment rather than of the build itself.
Where the outcome on real hardware has not actually been tested, this section
says so rather than promising it will just work.

**The Caps Lock LED follows caps state on real hardware, but not on a VM.**
This setup remaps Caps Lock into a scroll layer through keyd
(`setup/system/keyd/default.conf`): tapping it briefly toggles caps, and on a
physical keyboard the indicator lights to match. Both `/sys/class/leds` caps
entries — the real i8042 keyboard's and keyd's own virtual one — flip together
across a tap, which also shows that sway can set LED state on a device keyd
holds an exclusive grab on. A grab blocks other readers; it does not block
writing an LED.

On a virtual machine none of that is visible, because an emulated i8042
keyboard has no lamp attached and the light on your real keyboard belongs to
the host, which is told nothing about caps state inside the guest. That was
once recorded here as an unresolved limitation, with a note that real hardware
had never been tried; it has been now, and it behaves.

**GPU rendering has been an open question on this VM, and its answer changed
during development.** Early in this repository's history the VM's virtio GPU
was presented with no 3D acceleration, and Sway ran entirely software-rendered
through llvmpipe — usable, but a poor basis for judging how the compositor
*feels* (motion, animation, smoothness), and implicated in at least one
compositor crash. Enabling 3D acceleration on the hypervisor side (in
virt-manager: Video set to `virtio` with 3D acceleration, Display set to
`spice` with OpenGL) fixed it — the kernel now reports `+virgl`, and
`checks/session.sh` reports zero software-rendering log lines rather than
skipping past known-expected ones. `checks/session.sh` deliberately tells the
two situations apart: software rendering on a virtio GPU reporting `-virgl`
is reported as expected (a VM configuration issue, not fixable from inside
the guest), while software rendering on anything else is treated as a real
failure. On real hardware with a normal GPU, this whole question does not
apply — but there is no measurement from this repository's history of that
happening, only reasoning about what the check would report.

**Enabling GPU acceleration inverted the mouse cursor, and the fix is
believed VM-specific but not confirmed either way.** Once the virtio GPU took
over cursor drawing, the hardware cursor plane rendered the pointer upside
down. The fix, `WLR_NO_HARDWARE_CURSORS=1` in
`setup/dotfiles/dot_config/environment.d/10-appearance.conf`, makes wlroots
composite the cursor itself instead of handing it to the GPU. This setting
ships in every build from this repository, VM or not — it has not been
tested on real hardware, and if the inverted-cursor bug really is unique to
virtio's cursor plane implementation, the setting is simply a no-op there
rather than a regression. Do not assume it can be safely removed without
testing first.

**A guest-agent package was tried and removed; it is not part of the current
build.** A SPICE guest agent was installed at one point specifically to try
to fix the inverted-cursor problem above. It did not fix it — the actual fix
was `WLR_NO_HARDWARE_CURSORS`, above — and the package was later removed once
that was established, along with the manifest comment that had wrongly kept
describing the untested theory as though it were the outcome. It is not
declared in `setup/packages/*.txt` today. If you find yourself tempted to add
a SPICE or QEMU guest-agent package to fix a VM-only problem, check
`DECISIONS.md` first for whether this has already been tried.

If you build this on real hardware and observe something that differs from
what is written here — the Caps Lock LED behaving correctly, rendering
working differently, the cursor fix being unnecessary or insufficient —
that is new information this repository does not yet have. It belongs in
`DECISIONS.md`, next to the VM-side observations it would be replacing or
confirming.
