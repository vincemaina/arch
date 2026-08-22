# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

<!-- BACKLOG.MD GUIDELINES START -->
<!-- backlog.md-instructions-version: 1.50.1 -->
<CRITICAL_INSTRUCTION>

## Backlog.md Workflow

This project uses Backlog.md for task and project management.

**For every user request in this project, run `backlog instructions overview` before answering or taking action.**

Use the overview to decide whether to search, read, create, or update Backlog tasks.

Before task lifecycle actions, read the matching detailed guide:
- `backlog instructions task-creation` before creating or splitting tasks
- `backlog instructions task-execution` before planning, changing status or assignee, adding a plan or implementation notes, or implementing task work
- `backlog instructions task-finalization` before checking acceptance criteria, writing final summaries, or moving tasks to terminal statuses

Use `backlog <command> --help` before running unfamiliar commands. Help shows options, fields, and examples.

Do not edit Backlog task, draft, document, decision, or milestone markdown files directly. Use the `backlog` CLI so metadata, relationships, and history stay consistent.

</CRITICAL_INSTRUCTION>
<!-- BACKLOG.MD GUIDELINES END -->

## What this repository is

A version-controlled, reproducible **Arch Linux system build** — package manifests, install scripts, system config and user dotfiles. It is not an application: there is no build system, no test suite, no linter and no package manager for the repo itself. Everything here is Bash, plain text manifests, and config files.

There are two entrypoints: `install.sh` builds a machine from the live ISO and is destructive; `sync.sh` applies the repository to a machine already running it and is safe to repeat. Reach for `sync.sh` when iterating — a change is not worth a full rebuild until it is worth a reproducibility test.

### `setup/` is the only thing that becomes the Arch system

**Nothing outside `setup/` ends up on the built machine.** `README.md`, `DECISIONS.md`, `CLAUDE.md`,
`claude-best-practices.md` and `backlog/` exist to develop, document and manage *this repository*;
they are never copied onto the target system and their tooling is never installed on it.
(`install.sh` is the exception in kind, not in placement — it orchestrates the build but runs from
the live ISO and is not copied either.)

Two consequences worth holding onto:

- Tools used to work on the repo (`backlog`, Claude Code, anything else) must never be added to
  `setup/packages/*.txt`. Those manifests describe what the *built machine* should have.
- Anything a chroot stage genuinely needs at install time must live under `setup/`, because that is
  the only directory copied into the new filesystem.

## Commands

```bash
# Full install. Run as root from a booted Arch live ISO. ERASES the target disk.
# Asks for this machine's identity first, defaulting to whatever install.conf
# already says - so pressing Enter through it changes nothing.
./install.sh /dev/vda        # or /dev/nvme0n1 on real hardware
./install.sh --no-wizard /dev/vda   # skip the questions entirely
# A run whose stdin is not a terminal skips the wizard on its own, so an
# existing scripted build needs no new flag.

# Update a machine that is already running this setup. Safe and repeatable.
# Run as the normal user, never root.
./sync.sh
./sync.sh --dry-run       # preview: the package diff, then a chezmoi diff

# Does the running machine match what the repo intends? Run this after any change.
./checks/session.sh

# Does every command the session invokes come from a declared package?
# Needs a real Arch system (uses pacman and pactree).
./checks/sway-commands.sh

# Is any key bound twice? Prints the full binding table.
./checks/sway-bindings.sh

# Does what is installed match the manifests, in both directions?
./checks/packages.sh

# Does the manual still describe a system that exists?
./checks/manual.sh

# A report, not a check: every shortcut, grouped by the context it applies in.
./tools/shortcuts.sh

# Build docs/manual/ into one self-contained HTML page and open it.
./tools/manual.sh --open

# Backlog task management (see the CRITICAL_INSTRUCTION block above)
backlog task list
backlog task create "..."
```

`backlog` is a repo-management tool, not part of the built system. If it is missing, install it from
[MrLesk/Backlog.md](https://github.com/MrLesk/Backlog.md) — see the "Project Management" section of
`claude-best-practices.md`. Do **not** add it to `setup/packages/`.

Individual stages under `setup/install/` can be run on their own for debugging, but the paths they expect differ depending on where they run — see "Two execution contexts" below.

**Testing = a fresh VM.** There is no unit test. Changes are validated by building a new VM from the repository and confirming the system comes up correctly (`DECISIONS.md` → "Testing Strategy"). Prefer a fresh install over patching the reference VM; a script that works on an already-configured machine proves nothing about reproducibility. Never test the installer against the current machine.

## Architecture

### Two execution contexts — the key thing to understand

`install.sh` runs the five stages in two different environments, and the payload is copied between them:

| Stage | Runs where | Root path it uses |
| --- | --- | --- |
| `00-wizard.sh`, `01-disk.sh`, `02-base.sh` | Live ISO, against the repo checkout | `setup/` inside the clone |
| *(copy)* | `cp -a setup/. /mnt/opt/arch-setup/` | — |
| `03-system.sh`, `04-desktop.sh`, `05-dotfiles.sh` | `arch-chroot /mnt` | hardcoded `SETUP_ROOT=/opt/arch-setup` |

So stages 3–5 must only reference paths under `/opt/arch-setup`, and only the contents of `setup/` exist inside the chroot — the repo-level files are deliberately not copied (see the boundary note above).

Stage responsibilities: 01 partitions and mounts, 02 `pacstrap`s base + writes fstab, 03 configures locale/hostname/user/sudo/NetworkManager and installs systemd-boot, 04 installs desktop + dev packages, 05 applies dotfiles.

`sync.sh` is the third context: it runs on a fully installed machine, as the normal user, from a git clone. It must never reference the numbered stages — anything it calls has to be safe to run repeatedly on a live system. `checks/` shares that context: repository tooling that reads `setup/` and inspects the live system, never copied onto it.

### Session components are systemd user units

The machine boots to greetd/ReGreet, which launches `uwsm start -N Sway -D sway -- sway`. The `.desktop` form — `uwsm start -- sway.desktop` — is what this line used to say and is exactly what must *not* be used; `setup/system/wayland-sessions/sway-uwsm.desktop` explains why at length, and this file contradicted it until TASK-23 checked.

mako, swayidle, the polkit agent, autotiling and the workspace greeter are user units in `setup/dotfiles/dot_config/systemd/user/`; Waybar's unit ships with its package, so the repo carries only a `waybar.service.d/override.conf` drop-in. All six are enabled by committed symlinks in `wayland-session@sway.target.wants/` rather than `systemctl --user enable` (which has no user session inside the installer chroot).

Bind session components to **`wayland-session@sway.target`, never `graphical-session.target`** — the generic target is reached by every compositor, so a unit wanted by it would also start under a different desktop. Add a session component as a unit, not a sway `exec` line; an `exec` gets no supervision. A plain `sway` launch reaches no session target at all, so nothing starts — which is why login is graphical.

Helper scripts in `dot_local/bin/` must carry a `# requires:` header listing the external commands they call; `checks/sway-commands.sh` fails if one does not.

### System configuration has one source of truth

`setup/system/apply-config.sh` owns everything machine-wide that both paths need,
which is more than the name suggests: the mapping from repository file to `/etc`
destination, enabling `earlyoom` and `greetd`, the whole initramfs story (microcode
hook, re-enabling the `fallback` preset that mkinitcpio v40 stopped shipping, and a
*conditional* `mkinitcpio -P` because regenerating is slow), and disabling
`NetworkManager-wait-online`. Machine-wide work belongs here, not in a stage script.

`04-desktop.sh` calls it at the end of a fresh install and `sync.sh` calls it with
`--activate`, so a new system config file is added in exactly one place and reaches
both paths. Adding one to only the installer means it can never reach a running
machine — that was a real bug, caught by `checks/session.sh`.

`--activate` is the whole difference between the two callers. Without it the script
only writes files and enables units, which is all the installer chroot can do. With
it, the change also takes effect now — and failures there warn rather than abort,
because the configuration is already written and one service that will not restart
should not fail the whole sync. **greetd is deliberately never restarted**: it owns
the session of whoever is running `sync.sh`.

Bootloader templates under `setup/system/loader/` are the exception: they are
rendered with the machine's root UUID at install time and must never be applied by
sync.

### `setup/install.conf`

Single source of machine identity (`USERNAME`, `HOSTNAME`, `TIMEZONE`, `LOCALE`, `KEYMAP`, `GIT_NAME`, `GIT_EMAIL`), `source`d by `03-system.sh` and `05-dotfiles.sh`, and read a second way by `dot_gitconfig.tmpl` through chezmoi's `include "../install.conf"`.

**`setup/install/00-wizard.sh` is the only writer of this file other than a human.** It rewrites just the `KEY="value"` lines, leaves every comment in place, refuses values containing `"`, `\`, `` ` `` or `$`, and sources the result back in a clean environment before replacing the original. The quoting is load-bearing in two directions now: `source` has to accept it *and* the gitconfig template's regex has to match it. Add new machine-level variables here rather than hardcoding them in a stage. Passwords are intentionally interactive, never stored.

### Package manifests — two different parsers

- `packages/base.txt` is read by `02-base.sh` with a bare `mapfile` and **no filtering**. It must stay one package per line with **no comments and no blank lines**, or pacstrap receives them as package names and fails.
- `packages/desktop.txt` and `packages/dev.txt` are read by `04-desktop.sh` through `grep -Ev '^[[:space:]]*(#|$)'`, so comments and blank lines are fine and are used for grouping.
- `sync.sh` is the asymmetry to watch: it globs `packages/*.txt` — `base.txt` included — through the comment-stripping grep. So a comment added to `base.txt` breaks a fresh install while sync keeps working, which means it will not show up on the machine you are testing on.

Manifests list *intentional top-level* packages, not transitive dependencies. A dependency may still be listed explicitly when the system relies on that capability directly (e.g. `polkit`), so a dependency-graph change cannot silently remove it.

**That last sentence describes an intention, and until TASK-13 nothing delivered
it.** Listing a package that something else already pulls in does not make
pacman treat it as wanted in its own right: `pacman -T` reports it satisfied so
`sync.sh` never installs it, and `pacman -S --needed` skips an installed package
without changing its install reason. `polkit` itself was marked "installed as a
dependency" on the reference machine, along with `mesa`, `adwaita-cursors` and
`xdg-desktop-portal-gtk` - so removing whatever pulled them in would have taken
them, exactly as if they had never been listed. Both install paths now mark
every declared package explicit after installing, and `checks/packages.sh`
fails if one drifts back.

### Dotfiles (chezmoi)

`setup/.chezmoiroot` contains `dotfiles`, so chezmoi's source state is `setup/dotfiles/` only — `install/`, `packages/` and `system/` are not interpreted as home-directory content. Stage 05 runs `chezmoi --source /opt/arch-setup apply` as the target user via `runuser`, with `HOME` set explicitly.

Filenames use chezmoi's source naming: `dot_config/sway/config` → `~/.config/sway/config`. Add new user config by creating the `dot_*` path under `setup/dotfiles/`; nothing else needs to change.

### System config vs user config

Machine-wide configuration is applied by scripts (`setup/system/` templates + `sed`), user configuration by chezmoi. Keep that boundary. `system/loader/arch.conf` is a template: `03-system.sh` substitutes `__ROOT_UUID__` with the real root UUID discovered via `findmnt`/`blkid`.

### Disk layout

GPT/UEFI, 1 GiB FAT32 ESP + Btrfs root, subvolumes `@`, `@home`, `@snapshots`, mounted with `compress=zstd`. `01-disk.sh` detects nvme-style names (trailing digit → `p1`/`p2` suffix). No separate `/home` partition and no full-disk encryption — both are deliberate, see `DECISIONS.md`.

## Theming: several palettes, one selected, all templated

`setup/dotfiles/.chezmoidata/themes.toml` holds every colour of every theme,
including the sixteen ANSI terminal colours. Sway
appearance, the Waybar stylesheet, foot, rofi, mako, swaylock and the starship
prompt are all `.tmpl` files that resolve the selected theme in their first line
and read from it, so **changing a colour means editing that one file and running
`sync.sh`** — never edit a rendered colour in place, it will be overwritten and
the others will drift.

Names are by role (`accent`, `urgent`, `muted`), not by colour.

**Which theme is selected is machine-local**, in `~/.config/chezmoi/chezmoi.toml`
under `[data]`, deliberately not in the repository — so switching leaves no diff.
chezmoi merges config data *over* `.chezmoidata`, which is what makes the tracked
default in `themes.toml` work for the installer, which has no config file at all.
`~/.local/bin/theme` is the switcher and `~/.local/bin/wallpaper` picks the
background style within a theme, remembered per theme. `theme --current` and
`wallpaper --current` are how you find out what a machine is actually wearing,
because git no longer tells you.

**Both write the same file, through one writer.** `~/.local/lib/desktop_config.py`
is the only thing that reads or writes `chezmoi.toml`. They each had their own
copy once and the copies disagreed about nested tables, which turned
`[data.wallpaper]` into a string and broke every subsequent `apply`. Add a
machine-local value through that helper, not by hand.

Three things worth holding onto before touching a theme:

- **Every theme must be a dark theme.** GTK reads `GTK_THEME` once at session
  start and stays Adwaita dark, so a light theme would leave every dialog looking
  like a different computer. See `DECISIONS.md`.
- **Every theme must define every key every other theme defines**, or selecting it
  fails at render. `checks/session.sh` checks this, along with two contrast floors
  that were both learned by breaking them.
- **Adding a theme costs no bytes.** Wallpapers are generated on the machine by
  `~/.local/bin/wallpaper` from the theme's own colours, in one of four styles,
  and cached in `~/.local/share/wallpapers/`. Nothing image-shaped is tracked,
  and `checks/session.sh` fails if anything image-shaped appears in
  `setup/dotfiles/` — committing them grew by ~10M per theme, which is backwards.

Nothing here reads colours at runtime — every consumer holds a rendered copy — so
a change has to be reloaded into each one. That is
`run_onchange_after_reload-theme.sh.tmpl`, which re-runs whenever the theme name,
the wallpaper style or a hash of the selected palette changes. The three lines
carrying them read like comments and are load-bearing. foot is the one consumer that cannot reload at
all: terminals already open keep their colours.

To check a template renders before applying it anywhere:

```bash
mkdir -p /tmp/render
chezmoi --source ./setup --destination /tmp/render apply --force
```

The `mkdir` is not optional: chezmoi creates directories *below* the destination
but not the destination itself, and without it every theme fails identically with
what looks like a template error.

That catches template errors, and lets you read what a consumer will actually
receive. It has already caught a real bug: swaylock takes colours without a
leading `#`, unlike every other consumer.

**It is not entirely a dry run.** `setup/dotfiles/` contains `run_onchange_`
scripts, and chezmoi runs scripts regardless of `--destination`. Rendering to a
scratch directory still executes them against the real system — the mime-defaults
script really does call `xdg-mime` on your machine, and the theme-reload script
really does restart your waybar. Templates are safe to render; scripts are not
sandboxed by pointing chezmoi elsewhere. **Add `--exclude=scripts`** when you only
want to see what a template produces.

Nerd Font glyphs must be written **by codepoint**, not pasted. Pasting has lost
them silently more than once, leaving `""` where an icon should be — which looks
configured in the file and renders as nothing. The same applies to *editing*:
a scripted `replace` whose match string contains a pasted glyph matches nothing
and reports nothing, so assert every replacement and match on the key rather than
the value. See the `scripting-traps` skill.

## The bar is clickable

Every module in `waybar/config.jsonc.tmpl` does something when clicked, and the
table at the top of that file is the record of what. Three of them open a window
through `~/.local/bin/sway-toggle-window`, so clicking twice closes it.

Two things will silently break it, and `checks/session.sh` covers both:

- **waybar's PATH is not your PATH.** It runs as a systemd user service, so
  `~/.local/bin` is not on it — `.zshrc` puts it there and applies to interactive
  shells only. Click commands must be absolute, which is why that file is a
  `.tmpl`. A helper calling a *sibling* helper by bare name fails the same way.
- **The `app_id` ties three files together**: the command that sets it, the
  toggle that finds the window by it, and the `for_window` rule that floats it.
  Nothing else notices when they disagree; the window just tiles.

## Checks

Five scripts, run from the repo on the target machine:

| Script | Answers |
| --- | --- |
| `checks/sway-commands.sh` | Does every command the session invokes come from a declared package? |
| `checks/sway-bindings.sh` | Is any key bound twice? Prints the full binding table. |
| `checks/session.sh` | Does the running machine match what the repo intends? |
| `checks/packages.sh` | Does what is installed match `packages/*.txt`, both ways? |
| `checks/manual.sh` | Does the manual still name files, helpers and bindings that exist? |

`tools/` holds things that produce output rather than verdicts.
`tools/shortcuts.sh` lists every shortcut by context and flags keys that mean
different things in different tools; `--markdown` emits the same table for the
manual to embed. `tools/manual.sh` builds `docs/manual/` into one HTML page. Keep the distinction: `checks/` exits
non-zero on a problem, `tools/` produces something to read. Neither reaches the
built machine — which is why the wallpaper generator lives in `dot_local/bin/`
and not here: it is the one piece of the theming machinery that has to run on
the built machine.

`checks/session.sh` is the one to run after any change. It covers swap, the OOM
handler, session units, the boot path, the greeter's session list, the shell,
the wallpaper and dotfile references.

## The failure mode this repository keeps hitting

Nearly every bug found here has been **invisible**: configuration that looks
correct and does nothing. Media keys calling an uninstalled binary. Screenshots
written to a directory nothing created. polkit with no agent. A theme `include`
pointing at a file that does not exist. Empty icon strings. A boot entry naming
an initramfs that was never built. A greeter offering a session that bypassed
uwsm.

One variant worth naming separately: a **fix that did not work, kept anyway**.
The SPICE guest agent was installed to stop a ghost cursor, did not stop it, and
stayed - with a manifest comment describing the hypothesis it was tried under as
though it were the outcome. Read that comment a month later and the package is
load-bearing. It was not. When a fix fails, take it back out, or write down that
it failed where the next reader will look.

None announced itself; several had been broken since the config was first
committed. Two consequences for how to work here:

- **Verify against the running system, not the file.** Ask `swaymsg` what it
  applied, ask `systemctl` what is running, ask the process what arguments it
  received. `systemctl show` reports the unit file, not the expansion.
- **When something is wrong, read the log or the source before theorising.**
  Every wrong guess in this repo's history took longer than the two minutes it
  would have taken to look.

## Two ordering rules, both learned the hard way

**Packages before configuration.** A unit only exists once its package is
installed. `apply-config.sh` runs at the end of `04-desktop.sh`, not in `03`,
because enabling greetd before the desktop manifest is installed aborts the
install. `sync.sh` reconciles packages, then system config, then dotfiles, then
the login shell — which is last because switching shells before its rc exists
hands over a broken shell.

**Session components use `Restart=always`, not `on-failure`.** They have no
legitimate reason to exit, and `pkill` terminates cleanly — which `on-failure`
correctly does not treat as a failure, so the component stays dead.

## Skills

`.claude/skills/` holds what previous sessions had to work out the hard way, so
it is not rediscovered a fourth time. They load on demand; read the one that
matches before starting.

| Skill | Load it when |
| --- | --- |
| `desktop-verification` | Changing anything visual. How to screenshot and actually look, test on a throwaway output without disturbing the user's screen, trial keybindings at runtime, and ask each program what it applied. |
| `sway-capability-limits` | Someone asks for blur, shadows, rounding, an overview, focus-based opacity, HiDPI or workspaces spanning displays. All established as impossible here, with the evidence. |
| `scripting-traps` | Writing a check, editing a config programmatically, killing a process, or building a menu for rofi. Concrete footguns, each of which produced a confident wrong result rather than an error. |

Like `backlog/` and this file, they are repository tooling and never reach the
built machine.

## The manual

`docs/manual/` is the only document here written to be *read* rather than
consulted: ten chapters on using the desktop and on changing it, for someone
who has never seen this repository. It is the fifth documentation surface after
this file, `README.md`, `FLOW.md` and `DECISIONS.md`, and it should not restate
any of them — it links across instead.

Two rules keep it honest, and both exist because prose goes stale exactly the
way configuration does. Anything derivable from the configuration is generated
from it: chapter 3 contains the line `{{shortcuts}}` and no shortcut table at
all. Anything asserted by hand is checked: `checks/manual.sh` fails when the
manual names a file, a helper script or a `$mod` binding that does not exist,
and it caught a real drift within an hour of being written.

The markdown dialect is restricted and `tools/manual-render.py` **refuses**
what it does not understand rather than approximating it. The dialect and the
reasoning are in `docs/manual/README.md` and in `DECISIONS.md`. Like everything
else here, the manual is repository tooling: nothing it needs may be added to
`setup/packages/`, which is why there is no pandoc. `sync.sh` installs the
built page so the `manual` command and the launcher entry can open it.

## The hook that keeps the record

`.claude/hooks/keep-the-record.sh` runs at `SessionStart` (to note where the
session began) and at `Stop`. It compares what changed against three things
this repository is known to forget, and blocks the end of the turn once if any
is unanswered:

- **The manual.** If a keybinding, helper script, bar module, theme, package,
  session unit, install path or check changed and `docs/manual/` did not, it
  names the chapter that most likely covers it.
- **The software record.** If a file under `setup/packages/` changed and
  neither `docs/software/README.md` nor `DECISIONS.md` did, it says so — and
  names the packages actually added or removed, by diffing the manifest
  against the session's own baseline, rather than saying "something changed".
  A package added and removed again in the same session, or a comment-only
  edit that adds or drops no package line, produces nothing to name and stays
  silent.
- **The backlog.** If files changed and no task file was touched, it says so.
  It deliberately does **not** report on every In Progress task — several have
  been open for weeks, and nagging about those at the end of an unrelated turn
  is how a hook trains you to ignore it.

It asks **once per session per reason**, keyed on a hash of the message, so a
new reason still gets through and nothing can loop. Addressing it and saying
why it does not apply are equally valid answers. Its state lives in
`.claude/state/`, which is ignored; `<session>.ran` is appended on every Stop
so that "never invoked" and "nothing to report" cannot be confused, which is
the exact shape of silence that hides bugs here.

Like everything in `.claude/`, it is repository tooling and never reaches the
built machine.

## Reference material

`docs/themes/` holds screenshots of other people's setups, collected as
inspiration. Look there before proposing a visual direction: a uniform grey bar
and a first set of wallpapers were both rejected as lifeless, and both times the
reference material settled it. `docs/wallpapers/` documents how wallpapers are generated;
no image is tracked anywhere in this repository. `screenshots/` holds captures of this setup, taken to review
changes to how it looks.

## Conventions

- Every stage script starts `set -euo pipefail` and prints `==>` progress banners.
- Stage scripts are numbered and ordered; keep new work in its own numbered stage rather than growing an existing one.
- New scripts must be committed executable (`git update-index --chmod=+x` or `chmod +x` before adding).
- **`DECISIONS.md` is the rationale record.** It documents *why* each technology and layout was chosen, with trade-offs and rejected alternatives. When making an architectural change, update it in the same style (`## Decision` → `### Why` → `### Trade-off` / `### Alternatives considered`). It is the first place to look before proposing a different tool.
- The guiding principle from `DECISIONS.md`: minimal enough to stay fast and understandable, automated enough to be reproducible, practical enough to use daily. New tooling must earn its place.
- Config for its own sake is avoided — a dotfile is only committed once there is a meaningful customisation worth preserving.
- **Merging and pushing to `main` is reserved for the user by default in Claude Code's harness — that reservation is explicitly lifted in this repository.** See "Finishing work in a worktree" below for what that means in practice.

## Finishing work in a worktree

An agent that finishes a task in a worktree finishes the whole thing. Do not
stop at "the branch is pushed" and ask whether to merge: the user said once
that merging and pushing to `main` is allowed here and would rather not repeat
it every session. This does not extend to force-pushing `main`, and it is
specific to this repository.

So, when the work is done and the task is closed in Backlog:

1. **Merge into `main`** with `--no-ff` and a `Merge TASK-nn: <what changed>`
   subject, matching the existing merge commits.
2. **Re-run the checks on merged `main`,** not only on the branch. That is the
   first moment the work and whatever landed while it was out exist together,
   and it is the run that matters. If it fails, fix it before pushing.
3. **Push `main`.**
4. **Clean up:** `git worktree remove` the worktree, then delete its branch both
   locally (`git branch -d`) and on the remote (`git push origin --delete`).
5. **Say so plainly:** the work is merged and pushed, the worktree and branch
   are gone locally and on the remote, and the conversation is ready to close.

Two things to check around step 4, because a worktree here is rarely the only
one. `git worktree list` may show worktrees belonging to *other* sessions,
sometimes `locked` — remove only your own. And `main` may have moved while you
worked: pull before pushing rather than assuming the merge is still a
fast-forward. Both have already happened during a single task.

Step 4 is not only tidiness. A worktree is a checkout with a deadline, and this
repository has already been bitten once by one outliving the state that pointed
at it — `sync.sh` recorded a worktree path as the machine's chezmoi source, the
worktree was deleted, and `chezmoi managed` then returned nothing without ever
erroring (TASK-121.1). That specific hole is closed, but the fewer stale
worktrees linger, the less there is to point at nothing.

## Known gaps

- `README.md` links to `FLOW.md`, which does not exist yet.
- `backlog` is not installed on every machine this repository gets worked on, so the CRITICAL_INSTRUCTION at the top of this file can fail with `command not found`. Install it from [MrLesk/Backlog.md](https://github.com/MrLesk/Backlog.md) rather than falling back to editing `backlog/tasks/*.md` by hand — and never add it to `setup/packages/`.
- `claude-best-practices.md` (untracked) holds the user's general working preferences, not project rules.
