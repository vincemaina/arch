---
id: TASK-126
title: >-
  Re-count the niri cost analysis in DECISIONS.md, which brands itself counted
  rather than estimated
status: To Do
assignee: []
created_date: '2026-08-22 18:13'
updated_date: '2026-08-22 18:13'
labels:
  - repo
dependencies: []
priority: low
type: chore
ordinal: 130000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
DECISIONS.md's 'What it would cost, counted rather than estimated' section, under the decision to stay on sway rather than move to niri, states several figures: 609 lines of compositor config, 69 keybindings, 19 window rules, eight helper scripts speaking sway IPC, and six pieces of repository tooling parsing sway's config syntax or IPC.

Two of them have already been found stale and corrected in passing, both by the same removal: the workspace greeter was counted as one of four sway features with no niri equivalent, and the helper-script figure said nine. The second was verified against 665bee5^ - nine before TASK-113 deleted the greeter, eight after.

The rest were not verified, and at least one looks wrong on its face: the section says 69 keybindings, while the commit that closed TASK-113/116/117 records checks/sway-bindings.sh reporting 76. TASK-119, TASK-120, TASK-122, TASK-123 and TASK-124 have all changed bindings since, though mostly at the keyd layer rather than sway's.

The point is not that the figures must be perfect. It is that this section explicitly claims to be counted rather than estimated, which is what makes it persuasive, and a stale count spends that credibility. Either re-count and correct them, or say plainly what date they were counted on so a reader knows what they are looking at.

Worth deciding while doing it: what a 'keybinding' counts as here, since sway bindings, binding modes and keyd-level remaps are three different things and the current figure does not say which it means.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every figure in that section is either re-counted against the current tree or dated
- [ ] #2 What a keybinding counts as is stated, since sway bindings, modes and keyd remaps are three different things
- [ ] #3 The counting method is recorded, so the next reader can repeat it rather than re-inventing it
<!-- AC:END -->
