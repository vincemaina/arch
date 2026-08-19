---
id: TASK-12
title: Add a sync path for machines that are already installed
status: To Do
assignee: []
created_date: '2026-08-19 18:15'
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
- [ ] #1 One documented command re-applies dotfiles and reconciles installed packages on a running system
- [ ] #2 The command never touches partitioning, the bootloader or user creation
- [ ] #3 Running it repeatedly is safe and reports what changed
- [ ] #4 It reports, rather than silently applies, anything that needs a session restart to take effect
- [ ] #5 README documents it as the normal day-to-day workflow alongside the fresh-install flow
<!-- AC:END -->
