---
id: TASK-144.4
title: Give waybar a local override that can actually win
status: To Do
assignee: []
created_date: '2026-08-23 12:57'
labels: []
dependencies: []
parent_task_id: TASK-144
priority: medium
type: feature
ordinal: 154000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
waybar failed BOTH tests the local layer requires, and for different reasons in each half.

Its JSON include is safe when the file is missing (waybar keeps running, measured), but its precedence is documented as the opposite of every other tool here: 'in case of duplicate options, the first defined value takes precedence, i.e. including file -> first included file'. So a local file could add keys and never change one - a file that silently ignores half of what you put in it, which is worse than no file because the failure looks like the user's mistake.

Its stylesheet is worse: a missing CSS @import makes waybar exit 1, and waybar.service is Restart=always, so a deleted local stylesheet is a crash-looping bar. That is mako's failure mode exactly.

The fix for the config half is a wrapper: config.jsonc becomes a thin managed file containing only an include of [local.jsonc, base.jsonc], with the repository's real configuration moved to base.jsonc. Because the including file wins and the first include beats the second, local.jsonc would then take precedence over the repository.

Not done inline with the rest of the local layer because config.jsonc is named by seven other files - tools/performance.sh, three dot_local/bin helpers, setup/system/greetd/regreet.toml, checks/session.sh and the manual - and the theme reload script hashes it. Restructuring it needs each of those checked and a fresh VM build to be sure the bar still comes up.

The stylesheet half may have no safe answer at all. If it does not, say so where a reader will look rather than leaving the asymmetry unexplained.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A setting in waybar's local file overrides the same setting in the repository's config, demonstrated rather than assumed
- [ ] #2 A missing or empty local file leaves the bar running
- [ ] #3 Every file that names config.jsonc still works, including checks/session.sh and the theme reload
- [ ] #4 The stylesheet half is either solved or its absence is documented with the measurement behind it
<!-- AC:END -->
