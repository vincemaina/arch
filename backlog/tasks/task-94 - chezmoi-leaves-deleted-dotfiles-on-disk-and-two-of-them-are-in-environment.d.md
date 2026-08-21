---
id: TASK-94
title: 'chezmoi leaves deleted dotfiles on disk, and two of them are in environment.d'
status: To Do
assignee: []
created_date: '2026-08-21 21:11'
labels:
  - desktop
  - repo
dependencies:
  - TASK-58
ordinal: 96000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
chezmoi apply never removes a file the source state has stopped shipping. So a dotfile deleted from setup/dotfiles/ stays on every machine that already had it, and the running machine quietly stops matching what a rebuild would produce.

Two are live on the reference VM right now, found by replaying every deletion under setup/dotfiles/ out of git history and checking which target paths still exist and are no longer in 'chezmoi managed':

  * ~/.config/environment.d/10-cursor.conf - deleted from the repo in 87abc7c, when its contents moved into 10-appearance.conf.
  * ~/.config/environment.d/20-path.conf - deleted in ea2af45, after that commit established that environment.d cannot prepend to PATH and moved xdg-terminal-exec to /usr/local/bin instead.

environment.d is the worst directory for this to happen in. The user manager reads *.conf in lexicographic order and the last file wins, so 10-cursor.conf sorts AFTER 10-appearance.conf and would override any cursor change the repo makes - on this machine only, and not on a fresh one. That is a difference between the running system and a rebuild that no check would report and no diff would show. 20-path.conf is inert, but it is inert for a reason the file itself contradicts at length, which is worse than absent.

Neither is a fault in the two commits: chezmoi genuinely does not do this, and both were correct to delete the source file. What is missing is the other half - either a chezmoi 'remove_' entry, a .chezmoiremove file, or a check that notices.

Note that most of what this search turns up is a false positive: a file deleted and re-added as a .tmpl is still managed under a different source name. Compare against 'chezmoi managed', not against git alone. tools/session-inventory.sh does this for ~/.config/environment.d specifically.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The two stale files are gone from the reference machine by a mechanism a rebuild reproduces, not by rm
- [ ] #2 A dotfile deleted from setup/dotfiles/ in future is removed from machines that already have it, or a check reports that it was not
- [ ] #3 The check distinguishes a genuinely orphaned target from one that was re-added under a different chezmoi source name, such as a plain file becoming a .tmpl
<!-- AC:END -->
