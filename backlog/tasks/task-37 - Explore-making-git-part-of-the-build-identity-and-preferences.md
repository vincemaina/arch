---
id: TASK-37
title: 'Explore making git part of the build: identity and preferences'
status: To Do
assignee: []
created_date: '2026-08-20 13:43'
updated_date: '2026-08-20 13:44'
labels:
  - dev
  - dotfiles
dependencies: []
priority: low
type: spike
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Committing on a machine freshly built from this repository fails: git has no user.name or user.email, because nothing under setup/ ever sets them. It surfaced the way most bugs here surface - it looked configured right up until it was used. Setting it by hand works, and then has to be remembered again on the next machine.

The idea is to make git configuration part of the build rather than something redone per machine: the identity, and the preferences that otherwise get answered wrong under time pressure - pull strategy (merge, rebase or ff-only), default branch name, push behaviour, and whatever else earns its place.

This is user configuration, so a dot_gitconfig under setup/dotfiles/ is the obvious home, and it would reach a running machine through sync.sh like anything else. But identity is per-machine rather than universal, which puts it next to TASK-14 (chezmoi templating for per-machine values and profiles). That overlap wants resolving, not duplicating.

Two things to weigh honestly. Committing an identity into a public repository publishes an email address that the commit history already exposes anyway, so the cost is low - but it should be a deliberate choice rather than a side effect. And CLAUDE.md is explicit that a dotfile is only committed once there is a meaningful customisation worth preserving: a gitconfig holding nothing but a name and an email may not clear that bar, while one that also settles merge and rebase behaviour probably does.

Raised as an idea rather than a request. Needs discussing before anything is committed to.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 It is decided whether git configuration belongs in the build at all, and deciding against it counts as completing this
- [ ] #2 The split between what is universal and what is per-machine is settled against TASK-14 rather than duplicated
- [ ] #3 Every preference encoded is named with a reason, rather than a generic gitconfig being copied in wholesale
- [ ] #4 Publishing an identity in a public repository is an explicit recorded decision, either way
- [ ] #5 If it goes ahead, a machine built from scratch can commit without any manual git configuration
- [ ] #6 The outcome is recorded in DECISIONS.md
<!-- AC:END -->
