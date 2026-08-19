---
id: TASK-15
title: Log in graphically and start the session automatically
status: To Do
assignee: []
created_date: '2026-08-19 18:15'
updated_date: '2026-08-19 22:53'
labels:
  - session
  - performance
dependencies: []
priority: high
type: feature
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Booting currently lands at a TTY where you log in and type a launch command by hand. Beyond being friction on a daily driver, it is actively dangerous now that the session is supervised: typing sway rather than uwsm start -- sway produces a desktop that looks completely normal while missing its bar, notifications, idle handling and authentication agent, with nothing on screen indicating it. That has already happened once during verification.

The wanted behaviour is a graphical login at boot that handles authentication and then starts the session correctly, so the launch command cannot be got wrong because nobody types it.

It has to integrate with the rest of the session rather than sit beside it. The session must come up through uwsm so graphical-session.target is reached and the supervised components start. Locking, idle timeouts and sleep must keep working, and unlocking must return to the running session rather than to the login screen. greetd can launch a uwsm session through a wayland-sessions desktop entry, which is the documented mechanism.

DECISIONS.md currently records "No display manager" as a deliberate choice. That entry needs revising rather than contradicting: it was right for a proof of concept and is being reconsidered because the session now has components that a manual launch can silently skip.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Booting reaches a graphical login prompt with no manual step
- [ ] #2 Logging in starts the session through uwsm, so every supervised component comes up
- [ ] #3 There is no way to reach a partially-started session by accident
- [ ] #4 Screen locking, idle timeouts and sleep behave the same as before, and unlocking returns to the running session
- [ ] #5 A documented escape hatch to a plain TTY shell still exists for recovery
- [ ] #6 Boot time is measured before and after, and any unit found to be delaying boot for no benefit is dealt with
- [ ] #7 DECISIONS.md revises the existing no-display-manager entry rather than leaving it contradicted
<!-- AC:END -->
