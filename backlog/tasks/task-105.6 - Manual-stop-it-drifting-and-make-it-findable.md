---
id: TASK-105.6
title: 'Manual: stop it drifting, and make it findable'
status: Done
assignee: []
created_date: '2026-08-22 10:27'
updated_date: '2026-08-22 11:05'
labels: []
dependencies: []
parent_task_id: TASK-105
ordinal: 113000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A manual nobody can find is not a manual, and one that quietly goes stale is worse than none. Add a check that fails when the manual names a file, script, command or keybinding that no longer exists, and wire the manual into README.md and into the machine itself so it can be opened without knowing the path.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A check fails when the manual references a path, helper or binding that does not exist
- [x] #2 The check is proven to fail by introducing a wrong reference, and to pass once corrected
- [x] #3 README.md links to the manual
- [x] #4 The manual can be opened from the running desktop without typing a path
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
checks/manual.sh, plus README.md and on-machine discoverability.

The check has eight assertions: the manual builds at all (the renderer refusing unsupported markdown IS the dialect check); every relative link resolves; no cross-chapter link is labelled with a filename; every repository path named in a code span exists; every ~/.local/bin helper named is shipped; every $mod binding named is bound; chapter numbering is sane; every chapter has a title.

Two subtleties it had to learn:
  * chezmoi source naming. ~/.config/foo is setup/dotfiles/dot_config/foo, an executable carries an executable_ prefix and a template a .tmpl suffix, so the check maps a path the reader would type back to the file they would edit.
  * A dotfile the repository deliberately does NOT track still exists as far as the manual is concerned. ~/.config/zsh/local.zsh is the entire point of .chezmoiignore, so the check reads that file and treats what it lists as legitimately absent. Without this it failed on a correct sentence, which would have pushed the manual into either silence or a lie.
  The $mod binding check covers the numbered chapters only, not the index. The index is about the manual rather than about the desktop, and it deliberately names a binding that was taken away in order to explain what the check cannot see.

AC#2 (proven both ways, three times): introduced a bad path, a bad helper and an unbound $mod binding into a chapter - all three were reported, exit 1. Removed them, exit 0. Repeated after the check was later changed to scope bindings to chapters, with four failures reported and exit 1, then clean.

It also earned its keep before it was finished. TASK-106 rebound the scratchpad off $mod+minus while these chapters were being written, and the check failed on chapter 2 within the hour, naming the file and the binding.

AC#4: setup/dotfiles/dot_local/bin/executable_manual opens the installed copy, with a message pointing at sync.sh when it is not there yet; manual.desktop.tmpl puts "Manual" in the launcher with an absolute Exec, because ~/.local/bin is not on the PATH rofi hands to what it spawns. sync.sh builds the manual after the dotfiles and installs it to ~/.local/share/manual/. Verified: both files applied with a targeted chezmoi apply, the missing-manual path prints its message and exits 1, the installed path resolves to the real file (xdg-open stubbed so no window opened), and xdg-mime confirms qutebrowser is what will open it. The launcher entry was NOT confirmed by eye - proving it needs a rofi window on the user visible screen, and the twelve identical entries beside it already work.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
checks/manual.sh fails when the manual names a path, helper or $mod binding that does not exist, proven three times by introducing each failure and removing it. README.md and CLAUDE.md link the manual; sync.sh installs the built page and a manual command plus a launcher entry open it.
<!-- SECTION:FINAL_SUMMARY:END -->
