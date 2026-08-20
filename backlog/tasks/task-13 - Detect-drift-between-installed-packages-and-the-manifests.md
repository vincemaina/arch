---
id: TASK-13
title: Detect drift between installed packages and the manifests
status: To Do
assignee: []
created_date: '2026-08-19 18:15'
labels:
  - repo
  - workflow
dependencies: []
priority: low
type: chore
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
packages/README.md describes comparing pacman -Qqe against the manifests to find packages that were installed ad hoc or are listed but unused, but this is a manual chore that will not happen reliably. Automating it keeps the manifests honest as the intentional description of the system.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A script reports packages explicitly installed but not in any manifest
- [ ] #2 It also reports packages listed in a manifest but not installed
- [ ] #3 It exits non-zero when drift is found so it can gate other checks
- [ ] #4 It ignores the distinction between manifest files rather than requiring a package to be in a specific one
<!-- AC:END -->
