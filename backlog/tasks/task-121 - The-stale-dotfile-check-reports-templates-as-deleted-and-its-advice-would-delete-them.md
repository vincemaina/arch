---
id: TASK-121
title: >-
  The stale-dotfile check reports templates as deleted, and its advice would
  delete them
status: Done
assignee: []
created_date: '2026-08-22 16:07'
updated_date: '2026-08-22 17:12'
labels:
  - repo
dependencies:
  - TASK-94
priority: high
type: bug
ordinal: 125000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
checks/session.sh fails with seven files it says were deleted from setup/dotfiles/ but are still on disk, and tells you to add them to .chezmoiremove and run sync.sh:

  .config/foot/foot.ini
  .config/sway/config.d/30-appearance.conf
  .config/waybar/config.jsonc
  .config/waybar/style.css
  .config/yazi/keymap.toml
  .config/yazi/yazi.toml
  .local/share/applications/notification-centre.desktop

None of them were deleted. Every one is still shipped as a template - foot.ini.tmpl renders to foot.ini - and the check appears to compare target paths against source filenames without stripping the .tmpl suffix, so a file that was converted to a template reads as one that vanished.

Confirmed two ways rather than inferred from the file listing: chezmoi managed lists all seven as still managed, and chezmoi status reports the machine matching the repository exactly.

The reason this is worth a ticket rather than a note is the advice. Adding those paths to .chezmoiremove tells chezmoi to delete them, so the next sync.sh would remove the foot config, the waybar config and stylesheet, the sway appearance fragment, both yazi configs and the notification-centre launcher entry from the machine - and chezmoi would then try to put them back, since it still manages them. A check that fails wrongly is a nuisance; one that hands you a destructive fix is worse than not having it.

Worth checking whether the same comparison misses the other chezmoi source prefixes as well - dot_, executable_, private_, symlink_ - since a file that is executable or a symlink would presumably read as deleted for the same reason. The check currently passes for those only because none happen to have been removed.

Also worth deciding what the check should do about the genuine case it was written for, which is real: TASK-94 found two files in environment.d that the repository had stopped shipping and were still active on disk.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A dotfile converted to a template is not reported as deleted
- [x] #2 The other chezmoi source prefixes are handled too - dot_, executable_, private_, symlink_ - rather than only .tmpl
- [x] #3 The genuine case TASK-94 was written for still fails: a file the repository has actually stopped shipping and is still on disk
- [x] #4 The check is exercised against both cases before being trusted, since it currently passes for prefixed files only because none have been removed
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause found, and it is not the .tmpl suffix this ticket first guessed at. The check already handles source-name changes correctly - its own comment says so and the code strips prefixes and suffixes.

The fault is that it calls bare `chezmoi managed` with no --source. chezmoi then reads sourceDir from ~/.config/chezmoi/chezmoi.toml, which sync.sh records through `theme --record-source` so that a machine with a checkout uses the checkout. A previous session ran sync.sh from inside a git worktree, so the recorded path was .claude/worktrees/task-112-select-all/setup. That worktree has since been removed.

With sourceDir pointing at a directory that no longer exists, `chezmoi managed` returns nothing at all. The check reads that empty set as "nothing is managed", so every file ever deleted from setup/dotfiles/ and later re-added under another source name reads as an orphan - which is precisely the false positive it was written to avoid.

Fixed by passing --source explicitly, pointed at setup/ so .chezmoiroot redirects the rest of the way, exactly as sync.sh does. The check now asks about the checkout it is checking rather than about whatever the machine last recorded. It also exits non-zero if chezmoi fails rather than continuing with an empty set, since silently treating failure as "nothing is managed" is what made this destructive rather than merely wrong.

Two things found alongside, both worth their own attention.

The recorded sourceDir was repaired on this machine with `theme --record-source /home/vincemaina/Arch/setup`, but nothing stops it happening again: sync.sh run from a worktree will record the worktree path, and removing that worktree leaves every bare chezmoi command on the machine silently operating on nothing.

And with sourceDir repaired, the machine turns out to be well behind the repository - 19 dotfiles differ, including a foot.ini still carrying the tokyonight-night include that was fixed long ago. Three other checks fail as a direct result. Running sync.sh should clear them.

Continued in a later session. The --source fix described above had landed (a588b3b) and the machine had been synced, so checks/session.sh was already at 92 passed, 0 failed and chezmoi status was clean - the 19-files-behind half of these notes is resolved.

Two things were still missing, and both were about whether the check can be trusted rather than about the fix itself.

The first is a real defect the previous session believed it had fixed. The notes say it 'exits non-zero if chezmoi fails rather than continuing with an empty set'. The python does exit 3, but nothing read that status: session.sh runs 'set -uo pipefail' with no -e, so the assignment simply received an empty string, and an empty orphan list is indistinguishable from a clean machine. Proved by putting a chezmoi on PATH that exits 1 - the check printed a green PASS, 'every dotfile this repository has deleted is gone from this machine too'. Exactly the silent-success shape that made the original bug destructive, reintroduced by the guard against it. Now the exit status is read and the check fails saying it could not compute an answer.

The second is AC 4, which had never been done: the check had passed for prefixed and templated files only because none had been removed. Exercised with three live probes committed to a worktree branch - one dotfile deleted outright, one deleted and re-added as .tmpl, one re-added with an executable_ prefix - all three targets created on disk. Only the genuine deletion was reported. Probes then reset out of history and removed from disk.

Found while doing it: git records a rename inside a single commit as a rename, so --diff-filter=D never reports it. Only delete-then-readd across commits reaches the source-name comparison at all. Noted in the check, since the first probe attempt used git mv and silently tested nothing.

The remaining half of these notes - that nothing stops sync.sh recording a worktree sourceDir again - is now TASK-121.1.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The check was already fixed by passing --source explicitly; what this session added was proof it works and one defect found while getting it.

The defect: the python guard that exits non-zero when chezmoi cannot be asked what it manages was inert, because session.sh has no set -e and nothing read the status. A failing chezmoi produced an empty orphan list and a green PASS - the same silent-success that made the original bug destructive. The exit status is now read, and the check says it could not compute an answer instead of reporting a pass.

Verified by running checks/session.sh with a chezmoi on PATH that exits 1: PASS before, FAIL after. Then with three probes committed to a throwaway branch and their targets created on disk - one dotfile stopped being shipped, one converted to .tmpl, one given an executable_ prefix - only the genuine deletion was reported. Probes removed, and the full check is back to 92 passed, 0 failed with chezmoi status clean.

Also recorded that a single-commit rename is never seen by this check at all, and gave the manual's chezmoi-pointed-at-nothing bullet the other half of the story. The unresolved sourceDir recurrence is TASK-121.1.
<!-- SECTION:FINAL_SUMMARY:END -->
