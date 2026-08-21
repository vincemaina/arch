---
id: TASK-91
title: 'Decide the two browsers: one lightweight, one full-fledged'
status: To Do
assignee: []
created_date: '2026-08-21 20:51'
labels: []
dependencies: []
priority: low
type: spike
ordinal: 93000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The desktop should carry two browsers, and only two: a lightweight keyboard-driven one, which qutebrowser already is, and one full-fledged browser for everything qutebrowser cannot do - the sites that need a modern engine's full behaviour, DRM, or an extension.

This exists because checks/packages.sh surfaced firefox as installed by hand and declared nowhere, so a rebuilt machine would not have it. Whether firefox is the right second browser is the actual question, and it is not a question about firefox alone - it is about what the pair should be, which is why it is not being settled as a package-drift line item.

Deliberately low priority: nothing is blocked on it. firefox works today, it simply is not reproducible, and the cost of that is a rebuilt machine missing a browser somebody would notice in the first hour.

Worth settling when picked up: whether the second browser is firefox, a chromium, or a webkit build; whether it needs declaring in desktop.txt or is genuinely occasional enough to install by hand; what qutebrowser actually fails at on this machine, measured rather than assumed, since that is what the second browser is for; and whether the two should share anything - default handler, downloads directory, the xdg-mime entries.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 What qutebrowser cannot do is named from actual use, not assumed
- [ ] #2 The second browser is chosen and declared in a manifest, so a rebuilt machine has both
- [ ] #3 xdg-mime and the default-browser handling name whichever is meant to open a link, and it is verified by opening one
- [ ] #4 The outcome is recorded in DECISIONS.md, which currently has no entry about browsers at all
<!-- AC:END -->
