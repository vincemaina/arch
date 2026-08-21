---
id: TASK-54
title: >-
  Temporarily remove the script that finds the best space for new floating
  windows
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 10:18'
updated_date: '2026-08-21 20:04'
labels: []
dependencies: []
ordinal: 52000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Right it just feels a little bit glitchy and I'm not sure about it.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Find what actually uses sway-place-floating.
2. Remove it, and replace what it was doing with something sway can express.
3. Make sure it leaves already-installed machines rather than only the repository.
4. Verify the greeting card still lands where it should.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
REMOVED. sway-place-floating scored candidate positions for a new floating window by how much each overlapped what was already floating, and moved the window to the emptiest one - so a second card would not land exactly on top of the first.

Why it felt glitchy, which is worth recording because the helper was not buggy: placement can only happen AFTER the window exists, because there is nothing to move until then. So the window appeared wherever sway put it and then jumped. Nothing was wrong with the scoring; the visible jump was inherent to doing it from outside.

Replaced with 'for_window [app_id="greeting"] move position center', which sway applies as the window is mapped, so there is nothing to see.

What that costs: two cards on the same workspace now land on the same spot. Acceptable because sway-workspace-greeter opens at most one per workspace and two workspaces are never on screen at once, so it needs a card opened deliberately on top of an existing one.

Three places, not one - the third is the one that would have been missed. The script is deleted, executable_terminal no longer calls it (and now execs foot directly, since nothing needs to outlive the launch any more), and .chezmoiremove deletes it from machines that already have it. chezmoi leaves files it does not manage alone, so without the third it would sit in ~/.local/bin forever with nothing explaining it.

VERIFIED against the running system: the floating greeting card is 774x452 at x=573 on a 1920-wide output, and (1920-774)/2 = 573 exactly. It does not move after appearing. checks/session.sh 73/73, sway-commands clean.

FOUND WHILE VERIFYING, and filed as TASK-87: app_id=greeting is not the login card alone. greeting.service opens one, sway-workspace-greeter opens one per empty workspace, and 'terminal --floating' uses it too - so it names most of the terminals on the machine, including the one being worked in. 'swaymsg [app_id="greeting"] kill', used to clean up a spawned test window, closed the session's own terminal three times, taking the editor and five background jobs with it each time. Recorded in the scripting-traps skill as well, since a comment in one config file is not where anyone will look.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed sway-place-floating and replaced it with a sway window rule that centres the greeting card as it is mapped. The helper was not buggy - it could only run after the window existed, so the window always appeared and then jumped, which is the glitchiness the ticket described and was inherent rather than fixable. Removed in three places: the script, its caller in executable_terminal, and .chezmoiremove so machines that already have it lose it too. Verified against the running system: the card sits at x=573 on a 1920-wide output, which is exact. Filed TASK-87 for the app_id collision found while verifying.
<!-- SECTION:FINAL_SUMMARY:END -->
