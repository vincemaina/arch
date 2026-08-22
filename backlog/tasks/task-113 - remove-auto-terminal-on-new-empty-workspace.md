---
id: TASK-113
title: remove auto terminal on new empty workspace
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 14:01'
updated_date: '2026-08-22 18:13'
labels: []
dependencies: []
priority: medium
type: chore
ordinal: 121000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
im not sure i like this anymore. it's proving to be more annoying than useful.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Delete the mechanism entirely rather than toggle it off, since this repo avoids config kept only in a disabled state: setup/dotfiles/dot_config/systemd/user/greeting.service, its wants symlink, and executable_sway-workspace-greeter.
2. executable_terminal: remove the --greeting mode and the greeting app_id/comment block; only 'floating-term' remains as the floating app_id.
3. 40-window-rules.conf: remove the for_window rules for app_id=greeting and the comment explaining them.
4. executable_startup: remove the 'greeting' entry from OPTIONAL.
5. checks/session.sh (TASK-88 terminal-windows check): remove the two-app_id regression guard, since it exists specifically to catch greeting and floating-term sharing an id - a risk that cannot recur once greeting does not exist.
6. .chezmoiremove: list the three deleted paths so already-installed machines actually lose them (TASK-94's lesson) - .config/systemd/user/greeting.service, .config/systemd/user/wayland-session@sway.target.wants/greeting.service, .local/bin/sway-workspace-greeter.
7. docs/manual/01-getting-started.md and 05-making-it-yours.md: drop greeting from the example command and the startup component list.
8. CLAUDE.md: 'workspace greeter' and 'All six' become five.
9. Verify: checks/session.sh, checks/manual.sh, checks/sway-bindings.sh; render setup with chezmoi to a scratch dir; on the live machine after sync.sh, confirm no greeting.service and no auto-terminal on an empty workspace.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Removed the mechanism entirely rather than toggling it off: greeting.service, its wants symlink, and executable_sway-workspace-greeter are deleted, listed in .chezmoiremove so already-installed machines actually lose them (TASK-94's lesson). executable_terminal loses the --greeting mode; the fastfetch-once-per-session behaviour it drove goes with it (fastfetch stays installed, run manually - docs/software/README.md and its config header updated to say so). Window rules, executable_startup's toggle table, checks/session.sh's TASK-88 two-app_id guard, tools/performance.sh's boot-timeline mark, CLAUDE.md, DECISIONS.md, and the manual (chapters 1, 2, 4, 5) all updated to match. Verified: chezmoi rendered to a scratch dir with --exclude=scripts confirms no greeting.service, no greeting wants-symlink, no sway-workspace-greeter, and only floating-term remains as a floating app_id. checks/session.sh (91/91), checks/manual.sh (8/8), checks/sway-bindings.sh (76, no duplicates) and checks/packages.sh (6/6) all pass against the worktree. Not yet applied to the running machine - that needs sync.sh from a checkout with this merge, run by the user (running it from this worktree would repeat the TASK-121 sourceDir bug).

Follow-up from a later session: the manual sweep for this removal missed two places.

docs/manual/07-how-it-is-put-together.md still listed the workspace greeter among the session's systemd user units, and DECISIONS.md still counted it as one of four sway features with no niri equivalent. checks/manual.sh passed over both because it verifies named files, helpers and bindings, and these were prose - 'the workspace greeter' in words, not a path. A per-line grep of the sources misses them too: markdown wraps between 'workspace' and 'greeter', so the phrase only exists once rendered. Found by flattening newlines before grepping, and by searching the built HTML.

Both corrected. The niri sentence keeps the greeter in the past tense rather than deleting it, since that section is a rationale record.

Also corrected there: 'Nine helper scripts speak sway IPC' was counted while the greeter existed. Verified against 665bee5^ - nine then, eight now - so it is stale by exactly this removal, and now says eight.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The auto-terminal-on-empty-workspace mechanism (greeting.service + sway-workspace-greeter) is removed outright, not toggled off, per the user's 'more annoying than useful' call. $mod+Return still opens a terminal on demand. fastfetch remains installed for manual use. All references across checks, tools, CLAUDE.md, DECISIONS.md and the manual updated to match; checks/session.sh, checks/manual.sh, checks/sway-bindings.sh and checks/packages.sh all pass.
<!-- SECTION:FINAL_SUMMARY:END -->
