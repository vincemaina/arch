# Software this setup installs

One hundred and sixteen packages are declared across [`setup/packages/`](../../setup/packages/).
This document accounts for every one of them: what it is for, where its
rationale lives, and what it costs on the machine.

## What lives where

Three places already hold part of the answer, and this document is deliberately
the fourth rather than a replacement for any of them.

| | Answers |
| --- | --- |
| [`DECISIONS.md`](../../DECISIONS.md) | Why a technology was chosen, what was rejected, and what it costs in trade-offs. The rationale record. |
| The manifest comments in `setup/packages/*.txt` | Why a specific package line is there, next to the line itself, where someone editing the manifest will read it. |
| [`setup/packages/README.md`](../../setup/packages/README.md) | What the manifests are and the top-level-only philosophy. |
| **This document** | The complete roll call — every declared package accounted for — plus **measured** resource cost, which none of the above carry. |

So a package with a `DECISIONS.md` section is listed here with a pointer, not a
summary. Restating a rationale in a second place is how two copies start
disagreeing.

## The entry format

A tool that needs an entry of its own gets these five headings, in this order.
Anything missing should say so rather than be omitted, because a gap that is
named can be filled and a gap that is silent looks like a decision.

```markdown
### package-name

**Problem.** What goes wrong without it.
**Choice.** Why this one.
**Alternatives.** What else was considered, and what ruled each out.
**How it works.** Enough mechanism to debug it when it misbehaves.
**Cost.** Disk from `pacman -Qi`; memory and CPU measured if it runs resident.
```

If the honest answer to **Choice** is "it was the obvious package and nothing
else was looked at", write that. It is a true statement about the state of the
decision, and it tells the next reader that re-evaluating is cheap. A rationale
invented after the fact is worse than no rationale: this repository has already
been bitten once by a comment that described a hypothesis as though it were an
outcome.

## How the figures were measured

Every number below came from this machine on **2026-08-21**, except the figures
for packages declared after that date — `cliphist`, `cava`, `mpv`/`mpv-mpris`/
`yt-dlp`, `firefox`, `lazygit` and `openssh` — which are dated **2026-08-22**
where they appear. Nothing is quoted from a benchmark elsewhere.

The reference machine is a **KVM guest: 4 vCPU of an Intel i7-10700, 3.8 GiB
RAM, kernel 7.1.8, software rendering.** That matters. The repository targets a
16 GB machine but has to work unchanged here, and a daemon that is free on the
larger machine may not be on this one. Figures from a laptop with a real GPU
will differ, particularly for the compositor.

Three sources, all readable without root:

```bash
# Disk, per package
pacman -Qi <package> | grep 'Installed Size'

# Memory and cumulative CPU, per unit, from systemd's own cgroup accounting
systemctl show <unit> -p MemoryCurrent --value
systemctl show <unit> -p CPUUsageNSec --value
systemctl show <unit> -p ActiveEnterTimestampMonotonic --value   # to divide by

# Proportional set size, per process — shared pages counted once
cat /proc/<pid>/smaps_rollup
```

Ask each property in a **separate** `systemctl show` call. Requesting several
at once returns them in systemd's order, not the order asked for, and reading
them positionally silently transposes the values — which produced a first draft
of the table below claiming several daemons used 17 GB on a 3.8 GB machine.

Three caveats on the numbers, all of which make them upper bounds rather than
understatements:

- `MemoryCurrent` is the cgroup total, so it includes page cache charged to the
  unit as well as anonymous memory.
- `CPUUsageNSec` is cumulative since the unit last started, so the percentages
  are long-run averages, not what the process is doing right now. A unit
  restarted recently is measured over a shorter window.
- `/proc/PID/smaps_rollup` is unreadable without root for processes whose
  dumpable flag is cleared — anything running as root, and the compositor.
  Those rows use resident set size from `ps`, which counts shared pages in
  full and therefore overstates.

### What the session costs at rest

| Unit | Memory | CPU, long-run average |
| --- | ---: | ---: |
| sway (RSS, `ps`) | 143.8 MiB | 5.2% of one core |
| waybar | 18.5 MiB | 0.25% |
| autotiling | 15.8 MiB | 0.014% |
| pipewire | 10.0 MiB | 0.030% |
| pipewire-pulse | 11.9 MiB | 0.028% |
| wireplumber | 9.6 MiB | 0.004% |
| polkit-agent (polkit-gnome) | 9.1 MiB | 0.001% |
| gvfs-daemon | 12.7 MiB | < 0.001% |
| xdg-desktop-portal | 3.8 MiB | 0.001% |
| xdg-desktop-portal-gtk | 7.4 MiB | 0.004% |
| xdg-desktop-portal-wlr | 1.0 MiB | 0.001% |
| dbus-broker (user) | 1.5 MiB | 0.001% |
| mako | 1.2 MiB | 0.000% |
| swayidle | 0.4 MiB | < 0.001% |
| cliphist@text + cliphist@image (2026-08-22) | 2.9 MiB | < 0.001% |

| System unit | Memory | CPU, long-run average |
| --- | ---: | ---: |
| NetworkManager | 18.0 MiB | 0.002% |
| systemd-journald | 15.6 MiB | 0.002% |
| systemd-udevd | 15.1 MiB | 0.004% |
| keyd | 35.5 MiB | 0.006% |
| greetd | 6.6 MiB | < 0.001% |
| polkitd | 2.5 MiB | 0.002% |
| dbus-broker (system) | 2.1 MiB | 0.001% |
| systemd-logind | 1.5 MiB | 0.001% |
| **earlyoom** | **1.0 MiB** | **0.004%** |

Two readings worth taking from that table.

**The compositor is the cost — or was.** The session-cost table above still
reports the 2026-08-21 sway figure of 143.8 MiB RSS at 5.2% of a core, measured
while the hypervisor presented the virtio GPU without 3D acceleration, so every
frame went through llvmpipe on the CPU. **That is no longer this machine's
state.** `DECISIONS.md` → "The VM rendered in software, and no longer does"
records that 3D acceleration was enabled on the hypervisor on 2026-08-22: the
kernel now reports `+virgl +edid` with two capability sets, and `ps` shows sway
resident at roughly 68 MiB — well under half the figure above. The session-cost
table is not corrected here, because doing that properly means re-measuring
every row in it, not just sway's, and that is the general resource-cost pass
covered by a separate ticket. Read the sway row above as **history of a
software-rendered machine**, not as this machine's current cost, until that
pass happens.

**earlyoom is the cheapest insurance here.** 1.0 MiB and four thousandths of a
percent of one core, for the thing that keeps the machine responsive when it
runs out of memory. It is the worked example this document was asked for, and
the numbers are why the argument in `DECISIONS.md` → "earlyoom rather than
systemd-oomd" ends where it does: at this price the question is not whether the
protection is worth its cost, only which implementation behaves best.

Boot, measured with `systemd-analyze` on the same machine:

```text
866ms (kernel) + 1.720s (initrd) + 2.066s (userspace) = 4.653s
graphical.target reached after 2.061s in userspace
```

### What the whole declared set costs on disk

**1.51 GiB** (1541.2 MiB) across all 100 declared packages, currently
installed, from `pacman -Qi`, excluding dependencies. Re-derived on
**2026-08-23** against every package name in `setup/packages/*.txt` — all 100
found installed, 0 missing.

That last figure was taken on a **different machine** from every other number in
this document: the ThinkPad TASK-146 was done on, not the KVM guest described
above. For disk that is defensible — a package occupies the same space wherever
it is installed — but the comparison against yesterday's 1.49 GiB is looser than
it looks, because the two machines were not checked for matching package
versions and some of the 17.6 MiB difference is certainly upstream growth rather
than anything this repository did. Treat the trend as real and the exact delta
as approximate. It would not be defensible at all for the memory or CPU tables,
and none of those were touched.

The history, since the shape of the growth is more useful than the number: 1.13
GiB across 90 packages on 2026-08-21, then 1.49 GiB across 98 on 2026-08-22 —
almost entirely `firefox` (294.9 MiB) and `yt-dlp` (31.7 MiB) — and 1.51 GiB
across 100 today. Of the 17.6 MiB between yesterday and today, 5.41 MiB is the
two new packages (`bluez`, `bluez-utils`) and the remaining ~12 MiB is not
attributable from here — it is some mixture of upstream growth and the two
machines differing, and this document should not guess which. What is worth
keeping from it: **no figure in here is exact for long**, and the roll call is
the durable part, not the totals.

| Package | Installed |
| --- | ---: |
| firefox | 294.9 MiB |
| ttf-jetbrains-mono-nerd | 228.4 MiB |
| linux | 147.7 MiB |
| papirus-icon-theme | 111.5 MiB |
| noto-fonts | 106.8 MiB |
| nodejs | 61.3 MiB |
| mesa | 52.7 MiB |
| chezmoi | 39.9 MiB |
| yt-dlp | 31.7 MiB |
| intel-ucode | 31.4 MiB |

The five font and icon packages together are 466.7 MiB — 30.6% of everything
declared, down from 39% a day earlier only because firefox and yt-dlp grew the
denominator, not because fonts shrank — and cost nothing at runtime beyond what
is actually rendered. That is a fine trade to have made, but it should be a
known one: shrinking the install means looking here first, not at the daemons.

## Every declared package

`base.txt` is the core bootable system, `desktop.txt` the graphical session,
`dev.txt` the terminal and editing environment. Rationale column: **D** points
at a `DECISIONS.md` section, **M** means the manifest comments carry it next to
the line, **↓** means an entry below in this document.

### base.txt

| Package | Role | Rationale |
| --- | --- | --- |
| `base` | The Arch base meta-package. Pulls in the core userland; no files of its own | D: Arch Linux |
| `linux` | The kernel. Stock Arch, not `-lts` or `-zen` | ↓ |
| `linux-firmware` | Meta-package for device firmware blobs | ↓ |
| `btrfs-progs` | `mkfs.btrfs`, `btrfs subvolume`, `btrfs scrub` | ↓ |
| `networkmanager` | Network configuration daemon | D: NetworkManager |
| `sudo` | Privilege escalation for the `wheel` group | ↓ |
| `vim` | Editor available before the desktop manifest exists | ↓ |
| `git` | Cloning this repository, and daily use | D: Git |
| `openssh` | The SSH client. Declared explicitly so it cannot be silently pulled out from under `git@github.com` | D: No SSH key or agent is provisioned by the build |
| `intel-ucode` | Intel CPU microcode | D: Early microcode via the mkinitcpio hook |
| `amd-ucode` | AMD CPU microcode. Both are installed so one image boots either | D: Early microcode via the mkinitcpio hook |
| `zram-generator` | Creates `/dev/zram0` from `/etc/systemd/zram-generator.conf` | D: zram instead of a disk swapfile |
| `earlyoom` | Kills something while the machine is still usable | D: earlyoom rather than systemd-oomd |

### desktop.txt — compositor and session

| Package | Role | Rationale |
| --- | --- | --- |
| `sway` | The compositor | D: Sway, Wayland |
| `swaybg` | Draws the wallpaper. Restarted by `swaymsg reload` | ↓ |
| `swayidle` | Idle timeouts; drives `~/.local/bin/sway-idle` | ↓ |
| `swaylock` | Screen locker; colours templated from the palette | ↓ |
| `waybar` | The bar | D: Waybar, The bar reports and responds |
| `uwsm` | Wraps the compositor in systemd units | D: uwsm for session management |
| `greetd` | Authenticates and launches the session | D: A display manager, reversing an earlier decision |
| `greetd-regreet` | The login screen itself | D: … → Why greetd and ReGreet |
| `cage` | Kiosk compositor that hosts ReGreet | D: … → Why greetd and ReGreet |
| `foot` | Terminal emulator | D: Foot |
| `xorg-xwayland` | X11 compatibility. Not normally running | M — and read that comment before adding the first X11 app |
| `polkit` | Privilege authorisation. Declared, not inherited | D: polkit |
| `polkit-gnome` | The agent that draws the password prompt | D: polkit-gnome as the authentication agent |
| `mesa` | GL/EGL. Declared for the same reason as `polkit` | M, D: The VM rendered in software, and no longer does |
| `keyd` | Key remapping at the evdev layer | D: Key remapping with keyd |
| `autotiling` | Picks the split direction from the focused container's shape | M |

### desktop.txt — audio, portals, notifications

| Package | Role | Rationale |
| --- | --- | --- |
| `pipewire` | Audio server | D: PipeWire |
| `pipewire-pulse` | PulseAudio compatibility layer | D: PipeWire |
| `pipewire-audio` | `pw-play`, which is what makes the desktop's four sounds audible. Declared rather than inherited — it arrives as a dependency of `pipewire-pulse` above, and was marked "installed as a dependency", which is the state that lets a graph change remove it silently. Same reasoning as `polkit` and `mesa`. | D: The desktop's sounds are generated, not shipped |
| `wireplumber` | PipeWire's session manager — routing policy | D: WirePlumber |
| `pavucontrol` | Graphical mixer; opened by the bar's audio module | ↓ |
| `bluez` | `bluetoothd`, and a `bluetooth.service` this repository deliberately never enables | ↓ |
| `bluez-utils` | `bluetoothctl`: the pairing interface, and what the menu asks about devices | ↓ |
| `xdg-desktop-portal` | The portal front end | D: xdg-desktop-portal and xdg-desktop-portal-wlr |
| `xdg-desktop-portal-wlr` | Screencast/screenshot backend for wlroots | D: same |
| `xdg-desktop-portal-gtk` | File chooser dialogs that match everything else | D: Applications are made to match |
| `mako` | Notification daemon | D: Mako |
| `libnotify` | `notify-send`, and the client library | ↓ |

### desktop.txt — utilities

| Package | Role | Rationale |
| --- | --- | --- |
| `grim` | Screenshot capture | D: grim + slurp |
| `slurp` | Region selection for grim | D: grim + slurp |
| `wl-clipboard` | `wl-copy` / `wl-paste` | D: wl-clipboard |
| `cliphist` | Clipboard **history** — `wl-clipboard` only holds one entry | M, D: Clipboard history: cliphist behind rofi, two watchers, no auto-paste |
| `brightnessctl` | Backlight control, bound to the brightness keys | ↓ |
| `playerctl` | MPRIS control, and `playerctld` behind waybar's media module | D: Helper scripts declare what they call, The bar reports and responds |
| `mpv` | Plays a URL and exposes MPRIS, so the bar and playback keys control it | ↓ |
| `mpv-mpris` | The plugin that makes `mpv` visible over MPRIS. Without it mpv plays and nothing on the desktop can see it | ↓ |
| `yt-dlp` | Resolves a pasted YouTube/SoundCloud link for mpv to play | ↓ |
| `cava` | Terminal spectrum display, reading whatever is audible from the default output's monitor | ↓ |
| `xdg-user-dirs` | Creates `~/Pictures` and friends | ↓ |
| `gvfs` | Removable and network volumes for GIO, so a USB stick appears in a Save As dialog | M, D: GVFS |
| `yazi` | The terminal file manager, and the default one `$mod+e` opens. Selected by `explorer --use`, so which key reaches it is machine-local | M, D: No graphical file manager, reversing an earlier decision; D: Both file managers stay, behind `explorer --use` |
| `thunar` | The graphical file manager, on `$mod+Ctrl+e` by default. Kept for what yazi cannot do at all — thumbnails, bulk rename, dragging a file into another window, a sidebar of drives | ↓ |
| `tumbler` | Thumbnails for Thunar. Declared, not left optional — its absence is what made the last Thunar useless | ↓ |
| `udisks2` | `udisksctl`, behind yazi's mount manager on `M` — mounts and unmounts a drive without root | ↓ |
| `imv` | Image viewer | M |
| `btop` | System monitor | D: btop |
| `firefox` | **The browser.** What `$mod+b` opens and where every link goes, since TASK-183. Turned down and given Vimium by `/etc/firefox/policies/policies.json` | M, D: The everyday browser is firefox; D: Firefox is configured by enterprise policy, not by a profile file |
| `qutebrowser` | Web browser, the everyday one until TASK-183. Still on `browser --use qutebrowser` | D: The everyday browser is firefox |
| `vimb` | Minimal WebKitGTK browser, trialled against qutebrowser and not chosen either. Still on `browser --use vimb` | D: The everyday browser is firefox; D: Launching an application gives you a new instance of it |
| `rofi` | The launcher — one prompt, several sources via `combi` | M, D: rofi, reversing an earlier decision |
| `rofi-calc` | Calculator source for that prompt, via libqalculate | M |
| `fastfetch` | System summary, run manually | M |

### desktop.txt — virtual machines

| Package | Role | Rationale |
| --- | --- | --- |
| `qemu-system-x86` | The emulator. Runs the guest, with KVM doing the actual work | M, D: Virtual machines with qemu alone, and clones that cost nothing |
| `qemu-img` | Creates the disks, and creates a clone as an overlay rather than a copy | ↓ |
| `qemu-ui-gtk` | The window the guest is drawn in. GTK over SDL because `gtk3` is already installed, so the difference is `vte3` at 1.8 MiB | ↓ |
| `qemu-hw-display-virtio-vga` | The guest's graphics card. A **separate package** from the emulator — without it the device is simply absent | ↓ |
| `qemu-hw-display-virtio-vga-gl` | The same card with 3D acceleration. A subclass of the above, so it needs it present to register at all | ↓ |
| `qemu-hw-display-virtio-gpu` | The base GPU device the VGA ones are built on | ↓ |
| `qemu-hw-display-virtio-gpu-gl` | What actually pulls in `virglrenderer`; the `-vga-gl` package declares only `qemu-common` and would leave a GL device with no renderer behind it | ↓ |
| `qemu-audio-pipewire` | Guest audio, straight into the pipewire this desktop already runs | ↓ |
| `edk2-ovmf` | UEFI firmware for the guest. Declared although `qemu-system-x86` depends on it, because `~/.local/bin/vm` names the firmware file directly — the same reasoning as `polkit` and `mesa` | ↓ |

### desktop.txt — appearance

| Package | Role | Rationale |
| --- | --- | --- |
| `adwaita-cursors` | The cursor theme, declared in three places | D: One cursor theme, set in three places |
| `gnome-themes-extra` | Supplies Adwaita-dark for GTK, which a dark theme selects | ↓ |
| `papirus-icon-theme` | The icon set | ↓ |
| `noto-fonts` | General-purpose coverage | D: Noto Fonts |
| `noto-fonts-emoji` | Colour emoji | D: Noto Fonts |
| `ttf-jetbrains-mono-nerd` | Monospace plus the Nerd Font glyphs the bar uses | D: JetBrains Mono Nerd Font |
| `ttf-dejavu` | Fallback for glyphs Noto lacks | ↓ |

### dev.txt — shell

| Package | Role | Rationale |
| --- | --- | --- |
| `zsh` | The login shell | D: zsh, without a framework |
| `zsh-autosuggestions` | History-based suggestion, sourced directly | D: same |
| `zsh-syntax-highlighting` | Command-line highlighting, sourced directly | D: same |
| `zsh-completions` | Extra completion definitions | D: same |
| `starship` | The prompt, templated from the palette | D: same |
| `zoxide` | Frecency-ranked `cd` | ↓ |
| `eza` | `ls` replacement, ANSI-coloured | D: Tools take their colours from the terminal |
| `bat` | `cat` replacement, ANSI-coloured | D: same |
| `dust` | Ranks the biggest directories at any depth, where `du` needs the depth guessed first | M, D: dust rather than a `du` pipeline |

### dev.txt — version control

| Package | Role | Rationale |
| --- | --- | --- |
| `lazygit` | TUI for staging hunks, reading history and resolving conflicts — what the bare `git` CLI is poor at | M, D: lazygit as the git interface, and delta deliberately not yet |

### dev.txt — editor and language support

| Package | Role | Rationale |
| --- | --- | --- |
| `neovim` | The editor | D: Neovim, Neovim as the editor |
| `tree-sitter-python` | Grammar, from pacman rather than a runtime downloader | M |
| `tree-sitter-javascript` | Grammar | M |
| `tree-sitter-bash` | Grammar | M |
| `nodejs` | Runtime for the npm-only language servers | M |
| `npm` | Installs those, pinned by a tracked lockfile | M |
| `pyright` | Python types and navigation | M |
| `ruff` | Python linting and formatting | M |
| `typescript-language-server` | JS/TS server | M |
| `typescript` | The compiler that server needs at runtime | M |
| `marksman` | Markdown navigation and link checking. No formatter | M |
| `prettier` | Markdown formatting only — the one gap marksman leaves | M |

### dev.txt — terminal utilities

| Package | Role | Rationale |
| --- | --- | --- |
| `ripgrep` | Recursive search | D: Terminal utilities |
| `fd` | File finding | D: Terminal utilities |
| `fzf` | Fuzzy selection | D: Terminal utilities |
| `tree` | Directory listing | D: Terminal utilities |
| `unzip` / `zip` | Archives | D: Terminal utilities |
| `man-db` / `man-pages` | Manual pages | D: Terminal utilities |
| `less` | Pager | D: Terminal utilities |
| `chezmoi` | Applies the dotfiles | D: Chezmoi |
| `pacman-contrib` | `pactree`, which the repository's own checks depend on | ↓ |

## Entries

The packages marked ↓ above. Each was checked against the running system, and
where the record genuinely does not exist, it says so rather than inventing one.

### linux

**Problem.** The machine needs a kernel.
**Choice.** Stock Arch `linux`, not `linux-lts` or `linux-zen`. No record exists
of the alternatives being weighed; it is the default and was taken as such.
**How it works.** `arch.conf` names `/vmlinuz-linux` and
`/initramfs-linux.img`; `arch-fallback.conf` names the same kernel with
`initramfs-linux-fallback.img`. Both images are produced by `mkinitcpio -P`,
which `apply-config.sh` runs only when something changed or an image is
missing.
**Cost.** 147.7 MiB installed, the second largest package declared.

### linux-firmware

**Problem.** Devices that load firmware at probe time — GPUs, Wi-Fi, some
storage — fail without the blobs present in the initramfs or on disk.
**Choice.** The meta-package, which is the safe default for a build meant to be
restorable onto unknown hardware.
**How it works.** In current Arch this is a **meta-package**: `pacman -Qi`
reports 0 B for it, and the actual blobs come from the `linux-firmware-*`
subpackages it depends on. So the manifest line costs nothing on its own and
the disk usage does not appear against this name.
**Cost.** 0 B for the meta-package; the pulled-in subpackages are dependencies
and, by this repository's convention, are not declared.

### btrfs-progs

**Problem.** `01-disk.sh` calls `mkfs.btrfs` and `btrfs subvolume create` from
the live ISO, and the installed machine needs the same tools to inspect,
balance or scrub the filesystem it is running on.
**Choice.** There is no alternative — it is the userspace for the filesystem
chosen in `DECISIONS.md` → "Btrfs".
**How it works.** Declared in `base.txt` so `pacstrap` puts it in the new root,
not only in the live environment where `01-disk.sh` used it.
**Cost.** 6.75 MiB installed. Nothing resident: it has no daemon. Btrfs
maintenance — scrub and balance timers — is not set up, which is a real gap
rather than an omission from this entry.

### sudo

**Problem.** `sync.sh` runs as the normal user and needs root for `pacman` and
`apply-config.sh`. The alternative is running the whole sync as root, which
would write the dotfiles to root's home.
**Choice.** `sudo` over `doas` and over `run0`. No record exists of the smaller
alternatives being considered; sudo is what the ArchWiki assumes, which matters
for a machine used while learning Arch.
**How it works.** `03-system.sh` adds the user to `wheel` and writes
`/etc/sudoers.d/wheel` at mode 440 — a drop-in rather than an edit to
`/etc/sudoers`, so a package update to the main file cannot conflict with it.
The rule is the unmodified `%wheel ALL=(ALL:ALL) ALL`: a password is required
every time, deliberately.
**Cost.** 7.85 MiB installed. Nothing resident.

### vim

**Problem.** Something has to be able to edit a file before the desktop and dev
manifests are installed — during stages 1 to 3, and in any recovery boot where
`dev.txt` never got applied.
**Choice.** `vim` in `base.txt` and `neovim` in `dev.txt` is not redundancy by
accident: they sit on opposite sides of the manifest boundary, and the base
system must stand up without the dev one. The daily editor is Neovim; see
`DECISIONS.md` → "Neovim as the editor, and how a file gets opened".
**Cost.** 5.37 MiB installed. Nothing resident.

### swaybg, swayidle, swaylock

**Problem.** Three things sway does not do itself: draw a background, act on
idleness, and lock the screen.
**Choice.** The wlroots-native tools from the same project, which is why none of
them has a `DECISIONS.md` section — no alternative was seriously in play.
**How it works.**
- `swaybg` is started by sway's `output ... bg` line in
  `config.d/30-appearance.conf.tmpl`, so `swaymsg reload` restarts it and the
  wallpaper follows a theme change. The image itself is generated on the
  machine — see [`docs/wallpapers/`](../wallpapers/README.md).
- `swayidle` runs as a user unit bound to `wayland-session@sway.target` and
  execs `~/.local/bin/sway-idle`, which is where the timeouts live.
- `swaylock` is invoked by that helper. Its colours are templated, and it is the
  one consumer that wants them **without** a leading `#` — a real bug, caught by
  rendering the templates to a scratch directory.
**Cost.** swaybg 33.6 KiB installed / 12.2 MiB RSS resident; swayidle 36.2 KiB
installed / 0.4 MiB resident and effectively no CPU; swaylock 86.9 KiB
installed, resident only while the screen is locked.

### pavucontrol

**Problem.** Per-application volume and output-device switching, which the
volume keys cannot express.
**Choice.** The standard PulseAudio mixer, working against pipewire-pulse. No
alternative recorded.
**How it works.** Not resident. It is launched by the audio module in
`waybar/config.jsonc.tmpl`, so the way to reach it is clicking the bar.
**Cost.** 1.04 MiB installed. Zero at rest — it only runs while open.

### libnotify

**Problem.** Sending a notification from a script needs a client, not just the
daemon.
**Choice.** The reference client library; `notify-send` comes with it.
**How it works.** In this repository `notify-send` is used from
`foot/foot.ini.tmpl`. It is also the library any GTK application links to talk
to mako. Declared explicitly rather than left as a transitive dependency for the
same reason as `polkit`: the system uses the capability directly.
**Cost.** 172 KiB installed. Nothing resident.

### brightnessctl

**Problem.** Backlight control needs write access to `/sys/class/backlight`,
which a normal user does not have.
**Choice.** No comparison against `light` or `acpilight` is recorded.
**How it works.** Not the way the obvious guess says. The Arch package ships
**only** the binary and a man page — `pacman -Ql brightnessctl` is seven lines,
with no udev rule, no setuid bit and no file capability, and this user is in no
`video` group. It works because it links `libsystemd` and calls logind's
`SetBrightness` method on `org.freedesktop.login1.Session`, which grants the
change to whoever owns the active session. So it depends on being run from
inside a real session, and a `sudo brightnessctl` or a run from a detached
context is the case that behaves differently.

Bound in `config.d/52-media-keys.conf` — through `~/.local/bin/brightness`
rather than directly, so that a key which would change nothing plays the
`limit` sound instead of failing silently — and listed by
`~/.local/bin/shortcuts`.
**On this VM `/sys/class/backlight/` is empty**, so the binding does nothing
here and only means anything on a laptop — worth knowing before debugging it,
since it is precisely the shape of failure this repository keeps hitting.
**Cost.** 28.4 KiB installed. Nothing resident.

### pipewire-audio — the sounds

**Problem.** The desktop had no sounds at all: a notification arrived silently,
a password prompt appeared silently, and a volume key at its ceiling did nothing
in a way indistinguishable from a broken key.

**Choice.** `pw-play`, from `pipewire-audio`, which was already installed as a
dependency of the declared `pipewire-pulse`. Nothing new is installed; the
package is declared so that a dependency-graph change cannot silence the desktop
quietly, the same reasoning `polkit` and `mesa` are declared under.

**How it works.** `~/.local/bin/sounds` computes four short WAVs from a table of
frequencies and envelopes and caches them in `~/.local/share/sounds/`; nothing
audio-shaped is tracked, and `checks/session.sh` fails if anything ever is.
`~/.local/bin/play-sound` is what mako, sway and the volume and brightness
helpers actually call — a shell script rather than part of the generator,
because it runs on every notification and starting a Python interpreter to make
a noise measured 30 ms against about 2. It rate-limits to one sound per event
per quarter second, so a burst of notifications does not sound like a fault, and
it is silent while mako is in do-not-disturb.

See *The desktop's sounds are generated, not shipped* in `DECISIONS.md` for why
they are generated rather than taken from `sound-theme-freedesktop`, which is
also already on the machine.

**Cost.** 6.79 MiB installed, already present. Nothing resident: `pw-play` runs
for the length of a sound and exits. The four cached sounds are about 175 KiB.

### network-manager-applet — removed, kept as history

This document used to carry a full entry here, ending with "the most
questionable resident cost in the session: a tray applet on a desktop with no
tray. Whether it earns 9.8 MiB is a real question, not a settled one." That
question was reopened and answered: **TASK-92 removed the package.** It is in
no manifest and cost nothing as of 2026-08-22. The manifest comment at the spot
it used to occupy in `desktop.txt` carries the full story, including the one
thing that made the removal non-obvious — `openssh` was only declared, and only
survived removing this, because TASK-38 had already pulled it out from behind
`network-manager-applet`'s dependency chain in `base.txt` beforehand. See
`DECISIONS.md` → "No SSH key or agent is provisioned by the build" for that
half.

### xdg-user-dirs

**Problem.** `~/Pictures` has to exist before a screenshot can be written into
it. A screenshot binding writing to a directory nothing created is one of the
silent failures this repository has already hit.
**Choice.** The XDG reference implementation.
**How it works.** Also not started by anything here. The package ships
`xdg-user-dirs.service` as a user unit and an autostart entry; the unit writes
`~/.config/user-dirs.dirs` and creates the directories it names. Verified
present on this machine.
**Cost.** 177 KiB installed. Runs once per login and exits; nothing resident.

### gnome-themes-extra, papirus-icon-theme, ttf-dejavu

**Problem.** GTK's built-in Adwaita has no dark variant as a separate theme
name, applications with no icon theme fall back to missing-image placeholders,
and Noto does not cover every glyph.
**Choice.** These three supply what `DECISIONS.md` → "Applications are made to
match" *sets*. That section explains the mechanism — the settings files and the
GTK portal — but names no package, so the packages themselves are undocumented.
`gnome-themes-extra` is what makes `Adwaita-dark` resolve to a real theme; it is
still required, and is now required *conditionally*, since `gtk-3.0/settings.ini`
names `Adwaita-dark` only under a dark theme and plain `Adwaita` under a light
one (`DECISIONS.md` → "Light themes, and the reason that did not survive being
checked"). `GTK_THEME=Adwaita:dark` used to be the lever and is deliberately no
longer set anywhere. `papirus-icon-theme` supplies both `Papirus-Dark` and
`Papirus`, which the same file switches between; it was chosen over Adwaita's
icons with no recorded comparison. `ttf-dejavu` is a fallback with no recorded
comparison either.
**Cost.** The reason to look at them together: 4.2 + 111.5 + 9.8 = **125.5 MiB**,
8.2% of everything declared, for appearance alone — and with the two Noto
packages and the Nerd Font, 466.7 MiB, 30.6% of the install (re-derived
2026-08-22; it was 39% of a smaller total a day earlier — see "What the whole
declared set costs on disk" above). Zero at runtime beyond what is rendered.
That is the trade this setup has made; it is defensible, and it should be made
knowingly.

### librsvg - tried for the bar's Arch logo, and removed

**What was tried.** TASK-164's first implementation rendered the bar's Arch
logo (TASK-159) as a themed SVG, drawn through waybar's `image` module, and
declared `librsvg` on the reasoning that it supplies `gdk-pixbuf`'s SVG loader
plugin and the bar now depended on that directly rather than inheriting it.
That reasoning was checked against what the package *installs*, never against
what actually renders - and the plugin genuinely does not exist to install:
this system's `gdk-pixbuf2` (2.44.7) ships no loader plugins at all, for any
format, having moved GTK4 image loading to the sandboxed `glycin` library
instead. `librsvg` was declared, present, and doing nothing.
**What that actually did.** Not "no logo" - the whole bar. waybar is GTK3, so
it still asks `gdk-pixbuf` for a loader the traditional way, gets none, and
the `image` module's layer-shell surface never receives its first `configure`
from the compositor. waybar keeps running - the process, the config parse,
the CSS load all look fine in the log - but no bar is ever mapped, on any
output, on every restart. This is exactly the invisible failure mode CLAUDE.md
names: nothing here errors, and it was reintroduced on every `sync.sh` a
theme-followed machine ran, because the missing piece was distro packaging,
not this repository's config.
**What replaced it.** TASK-164's follow-up fix draws the logo as a Nerd Font
glyph in a `custom` module instead - Pango text, the same rendering path every
other icon on this bar already uses, themed with an ordinary CSS `color` rather
than a baked-in SVG fill. See the `custom/arch-logo` comment in
`config.jsonc.tmpl` for the glyph and the reasoning. `librsvg` is not declared
here any more: nothing in this repository uses it.
**Left as a known gap.** Whether GTK icon themes generally (not just this bar)
render SVG correctly on this machine was not investigated - `papirus-icon-theme`
is itself all SVG, and if GTK's icon-theme code takes the same `gdk-pixbuf`
path as the `image` module did, the same gap may be silently affecting more
than the bar. Worth a task of its own if it turns out to matter.

### zoxide

**Problem.** `cd` into a deep path needs the whole path, every time.
**Choice.** `zoxide` over `autojump` and `z`: it is packaged, written in Rust
with a startup cost the shell budget can absorb, and initialises with one line.
No comparison against `fzf`'s own directory widgets is recorded.
**How it works.** Initialised from `dot_zshrc`, which is where to look if it
stops working. It keeps its database under `~/.local/share/`, so the ranking is
machine-local and deliberately not in the repository — the same boundary the
theme selection sits on.
**Cost.** 1.15 MiB installed. Nothing resident. Its shell hook is inside the
400 ms interactive startup budget that `checks/session.sh` enforces.

### pacman-contrib

**Problem.** `checks/sway-commands.sh` has to answer "which declared package
provides this command", including through dependency chains, and pacman alone
cannot walk that graph.
**Choice.** The official package that provides `pactree`.
**How it works.** This is the one genuinely unusual entry in the manifests, and
worth stating plainly: **it is on the built machine for the sake of the
repository's own tooling.** That cuts against the boundary in `CLAUDE.md` — repo
tools do not go in `setup/packages/` — and the reason it is defensible is that
`pactree` is a pacman utility a person maintaining an Arch machine wants anyway,
and the same package brings `paccache` for trimming the package cache and
`checkupdates` for a safe update count. Neither of those is used anywhere in
this repository, which is worth knowing before assuming they are wired up.
**Cost.** 129 KiB installed. Nothing resident.

### mpv, mpv-mpris, yt-dlp

**Problem.** Playing background music meant opening qutebrowser and finding a
tab — a browser, a window and a set of keystrokes for something that should be
one keypress and then invisible. See TASK-101.
**Choice.** `mpv` playing a URL, made visible to the rest of the session by
`mpv-mpris`, with `yt-dlp` resolving a pasted link. Not a music application —
that is the design: no library, no daemon, no second window to manage, and the
bar's media module and the playback keys drive it exactly as they would drive
anything else over MPRIS. Alternatives were genuinely compared, in TASK-101
rather than in `DECISIONS.md` or a manifest comment, which is why the pointer
here is `↓` rather than `D`: **`spotify-player`/`ncspot`** (31 MiB / 16 MiB) —
real playlists and native MPRIS, but both need a Premium account. **`cmus`**
(852 KiB, by far the smallest) — local files only, so it does not answer the
streaming case this was for. **`mpd` + `ncmpcpp`** — a daemon and a client for
a local library, more machinery than the problem needs. A fifth option,
`cliamp`, prompted the search and was rejected outright on packaging: it is
Homebrew-only, no Arch package and no PKGBUILD, the same objection that already
ruled out the AUR route in TASK-43.
**How it works.** The line that makes the whole design work is
`script=/usr/lib/mpv-mpris/mpris.so` in `~/.config/mpv/mpv.conf` — without it
mpv plays perfectly and nothing on the desktop can see it. `mpv` is started
with `systemd-run --user --scope` so it dies with whatever launched it rather
than surviving in an orphaned cgroup. It is started once, idle, listening on a
JSON IPC socket, and everything after that — queue this, play that now,
reorder, remove, stop — is a message to that socket, sent by
`~/.local/lib/mpv_queue.py`, which is the only thing that speaks it. The queue
is mpv's own playlist, so nothing here keeps a second copy of it that could
disagree. Addressing mpv by its socket also fixed a real bug: stopping used to
be `pkill -x mpv`, which killed every mpv the user had running, including one
playing a film. Stations are tracked data in
`~/.config/focus-music/stations`, reached through `~/.local/bin/focus-music`,
alongside whatever a machine has kept in `stations.local`. `yt-dlp` is no
longer an accessory to that path but part of it: the helper searches YouTube
for arbitrary text and plays the result, so anything not carried by a radio
station is one prompt away rather than a file edit. The SomaFM and laut.fm
stations remain direct HTTP streams that start instantly with nothing to
resolve; a station may also be written as `search:<text>`, which is resolved
afresh on every play. That is deliberate - what the helper writes down is
always a search and never a video id, because an id is a link that rots and a
search is not. `focus-music --check` resolves every entry and names the dead
ones.
**Cost.** `mpv` 6.34 MiB, `mpv-mpris` 35.18 KiB, `yt-dlp` 31.66 MiB installed
(2026-08-22) — 31.66 MiB of that is a Python interpreter's worth of extractor
code, and it now earns it: search is a first-class way into this feature
rather than a fallback. None of the three is resident until a station is actually playing,
so there is no row in the session-cost table above.

### cava

**Problem.** No visual feedback for whatever audio is actually playing,
independent of which player produced it. See TASK-103.
**Choice.** `cava`. No alternative is recorded — it was the obvious terminal
spectrum analyser for the job, and TASK-103 evaluated it directly (fetched to a
scratch directory and run) rather than against competitors.
**How it works.** Configured with `input method = pulse`, `source = auto`,
which attaches to the default output's `MONITOR` — so it visualises whatever is
audible (radio, a browser tab, a notification) without any MPRIS integration
and without `mpv` or anything else knowing it exists. Colours are templated
from `.chezmoidata/themes.toml` like every other consumer, rendering a
quiet-to-loud gradient through the theme's own identity colours rather than a
fixed green-amber-red.
**Cost.** 195.37 KiB installed. Not resident by default — it runs only while
its window is open. Measured while running, over 30s of wall clock on
2026-08-22: cava itself 1.27% of one core / 8.0 MiB PSS, but the foot window
showing it costs *more* than cava does — 2.00% of one core / 12.0 MiB PSS for
the redraw, against 0.00%/11.5 MiB for an identical idle foot window. Total for
the visualiser while open: **~3.27% of one core, ~20 MiB**, and that is a floor
rather than a total — it does not include what sway itself pays to composite a
window that repaints every frame.

### bluez, bluez-utils

**Problem.** Connecting a bluetooth device — headphones, a keyboard, a mouse —
needs `bluetoothd`, and nothing else in this setup provides it. But the setup
runs on machines that have no bluetooth radio at all, and on machines that have
one and never use it. A daemon enabled once in the manifest would run on every
one of them, from boot to shutdown, forever.

**Choice.** Split the two decisions apart. The *packages* are declared for every
machine, because 5.4 MiB of disk that costs no processes is not worth making
the manifest machine-dependent for. The *service* is opted into per machine,
with `bluetooth on`, and `bluez` ships `bluetooth.service` disabled so the
default on a fresh install is off. `checks/session.sh` fails if anything in
`setup/` ever enables it.

`bluez-utils` is separate from `bluez` in Arch and supplies `bluetoothctl`,
which is both how a device gets paired and how the menu asks what is connected.

**Alternatives.** `blueman` (7.0 MiB plus `gtk3`, `libnm`, `python-cairo` and
`python-gobject`) is the usual graphical answer and was rejected for the reason
`network-manager-applet` was removed in TASK-92: it is a tray application and
this desktop has no tray, so its icon would have nowhere to go. `bluetuith` is
the TUI alternative and is AUR-only, which TASK-43 ruled out. That leaves
`bluetoothctl` in a terminal, which is the same answer `nmtui` already is for
the network.

Not considered further: leaving bluetooth out entirely. It was the previous
state and the reason this ticket exists.

**How it works.** `bluetoothd` exposes controllers and devices on the system
bus under `org.bluez`. That is what makes the bar module work the way it does:
with the daemon stopped there is no controller on the bus at all, so Waybar's
`bluetooth` module renders `format-no-controller` — set to the empty string
here, which hides the module outright. A visible module therefore means a
running daemon, which is the whole design and is why that empty string has a
check of its own.

`~/.local/bin/bluetooth` is the switch. It calls `systemctl enable --now` /
`disable --now`, which reaches root through polkit rather than sudo — systemd
asks polkit itself over D-Bus, so the `polkit-gnome` agent already running here
draws the prompt. That matters because the command is normally launched from a
menu, where a sudo prompt on a terminal nobody is looking at would just hang.

Audio needs nothing more. `pipewire-audio` — already installed, as a dependency
of the declared `pipewire-pulse` — itself depends on `bluez-libs` and ships
`/usr/lib/spa-0.2/bluez5/` with SBC, AAC, aptX, LDAC, LC3 and the HFP codecs.
That was already on every machine here; only the daemon was missing.

**Cost.** 1.73 MiB (`bluez`) + 3.69 MiB (`bluez-utils`) = **5.41 MiB** installed,
from `pacman -Qi` after installing them on 2026-08-23. Resident cost is **not measured** — see the
gap below.

### qemu-system-x86, qemu-img, qemu-ui-gtk, qemu-hw-display-virtio-vga-gl, qemu-hw-display-virtio-gpu-gl, qemu-audio-pipewire, edk2-ovmf

**Problem.** Running something you do not trust, or keeping a project's tooling
away from the machine you actually use, meant either not doing it or doing it on
the real system. The setup could be rebuilt in a VM by hand, but that meant
downloading an ISO and sitting through the install wizard each time, which is
enough friction that it never happened.

**Choice.** qemu on its own, driven by [`~/.local/bin/vm`](../../setup/dotfiles/dot_local/bin/executable_vm).
The rationale in full is in `DECISIONS.md` under *Virtual machines with qemu
alone, and clones that cost nothing*; the short version is that libvirt's
scaffolding buys management this setup does not need, and qcow2 overlays buy
most of what its snapshots would have.

**Alternatives.** `libvirt` + `virt-manager` was the obvious answer and is
covered in `DECISIONS.md`. `qemu-ui-sdl` was measured against `qemu-ui-gtk` and
lost by about 2 MiB of difference — `gtk3` is already installed here, so GTK
costs only `vte3`, while SDL would have cost `sdl2_image`. GTK also has
`zoom-to-fit` and a menubar that can be turned off, which the full-screen login
session in TASK-69.3 needs.

**How it works.** Machines live in `~/.local/share/vm/<name>/`, one directory
each, holding a disk, that machine's own UEFI variable store, and a `vm.conf`
naming its memory and CPU count. A machine cloned from the bundled base image is
a qcow2 **overlay**: an almost empty file naming the base as its backing file,
which grows only as the guest writes. That is why a new machine is instant and
`vm reset` is a delete rather than a reinstall — and why the base must stay
read-only, since writing to a backing file corrupts every overlay derived from
it.

Three things about this are easy to get wrong and are worth knowing before
debugging it:

- **The virtio display devices are separate packages.** `qemu-system-x86` alone
  does not provide `virtio-vga`. Naming a device that is not installed makes
  qemu exit with an error about an unknown device, from configuration that looks
  entirely correct — so `vm` asks `qemu-system-x86_64 -device help` what exists
  and degrades to std VGA with a warning rather than asserting.
- **The OVMF path is discovered, not hardcoded.** Arch has moved it before
  (`/usr/share/edk2-ovmf/x64/` became `/usr/share/edk2/x64/`, and the 4m
  variants appeared beside the originals). A stale hardcoded path would surface
  as a guest that will not boot with nothing pointing at the cause.
- **qemu is in `earlyoom`'s `--avoid` list**, because killing a guest is a power
  cut to the machine inside it rather than a lost browser tab. That is only safe
  because `vm` always passes a fixed `-m`; the cap and the avoid rule are one
  decision, not two. The name is at the limit of what earlyoom can match: `comm`
  truncates `qemu-system-x86_64` to the fifteen bytes `qemu-system-x86`.

**Cost.** Measured with `pacman -Qi` on **2026-08-23**, after installation:

| Declared | Size |
| --- | ---: |
| `qemu-system-x86` | 54.97 MiB |
| `edk2-ovmf` | 15.57 MiB |
| `qemu-img` | 10.74 MiB |
| `qemu-ui-gtk` | 130.52 KiB |
| `qemu-hw-display-virtio-gpu` | 118.39 KiB |
| `qemu-hw-display-virtio-gpu-gl` | 94.58 KiB |
| `qemu-audio-pipewire` | 94.38 KiB |
| `qemu-hw-display-virtio-vga` | 62.34 KiB |
| `qemu-hw-display-virtio-vga-gl` | 62.27 KiB |
| **declared total** | **81.8 MiB** |

New dependencies pulled in alongside them — `qemu-common`,
`qemu-system-x86-firmware`, `seabios`, `vte3`, `vte-common`, `virglrenderer`,
`dtc`, `libcbor`, `capstone`, `libslirp`, `libxdp`, `ndctl`, `numactl`,
`rdma-core`, `vde2`, `wolfssl`, `libaio`, `libtraceevent`, `libtracefs` and
`qemu-ui-opengl` — come to **43.0 MiB**, for about **125 MiB** on disk in total.

**Resident cost is nil when no guest is running.** There is no daemon, which is
a large part of why libvirt was not chosen. A running guest costs whatever `-m`
allows it plus qemu's own overhead, and `vm.conf` is where that number lives —
the default is half of host RAM, which is 3840 MiB here.

**A machine costs almost nothing until it runs.** Measured: a clone of a 10 GiB
base image is **196 KiB** on disk at creation. That is the overlay working as
intended rather than an estimate.

### power-profiles-daemon, python-gobject

**Problem.** TASK-140: an easy way to switch the CPU between Performance,
Balanced and Power Saving, from the bar rather than a terminal.

**Choice.** `power-profiles-daemon`, opened from
[`~/.local/bin/power-profile`](../../setup/dotfiles/dot_local/bin/executable_power-profile).
The obvious alternative to a daemon at all was writing the sysfs knobs
directly from a plain script - no daemon, matching `theme`/`sounds`/`wallpaper`
elsewhere in this setup - and that was the first plan. It does not survive
contact with what those knobs actually are: `energy_performance_preference`
and `platform_profile` are root-only sysfs writes, so a script-only approach
would mean inventing our own privilege-escalation mechanism (a udev rule
loosening permissions on those specific attributes, or a sudoers/polkit rule)
rather than using the one already vetted for exactly this - run as root,
authorise a client's request over D-Bus via polkit. `power-profiles-daemon`
exists to be that safely, not to schedule anything ongoing: it is
event-driven, not polling.

**Alternatives.** TLP manages more hardware surface overall - USB
autosuspend, PCIe ASPM, disk APM, per-AC/battery charge thresholds - but is a
static config file re-applied on AC/battery transitions, not a live "pick one
of three modes and it takes effect now" tool. Making it behave like a 3-way
switch would need scripting on top of it that TLP was never shaped for, where
`power-profiles-daemon` already exposes exactly `performance` / `balanced` /
`power-saver` through one command, `powerprofilesctl set <mode>`.

**How it works.** `powerprofilesctl` is the CLI ~/.local/bin/power-profile
actually calls - `get` to read the current profile, `set` to change it. It is
not part of the `power-profiles-daemon` package itself: pacman lists it as an
*Optional Dep*, needing `python-gobject`, so both have to be declared or the
daemon installs with no command-line client. The daemon exposes
`org.freedesktop.UPower.PowerProfiles` on the system bus; changing a profile
writes `energy_performance_preference` (or the scaling governor as a
fallback) and, on hardware whose firmware exposes it, `platform_profile` -
which is also what can shift fan curves and thermal limits on supporting
laptops.

On the bar, `battery`'s `on-click` and a new `custom/power-profile` module
both open the same menu - never both visible on one machine, since one hides
itself with no battery hardware and the other hides itself when a battery
*is* present. See `docs/manual/02-the-desktop.md` → "Power profiles".

**Cost.** `power-profiles-daemon`: **141.95 KiB** installed
(`pacman -Si`, 2026-08-24 - not yet installed on the reference machine, see the
gap below). `polkit`, `glib2`, `glibc`, `gcc-libs` and `upower` are already
declared or installed elsewhere in this setup; the one genuinely new
transitive dependency is `libgudev`. `python-gobject`: **1541.82 KiB**
installed (`pacman -Si`, 2026-08-24); `glib2`, `glibc` and `libffi` are
already present, so the real new weight is `gobject-introspection-runtime`.
Resident cost is **not measured** - see the gap below.

### udisks2

**Problem.** TASK-188: an external drive was not reachable from the file
manager at all. yazi's layout is three fixed columns with no fourth pane, so
the sidebar a GUI file manager keeps its device list in has nowhere to live -
and without a device list, an unmounted disk is something you mount from a
shell and then type the path to. This machine has four disks and, at rest,
partitions on three of them mounted nowhere.

**Choice.** `udisks2`, driven by the `mount.yazi` plugin bound to `M`. The
plugin is upstream's own (`yazi-rs/plugins`) and shells out to `udisksctl`,
so the package is not really a choice made here so much as the interface that
plugin speaks. What *was* chosen is doing it through udisks at all rather
than `sudo mount`: udisks lets the logged-in user mount a removable volume
with no password, through a polkit policy written for exactly this, instead
of inventing a sudoers rule. Same reasoning as `power-profiles-daemon` above.

**Alternatives.** `udevil` and `pmount` are the setuid-helper approach and
both are effectively unmaintained. A `sudoers` entry for `mount` is the thing
udisks exists so you do not write. Going the other way - a graphical file
manager purely for its device sidebar - is the decision TASK-44 already made
and reversed; see *No graphical file manager, reversing an earlier decision*
in `DECISIONS.md`.

**How it works.** `udisksd` runs as root on the system bus and is **D-Bus
activated, not enabled** - `udisks2.service` ships `disabled` and nothing in
`apply-config.sh` turns it on. The first `udisksctl` call starts it, and it
then stays up. Mounts land under `/run/media/<user>/<label>`.

Authorisation is where the two kinds of drive part company, and it is worth
knowing which you have before reading a password prompt as a bug:

| | polkit action | As the active console user |
| --- | --- | --- |
| Removable disk (USB stick, external drive) | `filesystem-mount` | `yes` — no prompt |
| Fixed internal disk (the Windows partitions here) | `filesystem-mount-system` | `auth_admin_keep` — prompts once |

Measured on this machine: `udisksctl mount -b /dev/loop0` on a loopback
volume mounted at `/run/media/vincemaina/TESTSTICK` with no prompt, and
`udisksctl mount -b /dev/sdb1` - a partition on a fixed internal disk -
returned `NotAuthorizedCanObtain`. `mount.yazi` handles that second case: it
retries over D-Bus and then interactively, so the session's polkit agent asks
for a password rather than the operation simply failing.

No filesystem package is needed for the drives this is aimed at. `vfat`,
`exfat` and `ntfs3` are all kernel modules in `linux`, so `ntfs-3g`,
`exfatprogs` and `dosfstools` are **not** declared - they supply `mkfs` and
`fsck`, not the ability to mount. `lsblk`, which the plugin uses to fill in
the filesystem column for unmounted partitions, and `eject` are in
`util-linux` under `base`.

**Cost.** 7.88 MiB on disk (`pacman -Qi`, 2.11.2-1), and it was already
installed as a dependency of `gvfs` before being declared, so declaring it
added nothing. `udisksd` resident: 16.2 MiB RSS, 8.35 MiB by the cgroup
(`systemd-cgtop -1 --raw`), measured 2026-08-27 - but only *after* something
first calls it. On a machine that never touches a removable drive it is not
running at all, which is why it does not appear in the session's idle-memory
figure.

### thunar, tumbler

**Problem.** TASK-189: yazi is fast and keyboard-native but suits a small job
done and closed. Bulk work — moving, renaming and organising many files at
once — and looking at a directory of images are the two things it is weakest
at, and both are what a graphical file manager is for.

**Choice.** Thunar, chosen over pcmanfm, pcmanfm-qt, nemo and nautilus by
unpacking each candidate and reading what is inside, not on reputation. See
*Thunar returns, and the four file managers it was measured against* in
`DECISIONS.md` for the full comparison. The short version is that rebindable
keys were the cull: Thunar and nemo can be given vim keys, pcmanfm and
pcmanfm-qt cannot at any price, and of the two that can, nemo starts a daemon
at every login and Thunar starts nothing.

**Alternatives.** pcmanfm (9.3 MiB, 7 packages, keys compiled in),
pcmanfm-qt (9.7 MiB, 7 packages, keys compiled in, and Qt so it would not
follow the GTK theme), nemo (14.9 MiB, 10 packages, hard-depends on `xapp`
whose autostart entry has no `OnlyShowIn`), nautilus (64.4 MiB, 27 packages,
drags in the `localsearch` indexer), dolphin (72 packages).

**How it works.** `$mod+e` runs `thunar`. Its app_id is `thunar` — GTK's
derived one, since Thunar takes no app_id flag and its desktop entry has no
`StartupWMClass` — and `40-window-rules.conf` floats it at 1100×700 on that
string. Keys come from `~/.config/Thunar/accels.scm`, tracked and read-only;
see the manual for what is bound and for the two things GTK accelerators
cannot express.

`tumbler` is the thumbnailer, and it is declared rather than left as an
Optional Dep on purpose. That exact omission is what made the previous Thunar
useless: thumbnails are the strongest argument for a graphical file manager
and it was the one thing that installation could not do, logging
`ThunarThumbnailer: Failed to retrieve supported types ... ServiceUnknown`
on its single run. Confirmed working this time by looking at a directory of
screenshots and seeing them render, not by checking the package is present.

**Cost.** Measured on this machine, 2026-08-27.

| | |
| --- | --- |
| Disk, thunar + 6 dependencies | 20.5 MiB (`thunar` 9.58, `libexif` 3.12, `exo` 2.21, `libxfce4ui` 2.21, `libgtop` 1.29, `xfconf` 1.12, `libxfce4util` 1.09) |
| Disk, tumbler | 880 KiB |
| **Resident at login** | **nothing** — no autostart entry, and neither systemd user unit has a `WantedBy=` |
| **Resident after the window is closed** | **28.7 MiB** — `tumblerd` 20.3 MiB and `xfconfd` 8.4 MiB, both D-Bus activated on first use and neither exiting afterwards |
| Window on screen | 157 ms from launch to sway's `window::new`, warm cache, mean of three runs. A `foot` window on the same measurement is 20 ms, so Thunar costs about 137 ms more to appear |

That 28.7 MiB is the figure TASK-190 was to have weighed, and TASK-196 weighed
it and kept Thunar anyway. Thunar genuinely starts nothing at login — but "no
background processes when it is not open" is only true until the first time it
is opened, and after that two daemons stay for the rest of the session. The
point of keeping it on `$mod+Ctrl+e` rather than on `$mod+e` is that the cost
is now paid only in sessions where it is actually reached for, which for the
jobs it is kept for is not most of them.

The 157 ms is not comparable to the browser figures elsewhere in
`DECISIONS.md`, which were keypress-to-mapped-window and cold. This one starts
at process launch and stops at the compositor creating the container, warm.
The useful part is the ratio against `foot` measured the same way.

## Gaps this document does not close

Named rather than left silent, because a gap that is written down can be filled.

- **The session-cost table's sway row is now measuring a machine that no
  longer exists.** It was taken on 2026-08-21 under software rendering; on
  2026-08-22 the hypervisor's 3D acceleration was turned on (`DECISIONS.md` →
  "The VM rendered in software, and no longer does"), and `ps` now shows sway
  resident at roughly 68 MiB against the 143.8 MiB recorded there. The other
  rows in that table were not re-measured — doing that properly is a full pass
  over every unit, not a one-line fix, and that pass is the separate ticket
  for a general resource-cost register. Until it happens, read the session-cost
  table as a snapshot of a software-rendered machine, not this one.
- **`power-profiles-daemon` and `python-gobject` are sized from `pacman -Si`,
  not `pacman -Qi`.** Both were left uninstalled on the reference machine
  deliberately - a running sway session was live during TASK-140's
  implementation, and installing packages plus restarting a session-adjacent
  daemon on someone's active desktop is exactly the kind of outward-facing
  change this repository's own conventions say to confirm first rather than
  just do. `sync.sh` installs them the same way it does everything else;
  once it has, this entry's Cost section should move to measured figures
  and the daemon's resident memory should be added.
- **Several entries above say no alternative was recorded**, and it is worth
  being explicit about which: `linux`, `btrfs-progs`, `sudo`,
  `swaybg`/`swayidle`/`swaylock`, `brightnessctl`, `papirus-icon-theme`,
  `ttf-dejavu`, and `cava`. `zoxide` compares against `autojump` and `z` but not
  `fzf`'s own directory widgets, and `pavucontrol` names no alternative either.
  That is the honest state, not a placeholder to be filled with a
  plausible-sounding reason later — see "The entry format" above for why that
  matters.
- **`bluetoothd` has no measured resident cost.** The entry above gives disk
  only. The machine TASK-146 was written on had no `bluez` installed and no way
  to install it during that session, so the figure that actually matters — what
  the daemon costs while running, which is the entire reason it is opted into
  rather than enabled everywhere — is missing. Take it on the first machine
  where `bluetooth on` is used: `systemd-cgtop -1 --raw` for the unit and
  `ps -o rss= -C bluetoothd` while a device is connected, since an idle
  controller and a connected headset are not the same measurement.
- **Package cost is disk and, where resident, memory/CPU — nothing about
  network egress.** `yt-dlp` and `firefox` are the two packages here that talk
  to the internet on their own initiative (a video-info fetch, an update
  check), and this document has no figure for that.
