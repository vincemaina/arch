---
id: TASK-40
title: Swap left Alt and left Control across the whole system
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-20 14:23'
updated_date: '2026-08-20 14:47'
labels:
  - desktop
  - feel
dependencies:
  - TASK-30
priority: medium
type: feature
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Left Control sits in the far bottom corner, and it is the modifier reached for most often - every copy, paste, word-wise motion, terminal signal and readline binding goes through it. Left Alt sits under a stronger finger and is used far less. Swapping them puts the frequent modifier where the hand already is.

xkb has this as a stock option, ctrl:swap_lalt_lctl, so the mechanism is not the question. Where it has to be applied is, because this system has at least four places that read a keyboard configuration independently and nothing currently keeps them agreeing:

sway, through xkb_options in dot_config/sway/config.d/10-input.conf, which already sets xkb_layout gb and is the obvious first home.

The console. install.conf sets KEYMAP=uk, which 03-system.sh writes to /etc/vconsole.conf. Ctrl+Alt+F2 is the documented way back in when the session will not start, and a swap that does not apply there means the recovery path has different modifiers from everything else - which is exactly when muscle memory is least available.

The greeter. greetd and ReGreet run before the user session, so they read their own configuration rather than the sway one.

XWayland applications, which need confirming rather than assuming, since they take a separate path to the keymap.

The interesting question is not how to set it but how to keep the four in agreement, which is the same single-source-of-truth problem apply-config.sh solved for /etc and TASK-14 is circling for per-machine values. A swap applied in three places out of four is worse than not doing it at all: it would work everywhere except the one place reached in an emergency.

Worth checking against TASK-30 before starting. tools/shortcuts.sh already reports every shortcut by the context it applies in, and it should either keep telling the truth after a swap or be taught about it.

Also worth deciding deliberately: whether this is universal or per-machine. An external keyboard may already be laid out differently, which makes it a candidate for the profile mechanism rather than a flat setting.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Left Alt and left Control are swapped in the sway session
- [ ] #2 The swap applies on the plain console reached by Ctrl+Alt+F2, so the recovery path uses the same modifiers as everything else
- [ ] #3 The swap applies at the greeter, which runs before the user session
- [ ] #4 XWayland applications are confirmed to follow the swap, by observation rather than assumption
- [ ] #5 The keyboard configuration has one source of truth rather than the same option repeated in four places that can drift apart
- [ ] #6 tools/shortcuts.sh still reports shortcuts truthfully after the swap
- [ ] #7 Whether this is universal or per-machine is decided and recorded, given an external keyboard may already differ
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. keyd rather than per-layer configuration. It remaps at the evdev layer, below xkb and below the console keymap, so sway, the console, the greeter and XWayland all inherit one config instead of four being kept in agreement. It is in extra, which matters because this repository has no AUR support at all - no helper installed, sync.sh calls pacman -S, and nothing in the manifests comes from outside the official repositories.

2. Declare keyd in packages/desktop.txt. It is machine-wide input rather than a desktop application, but desktop.txt is where non-base packages live and the manifest is read before apply-config.sh runs, which is the ordering the unit needs.

3. Add setup/system/keyd/default.conf with [ids] * so it applies to every keyboard, and the two-line swap in [main].

4. Install and enable it from apply-config.sh, which is the single owner of machine-wide configuration and already reaches both a fresh install and a running machine. Add keyd to ENABLE_UNITS, and add the config to CONFIG_FILES.

5. Restart keyd on --activate so the swap takes effect without a reboot. Unlike greetd, keyd does not own the session, so restarting it is safe.

6. Verify against the running system rather than the file, per the failure mode this repository keeps hitting. keyd -m reports what the daemon actually emits for a physical keypress, which is the only direct evidence the remap is live. Confirm in the sway session, on a plain console reached by Ctrl+Alt+F2, and in an XWayland client.

7. Extend checks/session.sh: keyd running and restartable, and its config mapping both directions. A swap present in three of four contexts is worse than none, so the check should cover the ones a script can reach.

8. Record the decision in DECISIONS.md, including the udev hwdb alternative, which needs no package at all and was rejected for not growing into the keyboard layer TASK-19 anticipates.

9. Safety. A root daemon intercepting all input can lock the keyboard out of the machine used to fix it. Confirm the documented panic sequence from the installed man page before enabling, and note it in the decision record.
<!-- SECTION:PLAN:END -->
