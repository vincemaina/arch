---
id: TASK-30
title: 'Track every keyboard shortcut in one place, across all tools'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-20 11:09'
updated_date: '2026-08-20 12:56'
labels:
  - desktop
  - feel
dependencies: []
priority: high
type: feature
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Shortcuts are currently defined per tool with no way to see them together: sway bindings in config.d, terminal bindings in the zshrc and fzf defaults, and whatever qutebrowser, neovim and the launcher define internally. checks/sway-bindings.sh prints the sway set, which is one context out of several.

Without a combined view there is no way to answer the questions that matter. Does the same action use the same key in different tools. Does a key mean one thing in the terminal and something unrelated in the browser. Does a sway binding shadow something an application needed, which is the failure that started TASK-2 in the first place.

The wanted outcome is a single place listing every shortcut grouped by the context it applies in - system and window management, terminal, browser, editor, launcher - generated from the actual configuration rather than maintained by hand, since a hand-written list is wrong the first time someone changes a binding without updating it.

Conflicts across contexts are not automatically wrong: the same key doing different things in different applications is normal. The value is in seeing it and deciding, rather than discovering it by surprise.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 One command produces a list of every shortcut grouped by the context it applies in
- [x] #2 The list is derived from actual configuration rather than maintained by hand
- [x] #3 Shortcuts that mean different things in different contexts are surfaced rather than hidden
- [x] #4 Adding a binding to any tracked tool appears in the list without editing it
- [x] #5 It is obvious which tools are covered and which are not yet
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented as tools/shortcuts.sh. Kept out of checks/ deliberately: checks exit non-zero on a problem, this produces a report to read, and conflating the two makes both less useful.

sway bindings come from calling checks/sway-bindings.sh rather than parsing the config a second time, so the two cannot disagree about what is bound.

zsh bindings are derived by difference: what an interactive shell binds minus what a shell started with no configuration binds. That needs no list of our own bindings and cannot go stale.

Testing that caught a real gap. The first version compared keys alone, which hid Ctrl+R entirely - zsh binds it to its own history search by default and fzf rebinds it, so the key is present in both sets while the meaning changed. Comparing key-and-widget pairs surfaces rebindings, which is where the interesting cases live.

Cross-context conflicts are found by canonicalising both sides - lower case, sorted modifiers, Mod4 as Super - so a sway binding and a zsh binding are comparable at all. Verified by temporarily binding Ctrl+t in sway alongside fzf file widget, which was correctly reported with both meanings.

Currently zero conflicts, which is itself informative: sway lives on Super, the shell on Ctrl and Alt.

Coverage is stated rather than implied. qutebrowser, neovim, wofi and foot are listed as uncovered with the reason, and each becomes coverable by giving it a config this repository owns.
<!-- SECTION:NOTES:END -->
