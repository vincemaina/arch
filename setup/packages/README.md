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

## Checking that this is still true

The comparison used to be a manual one: run `pacman -Qqe`, read it
against these files, notice what had changed. It never happened.
`checks/packages.sh`, in the repository rather than on the built
machine, does it instead:

```bash
./checks/packages.sh
```

The model it enforces is the one described above — **these manifests
declare the set of packages that should be explicitly installed** — so
drift is the difference between that set and `pacman -Qqe`, in both
directions. It exits non-zero when the two disagree, so it can gate
other checks. It never installs, removes or re-marks anything; it
prints the command that would.

Which manifest a package is in does not matter to it. `base`/`desktop`/
`dev` says when a package is installed, not whether it is wanted, and
moving a line between two files is not drift.

Four kinds of disagreement, one remedy each:

| Reported | What it means | Remedy |
| --- | --- | --- |
| declared but not installed | the manifest asks for something absent | `./sync.sh`, or drop the line |
| declared but installed as a dependency | present, but pacman will remove it with whatever needs it | `pacman -D --asexplicit` |
| explicitly installed, undeclared, inside the manifests' dependency closure | already arrives anyway; only the marking is wrong | `pacman -D --asdeps` |
| explicitly installed, undeclared, needed by nothing declared | installed by hand; a rebuilt machine would not have it | declare it, or `pacman -Rns` |

The second one is the case this section of the README is about, and it
is not hypothetical: `sync.sh` installs with `pacman -T`, which reports
a package as satisfied when something else already pulled it in. pacman
is then never told the package is wanted in its own right, so listing
`polkit` here does not by itself stop `-Rns` taking it away. The check
is what notices. The same applies one step removed, when the declared
name is a virtual one and the package providing it is the dependency.

It also checks the manifests themselves, because the two parsers do not
agree and the disagreement is invisible on a running machine:
`base.txt` must carry no comments and no blank lines (`02-base.sh` reads
it unfiltered and hands every line to `pacstrap`), every package line
must be a bare package name with no stray whitespace, and no package may
be listed twice.
