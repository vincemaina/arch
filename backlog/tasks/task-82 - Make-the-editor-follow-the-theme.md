---
id: TASK-82
title: Make the editor follow the theme
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 14:21'
updated_date: '2026-08-21 19:55'
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
- [x] #1 The editor uses the selected theme's colours, and switching theme changes it
- [x] #2 Any colour the syntax theme needs beyond the existing roles is either derived from them or added to all eight themes, so checks/session.sh still passes
- [x] #3 Comments and diagnostics are checked against the same contrast floors as the rest of the palette, not eyeballed
- [x] #4 A running editor either follows a theme switch or the limitation is stated, the way foot's is
- [x] #5 No colour is written twice - the colorscheme reads themes.toml rather than restating it
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
VERIFICATION.

AC1 - the editor follows the theme, and a switch changes it. colors/arch.lua.tmpl renders from .chezmoidata/themes.toml like every other consumer. checks/session.sh compares the editor's actual Normal foreground against the selected theme's text colour rather than merely asserting a colourscheme is loaded, because loading the wrong one would pass that.

AC2 - no new role was needed, so all eight themes are untouched. Syntax reads the sixteen ANSI colours under term, which every theme already defines for foot; chrome reads the fifteen roles. A syntax theme wants distinct treatments for keywords, strings, functions, types and constants, which is what the ANSI sixteen already are and what the roles are not - so the mapping was found rather than invented.

AC3 - CONTRAST IS NOW ACTUALLY CHECKED. arch.lua.tmpl claimed 'checks/session.sh enforces that floor' about the comment colour, and session.sh had never heard of bright_black - a comment describing a hypothesis as an outcome, which is the failure mode CLAUDE.md names. Four floors added: comments (term.bright_black) and the error, warning and info diagnostics, all at 4.5:1 against the background. Measured across all eight themes first rather than picking a number: comments run 4.52 (ember, the tightest) to 6.38 (cobalt), diagnostics 5.28 to 13.42. Proven by dimming ember's comment colour to 222222, which failed with 'ember: term.bright_black on bg is 1.19:1'.

AC4 - A RUNNING EDITOR NOW FOLLOWS A THEME SWITCH, rather than the limitation being stated. The ticket expected this to be foot's problem again; it is not. Every neovim listens on a socket whether asked to or not - v:servername is set even headless - so a running editor is reachable at $XDG_RUNTIME_DIR/nvim.<pid>.0 with no configuration at all. run_onchange_after_reload-theme.sh now sends each one a colorscheme reload.

--remote-expr rather than --remote-send, because send types keys into whatever mode the editor is in: an editor sitting in insert mode would get ':colorscheme arch' inserted into the file being edited.

Verified end to end against a real running editor: Normal foreground #d8ece2 under verdant, #dae3f5 after switching to cobalt, back to #d8ece2 on switching back - without restarting it.

foot remains the only consumer that cannot be reloaded.

AC5 - no colour is restated. The template resolves the palette in its first line and every value reads from it; treesitter captures are linked to the vim groups rather than given their own colours, which is how a theme ends up with forty shades nobody can tell apart.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The editor renders its colourscheme from themes.toml like every other consumer, with syntax reading the sixteen ANSI colours and chrome reading the fifteen roles, so no theme needed a new key. Normal has no background, so the terminal's transparency shows through and the editor matches the other terminal tools. A running editor now follows a theme switch over the socket neovim always opens - verified by watching Normal's foreground change from #d8ece2 to #dae3f5 and back without a restart. The comment and diagnostic contrast floors that arch.lua.tmpl claimed were enforced now actually are, proven by breaking one.
<!-- SECTION:FINAL_SUMMARY:END -->
