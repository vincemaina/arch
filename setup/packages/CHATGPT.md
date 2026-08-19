Yep. I’d start by making the package manifests reflect the **known-good VM we’ve actually built**, rather than trying to anticipate every future tool.

I’d use three manifests:

```text
packages/
├── base.txt
├── desktop.txt
└── dev.txt
```

The split is conceptual rather than something Pacman or chezmoi understands.

`base.txt` means “the machine should still be a usable Arch system without a graphical desktop.” Put this in it:

```text
base
linux
linux-firmware
btrfs-progs
networkmanager
sudo
vim
git
```

Those correspond directly to the `pacstrap` we used. Their purposes are:

| Package          | Why it's here                                    |
| ---------------- | ------------------------------------------------ |
| `base`           | Essential Arch userspace                         |
| `linux`          | Linux kernel                                     |
| `linux-firmware` | Firmware blobs used by hardware                  |
| `btrfs-progs`    | Tools required to manage our Btrfs filesystem    |
| `networkmanager` | Networking                                       |
| `sudo`           | Privilege escalation for your normal user        |
| `vim`            | Basic editor available even before desktop setup |
| `git`            | Lets us clone/manage this setup repository       |

I would **not** put systemd in here explicitly. It's already pulled in by Arch's base system.

---

`desktop.txt` should describe everything required to recreate your current Sway desktop:

```text
sway
swaybg
swayidle
swaylock
waybar
foot
wofi
mako
xorg-xwayland

polkit

pipewire
pipewire-pulse
wireplumber

xdg-desktop-portal
xdg-desktop-portal-wlr

grim
slurp
wl-clipboard

brightnessctl
pavucontrol
network-manager-applet

noto-fonts
noto-fonts-emoji
ttf-dejavu

thunar
gvfs

qutebrowser

btop
```

The blank lines are purely there to make it human-readable.

Conceptually that file contains several layers:

```text
Sway environment
├── compositor
│   ├── sway
│   ├── swaybg
│   ├── swayidle
│   └── swaylock
│
├── UI
│   ├── waybar
│   ├── wofi
│   ├── mako
│   └── foot
│
├── compatibility
│   └── xorg-xwayland
│
├── desktop plumbing
│   ├── polkit
│   ├── xdg-desktop-portal
│   └── xdg-desktop-portal-wlr
│
├── audio
│   ├── pipewire
│   ├── pipewire-pulse
│   └── wireplumber
│
├── screenshots/clipboard
│   ├── grim
│   ├── slurp
│   └── wl-clipboard
│
├── controls
│   ├── brightnessctl
│   ├── pavucontrol
│   └── network-manager-applet
│
├── fonts
│   ├── noto-fonts
│   ├── noto-fonts-emoji
│   └── ttf-dejavu
│
└── applications
    ├── thunar
    ├── gvfs
    ├── qutebrowser
    └── btop
```

That grouping should probably live in documentation rather than comments inside the package file.

---

Then I'd make `dev.txt`:

```text
neovim
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

These aren't required for Sway to work. They're your useful terminal/development environment.

This distinction gives you a nice future option:

```bash
install-base
```

could create a server/minimal machine, while:

```bash
install-desktop
```

adds Sway, and:

```bash
install-dev
```

adds your development tools.

You might eventually have different machine profiles:

```text
Arch base
   │
   ├── desktop
   │     └── dev
   │
   └── server
```

without needing entirely separate repositories.

### One thing I'd deliberately leave out for now

We discussed things like:

```text
cliphist
playerctl
lxqt-policykit
```

but you never actually confirmed that we installed/configured those on the known-good VM. So I wouldn't quietly add them to the canonical package set yet.

The principle should be:

> **The repo describes intentional known-good state, not every idea we've discussed.**

That's going to matter a lot once this thing becomes automated.

### How the installer will consume these

Again, these files have **nothing to do with chezmoi**.

Our scripts will explicitly feed them into Pacman.

For example:

```bash
sudo pacman -S --needed - < packages/desktop.txt
```

There's one snag with my nicely spaced example above: if we want to pipe the file directly into Pacman, I'd keep the actual manifests extremely boring — **one package per line, no comments or section headings**.

So the real `desktop.txt` I'd commit would be:

```text
sway
swaybg
swayidle
swaylock
waybar
foot
wofi
mako
xorg-xwayland
polkit
pipewire
pipewire-pulse
wireplumber
xdg-desktop-portal
xdg-desktop-portal-wlr
grim
slurp
wl-clipboard
brightnessctl
pavucontrol
network-manager-applet
noto-fonts
noto-fonts-emoji
ttf-dejavu
thunar
gvfs
qutebrowser
btop
```

Then document the categories separately in `packages/README.md`.

I'd create that too:

```text
packages/
├── README.md
├── base.txt
├── desktop.txt
└── dev.txt
```

And give `packages/README.md` roughly this purpose:

> Package manifests define the software that should be explicitly installed on the system. They are plain package lists consumed by the installation scripts using Pacman. They are not managed or interpreted by chezmoi.
>
> `base.txt` contains packages required for the core Arch installation.
>
> `desktop.txt` contains the graphical Sway desktop and supporting desktop infrastructure.
>
> `dev.txt` contains development and terminal productivity tools.
>
> Dependencies should generally not be listed manually. Pacman installs them automatically. A package belongs here when we intentionally want it installed, rather than merely because another package depends on it.

That last paragraph is important. Otherwise if you generate this from:

```bash
pacman -Q
```

you'll eventually commit hundreds of transitive dependencies and defeat the purpose.

Our manifests are really:

```text
desired explicitly-installed software
```

not:

```text
literal complete contents of /usr
```

### Then verify against the VM

Once you've created those three files, I'd do one useful reality check on the VM:

```bash
pacman -Qqe
```

That shows packages marked as **explicitly installed**.

Don't blindly copy the output. Instead, compare it against our manifests.

If you want an easy file to inspect:

```bash
pacman -Qqe > ~/explicit-packages.txt
```

Anything in there that we haven't accounted for is worth asking:

> Did I intentionally install this, or was it incidental?

That will give us our definitive package inventory.

After that, I think the next thing should be **capturing your current Sway and Waybar configuration exactly as it exists now**, because unlike the package list, that's genuinely unique to the desktop you've just built. Then we'll decide how chezmoi should represent those files.
