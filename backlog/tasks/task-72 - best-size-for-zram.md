---
id: TASK-72
title: best size for zram?
status: To Do
assignee: []
created_date: '2026-08-21 11:47'
labels: []
dependencies: []
priority: low
type: enhancement
ordinal: 74000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
currently its set of half or ram. but in a previous installation one place recommended setting it to 100% of ram, 150% or even 200%. I don't fully understand but this is perhaps worth looking in to. Perhaps it should also consider how much ram there is first before prescribing zram. i.e. if the user already has 64gb ram, would having zram set to twice that, eat up 128gb of their ssd/hdd storage? or is that not how swaps work, can space reserved for swapped pages still be used for file storage?
<!-- SECTION:DESCRIPTION:END -->
