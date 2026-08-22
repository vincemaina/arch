---
id: TASK-115
title: The console keymap cannot be reconciled by sync.sh
status: To Do
assignee: []
created_date: '2026-08-22 14:06'
labels: []
dependencies: []
priority: low
type: bug
ordinal: 123000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`KEYMAP` in `setup/install.conf` reaches the machine exactly once, when `03-system.sh` writes `/etc/vconsole.conf` during a fresh install. `sync.sh` has no path for it, so editing `install.conf` on a running machine changes the repository's intent and nothing else.

Found while doing TASK-114: changing the layout to `us` needed a root command typed by hand, because there was no other way to get it there. That is the shape of problem this repository keeps finding at the bottom of a bug - configuration that looks correct and does nothing - and here it is arguably worse than usual, because the context it silently leaves stale is the text console, which is what `Ctrl+Alt+F2` reaches when the graphical session will not start.

The obvious home is `setup/system/apply-config.sh`, which already owns everything machine-wide that both the installer and sync need. The complication is that it does not currently source `install.conf`, and `install.conf` is machine identity rather than system configuration - so this is a question about where that boundary sits, not a one-line change. `checks/session.sh` should probably also assert that `/etc/vconsole.conf` agrees with `install.conf`, since nothing notices today when they disagree.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 sync.sh brings /etc/vconsole.conf into agreement with KEYMAP in install.conf, or a decision is recorded for why it deliberately does not
- [ ] #2 A check fails when the running machine's console keymap disagrees with the repository
<!-- AC:END -->
