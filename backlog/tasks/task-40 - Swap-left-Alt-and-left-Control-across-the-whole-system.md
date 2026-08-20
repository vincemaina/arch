---
id: TASK-40
title: Swap left Alt and left Control across the whole system
status: Done
assignee:
  - '@claude'
created_date: '2026-08-20 14:23'
updated_date: '2026-08-20 15:14'
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
- [x] #1 Left Alt and left Control are swapped in the sway session
- [x] #2 The swap applies on the plain console reached by Ctrl+Alt+F2, so the recovery path uses the same modifiers as everything else
- [x] #3 The swap applies at the greeter, which runs before the user session
- [x] #4 XWayland applications are confirmed to follow the swap, by observation rather than assumption
- [x] #5 The keyboard configuration has one source of truth rather than the same option repeated in four places that can drift apart
- [x] #6 tools/shortcuts.sh still reports shortcuts truthfully after the swap
- [x] #7 Whether this is universal or per-machine is decided and recorded, given an external keyboard may already differ
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
keyd rather than xkb_options per context. It remaps at the evdev layer, below xkb and below the console keymap, so sway, the console, the greeter and XWayland inherit one file instead of four being kept in agreement. It is in extra, which mattered: this repository has no AUR support - no helper installed, sync.sh calls pacman -S, and nothing in the manifests comes from outside the official repositories.

The first config was wrong in the way this repository keeps finding. leftcontrol = leftalt parses, looks obviously correct, and emits the Alt keycode without giving the key Alt modifier semantics, so combinations would have composed wrongly. keyd itself warned about it - "You should use layer(alt) instead of assigning to leftalt directly" - which is only visible because keyd check was run before enabling anything rather than after something misbehaved. Rewritten as layer(alt) and layer(control); keyd check then reports no errors.

keyd check turned out to be a real gate rather than advisory: exit 255 on an invalid key, 0 on a good config. apply-config.sh now runs it against /etc/keyd/default.conf and refuses to enable the unit if it fails, because enabling a keyd that cannot parse its config leaves the machine with no usable keyboard to fix itself from. Panic sequence confirmed from the installed man page: backspace+escape+enter held together terminates keyd.

Verified live. keyd is active and enabled; the installed config is byte-identical to the repository; the journal shows DEVICE: match against the AT Translated Set 2 keyboard while correctly ignoring the mouse, the QEMU tablet and the power button; and sway now reports a keyd virtual keyboard alongside the physical device, which is the expected topology. checks/session.sh reports 40 passed 0 failed, sway-commands and sway-bindings pass, and tools/shortcuts.sh runs clean.

XWayland is structurally covered rather than merely likely: events are already swapped before they reach the compositor, so there is no path by which an X11 client could see the unswapped keys. That is a property of choosing keyd - it would have been a genuine open question with xkb_options.

A pleasing accident: Ctrl+Alt+F2 still needs the same two physical keys, because both of its modifiers moved.

Recorded as universal rather than per-machine. The config matches [ids] *, and the swap is a property of the hands rather than the hardware; a per-machine setting would move the modifier depending on which machine was in front of you, which is the opposite of what building muscle memory needs.

Outstanding, all needing a human at the machine: the console reached by Ctrl+Alt+F2, the greeter at the next login, an XWayland client, and direct event-level proof via keyd listen, which needs root.

Event-level proof obtained. keyd listen reports +control / -control when the key left of the space bar is pressed - the daemon itself confirming the physical Alt key now carries the Control modifier, rather than the config file being read back. Verified by the user, since the keyd socket is root-only.

XWayland confirmed by forcing an existing application onto it with QT_QPA_PLATFORM=xcb qutebrowser, which avoided installing an X11 client purely to test with. Behaved correctly.

The console reached by Ctrl+Alt+F2 confirmed working.

Remaining: the greeter, which only appears at the next login.

Greeter confirmed, and by timestamps rather than by a keypress. This boot: keyd logged DEVICE: match against the AT Translated Set 2 keyboard at 16:12:49.168664, and greetd started at 16:12:49.210064 - 42ms later. keyd held an exclusive grab on the keyboard before greetd existed, so the greeter cannot have received unswapped events. That is stronger evidence than trying a modifier in a password field, where the result is largely invisible anyway.

This is a property of remapping at the evdev layer: the ordering makes the greeter correct by construction. With xkb_options it would have needed its own configuration and its own verification.

All seven criteria now met. checks/session.sh reports 40 passed 0 failed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Left Alt and left Control are swapped system-wide with keyd, which remaps at the evdev layer so sway, the console, the greeter and XWayland all inherit one config rather than the same option being repeated in four places that can drift apart. Written with layer(alt) rather than a bare key assignment, which emits the keycode without the modifier semantics - keyd warns about exactly that, caught by running keyd check before enabling anything. apply-config.sh gates activation on keyd check and refuses rather than starting a daemon that cannot parse its config, since that would leave the machine with no keyboard to fix itself from. Verified in every context: keyd listen reports +control from the physically swapped key, an XWayland client via QT_QPA_PLATFORM=xcb behaves correctly, the console reached by Ctrl+Alt+F2 works, and the greeter is covered by keyd grabbing the keyboard 42ms before greetd started. Recorded as universal rather than per-machine, since the swap is a property of the hands and not the hardware. checks/session.sh covers the config, both mappings, the unit, and that a device was actually grabbed.
<!-- SECTION:FINAL_SUMMARY:END -->
