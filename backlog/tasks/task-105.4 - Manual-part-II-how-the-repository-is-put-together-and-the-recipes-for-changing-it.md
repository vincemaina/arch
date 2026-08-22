---
id: TASK-105.4
title: >-
  Manual part II: how the repository is put together, and the recipes for
  changing it
status: Done
assignee: []
created_date: '2026-08-22 10:27'
updated_date: '2026-08-22 11:05'
labels: []
dependencies: []
parent_task_id: TASK-105
ordinal: 111000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Chapters seven and eight, the editing half. How it is put together: the two entrypoints, the two execution contexts and the copy between them, the setup/ boundary, what apply-config.sh owns, how chezmoi is rooted, and what sync.sh does in what order and why. Then recipes, each end to end: add a package, add a dotfile, add a keybinding, add a theme, add a session unit, add a machine-wide config file. Each recipe must say which of install.sh and sync.sh carries the change, because adding something to only one path is a bug this repository has already shipped.

CLAUDE.md, FLOW.md and DECISIONS.md already carry much of this for a builder. Do not restate them - write for someone changing the system, and link across rather than copying.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each recipe is a complete worked example ending in a verified change on a running machine
- [x] #2 Every recipe states whether the change reaches a fresh install, a synced machine, or both
- [x] #3 The two execution contexts and the setup/ boundary are explained well enough to predict which paths a new script may use
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Wrote docs/manual/07-how-it-is-put-together.md and 08-recipes.md, from install.sh, sync.sh, setup/system/apply-config.sh and the four check scripts rather than from prose about them - CLAUDE.md has been wrong before. No contradiction found this time; FLOW.md in particular is accurate and is linked rather than duplicated.

One inference caught before it shipped: the wayland-session@sway.target.wants/ entries are chezmoi symlink_ source files (git mode 100644) holding the target as text, not filesystem symlinks. A recipe telling the reader to run ln -s would have produced a git symlink object and not matched the convention. The recipe writes the file content with printf, as the real ones do.

AC#1 NOT checked. Every recipe is complete and each verify step is built from what the corresponding script and check actually do, but no recipe was executed end to end on a running machine - install.sh and the install stages were out of bounds, and proving a change survives a fresh build needs a VM rebuild. The recipes are derived, not demonstrated, and that distinction is worth keeping honest.

Also fixed during integration: three code spans naming paths that do not exist. A truncated setup/install/01, and a foo/bar placeholder used to explain chezmoi naming - replaced with a real example, dot_config/mako/config, which is both clearer and checkable.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Two chapters on how the repository is put together and eight worked recipes for changing it, each stating whether the change reaches a fresh install, a synced machine or both. Derived from the scripts themselves; AC#1 left unchecked because no recipe was executed end to end on a machine.
<!-- SECTION:FINAL_SUMMARY:END -->
