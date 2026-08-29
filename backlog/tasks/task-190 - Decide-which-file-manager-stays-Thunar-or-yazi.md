---
id: TASK-190
title: 'Decide which file manager stays: Thunar or yazi'
status: Done
assignee: []
created_date: '2026-08-27 10:45'
updated_date: '2026-08-29 14:40'
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

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
ANSWERED BY TASK-196, IN THE NEGATIVE: neither file manager goes.

This task's premise was that one of them had to. That premise is this repository's standing argument - two things doing one job is a smell - and it is sound where the two are INTERCHANGEABLE, which is what made it work for the two browsers (TASK-178) and the two Escape keys (TASK-110). The fortnight of use this task asked for showed it does not hold here. yazi and Thunar were not being compared; they were being used for different work. yazi is what the hand reaches for, and Thunar was reached for rarely and specifically, for four things yazi cannot do at all: a directory of thumbnails, a bulk rename with a preview column, dragging a file into another window, and a sidebar of mounted drives.

So deleting Thunar would have removed capabilities rather than a duplicate, and doing it anyway would have been a rule outranking the evidence it exists to serve. This task asked which one wins; the answer is that the question was wrong.

TASK-196 put the choice behind ~/.local/bin/explorer instead - $mod+e opens the selected one, $mod+Ctrl+e opens the other, default yazi - and recorded the reasoning in DECISIONS.md as 'Both file managers stay, behind explorer --use', with the 20.5 MiB this task was written to reclaim named as knowingly not reclaimed. The 'Running both permanently' alternative inside the TASK-189 entry is now marked as the one that won.

AC #1 and #2 are left unchecked honestly. The fortnight of real use happened and is what settled it, but no cold-start or resident-after-close figures were taken by TASK-177's method beyond the ones docs/software/README.md already carries, and the decision did not rest on them. AC #3 is unchecked because nothing was removed - that is the outcome, not an omission. AC #4 and #5 are TASK-196's, and are recorded there.
<!-- SECTION:FINAL_SUMMARY:END -->
