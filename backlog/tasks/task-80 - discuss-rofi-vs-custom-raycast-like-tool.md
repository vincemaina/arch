---
id: TASK-80
title: discuss rofi vs custom raycast-like tool
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 14:06'
updated_date: '2026-08-21 17:26'
labels: []
dependencies: []
priority: medium
type: spike
ordinal: 82000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Don't know exactly how flexible rofi is, or what makes it so great as an application launcher. But possibly a custom tool might behave more like raycast.
This is an area that's worth the investment as it's essentially the entry point for every other thing in this operating system, bar the terminal. It's the most user-friendly interface for the platform
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Establish what rofi can and cannot do relative to Raycast, from its own theme format rather than from assumption.
2. Decide: stay on rofi, or build a custom launcher.
3. If staying, close the gap that made it feel basic - the visual treatment - by restyling config.rasi.tmpl.
4. Verify the restyle renders for every theme and actually masks what is behind it.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DECISION: stay on rofi. Building a custom launcher would mean reimplementing the parts that already work - .desktop parsing, icon-theme lookup, fuzzy matching, the window switcher, the script protocol that theme/wallpaper/shortcuts/find-files all already speak - to gain a look, which is the one thing rofi's theme format can actually give. Four custom modes were built on that protocol during this session at no cost; a custom tool would have had to grow an equivalent first.

WHAT MADE IT FEEL BASIC WAS GEOMETRY, NOT CAPABILITY. The old theme was a 4px accent frame around square corners with 40% of the screen width, cramped rows and 20px icons. Restyled config.rasi.tmpl to Raycast's proportions: fixed 780px width, 14px window radius over a 1px hairline border, 18px/22px inputbar, 26px icons, 10px element radius, 9 fixed lines so the window does not resize as results narrow, placeholder text, and a persistent footer showing the keys.

REVERSES A RECORDED DECISION. 'Square, like everything else' was right when nothing else on screen was round. The bar now has 14px pills and circular workspace targets, so square corners here had become the odd one out. Noted in the template so the reversal is not mistaken for drift.

The footer needs the 'textbox-' prefix - a custom child of mainbox that is not one of rofi's known widget names is only recognised as a textbox if it is named textbox-something. Without it the child is silently absent, no error.

VERIFICATION.
- Renders for all eight themes: rendered config.rasi with chezmoi --destination against each palette in turn; every one produced a window background of that theme's bg at f7 and a 14px radius. (The render harness needs HOME, XDG_CONFIG_HOME *and* an existing destination directory - chezmoi will not create the destination root, and the first attempt reported a template failure that was only a missing mkdir.)
- rofi -dump-theme confirms it accepts the values: window background-color resolves to rgba(10,18,16,97%).
- Masking measured over static content on an empty workspace: luminance spread behind 203.3, through the launcher 6.3 = 3% visible, which is what 97% opacity predicts.

A MEASUREMENT THAT WAS WRONG TWICE, worth recording because both mistakes look like findings.
1. A before/after taken while the terminal behind was scrolling compared two different scenes and reported '75% still shows through'. There was nothing to explain; the measurement was invalid.
2. A single-patch sample then reported perfect masking - it had landed in a blank gap between two blocks of text. One patch is not a measurement.
Only the third attempt - static content, full-region luminance spread, before and after - answered the question.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Decided to stay on rofi rather than build a Raycast-like launcher: rofi already supplies desktop parsing, icon lookup, matching, the window switcher and a script protocol that four custom modes in this desktop already use, and the only real gap was how it looked. Closed that gap by restyling setup/dotfiles/dot_config/rofi/config.rasi.tmpl to Raycast proportions - fixed 780px width, 14px radius, hairline border, generous inputbar, 26px icons, rounded rows, a fixed 9-line list so the window stops resizing as you type, and a persistent key footer. Verified by rendering the template against all eight themes, by rofi -dump-theme, and by measuring that the window masks 97% of what is behind it.
<!-- SECTION:FINAL_SUMMARY:END -->
