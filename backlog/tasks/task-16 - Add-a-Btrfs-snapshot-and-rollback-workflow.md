---
id: TASK-16
title: Add a Btrfs snapshot and rollback workflow
status: To Do
assignee: []
created_date: '2026-08-19 18:15'
labels:
  - foundation
  - recovery
dependencies: []
priority: medium
type: feature
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
01-disk.sh creates an @snapshots subvolume and mounts it, but nothing ever writes to it. The rollback safety net that motivated choosing Btrfs is therefore only half built, and a bad update currently has no recovery path better than reinstalling. This is a direct contributor to the rock-solid stability goal: it makes updates cheap to undo.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Snapshots are taken automatically around package upgrades
- [ ] #2 A retention policy bounds how much disk snapshots can consume
- [ ] #3 Rolling back to a previous snapshot is documented and has been performed successfully on a VM
- [ ] #4 Snapshots do not recurse into themselves or bloat the root subvolume
- [ ] #5 DECISIONS.md records the tool chosen and the alternatives weighed
<!-- AC:END -->
