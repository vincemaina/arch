---
id: TASK-14
title: Use chezmoi templating for per-machine values and profiles
status: To Do
assignee: []
created_date: '2026-08-19 18:15'
labels:
  - repo
  - dotfiles
dependencies: []
priority: medium
type: feature
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
setup/install.conf holds the machine identity but the dotfiles cannot see it, so anything machine-specific has to be hardcoded or left out. That is why there is no output configuration, no touchpad block and no battery handling: what is right for the reference VM is wrong for a laptop. chezmoi templating with a machine profile would let one set of dotfiles cover VM, laptop and desktop without forking them.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Dotfiles can reference the username, hostname and a machine profile without duplicating install.conf
- [ ] #2 A profile is chosen at install time and recorded on the machine for later syncs
- [ ] #3 At least one genuinely machine-specific setting is driven by the profile rather than hardcoded
- [ ] #4 Laptop-only modules and bindings do not appear on a VM install
- [ ] #5 A fresh VM install still completes unchanged
<!-- AC:END -->
