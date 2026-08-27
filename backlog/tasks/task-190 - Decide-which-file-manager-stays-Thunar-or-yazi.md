---
id: TASK-190
title: 'Decide which file manager stays: Thunar or yazi'
status: To Do
assignee: []
created_date: '2026-08-27 10:45'
labels: []
dependencies:
  - TASK-189
ordinal: 196000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-189 puts Thunar on $mod+e and moves yazi to $mod+Ctrl+e so both are genuinely reachable. This task closes the question afterwards: one of them goes.

Two file managers for one job is exactly what this repository argues against, and it is tolerable only while this ticket exists - the same bargain TASK-110 struck for the two Escape bindings and TASK-178 for the two browsers. If you are reading this and it is still open after a month, that is the finding.

WHAT IS ACTUALLY BEING COMPARED

Cost is not the question; it is already measured and Thunar loses it (20.5 MiB and 7 packages against yazi, which is already installed). The question is which one the hand reaches for, and only using both answers that.

The specific things worth watching, because they are what yazi was said to be weak at:
- Bulk work. Moving, renaming and organising many files at once, which is the complaint that started this - yazi suits small tasks handled quickly.
- Looking at a directory of images. Thumbnails are the strongest argument for a GUI file manager and the thing TASK-44s Thunar could not do.
- Dragging a file into another window, which yazi cannot originate at all.
- Whether vim keys in Thunar actually feel like vim keys, or like a GUI wearing them.
- Whether $mod+Ctrl+e gets pressed at all.

HOW TO SETTLE IT

TASK-44 settled the last one on REACHABILITY rather than taste, because nothing routed to Thunar and two days was not long enough to measure preference. That shortcut is not available this time - both are on a key, both are in the launcher - so this one has to be settled on use. Give it a fortnight of real work.

The measurements TASK-189 should have left behind: cold start keypress-to-mapped-window for both, by the method TASK-177 used for the browsers (foot 135ms, vimb 354ms, qutebrowser 1673ms), and what each leaves resident after the window closes.

WHATEVER IS DECIDED

Remove the loser properly - its binding, its window rule, its $explorer entry, its packages, its manual section - and record the reasoning in DECISIONS.md next to the section TASK-189 writes. If Thunar goes, that section becomes the second reversal of the same decision and should say so plainly rather than being deleted, the way TASK-44 reproduced the decision it reversed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Both file managers have been used for real work over at least a fortnight, and the notes say what each was actually reached for
- [ ] #2 Cold-start times and resident-after-close figures for both are recorded, by the method TASK-177 used
- [ ] #3 One file manager is chosen, and the other is removed completely: binding, window rule, $explorer, packages, manual section
- [ ] #4 DECISIONS.md records the outcome and the reasoning, including the honest answer if the reason is taste rather than measurement
- [ ] #5 checks/session.sh, checks/packages.sh, checks/sway-bindings.sh and checks/manual.sh all pass after the removal
<!-- AC:END -->
