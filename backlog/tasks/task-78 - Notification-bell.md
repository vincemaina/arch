---
id: TASK-78
title: Notification bell
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 13:11'
updated_date: '2026-08-22 01:08'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 80000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Is it worth having a notification bell at the top of the screen, that servers as an easy place to see how many undismissed notifications you have - in case you missed the popup. And clicking it opens up notification history.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A waybar module shows a bell + unread count when there are unseen notifications, and is completely hidden (no bare glyph) when there are none.
- [x] #2 Clicking the bell opens the existing notification centre (notification-centre) rather than a new tool.
- [x] #3 Opening the centre clears the badge (marks currently-pending notifications as seen).
- [x] #4 The count reflects notifications missed while away, not just what is still on-screen - it does not read 0 just because mako's 5s popup timeout has already expired the item into history.
- [x] #5 Click commands and exec paths are absolute (chezmoi-templated), matching the rest of config.jsonc.tmpl.
- [x] #6 New helper scripts carry a '# requires:' header and checks/sway-commands.sh and checks/session.sh both still pass.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Reuse the existing notification-centre tool (rofi, dismiss/restore/DND) rather than building a new one - it already covers 'history'.
2. Add a waybar custom module (custom/notifications) as a bar bell indicator, hidden entirely when there is nothing pending (same idiom as sway/scratchpad).
3. Define 'undismissed' as unseen since the bell was last opened, not makoctl list's live count - mako's 5s default-timeout means list is almost always empty by the time anyone looks, which would defeat the point ('in case you missed the popup'). Track a high-water mark over mako's monotonically increasing notification ids in ~/.cache/notification-bell/last-seen.
4. New script notification-count (waybar exec, polled every 5s, cheap: two local makoctl IPC calls + grep/awk, no python3): counts ids in list+history greater than the stored marker; outputs waybar custom-module JSON, empty text at zero.
5. New script notification-bell-open (on-click): opens the existing notification-centre, then advances the marker to the current max id so the badge clears.
6. Verify the bell glyph (U+F0F3) against the installed font, verify template renders via chezmoi, verify the module actually appears/disappears/reacts by running a throwaway waybar instance on a headless output with a visible marker (the real waybar also renders onto any new headless output and had to be avoided by anchoring the test bar at the bottom instead of top).
7. Keep the config.jsonc.tmpl click-table and style.css.tmpl pill/hover rules in sync with the new module.
8. Run checks/session.sh and checks/sway-commands.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented as two new scripts plus a waybar module, all in files this agent owns:

- setup/dotfiles/dot_local/bin/executable_notification-count - waybar's exec for custom/notifications, polled every 5s. Bash only (no python3): two makoctl IPC calls (list, history), grep -oE to pull ids, sort/awk for a high-water-mark comparison against ~/.cache/notification-bell/last-seen. Outputs waybar custom-module JSON; empty text when count is 0 so waybar hides the widget entirely (same as sway/scratchpad).
- setup/dotfiles/dot_local/bin/executable_notification-bell-open - the on-click target. Calls the existing sibling notification-centre (resolved via readlink -f "$0", not by bare name - waybar's PATH does not include ~/.local/bin), then advances last-seen to the current max mako id so the badge clears.
- config.jsonc.tmpl: custom/notifications added to modules-left (after sway/scratchpad), click-table comment updated. style.css.tmpl: #custom-notifications added to the shared pill/hover groups, coloured @warning like scratchpad.

Key decision: 'undismissed' is read as 'unseen since the bell was last opened' (a high-water mark over mako's monotonically increasing notification ids), not makoctl list's live count. mako's default-timeout is 5s (setup/dotfiles/dot_config/mako/config.tmpl), so list is almost always empty by the time anyone looks at the bar - a badge driven by list alone would read 0 for exactly the case the task describes ('in case you missed the popup'). Verified ids survive 'makoctl reload' (what the theme switcher runs) across a live reload; a genuine mako restart resets ids to 1, handled by treating a stored marker greater than the current max as stale.

Verification:
- Rendered both .tmpl files with chezmoi --exclude=scripts; diffed cleanly.
- Checked U+F0F3 renders as a bell in JetBrainsMono Nerd Font via pango-view (not pasted, not assumed).
- Ran the two scripts directly against the live mako instance: confirmed the count increases on notify-send, decreases to 0 immediately after notification-bell-open runs (which really invoked notification-centre via rofi), and stays correct across a simulated daemon-id-reset.
- Built a throwaway waybar instance on a headless output (swaymsg create_output) with the real rendered config/css plus a magenta border marker, to prove which bar a screenshot was showing. First attempt anchored top and was invisibly occluded by the real production waybar, which (per its unrestricted config) also draws on any new headless output - moved the test bar to position:bottom to separate it spatially, matching the desktop-verification skill's warning. Screenshotted both states: bell+count visible in @warning amber next to the workspace number when count>0, completely absent when count==0.
- Cleaned up: unplugged the headless output, refocused Virtual-1, removed the two scripts I had temporarily copied into the real ~/.local/bin for testing, cleared ~/.cache/notification-bell, dismissed the test notifications.
- ./checks/session.sh: 81 passed, 0 failed. ./checks/sway-commands.sh: 1 pre-existing failure (cliphist is not installed on this dev VM - unrelated to this task, packages/desktop.txt already declares it, not touched by this change).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added a notification bell to the bar (waybar custom/notifications, modules-left after sway/scratchpad). It counts unseen notifications - a high-water mark over mako's monotonically increasing ids in list+history, not the live 'list' count, because mako's 5s default-timeout means list is empty by the time anyone looks. Hidden entirely at zero, same idiom as sway/scratchpad; shows the bell glyph (U+F0F3, checked against the installed font) plus a count in the warning colour otherwise. Clicking it opens the existing notification-centre and then clears the badge.

New files: setup/dotfiles/dot_local/bin/executable_notification-count (waybar's exec, interval 5s, two local makoctl IPC calls + grep/awk, no python3) and executable_notification-bell-open (on-click: opens notification-centre, advances the seen-marker). Both carry '# requires: makoctl' headers. config.jsonc.tmpl and style.css.tmpl updated to declare/style the module and keep the click-table comment accurate.

Verified: chezmoi render clean; font glyph confirmed via pango-view; both scripts exercised directly against the live mako instance (count rises on notify-send, resets via notification-bell-open which really opened notification-centre); full round-trip watched on a throwaway waybar instance on a headless output (had to anchor it at the bottom - the real production waybar also renders on any new headless output and was occluding a top-anchored test bar, a variant of the documented trap). ./checks/session.sh: 81 passed, 0 failed. ./checks/sway-commands.sh: only the pre-existing, unrelated 'cliphist is not installed' gap (dev VM only, not this change). Test artifacts (headless output, temp copies in ~/.local/bin, cache state, test notifications) all cleaned up; no git commit made.
<!-- SECTION:FINAL_SUMMARY:END -->
