---
id: TASK-144
title: A machine-local layer above the repository
status: To Do
assignee: []
created_date: '2026-08-23 11:40'
labels: []
dependencies: []
priority: high
type: feature
ordinal: 148000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The repository should be a starting point, not a cage. Today a machine that wants to differ has two bad options: hardcode itself into the shared config, or have its change reverted by the next ./sync.sh. That blocks publishing the build, because a stranger's laptop is not this one - and it already bites here: the terminal font is 15 on this machine and 10 in the repo, so sync silently reverts it.

The design is three layers, with the tool's own capability deciding which applies:

  Base      the repository, generic, naming no machine
  Overrides a local file the tracked config includes last, seeded once and never rewritten
  Values    machine-local data in chezmoi.toml, consumed by templates

Two things were established before proposing this, by measurement rather than reading:

  * Nothing under setup/dotfiles uses chezmoi's exact_ prefix, so chezmoi already leaves unknown files in managed directories alone. Drop-ins in sway/config.d, environment.d and systemd *.d survive sync today - undocumented, but working.
  * chezmoi's create_ attribute creates a file once with seeded content and never overwrites it afterwards, even under apply --force. Verified against a scratch destination. That is the whole override mechanism, and it is a documented chezmoi feature rather than something invented here.

Tool support for an include point, checked in each tool's own manual: foot include (absolute path), mako include= (accepts ~/), sway already globs config.d/*.conf, git [include], waybar include array and CSS @import, rofi @import, mpv include=, nvim pcall(dofile). keyd was done under TASK-133. No include mechanism: starship, yazi, GTK settings.ini - those need the values layer.

This is deliberately NOT TASK-14. Profiles answer 'this is a laptop, so show a battery module'. Local overrides answer 'I like this font bigger'. Collapsing them would mean declaring a profile for every personal preference.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A machine can change a tracked setting and keep that change across ./sync.sh, without editing any tracked file
- [ ] #2 The mechanism is documented as a general rule rather than existing per-tool by accident
- [ ] #3 No tracked file names a specific machine in order to make this work
- [ ] #4 A fresh install still produces a working desktop with an empty local layer
<!-- AC:END -->
