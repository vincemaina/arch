---
id: TASK-51
title: Two mouse cursors after enabling GPU acceleration
status: Done
assignee: []
created_date: '2026-08-21 00:14'
updated_date: '2026-08-21 00:40'
labels:
  - desktop
  - foundation
dependencies:
  - TASK-26
priority: medium
type: bug
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Enabling 3D acceleration on the hypervisor fixed the software rendering in TASK-26 and left the mouse pointer rendered upside down. Setting WLR_NO_HARDWARE_CURSORS=1 gave a correct pointer and a second, inverted one alongside it.

What the evidence actually shows, which is the useful part. grim captures what sway composites: a software cursor is drawn into the frame and appears in a screenshot, while a hardware cursor lives on a separate plane and does not. A screenshot taken in the two-cursor state contains exactly one pointer, the right way up. So sway is drawing its cursor correctly, and the inverted one is being drawn by something outside the compositor.

That reframes the whole thing. WLR_NO_HARDWARE_CURSORS did not cause the second cursor - it fixed the first one and made the second visible, because previously the only pointer on screen was the one the host was drawing wrongly.

Likely cause, and the first thing to try: the host offers a SPICE agent channel at /dev/virtio-ports/com.redhat.spice.0 and nothing in the guest was listening on it. Without the agent, the SPICE client cannot coordinate the pointer with the guest and falls back to drawing its own. spice-vdagent is 129 KiB in extra and is now declared.

If the agent does not settle it, the remaining suspects are all host-side: the virgl cursor path rendering the guest cursor buffer with a Y-flip, the Display spice OpenGL setting interacting with cursor handling, or the viewer drawing a client-side pointer while ungrabbed. None of those are reachable from inside the guest.

Worth recording either way, because it looks like an unrelated fault and is a direct consequence of fixing TASK-26 - and because the screenshot test that identified which cursor was which is reusable for any question of the form "is the compositor drawing this or is something else".
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Exactly one pointer appears on screen, the right way up
- [x] #2 Whether the fix is the guest agent or something host-side is established, not guessed - the screenshot test distinguishes which side is drawing a cursor
- [x] #3 If it turns out to be host-side, that is recorded as such rather than left as an open bug against this repository
- [ ] #4 WLR_NO_HARDWARE_CURSORS is re-examined once fixed: it was set to work around the inverted pointer, and may no longer be needed
- [x] #5 The outcome is recorded next to the TASK-26 entry in DECISIONS.md, since it is a consequence of that fix rather than a separate fault
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
spice-vdagent tried and did not fix it. The daemon is socket-activated by a udev rule on the virtio port appearing, so it starts by itself on a normal boot; this machine needed one manual start only because the package was installed after the port already existed. Agent and daemon both run, and the daemon logs "opening vdagent virtio channel", so it is talking to the host. The ghost cursor is unchanged.

The elimination is now firm rather than suspected. grim without -c cannot capture a hardware cursor plane - it copies what the compositor composites. A screenshot taken in the two-cursor state contains exactly one pointer, upright, positioned where the working cursor is. So sway is using software cursors, WLR_NO_HARDWARE_CURSORS did reach it, and wlroots is setting no hardware cursor at all. Nothing inside the guest is drawing the second pointer.

Remaining candidates are all on the host: the SPICE viewer drawing its own client-side cursor while ungrabbed, or the virgl cursor path rendering with a Y-flip. Neither is reachable from here.

Left to confirm: whether the ghost appears on a plain console reached by Ctrl+Alt+F2, where sway is not running. If it does, that is conclusive and this stops being a bug against this repository.

Also worth noting for the repository rather than for this bug: spice-vdagent ships its user unit in graphical-session.target.wants, the generic target CLAUDE.md says never to bind session components to. That is the package own choice and is defensible - a SPICE agent should run under any desktop in a VM - but it means the unit will start under any compositor tried later, including anything chosen by TASK-31. Not something to copy.

Fixed. The greeter was the source.

The Ctrl+Alt+F2 test was what cracked it: the inverted pointer appeared on a plain text console, where no compositor runs and a console has no cursor of its own. So nothing was drawing it - it was one stale object on the virtio-gpu cursor plane that the host renders flipped and nothing ever clears.

The greeter sets it. greetd runs cage, which links the same libwlroots-0.20 as sway, and it runs before any user session. Fixing only the user session therefore gave a correct pointer drawn by sway with the greeters stale one still underneath, which is exactly the two-cursor state that was reported. WLR_NO_HARDWARE_CURSORS=1 is now set on the greetd command as well, so nothing sets a hardware cursor at any point in the boot.

Confirmed working with OpenGL and 3D acceleration both enabled, which is the configuration that matters - the fix did not require giving either of them up.

Worth keeping: the elimination method. grim without -c copies what the compositor composites and cannot capture a hardware cursor plane, so a screenshot tells you which side is drawing a pointer. That is what proved sway was innocent long before the cause was found.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Two cursors after enabling 3D acceleration: one drawn correctly by sway, one inverted and stale. The inverted one was a hardware cursor set by the greeter - cage is wlroots like sway and runs first - which the host renders flipped on the virtio-gpu cursor plane and never clears, which is why it survived logging in, switching to a text console and logging out. Setting WLR_NO_HARDWARE_CURSORS=1 on the greetd command as well as in the user session means nothing sets a hardware cursor at any point. Fixed with OpenGL and 3D acceleration both left on. The diagnostic worth remembering: grim cannot capture a hardware cursor plane, so a screenshot distinguishes a cursor the compositor draws from one something else draws.
<!-- SECTION:FINAL_SUMMARY:END -->
