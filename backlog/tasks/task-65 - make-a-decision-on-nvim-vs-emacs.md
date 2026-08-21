---
id: TASK-65
title: make a decision on nvim vs emacs
status: Done
assignee: []
created_date: '2026-08-21 10:24'
updated_date: '2026-08-21 11:49'
labels: []
dependencies: []
priority: medium
type: spike
ordinal: 67000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
do i just want a text editor that i then connect up with other tools? all do i want a cohesive all in one project envinroment. there are benefits to one, obviously with vim you get flexibility, and possibly a more lightweight system. with emacs i feel like it'd be easier to have something more akin to a full ide, with resumable sessions and everything. this is just off the top of my head though, haven't verified
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Decided: Neovim.

The framing in this ticket was the right one - a text editor connected to other
tools, or a cohesive environment that subsumes them - and Emacs was a serious
answer to the second. org-mode alone would absorb TASK-62 (notes), TASK-63
(todo) and TASK-61's agenda into one system, org-caldav covers the Google
Calendar sync in TASK-61.3, and magit is a strong answer to TASK-45. Four
tickets collapsing into one tool is not a small argument, and the intuition in
this ticket about resumable sessions was correct: desktop.el does that, and it
also speaks to TASK-50.

Rejected in favour of keeping those separate and replaceable. Neovim is 30 MiB
against Emacs at 264 MiB, was already installed, already the handler for
text/plain, and starts fast enough to be what opens when you press enter on a
file in the launcher. Helix was the third candidate - genuinely productive with
no configuration at all, LSP and tree-sitter built in - but has no plugin system
yet, which makes choosing it a bet on never wanting to extend it.

The cost is accepted rather than hidden: notes, todo and calendar stay three
separate builds, and the editor's environment is assembled rather than arriving
whole. TASK-24 is where that assembly happens.

Recorded in DECISIONS.md, together with the file-opening chain that TASK-47
turned out to need, since the two are the same decision from the user's side:
what happens when you choose a file.
<!-- SECTION:FINAL_SUMMARY:END -->
