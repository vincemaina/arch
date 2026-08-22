---
id: TASK-105
title: A complete manual for using and editing this system
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 10:27'
updated_date: '2026-08-22 11:06'
labels: []
dependencies: []
ordinal: 107000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The repository documents itself well for whoever is building it - DECISIONS.md carries the rationale, FLOW.md the install path, CLAUDE.md the architecture, docs/software/ the roll call. What none of them is, is a manual: a document you read to learn how to *use* this desktop, and how to change it, without already knowing how it was made.

That gap is felt most by the person who has to come back to this machine after six months, and by anyone else who is handed it. Features have accumulated faster than any record of them - a launcher, themes, a wallpaper library, focus music, a focus timer, clipboard history, a notification centre, scroll layers below the compositor - and the only way to find out what exists is to read the source.

Deliver a manual in docs/manual/, written as markdown chapters, covering both halves: using the system day to day, and editing it. It must be exportable to a single PDF for reading away from the machine.

The manual must not be allowed to drift. This repository's recurring failure is configuration that looks correct and does nothing; a manual that describes a keybinding that no longer exists is the same failure in prose. Anything derivable from the configuration should be generated from it, and anything asserted by hand should be checkable.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A reader who has never seen this repository can, from the manual alone, log in, move around the desktop, and find every feature the system offers
- [x] #2 A reader can, from the manual alone, add a package, a dotfile, a keybinding, a theme and a session unit, and knows which of install.sh and sync.sh applies their change
- [x] #3 The keyboard reference is generated from the actual configuration rather than maintained by hand
- [x] #4 The whole manual builds into one self-contained file that can be printed to PDF, with no package added to setup/packages/
- [x] #5 A check fails if the manual names a file, command or keybinding that does not exist
- [x] #6 The manual is discoverable from README.md and from the machine itself
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Fix the chapter list and the markdown subset the builder accepts, and write that down first so six chapters can be written in parallel against one spec.
2. Build tools/manual.sh: stdlib-only renderer, one self-contained HTML, generated keyboard chapter from tools/shortcuts.sh, refuses unsupported markdown.
3. Write the ten chapters (subtasks .2 to .5), each verified against the running system rather than the config file.
4. checks/manual.sh: every path, helper, command and keybinding named in the manual must exist. Prove it fails on a wrong reference.
5. Discoverability: README.md table entry, and a way to open it from the desktop.
6. Record the no-pandoc decision in DECISIONS.md.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Ten chapters in docs/manual/, about 12,000 words, split into using it (1-6) and editing it (7-10). Written by four workers in parallel against one dialect spec, then fact-checked as a whole by a fifth, which found four real errors that individual verification had missed.

FORMAT CHANGED MID-TASK, at the user request and for the better. The ticket said exportable to a single PDF; the user clarified that PDF was only ever a means to an end - one cohesive document instead of ten files somebody has to open individually, with links between sections. HTML delivers exactly that and is cheaper: no exporter was ever built, since "print to PDF" was always just Ctrl+P in a browser. The build now targets one self-contained HTML page with a contents column that stays on screen, tracks where you are, and folds away the chapters you are not reading. The print stylesheet stays because it costs nothing. AC#4 is met more directly than it was written.

Two things stop it drifting, and both were exercised in anger:
  * Chapter 3 contains no shortcut table. It contains the line {{shortcuts}}, and tools/shortcuts.sh --markdown generates the whole reference from the sway and zsh configuration. The terminal report is unchanged; both formats now write through the same heading/row/note/para helpers so they cannot disagree.
  * checks/manual.sh caught chapter 2 describing $mod+Shift+minus within an hour of being written, when TASK-106 rebound the scratchpad. Its limit is documented as carefully as its function: it sees existence, never meaning, and $mod+minus itself sailed through while meaning something completely different.

Verified by looking, not by assuming. Rendered headless into a scratch firefox profile so nothing touched the user session. First pass had every contents entry underlined and unreadable; restyled. The print stylesheet was exercised by rewriting @media print to @media screen in a copy.

One investigation worth keeping. The sidebar rendered blank whenever the capture URL carried a fragment, and it would have been easy to blame the CSS. Measured instead: a fragment matching NOTHING rendered perfectly, a position:fixed probe element was also missing, and scroll position was 0. Firefox headless --screenshot fires before the anchor scroll and drops composited layers - a capture artifact, not a page bug. The hunt did surface a genuine bug on the way: the scroll handler called scrollIntoView, which scrolls every scrollable ancestor including the window, so clicking a chapter in the contents would have thrown the page back to the top. It now moves only the contents column, and only when that column can move.

Checks: manual 8/8, session 92/0, packages clean, sway-commands clean, sway-bindings 74 with no duplicate.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
docs/manual/ is ten chapters on using and editing this desktop, built by tools/manual.sh into one self-contained HTML page with a persistent contents column and links between every chapter - no package added to setup/packages/, since HTML never needed pandoc. The keyboard reference is generated from the configuration and checks/manual.sh fails when the manual names anything that does not exist, which it did within an hour of being written. Reachable from README.md, from CLAUDE.md, from the manual command and from the launcher.
<!-- SECTION:FINAL_SUMMARY:END -->
