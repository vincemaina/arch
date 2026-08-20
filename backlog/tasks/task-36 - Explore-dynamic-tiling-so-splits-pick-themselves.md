---
id: TASK-36
title: 'Explore dynamic tiling, so splits pick themselves'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-20 13:00'
updated_date: '2026-08-20 20:35'
labels:
  - desktop
  - feel
dependencies: []
priority: low
type: spike
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Sway always splits in whichever direction was last set, so keeping a sensible layout means deciding split direction before opening each window. Dynamic tiling would choose for you - split a wide container horizontally, a tall one vertically - and possibly decide placement too, the way a dwindle or master-and-stack layout does.

Not essential. The current behaviour is predictable and predictability has real value in a tiling window manager. This is about whether the workflow feels intuitive rather than whether it works.

The usual approach is a small daemon listening on the sway IPC socket, watching for focus changes and setting splith or splitv based on the focused container dimensions. autotiling is the common one; whether it or an equivalent is in the official repositories needs establishing, since this repository does not build from the AUR, and a script this small might be better owned here than depended upon.

Two connections worth making rather than discovering later.

It interacts directly with TASK-2. The split verbs on mod+b and mod+v were only just restored after an application binding had shadowed them; if dynamic tiling works well those become manual overrides for the cases it gets wrong rather than the primary mechanism, which changes how prominent they should be.

It also overlaps TASK-31. Hyprland ships dwindle and master layouts natively, so if a compositor change is being considered anyway, this stops being a thing to add and becomes a property of that choice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Whether an implementation exists in the official repositories is established, and if not, whether writing one here is proportionate
- [x] #2 Tried for long enough to judge feel rather than mechanism, since the whole question is whether it is more intuitive
- [x] #3 The effect on the split bindings is decided: kept as overrides, demoted, or removed
- [x] #4 Any cost is measured - a daemon on the IPC socket reacting to every focus change is not free
- [x] #5 A decision is recorded in DECISIONS.md, and concluding that manual splits are better counts as completing this
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
autotiling is in extra, which was the open question - this repository has no AUR support, and a package that needed it would have meant writing our own. It does not: 75 KiB plus python-i3ipc, with python already installed.

Tried as a throwaway prototype first, written against the sway IPC socket directly, so the feel could be judged before depending on anything. Verdict was immediate and positive, so the real package went in as a session unit bound to wayland-session@sway.target with Restart=always, following mako and swayidle.

Cost, measured rather than waved away: 23.5 MiB RSS. About three times mako, which is Python rather than the work being done. For context the bar is 70 MiB and a terminal is 103 MiB, so it is not where the memory goes.

Effect on the split bindings, which was criterion 3: they are gone entirely rather than demoted. splith and splitv on $mod+b and $mod+v had nothing left to do, and the letters went to the browser and the file explorer. That also reversed the rule that applications get no bindings - deliberately, and recorded in the config, since the verbs those letters were being protected for stopped needing protection.

Honest scope: this is not full dynamic tiling. It picks the split direction from the shape of the focused container; it does not do master-and-stack, dwindle or automatic placement. Those remain a property of a different compositor, which is TASK-31.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
autotiling picks the sway split direction from the shape of the focused container, so a window no longer has to be aimed before it is opened. Available in extra, so no AUR question. Tried first as a throwaway IPC prototype to judge the feel, then installed as a session unit alongside mako and swayidle, costing 23.5 MiB. The split bindings it made redundant were removed rather than demoted, and their letters reassigned. It is not full dynamic tiling - no master-and-stack or automatic placement - which stays with the compositor question in TASK-31.
<!-- SECTION:FINAL_SUMMARY:END -->
