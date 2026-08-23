---
id: TASK-144.1
title: Write the three-layer rule down as a decision
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 11:40'
updated_date: '2026-08-23 11:42'
labels: []
dependencies: []
parent_task_id: TASK-144
type: docs
ordinal: 149000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
DECISIONS.md gains the rule and the reasoning; the manual gains a short section telling a reader where their own changes go. Includes recording the two measured facts - no exact_ dirs, and create_ semantics - because both are the kind of thing the next person would otherwise re-derive.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 DECISIONS.md states the three layers and why profiles are a separate thing
- [x] #2 The manual tells a reader where to put a change of their own, per tool
- [x] #3 checks/manual.sh passes and the manual builds
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Generalised the existing '## Machine-local dotfile changes' decision rather than adding a competing one - it already had the right three-way model (universal / declared per-machine / machine-local scratch) and a table for it, but had only ever implemented the shell case.

Added: the two measured facts (no exact_ dirs, so drop-ins already survive; create_ writes once and never overwrites, verified against a scratch destination under apply --force), the layer table, the per-tool include support taken from each tool's own manual, and a subsection saying why profiles are a separate mechanism.

Manual chapter 5 gains 'Changes this machine keeps'. It documents ONLY what exists today - zsh local, sway and environment.d 99-* drop-ins, /etc/keyd/local - because checks/manual.sh fails on a path the manual names that does not exist, and foot/mako/git arrive with TASK-144.3.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
DECISIONS.md's machine-local decision now describes a general layer rather than a shell-only escape hatch: three layers, which one applies decided by what each tool supports, the two measured facts underneath it, and why machine profiles remain separate. Manual chapter 5 gains a reader-facing section on where a change of your own goes. Verified with checks/manual.sh 8/0 and a clean manual build.
<!-- SECTION:FINAL_SUMMARY:END -->
