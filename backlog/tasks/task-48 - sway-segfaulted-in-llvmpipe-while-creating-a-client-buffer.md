---
id: TASK-48
title: sway segfaulted in llvmpipe while creating a client buffer
status: To Do
assignee: []
created_date: '2026-08-20 22:36'
updated_date: '2026-08-20 22:37'
labels:
  - foundation
  - performance
dependencies:
  - TASK-26
priority: medium
type: bug
ordinal: 46000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The session died at 23:30:11 on 2026-08-20. The machine did not reboot - only sway went, greetd restarted, and logging back in restored everything.

The coredump is unambiguous about where. Stack trace, innermost first: a segfault in libc, then seven frames inside libgallium-26.1.7, then libwlroots-0.20 at wlr_client_buffer_create. So sway was allocating a buffer for a client window, that call went into Mesa gallium, and it crashed there.

On this machine gallium is llvmpipe. The virtio GPU is presented without 3D - the kernel reports "-virgl" with zero capability sets - so there is no hardware path and everything renders on the CPU. That is TASK-26, recorded in DECISIONS.md under "The VM renders in software". This crash is a consequence of that arrangement rather than a separate problem.

Ruled out. Memory pressure: earlyoom reported 58% available a minute before, no kernel OOM, nothing killed. Configuration: the crash is inside a library, not in sway config parsing, and the session had been running for over an hour and a half.

Unrelated, though it appeared in the same investigation: rofi segfaulted separately at 21:45:55 with a completely different stack - g_log into g_strdup_vprintf into libc, which is glib formatting a log message rather than anything graphical. Plausibly the "Rofi already running?" warning path. Worth its own look only if it recurs.

The real fix is not in the guest. Enabling 3D acceleration on the hypervisor - virt-manager Video set to virtio with 3D acceleration, and Display spice with OpenGL - takes llvmpipe out of the path entirely. TASK-26 already recommends this for performance; this raises the stakes from "the desktop is CPU-rendered" to "the compositor can crash".

Worth deciding whether anything is worth doing inside the guest in the meantime. Sway has no crash recovery, and a compositor segfault costs every open window. There may be nothing proportionate short of enabling acceleration, in which case that is the answer and should be written down rather than left as an open worry.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Whether enabling 3D acceleration on the hypervisor stops it is established by running with acceleration on, not assumed
- [ ] #2 If it recurs before then, the coredump is compared with this one to confirm it is the same path rather than a new fault
- [ ] #3 Whether anything proportionate can be done inside the guest is decided, and concluding that nothing is counts as completing this
- [ ] #4 The outcome is recorded alongside the existing software-rendering entry in DECISIONS.md, since it is the same root cause rather than a separate finding
<!-- AC:END -->
