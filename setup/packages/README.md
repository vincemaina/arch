# Packages

This directory defines the software that this Arch installation is
intended to have installed.

These files are a convention used by this repository. They are not
special Arch Linux or chezmoi files.

## Manifests

- `base.txt` — packages required for the core bootable Arch system.
- `desktop.txt` — Sway and supporting graphical desktop software.
- `dev.txt` — development and terminal productivity tools.

Each manifest contains one Arch package per line.

Installation scripts pass these manifests to `pacman` or `pacstrap`.

## Philosophy

The manifests describe intentional top-level requirements rather than
every package currently installed on the machine.

Dependencies should normally not be added merely because they appear in
`pacman -Q`.

However, a dependency may be listed explicitly when the system relies
on that capability directly. For example, `polkit` may be listed even
if another desktop package currently installs it transitively.

This prevents changes to dependency graphs from unexpectedly removing a
capability the system relies on.

`pacman -Qqe` can be used to inspect packages currently marked as
explicitly installed and compare them against these manifests.
