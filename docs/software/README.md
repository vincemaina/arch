# Software this setup installs

One hundred packages are declared across [`setup/packages/`](../../setup/packages/).
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
| `spotify-player` | Spotify without the desktop app: a daemon that streams and exposes MPRIS, with a TUI and a CLI as remote controls | ↓ |
| `xdg-user-dirs` | Creates `~/Pictures` and friends | ↓ |
| `gvfs` | Removable and network volumes for GIO, so a USB stick appears in a Save As dialog | M, D: GVFS |
| `yazi` | The file manager, on `$mod+e`. It replaced Thunar rather than sitting beside it | M, D: No graphical file manager, reversing an earlier decision |
| `imv` | Image viewer | M |
| `btop` | System monitor | D: btop |
| `qutebrowser` | Web browser, the everyday one | D: Two browsers: qutebrowser for everything, firefox for DRM and extensions |
| `firefox` | The other browser, for WebExtensions and DRM that `qutebrowser`'s webengine cannot do at all | M, D: Two browsers: qutebrowser for everything, firefox for DRM and extensions |
| `rofi` | The launcher — one prompt, several sources via `combi` | M, D: rofi, reversing an earlier decision |
| `rofi-calc` | Calculator source for that prompt, via libqalculate | M |
| `fastfetch` | System summary, run manually | M |

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

Bound in `config.d/52-media-keys.conf` and listed by `~/.local/bin/shortcuts`.
**On this VM `/sys/class/backlight/` is empty**, so the binding does nothing
here and only means anything on a laptop — worth knowing before debugging it,
since it is precisely the shape of failure this repository keeps hitting.
**Cost.** 28.4 KiB installed. Nothing resident.

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

### spotify-player

**Problem.** Spotify with a Premium account, without keeping either the
official desktop application or a browser tab open for it. TASK-135.
**Choice.** `spotify-player`, from `extra`. The decision was made on Arch's
compiled feature set rather than on the project descriptions, because that is
what determines whether it can integrate at all:

```text
$ spotify_player features
daemon streaming media-control image ratatui-image sixel notify fzf pulseaudio-backend
```

`media-control` is MPRIS, and `daemon` is what allows playback to outlive the
window that started it. It is also both halves of the problem in one binary —
something that streams and something that can browse a library — sharing one
config, one cache and one login.
**Alternatives.** `ncspot` has MPRIS too — it is in its default features and
Arch builds the defaults — so that did not separate them. It has no daemon
mode at all, which does: its TUI process *is* the player, so hiding that window
through `sway-toggle-window` would stop the music, because that helper kills
the window rather than stashing it. `spotifyd` is the opposite shape, a daemon
with no way to browse a library, so it would have needed a second package to
pick anything with. `librespot` is the library all three are built on and is
not a client. The official `spotify` client is AUR-only and is the thing being
avoided. Nothing here was ruled out on availability: all four are in `extra`,
so the AUR decision in TASK-43 did not come into it.
**How it works.** One `spotify_player -d` daemon streams and claims the MPRIS
name `org.mpris.MediaPlayer2.spotify_player`; the TUI and every CLI call are
controllers that talk to it. That split is bought by one line in
`~/.config/spotify-player/app.toml`:

```toml
enable_streaming = "DaemonOnly"
```

Without it every invocation registers its own Spotify Connect device and its
own bus name, and the bar follows whichever it noticed first. The TUI is
additionally launched with `-o enable_media_control=false` so that only the
daemon ever claims a bus name.

`~/.local/bin/spotify` is the rofi picker and starts the daemon on demand in a
*named* transient scope — `systemd-run --user --scope --unit=spotify-daemon` —
so stopping it is `systemctl --user stop spotify-daemon.scope`, addressing
exactly this process. `focus-music` reached the same place from the other
direction after `pkill -x mpv` was found to kill a film playing in another
workspace; naming the scope means that mistake is not available here.

Because the daemon is a plain MPRIS player, waybar's `mpris` module,
`~/.local/bin/media` and `~/.local/bin/focus-timer` act on it with no
Spotify-specific code in any of them. The only line any of them gained is a
`player-icons` entry in the bar, keyed on the MPRIS name.

Premium is required — librespot cannot stream without it — and authentication
is two OAuth flows (a librespot session and a Web API token, under two
different client ids) that happen once per machine and cache under
`~/.cache/spotify-player`. No password, token or client secret is stored in
this repository. `client_id` is deliberately left unset: the bundled default
is registered in Spotify's extended quota mode and predates the November 2024
Web API changes, whereas an application registered today starts restricted and
returns 403 and 429 on exactly the browse endpoints this uses.
**Cost.** 31.76 MiB installed, 8.51 MiB download. Nothing is resident until
music is playing — there is no session unit and no autostart — so there is no
row in the session-cost table above.

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
