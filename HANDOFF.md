# Handoff

Temporary. **Read this, act on the two things at the bottom, then delete this
file and commit the deletion.** It exists only to carry state that a git log
does not, and it goes stale fast.

Work up to this point happened on the host, against a VM over SSH and
screenshots. It now continues on the machine itself.

## Read these first

`CLAUDE.md` is the standing guidance and is current — the theming system, the
check scripts, the ordering rules, and the failure mode this repository keeps
hitting. `DECISIONS.md` is the rationale record and is long, but the entries
explain *why* things are the way they are, including two decisions that were
reversed and say so.

Do not re-derive from those files. They are accurate.

## Where things stand

The foundation is built and verified on a machine built from scratch: microcode,
a fallback boot entry, zram with earlyoom, a graphical login through greetd, a
fully supervised session under uwsm, and a sync path so changes reach a running
machine without a rebuild.

The desktop has a design: one palette in `.chezmoidata/palette.toml` driving
sway, the bar, foot, swaylock and the prompt through templates. zsh with
starship, fzf, zoxide, eza and bat. A keybinding scheme with a stated principle
and a check that enforces it.

**Two tasks are In Progress and both need the physical machine:**

- **TASK-8** — everything passes except booting the fallback entry. Reboot,
  pick "Arch Linux (fallback initramfs)" at the menu, confirm it boots. That is
  the whole remaining criterion. Note that `mkinitcpio` v40 stopped building the
  fallback image by default; `apply-config.sh` now enables the preset, so the
  image should exist — `checks/session.sh` verifies it does.
- **TASK-20** — one criterion left: whether XWayland applications render at the
  correct scale. Needs a scaled output to mean anything, so it may not be
  answerable on the current display.

## What to do first

Run `./checks/session.sh` before anything else. It is the fastest way to learn
the state of the machine, and it has found real bugs on every run so far.

## Things worth knowing that are not in the git log

**Verify against the running system, not the file.** Every wrong turn in this
repository came from reasoning about configuration instead of asking what was
actually running. `systemctl show` reports the unit file, not the expansion —
inspect the process. Ask `swaymsg` what it applied. Read the journal before
forming a theory.

**Render templates before trusting them.** `chezmoi --source ./setup
--destination /tmp/render apply --force` renders everything into a scratch
directory. It has caught bugs that reading the template did not.

**Nerd Font glyphs must be written by codepoint**, never pasted. Pasting has
silently lost them twice, leaving `""` where an icon should be, which looks
configured and renders as nothing.

**The user pushes back on aesthetics and is usually right.** A uniform grey bar
and a first set of wallpapers were both rejected as lifeless, and both times the
reference material in `docs/themes/` settled it. Look there before proposing a
visual direction.

**TASK-31 has quietly become load-bearing.** Three tasks now point at it —
compositor effects (31), the workspace model (34), and dynamic tiling (36). The
frustrations behind them may all be one decision about whether sway is the right
compositor, rather than three problems to solve inside sway. Worth raising before
sinking effort into workarounds.

## Housekeeping

Branch `keybinding-model` is well ahead of `main`. Merge it before starting new
work; do not build further on top of an unmerged branch.

`backlog` is the task tool and `CLAUDE.md` requires consulting it before acting.
If it is not installed on this machine, install it from
<https://github.com/MrLesk/Backlog.md>. It is repository tooling and must not go
into `setup/packages/`, which describes the built system.

`docs/wallpapers/*.png` are gitignored candidates. Only the chosen one is
tracked, under `setup/dotfiles/`.

## Then

Delete this file and commit that. If it still exists in a week it is lying about
something.
