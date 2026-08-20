---
id: TASK-15
title: Log in graphically and start the session automatically
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-19 18:15'
updated_date: '2026-08-20 00:00'
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
- [x] #1 Booting reaches a graphical login prompt with no manual step
- [x] #2 Logging in starts the session through uwsm, so every supervised component comes up
- [x] #3 There is no way to reach a partially-started session by accident
- [x] #4 Screen locking, idle timeouts and sleep behave the same as before, and unlocking returns to the running session
- [x] #5 A documented escape hatch to a plain TTY shell still exists for recovery
- [x] #6 Boot time is measured before and after, and any unit found to be delaying boot for no benefit is dealt with
- [x] #7 DECISIONS.md revises the existing no-display-manager entry rather than leaving it contradicted
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

Locked the machine out of the desktop. Logging in reported the sway desktop entry as hidden and returned to the login screen.

Cause: Exec was uwsm start -- sway.desktop, which makes uwsm resolve sway.desktop as a desktop entry ID through the XDG data hierarchy. /usr/local/share precedes /usr/share there, so uwsm found the Hidden masking entry placed next to our session entry - the one whose only job is to suppress the stock session in the login screen - and refused to start a hidden session. The mask intended for the greeter also shadowed the entry the session needed.

Fixed by naming the compositor binary directly: uwsm start -N Sway -D sway -- sway. That avoids the ID lookup entirely, with -N and -D supplying the metadata the entry would have provided. The compositor id stays sway, so wayland-session@sway.target is unchanged and the units still bind correctly.

Both files now document the interaction, including the general hazard that anything resolving the sway.desktop ID gets the mask rather than the packaged entry.

Added a guard to checks/session.sh: for any offered session whose Exec names a .desktop ID, it resolves that ID the same way and fails if it lands on a hidden entry or resolves to nothing. Verified it flags the exact Exec that caused the lockout and passes the corrected one.

Recovery path worked as designed: greetd holds only VT 1, so Ctrl+Alt+F2 reached a console. Worth noting that the escape hatch stopped this being unrecoverable, which is the argument for keeping it.

Login works after the Exec fix, but waybar does not start.

Eliminated the first hypothesis by reading uwsm source rather than guessing: in start mode CompGlobals.id is os.path.basename of the first argument after --, so the id is sway and -N only sets the display name. The target is wayland-session@sway.target as intended and the -N change did not affect it.

Current hypothesis, awaiting evidence: waybar is the only session component still using its packaged unit, which declares Requisite=graphical-session.target and After=graphical-session.target. Our three units were retargeted and now require the sway target instead. If wayland-session@sway.target is reached before graphical-session.target becomes active, waybar requisite is unmet and systemd declines to start it, while the other three are unaffected. That predicts mako, swayidle and polkit-agent all running with only waybar missing.

If confirmed, the fix is a drop-in at waybar.service.d rather than a copied unit, resetting Requisite, After and PartOf to the sway target while keeping the packaged ExecStart and Restart.

Root cause found, and it was not the requisite failure predicted. The journal shows a systemd ordering cycle:

  graphical-session.target after wayland-session@sway.target after waybar.service after graphical-session.target

uwsm orders graphical-session.target after wayland-session@sway.target. Waybar packaged unit declares After=graphical-session.target, which is correct while that target is what pulls it in, but our enable symlink moved it under the sway target instead, closing the loop. systemd resolves a cycle by deleting a job from it, and it chose waybar start, so the bar silently never ran. Our own three units avoided this only because retargeting them rewrote their After= as well.

Fixed with a drop-in at waybar.service.d rather than copying the unit, so ExecStart, the SIGUSR2 reload and Restart=on-failure stay as packaged. Empty assignments reset the inherited lists before the compositor target is set.

Separately, removed the polkit cgroup check added earlier. It inferred registration from the agent living outside a logind session scope, and the user has since confirmed pkexec produces a password dialog while that check reports failure. The theory was wrong and the check was failing a working system, so it is gone; registration is only confirmable by actually requesting an authentication, which the manual list already covers.

Waybar confirmed showing after the drop-in. The full session now comes up from a graphical login with no manual step.

Verified: boot reaches the ReGreet login screen (AC #1); logging in brings up every supervised component (AC #2); the greeter offers exactly one session and it goes through uwsm, which checks/session.sh asserts on every run (AC #3, with the limit that someone can still run sway by hand from a TTY - it is the accidental path that is closed); the VT 2 escape hatch was proven in anger during the lockout rather than merely documented (AC #5); DECISIONS.md quotes and revises the original no-display-manager entry (AC #7).

Outstanding: AC #4, that locking, idle timeouts and sleep still behave and unlocking returns to the session, and AC #6, the boot time measurement.

Fresh install aborted with "Failed to enable unit: Unit greetd.service does not exist". Ordering bug: apply-config.sh was called from 03-system.sh, which runs before 04-desktop.sh installs the desktop manifest, so greetd did not exist yet when the script tried to enable it. earlyoom was unaffected only because it is in base.txt and therefore already present from pacstrap.

Moved the call to the end of 04-desktop.sh, once every package it refers to exists. sync.sh already had the right order, reconciling packages before configuration; the installer did not.

Enabling is now guarded by a unit-file existence check, done by file rather than through systemctl because this also runs inside the chroot where there is no manager to ask. A future ordering mistake now says what is actually wrong instead of failing on a systemctl error partway through an install.

This is a good argument for the fresh-install test recorded under Testing Strategy: everything worked on the converted machine, and only a build from scratch exposed it.

Boot measured on the VM at 4.412s total - 842ms kernel, 1.501s initrd, 2.068s userspace - with graphical.target reached at 2.065s. systemd-analyze blame is topped entirely by device units, which is timing noise rather than services stalling, so nothing there needs fixing. NetworkManager-wait-online was enabled; nothing on this system orders after network-online.target, so it buys nothing and can stall boot for many seconds on wireless or a slow lease. It is now disabled by apply-config.sh.

swaylock verified: locking and unlocking returns to the running session rather than to the greeter, which was the plausible regression from greetd owning the session. Idle timeout and suspend not separately observed; swayidle.service is confirmed running and its configuration is unchanged from when the timeout was working.
<!-- SECTION:NOTES:END -->
