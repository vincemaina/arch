---
id: TASK-76
title: 'fix: mod + q repeats'
status: To Do
assignee: []
created_date: '2026-08-21 12:21'
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
