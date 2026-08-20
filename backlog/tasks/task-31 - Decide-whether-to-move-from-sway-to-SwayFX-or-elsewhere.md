---
id: TASK-31
title: 'Decide whether to move from sway to SwayFX, or elsewhere'
status: To Do
assignee: []
created_date: '2026-08-20 12:52'
updated_date: '2026-08-20 16:13'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fed in from TASK-34, which decided to keep sway workspace model rather than script around it, and referred the compositor question here.

Two requirements have now been stated concretely enough to judge a compositor against, and they pull in different directions:

Workspaces that span every display, so one workspace holds a task across both screens. sway cannot do this and the difference is structural, demonstrated on two outputs rather than reasoned about.

An overview: a way to see all workspaces at once and drag or reorder them. sway has no exposé of any kind, and the community tools for it - sov, swayr - are not in the official repositories, which matters because this repository has no AUR support.

The overview requirement is the harder constraint. Spanning can be approximated with a script; an overview cannot be built at all.

How the candidates answer them. niri: per-monitor workspaces, so no spanning, but a first-class overview with keyboard and pointer navigation, window relocation and workspace reordering - the best keyboard-driven tiling of the three. COSMIC: the only one offering spanning natively, as an explicit setting, plus an overview and per-workspace tiling, at the cost of less mature tiling. Hyprland: per-monitor, overview through plugins, which is a maintenance surface.

The decision this reduces to: whether spanning workspaces or the quality of tiling and overview matters more. They cannot both be maximised. Note that with one display today, the spanning question is unfalsifiable in daily use, which argues for judging on tiling and overview now and revisiting spanning when a second screen exists.

Sources are recorded in the DECISIONS.md entry "Workspaces stay per-output, as sway does them".
<!-- SECTION:NOTES:END -->
