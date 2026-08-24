---
id: TASK-162
title: Control display brightness from the VM guest and from the login/greeter screen
status: Done
assignee:
  - '@claude'
created_date: '2026-08-24 09:06'
updated_date: '2026-08-24 09:21'
labels:
  - vm
  - desktop
dependencies: []
priority: low
ordinal: 171000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Brightness can only be adjusted from inside the bare-metal sway session (the ~/.local/bin/brightness helper and its media-key binding described in CLAUDE.md). There is no way to change it from inside a running VM guest, or from the greetd/ReGreet login screen before any session has started. Give both of those contexts a way to control brightness.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Brightness can be adjusted while a VM guest session is active, at the login/greeter screen, or explain why one of the two is not feasible and adjust scope
- [x] #2 Any new control does not conflict with the existing sway media-key brightness binding or its checks/session.sh coverage
- [x] #3 docs/manual/ documents the new control
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Investigate feasibility in both named contexts before writing any code.
2. VM guest context: read setup/dotfiles/dot_local/bin/executable_vm and setup/system/bin/vm-session. Confirmed (and cross-checked against docs/manual/04-applications.md's own prior investigation from TASK-69.3, which already established cage defines no keybindings at all) that a VM guest run from inside a normal Sway session already has its keyboard shared with every Sway bindsym, including the XF86MonBrightness{Up,Down} bindings in 52-media-keys.conf - Sway intercepts the physical key before the qemu client ever sees it. Verified statically that qemu-system-x86_64 implements no wlr-keyboard-shortcuts-inhibit protocol client (grep of the binary for the protocol name found nothing) and vm-session/executable_vm pass no grab-on-hover option, so nothing competes for the key. So brightness already works for a VM guest window run under Sway - the everyday case - and needs no new code, only confirmation + a doc note.
3. Greeter/login-VM-session context: both regreet (the login prompt) and the dedicated 'Virtual machine' login session are hosted by bare cage, which (per the manual's own existing, cited investigation) implements no keybinding mechanism whatsoever - any key reaches the one client directly. Checked whether a lightweight fix exists: keyd only remaps/re-emits, it cannot execute commands; udev rules cannot react to individual keypresses (only device add/remove); /dev/input/event* and /dev/uinput are root:root 0660/0600 on this machine, so an unprivileged listener cannot read them. The only real fix is a new always-on, root-privileged raw-input daemon, which would then need to detect whether the Sway session currently owns the seat to avoid double-firing with the existing Sway bindsym binding (a real AC#2 conflict risk) - disproportionate new system-level machinery for a low-priority, few-seconds-long screen with no established precedent in this repo for a command-executing input daemon.
4. Narrow scope per AC#1's explicit escape valve: keep the VM-guest-under-Sway case as already working (verify only), declare the greeter/login-VM-session case infeasible with reasoning recorded in the task and in docs/manual/04-applications.md, and make no code change that could conflict with the existing binding (AC#2 trivially holds since nothing new is added).
5. Update docs/manual/04-applications.md to state explicitly that brightness keys are included among the Sway keybindings a VM guest shares, and that the cage-hosted contexts (regreet itself and the Virtual machine login session) cannot honour them, with the reasoning.
6. Run checks/session.sh and checks/manual.sh to confirm nothing broke.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified rather than assumed: grepped the installed qemu-system-x86_64 binary for the wlr-keyboard-shortcuts-inhibit protocol strings (none found), and confirmed vm-session/executable_vm pass no grab-on-hover option - so nothing competes with Sway for the key, matching docs/manual/04-applications.md's existing TASK-69.3 finding that cage (which hosts both the greeter and the login VM session) implements no keybinding mechanism at all, cited from cage's own --help/manual page. Checked for a lightweight fix for the cage-hosted contexts and found none: keyd only remaps/re-emits, it cannot execute commands; udev rules fire on device add/remove, not individual keypresses; /dev/input/event* and /dev/uinput are root:root 0660/0600 on this machine so an unprivileged listener has no access. The only real fix is a new always-on root-privileged raw-input daemon that would also need to detect whether Sway currently owns the seat to avoid double-firing with the existing bindsym binding once logged in (AC#2's conflict risk) - judged disproportionate machinery for a low-priority, few-seconds-long screen, so scope narrowed per AC#1's explicit allowance.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Brightness for a VM guest already works when the guest is run with 'vm run' inside a normal Sway session: Sway intercepts the XF86MonBrightness{Up,Down} bindsyms in 52-media-keys.conf before the qemu client ever sees the key, the same mechanism docs/manual/04-applications.md already documents for $mod bindings (verified by grepping the qemu-system-x86_64 binary for the wlr-keyboard-shortcuts-inhibit protocol, which it does not implement, and confirming vm-session/executable_vm request no keyboard grab). Scope narrowed for the two cage-hosted contexts (the ReGreet login prompt itself, and the dedicated 'Virtual machine' login session) per AC#1's explicit allowance: cage implements no keybinding mechanism at all (an existing, cited finding from TASK-69.3), and neither of its unprivileged callers can read /dev/input or /dev/uinput (root:root 0660/0600 on this machine) - so the only real fix is a new always-on, root-privileged raw-input daemon that would also have to detect whether Sway currently owns the seat to avoid double-firing with the existing binding once logged in, which is disproportionate machinery for a screen seen a few seconds at a time. No code changed, so AC#2 (no conflict with the existing binding) holds trivially. Documented the working case and the narrowed-out case, with reasoning, in docs/manual/04-applications.md (AC#3). Verified with checks/manual.sh (8/8 passed) and checks/session.sh (124/124 passed, 0 failed) on the branch.
<!-- SECTION:FINAL_SUMMARY:END -->
