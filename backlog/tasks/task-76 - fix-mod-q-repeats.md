---
id: TASK-76
title: 'fix: mod + q repeats'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 12:21'
updated_date: '2026-08-21 13:54'
labels: []
dependencies: []
priority: high
type: bug
ordinal: 78000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
currently we have our system setup to be snappy with quick key repeats. that applies to everything, including the mod + q shortcut. meaning that it's very easy to mistakenly shut down all your windows. key repeats should not apply to the mod + q operation, and also for several others e.g. toggling workspaces, toggling scratchpad.

in fact a whitelist system would be better. key repeats should basically available for standard text entry, for mod + shift + h/j/k/l (i.e. moving windows - particularly in floating mode), and also resizing windows. there may a few other things where it makes sense but broadly thats the idea.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Holding $mod+q closes one window, not every window on the workspace
- [x] #2 Repeat is off by default and on by exception, rather than the reverse
- [x] #3 Holding volume or brightness still steps continuously, since that is the one place repeat is expected
- [x] #4 Nudging a window and resizing still repeat, since a single press is never enough in floating mode
- [x] #5 A binding added later without --no-repeat fails a check rather than quietly becoming repeatable
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Key repeat is now off by default and on by exception.

sway repeats a binding while the key is held unless --no-repeat says
otherwise, and repeat_rate is 40 here because text entry wants it. Together
that made a slightly-long press on $mod+q close every window on the
workspace. 54 bindings gained --no-repeat.

12 kept repeat, each because holding the key is the gesture: nudging a window
with $mod+Shift+h/j/k/l, which in floating mode moves by pixels; the same keys
inside the resize mode; and volume and brightness, where holding is how they
are expected to work. Workspace toggling and the scratchpad, both named in the
report, are among those that no longer repeat.

Focus movement was considered and deliberately excluded - not destructive, but
discrete, and at this rate holding $mod+l overshoots. The reasoning is written
into the config so the next reader does not have to guess.

checks/sway-bindings.sh enforces it: any binding without --no-repeat that is
not on the whitelist fails the check. Verified by removing the flag from
$mod+q and watching the check name it.
<!-- SECTION:FINAL_SUMMARY:END -->
