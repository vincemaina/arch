---
id: TASK-64
title: One place to change how the desktop behaves
status: To Do
assignee: []
created_date: '2026-08-21 10:23'
labels:
  - desktop
  - feel
dependencies: []
ordinal: 66000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Things that can be changed at runtime are accumulating, and each arrives with its own launcher entry. There are already two - Theme and Wallpaper - and this morning's tickets add calendar accounts and whatever the notes and todo tools need. At some point the launcher is a list of settings rather than a list of applications, and there is no single place to answer "what can I change?".

The want is a settings menu: one entry that opens a list of what is adjustable, and dispatches to the thing that adjusts it.

WHAT MAKES THIS EASY, AND THE TRAP IN IT

Easy, because the pieces exist. theme and wallpaper are already scripts that each take an argument or show their own picker, and both read and write machine-local state through ~/.local/lib/desktop_config.py. A menu is a rofi list that calls them.

The trap is that a settings menu is exactly the sort of thing that becomes a second implementation. If it learns to write chezmoi.toml itself, it will disagree with the helpers - which has already happened once here, when theme and wallpaper each had their own TOML writer and one of them flattened a nested table, breaking every apply until it was found. The menu must dispatch to the existing tools and own no settings of its own.

Worth deciding:

  * Whether it is one flat list or nested. Flat is faster to use and gets unwieldy; nested is tidier and adds a keypress to everything.
  * Whether it shows current values. "Theme" is less useful than "Theme: slate", and the helpers can already answer - both support --current.
  * What belongs in it. Anything that is a runtime choice qualifies; anything that is a repository change does not, because editing the repository is a different act with different consequences and blurring them invites someone to look for "install packages" in a settings menu.
  * Whether existing entries stay reachable directly. Hiding Theme behind two keypresses to tidy the launcher would be a downgrade for the thing most often used.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One launcher entry lists what can be changed and dispatches to the tool that changes it
- [ ] #2 It owns no settings itself - every change goes through the existing helper, so there is still one writer of machine-local state
- [ ] #3 Current values are visible where the tool can report them
- [ ] #4 What counts as a setting, as against a repository change, is stated
- [ ] #5 The things used most often are not made slower to reach than they are today
- [ ] #6 checks/session.sh covers it the way the bar's click actions are covered, since a menu entry pointing at a missing command fails silently
<!-- AC:END -->
