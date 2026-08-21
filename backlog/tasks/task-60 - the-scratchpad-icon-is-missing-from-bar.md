---
id: TASK-60
title: the scratchpad icon is missing from bar
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 10:21'
updated_date: '2026-08-21 11:04'
labels: []
dependencies: []
priority: medium
type: bug
ordinal: 58000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
the icon that tells you how many things you have in your scracthpad, disappeared at some point. we should bring that back
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The bar shows how many windows are in the scratchpad
- [x] #2 It stays out of the way when the scratchpad is empty, which is most of the time
- [x] #3 Clicking it does something useful, since every other module in the bar does - checks/session.sh enforces this
- [x] #4 Its icon is written by codepoint rather than pasted, and renders as an icon rather than an empty box
- [x] #5 It is styled with the rest of the bar and follows the selected theme, rather than arriving in a default colour
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Establish why it went, so it is not re-removed later. git log says it was
   dropped in 8115534, the commit that made every module clickable - the config
   header lists it under "Also removed" alongside temperature. It was cut as
   unused clutter, not because it was broken.
2. Put sway/scratchpad back. show-empty defaults to false, which is the
   behaviour wanted: invisible until something is in it.
3. Give it a click action. TASK-53's rule is that every module does something,
   and the check added there fails a module with none. `swaymsg scratchpad show`
   is the natural one - it is what the keybinding does.
4. Icon by codepoint. The version that was removed used two pasted glyphs in a
   format-icons array, which is exactly the failure this repository keeps
   hitting.
5. Style it: the shared pill rule plus a colour from the palette, so it themes
   with everything else.
6. Verify against the running bar with something actually in the scratchpad,
   not just an empty one - an empty scratchpad hides the module, so a screenshot
   of nothing proves nothing.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verification evidence.

Why it went, since that matters for whether it comes back: removed in d1c9c08,
which trimmed the bar to "what is worth a permanent place on screen" and gave
the reason that it reported state that was already obvious. That reason was
sound for the idle inhibitor, cut in the same commit, and wrong for this one -
a window in the scratchpad is hidden by definition, so the count is the only
evidence it exists.

AC1/AC2 - tested with a throwaway window actually in the scratchpad, because an
empty scratchpad hides the module and a screenshot of an empty bar proves
nothing. With one stashed, the bar shows the icon and "1"; after restoring it,
the module disappears entirely.

AC3 - on-click runs `swaymsg scratchpad show`, the same action as $mod+minus.
Driven through waybar's own environment taken from /proc: the window came back
and the scratchpad emptied. checks/session.sh now counts 11 modules and 9 click
actions, and its "every module responds to a click" check would have failed had
this been added without one.

AC4 - written as a \u escape and confirmed present in JetBrainsMono Nerd Font by
checking the font's charset via fc-list before using it, rather than pasting the
glyph and hoping. U+F2D2, window-restore.

AC5 - styled from the palette and joined to the shared pill rule, so it has the
same padding, margin and hover behaviour as every other module. The colour
choice was measured: `tertiary` was the obvious pick because the workspace discs
next to it use it, but against the background it falls to 2.04:1 in mono and
2.42:1 in abyss - it is a fill colour with light text on top, not a text colour.
`warning` measures 8.6:1 to 13.4:1 across all eight themes and is the palette
role that means "attention, nothing wrong yet", which is what a stashed window
is.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The scratchpad count is back on the bar, in modules-left where it was before
d1c9c08 removed it. It is hidden while the scratchpad is empty and shows an
icon and a count when it is not, and clicking it restores the next window -
the same action as $mod+minus, which it needed because every module in this
bar does something when clicked and checks/session.sh enforces that.

Verified with a window genuinely in the scratchpad rather than against an
empty one, and the click driven through waybar's real environment. The icon
was checked against the font's charset before use and the colour chosen by
measuring contrast across all eight themes, where the obvious candidate
turned out to be a fill colour that reads at 2.04:1 as text.
<!-- SECTION:FINAL_SUMMARY:END -->
