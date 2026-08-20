---
id: TASK-34
title: 'Rethink the workspace model, which feels clunky'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-20 12:56'
updated_date: '2026-08-20 16:13'
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
- [x] #1 The behaviour actually wanted is described concretely enough to test against, including what happens on one display versus two
- [ ] #2 Each option is tried far enough to judge, not just read about
- [ ] #3 The multi-display case is evaluated on an actual second display rather than reasoned about
- [x] #4 Any option requiring a compositor change is fed into TASK-31 rather than decided separately
- [x] #5 A decision is recorded in DECISIONS.md, and deciding the current model is fine after real use counts as completing this
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Behaviour established on two real outputs rather than reasoned about. A second output was created with swaymsg create_output, which gives a genuine sway output with genuine workspace semantics without needing physical hardware, and the visible display was never disturbed.

What sway actually does. Workspaces belong to exactly one output. With Virtual-1 showing 1,2,3 and a second output showing 4: pressing the binding for a workspace on the current output switches that output, as expected. Pressing the binding for a workspace living on the other output does not bring it over - it moves focus to the other output instead. So the switch sends you to the workspace rather than bringing the workspace to you. That is the "half a workspace" complaint, and it is structural.

A promising-looking dead end, worth recording so it is not tried again. Search results claim `workspace <name> output A B` makes a workspace span both displays. It does not. sway(5) is explicit: "Multiple outputs can be listed and the first available will be used" - it is a priority list with failover, not spanning. Reading the manual rather than trusting the summary saved building on a false premise.

Landscape, from research:

sway - no spanning, and no overview of any kind. The two matches for overview/expose in sway(5) are about laptop lid switches and an exposed keypad, not window management.

niri - per-monitor vertical workspace stacks, so it does NOT solve spanning either. It does have a first-class Overview: a zoomed-out view of all workspaces with keyboard and pointer navigation, window relocation and workspace reordering, which is precisely the visualise-and-drag ask.

Hyprland - per-monitor by default, with overview available through plugins (hyprexpo, Hyprspace) that do support dragging between monitors. Plugins are a maintenance surface.

COSMIC - offers both models as an explicit setting: "Workspaces span multiple displays" or "Displays have separate workspaces". Also has a native overview and per-workspace tiling. It is the only option found that provides the wanted model natively rather than by script or plugin.

KDE Plasma - virtual desktops span all monitors by default, and it has an overview. Notably it is adding per-screen desktops in 6.7 after twenty-one years of requests, which is evidence that the spanning model has real costs rather than being straightforwardly better.

GNOME - workspaces apply only to the primary monitor by default; spanning is a settings change.

The cost of the wanted model, which the ask has not yet accounted for. In span mode both displays switch together, so a video or reference document on the second screen cannot stay put while the first screen changes. That is the trade-off, and it is exactly what KDE users spent two decades asking to opt out of. Worth deciding deliberately rather than discovering later.

Additional requirement raised during this work: a way to visualise all workspaces and drag or reorder them. sway cannot do this at all - no overview exists, and the community tools for it (sov, swayr) are not in the official repositories, which matters because this repository has no AUR support. This requirement pushes considerably harder toward a compositor change than the spanning question alone does.

Current urgency is lower than it appears: this machine has one display. The multi-display pain is anticipated rather than being felt daily, whereas the reach-for-the-number-row complaint is felt now and is compositor-independent.

Closed as a deliberate no. Criteria 2 and 3 are left unchecked rather than ticked, because they were genuinely not satisfied and pretending otherwise would misrepresent what this decision rests on.

#2 asked that each option be tried far enough to judge. sway behaviour was tried and demonstrated; niri, COSMIC and Hyprland were researched but not run. That is enough to decide "keep sway for now" - which requires only knowing that no cheap fix exists within sway - but it is not enough to decide which compositor to move to. That decision is TASK-31 and will need them actually installed.

#3 asked for evaluation on an actual second display. A second sway output was created with swaymsg create_output, which has genuine workspace semantics and was sufficient to demonstrate the structural behaviour, but it is not a physical second monitor and says nothing about what living with two screens daily feels like.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Decided not to pursue synchronised or spanning workspaces: sway model stays as it is, where each workspace belongs to one output. The behaviour was demonstrated on two real outputs rather than argued about - switching to a workspace living on another output moves focus there instead of bringing the workspace over - and the claim that `workspace <name> output A B` spans displays was checked against sway(5) and found false, it being a failover list. Scripting grouped switching was rejected because the machine has one display so the problem is anticipated rather than felt, the seams are predictable, and it would be discarded if the compositor changed. The cost of the wanted model was also recorded, since the request had not accounted for it: where workspaces do span, both screens switch together, which is what KDE users spent twenty-one years asking to opt out of. The compositor options that would provide the model natively have been fed into TASK-31 along with the overview requirement, which is the harder constraint since sway cannot provide one at all. Criteria 2 and 3 are deliberately left unchecked: the alternatives were researched rather than run, and a headless output is not a second monitor.
<!-- SECTION:FINAL_SUMMARY:END -->
