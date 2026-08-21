---
id: TASK-60
title: the scratchpad icon is missing from bar
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-21 10:21'
updated_date: '2026-08-21 11:00'
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
- [ ] #1 The bar shows how many windows are in the scratchpad
- [ ] #2 It stays out of the way when the scratchpad is empty, which is most of the time
- [ ] #3 Clicking it does something useful, since every other module in the bar does - checks/session.sh enforces this
- [ ] #4 Its icon is written by codepoint rather than pasted, and renders as an icon rather than an empty box
- [ ] #5 It is styled with the rest of the bar and follows the selected theme, rather than arriving in a default colour
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
