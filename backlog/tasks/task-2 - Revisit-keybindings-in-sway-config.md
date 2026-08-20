---
id: TASK-2
title: Redesign the keybinding model
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-19 15:27'
updated_date: '2026-08-20 00:37'
labels:
  - desktop
  - feel
dependencies:
  - TASK-17
priority: high
type: enhancement
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The bindings are still essentially the sway defaults with a few app launchers bolted on, and two of those collide with core layout verbs: mod+b at line 147 overwrites splith and mod+e at line 153 overwrites layout toggle split. So two fundamental tiling operations were traded for launching a browser and a file manager. The wider question is what the interaction model should be - which actions deserve a bare chord, which belong behind a mode, and how to keep it coherent as more is added - rather than accumulating bindings one at a time.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Core layout operations are all reachable again, including the split verbs currently shadowed
- [ ] #2 The binding scheme follows a stated organising principle rather than being ad hoc
- [ ] #3 Application launching does not consume bindings needed for window management
- [ ] #4 No binding is defined twice or silently overridden
- [ ] #5 The scheme is documented so it can be extended consistently later
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. State the organising principle in the fragment header: $mod is window management, one key opens the launcher, and applications get no bindings of their own. Every future binding has to answer to that.
2. Move the launcher from $mod+d to $mod+space.
3. Rehome focus mode_toggle, which currently owns $mod+space, to $mod+Tab. Alt+Tab already toggles between the last two workspaces, so $mod+Tab toggling between the tiling and floating layers is the same idea at a different scope.
4. Restore the three shadowed sway defaults: $mod+b splith, $mod+v splitv, $mod+e layout toggle split.
5. Drop the qutebrowser and thunar bindings. With no application bindings there is nothing left to collide with window management, which is the actual fix rather than relocating the collision.
6. Leave $mod+d unbound rather than finding it a job.
7. Change nothing else. Screenshots, media keys, workspaces, scratchpad, resize mode and Alt+Tab are existing choices and not this task to churn.
8. Add checks/sway-bindings.sh to detect a binding defined twice across fragments, and to print the full table, which doubles as the documentation of the scheme.
9. Record the principle in DECISIONS.md.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Scheme implemented and pruned with the user, who is new to sway and asked for a recommendation rather than a list to choose from blind.

Principle: $mod is window management, nothing else takes a $mod chord, one binding per action. Applications get no bindings and are launched from $mod+space, which the user chose over $mod+d. The terminal on $mod+Return is the single deliberate exception.

Restored the three shadowed defaults: $mod+b splith, $mod+v splitv, $mod+e layout toggle split. Dropped the qutebrowser and thunar bindings that had taken two of them.

Removed by agreement: the eight arrow-key duplicates of h/j/k/l and their Shift moves; $mod+s stacking, which does the same job as tabbed; Ctrl+Alt+arrows and Alt+Tab, replaced by $mod+Tab for back_and_forth; and focus mode_toggle. Also removed the four arrow duplicates inside resize mode, applying the same reasoning, which was flagged to the user rather than done silently.

Kept on my recommendation, with an explanation of what each does since they were unfamiliar: splits, tabbed, scratchpad, focus parent, and the full block of ten workspaces.

80 bindings to 64. checks/sway-bindings.sh reports no duplicates.
<!-- SECTION:NOTES:END -->
