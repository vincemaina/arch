---
id: TASK-75
title: Make the login screen look like the rest of the desktop
status: To Do
assignee: []
created_date: '2026-08-21 12:12'
labels:
  - desktop
  - feel
dependencies: []
ordinal: 77000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The greeter is the first thing seen at every boot and the one part of the desktop that never got designed. greetd runs ReGreet inside cage, configured from setup/system/greetd/regreet.toml, and it currently looks like whatever ReGreet's defaults are - which is nothing like the bar, the launcher or the terminal that appear thirty seconds later.

Worth deciding what "looks right" means before changing anything, because the greeter is the one surface that cannot follow the theme the way everything else does. Themes are machine-local, chosen per user and stored in that user's chezmoi config, and the greeter runs before any user has logged in - so it has no user whose theme to read. It can be given a fixed appearance derived from the default theme in themes.toml, or its own small palette, but it cannot simply follow whatever the user picked last.

Things that are probably wrong and worth looking at with a screenshot rather than from memory: the wallpaper or lack of one, the font, the size and placement of the input, the session picker, and whether the machine name and time are shown at all.

Two constraints already established elsewhere and easy to trip over again:

  * The greeter's session list must keep offering only the uwsm entry. A session that bypasses uwsm starts a desktop where nothing is supervised, and checks/session.sh covers this because it has been broken before.
  * greetd is deliberately never restarted by sync.sh, because it owns the session of whoever is running it. So testing a change means logging out, and getting it wrong means being unable to log back in - which is the one failure in this repository that cannot be fixed from inside the session.

That last point is the real risk and should shape the approach: have a way back in before changing the thing that lets you in. A second TTY with a known-good greetd config, or testing the ReGreet config against a nested cage inside the running session first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The greeter is looked at as it actually renders, with a screenshot, before anything is changed
- [ ] #2 It reads as part of the same desktop - font, colours and layout are deliberate rather than defaults
- [ ] #3 How it relates to the theme system is decided, given it runs before any user exists to have a theme
- [ ] #4 The session list still offers only the uwsm entry, and checks/session.sh still says so
- [ ] #5 There was a tested way back in before the greeter was changed, since a broken greeter cannot be fixed from inside the session
<!-- AC:END -->
