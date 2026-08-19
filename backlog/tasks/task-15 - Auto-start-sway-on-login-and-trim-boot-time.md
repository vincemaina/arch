---
id: TASK-15
title: Log in graphically and start the session automatically
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-19 18:15'
updated_date: '2026-08-19 23:12'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Install greetd with ReGreet as the login screen, hosted by cage. greetd is a login daemon and nothing else, ReGreet reads session entries so the session list is derived rather than hand-maintained, and both are in the official extra repository.
2. Ship a wayland-sessions entry that launches uwsm start -- sway.desktop, so logging in always goes through uwsm and reaches the session target.
3. Ship a second entry hiding the packaged sway.desktop, so the plain non-uwsm session cannot be selected from the picker. Both go in /usr/local/share/wayland-sessions, which the desktop entry spec reserves for local entries and which takes precedence over /usr/share, so nothing pacman owns has to be modified.
4. Retarget the session units from graphical-session.target to wayland-session@sway.target before any second session exists. The generic target is reached by every compositor, so units wanted by it would start under another desktop, where waybar would draw a sway bar and the idle script would call a swaymsg that is not there.
5. Have chezmoi delete the old graphical-session.target.wants directory through .chezmoiremove, or the stale enable symlinks keep the leak alive on machines that already synced.
6. Install greetd configuration through apply-config.sh so it reaches both fresh installs and running machines, and enable greetd there. Do not restart greetd on --activate: it owns the running session.
7. Keep greetd on VT 1 only, so the other virtual terminals keep their gettys and Ctrl+Alt+F2 remains the recovery path.
8. Revise the no-display-manager entry in DECISIONS.md by quoting it and explaining what changed, rather than deleting it.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented. Boot now reaches ReGreet, which lists sessions read from the wayland-sessions directories, and logging in runs uwsm start -- sway.desktop.

The session units moved to wayland-session@sway.target, confirmed from the uwsm documentation as the per-compositor target name, with the compositor id being sway for both uwsm start -- sway and uwsm start -- sway.desktop. Waybar keeps its packaged unit, which is wanted by graphical-session.target in its own [Install] section; moving only the enable symlink is enough, because a unit starts when something wants it and nothing will want it outside a sway session.

checks/session.sh now tests for the sway-specific target and additionally fails if anything is still enabled under graphical-session.target, so the leak cannot silently return.

Verified locally: every script parses; the config file mapping still parses correctly with comments inside the bash array, producing seven entries; the sway configuration is untouched by this work.

Not verifiable here, and the main risks for the VM: whether ReGreet reads /usr/local/share/wayland-sessions rather than only /usr/share, whether the Hidden entry actually suppresses the packaged sway.desktop, and whether cage -s is the right invocation. The first two fail loudly rather than silently - either no sway entry appears, or two do.

Greeter offered a session named Sway that did not use uwsm. Root cause found by reading ReGreet 0.5.0 source rather than guessing.

ReGreet derives its session search path from XDG_DATA_DIRS and falls back to a compiled-in default of /usr/share/xsessions:/usr/share/wayland-sessions when it is unset. Under greetd the greeter user has no environment, so /usr/local/share was never scanned and the packaged sway.desktop was offered instead. Both entries are named Sway, so the dropdown looked exactly as intended while running the wrong command - the naming choice hid the diagnosis.

The masking mechanism itself was sound: a Hidden or NoDisplay entry inserts its name into found_session_names before skipping, so it does suppress a later duplicate of the same filename. It only needed its directory scanned first.

Fixed by setting XDG_DATA_DIRS=/usr/local/share:/usr/share in the greetd command, via an env prefix since greetd execs the command without a shell.

Added a check that replicates ReGreet discovery - the same search path derivation, first-match-wins dedup by type and filename, and Hidden claiming the name before being skipped - and reports each offered session with its Exec, failing on any that bypasses uwsm. Verified against a fake tree: it reproduces the bug exactly before the fix, one session named Sway running plain sway, and passes after, one session named Sway running uwsm start -- sway.desktop. This runs without rebooting, so the same class of failure is now caught before it reaches a boot.
<!-- SECTION:NOTES:END -->
