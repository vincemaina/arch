---
id: TASK-144.3
title: 'Local include files for sway, foot, mako and git'
status: To Do
assignee: []
created_date: '2026-08-23 11:40'
labels: []
dependencies: []
parent_task_id: TASK-144
type: feature
ordinal: 151000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The override layer for the four tools reached for most often. Each tracked config gains an include of a create_ file, seeded with a comment explaining what it is for and never rewritten afterwards. foot needs an absolute path, so its include line has to be templated.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each of the four has a local file that is created once and never overwritten
- [ ] #2 The include is last, so a local setting wins
- [ ] #3 A missing or empty local file breaks nothing
- [ ] #4 checks/session.sh passes
<!-- AC:END -->
