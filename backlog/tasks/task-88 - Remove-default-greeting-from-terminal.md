---
id: TASK-88
title: Remove default greeting from terminal
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 20:04'
updated_date: '2026-08-21 20:22'
labels: []
dependencies: []
priority: low
type: task
ordinal: 90000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
At some point i made a decision to load fastfetch for all new terminals. I think I'd like to go back on that and only load it automatically in a terminal when the user first lands in a session.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Find where fastfetch actually runs and what opens those terminals.
2. Make the summary once a session rather than once a window.
3. Give the greeting card an app_id distinct from ordinary floating terminals, since telling them apart is what makes 2 expressible.
4. Verify on the running system, and add a check so the two files cannot drift.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
There was never a separate login greeting. sway-workspace-greeter opens a card on every empty workspace and covers login as the first of those - one mechanism, deliberately. So 'only when the user first lands in a session' means the greeter has to distinguish its first card from the rest, which it now does with a flag on the greeter process. That process IS the session - the unit is PartOf wayland-session@sway.target - so the flag has exactly the right lifetime and needs no state on disk.

terminal grew a third mode. --greeting is the once-a-session card, app_id=greeting, with fastfetch. --floating is every other floating terminal, app_id=floating-term, no fastfetch. Plain terminal is unchanged except that it no longer runs fastfetch either.

TWO SEPARATE WAYS THIS CLOSED THE SESSION'S OWN TERMINAL, both found by doing it:

1. app_id=greeting was on every floating terminal, so 'swaymsg [app_id=greeting] kill' - cleaning up a spawned test window - closed the terminal the command was typed into. Three times, taking the editor and five background jobs with it each time. Splitting the app_ids narrows this to one card; the general lesson, that a class selector matches members of the class you did not have in mind, is in the scripting-traps skill because renaming does not fix it.

2. THE GREETER OWNED EVERY TERMINAL IT OPENED. subprocess.Popen made them children of greeting.service, and systemd's default KillMode is control-group - so 'systemctl --user restart greeting.service' killed every terminal the greeter had ever opened. Confirmed by reading the unit's cgroup, which held a foot process. This is worse than the first: the unit is Restart=always, so a crash in the greeter would have closed every open terminal at the worst possible moment, and nothing would have explained why.

Fixed with systemd-run --user --scope --quiet --collect, which puts each terminal in its own transient scope under app.slice - where a user application belongs anyway. This is a thing that launches terminals, not a thing that owns them.

VERIFIED on the running system: after restarting the greeter its cgroup holds only python3 and swaymsg, no terminal. Landing on an empty workspace produced app_id=greeting with fastfetch in scope run-p138024-i134662.scope; the next empty workspace produced app_id=floating-term with no fastfetch, also in its own scope. Both floating and centred at x=573 on a 1920-wide output.

checks/session.sh gained a Terminal windows section: every app_id the helper sets must be floated and centred by a rule, and the two must stay different. Proven by deleting the floating-term rule, which failed by name.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
fastfetch now runs for the first card of a session instead of every terminal, using a flag on the greeter process - whose lifetime is the session, so no state on disk. Splitting the greeting card's app_id from ordinary floating terminals is what made that expressible, and also narrowed a selector hazard that had closed the session's own terminal three times. Found and fixed a worse one on the way: the greeter owned every terminal it opened, so restarting greeting.service killed them all, and Restart=always meant a crash would have done the same - terminals now get their own transient scope. Verified on the running system and covered by two new checks, both proven by breaking them.
<!-- SECTION:FINAL_SUMMARY:END -->
