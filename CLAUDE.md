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

The only "run" is installing an operating system onto a disk, which is destructive.

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
./install.sh /dev/vda        # or /dev/nvme0n1 on real hardware

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
| `01-disk.sh`, `02-base.sh` | Live ISO, against the repo checkout | `setup/` inside the clone |
| *(copy)* | `cp -a setup/. /mnt/opt/arch-setup/` | — |
| `03-system.sh`, `04-desktop.sh`, `05-dotfiles.sh` | `arch-chroot /mnt` | hardcoded `SETUP_ROOT=/opt/arch-setup` |

So stages 3–5 must only reference paths under `/opt/arch-setup`, and only the contents of `setup/` exist inside the chroot — the repo-level files are deliberately not copied (see the boundary note above).

Stage responsibilities: 01 partitions and mounts, 02 `pacstrap`s base + writes fstab, 03 configures locale/hostname/user/sudo/NetworkManager and installs systemd-boot, 04 installs desktop + dev packages, 05 applies dotfiles.

### `setup/install.conf`

Single source of machine identity (`USERNAME`, `HOSTNAME`, `TIMEZONE`, `LOCALE`, `KEYMAP`), `source`d by `03-system.sh` and `05-dotfiles.sh`. Add new machine-level variables here rather than hardcoding them in a stage. Passwords are intentionally interactive, never stored.

### Package manifests — two different parsers

- `packages/base.txt` is read by `mapfile` **with no filtering**. It must stay one package per line with **no comments and no blank lines**, or pacstrap receives them as package names and fails.
- `packages/desktop.txt` and `packages/dev.txt` are read through `grep -Ev '^[[:space:]]*(#|$)'`, so comments and blank lines are fine and are used for grouping.

Manifests list *intentional top-level* packages, not transitive dependencies. A dependency may still be listed explicitly when the system relies on that capability directly (e.g. `polkit`), so a dependency-graph change cannot silently remove it.

### Dotfiles (chezmoi)

`setup/.chezmoiroot` contains `dotfiles`, so chezmoi's source state is `setup/dotfiles/` only — `install/`, `packages/` and `system/` are not interpreted as home-directory content. Stage 05 runs `chezmoi --source /opt/arch-setup apply` as the target user via `runuser`, with `HOME` set explicitly.

Filenames use chezmoi's source naming: `dot_config/sway/config` → `~/.config/sway/config`. Add new user config by creating the `dot_*` path under `setup/dotfiles/`; nothing else needs to change.

### System config vs user config

Machine-wide configuration is applied by scripts (`setup/system/` templates + `sed`), user configuration by chezmoi. Keep that boundary. `system/loader/arch.conf` is a template: `03-system.sh` substitutes `__ROOT_UUID__` with the real root UUID discovered via `findmnt`/`blkid`.

### Disk layout

GPT/UEFI, 1 GiB FAT32 ESP + Btrfs root, subvolumes `@`, `@home`, `@snapshots`, mounted with `compress=zstd`. `01-disk.sh` detects nvme-style names (trailing digit → `p1`/`p2` suffix). No separate `/home` partition and no full-disk encryption — both are deliberate, see `DECISIONS.md`.

## Conventions

- Every stage script starts `set -euo pipefail` and prints `==>` progress banners.
- Stage scripts are numbered and ordered; keep new work in its own numbered stage rather than growing an existing one.
- New scripts must be committed executable (`git update-index --chmod=+x` or `chmod +x` before adding).
- **`DECISIONS.md` is the rationale record.** It documents *why* each technology and layout was chosen, with trade-offs and rejected alternatives. When making an architectural change, update it in the same style (`## Decision` → `### Why` → `### Trade-off` / `### Alternatives considered`). It is the first place to look before proposing a different tool.
- The guiding principle from `DECISIONS.md`: minimal enough to stay fast and understandable, automated enough to be reproducible, practical enough to use daily. New tooling must earn its place.
- Config for its own sake is avoided — a dotfile is only committed once there is a meaningful customisation worth preserving.

## Known gaps

- `README.md` links to `FLOW.md`, which does not exist yet.
- `setup/packages/CHATGPT.md` is a raw pasted design conversation, superseded by `packages/README.md` and `DECISIONS.md`; treat it as historical, not authoritative.
- `claude-best-practices.md` (untracked) holds the user's general working preferences, not project rules.
