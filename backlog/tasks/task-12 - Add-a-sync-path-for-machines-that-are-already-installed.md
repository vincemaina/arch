---
id: TASK-12
title: Add a sync path for machines that are already installed
status: Done
assignee:
  - '@claude'
created_date: '2026-08-19 18:15'
updated_date: '2026-08-19 18:48'
labels:
  - repo
  - workflow
dependencies: []
priority: high
type: feature
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The repository can only build a machine from scratch. install.sh partitions a disk and ends by powering off, and the only dotfile application happens inside the chroot in 05-dotfiles.sh. There is no supported way to pull a change from this repo onto a machine that is already running it, which is exactly the loop we will be in constantly while tuning the desktop. Today that means remembering the right chezmoi invocation by hand.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 One documented command re-applies dotfiles and reconciles installed packages on a running system
- [x] #2 The command never touches partitioning, the bootloader or user creation
- [x] #3 Running it repeatedly is safe and reports what changed
- [x] #4 It reports, rather than silently applies, anything that needs a session restart to take effect
- [x] #5 README documents it as the normal day-to-day workflow alongside the fresh-install flow
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add sync.sh at the repository root, mirroring install.sh: install.sh builds a machine from an ISO, sync.sh updates one that is already running. Both drive setup/ from a clone and neither is copied onto the target.
2. Guard: refuse to run as root, since chezmoi must run as the user and pacman is reached through sudo. Verify chezmoi and pacman are present before doing anything.
3. Reconcile packages using pacman -T against every manifest, so packages satisfied by a provider are not reinstalled. Install only what is missing with pacman -S --needed. Report drift but do not remove anything; removal stays with TASK-13.
4. Apply dotfiles with chezmoi --source setup apply, the same invocation 05-dotfiles.sh uses so the .chezmoiroot redirect to dotfiles/ still applies. Capture chezmoi status before applying so the script can report which files actually changed.
5. Map changed paths to what each one needs to take effect - sway reload, waybar restart, new terminal, re-login - and print that as the closing summary.
6. Support --dry-run so the whole thing can be previewed without touching the machine, and --help.
7. Never reference the install stages that partition, install the bootloader or create users.
8. Document it in README as the day-to-day workflow next to the fresh-install flow, and record in DECISIONS.md why sync is one flat script rather than numbered stages.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented as sync.sh at the repository root, alongside install.sh.

Package reconciliation uses pacman -T rather than looping over pacman -Qq, so a package satisfied by a provider under a different name is not treated as missing and reinstalled on every run. It installs what is missing and never removes anything; drift reporting stays with TASK-13.

Dotfiles use the same chezmoi --source setup invocation as 05-dotfiles.sh, so the .chezmoiroot redirect still applies. chezmoi status is captured before applying, which is what makes both the change report and the restart hints possible.

Verified by running sync.sh against stub pacman, chezmoi and sudo commands on PATH, covering: help, unknown flag, fully-in-sync, dry run with drift, real run with drift, repeat run after a sync, and the missing-dependency guard. Hint mapping produced the correct advice per changed path, and grep confirmed the script references none of the numbered install stages or any destructive command.

Not executed: the refuse-to-run-as-root guard, which was reviewed by inspection only, since the development container has no root available.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added sync.sh, a second root entrypoint that applies the repository to a machine already running it: installs declared packages that are missing via pacman -T plus pacman -S --needed, re-applies dotfiles with chezmoi, and reports both what changed and what needs to restart for it to take effect. Supports --dry-run, refuses to run as root, and references no destructive install stage. Documented in README as the day-to-day loop, with the entrypoint split, the flat-script structure and the never-remove-packages policy recorded in DECISIONS.md. Verified end to end against stub pacman/chezmoi/sudo across seven scenarios including idempotence and the drift path.
<!-- SECTION:FINAL_SUMMARY:END -->
