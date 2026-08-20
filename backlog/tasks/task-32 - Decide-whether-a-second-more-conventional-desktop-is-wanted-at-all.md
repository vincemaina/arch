---
id: TASK-32
title: 'Decide whether a second, more conventional desktop is wanted at all'
status: To Do
assignee: []
created_date: '2026-08-20 12:52'
labels:
  - desktop
dependencies: []
priority: low
type: spike
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The idea is an optional desktop environment alongside sway - COSMIC, XFCE or Budgie were mentioned - for times when a conventional desktop suits better than a tiling one. The groundwork already exists: the greeter reads session entries, so a second desktop would appear in the login list on its own, and session components are bound to wayland-session@sway.target rather than the generic graphical target specifically so they cannot leak into another session.

The user described this as a big if, and was explicit that committing to one environment is probably better than maintaining two. That scepticism should be treated as the leading position rather than something to argue past.

The honest case against: a second desktop roughly doubles the surface that has to be themed, configured and kept working, and every piece of polish done for sway would either be duplicated or visibly absent. It also cuts against the stated goal of a minimal system whose complexity is intentional - the repository idles at 550-650 MiB precisely because it installs one of everything.

The honest case for: there are tasks a tiling window manager genuinely handles badly, and having a fallback that is known to work is worth something on a machine that is also being used to learn Arch.

The useful output may well be a recorded decision not to do this, which is worth more than leaving it as a vague possibility that resurfaces every few weeks.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The actual situations where a tiling desktop is the wrong tool are named concretely, rather than assumed to exist
- [ ] #2 The added package and disk cost of each candidate is measured, not estimated
- [ ] #3 What would have to be duplicated to keep both looking deliberate is enumerated
- [ ] #4 A decision is recorded in DECISIONS.md, and deciding not to do it counts as completing this
<!-- AC:END -->
