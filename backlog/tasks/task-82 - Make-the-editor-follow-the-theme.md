---
id: TASK-82
title: Make the editor follow the theme
status: To Do
assignee: []
created_date: '2026-08-21 14:21'
labels:
  - dev
  - dotfiles
  - feel
dependencies:
  - TASK-24
ordinal: 84000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Eight themes drive sway's borders, the bar, foot, rofi, mako, swaylock, the prompt and the wallpaper. Neovim would be the only thing on the screen that ignores them - and it is the window that will be open most of the day, so it is the worst candidate for being the odd one out.

The mechanism already exists and is the same one everything else uses: .chezmoidata/themes.toml holds the roles, and a .tmpl file resolves the selected theme in its first line and reads from it. A colorscheme is a Lua file setting highlight groups, so it templates like any other consumer.

What makes this more than a mechanical job is that a colorscheme needs more colours than the palette defines. The palette has fifteen roles plus sixteen ANSI colours, chosen for a bar and a terminal; a syntax theme wants distinct treatments for comments, strings, keywords, functions, types, constants and diagnostics, plus a selection and a cursor line. Some of that maps cleanly - `urgent` is an error, `muted` is a comment - and some has to be derived, which is the interesting part and the thing to get right rather than guess at.

Two constraints the rest of the theming already established and this must not break:

  * Every theme must define every key every other theme defines, or selecting one fails at render. checks/session.sh enforces it, so any new role added for the editor has to be added to all eight themes.
  * The contrast floors are checked, and were both learned by breaking them. Comments in particular: the terminal's bright_black sits near 4.8:1 deliberately, against the usual near-invisible grey.

Reloading is the other half. Everything else reloads through run_onchange_after_reload-theme.sh; a running neovim would need telling too, or the editor lags a theme switch until it is restarted - which is the same class of problem foot has and worth stating either way rather than discovering.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The editor uses the selected theme's colours, and switching theme changes it
- [ ] #2 Any colour the syntax theme needs beyond the existing roles is either derived from them or added to all eight themes, so checks/session.sh still passes
- [ ] #3 Comments and diagnostics are checked against the same contrast floors as the rest of the palette, not eyeballed
- [ ] #4 A running editor either follows a theme switch or the limitation is stated, the way foot's is
- [ ] #5 No colour is written twice - the colorscheme reads themes.toml rather than restating it
<!-- AC:END -->
