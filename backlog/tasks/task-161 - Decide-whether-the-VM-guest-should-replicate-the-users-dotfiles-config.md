---
id: TASK-161
title: Decide whether the VM guest should replicate the user's dotfiles/config
status: To Do
assignee: []
created_date: '2026-08-24 09:05'
labels:
  - vm
  - discussion
dependencies:
  - TASK-69.1
priority: low
ordinal: 170000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Idea raised while discussing the VM tooling (TASK-69 family): make the guest environment self-replicating, copying over some of the user's own configuration (shortcuts were mentioned specifically) so the VM feels close to the real desktop, without carrying accumulated personal files (downloads, wallpapers, etc.). The user was explicitly unsure this is a good idea - a blank-slate guest may be more useful for some purposes than a mirrored one. This task is to have that discussion and record a decision before any implementation, not to build it yet.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Decide, and record the reasoning in DECISIONS.md or this task, whether the VM guest should replicate any of the host user's config
- [ ] #2 If yes: scope exactly what replicates (e.g. keybindings/shortcuts only vs. broader dotfiles) and how it stays reproducible rather than becoming another config source to keep in sync
- [ ] #3 If no: close this task documenting why a blank-slate guest was preferred
<!-- AC:END -->
