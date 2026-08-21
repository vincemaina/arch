---
id: TASK-52
title: 'More themes, and a choice of wallpaper within each'
status: To Do
assignee: []
created_date: '2026-08-21 03:50'
labels:
  - desktop
  - feel
  - dotfiles
dependencies: []
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-46 delivered theme switching with three themes, each with exactly one wallpaper generated from its palette and committed as a PNG. Two things are wanted on top of that: many more themes, including a green one, and a choice of wallpaper within a theme rather than one fixed image - the generated gradient, or one of several alternatives that carry the theme's colours.

The blocker is size. Three themes at one image each is already 7.8M of tracked PNG. Nine themes at four wallpapers each would be around 94M, which is not something a configuration repository should carry, and it grows every time a theme is added.

So the images should stop being committed and start being generated on the machine, on demand, cached. That inverts the current arrangement: tools/wallpaper.py never reaches the built system, and would have to move into the dotfiles so it does. Adding a theme then costs no bytes at all, which is the property that makes "way more themes" cheap rather than expensive.

The wallpaper choice is per-theme and machine-local, in the same place the theme selection lives, so that switching to a theme returns the wallpaper last chosen for it rather than resetting.

Worth deciding while doing it: whether a user-supplied image (a photograph, say) can be selected the same way, since the mechanism is nearly the same and the alternative is a second mechanism later.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Several more themes exist, including a green one, and every one of them passes the existing key-parity and contrast checks
- [ ] #2 Within a theme, more than one wallpaper can be chosen, and the choice is made from the launcher rather than by editing anything
- [ ] #3 The wallpaper choice is remembered per theme, so switching away and back does not lose it
- [ ] #4 Wallpaper images are no longer committed to the repository, and adding a theme adds no binary files
- [ ] #5 Generating a wallpaper on the machine is fast enough not to make switching feel broken, with the measurement recorded rather than asserted
- [ ] #6 A wallpaper that has already been generated is not generated again
- [ ] #7 Whether a user-supplied image can be chosen the same way is decided rather than left implicit
- [ ] #8 checks/session.sh covers the new arrangement, including that the wallpaper on screen matches the theme and style selected
<!-- AC:END -->
