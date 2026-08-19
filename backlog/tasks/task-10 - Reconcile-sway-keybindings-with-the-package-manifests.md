---
id: TASK-10
title: Reconcile sway keybindings with the package manifests
status: To Do
assignee: []
created_date: '2026-08-19 18:15'
labels:
  - foundation
  - desktop
dependencies: []
priority: high
type: bug
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Several bindings in setup/dotfiles/dot_config/sway/config call commands the install never provides, so they fail silently. playerctl is bound for media keys at lines 212-216 but is absent from setup/packages/desktop.txt. The screenshot bindings at lines 245-246 write into ~/Pictures, which nothing creates. polkit is installed but no authentication agent runs, so any GUI privilege prompt fails. The general problem is that the dotfiles and the manifests can drift apart without anything noticing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Media keys control playback on a fresh install
- [ ] #2 Both screenshot bindings save a file successfully on a fresh install
- [ ] #3 A GUI action requiring elevated privileges shows a working authentication prompt
- [ ] #4 Every external command referenced by the sway config resolves to a package listed in a manifest
- [ ] #5 The check for the criterion above is automated so future drift is caught rather than discovered in use
<!-- AC:END -->
