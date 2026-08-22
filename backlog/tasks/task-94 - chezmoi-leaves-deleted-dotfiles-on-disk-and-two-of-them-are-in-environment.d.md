---
id: TASK-94
title: 'chezmoi leaves deleted dotfiles on disk, and two of them are in environment.d'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 21:11'
updated_date: '2026-08-22 00:01'
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
- [x] #1 The two stale files are gone from the reference machine by a mechanism a rebuild reproduces, not by rm
- [x] #2 A dotfile deleted from setup/dotfiles/ in future is removed from machines that already have it, or a check reports that it was not
- [x] #3 The check distinguishes a genuinely orphaned target from one that was re-added under a different chezmoi source name, such as a plain file becoming a .tmpl
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Both files removed through .chezmoiremove rather than rm, so a rebuild reproduces it (AC1). Verified inert before removing rather than assuming: the user manager's PATH contains no ~/.local/bin and no unexpanded $PATH, and xdg-terminal-exec now resolves to /usr/local/bin - so 20-path.conf was doing nothing, as ea2af45 concluded. 10-cursor.conf was not inert: it duplicated XCURSOR_THEME and XCURSOR_SIZE and sorts after the 10-appearance.conf that replaced it, so it won.

AC2 and AC3 are a new session.sh section. It replays every deletion under setup/dotfiles/ out of git history, maps each chezmoi source name back to its target path - stripping the attribute prefixes and .tmpl, turning dot_ into a leading dot - and reports any that still exist on disk while no longer being managed.

THE CHECK PASSED WHEN IT SHOULD HAVE FAILED, AND THAT WAS THE INTERESTING PART. Written, run, green on the first attempt. Putting 10-cursor.conf back by hand and re-running produced green again.

Cause: 'chezmoi managed' lists every path in .chezmoiremove as well, because managing a file's removal is a kind of managing it. The check asked 'is this target still managed?' to avoid reporting a file re-added under a different source name - which is correct and necessary - and that same question made it skip precisely the files it was written to find. It would have passed forever.

Fixed by subtracting .chezmoiremove from the managed set. Now: with a stale file present it fails naming the path; with the machine clean it passes; and the four files that were deleted and re-added as .tmpl - waybar's config.jsonc and style.css, foot.ini, yazi.toml - all exist on disk and are correctly not reported, which is AC3 demonstrated rather than argued.

Recorded in the scripting-traps skill, both the chezmoi behaviour and the general form: a check that has never failed has not been tested.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The two stale environment.d files are gone via .chezmoiremove, so a rebuild reproduces their absence, and checks/session.sh now replays every deletion under setup/dotfiles/ and reports any target still on disk that chezmoi no longer manages. The check passed on first writing and the passing was the bug: 'chezmoi managed' includes .chezmoiremove paths, so it skipped exactly the files it existed for. Proven working by putting a stale file back and watching it fail, and proven not to false-positive on the four files that were deleted and re-added as templates.
<!-- SECTION:FINAL_SUMMARY:END -->
