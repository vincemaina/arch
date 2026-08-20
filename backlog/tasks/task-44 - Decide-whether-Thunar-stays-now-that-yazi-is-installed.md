---
id: TASK-44
title: Decide whether Thunar stays now that yazi is installed
status: To Do
assignee: []
created_date: '2026-08-20 20:37'
updated_date: '2026-08-20 20:37'
labels:
  - desktop
  - repo
dependencies:
  - TASK-27
priority: low
type: spike
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Thunar was picked without a recorded reason. It appears in DECISIONS.md only in passing, inside decisions about other things, so nobody ever wrote down why a GUI file manager belongs on a keyboard-driven tiling desktop.

What it costs: 9.58 MiB, plus roughly 5.5 MiB of XFCE libraries - exo, libxfce4util and libxfce4ui - that exist solely to support it, across a dependency closure of 183 packages.

What it earns is the question. It was not opened once during a full day of work on this machine, and the desktop now has yazi bound to $mod+e, opening floating, and registered as the handler for inode/directory so a folder from the launcher or from a file manager link lands there too.

The objection that would normally settle this does not apply. Losing Thunar would not lose file dialogs: those come from xdg-desktop-portal-gtk, which is a separate package and stays regardless. Save As and Open would be unaffected.

The honest case for keeping it: a GUI file manager is better at a few things a terminal one is not - dragging files between windows, previewing a directory of images at a glance, and being usable when you are not already thinking in keystrokes. Those are real, and none of them came up today, which is either evidence that they do not matter here or evidence that a fortnight is a better sample than a day.

The decision should be made on use rather than taste: if Thunar goes untouched for a fortnight while yazi is bound to a key, that is the answer.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The decision is made on observed use over a fortnight, not on preference, and deciding to keep Thunar counts as completing this
- [ ] #2 If it goes, thunar leaves packages/desktop.txt along with the XFCE libraries that exist only for it, and the window rule that floats it
- [ ] #3 File dialogs are confirmed still working afterwards, since they come from xdg-desktop-portal-gtk rather than from Thunar
- [ ] #4 Whatever a GUI file manager does better is named concretely, so the decision records what is being given up rather than implying nothing is
- [ ] #5 The outcome is recorded in DECISIONS.md, which currently has no entry explaining why a file manager was chosen at all
<!-- AC:END -->
