# README.md

This project contains my version-controlled, reproducable Arch linux build.
It's designed to be lightweight, minimal, and stable.
Idle memory usage is very low (around 650 MiB).
Idle CPU usage is basically 0%.
And everything is snappy and instant.


## What each dir is for

| Area        | Question it answers                        | Managed by              |
| ----------- | ------------------------------------------ | ----------------------- |
| `packages/` | What software should be installed?         | Our scripts + `pacman`  |
| `install/`  | How do we build the machine?               | Shell scripts           |
| `system/`   | What should global OS config look like?    | Shell scripts/templates |
| `dotfiles/` | What should my user environment look like? | chezmoi                 |

### packages/

Keeps package selection declarative and readable instead of burying it inside
shell scripts.

Then install script can do something like:

```bash
sudo pacman -S --needed - < packages/desktop.txt`
```
So `packages/` answers: what software should this machine have?
Not: how should it be configured?


### install/

This contains executable scripts.

For example:

```
install/
├── 01-disk.sh
├── 02-base.sh
├── 03-system.sh
├── 04-desktop.sh
└── 05-user.sh
```

`01-disk.sh` eventually responsible for things like:

```bash
GPT partition table
EFI partition
Btrfs partition
@ subvolume
@home subvolume
@snapshots subvolume
mounting everything
```

`02-system.sh` would run things like:

```bash
pacstrap
genfstab
```

### system/

Machine-wide configuration

This is for config that belongs outside your home directory.

Think:

```
/etc/...
/boot/...
```

Examples:

```
system/
├── locale.conf
├── hostname
├── loader/
│   ├── loader.conf
│   └── entries/
│       └── arch.conf
└── systemd/
```

So `system/` answers: what should the operating system's global configuration look like?


### dotfiles/

Your personal desktop environment.
This is where things like:

```
~/.config/sway/config
~/.config/waybar/config.jsonc
~/.config/waybar/style.css
~/.config/foot/foot.ini
~/.config/mako/config
```

belong.

And this is where **chezmoi** comes in.

Chezmoi is specifically designed to manage dotfiles across machines. It maintains a source representation and applies that into your home directory.

So conceptually:

```
repo
  │
  └── dotfiles/
       │
       ├── sway config
       ├── waybar config
       ├── foot config
       └── ...
              ↓
           chezmoi
              ↓
~/.config/sway/config
~/.config/waybar/config.jsonc
...
```

That answers: what should Vince's user environment look like?

This is exactly where your Sway shortcuts, border settings, GB keyboard layout, Wofi binding, screenshot shortcuts, Waybar appearance, Mako startup, etc. should live.
