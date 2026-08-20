---
id: TASK-34
title: 'Rethink the workspace model, which feels clunky'
status: To Do
assignee: []
created_date: '2026-08-20 12:56'
labels:
  - desktop
  - feel
dependencies:
  - TASK-31
priority: medium
type: spike
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The numbered workspace scheme is not working. Two complaints, and the second is the substantial one.

Numbers feel clunky: switching means naming a slot rather than moving to a thing, and the association between a number and what is in it has to be held in your head.

More importantly, sway binds each workspace to a single output. With two displays you get separate sets of workspaces, one per screen, which is confusing because a workspace is then half a workspace. The wanted model is the one GNOME and macOS use: a workspace spans every display, so it holds a whole task or project across both screens, and you move between them with a single shortcut rather than picking numbers.

Sway does not work that way natively. Options worth weighing, roughly in order of how much they disturb:

A script that switches all outputs together, so workspace N means "N on every screen at once", giving grouped workspaces on top of sway existing model. Cheapest, and the seams will show.

Named rather than numbered workspaces, moved between by direction rather than by index, which addresses the clunkiness without addressing the multi-display problem.

Changing compositor. niri is built entirely around a scrollable model, which is close to what is being described, and Hyprland has its own workspace handling. This overlaps TASK-31: if a compositor change is being considered anyway, the workspace model belongs in that decision rather than being solved twice.

Worth being honest that this is partly unfamiliarity. The numbered model is what tiling window managers do, and a fortnight of use may change the judgement. The multi-display complaint will not go away with familiarity though - that is a genuine difference in model, not a matter of habit.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The behaviour actually wanted is described concretely enough to test against, including what happens on one display versus two
- [ ] #2 Each option is tried far enough to judge, not just read about
- [ ] #3 The multi-display case is evaluated on an actual second display rather than reasoned about
- [ ] #4 Any option requiring a compositor change is fed into TASK-31 rather than decided separately
- [ ] #5 A decision is recorded in DECISIONS.md, and deciding the current model is fine after real use counts as completing this
<!-- AC:END -->
