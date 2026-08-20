---
id: TASK-31
title: 'Decide whether to move from sway to SwayFX, or elsewhere'
status: To Do
assignee: []
created_date: '2026-08-20 12:52'
labels:
  - desktop
  - foundation
dependencies: []
references:
  - 'https://github.com/WillPower3309/swayfx'
priority: medium
type: spike
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Rounded window corners, blur and shadows keep coming up while shaping the look, and baseline sway supports none of them. It has no compositing effects at all by design. Two rounding attempts have already been shelved for this reason.

SwayFX is a fork of sway that adds exactly those effects and is otherwise a drop-in replacement, so the existing configuration would largely carry over. It is AUR-only, which is the real cost: this repository installs everything from official packages, and building from the AUR means either an AUR helper or manual makepkg, unreviewed PKGBUILDs, and a package that tracks upstream sway releases and can therefore lag on a rolling distribution.

Hyprland is the other direction people go for the same reasons. It is in the official repositories, has effects built in, and is actively developed - but it is a different compositor with its own configuration language, so the sway config, the keybinding scheme and the session wiring would all need rewriting rather than porting.

The decision should be made on evidence rather than screenshots. Effects cost GPU work and memory, and this setup idles at 550-650 MiB and is meant to never drop a frame. That matters more here than on a machine with a dedicated GPU, and TASK-26 has not yet established whether there is hardware acceleration at all.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Idle memory and CPU measured on the same hardware for each option considered, not quoted from elsewhere
- [ ] #2 Frame timing under normal use compared, since never dropping a frame is the stated goal
- [ ] #3 The maintenance cost of each is assessed honestly, including what happens when upstream sway releases and the fork has not caught up
- [ ] #4 How much of the existing configuration survives each option is established rather than assumed
- [ ] #5 A decision is recorded in DECISIONS.md, including the case for staying on plain sway
<!-- AC:END -->
